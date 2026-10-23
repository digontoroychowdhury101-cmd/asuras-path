--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/InputController
-- Hybrid Souls control scheme for keyboard/mouse, gamepad and touch. Presses are stamped with
-- server time, deduplicated and priority-ordered through the shared InputBuffer, then sent as
-- ActionIntent packets. The server buffers again and re-validates every action.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local InputBuffer = require(Shared:WaitForChild("Simulation"):WaitForChild("InputBuffer") :: ModuleScript)
local InputMap = require(Shared:WaitForChild("Shared"):WaitForChild("InputMap") :: ModuleScript)
local WorldState = require(script.Parent:WaitForChild("WorldStateController") :: ModuleScript)
local CameraController = require(script.Parent:WaitForChild("CameraController") :: ModuleScript)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Movement = require(script.Parent:WaitForChild("MovementController") :: ModuleScript)

type WorldState = WorldState.WorldState
type CameraController = CameraController.CameraController

export type Device = "Keyboard" | "Gamepad" | "Touch"
export type Command =
	"Light"
	| "Heavy"
	| "WeaponArt"
	| "Guard"
	| "Roll"
	| "Dash"
	| "Sprint"
	| "Lock"
	| "Swap"
	| "Heal"
	| "Interact"
	| "Shoulder"
	| "Cursor"
	| "Jump"
	| "Slide"
	| "Aim"

local Controller = {}
Controller.__index = Controller

-- Bindings, captions and touch labels all come from the shared InputMap.
local function keyTable(names: { [string]: InputMap.Command }, enum: any): { [any]: Command }
	local result: { [any]: Command } = {}
	for name, command in names do
		result[enum[name]] = command :: any
	end
	return result
end
local KEYBOARD: { [Enum.KeyCode]: Command } = keyTable(InputMap.lookup("Combat", "Keys"), Enum.KeyCode)
local MOUSE: { [Enum.UserInputType]: Command } = keyTable(InputMap.lookup("Combat", "Mouse"), Enum.UserInputType)
local GAMEPAD: { [Enum.KeyCode]: Command } = keyTable(InputMap.lookup("Combat", "Pad"), Enum.KeyCode)
-- Keys bound to "Cursor": the cursor stays free only while one of them is physically held.
local CURSOR_KEYS: { Enum.KeyCode } = {}
for _, name in (InputMap.get("Cursor") :: InputMap.Binding).Keys do
	table.insert(CURSOR_KEYS, (Enum.KeyCode :: any)[name])
end
-- Jump, dash, slide and glide inputs are owned by one context action (native held-jump repeats
-- cannot spend the double jump); jump never takes the raw InputBegan path.
local MOVEMENT_INPUTS: { any } = {}
local JUMP_INPUTS: { [Enum.KeyCode]: boolean } = {}
for _, command in { "Jump", "Dash", "Slide", "Aim" } do
	local binding = InputMap.get(command) :: InputMap.Binding
	for _, name in binding.Keys do
		table.insert(MOVEMENT_INPUTS, (Enum.KeyCode :: any)[name])
	end
	for _, name in binding.Pad do
		table.insert(MOVEMENT_INPUTS, (Enum.KeyCode :: any)[name])
	end
	for _, name in binding.Mouse do
		table.insert(MOVEMENT_INPUTS, (Enum.UserInputType :: any)[name])
	end
	if command == "Jump" then
		for _, name in binding.Keys do
			KEYBOARD[(Enum.KeyCode :: any)[name]] = nil
			JUMP_INPUTS[(Enum.KeyCode :: any)[name]] = true
		end
		for _, name in binding.Pad do
			GAMEPAD[(Enum.KeyCode :: any)[name]] = nil
			JUMP_INPUTS[(Enum.KeyCode :: any)[name]] = true
		end
	end
end
local PROMPT_KEY: Enum.KeyCode = (Enum.KeyCode :: any)[InputMap.PromptKey]
local PROMPT_PAD: Enum.KeyCode = (Enum.KeyCode :: any)[InputMap.PromptPad]

local TOUCH_LAYOUT: { { Command: Command, Position: UDim2, Size: number } } = {
	{ Command = "Light", Position = UDim2.new(1, -96, 1, -150), Size = 84 },
	{ Command = "Heavy", Position = UDim2.new(1, -190, 1, -110), Size = 72 },
	{ Command = "Guard", Position = UDim2.new(1, -110, 1, -250), Size = 72 },
	{ Command = "Dash", Position = UDim2.new(1, -205, 1, -205), Size = 64 },
	{ Command = "Jump", Position = UDim2.new(1, -82, 1, -62), Size = 68 },
	{ Command = "Slide", Position = UDim2.new(1, -300, 1, -325), Size = 56 },
	{ Command = "Aim", Position = UDim2.new(1, -300, 1, -65), Size = 52 },
	{ Command = "WeaponArt", Position = UDim2.new(1, -280, 1, -150), Size = 56 },
	{ Command = "Lock", Position = UDim2.new(1, -70, 1, -326), Size = 52 },
	{ Command = "Heal", Position = UDim2.new(1, -150, 1, -320), Size = 52 },
	{ Command = "Interact", Position = UDim2.new(1, -230, 1, -290), Size = 52 },
	{ Command = "Swap", Position = UDim2.new(1, -300, 1, -230), Size = 48 },
}

-- Own jump edges so native held-jump repeats cannot spend the double jump.
local MOVEMENT_ACTION = "AsuraKineticMovement"
local STICK_DEADZONE = 0.18
local STICK_SPEED = 900
local TOUCH_SCALE = 1.4
-- Authored minimum button size: at the smallest HUD factor (0.7) it is still a 44-point target (batch 25).
local MIN_TOUCH = 64

export type Sender = (action: string, variant: string?, x: number?, z: number?, held: boolean?, time: number?) -> ()

type Fields = {
	State: WorldState,
	Camera: CameraController,
	Movement: Movement.MovementController,
	Send: Sender,
	Buffer: InputBuffer.Buffer,
	Device: Device,
	Connections: { RBXScriptConnection },
	GuardHeld: boolean,
	SprintHeld: boolean,
	CursorFree: boolean,
	MenuOpen: boolean,
	MenuOwners: { [string]: true },
	Stick: Vector2,
	TouchLook: Vector2,
	TouchGui: ScreenGui,
	TouchButtons: { [Command]: TextButton },
	LookTouch: InputObject?,
	OnCommand: ((command: Command) -> ())?,
	OnDeviceChanged: ((device: Device) -> ())?,
}

export type InputController = typeof(setmetatable({} :: Fields, Controller))

local function deviceFor(inputType: Enum.UserInputType): Device?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.sub(inputType.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Keyboard or string.sub(inputType.Name, 1, 5) == "Mouse" then
		return "Keyboard"
	end
	return nil
end

-- Prompts currently on screen (most recent last) and the one a touch USE press is holding.
local shownPrompts: { ProximityPrompt } = {}
local heldPrompt: ProximityPrompt? = nil

local function buildTouchGui(self: InputController)
	-- Buttons hang off a bottom-right cluster that scales with the viewport, so the top of the
	-- cluster never climbs into the Roblox top bar on short landscape phones.
	local gui = Instance.new("Frame")
	gui.Name = "Cluster"
	gui.AnchorPoint = Vector2.new(1, 1)
	gui.Position = UDim2.fromScale(1, 1)
	gui.Size = UDim2.fromOffset(340, 360)
	gui.BackgroundTransparency = 1
	gui.Parent = self.TouchGui
	gui.Destroying:Once(HudKit.bindScale(gui, 1))
	for _, entry in TOUCH_LAYOUT do
		local button = Instance.new("TextButton")
		button.Name = entry.Command
		button.Text = InputMap.label(entry.Command, "Touch")
		button.Font = Enum.Font.GothamMedium
		button.TextScaled = true
		button.TextColor3 = Color3.fromRGB(255, 226, 238)
		button.BackgroundColor3 = Color3.fromRGB(48, 18, 42)
		button.BackgroundTransparency = 0.3
		button.AutoButtonColor = false
		button.Size = UDim2.fromOffset(math.max(entry.Size, MIN_TOUCH), math.max(entry.Size, MIN_TOUCH))
		button.Position = entry.Position
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(247, 168, 200)
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.18, 0)
		padding.PaddingLeft = UDim.new(0.08, 0)
		padding.PaddingRight = UDim.new(0.08, 0)
		local textLimit = Instance.new("UITextSizeConstraint")
		textLimit.MinTextSize, textLimit.MaxTextSize = 10, 16
		textLimit.Parent = button
		padding.PaddingBottom = UDim.new(0.18, 0)
		padding.Parent = button
		local command: Command = entry.Command
		button.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				button.BackgroundTransparency = 0.05
				self:Press(command)
			end
		end)
		button.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				button.BackgroundTransparency = 0.3
				self:Release(command)
			end
		end)
		button.Parent = gui
		self.TouchButtons[command] = button
	end
	local compact = { { "Slide", "Heal", "Lock" }, { "Swap", "Interact", "Guard" },
		{ "WeaponArt", "Dash", "Light" }, { "Aim", "Heavy", "Jump" } }
	local function arrange()
		if self.TouchGui.AbsoluteSize.Y < 420 then
			for row, names in compact do
				for col, name in names do
					local button = self.TouchButtons[name :: Command]
					button.Position = UDim2.new(1, -({ 218, 136, 54 })[col], 1, -({ 274, 200, 122, 40 })[row])
				end
			end
		else
			for _, entry in TOUCH_LAYOUT do self.TouchButtons[entry.Command].Position = entry.Position end
		end
	end
	table.insert(self.Connections, self.TouchGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange))
	arrange()
	-- PlayerModule still owns the native thumbstick. Its separate jump button would duplicate
	-- our edge-owned double jump, so hide that button only, including when Roblox rebuilds it.
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function nativeJump(item: Instance)
		if item.Name ~= "JumpButton" or not item:IsA("GuiObject") or not item:FindFirstAncestor("TouchControlFrame") then return end
		item.Visible = false
		table.insert(self.Connections, item:GetPropertyChangedSignal("Visible"):Connect(function() if item.Visible then item.Visible = false end end))
	end
	for _, item in playerGui:GetDescendants() do nativeJump(item) end
	table.insert(self.Connections, playerGui.DescendantAdded:Connect(nativeJump))
end

function Controller.new(state: WorldState, camera: CameraController, send: Sender, movement: Movement.MovementController): InputController
	local gui = Instance.new("ScreenGui")
	gui.Name = "AsuraTouchControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local fields: Fields = {
		State = state,
		Camera = camera,
		Movement = movement,
		Send = send,
		Buffer = InputBuffer.new(),
		Device = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Touch" else "Keyboard",
		Connections = {},
		GuardHeld = false,
		SprintHeld = false,
		CursorFree = false,
		MenuOpen = false,
		MenuOwners = {},
		Stick = Vector2.zero,
		TouchLook = Vector2.zero,
		TouchGui = gui,
		TouchButtons = {},
		LookTouch = nil,
		OnCommand = nil,
		OnDeviceChanged = nil,
	}
	local self = setmetatable(fields, Controller)
	buildTouchGui(self)
	self:SetDevice(self.Device)
	table.insert(self.Connections, ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		-- Any prompt (including saved-place content) answers the shared Interact binding.
		if prompt.KeyboardKeyCode ~= PROMPT_KEY or prompt.GamepadKeyCode ~= PROMPT_PAD then
			InputMap.applyPrompt(prompt)
		end
		table.insert(shownPrompts, prompt)
	end))
	table.insert(self.Connections, ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local index = table.find(shownPrompts, prompt)
		if index then
			table.remove(shownPrompts, index)
		end
		if heldPrompt == prompt then
			heldPrompt = nil
		end
	end))

	table.insert(self.Connections, UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		local device: Device? = deviceFor(inputType)
		if device then
			self:SetDevice(device)
		end
	end))
	-- Device Simulator and hardware capability changes need not produce an input event. Refresh
	-- on capability changes too, so an already-running session never keeps desktop controls on a phone.
	local function capabilitiesChanged()
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			self:SetDevice("Touch")
		elseif not UserInputService.KeyboardEnabled and UserInputService.GamepadEnabled then
			self:SetDevice("Gamepad")
		elseif self.Device == "Touch" and not UserInputService.TouchEnabled then
			self:SetDevice(deviceFor(UserInputService:GetLastInputType()) or "Keyboard")
		end
	end
	for _, capability in { "TouchEnabled", "KeyboardEnabled", "GamepadEnabled" } do
		table.insert(self.Connections, UserInputService:GetPropertyChangedSignal(capability):Connect(capabilitiesChanged))
	end
	capabilitiesChanged()
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		self:Began(input, processed)
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input: InputObject, _processed: boolean)
		self:Ended(input)
	end))
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		self:Changed(input, processed)
	end))
	table.insert(self.Connections, UserInputService.WindowFocusReleased:Connect(function()
		self.Movement:Cancel()
		self.CursorFree = false -- the Alt release is lost when focus leaves mid-press
	end))
	table.insert(self.Connections, UserInputService.WindowFocused:Connect(function() self.CursorFree = false end))
	table.insert(self.Connections, UserInputService.TextBoxFocused:Connect(function() self.Movement:SetEnabled(false) end))
	table.insert(self.Connections, GuiService.MenuOpened:Connect(function() self.Movement:SetEnabled(false) end))
	ContextActionService:BindActionAtPriority(MOVEMENT_ACTION, function(_name: string, inputState: Enum.UserInputState, event: InputObject): Enum.ContextActionResult
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		local command: Command = if JUMP_INPUTS[event.KeyCode] then "Jump"
			else KEYBOARD[event.KeyCode] or GAMEPAD[event.KeyCode] or MOUSE[event.UserInputType]
		if inputState == Enum.UserInputState.Begin then
			self:SetDevice(deviceFor(event.UserInputType) or self.Device)
			self:Press(command)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			self:Release(command)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(MOVEMENT_INPUTS))
	return self
end

function Controller.SetDevice(self: InputController, device: Device)
	if self.Device == device and self.TouchGui.Enabled == (device == "Touch") then
		return
	end
	self.Device = device
	Players.LocalPlayer:SetAttribute("AsuraInputDevice", device)
	self.TouchGui.Enabled = device == "Touch" and not self.MenuOpen
	local callback = self.OnDeviceChanged
	if callback then
		callback(device)
	end
end

-- Caption of any InputMap command (combat, spells, menus) for the active device; "" on touch.
function Controller.Label(self: InputController, command: string): string
	if self.Device == "Touch" then
		return ""
	end
	return InputMap.label(command, self.Device)
end

-- Caption for instructional text (tutorial, counter hints): touch names its on-screen button
-- ("JUMP") where Label answers "" so key badges can hide (batch 25).
function Controller.Hint(self: InputController, command: string): string
	return InputMap.label(command, self.Device)
end

-- Each window claims input under its own owner name; input stays with menus until every owner has
-- released it, so closing Respite over a dialogue cannot hand keys back while Lin is still talking.
function Controller.SetMenu(self: InputController, open: boolean, owner: string?)
	self.MenuOwners[owner or "Menu"] = if open then true else nil
	open = next(self.MenuOwners) ~= nil
	self.MenuOpen = open
	self.Movement:SetEnabled(not open)
	self.TouchGui.Enabled = self.Device == "Touch" and not open
	if open and self.GuardHeld then
		self:Release("Guard")
	end
	if open and self.SprintHeld then
		self.SprintHeld = false
		self.Send("Sprint", nil, nil, nil, false, Workspace:GetServerTimeNow())
	end
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Movement intent in world space for evasions: stick/keys direction, else straight back.
function Controller.EvadeDirection(self: InputController): Vector3
	local own = self.State:Own()
	local humanoid = own and own.Humanoid
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		local direction = humanoid.MoveDirection
		return Vector3.new(direction.X, 0, direction.Z).Unit
	end
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local back = -Vector3.new(look.X, 0, look.Z)
	return if back.Magnitude > 1e-3 then back.Unit else Vector3.new(0, 0, 1)
end

function Controller.Press(self: InputController, command: Command)
	local callback = self.OnCommand
	if callback then
		callback(command)
	end
	local blocked = self.MenuOpen or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil
	-- Open menus own every key except cursor release; world interaction waits until they close.
	if blocked and command ~= "Cursor" then
		return
	end
	local stamp = now()
	if command == "Jump" or command == "Slide" or command == "Aim" then
		self.Movement:Press(command)
	elseif command == "Light" or command == "Heavy" or command == "WeaponArt" then
		InputBuffer.push(self.Buffer, command, stamp)
	elseif command == "Guard" then
		-- Sekiro rule: a guard press during a feintable windup feints; otherwise it deflects, and
		-- holding it keeps the guard raised once the deflect window closes.
		local snapshot = self.State:OwnSnapshot()
		if snapshot and snapshot.State == "Startup" then
			self.Send("Feint", nil, nil, nil, nil, stamp)
		end
		InputBuffer.push(self.Buffer, "Deflect", stamp)
		if not self.GuardHeld then
			self.GuardHeld = true
			self.Send("Block", nil, nil, nil, true, stamp)
		end
	elseif command == "Roll" or command == "Dash" then
		self.Movement:Release("Slide")
		local direction = self:EvadeDirection()
		InputBuffer.push(self.Buffer, command, stamp, nil, direction.X, direction.Z)
	elseif command == "Sprint" then
		if self.Device == "Gamepad" or self.Device == "Keyboard" then
			self.SprintHeld = not self.SprintHeld
		else
			self.SprintHeld = true
		end
		self.Send("Sprint", nil, nil, nil, self.SprintHeld, stamp)
	elseif command == "Lock" then
		self.Camera:ToggleLock()
	elseif command == "Shoulder" then
		self.Camera:ToggleShoulder()
	elseif command == "Swap" then
		self.Send("Swap", nil, nil, nil, nil, stamp)
	elseif command == "Heal" then
		self.Send("Heal", nil, nil, nil, nil, stamp)
	elseif command == "Interact" then
		-- A visible prompt on the Interact key already owns the press (and runs its hold bar);
		-- sending the intent too would rest or recover twice. Touch USE drives the prompt instead.
		local prompt = self:OwningPrompt()
		if prompt then
			if self.Device == "Touch" then
				heldPrompt = prompt
				prompt:InputHoldBegin()
			end
			return
		end
		self.Send("Interact", nil, nil, nil, nil, stamp)
	elseif command == "Cursor" then
		-- Held, not toggled: Alt-Tab and window focus changes deliver a lone Alt press, which used to
		-- leave the cursor free and mouse look dead until Alt was pressed again.
		self.CursorFree = true
	end
end

-- The newest visible prompt that answers this device's Interact input (InputMap.routeInteract).
function Controller.OwningPrompt(self: InputController): ProximityPrompt?
	local views: { InputMap.PromptView } = {}
	for index, prompt in shownPrompts do
		views[index] = { Enabled = prompt.Enabled, Key = prompt.KeyboardKeyCode.Name, Pad = prompt.GamepadKeyCode.Name }
	end
	local route, index = InputMap.routeInteract(self.Device, views, false)
	return if route == "Prompt" and index then shownPrompts[index] else nil
end

function Controller.Release(self: InputController, command: Command)
	if command == "Jump" or command == "Slide" or command == "Aim" then
		self.Movement:Release(command)
	elseif command == "Interact" and heldPrompt then
		heldPrompt:InputHoldEnd()
		heldPrompt = nil
	elseif command == "Guard" and self.GuardHeld then
		self.GuardHeld = false
		self.Send("Block", nil, nil, nil, false, now())
	elseif command == "Sprint" and self.Device == "Touch" and self.SprintHeld then
		self.SprintHeld = false
		self.Send("Sprint", nil, nil, nil, false, now())
	elseif command == "Cursor" then
		self.CursorFree = false
	end
end

function Controller.Began(self: InputController, input: InputObject, processed: boolean)
	local device: Device? = deviceFor(input.UserInputType)
	if device then
		self:SetDevice(device)
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		if not processed and self.LookTouch == nil and input.Position.X > Workspace.CurrentCamera.ViewportSize.X * 0.4 then
			self.LookTouch = input
		end
		return
	end
	if processed or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	local command: Command? = nil
	if input.UserInputType == Enum.UserInputType.Keyboard then
		command = KEYBOARD[input.KeyCode]
	elseif MOUSE[input.UserInputType] then
		command = MOUSE[input.UserInputType]
	elseif device == "Gamepad" then
		command = GAMEPAD[input.KeyCode]
	end
	if command ~= nil then
		self:Press(command :: Command)
	end
end

function Controller.Ended(self: InputController, input: InputObject)
	if input == self.LookTouch then
		self.LookTouch = nil
		return
	end
	local command: Command? = nil
	if input.UserInputType == Enum.UserInputType.Keyboard then
		command = KEYBOARD[input.KeyCode]
	elseif MOUSE[input.UserInputType] then
		command = MOUSE[input.UserInputType]
	elseif deviceFor(input.UserInputType) == "Gamepad" then
		command = GAMEPAD[input.KeyCode]
	end
	if command ~= nil then
		self:Release(command :: Command)
	end
end

function Controller.Changed(self: InputController, input: InputObject, processed: boolean)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local value = Vector2.new(input.Position.X, -input.Position.Y)
		self.Stick = if value.Magnitude > STICK_DEADZONE then value else Vector2.zero
	elseif input == self.LookTouch and not processed then
		self.TouchLook += Vector2.new(input.Delta.X, input.Delta.Y) * TOUCH_SCALE
	end
end

-- Per frame: route look input to the camera, then flush buffered presses in priority order.
function Controller.Step(self: InputController, dt: number)
	self.Movement:SetEnabled(not self.MenuOpen and not GuiService.MenuIsOpen and UserInputService:GetFocusedTextBox() == nil)
	if self.CursorFree then
		local held = false
		for _, key in CURSOR_KEYS do
			held = held or UserInputService:IsKeyDown(key)
		end
		self.CursorFree = held -- a press whose release never arrived (focus change) must not stick
	end
	local gameplay = not self.MenuOpen and not self.CursorFree and self.Device ~= "Touch"
	UserInputService.MouseBehavior = if gameplay then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not gameplay
	if not self.MenuOpen then
		if self.Device == "Keyboard" and gameplay then
			local delta = UserInputService:GetMouseDelta()
			if delta.Magnitude > 0 then
				self.Camera:Look(delta)
			end
		elseif self.Device == "Gamepad" then
			if self.Camera.Locked then
				self.Camera:Look(self.Stick, true)
			elseif self.Stick.Magnitude > 0 then
				self.Camera:Look(self.Stick * STICK_SPEED * dt)
			end
		elseif self.Device == "Touch" and self.TouchLook.Magnitude > 0 then
			self.Camera:Look(self.TouchLook)
		end
	end
	self.TouchLook = Vector2.zero
	if GuiService.MenuIsOpen then
		return
	end
	local stamp = now()
	for _ = 1, self.Buffer.Capacity do
		local action, time, variant, x, z = InputBuffer.pop(self.Buffer, stamp)
		if action == nil then
			break
		end
		local hasDirection = action == "Roll" or action == "Dash"
		self.Send(action, if variant ~= "" then variant else nil, if hasDirection then x else nil, if hasDirection then z else nil, nil, time)
	end
end

function Controller.Destroy(self: InputController)
	ContextActionService:UnbindAction(MOVEMENT_ACTION)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self.TouchGui:Destroy()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

return Controller

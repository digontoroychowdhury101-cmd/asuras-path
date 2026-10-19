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

local KEYBOARD: { [Enum.KeyCode]: Command } = {
	[Enum.KeyCode.F] = "Guard",
	[Enum.KeyCode.LeftControl] = "Slide",
	[Enum.KeyCode.C] = "Slide",
	[Enum.KeyCode.LeftShift] = "Dash",
	[Enum.KeyCode.Q] = "Dash",
	[Enum.KeyCode.CapsLock] = "Sprint",
	[Enum.KeyCode.X] = "Lock",
	[Enum.KeyCode.J] = "Swap",
	[Enum.KeyCode.V] = "Heavy",
	[Enum.KeyCode.R] = "Heal",
	[Enum.KeyCode.Z] = "Interact",
	[Enum.KeyCode.G] = "WeaponArt",
	[Enum.KeyCode.T] = "Shoulder",
	[Enum.KeyCode.LeftAlt] = "Cursor",
}
local MOUSE: { [Enum.UserInputType]: Command } = {
	[Enum.UserInputType.MouseButton1] = "Light",
	[Enum.UserInputType.MouseButton2] = "Aim",
	[Enum.UserInputType.MouseButton3] = "Lock",
}
local GAMEPAD: { [Enum.KeyCode]: Command } = {
	[Enum.KeyCode.ButtonR1] = "Light",
	[Enum.KeyCode.ButtonR2] = "Heavy",
	[Enum.KeyCode.ButtonL1] = "Guard",
	[Enum.KeyCode.ButtonL2] = "Aim",
	[Enum.KeyCode.ButtonB] = "Dash",
	[Enum.KeyCode.ButtonR3] = "Lock",
	[Enum.KeyCode.ButtonL3] = "Slide",
	[Enum.KeyCode.DPadLeft] = "Sprint",
	[Enum.KeyCode.ButtonStart] = "Heal",
	[Enum.KeyCode.ButtonX] = "Interact",
	[Enum.KeyCode.ButtonY] = "WeaponArt",
	[Enum.KeyCode.DPadRight] = "Swap",
}

local LABELS: { [Command]: { Keyboard: string, Gamepad: string } } = {
	Light = { Keyboard = "M1", Gamepad = "R1" },
	Heavy = { Keyboard = "V", Gamepad = "R2" },
	Guard = { Keyboard = "F", Gamepad = "L1" },
	Roll = { Keyboard = "Shift/Q", Gamepad = "B" },
	Lock = { Keyboard = "X", Gamepad = "R3" },
	Swap = { Keyboard = "J", Gamepad = "D-Right" },
	Heal = { Keyboard = "R", Gamepad = "Start" },
	Interact = { Keyboard = "Z", Gamepad = "X" },
	WeaponArt = { Keyboard = "G", Gamepad = "Y" },
	Dash = { Keyboard = "Shift/Q", Gamepad = "B" },
	Sprint = { Keyboard = "Caps", Gamepad = "D-Left" },
	Shoulder = { Keyboard = "T", Gamepad = "—" },
	Cursor = { Keyboard = "Alt", Gamepad = "—" },
	Jump = { Keyboard = "Space", Gamepad = "A" },
	Slide = { Keyboard = "C/Ctrl", Gamepad = "L3" },
	Aim = { Keyboard = "RMB", Gamepad = "L2" },
}

local TOUCH_LAYOUT: { { Command: Command, Label: string, Position: UDim2, Size: number } } = {
	{ Command = "Light", Label = "ATK", Position = UDim2.new(1, -96, 1, -150), Size = 84 },
	{ Command = "Heavy", Label = "HVY", Position = UDim2.new(1, -190, 1, -110), Size = 72 },
	{ Command = "Guard", Label = "GUARD", Position = UDim2.new(1, -110, 1, -250), Size = 72 },
	{ Command = "Dash", Label = "DASH", Position = UDim2.new(1, -205, 1, -205), Size = 64 },
	{ Command = "Jump", Label = "JUMP", Position = UDim2.new(1, -82, 1, -62), Size = 68 },
	{ Command = "Slide", Label = "SLIDE", Position = UDim2.new(1, -300, 1, -325), Size = 56 },
	{ Command = "Aim", Label = "GLIDE", Position = UDim2.new(1, -300, 1, -65), Size = 52 },
	{ Command = "WeaponArt", Label = "SKILL", Position = UDim2.new(1, -280, 1, -150), Size = 56 },
	{ Command = "Lock", Label = "LOCK", Position = UDim2.new(1, -70, 1, -330), Size = 52 },
	{ Command = "Heal", Label = "HEAL", Position = UDim2.new(1, -150, 1, -320), Size = 52 },
	{ Command = "Interact", Label = "USE", Position = UDim2.new(1, -230, 1, -290), Size = 52 },
	{ Command = "Swap", Label = "SWAP", Position = UDim2.new(1, -300, 1, -230), Size = 48 },
}

-- Own jump edges so native held-jump repeats cannot spend the double jump.
local MOVEMENT_ACTION = "AsuraKineticMovement"
local STICK_DEADZONE = 0.18
local STICK_SPEED = 900
local TOUCH_SCALE = 1.4

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
		button.Text = entry.Label
		button.Font = Enum.Font.Antique
		button.TextScaled = true
		button.TextColor3 = Color3.fromRGB(236, 226, 206)
		button.BackgroundColor3 = Color3.fromRGB(20, 14, 12)
		button.BackgroundTransparency = 0.3
		button.AutoButtonColor = false
		button.Size = UDim2.fromOffset(entry.Size, entry.Size)
		button.Position = entry.Position
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(150, 32, 28)
		stroke.Thickness = 2
		stroke.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.18, 0)
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
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		self:Began(input, processed)
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input: InputObject, _processed: boolean)
		self:Ended(input)
	end))
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		self:Changed(input, processed)
	end))
	table.insert(self.Connections, UserInputService.WindowFocusReleased:Connect(function() self.Movement:Cancel() end))
	table.insert(self.Connections, UserInputService.TextBoxFocused:Connect(function() self.Movement:SetEnabled(false) end))
	table.insert(self.Connections, GuiService.MenuOpened:Connect(function() self.Movement:SetEnabled(false) end))
	ContextActionService:BindActionAtPriority(MOVEMENT_ACTION, function(_name: string, inputState: Enum.UserInputState, event: InputObject): Enum.ContextActionResult
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		local command: Command = if event.KeyCode == Enum.KeyCode.Space or event.KeyCode == Enum.KeyCode.ButtonA then "Jump"
			else KEYBOARD[event.KeyCode] or GAMEPAD[event.KeyCode] or MOUSE[event.UserInputType]
		if inputState == Enum.UserInputState.Begin then
			self:SetDevice(deviceFor(event.UserInputType) or self.Device)
			self:Press(command)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			self:Release(command)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA,
		Enum.KeyCode.LeftShift, Enum.KeyCode.Q, Enum.KeyCode.ButtonB, Enum.KeyCode.C, Enum.KeyCode.LeftControl,
		Enum.KeyCode.ButtonL3, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	return self
end

function Controller.SetDevice(self: InputController, device: Device)
	if self.Device == device and self.TouchGui.Enabled == (device == "Touch") then
		return
	end
	self.Device = device
	self.TouchGui.Enabled = device == "Touch" and not self.MenuOpen
	local callback = self.OnDeviceChanged
	if callback then
		callback(device)
	end
end

function Controller.Label(self: InputController, command: Command): string
	local entry = LABELS[command]
	if self.Device == "Gamepad" then
		return entry.Gamepad
	elseif self.Device == "Touch" then
		return ""
	end
	return entry.Keyboard
end

function Controller.SetMenu(self: InputController, open: boolean)
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
	if blocked then
		if command ~= "Interact" and command ~= "Cursor" then return end
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
		-- A visible ProximityPrompt already owns E / ButtonX (and runs its hold bar); sending the
		-- Interact intent as well would rest or recover twice. Touch USE drives the prompt instead.
		local prompt = shownPrompts[#shownPrompts]
		if prompt and not self.MenuOpen then
			if self.Device == "Touch" then
				heldPrompt = prompt
				prompt:InputHoldBegin()
			end
			return
		end
		self.Send("Interact", nil, nil, nil, nil, stamp)
	elseif command == "Cursor" then
		self.CursorFree = not self.CursorFree
	end
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

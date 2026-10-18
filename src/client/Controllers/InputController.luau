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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local InputBuffer = require(Shared:WaitForChild("Simulation"):WaitForChild("InputBuffer") :: ModuleScript)
local WorldState = require(script.Parent:WaitForChild("WorldStateController") :: ModuleScript)
local CameraController = require(script.Parent:WaitForChild("CameraController") :: ModuleScript)

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

local Controller = {}
Controller.__index = Controller

local KEYBOARD: { [Enum.KeyCode]: Command } = {
	[Enum.KeyCode.F] = "Guard",
	[Enum.KeyCode.LeftControl] = "Dash",
	[Enum.KeyCode.LeftShift] = "Sprint",
	[Enum.KeyCode.X] = "Lock",
	[Enum.KeyCode.Q] = "Swap",
	[Enum.KeyCode.R] = "Heal",
	[Enum.KeyCode.E] = "Interact",
	[Enum.KeyCode.G] = "WeaponArt",
	[Enum.KeyCode.T] = "Shoulder",
	[Enum.KeyCode.LeftAlt] = "Cursor",
}
local MOUSE: { [Enum.UserInputType]: Command } = {
	[Enum.UserInputType.MouseButton1] = "Light",
	[Enum.UserInputType.MouseButton2] = "Heavy",
	[Enum.UserInputType.MouseButton3] = "Lock",
}
local GAMEPAD: { [Enum.KeyCode]: Command } = {
	[Enum.KeyCode.ButtonR1] = "Light",
	[Enum.KeyCode.ButtonR2] = "Heavy",
	[Enum.KeyCode.ButtonL1] = "Guard",
	[Enum.KeyCode.ButtonL2] = "Roll",
	[Enum.KeyCode.ButtonB] = "Roll",
	[Enum.KeyCode.ButtonR3] = "Lock",
	[Enum.KeyCode.ButtonL3] = "Sprint",
	[Enum.KeyCode.DPadDown] = "Swap",
	[Enum.KeyCode.DPadUp] = "Heal",
	[Enum.KeyCode.ButtonX] = "Interact",
	[Enum.KeyCode.ButtonY] = "WeaponArt",
	[Enum.KeyCode.DPadRight] = "Shoulder",
}

local LABELS: { [Command]: { Keyboard: string, Gamepad: string } } = {
	Light = { Keyboard = "M1", Gamepad = "R1" },
	Heavy = { Keyboard = "M2", Gamepad = "R2" },
	Guard = { Keyboard = "F", Gamepad = "L1" },
	Roll = { Keyboard = "Space", Gamepad = "B" },
	Lock = { Keyboard = "X", Gamepad = "R3" },
	Swap = { Keyboard = "Q", Gamepad = "D-Down" },
	Heal = { Keyboard = "R", Gamepad = "D-Up" },
	Interact = { Keyboard = "E", Gamepad = "X" },
	WeaponArt = { Keyboard = "G", Gamepad = "Y" },
	Dash = { Keyboard = "Ctrl", Gamepad = "—" },
	Sprint = { Keyboard = "Shift", Gamepad = "L3" },
	Shoulder = { Keyboard = "T", Gamepad = "D-Right" },
	Cursor = { Keyboard = "Alt", Gamepad = "—" },
}

local TOUCH_LAYOUT: { { Command: Command, Label: string, Position: UDim2, Size: number } } = {
	{ Command = "Light", Label = "ATK", Position = UDim2.new(1, -96, 1, -150), Size = 84 },
	{ Command = "Heavy", Label = "HVY", Position = UDim2.new(1, -190, 1, -110), Size = 72 },
	{ Command = "Guard", Label = "GUARD", Position = UDim2.new(1, -110, 1, -250), Size = 72 },
	{ Command = "Roll", Label = "DODGE", Position = UDim2.new(1, -205, 1, -205), Size = 64 },
	{ Command = "WeaponArt", Label = "SKILL", Position = UDim2.new(1, -280, 1, -150), Size = 56 },
	{ Command = "Lock", Label = "LOCK", Position = UDim2.new(1, -70, 1, -330), Size = 52 },
	{ Command = "Heal", Label = "HEAL", Position = UDim2.new(1, -150, 1, -320), Size = 52 },
	{ Command = "Interact", Label = "USE", Position = UDim2.new(1, -230, 1, -290), Size = 52 },
	{ Command = "Swap", Label = "SWAP", Position = UDim2.new(1, -300, 1, -230), Size = 48 },
}

-- Space is the default jump key; the roll binding sinks it so a dodge never also hops.
local ROLL_ACTION = "AsuraRollSinkJump"
local STICK_DEADZONE = 0.18
local STICK_SPEED = 900
local TOUCH_SCALE = 1.4

export type Sender = (action: string, variant: string?, x: number?, z: number?, held: boolean?, time: number?) -> ()

type Fields = {
	State: WorldState,
	Camera: CameraController,
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

local function buildTouchGui(self: InputController)
	local gui = self.TouchGui
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
		local command = entry.Command
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

function Controller.new(state: WorldState, camera: CameraController, send: Sender): InputController
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

	table.insert(self.Connections, UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		local device = deviceFor(inputType)
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
	ContextActionService:BindActionAtPriority(ROLL_ACTION, function(_name: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin and UserInputService:GetFocusedTextBox() == nil then
			self:SetDevice("Keyboard")
			self:Press("Roll")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)
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
	self.TouchGui.Enabled = self.Device == "Touch" and not open
	if open and self.GuardHeld then
		self:Release("Guard")
	end
	if open and self.SprintHeld then
		self:Release("Sprint")
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
	if self.MenuOpen and command ~= "Interact" and command ~= "Cursor" then
		return
	end
	local stamp = now()
	if command == "Light" or command == "Heavy" or command == "WeaponArt" then
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
		local direction = self:EvadeDirection()
		InputBuffer.push(self.Buffer, command, stamp, nil, direction.X, direction.Z)
	elseif command == "Sprint" then
		if self.Device == "Gamepad" then
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
		self.Send("Interact", nil, nil, nil, nil, stamp)
	elseif command == "Cursor" then
		self.CursorFree = not self.CursorFree
	end
end

function Controller.Release(self: InputController, command: Command)
	if command == "Guard" and self.GuardHeld then
		self.GuardHeld = false
		self.Send("Block", nil, nil, nil, false, now())
	elseif command == "Sprint" and self.Device ~= "Gamepad" and self.SprintHeld then
		self.SprintHeld = false
		self.Send("Sprint", nil, nil, nil, false, now())
	end
end

function Controller.Began(self: InputController, input: InputObject, processed: boolean)
	local device = deviceFor(input.UserInputType)
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
	ContextActionService:UnbindAction(ROLL_ACTION)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self.TouchGui:Destroy()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

return Controller

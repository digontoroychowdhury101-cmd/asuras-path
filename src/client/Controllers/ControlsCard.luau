--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ControlsCard
-- Device-aware controls reference. Opens automatically on a fresh spawn, folds into a small
-- "Controls" pill after a while (or once the player starts fighting), and toggles with H on
-- keyboard or a tap on touch. Key names come from InputController.Label,
-- so the card can never drift from the real bindings.
local UserInputService = game:GetService("UserInputService")

local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)

local P = HudKit.Palette
local AUTO_HIDE = 25
local ROW_HEIGHT = 26
local COLUMN_WIDTH = 300

-- Command, description. Order is the order a newcomer needs them.
local ROWS: { { string } } = {
	{ "Light", "Light attack" },
	{ "Heavy", "Heavy attack · Deathblow" },
	{ "Guard", "Guard · tap on impact to deflect" },
	{ "Jump", "Jump · double jump · hold to glide" },
	{ "Dash", "Dash · stamina + brief i-frames" },
	{ "Slide", "Hold slide · + Jump: bullet jump" },
	{ "Aim", "Hold in air to glide (3.5 s)" },
	{ "Lock", "Lock on to a foe" },
	{ "Heal", "Drink from the gourd" },
	{ "Interact", "Interact · rest at altars" },
	{ "Swap", "Swap weapon" },
	{ "WeaponArt", "Weapon art" },
	{ "Sprint", "Toggle sprint" },
}
local TOUCH: { [string]: string } = {
	Light = "ATK", Heavy = "HVY", Guard = "GUARD", Dash = "DASH", Jump = "JUMP", Slide = "SLIDE", Aim = "GLIDE", Lock = "LOCK", Heal = "HEAL",
	Interact = "USE", Swap = "SWAP", WeaponArt = "SKILL", Sprint = "—",
}
local TOGGLE_HINT: { [string]: string } = { Keyboard = "[H]", Gamepad = "", Touch = "" }

local Controller = {}
Controller.__index = Controller

export type ControlsCard = typeof(setmetatable({} :: {
	Input: any,
	Ui: any,
	Card: Frame,
	Pill: TextButton,
	Keys: { [string]: TextLabel },
	Open: boolean,
	Timer: number,
	Cleanup: { () -> () },
}, Controller))

function Controller.new(input: any, ui: any): ControlsCard
	-- Two columns docked bottom-centre: clear of the vitals (top-left), loadout (bottom-left),
	-- objective (top-right) and the touch cluster (bottom-right) even on landscape phones.
	local perColumn = math.ceil(#ROWS / 2)
	local dock = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16) }
	local card = HudKit.panel(ui.Gui, "ControlsCard", { AnchorPoint = dock.AnchorPoint, Position = dock.Position, Size = UDim2.fromOffset(2 * COLUMN_WIDTH + 28, 46 + perColumn * ROW_HEIGHT), Active = true })
	HudKit.make("UIPadding", card, { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 8) })
	HudKit.label(card, "CONTROLS", 18, HudKit.TitleFont, P.Ember, { Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	local keys: { [string]: TextLabel } = {}
	for index, row in ROWS do
		local x = if index > perColumn then COLUMN_WIDTH else 0
		local y = 28 + ((index - 1) % perColumn) * ROW_HEIGHT
		local key = HudKit.label(card, "", 15, Enum.Font.GothamMedium, P.Gold, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(70, ROW_HEIGHT - 4), BackgroundTransparency = 0.6, BackgroundColor3 = Color3.fromRGB(40, 30, 26) })
		HudKit.make("UICorner", key, { CornerRadius = UDim.new(0, 4) })
		local text = HudKit.label(card, row[2], 17, HudKit.BodyFont, P.Ivory, { Position = UDim2.fromOffset(x + 78, y), Size = UDim2.fromOffset(COLUMN_WIDTH - 84, ROW_HEIGHT - 4), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
		HudKit.make("UITextSizeConstraint", text, { MinTextSize = 10, MaxTextSize = 17 })
		keys[row[1]] = key
	end
	local pill = HudKit.make("TextButton", ui.Gui, {
		Name = "ControlsPill", AnchorPoint = dock.AnchorPoint, Position = dock.Position, Size = UDim2.fromOffset(150, 30),
		BackgroundColor3 = P.Ink, BackgroundTransparency = 0.35, Font = HudKit.BodyFont, TextSize = 17, TextColor3 = P.Ivory, Visible = false,
	}) :: TextButton
	HudKit.make("UICorner", pill, { CornerRadius = UDim.new(1, 0) })
	HudKit.make("UIStroke", pill, { Color = P.Edge, Thickness = 1, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

	local self = setmetatable({ Input = input, Ui = ui, Card = card, Pill = pill, Keys = keys, Open = true, Timer = AUTO_HIDE, Cleanup = {} }, Controller)
	table.insert(self.Cleanup, HudKit.bindScale(card, 0.75))
	table.insert(self.Cleanup, HudKit.bindScale(pill, 0.85))

	local previousDevice = input.OnDeviceChanged
	input.OnDeviceChanged = function(device: string)
		if previousDevice then
			previousDevice(device)
		end
		self:Refresh()
	end
	table.insert(self.Cleanup, function()
		input.OnDeviceChanged = previousDevice
	end)
	local toggleConnection = UserInputService.InputBegan:Connect(function(event: InputObject, processed: boolean)
		local key = event.KeyCode
		if not processed and not UserInputService:GetFocusedTextBox() and (key == Enum.KeyCode.H) then
			self:SetOpen(not self.Open)
		end
	end)
	table.insert(self.Cleanup, function()
		toggleConnection:Disconnect()
	end)
	-- Card and pill connections die with the instances in Destroy.
	pill.Activated:Connect(function()
		self:SetOpen(true)
	end)
	card.InputBegan:Connect(function(event: InputObject)
		if event.UserInputType == Enum.UserInputType.Touch or event.UserInputType == Enum.UserInputType.MouseButton1 then
			self:SetOpen(false)
		end
	end)
	self:Refresh()
	return self
end

function Controller.Refresh(self: ControlsCard)
	local device = self.Input.Device
	for command, key in self.Keys do
		key.Text = if device == "Touch" then TOUCH[command] else self.Input:Label(command)
	end
	local hint = TOGGLE_HINT[device] or ""
	self.Pill.Text = if hint ~= "" then hint .. "  Controls" else "Controls"
end

function Controller.SetOpen(self: ControlsCard, open: boolean)
	self.Open = open
	self.Timer = if open then AUTO_HIDE else 0
	HudKit.cue(HudKit.Sounds.Tick, 0.35, if open then 1.2 else 0.9)
end

function Controller.Update(self: ControlsCard, dt: number)
	local blocked = self.Ui.Altar.Visible or self.Ui.DeathShown or self.Ui.BossEntity ~= nil or self.Ui.PrologueActive == true
	if self.Open and self.Timer > 0 and not blocked then
		self.Timer -= dt
		if self.Timer <= 0 then
			self.Open = false
		end
	end
	self.Card.Visible = self.Open and not blocked
	self.Pill.Visible = not self.Open and not blocked
end

function Controller.Destroy(self: ControlsCard)
	for _, cleanup in self.Cleanup do
		cleanup()
	end
	self.Card:Destroy()
	self.Pill:Destroy()
end

return Controller

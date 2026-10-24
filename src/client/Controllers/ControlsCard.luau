--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ControlsCard
-- Device-aware controls reference. A centred overlay over a dim backdrop, in the band HudLayout
-- reserves between the top strip and the action bar, so it never covers the combat row. Opens on
-- a fresh spawn, folds into a "Controls" pill (left utility column, beside Codex) after a while,
-- on any combat input, or with H / B / a tap. Rows, captions and the toggle key come from InputMap.
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")

local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Layout = require(script.Parent:WaitForChild("HudLayout") :: ModuleScript)
local Visibility = require(script.Parent:WaitForChild("HudVisibility") :: ModuleScript)
local InputMap = require(Shared:WaitForChild("Shared"):WaitForChild("InputMap") :: ModuleScript)

local P = HudKit.Palette
local AUTO_HIDE = 25
local ROW_HEIGHT = 26
local COLUMN_WIDTH = 300
local CLOSE_KEYS = { [Enum.KeyCode.ButtonB] = true, [Enum.KeyCode.Backspace] = true }

-- Command, description: every InputMap binding with reference text, in map order.
local ROWS: { { string } } = {}
for _, binding in InputMap.Bindings do
	if binding.Help then
		table.insert(ROWS, { binding.Command, binding.Help })
	end
end
local TOGGLE: { [Enum.KeyCode]: boolean } = {}
for _, name in (InputMap.get("Controls") :: any).Keys do
	TOGGLE[(Enum.KeyCode :: any)[name]] = true
end

local Controller = {}
Controller.__index = Controller

export type ControlsCard = typeof(setmetatable({} :: {
	Input: any, Ui: any, Card: Frame, Backdrop: TextButton, Pill: TextButton, Keys: { [string]: TextLabel },
	Open: boolean, Timer: number, Cleanup: { () -> () },
}, Controller))

function Controller.new(input: any, ui: any): ControlsCard
	local perColumn = math.ceil(#ROWS / 2)
	local size = Vector2.new(2 * COLUMN_WIDTH + 28, 46 + perColumn * ROW_HEIGHT)
	local backdrop = HudKit.make("TextButton", ui.Gui, {
		Name = "ControlsBackdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55,
		Text = "", AutoButtonColor = false, ZIndex = 30, Visible = false,
	}) :: TextButton
	-- Near-opaque: a modal over the backdrop must not let a teaching card's text bleed through (F03).
	local card = HudKit.panel(ui.Gui, "ControlsCard", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y), Active = true, ZIndex = 31, BackgroundTransparency = 0.04 })
	HudKit.make("UIPadding", card, { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 8) })
	HudKit.label(card, "CONTROLS", 18, HudKit.TitleFont, P.Ember, { Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	HudKit.label(card, "", 13, HudKit.BodyFont, P.Muted, { Name = "CloseHint", Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Right })
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
	local slot = Layout.Regions.ControlsPill
	local pill = HudKit.make("TextButton", ui.Gui, {
		Name = "ControlsPill", Position = UDim2.new(slot.At[1], slot.Offset[1], slot.At[2], slot.Offset[2]), Size = UDim2.fromOffset(slot.Size[1], slot.Size[2]),
		BackgroundColor3 = P.Ink, BackgroundTransparency = 0.35, Font = HudKit.BodyFont, TextSize = 17, TextColor3 = P.Ivory, Visible = false,
	}) :: TextButton
	HudKit.make("UICorner", pill, { CornerRadius = UDim.new(1, 0) })
	HudKit.make("UIStroke", pill, { Color = P.Edge, Thickness = 1, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

	local self = setmetatable({ Input = input, Ui = ui, Card = card, Backdrop = backdrop, Pill = pill, Keys = keys, Open = true, Timer = AUTO_HIDE, Cleanup = {} }, Controller)
	-- Size the card into the reserved band for the current viewport.
	local scale = HudKit.make("UIScale", card, {}) :: UIScale
	local function place(v: Vector2)
		local s, rect = Layout.modal(v.X, v.Y, size.X, size.Y, input.Device == "Touch")
		scale.Scale, card.Position = s, UDim2.fromOffset(rect.X + rect.W / 2, rect.Y + rect.H / 2)
	end
	table.insert(self.Cleanup, HudKit.onViewport(place))
	table.insert(self.Cleanup, HudKit.bindScale(pill, slot.Base))
	-- Any combat command folds the reference away so it never sits over a fight. Only a card on
	-- screen folds (F08): the Space or click that skips the prologue closed it before it was seen.
	local previousCommand, previousDevice = input.OnCommand, input.OnDeviceChanged
	input.OnCommand = function(command: string)
		if previousCommand then previousCommand(command) end
		if self.Open and self.Card.Visible and command ~= "Controls" and command ~= "Cursor" and command ~= "Shoulder" then self:SetOpen(false) end
	end
	input.OnDeviceChanged = function(device: string)
		if previousDevice then previousDevice(device) end
		local camera = workspace.CurrentCamera
		if camera then place(camera.ViewportSize) end
		self:Refresh()
	end
	table.insert(self.Cleanup, function() input.OnCommand, input.OnDeviceChanged = previousCommand, previousDevice end)
	local toggleConnection = UserInputService.InputBegan:Connect(function(event: InputObject, processed: boolean)
		local key = event.KeyCode
		if not processed and not UserInputService:GetFocusedTextBox() and TOGGLE[key] and not self.Input.MenuOpen then
			self:SetOpen(not self.Open)
		elseif self.Open and CLOSE_KEYS[key] and self.Card.Visible then
			self:SetOpen(false)
		end
	end)
	table.insert(self.Cleanup, function() toggleConnection:Disconnect() end)
	-- Card, backdrop and pill connections die with the instances in Destroy.
	pill.Activated:Connect(function() self:SetOpen(true) end)
	backdrop.Activated:Connect(function() self:SetOpen(false) end)
	card.InputBegan:Connect(function(event: InputObject)
		if event.UserInputType == Enum.UserInputType.Touch or event.UserInputType == Enum.UserInputType.MouseButton1 then self:SetOpen(false) end
	end)
	self:Refresh()
	return self
end

function Controller.Refresh(self: ControlsCard)
	local device = self.Input.Device
	for command, key in self.Keys do
		key.Text = InputMap.label(command, device)
	end
	self.Pill.Text = if device == "Keyboard" then "[" .. InputMap.label("Controls", device) .. "]  Controls" else "Controls"
	local hint = self.Card:FindFirstChild("CloseHint") :: TextLabel?
	if hint then
		hint.Text = if device == "Keyboard" then "[" .. InputMap.label("Controls", device) .. "] close" elseif device == "Gamepad" then "[B] close" else "tap to close"
	end
end

function Controller.SetOpen(self: ControlsCard, open: boolean)
	self.Open = open
	self.Timer = if open then AUTO_HIDE else 0
	HudKit.cue(HudKit.Sounds.Tick, 0.35, if open then 1.2 else 0.9)
end

function Controller.Update(self: ControlsCard, dt: number)
	-- A window that owns input (the Arsenal opens on its own key) hides the card; F05: it drew over the Arsenal.
	-- F08: so does the prologue's handoff line, which the card's backdrop dimmed and half covered.
	local blocked = not Visibility.of(self.Ui).Guidance or self.Ui.BossEntity ~= nil or self.Input.MenuOpen
		or os.clock() < (self.Ui.HandoffUntil or 0)
	if self.Open and self.Timer > 0 and not blocked then
		self.Timer -= dt
		if self.Timer <= 0 then
			self.Open = false
		end
	end
	self.Card.Visible = self.Open and not blocked
	self.Backdrop.Visible = self.Card.Visible
	self.Pill.Visible = not self.Open and not blocked and self.Input.Device ~= "Touch" -- touch: Respite > Controls
end

function Controller.Destroy(self: ControlsCard)
	for _, cleanup in self.Cleanup do cleanup() end
	self.Card:Destroy(); self.Backdrop:Destroy(); self.Pill:Destroy()
end

return Controller

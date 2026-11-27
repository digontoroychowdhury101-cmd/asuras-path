--!strict
-- Spell slots and Arsenal share a row above the combat buttons on touch.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Spells = require(Shared:WaitForChild("Simulation"):WaitForChild("SpellSchema") :: ModuleScript)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Layout = require(script.Parent:WaitForChild("HudLayout") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local Icons = require(script.Parent:WaitForChild("MoveIcons") :: ModuleScript)

local Hud = {}
local C = require(script.Parent.CombatHudStyle)

local ROW_Y = 46
local SLOT_X, SLOT_SIZE = { 53, 153 }, 76
local MENU_X, MENU_SIZE = 253, 58
local TICKS = 24

export type Card = { Button: TextButton, Name: TextLabel, Timer: TextLabel, Shade: Frame, Segments: { Frame }, Icon: CanvasGroup, Kind: string, Size: number, Key: TextLabel }
export type View = { Root: Frame, Cards: { Card }, Menu: TextButton, MenuKey: TextLabel }

local function badge(holder: Instance, size: number): TextLabel
	local b = HudKit.make("Frame", holder, {
		Name = "Key", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, size * 0.36, 0.5, size * 0.36),
		Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.Raised, BorderSizePixel = 0, ZIndex = 4,
	}) :: Frame
	HudKit.make("UIStroke", b, { Color = C.Edge, Thickness = 1 })
	return HudKit.label(b, "", 12, Enum.Font.GothamBold, C.Ivory, { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
end

local function caption(key: TextLabel, text: string?)
	local badgeFrame = key.Parent :: Frame
	badgeFrame.Visible = text ~= nil and text ~= ""
	key.Text = text or ""
	badgeFrame.Size = UDim2.fromOffset(math.max(20, #key.Text * 7 + 8), 20)
end

local function captionLine(root: Frame, x: number, text: string): TextLabel
	local label = HudKit.label(root, text, 15, HudKit.TitleFont, C.Ivory, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, 88), Size = UDim2.fromOffset(98, 24),
		TextStrokeTransparency = 0.3, TextWrapped = true, TextScaled = true,
	})
	HudKit.make("UITextSizeConstraint", label, { MinTextSize = 11, MaxTextSize = 15 })
	return label
end

local function arsenalSeal(root: Frame): TextButton
	local holder = HudKit.make("Frame", root, {
		Name = "ArsenalSeal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(MENU_X, ROW_Y),
		Size = UDim2.fromOffset(MENU_SIZE, MENU_SIZE), BackgroundTransparency = 1,
	}) :: Frame
	local seal = HudKit.make("Frame", holder, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(42, 42),
		Rotation = 45, BackgroundColor3 = C.Raised, BorderSizePixel = 0,
	}) :: Frame
	local rim = HudKit.make("UIStroke", seal, { Color = C.Edge, Thickness = 2 }) :: UIStroke
	local face = HudKit.make("Frame", seal, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = C.Shade, BorderSizePixel = 0,
	}) :: Frame
	HudKit.make("UIStroke", face, { Color = C.Patina, Thickness = 1 })
	local icon = Icons.draw(holder, "Arsenal", MENU_SIZE)
	icon.Size = UDim2.fromOffset(32, 32)
	local button = HudKit.make("TextButton", holder, {
		Name = "Arsenal", Size = UDim2.fromScale(1, 1), Text = "", BackgroundTransparency = 1,
		AutoButtonColor = false, Selectable = true, ZIndex = 4,
	}) :: TextButton
	local hovered, selected = false, false
	local function focus()
		rim.Color = if hovered or selected then C.Gold else C.Edge
	end
	button.MouseEnter:Connect(function() hovered = true; focus() end)
	button.MouseLeave:Connect(function() hovered = false; focus() end)
	button.SelectionGained:Connect(function() selected = true; focus() end)
	button.SelectionLost:Connect(function() selected = false; focus() end)
	return button
end

function Hud.new(gui: ScreenGui, cast: (number) -> (), menu: () -> ()): View
	local root = HudKit.make("Frame", gui, {
		Name = "QiSpellSlots", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(Layout.SpellSize[1], Layout.SpellSize[2]), BackgroundTransparency = 1,
	}) :: Frame
	root.Destroying:Once(HudKit.bindScale(root, Layout.SpellBase))
	local cards: { Card } = {}
	for slot, x in SLOT_X do
		local button = Sakura.roundButton(root, SLOT_SIZE, UDim2.fromOffset(x, ROW_Y), "")
		button.Name = "SpellSlot" .. slot
		local holder = button.Parent :: Frame
		local inner = HudKit.make("Frame", holder, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(62, 62), BackgroundTransparency = 1,
		})
		HudKit.make("UICorner", inner, { CornerRadius = UDim.new(1, 0) })
		HudKit.make("UIStroke", inner, { Color = C.Gold, Thickness = 1, Transparency = 0.7 })
		local shade = HudKit.make("Frame", holder, {
			Name = "Shade", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Ink, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
		}) :: Frame
		HudKit.make("UICorner", shade, { CornerRadius = UDim.new(1, 0) })
		local key = badge(holder, SLOT_SIZE)
		local timer = HudKit.label(holder, "", 20, Enum.Font.GothamBold, C.Ivory, { Size = UDim2.fromScale(1, 1), ZIndex = 5, TextStrokeTransparency = 0.2 })
		local name = captionLine(root, x, "")
		local segments: { Frame } = {}
		local radius = SLOT_SIZE * 0.5 + 5
		for n = 1, TICKS do
			local angle = math.rad((n - 1) * 360 / TICKS - 90)
			segments[n] = HudKit.make("Frame", root, {
				Name = "Tick", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 5), Rotation = math.deg(angle) + 90,
				Position = UDim2.fromOffset(x + math.cos(angle) * radius, ROW_Y + math.sin(angle) * radius),
				BackgroundColor3 = C.Jade, BorderSizePixel = 0, Visible = false,
			}) :: Frame
		end
		button.Activated:Connect(function() cast(slot) end)
		table.insert(cards, { Button = button, Name = name, Timer = timer, Shade = shade, Segments = segments, Icon = Icons.draw(holder, "Empty", SLOT_SIZE), Kind = "Empty", Size = SLOT_SIZE, Key = key })
	end
	local menuButton = arsenalSeal(root)
	local menuKey = badge(menuButton.Parent :: Frame, MENU_SIZE)
	captionLine(root, MENU_X, "Arsenal")
	menuButton.Activated:Connect(menu)
	return { Root = root, Cards = cards, Menu = menuButton, MenuKey = menuKey }
end

-- `keys` = { spell 1, spell 2, Arsenal } captions for the active device.
function Hud.update(view: View, slots: { string }, cooldowns: { [string]: number }, now: number, qi: number, touch: boolean?, keys: { string }?)
	-- Touch: the top-right corner above the combat buttons (HudLayout.Touch, batch 25); else bottom-right.
	local screen = view.Root.Parent
	if touch and screen and screen:IsA("GuiBase2d") then
		local r = Layout.touch(screen.AbsoluteSize.X, screen.AbsoluteSize.Y).Spells
		view.Root.AnchorPoint, view.Root.Position = Vector2.zero, UDim2.fromOffset(math.floor(r.X), math.floor(r.Y))
	else
		view.Root.AnchorPoint, view.Root.Position = Vector2.new(1, 1), UDim2.new(1, -24, 1, -24)
	end
	local touchLayout = touch == true
	if view.Root:GetAttribute("TouchLayout") ~= touchLayout then
		view.Root:SetAttribute("TouchLayout", touchLayout)
		local menuHolder = view.Menu.Parent :: Frame
		local scale = menuHolder:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", menuHolder)
		scale.Scale = if touchLayout then 1.4 else 1
	end
	local captions = keys or {}
	caption(view.MenuKey, if touch then nil else captions[3])
	for slot, c in view.Cards do
		caption(c.Key, if touch then nil else captions[slot])
		local id = slots[slot]
		local s = if id then Spells.get(id) else nil
		local remaining = if id then math.max(0, (cooldowns[id] or 0) - now) else 0
		local ready = s ~= nil and remaining == 0 and qi >= s.QiCost
		local kind = if s then s.Discipline else "Empty"
		if kind ~= c.Kind then
			c.Icon:Destroy()
			c.Icon, c.Kind = Icons.draw(c.Button.Parent :: Frame, kind, c.Size), kind
		end
		c.Icon.GroupTransparency = if ready then 0 else 0.5
		c.Shade.BackgroundTransparency = if remaining > 0 then 0.35 else 1
		c.Name.Text = if s then (if touch then string.format("%d Qi", s.QiCost) else string.format("%s · %d Qi", s.Name, s.QiCost)) else "Empty slot"
		c.Timer.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
		local lit = if s and remaining > 0 then math.ceil(remaining / s.Cooldown * TICKS) else 0
		for n, f in c.Segments do
			f.Visible = n <= lit
		end
	end
end

return table.freeze(Hud)

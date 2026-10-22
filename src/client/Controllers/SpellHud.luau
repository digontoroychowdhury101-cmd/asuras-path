--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/SpellHud
-- Bottom-right sakura skill cluster: two blossom-framed spell buttons (slot I = 1 / D-Pad Up,
-- slot II = E / D-Pad Down) and a smaller Arsenal button, each with a key badge. A ring of petal
-- ticks drains with the cooldown; the disc dims while the spell is unaffordable. Each button shows
-- a drawn picture of its spell school (MoveIcons). On touch the cluster lifts above the combat buttons.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Spells = require(Shared:WaitForChild("Simulation"):WaitForChild("SpellSchema") :: ModuleScript)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Layout = require(script.Parent:WaitForChild("HudLayout") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local Icons = require(script.Parent:WaitForChild("MoveIcons") :: ModuleScript)

local Hud = {}
local C = Sakura.Colors

-- Customization ------------------------------------------------------------------------------
local CLUSTER = Vector2.new(260, 190)
-- Badge captions are filled each frame from InputMap via Hud.update (hidden on touch).
local SLOTS = { { Pos = Vector2.new(64, 118), Size = 78 }, { Pos = Vector2.new(160, 64), Size = 78 } }
local MENU = { Pos = Vector2.new(214, 150), Size = 52 }
local TICKS = 24

export type Card = { Button: TextButton, Name: TextLabel, Timer: TextLabel, Shade: Frame, Segments: { Frame }, Icon: CanvasGroup, Kind: string, Size: number, Key: TextLabel }
export type View = { Root: Frame, Cards: { Card }, Menu: TextButton, MenuKey: TextLabel }

local function badge(holder: Instance, size: number): TextLabel
	local b = HudKit.make("Frame", holder, {
		Name = "Key", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, size * 0.36, 0.5, size * 0.36),
		Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.Ink, BorderSizePixel = 0, ZIndex = 4,
	}) :: Frame
	HudKit.make("UICorner", b, { CornerRadius = UDim.new(1, 0) })
	HudKit.make("UIStroke", b, { Color = C.Sakura, Thickness = 1 })
	return HudKit.label(b, "", 12, Enum.Font.GothamBold, C.Blossom, { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
end

local function caption(key: TextLabel, text: string?)
	local badgeFrame = key.Parent :: Frame
	badgeFrame.Visible = text ~= nil and text ~= ""
	key.Text = text or ""
	badgeFrame.Size = UDim2.fromOffset(math.max(20, #key.Text * 7 + 8), 20)
end

function Hud.new(gui: ScreenGui, cast: (number) -> (), menu: () -> ()): View
	local root = HudKit.make("Frame", gui, {
		Name = "QiSpellSlots", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(CLUSTER.X, CLUSTER.Y), BackgroundTransparency = 1,
	}) :: Frame
	root.Destroying:Once(HudKit.bindScale(root, 0.85))
	local cards: { Card } = {}
	for slot, layout in SLOTS do
		local at = UDim2.fromOffset(layout.Pos.X, layout.Pos.Y)
		local button = Sakura.roundButton(root, layout.Size, at, "")
		local holder = button.Parent :: Frame
		local shade = HudKit.make("Frame", holder, {
			Name = "Shade", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Ink, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
		}) :: Frame
		HudKit.make("UICorner", shade, { CornerRadius = UDim.new(1, 0) })
		local key = badge(holder, layout.Size)
		local timer = HudKit.label(holder, "", 20, Enum.Font.GothamBold, C.Ivory, { Size = UDim2.fromScale(1, 1), ZIndex = 5, TextStrokeTransparency = 0.2 })
		local name = HudKit.label(root, "", 12, Enum.Font.Garamond, C.Blossom, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(layout.Pos.X, layout.Pos.Y + layout.Size * 0.62),
			Size = UDim2.fromOffset(120, 16), TextStrokeTransparency = 0.4,
		})
		local segments: { Frame } = {}
		local radius = layout.Size * 0.5 + 15
		for n = 1, TICKS do
			local angle = math.rad((n - 1) * 360 / TICKS - 90)
			segments[n] = HudKit.make("Frame", root, {
				Name = "Tick", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(3, 7), Rotation = math.deg(angle) + 90,
				Position = UDim2.fromOffset(layout.Pos.X + math.cos(angle) * radius, layout.Pos.Y + math.sin(angle) * radius),
				BackgroundColor3 = C.Sakura, BorderSizePixel = 0, Visible = false,
			}) :: Frame
		end
		button.Activated:Connect(function() cast(slot) end)
		table.insert(cards, { Button = button, Name = name, Timer = timer, Shade = shade, Segments = segments, Icon = Icons.draw(holder, "Empty", layout.Size), Kind = "Empty", Size = layout.Size, Key = key })
	end
	local menuButton = Sakura.roundButton(root, MENU.Size, UDim2.fromOffset(MENU.Pos.X, MENU.Pos.Y), "")
	Icons.draw(menuButton.Parent :: Frame, "Arsenal", MENU.Size)
	local menuKey = badge(menuButton.Parent :: Frame, MENU.Size)
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
	local captions = keys or {}
	caption(view.MenuKey, captions[3])
	for slot, c in view.Cards do
		caption(c.Key, captions[slot])
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
		c.Name.Text = if s then string.format("%s · %d Qi", s.Name, s.QiCost) else "Empty slot"
		c.Timer.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
		local lit = if s and remaining > 0 then math.ceil(remaining / s.Cooldown * TICKS) else 0
		for n, f in c.Segments do
			f.Visible = n <= lit
		end
	end
end

return table.freeze(Hud)

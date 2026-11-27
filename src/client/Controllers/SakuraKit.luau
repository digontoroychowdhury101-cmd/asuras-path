--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/SakuraKit
-- Drawn HUD fittings shared by navigation, the spell tray and legacy segmented meters.
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)

local Kit = {}
local make = HudKit.make
local P = HudKit.Palette

Kit.Colors = table.freeze({
	Ink = P.Ink, Plum = Color3.fromRGB(34, 37, 30), Track = Color3.fromRGB(44, 46, 36),
	Sakura = P.Jade, Blossom = P.Ivory, Rose = P.Edge,
	Crimson = P.Blood, Gold = P.Gold, Ivory = P.Ivory,
	Qi = P.Jade, Stamina = Color3.fromRGB(205, 191, 144),
	BloodPetal = Color3.fromRGB(122, 10, 20), EmberPetal = Color3.fromRGB(176, 28, 36),
})
local C = Kit.Colors

export type Bar = { Segments: { Frame }, Count: number }

local function round(gui: GuiObject)
	make("UICorner", gui, { CornerRadius = UDim.new(1, 0) })
end

-- The seal's cross fixes the reading point on the compass line.
function Kit.crest(parent: Instance, size: number, position: UDim2, tint: Color3?): Frame
	local holder = make("Frame", parent, {
		Name = "Crest", AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
	}) :: Frame
	local thin = math.max(1, size * 0.07)
	for _, rotation in { 0, 90 } do -- blade cross reaching past the seal
		make("Frame", holder, {
			Name = "Blade", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(thin, size),
			Rotation = rotation, BackgroundColor3 = C.Gold, BackgroundTransparency = 0.15, BorderSizePixel = 0,
		})
	end
	local outer = make("Frame", holder, {
		Name = "Seal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size * 0.6, size * 0.6),
		Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}) :: Frame
	make("UIGradient", outer, { Rotation = 90, Color = ColorSequence.new(C.Plum, C.Ink) })
	make("UIStroke", outer, { Color = C.Gold, Thickness = if size > 30 then 1.5 else 1, Transparency = 0.1 })
	local inner = make("Frame", outer, {
		Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.55, 0.55),
		BackgroundColor3 = tint or C.Crimson, BorderSizePixel = 0,
	}) :: Frame
	make("UIStroke", inner, { Color = C.Ink, Thickness = 1 })
	make("Frame", inner, {
		Name = "Pip", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.36),
		BackgroundColor3 = C.Gold, BorderSizePixel = 0,
	})
	return holder
end

function Kit.medallion(parent: Instance, size: number, position: UDim2, withCrest: boolean?, studs: { number }?): Frame
	local disc = make("Frame", parent, {
		Name = "Medallion", AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = C.Plum, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}) :: Frame
	round(disc)
	make("UIGradient", disc, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(166, 168, 155)) })
	make("UIStroke", disc, { Color = C.Rose, Thickness = if size >= 100 then 2 else 1, Transparency = 0.05 })
	local inner = make("Frame", disc, {
		Name = "Inner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1,
	}) :: Frame
	round(inner)
	make("UIStroke", inner, { Color = C.Gold, Thickness = 1, Transparency = 0.7 })
	if withCrest then
		Kit.crest(disc, size * 0.62, UDim2.fromScale(0.5, 0.5))
	end
	local list: { number } = studs or {}
	for _, degrees in list do
		local a = math.rad(degrees - 90)
		Kit.crest(disc, math.max(12, size * 0.2), UDim2.new(0.5, math.cos(a) * size * 0.5, 0.5, math.sin(a) * size * 0.5))
	end
	return disc
end

function Kit.diamond(parent: Instance, size: number, position: UDim2, fill: Color3, edge: Color3?): Frame
	local d = make("Frame", parent, {
		Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size),
		Rotation = 45, BackgroundColor3 = fill, BorderSizePixel = 0, ZIndex = 4,
	}) :: Frame
	make("UIStroke", d, { Color = edge or C.Ink, Thickness = 1.5 })
	return d
end

-- Horizontal segmented bar: segments fill left-to-right so Interface setArc can colour them.
function Kit.bar(parent: Instance, name: string, position: Vector2, width: number, height: number, count: number, caps: boolean): (Frame, Bar)
	local frame = make("Frame", parent, {
		Name = name, Position = UDim2.fromOffset(position.X, position.Y), Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, BorderSizePixel = 0,
	}) :: Frame
	make("UIStroke", frame, { Color = C.Rose, Thickness = 1, Transparency = 0.25 })
	local segments: { Frame } = {}
	local step = (width - 2) / count
	for i = 1, count do
		segments[i] = make("Frame", frame, {
			Name = "Segment" .. i, Position = UDim2.fromOffset(1 + (i - 1) * step, 1), Size = UDim2.new(0, math.ceil(step), 1, -2),
			BackgroundColor3 = C.Track, BorderSizePixel = 0,
		}) :: Frame
	end
	local gloss = make("Frame", frame, {
		Name = "Gloss", Size = UDim2.new(1, 0, 0.32, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.92, BorderSizePixel = 0, ZIndex = 3,
	}) :: Frame
	make("UIGradient", gloss, { Rotation = 90, Transparency = NumberSequence.new(0.2, 1) })
	if caps then
		Kit.diamond(frame, height * 0.9, UDim2.new(0, 0, 0.5, 0), C.Gold)
		Kit.diamond(frame, height * 0.9, UDim2.new(1, 0, 0.5, 0), C.Gold)
	end
	return frame, { Segments = segments, Count = count }
end

function Kit.roundButton(parent: Instance, size: number, position: UDim2, glyph: string): TextButton
	local holder = make("Frame", parent, {
		Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
	}) :: Frame
	local disc = make("Frame", holder, {
		Name = "Disc", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}) :: Frame
	round(disc)
	make("UIGradient", disc, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(52, 53, 42), C.Ink) })
	local edge = make("UIStroke", disc, { Color = C.Rose, Thickness = if size < 40 then 1 else 2 }) :: UIStroke
	local button = make("TextButton", holder, {
		Name = "Button", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, AutoButtonColor = false, BorderSizePixel = 0, Selectable = true,
		Text = glyph, Font = Enum.Font.Antique, TextSize = size * 0.42, TextColor3 = C.Blossom, ZIndex = 2,
	}) :: TextButton
	round(button)
	local hover, selected = false, false
	local function highlight()
		edge.Color = if hover or selected then C.Gold else C.Rose
		edge.Thickness = if hover or selected or size >= 40 then 2 else 1
	end
	button.MouseEnter:Connect(function() hover = true; highlight() end)
	button.MouseLeave:Connect(function() hover = false; highlight() end)
	button.SelectionGained:Connect(function() selected = true; highlight() end)
	button.SelectionLost:Connect(function() selected = false; highlight() end)
	return button
end

return table.freeze(Kit)

--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/SakuraKit
-- Sakura HUD primitives, built purely from instances (no uploaded art): martial diamond-seal
-- crests, ringed medallions, diamond caps, segmented stat bars compatible with the Interface
-- `Arc` contract ({ Segments, Count }) and round crest-backed buttons.
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)

local Kit = {}
local make = HudKit.make

-- Customization ------------------------------------------------------------------------------
Kit.Colors = table.freeze({
	Ink = Color3.fromRGB(22, 10, 20), Plum = Color3.fromRGB(48, 18, 42), Track = Color3.fromRGB(40, 20, 34),
	Sakura = Color3.fromRGB(247, 168, 200), Blossom = Color3.fromRGB(255, 218, 232), Rose = Color3.fromRGB(214, 84, 140),
	Crimson = Color3.fromRGB(196, 22, 38), Gold = Color3.fromRGB(236, 196, 120), Ivory = Color3.fromRGB(255, 240, 246),
	Qi = Color3.fromRGB(196, 120, 236), Stamina = Color3.fromRGB(255, 196, 214),
	-- Grimdark drift: blood-red screen petals (decoration only; warnings use Crimson + shape).
	BloodPetal = Color3.fromRGB(122, 10, 20), EmberPetal = Color3.fromRGB(176, 28, 36),
})
local C = Kit.Colors

export type Bar = { Segments: { Frame }, Count: number }

local function round(gui: GuiObject)
	make("UICorner", gui, { CornerRadius = UDim.new(1, 0) })
end

-- Martial seal: a crossed blade star behind a lacquered outer diamond, a crimson inner diamond
-- and a gold centre pip. Replaces the old five-petal blossom wherever a motif is drawn.
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
	make("UIGradient", outer, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 16, 22), C.Ink) })
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

-- Plum disc, sakura outer ring, faint gold inner ring, optional centre crest and rim studs.
function Kit.medallion(parent: Instance, size: number, position: UDim2, withCrest: boolean?, studs: { number }?): Frame
	local disc = make("Frame", parent, {
		Name = "Medallion", AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = C.Plum, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}) :: Frame
	round(disc)
	make("UIGradient", disc, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(120, 60, 100), C.Ink) })
	make("UIStroke", disc, { Color = C.Sakura, Thickness = math.max(2, size / 36), Transparency = 0.05 })
	local inner = make("Frame", disc, {
		Name = "Inner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1,
	}) :: Frame
	round(inner)
	make("UIStroke", inner, { Color = C.Gold, Thickness = 1, Transparency = 0.5 })
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
	local gloss = make("Frame", frame, { -- lacquer highlight across the upper half
		Name = "Gloss", Size = UDim2.new(1, 0, 0.45, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 3,
	}) :: Frame
	make("UIGradient", gloss, { Rotation = 90, Transparency = NumberSequence.new(0.2, 1) })
	if caps then
		Kit.diamond(frame, height * 0.9, UDim2.new(0, 0, 0.5, 0), C.Sakura)
		Kit.diamond(frame, height * 0.9, UDim2.new(1, 0, 0.5, 0), C.Sakura)
	end
	return frame, { Segments = segments, Count = count }
end

-- Round skill-style button: plum disc ringed in sakura over a faded seal crest.
function Kit.roundButton(parent: Instance, size: number, position: UDim2, glyph: string): TextButton
	local holder = make("Frame", parent, {
		Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
	}) :: Frame
	local back = Kit.crest(holder, size * 1.32, UDim2.fromScale(0.5, 0.5), C.Rose)
	local seal = back:FindFirstChild("Seal") :: Frame?
	if seal then seal.BackgroundTransparency = 0.35 end
	-- The lacquer disc sits behind a clear button so its gradient never tints the glyph.
	local disc = make("Frame", holder, {
		Name = "Disc", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}) :: Frame
	round(disc)
	make("UIGradient", disc, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 80, 130), Color3.fromRGB(58, 24, 50)) })
	make("UIStroke", disc, { Color = C.Sakura, Thickness = 2 })
	local button = make("TextButton", holder, {
		Name = "Button", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, AutoButtonColor = false, BorderSizePixel = 0,
		Text = glyph, Font = Enum.Font.Antique, TextSize = size * 0.42, TextColor3 = C.Blossom, ZIndex = 2,
	}) :: TextButton
	round(button)
	return button
end

return table.freeze(Kit)

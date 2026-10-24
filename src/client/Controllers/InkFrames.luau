--!strict
-- Single-beat impact frames that open the Blazing Sun blast: the red ink splatter and the white shard
-- burst. Each lasts two to four frames and re-cuts every frame like hand-drawn smears. Caster only.
local Kit = require(script.Parent.SkillKit)
local Manga = require(script.Parent.MangaFx)
local Ink = {}

local rgb = Color3.fromRGB
local WHITE, INK = Color3.new(1, 1, 1), rgb(6, 6, 8)

local function full(gui: ScreenGui, color: Color3): Frame
	local back = Manga.box(gui, color)
	back.Position, back.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	return back
end

-- A thin stroke from `from` at `angle` (radians), `length` px long.
local function stroke(f: Frame, from: Vector2, angle: number, length: number, width: number)
	local mid = from + Vector2.new(math.cos(angle), math.sin(angle)) * length / 2
	f.Position, f.Size, f.Rotation = UDim2.fromOffset(mid.X, mid.Y), UDim2.fromOffset(length, width), math.deg(angle)
end

Ink.full, Ink.stroke = full, stroke -- shared with NovaInk

-- Black frame splashed with blood-red ink around a white-hot star.
function Ink.splatter(trove: Kit.Trove, seconds: number)
	local gui, size = Manga.screen(trove, 62)
	if not gui then return end
	local back = full(gui, INK)
	local drops: { Frame } = {}
	for n = 1, 80 do drops[n] = Manga.blob(back, rgb(222, 18, 10)) end
	local rays: { Frame } = {}
	for n = 1, 24 do
		rays[n] = Manga.box(back, if n % 3 == 0 then WHITE else rgb(255, 236, 90))
		rays[n].ZIndex = 4
	end
	local star = Manga.blob(back, rgb(255, 250, 225))
	star.ZIndex = 5
	Manga.animate(trove, gui, seconds, function()
		local c = Vector2.new(size.X * 0.5, size.Y * 0.47)
		for _, f in drops do
			local a, r = math.random() * math.pi * 2, size.Y * (0.05 + 0.6 * math.random() ^ 1.3)
			local d = size.Y * (0.08 + math.random() * 0.3) * (1.1 - r / (size.Y * 0.75))
			f.Position, f.Size = UDim2.fromOffset(c.X + math.cos(a) * r * 1.4, c.Y + math.sin(a) * r), UDim2.fromOffset(d * (1 + math.random()), d)
			f.Rotation = math.random() * 180
		end
		for n, f in rays do stroke(f, c, n / #rays * math.pi * 2 + math.random() * 0.3, size.Y * (0.14 + math.random() * 0.3), 4 + math.random() * 12) end
		star.Position, star.Size = UDim2.fromOffset(c.X, c.Y), UDim2.fromOffset(size.Y * 0.2, size.Y * 0.2)
	end)
end

-- Warm white flash of yellow, white and red sticks flying from the centre, a flare line through it.
function Ink.shards(trove: Kit.Trove, seconds: number)
	local gui, size = Manga.screen(trove, 62)
	if not gui then return end
	-- A hazy, washed-out flash the world still shows through, with a soft white heart.
	local back = full(gui, rgb(250, 232, 214))
	back.BackgroundTransparency = 0.3
	for k, spec in { { 1.3, 0.75 }, { 0.95, 0.5 }, { 0.6, 0.15 } } do
		local glow = Manga.blob(back, WHITE)
		glow.Position, glow.Size, glow.BackgroundTransparency, glow.ZIndex = UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(size.Y * spec[1], size.Y * spec[1]), spec[2], 1 + k
	end
	local colors = { WHITE, rgb(255, 236, 90), rgb(255, 176, 40), rgb(225, 40, 20) }
	local sticks: { Frame } = {}
	for n = 1, 48 do
		sticks[n] = Manga.box(back, colors[(n % #colors) + 1])
		sticks[n].ZIndex = 5
	end
	local flare = Manga.box(back, WHITE)
	flare.Position, flare.Size, flare.ZIndex = UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(size.X * 0.008, size.Y), 4
	Manga.animate(trove, gui, seconds, function()
		local c = size / 2
		for _, f in sticks do
			local a = math.random() * math.pi * 2
			local from = c + Vector2.new(math.cos(a), math.sin(a)) * size.Y * math.random() * 0.12
			stroke(f, from, a + (math.random() - 0.5) * 0.6, size.Y * (0.08 + math.random() * 0.4), 4 + math.random() * 9)
		end
	end)
end

return table.freeze(Ink)

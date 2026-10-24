--!strict
-- The Supernova's three ink frames, back to back after the detonation: the black frame with a white
-- hatched dome over a two-lobed ink core, the inverted white frame with a hatched black blob and a
-- white radial burst, and the white frame torn by black ink streaks. Lines re-cut every frame like
-- smear animation. Caster only; reduced flashes shortens every beat.
local Kit = require(script.Parent.SkillKit)
local Manga = require(script.Parent.MangaFx)
local Ink = require(script.Parent.InkFrames)
local Nova = {}

local rgb = Color3.fromRGB
local WHITE, INK = Color3.new(1, 1, 1), rgb(6, 6, 8)

-- Black frame: a thick white dome of vertical ink hatching arching over a two-lobed black core that
-- sits on a hatched white ground line, white rain from the top edge, needle sparkles.
function Nova.dome(trove: Kit.Trove, seconds: number)
	local gui, size = Manga.screen(trove, 62)
	if not gui then return end
	local back = Manga.box(gui, INK)
	back.Position, back.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	local hatch: { Frame } = {}
	for n = 1, 320 do hatch[n] = Manga.box(back, WHITE) end
	local inner: { Frame } = {}
	for n = 1, 70 do
		inner[n] = Manga.box(back, INK)
		inner[n].ZIndex = 4
	end
	local arch = Manga.blob(back, WHITE) -- solid white under the hatching: the dome reads as one bright mass
	arch.ZIndex = 1
	local lobes = { Manga.blob(back, INK), Manga.blob(back, INK) }
	for _, l in lobes do l.ZIndex = 3 end
	local ground = Manga.box(back, WHITE)
	ground.AnchorPoint, ground.ZIndex = Vector2.new(0.5, 0), 2
	for n, at in { Vector2.new(0.24, 0.24), Vector2.new(0.66, 0.16), Vector2.new(0.86, 0.42), Vector2.new(0.12, 0.6) } do
		Manga.sparkle(back, at * size, size.Y * (0.22 + 0.06 * n))
	end
	Manga.animate(trove, gui, seconds, function(t: number)
		local grow = 1 + t * 1.5
		local c = Vector2.new(size.X * 0.5, size.Y * 0.6)
		local rx, ry = size.X * 0.23 * grow, size.Y * 0.4 * grow
		arch.Position, arch.Size = UDim2.fromOffset(c.X, c.Y), UDim2.fromOffset(rx * 2.15, ry * 1.75)
		for i, l in lobes do
			l.Position = UDim2.fromOffset(c.X + (if i == 1 then -1 else 1) * rx * 0.36, c.Y + ry * 0.08)
			l.Size = UDim2.fromOffset(rx * 0.95, ry * 1.05)
		end
		ground.Position, ground.Size = UDim2.fromOffset(c.X, c.Y + ry * 0.5), UDim2.fromOffset(size.X, size.Y)
		for n, f in inner do -- the core's edge hatched up into the white, so the two read as one ink mass
			local i = if n % 2 == 0 then 1 else -1
			local a = math.pi + (math.random() * 0.9 + 0.05) * math.pi
			local len = size.Y * (0.03 + math.random() * 0.08)
			f.Position = UDim2.fromOffset(c.X + i * rx * 0.36 + math.cos(a) * rx * 0.47, c.Y + ry * 0.08 + math.sin(a) * ry * 0.52 - len * 0.4)
			f.Size = UDim2.fromOffset(1 + math.random() * 3, len)
		end
		for n, f in hatch do
			if n <= 240 then -- the arch's fuzzy rim: strokes poking out of it, longest at the crown
				local a = math.pi * 0.92 + n / 240 * math.pi * 1.16
				local crown = math.max(0, -math.sin(a))
				local len = size.Y * (0.05 + math.random() * 0.1 + crown * 0.1)
				f.Position = UDim2.fromOffset(c.X + math.cos(a) * rx * 1.06 + (math.random() - 0.5) * 12, c.Y + math.sin(a) * ry * 0.86 - len * 0.2)
				f.Size = UDim2.fromOffset(2 + math.random() * 5, len)
			elseif n <= 280 then -- rain from the top edge
				f.Position, f.Size = UDim2.fromOffset(math.random() * size.X, math.random() * size.Y * 0.25), UDim2.fromOffset(1 + math.random() * 2, size.Y * (0.08 + math.random() * 0.35))
			else -- hatching up from the ground line
				f.Position, f.Size = UDim2.fromOffset(math.random() * size.X, c.Y + ry * 0.5 - size.Y * 0.03), UDim2.fromOffset(1 + math.random() * 3, size.Y * (0.03 + math.random() * 0.09))
			end
		end
	end)
end

-- White frame torn by black vertical ink streaks (the column's first instant).
function Nova.streaks(trove: Kit.Trove, seconds: number)
	local gui, size = Manga.screen(trove, 62)
	if not gui then return end
	local back = Manga.box(gui, WHITE)
	back.Position, back.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	-- Each tear is three stacked strokes of different widths and lengths: a ragged ink edge.
	local streaks: { Frame } = {}
	for n = 1, 96 do streaks[n] = Manga.box(back, if n % 7 == 0 then Color3.fromRGB(110, 110, 115) else INK) end
	Manga.animate(trove, gui, seconds, function()
		for n = 1, #streaks, 3 do
			local x = size.X * (0.5 + (math.random() - 0.5) * (if math.random() < 0.65 then 0.32 else 0.95))
			local y, width, tilt = size.Y * (0.25 + math.random() * 0.55), 4 + math.random() ^ 1.6 * 70, (math.random() - 0.5) * 14
			for k = 0, 2 do
				local f = streaks[n + k]
				f.Position = UDim2.fromOffset(x + (math.random() - 0.5) * width * 0.6, y + (math.random() - 0.5) * size.Y * 0.3)
				f.Size, f.Rotation = UDim2.fromOffset(width * (0.35 + math.random() * 0.65), size.Y * (0.2 + math.random() * 0.7)), tilt + (math.random() - 0.5) * 6
			end
		end
	end)
end

-- White frame: a black hatched blob on hatched ground with white rays bursting from its heart.
function Nova.burst(trove: Kit.Trove, seconds: number)
	local gui, size = Manga.screen(trove, 62)
	if not gui then return end
	local back = Ink.full(gui, WHITE)
	local core = Manga.blob(back, INK)
	core.ZIndex = 2
	local fringe: { Frame } = {}
	for n = 1, 230 do
		fringe[n] = Manga.box(back, INK)
		fringe[n].ZIndex = 2
	end
	local rays: { Frame } = {}
	for n = 1, 44 do
		rays[n] = Manga.box(back, WHITE)
		rays[n].ZIndex = 4
	end
	for n = 1, 3 do Manga.sparkle(back, Vector2.new(size.X * (0.1 + 0.3 * n), size.Y * (0.1 + 0.12 * (n % 2))), size.Y * 0.4, rgb(70, 70, 75)) end
	Manga.animate(trove, gui, seconds, function()
		local c = Vector2.new(size.X * 0.5, size.Y * 0.5)
		local rx, ry = size.Y * 0.44, size.Y * 0.4 -- a round blob, not a pill
		core.Position, core.Size = UDim2.fromOffset(c.X, c.Y), UDim2.fromOffset(rx * 2, ry * 2)
		for n, f in fringe do
			if n <= 150 then -- hatched rim of the blob
				local a = n / 150 * math.pi * 2
				f.Position = UDim2.fromOffset(c.X + math.cos(a) * rx * 0.97 + (math.random() - 0.5) * 8, c.Y + math.sin(a) * ry * 0.97)
				f.Size = UDim2.fromOffset(2 + math.random() * 4, size.Y * (0.05 + math.random() * 0.14))
			else -- hatched ground band
				f.Position, f.Size = UDim2.fromOffset(math.random() * size.X, size.Y * 0.92), UDim2.fromOffset(2 + math.random() * 4, size.Y * (0.06 + math.random() * 0.16))
			end
		end
		local hub = c + Vector2.new(size.X * 0.03, size.Y * 0.16)
		for n, f in rays do
			Ink.stroke(f, hub, n / #rays * math.pi * 2 + (math.random() - 0.5) * 0.25, size.Y * (0.1 + math.random() * 0.36), 1 + math.random() * 4)
		end
	end)
end

return table.freeze(Nova)

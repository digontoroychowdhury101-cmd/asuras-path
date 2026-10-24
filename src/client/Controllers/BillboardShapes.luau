--!strict
-- The Supernova's one-off billboard shapes: the merged five-lobed detonation blob, the hollow gold
-- 4-point stars by the planet and the vertical lens-flare line. Built on BillboardFx's helpers.
local Kit = require(script.Parent.SkillKit)
local Bb = require(script.Parent.BillboardFx)
local Shapes = {}

local WHITE = Color3.new(1, 1, 1)

-- Detonation blob: a white core with `lobes` bulges under a soft glowing rim, swelling from 40% to
-- `studs` over `grow` seconds and then fading over `fade` (the reference's white star-burst).
function Shapes.blob(trove: Kit.Trove, adornee: Instance, glow: Color3, studs: number, lobes: number, grow: number, fade: number): BillboardGui
	local gui = Bb.board(trove, adornee, studs * 0.4)
	-- One CanvasGroup so the lobes fade as a single merged shape, never as overlapping circles.
	local group = Instance.new("CanvasGroup")
	group.Size, group.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	group.Parent = gui
	local function puff(x: number, y: number, d: number)
		for _, layer in { { glow, 1.3, 0.45, 1 }, { WHITE, 1, 0, 2 } } do
			local f = Bb.frame(group, layer[1], UDim2.fromScale(d * layer[2], d * layer[2]), 0, layer[4])
			f.Position, f.BackgroundTransparency = UDim2.fromScale(x, y), layer[3]
			Bb.round(f)
		end
	end
	puff(0.5, 0.5, 0.48)
	local spin = math.random() * math.pi * 2
	for n = 1, lobes do
		local a = spin + n / lobes * math.pi * 2
		puff(0.5 + math.cos(a) * 0.25, 0.5 + math.sin(a) * 0.25, 0.24 + math.random() * 0.1)
	end
	Kit.tween(trove, gui, grow, { Size = UDim2.fromScale(studs, studs) }, Enum.EasingStyle.Quart)
	Kit.after(trove, grow, function() Kit.tween(trove, group, fade, { GroupTransparency = 1 }) end)
	return gui
end

-- A hollow 4-point star outline (the reference's gold stars hanging by the planet), fading in and out.
function Shapes.star(trove: Kit.Trove, adornee: Instance, color: Color3, studs: number, seconds: number): BillboardGui
	local gui = Bb.board(trove, adornee, studs)
	local group = Instance.new("CanvasGroup")
	group.Size, group.BackgroundTransparency, group.GroupTransparency = UDim2.fromScale(1, 1), 1, 1
	group.Parent = gui
	local tips = { Vector2.new(0.5, 0), Vector2.new(1, 0.5), Vector2.new(0.5, 1), Vector2.new(0, 0.5) }
	local points: { Vector2 } = {}
	for n, tip in tips do
		local nxt = tips[(n % 4) + 1]
		table.insert(points, tip)
		table.insert(points, Vector2.new(0.5, 0.5) + ((tip + nxt) / 2 - Vector2.new(0.5, 0.5)) * 0.3)
	end
	for n, a in points do
		local b = points[(n % #points) + 1]
		local mid, delta = (a + b) / 2, b - a
		local f = Bb.frame(group, color, UDim2.fromScale(delta.Magnitude + 0.02, 0.03), math.deg(math.atan2(delta.Y, delta.X)))
		f.Position = UDim2.fromScale(mid.X, mid.Y)
	end
	Kit.tween(trove, group, seconds * 0.25, { GroupTransparency = 0.25 })
	Kit.after(trove, seconds * 0.7, function() Kit.tween(trove, group, seconds * 0.3, { GroupTransparency = 1 }) end)
	return gui
end

-- A thin vertical flare line through `adornee` (lens streak).
function Shapes.line(trove: Kit.Trove, adornee: Instance, color: Color3, studs: number, seconds: number)
	local gui = Bb.board(trove, adornee, studs)
	local f = Bb.frame(gui, WHITE, UDim2.fromScale(0.012, 1))
	local g = Instance.new("UIGradient")
	g.Transparency, g.Color, g.Parent = Bb.seq(0, 1, 0.5, 0, 1, 1), ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, color) }), f
	Kit.tween(trove, f, seconds, { Size = UDim2.fromScale(0.004, 1.2), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

return table.freeze(Shapes)

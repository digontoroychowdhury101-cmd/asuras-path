--!strict
-- Camera-facing 2D shapes drawn in the world with BillboardGuis: glowing rings, 4-point lens-flare
-- sparkles, jagged starbursts and spinning crescent arcs (BillboardShapes has the rest). Sizes are
-- in studs; stroke widths follow the on-screen size so a ring stays a ring at any distance.
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.SkillKit)
local Bb = {}

local WHITE = Color3.new(1, 1, 1)
local function seq(...: number): NumberSequence
	local keys, args = {}, { ... }
	for n = 1, #args, 2 do table.insert(keys, NumberSequenceKeypoint.new(args[n], args[n + 1])) end
	return NumberSequence.new(keys)
end
local TIP = seq(0, 1, 0.5, 0, 1, 1) -- transparent ends, solid middle

-- An invisible anchored point to hang boards on (world position, not a character limb).
function Bb.anchor(parent: Instance, at: Vector3): BasePart
	local p = Kit.part(parent, "BoardAnchor", WHITE, Vector3.one * 0.1, CFrame.new(at))
	p.Transparency = 1
	return p
end

function Bb.board(trove: Kit.Trove, adornee: Instance, studs: number): BillboardGui
	local gui = Kit.add(trove, Instance.new("BillboardGui"))
	gui.Adornee, gui.Size, gui.LightInfluence, gui.AlwaysOnTop = adornee, UDim2.fromScale(studs, studs), 0, false
	gui.MaxDistance, gui.ZIndexBehavior, gui.Brightness = 2000, Enum.ZIndexBehavior.Sibling, 2 -- glows like the clip's light
	gui.Parent = adornee
	return gui
end

local function frame(parent: Instance, color: Color3, size: UDim2, rotation: number?, z: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint, f.Position, f.Size, f.BackgroundColor3 = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), size, color
	f.BorderSizePixel, f.Rotation, f.ZIndex = 0, rotation or 0, z or 1
	f.Parent = parent
	return f
end

local function round(f: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius, c.Parent = UDim.new(0.5, 0), f
end

-- Hollow circle with a stroke `ratio` of its on-screen width; returns the stroke to animate.
local function circle(gui: BillboardGui, color: Color3, scale: number, ratio: number, transparency: number, trove: Kit.Trove): UIStroke
	local f = frame(gui, color, UDim2.fromScale(scale, scale))
	f.BackgroundTransparency = 1
	round(f)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Transparency, stroke.Parent = color, transparency, f
	Kit.add(trove, RunService.Heartbeat:Connect(function()
		stroke.Thickness = math.max(1, gui.AbsoluteSize.X * scale * ratio)
	end))
	return stroke
end

Bb.seq, Bb.frame, Bb.round, Bb.circle = seq, frame, round, circle -- for the other shape modules

-- The circle: a white-hot ring with a cyan glow that snaps open from `from` to `to` studs.
-- `weight` thickens every layer (the detonation's white donut is ~4).
function Bb.ring(trove: Kit.Trove, adornee: Instance, glow: Color3, from: number, to: number, grow: number, hold: number, fade: number, weight: number?): BillboardGui
	local gui = Bb.board(trove, adornee, from)
	local w = weight or 1
	local strokes = { circle(gui, glow, 0.92, 0.07 * w, 0.75, trove), circle(gui, glow, 0.92, 0.035 * w, 0.35, trove), circle(gui, WHITE, 0.92, 0.012 * w + 0.02 * (w - 1), 0, trove) } -- heavy rings are mostly white
	Kit.tween(trove, gui, grow, { Size = UDim2.fromScale(to, to) }, Enum.EasingStyle.Quart)
	Kit.after(trove, grow + hold, function()
		for _, s in strokes do Kit.tween(trove, s, fade, { Transparency = 1 }) end
		Kit.tween(trove, gui, fade, { Size = UDim2.fromScale(to * 1.08, to * 1.08) })
	end)
	return gui
end

-- 4-point lens-flare sparkle (long horizontal spike, shorter vertical, hot centre) that twinkles.
function Bb.sparkle(trove: Kit.Trove, adornee: Instance, color: Color3, studs: number, seconds: number, tilt: number?): BillboardGui
	local gui = Bb.board(trove, adornee, studs)
	local holder = frame(gui, color, UDim2.fromScale(1, 1), tilt)
	holder.BackgroundTransparency = 1
	for _, bar in { { 1, 0.045, 0 }, { 0.6, 0.04, 90 }, { 0.35, 0.03, 45 }, { 0.35, 0.03, -45 } } do
		local f = frame(holder, color, UDim2.fromScale(bar[1], bar[2]), bar[3])
		local g = Instance.new("UIGradient")
		g.Transparency, g.Color, g.Parent = TIP, ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, color) }), f
	end
	local glow = frame(holder, color, UDim2.fromScale(0.16, 0.16), 0, 2)
	glow.BackgroundTransparency = 0.45
	round(glow)
	round(frame(holder, WHITE, UDim2.fromScale(0.06, 0.06), 0, 3))
	holder.Size = UDim2.fromScale(0, 0)
	Kit.tween(trove, holder, seconds * 0.3, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	Kit.after(trove, seconds * 0.55, function() Kit.tween(trove, holder, seconds * 0.45, { Size = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end)
	return gui
end

-- Jagged anime starburst: `count` tapered spikes of random length, re-cut every frame so it boils.
function Bb.starburst(trove: Kit.Trove, adornee: Instance, colors: { Color3 }, studs: number, count: number): BillboardGui
	local gui = Bb.board(trove, adornee, studs)
	local spikes: { Frame } = {}
	for n = 1, count do
		local f = frame(gui, colors[(n % #colors) + 1], UDim2.fromScale(0.5, 0.06), 0, if n % 3 == 0 then 2 else 1)
		local g = Instance.new("UIGradient")
		g.Transparency, g.Parent = seq(0, 1, 0.42, 0.05, 0.5, 0, 0.58, 0.05, 1, 1), f
		spikes[n] = f
	end
	local core = frame(gui, colors[1], UDim2.fromScale(0.26, 0.26), 0, 4)
	round(core)
	local base = math.random() * 360
	Kit.add(trove, RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for n, f in spikes do
			local length = 0.45 + 0.55 * (0.5 + 0.5 * math.noise(n * 1.7, t * 9))
			f.Size = UDim2.fromScale(length, 0.05 + 0.04 * (n % 3))
			f.Rotation = base + n / #spikes * 180 + math.noise(n, t * 4) * 14
		end
	end))
	return gui
end

-- Crescent arc: `span` (0..1) of a glowing circle, spinning at `speed` degrees per second.
function Bb.arc(trove: Kit.Trove, adornee: Instance, color: Color3, studs: number, span: number, speed: number, weight: number?): BillboardGui
	local gui = Bb.board(trove, adornee, studs)
	local w = weight or 1
	local cut = math.clamp(span, 0.05, 0.95)
	local mask = seq(0, 1, 0.5 - cut / 2, 1, 0.5 - cut / 2 + 0.02, 0, 0.5 + cut / 2 - 0.02, 0, 0.5 + cut / 2, 1, 1, 1)
	local grads: { UIGradient } = {}
	for _, layer in { { color, 0.09, 0.6 }, { color, 0.04, 0.1 }, { WHITE, 0.014, 0 } } do
		local stroke = circle(gui, layer[1], 0.9, layer[2] * w, layer[3], trove)
		local g = Instance.new("UIGradient")
		g.Transparency, g.Parent = mask, stroke
		table.insert(grads, g)
	end
	local angle = math.random() * 360
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		angle += speed * dt
		for _, g in grads do g.Rotation = angle end
	end))
	return gui
end

return table.freeze(Bb)

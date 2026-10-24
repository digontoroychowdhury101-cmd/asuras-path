--!strict
-- Camera direction for Celestial Supernova (caster only), cut to the reference: a tight orbit in the
-- smoke, a pull-back that frames the ring, a fast swoop, a wide tilted look at the planet, a push-in
-- as it ignites; after release a straight look at the blast, then a close shot inside the column.
local Cinema = require(script.Parent.SkillCinema)
local Kit = require(script.Parent.SkillKit)
local Shots = {}

local function dir(angle: number): Vector3 return Vector3.new(math.cos(angle), 0, math.sin(angle)) end

function Shots.startup(cast: any, center: () -> Vector3?, floor: Vector3, radius: number)
	local w = cast.Windup
	local yaw = math.random() * math.pi * 2
	local function at(): Vector3 return center() or floor end
	-- A: close in the vortex, slightly above, Dutch.
	Cinema.play(cast.Cinema, function(t: number)
		local c = at()
		return Cinema.look(c + dir(yaw + t * 0.7) * 7.5 + Vector3.new(0, 2.2, 0), c + Vector3.new(0, 0.6, 0), 55, -7)
	end, w * 0.23, 0.25)
	-- B: pull back to frame the circle.
	Kit.after(cast.Trove, w * 0.23, function()
		Cinema.play(cast.Cinema, function(t: number)
			local k = 1 - (1 - math.min(1, t / (w * 0.06))) ^ 3
			local c = at()
			return Cinema.look(c + dir(yaw + 0.16 + t * 0.2) * (7.5 + k * 20) + Vector3.new(0, 2.2 + k * 3, 0), c, 55, -4)
		end, w * 0.11, 0.05)
	end)
	-- C: the swoop, a fast low arc under the forming ring.
	Kit.after(cast.Trove, w * 0.34, function()
		Cinema.play(cast.Cinema, function(t: number)
			local k = math.min(1, t / (w * 0.13))
			local c = at()
			return Cinema.look(c + dir(yaw + 0.3 + k * 2.4) * (30 + k * 10) + Vector3.new(0, 8 - k * 14, 0), c + Vector3.new(0, -2 + k * 2, 0), 72 - k * 10, 12 - k * 4)
		end, w * 0.13, 0.04)
	end)
	-- D: wide on the planet, ring tilted across frame; E: push-in as it ignites.
	Kit.after(cast.Trove, w * 0.47, function()
		local base = yaw + 2.7
		Cinema.play(cast.Cinema, function(t: number)
			local c = at()
			local push = math.clamp((t - w * 0.38) / (w * 0.15), 0, 1)
			local d = radius * (3.3 - push * 0.8)
			return Cinema.look(c + dir(base + t * 0.1) * d + Vector3.new(0, radius * 0.3, 0), c, 55 - push * 6, 9)
		end, w * 0.53 + 3, 0.06) -- holds past a late release cue
	end)
end

function Shots.release(cast: any, ground: Vector3, center: Vector3, radius: number)
	local yaw = math.random() * math.pi * 2
	Cinema.play(cast.Cinema, function(t: number)
		return Cinema.look(center + dir(yaw) * (radius * 3 + t * 6) + Vector3.new(0, radius * 0.3, 0), center, 62, 4)
	end, 0.62, 0.04)
	Kit.after(cast.Trove, 0.62, function()
		Cinema.play(cast.Cinema, function(t: number) -- close outside the column, looking in at the caster
			local eye = center + dir(yaw + 1.2 + t * 0.12) * 21 + Vector3.new(0, -3 + t * 0.8, 0)
			return Cinema.look(eye, center + Vector3.new(0, 2 + t * 1.2, 0), 64, -6)
		end, 6, 0.02)
	end)
end

return table.freeze(Shots)

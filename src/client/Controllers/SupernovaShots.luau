--!strict
-- Camera direction for Celestial Supernova (caster only). Startup is three shots chained over the
-- server's windup: a low wide angle looking up as the caster rises off the sigil, a slow orbit
-- around the planet, and a fast push-in on the implosion. Release looks up the column from the
-- ground; the finale pulls back high and wide so the whole blast fits the frame.
local Cinema = require(script.Parent.SkillCinema)
local Kit = require(script.Parent.SkillKit)
local Shots = {}

function Shots.startup(cast: any, center: () -> Vector3?, floor: Vector3)
	local w = cast.Windup
	local side = math.random() * math.pi * 2
	local wide = Vector3.new(math.cos(side), 0, math.sin(side))
	-- 1. Low, wide, looking up past the sigil at the rising caster.
	Cinema.play(cast.Cinema, function(t: number)
		local at = center() or floor
		local eye = floor + wide * (22 - t * 2) + Vector3.new(0, -1.6, 0)
		return Cinema.look(eye, at + Vector3.new(0, 2 + t * 1.5, 0), 70, 4)
	end, w * 0.3 + 0.1, 0.35)
	-- 2. Slow orbit at the planet's height.
	Kit.after(cast.Trove, w * 0.3, function()
		local start = side + 0.6
		Cinema.play(cast.Cinema, function(t: number)
			local at = center()
			if not at then return nil end
			local angle = start + t * 0.45
			local eye = at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (18 - t * 0.6) + Vector3.new(0, 2.5 - t * 0.4, 0)
			return Cinema.look(eye, at + Vector3.new(0, 0.6, 0), 60, -3)
		end, w * 0.52 + 0.1, 0.6)
	end)
	-- 3. Fast push-in on the collapsing core, a hard Dutch angle.
	Kit.after(cast.Trove, w * 0.82, function()
		local at0 = center() or floor
		local from = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or at0 + wide * 16
		Cinema.play(cast.Cinema, function(t: number)
			local at = center() or at0
			local k = math.clamp(t / (w * 0.18), 0, 1)
			local eye = from:Lerp(at + (from - at).Unit * 6, k * k)
			return Cinema.look(eye, at, 58 - k * 18, -10 * k)
		end, w * 0.18 + 0.3, 0.08)
	end)
end

function Shots.release(cast: any, ground: Vector3)
	local side = math.random() * math.pi * 2
	Cinema.play(cast.Cinema, function(t: number)
		local eye = ground + Vector3.new(math.cos(side + t * 0.18), 0, math.sin(side + t * 0.18)) * (36 + t * 3) + Vector3.new(0, 1.5, 0)
		return Cinema.look(eye, ground + Vector3.new(0, 20 + t * 6, 0), 74, -5)
	end, 4, 0.12)
end

function Shots.finale(cast: any)
	local column = cast.Bag.Column
	if not column then Cinema.release(cast.Cinema, 0.8) return end
	local ground = column.Ground
	local side = math.random() * math.pi * 2
	Cinema.play(cast.Cinema, function(t: number)
		local k = math.min(1, t / 1.4)
		local eye = ground + Vector3.new(math.cos(side), 0, math.sin(side)) * (40 + 30 * k) + Vector3.new(0, 10 + 30 * k, 0)
		return Cinema.look(eye, ground + Vector3.new(0, 18 + 10 * k, 0), 70, 0)
	end, 1.8, 0.2)
	Kit.after(cast.Trove, 1.8, function() Cinema.release(cast.Cinema, 0.9) end)
end

return table.freeze(Shots)

--!strict
-- Camera direction for Blazing Sun Awakening (caster only), cut to the reference: a low close-up on
-- the face, an extreme close-up drifting along the cheek and shoulder, a medium shot on the chest as
-- the ember builds, a push into the sunburst; after release, the blazing-eye macro on the black
-- silhouette and a medium shot of the burning fists.
local Cinema = require(script.Parent.SkillCinema)
local Kit = require(script.Parent.SkillKit)
local Shots = {}

local function head(cast: any): BasePart?
	local h = cast.Entity.Model:FindFirstChild("Head")
	return if h and h:IsA("BasePart") then h else nil
end

local function root(cast: any): CFrame?
	local r = cast.Entity.Root
	return if r and r.Parent then r.CFrame else nil
end

function Shots.startup(cast: any)
	local w = cast.Windup
	Cinema.play(cast.Cinema, function(t: number) -- low, close, looking up at the face
		local h = head(cast)
		if not h then return nil end
		local cf = h.CFrame
		return Cinema.look(cf.Position + cf.LookVector * 3.6 - cf.UpVector * 0.7 + cf.RightVector * 0.7, cf.Position + cf.UpVector * 0.1, 46, 5)
	end, w * 0.07, 0.02)
	Kit.after(cast.Trove, w * 0.07, function() -- extreme close-up drifting along cheek and shoulder
		Cinema.play(cast.Cinema, function(t: number)
			local h = head(cast)
			if not h then return nil end
			local cf, k = h.CFrame, t / (w * 0.32)
			local eye = cf.Position + cf.LookVector * 3 + cf.RightVector * (1.6 - k * 0.8) - cf.UpVector * (0.5 + k * 0.3)
			return Cinema.look(eye, cf.Position - cf.UpVector * 0.5 + cf.RightVector * 0.3, 40, -4)
		end, w * 0.32, 0.02)
	end)
	Kit.after(cast.Trove, w * 0.39, function() -- medium on the chest, then the push into the burst
		Cinema.play(cast.Cinema, function(t: number)
			local cf = root(cast)
			if not cf then return nil end
			local push = math.clamp((t - w * 0.47) / (w * 0.12), 0, 1)
			return Cinema.look(cf:PointToWorldSpace(Vector3.new(0.6, 1.3, -(8.5 - push * 4))), cf:PointToWorldSpace(Vector3.new(0, 0.9, 0)), 48 - push * 6, 0)
		end, w * 0.61 + 3, 0.02) -- holds past a late release cue
	end)
end

-- After release: hold through the 2D blast, then the eye macro, then the fists.
function Shots.release(cast: any, eyes: number, fists: number, finish: number)
	Cinema.play(cast.Cinema, function(t: number)
		local cf = root(cast)
		if not cf then return nil end
		return Cinema.look(cf:PointToWorldSpace(Vector3.new(0, 0.6, -6)), cf:PointToWorldSpace(Vector3.new(0, 1, 0)), 60, 0)
	end, eyes, 0.02)
	Kit.after(cast.Trove, eyes, function()
		Cinema.play(cast.Cinema, function(t: number)
			local h = head(cast)
			if not h then return nil end
			local cf = h.CFrame
			return Cinema.look(cf.Position + cf.LookVector * (2.9 - math.min(t, 1.5) * 0.3) + cf.UpVector * 0.1, cf.Position + cf.UpVector * 0.1, 50, 0)
		end, fists - eyes, 0.02)
	end)
	Kit.after(cast.Trove, fists, function()
		Cinema.play(cast.Cinema, function(t: number)
			local cf = root(cast)
			if not cf then return nil end
			return Cinema.look(cf:PointToWorldSpace(Vector3.new(-1.2, 0.8, -(10.5 - t * 0.4))), cf:PointToWorldSpace(Vector3.new(0, 0.6, 0)), 50, 0)
		end, finish - fists, 0.04)
	end)
	Kit.after(cast.Trove, finish, function() Cinema.release(cast.Cinema, 0.6) end)
end

return table.freeze(Shots)

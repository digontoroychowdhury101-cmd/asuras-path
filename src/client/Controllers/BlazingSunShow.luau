--!strict
-- Blazing Sun Awakening timeline. Stance tension runs over the server's windup; the authoritative
-- SpellRelease cue fires the manga impact frame, fire shockwave, blazing-eye macro shot and flame
-- gauntlets; later SpellPulse cues ring heat around the stance. Camera, grading and the 2D frame
-- belong to the caster's client; the fire itself is seen by everyone nearby.
local Kit = require(script.Parent.SkillKit)
local Cinema = require(script.Parent.SkillCinema)
local Screen = require(script.Parent.ImpactFrame)
local Flame = require(script.Parent.FlameForms)
local Show = {}

local TENSION = { Brightness = -0.15, Contrast = 0.35, Saturation = -0.25, TintColor = Color3.fromRGB(255, 225, 200) }
local NEUTRAL = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }
local GAZE = { Brightness = -0.3, Contrast = 0.55, Saturation = -0.4, TintColor = Color3.fromRGB(255, 205, 180) }
local GAUNTLET_SECONDS = 4.6 -- flame gauntlets outlast the last heat ring

local function rootFrame(cast: any): CFrame?
	local root = cast.Entity.Root
	return if root and root.Parent then root.CFrame else nil
end

-- Phase 1: low over-the-shoulder Dutch angle, trembling fists, embers rising off the hands.
function Show.startup(cast: any)
	local w = cast.Windup
	local tension = Kit.trove()
	cast.Bag.Tension = tension
	Kit.add(cast.Trove, function() Kit.clean(tension) end)
	for _, hand in Kit.hands(cast.Entity.Model) do Flame.embers(tension, hand) end
	if not cast.Own then return end
	cast.Bag.Grade = Screen.grade(cast.Trove)
	Screen.settle(cast.Trove, cast.Bag.Grade, TENSION, w * 0.6)
	Cinema.play(cast.Cinema, function(t: number)
		local cf = rootFrame(cast)
		if not cf then return nil end
		-- Off the right shoulder and low, aimed past the caster's left: the body sits on the left third
		-- of the frame instead of filling it (a wide hat used to block the whole shot).
		local push = math.min(1, t / w)
		local eye = cf:PointToWorldSpace(Vector3.new(4.6, -0.8, 9.5 - push * 2))
		return Cinema.look(eye, cf:PointToWorldSpace(Vector3.new(-1.4, 1.6, -8)), 50, 6)
	end, w + 0.1, 0.3)
	-- Fists tremble: small repeating trauma kicks that grow toward the release.
	for n = 1, math.max(1, math.floor(w / 0.25)) do
		Kit.after(tension, n * 0.25, function() Cinema.shake(cast.Cinema, 0.12 + 0.2 * (n * 0.25 / w), 1.5, 2) end)
	end
end

local function gaze(cast: any, head: BasePart)
	Screen.settle(cast.Trove, cast.Bag.Grade, GAZE, 0.08)
	Cinema.play(cast.Cinema, function(t: number)
		if not head.Parent then return nil end
		-- Head-and-shoulders push-in, not an extreme macro: at 2 studs a blocky head (and a hat brim)
		-- filled the screen as flat panels. From here the blazing eyes and both gauntlets read together.
		local cf = head.CFrame
		local eye = cf.Position + cf.LookVector * (7 - math.min(t, 1) * 1.5) + cf.UpVector * 0.2 + cf.RightVector * 0.8
		return Cinema.look(eye, cf.Position - cf.UpVector * 0.9, 40 - math.min(t, 1) * 5, -3)
	end, 1.15, 0.05)
	Kit.after(cast.Trove, 1.15, function()
		Screen.settle(cast.Trove, cast.Bag.Grade, NEUTRAL, 0.5)
		Cinema.release(cast.Cinema, 0.5)
	end)
end

-- Phases 2-4: impact frame sequence, fire shockwave, blazing eyes, then the gauntlets.
function Show.release(cast: any, at: Vector3)
	if cast.Bag.Tension then Kit.clean(cast.Bag.Tension) end
	local folder = Kit.folder(cast.Trove, "BlazingSunAwakening")
	cast.Bag.Folder = folder
	local model = cast.Entity.Model
	local floor = CFrame.new(at - Vector3.new(0, 2.8, 0))
	if cast.Own then
		local grade = cast.Bag.Grade or Screen.grade(cast.Trove)
		cast.Bag.Grade = grade
		Screen.pulse(cast.Trove, grade, { Brightness = -1, Contrast = 0.5 }, 0.035, 0) -- A: blackout cut (2 frames)
		Kit.after(cast.Trove, 0.04, function() -- B: solarized burst (1 frame)
			Screen.pulse(cast.Trove, grade, { Brightness = 0.8, Contrast = 0.6, TintColor = Screen.Yellow }, 0.02, 0.18)
		end)
		Kit.after(cast.Trove, 0.06, function() -- C: 2D manga impact frame (8 frames)
			Screen.manga(cast.Trove, model, 0.15)
			Cinema.shake(cast.Cinema, 0.8, 1.3, 2)
		end)
	end
	Kit.after(cast.Trove, if cast.Own then 0.06 else 0, function() Flame.shockwave(cast.Trove, folder, floor) end) -- D
	local head = Kit.head(model)
	Kit.after(cast.Trove, 0.2, function()
		if head then
			local eyes = Kit.trove()
			Kit.add(cast.Trove, function() Kit.clean(eyes) end)
			Flame.eyes(eyes, head)
			Kit.after(cast.Trove, 1.6, function() Kit.clean(eyes) end)
			if cast.Own then gaze(cast, head) end
		end
		for _, hand in Kit.hands(model) do Flame.gauntlet(cast.Trove, hand) end
	end)
	Kit.after(cast.Trove, GAUNTLET_SECONDS, function() Kit.clean(cast.Trove) end)
end

-- Phase 4 pulses: the first pulse is the shockwave itself; later ones ring heat.
function Show.pulse(cast: any, at: Vector3)
	if cast.Pulses <= 1 or not cast.Bag.Folder then return end
	Flame.heat(cast.Trove, cast.Bag.Folder, CFrame.new(at - Vector3.new(0, 2.8, 0)))
end

return table.freeze(Show)

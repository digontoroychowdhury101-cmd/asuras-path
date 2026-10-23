--!strict
-- Blazing Sun Awakening timeline (phases are fractions of the server's windup):
--   0.00 fire sigil, embers, low over-the-shoulder Dutch angle   0.25 flame spirals climb the body
--   0.45 a sun forms overhead (hero shot from the front, low)     0.80 it is crushed into the chest
--   release: blackout, solarized flash, manga frame, negative frame; fire nova, a ring of erupting
--   pillars, rays, blazing-eye close-up and gauntlets   pulses: pillar rings   final pulse: frame
-- Camera, grading and the 2D frames belong to the caster's client; the fire is seen by everyone.
local Kit = require(script.Parent.SkillKit)
local Fx = require(script.Parent.SkillFx)
local Cinema = require(script.Parent.SkillCinema)
local Screen = require(script.Parent.ImpactFrame)
local Flame = require(script.Parent.FlameForms)
local Solar = require(script.Parent.SolarForms)
local Show = {}

Show.FinalPulse = 4
local TENSION = { Brightness = -0.15, Contrast = 0.35, Saturation = -0.25, TintColor = Color3.fromRGB(255, 225, 200) }
local KILN = { Brightness = -0.05, Contrast = 0.5, Saturation = 0.15, TintColor = Color3.fromRGB(255, 200, 160) }
local NEUTRAL = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }
local GAZE = { Brightness = -0.3, Contrast = 0.55, Saturation = -0.4, TintColor = Color3.fromRGB(255, 205, 180) }
local GAUNTLET_SECONDS = 6.4 -- flame gauntlets outlast the last pillar ring
local P = Screen.Palettes

local function rootFrame(cast: any): CFrame?
	local root = cast.Entity.Root
	return if root and root.Parent then root.CFrame else nil
end

function Show.startup(cast: any)
	local w = cast.Windup
	local tension = Kit.trove()
	cast.Bag.Tension = tension
	Kit.add(cast.Trove, function() Kit.clean(tension) end)
	local folder = Kit.folder(tension, "BlazingSunStance")
	local cf = rootFrame(cast) or CFrame.identity
	local floor = CFrame.new(cf.Position - Vector3.new(0, 2.85, 0))
	cast.Bag.Floor = floor
	Fx.sigil(tension, folder, floor, 9, Flame.Body, Flame.Core, w * 0.3)
	for _, hand in Kit.hands(cast.Entity.Model) do Flame.embers(tension, hand) end
	Kit.after(tension, w * 0.25, function() if cast.Entity.Root then Solar.swirl(tension, cast.Entity.Root, w * 0.8) end end)
	Kit.after(tension, w * 0.45, function()
		local at = (rootFrame(cast) or cf).Position + Vector3.new(0, 7, 0)
		cast.Bag.Sun = Solar.sun(tension, folder, at, 3.2, w * 0.25)
		Fx.flash(tension, folder, at, Flame.Core, 10, 0.4)
	end)
	Kit.after(tension, w * 0.8, function()
		if cast.Bag.Sun then Solar.compress(tension, cast.Bag.Sun, function() return (rootFrame(cast) or cf).Position + Vector3.new(0, 0.6, 0) end, w * 0.18) end
	end)
	if not cast.Own then return end
	cast.Bag.Grade = Screen.grade(cast.Trove)
	Screen.settle(cast.Trove, cast.Bag.Grade, TENSION, w * 0.4)
	Cinema.play(cast.Cinema, function(t: number) -- off the right shoulder, low, Dutch
		local c = rootFrame(cast)
		if not c then return nil end
		local push = math.min(1, t / (w * 0.45))
		return Cinema.look(c:PointToWorldSpace(Vector3.new(4.6, -0.8, 9.5 - push * 2)), c:PointToWorldSpace(Vector3.new(-1.4, 1.6, -8)), 50, 6)
	end, w * 0.45, 0.3)
	Kit.after(tension, w * 0.45, function() -- hero shot: low in front, looking up at the caster and the sun
		Screen.settle(cast.Trove, cast.Bag.Grade, KILN, w * 0.3)
		Cinema.play(cast.Cinema, function(t: number)
			local c = rootFrame(cast)
			if not c then return nil end
			local k = math.min(1, t / (w * 0.55))
			return Cinema.look(c:PointToWorldSpace(Vector3.new(-3, -2.2, -(15 - k * 6))), c.Position + Vector3.new(0, 4.5 - k * 3.5, 0), 62 - k * 14, -4 - k * 6)
		end, w * 0.55 + 0.1, 0.12)
	end)
	for n = 1, math.max(1, math.floor(w / 0.25)) do -- fists tremble, harder toward release
		Kit.after(tension, n * 0.25, function() Cinema.shake(cast.Cinema, 0.1 + 0.25 * (n * 0.25 / w), 1.5, 2) end)
	end
end

local function gaze(cast: any, head: BasePart)
	Screen.settle(cast.Trove, cast.Bag.Grade, GAZE, 0.08)
	Cinema.play(cast.Cinema, function(t: number) -- head-and-shoulders push-in (a macro filled the screen)
		if not head.Parent then return nil end
		local cf = head.CFrame
		local eye = cf.Position + cf.LookVector * (7 - math.min(t, 1) * 1.5) + cf.UpVector * 0.2 + cf.RightVector * 0.8
		return Cinema.look(eye, cf.Position - cf.UpVector * 0.9, 40 - math.min(t, 1) * 5, -3)
	end, 1.3, 0.05)
	Kit.after(cast.Trove, 1.3, function() -- pull back wide to watch the pillar rings
		Screen.settle(cast.Trove, cast.Bag.Grade, NEUTRAL, 0.6)
		local side = math.random() * math.pi * 2
		Cinema.play(cast.Cinema, function(t: number)
			local c = rootFrame(cast)
			if not c then return nil end
			local eye = c.Position + Vector3.new(math.cos(side + t * 0.2), 0, math.sin(side + t * 0.2)) * 26 + Vector3.new(0, 9, 0)
			return Cinema.look(eye, c.Position + Vector3.new(0, 2, 0), 64, 0)
		end, 3.2, 0.5)
		Kit.after(cast.Trove, 3.2, function() Cinema.release(cast.Cinema, 0.7) end)
	end)
end

-- Impact sequence, fire nova, the erupting pillar ring, blazing eyes, then the gauntlets.
function Show.release(cast: any, at: Vector3)
	if cast.Bag.Tension then Kit.clean(cast.Bag.Tension) end
	local folder = Kit.folder(cast.Trove, "BlazingSunAwakening")
	cast.Bag.Folder = folder
	local model = cast.Entity.Model
	local floor = CFrame.new(at - Vector3.new(0, 2.8, 0))
	if cast.Own then
		local grade = cast.Bag.Grade or Screen.grade(cast.Trove)
		cast.Bag.Grade = grade
		Screen.pulse(cast.Trove, grade, { Brightness = -1, Contrast = 0.5 }, 0.035, 0) -- A: blackout (2 frames)
		Kit.after(cast.Trove, 0.04, function() Screen.pulse(cast.Trove, grade, { Brightness = 0.8, Contrast = 0.6, TintColor = Screen.Yellow }, 0.02, 0.18) end)
		Kit.after(cast.Trove, 0.06, function() -- C/D: manga frame then its negative
			Screen.sequence(cast.Trove, model, { { P.Fire, 0.13 }, { P.FireNegative, 0.07 } })
			Cinema.shake(cast.Cinema, 0.85, 1.2, 2)
		end)
	end
	Kit.after(cast.Trove, if cast.Own then 0.2 else 0, function()
		Flame.shockwave(cast.Trove, folder, floor)
		Fx.flash(cast.Trove, folder, at, Flame.Core, 22, 0.6)
		Fx.rays(cast.Trove, folder, CFrame.new(at), Flame.Core, 18, 40, 0.7)
		Fx.cracks(cast.Trove, folder, floor.Position, 10, 18, Flame.Body, 0.3)
		Solar.pillars(cast.Trove, folder, floor, 8, 11, 22, 0)
	end)
	local head = Kit.head(model)
	Kit.after(cast.Trove, 0.3, function()
		if head then
			local eyes = Kit.trove()
			Kit.add(cast.Trove, function() Kit.clean(eyes) end)
			Flame.eyes(eyes, head)
			Kit.after(cast.Trove, 1.8, function() Kit.clean(eyes) end)
			if cast.Own then gaze(cast, head) end
		end
		for _, hand in Kit.hands(model) do Flame.gauntlet(cast.Trove, hand) end
	end)
	Kit.after(cast.Trove, GAUNTLET_SECONDS, function() Kit.clean(cast.Trove) end)
end

-- Pulses 2..3 ring heat and a rotated ring of pillars; the final pulse adds a frame and a big nova.
function Show.pulse(cast: any, at: Vector3)
	if cast.Pulses <= 1 or not cast.Bag.Folder then return end
	local floor = CFrame.new(at - Vector3.new(0, 2.8, 0))
	local final = cast.Pulses >= Show.FinalPulse
	Flame.heat(cast.Trove, cast.Bag.Folder, floor)
	Solar.pillars(cast.Trove, cast.Bag.Folder, floor, if final then 12 else 6, if final then 14 else 8 + cast.Pulses, if final then 30 else 14, cast.Pulses * 0.5)
	if final then
		Flame.shockwave(cast.Trove, cast.Bag.Folder, floor)
		Fx.flash(cast.Trove, cast.Bag.Folder, at, Flame.Body, 30, 0.7)
	end
	if cast.Own then
		Cinema.shake(cast.Cinema, if final then 0.8 else 0.4, 1.4, 2)
		if final then Screen.frame(cast.Trove, cast.Entity.Model, 0.08, P.FireNegative) end
	end
end

return table.freeze(Show)

--!strict
-- Blazing Sun Awakening, cut to the reference video (startup phases are fractions of the server
-- windup; the release and pulses wait for the authoritative cues):
--   0.00 the world goes orange duotone, white sparkles, low close-up on the face
--   0.07 extreme close-up along cheek and shoulder   0.33 "BOOM." bubble
--   0.39 black void, medium shot; 0.42 an ember kindles on the chest   0.80 a thorn ring clamps it
--   0.88 it bursts into a sunburst that fills the frame
--   release: black/white ground frame, boiling 2D toon fire, gradient wash, dark sun frame;
--   +3.5 black silhouette, blazing star eyes, ember rain   +5.4 burning fists with gold crescents
-- Void, camera, grading and 2D layers are the caster's; everyone nearby sees the fire in the world.
local Kit = require(script.Parent.SkillKit)
local Fx = require(script.Parent.SkillFx)
local Cinema = require(script.Parent.SkillCinema)
local Screen = require(script.Parent.ImpactFrame)
local Flame = require(script.Parent.FlameForms)
local Bb = require(script.Parent.BillboardFx)
local Manga = require(script.Parent.MangaFx)
local Canvas = require(script.Parent.FireCanvas)
local Stage = require(script.Parent.VoidStage)
local Sun = require(script.Parent.SunForms)
local Shots = require(script.Parent.SunShots)
local Show = {}

Show.FinalPulse = 4
local EYES, FISTS, FINISH = 3.5, 5.4, 8.6 -- seconds after release
local rgb = Color3.fromRGB

local function root(cast: any): BasePart?
	local r = cast.Entity.Root
	return if r and r.Parent then r else nil
end

local function sparkles(cast: any, trove: Kit.Trove, count: number)
	local r = root(cast)
	if not r then return end
	for n = 1, count do
		Kit.after(trove, (n - 1) * 0.12, function()
			local a = Kit.attach(trove, r, Vector3.new((math.random() - 0.5) * 6, 1 + math.random() * 3, -1 - math.random() * 2), "Twinkle")
			Bb.sparkle(trove, a, Color3.new(1, 1, 1), 0.9, 0.5, (math.random() - 0.5) * 30)
		end)
	end
end

function Show.startup(cast: any)
	local w = cast.Windup
	local tension = Kit.trove()
	cast.Bag.Tension = tension
	Kit.add(cast.Trove, function() Kit.clean(tension) end)
	local r = root(cast)
	sparkles(cast, tension, 6)
	if cast.Own then
		cast.Bag.Grade = Screen.grade(cast.Trove)
		cast.Bag.Hud = Kit.add(cast.Trove, Stage.hud())
		Screen.settle(cast.Trove, cast.Bag.Grade, Stage.Grades.Duotone, 0.04)
		Shots.startup(cast)
		Kit.after(tension, w * 0.33, function() Manga.boom(tension, Vector2.new(0.28, 0.48), w * 0.1) end)
		Kit.after(tension, w * 0.39, function()
			local base = root(cast) or r
			if not base then return end
			cast.Bag.Void = Stage.void(cast.Trove, base.Position, 40, 2.8, 60, rgb(4, 2, 2), { cast.Entity.Model })
			cast.Bag.Key = Stage.key(cast.Trove, base, rgb(255, 120, 50), 2.5)
		end)
	end
	if not r then return end
	local chest = Sun.chest(tension, r)
	Kit.after(tension, w * 0.42, function()
		local ember = Sun.ember(tension, chest)
		Kit.tween(tension, ember, w * 0.4, { Size = UDim2.fromScale(3, 3) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
	Kit.after(tension, w * 0.8, function()
		Bb.thorns(tension, chest, 4.2)
		if cast.Own then Cinema.shake(cast.Cinema, 0.25, 1, 2) end
	end)
	Kit.after(tension, w * 0.88, function()
		local burst = Bb.starburst(tension, chest, Sun.Burst, 3, 14)
		Kit.tween(tension, burst, w * 0.11, { Size = UDim2.fromScale(16, 16) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Kit.light(chest, Sun.Burst[3], 30, 6)
	end)
end

-- The blast as the reference draws it, then the eyes, then the fists.
function Show.release(cast: any, at: Vector3)
	if cast.Bag.Tension then Kit.clean(cast.Bag.Tension) end
	local folder = Kit.folder(cast.Trove, "BlazingSunAwakening")
	cast.Bag.Folder = folder
	local model = cast.Entity.Model
	local floor = CFrame.new(at - Vector3.new(0, 2.8, 0))
	Flame.shockwave(cast.Trove, folder, floor)
	Fx.flash(cast.Trove, folder, at, Sun.Burst[2], 26, 0.6)
	Fx.burst(Bb.anchor(folder, at), ColorSequence.new(Sun.Burst[1], Sun.Burst[4]), 70, 45)
	if cast.Own then
		Manga.groundFlash(cast.Trove, 0.1)
		Kit.after(cast.Trove, 0.1, function() Canvas.chaos(cast.Trove, 2.5) end)
		Kit.after(cast.Trove, 2.6, function() Canvas.wash(cast.Trove, 0.45) end)
		Kit.after(cast.Trove, 3.05, function() Canvas.sunFrame(cast.Trove, 0.45) end)
		Cinema.shake(cast.Cinema, 0.9, 0.5, 2)
		Shots.release(cast, EYES, FISTS, FINISH)
	end
	local head = Kit.head(model)
	Kit.after(cast.Trove, EYES, function()
		if not head then return end
		local eyes = Kit.trove()
		cast.Bag.Eyes = eyes
		Kit.add(cast.Trove, function() Kit.clean(eyes) end)
		local flares = Sun.eyes(eyes, head, 2.3)
		if cast.Own then
			if cast.Bag.Void then Stage.tint(cast.Trove, cast.Bag.Void, rgb(62, 18, 6), 0.05) end
			cast.Bag.Mask = Stage.silhouette(eyes, model, rgb(8, 4, 3))
			Screen.settle(cast.Trove, cast.Bag.Grade or Screen.grade(cast.Trove), Stage.Grades.Ember, 0.05)
		end
		Kit.after(cast.Trove, FISTS - EYES, function()
			for _, f in flares do f.Scale = 0.9 end
			if cast.Bag.Mask then cast.Bag.Mask:Destroy() end
		end)
	end)
	Kit.after(cast.Trove, FISTS, function()
		for _, hand in Kit.hands(model) do Sun.gauntlet(cast.Trove, hand) end
		if cast.Own and cast.Bag.Void then Stage.tint(cast.Trove, cast.Bag.Void, rgb(8, 4, 3), 0.3) end
	end)
	Kit.after(cast.Trove, FINISH, function()
		if cast.Own then
			Stage.remove(cast.Bag.Void)
			if cast.Bag.Hud then cast.Bag.Hud() end
			Screen.settle(cast.Trove, cast.Bag.Grade or Screen.grade(cast.Trove), Stage.Grades.Neutral, 0.5)
		end
	end)
	Kit.after(cast.Trove, FINISH + 1.6, function() Kit.clean(cast.Trove) end)
end

-- Pulses: heat rings in the world and a kick of shake for the caster.
function Show.pulse(cast: any, at: Vector3)
	if cast.Pulses <= 1 or not cast.Bag.Folder then return end
	Flame.heat(cast.Trove, cast.Bag.Folder, CFrame.new(at - Vector3.new(0, 2.8, 0)))
	if cast.Own then Cinema.shake(cast.Cinema, if cast.Pulses >= Show.FinalPulse then 0.6 else 0.35, 1.4, 2) end
end

return table.freeze(Show)

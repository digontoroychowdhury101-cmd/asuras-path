--!strict
-- Celestial Supernova, cut to the reference video (phases are fractions of the server windup so a
-- quick-cast catalyst stays in sync; the release and pulses wait for the authoritative cues):
--   0.00 teal void, smoke vortex, rocks; the caster rises   0.26 the glowing ring and gold sparkles
--   0.34 camera swoop with motion streaks                   0.45 the banded planet and Saturn ring
--   0.80 the planet burns white   0.86 gold flame crescents   release: white blast, a huge ring and
--   flare line, ink dome and ink streak frames, the column   pulses: flare   final: slow whiteout
-- Void, camera, grading and 2D frames are the caster's; everyone nearby sees the world effects.
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.SkillKit)
local Fx = require(script.Parent.SkillFx)
local Cinema = require(script.Parent.SkillCinema)
local Screen = require(script.Parent.ImpactFrame)
local Forms = require(script.Parent.CelestialForms)
local Pillar = require(script.Parent.CelestialPillar)
local Shots = require(script.Parent.SupernovaShots)
local Bb = require(script.Parent.BillboardFx)
local Shapes = require(script.Parent.BillboardShapes)
local Scenery = require(script.Parent.NovaScenery)
local Manga = require(script.Parent.MangaFx)
local Planet = require(script.Parent.PlanetForms)
local Stage = require(script.Parent.VoidStage)
local Ink = require(script.Parent.NovaInk)
local Sfx = require(script.Parent.SkillAudio)
local Show = {}

Show.FinalPulse = 3
local RISE, RADIUS = 20, 18 -- high enough that the planet clears the void floor
local VOID_COLOR = Color3.fromRGB(14, 64, 70)
local WHITE = Color3.new(1, 1, 1)

local function center(cast: any): Vector3?
	local root = cast.Entity.Root
	return if root and root.Parent then root.Position else nil
end

function Show.startup(cast: any)
	local w = cast.Windup
	local folder = Kit.folder(cast.Trove, "CelestialSupernova")
	cast.Bag.Folder = folder
	local floor = center(cast) or Vector3.zero
	local function at(): Vector3 return center(cast) or floor end
	Sfx.score(cast, "Nova", "Startup")
	if cast.Own then
		cast.Bag.Void = Stage.void(cast.Trove, floor, 95, 2.8, 200, VOID_COLOR, { cast.Entity.Model, folder })
		cast.Bag.Grade = Screen.grade(cast.Trove)
		cast.Bag.Bloom = Stage.bloom(cast.Trove, 1.3, 32, 0.82, 0.6)
		Screen.settle(cast.Trove, cast.Bag.Grade, Stage.Grades.TealVoid, 0.3)
		Shots.startup(cast, function() return center(cast) end, floor, RADIUS)
	end
	cast.Bag.Widen = Scenery.vortex(cast.Trove, folder, at, 10)
	Scenery.rocks(cast.Trove, folder, floor + Vector3.new(0, 6, 0), 26, 70)
	Kit.after(cast.Trove, w * 0.03, function() Forms.levitate(cast, RISE, w * 0.45) end)
	Kit.after(cast.Trove, w * 0.24, function() Scenery.sparkles(cast.Trove, folder, at(), 4, 16, 3, w * 0.14) end)
	Kit.after(cast.Trove, w * 0.26, function() -- the circle
		local hold = Bb.anchor(folder, at())
		Kit.add(cast.Trove, RunService.Heartbeat:Connect(function() hold.Position = at() end))
		Bb.ring(cast.Trove, hold, Planet.Cyan, 3, 13, w * 0.05, w * 0.06, w * 0.05)
	end)
	Kit.after(cast.Trove, w * 0.34, function()
		cast.Bag.Widen(14)
		if cast.Own then Manga.streaks(cast.Trove, Color3.fromRGB(20, 80, 95), w * 0.12) end
	end)
	Kit.after(cast.Trove, w * 0.45, function() -- the planet
		cast.Bag.Widen(RADIUS * 1.5)
		cast.Bag.Planet = Planet.body(cast.Trove, folder, at, RADIUS, w * 0.06)
		Scenery.stars(cast.Trove, folder, at(), RADIUS, w * 0.42)
	end)
	Kit.after(cast.Trove, w * 0.8, function() if cast.Bag.Planet then Planet.ignite(cast.Trove, cast.Bag.Planet, w * 0.18) end end)
	Kit.after(cast.Trove, w * 0.86, function() -- gold flame crescents tearing round the white-hot planet
		local c = at()
		cast.Bag.Arcs = Scenery.crescents(cast.Trove, folder, c, RADIUS)
		Fx.burst(Bb.anchor(folder, c), ColorSequence.new(WHITE, Planet.Gold), 40, 50)
		if cast.Own then Cinema.shake(cast.Cinema, 0.35, 0.6, 2) end
	end)
end

-- Detonation, timed to the reference: 0.00 five-lobed white blast and gold embers, 0.12 thick white
-- donut, 0.20 ring, flare line and white heart, 0.22 the column, then three ink frames (0.36 dome,
-- 0.42 inverted burst, 0.47 streaks) and at 0.59 the shot inside the column.
function Show.release(cast: any, ground: Vector3)
	local folder = cast.Bag.Folder or Kit.folder(cast.Trove, "CelestialSupernova")
	cast.Bag.Folder = folder
	Sfx.score(cast, "Nova", "Release")
	local c = center(cast) or ground + Vector3.new(0, RISE, 0)
	Planet.remove(cast.Bag.Planet)
	cast.Bag.Planet = nil
	for _, p in cast.Bag.Arcs or {} do p:Destroy() end -- the crescents burn out in the blast
	if cast.Bag.Widen then cast.Bag.Widen(10) end
	local hub = Bb.anchor(folder, c)
	if cast.Bag.Bloom then Kit.tween(cast.Trove, cast.Bag.Bloom, 0.6, { Intensity = 0.45 }) end -- keep the column cyan, not blown white
	Shapes.blob(cast.Trove, hub, Planet.Cyan, RADIUS * 3.2, 5, 0.12, 0.2)
	Fx.burst(hub, ColorSequence.new(WHITE, Planet.Gold), 60, 70)
	Kit.after(cast.Trove, 0.12, function() Bb.ring(cast.Trove, hub, Planet.Cyan, RADIUS * 2.4, RADIUS * 3.3, 0.06, 0.03, 0.08, 4.5) end)
	Kit.after(cast.Trove, 0.2, function()
		Bb.ring(cast.Trove, hub, Planet.Cyan, RADIUS * 3.6, RADIUS * 4, 0.04, 0.3, 0.3, 1.8)
		Shapes.line(cast.Trove, hub, Planet.Cyan, RADIUS * 4.5, 0.35)
		Fx.flash(cast.Trove, folder, c, WHITE, RADIUS * 1.4, 0.45)
	end)
	Kit.after(cast.Trove, 0.22, function()
		cast.Bag.Column = Pillar.erupt(cast.Trove, folder, ground, 24, c.Y - ground.Y)
		Scenery.rocks(cast.Trove, folder, ground + Vector3.new(0, 10, 0), 14, 34)
		Kit.shockwave(cast.Trove, folder, CFrame.new(ground - Vector3.new(0, 2.6, 0)), Planet.Cyan, 48, 0.9, 0.2)
	end)
	Kit.after(cast.Trove, 4.4, function() Show.whiteout(cast) end) -- if the final pulse never arrives
	if cast.Own then
		Cinema.shake(cast.Cinema, 0.8, 1.2, 2)
		Shots.release(cast, ground, c, RADIUS)
		Kit.after(cast.Trove, 0.36, function() Ink.dome(cast.Trove, 0.06) end)
		Kit.after(cast.Trove, 0.42, function() Ink.burst(cast.Trove, 0.05) end)
		Kit.after(cast.Trove, 0.47, function() Ink.streaks(cast.Trove, 0.12); Cinema.shake(cast.Cinema, 0.6, 1.4, 2) end)
	end
end

function Show.pulse(cast: any, _at: Vector3)
	local column = cast.Bag.Column
	if not column or cast.Pulses <= 1 or cast.Pulses >= Show.FinalPulse then return end
	Pillar.flare(cast.Trove, column, 1)
	Sfx.play(cast, "NovaRing", 0.7)
	if cast.Own then Cinema.shake(cast.Cinema, 0.4, 1.4, 2) end
end

-- Final beat: the frame fades slowly to white, holds, and cuts back to the world.
function Show.whiteout(cast: any)
	if cast.Bag.Done then return end
	cast.Bag.Done = true
	Sfx.play(cast, "NovaWhite")
	if cast.Own then
		Manga.fill(cast.Trove, WHITE, 1.1, 0.45, 0.35)
		Kit.after(cast.Trove, 1.55, function()
			Stage.remove(cast.Bag.Void)
			Screen.settle(cast.Trove, cast.Bag.Grade or Screen.grade(cast.Trove), Stage.Grades.Neutral, 0.2)
			Cinema.release(cast.Cinema, 0.03)
		end)
	end
	Kit.after(cast.Trove, if cast.Own then 1.1 else 0, function()
		if cast.Bag.Column then Pillar.dissolve(cast.Trove, cast.Bag.Column, 0.8) end
		if cast.Bag.Align then Forms.levitate(cast, 0, 0.9) end
	end)
	Kit.after(cast.Trove, 2.6, function() Kit.clean(cast.Trove) end)
end

return table.freeze(Show)

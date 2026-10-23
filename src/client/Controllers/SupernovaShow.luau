--!strict
-- Celestial Supernova timeline. Startup phases are fractions of the server's windup (so quick-cast
-- catalysts stay in sync); the column waits for the authoritative SpellRelease cue, pulses flare it
-- and the final pulse whites out. Levitation, camera, grading and impact frames belong to the
-- caster's client; everyone else sees the replicated body and the world-space effects.
--   0.00 sigil, dim  0.05 rise, starlight converges  0.30 planet, orbits, moons  0.55 lightning well
--   0.82 implosion   0.94 negative frame   release: frame, column, fissures, rays   final: whiteout
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.SkillKit)
local Fx = require(script.Parent.SkillFx)
local Cinema = require(script.Parent.SkillCinema)
local Screen = require(script.Parent.ImpactFrame)
local Forms = require(script.Parent.CelestialForms)
local Pillar = require(script.Parent.CelestialPillar)
local Shots = require(script.Parent.SupernovaShots)
local Show = {}

Show.FinalPulse = 3
local RISE = 12
local VOID = { Brightness = -0.35, Contrast = 0.25, Saturation = -0.55, TintColor = Color3.fromRGB(150, 175, 200) }
local WELL = { Brightness = -0.5, Contrast = 0.45, Saturation = -0.7, TintColor = Color3.fromRGB(120, 160, 200) }
local P = Screen.Palettes

local function center(cast: any): Vector3?
	local root = cast.Entity.Root; return if root and root.Parent then root.Position else nil
end

local levitate = Forms.levitate

function Show.startup(cast: any)
	local w = cast.Windup
	local folder = Kit.folder(cast.Trove, "CelestialSupernova")
	cast.Bag.Folder = folder
	local floor = center(cast) or Vector3.zero
	local ground = CFrame.new(floor - Vector3.new(0, 2.85, 0))
	cast.Bag.Sigil = Fx.sigil(cast.Trove, folder, ground, 13, Forms.Teal, Forms.Gold, w * 0.25)
	Kit.after(cast.Trove, w * 0.05, function() levitate(cast, RISE, w * 0.4) end)
	if cast.Own then
		cast.Bag.Grade = Screen.grade(cast.Trove)
		Screen.settle(cast.Trove, cast.Bag.Grade, VOID, w * 0.35)
		Shots.startup(cast, function() return center(cast) end, floor)
	end
	local motes = Kit.attach(cast.Trove, cast.Entity.Root, Vector3.zero, "SupernovaMotes")
	local gather = Fx.converge(motes, Forms.Teal, 16, 0)
	Kit.after(cast.Trove, w * 0.05, function() gather.Rate = 40 end)
	cast.Bag.Voxels = Forms.voxels(folder, floor, 18)
	local clock = 0
	Kit.add(cast.Trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		cast.Bag.Clock = clock
		local spiral = cast.Bag.Spiral or 0
		Forms.drift(cast.Bag.Voxels, cast.Bag.Axis or floor, clock, if spiral > 0 then math.max(1e-3, clock - spiral) else 0)
		local at = center(cast)
		if cast.Bag.Rings and at then Forms.spin(cast.Bag.Rings, at, cast.Bag.Speed or 4, dt) end
		if cast.Bag.Orb and at then cast.Bag.Orb.Position, cast.Bag.Core.Position = at, at end
	end))
	Kit.after(cast.Trove, w * 0.3, function()
		local at = center(cast) or floor
		cast.Bag.Orb, cast.Bag.Core = Forms.orb(cast.Trove, folder, at)
		cast.Bag.Rings = Forms.rings(folder)
		Fx.flash(cast.Trove, folder, at, Forms.Teal, 16, 0.5)
	end)
	Kit.after(cast.Trove, w * 0.55, function() -- gravity well: bolts from the planet to the sigil's star
		if cast.Own then Screen.settle(cast.Trove, cast.Bag.Grade, WELL, w * 0.25) end
		gather.Rate = 90
		for n = 1, 4 do
			local yaw = n / 4 * math.pi * 2
			Fx.lightning(cast.Trove, folder, function() return center(cast) or floor end,
				function() return floor + Vector3.new(math.cos(yaw) * 10, -2.6, math.sin(yaw) * 10) end, if n % 2 == 0 then Forms.Gold else Forms.Cyan, w * 0.3)
		end
	end)
	Kit.after(cast.Trove, w * 0.82, function() -- implosion
		gather.Rate = 0
		if not cast.Bag.Rings then return end
		local implode = w * 0.14
		for _, r in cast.Bag.Rings do
			local from = r.Radius
			Kit.add(cast.Trove, RunService.Heartbeat:Connect(function(dt: number) r.Radius = math.max(0.3, r.Radius - dt * from / implode) end))
		end
		cast.Bag.Speed = 16
		Kit.tween(cast.Trove, cast.Bag.Orb, implode, { Size = Vector3.one * 0.5 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Kit.tween(cast.Trove, cast.Bag.Core, implode, { Size = Vector3.one * 0.5, Color = Color3.new(1, 1, 1) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	end)
	if cast.Own then
		Kit.after(cast.Trove, w * 0.94, function()
			Screen.pulse(cast.Trove, cast.Bag.Grade, { Brightness = -1, Contrast = 0.6 }, w * 0.03, 0)
			Screen.frame(cast.Trove, cast.Entity.Model, w * 0.05, P.CelestialNegative)
		end)
	end
end

-- The column erupts through the caster: impact frame, shockwaves, fissures, rays, rune rings.
function Show.release(cast: any, ground: Vector3)
	local folder = cast.Bag.Folder or Kit.folder(cast.Trove, "CelestialSupernova")
	cast.Bag.Folder = folder
	for _, key in { "Orb", "Core" } do if cast.Bag[key] then cast.Bag[key]:Destroy(); cast.Bag[key] = nil end end
	for _, r in cast.Bag.Rings or {} do for _, p in r.Parts do p:Destroy() end end
	cast.Bag.Rings = nil
	local column = Pillar.erupt(cast.Trove, folder, ground, 24)
	cast.Bag.Column = column
	Pillar.runes(cast.Trove, folder, column, 0.45)
	cast.Bag.Axis, cast.Bag.Spiral = ground, (cast.Bag.Clock or 0) + 1e-3
	Kit.after(cast.Trove, 4.2, function() Show.whiteout(cast) end) -- if the final pulse never arrives
	local floor = CFrame.new(ground - Vector3.new(0, 2.6, 0))
	Fx.cracks(cast.Trove, folder, floor.Position, 12, 26, Forms.Cyan, 0.35)
	Fx.rays(cast.Trove, folder, CFrame.new(ground + Vector3.new(0, 4, 0)), Forms.Teal, 22, 60, 0.9)
	for n, wave in { { Forms.Teal, 48, 0.9, 0.2 }, { Forms.Gold, 32, 0.75, 0.35 }, { Color3.new(1, 1, 1), 60, 1.2, 0.6 } } do
		Kit.after(cast.Trove, (n - 1) * 0.1, function() Kit.shockwave(cast.Trove, folder, floor, wave[1], wave[2], wave[3], wave[4]) end)
	end
	if cast.Own then
		Screen.frame(cast.Trove, cast.Entity.Model, 0.14, P.Celestial)
		Kit.after(cast.Trove, 0.14, function() Screen.pulse(cast.Trove, cast.Bag.Grade or Screen.grade(cast.Trove), { Brightness = 0.7, Contrast = 0.5 }, 0.03, 0.4) end)
		Cinema.shake(cast.Cinema, 0.7, 1.1, 2)
		Shots.release(cast, ground)
	end
end

function Show.pulse(cast: any, at: Vector3)
	local column = cast.Bag.Column
	if not column or cast.Pulses <= 1 or cast.Pulses >= Show.FinalPulse then return end
	Pillar.flare(cast.Trove, column, 1)
	Kit.shockwave(cast.Trove, cast.Bag.Folder, CFrame.new(column.Ground - Vector3.new(0, 2.6, 0)), Forms.Cyan, 40, 0.7, 0.3)
	if cast.Own then
		Screen.pulse(cast.Trove, cast.Bag.Grade or Screen.grade(cast.Trove), { Brightness = 0.35, Contrast = 0.3, TintColor = Color3.fromRGB(200, 255, 255) }, 0.03, 0.3)
		Cinema.shake(cast.Cinema, 0.5, 1.4, 2)
	end
end

-- Final beat: negative frame, whiteout, the column blasts wide and dissolves, the caster lands.
function Show.whiteout(cast: any)
	if cast.Bag.Done then return end
	cast.Bag.Done = true
	local column = cast.Bag.Column
	if column then
		column.Fading = true
		Pillar.dissolve(cast.Trove, column, 0.9)
		Fx.flash(cast.Trove, cast.Bag.Folder, column.Ground + Vector3.new(0, 10, 0), Color3.new(1, 1, 1), 70, 0.8)
		Fx.rays(cast.Trove, cast.Bag.Folder, CFrame.new(column.Ground + Vector3.new(0, 20, 0)), Forms.Gold, 30, 90, 1.2)
	end
	if cast.Bag.Sigil then Fx.fade(cast.Trove, cast.Bag.Sigil, 1) end
	for _, v in cast.Bag.Voxels or {} do Kit.tween(cast.Trove, v.Part, 0.6, { Transparency = 1 }) end
	if cast.Own then
		Screen.frame(cast.Trove, cast.Entity.Model, 0.1, P.CelestialNegative)
		Kit.after(cast.Trove, 0.1, function()
			Screen.pulse(cast.Trove, cast.Bag.Grade or Screen.grade(cast.Trove), { Brightness = 1, Contrast = 0.4 }, 0.06, 0.8)
		end)
		Cinema.shake(cast.Cinema, 1, 0.8, 3)
		Shots.finale(cast)
	end
	if cast.Bag.Align then levitate(cast, 0, 1.4) end
	Kit.after(cast.Trove, 2, function() Kit.clean(cast.Trove) end)
end

return table.freeze(Show)

--!strict
-- Celestial Supernova timeline. Startup phases are fractions of the server's windup (so quick-cast
-- catalysts stay in sync); the pillar waits for the authoritative SpellRelease cue and the whiteout
-- for the second SpellPulse. Levitation, camera, grading and shake belong to the caster's client;
-- everyone else sees the replicated body and the world-space effects.
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.SkillKit)
local Cinema = require(script.Parent.SkillCinema)
local Screen = require(script.Parent.ImpactFrame)
local Forms = require(script.Parent.CelestialForms)
local Show = {}

local RISE = 10 -- studs of levitation
local VOID = { Brightness = -0.35, Contrast = 0.25, Saturation = -0.55, TintColor = Color3.fromRGB(150, 175, 200) }

local function center(cast: any): Vector3?
	local root = cast.Entity.Root
	return if root and root.Parent then root.Position else nil
end

local function levitate(cast: any, rise: number, seconds: number)
	local root = cast.Entity.Root
	if not cast.Own or not root then return end
	local align = cast.Bag.Align
	if not align then
		local anchor = Kit.attach(cast.Trove, root, Vector3.zero, "SupernovaLift")
		align = Kit.add(cast.Trove, Instance.new("AlignPosition"))
		align.Mode, align.Attachment0 = Enum.PositionAlignmentMode.OneAttachment, anchor
		align.MaxForce, align.MaxVelocity, align.Responsiveness = 1e6, 40, 25
		align.Position, align.Parent = root.Position, root
		cast.Bag.Align, cast.Bag.Floor = align, root.Position
	end
	Kit.tween(cast.Trove, align, seconds, { Position = cast.Bag.Floor + Vector3.new(0, rise, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

-- Phases 1-3: levitate into the void, planet and rings, gravitational implosion.
function Show.startup(cast: any)
	local w = cast.Windup
	local folder = Kit.folder(cast.Trove, "CelestialSupernova")
	cast.Bag.Folder = folder
	levitate(cast, RISE, w * 0.36)
	if cast.Own then
		cast.Bag.Grade = Screen.grade(cast.Trove)
		Screen.settle(cast.Trove, cast.Bag.Grade, VOID, w * 0.36)
		local start = math.random() * math.pi * 2
		Cinema.play(cast.Cinema, function(t: number)
			local at = center(cast)
			if not at then return nil end
			local angle = start + t * 0.4
			local zoom = math.clamp((t - w * 0.84) / (w * 0.16), 0, 1)
			local eye = at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (17 - zoom * 4) + Vector3.new(0, 3 - t * 0.5, 0)
			return Cinema.look(eye, at + Vector3.new(0, 1, 0), 62 - zoom * 12, 0)
		end, w + 0.2, 0.4)
	end
	local floor = center(cast) or Vector3.zero
	cast.Bag.Voxels = Forms.voxels(folder, floor, 14)
	local clock = 0
	Kit.add(cast.Trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		cast.Bag.Clock = clock
		local spiral = cast.Bag.Spiral or 0
		Forms.drift(cast.Bag.Voxels, cast.Bag.Axis or floor, clock, if spiral > 0 then math.max(1e-3, clock - spiral) else 0)
		local at = center(cast)
		if cast.Bag.Rings and at then Forms.spin(cast.Bag.Rings, at, cast.Bag.Speed or 4, dt) end
		if cast.Bag.Orb and at then
			cast.Bag.Orb.Position = at
			cast.Bag.Core.Position = at
		end
	end))
	Kit.after(cast.Trove, w * 0.36, function()
		local at = center(cast) or floor
		cast.Bag.Orb, cast.Bag.Core = Forms.orb(cast.Trove, folder, at)
		cast.Bag.Rings = Forms.rings(folder)
	end)
	Kit.after(cast.Trove, w * 0.84, function()
		if not cast.Bag.Rings then return end
		local implode = w * 0.16
		for _, r in cast.Bag.Rings do
			local from = r.Radius
			Kit.add(cast.Trove, RunService.Heartbeat:Connect(function(dt: number)
				r.Radius = math.max(0.3, r.Radius - dt * from / implode)
			end))
		end
		cast.Bag.Speed = 14
		Kit.tween(cast.Trove, cast.Bag.Orb, implode, { Size = Vector3.one * 0.5 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Kit.tween(cast.Trove, cast.Bag.Core, implode, { Size = Vector3.one * 0.5, Color = Color3.new(1, 1, 1) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	end)
end

-- Phase 4: the column erupts through the caster, shockwave discs race outward, voxels spiral up.
function Show.release(cast: any, ground: Vector3)
	local folder = cast.Bag.Folder or Kit.folder(cast.Trove, "CelestialSupernova")
	cast.Bag.Folder = folder
	for _, key in { "Orb", "Core" } do
		if cast.Bag[key] then cast.Bag[key]:Destroy(); cast.Bag[key] = nil end
	end
	if cast.Bag.Rings then
		for _, r in cast.Bag.Rings do for _, p in r.Parts do p:Destroy() end end
		cast.Bag.Rings = nil
	end
	cast.Bag.Pillar = Forms.pillar(cast.Trove, folder, ground)
	cast.Bag.Axis, cast.Bag.Spiral = ground, (cast.Bag.Clock or 0) + 1e-3
	Kit.after(cast.Trove, 2.4, function() Show.whiteout(cast) end) -- if the second pulse never arrives
	local floor = CFrame.new(ground - Vector3.new(0, 2.6, 0))
	Kit.shockwave(cast.Trove, folder, floor, Forms.Teal, 42, 0.9)
	Kit.after(cast.Trove, 0.12, function() Kit.shockwave(cast.Trove, folder, floor, Forms.Gold, 28, 0.75, 0.35) end)
	if cast.Own then
		Cinema.shake(cast.Cinema, 0.55, 1.2, 2)
		local side = math.random() * math.pi * 2
		Cinema.play(cast.Cinema, function(t: number)
			local eye = ground + Vector3.new(math.cos(side + t * 0.15), 0, math.sin(side + t * 0.15)) * 34 + Vector3.new(0, 1.5, 0)
			return Cinema.look(eye, ground + Vector3.new(0, 18 + t * 4, 0), 72, -4)
		end, 3, 0.12)
	end
end

-- Phase 5: whiteout flash, heavy trauma with cubic falloff, the column fades and the caster lands.
function Show.whiteout(cast: any)
	if cast.Bag.Done then return end
	cast.Bag.Done = true
	for _, p in cast.Bag.Pillar or {} do
		Kit.tween(cast.Trove, p, 0.6, { Transparency = 1, Size = Vector3.new(p.Size.X, p.Size.Y * 1.6, p.Size.Z * 1.6) })
	end
	for _, v in cast.Bag.Voxels or {} do Kit.tween(cast.Trove, v.Part, 0.6, { Transparency = 1 }) end
	if cast.Own then
		Screen.pulse(cast.Trove, cast.Bag.Grade or Screen.grade(cast.Trove), { Brightness = 1, Contrast = 0.4 }, 0.05, 0.6)
		Cinema.shake(cast.Cinema, 1, 0.9, 3)
		Cinema.release(cast.Cinema, 0.8)
	end
	if cast.Bag.Align then levitate(cast, 0, 1.1) end
	Kit.after(cast.Trove, 1.4, function() Kit.clean(cast.Trove) end)
end

return table.freeze(Show)

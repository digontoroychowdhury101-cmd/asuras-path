--!strict
-- Procedural geometry for Celestial Supernova: planetary orb, dual counter-rotating orbital rings,
-- reverse-gravity voxels and the sky-piercing light column. Pure Luau, no meshes or Blender.
local Workspace = game:GetService("Workspace")
local Kit = require(script.Parent.SkillKit)
local Forms = {}

Forms.Teal = Color3.fromRGB(0, 255, 255)
Forms.Deep = Color3.fromRGB(36, 177, 174)
Forms.Gold = Color3.fromRGB(255, 170, 0)
Forms.Cyan = Color3.fromRGB(0, 230, 230)
local WHITE = Color3.new(1, 1, 1)

export type Ring = { Parts: { BasePart }, Radius: number, Angle: number, Spin: number, Tilt: CFrame }
export type Voxel = { Part: BasePart, Base: Vector3, Lift: number, Phase: number, Spin: Vector3 }

function Forms.orb(trove: Kit.Trove, folder: Instance, center: Vector3): (BasePart, BasePart)
	-- ForceField shell: a shimmering energy surface the caster shows through, not a solid plastic ball.
	local shell = Kit.part(folder, "PlanetOrb", Forms.Teal, Vector3.one * 0.2, CFrame.new(center), Enum.PartType.Ball)
	shell.Material, shell.Transparency = Enum.Material.ForceField, 0
	local core = Kit.part(folder, "PlanetCore", WHITE, Vector3.one * 0.1, CFrame.new(center), Enum.PartType.Ball)
	Kit.light(shell, Forms.Teal, 22, 3)
	Kit.tween(trove, shell, 0.55, { Size = Vector3.one * 6 }, Enum.EasingStyle.Back)
	Kit.tween(trove, core, 0.55, { Size = Vector3.one * 2.6 }, Enum.EasingStyle.Back)
	return shell, core
end

local function ring(folder: Instance, radius: number, color: Color3, tilt: CFrame, spin: number): Ring
	local parts: { BasePart } = {}
	for _ = 1, 28 do
		table.insert(parts, Kit.part(folder, "OrbitSegment", color, Vector3.new(1, 0.3, 0.3), CFrame.identity))
	end
	return { Parts = parts, Radius = radius, Angle = 0, Spin = spin, Tilt = tilt }
end

-- Gold and teal rings on crossed tilts, spinning in opposite directions.
function Forms.rings(folder: Instance): { Ring }
	return {
		ring(folder, 6.5, Forms.Gold, CFrame.Angles(math.rad(28), 0, math.rad(8)), 1),
		ring(folder, 7.6, Forms.Cyan, CFrame.Angles(math.rad(-22), 0, math.rad(-34)), -1),
	}
end

-- Places every segment around `center` this frame; speed is radians per second.
function Forms.spin(rings: { Ring }, center: Vector3, speed: number, dt: number)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, r in rings do
		r.Angle += r.Spin * speed * dt
		local count = #r.Parts
		local chord = math.max(0.15, 2 * r.Radius * math.sin(math.pi / count) * 1.1)
		for n, p in r.Parts do
			local yaw = r.Angle + (n / count) * math.pi * 2
			table.insert(parts, p)
			table.insert(frames, CFrame.new(center) * r.Tilt * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -r.Radius))
			if math.abs(p.Size.X - chord) > 0.05 then p.Size = Vector3.new(chord, p.Size.Y, p.Size.Z) end
		end
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

function Forms.voxels(folder: Instance, ground: Vector3, count: number): { Voxel }
	local list: { Voxel } = {}
	for n = 1, count do
		local angle = (n / count) * math.pi * 2 + math.random() * 0.4
		local distance = 4 + math.random() * 7 -- inside the orbit camera's 13-17 stud radius
		local base = ground + Vector3.new(math.cos(angle) * distance, -2.4, math.sin(angle) * distance)
		local size = 0.5 + math.random()
		local glow = n % 4 == 0
		local p = Kit.part(folder, "VoidVoxel", if glow then Forms.Teal else Color3.fromRGB(46, 52, 60), Vector3.one * size, CFrame.new(base))
		p.Material = if glow then Enum.Material.Neon else Enum.Material.Slate
		table.insert(list, { Part = p, Base = base, Lift = 2 + math.random() * 7, Phase = math.random() * 6,
			Spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3 })
	end
	return list
end

-- hover (0) bobs the voxels up from the floor; spiral (>0, seconds since release) draws them up the beam.
function Forms.drift(voxels: { Voxel }, axis: Vector3, clock: number, spiral: number)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, v in voxels do
		local spin = CFrame.Angles(v.Spin.X * clock, v.Spin.Y * clock, v.Spin.Z * clock)
		local at: Vector3
		if spiral <= 0 then
			at = v.Base + Vector3.new(0, math.min(v.Lift, clock * 3.5) + math.sin(clock * 1.7 + v.Phase) * 0.35 + 2.4, 0)
		else
			local offset = v.Base - axis
			local angle = math.atan2(offset.Z, offset.X) + spiral * 2.2
			local r = math.max(2, Vector3.new(offset.X, 0, offset.Z).Magnitude * (1 - math.min(0.7, spiral * 0.4)))
			at = Vector3.new(axis.X + math.cos(angle) * r, v.Base.Y + v.Lift + 2.4 + spiral * spiral * 9, axis.Z + math.sin(angle) * r)
		end
		table.insert(parts, v.Part)
		table.insert(frames, CFrame.new(at) * spin)
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- A 24-stud, 120-stud-tall column of cyan light that drives down from the sky onto `ground`.
function Forms.pillar(trove: Kit.Trove, folder: Instance, ground: Vector3): { BasePart }
	local up = CFrame.Angles(0, 0, math.pi / 2)
	local top = ground + Vector3.new(0, 120, 0)
	local outer = Kit.part(folder, "SupernovaPillar", Forms.Teal, Vector3.new(1, 24, 24), CFrame.new(top) * up, Enum.PartType.Cylinder)
	outer.Transparency = 0.45
	local inner = Kit.part(folder, "SupernovaCore", WHITE, Vector3.new(1, 8, 8), CFrame.new(top) * up, Enum.PartType.Cylinder)
	inner.Transparency = 0.1
	for _, p in { outer, inner } do
		Kit.tween(trove, p, 0.22, { Size = Vector3.new(120, p.Size.Y, p.Size.Z), CFrame = CFrame.new(ground + Vector3.new(0, 60 - 2.4, 0)) * up },
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	Kit.light(inner, Forms.Teal, 60, 6)
	return { outer, inner }
end

return table.freeze(Forms)

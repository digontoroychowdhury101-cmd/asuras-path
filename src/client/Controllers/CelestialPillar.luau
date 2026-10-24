--!strict
-- The Supernova column as the reference shows it: a translucent cyan cylinder with a pale glowing
-- heart, thin bright edge lines running its full height, dark jagged ink slivers streaming up
-- through it, and a flat translucent disc band circling it at the caster's height.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Kit = require(script.Parent.SkillKit)
local Pillar = {}

local rgb = Color3.fromRGB
local HEIGHT = 160
local UP = CFrame.Angles(0, 0, math.pi / 2)
local SHELL, HEART, EDGE, INK = rgb(70, 225, 235), rgb(200, 255, 255), rgb(225, 255, 255), rgb(2, 10, 14)

export type Column = { Parts: { BasePart }, Shards: { BasePart }, Band: { BasePart }, Ground: Vector3, Width: number, Fading: boolean? }

local function cylinder(folder: Instance, name: string, color: Color3, width: number, transparency: number, top: Vector3): BasePart
	local p = Kit.part(folder, name, color, Vector3.new(1, width, width), CFrame.new(top) * UP, Enum.PartType.Cylinder)
	p.Transparency = transparency
	return p
end

-- Drives the column down onto `ground` in 0.2 s; `band` is the disc's height above the ground.
function Pillar.erupt(trove: Kit.Trove, folder: Instance, ground: Vector3, width: number, band: number): Column
	local top = ground + Vector3.new(0, HEIGHT, 0)
	local shell = cylinder(folder, "SupernovaPillar", SHELL, width, 0.62, top)
	local heart = cylinder(folder, "SupernovaHeart", HEART, width * 0.55, 0.5, top)
	local sheath = cylinder(folder, "SupernovaSheath", SHELL, width * 1.04, 0, top)
	sheath.Material = Enum.Material.ForceField
	local parts = { shell, heart, sheath }
	for n = 1, 8 do -- edge lines on the silhouette of the beam
		local yaw = n / 8 * math.pi * 2
		local line = Kit.part(folder, "PillarEdge", EDGE, Vector3.new(1, 0.22, 0.22), CFrame.new(top + Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * width * 0.5) * UP)
		line.Transparency = 0.15
		table.insert(parts, line)
	end
	for _, p in parts do
		local at = Vector3.new(p.Position.X, ground.Y + HEIGHT / 2 - 2.6, p.Position.Z)
		Kit.tween(trove, p, 0.2, { Size = Vector3.new(HEIGHT, p.Size.Y, p.Size.Z), CFrame = CFrame.new(at) * UP }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	Kit.light(heart, SHELL, 60, 6)
	-- Ink slivers: thin jagged dark wedges at varied radii, leaning a little, racing up and wrapping round.
	local shards: { BasePart } = {}
	local spec = {}
	for n = 1, 46 do
		local p = Kit.part(folder, "InkShard", INK, Vector3.new(0.1 + math.random() * 0.25, 5 + math.random() * 18, 0.4 + math.random() * 1.4), CFrame.new(ground),
			if n % 2 == 0 then Enum.PartType.Wedge else Enum.PartType.Block)
		p.Material, p.Transparency = Enum.Material.SmoothPlastic, 1
		shards[n] = p
		spec[n] = { Yaw = math.random() * math.pi * 2, R = width * (0.12 + math.random() * 0.36), H = math.random() * HEIGHT, Speed = 30 + math.random() * 40, Lean = (math.random() - 0.5) * 0.4 }
	end
	-- Disc band: a wide translucent ring and a bright rim at the caster's height.
	local ring: { BasePart } = {}
	for n = 1, 64 do
		local rim = n > 32
		local p = Kit.part(folder, "PillarBand", if rim then EDGE else SHELL, Vector3.new(1, if rim then 0.15 else 0.1, if rim then 0.2 else width * 0.25), CFrame.new(ground))
		p.Transparency = if rim then 0.35 else 0.82
		ring[n] = p
	end
	local column: Column = { Parts = parts, Shards = shards, Band = ring, Ground = ground, Width = width }
	local clock = 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		local frames: { CFrame } = {}
		for n, p in shards do
			local s = spec[n]
			s.H = (s.H + s.Speed * dt) % HEIGHT
			local yaw = s.Yaw + clock * 0.6
			frames[n] = CFrame.new(ground + Vector3.new(math.cos(yaw) * s.R, s.H - 2.6, math.sin(yaw) * s.R)) * CFrame.Angles(0, -yaw, s.Lean)
			if not column.Fading then p.Transparency = math.clamp(1 - clock * 4, 0.05, 1) end
		end
		local wobble = math.sin(clock * 1.3) * 0.06
		for n, p in ring do
			local rim = n > 32
			local s = if rim then n - 32 else n
			local rr = width * (if rim then 1.12 else 0.92)
			local yaw = s / 32 * math.pi * 2 + clock * 0.4
			table.insert(frames, CFrame.new(ground + Vector3.new(0, band, 0)) * CFrame.Angles(wobble, 0, wobble * 0.6) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -rr))
			if math.abs(p.Size.X - 2 * rr * math.sin(math.pi / 32) * 1.12) > 0.05 then p.Size = Vector3.new(2 * rr * math.sin(math.pi / 32) * 1.12, p.Size.Y, p.Size.Z) end
		end
		local all = table.move(ring, 1, #ring, #shards + 1, table.clone(shards))
		Workspace:BulkMoveTo(all, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end))
	return column
end

-- A pulse: the beam swells and brightens for a beat, then settles.
function Pillar.flare(trove: Kit.Trove, column: Column, strength: number)
	for _, p in column.Parts do
		local base = p.Size
		Kit.tween(trove, p, 0.08, { Size = Vector3.new(base.X, base.Y * (1 + 0.25 * strength), base.Z * (1 + 0.25 * strength)) }, Enum.EasingStyle.Quad)
		Kit.after(trove, 0.1, function() Kit.tween(trove, p, 0.5, { Size = base }, Enum.EasingStyle.Sine) end)
	end
end

-- Final beat: the column blasts wide and dissolves.
function Pillar.dissolve(trove: Kit.Trove, column: Column, seconds: number)
	column.Fading = true
	for _, p in column.Parts do
		Kit.tween(trove, p, seconds, { Transparency = 1, Size = Vector3.new(p.Size.X * 1.2, p.Size.Y * 2, p.Size.Z * 2) }, Enum.EasingStyle.Quart)
	end
	for _, p in column.Shards do Kit.tween(trove, p, seconds * 0.6, { Transparency = 1 }) end
	for _, p in column.Band do Kit.tween(trove, p, seconds * 0.6, { Transparency = 1 }) end
end

return table.freeze(Pillar)

--!strict
-- The Celestial Supernova planet from the reference: a translucent sphere wrapped in streaking cyan
-- cloud bands under a tilted Saturn ring, which can burn white-hot before it detonates (NovaScenery
-- has the vortex, rocks and gold accents around it). Procedural parts only.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Kit = require(script.Parent.SkillKit)
local Planet = {}

local rgb = Color3.fromRGB
Planet.Cyan, Planet.Deep, Planet.Gold = rgb(120, 255, 255), rgb(0, 110, 125), rgb(255, 160, 30)
local WHITE = Color3.new(1, 1, 1)

export type Body = { Shell: BasePart, Inner: BasePart, Core: BasePart, Bands: { BasePart }, Ring: { BasePart }, Light: PointLight, Radius: number }

local function slab(folder: Instance, color: Color3, size: Vector3, transparency: number): BasePart
	local p = Kit.part(folder, "PlanetBand", color, size, CFrame.identity)
	p.Transparency = transparency
	return p
end

-- The planet: radius `radius`, centred on `center()`, growing in over `grow` seconds.
function Planet.body(trove: Kit.Trove, folder: Instance, center: () -> Vector3, radius: number, grow: number): Body
	local at = center()
	local shell = Kit.part(folder, "PlanetShell", Planet.Cyan, Vector3.one * 0.5, CFrame.new(at), Enum.PartType.Ball)
	shell.Material = Enum.Material.ForceField
	local inner = Kit.part(folder, "PlanetBody", rgb(0, 70, 82), Vector3.one * 0.5, CFrame.new(at), Enum.PartType.Ball)
	inner.Transparency = 0.45
	local core = Kit.part(folder, "PlanetHeart", WHITE, Vector3.one * 0.2, CFrame.new(at), Enum.PartType.Ball)
	core.Transparency = 1
	local light = Kit.light(inner, Planet.Cyan, 60, 2)
	for _, p in { shell, inner } do Kit.tween(trove, p, grow, { Size = Vector3.one * radius * 2 }, Enum.EasingStyle.Back) end
	-- Cloud bands: 13 latitudes x 32 slabs of varied thickness, each a broken arc that ripples in
	-- latitude as it turns, so the planet reads as wavy brushed weather rather than stacked rings.
	local SEG = 32
	local bands: { BasePart } = {}
	local layout = {}
	for lat = 1, 13 do
		local phi = math.rad(-72 + (lat - 1) * 12)
		local bright = lat % 2 == 1
		local start, run = math.random(1, SEG), math.random(16, 28)
		local thick = radius * (0.07 + math.random() * 0.09)
		for s = 1, SEG do
			local lit = ((s - start) % SEG) < run
			local p = slab(folder, if bright then Planet.Cyan else Planet.Deep, Vector3.new(1, thick, 0.3), if lit then (if bright then 0.12 else 0.3) else 1)
			table.insert(bands, p)
			table.insert(layout, { Phi = phi, Index = s, Lat = lat, Speed = (if bright then 0.9 else 0.55) * (1 + lat * 0.05) })
		end
	end
	-- Saturn ring: a faint translucent sheet between a bright outer rim and a fainter inner rim.
	local RING = 56
	local ring: { BasePart } = {}
	for _ = 1, RING do table.insert(ring, slab(folder, rgb(60, 210, 220), Vector3.new(1, 0.1, radius * 0.4), 0.88)) end
	for _ = 1, RING do table.insert(ring, slab(folder, Planet.Cyan, Vector3.new(1, 0.22, 0.28), 0)) end
	for _ = 1, RING do table.insert(ring, slab(folder, Planet.Cyan, Vector3.new(1, 0.12, 0.16), 0.55)) end
	local body: Body = { Shell = shell, Inner = inner, Core = core, Bands = bands, Ring = ring, Light = light, Radius = radius }
	local axis = CFrame.Angles(math.rad(14), 0, math.rad(-10))
	local ringTilt = CFrame.Angles(math.rad(14), 0, math.rad(-16))
	local clock = 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		if not shell.Parent then return end -- removed at detonation
		clock += dt
		local c = center()
		local r = shell.Size.X / 2 * 1.01
		local frames: { CFrame } = {}
		for n, p in bands do
			local l = layout[n]
			local yaw = l.Index / SEG * math.pi * 2 + clock * l.Speed
			local phi = l.Phi + 0.07 * math.sin(yaw * 3 + clock * 1.5 + l.Lat)
			local ring_r = r * math.cos(phi)
			frames[n] = CFrame.new(c) * axis * CFrame.new(0, r * math.sin(phi), 0) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -ring_r) * CFrame.Angles(phi, 0, 0)
			p.Size = Vector3.new(2 * ring_r * math.sin(math.pi / SEG) * 1.15, p.Size.Y, p.Size.Z)
		end
		for n, p in ring do
			local layer = math.ceil(n / RING)
			local s = n - (layer - 1) * RING
			local rr = r * (if layer == 1 then 1.72 elseif layer == 2 then 2.02 else 1.42)
			local yaw = s / RING * math.pi * 2 + clock * 0.25
			table.insert(frames, CFrame.new(c) * ringTilt * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -rr))
			p.Size = Vector3.new(2 * rr * math.sin(math.pi / RING) * 1.03, p.Size.Y, if layer == 1 then r * 0.55 else p.Size.Z)
		end
		local all = table.move(ring, 1, #ring, #bands + 1, table.clone(bands))
		Workspace:BulkMoveTo(all, frames, Enum.BulkMoveMode.FireCFrameChanged)
		shell.Position, inner.Position, core.Position = c, c, c
	end))
	return body
end

-- The planet burns white from the inside over `seconds` (the build to detonation).
function Planet.ignite(trove: Kit.Trove, body: Body, seconds: number)
	body.Core.Transparency = 0.05
	Kit.tween(trove, body.Core, seconds, { Size = Vector3.one * body.Radius * 1.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Kit.tween(trove, body.Inner, seconds, { Color = rgb(180, 255, 255), Transparency = 0.2 })
	Kit.tween(trove, body.Light, seconds, { Brightness = 10, Color = WHITE })
	for _, p in body.Bands do
		if p.Transparency < 1 then Kit.tween(trove, p, seconds, { Color = WHITE }) end
	end
end

function Planet.remove(body: Body?)
	if not body then return end
	for _, p in { body.Shell, body.Inner, body.Core } do p:Destroy() end
	for _, p in body.Bands do p:Destroy() end
	for _, p in body.Ring do p:Destroy() end
end

return table.freeze(Planet)

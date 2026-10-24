--!strict
-- Celestial Supernova world pieces from the reference: a vortex of translucent teal smoke ribbons
-- whipping around the caster, floating black rocks and glowing cubes, and the planet itself — a
-- translucent sphere wrapped in streaking cyan cloud bands under a tilted Saturn ring — which can
-- burn white-hot before it detonates. Procedural parts and Beams only.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Kit = require(script.Parent.SkillKit)
local Planet = {}

local rgb = Color3.fromRGB
Planet.Cyan, Planet.Deep, Planet.Gold = rgb(120, 255, 255), rgb(0, 110, 125), rgb(255, 160, 30)
local WHITE = Color3.new(1, 1, 1)

-- Curved smoke ribbons orbiting `center()`; returns a setter for their radius (to widen the storm).
function Planet.vortex(trove: Kit.Trove, folder: Instance, center: () -> Vector3, count: number): (number) -> ()
	local hub = Kit.part(folder, "VortexHub", WHITE, Vector3.one * 0.1, CFrame.new(center()))
	hub.Transparency = 1
	local radius = 6
	local ribbons = {}
	for n = 1, count do
		local a0, a1 = Kit.attach(trove, hub, Vector3.zero, "RibbonA"), Kit.attach(trove, hub, Vector3.zero, "RibbonB")
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1, beam.Segments, beam.FaceCamera = a0, a1, 24, true
		beam.Texture, beam.TextureSpeed, beam.TextureLength = Assets.Textures.Smoke, 0.6, 6
		beam.Color = ColorSequence.new(if n % 3 == 0 then rgb(200, 255, 255) else rgb(70, 205, 215))
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
		beam.LightEmission, beam.LightInfluence, beam.Width0, beam.Width1 = 1, 0, 3 + math.random() * 4, 4 + math.random() * 6
		beam.Parent = hub
		ribbons[n] = { A = a0, B = a1, Beam = beam, Phase = math.random() * 6, Tilt = (math.random() - 0.5) * 1.6, Speed = 1.6 + math.random() * 1.8 }
	end
	-- A soft teal cloud boiling round the caster under the ribbons.
	Kit.emitter(hub, { Texture = Assets.Textures.Smoke, Color = ColorSequence.new(rgb(90, 220, 230), rgb(20, 90, 110)), Size = NumberSequence.new(5, 12),
		Rate = 7, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1, 3), Spread = 180, Light = 0.4, Spin = NumberRange.new(-40, 40),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }) })
	local clock = 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		hub.Position = center()
		for _, r in ribbons do
			local a = r.Phase + clock * r.Speed
			local rr = radius * (0.7 + 0.3 * math.sin(clock + r.Phase))
			local function at(off: number): Vector3
				local yaw = a + off
				return Vector3.new(math.cos(yaw) * rr, math.sin(yaw * 0.5 + r.Tilt) * rr * 0.35 + r.Tilt * 2, math.sin(yaw) * rr)
			end
			r.A.Position, r.B.Position = at(0), at(1.9)
			r.Beam.CurveSize0, r.Beam.CurveSize1 = rr * 0.9, -rr * 0.9
		end
	end))
	return function(r: number) radius = r end
end

-- Dark rocks (and a few glowing cubes) hanging in the void around `center`, tumbling slowly.
function Planet.rocks(trove: Kit.Trove, folder: Instance, center: Vector3, count: number, spread: number)
	local parts: { BasePart } = {}
	local spins: { CFrame } = {}
	for n = 1, count do
		local cube = n % 5 == 0
		local size = if cube then Vector3.one * (0.5 + math.random() * 0.6) else Vector3.new(1 + math.random() * 2.5, 0.8 + math.random() * 2, 1 + math.random() * 2)
		local offset = Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.6, math.random() - 0.5) * spread
		local p = Kit.part(folder, if cube then "GlowCube" else "VoidRock", if cube then Planet.Cyan else rgb(14, 18, 22), size, CFrame.new(center + offset))
		p.Material = if cube then Enum.Material.Neon else Enum.Material.Slate
		parts[n], spins[n] = p, CFrame.Angles(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	end
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		local frames: { CFrame } = {}
		for n, p in parts do frames[n] = p.CFrame * spins[n]:Lerp(CFrame.identity, 1 - dt) + Vector3.new(0, dt * 0.6, 0) end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end))
end

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
	-- Cloud bands: 11 latitudes x 22 slabs, each band a broken arc so it reads as streaking weather.
	local bands: { BasePart } = {}
	local layout = {}
	for lat = 1, 11 do
		local phi = math.rad(-70 + (lat - 1) * 14)
		local bright = lat % 2 == 1
		local start, run = math.random(1, 22), math.random(12, 20)
		for s = 1, 22 do
			local lit = ((s - start) % 22) < run
			local p = slab(folder, if bright then Planet.Cyan else Planet.Deep, Vector3.new(1, radius * 0.17, 0.3), if lit then (if bright then 0.15 else 0.25) else 1)
			table.insert(bands, p)
			table.insert(layout, { Phi = phi, Index = s, Speed = (if bright then 0.9 else 0.55) * (1 + lat * 0.06) })
		end
	end
	-- Saturn ring: a wide translucent band with a bright rim line.
	local ring: { BasePart } = {}
	for s = 1, 40 do table.insert(ring, slab(folder, rgb(60, 210, 220), Vector3.new(1, 0.15, radius * 0.45), 0.8)) end
	for s = 1, 40 do table.insert(ring, slab(folder, Planet.Cyan, Vector3.new(1, 0.25, 0.3), 0.05)) end
	local body: Body = { Shell = shell, Inner = inner, Core = core, Bands = bands, Ring = ring, Light = light, Radius = radius }
	local axis = CFrame.Angles(math.rad(14), 0, math.rad(-10))
	local ringTilt = CFrame.Angles(math.rad(22), 0, math.rad(8))
	local clock = 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		if not shell.Parent then return end -- removed at detonation
		clock += dt
		local c = center()
		local r = shell.Size.X / 2 * 1.01
		local frames: { CFrame } = {}
		for n, p in bands do
			local l = layout[n]
			local ring_r = r * math.cos(l.Phi)
			local yaw = l.Index / 22 * math.pi * 2 + clock * l.Speed
			frames[n] = CFrame.new(c) * axis * CFrame.new(0, r * math.sin(l.Phi), 0) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -ring_r) * CFrame.Angles(l.Phi, 0, 0)
			p.Size = Vector3.new(2 * ring_r * math.sin(math.pi / 22) * 1.15, p.Size.Y, p.Size.Z)
		end
		for n, p in ring do
			local rim = n > 40
			local s = if rim then n - 40 else n
			local rr = r * (if rim then 2.05 else 1.75)
			local yaw = s / 40 * math.pi * 2 + clock * 0.25
			table.insert(frames, CFrame.new(c) * ringTilt * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -rr))
			p.Size = Vector3.new(2 * rr * math.sin(math.pi / 40) * 1.02, p.Size.Y, if rim then 0.3 else r * 0.55)
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

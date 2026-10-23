--!strict
-- Procedural fire for the Blazing Sun build-up and blast: a miniature sun (plasma core, ForceField
-- corona, looping solar-flare ribbons), twin flame spirals winding up the body, and rings of fire
-- pillars that erupt from the ground. Colours are FlameForms' crimson/orange/yellow palette.
local RunService = game:GetService("RunService")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Kit = require(script.Parent.SkillKit)
local Flame = require(script.Parent.FlameForms)
local Fx = require(script.Parent.SkillFx)
local Solar = {}

export type Sun = { Core: BasePart, Corona: BasePart, Flares: { Beam }, Hub: Attachment, Glow: { BasePart } }

local function seq(a: Color3, b: Color3): ColorSequence return ColorSequence.new(a, b) end

-- A sun that grows to `size` over `grow` seconds at `at`; flares loop out of it as curved ribbons.
function Solar.sun(trove: Kit.Trove, folder: Instance, at: Vector3, size: number, grow: number): Sun
	local core = Kit.part(folder, "SunCore", Flame.Core, Vector3.one * 0.2, CFrame.new(at), Enum.PartType.Ball)
	local corona = Kit.part(folder, "SunCorona", Flame.Body, Vector3.one * 0.3, CFrame.new(at), Enum.PartType.Ball)
	corona.Material = Enum.Material.ForceField
	Kit.light(core, Flame.Body, 40, 6)
	Kit.tween(trove, core, grow, { Size = Vector3.one * size }, Enum.EasingStyle.Back)
	Kit.tween(trove, corona, grow, { Size = Vector3.one * size * 1.7 }, Enum.EasingStyle.Back)
	-- Layered bloom shells (white-hot heart, yellow and orange haze) so it reads as a star, not a disc.
	local glow: { BasePart } = {}
	for n, layer in { { Flame.Plasma, 0.55, 0 }, { Flame.Core, 1.4, 0.55 }, { Flame.Body, 2.4, 0.82 } } do
		local shell = Kit.part(folder, "SunGlow", layer[1], Vector3.one * 0.2, CFrame.new(at), Enum.PartType.Ball)
		shell.Transparency = layer[3]
		Kit.tween(trove, shell, grow, { Size = Vector3.one * size * layer[2] }, Enum.EasingStyle.Back)
		glow[n] = shell
	end
	local hub = Kit.attach(trove, core, Vector3.zero, "SunHub")
	Kit.emitter(hub, { Texture = Assets.Textures.Flame, Color = seq(Flame.Plasma, Flame.Body), Size = NumberSequence.new(size * 0.6, size * 0.15),
		Rate = 60, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(2, 5), Spread = 180, Light = 1 })
	local flares: { Beam } = {}
	for n = 1, 5 do
		local a = Kit.attach(trove, core, Vector3.zero, "FlareA")
		local b = Kit.attach(trove, core, Vector3.zero, "FlareB")
		local beam = Fx.beam(trove, a, b, if n % 2 == 0 then Flame.Core else Flame.Body, 1.6, core)
		beam.FaceCamera, beam.Segments, beam.Texture = true, 16, ""
		flares[n] = beam
	end
	local clock = 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		local r = core.Size.X * 0.5
		for n, beam in flares do
			local phase = n * 1.3 + clock * (0.8 + n * 0.15)
			local dirA = Vector3.new(math.cos(phase), math.sin(phase * 0.7), math.sin(phase))
			local dirB = Vector3.new(math.cos(phase + 1.1), math.sin(phase * 0.7 + 0.8), math.sin(phase + 1.1))
			beam.Attachment0.Position, beam.Attachment1.Position = dirA.Unit * r, dirB.Unit * r
			local loop = r * (1.4 + 0.6 * math.sin(clock * 5 + n))
			beam.CurveSize0, beam.CurveSize1 = loop, -loop
		end
		corona.CFrame = core.CFrame * CFrame.Angles(clock * 0.7, clock, 0)
		for n, shell in glow do
			shell.Position = core.Position
			if n == 3 then shell.Transparency = 0.78 + 0.08 * math.sin(clock * 9) end
		end
	end))
	return { Core = core, Corona = corona, Flares = flares, Hub = hub, Glow = glow }
end

-- Drives the sun down into the caster's chest, crushing it to a point.
function Solar.compress(trove: Kit.Trove, sun: Sun, target: () -> Vector3, seconds: number)
	local from = sun.Core.Position
	local clock = 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		clock = math.min(seconds, clock + dt)
		local k = (clock / seconds) ^ 2
		local at = from:Lerp(target(), k)
		sun.Core.Position = at
		sun.Core.Size = Vector3.one * math.max(0.3, (1 - k) * sun.Core.Size.X + k * 0.3)
		sun.Corona.Size = Vector3.one * math.max(0.4, (1 - k) * sun.Corona.Size.X)
		for _, shell in sun.Glow do shell.Size = Vector3.one * math.max(0.3, (1 - k * 0.2) * shell.Size.X) end
	end))
end

-- Two flame streams spiralling up the caster's body for `seconds`.
function Solar.swirl(trove: Kit.Trove, root: BasePart, seconds: number)
	local holders: { Attachment } = {}
	for n = 1, 2 do
		local a = Kit.attach(trove, root, Vector3.zero, "SunSwirl")
		Kit.emitter(a, { Texture = Assets.Textures.Flame, Color = seq(Flame.Core, Flame.Body), Size = NumberSequence.new(1.1, 0.2),
			Rate = 70, Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(0.5, 1.5), Spread = 30, Light = 1 })
		holders[n] = a
	end
	local clock = 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		for n, a in holders do
			local angle = clock * 7 + n * math.pi
			local height = ((clock * 3.2 + n * 1.5) % 5) - 2.6
			a.Position = Vector3.new(math.cos(angle) * 2.4, height, math.sin(angle) * 2.4)
		end
	end))
	Kit.after(trove, seconds, function() for _, a in holders do a:Destroy() end end)
end

-- `count` fire pillars erupting in a ring of `radius` around `floor` (height ~`height`).
function Solar.pillars(trove: Kit.Trove, folder: Instance, floor: CFrame, count: number, radius: number, height: number, offset: number)
	for n = 1, count do
		local yaw = n / count * math.pi * 2 + offset
		local base = floor * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -radius)
		local up = base * CFrame.Angles(0, 0, math.pi / 2) -- cylinders run along X
		local pillar = Kit.part(folder, "FirePillar", Flame.Body, Vector3.new(0.2, 3, 3), up, Enum.PartType.Cylinder)
		pillar.Transparency = 0.2
		local core = Kit.part(folder, "FirePillarCore", Flame.Core, Vector3.new(0.2, 1.3, 1.3), up, Enum.PartType.Cylinder)
		local h = height * (0.75 + math.random() * 0.5)
		for _, p in { pillar, core } do
			Kit.tween(trove, p, 0.18, { Size = Vector3.new(h, p.Size.Y, p.Size.Z), CFrame = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2) }, Enum.EasingStyle.Quint)
			Kit.after(trove, 0.25, function() Kit.tween(trove, p, 0.55, { Size = Vector3.new(h * 1.2, 0.1, 0.1), Transparency = 1 }, Enum.EasingStyle.Quad) end)
		end
		local burst = Kit.emitter(pillar, { Texture = Assets.Textures.Flame, Color = seq(Flame.Core, Flame.Coal), Size = NumberSequence.new(2.2, 0.4),
			Rate = 0, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(8, 16), Spread = 25, Accel = Vector3.new(0, 18, 0) })
		burst.EmissionDirection = Enum.NormalId.Right -- the cylinder's +X axis points up
		burst:Emit(12)
	end
end

return table.freeze(Solar)

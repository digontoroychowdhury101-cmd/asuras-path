--!strict
-- Higher-order effects shared by the showcase sorceries: ground sigils, energy beams, crackling
-- lightning, glowing ground fissures, anime light rays, flash spheres, converging motes and one-shot
-- spark bursts. Built from SkillKit parts/emitters; everything lives in the caller's trove.
local RunService = game:GetService("RunService")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Kit = require(script.Parent.SkillKit)
local Fx = {}

local function flat(cf: CFrame): CFrame return cf * CFrame.Angles(0, 0, math.pi / 2) end

-- Ground magic circle: outer and inner rings, an eight-point star of crossed bars and rune ticks.
-- Grows in over `grow` seconds and spins; returns the model (PivotTo it to move the circle).
function Fx.sigil(trove: Kit.Trove, parent: Instance, at: CFrame, radius: number, outer: Color3, inner: Color3, grow: number): Model
	local model = Instance.new("Model")
	model.Name = "Sigil"
	for _, r in { { radius, 0.35, outer, 40 }, { radius * 0.92, 0.12, inner, 40 }, { radius * 0.55, 0.22, inner, 28 } } do
		local ring = Kit.ring(model, "SigilRing", r[1], r[2], r[3], r[4])
		ring.Parent = model
	end
	for n = 0, 3 do -- two squares rotated 45 degrees make the eight-point star
		local yaw = n * math.pi / 4
		Kit.part(model, "SigilBar", inner, Vector3.new(radius * 1.55, 0.12, 0.16), CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, radius * 0.55))
		Kit.part(model, "SigilBar", inner, Vector3.new(radius * 1.55, 0.12, 0.16), CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -radius * 0.55))
	end
	for n = 1, 16 do
		local yaw = n / 16 * math.pi * 2
		Kit.part(model, "SigilRune", outer, Vector3.new(0.18, 0.12, if n % 2 == 0 then 1.4 else 0.7), CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -radius * 0.78))
	end
	model.WorldPivot = CFrame.identity
	model.Parent = parent
	local scale, spin = 0.05, 0
	model:ScaleTo(scale)
	Kit.add(trove, model)
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		scale = math.min(1, scale + dt / math.max(grow, 0.05))
		spin += dt * 0.6
		model:ScaleTo(math.max(0.05, 1 - (1 - scale) ^ 3))
		model:PivotTo(at * CFrame.Angles(0, spin, 0))
	end))
	return model
end

function Fx.fade(trove: Kit.Trove, model: Instance, seconds: number)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then Kit.tween(trove, p, seconds, { Transparency = 1 }) end
	end
end

-- A glowing beam between two attachments (Ribbon texture scrolls along it).
function Fx.beam(trove: Kit.Trove, a0: Attachment, a1: Attachment, color: Color3, width: number, parent: Instance): Beam
	local beam = Kit.add(trove, Instance.new("Beam"))
	beam.Attachment0, beam.Attachment1, beam.Color = a0, a1, ColorSequence.new(color)
	beam.Width0, beam.Width1, beam.LightEmission, beam.LightInfluence = width, width * 0.4, 1, 0
	beam.Texture, beam.TextureSpeed, beam.TextureLength, beam.FaceCamera = Assets.Textures.Ribbon, 2.5, 4, true
	beam.Transparency = NumberSequence.new(0.05)
	beam.Parent = parent
	return beam
end

-- Crackling bolt from `from` to `to`: jagged neon segments re-cut 20 times a second for `seconds`.
function Fx.lightning(trove: Kit.Trove, parent: Instance, from: () -> Vector3, to: () -> Vector3, color: Color3, seconds: number)
	local count = 9
	local parts: { BasePart } = {}
	for n = 1, count do parts[n] = Kit.part(parent, "Bolt", color, Vector3.new(0.18, 0.18, 1), CFrame.identity) end
	local stop, clock = os.clock() + seconds, 0
	Kit.add(trove, RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < 0.05 and os.clock() < stop then return end
		clock = 0
		local a, b = from(), to()
		local last = a
		for n, p in parts do
			local t = n / count
			local jitter = if n == count then Vector3.zero else Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (b - a).Magnitude * 0.18
			local point = a:Lerp(b, t) + jitter
			local len = (point - last).Magnitude
			p.Size = Vector3.new(0.16, 0.16, len)
			p.CFrame = CFrame.lookAt((last + point) / 2, point)
			p.Transparency = if os.clock() > stop then 1 else math.random() * 0.3
			last = point
		end
	end))
end

-- Radial ground fissures with a glowing seam, racing out from `center` over `seconds`.
function Fx.cracks(trove: Kit.Trove, parent: Instance, center: Vector3, count: number, length: number, glow: Color3, seconds: number)
	for n = 1, count do
		local yaw = n / count * math.pi * 2 + math.random() * 0.5
		local reach = length * (0.6 + math.random() * 0.4)
		local base = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
		local rock = Kit.part(parent, "Fissure", Color3.fromRGB(28, 26, 30), Vector3.new(1.4, 0.3, 0.1), base * CFrame.new(0, 0.05, 0))
		rock.Material = Enum.Material.Slate
		local seam = Kit.part(parent, "FissureGlow", glow, Vector3.new(0.35, 0.34, 0.1), base * CFrame.new(0, 0.07, 0))
		for _, p in { rock, seam } do
			Kit.tween(trove, p, seconds, { Size = Vector3.new(p.Size.X, p.Size.Y, reach), CFrame = base * CFrame.new(0, p.Position.Y - center.Y, -reach / 2) },
				Enum.EasingStyle.Quart)
		end
	end
end

-- Anime light rays: long tapered neon blades fanning out from `at` that flare and fade.
function Fx.rays(trove: Kit.Trove, parent: Instance, at: CFrame, color: Color3, count: number, length: number, seconds: number)
	for n = 1, count do
		local dir = CFrame.Angles(math.random() * math.pi * 2, math.random() * math.pi * 2, 0)
		local ray = Kit.part(parent, "LightRay", color, Vector3.new(0.6, 0.6, 0.5), at * dir)
		ray.Transparency = 0.15
		local reach = length * (0.5 + math.random() * 0.5)
		Kit.tween(trove, ray, seconds, { Size = Vector3.new(0.05, 0.05, reach), CFrame = at * dir * CFrame.new(0, 0, -reach / 2), Transparency = 1 },
			Enum.EasingStyle.Quint)
	end
end

-- A flash sphere that blooms to `size` and fades out.
function Fx.flash(trove: Kit.Trove, parent: Instance, at: Vector3, color: Color3, size: number, seconds: number)
	local ball = Kit.part(parent, "FlashSphere", color, Vector3.one, CFrame.new(at), Enum.PartType.Ball)
	ball.Transparency = 0.05
	Kit.light(ball, color, math.min(60, size * 2), 8)
	Kit.tween(trove, ball, seconds, { Size = Vector3.one * size, Transparency = 1 }, Enum.EasingStyle.Quart)
end

-- Motes drawn inward to `holder` from a sphere of `radius` (the gathering of power).
function Fx.converge(holder: Instance, color: Color3, radius: number, rate: number): ParticleEmitter
	local e = Kit.emitter(holder, { Texture = Assets.Textures.Ember, Color = ColorSequence.new(Color3.new(1, 1, 1), color),
		Size = NumberSequence.new(0.35, 0.1), Rate = rate, Lifetime = NumberRange.new(0.9, 1.1), Speed = NumberRange.new(radius * 0.95, radius),
		Spread = 0, Light = 1 })
	e.Shape, e.ShapeStyle, e.ShapeInOut = Enum.ParticleEmitterShape.Sphere, Enum.ParticleEmitterShapeStyle.Surface, Enum.ParticleEmitterShapeInOut.Inward
	return e
end

function Fx.burst(holder: Instance, colors: ColorSequence, count: number, speed: number, texture: string?)
	local e = Kit.emitter(holder, { Texture = texture or Assets.Textures.Ember, Color = colors, Size = NumberSequence.new(0.45, 0.05), Rate = 0,
		Lifetime = NumberRange.new(0.5, 1.2), Speed = NumberRange.new(speed * 0.5, speed), Spread = 180, Drag = 2, Light = 1 })
	e:Emit(count)
end

Fx.flat = flat
return table.freeze(Fx)

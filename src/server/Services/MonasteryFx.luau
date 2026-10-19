--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryFx
-- Particle presets (built-in rbxasset://textures/particles/* only) and the lantern for the
-- Desecrated Monastery. Glow comes from translucent paper, PointLights and light-emitting
-- particles rather than Neon parts.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)

local Fx = {}

local P = Kit.Palette
local seq = Kit.sequence

-- Slow, wide banks of dawn mist that hug the ground inside a box volume.
function Fx.mist(parent: Instance, cframe: CFrame, size: Vector3, rate: number, scale: number, color: Color3?): ParticleEmitter
	local anchor = Kit.hidden(parent, "MistBank", size, cframe)
	local e = Instance.new("ParticleEmitter")
	e.Name = "DawnMist"
	e.Texture = Kit.Texture.Smoke
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = rate
	e.Lifetime = NumberRange.new(14, 22)
	e.Speed = NumberRange.new(0.1, 0.6)
	e.Acceleration = Vector3.new(0.35, 0.04, -0.15)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-4, 4)
	e.Size = seq({ { 0, scale * 0.6 }, { 1, scale } })
	e.Transparency = seq({ { 0, 1 }, { 0.25, 0.72 }, { 0.75, 0.78 }, { 1, 1 } })
	e.Color = ColorSequence.new(color or P.Mist, P.Dawn)
	e.LightInfluence = 0.8
	e.Parent = anchor
	return e
end

-- Crimson leaves drifting down from a volume (dead maples, wind over broken walls).
function Fx.leaves(parent: BasePart, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "CrimsonLeaves"
	e.Texture = Kit.Texture.Mote
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = rate
	e.Lifetime = NumberRange.new(7, 11)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(1.1, -1.2, 0.5)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Drag = 0.6
	e.Size = seq({ { 0, 0.32 }, { 1, 0.18 } })
	e.Transparency = seq({ { 0, 1 }, { 0.12, 0.1 }, { 0.85, 0.2 }, { 1, 1 } })
	e.Color = ColorSequence.new(P.Leaf, P.LeafDark)
	e.LightInfluence = 1
	e.Parent = parent
	return e
end

-- Soft candle glow that sits inside translucent paper or a brazier bowl.
function Fx.glow(parent: BasePart, size: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Glow"
	e.Texture = Kit.Texture.Fire
	e.LockedToPart = true
	e.Rate = 8
	e.Lifetime = NumberRange.new(0.6, 0.9)
	e.Speed = NumberRange.new(0, 0.2)
	e.Size = seq({ { 0, size }, { 1, size * 0.6 } })
	e.Transparency = seq({ { 0, 0.55 }, { 1, 1 } })
	e.Color = ColorSequence.new(Color3.fromRGB(255, 196, 120), Color3.fromRGB(255, 110, 40))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Parent = parent
end

-- Rising embers over a brazier or censer.
function Fx.embers(parent: BasePart, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Texture = Kit.Texture.Sparks
	e.Rate = rate
	e.Lifetime = NumberRange.new(2, 3.5)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(18, 18)
	e.Acceleration = Vector3.new(0.6, 2, 0.3)
	e.Drag = 0.7
	e.Size = seq({ { 0, 0.2 }, { 1, 0.04 } })
	e.Transparency = seq({ { 0, 0 }, { 0.8, 0.3 }, { 1, 1 } })
	e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 80, 30))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Parent = parent
end

-- Stone (standing) or paper (hanging) lantern; the only warm light sources in the ruin.
function Fx.lantern(parent: Instance, base: CFrame, hanging: boolean?, range: number?)
	local group = Kit.folder("Lantern", parent)
	local y = if hanging then 0 else 3.4
	if not hanging then
		Kit.part(group, "Foot", Vector3.new(2.6, 0.4, 2.6), base * CFrame.new(0, 0.2, 0), P.StoneDark, Enum.Material.Slate)
		Kit.part(group, "Stem", Vector3.new(0.9, 2.4, 0.9), base * CFrame.new(0, 1.6, 0), P.Stone, Enum.Material.Slate)
		Kit.part(group, "Sill", Vector3.new(2, 0.3, 2), base * CFrame.new(0, y - 0.85, 0), P.StoneDark, Enum.Material.Slate, Kit.decor())
	else
		Kit.part(group, "Cord", Vector3.new(0.08, 3, 0.08), base * CFrame.new(0, 2.2, 0), P.Iron, Enum.Material.Metal, Kit.decor())
	end
	local paper = Kit.part(group, "Paper", Vector3.new(1.3, 1.5, 1.3), base * CFrame.new(0, y, 0), P.Lantern, Enum.Material.Glass,
		{ Collide = false, Query = false, Transparency = 0.25, Shadow = false })
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			Kit.part(group, "Rib", Vector3.new(0.12, 1.7, 0.12), base * CFrame.new(x * 0.7, y, z * 0.7), P.WoodDark, Enum.Material.Wood, Kit.decor())
		end
	end
	Kit.part(group, "Cap", Vector3.new(2.2, 0.35, 2.2), base * CFrame.new(0, y + 0.95, 0), P.Iron, Enum.Material.Metal, Kit.decor())
	Fx.glow(paper, 1.1)
	Kit.light(paper, P.Lantern, range or 18, 1.3, true)
end

return Fx

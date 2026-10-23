--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryHorizon
-- What holds the Shrine up and what surrounds it: layered karst foundations (lobby kit cliffs) under
-- the courtyard, the walkways, the forge platform, the duel court and the Well of Descent; a sea of
-- sunlit cloud below; and an authored karst landscape with inhabited summit pagodas and cascades. Nothing here collides - falls still drop to SanctuaryService's cloud catch.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)

local Vista = require(script.Parent:WaitForChild("SanctuaryVista") :: ModuleScript)
local Horizon = {}

local function rock(group: Instance, name: string, cf: CFrame, scale: Vector3)
	if not Kit.place(group, name, cf, scale, false) then
		local size = Vector3.new(30, 24, 30) * scale
		Kit.slab(group, "RockFoot", size, cf * CFrame.new(0, -size.Y / 2, 0), "Rock", { Collide = false, Query = false, Shadow = false })
	end
end

-- Foundations: `origin` is the plaza centre; forge/duel centres and the descent pavilion are local.
function Horizon.Foundations(parent: Instance, origin: CFrame, forge: Vector3, duel: Vector3, descent: Vector3)
	local group = Kit.folder("Foundations", parent)
	for k = 0, 3 do
		local side = origin * CFrame.Angles(0, math.rad(90 * k), 0)
		for _, x in { -22, 22 } do
			rock(group, "Cliff_Shelf", side * CFrame.new(x, -5.6, -38) * CFrame.Angles(0, (x / 22) * 0.12, 0), Vector3.new(0.72, 1.4, 1.2))
		end
		rock(group, "Cliff_Ledge", side * CFrame.new(-34, -5.4, -34), Vector3.new(0.7, 1.25, 0.7))
	end
	rock(group, "Cliff_Spur", origin * CFrame.new(0, -28, 0), Vector3.new(4.2, 2.6, 4.2))
	rock(group, "Cliff_Ledge", origin * CFrame.new(forge) * CFrame.new(0, -5.2, 0), Vector3.new(0.95, 1.5, 0.95))
	rock(group, "Cliff_Spur", origin * CFrame.new(forge) * CFrame.new(-2, -36, 3), Vector3.new(2, 1.8, 2))
	rock(group, "Cliff_Ledge", origin * CFrame.new(duel) * CFrame.new(0, -4.8, 0), Vector3.new(1.65, 1.6, 1.65))
	rock(group, "Cliff_Spur", origin * CFrame.new(duel) * CFrame.new(4, -42, -2), Vector3.new(2.6, 2.2, 2.6))
	rock(group, "Cliff_Ledge", origin * CFrame.new(descent) * CFrame.new(0, -6.2, 0), Vector3.new(0.85, 1.1, 0.85))
	for _, x in { -56, 54 } do -- under the two walkways
		rock(group, "Cliff_Shelf", origin * CFrame.new(x, -3.3, 0) * CFrame.Angles(0, 0.04 * x, 0), Vector3.new(0.34, 0.8, 0.5))
	end
	rock(group, "Cliff_Shelf", origin * CFrame.new(0, -3.4, 60) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.4, 0.8, 0.5))
	-- Fractured shoulders break the straight platform rims into natural hanging escarpments.
	for i, placement in { { -43, -34, 22 }, { 42, -27, -18 }, { -38, 27, 63 }, { 40, 31, -51 } } do
		local edge = origin * CFrame.new(placement[1], -12 - i * 2, placement[2]) * CFrame.Angles(0, math.rad(placement[3]), 0)
		rock(group, "Cliff_Shelf", edge, Vector3.new(0.72, 2.25, 0.82))
		rock(group, "Cliff_Spur", edge * CFrame.new(5, -33, -2), Vector3.new(1.55, 2.65, 1.2))
	end
	return group
end

local function mist(anchor: BasePart, rate: number, size: number, transparency: number, color: Color3, lifetime: number, initial: number)
	if Assets.Textures.Smoke == "" then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "RollingCloud"
	e.Texture, e.Rate, e.Lifetime, e.Speed = Assets.Textures.Smoke, rate, NumberRange.new(lifetime - 5, lifetime), NumberRange.new(0.6, 1.2)
	e.Acceleration, e.Shape, e.ShapeStyle = Vector3.new(0.025, 0, 0.015), Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection, e.SpreadAngle = Enum.NormalId.Right, Vector2.new(8, 8)
	e.Size = Kit.sequence({ { 0, size * 0.78 }, { 0.48, size }, { 1, size * 1.1 } })
	e.Transparency = Kit.sequence({ { 0, 0.8 }, { 0.16, transparency }, { 0.68, transparency + 0.08 }, { 1, 1 } })
	e.Color = ColorSequence.new(color, Color3.fromRGB(242, 238, 236))
	e.LightInfluence, e.LightEmission = 0.05, 0.18
	e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-1.8, 1.8)
	e.Parent = anchor
	e:Emit(initial)
end

-- Two staggered beds fill the space below the island rather than painting the horizon alone.
-- Their opaque silhouettes are the overlapping soft particle alpha, never flattened mesh discs.
-- Every local emitter is 70–100 studs below the plaza; its largest puff stays below flagstones.
function Horizon.Build(parent: Instance, origin: CFrame)
	local sky = Kit.folder("CloudSea", parent)
	for row, z in { -560, -340, -120, 100 } do
		for column, x in { -220, 0, 220 } do
			local lower = Kit.hidden(sky, "DeepCloudBank", Vector3.new(210, 8, 210), origin * CFrame.new(x, -100 + (row % 2) * 2, z))
			mist(lower, 0.7, 142, 0.14, Color3.fromRGB(247, 243, 237), 26, 8)
			local upper = Kit.hidden(sky, "SunlitCloudCrest", Vector3.new(185, 6, 185), origin * CFrame.new(x + 22, -80 + (column % 2) * 2, z + 40))
			mist(upper, 0.48, 106, 0.10, Color3.fromRGB(247, 243, 237), 24, 7)
		end
	end
	-- Broad but sparse foot banks connect the rolling local sea to the hazed physical mountains.
	for _, bank in {
		{ -1180, -1120 }, { 1120, -1050 }, { -1920, -980 }, { 1870, -1640 },
		{ -920, 890 }, { 1320, 640 }, { 400, 2000 }, { -980, 2490 },
	} do
		local anchor = Kit.hidden(sky, "MountainFootCloud", Vector3.new(420, 12, 320), origin * CFrame.new(bank[1], -90, bank[2]))
		mist(anchor, 1.0, 240, 0.08, Color3.fromRGB(247, 243, 237), 34, 22)
	end
	Vista.Build(parent, origin)
	sky:SetAttribute("CloudMeshBudget", 0)
	sky:SetAttribute("MistEmitterBudget", 32)
	sky:SetAttribute("CloudParticleSteadyStateCeiling", 644)
	sky:SetAttribute("CloudInitialParticleBudget", 356)
	sky:SetAttribute("LocalCloudElevationMin", origin.Position.Y - 100)
	sky:SetAttribute("LocalCloudElevationMax", origin.Position.Y - 78)
	return sky
end

return table.freeze(Horizon)

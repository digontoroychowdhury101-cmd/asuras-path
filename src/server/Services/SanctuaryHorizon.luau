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

local function mist(anchor: BasePart, rate: number, size: number, transparency: number, color: Color3)
	if Assets.Textures.Smoke == "" then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture, e.Rate, e.Lifetime, e.Speed = Assets.Textures.Smoke, rate, NumberRange.new(20, 28), NumberRange.new(0.2, 0.6)
	e.Acceleration, e.Shape, e.ShapeStyle = Vector3.new(0.5, 0, 0.15), Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	e.Size = Kit.sequence({ { 0, size * 0.7 }, { 1, size * 1.2 } })
	e.Transparency = Kit.sequence({ { 0, 1 }, { 0.25, transparency }, { 0.75, transparency + 0.05 }, { 1, 1 } })
	e.Color = ColorSequence.new(color, Color3.fromRGB(214, 206, 214))
	e.LightInfluence, e.Rotation, e.RotSpeed = 0.85, NumberRange.new(0, 360), NumberRange.new(-2, 2)
	e.Parent = anchor
end

-- Cloud banks stay well below the walking surfaces. Flattened shared meshes supply the distant
-- sea while a bounded set of translucent wisps blends their silhouettes into the mountain feet.
function Horizon.Build(parent: Instance, origin: CFrame)
	local sky = Kit.folder("CloudSea", parent)
	local rng = Random.new(2718)
	local names = { "Cloud_A", "Cloud_B", "Cloud_C" }
	for k = 0, 25 do
		local a = math.rad(k * 137.508)
		local r = 150 + (k / 25) ^ 0.8 * 1020
		local at = origin * CFrame.new(math.cos(a) * r, -184 - rng:NextNumber(0, 46) - r * 0.025, math.sin(a) * r - 120)
		local size = 3.5 + r / 230 + rng:NextNumber(0, 1.2)
		local bank = Kit.place(sky, names[k % 3 + 1], at * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Vector3.new(size, 0.85 + size * 0.07, size * 0.8), false)
		if bank then
			for _, p in bank:GetDescendants() do
				if p:IsA("BasePart") then
					p.Transparency = 0.4
					p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
				end
			end
		end
	end
	for k = 0, 7 do
		local a = math.rad(k * 45 + 17)
		local anchor = Kit.hidden(sky, "CloudBank", Vector3.new(260, 8, 190), origin * CFrame.new(math.cos(a) * 510, -155, math.sin(a) * 510 - 160))
		mist(anchor, 0.22, 105, 0.84, Color3.fromRGB(251, 235, 220))
	end
	for _, p in { { -110, -35 }, { 125, -60 }, { 0, 125 }, { 0, -390 } } do
		local anchor = Kit.hidden(sky, "CliffMist", Vector3.new(95, 4, 75), origin * CFrame.new(p[1], -78, p[2]))
		mist(anchor, 0.18, 52, 0.88, Color3.fromRGB(241, 230, 219))
	end
	Vista.Build(parent, origin)
	sky:SetAttribute("CloudMeshBudget", 26)
	sky:SetAttribute("MistEmitterBudget", 12)
	return sky
end

return table.freeze(Horizon)

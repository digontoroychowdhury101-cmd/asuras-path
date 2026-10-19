--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryLandmarks
-- Set pieces that give each zone of the Desecrated Monastery a silhouette: the two rest shrines
-- (AltarAnchor_<id> parts receive WorldService's rest prompt), the gutted bell tower and its
-- fallen bronze bell, the cold iron cauldron, and the toppled pagoda among the grave stupas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("AsurasPath").Shared.WorldDefinitions)
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Ruins = require(script.Parent:WaitForChild("MonasteryRuins") :: ModuleScript)

local Landmarks = {}

local P = Kit.Palette
local G = Kit.GROUND
local SLATE, WOOD, CORRODED = Enum.Material.Slate, Enum.Material.Wood, Enum.Material.CorrodedMetal

-- Low stone shrine with an iron censer; its stele stands behind (+Z), away from the spawn point.
local function shrine(parent: Instance, altar: World.Altar)
	local group = Kit.folder("Shrine_" .. altar.Id, parent)
	local base = CFrame.new(altar.Placement.X, G, altar.Placement.Z)
	Kit.disc(group, "Step", 3.4, 0.5, base * CFrame.new(0, 0.25, 0), P.StoneDark, SLATE)
	Kit.part(group, "Pedestal", Vector3.new(2.6, 2, 2.6), base * CFrame.new(0, 1.5, 0), P.Stone:Lerp(P.Moss, 0.2), SLATE)
	Kit.disc(group, "Censer", 1.3, 0.9, base * CFrame.new(0, 2.95, 0), P.Iron, CORRODED)
	Kit.disc(group, "Ash", 1.05, 0.1, base * CFrame.new(0, 3.42, 0), Color3.fromRGB(70, 64, 60), Enum.Material.Sand, Kit.decor())
	for k = 0, 4 do
		local a = math.rad(k * 72)
		Kit.part(group, "Incense", Vector3.new(0.06, 1.3, 0.06), base * CFrame.new(math.cos(a) * 0.5, 4, math.sin(a) * 0.5) * CFrame.Angles(0.12, 0, 0.1), P.Wood, WOOD, Kit.decor())
	end
	local stele = Kit.part(group, "Stele", Vector3.new(3.4, 6, 0.9), base * CFrame.new(0, 3, 4.6) * CFrame.Angles(math.rad(-4), 0, math.rad(3)), P.StoneDark, SLATE)
	Kit.part(group, "SteleCap", Vector3.new(4.2, 0.7, 1.4), stele.CFrame * CFrame.new(0, 3.3, 0), P.Roof, SLATE, Kit.decor())
	local anchor = Kit.hidden(group, "AltarAnchor_" .. altar.Id, Vector3.new(1, 0.2, 1), base * CFrame.new(0, 3.6, 0))
	Fx.glow(anchor, 0.9)
	Fx.embers(anchor, 3)
	Kit.light(anchor, P.Lantern, 20, 1.6, true)
end

local function bellTower(parent: Instance, at: Vector3)
	local group = Kit.folder("BellTower", parent)
	local base = CFrame.new(at.X, G, at.Z)
	Kit.part(group, "Podium", Vector3.new(14, 3, 14), base * CFrame.new(0, 1.5, 0), P.StoneDark, Enum.Material.Cobblestone)
	for index, corner in { Vector2.new(-5, -5), Vector2.new(5, -5), Vector2.new(5, 5), Vector2.new(-5, 5) } do
		local h = ({ 16, 9, 5, 13 })[index]
		Kit.part(group, "Post", Vector3.new(1.6, h, 1.6), base * CFrame.new(corner.X, 3 + h * 0.5, corner.Y), P.Lacquer:Lerp(P.WoodDark, 0.55), WOOD)
	end
	Kit.beam(group, "HangingBeam", (base * CFrame.new(-5, 18.6, -5)).Position, (base * CFrame.new(4, 6, 6)).Position, 1.2, P.WoodDark, WOOD)
	Kit.part(group, "RoofShard", Vector3.new(12, 0.6, 9), base * CFrame.new(-1.5, 16, 0) * CFrame.Angles(math.rad(28), 0.2, math.rad(-14)), P.Roof, SLATE, Kit.decor())
	Fx.lantern(group, CFrame.new(at.X - 5, G + 13.4, at.Z - 6.4), true, 18)
end

-- The great bell lies on its side where it fell, its lip split open.
local function fallenBell(parent: Instance, at: Vector3)
	local group = Kit.folder("FallenBell", parent)
	local lie = CFrame.new(at.X, G + 3.6, at.Z) * CFrame.Angles(0, math.rad(35), 0)
	Kit.part(group, "Body", Vector3.new(7, 7, 7), lie, Color3.fromRGB(58, 52, 40), CORRODED, { Shape = Enum.PartType.Cylinder })
	Kit.part(group, "Lip", Vector3.new(1.2, 8.6, 8.6), lie * CFrame.new(3.6, -0.3, 0), Color3.fromRGB(70, 62, 44), CORRODED, { Shape = Enum.PartType.Cylinder })
	Kit.part(group, "Crown", Vector3.new(1.4, 3, 3), lie * CFrame.new(-4.1, 0, 0), P.Iron, CORRODED, { Shape = Enum.PartType.Cylinder })
	for k = 0, 3 do
		Kit.part(group, "Band", Vector3.new(0.3, 7.3, 7.3), lie * CFrame.new(-2.4 + k * 1.6, 0, 0), P.Rust, CORRODED, { Shape = Enum.PartType.Cylinder, Collide = false, Query = false })
	end
end

local function cauldron(parent: Instance, at: Vector3)
	local group = Kit.folder("IronCauldron", parent)
	local base = CFrame.new(at.X, G, at.Z)
	Kit.disc(group, "Plinth", 4.4, 0.8, base * CFrame.new(0, 0.4, 0), P.StoneDark, SLATE)
	for k = 0, 2 do
		local a = math.rad(k * 120)
		Kit.part(group, "Leg", Vector3.new(0.7, 2.4, 0.7), base * CFrame.new(math.cos(a) * 2.2, 2, math.sin(a) * 2.2), P.Iron, CORRODED)
	end
	Kit.disc(group, "Bowl", 3, 2.4, base * CFrame.new(0, 3.6, 0), P.Iron, CORRODED)
	Kit.disc(group, "Rim", 3.3, 0.35, base * CFrame.new(0, 4.9, 0), P.Rust, CORRODED, Kit.decor())
	local coals = Kit.disc(group, "Coals", 2.7, 0.12, base * CFrame.new(0, 4.82, 0), Color3.fromRGB(60, 34, 24), Enum.Material.Basalt, Kit.decor())
	Fx.glow(coals, 1.6)
	Fx.embers(coals, 5)
	Kit.light(coals, Color3.fromRGB(255, 140, 70), 22, 1.4, true)
end

-- First tier still stands; the three upper tiers fell west and lie broken in a line.
local function toppledPagoda(parent: Instance, at: Vector3, rng: Random)
	local group = Kit.folder("ToppledPagoda", parent)
	Kit.disc(group, "Platform", 11, 1.6, CFrame.new(at.X, 0.8, at.Z), P.StoneDark, SLATE)
	Kit.part(group, "Tier1", Vector3.new(11, 9, 11), CFrame.new(at.X, 6.1, at.Z), P.Stone:Lerp(P.Lacquer, 0.25), Enum.Material.Plaster)
	Ruins.roof(group, CFrame.new(at.X, 10.4, at.Z), 18, 18, rng, true)
	for tier = 2, 4 do
		local s = 11 - tier * 1.8
		local x = at.X - 6 - tier * 8.5
		local lie = CFrame.new(x, s * 0.5 - 0.4, at.Z + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), math.rad(90 + rng:NextNumber(-12, 12)))
		Kit.part(group, "Tier" .. tier, Vector3.new(s, s * 0.8, s), lie, P.Stone:Lerp(P.Lacquer, 0.2), Enum.Material.Plaster)
		Kit.part(group, "TierEave", Vector3.new(s + 5, 0.6, s + 5), lie * CFrame.new(0, s * 0.42, 0), P.Roof, SLATE, Kit.decor())
	end
	Kit.beam(group, "Spire", Vector3.new(at.X - 46, 1, at.Z), Vector3.new(at.X - 58, 2.4, at.Z + 4), 0.8, P.Iron, CORRODED, true)
end

local function stupa(parent: Instance, at: Vector3, rng: Random)
	local tilt = CFrame.new(at.X, G, at.Z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, math.pi), rng:NextNumber(-0.12, 0.12))
	local s = rng:NextNumber(0.8, 1.3)
	Kit.part(parent, "StupaBase", Vector3.new(3 * s, 1.4 * s, 3 * s), tilt * CFrame.new(0, 0.7 * s, 0), P.StoneDark, SLATE)
	Kit.part(parent, "StupaDome", Vector3.new(2.6 * s, 2.6 * s, 2.6 * s), tilt * CFrame.new(0, 2.6 * s, 0), P.Stone:Lerp(P.Moss, rng:NextNumber(0, 0.5)), SLATE, { Shape = Enum.PartType.Ball })
	Kit.part(parent, "StupaSpire", Vector3.new(0.5 * s, 2.4 * s, 0.5 * s), tilt * CFrame.new(0, 4.8 * s, 0), P.Iron, CORRODED, Kit.decor())
end

function Landmarks.Build(parent: Instance, rng: Random)
	for _, altar in World.Regions.DesecratedMonastery.Altars do
		shrine(parent, altar)
	end
	bellTower(parent, Vector3.new(64, 0, -772))
	fallenBell(parent, Vector3.new(58, 0, -843))
	cauldron(parent, Vector3.new(0, 0, -836))
	toppledPagoda(parent, Vector3.new(-62, 0, -1052), rng)
	local graves = Kit.folder("GraveStupas", parent)
	for _ = 1, 12 do
		local spot = Vector3.new(rng:NextNumber(-130, -26), 0, rng:NextNumber(-998, -1108))
		if (spot - Vector3.new(-90, 0, -1052)).Magnitude > 34 then
			stupa(graves, spot, rng)
		end
	end
end

return Landmarks

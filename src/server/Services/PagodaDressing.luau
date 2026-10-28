--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/PagodaDressing
-- Celestial Pagoda silhouettes and storytelling (batch 20). All decor: four uploaded high-detail
-- pagodas on rock pillars around Wu's open hall, the paifang at the cloud stair, bixie guardians,
-- temple lanterns, pines and crags (AsuraHanHD / AsuraHanKit), a lotus pool and drifting mist in
-- the gorge, prayer banners from the gallery, the empty throne's canopy and the hall's great bell.
-- Collision lives in CelestialPagodaLayout.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Fx = require(script.Parent:WaitForChild("MonasteryFx") :: ModuleScript)
local Decor = require(script.Parent:WaitForChild("RegionDecor") :: ModuleScript)

local Dressing = {}
local P = Kit.Palette
local M = Enum.Material
local rgb = Color3.fromRGB
local GOLD = rgb(176, 140, 72)

local function tower(parent: Instance, x: number, z: number, tiers: number)
	Kit.part(parent, "TowerBody", Vector3.new(14, 40, 14), CFrame.new(x, 20, z), P.Lacquer:Lerp(P.WoodDark, 0.35), M.Wood, Kit.decor())
	for k = 1, tiers do
		local y = 40 + (k - 1) * 14
		Decor.roof(parent, CFrame.new(x, y, z), 24 - k * 3, 24 - k * 3, 4)
		Kit.part(parent, "TowerStorey", Vector3.new(12 - k * 2, 10, 12 - k * 2), CFrame.new(x, y + 9, z), P.Lacquer, M.Wood, Kit.decor())
	end
	Kit.part(parent, "TowerFinial", Vector3.new(1, 8, 1), CFrame.new(x, 44 + tiers * 14, z), GOLD, M.Metal, Kit.decor())
end

function Dressing.Build(map: Instance, _layout: any, rng: Random)
	local set = Kit.folder("PagodaDressing", map)
	-- Corner pagodas (AsuraHanHD) on the rock pillars CampaignTerrain raises outside the hall frame;
	-- the primitive towers remain only as the fallback when the kit is missing.
	for _, c in { { -140, -2318 }, { 140, -2318 }, { -140, -2448 }, { 140, -2448 } } do
		local at = Vector3.new(c[1], 0, c[2])
		if not Decor.han(set, "AsuraHanHD", "HanPagodaHD", Decor.facing(at, Vector3.new(0, 0, c[2])), 0.75) then
			tower(set, c[1] * 114 / 140, c[2], 3)
		end
	end
	-- Hall columns and gate towers keep their layout boxes as invisible colliders under real models:
	-- lobby-kit lacquer columns with bases and bracket sets, and Han watchtowers at the forecourt.
	Decor.dressBoxes(map, {
		HallColumn = function(foot, box)
			if not Decor.han(set, "AsuraLobbyKit", "Column_Lacquer", foot, box.Size.Y / 10) then
				return false
			end
			Decor.han(set, "AsuraLobbyKit", "Column_Base", foot, 2)
			Decor.han(set, "AsuraLobbyKit", "Bracket_Set", foot + Vector3.new(0, box.Size.Y, 0), 1.3)
			return true
		end,
		GateTower = function(foot, box)
			return Decor.han(set, "AsuraHanKit", "HanDefenseTower", Decor.facing(foot.Position, Vector3.new(0, 0, -2200)), box.Size.Y / 31) ~= nil
		end,
	})
	-- The paifang over the head of the cloud stair, facing the approach from the Colosseum causeway.
	Decor.han(set, "AsuraHanHD", "HanGateHD", Decor.facing(Vector3.new(0, 0, -2124), Vector3.new(0, 0, -2000)), 2)
	-- Forecourt guardians and lanterns (AsuraHanKit), clear of the walk to Wu's gate.
	for _, side in { -1, 1 } do
		Decor.han(set, "AsuraHanKit", "HanBixie", Decor.facing(Vector3.new(side * 44, 0, -2284), Vector3.new(0, 0, -2284)), 1.6)
		Decor.han(set, "AsuraHanKit", "HanLantern", CFrame.new(side * 30, 0, -2262), 1.4)
	end
	-- Pines and crags along the cliff tops either side of the cloud stair.
	for _ = 1, 14 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, z = side * rng:NextNumber(24, 146), rng:NextNumber(-2126, -2160)
		Decor.han(set, "AsuraHanKit", "Pine", CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0), rng:NextNumber(4.5, 7))
	end
	for _, c in { { -150, -2130 }, { 150, -2140 }, { -96, -2166 }, { 110, -2166 } } do
		Decor.han(set, "AsuraHanKit", ({ "CragA", "CragB", "CragC" })[rng:NextInteger(1, 3)],
			CFrame.new(c[1], -2, c[2]) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0), rng:NextNumber(1.6, 2.4))
	end
	-- Lotus pool on the gorge floor (top -26) and mist pooling under the galleries.
	Kit.part(set, "LotusPool", Vector3.new(60, 0.1, 30), CFrame.new(70, -25.94, -2214), rgb(40, 74, 82), M.Glass, Kit.decor())
	for _ = 1, 22 do
		local pad = Kit.part(set, "LotusPad", Vector3.new(0.12, rng:NextNumber(2, 4), rng:NextNumber(2, 4)), CFrame.new(rng:NextNumber(44, 96), -25.85, rng:NextNumber(-2202, -2226))
			* CFrame.Angles(0, 0, math.rad(90)), rgb(70, 110, 66), M.Grass, Kit.decor())
		pad.Shape = Enum.PartType.Cylinder
	end
	Fx.mist(set, CFrame.new(0, -22, -2212), Vector3.new(290, 6, 70), 3, 28)
	-- Prayer banners from the gallery and the lantern rafter.
	for _, x in { -112, -96, -80, -66 } do
		Decor.banner(set, CFrame.new(x, -6.8, -2240.4), rng:NextNumber(5, 8), if x == -96 then rgb(214, 204, 176) else P.Lacquer)
	end
	Decor.banner(set, CFrame.new(0, -6.8, -2216.2), 6, GOLD)
	-- The empty throne: canopy and posts (the seat itself is the layout's EmptyThrone).
	Kit.part(set, "ThroneBack", Vector3.new(6, 6, 0.8), CFrame.new(-140, 23, -2282), P.Lacquer, M.Wood, Kit.decor())
	Decor.roof(set, CFrame.new(-140, 26, -2280), 10, 8, 2, P.Lacquer)
	Kit.part(set, "ThroneCushion", Vector3.new(5, 0.6, 3), CFrame.new(-140, 20.3, -2279.5), GOLD, M.Fabric, Kit.decor())
	-- The hall's great bell, hung beside the fog gate.
	Kit.part(set, "BellFrame", Vector3.new(12, 1, 1), CFrame.new(60, 16, -2276), P.WoodDark, M.Wood, Kit.decor())
	for _, x in { 54.5, 65.5 } do
		Kit.part(set, "BellPost", Vector3.new(1, 16, 1), CFrame.new(x, 8, -2276), P.Lacquer, M.Wood, Kit.decor())
	end
	local bell = Kit.part(set, "GreatBell", Vector3.new(6, 8, 6), CFrame.new(60, 11, -2276), rgb(112, 91, 57), M.Metal, Kit.decor())
	bell.Shape = Enum.PartType.Cylinder
	bell.CFrame = bell.CFrame * CFrame.Angles(0, 0, math.rad(90))
	-- A dawn-coloured haze beyond the dawn terrace, toward the summit.
	Fx.mist(set, CFrame.new(0, -6, -2520), Vector3.new(80, 10, 40), 2, 34, rgb(232, 200, 176))
end

return Dressing

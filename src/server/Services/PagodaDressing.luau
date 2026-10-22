--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/PagodaDressing
-- Celestial Pagoda silhouettes and storytelling (batch 20). All decor: four corner towers with
-- stacked curved eaves around Wu's open hall (their roofs start above the arena's air space), the
-- torn upper roof ring, criss-cross rafters over the lotus gorge, a lotus pool and drifting mist in
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
	-- Corner towers and the torn roof ring above the hall (clear of its 86-stud air space).
	for _, c in { { -114, -2296 }, { 114, -2296 }, { -114, -2466 }, { 114, -2466 } } do
		tower(set, c[1], c[2], 3)
	end
	for k = 0, 15 do
		if k % 5 ~= 2 then -- broken bays
			local a = math.rad(k * 22.5)
			Kit.part(set, "RoofRing", Vector3.new(38, 1.2, 10), CFrame.new(math.cos(a) * 100, 96 + (k % 3), -2380 + math.sin(a) * 100)
				* CFrame.Angles(0, -a + math.pi / 2, math.rad(12)), P.Roof, M.Slate, Kit.decor())
		end
	end
	-- Rafters over the gorge: dark beams at two heights, criss-crossed.
	for k = 0, 6 do
		local z = -2180 - k * 11
		Kit.beam(set, "OverRafter", Vector3.new(-150, 14 + (k % 2) * 6, z), Vector3.new(150, 14 + (k % 2) * 6, z - 8), 1.4, P.WoodDark, M.Wood)
	end
	Kit.beam(set, "OverRafter", Vector3.new(-150, 24, -2176), Vector3.new(150, 18, -2248), 1.6, P.WoodDark, M.Wood)
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
	local bell = Kit.part(set, "GreatBell", Vector3.new(6, 8, 6), CFrame.new(60, 11, -2276), rgb(112, 91, 57), M.Metal, Kit.decor())
	bell.Shape = Enum.PartType.Cylinder
	bell.CFrame = bell.CFrame * CFrame.Angles(0, 0, math.rad(90))
	-- A dawn-coloured haze beyond the dawn terrace, toward the summit.
	Fx.mist(set, CFrame.new(0, -6, -2520), Vector3.new(80, 10, 40), 2, 34, rgb(232, 200, 176))
end

return Dressing

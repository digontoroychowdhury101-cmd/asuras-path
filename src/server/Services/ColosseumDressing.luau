--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/ColosseumDressing
-- Ash Colosseum silhouettes and storytelling (batch 18). All decor: champion statues on the road's
-- plinths (the uploaded AsuraColossusStatue where present, a carved stand-in otherwise), broken
-- arcade arches along the cavea's crown (AsuraRuinArch), torn order banners on the facade, braziers
-- in the hall and on the tiers, the antechamber's fallen roof beams, spears and shields of the
-- order's last disciples in the ash, and Victor's gate lintel. Collision lives in AshColosseumLayout.
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)
local Decor = require(script.Parent:WaitForChild("RegionDecor") :: ModuleScript)
local Pbr = require(script.Parent:WaitForChild("PbrAssets") :: ModuleScript)

local Dressing = {}
local P = Kit.Palette
local M = Enum.Material
local rgb = Color3.fromRGB
local ASH = rgb(92, 88, 86)

local function statue(parent: Instance, base: CFrame)
	if Pbr.place(parent, "AsuraColossusStatue", base, 11, "Y") then
		return
	end
	Kit.part(parent, "ChampionRobe", Vector3.new(3.4, 7, 2.6), base * CFrame.new(0, 3.5, 0), P.Stone, M.Slate, Kit.decor())
	Kit.part(parent, "ChampionShoulders", Vector3.new(4.6, 1.4, 2.4), base * CFrame.new(0, 7.4, 0), P.Stone, M.Slate, Kit.decor())
	Kit.part(parent, "ChampionHead", Vector3.new(1.6, 1.8, 1.6), base * CFrame.new(0, 9, 0), P.StoneDark, M.Slate, Kit.decor())
	Kit.beam(parent, "ChampionJian", (base * CFrame.new(0.6, 1, -1.4)).Position, (base * CFrame.new(0.6, 8, -1.4)).Position, 0.3, P.StoneDark, M.Slate)
end

function Dressing.Build(map: Instance, _layout: any, rng: Random)
	local set = Kit.folder("ColosseumDressing", map)
	-- Champions on the ash road plinths (x +/-20, z -1694, plinth top 4); one has fallen.
	statue(set, CFrame.new(-20, 4, -1694) * CFrame.Angles(0, math.rad(200), 0))
	Kit.part(set, "FallenChampion", Vector3.new(8, 3, 3), CFrame.new(24, 1.4, -1702) * CFrame.Angles(0, math.rad(30), math.rad(8)), P.Stone, M.Slate, Kit.decor())
	-- Arcade arches along the cavea's crown (tier 5 top 20) and across the facade.
	for _, spot in { { -108, -1930 }, { -108, -2010 }, { 108, -1950 }, { 108, -2030 }, { -60, -2073 }, { 60, -2073 } } do
		if not Pbr.place(set, "AsuraRuinArch", CFrame.new(spot[1], 20, spot[2]) * CFrame.Angles(0, if math.abs(spot[1]) > 100 then math.rad(90) else 0, 0), 16, "Y") then
			for _, side in { -1, 1 } do
				Kit.part(set, "ArcadePier", Vector3.new(2.4, 14, 2.4), CFrame.new(spot[1], 27, spot[2]) * CFrame.Angles(0, if math.abs(spot[1]) > 100 then math.rad(90) else 0, 0)
					* CFrame.new(side * 5, 0, 0), P.Stone, M.Slate, Kit.decor())
			end
		end
	end
	for _, x in { -60, -36, 36, 60, 88 } do
		Decor.banner(set, CFrame.new(x, 20.5, -1887.2), rng:NextNumber(9, 14), if x == 88 then rgb(60, 22, 22) else P.Lacquer)
	end
	-- Braziers: hall colonnade gaps and the tier crowns either side of the arena.
	for _, spot in { { -22, 0, -1828 }, { 22, 0, -1806 }, { -100, 16, -1920 }, { 100, 16, -1920 }, { -100, 16, -2000 }, { 100, 16, -2000 } } do
		Decor.brazier(set, CFrame.new(spot[1], spot[2], spot[3]))
	end
	-- Antechamber: fallen roof beams high over the hall (open to the ash sky), soot on the walls.
	for k = 0, 3 do
		Kit.beam(set, "FallenRafter", Vector3.new(-34, 12 + k * 0.6, -1716 - k * 13), Vector3.new(30 - k * 6, 10.5 - k, -1722 - k * 12), 1.2, P.WoodDark, M.Wood)
	end
	-- The order's last stand: spears and shields in the ash of the hall and the arena margins.
	for _ = 1, 18 do
		local x, z = rng:NextNumber(-48, 48), rng:NextNumber(-1782, -1878)
		if math.abs(x) > 10 then
			local tip = Vector3.new(x + rng:NextNumber(-1, 1), rng:NextNumber(4, 6), z + rng:NextNumber(-1, 1))
			Kit.beam(set, "FallenSpear", Vector3.new(x, -0.4, z), tip, 0.2, P.WoodDark, M.Wood)
		end
	end
	for _ = 1, 8 do
		Kit.part(set, "DiscardedShield", Vector3.new(0.4, 3, 3), CFrame.new(rng:NextNumber(-46, 46), 0.1, rng:NextNumber(-1782, -1878))
			* CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, math.pi), math.rad(90)), rgb(70, 52, 40), M.Metal,
			{ Collide = false, Query = false, Shadow = true, Shape = Enum.PartType.Cylinder })
	end
	for _ = 1, 16 do
		Kit.part(set, "AshDrift", Vector3.new(rng:NextNumber(8, 20), 0.3, rng:NextNumber(6, 14)), CFrame.new(rng:NextNumber(-110, 110), 0.05, rng:NextNumber(-1700, -2110))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), ASH, M.Sand, Kit.decor())
	end
	-- Victor's gate: a lintel and a name board over the south passage.
	Kit.part(set, "VictorLintel", Vector3.new(38, 2.4, 4), CFrame.new(0, 21, -2035), P.StoneDark, M.Slate, Kit.decor())
	Kit.part(set, "VictorBoard", Vector3.new(10, 3, 0.4), CFrame.new(0, 17.5, -2032.8), P.WoodDark, M.Wood, Kit.decor())
end

return Dressing

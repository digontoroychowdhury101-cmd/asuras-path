--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/AshColosseumLayout
-- Grandmaster Shen's campaign colosseum (batch 18, findings #22 #27 #28 #32) - the ruined martial
-- arena of his order, distinct from the Sanctuary's PvP rings. Walked north to south (-Z):
--   Bamboo Pass join -> ash road between toppled champion statues -> Colosseum Antechamber (a roofless
--   gatehouse raised three steps: altar pocket) -> Hall of Champions colonnade (two swordsmen, one
--   per half, a broken wall between) -> the facade and fog gate -> Shen's arena (BossArenas floor,
--   x -60..60, z -1895..-2025) inside a five-tier cavea -> Victor's gate through the south tiers ->
--   ashen causeway -> the Celestial Pagoda's cloud stair.
-- The podium wall is low (3) and the first tier starts 12 studs beyond the arena edge, so the camera
-- keeps its distance on both of Shen's forms (the facade stands 18 north of the arena); the fog
-- gate, phases and IDs are unchanged.
-- Batch 24: the Proving Court east of the ash road encloses the existing PvP ring Ring_OctagonOfAsh
-- (ColosseumService, centre 118,0,-1770, threshold apothem 28), which the batch 18 veil had shut out.
local hasScript = pcall(function() return script.Parent end)
local L: any = if hasScript then (require(script.Parent.RegionLayout) :: any) else (require("./RegionLayout") :: any)

local r = L.region("AshColosseum")
local VEIL_H = 220
local AX, AS = 60, -2025 -- arena half-width and south edge (its north edge is z -1895)

L.slab(r, "AshGround", "Ash", -180, 180, -1680, -2120, -0.1, 6)
L.slab(r, "AshRoad", "Basalt", -8, 8, -1680, -1704, 0.2, 1)
-- Antechamber: raised floor, three steps in and out, broken side and end walls with doorways.
L.slab(r, "AntechamberFloor", "Basalt", -36, 36, -1712, -1768, 3, 4)
L.stairs(r, "AntechamberSteps", "Basalt", 0, -1704, 0, -1712, 0.2, 3, 16, 0.95)
L.stairs(r, "AntechamberSteps", "Basalt", 0, -1768, 0, -1776, 3, 0.2, 16, 0.95)
for _, side in { -1, 1 } do
	L.wall(r, "AnteWall", "Stone", side * 37, -1710, side * 37, -1770, 0, 12, 2)
	L.wall(r, "AnteFront", "Stone", side * 8, -1711, side * 37, -1711, 3, 10, 2)
	L.wall(r, "AnteBack", "Stone", side * 8, -1769, side * 37, -1769, 3, 10, 2)
	L.box(r, "Pillar", "Stone", side * 9.5, 11, -1711, 3, 16, 3) -- doorway jambs
	L.box(r, "Pillar", "Stone", side * 9.5, 11, -1769, 3, 16, 3)
	L.box(r, "StatuePlinth", "Basalt", side * 20, 2, -1694, 6, 4, 6)
end
-- Hall of Champions: colonnade, toppled columns as cover, and a broken wall between the two foes.
L.slab(r, "HallFlags", "Basalt", -8, 8, -1776, -1880, 0.2, 1)
for _, side in { -1, 1 } do
	for _, z in { -1792, -1816, -1840, -1864 } do
		L.box(r, "Pillar", "Stone", side * 30, 8, z, 3, 16, 3)
	end
	L.wall(r, "BrokenWall", "Stone", side * 12, -1814, side * 40, -1814, 0, 3, 2)
	L.wall(r, "HallWall", "Stone", side * 52, -1772, side * 52, -1876, 0, 14, 2)
end
L.box(r, "ToppledColumn", "Stone", -18, 1.5, -1800, 3, 3, 16, 64)
L.box(r, "ToppledColumn", "Stone", 26, 1.5, -1834, 3, 3, 16, 118)
-- The facade, 18 studs north of the arena so the camera keeps its distance, with the fog gate's
-- passage (30 wide) through its centre bay.
for _, side in { -1, 1 } do
	L.wall(r, "Facade", "Stone", side * 15, -1877, side * 116, -1877, 0, 22, 3)
	L.box(r, "GateTower", "Stone", side * 18, 14, -1874, 6, 28, 6)
	L.wall(r, "GatePassage", "Stone", side * 16, -1878, side * 16, -1892, 0, 14, 2)
end
-- Cavea: a low podium wall, then five tiers (4 high, 8 deep) starting 12 beyond the arena edge;
-- the south tiers part for Victor's gate.
for _, side in { -1, 1 } do
	L.wall(r, "Podium", "Basalt", side * (AX + 3), -1879, side * (AX + 3), AS - 3, 0, 3, 1.5)
	L.wall(r, "Podium", "Basalt", side * 14, AS - 3, side * (AX + 3), AS - 3, 0, 3, 1.5)
	for k = 1, 5 do
		local inner, top = 12 + (k - 1) * 8, 4 * k
		local x0, z1 = AX + inner, AS - inner - 8
		L.box(r, "Tier", "Basalt", side * (x0 + 4), top / 2, (-1879 + z1) / 2, 8, top, -1879 - z1)
		L.box(r, "Tier", "Basalt", side * (14 + x0) / 2, top / 2, AS - inner - 4, x0 - 14, top, 8)
	end
	L.box(r, "VictorJamb", "Stone", side * 16, 10, AS - 10, 4, 20, 4)
end
L.slab(r, "Causeway", "Basalt", -10, 10, AS - 3, -2120, 0.2, 1)
L.slab(r, "CourtLane", "Basalt", 30, 84, -1686, -1702, 0.2, 1)

for _, l in { { -14, -0.1, -1692 }, { 14, -0.1, -1692 }, { -28, 3, -1720 }, { 28, 3, -1720 }, { -28, 3, -1760 }, { 28, 3, -1760 },
	{ -12, -0.1, -1872 }, { 12, -0.1, -1872 }, { -13, -0.1, -2052 }, { 13, -0.1, -2052 },
	{ 84, -0.1, -1712 }, { 152, -0.1, -1712 }, { 84, -0.1, -1804 }, { 152, -0.1, -1804 } } do
	L.lantern(r, l[1], l[2], l[3])
end

L.fence(r, "Veil", "Veil", { { -30, -1680 }, { -30, -1708 }, { -40, -1708 }, { -40, -1772 }, { -54, -1772 }, { -54, -1876 }, { -116, -1876 },
	{ -116, -2080 }, { -16, -2080 }, { -16, -2120 } }, -10, VEIL_H, 2)
L.fence(r, "Veil", "Veil", { { 30, -1680 }, { 156, -1680 }, { 156, -1808 }, { 80, -1808 }, { 80, -1708 }, { 40, -1708 }, { 40, -1772 }, { 54, -1772 }, { 54, -1876 }, { 116, -1876 },
	{ 116, -2080 }, { 16, -2080 }, { 16, -2120 } }, -10, VEIL_H, 2)

L.mark(r, "Altar", "Colosseum Antechamber", 0, 3, -1736)
L.mark(r, "ArenaMouth", "Shen's fog gate", 0, 0.2, -1880)
L.mark(r, "VictorGate", "Victor's gate", 0, 0.2, -2040)
L.mark(r, "NorthJoin", "Ash road", 0, 0.2, -1682)
L.mark(r, "SouthJoin", "Cloud stair", 0, 0.2, -2118)
L.mark(r, "ProvingRing", "The Octagonal Ring of Ash", 118, 0, -1770)

L.zone(r, "AC_Road", "the ash road", -30, 30, -1680, -1708)
L.zone(r, "AC_Ante", "the antechamber", -40, 40, -1708, -1774)
L.zone(r, "AC_HallN", "the hall of champions", -52, 52, -1774, -1814)
L.zone(r, "AC_HallS", "the hall of champions", -52, 52, -1814, -1877)
L.zone(r, "AC_Arena", "Shen's arena", -116, 116, -1877, AS - 3)
L.zone(r, "AC_South", "the ashen causeway", -16, 16, AS - 3, -2120)
L.zone(r, "AC_Court", "the proving court", 30, 156, -1680, -1808)
L.door(r, "AC_Road", "AC_Ante", 0, 0.2, -1708, "Antechamber steps")
L.door(r, "AC_Ante", "AC_HallN", 0, 0.2, -1774, "Hall of Champions")
L.door(r, "AC_HallN", "AC_HallS", 0, 0.2, -1814, "Broken wall")
L.door(r, "AC_HallS", "AC_Arena", 0, 0.2, -1877, "Shen's fog gate")
L.door(r, "AC_Arena", "AC_South", 0, 0.2, AS - 3, "Victor's gate")
L.door(r, "AC_South", "CP_Stair", 0, 0.2, -2120, "Cloud stair")
L.door(r, "AC_Road", "AC_Court", 30, 0.2, -1694, "Proving court")
r.SpawnZones = { AC_Swordsman_Gate_A = "AC_HallN", AC_Swordsman_Gate_B = "AC_HallS" }

r.Groves = {} -- no bamboo here: ash, basalt and ruin

return L.freeze(r)

--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/BambooPassLayout
-- Bamboo Pass (batch 17, findings #22 #27 #28 #32 #44). Walked north to south (-Z):
--   Monastery road -> Bamboo Gate clearing (tablet V, first swordsman) -> ridge stairs to the
--   frosted crest (y 12, monk) -> shrine stairs -> Whispering Bamboo Shrine pocket (altar) ->
--   Baize's mouth -> Baize's arena (BossArenas floor, frost pillars) -> south moon gate -> ash
--   descent (monk) -> Ash Colosseum road.
-- Optional: three frost stones off the crest's east lip climb to the Frost Ridge (y 18), which
-- walls the arena's east side: two swordsmen, an overlook into the arena and tablet VI; the way
-- back is a one-way drop onto the shrine ground. Everything outside the walked network is bamboo
-- thicket behind an invisible veil (collides, ignored by cameras), so double jump and glide stay
-- inside the pass. Arena floors stay at y 0 (boss motion and attacks assume it).
local hasScript = pcall(function() return script.Parent end)
local L: any = if hasScript then (require(script.Parent.RegionLayout) :: any) else (require("./RegionLayout") :: any)

local r = L.region("BambooPass")
local VEIL_H = 220

-- Ground and the raised crest/ridge masses.
L.slab(r, "PassGround", "Grass", -200, 200, -1120, -1680, -0.1, 6) -- just under the arena floor (top 0)
L.slab(r, "TrailFlags", "Path", -6, 6, -1120, -1226, 0.2, 1)
L.slab(r, "FrostedCrest", "Snow", -40, 34, -1250, -1292, 12, 14)
L.slab(r, "CrestButtress", "Rock", 34, 42, -1244, -1252, 12, 14) -- closes the stone pocket's north end
L.stairs(r, "RidgeStair", "Path", 0, -1226, 0, -1250, 0, 12, 12)
L.stairs(r, "ShrineStair", "Path", 0, -1292, 0, -1316, 12, 0, 12)
L.slab(r, "ShrineFlags", "Path", -50, -22, -1316, -1340, 0.2, 1)
L.slab(r, "MouthFlags", "Path", -14, 14, -1340, -1378, 0.2, 1)
L.slab(r, "MoonGateFlags", "Path", -14, 14, -1562, -1680, 0.2, 1)
-- Frost Ridge: north ledge (y 18), the ridge above the arena's east side, the high shoulder that
-- closes it to the south (y 36, not climbable without the double jump that the veil then stops).
L.slab(r, "RidgeNorth", "Snow", 58, 160, -1246, -1290, 18, 20)
L.slab(r, "RidgeMass", "Rock", 106, 160, -1290, -1440, 18, 20)
L.slab(r, "RidgeShoulder", "Rock", 106, 160, -1440, -1582, 36, 38)
for i, s in { { 39, 13.5, -1268 }, { 46, 15, -1270 }, { 53, 16.5, -1268 } } do
	L.box(r, "FrostStone" .. i, "Snow", s[1], s[2] - 2, s[3], 4, 4, 4, i * 17)
end
L.slab(r, "OverlookFlags", "Path", 108, 150, -1392, -1432, 18.2, 1)
L.wall(r, "OverlookParapet", "Stone", 106.8, -1388, 106.8, -1436, 18, 2.6, 1.4)

-- Arena surround, 14+ studs off the arena edge so the camera keeps its distance: the bamboo palisade
-- (west, north and south), the ridge face (east), the north mouth and the south moon gate.
for _, w in { { -104, -1366, -104, -1574 }, { -104, -1366, -16, -1366 }, { 16, -1366, 106, -1366 }, { -104, -1574, -16, -1574 }, { 16, -1574, 106, -1574 } } do
	L.wall(r, "Palisade", "Timber", w[1], w[2], w[3], w[4], 0, 7, 1.6)
end
-- Gates: the Bamboo Gate (timber torii posts), the shrine posts, the moon gate jambs.
for _, x in { -9, 9 } do
	L.box(r, "GatePost", "Lacquer", x, 8, -1150, 1.6, 16, 1.6)
	L.box(r, "MoonJamb", "Stone", x * 1.9, 9, -1577, 3, 18, 3)
	L.box(r, "MouthPost", "Lacquer", x * 1.75, 7, -1366, 2, 14, 2)
end
L.box(r, "ShrineHall", "Timber", -36, 4.5, -1346, 18, 9, 1.4) -- back screen of the shrine pocket

-- Boundary veil around the walked network.
L.fence(r, "Veil", "Veil", { { -40, -1120 }, { -40, -1296 }, { -66, -1296 }, { -66, -1344 }, { -108, -1344 }, { -108, -1582 }, { -30, -1582 }, { -30, -1680 } }, -10, VEIL_H, 2)
L.fence(r, "Veil", "Veil", { { 40, -1120 }, { 40, -1246 }, { 162, -1246 }, { 162, -1582 }, { 30, -1582 }, { 30, -1680 } }, -10, VEIL_H, 2)

-- Lantern posts at the turns: gate, crest stair head, shrine, Baize's mouth, moon gate, overlook.
for _, l in { { -12, -0.1, -1166 }, { 12, -0.1, -1166 }, { -14, 12, -1254 }, { 14, 12, -1254 }, { -52, 0.2, -1320 }, { -22, -0.1, -1358 },
	{ 22, -0.1, -1358 }, { -20, -0.1, -1590 }, { 20, -0.1, -1590 }, { 112, 18.2, -1430 } } do
	L.lantern(r, l[1], l[2], l[3])
end

-- Points the server and the suite read.
L.mark(r, "Lore_Bamboo", "V · Jade in the Roots", -18, 3, -1140)
L.mark(r, "Lore_Wraith", "VI · What Death Cannot Keep", 128, 21.2, -1428)
L.mark(r, "Altar", "Whispering Bamboo Shrine", -36, 0.2, -1328)
L.mark(r, "Overlook", "Frost Ridge overlook", 112, 18.2, -1410, 270)
L.mark(r, "ArenaMouth", "Baize's mouth", 0, 0.2, -1362)
L.mark(r, "SouthJoin", "Ash road", 0, 0.2, -1678)
L.mark(r, "NorthJoin", "Monastery road", 0, 0.2, -1122)

-- Wayfinding zones (Z0 north edge > Z1 south edge) and doors.
L.zone(r, "BP_Gate", "the bamboo gate", -40, 40, -1120, -1226)
L.zone(r, "BP_Crest", "the frosted crest", -40, 34, -1226, -1292)
L.zone(r, "BP_Shrine", "the whispering shrine", -66, 106, -1292, -1366)
L.zone(r, "BP_Arena", "Baize's arena", -108, 106, -1366, -1582)
L.zone(r, "BP_South", "the ash descent", -30, 30, -1582, -1680)
L.zone(r, "BP_Ridge", "the frost ridge", 34, 160, -1246, -1440)
L.door(r, "DM:Road", "BP_Gate", 0, 0.2, -1120, "Bamboo Gate")
L.door(r, "BP_Gate", "BP_Crest", 0, 0.2, -1226, "Ridge stairs")
L.door(r, "BP_Crest", "BP_Shrine", 0, 0.2, -1316, "Shrine stairs")
L.door(r, "BP_Shrine", "BP_Arena", 0, 0.2, -1366, "Baize's mouth")
L.door(r, "BP_Arena", "BP_South", 0, 0.2, -1580, "Moon gate")
L.door(r, "BP_South", "AC_Road", 0, 0.2, -1680, "Ash road")
L.door(r, "BP_Crest", "BP_Ridge", 36, 12, -1268, "Frost stones")
L.door(r, "BP_Ridge", "BP_Shrine", 70, 0.2, -1292, "Ridge drop", true)
r.SpawnZones = {
	BP_Swordsman_Trail_A = "BP_Gate", BP_Monk_Trail = "BP_Crest", BP_Swordsman_Grove_A = "BP_Ridge",
	BP_Swordsman_Grove_B = "BP_Ridge", BP_Monk_Ridge = "BP_South",
}

-- Bamboo scatter {x0, x1, z0, z1, floor, stalks}: thickets hug the veil so the edge reads as a wall.
r.Groves = {
	{ -200, -44, -1120, -1294, 0, 150 }, { -200, -112, -1300, -1680, 0, 150 }, { -104, -34, -1586, -1680, 0, 40 },
	{ 44, 200, -1120, -1242, 0, 110 }, { 166, 200, -1242, -1680, 0, 70 }, { 34, 200, -1586, -1680, 0, 60 },
	{ 146, 158, -1300, -1386, 18, 20 }, { 110, 158, -1444, -1578, 36, 40 },
}

return L.freeze(r)

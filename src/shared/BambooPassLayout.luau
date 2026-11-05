--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/BambooPassLayout
-- Bamboo Pass (batch 17, findings #22 #27 #28 #32 #44). Walked north to south (-Z):
--   Monastery road -> Bamboo Gate clearing (tablet V, first swordsman) -> ridge stairs to the
--   frosted crest (y 12, monk) -> shrine stairs -> Whispering Bamboo Shrine pocket (altar) ->
--   Baize's mouth -> Baize's arena (BossArenas floor, frost pillars) -> south moon gate -> ash
--   descent (monk) -> Ash Colosseum road.
-- First walk, west of the gate clearing (route batch): Foundry yard -> Casting hall -> stairs -> Bell landing, with the Bell Terrace (altar)
-- west and the Bell Walk east into the crest; off the terrace, the optional Founders' Kiln (cache). The ridge stairs stay built, but their head
-- is barred from the crest side (RouteGates), so lifting that bar is the shortcut back; older saves past the shrine find it open.
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
	-- Narrow ground-bearing stems below the unchanged landing blocks. Their tops overlap the
	-- blocks' undersides; they add no landing or bridge across the established jump gaps.
	local bottom, top = -2, s[2] - 3.2
	L.box(r, "FrostFooting" .. i, "Rock", s[1], (bottom + top) / 2, s[3], 3.5, top - bottom, 3.5, i * 17)
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
L.fence(r, "Veil", "Veil", { { -40, -1120 }, { -40, -1160 }, { -126, -1160 }, { -126, -1203 }, { -194, -1203 }, { -194, -1349 }, { -138, -1349 }, { -138, -1296 },
	{ -66, -1296 }, { -66, -1344 }, { -108, -1344 }, { -108, -1582 }, { -30, -1582 }, { -30, -1680 } }, -10, VEIL_H, 2)
L.fence(r, "Veil", "Veil", { { -70, -1207 }, { -40, -1207 }, { -40, -1263 } }, -10, VEIL_H, 2) -- the clearing's west side, south of the Foundry path
L.fence(r, "Veil", "Veil", { { -40, -1281 }, { -40, -1296 }, { -66, -1296 } }, -10, VEIL_H, 2) -- the crest's west side, south of the Bell Walk
L.fence(r, "Veil", "Veil", { { 40, -1120 }, { 40, -1246 }, { 162, -1246 }, { 162, -1582 }, { 30, -1582 }, { 30, -1680 } }, -10, VEIL_H, 2)

-- Lantern posts at the turns: gate, crest stair head, shrine, Baize's mouth, moon gate, overlook.
for _, l in { { -12, -0.1, -1166 }, { 12, -0.1, -1166 }, { -14, 12, -1254 }, { 14, 12, -1254 }, { -52, 0.2, -1320 }, { -22, -0.1, -1358 },
	{ 22, -0.1, -1358 }, { -20, -0.1, -1590 }, { 20, -0.1, -1590 }, { 112, 18.2, -1430 } } do
	L.lantern(r, l[1], l[2], l[3])
end

-------------------------------------------------------------------------------------------------
-- The Foundry wing (route batch). Floors: yard 0, hall 6, Bell Walk and terrace 20, kiln 10. Art is BambooFoundry; collision is here.
-------------------------------------------------------------------------------------------------
-- Yard: an open fighting floor behind the clearing. Two slag heaps are its only cover.
L.slab(r, "FoundryPath", "Path", -44, -6, -1172, -1184, 0.2, 1)
L.slab(r, "YardFlags", "Path", -105, -44, -1174, -1182, 0.2, 1)
L.slab(r, "YardFlagsToHall", "Path", -105, -89, -1182, -1193, 0.2, 1)
L.box(r, "SlagHeap", "Basalt", -66, 1.4, -1197, 12, 3.2, 7, 18)
L.box(r, "SlagHeap", "Basalt", -112, 1.2, -1168, 9, 2.8, 6, -24)
L.lantern(r, -46, 0.2, -1170)
L.lantern(r, -46, 0.2, -1186)
-- Casting hall: floor raised on stone, walled and roofed, so the terrace beyond stays hidden until its west door.
L.stairs(r, "HallStair", "Path", -97, -1193, -97, -1207, 0, 6, 16)
L.slab(r, "CastingHallFloor", "Stone", -124, -70, -1207, -1250, 6, 8)
local HALL_TOP = 14
for _, w in { { -124, -1207, -105, -1207 }, { -89, -1207, -70, -1207 }, { -70, -1207, -70, -1250 }, { -70, -1250, -124, -1250 },
	{ -124, -1250, -124, -1228 }, { -124, -1216, -124, -1207 } } do
	L.wall(r, "HallWall", "Stone", w[1], w[2], w[3], w[4], 6, HALL_TOP, 2)
end
for _, x in { -110, -84 } do
	for _, z in { -1219, -1238 } do L.box(r, "HallColumn", "Lacquer", x, 6 + HALL_TOP / 2, z, 1.6, HALL_TOP, 1.6) end
end
L.box(r, "CastingPit", "Basalt", -97, 6.6, -1228, 9, 1.2, 9)
-- West door, stoop, and the stair up the terrace's cliff; a parapet closes the open side.
L.slab(r, "HallStoop", "Stone", -140, -124, -1205, -1230, 6, 8)
L.stairs(r, "TerraceStair", "Path", -132, -1230, -132, -1262, 6, 20, 14)
L.wall(r, "StairParapet", "Stone", -124.5, -1250, -124.5, -1262, 0, 23, 1)
-- Landing, where the terrace and the Bell Walk part.
L.slab(r, "BellLanding", "Stone", -140, -124, -1262, -1282, 20, 22)
L.wall(r, "LandingRail", "Stone", -140, -1282.5, -124, -1282.5, 20, 3, 1)
-- Terrace: open sky and the bell; its altar is the wing's safe pocket.
L.slab(r, "BellTerrace", "Rock", -192, -140, -1205, -1292, 20, 24)
L.slab(r, "TerraceFlags", "Path", -176, -140, -1262, -1282, 20.2, 1)
L.slab(r, "AltarFlags", "Path", -180, -158, -1216, -1240, 20.2, 1)
L.slab(r, "TerraceFlagsToAltar", "Path", -176, -162, -1240, -1262, 20.2, 1)
L.wall(r, "TerraceParapet", "Stone", -140.5, -1205, -140.5, -1262, 20, 3, 1)
L.wall(r, "TerraceParapet", "Stone", -140.5, -1282, -140.5, -1292, 20, 3, 1)
L.wall(r, "TerraceParapet", "Stone", -192, -1292.5, -177, -1292.5, 20, 3, 1)
L.wall(r, "TerraceParapet", "Stone", -163, -1292.5, -140, -1292.5, 20, 3, 1)
L.box(r, "BellTowerCore", "Stone", -180, 28.2, -1272, 14, 16, 14) -- the tall tower seen from the gate; only its base collides
for _, c in { { -160, -1250 }, { -150, -1250 }, { -160, -1241 }, { -150, -1241 } } do L.box(r, "BellPost", "Timber", c[1], 27.2, c[2], 1.4, 14, 1.4) end
L.lantern(r, -146, 20, -1258)
L.lantern(r, -146, 20, -1286)
-- Optional: down the south stair to the Founders' Kiln, with the cache at its back.
L.stairs(r, "KilnStair", "Path", -170, -1292, -170, -1312, 20, 10, 14)
L.slab(r, "KilnLedge", "Rock", -192, -140, -1292, -1345, 10, 14)
L.slab(r, "KilnFlags", "Path", -177, -163, -1312, -1332, 10.2, 1)
L.box(r, "KilnStack", "Stone", -148, 17, -1338, 10, 14, 10)
L.lantern(r, -160, 10.2, -1316)
L.lantern(r, -180, 10.2, -1316)
-- Bell Walk: a timber deck on stone piers, widening at the Ringers' Lookout, then down to the crest.
L.slab(r, "BellWalkDeck", "Timber", -124, -100, -1265, -1279, 20, 1.2)
L.slab(r, "RingersLookout", "Stone", -100, -84, -1257, -1287, 20, 21)
L.slab(r, "BellWalkDeck", "Timber", -84, -60, -1265, -1279, 20, 1.2)
L.stairs(r, "WalkDescent", "Path", -60, -1272, -40, -1272, 20, 12, 14, 1)
for _, x in { -118, -108, -76, -66, -52, -44 } do
	local top = if x < -60 then 19.4 elseif x == -52 then 16 else 13
	for _, z in { -1266, -1278 } do L.box(r, "WalkPier", "Stone", x, (top - 1) / 2, z, 2.4, top + 1, 2.4) end
end
for _, seg in { { -124, -100 }, { -84, -60 } } do
	for _, z in { -1264.6, -1279.4 } do L.wall(r, "WalkRail", "Timber", seg[1], z, seg[2], z, 20, 3, 0.8) end
end
for _, w in { { -100, -1257, -84, -1257 }, { -100, -1287, -84, -1287 }, { -100, -1257, -100, -1265 }, { -84, -1257, -84, -1265 }, { -100, -1279, -100, -1287 }, { -84, -1279, -84, -1287 } } do
	L.wall(r, "LookoutRail", "Stone", w[1], w[2], w[3], w[4], 20, 3, 1)
end
for _, z in { -1264.6, -1279.4 } do L.wall(r, "DescentRail", "Timber", -60, z, -40, z, 12, 11, 0.8) end
-- A fall from the walk or its stair lands in the fenced thicket, and the mist carries the body up to the landing.
L.catch(r, "the Bell Walk", -124, -40, -1250, -1296, 9, { -132, 20, -1272, 270 })
L.catch(r, "the Bell Walk", -70, -40, -1207, -1250, 9, { -132, 20, -1272, 270 })
-- The ridge stairs' head: posts and wings stay; RouteGates owns the leaves between them. Wings keep a stair-top hop from going round.
for _, side in { -1, 1 } do
	L.box(r, "RidgeGatePost", "Lacquer", side * 7, 18, -1250.5, 2, 12, 2)
	L.wall(r, "RidgeGateWing", "Timber", side * 8, -1250.5, side * 22, -1250.5, 12, 9, 1)
end
r.Gates = { BambooRidge = { Name = "RidgeGate", Kind = "Timber", X = 0, Y = 16.5, Z = -1250.5, SX = 12, SY = 9, SZ = 1, Yaw = 0 } }
-- What the scatter stays out of. The dressing's own stream is fixed at the count before this wing, so nothing placed earlier moves.
r.DressSeed = 76
r.GroveClear = { { -128, -40, -1160, -1209 }, { -128, -66, -1203, -1254 }, { -198, -120, -1200, -1296 }, { -128, -36, -1258, -1288 }, { -198, -136, -1290, -1352 } }

-- Points the server and the suite read.
L.mark(r, "Lore_Bamboo", "V · Jade in the Roots", -18, 3, -1140)
L.mark(r, "Lore_Wraith", "VI · What Death Cannot Keep", 128, 21.2, -1428)
L.mark(r, "Altar", "Whispering Bamboo Shrine", -36, 0.2, -1328)
L.mark(r, "AltarBell", "Bell Terrace", -169, 20.2, -1228)
L.mark(r, "Lore_Founder", "The Founders' Ledger", -76, 9, -1244)
L.mark(r, "Kiln", "Founders' Kiln", -170, 10.2, -1336)
L.mark(r, "Foundry", "Foundry yard", -80, 0.2, -1178)
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
L.zone(r, "BP_Yard", "the foundry yard", -124, -40, -1162, -1207)
L.zone(r, "BP_Hall", "the casting hall", -124, -70, -1207, -1250, 0)
L.zone(r, "BP_BellStair", "the terrace stair", -140, -124, -1205, -1262)
L.zone(r, "BP_Walk", "the bell walk", -140, -40, -1257, -1287, 9)
L.zone(r, "BP_Terrace", "the bell terrace", -192, -140, -1205, -1292)
L.zone(r, "BP_Kiln", "the founders' kiln", -192, -140, -1292, -1345)
L.door(r, "DM:Road", "BP_Gate", 0, 0.2, -1120, "Bamboo Gate")
L.door(r, "BP_Gate", "BP_Crest", 0, 0.2, -1226, "Ridge stairs", nil, nil, "BambooRidge")
L.door(r, "BP_Gate", "BP_Yard", -40, 0.2, -1178, "Foundry path")
L.door(r, "BP_Yard", "BP_Hall", -97, 6, -1207, "Casting hall")
L.door(r, "BP_Hall", "BP_BellStair", -124, 6, -1222, "Hall's west door")
L.door(r, "BP_BellStair", "BP_Walk", -132, 20, -1262, "Bell landing")
L.door(r, "BP_Walk", "BP_Terrace", -140, 20.2, -1272, "Bell Terrace")
L.door(r, "BP_Terrace", "BP_Kiln", -170, 20, -1292, "Kiln stair")
L.door(r, "BP_Walk", "BP_Crest", -40, 12, -1272, "Bell Walk stairs")
L.door(r, "BP_Crest", "BP_Shrine", 0, 0.2, -1316, "Shrine stairs")
L.door(r, "BP_Shrine", "BP_Arena", 0, 0.2, -1366, "Baize's mouth")
L.door(r, "BP_Arena", "BP_South", 0, 0.2, -1580, "Moon gate")
L.door(r, "BP_South", "AC_Road", 0, 0.2, -1680, "Ash road")
L.door(r, "BP_Crest", "BP_Ridge", 36, 12, -1268, "Frost stones", nil, true)
L.door(r, "BP_Ridge", "BP_Shrine", 70, 0.2, -1292, "Ridge drop", true)
r.SpawnZones = {
	BP_Swordsman_Trail_A = "BP_Gate", BP_Monk_Trail = "BP_Crest", BP_Swordsman_Grove_A = "BP_Ridge",
	BP_Swordsman_Grove_B = "BP_Ridge", BP_Monk_Ridge = "BP_South",
	BP_Monk_Yard = "BP_Yard", BP_Swordsman_Yard = "BP_Yard", BP_Swordsman_Hall = "BP_Hall", BP_Monk_Walk = "BP_Walk",
	BP_Swordsman_Kiln = "BP_Kiln", BP_Monk_Kiln = "BP_Kiln",
}

-- Bamboo scatter {x0, x1, z0, z1, floor, stalks}: thickets hug the veil so the edge reads as a wall.
r.Groves = {
	{ -200, -44, -1120, -1294, 0, 150 }, { -200, -112, -1300, -1680, 0, 150 }, { -104, -34, -1586, -1680, 0, 40 },
	{ 44, 200, -1120, -1242, 0, 110 }, { 166, 200, -1242, -1680, 0, 70 }, { 34, 200, -1586, -1680, 0, 60 },
	{ 146, 158, -1300, -1386, 18, 20 }, { 110, 158, -1444, -1578, 36, 40 },
}

return L.freeze(r)

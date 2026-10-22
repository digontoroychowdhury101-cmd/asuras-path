--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/SkyCitadelLayout
-- Sky Citadel and the final approach (batch 21, findings #22 #27 #28 #32). From the Pagoda's dawn
-- terrace the saddle stair drops to a stone bridge across the cloud chasm (y -20; monk), where the
-- summit's towers and the dragon's perch fill the skyline. Heaven's Stair climbs two flights past the
-- first gate landing (swordsman) to the Last Bastion (y 0: final incense altar, return portal to the
-- shrine, battlements) and the Wyrm's fog gate. The summit plateau (BossArenas floor x -90..90,
-- z -2740..-2920) has no wall, roof or pillar: only a low rim at its edge, so the Wyrm's flight and
-- landings and the camera have open air. Falls into the chasm return to the bridge head; falls from
-- the summit outside a fight return to the bastion (inside a fight the arena returns you itself).
local hasScript = pcall(function() return script.Parent end)
local L: any = if hasScript then (require(script.Parent.RegionLayout) :: any) else (require("./RegionLayout") :: any)

local r = L.region("SkyCitadel")

L.slab(r, "SaddleHead", "Tile", -30, 30, -2540, -2548, 0, 30)
L.stairs(r, "SaddleStair", "Marble", 0, -2548, 0, -2588, 0, -20, 10)
L.slab(r, "SaddleBridge", "Stone", -6, 6, -2588, -2620, -20, 3)
for _, side in { -1, 1 } do
	L.wall(r, "BridgeRail", "Stone", side * 6.5, -2590, side * 6.5, -2618, -20, 1.2, 1)
	L.box(r, "BridgePier", "Rock", side * 4, -60, -2604, 6, 74, 10)
end
L.stairs(r, "HeavenStair", "Marble", 0, -2620, 0, -2640, -20, -10, 12)
L.slab(r, "FirstGateLanding", "Tile", -20, 20, -2640, -2650, -10, 40)
L.stairs(r, "HeavenStair", "Marble", 0, -2650, 0, -2670, -10, 0, 12)
L.slab(r, "LastBastion", "Tile", -72, 72, -2670, -2740, 0, 50)
L.slab(r, "SummitPlateau", "Rock", -96, 96, -2736, -2926, -0.1, 50)
-- Battlements, gate towers, the summit rim (1.2: a visible edge, stepped over), the dragon's perch.
for _, side in { -1, 1 } do
	L.wall(r, "Battlement", "Stone", side * 71.5, -2671, side * 71.5, -2736, 0, 3, 1)
	L.wall(r, "Battlement", "Stone", side * 7, -2670.5, side * 71, -2670.5, 0, 3, 1)
	L.box(r, "GateTower", "Stone", side * 22, 15, -2724, 8, 30, 8)
	L.box(r, "FirstGateTower", "Stone", side * 16, 2, -2645, 6, 24, 6)
	L.wall(r, "SummitRim", "Stone", side * 95, -2738, side * 95, -2925, -0.1, 1.3, 1.4)
	L.wall(r, "SummitRim", "Stone", side * 26, -2737.5, side * 95, -2737.5, -0.1, 1.3, 1.4)
end
L.wall(r, "SummitRim", "Stone", -95, -2925, 95, -2925, -0.1, 1.3, 1.4)
L.box(r, "DragonPerch", "Rock", 0, 20, -2952, 14, 120, 14)

for _, l in { { -24, 0, -2544 }, { 24, 0, -2544 }, { -10, -10, -2642 }, { 10, -10, -2642 }, { -60, 0, -2680 }, { 60, 0, -2680 },
	{ -60, 0, -2730 }, { 58, 0, -2702 } } do
	L.lantern(r, l[1], l[2], l[3])
end

L.fence(r, "Veil", "Veil", { { -30, -2540 }, { -30, -2548 }, { -7, -2548 }, { -7, -2640 }, { -22, -2640 }, { -22, -2670 }, { -74, -2670 }, { -74, -2738 },
	{ -98, -2738 }, { -98, -2928 }, { 98, -2928 }, { 98, -2738 }, { 74, -2738 }, { 74, -2670 }, { 22, -2670 }, { 22, -2640 }, { 7, -2640 }, { 7, -2548 },
	{ 30, -2548 }, { 30, -2540 } }, -60, 280, 2)
L.catch(r, "the cloud bridge", -60, 60, -2540, -2668, -30, { 0, -20, -2592, 0 })
L.catch(r, "the last bastion", -110, 110, -2668, -2980, -20, { 0, 0, -2712, 0 })

L.mark(r, "Altar", "Sky Citadel Incense", -40, 0, -2690)
L.mark(r, "ReturnPortal", "Return to the Shrine", 44, 0, -2690, 90)
L.mark(r, "ArenaMouth", "Wyrm's fog gate", 0, 0, -2722)
L.mark(r, "Bridge", "Cloud bridge", 0, -20, -2604)
L.mark(r, "NorthJoin", "Summit bridge", 0, 0, -2542)

L.zone(r, "SC_Bridge", "the cloud bridge", -30, 30, -2540, -2620)
L.zone(r, "SC_Stair", "heaven's stair", -22, 22, -2620, -2670)
L.zone(r, "SC_Bastion", "the last bastion", -74, 74, -2670, -2738)
L.zone(r, "SC_Arena", "the summit", -98, 98, -2738, -2928)
L.door(r, "SC_Bridge", "SC_Stair", 0, -20, -2620, "Heaven's stair")
L.door(r, "SC_Stair", "SC_Bastion", 0, 0, -2670, "Last bastion")
L.door(r, "SC_Bastion", "SC_Arena", 0, 0, -2738, "Wyrm's fog gate")
r.SpawnZones = { SC_Monk_Bridge = "SC_Bridge", SC_Swordsman_Gate = "SC_Stair" }
r.Groves = {}

return L.freeze(r)

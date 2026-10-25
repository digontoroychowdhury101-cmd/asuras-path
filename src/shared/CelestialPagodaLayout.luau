--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/CelestialPagodaLayout
-- Celestial Pagoda Rafters (batch 20, findings #22 #27 #28 #32 #44). The pagoda's upper storey was
-- torn open; Wu holds its top hall (the arena floor stays at y 0). Walked north to south (-Z):
--   Colosseum causeway -> cloud stair down into the lotus gorge (the light well, y -26) -> the west
--   stair -> the west eave gallery (y -6, monk) -> the rafter beam -> the lantern rafter hub (swordsman)
--   -> the rafter stair up to the forecourt (y 0: incense altar, Wu's fog gate) -> Wu's hall -> the
--   dawn terrace (tablet VIII, the final lore) -> the summit bridge to the Sky Citadel.
-- Optional and bounded: four rafter ends climb off the gallery (single jumps, 4.5 each) to the Throne
-- Loft above the west forecourt - the empty throne and tablet VII. Every fall from the rafters lands
-- on the gorge floor and every fall from the loft on the forecourt; nothing is a mandatory jump.
local hasScript = pcall(function() return script.Parent end)
local L: any = if hasScript then (require(script.Parent.RegionLayout) :: any) else (require("./RegionLayout") :: any)

local r = L.region("CelestialPagoda")

-- Gorge: cliffs either side of the cloud stair, the gorge floor, the forecourt mass at its south.
L.slab(r, "NorthCliff", "Rock", -154, -6, -2120, -2172, 0, 30)
L.slab(r, "NorthCliff", "Rock", 6, 154, -2120, -2172, 0, 30)
L.stairs(r, "CloudStair", "Marble", 0, -2120, 0, -2172, 0.2, -26, 12)
L.slab(r, "GorgeFloor", "Stone", -154, 154, -2172, -2252, -26, 6)
L.slab(r, "Forecourt", "Tile", -154, 90, -2252, -2290, 0, 30)
L.slab(r, "DawnTerrace", "Tile", -30, 30, -2470, -2540, 0, 30)
-- Ascent: west stair, west eave gallery on posts, rafter beam, lantern hub, rafter stair.
L.stairs(r, "WestStair", "Timber", -14, -2184, -60, -2184, -26, -6, 10)
L.slab(r, "EaveGallery", "Timber", -116, -60, -2176, -2240, -6, 2)
for _, x in { -114, -92, -62 } do
	for _, z in { -2178, -2208, -2238 } do
		L.box(r, "GalleryPost", "Lacquer", x, -17, z, 1.6, 18, 1.6)
	end
end
L.slab(r, "RafterBeam", "Timber", -60, -14, -2225, -2231, -6, 1.6)
L.slab(r, "LanternRafter", "Timber", -14, 14, -2216, -2240, -6, 2)
L.box(r, "RafterPost", "Lacquer", -12, -17, -2218, 1.6, 18, 1.6)
L.box(r, "RafterPost", "Lacquer", 12, -17, -2218, 1.6, 18, 1.6)
L.stairs(r, "RafterStair", "Timber", 0, -2240, 0, -2252, -6, 0, 10)
L.wall(r, "GalleryRail", "Lacquer", -60.5, -2190, -60.5, -2224, -6, 2.6, 0.8)
L.wall(r, "GalleryRail", "Lacquer", -115.5, -2177, -115.5, -2239, -6, 2.6, 0.8)
-- Optional: rafter ends (adjacent, each 4.5 higher) to the Throne Loft (y 14) over the west forecourt.
for k, top in { -1.5, 3, 7.5, 12 } do
	L.slab(r, "RafterEnd", "Timber", -114, -110, -2241 - (k - 1) * 4, -2245 - (k - 1) * 4, top, 1.5)
end
L.slab(r, "ThroneLoft", "Timber", -150, -114, -2250, -2290, 14, 2)
for _, x in { -148, -116 } do
	for _, z in { -2252, -2288 } do
		L.box(r, "LoftPost", "Lacquer", x, 6, z, 1.6, 12, 1.6)
	end
end
L.wall(r, "LoftRail", "Lacquer", -150, -2289.5, -114, -2289.5, 14, 2.6, 0.8)
L.wall(r, "LoftRail", "Lacquer", -114.5, -2257, -114.5, -2289, 14, 2.6, 0.8)
L.box(r, "EmptyThrone", "Lacquer", -140, 17, -2280, 6, 6, 4)
-- Hall frame around Wu's floor (outside the arena, behind the veil) and the dawn gate posts.
for _, side in { -1, 1 } do
	for _, z in { -2296, -2340, -2384, -2428, -2466 } do
		L.box(r, "HallColumn", "Lacquer", side * 106, 15, z, 4, 30, 4)
	end
	L.box(r, "DawnPost", "Lacquer", side * 18, 9, -2486, 2.4, 18, 2.4)
	L.box(r, "GateTower", "Tile", side * 20, 12, -2274, 6, 24, 6)
end

for _, l in { { -14, -26, -2178 }, { 14, -26, -2178 }, { -70, 0, -2258 }, { 60, 0, -2258 }, { -24, 0, -2490 }, { 24, 0, -2490 }, { -146, 14, -2284 } } do
	L.lantern(r, l[1], l[2], l[3])
end
for _, l in { { -88, -1, -2208 }, { -38, -1, -2228 }, { 0, 0, -2228 }, { -100, -1, -2236 } } do
	L.light(r, l[1], l[2], l[3]) -- paper lanterns hung from the rafters
end

L.fence(r, "Veil", "Veil", { { -8, -2120 }, { -8, -2172 }, { -156, -2172 }, { -156, -2292 }, { -92, -2292 }, { -92, -2472 }, { -30, -2472 }, { -30, -2540 } }, -40, 260, 2)
L.fence(r, "Veil", "Veil", { { 8, -2120 }, { 8, -2172 }, { 156, -2172 }, { 156, -2254 }, { 92, -2254 }, { 92, -2472 }, { 30, -2472 }, { 30, -2540 } }, -40, 260, 2)

L.mark(r, "Altar", "Celestial Pagoda Rafters Incense", -46, 0, -2268)
L.mark(r, "Lore_Pagoda", "VII · The Empty Throne", -132, 17, -2262)
L.mark(r, "Lore_Dawn", "VIII · The Unwritten Dawn", -20, 3, -2500)
L.mark(r, "ArenaMouth", "Wu's fog gate", 0, 0, -2272)
L.mark(r, "Gorge", "Lotus gorge", 0, -26, -2180)
L.mark(r, "Hub", "Lantern rafter", 0, -6, -2228)
L.mark(r, "NorthJoin", "Cloud stair", 0, 0.2, -2122)
L.mark(r, "SouthJoin", "Summit bridge", 0, 0, -2538)

L.zone(r, "CP_Stair", "the cloud stair", -8, 8, -2120, -2172)
L.zone(r, "CP_Well", "the lotus gorge", -156, 156, -2172, -2252, -40, -16)
L.zone(r, "CP_GalleryW", "the eave gallery", -116, -14, -2176, -2244, -16, -1)
L.zone(r, "CP_Rafter", "the lantern rafter", -14, 14, -2216, -2252, -16, -1)
L.zone(r, "CP_WestStair", "the west stair", -60, -14, -2179, -2189, -27, -4) -- climbs west (Studio F19)
L.zone(r, "CP_Forecourt", "the pagoda forecourt", -156, 92, -2252, -2292, -4, 10)
L.zone(r, "CP_Loft", "the throne loft", -152, -108, -2238, -2292, 10, 30)
L.zone(r, "CP_Arena", "Wu's hall", -92, 92, -2292, -2470)
L.zone(r, "CP_Dawn", "the dawn terrace", -30, 30, -2470, -2540)
L.door(r, "CP_Stair", "CP_Well", 0, -26, -2172, "Lotus gorge")
L.door(r, "CP_Well", "CP_WestStair", -12, -26, -2184, "West stair")
L.door(r, "CP_WestStair", "CP_GalleryW", -62, -6, -2184, "Stair head")
L.door(r, "CP_GalleryW", "CP_Rafter", -14, -6, -2228, "Rafter beam")
L.door(r, "CP_Rafter", "CP_Forecourt", 0, 0, -2252, "Rafter stair")
L.door(r, "CP_Forecourt", "CP_Arena", 0, 0, -2292, "Wu's fog gate")
L.door(r, "CP_Arena", "CP_Dawn", 0, 0, -2470, "Dawn gate")
L.door(r, "CP_Dawn", "SC_Bridge", 0, 0, -2540, "Summit bridge")
L.door(r, "CP_GalleryW", "CP_Loft", -112, 3, -2246, "Rafter ends")
L.door(r, "CP_Loft", "CP_Forecourt", -130, 0, -2270, "Loft drop", true)
L.door(r, "CP_GalleryW", "CP_Well", -88, -26, -2210, "Gallery drop", true)
r.SpawnZones = { CP_Monk_Gallery = "CP_GalleryW", CP_Swordsman_Rafter = "CP_Rafter" }
r.Groves = {}

return L.freeze(r)

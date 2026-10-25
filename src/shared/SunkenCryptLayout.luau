--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/SunkenCryptLayout
-- Sanctuary Depths, the Sunken Crypt promised by the Slumbering Titan (batch 19, #22 #27 #28 #32).
-- The Sanctuary's south pavilion portal delivers to the Descent Landing (y 30) with the return portal
-- right behind the arrival. From there: the descent stair west -> the Incense Gallery (y 15, altar
-- pocket overlooking the nave) -> the gallery stair down -> the nave (sarcophagi, one swordsman) ->
-- Titan's fog gate (BossArenas floor x 430..610, z 790..970) inside a 16-stud ambulatory with a low
-- bone curb as the visible edge, so the camera and Titan's reach meet no wall.
-- Optional: the west ossuary (monk) ends at a flooded pit crossed on seven sarcophagus lids; beyond it
-- the reliquary and the bone stair climb onto the west wall balcony overlooking the arena. Falling
-- into the pit returns you to its north lip. The region sits at x 340..700, far from the shrine, so
-- the Sanctuary's cloud catch never claims crypt play (tools/test_campaign_regions.luau).
local hasScript = pcall(function() return script.Parent end)
local L: any = if hasScript then (require(script.Parent.RegionLayout) :: any) else (require("./RegionLayout") :: any)

local r = L.region("SanctuaryDepths")

-- Floor (14 thick so the pit cannot be walked under) with the pit cut out of it.
L.slab(r, "CryptFloor", "Crypt", 356, 628, 900, 1082, -0.1, 14)
L.slab(r, "CryptFloor", "Crypt", 404, 628, 772, 900, -0.1, 14)
L.slab(r, "CryptFloor", "Crypt", 356, 404, 772, 850, -0.1, 14)
L.slab(r, "PitWater", "Water", 356, 404, 850, 900, -12, 4)
for k = 1, 7 do
	local north = 900 - 2.75 * k - 4 * (k - 1)
	L.box(r, "SarcophagusLid", "Crypt", 366, (if k % 2 == 0 then 0.9 else 0.4) / 2 - 6, north - 2, 5, 12 + (if k % 2 == 0 then 0.9 else 0.4), 4)
end

-- Descent: landing (arrival), stair west, Incense Gallery, gallery stair to the nave.
L.slab(r, "DescentLanding", "Marble", 500, 540, 1048, 1078, 30, 31)
L.stairs(r, "DescentStair", "Marble", 500, 1056, 470, 1056, 30, 15, 12)
L.slab(r, "StairPlinth", "Crypt", 470, 500, 1046, 1062, 13, 14)
L.slab(r, "IncenseGallery", "Marble", 440, 470, 1020, 1078, 15, 16)
L.stairs(r, "GalleryStair", "Marble", 455, 1020, 455, 990, 15, 0.2, 12)
L.wall(r, "GalleryParapet", "Crypt", 440.5, 1020.5, 448, 1020.5, 15, 2.6, 1)
L.wall(r, "GalleryParapet", "Crypt", 462, 1020.5, 469.5, 1020.5, 15, 2.6, 1)
L.wall(r, "LandingParapet", "Crypt", 540.5, 1048, 540.5, 1077, 30, 2.6, 1)
L.wall(r, "LandingParapet", "Crypt", 500.5, 1048.5, 539.5, 1048.5, 30, 2.6, 1)

-- Crypt masses and walls: north band, east and south walls, the west wall that carries the balcony.
L.slab(r, "CryptMass", "Crypt", 356, 440, 1046, 1078, 40, 41)
L.slab(r, "CryptMass", "Crypt", 470, 500, 1062, 1078, 40, 41)
L.slab(r, "CryptMass", "Crypt", 540, 628, 1046, 1078, 40, 41)
L.wall(r, "CryptWall", "Crypt", 358, 1080, 626, 1080, -0.1, 60, 4)
L.wall(r, "CryptWall", "Crypt", 628, 772, 628, 1078, -0.1, 40, 4)
L.wall(r, "CryptWall", "Crypt", 356, 772, 628, 772, -0.1, 40, 4)
L.wall(r, "CryptWall", "Crypt", 356, 772, 356, 1046, -0.1, 40, 4)
L.slab(r, "BalconyWall", "Crypt", 404, 414, 774, 968, 16, 17)
L.wall(r, "BalconyParapet", "Bone", 413.5, 834, 413.5, 966, 16, 2.6, 1)
L.slab(r, "ReliquaryLoft", "Crypt", 376, 404, 832, 850, 16, 17)
L.stairs(r, "BoneStair", "Bone", 380, 800, 380, 832, 0.2, 16, 8)

-- The arena's visible edge: a low bone curb (steps over it; the fog seal does the real work).
L.wall(r, "ArenaCurb", "Bone", 429, 789, 429, 970, -0.1, 1.3, 1)
L.wall(r, "ArenaCurb", "Bone", 611, 789, 611, 970, -0.1, 1.3, 1)
L.wall(r, "ArenaCurb", "Bone", 429, 789, 611, 789, -0.1, 1.3, 1)
L.wall(r, "ArenaCurb", "Bone", 429, 971, 503, 971, -0.1, 1.3, 1)
L.wall(r, "ArenaCurb", "Bone", 537, 971, 611, 971, -0.1, 1.3, 1)
-- Nave sarcophagi (cover, off the walked line from the gallery stair to the gate).
for _, s in { { 384, 1012 }, { 404, 1028 }, { 384, 1036 }, { 572, 1004 }, { 596, 1020 }, { 572, 1034 } } do
	L.box(r, "Sarcophagus", "Crypt", s[1], 1.5, s[2], 4, 3, 8)
end
for _, x in { 498, 542 } do
	L.box(r, "Pillar", "Crypt", x, 12, 992, 4, 24, 4) -- the gate's guardian columns
end

for _, l in { { 534, 30, 1070 }, { 444, 15, 1064 }, { 440, -0.1, 982 }, { 600, -0.1, 982 }, { 384, -0.1, 906 }, { 360, -0.1, 790 } } do
	L.lantern(r, l[1], l[2], l[3])
end
L.light(r, 520, 26, 1000) -- censer chain over the gate approach

L.fence(r, "Veil", "Veil", { { 354, 770 }, { 630, 770 }, { 630, 1084 }, { 354, 1084 }, { 354, 770 } }, -20, 220, 2)
L.catch(r, "the pit's edge", 356, 404, 850, 900, -6, { 366, 0.2, 904, 0 })

L.mark(r, "Arrival", "Descent Landing", 520, 30, 1062, 0)
L.mark(r, "ReturnPortal", "Return to the Shrine", 520, 30, 1074, 0)
L.mark(r, "Altar", "Sanctuary Depths Incense", 455, 15, 1046)
L.mark(r, "ArenaMouth", "Titan's fog gate", 520, 0, 988)
L.mark(r, "PitLip", "Flooded pit", 366, 0.2, 904)
L.mark(r, "Overlook", "Ossuary balcony", 409, 16, 900, 270)
L.mark(r, "Reliquary", "Bone reliquary", 366, 0.2, 812)

L.zone(r, "SD_Descent", "the descent", 440, 544, 1020, 1080, 8, 40)
L.zone(r, "SD_Nave", "the crypt nave", 356, 628, 968, 1046, -4, 14)
L.zone(r, "SD_Ossuary", "the ossuary", 356, 404, 900, 968, -14, 14)
L.zone(r, "SD_Reliquary", "the reliquary", 356, 404, 774, 900, -4, 14) -- and the lid causeway over the pit (follow-up 18)
L.zone(r, "SD_Loft", "the ossuary balcony", 376, 414, 774, 968, 14, 30)
L.zone(r, "SD_Arena", "the Titan's hall", 414, 626, 774, 968, -4, 14)
L.door(r, "SD_Descent", "SD_Nave", 455, 0.2, 990, "Gallery stair")
L.door(r, "SD_Nave", "SD_Arena", 520, 0.2, 970, "Titan's fog gate")
L.door(r, "SD_Nave", "SD_Ossuary", 380, 0.2, 968, "Ossuary")
L.door(r, "SD_Ossuary", "SD_Reliquary", 366, 0.2, 901, "Sarcophagus lids") -- the pit lip; the line then runs down the lids
L.door(r, "SD_Reliquary", "SD_Loft", 380, 16, 832, "Bone stair")
L.door(r, "SD_Loft", "SD_Arena", 414, 0.2, 900, "Balcony drop", true)
r.SpawnZones = { SD_Swordsman_Nave = "SD_Nave", SD_Monk_Ossuary = "SD_Ossuary" }
r.Groves = {}

return L.freeze(r)

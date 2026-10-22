--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/SanctuaryRoutes
-- Player-scale routes added around the existing shrine (batch 16, findings #27 #28 #31 #32). The plaza,
-- stairs, gate, loggia and the Veiled Ascetic stay as built; this adds, as boxes the offline suite walks:
--   * The pilgrim walk out of the plaza's south opening (behind the spawn, away from the story gate)
--     to the Well of Descent pavilion: the Sunken Crypt portal, and the arrival point of its return leg.
--   * Cloud Reliquary: three cloud shards off the pavilion's east rail (single jumps, 3-stud gaps)
--     to an isle holding the cache - optional and deliberate; a miss falls to the cloud catch.
--   * Loggia Eaves: a service ledge round the forge pavilion's south side, the ladder (LootWorld) and a
--     railed lookout deck past the roof line - the cache no longer sits inside the roof ridge.
--   * Reveal points: viewing wings beside the gate on the landing and two pilgrim daises on the
--     terrace's front flanks, where her whole figure fits a normal camera with the tree behind.
--   * A rim parapet around the colossus terrace, open only where the landing and its wings join it.
local hasScript = pcall(function() return script.Parent end)
local L: any = if hasScript then (require(script.Parent.RegionLayout) :: any) else (require("./RegionLayout") :: any)

local r = L.region("Sanctuary")
local Y = 600 -- plaza flagstones; the landing and terrace are at 620
local TERRACE = { X = 0, Z = 555, Radius = 246, Top = 620 } -- SanctuaryColossus: centre and slab
local FIGURE = { X = 0, Z = 705 } -- her seat (terrace centre + TreeSpan.Forward)

-- Pilgrim walk and the Well of Descent.
L.slab(r, "PilgrimWalk", "Path", -6, 6, 946, 972, Y, 3)
for _, side in { -1, 1 } do
	L.wall(r, "PilgrimRail", "Stone", side * 6.4, 947, side * 6.4, 972, Y, 1.4, 0.8)
end
L.slab(r, "DescentPavilion", "Marble", -16, 16, 972, 1004, Y, 6)
-- Lobby rebuild: the four columns of the pyramidal roof over the Well (SanctuaryApproach).
for _, x in { -10, 10 } do
	for _, z in { 979, 997 } do
		L.box(r, "WellColumn", "Lacquer", x, Y + 5, z, 1.3, 10, 1.3)
	end
end
L.wall(r, "PavilionRail", "Stone", -15.6, 972, -15.6, 1004, Y, 2.6, 0.8)
L.wall(r, "PavilionRail", "Stone", -16, 1003.6, 16, 1003.6, Y, 2.6, 0.8)
L.wall(r, "PavilionRail", "Stone", 15.6, 972, 15.6, 983, Y, 2.6, 0.8)
L.wall(r, "PavilionRail", "Stone", 15.6, 993, 15.6, 1004, Y, 2.6, 0.8)
L.wall(r, "PavilionRail", "Stone", -16, 972.4, -6.8, 972.4, Y, 2.6, 0.8)
L.wall(r, "PavilionRail", "Stone", 6.8, 972.4, 16, 972.4, Y, 2.6, 0.8)
-- Cloud Reliquary stones and isle (cache SanctuaryReliquary sits on it).
for i, top in { 601, 602, 603 } do
	L.slab(r, "CloudShard" .. i, "Marble", 12 + i * 7, 16 + i * 7, 985, 991, top, 3)
end
L.slab(r, "ReliquaryIsle", "Marble", 40, 52, 980, 996, 604, 5)
-- Loggia Eaves: service ledge, deck rails (the 8x8 deck and ladder are LootWorld's).
L.slab(r, "ServiceLedge", "Path", -66, -60, 907, 922, Y, 3)
L.slab(r, "ServiceLedge", "Path", -102, -66, 918, 922, Y, 3)
L.wall(r, "LookoutRail", "Timber", -80.4, 919.5, -80.4, 927, 616, 2.4, 0.6)
L.wall(r, "LookoutRail", "Timber", -71.6, 919.5, -71.6, 927, 616, 2.4, 0.6)
L.wall(r, "LookoutRail", "Timber", -80.4, 927.4, -71.6, 927.4, 616, 2.4, 0.6)
-- Reveal points: landing wings beside the gate, pilgrim daises on the terrace's front flanks.
for _, side in { -1, 1 } do
	L.slab(r, "ViewingWing", "Path", side * 21, side * 33, 794, 814, 620, 10)
	L.wall(r, "WingRail", "Stone", side * 32.6, 794, side * 32.6, 814, 620, 2.6, 0.8)
	L.wall(r, "WingRail", "Stone", side * 21, 813.6, side * 33, 813.6, 620, 2.6, 0.8)
	local a = math.rad(side * 40)
	local x, z = TERRACE.X + math.sin(a) * 205, TERRACE.Z + math.cos(a) * 205
	L.box(r, "PilgrimDais", "Stone", x, TERRACE.Top + 0.6, z, 12, 1.2, 12, math.deg(math.atan2(x - FIGURE.X, z - FIGURE.Z)))
	L.mark(r, if side < 0 then "RevealWingW" else "RevealWingE", "Viewing wing", side * 27, 620, 804)
	L.mark(r, if side < 0 then "RevealDaisW" else "RevealDaisE", "Pilgrim dais", x, TERRACE.Top + 1.2, z)
end
-- Rim parapet: 2.6 high, open for 9 degrees either side of the landing and its viewing wings.
for k = 0, 56 do
	local a0, a1 = math.rad(9 + k * 6), math.rad(15 + k * 6)
	local rr = TERRACE.Radius - 2
	L.wall(r, "TerraceParapet", "Stone", TERRACE.X + math.sin(a0) * rr, TERRACE.Z + math.cos(a0) * rr,
		TERRACE.X + math.sin(a1) * rr, TERRACE.Z + math.cos(a1) * rr, TERRACE.Top, 2.6, 1.2)
end

L.mark(r, "CryptDescent", "Descend to the Sunken Crypt", 0, Y, 996, 0)
L.mark(r, "CryptReturn", "Well of Descent", 0, Y, 984, 0) -- faces north, back toward the plaza
L.mark(r, "Figure", "The Veiled Ascetic", FIGURE.X, 700, FIGURE.Z)
r.Terrace = TERRACE

return L.freeze(r)

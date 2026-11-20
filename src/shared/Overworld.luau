--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/Overworld
-- Canonical, engine-free data for the replacement overworld (GEOGRAPHY_PLAN.md). Every consumer
-- (terrain, regions, altars, route, map, compass, weather, encounters) reads this one table; there
-- is no second topology. Plain numbers, studs, yaw in degrees, north = world -Z, east = +X.
-- WorldDefinitions calls Overworld.apply(World) only while Overworld.Active is true. Active stays
-- true since the cutover (ticket 08): the old campaign regions, altars, gates and arenas leave the world.
-- Y values are planned elevations and are re-surveyed once terrain exists.

local Overworld: any = {}

-- Offline tests of the archived campaign builders text-replace this line with false to load the old corridor world.
Overworld.Active = true
Overworld.Root = "Map_Overworld"
-- Region transitions blend over this many studs centred on each shared border.
Overworld.Blend = 200
Overworld.Frame = { MinX = -10000, MaxX = -1600, MinZ = -9200, MaxZ = -800, WaterY = 0 }
Overworld.DomainId = "AshColosseum"

local function v(x: number, y: number, z: number) return { X = x, Y = y, Z = z } end
local function at(x: number, y: number, z: number, yaw: number) return { X = x, Y = y, Z = z, Yaw = yaw } end
-- The gate looks west across the processional bridge toward Snow Refuge.
Overworld.Vesperhold = at(-2800, 650, -6400, -90)

-- Fade the ridge's cold air across its flanks and the last stretch into Snow Refuge.
function Overworld.vesperholdWeight(x: number, z: number): number
	local g = Overworld.Vesperhold
	local outside = math.max(math.abs(z - g.Z) - 175, g.X - 490 - x, x - (g.X + 430), 0)
	local t = math.clamp(1 - outside / 85, 0, 1)
	return t*t*(3-2*t)
end
-- Box from X, Z and Y extents.
local function box(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number)
	return { Center = v((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Size = v(x1 - x0, y1 - y0, z1 - z0) }
end

-------------------------------------------------------------------------------------------------
-- Regions. Bounds are data only; the real borders are the transition bands below. The five boxes tile
-- Frame in XZ without overlap and their Y bands reach past every surface point (T09a: a grid of surface
-- points must all resolve to a region). The AshColosseum domain sits inside Mountain's box and is checked first.
-------------------------------------------------------------------------------------------------

local function region(id: string, name: string, biome: string, bounds: any, color: { number }, material: string, ambience: string)
	return { Id = id, Name = name, Biome = biome, Bounds = bounds, MapFolder = Overworld.Root, Blend = Overworld.Blend,
		Greybox = { Color = color, Material = material }, Ambience = ambience }
end

Overworld.RegionIds = { "Forest", "GoldenRavine", "AridBasin", "Snowfields", "MountainAscent" }
Overworld.Regions = {
	Forest = region("Forest", "The Bellwood", "Forest", box(-5200, -1600, -4200, -800, -100, 500), { 68, 92, 58 }, "Grass", "WindReeds"),
	GoldenRavine = region("GoldenRavine", "Amberfall Ravine", "DryRavine", box(-7600, -5200, -4200, -800, -200, 600), { 176, 140, 84 }, "Sand", "TempleBells"),
	AridBasin = region("AridBasin", "The Saltreach", "Arid", box(-10000, -7600, -4200, -800, -100, 450), { 190, 168, 128 }, "Sand", "WindReeds"),
	Snowfields = region("Snowfields", "Frostmere Heads", "Snow", box(-5600, -1600, -9200, -4200, 250, 1050), { 220, 228, 236 }, "Snow", "WindReeds"),
	MountainAscent = region("MountainAscent", "The Ashen Stair", "Alpine", box(-10000, -5600, -9200, -4200, 100, 1750), { 96, 92, 90 }, "Rock", "WindReeds"),
	-- Shen's sealed sanctum behind the summit barrier. Same Map_Overworld root: WorldService looks the
	-- folder up recursively, and one root suppresses the greybox of every overworld region.
	AshColosseum = region("AshColosseum", "Ash Colosseum", "Sanctum", box(-7270, -7130, -8325, -8175, 1565, 1635), { 58, 54, 52 }, "Basalt", "EmberCrowd"),
}

-- Shared borders: 150..400 stud authored bands (terrain, vegetation and material gradient).
Overworld.Bands = {
	{ A = "Forest", B = "GoldenRavine", Width = 400, Kind = "ridge" }, -- the N-S divide
	{ A = "Forest", B = "Snowfields", Width = 250, Kind = "river" }, -- headwater river from the gorge
	{ A = "GoldenRavine", B = "AridBasin", Width = 300, Kind = "dry channel" },
	{ A = "GoldenRavine", B = "MountainAscent", Width = 250, Kind = "foothills" },
	{ A = "AridBasin", B = "MountainAscent", Width = 350, Kind = "foothills" },
	{ A = "Snowfields", B = "MountainAscent", Width = 300, Kind = "ridge" }, -- White Pass saddle
	{ A = "Snowfields", B = "GoldenRavine", Width = 250, Kind = "ridge" }, -- the divide's northern end
}

-- One continuous N-S ridge (rain shadow): Ashen Stair spur -> monastery ridge -> Amberfall east rim.
Overworld.Divide = {
	v(-5400, 520, -5000), v(-5300, 450, -4500), v(-5150, 350, -4000), v(-5050, 290, -3500), v(-5100, 300, -3000),
	v(-5250, 310, -2500), v(-5350, 300, -2000), v(-5300, 300, -1600), v(-5400, 300, -1200),
}

-------------------------------------------------------------------------------------------------
-- Altars (WorldDefinitions.Altar shape). Kept IDs relocate; four are new places.
-------------------------------------------------------------------------------------------------

local function altar(id: string, name: string, region: string, x: number, y: number, z: number, yaw: number, exit: any)
	return { Id = id, Name = name, Region = region, Placement = at(x, y, z, 0), Spawn = at(x, y + 3, z - 8, yaw),
		Radius = 9, Starting = false, Exit = at(exit[1], y + 3, exit[2], 0) }
end

Overworld.Altars = {
	Altar_MonasteryGate = altar("Altar_MonasteryGate", "Gateway Glade", "Forest", -2200, 60, -1400, 0, { -2200, -1440 }),
	Altar_BellTerrace = altar("Altar_BellTerrace", "Bell Terrace", "Forest", -3000, 140, -2000, 180, { -2980, -2040 }),
	Altar_BambooShrine = altar("Altar_BambooShrine", "Whispering Bamboo Shrine", "Forest", -2600, 220, -3600, 306, { -2570, -3640 }),
	Altar_DesecratedCloister = altar("Altar_DesecratedCloister", "Desecrated Cloister", "Forest", -4400, 200, -3900, 0, { -4440, -3940 }),
	Altar_ColosseumAntechamber = altar("Altar_ColosseumAntechamber", "Colosseum Antechamber", "MountainAscent", -7200, 1550, -8000, 0, { -7200, -8040 }),
	Altar_RavineOverlook = altar("Altar_RavineOverlook", "Ravine Overlook", "GoldenRavine", -5550, 300, -3150, 270, { -5600, -3150 }),
	Altar_BasinCistern = altar("Altar_BasinCistern", "Basin Cistern", "AridBasin", -8100, 40, -2300, 0, { -8100, -2340 }),
	Altar_SnowRefuge = altar("Altar_SnowRefuge", "Snow Refuge", "Snowfields", -3400, 620, -6400, 0, { -3400, -6440 }),
	Altar_MountainRefuge = altar("Altar_MountainRefuge", "Mountain Refuge", "MountainAscent", -7750, 1000, -6500, 0, { -7750, -6540 }),
}

-- Retired altars stay in saved unlockedAltars; an activeAltar pointing at one respawns at the glade.
Overworld.RetiredAltars = {
	Altar_SanctuaryDepths = "Altar_MonasteryGate",
	Altar_CelestialPagoda = "Altar_MonasteryGate",
	Altar_SkyCitadel = "Altar_MonasteryGate",
}
-- Old campaign regions (not persisted keys). apply() removes them from the world.
Overworld.RetiredRegions = { "DesecratedMonastery", "BambooPass", "SanctuaryDepths", "CelestialPagoda", "SkyCitadel" }

-------------------------------------------------------------------------------------------------
-- Caches, lore, miniboss (positions only; rewards and text stay in ArsenalCatalog / NarrativeCatalog)
-------------------------------------------------------------------------------------------------

Overworld.Caches = {
	WaterfallAlcove = { Id = "WaterfallAlcove", Region = "Forest", Subarea = "F3", Position = v(-2820, 100, -2850) },
	SealedMausoleum = { Id = "SealedMausoleum", Region = "GoldenRavine", Subarea = "G4", Position = v(-6450, 290, -3250) },
	FoundersKiln = { Id = "FoundersKiln", Region = "AridBasin", Subarea = "B3", Position = v(-8520, 122, -3320) },
	PagodaRafters = { Id = "PagodaRafters", Region = "MountainAscent", Subarea = "M5", Position = v(-7180, 1620, -8060) },
	FrostWatchpost = { Id = "FrostWatchpost", Region = "Snowfields", Subarea = "S3", Position = v(-3520, 812, -7310), New = true },
	SaltCaravan = { Id = "SaltCaravan", Region = "AridBasin", Subarea = "B6", Position = v(-9510, 48, -1410), New = true },
}

Overworld.Lore = {
	Pillars = { Id = "Pillars", Region = "Forest", Subarea = "F5", Position = v(-4300, 205, -3800) },
	Feast = { Id = "Feast", Region = "Forest", Subarea = "F5", Position = v(-4250, 205, -3950) },
	Bell = { Id = "Bell", Region = "Forest", Subarea = "F5", Position = v(-4520, 210, -3750) },
	Emissary = { Id = "Emissary", Region = "Forest", Subarea = "F5", Position = v(-4600, 205, -4000) },
	Bamboo = { Id = "Bamboo", Region = "Forest", Subarea = "F4", Position = v(-2520, 225, -3700) },
	Founder = { Id = "Founder", Region = "Forest", Subarea = "F4", Position = v(-2750, 220, -3520) },
	Wraith = { Id = "Wraith", Region = "Forest", Subarea = "F4", Position = v(-2400, 230, -3850) },
	Pagoda = { Id = "Pagoda", Region = "MountainAscent", Subarea = "M5", Position = v(-7150, 1556, -8030) },
	Dawn = { Id = "Dawn", Region = "MountainAscent", Subarea = "M5", Position = v(-7260, 1556, -8060) },
}

-- Spawn keeps its stable id; WorldDefinitions.Spawns is repointed at ticket 08.
Overworld.Minibosses = {
	HollowBellWarden = { Id = "HollowBellWarden", Spawn = "DM_Warden_Graves", Region = "Forest", Subarea = "F2", Placement = at(-3060, 140, -2060, 90), Radius = 4 },
}

-- PvP rings keep their ids (saved match records name only the id); Ring_SanctuaryPromenade stays in the
-- lobby. Y is the ring floor height: the pad is flattened at Y - 2 because written terrain voxels surface about
-- 2 studs above heightAt (measured in Studio), so the floor lands on the voxel surface.
Overworld.Rings = {
	Ring_GatehouseCircle = { Region = "Forest", X = -2300, Y = 61, Z = -1320 },
	Ring_OctagonOfAsh = { Region = "MountainAscent", X = -8425, Y = 292, Z = -4625 },
}

-- The tutorial's Sparring Phantom keeps its spawn id (client and server look it up) on the glade, with the
-- same offset from the altar as at the old Monastery Gate.
Overworld.Training = { Spawn = "DM_Sparring_Phantom", Region = "Forest", Placement = at(-2185, 60, -1385, 200), Radius = 3 }

-------------------------------------------------------------------------------------------------
-- Ordinary encounters (ticket 09). The existing archetypes stand on flat, dry, road-side ground picked by a
-- scan of the road centrelines (grade over a 10 stud ring within the biome tolerance, off the chasm and the
-- channels) and keep clear of altars, arrival points, rings, caches, the summit gate and the glade. X, Z are
-- authored; Y is heightAt (a test re-derives it). WorldDefinitions spawns each at floor Y + 2 (the written
-- voxel surface), root 3 above it. Each home lies at least LeashRange + 12 inside its region box, so a
-- foe returning past its leash never leaves the biome, and at least Clearance.Margin beyond every
-- checkpoint's reach (leash + ring), so none is dragged into a rest or arrival point.
-- Terrain wiring: EncounterSpots mirrors Training/Minibosses ({ Spawn, Placement }) for OverworldTerrain.
-------------------------------------------------------------------------------------------------

local function group(id: string, region: string, edge: string, spawns: { any })
	local members = {}
	for _, s in spawns do
		table.insert(members, { Id = s[1], Mob = s[2], Region = region, X = s[3], Z = s[4], Y = s[5], Yaw = s[6], Radius = s[7], Group = id })
	end
	return { Id = id, Region = region, Edge = edge, Spawns = members }
end

Overworld.Encounters = {
	-- Metres of slack added to leash + checkpoint reach; the glade stays fight-free out to Glade studs.
	Clearance = { Margin = 10, Glade = 300, Ring = 34, Cache = 60, Gate = 150, Group = 140, Miniboss = 100 },
	-- Share of each region's foes that are Corrupt Wandering Monks (the rest Cursed Swordsmen); tests hold the actual share within 0.15.
	Mix = { Forest = 0.55, GoldenRavine = 0.4, AridBasin = 0.5, Snowfields = 0.6, MountainAscent = 0.35 },
	Groups = {
		group("Fo01", "Forest", "Altar_MonasteryGate>Altar_BellTerrace", { { "Fo01_A", "CorruptWanderingMonk", -2540, -1606, 83.8, 263, 5 } }),
		group("Fo02", "Forest", "Altar_MonasteryGate>Altar_BellTerrace", { { "Fo02_A", "CursedSwordsman", -2754, -1854, 125.2, 202, 5 } }),
		group("Fo03", "Forest", "Altar_BellTerrace>Altar_BambooShrine", { { "Fo03_A", "CorruptWanderingMonk", -2825, -2383, 131.2, 192, 5 }, { "Fo03_B", "CorruptWanderingMonk", -2827, -2396, 130.7, 192, 5 } }),
		group("Fo04", "Forest", "Altar_BellTerrace>Altar_BambooShrine", { { "Fo04_A", "CursedSwordsman", -2872, -2909, 109.3, 148, 5 } }),
		group("Fo05", "Forest", "Altar_BellTerrace>Altar_BambooShrine", { { "Fo05_A", "CursedSwordsman", -2594, -3451, 207.3, 191, 5 }, { "Fo05_B", "CorruptWanderingMonk", -2597, -3464, 208.6, 191, 5 } }),
		group("Fo06", "Forest", "Altar_BambooShrine>Altar_DesecratedCloister", { { "Fo06_A", "CursedSwordsman", -3132, -3721, 229.8, 286, 5 }, { "Fo06_B", "CorruptWanderingMonk", -3145, -3717, 230.0, 286, 5 } }),
		group("Fo07", "Forest", "Altar_BambooShrine>Altar_DesecratedCloister", { { "Fo07_A", "CorruptWanderingMonk", -3688, -3722, 251.6, 237, 5 }, { "Fo07_B", "CorruptWanderingMonk", -3700, -3730, 252.2, 237, 5 } }),
		group("Fo08", "Forest", "Altar_BambooShrine>Altar_DesecratedCloister", { { "Fo08_A", "CursedSwordsman", -4108, -3943, 235.3, 282, 5 }, { "Fo08_B", "CursedSwordsman", -4122, -3940, 233.4, 282, 5 } }),
		group("Fo09", "Forest", "Altar_MonasteryGate>F3_RiverRavine", { { "Fo09_A", "CorruptWanderingMonk", -2647, -2030, 124.3, 200, 5 } }),
		group("Fo10", "Forest", "F3_RiverRavine>Altar_BambooShrine", { { "Fo10_A", "CorruptWanderingMonk", -2715, -3114, 136.9, 222, 5 }, { "Fo10_B", "CursedSwordsman", -2724, -3124, 139.0, 222, 5 } }),
		group("Go01", "GoldenRavine", "Altar_RavineOverlook>G4_FarSide", { { "Go01_A", "CursedSwordsman", -5690, -3291, 294.5, 288, 5 } }),
		group("Go02", "GoldenRavine", "Altar_RavineOverlook>G4_FarSide", { { "Go02_A", "CursedSwordsman", -6210, -3280, 291.6, 235, 5 }, { "Go02_B", "CorruptWanderingMonk", -6221, -3288, 291.6, 235, 5 } }),
		group("Go03", "GoldenRavine", "G4_FarSide>B1_CaravanDescent", { { "Go03_A", "CorruptWanderingMonk", -6733, -3155, 291.4, 308, 5 }, { "Go03_B", "CursedSwordsman", -6744, -3146, 290.9, 308, 5 } }),
		group("Go04", "GoldenRavine", "G4_FarSide>B1_CaravanDescent", { { "Go04_A", "CursedSwordsman", -7187, -3018, 238.8, 244, 5 } }),
		group("Go05", "GoldenRavine", "G4_FarSide>G4_NorthRim", { { "Go05_A", "CorruptWanderingMonk", -6607, -3621, 320.5, 204, 5 } }),
		group("Ar01", "AridBasin", "B1_CaravanDescent>Altar_BasinCistern", { { "Ar01_A", "CursedSwordsman", -7833, -2660, 144.6, 348, 5 }, { "Ar01_B", "CorruptWanderingMonk", -7835, -2646, 142.3, 348, 5 } }),
		group("Ar02", "AridBasin", "Altar_BasinCistern>B3_KilnWorks", { { "Ar02_A", "CorruptWanderingMonk", -8310, -2704, 138.1, 222, 5 }, { "Ar02_B", "CorruptWanderingMonk", -8320, -2714, 140.3, 222, 5 } }),
		group("Ar03", "AridBasin", "Altar_BasinCistern>B3_KilnWorks", { { "Ar03_A", "CursedSwordsman", -8359, -3062, 149.1, 182, 5 } }),
		group("Ar04", "AridBasin", "B3_KilnWorks>M1_PassFoot", { { "Ar04_A", "CursedSwordsman", -8434, -3770, 212.0, 199, 5 }, { "Ar04_B", "CorruptWanderingMonk", -8439, -3783, 213.8, 199, 5 } }),
		group("Ar05", "AridBasin", "Altar_BasinCistern>B5_Canyon", { { "Ar05_A", "CursedSwordsman", -8374, -2855, 155.2, 246, 5 } }),
		group("Ar06", "AridBasin", "Altar_BasinCistern>B5_Canyon", { { "Ar06_A", "CorruptWanderingMonk", -8700, -3433, 157.0, 169, 5 }, { "Ar06_B", "CorruptWanderingMonk", -8697, -3446, 158.4, 169, 5 } }),
		group("Ar07", "AridBasin", "B5_Canyon>M1_PassFoot", { { "Ar07_A", "CursedSwordsman", -8918, -4031, 162.8, 95, 5 }, { "Ar07_B", "CursedSwordsman", -8904, -4033, 165.2, 95, 5 } }),
		group("Sn01", "Snowfields", "Altar_BambooShrine>S1_HeadwaterGorge", { { "Sn01_A", "CorruptWanderingMonk", -2655, -4774, 431.4, 168, 5 } }),
		group("Sn02", "Snowfields", "S1_HeadwaterGorge>Altar_SnowRefuge", { { "Sn02_A", "CorruptWanderingMonk", -3079, -5590, 496.7, 232, 5 }, { "Sn02_B", "CorruptWanderingMonk", -3090, -5598, 498.5, 232, 5 } }),
		group("Sn03", "Snowfields", "S1_HeadwaterGorge>Altar_SnowRefuge", { { "Sn03_A", "CursedSwordsman", -3191, -6095, 585.8, 180, 5 } }),
		group("Sn04", "Snowfields", "Altar_SnowRefuge>S5_WhitePass", { { "Sn04_A", "CorruptWanderingMonk", -3917, -6612, 633.0, 288, 5 } }),
		group("Sn05", "Snowfields", "Altar_SnowRefuge>S5_WhitePass", { { "Sn05_A", "CursedSwordsman", -4475, -6433, 628.9, 257, 5 }, { "Sn05_B", "CorruptWanderingMonk", -4488, -6437, 630.3, 257, 5 } }),
		group("Sn06", "Snowfields", "Altar_SnowRefuge>S5_WhitePass", { { "Sn06_A", "CursedSwordsman", -4905, -6775, 743.8, 226, 5 } }),
		group("Sn07", "Snowfields", "S1_HeadwaterGorge>S3_Watchpost", { { "Sn07_A", "CursedSwordsman", -3369, -6207, 608.6, 180, 5 }, { "Sn07_B", "CorruptWanderingMonk", -3369, -6221, 609.7, 180, 5 } }),
		group("Mo01", "MountainAscent", "M1_PassFoot>M2_RockSteps", { { "Mo01_A", "CursedSwordsman", -8064, -5380, 593.2, 149, 5 }, { "Mo01_B", "CorruptWanderingMonk", -8057, -5392, 596.8, 149, 5 } }),
		group("Mo02", "MountainAscent", "M2_RockSteps>Altar_MountainRefuge", { { "Mo02_A", "CursedSwordsman", -7943, -5767, 659.2, 168, 5 } }),
		group("Mo03", "MountainAscent", "M1_WhitePassFoot>Altar_MountainRefuge", { { "Mo03_A", "CursedSwordsman", -6577, -6515, 1008.6, 308, 5 } }),
		group("Mo04", "MountainAscent", "M1_WhitePassFoot>Altar_MountainRefuge", { { "Mo04_A", "CorruptWanderingMonk", -7118, -6579, 1019.9, 237, 5 }, { "Mo04_B", "CursedSwordsman", -7130, -6586, 1018.7, 237, 5 } }),
		group("Mo05", "MountainAscent", "Altar_MountainRefuge>M4_ThousandSteps", { { "Mo05_A", "CursedSwordsman", -7631, -6748, 1005.3, 188, 5 }, { "Mo05_B", "CursedSwordsman", -7633, -6762, 1009.3, 188, 5 } }),
		group("Mo06", "MountainAscent", "M2_RockSteps>M2_Gallery", { { "Mo06_A", "CorruptWanderingMonk", -8232, -6091, 774.7, 164, 5 } }),
	},
}

-- Flat { Spawn, Region, Placement, Radius, Mob } list (same shape as Training/Minibosses) for WorldDefinitions and OverworldTerrain.
Overworld.EncounterSpots = {}
for _, g in Overworld.Encounters.Groups do
	for _, s in g.Spawns do
		table.insert(Overworld.EncounterSpots, { Spawn = s.Id, Mob = s.Mob, Region = s.Region, Placement = at(s.X, s.Y, s.Z, s.Yaw), Radius = s.Radius })
	end
end

-------------------------------------------------------------------------------------------------
-- Summit barrier and Shen's domain. Floor of the arena is Y 1580 (arena centre - 20, as before).
-------------------------------------------------------------------------------------------------

Overworld.Barrier = {
	Region = "AshColosseum",
	Boss = "GrandmasterShen",
	Arena = { Center = v(-7200, 1600, -8255), Size = v(120, 60, 130) },
	BossSpawn = at(-7200, 1583, -8290, 180),
	Gate = {
		Id = "Gate_AshColosseum",
		Boss = "GrandmasterShen",
		Placement = at(-7200, 1590, -8187, 0),
		Size = v(26, 20, 1.5),
		Trigger = { Center = v(-7200, 1590, -8198), Size = v(30, 20, 14) },
		Inside = at(-7200, 1583, -8206, 180),
		Outside = at(-7200, 1583, -8140, 0), -- on the temple side, in MountainAscent
	},
}

-- Future arena sites for the archived bosses: data only, no region, fog gate or spawn is registered.
Overworld.ReservedArenas = {
	VenerableBaize = { Region = "Snowfields", Arena = { Center = v(-2400, 700, -8200), Size = v(180, 100, 180) } },
	SlumberingTitan = { Region = "AridBasin", Arena = { Center = v(-9300, 130, -2000), Size = v(180, 100, 180) } },
	SovereignWu = { Region = "GoldenRavine", Arena = { Center = v(-7100, 0, -1700), Size = v(180, 100, 180) } },
	TwinSentinels = { Region = "Forest", Arena = { Center = v(-1900, 150, -3100), Size = v(180, 100, 180) } },
	AzureWyrm = { Region = "MountainAscent", Arena = { Center = v(-6200, 1300, -8400), Size = v(180, 100, 180) } },
}

-------------------------------------------------------------------------------------------------
-- Landmarks (long-distance silhouettes, Persistent under streaming) and POIs
-------------------------------------------------------------------------------------------------

-- Silhouette: few big boxes {dx, dy, dz, sx, sy, sz}; dy is the box centre above the base (terrain - 3), same massing
-- as the detailed model. The service builds them as "<Id>_Far" (tag OverworldLandmarkFar, attr FarBeyond studs).
local function landmark(id: string, region: string, node: string, x: number, y: number, z: number, height: number, silhouette: { { number } })
	return { Id = id, Region = region, Node = node, Position = v(x, y, z), Height = height, Persistent = true, Silhouette = silhouette, FarBeyond = 700 }
end

Overworld.Landmarks = {
	BrokenBellTower = landmark("BrokenBellTower", "Forest", "Altar_DesecratedCloister", -5100, 300, -3950, 90, {
		{ 0, 35, 0, 16, 70, 16 }, { 0, 77, 0, 16, 14, 14 },
	}),
	FarSideAqueduct = landmark("FarSideAqueduct", "GoldenRavine", "G4_FarSide", -6650, 300, -3300, 80, {
		{ 0, 40, 0, 190, 80, 6 }, { 0, 84, 0, 190, 9, 10 },
	}),
	GateStatue = landmark("GateStatue", "AridBasin", "B4_SaltPan", -9500, 60, -3000, 140, {
		{ 0, 35, 0, 74, 70, 26 }, { 0, 105, 0, 56, 70, 30 }, { 36, 91, 0, 14, 42, 14 },
	}),
	WatchBeacon = landmark("WatchBeacon", "Snowfields", "S3_Watchpost", -3500, 880, -7300, 100, {
		{ 0, 36, 0, 18, 72, 18 }, { 0, 78, 0, 28, 12, 28 },
	}),
	ThousandSteps = landmark("ThousandSteps", "MountainAscent", "M4_ThousandSteps", -7400, 1300, -7300, 120, {
		{ 0, 20, 0, 70, 40, 70 }, { 0, 60, 0, 50, 40, 50 }, { 0, 100, 0, 25, 40, 25 },
	}),
	SummitTemple = landmark("SummitTemple", "MountainAscent", "Altar_ColosseumAntechamber", -7200, 1650, -8100, 160, {
		{ 0, 24, 0, 74, 48, 90 }, { 0, 51.5, 0, 92, 3, 100 }, { 0, 67, 0, 70, 3, 80 }, { 0, 82, 0, 48, 3, 60 }, { 0, 101, 0, 6, 34, 6 },
	}),
}
Overworld.SummitId = "SummitTemple"

local function poi(id: string, kind: string, region: string, x: number, y: number, z: number, level: string, hidden: boolean)
	return { Id = id, Kind = kind, Region = region, Position = v(x, y, z), Level = level, Hidden = hidden }
end

Overworld.POIs = {
	poi("ReturnGate", "Gate", "Forest", -2170, 60, -1380, "Surface", false),
	poi("BellGraves", "Encounter", "Forest", -3060, 140, -2060, "Surface", false),
	poi("RopeBridge", "Bridge", "Forest", -2800, 190, -2800, "Surface", false),
	poi("HermitHut", "Hut", "Forest", -3400, 160, -2700, "Surface", false),
	poi("GullyCave", "Cave", "Forest", -4950, 150, -3500, "Underground", false),
	poi("AmberCave", "Cave", "GoldenRavine", -5300, 250, -3350, "Underground", false),
	poi("ChainLift", "Lift", "GoldenRavine", -5950, 290, -3180, "Surface", false),
	poi("UnderCrossingGrotto", "Cave", "GoldenRavine", -5900, -60, -3000, "Underground", true),
	poi("CisternCavern", "Cave", "AridBasin", -8080, 30, -2260, "Underground", false),
	poi("CisternStair", "Stair", "AridBasin", -8000, 60, -2400, "Surface", false),
	poi("CanyonNarrows", "Canyon", "AridBasin", -9000, 150, -4000, "Surface", false),
	poi("DuneRuin", "Ruin", "AridBasin", -9500, 50, -1400, "Surface", false),
	poi("FrozenLake", "Lake", "Snowfields", -4400, 540, -5800, "Surface", false),
	poi("WatchpostRuins", "Ruin", "Snowfields", -3500, 820, -7300, "Surface", false),
	poi("Vesperhold", "Temple", "Snowfields", Overworld.Vesperhold.X, Overworld.Vesperhold.Y, Overworld.Vesperhold.Z, "Surface", false),
	poi("WhitePass", "Pass", "Snowfields", -5500, 900, -6800, "Surface", false),
	poi("CliffGalleries", "Gallery", "MountainAscent", -8300, 820, -6400, "Surface", false),
	poi("TempleLift", "Lift", "MountainAscent", -7000, 1560, -7900, "Surface", false),
	poi("SummitTempleDoor", "Temple", "MountainAscent", -7200, 1650, -8100, "Surface", false),
}
-- Every cache is a hidden POI: the map never reveals it before the player finds it.
for id, cache in Overworld.Caches do
	table.insert(Overworld.POIs, poi("Cache_" .. id, "Cache", cache.Region, cache.Position.X, cache.Position.Y, cache.Position.Z, "Surface", true))
end

-------------------------------------------------------------------------------------------------
-- Route graph. Edge Length is planned path length in studs (never shorter than the straight line).
-------------------------------------------------------------------------------------------------

local function node(kind: string, region: string, subarea: string?, x: number, y: number, z: number)
	return { Kind = kind, Region = region, Subarea = subarea, Position = v(x, y, z) }
end

Overworld.Nodes = {
	Altar_MonasteryGate = node("altar", "Forest", "F1", -2200, 60, -1400),
	Altar_BellTerrace = node("altar", "Forest", "F2", -3000, 140, -2000),
	F3_RiverRavine = node("subarea", "Forest", "F3", -2700, 100, -2800),
	F3_Falls = node("junction", "Forest", nil, -2820, 100, -2850),
	F2_HermitHut = node("junction", "Forest", nil, -3400, 160, -2700),
	Altar_BambooShrine = node("altar", "Forest", "F4", -2600, 220, -3600),
	Altar_DesecratedCloister = node("altar", "Forest", "F5", -4400, 200, -3900),
	F6_GullyCave = node("subarea", "Forest", "F6", -4950, 150, -3500),
	G1_AmberCave = node("subarea", "GoldenRavine", "G1", -5300, 250, -3350),
	Altar_RavineOverlook = node("altar", "GoldenRavine", "G2", -5550, 300, -3150),
	G3_Crossing = node("subarea", "GoldenRavine", "G3", -5900, 280, -3150),
	G3_Grotto = node("junction", "GoldenRavine", nil, -5900, -60, -3000),
	G4_FarSide = node("subarea", "GoldenRavine", "G4", -6350, 290, -3150),
	G4_NorthRim = node("junction", "GoldenRavine", nil, -6700, 330, -4150),
	B1_CaravanDescent = node("subarea", "AridBasin", "B1", -7700, 150, -3000),
	Altar_BasinCistern = node("altar", "AridBasin", "B2", -8100, 40, -2300),
	B3_KilnWorks = node("subarea", "AridBasin", "B3", -8500, 120, -3300),
	B4_SaltPan = node("subarea", "AridBasin", "B4", -9500, 60, -3000),
	B5_Canyon = node("subarea", "AridBasin", "B5", -9000, 150, -4000),
	B6_DuneRuin = node("subarea", "AridBasin", "B6", -9500, 50, -1400),
	S1_HeadwaterGorge = node("subarea", "Snowfields", "S1", -2800, 480, -5100),
	Altar_SnowRefuge = node("altar", "Snowfields", "S2", -3400, 620, -6400),
	S3_Watchpost = node("subarea", "Snowfields", "S3", -3500, 820, -7300),
	S4_LakeMargin = node("subarea", "Snowfields", "S4", -4400, 540, -5800),
	S5_WhitePass = node("subarea", "Snowfields", "S5", -5500, 900, -6800),
	M1_PassFoot = node("subarea", "MountainAscent", "M1", -8300, 280, -4700),
	M1_WhitePassFoot = node("subarea", "MountainAscent", "M1", -5800, 700, -6700),
	M2_RockSteps = node("subarea", "MountainAscent", "M2", -8050, 620, -5600),
	M2_Gallery = node("junction", "MountainAscent", "M2", -8300, 820, -6400),
	Altar_MountainRefuge = node("altar", "MountainAscent", "M3", -7750, 1000, -6500),
	M3_Viewpoint = node("junction", "MountainAscent", nil, -6800, 1100, -6600),
	M4_ThousandSteps = node("subarea", "MountainAscent", "M4", -7400, 1300, -7300),
	Altar_ColosseumAntechamber = node("altar", "MountainAscent", "M5", -7200, 1550, -8000),
	Gate_AshColosseum = node("barrier", "MountainAscent", nil, -7200, 1583, -8140),
}

local function edge(a: string, b: string, kind: string, length: number, region: string, lock: string?)
	return { A = a, B = b, Kind = kind, Length = length, Region = region, Lock = lock }
end

Overworld.Edges = {
	-- Forest: road F1 > F2 > F4 > F5 > gully; riverbed alternate; falls and hermit; BambooRidge rope bridge
	edge("Altar_MonasteryGate", "Altar_BellTerrace", "main", 1100, "Forest"),
	edge("Altar_BellTerrace", "Altar_BambooShrine", "main", 1800, "Forest"),
	edge("Altar_BambooShrine", "Altar_DesecratedCloister", "main", 1900, "Forest"),
	edge("Altar_DesecratedCloister", "F6_GullyCave", "main", 750, "Forest"),
	edge("Altar_MonasteryGate", "F3_RiverRavine", "alternate", 2000, "Forest"),
	edge("F3_RiverRavine", "Altar_BambooShrine", "alternate", 1100, "Forest"),
	edge("F3_RiverRavine", "F3_Falls", "optional", 150, "Forest"),
	edge("Altar_BellTerrace", "F2_HermitHut", "optional", 950, "Forest"),
	edge("Altar_BambooShrine", "Altar_BellTerrace", "shortcut", 1700, "Forest", "BambooRidge"),
	-- GoldenRavine
	edge("F6_GullyCave", "G1_AmberCave", "main", 420, "GoldenRavine"),
	edge("G1_AmberCave", "Altar_RavineOverlook", "main", 360, "GoldenRavine"),
	edge("Altar_RavineOverlook", "G3_Crossing", "main", 400, "GoldenRavine"),
	edge("G3_Crossing", "G4_FarSide", "main", 500, "GoldenRavine"),
	edge("Altar_RavineOverlook", "G4_FarSide", "alternate", 1200, "GoldenRavine"),
	edge("G3_Crossing", "G3_Grotto", "optional", 350, "GoldenRavine"),
	edge("G4_FarSide", "G4_NorthRim", "optional", 1200, "GoldenRavine"),
	edge("G4_FarSide", "Altar_RavineOverlook", "shortcut", 800, "GoldenRavine"),
	-- AridBasin: caravan road to the cistern and kiln, canyon alternate, salt pan loop, dune ruin
	edge("G4_FarSide", "B1_CaravanDescent", "main", 1500, "AridBasin"),
	edge("B1_CaravanDescent", "Altar_BasinCistern", "main", 900, "AridBasin"),
	edge("Altar_BasinCistern", "B3_KilnWorks", "main", 1150, "AridBasin"),
	edge("B3_KilnWorks", "M1_PassFoot", "main", 1450, "AridBasin"),
	edge("Altar_BasinCistern", "B5_Canyon", "alternate", 2200, "AridBasin"),
	edge("B5_Canyon", "M1_PassFoot", "alternate", 1200, "AridBasin"),
	edge("B3_KilnWorks", "B4_SaltPan", "optional", 1300, "AridBasin"),
	edge("B4_SaltPan", "B5_Canyon", "optional", 1400, "AridBasin"),
	edge("Altar_BasinCistern", "B6_DuneRuin", "optional", 2100, "AridBasin"),
	edge("Altar_BasinCistern", "B1_CaravanDescent", "shortcut", 850, "AridBasin"),
	-- Snowfields: gorge > refuge > White Pass saddle; exposed ridge alternate; watchposts; ice path home
	edge("Altar_BambooShrine", "S1_HeadwaterGorge", "main", 1700, "Snowfields"),
	edge("S1_HeadwaterGorge", "Altar_SnowRefuge", "main", 1550, "Snowfields"),
	edge("Altar_SnowRefuge", "S5_WhitePass", "main", 2400, "Snowfields"),
	edge("S5_WhitePass", "M1_WhitePassFoot", "main", 450, "Snowfields"),
	edge("S1_HeadwaterGorge", "S3_Watchpost", "alternate", 2700, "Snowfields"),
	edge("S3_Watchpost", "S5_WhitePass", "alternate", 2400, "Snowfields"),
	edge("Altar_SnowRefuge", "S3_Watchpost", "optional", 1100, "Snowfields"),
	edge("Altar_SnowRefuge", "S4_LakeMargin", "optional", 1300, "Snowfields"),
	edge("S4_LakeMargin", "S1_HeadwaterGorge", "shortcut", 1800, "Snowfields"),
	-- MountainAscent: pass foot > rock steps > refuge > Thousand Steps > antechamber > barrier
	edge("M1_PassFoot", "M2_RockSteps", "main", 1000, "MountainAscent"),
	edge("M2_RockSteps", "Altar_MountainRefuge", "main", 1000, "MountainAscent"),
	edge("M1_WhitePassFoot", "Altar_MountainRefuge", "main", 2250, "MountainAscent"),
	edge("Altar_MountainRefuge", "M4_ThousandSteps", "main", 950, "MountainAscent"),
	edge("M4_ThousandSteps", "Altar_ColosseumAntechamber", "main", 750, "MountainAscent"),
	edge("Altar_ColosseumAntechamber", "Gate_AshColosseum", "main", 180, "MountainAscent"),
	edge("M2_RockSteps", "M2_Gallery", "alternate", 950, "MountainAscent"),
	edge("M2_Gallery", "Altar_MountainRefuge", "alternate", 700, "MountainAscent"),
	edge("Altar_MountainRefuge", "M3_Viewpoint", "optional", 1100, "MountainAscent"),
	edge("G4_NorthRim", "M1_PassFoot", "optional", 2000, "MountainAscent"),
	edge("Altar_ColosseumAntechamber", "Altar_MountainRefuge", "shortcut", 1650, "MountainAscent"), -- temple lift
}

-- The full tour without fast travel (plan target ~15,700 studs, 15-25 minutes of play).
Overworld.LongRoute = {
	"Altar_MonasteryGate", "Altar_BellTerrace", "Altar_BambooShrine", "Altar_DesecratedCloister", "F6_GullyCave",
	"G1_AmberCave", "Altar_RavineOverlook", "G3_Crossing", "G4_FarSide", "B1_CaravanDescent", "Altar_BasinCistern",
	"B3_KilnWorks", "M1_PassFoot", "M2_RockSteps", "Altar_MountainRefuge", "M4_ThousandSteps",
	"Altar_ColosseumAntechamber", "Gate_AshColosseum",
}
Overworld.Gateway = "Altar_MonasteryGate"
Overworld.BarrierNode = "Gate_AshColosseum"

-------------------------------------------------------------------------------------------------
-- Blockout (ticket 03): greybox structures. Only X, Z (and deck ends / ramp ends, which are not on
-- natural ground) are authored; everything else stands on heightAt. Edges lists the route edges ("A>B",
-- either direction) a structure carries, which are exempt from the 30 degree ground-grade rule.
-------------------------------------------------------------------------------------------------

Overworld.Blockout = {
	-- Decks run A to B. stone = arched causeway with piers to the chasm floor; rope = planks and hand ropes.
	Bridges = {
		{ Id = "AmberfallCrossing", Kind = "stone", Region = "GoldenRavine", A = v(-5700, 296, -3150), B = v(-6200, 290, -3150), Width = 18,
			Edges = { "Altar_RavineOverlook>G3_Crossing", "G3_Crossing>G4_FarSide" } },
		{ Id = "ShelfBridge", Kind = "rope", Region = "GoldenRavine", A = v(-5775, 21, -3560), B = v(-6040, 26, -3560), Width = 6,
			Edges = { "Altar_RavineOverlook>G4_FarSide" } },
		{ Id = "BambooRidgeBridge", Kind = "rope", Region = "Forest", A = v(-2880, 106, -2800), B = v(-2730, 100, -2800), Width = 6, Edges = {} },
	},
	-- Ramps stand in for stairs where a route climbs more than 30 degrees (one slab, Humanoid slope is 89).
	Ramps = {
		{ Id = "ShelfEast", Region = "GoldenRavine", A = v(-5700, 296, -3200), B = v(-5775, 21, -3560), Width = 8, Edges = { "Altar_RavineOverlook>G4_FarSide" } },
		{ Id = "ShelfWest", Region = "GoldenRavine", A = v(-6190, 288, -3200), B = v(-6040, 26, -3560), Width = 8, Edges = { "Altar_RavineOverlook>G4_FarSide" } },
		{ Id = "ViewpointScramble", Region = "MountainAscent", A = v(-6960, 1047, -6583), B = v(-6850, 1094, -6595), Width = 6, Edges = { "Altar_MountainRefuge>M3_Viewpoint" } },
		{ Id = "SummitSteps", Region = "MountainAscent", A = v(-7204, 1522, -7940), B = v(-7200, 1550, -7995), Width = 10,
			Edges = { "M4_ThousandSteps>Altar_ColosseumAntechamber" } },
	},
	-- Lifts: a station at each end (Y 0 = on the ground there), the rider is carried A to B or back with the portal fade.
	Lifts = {
		{ Id = "ChainLift", Region = "GoldenRavine", A = v(-6330, 0, -3180), B = v(-5590, 0, -3180), Edges = { "G4_FarSide>Altar_RavineOverlook" } },
		{ Id = "TempleLift", Region = "MountainAscent", A = v(-7765, 0, -6480), B = v(-7175, 0, -8010), Edges = { "Altar_ColosseumAntechamber>Altar_MountainRefuge" } },
	},
	-- Roofed shelters: W across, D deep, Yaw degrees. Roofs carry the AsuraShelter tag.
	Shelters = {
		{ Id = "GladeShed", Region = "Forest", X = -2240, Z = -1400, Yaw = 0, W = 16, D = 12 },
		{ Id = "BellTerraceShed", Region = "Forest", X = -2965, Z = -2005, Yaw = 90, W = 18, D = 12 },
		{ Id = "HermitHut", Region = "Forest", X = -3400, Z = -2700, Yaw = 0, W = 12, D = 10 },
		{ Id = "SnowRefuge", Region = "Snowfields", X = -3430, Z = -6400, Yaw = 90, W = 24, D = 18 },
		{ Id = "MountainRefuge", Region = "MountainAscent", X = -7780, Z = -6500, Yaw = 90, W = 24, D = 18 },
		{ Id = "CliffGallery", Region = "MountainAscent", X = -8300, Z = -6400, Yaw = 0, W = 60, D = 14 },
		{ Id = "CisternPavilion", Region = "AridBasin", X = -8130, Z = -2300, Yaw = 90, W = 22, D = 16 },
		{ Id = "KilnShed", Region = "AridBasin", X = -8500, Z = -3300, Yaw = 0, W = 30, D = 20 },
	},
	-- Cave mouths on the surface: an arch facing a node. The caves' interiors are not built.
	Portals = {
		{ Id = "GullyCaveMouth", Region = "Forest", X = -4950, Z = -3500, Faces = "Altar_DesecratedCloister" },
		{ Id = "AmberCaveMouth", Region = "GoldenRavine", X = -5300, Z = -3350, Faces = "Altar_RavineOverlook" },
		{ Id = "CisternCaveMouth", Region = "AridBasin", X = -8080, Z = -2260, Faces = "Altar_BasinCistern" },
	},
	-- The way home: an arch near the glade altar; its prompt carries the player to the lobby bonfire.
	ReturnGate = { Id = "ReturnGate", Region = "Forest", X = -2170, Z = -1380, Faces = "Altar_MonasteryGate" },
}

-------------------------------------------------------------------------------------------------
-- Queries
-------------------------------------------------------------------------------------------------

local function contains(bounds: any, x: number, y: number, z: number): boolean
	local c, s = bounds.Center, bounds.Size
	return math.abs(x - c.X) <= s.X * 0.5 and math.abs(y - c.Y) <= s.Y * 0.5 and math.abs(z - c.Z) <= s.Z * 0.5
end
Overworld.contains = contains

-- Overworld region at a point, or nil. The domain wins over the mountain that encloses it.
function Overworld.regionAt(x: number, y: number, z: number): string?
	if contains(Overworld.Regions.AshColosseum.Bounds, x, y, z) then
		return "AshColosseum"
	end
	for _, id in Overworld.RegionIds do
		if contains(Overworld.Regions[id].Bounds, x, y, z) then
			return id
		end
	end
	return nil
end

-- Signed XZ distance to a region box: negative inside, positive outside.
local function signedDistance(bounds: any, x: number, z: number): number
	local dx = math.abs(x - bounds.Center.X) - bounds.Size.X * 0.5
	local dz = math.abs(z - bounds.Center.Z) - bounds.Size.Z * 0.5
	if dx <= 0 and dz <= 0 then
		return math.max(dx, dz)
	end
	return math.sqrt(math.max(dx, 0) ^ 2 + math.max(dz, 0) ^ 2)
end

local function blendRaw(x: number, z: number, y: number?): ({ [string]: number }, number, string)
	local raw: { [string]: number } = {}
	local total, nearest, nearestDistance = 0, "", math.huge
	for _, id in Overworld.RegionIds do
		local bounds = Overworld.Regions[id].Bounds
		if y == nil or math.abs(y - bounds.Center.Y) <= bounds.Size.Y * 0.5 then
			local d = signedDistance(bounds, x, z)
			if d < nearestDistance then
				nearest, nearestDistance = id, d
			end
			local w = math.clamp(0.5 - d / Overworld.Blend, 0, 1)
			if w > 0 then
				raw[id] = w
				total += w
			end
		end
	end
	return raw, total, nearest
end

-- Environment/weather weights per overworld region (the domain never blends). Linear over Blend studs
-- centred on each border; weights sum to 1 and are exactly 1 deeper than Blend/2 inside a region.
-- With y, regions whose height band excludes it are skipped (AridBasin under MountainAscent); a
-- point no band admits falls back to XZ alone, and a point outside every region to the nearest one.
function Overworld.blendAt(x: number, z: number, y: number?): { [string]: number }
	local raw, total, nearest = blendRaw(x, z, y)
	if nearest == "" then
		raw, total, nearest = blendRaw(x, z, nil)
	end
	if total == 0 then
		return { [nearest] = 1 }
	end
	local result: { [string]: number } = {}
	for id, w in raw do
		result[id] = w / total
	end
	return result
end

-- World XZ <-> map UV over the Frame. u grows east, v grows south, so north is the top of the map.
function Overworld.toMap(x: number, z: number): (number, number)
	local f = Overworld.Frame
	return (x - f.MinX) / (f.MaxX - f.MinX), (z - f.MinZ) / (f.MaxZ - f.MinZ)
end

function Overworld.fromMap(u: number, vv: number): (number, number)
	local f = Overworld.Frame
	return f.MinX + u * (f.MaxX - f.MinX), f.MinZ + vv * (f.MaxZ - f.MinZ)
end

-------------------------------------------------------------------------------------------------
-- Terrain: heightAt / surfaceAt are the one surface definition (writer, map renderer, tests).
-- Pure and deterministic (fixed math.noise offsets). Composition, in order: node-pinned base surface
-- (inverse-distance over the route nodes) -> summit massif -> divide ridge -> region relief noise
-- (weighted by blendAt, so relief crosses borders through the bands) -> roads toward their grade ->
-- flat pads -> river and dry channels -> the Amberfall chasm. Every term is continuous except the
-- chasm cliffs, so no biome or height ends on a box edge.
-------------------------------------------------------------------------------------------------

Overworld.TerrainDef = {
	Resolution = 4,
	-- Route nodes that are cave mouths or under-crossings do not pin the surface.
	Underground = { F6_GullyCave = true, G1_AmberCave = true, G3_Grotto = true },
	-- Nodes reached by scramble, not road: the viewpoint is 250 studs above the main road 100 studs away.
	Scramble = { M3_Viewpoint = true },
	-- Pseudo-nodes pinning the lake basin by the gateway glade (the only open water on the surface).
	-- Moved 100 studs in from the south-east corner so the lake sits inside the cliff ring of Edge, not on it.
	Anchors = { v(-1850, -14, -1060), v(-1740, -14, -1010), v(-1790, -10, -1170), v(-1930, -8, -970) },
	-- X, Z centre the massif noise (spurs, crown); the cone itself peaks at Peak, behind the arena, so the arena
	-- floor (a flat pad) is not under the summit and stays open to the sky.
	Summit = { X = -7200, Z = -8250, Y = 1650, Slope = 0.55, Peak = { X = -7200, Z = -8440 } },
	DivideRaise = 35, -- crest sits this far above the Divide polyline's Y
	DivideSlope = 0.35,
	Relief = { Forest = 14, GoldenRavine = 10, AridBasin = 12, Snowfields = 22, MountainAscent = 34 },
	Pad = { AltarRadius = 22, RingRadius = 34, AltarBlend = 36, CacheRadius = 9, CacheBlend = 20, GateRadius = 18, GateBlend = 56, GateStep = 16, ArenaMargin = 6, ArenaBlend = 56, SkipCaches = { WaterfallAlcove = true, PagodaRafters = true } },
	Road = { Half = 8, Blend = 26, MaxBlend = 140, MaxGrade = 0.46 },
	-- Channels: Points are { X, Z, depth below the surrounding ground }. Wet channels fill with Water
	-- where their bed falls below Frame.WaterY; the dry one is Amberfall's seasonal stream.
	Rivers = {
		-- The Bellwood's river gorge: the Headwater cuts 26..40 studs deep through the middle reach (falls, rope bridge).
		{ Id = "Headwater", Wet = true, Width = 22, Bank = 48, Points = {
			{ -2800, -5100, 6 }, { -2650, -4500, 12 }, { -2300, -4000, 20 }, { -2250, -3500, 26 }, { -2500, -3100, 32 },
			{ -2820, -2850, 38 }, { -2600, -2500, 40 }, { -2400, -2100, 36 }, { -2050, -1750, 28 }, { -1850, -1350, 20 }, { -1760, -1050, 12 } } },
		{ Id = "AmberfallStream", Wet = false, Width = 30, Bank = 45, Points = {
			{ -5950, -1350, 6 }, { -6700, -1300, 8 }, { -7500, -1700, 8 }, { -8300, -2000, 10 }, { -9000, -2500, 10 }, { -9500, -3000, 10 } } },
	},
	-- Layered chasm: Depth below the rim along Points; Shelf is { t, fraction of Depth } with t = distance
	-- from the centreline over HalfWidth (ledges, then cliffs up to the rim).
	Chasm = { HalfWidth = 225, Depth = 450, Points = {
		{ -6000, -3900 }, { -5900, -3500 }, { -5950, -3150 }, { -6050, -2600 }, { -5950, -2000 }, { -5900, -1600 } },
		Shelf = { { 0, 1 }, { 0.4, 1 }, { 0.5, 0.65 }, { 0.68, 0.62 }, { 0.78, 0.3 }, { 0.9, 0.28 }, { 1, 0 } } },
	-- Materials: salt pan and frozen lake centres.
	SaltPan = { X = -9500, Z = -3000, R = 650 },
	FrozenLake = { X = -4400, Z = -5800, R = 300 },
	-- World edge (C2 art a): the walkable land ends at a wobbling foot line about Foot studs inside the Frame
	-- (Scale divides that on a side: the south and east edges sit close to the lake and a reserved arena, so their
	-- ring is narrower). Beyond the foot the ground climbs a cliff to an outer range Rise..Rise+RiseVar above it
	-- (kept under its region's height band) and falls away behind the crest; inside the Coast arc round the
	-- south-west corner it drops over a sea cliff to Sea, under Frame.WaterY. Nothing walkable reaches the Frame edge.
	Edge = { Foot = 300, Wobble = 60, CornerK = 200, Rise = 370, RiseVar = 190, Sea = -90,
		Scale = { W = 1, E = 2.2, N = 1, S = 2.2 }, Coast = { X = -10000, Z = -800, R = 3500, Wobble = 600, Fuzz = 500 } },
	-- Forest ridges: long crests Amp studs high; the view lane (glade -> summit temple) stays open.
	Ridges = { Amp = 60, Scale = 820, LaneHalf = 120, LaneFade = 380 },
	-- Meadow bowls: ridges and base relief fade out between 1.5 R and 0.6 R, the floor dips ClearingDip studs.
	ClearingDip = 7,
	Clearings = { { X = -2200, Z = -1400, R = 170 }, { X = -3000, Z = -2000, R = 140 }, { X = -3400, Z = -2700, R = 100 },
		{ X = -2600, Z = -3600, R = 130 }, { X = -4400, Z = -3900, R = 170 } },
	-- Bellwood slice relief (C3 fault B): a ridge the glade road must cross (Height studs, Half its half width) and a swale
	-- ring round Bell Terrace (Drop studs below the surrounding ground from Inner studs out, easing back by Outer) so the
	-- terrace stands on a rise. Both give way to the view lane, the keep-outs (encounter homes, hero sites) and the pads.
	Slice = {
		Ridge = { X0 = -2992, Z0 = -1410, X1 = -2503, Z1 = -1879, Height = 50, Half = 130 },
		Terrace = { X = -3000, Z = -2000, Inner = 165, Fade = 70, Drop = 36, Outer = 320, OuterFade = 140 },
	},
	-- Forest floor round the gateway altar (C3 fault D): LeafyGrass and Grass within Radius studs (ragged by Wobble).
	GladeFloor = { Radius = 40, Wobble = 0.15 },
	-- Where one of Regions dominates a column, another region weighs in on its material only above Share, so no distant
	-- biome leaks patches (Slate on the Bellwood road, C3 fault E); inside the transition bands the shares are well above it.
	-- Bellwood only for now: the other biomes' dressing budgets were tuned with the leak (add them when those lanes retune).
	MaterialFloor = { Share = 0.08, Regions = { Forest = true } },
	-- Ashen Stair massif: terraces (Cut share of the way to a stepped profile, treads/risers every Terrace studs),
	-- radial spurs and gullies, and a crag crown that only adds height, clear of the arena and gate.
	Massif = { Terrace = 70, Riser = 0.5, Cut = 0.25, Spur = 90, Crown = 38, CrownReach = 560 },
}
for _, c in Overworld.TerrainDef.Clearings do
	c.Far2 = (c.R * 1.5) ^ 2
end

@native
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

@native
local function smax(a: number, b: number, k: number): number
	return (a + b + math.sqrt((a - b) ^ 2 + k * k)) * 0.5
end

@native
local function smin(a: number, b: number, k: number): number
	return a + b - smax(a, b, k)
end

local CELL = 256
local EMPTY: { any } = {}

local function segment(x0: number, z0: number, x1: number, z1: number, a: number, b: number): any
	return { x0 = x0, z0 = z0, x1 = x1, z1 = z1, len2 = math.max((x1 - x0) ^ 2 + (z1 - z0) ^ 2, 1e-6), a = a, b = b }
end

local function buildIndex(segs: { any }, reach: number): { [number]: { any } }
	local index: { [number]: { any } } = {}
	for _, s in segs do
		for cx = math.floor((math.min(s.x0, s.x1) - reach) / CELL), math.floor((math.max(s.x0, s.x1) + reach) / CELL) do
			for cz = math.floor((math.min(s.z0, s.z1) - reach) / CELL), math.floor((math.max(s.z0, s.z1) + reach) / CELL) do
				local key = cx * 65536 + cz
				local list = index[key]
				if not list then
					list = {}
					index[key] = list
				end
				table.insert(list, s)
			end
		end
	end
	return index
end

@native
local function near(index: { [number]: { any } }, x: number, z: number): { any }
	return index[math.floor(x / CELL) * 65536 + math.floor(z / CELL)] or EMPTY
end

@native
local function segDist(s: any, x: number, z: number): (number, number)
	local dx, dz = s.x1 - s.x0, s.z1 - s.z0
	local t = math.clamp(((x - s.x0) * dx + (z - s.z0) * dz) / s.len2, 0, 1)
	local px, pz = s.x0 + dx * t, s.z0 + dz * t
	return math.sqrt((x - px) ^ 2 + (z - pz) ^ 2), t
end

-- Meandering road centreline from node A to node B whose arc length is Length (never under 1.06x the
-- straight line), found by bisecting the sine amplitude. Returns points { x, z, y } with y on the grade.
local function roadPoints(a: any, b: any, length: number): { any }
	local dx, dz = b.X - a.X, b.Z - a.Z
	local d = math.sqrt(dx * dx + dz * dz)
	local target = math.max(length, d * 1.06)
	local nx, nz = -dz / d, dx / d
	local steps = math.max(8, math.ceil(target / 30))
	local function build(amp: number): ({ any }, number)
		local pts, total = {}, 0
		for k = 0, steps do
			local t = k / steps
			local off = amp * math.sin(3 * math.pi * t) * math.min(1, t * 6, (1 - t) * 6)
			pts[k + 1] = { a.X + dx * t + nx * off, a.Z + dz * t + nz * off }
			if k > 0 then
				total += math.sqrt((pts[k + 1][1] - pts[k][1]) ^ 2 + (pts[k + 1][2] - pts[k][2]) ^ 2)
			end
		end
		return pts, total
	end
	local lo, hi = 0, d * 0.6
	for _ = 1, 16 do
		local mid = (lo + hi) / 2
		local _, total = build(mid)
		if total < target then lo = mid else hi = mid end
	end
	local pts, total = build((lo + hi) / 2)
	-- Grade follows the base ground (smoothed, pinned to both node heights, never steeper than MaxGrade):
	-- roads that cross then agree on one elevation instead of averaging two interpolated lines.
	local n, grade = #pts, Overworld.TerrainDef.Road.MaxGrade
	local y, s, fromStart = {}, { 0 }, { 0 }
	for k, p in pts do
		y[k] = Overworld.baseAt(p[1], p[2])
		if k > 1 then
			s[k] = math.sqrt((p[1] - pts[k - 1][1]) ^ 2 + (p[2] - pts[k - 1][2]) ^ 2)
			fromStart[k] = fromStart[k - 1] + s[k]
		end
	end
	local e0, e1 = a.Y - y[1], b.Y - y[n]
	for k = 1, n do
		local t = fromStart[k] / total
		y[k] += e0 * (1 - t) + e1 * t
	end
	for _ = 1, 30 do
		local prev = y[1]
		for k = 2, n - 1 do
			local cur = y[k]
			y[k] = (prev + 2 * cur + y[k + 1]) / 4
			prev = cur
		end
	end
	-- Reachable cone from both pinned ends, so the slope limit below cannot move an end.
	local function clampAt(k: number, v: number): number
		local sa, sb = fromStart[k], total - fromStart[k]
		return math.clamp(v, math.max(a.Y - grade * sa, b.Y - grade * sb), math.min(a.Y + grade * sa, b.Y + grade * sb))
	end
	y[1], y[n] = a.Y, b.Y
	for k = 2, n do y[k] = clampAt(k, math.clamp(y[k], y[k - 1] - grade * s[k], y[k - 1] + grade * s[k])) end
	for k = n - 1, 1, -1 do y[k] = clampAt(k, math.clamp(y[k], y[k + 1] - grade * s[k + 1], y[k + 1] + grade * s[k + 1])) end
	for k, p in pts do p[3] = y[k] end
	return pts
end

local built: any = nil
local function data(): any
	if built then
		return built
	end
	local def = Overworld.TerrainDef
	local px, pz, py = {}, {}, {}
	for id, n in Overworld.Nodes do
		if not def.Underground[id] then
			table.insert(px, n.Position.X); table.insert(pz, n.Position.Z); table.insert(py, n.Position.Y)
		end
	end
	for _, p in def.Anchors do
		table.insert(px, p.X); table.insert(pz, p.Z); table.insert(py, p.Y)
	end

	local pads = {}
	for _, a in Overworld.Altars do
		table.insert(pads, { X = a.Placement.X, Z = a.Placement.Z, Y = a.Placement.Y, R = def.Pad.AltarRadius, Blend = def.Pad.AltarBlend, Id = a.Id })
	end
	for id, r in Overworld.Rings do
		table.insert(pads, { X = r.X, Z = r.Z, Y = r.Y - 2, R = def.Pad.RingRadius, Blend = def.Pad.AltarBlend, Id = id })
	end
	-- Gate corridor: a chain of pads at the gate's floor (wall bottom; voxels surface 2 above heightAt) from the
	-- temple-side Outside point through the wall to the arena's Inside point, so no terrain lip hides the gate.
	local gate = Overworld.Barrier.Gate
	local gateFloor = gate.Placement.Y - gate.Size.Y / 2 - 2
	for k = 0, math.floor((gate.Outside.Z - gate.Inside.Z) / def.Pad.GateStep) do
		table.insert(pads, { X = gate.Outside.X, Z = gate.Outside.Z - k * def.Pad.GateStep, Y = gateFloor, R = def.Pad.GateRadius,
			Blend = def.Pad.GateBlend, Id = if k == 0 then "Gate_AshColosseum" else "Gate_AshColosseum_" .. k })
	end
	-- Arena: one rectangular pad (HX, HZ half extents, R 0) over the whole footprint at the same floor, so the
	-- corridor, gate and arena are one flat walkable surface open to the sky (nothing above floor + 1).
	local arena = Overworld.Barrier.Arena
	table.insert(pads, { X = arena.Center.X, Z = arena.Center.Z, Y = gateFloor, R = 0, HX = arena.Size.X / 2 + def.Pad.ArenaMargin,
		HZ = arena.Size.Z / 2 + def.Pad.ArenaMargin, Blend = def.Pad.ArenaBlend, Id = "Arena_AshColosseum" })
	for id, c in Overworld.Caches do
		if not def.Pad.SkipCaches[id] then
			table.insert(pads, { X = c.Position.X, Z = c.Position.Z, Y = c.Position.Y, R = def.Pad.CacheRadius, Blend = def.Pad.CacheBlend, Id = id })
		end
	end

	local crest = {}
	for k = 2, #Overworld.Divide do
		local p, q = Overworld.Divide[k - 1], Overworld.Divide[k]
		table.insert(crest, segment(p.X, p.Z, q.X, q.Z, p.Y + def.DivideRaise, q.Y + def.DivideRaise))
	end
	-- baseAt (used by roadPoints) only needs the nodes and the crest, so it is usable before the roads exist.
	built = { n = #px, px = px, pz = pz, py = py, crestIndex = buildIndex(crest, 700) }
	-- The view lane: glade altar to the summit temple.
	local glade, temple = Overworld.Altars[Overworld.Gateway].Placement, Overworld.Landmarks.SummitTemple.Position
	built.lane = segment(glade.X, glade.Z, temple.X, temple.Z, 0, 0)
	local rd = def.Slice.Ridge
	built.ridge = segment(rd.X0, rd.Z0, rd.X1, rd.Z1, 0, 0)
	-- Ground that stays as the base surface: fighting ground, the scramble, bridge and ramp ends (a = inner radius, b = fade).
	local keep = {}
	local function hold(p: any, inner: number, fade: number)
		table.insert(keep, segment(p.X, p.Z, p.X, p.Z, inner, fade))
	end
	for _, s in Overworld.EncounterSpots do hold(s.Placement, 25, 70) end
	hold(Overworld.Minibosses.HollowBellWarden.Placement, 25, 70)
	for id in def.Scramble do hold(Overworld.Nodes[id].Position, 180, 220) end
	hold({ X = -2667, Z = -1588 }, 30, 60) -- the broken bell tower keeps its authored footing
	for _, b in Overworld.Blockout.Bridges do hold(b.A, 60, 140); hold(b.B, 60, 140) end
	for _, r in Overworld.Blockout.Ramps do hold(r.A, 60, 140); hold(r.B, 60, 140) end
	built.keepIndex = buildIndex(keep, 400)

	-- Roads: walkable edges (not shortcuts, caves, lifts or edges steeper than MaxGrade after meander).
	local roads, roadSegs = {}, {}
	for _, e in Overworld.Edges do
		local a, b = Overworld.Nodes[e.A], Overworld.Nodes[e.B]
		if e.Kind ~= "shortcut" and not def.Underground[e.A] and not def.Underground[e.B] and not def.Scramble[e.A] and not def.Scramble[e.B] then
			local pts = roadPoints(a.Position, b.Position, e.Length)
			local run = 0
			for k = 2, #pts do run += math.sqrt((pts[k][1] - pts[k - 1][1]) ^ 2 + (pts[k][2] - pts[k - 1][2]) ^ 2) end
			if math.abs(b.Position.Y - a.Position.Y) / run <= def.Road.MaxGrade then
				table.insert(roads, { A = e.A, B = e.B, Kind = e.Kind, Points = pts, Length = run })
				for k = 2, #pts do
					table.insert(roadSegs, segment(pts[k - 1][1], pts[k - 1][2], pts[k][1], pts[k][2], pts[k - 1][3], pts[k][3]))
				end
			end
		end
	end

	local channelSegs, chasmSegs = {}, {}
	for _, r in def.Rivers do
		for k = 2, #r.Points do
			local p, q = r.Points[k - 1], r.Points[k]
			local s = segment(p[1], p[2], q[1], q[2], p[3], q[3])
			s.wet = r.Wet
			table.insert(channelSegs, s)
		end
	end
	for k = 2, #def.Chasm.Points do
		local p, q = def.Chasm.Points[k - 1], def.Chasm.Points[k]
		table.insert(chasmSegs, segment(p[1], p[2], q[1], q[2], 0, 0))
	end

	local D = built
	D.Pads, D.Roads = pads, roads
	D.roadIndex = buildIndex(roadSegs, def.Road.Half + def.Road.MaxBlend)
	D.channelIndex = buildIndex(channelSegs, 80)
	D.chasmIndex = buildIndex(chasmSegs, def.Chasm.HalfWidth + 1)
	-- Road correction: where the node-pinned base differs from a road's grade, the base is eased toward
	-- it over 3x the mismatch (160..700 studs) so the road sits in the ground instead of a cut with cliff banks.
	local corr = {}
	for _, r in roads do
		for k = 1, #r.Points, 5 do
			local p = r.Points[k]
			local miss = p[3] - Overworld.baseAt(p[1], p[2])
			table.insert(corr, segment(p[1], p[2], p[1], p[2], miss, math.clamp(3 * math.abs(miss), 160, 700)))
		end
	end
	built.corrIndex = buildIndex(corr, 700)
	return built
end

-- Pads and roads (centrelines with grade Y) for tests and the map; built once on first use.
function Overworld.terrainData(): any
	return data()
end

-- Region weights that never switch (blendAt falls back to the nearest box where none covers a point,
-- which would step the relief): each region's weight decays smoothly with distance outside its box.
-- With h, AridBasin and MountainAscent are told apart by height where their boxes overlap.
-- Fills and returns out (the caller's reusable table: no allocation per call); boxes are read once.
local regionBoxes: { { Id: string, X: number, Z: number, HX: number, HZ: number } } = {}
@native
local function softWeights(out: { [string]: number }, x: number, z: number, h: number?): { [string]: number }
	if #regionBoxes == 0 then
		for _, id in Overworld.RegionIds do
			local b = Overworld.Regions[id].Bounds
			table.insert(regionBoxes, { Id = id, X = b.Center.X, Z = b.Center.Z, HX = b.Size.X * 0.5, HZ = b.Size.Z * 0.5 })
		end
	end
	local total, blend = 0, Overworld.Blend
	for _, r in regionBoxes do
		-- same distance as signedDistance: negative inside, positive outside
		local dx, dz = math.abs(x - r.X) - r.HX, math.abs(z - r.Z) - r.HZ
		local d: number
		if dx <= 0 and dz <= 0 then
			d = math.max(dx, dz)
		else
			d = math.sqrt(math.max(dx, 0) ^ 2 + math.max(dz, 0) ^ 2)
		end
		local w = 1 / (1 + math.max(d, 0) / blend) ^ 2
		if h and ((r.Id == "AridBasin" and h > 245) or (r.Id == "MountainAscent" and h <= 245)) then
			w *= 0.01
		end
		out[r.Id] = w
		total += w
	end
	for _, r in regionBoxes do
		out[r.Id] /= total
	end
	return out
end
local weightsSample: { [string]: number } = {} -- sampleAt's scratch (relief reads it)
local weightsMaterial: { [string]: number } = {} -- materialAt's scratch

@native
local function shelf(t: number): number
	local knots = Overworld.TerrainDef.Chasm.Shelf
	for k = 2, #knots do
		if t <= knots[k][1] then
			local p, q = knots[k - 1], knots[k]
			return p[2] + (q[2] - p[2]) * (t - p[1]) / (q[1] - p[1])
		end
	end
	return 0
end

-- World edge. Returns u (0 at the foot line, 1 at the Frame edge, 0 inside), the sea share c (0 range .. 1 sea cliff)
-- and the walkable inset in studs (positive on the walkable side of the foot line; scaled on the south and east sides).
@native
local function edgeAt(x: number, z: number): (number, number, number)
	local E, F = Overworld.TerrainDef.Edge, Overworld.Frame
	local k, sc = E.CornerK, E.Scale
	local dm = math.min((x - F.MinX) * sc.W, (F.MaxX - x) * sc.E, (z - F.MinZ) * sc.N, (F.MaxZ - z) * sc.S)
	if dm > E.Foot + 1.5 * E.Wobble + k then -- the rounded corners (smin) pull e down by at most k
		return 0, 0, dm - E.Foot
	end
	local e = smin(smin((x - F.MinX) * sc.W, (F.MaxX - x) * sc.E, k), smin((z - F.MinZ) * sc.N, (F.MaxZ - z) * sc.S, k), k)
	if e > E.Foot + 1.5 * E.Wobble then
		return 0, 0, e - E.Foot
	end
	e += E.Wobble * (math.noise(x / 430 + 2.7, z / 430 - 5.9) + 0.4 * math.noise(x / 140 - 8.1, z / 140 + 3.3))
	local u = math.clamp(1 - e / E.Foot, 0, 1)
	if u <= 0 then
		return 0, 0, e - E.Foot
	end
	local C = E.Coast
	local cd = math.sqrt((x - C.X) ^ 2 + (z - C.Z) ^ 2)
	return u, smooth(0.5 + (C.R + C.Wobble * math.noise(x / 1700 + 3.3, z / 1700 - 6.1) - cd) / C.Fuzz), e - E.Foot
end

function Overworld.edgeInset(x: number, z: number): number
	local _, _, inset = edgeAt(x, z)
	return inset
end

-- Height added by the edge to ground at h. The crest is held under its region's height band (Y top - 8).
@native
local function edgeDelta(x: number, z: number, h: number): number
	local u, c = edgeAt(x, z)
	if u <= 0 then
		return 0
	end
	local E, d = Overworld.TerrainDef.Edge, 0
	if c < 1 then
		-- Height cap: no region's band top, plus 2 studs per stud of distance outside its box, is exceeded (so the crest
		-- stays inside the band of the box it stands in and steps smoothly where the bands differ); the summit stays highest.
		local top = Overworld.TerrainDef.Summit.Y - 120
		for _, id in Overworld.RegionIds do
			local b = Overworld.Regions[id].Bounds
			top = math.min(top, b.Center.Y + b.Size.Y * 0.5 - 8 + 2 * math.max(signedDistance(b, x, z), 0))
		end
		local jag = 1 - math.abs(math.noise(x / 150 + 9.4, z / 150 - 4.8))
		local rise = E.Rise + E.RiseVar * (0.5 + 0.5 * math.noise(x / 700 + 1.3, z / 700 - 2.1)) + 60 * jag * jag
		-- The range is measured from the ground inland at the foot (the ground often falls away outward on a flank).
		local F = Overworld.Frame
		local cx, cz = (F.MinX + F.MaxX) * 0.5 - x, (F.MinZ + F.MaxZ) * 0.5 - z
		local cl = math.sqrt(cx * cx + cz * cz)
		local from = smax(h, Overworld.baseAt(x + cx / cl * E.Foot, z + cz / cl * E.Foot), 20)
		d += (1 - c) * (smin(from + rise, top - 60 * jag - 160 * math.clamp(0.5 + 0.7 * math.noise(x / 650 + 7.7, z / 650 - 3.1), 0, 1), 40) - h) * smooth(u / 0.6) * (1 - 0.15 * smooth((u - 0.75) / 0.25))
	end
	if c > 0 then
		-- The sea floor stays above every band bottom it stands in (same distance-field rule as the cap).
		local sea = E.Sea
		for _, id in Overworld.RegionIds do
			local b = Overworld.Regions[id].Bounds
			sea = math.max(sea, b.Center.Y - b.Size.Y * 0.5 + 6 - 2 * math.max(signedDistance(b, x, z), 0))
		end
		d += c * math.min(sea - h, 0) * smooth((u - 0.12) / 0.38)
	end
	return d
end

-- Share (0..1) of a meadow bowl at x, z.
@native
local function clearingAt(x: number, z: number): number
	local best = 0
	for _, c in Overworld.TerrainDef.Clearings do
		local d2 = (x - c.X) ^ 2 + (z - c.Z) ^ 2
		if d2 < c.Far2 then
			best = math.max(best, smooth((c.R * 1.5 - math.sqrt(d2)) / (c.R * 0.9)))
		end
	end
	return best
end

-- Relief: Bellwood ridges and
-- meadow bowls, and the Ashen Stair terraces, spurs and crown. W = softWeights, clr = clearingAt, h = ground so far.
@native
local function relief(D: any, x: number, z: number, h: number, W: { [string]: number }, clr: number): number
	local def, e = Overworld.TerrainDef, 0
	local wF = W.Forest
	if wF > 0.02 then
		local R = def.Ridges
		local rg = 1 - math.abs(math.noise(x / R.Scale + 31.1, z / R.Scale - 12.7))
		local lane = smooth((segDist(D.lane, x, z) - R.LaneHalf) / R.LaneFade)
		local dd = 700 -- ridges give way to the divide crest (and the cave mouths on its flank)
		for _, sg in near(D.crestIndex, x, z) do
			dd = math.min(dd, (segDist(sg, x, z)))
		end
		lane *= smooth((dd - 120) / 380)
		e += wF * R.Amp * (rg * rg * rg - 0.25) * lane * (1 - clr) - wF * def.ClearingDip * clr
		local S = def.Slice
		local crest = (1 - smooth(segDist(D.ridge, x, z) / S.Ridge.Half)) * (0.8 + 0.4 * math.noise(x / 160 + 3.9, z / 160 - 8.8))
		local tr = math.sqrt((x - S.Terrace.X) ^ 2 + (z - S.Terrace.Z) ^ 2)
		local ring = smooth((tr - S.Terrace.Inner) / S.Terrace.Fade) * (1 - smooth((tr - S.Terrace.Outer) / S.Terrace.OuterFade))
			* (0.8 + 0.4 * math.noise(x / 230 - 6.1, z / 230 + 2.2))
		-- Only the lane's own corridor (150 studs, fading over 90) stays clear: the road runs close beside the lane.
		local mask = smooth((segDist(D.lane, x, z) - 150) / 90) * smooth((dd - 120) / 380)
		e += wF * mask * ((1 - clr) * S.Ridge.Height * crest - S.Terrace.Drop * ring)
	end
	local wM = W.MountainAscent
	if wM > 0.02 and h > 380 then
		local M, S = def.Massif, def.Summit
		local dx, dz = x - S.X, z - S.Z
		local r = math.max(math.sqrt(dx * dx + dz * dz), 1)
		local mh = wM * smooth((h - 380) / 260)
		local q = (h + 45 * math.noise(x / 310 + 4.7, z / 310 - 8.3)) / M.Terrace
		local step = (math.floor(q) + smooth((q - math.floor(q) - (1 - M.Riser)) / M.Riser)) * M.Terrace
		e += mh * M.Cut * (step - q * M.Terrace)
		local sp = 1 - math.abs(math.noise(dx / r * 1.6 + 5.1, dz / r * 1.6 - 3.7, r / 1500))
		e += mh * M.Spur * (sp * sp * sp - 0.25) * smooth((r - 200) / 250) * (1 - smooth((r - 1800) / 1700))
		local crown = smooth((M.CrownReach - r) / 300) * smooth((r - 70) / 90)
		if crown > 0 then
			local g = 1 - math.abs(math.noise(x / 115 + 12.9, z / 115 - 6.2))
			e += mh * M.Crown * crown * g * g * g
		end
	end
	local ko = 1
	for _, k in near(D.keepIndex, x, z) do
		ko = math.min(ko, smooth((math.sqrt((x - k.x0) ^ 2 + (z - k.z0) ^ 2) - k.a) / k.b))
	end
	return e * ko
end

-- Node-pinned surface with the summit massif and divide ridge, before road correction and relief.
@native
function Overworld.baseAt(x: number, z: number): number
	local D, def = built or data(), Overworld.TerrainDef
	local num, den = 0, 0
	for i = 1, D.n do
		local dx, dz = x - D.px[i], z - D.pz[i]
		local d2 = dx * dx + dz * dz
		if d2 < 1 then
			num, den = D.py[i], 1
			break
		end
		local w = 1 / d2
		num += w * D.py[i]
		den += w
	end
	local h = num / den

	local S = def.Summit
	h = smax(h, S.Y - S.Slope * math.sqrt((x - S.Peak.X) ^ 2 + (z - S.Peak.Z) ^ 2), 40)

	local top = -math.huge
	for _, s in near(D.crestIndex, x, z) do
		local d, t = segDist(s, x, z)
		top = math.max(top, s.a + (s.b - s.a) * t - d * def.DivideSlope)
	end
	if top > -math.huge then
		h = smax(h, top, 24)
	end
	return h
end

-- Height of the ground at x, z, plus the road, channel and chasm weights (0..1) that shaped it.
@native
function Overworld.sampleAt(x: number, z: number, pads: any?): (number, number, number, number)
	local D, def = built or data(), Overworld.TerrainDef
	local h = Overworld.baseAt(x, z)
	local csum, cw = 0, 0
	for _, s in near(D.corrIndex, x, z) do
		local d = math.sqrt((x - s.x0) ^ 2 + (z - s.z0) ^ 2)
		if d < s.b then
			local w = (1 - d / s.b) ^ 2
			csum += w
			cw += w * s.a
		end
	end
	h += cw / math.max(csum, 1)

	local W, amp = softWeights(weightsSample, x, z, nil), 0
	for id, w in W do
		amp += w * def.Relief[id]
	end
	local clr = clearingAt(x, z)
	amp *= 1 - 0.8 * clr
	h += amp * (math.noise(x / 260 + 17.31, z / 260 - 9.77) + 0.35 * math.noise(x / 90 - 3.17, z / 90 + 41.13)
		+ 0.1 * math.noise(x / 33 + 7.91, z / 33 - 23.57) + 0.03 * math.noise(x / 13 - 11.43, z / 13 + 5.29))
	h += edgeDelta(x, z, h)
	h += relief(D, x, z, h, W, clr) -- before the roads and pads, so they ease into it over their own banks
	local gate = Overworld.Vesperhold
	local side, along = z - gate.Z, gate.X - x
	if math.abs(side) < 340 and along > -480 and along < 590 then
		-- A weather-cut ridge under the curtain wall, tapering down behind the apse.
		local crag = math.noise(side / 76, along / 88)
		local spur = 1 - smooth((math.abs(side + 0.09 * along) - 58 - 22 * crag) / 135)
		spur *= smooth((22 - along) / 78) * smooth((along + 480) / 260)
		h += spur * math.max(0, gate.Y - 21 + crag * 12 - h)
		-- Scour across the viaduct, with two uneven shoulders framing the approach.
		local gully = 1 - smooth(math.abs(along - 89 - 0.23 * side - 16 * crag) / 80)
		h -= 34 * gully * (1 - smooth((math.abs(side) - 155) / 185))
		local shoulder = 1 - smooth(math.abs(math.abs(side) - 170 - crag * 58) / 112)
		h += (67 + 30 * crag) * shoulder * smooth((along - 170) / 100) * smooth((590 - along) / 148)
		-- Bastion gorge: the T0 faces drop >= 150 studs either side of the gate, and the viaduct crosses a deeper scour.
		-- Confined to |side| < 255 and along -115..170 (the long ramps keep every 4-stud step under 6), inside vesperholdWeight's support, so no other height moves.
		local bite = smooth((math.abs(side) - 40) / 100) * (1 - smooth((math.abs(side) - 150) / 105))
			* smooth((along + 115) / 105) * (1 - smooth((along - 20) / 150))
		local scour = (1 - smooth(math.abs(side) / 70)) * smooth((along - 10) / 60) * (1 - smooth((along - 100) / 70))
		h -= (95 + 10 * crag) * bite + 45 * scour
	end

	-- Target grade: centrelines weighted by exp(-(d - nearest)/10), so the nearest one dominates and the
	-- target is continuous where parts of one road, or two roads, lie close together. The bank widens with
	-- the mismatch between that grade and the ground, so a road crossing higher or lower ground eases in.
	local roadW = 0
	local nearRoads = near(D.roadIndex, x, z)
	local dmin = math.huge
	for _, s in nearRoads do
		dmin = math.min(dmin, (segDist(s, x, z)))
	end
	if dmin < def.Road.Half + def.Road.MaxBlend then
		local wsum, wt = 0, 0
		for _, s in nearRoads do
			local d, t = segDist(s, x, z)
			local k = math.exp(-(d - dmin) / 10)
			wsum += k
			wt += k * (s.a + (s.b - s.a) * t)
		end
		local grade = wt / wsum
		roadW = 1 - smooth((dmin - def.Road.Half) / math.clamp(2 * math.abs(grade - h), def.Road.Blend, def.Road.MaxBlend))
		if roadW > 0 then
			h += roadW * (grade - h)
		end
	end

	local padW = 0
	local wsum, wt = 0, 0
	for _, p in (pads or D.Pads) do
		local dx, dz = x - p.X, z - p.Z
		if p.HX then -- rectangular pad: distance to the box
			dx, dz = math.max(math.abs(dx) - p.HX, 0), math.max(math.abs(dz) - p.HZ, 0)
		end
		local d = math.sqrt(dx * dx + dz * dz)
		local w = 1 - smooth((d - p.R) / p.Blend)
		if w > 0 then
			wsum += w
			wt += w * p.Y
			padW = math.max(padW, w)
		end
	end
	if padW > 0 then
		h += padW * (wt / wsum - h)
	end

	local carve, channelW = 0, 0
	for _, s in near(D.channelIndex, x, z) do
		local d, t = segDist(s, x, z)
		local r = if s.wet then def.Rivers[1] else def.Rivers[2]
		local w = 1 - smooth((d - r.Width / 2) / r.Bank)
		if w > 0 then
			carve = math.max(carve, w * (s.a + (s.b - s.a) * t))
			channelW = math.max(channelW, w)
		end
	end
	h -= carve * (1 - roadW) -- a road crosses the gorge on its own grade (a causeway), the cut stays either side

	local chasmW, chasmCarve = 0, 0
	for _, s in near(D.chasmIndex, x, z) do
		local d = segDist(s, x, z)
		local f = shelf(d / def.Chasm.HalfWidth)
		if f > 0 then
			chasmCarve = math.max(chasmCarve, f * def.Chasm.Depth)
			chasmW = math.max(chasmW, f)
		end
	end
	h -= chasmCarve
	return h, roadW, channelW, chasmW
end

@native
function Overworld.heightAt(x: number, z: number): number
	return (Overworld.sampleAt(x, z))
end

-- What the terrain writer paints in place of a materialAt name. Only Enum.Material.Grass grows Terrain.Decoration blades
-- (creator, 2026-11-21: tall grass wherever it fits), so leafy forest floor and foothill meadows are painted Grass. The
-- dressing keeps reading materialAt, so no tree, fern or prop moves. Desert, snow and the Vesperhold ridge never return LeafyGrass.
Overworld.Paint = table.freeze({ LeafyGrass = "Grass" }) :: { [string]: string }

-- Terrain material name (an Enum.Material name) for a column. Regions pick by blendAt weight, dithered
-- by low-frequency noise so every border is a ragged band, not a line. slope = |grad h| (rise / run).
local ROAD_MATERIAL: { [string]: string } = { Forest = "Ground", GoldenRavine = "Ground", AridBasin = "Limestone", Snowfields = "Slate", MountainAscent = "Slate" }

@native
local function regionMaterial(id: string, x: number, z: number, h: number, slope: number, roadW: number, channelW: number, chasmW: number, n1: number, n2: number): string
	local def = Overworld.TerrainDef
	if chasmW > 0.02 then
		return if slope > 0.9 then "Sandstone" else "Limestone"
	end
	if roadW > 0.5 then
		return ROAD_MATERIAL[id]
	end
	if id == "Forest" then
		if slope > 1.0 then return "Rock" end
		if channelW > 0.4 or h < 6 then return "Mud" end
		if slope > 0.6 then return if n1 > 0 then "Rock" else "Ground" end
		return if n1 > 0.12 then "LeafyGrass" elseif n1 < -0.22 then "Mud" else "Grass"
	elseif id == "GoldenRavine" then
		if slope > 0.8 then return "Sandstone" end
		if channelW > 0.4 then return "Sand" end
		local dry = math.clamp((-5250 - x) / 2000, 0, 1) -- the lee of the divide dries westward
		local score = dry + 0.5 * n1
		return if score < 0.25 then "Grass" elseif score < 0.55 then "Sand" else "Sandstone"
	elseif id == "AridBasin" then
		local p = def.SaltPan
		if slope < 0.15 and math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2) < p.R * (1 + 0.25 * n1) then return "Salt" end
		if slope > 0.5 then return "Sandstone" end
		return if n1 > 0.2 then "Limestone" else "Sand"
	elseif id == "Snowfields" then
		local ridge = Overworld.vesperholdWeight(x, z)
		if ridge > 0 and n1 * 0.5 + slope * 0.6 + ridge * 0.6 > 0.59 then
			return if slope + n2 * 0.4 > 0.38 then "Rock" else "Slate"
		end
		local p = def.FrozenLake
		if math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2) < p.R * (1 + 0.15 * n1) and slope < 0.2 then return "Glacier" end
		if channelW > 0.3 then return "Glacier" end
		if slope > 0.75 or (h > 700 and n2 > 0.15) then return "Rock" end
		return if h < 600 and n1 < -0.2 then "Ground" else "Snow"
	end
	-- MountainAscent
	if h < 450 then
		if slope > 0.7 then return "Rock" end
		return if n1 > 0.1 then "LeafyGrass" else "Grass"
	elseif h < 900 then
		if slope > 0.6 then return "Rock" end
		return if n1 > 0 then "Slate" else "Ground"
	elseif h < 1100 then
		return if n1 > 0 then "Slate" else "Basalt"
	end
	if slope < 0.7 and n2 > -0.1 then return "Snow" end
	return if slope > 1.0 then "Basalt" else "Rock"
end

@native
function Overworld.materialAt(x: number, z: number, h: number, slope: number, roadW: number?, channelW: number?, chasmW: number?): string
	local n1 = math.noise(x / 47 + 5.5, z / 47 + 9.1)
	local n2 = math.noise(x / 190 - 2.3, z / 190 + 13.7)
	local u = math.clamp(0.5 + 1.2 * math.noise(x / 90 + 21.7, z / 90 - 6.3) + 0.6 * math.noise(x / 14 + 3.9, z / 14 + 8.2), 0, 1)
	local def = Overworld.TerrainDef
	local g = Overworld.Altars[Overworld.Gateway].Placement
	if math.sqrt((x - g.X) ^ 2 + (z - g.Z) ^ 2) < def.GladeFloor.Radius * (1 + def.GladeFloor.Wobble * n1) then
		return if n1 > -0.12 then "LeafyGrass" else "Grass" -- forest floor round the glade altar, never a bare Ground or Rock slab
	end
	local pick, cum = "Forest", 0
	local weights = softWeights(weightsMaterial, x, z, h)
	local floor, top, topId = 0, 0, "Forest"
	for _, id in Overworld.RegionIds do
		if weights[id] > top then top, topId = weights[id], id end
	end
	if def.MaterialFloor.Regions[topId] then floor = def.MaterialFloor.Share end
	local kept = 0
	for _, id in Overworld.RegionIds do
		if weights[id] >= floor then kept += weights[id] end
	end
	u *= kept
	for _, id in Overworld.RegionIds do
		local w = weights[id]
		if w and w >= floor then
			cum += w
			pick = id
			if u <= cum then break end
		end
	end
	return regionMaterial(pick, x, z, h, slope, roadW or 0, channelW or 0, chasmW or 0, n1, n2)
end

-- Height, material name and slope hint (rise / run over 4 studs) at x, z.
@native
function Overworld.surfaceAt(x: number, z: number): (number, string, number)
	local h, roadW, channelW, chasmW = Overworld.sampleAt(x, z)
	local hx, hz = Overworld.heightAt(x + 4, z), Overworld.heightAt(x, z + 4)
	local slope = math.sqrt((hx - h) ^ 2 + (hz - h) ^ 2) / 4
	return h, Overworld.materialAt(x, z, h, slope, roadW, channelW, chasmW), slope
end

-- Bottom (stud Y) of the solid written under column (i, j) of a height grid hs[i][j] (margin index -1..n): the
-- shell below its own surface, or below its lowest 8-neighbour so steep faces leave no vertical gap between columns.
@native
function Overworld.shellBottom(hs: any, i: number, j: number, shell: number): number
	local low = hs[i][j]
	for di = -1, 1 do
		local col = hs[i + di]
		for dj = -1, 1 do
			local v = col[j + dj]
			if v < low then low = v end
		end
	end
	return low - shell
end

-- The pads (in their own order) that can change sampleAt anywhere in the box x0..x1, z0..z1: a pad's weight is exactly 0
-- beyond R + Blend of its shape, so passing this list as sampleAt's `pads` gives the same results with ~60 fewer pads.
function Overworld.padsNear(x0: number, z0: number, x1: number, z1: number): { any }
	local D = built or data()
	local cx, cz, qx, qz = (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0) / 2, (z1 - z0) / 2
	local out = {}
	for _, p in D.Pads do
		local dx, dz = math.max(math.abs(cx - p.X) - qx - (p.HX or 0), 0), math.max(math.abs(cz - p.Z) - qz - (p.HZ or 0), 0)
		if math.sqrt(dx * dx + dz * dz) <= p.R + p.Blend then
			table.insert(out, p)
		end
	end
	return out
end

-------------------------------------------------------------------------------------------------
-- Integration (WorldDefinitions, only while Active)
-------------------------------------------------------------------------------------------------

local function shortName(id: string): string
	return (string.gsub(id, "^Altar_", ""))
end

-- Adds the overworld regions, altars, caches and summit barrier to the world and removes the retired
-- altars, so they are never fast-travel destinations or map markers. The old campaign regions stay
-- until ticket 08 retires them; BossRoster is untouched.
function Overworld.apply(world: any)
	for _, id in Overworld.RegionIds do
		local def = Overworld.Regions[id]
		world.Regions[id] = { Id = id, Name = def.Name, Bounds = def.Bounds, MapFolder = def.MapFolder, Greybox = def.Greybox,
			Ambience = def.Ambience, Altars = {} }
		table.insert(world.RegionOrder, id)
	end
	-- The domain keeps its old region id (Combat:AshColosseum, boss mapping) in a new place.
	local domain = Overworld.Regions.AshColosseum
	local existing = world.Regions.AshColosseum
	world.Regions.AshColosseum = { Id = "AshColosseum", Name = domain.Name, Bounds = domain.Bounds, MapFolder = domain.MapFolder,
		Greybox = if existing then existing.Greybox else domain.Greybox, Ambience = if existing then existing.Ambience else domain.Ambience, Altars = {} }
	if not table.find(world.RegionOrder, "AshColosseum") then
		table.insert(world.RegionOrder, "AshColosseum")
	end

	local function drop(id: string)
		local old = world.Altars[id]
		if old then
			local oldRegion = world.Regions[old.Region]
			if oldRegion then
				oldRegion.Altars[shortName(id)] = nil
			end
			world.Altars[id] = nil
		end
	end
	for id in Overworld.RetiredAltars do
		drop(id)
	end
	for id, entry in Overworld.Altars do
		drop(id)
		world.Altars[id] = entry
		world.Regions[entry.Region].Altars[shortName(id)] = entry
	end

	local barrier = Overworld.Barrier
	local shen = world.Bosses[barrier.Boss]
	if shen then
		shen.Region, shen.Arena, shen.Spawn = barrier.Region, barrier.Arena, barrier.BossSpawn
	end
	world.FogGates[barrier.Gate.Id] = barrier.Gate
	world.Caches = Overworld.Caches

	-- Cutover: the old campaign leaves the world. Region keys and altar ids stay in saves; nothing here.
	for _, id in Overworld.RetiredRegions do
		world.Regions[id] = nil
		local index = table.find(world.RegionOrder, id)
		if index then
			table.remove(world.RegionOrder, index)
		end
	end
	for id, entry in world.Altars do
		if not world.Regions[entry.Region] then
			world.Altars[id] = nil
		end
	end
	-- Inactive bosses keep their ids, remembrance and endings but have no region, arena or fog gate
	-- in play: they sit on a reserved site (data only) and nothing spawns them.
	for id, boss in world.Bosses do
		if id ~= barrier.Boss then
			local site = Overworld.ReservedArenas[id]
			assert(site, "No reserved arena for inactive boss " .. id)
			local c = site.Arena.Center
			boss.Region, boss.Arena, boss.Inactive = site.Region, site.Arena, true
			boss.Spawn = { X = c.X, Y = c.Y, Z = c.Z, Yaw = 180 }
			world.FogGates[boss.FogGate] = nil
		end
	end
end

-- Discoveries: a POI is found by standing within POI studs of it (3D, so a cave interior is not found from
-- the surface), a landmark within Landmark studs on the ground plane. The server calls this once a second.
Overworld.RevealRadius = { POI = 40, Landmark = 150 }
function Overworld.revealedAt(x: number, y: number, z: number): { string }
	local ids: { string } = {}
	local r = Overworld.RevealRadius
	for _, p in Overworld.POIs do
		local d = p.Position
		if (d.X - x) ^ 2 + (d.Y - y) ^ 2 + (d.Z - z) ^ 2 <= r.POI ^ 2 then
			table.insert(ids, p.Id)
		end
	end
	for id, l in Overworld.Landmarks do
		if (l.Position.X - x) ^ 2 + (l.Position.Z - z) ^ 2 <= r.Landmark ^ 2 then
			table.insert(ids, id)
		end
	end
	return ids
end

local function deepFreeze(value: any)
	if type(value) ~= "table" or table.isfrozen(value) then
		return
	end
	for _, child in value do
		deepFreeze(child)
	end
	table.freeze(value)
end
for key, value in Overworld do
	if type(value) == "table" then
		deepFreeze(value)
	end
end

return table.freeze(Overworld)

--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/BiomeDressing
-- Placement DATA for the four non-forest biomes (open-world issues 13-16): Amberfall Ravine (GoldenRavine), The Saltreach
-- (AridBasin), Frostmere Heads (Snowfields), The Ashen Stair (MountainAscent). Same data shape as SliceDressing so one builder
-- can consume both: Pieces (kit slots; planned names and intended sizes, NO mesh files exist), Hero placements, scatter rules,
-- Keep exclusions (reused from SliceDressing), plus what the slice did not need: roofed Interiors (caves, hall, gallery:
-- entrance, extents, AsuraShelter roof spans) and lift end-structures. Nothing here is built, mapped or an asset id.
-- Mass dressing with meshes is gated on the slice review; this module only fixes WHERE and WHAT SIZE.
-- A placement's Y is Overworld.heightAt at its foot (GX, GZ), as in the slice. Interior placements stand on their own floor Y.
--
-- Copied from SliceDressing because it does not export them (export wanted if one builder serves both): hash/rand, circles
-- (it looks pieces up in SliceDressing.Pieces), crowded.
local hasScript = pcall(function() return script.Parent end)
local Overworld: any = if hasScript then require(script.Parent.Overworld) else require("./Overworld")
local Slice: any = if hasScript then require(script.Parent.SliceDressing) else require("./SliceDressing")

local BiomeDressing = {}

BiomeDressing.Seed = 20261116
BiomeDressing.Cell = Slice.Cell
BiomeDressing.Keep = Slice.Keep
BiomeDressing.MobLeash = Slice.MobLeash
BiomeDressing.Classes = { "Rock", "Tree", "Shrub", "Fern", "Grass" } -- own list: SliceDressing.Classes carries the forest's 13
BiomeDressing.Order = { "GoldenRavine", "AridBasin", "Snowfields", "MountainAscent" }
BiomeDressing.ImportYaw = {} :: { [string]: number }
-- Per biome (the slice's numbers); test_biome_dressing asserts every biome stays inside.
BiomeDressing.Budget = { MeshParts = 3000, PlaceholderParts = 3400, Tris = 5000000, TrisLod = 3200000, Placements = 1900 }

-------------------------------------------------------------------------------------------------
-- Kit slots. Size = { X, Y up, Z } studs, pivot = foot centre. s() = one sub-mesh (MeshPart) with a full-footprint placeholder box.
-------------------------------------------------------------------------------------------------

local function s(name: string, material: string, color: { number }, tris: number, collide: boolean?, lod: boolean?, shape: string?): any
	return { Name = name, Material = material, Color = color, Tris = tris, B = { { 0, 0, 0, 1, 1, 1 } }, Collide = collide == true, Lod = lod == true, Shape = shape or "Block" }
end
local function steps(color: { number }, tris: number, n: number, rise: number, tread: number, width: number): any
	return { Name = "Stone", Material = "Slate", Color = color, Tris = tris, B = {}, Collide = true, Lod = false, Shape = "Steps", Steps = n, Rise = rise, Tread = tread, Width = width }
end
local function kit(size: { number }, sink: number, structure: boolean, subs: { any }, trunk: number?): any
	return { Size = size, Sink = sink, Structure = if structure then true else nil, Trunk = trunk, Subs = subs }
end

local AMB, AMBD, BRZ, TIM, STN, GLW = { 196, 148, 92 }, { 150, 104, 64 }, { 150, 112, 58 }, { 150, 62, 42 }, { 112, 108, 100 }, { 255, 190, 110 }
local SND, SLT, SNW, ICE, BAS = { 200, 176, 128 }, { 232, 230, 222 }, { 226, 232, 240 }, { 170, 205, 225 }, { 70, 68, 72 }
local BARK, REDB, DRY, BRG, PGR = { 84, 62, 46 }, { 128, 72, 56 }, { 150, 130, 70 }, { 170, 120, 60 }, { 226, 214, 160 }
local PINE, PINE2, FRO, GRS, ROK = { 40, 78, 60 }, { 56, 98, 74 }, { 150, 170, 160 }, { 110, 140, 70 }, { 104, 100, 94 }

local P: { [string]: any } = {
	-- Shared interiors (caves, cistern hall, cliff gallery)
	Cave_Mouth_Arch = kit({ 22, 16, 10 }, 0.5, true, { s("Stone", "Slate", STN, 3200, true), s("Trim", "Wood", TIM, 400) }),
	Cave_Rib_Arch = kit({ 18, 15, 3 }, 0.2, true, { s("Stone", "Slate", STN, 900, true) }),
	Cave_Roof_Slab = kit({ 24, 3, 24 }, 0, true, { s("Stone", "Slate", STN, 600, true) }),
	Cave_Brazier = kit({ 3, 6, 3 }, 0.1, true, { s("Bronze", "Metal", BRZ, 300, true), s("Glow", "Neon", GLW, 40) }),
	Cave_Stair_Run = kit({ 10, 8, 20 }, 0.2, true, { steps(STN, 1300, 10, 0.8, 2, 10) }),

	-- Amberfall Ravine
	Ravine_Mausoleum = kit({ 36, 30, 40 }, 1.5, true, { s("Stone", "Sandstone", AMB, 9000, true), s("Roof", "Slate", STN, 3000), s("Door", "Metal", BRZ, 600) }),
	Ravine_Overlook_Pavilion = kit({ 30, 22, 30 }, 0.5, true, { s("Pillars", "Sandstone", AMB, 3000, true), s("Floor", "Slate", STN, 600, true), s("Roof", "Wood", TIM, 2800) }),
	Ravine_Overlook_Parapet = kit({ 14, 4, 2.4 }, 0.4, true, { s("Stone", "Sandstone", AMB, 700, true) }),
	Ravine_Span_Pylon = kit({ 7, 16, 7 }, 0.6, true, { s("Stone", "Sandstone", AMB, 1100, true), s("Bronze", "Metal", BRZ, 200) }),
	Ravine_Rope_Post = kit({ 2.4, 9, 2.4 }, 0.5, true, { s("Timber", "Wood", TIM, 260, true) }),
	Ravine_Lift_Station = kit({ 18, 22, 18 }, 0.8, true, { s("Stone", "Sandstone", AMB, 3200, true), s("Timber", "Wood", TIM, 2800, true), s("Winch", "Metal", BRZ, 600) }),
	Ravine_Lift_Pylon = kit({ 6, 40, 6 }, 0.8, true, { s("Timber", "Wood", TIM, 1800, true) }),
	Ravine_Cliff_Stair = kit({ 6, 20, 12 }, 0.3, true, { steps(AMB, 900, 22, 0.9, 0.5, 6) }),
	Ravine_Grotto_Landing = kit({ 20, 2, 14 }, 0, true, { s("Stone", "Sandstone", AMB, 600, true) }),
	Ravine_Bell_Post = kit({ 4, 12, 4 }, 0.5, true, { s("Stone", "Sandstone", AMB, 200, true), s("Bell", "Metal", BRZ, 500) }),
	Ravine_Cairn = kit({ 3.2, 4.2, 3.2 }, 0.3, false, { s("Stone", "Sandstone", AMB, 500) }),

	-- The Saltreach
	Basin_Statue_Hand = kit({ 22, 14, 30 }, 1, true, { s("Stone", "Sandstone", SND, 8000, true) }),
	Basin_Statue_Head = kit({ 26, 28, 30 }, 1.5, true, { s("Stone", "Sandstone", SND, 10000, true) }),
	Basin_Cistern_Pavilion = kit({ 22, 16, 16 }, 0.5, true, { s("Stone", "Sandstone", SND, 3500, true), s("Roof", "Slate", STN, 2000) }),
	Basin_Cistern_Stair = kit({ 12, 12, 22 }, 0.3, true, { steps(SND, 1500, 12, 1, 1.8, 12) }),
	Basin_Kiln_Shed = kit({ 30, 14, 20 }, 0.6, true, { s("Stone", "Sandstone", SND, 4200, true), s("Timber", "Wood", TIM, 3000, true), s("Roof", "Slate", STN, 2600) }),
	Basin_Kiln_Stack = kit({ 14, 42, 14 }, 1, true, { s("Brick", "Brick", AMBD, 5200, true) }),
	Basin_Clay_Heap = kit({ 10, 4, 10 }, 0.4, false, { s("Clay", "Mud", AMBD, 1500) }),
	Basin_Caravan_Post = kit({ 2, 10, 2 }, 0.5, true, { s("Timber", "Wood", TIM, 300, true) }),
	Basin_Canyon_Gate = kit({ 26, 22, 6 }, 0.8, true, { s("Stone", "Sandstone", SND, 5000, true) }),
	Basin_Ruin_Wall = kit({ 16, 8, 3 }, 0.5, true, { s("Stone", "Sandstone", SND, 1500, true) }),
	Basin_Obelisk = kit({ 5, 26, 5 }, 0.8, true, { s("Stone", "Sandstone", SND, 1800, true) }),
	Basin_Caravan_Wreck = kit({ 16, 7, 8 }, 0.5, false, { s("Timber", "Wood", TIM, 3600), s("Cloth", "Fabric", SND, 1200) }),
	Salt_Cairn = kit({ 4, 5, 4 }, 0.3, false, { s("Salt", "Salt", SLT, 600) }),
	Salt_Crystal_Cluster = kit({ 9, 8, 9 }, 0.5, false, { s("Salt", "Salt", SLT, 3000) }),

	-- Frostmere Heads
	Snow_Ruin_Wall = kit({ 14, 8, 3 }, 0.5, true, { s("Stone", "Slate", STN, 1400, true) }),
	Snow_Ruin_Pillar = kit({ 4, 14, 4 }, 0.6, true, { s("Stone", "Slate", STN, 600, true) }),
	Snow_Refuge_Hut = kit({ 24, 12, 18 }, 0.5, true, { s("Stone", "Slate", STN, 4000, true), s("Timber", "Wood", TIM, 3600, true), s("Roof", "Wood", TIM, 2400) }),
	Snow_Windbreak = kit({ 16, 7, 2.4 }, 0.4, true, { s("Stone", "Slate", STN, 800, true) }),
	Snow_Trail_Stake = kit({ 1.2, 14, 1.2 }, 0.6, true, { s("Pole", "Wood", TIM, 120, true), s("Banner", "Fabric", { 190, 40, 40 }, 80) }),
	Snow_Ice_Marker = kit({ 3, 9, 3 }, 0.4, true, { s("Ice", "Glacier", ICE, 400, true) }),
	Snow_Pass_Gate = kit({ 22, 18, 5 }, 0.6, true, { s("Stone", "Slate", STN, 2600, true) }),
	Snow_Pass_Cairn = kit({ 4, 5, 4 }, 0.3, false, { s("Stone", "Slate", STN, 600) }),

	-- The Ashen Stair
	Mtn_Thousand_Steps_Gate = kit({ 36, 34, 8 }, 1, true, { s("Stone", "Slate", STN, 7000, true), s("Timber", "Wood", TIM, 3000, true) }),
	Mtn_Pass_Gate = kit({ 24, 18, 5 }, 0.6, true, { s("Stone", "Slate", STN, 3600, true) }),
	Mtn_Stair_Run = kit({ 14, 12, 22 }, 0.4, true, { steps(STN, 2200, 14, 0.85, 1.6, 14) }),
	Mtn_Retaining_Wall = kit({ 18, 10, 3.6 }, 0.6, true, { s("Stone", "Slate", STN, 1600, true) }),
	Mtn_Refuge_Hall = kit({ 28, 14, 22 }, 0.6, true, { s("Stone", "Slate", STN, 5000, true), s("Timber", "Wood", TIM, 3800, true), s("Roof", "Slate", BAS, 2600) }),
	Mtn_Windbreak = kit({ 18, 8, 2.6 }, 0.4, true, { s("Stone", "Slate", STN, 900, true) }),
	Mtn_Lift_Station = kit({ 18, 24, 18 }, 0.8, true, { s("Stone", "Slate", STN, 3400, true), s("Timber", "Wood", TIM, 3000, true), s("Winch", "Metal", BRZ, 700) }),
	Mtn_Lift_Pylon = kit({ 6, 46, 6 }, 0.8, true, { s("Timber", "Wood", TIM, 2000, true) }),
	Mtn_Wind_Cairn = kit({ 4, 6, 4 }, 0.3, false, { s("Stone", "Slate", STN, 700) }),
	Mtn_Viewpoint_Cairn = kit({ 8, 9, 8 }, 0.5, false, { s("Stone", "Slate", STN, 1800) }),
}

-------------------------------------------------------------------------------------------------
-- Upload kits (lanes D5, K): every piece of assets/source/overworld/upload/{amberfall,saltreach,frostmere,ashen}/upload_manifest.json has a placeholder spec.
-- Data only: rows are { piece, family (v veg, r rock, b built, h hero), silhouette archetype (SIL below), X, Y up, Z, "Sub:tris ..." } copied from
-- the manifests (size_studs_xyz_roblox, sub_meshes), so sub names match the registry keys (<Piece>__<Sub>) and a real-mesh swap stays a data
-- change: Registry (generated module) -> Assets -> silhouette placeholder. test_biome_dressing checks every row against its own copy, +-5%.
-------------------------------------------------------------------------------------------------

local AMBERFALL_KIT: { any } = {
	{ "Amber_Maple_Red", "v", "Tree", 37.2, 42.0, 40.5, "Bark:1602 Leaves_Detail:9640 Leaves_Mass:3456" },
	{ "Amber_Stump", "v", "Column", 15.2, 7.3, 15.2, "Bark:756 Ends:18" },
	{ "Amber_Grass_Pale", "v", "Tuft", 6.8, 5.1, 7.1, "Blades:770" },
	{ "Amber_Maple_Gold", "v", "Tree", 45.2, 36.5, 40.5, "Bark:1984 Leaves_Detail:12064 Leaves_Mass:4320" },
	{ "Amber_RedTrunk_A", "v", "Tree", 34.0, 44.7, 31.9, "Bark:1036 Leaves_Detail:6280 Leaves_Mass:2304" },
	{ "Amber_RedTrunk_B", "v", "Tree", 25.4, 57.7, 25.5, "Bark:940 Leaves_Detail:5472 Leaves_Mass:2016" },
	{ "Amber_Cliff_Pine", "v", "Conifer", 30.4, 31.6, 25.8, "Bark:768 Leaves_Detail:2832 Leaves_Mass:1728" },
	{ "Amber_Maple_Sapling", "v", "Tree", 20.6, 19.2, 19.3, "Bark:856 Leaves_Detail:5472 Leaves_Mass:2016" },
	{ "Amber_Dead_Snag", "v", "Snag", 15.5, 37.9, 12.4, "Bark:698 Ends:14" },
	{ "Amber_Fallen_Log", "v", "Slab", 26.8, 6.1, 10.4, "Bark:840 Ends:28" },
	{ "Amber_Root_Tangle", "v", "Slab", 20.1, 5.8, 20.9, "Bark:864" },
	{ "Amber_Shrub_Dry", "v", "Plant", 12.2, 6.8, 13.8, "Leaves:3872 Stems:2592" },
	{ "Amber_Shrub_Sumac", "v", "Plant", 11.2, 7.0, 9.1, "Leaves:2976 Stems:2016" },
	{ "Amber_Fern_Bronze", "v", "Plant", 10.8, 2.7, 10.9, "Fronds:2112" },
	{ "Amber_Leaf_Litter_A", "v", "Slab", 20.6, 0.6, 21.1, "Leaves:5760 Twigs:200" },
	{ "Amber_Leaf_Litter_B", "v", "Slab", 16.5, 2.5, 16.6, "Leaves:7200" },
	{ "Amber_Grass_Dry", "v", "Tuft", 5.3, 2.5, 5.9, "Blades:600" },
	{ "Amber_Grass_Seed", "v", "Tuft", 5.6, 5.5, 5.1, "Blades:392 Seeds:768" },
	{ "Amber_Boulder_A", "r", "Rock", 20.7, 8.8, 12.9, "Stone:8000" },
	{ "Amber_Cliff_Wall_A", "r", "Rock", 42.3, 33.8, 27.1, "Stone:9040" },
	{ "Amber_Ledge_Overhang", "r", "Rock", 27.6, 19.5, 21.4, "Stone:4228" },
	{ "Amber_Cliff_Corner", "r", "Rock", 45.2, 29.9, 38.8, "Stone:14912" },
	{ "Amber_Spire", "r", "Tower", 12.9, 41.3, 13.2, "Stone:7124" },
	{ "Amber_Boulder_B", "r", "Rock", 13.6, 12.5, 8.9, "Stone:7680" },
	{ "Amber_Boulder_C", "r", "Rock", 32.1, 4.4, 12.0, "Stone:6720" },
	{ "Amber_Scree_A", "r", "Slab", 21.5, 2.6, 20.0, "Stone:1620" },
	{ "Amber_Scree_B", "r", "Slab", 17.5, 2.6, 18.5, "Stone:2200" },
	{ "Amber_Cliff_Wall_B", "r", "Rock", 29.8, 48.1, 21.2, "Stone:11632" },
	{ "Amber_Ledge_Long", "r", "Slab", 33.6, 5.2, 14.7, "Stone:2948" },
	{ "Amber_Aqueduct_Span_A", "b", "Arcade", 24.0, 32.8, 8.9, "Arches:772 Deck:836 Piers:1320" },
	{ "Amber_Aqueduct_Span_Tall", "b", "Arcade", 24.0, 50.8, 10.0, "Arches:1472 Deck:1144 Piers:2420" },
	{ "Amber_Footbridge_Rope", "b", "Slab", 64.2, 11.5, 9.4, "Rope:1088 Stone:352 Timber:1056" },
	{ "Amber_Aqueduct_Span_Ruined", "b", "Arcade", 24.0, 29.8, 13.9, "Arches:1540 Deck:176 Piers:1012" },
	{ "Amber_Aqueduct_Abutment", "b", "Hall", 23.0, 32.8, 22.6, "Arches:196 Deck:836 Piers:2156" },
	{ "Amber_Stair_Run", "b", "Ramp", 12.4, 13.6, 24.1, "Steps:528 Walls:2112" },
	{ "Amber_Stair_Worn", "b", "Ramp", 12.4, 13, 24.1, "Steps:396 Walls:792" },
	{ "Amber_Retaining_Wall_A", "b", "Wall", 22.2, 11.1, 6.9, "Coping:308 Wall:1892" },
	{ "Amber_Retaining_Wall_B", "b", "Wall", 24.1, 10.1, 13.7, "Coping:264 Wall:2288" },
	{ "Amber_Shrine", "b", "Hall", 21.0, 22.3, 21.7, "Bronze:436 Glow:44 Roof:1312 Stone:660 Timber:352" },
	{ "Amber_Lantern_Stone", "b", "Column", 4.1, 10.6, 4.1, "Bronze:248 Glow:44 Stone:232" },
	{ "Amber_Lantern_Hanging", "b", "Column", 6.5, 12.2, 2.2, "Bronze:136 Glow:44 Rope:12 Timber:116" },
	{ "Amber_Rope_Rail", "b", "Wall", 13.4, 5.2, 1.4, "Rope:172 Timber:112" },
	{ "Amber_Cart", "b", "Slab", 21.4, 6.8, 8.7, "Timber:1920" },
	{ "Amber_Crate_Stack", "b", "Slab", 12.9, 6.7, 9.2, "Rope:408 Timber:1840" },
	{ "Amber_Aqueduct_Hero", "h", "Arcade", 120, 82.1, 25.9, "Arches:8732 Deck:4752 Piers:16720" },
}
local SALTREACH_KIT: { any } = {
	{ "Salt_Pan_Frame", "b", "Slab", 27.2, 9.0, 17.0, "Bund:528 Crust:264 Timber:582" },
	{ "Boardwalk_Straight", "b", "Slab", 16, 7.0, 5.4, "Rope:288 Timber:1072" },
	{ "Fisher_Hut_A", "b", "Hall", 17.2, 14.8, 14.6, "Roof:836 Stone:3608 Timber:2880" },
	{ "Salt_Pan_Channel", "b", "Slab", 32, 8.7, 12, "Crust:44 Stone:7040 Timber:760" },
	{ "Boardwalk_Steps", "b", "Ramp", 11.3, 11.0, 5.5, "Rope:88 Timber:784" },
	{ "Pier_Section", "b", "Slab", 22, 12.6, 8.6, "Timber:1964" },
	{ "Pier_End", "b", "Column", 12.1, 19, 8.8, "Iron:156 Lantern:44 Rope:172 Timber:1128" },
	{ "Net_Rack", "b", "Wall", 23.0, 11.8, 7.6, "Net:1008 Timber:136" },
	{ "Boat_Hull_A", "b", "Slab", 24.7, 7.3, 7.9, "Canvas:160 Hull:1440 Ribs:942" },
	{ "Boat_Hull_B", "b", "Slab", 21.0, 6.0, 6.4, "Hull:884 Ribs:1048" },
	{ "Fisher_Hut_B", "b", "Hall", 16.4, 17.8, 13.4, "Roof:396 Stone:1056 Timber:2936" },
	{ "Stone_Lantern_Salt", "b", "Column", 6.1, 13.9, 7.0, "Glow:28 Iron:28 Stone:460" },
	{ "Gate_Pier", "b", "Column", 10.7, 25.1, 8.8, "Iron:144 Stone:4400 Timber:44" },
	{ "Gate_Arch", "b", "Arch", 36.8, 28.7, 8.8, "Iron:456 Stone:8800 Timber:128" },
	{ "Saltreach_Gate_Statue", "h", "Tower", 70.2, 142.8, 46.6, "Anchor:532 Arms:1336 Base:9328 Body:6832 Cords:156 Head:4020" },
	{ "Sea_Stack_Base", "r", "Rock", 30.7, 18.5, 25.0, "Stone:8000" },
	{ "Tide_Boulder_A", "r", "Rock", 20.5, 9.2, 13.8, "Stone:8000" },
	{ "Salt_Crust_Slab_A", "r", "Slab", 33.4, 2.4, 22.1, "Crust:528" },
	{ "Sea_Stack_Mid", "r", "Tower", 17.5, 16, 18.7, "Stone:5120" },
	{ "Sea_Stack_Cap", "r", "Rock", 15.3, 16.3, 15.4, "Stone:5440" },
	{ "Tide_Boulder_B", "r", "Rock", 14.0, 11.4, 8.8, "Stone:7680" },
	{ "Tide_Boulder_C", "r", "Rock", 28.3, 4.4, 12.9, "Stone:6720" },
	{ "Salt_Crust_Slab_B", "r", "Slab", 29.0, 2.5, 26.1, "Crust:440" },
	{ "Shore_Cliff_A", "r", "Rock", 44.8, 24.6, 11.3, "Stone:5120" },
	{ "Shore_Cliff_B", "r", "Rock", 47.9, 27.5, 11.7, "Stone:6400" },
	{ "Shore_Cliff_Corner", "r", "Rock", 32.6, 27.3, 38.6, "Stone:6400" },
	{ "Salt_Pine_A", "v", "Conifer", 36.9, 53.8, 31.5, "Bark:1188 Needles_Detail:14016 Needles_Mass:7680" },
	{ "Dune_Scrub_A", "v", "Plant", 7.9, 3.1, 8.1, "Leaves:1080 Stems:414" },
	{ "Driftwood_Log", "v", "Slab", 23.4, 6.6, 7.2, "Wood:586" },
	{ "Salt_Pine_B", "v", "Conifer", 26.6, 35.8, 23.8, "Bark:1004 Needles_Detail:11232 Needles_Mass:6144" },
	{ "Salt_Pine_Dead", "v", "Snag", 21.7, 42.2, 15.8, "Bark:1572" },
	{ "Salt_Grass_Tuft", "v", "Tuft", 6.6, 3.3, 4.8, "Blades:770" },
	{ "Salt_Grass_Tall", "v", "Tuft", 9.5, 6.1, 6.2, "Blades:630" },
	{ "Dune_Scrub_B", "v", "Plant", 4.3, 1.7, 5.0, "Leaves:840 Stems:322" },
	{ "Driftwood_Pile", "v", "Slab", 17.9, 8.2, 15.7, "Wood:1722" },
	{ "Kelp_Wrack", "v", "Slab", 25.9, 1.1, 25.4, "Blades:336 Holdfast:320" },
	{ "Shore_Reeds", "v", "Plant", 9.9, 14.2, 8.1, "Blades:630 Heads:560" },
}

local FROSTMERE_KIT: { any } = {
	{ "Frost_Fir_A", "v", "Conifer", 16.6, 47.5, 16.3, "Bark:254 Boughs:4524 Snow:4524" },
	{ "Frost_Fir_B", "v", "Conifer", 12.4, 61.5, 12.3, "Bark:254 Boughs:5436 Snow:5436" },
	{ "Frost_Fir_Broad", "v", "Conifer", 20.5, 35.5, 21.8, "Bark:254 Boughs:3216 Snow:3216" },
	{ "Frost_Fir_Sapling", "v", "Conifer", 8.2, 15.9, 8.7, "Bark:254 Boughs:1620 Snow:1620" },
	{ "Frost_Birch_A", "v", "Tree", 19.3, 31.2, 24.1, "Bark:908 Twigs:3360" },
	{ "Frost_Birch_B", "v", "Tree", 25.3, 23.1, 20.1, "Bark:796 Twigs:2800" },
	{ "Frost_Shrub_Frozen", "v", "Plant", 9, 5.5, 11, "Ice:980 Snow:2792 Stems:2072" },
	{ "Frost_Shrub_Small", "v", "Plant", 3.3, 2.7, 3.3, "Ice:260 Snow:712 Stems:504" },
	{ "Frost_Grass_Tuft_A", "v", "Tuft", 4.6, 2.9, 4.5, "Blades:350 Snow:96" },
	{ "Frost_Grass_Tuft_B", "v", "Tuft", 7.1, 4.9, 6.2, "Blades:630 Snow:96" },
	{ "Frost_Dead_Snag", "v", "Snag", 14.8, 36.7, 11.6, "Bark:698 Ends:14 Snow:344" },
	{ "Frost_Fallen_Log", "v", "Slab", 25.8, 6.4, 13.4, "Bark:520 Ends:28 Snow:2112" },
	{ "Frost_Boulder_A", "r", "Rock", 16.4, 7.3, 10, "Stone:7680" },
	{ "Frost_Boulder_B", "r", "Rock", 11.3, 10.3, 7.3, "Stone:7680" },
	{ "Frost_Boulder_C", "r", "Rock", 23.8, 3.9, 9.9, "Stone:6720" },
	{ "Frost_Ice_Shards_A", "r", "Rock", 14.7, 12.9, 16.4, "Base:1600 Ice:484" },
	{ "Frost_Ice_Shards_B", "r", "Rock", 9.2, 8.8, 7.8, "Base:1600 Ice:308" },
	{ "Frost_Cliff_Wall_A", "r", "Rock", 41.8, 34, 23.8, "Stone:8176" },
	{ "Frost_Cliff_Wall_B", "r", "Rock", 29.5, 47.5, 23, "Stone:11200" },
	{ "Frost_Cliff_Corner", "r", "Rock", 45.8, 29.8, 36.5, "Stone:17504" },
	{ "Frost_Scree_A", "r", "Slab", 20.1, 2.8, 19.8, "Stone:1620" },
	{ "Frost_Scree_B", "r", "Slab", 16.8, 2.4, 18.2, "Stone:2200" },
	{ "Frost_Fishing_Hut", "b", "Hall", 19.6, 14.4, 20.3, "Ice:44 Iron:56 Roof:24 Rope:14 Snow:536 Timber:2688" },
	{ "Frost_Cairn", "b", "Column", 11.4, 17.2, 9.9, "Stone:4800" },
	{ "Frost_Dock_Section", "b", "Slab", 29.2, 5.6, 19.8, "Ice:420 Snow:1056 Timber:984" },
	{ "Frost_Prayer_Flags", "b", "Wall", 34.4, 16, 8.6, "Flags:480 Footing:2560 Poles:184 Rope:140" },
	{ "Frost_Brazier", "b", "Column", 8.2, 10.5, 7.7, "Fire:456 Iron:406 Snow:112 Stone:44" },
	{ "Frost_Stair_Run", "b", "Ramp", 12.4, 13.9, 24.1, "Snow:1144 Steps:528 Walls:2112" },
	{ "Frost_Retaining_Wall", "b", "Wall", 25.9, 10.6, 11.2, "Coping:308 Snow:692 Wall:2068" },
	{ "Frost_Sled", "b", "Slab", 15.9, 4.6, 4.5, "Iron:232 Rope:104 Snow:192 Timber:980" },
	{ "Frost_Lantern", "b", "Column", 7, 12.3, 6.9, "Glow:44 Iron:248 Snow:216 Stone:232" },
	{ "Frost_Beacon_Hero", "h", "Tower", 18, 100, 18.1, "Fire:516 Stone:6432 Timber:3260" },
}
local ASHEN_KIT: { any } = {
	{ "Ash_Pine_A", "v", "Conifer", 17.3, 54.6, 19.8, "Bark:884 Boughs:2304 Boughs_Detail:3288" },
	{ "Ash_Lichen_B", "v", "Slab", 6.3, 0.7, 7.7, "Crust:400" },
	{ "Ash_Pine_B", "v", "Conifer", 15.8, 68.6, 16.3, "Bark:1036 Boughs:2880 Boughs_Detail:4104" },
	{ "Ash_Pine_C", "v", "Conifer", 19.4, 31, 17.8, "Bark:680 Boughs:1728 Boughs_Detail:2456" },
	{ "Ash_Snag_A", "v", "Snag", 13.9, 40.2, 12.3, "Bark:790 Ends:14" },
	{ "Ash_Snag_B", "v", "Snag", 12.2, 32.8, 12.8, "Bark:760 Ends:14" },
	{ "Ash_Snag_Fallen", "v", "Slab", 23.6, 5.5, 9.4, "Bark:680 Ends:28" },
	{ "Ash_Shrub", "v", "Plant", 12.7, 6.7, 11.5, "Leaves:3952 Stems:2664" },
	{ "Ash_Shrub_Small", "v", "Plant", 5.8, 3.7, 7.1, "Leaves:2640 Stems:1764" },
	{ "Ash_Tussock_A", "v", "Tuft", 7.3, 3, 7.5, "Blades:910" },
	{ "Ash_Tussock_B", "v", "Tuft", 5.1, 2.5, 4.9, "Blades:350" },
	{ "Ash_Lichen_A", "v", "Slab", 8.2, 0.8, 8.6, "Crust:720" },
	{ "Ash_Boulder_A", "r", "Rock", 19.4, 9.9, 12.1, "Stone:8000" },
	{ "Ash_Boulder_B", "r", "Rock", 13.5, 11.3, 8.4, "Stone:7680" },
	{ "Ash_Boulder_C", "r", "Rock", 30.5, 4.6, 11.7, "Stone:6720" },
	{ "Ash_Scree_A", "r", "Slab", 18.2, 2.8, 21.3, "Stone:1620" },
	{ "Ash_Scree_B", "r", "Slab", 17.8, 2.5, 19, "Stone:2200" },
	{ "Ash_Cliff_Switchback_A", "r", "Rock", 40.7, 33.9, 23.7, "Stone:6820" },
	{ "Ash_Cliff_Switchback_B", "r", "Rock", 30.6, 46.1, 20, "Stone:6856" },
	{ "Ash_Cliff_Corner", "r", "Rock", 45, 32.2, 37.6, "Stone:8000" },
	{ "Ash_Ledge", "r", "Slab", 33.5, 5.1, 15.8, "Stone:2948" },
	{ "Ash_Crag", "r", "Tower", 16.3, 41.3, 10.8, "Stone:16004" },
	{ "Ash_Stair_Run_Straight", "b", "Ramp", 14.4, 14.7, 22.6, "Steps:616 Walls:2464" },
	{ "Ash_Stair_Run_Long", "b", "Ramp", 10.8, 26.6, 45, "Steps:1232 Walls:4928" },
	{ "Ash_Stair_Run_Turn", "b", "Ramp", 25.1, 16.4, 25.1, "Steps:748 Walls:2992" },
	{ "Ash_Retaining_Wall_A", "b", "Wall", 18.2, 12.1, 7, "Coping:264 Wall:1540" },
	{ "Ash_Retaining_Wall_B", "b", "Wall", 22.1, 11.1, 12.3, "Coping:220 Wall:2068" },
	{ "Ash_Shrine_Pilgrim", "b", "Hall", 13, 15.8, 15.3, "Bronze:1028 Glow:44 Roof:1088 Stone:264 Timber:600" },
	{ "Ash_Prayer_Flags", "b", "Wall", 29.8, 17.4, 3.7, "Flags:336 Poles:144 Rope:136 Stone:176" },
	{ "Ash_Lantern_Stone", "b", "Column", 4.1, 10.6, 4.1, "Bronze:248 Glow:44 Stone:232" },
	{ "Ash_Rest_Pavilion", "b", "Hall", 30.3, 24.1, 30.4, "Bronze:656 Roof:1568 Stone:528 Timber:1588" },
	{ "Ash_Gate_Broken", "b", "Arch", 25, 18.2, 12.1, "Stone:1144 Timber:36" },
	{ "Ash_Summit_Pagoda", "h", "Tower", 60, 160.6, 60, "Bronze:4544 Roof:9440 Stone:4048 Timber:10824" },
	{ "Ash_Summit_Wing", "h", "Hall", 40, 60, 50, "Roof:3168 Stone:792 Timber:5892" },
}

local ROPE, SALTW, IRON, CANVAS, TWIG = { 150, 125, 85 }, { 128, 108, 84 }, { 74, 74, 80 }, { 210, 200, 176 }, { 120, 92, 60 }
-- Material and colour by the sub name's first word, per kit (the stone palette differs: amber sandstone against pale shore stone).
local LOOKS_AMBER: { [string]: { any } } = {
	Bark = { "Wood", BARK }, Ends = { "Wood", { 170, 140, 100 } }, Stems = { "Wood", BARK }, Twigs = { "Wood", TWIG }, Leaves = { "Grass", DRY }, Blades = { "Grass", PGR }, Seeds = { "Grass", DRY }, Fronds = { "Grass", BRG },
	Stone = { "Sandstone", AMB }, Timber = { "Wood", TIM }, Bronze = { "Metal", BRZ }, Glow = { "Neon", GLW }, Rope = { "Fabric", ROPE }, Roof = { "Slate", STN }, Coping = { "Sandstone", AMBD },
	Arches = { "Sandstone", AMBD }, Piers = { "Sandstone", AMB }, Deck = { "Slate", STN }, Steps = { "Sandstone", AMB }, Walls = { "Sandstone", AMBD }, Wall = { "Sandstone", AMB },
}
local LOOKS_SALT: { [string]: { any } } = {
	Bark = { "Wood", SALTW }, Wood = { "Wood", SALTW }, Needles = { "Grass", PINE2 }, Leaves = { "Grass", DRY }, Stems = { "Wood", SALTW }, Blades = { "Grass", PGR }, Heads = { "Grass", DRY },
	Holdfast = { "Wood", TWIG }, Stone = { "Limestone", SND }, Timber = { "Wood", SALTW }, Iron = { "Metal", IRON }, Glow = { "Neon", GLW }, Lantern = { "Neon", GLW }, Rope = { "Fabric", ROPE },
	Roof = { "Slate", STN }, Bund = { "Sandstone", SND }, Crust = { "Salt", SLT }, Canvas = { "Fabric", CANVAS }, Hull = { "Wood", SALTW }, Ribs = { "Wood", TWIG }, Net = { "Fabric", ROPE },
	Anchor = { "Metal", IRON }, Arms = { "Sandstone", SND }, Base = { "Slate", STN }, Body = { "Sandstone", SND }, Cords = { "Fabric", ROPE }, Head = { "Sandstone", SND },
}
local LOOKS_FROST: { [string]: { any } } = {
	Bark = { "Wood", BARK }, Boughs = { "Grass", PINE }, Snow = { "Snow", SNW }, Twigs = { "Wood", TWIG }, Stems = { "Wood", TWIG }, Ice = { "Glacier", ICE }, Blades = { "Grass", PGR }, Ends = { "Wood", { 170, 140, 100 } },
	Stone = { "Slate", STN }, Base = { "Slate", STN }, Footing = { "Slate", STN }, Steps = { "Slate", STN }, Wall = { "Slate", STN }, Walls = { "Slate", BAS }, Coping = { "Slate", BAS }, Roof = { "Slate", BAS },
	Iron = { "Metal", IRON }, Rope = { "Fabric", ROPE }, Timber = { "Wood", TIM }, Poles = { "Wood", TIM }, Flags = { "Fabric", { 190, 40, 40 } }, Fire = { "Neon", GLW }, Glow = { "Neon", GLW },
}
local LOOKS_ASH: { [string]: { any } } = {
	Bark = { "Wood", BARK }, Boughs = { "Grass", PINE }, Leaves = { "Grass", PINE2 }, Stems = { "Wood", BARK }, Blades = { "Grass", GRS }, Crust = { "Grass", { 150, 160, 96 } }, Ends = { "Wood", { 170, 140, 100 } },
	Stone = { "Slate", STN }, Steps = { "Slate", STN }, Wall = { "Slate", STN }, Walls = { "Slate", BAS }, Coping = { "Slate", BAS }, Roof = { "Slate", BAS }, Bronze = { "Metal", BRZ }, Glow = { "Neon", GLW },
	Timber = { "Wood", TIM }, Poles = { "Wood", TIM }, Flags = { "Fabric", { 190, 40, 40 } }, Rope = { "Fabric", ROPE },
}
local LEAF_TINT: { [string]: { number } } = { Amber_Maple_Red = { 170, 56, 40 }, Amber_Maple_Gold = { 212, 164, 56 }, Amber_Maple_Sapling = { 190, 110, 50 }, Amber_RedTrunk_A = { 186, 98, 52 },
	Amber_RedTrunk_B = { 160, 84, 46 }, Amber_Cliff_Pine = PINE2, Amber_Shrub_Sumac = { 176, 48, 40 }, Amber_Leaf_Litter_A = { 170, 96, 48 }, Amber_Leaf_Litter_B = { 190, 128, 56 } }
-- Subs a character or a projectile meets (placeholder collision); plants, rock and glow never collide in the placeholder (as the scatter pieces above).
local HARD: { [string]: boolean } = { Stone = true, Timber = true, Piers = true, Arches = true, Deck = true, Steps = true, Walls = true, Wall = true, Coping = true, Hull = true, Bund = true,
	Base = true, Body = true, Crust = true, Footing = true }
local UPRIGHT: { [string]: boolean } = { Tree = true, Conifer = true, Snag = true }

for _, group in { { AMBERFALL_KIT, LOOKS_AMBER }, { SALTREACH_KIT, LOOKS_SALT }, { FROSTMERE_KIT, LOOKS_FROST }, { ASHEN_KIT, LOOKS_ASH } } do
	for _, row in group[1] do
		local name, fam, arch, X, Y, Z = row[1], row[2], row[3], row[4], row[5], row[6]
		assert(P[name] == nil and Slice.Pieces[name] == nil, "BiomeDressing kit: duplicate piece " .. name)
		local subs = {}
		for subName, tris in string.gmatch(row[7], "(%S+):(%d+)") do
			local root = string.match(subName, "^[^_]+") :: string
			local look = group[2][root]
			assert(look, "BiomeDressing kit: no look for " .. subName)
			local color = if root == "Leaves" and LEAF_TINT[name] then LEAF_TINT[name] else look[2]
			local hard = (fam == "b" or fam == "h") and HARD[root] == true
			table.insert(subs, s(subName, look[1], color, tonumber(tris) :: number, hard, string.find(subName, "_Detail$") ~= nil, if root == "Bark" and UPRIGHT[arch] then "Cylinder" else nil))
		end
		local sink = if fam == "h" then 3 elseif fam == "r" then math.clamp(0.1 * Y, 0.3, 2.5) elseif fam == "b" then (if Y < 12 then 0.3 else 0.8) elseif UPRIGHT[arch] then 0.8 else 0.2
		P[name] = kit({ X, Y, Z }, sink, fam == "b" or fam == "h", subs, if arch == "Tree" or arch == "Conifer" then 0.07 * math.max(X, Z) elseif arch == "Snag" then 0.15 * math.max(X, Z) else nil)
		P[name].Key, P[name].Fam, P[name].ArchHint = name, fam, arch
		if arch == "Tuft" then P[name].DoubleSided = true end
	end
end

-- Hero slots: the biome's landmark slot name (hero placements, tests) resolves to the uploaded hero's spec, so its registry keys are the hero's.
BiomeDressing.Slots = { Ravine_Aqueduct_Arch = "Amber_Aqueduct_Hero", Basin_Gate_Statue = "Saltreach_Gate_Statue", Snow_Watch_Beacon = "Frost_Beacon_Hero",
	Summit_Temple_Pagoda = "Ash_Summit_Pagoda", Summit_Temple_Wing = "Ash_Summit_Wing" } :: { [string]: string }
for slot, hero in BiomeDressing.Slots do
	assert(P[hero] and P[slot] == nil, "BiomeDressing.Slots: " .. slot .. " / " .. hero)
	P[slot] = P[hero]
end
BiomeDressing.Pieces = P

-- Radius (footprint half-diagonal; crown radius for trees) and part / triangle counts, derived once (as SliceDressing).
-- A name the uploaded slice manifests also hold (the hero kit: aqueduct, beacon, gate statue, pagoda) takes the slice definition: the
-- manifest's real sizes and sub-mesh names are the truth, and the same registry keys resolve it for both modules.
BiomeDressing.Shared = {} :: { [string]: boolean }
for name in P do
	local sp = Slice.Pieces[name]
	if sp and not BiomeDressing.Slots[name] then
		P[name] = { Size = sp.Size, Sink = sp.Sink, Structure = sp.Structure, Trunk = sp.Trunk, Subs = sp.Subs }
		BiomeDressing.Shared[name] = true
	end
end
for name, p in P do
	local sz = p.Size
	if p.Radius then continue end -- a hero slot shares its hero's table
	p.Radius = if p.Trunk then 0.5 * math.max(sz[1], sz[3]) else 0.5 * math.sqrt(sz[1] ^ 2 + sz[3] ^ 2)
	p.Trunk = p.Trunk or p.Radius
	local n, tris, near = 0, 0, 0
	for _, sb in p.Subs do
		n += if sb.Shape == "Steps" then sb.Steps else #sb.B
		tris += sb.Tris
		near += if sb.Lod then 0 else sb.Tris
	end
	p.PlaceholderParts, p.Tris, p.TrisLod, p.MeshParts = n, tris, near, #p.Subs
end

-------------------------------------------------------------------------------------------------
-- Paths. An edge key "A>B" is its road (Overworld.terrainData().Roads) or, where the edge has none (cave and scramble
-- nodes, shortcuts), the straight line between its nodes.
-------------------------------------------------------------------------------------------------

local paths: { [string]: any } = {}

local function pathOf(key: string): any
	local cached = paths[key]
	if cached then
		return cached
	end
	local pts: any = nil
	for _, r in Overworld.terrainData().Roads do
		if r.A .. ">" .. r.B == key then
			pts = r.Points
		end
	end
	if not pts then
		local a, b = key:match("^(.-)>(.+)$")
		local na, nb = Overworld.Nodes[a], Overworld.Nodes[b]
		assert(na and nb, "BiomeDressing: no edge " .. key)
		pts = { { na.Position.X, na.Position.Z, na.Position.Y }, { nb.Position.X, nb.Position.Z, nb.Position.Y } }
	end
	local arc = { 0 }
	for k = 2, #pts do
		arc[k] = arc[k - 1] + math.sqrt((pts[k][1] - pts[k - 1][1]) ^ 2 + (pts[k][2] - pts[k - 1][2]) ^ 2)
	end
	local path = { Points = pts, Arc = arc, Length = arc[#pts] }
	paths[key] = path
	return path
end
BiomeDressing.pathOf = pathOf

-- World x, z and unit tangent at arc length d along a path.
local function pointAt(path: any, d: number): (number, number, number, number)
	local pts, arc = path.Points, path.Arc
	d = math.clamp(d, 0, path.Length)
	local k = 2
	while k < #pts and arc[k] < d do
		k += 1
	end
	local p, q = pts[k - 1], pts[k]
	local t = (d - arc[k - 1]) / math.max(arc[k] - arc[k - 1], 1e-6)
	local dx, dz = q[1] - p[1], q[2] - p[2]
	local l = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
	return p[1] + dx * t, p[2] + dz * t, dx / l, dz / l
end

-------------------------------------------------------------------------------------------------
-- Hero specs. at() = absolute; edge() = on a path at Frac (0..1) or Arc studs, Off sideways (+ = right going A to B);
-- series() = every Step studs (Off alternates through a list), Clip drops what falls outside the region box.
-- Flags: Landmark (far silhouette, Persistent), Road (stands on the carriageway on purpose), Shelf / Cliff (stands on the
-- chasm shelf / a cliff face: slope and chasm checks waived), Foot = { lx, lz } ground sample, LiftEnd, Shelter.
-------------------------------------------------------------------------------------------------

local function with(t: any, extra: any?): any
	local out = {}
	for k, v in t do out[k] = v end
	for k, v in extra or {} do out[k] = v end
	return out
end
local function at(id: string, piece: string, x: number, z: number, yaw: number, extra: any?): any
	return with({ Id = id, Piece = piece, X = x, Z = z, Yaw = yaw, Scale = 1 }, extra)
end
local function edge(id: string, piece: string, key: string, frac: number, off: number, extra: any?): any
	return with({ Id = id, Piece = piece, Edge = key, Frac = frac, Off = off, Scale = 1 }, extra)
end
local function series(id: string, piece: string, key: string, step: number, off: any, extra: any?): any
	return with({ Id = id, Piece = piece, Edge = key, Step = step, Off = off, Series = true, Clip = true, Ground = true, AvoidRoad = 10, Scale = 1 }, extra)
end

local function portal(id: string): any
	for _, p in Overworld.Blockout.Portals do
		if p.Id == id then return p end
	end
	error("BiomeDressing: no portal " .. id)
end

-- Stairs down a ramp (the blockout's stand-in slab): one flight per `rise` studs of drop, along A to B.
local function rampStairs(ramp: any, piece: string, rise: number): { any }
	local out = {}
	local n = math.max(1, math.ceil(math.abs(ramp.A.Y - ramp.B.Y) / rise))
	local dx, dz = ramp.B.X - ramp.A.X, ramp.B.Z - ramp.A.Z
	local yaw = math.deg(math.atan2(dx, dz))
	for k = 1, n do
		local t = (k - 0.5) / n
		table.insert(out, at(ramp.Id .. "_Stair_" .. k, piece, ramp.A.X + dx * t, ramp.A.Z + dz * t, yaw, { Cliff = true }))
	end
	return out
end

local function bridgeEnds(bridge: any, piece: string, gap: number, extra: any?): { any }
	local out = {}
	local dx, dz = bridge.B.X - bridge.A.X, bridge.B.Z - bridge.A.Z
	local l = math.sqrt(dx * dx + dz * dz)
	local tx, tz = dx / l, dz / l
	local yaw = math.deg(math.atan2(tx, tz))
	for ei, end_ in { bridge.A, bridge.B } do
		for si, side in { 1, -1 } do
			local off = side * (bridge.Width / 2 + gap)
			table.insert(out, at(string.format("%s_End%d_%s", bridge.Id, ei, if si == 1 then "R" else "L"), piece, end_.X - tz * off, end_.Z + tx * off, yaw, extra))
		end
	end
	return out
end

local function liftEnds(lift: any, piece: string, pylon: string, pylons: number): { any }
	local out = {}
	local dx, dz = lift.B.X - lift.A.X, lift.B.Z - lift.A.Z
	local l = math.sqrt(dx * dx + dz * dz)
	local yawAB = math.deg(math.atan2(dx, dz))
	table.insert(out, at(lift.Id .. "_StationA", piece, lift.A.X, lift.A.Z, yawAB, { LiftEnd = lift.Id }))
	table.insert(out, at(lift.Id .. "_StationB", piece, lift.B.X, lift.B.Z, yawAB + 180, { LiftEnd = lift.Id }))
	for k = 1, pylons do -- pylons up the line (both ends, inward), on the ground only
		local d = 40 + 38 * (k - 1)
		local side = { Ground = true, AvoidRoad = 12 }
		table.insert(out, at(lift.Id .. "_PylonA" .. k, pylon, lift.A.X + dx / l * d - dz / l * 20, lift.A.Z + dz / l * d + dx / l * 20, yawAB, side))
		table.insert(out, at(lift.Id .. "_PylonB" .. k, pylon, lift.B.X - dx / l * d - dz / l * 20, lift.B.Z - dz / l * d + dx / l * 20, yawAB, side))
	end
	return out
end

local function shelters(region: string, map: { [string]: string }): { any }
	local out = {}
	for _, sh in Overworld.Blockout.Shelters do
		if sh.Region == region and map[sh.Id] then
			table.insert(out, at("Shelter_" .. sh.Id, map[sh.Id], sh.X, sh.Z, sh.Yaw, { Shelter = sh.Id }))
		end
	end
	return out
end

local function ring(prefix: string, piece: string, cx: number, cz: number, r: number, n: number, extra: any?): { any }
	local out = {}
	for k = 1, n do
		local a = (k - 1) / n * math.pi * 2
		table.insert(out, at(string.format("%s_%02d", prefix, k), piece, cx + math.cos(a) * r, cz + math.sin(a) * r, math.deg(a) + 90, with({ Ground = true, AvoidRoad = 12 }, extra)))
	end
	return out
end

local function extend(list: { any }, more: { any })
	for _, m in more do table.insert(list, m) end
end

local function nodeXZ(id: string): (number, number)
	local p = Overworld.Nodes[id].Position
	return p.X, p.Z
end

-------------------------------------------------------------------------------------------------
-- Interiors. Mode "Carved": a passage cut into rock (floor Profile = { { t, floorY | "G" ground at that end } }, Width, Height,
-- Roof thickness; the builder carves terrain Air and raises the roof slabs, so the roof must lie under the ground).
-- Mode "Built": a roofed structure on the ground (the gallery). Open stretches (roof not buried: the entrance cutting) get no
-- roof; every buried stretch gets Cave_Roof_Slab spans tagged AsuraShelter.
-------------------------------------------------------------------------------------------------

BiomeDressing.Interiors = {
	GoldenRavine = {
		-- G1: the Gully Cave links the Bellwood to Amberfall; this passage (owned here) spans both mouths. The Forest-side mouth
		-- arch belongs to the Bellwood's dressing (ForestMouth), floor 250 is the G1 node's level under the surface mouth.
		{ Id = "AmberCave", Kind = "Tunnel", Mode = "Carved", Poi = "AmberCave", Portal = "AmberCaveMouth", ThroughPortal = "GullyCaveMouth", Through = "Forest",
			Profile = { { 0, "G" }, { 0.3, 250 }, { 0.6, 250 }, { 1, "G" } }, Width = 16, Height = 14, Roof = 3, Lights = true },
		-- Under-crossing grotto (hidden POI): a chamber in the east chasm wall, 100 above the chasm floor, reached by cliff stairs.
		{ Id = "UnderCrossingGrotto", Kind = "Grotto", Mode = "Carved", Poi = "UnderCrossingGrotto", A = { X = -5871, Z = -3000 }, B = { X = -5801, Z = -3000 },
			Profile = { { 0, -60 }, { 1, -60 } }, Width = 26, Height = 14, Roof = 3, Fixed = true, Lights = true },
	},
	AridBasin = {
		-- B2: the cistern hall under the rise south of the altar; the altar pad is the open cutting in front of it.
		{ Id = "CisternCavern", Kind = "Hall", Mode = "Carved", Poi = "CisternCavern", Portal = "CisternCaveMouth", B = { X = -8068, Z = -2110 },
			Profile = { { 0, "G" }, { 0.27, 26 }, { 1, 26 } }, Width = 40, Height = 16, Roof = 3, Lights = true },
	},
	Snowfields = {},
	MountainAscent = {
		-- M2 cliff gallery: a roofed walkway along the cliff face (the CliffGallery shelter), columns and a roof span on the ground.
		{ Id = "CliffGallery", Kind = "Gallery", Mode = "Built", Poi = "CliffGalleries", Shelter = "CliffGallery", Width = 14, Height = 11, Roof = 4, Lights = false },
	},
}

-------------------------------------------------------------------------------------------------
-- Biome definitions
-------------------------------------------------------------------------------------------------

local function ravineHeroes(): { any }
	local H: { any } = {
		at("Aqueduct", "Ravine_Aqueduct_Arch", -6650, -3290, 90, { Landmark = true, Road = true }),
		at("Mausoleum", "Ravine_Mausoleum", -6450, -3250, 180),
		at("OverlookPavilion", "Ravine_Overlook_Pavilion", -5610, -3235, 270),
		at("GrottoLanding", "Ravine_Grotto_Landing", -5879, -3000, 90, { Interior = true, Y = -60 }),
	}
	-- Rim parapets either side of the crossing's deck head (deck z -3150, 18 wide)
	for k = 0, 14 do
		local z = -3258 + k * 14.4
		if math.abs(z + 3150) > 17 then
			table.insert(H, at(string.format("Parapet_%02d", k + 1), "Ravine_Overlook_Parapet", -5688, z, 90, { AvoidRoad = 16 }))
		end
	end
	for _, b in Overworld.Blockout.Bridges do
		if b.Region == "GoldenRavine" then
			extend(H, bridgeEnds(b, if b.Kind == "stone" then "Ravine_Span_Pylon" else "Ravine_Rope_Post", if b.Kind == "stone" then 4.5 else 1.4, if b.Kind == "stone" then nil else { Shelf = true }))
		end
	end
	for _, r in Overworld.Blockout.Ramps do
		if r.Region == "GoldenRavine" then extend(H, rampStairs(r, "Ravine_Cliff_Stair", 20)) end
	end
	for _, l in Overworld.Blockout.Lifts do
		if l.Region == "GoldenRavine" then extend(H, liftEnds(l, "Ravine_Lift_Station", "Ravine_Lift_Pylon", 2)) end
	end
	local mouth = portal("AmberCaveMouth")
	table.insert(H, at("AmberCaveMouthArch", "Cave_Mouth_Arch", mouth.X, mouth.Z, 0, { CaveMouth = "AmberCave" }))
	-- Bell posts (the TempleBells ambience) along the approach to the overlook and the road to the crossing; cairns on the far rim
	extend(H, { series("BellPost_Approach", "Ravine_Bell_Post", "G1_AmberCave>Altar_RavineOverlook", 95, { 11, -11 }, { Start = 70, End = 60 }) })
	extend(H, { series("BellPost_Road", "Ravine_Bell_Post", "Altar_RavineOverlook>G3_Crossing", 55, { 12, -12 }, { Start = 40, Until = 0.3 }) })
	extend(H, { series("Cairn_Rim", "Ravine_Cairn", "G4_FarSide>G4_NorthRim", 110, { 11, -11 }, { Start = 40 }) })
	extend(H, { series("Cairn_Shelf", "Ravine_Cairn", "Altar_RavineOverlook>G4_FarSide", 120, { 11, -11 }, { Start = 60 }) })
	return H
end

local function basinHeroes(): { any }
	local H: { any } = {
		at("GateStatue", "Basin_Gate_Statue", -9500, -2880, 180, { Landmark = true }),
		at("StatueHand", "Basin_Statue_Hand", -9440, -2800, 40),
		at("StatueHead", "Basin_Statue_Head", -9570, -2790, 300),
		at("CisternMouthArch", "Cave_Mouth_Arch", portal("CisternCaveMouth").X, portal("CisternCaveMouth").Z, 0, { CaveMouth = "CisternCavern" }),
		at("KilnStack_1", "Basin_Kiln_Stack", -8470, -3345, 0),
		at("KilnStack_2", "Basin_Kiln_Stack", -8535, -3350, 0),
		at("ClayHeap_1", "Basin_Clay_Heap", -8470, -3270, 20),
		at("ClayHeap_2", "Basin_Clay_Heap", -8540, -3265, 100),
		at("CanyonGate_N", "Basin_Canyon_Gate", -8950, -3920, 90, { Road = true }),
		at("DuneObelisk", "Basin_Obelisk", -9470, -1370, 0),
		at("CaravanWreck", "Basin_Caravan_Wreck", -9535, -1425, 35),
	}
	extend(H, shelters("AridBasin", { CisternPavilion = "Basin_Cistern_Pavilion", KilnShed = "Basin_Kiln_Shed" }))
	extend(H, ring("DuneRuin", "Basin_Ruin_Wall", -9500, -1400, 46, 7, { Clip = true }))
	-- Cistern stair: the shortcut from the altar up to the caravan road (CisternStair POI), flights climbing the rise
	for k = 1, 4 do
		local t = (k - 0.5) / 4
		local ax, az = nodeXZ("Altar_BasinCistern")
		local bx, bz = nodeXZ("B1_CaravanDescent")
		local dx, dz = bx - ax, bz - az
		local l = math.sqrt(dx * dx + dz * dz)
		local d0 = 60 -- clear of the altar pad
		table.insert(H, at("CisternStair_" .. k, "Basin_Cistern_Stair", ax + dx / l * (d0 + t * 70), az + dz / l * (d0 + t * 70), math.deg(math.atan2(dx, dz)), { Cliff = true }))
	end
	extend(H, { series("CaravanPost_Descent", "Basin_Caravan_Post", "G4_FarSide>B1_CaravanDescent", 120, { 11, -11 }, { Start = 60 }) })
	extend(H, { series("CaravanPost_Cistern", "Basin_Caravan_Post", "B1_CaravanDescent>Altar_BasinCistern", 110, { 11, -11 }, { Start = 55 }) })
	extend(H, { series("CaravanPost_Kiln", "Basin_Caravan_Post", "Altar_BasinCistern>B3_KilnWorks", 120, { 11, -11 }, { Start = 80 }) })
	extend(H, { series("CaravanPost_Pass", "Basin_Caravan_Post", "B3_KilnWorks>M1_PassFoot", 130, { 11, -11 }, { Start = 80 }) })
	extend(H, { series("CanyonPost", "Basin_Caravan_Post", "Altar_BasinCistern>B5_Canyon", 160, { 11, -11 }, { Start = 80 }) })
	extend(H, { series("PanPost", "Basin_Caravan_Post", "B3_KilnWorks>B4_SaltPan", 130, { 11, -11 }, { Start = 80, End = 120 }) })
	extend(H, { series("SaltCairn_Road", "Salt_Cairn", "B3_KilnWorks>B4_SaltPan", 90, { 15, -15 }, { Start = 700, End = 40 }) })
	return H
end

local function snowHeroes(): { any }
	local H: { any } = {
		at("WatchBeacon", "Snow_Watch_Beacon", -3460, -7300, 0, { Landmark = true }),
		at("PassGate", "Snow_Pass_Gate", -5500, -6800, 90, { Road = true, Clip = true }),
	}
	extend(H, shelters("Snowfields", { SnowRefuge = "Snow_Refuge_Hut" }))
	-- Watchpost ruins round the FrostWatchpost cache
	local c = Overworld.Caches.FrostWatchpost.Position
	extend(H, ring("WatchRuin", "Snow_Ruin_Wall", c.X, c.Z, 38, 7))
	extend(H, ring("WatchPillar", "Snow_Ruin_Pillar", c.X, c.Z, 26, 4))
	extend(H, ring("RefugeWindbreak", "Snow_Windbreak", -3400, -6400, 52, 5))
	extend(H, ring("PassCairn", "Snow_Pass_Cairn", -5500, -6800, 34, 5, { Clip = true }))
	-- The trail: stakes every 50 studs on the main route, every 70 on the alternate ridge and optional legs, visible in a squall.
	local mains = { "S1_HeadwaterGorge>Altar_SnowRefuge", "Altar_SnowRefuge>S5_WhitePass", "S5_WhitePass>M1_WhitePassFoot", "Altar_BambooShrine>S1_HeadwaterGorge" }
	for i, key in mains do
		extend(H, { series("Trail_M" .. i, "Snow_Trail_Stake", key, 50, { 11, -11 }, { Start = 25 }) })
	end
	local others = { "S1_HeadwaterGorge>S3_Watchpost", "S3_Watchpost>S5_WhitePass", "Altar_SnowRefuge>S3_Watchpost", "Altar_SnowRefuge>S4_LakeMargin" }
	for i, key in others do
		extend(H, { series("Trail_A" .. i, "Snow_Trail_Stake", key, 70, { 10, -10 }, { Start = 35 }) })
	end
	-- Lake ice path (shortcut S4 > S1, cosmetic ice, normal traction): glacier markers over the frozen margins
	extend(H, { series("IceMarker", "Snow_Ice_Marker", "S4_LakeMargin>S1_HeadwaterGorge", 130, { 6, -6 }, { Start = 70 }) })
	-- Exposed ridge windbreaks (the alternate's only cover)
	for k, fr in { 0.33, 0.66 } do
		table.insert(H, edge("RidgeWindbreak_A" .. k, "Snow_Windbreak", "S1_HeadwaterGorge>S3_Watchpost", fr, 12))
		table.insert(H, edge("RidgeWindbreak_B" .. k, "Snow_Windbreak", "S3_Watchpost>S5_WhitePass", fr, 12))
	end
	return H
end

local function mountainHeroes(): { any }
	local H: { any } = {
		at("SummitPagoda", "Summit_Temple_Pagoda", -7320, -8030, 0, { Landmark = true }),
		at("SummitWing", "Summit_Temple_Wing", -7100, -8000, 0),
		at("ThousandStepsGate", "Mtn_Thousand_Steps_Gate", -7400, -7300, 0, { Landmark = true, Road = true }),
		at("PassGate", "Mtn_Pass_Gate", -8300, -4700, 90, { Road = true }),
		at("ViewpointCairn", "Mtn_Viewpoint_Cairn", -6800, -6600, 0),
	}
	extend(H, shelters("MountainAscent", { MountainRefuge = "Mtn_Refuge_Hall" }))
	extend(H, ring("RefugeWindbreak", "Mtn_Windbreak", -7750, -6500, 52, 5))
	for _, r in Overworld.Blockout.Ramps do
		if r.Region == "MountainAscent" then extend(H, rampStairs(r, "Mtn_Stair_Run", 10)) end
	end
	for _, l in Overworld.Blockout.Lifts do
		if l.Region == "MountainAscent" then extend(H, liftEnds(l, "Mtn_Lift_Station", "Mtn_Lift_Pylon", 5)) end
	end
	-- Thousand Steps and the summit approach: a stair flight and a retaining wall every 60 studs through the switchbacks
	for i, key in { "Altar_MountainRefuge>M4_ThousandSteps", "M4_ThousandSteps>Altar_ColosseumAntechamber" } do
		extend(H, { series("Switchback_Stair" .. i, "Mtn_Stair_Run", key, 60, 0, { Start = 40, End = 50, Road = true }) })
		extend(H, { series("Switchback_Wall" .. i, "Mtn_Retaining_Wall", key, 60, { 13, -13 }, { Start = 70, End = 50 }) })
		extend(H, { series("WindCairn" .. i, "Mtn_Wind_Cairn", key, 90, { 11, -11 }, { Start = 55 }) })
	end
	return H
end

BiomeDressing.Defs = {
	GoldenRavine = {
		Corridor = { Half = 110, Fade = 60, Discs = { { Node = "Altar_RavineOverlook", R = 150 }, { Node = "G4_FarSide", R = 130 } } },
		-- Tall plants keep clear of the sight lines from the crossing's far half to the aqueduct.
		Lane = { Hero = "Aqueduct", Edge = "G3_Crossing>G4_FarSide", Reach = 600, HalfWidth = 14 },
		Scatter = {
			Rock = { Salt = 5, Spacing = 40, Base = 0.6, MaxSlope = 1.6, MinSlope = 0.1, Tall = true, Scale = { 0.8, 1.3 },
				Pieces = { { "Amber_Boulder_A", 0.12 }, { "Amber_Boulder_B", 0.12 }, { "Amber_Boulder_C", 0.08 }, { "Amber_Scree_A", 0.1 }, { "Amber_Scree_B", 0.1 }, { "Amber_Ledge_Long", 0.1 },
						{ "Amber_Ledge_Overhang", 0.1 }, { "Amber_Cliff_Wall_A", 0.08 }, { "Amber_Cliff_Wall_B", 0.08 }, { "Amber_Cliff_Corner", 0.06 }, { "Amber_Spire", 0.06 } },
				Material = { Sandstone = 1, Sand = 0.5, Grass = 0.3, Ground = 0.4, Limestone = 0.4 } },
			Tree = { Salt = 1, Spacing = 46, Base = 0.55, MaxSlope = 0.5, Tall = true, Scale = { 0.85, 1.2 },
				Pieces = { { "Amber_RedTrunk_A", 0.22 }, { "Amber_RedTrunk_B", 0.16 }, { "Amber_Maple_Red", 0.18 }, { "Amber_Maple_Gold", 0.12 }, { "Amber_Cliff_Pine", 0.12 },
						{ "Amber_Maple_Sapling", 0.12 }, { "Amber_Dead_Snag", 0.08 } }, Material = { Grass = 1, Sand = 0.35, Ground = 0.3, Sandstone = 0.08 } },
			Shrub = { Salt = 2, Spacing = 22, Base = 0.4, MaxSlope = 0.7, Scale = { 0.8, 1.4 },
				Pieces = { { "Amber_Shrub_Dry", 0.3 }, { "Amber_Shrub_Sumac", 0.25 }, { "Amber_Stump", 0.15 }, { "Amber_Fallen_Log", 0.15 }, { "Amber_Root_Tangle", 0.15 } }, Material = { Grass = 1, Sand = 0.6, Sandstone = 0.15, Ground = 0.4 } },
			Fern = { Salt = 3, Spacing = 18, Base = 0.3, MaxSlope = 0.8, Scale = { 0.8, 1.5 },
				Pieces = { { "Amber_Fern_Bronze", 0.5 }, { "Amber_Leaf_Litter_A", 0.25 }, { "Amber_Leaf_Litter_B", 0.25 } }, Material = { Grass = 0.8, Sand = 0.5, Ground = 0.2 } },
			Grass = { Salt = 4, Spacing = 11, Base = 0.45, MaxSlope = 0.6, Scale = { 0.9, 1.7 },
				Pieces = { { "Amber_Grass_Pale", 0.5 }, { "Amber_Grass_Dry", 0.3 }, { "Amber_Grass_Seed", 0.2 } }, Material = { Grass = 1, Sand = 0.45, Ground = 0.2, Sandstone = 0.05 } },
		},
		Hero = ravineHeroes,
	},
	AridBasin = {
		Corridor = { Half = 80, Fade = 50, Density = 0.45, Discs = { { Node = "Altar_BasinCistern", R = 150 }, { Node = "B3_KilnWorks", R = 120 }, { Node = "B6_DuneRuin", R = 110 }, { Node = "B4_SaltPan", R = 140 } } },
		Lane = { Hero = "GateStatue", Edge = "B3_KilnWorks>B4_SaltPan", Reach = 700, HalfWidth = 16 },
		Scatter = {
			Rock = { Salt = 5, Spacing = 36, Base = 0.7, MaxSlope = 1.6, MinSlope = 0.1, Tall = true, Scale = { 0.8, 1.3 },
				Pieces = { { "Tide_Boulder_A", 0.2 }, { "Tide_Boulder_B", 0.2 }, { "Tide_Boulder_C", 0.12 }, { "Salt_Crust_Slab_A", 0.04 }, { "Salt_Crust_Slab_B", 0.04 }, { "Sea_Stack_Base", 0.06 },
					{ "Sea_Stack_Mid", 0.06 }, { "Sea_Stack_Cap", 0.06 }, { "Shore_Cliff_A", 0.06 }, { "Shore_Cliff_B", 0.06 }, { "Shore_Cliff_Corner", 0.1 } },
				ByMaterial = { Salt = { { "Salt_Crust_Slab_A", 0.3 }, { "Salt_Crust_Slab_B", 0.3 }, { "Salt_Crystal_Cluster", 0.25 }, { "Salt_Cairn", 0.15 } } },
				Material = { Sandstone = 1, Limestone = 0.6, Sand = 0.35, Salt = 1.6, Ground = 0.4 } },
			Tree = { Salt = 1, Spacing = 70, Base = 0.5, MaxSlope = 0.45, Tall = true, Scale = { 0.85, 1.2 },
				Pieces = { { "Salt_Pine_A", 0.35 }, { "Salt_Pine_B", 0.35 }, { "Salt_Pine_Dead", 0.3 } }, Material = { Sand = 0.5, Limestone = 0.4, Sandstone = 0.1, Ground = 0.3 } },
			Shrub = { Salt = 2, Spacing = 22, Base = 0.45, MaxSlope = 0.7, Scale = { 0.8, 1.4 },
				Pieces = { { "Dune_Scrub_A", 0.3 }, { "Dune_Scrub_B", 0.3 }, { "Driftwood_Log", 0.2 }, { "Driftwood_Pile", 0.2 } }, Material = { Sand = 1, Limestone = 0.7, Sandstone = 0.2, Ground = 0.4 } },
			Fern = { Salt = 3, Spacing = 26, Base = 0.3, MaxSlope = 0.7, Scale = { 0.8, 1.4 },
				Pieces = { { "Shore_Reeds", 0.5 }, { "Kelp_Wrack", 0.5 } }, Material = { Sand = 0.7, Limestone = 0.6, Sandstone = 0.2 } },
			Grass = { Salt = 4, Spacing = 12, Base = 0.35, MaxSlope = 0.6, Scale = { 0.9, 1.6 },
				Pieces = { { "Salt_Grass_Tuft", 0.55 }, { "Salt_Grass_Tall", 0.45 } }, Material = { Sand = 1, Limestone = 0.5, Ground = 0.2 } },
		},
		Hero = basinHeroes,
	},
	Snowfields = {
		Corridor = { Half = 70, Fade = 45, Density = 0.3, Discs = { { Node = "Altar_SnowRefuge", R = 150 }, { Node = "S3_Watchpost", R = 130 } } },
		Lane = { Hero = "WatchBeacon", Edge = "S1_HeadwaterGorge>S3_Watchpost", Reach = 700, HalfWidth = 14 },
		Scatter = {
			Rock = { Salt = 5, Spacing = 34, Base = 0.7, MaxSlope = 1.6, MinSlope = 0.1, Tall = true, Scale = { 0.8, 1.3 },
				Pieces = { { "Frost_Boulder_A", 0.12 }, { "Frost_Boulder_B", 0.12 }, { "Frost_Boulder_C", 0.08 }, { "Frost_Ice_Shards_A", 0.1 }, { "Frost_Ice_Shards_B", 0.1 }, { "Frost_Scree_A", 0.12 },
					{ "Frost_Scree_B", 0.1 }, { "Frost_Cliff_Wall_A", 0.1 }, { "Frost_Cliff_Wall_B", 0.08 }, { "Frost_Cliff_Corner", 0.08 } },
				Material = { Rock = 1, Snow = 0.35, Slate = 0.5, Ground = 0.2 } },
			Tree = { Salt = 1, Spacing = 38, Base = 0.8, MaxSlope = 0.6, Tall = true, Scale = { 0.85, 1.2 }, Alt = { 300, 720, 120 },
				Pieces = { { "Frost_Fir_A", 0.24 }, { "Frost_Fir_B", 0.2 }, { "Frost_Fir_Broad", 0.16 }, { "Frost_Fir_Sapling", 0.12 }, { "Frost_Birch_A", 0.1 }, { "Frost_Birch_B", 0.08 }, { "Frost_Dead_Snag", 0.1 } }, Material = { Snow = 0.5, Ground = 1, Slate = 0.3, Rock = 0.05 } },
			Shrub = { Salt = 2, Spacing = 20, Base = 0.4, MaxSlope = 0.7, Scale = { 0.8, 1.4 }, Alt = { 300, 780, 120 },
				Pieces = { { "Frost_Shrub_Frozen", 0.4 }, { "Frost_Shrub_Small", 0.4 }, { "Frost_Fallen_Log", 0.2 } }, Material = { Snow = 0.45, Ground = 1, Slate = 0.2 } },
			Fern = { Salt = 3, Spacing = 19, Base = 0.4, MaxSlope = 0.8, Scale = { 0.8, 1.4 }, Alt = { 300, 800, 150 },
				Pieces = { { "Frost_Grass_Tuft_B", 1 } }, Material = { Snow = 0.6, Ground = 0.9, Slate = 0.2 } },
			Grass = { Salt = 4, Spacing = 15, Base = 0.4, MaxSlope = 0.6, Scale = { 0.9, 1.6 }, Alt = { 300, 760, 120 },
				Pieces = { { "Frost_Grass_Tuft_A", 1 } }, Material = { Snow = 0.7, Ground = 1, Slate = 0.15 } },
		},
		Hero = snowHeroes,
	},
	MountainAscent = {
		Corridor = { Half = 80, Fade = 50, Density = 0.55, Discs = { { Node = "Altar_MountainRefuge", R = 140 }, { Node = "Altar_ColosseumAntechamber", R = 110 } } },
		-- The summit temple stays visible: tall plants keep off the lines from the switchbacks to the pagoda.
		Lane = { Hero = "SummitPagoda", Edge = "Altar_MountainRefuge>M4_ThousandSteps", Reach = 900, HalfWidth = 16 },
		Scatter = {
			Rock = { Salt = 5, Spacing = 36, Base = 0.5, MaxSlope = 1.8, MinSlope = 0.1, Tall = true, Scale = { 0.8, 1.3 },
				Pieces = { { "Ash_Boulder_A", 0.12 }, { "Ash_Boulder_B", 0.12 }, { "Ash_Boulder_C", 0.08 }, { "Ash_Scree_A", 0.1 }, { "Ash_Scree_B", 0.1 }, { "Ash_Ledge", 0.1 }, { "Ash_Crag", 0.1 },
					{ "Ash_Cliff_Switchback_A", 0.1 }, { "Ash_Cliff_Switchback_B", 0.08 }, { "Ash_Cliff_Corner", 0.1 } },
				Material = { Rock = 1, Basalt = 0.8, Slate = 0.6, Ground = 0.4, Snow = 0.2, LeafyGrass = 0.15, Grass = 0.15 } },
			Tree = { Salt = 1, Spacing = 34, Base = 0.9, MaxSlope = 0.6, Tall = true, Scale = { 0.85, 1.2 }, Alt = { 100, 560, 140 },
				Pieces = { { "Ash_Pine_A", 0.3 }, { "Ash_Pine_B", 0.25 }, { "Ash_Pine_C", 0.2 }, { "Ash_Snag_A", 0.13 }, { "Ash_Snag_B", 0.12 } }, Material = { LeafyGrass = 1, Grass = 0.8, Ground = 0.5, Slate = 0.15, Rock = 0.05 } },
			Shrub = { Salt = 2, Spacing = 18, Base = 0.45, MaxSlope = 0.8, Scale = { 0.8, 1.4 }, Alt = { 100, 800, 160 },
				Pieces = { { "Ash_Shrub", 0.35 }, { "Ash_Shrub_Small", 0.4 }, { "Ash_Snag_Fallen", 0.25 } }, Material = { LeafyGrass = 1, Grass = 0.7, Ground = 0.5, Slate = 0.25 } },
			Fern = { Salt = 3, Spacing = 16, Base = 0.35, MaxSlope = 0.8, Scale = { 0.8, 1.4 }, Alt = { 100, 520, 120 },
				Pieces = { { "Ash_Tussock_A", 0.5 }, { "Ash_Lichen_A", 0.25 }, { "Ash_Lichen_B", 0.25 } }, Material = { LeafyGrass = 1, Grass = 0.6, Ground = 0.4 } },
			Grass = { Salt = 4, Spacing = 11, Base = 0.4, MaxSlope = 0.7, Scale = { 0.9, 1.6 }, Alt = { 100, 700, 150 },
				Pieces = { { "Ash_Tussock_B", 1 } }, Material = { Grass = 1, LeafyGrass = 0.7, Ground = 0.4, Slate = 0.1 } },
		},
		Hero = mountainHeroes,
	},
}

-- Lifts: both ends must be built structures (hero stations tagged LiftEnd) and the map shows the link (a shortcut edge).
BiomeDressing.Lifts = {
	GoldenRavine = { { Id = "ChainLift", Edge = "G4_FarSide>Altar_RavineOverlook", Poi = "ChainLift" } },
	AridBasin = {},
	Snowfields = {},
	MountainAscent = { { Id = "TempleLift", Edge = "Altar_ColosseumAntechamber>Altar_MountainRefuge", Poi = "TempleLift" } },
}

-------------------------------------------------------------------------------------------------
-- Deterministic hash (copy of SliceDressing's: murmur fmix32 over integer cell coordinates)
-------------------------------------------------------------------------------------------------

local TWO32 = 4294967296

local function mul32(a: number, b: number): number
	return ((bit32.rshift(a, 16) * b % 65536) * 65536 + (a % 65536) * b) % TWO32
end

local function hash(a: number, b: number, salt: number): number
	local x = bit32.bxor((a * 73856093) % TWO32, (b * 19349663) % TWO32, (salt * 83492791) % TWO32)
	x = mul32(bit32.bxor(x, bit32.rshift(x, 16)), 0x85ebca6b)
	x = mul32(bit32.bxor(x, bit32.rshift(x, 13)), 0xc2b2ae35)
	return bit32.bxor(x, bit32.rshift(x, 16))
end

local function rand(a: number, b: number, salt: number): number
	return hash(a, b, salt) / TWO32
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function worldDist(x0: number, z0: number, x1: number, z1: number): number
	return math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
end
local segDist = Slice.segDist

local function inBox(bounds: any, x: number, z: number): boolean
	return math.abs(x - bounds.Center.X) <= bounds.Size.X * 0.5 and math.abs(z - bounds.Center.Z) <= bounds.Size.Z * 0.5
end
BiomeDressing.inBox = inBox

-- Altitude factor: 1 between Alt[1] and Alt[2], fading to 0 over Alt[3] studs beyond either.
function BiomeDressing.altFactor(alt: any, h: number): number
	if not alt then
		return 1
	end
	return smooth((h - (alt[1] - alt[3])) / alt[3]) * (1 - smooth((h - alt[2]) / alt[3]))
end

-------------------------------------------------------------------------------------------------
-- Exclusions (identical to the slice's, over this biome's pieces)
-------------------------------------------------------------------------------------------------

local function circles(heroes: { any }, extra: { any }): { any }
	local K: any = Slice.Keep
	local list: { any } = {}
	local function add(x: number, z: number, k: any)
		table.insert(list, { X = x, Z = z, Keep = k })
	end
	for _, a in Overworld.Altars do
		add(a.Placement.X, a.Placement.Z, K.Altar)
		add(a.Spawn.X, a.Spawn.Z, K.Arrival)
		add(a.Exit.X, a.Exit.Z, K.Arrival)
	end
	for _, r in Overworld.Rings do
		add(r.X, r.Z, K.Ring)
	end
	local rg = Overworld.Blockout.ReturnGate
	add(rg.X, rg.Z, K.ReturnGate)
	for _, sh in Overworld.Blockout.Shelters do
		local half = 0.5 * math.sqrt(sh.W ^ 2 + sh.D ^ 2)
		local k = {}
		for cls, pad in K.Shelter do
			k[cls] = half + pad
		end
		add(sh.X, sh.Z, k)
	end
	for _, group in { Overworld.Blockout.Bridges, Overworld.Blockout.Ramps, Overworld.Blockout.Lifts } do
		for _, b in group do
			add(b.A.X, b.A.Z, K.SpanEnd); add(b.B.X, b.B.Z, K.SpanEnd)
		end
	end
	for _, p in Overworld.Blockout.Portals do
		add(p.X, p.Z, K.SpanEnd)
	end
	local function home(x: number, z: number, mob: string)
		local leash = Slice.MobLeash[mob]
		assert(leash, "SliceDressing.MobLeash lacks " .. mob)
		local k = {}
		for cls, f in K.Leash do
			k[cls] = f * leash
		end
		add(x, z, k)
	end
	for _, sp in Overworld.EncounterSpots do
		home(sp.Placement.X, sp.Placement.Z, sp.Mob)
	end
	for _, m in Overworld.Minibosses do
		home(m.Placement.X, m.Placement.Z, m.Id)
	end
	home(Overworld.Training.Placement.X, Overworld.Training.Placement.Z, "SparringPhantom")
	for _, h in heroes do
		local radius = P[h.Piece].Radius * h.Scale
		local k = {}
		for cls, pad in K.Hero do
			k[cls] = radius + pad
		end
		add(h.X, h.Z, k)
	end
	for _, e in extra do
		add(e.X, e.Z, e.Keep)
	end
	return list
end

local function hostile(x: number, z: number, cls: string, list: { any }, roadSegs: { any }, lanes: { any }, tall: boolean, laneHalf: number): boolean
	local K: any = Slice.Keep
	for _, c in list do
		if worldDist(x, z, c.X, c.Z) < c.Keep[cls] then
			return true
		end
	end
	local road = K.Road[cls]
	for _, sg in roadSegs do
		if segDist(sg[1], sg[2], sg[3], sg[4], x, z) < road then
			return true
		end
	end
	if tall then
		for _, l in lanes do
			if segDist(l[1], l[2], l[3], l[4], x, z) < laneHalf then
				return true
			end
		end
	end
	return false
end

-- Footprint clearance for the uploaded kit's big rock and built masses (cliffs, spans, boat hulls): hostile() measures the centre, which is
-- enough for a boulder but lets a 45 stud cliff sit across a road or an altar pad. Applies from radius 14; trees keep their crown overhang.
local function massHostile(piece: any, radius: number, x: number, z: number, list: { any }, roadSegs: { any }): boolean
	if piece.Fam == nil or piece.Fam == "v" or radius <= 14 then
		return false
	end
	for _, c in list do
		if worldDist(x, z, c.X, c.Z) < c.Keep.Rock + 0.5 * radius then
			return true
		end
	end
	for _, sg in roadSegs do
		if segDist(sg[1], sg[2], sg[3], sg[4], x, z) < 0.6 * radius then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------------------------
-- Interiors
-------------------------------------------------------------------------------------------------

-- Sample a carved or built interior every 8 studs; returns the record and appends placements.
local function buildInterior(spec: any, region: string, placements: { any }, extraCircles: { any }): any
	local ax, az, bx, bz = 0, 0, 0, 0
	local mouthA: any = nil
	if spec.Portal then
		mouthA = portal(spec.Portal)
		ax, az = mouthA.X, mouthA.Z
	elseif spec.A then
		ax, az = spec.A.X, spec.A.Z
	elseif spec.Shelter then
		local shelter: any = nil
		for _, sh in Overworld.Blockout.Shelters do
			if sh.Id == spec.Shelter then shelter = sh end
		end
		local rad = math.rad(shelter.Yaw)
		ax, az = shelter.X - math.cos(rad) * shelter.W / 2, shelter.Z + math.sin(rad) * shelter.W / 2
		bx, bz = shelter.X + math.cos(rad) * shelter.W / 2, shelter.Z - math.sin(rad) * shelter.W / 2
	end
	if spec.ThroughPortal then
		local p = portal(spec.ThroughPortal)
		bx, bz = p.X, p.Z
	elseif spec.B then
		bx, bz = spec.B.X, spec.B.Z
	end
	local len = worldDist(ax, az, bx, bz)
	local tx, tz = (bx - ax) / len, (bz - az) / len
	local yaw = math.deg(math.atan2(tx, tz))
	local g0, g1 = Overworld.heightAt(ax, az), Overworld.heightAt(bx, bz)
	local built = spec.Mode == "Built"

	local function floorAt(t: number): number
		if not spec.Profile then
			return Overworld.heightAt(ax + (bx - ax) * t, az + (bz - az) * t)
		end
		local prof = spec.Profile
		local function val(e: any): number
			if e[2] == "G" then return if e[1] == 0 then g0 else g1 end
			return e[2]
		end
		for k = 2, #prof do
			if t <= prof[k][1] then
				local a, b = prof[k - 1], prof[k]
				return val(a) + (val(b) - val(a)) * (t - a[1]) / math.max(b[1] - a[1], 1e-6)
			end
		end
		return val(prof[#prof])
	end
	-- Lowest ground over the centre and both walls at distance d along the passage.
	local function groundAt(d: number): number
		local t = d / len
		local x, z = ax + (bx - ax) * t, az + (bz - az) * t
		local w = spec.Width / 2
		return math.min(Overworld.heightAt(x, z), Overworld.heightAt(x - tz * w, z + tx * w), Overworld.heightAt(x + tz * w, z - tx * w))
	end
	local function roofedAt(d: number): boolean
		if built then return true end
		local t = d / len
		return groundAt(d) - (floorAt(t) + spec.Height + spec.Roof) >= 2
	end

	local rec: any = { Id = spec.Id, Kind = spec.Kind, Mode = spec.Mode, Poi = spec.Poi, Region = region, Through = spec.Through, Length = len, Width = spec.Width, Height = spec.Height,
		RoofThickness = spec.Roof, Tag = "AsuraShelter", Yaw = yaw, A = { X = ax, Z = az }, B = { X = bx, Z = bz }, Fixed = spec.Fixed == true,
		MouthA = if spec.Portal then { X = ax, Z = az } else nil, ForestMouth = if spec.ThroughPortal then { X = bx, Z = bz } else nil, Roofs = {}, Open = {} }
	local slab, slabs = 24, 0
	local floorMin, topMax = math.huge, -math.huge
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	local d = 0
	local spanStart: number? = nil
	local function closeSpan(dEnd: number)
		if spanStart then
			local t0, t1 = spanStart / len, dEnd / len
			table.insert(rec.Roofs, { X0 = ax + (bx - ax) * t0, Z0 = az + (bz - az) * t0, X1 = ax + (bx - ax) * t1, Z1 = az + (bz - az) * t1, Y = floorAt((spanStart + dEnd) / 2 / len) + spec.Height,
				Length = dEnd - spanStart, Width = spec.Width + 2, Thickness = spec.Roof, Tag = "AsuraShelter" })
			spanStart = nil
		end
	end
	local openStart: number? = nil
	local roofLength, nRib, nBrazier = 0, 0, 0
	local function place(suffix: string, piece: string, x: number, z: number, y: number, yawDeg: number, scale: number, extra: any?)
		table.insert(placements, with({ Id = string.format("%s_%s", spec.Id, suffix), Piece = piece, Class = "Interior", Kind = "Interior", Cave = spec.Id, X = x, Z = z, GX = x, GZ = z, Y = y,
			Yaw = yawDeg + (BiomeDressing.ImportYaw[piece] or 0), Scale = scale, Sink = P[piece].Sink, Landmark = false, Cell = Slice.cellOf(x, z) }, extra))
	end
	while d < len do
		local dEnd = math.min(d + slab, len)
		local mid = (d + dEnd) / 2
		local t = mid / len
		local x, z = ax + (bx - ax) * t, az + (bz - az) * t
		local fl = floorAt(t)
		local okRoof = roofedAt(d) and roofedAt(mid) and roofedAt(dEnd)
		for _, dd in { d, dEnd } do
			local tt = dd / len
			local px, pz = ax + (bx - ax) * tt, az + (bz - az) * tt
			local w = spec.Width / 2 + 2
			for _, sx in { -w, w } do
				x0, x1 = math.min(x0, px - tz * sx), math.max(x1, px - tz * sx)
				z0, z1 = math.min(z0, pz + tx * sx), math.max(z1, pz + tx * sx)
			end
		end
		floorMin = math.min(floorMin, floorAt(d / len), floorAt(dEnd / len))
		topMax = math.max(topMax, floorAt(d / len) + spec.Height + spec.Roof, floorAt(dEnd / len) + spec.Height + spec.Roof)
		if okRoof then
			if openStart then
				table.insert(rec.Open, { From = openStart, To = d })
				openStart = nil
			end
			spanStart = spanStart or d
			roofLength += dEnd - d
			local across = math.ceil(spec.Width / 24)
			for c = 1, across do
				local off = (c - (across + 1) / 2) * 24
				slabs += 1
				place("Roof" .. slabs, "Cave_Roof_Slab", x - tz * off, z + tx * off, fl + spec.Height, yaw, 1, { Roof = true, Tag = "AsuraShelter" })
			end
			nRib += 1
			place("Rib" .. nRib, "Cave_Rib_Arch", x, z, fl, yaw, spec.Width / 16)
			if spec.Lights and nRib % 2 == 0 then
				nBrazier += 1
				place("Brazier" .. nBrazier, "Cave_Brazier", x - tz * (spec.Width / 2 - 2) * (if nBrazier % 2 == 0 then 1 else -1), z + tx * (spec.Width / 2 - 2) * (if nBrazier % 2 == 0 then 1 else -1), fl, yaw, 1)
			end
		else
			closeSpan(d)
			openStart = openStart or d
			-- the open cutting: keep scatter off it
			local r = spec.Width / 2 + 8
			for off = d, dEnd, 8 do
				local tt = off / len
				table.insert(extraCircles, { X = ax + (bx - ax) * tt, Z = az + (bz - az) * tt, Keep = { Tree = r + 6, Shrub = r, Fern = r, Grass = r, Rock = r + 4 } })
			end
		end
		-- stairs where the floor climbs more than 8 per cent over the slab
		local slope = (floorAt(math.min(dEnd / len, 1)) - floorAt(d / len)) / math.max(dEnd - d, 1)
		if math.abs(slope) > 0.08 then
			place("Stair" .. (d // slab + 1), "Cave_Stair_Run", x, z, fl, yaw + (if slope > 0 then 0 else 180), 1, { Climb = slope })
		end
		d += slab
	end
	closeSpan(len)
	if openStart then
		table.insert(rec.Open, { From = openStart, To = len })
	end
	-- merge roof slabs separated by one open slab edge? no: spans are the maximal roofed runs of whole slabs
	rec.RoofLength, rec.Slabs, rec.Ribs = roofLength, slabs, nRib
	rec.Extents = { X0 = x0, X1 = x1, Z0 = z0, Z1 = z1, Y0 = floorMin, Y1 = topMax }
	return rec
end

-------------------------------------------------------------------------------------------------
-- Builder
-------------------------------------------------------------------------------------------------

local builtCache: { [string]: any } = {}

local function expand(specs: { any }): { any }
	local out: { any } = {}
	for _, sp in specs do
		if sp.Series then
			local path = pathOf(sp.Edge)
			local last = path.Length * (sp.Until or 1) - (sp.End or 0)
			local k: number, d: number = 0, sp.Start or sp.Step * 0.5
			while d <= last do
				k += 1
				local off = if type(sp.Off) == "table" then sp.Off[(k - 1) % #sp.Off + 1] else (sp.Off or 0)
				table.insert(out, with(sp, { Series = false, Id = string.format("%s_%03d", sp.Id, k), Arc = d, Off = off }))
				d += sp.Step
			end
		else
			table.insert(out, sp)
		end
	end
	return out
end

-- Walkable edges of a region, as segments: the biome's corridor spine (lift lines are flown, not walked).
local FLOWN: { [string]: boolean } = { ["G4_FarSide>Altar_RavineOverlook"] = true, ["Altar_ColosseumAntechamber>Altar_MountainRefuge"] = true }
local function walks(region: string): { any }
	local out: { any } = {}
	for _, e in Overworld.Edges do
		local key = e.A .. ">" .. e.B
		local under = Overworld.TerrainDef.Underground
		if e.Region == region and not FLOWN[key] and not (under[e.A] and under[e.B]) then
			table.insert(out, pathOf(key))
		end
	end
	return out
end
BiomeDressing.walks = walks

-- Placements for one biome: { Placements, Heroes, Interiors, Counts, ByClass, Cells, MeshParts, PlaceholderParts, Tris, TrisLod, Bounds,
-- Lanes, RoadSegments, Dropped }. Pure and memoised (build(id, true) rebuilds); same seed and terrain, same list.
-- tick (optional) is called inside every long loop so a server can yield between slices (BiomeDressingService passes a pacer).
function BiomeDressing.build(id: string, fresh: boolean?, tick: (() -> ())?): any
	local pace: () -> () = tick or function() end
	if fresh then
		builtCache[id] = nil
	end
	if builtCache[id] then
		return builtCache[id]
	end
	local def: any = (BiomeDressing.Defs :: any)[id]
	assert(def, "BiomeDressing: unknown biome " .. tostring(id))
	local bounds = Overworld.Regions[id].Bounds
	local biomeIndex = table.find(BiomeDressing.Order, id) :: number
	local placements: { any } = {}
	local heroes: { any } = {}
	local dropped = 0

	-- Ground filter for series and rings: a post is dropped (counted) where the ground is wet, cliff, a road, an altar or a foe's home.
	local allRoads: { any } = {}
	for _, road in Overworld.terrainData().Roads do
		for k = 2, #road.Points do
			table.insert(allRoads, { road.Points[k - 1][1], road.Points[k - 1][2], road.Points[k][1], road.Points[k][2] })
		end
	end
	local function groundOk(x: number, z: number, avoidRoad: number): boolean
		local h, _, channelW, chasmW = Overworld.sampleAt(x, z)
		local sx, sz = (Overworld.heightAt(x + 4, z) - h) / 4, (Overworld.heightAt(x, z + 4) - h) / 4
		if channelW >= 0.5 or chasmW >= 0.01 or math.sqrt(sx * sx + sz * sz) >= 0.9 then
			return false
		end
		for _, a in Overworld.Altars do
			if worldDist(x, z, a.Placement.X, a.Placement.Z) < 16 then return false end
		end
		for _, e in Overworld.EncounterSpots do
			if worldDist(x, z, e.Placement.X, e.Placement.Z) < 14 then return false end
		end
		for _, sg in allRoads do
			if segDist(sg[1], sg[2], sg[3], sg[4], x, z) < avoidRoad then return false end
		end
		return true
	end

	for _, spec in expand(def.Hero()) do
		pace()
		local piece = P[spec.Piece]
		assert(piece, "BiomeDressing: unknown piece " .. tostring(spec.Piece) .. " (" .. spec.Id .. ")")
		local x, z, yaw = spec.X, spec.Z, spec.Yaw
		if spec.Edge then
			local path = pathOf(spec.Edge)
			local px, pz, tx, tz = pointAt(path, spec.Arc or spec.Frac * path.Length)
			x, z = px - tz * (spec.Off or 0), pz + tx * (spec.Off or 0)
			yaw = math.deg(math.atan2(tx, tz)) + (spec.YawAdd or 0)
		end
		if (spec.Clip and not inBox(bounds, x, z)) or ((spec.Ground or spec.AvoidRoad) and not groundOk(x, z, if spec.Road then 0 else (spec.AvoidRoad or 0))) then
			dropped += 1
		else
			local scale = spec.Scale or 1
			local fx, fz = if spec.Foot then spec.Foot[1] else 0, if spec.Foot then spec.Foot[2] else 0
			if piece.Subs[1].Shape == "Steps" and not spec.Y then
				-- a stair climbs toward local -Z and its flat underside sits at the low (+Z) end's ground: face the rising slope, stand on the low end
				local half = 0.5 * piece.Size[3] * scale
				local r0 = math.rad(yaw)
				local sy, cy = math.sin(r0), math.cos(r0)
				if Overworld.heightAt(x + sy * half, z + cy * half) > Overworld.heightAt(x - sy * half, z - cy * half) then yaw += 180 end
				fx, fz = 0, half
			end
			local rad = math.rad(yaw)
			local gx, gz = x + fx * math.cos(rad) + fz * math.sin(rad), z - fx * math.sin(rad) + fz * math.cos(rad)
			local h = { Id = spec.Id, Piece = spec.Piece, Class = "Hero", Kind = if spec.Interior then "Interior" else "Hero", X = x, Z = z, GX = gx, GZ = gz,
				Y = spec.Y or Overworld.heightAt(gx, gz), Yaw = yaw + (BiomeDressing.ImportYaw[spec.Piece] or 0), Scale = scale, Sink = piece.Sink, Landmark = spec.Landmark == true,
				Cell = Slice.cellOf(x, z), Road = spec.Road == true, Shelf = spec.Shelf == true, Cliff = spec.Cliff == true, LiftEnd = spec.LiftEnd, Shelter = spec.Shelter, CaveMouth = spec.CaveMouth }
			table.insert(heroes, h)
			table.insert(placements, h)
		end
	end

	-- Interiors (appended after the heroes so a hero list never shifts)
	local extraCircles: { any } = {}
	local interiors: { any } = {}
	for _, spec in (BiomeDressing.Interiors :: any)[id] do
		pace()
		table.insert(interiors, buildInterior(spec, id, placements, extraCircles))
	end

	-- Corridor spine: this region's walkable edges; scatter lives within Half + Fade of it and inside a disc round each key node.
	local C: any = def.Corridor
	local spine = walks(id)
	local x0: number, x1: number, z0: number, z1: number = math.huge, -math.huge, math.huge, -math.huge
	local function grow(x: number, z: number, r: number)
		x0, x1, z0, z1 = math.min(x0, x - r), math.max(x1, x + r), math.min(z0, z - r), math.max(z1, z + r)
	end
	for _, path in spine do
		for _, p in path.Points do grow(p[1], p[2], C.Half + C.Fade) end
	end
	local discs: { any } = {}
	for _, dsc in C.Discs do
		local nx, nz = nodeXZ(dsc.Node)
		table.insert(discs, { X = nx, Z = nz, R = dsc.R })
		grow(nx, nz, dsc.R + C.Fade)
	end
	x0, x1 = math.max(x0, bounds.Center.X - bounds.Size.X / 2), math.min(x1, bounds.Center.X + bounds.Size.X / 2)
	z0, z1 = math.max(z0, bounds.Center.Z - bounds.Size.Z / 2), math.min(z1, bounds.Center.Z + bounds.Size.Z / 2)

	-- Every road (and the straight legs where an edge has none) near the box is kept clear.
	local roadSegs: { any } = {}
	for _, road in Overworld.terrainData().Roads do
		for k = 2, #road.Points do
			local p, q = road.Points[k - 1], road.Points[k]
			if math.max(p[1], q[1]) > x0 - 20 and math.min(p[1], q[1]) < x1 + 20 and math.max(p[2], q[2]) > z0 - 20 and math.min(p[2], q[2]) < z1 + 20 then
				table.insert(roadSegs, { p[1], p[2], q[1], q[2] })
			end
		end
	end
	for _, path in spine do
		if #path.Points == 2 then
			table.insert(roadSegs, { path.Points[1][1], path.Points[1][2], path.Points[2][1], path.Points[2][2] })
		end
	end
	local lanes: { any } = {}
	local laneHero: any = nil
	for _, h in heroes do
		if h.Id == def.Lane.Hero then laneHero = h end
	end
	if laneHero then
		local lp = pathOf(def.Lane.Edge)
		for _, p in lp.Points do
			if worldDist(p[1], p[2], laneHero.X, laneHero.Z) <= def.Lane.Reach then
				table.insert(lanes, { p[1], p[2], laneHero.X, laneHero.Z })
			end
		end
	end
	local list = circles(heroes, extraCircles)

	-- Distance to the spine is measured from each 64 stud block's centre first: blocks farther than the reach (+ block half
	-- diagonal) skip the exact test, which keeps the long snow and mountain spines cheap.
	local spineReach, blockD = C.Half + C.Fade, {}
	local function spineDist(x: number, z: number): number
		local dmin = math.huge
		for _, path in spine do
			local pts = path.Points
			for k = 2, #pts do
				dmin = math.min(dmin, segDist(pts[k - 1][1], pts[k - 1][2], pts[k][1], pts[k][2], x, z))
			end
		end
		return dmin
	end
	local function corridorWeight(x: number, z: number): number
		local bx, bz = math.floor(x / 64), math.floor(z / 64)
		local key = bx * 65536 + bz
		local cd = blockD[key]
		if not cd then
			cd = spineDist((bx + 0.5) * 64, (bz + 0.5) * 64)
			blockD[key] = cd
		end
		local w = 0
		if cd - 46 <= spineReach then
			w = 1 - smooth((spineDist(x, z) - C.Half) / C.Fade)
		end
		for _, dsc in discs do
			w = math.max(w, 1 - smooth((worldDist(x, z, dsc.X, dsc.Z) - dsc.R) / C.Fade))
		end
		return w
	end

	local occ: { [number]: { any } } = {}
	local GRID = 32
	local function occKey(ix: number, iz: number): number
		return ix * 4096 + iz
	end
	local function crowded(x: number, z: number, cls: string, radius: number, trunk: number): boolean
		local reach = math.ceil(40 / GRID)
		local cx, cz = math.floor(x / GRID), math.floor(z / GRID)
		for ix = cx - reach, cx + reach do
			for iz = cz - reach, cz + reach do
				for _, o in occ[occKey(ix, iz)] or {} do
					local dd = worldDist(x, z, o.X, o.Z)
					local need = if cls == "Tree" and o.Class == "Tree" then 0.65 * (radius + o.R) else 0.5 * (trunk + o.T) + 1
					if dd < need then
						return true
					end
				end
			end
		end
		return false
	end

	local byClass: { [string]: number } = {}
	local dens: number = C.Density or 1
	for _, class in BiomeDressing.Classes do
		local rule: any = def.Scatter[class]
		local S = rule.Spacing
		local salt = rule.Salt * 10 + biomeIndex * 1000
		local n = 0
		for gi = math.floor(x0 / S), math.ceil(x1 / S) do
			for gj = math.floor(z0 / S), math.ceil(z1 / S) do
				pace()
				local x = (gi + 0.5 + (rand(gi, gj, salt + 1) - 0.5) * 0.8) * S
				local z = (gj + 0.5 + (rand(gi, gj, salt + 2) - 0.5) * 0.8) * S
				if inBox(bounds, x, z) then
					local wc = corridorWeight(x, z)
					if wc > 0 and rand(gi, gj, salt + 3) < rule.Base * dens * wc and not hostile(x, z, class, list, roadSegs, lanes, rule.Tall == true, def.Lane.HalfWidth) then
						local h, roadW, channelW, chasmW = Overworld.sampleAt(x, z)
						if roadW < 0.5 and channelW < 0.05 and chasmW < 0.01 and h > 3 then
							local sx, sz = (Overworld.heightAt(x + 4, z) - h) / 4, (Overworld.heightAt(x, z + 4) - h) / 4
							local slope = math.sqrt(sx * sx + sz * sz)
							local mat = Overworld.materialAt(x, z, h, slope, roadW, channelW, chasmW)
							local factor = rule.Material[mat] or 0
							factor *= 1 - smooth((slope - (rule.MaxSlope - 0.15)) / 0.15)
							if rule.MinSlope then
								factor *= smooth((slope - rule.MinSlope + 0.1) / 0.2)
							end
							factor *= BiomeDressing.altFactor(rule.Alt, h)
							-- region blend: density follows this region's environment weight across the border band
							factor *= Overworld.blendAt(x, z)[id] or 0
							if rand(gi, gj, salt + 3) < rule.Base * dens * wc * math.clamp(factor, 0, 1.6) then
								local list2 = if rule.ByMaterial and rule.ByMaterial[mat] then rule.ByMaterial[mat] else rule.Pieces
								local total = 0
								for _, entry in list2 do total += entry[2] end
								local pick, cum, r4 = list2[1][1], 0, rand(gi, gj, salt + 4) * total
								for _, entry in list2 do
									cum += entry[2]
									pick = entry[1]
									if r4 <= cum then break end
								end
								local piece = P[pick]
								assert(piece, "BiomeDressing: scatter piece missing " .. pick)
								local scale = rule.Scale[1] + (rule.Scale[2] - rule.Scale[1]) * rand(gi, gj, salt + 5)
								local radius, trunk = piece.Radius * scale, piece.Trunk * scale
								if not massHostile(piece, radius, x, z, list, roadSegs) and (class == "Grass" or not crowded(x, z, class, radius, trunk)) then
									n += 1
									table.insert(placements, { Id = string.format("%s_%04d", class, n), Piece = pick, Class = class, Kind = "Scatter", X = x, Z = z, GX = x, GZ = z, Y = h,
										Yaw = rand(gi, gj, salt + 6) * 360 + (BiomeDressing.ImportYaw[pick] or 0), Scale = scale, Sink = piece.Sink, Landmark = false, Cell = Slice.cellOf(x, z) })
									if class ~= "Grass" then
										local key = occKey(math.floor(x / GRID), math.floor(z / GRID))
										occ[key] = occ[key] or {}
										table.insert(occ[key], { X = x, Z = z, R = radius, T = trunk, Class = class })
									end
								end
							end
						end
					end
				end
			end
		end
		byClass[class] = n
	end

	-- Totals and per-cell lists (a cell needs its own tile and every tile a hero footprint reaches)
	local counts: { [string]: number } = {}
	local cells: { [string]: any } = {}
	local meshParts: number, placeholderParts: number, tris: number, trisLod: number = 0, 0, 0, 0
	local function cellFor(key: string): any
		local c = cells[key]
		if not c then
			c = { Placements = {}, Needs = { [key] = true } }
			cells[key] = c
		end
		return c
	end
	for _, pl in placements do
		local piece = P[pl.Piece]
		counts[pl.Piece] = (counts[pl.Piece] or 0) + 1
		meshParts += piece.MeshParts
		placeholderParts += piece.PlaceholderParts
		tris += piece.Tris
		trisLod += piece.TrisLod
		local c = cellFor(pl.Cell)
		table.insert(c.Placements, pl)
		if pl.Kind ~= "Scatter" then
			local r = piece.Radius * pl.Scale
			for _, dx in { -r, 0, r } do
				for _, dz in { -r, 0, r } do
					c.Needs[Slice.cellOf(pl.X + dx, pl.Z + dz)] = true
				end
			end
		end
	end
	local result = { Biome = id, Placements = placements, Heroes = heroes, Interiors = interiors, Counts = counts, ByClass = byClass, Cells = cells, MeshParts = meshParts,
		PlaceholderParts = placeholderParts, Tris = tris, TrisLod = trisLod, Bounds = { X0 = x0, X1 = x1, Z0 = z0, Z1 = z1 }, Lanes = lanes, RoadSegments = roadSegs, Dropped = dropped,
		Circles = list }
	builtCache[id] = result
	return result
end

-- Kit slots used by a biome (hero, scatter and interior placements), by piece name: { [name] = count }.
function BiomeDressing.slotsOf(id: string): { [string]: number }
	return BiomeDressing.build(id).Counts
end

-------------------------------------------------------------------------------------------------
-- Planner (open-world D4). Additive to build(): scale tiers, placeholder silhouettes (bbox + rough primitives, held as data so a mesh
-- swap changes data only), the per-region part budget, distance thinning, noise-mask clustering and a composed set piece per site.
-- plan() is what BiomeDressingService raises. Pure and deterministic: same seed and terrain, same list.
-------------------------------------------------------------------------------------------------

-- Placeholder parts one region may hold at once (silhouette primitives; set pieces included). plan() trims scatter to it (grass first)
-- and BiomeDressingService refuses any part past it. Raise only with a Studio profile behind it.
BiomeDressing.PartBudget = 1500

-- Scale tiers by the piece's longest side: three scales in every view (landmark and tree masses, mid structures and rocks, ground cover).
BiomeDressing.TierMin = { Large = 24, Medium = 9 }
-- Studs beyond which a tier is not built, and the distance from which its scatter thins linearly to nothing at Reach.
BiomeDressing.Reach = { Large = 900, Medium = 420, Small = 170 }
BiomeDressing.ThinFrom = { Large = 450, Medium = 170, Small = 60 }
-- Value-noise clustering per scatter class: { cell size studs, threshold, salt }. A spot survives with smooth((mask - threshold) / 0.2).
BiomeDressing.Cluster = { Rock = { 130, 0.42, 301 }, Tree = { 170, 0.40, 302 }, Shrub = { 90, 0.44, 303 }, Fern = { 70, 0.46, 304 }, Grass = { 55, 0.42, 305 } }
-- Which Keep column a set-piece tier borrows.
local TIER_KEEP: { [string]: string } = { Large = "Tree", Medium = "Rock", Small = "Fern" }

-- Silhouette templates { Shape, cx, cz, y0, y1, w, d, role }: centre (fractions of the footprint), height span and size (fractions of the box).
-- Shapes: Block, Cylinder (upright), Wedge. role picks the sub-mesh whose material, colour and collision the primitive borrows.
local SIL: { [string]: { { any } } } = {
	Tree = { { "Cylinder", 0, 0, 0, 0.62, 0.1, 0.1, "trunk" }, { "Cylinder", 0, 0, 0.36, 1, 0.8, 0.8, "leaf" } },
	Conifer = { { "Cylinder", 0, 0, 0, 0.5, 0.09, 0.09, "trunk" }, { "Cylinder", 0, 0, 0.12, 0.45, 0.85, 0.85, "leaf" }, { "Cylinder", 0, 0, 0.4, 0.72, 0.6, 0.6, "leaf" },
		{ "Cylinder", 0, 0, 0.68, 1, 0.32, 0.32, "leaf" } },
	Rock = { { "Block", 0, 0, 0, 0.65, 1, 1, "body" }, { "Block", 0.05, 0, 0.65, 1, 0.6, 0.7, "body" } },
	Tower = { { "Block", 0, 0, 0, 0.5, 1, 1, "body" }, { "Block", 0, 0, 0.5, 0.85, 0.7, 0.7, "body" }, { "Block", 0, 0, 0.85, 1, 0.5, 0.5, "top" } },
	Column = { { "Block", 0, 0, 0, 1, 1, 1, "body" } },
	Wall = { { "Block", 0, 0, 0, 1, 1, 1, "body" } },
	Slab = { { "Block", 0, 0, 0, 1, 1, 1, "body" } },
	Plant = { { "Cylinder", 0, 0, 0, 1, 1, 1, "leaf" } },
	Snag = { { "Cylinder", 0, 0, 0, 1, 0.8, 0.8, "trunk" } },
	Ramp = { { "Wedge", 0, 0, 0, 1, 1, 1, "body" } },
	Tuft = { { "Block", 0, 0, 0, 1, 1, 0.45, "leaf" } },
	Hall = { { "Block", 0, 0, 0, 0.62, 1, 1, "body" }, { "Wedge", 0, 0, 0.62, 1, 1, 1, "top" } },
	Arch = { { "Block", -0.4, 0, 0, 0.8, 0.2, 1, "body" }, { "Block", 0.4, 0, 0, 0.8, 0.2, 1, "body" }, { "Block", 0, 0, 0.8, 1, 1, 1, "body" } },
	Arcade = { { "Block", -0.4, 0, 0, 0.8, 0.1, 1, "body" }, { "Block", 0, 0, 0, 0.8, 0.1, 1, "body" }, { "Block", 0.4, 0, 0, 0.8, 0.1, 1, "body" },
		{ "Block", 0, 0, 0.8, 1, 1, 1, "body" } },
}
BiomeDressing.Silhouettes = SIL

-- Archetype by name; first match wins. Steps are detected from the sub-mesh shape. Default: Hall for a structure, Rock otherwise.
local ARCH_EXACT: { [string]: string } = { Basin_Statue_Hand = "Rock", Basin_Statue_Head = "Rock", Basin_Gate_Statue = "Tower", Ravine_Aqueduct_Arch = "Arcade",
	Cave_Rib_Arch = "Arch", Cave_Mouth_Arch = "Arch", Cave_Roof_Slab = "Slab", Cave_Brazier = "Column", Basin_Caravan_Wreck = "Slab", Ravine_Grotto_Landing = "Slab" }
local ARCH_WORDS: { { string } } = { { "Pine", "Conifer" }, { "Tree", "Tree" }, { "Acacia", "Tree" }, { "Gate", "Arch" }, { "Beacon", "Tower" }, { "Stack", "Tower" },
	{ "Spire", "Tower" }, { "Obelisk", "Column" }, { "Pylon", "Column" }, { "Pillar", "Column" }, { "Post", "Column" }, { "Stake", "Column" }, { "Marker", "Column" },
	{ "Wall", "Wall" }, { "Parapet", "Wall" }, { "Windbreak", "Wall" }, { "Scree", "Slab" }, { "Boulder", "Rock" }, { "Crag", "Rock" }, { "Drift", "Rock" },
	{ "Cairn", "Rock" }, { "Heap", "Rock" }, { "Cluster", "Rock" }, { "Shrub", "Plant" }, { "Scrub", "Plant" }, { "Fern", "Plant" }, { "Tussock", "Plant" },
	{ "Agave", "Plant" }, { "Clump", "Tuft" }, { "Tuft", "Tuft" } }

local function pickSub(subs: { any }, role: string): number
	local function find(pred: (any) -> boolean): number?
		for i, sb in subs do
			if pred(sb) then return i end
		end
		return nil
	end
	if role == "body" then
		return find(function(sb: any): boolean return sb.Collide end) or 1
	elseif role == "top" then
		return find(function(sb: any): boolean return sb.Name:find("Roof") ~= nil or sb.Name:find("Head") ~= nil or sb.Name:find("Fire") ~= nil or sb.Name:find("Crown") ~= nil end) or #subs
	elseif role == "trunk" then
		return find(function(sb: any): boolean return sb.Name == "Bark" end) or 1
	end
	-- leaf: the main foliage sub, never the LOD detail one
	return find(function(sb: any): boolean return not sb.Lod and sb.Name ~= "Bark" and sb.Name ~= "Stems" end) or #subs
end

for name, p in P do
	local arch = ARCH_EXACT[name] or p.ArchHint
	if not arch then
		for _, sb in p.Subs do
			if sb.Shape == "Steps" then arch = "Steps" end
		end
	end
	if not arch then
		for _, w in ARCH_WORDS do
			if name:find(w[1], 1, true) then
				arch = w[2]
				break
			end
		end
	end
	p.Arch = arch or (if p.Structure then "Hall" else "Rock")
	local parts: { any } = {}
	if p.Arch == "Steps" then
		p.Parts = p.Subs[1].Steps
	else
		for _, t in SIL[p.Arch] do
			table.insert(parts, { Shape = t[1], Cx = t[2], Cz = t[3], Y0 = t[4], Y1 = t[5], W = t[6], D = t[7], Sub = pickSub(p.Subs, t[8]) })
		end
		p.Parts = #parts
	end
	p.Sil = parts
	local longest = math.max(p.Size[1], p.Size[2], p.Size[3])
	p.Tier = if longest >= BiomeDressing.TierMin.Large then "Large" elseif longest >= BiomeDressing.TierMin.Medium then "Medium" else "Small"
end

-- Registered-asset fits (piece -> a mesh already uploaded in one of assets/*_UPLOADED.json). The service clones ServerStorage/<Path>, keeps
-- the named MeshPart and scales it into the piece box (SliceDressingService's assetPiece). Ids are copied from the registries, never invented.
local PH5 = "assets/PHASE5_UPLOADED.json"
local STONE_FIT = { Registry = PH5, Id = 106842288070597, Path = "AsuraAssets/AsuraStone", Part = "Plane.001" }
local PILLAR_FIT = { Registry = PH5, Id = 83165492087847, Path = "AsuraAssets/AsuraRuinPillar", Part = "geom-PillarSegmentOne200" }
BiomeDressing.Assets = {
	Amber_Boulder_A = STONE_FIT, Amber_Boulder_B = STONE_FIT, Amber_Boulder_C = STONE_FIT,
	Tide_Boulder_A = STONE_FIT, Tide_Boulder_B = STONE_FIT, Tide_Boulder_C = STONE_FIT,
	Snow_Ruin_Pillar = PILLAR_FIT, Basin_Obelisk = PILLAR_FIT,
	Cave_Brazier = { Registry = PH5, Id = 108335955316266, Path = "AsuraAssets/AsuraFirePit", Part = "texturedMesh.002" },
	Cave_Mouth_Arch = { Registry = PH5, Id = 103358279439886, Path = "AsuraAssets/AsuraRuinArch", Part = "geom-RuinArchOne200" },
} :: { [string]: any }
for name in BiomeDressing.Assets do
	assert(P[name], "BiomeDressing.Assets: unknown piece " .. name)
end
-- Generated from assets/BIOME_KIT_UPLOADED.json once a biome kit is uploaded (same shape as SliceDressing.Registry: [piece][piece__Sub] = { MeshId, ... }).
BiomeDressing.Registry = {} :: any
-- The uploaded kits reach runtime as generated modules next to this file (the "pieces" table of assets/<KIT>_KIT_UPLOADED.json, same shape as
-- SliceKitRegistry; tools/assets/kit_registry.py). Absent module = pieces stay assets or silhouettes. A hero slot looks up its hero's key; the hero
-- pack (HeroKitRegistry) is read first so a kit row of the same name wins, and the service falls back to it for a slot whose refined hero is absent.
if hasScript then
	for _, moduleName in { "HeroKitRegistry", "AmberfallKitRegistry", "SaltreachKitRegistry", "FrostmereKitRegistry", "AshenKitRegistry" } do
		local ok, reg = pcall(function() return require((script :: any).Parent[moduleName]) end)
		if ok and type(reg) == "table" then
			for piece, subs in reg do
				BiomeDressing.Registry[piece] = subs
			end
		end
	end
end

-- Set-piece kits per biome: the pieces a site's composed set draws from, by tier (every name must exist and carry that tier).
BiomeDressing.SetKits = {
	-- Amberfall and Saltreach: the uploaded kits' built pieces (a site's picks walk the list in order, site by site, so a small biome still shows most of them).
	GoldenRavine = { Large = { "Amber_Aqueduct_Span_Ruined", "Amber_Aqueduct_Abutment", "Amber_Footbridge_Rope", "Amber_Stair_Run", "Amber_Cliff_Corner", "Amber_Cliff_Wall_B" },
		Medium = { "Amber_Retaining_Wall_A", "Amber_Shrine", "Amber_Lantern_Stone", "Amber_Lantern_Hanging", "Amber_Rope_Rail", "Amber_Cart", "Amber_Crate_Stack" },
		Small = { "Ravine_Cairn", "Amber_Grass_Pale", "Amber_Grass_Dry", "Amber_Grass_Seed" } },
	AridBasin = { Large = { "Gate_Arch", "Salt_Pan_Channel", "Boat_Hull_A", "Gate_Pier", "Salt_Pan_Frame" },
		Medium = { "Boardwalk_Straight", "Fisher_Hut_A", "Pier_Section", "Net_Rack", "Fisher_Hut_B", "Boat_Hull_B", "Pier_End", "Boardwalk_Steps", "Stone_Lantern_Salt" },
		Small = { "Salt_Cairn", "Dune_Scrub_A", "Dune_Scrub_B", "Salt_Grass_Tuft" } },
	-- Frostmere and Ashen: the same walk over the kits' built pieces (lane K).
	Snowfields = { Large = { "Frost_Dock_Section", "Frost_Prayer_Flags", "Frost_Stair_Run", "Frost_Retaining_Wall", "Frost_Cliff_Wall_B" },
		Medium = { "Frost_Fishing_Hut", "Frost_Cairn", "Frost_Brazier", "Frost_Lantern", "Frost_Sled", "Frost_Ice_Shards_A" },
		Small = { "Frost_Shrub_Small", "Frost_Grass_Tuft_A", "Frost_Grass_Tuft_B" } },
	MountainAscent = { Large = { "Ash_Rest_Pavilion", "Ash_Gate_Broken", "Ash_Stair_Run_Turn", "Ash_Prayer_Flags", "Ash_Stair_Run_Long" },
		Medium = { "Ash_Shrine_Pilgrim", "Ash_Retaining_Wall_A", "Ash_Retaining_Wall_B", "Ash_Lantern_Stone", "Ash_Stair_Run_Straight", "Ash_Snag_Fallen" },
		Small = { "Ash_Lichen_A", "Ash_Tussock_A", "Ash_Tussock_B", "Ash_Shrub_Small", "Ash_Lichen_B" } },
}

local function strHash(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = mul32(bit32.bxor(h, string.byte(s, i)), 16777619)
	end
	return h
end
BiomeDressing.strHash = strHash

-- Smooth value noise 0..1 on a lattice of `scale` studs.
local function vnoise(x: number, z: number, scale: number, salt: number): number
	local gx, gz = x / scale, z / scale
	local ix, iz = math.floor(gx), math.floor(gz)
	local fx, fz = smooth(gx - ix), smooth(gz - iz)
	local a, b = rand(ix, iz, salt), rand(ix + 1, iz, salt)
	local c, d = rand(ix, iz + 1, salt), rand(ix + 1, iz + 1, salt)
	local top = a + (b - a) * fx
	return top + ((c + (d - c) * fx) - top) * fz
end

-- Cluster mask 0..1 for a scatter class (two octaves): high where the class gathers, low where it thins out.
function BiomeDressing.mask(class: string, x: number, z: number): number
	local c = (BiomeDressing.Cluster :: any)[class]
	return 0.65 * vnoise(x, z, c[1], c[3]) + 0.35 * vnoise(x, z, c[1] * 0.4, c[3] + 17)
end

-- Distance thinning: is this placement built when the nearest viewer is d studs away? Scatter keeps a falling share (its own stable Rank
-- decides which survive, so the same ones stay as you walk); structures, set pieces and interiors have Rank 0 and keep until Reach.
function BiomeDressing.visibleAt(pl: any, d: number): boolean
	if pl.Landmark then
		return true
	end
	local reach, from = BiomeDressing.Reach[pl.Tier], BiomeDressing.ThinFrom[pl.Tier]
	if d >= reach then
		return false
	end
	local share = if d <= from then 1 else 1 - (d - from) / (reach - from)
	return pl.Rank < share
end

-- Every site that gets a composed set piece: each surface route-graph node of the region (altars, subareas, junctions), each landmark and
-- each visible surface point of interest that is not already a structure of its own (caves, lifts, bridges, gates, encounters, hidden caches).
local SITE_KINDS: { [string]: boolean } = { Ruin = true, Lake = true, Pass = true, Canyon = true, Gallery = true, Temple = true, Stair = true, Hut = true }
function BiomeDressing.sites(id: string): { any }
	local out: { any } = {}
	local under = Overworld.TerrainDef.Underground
	local function overSpan(x: number, z: number): boolean -- a node over the chasm is mid-span: the span's own pylons and posts are its composed set
		local _, _, _, chasmW = Overworld.sampleAt(x, z)
		return chasmW >= 0.05
	end
	for nid, nd in Overworld.Nodes do -- altars, subareas and junctions of the route graph (the barrier node is the lead's gate, left alone)
		if nd.Region == id and nd.Kind ~= "barrier" and not under[nid] and not overSpan(nd.Position.X, nd.Position.Z) then
			table.insert(out, { Id = nid, Kind = if nd.Kind == "altar" then "Altar" else "Node", X = nd.Position.X, Z = nd.Position.Z })
		end
	end
	for lid, lm in Overworld.Landmarks do
		if lm.Region == id then
			table.insert(out, { Id = "Landmark_" .. lid, Kind = "Landmark", X = lm.Position.X, Z = lm.Position.Z })
		end
	end
	for _, p in Overworld.POIs do
		if p.Region == id and p.Level == "Surface" and not p.Hidden and SITE_KINDS[p.Kind] then
			table.insert(out, { Id = "Poi_" .. p.Id, Kind = p.Kind, X = p.Position.X, Z = p.Position.Z })
		end
	end
	table.sort(out, function(a: any, b: any): boolean return a.Id < b.Id end)
	return out
end

local planCache: { [string]: any } = {}

-- Region plan: { Biome, Placements, Sites, Cells, Parts, Budget, Trimmed, ByTier, ByKind, ... }. Every placement carries Tier, Parts and Rank.
-- Scatter outside the biome's noise clusters is dropped, nothing but a hero stands on an arena pad, set pieces are composed per site, and
-- scatter is trimmed (grass, ferns, shrubs, rocks, trees in that order, highest Rank first) until Parts <= PartBudget.
function BiomeDressing.plan(id: string, fresh: boolean?, tick: (() -> ())?): any
	if fresh then
		planCache[id] = nil
	end
	if planCache[id] then
		return planCache[id]
	end
	local pace: () -> () = tick or function() end
	local R = BiomeDressing.build(id, false, tick)
	local def: any = (BiomeDressing.Defs :: any)[id]
	local bounds = Overworld.Regions[id].Bounds
	local biomeIndex = table.find(BiomeDressing.Order, id) :: number
	local kit: any = (BiomeDressing.SetKits :: any)[id]

	-- Arena pads: the reserved boss arenas and the summit barrier arena (plus rings, already in R.Circles).
	local arenas: { any } = {}
	local function arena(a: any)
		table.insert(arenas, { X0 = a.Center.X - a.Size.X / 2, X1 = a.Center.X + a.Size.X / 2, Z0 = a.Center.Z - a.Size.Z / 2, Z1 = a.Center.Z + a.Size.Z / 2 })
	end
	for _, ra in Overworld.ReservedArenas do arena(ra.Arena) end
	arena(Overworld.Barrier.Arena)
	local function inArena(x: number, z: number): boolean
		for _, a in arenas do
			if x >= a.X0 and x <= a.X1 and z >= a.Z0 and z <= a.Z1 then return true end
		end
		return false
	end

	local out: { any } = {}
	local masked, arenaDropped = 0, 0
	for _, pl in R.Placements do
		pace()
		local piece = P[pl.Piece]
		local rank = if pl.Kind == "Scatter" then rand(strHash(pl.Id), biomeIndex, 991) else 0
		local keep = true
		if pl.Kind == "Scatter" then
			if inArena(pl.X, pl.Z) then
				keep, arenaDropped = false, arenaDropped + 1
			else
				local c = (BiomeDressing.Cluster :: any)[pl.Class]
				local k = smooth((BiomeDressing.mask(pl.Class, pl.X, pl.Z) - c[2]) / 0.2)
				if rand(strHash(pl.Id), biomeIndex, 41) >= math.max(k, 0.05) then
					keep, masked = false, masked + 1
				end
			end
		end
		if keep then
			table.insert(out, with(pl, { Tier = piece.Tier, Parts = piece.Parts, Rank = rank }))
		end
	end

	-- Set pieces
	local setPlaced: { any } = {}
	local nearCircles: { any }, nearRoads: { any } = {}, {} -- the exclusions within search reach of the site being composed
	local function okSpot(x: number, z: number, piece: any, scale: number): boolean
		if not inBox(bounds, x, z) or inArena(x, z) then
			return false
		end
		if hostile(x, z, TIER_KEEP[piece.Tier], nearCircles, nearRoads, R.Lanes, piece.Tier == "Large", def.Lane.HalfWidth) or massHostile(piece, piece.Radius * scale, x, z, nearCircles, nearRoads) then
			return false
		end
		local h, roadW, channelW, chasmW = Overworld.sampleAt(x, z)
		if roadW >= 0.5 or channelW >= 0.05 or chasmW >= 0.01 or h <= 3 then
			return false
		end
		local sx, sz = (Overworld.heightAt(x + 4, z) - h) / 4, (Overworld.heightAt(x, z + 4) - h) / 4
		if math.sqrt(sx * sx + sz * sz) >= (if piece.Tier == "Small" then 0.75 else 0.55) then
			return false
		end
		local rr = piece.Radius * scale
		for _, o in setPlaced do
			if worldDist(x, z, o.X, o.Z) < 0.5 * (rr + o.R) + 2 then
				return false
			end
		end
		return true
	end
	local function findSpot(site: any, piece: any, scale: number, base: number, r0: number): (number?, number?)
		local rad = r0
		while rad <= 130 do
			pace()
			for step = 0, 9 do
				for _, sgn in { 1, -1 } do
					if step > 0 or sgn == 1 then
						local a = math.rad(base + sgn * step * 20)
						local x, z = site.X + math.cos(a) * rad, site.Z + math.sin(a) * rad
						if okSpot(x, z, piece, scale) then
							return x, z
						end
					end
				end
			end
			rad += 8
		end
		return nil, nil
	end

	local sites = BiomeDressing.sites(id)
	local siteRecs: { any } = {}
	local sets: { any } = {}
	local seq: { [string]: number } = { Large = 0, Medium = 0, Small = 0 } -- picks walk the kit list in order (deterministic, covers the kit)
	for _, site in sites do
		local sh = strHash(site.Id)
		local theta0 = rand(sh, 1, 77) * 360
		local isAltar = site.Kind == "Altar"
		nearCircles, nearRoads = {}, {}
		for _, c in R.Circles do
			local reach = 0
			for _, v in c.Keep do reach = math.max(reach, v) end
			if worldDist(site.X, site.Z, c.X, c.Z) <= 130 + 45 + reach then table.insert(nearCircles, c) end
		end
		for _, sg in R.RoadSegments do
			if segDist(sg[1], sg[2], sg[3], sg[4], site.X, site.Z) <= 130 + 45 + 14 then table.insert(nearRoads, sg) end
		end
		local rec: any = { Id = site.Id, Kind = site.Kind, X = site.X, Z = site.Z, Pieces = {}, Tiers = { Large = 0, Medium = 0, Small = 0 } }
		local n = 0
		for _, group in { { "Large", 1, 0 }, { "Medium", if isAltar then 3 else 2, 110 }, { "Small", if isAltar then 5 else 4, 40 } } do
			local tier, count, offset = group[1] :: string, group[2] :: number, group[3] :: number
			local list: { string } = kit[tier]
			for k = 1, count do
				n += 1
				local pick = list[1 + seq[tier] % #list]
					seq[tier] += 1
				local piece = P[pick]
				local scale = 0.9 + 0.3 * rand(sh, n, 92)
				local r0 = (if isAltar then 30 else 14) + piece.Radius * scale * 0.6
				local x, z = findSpot(site, piece, scale, theta0 + offset + (k - 1) * (360 / count), r0)
				if x and z then
					local yaw = math.deg(math.atan2(site.X - x, site.Z - z)) + (rand(sh, n, 93) - 0.5) * 50
					local pl = { Id = string.format("Set_%s_%d", site.Id, n), Piece = pick, Class = "Set", Kind = "Set", Site = site.Id, SiteKind = site.Kind, SiteReady = if isAltar then site.Id else nil,
						X = x, Z = z, GX = x, GZ = z, Y = Overworld.heightAt(x, z), Yaw = yaw + (BiomeDressing.ImportYaw[pick] or 0), Scale = scale, Sink = piece.Sink, Landmark = false,
						Cell = Slice.cellOf(x, z), Tier = piece.Tier, Parts = piece.Parts, Rank = 0 }
					table.insert(setPlaced, { X = x, Z = z, R = piece.Radius * scale })
					table.insert(out, pl)
					table.insert(sets, pl)
					table.insert(rec.Pieces, pl.Id)
					rec.Tiers[tier] += 1
				end
			end
		end
		table.insert(siteRecs, rec)
	end

	-- Scatter that overlaps a set piece makes way for it.
	local overlapped = 0
	local kept: { any } = {}
	for _, pl in out do
		local clash = false
		if pl.Kind == "Scatter" then
			local rp = P[pl.Piece].Radius * pl.Scale
			for _, o in setPlaced do
				if math.abs(pl.X - o.X) < 60 and math.abs(pl.Z - o.Z) < 60 and worldDist(pl.X, pl.Z, o.X, o.Z) < 0.5 * (rp + o.R) + 1 then
					clash = true
					break
				end
			end
		end
		if clash then overlapped += 1 else table.insert(kept, pl) end
	end
	out = kept

	-- Budget: structures, interiors and set pieces stay; scatter is trimmed to fit.
	local parts, fixed = 0, 0
	for _, pl in out do
		parts += pl.Parts
		if pl.Kind ~= "Scatter" then fixed += pl.Parts end
	end
	assert(fixed <= BiomeDressing.PartBudget, string.format("BiomeDressing %s: fixed placements (%d parts) exceed PartBudget %d", id, fixed, BiomeDressing.PartBudget))
	local trimmed = 0
	if parts > BiomeDressing.PartBudget then
		local DROP: { [string]: number } = { Grass = 1, Fern = 2, Shrub = 3, Rock = 4, Tree = 5 }
		local cand: { any } = {}
		for _, pl in out do
			if pl.Kind == "Scatter" then table.insert(cand, pl) end
		end
		table.sort(cand, function(a: any, b: any): boolean
			if DROP[a.Class] ~= DROP[b.Class] then return DROP[a.Class] < DROP[b.Class] end
			if a.Rank ~= b.Rank then return a.Rank > b.Rank end
			return a.Id < b.Id
		end)
		local gone: { [any]: boolean } = {}
		for _, pl in cand do
			if parts <= BiomeDressing.PartBudget then break end
			gone[pl] = true
			parts -= pl.Parts
			trimmed += 1
		end
		local fit: { any } = {}
		for _, pl in out do
			if not gone[pl] then table.insert(fit, pl) end
		end
		out = fit
	end

	-- Totals and per-cell lists (as build(): a cell needs its own tile and every tile a structure footprint reaches)
	local cells: { [string]: any } = {}
	local byTier: { [string]: number } = { Large = 0, Medium = 0, Small = 0 }
	local byKind: { [string]: number } = {}
	for _, pl in out do
		byTier[pl.Tier] += 1
		byKind[pl.Kind] = (byKind[pl.Kind] or 0) + 1
		local c = cells[pl.Cell]
		if not c then
			c = { Placements = {}, Needs = { [pl.Cell] = true } }
			cells[pl.Cell] = c
		end
		table.insert(c.Placements, pl)
		if pl.Kind ~= "Scatter" then
			local r = P[pl.Piece].Radius * pl.Scale
			for _, dx in { -r, 0, r } do
				for _, dz in { -r, 0, r } do
					c.Needs[Slice.cellOf(pl.X + dx, pl.Z + dz)] = true
				end
			end
		end
	end
	local plan = { Biome = id, Placements = out, Sets = sets, Sites = siteRecs, Cells = cells, Parts = parts, Budget = BiomeDressing.PartBudget, Trimmed = trimmed, Masked = masked,
		ArenaDropped = arenaDropped, Overlapped = overlapped, ByTier = byTier, ByKind = byKind, Bounds = R.Bounds, Lanes = R.Lanes, Build = R }
	planCache[id] = plan
	return plan
end

return BiomeDressing

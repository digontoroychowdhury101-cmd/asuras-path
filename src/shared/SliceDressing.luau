--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/SliceDressing
-- Representative slice (open-world issue 12): Gateway Glade -> Bell Terrace in the Bellwood. Engine-free DATA plus the
-- deterministic builder that turns it into placements; SliceDressingService raises them under Map_Overworld/SliceDressing.
--   Hero      hand-placed kit pieces (terrace stair and walls, pavilion, broken tower, gates, lantern posts).
--   Scatter   seeded jittered-grid rules for trees, shrubs, ferns, grass and rocks inside the slice corridor.
--   Keep      every exclusion (road, altars, arrival points, rings, encounter homes + leash, shelters, bridge ends, the
--             route's line of sight to the pavilion, the hero footprints) as radii per plant class.
-- A placement's Y is Overworld.heightAt at its foot (GX, GZ): the surface definition. The written voxel surface sits about
-- 2 studs higher (Overworld.luau Rings note), so the service raycasts and only falls back to heightAt + 2.
-- Piece sizes come from assets/source/overworld/slice/manifest.json (size_studs_xyz is Blender XYZ, Z up; stored here as
-- { X, Y up, Z } = { bx, bz, by }). Pivot = foot centre. Nothing here is an asset id.
local hasScript = pcall(function() return script.Parent end)
local Overworld: any = if hasScript then require(script.Parent.Overworld) else require("./Overworld")

local SliceDressing = {}

SliceDressing.Seed = 20261115
SliceDressing.Cell = 128 -- studs: the terrain tile size, so a cell key "i,j" is the OverworldTerrain tile key

-- Budget the builder must stay inside (test_slice_dressing asserts it). MeshParts = final kit sub-meshes (one MeshPart each);
-- PlaceholderParts = what the placeholder builder makes (stairs are step blocks); Tris = authored triangles if all were loaded
-- (TrisLod = the same with every Lod sub-mesh dropped, i.e. Leaves_Detail beyond ~150 studs, manifest "lod"). Raise a number only with a Studio profile behind it.
SliceDressing.Budget = { MeshParts = 3000, PlaceholderParts = 3400, Tris = 5000000, TrisLod = 3200000, Placements = 1900 }

-------------------------------------------------------------------------------------------------
-- Pieces. Sub = one kit sub-mesh (Piece__Name). B = placeholder boxes { cx, cz, y0, y1, w, d } as fractions of the piece
-- footprint (cx, cz, w, d) and height (y0, y1). Steps = n step blocks climbing local -Z (rise per step, tread per step).
-- Collide: the placeholder collides only where the real mesh will (structures); plants never collide.
-------------------------------------------------------------------------------------------------

local function sub(name: string, material: string, color: { number }, tris: number, boxes: { { number } }, collide: boolean?, lod: boolean?, shape: string?): any
	return { Name = name, Material = material, Color = color, Tris = tris, B = boxes, Collide = collide == true, Lod = lod == true, Shape = shape or "Block" }
end

local STONE, TIMBER, BRONZE, GLOW = { 112, 108, 100 }, { 150, 62, 42 }, { 150, 112, 58 }, { 255, 190, 110 }
local ROOFC, BARK, LEAF, LEAF2, FERN, GRASS, ROCKC = { 70, 78, 76 }, { 84, 62, 46 }, { 58, 96, 52 }, { 74, 112, 58 }, { 70, 120, 62 }, { 110, 140, 70 }, { 104, 100, 94 }

SliceDressing.Pieces = {
	Bell_Terrace_Pavilion = { Size = { 66.7, 89.2, 67.3 }, Structure = true, Sink = 1.5, Subs = {
		sub("Stone", "Slate", STONE, 1364, { { 0, 0, 0, 0.07, 1, 1 } }, true),
		sub("Timber", "Wood", TIMBER, 3504, { { -0.3, -0.3, 0.07, 0.42, 0.09, 0.09 }, { 0.3, -0.3, 0.07, 0.42, 0.09, 0.09 },
			{ -0.3, 0.3, 0.07, 0.42, 0.09, 0.09 }, { 0.3, 0.3, 0.07, 0.42, 0.09, 0.09 }, { 0, 0, 0.42, 0.6, 0.45, 0.45 } }, true),
		sub("Roof", "Slate", ROOFC, 4096, { { 0, 0, 0.42, 0.5, 0.96, 0.96 }, { 0, 0, 0.6, 0.68, 0.6, 0.6 } }),
		sub("Bronze", "Metal", BRONZE, 2700, { { 0, 0, 0.2, 0.38, 0.12, 0.12 }, { 0, 0, 0.68, 1, 0.03, 0.03 } }),
	} },
	Bell_Tower_Broken = { Size = { 29, 29.6, 29 }, Structure = true, Sink = 3, Subs = {
		sub("Stone", "Slate", STONE, 1584, { { 0, 0, 0, 0.5, 1, 1 }, { 0, 0, 0.5, 0.78, 0.62, 0.62 }, { -0.12, 0, 0.78, 1, 0.3, 0.5 } }, true),
		sub("Timber", "Wood", TIMBER, 176, { { 0, 0, 0.56, 0.62, 0.95, 0.12 } }),
		sub("Bronze", "Metal", BRONZE, 604, { { 0, 0, 0.28, 0.54, 0.3, 0.3 } }),
	} },
	Bell_Timber_Gate = { Size = { 19, 17.6, 3.2 }, Structure = true, Sink = 0.5, Subs = {
		sub("Timber", "Wood", TIMBER, 392, { { -0.4, 0, 0, 0.82, 0.13, 0.9 }, { 0.4, 0, 0, 0.82, 0.13, 0.9 }, { 0, 0, 0.82, 1, 1, 0.9 } }, true),
		sub("Stone", "Slate", STONE, 88, { { -0.4, 0, 0, 0.05, 0.22, 1 }, { 0.4, 0, 0, 0.05, 0.22, 1 } }),
		sub("Bronze", "Metal", BRONZE, 144, { { -0.4, 0, 0.82, 0.88, 0.2, 1 }, { 0.4, 0, 0.82, 0.88, 0.2, 1 } }),
	} },
	Bell_Lantern_Post = { Size = { 4.1, 10.6, 4.1 }, Structure = true, Sink = 0.5, Subs = {
		sub("Stone", "Slate", STONE, 232, { { 0, 0, 0, 0.5, 1, 1 } }, true),
		sub("Bronze", "Metal", BRONZE, 248, { { 0, 0, 0.5, 0.72, 0.4, 0.4 } }),
		sub("Glow", "Neon", GLOW, 44, { { 0, 0, 0.72, 1, 0.3, 0.3 } }),
	} },
	Bell_Stair_Segment = { Size = { 12.4, 11, 20.2 }, Structure = true, Sink = 1.0, Subs = {
		{ Name = "Stone", Material = "Slate", Color = STONE, Tris = 2200, B = {}, Collide = true, Lod = false, Shape = "Steps", Steps = 10, Rise = 1.05, Tread = 2, Width = 12 },
	} },
	Bell_Terrace_Wall = { Size = { 16, 9, 3.6 }, Structure = true, Sink = 0.5, Subs = {
		sub("Stone", "Slate", STONE, 1540, { { 0, 0, 0, 1, 1, 1 } }, true),
	} },
	Canopy_Tree_A = { Size = { 39.7, 44.2, 41.1 }, Trunk = 2.6, Sink = 0.8, Subs = {
		sub("Bark", "Wood", BARK, 1646, { { 0, 0, 0, 0.62, 0.1, 0.1 } }, false, false, "Cylinder"),
		sub("Leaves_Mass", "Grass", LEAF, 3456, { { 0, 0, 0.4, 0.82, 0.8, 0.8 }, { 0, 0, 0.82, 1, 0.5, 0.5 } }),
		sub("Leaves_Detail", "Grass", LEAF2, 9640, { { 0, 0, 0.6, 0.82, 1, 1 } }, false, true),
	} },
	Canopy_Tree_B = { Size = { 31.8, 58.6, 30.8 }, Trunk = 2.2, Sink = 0.8, Subs = {
		sub("Bark", "Wood", BARK, 1868, { { 0, 0, 0, 0.7, 0.08, 0.08 } }, false, false, "Cylinder"),
		sub("Leaves_Mass", "Grass", LEAF, 4896, { { 0, 0, 0.3, 0.88, 0.8, 0.8 }, { 0, 0, 0.88, 1, 0.5, 0.5 } }),
		sub("Leaves_Detail", "Grass", LEAF2, 12896, { { 0, 0, 0.5, 0.88, 1, 1 } }, false, true),
	} },
	-- Round 3 shrubs have no Leaves_Mass sub-mesh (manifest lod: cull the whole piece beyond ~120 studs).
	Understory_Shrub = { Size = { 9.3, 7.4, 7.7 }, Sink = 0.3, Subs = {
		sub("Stems", "Wood", BARK, 2304, { { 0, 0, 0, 0.35, 0.3, 0.3 } }),
		sub("Leaves", "Grass", LEAF, 3456, { { 0, 0, 0.2, 1, 1, 1 } }),
	} },
	Understory_Shrub_Small = { Size = { 4.1, 3.5, 4.6 }, Sink = 0.2, Subs = {
		sub("Stems", "Wood", BARK, 1332, { { 0, 0, 0, 0.35, 0.3, 0.3 } }),
		sub("Leaves", "Grass", LEAF2, 1904, { { 0, 0, 0.2, 1, 1, 1 } }),
	} },
	Fern_Clump = { Size = { 8.5, 3.2, 8.2 }, Sink = 0.2, Subs = { sub("Fronds", "Grass", FERN, 2016, { { 0, 0, 0, 1, 1, 1 } }) } },
	Grass_Clump = { Size = { 4.1, 3.4, 3.5 }, Sink = 0.1, DoubleSided = true, Subs = { sub("Blades", "Grass", GRASS, 220, { { 0, 0, 0, 1, 1, 1 } }) } },
	-- Rocks and the path stones (round 3). Boulder bases are flat and buried (z >= -1); C has a walkable top.
	Boulder_Granite_A = { Size = { 17.2, 7.8, 10.5 }, Sink = 1.0, Subs = { sub("Stone", "Rock", ROCKC, 8000, { { 0, 0, 0, 1, 1, 1 } }, false) } },
	Boulder_Granite_B = { Size = { 12.3, 10.6, 7.6 }, Sink = 1.0, Subs = { sub("Stone", "Rock", ROCKC, 7680, { { 0, 0, 0, 1, 1, 1 } }, false) } },
	Boulder_Granite_C = { Size = { 24.4, 4.1, 11.1 }, Sink = 0.6, Subs = { sub("Stone", "Rock", ROCKC, 6720, { { 0, 0, 0, 1, 1, 1 } }, false) } },
	Stepping_Stones = { Size = { 15.8, 2.2, 21.9 }, Structure = true, Sink = 0.2, Subs = { sub("Stone", "Slate", STONE, 6720, { { 0, 0, 0, 0.3, 1, 1 }, { -0.25, 0.25, 0, 1, 0.3, 0.3 }, { 0.25, -0.25, 0, 0.8, 0.25, 0.25 } }, true) } },
}

-------------------------------------------------------------------------------------------------
-- Placeholder specs for every other piece of the five upload manifests (slice, hero, bellwood_veg, bellwood_built_a, bellwood_built_b).
-- Data only: KIT rows are { piece, silhouette, X, Y up, Z, "Sub:tris ..." } copied from assets/source/overworld/upload/*/upload_manifest.json
-- (size_studs_xyz_roblox, sub_meshes), so the sub names match the registry keys (<Piece>__<Sub>) and a real-mesh swap stays a data change
-- (Assets / Registry resolution is untouched). RECIPES give each silhouette's boxes per sub name as fractions of the footprint and height
-- { cx, cz, y0, y1, w, d }; the union of a piece's boxes spans its manifest bounding box (test_slice_dressing checks +-5%).
-------------------------------------------------------------------------------------------------

local KIT: { any } = {
	{ "Ravine_Aqueduct_Arch", "aqueduct", 125, 82, 24, "Arches:348 Deck:180 Piers:216" },
	{ "Snow_Watch_Beacon", "beacon", 19.6, 101, 19.6, "Fire:38 Ice:328 Stone:104 Timber:128" },
	{ "Basin_Gate_Statue", "statue", 70, 139.0, 44, "Base:96 Body:124 Head:52" },
	{ "Summit_Temple_Pagoda", "hall", 61.8, 160.9, 65.6, "Bronze:624 Roof:160 Stone:132 Timber:300" },
	{ "Summit_Temple_Wing", "hall", 40, 60.2, 54.8, "Bronze:224 Roof:64 Stone:96 Timber:120" },
	{ "Canopy_Tree_C", "tree", 38.6, 49.6, 42.3, "Bark:1982 Leaves_Detail:12064 Leaves_Mass:4320" },
	{ "Canopy_Tree_D", "tree", 45.2, 37.3, 45.5, "Bark:1984 Leaves_Detail:12064 Leaves_Mass:4320" },
	{ "Conifer_Tall", "conifer", 26.9, 68.5, 29.5, "Bark:3828 Needles_Detail:7120 Needles_Mass:14112" },
	{ "Old_Gnarled_Tree", "gnarled", 35.1, 31.2, 28.7, "Bark:1482 Leaves_Detail:5136 Leaves_Mass:3456" },
	{ "Sapling_Tree", "sapling", 20.9, 16.9, 22.8, "Bark:724 Leaves_Detail:5064 Leaves_Mass:2016" },
	{ "Fallen_Log_A", "log", 30.3, 10.3, 16.3, "Bark:1220 Ends:14 Moss:640" },
	{ "Fallen_Log_B", "log", 17.9, 6.8, 6.2, "Bark:520 Ends:28 Moss:400" },
	{ "Tree_Stump_A", "stump", 18.2, 7.0, 17.9, "Bark:756 Ends:18 Moss:400" },
	{ "Tree_Stump_B", "stump", 14.8, 9.2, 13.8, "Bark:676 Ends:18 Moss:480" },
	{ "Dead_Standing_Trunk", "snag", 15.3, 39.5, 13.3, "Bark:794 Ends:14" },
	{ "Exposed_Roots_A", "roots", 21.4, 5.9, 21.2, "Bark:676 Moss:480" },
	{ "Exposed_Roots_B", "roots", 18.7, 5.1, 17.2, "Bark:914 Moss:400" },
	{ "Shrub_Hazel", "shrub", 12.1, 7.7, 9.4, "Leaves:2896 Stems:1980" },
	{ "Shrub_Thicket", "shrub", 14.6, 11.2, 13.6, "Leaves:4000 Stems:2844" },
	{ "Shrub_Berry", "shrub", 7.5, 4.6, 6.4, "Berries:2880 Leaves:2992 Stems:2124" },
	{ "Fern_Bracken", "plant", 11.7, 3.1, 13.0, "Fronds:1296" },
	{ "Fern_Sword", "plant", 10.6, 3.6, 10.9, "Fronds:3808" },
	{ "Flowers_Daisy", "plant", 6.5, 4.3, 7.3, "Blooms:2304 Stems:672" },
	{ "Flowers_Foxglove", "plant", 6.9, 5.5, 6.2, "Blooms:2064 Stems:276" },
	{ "Mushroom_Cluster", "plant", 8.1, 3.7, 7.3, "Caps:3360" },
	{ "Vine_Hanging", "drape", 14.7, 19.1, 9.6, "Bark:1386 Leaves:1888" },
	{ "Moss_Drape", "drape", 13.1, 19.1, 12.0, "Bark:230 Moss:330" },
	{ "Reed_Clump_A", "plant", 5.5, 7.0, 5.9, "Blades:414" },
	{ "Reed_Clump_B", "plant", 8.3, 9.7, 8.1, "Blades:270 Heads:608" },
	{ "Grass_Tall", "plant", 6.4, 4.9, 6.2, "Blades:490" },
	{ "Grass_Lush", "plant", 6.4, 2.3, 5.7, "Blades:450" },
	{ "Grass_Seed", "plant", 5.6, 5.4, 5.8, "Blades:336 Seeds:768" },
	{ "Bell_Stair_Straight_A", "stairs", 10.4, 8.7, 14.0, "Stone:7392" },
	{ "Bell_Stair_Straight_B", "stairs", 14.4, 8.3, 13.3, "Stone:5896" },
	{ "Bell_Stair_Turn", "stairs", 16.4, 9.2, 16.6, "Stone:8976" },
	{ "Bell_Retain_Wall_Short", "wall", 12.0, 7.5, 5.0, "Stone:5456" },
	{ "Bell_Retain_Wall_Long", "wall", 24.0, 8.0, 5.0, "Stone:3696 Stone2:6336" },
	{ "Bell_Retain_Wall_Corner", "corner", 10.7, 7.5, 10.7, "Stone:7392" },
	{ "Bell_Paving_Flag", "flat", 8.0, 1.4, 8.0, "Stone:2156" },
	{ "Bell_Paving_Sett", "flat", 8.1, 1.4, 8.0, "Stone:9388" },
	{ "Bell_Edging_Kerb", "flat", 1.3, 1.7, 7.9, "Stone:528" },
	{ "Bell_Edging_Cobble", "flat", 1.7, 1.6, 8.1, "Stone:1920" },
	{ "Boulder_Granite_D", "rock", 11.6, 8.2, 9.5, "Stone:8320" },
	{ "Boulder_Granite_Split", "rock", 13.2, 7.2, 8.9, "Stone:11520" },
	{ "Scree_Patch_A", "flat", 15.2, 1.0, 12.1, "Stone:7600" },
	{ "Scree_Patch_B", "flat", 17.6, 1.4, 12.6, "Stone:11600" },
	{ "Outcrop_Mossy", "rock", 19.5, 6.1, 10.2, "Stone:9600" },
	{ "Cliff_Face_A", "cliff", 16, 14.0, 4.8, "Stone:7146" },
	{ "Cliff_Face_B", "cliff", 16, 14.0, 4.9, "Stone:7146" },
	{ "Cliff_Face_C", "cliff", 16, 13.5, 6.8, "Stone:7146" },
	{ "Bell_Timber_Gate_Side", "gateside", 10, 10.5, 3.6, "Bronze:536 Stone:352 Timber:496" },
	{ "Bell_Fence_Rail", "rail", 8.8, 4.5, 1.0, "Timber:468" },
	{ "Bell_Fence_Picket", "picket", 8.6, 4.4, 1.1, "Timber:948" },
	{ "Bell_Fence_Post", "post", 2.6, 6.6, 2.3, "Bronze:484 Stone:352 Timber:84" },
	{ "Bell_Shrine_Roadside", "hall", 9.2, 9.9, 11.7, "Bronze:464 Roof:1088 Stone:1760 Timber:464" },
	{ "Bell_Grave_A", "grave", 5.3, 6.2, 4.0, "Bronze:424 Mound:320 Stone:660 Timber:88" },
	{ "Bell_Grave_B", "grave", 5.3, 4.2, 3.9, "Bronze:480 Mound:320 Stone:1456" },
	{ "Bell_Grave_C", "grave", 5.2, 6.1, 4.2, "Bronze:444 Mound:320 Stone:704" },
	{ "Bell_Prayer_Flags_Short", "flags", 12.2, 13.0, 2.2, "Cloth:288 Stone:352 Timber:302" },
	{ "Bell_Prayer_Flags_Long", "flags", 24.2, 13.0, 2.3, "Cloth:672 Stone:352 Timber:302" },
	{ "Bell_Signpost_A", "sign", 6.5, 9.4, 2.5, "Bronze:144 Stone:176 Timber:92" },
	{ "Bell_Signpost_B", "sign", 4.8, 5.5, 3.0, "Bronze:442 Stone:704 Timber:104" },
	{ "Bell_Well", "hall", 9.9, 12.5, 8.6, "Bronze:118 Roof:1088 Stone:11616 Timber:284" },
	{ "Bell_Tower_Ruined", "ruin", 53.8, 76.7, 52.9, "Bronze:944 Roof:88 Rubble:3432 Stone_A:11176 Stone_B:8536 Stone_Base:4488 Stone_Belfry:3344 Timber:484" },
	{ "Hermit_Hut", "hall", 20.0, 20.3, 19.6, "Bronze:272 Roof:2024 Stone:3652 Timber:6260" },
	{ "Rope_Bridge_Deck_A", "deck", 6.1, 4.4, 8.4, "Rope:696 Timber:484" },
	{ "Rope_Bridge_Deck_B", "deck", 6.1, 4.3, 8.4, "Rope:644 Timber:440" },
	{ "Rope_Bridge_Anchor", "anchor", 10.9, 14.7, 15.7, "Bronze:64 Rope:672 Stone:176 Timber:660" },
	{ "Falls_Alcove", "alcove", 46.0, 21.6, 22.1, "Rock_Back:15360 Rock_Lip:5440 Rock_Rim:3200 Rock_Sides:6400 Shrine_Stone:484 Shrine_Timber:44" },
	{ "Cart_A", "cart", 19.1, 7.1, 8.0, "Bronze:160 Cloth:386 Timber:2396" },
	{ "Cart_B", "cart", 23.8, 8.7, 12.1, "Bronze:456 Cloth:240 Timber:3434" },
	{ "Crate_A", "crate", 4.4, 4.4, 4.2, "Bronze:24 Timber:1080" },
	{ "Crate_B", "crate", 6, 5.8, 5.5, "Timber:792" },
	{ "Crate_C", "crate", 4.5, 5.7, 3.6, "Bronze:48 Timber:1168" },
	{ "Pot_A", "pot", 4.7, 4.5, 4.7, "Clay:720" },
	{ "Pot_B", "pot", 4.3, 6.2, 3.7, "Clay:880" },
	{ "Pot_C", "pot", 5.7, 4.9, 5.7, "Clay:976 Rope:136" },
	{ "Lantern_Hanging", "lantern", 4.3, 11.5, 5.0, "Bronze:524 Glow:28 Rope:70" },
	{ "Lantern_Stone", "lantern", 5.5, 10.0, 5.5, "Glow:44 Stone:432" },
}

local CYL, CYX = "Cylinder", "CylinderX" -- CylinderX lies along X (logs); Cylinder stands up (trunks)
local function rc(sink: number, solid: boolean, trunk: number?, subs: any): any
	return { Sink = sink, Solid = solid, Trunk = trunk, Subs = subs }
end
local function crown(under: number, fringe: number): (any, any) -- Leaves_Mass/_Mass boxes keep CrownFrac (0.8) of the footprint; the _Detail fringe is full width
	return { { 0, 0, under, 0.82, 0.8, 0.8 }, { 0, 0, 0.82, 1, 0.5, 0.5 } }, { { 0, 0, fringe, 0.82, 1, 1 } }
end
local function treeRecipe(sink: number, trunk: number, bark: number, under: number, fringe: number, needles: boolean?): any
	local mass, detail = crown(under, fringe)
	local m, d = if needles then "Needles_Mass" else "Leaves_Mass", if needles then "Needles_Detail" else "Leaves_Detail"
	return rc(sink, false, trunk, { Bark = { Shape = CYL, B = { { 0, 0, 0, 0.6, bark, bark } } }, [m] = { B = mass }, [d] = { B = detail } })
end
local FULL = { { 0, 0, 0, 1, 1, 1 } }
local HALL = { Stone = { B = { { 0, 0, 0, 0.1, 1, 1 } } },
	Timber = { B = { { -0.38, -0.38, 0.1, 0.55, 0.12, 0.12 }, { 0.38, -0.38, 0.1, 0.55, 0.12, 0.12 }, { -0.38, 0.38, 0.1, 0.55, 0.12, 0.12 }, { 0.38, 0.38, 0.1, 0.55, 0.12, 0.12 } } },
	Roof = { B = { { 0, 0, 0.55, 0.78, 1, 1 }, { 0, 0, 0.78, 1, 0.55, 0.55 } } }, Bronze = { B = { { 0, 0, 0.15, 0.4, 0.2, 0.2 } } } }
local RECIPES: { [string]: any } = {
	tree = treeRecipe(0.8, 0.07, 0.07, 0.35, 0.55), gnarled = treeRecipe(1, 0.14, 0.16, 0.3, 0.45), sapling = treeRecipe(0.5, 0.06, 0.07, 0.25, 0.4),
	conifer = rc(1, false, 0.1, { Bark = { Shape = CYL, B = { { 0, 0, 0, 0.8, 0.1, 0.1 } } },
		Needles_Mass = { B = { { 0, 0, 0.18, 0.45, 0.8, 0.8 }, { 0, 0, 0.45, 0.72, 0.6, 0.6 }, { 0, 0, 0.72, 1, 0.35, 0.35 } } }, Needles_Detail = { B = { { 0, 0, 0.2, 0.45, 1, 1 } } } }),
	log = rc(0.5, false, nil, { Bark = { Shape = CYX, B = FULL }, Ends = { B = { { 0.49, 0, 0.05, 0.95, 0.02, 0.9 } } }, Moss = { B = { { 0, 0, 0.6, 1, 0.5, 0.5 } } } }),
	stump = rc(0.5, false, nil, { Bark = { Shape = CYL, B = FULL }, Ends = { Shape = CYL, B = { { 0, 0, 0.95, 1, 0.9, 0.9 } } }, Moss = { B = { { 0.3, 0.3, 0, 0.5, 0.35, 0.35 } } } }),
	snag = rc(1, false, nil, { Bark = { Shape = CYL, B = { { 0, 0, 0, 0.6, 1, 1 }, { 0, 0, 0.6, 0.85, 0.6, 0.6 } } }, Ends = { Shape = CYL, B = { { -0.1, 0.1, 0.85, 1, 0.3, 0.3 } } } }),
	roots = rc(0.4, false, nil, { Bark = { B = { { 0, 0, 0, 0.5, 1, 0.3 }, { 0, 0, 0, 0.5, 0.3, 1 }, { 0, 0, 0.3, 1, 0.35, 0.35 } } }, Moss = { B = { { 0, 0, 0.5, 0.7, 0.5, 0.5 } } } }),
	shrub = rc(0.3, false, nil, { Stems = { Shape = CYL, B = { { 0, 0, 0, 0.4, 0.3, 0.3 } } }, Leaves = { B = { { 0, 0, 0.2, 0.75, 1, 1 }, { 0, 0, 0.75, 1, 0.6, 0.6 } } },
		Berries = { B = { { 0.2, 0.2, 0.45, 0.7, 0.5, 0.5 } } } }),
	plant = rc(0.15, false, nil, { Fronds = { B = FULL }, Blades = { B = FULL }, Caps = { B = FULL }, Stems = { B = { { 0, 0, 0, 0.7, 0.35, 0.35 } } },
		Blooms = { B = { { 0, 0, 0.5, 1, 1, 1 } } }, Heads = { B = { { 0, 0, 0.7, 1, 0.8, 0.8 } } }, Seeds = { B = { { 0, 0, 0.65, 1, 0.9, 0.9 } } } }),
	drape = rc(0, false, nil, { Bark = { B = { { -0.4, 0, 0, 1, 0.12, 0.4 } } }, Leaves = { B = { { 0, 0, 0, 0.9, 1, 1 } } }, Moss = { B = { { 0, 0, 0, 0.9, 1, 1 } } } }),
	stairs = rc(0.3, true, nil, {}),
	wall = rc(0.5, true, nil, { Stone = { B = { { 0, 0, 0, 0.7, 1, 1 }, { 0, -0.1, 0.7, 1, 0.95, 0.7 } } }, Stone2 = { B = { { 0, 0, 0.9, 1, 0.9, 0.9 } } } }),
	corner = rc(0.5, true, nil, { Stone = { B = { { -0.25, 0, 0, 1, 0.5, 1 }, { 0.25, -0.25, 0, 1, 0.5, 0.5 } } } }),
	flat = rc(0.15, false, nil, { Stone = { B = FULL } }),
	rock = rc(1, false, nil, { Stone = { B = { { 0, 0, 0, 0.7, 1, 1 }, { 0.05, 0, 0.7, 1, 0.6, 0.7 } } } }),
	cliff = rc(1, false, nil, { Stone = { B = { { 0, 0, 0, 0.6, 1, 1 }, { 0, -0.1, 0.6, 1, 0.9, 0.7 } } } }),
	gateside = rc(0.5, true, nil, { Timber = { B = { { -0.4, 0, 0, 0.85, 0.2, 0.9 }, { 0.4, 0, 0, 0.85, 0.2, 0.9 }, { 0, 0, 0.8, 1, 1, 0.9 } } },
		Stone = { B = { { -0.4, 0, 0, 0.12, 0.2, 1 }, { 0.4, 0, 0, 0.12, 0.2, 1 } } }, Bronze = { B = { { 0, 0, 0.72, 0.8, 1, 0.3 } } } }),
	rail = rc(0.2, true, nil, { Timber = { B = { { 0, 0, 0, 0.3, 1, 1 }, { 0, 0, 0.6, 1, 1, 1 } } } }),
	picket = rc(0.2, true, nil, { Timber = { B = { { -0.4, 0, 0, 1, 0.2, 1 }, { 0, 0, 0, 0.9, 0.2, 1 }, { 0.4, 0, 0, 1, 0.2, 1 } } } }),
	post = rc(0.3, true, nil, { Stone = { B = { { 0, 0, 0, 0.3, 1, 1 } } }, Timber = { B = { { 0, 0, 0.3, 0.85, 0.6, 0.6 } } }, Bronze = { B = { { 0, 0, 0.85, 1, 0.7, 0.7 } } } }),
	hall = rc(1, true, nil, HALL),
	grave = rc(0.2, true, nil, { Mound = { B = { { 0, 0, 0, 0.25, 1, 1 } } }, Stone = { B = { { 0, 0.1, 0.2, 1, 0.5, 0.25 } } },
		Timber = { B = { { 0.3, 0.3, 0.2, 0.8, 0.1, 0.1 } } }, Bronze = { B = { { -0.3, 0, 0.2, 0.45, 0.2, 0.2 } } } }),
	flags = rc(0.3, true, nil, { Cloth = { B = { { 0, 0, 0.55, 0.95, 0.96, 0.1 } } }, Stone = { B = { { -0.45, 0, 0, 0.2, 0.1, 1 }, { 0.45, 0, 0, 0.2, 0.1, 1 } } },
		Timber = { B = { { -0.48, 0, 0, 1, 0.04, 0.2 }, { 0.48, 0, 0, 1, 0.04, 0.2 } } } }),
	sign = rc(0.3, true, nil, { Stone = { B = { { 0, 0, 0, 0.2, 0.6, 1 } } }, Timber = { B = { { 0, 0, 0.2, 1, 0.15, 0.2 }, { 0, 0, 0.65, 0.9, 1, 0.15 } } },
		Bronze = { B = { { 0.3, 0, 0.9, 1, 0.2, 0.2 } } } }),
	cart = rc(0.2, true, nil, { Timber = { B = { { 0, 0, 0.25, 0.55, 1, 0.8 } } }, Bronze = { B = { { 0.3, 0, 0, 0.45, 0.2, 1 }, { -0.3, 0, 0, 0.45, 0.2, 1 } } },
		Cloth = { B = { { 0, 0, 0.55, 1, 0.7, 0.6 } } } }),
	crate = rc(0.1, true, nil, { Timber = { B = FULL }, Bronze = { B = { { 0, 0, 0.4, 0.6, 0.98, 0.98 } } } }),
	pot = rc(0.1, true, nil, { Clay = { B = { { 0, 0, 0, 0.7, 1, 1 }, { 0, 0, 0.7, 1, 0.6, 0.6 } } }, Rope = { B = { { 0, 0, 0.5, 0.6, 0.98, 0.98 } } } }),
	lantern = rc(0.2, true, nil, { Bronze = { B = { { 0, 0, 0, 0.5, 1, 1 } } }, Stone = { B = { { 0, 0, 0, 0.55, 1, 1 }, { 0, 0, 0.55, 0.8, 0.5, 0.5 } } },
		Glow = { B = { { 0, 0, 0.5, 1, 0.6, 0.6 } } }, Rope = { B = { { 0, 0, 0.8, 1, 0.1, 0.1 } } } }),
	deck = rc(0.2, true, nil, { Timber = { B = { { 0, 0, 0, 0.6, 1, 1 } } }, Rope = { B = { { -0.48, 0, 0.3, 1, 0.04, 1 }, { 0.48, 0, 0.3, 1, 0.04, 1 } } } }),
	anchor = rc(0.5, true, nil, { Stone = { B = { { 0, 0, 0, 0.4, 1, 1 } } }, Timber = { B = { { 0, 0, 0.4, 1, 0.2, 0.3 } } }, Bronze = { B = { { 0, 0, 0.5, 0.7, 0.3, 0.3 } } },
		Rope = { B = { { 0, -0.3, 0.7, 0.8, 0.1, 0.3 } } } }),
	alcove = rc(1, false, nil, { Rock_Back = { B = { { 0, 0.4, 0, 1, 1, 0.2 } } }, Rock_Sides = { B = { { -0.45, 0, 0, 0.9, 0.1, 1 }, { 0.45, 0, 0, 0.9, 0.1, 1 } } },
		Rock_Rim = { B = { { 0, 0.1, 0.9, 1, 1, 0.8 } } }, Rock_Lip = { B = { { 0, -0.4, 0, 0.15, 1, 0.2 } } }, Shrine_Stone = { B = { { 0, 0.1, 0, 0.3, 0.2, 0.3 } } },
		Shrine_Timber = { B = { { 0, 0.1, 0.3, 0.6, 0.1, 0.1 } } } }),
	-- the ruined bell tower: wide plinth, tapered column, broken belfry that rises on one side only
	ruin = rc(2.5, true, nil, { Stone_Base = { B = { { 0, 0, 0, 0.22, 1, 1 } } }, Stone_A = { B = { { 0, 0, 0.22, 0.6, 0.7, 0.7 } } }, Stone_B = { B = { { 0, 0, 0.6, 0.8, 0.55, 0.55 } } },
		Stone_Belfry = { B = { { -0.1, -0.05, 0.8, 1, 0.3, 0.3 } } }, Roof = { B = { { 0.12, 0.1, 0.78, 0.88, 0.2, 0.25 } } }, Timber = { B = { { 0, 0, 0.55, 0.8, 0.08, 0.08 } } },
		Bronze = { B = { { 0, 0, 0.62, 0.75, 0.15, 0.15 } } }, Rubble = { B = { { 0.3, 0.3, 0.22, 0.3, 0.3, 0.3 }, { -0.3, -0.25, 0.22, 0.28, 0.3, 0.3 } } } }),
	aqueduct = rc(1, true, nil, { Piers = { B = { { -0.4, 0, 0, 0.8, 0.1, 1 }, { 0, 0, 0, 0.8, 0.1, 1 }, { 0.4, 0, 0, 0.8, 0.1, 1 } } },
		Arches = { B = { { -0.2, 0, 0.5, 0.8, 0.3, 0.7 }, { 0.2, 0, 0.5, 0.8, 0.3, 0.7 } } }, Deck = { B = { { 0, 0, 0.8, 1, 1, 1 } } } }),
	beacon = rc(1, true, nil, { Stone = { B = { { 0, 0, 0, 0.5, 1, 1 }, { 0, 0, 0.5, 0.8, 0.5, 0.5 } } }, Ice = { B = { { 0, 0, 0.55, 0.8, 0.55, 0.55 } } },
		Timber = { B = { { 0, 0, 0.8, 0.9, 0.7, 0.7 } } }, Fire = { B = { { 0, 0, 0.9, 1, 0.4, 0.4 } } } }),
	statue = rc(1, true, nil, { Base = { B = { { 0, 0, 0, 0.2, 1, 1 } } }, Body = { B = { { 0, 0, 0.2, 0.75, 0.6, 0.6 } } }, Head = { B = { { 0, 0, 0.75, 1, 0.3, 0.3 } } } }),
}
-- Sub material and colour by the sub name's first word; Solid recipes collide only on these.
local LOOKS: { [string]: { any } } = {
	Bark = { "Wood", BARK }, Stems = { "Wood", BARK }, Leaves = { "Grass", LEAF }, Needles = { "Grass", { 46, 84, 58 } }, Fronds = { "Grass", FERN }, Blades = { "Grass", GRASS },
	Caps = { "Fabric", { 176, 120, 84 } }, Blooms = { "Grass", { 206, 128, 176 } }, Seeds = { "Grass", { 160, 140, 84 } }, Heads = { "Grass", { 160, 140, 84 } },
	Berries = { "Grass", { 170, 44, 64 } }, Moss = { "Grass", { 72, 104, 52 } }, Ends = { "Wood", { 170, 140, 100 } }, Stone = { "Slate", STONE }, Rock = { "Rock", ROCKC },
	Shrine = { "Slate", STONE }, Timber = { "Wood", TIMBER }, Roof = { "Slate", ROOFC }, Bronze = { "Metal", BRONZE }, Glow = { "Neon", GLOW }, Cloth = { "Fabric", { 190, 60, 50 } },
	Rope = { "Fabric", { 150, 125, 85 } }, Clay = { "Concrete", { 150, 98, 70 } }, Rubble = { "Slate", { 90, 86, 80 } }, Mound = { "Ground", { 90, 70, 52 } },
	Arches = { "Slate", STONE }, Piers = { "Slate", STONE }, Deck = { "Slate", STONE }, Base = { "Slate", STONE }, Body = { "Slate", STONE }, Head = { "Slate", STONE },
	Fire = { "Neon", { 255, 140, 60 } }, Ice = { "Ice", { 190, 225, 240 } },
}
local SOLID: { [string]: boolean } = { Stone = true, Rock = true, Shrine = true, Timber = true, Rubble = true, Arches = true, Piers = true, Deck = true, Base = true, Body = true, Head = true, Clay = true, Mound = true }

for _, row in KIT do
	local name, arch, X, Y, Z, subs = row[1], row[2], row[3], row[4], row[5], row[6]
	local rec = RECIPES[arch]
	assert(rec, "SliceDressing kit: no recipe " .. tostring(arch))
	local list = {}
	for subName, tris in string.gmatch(subs, "(%S+):(%d+)") do
		local key = string.match(subName, "^[^_%d]+") :: string
		local look = LOOKS[subName] or LOOKS[key]
		assert(look, "SliceDressing kit: no look for " .. subName)
		local solid = rec.Solid and SOLID[key] == true
		if arch == "stairs" then -- n step blocks climbing local -Z; the union is exactly Size
			local n = math.max(4, math.floor(Y + 0.5))
			table.insert(list, { Name = subName, Material = look[1], Color = look[2], Tris = tonumber(tris), B = {}, Collide = true, Lod = false, Shape = "Steps", Steps = n, Rise = Y / n, Tread = Z / n, Width = X })
		else
			local def = rec.Subs[subName]
			assert(def, "SliceDressing kit: " .. name .. " has no box recipe for " .. subName)
			table.insert(list, sub(subName, look[1], look[2], tonumber(tris) :: number, def.B, solid, string.find(subName, "_Detail$") ~= nil, def.Shape))
		end
	end
	SliceDressing.Pieces[name] = { Size = { X, Y, Z }, Structure = if rec.Solid then true else nil, Sink = rec.Sink, Trunk = if rec.Trunk then rec.Trunk * math.max(X, Z) else nil, Subs = list, Kit = true }
end

-- Near/far (lane D6): beyond FarSwitch studs from every capture eye and road centreline a tree stands as <Piece>_Far, the low-tri variant lane M8 builds
-- (pack assets/source/overworld/upload/bellwood_far/: same bbox, about 10-15% of the tris). The pack did not exist when this was written, so every _Far spec is an
-- ESTIMATE (Estimate = true): the near piece's sub names, boxes and bbox with Tris = FarTrisFraction of each near sub. Replace the fraction by the pack manifest numbers on arrival;
-- the registry keys are <Piece>_Far__<Sub> and a missing key leaves the placeholder, exactly like a near piece.
SliceDressing.FarSwitch = 140
SliceDressing.FarTrisFraction = 0.12
SliceDressing.FarPieces = { "Canopy_Tree_A", "Canopy_Tree_B", "Canopy_Tree_C", "Canopy_Tree_D", "Conifer_Tall", "Old_Gnarled_Tree" }
for _, name in SliceDressing.FarPieces do
	local nearSpec = SliceDressing.Pieces[name]
	local subs = {}
	for _, sb in nearSpec.Subs do
		local c = table.clone(sb)
		c.Tris = math.max(1, math.floor(sb.Tris * SliceDressing.FarTrisFraction + 0.5))
		if string.find(sb.Name, "_Mass$") and #sb.B == 2 then -- the far placeholder merges the crown and its cap into one box (same height and footprint)
			c.B = { { 0, 0, sb.B[1][3], sb.B[2][4], sb.B[1][5], sb.B[1][6] } }
		end
		table.insert(subs, c)
	end
	SliceDressing.Pieces[name .. "_Far"] = { Size = nearSpec.Size, Structure = nearSpec.Structure, Sink = nearSpec.Sink, Trunk = nearSpec.Trunk, Subs = subs, Kit = true, Far = true, FarOf = name, Estimate = true }
end

-- The union of a piece's placeholder boxes (and step blocks) as { x, y, z } extents in studs; equals Size within the recipe's fractions.
function SliceDressing.specBounds(name: string): { number }
	local p = SliceDressing.Pieces[name]
	local X, Y, Z = p.Size[1], p.Size[2], p.Size[3]
	local x0, x1, y0, y1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, sb in p.Subs do
		if sb.Shape == "Steps" then
			x0, x1 = math.min(x0, -sb.Width / 2), math.max(x1, sb.Width / 2)
			y0, y1 = math.min(y0, 0), math.max(y1, sb.Rise * sb.Steps)
			z0, z1 = math.min(z0, Z / 2 - sb.Tread * sb.Steps), math.max(z1, Z / 2)
		else
			for _, b in sb.B do
				x0, x1 = math.min(x0, (b[1] - b[5] / 2) * X), math.max(x1, (b[1] + b[5] / 2) * X)
				y0, y1 = math.min(y0, b[3] * Y), math.max(y1, b[4] * Y)
				z0, z1 = math.min(z0, (b[2] - b[6] / 2) * Z), math.max(z1, (b[2] + b[6] / 2) * Z)
			end
		end
	end
	return { x1 - x0, y1 - y0, z1 - z0 }
end

-- Radius (footprint half-diagonal; crown radius for trees) and placeholder part count, derived once.
for _, p in SliceDressing.Pieces do
	local s = p.Size
	p.Radius = if p.Trunk then 0.5 * math.max(s[1], s[3]) else 0.5 * math.sqrt(s[1] ^ 2 + s[3] ^ 2)
	p.Trunk = p.Trunk or p.Radius
	local n, tris, near = 0, 0, 0
	for _, sb in p.Subs do
		if string.find(sb.Name, "_Mass$") then -- canopy underside (fraction of height) and crown radius of a tree
			p.Under, p.Crown = sb.B[1][3], sb.B[1][5] * 0.5 * math.max(s[1], s[3])
		end
		n += if sb.Shape == "Steps" then sb.Steps else #sb.B
		tris += sb.Tris
		near += if sb.Lod then 0 else sb.Tris
	end
	p.PlaceholderParts, p.Tris, p.TrisLod, p.MeshParts = n, tris, near, #p.Subs
	-- Occluders { radius, y0, y1 } at scale 1, y from the foot: a tree is a trunk below the canopy underside and the canopy's bounding circle above it; anything else its bounding circle.
	local half = 0.5 * math.sqrt(s[1] ^ 2 + s[3] ^ 2)
	if p.Under then
		p.Occ = { { 0.5 * p.Trunk, -p.Sink, p.Under * s[2] - p.Sink }, { half, p.Under * s[2] - p.Sink, s[2] - p.Sink } }
	else
		p.Occ = { { half, -p.Sink, s[2] - p.Sink } }
	end
end

-------------------------------------------------------------------------------------------------
-- Hero placements (hand-placed). X, Z, Yaw authored (Yaw degrees; a piece's front is local +Z for the pavilion, local -Z is
-- the stair's climb; the lead confirms against the import and fixes it in one place, ImportYaw below). Arc = studs along the
-- main road from the glade, Off = sideways (+ = right when walking glade -> terrace). Foot = local (lx, lz) where the ground is
-- sampled for Y (the stair stands on its low end). Landmark = Persistent (far silhouette); the rest stream with their cell.
-------------------------------------------------------------------------------------------------

SliceDressing.ImportYaw = {} :: { [string]: number } -- piece -> yaw added at build (0 until the Studio import says otherwise)

SliceDressing.Route = { From = "Altar_MonasteryGate", To = "Altar_BellTerrace" }
-- Scatter lives within Half of the route plus a Fade band, and inside a disc round each altar (the two clearings).
SliceDressing.Corridor = { Half = 100, Fade = 40, Discs = { { Altar = "Altar_MonasteryGate", R = 170 }, { Altar = "Altar_BellTerrace", R = 140 } } }
-- Trees keep clear of the lines from the route (the last Reach studs) to the pavilion; HalfWidth studs either side.
SliceDressing.Lane = { To = "Pavilion", Reach = 360, HalfWidth = 12 }

local function arcHero(id: string, piece: string, arc: number, off: number, face: string?): any
	return { Id = id, Piece = piece, Arc = arc, Off = off, Face = face or "Road" }
end

SliceDressing.Hero = {
	{ Id = "Pavilion", Piece = "Bell_Terrace_Pavilion", X = -3020, Z = -1900, Yaw = 180, Scale = 1, Landmark = true },
	-- Raise: the scale grows from Scale (steps of 0.1, to Max) until the line from From (arrival, eye at Eye) to the tower top clears the terrain
	-- by Margin: heightAt-derived at build, so a reshaped Bellwood relief never hides the tower (fault C). Placeholder height; the mesh keeps its shape.
	{ Id = "TowerMid", Piece = "Bell_Tower_Ruined", X = -2667, Z = -1588, Yaw = 20, Scale = 1, Landmark = true,
		Raise = { From = { X = -2203, Z = -1415 }, Max = 1.7, Margin = 2.5 } },
	-- Terrace stair: the plateau (140) falls to the court (132) across z -1975..-1945 at x -3000. Pivot mid-run, ground sampled at the low (south) end.
	{ Id = "TerraceStair", Piece = "Bell_Stair_Segment", X = -3000, Z = -1960, Yaw = 0, Scale = 1, Foot = { 0, 10 } },
	{ Id = "TerraceWall_W1", Piece = "Bell_Terrace_Wall", X = -3014.5, Z = -1953, Yaw = 0, Scale = 1 },
	{ Id = "TerraceWall_W2", Piece = "Bell_Terrace_Wall", X = -3030.5, Z = -1953, Yaw = 0, Scale = 1 },
	{ Id = "TerraceWall_W3", Piece = "Bell_Terrace_Wall", X = -3046.5, Z = -1953, Yaw = 0, Scale = 1 },
	{ Id = "TerraceWall_E1", Piece = "Bell_Terrace_Wall", X = -2985.5, Z = -1953, Yaw = 0, Scale = 1 },
	{ Id = "TerraceWall_E2", Piece = "Bell_Terrace_Wall", X = -2969.5, Z = -1953, Yaw = 0, Scale = 1 },
	{ Id = "TerraceWall_E3", Piece = "Bell_Terrace_Wall", X = -2953.5, Z = -1953, Yaw = 0, Scale = 1 },
	-- Court path: stair foot to the pavilion's own stair (the pavilion plinth edge is z -1933).
	{ Id = "CourtStones", Piece = "Stepping_Stones", X = -3010, Z = -1942, Yaw = 0, Scale = 1 },
	arcHero("GateGlade", "Bell_Timber_Gate", 95, 0),
	arcHero("GateTerrace", "Bell_Timber_Gate", 1000, 0),
	-- Lantern posts: pairs through the glade and the terrace approach, single posts in the wild middle.
	arcHero("Lantern_040R", "Bell_Lantern_Post", 40, 11),
	arcHero("Lantern_125L", "Bell_Lantern_Post", 125, -11), arcHero("Lantern_125R", "Bell_Lantern_Post", 125, 11),
	arcHero("Lantern_210L", "Bell_Lantern_Post", 210, -11), arcHero("Lantern_210R", "Bell_Lantern_Post", 210, 11),
	arcHero("Lantern_295L", "Bell_Lantern_Post", 295, -11), arcHero("Lantern_295R", "Bell_Lantern_Post", 295, 11),
	arcHero("Lantern_400R", "Bell_Lantern_Post", 400, 11), arcHero("Lantern_520L", "Bell_Lantern_Post", 520, -11),
	arcHero("Lantern_640R", "Bell_Lantern_Post", 640, 11), arcHero("Lantern_760L", "Bell_Lantern_Post", 760, -11),
	arcHero("Lantern_880R", "Bell_Lantern_Post", 880, 11),
	arcHero("Lantern_960L", "Bell_Lantern_Post", 960, -11), arcHero("Lantern_960R", "Bell_Lantern_Post", 960, 11),
	arcHero("Lantern_1040L", "Bell_Lantern_Post", 1040, -11), arcHero("Lantern_1040R", "Bell_Lantern_Post", 1040, 11),
}

-------------------------------------------------------------------------------------------------
-- Composed set pieces: the built kit (bellwood_built_a / _b) arranged round an anchor. Items = { piece, lx, lz, dyaw, scale?, path? }; the frame is
-- local +Z = forward, local +X = right: forward is the nearest road's direction at the anchor (an altar, encounter, miniboss or cache), the line
-- to the route for a Hero anchor (its offsets grow with the hero's scale), or At.Yaw degrees. dyaw turns the piece; path = may stand on a road.
-- The builder drops an item that would stand in water or a chasm, on a road, inside an altar pad, or in a kept sight (SetStats counts them).
-------------------------------------------------------------------------------------------------
SliceDressing.Sets = {
	{ Id = "GladeAltar", At = { Altar = "Altar_MonasteryGate", Scale = 1.4 }, -- Scale pushes the kit past the forest-floor ring (24..34)
		Items = { -- the arrival: wayside shrine, yard fence, cart and stores, well, signs
		{ "Bell_Shrine_Roadside", -31, -6, 90 }, { "Bell_Paving_Flag", -31, 8, 0 }, { "Bell_Paving_Flag", -31, 16, 0 }, { "Bell_Signpost_A", 21, 26, 180 }, { "Bell_Signpost_B", -17, 34, 180 },
		{ "Lantern_Stone", -27, -16, 0 }, { "Lantern_Stone", 27, -16, 0 }, { "Lantern_Stone", -27, 16, 0 }, { "Lantern_Stone", 27, 14, 0 },
		{ "Cart_A", 35, -8, 20 }, { "Crate_A", 39, -15, 10 }, { "Crate_B", 31, -17, 70 }, { "Crate_C", 41, -3, 0 }, { "Pot_A", 37, 4, 0 }, { "Pot_B", 29, -23, 0 }, { "Pot_C", 33, 8, 0 },
		{ "Bell_Well", -32, -30, 0 }, { "Bell_Fence_Post", -18, -36, 0 }, { "Bell_Fence_Post", -9, -36, 0 }, { "Bell_Fence_Post", 0, -36, 0 }, { "Bell_Fence_Post", 9, -36, 0 }, { "Bell_Fence_Post", 18, -36, 0 },
		{ "Bell_Fence_Rail", -13.5, -36, 0 }, { "Bell_Fence_Rail", -4.5, -36, 0 }, { "Bell_Fence_Rail", 4.5, -36, 0 }, { "Bell_Fence_Rail", 13.5, -36, 0 },
		{ "Bell_Prayer_Flags_Long", 0, -44, 0 }, { "Bell_Prayer_Flags_Short", -38, 22, 90 }, { "Bell_Edging_Kerb", -11, 30, 0, nil, true }, { "Bell_Edging_Kerb", 11, 30, 0, nil, true },
		{ "Bell_Edging_Kerb", -11, 38, 0, nil, true }, { "Bell_Edging_Kerb", 11, 38, 0, nil, true } } },
	{ Id = "TowerYard", At = { Hero = "TowerMid" }, Items = { -- Bell_Tower_Ruined: graves and fence behind, cliff backdrop, cobbled approach, lanterns, flags
		{ "Bell_Paving_Flag", 0, 46, 0, nil, true }, { "Bell_Paving_Flag", 0, 54, 0, nil, true }, { "Bell_Edging_Cobble", -6, 46, 0, nil, true }, { "Bell_Edging_Cobble", 6, 46, 0, nil, true },
		{ "Bell_Edging_Cobble", -6, 54, 0, nil, true }, { "Bell_Edging_Cobble", 6, 54, 0, nil, true }, { "Lantern_Stone", -14, 48, 0 }, { "Lantern_Stone", 14, 48, 0 }, { "Bell_Signpost_A", 22, 50, 180 },
		{ "Bell_Grave_A", -46, -14, 0 }, { "Bell_Grave_B", -52, -22, 20 }, { "Bell_Grave_C", -44, -30, -15 }, { "Bell_Fence_Rail", -58, -14, 90 }, { "Bell_Fence_Rail", -58, -26, 90 },
		{ "Bell_Fence_Post", -58, -20, 0 }, { "Bell_Fence_Post", -58, -8, 0 }, { "Bell_Prayer_Flags_Long", 34, -34, 0 }, { "Bell_Retain_Wall_Long", 24, -48, 180 }, { "Bell_Retain_Wall_Long", -2, -48, 180 },
		{ "Bell_Retain_Wall_Corner", -18, -48, 180 }, { "Cliff_Face_A", -16, -62, 180 }, { "Cliff_Face_B", 2, -62, 180 }, { "Cliff_Face_C", 20, -62, 180 }, { "Scree_Patch_A", -34, 34, 0 }, { "Scree_Patch_B", 38, 30, 30 },
		{ "Moss_Drape", -34, 8, 0 }, { "Vine_Hanging", 36, 10, 0 }, { "Crate_C", 50, 14, 0 }, { "Pot_C", 52, 20, 0 }, { "Outcrop_Mossy", -50, 40, 20 } } },
	{ Id = "TerraceCourt", At = { Altar = "Altar_BellTerrace", Yaw = 0 }, Items = { -- the plateau round the terrace altar (roads leave to the east and north: the kit sits west and south)
		{ "Bell_Paving_Sett", -12, 29, 0 }, { "Bell_Paving_Sett", -4, 29, 0 }, { "Bell_Paving_Sett", 4, 29, 0 }, { "Bell_Paving_Sett", 12, 29, 0 },
		{ "Bell_Stair_Straight_A", 38, 14, -90 }, { "Bell_Stair_Turn", 62, 14, -90 }, { "Bell_Retain_Wall_Long", 70, -24, 90 }, { "Bell_Retain_Wall_Long", 70, -48, 90 }, { "Bell_Retain_Wall_Long", 70, 0, 90 },
		{ "Bell_Retain_Wall_Corner", 70, -62, 90 }, { "Bell_Retain_Wall_Short", 56, -62, 0 }, { "Cliff_Face_A", 86, -24, 90 }, { "Cliff_Face_B", 86, 0, 90 }, { "Cliff_Face_C", 86, 24, 90 },
		{ "Lantern_Stone", 30, -12, 0 }, { "Lantern_Stone", -30, -12, 0 }, { "Lantern_Stone", 30, 12, 0 }, { "Lantern_Stone", -30, 12, 0 },
		{ "Bell_Timber_Gate_Side", -13, 37, 0 }, { "Bell_Timber_Gate_Side", 13, 37, 0 }, { "Lantern_Hanging", -17, 26, 0 }, { "Lantern_Hanging", 17, 26, 0 }, { "Bell_Prayer_Flags_Long", 50, -40, 90 },
		{ "Bell_Signpost_B", 20, 30, 180 }, { "Bell_Well", -40, -10, 0 }, { "Bell_Fence_Rail", 48, -9, 90 }, { "Bell_Fence_Rail", 48, 0, 90 }, { "Bell_Fence_Rail", 48, 9, 90 },
		{ "Bell_Fence_Post", 48, -13.5, 0 }, { "Bell_Fence_Post", 48, -4.5, 0 }, { "Bell_Fence_Post", 48, 4.5, 0 }, { "Bell_Fence_Post", 48, 13.5, 0 } } },
	{ Id = "WardenGraves", At = { Miniboss = "HollowBellWarden" }, Items = { -- the Hollow Bell Warden's graveyard
		{ "Bell_Grave_A", -12, 0, 0 }, { "Bell_Grave_B", -16, 10, 20 }, { "Bell_Grave_C", -10, -12, -10 }, { "Bell_Grave_A", 12, 2, 10 }, { "Bell_Grave_B", 16, -10, 0 }, { "Bell_Grave_C", 8, 14, 30 },
		{ "Bell_Fence_Post", -24, -16, 0 }, { "Bell_Fence_Post", 24, -16, 0 }, { "Bell_Fence_Post", -24, 20, 0 }, { "Bell_Fence_Post", 24, 20, 0 }, { "Lantern_Stone", -20, 18, 0 }, { "Lantern_Stone", 20, 18, 0 },
		{ "Pot_A", -6, 8, 0 }, { "Pot_B", 4, -6, 0 }, { "Bell_Shrine_Roadside", 0, -28, 180 }, { "Bell_Prayer_Flags_Short", -26, 0, 90 }, { "Bell_Prayer_Flags_Short", 26, 0, 90 } } },
	{ Id = "WaysideShrine", At = { Encounter = 1 }, Items = { -- the first foe on the road: shrine, a wrecked cart and its stores
		{ "Bell_Shrine_Roadside", 24, 4, -90 }, { "Cart_B", -22, 8, 30 }, { "Crate_A", -28, -4, 0 }, { "Crate_B", -16, -6, 50 }, { "Crate_C", -30, 16, 0 }, { "Pot_A", 26, -12, 0 }, { "Pot_B", 30, 12, 0 },
		{ "Lantern_Stone", 14, -14, 0 }, { "Lantern_Stone", -14, 16, 0 }, { "Bell_Signpost_B", 14, -26, 180 }, { "Bell_Fence_Post", 18, 18, 0 }, { "Bell_Fence_Post", 27, 18, 0 }, { "Bell_Fence_Rail", 22.5, 18, 0 } } },
	{ Id = "HermitCamp", At = { Encounter = 2 }, Items = { -- the swordsman's camp: hermit hut, cart, well, flags
		{ "Hermit_Hut", 38, 8, -90 }, { "Cart_A", -26, 6, 70 }, { "Crate_A", -30, -6, 0 }, { "Crate_B", -22, -12, 40 }, { "Pot_C", 24, -18, 0 }, { "Bell_Well", 28, -34, 0 }, { "Bell_Fence_Rail", -20, 26, 0 },
		{ "Bell_Fence_Rail", -11, 26, 0 }, { "Bell_Fence_Post", -24.5, 26, 0 }, { "Bell_Fence_Post", -15.5, 26, 0 }, { "Bell_Fence_Post", -6.5, 32, 0 }, { "Bell_Prayer_Flags_Short", -30, 26, 90 },
		{ "Lantern_Hanging", 16, 14, 0 }, { "Lantern_Stone", -14, -22, 0 } } },
	{ Id = "BrokenCrossing", At = { Encounter = 14 }, Items = { -- a broken rope bridge across the old side road
		{ "Rope_Bridge_Anchor", -16, 14, 90 }, { "Rope_Bridge_Deck_A", -6, 14, 90, nil, true }, { "Rope_Bridge_Deck_B", 2, 14, 90, nil, true }, { "Rope_Bridge_Anchor", 20, 14, -90 }, { "Bell_Signpost_A", 12, -16, 180 },
		{ "Lantern_Stone", -14, -10, 0 }, { "Lantern_Stone", 14, -10, 0 }, { "Crate_A", -24, -20, 0 }, { "Crate_C", -20, -26, 30 }, { "Pot_A", 24, -22, 0 }, { "Bell_Retain_Wall_Short", -30, 0, 90 },
		{ "Bell_Retain_Wall_Short", 30, 0, 90 }, { "Bell_Fence_Post", 30, -14, 0 } } },
	{ Id = "FallsCache", At = { Cache = "WaterfallAlcove", Yaw = 0, Off = { -110, -50 } }, Items = { -- the waterfall alcove cache (outside the road corridor)
		{ "Falls_Alcove", 0, 0, 0 }, { "Lantern_Stone", -14, -22, 0 }, { "Lantern_Stone", 14, -22, 0 }, { "Pot_A", -8, -28, 0 }, { "Pot_B", 8, -28, 0 }, { "Crate_B", -22, -18, 20 }, { "Crate_A", 22, -18, 0 },
		{ "Bell_Prayer_Flags_Short", 0, -34, 0 }, { "Bell_Signpost_B", 24, -30, 180 } } },
} :: { any }

-------------------------------------------------------------------------------------------------
-- Scatter rules. Spacing = jittered grid pitch, Base = chance per grid cell before the factors, Material = factor by terrain
-- material name, MaxSlope = rise/run (fades to 0 over the last 0.15), Clearing = how much the meadow bowls cut it (negative =
-- more), Pieces = weighted variants, Scale = { min, max }. Tall classes also keep clear of the pavilion lane.
-------------------------------------------------------------------------------------------------

-- Order matters: trees go first so the understory can read the canopy (Under = chance factor beneath a crown, Gap = in a gap, Glade = in a
-- authored glade). Jitter = how far a candidate strays from its grid cell centre (1 = anywhere in the cell: no visible grid). Cluster = the
-- noise mask that groups trees into groves and leaves gaps (Lo..Hi smoothstep of the two-octave noise, Floor = chance left in a gap).
SliceDressing.Classes = { "Tree", "Rock", "Cliff", "Outcrop", "Scree", "Deadwood", "Sapling", "Shrub", "Fern", "Flower", "Mushroom", "Reed", "Grass" }
-- Keep / exclusion table a class borrows (Keep has Tree, Shrub, Fern, Grass, Rock only): saplings keep clear like trees (their crown must not reach the road).
SliceDressing.KeepAs = { Sapling = "Tree", Deadwood = "Rock", Cliff = "Rock", Outcrop = "Rock", Scree = "Shrub", Flower = "Grass", Mushroom = "Fern", Reed = "Fern" } :: { [string]: string }
SliceDressing.Scatter = {
	Tree = { Salt = 1, Spacing = 22, Base = 0.85, Jitter = 1, MaxSlope = 0.55, Clearing = 0.9, Tall = true, Scale = { 0.7, 1.4 }, Cluster = { Lo = 0.3, Hi = 0.52, Floor = 0.05 }, Roadside = 2.6,
			FarBelt = 170, FarDensity = 0.6, -- beyond Half + Fade of the route, out to FarBelt studs more, at FarDensity of the chance: _Far variants only (they are > FarSwitch from every road)
		Pieces = { { "Canopy_Tree_A", 0.26 }, { "Canopy_Tree_B", 0.14 }, { "Canopy_Tree_C", 0.18 }, { "Canopy_Tree_D", 0.14 }, { "Conifer_Tall", 0.04 }, { "Old_Gnarled_Tree", 0.14 } }, Material = { LeafyGrass = 1, Grass = 0.9, Ground = 0.5, Mud = 0.3, Rock = 0.1 } },
	Rock = { Salt = 5, Spacing = 40, Base = 0.8, Jitter = 1, MaxSlope = 1.6, MinSlope = 0.1, Clearing = 0.9, Tall = true, Scale = { 0.7, 1.2 },
		Pieces = { { "Boulder_Granite_A", 0.3 }, { "Boulder_Granite_B", 0.25 }, { "Boulder_Granite_C", 0.15 }, { "Boulder_Granite_D", 0.15 }, { "Boulder_Granite_Split", 0.15 } }, Material = { Rock = 1, Ground = 0.5, Mud = 0.2, LeafyGrass = 0.3, Grass = 0.25 } },
	Cliff = { Salt = 6, Spacing = 60, Base = 0.5, Jitter = 1, MaxSlope = 2.4, MinSlope = 0.5, Clearing = 0.9, Tall = true, Scale = { 0.8, 1.3 }, FaceDownhill = true,
		Pieces = { { "Cliff_Face_A", 1 }, { "Cliff_Face_B", 1 }, { "Cliff_Face_C", 1 } }, Material = { Rock = 1, Ground = 0.4, LeafyGrass = 0.2, Grass = 0.2, Mud = 0.1 } },
	Outcrop = { Salt = 8, Spacing = 70, Base = 0.5, Jitter = 1, MaxSlope = 1.6, MinSlope = 0.12, Clearing = 0.9, Scale = { 0.8, 1.3 },
		Pieces = { { "Outcrop_Mossy", 1 } }, Material = { Rock = 1, Ground = 0.5, LeafyGrass = 0.15, Grass = 0.1 } },
	Scree = { Salt = 9, Spacing = 50, Base = 0.5, Jitter = 1, MaxSlope = 1.0, MinSlope = 0.15, Clearing = 0.9, Scale = { 0.8, 1.3 },
		Pieces = { { "Scree_Patch_A", 1 }, { "Scree_Patch_B", 1 } }, Material = { Rock = 1, Ground = 0.6, Mud = 0.1 } },
	Deadwood = { Salt = 11, Spacing = 30, Base = 0.45, Jitter = 1, MaxSlope = 0.6, Clearing = 0.5, Tall = true, Under = 1.8, Gap = 0.5, Glade = 0.6, Scale = { 0.8, 1.2 },
		Pieces = { { "Fallen_Log_A", 0.22 }, { "Fallen_Log_B", 0.2 }, { "Tree_Stump_A", 0.15 }, { "Tree_Stump_B", 0.15 }, { "Dead_Standing_Trunk", 0.06 }, { "Exposed_Roots_A", 0.11 }, { "Exposed_Roots_B", 0.11 } },
		Material = { LeafyGrass = 1, Grass = 0.6, Ground = 0.6, Mud = 0.5 } },
	Sapling = { Salt = 12, Spacing = 24, Base = 0.1, Jitter = 1, MaxSlope = 0.6, Clearing = 0.6, Under = 0.5, Gap = 1.5, Glade = 2, Scale = { 0.8, 1.3 },
		Pieces = { { "Sapling_Tree", 1 } }, Material = { LeafyGrass = 1, Grass = 0.8, Ground = 0.4, Mud = 0.3 } },
	Shrub = { Salt = 2, Spacing = 20, Base = 0.22, Jitter = 1, MaxSlope = 0.7, Clearing = 0.5, Under = 0.25, Gap = 1.5, Glade = 1.8, Scale = { 0.8, 1.4 },
		Pieces = { { "Understory_Shrub", 0.15 }, { "Understory_Shrub_Small", 0.5 }, { "Shrub_Hazel", 0.15 }, { "Shrub_Thicket", 0.1 }, { "Shrub_Berry", 0.1 } }, Material = { LeafyGrass = 1, Grass = 0.7, Ground = 0.45, Mud = 0.4, Rock = 0.12 } },
	Fern = { Salt = 3, Spacing = 15, Base = 0.22, Jitter = 1, MaxSlope = 0.8, Clearing = 0.3, Under = 0.4, Gap = 1.4, Glade = 1.6, Scale = { 0.8, 1.5 },
		Pieces = { { "Fern_Clump", 0.4 }, { "Fern_Bracken", 0.3 }, { "Fern_Sword", 0.3 } }, Material = { Mud = 1, LeafyGrass = 0.85, Grass = 0.45, Ground = 0.25 } },
	Flower = { Salt = 13, Spacing = 14, Base = 0.09, Jitter = 1, MaxSlope = 0.5, Clearing = -0.3, Under = 0.4, Gap = 1.6, Glade = 2.4, Scale = { 0.9, 1.5 },
		Pieces = { { "Flowers_Daisy", 0.5 }, { "Flowers_Foxglove", 0.5 } }, Material = { Grass = 1, LeafyGrass = 0.8, Ground = 0.2 } },
	Mushroom = { Salt = 14, Spacing = 28, Base = 0.25, Jitter = 1, MaxSlope = 0.7, Clearing = 0.5, Under = 1.8, Gap = 0.35, Glade = 0.5, Scale = { 0.9, 1.4 },
		Pieces = { { "Mushroom_Cluster", 1 } }, Material = { Mud = 1, LeafyGrass = 0.8, Ground = 0.5, Grass = 0.3 } },
	Reed = { Salt = 15, Spacing = 16, Base = 0.3, Jitter = 1, MaxSlope = 0.5, Clearing = 0, Under = 1, Gap = 1, Glade = 1, Scale = { 0.9, 1.4 },
		Pieces = { { "Reed_Clump_A", 0.5 }, { "Reed_Clump_B", 0.5 } }, Material = { Mud = 1 } },
	Grass = { Salt = 4, Spacing = 11, Base = 0.33, Jitter = 1, MaxSlope = 0.6, Clearing = -0.6, Under = 0.5, Gap = 1.3, Glade = 1.5, Scale = { 0.9, 1.7 },
		Pieces = { { "Grass_Clump", 0.4 }, { "Grass_Tall", 0.2 }, { "Grass_Lush", 0.25 }, { "Grass_Seed", 0.15 } }, Material = { Grass = 1, LeafyGrass = 0.65, Ground = 0.2, Mud = 0.2 } },
}
SliceDressing.CrownSpacing = 0.45 -- two crowns keep this fraction of their summed radii apart (they may overlap: that is a canopy)
SliceDressing.CrownFrac = 0.8 -- the drawn leaf mass is this fraction of a tree's footprint (Leaves_Mass); coverage is measured with it
SliceDressing.RoadClearance = 14 -- a crown that overhangs a road has its underside at least this high (fault A); VoxelLift is the written surface above heightAt
SliceDressing.VoxelLift = 2

-- Authored glades: open clearings in the canopy (no tree centre inside R), understory boosted. Arc = studs along the route, Off = sideways
-- (+ right walking glade -> terrace). Position is route-relative, so it follows the road, never a baked Y.
SliceDressing.Glades = {
	{ Id = "MossGap", Arc = 170, Off = 62, R = 32 }, { Id = "FernHollow", Arc = 345, Off = -58, R = 36 },
	{ Id = "StoneRise", Arc = 700, Off = 62, R = 34 }, { Id = "LightShaft", Arc = 520, Off = 66, R = 30 },
}

-- Lines of sight kept free of anything that would block them: a placement is refused when its top stands above the ray (minus Margin)
-- where it crosses a crown's reach of the line. From = world XZ, FromSpawn = an altar spawn, or FromNear = the route point nearest a hero; To = hero id (its top).
SliceDressing.Sights = {
	{ Id = "TowerFromGlade", From = { X = -2203, Z = -1415 }, To = "TowerMid", Margin = 2 },
	{ Id = "PavilionFromTower", FromNear = "TowerMid", To = "Pavilion", Margin = 2 },
	{ Id = "TowerFromSpawn", FromSpawn = "Altar_MonasteryGate", To = "TowerMid", Margin = 2 },
}

-- Sight cones (fault C, lane D6): a widening cone (Pad studs plus Deg degrees of half-angle) from each listed capture eye to a hero's top, kept clear of
-- anything that would hide the part of the hero above LowFrac of its height: a piece (trunk, canopy bounding circle, or bounding circle) that reaches the cone and
-- overlaps the band of rays from LowFrac to the top is refused. Beyond the hero (up to Beyond studs, same cone) nothing may rise within SkyMargin degrees of the hero's
-- top as seen from the eye, so the hero stands above the far tree line.
SliceDressing.Cones = {
	{ Id = "TowerCone", Captures = { "01_glade_arrival", "07_tower_from_glade" }, To = "TowerMid", Deg = 4, Pad = 6, LowFrac = 0.25, SkyMargin = 1.5, Beyond = 700 },
} :: { any }

-- Forest floor round the glade altar (fault D): ferns, grass and a few small rocks in the ring Inner..Outer (the pad is 22 radius and stays
-- clear; arrival and altar keeps are skipped here, every other exclusion stays). Spacing = the jittered cell, Chance = per cell.
SliceDressing.Floor = { Altar = "Altar_MonasteryGate", Inner = 24, Outer = 34, Spacing = 4, Chance = 0.9, Rocks = 4, RockChance = 0.25, RockPiece = "Boulder_Granite_B", RockScale = { 0.22, 0.4 },
	Flower = 0.12, Fern = 0.4, Grass = 0.7 }

-------------------------------------------------------------------------------------------------
-- Registered-asset swap table: piece name -> { Registry = "<assets/ file>", Id = <mesh asset number>, Path = "<ServerStorage path>", Part = <MeshPart
-- name to keep, else the whole model> }, or nil = placeholder. Every Id is copied from its Registry file (test_slice_dressing greps it);
-- SliceDressingService clones the model at Path and fits it to the piece (fit = largest scale that stays inside Size). Fits per
-- workers/19a-registry-fit.md. Left nil on purpose: Bell_Timber_Gate (the only registered gate art, AsuraBambooGateArt, is a lobby plaque
-- and not a 19 stud gate), shrubs and ferns (the bamboo tuft is grass), Boulder A/C, trees, pavilion, tower, stair, wall, stepping stones.
-------------------------------------------------------------------------------------------------
SliceDressing.Assets = {
	Bell_Lantern_Post = { Registry = "assets/PHASE5_UPLOADED.json", Id = 105652153407631, Path = "AsuraAssets/AsuraBrassLantern" },
	Boulder_Granite_B = { Registry = "assets/PHASE5_UPLOADED.json", Id = 106842288070597, Path = "AsuraAssets/AsuraStone" },
	Grass_Clump = { Registry = "assets/LIVING_BAMBOO_UPLOADED.json", Id = 81752398968484, Path = "AsuraLivingBamboo", Part = "Ground_GrassTuft" },
} :: { [string]: { Registry: string, Id: number, Path: string, Part: string? } }

-- Slice kit registry by name: { [piece] = { [piece .. "__" .. sub] = { MeshId, ColorMap, NormalMap, RoughnessMap, MetalnessMap, center = { x, y, z }? } } },
-- the "pieces" table of assets/SLICE_KIT_UPLOADED.json. It reaches runtime as the generated module src/shared/SliceKitRegistry.luau
-- (a sibling of this file; see WIRING FOR LEAD in workers/12g). Absent module = empty registry = every piece stays a placeholder.
SliceDressing.Registry = {} :: any
-- Documented fallback: SliceKitRegistry.luau is generated from assets/SLICE_KIT_UPLOADED.json after uploads; absent until then, so resolution falls through to Assets then placeholder.
do
	local ok, reg = pcall(function() return require((script :: any).Parent.SliceKitRegistry) end)
	if ok and type(reg) == "table" then
		SliceDressing.Registry = reg
	end
end

-------------------------------------------------------------------------------------------------
-- Keep: minimum distance of a placement's centre from each constraint, by class { Tree, Shrub, Fern, Grass, Rock }.
-------------------------------------------------------------------------------------------------

local function keep(t: number, s: number, f: number, g: number, r: number): any
	return { Tree = t, Shrub = s, Fern = f, Grass = g, Rock = r }
end

SliceDressing.Keep = {
	Road = keep(12, 11, 9.5, 8.5, 13), -- from any road centreline (Road.Half is 8); a tree trunk 4 studs off the road lets its crown overhang it
	Altar = keep(32, 30, 26, 25, 32), -- the pad is 22 radius
	Arrival = keep(14, 14, 12, 12, 14), -- altar Spawn and Exit points
	Ring = keep(48, 44, 40, 38, 48), -- PvP ring pad is 34 radius
	ReturnGate = keep(30, 24, 20, 18, 30),
	Shelter = keep(14, 7, 4, 3, 8), -- added to the shelter's half diagonal
	SpanEnd = keep(36, 30, 24, 20, 36), -- bridge / ramp / lift / portal ends
	Hero = keep(8, 5, 3, 2, 4), -- added to the hero's radius * scale
	-- Encounter homes: fractions of the foe's LeashRange (WorldDefinitions). Tall pieces keep half the leash clear (sight and
	-- camera), low plants only the fighting ground; nothing collides, so the chase space itself stays open.
	Leash = { Tree = 0.5, Rock = 0.5, Shrub = 0.22, Fern = 0.16, Grass = 0.12 },
}
SliceDressing.MobLeash = { CorruptWanderingMonk = 90, CursedSwordsman = 110, HollowBellWarden = 70, SparringPhantom = 24 } :: { [string]: number }

-- Review captures (Studio, player height). From = world XZ or an Arc (+ Off); To = a hero id or world XZ; Eye above ground.
SliceDressing.Eye = 5
SliceDressing.Captures = ({
	{ Id = "01_glade_arrival", Note = "Altar spawn looking down the road to the glade gate: ground materials, canopy wall, lanterns", From = { X = -2203, Z = -1415 }, ToHero = "GateGlade", ToDy = 8 },
	{ Id = "02_road_lanterns", Note = "Mid-glade road looking along it: lantern posts, canopy gap at player height", FromArc = 215, ToArc = 330, ToDy = 7 },
	{ Id = "03_understory", Note = "Road edge looking into the forest: shrubs, ferns, grass, trunks", FromArc = 675, FromOff = 15, ToArc = 675, ToOff = 55, ToDy = 2 },
	{ Id = "04_broken_tower", Note = "Approach to the mid-route broken tower", FromArc = 420, ToHero = "TowerMid", ToDy = 12 },
	{ Id = "05_pavilion_lane", Note = "Late approach: the pavilion above the tree line through the cleared lane", FromArc = 770, ToHero = "Pavilion", ToDy = 55 },
	{ Id = "06_terrace_stair", Note = "Altar plateau looking down the terrace stair and walls at the pavilion court", From = { X = -3000, Z = -1983 }, ToHero = "Pavilion", ToDy = 30 },
	{ Id = "07_tower_from_glade", Note = "Glade arrival at player height: the broken bell tower above the trees along its cleared sightline (fault C)", From = { X = -2203, Z = -1415 }, ToHero = "TowerMid", ToFrac = 0.9 },
} :: any) :: { any }

-------------------------------------------------------------------------------------------------
-- Deterministic hash (xorshift32 over integer cell coordinates; bit32 is exact, no random state)
-------------------------------------------------------------------------------------------------

local TWO32 = 4294967296

-- 32-bit multiply exact in doubles (a is split so no product passes 2^48).
local function mul32(a: number, b: number): number
	return ((bit32.rshift(a, 16) * b % 65536) * 65536 + (a % 65536) * b) % TWO32
end

local function hash(a: number, b: number, salt: number): number
	local x = bit32.bxor((a * 73856093) % TWO32, (b * 19349663) % TWO32, (salt * 83492791) % TWO32)
	x = mul32(bit32.bxor(x, bit32.rshift(x, 16)), 0x85ebca6b) -- murmur3 fmix32: nonlinear, so salts give independent draws
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

-------------------------------------------------------------------------------------------------
-- Route
-------------------------------------------------------------------------------------------------

local route: any = nil

-- { Points = { { x, z, y } }, Arc = { number }, Length } of the main road between Route.From and Route.To.
function SliceDressing.route(): any
	if route then
		return route
	end
	local pts: any = nil
	for _, r in Overworld.terrainData().Roads do
		if r.A == SliceDressing.Route.From and r.B == SliceDressing.Route.To then
			pts = r.Points
		end
	end
	assert(pts, "SliceDressing: no road " .. SliceDressing.Route.From .. " > " .. SliceDressing.Route.To)
	local arc = { 0 }
	for k = 2, #pts do
		arc[k] = arc[k - 1] + math.sqrt((pts[k][1] - pts[k - 1][1]) ^ 2 + (pts[k][2] - pts[k - 1][2]) ^ 2)
	end
	route = { Points = pts, Arc = arc, Length = arc[#pts] }
	return route
end

-- World x, z and unit tangent (tx, tz) at arc length s along the route.
function SliceDressing.pointAt(s: number): (number, number, number, number)
	local R: any = SliceDressing.route()
	local pts, arc = R.Points, R.Arc
	s = math.clamp(s, 0, R.Length)
	local k = 2
	while k < #pts and arc[k] < s do
		k += 1
	end
	local p, q = pts[k - 1], pts[k]
	local t = (s - arc[k - 1]) / math.max(arc[k] - arc[k - 1], 1e-6)
	local dx, dz = q[1] - p[1], q[2] - p[2]
	local l = math.sqrt(dx * dx + dz * dz)
	return p[1] + dx * t, p[2] + dz * t, dx / l, dz / l
end

local function segDist(x0: number, z0: number, x1: number, z1: number, x: number, z: number): number
	local dx, dz = x1 - x0, z1 - z0
	local t = math.clamp(((x - x0) * dx + (z - z0) * dz) / math.max(dx * dx + dz * dz, 1e-9), 0, 1)
	return math.sqrt((x - x0 - dx * t) ^ 2 + (z - z0 - dz * t) ^ 2)
end
SliceDressing.segDist = segDist

-------------------------------------------------------------------------------------------------
-- Builder
-------------------------------------------------------------------------------------------------

-- World X, Z of a review capture's eye (From, or FromArc + FromOff along the route).
local function captureEye(c: any): (number, number)
	if c.FromArc then
		local px, pz, tx, tz = SliceDressing.pointAt(c.FromArc)
		local off = c.FromOff or 0
		return px - tz * off, pz + tx * off
	end
	return c.From.X, c.From.Z
end

function SliceDressing.cellOf(x: number, z: number): string
	local F = Overworld.Frame
	return math.floor((x - F.MinX) / SliceDressing.Cell) .. "," .. math.floor((z - F.MinZ) / SliceDressing.Cell)
end

local function worldDist(x0: number, z0: number, x1: number, z1: number): number
	return math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
end

-- The circular exclusions (everything but roads, lanes): { X, Z, Keep = class table or per-class radii }.
local function circles(heroes: { any }): { any }
	local K: any = SliceDressing.Keep
	local list: { any } = {}
	local function add(x: number, z: number, k: any, altar: boolean?)
		table.insert(list, { X = x, Z = z, Keep = k, Altar = altar == true })
	end
	for _, a in Overworld.Altars do
		add(a.Placement.X, a.Placement.Z, K.Altar, true) -- Altar = the forest floor ring may stand inside this one (Floor)
		add(a.Spawn.X, a.Spawn.Z, K.Arrival)
		add(a.Exit.X, a.Exit.Z, K.Arrival)
	end
	for _, r in Overworld.Rings do
		add(r.X, r.Z, K.Ring)
	end
	local rg = Overworld.Blockout.ReturnGate
	add(rg.X, rg.Z, K.ReturnGate)
	for _, s in Overworld.Blockout.Shelters do
		local half = 0.5 * math.sqrt(s.W ^ 2 + s.D ^ 2)
		local k = {}
		for cls, pad in K.Shelter do
			k[cls] = half + pad
		end
		add(s.X, s.Z, k)
	end
	for _, b in Overworld.Blockout.Bridges do
		add(b.A.X, b.A.Z, K.SpanEnd); add(b.B.X, b.B.Z, K.SpanEnd)
	end
	for _, b in Overworld.Blockout.Ramps do
		add(b.A.X, b.A.Z, K.SpanEnd); add(b.B.X, b.B.Z, K.SpanEnd)
	end
	for _, b in Overworld.Blockout.Lifts do
		add(b.A.X, b.A.Z, K.SpanEnd); add(b.B.X, b.B.Z, K.SpanEnd)
	end
	for _, p in Overworld.Blockout.Portals do
		add(p.X, p.Z, K.SpanEnd)
	end
	local function home(x: number, z: number, mob: string)
		local leash = SliceDressing.MobLeash[mob]
		assert(leash, "SliceDressing.MobLeash lacks " .. mob)
		local k = {}
		for cls, f in K.Leash do
			k[cls] = f * leash
		end
		add(x, z, k)
	end
	for _, s in Overworld.EncounterSpots do
		home(s.Placement.X, s.Placement.Z, s.Mob)
	end
	for _, m in Overworld.Minibosses do
		home(m.Placement.X, m.Placement.Z, m.Id)
	end
	home(Overworld.Training.Placement.X, Overworld.Training.Placement.Z, "SparringPhantom")
	for _, h in heroes do
		local radius = SliceDressing.Pieces[h.Piece].Radius * h.Scale
		local k = {}
		for cls, pad in K.Hero do
			k[cls] = radius + pad
		end
		add(h.X, h.Z, k)
	end
	return list
end

local function hostile(x: number, z: number, class: string, list: { any }, roadSegs: { any }, lanes: { any }, tall: boolean): boolean
	local K: any = SliceDressing.Keep
	local cls = (SliceDressing.KeepAs :: any)[class] or class
	for _, c in list do
		if worldDist(x, z, c.X, c.Z) < c.Keep[cls] then
			return true
		end
	end
	local road = K.Road[cls]
	for _, s in roadSegs do
		if segDist(s[1], s[2], s[3], s[4], x, z) < road then
			return true
		end
	end
	if tall then
		for _, s in lanes do
			if segDist(s[1], s[2], s[3], s[4], x, z) < SliceDressing.Lane.HalfWidth then
				return true
			end
		end
	end
	return false
end

local function clearingFactor(x: number, z: number): number
	local c = 0
	for _, cl in Overworld.TerrainDef.Clearings do
		local d = worldDist(x, z, cl.X, cl.Z)
		c = math.max(c, 1 - smooth((d - 0.4 * cl.R) / (0.6 * cl.R)))
	end
	return c
end

-- Two-octave value noise in 0..1: the grove / gap mask that keeps the canopy from reading as a grid.
local function valueNoise(x: number, z: number, size: number, salt: number): number
	local fx, fz = x / size, z / size
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = smooth(fx - ix), smooth(fz - iz)
	local a, b = rand(ix, iz, salt), rand(ix + 1, iz, salt)
	local c, d = rand(ix, iz + 1, salt), rand(ix + 1, iz + 1, salt)
	return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * tz
end

function SliceDressing.cluster(x: number, z: number): number
	return 0.6 * valueNoise(x, z, 150, 901) + 0.4 * valueNoise(x, z, 55, 902)
end

-- Height of a placed piece above its foot (the top of the mesh; the Sink is buried).
local function heightOf(piece: any, scale: number): number
	return (piece.Size[2] - piece.Sink) * scale
end

-- A placement at (x, z) with its foot at groundY, top = groundY + height, blocks a sight when it stands within `reach` of the line and its
-- top rises above the ray (less Margin) where the line first meets its reach. Pure: only heights and radii.
local function blocks(s: any, x: number, z: number, groundY: number, height: number, reach: number): boolean
	local dx, dz = s.X1 - s.X0, s.Z1 - s.Z0
	local raw = ((x - s.X0) * dx + (z - s.Z0) * dz) / (s.Len * s.Len)
	if raw >= 1 then
		return false -- beyond the target
	end
	local t = math.clamp(raw, 0, 1)
	if worldDist(x, z, s.X0 + dx * t, s.Z0 + dz * t) >= reach then
		return false
	end
	local tNear = math.max(0, t - reach / s.Len)
	return groundY + height > s.Y0 + (s.Y1 - s.Y0) * tNear - s.Margin
end

-- Line of sight along sight `s` ({ X0, Z0, Y0, X1, Z1, Y1, Len, Margin }): { Clear, TerrainAt, Blockers }. Terrain blocks where heightAt + VoxelLift
-- stands above the ray; Blockers lists the placement ids (not the target) whose tops cross it. Exported for the test.
function SliceDressing.lineOfSight(s: any, placements: { any }): any
	local terrainAt: number? = nil
	local step = 3
	for d = 0, s.Len - 20, step do
		local t = d / s.Len
		local x, z = s.X0 + (s.X1 - s.X0) * t, s.Z0 + (s.Z1 - s.Z0) * t
		if Overworld.heightAt(x, z) + SliceDressing.VoxelLift > s.Y0 + (s.Y1 - s.Y0) * t then
			terrainAt = d
			break
		end
	end
	local blockers: { string } = {}
	for _, pl in placements do
		if pl.Id ~= s.To and pl.Id ~= s.Id then
			local piece = SliceDressing.Pieces[pl.Piece]
			if blocks(s, pl.X, pl.Z, pl.Y, heightOf(piece, pl.Scale), piece.Radius * pl.Scale) then
				table.insert(blockers, pl.Id)
			end
		end
	end
	return { Clear = terrainAt == nil and #blockers == 0, TerrainAt = terrainAt, Blockers = blockers }
end

local built: any = nil

-- Placements for the whole slice: { Placements = { ... }, Counts = { [piece] = n }, ByClass, Cells = { [key] = { Placements, Needs } },
-- MeshParts, PlaceholderParts, Tris }. Pure and memoised (build(true) rebuilds); the same seed and terrain always give the same list.
function SliceDressing.build(fresh: boolean?): any
	if fresh then
		built = nil -- the test rebuilds from scratch to prove determinism
	end
	if built then
		return built
	end
	local P: any = SliceDressing.Pieces
	local R: any = SliceDressing.route()
	local placements: { any } = {}
	local heroes: { any } = {}

	-- Hero: resolve Arc into world X, Z, Yaw; ground at Foot.
	for _, spec in SliceDressing.Hero do
		local piece = P[spec.Piece]
		assert(piece, "SliceDressing.Hero: unknown piece " .. tostring(spec.Piece))
		local x, z, yaw = spec.X, spec.Z, spec.Yaw
		if spec.Arc then
			local px, pz, tx, tz = SliceDressing.pointAt(spec.Arc)
			x, z = px - tz * spec.Off, pz + tx * spec.Off
			yaw = math.deg(math.atan2(tx, tz))
		end
		local scale = spec.Scale or 1
		local rad = math.rad(yaw)
		local fx, fz = if spec.Foot then spec.Foot[1] else 0, if spec.Foot then spec.Foot[2] else 0
		local gx, gz = x + fx * math.cos(rad) + fz * math.sin(rad), z - fx * math.sin(rad) + fz * math.cos(rad)
		local gy = Overworld.heightAt(gx, gz)
		if spec.Raise then -- smallest scale whose top is seen over the terrain from the arrival point
			local rz: any = spec.Raise
			local ex, ez = rz.From.X, rz.From.Z
			local ey = Overworld.heightAt(ex, ez) + SliceDressing.Eye
			local len = worldDist(ex, ez, x, z)
			while scale < rz.Max do
				local top = gy + heightOf(piece, scale)
				local clear = true
				for d = 0, len - 20, 3 do
					local t = d / len
					if ey + (top - ey) * t < Overworld.heightAt(ex + (x - ex) * t, ez + (z - ez) * t) + SliceDressing.VoxelLift + rz.Margin then
						clear = false
						break
					end
				end
				if clear then break end
				scale += 0.1
			end
		end
		local h = { Id = spec.Id, Piece = spec.Piece, Class = "Hero", Kind = "Hero", X = x, Z = z, GX = gx, GZ = gz, Y = gy,
			Yaw = yaw + (SliceDressing.ImportYaw[spec.Piece] or 0), Scale = scale, Sink = piece.Sink, Landmark = spec.Landmark == true, Cell = SliceDressing.cellOf(x, z) }
		table.insert(heroes, h)
		table.insert(placements, h)
	end
	local pavilion: any = nil
	for _, h in heroes do
		if h.Id == SliceDressing.Lane.To then pavilion = h end
	end

	-- Road segments (every road, so side roads and the alternate are kept clear too) and pavilion lanes.
	local C: any = SliceDressing.Corridor
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	local function grow(x: number, z: number, r: number)
		x0, x1, z0, z1 = math.min(x0, x - r), math.max(x1, x + r), math.min(z0, z - r), math.max(z1, z + r)
	end
	for _, p in R.Points do grow(p[1], p[2], C.Half + C.Fade) end
	for _, d in C.Discs do
		local a = Overworld.Altars[d.Altar].Placement
		grow(a.X, a.Z, d.R + C.Fade)
	end
	local treeRule: any = (SliceDressing.Scatter :: any).Tree
	local beltExtra = if treeRule.FarBelt then treeRule.FarBelt + C.Fade else 0 -- the tree grid and the road list reach this far past the corridor box
	local roadSegs: { any } = {}
	for _, road in Overworld.terrainData().Roads do
		for k = 2, #road.Points do
			local p, q = road.Points[k - 1], road.Points[k]
			if math.max(p[1], q[1]) > x0 - 20 - beltExtra and math.min(p[1], q[1]) < x1 + 20 + beltExtra and math.max(p[2], q[2]) > z0 - 20 - beltExtra and math.min(p[2], q[2]) < z1 + 20 + beltExtra then
				table.insert(roadSegs, { p[1], p[2], q[1], q[2] })
			end
		end
	end
	local lanes: { any } = {}
	if pavilion then
		for k = 1, #R.Points do
			local p = R.Points[k]
			if worldDist(p[1], p[2], pavilion.X, pavilion.Z) <= SliceDressing.Lane.Reach then
				table.insert(lanes, { p[1], p[2], pavilion.X, pavilion.Z })
			end
		end
	end

	-- Sights (lines kept free) and authored glades, both resolved against the built heroes.
	local heroById: { [string]: any } = {}
	for _, h in heroes do heroById[h.Id] = h end
	local sights: { any } = {}
	for _, sp: any in SliceDressing.Sights do
		local target = heroById[sp.To]
		assert(target, "SliceDressing.Sights: unknown hero " .. tostring(sp.To))
		local fx, fz = 0, 0
		if sp.From then
			fx, fz = sp.From.X, sp.From.Z
		elseif sp.FromSpawn then
			fx, fz = Overworld.Altars[sp.FromSpawn].Spawn.X, Overworld.Altars[sp.FromSpawn].Spawn.Z
		else
			local near = heroById[sp.FromNear]
			assert(near, "SliceDressing.Sights: unknown hero " .. tostring(sp.FromNear))
			local best = math.huge
			for s = 0, R.Length, 10 do
				local px, pz = SliceDressing.pointAt(s)
				if worldDist(px, pz, near.X, near.Z) < best then
					best, fx, fz = worldDist(px, pz, near.X, near.Z), px, pz
				end
			end
		end
		table.insert(sights, { Id = sp.Id, To = sp.To, X0 = fx, Z0 = fz, Y0 = Overworld.heightAt(fx, fz) + SliceDressing.Eye, X1 = target.X, Z1 = target.Z,
			Y1 = target.Y + heightOf(P[target.Piece], target.Scale), Len = worldDist(fx, fz, target.X, target.Z), Margin = sp.Margin })
	end
	local glades: { any } = {}
	for _, g: any in SliceDressing.Glades do
		local px, pz, tx, tz = SliceDressing.pointAt(g.Arc)
		table.insert(glades, { Id = g.Id, X = px - tz * g.Off, Z = pz + tx * g.Off, R = g.R })
	end
	-- Sight cones, one per distinct eye (captures 01 and 07 share one): the ray band from LowFrac of the target's height to its top, and the skyline beyond it.
	local cones: { any } = {}
	for _, cs: any in SliceDressing.Cones do
		local target = heroById[cs.To]
		assert(target, "SliceDressing.Cones: unknown hero " .. tostring(cs.To))
		local h = heightOf(P[target.Piece], target.Scale)
		local seen: { [string]: boolean } = {}
		for _, cap: any in SliceDressing.Captures do
			if table.find(cs.Captures, cap.Id) then
				local fx, fz = captureEye(cap)
				if not seen[fx .. "," .. fz] then
					seen[fx .. "," .. fz] = true
					local len = worldDist(fx, fz, target.X, target.Z)
					local y0 = Overworld.heightAt(fx, fz) + SliceDressing.Eye
					table.insert(cones, { Id = cs.Id, X0 = fx, Z0 = fz, Y0 = y0, Len = len, Ux = (target.X - fx) / len, Uz = (target.Z - fz) / len, Tan = math.tan(math.rad(cs.Deg)), Pad = cs.Pad,
						YLow = target.Y + cs.LowFrac * h, YTop = target.Y + h, Sky = math.atan2(target.Y + h - y0, len), SkyMargin = math.rad(cs.SkyMargin), Beyond = cs.Beyond })
				end
			end
		end
	end
	local function coneBlocks(x: number, z: number, groundY: number, piece: any, scale: number): boolean
		for _, cn in cones do
			local px, pz = x - cn.X0, z - cn.Z0
			local along = px * cn.Ux + pz * cn.Uz
			local hyp = math.sqrt(px * px + pz * pz)
			if along < cn.Len + cn.Beyond then
				local lat = if along > 0 then math.sqrt(math.max(hyp * hyp - along * along, 0)) else hyp
				local cr = cn.Pad + cn.Tan * math.max(along, 0)
				for _, o in piece.Occ do
					if lat - o[1] * scale < cr then
						local y0, y1 = groundY + o[2] * scale, groundY + o[3] * scale
						if along <= cn.Len then
							local f = math.max(along, 0) / cn.Len
							if y1 >= cn.Y0 + (cn.YLow - cn.Y0) * f and y0 <= cn.Y0 + (cn.YTop - cn.Y0) * f then
								return true
							end
						elseif math.atan2(y1 - cn.Y0, hyp) > cn.Sky - cn.SkyMargin then
							return true
						end
					end
				end
			end
		end
		return false
	end
	local function blocksSight(x: number, z: number, groundY: number, piece: any, scale: number): boolean
		for _, s in sights do
			if blocks(s, x, z, groundY, heightOf(piece, scale), piece.Radius * scale) then
				return true
			end
		end
		return coneBlocks(x, z, groundY, piece, scale)
	end
	local eyeSpots: { { number } } = {} -- every capture eye: the far switch measures from these and from the roads
	for _, cap: any in SliceDressing.Captures do
		local fx, fz = captureEye(cap)
		table.insert(eyeSpots, { fx, fz })
	end
	local function farFrom(x: number, z: number): number
		local d = math.huge
		for _, e in eyeSpots do
			d = math.min(d, worldDist(x, z, e[1], e[2]))
		end
		for _, s in roadSegs do
			d = math.min(d, segDist(s[1], s[2], s[3], s[4], x, z))
		end
		return d
	end
	local function gladeWeight(x: number, z: number): number
		local w = 0
		for _, g in glades do
			w = math.max(w, 1 - smooth((worldDist(x, z, g.X, g.Z) - 0.85 * g.R) / (0.3 * g.R)))
		end
		return w
	end
	local function nearRoad(x: number, z: number): number
		local d = math.huge
		for _, s in roadSegs do
			d = math.min(d, segDist(s[1], s[2], s[3], s[4], x, z))
		end
		return d
	end

	-- Composed set pieces (SliceDressing.Sets): resolved once the roads, sights and heroes exist; items that would stand in water, on a road, inside an altar pad
	-- or in a kept sight are dropped (and counted). They are hero placements, so every scatter class keeps clear of them.
	local setStats: { [string]: any } = {}
	local function nearAnyRoad(x: number, z: number): number -- every road, also the ones outside the scatter corridor (the cache site)
		local d = math.huge
		for _, road in Overworld.terrainData().Roads do
			for k = 2, #road.Points do
				local p, q = road.Points[k - 1], road.Points[k]
				d = math.min(d, segDist(p[1], p[2], q[1], q[2], x, z))
			end
		end
		return d
	end
	for _, set: any in SliceDressing.Sets do
		local at: any = set.At
		local ax, az, scaleUp = 0, 0, 1
		if at.Altar then
			local a = Overworld.Altars[at.Altar].Placement
			ax, az = a.X, a.Z
		elseif at.Encounter then
			local a = Overworld.EncounterSpots[at.Encounter].Placement
			ax, az = a.X, a.Z
		elseif at.Miniboss then
			local a = Overworld.Minibosses[at.Miniboss].Placement
			ax, az = a.X, a.Z
		elseif at.Cache then
			local a = Overworld.Caches[at.Cache].Position
			ax, az = a.X + (if at.Off then at.Off[1] else 0), a.Z + (if at.Off then at.Off[2] else 0) -- Off = a dry spot beside the cache pool
		else
			local hh = heroById[at.Hero]
			assert(hh, "SliceDressing.Sets: unknown hero " .. tostring(at.Hero))
			ax, az, scaleUp = hh.X, hh.Z, hh.Scale
		end
		scaleUp *= at.Scale or 1
		local yaw = at.Yaw
		if yaw == nil then
			local best, dx, dz = math.huge, 0, 1
			if at.Hero then -- front toward the nearest route point
				for s = 0, R.Length, 10 do
					local px, pz = SliceDressing.pointAt(s)
					if worldDist(px, pz, ax, az) < best then best, dx, dz = worldDist(px, pz, ax, az), px - ax, pz - az end
				end
			else -- along the nearest road
				for _, sg in roadSegs do
					local d = segDist(sg[1], sg[2], sg[3], sg[4], ax, az)
					if d < best then best, dx, dz = d, sg[3] - sg[1], sg[4] - sg[2] end
				end
			end
			yaw = math.deg(math.atan2(dx, dz))
		end
		local st = math.rad(yaw)
		local stat = { Placed = 0, Skipped = 0, Why = {} :: { string } }
		setStats[set.Id] = stat
		for n, item: any in set.Items do
			local piece = P[item[1]]
			assert(piece, "SliceDressing.Sets: unknown piece " .. tostring(item[1]))
			local lx, lz = item[2] * scaleUp, item[3] * scaleUp
			local scale = item[5] or 1
			local x = ax - lx * math.cos(st) + lz * math.sin(st)
			local z = az + lx * math.sin(st) + lz * math.cos(st)
			local h, _roadW, channelW, chasmW = Overworld.sampleAt(x, z)
			local why: string? = nil
			if channelW >= 0.05 or chasmW >= 0.01 or h <= 3 then
				why = "water"
			elseif not item[6] and nearAnyRoad(x, z) < 8.2 + 0.5 * math.min(piece.Size[1], piece.Size[3]) * scale then
				why = "road"
			elseif blocksSight(x, z, h, piece, scale) then
				why = "sight"
			else
				for _, a in Overworld.Altars do
					if worldDist(x, z, a.Placement.X, a.Placement.Z) < 22 + 0.35 * math.max(piece.Size[1], piece.Size[3]) * scale then why = "pad" end
				end
			end
			if why then
				stat.Skipped += 1
				table.insert(stat.Why, item[1] .. ":" .. why)
			else
				stat.Placed += 1
				local pl = { Id = string.format("Set_%s_%02d", set.Id, n), Piece = item[1], Class = "Hero", Kind = "Hero", Set = set.Id, X = x, Z = z, GX = x, GZ = z, Y = Overworld.heightAt(x, z),
					Yaw = yaw + item[4] + (SliceDressing.ImportYaw[item[1]] or 0), Scale = scale, Sink = piece.Sink, Landmark = false, Cell = SliceDressing.cellOf(x, z) }
				table.insert(heroes, pl)
				table.insert(placements, pl)
			end
		end
	end
	local list = circles(heroes)
	local listNoAltar: { any } = {} -- the forest floor ring stands inside the altar keep (Floor), nothing else relaxes
	for _, c in list do
		if not c.Altar then table.insert(listNoAltar, c) end
	end

	local function corridorWeight(x: number, z: number): number
		local d = math.huge
		for k = 2, #R.Points do
			local p, q = R.Points[k - 1], R.Points[k]
			d = math.min(d, segDist(p[1], p[2], q[1], q[2], x, z))
		end
		local w = 1 - smooth((d - C.Half) / C.Fade)
		for _, disc in C.Discs do
			local a = Overworld.Altars[disc.Altar].Placement
			w = math.max(w, 1 - smooth((worldDist(x, z, a.X, a.Z) - disc.R) / C.Fade))
		end
		return w
	end

	-- Far belt (trees only): route distance in the band past the corridor fade, ramped in over 10 studs and out over Fade.
	local function beltWeight(x: number, z: number, rule: any): number
		local d = math.huge
		for k = 2, #R.Points do
			local p, q = R.Points[k - 1], R.Points[k]
			d = math.min(d, segDist(p[1], p[2], q[1], q[2], x, z))
		end
		local inner = C.Half + C.Fade
		return rule.FarDensity * smooth((d - inner) / 10) * (1 - smooth((d - inner - rule.FarBelt) / C.Fade))
	end

	-- Occupancy hash (all but grass) for spacing between accepted placements, and the tree crowns the understory reads.
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
					local d = worldDist(x, z, o.X, o.Z)
					local need = if cls == "Tree" and o.Class == "Tree" then SliceDressing.CrownSpacing * (radius + o.R) else 0.5 * (trunk + o.T) + 1
					if d < need then
						return true
					end
				end
			end
		end
		return false
	end
	local function underCrown(x: number, z: number): boolean
		local cx, cz = math.floor(x / GRID), math.floor(z / GRID)
		for ix = cx - 1, cx + 1 do
			for iz = cz - 1, cz + 1 do
				for _, o in occ[occKey(ix, iz)] or {} do
					if o.Class == "Tree" and worldDist(x, z, o.X, o.Z) < o.C then
						return true
					end
				end
			end
		end
		return false
	end

	local function pickPiece(rule: any, r: number): string
		local total = 0
		for _, entry in rule.Pieces do total += entry[2] end
		local pick, cum = rule.Pieces[1][1], 0
		for _, entry in rule.Pieces do
			cum += entry[2]
			pick = entry[1]
			if r * total <= cum then break end
		end
		return pick
	end
	local counts: { [string]: number } = {}
	local byClass: { [string]: number } = {}
	local function accept(class: string, id: string, pick: string, x: number, z: number, h: number, scale: number, yawR: number, radius: number, trunk: number, floor: boolean)
		local piece = P[pick]
		table.insert(placements, { Id = id, Piece = pick, Class = class, Kind = "Scatter", Floor = floor, X = x, Z = z, GX = x, GZ = z, Y = h,
			Yaw = yawR * 360 + (SliceDressing.ImportYaw[pick] or 0), Scale = scale, Sink = piece.Sink, Landmark = false, Cell = SliceDressing.cellOf(x, z) })
		if class ~= "Grass" then
			local key = occKey(math.floor(x / GRID), math.floor(z / GRID))
			occ[key] = occ[key] or {}
			table.insert(occ[key], { X = x, Z = z, R = radius, T = trunk, C = (piece.Crown or radius) * scale, Class = class })
		end
	end
	for _, class in SliceDressing.Classes do
		local rule: any = (SliceDressing.Scatter :: any)[class]
		local S = rule.Spacing
		local jitter = rule.Jitter or 0.8
		local n = 0
		local belt = rule.FarBelt ~= nil
		local ext = if belt then beltExtra else 0
		for gi = math.floor((x0 - ext) / S), math.ceil((x1 + ext) / S) do
			for gj = math.floor((z0 - ext) / S), math.ceil((z1 + ext) / S) do
				local x = (gi + 0.5 + (rand(gi, gj, rule.Salt * 10 + 1) - 0.5) * jitter) * S
				local z = (gj + 0.5 + (rand(gi, gj, rule.Salt * 10 + 2) - 0.5) * jitter) * S
				local wc = corridorWeight(x, z)
				local beltOnly = false -- the far belt plants only _Far variants; a belt spot near a side road or a capture eye stays empty (a near tree there would cost 8x the tris)
				if belt and wc <= 0.001 then
					wc, beltOnly = beltWeight(x, z, rule), true
				end
				-- Early out before the terrain sample: the chance can never exceed Base * corridor * 1.6 (grass loves a clearing).
				if wc > 0 and rand(gi, gj, rule.Salt * 10 + 3) < rule.Base * wc * 1.6 and not hostile(x, z, class, list, roadSegs, lanes, rule.Tall == true) then
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
						factor *= 1 - rule.Clearing * clearingFactor(x, z)
						local glade = gladeWeight(x, z)
						if rule.Cluster then -- groves and gaps
							local c = rule.Cluster
							factor *= c.Floor + (1 - c.Floor) * smooth((SliceDressing.cluster(x, z) - c.Lo) / (c.Hi - c.Lo))
						end
						if rule.Roadside then -- crowns reach over the road: denser just past the written road edge (the road blends out by ~21 studs)
							factor *= 1 + rule.Roadside * (1 - smooth((nearRoad(x, z) - 20) / 16))
						end
						if rule.Gap then -- understory favours canopy gaps and glades
							factor *= if underCrown(x, z) then rule.Under else rule.Gap
							factor *= 1 + (rule.Glade - 1) * glade
						end
						if rand(gi, gj, rule.Salt * 10 + 3) < rule.Base * wc * math.clamp(factor, 0, 1.6) then
							local pick = pickPiece(rule, rand(gi, gj, rule.Salt * 10 + 4))
							local isFar = belt and farFrom(x, z) > SliceDressing.FarSwitch
							if isFar then
								pick ..= "_Far" -- low-tri variant, same bbox
							end
							local piece = P[pick]
							local scale = rule.Scale[1] + (rule.Scale[2] - rule.Scale[1]) * rand(gi, gj, rule.Salt * 10 + 5)
							local fits = isFar or not beltOnly
							if class == "Tree" then
								local lift = piece.Under * piece.Size[2] - piece.Sink -- underside above the foot at scale 1
								if nearRoad(x, z) < piece.Radius * scale and lift * scale < SliceDressing.RoadClearance then
									scale = SliceDressing.RoadClearance / lift + 0.01 -- an overhanging crown clears the road, or is not planted
									fits = scale <= rule.Scale[2]
								end
								if glade > 0 then
									for _, g in glades do
										if worldDist(x, z, g.X, g.Z) < g.R then fits = false end
									end
								end
							end
							local radius, trunk = piece.Radius * scale, piece.Trunk * scale
							if fits and not blocksSight(x, z, h, piece, scale) and (class == "Grass" or not crowded(x, z, class, radius, trunk)) then
								n += 1
								accept(class, string.format("%s_%04d", class, n), pick, x, z, h, scale, if rule.FaceDownhill then math.deg(math.atan2(-sx, -sz)) / 360 else rand(gi, gj, rule.Salt * 10 + 6), radius, trunk, false)
							end
						end
					end
				end
			end
		end
		byClass[class] = n
	end

	-- Forest floor round the glade altar (fault D): ferns, grass and a few small rocks in the ring Inner..Outer; the pad inside stays clear.
	local F: any = SliceDressing.Floor
	local ap = Overworld.Altars[F.Altar].Placement
	local fs, floorN, floorRocks = F.Spacing, { Fern = 0, Grass = 0, Rock = 0, Flower = 0 }, 0
	for gi = math.floor((ap.X - F.Outer) / fs), math.ceil((ap.X + F.Outer) / fs) do
		for gj = math.floor((ap.Z - F.Outer) / fs), math.ceil((ap.Z + F.Outer) / fs) do
			local x, z = (gi + rand(gi, gj, 71)) * fs, (gj + rand(gi, gj, 72)) * fs
			local d = worldDist(x, z, ap.X, ap.Z)
			if d >= F.Inner and d <= F.Outer and rand(gi, gj, 73) < F.Chance then
				local class = if rand(gi, gj, 74) < F.RockChance and floorRocks < F.Rocks then "Rock" elseif rand(gi, gj, 78) < F.Flower then "Flower" elseif rand(gi, gj, 75) < F.Fern then "Fern" else "Grass"
				local rule: any = (SliceDressing.Scatter :: any)[class]
				local pick = if class == "Rock" then F.RockPiece else pickPiece(rule, rand(gi, gj, 79))
				local range = if class == "Rock" then F.RockScale else rule.Scale
				local scale = range[1] + (range[2] - range[1]) * rand(gi, gj, 76)
				local piece = P[pick]
				if not hostile(x, z, class, listNoAltar, roadSegs, lanes, false) then
					local h, roadW, channelW, chasmW = Overworld.sampleAt(x, z)
					local sx, sz = (Overworld.heightAt(x + 4, z) - h) / 4, (Overworld.heightAt(x, z + 4) - h) / 4
					if roadW < 0.5 and channelW < 0.05 and chasmW < 0.01 and h > 3 and math.sqrt(sx * sx + sz * sz) < rule.MaxSlope
						and not blocksSight(x, z, h, piece, scale) and (class == "Grass" or not crowded(x, z, class, piece.Radius * scale, piece.Trunk * scale)) then
						floorN[class] += 1
						floorRocks += if class == "Rock" then 1 else 0
						byClass[class] += 1
						accept(class, string.format("Floor_%s_%03d", class, floorN[class]), pick, x, z, h, scale, rand(gi, gj, 77), piece.Radius * scale, piece.Trunk * scale, true)
					end
				end
			end
		end
	end

	-- Totals and per-cell lists. A cell needs its own tile and every tile a hero footprint reaches (ground for the raycast).
	local cells: { [string]: any } = {}
	local meshParts, placeholderParts, tris, trisLod = 0, 0, 0, 0
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
		if pl.Kind == "Hero" then
			local r = piece.Radius * pl.Scale
			for _, dx in { -r, 0, r } do
				for _, dz in { -r, 0, r } do
					c.Needs[SliceDressing.cellOf(pl.X + dx, pl.Z + dz)] = true
				end
			end
		end
	end
	built = { Placements = placements, Counts = counts, ByClass = byClass, Cells = cells, MeshParts = meshParts, PlaceholderParts = placeholderParts, Tris = tris, TrisLod = trisLod,
		Bounds = { X0 = x0, X1 = x1, Z0 = z0, Z1 = z1 }, SetStats = setStats, Lanes = lanes, RoadSegments = roadSegs, Sights = sights, Glades = glades }
	return built
end

-- Review cameras with the eye resolved on the ground: { Id, Note, From = { X, Y, Z }, To = { X, Y, Z } }.
function SliceDressing.captures(): { any }
	local result = SliceDressing.build()
	local out: { any } = {}
	local function at(x: number, z: number, dy: number): any
		return { X = x, Y = Overworld.heightAt(x, z) + dy, Z = z }
	end
	local function onRoute(arc: number, off: number): (number, number)
		local px, pz, tx, tz = SliceDressing.pointAt(arc)
		return px - tz * off, pz + tx * off
	end
	for _, c: any in SliceDressing.Captures do
		local fx, fz = if c.From then c.From.X else 0, if c.From then c.From.Z else 0
		if c.FromArc then
			fx, fz = onRoute(c.FromArc, c.FromOff or 0)
		end
		local tx, tz, ty = 0, 0, c.ToDy or 0
		if c.ToHero then
			for _, pl in result.Placements do
				if pl.Id == c.ToHero then
					tx, tz = pl.X, pl.Z
					if c.ToFrac then -- aim at a fraction of the piece's height above the ground (scale is resolved at build)
						ty = c.ToFrac * SliceDressing.Pieces[pl.Piece].Size[2] * pl.Scale
					end
				end
			end
		elseif c.ToArc then
			tx, tz = onRoute(c.ToArc, c.ToOff or 0)
		end
		table.insert(out, { Id = c.Id, Note = c.Note, From = at(fx, fz, SliceDressing.Eye), To = at(tx, tz, ty) })
	end
	return out
end

return SliceDressing

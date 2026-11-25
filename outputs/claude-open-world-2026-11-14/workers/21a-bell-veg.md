# 21a Bellwood vegetation (M1 headless)

Script: tools/blender/overworld/bellwood_veg.py (`blender -b -P`, rebuilds everything: textures, geometry, GLBs, upload pack, renders).
Out: assets/source/overworld/bellwood_veg/ ; upload pack: assets/source/overworld/upload/bellwood_veg/ ; renders: outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/. Registry target (no IDs yet): assets/BELLWOOD_KIT_UPLOADED.json.

## PIECE LIST (build order = priority)
Trees: Canopy_Tree_C, Canopy_Tree_D (broadleaf), Conifer_Tall, Old_Gnarled_Tree, Sapling_Tree
Deadwood: Dead_Standing_Trunk, Fallen_Log_A, Fallen_Log_B, Tree_Stump_A, Tree_Stump_B, Exposed_Roots_A, Exposed_Roots_B
Shrubs: Shrub_Hazel, Shrub_Thicket, Shrub_Berry
Ferns: Fern_Bracken, Fern_Sword
Flowers: Flowers_Daisy, Flowers_Foxglove
Fungi: Mushroom_Cluster
Hanging: Vine_Hanging, Moss_Drape
Wet edge: Reed_Clump_A, Reed_Clump_B
Grass: Grass_Tall, Grass_Lush, Grass_Seed

## Progress (appended per piece by the script)

## Status (final run: 27/27 pieces built, exported, rendered)
- All sub-meshes < 18000 tris (asserted in obj() and on the exported GLB). Largest sub-mesh: Canopy_Tree_C__Leaves_Detail 12064.
- Extra renders: vignette_forest_floor_player.png, vignette_forest_high.png, vignette_wet_edge_player.png (same folder as the per-piece eye_*.png).
- Rebuild everything: `blender -b -P tools/blender/overworld/bellwood_veg.py` (VEG_ONLY=Name,Name for a subset; re-running appends progress lines again).
- Not done / known limits: no LOD variants; Exposed_Roots_A still reads as a low spider-like buttress set at distance; Bell_Conifer / Bell_Bloom / Bell_Mushroom are flat-colour atlases (no per-leaf alpha cards); registry IDs empty (nothing uploaded).
- Canopy_Tree_C: sub-meshes {"Canopy_Tree_C__Bark": 1982, "Canopy_Tree_C__Leaves_Detail": 12064, "Canopy_Tree_C__Leaves_Mass": 4320}; tris 18366; size [38.65, 49.59, 42.33] studs; GLB 2739 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Canopy_Tree_C.png
- Canopy_Tree_D: sub-meshes {"Canopy_Tree_D__Bark": 1984, "Canopy_Tree_D__Leaves_Detail": 12064, "Canopy_Tree_D__Leaves_Mass": 4320}; tris 18368; size [45.16, 37.31, 45.52] studs; GLB 2739 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Canopy_Tree_D.png
- Conifer_Tall: sub-meshes {"Conifer_Tall__Bark": 3828, "Conifer_Tall__Needles_Detail": 7120, "Conifer_Tall__Needles_Mass": 14112}; tris 25060; size [26.94, 68.45, 29.53] studs; GLB 2838 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Conifer_Tall.png
- Old_Gnarled_Tree: sub-meshes {"Old_Gnarled_Tree__Bark": 1482, "Old_Gnarled_Tree__Leaves_Detail": 5136, "Old_Gnarled_Tree__Leaves_Mass": 3456}; tris 10074; size [35.06, 31.17, 28.73] studs; GLB 2334 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Old_Gnarled_Tree.png
- Sapling_Tree: sub-meshes {"Sapling_Tree__Bark": 724, "Sapling_Tree__Leaves_Detail": 5064, "Sapling_Tree__Leaves_Mass": 2016}; tris 7804; size [20.94, 16.89, 22.8] studs; GLB 2270 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Sapling_Tree.png
- Fallen_Log_A: sub-meshes {"Fallen_Log_A__Bark": 1220, "Fallen_Log_A__Ends": 14, "Fallen_Log_A__Moss": 640}; tris 1874; size [30.26, 10.26, 16.27] studs; GLB 3986 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Fallen_Log_A.png
- Fallen_Log_B: sub-meshes {"Fallen_Log_B__Bark": 520, "Fallen_Log_B__Ends": 28, "Fallen_Log_B__Moss": 400}; tris 948; size [17.93, 6.78, 6.23] studs; GLB 3962 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Fallen_Log_B.png
- Tree_Stump_A: sub-meshes {"Tree_Stump_A__Bark": 756, "Tree_Stump_A__Ends": 18, "Tree_Stump_A__Moss": 400}; tris 1174; size [18.24, 6.95, 17.95] studs; GLB 3968 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Tree_Stump_A.png
- Tree_Stump_B: sub-meshes {"Tree_Stump_B__Bark": 676, "Tree_Stump_B__Ends": 18, "Tree_Stump_B__Moss": 480}; tris 1174; size [14.84, 9.19, 13.83] studs; GLB 3968 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Tree_Stump_B.png
- Dead_Standing_Trunk: sub-meshes {"Dead_Standing_Trunk__Bark": 794, "Dead_Standing_Trunk__Ends": 14}; tris 808; size [15.29, 39.55, 13.32] studs; GLB 2494 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Dead_Standing_Trunk.png
- Exposed_Roots_A: sub-meshes {"Exposed_Roots_A__Bark": 676, "Exposed_Roots_A__Moss": 480}; tris 1156; size [21.45, 5.86, 21.17] studs; GLB 2711 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Exposed_Roots_A.png
- Exposed_Roots_B: sub-meshes {"Exposed_Roots_B__Bark": 914, "Exposed_Roots_B__Moss": 400}; tris 1314; size [18.68, 5.12, 17.25] studs; GLB 2718 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Exposed_Roots_B.png
- Shrub_Hazel: sub-meshes {"Shrub_Hazel__Leaves": 2896, "Shrub_Hazel__Stems": 1980}; tris 4876; size [12.09, 7.73, 9.36] studs; GLB 2150 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Shrub_Hazel.png
- Shrub_Thicket: sub-meshes {"Shrub_Thicket__Leaves": 4000, "Shrub_Thicket__Stems": 2844}; tris 6844; size [14.64, 11.2, 13.59] studs; GLB 2239 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Shrub_Thicket.png
- Shrub_Berry: sub-meshes {"Shrub_Berry__Berries": 2880, "Shrub_Berry__Leaves": 2992, "Shrub_Berry__Stems": 2124}; tris 7996; size [7.5, 4.61, 6.42] studs; GLB 2486 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Shrub_Berry.png
- Fern_Bracken: sub-meshes {"Fern_Bracken__Fronds": 1296}; tris 1296; size [11.72, 3.11, 12.97] studs; GLB 168 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Fern_Bracken.png
- Fern_Sword: sub-meshes {"Fern_Sword__Fronds": 3808}; tris 3808; size [10.64, 3.61, 10.86] studs; GLB 340 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Fern_Sword.png
- Flowers_Daisy: sub-meshes {"Flowers_Daisy__Blooms": 2304, "Flowers_Daisy__Stems": 672}; tris 2976; size [6.53, 4.3, 7.33] studs; GLB 432 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Flowers_Daisy.png
- Flowers_Foxglove: sub-meshes {"Flowers_Foxglove__Blooms": 2064, "Flowers_Foxglove__Stems": 276}; tris 2340; size [6.92, 5.48, 6.19] studs; GLB 399 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Flowers_Foxglove.png
- Mushroom_Cluster: sub-meshes {"Mushroom_Cluster__Caps": 3360}; tris 3360; size [8.05, 3.67, 7.27] studs; GLB 266 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Mushroom_Cluster.png
- Vine_Hanging: sub-meshes {"Vine_Hanging__Bark": 1386, "Vine_Hanging__Leaves": 1888}; tris 3274; size [14.66, 19.14, 9.56] studs; GLB 2069 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Vine_Hanging.png
- Moss_Drape: sub-meshes {"Moss_Drape__Bark": 230, "Moss_Drape__Moss": 330}; tris 560; size [13.11, 19.1, 11.96] studs; GLB 1291 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Moss_Drape.png
- Reed_Clump_A: sub-meshes {"Reed_Clump_A__Blades": 414}; tris 414; size [5.53, 6.99, 5.93] studs; GLB 77 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Reed_Clump_A.png
- Reed_Clump_B: sub-meshes {"Reed_Clump_B__Blades": 270, "Reed_Clump_B__Heads": 608}; tris 878; size [8.26, 9.69, 8.05] studs; GLB 344 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Reed_Clump_B.png
- Grass_Tall: sub-meshes {"Grass_Tall__Blades": 490}; tris 490; size [6.39, 4.93, 6.17] studs; GLB 82 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Grass_Tall.png
- Grass_Lush: sub-meshes {"Grass_Lush__Blades": 450}; tris 450; size [6.42, 2.27, 5.71] studs; GLB 80 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Grass_Lush.png
- Grass_Seed: sub-meshes {"Grass_Seed__Blades": 336, "Grass_Seed__Seeds": 768}; tris 1104; size [5.62, 5.38, 5.84] studs; GLB 379 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Grass_Seed.png
- Reed_Clump_B: sub-meshes {"Reed_Clump_B__Blades": 270, "Reed_Clump_B__Heads": 608}; tris 878; size [8.26, 9.69, 8.05] studs; GLB 336 KB; render outputs/claude-open-world-2026-11-14/captures/kit/bellwood_veg/eye_Reed_Clump_B.png

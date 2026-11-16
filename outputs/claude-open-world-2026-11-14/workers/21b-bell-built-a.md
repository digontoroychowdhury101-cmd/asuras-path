# 21b Bellwood rock + built A (headless lane M2)

Script: tools/blender/overworld/bellwood_built_a.py (blender -b). Out: assets/source/overworld/bellwood_built_a/, upload pack: assets/source/overworld/upload/bellwood_built_a/, renders: outputs/claude-open-world-2026-11-14/captures/kit/bellwood_built_a/. Registry target: assets/BELLWOOD_KIT_UPLOADED.json (no IDs yet).

## PIECE LIST (priority order)
1. Stairs: Bell_Stair_Straight (A/B variants), Bell_Stair_Turn (90 deg landing + treads)
2. Walls: Bell_Retain_Wall_Short, Bell_Retain_Wall_Long, Bell_Retain_Wall_Corner
3. Paving: Bell_Paving_A, Bell_Paving_B; edging: Bell_Edging_A, Bell_Edging_B
4. Rocks: Boulder_Granite_D, Boulder_Granite_Split, Scree_Patch_A/B, Outcrop_Mossy, Cliff_Face_A/B/C (tileable edges)
5. Gate_Side (small timber side gate), Fence_Rail, Fence_Picket, Fence_Post
6. Shrine_Roadside, Bell_Grave_A/B/C, Prayer_Flags_Short/Long, Signpost_A/B, Well_Stone

## PROGRESS (appended per piece)
- Bell_Stair_Straight_A: built, sub-meshes {"Stone": 7392}
- Bell_Stair_Straight_B: built, sub-meshes {"Stone": 5896}
- Bell_Stair_Turn: built, sub-meshes {"Stone": 8976}
- Bell_Retain_Wall_Short: built, sub-meshes {"Stone": 5456}
- Bell_Retain_Wall_Long: built, sub-meshes {"Stone": 3696, "Stone2": 6336}
- Bell_Retain_Wall_Corner: built, sub-meshes {"Stone": 7392}
- Bell_Paving_Flag: built, sub-meshes {"Stone": 2156}
- Bell_Paving_Sett: built, sub-meshes {"Stone": 9388}
- Bell_Edging_Kerb: built, sub-meshes {"Stone": 528}
- Bell_Edging_Cobble: built, sub-meshes {"Stone": 1920}
- Boulder_Granite_D: built, sub-meshes {"Stone": 8320}
- Boulder_Granite_Split: built, sub-meshes {"Stone": 11520}
- Scree_Patch_A: built, sub-meshes {"Stone": 7600}
- Scree_Patch_B: built, sub-meshes {"Stone": 11600}
- Outcrop_Mossy: built, sub-meshes {"Stone": 9600}
- Cliff_Face_A: built, sub-meshes {"Stone": 7146}
- Cliff_Face_B: built, sub-meshes {"Stone": 7146}
- Cliff_Face_C: built, sub-meshes {"Stone": 7146}
- Bell_Timber_Gate_Side: built, sub-meshes {"Timber": 496, "Stone": 352, "Bronze": 536}
- Bell_Fence_Rail: built, sub-meshes {"Timber": 468}
- Bell_Fence_Picket: built, sub-meshes {"Timber": 948}
- Bell_Fence_Post: built, sub-meshes {"Timber": 84, "Stone": 352, "Bronze": 484}
- Bell_Shrine_Roadside: built, sub-meshes {"Stone": 1760, "Timber": 464, "Roof": 1088, "Bronze": 464}
- Bell_Grave_A: built, sub-meshes {"Stone": 660, "Mound": 320, "Bronze": 424, "Timber": 88}
- Bell_Grave_B: built, sub-meshes {"Stone": 1456, "Mound": 320, "Bronze": 480}
- Bell_Grave_C: built, sub-meshes {"Stone": 704, "Mound": 320, "Bronze": 444}
- Bell_Prayer_Flags_Short: built, sub-meshes {"Timber": 302, "Stone": 352, "Cloth": 288}
- Bell_Prayer_Flags_Long: built, sub-meshes {"Timber": 302, "Stone": 352, "Cloth": 672}
- Bell_Signpost_A: built, sub-meshes {"Timber": 92, "Stone": 176, "Bronze": 144}
- Bell_Signpost_B: built, sub-meshes {"Timber": 104, "Stone": 704, "Bronze": 442}
- Bell_Well: built, sub-meshes {"Stone": 11616, "Timber": 284, "Roof": 1088, "Bronze": 118}

## DONE (31 pieces, max sub-mesh 11,616 tris, pack check: none)
Master: assets/source/overworld/bellwood_built_a/ (GLBs, maps/, manifest.json, .blend). Upload pack: assets/source/overworld/upload/bellwood_built_a/ (GLBs, maps/, upload_manifest.json, registry target assets/BELLWOOD_KIT_UPLOADED.json, no IDs). Renders: outputs/claude-open-world-2026-11-14/captures/kit/bellwood_built_a/eye_<Piece>.png (3/4, eye 5 studs, 5.5-stud figure) + tiling_cliffs, tiling_paving_edging, assembly_walls_stairs.
Final names differ slightly from the list: Bell_Stair_Straight_A/B, Bell_Paving_Flag/Sett, Bell_Edging_Kerb/Cobble, Bell_Timber_Gate_Side, Bell_Well. New material Bell_Flag (cloth atlas). Not done: dedicated 2nd/3rd variants of walls beyond short/long/corner; cliff B/C are smooth-faced.

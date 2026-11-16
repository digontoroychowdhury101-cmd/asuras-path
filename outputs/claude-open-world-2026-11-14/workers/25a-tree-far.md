# 25a Bellwood far-tree LOD variants (lane M8, headless Blender)

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

- Supersedes: nothing (searched `**/*bellwood_far*` and workers/*, no earlier far/LOD tree work; slice_kit.py only notes "Leaves_Mass is the distance LOD" in prose).
- Linked from LEDGER.md: lane M8 row (the lead adds the link; this lane may not edit LEDGER.md).
- Why a new file: per-lane worker log required by the run rule; existing packs (bellwood_veg, slice) must not be modified.

## Scope
Six tree forms: Canopy_Tree_A, Canopy_Tree_B (slice pack), Canopy_Tree_C, Canopy_Tree_D, Conifer_Tall, Old_Gnarled_Tree (bellwood_veg pack). Sapling_Tree is not a distant tree, skipped.
Piece names are the real near names + `_Far` (e.g. Canopy_Tree_A_Far); sub-meshes `<Piece>_Far__Bark`, `<Piece>_Far__Leaves` (conifer `__Needles`).

## Method (tools/blender/overworld/bellwood_far.py, `blender -b -P`)
1. Import near GLB (read-only), take Bark, Leaves_Mass, Leaves_Detail verts.
2. Bark: collapse-decimate to ~200-300 tris.
3. Canopy: k-means the leaf verts into 10-14 clusters, one 80-tri ellipsoid lump per cluster (~900-1100 tris). Conifer: height tiers of 12-sided frusta from per-slice radial extent.
4. Affine-fit the whole far mesh so its bbox equals the near bbox exactly (same pivot, same silhouette extremes).
5. Bake a 256x128 albedo atlas (bark half + leaf half) by box-downscaling the near Bell_Bark/Bell_Leaf/Bell_Conifer colour maps. Colour only (no normal/roughness).
6. Export GLB (same exporter settings as near), build upload pack (format of upload/bellwood_veg), UPLOAD.md.
7. Render near vs far side by side at 60, 150, 300 studs per form; view and recommend a switch distance.

## Files
- NEW tools/blender/overworld/bellwood_far.py
- NEW assets/source/overworld/bellwood_far/*.glb, bellwood_far.blend, maps/
- NEW assets/source/overworld/upload/bellwood_far/*.glb, maps/, upload_manifest.json, UPLOAD.md
- NEW outputs/claude-open-world-2026-11-14/captures/kit/bellwood_far/*.png
- this file

## Checkpoints
- [export] Canopy_Tree_A_Far: far 1499 tris (10.2% of near 14742); sub-meshes {'Canopy_Tree_A_Far__Bark': 299, 'Canopy_Tree_A_Far__Leaves': 1200}; size [39.7, 44.23, 41.11] vs near [39.7, 44.23, 41.11]; max bbox edge delta 0.0 studs; GLB 87 KB; atlas 256x128
- [render] Canopy_Tree_A: Canopy_Tree_A_60.png, Canopy_Tree_A_150.png, Canopy_Tree_A_300.png (near left, far right; Roblox 70 deg FOV, eye 6 studs)
- [export] Canopy_Tree_B_Far: far 1499 tris (7.6% of near 19660); sub-meshes {'Canopy_Tree_B_Far__Bark': 299, 'Canopy_Tree_B_Far__Leaves': 1200}; size [31.83, 58.6, 30.79] vs near [31.83, 58.6, 30.79]; max bbox edge delta 0.0 studs; GLB 87 KB; atlas 256x128
- [render] Canopy_Tree_B: Canopy_Tree_B_60.png, Canopy_Tree_B_150.png, Canopy_Tree_B_300.png (near left, far right; Roblox 70 deg FOV, eye 6 studs)
- [export] Canopy_Tree_C_Far: far 1496 tris (8.1% of near 18366); sub-meshes {'Canopy_Tree_C_Far__Bark': 296, 'Canopy_Tree_C_Far__Leaves': 1200}; size [38.65, 49.59, 42.33] vs near [38.65, 49.59, 42.33]; max bbox edge delta 0.0 studs; GLB 87 KB; atlas 256x128
- [render] Canopy_Tree_C: Canopy_Tree_C_60.png, Canopy_Tree_C_150.png, Canopy_Tree_C_300.png (near left, far right; Roblox 70 deg FOV, eye 6 studs)
- [export] Canopy_Tree_D_Far: far 1495 tris (8.1% of near 18368); sub-meshes {'Canopy_Tree_D_Far__Bark': 295, 'Canopy_Tree_D_Far__Leaves': 1200}; size [45.16, 37.31, 45.52] vs near [45.16, 37.31, 45.52]; max bbox edge delta 0.0 studs; GLB 87 KB; atlas 256x128
- [render] Canopy_Tree_D: Canopy_Tree_D_60.png, Canopy_Tree_D_150.png, Canopy_Tree_D_300.png (near left, far right; Roblox 70 deg FOV, eye 6 studs)
- [export] Conifer_Tall_Far: far 984 tris (3.9% of near 25060); sub-meshes {'Conifer_Tall_Far__Bark': 216, 'Conifer_Tall_Far__Needles': 768}; size [26.94, 68.45, 29.53] vs near [26.94, 68.45, 29.53]; max bbox edge delta 0.0 studs; GLB 81 KB; atlas 256x128
- [render] Conifer_Tall: Conifer_Tall_60.png, Conifer_Tall_150.png, Conifer_Tall_300.png (near left, far right; Roblox 70 deg FOV, eye 6 studs)
- [export] Old_Gnarled_Tree_Far: far 1198 tris (11.9% of near 10074); sub-meshes {'Old_Gnarled_Tree_Far__Bark': 238, 'Old_Gnarled_Tree_Far__Leaves': 960}; size [35.06, 31.17, 28.73] vs near [35.06, 31.17, 28.73]; max bbox edge delta 0.0 studs; GLB 80 KB; atlas 256x128
- [render] Old_Gnarled_Tree: Old_Gnarled_Tree_60.png, Old_Gnarled_Tree_150.png, Old_Gnarled_Tree_300.png (near left, far right; Roblox 70 deg FOV, eye 6 studs)

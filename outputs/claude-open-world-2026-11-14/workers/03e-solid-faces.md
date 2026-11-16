# 03e solid faces (lane 4c, source only, no Studio)

Cause confirmed in a pure harness: the fixed 12-stud shell left see-through gaps between neighbouring columns on steep faces (old shell gaps over 1 voxel: east edge 1472, south edge 168, SW coast 2 597; none on gentle tiles).

Fix: `Overworld.shellBottom(hs, i, j, shell)` (TERRAIN section of src/shared/Overworld.luau) returns min(own surface, lowest of 8 neighbours) minus shell. `OverworldTerrain.writeTile` samples a one-column margin all round and fills each column down to that bottom; `tile.Floor` is the lowest bottom (fall-through margin and Clear still bound it). C3 guard, site ranks and Refocus/Verdict/RescueAltar untouched.

Voxels (non-air, pure count): east edge tile x2.22, south edge x1.56, SW coast 2 x1.33, summit north face x1.25 / x1.23, N cliffs x1.15, clearing (flat meadow) x1.07; whole-frame grid sample (tile every 7th) x1.098. Flat columns identical.

Tests: tools/test_overworld_terrain.luau section 13 (88 passed), test_overworld_order via lune_compat (438 passed, generation sim gaps and site ordering pass), lune_compat --all clean, plain-luau encounters 2307 and world_map 435 passed, luau-compile --null ok, scratch build l4c.rbxlx ok.

Studio must confirm: east/south edge and SW coast show no holes; writing time and TerrainVoxels MB (about 1.1x voxels expected, steep edge tiles up to 2x); no 1-voxel sheets on N cliffs.

# 12b Slice dressing (Gateway Glade to Bell Terrace) - lane 6c source, no Studio

Supersedes: nothing (searched workers/ and *SliceDressing*: none). Linked from CONTINUATION.md row L6c; lead links from LEDGER.
Files: src/shared/SliceDressing.luau, src/server/Services/SliceDressingService.luau, tools/test_slice_dressing.luau.
Read-only inputs: Overworld.luau, OverworldService.luau, assets/source/overworld/slice/manifest.json, 12a-slice-kit.md, issues/12, LEDGER C2 sign-off.

## Log
- [start] read manifest, 12a, Overworld (roads via terrainData().Roads, heightAt/surfaceAt, Altars/Rings/Encounters/Blockout), OverworldService (Ready(area), SiteReady_<altar> attrs, Terrain.Manifest tiles). Next: probe road/terrain numbers, write SliceDressing.
- [probe] Run Luau probes from scratchpad (not repo). Facts: main road F1>F2 = 38 pts, 1100 studs, grade <= 0.10, +Z south, +X east, road ends on Bell Terrace altar (-3000,140,-2000). Altar plateau flat 140 to z~-1975 then drops to 132 by z~-1945 (x=-3000): terrace stair + walls go there. Flattest 67x67 patch: (-3020,-1900), relief 2.3 -> Pavilion (stair face north, yaw 180). Tower: (-2667,-1588) relief 8 at scale 1.5 (north of road, arc ~536). Warden home (-3060,-2060) leash 70, Fo01 (-2540,-1606), Fo02 (-2754,-1854) on/near road. Voxel surface = heightAt + 2 (Overworld.luau:128 note): service raycasts, fallback +2.
- [design] Placement Y = heightAt (data); Sink/lift only in service. Kit sizes: manifest Blender XYZ (Z up) -> Roblox {X, Y up, Z}. Cells = 128 = terrain tiles (key "i,j") so readiness = OverworldTerrain.Manifest[key].
- [file1] src/shared/SliceDressing.luau written (Pieces from manifest, Hero authored, Scatter/Keep rules, build(), captures()). Fix: first hash was xorshift (salts correlated, only tree A placed) -> murmur fmix32. Build ~1 s. Tuned densities: 1663 placements, 2470 kit MeshParts, 3.75M tris.
- [file2] src/server/Services/SliceDressingService.luau written (cells Atomic, landmarks Persistent, readiness = WaitReady Glade + Terrain.Manifest tiles, makePiece = swap point via ServerStorage/SliceKit templates, no asset ids). luau-compile --null ok.
- [file3] tools/test_slice_dressing.luau written. Round-3 kit landed mid-task (manifest round 3: shrub rework, Understory_Shrub_Small, Boulder_Granite_A/B/C, Stepping_Stones): data and test literal re-synced to manifest.json (python cross-check: 0 mismatches of 16). Forest_Boulder stand-in deleted. Road-verge fix: scatter only rejected on roadW >= 0.5 (0.05 left a 30 stud bare verge).
- [verify] luau-compile --null on all 3 files ok; luau.exe tools/test_slice_dressing.luau 177 pass; lune_compat on the test 193 pass (adds 16 service checks); lune_compat --all 39 PASS 0 FAIL. luau-analyze: only Roblox-global/type noise (no Roblox type defs here).
- [result] 1711 placements (hero 31 + scatter 1680): trees 157 (A 81, B 76), shrubs 227 (111 big, 116 small), ferns 268, grass 1005, boulders 25, lanterns 17, gates 2, walls 6, stair 1, stones 1, pavilion 1, tower 1. 2295 kit MeshParts / 2319 placeholder parts / 4.70M tris (2.94M with Leaves_Detail dropped). Budget 1900 / 3000 / 3400 / 5.0M (3.2M lod). 45 cells (<= 900 parts each). Build 1.3 s.

## WIRING FOR LEAD (I did not edit default.project.json or Bootstrap)
1. default.project.json, ReplicatedStorage/AsurasPath/Shared, after the "Overworld" entry (line ~269):
   "SliceDressing": { "$path": "src/shared/SliceDressing.luau" },
2. default.project.json, Services, after "OverworldService" (line ~527):
   "SliceDressingService": { "$path": "src/server/Services/SliceDressingService.luau" },
3. src/server/Bootstrap.server.luau:
   local SliceDressing = require(Services:WaitForChild("SliceDressingService") :: ModuleScript) :: any   -- with the other requires (~line 34)
   after `OverworldWorld.Start()` / `started.Overworld = true` (~line 370):  SliceDressing.Start(); started.SliceDressing = true
   in the teardown, before `if started.Overworld then pcall(OverworldWorld.Destroy)` (~line 97):  if started.SliceDressing then pcall(SliceDressing.Destroy) end
4. Studio import (swap point = makePiece in the service): import each GLB (3D Importer, one MeshPart per Piece__Sub, pivot foot centre) into ServerStorage/SliceKit/<Piece> as a Model; the service clones it instead of building placeholders. Piece front is local +Z for the pavilion, local -Z is the stair climb; if the importer flips, set SliceDressing.ImportYaw[piece] = 180 (one table, nothing else changes). Grass_Clump DoubleSided = true. Tri/part numbers above become real once the templates exist.
5. Client LOD: parts with attribute LodDetail = true are the Leaves_Detail sub-meshes (drop beyond ~150). Foliage parts carry tag AsuraFoliageShadow + AsuraShadowDistance 120 (LandscapeBudget). Part names are Piece__Sub, so "Lantern" names stay protected from its fade.
6. Terrain pads/materials are untouched; hero Y = heightAt, service raises ground by raycast (fallback heightAt + 2).

## SIX REVIEW CAPTURES (SliceDressing.captures(); eye = ground + 5)
01_glade_arrival  eye (-2203, 65.0, -1415) -> (-2254, 68.3, -1477) altar spawn down the road to the glade gate
02_road_lanterns  eye (-2319, 69.1, -1573) -> (-2431, 79.6, -1598) along the road: lanterns, canopy gap
03_understory     eye (-2685, 113.8, -1720) -> (-2650, 103.4, -1739) road edge into shrubs, ferns, grass
04_broken_tower   eye (-2520, 86.5, -1604) -> (-2667, 110.2, -1588) approach to the mid-route tower
05_pavilion_lane  eye (-2746, 128.4, -1834) -> (-3020, 187.6, -1900) pavilion above the trees through the cleared lane
06_terrace_stair  eye (-3000, 145.0, -1983) -> (-3020, 162.6, -1900) plateau looking down stair and walls at the pavilion court

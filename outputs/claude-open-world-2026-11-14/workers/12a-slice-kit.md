# 12a Slice kit (Bellwood: Gateway Glade to Bell Terrace) - lane 2 Blender

Scope: assets/source/overworld/slice/, tools/blender/overworld/, captures/slice/. No Studio, no src/.
Method: procedural bpy + numpy PBR maps (pattern from tools/blender/bamboo_karst_kit.py), run headless: Blender 5.2 `-b -P tools/blender/overworld/slice_kit.py -- <out>`.
Export scale: 1 Blender unit = 1 stud; foot/base centre at origin (z=0); GLB (glTF Y-up) one file per piece, textures embedded and also in maps/.
Licence of everything below: original procedural work for this project (no third-party assets, no generation credits spent).

Script: tools/blender/overworld/slice_kit.py (deterministic). Outputs: assets/source/overworld/slice/{Piece}.glb, maps/*.png (24), manifest.json, bellwood_slice_kit.blend.
Renders: captures/slice/{Piece}.png x10, vignette_player.png (eye 5 studs), vignette_high.png (Blender EEVEE, not Studio).

## Pieces (tris per sub-mesh, all < 18k; size in studs X,Y,Z; pivot base centre)
| Piece | Sub-meshes: tris | Size |
|---|---|---|
| Bell_Stair_Segment (10 steps, rise 0.8, tread 2, 12 wide; climbs +Y) | Stone 2200 | 12.4x20.2x11 |
| Bell_Lantern_Post | Stone 232, Bronze 248, Glow 44 | 4.1x4.1x10.6 |
| Bell_Timber_Gate (torii-like, vermilion-weathered) | Timber 392, Stone 88, Bronze 144 | 19x3.2x17.6 |
| Bell_Terrace_Wall (16 long, 8 high incl. coping, ruined end) | Stone 1540 | 16x3.6x9 |
| Bell_Tower_Broken (landmark; scale up for distance) | Stone 1584, Timber 176, Bronze 604 | 29x29x29.7 |
| Canopy_Tree_A (broad, lean to WNW) | Bark 562, Leaves 3520 | 33x30x49 |
| Canopy_Tree_B (tiered, slender) | Bark 896, Leaves 5120 | 25x25x57 |
| Understory_Shrub | Stems 182, Leaves 2560 | 7x7x6 |
| Fern_Clump | Fronds 528 | 10x11x4 |
| Grass_Clump | Blades 220 | 4x4.5x3.4 |

Textures (PNG, Color sRGB + Normal OpenGL + Roughness, Metal for bronze): Stone/Timber/Bark/Leaf 512x512, Bronze/Fern 256x256, Grass 128x256, LanternGlow 128x128 (Color+Roughness only). Tile scale: Stone/Timber/Bark 8 studs per repeat, Bronze 4. Leaf is a painted leaf-litter tile on spherical UVs.
Fern, Grass: double-sided (no alpha; leaflets/blades are real geometry). Foliage is opaque.
Licence/source: all original (procedural bpy + numpy, this repo). No Poly Haven/Sketchfab/generation used, no credits spent.
Upload: NOT done (blocked on lane 1 Studio import review first; no asset IDs invented).

## Log
- Script written, built twice; first Blender 5.2 run failed on Matrix.Rotation axis arg (fixed). Leaf blobs raised to icosphere subdiv 3. All sub-mesh asserts pass.
- Wall/vignette fix: wall back face seated at plateau front (was buried).
- Vignette viewed: stair + lanterns + gate + wall + trees read; trunks were near-black, brightened.
- Known weak spots: fern leaflets blocky, canopy blobs read stylised/bonsai at close range; no sway vertex colours exported (COLOR_0 would multiply albedo): lane 1 derives sway weight from height above the base pivot.

## Round 2
Rebuild everything: `"C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/slice_kit.py` (no args; defaults to this repo's paths; env `SLICE_R1=<dir of round-1 GLBs>` also writes the old-vs-new eye-height comparisons). All sub-mesh asserts (< 18000) pass. Round-1 renders kept as `*_r1.png`.
- Fern_Clump: blocky leaflets replaced by 12 pinnate fronds x 17 narrow pinna pairs (two-sided kites, real back faces), inner fronds taller. Fronds 2016 tris (was 528). Fern material now backface-culled (no DoubleSided needed). Render: eye_compare_Fern_Clump.png (old left, new right, eye 5 studs).
- Canopy_Tree_A: blob crown replaced by 3 limb tiers (forking limbs, drooping), 12 ragged foliage shelves, leaf sprays on top and beards under rims, bare trunk with snapped stubs to ~16 studs (gap at player height). Bark 1646, Leaves_Mass 3456, Leaves_Detail 9640. Size 39.7x41.1x44.2. eye_compare_Canopy_Tree_A.png.
- Canopy_Tree_B: 5 tiers (3-4 limbs each) of shelves + sprays, leader now reaches the top tuft. Bark 1868, Leaves_Mass 4896, Leaves_Detail 12896. Size 31.8x30.8x58.6. eye_compare_Canopy_Tree_B.png.
- Understory_Shrub: sprays + 3 low shelves + ground tufts. Stems 182, Leaves_Mass 504, Leaves_Detail 792. eye_compare_Understory_Shrub.png (still the weakest piece: shelves read as mounds).
- Bell_Terrace_Pavilion (NEW hero landmark, original): stepped stone plinth + 8-step stair on -Y, 4 weathered vermilion timber pillars, open bell storey, two upturned hipped tile roofs over a solid upper drum, bronze finial spire, original bronze bell (lathe, 28 seg) on a loop with striker log on chains. Stone 1364, Timber 3504, Roof 4096, Bronze 2700. Size 66.7x67.3x89.2 studs. New material Bell_Roof (512 slate/clay tile maps). Renders: Bell_Terrace_Pavilion.png, eye_pavilion_approach.png, pavilion_1000studs.png (70 deg vFOV 1920x1080, eye 5 studs, 1010 studs away: reads as a two-tier pagoda with gold spire above the tree line, ~65 px tall).
- Bronze patina reduced (pat only in hollows) so bell/lanterns stay bronze instead of teal/orange camouflage.
- Camera clip_end raised to 6000 (default clipped the far half of the pavilion in the 1000-stud shot).
- manifest.json: round, build command, tri_cap, tris_total per piece, LOD hint, studio_import_notes. Vignettes re-rendered (vignette_player.png, vignette_high.png, now with the pavilion beyond the gate).
- Studio import needs: import per sub-mesh (Piece__Sub), SurfaceAppearance per material from maps/, Grass_Clump DoubleSided = true, drop Leaves_Detail at distance (LOD), no upload done.

## Round 3
Same one-command rebuild (`blender -b -P tools/blender/overworld/slice_kit.py`); manifest.json round 3; all sub-mesh asserts < 18000 pass. 16 GLBs. No upload, no Studio, no src/.
- Understory_Shrub reworked (no foliage pads/mounds): vase of 6 forking, drooping woody stems (2 fork levels), leaf clusters only on twig tips + leaf pairs on the last twigs + a few low leaves, real sky gaps. Stems 2304, Leaves 3456; 9.3x7.7x7.4. New Understory_Shrub_Small (4 stems, scale 0.4): Stems 1332, Leaves 1904; 4.1x4.6x3.5. Leaves use a tiny UV patch (flat leaf colour; no dark edge blotches). Renders: eye_Understory_Shrub.png, eye_Understory_Shrub_Small.png. Sub-mesh "Leaves_Mass" no longer exists for shrubs.
- New material Bell_Granite (1024x1024 atlas, Color/Normal/Roughness): quadrants granite, moss, mud-stained base, lichen, picked per face by UV (never tiled; leave StudsPerTile default). Palette follows Forest terrain materialAt (Rock steep / LeafyGrass+Grass flat / Mud low).
- Boulder_Granite_A (rounded mossy boulder + 3 companions) Stone 8000, 17.2x10.5x7.8. Boulder_Granite_B (tall faceted outcrop + 2 blocks, flat shaded) Stone 7680, 12.3x7.6x10.6. Boulder_Granite_C (low flat-topped split ledge + rubble, walkable top) Stone 6720, 24.4x11.1x4.1. Rocks have flat buried bases (z >= -1).
- Stepping_Stones (7 stones, top 0.6 studs, S-curve along +Y, plus 2 rows of edge cobbles): Stone 6720, 15.8x21.9x2.2.
- Renders (eye 5 studs): eye_Boulder_Granite_A/B/C.png, eye_Stepping_Stones.png, new vignette_floor_player.png (clearing: path, rocks, both shrubs, ferns, grass, trees); vignette_player.png / vignette_high.png updated with stones + boulders + both shrub sizes; per-piece previews for all new pieces.
- Known weak spots: moss patches are per-face so edges are jagged at close range; stepping stones are one merged mesh (not separable); big shrub is ~7.4 studs tall (scale in Studio for taller/shorter).

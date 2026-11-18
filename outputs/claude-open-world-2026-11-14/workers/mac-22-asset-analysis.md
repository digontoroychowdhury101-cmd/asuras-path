# mac-22 asset analysis (offline, Python+Pillow only)

Supersedes: nothing. Linked from CONTINUATION.md "Mac resume — 2026-11-18" lane table. Why new: this lane's note. Instruction: lead's mac-22 analysis order.

## Plan
1. GLB dump script (work/mac-resume-2026-11-17/analysis22/glbdump.py): materials, images, COLOR_0, normals, per primitive.
2. Registry compare (BELLWOOD_KIT_UPLOADED.json, SLICE_KIT_UPLOADED.json, BELLWOOD_FAR_KIT_UPLOADED.json): colour/metal/rough map IDs per sub.
3. Far trees (bellwood_far), foliage + grass vs terrain colours in src/shared/SliceDressing.luau / Overworld.luau, trunks.

Files: upload/slice/{Bell_Terrace_Pavilion,Fern_Clump,Grass_Clump,Canopy_Tree_A/B}.glb; bellwood_built_a/{Bell_Shrine_Roadside,Bell_Well}; bellwood_built_b/{Cart_A,Cart_B,Crate_A/B/C,Hermit_Hut,Lantern_Stone}; bellwood_far/*; bellwood_veg/{Canopy_Tree_C/D,Grass_*,Fern_*}.

## Checkpoints
- Pavilion/Cart_A: Bell_Timber_Color 512 mean sRGB (45,24,16) lum 27.8, 54.5% px max<40; Roof colour lum 46.6 (9.5% near-black); no COLOR_0, no inverted normals (0%), all subs have ColorMap IDs. Packed MR images carry B=255 (metal) with metallicFactor=0 -> checking importer metal route.
- Built pieces: all dark ones share Bell_Timber_Color (lum 27.8) and/or Bell_Roof_Color (46.6); control Lantern_Stone Stone (lum 82.3) uses SAME MetalnessMap id 89863602509302 so metal map is not the discriminator. 0% inverted normals, NORMAL present, no COLOR_0 anywhere, 0 empty ColorMaps.
- Far trees: registry readback has ColorMap/Normal/Rough/Metal ALL EMPTY on all 12 subs (MeshId only); GLB far material = baseColorTexture only (no MR/normal), roughnessFactor 0.95 metal 0, doubleSided, one 256x128 PNG atlas shared by Bark+Leaves. Cause of lime/glossy: no SurfaceAppearance created by importer.
- Far atlas halves (256x128 RGB, all six same layout; UV bark u 0.02-0.48, leaves/needles u 0.52-0.98): bark half litmean (54,48,35) S .36 V .22; leaf half (51,94,28) S .69 V .37 (conifer needles (28,67,37)). Not neon in the PNG -> lime comes from missing SurfaceAppearance.
- Image stats (lit = max>=40): near leaf lit mean (69,118,31) H94 S.74 V.46, only 35% lit (rest black padding), MR rough(G) .62; bark (57,51,37) V.23 rough .80; timber lit (62,27,18) V.24 (45% lit); roof (43,50,47) V.22; grass (83,91,43) H70 S.55 V.36 rough .50; fern (45,87,27) S.69 V.34 rough .50. Terrain: Overworld sets no material colours/variants in source (only CampaignTerrain does: LeafyGrass tint (176,180,150) x AsuraGrass map mean (156,150,92) = (107,106,54), H58 S.50 V.42).
- Foliage: lit rough leaf .62 / grass .50 / fern .50 (no scalar to override in SurfaceAppearance; needs texture edit). Colour tint (Color3 <= 1 only darkens): leaf (0.84,0.78,1.0) -> (58,92,31); grass (0.80,0.95,1.0) -> (66,86,43). Lifts (timber/roof/bark) cannot be done by tint -> texture edit + re-upload.
- Grass cards: Keep.Road 8.5 from centreline (road half 8), Arrival 12, Scale 0.9-1.7, Spacing 11, Base 0.33; Grass_Tall/Seed reach 8-9 studs at 1.7x.
- DONE. Scripts: work/mac-resume-2026-11-17/analysis22/{glbdump,imgstats}.py, out/.

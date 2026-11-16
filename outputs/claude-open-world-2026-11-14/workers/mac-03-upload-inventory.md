# mac-03 upload inventory (lane I, read-only)

Plan: (1) survey assets/source/overworld/upload/* manifests, GLB sizes, maps, audio beds, registries and src requires; (2) summarise LEDGER upload order and register_uploads.py, then report. Nothing edited except this note.

Method: manifests read as JSON (python3 -I). GLB bytes from stat, never opened. Texture sizes from `sips -g`. Audio durations from `afinfo`. Triangle figures are the manifest's planned tris_total per sub-mesh, not measured on the GLB. Pack sub-mesh counts come from manifest "sub_meshes".

## 1. Upload packs (assets/source/overworld/upload/)

| Pack | Pieces | Sub-meshes | Max sub-mesh tris (which) | GLB total (bytes) | Largest GLB | PNG maps | Distinct px sizes | UPLOAD.md | upload_manifest.json |
|---|---|---|---|---|---|---|---|---|---|
| slice | 16 | 31 | 12,896 (Canopy_Tree_B__Leaves_Detail) | 48,155,612 | Boulder_Granite_B.glb 5,960,740 | 30 | 512² 15, 256² 7, 1024² 3, 128² 2, 128x256 3 | yes | yes |
| bellwood_veg | 27 | 58 | 14,112 (Conifer_Tall__Needles_Mass) | 50,731,460 | Fallen_Log_A.glb 4,082,092 | 33 | 512² 15, 256² 9, 128x256 9 | no | yes |
| bellwood_built_a | 31 | 57 | 11,616 (Bell_Well__Stone) | 120,136,560 | Bell_Grave_A.glb 8,336,972 | 19 | 512² 9, 256² 7, 1024² 3 | no | yes |
| bellwood_built_b | 16 | 46 | 15,360 (Falls_Alcove__Rock_Back) | 38,140,136 | Falls_Alcove.glb 9,398,992 | 24 | 512² 9, 256² 10, 1024² 3, 128² 2 | no | yes |
| bellwood_far | 6 | 12 | 1,200 (Canopy_Tree_A_Far__Leaves) | 523,512 | Canopy_Tree_C_Far.glb 89,736 | 6 | 256x128 6 | yes | yes |
| hero | 5 | 18 | 624 (Summit_Temple_Pagoda__Bronze) | 1,542,608 | Summit_Temple_Pagoda.glb 393,512 | 40 | 128² 40 | no | yes |
| amberfall | 45 | 91 | 16,720 (Amber_Aqueduct_Hero__Piers) | 166,809,472 | Amber_Cliff_Corner.glb 6,564,696 | 46 | 512² 27, 1024² 6, 256² 7, 128x256 3, 128² 3 | yes | yes |
| saltreach | 37 | 73 | 14,016 (Salt_Pine_A__Needles_Detail) | 112,237,408 | Saltreach_Gate_Statue.glb 8,453,260 | 46 | 512² 21, 256² 10, 128x256 9, 1024² 3, 128² 3 | yes | yes |
| frostmere | 32 | 79 | 17,504 (Frost_Cliff_Corner__Stone) | 145,991,052 | Frost_Prayer_Flags.glb 7,512,000 | 55 | 512² 42, 256² 4, 1024² 3, 128x256 3, 128² 3 | yes | yes |
| ashen | 34 | 68 | 16,004 (Ash_Crag__Stone) | 125,486,136 | Ash_Crag.glb 6,286,124 | 49 | 512² 30, 256² 7, 1024² 6, 128x256 3, 128² 3 | yes | yes |
| audio | (5 OGG, no pieces) | - | - | 1.8 MB folder (see section 1b) | - | 0 | - | no | no |

Notes:
- Piece count matches GLB file count in every pack. Manifest cap is 18,000 tris per sub-mesh (slice manifest `tri_cap_per_sub_mesh`); the highest planned sub-mesh is 17,504 (frostmere), under the cap.
- Every pack's manifest points its registry at a file that does not exist yet (see section 2). Each manifest carries `no_ids_yet: true`.
- Folder totals (du, incl. maps): amberfall 177M, frostmere 159M, ashen 139M, bellwood_built_a 124M, saltreach 121M, bellwood_veg 54M, bellwood_built_b 46M, slice 57M, hero 2.5M, bellwood_far 848K.
- The `maps/` subfolder in each pack holds loose PNGs (the GLBs embed the same maps, per the manifest `format` field).

### 1b. Audio beds (assets/source/overworld/upload/audio/)

No manifest in this folder. Files (all Ogg Vorbis, 2 ch, 44.1 kHz, afinfo duration 22.0 s each):

| File | Bytes |
|---|---|
| amberfall_ravine.ogg | 400,998 |
| ashen_stair.ogg | 379,305 |
| bellwood_forest_day.ogg | 418,161 |
| frostmere_snow.ogg | 289,938 |
| saltreach_basin_r2.ogg | 413,740 |

workers/17-audio.md confirms the five beds and says the wavs were not uploadable and the ogg/mp3 encode needed ffmpeg. The ogg files are present here. Its "upload BLOCKED" note is older than the LEDGER ruling in section 3.

## 2. Registries

Registry JSON files for the overworld packs: none exist. `ls assets/` finds no SLICE_, BELLWOOD_, BELLWOOD_FAR_, HERO_, AMBERFALL_, SALTREACH_, FROSTMERE_, ASHEN_ KIT_UPLOADED.json. Each manifest names its target:
- slice → assets/SLICE_KIT_UPLOADED.json
- bellwood_veg, bellwood_built_a, bellwood_built_b → assets/BELLWOOD_KIT_UPLOADED.json
- bellwood_far → assets/BELLWOOD_FAR_KIT_UPLOADED.json
- hero → assets/HERO_KIT_UPLOADED.json
- amberfall / saltreach / frostmere / ashen → assets/<BIOME>_KIT_UPLOADED.json

Generated registry modules expected by src/ (none exist in src/ or assets/):

| Require | file:line | pcall-guarded | Fallback when absent |
|---|---|---|---|
| SliceKitRegistry | src/shared/SliceDressing.luau:549 | yes, `pcall(function() return require(...Parent.SliceKitRegistry) end)` | falls through to Assets, then placeholder (documented at line 547) |
| AmberfallKitRegistry, SaltreachKitRegistry | src/shared/BiomeDressing.luau:1448-1449 (loop over the two names) | yes, `pcall` per module, requires `type(reg) == "table"` | pieces stay assets or silhouettes |

No require exists in src/ for FrostmereKitRegistry, AshenKitRegistry, BellwoodKitRegistry, or HeroKitRegistry. Those packs have no consumer module expected yet. Slice's own note (`SliceDressing.luau:544`) says the module is generated from assets/SLICE_KIT_UPLOADED.json after uploads.

Other src/ references are unrelated: the server dressing services (SliceDressingService.luau:13, BiomeDressingService.luau:19) describe the same registry shape. The WagerWorld, LootWorld pcall requires are for SanctuaryKit, not overworld.

## 3. Upload order (LEDGER.md)

Two LEDGER sections matter; the later one supersedes the earlier:
- "Upload authorisation" (line 252): creator approved uploads to their own account, folder approval is the creator's step, slice kit first. Audio beds prepared only at that point.
- "Creator published the place; uploads opened" (line 367, 13:03): Team Create is on, so the lead split into a TEST local copy and an UPLOAD window on the cloud place. Upload calls only in the UPLOAD window. The order given there is: lantern → verify in TEST Play → slice kit → Bellwood + hero → 5 audio beds → later biome kits.

Creator quote, 1 line (LEDGER line ~383): "Upload the five task audio beds too; that is approved."

Also recorded in the section: one uploader, registry checked before each upload, no re-uploads, checkpoint right after each ID. The earlier "Upload attempt" section (line 275) says the Studio route was CLOSED until the place was saved; the 13:03 section overrides that.

## 4. tools/assets/register_uploads.py

Takes one argument: a JSON file path. Reads `{"Audio": {key: "rbxassetid://N"}, "Textures": {...}, "Sky": {...}, "Models": {name: [part, ...]}}`. Every ID must match `rbxassetid://` followed by 6-20 digits, or it raises. Each Audio/Textures/Sky key must already exist as a slot in src/shared/PresentationAssets.luau. Each Models entry is a non-empty list of parts, and each part needs MeshId, ColorMap, NormalMap, RoughnessMap and MetalnessMap (all validated); Name is optional, used only for the markdown table. On success it rewrites the slot values in PresentationAssets.luau, marks matching entries in assets/PHASE5_IMPORT_QUEUE.json as uploaded, merges everything into assets/PHASE5_UPLOADED.json, and regenerates the PHASE5 table in assets/ASSET_IDS.md. It is Phase-5 only: it does not write any overworld *_UPLOADED.json registry, does not generate SliceKitRegistry or AmberfallKitRegistry modules, and writes into src/. The LEDGER's rule "every ID goes into an *_UPLOADED.json" therefore needs a separate step for the overworld packs. Not run in this lane.

## Flags
- No UPLOAD.md in bellwood_veg, bellwood_built_a, bellwood_built_b, hero (4 packs).
- Audio folder has no manifest and no durations list; durations taken from afinfo.
- Triangle counts are manifest plans, not measured on the GLBs.
- No instructions directed at me were found in the files read.

# 23c Frostmere Heads kit (M6, headless Blender only)

Supersedes: nothing. An earlier search (glob over tools/blender/overworld/*.py, outputs/claude-open-world-2026-11-14/**/*rostmere*, assets/source/overworld/**/*rostmere*) found no Frostmere kit scripts, packs or notes; the only Frostmere file is the audio bed assets/source/overworld/upload/audio/frostmere_snow.ogg. The Snow_Watch_Beacon blockout in assets/source/overworld/hero/ (hero_silhouettes.py) stays as the placeholder; this kit adds a refined beacon beside it.
Linked from LEDGER.md: not edited by this lane (LEDGER.md is outside the files this lane may write); the lane lead links this note from the LEDGER.md worker table.
Why a new file: the per-lane progress note the task requires, holding the plan, file list and one checkpoint line per family.

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Plan (one script run + export + render per family; pattern copied from the finished Amberfall kit)
Scripts (tools/blender/overworld/): frostmere_common.py (execs amberfall_common.py, then repoints paths, registry, materials and render look), frostmere_veg.py, frostmere_rock.py, frostmere_built.py, frostmere_hero.py, frostmere_pack.py (stdlib: merges part JSONs into the pack manifest + UPLOAD.md).
Out: assets/source/overworld/frostmere/ (GLB, maps, parts/<family>.json, .blend); pack assets/source/overworld/upload/frostmere/ (upload_manifest.json, UPLOAD.md, maps/, GLBs); renders outputs/claude-open-world-2026-11-14/captures/kit/frostmere/. Registry target (no IDs): assets/FROSTMERE_KIT_UPLOADED.json.
Palette (src/shared/BiomeDressing.luau Snow block): snow (226,232,240), ice (170,205,225), slate (112,108,100), dark basalt (70,68,72), timber (150,62,42) weathered to grey-brown, fire glow (255,190,110), dark pine green.
1 unit = 1 stud, base centre at the origin, each sub-mesh < 18000 tris, baked PBR (Color, Normal OpenGL, Roughness; Iron also Metal) at <= 1024 px.

Families and pieces:
- veg: Frost_Fir_A (matches slot Snow_Pine_A 16x46x16), Frost_Fir_B (Snow_Pine_B 12x60x12), Frost_Fir_Broad, Frost_Fir_Sapling, Frost_Birch_A, Frost_Birch_B, Frost_Shrub_Frozen, Frost_Shrub_Small, Frost_Grass_Tuft_A, Frost_Grass_Tuft_B, Frost_Dead_Snag, Frost_Fallen_Log
- rock: Frost_Boulder_A/B/C (slots Snow_Boulder_A/B/C), Frost_Ice_Shards_A/B, Frost_Cliff_Wall_A/B, Frost_Cliff_Corner, Frost_Scree_A/B
- built: Frost_Fishing_Hut, Frost_Cairn, Frost_Dock_Section, Frost_Prayer_Flags, Frost_Brazier, Frost_Stair_Run, Frost_Retaining_Wall, Frost_Sled, Frost_Lantern
- hero: Frost_Beacon_Hero, 18 x 100 x 18 studs, sub-meshes Stone / Timber / Fire (slot Snow_Watch_Beacon)

## Checkpoints
- CHECKPOINT veg: 12 pieces (Frost_Fir_A/B/Broad/Sapling, Frost_Birch_A/B, Frost_Shrub_Frozen/Small, Frost_Grass_Tuft_A/B, Frost_Dead_Snag, Frost_Fallen_Log); largest sub-mesh Frost_Fir_B__Snow = 5436 tris
- CHECKPOINT rock: 10 pieces (Frost_Boulder_A/B/C, Frost_Ice_Shards_A/B, Frost_Cliff_Wall_A/B, Frost_Cliff_Corner, Frost_Scree_A/B); largest sub-mesh Frost_Cliff_Corner__Stone = 17504 tris
- CHECKPOINT built: 9 pieces (Frost_Fishing_Hut, Cairn, Dock_Section, Prayer_Flags, Brazier, Stair_Run, Retaining_Wall, Sled, Lantern); largest sub-mesh Frost_Cairn__Stone = 4800 tris
- CHECKPOINT hero: 1 piece (Frost_Beacon_Hero, 18 x 100 x 18.05); largest sub-mesh Frost_Beacon_Hero__Stone = 6432 tris; renders eye_Frost_Beacon_Hero.png and eye_Frost_Beacon_Hero_top.png
- CHECKPOINT pack: 32 pieces, 18 materials, upload_manifest.json + UPLOAD.md in assets/source/overworld/upload/frostmere/; largest sub-mesh Frost_Cliff_Corner__Stone = 17504 tris (cap 18000); manifest_check: problems none. (Earlier duplicate lines from veg/rock/hero tweak re-runs were merged here.)

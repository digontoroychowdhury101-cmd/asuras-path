# 23a Amberfall Ravine kit (M4, headless Blender only)

Supersedes: nothing. An earlier search (find -ipath "*amberfall*", grep -rli amberfall over tools/, workers/, assets/*.json) found only audio beds, tests and region data; no Amberfall kit scripts, packs or notes exist. The 5 hero blockouts in assets/source/overworld/hero/ (Ravine_Aqueduct_Arch) stay as placeholders; this kit adds a refined hero beside them.
Linked from LEDGER.md: not edited by this lane (LEDGER.md is outside the files this lane may write); the lane lead links this note from the LEDGER.md worker table.
Why a new file: the per-lane progress note the task requires, holding the plan, file list and one checkpoint line per family.

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Plan (one script run + export + render per family)
Scripts (tools/blender/overworld/): amberfall_common.py (helpers, exec'd by the family scripts), amberfall_veg.py, amberfall_rock.py, amberfall_built.py, amberfall_hero.py, amberfall_pack.py (stdlib: merges per-family part JSONs into the pack manifest + UPLOAD.md).
Out: assets/source/overworld/amberfall/ (GLB, maps, parts/<family>.json); pack assets/source/overworld/upload/amberfall/; renders outputs/claude-open-world-2026-11-14/captures/kit/amberfall/. Registry target (no IDs): assets/AMBERFALL_KIT_UPLOADED.json.
Palette: sandstone amber (196,148,92), dark amber (150,104,64), red trunks (128,72,56), dry pale grass (226,214,160), bronze ferns, maple scarlet/orange/gold, timber (150,62,42).

Families and pieces:
- veg: Amber_Maple_Red, Amber_Maple_Gold, Amber_RedTrunk_A, Amber_RedTrunk_B, Amber_Cliff_Pine, Amber_Maple_Sapling, Amber_Dead_Snag, Amber_Fallen_Log, Amber_Stump, Amber_Root_Tangle, Amber_Shrub_Dry, Amber_Shrub_Sumac, Amber_Fern_Bronze, Amber_Leaf_Litter_A, Amber_Leaf_Litter_B, Amber_Grass_Pale, Amber_Grass_Dry, Amber_Grass_Seed
- rock: Amber_Boulder_A/B/C, Amber_Scree_A/B, Amber_Cliff_Wall_A/B, Amber_Cliff_Corner, Amber_Ledge_Long, Amber_Ledge_Overhang, Amber_Spire
- built: Amber_Aqueduct_Span_A, Amber_Aqueduct_Span_Tall, Amber_Aqueduct_Span_Ruined, Amber_Aqueduct_Abutment, Amber_Stair_Run, Amber_Stair_Worn, Amber_Retaining_Wall_A/B, Amber_Footbridge_Rope, Amber_Shrine, Amber_Lantern_Stone, Amber_Lantern_Hanging, Amber_Rope_Rail, Amber_Cart, Amber_Crate_Stack
- hero: Amber_Aqueduct_Hero (120 x 82 x 26 studs, sub-meshes Piers / Arches / Deck, same slots as Ravine_Aqueduct_Arch in src/shared/BiomeDressing.luau)

## Checkpoints (one line per family: family, pieces, largest sub-mesh tris)
- CHECKPOINT veg: 3 pieces (Amber_Maple_Red, Amber_Stump, Amber_Grass_Pale); largest sub-mesh Amber_Maple_Red__Leaves_Detail = 9640 tris
- CHECKPOINT veg: 18 pieces (Amber_Maple_Red, Amber_Maple_Gold, Amber_RedTrunk_A, Amber_RedTrunk_B, Amber_Cliff_Pine, Amber_Maple_Sapling, Amber_Dead_Snag, Amber_Fallen_Log, Amber_Stump, Amber_Root_Tangle, Amber_Shrub_Dry, Amber_Shrub_Sumac, Amber_Fern_Bronze, Amber_Leaf_Litter_A, Amber_Leaf_Litter_B, Amber_Grass_Pale, Amber_Grass_Dry, Amber_Grass_Seed); largest sub-mesh Amber_Maple_Gold__Leaves_Detail = 12064 tris
- CHECKPOINT rock: 3 pieces (Amber_Boulder_A, Amber_Cliff_Wall_A, Amber_Ledge_Overhang); largest sub-mesh Amber_Cliff_Wall_A__Stone = 8800 tris
- CHECKPOINT rock: 3 pieces (Amber_Cliff_Wall_A, Amber_Cliff_Corner, Amber_Spire); largest sub-mesh Amber_Cliff_Corner__Stone = 14912 tris
- CHECKPOINT rock: 11 pieces (Amber_Boulder_A, Amber_Boulder_B, Amber_Boulder_C, Amber_Scree_A, Amber_Scree_B, Amber_Cliff_Wall_A, Amber_Cliff_Wall_B, Amber_Cliff_Corner, Amber_Ledge_Long, Amber_Ledge_Overhang, Amber_Spire); largest sub-mesh Amber_Cliff_Corner__Stone = 14912 tris
- CHECKPOINT built: 3 pieces (Amber_Aqueduct_Span_A, Amber_Aqueduct_Span_Tall, Amber_Footbridge_Rope); largest sub-mesh Amber_Aqueduct_Span_Tall__Piers = 2420 tris
- CHECKPOINT built: 15 pieces (Amber_Aqueduct_Span_A, Amber_Aqueduct_Span_Tall, Amber_Aqueduct_Span_Ruined, Amber_Aqueduct_Abutment, Amber_Stair_Run, Amber_Stair_Worn, Amber_Retaining_Wall_A, Amber_Retaining_Wall_B, Amber_Footbridge_Rope, Amber_Shrine, Amber_Lantern_Stone, Amber_Lantern_Hanging, Amber_Rope_Rail, Amber_Cart, Amber_Crate_Stack); largest sub-mesh Amber_Aqueduct_Span_Tall__Piers = 2420 tris
- CHECKPOINT hero: 1 pieces (Amber_Aqueduct_Hero); largest sub-mesh Amber_Aqueduct_Hero__Piers = 16720 tris
- CHECKPOINT hero: 1 pieces (Amber_Aqueduct_Hero); largest sub-mesh Amber_Aqueduct_Hero__Piers = 16720 tris
- CHECKPOINT pack: amberfall_pack.py merged 45 pieces (18 veg, 11 rock, 15 built, 1 hero), 15 materials, problems none. Largest sub-mesh Amber_Aqueduct_Hero__Piers = 16720 tris. Pack: assets/source/overworld/upload/amberfall/ (upload_manifest.json, UPLOAD.md, maps/). Renders: outputs/claude-open-world-2026-11-14/captures/kit/amberfall/eye_*.png. No uploads, no IDs. Known limits: no LOD, leaf/pad atlases are flat-colour cards, no vignette render, built/rock face UVs untiled by design.

# 23d Ashen Stair kit (M7, headless Blender only)

Supersedes: nothing. Earlier searches (Glob assets/source/overworld/** for ummit/shen/Mtn, Grep tools/ for ashen/Mtn_/summit_temple, Glob workers/ and captures/ for ashen) found no Ashen kit scripts, packs or notes. Only the 2 hero blockouts assets/source/overworld/hero/Summit_Temple_Pagoda.glb and Summit_Temple_Wing.glb exist (hero_silhouettes.py placeholders); they stay on disk as placeholders and this kit adds refined heroes beside them (same slot sizes and sub-mesh names). tools/blender/armour/ashen.py is an unrelated armour set.
Linked from LEDGER.md: not edited by this lane (LEDGER.md is outside the files this lane may write); the lane lead links this note from the LEDGER.md worker table, as for 23a/23b.
Why a new file: the per-lane progress note the task requires, holding the plan, file list and one checkpoint line per family.

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Plan (one script run + export + render per family; pattern copied from the finished Amberfall kit)
Scripts (tools/blender/overworld/): ashen_common.py (helpers + Ashen materials, exec'd by the family scripts), ashen_veg.py, ashen_rock.py, ashen_built.py, ashen_hero.py, ashen_pack.py (stdlib: merges the per-family part JSONs into the pack manifest + UPLOAD.md).
Out: assets/source/overworld/ashen/ (GLB, maps, parts/<family>.json, .blend); pack assets/source/overworld/upload/ashen/ (upload_manifest.json, UPLOAD.md, maps/); renders outputs/claude-open-world-2026-11-14/captures/kit/ashen/ (eye_<piece>.png beside a 5.5 stud figure; hero also sil_<piece>.png far silhouette). Registry target (no IDs): assets/ASHEN_KIT_UPLOADED.json. 1 unit = 1 stud, base centre at origin. No git, no uploads, no downloads.
Palette (src/shared/BiomeDressing.luau + Overworld.luau Mountain region (96,92,90) Rock): slate stone (112,108,100), basalt (70,68,72), timber vermilion (150,62,42), bronze (150,112,58), bark (84,62,46), alpine pine (40,78,60)/(56,98,74), tussock (110,140,70), scree/rock (104,100,94).

Families and pieces:
- veg: Ash_Pine_A (18x50x18 slot), Ash_Pine_B (14x64x14 slot), Ash_Pine_C (krummholz), Ash_Snag_A, Ash_Snag_B, Ash_Snag_Fallen, Ash_Shrub, Ash_Shrub_Small, Ash_Tussock_A, Ash_Tussock_B, Ash_Lichen_A, Ash_Lichen_B
- rock: Ash_Boulder_A/B/C (basalt), Ash_Cliff_Switchback_A/B, Ash_Cliff_Corner, Ash_Scree_A/B, Ash_Ledge, Ash_Crag
- built: Ash_Stair_Run_Straight (14x12x22 slot), Ash_Stair_Run_Long, Ash_Stair_Run_Turn, Ash_Retaining_Wall_A/B, Ash_Shrine_Pilgrim, Ash_Prayer_Flags, Ash_Lantern_Stone, Ash_Rest_Pavilion, Ash_Gate_Broken
- hero: Ash_Summit_Pagoda (60 x 160 x 60 studs XYZ Roblox, sub-meshes Stone / Timber / Roof / Bronze, five-tier pagoda on a stair-notched terrace, spire) and Ash_Summit_Wing (40 x 60 x 50, sub-meshes Stone / Roof / Timber); the slots Summit_Temple_Pagoda / Summit_Temple_Wing in src/shared/BiomeDressing.luau. Far silhouette render at ~1000 studs (C3 ruling 6: visible from all 5 regions).

## Checkpoints (one line per family: family, pieces, largest sub-mesh tris)
- CHECKPOINT veg: 2 pieces (Ash_Pine_A, Ash_Lichen_B); largest sub-mesh Ash_Pine_A__Boughs_Detail = 3288 tris
- CHECKPOINT veg: 12 pieces (Ash_Pine_A, Ash_Pine_B, Ash_Pine_C, Ash_Snag_A, Ash_Snag_B, Ash_Snag_Fallen, Ash_Shrub, Ash_Shrub_Small, Ash_Tussock_A, Ash_Tussock_B, Ash_Lichen_A, Ash_Lichen_B); largest sub-mesh Ash_Pine_B__Boughs_Detail = 4104 tris
- CHECKPOINT rock: 10 pieces (Ash_Boulder_A, Ash_Boulder_B, Ash_Boulder_C, Ash_Scree_A, Ash_Scree_B, Ash_Cliff_Switchback_A, Ash_Cliff_Switchback_B, Ash_Cliff_Corner, Ash_Ledge, Ash_Crag); largest sub-mesh Ash_Crag__Stone = 16004 tris
- CHECKPOINT built: 10 pieces (Ash_Stair_Run_Straight, Ash_Stair_Run_Long, Ash_Stair_Run_Turn, Ash_Retaining_Wall_A, Ash_Retaining_Wall_B, Ash_Shrine_Pilgrim, Ash_Prayer_Flags, Ash_Lantern_Stone, Ash_Rest_Pavilion, Ash_Gate_Broken); largest sub-mesh Ash_Stair_Run_Long__Walls = 4928 tris
- CHECKPOINT hero: 2 pieces (Ash_Summit_Pagoda, Ash_Summit_Wing); largest sub-mesh Ash_Summit_Pagoda__Timber = 10824 tris
- CHECKPOINT hero: 2 pieces (Ash_Summit_Pagoda, Ash_Summit_Wing); largest sub-mesh Ash_Summit_Pagoda__Timber = 10824 tris
- CHECKPOINT pack: ashen_pack.py merged 34 pieces (12 veg, 10 rock, 10 built, 2 hero), problems none. Pack: assets/source/overworld/upload/ashen/ (upload_manifest.json, UPLOAD.md, maps/). Renders: outputs/claude-open-world-2026-11-14/captures/kit/ashen/eye_*.png (+ sil_*.png hero). No uploads, no IDs. Known limits: no LOD, needle/leaf atlases are flat-colour cards, wing bronze rides in Timber, cliff switchback ledges are low contrast at eye height.

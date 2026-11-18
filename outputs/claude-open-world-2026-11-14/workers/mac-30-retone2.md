# mac-30 GLB re-tone v2 (offline, Python+Pillow+numpy)

Supersedes: nothing (extends mac-26-retone.md; retone/ output kept as is). Linked from CONTINUATION.md "Mac resume — 2026-11-18" lane table. Why new: this lane's note. Instruction: lead's mac-30 order.

## Plan
1. tools/assets/retone_glb.py v2: B-channel metal fix on every metallicRoughness image (B>=250 everywhere -> 0; real metal untouched), gentler lifts (Timber 55, Roof 60, Bark 60, Leaf sat .62, Conifer sat .55 hue 120, rough G 204), far atlas re-match, far MR B=0, extended --selfcheck.
2. `--all` -> work/mac-resume-2026-11-18/retone2/ (+ report.json, contact_sheet.png), registry cross-check.
3. Generator root cause search in tools/blender/overworld/*.py (source only); count B=255 GLBs in amberfall/ashen/frostmere/saltreach.

Files: tools/assets/retone_glb.py, work/mac-resume-2026-11-18/retone2/**, one source fix under tools/blender/overworld/ if cause is clear.

## Checkpoints
- Inventory: every non-metal MR image in all 6 groups + 4 biome packs is solid B=255; bronze/iron MR images vary (mean 180-221); Hero_TempleGold_Metal MR is also solid 255 (real gold, kept by name rule).
- Tool v2 done; `--selfcheck` passes (Crate_B, Canopy_Tree_A, Cart_B bronze B untouched, Canopy_Tree_A_Far MR B=0 G~230). Metal rule = MR image of a material with explicit metallicFactor 0 and B>=250 everywhere (so Bronze/Iron and Hero_TempleGold, factor unset, are kept).
- `--all` -> work/mac-resume-2026-11-18/retone2/: slice 16, built_a 31, built_b 16, veg 27, far 6, hero 5 = 101 GLBs, all registered, no registered model unaffected (report.json, contact_sheet.png).
- Generator: slice_kit.material() (exec'd by all packs) and hero_silhouettes.material() left Metallic unlinked -> exporter fills MR.B=255. Now a black Metal map is linked. Not run in Blender.
- Biome packs B=255 GLB counts: amberfall 45/45, ashen 34/34, frostmere 32/32, saltreach 37/37 (= 148).

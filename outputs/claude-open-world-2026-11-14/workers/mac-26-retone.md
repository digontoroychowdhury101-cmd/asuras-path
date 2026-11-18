# mac-26 GLB texture re-tone (offline, Python+Pillow+numpy)

Supersedes: nothing. Linked from CONTINUATION.md "Mac resume — 2026-11-18" lane table. Why new: no GLB texture re-tone tool existed in tools/assets/. Instruction: lead's mac-26 order.

## Plan
1. tools/assets/retone_glb.py: GLB read/rewrite (BIN rebuilt, bufferViews re-offset, accessors/meshes untouched), per-image-name transforms, far-atlas PBR add, `--selfcheck`, `--all`.
2. Run on upload/{slice,bellwood_built_a,bellwood_built_b,bellwood_veg,bellwood_far,hero} -> work/mac-resume-2026-11-18/retone/<group>/<Piece>.glb (only pieces with a transformed image).
3. Contact sheet PNG + report.json in the same folder; registry cross-check.

Files: tools/assets/retone_glb.py, work/mac-resume-2026-11-18/retone/**.

## Checkpoints
- Tool written; `--selfcheck` passes (Crate_B, Canopy_Tree_A, Canopy_Tree_A_Far: accessors/meshes/non-image bufferViews byte-identical, 4-byte aligned, far gets +2 images with normal + MR refs).
- `--all` done: slice 9, built_a 11, built_b 11, veg 22, far 6, hero 0 = 59 pieces, all registered. Outputs + report.json + contact_sheet.png in work/mac-resume-2026-11-18/retone/.
- Lum (whole image): Timber 27.8->72.0, Roof 46.6->75.0, Bark 47.6->75.0. Leaf lit HSV (94,.74,.46)->(100,.55,.41); Conifer (127,.60,.35)->(112,.55,.41); Grass (70,.55,.36)->(95,.45,.36); Fern S .69->.55; leaf/conifer/grass/fern roughness G 158/128 -> 235. Far atlas lum 63/52 -> 82/81.
- Uncertain: no pure-black padding exists (dark fill is real dark green/brown, all images RGB, no alpha); transformed whole image with a fade weight instead. Hero Hero_* images untouched (Bell_ prefix only).

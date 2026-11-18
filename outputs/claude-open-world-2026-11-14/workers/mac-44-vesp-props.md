# mac-44 Vesperhold props + withered trees + upload readiness (worker log, 2026-11-19)

Supersedes: nothing. Linked from CONTINUATION.md "Vesperhold — 2026-11-19". New because these kit groups (F figures/props, G trees, GLB texture embedding) do not exist. Order: lead's mac-44 order per workers/mac-41-vesperhold-plan.md.

## Plan
- tools/blender/vesperhold/vesp_common.py: imports vesperhold_kit.py as a module (VESP_NOMAIN=1) and reuses its builder, materials, naming, manifest, GLB export and render sheets unchanged (mac-42 outputs untouched). Adds new material generators (Wax, Flame, Banner 512x2048 with sigil, Rope, Water RGBA, DeadBark), a UV-carrying prim path (tubes, cloth sheets, smooth shading) and a mixed finish().
- tools/blender/vesperhold/vesperhold_props.py -> assets/source/vesperhold/props/ (group F + Banner_Pole, Brazier_Post, Pedestal_Statue_Staff, Ruined_Arch, Waterfall_Sheet_A/B).
- tools/blender/vesperhold/vesperhold_trees.py -> assets/source/vesperhold/trees/ (own recursive tapered-tube generator, no leaves).
- tools/blender/vesperhold/vesp_embed.py (stdlib + PIL/numpy, no Blender): injects embedded Color/ORM JPEG q90 + Normal PNG into GLBs; make_upload_pack.py calls it for the vesperhold groups -> assets/source/vesperhold/upload/{kit,props,trees}.
- Registry: one assets/VESPERHOLD_KIT_UPLOADED.json for all three groups if the tool allows (piece names are unique across groups).

## Checkpoints
(one line per Blender run below)
- run1 props (scratch, 4 pieces, no render): ok; fixes after looking: statue hood pit, banner spokes heavier, wax paler, flame smoother. mem free 62% -> 62%.
- run2 props full (26 pieces, scratch): hull/kit-sub add bugs fixed; waterfall rows denser at lip; mem free 62%.
- run3 props FINAL (assets/source/vesperhold/props, maps regenerated, 8 contact sheets): ~17 s wall, 26 GLBs, max sub 14.0k tris; mem free 67% -> 60%.
- run4 trees FINAL (10 pieces, 3 sheets): ~6 s wall, max sub 14.9k (split by Z band); mem free 61% -> 60%. Re-run after root clamp (-2.8) for pack check.
- pack: make_upload_pack.py kit props trees -> upload/{kit,props,trees} GLBs with embedded textures (vesp_embed.py), manifest_check problems: none x3. Sizes: kit 1613 MB (22 GLB > 50 MB), props 990 MB (5 > 50), trees 292 MB (0). Fix switch: VESP_NORMAL=jpeg -> normal 6.2 MB instead of 11.1 MB (kit 1040, props 623 with 1 > 50, trees 194).
- Not done: no Studio import/upload, nothing committed. Weak: gargoyle A/B near-identical, statue arms chunky, ruined arch pier plain, waterfall banding lines at row seams.

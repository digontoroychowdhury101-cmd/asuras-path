# mac-52: Vesperhold gargoyles v2 + hero withered trees (hand-modelled, baked)

Worker: mac-52 (observed model: Opus 5.5, claude-opus-5-5). Branch ux/onboarding-overhaul. Not committed: the lead commits.
Rules: workers/mac-50-vesp-rebuild-rules.md (heavy mkdir lock, memory before/after, never decimate, subs < 18k, bake, no Meshy).

## Plan
- tools/blender/vesperhold/vesperhold_gargoyles.py (new, mine): Gargoyle_A (crouching winged beast on a moulded corbel) and
  Gargoyle_B (emaciated long-necked waterspout on a wall block). Signed-distance sculpt per role, polygonised twice (surface nets
  + Newton projection): LOW shipped, HIGH fine + pits/chips; vesp_bake per role. Shared render/export helpers live here too.
- tools/blender/vesperhold/vesperhold_props.py: only the Gargoyle_A/B PLAN tuples removed + `import vesperhold_gargoyles`.
- tools/blender/vesperhold/vesperhold_trees.py (mine): rewritten. Skeleton generator -> numpy tube mesher at two levels
  (LOW shipped, HIGH with bark furrows + bark_willow_02 displacement + knots), buttress root flare, pointed twig tips, bake per
  role (Trunk/Limbs/Branches/Twigs, Chain on oak A). Stumps/logs = CC0 Poly Haven scans scaled to studs, retoned, split.

## Blender runs (memory_pressure free %, before -> after)
| Run | Result | free % before -> after |
|---|---|---|
| gA_clay1 (Gargoyle_A clay) | failed in camera framing (NaN from degenerate wrist membrane triangles); fixed | 57 -> 52 |
| garg_clay2 (A+B clay, 178 s) | OK. Look 1: A head skull-like, brow weak, torso a sack, ridge faint, stone lumps doughy; B teeth float/drip, block plain, mannequin hidden in side views | 51 -> 54 |
| garg_clay3 (A+B clay, 164 s) | OK. Look 2: tooth tips frayed; A nostrils read as eyes (face too cute); B neck detail reads scaly. Fix 3: tooth tip r 0.014, scowling brow, bigger sockets, small nostrils, less pit/chip | 61 -> 57 |
| trees_clay1 (Oak A, Pine A, Thorn A clay, 103 s) | OK. Look 1 vs ref_04: oak silhouette right (buttress roots, reaching arms, chain on a limb); deep twigs curl into loops, one reaching arm slides along the floor; thorn stems each flare into overlapping skirts. Fix: lower deep wobble/droop, keep limbs above 4 studs off the floor, thorn flare 0.18 | 59 -> 59 |

## Status
In progress.

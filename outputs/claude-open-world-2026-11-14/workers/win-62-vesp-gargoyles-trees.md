# win-62: Vesperhold gargoyles + withered hero trees (Windows PC, continues mac-52)

Worker: win-62 (observed model: Opus 5.5, claude-opus-5-5). Branch ux/onboarding-overhaul. Not committed: the lead commits.
Rules: workers/mac-50-vesp-rebuild-rules.md (heavy mkdir lock, memory before/after, never decimate, subs < 18k, bake, no Meshy).

## Plan
- Gargoyles: re-run mac-52 clay pass 3 fixes, look, fix, then bake A + B at 2048 into
  assets/source/vesperhold/candidate-win-2026-11-19/props (merge only Gargoyle_A/B into props/manifest.json).
- Trees: clay Oak/Pine/Thorn, look, fix, bake all 6 heroes + 4 CC0 scans into candidate-win-2026-11-19/trees.
- Sheets: outputs/vesperhold/kit-renders-win/F2_gargoyles_win.jpg, T1_trees_win.jpg.

## Files
- tools/blender/vesperhold/vesperhold_gargoyles.py, tools/blender/vesperhold/vesperhold_trees.py (owned).
- Sheet copy target now env-driven (VESP_SHEET_DIR / VESP_SHEET_NAME), default unchanged.

## Blender runs (free RAM before -> after)
| Run | Result | RAM |
|---|---|---|
| garg_clay1 (A+B clay, mac-52 pass-3 code, 215 s) | OK. Look: A face still rat/cat (nostril dots read as a 2nd pair of eyes, domed skull), torso a smooth sack; B silhouette strong and clearly unlike A, but teeth/horn tips fray into floating bits, wing tatter leaves detached shards, cartoon eyeballs, neck knobs read scaly. Fix: TIPMIN 0.024 on every tube, A flat cranium + crest + V brow + nostril slits + flank ribs, B empty sockets + brow, sparse neck knobs, edge-only tatter | 3.8 -> 4.0 GB |
| garg_clay2 (A+B clay, 233 s; waited ~4 min on lead's Studio lock) | OK. A now a fierce beast in profile (flat skull, crest, V brow); B fine. Teeth/claw tips still fray: FG.weather chips the most convex verts (tips) by ~40% of their radius. Fix: SDF thickness mask (field 0.05 inside) blends detail+weather out on thin features; tooth tip r 0.03, B teeth rad 0.05 | 3.6 -> 3.7 GB |
| garg_clay3 (B clay, 104 s) | OK. Fray gone, but teeth now near-cylindrical blunt nubs (read as fingers). Fix: conical fangs root rad*(1.5+L) -> tip TIPMIN | 3.7 -> 3.8 GB |
| trees_clay1 (6 heroes clay, 227 s) | OK. Oaks: limbs drift into tusk-like crescents, one oak A limb still crawls along the ground. Pines: dead-straight spiky poles (every small stub sprouts 3-6 long splinters = hedgehog). Thorns: upright generic lollipop trees, fat finger roots. Fix: wander freq x length/12, ground lift below 7 studs, splinters scaled to stub r, bowed lean (pines 0.12/0.17 H, thorns 0.24/0.2 H), more long drooping pine limbs, thorn roots rr 0.5 | 3.7 -> 4.0 GB |
| trees_clay2 (6 heroes clay, 240 s) | OK. Oak A now gnarled/haunting like ref_04; pines lean with long drooping low limbs and short stub splinters; thorns lean, acceptable. Oak B (and some oak A limbs) double back and wrap round the trunk; oak B high 3.7M tris. Fix: limb walk may not turn back past 75 deg from its start heading | 4.5 -> 4.6 GB |
| trees_clay3 (oaks clay, 90 s) | OK. Oak A: leaning gnarled trunk, low reaching arm, chain on a broken limb: matches ref_04. Oak B: no more trunk-wrapping loops, but still a dense tentacle tangle (crossing drooping limbs); accepted as the contrasting variant, flagged weak. Oak B high 4.0M tris | 5.0 -> 5.1 GB |
| garg_bake1 (A+B bake 2048, 408 s incl. lock wait; bakes ~17 s/role) | OK. Soot-black weathered stone, frost on heads/hands/corbel tops, conical fangs, A/B unmistakably different. Slight brown cast from rock_04 -> sat 0.4, frost 0.5 for a re-bake. Manifest: 27 pieces after merge (win-61 entries intact) | 6.2 -> 5.6 GB |
| trees_bake1 (Oak A bake 2048, 315 s; ~40 s/role) | OK. Bark furrows read in the normal map, bleached grey dead wood, frost on roots and limb tops, iron chain. Minor: collar where main limbs leave the broken trunk top, one twig kinks into an L | 6.1 -> 5.3 GB |
| trees_bake2 (Oak B bake, 312 s) | Baked fine technically, but rejected on look: tentacle tangle, reaching arms droop, hit the ground lift and swing back up into U-loops. Fix (B only, A untouched): 2 arms, arm droop 0.12, arm up 0.9 | 5.1 -> 6.7 GB |
| trees_clay4 (Oak B clay, 45 s) | OK. Broad gnarled oak with a spreading crown; no trunk wrapping; one low S-hooked limb left (accepted) | 6.0 -> 6.3 GB |
| trees_bake3 (Oak B + Pine A/B bake, 440 s) | OK. Oak B spreading gnarled crown; pines bleached grey, frost on root flare, snapped crown shards, mild bowed lean. Pine trunk furrows read shallower than the oak | 6.0 -> 6.3 GB |
| trees_bake4 (Thorn A/B + Stump A/B + Log A/B, 383 s) | OK. Thorns lean and twist, thorny crowns read; weak: root LOW faceted (8 sides) up close, frost blotches on roots. Stumps/logs: CC0 scans retoned grey with frost, at stud scale (stumps 5.7/9.4, logs 16.5/15.7 studs) | 6.0 -> 6.6 GB |
| garg_bake2 (A+B re-bake, sat 0.4, 414 s) | OK, final. Brown cast gone: soot-grey/black stone, frost on tops. Manifest 27 pieces intact | 6.3 -> 6.5 GB |

## Codex continuation, 20 November

Continued from `067bcd9` in the Windows candidate. The second gargoyle bake had completed before Claude stopped, so the
existing final A/B exports were carried forward. Their squat winged and long-spouted silhouettes read distinctly in the
renders. The interrupted tree bake was re-run with weighted normals and 2048 maps. The export check found that both oak
roots extended below the declared burial limit, even though the centreline was clamped. The generator now compresses the
buried ends smoothly and keeps the shape above ground. The two oaks retain visible seams where some major limbs join the trunk,
and one low limb on the broader oak still forms a hook.

| Windows Blender batch | Free GiB before → after | Result |
|---|---|---|
| Weighted-normal oak rebuild | 5.30 → 6.45 | Baked and rendered. GLB check found underside depths 3.32 and 5.22 studs. |
| Weighted-normal pines | 6.44 → 6.70 | Both baked and rendered. |
| Weighted-normal thorns, plus stump and log scans | 6.70 → 6.49 | Six baked and rendered. |
| Oak burial correction | 6.23 → 6.86 | Both rebaked. GLB bases sit 2.65 and 2.79 studs below grade. |

All 10 tree exports passed direct GLB and manifest checks. Their 42 submeshes top out at 16,967 triangles with four
2048 × 2048 maps per material.

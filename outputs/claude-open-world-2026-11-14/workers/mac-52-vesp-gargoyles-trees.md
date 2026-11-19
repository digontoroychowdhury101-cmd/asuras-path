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
(filled in after each run)

## Status
In progress.

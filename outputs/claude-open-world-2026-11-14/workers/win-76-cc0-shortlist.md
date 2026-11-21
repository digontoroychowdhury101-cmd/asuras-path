# win-76 CC0 replacement trees/props shortlist (research only, 2026-11-21)

Nothing downloaded, imported or uploaded. Every download and every Roblox upload below is **held for the creator's approval**.
Rules applied: CC0 or a GPL/MIT generator only. No NC/ND, no Creator Store free models, no paid generation. Licences were read
from each source's own page on 2026-11-21. Re-check the licence per asset at download time and record it in THIRD_PARTY.md.

## Ranked shortlist

| # | Source | What fits Asura's Path | Licence | Fit / cost |
|---|---|---|---|---|
| 1 | Blender **Sapling Tree Gen** (extensions.blender.org/add-ons/sapling-tree-gen) | Our own bark/leaf maps on generated trunks: forest broadleaf, pines, Amberfall maples | Add-on GPL-2.0-or-later (it was bundled with Blender 4.1). The trees it generates are our own work. | Best match to the existing baked-PBR kits; no third-party art at all. Cost: Blender time per species plus bake. |
| 2 | **Poly Haven** "Pine Forest" collection: pine_tree_01, dead_tree_trunk, dead_tree_trunk_02, tree_stump_01/02, rock_moss_set_01, moss_01 | Forest-floor realism: logs, stumps and mossy rocks under the canopy (helps the "park, not wilderness" look) | CC0 for all assets (polyhaven.com/license) | Photoscanned PBR that suits our look. Very heavy (tree_small_02 is ~5M tris; the logs ship 8K maps), so each needs decimation, baking to <=1024 maps and splitting under the 18-20k sub-mesh cap. |
| 3 | **Quaternius Stylized Nature MegaKit** (quaternius.com, itch.io free Standard zip) | 40 trees (birch, pine, cherry), 27 rocks, bushes and plants: stand-ins for the region kits, cherry for shrine courts | CC0 (itch.io and OpenGameArt) | Stylized ("Ghibli") look; needs a retone to sit next to the PBR forest. Free tier only; the paid Source zip is not to be bought. |
| 4 | Quaternius **Textured LowPoly Trees** (45 trees) / **Ultimate Nature Pack** (150+) | Far-belt silhouettes or blockouts | CC0 | Low-poly; only for distance or placeholder use. No maples confirmed. |
| 5 | **Kenney Nature Kit** (330 assets, v1.0) | Blockout props: rocks, logs, path pieces | CC0 | Flat-shaded low-poly, the weakest fit; placeholder use only. |

## Recommendation
- Trees: Sapling (1), textured with our existing lifted bark/leaf maps. It avoids a style clash and any licence question.
- Ground clutter: the Poly Haven logs, stumps and mossy rocks (2), decimated and baked by the existing tools/blender/overworld pipeline.
- Quaternius and Kenney only as region stand-ins if the four built region kits (Amberfall 45 / Saltreach 37 / Frostmere 32 / Ashen 34 GLBs,
  already in assets/source/overworld/upload/) stay unuploaded.

## Held decisions (creator)
1. Download any of the above (state file, source and size first).
2. Upload the four built region kits (148 GLBs). 193 of 208 region pieces are still placeholders without them.

Sources: extensions.blender.org/add-ons/sapling-tree-gen, polyhaven.com/license, polyhaven.com/collections, polyhaven.com/a/dead_tree_trunk,
polyhaven.com/a/rock_moss_set_01, quaternius.itch.io/stylized-nature-megakit, quaternius.itch.io/textured-lowpoly-trees,
quaternius.itch.io/150-lowpoly-nature-models, kenney.nl/assets/nature-kit.

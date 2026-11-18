# mac-23 canopy (source-side, Luau)

Supersedes: nothing. Linked from CONTINUATION.md "Mac resume — 2026-11-18" lane table. Why new: this lane's note. Instruction: lead's mac-23 canopy order.

## Plan
Work order = mac-20 verdict items 2 (park -> wilderness) and 4 source half (grass scale near road/arrival).
Files: src/shared/SliceDressing.luau (Tree/Grass/understory rules, CrownSpacing, Roadside, grass scale cap), tools/test_slice_dressing.luau (per-class print, road-canopy check, sky-occlusion print, tightened COVER_MIN).
Tests: `work/bin/luau/luau tools/test_slice_dressing.luau`, `python3 tools/lune_compat.py tools/test_slice_dressing.luau`, `python3 tools/test_kit_registry.py`.

## Checkpoints
- Baseline (plain luau 1320/0; lune_compat 1347/0): 218 trees (101 near + 117 far), canopy coverage 43% of 604 free samples, 1563 placements, 2597 MeshParts, 4.37M tris, 3.16M TrisLod.
- Test added: per-class print, road-canopy check (floor 12%), sky-occlusion print per eye, near-road grass cap check, COVER_MIN 0.3 -> 0.6. Baseline model vs Studio (01..07): model 1/20/18/17/19/6/1 vs Studio 0/18/10/12/12/7/0 (model runs ~1.0-1.7x high mid-range).
- Rule edits (SliceDressing.luau): Tree Spacing 22->12, Base 0.85->0.52, Scale {0.7,1.4}->{0.75,1.4}, Cluster Lo/Hi 0.3/0.52 -> 0.28/0.46 Floor 0.05->0.15, Roadside 2.6->5, new RoadMin {26,1.38} + RoadPieces (A/C/D) + a road-band-first pass, new Taper {40,140,0.04} (near trees thin out 40-140 studs from roads/eyes), FarDensity 0.4->0.22, Conifer weight 0.04->0.055 (test needs 4% of trees), CrownSpacing 0.45->0.25. Understory: Grass Under 0.5->0.15 Gap 1.3->1.25, Flower Under 0.4->0.1 Gap 1.6->1.0 Base 0.09->0.05, Fern Under 0.4->1.0 Gap 1.4->0.7 Base 0.22->0.17, Shrub Under 0.25->0.6 Gap 1.5->0.9 Base 0.22->0.18, Mushroom Base 0.25->0.14, Rock Base 0.8->0.55, Sapling 0.1->0.07, Deadwood 0.45->0.3. Grass NearScale {Dist 32, Scale 0.5..0.9} (road centreline or altar spawn/exit); Floor Spacing 4->3.4 Chance 0.9->1 (the smaller grass dropped the ring to 39% < 40%).
- Final: 1349/0 under lune_compat (1322/0 plain luau), test_kit_registry exit 0.

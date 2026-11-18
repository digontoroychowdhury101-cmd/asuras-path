# mac-29 canopy pass 2 (source-side, Luau, light slot)

Supersedes: nothing. Linked from CONTINUATION.md "Mac resume — 2026-11-18" table. Why new: this lane's note. Instruction: lead's mac-29 order.

## Plan
Fix mac-27 findings: 03 black frame (trunk 3.8 studs from eye), 01/07 park read (foreground grass; canopy), 04/05/06 low sky occlusion, pay tris, calibrate model vs Studio.
Files: src/shared/SliceDressing.luau (Keep.Eye, EyeView, Stands, Taper.Ramp, NearScale on eyes), tools/test_slice_dressing.luau (A2c eye tests, grass cap incl. eyes, per-elevation sky print, calibrated prediction + floors).
Tests: `python3 tools/lune_compat.py tools/test_slice_dressing.luau`, `python3 tools/test_kit_registry.py` (plain luau for the diagnostics prints).

## Checkpoints
- Baseline: 366 trees (181 near + 185 far), 4.94M tris, model sky 16/65/80/28/25/14/16 vs Studio 11.2/54.6/77.5/19.6/19.2/11.2/11.2 (ratio 0.70-0.97).
- Finding: no SliceDressing grass card stands within 21.7 studs of eye 01/07 (nearest Floor_Grass_026, 3.7 studs tall); the carpet in captures 01/07 is not a scatter card (Terrain Decoration grass is the suspect; outside this lane's files).
- Rules: Keep.Eye 14/6/6/8/14, EyeView {10,2,10}, Stands (ring 18..85, Boost 3, MinScale 1.38, StandPieces A-weighted), Taper.Ramp 60 (pays for stands), capture eyes added to the grass NearScale arrivals.
- Final: 1356/0 lune_compat, kit registry exit 0; 339 trees (154 near + 185 far), 4.49M tris, 2.79M TrisLod, 1334 placements, 2347 MeshParts; predicted Studio 01 23 / 02 54 / 03 29 / 04 22 / 05 22 / 06 16 / 07 23 %.

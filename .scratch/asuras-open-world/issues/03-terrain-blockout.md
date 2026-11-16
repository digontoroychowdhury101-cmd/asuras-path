# 03 — Terrain and blockout
Status: blocked
Blocked by: 01
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §6–§11 §16.3

## What to build
A server builder writes Terrain and blockout geometry for all five regions from the canonical data, under Workspace.Map_Overworld, and records a terrain ownership manifest. The main, alternate, optional and shortcut routes can each be walked with real character movement.

## Acceptance
- [ ] Ownership manifest lists every Terrain box written; no other Terrain is cleared (evidence: test name)
- [ ] All overworld geometry sits under Workspace.Map_Overworld (evidence: Studio explorer check)
- [ ] Studio run walks main, alternate, optional and shortcut routes end to end (evidence: Studio run notes)
- [ ] Measured traversal time per route is recorded against the plan targets (evidence: measurement table)
- [ ] Before full build, measure server boot time and memory for runtime terrain generation of ONE region via the existing CampaignTerrain approach; choose runtime, baked-in-place (via tools/build.py) or hybrid mesh landforms; record the measurement and choice; the choice survives tools/build.py (evidence: measurement table and recorded choice)
- [ ] No biome ends on a straight box edge; authored transition bands are present (evidence: Studio capture)
- [ ] Rain shadow is true on the ground: divide ridge and Amberfall dry-grass transition (evidence: Studio survey)
- [ ] Measured traversal with real inputs is reported at C2 (evidence: measurement table)

## Evidence
(empty; filled on completion)

## Amendment (C2 review, 2026-11-15)
- Unwritten ground (must-fix 1): no player on foot, gliding or fast-travelling may reach unwritten ground (sprint ≈ 6,000 studs in 180 s). If reached anyway: stop them or put them back at the nearest written overworld altar, never drop to the lobby. Suggested: generate tiles nearest current players first, after arrival sites. Prove with a test + one Studio run sprinting away from the glade from second 9.
- World edge (art a): no straight slab cut visible from any route or landmark; unreachable outer ranges, sea cliffs, haze, irregular coast; lobby island skyline not behind it.

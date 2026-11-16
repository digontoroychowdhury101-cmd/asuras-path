# 05 — World map (M)
Status: blocked
Blocked by: 01, 03, 07
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §12

## What to build
Pressing M (or the gamepad or touch equivalent) opens a large map rendered from the canonical data. It shows the player's position and heading, regions, discovered altars, landmarks, a legend, zoom and pan, one placed waypoint, an underground level filter, and persistent discoveries. M or Escape closes it and restores input and camera. The radar is removed from gameplay while Respite and Controls stay reachable.

## Acceptance
- [ ] test_input_map: Map is bound on keyboard, gamepad and touch; no Enum.KeyCode.M literal (evidence: test name)
- [ ] Pure transform test: world to map to world round-trip (evidence: test name)
- [ ] Studio surveyed-point check: map matches terrain in every biome and near edges (evidence: Studio measurements)
- [ ] Opening the map blocks gameplay input; closing restores input and camera (evidence: Studio run notes)
- [ ] Discoveries persist across rejoin and are never duplicated (evidence: test name or Studio run)
- [ ] Radar is gone; Respite and Controls are reachable (evidence: Studio capture)
- [ ] Retired altars are never shown as markers (evidence: test name)
- [ ] Display names match the ruling: The Bellwood, Amberfall Ravine, The Saltreach, Frostmere Heads, The Ashen Stair, Ash Colosseum (evidence: test name or Studio capture)

## Evidence
(empty; filled on completion)

## Amendment (C2 review, 2026-11-15)
- Must-fix 2: close unverified Studio items: radar hidden in overworld; map at two more resolutions (one small, one large).
- Must-fix 4: map draws ravine floor water blue. If dry, draw depth; if flooded in-world it is a terrain defect (deep dry ravine with seasonal stream).
- Map look (art e): same data, restyled bake: parchment, no speckle, hill shading/contours, clean road and river strokes.

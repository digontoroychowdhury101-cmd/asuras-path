# 06 — Compass bearings
Status: ready-for-agent
Blocked by: none
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §12

## What to build
Extend SakuraCompass with 15° ticks, numeric labels at readable intervals, intercardinals, and a precise current bearing that wraps smoothly from 359 to 0. Waypoint icons are decluttered. North is 0 at world -Z and east is 90 at +X. The waypoint icon hook is finished with ticket 05.

## Acceptance
- [ ] Pure test: N=0, E=90, S=180, W=270 (evidence: test name)
- [ ] Pure test: the 359 to 0 wrap is continuous with no sweep back (evidence: test name)
- [ ] Ticks and labels render at readable intervals (evidence: Studio capture)
- [ ] Waypoint icons are decluttered when several overlap (evidence: Studio capture)

## Evidence
(empty; filled on completion)

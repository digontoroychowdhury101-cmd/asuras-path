# 02 — Shrine entry and return
Status: blocked
Blocked by: 01, 03
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §4 §17

## What to build
The gateway portal lands players at the relocated Altar_MonasteryGate in a blockout glade. There they can rest, and a return gate travels them to the lobby bonfire through the existing Characters path. The lobby itself does not change.

## Acceptance
- [ ] Studio run: portal to glade, rest, return gate, then bonfire completes (evidence: Studio run notes)
- [ ] Lobby before and after camera captures match (evidence: Studio capture pair)
- [ ] LAYOUT.PortalDestination still equals Altar_MonasteryGate (evidence: test name)
- [ ] Fixed lobby cameras captured into outputs/claude-open-world-2026-11-14/baseline/ BEFORE any overworld geometry exists in the open place (evidence: capture files)
- [ ] After blockout, if any overworld silhouette is visible from a lobby camera, overworld landmarks are hidden for lobby players; no lobby fog or lighting change (evidence: Studio capture pair)

## Evidence
(empty; filled on completion)

## Amendment (C2 review, 2026-11-15)
- Unwritten ground (must-fix 1): no player on foot, gliding or fast-travelling may reach unwritten ground (sprint ≈ 6,000 studs in 180 s). If reached anyway: stop them or put them back at the nearest written overworld altar, never drop to the lobby. Suggested: generate tiles nearest current players first, after arrival sites. Prove with a test + one Studio run sprinting away from the glade from second 9.
- Portal timeout (must-fix 2): Studio-verify the portal-wait timeout path.

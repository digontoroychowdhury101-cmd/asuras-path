# 19 — Verification report
Status: blocked
Blocked by: 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §17 §18

## What to build
Run verify_all.sh, Studio passes on the identified real place, captures for each biome, measured traversal, and a statement of two-client and device status. Then write the final report.

## Acceptance
- [ ] bash tools/verify_all.sh passes on a temp build (evidence: script output)
- [ ] Studio passes run on places/AsurasPath.rbxlx after the identity check (evidence: Studio run notes)
- [ ] Capture set for each biome is attached (evidence: capture list)
- [ ] Measured traversal is recorded per route (evidence: measurement table)
- [ ] Two-client and device status is stated, with unperformed checks marked (evidence: report section)
- [ ] Report lists endings (deferred with archived bosses) as a creator decision to revisit (evidence: report section)

## Evidence
(empty; filled on completion)

## Amendment (C2 review, 2026-11-15)
- Must-fix 2 (all): close unverified Studio items: radar hidden in overworld; portal-wait timeout path; map at two more resolutions (one small, one large); death (stakes) card distance measured, not guessed.
- Must-fix 3 (two clients): try a real two-client Studio local-server test for the lobby duel now and Shen participants at T10; if tooling cannot drive it, say so and leave both unperformed. State the two-client status in the report.
- Review gate: before mass dressing, finish one slice (gateway glade → Bell Terrace: terrain materials, vegetation kit, one structure kit, overworld light) and return six player-height captures before biome variants. C3 returns for mechanics; slice review with it or straight after.

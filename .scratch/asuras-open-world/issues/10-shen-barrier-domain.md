# 10 — Shen barrier and domain
Status: blocked
Blocked by: 03, 07, 08
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §8

## What to build
Gate_AshColosseum and the Shen arena move to the summit temple sanctum, region AshColosseum. The barrier can be entered from both sides, shows its prompt at distance, and can be left before entry. Death leads to a retry runback, victory leads to a reliable exit, and reset never traps the player. Shen uses the real forms, animations and sounds.

## Acceptance
- [ ] Studio run: barrier prompt appears at distance; leave-before-entry works from both sides (evidence: Studio run notes)
- [ ] Death retry runback reaches the barrier within 90 s from the refuge (evidence: measurement)
- [ ] Victory exits the arena and the barrier no longer traps anyone (evidence: Studio run notes)
- [ ] Reset never traps the player (evidence: test name)
- [ ] Both Shen phases use the real animations and sounds (evidence: Studio capture)
- [ ] Existing test_boss_* tests pass at the new placement (evidence: test names)

## Evidence
(empty; filled on completion)

## Amendment (C2 review, 2026-11-15)
- Two clients (must-fix 3): try a real two-client Studio local-server test for the lobby duel now and Shen participants at T10; if tooling cannot drive it, say so and leave both unperformed.

# 07 — Persistence migration
Status: blocked
Blocked by: 01
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §4 §17

## What to build
Old saves migrate onto the new world. A retired activeAltar maps to the safe spawn, and stranded bloodstains relocate with essence intact. An optional souls.world.discoveries field is added. Caches, lore and the miniboss flag are relocated. The Objectives route is rewritten to end at Boss:GrandmasterShen. New caches FrostWatchpost (WindSlash) and SaltCaravan (Thunderfall) are added. Inactive bosses are archived. No reward is duplicated on retry or rejoin.

## Acceptance
- [ ] Old-save profile fixtures in test_profile_integrity (or a sibling) cover retired activeAltar, stranded bloodstain, caches and routeFlags (evidence: test name)
- [ ] Migrated fixtures keep all altars, bosses, caches, routeFlags, lore and essence (evidence: test name)
- [ ] Retry and rejoin grant no duplicate reward (evidence: test name)
- [ ] Fresh-profile walk-through reaches Boss:GrandmasterShen through normal play (evidence: Studio walk-through notes)
- [ ] Profiles that already own WindSlash or Thunderfall get no duplicate from FrostWatchpost or SaltCaravan; a fresh profile can earn both (evidence: fixture tests)
- [ ] Ending code and saved sovereign and ending flags are untouched; no sovereign progress is granted (evidence: test name)
- [ ] Retired altars are never offered as fast-travel destinations (evidence: test name)

## Evidence
(empty; filled on completion)

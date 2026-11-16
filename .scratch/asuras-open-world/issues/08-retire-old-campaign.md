# 08 — Retire the old campaign
Status: blocked
Blocked by: 02, 03, 07
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §4

## What to build
Bootstrap stops MonasteryService and CampaignWorld. BossRoster registers no inactive regions, arenas or gates. The WorldService greybox fallback follows the new regions. Old-world tests are replaced by overworld tests. The result has no overlapping worlds, no duplicate NPCs or altars, and no obsolete markers.

## Acceptance
- [ ] Bootstrap test: MonasteryService and CampaignWorld are not started (evidence: test name)
- [ ] BossRoster test: no inactive region, arena or gate is registered (evidence: test name)
- [ ] Old-world tests are removed and replaced by overworld tests (evidence: test list diff)
- [ ] Studio scan finds no duplicate NPC or altar IDs and no obsolete markers (evidence: Studio scan output)

## Evidence
(empty; filled on completion)

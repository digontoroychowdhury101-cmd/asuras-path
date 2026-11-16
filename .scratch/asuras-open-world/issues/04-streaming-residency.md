# 04 — Streaming residency
Status: ready-for-agent
Blocked by: none (validate on the EXISTING world first, before blockout volume depends on it)
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §15

## What to build
Enable streaming as a deliberate contract change across default.project.json, Config, ConfigValidator and their tests. Teleport requests stream-around before pivot, Persistent landmarks and lobby top-level models stay loaded, and client presence assumptions are made stream-safe. The lobby stays unchanged. If validation fails, fall back to streaming off with LandscapeBudget distance hiding, and record the decision.

## Acceptance
- [ ] Config and ConfigValidator tests pass with the streaming settings (evidence: test names)
- [ ] Teleport requests stream-around before the pivot (evidence: test name)
- [ ] Lobby capture is unchanged with the Persistent lobby models (evidence: Studio capture pair)
- [ ] Client lookups (WaypointMarker, SpellController, DialogueController, WorldStateController) tolerate absent instances (evidence: test name or Studio run)
- [ ] If the fallback is used, the decision and its evidence are written in Evidence below (evidence: recorded note)
- [ ] Validated on the existing world: lobby intact, teleport stream-in, the four client presence assumptions (WaypointMarker PortalTrigger, SpellController WorldDiscoveryCaches, DialogueController JadeCataclysm, WorldStateController AsurasPath), ConfigValidator contract and its tests; recorded fallback taken early if any fails (evidence: Studio run notes and test names)

## Evidence
(empty; filled on completion)

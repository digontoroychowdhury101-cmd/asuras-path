# 01 — Overworld canonical data
Status: ready-for-agent
Blocked by: none
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §4 §6 §12

## What to build
A pure shared Luau module holds the whole overworld definition: world frame, five regions plus the AshColosseum domain, altars (kept IDs relocated, new IDs added), caches, lore placement, route graph, POIs with level and hidden flags, the summit barrier, reserved arenas, and the world-to-map transform. It is applied into WorldDefinitions via `apply(world)`, the same pattern as BossRoster.apply. The retired altar-to-safe-spawn map lives in the same module.

## Acceptance
- [ ] Pure Luau test: every kept and new altar, cache and gate ID is present (evidence: test name)
- [ ] Pure Luau test: every altar, POI and gate lies inside its region bounds (evidence: test name)
- [ ] Pure Luau test: the route graph is connected from the gateway to the barrier node (evidence: test name)
- [ ] Pure Luau test: the retired altar map is total over the retired IDs (evidence: test name)
- [ ] default.project.json maps the new module (evidence: file diff)
- [ ] luau-compile is clean on the new and changed files (evidence: compile output)
- [ ] Pure Luau test: display names are The Bellwood, Amberfall Ravine, The Saltreach, Frostmere Heads, The Ashen Stair and Ash Colosseum, with no reference-game names (evidence: test name)
- [ ] Pure Luau test: the continuous N–S divide ridge is in the data (evidence: test name)
- [ ] Pure Luau test: each region border has a transition band and a Blend margin (~200 studs) usable by environment and weather selection (evidence: test name)
- [ ] Pure Luau test: retired altars (Altar_SanctuaryDepths, Altar_CelestialPagoda, Altar_SkyCitadel) are absent from World.Altars, so they never appear as fast-travel destinations or map markers (evidence: test name)

## Evidence
(empty; filled on completion)

# 11 — Weather, time and composition
Status: blocked
Blocked by: 01
Spec: ../SPEC.md  · Plan: ../../../outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md · Brief sections: §13

## What to build
A server world clock and per-region weather states. The client EnvironmentController is the single Lighting owner and composes biome, time, weather, shelter, boss and comfort. FoliageWind stays the sole GlobalWind writer and gains a weather target. One client weather FX owner handles cleanup. Lobby and domain presentation are preserved. Tests extend test_audiovisual.

## Acceptance
- [ ] test_audiovisual extension: compose priority across biome, time, weather, shelter, boss and comfort (evidence: test name)
- [ ] Cleanup counts reach zero after region, shelter, respawn and reset changes (evidence: test name)
- [ ] FoliageWind is the only writer of GlobalWind (evidence: test name or grep check)
- [ ] Lobby capture is unchanged (evidence: Studio capture pair)
- [ ] Overworld prevailing wind is ESE; the lobby keeps its own wind (evidence: test name)
- [ ] One wind source feeds foliage, precipitation, cloth and ambience (evidence: test name or grep check)
- [ ] Selection blends across region Blend margins with no snap at box edges (evidence: test name)

## Evidence
(empty; filled on completion)

## Amendment (C2 review, 2026-11-15)
- Light (art c): overworld profiles via existing environment owner; glare capped, combat fill kept; lobby lighting untouched.
- Caves/lifts (art f): real roofed interiors suppressing weather by C4. Fade-teleport lifts may stay if both ends are built structures and the map shows the link.

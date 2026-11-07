# AR00: spatial plan and measured scale prototypes

**Done for planning.** A coordinate site plan covers all six arenas, with old and new footprints, service and scenic extents and planned region bounds. A machine-readable manifest records the overlap tests. Two untextured prototypes per arena were built and captured in a temporary Studio place, and the walk speed was measured at runtime.

AR01 (Shen) is implemented next from this manifest. AR02–AR06 are outside this run; their footprints below are reviewed proposals, not implemented geometry.

## Chosen footprints (variant B; A is about 0.8 linear)

| Arena | Baseline core | B core (centre) | Area vs baseline | Corner-to-corner walk | Why not scale in place |
|---|---|---|---:|---:|---|
| AR01 Shen | 120×130 at (0, −1960) | **240×190 at (0, −1990)** | ×2.92 | 13.7 s (9.1 s sprint) | North edge pinned by the Hall facade (−1877, two foe pockets). South edge pinned by the Pagoda cloud stair (−2120). The bowl grows east–west; the region widens 360→480. |
| AR02 Twins | 180×180 at (300, −930) | 260×270 at (340, −975) | ×2.17 | 16.7 s | Keep the courtyard-road gate (−840); grow south-east, clear of the Cloister and Bamboo. EastPass zone and region widen. |
| AR03 Baize | 180×180 at (0, −1470) | 300×200 at (−60, −1474) | ×1.85 | 16.1 s | Shrine (−1366) and moon gate (−1577) pin depth. A west side-basin; the Foundry wing ends at −1345. |
| AR04 Titan | 180×180 at (520, 880) | 280×320 at (554, 808) | ×2.77 | 19.0 s | West edge 414 (ossuary/loft/reliquary) and north edge 968 (nave) are held. Grows east/south; the arena mouth moves east along the nave. |
| AR05 Wu | 180×180 at (0, −2380) | 340×176 at (0, −2380) | ×1.85 | 17.1 s | Forecourt (−2292) and dawn terrace/bridge (−2470/−2540) pin depth. Widens into a mirror expanse, with a noncolliding lake beyond. |
| AR06 Wyrm | 180×180 at (0, −2830) | 400×440 at (0, −2960) | ×5.43 | 26.6 s | Nothing lies south of the summit; the shelf extends south of the bastion gate. |

Every B core passes the AABB tests in [OVERLAPS.md](OVERLAPS.md) against other zones, altars, foe posts, tablets, caches, PvP rings and other regions. Two exceptions are recorded rather than hidden:

- **Twins** sits inside its own EastPass ridge zone (as it does today), so EastPass must widen.
- **Baize** keeps today's horizontal overlap with the elevated BP_Ridge route, which needs a height-aware review in AR03.

Each arena's three extents (combat core, service/entry/exit, noncolliding scenic envelope) and its planned region bounds are in `spatial-manifest.json`.

## Measurements

| Check | Result | Evidence type |
|---|---|---|
| Walk speed | 358 studs in 16.24 s = **22.08 studs/s** average; full speed (22.40) after 0.46 s. 187 studs in 8.58 s on a second leg | Studio Play, server-issued `MoveTo` on the Wyrm-B prototype floor (seeded, not normal input) |
| Sprint / dash / roll | 33.6 / 14 in 0.22 s / 11 in 0.36 s | CombatSettings (C00) |
| Boss pursuit | Bosses use the same base walk × combat multiplier × pace (CharacterService:1503). Shen gap-closes with a lunge from 36 studs (2.5 s delay, 7 s cooldown) | Source |
| Initial engagement | B prototypes start the boss **60 studs** inside the gate and the player 15 inside, a 45-stud gap (Shen today: 85) | Prototype placement |
| Lock-on | Acquires at 60, breaks at 80. Every B diagonal is >80, so a player who deliberately retreats to the far corner loses lock. Shen's gap closer (36) and pursuit pull the fight back well inside 60 | Source, plus arithmetic on the manifest |
| Camera | Boom 8–16 with a 0.6 probe. Edges need a ≥16-stud clear retreat band before any collidable tier/arcade. The existing test enforces 12 (16 for Titan/Wyrm) | CameraController, `test_campaign_regions.luau` §3 |
| Empty pursuit | Corner-to-corner exceeds the 8–10 s review trigger for every B except a sprinted AR01 (9.1 s). This is acceptable only because the boss closes the gap; review it per arena during play. I changed no timings | Arithmetic at the measured walk |

**Scoped camera/lock policy:** none is needed for AR01. Shen fights at humanoid scale and pursues, so the global 60/80 values stay. A Wyrm-scale policy (AR06) should be decided there with the real model.

## Prototype evidence

`prototypes/` holds 18 captures (gate view at the default follow-camera offset and FOV 70, top-down with A translucent inside B, and a corner view looking back) plus `contact-sheet.jpg`. Shen, Zhao and Bull are the real templates at roster scale. Baize, Titan, Wu and Wyrm are **labelled proxy boxes** because their model files are missing (C00).

Everything is untextured blockout, built by `tools/arenas/PrototypeBuild.luau` in an unsaved temporary place; it is not production art.

## Status by evidence type

| Category | Result |
|---|---|
| Static review | All arena/fog/spawn/zone/door/region coordinates traced: `spatial_extract.luau` → `spatial-current.json`. Absolute Shen literals were found only in `AshColosseumLayout`, `ColosseumDressing`, `WorldDefinitions`, `Objectives` (gate approach, unchanged) and two tests. |
| Local regression | Not run for AR00: no game source changed. It runs at the AR01 checkpoint. |
| Studio integration | Seeded prototypes and one Play traversal in a temporary place; Play was stopped. Two Studio windows had opened the same temporary file. Measurements came from identical builds, and the prototype captures from the digest-verified window. |
| Human / multiplayer / device | Not performed. |

## Remaining dependencies and next action

- AR02–AR06 need the four missing boss models before clearance checks (pillars, flight, tail, kneel).
- Titan and Twins need either an entrance-offset field (gate X ≠ arena centre X) or a gate move. AR01 does not need one.
- **Next:** implement AR01 at 240×190 centred (0, −1990).

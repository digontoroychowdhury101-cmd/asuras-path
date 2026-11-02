# Batch 1: opening journey and forge (Mac)

Base revision `c2b7a1f`; the batch commit is the one containing this file. Build: scripts 273, bytes 2164689, digest 1160571320 (`tools/build.py` and `tools/qa/SourceDigest.luau` in Studio agree). `tools/verify_all.sh` passes. Studio: fresh in-memory mock profile, about 15 fps, MCP-driven keys and mouse. No live DataStore, hardware or human play.

**Status: implemented; the ordinary earned route is NOT accepted.** No MCP-driven fight beat a real monk.

## Implemented (existing systems extended)
- Objectives: opening route Training → first monk → inscription → Cloister → smith, with cross-region smith return and shortage text (`Objectives.luau`, `ObjectiveController`). Warden stays optional; no new miniboss.
- Contextual hints for rally, ceiling injury, heal and deathblow (`TutorialRules`, `TutorialController`). Session-only, not persisted. Durable milestones derive from the profile (`Rules.milestones`).
- Training ring fix: finishing or skipping mid-fight stays protected until the player walks out. Found in Studio, where skipping at 1 HP killed the player and dropped 500 Essence.
- Forge: `ForgeQuote` shared previews; Gao panel with weapon list, current/next stats, cost, ore count, refusal text and deliberate equip; `Rules.upgradeRefusal`, `MaxTier`; one profile debit; confirmation spent before charge; stale quotes uncharged; `Refused` reply when hunted.
- Economy: no tuning needed. Start 500 Essence (starting currency), 0 ore. +1 costs 250 Essence + 1 ore; a felled foe with Essence leaves 1 ore; the Hermit also sells ore at 80 Essence (not yet stated in the UI).

## Measured in Studio
| Check | Evidence type | Result |
|---|---|---|
| Bonfire, gate, kindle | real input | objective at gate ~20 s, kindled ~25 s from first control |
| Skip, death card, bloodstain recovery, Pillars +100, altar Travel | real input, earlier run | pass |
| +0 light on phantom | real input | 8 per hit (5 hits) |
| Buy +1 by click | seeded funds, real click | 6500→6250 Essence, ore 3→2, preview 8.8→9.6 |
| Select Dao, take in hand, take Jian back | seeded Dao, real clicks | `AsuraMainhand` and `AsuraWeapon` follow; Jian keeps +1, Dao shows +0 |
| Three rapid clicks on one quote | seeded, real clicks | exactly one tier: +1→+2, 6250→5543, ore 2→0 |
| Close, reopen | real input | panel recovers on weapon in hand |
| +2 light on phantom | real input | 9.6 per hit (3 hits) |
| Insufficient ore | real click, no seed | refusal shown, nothing moved |
| Monk kill | **diagnostic only** (KOProtected) | +45 unbanked, +1 ore, objective advances |

Every seeded run used `OpeningSeed` (mock only, unsaved, removed by Stop). Log: `studio_walk.log`.

## Offline only
`test_progression_runtime.py`: duplicate delivery, stale quote, forged/unowned/malformed packets, max tier, wrong location and state refusals, per-weapon levels, release and reload through an **in-memory** store. Death and a real process reload with the forge were not run in Studio; neither proves live DataStore.

## Open
- Real monk fights through MCP lost: the monk took the player 100→0 in about 2.5–5 s at this input rate. Monk lethality is for human judgement; not tuned.
- Cloister kindle and `ForgeHome` marker not walked in Studio (offline only). Cloister rest was refused while a monk hunted the player (real rule).
- Gamepad and touch forge layouts not exercised here.
- Non-fatal `CampaignTerrain` Region3 grid error at boot, not from this batch and not fixed here.

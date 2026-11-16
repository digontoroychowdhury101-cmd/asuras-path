Plan: list every open-world check that needs two or more clients or servers, with its status, pass criteria and past attempts, for the other computer to run.
Plan: map each to its existing harness, give exact launch and identity steps, and name the gaps that have no harness. This MacBook runs none of them (creator standing rule).

# Multi-client pending list (for the other computer)

Status for every row: **pending — other computer**. Nothing below was run on this Mac. Sources read: CONTINUATION.md, LEDGER.md, handoff/VALIDATION.md, workers 10b-shen-multi, 10c-studio, 09c-studio, 10b-studio, 18-perf.

## 1. Pending multi-client checks

| # | Check | Pass criteria | Attempted before (evidence) | Still open |
|---|---|---|---|---|
| 1 | Lobby casual duel, 2 players plus spectator (Ring_SanctuaryPromenade) | Challenge, accept, countdown to Fighting on both, attack lowers HP, spectator unaffected, mid-match leave releases and restores survivor, wager settles once | workers/10c-studio.md run 3 passed (28/30, 2 harness artefacts). Runs 1-2 failed with StepOnThreshold. workers/09c-studio.md: baseline 462022588 also 1/3 StepOnThreshold, so pre-existing | Re-run 3x on current build; StepOnThreshold cause unresolved |
| 2 | Lobby ranked duel: queue, pair, Fighting, KO, release | Both paired on Promenade, KO result delivered to the winner, ELO/result correct | workers/10c-studio.md: queue, pair, Fighting, release pass. Winner message check matched nothing | Winner delivery and ELO not confirmed |
| 3 | Shen sealed fight, 2 participants (real entry, not seeded) | Both players inside on the real route, both engaged, KO resets gate | workers/10b-shen-multi.md: both engaged, one dies while other fights on, win gives 4000 Essence each. But both were seeded by server teleport | Second player refused with ArenaOccupied; no real two-participant entry was ever made |
| 4 | Shen refusal feedback to the late player | Refused player sees a REASONS toast | 10b-shen-multi.md: prompt path drops result, so no feedback. LEDGER lists L6b as source-only | Not seen in Studio |
| 5 | Shen arena reachable on foot (full terrain) | Players can walk in and out; Shen can see them | 10b-shen-multi.md FINDING: terrain wedge z -8228..-8248 seals the arena; "Can not find a route" both ways | No recorded fix; LEDGER R6 X fixed only the walk-out re-seal trap |
| 6 | Shen re-entry after win (BossFelled) | Refusal is explained to the player | 10b-shen-multi.md item 2: silent refusal | Open |
| 7 | Shen leave by disconnect (PlayerRemoving) | Participant dropped, fight ends when none left | 10b-shen-multi.md: not driven ("would end one client") | Open |
| 8 | Overworld tile priority, 2 players far apart | Each player's nearest altar and tiles written first; no unwritten ground for either | Solo only: CONTINUATION C3 sprint run (workers/10-c3-fixes.md) | No two-player evidence |
| 9 | Radar and map, 2 players | Each player sees own marker; radar hidden in overworld for both; map arrow correct for own position | Solo only: workers/10c-studio.md (map resolutions, 0.00 error). Map does not follow the player (known) | No two-player evidence |
| 10 | Heartbeat and budget with 2 players connected | Heartbeat >=45 Hz while writing, TerrainVoxels <=185-200 MB | workers/18-perf.md is source-only; PerfBudget is Studio-only and unmeasured | Not measured with 2 clients |

## 2. Harness and launch

**Existing harness files (under tools/qa/):**
- `ColosseumMultiClient.server.luau` and `.client.luau`: lobby duel, ranked and casual; run with `StudioTestService:ExecuteMultiplayerTestAsync(3, {})` (rows 1, 2).
- `LaunchStudioTests.luau`: scenario-driven, 2 clients (rows 1, 2; scenario arg).
- `OmniPvP.server.luau` and `.client.luau`: PvP, 2 clients (rows 1, 2).
- `LobbyMultiplayer.server.luau` and `.client.luau`: lobby multiplayer. No worker note records a run, so treat as unverified.
- `ShenProbe.server.luau`: single-server probe. Not checked for multi-client use. No committed Shen two-player driver exists (see gaps).
- Python: `tools/studio_mcp.py` (`--digest`, bridge), `tools/run_studiomcp.py`. The qa_inject and qa_place scripts were not read here.
- Offline suites only, not Studio drivers: `tools/test_boss_runtime.py`, `tools/test_shen_integration.py`, `tools/test_world_map.luau`, `tools/test_overworld_order.luau`.

**Launch steps:**
1. Pull `ux/onboarding-overhaul` and verify the dated checkpoint: `shasum -a 256 -c places/checkpoints/AsurasPath_OpenWorld_2026-11-16.sha256` (must print OK).
2. Make a working copy, never open the dated file: `cp places/checkpoints/AsurasPath_OpenWorld_2026-11-16.rbxlx work/multiclient/AsurasPath_TEST.rbxlx`.
3. Open the copy in Studio via File > Open from File (not the cloud place, not the dated file).
4. Identity check, in Edit mode: confirm `persistedToCloud = false` (not Team Create cloud). Then run `tools/qa/SourceDigest.luau` in the Command Bar and compare with `python3 tools/studio_mcp.py --digest work/multiclient/AsurasPath_TEST.rbxlx`. Expect 275 scripts, 3149701 bytes, digest 1516687798. Any other digest: stop.
5. Insert the harness scripts in memory only (never save). Command Bar, or Test tab > Clients and Servers > Local Server, 2 or 3 players. Record the Studio ids.
6. Run `ExecuteMultiplayerTestAsync(N, {})` (or `LaunchStudioTests` with the scenario) and collect the `[ColoQA RESULT]` lines.
7. Remove the in-memory scripts, End Test, and do not save the place.

**Where to write results:** a new file `outputs/claude-open-world-2026-11-14/workers/<id>-multiclient-run.md` (one log line per step, as in 10c-studio.md), with screenshots under `captures/multiclient/`. Each row above gets a verdict: PASS, FAIL or BLOCKED, with the run count.

## 3. Gaps with no harness

- **Shen with two real participants:** no committed driver. Earlier runs used ad hoc in-memory scripts and server teleports, which are not in the repo.
- **Shen leave by disconnect (row 7):** no driver.
- **Overworld tile priority, 2 far-apart players (row 8):** no multi-client test exists. A new driver is needed.
- **Radar and map with 2 players (row 9):** no harness.
- **Heartbeat with 2 clients (row 10):** no measurement harness; PerfBudget is only attributes in Studio.
- **Terrain plug in the Shen arena (row 5):** a terrain fix is not yet done, so no test can pass.
- **Lobby multiplayer (LobbyMultiplayer.*):** a harness exists but has never been recorded as run.

Skipped: did not read the qa_inject and qa_place scripts, the ShenProbe body, or the LobbyMultiplayer scripts. Risk: the harness lists are from file names and worker notes, not from running anything. Nothing was executed; no Studio, git or tests touched.

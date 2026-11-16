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

## R2-5 harnesses

Plan (written first): add two write-only harnesses under tools/qa/ for the two gaps in section 3 (Shen with two players, row 3/4/6/7; terrain priority with two far-apart players, row 8), compile-check them, document launch. Nothing run; no Studio MCP; no commit (lane brief).
- [checkpoint 1] Design read from source: WorldService traverseGate (refuses with ArenaOccupied while fights[gate] exists, line ~889; the prompt handler now sets AsuraResult "!ArenaOccupied", toast text in InterfaceController REASONS line 79, so the 10b "no feedback" finding is fixed in source), updateGates (non-participant inside Boss.Arena while a fight runs is teleported to Gate.Outside; reset when living == 0), startFight (only players inside the arena at start join), PlayerRemoving (drops participant, endFight if none left), setGate (wall CanCollide + Sealed attribute). So by design B outside cannot join: prompt refused with feedback, walker blocked by the sealed wall or expelled. OverworldTerrain: Priority + Refocus (players inside the Frame and their 2 s look-ahead, URGENT 256 studs first), OverworldService focus()/guard()/SiteReady/Ready(altarId), Stats.Parallel/Inline.
- [checkpoint 2] Files written, compiled with work/bin/luau/luau-compile --null: OK for all three.

### tools/qa/ShenMultiClient.server.luau + .client.luau (needs RemoteEvent "ShenQA" in ReplicatedStorage; 2 players)
Asserts (PASS/FAIL line each, prefix `[ShenMC]`, final `[ShenMC RESULT] {json}`):
1. gate wall found, open; both start outside the arena;
2. A walks in on foot (Humanoid:MoveTo to the trigger) and the gate seals (fallback to the prompt, logged as INFO "entry route used");
3. A.AsuraEncounter = GrandmasterShen, B.AsuraEncounter nil, boss present, Shen entity found (INFO: AI mode, Idle = the 10b terrain-plug symptom);
4. B outside: prompt refused with `!ArenaOccupied`; B walking at the sealed gate does not become a participant nor stay in the arena; fight and seal untouched;
5. replication to both clients: Sealed, AsuraEncounter per client, Shen Humanoid.Health/MaxHealth equals server Fighter.ActiveHP after seeded damage (B: if StreamingEnabled and B is outside stream range the check is INFO not FAIL);
6. A killed by Shen (seeded lethal hit): gate unsealed, Shen despawned, A encounter nil, B untouched;
7. B then walks in (fresh sealed fight), leaves mid-fight via LeaveTest: PlayerRemoving unseals and resets, A has no encounter.
Not covered: A and B both as participants (the shipped design refuses a second player once sealed; both-participants needs a simultaneous walk-in and cannot be driven reliably, earlier runs seeded it), BossFelled re-entry (row 6), terrain-plug fix (row 5). Players are KOProtected until the seeded death. Evidence type: seeded Studio diagnostic.

### tools/qa/TerrainPriorityMultiClient.server.luau (needs RemoteEvent "TerrainQA"; no client script; 2 players)
Two players placed right after AsuraReady at Altar_MonasteryGate (glade) and Altar_BasinCistern (~5900 studs apart, constants at top; PLACE_EARLY true), anchored until their site is Ready, then released. Asserts (`[TerrainMC]`): targets > 3000 apart; each player's ground written (Terrain.Verdict nil and Ready(site)) within 90 s; both grounded without falls (5 s watch after release; Fell verdict, Y drop > 60, KO); no player left on unwritten ground (Map_Overworld Rescues delta 0, none free-standing over Unwritten); server Heartbeat mean of 1 s windows >= 45 Hz and no window < 30 Hz while writing; generation did not fail. INFO: placement-time readiness, per-player seconds, OverworldTerrain.Stats (Parallel/Inline deltas, WriteCalls, WriteMs, ComputeMs, YieldMs), Done/Total.
Caveat: with PLACE_EARLY the guard is expected to bounce the far player once any altar is ready and the far site is not (that is its design); the harness reports it as FAIL on the guard line and puts the player back so timing continues. Set PLACE_EARLY=false to place each player only when his site is written (the real travel rule) for a guard-free timing run; the two runs together separate "priority speed" from "guard behaviour".

### Launch steps (both; other computer only)
1. `git pull --rebase origin ux/onboarding-overhaul`, note `git rev-parse --short HEAD`.
2. `mkdir -p work/multiclient && python3 tools/build.py --output work/multiclient/AsurasPath_MC.rbxlx` (fresh build of the current commit).
3. Digest of the plain build: `python3 tools/studio_mcp.py --digest work/multiclient/AsurasPath_MC.rbxlx` (record it).
4. Server harness into a copy: `python3 tools/qa/qa_place.py work/multiclient/AsurasPath_MC_QA.rbxlx tools/qa/ShenMultiClient.server.luau tools/qa/TerrainPriorityMultiClient.server.luau`. This builds from default.project.json of the same commit with the probes as `QA_<name>` Scripts in ServerScriptService (qa_inject.py is refused by newer Studio). Run one harness per Play: disable the other (Disabled = true in the Explorer) so they do not both call EndTest.
5. Open the QA copy via File > Open from File (never the dated checkpoint, never the cloud place). Edit mode, Command Bar: confirm `game.PlaceId`/`game:GetService("RunService"):IsStudio()` and that persistedToCloud = false (Team Create off). Run tools/qa/SourceDigest.luau; expected = step 3 digest plus exactly the two QA scripts (so scripts +2, otherwise identical); any other difference: stop.
6. In memory only (Command Bar, Edit mode): create RemoteEvent `ShenQA` (Shen) or `TerrainQA` (terrain) in ReplicatedStorage; for Shen also paste tools/qa/ShenMultiClient.client.luau as a LocalScript into StarterPlayer.StarterPlayerScripts (it is cloned into each client's PlayerScripts). Do not save.
7. Test tab > Clients and Servers > Local Server, Players = 2, Start. (Or `game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, {})`.) The server ends the test itself after printing RESULT.
8. Results: copy the server output lines `[ShenMC ...]` / `[TerrainMC ...]` into a new file workers/<id>-multiclient-run.md (one block per harness, Studio ids, commit hash, digest). Delete nothing; End Test and close without saving.

Status: **pending — other computer** for both ShenMultiClient and TerrainPriorityMultiClient. Compile-checked only (luau-compile --null); never executed, so selectors such as the gate wall name FogGate_Gate_AshColosseum, client-side prompt:InputHoldBegin and EndTest from the harness are unproven.

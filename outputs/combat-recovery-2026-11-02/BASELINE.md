# Baseline — combat recovery Stage 1 (2 November 2026, Windows)

## 1. Provenance and environment

| Item | Value |
|---|---|
| Branch / HEAD | `ux/onboarding-overhaul` @ `7dae4f7` (fast-forwarded from `497e23b`; the new commit adds prompt docs only, so combat source is identical to the audited commit) |
| Working tree at start | clean |
| OS | Windows 11 Home 10.0.26300 |
| Tooling | `work/bin/luau` (luau, luau-compile, luau-analyze), Rojo 7.7.1, Python 3.15.0, Git Bash. `gh` CLI absent (GitHub REST API via curl used instead). |
| Current build script digest | `scripts 264 bytes 2009167 digest 1345127265` (`tools/studio_mcp.py --digest` on the verifier's temp build) |
| Open Studio (Edit, `4e3a0d70…`) | `scripts 263 bytes 1981562 digest 192984849`. **Does not match the current build.** Studio version was not read. |
| Open Studio (Play, `5a2efb23…`) | Running about 50 min with 1 player and 22 fighters. Provenance unverified. Only read from, not modified or stopped. |
| `places/AsurasPath.rbxlx` | Saved 15:39 today. A `.lock` is present (open in Studio). **Not rebuilt in Stage 1**: no mapped source changed, and rebuilding while Studio holds it risks overwriting saved Studio work. |
| Supported multiplayer launch | `StudioTestService:ExecuteMultiplayerTestAsync(2, {})` with the unmapped OmniPvP harness inserted temporarily (`tools/qa/OmniPvP.*`). Real-device multiplayer is not available here. |

Recent living-state entries were rechecked: group attack turns (`MobSpacing.TurnGap`/`TurnMax`), monk and swordsman gaits and the Warden standoff are present in source. The observer catch-up re-run listed as a TODO (2026-11-01) is still open.

## 2. Existing test suites

`bash tools/verify_all.sh`: **PASS**, 14/14 steps in 56 s (`logs/verify_all_baseline.log`). It covers omni combat 84, combat contact 68, combat presentation 165, boss encounters 286 and others. Evidence class: offline regression / engine emulation. It does **not** test latency, buffer expiry, prediction, animation timebase, hitstop, or blade/volume agreement. Misleading assertion: `test_omni_combat.luau:27` (`"Deflect = 100,"` matches input priority, not the 0.10 s window).

## 3. OmniPvP harness: what it proves and what it does not

What it does: two real Studio clients join a casual Promenade duel. The server teleports both, forces Jian, and has each client fire the **production** `ActionIntent` remote on the server's cue. Defenses are fired when the **server** sees the attacker's windup reach `impact − lead`.

What it does **not** prove, with weaknesses:
1. **No ordinary input.** Presses are remote calls cued by perfect server timing, a server-timed bot. They say nothing about human fairness or defender-visible timing.
2. **`result.passed = ok`** only records whether `xpcall` raised. Failed checks are counted in `result.failed` but do not flip `passed`.
3. **Lenient thresholds**: dodge passes at 2/3 and deflect at 1/4.
4. **Incomplete outcome kinds**: the spin check counts `Hit` only, not `CounterHit`, `Block` or `Armored`. The 35° whiff check ignores `CounterHit`.
5. **Ready ≠ state received**: `Ready` fires on `AsuraClientReady`, not on a decoded own snapshot.
6. **Sequence ownership race**: the harness client sets `seq = max(seq, serverLastSeq) + 1` while the production client keeps sending its own seqs. A harness intent can be silently dropped (`seq <= LastSeq`).
7. **Incomplete reset**: `reset()` restores HP, posture and stamina only. It does not clear fighter state, input buffer, `DeflectChain`, `DashChain`, forced weapon or `KOProtected`, so trials are not independent.
8. **No cleanup**: KO protection and forced weapons persist, and the duel is never ended. The inserted instances must be removed by hand ("never save").
9. **Asynchronous logging**: event capture is a `Subscribe` callback, and the client `Observed` messages race with the checks. There is no per-action correlation ID.
10. **Local ping is about 0.5 ms**, so no latency condition is ever exercised.

## 4. Measurements

| Metric | Value | Class | Notes |
|---|---|---|---|
| Client frame time (RenderStepped, 4 s, 94 frames) | p50 **42.4 ms**, p95 45.6, p99 48.9 (about 23 fps) | Seeded Studio diagnostic, unverified build | Focus and graphics quality not recorded. At this rate "one rendered frame" is 42 ms, nearly half the 100 ms deflect window. |
| Active animation tracks (client) | 30 | Same | 22 fighters loaded. |
| Server Heartbeat | 0.83 ms. Physics 59.9 Hz | Same | `CharacterService.GetPerformance` not readable from the plugin context (separate module instance). Step p95 and dropped steps BLOCKED. |
| Ping | 0.5 ms | Same | Local Studio; no RTT/one-way separation possible. |
| Server queue life left after rewind | `max(0, 100 ms − one-way)` | Offline (derived from code) | 0 at ≥ 100 ms one-way. |
| Local action start delay | ≈ RTT + 0–33 ms snapshot interval + attribute replication | Offline (derived) | Not yet measured live. |
| Dash distance executed by client | `DashDistance × (Duration − StateElapsed_at_sample)/Duration` | Offline (derived) | Loses the sample-age share. Transit time is ignored entirely (no sample time). |
| Snapshot interval | 2 ticks (30 Hz), only when the packed string changes | Static | Actual arrival cadence unmeasured. |

**Not measured (BLOCKED until the instrumented, verified build is open):** press→visible, press→server start, snapshot age, contact→feedback, visible/server contact error, dash start vs grant, server step p50/p95/p99, dropped steps, and ordinary-input captures for Jian/orbit/monk/swordsman/groups/bosses. Reason: the open Studio place is not the current build. The required instrumentation (stable IDs, ack records) is part of Stage 2. Collecting timings now would measure an unknown build with no correlation IDs.

## 5. Offline tables produced
- `frame_table.md`: every weapon's tempo-scaled frame data and the light-link exchange classification.
- `anim_coverage_baseline.md`: authored/borrowed/silent animation slots per weapon.

## 6. Stage 2 before/after (seeded Studio diagnostic, single client)

**Provenance.** Each place was built from the checkout into `places/`, opened in its own Studio session and digest-checked in Edit with `tools/qa/SourceDigest.luau` before Play. The user's open place was never touched.

| Place | Source | Scripts / bytes / digest | Studio |
|---|---|---|---|
| Before | HEAD `be08811` → `stage2_before_be08811.rbxlx` | Verified in Edit | pid 28236 |
| After | Working tree → `stage2_after.rbxlx` | 265 / 2035921 / 454417533 | pid 29064 |
| After, fixed | `stage2_after_fix.rbxlx` (adds the drift clamp) | 265 / 2036120 / 1262899227 | `CharacterService` synced into pid 29064 Edit; the live digest then matched exactly |

**Temporary QA additions.** `MonasteryProbe.server.luau` and `Stage2Timing.{server,client}.luau` were inserted at Play by `qa_inject.py` and removed by Stop; the Edit digest afterwards equalled the build. The test area was cleared of foes and the player KO-protected and placed at (0, 3.5, −740). `IncomingReplicationLag` was set on client and server, then reset to 0. Window focus was confirmed for every run (`focused_share` 1.0, OS foreground recorded in each summary).

| Run | Inputs | Frame p50 / p95 ms | Server tick p99 ms | Press→ack p50 ms | Receipt→start | Press→local pose |
|---|---|---|---|---|---|---|
| before_lag0 | 6 L1, 3 F | 41.7 / 42.9 | 43.4 | 86.5 | 33.3 ms | L1 ≈ 126 ms. F 126–168 ms |
| before_lag0_b | 4 dash, 3 heavy, 3 F | 41.8 / 43.8 | 48.1 | 90.9 | 33.3 ms | Dash 126–167. Heavy 126–169. F 132–168 |
| before_lag100 | 2 dash, 2 heavy, 2 F, 4 L1 | 41.8 / 43.6 | 49.0 | 337.7 | 33.3 ms | All ≈ 375–389 ms |
| before_lag100_combo | 3 × 4 clicks | 42.9 / 55.1 | 52.3 | 340.5 | 33.3 ms | Pose for only 3 of 12 presses (≈ 371–378 ms); the other 9 were not seen |
| after_lag0 | as before_lag0 + dashes | 41.9 / 45.0 | 45.4 | 127.6 | 33.3 ms | L1/F/Heavy ≈ 1.0–1.2 ms. Dash ≈ 42 ms. Contaminated: a Sparring Phantom hit and KO'd the player, so 2 presses Expired legitimately |
| after_lag0_b (fixed) | 4 dash, 3 heavy, 3 F | 44.3 / 48.2 | 49.4 | 135.2 | 33.3 ms | Heavy/F 1.3–1.9 ms. Dash 46–51 ms. 10/10 Executed |
| after_lag100 (fixed) | 2 dash, 2 heavy, 2 F, 4 L1 | 44.5 / 47.6 | 48.1 | 363.2 | 33.3 ms | L1/Heavy/F 1.3–2.2 ms. Dash ≈ 45 ms. 10/10 Executed |
| after_lag100_combo (fixed) | 3 × 4 clicks | 46.1 / 51.6 | 51.9 | 381.3 | 33.3 ms | First click of each string ≈ 2 ms (predicted from Idle). Follow-ups 412–945 ms (not predicted, by scope); 2 of 12 not seen (see note). 12/12 Executed |

**Notes.**
- The before runs have no terminal column because HEAD has no `AsuraIntent` records.
- The press→ack figure rises by about 40 ms (one client frame) after the change. The ack is still written when the server receives the press, so the cause is **not isolated**. Candidates are the larger v4 record or the extra `AsuraIntent` attribute sharing the frame. Receipt→start is unchanged, and the prediction removes the visible cost.
- The dash pose takes about 45 ms. That is about one frame at the measured 44 ms frame time, and fits the drive starting on the next render step. It was not traced further.
- "Local pose" is the next `AnimationPlayed` after the press. A follow-up swing of the same move re-seeks the existing track, so this probe does not see it. That is why the combo run shows 2 misses and the 945 ms values. This is Stage 3 animation work, not a server timing fault.
- Scripted MCP clicks arrived about 460 ms apart, not 160 ms, so neither run chained L1→L2.
- The one-tick server receipt→start (33.3 ms = 2 ticks) is the drain point after `Combat.step`, as specified.
- **Remote windup visibility (A10) was NOT RUN.** It needs a second observer client, which is Stage 4.

**Defect found while measuring.** After about 2 h of uptime, `InputBuffer.push` raised "receipt precedes the press" after the ack had already been set. Seqs 20–25 of the first after_lag0_b attempt were lost with no terminal record (the fixed rerun overwrote those logs). Studio output said `InputBuffer:201: InputBuffer.push: receipt precedes the press`. It is fixed by clamping the accepted press to receipt, and offline case T-IN-06 covers it.

## 7. Defect ledger
See `DEFECT_LEDGER.md`. 13 of 14 master findings are confirmed in source (one is partially inspected, and #14 is measured with a provenance caveat).

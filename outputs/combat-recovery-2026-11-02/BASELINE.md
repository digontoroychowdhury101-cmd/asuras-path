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

## 6. Defect ledger
See `DEFECT_LEDGER.md`. 13 of 14 master findings are confirmed in source (one is partially inspected, and #14 is measured with a provenance caveat).

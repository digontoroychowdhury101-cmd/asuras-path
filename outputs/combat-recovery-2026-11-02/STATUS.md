# Combat recovery — status

| Stage | State | Date |
|---|---|---|
| 1 Baseline, research, specification | **Done** (specification and offline evidence). Live pipeline measurements are BLOCKED and carried into Stage 4. | 2026-11-02 |
| 2 Timing, input and parry | **Done, closure pass applied** (implementation, offline fixtures and seeded single-client Studio diagnostics on digest-verified builds). Multiplayer is **not** verified; that is Stage 4. Pending: rejected-dash correction against real Studio walls and slopes; A1 is not met on the changed-pose measure. | 2026-11-02 |
| 3 Animation, footwork and contact | Not started | — |
| 4 Real multiplayer verification | Not started | — |
| 5 Feel acceptance and handoff | Not started | — |

## Stage 1 summary

**Highest-impact confirmed defects (static source and offline tables):**
1. **Late presses silently die** (#1). Press time is rewound up to 150 ms, but queue lifetime is counted from that rewound time (100 ms). At about 100 ms one-way, a buffered attack, dodge or parry expires before it can execute, after the client was already told "Buffered".
2. **Nothing the player does starts locally** (#2, #3). Attacks and dashes wait a full round trip plus a snapshot. Animation clocks ignore transit (no sample time in the record), late swings catch up at 2×, and the dash loses distance and spends its i-frames before the body moves.
3. **Parries are not 1:1 and not latency-consistent** (#8, #9). One press deflects every contact in its window. Geometry is rewound but facing and state are present-time. Boss pulses and closing sweeps resolve before that tick's defensive intents. Boss Perilous Thrust has its own literal 0.1 s window.
4. **Most weapons have no swing animation** (#5). 10 of 12 families play no action clip. TwinDaggers borrows Jian clips with different timings.
5. **Hitstop fights the animation clock** (#11). Three systems write `AdjustSpeed`: stale speeds are restored, there are hard re-seats after freezes and gait freezes while roots slide.
6. **Light strings are almost all true combos** (#10). 17/28 links leave no defensive answer even at the slowest continuation.
7. **Studio frame rate measured at about 23 fps** (p50 42 ms) on an unverified session. This must be re-measured with focus on the verified build.

**Implementation choices (to reach running code):** contract-defined intent lifetimes with terminal acks. `ActionSeq`/`SampleTick` in the packed record. Phase-ordered ticks with simultaneous resolution. One-press-one-token parries with a ≤ 100 ms defender grace evaluated at contact time. Local prediction with bounded reconciliation (Orange Duck velocity-bounded adjustment). Joint-offset inertialization (Orange Duck spring decay). IKControl foot locking and stance stepping (ALS and Overgrowth concepts). Baked blade trajectories with clip phase metadata (Epic Fight concept, written independently). Details: `TIMING_CONTRACT.md`, `INTEGRATION_MAP.md`.

**Design direction (creator, added mid-stage):** fast, aggressive wuxia combat, with omnidirectional footwork, precise deflections and flowing counters. `DESIGN_INTENT.md` defines the rhythm (beats, strings with deliberate seams), movement freedom, commitment windows and defensive opportunities, and adds the T-MX moving-exchange cases and target A10 (readable observer windups). It found one new gap against the direction: combo follow-ups can only turn 0–24°, so a string cannot redirect to a flanking foe (T-MX-04 fails by inspection). It also proposes **Borrowed Force (借力)**: deflects bank up to 3 charges, spent on a free-direction riposte, a flank step or a cheaper Art. This is a proposal only, waiting for your approval, and comes after the Stage 2 parry token.

**Not done / open:** live pipeline timings, ordinary-input captures and the OmniPvP run are all BLOCKED because the open Studio place does not match the build and instrumentation does not exist yet. Reference-game inspection NOT RUN. Human judgments open.

## Stage 2 summary

**What changed (all server-authoritative; 60 Hz, 150 ms rewind, 1.4× tempo and the 100 ms deflect baseline are unchanged):**
1. **Input lifetimes** (ledger #1, #13). Queue lifetime counts from server receipt (100 ms) and there is an absolute execute-by of press + 250 ms. Every intent ends with exactly one terminal record (`Executed`, `Rejected`, `Expired`, `Stale`, `Superseded`, `Cancelled`, `Flushed`, `Evicted`) in the `AsuraIntent` attribute, which keeps the last 8. Spells join the same boundary queue.
2. **Replicated timeline** (#3). Codec v4 (70 bytes) carries `ActionSeq`, `SampleTick` and a server-time `SampleStamp`. Clients age each snapshot (capped at 150 ms) and key animation occurrences by `ActionSeq`.
3. **Bounded local prediction** (#2). L1/Heavy from Idle, Dash/Roll from Idle (exact grant distance) and the guard pose start locally. Each is confirmed by `ActionSeq` and rolled back on a non-Executed terminal record or after 0.5 s.
4. **Contact phase order and defender grace** (#8, #9). Contacts are detected for all fighters, then resolved together (trades are symmetric, with no entity-id bias). Player defenders who could still defend get a grace `G = min(ping/2 + 1 tick, 100 ms)`. Defense is judged at contact time. Boss impacts resolve after that tick's intents. Perilous Thrust uses the shared window rule.
5. **Exchange answerability** (#10). A 100 ms point into light hitstun allows Deflect or Block only, with no attack or dash. In `frame_table_stage2.md` every light link now leaves at least 25 ms of deflect answer (before: 20 of 28 links had none). Attack answers are unchanged, so true combos are still true combos.

**Studio after-measurements** (seeded diagnostic, single client, digest-verified). In the three runs on the fixed build, all 32/32 presses were Executed with one terminal record each. With 100 ms injected lag, a new action track appeared in about 2 ms instead of about 377 ms, and a dash started moving in about 45 ms. Frame time is still about 44 ms (A9 unmet, not a Stage 2 target). Details are in `BASELINE.md` §6. *Corrected by the closure pass:* the 2 ms figure is a **track-start proxy**, not a changed pose. The 33.3 ms receipt→start was a probe artifact; the real delay is one tick.

## Stage 2 closure pass (against d6440f8)

Full tables: `closure/CLOSURE.md`. Old-code results: `closure/before_d6440f8.md`. Offline evidence: `tools/test_stage2_closure.luau` (56/56) and `tools/test_stage2_timing.luau` (111/111). Studio evidence: `logs/closure_{lag0,lag100,combo}_*` on `places/stage2_closure.rbxlx` (digest 728868348).
1. **Intent-correlated confirmation.** Codec v5 (74 bytes) adds `IntentSeq`, the client intent that started the current action. A prediction is confirmed only by a sample naming its own seq. An unrelated `ActionSeq` change (a hit, a guard change) no longer confirms anything. Executed-then-interrupted ends without rollback. Older samples are dropped. Regressions P-01..P-07 cover all of these.
2. **Contact snapshots.** Defender state, move, armor, weapon, poise and invulnerability, and the attacker's weapon and damage scaling, are frozen at t_c. Geometry and facing come from detection at the attacker's rewound time. Deflect and press-anchored dashes are judged at resolution; resources and stun are applied at resolution. A held contact no longer writes a newer swing's hit registry, and a KO'd attacker is no longer revived by a late deflect (D-01..D-08; D-03, D-06, D-07 and D-08 failed on d6440f8).
3. **Grace by defense type.** Parry: covered. Dash: before, a dash pressed before t_c but granted in the grace was **hit**. Its i-frames now anchor to the accepted press while a contact is held. Roll keeps its own 40 ms i-frame start. Boss pulses and AI area waves: **no grace** (guarantee narrowed and documented). Added hit-confirm delay: 16.7 / 50 / 66.7 / 100 ms at 0 / 50 / 100 / ≥ 200 ms ping; NPCs 0. Grace was not widened.
4. **Measurement by ID.** Probe v2 ties each press to its intent seq and reports occurrence, the track-start proxy, changed pose and body movement separately, with missing values and outliers kept. Lag 0 / lag 100: changed pose p50 85 / 87 ms (≈ the second rendered frame at ≈ 42 ms frames, so **A1 is not met**); dash body move 43 ms (first frame).
5. **Receipt→start = one tick** (16.7 ms in every run; R-01). Rejected-dash correction undoes only the drive's own travel: horizontal, swept against walls, never moving a respawned or KO'd body. Real Studio wall and slope geometry is **PENDING**.
6. **Combo chain** (automated OS clicks via `jian_combo_clicks.ps1`, not human play): L1→L2→L3→L4 executed in 3 of 3 chains, at spacings of 96–186 ms. Follow-ups are server-started (not predicted); visual continuity is Stage 3.

**Defect found and fixed during measurement.** After about 2 h of server uptime, `simTime` drifts just below the tick grid. `Tempo.reconcile` then snapped a press slightly after receipt, and `InputBuffer.push` raised **after** the ack. The press was lost with no terminal record. The accepted press is now clamped to receipt. Offline case T-IN-06 fails on the old code with the same Studio error.

**Not done / remaining blockers.**
- **Multiplayer NOT verified.** These are single-client runs with `IncomingReplicationLag`. The two-client, RTT-bucket and remote-observer measurements (A3, A8 live, A10 / T-MX-08) belong to Stage 4.
- **Animation is not complete (Stage 3).** That covers 10 silent families, inertialization, bounded phase correction (the `DRIFT` seat and `CATCH_UP` remain), foot planting, blade trajectories and hitstop ownership. Back-to-back same-move swings re-seek one track. The local-pose probe cannot see that, and it is what produced the two misses and the 945 ms outliers in `after_lag100_combo`.
- **Studio MCP input spacing.** Scripted clicks arrive about 460 ms apart, not the 160 ms requested. *Resolved in the closure pass* with scheduled OS clicks (automated, not human): the chain executes L1→L4.
- **A1 (≤ 1 frame to a changed pose) is not met** at ≈ 24 fps: changed pose arrives on the second frame. A predicted dash's animation occurrence waits for confirmation even though the body moves at once. Both are for Stage 3.
- **Rejected-dash correction against real Studio walls and slopes is pending.** Descending ground is not corrected (horizontal only).
- `EnvironmentService.luau` is still unmapped in `default.project.json`, as it was before Stage 2. It is unrelated and left alone.
- The redirect budget (T-MX-04) and string seams are undecided.
- Borrowed Force remains a proposal only.

## Files
`BASELINE.md`, `DESIGN_INTENT.md`, `DEFECT_LEDGER.md`, `RESEARCH.md`, `INTEGRATION_MAP.md`, `TIMING_CONTRACT.md`, `TEST_MATRIX.md`, `results.json`, `frame_table.md`, `frame_table_stage2.md`, `anim_coverage_baseline.md`, `logs/` (Stage 1 baseline log and Stage 2 `before_*`/`after_*` client, server and summary JSON), `places/` (the generated `stage2_before_be08811.rbxlx`, `stage2_after.rbxlx`, `stage2_after_fix.rbxlx` and `stage2_closure.rbxlx` test places), `closure/` (closure-pass results and before-probe). Stage 1 tools: `tools/combat_frame_table.luau`, `tools/combat_anim_coverage.luau`. Stage 2 tools: `tools/test_stage2_timing.luau` (111 checks), `tools/qa/Stage2Timing.{server,client}.luau` (QA probes, injected only and never mapped), `tools/qa/stage2_timing_report.py`, `tools/qa/place_script_diff.py`.

## Next session (Stage 3)
Start from `TIMING_CONTRACT.md` §7–§8 and `INTEGRATION_MAP.md` I-1, I-3, I-4 and the animation half of I-2:
- Replace the `DRIFT` seat and the 2× catch-up with bounded rate correction.
- Add the pose inertializer for combo links and give `FighterAnimations` sole ownership of hitstop speed.
- Restart same-move swings by `ActionSeq`, then fix the probe so it records restarts.
- Start the predicted dash's animation occurrence locally, and bring the changed pose to the first frame (A1). Use probe v2's changed-pose measure, not the track-start proxy.
- Author or validate clips for the 10 silent families, and bake the blade trajectories.
- Leave the two-client measurements to Stage 4. Do not implement Borrowed Force without explicit approval.

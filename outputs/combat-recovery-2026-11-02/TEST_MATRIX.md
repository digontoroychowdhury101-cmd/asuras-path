# Test matrix — initial (Stage 1, 2 November 2026)

Status: **PASS** = ran and met its criterion · **FAIL** = ran and missed · **BLOCKED** = cannot run yet (reason given) · **NOT RUN** = runnable but not yet done. Evidence class follows the master list.

## Baseline runs (this stage)

| ID | What | Evidence class | Status | Result |
|---|---|---|---|---|
| B-01 | `bash tools/verify_all.sh` (14 steps) | Offline behavior / engine emulation | **PASS** | All suites pass, place built to temp, 56 s (`logs/verify_all_baseline.log`). This says nothing about feel, latency or Studio. |
| B-02 | `tools/combat_frame_table.luau` | Offline behavior table | **PASS** (ran) | `frame_table.md`: 17/28 light links are true combos at the slowest continuation, 24/28 at the fastest. |
| B-03 | `tools/combat_anim_coverage.luau` | Static catalog table | **PASS** (ran) | `anim_coverage_baseline.md`: 1/12 families authored, 1 borrowed, 10 with no action clips. |
| B-04 | Studio provenance (SourceDigest on open Edit place) | Seeded Studio diagnostic | **FAIL** | Open place 263 scripts / digest 192984849. Current build 264 / 1345127265. |
| B-05 | Client frame-time sample (running Play session) | Seeded Studio diagnostic, **unverified provenance** | Recorded | p50 42.4 / p95 45.6 / p99 48.9 ms, 30 tracks, 22 fighters, server Heartbeat 0.83 ms, ping 0.5 ms. Focus not measured. |
| B-06 | OmniPvP two-client harness | Real local multiplayer (seeded) | **BLOCKED** | Needs the verified build open in Studio and harness fixes (see `BASELINE.md` §3). Stage 4. |
| B-07 | Ordinary-input captures (Jian chain/heavy/guard/parry/dash, orbit, monk, swordsman, groups, bosses) | Real ordinary input / human | **BLOCKED** | No verified Studio build open, and there is no instrumented pipeline yet. Stage 4/5. |
| B-08 | Reference-game inspection | Primary-source review | **NOT RUN** | See `RESEARCH.md`. |

## Stage 2 runs (2 November 2026)

Evidence classes: **O** = offline fixture (the real server and client modules under Lune, with engine fakes); **D** = seeded Studio diagnostic (single client, digest-verified build, injected lag). Where a case is marked "failed on old code", it was run against HEAD `be08811` or the old code path first and failed there.

| ID | Class | Status | Result |
|---|---|---|---|
| S2-01 `tools/test_stage2_timing.luau` | O | **PASS** | 111/111 checks |
| S2-02 `bash tools/verify_all.sh` after all changes | O | **PASS** | All suites pass. The extraction markers in `test_omni_combat`, `test_combat_contact` and `test_review_regressions` now point at the new contact block. The literal `"Deflect = 100,"` check was replaced by a behavioural window check. |
| T-IN-01 | O | **PASS** (failed on old code) | A press made in Recovery with 0/50/100/140 ms transit executes on the first legal tick. On the old code, transit of 50 ms or more never executes. |
| T-IN-02 / 03 / 04 | O | **PASS** | A press that waits 130 ms expires with one record. A forged-old press is clamped and never executes. A push older than ExecuteBy is Stale. Light + Deflect on the same tick resolves deterministically. |
| T-IN-05 | O | **PASS** | Seeded 600-tick mixed stream with 0–150 ms transit, a respawn flush and buffer overflow: every seq got exactly one terminal record. |
| T-IN-06 (new) | O + D | **PASS** (failed on old code and live) | `push` no longer raises when `simTime` has drifted below the tick grid. |
| T-SP-01 / 02 | O | **PASS** (failed on old code) | A cast pressed in Recovery starts on the first legal tick and charges Qi once. A cast that cannot start in time is refused and costs nothing. |
| T-RT-01 / 02 (= T-TB) | O | **PASS** | The v4 round trip keeps the tick, stamp and ActionSeq, and a v3 record is refused. One swing keeps one ActionSeq. The same move again is a new action. Two dashes with an unseen Idle between them count as two. |
| T-PR-01 / 02 | O | **PASS** | Prediction gates hold. The dash starts at once. The grant is adopted, not reapplied. The snapshot confirms. A rejected dash returns to its start. The timeout rolls back. A Light from Idle is predicted as L1. |
| T-PA-01 / 02 | O | **PASS** | Parry: no HP lost, Qi gained once, posture reflected, exactly one spark. Miss: nothing happens. |
| T-PA-03 | O | **Policy changed** | Two attackers on the same tick are **both** deflected, one spark each (T-PA-06 in the suite). This is the creator-clarified policy (`TIMING_CONTRACT.md` §0), not 1:1. |
| T-PA-04 (spec T-PA-07/08) | O | **PASS** (failed on old code) | Pressed 30 ms before t_c and arriving 3 ticks later: deflected. Pressed 20 ms after t_c: never deflected. Grace is capped at 100 ms. |
| T-PA-05 | O | **PASS** | An NPC defender resolves on the contact tick. A player defender is held for G. Attacking after t_c ends the hold. |
| T-PA-07 (spec T-PA-05/06) | O | **PASS** | Head injury and spam decay apply. A success resets the chain and the next press is legal at once. |
| T-PA-08 (spec T-PA-10) | O | **PASS** (failed on old code: +105 ms refused) | The thrust uses the shared window with half-tick tolerance and head injury, capped at 100 ms. No retroactive parry. |
| T-OR-01 | O | **PASS** (failed on old code: the higher id always won) | A mutual strike is a trade, and the result does not depend on id order. |
| T-HS (light hitstun) | O | **PASS** (failed on old code) | Deflect and guard are legal after the 100 ms defend point; attack and dash are not. Heavy hitstun is unchanged. No window opens before the hit. |
| T-EX-01 | O | **PASS** (ran) | `frame_table_stage2.md`: every light link now leaves at least 25 ms to answer with a deflect (before: 20/28 left 0). The attack-answer classes are unchanged. |
| S2-D1 after_lag0_b / after_lag100 | D | **PASS** for A1 (attack, deflect) and A5 (terminals) | 20/20 Executed. Local pose for attack and deflect in 1.3–2.2 ms. Receipt→start 33.3 ms. |
| S2-D2 dash start (A7 timing) | D | **FAIL** against "≤ 1 frame" (borderline) | 45–51 ms, about one frame at the measured 44 ms. End-distance error not measured live. |
| S2-D3 after_lag100_combo | D | **PASS** for terminals (12/12) | Follow-up swings are not predicted, by scope. The local-pose probe misses re-seeked tracks (Stage 3). Real 160 ms click spacing was not achievable through the MCP. |
| A9 frame time | D | **FAIL** | p95 47.6–51.6 ms with focus confirmed. Not a Stage 2 change; tracked for Stage 4. |
| A10 / T-MX-08 remote windups | — | **NOT RUN** | Needs an observer client (Stage 4). |
| T-MP / T-MX-07 two-client | — | **BLOCKED** until Stage 4 | Multiplayer is not verified. |

## Stage 3 Mac runs (2 November 2026)

Classes: **O** offline fixture (real modules under Lune with fake engine services); **D** seeded Studio diagnostic, single client, Studio-injected input, never ordinary human input. `B-03`'s tool `tools/combat_anim_coverage.luau` was replaced by `tools/animation/coverage.py`.

| ID | Class | Status | Result |
|---|---|---|---|
| `bash tools/verify_all.sh` | O | **PASS** | 14 steps, no skips. `mac-stage3/verify_all.log` |
| `tools/test_stage3_motion.luau` | O | **PASS** | 214/214: T-FC, T-RB, T-AN, T-HS, T-FW, T-CT |
| `test_stage2_timing`, `test_stage2_closure` | O | **PASS** | 111/111, 56/56 |
| `test_combat_contact`, `test_omni_combat`, `test_boss_presentation`, `test_cast_visuals` | O | **PASS** | 68, 84, 232, 48 |
| `tools/qa/mutation_stage3.py` | O | **PASS** | 11 of 11 restored defects caught |
| Analyzer | Static | **Separate outcome** | New hybrid modules report only missing engine globals and require paths, an environment limit. `WeaponSchema` union errors reached through `LocalPrediction`: file not changed in this batch. Not a pass. |
| Clip read-back | D | **PASS** | 189/189 ids load with keyed poses. Loads only, not quality. |
| Source digest in Studio | D | **PASS** | `scripts 272 bytes 2141351 digest 358582538` |
| mac_s3_run1 | D | A1 **FAIL**, rest recorded | Earlier build. 60 fps, focus 1.0. First motion 50 ms. One click unsent; seq 7 pose and seq 10 receipt missing. |
| mac_s3_run2_chains | D | Partial | Earlier build. Focus 0.893, throttled from 9.41 s. Found the restart gap, since fixed. |
| mac_s3_run3_control | D | Control | Earlier build. Transition off, 15 fps. Clip pops ≥0.25 stud at once. |
| mac_s3_run4_final | D | Recorded | Final source. p50 16.7, p95 66.9 ms; 66 ms frames until ~10.6 s, ~17 ms after. Seq 1–6 chain; seq 5 expired honestly; one click unsent. |
| mac_s3_run5_dao_seeded | D | Recorded | Dao by seeded equip, 15 fps. Dao clips play, one start per traced press; repeats of the same track while still playing raise no start row. |
| mac_s3_run6_final_foreground | D | Recorded | Focus attribute 1.0 yet 15 fps. Seq 3, 6 Unpredicted near link edges, seq 7 pose missing. |
| T-FW real slopes, walls, knockback | Studio | **NOT RUN** | Windows W-07, W-08 |
| Two-client, network simulation, ordinary input | Real | **NOT RUN** | pending — other computer |

**Frame-rate note:** on this Mac the frame rate followed whether Studio was really in front, not the `WindowFocused` state: runs 3 and 6 reported focus 1.0 at 15 fps, and run 4 reported unfocused at 60 fps. Read frame times, not the focus share.

## Stage 3A closure runs (2 November 2026)

| ID | Class | Status | Result |
|---|---|---|---|
| T-RC, T-PB, T-TR, T-FB in `test_stage3_motion` | O | **PASS** after fixes | 279/279. Before fixes: 29 failed (`mac-stage3/closure_before_fix.txt`) |
| `mutation_stage3.py` | O | **PASS** | 21 of 21 caught; one was missed at first, and T-PB-08 was added for it |
| Scale probe, trail and debug in Play | D | Recorded | `mac-stage3/closure_studio_check.md`. Not a visual judgment |
| A1 | — | **FAIL** (unchanged) | Pending controlled measurements |
| Real latency, budget transitions, scaled rigs in play | Studio | **NOT RUN** | W-04, W-06, W-13 |

## Acceptance cases to build (Stages 2–5)

| ID | Case | Class | Target | Stage | Status |
|---|---|---|---|---|---|
| T-IN-01 | Intent with transit 0/50/100/140 ms into a fighter in Recovery with 90 ms left executes on the first legal tick | Offline | Executed, never Expired | 2 | NOT RUN (fails by inspection today: ≥100 ms expires) |
| T-IN-02 | Intent waiting > 100 ms server queue time → `Expired` with reason | Offline | 1 terminal record | 2 | NOT RUN |
| T-IN-03 | Press with `T_p + 250 ms < S` → `Stale` | Offline | Never executes | 2 | NOT RUN |
| T-IN-04 | Light + Deflect in the same tick → Deflect starts, Light `Superseded` or kept | Offline | Deterministic | 2 | NOT RUN |
| T-IN-05 | Each seq gets exactly one terminal ack | Offline + Studio | 100% | 2/4 | NOT RUN |
| T-PR-01..06 | Predicted attack/dash start, ack reconcile, reject rollback, no-ack timeout, distance correction, spam chain mirror | Offline (emulated client) + Studio | A1, A6, A7 | 2 | NOT RUN |
| T-TB-01..05 | Sample-tick age, out-of-order drop, skipped Startup, repeated identical move, stream-in mid-action | Offline | Correct occurrence and phase | 2 | NOT RUN |
| T-AN-01..05 | Combo link continuity, bounded phase correction, no seat ≤ 250 ms, hitstop resume, finished-clip hold | Offline + Studio trace | A6, T-AN-02 | 3 | NOT RUN |
| T-CV-01..03 | Every playable family × key authored or validated borrowed. Borrowed clip contact within ±1 tick of the borrower's frame data | Offline | 0 silent slots | 3 | **FAIL** today (B-03) |
| T-FW-01..04 | Single movement owner. Planted-foot drift. No reversed cycles. Dash root vs clip | Studio trace | ≤ 0.2 stud | 3 | NOT RUN |
| T-CT-01..04 | Clip contact vs first active tick, blade-vs-volume error per tick, multi-pulse identity, fallback flagged | Offline + Studio | A3, A4 | 3 | NOT RUN |
| T-PA-01 | In-window press deflects | Offline | 100% | 2 | NOT RUN |
| T-PA-02 | Press one tick outside does not deflect | Offline | 0% | 2 | NOT RUN |
| T-PA-03 | Second contact on one token (two attackers, same tick) → only one deflected | Offline | 1 | 2 | NOT RUN (fails by inspection: both deflect today) |
| T-PA-04 | Multi-pulse attack: each pulse needs its own press | Offline | 1:1 | 2 | NOT RUN |
| T-PA-05 | Successful parry re-arms next tick | Offline | Legal | 2 | NOT RUN |
| T-PA-06 | Spam: window decays per contract, floor 30 ms | Offline | Matches | 2 | NOT RUN |
| T-PA-07 | Press stamped before `t_c`, arriving within G → deflected as of `t_c` | Offline | Deflected | 2 | NOT RUN (fails today) |
| T-PA-08 | Press stamped after `t_c` → never deflects | Offline | 0% | 2 | NOT RUN |
| T-PA-09 | Facing is evaluated at `t_c` from history | Offline | Matches history | 2 | NOT RUN |
| T-PA-10 | Boss Perilous Thrust uses the same window/tolerance/injury scaling | Offline | Equal | 2 | NOT RUN (fails today) |
| T-OR-01..05 | Boundary press vs closing-window sweep. Boss pulse vs same-tick deflect. Actor-id swap invariance. Simultaneous trade. Phase transition at contact | Offline | Outcome independent of id order | 2 | NOT RUN |
| T-EX-01..04 | Link classification table regenerated after any tuning. Deflect recoil, guard release and recovery-cancel windows tabulated | Offline | Intentional classes recorded | 2 | Baseline table done (B-02) |
| T-HS-01..04 | One hitstop per ContactId per observer. No stale speed. No seat after release. Gait not frozen | Offline (fake tracks) + Studio | A6 | 3 | NOT RUN |
| T-NB-01..05 | Standoff, gait, group turns retained. Telegraph clip contact vs pulse. Duo coordination. Large-body arena clamp | Offline + Studio | Existing suites + new | 3/4 | Existing suites PASS (B-01). Studio NOT RUN |
| T-SP-01..03 | Spell press buffered across the Recovery→Idle boundary. Injury/spam modifiers in diagnostics. Resource integrity | Offline | Executed | 2 | NOT RUN |
| T-MX-01 | Attack→parry: an aggressor in Recovery deflects the answer (one token, one contact) | Offline + two-client + human | Legal every Recovery tick | 2/4/5 | NOT RUN |
| T-MX-02 | Parry→counter for every family L1 while moving | Offline + Studio + two-client | Hit during recoil when startup < 320 ms, A1, A3 | 2/4 | NOT RUN (offline margins in `DESIGN_INTENT.md` §1) |
| T-MX-03 | Dodge→attack: i-frame/distance evade, then a buffered light on the first cancel tick | Offline + Studio + two-client | A7, never Expired | 2/4 | NOT RUN |
| T-MX-04 | Combo direction change 45/90/135° to a second foe | Offline + Studio | Matches the decided redirect budget | 2/3 | **FAIL by inspection** (current budget 0–24°) |
| T-MX-05 | Locked circling 5 s plus mid-orbit attacks | Studio trace + human | Facing ≤ 10°, no reversed cycle, foot drift ≤ 0.2 stud | 3/5 | NOT RUN |
| T-MX-06 | Unlocked circling with stick-direction attacks | Studio + human | Strike yaw = press direction | 3/5 | NOT RUN |
| T-MX-07 | 20 s sustained exchange loop, RTT 0/60/120/200 ms | Two-client (automated) + human repeat | 1:1 contacts, 0 unexplained expiries, matches offline replay ≤ 200 ms RTT | 4/5 | BLOCKED (Stage 4) |
| T-MX-08 | Observer-visible windups for every family's light/heavy/art | Studio trace | A10: ≥ 90% of startup visible, catch-up ≤ 1.5× | 3/4 | NOT RUN |
| T-BF-01.. | Borrowed Force proposal (charges, spends, caps) | Offline | Only if the creator approves the proposal | after 3 | Proposal only |
| T-PF-01..03 | Frame p50/p95/p99 with focus recorded, server step p95, dropped steps | Studio on verified build | A9 | 4 | BLOCKED (provenance) |
| T-MP-01.. | Two genuine Studio clients, measured RTT buckets, pipeline timestamps per stable ID | Real local multiplayer | A2, A3, A8 | 4 | BLOCKED |
| T-HU-01.. | Human ordinary-input feel judgments | Human judgment | — | 5 | Open; cannot be automated |

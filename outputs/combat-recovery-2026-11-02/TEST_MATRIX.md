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

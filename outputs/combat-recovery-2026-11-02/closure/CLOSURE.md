# Stage 2 closure pass (against d6440f8, 2 November 2026)

Evidence classes: **O** offline (`tools/test_stage2_closure.luau`, 56/56; `tools/test_stage2_timing.luau`, 111/111; `tools/verify_all.sh` passes) and **D** seeded single-client Studio diagnostic on `places/stage2_closure.rbxlx` (built from the working tree; 265 scripts, 2 045 232 bytes, digest **728868348**; Edit digest re-checked after Stop, so the injected `MonasteryProbe` and `Stage2Timing` probes were removed). The "before" column comes from `before_d6440f8.md`, which ran the same cases on d6440f8's own `CombatRules`.

## 1. Prediction confirmation correlated to the intent

| Case | Before (d6440f8) | After | Evidence |
|---|---|---|---|
| A hit bumps `ActionSeq` during a predicted dash | Any ActionSeq change confirmed the prediction | Not confirmed; the dash stops and only its own travel is undone (knockback kept) | O P-01 PASS |
| The guard or state changes under a predicted Light | Confirmed | Not confirmed; the refused swing ends with no body move | O P-02 PASS |
| Rejection | Rolled back | Rolled back (travel only) | O P-03 PASS |
| Timeout (no answer) | Rolled back at 0.5 s | Rolled back at 0.5 s | O P-04 PASS |
| Delayed confirmation (0.24 s of unchanged samples) | — | Neither confirmed nor rolled back until the sample naming the intent arrives | O P-05 PASS |
| Out-of-order sample / Executed then interrupted | — | Older samples are dropped. An Executed intent whose action already ended is ended **without** rollback | O P-06 PASS |
| Wire | v4 (70 B), no intent | **v5 (74 B)**: `IntentSeq` u32 at bytes 70–73; a hit-started state names intent 0; v4 is refused | O P-07 PASS |
| Live | — | 10/10 (lag 0), 10/10 (lag 100) and 3/3 combo-chain L1 predictions were Confirmed by their own seq; no false confirmations | D PASS |

## 2. Deferred-contact consistency: which timestamp governs what

| Quantity | Timestamp | Source |
|---|---|---|
| Hit geometry (volume vs hurtbox) and defender facing | Detection tick, at the attacker's rewound time (≤ 150 ms) | `Lag` history, as in Stage 2 |
| Defender state, move, armor tier, weapon, poise, invulnerability | **t_c, frozen** | `ContactSnapshot` taken at detection |
| Attacker weapon, damage scale, infusion stun and burn, guard pierce | **t_c, frozen** | `ContactSnapshot` |
| Deflect timing | Judged at resolution against t_c (press window must cover t_c) | `isDeflectTimed` |
| Dash or roll evasion | Judged at resolution: a press at or before t_c whose press-anchored i-frames cover t_c (`Rules.dashCovers`) | grace only |
| Resources (HP, stamina, posture) and the stun applied | Applied at resolution | `resolveHit` |
| Attacker hit registry | Written only for immediate contacts; a deferred contact never writes the newer action's registry | `resolveHit` |

| Case | Before | After | Evidence |
|---|---|---|---|
| D-01 the defender begins a move after t_c | Counter-hit (current move read) | Plain hit; the move is cancelled into hitstun | O PASS |
| D-02 hyper armor begins after t_c | Armored | Not armored | O PASS |
| D-03 armor active at t_c, move ends before resolution | **CounterHit** | Armor holds | O PASS |
| D-04 / D-05 a weapon swap after t_c (attacker or defender) | Current weapon used | t_c weapon used | O PASS |
| D-06 invulnerability begins after t_c | **Whiff** | Hit | O PASS |
| D-07 the defender is KO'd during grace | — | Not hit again | O PASS |
| D-07 the attacker is KO'd, then a late deflect resolves | **Attacker revived into Blockstun** | Attacker stays KO | O PASS |
| D-08 the attacker starts a newer swing while the earlier contact waits | **The newer swing's registry held the defender** (its hit was eaten) | Registry clean. The newer swing is not cancelled by its own earlier hit and can still hit. A late **deflect** does recoil the attacker out of the newer swing; this is intended (the parry was earned at t_c) | O PASS |

## 3. Grace by defense type

| Defense | Press before t_c, received after | Policy | Evidence |
|---|---|---|---|
| Parry | Deflects (pressed 30 ms early, arriving 3 ticks late) | Press window must cover t_c | O G-01 PASS |
| Dash | Before: **Hit** (i-frames anchored to the grant tick, after t_c). After: evades | I-frames re-anchored to the accepted press while the contact is held (`DashPressedAt`). A press after t_c never evades (G-03). Arrival after G is too late (G-05) | O G-02/03/05 PASS |
| Roll | Pressed 30 ms early: hit, because roll i-frames start 40 ms after the press. Pressed 60 ms early: evades | Same anchoring; the roll's own 40 ms startup is kept, not waived | O G-04 PASS |
| NPC defender | — | G = 0; the hit confirms on the contact tick | O G-06 PASS |
| Boss pulse | Same-tick deflect that drained first: deflected. Otherwise hit | Phase ordering only, **no grace** (narrowed guarantee) | O G-07 PASS |
| AI area wave (`ApplyArea`) | Hit | Resolves at listener time: **no grace and no dash anchoring** (narrowed; its return value feeds SpellEffects, so it is not queued) | O G-07 PASS |

**Added hit-confirm delay** for a player defender who could still defend = ⌈G / tick⌉ ticks, G = min(ping/2 + 1 tick, 100 ms):

| Defender ping | 0 ms | 50 ms | 100 ms | 200 ms | 300 ms | NPC |
|---|---|---|---|---|---|---|
| Delay | 16.7 ms | 50 ms | 66.7 ms | 100 ms | 100 ms (cap) | 0 |

The grace window was not widened.

## 4. Measurement correlation (probe v2)

Every press is now tied to its intent by ID. The client trace records `Sent(seq)` → `Predicted`/`Unpredicted` → `Confirmed`/`Ended`/`RolledBack` → `Occurrence(seq)`. The server records the intent behind each start (`actionIntent`) and the tick it entered, plus the terminal record. Four presentation measures are kept apart: occurrence (the animation layer adopts that intent), **track-start proxy** (first new Action-priority track: this is the Stage 2 "≈ 2 ms" figure, relabelled), changed pose (the right hand moves ≥ 0.25 stud relative to the root) and body movement (the root moves ≥ 0.25 stud; dashes only). All are read on RenderStepped before render, so display latency is excluded. Missing values stay null, with the seq listed.

| Run (D) | Presses | receipt→start p50 / max | Track-start proxy p50 | Changed pose p50 / p95 | Dash body move | Occurrence p50 | Missing |
|---|---|---|---|---|---|---|---|
| `closure_lag0` | 10 | 16.7 / 16.7 ms | 1.0 ms | 85.0 / 208.2 ms (outlier 208.2, deflect) | 43.0–45.8 ms | 126.0 ms | seq 14 receipt→start: the server probe window closed before it |
| `closure_lag100` | 10 | 16.7 / 16.7 ms | 1.4 ms | 86.8 / 128.0 ms | 42.5–42.8 ms | 375.5 ms | seqs 21, 24 changed pose: the deflect pose never moved the hand 0.25 stud within 1.5 s |
| `closure_combo` | 12 | 16.7 / 50.0 ms | 46.5 ms | 2.0 / 47.4 ms | — | 138.5 ms | none (5 track-start outliers, 137–225 ms) |

Frame time p50 ≈ 42 ms (≈ 24 fps) in all runs, with `focused_share` 1.0. One rendered frame is therefore ≈ 42 ms, so a changed pose at ≈ 85 ms is the **second** rendered frame after the press. **A1 (≤ 1 frame to changed pose) is not met.** 3 of 6 light presses reached it (≈ 43 ms); the rest took ≈ 126 ms. Heavy and dash took ≈ 85 ms. A dash moved the body on the first frame (A7's 1-frame start is met).

Findings for Stage 3:
- A predicted dash moves the body on the first frame, but its animation **occurrence** waits for confirmation (126–170 ms at lag 0, 376–390 ms at lag 100).
- A predicted attack's occurrence is logged again when the server sample confirms it (adoption). The report uses the first occurrence.

## 5. Acceptance gaps

**Receipt→start.** The implemented delay is **one tick**: an intent received between ticks starts on the next tick, and that tick's sample names it (O R-01 PASS; D p50 16.7 ms in all three runs). The Stage 2 figure of 33.3 ms was a **probe artifact**. The server probe's OnStep listener runs before fighters step, so it saw each start one tick late. The probe now stamps the entering tick (`entered = previousNow`). The original target, A2 ≤ one-way + 1 tick + queue wait, is met. Combo links show 33.3–50 ms because the buffered press waits for the previous move's chain window: that is queue wait, which A2 allows.

**Rejected-dash correction.** Rollback undoes only the dash drive's own travel (from the drive's recorded stop, or the current position while it is still running). It is horizontal only and swept with `Blockcast` against the world (excluding the own character), stopping 0.05 stud short of anything hit. It does nothing if the character model changed (respawn) or the snapshot is KO.

| Case | Status |
|---|---|
| Wall between the body and the old start | O R-02 PASS (stops short) |
| Rising ground | O R-02 PASS (stops at the contact, height kept) |
| Interruption (a hit during the dash) | O P-01 PASS (knockback kept) |
| Respawn | O R-02 PASS (a new character is not moved) |
| KO | O R-02 PASS |
| The same cases against real Studio walls and slopes | **PENDING** (NOT RUN). The offline sweeps use fakes of `Workspace:Blockcast`. Descending slopes and steps are not handled (the correction is horizontal). |

## 6. Genuine combo chain (D, automated input)

`tools/qa/jian_combo_clicks.ps1` sent real Windows `mouse_event` clicks into the focused Studio game view (the production `InputController` path, not remotes), scheduled for 0/160/320/520 ms. **This is automated input, not human play.** The achieved spacings were 96–186 ms (OS scheduling jitter), all recorded.

| Chain | Server starts (intent → move) | Result |
|---|---|---|
| 1 | 29 L1 → 30 L2 → 31 L3 → 32 L4 | PASS |
| 2 | 33 L1 → 34 L2 → 35 L3 → 36 L4 | PASS |
| 3 | 37 L1 → 38 L2 → 39 L3 → 40 L4 | PASS |

Each L1 was predicted and confirmed. L2–L4 were **Unpredicted** (follow-ups are not predicted, as documented) and started from the server, with an occurrence after one snapshot round trip (p50 138.5 ms at lag 0). Visual continuity across links is Stage 3. Two-client fairness is Stage 4.

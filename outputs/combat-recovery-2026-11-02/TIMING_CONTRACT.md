# Timing contract — Asura's Path combat (Stage 1 specification, 2 November 2026)

This is the specification that Stages 2–3 implement. It is **not implemented yet**. Values marked *initial* are the comparison baseline required by the master prompt: 60 Hz simulation, 150 ms maximum rewind, 1.4× tempo and a 100 ms ordinary deflect window. Any change needs before/after evidence in `TEST_MATRIX.md`.

## 1. Clocks

| Clock | Owner | Definition | Use |
|---|---|---|---|
| **S** (authoritative) | server `CharacterService.simTime` | Tick index `k`, `S = k / 60` on the `GetServerTimeNow` base. Re-synced only on drift > 250 ms (unchanged). | All outcomes, windows, i-frames, contact times. |
| **Ŝ** (client estimate of S) | `Workspace:GetServerTimeNow()` | Engine-synchronised estimate. Its error is **unmeasured**; Stage 4 measures it with an echo (server stamps, client returns the stamp, half the round trip bounds the error). | Press stamps, snapshot age, local predicted starts. |
| **P_local** | client | `Ŝ` at the render frame. | The local fighter's predicted presentation. |
| **P_remote** | client | `Ŝ − D_interp`, with `D_interp = Config.Network.InterpolationDelay` (0.067 s, *initial*). | Other fighters' presentation, which trails S by a known, constant amount instead of a varying one. |
| Monotonic | `os.clock()` | Local durations only (frame times, hitstop length). Never compared across processes. | Diagnostics. |

## 2. Identities

- **IntentSeq**: the client sequence that already exists (`packet.seq`). Every intent ends with exactly **one** terminal record `{seq, result, reason, tick}`. `result` is one of `Executed`, `Rejected(reason)`, `Expired`, `Stale`, `Superseded`. The record replicates through one `AsuraAck` attribute that names the seq the result belongs to. The current attribute is ambiguous (see ledger).
- **ActionSeq**: a per-fighter u8 counter that increments on every action start (`tryAttack`, `tryDash`, `tryDeflect`, deathblow, feint-cancel). It is packed into the unused byte 39 of the fighter record. Each record also carries `StartTick` (u16, the low bits of the start tick). An animation occurrence is keyed by `ActionSeq`, never by `move id + serial`.
- **SampleTick**: the tick on which the record was packed, as u32 (or u16 plus a wrap check). The client discards a record older than the last one applied and computes `age = Ŝ − SampleTick/60`, clamped to `[0, 0.25]`.
- **ContactId** = `(attackerId, ActionSeq, pulse)`. `pulse` is 0 for a single-volume swing. Multi-pulse moves and boss repeats number their pulses 1..n. `HitRegistry` is keyed by `(ContactId, defenderId)`, so each pulse may hit each defender once and a repeat of the same move is a new identity.

## 3. Input lifetimes

| Quantity | Value | Rule |
|---|---|---|
| Accepted press time `T_p` | `clamp(snap(T_client), S_recv − 0.150, S_recv)` | As today (`Tempo.reconcile`). It is used only for **defense eligibility** (§5) and diagnostics, never for queue lifetime. |
| Queue lifetime | 100 ms (*initial*) from **server receipt tick** | `InputBuffer` stores `EnqueuedAt` separately from `PressedAt`. |
| Absolute execute-by | `T_p + 0.250` (rewind cap + queue lifetime) | An entry that would execute later is `Stale`. This stops very late commands from executing long after intent. |
| Drain | All eligible entries per tick in priority order, at most one action **start** per fighter per tick. Lower-priority entries made illegal by that start stay queued until they expire. | They are reported `Superseded` when the higher-priority action consumed their window. |
| Duplicate window | 33 ms (unchanged) | The duplicate refreshes `PressedAt` and `EnqueuedAt`. |
| Spells | They join the same buffer with the same lifetimes. The Idle-only cast start remains, as intentional commitment. | |

## 4. Tick phase order (server)

1. Record history (positions and facing for every fighter: `Lag.record`).
2. **Drain intents** for every fighter (deflect, block, dash and attack starts take effect at tick `k`).
3. `Combat.step` timers and expiry for every fighter, then step listeners (AI decisions, boss telegraphs). Bosses **submit** pulses as contacts and never call `ApplyBossAttack` directly.
4. **Collect contacts**: every active volume sweeps `[k−1, k]`, including windows that close at `k`, and every boss pulse due at `k`. Each contact is checked against the defender's rewound hurtbox.
5. **Resolve simultaneously** against the tick-start snapshot of each defender (state, facing, tokens). Results are applied after all contacts are evaluated. Ordering by entity id may only order event emission, never change outcomes.
6. Pending-contact expiry (§5.3), locomotion, replicate, flush events.

**Simultaneous-hit policy.** Two fighters who strike each other on the same tick both get hit (a trade). The exception is a fighter whose own contact is parried by the other in the same tick: the deflect wins, because a parry token is a defensive state that was already present at tick start. Counter-hit status is judged from the tick-start state (both in `Active` → neither is a counter-hit).

## 5. Defense, contact time and latency

### 5.1 Contact time
`t_c` is the tick at which the swept volume first intersects the defender's rewound hurtbox. Defense, facing and i-frames are all evaluated **at `t_c`**: facing from `Lag` history at `t_c`, state from the tick-start snapshot. Present-time reads are no longer used. Rewind for geometry uses the **attacker's** latency (unchanged, ≤ 150 ms). The defender's facing is sampled at the same rewound time, so the two describe the same moment.

### 5.2 Parry token (1:1)
- A legal Deflect press creates **one token** `{pressedAt = max(T_p, last resolved contact against this defender + 1 tick), window = W}`. The base `W` is 100 ms (*initial*), scaled by head injury (`headDeflectWindow`) and by spam decay (`(1 − 0.45)^chain`, floor 30 ms), as today. A token can never start before a contact that was already resolved, so there are no retroactive parries.
- A contact is deflected when `t_c ∈ [pressedAt − ½ tick, pressedAt + W + ½ tick]` and the defender faces the attacker at `t_c`. **The first deflected contact consumes the token.** Other contacts in the same window (a second attacker or a second pulse) are judged as guard, not deflect. Each contact needs its own press.
- **Successful parry**: the token is consumed, the defender re-arms immediately (the next press is legal at once), the spam chain resets and `Deflecting` recovery ends at `t_c + DeflectRecovery`. **Failed press** (no contact in the window): the spam chain grows, and the next press within 300 ms decays the window (unchanged). Stamina cost is unchanged.
- **Boss Perilous Thrust** uses the same token rule and window, including half-tick tolerance and injury/spam scaling. The literal `0.1` goes.

### 5.3 Bounded defender grace (latency policy)
Only when the defender is a **player** whose token or dash could still legally arrive: a detected contact enters a pending queue for `G` instead of resolving at once:

`G = min(defender one-way estimate + 1 tick, 100 ms)`, with the one-way estimate `= GetNetworkPing()/2`, smoothed. For NPC defenders `G = 0`.

During `G`, a Deflect or Dash intent from that defender with `T_p ≤ t_c` (a Deflect token must cover `t_c`, and a dash's i-frames must cover `t_c` from its accepted press) resolves the pending contact as a deflect or evade **as of `t_c`**. When `G` expires, the contact resolves against the `t_c` snapshot. Anything the defender started after `t_c` is overridden by the resulting stun. Feedback to the attacker is delayed by at most `G`.

**Stated latency limit:** grace compensates the upstream half only. The defender still sees the windup late by `server→client one-way + D_interp + one frame`. Beyond about **200 ms RTT** (G hits its 100 ms cap), presses made in time on the defender's screen can be judged late. This is documented behavior, not a bug. Arbitrary retroactive parries are impossible: a press stamped after `t_c` never deflects, and `T_p` can never precede `S_recv − 150 ms`.

### 5.4 I-frames
Dash and roll i-frames are anchored to the **grant tick** (unchanged) unless the grace rule applies. The predicted local body may start moving up to one-way earlier. This favors the attacker's geometry slightly and is bounded by `G`.

## 6. Prediction and reconciliation (local fighter only)

| Action | Local start | Acknowledged | Rejected / no ack within `RTT×2 + 100 ms` |
|---|---|---|---|
| Light / Heavy / Art | When a mirror of `Schema.canAct` on the last own snapshot plus local predicted state passes, start the clip at once with `predicted = IntentSeq`. | The server's `ActionSeq`/`StartTick` gives the authoritative phase. Phase error is corrected by playback rate in `[0.75, 1.5]` (Orange Duck `adjust_by_velocity` idea: correction bounded relative to current progress), never by a seat unless error > 250 ms. | Inertialized blend (≤ 120 ms) back to the authoritative state. The rejection reason is shown in debug HUD only. |
| Dash / Roll | Start the LinearVelocity drive immediately with the local budget `distance(chain)` mirrored from `CombatRules.tryDash`. | The server's `DashDistance`/direction: correct the remaining distance by a bounded per-frame ratio (≤ 25% of current speed). | Stop the drive. No positional snap: the client owns the body, and the server validates the distance travelled. |
| Deflect / Block | Play the guard pose at once (cosmetic). | Server token. | Drop the pose with a blend. |

Presentation never writes authoritative state. Predictions live only in `FighterAnimations`/`WorldStateController` local fields.

## 7. Animation phase mapping

- Each move's clip has metadata `{antic, contact, activeEnd, recoveryEnd}` in clip seconds. This is the Epic Fight phase concept, implemented independently. For authored clips, `contact` must equal `StartupSeconds` and `activeEnd` must equal `StartupSeconds + ActiveSeconds` within ±1 tick. A test enforces it. `Startup + Active×0.5` is removed.
- Clip time = `phaseStart(state) + age-corrected elapsed`. A skipped phase is detected by `ActionSeq`/`StartTick`, not by observing `Startup`.
- Combo continuation (`L(n)` Recovery → `L(n+1)`) starts the next clip with a pose-offset inertialization from the current pose (§8). A short authored "link" lead-in is optional.

## 8. Playback ownership and hitstop

- `FighterAnimations` is the **only** writer of `AnimationTrack.Speed` and `TimePosition` for fighters it animates. `BossAnimations` is the only writer for bosses.
- Hitstop and cinematics submit a **time-scale request** `{actor, scale, untilClock}` to that owner. The owner computes `speed = phaseCorrection × min(requested scales)`. When the request ends, the presentation clock continues and phase debt is repaid by the bounded rate (§6), not by a seat.
- Base and gait tracks are **not** frozen by hitstop, so the feet do not slide. Only the action layer and the trail are frozen.
- One hitstop per `(ContactId, observer)`. Duplicate events are ignored.

## 9. Numerical acceptance targets (set before any new measurement)

| ID | Target | Measured how |
|---|---|---|
| A1 | Legal local press → first changed pose: ≤ 1 rendered frame at the measured frame time. | Client probe: InputBegan `os.clock` → frame where the action track `IsPlaying`. |
| A2 | Press → server start: ≤ one-way + 1 tick + queue wait, with p50/p95 reported per RTT bucket. | Server log of `IntentSeq` receipt/start ticks plus `Ŝ` stamps. |
| A3 | Local visible contact vs server `t_c`: ≤ 1 tick (16.7 ms) in controlled tests. Remote observer: within `D_interp ± 1 tick`. | Clip-time contact marker vs replicated `StartTick`. |
| A4 | Blade/server volume error at each active tick: ≤ 0.5 stud (tip and hilt). | Offline baked-trajectory comparison (Stage 3) plus a Studio sample. |
| A5 | Zero unexplained intent terminations and zero duplicate outcomes per `ContactId` in deterministic fixtures. | Offline fixtures T-IN, T-PA. |
| A6 | No intra-action `TimePosition` seat when error ≤ 250 ms. Playback rate stays in `[0.75, 1.5]` except hitstop. | Client trace. |
| A7 | Dash: local motion starts ≤ 1 frame after press. Final distance error vs grant ≤ 0.5 stud. | Client trace vs replicated grant. |
| A8 | Parry fixtures: an in-window press is deflected 100%. One tick outside is never deflected. A second contact on one token is never deflected. With simulated one-way 50/100/150 ms, an on-time press is deflected for one-way ≤ G cap. | Offline fixtures plus a two-client run. |
| A10 | Observer-visible windup ≥ 90% of authored startup when snapshot age ≤ `D_interp + 1 tick`. Catch-up never above 1.5×. Readable anticipation at 1.4× tempo (`DESIGN_INTENT.md`). | Client trace on the observer, per family and move. |
| A9 | Frame time on the verified build with a focused window: report p50/p95/p99. Target p95 ≤ 16.7 ms on the dev PC, else report the platform limit. | Studio probe with focus and quality recorded. |

# Combat design intent — fast, aggressive wuxia (Stage 1 specification, 2 November 2026)

Direction (creator, 2 November 2026): **fast, aggressive wuxia combat built around omnidirectional footwork, precise deflections and flowing counterattacks.** This document turns that into checkable rules for Stages 2–5. It complements `TIMING_CONTRACT.md`, which defines *how* time is measured. This file defines *what the timing should feel like*.

**Baseline**: 1.4× tempo, 60 Hz, 100 ms deflect, as already tuned. Every number below marked *current* is read from source (`frame_table.md`, `CombatSettings`, `MoveSchema`, `StrikeGeometry`). Numbers marked *target* are hypotheses until Stage 4 measurements and Stage 5 playtests justify them. No tuning was changed in Stage 1.

## 1. Combat rhythm

The exchange unit is a **beat**: one committed action and the answer it invites. At 1.4× a light beat is about 280–330 ms (Jian L1 total 283 ms, *current*), and a heavy beat about 680 ms.

| Phrase | Intended shape | Current support | Gap |
|---|---|---|---|
| **Pressure string** | 2–4 lights. Each link either keeps initiative or hands it over at an authored point. | 17/28 links are true combos regardless of timing. The defender can do nothing after the first hit. | Too few answer points. *Target*: at least one deliberate "seam" per string (a link the defender can deflect if they read it). It is chosen per weapon, not by loosening windows globally. Decided with before/after link tables in Stage 2. |
| **Deflect → counter** | A precise deflect hands the initiative back with a short, guaranteed punish. | The attacker recoils 320 ms. The defender may attack from `Deflecting` at once. Counter margin = 320 − startup: Jian light +220 ms, Guandao L1 +170, Odachi L1 +70, Jian heavy +3 (effectively not guaranteed). | Works offline. Keep it, and make it visible (riposte clip and VFX). The 1:1 token fix (contract §5.2) is required so chained deflects are earned. |
| **Evade → attack** | A dodge is an attack setup, not just an escape. | Dash cancels into Light/Heavy/Running at 0.6 × duration (dash 132 ms, roll 216 ms). Running attack is allowed from Dashing. | Works offline. It needs the predicted local dash (ledger #2), or the cancel arrives a round trip late. |
| **Reset / spacing** | Brief neutral: circling, feint, spacing at weapon reach. | Feint 150 ms on heavy/art. Lock-on orbit exists. | Footwork presentation (ledger #6). |

**Readable anticipation at high tempo** (must survive any tuning):
- Light startups stay ≥ `Tempo.LightMinFrames` (85 ms) and heavy/art ≥ 210 ms (`Tempo.enforceTelegraph`, *current*).
- Lights are read by **pattern and spacing**, not reaction. Heavies, arts and boss perilous attacks are read by **reaction** and must keep a visible windup pose of at least 210 ms on remote observers.
- Remote windups may **never** be shortened by catch-up while snapshot age ≤ `D_interp + 1 tick` (contract §1). *Target*: ≥ 90% of authored startup visibly played on observers (A10 below).

## 2. Movement freedom (omnidirectional footwork)

| Rule | Current | Intent |
|---|---|---|
| Free movement | Idle walk 22.4 studs/s, sprint 33.6. Any analog direction. | Keep. |
| Attack direction from neutral | The aim is the sent direction. Light startup ≤ 150 ms means the windup budget is 0, so it never tracks after the press. | Keep. The press direction commits, and late sidesteps make it whiff (honest). |
| Movement during an action | Startup 0.35×, Active 0.25×, Recovery 0.5×, Deflecting 0.6×, Blocking 0.5×. Steps switch in one tick. | Keep the ratios. Blend speed changes over 1–2 ticks on the presentation side, and the feet must match the root (I-3). |
| **Combo direction change** | A follow-up turns from the last committed yaw at 240°/s × time spent in Recovery. Pressed at the first Recovery frame that is **0°**; at the end of the 100 ms combo window **24°**. | **Gap with the new direction.** A flowing wuxia string should be able to switch to a flanking foe. *Target proposal*: each light link gets a **redirect budget at press** (for example 90° for Jian/Dao/TwinDaggers, 45° for polearms, 30° Odachi) applied at the follow-up's start. It is still bounded by the 150 ms commit lead, so nothing tracks once the swing is committed. Decide in Stage 2 with T-MX-04. |
| Dodge direction | 8-way plus analog. Backdash and roll pick from direction. Spam decay on distance and i-frames. | Keep. Predicted locally (contract §6). |
| Locked circling | The camera lock orbits. Movement is relative to the target. | The body faces the target. Strafe and backpedal use directional clips or planted stance stepping (I-3), never a reversed forward cycle. |
| Unlocked | Free camera. Attacks use the stick or camera direction. | The same commitment rules as locked. Locking only changes facing help, never hit validation. |

## 3. Commitment windows (what you cannot do, and for how long)

| State | Locked out of | Way out | Reason |
|---|---|---|---|
| Startup | Everything except feint (heavy/art, first 150 ms, 4 stamina) | Feint | Readable intent. Heavies stay baitable. |
| Active | Everything | — | The contact moment is honest. |
| Recovery | Attacks (except combo continuation in its window). Dodge/Art after the cancel frame. | Deflect and Block **always** allowed | **Attack→parry**: an aggressor can always try to defend the answer, but a mistimed press costs stamina. |
| Dashing | Everything until 0.6 × duration | Light, Heavy, Running, Deflect, Block after that | **Evade→attack** flow. |
| Hitstun | Everything (280 / 480 ms) | — | Being hit is the main cost. Its length decides which links are true (§1). |
| Deflecting (missed) | Window plus 200 ms recovery. Spam decays the next window. | Block, Deflect, Light, Heavy | Mashing is weaker than reading. |

## 4. Defensive opportunities (each needs a test)

1. **Read the first hit** of any string with a deflect, block or evade. A light startup of 83–250 ms means this is mostly anticipation.
2. **Seams** inside strings (§1 target), deflectable by a read.
3. **Recovery defense**: an aggressor answered mid-string can still deflect or block from Recovery.
4. **Evade i-frames**: dash 0–100 ms, roll 40–240 ms, decaying with spam.
5. **Feint read**: a heavy that becomes nothing. Deflecting early is penalised only by recovery and stamina.
6. **Perilous attacks** (bosses): deflect or evade only, with the same token rules as players (contract §5.2).

## 5. Proposed distinctive mechanic: **Borrowed Force (借力, *jièlì*)**. PROPOSAL ONLY, not implemented in Stage 1

**Idea.** A precise deflect does not only reflect posture. It lets the defender *borrow* the attacker's force. Each successful deflect stores one **Borrowed Force** charge (max 3, shown as pips beside the Qi bar). Charges fade 1.5 s after the last deflect and are lost when hit. While charged, the next action **spends one charge**:

| Spend | Effect | Player decision |
|---|---|---|
| **Riposte** (Light or Heavy pressed in the post-deflect window) | Ignores the combo redirect budget, so it can turn fully toward any foe in reach. It adds the stored reflected posture (`DeflectReflect × 0.5` per charge) to the target. Plays a riposte variant of L1/Heavy. | Cash in now for a safe punish, or keep deflecting to bank. |
| **Flowing Step** (Dash in the window) | A short sidestep that ends on the attacker's flank, keeps full i-frames and ignores dash spam decay once. | Reposition in groups, or take damage now. |
| **Release** (Weapon Art with ≥ 2 charges) | Qi cost reduced by 30% per charge spent (all charges). The Art gains hyper-armor on its first active frame. | Spend the bank on a big finisher, or keep Qi for spells. |

**Why it fits.** It builds only on existing systems: deflect reflect posture (`DeflectReflectScale`), Qi (`GainOnDeflect`, Art `QiCost`), posture break into Deathblow, and the existing dash and attack states. It rewards *chains* of precise deflects with *flowing counters* in any direction, which is the creator's stated identity. A 3-deflect chain against a boss becomes a strong, earned turn reversal.

**Tradeoffs and risks.**
- It stacks with the existing 320 ms recoil punish. Riposte posture must be capped, for example at a total ≤ 35% of posture max per spend, or bosses melt. Tune with posture-break-time measurements.
- It encourages turtling for charges. Mitigations: the 1.5 s fade and loss on hit. Active aggression still earns Qi normally.
- Readability: the opponent must see the charge. The pips replicate in the fighter record (one spare flag bit plus a 2-bit count), and a weapon glow scales with charges.
- AI: ordinary foes do **not** earn charges at first, which keeps PvE fair. Bosses may get a scripted variant later.
- PvP: the 1:1 token (contract §5.2) is a prerequisite. Without it, one press could bank several charges.

**Integration cost (estimate).**
- Server: `Fighter.FlowCharges/FlowUntil` and the three spend branches in `tryAttack`/`tryDash`, plus the deflect branch in `resolveHit`/`applyBossAttack`. About 120 lines, plus offline tests (about 15 cases). Packet: 3 bits in the flags byte or the spare byte (byte 39 is reserved for `ActionSeq`, so use the flags high bits).
- Client: HUD pips (CombatHud), glow (SkinWeaponFx/WeaponTrails), riposte clip variant per family (Stage 3 coverage work; L1 with inertialized lead-in can stand in). About 80 lines plus clips.
- Risk to existing systems: low. No schema-v4 profile change, and charges are per-life combat state.
- **Gate**: build only after the Stage 2 parry token and Stage 3 coverage exist, and only with the creator's approval of this proposal.

## 6. Moving-exchange acceptance cases (added to `TEST_MATRIX.md` as T-MX)

| ID | Case | Pass criteria (*target*) | Classes |
|---|---|---|---|
| T-MX-01 Attack→parry | A attacks Jian L1→L2. B deflects L2. A, now in Recovery, presses Deflect against B's counter. | A's Deflect is legal on every Recovery tick. If timed, B's counter is deflected (one token, one contact). A late press gives guard plus stamina cost, never a free hit. Intents: 0 expired, 0 duplicate outcomes. | Offline fixture; two-client; human |
| T-MX-02 Parry→counter | B deflects A's light, then counters with each family's L1, both fighters moving at walk speed before contact. | The counter contacts while A is in recoil for every family whose startup is < 320 ms. Outcome Hit (not Blocked). B's local counter visual starts ≤ 1 frame after the press (A1). Remote contact error ≤ 1 tick (A3). | Offline; Studio; two-client |
| T-MX-03 Dodge→attack | B rolls or dashes sideways out of A's heavy, then buffers a light during the dash. | 0 hits from the heavy when the i-frames or distance cover contact. The light starts on the first legal cancel tick (dash 132 ms / roll 216 ms after grant). Local motion starts ≤ 1 frame after the dodge press (A7). The dash end error is ≤ 0.5 stud. The buffered light is never Expired. | Offline; Studio; two-client |
| T-MX-04 Combo direction change | A strings L1 at foe X, then L2 at foe Y placed 45/90/135° away. | Matches the decided redirect budget (§2) exactly: within budget → hits Y, beyond it → commits at the budget and whiffs honestly. No yaw change after commit lead. The body, clip and server volume agree (A4). **Today**: the budget is 0–24°, so this case FAILS against the new direction until Stage 2 decides. | Offline; Studio |
| T-MX-05 Locked circling | A locked on B circles at walk speed in both directions for 5 s and attacks mid-orbit. | The body faces B within 10°. The attack aim follows lock. No reversed forward cycle. Planted-foot drift ≤ 0.2 stud during contact phases (I-3). Strike yaw = sent aim. | Studio trace; human |
| T-MX-06 Unlocked circling | The same orbit with free camera and attacks along the stick. | The attack direction equals the press direction. The same commit and whiff rules as locked. No auto-turn toward B unless the press points at B. | Studio; human |
| T-MX-07 Sustained exchange | A 20 s scripted loop between two clients: attack → parry → counter → dodge → attack, with moving footwork, at 1.4×, in RTT buckets 0/60/120/200 ms. | Every contact 1:1 (unique ContactId, one outcome). 0 unexplained intent terminations. Heavy and perilous windups visibly ≥ 210 ms on the observer. Frame p95 recorded. Outcomes identical to the offline replay of the same timeline for RTT ≤ 200 ms (beyond that, contract §5.3 latency limit applies and is reported). | Two-client (bot = automated, not human); human repeat |
| T-MX-08 Readable anticipation | Observer view of remote windups for every family light, heavy and art, at snapshot age ≤ D_interp + 1 tick. | ≥ 90% of authored startup plays before contact (A10). No catch-up speed > 1.5×. | Studio trace |

**A10** (added to the contract targets): observer-visible windup ≥ 90% of authored startup when snapshot age ≤ `D_interp + 1 tick`.

## 7. Tuning policy
1.4× stays until there is evidence. A tempo, hitstun, window or redirect change needs: (1) regenerated `frame_table.md` before/after, (2) the affected T-MX/T-PA results, (3) Stage 4 frame-time and latency measurements showing the change is not hiding a timing defect, and (4) a Stage 5 human playtest note. Loosening defense windows to cover latency is explicitly not allowed (master prompt).

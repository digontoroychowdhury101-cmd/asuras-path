# Post-F26 Step 2 — shared omnidirectional combat (25 Oct 2026, Computer B)

Start: `0c8c3d4`, place digest 1438804042. One combat path exists already: players, monks/swordsmen, humanoid bosses (Shen, the Twin Sentinels, Wu) and Colosseum duels all strike through `CharacterService.resolveContacts` with the 60 Hz/150 ms rewind. Boss perilous attacks (`BossAttackService`) are a separate, telegraphed layer on top of it.

## 1. What already supported 360° combat (before this batch)

| Area | Existing support | Source |
|---|---|---|
| Camera-relative movement | Humanoid walk follows the camera; unlocked, `AutoRotate` faces the walk direction in any of 360°. Sprint, slide, double jump and glide exist. | `MovementController`, Roblox ControlModule |
| Orbiting a target | Lock-on (`LOCK_RANGE` 60, break 80) turns `AutoRotate` off and faces the target, so walking left/right circles it. | `CameraController.Update` |
| Target switching | Mouse flick (accumulated 45 px), right-stick flick (0.85), and touch look-swipe all call `SwitchTarget` by screen side, with a 0.25 s cooldown. | `CameraController.Look/SwitchTarget` |
| Directional dodges | Roll/Dash carry a world direction from the camera-relative move input; with no input they go straight back. The server grants distance, i-frames and spam decay. | `InputController.EvadeDirection`, `CombatRules.tryDash` |
| Authoritative hits | The server sweeps a weapon capsule along the move's `Arc`/`Reach`/`Lunge` against rewound hurtboxes. Damage, deflect (100 ms) and three-layer health are server-side. | `CharacterService.weaponSegment/resolveContacts`, `LagCompensation` |
| Whiffs | A swing that closes with no contact emits `Whiff`, names the nearest foe and the gap, and draws a 90° reach arc. | `annotateWhiffs`, `GameFeelController` |
| Guard direction | Block and deflect need the defender to face the attacker (`FACING_DOT` 0.15), so hits from the flank or back go through. | `resolveContacts` |
| Boss commit | Perilous attacks freeze their aim at telegraph start; thrusts and charges are checked against that fixed line. | `BossAttackService.start/strike` |

## 2. What was missing

1. **Tracking never committed for players.** While locked on, the client snapped the root to the target every frame through Startup, Active and Recovery. The server swept the blade from the *live* root, so a circling target could never make a locked attacker whiff. A modified client could also spin during Active to sweep 360°.
2. **Enemy windup tracking was instant.** `CharacterService.Face` snapped enemies to the target at any rate until the first active frame. Moving enemies also turned freely through `Humanoid.AutoRotate` during Startup and Active (they walk at 0.35×/0.25×). A late sidestep could not beat them.
3. **Attacks ignored the input direction.** An unlocked attack went wherever the body last faced, not where the stick or camera pointed.
4. **No aerial rules.** The server had no notion of airborne: every move, including heavies and weapon arts, could be thrown from a double jump, as often as wanted, with no landing cost.
5. **The visible arc was not the validated arc.**
   - The weapon ribbon (`WeaponTrails`) follows the animated blade, which the server never consults.
   - The whiff arc was a fixed 90° drawn from the attacker's current look.
   - Neither matched a Jian thrust (10–12°) or a Dao sweep (90–180°).
6. **Free flight.** There is no Aerial Duel ruleset in code. It stays out of scope here; grounded rules must not prevent adding one.

## 3. Rule set delivered by this batch

All rules live in one shared module, `src/simulation/StrikeGeometry.luau`, with its numbers in `CombatSettings.Tracking`. Players, monks, swordsmen, humanoid bosses (the Twin Sentinels) and Colosseum duels all use it through `CharacterService`. Free flight is untouched: an `AsuraRuleset = "AerialDuel"` model attribute lifts the air limits for a future optional ruleset, and nothing sets it today.

| Rule | Value | Where |
|---|---|---|
| Neutral turning | free (Idle, resting) | `turnStep` |
| Windup tracking | 240°/s, stops 9 frames (0.15 s) before the first active frame | `StartupTurnRate`, `CommitLeadSeconds` |
| Committed swing | Active frames never turn. The server sweeps the yaw committed at the first active frame, within the windup budget of the press aim. | `commit`, `CharacterService.commitStrike/strikeFrame` |
| Recovery and guard turning | 240°/s; guard no longer snaps (Blocking, Deflecting, Blockstun) | `turnStep` |
| Press aim (players) | Locked target, else move input, else camera (mouse) or body (stick/touch). Sent with the intent. A combo follow-up turns from the last commit at 240°/s; out of a guard the swing leaves along the body. | `InputController.AttackDirection`, `CharacterService.aimStrike` |
| AI aim | Target position plus 0.1 s of its ground velocity | `AimLeadSeconds`, `AIService.leadPoint` |
| AI walk-turn | `Humanoid.AutoRotate` only in neutral | `CharacterService.applyLocomotion` |
| Air | 1 light and 1 dodge per airtime; heavy, weapon art and running attack wait for the ground (buffered); anchored flight never counts | `airAllows/airSpend`, `airborne()` |
| Landing after an air strike | 10 frames (0.167 s) of move-less Recovery: deflect/guard open, no combo or dodge; an air dodge into the ground still pays it | `CombatRules.landingRecovery` |
| Visible arc | The server publishes each committed strike (`AsuraStrike`: arc, reach, lunge, yaw). `WeaponTrails` draws that exact path: a thin line for thrusts (arc ≤ 40°), a fan for sweeps. It fades in 0.15 s, so it never reads as the next swing. | `StrikeGeometry.encode/sweep`, `WeaponTrails` |
| Client dash | Horizontal-plane `LinearVelocity` for the granted distance (was a per-frame velocity write) | `WorldStateController` |

**Unchanged:**
- Move frame data (startup, active, recovery) for all 12 weapons; the 1.4× tempo; the 100 ms deflect.
- Three-layer health; the 60 Hz pose history and 150 ms rewind; profile schema v4.
- The weapon capsule geometry: the moved `segment` matches the old `weaponSegment` number for number on all 48 moves.

**Why players can read it:**
1. A thrust is a thin line and a sweep is a fan, in grayscale too: step off a line, get behind a fan.
2. Lights go exactly where they were pressed. Heavies track only in the first part of their windup, by at most 240°/s × (startup − 0.15 s): 32–40° for Unarmed/Jian/Dao, 84° for the slow Odachi/Bone Cleaver.
3. A steady circle gets read by AI aim lead; a reversal or a late sidestep makes the committed swing whiff.
4. After a whiff, a punish from behind lands; from the flank (90°) the recovering guard turns in time to block.

## 4. Evidence

Build: start `0c8c3d4`; final saved place `places/AsurasPath.rbxlx` digest **1219538751** (255 scripts). It is byte-identical in `outputs/` (sha1 `f91d8f89…`), and Studio Edit read-back matches. Studio was synced by `tools/qa/studio_sync.py` (scripts only, never saved) and checked between rounds.

**Evidence labels used below:**
- **local regression:** offline tests.
- **real Studio input:** keyboard/mouse through the Studio injector.
- **seeded:** placement, weapon, heal and KO protection set by the QA probe; *server-timed* intents pushed through the real CharacterService path at exact offsets.
- **live AI:** the game's own AIService.

There is no human continuous-input play, no device hardware and no two-client run in this batch.

### Local regression
- `bash tools/verify_all.sh`: SUCCESS, 14 steps.
- `python3 tools/lune_compat.py --all`: 21 suites, 2,276 checks (`OMNI_VERIFY_LOG.txt`).
- New `tools/test_omni_combat.luau`, 84 checks:
  - invariants;
  - segment parity on 48 moves;
  - yaw and turn math, state budgets;
  - a 60 Hz circling simulation (Unarmed/Jian lights read a steady circle but whiff on a reversal; a Jian heavy whiffs on a steady circle; a Dao heavy catches it);
  - punish geometry (flank guarded, behind lands);
  - air allowances and landing recovery;
  - record round-trip;
  - wiring and device mappings;
  - the **real `resolveContacts`/`strikeFrame`** with real LagCompensation: a root spun 180° after the commit cannot cut the body behind. This check fails on the old live-root sweep (verified).
- Contract updates in 5 existing harnesses: contact, cast visuals, review, audiovisual, movement.

### Studio (Computer B, macOS, 1 client, Studio Play)

| Beat | Unarmed vs monk | Jian vs Cursed Swordsman (Dao) | Dao vs skilled opponent* |
|---|---|---|---|
| Approach | `u01` real input; monk engages | real W + lock (X) | — |
| Circling (locked) | `u02` real A/D; monk lights land 0.6–6.4° off (lead aim) | `j02` real A; Dao sweeps drawn as fans round the circling player | — |
| Attack | `u03` real M1 → `Hit` 4.0; committed record 29.5° off still within fist width | seeded: aimed light → `Armored`/`CounterHit` | seeded: aimed Dao light → `Hit` 5.85 |
| True miss | monk heavy → seeded flank step after commit → `Whiff` on 9 heavies across runs, no Evade (`u05`) | seeded aim 35° beside the body → `Whiff`, record 35.0° off (vs Sparring Phantom); aimed at the body → hit | Dao light 35° beside → still contacts (`Block`): wide sweep vs thin thrust |
| Dodge | server-timed dash 0.05 s pre-impact → 3/3 `Evade`, 0 hits (`u06`) | 2/2 `Evade` | 2/2 `Evade` |
| Deflect | 5/5 then 7/7 `DeflectSpark` (`u07` "PARRY!") | 9/9 | 8/8 (a multi-hit art's later hit landed) |
| Punish | front: `Block` (AI guards); behind 150°: `Hit` 6.0 ×2; flank 90°: `Block` | — | — |
| Disengage | `d08` real S + 2×Q: 14.0 + 11.48 studs, clear at 85 studs, 0 hits | — | — |
| Air | — | `j09` real double jump, 1 air light (seeded timing): Startup → Active → Recovery; 2nd light, heavy, 2nd dash refused; touchdown → move-less Recovery 0.167 s | — |

\*Skilled opponent: no dedicated skilled duelist exists in content. A Cursed Swordsman (deflect 0.4, reaction 0.22 s, the highest regular-mob profile) was force-armed with a Jian (seeded).

- **Dash fix (real input, plaza):**
  - before: 6.05 studs for a 14-stud grant;
  - after the constraint: 63.6 st/s held, overshoot to 19.4 at about 24 fps;
  - after the distance cap: 14.7 studs.
- **Twin Sentinels (seeded entry like F10, live boss AI, `t01`):**
  - Zhao's Guandao commits 120°/160° sweeps at 10.5–12 studs; 2 evades.
  - A thrust committed 70° off after the dash and **whiffed**; the Iron Bull whiffed repeatedly on committed swings.
  - Real X locked the Bull.
  - The injector's stick flick registered as Keyboard, so lock switching was **not** exercised by real input (as in F10).
- **Not run here:**
  - **two-client grounded PvP.** The harness `tools/qa/OmniPvP.server.luau` + `.client.luau` is ready: hit vs 35°-off whiff, spin exploit, cued dodge/deflect, air limits. On this MacBook the 2-client launch joined only 1 client and the owner asked to run it on the other computer.
  - devices: keyboard/mouse only; gamepad and touch are source/emulation (`InputMap` bindings checked in tests).

Captures are in `omni-views/`, all from the ordinary game camera. Arcs in captures are held for 3 s by a QA client copy of the drawn arc (same geometry). In play they fade in 0.15 s, so the stacked arcs in `t01` exaggerate clutter.

## 5. Findings and fairness questions for the human playtest

1. **Fixed here:** guard snap-turn defeated flank punishes; air-dodging into the ground skipped the landing cost; the client dash covered ~43% of its grant; a client could spin a committed swing (live-root sweep).
2. **Open (human):** monk lights chain hitstun on a passive body (13 hits in 4 s). Is that fair at human reaction speed?
3. **Open (human):** two Twin Sentinels with 120–160° arcs at ~11 studs overwhelm a body reacting to one attacker. Is that fair?
4. **Open (human):** 240°/s tracking, the 0.15 s commit lead and the 0.1 s AI lead are first values. Judge with continuous input whether circling is too strong against thrusts or too weak against sweeps.
5. **Open (human):** target switching by mouse flick, stick flick and touch swipe, which can't be driven here.
6. **Open (dev/human):** server-side dash displacement still trails the grant by about 0.1 s (replication). Dodges are carried by i-frames; displacement-based whiffs need an earlier move.

**Status: Implemented — acceptance pending.** The batch is not accepted until a human continuous-input playtest (plus the two-client run on the other computer) reviews items 2–6.

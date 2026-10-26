# Post-F26 Steps 4–5: Twin Sentinels greybox, Desecrated Monastery approach (26 Oct 2026, Computer B, Mac only)

**Build identity**
- **Start:** `17302c1`, place digest 1661908618 (255 scripts).
- **End:** place digest **557606020** (256 scripts, 1,862,424 bytes).
- `places/` and `outputs/` hold the same file, and the Studio Edit read-back gives the same digest.

**Scope limits**
- The 100 ms deflect window is unchanged.
- No difficulty retune: no damage, HP, windup, interval or frame data changed.
- No two-client run, no human play, and no earned-victory claim.

**Evidence labels**
- **SD (seeded Studio diagnostic):** placement, KO protection or heals, foes cleared off a walked leg, server-timed player intents, scripted `Humanoid:MoveTo` locomotion.
- **RI (real Studio input):** keys and clicks through the Studio injector.
- **LR (local regression).**
- Boss AI, strikes, perilous attacks, the Oath, the lifecycle and rewards are the live game in every run.

## Step 4: Twin Sentinels audit against the roadmap

| Item | Finding (before) | Result |
|---|---|---|
| Distinct roles | Zhao: lightning thrust ×3 and thunder dash, every 3.2 s. Bull: shield charge and 65-stud hammer ring, guard 0.95, every 4 s, poise 0.9. **Both swing the same Guandao melee moveset.** | Perilous roles distinct. Melee sameness is open as decision D1 in the Step 6 brief. |
| Positioning | SD: after their lunges, Zhao stood 2.4–3.3 studs and the Bull 3.7–3.9 from the player, **3.1 apart** (the F10 rule is 7.25). Bodies overlapped on the player. | **Fixed**: 6.3–7.8 from the player, 61–88° apart (three 20–25 s runs). |
| Attack overlap | SD, 25 s passive: 71 impacts and 20 cross-Twin pairs within 350 ms. The opening was **Zhao's thrust and the Bull's charge in the same frame (0 ms)** with two different named counters. | **Fixed**: one perilous at a time. The second lands at least 0.9 s after the partner's last pulse. Melee pairs untouched. |
| Valid response? | Every pair measured has at least one rules-valid answer. Roll i-frames cover up to 0.20 s, dash up to 0.10 s. Guard or deflect covers both Twins within the 163° facing cone; pairs stood 9–50° apart before, 61–88° after. Before: 20 pairs, 0 without an answer. After: 17 + 19 pairs, 1 + 0 without. That one was a 217 ms light + hammer pair, which the probe's simple model under-counts (the ring reaches the player about 0.24 s after impact). | **SD proof after fix**: server-timed rolls cut hits from 44 to 4 per ~20 s (5 evades). Timed deflects gave 3 deflect sparks and 2 blocks. |
| Committed misses and recovery | 14 whiffs per 20–25 s on a passive body, before and after. After the fix a Twin left on the player steps back to its flank point before swinging again (a recovery window). | Human feel: pending. |
| Both Oath orders | — | **SD.** Zhao first: the Bull heals and inherits LightningSpear and ThunderQuickstep. Bull first: Zhao inherits IronCharge and ColossalHammer. First impact after the Oath came at +3.85 s and +3.55 s (minimum 2.35). |
| Camera clearance | RI lock on the Bull: **the Bull covered 40% of the frame on average, 100% at peak**. The lens dropped to y 1.4 (16° pitch-up off a tall target 7 studs away). Capture `views/b01_…`. | **Fixed**: same lock, 19% mean / 42% peak (`a02_…`). A Twin between the lens and the player fades to 0.6 (`a03_…`, SD pinned). |
| Entry, skip, retry | — | RI: the fog-gate Z prompt traverses to the Inside mark and the intro fires. RI: Z during the intro skips it (first impact 3.57 s after the intro, against 3.93 s unskipped). SD death: `BossReset`, both despawned, gate unsealed. Re-entry spawns fresh 1000/1600. |
| First-impact grace | — | Unskipped: first impact 4.03 s after the intro (minimum 3.93). |
| Rewards and cleanup | — | Both orders: `BossDefeated`, gate unsealed, `AsuraBosses=TwinSentinels`, 12 Qi orbs, 0 Twin models after 7.5 s. Note: killing the Bull grants no weapon mastery (its agent Essence is 0); only Zhao's kill does. |
| Banner overlap (old #24) | "▲ PERILOUS — counter" was drawn across both duo bars (`b01`). | **Fixed**: it now sits under the strip and lock hint (`a04`, `a05`). |

### Code changes (Step 4)

| File | Change |
|---|---|
| `BossEncounterRules` | `crowded` (a Twin under 0.7 × engage stop from the player, or under 0.7 × gap from its partner) and `perilousClear` (gap 0.9 s = `BossHandoff.Lead`) |
| `AIService.decide` | A crowded Twin re-runs `closeIn` (flank point) before its next swing |
| `BossMotion` | `partner`, `duoGap`. A Twin's lunge ends on its engage point (weapon reach × 0.6), flanking its partner. Hits still use the marked origin and aim. |
| `BossAttackService.lastImpact` | Final pulse of an attack in progress |
| `BossTactics.step` | A Twin's scheduled perilous, and its gap-closer, wait while the partner's is pending. The cursor is kept, and melee carries on. |
| `CameraController` | Lock pitch treats a target as at least 12 studs away (`LOCK_PITCH_NEAR`). Far and flying targets are unchanged. |
| `CameraClearance` (new) | Client-only fade of an unlocked hostile that is nearer the lens than the player, within 30 studs of them |
| `DuoBars.below`, `CombatCallouts` | Perilous banner placed under the duo strip |

## Step 5: Monastery approach and boss court

All walks follow RouteGuide's own staged route, the line the minimap draws (SD locomotion).

| Check | Result |
|---|---|
| Gate altar → Twins fog gate | Gatehouse → Ridge pass → Outside: 3 legs ok, no fall or stall, lowest −0.4 |
| Cloister altar → fog gate | Cloister gateway → far bridgehead → bridge → processional path → ridge pass → Outside: 6 legs ok |
| Return paths | Fog gate → Gate altar ok. The bridge crossed in both directions ok. |
| Real fog entry | Z prompt at Outside → Inside (300, −860), fight starts (RI) |
| Floor edges | No drop within 3.5 studs of either line, or within 9 of the bridge centre line. The pass's sides are terrain walls 24–52 high, not edges. |
| Sightlines (eye height) | From both bridge ends: clear to the swordsman's post (6/6). Tablets II–IV: clear from three approach points each. Courtyard to ridge pass: clear. The fog gate is hidden behind the ridge until x ≈ 190 (the pass cut), then clear. |
| Bridge contact, both ends | **Fault found (SD + live AI):** after deflect recoil the swordsman left the deck through the west broken-rail bay (z −944…−952). It then stood **under the bridge in Engage at y −4.7**, unreachable. **Fixed**: invisible collidable `RailGap` guards in the 4 broken bays; the fallen-rail decor is kept. After the fix, 4 server-timed deflect-punish rounds from the north and south ends: 3–6 deflects each, strikes made contact each round. The swordsman stayed on the deck (x −7…7, root y 3.4). |
| Rafters ladder | Climbing state reached, standing on the loft (root y 33.1). The cache was claimed with a real Z hold (profile `caches: PagodaRafters`). Dropping off the loft: no HP loss. |
| Tablets II–IV | Real Z holds at Feast, Bell and Emissary. `LoreEntries` all three, Qi 500 → 900 (+125, +125, +150). Codex shows the inscription (`m02`). |
| Boot | Monastery 3,373 parts (+4 guards), 0 walkability issues, console clean |

## Checks run

- `bash tools/verify_all.sh`: **SUCCESS**, 14/14 steps (`VERIFY_LOG.txt`).
- Lune suites: 22 pass, including the new `test_twins_monastery` (33 checks, 13 of them failing on the old code).
- `test_boss_runtime`: 35 checks (+5). The new checks run the real BossTactics/BossAttackService with two Twins and fail on the old code at "the Bull holds while Zhao's is pending".
- Contract counts updated in `test_combat_contact`: 3 `closeIn` calls; CombatCallouts under 150 lines.
- `python3 tools/build.py`: 264 sources, 489 asset IDs.
- QA tools added, all unmapped and never saved into the place:
  - `tools/qa/TwinsProbe.server.luau`
  - `tools/qa/TwinsCamera.client.luau`
  - `tools/qa/MonasteryProbe.server.luau`
  - `tools/qa/MonasteryWalk.client.luau`
  - `tools/qa/qa_inject.py`

## Captures (`views/`, game camera)

| File | Shows |
|---|---|
| `b01` | Before: Bull locked at 7 studs, lens near the floor, Bull fills the frame, banner over the bars |
| `a01`, `a02` | After: spaced Twins, both visible, player centred |
| `a03` | Zhao pinned between lens and player, faded (SD) |
| `a04`, `a05` | Banner under the duo strip |
| `g01` | The camera crushed against the north berm at the gate edge (recorded, not changed) |
| `m01` | Rafters loft: the camera sits above the drum-tower roof (recorded) |
| `m02` | Tablet IV read |

## Remaining gaps (exact)

- **Human (Windows):** Twins feel and fairness; flick, stick and swipe lock switching; whether 0.9 s perilous turn-taking and the step-out windows read well; bridge duel feel; earned victory.
- **Two-client:** not run (Windows only, as before).
- **Bull melee:** guandao frame data on a maul body (brief decision D1).
- **Banner vs toast:** at 1920×790 the banner grazes a simultaneous "Posture broken!" toast. Short viewports (1221×503) were not re-captured.
- **Camera framing:** at the court's north edge (12-stud band behind the gate) the camera is pulled in to ~2 studs by the berm. On the Rafters loft the camera sits over the roof (roof decor is not `WorldGeometry`). Recorded, not changed.
- **Mastery reward:** killing the Bull grants no weapon mastery (agent Essence 0).
- **Art:** no Twins templates, clips or arena props. Step 6 brief: `STEP6_TWINS_ASSET_BRIEF.md`.

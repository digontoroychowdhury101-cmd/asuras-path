# Grandmaster Shen: grip and body-mobility pilot (2026-11-06)

Response to `prompt.md` / `REVIEW.md` (Shen polearm mechanics). This is the **pilot stage**: one diagonal cut (Guandao_L1), Heavy, a linked combo (FlowingJian / Flowing Glaive), a grounded turn, plus phase 1 locomotion, because the grip lifecycle and the run were mandatory corrections. Nothing was published or uploaded; the game still plays the old published IDs until the pilot is approved and the set is re-published.

## 1. Provenance (why it read one-handed)

| Pilot clip | Source revision | Registered/runtime ID (Studio play, 2026-11-06) |
|---|---|---|
| P1_Idle | 980fabc | rbxassetid://95368630147871 |
| P1_TurnLeft | 980fabc | rbxassetid://140732239975623 |
| P1_RunForward | 980fabc | rbxassetid://112184891375884 |
| P1_Guandao_L1 | 980fabc | rbxassetid://90693278321537 |
| P1_Guandao_Heavy | 980fabc | rbxassetid://84483982609721 |
| P1_FlowingJian | 980fabc | rbxassetid://130228806026081 |

Measured in the running Studio playtest (`ShenQA.rbxlx`, client, tracks paused at 4 points per clip):
- Model attributes `AsuraBossAnimation_*` equal `published.json` for every slot; only one boss track was playing (Idle).
- Rig rest geometry in Studio equals the solver's (`Glaive` joint 0.96,-0.42,-0.45; wrists; weapon mesh bounds to 0.01). The visible glaive (`Shen1_Weapon_1..3`) is welded to the `Glaive` part, driven by its own AnimationConstraint.
- Skinned hands: `Sk_LeftHand`/`Sk_RightHand` follow the R15 hands rigidly (constant offset in every clip; `TransformedWorldCFrame`). No render-path, retarget or competing-track fault.
- Both palms were on the haft (0.064 rig units), **but only 0.50 rig units apart** in idle, walk, strafe, turn and hit (shoulder width is 1.44). The guard keyed 1.15; the left arm could not reach that spot from a fist parked beside the hip, so the solver slid the lead hand back to 0.5. From the side the hands overlap at the hip and the blade trails low: a one-handed carry. Cuts collapsed the same way at contact (0.45-0.47).

## 2. What changed (editable sources)

`tools/animation/opening_cast/shen_clips.py`
- **Middle guard**: right fist rear and in front of the hip (0.4, 0.25, -0.35), left hand leading by `LSL` 1.25, hips half-turned (`YAW` pel -30, chest -14, head 38), blade at the opponent's waist, `RHAFT` H(-14,-6). Constants `RSL/LSL/YAW/CARRY` replace the scattered literals.
- **Carry follows the shoulders**: `carried(yaw)` turns the guard with the trunk in turns, walk, backstep, strafe, run (`CARRY` -10/-20) and phase 2 glide, so a turn never pulls the lead hand off.
- **Run**: lean 13 -> 20, contact knee flex 22 -> 28, feet land under the body (centre 0.42 -> 0.15), no artificial flight lift. Leg-reach failure 0.18 -> 0.03.
- **Heavy**: blade crossing moved from 0.416 s to the authoritative contact 0.383 s (BossAnimations phase-locks `contacts[1]` = 0.383 to the server impact, so the old blade passed one frame late); hand path 0.2 further forward. Contact/active window unchanged (0.383, 0.067).
- **Flowing Glaive**: linked cuts (`arc(..., link=True)`) start from the previous cut's ending instead of blending back toward the guard; follow-throughs/wind-ups shortened (72/90/74/96/80/126 -> 50/70/55/75/60/110 degrees) so the butt passes low in front of the hip instead of through the right shoulder. Contacts unchanged: 0.80, 1.45, 2.10, 2.75.

`tools/animation/opening_cast/shen_lib.py` (affects every clip at its next bake)
- **Shoulder girdle** (`PROTRACT` 0.25 rig units, about 8 cm at his scale): before a hand gives up its spot, its shoulder joint glides toward it. Exported as joint translation, so the skinned shoulder and mantle stretch with it in game (BossCloth carries limb translation to the skin bones).
- **Spine reach** (`spine_reach`, up to 25 deg turn / 14 deg bow): where the gap remains, the chest turns and bows into it by a finite-difference step, smoothed over time; the head turns back to keep his eyes on target.
- **Grip slide floor**: the lead hand may slide toward the fist only to 0.95 (carry/guard) or 0.85 (attacks, a real grip slide); past that the weapon comes to it. Was 0.5.
- **Continuity**: per-frame solver corrections are smoothed over time (`settle`); the weapon is cleared off the body again after being brought to the lead hand; within a clip the same stretch of haft keeps to the side of the torso it was on (no flip through him).
- **Validator**: new `hand_spacing` stat; carry/guard/locomotion fails under 0.8 ("hands bunched"). No existing limit was raised.

New tools: `tools/qa/shen_grip_report.py` (hand spacing, hand depth, haft pitch, tip height, contact, clearance per clip), `tools/qa/shen_preview_luau.py` (rebuild an exported clip inside a Studio playtest and register it locally), `tools/blender/shen_import/compare_video.py` (labelled before/after grid video), `cloth_bake.py` shot `pilot1` and `SHEN_BAKE_DIR`/`SHEN_SHOT_SUFFIX` to bake a shot from a saved earlier bake.

## 3. Weapon mechanical model (animation assumptions, not measured data)

Mesh at game scale 1.3 (P1): 8.42 studs overall, butt to socket 5.03, blade 3.39, blade/ornament reach 1.71 off the axis. Taking his body as an adult of about 1.8 m (1 stud about 0.257 m): 2.16 m overall, shaft 1.29 m, blade 0.87 m including socket ornament.
Assumed: waxwood shaft 35 mm, 700 kg/m3 (0.87 kg); steel blade 0.70 m effective x 0.10 m x 3 mm average (1.65 kg); bronze socket/guard 0.30 kg; butt cap 0.25 kg. **Total about 3.1 kg; balance about 1.19 m from the butt (just short of the socket), 0.43 m beyond the lead hand.** Hands: right 0.34 m, left 0.76 m from the butt. Rotational inertia about the rear hand about 3.3 kg m2, about the balance point about 1.1 kg m2, about the mid-grip about 2.3 kg m2.
Consequences used: the lead hand carries most of the static weight and steers; the rear hand supplies the push/pull couple and the braking; a heavy blade-forward weapon needs the trunk and shoulders to travel into the cut (hence the shoulder glide and spine reach) and visible braking after contact.

## 4. Results by evidence type

**Static review (solver output, local bake)** - pilot clips, before -> after:

| Clip | Hand spacing (min, rig units) | At contact | Other |
|---|---|---|---|
| P1 Idle | 0.50 -> 1.25 | - | clear |
| P1 TurnLeft / TurnRight | 0.50 -> 1.14 / 1.25 | - | |
| P1 Walk / Back / Strafe | 0.50 -> 1.14 | - | |
| P1 RunForward | 0.53 -> 1.25 | - | leg reach 0.18 -> 0.03 (passes) |
| P1 Guandao_L1 | 0.45 -> 0.78 | 0.55 -> 0.82 | reach 7.8 -> 7.64 studs (limit 7.375); fist max 34 rig/s |
| P1 Guandao_Heavy | 0.46 -> 0.70 | 0.46 -> 0.70 | blade crossing 0.416 -> 0.383 s; reach 7.79 -> 7.83 |
| P1 FlowingJian | 0.33 -> 0.69 | 0.58/0.76/0.99/1.2 -> 1.08/1.08/1.08/1.2 | wrists 131/118 -> 95/99 (passes); single-frame hand jumps up to 1.8 rig units removed (max 10 rig/s) |

All 64 clips (both phases) were re-exported with the final solver on 2026-11-06 and every one validates clean (`export.py`: 64 OK, 0 FIX). Section 5 lists what changed after the pilot.

**Local regression**: `ASURA_BUILD_OUTPUT=<scratch> bash tools/verify_all.sh` passed 14/14 again after section 5 (built to a temporary place; saved place untouched). The boss-runtime stub gained `BossAppearance.stage`; `test_ordinary_foe_fairness.luau` gained F-06 (light lead). It does not exercise animation content.

**Studio integration**: provenance and grip measurements above were taken in Studio play. The re-baked pilot clips were **not** played in Studio: they are unpublished, the MCP thread cannot fetch files over HTTP, and pasting each clip inline is impractical. `tools/qa/shen_preview_luau.py` is ready for that check. Footage is a Blender render of the real skinned GLB with the game's cloth simulation and travelling root (`cloth_bake.py` + `review.py`), not Studio.

**Multiplayer**: not run (this computer is not used for multi-client tests).

**Device profiling**: not run; no performance claim.

## 5. Second pass: the rest of the mandatory corrections (2026-11-06)

| # | Correction | State | Evidence |
|---|---|---|---|
| 1 | Two-hand grip | Done (pilot + propagated to all 64) | Section 4; full re-export clean |
| 2 | Solver failures, no raised limits | Done | All 64 validate; `WRIST_LIMIT` 115 and every other limit unchanged |
| 3 | Whole-weapon clearance | Done | Validator clearance on every clip; death clips keep the glaive 0.08 rig units off the body at worst |
| 4 | Run rebuild | Done | Section 4 |
| 5 | Deaths, both phases, with `DeathFadeAt` 2.6 | Done | Below |
| 6 | Phase reveal (white/translucent swap) | Done, single-client Studio | Below |
| 7 | Low Blood Wave warning | Done | `ShenPresentation` `WAVE_HEIGHT` {0.55, 0.3}; `test_shen_presentation` 34/34 |
| 8 | Skyfall with the live server root | Done, static proof | Below |
| 9 | Light-attack readability | Done, server-side | Below |

**Solver (`shen_lib.py`, every clip)**
- `wrist_yield`: when a wrist bends more than 80 deg past its rest angle on the haft, the rear hand first slides up the haft (up to 0.9 rig units, keeping 1.0 from the lead hand) until the arm is bent. Only if the arm is already bent, or the slide runs out, does the haft tilt, by at most 30 deg about a stable axis. Corrections are spread over neighbouring frames. Bake order: settle (5 passes) -> swivel -> up to 3 rounds of yield, settle and swivel -> solve.
- Left hand: the grip and the free-hand reach are blended only across a narrow crossover band; the shortfall is counted only by the share that is acting. This fixed Flourish (left wrist 168 deg) and Crimson Embrace ("left hand short 0.48").
- Released weapon (`wfree`): a clip can let go of the glaive. It travels to an authored resting place, is lifted clear of the floor, and the right arm is solved to its own target instead of the haft.
- `rest_on_floor` (opt-in `floor_body`): pelvis, feet and free hands are lifted by the smoothed amount anything sinks below the floor. `uncorrupt` fades phase 2's corruption pose out over a window.
- Fixed by the above: Heavy (P2), Skyfall, Crimson Embrace, Rending Arc, Wheel of Heaven, Flourish, and a one-frame spike in P2 Heavy.

**Deaths (P1, P2)**: snap at 0.24 s, knee at 1.15 s, the glaive leaves the hands at 1.35 s, topple at 1.55 s, ground impact at 1.84 s, a small rebound, then rest by 2.1-2.2 s. The dissolve completes at `DeathFadeAt` 2.6 s, so he lies still for about 0.4 s before fading. Validator: no problems in either phase. Lowest body point +0.01 rig units above the floor from 1.8 s on, glaive resting on the floor (+0.01 to +0.02). In game the phase 2 orbs drop to the floor and roll to rest when the death dissolve starts (`ClothSim.drop` from `BossCloth`; covered by `test_cloth_sim.py`). The Blender renders do not run that event, so the orbs stay up there.

**Phase reveal**: `BossSkin.stage` clones the next phase's skin as soon as the transition begins, hidden and without shadows, so it reaches every client early. At the reveal, `Skin.attach` swaps to it in one step. On the client, `BossCloth` keeps the staged pieces at 0.985 transparency so their meshes and textures load before they are shown.
Measured in Studio, single client, with ShenProbe forcing the transition:
- Before: phase 2 parts arrived over 5 frames after phase 1 was destroyed (he was half-built on screen), followed by stalls of 0.73 s and 0.68 s.
- After: the new skin appears whole in one frame (43 opaque parts, an 18 ms frame), with no gap.
- With a cold asset cache there is still a stall of about 0.6 s, now at the start of the transition while phase 1 is still standing. With a warm cache there is no stall (80-100 ms frames against a 67 ms baseline).
- The 67 ms baseline is Studio throttling an unfocused window to 15 fps, not the game. A normal, AI-driven transition was not recorded.
- Evidence: `studio_evidence/p2_after_staged_reveal.jpg`.

**Light-attack readability**:
- Measured before: Shen's light startup is 12 frames, which the 1.4 tempo scalar cuts to 9 frames, so impact came 0.15 s after the cue.
- The server now holds his lights for at least 0.25 s from warning to impact (`BossAnimationRules.LightLead`, passed through `Telegraph.plan`). Damage moves with the schedule; the contact time inside the clip is unchanged.
- The client stretches the clip at speed 0.6 (the low end of `SyncSpeed`) and holds the remaining 0.017 s or less.
- Covered by test F-06. Not seen live.

**Skyfall**: the server moves the root along a 28-stud sine arc between the start of the move and its impact. The clip leaves the root alone while airborne (`hover`), so he is moved once, not twice. In the `sky2` bake, the root rises 21 rig units (28 studs) while his hip stays at standing height (1.0 to 1.33 against 1.15 at rest), so the clip adds no lift of its own. The review camera follows at 90% of the height, so he leaves the top of the frame at the apex. A live Studio recording needs the new clips published.

**Cloth (now in game; `ClothSim`, `skin_rig.py`)**
- Collisions are solid: each particle and each surface link (edges and quad diagonals) is kept out of every body volume on every pass. The blade is a collider as well as the haft.
- Every garment now avoids both arms. The arm volumes keep each garment's sculpted clearance instead of lifting it off. The torn phase 2 sleeves (rags) also avoid the legs and hips.
- `tools/test_cloth_sim.py` passes: rest drift 0.93 (P1) and 1.01 (P2), limit 1.2. The earlier patch that failed this test is replaced.
- `tools/qa/shen_cloth_report.py` now samples only the cloth surface. Bend links, which span a fold, are no longer counted. Measured on re-baked shots, as share of frames, before -> after this pass:
  - P2 rags through arms: 68-91% -> 1-2%.
  - P2 hair through arms: 29% -> 9% (deaths2).
  - P1 coat through legs: 32% -> 0% (pilot1) and 38% -> 9% (deaths1).
  - Weapon through cloth: no frames in any shot (was up to 1.7%, 0.04 deep).
- What remains is almost all in the first row of cloth next to a pinned seam (the waist or shoulder), where the pin is carried by the body and cannot move.
  - Under-robe through the thighs when the hips fold: run1 47%, deaths 66%, at most 0.08 deep while running.
  - Sleeves through the round torso proxy: 18-31%.
  - In the real mesh this is the skin blend at the hip and shoulder. A mesh-level check is still owed.

**Footage**: re-rendered with the final clips and cloth (Blender render of the real skinned GLB, game cloth simulation, travelling root). Files are in `pilot/`: pilot1 and run1 before/after comparisons at 1x and half speed, left-hand close-ups, and the new `deaths_p1_p2` (side and low cameras; `review.py` gained `SHEN_REVIEW_GROUNDED=1` so phase 2 is framed on the floor), `skyfall_p2` and `cuts_p2`. Not Studio footage.

## 6. Results by evidence type (second pass)

- **Static review**: the validator is clean on all 64 clips. Wrist, cloth and death measurements are above.
- **Local regression**: `verify_all.sh` 14/14; cloth simulation test passes.
- **Studio integration**: the phase reveal was measured in single-client play. The re-exported clips were not played in Studio: they are unpublished, so the game still plays the old published IDs (`manifest.json` lists the new content with `uploaded: false`).
- **Multiplayer**: not run (this computer is not used for multi-client tests).
- **Device profiling**: not run; no performance claim for the cloth or the staged skin.

## 7. Remaining

- **Publish.** Upload the 64 re-exported clips and update the IDs. Until then, none of the motion changes are visible in game. After publishing:
  - record Skyfall, the deaths, a phase transition driven by the AI, and light-attack timing in Studio;
  - run the two-client check of the phase reveal and the lights on the other computer.
- **Device profiling** of the cloth (more collision volumes per particle) and of the staged second skin, which spends memory during the transition.
- **Heavy**: contact spacing 0.70 and L1 0.82 still read narrower than the guard. Next iteration: a deliberate grip slide and a braking step.
- **Cloth at pinned seams**: needs a mesh-level check of the hip and shoulder blend (see above).

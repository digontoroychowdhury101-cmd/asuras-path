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

All 11 exported pilot clips validate clean (`export.py`). The full 64-clip sweep with the new solver is in the next section; clips other than the pilot were **not** re-exported.

**Local regression**: `ASURA_BUILD_OUTPUT=<scratch> bash tools/verify_all.sh` passed 14/14 (built to a temporary place; saved place untouched). It does not exercise animation content.

**Studio integration**: provenance and grip measurements above were taken in Studio play. The re-baked pilot clips were **not** played in Studio: they are unpublished, the MCP thread cannot fetch files over HTTP, and pasting each clip inline is impractical. `tools/qa/shen_preview_luau.py` is ready for that check. Footage is a Blender render of the real skinned GLB with the game's cloth simulation and travelling root (`cloth_bake.py` + `review.py`), not Studio.

**Multiplayer**: not run (this computer is not used for multi-client tests).

**Device profiling**: not run; no performance claim.

## 5. Remaining defects and next steps

- Heavy contact spacing 0.70 and L1 0.82 still read narrower than the guard; Heavy's peak fist speed is 43 rig/s for one frame after contact. A Heavy re-author with a deliberate grip slide and braking step is the next pilot iteration.
- Phase 2 and the remaining phase 1 clips are not re-exported; the new solver changes all of them at their next bake (results in the sweep below). Hesitant Moon and Crimson Embrace (wrist 128) need attention before propagation.
- Not started under this pilot: deaths (both phases), phase reveal, Blood Wave warning, Skyfall live-root proof, light-attack readability (peak blade-tip speeds in the lights are a diagnostic of the 0.15 s contacts and are unrealistically high).
- Published IDs still point at the pre-pilot clips; `manifest.json` lists them as `asset_id` for the new content with `uploaded: false`.

## 6. Follow-ups in the same session (left-hand cohesion, solid cloth)

- **Left hand / sleeve gap (cause found)**: the solver laid the palm on the haft and let the wrist absorb the rest. The left wrist sat at 48 deg radial/ulnar deviation for all of idle (anatomical about 20-35) and up to 99 deg in Flowing Glaive, so the hand swung out from under the bracer (close renders, `review.py` cameras `lhand*`). Fix in `shen_lib.py`: `swivel` now also chooses a diagonal grip (`GRIP_SLANTS`, now ±20 deg) and costs wrist pose by anatomy (`WRIST_LIMITS`, `wrist_cost`). Measured with the first version: idle deviation 48 -> 16, frames past range 100% -> 0%; L1 deviation 83 -> 37. New `tools/qa/shen_wrist_report.py`, `tools/blender/shen_import/seam_check.py`.
- **Not settled**: the ±20 deg re-export was interrupted by the usage limit, so the staged pilot `.rbxmx` files may mix the ±36 and ±20 runs. Re-export all 11 pilot clips before review. Finger curl stays about the fixed knuckle line (a haft-following curl was tried and dropped).
- **Solid cloth (work in progress, not in game)**: `pilot/cloth-solid-wip.patch` adds a blade collider, wider garment hit lists and link-midpoint collisions resolved on every pass. Measured in Blender bakes (`tools/qa/shen_cloth_report.py`): coat through legs 56% -> 0% of frames, hair through arms 39% -> 0%, under-robe through legs 27% -> 5%. It fails `tools/test_cloth_sim.py` (rest drift 1.66 > 1.2), so it was reverted from the game. The sleeve/torso flags come from the round torso proxy and need a mesh-level check.

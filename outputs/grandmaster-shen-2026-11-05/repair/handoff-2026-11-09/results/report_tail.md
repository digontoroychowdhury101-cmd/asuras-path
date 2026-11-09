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

**Deaths (P1, P2)**: snap at 0.24 s, knee at 1.15 s, the glaive leaves the hands at 1.35 s, topple at 1.55 s, ground impact at 1.84 s, a small rebound, then rest by 2.1-2.2 s. The dissolve completes at `DeathFadeAt` 2.6 s, so he lies still for about 0.4 s before fading. Validator: no problems in either phase. Lowest body point +0.01 rig units above the floor from 1.8 s on, glaive resting on the floor (+0.01 to +0.02). The phase 2 orbs drop to the floor and roll when the death dissolve starts (`ClothSim.drop`, `BossCloth`).

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

**Skyfall**: the server moves the root along a 28-stud sine arc between the start of the move and its impact. The clip leaves the root alone while airborne (`hover`), so he is moved once, not twice. Checked against the source only; a live recording needs the new clips published.

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

**Footage**: re-rendered with the final clips and cloth (Blender render of the real skinned GLB, game cloth simulation, travelling root). Files are in `pilot/`: pilot1 and run1 before/after comparisons at 1x and half speed, left-hand close-ups, and the new deaths, Skyfall and Rending Arc shots. Not Studio footage.

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

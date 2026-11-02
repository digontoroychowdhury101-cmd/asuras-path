# Research — open-source references and reference games (Stage 1, 2 November 2026)

**Method.** Each repository was sparse-cloned into the git-ignored `work/research/<name>/` at the commit below. Metadata (stars, archive flag, last push, detected license) came from the GitHub REST API on 2 November 2026. Only the files listed under "Inspected" were read. Stars are historical counts, not quality evidence. **No code was copied into the project in Stage 1.**

## Pinned sources

| Repository (verified owner) | Branch @ SHA (commit date) | Stars / archived / last push | Code license (verified) | Separate asset/data terms |
|---|---|---|---|---|
| WolfireGames/overgrowth | main @ `245fe4828631c84c0023d29d1525f5716ccb6106` (2025-03-20) | 2,943 / no / 2026-09-24 | Apache-2.0 (README §License; API reports Apache-2.0) | Game data and art are not in the repo and are commercial. Distributing original assets needs written permission (README). |
| Sixze/ALS-Refactored | main @ `b754d6f0f2bb03741d301f8fb88077ebfe561e17` (2026-08-13) | 1,527 / no / 2026-08-12 | MIT (`LICENSE.md`, © 2026 Sixze et al.) | The repo contains `.uasset` animations. Their provenance is not separately licensed in what I read. **Do not use the assets.** |
| orangeduck/Motion-Matching | main @ `57b7250e0d34a4e456a34d47e24c2f05fdcc711e` (2025-02-05) | 932 / no / 2025-02-06 | MIT | The database comes from Ubisoft LaFAN1, **CC BY-NC-ND 4.0** (README l.25). The data is unusable for us. |
| JLPM22/MotionMatching | main @ `35fc8ee9a0fd97f12de458ea81eaef7c8219d87a` (2026-04-24) | 605 / no / 2026-04-24 | MIT (README §License) | The samples include BVH mocap. Their origin was not verified, so they are not used. |
| Antikythera-Studios/epicfight | 1.21.1 @ `a78aa24b72e90a9d09f5fd61925e4369d117abaf` (2026-05-26) | 244 / no / 2026-10-27 | **GPL-3.0** (`LICENSE`) | `LICENSE-ASSETS`: all rights reserved for `src/main/resources/assets` (including animations). |
| ZsoltMolnarrr/BetterCombat | 26.2 @ `d7ad3c27841f70b3bb4ebbbdfa11dace17c3d09d` (2026-07-31) | 200 / no / 2026-09-17 | **"All Rights Reserved"** (`LICENSE`; API reports NOASSERTION) | The `.blend` animations are under the same terms. |
| georgehuan1994/Unreal-Melee-Combat-System | main @ `dde95ebb68d2b355428acfbca0137ccc7080dd58` (2023-03-14) | 66 / **archived** / 2023-03-14 | MIT | Only README and LICENSE were checked out. **No source was inspected.** |
| Swordphin/raycastHitboxRbxl | master @ `ed076f39a30bf83a77f799fcc95987bac7b1dfeb` (2021-09-21) | 69 / no / 2024-08-03 | MIT | — |
| 1Axen/Secure-Cast | main @ `fe3c585d5803edc8b6374ecde88ec6b22d7780b5` (2024-10-21) | 30 / **archived** / 2024-10-21 | MIT | — |

## Per-candidate findings

### Orange Duck Motion-Matching — ADOPT (technique, MIT, with notice)
- **Inspected**: `spring.h` (`decay_spring_damper_exact`, `inertialize_transition`, `inertialize_update`, l.115-200) and `controller.cpp` (`contact_update` l.796-870; `adjust_character_position` / `adjust_character_position_by_velocity` l.1042-1110; `clamp_character_position` l.1145; `inertialize_root_adjust` l.279).
- **Techniques**: (1) *Inertialization*. On a transition the pose switches immediately. The difference from the old pose is stored as an offset (with velocity) and decayed by an exact critically damped spring with a set half-life, so there is no cross-fade of two live poses. (2) *Contact locking*. A contact point is locked when the contact flag rises, unlocked when it falls or drifts past a radius, and both changes are inertialized. (3) *Velocity-bounded adjustment*. The visible character is pulled toward the simulation by a damped amount capped at `ratio × |velocity| × dt`, so a standing character never slides.
- **Fit**: R15 has 15 Motor6D joints, so per-joint offset decay costs about 15 quaternion ops per actor per frame. Roblox `AnimationTrack` has no inertialization, but `Motor6D.Transform` can be post-adjusted after the Animator evaluates. Stage 3 must confirm the exact RunService phase on the current engine. Technique (3) maps directly onto reconciliation of the predicted dash and onto bounded animation phase correction.
- **Assets**: none needed. **License**: MIT for the code; the formula port gets an MIT notice in `THIRD_PARTY_NOTICES.md`. Data excluded (CC BY-NC-ND).
- **Maintenance**: stable reference code from 2025. The full motion-matching database and the learned (LMM) stack are **rejected**: no licensed data, plus runtime cost.

### ALS-Refactored — ADOPT (concept; MIT)
- **Inspected**: `AlsAnimationInstance.cpp` (`RefreshFootLock` l.1395-1520, `ProcessFootLockTeleport/BaseChange` l.1332-1391) and `AlsFootLockSettings.h`.
- **Technique**: foot lock amount comes from an authored curve. It may jump to 1 (lock a new location) or fall, but never blends in partially. It decays at 5/s while moving and 0.6/s while airborne. Locks are stored relative to the movement base and constrained by thigh and foot angle limits (90° / 40°). A lock amount ≤ 0.9 re-captures the location to avoid teleporting feet.
- **Fit**: Roblox `IKControl` (Position type, chain UpperLeg→Foot) can pin a foot to a world target with weight = lock amount. The curves can be baked by the existing Blender clip tools. Cost: two IKControls per animated fighter, enabled only near the camera.
- **Assets**: our own authored foot-contact curves. ALS `.uasset` content is not used.

### Overgrowth — ADOPT (concept; Apache-2.0)
- **Inspected**: `Data/Scripts/aschar.as` (`UpdateActiveBlockMechanics` l.4786-4811, `HowLongDoesActiveBlockLast` l.13259, `HandleFootStance` l.11746-11830) and `playercontrol.as` (`WantsToStartActiveBlock` l.402).
- **Techniques**: (1) *Active block re-arm*. A press opens a 0.2–0.4 s window. Any press inside the 0.2 s recharge refreshes the recharge without opening a new window, so mashing can never chain windows. (2) *Combat foot stance*. In stance each foot has a target that leads the body velocity. When the planted foot drifts more than 0.1 studs from its target, the foot facing away from travel lifts and steps over `1/step_speed` with a sinusoidal height, and the feet alternate.
- **Fit**: (1) informs the parry-spam rule (contract §5.2), which we keep as our existing decay plus the new token. (2) gives a procedural stance shuffle for locked orbit and low-speed sidesteps, where no directional clip exists, driven by IKControl targets. Ragdoll and the active-combat physics are **rejected**, as the master prompt requires.
- **License**: Apache-2.0. Only behavior is reimplemented, with attribution in notices. No assets.

### Epic Fight — ADOPT CONCEPT ONLY (GPL-3.0, so no code or expression reuse)
- **Inspected**: `AttackAnimation.java` (Phase `antic/preDelay/contact/recovery` l.443+, `attackTick` l.193-217, `hurtCollidingEntities` swept between previous and current pose time l.220-240, per-phase `currentlyAttackTriedEntities` / `MAX_STRIKES`) and `ParryingSkill.java` (`parry_window` default 8 ticks, re-arm only after `2×window` l.75/87, success clears `LAST_ACTIVE` "Fix continuous parry" l.101-111, failure adds a stamina penalty l.114).
- **Concepts used**: phase boundaries in clip time, a collider swept between consecutive pose times, per-phase hit registries (multi-pulse identity), one press = one parry, and a growing penalty for failed parries.
- **Why not code**: the project is not GPL. Our implementation is written independently from the contract text. The `assets` folder is all rights reserved.

### Better Combat — REFERENCE ONLY (All Rights Reserved)
- **Inspected**: `LICENSE`, and `WeaponAttributes.java` (`upswing` l.176-230: hit delivered at a fraction of the attack duration, `attack_range`).
- **Use**: confirms the "windup-to-contact as authored fraction of the clip" data model, which our contract already states through clip phase metadata. Nothing is reused. No parry reference.

### raycastHitboxRbxl — REJECT as primary (MIT)
- **Inspected**: `lib/HitboxCaster.lua` (raycasts between attachments every Heartbeat, `DEFAULT_SIMULATION_TYPE = Heartbeat`).
- **Reason**: it raycasts from animated attachments on whatever machine runs it. The server does not evaluate players' client-driven animations, so server authority would rest on client poses. Baked trajectories (Integration I-4) give the same visual alignment without trusting the client. Kept as a cross-check pattern for a client-side debug overlay.

### Secure-Cast — DEFER (MIT, archived)
- **Inspected**: `src/Utility/Snapshots.lua` (ring of 60 snapshots, `GetSnapshotsAtTime` linear back-scan, `GetPlayerAtTime` interpolation).
- **Reason**: our `LagCompensation` already stores tick history with bisection and swept-capsule tests (`queryHit`). Nothing new for melee. Revisit only if projectile spells need server rewind.

### JLPM22/MotionMatching — SECONDARY (MIT)
- **Inspected**: `Runtime/Inertialization/Inertialization.cs` (offset rotations and velocities per joint plus contact offsets, the same model as Orange Duck) and a symbol search of `MotionMatchingController.cs` (`FootLock`, `UpdateFootLock` l.351-356).
- **Use**: a second implementation that confirms joint-offset inertialization works with per-joint quaternion offsets. We follow Orange Duck's formulation.

### Unreal Melee Combat System — NOT INSPECTED beyond README
Archived. Only README and LICENSE were checked out, so I make no claim about its architecture.

## Reference games — access limits

**NOT RUN in Stage 1.** I did not watch, frame-step or analyse any official Deepwoken, Sekiro, Dark Souls/Elden Ring or Phantom Blade Zero footage or documentation in this session. The design intent below comes from the master prompt only, and no timing values are attributed to these games:

- Deepwoken: a responsive parry exchange. Sekiro: attack, deflect and counter rhythm with posture pressure. Souls: commitment, spacing and punish windows. Phantom Blade Zero: connected choreography.

Stage 2/5 carry a task to inspect official sources (developer posts and official trailers) and record what was actually viewed.

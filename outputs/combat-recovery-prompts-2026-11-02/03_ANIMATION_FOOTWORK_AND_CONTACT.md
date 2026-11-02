# STAGE 3 — cohesive animation, grounded footwork and honest contact

Apply the master and completed timing contract. Implement the selected external techniques as small Roblox-native modules or improvements. Do not substitute more effects for motion/contact repair.

## A. Animation coverage and continuity

1. Generate `ANIMATION_COVERAGE.md` from actual runtime resolution: every playable weapon, grip/family, light step, heavy, running attack, art, stance, guard/impact, deflect, directional dodge, hit reaction, break/recovery and deathblow. Record the resolved ID/source, load result, authored timings, phase mapping and known fallback. Include relevant production mobs and boss overrides separately.
2. Start with a complete Jian-versus-Jian vertical slice, then cover every currently playable family before claiming completion. An empty slot, a no-op, borrowed incompatible Jian thrust, or stock placeholder is not finished coverage. If publishing/ownership/tools block an asset, finish sources/validation and mark that specific runtime acceptance BLOCKED. Do not silently disable existing weapons.
3. Preserve correct one-/two-handed grips, offhand placement, planted support and weapon clearance. Match each move's pose trajectory and phase durations. Derive timing mappings per move; do not assume a shared family clip authored for one weapon runs correctly at speed 1 for another.
4. Implement smooth transitions informed by the chosen inertialization/blending references. Preserve momentum/pose through combo follow-throughs instead of always resetting to neutral. Apply masks/priorities so locomotion, guard and attacks blend intentionally. Avoid fighting Roblox Animate or playing duplicated remote tracks.
5. Replace large routine time-position snaps and 2× catch-up with the selected bounded correction policy. Some late poses may require a discontinuity; record the fallback and why, rather than hiding it. Test first-use asset loading, streamed observers, repeated moves and skipped state phases.

## B. Grounded locomotion and attack steps

Adapt the selected ALS/Overgrowth/Orange Duck/JLPM22 techniques, with source symbols and provenance recorded:

- Directional forward/back/strafe/diagonal combat locomotion relative to facing, with smooth start, stop, acceleration and direction changes. A reversed forward run alone does not establish credible backward footwork.
- Foot-contact phase tracking and bounded planting/IK where appropriate; pelvis/ground adjustment on slopes and steps. Release locks during swing, jump, dodge, teleport, airborne states and ragdoll/death as intended. Prevent knee flips, overextension, foot skating and ground penetration.
- Coordinate root translation/rotation and authored attack steps. For each action choose one root-motion/movement owner and a bounded displacement curve. Retain collision and arena constraints. Avoid simultaneous Humanoid MoveTo, root CFrame writes and another constraint competing to move the same body.
- Preserve recent mob standoff, crowd step-back, ally fan-out and attack turns. Review 10/15 Hz AI facing/decisions versus render motion: smoothly present orientation while retaining authoritative commit constraints. Do not interpolate gameplay yaw into a different attack direction.
- Test forward, backward, both strafes, diagonals, planted guard turns, locked orbit, unlocked reversals, sprint-to-attack and attack-to-dodge/guard on players and production mobs.

Do not adopt full motion matching unless there is sufficient licensed data, a clear benefit over the smaller solution and a measured CPU/memory budget. Do not port external engine runtimes or an ML training system for this task by default.

## C. Align the blade and contact

- Overlay or record the visible hilt/tip, authoritative segment/sweep, committed yaw, moving root, defender hurtboxes and actual contact fraction/time. Check near, middle and maximum range, close overlap, side/rear targets, high/low ground, changing scale and moving attacker/defender.
- Compare trajectory through the whole active interval, not one frame or an entire static fan. Fix material mismatch between animation, trail and gameplay geometry. Prefer shared authored/baked server-sampleable trajectories when a generic sweep cannot represent a move honestly; no client-reported blade pose may decide hits.
- Keep broadphase/sweeps continuous enough across real step sizes. Review previous/current root movement rather than generating both segment endpoints from one current pose if that misses translation. Preserve duplicate-hit prevention and intentional pulse identities.
- Separate debug reach outlines from production weapon trails. A full fan displayed at once can imply instantaneous coverage. Production trails and impact sparks should follow the agreed timeline/trajectory. Retain readable low-effects cues and accessibility preferences.
- Review boss multi-pulse authored contacts, signature attacks, fixed-aim thrusts, large-body hurtboxes and arena-clamped motion. Ground impact/reaction geometry must agree with the animation the player sees.

## D. Hitstop, reactions and feedback

Give animation playback, hitstop, catch-up and cinematics a single composable speed/clock policy. Never restore an obsolete saved speed or continue hard drift correction through a freeze. Decide how cosmetic root/pose presentation behaves during hitstop while the authoritative simulation continues. Test new tracks starting during a freeze, interrupted tracks, repeated impacts, death and finish cinematics.

Deliver directional reactions appropriate to outcome/grip, clear block versus deflect, and coherent transitions back into controllable stance. Avoid duplicate sound/VFX/camera impulses after prediction acknowledgment. Tune shake/FOV/audio only after timing and motion align; preserve reduced-motion/flash settings and readability in groups.

## E. Gate

Save comparable real-speed before/after video plus slow inspection where available. Log blade/contact error, foot drift during planted intervals, transition snaps, track counts and CPU/frame cost. Verify flat ground, slopes/steps and low FPS. Run relevant presentation, movement, simulation and asset-validation checks, then a canonical build. Update the coverage matrix and integration map with running implementation paths and measured results. Continue to real multiplayer verification.

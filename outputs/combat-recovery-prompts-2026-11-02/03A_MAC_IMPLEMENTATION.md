# PROMPT 1 — MAC FIRST: Stage 3 implementation and Windows handoff

You are continuing **Asura's Path**, a Roblox combat game. Execute the Mac implementation half of Stage 3: responsive, connected animation; omnidirectional footwork; honest blade/contact alignment; selected open-source adaptations; and focused closure carryovers. Implement the work, do not stop at a plan or research report.

## Scope, precedence and starting point

This prompt combines the original Stage 3 with the latest six-point follow-up and the Stage 2 closure findings. Read `outputs/combat-recovery-prompts-2026-11-02/MASTER_PROMPT.md` and `03_ANIMATION_FOOTWORK_AND_CONTACT.md` for the full architecture/file list. **This prompt controls this session's scope: stop at the Mac-to-Windows handoff; do not automatically execute Stages 4–5 or attempt final acceptance here.**

The known closure commit is `6bcaccb`. Read current source and history; use any newer completed work rather than reverting to that commit. Read applicable AGENTS.md, CLAUDE.md and docs/BUILD.md. Inspect the branch, dirty files, source provenance and current Studio sessions. Sync safely with `ux/onboarding-overhaul` under the current repository/host rules. Do not rebase dirty work, overwrite unrelated edits or operate on another person's Studio session. The Windows worker must be paused while this Mac batch owns the branch.

Then read these existing evidence files in `outputs/combat-recovery-2026-11-02/`: `STATUS.md`, `closure/CLOSURE.md`, `TIMING_CONTRACT.md`, `DESIGN_INTENT.md`, `INTEGRATION_MAP.md`, `RESEARCH.md`, `DEFECT_LEDGER.md` and `TEST_MATRIX.md`. Earlier specification sections contain superseded proposals; the implemented closure policy and subsequent explicit user instructions take precedence. Do not accidentally restore one-token-only parries or obsolete timing/codec behavior from old prose.

Preserve Stage 2's intent-correlated confirmation, v5 codec or its deliberate successor, receipt-based input lifetimes, terminal records, contact snapshots, registry isolation, KO protection, press-anchored dodge grace and light-hitstun defensive answer. Keep the closure and timing regressions green. Do not implement **Borrowed Force**; it remains an unapproved proposal.

## Product and authority contract

Target fast, aggressive wuxia combat with precise deflections, connected counters, grounded directional footwork and readable committed strikes. Deepwoken/Sekiro are behavioral exchange references; Souls/Elden Ring inform spacing and commitment; Phantom Blade Zero informs connected choreography. Do not claim their private implementation or exact frame data is known.

Keep 60 Hz simulation, the existing 150 ms rewind ceiling, 1.4× tempo and 100 ms ordinary deflect baseline. Do not loosen windows to hide latency or animation defects. Record any evidenced per-move tuning and update affected tests. Preserve the campaign, schema v4 player data, health layers, spells, boss phases, mob attack turns/standoff, respawn safeguards and accessibility controls. Clients may predict bounded presentation/movement; server outcomes remain authoritative. Never award client-predicted damage, parries, i-frames or rewards.

## 1. Finish the two targeted timing/movement carryovers

**Mixed-time facing:** inspect `CharacterService.facingAt`, which previously combined the rewound defender pose with the attacker's current position. Specify which time governs attacker position, defender position/facing, geometry and contact resolution. Fix inconsistent mixing or implement and behaviorally justify an explicit policy. Test moving opponents near the frontal/rear guard boundary, rotations, delayed contacts and asymmetric roles. Keep present-time and historical readings clearly named; do not claim a historical state record alone solves pose timing.

**Rejected-dash correction:** inspect `WorldStateController.Rollback`. It previously zeroed horizontal velocity even while claiming to preserve knockback. Test displacement and ongoing velocity separately, including external movement during a dash. Correct unintended cancellation of legitimate motion. Keep collision sweeps, no movement of a replacement/KO'd body, and no double application on acknowledgment. Model walls, rising/descending ground, steps, interruption, timeout and rejection in behavioral tests. Real Studio geometry acceptance belongs to the Windows prompt if infeasible here; faked Blockcast results are not that acceptance.

## 2. Complete a coherent Jian vertical slice first

Implement and demonstrate the following before expanding the same solution across families:

1. **Dash animation starts with predicted movement**, using the actual direction/action. Acknowledgment adopts the same occurrence without restarting it, replaying effects or applying displacement twice. Handle refusal, interruption, timeout, respawn and a missed intermediate snapshot.
2. **First-visible-motion latency:** investigate update ordering, asset readiness, fades and authored anticipation. Closure measured roughly 85 ms changed-pose response at ~24 fps, not the earlier ~2 ms track-start proxy. Distinguish small genuine pose motion, the existing 0.25-stud probe threshold, intentional windup and display presentation. Fix avoidable delay; do not accelerate away the telegraph, change a threshold just to pass A1, or treat track.IsPlaying as visible movement.
3. **Responsive combo links:** support timely L1→L2→L3→L4 presentation through production input. Predict eligible follow-ups with a separate local presentation model where appropriate, validate state/resources/cancel windows, and reconcile by intent identity. If a link remains server-driven, quantify its delay and demonstrate how it meets the target. Prediction must never confirm on an unrelated state change or alter authoritative snapshots.
4. **Phase and pose continuity:** replace routine hard seeks/2× catch-up with bounded phase correction under the current timing contract. Use per-move authored phase metadata. Preserve follow-through and momentum through links instead of forcing neutral between clips. Handle same-move repeats, skipped phases, new observers, stale samples, first-use load and weapon swaps.
5. **Single playback owner:** coordinate animation correction, hitstop and cinematics through the appropriate actor owner. No competing speed writes or stale-speed restores. Specify freeze/debt repayment for action/base/gait/trail/root presentation while server simulation continues. Handle tracks starting or ending during hitstop and duplicate contact cues.
6. **Measure and regress:** retain explicit intent/action/contact IDs, list missing samples and outliers, and record both changed pose and body movement. Use feasible Mac single-client checks; leave high-frame-rate and two-client acceptance pending for Windows.

## 3. Integrate the selected GitHub techniques into running code

Continue the existing pinned research and integration map, rather than repeating broad discovery. Inspect actual upstream symbols before implementing:

- Orange Duck Motion-Matching: https://github.com/orangeduck/Motion-Matching — critically damped pose-offset/inertialized transitions, contact lock/unlock and bounded corrections; cross-check https://github.com/JLPM22/MotionMatching where useful.
- ALS Refactored: https://github.com/Sixze/ALS-Refactored — foot locking, directional locomotion and ground/pelvis adjustment.
- Overgrowth: https://github.com/WolfireGames/overgrowth — stance stepping, planted feet and connected reactions; inspect aschar.as rather than importing its engine.
- Epic Fight / Better Combat — phase/contact coordination concepts already selected in INTEGRATION_MAP; write the implementation independently where their licenses preclude code reuse. Do not copy their restricted assets/code into the project.

Verify pinned SHA, provenance and separate code/data/asset licenses; add accurate required notices and per-adaptation source references. Update the source-symbol → local-code → test/evidence map. A links-only report or unused vendored file is not integration. Do not force reuse from every repo. No full motion-matching database, ML runtime, foreign game engine or active ragdoll simulation by default; use the small Roblox-native solution supported by the research and budget.

## 4. Ground the movement and align contact

- Implement forward/back/side/diagonal combat locomotion relative to facing, with coherent acceleration, start/stop, reversals and turn-in-place/stance steps. Reversing a forward run alone is insufficient.
- Add bounded foot-contact locking/IK and ground/pelvis adjustment as justified. Release locks appropriately for swing, jump, dash, teleport and death. Prevent skating, knee flips, overextension and floor penetration. Apply post-animation joint corrections in the actual Roblox evaluation order, with one joint writer; test respawn/rig scale and reduced-motion behavior.
- Establish one root movement owner per actor/action. Coordinate attack steps/lunges and facing with root motion, collision and arena clamps. Do not let Humanoid MoveTo, CFrame writes and constraints compete. Retain NPC standoff, crowd step-back, ally spacing and attack turns. Smooth presentation without changing committed gameplay yaw.
- Record/bake visible hilt/tip trajectories and phase times where generic root arcs are inadequate. Use shared server-sampleable data for authority and client trails; no client-evaluated blade pose decides hits. Compare throughout active frames, not one still or a complete static fan. Include root translation between previous/current samples, reach, lunge, pulse identity and duplicate-hit prevention.
- Keep debug outlines separate from production trails. Sparks, trails, hit reactions and damage must describe the same action/contact. Include boss pulses, signature attacks, large/scaled bodies and fixed-aim strikes, not only player Jian.

## 5. Complete supported weapon/action coverage

Generate ANIMATION_COVERAGE.md from actual resolution and runtime loading where available: every playable weapon/family, grip, light step, heavy, running attack, art, stance, guard/impact, deflect, directional dodge, reaction, break/recovery and deathblow. List player, production-mob and boss overrides separately. Do not equate “12 weapon entries” with 12 independently authored families; report the actual mapping.

Finish meaningful coverage after the Jian slice. Empty clips, no-op playback, incompatible borrowed thrusts or generic stock placeholders remain open. Match each family/move's grip, phase timing, path, offhand placement and clearance. Shared clips require an evidenced per-move mapping. Use the existing authoring/publishing/read-back workflow where authorized and available. If publication, ownership or tools block a clip, prepare its complete source/bake/manifest, list the exact blocker and make it an actionable Windows task; do not mark it loaded or silently disable weapons.

## 6. Mac execution and completion boundary

This Mac is an implementation/authoring host, not presumed incapable of Studio. Run supported focused single-client checks when feasible and report actual frame times/focus/settings. Use offline authoring/validation and regression tests for the rest. Do not repeatedly attempt heavy two-client boot or full-world performance acceptance here. No artificial stripping of the canonical world, global driver changes or inflated acceptance claims.

Run relevant suites, including both Stage 2 suites and new behavioral coverage, then the required verifier/build workflow. Missing binaries, missing engine type definitions, genuine new analyzer errors, existing failures and fake-engine passes are separate outcomes. Diagnose the supported project tooling; do not call a skipped suite a pass. Verify a test can detect the defect where appropriate.

Retain evidence in the existing combat-recovery directory, adding dated subsections or a Mac Stage 3 subdirectory without overwriting historical logs. Update STATUS, TIMING_CONTRACT, INTEGRATION_MAP, ANIMATION_COVERAGE, TEST_MATRIX and the defect ledger. Add **MAC_TO_WINDOWS.md** containing:

- The exact final commit/build digest and what is implemented versus incomplete.
- Changed runtime/authoring files, asset IDs/manifests and upstream adaptation provenance.
- Tests/Studio runs actually completed, measured conditions, failures and missing samples.
- A prioritized Windows queue with exact runnable commands, test case IDs, expected outcomes, scene/setup and evidence destinations.
- Outstanding assets, wall/slope/knockback tests, first-motion and dash-animation checks, blade/foot drift, full-world performance and two-client acceptance. State any unused decisions/proposals clearly.

Remove only owned temporary QA injections, restore lag/settings and stop owned Play sessions. Rebuild canonical outputs if source/assets/mappings changed. Follow the repository's commit/push handoff protocol within actual authorization; stage only your batch and preserve unrelated work. Update PROJECT_STATE in ≤60 words. End with the handoff commit and exact unfinished Windows work. **Mac implementation complete is not Stage 3 accepted, multiplayer verified or combat fixed.**

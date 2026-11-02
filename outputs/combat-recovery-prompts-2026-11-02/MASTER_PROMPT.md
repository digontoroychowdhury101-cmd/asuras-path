# MASTER PROMPT — repair combat cohesion in Asura's Path

You are implementing and validating the Roblox combat game **Asura's Path**. Combat currently feels choppy, delayed, disconnected and insufficiently grounded. Repair the causes, research and integrate suitable open-source techniques, and complete the outstanding multiplayer verification with two genuine Studio clients connected to one server.

This is an execution task. Read, investigate, implement, test and deliver reviewable results. Do not stop at recommendations, a repo list, a plan, scaffolding, or green offline tests. Work through the five stage files beside this master in order. Keep concise progress updates and persistent evidence so another session can continue.

## Product target

Deliver responsive omnidirectional sword combat with readable committed attacks, coherent footwork, visually credible weapon contact, consistent parry exchanges and clear recovery. Use Deepwoken as a behavioral reference for responsive parry exchanges; Sekiro for attack/deflect/counter rhythm and posture pressure; Dark Souls/Elden Ring for deliberate commitment, spacing and punish windows; Phantom Blade Zero for connected martial-arts choreography and defensive reactions.

These are design references, not claims that their private code, exact timing or network implementations are known. Research primary sources and official gameplay demonstrations. Record what you actually inspected. Do not claim to have watched or frame-analyzed a video when you only read its description. Do not aim for unrestricted animation cancellation, exact imitation of every reference game, or physically simulated limbs at the expense of responsiveness.

For this task, **1:1 parry** means that one eligible defensive press, a specific incoming contact, the visible defense, the authoritative result, and feedback agree on an explicit shared timeline. It does not mean copying an unverified Deepwoken window. Define and test the behavior for repeated contacts, multi-pulse attacks, successful re-arming, failed presses, spam decay and simultaneous exchanges.

## Repository and working contract

- Read applicable `AGENTS.md`, `CLAUDE.md`, `PROJECT_STATE.md` and `docs/BUILD.md`. Inspect the current branch, HEAD, dirty files and current Studio source provenance before editing. Preserve unrelated work. Respect current host approvals and prior approval rejections; do not bypass a rejected rebase. Do not stage unrelated files or rewrite history.
- Keep edits, research checkouts and evidence within this repository. Do not text-read binary place/model/animation files. Use appropriate parsers/rendering tools when inspecting them.
- Maintain the deterministic engine-free simulation and server authority. Clients may predict presentation and bounded permitted movement, but never award damage, posture, invulnerability, successful defense, rewards or match outcomes.
- Preserve the campaign, player data schema v4, three-layer health, weapons/spells, boss phases, ordinary-mob attack turns, respawn safeguards, accessibility preferences and cross-device controls. Do not replace the game with an external framework.
- Retain 60 Hz simulation and the existing 150 ms maximum rewind unless an evidenced design change is documented and separately justified. Keep 1.4× tempo and the 100 ms ordinary deflect baseline as the initial comparison baseline. You may tune per-move timing, movement and exchange rules within this task when measurements justify it; record before/after values, tradeoffs and affected tests. Do not silently loosen defense windows to hide timing errors.
- Keep presentation state distinct from authoritative state. Do not mutate the shared authoritative snapshot to fake responsiveness. Use stable action/contact identities and explicit acknowledgments where needed.
- Use modern Luau, `task`, supported raycasts and modern constraints. Add modules to `default.project.json` when required. Avoid unrelated rewrites or new dependencies with no demonstrated benefit.

## Read these files in order

### 1. Context

`PROJECT_STATE.md`; `CLAUDE.md`; `outputs/jian-combat-2026-11-01/README.md`; `outputs/claude-followup-2026-10-21/OMNI_COMBAT.md`.

### 2. Simulation and tuning

`src/simulation/CombatRules.luau`; `src/shared/CombatSettings.luau`; `src/simulation/StrikeGeometry.luau`; `MoveSchema.luau`; `WeaponSchema.luau`; `WeaponExpansion.luau`; `SpellRules.luau`; `SpellSchema.luau`; `InputBuffer.luau`; `Tempo.luau`.

### 3. Server and AI

`src/server/CharacterService.luau`; `LagCompensation.luau`; `src/server/Services/AIService.luau`; `src/shared/MobSpacing.luau`; `src/server/Services/BossAttackService.luau`; `BossTactics.luau`; `BossDuo.luau`; `BossHazards.luau`; `BossArenas.luau`; `MagicService.luau`; `SpellGeometry.luau`; `src/server/RecoveryRules.luau`. Follow the actual dependencies into `BossMotion`, spell effects and networking where relevant.

### 4. Shared contracts

`src/shared/BossAttackCatalog.luau`; `BossEncounterRules.luau`; `BossTypes.luau`; `BossRoster.luau`; `InputMap.luau`; `ContactCues.luau`; `AnimationCatalog.luau`; `BossAnimationRules.luau`; relevant `Config` and intent protocol definitions.

### 5. Client

In `src/client/Controllers/`: `InputController.luau`; `FighterAnimations.luau`; `CombatFeedback.luau`; `GameFeelController.luau`; `CombatHud.luau`; `ActionBar.luau`; `CombatCallouts.luau`; `TargetPlate.luau`; `EnemyBars.luau`; `BossHud.luau`; `DuoBars.luau`; `CombatVfx.luau`; `SanguineCombat.luau`; `WeaponTrails.luau`; `SkinWeaponFx.luau`; `SpellController.luau`; `SpellHud.luau`; `SpellVfx.luau`; `BossAnimations.luau`; `BossCinematics.luau`. Also inspect `WorldStateController`, `CameraController`, `MovementController`, render/update ordering and the Jian/opening-cast animation authoring tools.

### 6. Tests and existing harness

`tools/test_omni_combat.luau`; `tools/test_combat_contact.luau`; `tools/test_weapons_and_spells.luau`; `tools/test_boss_encounters.luau`; relevant presentation/movement/runtime tests; `tools/qa/OmniPvP.server.luau`; `tools/qa/OmniPvP.client.luau`; `tools/verify_all.sh`.

## Audit findings to verify, reproduce and resolve

These were source findings at commit `497e23b`, not fresh human-playtest conclusions. Reconfirm each against the current implementation, distinguish confirmed defects from intentional behavior and hypotheses, and record evidence before changing it.

1. **Input lifetime versus transit:** `CharacterService.onIntent` pushes reconciled original press timestamps into a buffer whose lifetime is 100 ms. A valid press can already exceed that lifetime when consumed; timestamp reconciliation permits up to 150 ms rewind. Separate network validity/press time from executable queue lifetime without letting old commands execute long after intent. Explain expiry, supersession and rejection to diagnostics.
2. **Local action delay:** player attacks and dash grants depend on server replication before presentation/movement starts. Late attacks catch up at up to 2×, producing delayed-then-rushed playback. Implement bounded local prediction and reconciliation where appropriate, retaining server outcomes and movement validation.
3. **Incomplete animation timebase:** fighter playback uses packed state elapsed plus time since receipt; the packed fighter record lacks a sample/send timestamp to account for transit. Establish explicit action starts, phase boundaries, sequence IDs and snapshot timing. Handle stale/out-of-order state, skipped phases, streaming and repeated moves.
4. **Animation discontinuities:** hard playback-position corrections, fixed fades, catch-up speed changes and repeated action identities need review. Ordinary combo continuation can cut from a follow-through into a neutral-start clip. Solve pose continuity and phase continuity together.
5. **Coverage gaps:** most base player Unarmed/Dao/Guandao custom slots were empty; expanded weapons fall back to families, while the controller skips unauthored slots. TwinDaggers inherits Jian clips despite different frame data. Make a runtime coverage matrix and deliver meaningful, correctly timed animation for every currently playable weapon family and relevant action. Reuse must match grip, trajectory and timing; no silent no-op or inappropriate generic slash.
6. **Footwork/movement mismatch:** abrupt state speed multipliers, limited gait selection, reversed forward cycles, lack of directional blends/runtime planting and cosmetic lunges can separate feet from root motion. Establish one movement owner per actor/action and align world displacement, foot contacts and authored poses.
7. **Visible blade versus hit volume:** `StrikeGeometry` uses generic root-relative arcs/thrusts; the visible full sweep outline is not proof that the animated blade matches that volume at each instant. Compare blade/hilt trajectory, committed facing, root movement, hurtboxes and actual contact times throughout moves. Preserve authoritative validation; consider shared authored/baked trajectory data if necessary.
8. **Parry correctness under latency:** backdating a press does not undo an already resolved hit. Current geometry rewind and current-time defense/facing can describe different moments. Define a bounded, consistent policy for contact time, defense eligibility, facing, i-frames and accepted late input; explicitly document the latency limit. Do not permit arbitrary retroactive parries.
9. **Tick ordering:** closing-window sweeps occur before normal buffer draining; boss listeners can resolve impacts before player defensive intents drain. Test boundary presses and actor-order bias, including simultaneous attacks and phase transitions. Deterministic ordering alone does not prove fairness.
10. **Exchange timing:** short light startups and follow-up contact intervals can fit inside the 280 ms light hitstun, whose action row is empty. Determine which combos are intentionally true, which permit a defensive answer, and where punish windows exist. Include successful deflect recoil, defensive re-arming, recovery cancels, blockstun and guard release. Do not remove all commitment to make the game feel fast.
11. **Hitstop ownership:** feedback freezes tracks while animation correction/catch-up/cinematics also control playback speed. Coordinate these systems so freeze/resume does not cause stale-speed restores, timeline jumps, sliding roots or duplicate feedback. Keep authoritative simulation running.
12. **NPC/boss coherence:** retain and regression-test recent standoff, gait and group-turn fixes. Check telegraph timing versus real contact, special-attack cancellation, signature attacks, boss pulse identity, arena clamps, large bodies and duo coordination. Do not accept fixes that work only in a stationary Jian duel.
13. **Spells and injury:** spells currently require Idle and use a separate input path. Review lost boundary presses and intentional cast commitment. Head injury and parry-spam penalties intentionally alter timing; keep them explicit and testable rather than confusing them with network loss. Retain health/posture/stamina/Qi integrity.
14. **Performance and evidence:** earlier Studio runs were background-throttled or affected by graphics handoff/frame caps. Record actual frame times and focus state. A nominal 60 Hz simulation and green mocked tests do not establish smooth rendering, fair latency or human feel.

## Open-source research and integration contract

Actively inspect, compare and integrate suitable techniques; do not merely mention repositories in a report. Start with the following verified discovery leads. Counts are historical observations from 2 November 2026, not immutable quality scores:

| Repository | Observed stars | Intended study |
|---|---:|---|
| https://github.com/WolfireGames/overgrowth | 2,943 | Shipped character/combat code, active blocking, reactions, planted feet and foot IK; inspect `Data/Scripts/aschar.as` and `playercontrol.as` |
| https://github.com/Sixze/ALS-Refactored | 1,527 | Foot locking, pelvis/ground offsets, directional movement, network locomotion; inspect `Source/ALS/Private/AlsAnimationInstance.cpp` |
| https://github.com/orangeduck/Motion-Matching | 932 | Foot contacts, inertialized transitions and controller/animation displacement; inspect `controller.cpp` and `database.h` |
| https://github.com/JLPM22/MotionMatching | 605 | Accessible trajectory controller, foot locking and inertialization; inspect runtime controller and `Runtime/Inertialization/Inertialization.cs` |
| https://github.com/Antikythera-Studios/epicfight | 244 | Attack phases, animated collision and parry/guard; inspect `AttackAnimation.java`, `ActionAnimation.java`, `GuardSkill.java`, `ParryingSkill.java` |
| https://github.com/ZsoltMolnarrr/BetterCombat | 200 | Combo/weapon data and windup-to-contact coordination; not an implemented parry reference per the inspected README |
| https://github.com/georgehuan1994/Unreal-Melee-Combat-System | 66 | Secondary archived Soulslike architecture/directional-reaction example |
| https://github.com/Swordphin/raycastHitboxRbxl | 69 | Roblox-specific melee trace reference |
| https://github.com/1Axen/Secure-Cast | 30 | Archived Roblox server-authoritative projectile/lag-compensation reference |

Verify current owner/redirect, branch, commit SHA, activity, code license and separate asset/data licenses before reuse. Inspect real source and relevant demos; stars do not prove responsiveness or correctness. Exclude exploit repositories, unauthorized leaks, reuploads and unsupported “production ready” claims. Prefer primary sources.

Overgrowth code is advertised as Apache-2.0 with commercial assets separate. ALS and Orange Duck advertise MIT code; Orange Duck identifies separate restricted source animation data. Epic Fight separates GPL code from restricted assets. Better Combat needs its actual license inspected rather than assuming permissive reuse. Preserve notices and provenance for any copied/adapted material. Do not copy restricted assets or incompatible code into the project. If reuse is unsuitable, document the reason and implement the independently specified behavior using appropriate sources.

Make substantive Roblox-native adaptations from the selected references where justified, with a traceable source-to-change mapping and before/after evidence. Do not import an Unreal/Unity/C++ runtime or a large motion-matching/ML stack by default. A small, well-authored directional blend/foot-contact system may be a better fit. Full motion matching requires suitable licensed motion data and a measured runtime budget; justify it before adopting it. Do not add ragdoll simulation to active combat just because Overgrowth has it.

## Evidence and delivery

Use `outputs/combat-recovery-<actual-date>/` for `STATUS.md`, `BASELINE.md`, `RESEARCH.md`, `INTEGRATION_MAP.md`, `TIMING_CONTRACT.md`, `ANIMATION_COVERAGE.md`, `TEST_MATRIX.md`, `ACCEPTANCE.md`, machine-readable results, logs and both-client captures. Preserve historical evidence; mark superseded conclusions.

Classify every claim as static source inspection, offline behavior test, engine emulation, seeded Studio diagnostic, real local multiplayer, real ordinary input, human judgment, device hardware or live-service evidence. Use PASS/FAIL/BLOCKED/NOT RUN distinctly. Never represent automated remotes as ordinary inputs or perfect server-timed bots as human fairness tests.

Run the relevant regression suites and required build/verifier workflow. If a tool is missing, diagnose and use the supported project setup; do not invent a pass. Rebuild canonical place outputs when source/assets/mappings change, verify the tested Studio source matches the final build, remove temporary QA injections, and follow repository handoff rules within actual authorization. Do not enable ranked release flags or claim launch readiness from this work.

The final handoff must say what changed, what was adapted from which pinned sources, before/after measurements, tests actually run, unresolved failures, and exactly which human/device/live checks remain. Completion requires both implementation evidence and the applicable verification gates below; unavailable human or hardware evidence must remain explicitly open.

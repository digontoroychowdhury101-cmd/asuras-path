# PROMPT 2 — WINDOWS AFTER MAC: finish Stage 3, then multiplayer and acceptance

You are continuing **Asura's Path** on the Lenovo gaming Windows computer **after the Mac implementation batch has finished and pushed its handoff**. Finish remaining Stage 3 implementation/runtime verification, execute genuine Stage 4 multiplayer verification, and complete the available Stage 5 checks. Do the work and fix discovered failures; do not merely restate the Mac report.

## 1. Acquire the exact handoff

Read applicable AGENTS.md, CLAUDE.md and docs/BUILD.md. Inspect branch/HEAD, dirty files and existing Studio sessions; preserve unrelated work. Coordinate exclusive ownership of `ux/onboarding-overhaul`: the Mac worker must now be paused. Safely sync and read `outputs/combat-recovery-2026-11-02/MAC_TO_WINDOWS.md`, or the exact replacement path identified by the Mac session. If the handoff is missing, inspect current history/artifacts and establish what actually landed; do not invent Mac completion.

If later Mac follow-up batches have landed, also read `outputs/mac-followup-2026-11-02/HANDOFF.md` and their results. Use the latest completed revision as the test baseline, preserving the original combat handoff as history. Add the affected targeted checks for opening/forge transactions, Bull/duo playback, armour ownership/replication/contact-time effects/duel normalization and changed traversal/performance. Only test additions actually installed. Their RPG/content acceptance is separate from combat Stage 5; do not expand this session into building undispatched features or certify later changes using an older build's results.

Read `outputs/combat-recovery-prompts-2026-11-02/MASTER_PROMPT.md`, the original `03_ANIMATION_FOOTWORK_AND_CONTACT.md`, `03A_MAC_IMPLEMENTATION.md`, `04_REAL_MULTIPLAYER_VERIFICATION.md` and `05_FEEL_ACCEPTANCE_AND_HANDOFF.md`. Those contain the complete coverage/multiplayer matrices. **This prompt scopes the sequence: close Stage 3's outstanding work first, then Stage 4, then applicable Stage 5.** Do not restart Stages 1–2 or reimplement already validated Mac changes.

Read current STATUS, closure/CLOSURE, TIMING_CONTRACT, DESIGN_INTENT, INTEGRATION_MAP, ANIMATION_COVERAGE, TEST_MATRIX and defect ledger. The known Stage 2 closure is `6bcaccb`; use the newer Mac handoff as the implementation baseline. Earlier spec tables contain superseded proposals; current implemented closure policy and explicit user instructions take precedence. Borrowed Force remains unapproved and must not be implemented.

Preserve server authority, prediction/intent identities, contact snapshots, registry/KO fixes, 60 Hz simulation, 150 ms rewind ceiling, 1.4× baseline tempo, 100 ms ordinary deflect baseline, player schema/health layers, boss/mob/recovery systems and accessibility. Do not silently widen windows, alter balance or reduce the canonical world to make tests pass.

## 2. Establish a trustworthy Windows runtime

Record OS/Studio version, actual GPU/session conditions, graphics quality, focus, source/build digest and frame/step p50/p95/p99 with dropped steps. Previous sessions reported ~23–24 fps even while focused; a gaming laptop does not prove that cap disappeared. Diagnose with supported profiling and a controlled scene comparison. Report any persistent cap rather than labeling results as 60 fps. Do not change global graphics/drivers or unrelated settings without actual authorization.

Build and open a dedicated test place from the handoff, using the project's supported workflow. Verify running source/digest against the checkout and preserve the user's other open places. Do not tune one build and capture another. Restore all owned temporary settings afterward.

## 3. Finish Stage 3's real runtime gates

Use the handoff queue and fix any outstanding implementation, publishing, integration or mapping work. Authoring completed on Mac is not runtime playback acceptance. Verify load-back/ownership, metadata and actual playback for every supported weapon/action, relevant production mob and boss override. Record missing/incompatible clips honestly. Complete the selected GitHub adaptations in running code with pinned provenance and appropriate notices; do not substitute screenshots or an unused module for integration.

Prioritize these inherited six-point requirements:

1. **Predicted dash motion and animation begin together.** Measure input, body displacement and visible pose separately; test all directions and neutral backstep. Server acknowledgment must adopt, not restart, duplicate effects or reapply movement.
2. **First-visible-motion target:** resolve avoidable update/fade/load delays. Compare at measured 60 fps when attainable and controlled 30 fps; retain a lower-FPS comparison if relevant. The old ~2 ms result is a track-start proxy. Closure's ~85 ms threshold-crossing pose result is not silently promoted into a pass. Keep authored anticipation readable; do not shorten windups or change measurement thresholds just to pass.
3. **Combo responsiveness and continuity:** use actual production input, including the existing Windows OS-click tool or a supported client scheduler for controlled timing. Record achieved spacing and explicit intent/action IDs; label automation honestly. Verify L1→L4, same-move repeats, heavy/art transitions and guard/dodge cancels, including delayed confirmation. Inspect links at real speed from owner and observer views.
4. **Playback/contact coherence:** validate bounded phase correction, inertialized transitions, single playback/hitstop ownership, masks/priorities, foot locks, authored phases and blade/trail geometry. Test new tracks during freeze, repeated impacts, interruption, streaming/skipped phases, weapon swaps and cinematics. Server simulation must keep running.
5. **Temporal facing policy:** verify the Mac fix/decision for rewound defender versus attacker position. Test moving opponents, turns, front/rear guard boundaries, delayed contact, role reversal and asymmetric latency. Historical state labels alone do not prove pose consistency.
6. **Rejected dash in actual geometry:** test walls/corners, rising/descending slopes, steps, changing ground height, interruption/ongoing knockback velocity, timeout, KO and respawn. Offline Blockcast fakes do not satisfy this gate. Confirm correction cannot tunnel, float/penetrate ground, erase legitimate motion or move the replacement character. Distinguish ordinary wall-limited accepted dash from a server-rejected prediction; explicitly induce each through the QA scenario.

Extend the checks through forward/back/side/diagonal locomotion, lock orbit, unlocked reversals, stance turns, sprint→attack and attack→guard/dodge. Check planted-foot drift, knee/weapon clearance, root ownership, scaled rigs, high/low ground and moving root sweeps at near/mid/max reach. Retain crowd spacing/group turns and evaluate at least one humanoid boss, one large creature and duo/pulse cases.

Compare Mac baseline/handoff and Windows final captures only with disclosed equipment/stats/network/frame conditions. Save real-speed footage and targeted slow inspection. Measure timing alignment, blade error, foot drift, transition discontinuity and runtime cost against the existing targets; name unmet targets. Run affected regressions after fixes and verify the final build again.

## 4. Execute Stage 4 with two genuine clients

Follow `04_REAL_MULTIPLAYER_VERIFICATION.md` in full, including its authoritative combat matrix. Inspect the current OmniPvP harness before modifying it. Start the installed Studio version's supported **one server plus two actual client sessions/processes**. NPCs, mocks or two separate solo servers do not qualify. Prove both distinct players receive their own and the other player's correlated authoritative action state.

Repair any remaining harness weaknesses: aggregate success requires zero failed mandatory checks; clean scenario resets; one sequence owner per production sender; full damaging-outcome/resource assertions; explicit IDs and expected results; deterministic boundary fixtures; complete both-client evidence; failure-safe cleanup. Direct production-remote diagnostics and ordinary production input are separate test categories. One parry out of four is not deterministic acceptance.

Run the full prescribed matrix: unlocked/locked aim and circling; tracking/commit/sidestep/spin exploit; near/far/side/rear geometry; guard boundaries/release; early/on-time/late parry; opening/closing-tick defenses; simultaneous attacks and interruption/armor; true-combo answers; directional dodges and rejection; aerial restrictions/landing; repeated contacts/pulses and duplicate prevention; lifecycle/rematch/disconnect; mobs/bosses/spells. Reverse player roles and relevant ID/join ordering.

Use supported network simulation. Target measured RTT scenarios 0/local, 50, 100 and 150 ms where supported, with 200 ms as a beyond-envelope observation; add supported jitter/asymmetry/loss cases. Record configured and measured values, directionality, snapshot age, frame times and clock uncertainty. Partial QA transport delay is not full Roblox physics/network emulation. No fabricated timestamps, authority bypasses or green labels for unavailable cases.

Specifically assess the current grace tradeoff: up to 100 ms added melee hit-confirm delay for eligible player defenders, no grace for NPC defenders, and documented no-grace boss/area paths. Validate that visual contact, defense result, reaction and feedback remain understandable; do not claim all attack types have equal latency compensation. Check whether delayed parry recoil interrupting a newer swing remains coherent from both views.

If the host cannot run reliable two-client tests, document exact attempts and the cause, finish independent work and leave multiplayer acceptance BLOCKED. Do not repeatedly retry unchanged failures or substitute seeded solo results.

## 5. Ordinary input and Stage 5 acceptance

Follow `05_FEEL_ACCEPTANCE_AND_HANDOFF.md`. After engineering diagnostics pass, perform a normal-input duel using current InputMap bindings, normal stats/resources and no hidden protection/forced reactions. Check visible timing, defensive learning, true-combo opportunities, footwork/camera, target loss, death/respawn, rematch and cleanup. Automated OS input is automated real input, not human judgment. If a second operator is needed, prepare the clients and exact short human protocol; leave that judgment explicitly pending while completing independent checks.

Review PvE transfer: monk, swordsman, mixed pair and representative bosses, including large/duo cases. Assess reduced-motion/flash/effects readability. Keyboard/mouse, physical gamepad/touch hardware, emulation and cross-server/live services need distinct evidence. Run live persistence/matchmaking only in an already authorized private environment; otherwise NOT RUN. Never enable ranked/public release flags to satisfy this task.

Run the required full verifier/build and relevant timing/closure/animation/movement/contact/protocol/boss/spell/lifecycle suites. Do not label historical passes as new results. Update canonical place outputs and prove final Studio source provenance. Remove owned injected QA scripts/remotes, debug holds, lag adapters and forced state; retain intentional unmapped reusable QA tools. Restore settings and stop owned sessions.

## 6. Final evidence and handoff

Preserve historical logs and the Mac handoff. Finalize STATUS, TIMING_CONTRACT, INTEGRATION_MAP, ANIMATION_COVERAGE, TEST_MATRIX, ACCEPTANCE and the defect ledger; add a Windows result report referencing exact source/build identity and both-client logs/captures. Resolve contradictions between old design proposals and actual behavior; retain old specifications as clearly historical rather than leaving competing active contracts.

Report separately: implementation complete, Stage 3 runtime accepted, real two-client checks, human feel, hardware/performance and live-service status. Use PASS/FAIL/BLOCKED/NOT RUN/PENDING accurately. A running clip, a bot win, green offline tests or one screenshot does not establish fluid combat. Do not mark Stage 5 complete while required human evidence is unavailable.

Follow the authorized repository commit/push protocol, preserve unrelated work and add a ≤60-word PROJECT_STATE entry. End with what changed after the Mac handoff, measured before/after improvements, source adaptations actually used, tests run and exact unresolved checks. Fix newly found engineering failures within scope before returning; do not simply assign them back to the user.

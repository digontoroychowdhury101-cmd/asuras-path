# Combat master completion audit — 6 November 2026

The combat master is **not complete**. Most timing and motion infrastructure has landed, but Stage 3 still has implementation and runtime gaps, Stage 4 has only a narrow multiplayer smoke result, and Stage 5 has no recorded human acceptance. **C00 can start now; AR00 prototypes can follow measured asset intake. Neither requires pretending combat is accepted.** Final arena acceptance must use the integrated bosses and repeat the affected combat checks.

## Scope and evidence

Audited `outputs/combat-recovery-prompts-2026-11-02/MASTER_PROMPT.md`, original Stages 1–5, replacement dispatches 03A/03B, combat status/contracts/coverage, later Windows and Mac handoffs, current source/mappings, and the latest Shen pilot. This audits completion; it does not implement the remaining stages or start environment production.

Source checkpoint: **`29d18af4b4f488e8348a49e0f96d649214fddd4d`**, branch `ux/onboarding-overhaul`. The checkout initially held `9daebb1`; the normal relay advanced it to `29d18af` during inspection. Both start/end identities of the successful fresh regression run are `29d18af`. Unrelated untracked art, Rodin exports and boss work were preserved.

Fresh evidence: static review and **626 passing local checks** across six suites, through the project's engine shim. See [focused-regressions.json](focused-regressions.json) and [log](focused-regressions.log). The first attempt could not launch because this checkout lacked `work/bin/luau/luau`; its error is preserved in `initial-tooling-attempt.*`. Installed official pinned Luau 0.742 into ignored `work/bin/luau`, verified its published SHA256, then reran successfully. This audit did **not** run the full verifier, a new Studio session, two clients, human play, device profiling or live services. Recorded Studio results below are historical and identify their limitations.

## Stage-by-stage result

| Stage | Completed evidence | Remaining work | Assessment |
|---|---|---|---|
| **1 — baseline/research/specification** | Baseline, defect ledger, frame tables, timing contract, pinned repository/license research and integration map exist. Selected techniques reached mapped runtime code in later stages. | Official reference-game inspection is explicitly NOT RUN in `RESEARCH.md:64`; no later completion evidence found in this packet. Historical live baseline gaps were carried forward. | **Core deliverables done; research/live evidence carryovers remain.** Do not redo the whole stage. |
| **2 — timing/input/parry** | Receipt-based queues and terminal statuses; codec v5 with sample/action/intent identity; prediction and intent-correlated confirmation; frozen contact data; defensive grace; simultaneous-contact ordering; light-hitstun defensive answer. Closure evidence and fresh regressions support these. | Real-world rejected-dash cases and changed-pose response were carried into Stage 3; full latency/facing/grace validation remains Stage 4. | **Implementation delivered; carried runtime gates remain open.** |
| **3A — Mac motion implementation** | Predicted dash/combo presentation, bounded phase correction, joint-offset transitions, foot planting/stance steps, shared blade/trail data, published family clips, cleanup corrections and mutation evidence. | Concrete asset/grip/contact gaps listed below, plus visual/runtime acceptance. | **Mac batch delivered; Stage 3 is not accepted.** |
| **3B — Windows completion dispatch** | 3 November fixed refused-dash settlement on stairs and ordinary-foe opener fairness. W-07 flat/upstairs/downstairs passed on that revision. | W-01–06, W-08, W-10–13; remaining W-07 cases; full W-09/Stage 4. Later armour and boss changes require revalidation. | **Partially executed. Resume this dispatch; do not restart 1–2.** |
| **4 — genuine multiplayer** | One real server/two Studio clients; saved smoke result has 12 checks, zero failed, at local latency. | Harness hardening, both-client correlated combat/presentation evidence, full matrix, role reversals, measured latency/frame cases, cleanup/lifecycle coverage. | **Smoke pass only; stage incomplete.** |
| **5 — ordinary input/feel/final handoff** | Human protocol exists; historical local/seeded checks exist. | Actual normal-input duel and PvE judgments, comparable final footage, full-world/device evidence, final current-build hygiene and consolidated `ACCEPTANCE.md`. | **Not accepted; recorded status says not started.** |

A percentage would hide these differences. Published clips, implementation, seeded diagnostics, multiplayer outcomes and human acceptance are separate deliverables.

## What is genuinely implemented

Current source confirms the handoffs describe real code, rather than unused proposals:

- `CharacterService` owns terminal intent records and phased contact settlement; `facingAt` samples historical attacker and defender positions. `CombatRules` packs version 5, including `SampleTick`, `SampleStamp` and `IntentSeq`. `WorldStateController` adopts predictions by their own intent and handles refused travel/velocity correction.
- `AnimationTiming`, `FootStep`, `LocalPrediction`, `ActorPose`, `PlaybackScale` and `StrikeTrajectories` are mapped in `default.project.json`; their consumers use them.
- The pinned Orange Duck/JLPM22 transition techniques, ALS foot-lock concepts and Overgrowth stance-stepping concepts have local destinations and tests. `THIRD_PARTY_NOTICES.md` exists. Epic Fight/Better Combat are recorded as conceptual references with independent implementation. A fresh broad repository search is not necessary to resume this work.
- Preserve the creator-clarified multi-contact parry policy in the implemented timing contract: a press can defend distinct eligible contacts inside its window; duplicate outcomes remain forbidden. Do not restore the superseded one-token-only proposal from older tables. Borrowed Force remains unapproved.

Fresh local results: Stage 2 timing **111**, Stage 2 closure **57**, Stage 3 motion **284**, contact **68**, omni **84**, ordinary-foe fairness **22**; all passed. These exercise local behavior/fakes and do not establish physics, appearance or fairness.

## The actual unfinished combat work

### 1. First motion and transitions

**A1 remains a last-measured FAIL, not a newly measured failure here.** The Mac handoff records about 50 ms to its existing 0.25-stud changed-pose threshold at 60 fps, against a one-frame target (~16.7 ms). Small motion and animation-track start are separate measures. The old ~2 ms track-start proxy cannot close A1. `ActorPose.HALFLIFE` remains 0.045 s. W-01 must measure current source at attainable 60/controlled 30 fps and resolve avoidable delay without changing thresholds or removing anticipation just to pass.

W-02–04 still need directional dash pose/body agreement, scheduled production-input combo links with one occurrence per intent, observer catch-up and bounded convergence at latency. The earlier repeated-track observation was not traced to a confirmed runtime defect; measure it, do not invent a cause.

### 2. Weapon, grip and visible-contact gaps

The family authoring, generated blade data and `WeaponModels` have no later repair recorded after the Stage 3 implementation. The handoff/coverage still list:

- Odachi/Cleaver and Heaven-Piercing blade/reach mismatch; Catalyst's short visible staff versus generic volume.
- Chain Scythe and Prayer/censer chains made of pieces welded to the hand, with generic reach exceeding the visible action.
- Six moves without baked blade alignment: Dao L2, L3, Art, Running; Guandao Art, Running.
- Universal Deflect/Roll/Backdash/Hitstun/Break/Recover clips based on Jian grip, with two-handed/offhand coherence unfinished. All families need W-10 motion review, not just successful asset loading.
- Production mobs with their own clips bypass player baked trajectories in `StrikeTrajectories.forFighter`; boss-specific contacts require separate checking. Do not apply the obsolete coverage statement that Shen has no imported animations: his own resolver/import has since changed.

Run W-06 throughout active frames: visible hilt/tip, moving root, committed yaw, server sweep, trail, contact, damage and reaction; include scale/reach bonuses, slopes, pulses and signatures. Reduced baked player ranges/arcs and the T-MX-04 combo-redirection expectation remain recorded design/acceptance questions, not permission for silent balance changes.

### 3. Footwork, movement ownership and real geometry

- W-05: measured planted-foot drift, slopes/steps, backward/strafe/diagonal movement, knee and weapon clearance, scale, lock/unlock and reduced motion.
- W-07: preserve the historical flat/stairs fixes; complete corner/oblique-wall behavior, ongoing knockback, timeout/refusal, KO and replacement-character cases. An oblique-wall residual displacement is an open observation, not an established new bug. Very late confirmation beyond ~0.5 s is outside the documented prediction envelope.
- W-08/W-13: runtime movement-owner coherence and pose-budget/range transitions with 9+ fighters, a fighter beyond 70 studs and a scaled rig.
- W-11: comparable canonical-world frame/step distributions, dropped steps, memory and track counts. A nominal 60 Hz simulation is not a rendering result.

### 4. Multiplayer harness is still below the master contract

Current `tools/qa/OmniPvP.server.luau` retains the original weaknesses:

| Location | Current behavior | Required completion |
|---|---|---|
| `:180–184` | `result.passed = ok`; failed mandatory checks are counted separately | Require successful execution **and** zero failed/missing mandatory checks; prove a deliberate failed-check fixture fails the aggregate. |
| `:160–162` | Dodge threshold 2/3; parry threshold 1/4 | Deterministic per-attempt expected outcomes; full negated damage, posture/Qi/events and identity checks. |
| `:82–85` | Scenario reset restores HP layers, posture and stamina only | Reset action/queue/history/guard/prediction/ack/temporary protection and assert preconditions. |
| `:101`; client `:24–25` | QA sender uses server `LastSeq` alongside the production sender | One intentional sequence owner per sender path; separate normal-input coverage. |
| client `:13–15`, `:41–42` | Observes duel events/readiness; does not collect both fighters' correlated combat snapshots/pose traces | Both clients must prove own/remote authoritative identities and displayed action/contact/feedback. |
| no-hit checks; `:78–79` | Partial event assertions; seeded KO protection | Include every damaging path/resources; normal-input acceptance must use ordinary stats with no protection. |

The historical JSON genuinely has **zero** failed checks; this audit is not claiming that particular pass was fabricated. Its scope and permissive assertions cannot satisfy the complete stage. Its ping field alone also does not establish the requested measured RTT conditions; the report labels the run loopback/<1 ms.

After hardening, run Stage 4's full aim/geometry/guard/parry/exchange/dodge/air/identity/lifecycle/PvE-spell matrix, role reversals and network/frame conditions. Target supported measured local/50/100/150 ms RTT, with 200 ms beyond-envelope observation; unsupported jitter/loss/asymmetry stays NOT RUN. Preserve the <=100 ms eligible player-melee grace and documented no-grace boss/area limits. Partial transport delay is not full physics-network emulation.

### 5. Acceptance and evidence closure

Run W-12/Stage 5's ordinary-control duel and PvE transfer with actual human observations. OS-driven keys and server-cued defenses remain automation. Monk difficulty, contact-range changes, two-handed clips and camera comfort need those observations. Use physical-device and private-live evidence only when actually available/authorized; neither is supplied by desktop mocks.

The old `TEST_MATRIX.md` still contains initial NOT RUN rows below later passing tables; other contracts retain superseded planning prose. Reconcile them in the completion session and create the combat packet's missing final `ACCEPTANCE.md`. This audit preserves those historical records rather than rewriting them into passes.

## Later content batches: do not implement them twice

The 3 November Windows report says Batches 2–4 were not started **at that time**. The 5 November shared handoff supersedes that statement:

| Batch | Implementation | Remaining acceptance |
|---|---|---|
| 1 opening/Gao | Delivered; several Windows real-input paths on seeded milestones | Fresh earned opening, death/recovery/first upgrade, rejoin/devices as applicable. |
| 2 Iron Bull/Zhao | Supplied models, clips/gait, seeded both kill orders/retry and shared death/reset fixes | Ordinary-input fights, defenses/contact, guard/deathblow, camera/performance, repeated shared-boss cleanup. |
| 3 armour | Three suits, ownership/forge/reinforce/equip and contact-time protection | Two-client visuals/normalization, deferred-hit protection, earned acquisition, bodies/devices/save tests. |
| 4 Foundry route | Wing/altar/cache/barred shortcut, later mesh and interaction fixes | Earned traversal, two-client gate ownership/reset, retry/falls, rejoin/old saves, performance and human readability. |

Read their current results through `outputs/mac-followup-2026-11-02/HANDOFF.md` and `outputs/foundry-kit-2026-11-05/RESULTS.md`. Armour changes `CombatRules`, `CharacterService` and contact snapshots; later boss changes touch shared animation/death paths. The earlier multiplayer pass cannot certify these revisions.

**Shen is still in progress.** Existing forms/64 published clips have a seeded single-client integration result. However, `grip-pilot-2026-11-06.md` says the 11-clip pilot is unpublished, its final re-export was interrupted and staged files may mix wrist-solver versions. Phase 2/remaining clips, death/reveal/warnings/readability still need work; the cloth patch was reverted after a failing rest-drift check. Finish/review/publish the pilot and validate it before treating the boss's final motion/attack extents as stable. Do not discard his current work or restart his model.

## What to run next, and on which computer

| Work | Mac | Windows | Dependency |
|---|---|---|---|
| C00 survey, all nine supplied asset files, exact libraries/rig/camera measurements | **Start now** | Optional | Preserve current boss work; model creation is not import/rig/runtime acceptance. |
| AR00 site plan and reversible scale prototypes | **After C00 measurements** | Heavy comparison runs if needed | Use actual boss bounds; mark provisional rigs/attack extents. No blind in-place enlargement. |
| Remaining Stage 3 authoring/code repairs, reference-source evidence, Shen pilot preparation | Suitable | Suitable | One owner of shared files/relay branch; separate asset preparation can proceed independently. |
| 03B: close Stage 3 runtime, Stage 4, available Stage 5 | Preparation only | **Resume here** | New current build and measured conditions. Do not rerun 1–2 as a new implementation project. |
| Four-batch integrated acceptance | Prepare assets/checklists | **After combat revalidation** | Existing `WINDOWS_ALL_FOUR_ACCEPTANCE.md`; batches are already implemented. |
| C01–06 / AR01–06 production | Suitable for authoring/bounded previews | Heavy import/profiling checks | C00/AR00 output and the relevant stable boss; keep a baseline checkpoint. |
| C07 final integrated acceptance | Preparation only | **Last** | All selected environment/arena changes + final integrated bosses; repeat affected combat/lifecycle/performance checks. |

For the cleanest comparison, capture the remaining combat baseline before major world changes. That does **not** block C00 or reversible AR00 planning now. If art and combat work overlap, separate branches/worktrees and place copies, with one integration owner; do not let two writers modify the same shared checkout/place concurrently. Later environment changes require affected regression/Studio checks again even if the old scene was accepted.

Next dispatch: [RESUME_WINDOWS.md](RESUME_WINDOWS.md), alongside the existing 03B prompt. Mac can run C00 independently within those ownership rules.

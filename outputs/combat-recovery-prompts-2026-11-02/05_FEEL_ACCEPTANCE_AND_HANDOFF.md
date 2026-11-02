# STAGE 5 — ordinary input, feel acceptance and final handoff

Apply the master. Finish the implementation and verification work already authorized. Do not convert an unfinished technical task into a request for the user to discover basic bugs.

## A. Ordinary-input acceptance

After seeded diagnostics pass, perform a short duel through normal production controls, in the two genuine clients. Real mouse/key/gamepad/touch input must traverse the actual input controller, aim selection, buffer/sender, prediction and server validation. Label OS-driven automated input as automated real input, not a human playtest. A direct `ActionIntent` call is not equivalent.

Use normal health, damage, stamina and injuries. Temporary KO protection, forced stats, scripted reactions or teleports may be useful diagnostics but cannot establish ordinary combat fairness. Do not accidentally test a different build or hidden QA overrides.

If only one operator is available, prepare both clients and a repeatable two-person script. Give exact controls from the current `InputMap`, roles and locations; do not use stale generic bindings. Leave human fairness open until an actual human review occurs. Continue all independent engineering checks while waiting or handing off.

Suggested 10–15 minute human protocol:

1. **Response and spacing:** each player attacks from standing, movement and sprint; circles locked/unlocked; approaches/leaves range; changes direction and targets. Note delayed starts, sticky commands, root snaps, sliding feet and invisible hits.
2. **Defense exchange:** alternate predictable singles, short strings and pauses. Test early/on-time/late parry, held guard, release/re-press, feints, whiff punish and each directional dodge. Assess whether the visible moment reliably teaches the accepted timing, and whether a successful defense produces a readable opportunity.
3. **Pressure and commitment:** intentionally take the first light of a string, then attempt the documented defensive answer. Test intended true combos and escape gaps, stamina/posture break, injuries and recovery. Determine whether mistakes are understandable rather than merely survivable.
4. **PvE transfer:** fight one monk, one swordsman, a mixed ordinary pair, a humanoid boss and a large/boss-duo case. Check standoff, attacks taking turns, telegraph/readability, reactions and camera behavior during moving combat.
5. **Lifecycle:** lose lock, kill a target, die, respawn, rematch and disconnect/rejoin the local session as supported. Look for stuck guard, frozen tracks, duplicated FX, lingering constraints and stale HUD/target state.

Repeat representative observations under a supported measured latency condition. Record each human's actual observations, conditions and unresolved issues; do not replace them with a bot win rate. Keyboard/mouse, gamepad and touch hardware are separate acceptance categories. Emulation proves only what it exercises.

## B. Evaluate cohesive feel

Compare baseline and final footage at normal speed using similar equipment, stats, camera, scene and frame/network conditions. Evaluate together:

- Input response without misleading predicted outcomes.
- Readable anticipation, acceleration, contact, follow-through and recovery.
- Connected combo/defense transitions with correctly timed feet and root movement.
- Consistent parry learning, explicit punish windows and intentional true combos.
- Blade/trace/trail alignment and contact reactions from both players' views.
- Camera readability during circling and groups; no excessive shake/FOV or overlapping callouts masking contact.
- Stable performance and accessibility settings, including reduced effects/motion/flashes.

Fix material engineering regressions, then rerun affected checks. Do not endlessly broaden tests after all relevant checks pass, and do not pursue cosmetic polish while mandatory timing/network defects remain.

## C. Regression and production-build verification

Run the project's relevant simulation, contact, weapons/spells, boss, movement, animation/presentation, protocol/codec and lifecycle tests, then the required full verifier/build protocol. Include regressions for every confirmed defect fixed. If tools/platform/assets are unavailable, record the exact blocker; historical green logs do not count as a new pass.

Rebuild canonical place outputs when game source/assets/mappings changed. Verify the final place and running Studio source correspond to the final source revision/digest. Confirm temporary harness scripts/remotes, debug arc holds, latency adapters, forced stats and protection are absent from the production build. Preserve intentional reusable unmapped QA tools.

Check no accidental changes to player schema/data, rewards, ranked gating, campaign traversal, boss encounter ownership or respawn/fall safeguards. Performance acceptance must include the real world, not only the isolated test arena.

Cross-server matchmaking, live persistence and live ranked are separate. Run them only in an already authorized private environment with appropriate boundaries; otherwise mark NOT RUN. Do not enable ranked/live release flags, open public access or alter production data to manufacture acceptance.

## D. Deliver reviewable artifacts

Finalize `STATUS.md`, `BASELINE.md`, `RESEARCH.md`, `INTEGRATION_MAP.md`, `TIMING_CONTRACT.md`, `ANIMATION_COVERAGE.md`, `TEST_MATRIX.md` and `ACCEPTANCE.md`, with links to machine-readable results/logs and both-client evidence.

The integration map must include each selected upstream URL, pinned SHA, exact source file/symbol, license/asset restrictions, what was copied/adapted or independently implemented, local destination, notices and evidence of the running behavior. Explicitly list rejected/deferred repos and reasons. No claim of integration for an unused vendored file or a README link.

The acceptance table must separate:

| Gate | Required proof |
|---|---|
| Engineering correctness | Behavioral regressions and relevant runtime checks |
| Two-client boot | Distinct players on one real server, both receiving matching authoritative identities |
| Multiplayer outcomes | Full expected/actual results under measured supported conditions |
| Presentation coherence | Both-client timing/contact/track evidence and comparable footage |
| Human fairness/feel | Actual ordinary-input observations; otherwise explicitly pending |
| Hardware/performance | Named physical devices and measured conditions; emulation separately labeled |
| Production hygiene | Final source/build identity and removed QA injections |
| Live services | Separate authorized live evidence or NOT RUN |

Follow the repository's authorized handoff/commit/push rules, preserving unrelated changes and honoring approval restrictions. Append at most 60 words to `PROJECT_STATE.md` describing completed work and next steps. Do not stash or discard someone else's work to get a clean status.

Final response: state the concrete outcome first, then the key measured improvements, upstream techniques actually integrated, verification performed, remaining blockers and exact next human test if needed. Do not call the game fixed, fluid, accepted or launch-ready solely because a bot won, an asset loaded, a screenshot looked good or offline tests passed.

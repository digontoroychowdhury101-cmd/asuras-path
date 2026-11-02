# STAGE 1 — baseline, source research and implementation specification

Apply `MASTER_PROMPT.md`. Execute this stage, write its artifacts, and continue to Stage 2 when running the full task. Do not change combat balance before obtaining a reproducible baseline.

## A. Establish the real baseline

1. Read the master file list in order. Record branch, HEAD, working-tree ownership, build digest/source provenance, Studio version, OS, available tooling and supported multiplayer launch methods. Recheck recent living-state entries, including mob gait/group turns and observer catch-up follow-up.
2. Inspect the existing OmniPvP harness before modifying it. Document what it does and does not prove. It uses seeded placement, direct production-remote commands and server-cued defenses, not normal player input. Its ready message is not proof of received authoritative state. Its `result.passed = ok` only describes whether `xpcall` raised; failed checks are counted separately. Some no-hit checks omit outcome kinds. Dodge accepts 2/3 and parry accepts 1/4. Identify reset, sequence ownership, asynchronous logging and cleanup weaknesses too.
3. Run relevant existing suites where supported. Separate a missing executable, shim limitation, existing failing test and actual runtime failure. Note that the omni suite's old “100 ms deflect” source-string assertion searched for `Deflect = 100,`, which can match input priority rather than the deflect duration. Replace misleading assertions with behavior/property checks in later stages.
4. Create a minimal controlled combat scene or isolated test location within the real game, using normal stats and known weapons. Keep existing full-world baselines as well. Do not globally delete environment/content or overwrite saved Studio work to get better performance.
5. Capture initial ordinary input and seeded cases: Jian attack/combo/heavy/guard/parry/dash; locked orbit, backward/sideways movement; one monk and one swordsman; two ordinary foes; one humanoid boss and one large/nonhumanoid boss. State which captures were actually possible.

## B. Measure the pipeline

Instrument without adding authority bypasses. Correlate each action/contact using stable IDs. Record, when available: input edge, local presentation start, remote send, server receipt, validation, buffer enqueue/consume/expiry, authoritative action start, commit, contact, outcome, snapshot sample/send/receive, feedback and visual-contact time. Use synchronized server-time estimates for cross-process comparisons and monotonic time only for local durations; record clock uncertainty.

Measure at least press-to-visible-response, press-to-server-start, snapshot age, contact-to-feedback delay, visible/server contact error, dash grant versus actual distance/start, local/server p50/p95/p99 frame/step time, dropped sim steps and active track counts. Do not infer all of these from a single average ping. Distinguish RTT, one-way delay and snapshot interval.

Build a defect ledger with reproduction, current code location, confidence, expected behavior, likely cause and a validation case for each master finding. Check whether already fixed before editing.

## C. Research and select integrations

Inspect the actual source of the master shortlist, pin SHAs and verify separate licenses for code, animation, datasets, art and bundled dependencies. Add focused candidates only if they solve a concrete remaining problem. Inspect official reference-game documentation/gameplay with honest access limits.

For each candidate record: relevant files/symbols, technique, fit to Roblox R15 and the current architecture, cost, asset requirements, licensing constraints, maintenance status and adopt/reject/defer decision. Do not count an engine's unrelated repository stars as evidence for a combat subsystem.

Select a coherent minimum set of adaptations: normally a transition/foot-contact technique, movement/grounding technique and attack/contact coordination technique. Do not force code reuse from every repo. Every selected integration needs an implementation destination, rationale and measurable acceptance case. At least the chosen applicable techniques must reach running game code in subsequent stages; a links-only research note does not fulfill the task.

## D. Specify before implementing

Write `TIMING_CONTRACT.md`: input lifetimes, authoritative/presentation clocks, action IDs, defense/contact timestamps, rewind/facing/i-frame policy, prediction acknowledgments, rejected-action reconciliation, animation phase mapping and hitstop ownership. Define contact identity for repeated pulses and the intended simultaneous-hit policy.

Define numerical acceptance targets before evaluating new results. Suggested starting targets, subject to measured platform limits: immediate legal local visual response within one rendered frame; ordinary visible/contact alignment within one 60 Hz tick in controlled tests; no unexplained action expiry or duplicate outcome in deterministic fixtures. Report observed errors and network uncertainty; do not declare these suggestions achieved without measurement.

Deliver `BASELINE.md`, `RESEARCH.md`, `INTEGRATION_MAP.md`, `TIMING_CONTRACT.md`, initial `TEST_MATRIX.md` and `STATUS.md`. A concise summary must identify the highest-impact confirmed defects and actual implementation choices, not just possible improvements.

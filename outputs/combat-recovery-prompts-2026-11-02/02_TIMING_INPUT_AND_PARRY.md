# STAGE 2 — shared timeline, responsive input and authoritative parry

Apply the master and Stage 1 artifacts. Implement the timing repair in the real game. Do not stop after editing constants or writing a design document.

## A. Correct input ownership and lifetime

- Separate the original press timestamp used for validated timing from server receipt/enqueue time and the legal executable buffer interval. Define when a press may wait, expire, be replaced, be cancelled or execute. Keep resource/state eligibility checked at execution.
- Reproduce and fix a valid command whose original timestamp is already older than the 100 ms queue window on arrival. Also prove very old/stale/future/forged timestamps cannot become fresh executable commands just by resetting queue age.
- Preserve input priority without starving valid lower-priority commands or executing multiple stale attacks from one user gesture. Review guard-down/guard-up ordering, menu/focus changes, feint-plus-deflect behavior and held inputs.
- Use explicit action sequence/occurrence IDs and terminal statuses. Diagnostics must distinguish queued, accepted, executed, superseded, expired and rejected. Avoid a permanent “Buffered” result with no final explanation.
- Review spells' separate input path. Support intentional boundary queuing consistently or clearly specify refusal; do not introduce accidental ability cancellation or alter cast costs/cooldowns to conceal missed presses.

## B. Establish an explicit replicated timeline

- Replicate authoritative sample/action timing and stable action identities, rather than assuming snapshot receipt equals server sample time. Define and version codec changes. Update all packet sizes, consumers and tests together; handle incompatible/stale records safely within the actual deployment model.
- Correctly reconstruct Startup/Active/Recovery after network transit and skipped updates. Repeated identical moves must be distinguishable even if Idle/Startup was not observed. Handle streaming in halfway through a move, character replacement, weapon swap and entity removal.
- Implement immediate bounded local presentation prediction for legal attacks/guard/dodge where useful, using shared rules. Keep prediction separate from authoritative snapshots and reconcile by action identity. Accepted actions must not restart; rejected ones must blend out/return coherently. Never predict damage, successful parry or rewards as confirmed outcomes.
- Repair the delay between dash input and displacement where feasible. There must be one local movement executor and authoritative validation/bounds. Do not double-apply the grant on acknowledgment or grant client-controlled i-frames. Test walls, slopes, interrupted dash, low FPS and rejection.
- Remote windups need explicit server-authored start/impact information as early as possible. Do not claim prediction can recreate warning time already lost in transit. Define the supported latency/readability envelope and a bounded late-arrival policy.

## C. Make defense and contact temporally consistent

- Decide which instant is used for strike geometry, defender position, facing, guard, i-frames and deflect eligibility. Evaluate the current attacker rewind/current defender-state mixture. Preserve bounded rewind and anti-forgery validation.
- A late timestamp alone cannot reverse damage already applied. Implement and test the chosen bounded late-defense policy, or explicitly document the remaining latency limit. If introducing a short resolution grace/deferred outcome, quantify added impact delay and ordering interactions. Do not add unrestricted rollback, broad forgiveness or arbitrary retroactive parries.
- Fix closing-window/boss-listener/intent-consumption boundary ordering where needed. Run contacts at opening, middle and closing ticks and presses exactly around each boundary. Test both player IDs, join orders, NPC/player roles and simultaneous inputs; specify intended trades versus interruption.
- Define one-press/contact behavior, parry success/miss recovery, success re-arm, spam decay, head injury, held guard and front/rear eligibility. Ordinary deflect and boss perilous-thrust rules currently differ; retain intentional differences and document them.
- Reassess Jian light hitstun versus follow-up spacing. Enumerate true combo routes, defensive answers and whiff punish windows. Preserve meaningful commitment. Make any timing adjustments based on evidence and record before/after values rather than simply shortening every recovery.

## D. Verification gate

Add focused behavioral regressions using actual simulation and extracted/runtime server paths where supported: delayed arrival versus expiry; old/future timestamp refusal; action acknowledgment and stale state; guard release; hitstop-independent timing; rejected prediction; dash acknowledgment deduplication; repeated same move; contact identity; opening/closing defensive boundaries; simultaneous attacks; multi-pulse defense; injury/spam changes; death/respawn flush.

Use controlled fixtures with full expected outcomes. A parry test must assert no HP loss, correct posture/Qi/event changes and no duplicate damage as well as a spark. A miss must reject all damaging outcome paths, not just `Hit`. Avoid tests that only search for a source string or repeat the implementation formula.

Run relevant suites, then Studio timing probes. Save before/after distributions and representative traces. Update the timing contract and integration map. Do not mark multiplayer verified until Stage 4 actually runs two genuine clients. Do not mark the full combat task complete while animation/footwork remains outstanding.

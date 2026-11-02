# STAGE 4 — genuine two-client multiplayer verification

Apply the master and completed implementation artifacts. This stage extends the original multiplayer request. Inspect the current harness and historical `OMNI_COMBAT.md` before changing or running it.

## CHECKPOINT A — real multiplayer boot and provenance

Start the currently supported Studio local server with **two actual client processes/sessions** attached to that same server. Verify the launch API/tool against the installed Studio version; do not blindly assume the historical `StudioTestService` command remains supported.

Record OS, machine/GPU context, Studio version, launch method, server/session identity, client identities/UserIds, test build/HEAD/digest, foreground/background focus, graphics settings, measured client frame-time distributions and server step/dropped-step counts. Distinct NPCs, two solo servers or mocked players do not satisfy this checkpoint.

Both clients must report actual authoritative state for themselves and the other player, not merely `AsuraClientReady`. Correlate a known server action/state identity and timestamp observed by both clients. Confirm no production script errors, duplicate animation tracks or stale entity bindings. Preserve normal account/mock-data boundaries and private test scope.

If this host cannot boot both clients, record the exact attempts and failure. Prepare a runnable harness and precise supported alternate-host instructions; continue independent work. Leave this checkpoint BLOCKED, not PASS.

## CHECKPOINT B — repair the harness before trusting its result

- Top-level success must require successful execution **and zero failed mandatory checks**. Errors, missing clients, missing evidence and timeouts must not become passes. Add a fixture proving a deliberately failing check makes the aggregate result fail, without leaving deliberate failures in the normal run.
- Use isolated scenarios with complete resets and explicit preconditions: fighter state/move, resources/injuries, guard/sprint, input queue, history, action IDs, prediction/ack state, dash state and temporary protection. Wait for placement/pose-history stabilization. Do not reset only health while leaving a previous action live.
- Avoid bypassing the logic under test. Seed placement/resources for labeled diagnostics, but run actions through real client remotes. Keep a separate normal-input path through the production input controller. Do not manipulate production `LastSeq` to race the controller's own sender or create two competing sequence owners.
- Replace “at least one parry out of four” with deterministic timing fixtures whose expected result is defined per attempt. In randomized jitter tests, specify seed, distribution, sample count and expected policy before running; report every failure and distribution rather than cherry-picking favorable runs.
- A no-hit assertion must include all damaging outcomes, HP layers and unintended state/resource changes, including `CounterHit`, `Armored`, KO and applicable spell/pulse paths. A deflect assertion must include correct damage negation, posture/Qi/event changes, action identity and no duplicate outcome.
- Collect per-case evidence from both clients: own/remote authoritative IDs, displayed action/phase, playback speed, visible contact/reaction and state/resource results. A server attribute existing does not prove the second client saw it correctly.
- Retain errors/timeouts and failed captures. Use structured case IDs, expected/actual, timings, conditions and evidence paths. Include cleanup and restoration after failures/disconnects.

## CHECKPOINT C — authoritative combat matrix

Run both actor roles and relevant join/ID orders. Use full expected outcomes, not merely “some event occurred.”

| Area | Required cases |
|---|---|
| Aim/turn | Unlocked 360° attacks; move/camera/locked aim; early windup tracking; commit boundary; late sidestep; direction reversal; client spin after commit; recovery turning |
| Geometry | Thrust and slash; near/mid/max reach and just beyond; lateral/rear misses; moving attacker/defender; scales; slopes/height differences; translation during active frames |
| Guard | Front, side boundary and rear; press/release; blockstun; guard break; guard held through state expiry; guarding must not snap to a rear attacker |
| Parry | Early/on-time/late around exact boundaries; opening/closing sweep tick; delayed arrival; rejected/stale/future inputs; spam/head injury; success re-arm; two distinct incoming contacts; multi-pulse attacks |
| Exchanges | Simultaneous attacks; startup interruption; intended trade policy; armor; true combo routes versus defensive opportunities; whiff punish; combo guard/dodge/feint cancels |
| Dodge | Forward/back/both sides/diagonals and neutral backstep; start displacement versus i-frames; collision/distance cap; spam decay; interrupted/rejected prediction; acknowledgment deduplication |
| Air | First/second light; heavy/art/running restrictions; first/second dodge; landing recovery; stun/death while landing; allowed aerial-defense policy |
| Identity | One outcome per target/contact; intentional pulses distinct; repeated same move without observed neutral; late/duplicate/stale snapshots; no double animation/feedback after reconciliation |
| Lifecycle | Target loss, range/LOS lock loss, target switch, weapon swap, death/deathblow, respawn, rematch, entity removal, disconnect and cleanup |
| PvE/boss/spell | Recent mob group turns/standoff; no shoving; boss commit/pulses/cancellation; large body; duo coordination; spell interruption/queued boundary/cooldowns; no cross-encounter damage |

At least Jian, a wide-sweep weapon and a slower/heavy family need networked contact cases; all playable families need the coverage/regression checks from Stage 3. Test the low-effects/reduced-motion presentation too.

## CHECKPOINT D — measured network and frame conditions

Use supported Studio/network emulation or a precisely documented bounded QA transport adapter. Never add production timestamp forgery or authority bypasses. Start with local baseline and target **50/100/150 ms measured RTT** scenarios where supported, plus **200 ms RTT** as a beyond-envelope observation; add jitter/asymmetry/packet loss only when the tool supports them. These are requested conditions, not assumed achievements. Name unsupported cases NOT RUN.

Record configured versus measured RTT, one-way assumptions, jitter, packet loss, snapshot age and clock error. Do not conflate the 150 ms rewind ceiling with a guaranteed supported RTT. If using an adapter, specify which input/snapshot/event paths it delays and whether Roblox physics replication remains undelayed; do not label partial simulation “full network emulation.”

Test 60 FPS baseline and controlled 30 FPS where available; inspect both attacker and defender under actual render throttling. Include server hitch/catch-up behavior and dropped-step reporting. Avoid changing OS graphics/drivers globally merely to obtain a pass.

For each condition compare accepted/expired/rejected actions, prediction corrections, parry results, visible/server contact error and dash timing. Keep low-delay success separate from high-delay limitations. Fix failures and rerun affected cases without deleting the initial evidence.

## CHECKPOINT E — clean exit

Save machine-readable server results, both-client traces and captures, test conditions and the exact tested source identity. Disconnect subscriptions, remove owned QA scripts/remotes/overrides, restore temporary stats/settings and stop owned test sessions. Inspect canonical project mappings/build to prove no harness injection shipped. Do not delete unrelated QA tools or overwrite another session's Studio work.

Mark this stage complete only when two real clients ran the required supported cases with interpretable results. Separate blockers and remaining human/device/live acceptance. Continue to Stage 5.

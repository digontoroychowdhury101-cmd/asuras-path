# Investigate performance

Read [performance](../references/performance.md) for relevant measurement tools.

1. Define the scenario, client/server side, device, player/entity count,
   update rates, duration, symptom, and target.
2. Reproduce and capture frame-time distribution, CPU/GPU/physics/network
   evidence and memory trends as applicable. Use exposed Studio capabilities
   for instrumentation/logs; ordinary Luau cannot enumerate all connections.
   Without runtime access, request relevant captures and label hypotheses.
3. Rank costs from evidence rather than a fixed category ordering. Propose
   the smallest targeted fix; use pooling/ECS only for a demonstrated need.
4. Within authorized scope, change one factor and rerun a comparable workload.
   Record before/after and correctness checks; retain a rollback.
5. Stop at the agreed target or bounded investigation budget. If measurement
   is unavailable or results inconclusive, report the gap and next experiment.

Output scenario/environment, measurements, supported causes, changes, and
remaining uncertainty. Expected impact is an estimate, not a measured speedup.
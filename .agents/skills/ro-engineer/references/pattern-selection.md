# Pattern selection

Start with current architecture, interfaces, team knowledge, and installed
libraries. Extend a working system before introducing a second one. Compare
functional needs, lifetimes, update rates, target-device budgets, maintenance,
migration, and tests for significant choices.

| Candidate | Evidence that favors it | Costs to check |
|---|---|---|
| Plain functions/module or typed data | Local logic with a clear owner | Avoid duplicating existing behavior |
| OOP | Independent stateful lifetimes tied to Models, vehicles, sessions | Metatable typing, cleanup, callback ownership |
| Composition | Repeated independent behavior combinations | Wiring and ownership; components need not be classes |
| ECS | Existing ECS project, bulk queries/scheduling needs, or representative benchmark supports migration | Structural changes, debugging, library APIs, replication, team cost |
| State store | Multiple consumers need coordinated updates/subscriptions | Notification cost, duplicate truth, snapshot/resync |
| Pooling | Profiling identifies material allocation/destruction cost | Reset correctness, retained memory, peak demand, exhaustion |

Choices can combine. Entity count is an input, not an adoption threshold.
ECS is not inherently faster than OOP; frequent spawning alone does not
justify a pool. An existing ECS project may reasonably keep ECS for a small
addition to avoid a second architecture.

For a substantial decision, give fit, key trade-offs, and why plausible
alternatives lose. Define migration boundaries and rollback for architectural
changes. A small fix simply preserves the existing pattern.
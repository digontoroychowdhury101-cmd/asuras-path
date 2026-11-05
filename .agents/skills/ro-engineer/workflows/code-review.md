# Review Roblox code

Read affected scripts and relevant callers/configuration. Use exposed
dependency/validation tools when helpful. Inspect these risks where applicable:

| Area | Evidence to inspect |
|---|---|
| Security | Runtime payload validation, server pricing/grants, legal state, rate limits |
| Persistence | Atomic mutations, durable/idempotent receipts, retries, session ownership, migration |
| Lifecycle | Resource ownership, external connections, delayed callbacks, player/character/stream-out teardown |
| Integration | Existing API contracts, require/startup order, replication snapshots/resync |
| Types/APIs | Configured checker results, unsafe casts, optional Instances, supported engine APIs |
| Architecture | Fit with project and workload; unnecessary new abstractions |
| Performance | Actual hot paths/profile; unbounded work or retention |

Do not flag pairs/ipairs, module return shape, inheritance depth, or a missing
new framework merely for style. Report actionable findings by severity with
location, failure scenario, consequence, and a specific fix. Distinguish
observed failures from hypotheses. Grades and rewritten code are optional when
requested/useful; a review does not claim runtime success.
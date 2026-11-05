# Reproducible skill benchmark plan

This is a plan, not measured model-performance evidence. Fewer instruction
bytes do not establish better answers or lower end-to-end token cost.

Compare A (no skill), B (v1.0.0 at c818877), C (candidate v1.0.1) using the same
model/version/settings, tools/permissions, project snapshot, task prompt, and
time/tool budget. Start fresh sessions and isolated fixture copies; randomize
condition order. Run at least three trials per condition when practical.

| Task | Fixture / observable acceptance |
|---|---|
| Projectile | Existing weapon API; correct hit/timeout/owner-leave cleanup and server damage validation |
| Inventory | Existing schema/services; capacity/stack/equip behavior, concurrent mutation tests |
| Remote security | Seed invalid type/range/NaN/inf, unauthorized ownership, flood and replay defects; identify each without inventing findings |
| Module refactor | Existing callers/tests; identical interface/behavior, no unrelated rewrite |
| Performance diagnosis | Reproducible workload and trace; locate measured cause and compare before/after under equal fidelity |
| Persistence integration | Fake store with retries/failures/session conflict; no duplication/lost grants; migration tests |
| Architecture choice | Both existing ECS and plain-module projects; preserve suitable architecture with justified trade-offs |
| Component integration | Versioned library docs and callers; correct API, dependencies, cleanup, no duplicate subsystem |

Commit fixture snapshots, prompts, expected behaviors and runnable checks before
trials. Keep acceptance private to evaluators. Never use production saves or
publish places. Record model/client/tool versions, condition, trial, artifacts,
test results, security defects, integration errors, unnecessary abstractions,
actual input/output tokens, tool calls, elapsed time, and human corrections.
Use null/unavailable for absent usage telemetry; bytes/4 is not measured tokens.

Report pass rates and distributions across trials, with failure examples and
reviewer judgments separate from measurements. Compare total tokens including
references and tool outputs, not only entrypoint size. Repeat the same fixtures
across Claude/Codex/ChatGPT only where equivalent capabilities can be provided;
separate host limitations from skill effects.

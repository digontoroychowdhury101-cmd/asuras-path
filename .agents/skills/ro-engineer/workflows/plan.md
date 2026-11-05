# Plan substantial work

Use when the user asks for a plan or the change benefits from coordination.
A trivial fix can go directly to implementation.

Inspect relevant hierarchy, code, callers, remotes, persistence, state, and
lifecycle. Identify reuse and distinguish inspected facts from assumptions.
If access is missing, ask only for context material to the decision.

Describe ordered tasks with affected files/instances, dependencies, and
observable verification. Include relevant risks: trust boundaries, replication,
target-device cost, resource lifetime, data migration, or economy/policy.
Use [system design](design-system.md) for unresolved architecture; use
[loop design](design-game-loop.md) only when player behavior is being designed.
The [plan template](../templates/plan-template.md) is optional.

A plan-only request ends with the plan and material open questions. When the
user authorized implementation, continue after planning without inserting an
extra approval gate. Actions beyond that authorization still need permission.
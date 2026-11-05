# ECS decisions and integration

Check [pattern selection](pattern-selection.md) before introducing ECS. Existing
ECS architecture, repeated bulk queries, clear scheduling needs, or measured
hot-loop gains can justify it. Counts alone cannot. Include migration,
debugging, and team familiarity.

Use installed library docs and versions. Jecs and Matter are examples, not
guaranteed recommendations; verify APIs and maintenance before adoption. Avoid
building a new ECS engine as a side effect of gameplay work.

- Define ordering (input, AI, movement, damage, cleanup, instance sync) and
  appropriate RunService phases. Keep synchronous updates bounded; give slower
  AI a deliberate rate/budget.
- Follow query-mutation guarantees of the actual library. If mutation invalidates
  iteration, defer structural changes to a defined command-buffer boundary.
- Layout follows real access patterns. Archetypes and sparse sets have different
  query/mutation costs; neither is universally fastest.
- Own Instance links, ids, connections, and despawn paths. ECS data does not
  replicate itself. Use snapshots/changes for required state, or events for
  local cosmetics; gameplay remains server-authoritative.
- Batch Instance updates when measured benefit supports it (`BulkMoveTo` for
  suitable BaseParts). Pool render objects only when justified.

Benchmark equivalent behavior/counts/update rates, physics, rendering, and
replication on target hardware. Record frame-time distribution, memory, and
integration complexity; use MicroProfiler labels around systems. Do not credit
ECS for gains caused by reducing gameplay fidelity or removing physics.
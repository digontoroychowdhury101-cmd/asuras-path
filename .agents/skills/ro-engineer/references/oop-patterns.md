# OOP in Roblox projects

Use objects when independent identity, state, and lifetime fit the project.
A utility or server-lifetime service does not need a class. Preserve existing
constructors, naming, and caller contracts.

- Metatable objects commonly use `Class.__index = Class`. Type instance data
  and methods using the configured checker; explicit self annotations can help
  inference but are not a universal style requirement.
- Field prefixes are conventions, not access control. Define who mutates state.
- Document yielding construction; avoid yielding require cycles or exposing
  partly initialized objects to callbacks.
- Resource-owning objects need a teardown contract compatible with existing
  cleanup helpers. Make repeated cleanup safe, end subscriptions/delayed work,
  and guard late callbacks. Do not destroy caller-owned Models without an
  explicit ownership transfer.
- Prefer components when behavior combinations cause duplicated overrides or
  irrelevant base fields. Do not replace working inheritance solely for depth.

See [composition](composition.md) for tag/streaming and hybrid boundaries,
and [cleanup](cleanup-lifecycle.md) for resource semantics. Reuse the project's
signal implementation; a replacement needs an API, lifecycle, or measured benefit.
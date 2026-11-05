# Luau types at integration boundaries

Use inference for locals and explicit types for public APIs, config, persisted
schemas, and cross-system contracts. Match the configured Studio/luau-lsp
checker and installed library types; do not assume solver behavior from memory.

- Type untrusted payloads as `unknown`, then validate runtime type/shape,
  bounds, finite numbers, ownership, and state before use. Exported types and
  casts cannot validate remotes or stored data.
- `typeof` recognizes engine types; `IsA` narrows Instances. Narrow optional
  lookups before access. A cast to Model is not an IsA check.
- Separate persisted plain-data schemas from live Instance/object types.
  Validate and migrate saves at the boundary.
- Export reusable interface types where callers need them. Match existing
  constructor/metatable patterns rather than imposing a new class template.
- Model state/message variants as tagged unions when useful. Keep client
  request types separate from authoritative server state.
- Keep unavoidable `any` localized at an actual interop boundary; explain
  the lost guarantees. Do not hide errors with broad casts.
- Check inference and refinements with the actual checker. A type-check pass
  does not establish runtime security, engine availability, or replication.

Example numeric boundary (also apply domain-specific bounds/integrality):

```lua
local function isFiniteNumber(value: unknown): boolean
    return typeof(value) == "number"
        and value == value
        and math.abs(value) < math.huge
end
```

This boolean helper does not by itself promise cross-function type refinement.
Use explicit checks at the call site or supported refinement patterns.

Sources: [Luau type checking](https://luau.org/typecheck/),
[luau-lsp configuration](https://github.com/JohnnyMorganz/luau-lsp).
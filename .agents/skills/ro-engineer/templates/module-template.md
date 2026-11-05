# Optional ModuleScript starting point

Use the existing project's shape first. This plain function example needs no
class, cleanup helper, config dependency, or player subscription.

```lua
--!strict
local function clampCount(count: number, capacity: number): number
    return math.clamp(count, 0, capacity)
end

return clampCount
```

The return value need not be a table; preserve callers' expected interface.
Add typed public data, lifecycle, or configurable tuning only when needed.
For resource-owning objects see [OOP](../references/oop-patterns.md) and
[cleanup](../references/cleanup-lifecycle.md). The example assumes valid numeric
inputs; it is not a remote payload validator.
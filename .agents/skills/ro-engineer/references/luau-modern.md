# Luau conventions and engine behavior

Use the project's checker, formatter, module interfaces, and supported runtime.
Do not migrate unrelated code for style alone.

| Category | Guidance |
|---|---|
| Engine requirement | ModuleScripts return exactly one non-nil value; a function is valid. Require caches separately per environment, not shared state across client/server. Avoid yielding cyclic requires. |
| Type-checking convention | Prefer `--!strict` and typed public boundaries for new code. Preserve legacy file modes unless migration is in scope. |
| Syntax / style | Use scoped bindings. Generalized iteration is idiomatic; `pairs`/`ipairs` remain valid. `ipairs` stops at the first nil; do not change traversal semantics for style. |
| Scheduling | Prefer `task` APIs to legacy wait/spawn/delay. `task.spawn` resumes immediately; `task.defer` resumes at the end of the current resumption cycle, not necessarily next frame. |
| Project convention | Module return shape, names, init/start, config layout, and comments should fit the existing project. |
| Performance choice | Pools, buffers, table preallocation, batched updates, and Actors need workload evidence. |

Match RunService phases to work: render-only work is client-side; physics and
simulation updates need appropriate phases. Heartbeat is not a deprecated API
to replace mechanically. Prefer supported `Animator:LoadAnimation` over the
deprecated Humanoid method when touching animation loading.

Roblox-specific hazards:
- Streaming/replication order makes child lookups optional. Use bounded waits
  or nil handling; timeout is not proof content will never stream in.
- Keep untrusted inputs out of dynamic execution. `getfenv`/`setfenv` also
  inhibit optimizations; use explicit dependencies.
- Cancellation is not a substitute for lifetime checks on callbacks already
  executing. Own delayed work and guard effects after teardown.
- `table.freeze` is shallow; decide whether nested config is actually immutable.
- Parent new Instances after configuration when appropriate; do not rewrite
  unrelated creation sites as a mandatory performance fix.

Check version-sensitive APIs in current documentation rather than guessing new
keywords or assuming Studio, local tools, and live runtime features match.

Sources: [ModuleScript](https://create.roblox.com/docs/reference/engine/classes/ModuleScript),
[module return values](https://create.roblox.com/docs/scripting/module),
[Luau syntax](https://luau.org/syntax/),
[iteration performance](https://luau.org/performance/),
[task](https://create.roblox.com/docs/reference/engine/libraries/task),
[RunService](https://create.roblox.com/docs/reference/engine/classes/RunService).
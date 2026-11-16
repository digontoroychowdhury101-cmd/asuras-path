# 18 Perf budget instrumentation (Lane 3c, source only, no Studio)

## Files
- NEW src/server/Services/PerfBudget.luau (sampler, Boot(), budgets as data)
- NEW tools/test_perf_budget.luau (13 checks, plain luau)

## Reused (read-only)
Characters.GetPerformance() (entities, p95StepMs), OverworldService.Stats() (Total/Done/Failed). No Config debug-flag
pattern exists, so the gate is Studio or `ReplicatedStorage.AsurasPath.Perf` attribute Enabled=true.

## Measured (attributes on ReplicatedStorage.AsurasPath.Perf, every 5 s; log line every 30 s)
Mem_TerrainVoxels/PhysicsParts/Instances/Sounds/Gui (MB), HeartbeatHz, StepP95Ms, Entities, TerrainTotal/Done/Failed,
Instances_Map, Parts_<region> (descendant walk every 15 s).

## Budgets (PerfBudget.Budgets; warn once per key)
TerrainVoxels <= 200 MB, HeartbeatHz >= 55 (ticket); StepP95Ms <= 18.2 and PartsPerRegion <= 8000 provisional until first profile.

## WIRING FOR LEAD
default.project.json: none needed if `src/server/Services` is already mapped as a folder (file lands as Services/PerfBudget).
Bootstrap.server.luau, after OverworldWorld/Characters are started:
```lua
local PerfBudget = require(Services:WaitForChild("PerfBudget") :: ModuleScript) :: any
local perf = PerfBudget.Boot({ Characters = Characters, Overworld = OverworldWorld }) -- nil outside Studio
-- shutdown: if perf then perf:Stop() end
```

## Verify
luau.exe test_perf_budget: 13 passed. luau-compile --null OK. lune_compat --all: 0 FAIL. luau-analyze only flags Roblox globals in Boot.

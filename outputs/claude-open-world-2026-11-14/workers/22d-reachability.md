# 22d RG: retired-builder reachability test (source analysis only)

Supersedes: nothing. Searched before writing: Grep "22d|reachab|retired" over outputs/claude-open-world-2026-11-14 (only 19a-registry-fit.md and 10g-boss-fixes.md hold one-off manual greps of the same question; this file turns them into a repeatable test and does not replace their findings) and Glob tools/test_retired* (no match).
Linked from LEDGER.md: no. CONTINUATION.md:291 names this file; this lane may not edit LEDGER.md, so the lead must add the LEDGER entry.
Why new: C3 ruling 4 needs a mechanical proof (mapped modules and a require graph from the runtime roots), not a grep, and no earlier file computes the mapped-but-unreachable set.
Prompt: Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Request: write tools/test_retired_unreachable.py. Verifies the 12 retired builders are neither mapped in default.project.json nor reachable by require from any mapped Script/LocalScript, and lists mapped-but-unreachable modules.

## Progress
- Read default.project.json (no retired module is mapped now), Bootstrap requires, and require call shapes in src (script.Parent:WaitForChild, Services:WaitForChild, Shared.X, string paths, a few dynamic forms).

## Plan and file list (resumed run)
- Dynamic sites found: BossAppearance.luau:22 (require Shared:WaitForChild(source), source from literal table LooksDuelists/LooksBeasts/LooksSovereigns), ArsenalFacts.luau:12 (root[name]/Simulation[name], names are literal load("X") args). No ModuleScript enumeration (no IsA("ModuleScript")/GetDescendants requires). WorldDefinitions mentions MonasterySurvey in a comment only. SliceDressing.luau:227 pcall-requires SliceKitRegistry, which is not on disk (harmless, pcall).
- Files: (1) NEW tools/test_retired_unreachable.py; (2) EDIT tools/test_monastery_route.luau hygiene block only (lines 244-255; it reads retired MonasteryService/Bounds/Grounds/Terrain sources, asserts not mapped; add nothing that maps them).
- Method: parse project json to instance paths; strip comments; balanced-paren require scan; resolve leaf name by mapped instance name, disambiguating duplicates (RouteGates) by parent token; files with dynamic requires get edges to mapped names appearing as string literals; roots = *.server/*.client mapped scripts.
- checkpoint: plan appended
- checkpoint: wrote tools/test_retired_unreachable.py, running
- checkpoint: fixed parser for (require :: any)(...) (CampaignZones.load); run: 284 mapped, 271 reachable, 13 mapped-but-unreachable, retired 12 pass.
- checkpoint: edited tools/test_monastery_route.luau hygiene block (added 12-name not-mapped loop after line 255). Lune not run (lane scope).

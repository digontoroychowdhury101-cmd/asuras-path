# 22c biome builder (lane D4, source only)

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Header facts for this new file:
- Supersedes: nothing. Searched outputs/claude-open-world-2026-11-14 (Glob workers/22*, Grep "22c-biome"): only 22a, 22b, 22d, 22e exist, none cover the biome builder.
- Linked from LEDGER.md: yes, line 309 ("D4 biome builder", this path), and CONTINUATION.md line 290.
- Why a new file: the run rule requires a per-worker plan plus resume checkpoints before any source edit.

## Files (only these)
- EDIT src/shared/BiomeDressing.luau (placement data and pure planner)
- NEW  src/server/Services/BiomeDressingService.luau (Instance builder, lazy per region, time-sliced)
- EDIT tools/test_biome_dressing.luau
- This file. Nothing else (no default.project.json, no Bootstrap, no SliceDressing*, no git).

## Finding at start (baseline red)
tools/test_biome_dressing.luau fails to load: another lane's SliceDressing.Pieces now holds 5 pieces BiomeDressing also defines
(Ravine_Aqueduct_Arch, Snow_Watch_Beacon, Basin_Gate_Statue, Summit_Temple_Pagoda, Summit_Temple_Wing) and BiomeDressing asserts no clash.
SliceDressing.Classes also grew to 13 entries, but BiomeDressing iterates Classes with 5 scatter rules.

## Plan (each step leaves the test green)
1. BiomeDressing: own Classes list (5); shared pieces adopt the Slice definition (uploaded manifest is truth) instead of asserting. Test: allow shared names, sizes must match Slice. -> baseline green.
2. BiomeDressing: build(id, fresh, tick) optional yield hook (no behaviour change).
3. BiomeDressing: new pure API, additive (build() output unchanged):
   - Archetype + Silhouette data per piece (bbox + 1-4 rough primitives as fractions; mesh swap = data only), Tier Large/Medium/Small by max dimension.
   - PartBudget per region (number stated in code), Reach per tier, visibleAt(pl, dist) thinning.
   - noise mask (value noise) clustering; SetKits + Sites (altars, landmarks, surface POIs) with a composed set piece per site (1 Large, 2 Medium, 3+ Small).
   - plan(id, fresh, tick): build + arena/mask filter + set pieces + trim to PartBudget; deterministic.
4. BiomeDressingService: Start/Destroy/Stats; region activation by player proximity; Overworld Ready/SiteReady + Terrain.Manifest gating; ground raycast; registry -> Assets -> placeholder; distance thinning with hysteresis; per-part budget refusal; 2.5 ms time slice.
5. Test extension: budget per region, no placement on roads / arena pads / encounter spots, set piece per site, three tiers, determinism, silhouette validity, thinning, clustering.
6. Compile-check service with luau-compile --null; run test; report mapping and Bootstrap lines.

## Checkpoints (append one line per completed edit or test run)
- [start] baseline test red (shared-piece assert); plan written; no source touched yet.
- [step1] BiomeDressing: own Classes, shared pieces adopt Slice def; test shared-piece check relaxed. test_biome_dressing 13836 passed, 0 failed (plain luau, ~62 s; build 2-11 s per biome => tick hook needed).
- [step2-3] BiomeDressing: build(id,fresh,tick) hook; additive planner (PartBudget 1800, tiers, silhouettes, Assets, SetKits, sites, mask, visibleAt, plan). Not yet run.
- [step3] planner runs: sites 4/10/9/12 (Ravine/Basin/Snow/Mountain), every site Large>=1 Medium>=2 Small>=3, parts 1073-1562 before trim; PartBudget set to 1500 per region. Sites = surface route nodes + landmarks + surface POIs. luau-compile ok.
- [step4] NEW src/server/Services/BiomeDressingService.luau written (Start/Stats/Destroy, lazy region, 2.5 ms pace, thinning+hysteresis, budget refusal, registry->Assets->silhouette placeholder); luau-compile --null ok (analyze has no Roblox globals). Not run in Studio.
- [step5] test_biome_dressing.luau planner section added (about to run).
- [step5] test_biome_dressing plain luau: 18181 passed, 0 failed (~80 s). Next: lune_compat single-file, cleanup scratch tools/_tmp_*.luau, report.
- [done] all three files compile; test green; scratch removed. Lead lines: map BiomeDressing (shared) and BiomeDressingService (Services); Start after OverworldWorld.Start, Destroy in teardown.

## D5 (lane D5, source only: real Amberfall + Saltreach kit pieces into BiomeDressing)

Files (only these): EDIT src/shared/BiomeDressing.luau; EDIT tools/test_biome_dressing.luau; this note. No SliceDressing*, no BiomeDressingService (unless a bug blocks, then noted), no default.project.json, no Bootstrap, no git, no uploads.

Plan (each step leaves the test green):
1. Read both upload_manifest.json files, SliceDressing KIT/RECIPES pattern and the rest of BiomeDressing (planner, silhouettes, SetKits, Assets).
2. BiomeDressing: add AMBERFALL and SALTREACH KIT rows (bbox from manifest, within +-5%) with sub-mesh names equal to the registry keys, plus rough silhouette specs; pieces already shared with the slice (Amber_Aqueduct_Hero reuses Ravine_Aqueduct_Arch slots; Saltreach_Gate_Statue replaces Basin_Gate_Statue) follow the manifest. Test: kit-slot count bounds widened.
3. Ravine and Basin Scatter tiers + SetKits + set pieces draw from the real kit pieces (trees, deadwood, shrubs, grass, rocks, cliffs; built pieces in set kits). Old placeholder-only pieces stay only where still used (heroes), 1500-part budget, three scales, clustering and exclusions unchanged.
4. Frostmere and Ashen Stair untouched, with a TODO slot where their kits plug in.
5. Test: every manifest piece has a spec matching bbox +-5% and sub-mesh names; Ravine/Basin set kits use kit pieces; budget holds.
6. Run lune_compat single file; luau-compile --null; report counts and parts per region.

Checkpoints:
- [D5 start] plan written; no source touched yet.
- [D5 step1] manifests read (Amberfall 45, Saltreach 37, sub tri cap 18000, all subs under it); design: KIT rows {name, fam, arch, X, Y up, Z, "Sub:tris"} in BiomeDressing, hero slots alias via BiomeDressing.Slots (P[slot] = P[hero], def.Key = hero name for registry keys), set picks cycle through the kit, mass pieces get footprint-aware road/keep clearance. Service gets a 3-line def.Key edit (registry key). Source rows generated to scratchpad.
- [D5 step2-3] BiomeDressing: KIT rows (82 pieces) + looks + Slots alias + Ravine/Basin scatter + SetKits cycling + massHostile + Registry modules; service def.Key edit; compile ok; test not yet updated/run.
- [D5 step4] test extended (manifest rows for both kits, bbox/subs/tris/silhouette, hero slots, per-biome 80% kit use, built pieces in sets, old pieces gone); compile ok; first run next.
- [D5 step5] test_biome_dressing plain luau (work/bin/luau/luau.exe): 19179 passed, 0 failed (~35 s). lune_compat.py single-file run prints nothing and exits 0: it skips suites without an @lune/ require (this one has none), so plain luau is the real run. luau-compile --null ok on BiomeDressing, BiomeDressingService, the test.
- [D5 done] Amberfall 45 + Saltreach 37 pieces have specs (bbox exact copy, within 5%; subs = registry keys <Piece>__<Sub>; silhouette archetype). Ravine kit use 38/45, Basin 36/37; parts per region 1500/1078/1270/1500 (Ravine/Basin/Snow/Mtn, budget 1500). Hero slots: BiomeDressing.Slots (Ravine_Aqueduct_Arch -> Amber_Aqueduct_Hero, Basin_Gate_Statue -> Saltreach_Gate_Statue), service looks up registry by def.Key. Lead: generate src/shared/AmberfallKitRegistry.luau / SaltreachKitRegistry.luau (return the "pieces" table of assets/*_KIT_UPLOADED.json), BiomeDressing requires them if present.

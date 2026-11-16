# 24a terrain heartbeat (lane T3, source only, no Studio): bound every synchronous terrain call

Supersedes: nothing (searched workers/ for 2*.md in an earlier call: no 24a; 03f-budget-relief.md introduced the 6 ms slicer this lane tightens, it stays as history). Linked from LEDGER.md by the lead (same convention as 22a).
Why a new file: this is a new lane (C3 must-fix b, 22a CHK2 FAILED at 20.9 Hz) with its own log; no existing worker file covers it.
Prompt: Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Plan
Root cause: the slicer only checks the clock between columns/tiles; one `WriteVoxels` of a whole 128x64x128 slab (32x16x32 = 16384 voxels) is a single uninterruptible engine call, and it is not counted until after it returns. Also `shellBottom` loop has no Check, and `Clear` FillBlocks a whole slab per call. The urgent band only reorders tiles; it does not bypass the budget.
Fix: write each slab in boxes (full-height, 8 columns in Z, w columns in X) sized from a measured per-voxel cost so one call is about 2.5 ms; reserve the estimate against the slice before each call (yield first if it would not fit); adaptive budget (halve on slow Heartbeat dt, skip a frame at the floor, recover slowly); Clear in strips.

## Exact file list (only these)
- src/server/Services/OverworldTerrain.luau
- src/shared/Overworld.luau Terrain section: no edit expected (Edit only if needed)
- tools/test_overworld_terrain.luau (constants check only if needed)
- tools/test_overworld_order.luau (new fake tests)
- this file

## Log
- [edit0] plan file written; constants block edited next
- [edit1] OverworldTerrain.luau: slicer (Reserve/Limit/adaptive), Use hook, boxed WriteVoxels, strip Clear, Check in shellBottom loop
- [edit2] writeTile boxed writes + Clear strips applied
- [edit3] tools/test_overworld_order.luau: fake-clock bounded-call tests added (not yet run)
- [edit4] Clear boxed one column wide; test thresholds fixed; rerun next
- [test] order 472/0 pass, terrain run done; final report next

## T4 (lane T4, source only; Studio is measured later by the TEST-window operator)
Prompt: Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.
Targets (Fable ruling): heartbeat >= 45 Hz while writing (no dip under 30 Hz > 1 s); glade <= 20 s; every altar/arrival site <= 90 s; whole map <= 10 min (4356 tiles = 7.3 tiles/s); TerrainVoxels <= 185 MB; sprint + guard tests pass.
Diagnosis from reading T3 code: (1) the box loop writes full 64-stud slabs one column wide, so a column that holds ~3 solid voxels pays for 16 (and every slab between the tile floor and top, mostly Air): 4-5x more voxels through WriteVoxels than exist; (2) the per-voxel fill (math.clamp x2 per voxel, nested table.create per box) runs for those Air voxels too; (3) sampleAt loops every pad (about 60) and allocates a softWeights table per call, 2x per column (height + material).
Plan, in order, each measured offline (luau --codegen where native matters; compute only, WriteVoxels stubbed):
1. Stats counters on OverworldTerrain.Stats (ComputeMs, WriteMs, YieldMs, per-phase SampleMs/MaterialMs/ShellMs/FillMs, Tiles, WriteCalls, BoxVoxels, SolidVoxels); baseline on the T3 code.
2. Column cache: per column kLo/kHi voxel range from cached h/shellBottom/lake; fill only that range (tight boxes), no per-slab Air loop.
3. @native on the Terrain-section hot functions (sampleAt, baseAt, edge, relief, materialAt, shellBottom...), pad culling per tile (exact: a pad weight is 0 beyond R+Blend), alloc-free softWeights.
4. New module OverworldTerrainCompute (pure: tile -> packed buffer) + OverworldTerrainWorker (Actor script, BindToMessageParallel) + a pool in OverworldTerrain with inline fallback; main thread only decodes and calls WriteVoxels.
5. Box size from the measured write cost (cost = per call + per voxel, fitted online), plus a frame-headroom boost for glade/site tiles while no player is near unwritten ground.
Files touched: OverworldTerrain.luau, Overworld.luau (Terrain section only, Edit), NEW OverworldTerrainCompute.luau, NEW OverworldTerrainWorker.server.luau, tools/test_overworld_terrain.luau, tools/test_overworld_order.luau (+ a throwaway tools/_bench_t4.luau, deleted at the end).
- [T4 edit1] OverworldTerrain.luau: Stats (SampleMs/MaterialMs/ShellMs/FillMs/ComputeMs/WriteMs/YieldMs/Tiles/WriteCalls/BoxVoxels/SolidVoxels) + lap()/counted-yield; throwaway tools/_bench_t4.luau (WriteVoxels stubbed, 279 tiles = every 16th of the plan + 6 glade tiles)
- [T4 measure0 BASELINE, T3 code, plain Luau interp on this machine, 279 tiles] compute 45.4 ms/tile = sample 29.3 + material 2.7 + shell 0.4 + fill 13.0; BoxVoxels 24315/tile vs SolidVoxels 3868/tile (6.3x more voxels handed to WriteVoxels than exist; Air in full 64-stud slabs). T3's 125 ms/tile was this machine x 2.7 slower (or its tile mix); Studio 345 ms/tile means writes were ~220 ms.

## T4b (Mac) (lane T4b, source only, no Studio; finishes T4 steps 2-5)
Found: OverworldTerrainCompute.luau (Codex/T4) is complete and pure (tile -> packed buffer, tight per-column voxel ranges, @native, flat arrays) but not mapped/required; _bench_t4*.luau sit in tools/ (move to work/, delete at end). Overworld.sampleAt already takes a pads list but no culling helper exists (bench guards `O.padsNear`).
Plan: (1) Overworld.luau Terrain section: add exact `padsNear(x0,z0,x1,z1)` (a pad has weight 0 beyond R+Blend). (2) OverworldTerrain.luau: writeTile = compute (worker Actor pool via BindToMessageParallel + SharedTable string result, inline Compute.tile fallback) then main-thread decode into tight WriteVoxels boxes (row runs merged greedily by a fitted call+voxel cost model). Stats reshaped. (3) NEW OverworldTerrainWorker.server.luau (Script inside an Actor). (4) tests: order test fake-env updated (script, buffer), identity test old-path vs new on glade/lake/ravine/shell tiles.
Files: src/server/Services/OverworldTerrain.luau, OverworldTerrainCompute.luau, NEW OverworldTerrainWorker.server.luau, src/shared/Overworld.luau (Terrain section, Edit), tools/test_overworld_order.luau, tools/test_overworld_terrain.luau, this note, throwaway work/_bench_t4b.luau.
Lead mappings needed (see final report): OverworldTerrainCompute ModuleScript + OverworldTerrainWorker Actor in default.project.json.
Baseline offline (this Mac, work/bin/luau, compute only): T3-ref 15.5 ms/tile interp / 4.4 native; Compute.tile 14.9 / 4.1 (pads unculled). T3 ref solid/tile 3922 vs Compute 3824 (diff = Water voxels under the shell of lake columns that the old slab fill wrote; invisible, buried).
- [T4b edit1] Overworld.luau Terrain section: padsNear (exact pad cull). OverworldTerrain.luau rewritten head: Compute-based writeTile, worker pool (SharedTable strings) + inline fallback, fitted call/voxel cost model, run-merged tight boxes, Slicer.Wait. NEW OverworldTerrainWorker.server.luau. Compute.Header export.
- [T4b edit2] test_overworld_order env (script/buffer/Compute) + box assertions updated: order suite 472 pass / 0 fail. Identity test + pool test + measure next.
- [T4b edit3] Slicer grows to 1.5x BUDGET while Heartbeat <= 1/55 s (halves above 1/45 as before). Tests: order 487/0 (identity old-vs-new on glade/lake/ravine/cliff, inline + fake-Actor pool, dead-worker fallback), terrain 102/0 (padsNear bit-identical), data/blockout/encounters/world_map green, all src compiles. Benches deleted; pre-change writer kept as work/OverworldTerrain.t3.luau.bak.
- [T4b measure, offline, compute/main-thread only, NOT engine] 279 tiles: BoxVoxels/tile 5002 vs SolidVoxels 3772 (ratio 1.33; T3 was 24315 vs 3868 = 6.3x); 106 WriteVoxels calls/tile; main-thread decode 1.0 ms/tile (interp); worker compute 12.0 ms/tile interp (~3.8 native); T3 inline compute was 45.4 ms/tile (interp, measure0) -> 11.8 inline now. Modelled write at 60 us/call + 8 us/voxel = 46.5 ms/tile => ~572 s for 4356 tiles at 6 ms budget, ~380 s at 9 ms.
- [T4b open] lead: map OverworldTerrainCompute + Actor OverworldTerrainWorker in default.project.json (snippet in report); Studio operator measures the engine cost per call/voxel (Stats.WriteMs / WriteCalls / BoxVoxels).

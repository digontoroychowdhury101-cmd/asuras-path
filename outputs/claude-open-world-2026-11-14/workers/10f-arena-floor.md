# 10f arena floor (Lane 6, source only)

Supersedes: nothing (searched workers/10f*, LEDGER.md). Link from LEDGER.md pending (orchestrator).
Prompt: Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

- [cause] BossArenas floor slab (4 thick) top = boss.Spawn.Y - 3 = 1580, exactly the terrain pad's written surface (heightAt 1578 + 2; voxel jitter 1579.2..1580.9) -> coplanar z-fight = dark flat panels. The Approach slab had the same top. Not a hard-coded Y (baseline used 0; the Spawn.Y-3 change is already in place), not lighting. Walls offset from center so they follow. Pillars (Y = Top/2) are hard-coded but only for the inactive Beast boss (Baize), not built.
- [fix] src/server/Services/BossArenas.luau: Arenas.FloorLift = 1; center.Y = Spawn.Y - 3 + FloorLift (floor top 1581, approach likewise; 1-stud walkable step at the pad margin).
- [test] tools/test_boss_encounters.luau: source-level check reads FloorLift, samples Shen footprint with Overworld.heightAt+2: gap >= 0.05 and <= 2. Also made the fs probe a literal require inside pcall so lune_compat rewrites it (the old pcall(require,...) form silently skipped the traverseGate checks under compat). Lift 0 fails, lift 1 passes (316 checks).
- [verify] lune_compat --all no FAIL, test_boss_runtime.py ok, luau-compile --null ok.
- [Studio must capture] Shen arena from the gate: floor continuous, no dark panels; walk Outside -> centre (1 stud step at edge, no snag); Shen spawn stands on the floor (2 above top).

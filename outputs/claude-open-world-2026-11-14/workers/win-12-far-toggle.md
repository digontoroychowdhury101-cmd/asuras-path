# win-12 far-silhouette client toggle + 5b harness fix
Files: src/client/Controllers/LandscapeBudget.luau, tools/test_landscape_far.luau (NEW: no LandscapeBudget test existed), tools/qa/ShenMultiClient.server.luau, this note.
Checkpoint A: LandscapeBudget edited (Far rows, farShown hysteresis 15 studs, lobby hides _Far, restore on tag removal/Destroy).
Checkpoint A done: new tools/test_landscape_far.luau 13/0 (no prior LandscapeBudget test: 0 before); LandscapeBudget compiles.
Checkpoint B done: ShenMultiClient 5b place() fires Position, retries up to 3x, asserts both in trigger/arena, logs A Respawning/State/Encounter. Compiles; not run.

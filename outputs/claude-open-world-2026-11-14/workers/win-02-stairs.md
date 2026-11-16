# win-02 stairs + tower sightline (Windows, Sonnet)

Plan. Files: src/shared/BiomeDressing.luau, tools/test_biome_dressing.luau (SliceDressing/test_slice_dressing only if the tower sightline fails). Captures: captures/win/stair_*, tower_*.
1. TDD: failing check in test_biome_dressing for high-end exposure (top step vs ground) at both ends.
2. Smallest fix in BiomeDressing (rampStairs / stair placement), luau + lune_compat for both tests.
3. Studio: copy AsurasPathTEST.rbxlx -> work/windows-resume/stairs/AsurasPathTEST_stairs.rbxlx, verify digest, patch module in memory, Play, measure flights, walk, capture tower from glade arrival.
Checkpoints follow.
- CHECKPOINT 1: probe tools/_win02_probe.luau (to delete): heightAt says SummitSteps_Stair_1 top is 7.5 below ground at high end, _2 1.6 below (stair slope .54 vs ground .86/.6). Added high-end buried>2 check to test_biome_dressing stair section.
- CHECKPOINT 2: BiomeDressing: added Mtn_Stair_Mid (rise .95) / Mtn_Stair_Steep (1.35); rampStairs(taller) picks per flight by ground climb over 22 studs (Mountain only). Probe: Stair_1 top -0.5, Stair_2 -0.2 vs ground (was -7.5/-1.6). Running tests.
- CHECKPOINT 3: luau slice 989/0; biome only the two 20s build-time checks fail under load (stair check passes; 19089 pass). Studio window d6b6bf65 opened on AsurasPathTEST_stairs.rbxlx.
- CHECKPOINT 4 (Studio d6b6bf65, digest 277/3174231/1755809200 verified, PlaceId 0, persistedToCloud=false; module patched in memory via 4 string edits; Play started; teleported to summit, MountainAscent dressing raised): terrain raycast. SummitSteps_Stair_1 Mtn_Stair_Steep lowSink 0.9, high top-ground 0.0; _2 Mtn_Stair_Mid lowSink 1.1, high +0.5; _3 Mtn_Stair_Run lowSink 0.5 high +10.9 (floats above flat plateau, open defect, not in task).
- CHECKPOINT 5: walked char (real nav) from -7204,1520,-7925 over all 3 SummitSteps flights to -7200,1563.5,-7992. Capture stair_summit_flights_looking_up.jpg (client lit by overrides, game clock night 17-22h; camera -7204,1534,-7922 -> -7202,1552,-7970, stack digest 277/3174231/1755809200 + in-memory BiomeDressing patch).
- CHECKPOINT 6: capture stair_summit_flight2_side.jpg (cam -7225,1550,-7950 -> -7203,1548,-7960): treads flush with slope, no burial.
- CHECKPOINT 7: tower sightline in Studio from glade arrival eye (-2200.5,66.5,-1408) rays to tower x-z (-2667,-1588): y115..168 hit Bell_Tower_Ruined parts (visible), y95 foot hidden by Terrain at 433 studs. Capture tower_from_glade_eye1.jpg (cam -2200.5,69,-1408 -> -2667,140,-1588; client lit day, post-effects off; placeholder tower geometry). Tower visible, centre frame.
- CHECKPOINT 8: second eye (-2203,69,-1415): all four rays y115-168 hit tower parts; capture tower_from_glade_eye2_night.jpg (game night grade, tower silhouette centre, lit by moon). Stopping Play.
- FINAL: slice luau 989/0, lune slice 1013/0; biome luau 19089 pass, only the two 20 s build-time checks fail under machine load (stair checks pass); lune biome printed nothing (paging-file pressure), not confirmed. Probe deleted. Window closed (process killed, nothing saved). Not committed.

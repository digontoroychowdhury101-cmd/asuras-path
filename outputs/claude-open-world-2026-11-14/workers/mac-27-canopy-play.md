# mac-27 canopy play (heavy slot, Sonnet)

Supersedes: nothing. Linked from CONTINUATION.md "Mac resume — 2026-11-18" table. Why new: this lane's note. Instruction: lead's mac-27 order.

## Plan
1 build canopy27 + expected digest; 2 open local copy, assert PlaceId 0 + digest; 3 Play, slice stats; 4 console classes; 5 canopy rays at 7 eyes; 6 frame time at 01; 7 captures 01-07 (preliminary); 8 teardown, digest, close w/o save.

## Log
- [build] HEAD 62f1146 (034a7d2 in history). built; expected digest scripts 281 bytes 3256828 hash 728218180; mem(before build) free 55%
- [open] Studio pid 33592, canopy27.rbxlx Edit persistedToCloud=false PlaceId 0; in-Studio digest 281/3256828/728218180 == expected. mem(Studio open) free 36%
- [play] Play started; slice 63/63 cells, 0 placeholder, 2391 kit MeshParts, 58.4 s (log). Terrain still 3812/4356 at that point. Next: stats, canopy rays, console, frame time, captures.
- [stats] slice MeshParts 2391 (attr), Parts(placeholder) 0, ws MeshParts 5891 (server), ws instances 35541 (server), slice descendants 5197; CanQuery was false on 2024/2391 (forced true).
- [canopy] 60az x 4el(20/40/60/80) 150 studs, Include-filter SliceDressing, from SliceDressing.captures() eyes: 01 11.2% (27/240; excl cone 11.6%) | 02 54.6% | 03 77.5% | 04 19.6% | 05 19.2% | 06 11.2% | 07 11.2% (excl cone 11.6%). 01/07 blocked only at 20 deg.
- [frame] view01 terrain done, 350 RenderStepped: mean 17.2 ms p50 16.7 p95 22.3 max 30.1 (first run 17.3/16.7/21.3/121.1 incl setup); Stats total mem 5247 MB; clock reset epoch=now-7000 per view. cap 01 saved (HUD ScreenGuis disabled, avatar+NPCs hidden).
- [caps] 01,02 ok; 03 BLACK: Canopy_Tree_A__Bark (Tree_0016, Cell_57_58) 3.8 studs from eye, trunk fills frame (3.1-4.1 over +-30 deg).
- [caps] 04,05 saved. NOTE: unanchored teleport got reverted to lobby (respawn displaced 0,603,920; entity nil) before 05; redone with RequestStreamAroundAsync + HRP.Anchored. Console: huge 'No asset content representation' flood in Play (truncated by tool) - to count at end.
- [caps] 06,07 saved (all 7 in captures/mac/slice_canopy27_0N_*.jpg). Next: console classes via LogService, teardown.
- [console] from Studio log file (in-Studio history capped ~100): 192 "No asset content representation" lines, 13 unique rbxassetid (not in repo registries nor DataModel props; unattributed), 0 rbxassethash, 0 type-mismatch, 43 Wrap-deformer mesh-fetch warnings, 8 StyleRule CornerRadius warnings.
- [END] Play stopped; Edit digest 281/3256828/728218180 unchanged, PlaceId 0; SIGTERM ignored, kill -9 on pid 33592 only; 0 Studio processes; rbxlx mtime unchanged (23:00); removed stale .lock; mem after 50% free (before build 55, Studio open 36).

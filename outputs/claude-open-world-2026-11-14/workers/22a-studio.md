# 22a studio (lane S2a, single Studio operator): terrain memory / heartbeat / sprint / rain / haze / Shen gate

Supersedes: nothing (searched workers/ for 22a in an earlier call: none). Linked from LEDGER.md by the lead (CONTINUATION.md row S2a names this file).
Why a new file: this is a new Studio measurement lane (stage 2, t15) with its own log; no existing worker file covers it.
Prompt: Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Log
- [22a start] Method from workers/12e-studio.md (python http.server, execute_luau Edit sync, restore from baseline.json). Scratch dir scratchpad/t15. Captures -> captures/t15/. No src edits, no git, no save.
- [22a prep] repo built ONCE to scratchpad/t15: scripts 284 bytes 3051381 digest 1053460866 (LOADED DIGEST; 33 changed, 10 new, 12 retired baseline scripts which will be PARKED not destroyed). sync.json/restore.json/baseline.json in t15; http 8791 (python, mine). Captures -> captures/t15/.
- [22a RESUME after usage-limit stop] Studio at baseline 462022588 Edit HttpEnabled false; http 8791 restarted by me. Remaining plan (checklist, lead order):
  - [ ] sync build 1053460866 (sync.json; retired scripts parked in ServerStorage.S2aHold, not destroyed)
  - [ ] 1 TerrainVoxels MB after all tiles (<=185)
  - [ ] 2 heartbeat Hz while writing (>=45), per-tile cost, glade-ready time
  - [ ] 3 sprint from s9, guard verdicts
  - [ ] 4 slice captures 01-07 (src/shared/SliceDressing.luau Captures defs) -> captures/t15/slice_01..07.png
  - [ ] 5 five summit views -> captures/t15/summit_<region>.png
  - [ ] 6 rain (Squash -2) + haze >600 studs captures
  - [ ] 7 Shen gate walk-out/in
  - [ ] restore baseline.json, HttpEnabled false, digest 462022588, kill server
- [22a sync] changed 33 created 10 parked 12; digest (excl S2aHold) scripts 284 bytes 3051381 digest 1053460866 == build. HttpEnabled true (restore false). STUDIO RUN STARTED; restore via t15/restore.json (revert changed, destroy 10 created, unpark S2aHold, delete holder).
- [22a play1 started] S2aProbe Script (in-memory, ServerScriptService, REMOVE at restore) logs hb/TV every 2 s. Early read: glade ready 18.85 s; hb 35-46 Hz during writes (Studio w/ client), TV 27 MB @ 500 tiles of 4356; writing ~7.5 tiles/s so ~10 min total. Waiting for completion.
- [22a CHK 1 TerrainVoxels] PASS: after all 4356 tiles TV=178.8 MB at completion (177.1 MB 25 s later), peak 181.4 MB (limit 185); in-write samples 27 MB @500 tiles, 97 @2300, 135 @3500, 181 @4300. [PerfBudget] voxels=178 MB.
- [22a CHK 2 heartbeat/timing] FAIL for >=45 Hz: write-phase Heartbeat (server, Studio w/ client) min 1.0, avg 20.9 over 692 2-s windows (typical 20-35, repeated 10-30 s stalls at 2-7 Hz, e.g. t=976-1002, t=1258-1273); server physics FPS (GetRealPhysicsFPS) ~59.5 outside stalls. Pre-write idle t=12-18 s was 44-46 Hz and idle after completion 24-44 Hz, with one 3.8 Hz stall at t=1516-1522 AFTER writes ended, so part of the limit is Studio client/render, not only the write. Glade ready 18.85 s, altars 50.6 s, ALL 4356 tiles 1504.9 s (avg 345 ms/tile; 100 tiles/~15-60 s). Console: only [PerfBudget] breaches + ContentId 203785492 x3. Server step p95 4-9.6 ms.
- [22a CHK 3 sprint] PASS (Play 2, tiles still writing). Player placed at glade (-2203,62,-1415) ~t=23 s after Play start (glade ready 18.9 s), W held due north: jog 22.2 st/s for 1900 studs (z -1415 -> -3315, 63 probe samples, ground ray 2.4-3.3 studs under root every sample, never NONE), then CapsLock sprint 32.8 st/s measured server-side to z -4399 (3000 studs from glade) with only 300 of 4356 tiles written. Rescues attr nil, no [Overworld] guard warn, no fall. Guard verdict: none triggered (always on written ground). Direction tested: north only (real input).
- [22a CHK 4 slice captures] saved captures/t15/slice_01..07.png (SliceDressing.captures() cameras, FOV 70, clear morning clock 8.98, GUIs off, avatar hidden, player anchored at From; Play 2 with only ~600 of 4356 tiles written but all slice ground present). Reads: 01 torii + lantern on the road with box canopies and tall grass (placeholders); 02 road low to the ground, dark box canopy undersides, lantern cubes; 03 understory boxes + grass + rock slab, far ridge; 04 road with a monk NPC on it, tower NOT visible; 05 pavilion (red posts, dark roof, gold finial) above trees, a swordsman NPC at frame edge; 06 pavilion from the stair, terrace walls, dark rock cliff behind; 07 tower from glade: tower NOT visible (a tree canopy and a dark roofed shelter left of frame block the line; torii right). Cameras sit ~1-2 studs over the ground in 02-04 (Eye 5 above heightAt but ground in view is closer).

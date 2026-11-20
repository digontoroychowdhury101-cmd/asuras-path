# win-70 forest re-capture (lead, Opus 5.5, Windows, 2026-11-21)

Supersedes: nothing (next review of mac-20-slice-verdict.md after the mac-31 canopy pass and the retone2 uploads).
Instruction: handoff §4 step 7, creator's "Yes continue".

## Method (mac-20 gate)
- Build of 97deae7 to work/vesperhold-claude/win70/ForestRecapture.rbxlx; Studio Edit digest 287 / 3471464 / 2088899630
  (same as the checkpoint), PlaceId 0. Closed unsaved; file mtime unchanged. Heavy lock taken and released.
- Seven eyes from SliceDressing.captures(), camera held at RenderStep Camera+50, avatar/NPCs/UI hidden client-side,
  AsuraWorldEpoch = now-7000 (clock ~12.0, clear). A server Heartbeat hold kept the character at each eye: the
  CharacterService respawn guard sends it back to the lobby (0,603,920), which also switched lighting to the lobby
  sunset and left the eye unstreamed. 04 and 05 were retaken under the hold.
- Captures: captures/win/forest70/forest70_01..07.jpg, _01_nodecoration.jpg, sheet forest70_sheet.jpg.

## Numbers
- Slice: 63/63 cells, 2347 MeshParts, 0 placeholders; workspace MeshParts 10430 (server).
- Canopy (60 az x 4 el 20/40/60/80, 150 studs, SliceDressing only, CanQuery forced): 01 20.0 | 02 54.6 | 03 23.8 |
  04 31.2 | 05 23.3 | 06 15.4 | 07 20.0 % — identical to mac-31 (layout unchanged since f407964).
- Frame time, view 01, 3 x 300 RenderStepped: mean 45.8 / 45.4 / 45.5 ms, p95 54.1 / 53.0 / 53.7; client memory 3595 MB.
  Terrain was still generating (1702/4356 tiles, server heartbeat 17-23 Hz). Win-16 on this PC: 57.2 ms.
- Terrain grass A/B at view 01: Decoration off 46.4 ms vs on 45.9 ms (no measurable cost either way).
- Console content failures: 0 "No asset content representation" (win-16 had 122 on 24 far-tree IDs);
  14 unique IDs "Asset content representation is being generated" (not in repo, build or live DataModel; transient
  processing of inner assets of recently uploaded models); 1 known rbxassetid://203785492 type mismatch.

## Against the mac-20 list
1. Far trees: textures now load (atlas 136311721561505 on every *_Far__Leaves), but Canopy_Tree_B/C/D_Far at
   170-230 studs still read as glossy lime stacked discs in 01, 04, 07. **Open.**
2. Park, not wilderness: 01/07 still open grass under sky; 02 a dark closed tunnel; 06 15.4% (<25). **Open.**
3. Built pieces near-black: **fixed** — cart, crates, torii, fence and pavilion read as red-lacquered timber (05, 06).
4. Foreground grass: the blades are Terrain.Decoration (confirmed again by the A/B). Still dominate 01, 06, 07.
   **Decision needed** (Decoration is global terrain state, so turning it off also changes other regions).
5. Foliage: near crowns darker and textured, no longer neon; trunks and understory still near-black in shade (02, 03). **Partly.**

**Lead assessment: not yet acceptable; M2 stays held.** Creator review of forest70_sheet.jpg pending.

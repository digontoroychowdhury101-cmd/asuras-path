# 22e Bellwood kit sheet + slice vignettes (lane LB, only live Blender operator)

Supersedes: nothing. Searched workers/ for kit-sheet, sheet and vignette first: only 12a-slice-kit.md and 21a-bell-veg.md mention vignettes (their own per-pack vignette_*.png, kept untouched). Linked from CONTINUATION.md row "LB live Blender" (line 295); the lead links it from LEDGER.md (LB may not edit LEDGER).
Why a new file: durable per-step log for LB, which owns only captures/kit/bellwood_sheet/** and assets/source/overworld/vignettes/**; no existing worker file covers a combined sheet or the glade-to-terrace vignettes.

Prompt: Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Log
- [start] Inputs read: CONTINUATION row LB, SliceDressing.luau (Captures 01-07 camera defs, Hero placements, scatter builder), 12b/12c notes. GLB units are 1 unit = 1 stud (pack manifests: "1 stud = 1 unit, Y up"); 0.28 m/stud is metadata only, so scenes stay in studs and the figure is 5.5 BU tall. Placements come from running SliceDressing.build() headless in luau.exe, not re-derived. No git, no uploads, no generators.
- [resume plan] Order per coordinator: (1) vignettes first, then (2) kit sheet. Files: assets/source/overworld/vignettes/{dump_slice.luau, slice_data.json, build_vignette.py, vignette_01..07.png, vignettes.blend}; then captures/kit/bellwood_sheet/{sheet_veg,sheet_rock,sheet_built,sheet_hero}*.png + sheet_index.md, script assets/source/overworld/vignettes/kit_sheet.py. One script run per output; checkpoint line after each render.
- [checkpoint] vignettes.blend built (1550 placements, 0 import failures; build_vignette.py, render_view.py, dump_slice.luau, slice_data.json). vignette_01 (glade arrival: lantern/shrine/ferns, torii down the road, Bell_Tower_Ruined left of road), vignette_02, vignette_03 rendered.
- [checkpoint] vignette_04..07.png rendered (04 tower approach, 05 pavilion lane, 06 terrace stair + pavilion court + ruined tower at left, 07 tower from glade arrival: Bell_Tower_Ruined above the trees along the cleared sightline). Eyeballed 01,02,03,06,07: kit reads correctly, ground is a simple colour-by-road/slope sculpt of Overworld.heightAt (8-stud grid, 4-stud mesh). vignettes.blend saved. Next: kit sheet (kit_sheet.py, one run per sheet PNG).
- [checkpoint] sheet_hero_1.png (5 hero pieces, labels ok). Plan: hero 1, rock 2, veg 6, built 6 sheets; one blender run per sheet.
- [checkpoint] sheet_{hero_1,rock_1-2,veg_1-6,built_1-6}.png + sheet_index.md written: 15 sheets, 95 pieces, 0 import failures. Done.
- [checkpoint] sheet_built_7.png added (missed by a re-plan); sheet_index.md rewritten: 16 sheets, 95 pieces, 0 import failures. LB done.

## LB2 re-render
Plan: LB2 (only Blender operator for vignettes) rebuilds vignettes from the CURRENT D3 SliceDressing.build(). Steps: (1) re-run dump_slice.luau (adapt if output shape changed) to slice_data.json; (2) copy vignette_01..07.png to vignette_0N_preD3.png; (3) edit build_vignette.py to drop the hand-added extras section (sets are now in the data) and map any new pieces/packs; (4) rebuild vignettes.blend; (5) one render_view.py job per vignette 1..7; (6) view all seven as images and note floating pieces, trees on the road, occluded tower in 07.
Files (all under assets/source/overworld/vignettes/): dump_slice.luau, slice_data.json, build_vignette.py, build_report.json, vignettes.blend, vignette_01..07.png, vignette_01..07_preD3.png (new copies, supersede nothing; same artefact family as the existing vignettes, listed here, lead links from LEDGER.md). No git, no uploads, no generators.
- [LB2 checkpoint] slice_data.json re-dumped from D3 SliceDressing.build(): 1456 placements, 87 pieces, 7 captures, shape unchanged (old preD3 dump kept as slice_data_preD3.json, old PNGs copied to vignette_0N_preD3.png). build_vignette.py: hand extras and tower swap removed; vignettes.blend rebuilt, 1456 placements, 0 import failures.
- [LB2 checkpoint] vignette_01.png rendered (post-D3, own job).
- [LB2 checkpoint] vignette_02, 03, 04 rendered (post-D3, one blender job each).
- [LB2 checkpoint] vignette_05, 06, 07 rendered (post-D3, one blender job each). Next: view all seven, report.
- [LB2 done] All seven post-D3 renders viewed. Tower: clear in 04; small, tree-occluded sliver in 01 and 07; absent/not framed in 02, 03, 05; 06 is the pavilion court (tower not in frame). No sunk or floating pieces seen by eye; no numeric per-piece check was run.

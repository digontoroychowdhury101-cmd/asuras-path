# Worker 06 - compass numeric bearings (progress log)

- [x] Read SakuraCompass.luau, HudKit, SakuraKit colours, test_hud_layout.luau. `lune_compat.py --all` globs tools/test_*.luau, so verify_all.sh needs no edit.
- Plan: Compass.bearing / offset / readout pure fns; numbers every 30 deg (non-cardinal) size 11; Heading label moved to top row as "NE 045" readout; Markers row y=20 ZIndex 0; Compass.setMarker(view,id,bearing?).
- Density reasoning: strip px/deg = width/(2*80). min 240px -> 1.5 px/deg: 15 deg = 22.5 px, 30 deg = 45 px; max 520 -> 3.25 px/deg. 3-digit label ~16 px wide at size 11. 15-deg numbers leave ~6 px gaps at min (too dense, also collides with letters); 30-deg numbers leave 29 px between numbers and 22.5 px centre gap to the nearest letter (>= 8+7+4 clearance). Chosen: every 30 deg, skipping the 90-multiples (letters).
- [ ] patch applied
- [ ] tests run
- [x] patch applied to SakuraCompass.luau (bearing/offset/readout/setMarker, numbers every 30, readout label top row)
- [x] wrote tools/test_compass_bearing.luau (picked up by lune_compat --all glob)
- [x] tests: test_compass_bearing 1828 pass; test_hud_layout 258 pass; test_input_map 421 pass; luau-compile --null OK. luau-analyze only emits Roblox-global noise (same on unmodified file). Studio visual check NOT done.

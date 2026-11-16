# 05b map style (lane 5, source only)
- Baseline bake (old WorldMap, test harness machine): paintRow x256 = 1.69-1.76 s, paintRoutes 0.002 s. Budget 1.5x = 2.55 s.
- Plan: row-cached height/chasm samples (one sampleAt per pixel), parchment-by-biome via Overworld.blendAt, NW hill shade from +-2px height gradient (quantised), contours every 40 studs (index every 200, none on flat ground), coast outline, chasm as umber depth, routes drawn as cased strokes (rivers then roads).
- WorldMap.luau restyled (palette, row cache, shading, contours, coast, strokes, inset/centreOn/follow).
- WorldMapController.luau: View.Inset, Centre via centreOn, follow on marker crossing out, legend hidden on short panes.
- WorldMapController.luau: View.Inset, Centre via centreOn, follow on marker crossing out, legend hidden on short panes.
- tools/test_world_map.luau: road check replaced; sections 11 (style) and 12 (inset/follow) added.
- fixed: lighting clip (LIGHT_BASE), follow boundary epsilon, flat-window speckle test found from terrain.
- test 168 passed 0 failed; bake rows ~1.5-1.7s vs 1.7s baseline.
- tests adapted to lane 4 terrain (water and flat windows found from data); final 169 passed; compat/compile/build ok.

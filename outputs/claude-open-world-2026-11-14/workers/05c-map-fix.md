# 05c map fix (Lane 5c, source only, no Studio)

Supersedes: nothing. Linked from LEDGER.md by the coordinating lane.
Prompt: Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Log
- [src/shared/WorldMap.luau] added WorldMap.Layout, controlRects(w,h), insetFor(w,h) (safe strips from the real Tools/Legend/hint rects, Gap 24 for the 26 px arrow); added WorldMap.tintAt(x,z,h): blendAt with no height filter, 5-tap spread 90 studs; paintRow uses it.
- [src/client/Controllers/WorldMapController.luau] INSET const removed; Tools/Legend frames built from WorldMap.Layout; Fit sets View.Inset = insetFor(W,H) each call and, on a pane resize, follows the arrow out of the controls (margin 0); Open now opens the window and Fits before Centre (stale-size root cause: Centre ran on the previous W/H, then Fit only re-covered).
- [tools/test_world_map.luau] section 12 rewritten: for 443x199, 996x550, 1040x660, 640x360 every region centre, frame corner and edge, opened and followed, keeps the whole 26 px arrow clear of the real Tools and Legend rects; picture covers the safe rect. Section 13: tint continuity over 20 region-border walks, worst step 13.04/255 (bound 16).
- VERIFY: luau test 436 passed 0 failed; lune_compat --all all PASS (one transient missing work/legacy file from another lane on the first run); luau-compile --null clean on all three files. Studio: capture 640x360 east edge and 996x550 south-west corner (legend), and a biome border (Frostmere/Ashen Stair).

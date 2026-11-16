# 21c Bellwood built B (lane M3, headless Blender)

Script: tools/blender/overworld/bellwood_built_b.py (`blender -b -P ... -- <out> <captures>`; reuses the material + geometry helpers of slice_kit.py by exec, so stone/timber/bronze language is identical).
Out: assets/source/overworld/bellwood_built_b/ ; upload pack: assets/source/overworld/upload/bellwood_built_b/ ; renders: outputs/claude-open-world-2026-11-14/captures/kit/bellwood_built_b/. Registry target (no IDs yet): assets/BELLWOOD_KIT_UPLOADED.json.
Original procedural work only; no uploads, no credits.

## PIECE LIST (priority order)
1. Bell_Tower_Ruined (60-80 studs, ruined top, hanging bell, rubble; sub-meshes split under 18k)
2. Hermit_Hut (porch, tiled roof)
3. Rope_Bridge_Deck (modular deck segment) + Rope_Bridge_Anchor (post pair)
4. Falls_Alcove (rock niche + shrine ledge)
5. Cart_A, Cart_B
6. Crate_A, Crate_B, Crate_C
7. Pot_A, Pot_B, Pot_C
8. Lantern_Hanging, Lantern_Stone

## Log (appended after every piece)
Build: `blender -b -P tools/blender/overworld/bellwood_built_b.py` (all 16 GLBs, ~25 s). Every sub-mesh < 18000 asserted; make_upload_pack.pack() re-derived tris/size from the GLBs: problems none. Upload pack: assets/source/overworld/upload/bellwood_built_b/ (GLBs, maps/, upload_manifest.json with tris, file bytes, texture sizes, registry assets/BELLWOOD_KIT_UPLOADED.json, no IDs). Renders in captures/kit/bellwood_built_b/: `{Piece}.png` (iso) and `eye_{Piece}.png` (camera 5 studs, 5.5-stud orange figure beside).

- 1 Bell_Tower_Ruined (replaces Bell_Tower_Broken): 53.8x52.9x76.7 studs, 32.5k tris; Stone_Base 4488, Stone_A 11176, Stone_B 8536, Stone_Belfry 3344, Rubble 3432, Timber 484, Bronze 944 (1.35x bell on beam), Roof 88. Four unequal piers (to 76.7, 69, 62.5, 56), W lintel, half S lintel, collapsed NE faces, joists poking out, broken rafters + tile slab, door ajar, 6-step stair, rubble ring. Fault C captures: Bell_Tower_Ruined_treeline_190.png / _330.png (70 deg vFOV, camera 5 studs, 44-56 stud stand-in trees: tower top and bell clear the canopy by ~20 studs).
- 2 Hermit_Hut: 20x19.6x20.3, 12.2k tris (Stone 3652, Timber 6260, Roof 2024, Bronze 272): curved-eave tiled roof, plank walls, porch with posts/lean-to/steps, ajar door and shutters, stone chimney, firewood, barrel, wind chime.
- 3 Rope_Bridge_Deck_A/B (modular 8-stud segment along Y, 1.1k tris each; B has a missing and a half plank, a slack hanger) + Rope_Bridge_Anchor (1.6k tris: A-frame posts, crossbeam, stone footings, rope wraps, cable stubs).
- 4 Falls_Alcove: 46x22x21.6, 30.9k tris in 6 sub-meshes (Rock_Back 15360 = 3 rocks, Lip, Sides, Rim, Shrine_Stone, Shrine_Timber): back plate + two shoulders leaving a 6-stud recess, notched lip with chute slab (water spills at x=0), plunge-pool rim, shrine ledge with stone lantern at left.
- 5 Cart_A (hand cart, 2.9k tris), Cart_B (4-wheel, rear-left wheel gone, canopy hoops, barrels, 4.1k).
- 6 Crate_A/B/C (0.8-1.2k tris: closed braced, open with a missing slat, tall strapped).
- 7 Pot_A/B/C (clay jar, handled amphora, lidded rope-tied jar; 0.7-1.1k).
- 8 Lantern_Hanging (622 tris, chain + bronze cage + glow + tassel), Lantern_Stone (476 tris).
New materials: Bell_Clay, Bell_Rope (256-512 maps, bake = numpy procedural PBR). Everything else reuses Bell_Stone/Timber/Bronze/Roof/Granite/LanternGlow.

Known weak: hut chimney hidden from the front view; Crate_B's leaning lid does not land where intended (lid slab left off-view, still in the mesh); Cart_B prop log reads as a loose log; tower belfry is blocky (square stone blocks) up close; falls reads as a rock arch, not yet checked against real terrain; tower tri total 32k across 8 sub-meshes is heavy: Rubble/Stone_Base can be dropped at distance. No Studio import, no upload.

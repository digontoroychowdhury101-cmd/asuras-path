# mac-102: Bellwood reveal foreground lake scatter (pass 1)

Goal: fill the empty foreground lake in the tunnel-exit reveal (mac-99 item 2, concept `concepts/bellwood_3_sunken_temple_reveal.webp`) with art that is already uploaded. No new meshes.

## What changed
- `LandmarkLayout`: `Basin.Shallows` holds 7 pieces: mossy outcrop, two granite boulders, the Saltreach hull as a listing wreck, a floating log and two reed clumps. `Layout.shallowsSpot` seats each piece on the lake bed, or on the deep dish where it lies.
- `LandmarkWorld`: `shallowsFrame` builds each frame from yaw, pitch and roll. `build` places the pieces in a `Shallows` model after the gate. Rocks, log and hull get Hull collision; reeds and the wreck's ribs get none.
- `VesperholdKit.landmarks()` (now `Kit.landmarks`) merges `LandmarkKitRegistry`, `BellwoodKitRegistry`, `SliceKitRegistry` and `SaltreachKitRegistry`. The first module wins and missing modules are skipped, the same way as `SliceDressing.RegistryModules`.

## Tests (written first)
`tools/test_vesperhold_loader.luau` checks:
- registry merge order;
- each piece is placed at its `shallowsFrame` and Scale;
- each piece is inside the shore and clear of the colossal approach, the gate stair and the route causeways (`R + 2`) and of the gate (`Radius + R`);
- each piece is within 50° of the exit's view (the reveal camera is about ±51° wide at FOV 70);
- each piece is seated at bed + Lift with its foot under the water;
- collision is set per role.

Result: 231 passed. `verify_all` passes.

## Studio Play (Development, digest 295/3932154/617863386)
- All 7 pieces load. Every top is 4.5–9.6 studs above the water (150.5).
- First pass: the log (3 studs proud) and the slab boulder (2 studs) went under the water surface once near terrain finished streaming. Raised them: log Lift 7, slab Scale 3.2, outcrop Scale 2.8, wreck Lift 5.5 / Roll 8.
- Finding: `Reed_Clump_B__Heads` renders broken. The cattail heads show as green sleeves on candy-striped stems (`captures/mac/bellwood_reveal/mac102_reed_clump_b_uv_defect.jpg`). It is left out of the lake. The piece still appears in the Bellwood grove dressing, so that clump needs its UVs re-baked in Blender.
- Accepted shot: `captures/mac/bellwood_reveal/mac102_exit_reveal_lake_scatter.jpg`.
- Saved to Development (log: "Saved new changes", 12:31Z).

## Still against bellwood_3
- No colonnade (standing or toppled) and no lotus/lily cards; both need Blender kit steps.
- The right-hand foreground is still lighter than the concept's.
- Fix the Reed_Clump_B heads.

# win-112: Bellwood temple footings (Windows, 28 Nov 2026)

## Why
The handoff's Bellwood art order ends with side and rear foundations. A Studio probe showed the colossal temple's rear and flank walls rising sheer out of a flat cut, so its feet stood on nothing. This kit adds new foundation pieces around the base. The v20 temple, colonnade and gate stay as they were.

## Art
- **Generator:** `tools/blender/landmarks/bellwood_footings.py`.
  - It uses the colonnade, temple hall and gargoyle SDF helpers.
  - Sources are in `assets/source/landmarks/bellwood_footings/` (gitignored).
  - Run it with `FOOT_MODE=clay|bake` and `FOOT_PIECES`.
- **Bake:** the bake forces Cycles onto the CPU (`cpu_cycles`). This PC's AMD card fails Cycles' HIPRT setup and segfaults during the bake.
- **Three pieces.** Each pivot is at the centre of the wall contact on the bed, with the front facing +Y. All are placed at Scale 2.5.
  - `Bellwood_FootingBedrock`: a carved shelf of bedrock with two courses of masonry, moss pads and vines.
    - Sub-meshes: Stone 1,672, Rock and Rock_2 about 14k each, Vine and Vine_2 13,332 each.
  - `Bellwood_FootingButtress`: a stepped masonry buttress on a rock toe.
    - Sub-meshes: Stone 11,788, Rock 7,298, Vine 6,152.
  - `Bellwood_FootingScree`: fallen blocks and rubble spilling from the wall.
    - Sub-meshes: Stone 1,144, Rock 10,172, Vine 792.
- **Textures:** Poly Haven CC0 `rock_04`, `dark_rock` and `bark_willow_02` moss, all already credited. The rock is tinted cool and wet to match the temple stone. Maps are 2048, and no mesh was decimated.
- **Upload:**
  - Parts are in `assets/build/bellwood_footings/upload/`. Bedrock is split into two parts, and every part is under 20 MB.
  - The ledger is `uploads/win_footings_landmark_ledger.json`. All four parts were Approved.
  - The readback added 3 pieces and 11 subs to `assets/LANDMARK_KIT_UPLOADED.json`. Only additions were merged.

## Placement
- **Layout:** `LandmarkLayout` Basin.ColossalTemple.Footings lists 17 pieces in temple-frame space (+Z towards the exit, +X right).
  - Rear wall: three buttresses, two bedrock shelves and four scree spills, two of them at the corners.
  - Each flank: one bedrock shelf, one buttress and one scree.
  - Right lower terrace: one bedrock shelf and one scree.
  - The left lower terrace has none, because the gate towers dress it.
- **Build:** `LandmarkWorld.footings` builds them only after the whole colossal pack has placed. Stone and Rock use Hull collision.
- **Fit test:** `tools/test_bellwood_fit.luau` checks every piece:
  - it stays inside the shore;
  - it clears the gate towers and the causeway;
  - it sits on a back or flank wall, never on the stair.
  - Result: 10 passed.

## Verification
- **Unit tests:** `tools/test_kit_registry.py` passes 22 tests, including a new test that `bellwood_footings` is a landmark pack.
- **verify_all:** all 14 stages pass. Digest 306/4095978/1907997882 matches Studio Edit.
- **Single-client Play:** all 17 pieces built, 61 MeshParts on server and client.
  - The rear, left flank and right flank were inspected with a brightened client grade.
  - The buttresses and shelves seat against the walls and rise out of the lake water. No piece floats or leaves a gap.
- **Two-client Play:** not run. The footings are static scenery with no gameplay.
- **Save:** Development v98. Never published.

## Open
- Root grip on the temple tree is still a creator decision. The handoff says to use a new method or ask the creator.
- Two-client Sutra ally-heal check, carried over from win-111.

# win-105: Bellwood red maple leaves, colonnade sources rebuilt (Windows, 27 Nov 2026)

## Maple leaves (concept bellwood_3)
- Generator: `tools/blender/landmarks/bellwood_maple.py` (reuses the `bellwood_lotus.py` sheet, relax and render helpers).
  - One 2048 atlas, `Vesp_Bellwood_Maple__Leaf`. It has four quadrants: fresh crimson, turning orange, waterlogged maroon and underside.
  - Seven pointed lobes plus a petiole. Blades are 0.008·S thick so no light rim shows.
  - Waterlogged leaves sit lower and tilt as they sink.
- Pieces, both a single sub-mesh well under the 18k cap:
  - `Bellwood_MapleDrift`: 32 leaves, 12,672 tris, 13.8 × 8.8 studs. Asset 83630484532494.
  - `Bellwood_MapleRaft`: 24 leaves, 9,504 tris, 7.9 × 5.6 studs. Asset 75320334726445 (the pilot).
  - Both Approved.
- Pipeline:
  - Embedded with real Pillow (`work/.venv`) and `VESP_NORMAL=jpeg`; one part per piece, about 8 MB each.
  - Uploaded with `upload_batch.py`; ledger at `uploads/win_maple_landmark_ledger.json`.
  - Readback merged into `LANDMARK_KIT_UPLOADED.json` as additions only (36 lines added, 0 removed).
  - `bellwood_maple` added to the `landmark` packs.
- Placement in `Basin.Shallows`, all Scale 1 / Float 0.15:
  - Drift at (470, −95) and (421, −50), on the right of the exit view.
  - Raft at (439, −14) and (463, 46), on the left.
  - The first hand-picked spots sat on the walk or outside the reveal cone. These came from a sweep against the loader test's own shore, causeway and view checks.
- New tests (written first):
  - `test_landmark_kit_includes_maple_pack`.
  - Loader check: three or more maple drifts within 120 studs of the exit, at least one on each side.
- Results:
  - `test_kit_registry`: 20 OK. Loader: 234/0. Layout: 80/0.
  - verify_all: SUCCESS.
  - Digest 295/3940250/463588367 matches Studio.
- Play, single client:
  - All four models loaded at Y 150.65, on the 150.50 water.
  - The overlook capture shows red and orange drifts on both sides of the walk: `captures/win/bellwood_maple/win105_exit_maple_overlook.jpg`.
  - Saved to Development v71.
  - Multiplayer and device not run.

## Colonnade sources
- The Mac originals could not be recovered, so I rebuilt them from the mac-103 generator into `assets/source/landmarks/bellwood_colonnade/`. That folder is gitignored.
  - Triangle counts match mac-103 per sub-mesh: Standing 10088/4728/1236, Toppled 9048/3204/1236.
  - Sub-mesh names match the registry, and `kit_registry.py landmark --check` passes.
  - The uploaded assets are unchanged, so no re-upload was needed.
- Bake notes:
  - The bake needs the CC0 Poly Haven `distressed_painted_planks` 2k maps (Rob Tuytel, already credited).
  - On this AMD PC, bake with `--cycles-device CPU`; the HIP driver crashed on Toppled.
- Not yet pushed to the `landmark-assets-2026-11-21` recovery branch.

# win-114: Amberfall's Broken Ravine Bridge (Windows, 28–29 Nov 2026)

## Why
LANDMARK-BUILD-SPEC §2 is next in the build order now that Bellwood's art order is done (win-110 to win-113). This iteration builds the Broken Ravine Bridge, matching concept `amberfall_2_broken_ravine_bridge.webp`. The Cliff Monastery comes next.

## Site
- **Location:** the chasm bend at (-6050, -2600) in GoldenRavine, 550 studs south of the AmberfallCrossing. The front (Yaw 180) looks north up the chasm at the crossing.
- **Origin:** the chasm centre line at deck level (Y 292). The rims here are at 287–297.
- **Sampled profile, |x| from the centre line:**
  - upper ledge about -130 at 175–202;
  - lower ledge about -279 at 112–153;
  - floor about -445.
- **Layout test (`test_landmark_layout` §8, 99 passed):**
  - The towers stand within 9 studs of the rim: west 2.9, east 6.5.
  - The pier centres and inner faces stand on the lower ledges, and the arch springs clear.
  - The short bays open above the upper ledge.
  - The centre has 300+ studs of open chasm under the deck.
  - The crossing sees the deck over open air.
  - No road runs through the towers. The nearest placed thing is 421 studs away (G3_Grotto).

## Art: `tools/blender/landmarks/amberfall_broken_bridge.py`
Set `BRIDGE_MODE=clay|bake`. Sources go to `assets/source/landmarks/amberfall_bridge/`, which is gitignored and rebuilt by the generator.
- **Towers:** pagoda-capped gothic towers on both rims.
  - Gate stage with archivolts and a rose over the gate.
  - Belfry lancets with tracery.
  - Quatrefoil parapet, corner buttresses with crocketed pinnacles.
  - Two pagoda tiers with lattice screens, bronze bells and a gilt finial.
- **Abutments:** blind lancet and quatrefoil roundel.
- **Bays and piers:** a short bay sits on each upper ledge. A massive battered pier on each lower ledge has cutwaters and turrets.
- **Great arch:**
  - Pointed arch with two recessed orders and a hood.
  - Stacked lancet arcades above it.
  - The crown has collapsed: the last voussoirs sag, and the keystone and arcade bays are torn and ragged.
- **Deck:** balustrades with quatrefoil panels and a corbel table. The last slabs tilt and drop.
- **Gap:**
  - Three rusted chain swags.
  - Hanging chains ending in masonry lumps or rings.
  - Torn red banners with a gold lotus emblem hang on the swags and the towers.
- **Bake:**
  - 14 roles at 2048 on Poly Haven CC0 sets, already credited in THIRD_PARTY: medieval_blocks_03, roof_slates_02, distressed_painted_planks and metal_plate_02.
  - LOW totals 198k tris, split into 21 subs, each under 17.5k. Nothing is decimated.
  - The GLB is 9.6 MB. Embedded and split, it makes seven parts of 8–18 MB.
- **CPU only:** the AMD card failed this bake twice. First it ran out of HIP memory (exit 127, no maps). Then HIPRT failed even with the scene device set to CPU. `cpu_only()` now also sets the Cycles compute device type to NONE. A small AO test bake proved the fix, and the full bake then took 27 minutes.
- **Renders:** `renders/*_baked_{concept,crossing,front,deck,gap,tower,q34}.png`. The concept angle matches the key art.

## Game
- **LandmarkLayout `AmberfallBridge`:**
  - Region, Origin, Yaw and Span.
  - Pieces.Bridge, with Foot (0, -300, 0.695) from the manifest bbox. The pier feet are at -300.
  - Ten terrain Seats: rims cleared to the deck line, sandstone tower beds, approach pads, and rock under each abutment and pier.
  - Gorge: two mist banks low in the chasm and an amber leaf sheet over the deck.
- **LandmarkWorld:**
  - Fidelity: the TowerW/E and DeckW/E roles collide precisely. Everything that hangs in the chasm is non-colliding.
  - `seats()` and `gorgeFx()` run only once the piece has placed. Seats are written after `waitReady(region)`.
  - `World.Textures` is injectable for tests.
- **Registry:**
  - `kit_registry.py` lists `amberfall_bridge` in the landmark kit.
  - `test_kit_registry` passes 24 tests.
  - `test_vesperhold_loader` passes 237. New checks: the bridge build writes every seat and hangs its weather, and a missing kit writes nothing. The Bellwood fill counts now mark only the Forest region as ready.

## Verification
- `verify_all`: all local checks pass, with the place built at `work/verify.rbxlx`.
- **Upload: not done.** Roblox Studio stopped answering MCP: `open_cloud_invoke`, `get_studio_state` and `screen_capture` all time out, and desktop screenshots time out too. The Studio process reports as Responding at 134 MB, as if paged out with the screen locked or asleep.
  - Parts waiting: `assets/build/amberfall_bridge/upload/` (seven GLBs).
  - Ledger: `uploads/win_amberfall_bridge_landmark_ledger.json`.
- **Play:** not run. With no registered piece, the loader warns and writes no seat or weather, so the game is unchanged.

## Next
1. Upload with `ASURA_CLOUD_STUDIO=<Development window id>`, pilot p7 first.
2. Make the ledger paths relative.
3. Readback-merge the additions only, then run `kit_registry.py landmark`.
4. Single-client Play: placement, seats, deck collision, the view from the crossing, mist and leaves.
5. Save Development.
6. Then the Cliff Monastery.

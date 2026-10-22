# Shrine of the Ascendant — lobby rebuild (2026-10-21/22)

The Sanctuary lobby was rebuilt from `outputs/lobby-concept-2026-10-21/` on a new modular kit made in
Blender, uploaded through Studio and stored in the Rojo tree. The imported veiled statue and sacred tree
are untouched. The bonfire → stairs → gate → statue sightline and every gameplay identifier are kept.
The saved place `outputs/AsurasPath.rbxlx` is rebuilt from this checkout; the pre-rebuild copy is in
`backups/`. Nothing was published.

## Screenshots (`screenshots/`)

Each before/after pair uses the same fixed camera (`tools/qa/lobby_capture.py` CAMERAS), with HUD hidden:

| View | Before | After |
|---|---|---|
| Entrance (bonfire up the axis) | `before_entrance.jpg` | `after_entrance.jpg` |
| Elevated layout | `before_elevated.jpg` | `after_elevated.jpg` |
| Gameplay height | `before_gameplay.jpg` | `after_gameplay.jpg` |
| Statue terrace | `before_terrace.jpg` | `after_terrace.jpg` |
| Forge approach | `before_forge.jpg` | `after_forge.jpg` |
| Duel court approach | `before_duel.jpg` | `after_duel.jpg` |

`after_player_camera_hud.jpg` is the real third-person camera with the HUD on. `iter/` keeps the correction passes
(iter1–5, lighting/water/sky experiments, rest/Lin/Gao/gate tests).

## What changed

- **Kit (Blender, `tools/blender/lobby_kit*.py`, `lobby_textures.py`)**: 34 pieces, 47 single-material MeshParts,
  47,280 triangles in total. Hip-and-gable and pyramidal roofs with curved eaves, rafters, ridges, horns and tile ends; gallery bays;
  lacquered columns, stone bases, bracket sets, architraves; carved balustrade bays and posts (level and 1:2 stair);
  stone and hanging lanterns; dragon-crest and broken stelae, banded ruin pillars, a fallen pailou; basin coping;
  bonfire dais and paving medallion; gate plaque; layered karst cliffs, spurs, spires and outcrops; cloud puffs,
  crimson maples, shrubs and a cloth banner. Eleven tileable 1024/512 PBR sets (paving, stone, roof, lacquer, timber,
  bronze, rock, cloud, foliage, bark, banner) are generated in numpy. Budgets: ≤19,500 tris per part, ≤2,400 for repeated pieces.
  No violations. Editable sources: `assets/build/lobby_kit/*.blend`. GLBs, manifests and QA renders are kept alongside.
- **Upload/persistence**: imported via Studio 3D Importer (Creator: Me), extracted by `tools/assets/extract_lobby_kit.py` into
  `assets/models/AsuraLobbyKit.rbxmx` → `ServerStorage.AsuraLobbyKit`. All 47 parts have real uploaded MeshIds and four uploaded
  maps, checked against the manifests (sizes within 1%). Seven `MaterialService.Asura*` MaterialVariants reuse those maps
  so primitive floors match the meshes (`tools/assets/register_lobby_kit.py`). IDs: `assets/LOBBY_KIT_UPLOADED.json`, `assets/ASSET_IDS.md`.
- **Sky/lighting**: an original six-face golden-hour cubemap (`tools/assets/make_sunset_sky.py`, uploaded, face mapping verified in Studio).
  The Sanctuary profile is now 17:30, with warm haze, readable fill above the combat floor and the new sky
  (`EnvironmentProfiles.skyFor`). Other regions keep their profiles and default sky (Monastery checked after portal travel).
- **Builders (all ≤150 lines)**: `SanctuaryKit` (placement, shared surfaces, collision helpers), `SanctuaryRails`, `SanctuaryFrame`,
  `SanctuaryProps`, `SanctuaryCourtyard`, `SanctuaryCloisters`, `SanctuaryForge`, `SanctuaryDuelCourt`, `SanctuaryAscent`,
  `SanctuaryTerrace`, `SanctuaryHorizon`. `SanctuaryService` shrank from 942 to ~460 lines and keeps all behaviour (spawn, portal, fall catch,
  smith prompts, refill, interactables). `SanctuaryColossus` keeps the statue mount and restyles the terrace. `SanctuaryApproach` keeps every route box
  and restyles it, adding a pavilion over the Well of Descent.
- **Layout deltas**: stair width 14 → 18 (`WorldDefinitions.StairWidth`). The forge walkway leaves its south rail open onto the Loggia Eaves
  service ledge. The duel court's SE edge opens onto a landing under the spectator-balcony stair. Four `WellColumn` layout boxes were added in
  `SanctuaryRoutes` so the offline suites still see every collider. The old Phase 5 iron portal gates are no longer placed.
- **Collision**: kit meshes never collide or query. Movement uses primitive floors, one invisible wall per rail run, column/lantern/stele/trunk boxes.
- **Tooling/tests**: `tools/qa/lobby_capture.py` (fixed cameras, MCP calls), `tools/qa/studio_sync.py` (script-only push into an open Studio),
  `tools/qa/lobby_walk.json` + `LobbyWhere.luau` (route walk). Tests were updated for the deliberate lighting change, the new sky rule and the
  added builders. `lune_compat.py` long-string edge case fixed.

## Verified (Studio Play on the rebuilt place and local suites)

- Boot: server and client ready, scripts match the build digest, no game-script errors. The only content warning is the long-standing `203785492` asset-type mismatch.
- Walked with the real character (Studio navigation): bonfire, forge walkway/hall/smith, eaves service ledge, duel walkway/court/ring band,
  spectator landing, south plaza, pilgrim walk, Well pavilion, north plaza, stairs, landing. All reached; no snags recorded.
- Rest at the Primal Bonfire ("checkpoint set · flask refilled"). Lady Lin dialogue opens. Gao's prompt opens the Arsenal; refill/transmute prompts are present.
- The Ascension gate portal delivers to the Monastery Gate (0, 3, −728), which shows Monastery lighting and its sky.
- Fall off the east edge → cloud catch returns to the bonfire spawn (clouds don't collide).
- Optional routes (2026-10-22): Reliquary: from the Well pavilion's east gap across the three cloud shards to the isle;
  the cache claim returns `SanctuaryReliquary = true`. Loggia Eaves: climbed the ladder from the forge platform to the
  lookout deck; the claim returns `SanctuaryEaves = true`. Claims used Studio's mock persistence, so no real save data was written.
  Sunken Crypt: the Well portal → Descent Landing (520, 33, 1062, region SanctuaryDepths) → return portal → Well of Descent
  (0, 603, 984), with the Sanctuary sunset sky and 17:30 lighting restored.
- Fix from that walk: the forge's new south balustrade blocked the ladder's north face, the only face that reaches the deck
  (climbing the south face runs into the deck's underside). The rail now leaves a 6-stud gap at the ladder (`SanctuaryForge`).
- `bash tools/verify_all.sh`: see `verify_all.log` (all 14 steps; place built to `builds/verify.rbxlx`).

## Measured

Sanctuary after: 1,084 kit MeshParts, 692 primitives (386 colliding), 69 lights, 34 emitters/fires. Before: 1,479 BaseParts.
Placed kit geometry ≈ 643k triangles at full detail (Roblox automatic LOD reduces it with distance). The biggest contributors are the carved rail bays
(88k), cliff shelves (75k), stone lanterns (53k) and rail posts (46k). Studio client: RenderCPU ≈ 3.4 ms/frame, memory ≈ 3.7 GB (whole Studio
process). The window was in the background during measurement, so macOS throttled it to ~15 fps. That frame rate is **not** a valid GPU/FPS
reading, and no GPU frame time was reported.

## Not done / unverified

- Frame time on a focused Studio window, mobile or console devices; draw-call counts (Studio did not expose them). The rail/lantern triangle
  totals are the first place to cut if a phone struggles (fewer posts, lower-poly lantern, shorter rail runs).
- No duel was run. In a signed-in two-client test, both players joined but neither got a character. The cause was a
  pre-existing bug, now fixed: enemy entity ids counted down from −1, and Studio gives local test players UserIds −1, −2, ….
  `ensurePlayer` found a live enemy under the player's id and skipped spawning. Enemy ids now start at −1,000,000
  (`CharacterService`). Live servers were never affected, because real UserIds are positive. The fix passes the full verifier,
  but a duel hasn't been re-run with it: starting a two-client session needs Studio's toolbar (Test › Server and Clients,
  then Add Clients ×2). The ring geometry and id are unchanged. The terrace pilgrim daises were not walked.
- Frame time (`tools/qa/LobbyFrameTime.luau`, results in `qa/frame_time.txt`): **not a valid frame-rate reading.** Every
  lobby-on view ran at exactly 66.7 ms (15 fps), which is macOS's background-app cap, so Studio wasn't the active app.
  Render-CPU time with the lobby on was 2.9–5.5 ms per frame at all four views, so CPU-side rendering isn't the limit.
  GPU time isn't exposed on this Mac. A real reading still needs Studio active for the whole ~40 s run.
- Multiplayer, combat in the lobby and the camera in tight spots (under gallery roofs, beside the gate bays) were only checked at the shown views.
- A very high camera (300 studs above, `aerial`) renders only haze. The cause wasn't found; the required elevated view is fine.
- Art limits: banner and foliage meshes are low-poly blobs at close range; the forge chimney and some primitive props (bench, barrels, coal)
  are still blocky; the statue terrace remains a large open disc as designed. Distant waterfalls and buildings were not added (optional in the brief).
- The extra Studio windows have been closed. The saved `outputs/AsurasPath.rbxlx` was rebuilt after the last fix, and its scripts match the source exactly.
  The one remaining Studio window is the scratch import copy, with test edits in it; close it without saving.

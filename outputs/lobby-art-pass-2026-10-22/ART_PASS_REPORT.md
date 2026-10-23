**SUPERSEDED:** See the [23 October monumental art-pass report](../lobby-monumental-2026-10-23/ART_PASS_REPORT.md) for the current implementation and acceptance record. This older draft is retained as history; its zero-density atmosphere decision, smaller figure, cloud budgets and pending evidence do not describe the current lobby.

# Shrine of the Ascendant — art pass

Draft prepared 23 October 2026, Australia/Sydney. Final Studio acceptance, final comparison images and focused performance measurements remain pending below. This report describes persistent source/assets and existing evidence; it is not a claim that the final scene has passed every acceptance check.

## Intent and preservation

This pass follows `outputs/lobby-concept-2026-10-21/CLAUDE-LOBBY-REBUILD-PROMPT.md`, its two original concepts, the current-lobby reference, and the four additional detail references in `outputs/lobby-references-2026-10-22/`. The main correction is the missing ethereal mountain-and-cloud background, followed by water, foliage, stone values, the forge, duel presentation and the empty upper-terrace foreground.

The imported Veiled Ascetic and sacred tree were not remodelled or reprocessed. A read-only comparison of all 33 imported Figure/Canopy/Roots MeshParts against `backups/AsurasPath.before.rbxlx` found no changes to their MeshIds, sizes, CFrames, SurfaceAppearance map references, texture packs, colors or alpha modes. The new crimson crown is separate decorative foliage attached to sampled points on the existing tree. The existing bonfire → stairs → gateway → figure axis remains the composition's centre.

The existing gameplay services continue to own spawn, rest, dialogue, smith/refill actions, story travel, optional routes, falls, duels and wagers. Cosmetic ring and spectator-balcony work does touch their assembly entry points; the preservation tests and remaining live checks are listed separately below. Unrelated checkout changes are not part of this art-pass summary.

## Implemented environment work

| Area | Persistent change |
|---|---|
| Mountain realm | A new original panoramic golden-hour cloud sea and pagoda-crowned karst background, plus 24 placed three-dimensional karst peaks to provide scale and parallax around the lobby. Eight selected peaks carry small summit pagodas. Five visible cascades use 15 reused waterfall/foam meshes and five sparse mist emitters. No distant point lights or movement collision were added by the vista builder. |
| Cloud layer and foundations | Hanging rock shoulders reinforce the floating courtyard foundations. The old broad cloud meshes were removed from the continuous background; the panorama supplies that surface, with 12 bounded local mist emitters for parallax around island and mountain feet. |
| Sky and atmosphere | The Sanctuary uses the new six uploaded faces. The top/bottom projection was corrected for inside-cube handedness and Roblox cap orientation. Sanctuary exploration/combat profiles retain neutral readable fill and golden-hour sun; engine Density/Haze/Offset/Glare are zero because the panorama already contains distance haze and the engine veil obscured the lower sky at elevated cameras. Other regional profiles retain their authored values. |
| Sacred-tree crown | 28 branch attachment points drive 84 static double-sided crimson branch cards. Attachment points are relative to named existing tree chunks, so the crown follows their final mounted pose without changing hero geometry. No foliage update loop, extra light, or foliage collision is added. |
| Secondary foliage | Existing secondary maple bark is reused, while rounded foliage meshes are replaced by pointed, transparent crimson maple-branch sprays. Shrubs use the same texture for a consistent leaf language. |
| Courtyard finish | Both pools use shallow Terrain water, with the original solid floor/rim envelopes concealing voxel shore rounding. Coping is divided into short bays rather than stretched over full basin lengths. Dark waterlines, coping shadow courses and recessed paving joints improve close-range scale. Existing route openings remain intact. |
| Materials and lanterns | Stone/paving values move toward blue-grey, lacquer toward dark vermilion, bronze stays restrained, and lantern paper/glow is warmer and less glaring. Existing curved roofs, brackets, railings and architectural meshes remain reusable kit pieces. |
| Gao's forge | A recessed hearth, layered masonry hood, soot, grate, iron-banded chimney, rack feet and banded barrels improve the workshop. Timber posts, cantilevers, knee braces and a cross tie visually support the existing eaves lookout while keeping its ladder volume clear. Smith, quench trough and interaction ownership remain in the original service. |
| Duel promenade | A Sanctuary-only finish changes visible surfaces to stone and restrained bronze, adds an inlaid seal, coping and lantern posts, and hides the old cage-like visual pieces. The original ring parts, thresholds, barriers, positions, sizes and physics flags remain owned by ColosseumService. |
| Spectator balcony | Decorative masonry corbels, timber bearings, lacquered posts/brackets, a stair cheek and carved rail overlays give the existing balcony a credible structure. Its original deck, stair, rail collision and wager interaction are retained. |
| Upper landing | A pair of imported guardian lions on simple stone collars frames the landing at X ±17, outside the central stair/gateway route. |
| Statue forecourt | Two asymmetric rock gardens centred at terrace-local X ±56, Z 205 add shelves, 6–9 stud crags, low carved retaining fronts, crimson maples, shrubs and sparse leaf litter. A stone bench faces the figure. These additions are confined to their own noncolliding folder; the procession, existing ruin collision and pilgrim daises remain clear. |

The rock-garden addition is authored as 96 BaseParts including 30 MeshParts, with 54 branch cards / 110 Decals, no lights or emitters, and no active collision/query/touch flags. These are source-derived addition counts, not a final whole-scene profiler reading.

## Reusable assets and provenance

| Deliverable | Sources and integration |
|---|---|
| Karst kit | `tools/blender/sanctuary_vista.py`; editable `assets/build/sanctuary_vista/AsuraSanctuaryVista.blend`; import `AsuraSanctuaryVista.glb`; `manifest.json`, `validation.json`, `preview_sheet.png` and `preview_crown.png` in the same folder. Four templates / seven single-material MeshParts / 53,002 triangles total; largest part 18,928 triangles. |
| Vista library | `assets/models/AsuraSanctuaryVista.rbxmx`, mapped to `ServerStorage.AsuraSanctuaryVista`. `tools/assets/extract_sanctuary_vista.py` validates the imported model/part names, seven unique uploaded MeshIds, actual local centres/sizes/identity rotations, rock Color/Normal/Roughness maps, optional metalness, and referenced SharedStrings before extracting. `assets/SANCTUARY_VISTA_UPLOADED.json` records the IDs and GLB hash; eight SharedStrings were retained. Plain moss/water parts intentionally have no SurfaceAppearance. |
| Sky | `assets/build/sanctuary_sky/panorama.png`, generated with built-in imagegen; complete prompt in `prompt.md`. Native image is 1774 × 887. `tools/assets/panorama_to_sanctuary_sky.py` projects it into six 1024-square faces. `assets/SANCTUARY_SKY_UPLOADED.json` records the actual uploaded image IDs and face mapping, including corrected cap uploads. |
| Crimson foliage | `assets/build/sanctuary_sky/crimson_branch.png`, 1774 × 887 with alpha, generated with built-in imagegen; complete prompt in `crimson_branch_prompt.md`. The uploaded image is recorded as `branch` in `assets/SANCTUARY_SKY_UPLOADED.json` and referenced by `PresentationAssets.Textures.CrimsonBranch`. The older leaf/scatter masks retain their existing ambientCG LeafSet024 credit. |
| Guardian lion | `assets/build/guardian_lion/Asuraguardianlion.glb`, editable `AsuraGuardianLion.blend`, `cleanup.py`, raw generation in `source/`, and `validation.json`. One mesh/material, 17,622 triangles, UVs/normals and complete 1024 PBR. The installed pipeline used Pollinations for the reference image and microsoft/TRELLIS.2 for reconstruction. `assets/models/AsuraGuardianLion.rbxmx` and `assets/GUARDIAN_LION_UPLOADED.json` preserve the uploaded eight-stud template and real map IDs. `tools/assets/extract_guardian_lion.py` supports extraction. |
| Existing architecture | `assets/models/AsuraLobbyKit.rbxmx`, `assets/LOBBY_KIT_UPLOADED.json`, the existing `tools/blender/lobby_kit*.py` pipeline and shared `MaterialService.Asura*` variants are reused. They remain separate from the new vista and guardian libraries. |

Vista geometry is original procedural Blender work. Its rock Color/Normal/Roughness reuse the already-present Poly Haven `rock_face_03` CC0 source, resized to 1024. The optional black metalness comes from the existing generated lobby kit. No new third-party rock model or texture was downloaded. This reuse is recorded in `assets/CREDITS.md`.

The guardian's generator/procedure is recorded in its README. Existing `assets/CREDITS.md` still leaves the older hero base-sculpt generation service unspecified; this is a pre-existing provenance gap, not a new hero asset made in this pass.

## Source and build map

- Landscape and hero foliage: `SanctuaryHorizon.luau`, `SanctuaryVista.luau`, `SanctuaryCanopy.luau`, the small canopy call in `SanctuaryTitan.luau`, `SanctuaryTerrace.luau`.
- Courtyard, architecture and props: `SanctuaryCourtyard.luau`, `SanctuaryKit.luau`, `SanctuaryProps.luau`, `SanctuaryForge.luau`; the existing Frame/Rails/Cloisters builders and kit are retained.
- Landing and duel assembly: `SanctuaryAscent.luau`, `SanctuaryRingFinish.luau`, its Sanctuary-only call in `ColosseumService.luau`, and decorative supports in `WagerWorld.luau`.
- Persistent presentation: `src/shared/EnvironmentProfiles.luau`, `src/shared/PresentationAssets.luau`, `src/server/Services/EnvironmentService.luau`, `default.project.json`, the three mapped asset libraries above.
- Current local build target: `outputs/AsurasPath.rbxlx`, produced by `python3 tools/build.py`.

All unqualified builder filenames above are under `src/server/Services/`. Source changes and asset-library changes persist through rebuilding; script-only `studio_sync.py` does not replace mesh libraries.

**Final identity check pending:** the read-only audit during ongoing work found 234 mapped Luau scripts and 234 in the saved place; only `WagerWorld` and `SanctuaryVista` differed at that instant. Rebuild after the last edits and record a fresh Studio/build SourceDigest match here. This is a transient work-in-progress comparison, not a final divergence claim.

## Verification already evidenced

| Evidence | Recorded result and boundary |
|---|---|
| `qa/verify_all.log` | A completed 14/14 local verifier run: progression runtime 85 checks, campaign reachability 251, campaign builder 27, Colosseum runtime 135, combat presentation 161, audiovisual runtime 43; every source syntax-compiled and a temporary place built. The inspected run completed at 02:45 Sydney on 23 October. Later art/profile/source edits mean this is **pre-final-art evidence** until the final rerun is recorded. |
| `qa/audiovisual-final.log` | 43 audiovisual runtime assertions, 13 existing imported templates / 56 complete PBR MeshParts, and eight existing PBR exports passed. These are engine-fake / available-media checks, not a visual acceptance or a comprehensive validator of every newly added mesh. |
| `qa/colosseum-final.log`, `qa/colosseum-balcony.log` | Colosseum runtime: 135 passed, zero failed, under local mocks. The updated fixture checks that Sanctuary finishing leaves original ring geometry/physics and barrier visibility intact, and that added decoration cannot collide/query/touch. No live multi-client or DataStore claim. |
| `qa/combat-presentation.log` | Combat-presentation suite: 161 passed, zero failed. A final atmosphere-aware rerun remains to be attached if later than the stored evidence. |
| `qa/progression-balcony.log` | Contains an earlier harness failure (`Unmapped require in WagerWorld`). It is retained as iteration evidence and is superseded by the later full verifier's progression-runtime pass; it is not a passing live balcony test. |
| Vista extraction / validation | Seven unique uploaded mesh references, complete required rock PBR references, manifest transforms/sizes, eight SharedStrings; all seven exported parts have UVs, normals and one material. |
| Guardian validation | One 17,622-triangle UV/normals mesh, triangle budget passed, cleaned GLB hash matches the registry. |
| Hero preservation audit | All 33 imported hero MeshParts match the pre-pass backup for geometry references, sizes/transforms and PBR properties. |
| Targeted compilation | New canopy and final terrace-garden modules syntax-compiled locally. Compilation does not verify engine appearance or camera clearance. |

`qa/verify_all.initial.log` and `qa/verify_all.pre-final-art.log` retain earlier iterations. The temporary place build used by `verify_all.sh` leaves the saved `outputs/AsurasPath.rbxlx` unchanged.

## Representative section and final screenshots — pending

The existing `screenshots/section_comparison.jpg` records the representative courtyard comparison before the finish was extended to both pools. Baseline captures exist for entrance, elevated, gameplay, terrace, forge and duel views. They are evidence of the starting state / representative iteration, not final after images.

Fill this table after the final source/build sync, using the same fixed cameras in `tools/qa/lobby_capture.py` and a clean Play session:

| View | Before | Final after | Notes |
|---|---|---|---|
| Entrance | `screenshots/before_entrance.jpg` | **PENDING** | Bonfire → gate → pale figure, crimson crown, continuous background. |
| Elevated layout | `screenshots/before_elevated.jpg` | **PENDING** | Cloud sea below the horizon; island/terrace silhouettes and route layout. |
| Normal gameplay height | `screenshots/before_gameplay.jpg` | **PENDING** | Floor/water readability and actual player scale. |
| Statue terrace | `screenshots/before_terrace.jpg` | **PENDING** | Cap seam, new gardens, figure/tree preservation and foreground scale. |
| Forge | `screenshots/before_forge.jpg` | **PENDING** | Hearth, support structure, smith and ladder approach. |
| Duel promenade | `screenshots/before_duel.jpg` | **PENDING** | Accessible threshold, clear fighting floor and spectator structure. |
| Real third-person camera with HUD | — | **PENDING** | Ordinary camera collision/clearance and playable presentation. |

## Final Studio playtest — pending

Record actual results and evidence here; the old rebuild's playtest is useful baseline history, not a substitute for rerunning these on the current scene.

| Required check | Final result / evidence |
|---|---|
| Clean boot, correct place/build identity, server/client Output | **PENDING** |
| Spawn and rest/checkpoint | **PENDING** |
| Lady Lin dialogue | **PENDING** |
| Master Smith Gao dialogue/forge and quench refill | **PENDING** |
| Story gate → Monastery arrival and regional lighting | **PENDING** |
| Duel threshold and promenade access | **PENDING** |
| Spectator stair, balcony, Watch & Wager | **PENDING** |
| Well of Descent → Crypt → return, restored Sanctuary sky | **PENDING** |
| Reliquary jumps/cache, eaves ladder/cache | **PENDING** |
| Fall recovery to bonfire | **PENDING** |
| Stair/gateway, covered galleries, terrace/reveal-point camera clearance | **PENDING** |
| Two-client duel and reset/cleanup | **PENDING** |

Fresh Play is required after changing module sources: `require` caches and the client profile key can retain earlier values in an existing session. The prior apparent sky/hero-texture failure was resolved in a clean session; all seven new sky/branch IDs were identified as images. The cap projection and final zero-veil atmosphere still belong in the final captures above.

## Final performance and scene budget — pending

- Focus Studio for the full sample; the previous rebuild's 15 fps background-app cap is not a valid rendering measurement.
- Record hardware, Studio graphics quality, viewport dimensions, camera positions, sample length, average/p95 frame time and RenderCPU. Use `tools/qa/LobbyFrameTime.luau` or an equivalent focused bounded sample, with and without the Sanctuary if practical.
- Record final Sanctuary BaseParts/MeshParts, colliding primitives, Decals, lights and emitters. The authored local budgets are not measured final scene totals: 24 mountains, 15 cascade/foam meshes, five cascade mist emitters, 12 local cloud/foot mist emitters, six summit foliage cards and 84 hero crown cards.
- Mobile/console performance and GPU time: **PENDING / NOT CLAIMED**.

## Known stylistic limits and remaining work

- The background combines a static raster panorama with a bounded three-dimensional vista. The distant painted sky has no translation parallax; its native 1774 × 887 image limits fine detail despite 1024-square cubemap exports.
- Crimson foliage uses intersecting alpha cards. It has pointed botanical silhouettes and internal gaps, but shallow card depth remains visible from some angles; transparency/overdraw needs the final rendering measurement.
- The original upper terrace remains a broad circular floor. Focused gardens, ruins and layered edge rockwork improve the approach without replacing that established playable footprint.
- Waterfalls are decorative ribbon meshes and restrained mist rather than simulated flowing terrain water. Their final visibility and integration at all main viewpoints remain part of Studio visual acceptance.
- The guardian lions are naturalistic generated sculptures rather than traditional stylized foo lions. The requested pearl and lotus-scroll details are absent, and some chipped plinth edges remain; simple collars conceal the lower join. Their role is a secondary accent.
- Some small forge tools, benches, barrels and supporting masonry remain simple geometric props. The reference paintings contain substantially more hand-authored surface wear, carving and incidental detail than this game kit.
- Final after screenshots, current-build interaction acceptance and focused performance evidence are intentionally unfinished in this draft. No public publishing is part of this task.

## Final acceptance record — pending

**PENDING:** final build path/digest, final verifier result, completed screenshot table, completed live-play table, measured focused performance, and any remaining item explicitly carried into delivery.

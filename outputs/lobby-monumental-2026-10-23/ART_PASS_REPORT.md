# Shrine of the Ascendant — monumental art pass

23 October 2026, Australia/Sydney. Integrated target: `outputs/AsurasPath.rbxlx` in the current checkout. This report supersedes the 22 October draft, including its zero-density atmosphere decision and smaller figure. No experience publishing is included.

> Historical build record: the [23 October detail/device follow-up](../lobby-finish-2026-10-23/ART_FINISH_REPORT.md) updates the canonical source identity, landscape budget and device status, and resolves the local Rojo warning. Measurements and images below retain their original scope.

## Visual changes

The composition now follows the reference's hierarchy: a broad bonfire promenade between reflective pools, a grand stone stair, a double-eaved gateway, and the monumental seated goddess against the sacred tree. The forge and duel court remain on the lower courtyard tier, joined by covered galleries.

| Area | Implemented result |
|---|---|
| Golden-hour depth | Future technology / Realistic lighting, ClockTime 17.4, Brightness 2.2, diffuse 0.65 and specular 1.0. Real Atmosphere remains active: Density 0.38, Haze 2.2, Color 250/215/185, Decay 120/130/165, Glare 0.35 and Offset 0.2. |
| Post-processing | Bloom 0.25 / Size 24 / Threshold 2.0; SunRays 0.12 / Spread 0.45; ColorCorrection Contrast 0.15, Saturation 0.05 and Tint 255/246/236. Values live in `EnvironmentProfiles.luau`, with lighting technology persisted in `default.project.json`. |
| Monument | The figure is 150 studs high. Its imported geometry and PBR references are reused; the figure and existing binding roots receive the same 1.5× plinth-relative transform, preserving the roots wrapped around her robe and torso. The tree retains its original footprint and approximately 402-stud trimmed height. |
| Spacious procession | The central pool promenade is 48 studs wide, the main stair 30, and the arrival bridge 24. Terrace procession widens from 16 to 32 studs; flanking stelae and lanterns move out of that axis. Gameplay identifiers and route destinations remain in their original services. |
| Sacred terrace | Two raised prayer courts have broad five-step approaches, clean modular shrine roofs, carved fronts and asymmetric rock/maple gardens. Nine overlapping jagged Crown/Ridge masses replace the circular visible slab and its repeated underside ring. Original floor/core collision remains invisible. Seven thin mesh supports and two front flank supports carry the visible overhangs, with a 56-stud clear corridor over the staircase. |
| Cloud sea | Two overlapping local particle beds lie roughly 78–100 studs below the Y600 plaza, around Y500–522. Thirty-two cloud emitters connect the island to eight physical karst peaks at approximately 1,000–3,000 studs. Three intermediate peaks at 564–719 studs strengthen the silhouette through the required haze; six summits have modular pagodas. Five spillway cascades descend from carved courtyard lips into local spray. |
| Crafted lanterns | Stone pagoda and timber lantern housings enclose thin framed paper panes. Paper uses subdued warm Neon, RGB 151/101/58 at 0.35 transparency, with a small sheltered flame. Fifty-eight placed lantern lights meet the requested settings. Lin's carried lantern now has a metal roof, foot and four corner posts, plus a warm 1.2-brightness, 15-range shadowed light. A spatial audit covering the lobby and its external gameplay folders found no visible raw Neon placeholders. |
| Hearth and forge | The bonfire has a sunken stone bowl, jointed coping, stacked/split charred logs, fire, smoke and drifting embers. Its old flat emissive ring is replaced. Gao's recessed forge mouth uses dark basalt, a framed hearth and restrained fire. His legacy cyan interaction cube is hidden inside a carved stone seal; its original 2×2×2 prompt/collision anchor and callback remain. |
| Materials and water | Shared blue-grey stone/paving PBR, vermilion timber, charcoal curved roofs and restrained bronze unify the kit. Both shallow pools use reflective Terrain water with segmented coping, dark waterlines, leaf scatter and soft edge mist. |
| Living crown | Eighty-four double-sided branch cards provide pointed crimson foliage at 28 sampled limb anchors. Nineteen folded prayer-silk meshes hang from the branches. Secondary maples, drifting leaves and sparse water-edge mist use the same botanical language. |
| Side activities | The stone duel finish, spectator balcony supports and complete housed lanterns preserve the underlying ring, stair and wager ownership. The forge, Lady Lin, rest altar, story gate, Well of Descent and optional routes remain part of the working game. |

## Assets and persistent source

Architecture uses the existing Blender-authored `AsuraLobbyKit`: separate curved roofs/eaves, carved rail bays, timber pillars/brackets, folded cloth and stone props, with distinct shared PBR materials. Buildings and bridges were assembled from those crisp modules; no whole-building neural mesh was introduced.

The uploaded `AsuraSanctuaryVista` Crown/Ridge/Needle meshes supply distant mountains and the nine terrace cliff masses. The generator is `tools/blender/sanctuary_vista.py`; its editable `.blend`, GLB and manifests remain under `assets/build/sanctuary_vista/`. Each rock MeshPart is below 19,500 triangles; the foundation renders nine MeshParts / 170,352 triangles. Seven additional invisible MeshParts reuse baked collision data as thin ground supports, with two primitive supports beside the stair corridor. The three intermediate peaks and their pagodas add approximately 90,158 triangles. The rock maps reuse the existing Poly Haven Rock Face 03 CC0 scan. These assets are already integrated through Rojo-mapped `.rbxmx` libraries, with IDs recorded in `assets/SANCTUARY_VISTA_UPLOADED.json` and `assets/LOBBY_KIT_UPLOADED.json`.

The earlier pass's original imagegen sky and transparent maple branch remain integrated through `PresentationAssets.luau` and `assets/SANCTUARY_SKY_UPLOADED.json`. Source prompts, panorama, cutout and cube projection script are preserved. The eight-stud guardian lions reuse the earlier TRELLIS.2 output cleaned in Blender; `assets/GUARDIAN_LION_UPLOADED.json` records the actual imported mesh and PBR IDs. Updated provenance is in `assets/CREDITS.md`.

| Source group | Main files |
|---|---|
| Lighting and presentation | `src/shared/EnvironmentProfiles.luau`, `src/shared/PresentationAssets.luau`, `default.project.json`, `src/server/Services/EnvironmentService.luau` |
| Monument and terrace | `SanctuaryTitan.luau`, `SanctuaryCanopy.luau`, `SanctuaryColossus.luau`, `SanctuaryTerrace.luau` |
| Courtyard and architecture | `SanctuaryCourtyard.luau`, `SanctuaryAscent.luau`, `SanctuaryKit.luau`, `SanctuaryProps.luau`, `SanctuaryFrame.luau`, `SanctuaryApproach.luau`, `SanctuaryBonfire.luau` |
| Landscape and side activities | `SanctuaryHorizon.luau`, `SanctuaryVista.luau`, `SanctuaryForge.luau`, `SanctuaryRingFinish.luau`, `WagerWorld.luau`; existing gameplay assembly entry points are retained |

Unqualified builder paths above are under `src/server/Services/`. `python3 tools/build.py` rebuilds the integrated place. These are persistent source/library changes, not Play-session-only dressing.

## Studio comparisons

All comparison images are actual Studio captures. Baseline captures used Automatic graphics quality; final captures use quality 21. Panel layout changes the viewport aspect ratio, and the entrance/bridge cameras were reframed for the larger composition. These are visual comparisons, not a controlled performance A/B. The three final cameras set both CFrame and Focus; the bridge image uses a scripted camera at third-person height with the actual player and HUD, rather than claiming an unmodified camera-controller view.

| View | Before | After |
|---|---|---|
| Bonfire / entrance looking toward the goddess | [Before](screenshots/before_entrance.jpg) | [After](screenshots/after_entrance.jpg) |
| Elevated layout, cloud sea and side pavilions | [Before](screenshots/before_elevated.jpg) | [After](screenshots/after_elevated.jpg) |
| Third-person-height stone bridge | [Before](screenshots/before_gameplay.jpg) | [After](screenshots/after_gameplay.jpg) |

Additional captures: [Forge and carved smith seal](screenshots/forge_hearth.jpg), [closer elevated detail](screenshots/elevated_detail.jpg). The latter predates the final invisible supports and small NPC/seal cleanup; its terrain and architecture are unchanged. Files named `*_revision_needed.jpg` and `cloud_preview.jpg` are iteration records, not final views. A passing unit test does not certify visual fidelity.

Final cameras (position → target; vertical FOV): entrance `(0,606,935) → (0,650,817); 67.5°`, elevated `(175,735,1100) → (0,650,815); 60°`, bridge `(1.8,607,969) → (0,627,850); 70°`. Character root is held at `(0,603.1,956)` only for the bridge photo. Photo bindings, temporary visibility flags and anchoring are removed after capture.

## Verification and measurements

| Evidence | Result and boundary |
|---|---|
| `qa/verify_all.log` | Full local verifier passed 14/14 on the final source: progression 85 checks, campaign reachability 251, builder 27, Colosseum runtime 135, combat presentation 161 and audiovisual runtime 43. All source scripts compiled and the verification place built with the same source digest as the delivered place. |
| `qa/progression_final.log` | Earlier focused progression snapshot passed 85 checks and ending-credit checks. The complete final verifier above supersedes this snapshot. |
| `qa/combat_presentation.log`, `qa/audiovisual.log` | Focused authored-profile/media checks passed. Local engine fakes establish behavior and asset references, not rendered fidelity. |
| Final place / Studio source identity | `outputs/AsurasPath.rbxlx`, 3,124,010 bytes. All 234 mapped scripts / 1,672,825 source bytes agree between the freshly opened Studio Edit model, delivered file and verification build: SourceDigest `1060436377`. There are 238 mapped sources including libraries and 354 distinct asset IDs. SHA-256 and method are recorded in `qa/source_build_identity.json`. |
| Live route and interaction checks | Current build: main stair midpoint and upper landing reached at full health; controlled drops landed on east, west, rear and front overhang supports. Gao's replacement seal opens the Arsenal through a held Z input. Earlier same-pass checks confirmed rest/checkpoint, Lin dialogue, crossing/duel threshold, east prayer court and story-gate regional transition. `qa/live_checks.json` distinguishes current checks from earlier observations and seeded positioning. |
| Render diagnostic | Apple M1 / 8 GB, quality 21, 1221×543 viewport, elevated camera, 180 frames: mean 72.03 ms, p95 92.25 ms; RenderCPU mean 8.14 ms / p95 12.35 ms. Foreground focus was not established, so background throttling cannot be separated from GPU/scene cost. This is not a validated gameplay FPS result. Raw composition: approximately 1.65 million non-shadow scene triangles / 1,131 draw calls, plus 857,024 shadow triangles / 207 calls. See `qa/render_measurement.json`. |
| Whole-scene budget | Sanctuary folder: 3,378 BaseParts, 1,281 MeshParts, 444 colliding parts, 656 Decals, 1,233 SurfaceAppearances, 71 PointLights, 3 SpotLights and 53 enabled emitters. Whole Workspace: 10,740 BaseParts / 1,911 MeshParts / 3,379 colliding parts; other campaign regions are included in those totals. Authored cloud/cascade ceiling is 689 steady particles across 32 cloud and 5 cascade emitters, excluding leaves/fire. `qa/studio_visual_validation.json` records scope and exact profile values. |
| Loaded media and console | Preloading 3,170 Sanctuary mesh/surface/decal instances completed 1,957 callbacks with zero failures. The console still reports the pre-existing `203785492` asset-type mismatch; no source reference was found in this art pass. See `qa/preload_final.json` and `qa/studio_console.log`. |

## Remaining limits

- The composition and scale are substantially closer to the reference, but its fine cliff erosion, dense planted terraces, intricate relief carving and nuanced painterly sky are not fully matched. The current physical peaks remain visibly faceted at close range, and the mandated haze gives elevated views a strong peach veil.
- The large sacred-root footprint, inner circular parapet and established upper routes remain. Thin approximate collision supports were validated at four outer landing points; this is not exhaustive jump testing around every cliff boundary.
- The far background is a static generated panorama behind physical peaks and real aerial perspective. Its original 1774×887 resolution limits distant detail; the painted layer has no translation parallax.
- Leaves use intersecting alpha cards and water uses Roblox Terrain rendering. Fine branch depth, reflections and transparency depend on the device and graphics quality.
- The reused guardian sculptures are naturalistic lions, with some rough plinth edges concealed by collars; the requested traditional pearl and lotus-scroll details are absent.
- A focused standalone performance pass and optimization for lower-end devices remain unfinished. Mobile/console rendering, a live two-client duel, complete optional eaves traversal and live cache pickup are not established by the local verifier.
- The legacy `203785492` asset-type warning remains unresolved. Asset permission behavior in a published experience also remains untested; the place has not been published.

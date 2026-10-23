# Shrine of the Ascendant — monumental art pass

23 October 2026, Australia/Sydney. Integrated target: `outputs/AsurasPath.rbxlx` in the current checkout. This report supersedes the 22 October draft, including its zero-density atmosphere decision and smaller figure. No experience publishing is included.

## Visual changes

The composition now follows the reference's hierarchy: a broad bonfire promenade between reflective pools, a grand stone stair, a double-eaved gateway, and the monumental seated goddess against the sacred tree. The forge and duel court remain on the lower courtyard tier, joined by covered galleries.

| Area | Implemented result |
|---|---|
| Golden-hour depth | Future technology / Realistic lighting, ClockTime 17.4, Brightness 2.2, diffuse 0.65 and specular 1.0. Real Atmosphere remains active: Density 0.38, Haze 2.2, Color 250/215/185, Decay 120/130/165, Glare 0.35 and Offset 0.2. |
| Post-processing | Bloom 0.25 / Size 24 / Threshold 2.0; SunRays 0.12 / Spread 0.45; ColorCorrection Contrast 0.15, Saturation 0.05 and Tint 255/246/236. Values live in `EnvironmentProfiles.luau`, with lighting technology persisted in `default.project.json`. |
| Monument | The figure is 150 studs high. Its imported geometry and PBR references are reused; the figure and existing binding roots receive the same 1.5× plinth-relative transform, preserving the roots wrapped around her robe and torso. The tree retains its original footprint and approximately 402-stud trimmed height. |
| Spacious procession | The central pool promenade is 48 studs wide, the main stair 30, and the arrival bridge 24. Terrace procession widens from 16 to 32 studs; flanking stelae and lanterns move out of that axis. Gameplay identifiers and route destinations remain in their original services. |
| Sacred terrace | Two raised prayer courts have broad five-step approaches, clean modular shrine roofs, carved fronts and asymmetric rock/maple gardens. Six large jagged Crown/Ridge shoulders replace the repeated 33-piece underside ring. The structural core closes the upper cliff gap; the lower legacy root cylinder stays visually hidden with its collision retained. |
| Cloud sea | Two overlapping local particle beds lie roughly 78–100 studs below the Y600 plaza, around Y500–522. Thirty-two cloud emitters connect the island to eight physical karst peaks at approximately 1,000–3,000 studs. Peaks have deeply buried feet so their bases disappear into the sea. Five spillway cascades descend from carved courtyard lips into local spray. |
| Crafted lanterns | Stone pagoda and timber lantern housings enclose thin framed paper panes. Paper uses subdued warm Neon, RGB 151/101/58 at 0.35 transparency, with a small sheltered flame; there are no bare yellow lantern cubes. Lantern PointLights use RGB 255/175/95, Brightness 1.2–1.5, Range 12–16 and Shadows enabled. |
| Hearth and forge | The bonfire has a sunken stone bowl, jointed coping, stacked/split charred logs, fire, smoke and drifting embers. Its old flat emissive ring is replaced. Gao's recessed forge mouth uses dark basalt, a framed hearth and restrained fire rather than a glowing rectangular placeholder. |
| Materials and water | Shared blue-grey stone/paving PBR, vermilion timber, charcoal curved roofs and restrained bronze unify the kit. Both shallow pools use reflective Terrain water with segmented coping, dark waterlines, leaf scatter and soft edge mist. |
| Living crown | Eighty-four double-sided branch cards provide pointed crimson foliage at 28 sampled limb anchors. Nineteen folded prayer-silk meshes hang from the branches. Secondary maples, drifting leaves and sparse water-edge mist use the same botanical language. |
| Side activities | The stone duel finish, spectator balcony supports and complete housed lanterns preserve the underlying ring, stair and wager ownership. The forge, Lady Lin, rest altar, story gate, Well of Descent and optional routes remain part of the working game. |

## Assets and persistent source

Architecture uses the existing Blender-authored `AsuraLobbyKit`: separate curved roofs/eaves, carved rail bays, timber pillars/brackets, folded cloth and stone props, with distinct shared PBR materials. Buildings and bridges were assembled from those crisp modules; no whole-building neural mesh was introduced.

The uploaded `AsuraSanctuaryVista` Crown/Ridge/Needle meshes supply distant mountains and the six new terrace shoulders. `tools/blender/sanctuary_vista.py`, its editable `.blend`, GLB and manifests remain under `assets/build/sanctuary_vista/`. Each rock MeshPart is below 19,500 triangles; the six shoulders total 12 MeshParts / 115,038 triangles. The rock maps reuse the existing Poly Haven Rock Face 03 CC0 scan. These assets are already integrated through Rojo-mapped `.rbxmx` libraries, with IDs recorded in `assets/SANCTUARY_VISTA_UPLOADED.json` and `assets/LOBBY_KIT_UPLOADED.json`.

The earlier pass's original imagegen sky and transparent maple branch remain integrated through `PresentationAssets.luau` and `assets/SANCTUARY_SKY_UPLOADED.json`. Source prompts, panorama, cutout and cube projection script are preserved. The eight-stud guardian lions reuse the earlier TRELLIS.2 output cleaned in Blender; `assets/GUARDIAN_LION_UPLOADED.json` records the actual imported mesh and PBR IDs. Updated provenance is in `assets/CREDITS.md`.

| Source group | Main files |
|---|---|
| Lighting and presentation | `src/shared/EnvironmentProfiles.luau`, `src/shared/PresentationAssets.luau`, `default.project.json`, `src/server/Services/EnvironmentService.luau` |
| Monument and terrace | `SanctuaryTitan.luau`, `SanctuaryCanopy.luau`, `SanctuaryColossus.luau`, `SanctuaryTerrace.luau` |
| Courtyard and architecture | `SanctuaryCourtyard.luau`, `SanctuaryAscent.luau`, `SanctuaryKit.luau`, `SanctuaryProps.luau`, `SanctuaryFrame.luau`, `SanctuaryApproach.luau`, `SanctuaryBonfire.luau` |
| Landscape and side activities | `SanctuaryHorizon.luau`, `SanctuaryVista.luau`, `SanctuaryForge.luau`, `SanctuaryRingFinish.luau`, `WagerWorld.luau`; existing gameplay assembly entry points are retained |

Unqualified builder paths above are under `src/server/Services/`. `python3 tools/build.py` rebuilds the integrated place. These are persistent source/library changes, not Play-session-only dressing.

## Studio comparisons

All comparison images are actual Studio captures. Baseline captures used Automatic graphics quality; final visual acceptance uses focused Studio at graphics quality 21. Panel layout also changes viewport aspect ratio. The views document composition and defects rather than a controlled performance A/B comparison.

| View | Before | After |
|---|---|---|
| Bonfire / entrance looking toward the goddess | [Before](screenshots/before_entrance.jpg) | [After](screenshots/after_entrance.jpg) |
| Elevated layout, cloud sea and side pavilions | [Before](screenshots/before_elevated.jpg) | [After](screenshots/after_elevated.jpg) |
| Third-person-height stone bridge | [Before](screenshots/before_gameplay.jpg) | [After](screenshots/after_gameplay.jpg) |

Optional close views: `screenshots/forge_hearth.jpg` and guardian detail capture, if present. A passing unit test does not certify these images' visual quality; the focused Studio inspection is the acceptance evidence.

## Verification and measurements

| Evidence | Result and boundary |
|---|---|
| `qa/verify_all.log` | Full local verifier passed 14/14: progression 85 checks, campaign reachability 251, builder 27, Colosseum runtime 135, combat presentation 161 and audiovisual runtime 43; all sources compiled and a temporary place built. This completed before the last small forge/lantern cleanup. |
| `qa/progression_final.log` | Focused progression runtime passed 85 checks after the final cleanup; ending-credit checks passed. |
| `qa/combat_presentation.log`, `qa/audiovisual.log` | Focused authored-profile/media checks passed. Local engine fakes establish behavior and asset references, not rendered fidelity. |
| Final place / Studio source identity | **FINAL RECORD TO FILL:** current build path, mapped-script count and SourceDigest agreement after final sync. |
| Live route and interaction checks | **FINAL RECORD TO FILL:** actual current-build results, including any unverified multiplayer or optional-route checks. |
| Focused rendering measurement | **FINAL RECORD TO FILL:** hardware, quality 21, focused viewport size, camera, sample length, average/p95 frame time and RenderCPU. A background 15 fps cap is not a valid rendering result. |
| Whole-scene budget | **FINAL RECORD TO FILL:** measured BaseParts/MeshParts, colliding primitives, Decals, lights and emitters. Authored cloud/cascade ceiling is 689 steady particles across 32 cloud and 5 cascade emitters; this excludes leaves, fire and other effects. |

## Remaining limits

- The large sacred-root footprint and established upper route collision are retained. Prayer courts and jagged cliff shoulders improve its hierarchy, while the underlying upper floor still has a broad circular outline.
- The far background is a static generated panorama behind physical peaks and real aerial perspective. Its original 1774×887 resolution limits distant detail; the painted layer has no translation parallax.
- Leaves use intersecting alpha cards and water uses Roblox Terrain rendering. Fine branch depth, reflections and transparency depend on the device and graphics quality.
- The reused guardian sculptures are naturalistic lions, with some rough plinth edges concealed by collars; the requested traditional pearl and lotus-scroll details are absent.
- Focused Studio measurements, final route results and source identity must be recorded above before claiming them complete. Mobile/console rendering and a live two-client duel are not established by the local verifier.

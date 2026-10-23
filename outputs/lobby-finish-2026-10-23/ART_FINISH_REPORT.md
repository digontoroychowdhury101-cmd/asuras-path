# Shrine of the Ascendant — detail, rendering and device follow-up

23 October 2026. Target: `outputs/AsurasPath.rbxlx`, mirrored to `places/AsurasPath.rbxlx`. This follows the monumental art pass; its 150-stud goddess, original sacred tree, active 0.38-density / 2.2-haze Atmosphere, golden-hour lighting and gameplay routes remain.

## Implemented

- Added five original Blender-authored erosion/botanical modules: fractured sediment shelves, narrow fissure fins, actual fern blades, lobed crimson maple sprays and a shared two-sided branch plane. The kit totals **1,382 triangles**; 120 placed decorative modules add **33,120 authored triangles** before distance culling. Crevice planting and layered shelves dress courtyard edges and sacred-terrace shoulders without adding collision or obstructing the procession/spillways.
- Replaced paired foliage Decals with shared alpha-textured MeshParts. The existing branch texture is reused, retaining the red crown silhouette. Sanctuary Decals drop from **656 to 26**; 315 branch cards share one mesh and texture. Existing leaf scatter remains.
- Added a client-only landscape budget. Small dressing fades by projected size; structural columns, roofs, large rocks, hero meshes, sacred canopy and housed lanterns remain. Distant underground campaign meshes are hidden past 900 studs. Nearby lantern light contributions remain warm and shadowed; remote lights stop updating. Balanced mode reduces cloud/ambient particle rates while keeping real Atmosphere and cloud beds active. Settings follow graphics quality and touch capability. No collision, server authority or interaction identifiers change.
- Fixed device issues found in Studio: capability changes now select touch/gamepad controls without waiting for an input edge; HUD respects Roblox and device safe insets; short phones use a compact control grid and separate spell row; touch labels have restrained border strokes; the duplicate native jump button is hidden while its thumbstick remains; the Respite touch target measures 44 pixels.
- Fixed the installed **Rojo 7.7.1** warning. Its `preloadAssets` module was sending the Notification audio ID `203785492` to `PreloadAsync` as an image string. Typed `Sound` preloading succeeds; temporary sounds are destroyed afterward. Only the preloader was patched, with the original plugin backed up locally under `work/rojo-warning/`. Reproduction instructions for computer B are in `tools/qa/rojo_preloader_fix/README.md`. Fresh Play output no longer contains the mismatch. This is an editor-plugin fix, not a replacement game asset. The issue and approach are documented by [Rojo issue #1342](https://github.com/rojo-rbx/rojo/issues/1342) and [upstream PR #1344](https://github.com/rojo-rbx/rojo/pull/1344). A future plugin update may supersede the local patch.

## Persistent files

`tools/blender/sanctuary_detail.py` creates the editable `.blend` and importer GLB under `assets/build/sanctuary_detail/`. The imported, normalized library is `assets/models/AsuraSanctuaryDetail.rbxmx`; IDs and provenance are recorded in `assets/SANCTUARY_DETAIL_UPLOADED.json` and `assets/CREDITS.md`. Rock maps reuse the existing credited Poly Haven CC0 material. No whole-building neural mesh was introduced.

Builders: `SanctuaryEcology`, `SanctuaryKit`, `SanctuaryProps`, `SanctuaryCanopy`, `SanctuaryVista`, `SanctuaryService`. Client changes: `LandscapeBudget`, bootstrap, `InputController`, `DeviceLayout`, `SpellHud`. All source paths are under `src/`. QA harnesses under `tools/qa/` are not mapped into the shipping place.

## Verification status

- The complete local verifier passed **14/14 stages** on the production source, including progression, campaign reachability, combat and media checks. The movement harness was extended for capability changes and passed **50 checks**; device-layout regression passed **89 checks**. Engine fakes do not establish rendered fidelity or physical-device performance.
- Final Studio elevated composition at quality 21: **1,316,826 opaque triangles / 625 draw calls**, compared with the previous diagnostic **1,630,800 / 1,021**. The final viewport is 1221×503 versus 1221×543 before; this is a view-dependent cost diagnostic, not a controlled A/B. Across 120 samples per view, RenderCPU mean / p95 was entrance **6.49 / 9.51 ms**, elevated **7.82 / 16.28 ms**, crevice **6.94 / 9.16 ms**. All views recorded zero foreground frames and about 66.7 ms frame intervals; background throttling prevents a gameplay FPS claim. Studio process memory was about 4.34–4.36 GB on the local M1 / 8 GB Mac. See `qa/render_baseline.json` and `qa/render_final.json`.
- Final fresh-build Studio Device Simulator bounds audits passed on **Galaxy A06 (705×338)**, **iPhone 17 Pro (750×381)**, **iPad Pro M5 13-inch (1375×1032)** and **Xbox (1919×1079)**. Visible controls stayed within bounds without overlap; touch targets measured at least 44 pixels. Phone/tablet screenshots below are from the final build. The Xbox screenshot is explicitly an earlier iteration; the final Xbox bounds audit passed but its screenshot capture failed. Gamepad capability and layout were exercised; physical controller actions were not certified. Orientation was landscape; portrait was not tested. Files containing `iteration` are historical, not final acceptance records.
- Multiplayer attempts used actual local server/client processes and production remotes. One full-art run confirmed both clients booted and both characters spawned above the cloud sea, but match allocation timed out. Other launches stalled or lost a client. An asset-light fixture was attempted separately to isolate launch/resource pressure; it did not establish a successful duel. **A live two-client duel is not yet certified.** No failed/partial run is counted as a pass.

## Boundaries

Only the local Mac is available. Android bridge and Xcode device tooling are absent; Studio form-factor emulation cannot certify phone/tablet/console GPU performance, physical touch/controller latency, thermal behavior or TV overscan. Published asset permissions and public-server matchmaking remain untested. No experience was published. The scene still uses the existing large landscape silhouettes and generated panorama; added erosion detail improves close viewpoints rather than replacing every distant cliff with a new sculpt.

## Delivery and computer B

Work stopped at the user's request to conserve usage. The canonical and mirrored place files are byte-identical: **3,223,393 bytes**, SHA-256 `3b6de54795b27df3a06e14e95dac23f3db217aa212fccfdde7fe768b95ed1bac`. All 236 mapped scripts / 1,687,612 source bytes agree with fresh Studio Edit: **SourceDigest 1045496687**. There are 241 mapped sources including libraries and 360 distinct asset IDs. The earlier monumental report and its before/after images document the preceding build, not this source identity.

- [Computer B handoff](COMPUTER_B_HANDOFF.md)
- [Before entrance](screenshots/before_entrance.jpg), [before elevated](screenshots/before_elevated.jpg)
- [Monumental-pass before/after comparisons](../lobby-monumental-2026-10-23/ART_PASS_REPORT.md#studio-comparisons)
- Final device images: [Galaxy](screenshots/device_galaxy.jpg), [iPhone](screenshots/device_iphone.jpg), [iPad](screenshots/device_ipad.jpg)
- [Xbox iteration image](screenshots/device_xbox_iteration.jpg); [final Xbox bounds audit](qa/device_xbox.json)

No new final fixed-camera environment screenshots were captured after the detail/performance follow-up. Previous-pass comparisons and current device images are retained without relabeling them. Further cliff sculpting, foliage refinement, foreground/device FPS measurement, physical hardware testing, a successful two-client duel and published asset-permission checks are deferred. The failed multiplayer QA harnesses are preserved outside the shipping Rojo tree for later investigation.

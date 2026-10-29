# Environment art ledger — 29 October 2026

Status: **in progress**. The entry slice is visibly improved and integrated; Bamboo Pass and the full-world goal are not finished.

## Current build and authorization

- Branch `ux/onboarding-overhaul`; starting commit `8438e42`. Baseline documentation commits `d97e8d5` and `b881688` were pushed.
- User confirmed the local `places/AsurasPath.rbxlx` instance, approved future goal-related art uploads to their Roblox inventory, and approved goal-related pushes to this branch. No game publishing or spending is authorized or performed.
- Canonical source checkpoint: **261 scripts / 1,928,385 bytes / digest 531655793**, 273 mapped sources, 646 referenced asset IDs. Build mirrored to `places/AsurasPath.rbxlx`.
- Current Studio instance: `23114e37-9b1f-4703-881d-b052215e2a52`. The separate import snapshot was saved safely and its empty Studio process closed. The canonical place was freshly opened for v2, then script-synced through the current checkpoint.
- Existing unrelated untracked `outputs/blender-connection-2026-10-29/` is preserved and excluded from staging.
- Desktop: Apple M5 MacBook Air, 10 CPU cores, 8 GPU cores, 16 GB RAM. Physical mobile availability remains unverified.
- Rodin API balance check returned HTTP 200 / **0 credits**. No generation submitted or credits spent.

## What visibly changed

`baseline-eight/` contains all eight reviewed original gameplay-height views and reproducible camera/state metadata. `entry-slice-v5/` contains matching entry, close-path, ground-transition and crest views; the crest view mainly documents remaining work. FOV 70, logical viewport 1221 × 503, captures 1920 × 790, Automatic quality, normal regional lighting and HUD retained. These are seeded Studio diagnostics, not earned traversal.

The entry-to-crest slice now has five clump silhouettes, irregular clustered growth, leaning culms, overlapping upper and middle foliage, fern colonies, young shoots, litter, grass tufts, soil beds and reused MIT rocks. The uploaded lobby kit replaces flat gate bars with stone column feet, round lacquer columns, brackets, architraves and a shallow tiled gallery roof. Bamboo lighting has more neutral fill and less cyan. FrostedCrest/RidgeNorth retain their original collision/fill envelope with rock below a thin snow cap.

Runtime terrain queries found the first litter layer entirely buried below the voxel surface. Dressing now queries the real Terrain surface after one build-time yield; measured fern/litter bottoms land within about 0.007 stud of the sampled 0.40625-stud surface. No extra movement/camera colliders were added; offline campaign checks retain Bamboo's 73 colliders.

## Real imported assets and preserved masters

- Five original opaque mesh units, **7,556 total evaluated triangles**; largest fern 2,720. Real mesh and PBR IDs: `assets/LIVING_BAMBOO_UPLOADED.json`; built library: `assets/models/AsuraLivingBamboo.rbxmx`.
- Original generator: `tools/blender/living_bamboo_ground.py`. Dedicated live Blender scene `Asura Living Bamboo Master v1`; original Scene/camera/light preserved.
- Packed 2048-pixel master, separate 1024 upload maps, evaluated manifest, calibration GLB and validated kit export remain under `assets/build/living_bamboo_v1/` (established local build-artifact directory). Registry records 21 source/export/map file hashes. The preceding Blender scene was backed up separately.
- Small leaf-litter import proved Stud scale 1 and bounds 9.844 × 0.256 × 9.949 before the final kit upload. Final four units reuse the calibrated litter upload. Parts are anchored, double-sided, noncolliding/nonqueryable, with preserved foot pivots and no decimation.
- Studio import snapshot and source backups: local ignored `imported-ecology.rbxlx`. Runtime library extraction and fresh canonical import were verified.
- Concrete GitHub reuse: existing MIT HungryProton/scatter BoulderSmall meshes now frame fern beds at useful scale; existing licensed terrain PBR maps are reused in the true Grass variant. Credits remain in `assets/CREDITS.md`.

## Motion and registration evidence

The client wind controller uses one Heartbeat, 64-stud spatial buckets, bounded active sets (112 Detailed / 64 Balanced), distance-based rates, rooted world pivots, shared gusts, separate plant frequencies and leaf flutter. GlobalWind is (6,0,2). True Grass patches use Decoration and GrassLength serialized in the canonical build; deep shade retains LeafyGrass and soil. `tools/qa/EnvironmentFocus.luau` can attach an observer before foregrounding the window; the sampler only inherits actual observed events, otherwise initial focus remains unknown. The foreground composition includes a native Grass pass (29,382 triangles / 20 draw calls at the sampled entry).

The first timed capture exposed a real registration failure: replicated tags arrived before eligible MeshParts, leaving active rows with no moving pieces. A shared delayed-registration queue plus descendant handling now collects late parts/properties. No per-plant frame connections were added.

- `entry-wind-v6/`: 24 original client frames over 19.93 seconds, real timestamps/transforms and `timed-wind-preview.gif`. This is a **discrete frame sequence, not continuous video**. Sampled tip travel: bamboo 0.266 stud, grass 0.078, fern 0.048, shoots 0.059. Maximum measured culm-root error 0.000616 stud. Mean reported wind update 0.228 ms; maximum reported one-second peak 2.10 ms.
- `wind-lifecycle-final/`: actual current-controller regression passes. Tag-before-parts and two separately delayed Anchored properties yield 374 registrations / 1,151 cached parts from 373 / 1,149. Both late parts move. Two exit/re-entry cycles and part deletion return exactly to **373 / 1,149**. Temporary model destroyed.
- `wind-comfort-v6.json`: actual Respite UI Reduced motion turns custom motion off (0 active, sampled culm static) and native wind down to (0.6,0,0.2). Backspace reverts preview; Resume closes menu and restores (6,0,2), 112 active, 373 registered. No preference Apply/save.
- The earlier `entry-wind-v5/motion_summary.json` is deliberately retained as failed diagnostic evidence (zero motion); its raw frames remain local.

Continuous wind/traversal video is still open. CaptureService returned Start=Success in one capability probe but no completion callback before that Play session ended; this is not a delivered video. Mac Studio's inspected View/Test menus offered Screenshot but no video recorder. Investigate a supported capture/export route without public publishing.

## Performance and verification

See `PERFORMANCE.md` and raw JSON. Valid foreground entry/Monastery sequence: 60.013 seconds, 358.46 studs, 3,601 frames, 0 unknown/unfocused frames, p95 **17.57 ms** (target 16.7 **not met**), CPU p95 16.70, GPU p95 14.52. Registrations remain 373 across repeated region entry. Automatic graphics, Detailed landscape, observed ~60 fps pacing; exact frame-cap property is unavailable. This is an entry-slice diagnostic, not the final whole-route/Baize acceptance run. Shadow composition is large and needs cost investigation before scaling the treatment.

`verify-v6.log`: all 14 verifier stages pass, canonical build succeeds. Campaign shim: 27 passed, 0 failed, collision counts unchanged. Current-controller delayed registration/re-entry regression passes in Studio. Source digest on disk is recorded above; final Edit digest matches disk in `checkpoint-digest-v6.json` (261 / 1,928,385 / 531655793; five imported pieces).

## Remaining defects and acceptance

Highest impact next: (1) profile and budget distant culm shadows while preserving near contact; (2) replace the conspicuous green-cylinder fallen root giant with original organic root geometry and add broken/fallen bamboo; (3) dress the shrine's flat screen/roof and frame its empty lawn, then continue the same treatment through all eight Bamboo views. The white cliff material improved, but rectangular cliff/snow margins, arena pillars/floor/light bands and moon-gate jambs remain unresolved. Lighting and near-ground material quality need further scrutiny.

Full-world scope remains: finished Bamboo Pass; Sanctuary; Desecrated Monastery; Ash Colosseum; Sunken Crypt; Celestial Pagoda; Sky Citadel. The existing 1.18M-triangle fused tree has not yet received the required current-machine appearance/cost assessment and remains untouched.

Still incomplete: final eight matching Bamboo views including active Baize combat; three final gameplay views per other region; continuous wind/traversal capture; desktop target; physical mobile/device limitation audit; Balanced-tier and respawn/camera/lock-on/glide/interactions/full-route regressions; final fresh canonical reopen and complete visual defect audit. Passing imports and checks do not establish visual completion.

Diagnostic file boundaries: failed baseline read/start logs are retained for provenance; `baseline_sample.json` is the recovered complete baseline result. Overlay-obstructed/failed capture folders stay local and ignored. `entry-wind-v5/motion_summary.json` records the pre-repair zero-motion failure.

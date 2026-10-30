# Environment art ledger — 29 October 2026

Status: **Bamboo Pass visual slice closed at v9 (30 October 2026, Mac)**, stopping at the Bamboo boundary. Bamboo's Windows/hardware/device gates and every other region remain open; the full-world goal is unfinished.

## v9 — Bamboo slice close (30 October 2026)

- Resumed from the canonical place: on-disk SHA-256 matched v8 (`2e6d0ab8…bae76`) and a fresh Studio open read **261 / 1,935,942 / 991116205**. Studio `daca8a9a-02e3-4717-9a3f-3ef157897345`.
- **Moon gate:** 25 voussoirs (7.5°) under a slate coping band with a keystone; slate shells, plinths and imposts dress the unchanged 3 × 18 × 3 `MoonJamb` colliders (both still at x = ±17.1, `CanCollide` true). Boulders, ferns and young shoots plant both faces of the shoulders. The bare ash-descent road is now a grove (`Ecology.South`: 10 clumps, ferns/litter, soil and grass patches, one fallen pole). The flags at |x| < 14 stay clear.
- **Frost/overlook margins:** the 14 rectangular snow slabs are replaced by clusters of sunk, overlapping disc drifts, kept off paved floors. The overlook parapet gets irregular slate coping and a crag at each end. Remaining defect: the frosted crest's terrain snow cap still shows a straight lip in `close_path` (its slab is a route elevation and was not changed).
- **Root close-up:** the new `root_detail` view showed the scanned trunk floating 2.1–4.6 studs above the soil. It is now sunk and rolled 4.4°, with both ends measured within ±0.5 stud of the ground and a soil patch below. The lore tablet framing was also fixed.
- **Cost check and optimization:** the first pass added +161k triangles / +12 draws (+52%) at the arena camera. The south clumps were then switched to plain crowns with one fern each, giving **+67k (+21%) / +12** at the arena and +63k (+29%) / +1 at the moon gate (`slice-composition-*.json`). Registered moving plants are 792; the active cap stays 112.
- **Captures** (`final-slice-v9/`; FOV 70, HUD retained, 1221 × 503, Automatic quality, 8 s settle): `before_*` and `after_*` for the eight ordinary views plus `root_detail` (corrected root camera before view: `root-before/`). Pre-budget after-shots are kept in `after-prebudget/`. A 3 s settle once showed the overlook paving as stock slate; terrain was measured below the lid and a longer settle renders the paving correctly. The temporary terrain undercut tried during this check was reverted.
- **Active Baize combat** (`combat/combat_telegraph_airglide.jpg`): seeded through the normal fog-gate trigger (`AsuraEncounter = VenerableBaize`), with ordinary camera and lock-on. Player, sword, PERILOUS AIR GLIDE banner, boss bar, cyan ring and red target mark are all readable on the paving, with the moon gate visible behind; the camera is unobstructed. **Baize's body was not captured:** in three seeds it opened with Air Glide and killed the level-1 test character. Those deaths ran on Studio mock persistence (`StudioLiveData = false`).
- **Preserved:** Bamboo has 73 colliding parts (runtime and offline); new and pass dressing have 0 collide/query/touch parts. Rays land on Baize's floor at Y = 0.00 and the overlook paving at 18.20. The overlook, parapet, crest, ridge and flag slabs are unchanged, and the shrine `RestPrompt` is enabled. No asset ID added: 660 referenced before and after, with no uploads and no Rodin use.
- **Checks:** typed preload of all 49 slice meshes/maps passes (`v9-slice-preload.json`). The wind lifecycle passes (792→793→792, cached 2,545; `wind-lifecycle-v9.txt`). The actual Respite UI Reduced-motion toggle stops a new south culm (active 0, wind 0.6/0/0.2) and restores 112 active / (6,0,2) with no save (`wind-comfort-v9.json`). `verify-v9-final.log` passes all 14 stages (campaign regions 333/0; campaign build 27/0).
- **Build:** **261 scripts / 1,940,644 bytes / digest 803029733**; canonical and mirror SHA-256 `6097fb3dfad9ee195e0c0311c9c675d70201bed2f5e1a7bd46aaf2c9bcd76ce5`. Fresh canonical reopen (Studio `dda73794-0660-4c62-90bf-0914a7187a38`, after closing the synced session without saving): Edit digest **261 / 1,940,644 / 803029733** matches disk. A clean Play boot shows no errors, 73 Bamboo colliders and the v9 pass attribute (`checkpoint-digest-v9.json`).
- **Performance:** Mac Studio diagnostics only (see `PERFORMANCE.md`). No qualified foreground timing was possible this session; desktop and mobile acceptance are not claimed.
- **Still open for Bamboo:** Windows/desktop 16.7 ms and physical-mobile 33.3 ms gates; a full 60-second traversal/combat run in the foreground; Baize body/camera clearance in a sustained fight; crest snow lip; continuous wind/traversal video; Balanced-tier, respawn, glide and full-route regressions.

## Current build and authorization

- Branch `ux/onboarding-overhaul`; starting commit `8438e42`. Baseline documentation commits `d97e8d5` and `b881688` were pushed.
- User confirmed the local `places/AsurasPath.rbxlx` instance, approved future goal-related art uploads to their Roblox inventory, and approved goal-related pushes to this branch. No game publishing or spending is authorized or performed.
- Canonical source checkpoint: **261 scripts / 1,935,942 bytes / digest 991116205**, 274 mapped sources, 660 referenced asset IDs. Build mirrored to `places/AsurasPath.rbxlx`.
- Last Studio instance (now closed): `23114e37-9b1f-4703-881d-b052215e2a52`. The separate import snapshot was saved safely and its empty Studio process closed. The canonical place was freshly opened for v2, then script-synced through v8. A fresh canonical v8 reopen remains part of later acceptance.
- Existing unrelated untracked `outputs/blender-connection-2026-10-29/` is preserved and excluded from staging.
- Desktop: Apple M5 MacBook Air, 10 CPU cores, 8 GPU cores, 16 GB RAM. Physical mobile availability remains unverified.
- Rodin API balance check returned HTTP 200 / **0 credits**. No generation submitted or credits spent.

## Latest checkpoint — v8, pause handoff

- Clustered five-style bamboo now covers all eight original grove zones. Entry/shrine seeds are independent so future distant-grove changes do not disturb their arrangement. Registered moving plants total 736 in this version; the existing bounded scheduler stays at 112 Detailed / 64 Balanced.
- The old green-cylinder fallen log is replaced with the existing CC0 scanned trunk and pine-root uploads. The shrine now uses the already licensed Han pavilion, planted borders and exposed roots. Captures: `entry-shrine-v7/` and `checkpoint-v8-clean/` (four views, ordinary FOV/HUD, 1221 × 503 viewport). The dedicated root-detail view, complete final eight-view set, and active Baize combat comparison are still open.
- A new original broken clump and fallen pole are **uploaded and integrated**, not just exported: `AsuraBambooBreakage`, four MeshParts / 2,704 evaluated triangles, 2048 masters / 1024 upload maps. Four mesh and eight PBR map typed preloads all return Success (`v8-breakage-*.json`). Three broken clumps and two fallen poles are present in the current runtime. Registry: `assets/BAMBOO_BREAKAGE_UPLOADED.json`; model: `assets/models/AsuraBambooBreakage.rbxmx`; generator: `tools/blender/bamboo_breakage.py`.
- Initial breakage v2 export revealed selected objects leaking from an older Blender scene. The validated export explicitly restricts itself to the active scene and contains exactly four intended sections. Both older masters remain intact; validated and final checkpoint masters are preserved under `assets/build/bamboo_breakage_v2/`. All source shader maps were confirmed 2048 × 2048 before saving and quitting Blender.
- Fine bamboo shadows now have a production client distance budget (80 studs Detailed, 48 Balanced, 6-stud hysteresis), using one shared registry and existing refresh loop. Geometry stays visible; nearby shadows remain. Raw short diagnostics under `shadow-budget-before/after/` were background-throttled at FRM 2 and **cannot establish a performance gain**. `entry-shrine-v7/` reached FRM 21 / ~60 fps with GPU p95 13.28–14.19 ms, but initial focus was unknown, so this is not the final performance gate. The last valid 60-second p95 remains 17.57 ms, over target; no post-v8 acceptance result is claimed.
- Baize’s four blue block visuals now use uploaded ruined-stone pillar shells. The original four **8 × 30 × 8** collision/query proxies stay at exactly the same coordinates. The arena’s original **180 × 4 × 180** slab remains centred at **(0, −2, −1470)**. Clearing terrain only down to its top left a 0.4-stud smooth-voxel protrusion; clearing inside the slab’s existing depth exposes its unchanged Y=0 lid. Five fresh-Play rays now hit the actual floor Part at **Y=0** (`v8-runtime-check.json`). No arena collider was moved or resized.
- Floor paving, restrained Bamboo-only brazier brightness and thinner, flatter mist improve the arena/shrine read. These changes still need final combat-camera, traversal and visual acceptance.
- `verify-v8-final.log`: all 14 local stages pass. Fresh Play boot succeeds; current Edit source digest equals the built file (`checkpoint-digest-v8.json`): **261 / 1,935,942 / 991116205**. Canonical/mirrored SHA-256: **2e6d0ab8b38bf87fd28c161005f34ba39f0933aaa104918c78b89c10cdbbae76**.
- Local Studio backup `imported-breakage.rbxlx` was explicitly saved after the final sync; it includes source import backups. Blender’s final saved file is `assets/build/bamboo_breakage_v2/BambooBreakageMaster_Checkpoint.blend`. Native app inventory confirms both Studio and Blender stopped. No project-owned QA process remains running.

(v8 handoff, superseded by v9 above.) Resume by opening `places/AsurasPath.rbxlx` and checking the digest above. Continue Bamboo’s moon gate, frost/overlook margins, remaining ground/canopy composition and performance/regressions; then Sanctuary and every other campaign region. Preserve the original full goal. All approvals for goal art uploads and pushes to this branch remain recorded; do not re-request them.

## Earlier entry-checkpoint evidence (v1–v6)

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

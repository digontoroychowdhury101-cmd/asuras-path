# Environment art ledger — 29 October 2026

Status: baseline inspection in progress. No environment edits or completed visual criteria yet.

## Established baseline

- Branch `ux/onboarding-overhaul`, starting commit `8438e42`; pull reports up to date.
- Existing untracked `outputs/blender-connection-2026-10-29/` is preserved and excluded from this work's staging.
- Canonical build: `places/AsurasPath.rbxlx`, mirrored from `outputs/AsurasPath.rbxlx` by `tools/build.py`.
- Connected local Studio `AsurasPath.rbxlx`, version 0.745.0.7451137, PlaceId 0. Source digest matches disk: **259 scripts / 1,905,234 bytes / 1174798130**. Target confirmation requested; no game modification before the reply.
- Initial viewport 937 × 503, FOV 70; editor quality Automatic; GlobalWind (0,0,0). Running-client quality and frame cap are not measured yet.
- Available desktop: Apple M5 MacBook Air, 10 CPU cores, 8 GPU cores, 16 GB RAM. Physical mobile device availability is unknown; none verified.
- Blender MCP 1.30.0 / addon 1.8 / Blender 5.2.2 LTS is connected. Unsaved dirty scene has a camera and light, no meshes. Preserve it before loading any masters.
- Rodin configured via Blender in MAIN_SITE mode with the addon's trial key. A read-only request to the official `GET https://api.hyper3d.com/api/v2/check_balance` succeeded with HTTP 200 and **balance 0**. No generation submitted and no credits spent. Blender/existing assets remain available alternatives.
- Studio login completed by user. Computer-use access subsequently reports the Mac locked; unlock requested. MCP read-only access still works.

## Source findings to validate visually

These are implementation findings, not screenshot-grounded visual judgments:

1. `BambooDressing` scatters 640 single culms uniformly across eight rectangular zones, using `RegionDecor.scatter`. There are three culm templates, no clump architecture or near/mid/far distribution.
2. `CampaignTerrain.Kinds.Grass` maps to `LeafyGrass`; Roblox documents animated blades on `Grass` only. Deep shade should keep moss/litter, with true Grass confined to suitable openings.
3. Configured GlobalWind is zero; no custom imported-bamboo wind controller exists. Shrine ribbons are static parts.
4. SnowDrift dressing is thin rectangular Parts at fixed elevations. Their actual ground contact and silhouette need inspection.
5. Terrain.Decoration and GrassLength are documented but return “not a valid member” from this Studio MCP execution context. Investigate serialized properties and Studio Properties before implementing; do not treat an attempted assignment as evidence of grass motion.
6. Existing FusedTreeStatue registry records 78 parts / 1,180,276 triangles. Runtime screen contribution and render cost remain unmeasured. Preserve original geometry.

## Prepared evidence workflow

`tools/qa/bamboo_capture.py` defines eight repeatable player-height viewpoints. It records camera, FOV, viewport, actual quality, lighting, wind, region, encounter and HUD state. It uses ordinary running-game geometry and lighting, preserves HUD visibility, and restores the camera/player after captures. Teleported views are explicitly labelled seeded Studio diagnostics.

`tools/qa/EnvironmentSample.luau` records a bounded 60-second ordinary-gameplay sample, returning immediately so movement and combat can proceed. It records frame-time/CPU/GPU distributions, focus events, memory, position, region/encounter, mesh/instance counts and view-dependent render composition. It changes no scene settings or gameplay. Initial window focus is explicitly unknown until a focus event is observed. This sampler has not yet run in Studio.

Preparation checks: Python capture-tool syntax/help succeeded; a separate local baseline build succeeded (270 mapped sources, 633 referenced asset IDs) and matches the starting script digest. An Edit screenshot request did not return and its orchestration was cancelled; no image was produced. There are no running-client screenshots yet.

Continuation check: Studio remains in Edit with the same local instance; native computer-use inventory still explicitly reports the Mac locked. Target confirmation and push approval have not arrived. An isolated temporary Rojo serializer probe successfully wrote Terrain.Decoration=true and GrassLength=0.4, so these settings have a supported build-time route despite unavailable MCP property reads. See `terrain-serialization-probe.json`. The probe was deleted with its temporary directory; it was never opened or used as visual evidence. The actual game remains unchanged.

Before/after images, motion, 60-second traversal/combat performance, regression checks, other-region art passes and final canonical-build verification are all **incomplete**.

Next action: confirm the Studio instance, unlock the Mac, start the unchanged canonical game, inspect ordinary gameplay, and capture all eight baseline views. Build a screenshot-grounded defect list before changing environment art.

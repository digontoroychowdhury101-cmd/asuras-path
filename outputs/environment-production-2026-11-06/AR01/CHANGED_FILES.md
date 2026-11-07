# AR01 changed files (relative to 62d79ea, AR00)

## Game source
| File | Change |
|---|---|
| `src/shared/WorldDefinitions.luau` | Ash region bounds (480×200×440 at z −1900). Shen arena is 240×190 at (0, 20, −1990); spawn at (0, 3, −1955). |
| `src/shared/AshColosseumLayout.luau` | Bowl, tiers, facade, gate passage, podium, Victor jamb and south retaining wall are re-fitted to the new floor. |
| `src/server/Services/ColosseumDressing.luau` | Rewritten. Places the AsuraCovenantKit seat fronts, arcades, facade, gates, banks, props, braziers and horizon group, and keeps the approach dressing. |
| `src/server/Services/BossArenas.luau` | Ash arena floor: ash-pale gravel. |
| `src/server/Services/ArenaLighting.luau` | Ash brazier brightness is 0.4×. |
| `src/shared/ArenaLightPlan.luau` | Fill MaxSpacing 80 → 66. |
| `src/shared/EnvironmentProfiles.luau` | Ash exploration and combat grades are cold grey. Clock and fill floor are unchanged. |
| `default.project.json` | Maps `assets/models/AsuraCovenantKit.rbxmx` into ServerStorage. |

## Assets
| File | Change |
|---|---|
| `assets/models/AsuraCovenantKit.rbxmx` | New. 12 MeshParts with SurfaceAppearance, uploaded IDs only. |
| `assets/COVENANT_KIT_UPLOADED.json` | New. Model, mesh and map IDs, sizes, centres, triangle counts and GLB sha256 for each piece. |

## Tools and tests
| File | Change |
|---|---|
| `tools/blender/covenant_kit.py` | New. Procedural Blender kit: preview and bake (OPTIX/CUDA). |
| `tools/build_covenant_library.py` | New. Writes the kit `.rbxmx` from the upload record. |
| `tools/qa/AR01CaptureSetup.luau` | New. Seeded Studio stand for captures. |
| `tools/qa/AR01ShenProbe.luau` | New. Seeded Shen clamp, telegraph, corner and exit probe. |
| `tools/qa/ReadUploadedKit.luau` | New. Reads mesh and map IDs from uploaded models. |
| `tools/arenas/ar01_captures.py` | New. Before/after camera calls. |
| `tools/test_campaign_regions.luau` | AR01 spatial block added. |
| `tools/test_combat_presentation.luau` | Fill budget now scales with arena area. |

## Docs
- `outputs/environment-production-2026-11-06/AR01/**` (this folder)
- `PROJECT_STATE.md` (one line)

## Not committed
These are gitignored work products:
- `work/`: Studio places, logs and raw captures.
- `assets/build/covenant_kit_v1/`: GLBs and baked maps. Rebuild them with `tools/blender/covenant_kit.py bake`.

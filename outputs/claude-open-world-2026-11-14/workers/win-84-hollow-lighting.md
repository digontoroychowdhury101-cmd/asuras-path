# win-84: Bellwood Hollow lighting (Windows, 2026-11-23)

Creator note: the basin "should not have a sky since it is underground", and it was "too dark, add good lighting, be ambitious".

## Why it was dark (Studio, Development place, single-client Play)
- **Metal stone.** The 3D importer gave the colossal temple metalness maps: 555 of its 562 SurfaceAppearances, plus GateTowers 7/7. Metal reflects the sky, and the cave sky is black, so the stone rendered black.
  - With the metalness maps cleared, the stair reads as textured stone.
  - With a blue test sky, the rails reflect blue.
- **No sky light.** The black sky also gives PBR surfaces no environment light. Raising the Cavern ambient to (175,182,186) with exposure 0.45 changed almost nothing (capture 02 against 01).
- **Dark albedo.** The temple's stone albedo is dark. Even without metal and under a teal sky, the stair and lower tiers stayed a dark mass (capture 03).

## Fix
1. **Non-metal stone finish.** `assets/models/AsuraStoneFinish.rbxmx` holds 229 SurfaceAppearances, one per ColorMap of the colossal temple, guardians and gate towers. Each keeps the same colour, normal and roughness maps with no metalness. `tools/assets/build_stone_finish.py` writes it from LandmarkKitRegistry. `VesperholdKit.place` swaps it in by ColorMap id, because a running server cannot clear MetalnessMap. GiantFace and GiantCrown (outside, under the real sky) are unchanged.
2. **Cave sky.** One procedural 512² dark-teal image, (88,118,120) with ±4% tileable mottling, is used on all six faces so no seam can show. It is the colour of the vault's glow, and it is never visible as a sky: the vault covers it. It replaces the `CAVE_SKY` shortcut in EnvironmentController.
3. **Stair fill.** `LandmarkWorld.stairFill` places 14 shadowless amber PointLights (range 60, brightness 2.6) inside HollowLights: five pairs over the stair rails and two pairs on the side tiers. HollowLights now holds 32 lights in total.

## Uploads (Open Cloud via Studio MCP, user 3148600636; pilot = the only upload)
| what | operation | asset |
|---|---|---|
| Bellwood Hollow cave sky (Decal) | f513d344-b8df-4acc-9ffd-ff8618046872 | decal 111215040387593 (Approved) |
| image child | 11f8d4b5-6161-4130-8bd7-271673b837af | image 83866687618973 (Approved) |

## Captures (`captures/win/hollow84/`; 01–05 are live client overrides that preview the fix before the build)
- 00: up at the iris, before.
- 01: far shore, metalness cleared, black sky.
- 02: far shore, teal sky.
- 03: stair, teal sky.
- 04: stair with the flank lights.
- 05: far shore with all three fixes.

## Frame time (far-shore view, Studio, before the fix)
- HollowLights on: p50 66.2 ms, p95 77.2 ms. Off: p50 61.8 ms, p95 67.7 ms.
- Looking up: p50 64.2 ms. Looking away: p50 62.5 ms.
- Memory: 3390 MB, of which graphics 2673 MB; 96,015 instances.
- These numbers are an unfocused Studio window, not device numbers. Phone profiling is still open.

## Play verification (built place, Development, single client)
- **First Play: "Server startup failed".** `VesperholdKit.place` read `SurfaceAppearance.ColorMap`, which game scripts cannot do (Plugin capability). The Lune fakes do not enforce capabilities. Fixed in 684910d: the swap keys on the registry ColorMap carried in the kit template, and the test's imported surface now has a different ColorMap from its registry entry.
- **Review finding.** Gold and lantern subs had been stripped of metalness. They now keep it, leaving 210 finishes. On the client, 539 temple surfaces are non-metal and 23 gold and lantern surfaces are metal.
- **Second Play: clean start.** Results:
  - HollowLights holds 32 PointLights, 14 of them StairFill.
  - The sky is 83866687618973, and GlobalShadows is off inside.
  - All 432 upward rays from the lake hit vault rock, so no sky is visible.
- **Captures 10–15:** causeway (textures still streaming in: white for about 30 s on a cold client), stair with lions, up at the iris, far shore, hall interior, exit doorway.
- **Frame time** (far-shore view, Studio unfocused): p50 57.1 ms, p95 64.2 ms; it was 66.2 / 77.2 before. Memory 3202 MB.
- **Saved** to Development 118614906972571 as version 40. Never published.

## Still open
- **Hall back wall.** It stays black even with 50-stud lights 25 studs away (capture 14), so it is a near-black surface or an opening, not missing light. Trace the mesh.
- **Stair variants made no difference.** The stair reads darker than the client-side preview (04). Seven pairs at brightness 3, or the gold and lantern metal cleared, both left the build's look unchanged. The preview's warmer treads remain unexplained.
- **Not run in this batch:** the two-client multiplayer check, phone-emulator profiling and the switchback walk (route 380–395).

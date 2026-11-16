# Open-World Replacement — Ledger (lead: Opus 5.5, restart #2)

Historical starting baseline: HEAD `fb51a42` on `ux/onboarding-overhaul`. The creator subsequently authorised commits and pushes for the cross-computer handoff. Oversight file: [DELEGATION_STATUS.md](DELEGATION_STATUS.md) (Fable-owned, not edited here). Current resume point: the **Codex handoff completion** section at the top of [CONTINUATION.md](CONTINUATION.md).

## Handoff checkpoint — 2026-11-16

Claude pushed `b658140` before the usage stop. Codex then preserved the late T4
terrain edit, finished [MAC_HANDOFF.md](MAC_HANDOFF.md), added the missing reference
archive required by the brief, and delivered the ignored mesh/audio sources on
`codex/overworld-assets-2026-11-16` (commit
`1412139fbb6c9adc519031a5d02063c7a952732c`). The asset branch is data only; never
merge it into the code branch. SHA-256 pins and safe restore tooling are in
`handoff/` and `tools/assets/overworld_handoff.py`.

Local validation is green; new Studio validation is absent. T4 remains partial,
M8 far trees are exported, D6 has 276 trees and 74% static tower visibility.
The lantern folder permission now works, but processing returned Unknown Error
without an ID. Registries, real-mesh integration and engine performance/visual
acceptance remain open. Saved places and the cloud place were not changed.
See [handoff/VALIDATION.md](handoff/VALIDATION.md) for evidence and scope limits.

## Milestones
States: planned / blockout / integrated / verified / blocked.

| Milestone | State | Evidence |
|---|---|---|
| Startup inventories (3) | verified (files present; gaps noted) | inventory/preservation.md, world-assets.md, nav-env.md |
| Skill check (mattpocock to-spec etc.) | verified: all 7 SKILL.md exist under engineering/ and productivity/ | inventory/skills.md |
| Spec + tickets | verified (written) | .scratch/asuras-open-world/SPEC.md, issues/01..19 |
| C1 geography/route/streaming plan | verified: signed off by Fable 2026-11-15 (rulings R1–R3, conditions A–E below) | GEOGRAPHY_PLAN.md |
| Baseline place copy | verified (sha256 match a353dd00…) | baseline/AsurasPath.rbxlx, .rbxl |
| Lobby before-captures L1–L5 (condition C) | verified, before any overworld geometry | baseline/lobby/CAMERAS.md + 5 jpg |
| Studio identity | verified: open place = places/AsurasPath.rbxlx, digest 462022588 (286 scripts) | studio_mcp --digest vs SourceDigest in Studio |
| Studio-only work | none found: Edit Workspace has only AsurasPath/Camera/Terrain; all maps runtime-built | execute_luau listing |
| T04 streaming residency (condition D) | verified on EXISTING world (Studio solo): lobby L1–L5 match, portal stream-in, rest/travel back, 4 client lookups, no new errors; streaming ON kept | workers/04-streaming.md, captures/t04/ |
| T01 canonical data | integrated and ACTIVE (Overworld.Active=true since T08); overworld_data 2744/0 | src/shared/Overworld.luau, tools/test_overworld_data.luau, workers/01-canonical-data.md |
| Condition E terrain authoring | verified: background runtime generation; glade 6.8 s, all altars+barrier 8.9 s, all 4129 tiles 178–181 s | workers/03a-terrain-cost.md, workers/05-survey.md |
| T03 terrain/route blockout (5 regions) | blockout: traversable with real inputs on 8 measured legs; caves are mouths only; lifts are fade-teleports | workers/03-blockout.md, captures/t03/ |
| T02 shrine entry/return | integrated: portal (20 s glade wait) → glade, rest, return gate → bonfire, travel; timeout path untested | workers/03-blockout.md, workers/08-cutover.md |
| T07 persistence migration | integrated: fixtures pass (persistence 52/0 live); Studio death/stain recovery on glade done in T08 | workers/07-persistence.md |
| T08 cutover / old runtime retired | integrated: old builders off; no old Map_* in Workspace; rings re-homed except lobby Promenade (byte-identical); Studio digest 1156111094 | workers/08-cutover.md, captures/t08/, workers/08-audit.md |
| T05 M map | verified (survey): 16 surveyed points 0.0 stud GUI-chain error; M/Escape/cursor OK; lobby inert; one resolution only | workers/05-survey.md, captures/t05/ |
| Lobby after-captures (condition C) | verified after blockout and after cutover: no overworld silhouettes; no hiding needed | captures/t02/, captures/t08/ |
| Lobby duel | partial: Promenade unchanged (172 parts at (94,600,900)); queue enter/leave works solo; two-player duel NOT performed (single client); test_colosseum_runtime 135/0 | workers/05-survey.md |
| Open defects (pre-C2) | resolved: spawns wait for SiteReady flags (Studio: Phantom 65.2/62.0, Warden 144.7/140.4 at 8/15/60 s); 81x81 region grid 0 misses; radar hidden inside frame (source+unit only); removed assertions replaced; live-world suite 294/0; prologue/tutorial stakes/spawn-height fixed (not seen in Studio) | workers/09a-fixes.md, workers/08-tests.md, workers/09b-defects.md |
| Temp build (lead) | verified: 291 scripts, digest 694442432; places/ untouched; lune 35/35, py 13/13, plain luau 10/10 | scratchpad/AsurasPath_lead4.rbxlx |
| T06 compass bearings | verified: N/NE/E/S/W readouts and 351→9 sweep correct in Studio | workers/06-compass.md, workers/05-survey.md |
| C2 blockout + shrine + map/compass | verified: signed off by Fable as blockout 2026-11-15 | LEDGER "C2 sign-off" |
| C3 must-fix 1 unwritten ground | integrated + Studio sprint proof (north, real input, gap >= 362 studs, never on unwritten); guard returns to nearest written overworld altar (2 rescues proven) | workers/10-c3-fixes.md |
| C3 must-fix 4 ravine on map | verified: ReadVoxels 0 water on chasm floor; map draws depth | workers/10-c3-fixes.md |
| C3 must-fix 2 Studio items | partial: radar hidden verified; portal timeout verified (stays in lobby, toast, no banner; portal works once ready); stakes card measured (absent 149, shown 175; at 160 player is ~258 from Fo01, sight 55) → radius 160 kept; map resolutions pending | workers/10-c3-fixes.md, workers/10b-studio.md |
| Lobby L1–L5 after C3 batch | verified: mean pixel diff 0.98–2.71/255 vs baseline; no overworld silhouette | captures/t10/lobby_L*.jpg |
| C3 must-fix 2 map resolutions | verified: 640x360 and 2560x1440 (window reparented into fixed frame — not a true viewport change), 11 points 0.00 stud error; findings: small-screen marker hides behind "You" at east edge; map does not follow player | workers/10c-studio.md, captures/t10/map_*.jpg |
| C3 must-fix 3 two clients | partial: StudioTestService:ExecuteMultiplayerTestAsync(3) drivable. Casual lobby duel challenge→hit→leave→restore PASS; ranked queue→pair→Fighting→KO→release PASS; ranked winner/ELO not confirmed; casual challenge returned StepOnThreshold in 2/3 runs (flaky; baseline comparison pending) | workers/10c-studio.md |
| T09 encounters | verified in Studio: all 54 foes spawned by 18.7 s (flags 6.9–18.5 s), 0 below ground/off-region at 30 s and 242 s; engage→return→home in all 5 regions; Go02/Mo* not stuck | workers/09-encounters.md, workers/09c-studio.md |
| T10a Shen barrier (solo) | integrated: arena floor Y1580 at summit, gate z -8187; prompt 17.7 studs after fix (RequiresLineOfSight=false — gate wall buried in terrain pad slope); leave-before-entry outside verified, inside side not reachable; runback 14.9 s; KO reset unseals ≤0.8 s; "Barrier never traps" test; boss suites pass | workers/10a-shen.md, captures/t10/shen_*.jpg |
| Open: Shen gate buried in terrain slope | defect: terrain pad blend buries the gate wall; to fix before T10b | workers/10a-shen.md |
| T10b Shen multi-client (Studio, 2 real clients) | partial. Detail: workers/10b-shen-multi.md and captures/t10/shen_phase*.jpg.<br>**Passed:**<ul><li>with both players inside, Shen engages both;</li><li>one player dies while the other fights on;</li><li>no one rejoins mid-fight;</li><li>a win unseals the gate and gives AsuraBosses plus 4000 Essence;</li><li>AsuraStory stays empty (R1 holds);</li><li>25 Shen registry animation clips and the Shen sounds play.</li></ul>**DEFECTS:**<ul><li>a terrain wedge at z -8228..-8248 seals the arena (no route or line of sight), so players were teleported in;</li><li>a second player is refused silently with ArenaOccupied;</li><li>the arena is near-black as shipped;</li><li>re-entry after a win is refused silently (BossFelled).</li></ul> |
| Slice kit (Blender) | integrated as source. 10 pieces, every sub-mesh under 6k tris, 512 px PBR, GLB plus maps, script tools/blender/overworld/slice_kit.py. Not imported to Studio, not uploaded. | workers/12a-slice-kit.md, captures/slice/ |
| T11 weather/time/wind | integrated in source: Wind.luau, WeatherController, EnvironmentProfiles, EnvironmentService; test_weather_composition 100/0. The lead wired the project mappings and Bootstrap.client. The controller wiring is pending (L3b). | workers/11-weather.md |
| Relief and world edge (art a, b) | integrated in source. Edge ring with outer ranges and the south-west sea cliffs; ridges, bowls, gorge, massif terraces; summit line of sight from the glade. Terrain test 64/0; sampleAt cost 1.12x. Not seen in Studio. About 6% of corner edge samples are neither range nor sea. | workers/03b-relief.md |
| Map restyle (art e) | integrated in source. Parchment, hill shading, contours, stroked roads and rivers, ravine drawn as depth, marker inset, follow. world_map 169/0; bake time 1.0–1.1x. | workers/05b-map-style.md |
| T17 audio, first batch | partial. 2 usable beds (bellwood_forest_day, frostmere_snow); Saltreach rejected as near-silent. UPLOAD BLOCKED: the repo has no upload tooling and no ogg/mp3 encoder; local files kept; 240 ElevenLabs credits used. | workers/17-audio.md, assets/source/audio/overworld/ |
| Relief/edge in Studio (03c) | FAIL. **Pass:** the gorge and massif. **Failures:**<ul><li>east and south edge cliffs have see-through holes;</li><li>the SW coast and the N cliffs render as 1-voxel floating sheets (steep faces hollow; suspected 12-stud shell fill);</li><li>the temple is not visible by eye from the glade (line of sight is clear by raycast).</li></ul>**Generation:** glade 15.6 s, altars 36.1 s, all 4356 tiles 339 s by os.clock (~250 s game time), 195.9 MB, measured under load from the other lanes; the target is 178–181 s / 172 MB. **Map:** 0.000 error at 4 points; follow works; the arrow sits under the Tools column on the small pane; straight biome seams. **Lobby:** L1–L5 match. | workers/03c-studio.md, captures/t11/ |
| Shen arena wedge (L4b) | integrated in source. The summit peak moved behind the arena to (-7200,-8440); a rectangular pad covers arena and corridor at surface 1580; worst step 0.00. Not seen in Studio. | workers/03d-arena-terrain.md |
| Weather controller wiring + arena light (L3b) | integrated in source. The composed profile is applied; FoliageWind is the sole GlobalWind writer; wind ambience comes from the weather. ArenaLighting lifts lights by Center.Y-20 (Shen's lights had been built ~1560 studs underground). Weather test 113/0. The lead wired Soundscape.new(…, weather) and FoliageWind.new(weather). | workers/11b-weather-wire.md |
| T13 ravine stone span (L5b) | integrated in source. 199-part slate viaduct, deck 18 wide, 7 piers, 8 arches; the cave lintel is tagged AsuraShelter; test_ravine_span 25/0. | workers/13-ravine-span.md |
| Shen gate refusal feedback (L6b) | integrated in source. The baseline is single-entrant per sealed fight; players inside at start join; no rematch (fb51a42 WorldService 826-838, 861-862). The rule is kept and the refusals now show REASONS text. | workers/10d-shen-feedback.md |
| Slice kit round 2 (L2) | integrated as source. Fern fronds and layered tree crowns redone; new Bell_Terrace_Pavilion (67x67x89, ~65 px tall at 1000 studs at 1080p); detail sub-meshes up to 12.9k tris; the shrub is still weak. | workers/12a-slice-kit.md |
| Lead checks after round 2 | lune 38/38, py 13/13, build lead7 293 scripts digest 793867122; places/ untouched | - |
| Studio job B (10e) | **PASS:**<ul><li>Shen arena: walk route, lit floor, engage within 0.34 s, ArenaOccupied and BossFelled reasons with 2 clients.</li><li>Span: walk A→B.</li><li>Weather: slant matches wind from 112.5°, shelter suppression, margin fade, cleared in fights, lobby unchanged.</li></ul>**Defects:**<ul><li>rain streaks are nearly invisible;</li><li>dawn at 6.3 reads as full day;</li><li>chasm walls under the span show see-through squares;</li><li>dark rectangular panels on the arena floor.</li></ul>**Slice import BLOCKED:** open_cloud_invoke refused the assets/source/overworld/slice directory, which is not approved in Assistant Settings, MCP Permissions (creator action). | workers/10e-studio.md, captures/t12/ |
| Solid cliff faces (L4c) | integrated in source. shellBottom fills each column to the lowest neighbour minus the shell; voxels 1.10x overall, steep east edge 2.22x; test section 13 is 88/0. Not seen in Studio. | workers/03e-solid-faces.md |
| Map small-pane + seams (L5c) | integrated in source. insetFor uses the real Tools/Legend rects; tintAt is blended; world_map 436/0. Not seen in Studio. | workers/05c-map-fix.md |
| T18 PerfBudget (L3c) | integrated. Attributes on ReplicatedStorage.AsurasPath.Perf every 5 s; budgets TerrainVoxels ≤ 200 MB and heartbeat ≥ 55 Hz; Studio-only unless Perf.Enabled. The lead wired the mapping and Bootstrap.server Boot/Stop. | workers/18-perf.md |
| Slice dressing data (L6c) | integrated. 1711 placements (31 hero), PLACEHOLDER builder until mesh templates exist in ServerStorage/SliceKit; the lead wired the mappings and Bootstrap.server Start/Destroy. | workers/12b-slice-dressing.md |
| Slice kit round 3 (L2) | integrated as source. Shrub rework, 3 granite boulders, stepping stones. | workers/12a-slice-kit.md |
| Lead checks after round 3 | lune 39/39, py 13/13, build lead8 296 scripts digest 757616066; places/ untouched | - |
| Slice review captures (PLACEHOLDER geometry) | done. 45/45 cells, 2319 placeholder parts, built in 26.8 s; 6 review captures plus 2 establishing shots at about 09:00. The placeholders read as boxes; Bell Terrace is not visible from the glade at player height. | workers/12c-slice-studio.md, captures/slice_review/ |
| Perf after all tiles (Studio) | All tiles done in 183.3 s (glade 10.2 s, altars 22.9 s). TerrainVoxels 202 MB is OVER the 200 MB budget. Heartbeat 21–26 Hz while generating, 50–71 Hz after; step p95 1.8–2.8 ms. | workers/12c-slice-studio.md |
| Terrain holes after L4c (Studio) | PASS: E/S edges, SW coast (from the dune only), N cliffs and the chasm wall are solid | captures/slice_review/ |
| Map small pane after L5c (Studio) | PASS: 640x360 east edge and 994x548 SW corner arrows are clear | captures/slice_review/ |
| Audio beds round 2 | 3 more beds pass the objective checks (saltreach_basin_r2, amberfall_ravine, ashen_stair); 257 credits; human listening needed; upload still blocked | workers/17-audio.md |
| Biome placement data (no meshes) | Data only, nothing built or mapped. Amberfall 1360, Saltreach 1799, Frostmere 1728, Ashen Stair 1307 placements; 4 caves and lift stations; 91 kit slots; test 13830/0. Go02_A sits on the ShelfWest ramp line and must move. | workers/12d-biome-data.md |
| Weather defects (L5) | Fixed in source: 1.4-stud rain streaks within a 600-particle budget; dawn and dusk Horizon profile (brightness 0.70x/0.65x of noon); weather test 159/0. Not seen in Studio. | workers/11c-weather-fix.md |
| Shen arena floor panels (L6) | Fixed in source. Cause: the floor was coplanar with the terrain pad (z-fight); FloorLift is 1 stud. Not seen in Studio. | workers/10f-arena-floor.md |
| Lead checks after round 4 | lune 39/39, py 13/13, plain Luau suites pass, build lead9 296 scripts digest 329170919; places/ untouched; Studio 462022588 | - |
| C3 mechanics | returned to Fable 2026-11-15 | CONTINUATION.md |
| Lobby casual-duel StepOnThreshold flake | pre-existing: 1/3 on baseline 462022588 and 1/3 on repo state; not caused by this work; listed for creator | workers/09c-studio.md |
| C3 mechanics/persistence/encounters/Shen | planned | - |
| C4 biomes dressed, env/audio, old runtime retired | planned | - |
| C5 full verification + report | planned | - |

## Delegation ledger
| Task | Agent ID | Model requested | Why tier | Artifact | Validation |
|---|---|---|---|---|---|
| Preservation/migration inventory | a4f5c01a3b0f6391c | haiku (explicit `model`) | bounded reading | inventory/preservation.md | done; 54 tool uses; 4 escalation Qs open; return path from monastery UNCERTAIN |
| World/assets inventory + skill check | ab50b5bfca43f0685 | haiku (explicit `model`) | bounded reading | inventory/world-assets.md, inventory/skills.md | done; screenshots NOT viewed, archive grep-skim only (budget) |
| Nav/environment inventory | ab1d6ad6e541594e9 | sonnet (explicit `model`) | interface tracing across client/server | inventory/nav-env.md | done; verify_all.sh luau-on-Windows UNCERTAIN |
| Persistence escalation (8 Qs) | a431fcb1f73d51c73 | sonnet (explicit) | cross-file persistence tracing | inventory/preservation-escalation.md | done; endings need 6 sovereigns (scope flag for C1) |
| Reference archive + 16 screenshots | a57d4c86057bf869f | haiku (explicit) | reference indexing | inventory/reference-archive.md | done |
| Ticket files 01–19 | a170a495d4ae9d38d | haiku (explicit) | data authoring | .scratch/asuras-open-world/issues/ | done; 01 and 06 ready |
| T06 compass bearings | a56bb118f157f578a | sonnet (explicit) | routine Luau + test | SakuraCompass.luau diff, tools/test_compass_bearing.luau | lead reviewed diff; 3 tests pass (1828/258/421), compile OK |
| Fold rulings into tickets | afaacd2161c6d363d | haiku | doc edits | issues/01,02,03,04,05,07,11,19 | done |
| T04 streaming + Studio operator | a8f04a70789ea6210 | sonnet | lifecycle patch + live validation | 7 files, captures/t04 | lead reviewed diff; accepted; real-network latency unverified |
| T01 canonical data | af53bb729dbf5fc05 | sonnet | data authoring + test | Overworld.luau, test | lead reviewed hook; accepted |
| Condition E terrain cost (run 1) | ab3947383dd278c54 | sonnet | terrain functions + measurement | Overworld.luau terrain section, test_overworld_terrain (27/2 FAIL) | CUT OFF by usage limit (rate_limit 429); half-applied; no writer, no measurement; probe deleted by lead |
| T07 persistence migration | a1e5b00a26add570a | sonnet | persistence patch + fixtures (lead owns judgement) | ProfileStore, LootWorld, ArsenalCatalog, NarrativeCatalog, Objectives, tests | COMPLETE; lead read ProfileStore diff; suites pass with Active=false; Active=true only in scratch copy |
| Condition E terrain cost (run 2, resume) | a1d2f830b1be5bc77 | sonnet | terrain fix + writer + Studio measurement | Overworld.luau, OverworldTerrain.luau, captures/t03a | done; terrain test 29/0, data 2460/0; Studio left at digest 462022588 |

DECISION (condition E, lead, 2026-11-15): runtime generation in the BACKGROUND after boot, ordered gateway-glade-first then route order; portal entry waits (bounded) until glade tiles are written. Evidence: Forest 986 tiles 4.24M voxels 11.2 s compute / 18.7 s wall; all 5 ≈ 52 s compute / 82 s wall; TerrainVoxels ≈ 172 MB all regions; PasteRegion 0.45 s but persisting a TerrainRegion through tools/build.py NOT demonstrated → bake rejected for now. Survives build.py (terrain is source-generated). Upgrade path: Actor-parallel sampleAt (~20 s est., untested).
| T03 blockout + T02 entry/return (Studio operator) | a35d40168d36e3da4 | sonnet | builder + live validation | OverworldService.luau, Blockout data, captures/t02, captures/t03, workers/03-blockout.md | done in Studio variant (Active=true, digest 1201513283); lobby after-captures match; Studio restored |
| T05 M world map | a3e1c833ca98b9188 | sonnet | client UI + pure tests | WorldMap.luau, WorldMapController.luau, InputMap, SakuraHud/Minimap, Bootstrap.client | source + 118 tests pass; Studio NOT verified |

Lead integration 2026-11-15: mappings OverworldService, WorldMap, WorldMapController; PauseMenu "World map" entry (gamepad/touch path). Temp build 291 scripts digest 162161560; lune 32/32.
DECISION (T08, lead): PvP rings keep IDs. Ring_SanctuaryPromenade (lobby) untouched; Ring_GatehouseCircle → Bellwood gateway glade area; Ring_OctagonOfAsh → Ashen Stair foothills settlement (M1). Old builders retired from Bootstrap runtime; their source files and mappings stay for this reviewable handoff (cleanup = creator follow-up). Archived-builder tests run with an Overworld.Active=false stub. Inactive bosses keep World.Bosses entries but lose fog gates/arenas/regions.
Milestones: T03 blockout = blockout (Studio variant); T02 = integrated (variant); T05 = integrated (source).
| T08 cutover (Studio operator) | afca46d60880ea56a | sonnet | integration + live validation | workers/08-cutover.md | complete; lead reviewed WorldService diff |
| Post-cutover test audit | a37b9bffd76733c6b | sonnet | review | workers/08-audit.md | 3 removed assertions, 6 archive-only suites flagged |
| Survey: altar-first, map, compass, duel (Studio) | a597ef01e081af81b | sonnet | live validation + fixes | workers/05-survey.md, captures/t05 | done; mob-spawn-before-tiles defect found |
| Pre-C2 runtime fixes (Studio operator) | a37f902503e066e76 | sonnet | spawn gating, region coverage, radar | workers/09a-fixes.md | done; Studio restored 462022588 |
| Live-world test coverage | a09b5ffea35775268 | sonnet | test authoring | tools/test_live_world_mechanics.luau, workers/08-tests.md | done; found 4 src defects |
| Live-world src defects | a64d8ef4132355aba | sonnet | small src fixes | workers/09b-defects.md | done; lead checked tutorial assertion swap (not loosened) |
| Fold C2 review into tickets | a287ddd7ee5606d95 | haiku | doc edits | issues 02,03,05,10,11,12,13,15,16,18,19 | done |
| T09 ordinary encounters (source) | a5d60e5d11902439c | sonnet | data + tests | workers/09-encounters.md, tools/test_overworld_encounters.luau | complete; 35 groups / 54 foes; Studio verify pending |
| L1 slice studio | a1c7cf6cff876d873 | sonnet | Studio | workers/12c-slice-studio.md | done; Studio 462022588 |
| L3 audio round 2 | af94b540f5a003e7a | sonnet | assets | workers/17-audio.md | done |
| L4 biome data | a13fc923edeef0abf | sonnet | source | workers/12d-biome-data.md | done |
| L5 weather defects | adaf520125556c471 | sonnet | source | workers/11c-weather-fix.md | done |
| L6 arena floor | adb5b591b878489d1 | sonnet | source | workers/10f-arena-floor.md | done |
| L1 Studio job B | a74e120851466d13a | sonnet | Studio verification | workers/10e-studio.md | done; Studio 462022588 |
| L2 slice kit round 3 | a41aa8d83d31d7426 | sonnet | Blender | workers/12a-slice-kit.md | done |
| L3c T18 PerfBudget | a71f495b1ae2d8615 | sonnet | source | workers/18-perf.md | done |
| L4c solid faces | a03998532ee4bef29 | sonnet | source | workers/03e-solid-faces.md | done |
| L5c map fixes | af2bf869cc344d9fc | sonnet | source | workers/05c-map-fix.md | done |
| L6c slice dressing data | ac8c795bba3c26953 | sonnet | source | workers/12b-slice-dressing.md | done |
| L1 Studio job A (relief/map/lobby) | a682baf65264e0207 | sonnet | Studio verification | workers/03c-studio.md | done; Studio 462022588 |
| L2 slice kit round 2 | abf6a138e56938789 | sonnet | Blender | workers/12a-slice-kit.md | done |
| L3b weather wiring + arena light | a8e5a03cc6b5f7b24 | sonnet | source | workers/11b-weather-wire.md | done |
| L4b Shen arena terrain | ab25df5713a378d0f | sonnet | source | workers/03d-arena-terrain.md | done |
| L5b ravine span | a14e74a29d5b3811e | sonnet | source | workers/13-ravine-span.md | done |
| L6b Shen gate feedback | a26301023e9201a89 | sonnet | source | workers/10d-shen-feedback.md | done |
| L1 T10b Shen multi-client | a39ec39e97e12f1fb | sonnet | Studio 2-client | workers/10b-shen-multi.md | done with defects; no src change; lead re-verified Studio 462022588 |
| L2 slice kit | ac3abcb0801325dec | sonnet | Blender | workers/12a-slice-kit.md | done |
| L3 T11 weather | a7bc7f3c36f3bb923 | sonnet | source | workers/11-weather.md | done; lead wired project.json + Bootstrap.client |
| L4 relief/edge | aab6bf89b50c58df7 | sonnet | source | workers/03b-relief.md | done |
| L5 map restyle | af534849cefb0370e | sonnet | source | workers/05b-map-style.md | done |
| L6 T17 audio | a5be847d032233768 | sonnet | assets | workers/17-audio.md | done; upload blocked |
| T10a Shen barrier solo (Studio) | a8dbd9490f9211378 | sonnet | live validation + small fix | workers/10a-shen.md | done; WorldService gate prompt LOS fix; Studio 462022588 |
| S3 T09 Studio verify + duel flake | a054e2cf9a275447e | sonnet | live validation | workers/09c-studio.md | done; no source change; Studio 462022588 |
| S2 map resolutions + two clients (Studio) | a1fd43bef72a1b3c2 | sonnet | live validation | workers/10c-studio.md | done; no source change; Studio 462022588 |
| S1 portal timeout / stakes / lobby (Studio) | a047985c4c62234bb | sonnet | live validation | workers/10b-studio.md | done; no source change; Studio 462022588 |
| C3 must-fix batch (Studio) | ab5adb1773ca151d8 | sonnet | guard + generator + map + Studio | workers/10-c3-fixes.md, captures/t10 | CUT OFF (usage limit ~08:21); source complete, lead reconciled; Studio left in Play on variant 1124047492, restored by lead to 462022588 |

Reconcile 2026-11-15 (third stop): lune 35/35, py 13/13, build lead5 digest 1173473752. Per-file verdicts in CONTINUATION.md.

Reconcile 2026-11-15: tree matched worker notes after lead review; see CONTINUATION.md for per-file ownership and test results.

Model evidence: `model` passed explicitly on each Agent call; no fallback warning returned by the runtime. Observed running model not independently verified from transcripts (label: requested, unverified-observed).

## C1 rulings (Fable, 2026-11-15) — signed off; proceed to C2
- R1 Endings deferred with archived bosses; ending code and saved sovereign/ending flags untouched; nothing in the world promises an ending; final report lists it as creator decision. No faked sovereign progress.
- R2 Layout approved. Display names original (no Goldland/Thonia/Fragment); reconcile GLOSSARY.md + Revision 02, else: The Bellwood, Amberfall Ravine, The Saltreach, Frostmere Heads, The Ashen Stair; keep Ash Colosseum.
- R3 ESE prevailing overworld wind; lobby keeps its own; one wind source (foliage, precipitation, cloth, ambience).
- A Continuous N–S divide: mountain south spur → monastery ridge → ravine high east rim; ravine far side + basin in its lee; ravine = dry-grass transition.
- B No straight box-edge biome borders; authored transition bands; environment/weather blend margin.
- C Capture lobby cameras BEFORE any overworld geometry in the open place; if silhouettes show from the lobby, hide overworld landmarks for lobby players (no lobby fog/lighting change).
- D Streaming (T04) validated on the existing world first; take fallback early if it fails.
- E Measure server boot time + memory for runtime terrain gen (CampaignTerrain approach) on one region before choosing generation vs baked-in-place vs hybrid; choice must survive tools/build.py.
- Also: new spell caches — no duplicates for owners, fresh profile earns both (T07 acceptance); retired altars never fast-travel/map markers; C2 reports measured traversal with real inputs.
- Delegation for run 2 verified from runtime records by Fable (DELEGATION_STATUS.md); routing no longer marked unverified.

## C2 sign-off (Fable, 2026-11-15) — signed off as blockout; proceed T09, T10 toward C3
Reviewed captures: forest_elevated, mountain_entry, ravine_crossing_elevated, generating_far_void, map_overworld.

MUST FIX DURING C3 (function)
1. Unwritten ground: no player on foot, gliding or fast-travelling may reach unwritten ground (sprint ≈ 6,000 studs in 180 s). If reached anyway: stop them or put them back at the nearest written overworld altar, never drop to the lobby. Suggested: generate tiles nearest current players first, after arrival sites. Prove with a test + one Studio run sprinting away from the glade from second 9.
2. Close unverified Studio items: radar hidden in overworld; portal-wait timeout path; map at two more resolutions (one small, one large); death (stakes) card distance measured, not guessed.
3. Two clients: try a real two-client Studio local-server test for the lobby duel now and Shen participants at T10; if tooling cannot drive it, say so and leave both unperformed.
4. Map draws ravine floor water blue: if dry, draw depth; if flooded in-world it is a terrain defect (deep dry ravine with seasonal stream).

ART DIRECTION T12–T16 (non-blocking for C3)
a. World edge: no straight slab cut visible from any route/landmark; unreachable outer ranges, sea cliffs, haze, irregular coast; lobby island skyline not behind it.
b. Relief: mountain massif (cliffs, galleries, hard summit silhouette, temple readable from glade); forest ridges, river gorge, distinct clearings.
c. Light: overworld profiles via existing environment owner; glare capped, combat fill kept; lobby lighting untouched.
d. Ravine crossing: legible stone span with mass (no plank on stilts).
e. Map look: same data, restyled bake — parchment, no speckle, hill shading/contours, clean road and river strokes.
f. Caves: real roofed interiors suppressing weather by C4. Fade-teleport lifts may stay if both ends are built structures and the map shows the link.

REVIEW GATE: before mass dressing, finish one slice (gateway glade → Bell Terrace: terrain materials, vegetation kit, one structure kit, overworld light) and return six player-height captures before biome variants. C3 returns for mechanics; slice review with it or straight after.

## C3 sign-off (Fable, 2026-11-15): mechanics signed off; slice NOT signed off (placeholders)
Rulings on the lead's decisions:
1. **Runtime terrain: accepted, with two MUST-FIXes.**
   - (a) Terrain memory ≤ 185 MB after completion. Do not solid-fill deeper than needed; review the 03e fill depth.
   - (b) Server heartbeat ≥ 45 Hz while tiles are written: per-frame time slice. Nearest-player priority, the guard tests and the sprint run must still pass. Report the numbers.
2. Wind from 112.5°: approved.
3. Rings re-homed: approved.
4. Old builder source: approved only if none of it is mapped or reachable at runtime. Prove it with a test or grep, and list the files for the creator.
5. Single sealed Shen fight: approved.
6. Summit peak and the +1 stud floor: approved, on condition that the summit temple silhouette is visible from one player-height point in each of the 5 regions. Capture all five for C4.
7. Encounter terrain after altars: approved.
8. PerfBudget off in live: approved.
9. Endings deferred: stands, as a creator decision in the final report.

Slice faults, to fix before any mesh goes in:
- **A:** canopy cover across the slice, not just along the road: clustered with a noise mask, clearings, scale 0.7–1.4, random yaw, understory in the gaps; canopy undersides ≥ 14 studs over the road.
- **B:** real relief: the road climbs, the terrace sits on a visible rise, and at least one ridge or gorge lies between glade and terrace.
- **C:** the broken bell tower is visible above the trees from the glade arrival point at player height, with a sightline along the road; capture it.
- **D:** forest-floor material and scatter within ~30 studs of the glade altar.
- **E:** pale blue-grey "puddle" patches on the road: find the material and fix it.
- **F:** teal haze swallows everything past ~600 studs; ease it so far ridges and the summit read as silhouettes (overworld only).
- Check defect 6 (JadeDialogue/SpectatorWagers frames visible) on a clean baseline Play. If it predates this work, record it and leave it.

Kit approved in direction; tri counts stay under the cap and are recorded.

UPLOADS are BLOCKED on the creator:
- No workaround routes, no copying the files elsewhere, no runtime GLB loader.
- Dress with assets already registered (registries only, never invented IDs); the lobby's instances are never moved.
- Placeholders stay for pieces with no registered asset; the swap is a data change (name → ID).
- Prepare a one-step upload: a folder of final GLB/FBX, a manifest (name, tris, size, registry file), and the 3D Importer steps. Same for the 5 audio beds (file, length, loop points, where each plays).

Return at C4: all five biomes dressed as far as uploads allow, weather/time/wind/audio composed, old runtime retired, budgets met. Return earlier if the upload answer is needed.

## Creator direction (via Fable, 2026-11-16) — art bar raised
Verbatim: "can you add like a lot more detail and meshes that would make it look better".

**Mesh throughput:**
- One live Blender operator, plus 3–4 headless mesh lanes (`blender -b --python`).
- Each headless lane has its own .blend, its own export subfolder under assets/source/overworld/ and its own script under tools/blender/overworld/. Headless Blender is verified OK (5.2.2).

**Kit breadth per biome before C4:** three layers (vegetation, rock, built), plus the hero landmark and the pieces its subareas name. Each lane lists its pieces before modelling.

Bellwood minimum:
- **Vegetation:** 5 tree forms, dead trunk, fallen log, stump, roots, 3 shrubs, 2 ferns, flowers, mushrooms, vines or moss, reeds, grass cards.
- **Rock:** boulders, scree, mossy outcrop, cliff pieces.
- **Built:** stair runs, retaining walls, paving and edging, gate, fences, shrine, bell graves, prayer flags, signposts, well, carts, crates, pots, lantern variants, broken tower with a real ruined top, hermit hut, rope bridge, falls alcove.

**Standard:**
- High-detail master, baked PBR, each sub-mesh under the triangle cap, 3D Importer + SurfaceAppearance.
- Silhouette first; 2–3 variants of anything that repeats in view.
- Player-height render beside a 5.5-stud figure.
- Manifest records tris, texture size and file size.

**Placement:** three scales in every view; clustered, never grid; a composed set piece at every altar, cache, encounter site and landmark.

**Constraints:**
- T18 budgets still bind; bring measured trade-offs.
- Sourcing: original work only; nothing that spends credits or needs a new key or account; no reference-game likeness.

**Review:** the Bellwood kit sheet and one composed vignette per biome go to Fable as ready; other lanes do not wait.

## Upload authorisation (creator via Fable, 2026-11-16)
Q: "How should the new meshes get into Roblox?" A (creator, verbatim): "Lead uploads them".

**Covered:** meshes and their textures made for this task under assets/source/overworld/, to the creator's own account, via the Studio session's authenticated route or the 3D Importer.

**NOT covered:**
- the audio beds (prepare only);
- making anything public or putting it on the marketplace;
- publishing or saving the place;
- anything costing Robux or credits;
- any new key or credential.

If an upload asks for payment or a setting change: stop and report.

**Folder approval** (Assistant Settings → MCP Permissions, C:\Users\disha\Documents\asuras-path\assets\source\overworld) is the creator's step. Try the lantern post first. If it is refused, do not work around it; note it and tell Fable.

**If the lantern post uploads:**
1. Verify the ID in a Play copy at player height, then upload in batches, slice kit first.
2. Finished pieces only, no _r1 or drafts.
3. One uploader: the Studio operator.
4. Every ID goes into an *_UPLOADED.json registry, from real responses only.
5. Then swap the slice to real meshes, fix faults A–F, and send 6 new captures (the slice review). Real-mesh dressing of the other biomes follows that review.

## Upload attempt and Studio cloud-save (2026-11-16)

**Upload test (worker a8054cd8d2a89f7c0):**
- The Bell_Lantern_Post upload was REFUSED before sending: the file's directory is not approved in Assistant Settings → MCP Permissions.
- No IDs and no prompts.
- Per Fable, MCP Permissions are locked for a local-file place ("Save to Roblox to manage MCP permissions").

**Cloud save:**
- The creator first chose "Save to Roblox", then cancelled, verbatim: "nevermind, dont worry about it for now."
- The park request was cancelled before Studio was parked; Studio stayed at baseline 462022588.
- The never-save rule is back in full, with no exception.

**Uploads:**
- The authorisation stands, but the Studio route is CLOSED until the place is saved to Roblox (the creator is not doing that now).
- No upload attempts and no other route.
- Keep every batch upload-ready.
- Dress with registered assets plus placeholders matched to each real piece's bounding size and rough silhouette.

**Slice review:** six Studio captures with registered assets and placeholders, plus a matching Blender vignette of the same views built from the real kit.

## Round 6 results (2026-11-16)
- **T2 (a8d96d079eec28b3e):**
  - Slicer and sim tests; urgent 256-stud refocus band; order test 450/0.
  - Terrain tests 100/0: memory estimate 159 MB at SHELL 8 (SHELL 12 reproduces 201 MB); fault B ridge and climb; fault D glade floor now LeafyGrass/Grass; fault E 0 pale samples.
  - Go02 moved 49 studs off the ShelfWest ramp line.
- **D2 (a716ae44100928f80):** Assets filled from registries:
  - Bell_Lantern_Post → PHASE5 AsuraBrassLantern 105652153407631;
  - Boulder_Granite_B → PHASE5 AsuraStone 106842288070597;
  - Grass_Clump → LIVING_BAMBOO Ground_GrassTuft 81752398968484.
  
  The builder resolves registry → Assets → placeholder. SliceKitRegistry.luau is a generator to write after uploads. Slice test 201/0.
- **X (a73f55e854b87a3cd):** the Shen trigger seals only for a player seen outside first (fixes the inside-walk-out trap). BossArenas no longer requires CampaignTerrain (exposeFloor inlined). Boss test 323.
- **R (a31744ce266b6f6f1):** rain Squash 2 → -2 (VelocityParallel already set); weather test 242.
- **M1 (a431c9a9fbf3ffcbe):** 27 Bellwood vegetation pieces (largest sub-mesh 14.1k); upload/bellwood_veg.
- **M2 (a6c1febb90d7c638c):** 31 Bellwood rock and built-A pieces (largest 11.6k); upload/bellwood_built_a.
- **M3 (a02fd935cce8d61c9):** 16 built-B pieces, including Bell_Tower_Ruined (76.7 studs, 8 sub-meshes) and Falls_Alcove; upload/bellwood_built_b.
- **Ruling 4, partial (lead):**
  - Unmapped 12 retired builders in default.project.json: MonasteryService, CampaignWorld, CampaignTerrain, CampaignBounds, BambooDressing, PagodaDressing, CitadelDressing, MonasteryGrounds, MonasteryTerrain, MonasteryAtmosphere, MonasteryBounds, BambooEcology.
  - Grep: no live-path require of these. The rest of the monastery cluster (Halls, Ruins, Survey, Landmarks, Pockets, Secrets, Fx…) needs a graph analysis; MonasteryKit is live (lobby).
  - test_monastery_route hygiene now asserts the 4 retired monastery builders are NOT mapped.
- **Lead checks:** lune 39/39, py 13/13, build lead10 284 scripts digest 1053460866.

## Round 7 (launched 2026-11-16 03:00, cut off at the sixth stop, resumed ~07:35 with SendMessage)
| Lane | Agent (sonnet) | Note | State |
|---|---|---|---|
| S2a Studio (terrain numbers, then slice 01–07, summit x5, rain/haze, Shen) | a1c4cc703ff90612d | workers/22a-studio.md | resumed |
| LB vignettes 01–07, then Bellwood kit sheet | af956a53efda68bdc | workers/22e-kit-sheet.md | resumed |
| D3 slice kit placement | aa9fe61f94d2b0cc0 | workers/22b-slice-kit-placement.md | resumed |
| RG ruling-4 reachability | a43a4f98135500586 | workers/22d-reachability.md | resumed |
| M5 Saltreach (by family) | a9ec2c62161bac5a1 | workers/23b-salt-kit.md | resumed |
| M4 Amberfall (by family) | aef37b82aca003a87 | workers/23a-amber-kit.md | resumed |
| D4 biome builder | a663a883d3ff85a91 | workers/22c-biome-builder.md | queued for the next window (no files written) |
| M6 Frostmere | aba8b432b8e428c3f | workers/23c-frost-kit.md | queued for the next window (no files written) |

Run rule: each worker writes its plan and file list first and adds a one-line checkpoint after every edit or export. Mesh work runs one family per script run.

### Round 7 results
- **RG (a43a4f98135500586, workers/22d-reachability.md):**
  - NEW tools/test_retired_unreachable.py builds a require graph from the 3 mapped roots (Loading.client, Bootstrap.server, Bootstrap.client). It passes.
  - 13 mapped modules were unreachable. Lead decision: unmap 11 retired ones (BambooFoundry, ColosseumDressing, CryptDressing, MonasteryDressing, MonasteryHalls, MonasteryLandmarks, MonasteryPockets, MonasteryRuins, MonasterySecrets, MonasterySurvey, MonasteryRidgeProfile). The RETIRED list is now 23.
  - **CREATOR LIST:** SolarForms (client) and PresentationAudit (server) stay mapped but are orphans outside this task's retirement; KNOWN_ORPHANS in the test. The creator decides.
  - Tests adjusted to the retirement:
    - test_monastery_route: everything except MonasteryKit asserted unmapped;
    - test_monastery_discovery: Pockets and Secrets are retired;
    - test_github_reuse.py: MonasteryRidgeProfile asserted unmapped.
  - Dynamic requires reviewed: BossAppearance, ArsenalFacts, CampaignZones (literal tables) and SliceDressing (SliceKitRegistry).
  - The retired source files stay on disk (23, listed by the test's "RETIRED on disk" output).
- **D3 (aa9fe61f94d2b0cc0, workers/22b-slice-kit-placement.md):**
  - All 95 manifest pieces have bbox-matched (±5%) placeholder specs held as data.
  - Bell_Tower_Ruined replaces Broken as TowerMid, with the sightline from the glade clear.
  - Scatter: 5 tree forms, clustered with clearings, plus the full veg/rock scatter. Canopy clearance ≥14 over the road holds; the glade-altar floor ring is 46% covered.
  - 8 composed sets (157 pieces); 3 scales in all 7 capture views.
  - The SliceKitRegistry pcall is a documented fallback, and build() is tested with the module absent.
  - Test 936/0 (lune 960/0).
  - Budgets: placements 1456/1900, placeholder parts 2856/3400, kit MeshParts 2444/3000, tris 4.74M/5.0M (LOD-dropped 3.17M/3.2M).
  - Trade-off: trees fell from 196 to about 140 to fit the tri budget.
- **LB (af956a53efda68bdc, workers/22e-kit-sheet.md):**
  - Bellwood kit sheet: 16 PNGs in captures/kit/bellwood_sheet/ (95/95 pieces imported, 5.5-stud figure, labels).
  - Vignettes 01–07 rendered from the real kit, in assets/source/overworld/vignettes/ with vignettes.blend.
  - Caveat: they were built from the PRE-D3 placement dump (1458 placements plus about 95 LB-added set pieces), so the next round re-renders them from the D3 build.
- **M4 (aef37b82aca003a87, workers/23a-amber-kit.md):** Amberfall, 45 pieces (veg 18, rock 11, built 15, Aqueduct hero). The largest sub-mesh is 16,720 (Aqueduct_Hero__Piers). Pack in upload/amberfall; renders in captures/kit/amberfall/ (33 of 45 not yet eyeballed).
- **M5 (a9ec2c62161bac5a1, workers/23b-salt-kit.md):**
  - Saltreach, 37 pieces (veg 11, rock 11, built 14, Gate Statue hero 70×143×47). The largest sub-mesh is 14,016.
  - Pack in upload/saltreach; renders in captures/kit/saltreach/.
  - Note: the repo's Saltreach is an arid basin, so the shore pieces use the sand/salt palette.
- **D4 (aa58d1623cf64c556, fresh Agent; workers/22c-biome-builder.md):**
  - NEW BiomeDressingService plus a BiomeDressing plan(): 3 tiers, noise mask, set kits at all sites (4/10/9/12), visibleAt thinning, 15 PHASE5 fits, everything else a placeholder.
  - PartBudget 1500 per region: Ravine 1500, Basin 1073, Snow 1269, Mountain 1500.
  - Lazy per region within 1000 studs; unloads after 60 s; yields every 2.5 ms. Test 18181/0.
  - Lead wired it: default.project.json (BiomeDressing, BiomeDressingService) and Bootstrap.server (require, Start after SliceDressing, Destroy before SliceDressing).
  - Heartbeat is not yet measured in Studio.

## Creator published the place; uploads opened (recorded 2026-11-16 13:03)
- **Creator, verbatim** (relayed by Fable): "allowed full mcp permission now, had to publish it to roblox as.. do whatever you need to do". This was the creator's own action; the lead and workers still never save or publish.
- **Studio now:** "Asura's Path — Development", placeId 118614906972571, universe 10777041159, persistedToCloud true, Edit mode.
- **Lead check at 13:03:**
  - Digest `scripts 286 bytes 2859366 digest 462022588` matches the baseline, so the cloud copy holds the clean baseline. The S2a variant had died with the 08:13 exit, before the publish.
  - HttpEnabled false; Workspace holds AsurasPath, Terrain and Camera.
  - Config.Backend StudioLiveData = false, so Play still uses mock persistence.
  - **NetworkClient is present in the Edit DataModel: Team Create (collaborative editing) is ON.** Edit-DM changes replicate to the cloud place, so the in-memory sync-and-restore would write test variants into the creator's cloud place.
  - Per Fable's rule, Studio work and the upload test are STOPPED and the lead returned to Fable. Not tested: whether script edits go through drafts.

## Team Create ruling (Fable + creator, recorded 2026-11-16 ~13:20)
- **Creator, verbatim (operative parts):**
  - "Upload the five task audio beds too; that is approved."
  - "Please have the Opus lead continue on a separate LOCAL file/test copy, keeping the cloud-connected place untouched: save a local copy if needed, open that local copy separately, confirm persistedToCloud=false before temporary sync/Play tests. Use the existing cloud-connected instance only for approved task mesh/audio uploads, with one upload owner and no duplicate uploads. Do not disable Team Create or alter permissions/settings. Verify the lantern first, then kit/audio batches, registries, real-mesh forest integration and player-height captures. Continue existing preservation and acceptance requirements. Report any actual blocker precisely; no need to wait for another approval for this local-copy workflow."
- **Creator's independent check:** universe 10777041159 is PRIVATE; root place 118614906972571; Edit scripts match the baseline (286 scripts, 2859366 bytes, 462022588).
- **Two windows:**
  - **TEST (local scratch copy, persistedToCloud false):** all syncs, Play, captures and measurements. Every write script asserts the window identity first.
  - **UPLOAD (cloud 118614906972571):** upload calls only. No edits, inserts, Play syncs, setting changes, save or publish.
- **Uploads:** one owner, registry checked first, no re-uploads, checkpoint written right after each ID. Order: lantern → verify in TEST Play → slice kit → Bellwood + hero → 5 audio beds → later biome kits.
- **Heartbeat targets (ruling 1b):** ≥45 Hz while writing, no dip under 30 Hz longer than 1 s; glade ≤20 s; all altars and arrivals ≤90 s; whole map ≤10 min; memory ≤185 MB. The 45-minute T3 version must not ship.
- **Saltreach as a dry basin is correct** per GEOGRAPHY_PLAN.

## Round 8 results (2026-11-16)
- **T3 (ac6a972d4b3533876, workers/24a-terrain-heartbeat.md):**
  - Root cause: one uninterruptible WriteVoxels per 128×64×128 slab, a whole-slab FillBlock in Clear, and an unbudgeted shellBottom loop.
  - Fix: bounded column boxes of about 2.5 ms each, cost reserved before each call, an adaptive slicer (halves to a 1.5 ms floor when Heartbeat dt > 1/45 s, skips a frame at the floor, recovers).
  - Order 472/0, terrain 100/0.
  - Risk: at an assumed 8e-6 s per voxel the glade takes about 50 s (target about 20 s) and all tiles about 45 min. Studio must measure.
- **LB2 (a2077dccae061f30b, workers/22e-kit-sheet.md):** vignettes 01–07 re-rendered from D3's 1456 placements (pre-D3 copies kept). The tower is clear in 04, only a sliver in 01 and barely visible in 07 (trees on the sightline), so fault C is still open in the vignettes. No floating or sunk pieces seen.
- **D5 (a0817681213bc5b5f, workers/22c-biome-builder.md):**
  - All 82 Amberfall and Saltreach pieces have specs within ±5%. Hero slots: Ravine_Aqueduct_Arch→Amber_Aqueduct_Hero, Basin_Gate_Statue→Saltreach_Gate_Statue.
  - Kit use: Ravine 38/45, Basin 36/37. Parts: Ravine 1500, Basin 1078, Snow 1270, Mountain 1500.
  - Test 19179/0. Registry modules (AmberfallKitRegistry, SaltreachKitRegistry) to be generated after upload.
- **M6 (a26a6c14310d5cf92, workers/23c-frost-kit.md):** Frostmere, 32 pieces (veg 12, rock 10, built 9, Beacon hero 18×100×18). The largest sub-mesh is 17,504 (Frost_Cliff_Corner__Stone). Pack in upload/frostmere.
- **M7 (a61e64cb132cd91da, workers/23d-ashen-kit.md):** Ashen Stair, 34 pieces including Ash_Summit_Pagoda (60×160.6×60) and Wing. The largest sub-mesh is 16,004. A 1000-stud silhouette render is in captures/kit/ashen/. Pack in upload/ashen.

DECISION (R3 wind, lead, 2026-11-15): "east-south-east prevailing" is read meteorologically. The wind blows FROM 112.5° toward WNW, which is consistent with the rain shadow (condition A). The lobby keeps its own {6,0,2}. Wind.Prevailing.FromDegrees = 112.5.
DECISION (audio upload): blocked. There is no upload tooling or credentials path in the repo, so the beds stay as local files; listed for the creator.

## Decisions log
- 2026-11-15: restart #2; nothing on disk from run #1 except brief + DELEGATION_STATUS.md.
- 03c-studio (Lane 1 Studio verification of lanes 4/5): workers/03c-studio.md

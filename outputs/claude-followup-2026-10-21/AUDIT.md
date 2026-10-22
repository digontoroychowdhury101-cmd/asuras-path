# Independent follow-up audit — 21 October 2026 (Australia/Sydney)

The old 26 batches were **addressed at implementation level, not completed at acceptance level**. All 26 initial batch rows say Implemented — acceptance pending. The old final disposition is 0 Verified, 40 Implemented — acceptance pending, 4 Blocked on production art (#22/#23/#24/#32). The independent checks below support existing local implementation but do not upgrade those acceptance claims. Several art/navigation/animation deliverables remain partial.

## What was actually checked now

- Read the 44-finding playtest report, old 26-batch manifest and progress/acceptance notes; inspected runtime entry points and selected changed systems; mapped representative implementation and regression files for every old batch.
- Ran all 15 regression commands in the current verifier before its saved-place overwrite step. All passed; `lune_compat.py --all` included **17 emulated suites**. [Raw log](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21/LOCAL_TEST_LOG.txt>), [command results](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21/local-test-results.json>).
- Also ran **4 omitted checks**, all passed: backend, commercial systems, boss encounters (286 checks), audiovisual. [Additional log](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21/ADDITIONAL_TEST_LOG.txt>), [results](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21/additional-test-results.json>). Thus **19 successful command invocations**, not 19 independent engine sessions.
- Compiled **206 source scripts**, zero syntax failures; validated **206 Rojo $path mappings**, none missing. Built the full unstripped project to `/private/tmp/AsurasPath_Codex_Audit_2026-10-21.rbxlx`. Preserved the saved `outputs/AsurasPath.rbxlx`. [Static/build results](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21/static-check-results.json>).
- The existing audiovisual test passed 13 imported templates / 56 complete PBR MeshParts and 8 available PBR exports. This verifies the test's declared local scope, not Studio attachment/permissions or a listening pass.
- Saved a SHA-256 [source/project snapshot](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/claude-followup-2026-10-21/source-snapshot.json>); confirmed this audit did not change game source or `default.project.json`. Existing test runners generated their usual ignored work files; no game fix, asset upload, publication or new Studio play was performed.

The original playtest reached/killed normal enemies and assisted six boss starts; it did not establish a boss victory or full ending. The previous connection check in this chat got an MCP handshake but zero tools. This audit did not retry or certify a repaired live connection. Prompt 01 explicitly requires a current harmless Studio read and current-place identity.

## Concrete gaps requiring follow-up

| ID | Independently observed fact | Implication and owner |
|---|---|---|
| A1 | `docs/BUILD.md` still describes Cagebound Phase 12/missing commands. `tools/build.py` still prints hard-coded `external asset IDs: 0`. Older notes call the Phase 5 library missing, but it now exists and a complete build passed. | Correct current guidance/output and distinguish historical state; prompt 01. Do not recreate an already restored library or strip it from the build. |
| A2 | `verify_all.sh` omits direct backend/commercial/boss-encounter/audiovisual commands; they passed when run separately. | Consolidate existing meaningful checks, not duplicate new tests; prompt 01. A green current main runner does not include all claimed checks. |
| A3 | Saved library has no `AsuraBoss_*` models. Character/region production-art blockers remain recorded; local costumes and layout boxes exist. | Actual art/rig/animation/kit delivery plus real views is still required. Prompts 10–20; exact contracts in ASSET_REQUIREMENTS.md. |
| A4 | `AnimationCatalog` uses nil custom slots (45); `BossAnimations` routes humanoid idle/action/transform through four Shen keys, not per-boss/per-attack lookup. No shipped `AsuraBossAnimation_*` assignments were found in the project/library. | This is a content **and dispatch/integration** gap, not only an external import request. Prompt 10 owns shared mapping; 11–12 own creature/caster/dragon integration. |
| A5 | `SakuraMinimap` still draws entity/altar dots and cardinal labels without route geometry. Old progress explicitly says the minimap was unchanged, although `RouteGuide` now stages the main waypoint. | Finding 28 is partial implementation even before live acceptance. Prompt 14 supplies a bounded route/connection layer; 15–20 validate it on their routes. |
| A6 | `BossMusic` falls back to BossDrone; no `BossMusic_<bossId>` tracks appear in the saved project/library. Old notes have no actual listening or profiler capture. | Placeholder music, mix/listening and measured performance remain open; prompt 25. Estimates/part counts cannot pass measured FPS or bandwidth. |

Other disclosed limits: geometry checks and 44-pt target arithmetic do not prove touch usability; `keybinds` is a legacy table, not a functioning remapping UI. Mock wagers/DataStore replay do not prove real delivery. Fresh-profile teaching and ~100 ms deflect fairness need real continuous input. The new prompts retain these distinctions instead of inventing new defects or unproven root causes.

## All 26 original batches checked and assigned

Every listed representative file exists now. The audit compilation/build includes all src files; local tests support the implementation column. These checks do not prove every code path correct. See the preserved old ledger for detailed historical changes and the raw new logs for current executions.

| Original | Work | Current audit disposition | Representative source / regression | Follow-up | Acceptance still open |
|---|---|---|---|---|---|
| 01 | Checkpoint, death and recovery lifecycle | Implementation present; acceptance pending | [RecoveryRules.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/server/RecoveryRules.luau>); [test_recovery_lifecycle.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_recovery_lifecycle.luau>) | 02 | Actual rest/death/respawn positions at every altar; earned loss/recovery/rejoin. |
| 02 | One consistent input and interaction map | Implementation present; acceptance pending | [InputMap.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/InputMap.luau>); [test_input_map.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_input_map.luau>) | 03 | Real keyboard/controller/touch prompt ownership and held inputs. |
| 03 | Readable combat lighting and stable audio cleanup | Implementation present; acceptance pending | [ArenaLightPlan.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/ArenaLightPlan.luau>); [test_combat_presentation.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_combat_presentation.luau>) | 09 | Steady-light six-arena views and real repeated-cycle audio logs/listening. |
| 04 | HUD layout, health readability and death transitions | Implementation present; acceptance pending | [HudLayout.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/client/Controllers/HudLayout.luau>); [test_hud_layout.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_hud_layout.luau>) | 03 | Real HUD state views, crowded labels, transitions and hardware readability. |
| 05 | Rest, Lin dialogue and leveling flow | Implementation present; acceptance pending | [LevelPreview.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/LevelPreview.luau>); [test_rest_dialogue.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_rest_dialogue.luau>) | 04 | Real three-altar portraits, leveling, return/travel and interruption. |
| 06 | Useful Arsenal descriptions and Codex progress | Implementation present; acceptance pending | [ArsenalFacts.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/ArsenalFacts.luau>); [test_arsenal_codex.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_arsenal_codex.luau>) | 05 | Real empty/partial/full Arsenal/Codex and long-text/focus behavior. |
| 07 | Monastery collision, altar clearance and arrival repairs | Implementation present; acceptance pending | [MonasteryBounds.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/server/Services/MonasteryBounds.luau>); [test_monastery_route.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_monastery_route.luau>) | 14 | Real bridge duel, altar clearance, terrain/ladder/veil physics and arrival. |
| 08 | Earned remembrance and complete boss reward pipeline | Implementation present; acceptance pending | [ArsenalInventory.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/simulation/ArsenalInventory.luau>); [test_boss_rewards.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_boss_rewards.luau>) | 06 | Earned boss → Gao → choice → item/use → durable rejoin. |
| 09 | Attack contact, full-health healing and enemy deaths | Implementation present; acceptance pending | [ContactCues.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/ContactCues.luau>); [test_combat_contact.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_combat_contact.luau>) | 07 | Real contact/whiff/feint/heal/dissolve feedback. |
| 10 | A playable opening tutorial and clean prologue handoff | Implementation present; acceptance pending | [TutorialRules.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/TutorialRules.luau>); [test_opening_tutorial.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_opening_tutorial.luau>) | 08 | Fresh-profile play, avatar timing, actual training actions and first discovery. |
| 11 | Shen and Twin Sentinels presentation and fair entry | Partial delivery; production art + acceptance pending | [BossSkin.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/server/Services/BossSkin.luau>); [test_boss_presentation.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_boss_presentation.luau>) | 10 | Production Shen/Twins skins/animation mapping; real entry/phase/retry and target switching. |
| 12 | Baize and Titan creature presentation | Partial delivery; production art + acceptance pending | [BossBodies.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/BossBodies.luau>); [test_boss_presentation.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_boss_presentation.luau>) | 11 | Production Baize/Titan art/animations; real pillar/pounce/ankle/camera behavior. |
| 13 | Wu and Azure Wyrm presentation | Partial delivery; production art + acceptance pending | [LooksSovereigns.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/LooksSovereigns.luau>); [test_boss_presentation.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_boss_presentation.luau>) | 12 | Production Wu/Wyrm art/animations; real teleport/flight/landing/defeat. |
| 14 | Player, NPC and normal-enemy visual identity | Partial delivery; production art + acceptance pending | [CastFigures.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/server/Services/CastFigures.luau>); [test_cast_visuals.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_cast_visuals.luau>) | 13 | Production player/NPC/enemy art and actual avatar rebinding/portraits. |
| 15 | Monastery environment and navigable discovery route | Partial delivery; minimap + acceptance pending | [MonasteryZones.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/MonasteryZones.luau>); [test_monastery_discovery.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_monastery_discovery.luau>) | 14 | Actual walkthrough/collectibles/terrain plus minimap route layer (still absent). |
| 16 | Sanctuary framing, terrace and optional routes | Implementation present; acceptance pending | [SanctuaryRoutes.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/SanctuaryRoutes.luau>); [test_campaign_build.py](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_campaign_build.py>) | 15 | Real shrine/terrace/cache/ladder and natural-camera reveals; numeric model is insufficient. |
| 17 | Build the Bamboo Pass region | Partial delivery; production art + acceptance pending | [BambooPassLayout.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/BambooPassLayout.luau>); [test_campaign_regions.py](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_campaign_regions.py>) | 16 | Bamboo production kit and real route/tablet/altar/mobility checks. |
| 18 | Build the Ash Colosseum campaign region | Partial delivery; production art + acceptance pending | [AshColosseumLayout.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/AshColosseumLayout.luau>); [test_campaign_regions.py](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_campaign_regions.py>) | 17 | Colosseum production kit and real story/PvP access and Shen clearance. |
| 19 | Build Sanctuary Depths and the Sunken Crypt | Partial delivery; production art + acceptance pending | [SunkenCryptLayout.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/SunkenCryptLayout.luau>); [test_campaign_regions.py](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_campaign_regions.py>) | 18 | Crypt production kit, real descent/pit/return and Titan camera checks. |
| 20 | Build Celestial Pagoda and its lore route | Partial delivery; production art + acceptance pending | [CelestialPagodaLayout.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/CelestialPagodaLayout.luau>); [test_campaign_regions.py](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_campaign_regions.py>) | 19 | Pagoda production kit, actual rafters/elevation/tablets and Wu clearance. |
| 21 | Build Sky Citadel and the final approach | Partial delivery; production art + acceptance pending | [SkyCitadelLayout.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/SkyCitadelLayout.luau>); [test_campaign_regions.py](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_campaign_regions.py>) | 20 | Citadel production kit, real summit catches/Wyrm clearance/return. |
| 22 | A real six-sovereign ending and postgame handoff | Implementation present; acceptance pending | [EndingRules.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/shared/EndingRules.luau>); [test_progression_runtime.py](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_progression_runtime.py>) | 21 | Real ending presentation/interruption/rejoin; six earned victories still required. |
| 23 | Single-player campaign integration and remaining fixes | Local integration present; earned acceptance pending | [test_campaign_ledger.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_campaign_ledger.luau>); [test_campaign_regions.py](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_campaign_regions.py>) | 22 | Earned full six-boss campaign, collectibles/travel and ending; seeded ledger is insufficient. |
| 24 | Multiplayer and persistence integration | Mock integration present; real/live acceptance pending | [ColosseumService.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/server/Services/ColosseumService.luau>); [test_backend.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_backend.luau>) | 23 | Real 2-duelist + spectator sessions and isolated live persistence/failure recovery. |
| 25 | Device layouts, controls and accessibility | Emulation present; hardware acceptance pending | [DeviceLayout.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/client/Controllers/DeviceLayout.luau>); [test_device_layout.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_device_layout.luau>) | 24 | Actual captures, phone/tablet/controller hardware and comfort/settings use. |
| 26 | Performance, audio listening and final coverage audit | Offline checks present; measurement/listening/audit pending | [SpatialAudio.luau](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/client/Controllers/SpatialAudio.luau>); [test_audiovisual.py](</Users/digonto/Documents/ChatGPT/Roblox game 2/tools/test_audiovisual.py>) | 01, 25, 26 | Measured engine/device performance, real listening/music and complete evidence closure. |

## All 44 findings have work owners

Prompt 26 audits every row; it is not the sole implementation owner of any finding. A many-owner finding stays open until its necessary work and acceptance all pass. Prior report observations are not automatically current failures after code changes.

| Finding | Original problem | Current audit baseline | Follow-up owners |
|---|---|---|---|
| #1 (P1) | Later checkpoints did not produce later respawns | Implemented — acceptance pending | 02, 22 |
| #2 (P1) | Boss arenas lose most of their readable image | Implemented — acceptance pending | 09, 25 |
| #3 (P1) | The bridge fight is obstructed by its geometry | Implemented — acceptance pending | 14 |
| #4 (P1) | Desecrated Cloister altar needs physical and camera clearance | Implemented — acceptance pending | 04, 14 |
| #5 (P1) | The taught interaction button differs from the altar button | Implemented — acceptance pending | 03, 24 |
| #6 (P1) | E is also a spell, causing interaction ambiguity | Implemented — acceptance pending | 03, 24 |
| #7 (P1) | Combat sounds repeatedly throw cleanup exceptions | Implemented — acceptance pending | 09, 25 |
| #8 (P1) | Owned remembrance tokens are checked as booleans in the UI | Implemented — acceptance pending | 06, 22 |
| #9 (P1) | Transmutation content has not caught up with the campaign roster | Implemented — acceptance pending | 06, 22 |
| #10 (P1) | The promised ending needs a playable conclusion | Implemented — acceptance pending | 21, 22 |
| #11 (P2) | Introduce mechanics through a safe first encounter | Implemented — acceptance pending | 08 |
| #12 (P2) | Explain the changing health ceiling and Blood Rally | Implemented — acceptance pending | 03, 08, 24 |
| #13 (P2) | Perilous counter instructions need concrete input teaching | Implemented — acceptance pending | 08, 11, 24 |
| #14 (P2) | Make attack range and missed contact understandable | Implemented — acceptance pending | 07 |
| #15 (P2) | Make the first combat encounter readable before using multiple enemies | Implemented — acceptance pending | 08 |
| #16 (P2) | Boss entry needs a fair, observable handoff | Implemented — acceptance pending | 10, 11, 12, 22 |
| #17 (P2) | Give the Twins distinct, persistent identification | Implemented — acceptance pending | 03, 10 |
| #18 (P2) | Improve death and retry feedback | Implemented — acceptance pending | 02, 03, 22 |
| #19 (P2) | Clarify the stakes of carried currency | Implemented — acceptance pending | 02, 08, 22 |
| #20 (P3) | Decide whether healing at full health should consume a charge | Implemented — acceptance pending | 07 |
| #21 (P3) | Replace crude enemy death breakup with authored feedback | Implemented — acceptance pending | 07, 25 |
| #22 (P2) | Complete the environments beyond the Monastery | Blocked — production art + acceptance | 16, 17, 18, 19, 20, 22 |
| #23 (P2) | Boss models need to fulfill the encounter premise | Blocked — production art + acceptance | 10, 11, 12, 22, 25 |
| #24 (P2) | Player and NPC presentation is far behind the hero environment | Blocked — production art + acceptance | 13, 25 |
| #25 (P2) | Give the Monastery more authored spatial variety | Implemented — acceptance pending | 14, 25 |
| #26 (P2) | Close or develop the walkable empty exterior | Implemented — acceptance pending | 14 |
| #27 (P2) | Audit traversal against level boundaries | Implemented — acceptance pending | 14, 15, 16, 17, 18, 19, 20, 22 |
| #28 (P2) | Show navigable routes, including portal legs | Implemented — acceptance pending | 14, 15, 16, 17, 18, 19, 20, 21, 22 |
| #29 (P2) | Correct the Sanctuary destination wording | Implemented — acceptance pending | 14 |
| #30 (P2) | Make portal arrival and the nearby checkpoint obvious | Implemented — acceptance pending | 14 |
| #31 (P2) | Keep the shrine's large-scale spectacle, refine player-scale views | Implemented — acceptance pending | 15, 25 |
| #32 (P3) | Establish a consistent architecture/material vocabulary | Blocked — production art + acceptance | 14, 15, 16, 17, 18, 19, 20, 25 |
| #33 (P1) | Controls card overlaps the combat action bar | Implemented — acceptance pending | 03, 24 |
| #34 (P2) | Remove duplicate default and custom combat UI | Implemented — acceptance pending | 03, 24 |
| #35 (P2) | Improve the HUD's information hierarchy and small text | Implemented — acceptance pending | 03, 24 |
| #36 (P2) | Keep effects from competing with combat warnings | Implemented — acceptance pending | 03, 09, 24, 25 |
| #37 (P2) | Expand and synchronize the actual control reference | Implemented — acceptance pending | 03, 24 |
| #38 (P2) | Make resting and summoning Lin separate, understandable choices | Implemented — acceptance pending | 04 |
| #39 (P2) | Give dialogue a clear subject and consistent modal treatment | Implemented — acceptance pending | 04, 24 |
| #40 (P2) | Preview the concrete result of leveling | Implemented — acceptance pending | 04, 24 |
| #41 (P2) | Add useful spell and weapon descriptions | Implemented — acceptance pending | 05, 24 |
| #42 (P2) | Give Codex an informative empty state and progress | Implemented — acceptance pending | 05, 21, 24 |
| #43 (P3) | Clean up the initial prologue handoff | Implemented — acceptance pending | 08, 24 |
| #44 (P2) | Make discoveries and story progress part of the walked route | Implemented — acceptance pending | 08, 14, 16, 19, 22 |

The prepared prompt mapping covers all original batches and findings. It does **not** certify that future work, production assets or live acceptance have happened. Final closure must link actual evidence and preserve exact open dependencies.

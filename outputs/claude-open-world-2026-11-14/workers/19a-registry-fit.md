# 19a registry fit and old-builder reachability (read-only)

Supersedes: nothing. No 19* or registry-fit file existed in workers/ when searched on 2026-11-15.
Linked from LEDGER.md: no. This worker edits no other file, so the coordinator must add the LEDGER entry.
Why new: first audit of registered kit IDs against the overworld slots, and of retired builder reachability for the "not mapped and not reachable" ruling.
Prompt: Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Request: one read-only pass for registered-asset fit to overworld kit slots and for old-builder reachability. Verifies that every ID cited appears in a registry file at the line given.

## Task 1: registered-asset fit

Slot names: src/shared/SliceDressing.luau Pieces (16 pieces, lines 40-93), src/shared/BiomeDressing.luau kit() entries (91 total, lines 50-132+).
Counts: Bellwood slice 16 pieces. BiomeDressing by prefix: Mtn 20, Snow 18, Basin 16, Ravine 12, Cave 5, Sandstone 4, Dry 3, Red 2, Desert 2, Salt 2, Summit 2, Agave 1, Bronze 1, Dead 1, Frost 1, Pale 1.

| Asset (registry) | ID | Registry file:line | Kind | Best biome | Slot it could stand in for |
|---|---|---|---|---|---|
| AsuraLivingBamboo (mesh 1 of 5) | rbxassetid://81752398968484 | assets/LIVING_BAMBOO_UPLOADED.json:6, :17 | mesh | Bellwood | SliceDressing Understory_Shrub / Fern_Clump / Grass_Clump |
| AsuraBambooGateArt | rbxassetid://134797493263468 | assets/BAMBOO_GATE_ART.json:5 | mesh | Bellwood | SliceDressing Bell_Timber_Gate |
| AsuraBambooFrostSupport | rbxassetid://88640589607019 | assets/BAMBOO_FROST_SUPPORT_UPLOADED.json:14 | mesh | Frostmere | BiomeDressing Snow_Windbreak, Snow_Refuge_Hut |
| AsuraBambooFrostSteps | rbxassetid://77301153602166 | assets/BAMBOO_FROST_STEPS_UPLOADED.json:6 | mesh | Frostmere (2nd: Ashen Stair) | Mtn_Stair_Run / Snow stair |
| AsuraBambooBreakage | color map rbxassetid://117853702698728 (mesh ID not read) | assets/BAMBOO_BREAKAGE_UPLOADED.json:28 | mesh | Bellwood | dead/broken culm dressing (no exact slot) |
| HanGateHD Frame__Stone | rbxassetid://83497205981403 | assets/HAN_KITS_UPLOADED.json:27 | mesh | Ashen Stair / Saltreach | Mtn_Pass_Gate, Basin_Canyon_Gate |
| HanGateHD Frame__Bronze | rbxassetid://92992113590920 | assets/HAN_KITS_UPLOADED.json:11 | mesh | Bellwood | Bell_Timber_Gate |
| AsuraGuardianLion (GuardianCarving) | rbxassetid://105991522625229 | assets/GUARDIAN_LION_UPLOADED.json:9 | mesh | Saltreach | Basin_Gate_Statue |
| AsuraStone | rbxassetid://106842288070597 | assets/PHASE5_UPLOADED.json:74 | mesh | Saltreach | Basin_Obelisk, Basin_Boulder_B |
| AsuraBrassLantern (Spiral.001) | rbxassetid://105652153407631 | assets/PHASE5_UPLOADED.json:112 | mesh | Bellwood | Bell_Lantern_Post |
| AsuraFirePit | rbxassetid://108335955316266 | assets/PHASE5_UPLOADED.json:64 | mesh | Frostmere | Snow_Refuge_Hut hearth; Cave_Brazier |

Not usable as IDs (no registry ID found): AsuraBambooKit, AsuraReliquaryKit, AsuraFoundryKit. FOUNDRY_KIT_UPLOADED.json:2 names the library only, and no file under assets/*.json or assets/*.md mentions AsuraReliquaryKit or AsuraBambooKit. Their IDs must come from a new upload or the coordinator.

Insert pattern (runtime, clone-only):
- Bamboo: src/server/Services/RegionDecor.luau:79-83 FindFirstChild("AsuraBambooKit") then Clone.
- Han: RegionDecor.luau:91-108 Decor.han clones ServerStorage[kit][piece].
- Assets: RegionDecor.luau:113-122 Decor.nature clones ServerStorage.AsuraAssets.
- Slice: SliceDressingService.luau:12 and :123 (ServerStorage/SliceKit/<Piece>, pcall-guarded, falls back to placeholders).

Lobby: SanctuaryKit.luau:49-59 clones from ServerStorage AsuraLobbyKit, AsuraSanctuaryVista, AsuraSanctuaryDetail, and AsuraGuardianLion*. SanctuaryApproach.luau:34 clones AsuraReliquaryKit. Lobby instances must not be moved, so every new use must clone. Not verified: whether SanctuaryApproach calls Decor.han.

## Task 2: old-builder reachability

Project map: default.project.json lines are the key lines; each entry spans 3 lines.

| Module | Mapped (line) | Required by | Live path? | Verdict |
|---|---|---|---|---|
| MonasteryService | 515 | none (Bootstrap.server.luau:378 is a comment only) | no | unreachable, mapped |
| CampaignWorld | 521 | none (RouteGates.luau:107 is a comment) | no | unreachable, mapped |
| CampaignTerrain | 524 | BossArenas.luau:13 (top-level require, unguarded; BossArenas required by WorldService.luau:21) | YES | REACHABLE: blocks removal |
| CampaignBounds | 539 | CampaignWorld only | no | unreachable |
| BambooDressing | 542 | CampaignWorld.luau:22 only | no | unreachable |
| BambooEcology | 761 | BambooDressing only | no | unreachable |
| BambooFoundry | 767 | BambooDressing.luau:14 only | no | unreachable |
| ColosseumDressing, CryptDressing, PagodaDressing, CitadelDressing | 545, 548, 551, 554 | CampaignWorld.luau:23-26 only | no | unreachable |
| MonasteryTerrain | 569 | MonasteryBounds, MonasteryGrounds only | no | unreachable |
| MonasteryGrounds, MonasteryAtmosphere, MonasteryDressing, MonasteryBounds | 566, 581, 584, 590 | MonasteryService only | no | unreachable |
| MonasteryRuins, MonasteryHalls, MonasteryLandmarks, MonasteryPockets, MonasterySecrets | 572, 575, 578, 593, 596 | MonasteryService and each other | no | unreachable |
| MonasteryFx, MonasterySurvey | 563, 587 | none found | no | orphan, unreachable |
| MonasteryKit | 560 | RegionDecor.luau:8 (live via BossArenas, LootWorld); SanctuaryKit.luau:12 (lobby) | YES | KEEP: shared, live |
| RegionDecor | 518 | BossArenas, LootWorld, SanctuaryApproach | YES | KEEP |

Guards: Overworld.Active guards exist (BossArenas.luau:95, LootWorld.luau:33, AIService.luau:936, ColosseumService.luau:191) but none wraps the old builder requires. The old builders are not required at all, so no guard is needed for them.

Blocker: CampaignTerrain is live via BossArenas. Remove or re-home BossArenas's require (or move the ground helper into Overworld) before deleting it.

Files deletable once unmapped (after the blocker is cleared): src/server/Services/MonasteryService.luau, MonasteryDressing, MonasteryBounds, MonasteryGrounds, MonasteryTerrain, MonasteryAtmosphere, MonasteryHalls, MonasteryLandmarks, MonasteryPockets, MonasterySecrets, MonasteryRuins, MonasteryFx, MonasterySurvey, CampaignWorld, CampaignBounds, BambooDressing, BambooEcology, BambooFoundry, ColosseumDressing, CryptDressing, PagodaDressing, CitadelDressing. Keep CampaignTerrain until BossArenas is changed, then delete it too.

Project entries to remove for "not mapped" (key lines, each 3 lines with its closing brace): 515 MonasteryService, 521 CampaignWorld, 524 CampaignTerrain (after BossArenas change), 539 CampaignBounds, 542 BambooDressing, 545 ColosseumDressing, 548 CryptDressing, 551 PagodaDressing, 554 CitadelDressing, 563 MonasteryFx, 566 MonasteryGrounds, 569 MonasteryTerrain, 572 MonasteryRuins, 575 MonasteryHalls, 578 MonasteryLandmarks, 581 MonasteryAtmosphere, 584 MonasteryDressing, 587 MonasterySurvey, 590 MonasteryBounds, 593 MonasteryPockets, 596 MonasterySecrets, 761 BambooEcology, 767 BambooFoundry. Keep 518 RegionDecor and 560 MonasteryKit. Shared data (MonasteryZones 335, MonasteryRidgeProfile 338, CampaignZones 368) was not analysed.

Not done: no edits, no git writes, no Studio work, no binary reads. Not checked: SanctuaryApproach Han calls; full require graph of src/shared.

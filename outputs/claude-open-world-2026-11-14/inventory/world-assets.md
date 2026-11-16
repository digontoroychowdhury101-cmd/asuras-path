# World and assets inventory (read-only)

Scope: current repo state. Paths exact. Items marked UNCERTAIN were not fully read (budget).

## 1. Bootstrap order (`src/server/Bootstrap.server.luau`)

Requires, in dependency order (lines 27-47): EnvironmentService, LagCompensation, ProfileStore, PersistenceService, CharacterService, AIService, SanctuaryService (33), MonasteryService (34), CampaignWorld (35), WorldService (36), ColosseumService, ShopService, MagicService, LootService, RouteGates, DialogueService, WagerService, PresentationService, WeaponEffects, TutorialService.

Start calls (lines ~362-385):
- `Environment.Apply()` (362): sets Workspace gravity, wind, Lighting props, `Workspace.Terrain.WaterColor` (EnvironmentService line 103).
- `Persistence.Start()` (366), `Characters.Start()` (367), `AI.Start()` (369).
- `Sanctuary.Start()` (371) then `Monastery.Start()` (373).
- `Campaign.Start()` (375). Comment: Bamboo Pass to Sky Citadel maps, before WorldService "like the Monastery".
- `WorldService.Start()` (377).
- `Magic.Start()`, `Loot.Start()`, `WeaponEffects.Start()` (380); `RouteGates.Start()` (381); `Colosseum.Start()` (382); `Dialogue.Start()`, `Tutorial.Start()` (383-384); `Wagering.Start(Colosseum)` (385).

Ordering constraint: Monastery.Start and Campaign.Start run before WorldService.Start, because MapFolders suppress greybox regions.

`CampaignTerrain` is not required by Bootstrap. It is required by `BossArenas.luau` (line 12). Other callers were not confirmed (UNCERTAIN).

## 2. World builders

**CampaignWorld** (`src/server/Services/CampaignWorld.luau`)
- Entry: `CampaignWorld.Start()` (line 87), `Destroy()` (106), local `build(layout)` (34).
- Creates `Workspace.<region.MapFolder>` (e.g. `Map_BambooPass`), with child Folders `Structure` and `Lanterns` (lines 40-54).
- Layouts come from `src/shared/CampaignZones.luau` lines 13-16: `load("BambooPassLayout")`, `AshColosseumLayout`, `SunkenCryptLayout`, `CelestialPagodaLayout`, `SkyCitadelLayout`. Zone type at line 18 (`X0/X1/Z0/Z1`, `Region`).
- `Bounds.Start(Campaign.Layouts)` at line 98.
- Driven by `WorldDefinitions.World.Regions` and `CampaignZones`.

**MonasteryService** (`src/server/Services/MonasteryService.luau`)
- Entry: `MonasteryService.Start()` (line 44). Must run before WorldService (header line 8).
- Creates `Workspace.Map_DesecratedMonastery` (lines 52-53, parented to Workspace at line 90).
- Layer `"Bounds"` (lines 85-87): `MonasteryBounds.Build(map)` and `Start()`.
- Other monastery modules exist (MonasteryTerrain, MonasteryGrounds, MonasteryHalls, MonasteryLandmarks, MonasteryPockets, MonasteryRuins, MonasterySecrets, MonasterySurvey, MonasteryDressing, MonasteryFx, MonasteryAtmosphere, MonasteryKit). Their contents were not read (UNCERTAIN).

**CampaignTerrain** (`src/server/Services/CampaignTerrain.luau`)
- Writes Workspace Terrain only, no Folder. Uses `FillBlock`, `FillBall`, `FillCylinder`, `ReplaceMaterial` (Region3 with `ExpandToGrid`).
- Key functions: `surfaceHeight` (43), `applyOverrides` (53), `convert(part, box, solids)` (87), `grassPatch` (150), `forestFloor` (155), `exposeFloor` (163), `carve` (174), `backdrop` (267), `pillars` (331), `pad` (368), `clear` (376).
- Tables: `Kinds` (16; Grass, Rock, Snow, Ash, Basalt), `Overrides` (21), `Tints` (26), `Backdrops` (224), `Pillars` (301), `Massifs` (313).
- `convert` sets attribute `AsuraTerrainProxy` on source parts.
- Coordinates come from per-layout boxes (`box.X/Y/Z/SX/SY/SZ/Yaw`), not hard-coded. Region bounds are below.

**CampaignBounds** (`src/server/Services/CampaignBounds.luau`)
- Fall-return catch volumes only. No geometry. `Bounds.returnFor(list, position)` (22), `Bounds.Start(list)` (52), `Stop()` (63), `HOLD = 0.6` (15).

**BossArenas** (`src/server/Services/BossArenas.luau`)
- `Arenas.build(root)` (45) creates Folder `BossArenas` under root. Per boss, a floor part named `<boss.Id>Floor`, sized from `boss.Arena` (52-56).
- `Arenas.seal(gateId, sealed)` (23), `Arenas.loot` (102). `FloorColor` (15).

**WorldService** (`src/server/Services/WorldService.luau`): 37 pattern hits, not read (UNCERTAIN).

### Region list (`src/shared/WorldDefinitions.luau`, `World.Regions` at line 235)

| Id | Name | Bounds Center | Bounds Size | MapFolder |
|---|---|---|---|---|
| Sanctuary | The Shrine of the Ascendant | (SANCTUARY_ORIGIN.X, Y+200, Z-250) | 600 x 800 x 920 | `Sanctuary` |
| DesecratedMonastery | Desecrated Monastery | (0, 40, -900) | 400 x 200 x 440 | `Map_DesecratedMonastery` |
| BambooPass | Bamboo Pass | (0, 40, -1400) | 400 x 200 x 560 | `Map_BambooPass` |
| AshColosseum | Ash Colosseum | (0, 40, -1900) | 360 x 200 x 440 | `Map_AshColosseum` |
| SanctuaryDepths | not captured | UNCERTAIN | UNCERTAIN | UNCERTAIN |
| CelestialPagoda | not captured | UNCERTAIN | UNCERTAIN | UNCERTAIN |
| SkyCitadel | not captured | UNCERTAIN | UNCERTAIN | UNCERTAIN |

- `RegionId` type at line 22 lists all seven. The last three are used in spawns at lines 518-523.
- Altars (lines 282-336): Altar_SanctuaryBonfire, Altar_MonasteryGate, Altar_DesecratedCloister, Altar_BambooShrine, Altar_BellTerrace, Altar_ColosseumAntechamber.
- Fog gate `Gate_AshColosseum` (line 629): trigger center (0, 10, -1905), size (30, 20, 14), boss GrandmasterShen.
- Boss arena for Grandmaster Shen (line 532): center (0, 20, -1960), size 120 x 60 x 130, in AshColosseum.
- Mob spawns include CorruptWanderingMonk, CursedSwordsman, HollowBellWarden, SparringPhantom.

Note: the active code has 7 regions. The design doc (section 6) describes 14 regions. See that section.

## 3. Lobby (SanctuaryService)

- File: `src/server/Services/SanctuaryService.luau`. Header (lines 4-5): builds every piece under `Workspace.Sanctuary` from the WorldDefinitions layout, using the kit `assets/models/AsuraLobbyKit.rbxmx` (built from `tools/blender/lobby_kit.py`, concept 2026-10-21).
- `ORIGIN` (line 49) = `LAYOUT.Origin` (plaza centre at flagstone level, WorldDefinitions line 165). Exact numeric value of `SANCTUARY_ORIGIN` was not captured (UNCERTAIN).
- Catch volume: `CATCH_LIMITS.FloorY = ORIGIN.Y - CATCH_DEPTH` (65).
- `Workspace:FindFirstChild(World.Regions.Sanctuary.MapFolder)` (363) reuses or creates `Sanctuary`. Parented to Workspace at line 388.
- Sub-builders include Cloisters, Horizon, Colossus, Kit, Terrace, Vista, Courtyard, Ascent, Approach, Duel court, Forge, Bonfire, Titan, Rails, Props, Leaves, Ecology, Frame, RingFinish, Dressing. Only Cloisters, Horizon and Colossus were seen in the grep.
- ServerStorage: no direct `ServerStorage.AsuraLobbyKit` reference was found in the grep hits. The clone point is UNCERTAIN (likely in SanctuaryKit or SanctuaryDressing).
- Terrain near the lobby: no `FillBlock` or Terrain writes in SanctuaryService. Terrain writes in other sanctuary files were not checked (UNCERTAIN).

## 4. Assets

### `assets/models/` (binary .rbxmx/.rbxm/.glb; sizes in bytes)
- Armor: AsuraArmor_AshenPilgrim.rbxmx 113,512; AsuraArmor_CinnabarGuard.rbxmx 113,514; AsuraArmor_IronOath.rbxmx 113,507
- Packs: AsuraAssets.rbxm 128,150; AsuraAssets_Phase5.rbxmx 4,134,490
- Bamboo: AsuraBambooBreakage.rbxmx 72,079; AsuraBambooFrostSteps.rbxmx 15,311; AsuraBambooFrostSupport.rbxmx 17,520; AsuraBambooKit.rbxmx 106,663; AsuraLivingBamboo.rbxmx 131,488
- Bosses: AsuraBoss_CorruptWanderingMonk 121,440; AsuraBoss_CursedSwordsman 129,469; AsuraBoss_GeneralZhao 153,223; AsuraBoss_GrandmasterShen_P1.rbxmx 546,442; AsuraBoss_GrandmasterShen_P2.rbxmx 555,161; AsuraBoss_HollowBellWarden 129,408; AsuraBoss_IronBull 311,315
- Kits and architecture: AsuraFoundryKit 10,224; AsuraHanKit 329,666; AsuraHanHD 627,206; AsuraLobbyKit 376,397; AsuraReliquaryKit 69,840; AsuraSanctuaryDetail 79,202; AsuraSanctuaryVista 135,058
- Media and statues: AsuraGithubMedia 10,365; AsuraGuardianLion 39,279; AsuraGuardianLionMirror 10,257; Asuraguardianlion.glb 2,187,788; Asurastonelantern.glb 1,712,476
- Other: `maps/` folder; `report.json` (875 bytes)

Environment-relevant: bamboo group (Kit, FrostSteps, FrostSupport, LivingBamboo, Breakage); sanctuary (LobbyKit, SanctuaryVista, SanctuaryDetail); architecture (ReliquaryKit, FoundryKit, HanKit/HanHD, UNCERTAIN on Han scope); statues and lanterns (GuardianLion, stonelantern .glb). Individual trees and rocks are not named in the model list. Tree statue is covered by `assets/FUSED_TREE_STATUE_UPLOADED.json` (name only).

### JSON registries in `assets/` (names only; contents not read unless noted)
- Lobby and sanctuary: LOBBY_KIT_UPLOADED, LOBBY_SKY_UPLOADED, SANCTUARY_VISTA_UPLOADED, SANCTUARY_DETAIL_UPLOADED, SANCTUARY_SKY_UPLOADED, FUSED_TREE_STATUE_UPLOADED
- Bamboo: BAMBOO_GATE_ART, BAMBOO_BREAKAGE_UPLOADED, LIVING_BAMBOO_UPLOADED, BAMBOO_FROST_STEPS_UPLOADED, BAMBOO_FROST_SUPPORT_UPLOADED
- Kits: FOUNDRY_KIT_UPLOADED, HAN_KITS_UPLOADED, GUARDIAN_LION_UPLOADED
- GitHub: GITHUB_CODE_SOURCES, GITHUB_MODELS, GITHUB_REUSE, GITHUB_RESEARCH, GITHUB_SUPERPOWERS, GITHUB_TERRAIN, GITHUB_TERRAIN_UPLOADED, GITHUB_UPLOADED
- Phase 5: PHASE5_SOURCES, PHASE5_IMPORT_QUEUE, PHASE5_UPLOADED
- Shen and bosses: `assets/opening_cast/AsuraBoss_*.uploaded.json`, `AsuraArmor_*.uploaded.json`, `GrandmasterShen_audio.uploaded.json`, plus `assets/opening_cast/{monk,swordsman,warden,bull}.json`
- Animations: `assets/animations/<name>/manifest.json` and `published.json` (general_zhao, jian, families, opening_cast/*)
- Index: `assets/ASSET_IDS.md`

### `default.project.json`
- Maps `Workspace` (line 5, `$className: Workspace`) and `src/*` modules (lines ~177-290; e.g. `src/shared/WorldDefinitions.luau` at line 206).
- No explicit `assets/models` mapping was seen in the first 40 hits. Full mapping not read (UNCERTAIN).

### Headlines
- `docs/GITHUB_REUSE.md` (26 Oct 2026): "Included in the game build"; "Roblox texture integration and prepared audio"; "Other repositories screened"; "Reproduce and verify"; "Campaign terrain".
- `assets/CREDITS.md`: not read (budget). UNCERTAIN.

## 5. Grandmaster Shen (`outputs/grandmaster-shen-2026-11-05/RESULTS.md`)

- Status: integrated in the game. Both skinned forms imported, uploaded and bound at `ServerStorage.AsuraAssets.AsuraBoss_GrandmasterShen_P1` and `_P2`. All 64 clips and 16 sound layers published. Single-client Studio fight ran both phases, the transition, defeat, death, reset and retry.
- Open: two-client test on the other computer, and device profiling.
- Game files new: `src/client/Controllers/ShenPresentation.luau`, `BossCloth.luau`, `src/shared/ShenPresentationData.luau`, `ClothSim.luau`, `ShenClothData.luau` (generated).
- Game files edited: BossAnimations, InterfaceController, AIService, BossAttackService, BossHazards, BossSkin, PbrAssets, BossAnimationRules, BossArmaments, BossAttackCatalog, BossRigs, BossRoster, LooksDuelists, WorldDefinitions, default.project.json.
- Tools: `bind_skin.py`, `extract_skin.py`, `export.py` (motion re-bake: `tools/animation/opening_cast/export.py shen <clip names>`).
- Placement today: region `AshColosseum`. Arena center (0, 20, -1960), size 120 x 60 x 130 (WorldDefinitions line 532). Fog gate `Gate_AshColosseum`, trigger center (0, 10, -1905), size 30 x 20 x 14 (line 629). Floor built by `BossArenas.build`.
- Dependencies: `ServerStorage.AsuraAssets` P1/P2 bindings; `assets/models/AsuraBoss_GrandmasterShen_P1.rbxmx` and `_P2.rbxmx`; `assets/opening_cast/AsuraBoss_GrandmasterShen_P1/P2.uploaded.json`; `assets/opening_cast/GrandmasterShen_audio.uploaded.json`; `assets/animations/opening_cast/shen/`; `places/AsurasPath.rbxlx`.
- Known issue (RESULTS): phase 2 red arena lighting leaves him very dark. Hair and face readability not judged.
- Attachments created by `bind_skin.py`: section not read (UNCERTAIN).

## 6. World design (`outputs/world-design/World-Design-Revision-02.md`, "Bellwater", read through line 129)

Status: a design concept, not an implemented map. It replaces an earlier seven-landmark concept. The sanctuary remains the social lobby, with an adjoining duel court.

1. Scale: 14 regions, 42 named exploration areas. 12 are above ground; 2 (Deepworks, First City) form one connected underground network.
2. Sea is west (Wreckers' Coast); snowy headwaters are north and northeast; the former inland lake is east.
3. Watersheds: rivers descend through Pine March and Thousand Steps; the surviving lake water and exposed bed feed Reed Country to the south.
4. Great Sluice (Weirlands) controls the western outlet. Its drainage runs through Old Ward and Bellwater Town to the coast.
5. High Ward sits on the central ridge above the outlet. Longfields is the gentler southern upland; Quarry Hills cuts the western foothills.
6. Bellwater Town holds the sanctuary as one defensible refuge. The world does not radiate from it through equal bridges.
7. Underground layering: Deepworks lies beneath the dam, quarry and city; First City lies beneath the former lakebed. They connect underground and are not separate destinations.
8. Surface loops: Longfields-Bellwater main road, Bellwater-Reed ferry plus Longfields walk, Old Ward-Quarry Hills via Convict Stair, Pine March-High Ward old road, High Ward-Weirlands dam crest road, Thousand Steps-White Pass (late), White Pass-High Ward freight lift (return).
9. Underground connections: Weirlands-Deepworks (Chain Towers), Quarry-Deepworks ore lift, Old Ward-Deepworks cistern gate, Salt Basin-First City at Dry Harbour, Deepworks-First City collapsed passage, First City-Bellwater well stair (very late).
10. Opening: Longfields then Bellwater Town (sanctuary, optional duels). Middle: Old Ward to High Ward, or quarry and forest to the upper city. Late: mountain and underground pieces of the seal history. Clearing every region is not required.
11. Returns (convict stair, ore lift, cistern, sanctuary well): each should land somewhere recognisable. The closed side of the well should be visible before it opens.
12. Optional areas: Beacon Fort, Shuttered Baths, quarry pursuit, forest fort. Each needs a different spatial idea, not a repeated catacomb.
13. PvP: the duel court has its own entrance and queue. No story path requires it.
14. Art: limestone, dark local brick, weathered cedar, copper. Avoid repeated cathedral silhouettes, symmetrical biome wedges, uniform wet surfaces, and a single luminous tree or statue as the world's symbol.
15. Gap with code: the active code has 7 regions (Sanctuary, DesecratedMonastery, BambooPass, AshColosseum, plus three UNCERTAIN). The design uses different names and 14 regions. Reconciliation is not in scope of this inventory.

## 7. Reference archive (`outputs/hero-grand-soul-review-2026-11-09/`), skim

Coverage: targeted grep only (headings, observed and unverified tags). Full reads of ENVIRONMENT_FIELD_LOG.md, ACTIVE_SESSION.md, MAP_COVERAGE.md, OPEN_WORLD_GAPS.md, SOURCE_COVERAGE.md and SESSION.md were not done (budget). ACTIVE_SESSION.md and MAP_COVERAGE.md did not appear in the grep output (UNCERTAIN whether they match). Images not viewed (budget).

1. (observed, E08) A curved-blade enemy chased the character down a wooded slope; health reached zero while passing toward stone arches. Crossing is unverified.
2. (observed, E02) Bright haze persisted over the goldland ridge walk; no precipitation or timed change observed.
3. (observed, E07) Pale motes against amber distance haze on the wooded switchback; no transition observed.
4. (observed, SESSION) First timed unobscured gameplay view at 2026-11-08T15:26:46Z. Not proof of active control.
5. (observed, SESSION R02) Save menu showed one visible slot. Slot capacity, overwrite rules and save durability are unknown.
6. (observed, OPEN_WORLD_GAPS) Hero shows server selection with name, region, occupancy and ping. An Asura equivalent is not established. Presentation difference only.
7. (observed, OPEN_WORLD_GAPS) Destination contrast: a bright cyan opening between dark rock masses and warm grass. Lighting preset not measured; estimate only.
8. (observed, OPEN_WORLD_GAPS) Compass and diamond quick slots seen in Hero. Asura already has compass, minimap and action-bar controllers. Comparison pending.
9. (method, FIELDWORK) An unobserved weather state is unknown, not absent. Screenshots cannot reveal exact Atmosphere or Lighting values. Light and colour values are estimates.
10. (method, SOURCE_COVERAGE/README) Hero is a reference; original Asura design decisions are kept separate from reference behaviour.

## 8. Uncertainties

- Region bounds and MapFolders for SanctuaryDepths, CelestialPagoda and SkyCitadel were not captured (UNCERTAIN). Their layouts (`CelestialPagodaLayout`, `SkyCitadelLayout`, `SunkenCryptLayout`) exist in CampaignZones.
- `SANCTUARY_ORIGIN` numeric value not captured.
- Lobby clone point from `ServerStorage.AsuraLobbyKit` not located.
- `WorldService.luau`, `MonasteryTerrain.luau` and other monastery and sanctuary dressing files: not read.
- Registry JSON contents: not read; described by name only.
- `assets/CREDITS.md`: not read.
- `default.project.json` `assets` mappings: incomplete check.
- Shen `Attachments` section and decisions list: not read.
- Reference archive: only grep coverage; images not viewed; ACTIVE_SESSION.md and MAP_COVERAGE.md not confirmed.
- World design: read through line 129 only. Anything after may add detail.

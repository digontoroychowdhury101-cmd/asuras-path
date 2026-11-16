# Repository coverage and source inventory

Scope: selected static reads and targeted searches, not an exhaustive semantic review. This inventory enumerates candidate files for continuing the whole-project audit. File presence is not implementation acceptance.

## Mapping and callers inspected

default.project.json maps Shared and Simulation under ReplicatedStorage/AsurasPath, server modules under ServerScriptService/AsurasPath/Services and client controllers under StarterPlayerScripts/AsurasPath. Bootstrap.server starts Environment, Sanctuary, Monastery, CampaignWorld and WorldService. CampaignWorld consumes CampaignZones layouts and regional dressing modules. WorldDefinitions calls BossRoster.apply to append campaign content.

The mapped environment service is src/server/Services/EnvironmentService.luau. Do not assume the similarly named src/server/EnvironmentService.luau is the mapped current implementation.

## Files read or searched directly

Full or partial reads: README.md, PROJECT_STATE.md, docs/BUILD.md, tools/toolchain.env, default.project.json, ENVIRONMENT_PROMPTS.md; WorldDefinitions, BossRoster, CampaignZones, EnvironmentProfiles, RegionLayout, MonasteryZones, BambooPassLayout, RouteGuide, RouteGates, InputMap, ProfileSchema, RPGProfile, ProgressionRules, NarrativeCatalog, ArsenalCatalog, ShopCatalog, CombatSettings; Bootstrap.server, Bootstrap.client, Services/WorldService, Services/CampaignWorld, Services/CampaignBounds, Services/AIService, Services/EnvironmentService; Controllers/EnvironmentController, Controllers/LandscapeBudget, Controllers/MinimapRoute, Controllers/SoundscapeController; outputs/world-design/World-Design-Revision-02.md; combat master audit README; visual production ART_DIRECTION and environment-art README. Long reads sometimes returned truncated output; only visible portions and targeted matches support this report.

Targeted searches: streaming contracts; clock/weather terms; proposed region names; world build order; source require/caller mappings; combat/VFX delayed callbacks and teardown entry points. No speculative leak diagnosis follows from those search hits.

## Current source inventory

### src/client

- Bootstrap.client.luau

### src/client/Controllers

- ActionBar.luau
- ActorPose.luau
- AltarAscension.luau
- ArenaAsh.luau
- ArmorView.luau
- ArsenalPanel.luau
- ArsenalTabs.luau
- BillboardFx.luau
- BillboardShapes.luau
- BlazingSunShow.luau
- BossAnimations.luau
- BossCinematics.luau
- BossCloth.luau
- BossEffects.luau
- BossHud.luau
- BossMusic.luau
- CameraClearance.luau
- CameraController.luau
- CelestialForms.luau
- CelestialPillar.luau
- CodexView.luau
- ColosseumController.luau
- CombatCallouts.luau
- CombatFeedback.luau
- CombatHud.luau
- CombatSurfaces.luau
- CombatVfx.luau
- ComfortSettings.luau
- ControlsCard.luau
- CoreGuiPolicy.luau
- CreatureMotion.luau
- DeviceLayout.luau
- DialogueController.luau
- DialogueView.luau
- DuoBars.luau
- EncounterHandoffController.luau
- EndingController.luau
- EnemyBars.luau
- EnemyDissolve.luau
- EnemyPlate.luau
- EnvironmentController.luau
- FighterAnimations.luau
- FireCanvas.luau
- FireStorm.luau
- FlameForms.luau
- FoliageWind.luau
- GameFeelController.luau
- HudKit.luau
- HudLayout.luau
- HudVisibility.luau
- IconShapes.luau
- ImpactFrame.luau
- InkFrames.luau
- InputController.luau
- InterfaceController.luau
- LandscapeBudget.luau
- MangaFx.luau
- MasteryEffects.luau
- MinimapRoute.luau
- MoveIcons.luau
- MovementController.luau
- MovementEffects.luau
- MovementMath.luau
- NovaInk.luau
- NovaScenery.luau
- ObjectiveController.luau
- PauseMenu.luau
- PlanetForms.luau
- PlateLayout.luau
- PlaybackScale.luau
- PortraitCamera.luau
- PrologueController.luau
- QiVfx.luau
- SakuraCompass.luau
- SakuraHud.luau
- SakuraKit.luau
- SakuraMinimap.luau
- SanguineCombat.luau
- SanguineController.luau
- SanguineDispatch.luau
- SanguineGeometry.luau
- SanguineGhost.luau
- SanguineMagic.luau
- SanguineRuntime.luau
- ShenPresentation.luau
- SkillAudio.luau
- SkillCinema.luau
- SkillFx.luau
- SkillKit.luau
- SkillShowcase.luau
- SkinWeaponFx.luau
- SolarForms.luau
- SoundscapeController.luau
- SpatialAudio.luau
- SpellController.luau
- SpellHud.luau
- SpellVfx.luau
- SunForms.luau
- SunShots.luau
- SupernovaShots.luau
- SupernovaShow.luau
- TargetPlate.luau
- TutorialController.luau
- UiKit.luau
- UiWindow.luau
- VitalsTags.luau
- VoidStage.luau
- WagerController.luau
- WaypointMarker.luau
- WeaponTrails.luau
- WorldStateController.luau

### src/infrastructure

- IntentProtocol.luau

### src/loading

- Loading.client.luau

### src/server

- ArmorSkin.luau
- Bootstrap.server.luau
- CharacterService.luau
- EnemyAppearance.luau
- EnvironmentService.luau
- FighterAppearance.luau
- ForgeService.luau
- LagCompensation.luau
- MatchJournal.luau
- PersistenceService.luau
- ProfileBridge.luau
- ProfileStore.luau
- RecoveryRules.luau
- ShopService.luau

### src/server/Services

- AIService.luau
- ArenaLighting.luau
- BambooDressing.luau
- BambooEcology.luau
- BambooFoundry.luau
- BambooGateArt.luau
- BossAppearance.luau
- BossArenas.luau
- BossAttackService.luau
- BossDuo.luau
- BossHazards.luau
- BossMotion.luau
- BossSkin.luau
- BossTactics.luau
- CampaignBounds.luau
- CampaignTerrain.luau
- CampaignWorld.luau
- CastFigures.luau
- CitadelDressing.luau
- ColosseumDressing.luau
- ColosseumService.luau
- CostumeKit.luau
- CryptDressing.luau
- DialogueActions.luau
- DialogueService.luau
- EncounterHandoff.luau
- EnvironmentService.luau
- LootService.luau
- LootWorld.luau
- MagicService.luau
- MonasteryAtmosphere.luau
- MonasteryBounds.luau
- MonasteryDressing.luau
- MonasteryFx.luau
- MonasteryGrounds.luau
- MonasteryHalls.luau
- MonasteryKit.luau
- MonasteryLandmarks.luau
- MonasteryPockets.luau
- MonasteryRuins.luau
- MonasterySecrets.luau
- MonasteryService.luau
- MonasterySurvey.luau
- MonasteryTerrain.luau
- NarrativeWorld.luau
- PagodaDressing.luau
- PbrAssets.luau
- PresentationAudit.luau
- PresentationDressing.luau
- PresentationService.luau
- RegionDecor.luau
- RouteGates.luau
- SanctuaryApproach.luau
- SanctuaryAscent.luau
- SanctuaryBonfire.luau
- SanctuaryCloisters.luau
- SanctuaryColossus.luau
- SanctuaryCourtyard.luau
- SanctuaryDressing.luau
- SanctuaryDuelCourt.luau
- SanctuaryEcology.luau
- SanctuaryForge.luau
- SanctuaryFrame.luau
- SanctuaryHorizon.luau
- SanctuaryKit.luau
- SanctuaryLeaves.luau
- SanctuaryProps.luau
- SanctuaryRails.luau
- SanctuaryRingFinish.luau
- SanctuaryService.luau
- SanctuaryTerrace.luau
- SanctuaryTitan.luau
- SanctuaryVista.luau
- SpellEffects.luau
- SpellGeometry.luau
- TutorialService.luau
- WagerLedger.luau
- WagerService.luau
- WagerWorld.luau
- WeaponEffects.luau
- WeaponModels.luau
- WorldService.luau

### src/shared

- AnimationCatalog.luau
- AnimationFamilyIds.luau
- ArenaLightPlan.luau
- ArenaRules.luau
- ArmorRules.luau
- ArsenalCatalog.luau
- ArsenalFacts.luau
- ArsenalProtocol.luau
- AshColosseumLayout.luau
- BambooPassLayout.luau
- BossAnimationRules.luau
- BossArmaments.luau
- BossAttackCatalog.luau
- BossBodies.luau
- BossEncounterRules.luau
- BossHandoff.luau
- BossRigs.luau
- BossRoster.luau
- BossTypes.luau
- CampaignZones.luau
- CelestialPagodaLayout.luau
- ClothSim.luau
- CombatSettings.luau
- Config.luau
- ConfigValidator.luau
- ContactCues.luau
- CostumeSchema.luau
- DialogueRules.luau
- EffectEasing.luau
- EffectsPreference.luau
- EndingCredits.luau
- EndingRules.luau
- EnvironmentProfiles.luau
- ForgeQuote.luau
- InputMap.luau
- LevelPreview.luau
- LooksBeasts.luau
- LooksCast.luau
- LooksDuelists.luau
- LooksSovereigns.luau
- MobSpacing.luau
- MonasteryRidgeProfile.luau
- MonasteryZones.luau
- NarrativeCatalog.luau
- Objectives.luau
- PresentationAssets.luau
- ProfileSchema.luau
- ProgressionRules.luau
- RegionLayout.luau
- RouteGates.luau
- RouteGuide.luau
- RPGInventory.luau
- RPGProfile.luau
- SanctuaryRoutes.luau
- ShenClothData.luau
- ShenPresentationData.luau
- ShopCatalog.luau
- SkyCitadelLayout.luau
- StrikeTrajectories.luau
- StrikeTrajectoryData.luau
- SunkenCryptLayout.luau
- TutorialRules.luau
- WorldDefinitions.luau

### src/simulation

- AnimationTiming.luau
- ArsenalInventory.luau
- CombatRules.luau
- FootStep.luau
- InputBuffer.luau
- LocalPrediction.luau
- MatchmakingRules.luau
- MoveSchema.luau
- SpellRules.luau
- SpellSchema.luau
- StrikeGeometry.luau
- Tempo.luau
- WeaponExpansion.luau
- WeaponSchema.luau

## Asset and research folder inventory

These folders/files were enumerated; models, textures and prior recordings were not all opened or visually validated.

- assets/animations: 374 files
- assets/build: 171 files
- assets/concept-art: 10 files
- assets/github: 108 files
- assets/models: 34 files
- assets/opening_cast: 14 files
- assets/source: 116 files

- outputs/combat-recovery-2026-11-02
- outputs/combat-recovery-prompts-2026-11-02
- outputs/environment-art-2026-10-29
- outputs/environment-art-2026-10-30
- outputs/environment-art-2026-10-31
- outputs/environment-art-2026-11-05
- outputs/foundry-kit-2026-11-05
- outputs/grandmaster-shen-2026-11-05
- outputs/jian-combat-2026-11-01
- outputs/lobby-art-pass-2026-10-22
- outputs/lobby-concept-2026-10-21
- outputs/lobby-finish-2026-10-23
- outputs/lobby-monumental-2026-10-23
- outputs/lobby-rebuild-2026-10-21
- outputs/lobby-references-2026-10-22
- outputs/mac-followup-2026-11-02
- outputs/master-completion-audit-2026-11-06
- outputs/mugen-combat-review-2026-11-09
- outputs/playthrough-2026-10-20
- outputs/post-combat-mac-prompts-2026-11-02
- outputs/terrain-reuse-2026-10-26
- outputs/vfx-integration-2026-10-21
- outputs/visual-audit-2026-11-05
- outputs/world-design

## Validation

Documentation only. No tests, Studio runs, new multiplayer cases or device profiles were run. Preserve saved places; future verification follows docs/BUILD.md and bash tools/verify_all.sh with temporary build output. No staging or commits performed.

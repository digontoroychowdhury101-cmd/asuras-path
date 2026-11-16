# Spec: Asura's Path replacement overworld

Requirements source (authoritative, not duplicated here): `outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md` (the brief; section numbers below are its sections).
Volatile file/interface map: `outputs/claude-open-world-2026-11-14/inventory/*.md` (kept separate on purpose; re-verify before editing).
Geography/route/streaming plan (C1): `outputs/claude-open-world-2026-11-14/GEOGRAPHY_PLAN.md`.
Tickets: `.scratch/asuras-open-world/issues/`. Ledger: `outputs/claude-open-world-2026-11-14/LEDGER.md`.
Procedure: mattpocock `to-spec` template, local file instead of tracker (brief §2 override). No commits.

## Problem statement
The shrine gateway (`Altar_MonasteryGate`) leads to a short linear campaign corridor (Monastery → Bamboo Pass → Ash Colosseum → Pagoda/Citadel, X ±450, Z -680..-2980) built at runtime by MonasteryService/CampaignWorld/CampaignTerrain. Players want one connected, expansive overworld with five distinct biomes, a truthful M-map, a bearing compass, authored weather/time, and one Souls-style barrier into Grandmaster Shen's domain — without losing the protected lobby, existing mechanics or any player progress.

## Solution
Add one canonical, pure-data overworld definition that every consumer reads (terrain builder, region bounds, altars, route graph, POIs, map, compass waypoints, environment, encounters, boss barrier). Build the overworld in a clean coordinate frame away from the old corridor (X -10000..-1600, Z -9200..-800) under one owned root `Workspace.Map_Overworld` plus an ownership manifest for Terrain. Keep every persistent ID string; relocate kept altars/caches/gate/minibosses into the new world; map retired IDs deliberately. Repoint the gateway by moving the `Altar_MonasteryGate` placement (destination ID unchanged). Retire the old builders from Bootstrap after validation.

## User stories
1. As a lobby player, the Shrine of the Ascendant looks and behaves exactly as before (forge/Gao, bonfire, duels, colossus terrace, horizon), with no weather or world-map UI spill.
2. As a player, walking through the shrine portal lands me at the overworld gateway glade; I can rest there and travel back to the lobby bonfire, and a return gate at the glade takes me home.
3. As an explorer, I can walk/sprint/jump/glide from the gateway through forest foothills, jungle ravine and bamboo groves, then branch into the golden ravine and arid basin, or climb to the snowy headwaters and the mountain, without fast travel.
4. Each biome shows a distinct long-distance landmark, at least three subareas, a main route, an alternate route, an optional discovery branch and a return shortcut where topology allows.
5. I can see the summit from earlier regions.
6. Pressing M (or the gamepad/touch equivalent) opens a large map that matches the real terrain, shows my position/heading, regions, discovered checkpoints, landmarks and known destinations, supports zoom/pan/legend and one placed waypoint; M or Escape closes it and restores input/camera.
7. The top-centre compass shows N/E/S/W, intercardinals, 15° ticks with numeric labels and a precise bearing (N=0 at world -Z, E=90 at +X), wrapping smoothly 359→0.
8. Discoveries I make persist and are never duplicated; hidden rewards are not revealed automatically.
9. As a returning player with an old save, I spawn safely, keep all altars/bosses/caches/route flags/lore/essence/bloodstain essence, and get no duplicate rewards.
10. As a fresh player, I can earn every retained core mechanic and reach every delivered region and the single boss through normal play.
11. I can rest, die, recover my bloodstain, forge, equip, cast two spells, use the gourd and fast travel in the overworld exactly as before.
12. Ordinary enemies stand on deliberate fighting ground and leash before reaching checkpoints or the lobby.
13. At the summit temple I see the barrier before committing, "Traverse the Mist", fight Shen (both phases, real animations/sounds), and on death retry with a reasonable runback; on victory I exit reliably and the barrier no longer traps anyone.
14. Weather changes are authored per biome (forest rain/gusts, snow calm/gusty/squall, mountain exposure, desert dust/sandstorm, ravine golden/cool state), stop under roofs and caves, and never leak into the lobby, boss domain or a respawn.
15. Trees, bamboo, precipitation, flags and ambience follow one wind.
16. Each biome has original ambience beds and detail layers that crossfade without stacking.
17. The world stays playable on low settings with intentional reduced visuals.

## Implementation decisions
- Canonical data: new pure shared module (working name `Overworld`) applied into `WorldDefinitions` via an `apply(world)` hook (same pattern as `BossRoster.apply`). It owns: world frame, regions (bounds + elevation band + biome), height/biome functions or control data, roads, rivers, altars, landmarks, POIs (with level: surface/underground and hidden flag), route graph (nodes/edges with kind main/alternate/optional/shortcut and lock conditions), encounter sites, the barrier, reserved future arena sites. No second topology anywhere.
- Region IDs: new overworld region IDs (`Forest`, `GoldenRavine`, `AridBasin`, `Snowfields`, `MountainAscent`); `Sanctuary` unchanged; Shen's domain keeps region ID `AshColosseum` (keeps `Combat:AshColosseum` presentation and boss mapping). Old region IDs (`DesecratedMonastery`, `BambooPass`, `SanctuaryDepths`, `CelestialPagoda`, `SkyCitadel`) retired from the active world; they are not persisted keys.
- Persistent IDs kept and relocated: `Altar_MonasteryGate` (gateway glade), `Altar_BellTerrace`, `Altar_BambooShrine`, `Altar_DesecratedCloister`, `Altar_ColosseumAntechamber` (summit antechamber), `Gate_AshColosseum`, `GrandmasterShen`, `BambooRidge`, caches `WaterfallAlcove`/`PagodaRafters`/`SealedMausoleum`/`FoundersKiln`, miniboss flag `HollowBellWarden`, all 9 lore IDs. Lobby IDs untouched. New altar IDs only for new places (ravine overlook, basin cistern, snow refuge, mountain refuge). Full table: GEOGRAPHY_PLAN.md §Preservation.
- Retired altar IDs (`Altar_SanctuaryDepths`, `Altar_CelestialPagoda`, `Altar_SkyCitadel`) stay in saved `unlockedAltars`; an explicit retired→safe-spawn map sends an `activeAltar` pointing at one to `Altar_MonasteryGate` (not the silent bonfire repair).
- Inactive bosses (VenerableBaize, SlumberingTitan, SovereignWu, TwinSentinels, AzureWyrm) keep their definitions for ID/remembrance/ending lookups but register no region, arena, fog gate or spawn. Saved defeats and remembrance tokens are untouched. Reserved arena sites exist only as data.
- Stranded bloodstains (coordinates outside every active region) relocate to the mapped safe spawn on load, essence intact.
- Map discovery persistence: optional `souls.world.discoveries` map (id → true, capped like other world maps), added without changing schema version 4 conventions (migration copies it; absent = empty). Waypoint is session-local.
- Fresh-profile progression: boss-only rewards for inactive bosses are deferred future content except `WindSlash` and `Thunderfall`, which move onto two new overworld discovery caches; `IronOath` and `HeavenPiercingGuandao` remain explicitly deferred with Twin Sentinels. Objectives' boss/route lists are rewritten for the new route ending at `Boss:GrandmasterShen`. Endings that need six sovereigns are deferred (C1 ruling requested).
- Gateway: SanctuaryService unchanged except what streaming needs; `LAYOUT.PortalDestination` stays `Altar_MonasteryGate`; only that altar's placement moves. A return gate at the glade teleports to the bonfire through the same Characters path.
- Teleport: `CharacterService.Teleport` requests stream-around for the destination before pivot (needed by the streaming decision).
- Streaming: enabled deliberately (contract change in `default.project.json`, `Config`, `ConfigValidator`), Atomic world models, Persistent far-landmark silhouettes and lobby top-level models, PauseOutsideLoadedArea integrity, client lookups that assume presence made tag/stream-safe. Fallback if validation fails: streaming off with LandscapeBudget distance hiding (decision and evidence recorded).
- World root `Workspace.Map_Overworld` (matches LandscapeBudget's `^Map_` gate). Terrain written only inside an ownership manifest of boxes; never clear all Terrain/Workspace.
- Map rendering: client renders the map raster from the same canonical height/biome data (EditableImage if available, else frame layers), vector overlays for roads/rivers/POIs/route; map transform world XZ → map UV defined once in the canonical module; floor/level filter for underground markers.
- Input: new `Map` command in `InputMap` (keyboard M, a pad button, touch caption); handled in the existing HUD with the established focus/menu guards; no `Enum.KeyCode.M` literals. The persistent radar is removed from gameplay; Respite/Controls buttons keep a home.
- Environment composition: one owner per layer. Server owns world clock and per-region weather state (attributes); client `EnvironmentController` is the only Lighting tween owner and composes biome × time × weather × shelter × boss × comfort; `FoliageWind` stays the only `GlobalWind` writer and gains a weather wind target; precipitation/dust particles and their sounds are owned by one client weather module with explicit cleanup on region/shelter/respawn/stream/encounter changes.
- Audio: reuse SpatialAudio/Soundscape; new keys in PresentationAssets; ElevenLabs batches small, recorded; local-file fallback if upload blocked; never invent IDs.
- Art: Blender/Hyper3D/Studio generation per brief §14; sub-meshes under ~18-20k tris, baked PBR, SurfaceAppearance; one kit passes in-engine review before variants.

## Testing decisions (pre-approved seams, brief §2)
| Seam | Test | Catches | Misses |
|---|---|---|---|
| Canonical data | pure Luau test: every altar/POI/gate inside its region, route graph connected, every kept ID present, retired map total | geography/ID regressions | visual truth |
| Shrine entry/return | Studio run: portal → glade → return gate/travel → bonfire; lobby capture diff | gateway regression | multiplayer |
| WorldService rest/death/recovery, boss entry/retry | existing test_boss_* + Studio fight loop at new placement | encounter regressions | combat feel |
| Profile load/migration/reward | extend test_profile_integrity / ProfileStore fixtures with old saves (retired activeAltar, stranded stain, caches, routeFlags) | data loss, duplicates | DataStore outages |
| InputMap → map/compass | test_input_map (Map binding), pure transform test (world↔map, bearing N/E/S/W/359→0), Studio surveyed-point check | binding/transform errors | readability |
| Environment/audio lifecycle | test_audiovisual extension: compose priority, cleanup counts after region/shelter/respawn/reset | leaks, tween fights | visual quality |
Final: `bash tools/verify_all.sh` (temp build), Studio passes on the real place after identity check, captures, measured traversal.

## Out of scope
Additional active bosses or barriers; publishing; new survival/cold grind; global movement changes; replacing combat/network/persistence stacks; fourteen-region atlas of Revision 02.

## Further notes
Ending/narrative completion for six sovereigns is deferred pending Fable ruling. Two-client and device checks will be reported unperformed if unavailable.

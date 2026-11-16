# Preservation Inventory: player persistence and world IDs (read-only)

Status: COMPLETE (Q1-Q6). Verified by reading source; nothing was run in Studio. Items marked UNCERTAIN need the escalation list in Q6.
Baseline: HEAD fb51a42 on ux/onboarding-overhaul. Read-only; nothing in src/ was modified.
Linked from: ../LEDGER.md (milestone "Startup inventories (3)").

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

## Q1. Persistent IDs

Persisted maps keyed by ID (profile fields, verified in RPGProfile.luau:33-37, RouteGates.luau:19-24, ProfileSchema.luau:27):
- `defeatedBosses[bossId] = true`
- `unlockedAltars[altarId] = true`
- `routeFlags[gateId] = true` (written by server Services/RouteGates.luau:62)
- `inventory.LoreEntries[loreId] = true` (ProgressionRules.luau:61-62)
- `inventory.Weapons`, `inventory.Spells` keyed by weapon/spell IDs; `equippedLoadout` stores them by ID
- `colosseum`, `arenaWagers[id]` (id length cap 64, RPGProfile.luau:46-49)

| ID | kind | defined at (path:line) | stored in profile field |
|---|---|---|---|
| Sanctuary, DesecratedMonastery, BambooPass, AshColosseum | region | src/shared/WorldDefinitions.luau:237,248,257,267 (RegionId type :22) | not persisted; region is derived |
| SanctuaryDepths, CelestialPagoda, SkyCitadel | region | src/shared/BossRoster.luau:14-16 | not persisted |
| Altar_SanctuaryBonfire | altar | WorldDefinitions.luau:282; Objectives.luau:37 | `unlockedAltars`; always set true (RPGProfile.luau:37) |
| Altar_MonasteryGate | altar | WorldDefinitions.luau:291; Objectives.luau:38 | `unlockedAltars` |
| Altar_DesecratedCloister | altar | WorldDefinitions.luau:301; Objectives.luau:39 | `unlockedAltars` |
| Altar_BambooShrine | altar | WorldDefinitions.luau:313; Objectives.luau:40 | `unlockedAltars`; also a RouteGates "Past" altar (RouteGates.luau:11) |
| Altar_BellTerrace | altar | WorldDefinitions.luau:324 | `unlockedAltars` (not in Objectives.luau list, UNCERTAIN if objective-tracked) |
| Altar_ColosseumAntechamber | altar | WorldDefinitions.luau:335; Objectives.luau:41 | `unlockedAltars`; RouteGates "Past" altar (RouteGates.luau:11) |
| Altar_SanctuaryDepths, Altar_CelestialPagoda, Altar_SkyCitadel | altar (generated "Altar_"..regionId) | BossRoster.luau:24-27 | `unlockedAltars` |
| VenerableBaize | boss | BossRoster.luau:52 (name "Venerable Baize"); Objectives.luau:81 | `defeatedBosses`; RouteGates "Past" boss (RouteGates.luau:12) |
| SlumberingTitan | boss | BossRoster.luau:53; Objectives.luau:83 | `defeatedBosses` |
| SovereignWu | boss | BossRoster.luau:54; Objectives.luau:84 | `defeatedBosses` |
| TwinSentinels | boss (display "General Zhao"; Iron Bull is a partner, not its own ID) | BossRoster.luau:55,60; Objectives.luau:80 | `defeatedBosses` |
| AzureWyrm | boss | BossRoster.luau:56; Objectives.luau:85 | `defeatedBosses` |
| GrandmasterShen | boss | WorldDefinitions.luau:528; BossRoster.luau:63; Objectives.luau:82 | `defeatedBosses`; ArmorRules.luau:101 uses it as an armor gate |
| Gate_<bossId> (e.g. Gate_VenerableBaize, Gate_AshColosseum) | fog gate | BossRoster.luau:44,49; WorldDefinitions.luau:629 (Gate_AshColosseum) | not persisted; fog gate is per-boss, derived |
| BambooRidge | shortcut gate (RouteGates) | src/shared/RouteGates.luau:10-13; server Services/RouteGates.luau:17 (`ID = "BambooRidge"`) | `routeFlags.BambooRidge`; open also derived from Past altars/bosses (RouteGates.luau:16-27) |
| WaterfallAlcove, PagodaRafters, SealedMausoleum, FoundersKiln, SanctuaryEaves, SanctuaryReliquary | discovery cache | src/shared/ArsenalCatalog.luau:27-33 | `inventory.caches`-like table in ArsenalInventory.luau:6,10,48-52,85,102-103; NOT in ProfileSchema.luau inventory type. UNCERTAIN how it is written to the profile (grep for `caches` in RPGProfile/ProfileBridge found nothing) |
| Spell/weapon/armor IDs (ThunderclapPalm, GaleStep, Jian, ChainScythe, ...) | inventory | src/shared/ShopCatalog.luau:169-182 (cosmetics); spell/weapon catalogs not re-read | `inventory.Spells`, `inventory.Weapons`, `equippedLoadout`, `ownedCosmetics`, `equippedCosmetics` |
| Mob reward flags: HollowBellWarden (Reward.Flag) | flag | WorldDefinitions.luau:409-438 | ASSUMED stored via flag but not verified; UNCERTAIN |
| Lore entry IDs | lore | UNCERTAIN: not located; written only via ProgressionRules.discover (ProgressionRules.luau:60-62) | `inventory.LoreEntries` |
| Camp/rest, bloodstain, last spawn | world state | not checked in Q1 (see Q2/Q4) | UNCERTAIN |

Notes:
- Persisted flags are validated server-side with `I.id`, `v == true`, and a cap of 512 entries per flag map (RPGProfile.luau:60-63).
- Boss-kill rewards carry a Flag and Essence (WorldDefinitions.luau:438), but boss essence is hp*4 (BossRoster.luau:47).

## Q2. Save schema

Storage layout (two nested schemas, one DataStore):
- DataStore: `AsuraProfiles_v1` (src/server/PersistenceService.luau:17). Key: `"Player_" .. userId` (src/server/ProfileStore.luau:531,592). Other stores: `AsuraMatches_v1` (ColosseumService.luau:225), `AsuraSpectatorWagers_v1` (WagerLedger.luau:13), `Match_<id>` keys (MatchJournal.luau:7-24).
- Envelope: `{ storageVersion = 2, revision, profile, session = {id, expires} }` (ProfileStore.luau:555-560). Lease expiry: `leaseSeconds`. Unsupported storageVersion throws (ProfileStore.luau:536-537).
- Outer profile: src/shared/ProfileSchema.luau, `CURRENT_SCHEMA_VERSION = 4` (line 52). Fields at lines 9-47 include `defeatedBosses`, `unlockedAltars` (line 27), `colosseum`, `weaponMastery`, `arenaWagers`, `qiEssence`, `inventory.LoreEntries`, `receipts`, `appliedMatches`, `pendingMatches`. `routeFlags` is NOT in the ProfileSchema type (line 27 area) but is validated in RPGProfile.luau:60-62 and written by RouteGates.
- Souls section: `profile.souls`, `SOULS_VERSION = 4` (src/server/ProfileStore.luau:137). Type at lines 41-49: `{version, level, attributes, essence, inventory, world, deaths}`. `WorldState` at line 40: `{altars, activeAltar, bosses, bloodstain?, tutorial?, story?, minibosses?}`.
- So world progress is stored twice: `profile.defeatedBosses/unlockedAltars/routeFlags` (outer) and `profile.souls.world.bosses/altars` (inner). ProfileBridge syncs them (src/server/ProfileBridge.luau:11, 36-37). Two parallel currencies exist too: `profile.qiEssence` (outer) and `souls.essence` (inner). UNCERTAIN which one gameplay reads for each purpose. This is a data-risk point (see Q6).

Fields holding world progress:
| Concern | Field | Defined at |
|---|---|---|
| Last rest / spawn altar | `souls.world.activeAltar` (must be in `altars`, ProfileStore.luau:344-345) | ProfileStore.luau:40, 245 |
| Unlocked altars | `souls.world.altars`, outer `unlockedAltars` | ProfileStore.luau:245; RPGProfile.luau:33-37 |
| Defeated bosses | `souls.world.bosses`, outer `defeatedBosses` | ProfileStore.luau:443-444; RPGProfile.luau:33 |
| Route flags (shortcut gates) | outer `routeFlags` | RPGProfile.luau:34, 60; written at server Services/RouteGates.luau:62 |
| Minibosses claimed | `souls.world.minibosses` | ProfileStore.luau:353, 446-449 |
| Tutorial/story flags | `souls.world.tutorial`, `souls.world.story` | ProfileStore.luau:245, 433-438 |
| Bloodstain (death recovery) | `souls.world.bloodstain` {region,x,y,z,essence,death} | ProfileStore.luau:29, 250-263, 356-357, 455-456 |
| Essence (souls) | `souls.essence`, `souls.deaths` | ProfileStore.luau:45, 305, 381-385 |
| Qi essence | outer `qiEssence` | ProfileSchema.luau:23; RPGProfile.luau validate line 53 |
| Caches discovered | `ArsenalInventory` `caches` table (ArsenalInventory.luau:6,10,85,102) | UNCERTAIN whether persisted in outer profile or `souls.inventory`; `Arsenal.migrate` is merged into `souls.inventory` at ProfileStore.luau:459-460 |
| Lore/discovery | outer `inventory.LoreEntries` | ProfileSchema.luau:25; ProgressionRules.luau:60-62 |

Migration and version handling:
- Outer `ProfileSchema.Migrate(raw, id)` (ProfileSchema.luau ~223-289) starts from `ProfileSchema.Default`, copies known fields with repair helpers, then calls `RPG.apply` and asserts `Validate`. No per-version migration functions exist. Any older raw value is upgraded by copying into a fresh default. `schemaVersion > CURRENT` is rejected (ProfileSchema.luau:230).
- `ProfileSchema.Validate` requires `raw.schemaVersion == CURRENT_SCHEMA_VERSION` exactly (line 164). A version bump therefore needs the migration code to produce the new version (current code does this implicitly by building from Default).
- Inner souls: `Store.MigrateSouls(raw, startingAltar)` (ProfileStore.luau:362-464). Rejects `raw.version > SOULS_VERSION` (line 367-369). Validates arsenal only when `raw.version == SOULS_VERSION` (line 370). Older values are upgraded field by field from defaults.
- `Store.WithSouls` wraps the schema so every migrated profile gets `profile.souls` (ProfileStore.luau:467-472).
- Save path: `UpdateAsync` runs `schema.Migrate` then `schema.Validate` inside the transform (ProfileStore.luau:531-561); on failure the write is refused.

Risks noted for Q6:
- Two parallel copies of bosses/altars (outer and souls) plus two essence fields. Any reset or rename must touch both.
- Shortcut gate state (`routeFlags`) is outside `souls`, so migration code that only rebuilds `souls` would drop it. UNCERTAIN whether RPGProfile keeps it across a full rebuild (it does read `raw.routeFlags` at RPGProfile.luau:34).

## Q3. Shrine gateway (Altar_MonasteryGate)

All references under src/ (grep): WorldDefinitions.luau:65 (comment), 231 (`PortalDestination = "Altar_MonasteryGate"` in the Sanctuary layout), 290-291 (altar definition); Objectives.luau:38; MonasteryService.luau:5 (header), 46 (asserts `REGION.Altars.MonasteryGate`). Not referenced in any other .luau file under src/.

What it is: an incense altar (rest checkpoint) at the monastery gate landing. Spawn `at(0, 3, -728, 0)` (WorldDefinitions.luau:295), Region DesecratedMonastery.

Two different interactions use it:
1. Walking through the Shrine portal (the sanctuary "ascent" gate). Service: src/server/Services/SanctuaryService.luau.
   - Trigger: SanctuaryService.luau:375-376 builds the stair with `Ascent.Build` (src/server/Services/SanctuaryAscent.luau:121, part named `PortalTrigger`). Wired at line 397: `trigger.Touched:Connect(onPortal)`.
   - Destination: `DESTINATION = World.Altars[LAYOUT.PortalDestination]` (SanctuaryService.luau:59), i.e. Altar_MonasteryGate. `assert(DESTINATION ~= nil)` at line 361.
   - `onPortal` (lines 304-328): checks cooldown `transit[userId]`, alive, not in duel, model match. Then `Characters.Cinematic`, `Characters.Cue("PortalTransit", ...)`, and after `PORTAL_FADE` calls `Characters.Teleport(userId, arrivalCFrame(DESTINATION))`. `arrivalCFrame` (295-298) looks from the altar Spawn toward its Placement.
   - Not a ProximityPrompt. No rest happens on arrival, so it does not set activeAltar by itself.
2. Resting at the altar itself. Built by WorldService `buildAltar` (WorldService.luau:404-462), prompt `RestPrompt` with ActionText "Rest", anchored to `AltarAnchor_<id>` if authored (line 385). Triggered at WorldService.luau:1171-1180, which calls `restAt` (630-667). `restAt` sets `s.ActiveAltar`, `s.Altars[id]`, refills elixirs, sets respawn, flushes, and calls `ActivateAltar` on the ProfileStore engine (ProfileStore.luau:701-).

Return to the lobby (Workspace.Sanctuary, the MapFolder "Sanctuary"):
- UNCERTAIN: no return portal from the monastery was found. MonasteryService.luau has no Touched/Teleport code (grep). BossArenas has "Return to the Shrine" portals only for SanctuaryDepths (BossArenas.luau:96-99) and SkyCitadel (line 100).
- Likely path: WorldService `travel` (730-759) teleports to any kindled altar, including the bonfire, if the player is at an altar (`nearAltar`), not in a fight, and the destination is in `s.Altars`. Checked by reading code, not run in Studio.
- Death respawn: `onPlayerDeath` (577-609) respawns at `World.Altars[s.ActiveAltar]` via `AI.RespawnRegion` and `AI.Shelter`. So a death in the monastery returns the player to the Monastery Gate altar, not the lobby.
- The lobby itself is rebuilt by SanctuaryService.Start (358-388), which destroys any existing `Workspace.Sanctuary` folder and creates a new one. Default checkpoint is the bonfire (`BONFIRE_ALTAR`, line 370). `SanctuaryService.Start` must run before WorldService.Start (header line 14).

## Q4. WorldService flows (src/server/Services/WorldService.luau)

Public functions (module table `WorldService`):
- `WorldService.Flush(userId, timeout?)` line 300; `FlushAll(timeout?)` 312: drain the per-player persistence queue.
- `WorldService.Start()` 1158; `Destroy()` 1272.
- `WorldService.Refresh(userId)` 1300.
- `WorldService.RefillElixirs(userId)` 1305.
- `WorldService.RegisterInteractable(handler)` 1321: other services (e.g. the Sanctuary blacksmith) answer the Interact intent (comment line 91).
- `WorldService.GetSession(userId)` 1331; `IsInBossFight(userId)` 1335.

Remotes: none in WorldService. Client contact is through ProximityPrompts and player attributes only: `AsuraAltars`, `AsuraBosses`, `AsuraActiveAltar`, `AsuraEssence`, `AsuraLevel`, `AsuraElixirs`, `AsuraUnbanked`, `AsuraBloodstain`, `AsuraEncounter`, `AsuraResult` (prefix "!" for refusal), `AsuraRegion`, `AsuraOpening`, `AsuraOre`. Per-attribute list at lines 183-237.

Flows:
- Rest / checkpoint: `buildAltar` (404-462), `restAt` (630-667). Refusal reasons: InBossFight, InDuel, EnemiesNearby, TooFar.
- Fast travel: `travel(s, altarId)` (730-759). Refusals: AltarNotKindled, InBossFight, EnemiesNearby, NotAtAltar, AlreadyHere. Uses `Recovery.arrival` to place the player within rest reach.
- Death and bloodstain: `onPlayerDeath` (577-609) forfeits the old stain, calls `enqueue(... "RecordDeath")` (ProfileStore.luau:764) which writes `souls.world.bloodstain` and returns dropped essence. `placeStain` (511-556) builds `Bloodstain_<userId>` part with a ProximityPrompt (539-547). Recovery: `RecoverBloodstain` queued at line 567; refusal `NoBloodstain` at 563; `ProfileStore` clears the stain at lines 790-800.
- Respawn: `onPlayerAdded` (1024-1040) and `onCharacterSpawned` (1041-) use `record.world.bloodstain` and the active altar. Death respawn uses `World.Altars[s.ActiveAltar]` (602-608).
- Fog gate ("Traverse the Mist"): gate prompts created at 1182-1190 with ActionText literal "Traverse the Mist" (1186), `traverseGate` (857-871) checks 28-stud reach (line 863) and refusals BossFelled, ArenaOccupied, InBossFight, Unavailable. Teleports inside, then `startFight`.
- Gate sealing: `setGate(gateId, sealed)` (484-499) sets `Sealed` attribute on the `FogGate_<id>` wall (lines 467-479). `startFight` seals (853), `endFight` unseals (796).
- Participant tracking: `startFight` (824-855) adds the entrants plus any session inside the arena bounds who has not felled the boss and is not already in a fight (lines 832-840). `s.Fight = gate.Id` and `AsuraEncounter` attribute are set for each participant (846-852). `fights[gateId]` holds the record.
- Boss create/reset: create = `AI.SpawnBoss(boss.Id, list)` (841). Victory = `endFight(gateId, true)` (790-822): sets `s.Bosses[bossId]`, `publish`, `flush`, queues `RecordBossDefeat`, drops loot via `BossArenas.loot`. Reset (defeat without victory) = `AI.DespawnBoss(fight.BossId)` (819-821).
- Victory persistence: `Store.RecordBossDefeat` (ProfileStore.luau:842-858) writes `souls.world.bosses[bossId] = true`, capped by MAX_WORLD_ENTRIES, and awards arsenal (line 461 on load). It does NOT write the outer `defeatedBosses` field directly. Sync is via ProfileBridge (see Q2). UNCERTAIN whether the outer copy updates before the next save.
- Miniboss rewards: `grantMinibossReward` (937-) calls `Store.RecordMinibossDefeat` (ProfileStore.luau:870) which writes `souls.world.minibosses`.
- Fallback world generation: `buildGreybox` (362-378) builds floor parts per region when the authored `Map_<region>` folder is absent (check at 366 and 1197). `BossArenas.build` builds boss arenas procedurally (WorldService.luau:1181). `BossArenas.build` also places the return portals (BossArenas.luau:96-100).

Hard-wired IDs in WorldService.luau:
- TAG_ALTAR = "AsuraAltar" (67), TAG_STAIN = "AsuraBloodstain" (68), WORLD_GROUP = "WorldGeometry" (81), PROBE_GROUP = "CameraProbe" (82).
- Name patterns: `AltarAnchor_<altarId>` (385), `IncenseAltar_<altarId>` (410), `FogGate_<gateId>` (468), `Bloodstain_<userId>` (518), prompt text "Traverse the Mist" (1186), "Rest" (391, 451), "RestPrompt" (390, 450).
- No literal boss, gate or region IDs (no GrandmasterShen, Gate_AshColosseum, Altar_MonasteryGate) in WorldService.luau. Those come from `World.*` data (grep found none). The one exception is the fog-gate boss name via `World.Bosses[gate.Boss].Name` (1186).

## Q5. Fresh-profile progression (what needs a boss or encounter)

Free at start (no boss/encounter needed):
- Weapon: Jian fallback (RPGProfile.luau:27). Spells: ThunderclapPalm, GaleStep (ArsenalInventory.luau:10; RPGProfile.luau:31).
- Styles: Ironline unlocked; others locked (ProfileSchema.luau:75-79). Unlocks come from style spins, not bosses.
- Armor: AshenPilgrim (no requirement, ArmorRules.luau:25). CinnabarGuard needs altar `Altar_DesecratedCloister` (ArmorRules.luau:29; altar, not boss).

Boss-gated (rewards from `src/shared/ArsenalCatalog.luau:9-22`, granted by `ArsenalInventory.award` via remembrance tokens, ArsenalInventory.luau:30-34; forging needs the token, lines 41-43, 91-96):

| Reward (weapon/spell) | Boss ID that grants it | Defined at | At risk if encounter inactive? |
|---|---|---|---|
| PrayerOfTheDefiled (W), AbbotDirge (S) | GrandmasterShen | ArsenalCatalog.luau:9-10 | YES (only via Gate_AshColosseum fog gate) |
| CalamityBoneCleaver (W), FissureSlam (S) | DemonicChimera (Shen phase 2 token; BossTokens maps GrandmasterShen -> {GrandmasterShen, DemonicChimera}, ArsenalCatalog.luau:67) | ArsenalCatalog.luau:11-12 | YES (tied to Shen) |
| WarFan (W), WindSlash (S) | VenerableBaize | ArsenalCatalog.luau:13-14 | YES |
| Odachi (W), GraveTendrils (S) | SlumberingTitan | ArsenalCatalog.luau:15-16 | YES |
| Catalyst (W), BlackflameSurge (S) | SovereignWu | ArsenalCatalog.luau:17-18 | YES |
| HeavenPiercingGuandao (W), Thunderfall (S) | TwinSentinels | ArsenalCatalog.luau:19-20 | YES |
| ChainScythe (W), DragonsMaw (S) | AzureWyrm | ArsenalCatalog.luau:21-22 | YES |

Note: DragonsMaw and ChainScythe are also held by caches (ArsenalCatalog.luau:27-28: WaterfallAlcove and PagodaRafters), so a player can get them without the Wyrm.

Cache rewards (no boss needed; discovery only): WaterfallAlcove (ChainScythe, HeavenlyLightningSpear), PagodaRafters (TwinDaggers, DragonsMaw, Dao), SealedMausoleum (Odachi, GraveTendrils, BlackflameSurge, Guandao), FoundersKiln (materials only), SanctuaryEaves (WarFan, JadeAegis, CelestialSupernova), SanctuaryReliquary (Catalyst, EmberCataclysm, BlazingSunAwakening) (ArsenalCatalog.luau:27-33). Spells are granted by claiming a cache (ArsenalInventory.luau:67-68).

Armor (boss-gated): IronOath needs boss TwinSentinels (ArmorRules.luau:32, 101). YES, at risk if the Twin Sentinels encounter is inactive.

Route access (boss/altar-gated):
- Gate `BambooRidge` opens if `routeFlags.BambooRidge`, OR any of altars Altar_BambooShrine / Altar_ColosseumAntechamber is unlocked, OR boss VenerableBaize is defeated (RouteGates.luau:10-13, 16-26; "any" logic, not "all"). Server sets the flag at Services/RouteGates.luau:62.
- `Objectives.luau:247-258`: next objective is the next undefeated boss in the list (Boss:<id> step), so a missing boss changes the quest path.
- Ascend steps keyed `Ascend:<altarId>` (Objectives.luau:111, 231) depend on altars.

Quest/story steps:
- Shen is the only boss behind a fog gate created from WorldDefinitions (Gate_AshColosseum, WorldDefinitions.luau:629) and Objectives.luau:82 (Region AshColosseum). YES, at risk if its encounter is inactive.
- Ending decisions count defeated bosses (DialogueActions.luau:14, 47; EndingRules.luau:82-103). Ending.stage uses `p.defeatedBosses`.
- Remembrance grants depend on `souls.world.bosses` on every load (ProfileStore.luau:461), so the award list is recomputed from boss IDs.

Non-boss progression: Qi from lore discovery (ProgressionRules.luau:60-62), essence from encounters (WorldDefinitions.luau:374, 400, 429, 463 mob Essence values), Gao forge and blacksmith (Objectives.luau:130-134). Mob essence is not boss-gated, but a boss kill adds Essence (`boss.Essence = hp*4`, BossRoster.luau:47).

## Q6. Uncertainties and data-risk points

Data-risk points (ordered by severity):
1. Duplicate state. Boss and altar flags exist in both outer `defeatedBosses`/`unlockedAltars` (ProfileSchema.luau:27) and `souls.world.bosses`/`altars` (ProfileStore.luau:40). ProfileBridge syncs them (ProfileBridge.luau:11, 36-37). `RecordBossDefeat` writes only the souls copy (ProfileStore.luau:842-858). UNCERTAIN whether the outer copy catches up before save. Any change to bosses or altars must update both.
2. Two essence fields: outer `qiEssence` (ProfileSchema.luau:23) and `souls.essence` (ProfileStore.luau:45). UNCERTAIN which the new world must use. Do not reset either.
3. Renaming an ID silently strands progress. Boss IDs (`defeatedBosses`, remembrance tokens via `BossRemembrance_<id>`) and altar IDs (`unlockedAltars`, `activeAltar`) are keys. A rename orphans them. `ArsenalCatalog.LegacyBosses` (read via ArsenalInventory.luau:19, 25, 59) exists for remembrance IDs but NOT for route/altar IDs.
4. Unknown IDs are kept, not pruned. RPGProfile validation checks shape only (`I.id`, `v == true`, max 512 per map; RPGProfile.luau:60-63). Removed boss or altar IDs will linger harmlessly in the profile, but a removed `activeAltar` is repaired at migration (ProfileStore.luau:451-452), so the player is moved to the bonfire silently.
5. Bloodstain is stored as `souls.world.bloodstain` with a region name and coordinates (ProfileStore.luau:29, 764-800). If a region is removed, placeStain may fail. UNCERTAIN handling.
6. Schema migration is implicit. `ProfileSchema.Migrate` rebuilds from Default and copies known fields (ProfileSchema.luau ~223-289). Any field renamed or removed is dropped silently, with no warning. A forward-version guard exists (ProfileStore.luau:367-369), so old servers refuse newer souls records. Keep this guard.
7. The `routeFlags` field is not in the ProfileSchema type (ProfileSchema.luau:9-47), so it survives only because RPGProfile.luau:34 copies it. Treat it as at-risk.
8. Separate stores: `AsuraMatches_v1`, `AsuraSpectatorWagers_v1`, `Match_<id>` (MatchJournal, ColosseumService, WagerLedger). A world replacement must not reset these; they are not world state, but check that nothing in the new world clears them.
9. In-flight receipts and pending matches (ProfileSchema.luau:47: `receipts`, `appliedMatches`, `pendingMatches`) must not be cleared during a reset, or replays and duplicate charges become possible.

UNCERTAIN / not verified:
- Exact contents of `ArsenalCatalog.LegacyBosses` and `Catalog.Recipes` vs legacy IDs (not read).
- Where `ArsenalInventory.caches` is saved in the profile (not in ProfileSchema.inventory type; grep for `caches` in RPGProfile and ProfileBridge found nothing).
- Lore entry IDs (LoreEntries keys) and the lore catalog file (not located).
- Monastery return-to-lobby path (no portal in MonasteryService; see Q3).
- ProfileBridge save direction (read only lines 11, 36-37).
- Shen phase-2 `DemonicChimera` is a token, not a separate boss in WorldDefinitions.Bosses; whether a separate defeat record exists is UNCERTAIN.
- Mob reward flags (`Reward.Flag`, e.g. HollowBellWarden) are stored in `souls.world.minibosses` (ProfileStore.luau:870-880), not in outer flags; confirmed by RecordMinibossDefeat but not read in full.

NEEDS SONNET ESCALATION (unanswered, with file):
- LegacyBosses content and whether route/altar IDs have any legacy alias: src/shared/ArsenalCatalog.luau (LegacyBosses) and src/simulation/ArsenalInventory.luau:19, 59.
- Caches persistence location: where `ArsenalInventory` state is written to the profile (search src/server/ProfileStore.luau:459-461 and src/server/ProfileBridge.luau).
- Lore entry ID list: src/shared/ProgressionRules.luau:60-62 callers (DialogueActions.luau:59) and the lore catalog.
- Monastery return path: src/server/Services/MonasteryService.luau full read for any teleport or return portal.
- ProfileBridge direction: src/server/ProfileBridge.luau full read.


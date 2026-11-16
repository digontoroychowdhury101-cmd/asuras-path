# Asura’s Path open-world documentation and implementation gaps

Preliminary static assessment. **Reference gameplay comparison remains incomplete.** Priority below is proposed sequencing, not a claim that Hero implements each feature. `src/` searches did not find the proposed new region names; this is evidence about this checkout, not proof about unpublished work elsewhere.

## Existing foundation: preserve and document

| Area | Evidence and current behavior | Documentation still needed |
|---|---|---|
| World construction | `WorldDefinitions` + `BossRoster.apply`; Sanctuary/Monastery builders and five `CampaignZones.Layouts` build seven regions. `Bootstrap.server` starts these before WorldService. | Current playable atlas separate from proposed fourteen-region atlas; destination of every retained asset and encounter. |
| Traversal topology | `MonasteryZones`, `CampaignZones`, `RegionLayout`, regional layouts and `RouteGuide` represent doors, height bands, optional jumps, one-way drops and portals. | New connected route graph, measured travel durations, sightlines, safe retreat options and actual traversal distances. |
| Movement | `InputMap` exposes double jump, dash, sprint, slide, bullet jump and a 3.5-second glide help label. | Test actual reachable geometry; do not inherit a reference character's mobility assumptions. Swimming/climbing/mount behavior is not established by this review. |
| Checkpoints/death | `WorldService` owns active altar, elixir session state, unbanked Essence, bloodstain and serial persistence commits. | Put each checkpoint on the new graph; define runback, rest reset, death/rejoin and retrieval across transitions. |
| Ordinary encounters | `AIService` reads Monastery/Campaign zones, drives CharacterService intents and owns patrol/alert/combat/return states. | Encounter placement, safe-zone edges, group pressure and retreat across each new route. |
| Major encounters | `WorldDefinitions`/`BossRoster` supply Shen, Baize, Titan, Wu, Twin Sentinels and Wyrm. Twins include Zhao and Iron Bull. | Encounter relocation and unique approach/arena design; preserve earned rewards and existing boss identities. |
| Combat identity | `CombatSettings`: 1.4 tempo scalar, 60 Hz simulation, layered health/rally, posture and deflect. | Open-world encounter budget and terrain cases; fresh feel acceptance rather than assuming timing settings prove feel. |
| Growth/equipment | `ProgressionRules`, `RPGProfile`, `ArmorRules`, `ForgeService`, `ArsenalCatalog`. | Regional difficulty/reward pacing, alternatives to mandatory grind, material routes and equipment relevance. |
| Discovery | Authored caches, NPC/lore content and permanent route flags exist. Founders' Kiln pays materials; BambooRidge shortcut respects old progress. | Place these discoveries and persistent changes on the new map; define optional content payoff and return paths. |
| Atmosphere | `EnvironmentProfiles` and client `EnvironmentController` select biome/fight/phase looks; server applies shrine baseline. | New biome profiles and transitions, weather/day-time design decision, water/acoustic boundaries. |
| Audio and scenery cost | `SoundscapeController`, `SpatialAudio`, `FoliageWind`, `LandscapeBudget`; regional builders/dressing and mesh/PBR libraries. | Regional sound palettes, vista hierarchy, foreground readability and comparable device workloads. |
| UI/accessibility | `InputMap` includes keyboard/pad/touch captions; comfort options exist in profile schema. | Test new-map navigation on each input device, menus during danger, text scaling and reduced effects. |

These are source capabilities, not fresh Studio passes.

## Prioritized gap register

| ID / priority | Gap and concrete failure scenario | Existing location | Completion evidence |
|---|---|---|---|
| OW01 / first | Fourteen-region direction is not the seven-region runtime. A design writer could mark Longfields complete because a generated atlas exists. | `outputs/world-design/World-Design-Revision-02.md`; `src/shared/WorldDefinitions.luau:235`; `BossRoster.luau:12` | Region ledger: proposed, blockout, built, integrated, accepted; map every legacy region/asset to a keep/move/retire decision. |
| OW02 / first | The first open-world slice has no measured physical specification in the inspected direction. Enlarging scenery alone gives long empty travel rather than choices. | World Design Revision 02, “Roblox build approach” | Walkable Longfields → Bellwater → first Old Ward section, an optional branch, a distinct landmark choice and a returning shortcut; timed ordinary traversal footage. |
| OW03 / first | Streaming is explicitly disabled and validated as disabled. Simply toggling it breaks the existing config contract; leaving the full expanded world resident has unknown device cost. | `default.project.json:15`; `Config.luau:132`; `ConfigValidator.luau:100` | Decide residency strategy, update contracts intentionally, exercise stream-out/in for prompts, targets, HUD, audio and VFX; measure memory/frame distributions. No current performance conclusion. |
| OW04 / first | Existing route logic has region-specific portal assumptions and named joins. A new connection could produce a marker pointing to an obsolete portal or through a closed gate. | `RouteGuide.luau`; `CampaignZones.luau`; `SanctuaryRoutes.luau` | Reuse graph interfaces, update destinations, verify every required edge both ways, one-way returns and saved gates with ordinary control. |
| OW05 / first | New world needs a migration plan. Relocating/renaming altar, boss, cache or shortcut IDs can strand existing progress or duplicate grants. | `RPGProfile.luau`; `ProfileSchema.luau`; `ArsenalCatalog.LegacyBosses`; `RouteGates.luau` | Old-profile fixtures retaining ownership/progress, valid new spawn fallback, exactly-once discoveries and safe rejoin. |
| OW06 / first | Existing compact encounter zones/leashes are not authored for new open fields and settlements. A player may pull enemies to a safe hub or fight across inaccessible slopes. | `AIService.luau`; `MonasteryZones.luau`; `CampaignZones.luau`; `MobSpacing.luau` | Zone authoring and encounter recordings: multi-approach aggro, retreat, ally targeting, elevation, checkpoint shelter, repeated reset. |
| OW07 / next | Current boundaries include invisible Veil fences and catch volumes. Treating background terrain as freely explorable could expose abrupt barriers or unexpected teleport returns. | `BambooPassLayout.luau` (VEIL_H 220); `CampaignBounds.luau`; `MonasteryBounds.luau` | Playable-area boundaries communicate physically; test double jump/glide, edges, falls and safe return without entering boss-owned recovery. |
| OW08 / next | Regional clocks are authored looks, not evidence of a running day/night/weather simulation. Adding a global cycle may fight biome/encounter tweens or darken attack tells. | `EnvironmentProfiles.luau`; `EnvironmentController.luau`; mapped `Services/EnvironmentService.luau` | Explicit static-vs-dynamic decision; if dynamic, one composition owner for time/biome/weather/fight, visibility floors and measured transition recordings. Do not infer that Hero has a full cycle. |
| OW09 / next | The new geography promises rivers, coast, wetlands, sluices and connected underground areas; the inspected runtime does not establish these new features. Water visuals alone do not define traversal. | World Design Revision 02; `CampaignTerrain.luau`; regional layouts | Watershed/elevation blockout, shoreline collision, depth and fall/swim rules, permanent sluice states and join/rejoin behavior. |
| OW10 / next | Existing checkpoint and reward mechanics need new spacing. Wide travel can magnify death recovery or make upgrades compulsory before any alternative route. | `WorldService.luau`; `ProgressionRules.luau`; `LootService.luau` | Timed first-session and death loops, safe rest access, optional difficult encounters, reward/upgrade table linked to route observations. |
| OW11 / next | Lore/NPC catalog exists but is not the settlement/quest specification of Bellwater and the other proposed regions. | `NarrativeCatalog.luau`; `DialogueService.luau`; `DialogueActions.luau`; `EndingRules.luau` | State table per NPC/quest: prerequisites, transitions, reward, persistence, dialogue change, postgame state and recovery after reconnect. |
| OW12 / next | Existing asset production covers old regions/arenas. It cannot substitute for settlement, occupation and trade geography in the new direction. | `ENVIRONMENT_PROMPTS.md`; visual-audit production packet; `assets/models/` | Asset reuse ledger by new area; buildings with purpose, entrances, interior routes, scale, texel/material treatment and collision ownership. Preserve existing approved art sources. |
| OW13 / next | Enlarged traversable space adds long-lived effects and streaming lifetimes. This is a validation need, not a traced memory leak. | `EnvironmentController.Destroy`; `LandscapeBudget.Destroy`; `BossEffects`; `PlaybackScale`; `SpatialAudio` | Record ownership from allocation to teardown; repeated encounter/respawn/teleport/stream-out runs; delayed callbacks invalidated where needed; compare counts after cooldown. No speculative leak fix. |
| OW14 / next | Old route-specific audio and acoustics will not automatically follow new buildings, caves or waterfalls. | `SoundscapeController.luau`; `EnvironmentProfiles.acoustics` | Region/space sound table, interior/exterior transition, footstep surfaces, source positions, audibility and cleanup after crossing/rejoin. |
| OW15 / acceptance | Combat already has unresolved historical acceptance. Open-world completion cannot close animation/contact/network gates by documentation. | `outputs/master-completion-audit-2026-11-06/README.md` | Revalidate current source: ordinary-input visual contact, slopes/steps, real two-client cases, human feel and device evidence, separately labeled. |
| OW16 / acceptance | Regional diagrams and coordinates are not yet measured reference-game maps. A guessed 100-stud ASCII grid would create false precision. | This archive `SESSION.md` | Trace routes with observations and calibration, identify compass convention, separate estimates from measurements, include elevation and unreachable areas. |

## Reference-to-project comparisons that can currently be made

- Hero visibly has a save summary with location, level, stat abbreviations and recorded time. Asura has persistence/profile infrastructure, but a matching save-slot front end has not been established by this audit. Decide whether multiple slots serve this game's design before adding them.
- Hero visibly offers server selection with name, region, occupancy and displayed ping. Asura's server browser equivalent has not been established. This is an observed presentation difference, not evidence that server browsing is required for an open world.
- Hero's observed approach uses a bright cyan destination opening between dark rock/statue masses and warm grass foreground. Asura already has destination portals and region lighting; the useful candidate lesson is destination contrast, with avatar/attack readability checked at player height. Do not reproduce an unmeasured lighting preset.
- Hero's E interaction caption differs from Asura's canonical Z/USE input. This is not a missing mechanic. Preserve `InputMap` as the source of captions and accepted controls.
- Hero's compass and diamond quick slots were observed. Asura already has compass/minimap/action-bar controllers. Compare usability once Hero's menus and traversal can actually be exercised, rather than calling navigation absent.

## Build order proposed for the existing open-world direction

1. Record retain/move/retire decisions and persistent-ID mappings; choose the first playable slice.
2. Block out terrain, elevation, water and the route graph; time existing movement through it.
3. Place checkpoints, safe pockets, one returning shortcut and ordinary encounters; test retreat/death/rejoin.
4. Integrate one retained boss with its real body/attacks and intended arena visibility.
5. Place discoveries, NPC/quest states, forge/material sources and a complete first-session loop.
6. Make residency/streaming behavior work, including teardown; verify both players' views where relevant.
7. Dress landmarks, settlements/interiors, vegetation and ordinary working spaces using the reuse ledger.
8. Compose regional lighting/audio and any approved weather/time system without competing owners.
9. Validate current combat and the slice on real input devices and comparable recorded workloads.
10. Expand region by region using this accepted slice's measured constraints, not speculative map scale.

No generic replacement AI, terrain or weather scripts are supplied: the reference behaviors have not been measured, and this project already has working integration interfaces.

## Thonia route and fragment evidence

- The east switchback uses exposed dirt to guide the player downhill through grass, ferns and tall trunks. At the arch approach, grass and a pursuing enemy filled the camera and obscured the fight. Check Longfields route and encounter readability together at normal camera height, including when an enemy closes from behind. [Field log, E06–E08](ENVIRONMENT_FIELD_LOG.md)
- The Thonia’s Tongue overlook combines a visible landmark with a discoverable Fragment. After discovery, the same object offers leveling, flasks, fast travel, storage, spell attunement and Echoes. Define which services belong at Asura’s Path checkpoints and which belong in settlements before placing return points on the open-world routes. [Field log, E09–E10](ENVIRONMENT_FIELD_LOG.md)

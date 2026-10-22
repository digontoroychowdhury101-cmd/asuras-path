# Asura's Path — hands-on playtest, 20 October 2026

The Sanctuary has a memorable visual focal point, and the game already has a substantial set of combat, movement and progression systems. The experience currently breaks down around reliable retries, combat visibility, interaction consistency and the gap between the opening area's presentation and the later campaign blockouts. Those are the next priorities before tuning the whole game's difficulty or adding more systems.

**This was an actual Studio play session, but it was not a completed campaign.** I played the opening route, fought normal enemies, killed one monk, upgraded Vigor, rested at three altars, died and retried, explored around the Monastery, and entered all six boss encounters. I did not defeat a boss or reach the ending through earned progression. The later encounters were brief attempts accessed with test teleports; a temporary camera assist was also used for the later attempts because native mouse capture was unreliable through the control tool. Boss balance, phase two behavior and victory/reward delivery therefore remain unverified by play. The findings below distinguish direct observations, source findings and design recommendations.

## Test conditions and coverage

- Local single-client Roblox Studio session using `outputs/AsurasPath.rbxlx`, with the Rojo connection visible at `localhost:34872`.
- Existing working tree, based on Git commit `4dfc507` with substantial pre-existing changes. This report describes the working build seen in Studio, not a clean committed release.
- Fresh local session; local/mock profile behavior. No published live-server persistence or multiplayer claims.
- Keyboard and mouse: camera rotation, movement, jumping/double jumping, lock-on, light/heavy attacks, weapon art, guarding/deflect input, dodge, healing, both starting spells and interactions were exercised. Precise successful deflect timing was not established.
- Later access assistance changed position and temporarily stabilized the camera. No boss was automatically killed and no player health/damage boost was applied. This assistance prevents a verdict on the normal later route and default boss camera behavior.
- Simulation was paused briefly while inspecting, and the local test was stopped afterwards. Temporary runtime observers/camera helpers ended with the session. No gameplay source or saved place was changed for this assessment.
- Sound errors were inspected in the runtime log. The control tool did not provide a dependable audio listening channel, so this is not an assessment of the mix, music quality or positional sound by ear.

| Content | What was actually checked | Result / limit |
|---|---|---|
| Prologue and Sanctuary | Fresh boot, bonfire, Lin dialogue, level menu, stairs and portal | Reached Monastery normally; Vigor 10 → 11, level 2, HP 100 → 106 |
| Monastery Gate / courtyard | Rest, two-monk engagement, attacks, spells, guard and heal | One monk killed; +45 carried essence observed; died to subsequent combat |
| Monastery exploration / bridge | Alternate exterior route, wall double jump, ravine recovery, bridge swordsman | Traversal possible; bridge target was obstructed and remained at 120/120 during attempted attacks |
| Desecrated Cloister | Reached normally, rested, closed Lin projection and fought another monk | Rest refilled HP/gourd; obstructed altar camera; died; returned to Sanctuary |
| Twin Sentinels | Assisted approach, gate/encounter start, brief combat-input attempts and retry | Both names/boss UI appeared; deaths; no victory or sustained combat assessment |
| Venerable Baize | Assisted approach, start, spell/defense/jump and melee-input attempt | Air Glide counter cue and current model seen; no phase transition/victory |
| Grandmaster Shen | Assisted approach and brief fight with spell, defense/dodge/heal/melee inputs | Player damage, perilous cues and arena seen; no victory |
| Slumbering Titan | Assisted approach and brief fight/counter attempt | Arena and Air Glide cue seen; no victory |
| Sovereign Wu | Assisted approach and brief spell/dodge/melee-input attempt | Encounter starts; extremely poor visibility; no victory |
| Azure Wyrm | Assisted approach and brief spell/dodge/melee-input attempt | Encounter starts; current humanoid/wing-line presentation seen; no victory |
| Arsenal / Codex | All three Arsenal tabs, starting loadout, locked recipes, Codex opening/closing | Menus render; progression presentation gaps found; no cache unlock or forge transaction completed |
| Six-boss completion / ending | Source inspection only | Ending dialogue exists; an actual crossing/credits/completion sequence was not found in the inspected flow |
| PvP, wagers, touch/gamepad, reconnect | Not played | Requires separate sessions/devices/players |

## Highest-priority problems

Priority **P1** means address before the next representative full playthrough; **P2** means a major quality/clarity improvement; **P3** means polish after the core loop works.

### 1. P1 — Later checkpoints did not produce later respawns

**Observed, repeated before assisted boss access.** I rested at Monastery Gate, died, and returned to Sanctuary. After reaching and resting at Desecrated Cloister, death again returned me to Sanctuary. Client attributes still reported the later active altar while the player was physically at the Sanctuary spawn. One captured state was `AsuraActiveAltar=Altar_MonasteryGate`, `AsuraDeaths=1`, `AsuraRegion=Sanctuary`, position approximately `(0, 603.13, 920)`. Later observations retained `Altar_DesecratedCloister` at the same Sanctuary spawn.

The practical result is a long repeated run through the opening, and a bloodstain target across the portal/world separation. Diagnose checkpoint resolution, respawn placement and the Sanctuary fall-return safeguard together. The exact cause was not proven. Acceptance: rest at each altar, die to an enemy, and respawn safely at that altar with the appropriate resources and encounter reset.

### 2. P1 — Boss arenas lose most of their readable image

**Observed across all six encounter starts.** Entering combat changes the environment into a near-black scene. At Shen, Titan and Wu, much of the floor and both combatants disappear outside small pools of brazier light. Wyrm briefly had readable blue illumination during an effect, then returned to near-black. Labels, warning rings and HUD petals remain much brighter than the actors.

The source supports a likely contributor: `EnvironmentProfiles.resolve` applies the Ash Colosseum night profile to every first-phase boss, regardless of biome. Arena braziers are placed toward four corners with limited range. Improve neutral fill, actor/weapon separation, floor readability and biome-specific combat lighting. Evaluate at normal play distance and without a bright effect active. This needs fixing before judging attack telegraphs or difficulty.

Evidence: [Shen](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/04-shen-arena.png>), [Titan](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/05-titan-arena.png>), [Wyrm](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/07-wyrm-arena.png>).

### 3. P1 — The bridge fight is obstructed by its geometry

**Observed; root cause still to verify.** The Cursed Swordsman's lock marker and name were associated with the bridge's tall central stone obstruction. The enemy was difficult to see/reach, and remained at 120/120 during my attempted melee and spell attacks there. This could involve spawn height, pathing, a collision barrier or the attack line; the image alone does not prove which.

Move the enemy onto a clearly walkable combat surface and verify navigation/attack contact from both ends of the bridge. Check the central stone pieces against the intended path width and combat camera. [Evidence](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/03-bridge-enemy-obstructed.png>).

### 4. P1 — Desecrated Cloister altar needs physical and camera clearance

**Observed.** The rest interaction put the camera into/against large dark stone geometry; Lin's projection was obstructed. After closing the dialogue I needed to work around the pillar to leave the immediate area. The altar is technically reachable but does not feel like a safe, legible rest pocket.

Give the altar an open approach, standing area, departure path and tested portrait-camera clearance. Repeat the same collision/portrait check for every altar, using both shoulder views.

### 5. P1 — The taught interaction button differs from the altar button

**Observed and source-confirmed.** The controls card teaches Z for interaction, NPCs show Z, but altars show E. Pressing Z at the altar did nothing in the tested state. InputController suppresses its general interaction intent when a ProximityPrompt is showing, even when that prompt uses a different key.

Use one interaction binding and one prompt implementation throughout, including altars, caches, lore, fog gates and bloodstains. The control card should always describe the actual input accepted by the focused object.

### 6. P1 — E is also a spell, causing interaction ambiguity

**Observed and source-confirmed.** E casts Gale Step away from an accepted interaction. While attempting to reclaim a bloodstain, I cast/moved instead of recovering it. At an altar the same key rests. This is a costly distinction in a game where another death erases the previous loss.

Separate the spell and interaction keys, or implement explicit context ownership with clear priority and range feedback. Test just inside and just outside prompt range so one key never unexpectedly turns a recovery attempt into movement.

### 7. P1 — Combat sounds repeatedly throw cleanup exceptions

**Runtime-log observation, source-supported diagnosis.** The recorded fresh-run interval contained 179 locked-Parent exceptions involving `AsuraAudioSource` sounds, including `Flesh`, `Blunt`, `Clash`, `Bell` and `ParryBass`. The implicated cleanup path is `SpatialAudio.at`: destroying a child sound destroys its parent, while parent cleanup can itself destroy the child. Recursive destruction is a likely cause, not yet a validated fix. [Selected runtime evidence](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/runtime-evidence.txt>).

Make source/sound lifetime cleanup idempotent and verify ordinary combat, rest, death and session shutdown without those errors. This report does not claim how much of the mix was audible.

### 8. P1 — Owned remembrance tokens are checked as booleans in the UI

**Source finding; not reached through a boss victory.** `ArsenalInventory.award` stores a token object for each remembrance. `ArsenalTabs` checks `inv.remembrances[r.Boss] == true` to enable Forge. A valid token object fails that check, so an owned remembrance can still be presented as Locked.

Align the ownership check with the token schema and verify the entire earned boss kill → reward → Gao → enabled recipe → confirmation → forged item flow. See [ArsenalTabs.luau:103](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/client/Controllers/ArsenalTabs.luau:103>) and [ArsenalInventory.luau:21](</Users/digonto/Documents/ChatGPT/Roblox game 2/src/simulation/ArsenalInventory.luau:21>).

### 9. P1 — Transmutation content has not caught up with the campaign roster

**Menu observation and source finding.** Recipes shown include Demonic Chimera and Ash Pagoda General. The active six-boss roster includes Baize, Titan, Wu, Twins and Wyrm, but those five do not have matching recipes in `ArsenalCatalog`. Shen intentionally awards both Shen and Chimera tokens in the current inventory code; that detail alone is not a bug. The absent recipes and old Ash Pagoda General references are the unresolved content mismatch.

Decide the reward pair for each current boss, align names/IDs across lore, remembrances and recipes, and remove or explain obsolete entries. [Menu evidence](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/08-transmutation-roster.png>).

### 10. P1 — The promised ending needs a playable conclusion

**Source finding and design gap; ending not played.** Lin's six-sovereign Release dialogue says the player may cross or remain. Its choices currently lead to leveling or closing the conversation. In the inspected objective flow, completing all six bosses resolves to the PvP Colosseum objective. I did not find a crossing decision, ending scene, credits or explicit campaign-complete presentation in that flow.

Build a clear conclusion to the six-soul promise: return objective, deliberate choice, visible world/story response, completion acknowledgement and a clean continue-playing option. Verify it with earned victories before calling the campaign complete.

## Combat and teaching

### 11. P2 — Introduce mechanics through a safe first encounter

**Design recommendation based on the opening play.** The game presents many controls, stats and resources before giving the player a structured practice sequence. Add a safe enemy/training space that teaches one light hit, one deflect, one dodge, lock-on, healing and a deathblow. Then introduce a perilous counter and Blood Rally. A long control card does not establish those skills.

### 12. P2 — Explain the changing health ceiling and Blood Rally

**Observed.** My displayed maximum fell from 106 to lower values during damage, and healing stopped at the reduced ceiling. Without prior system knowledge, it looks as if the flask has failed or maximum health has been lost permanently. Explain recoverable versus lasting damage, the rally time window, what attacks restore, and what rest restores. Make the relevant bar segments distinguishable with labels/animation as well as color.

### 13. P2 — Perilous counter instructions need concrete input teaching

**Observed.** Boss cues say `Counter: Air Glide`, `Deflect` or `Evade`. Air Glide is not a self-explanatory button action for a first-time player. Teach the movement earlier, and include the relevant input icon/context hint on the first few cues. Preserve distinct attack poses, weapons and timing after lighting is fixed.

### 14. P2 — Make attack range and missed contact understandable

**Observed.** Several swings/heavy attempts from apparently close positions did not damage the target, while the starting palm spell could connect. Some attempts were outside the actual weapon reach; pressing guard during startup can also intentionally feint an attack. Those should not be mistaken for a broken damage system. Improve reach animation, contact VFX and the visual spacing between actors so a player can tell a whiff, a feint, a block and a hit apart.

### 15. P2 — Make the first combat encounter readable before using multiple enemies

**Observed.** Two monks can engage together, with overlapping bodies, warning indicators and names. The first courtyard should establish one readable duel before testing crowd control. For later groups, use approach spacing, line of sight and clear roles. This is a teaching/presentation recommendation, not a measured conclusion that their damage is too high.

### 16. P2 — Boss entry needs a fair, observable handoff

**Observed brief attempts; default-camera verdict limited.** Encounter starts lead quickly into incoming attacks, labels and environmental changes. At the Twins, deaths occurred very soon after entry, including on retry. Native control latency and camera capture make that unsuitable evidence for reducing boss damage. Verify that players are protected or fully in control during any introduction, that the camera has returned before attacks can connect, and that the entrance has enough readable space.

### 17. P2 — Give the Twins distinct, persistent identification

**Observed.** General Zhao, the encounter title and Iron Bull's name overlapped around the main boss bar. Give each actor a distinct silhouette, role and readable bar/name arrangement. Teach how switching targets works. Test the duo's opening and separation behavior with a human continuous-input run after the visibility fix; I did not validate their full coordinated moveset.

### 18. P2 — Improve death and retry feedback

**Observed.** Death can retain combat labels/callouts/HUD elements into the transition. Respawn also produced a fall-return message and abrupt view changes. Present death, loss, respawn location and recovery goal in a clean sequence. Do not classify every odd angle in this session as a camera bug: native mouse capture caused additional view disturbances, and the later fixed-camera assist bypassed normal behavior.

### 19. P2 — Clarify the stakes of carried currency

**Observed loss; rule confirmed in source.** The starting currency and combat reward were lost on death, and a second death removed the previous recovery opportunity. Explain that rule before the first likely death and distinguish carried, banked and spent values. Reassess the amount of repeated travel and early loss after checkpoints work; otherwise the economy is being evaluated through a broken retry loop.

### 20. P3 — Decide whether healing at full health should consume a charge

**Observed.** R could consume a flask while HP was already full. Prevent the waste, or deliberately retain it with clear feedback. Increase the legibility of the small remaining-charge count.

### 21. P3 — Replace crude enemy death breakup with authored feedback

**Observed on the killed monk.** The body breaks into block parts, with the name/indicator briefly lingering. A brief collapse, dissolve or consistent death effect, prompt nameplate removal and a readable reward pulse would make the kill feel much more intentional.

## World, route and visual production

### 22. P2 — Complete the environments beyond the Monastery

**Observed at assisted approaches, corroborated by procedural world construction.** Bamboo Pass, the Colosseum approach, Sanctuary Depths, Celestial Pagoda and Sky Citadel largely read as flat ground/arena floors, isolated props and fog apertures. The names promise bamboo routes, a crypt, rafters and a summit, which the visited views do not yet deliver. These need authored routes, silhouettes, boundaries, landmarks, encounters and discoveries. Assisted access did not validate every normal connecting path.

### 23. P2 — Boss models need to fulfill the encounter premise

**Observed.** Baize read as a bright block humanoid; Wyrm read as a blue humanoid with line-like wing extensions. Darkness limited the inspection of the other bosses. Audit whether intended skins are actually attaching, then supply complete models, material response, rigged poses and attack animations. Do not assume that an asset existing in the library proves it appears correctly in play.

### 24. P2 — Player and NPC presentation is far behind the hero environment

**Observed.** The player is a plain bald block avatar with a dark textured outfit. Lin and encountered enemies have very simple body/face presentation. Define recognizable apparel, faces, proportions and weapon handling so they belong to the same game as the colossal shrine figure. NPC dialogue needs a readable, expressive subject.

### 25. P2 — Give the Monastery more authored spatial variety

**Observed along the walked route.** Large repeated stone slabs, walls, pillars and lanterns dominate. Add distinctive combat pockets, a recognizable courtyard/bridge/cloister progression, broken architecture with deliberate cover, and local storytelling. Vary rhythm and silhouette before adding more repeated decorative pieces.

### 26. P2 — Close or develop the walkable empty exterior

**Observed.** It was easy to leave the intended Monastery route and walk along a large empty outside area. If that is a secret route, give it a destination and reward; otherwise use terrain, architectural boundaries or clear visual guidance to keep exploration intentional.

### 27. P2 — Audit traversal against level boundaries

**Observed.** Double jumping could put me on a wall. Falling into the ravine did not end the run; I could jump back up. Those may be valid wuxia movement freedoms, but the levels must account for them. Decide which walls/gaps are intended shortcuts and which should resist bypassing, then place rewards and enemy leashes accordingly. Do not simply remove mobility to compensate for an unfinished level.

### 28. P2 — Show navigable routes, including portal legs

**Observed.** The objective marker gives a direct distance across walls/vertical separation and, after death, across the Sanctuary-to-Monastery separation. The minimap shows points but little usable path/terrain information. Add route landmarks or staged waypoint targets at portals, bridges and turns. Make a bloodstain recovery route understandable from the respawn point.

### 29. P2 — Correct the Sanctuary destination wording

**Observed and source-confirmed.** After later altar progress, the objective said the northern gate would reach Whispering Bamboo Shrine. The actual Sanctuary portal still leads to Monastery Gate. Describe the immediate destination accurately, then advance to the next leg of the journey.

### 30. P2 — Make portal arrival and the nearby checkpoint obvious

**Observed.** The Monastery arrival faces into the route while the first altar is slightly behind the arrival point. The objective initially tells the player to kindle an altar only a few meters away, but its location is easy to miss. Frame arrival toward a safe orientation with the checkpoint in view and make the transition/arrival name clear.

### 31. P2 — Keep the shrine's large-scale spectacle, refine player-scale views

**Observed from the opening plaza.** The enormous veiled figure/tree is the most memorable feature. Its full composition often extends well above the normal camera view and lower portions are hidden by the gate. Build a few intentional reveal points while walking the stairs/landing, and verify the terrace edge and roots from the player's collision height. The full new terrace route was not walked in this session.

### 32. P3 — Establish a consistent architecture/material vocabulary

**Observed.** Highly detailed scanned assets, simple repeated primitives and a Roman-looking arch do not consistently share the same style or scale. Choose a deliberate wuxia/ruin reference language and match texture scale, roughness, wear and silhouette. Preserve intentionally contrasting landmarks where their story supports them.

## HUD, menus and narrative presentation

### 33. P1 — Controls card overlaps the combat action bar

**Observed.** Opening H puts the controls panel into the bottom-center action area, obscuring other guidance. Reserve a layout region or make it a proper modal. Verify the default opening state and a player reopening it mid-route. [Evidence](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/01-controls-overlap.png>).

### 34. P2 — Remove duplicate default and custom combat UI

**Observed.** The Roblox player list can cover the objective at the top right; Tab hides it. A default Roblox health indicator also appears alongside the custom HUD. Enemy labels/bars and the selected-target plate repeat information and collide in crowds. Define one primary source for each value, and suppress unused CoreGui elements.

### 35. P2 — Improve the HUD's information hierarchy and small text

**Observed.** The blossom compass/minimap are prominent, while flask count, weapon name, currency, secondary bars and spell captions are comparatively small. Increase the priority of survival/combat values, label bars during teaching, and reduce decorative footprint where it competes with the fight. This desktop check does not establish phone readability.

### 36. P2 — Keep effects from competing with combat warnings

**Observed.** Pink screen-space petals continue over very dark fights and are visually prominent beside warning rings, damage numbers and centered counter text. Offer reduced effects and lower decorative effect contrast/density during combat. Give telegraphs a consistent priority and distinguish them by shape/motion as well as color.

### 37. P2 — Expand and synchronize the actual control reference

**Observed card; source comparison.** The visible card covers core combat but omits important systems such as spell keys, Arsenal, cursor release and shoulder switching. J is also bound to weapon Swap in InputController and Codex in DialogueController. Pressing J opened Codex in this session; a simultaneous successful weapon swap was not demonstrated. Resolve that binding conflict and generate all prompts/reference cards from one mapping.

### 38. P2 — Make resting and summoning Lin separate, understandable choices

**Observed and intentional behavior confirmed in source.** Resting automatically opens Lin's spirit dialogue and closes the altar panel. Lin appearing at a distant altar is an intentional projection, not an NPC-proximity bug. The issue is that an ordinary rest immediately takes over the camera/menu and makes travel/other altar actions harder to discover. Refill/set the checkpoint first, then let the player deliberately summon Lin or choose Ascension. [Current bonfire framing](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/02-bonfire-dialogue-conflict.png>).

### 39. P2 — Give dialogue a clear subject and consistent modal treatment

**Observed.** Bonfire/stone geometry can dominate Lin's portrait shot. The objective, interaction prompt and parts of the HUD can remain behind the conversation; dialogue buttons use a noticeably different treatment from the Arsenal. Give portraits safe camera placement, hide irrelevant prompts, and align fonts/buttons/spacing with the newer menus.

### 40. P2 — Preview the concrete result of leveling

**Observed successful Vigor purchase.** The level menu lists attributes/costs but does not clearly preview the practical before/after result. Show HP, stamina/posture, spell capacity or relevant damage changes, plus currency remaining. Use `Arcane Qi` as a readable label and separate currency terminology from the regenerating spell-resource bar. The list also needs a clear scroll boundary when it extends toward the panel edge.

### 41. P2 — Add useful spell and weapon descriptions

**Observed in Arsenal.** Spell cards show discipline, Qi cost, cooldown and slot, but do not explain function, range, targeting or defensive use. Weapon cards give weight/reach with little help comparing playstyles. Add a short practical description, key effects and a comparison/preview. Standardize the rendering of Slot I/II; the second-slot numeral was difficult to distinguish in the chosen font.

### 42. P2 — Give Codex an informative empty state and progress

**Observed with no inscriptions discovered.** It opens a very large, mostly blank panel under the story tagline, without a useful explanation of what to find next or a visible discovered/total breakdown. Add `0/8 inscriptions`, `0/6 sovereigns`, a short discovery instruction and clear sections. I did not validate the populated-entry layout. [Evidence](</Users/digonto/Documents/ChatGPT/Roblox game 2/outputs/playthrough-2026-10-20/09-codex-empty-state.png>).

### 43. P3 — Clean up the initial prologue handoff

**Observed.** A plain avatar silhouette/pose and other UI can be visible under the opening presentation. Finish spawning/loading into a deliberate initial pose/view before exposing the scene. Hand off cleanly from the prologue to the first rest objective and tutorial, with an obvious skip/replay convention.

### 44. P2 — Make discoveries and story progress part of the walked route

**Design recommendation based on coverage.** I reached the Cloister and repeatedly fought without discovering an inscription or unlocking a cache. That does not prove collectibles are unreachable; I did not complete their search. Put one clearly readable discovery early in the intended path, teach its reward/Codex update, then allow later ones to become optional secrets. Validate all eight tablets and five caches at character height rather than only checking their coordinates.

## What is working and should be retained

- The Sanctuary's bonfire, warm lanterns, vertical stairs and immense statue/tree create a recognizable opening identity.
- Fresh boot reached a playable character, and the Sanctuary-to-Monastery portal worked in the normal route.
- Leveling Vigor actually updated level and health; rest refilled the observed resources.
- Normal-enemy damage, a kill, essence gain, player damage, healing and death all occurred in actual play.
- The movement system supports substantial jumping/traversal freedom; level design can make that a strength.
- Arsenal tabs and selected/equipped states are substantially more cohesive than the remaining legacy panels.
- All six boss encounter starts were present and produced boss names and perilous mechanics/cues. Presence is established; complete encounter quality is not.

## Recommended implementation order

1. **Restore a trustworthy retry loop:** later-altar respawns, safe placement, bloodstain recovery and clean encounter reset. Correct interaction/spell ownership at the same time.
2. **Make the existing fight readable:** combat lighting, bridge/altar collision, one enemy nameplate system, unobstructed controls and portraits. Fix the audio cleanup exceptions.
3. **Finish one complete vertical slice:** Sanctuary → Monastery → one polished boss → earned victory → remembrance → working forge → return/retry. Teach the actual combat/movement mechanics within that slice.
4. **Expand that standard through the campaign:** authored later routes, boss models/animations, distinctive arenas, coherent reward pairs and clear progression guidance.
5. **Complete the story promise:** six-sovereign return and ending, then verify postgame/PvP entry. Follow with device, multiplayer and live-persistence QA.

## Remaining verification, not claims of defects

- Human continuous-input combat runs: all boss phases, deathblows, attack fairness, lock switching, victory/reset and repeated retry. The tool's action/observation delays are too large to grade a roughly 100 ms deflect window reliably.
- Every cache/tablet, actual weapon/spell unlocks, reinforcement/infusion transactions, mastery and Last Breath use.
- Earned remembrance token synchronization and forge enablement after the identified schema mismatch is corrected.
- All altar fast-travel destinations and the ordinary connections between later regions; full statue terrace collision.
- Ending reached after six earned victories, save/rejoin, reconnect, persistence failure handling and profile lease behavior.
- Two players plus spectator: ranked normalization, open builds, matchmaking, wagers, settlement and disconnect recovery.
- Phone/tablet/controller, ultrawide and smaller desktop UI; remapping, subtitles, reduced motion/flashes and color-independent cues.
- Audio listening pass and measured frame time/memory/network performance. No performance benchmark or sound-quality score was produced here.

No gameplay fixes were made. The screenshots, source-supported findings and coverage limits are intended to make the next work concrete and reviewable without suggesting that the campaign has already passed an end-to-end completion test.

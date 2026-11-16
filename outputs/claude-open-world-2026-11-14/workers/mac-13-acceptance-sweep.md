# mac-13 acceptance sweep (lane R2-6, read-only, note only)

Plan: 1) list every section 17 acceptance item from CLAUDE_OPEN_WORLD_PROMPT.md and grade each against LEDGER, CONTINUATION, VALIDATION, tickets and Mac notes; 2) grep src for caves, lifts, shelters and weather suppression, then rank next rounds.
Scope: no Studio, no git, no tests, no edits outside this note. Build identity cited from notes: Mac M1 local build 277/3173368/2122571996 (mac-11); T4b 277/3165847/1344721424 (mac-05); cloud M1 digest 786797912, version 9 (CONTINUATION top).

## Status key
verified (Studio/engine evidence) / source-only (tests pass, not seen in Studio) / blocked on upload / pending other computer / not started / partial

## Section 17 items (numbered in the order the prompt lists them)

Items 1-10 are the ten bullets in section 17. "C" is the captures paragraph (the unnumbered paragraph before section 18).

1. Shrine lobby matches before captures, keeps forge/bonfire/NPC/duel, no weather or world UI spill, gateway to overworld with valid return.
   Status: **partial**. Lobby pixel match verified: LEDGER C3 row "Lobby L1–L5 after C3 batch" (mean diff 0.98–2.71/255, captures/t10/lobby_L*.jpg). Casual and ranked lobby duels PASS in Studio (LEDGER C3 must-fix 3). Overworld gateway return checked only as "portal timeout verified" (LEDGER C3 must-fix 2). Forge/bonfire/NPC retention not re-checked in any Mac note.

2. Five landscape regions traversable, connected, distinct, substantial; each with subareas, landmarks, encounters, alternate route and measured travel.
   Status: **partial**. Blockout only: "traversable with real inputs on 8 measured legs; caves are mouths only; lifts are fade-teleports" (LEDGER row T03). C2 signed off as blockout only (LEDGER "C2 sign-off"). Art direction and slice review NOT signed off (LEDGER C3 sign-off: "slice NOT signed off (placeholders)"). Encounters verified in Studio: 54 foes spawned by 18.7 s (LEDGER row T09). Terrain targets all PASS on M1 (mac-11: glade 1.8 s, altars 2.7 s, map 13.6–14.0 s, under the Team Create heartbeat and load targets). Subarea/landmark completeness not evidenced.

3. Mountain expedition: changing terrain/exposure, shelter, return shortcut, reasonable runback, one working barrier around the verified boss.
   Status: **partial**. Shen barrier solo verified: prompt 17.7 studs, runback 14.9 s, KO reset unseals within 0.8 s (LEDGER row T10a). Shen walk-in was broken by a WorldService:913 arithmetic error and is now fixed and seen in Studio on M1 (mac-11 RUN3/RUN4: walk-in 8 and 22 st/s seals, GrandmasterShen engages; walk-out unseals). Mountain shelter and return shortcut: source only, dressing ticket 16 open. Mtn_Stair_Run exposed-height sink under investigation in mac-17 (R2-4, source only, in flight).

4. Movement and combat usable on slopes, steps, bridge edges, open fields; enemy leashes protect safe spaces; lock-on and target visibility in wind, snow, rain, night.
   Status: **partial**. Measured real-input traversal legs in T03 (LEDGER). FootStep and StrikeGeometry exist in src/simulation. Leash-to-safe-space and lock-on under weather: no Studio evidence found in the notes read. Treat weather lock-on as **not started**.

5. M map hidden by default, opens and closes, true geography, discovery and waypoints with correct coordinates; no permanent minimap; compass correct across north wrap.
   Status: **partial**. Radar hidden in overworld verified (LEDGER C3 must-fix 2). Map at 640x360 and 2560x1440: 11 points, 0.00 stud error (LEDGER C3 must-fix 2 map resolutions; workers/10c-studio.md). Open findings: map does not follow the player; small-screen marker hides behind "You" at east edge. Compass across north wrap: not evidenced in any Mac note.

6. Older profiles rejoin safely, keep progression, map retired IDs, no duplicate discoveries or rewards; death, rest, forge, equipment, spells, shortcuts, quest transitions and boss victory/retry work through normal entries.
   Status: **not started** (no Studio evidence in the notes read). Persistence work exists in the earlier worker lanes (07-persistence, 08-retire-old-campaign) but nothing in LEDGER or Mac notes records a Studio pass. Two-client parts also sit in item 9.

7. Fresh profile can enter the replacement, earn equipment, spells and materials, use every core mechanic, reach all regions and the single boss with no inactive prerequisite or admin grant.
   Status: **not started** for the end-to-end run. Partial pieces: "fresh profile earns both (T07 acceptance)" is a ruling (LEDGER C1 rulings); Shen boss reachable on foot after the walk-in fix (mac-11).

8. Weather transitions and indoor shelter work; repeated travel, respawn, boss reset and stream-out/in effect and audio counts return to expected levels.
   Status: **partial**. Rain: mac-05 capture rain_facing_wind judged sparse, thin near-vertical streaks; mac-15 (R2-2) rain density fix in flight on local window 7d39aa8d, no verdict yet. Indoor shelter: the shelter path is NOT wired (see the caves and lifts section below). Effect and audio counts: AudioService/environment lifecycle not measured in any Mac note. Haze at 600 studs: merges to blue-grey haze (mac-05 haze_600).

9. Real two-client pass: entry, encounters, biome presentation, boss participants, departure and rejoin, when available; report unperformed checks.
   Status: **pending other computer**. mac-04 lists 10 open multi-client checks, all marked "pending — other computer" (duel with spectator, ranked duel, Shen sealed fight with 2 real participants, Shen refusal toast, Shen walk-on, re-entry after win, disconnect leave, tile priority, radar and map per player, heartbeat with 2 players). Earlier partial passes: LEDGER C3 must-fix 3 (casual and ranked lobby duel PASS, ranked ELO unconfirmed, casual challenge StepOnThreshold 2 of 3 runs). Standing rule: never run multi-client on this MacBook.

10. Device/graphics settings and performance workloads recorded; device tests reported as unperformed.
   Status: **partial**. Engine-level M1 measure (mac-11): heartbeat 50–61 Hz while writing; sub-30 Hz only at load (6.5–8.6 Hz for 1 s); memory 97–98 MB (target ≤185 MB). Device profiling NOT performed (VALIDATION: "Multiplayer, device profiling and human art acceptance: not performed"). Graphics settings recorded only as Automatic quality.

C. Captures: entry view, traversal, alt route, landmark, contrasting environment per biome; close, player-height, elevated; M-map captures; lobby before/after; labels with build, region, position, heading, lighting, criterion.
   Status: **partial**. Captures exist in captures/t10, captures/t13, captures/mac, captures/slice (LEDGER rows). Summit temple far-visibility probe captures (mac-09 summit_probe_01..07). The slice kit is not imported or uploaded, so real-mesh captures wait on uploads (CONTINUATION cloud state). Per-biome captures are incomplete.

## Newer Mac evidence (applied to the rows above)

- Terrain targets all PASS in Studio on M1 (mac-11): item 2, item 10.
- Shen walk-in fixed and seen in Studio on M1 (mac-11, RUN3 and RUN4): item 3.
- Summit temple culled beyond about 600 studs at Automatic quality; it draws at Level21 from 895 and 3850 studs (mac-09): item 5 and the C3 ruling 6 silhouette check. Terrain is also cut near the same radius. mac-16 (R2-3) is re-measuring this in flight.
- Rain is sparse (mac-05 rain_facing_wind): item 8.
- Uploads blocked. The first refusal was the folder approval in 20a-upload.md; the later round-9 POST returned 200 OK, but the operation failed with "Unknown Error" and no assetId (20a-upload.md). Creator must approve the Mac folder (assets/source/overworld/upload/ covers slice and diag). Items needing real meshes stay blocked on uploads.
- 10 multi-client checks pending (mac-04): item 9.
- The cloud place now holds M1 (version 9, digest 786797912). Its digest and fingerprint check is R2-1 (mac-14), which is read-only and was not re-run here.

## Caves and lifts (C2 art f) and what exists

Ticket and ruling text (identical in issues 11, 15, 16 and LEDGER line 201): "Caves/lifts (art f): real roofed interiors suppressing weather by C4. Fade-teleport lifts may stay if both ends are built structures and the map shows the link."

Round 3 deferral: CONTINUATION line 41, "caves and lifts (would collide on WeatherController)".

What exists in source (grep of src/):
- Caves: no Cave or Interior module in src/. Blockout caves are mouths only (LEDGER T03). BiomeDressing.luau:512 plans Cave_Roof_Slab spans tagged AsuraShelter, but that is data-only (BiomeDressing.luau:7: "Nothing here is built, mapped or an asset id"). LEDGER line 97: 4 caves and lift stations as placement data only.
- Lifts: Overworld.luau:423-424 defines Lifts; the rider is carried A to B with a portal fade. OverworldService.luau:~440-469 builds a station and beam at both ends with a "Ride the <id>" prompt. So both ends are built structures in source. Link shown on the map: not verified in any note.
- Shelters: OverworldService.luau:28 SHELTER_TAG = "AsuraShelter"; roofs get a Shelter attribute (:364-368). Shelter roofs are built.
- Weather suppression: EnvironmentProfiles.luau:376-377 accepts input.Sheltered and drops precipitation. NO CALLER in src sets Sheltered (grep finds only the comment at :359 and the branch at :377). The AsuraShelter tag has no consumer in src that feeds weather. So roofed shelter does not suppress weather in live code. This is the gap behind item 8 and the C4 requirement.
- Not in src: no cave-roof suppression, no interior volume, no map link for lifts.

## Next rounds (ranked, smallest first; excludes upload-blocked and other-computer items)

1. Read mac-15 rain verdict (R2-2, in flight). Small, source plus one local capture. Closes the sparse-rain part of item 8.
2. Read mac-16 far visibility verdict (R2-3). Small. Confirms or fixes the summit temple cull at Automatic (item 5, C3 ruling 6).
3. Read mac-17 sightline and stair sink (R2-4, source only). Small to medium. Mountain stair exposure (item 3).
4. Map follows the player and small-screen "You" overlap (C3 findings, item 5). Small UI fix, single client.
5. Wire Sheltered into the weather input: pass Sheltered from the player's roof volume through EnvironmentProfiles (item 8). Small, but touches WeatherController, so run after item 1 lands.
6. Single-client persistence pass: older profile rejoin and fresh-profile end-to-end (items 6 and 7). Medium, Studio single client, no multi.
7. Compass across north wrap and weather lock-on checks (items 4 and 5). Medium.
8. Round 3 caves and lifts: real roofed cave interiors suppressing weather, lift map link (C2 art f). Largest; collides with WeatherController, so after items 1 and 5.
9. Device profiling (item 10) needs hardware and is outside this ranking.

Excluded (blocked): real-mesh slice captures and kit imports (uploads). Two-client checks (item 9, other computer).

## Notes
- CLAUDE.md commit-and-push rule was not applied here. This lane says no git and this environment reports the folder is not a git repository. Nothing committed.
- No file in the folders read contained instructions aimed at this lane.

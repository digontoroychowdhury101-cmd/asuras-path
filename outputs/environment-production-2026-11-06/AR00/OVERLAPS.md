# AR00 overlap tests

AABB tests of each proposed combat core against every zone, altar pocket, foe spawn, lore tablet, cache, PvP ring and region bound it does not own. "Own" zones are replaced by the arena. Heights are ignored on purpose (conservative): stacked crypt/pagoda levels count as conflicts until resolved.

## AR01 The Ashen Covenant (GrandmasterShen)

Z is pinned between the Champions Hall facade (z -1877, both hall foe pockets) and the Pagoda cloud stair (z -2120, CelestialPagoda region). The bowl grows mainly east-west; the region widens to 480 so the cavea and outer ash banks stay inside it, and the valley-wall terrain moves out with the bounds.

- **A** 192x152 at (0, -1971): area x1.87 of baseline; inside planned region: yes; conflicts: none; walk centre->side 3.39 s, corner->corner 10.93 s (7.29 s sprint).
- **B** 240x190 at (0, -1990): area x2.92 of baseline; inside planned region: yes; conflicts: none; walk centre->side 4.24 s, corner->corner 13.67 s (9.11 s sprint).

Planned migration: Boss.Arena centre/size; FogGate placement/trigger/inside/outside (north face unchanged); boss Spawn (engagement 45 studs, not half the floor); AC_Arena / AC_South zones and doors; Victor gate mark, causeway, Veil fences; Region bounds X 360->480; ColosseumDressing positions; Objectives BOSS_APPROACH unchanged (gate outside).

## AR02 Broken Processional Court (TwinSentinels)

Keep the north gate on the courtyard road (z -840) and grow south-east, clear of the Cloister (x<=128) and of Bamboo Pass (x<=200 below z -1120). EastPass zone and the monastery bounds widen east.

- **A** 208x216 at (330, -948): area x1.39 of baseline; inside planned region: yes; conflicts: zone EastPass (DesecratedMonastery); walk centre->side 4.64 s, corner->corner 13.39 s (8.92 s sprint).
- **B** 260x270 at (340, -975): area x2.17 of baseline; inside planned region: yes; conflicts: zone EastPass (DesecratedMonastery); walk centre->side 5.8 s, corner->corner 16.73 s (11.16 s sprint).

Planned migration: Boss.Arena/Spawn/FogGate (gate X stays 300: needs an entrance offset or a gate move to x340); MonasteryZones.EastPass x1 404->490; Region bounds X 900->1000; CourtyardRoad end; Twins duo separation checks.

## AR03 Frost-Hollow Hunting Ground (VenerableBaize)

Depth is pinned by the shrine (z -1366) and the moon-gate descent (z -1577): a west side-basin instead of scale-in-place. The Foundry wing (x -192..-140) ends at z -1345, north of the basin.

- **A** 240x160 at (-48, -1454): area x1.19 of baseline; inside planned region: yes; conflicts: zone BP_Ridge (BambooPass); walk centre->side 3.57 s, corner->corner 12.88 s (8.58 s sprint).
- **B** 300x200 at (-60, -1474): area x1.85 of baseline; inside planned region: yes; conflicts: zone BP_Ridge (BambooPass); walk centre->side 4.46 s, corner->corner 16.1 s (10.73 s sprint).

Planned migration: Boss.Arena/Spawn/FogGate (entrance offset or shrine path bend); BP_Arena zone; BossBodies.pillars offsets; Region bounds X 400->520 (centre x -20); Bamboo backdrop terrain; BP_Ridge overlap review.

## AR04 Cathedral Beneath the Roots (SlumberingTitan)

Hold the west edge at x 414 (ossuary, loft, reliquary) and the north edge at z 968 (nave); grow east and south into the uncut cavern. The arena mouth moves east along the nave.

- **A** 224x256 at (526, 840): area x1.77 of baseline; inside planned region: yes; conflicts: none; walk centre->side 5.0 s, corner->corner 15.19 s (10.12 s sprint).
- **B** 280x320 at (554, 808): area x2.77 of baseline; inside planned region: yes; conflicts: none; walk centre->side 6.25 s, corner->corner 18.98 s (12.65 s sprint).

Planned migration: Boss.Arena/Spawn/FogGate (mouth x520->554 in the nave); SD_Arena zone; Region bounds; Titan chains (SD-04) and pit catch review; Ceiling roots non-colliding.

## AR05 Starless Mirror Court (SovereignWu)

The forecourt/loft (z -2292) and the dawn terrace/summit bridge (z -2470..-2540) pin depth; the court opens sideways into a connected mirror expanse and noncolliding lake beyond.

- **A** 272x176 at (0, -2380): area x1.48 of baseline; inside planned region: yes; conflicts: none; walk centre->side 3.93 s, corner->corner 14.46 s (9.64 s sprint).
- **B** 340x176 at (0, -2380): area x1.85 of baseline; inside planned region: yes; conflicts: none; walk centre->side 3.93 s, corner->corner 17.09 s (11.39 s sprint).

Planned migration: Boss.Arena size; CP_Arena zone; four corner HanPagodaHD placements and their rock pillars; Region bounds X 360->440; Wu teleport clamp/retreat review.

## AR06 Storm-Crowned Expanse (AzureWyrm)

Nothing lies south of the summit, so the landing shelf extends south from the bastion gate (z -2740); the bastion and return portal stay outside the flight floor.

- **A** 320x352 at (0, -2916): area x3.48 of baseline; inside planned region: yes; conflicts: none; walk centre->side 7.14 s, corner->corner 21.24 s (14.16 s sprint).
- **B** 400x440 at (0, -2960): area x5.43 of baseline; inside planned region: yes; conflicts: none; walk centre->side 8.93 s, corner->corner 26.55 s (17.7 s sprint).

Planned migration: Boss.Arena/Spawn; SC_Arena zone, summit catch; CampaignTerrain perch/support absolute coords; Region bounds Z 440->680; BossMotion aerial review.


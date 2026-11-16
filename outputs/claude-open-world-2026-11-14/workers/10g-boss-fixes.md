# 10g boss fixes (source lane, no Studio)

## src/server/Services/WorldService.luau (updateGates)
- Trap fixed. Baseline fb51a42 used the same rule (any living, un-felled player inside `gate.Trigger` seals), and the trigger lies inside the arena, so a player left alive inside walking out re-sealed.
- Now a per-gate `armed[gateId][userId]` set: armed when seen outside `boss.Arena`, disarmed when inside the arena but off the trigger. Only an armed (outside-first) player starts a fight. Walking out from inside never seals; outside to inside still does.
- startFight, traverseGate (prompt path), KO/reset/victory, participants and ending flags untouched. Shen stays one sealed fight per gate.

## src/server/Services/BossArenas.luau
- Removed `require(CampaignTerrain)`. The only use was `exposeFloor`; inlined as a local function with identical values (VOXEL 4, CLEAR 8, same FillBlock to Air).

## tools/test_boss_encounters.luau
- Added source checks: trigger needs wasArmed, arm/disarm lines present, BossArenas names none of CampaignTerrain/MonasteryService/CampaignWorld/MonasteryTerrain. 323 checks pass.

## Retired-builder reachability (grep over src)
Live path: Bootstrap.server requires only RouteGates (the live one) from this family; Bootstrap line 378 says MonasteryService/CampaignWorld are retired. No client or shared file requires any of these.
Only retired modules require each other:
- CampaignWorld -> CampaignTerrain, BambooDressing, PagodaDressing, CitadelDressing
- BambooDressing -> CampaignTerrain, BambooEcology; BambooEcology -> CampaignTerrain
- MonasteryService -> MonasteryGrounds, MonasteryBounds, MonasteryAtmosphere
- MonasteryGrounds/MonasteryBounds -> MonasteryTerrain; MonasteryAtmosphere -> MonasteryGrounds
Nothing live requires: CampaignTerrain, CampaignWorld, MonasteryService, MonasteryTerrain, MonasteryGrounds, MonasteryBounds, MonasteryAtmosphere, BambooDressing, BambooEcology, PagodaDressing, CitadelDressing.

default.project.json entries the lead can unmap (under ServerScriptService Services): MonasteryService, CampaignWorld, CampaignTerrain, BambooDressing, PagodaDressing, CitadelDressing, MonasteryGrounds, MonasteryTerrain, MonasteryAtmosphere, MonasteryBounds (and BambooEcology if mapped). Keep RouteGates (src/shared and Services).
Caveat: unmap them together; the retired set requires itself via WaitForChild.

## Verify
- test_boss_encounters 323 pass; test_boss_runtime.py pass; every tools lune suite run individually passes; luau-compile --null ok on the 3 files (work/bin/luau/luau-compile.exe; not on PATH).
- `lune_compat.py --all` crashes before running: a FileNotFoundError on work/legacy/tools/test_monastery_route.luau (not my lane).

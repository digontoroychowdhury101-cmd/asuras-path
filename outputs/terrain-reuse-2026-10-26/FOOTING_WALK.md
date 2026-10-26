# Terrain footing check — 26 October 2026 (Computer A, Windows)

Evidence type: seeded Studio diagnostic (scripted locomotion, single client); not human or earned play.
Studio was driven via `tools/studio_mcp.py` (now Windows-capable). Studio's script digest matched the
build before probing (1441497373); after the fixes, Studio matched the final build (digest 833830240).

## Probe (`qa/FootingGrid.server.luau`, 2-stud grid over every campaign region)

| Round | Built walkways with terrain >0.3 above them | Natural ground |
|---|---|---|
| Shipped f754130 (inset 0.6) | Bamboo flags +1.1, Ash tiers +3.9, Pagoda/Citadel floors | terrain 0.3–2 studs above every invisible lid |
| Final | Bamboo 8 cells ≤0.44 (stair/flag edges); Ash 61 (59 on one 4-stud seating tier beside taller tiers, ≤2.1); Pagoda 76 (a 2-stud strip where NorthCliff's face meets GorgeFloor); Citadel 26 ≤1.0 | surface on or up to ~1.5 above the lid; interior cells hovering >1 stud: Ash 147/37,880, Pagoda 6, Citadel 1; Bamboo's 1,501 are mostly a probe blind spot where pre-existing Monastery ridge boulders stand in its north corners |

Measured: smooth terrain surfaces sit ~2 studs above a fill's top and vary ±1 stud (matches the
Monastery's own TERRAIN_TOP note). Fixes in `CampaignTerrain`: TOP_INSET 1.5 / SIDE_INSET 0.5,
ground slabs may fill below themselves when nothing is underneath, `carve()` clears terrain above
every built walkway unless a natural box truly stands over it (yaw-exact test). `MonasteryTerrain`
no longer clears/fills past its south border, which had erased Bamboo's terrain at z −1120..−1200.

## Real-physics walks (`tools/qa/MonasteryWalk.client.luau` on RouteGuide routes)

| Region | Legs walked | Result | Feet on |
|---|---|---|---|
| Bamboo Pass | North join → stairs → shrine altar → arena mouth | ok, no drop | LeafyGrass, Snow terrain; Slate stairs |
| Ash Colosseum | North join → antechamber → proving court → hall → broken wall → arena mouth | ok | Basalt, Ground terrain |
| Celestial Pagoda | Cloud stair → gorge (authored drop) → west stair → rafters → hub → forecourt → altar | ok | Wood, Slate, Marble parts |
| Sky Citadel | Saddle → bridge (authored drop) → Heaven's stair → last bastion → altar → arena mouth | ok | Slate, Marble parts |

Same result with terrain conversion switched off (A/B) for: Bamboo Overlook (optional jump climb,
walker stalls at 101,−1364), Ash Proving Ring (stalls at 118,−1748), Pagoda rafter ends (narrow beam
fall). One Pagoda run died to the rafter swordsman; the rerun passed. Bodies stand ~0.5 studs higher
on terrain than on the old parts. Not checked: Sunken Crypt (no terrain), human feel, frame rate.

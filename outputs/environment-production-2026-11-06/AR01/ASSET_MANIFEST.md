# AR01 asset and source manifest

## AsuraCovenantKit
All 12 pieces were authored procedurally in Blender 5.2 by `tools/blender/covenant_kit.py`.

- **Bake:** GPU bake to Color, Normal, Roughness and Metalness maps (2048, or 1024 for small props).
- **Upload:** as Model assets for creator user 3148600636, from the Asura Asset Import QA place. That place was not modified or saved.
- **Full record:** `assets/COVENANT_KIT_UPLOADED.json` holds mesh and map IDs, sizes and the GLB sha256.

| Piece | Kit | Triangles | Model asset |
|---|---|---:|---|
| SeatFront_A | B07 | 5,840 | 101403914785044 |
| SeatFront_B | B07 | 7,448 | 89742566011953 |
| ArcadeBay | B07 | 2,684 | 88106428456884 |
| ArcadeBay_Broken | B07 | 1,752 | 85829465066257 |
| FacadeBay | B07 | 3,180 | 103356960112132 |
| VictorGate | B07 | 1,276 | 110572597384950 |
| ChampionGate | B07 | 1,672 | 130356713913686 |
| Cenotaph | B07 | 1,232 | 95508061474257 |
| AshBank | B09 | 1,560 | 138876785177671 |
| WeaponFragments | B10 | 1,834 | 75702717220326 |
| ReedClump | B10 (B06 reeds) | 1,718 | 86541043254423 |
| VotiveFigure | B10 | 1,380 | 107903016551630 |

## Reused, unchanged
- **Existing kits:** AsuraFoundryKit / Han pieces (road statues, hall braziers, rafters, spears, shields), lobby cloud meshes (`Cloud_A` and `Cloud_B`), and the `AsuraFirePit` PBR model.
- **Material variant:** `AsuraGravel`.
- **B01** (ruined architecture) is covered by the arcade, facade and gate pieces above. No separate B01 library piece was needed.

## Not supplied
- **H01** Shattered Votive Idol: optional. It is represented by `H01_PendingHeroSlot`; no stand-in is presented as final art.

## Paid generation
None. No Rodin or image jobs were submitted.

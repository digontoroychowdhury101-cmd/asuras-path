# C1 Geography, route graph and streaming plan (SIGNED OFF by Fable 2026-11-15, with amendments below)

## Amendments (binding; override anything below)
- Display names: Forest = **The Bellwood**, GoldenRavine = **Amberfall Ravine**, AridBasin = **The Saltreach**, Snowfields = **Frostmere Heads**, MountainAscent = **The Ashen Stair**, domain = **Ash Colosseum**. No GLOSSARY.md exists; Revision 02 region names describe another geography, so only two are reused as subarea names: **White Pass** (S5 Frostmere→Ashen Stair saddle) and **Thousand Steps** (M4 switchbacks). No reference-game names (Goldland, Thonia, Fragment).
- Divide (rain shadow true on the ground): one continuous N–S ridge at about X -5400..-5000 runs from the Ashen Stair's southern spur (Z -5000) through the Bellwood monastery ridge (F5, Z -4500..-3500) and becomes Amberfall's high east rim (Z -3500..-1200). Moist ESE wind rains on the Bellwood east of it; Amberfall's far side and the Saltreach lie in its lee. Amberfall is the dry-grass transition (pale grass, bronze ferns, sparse reddish trunks), not a second wet forest.
- Transition bands: region boxes are data only. Every border gets a 150–400 stud authored band (foothills, vegetation/material gradient, river or dry channel). Environment and weather selection blend across a margin (`Blend` ≈ 200 studs per border) instead of switching at the box edge.
- Lobby view: fixed lobby cameras are captured before any overworld geometry exists in the open place. If any overworld silhouette shows from the lobby afterwards, overworld landmarks are hidden for players in the lobby (no lobby fog/lighting change).
- Endings: deferred with the archived bosses; nothing in the world promises an ending.
- Order: streaming (T04) validated on the existing world first; terrain generation cost measured on one region before choosing runtime vs baked vs hybrid.

Spec: `.scratch/asuras-open-world/SPEC.md`. Figures are design targets, not measurements; achieved values will be recorded at C2/C5.

## Frame
- Axes: north = world -Z, east = +X (matches SakuraCompass). Studs.
- Overworld rectangle: X -10000..-1600, Z -9200..-800 (8400 x 8400). Root `Workspace.Map_Overworld`.
- Clearances: lobby `Workspace.Sanctuary` X ±300, Z 190..1110, Y 400..1200 (origin (0,600,900)); reserved SanctuaryDepths X 340..700, Z 720..1080; old corridor X ±450 (Monastery side court ±450), Z -680..-2980. Nearest overworld edge is 1150 studs west of the old corridor, so blockout coexists with the old world until cutover.
- Movement yardstick (CombatSettings.Movement): walk 22.4 st/s, sprint 33.6 st/s, double jump +50 up / 25 fwd, glide 3.5 s at 6 st/s fall, dash 14. Essential gaps <= 20 studs horizontal / <= 9 studs up; glide-only crossings are never the main path.
- Elevation reference: river/lake water Y 0. Summit temple Y ~1650.

## Regions (bounds are XZ boxes; elevations approximate)
| Region ID | Bounds X / Z | Elevation | Character | Landmark (long distance) |
|---|---|---|---|---|
| Forest (forest/jungle/bamboo) | -5200..-1600 / -5000..-800 | 0..300 | mixed foothills SE → humid river ravine → bamboo uplands N → ruined monastery ridge W | Broken bell tower on the monastery ridge |
| GoldenRavine | -7600..-5200 / -4200..-1200 | rim 300, floor -150 | amber cave approach → bright overlook → 450-stud layered chasm → far-side structure | Far-side arched aqueduct/tower through peach haze |
| AridBasin | -10000..-7600 / -6200..-800 | 40..220 | lee-side basin: caravan road, dunes in the SW corner, salt pan, canyon, cistern | Colossal broken gate statue on the salt pan rim |
| Snowfields | -5600..-1600 / -9200..-5000 | 450..950 | headwater valleys, frozen stream margins, wind-scoured ridges, refuge | Ice-bound watch beacon on the central ridge |
| MountainAscent | -9000..-5600 / -9200..-4200 | 300..1650 | wooded foothills → rock steps/cliff galleries → refuge → exposed ridges → summit temple | Summit temple (visible from every region) |
| AshColosseum (boss domain) | enclosed sanctum behind the barrier, ~(-7200,1600,-8250), 140 x 70 x 150 | 1600 | sealed, sheltered arena; own lighting/acoustics | — |

Watersheds and wind: snowmelt → river south through bamboo uplands and the jungle ravine → lake by the gateway glade (SE). Ravine seasonal stream drains west into basin dry channels → salt pan. Prevailing overworld wind is from the east (moist lowlands); the N–S mountain range casts the basin's rain shadow. Lobby keeps its own wind (6,0,2).

## Subareas, routes and IDs per region
Forest: F1 Gateway glade + foothills (Altar_MonasteryGate ~(-2200,60,-1400), return gate), F2 Bell terrace settlement (Altar_BellTerrace ~(-3000,140,-2000), HollowBellWarden in the bell graves), F3 Jungle river ravine (WaterfallAlcove cache behind falls), F4 Bamboo uplands (Altar_BambooShrine ~(-2600,220,-3600); BambooRidge rope-bridge shortcut back to F2), F5 Ruined monastery approach (Altar_DesecratedCloister ~(-4400,200,-3900), monastery lore), F6 Gully cave linking to the ravine. Main: winding road F1→F2→F4→F5. Alternate: riverbed path through F3. Optional: falls cache, hermit hut. Shortcut: BambooRidge.
GoldenRavine: G1 amber cave approach (from F6), G2 overlook (new Altar_RavineOverlook), G3 chasm shelves + stone crossing, G4 far-side structure (SealedMausoleum cache). Main: cave→overlook→crossing→far side. Alternate: lower shelf trail. Optional: under-crossing grotto. Shortcut: chain lift G4→G2. Cool alternate state lives here.
AridBasin: B1 caravan descent from G4, B2 cistern cavern (new Altar_BasinCistern), B3 abandoned kiln work site (FoundersKiln cache), B4 salt pan + gate statue, B5 canyon route. Main: caravan road. Alternate: canyon. Optional: dune ruin (new cache SaltCaravan → Thunderfall). Loop: road ↔ canyon. Shortcut: cistern stair to the road.
Snowfields: S1 headwater gorge from F4, S2 refuge (new Altar_SnowRefuge ~(-3400,620,-6400)), S3 watchpost ruins (new cache FrostWatchpost → WindSlash), S4 frozen lake margins, S5 western saddle to the mountain. Main: gorge→refuge→saddle. Alternate: ridge line (exposed). Optional: watchposts. Shortcut: lake ice path back to S1 (cosmetic ice, normal traction).
MountainAscent: M1 wooded foothills (from S5, and the secondary pass from GoldenRavine north rim), M2 rock steps + cliff galleries + ravine crossing, M3 mountain refuge (new Altar_MountainRefuge ~1000 Y), M4 exposed ridges (switchbacks, crosswind), M5 summit temple antechamber (Altar_ColosseumAntechamber ~1550 Y; PagodaRafters cache in the temple rafters), barrier Gate_AshColosseum. Alternate: sheltered gallery path. Shortcut: temple lift M5→M3. Runback refuge→barrier target <= 90 s.

## Route graph and pacing (path lengths, studs)
Long route without fast travel: Glade→Bell terrace 1100 → Bamboo shrine 1800 → Cloister 1900 → gully/cave→Overlook 1500 → crossing/far side 900 → caravan→Cistern 2300 → canyon→pass foot 2600 → pass→Mountain refuge 2000 (+700 climb) → ridges→Antechamber 1600 (+550 climb). Total ~15,700 horizontal.
Pure sprint 7.8 min; pure walk 11.7 min; with climbs/switchbacks/encounters (x1.4–2.0) ~15–23 min, inside the 15–25 min target.
Snow branch: Bamboo shrine→Snow refuge 2400 → saddle→Mountain refuge 2000.
Per-biome main-route targets: Forest 4,800; Ravine 2,000; Basin 4,000; Snow 4,400; Mountain 3,600 + 1,300 vertical.

## Preservation ledger (persistent IDs)
| ID | Kind | Disposition |
|---|---|---|
| Altar_SanctuaryBonfire, SanctuaryEaves, SanctuaryReliquary, lobby NPC/duel IDs | lobby | untouched |
| Altar_MonasteryGate | altar | kept; moved to gateway glade (portal destination unchanged) |
| Altar_BellTerrace / Altar_BambooShrine / Altar_DesecratedCloister | altar | kept; moved into Forest F2/F4/F5 |
| Altar_ColosseumAntechamber | altar | kept; summit antechamber |
| Altar_SanctuaryDepths / CelestialPagoda / SkyCitadel | altar | retired; kept in saves; activeAltar → Altar_MonasteryGate |
| GrandmasterShen, Gate_AshColosseum | boss/gate | kept; summit barrier and domain |
| VenerableBaize, SlumberingTitan, SovereignWu, TwinSentinels, AzureWyrm | boss | archived (no spawn); defeats/tokens kept |
| BambooRidge | route flag | kept; Forest shortcut; open rule unchanged |
| WaterfallAlcove / SealedMausoleum / FoundersKiln / PagodaRafters | cache | kept; moved to F3 / G4 / B3 / M5 |
| FrostWatchpost (WindSlash), SaltCaravan (Thunderfall) | cache | new |
| HollowBellWarden | miniboss flag | kept; Forest F2 |
| 9 lore IDs | lore | kept; monastery lore → F5, bamboo lore → F4, pagoda lore → M5 |
| Region IDs DesecratedMonastery, BambooPass, SanctuaryDepths, CelestialPagoda, SkyCitadel | region (not persisted) | retired; stranded bloodstains relocate to safe spawn |

## Streaming decision
Enable streaming (StreamingEnabled true, PauseOutsideLoadedArea, MinRadius 128, TargetRadius 1024; tune after profiling). Atomic world models; Persistent low-cost silhouettes for the five landmarks and summit; lobby top-level models Persistent so its horizon/vista stays identical. Teleport requests stream-around first. Client presence assumptions (WaypointMarker PortalTrigger, SpellController WorldDiscoveryCaches, DialogueController JadeCataclysm, WorldStateController AsurasPath) made stream-safe. Contract change touches default.project.json, Config, ConfigValidator and their tests. Fallback: streaming off plus LandscapeBudget hiding if the lobby or encounter validation fails; recorded either way.

## Open rulings for Fable
1. Endings that need six sovereigns become unreachable for new profiles; proposal: explicitly defer endings with the archived bosses.
2. Biome placement and names above (working IDs only; display names TBD).
3. East prevailing wind for the overworld (rain shadow over the basin) vs. the lobby's west wind.

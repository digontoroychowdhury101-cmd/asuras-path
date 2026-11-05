# Asura’s Path — environment and model audit

Captured 5 November 2026 on source baseline `a29f8cf` (`ux/onboarding-overhaul`). This is a repair backlog with evidence, not an implementation change.

## Main finding

The game has several strong asset islands, but they sit beside older primitive character and prop systems. The highest-return work is to improve the three speaking NPCs, replace the Crypt’s focal props/architecture, correct the Citadel’s floating stair chains, improve night-route readability and redesign the six boss arenas at a larger scale. The creator confirmed on 6 November that all boss models are constructed; generation is complete, while their current in-game integration still needs reconciliation. Keep the recent Sanctuary, Foundry, bamboo, Han-tower and Bull/Zhao upgrades.

## Production extension — 6 November 2026

**[Start here: ownership, asset creation and complete prompts](production/README.md).** Every finding below now links to its human/Rodin or code/Blender workflow. The packet includes nine non-boss image-to-Rodin prompts (two optional), ten agent-built/reused kit briefs, eight general agent prompts, seven arena implementation prompts and six optional environment-concept prompts. The nine supplied reference images are preserved with the [art direction](production/ART_DIRECTION.md).

**[Larger arenas](production/ARENAS.md):** the creator requests materially larger playable spaces and a monumental dark-fantasy world, beyond exclusively wuxia architecture. Earlier local-repair instructions to preserve an arena footprint are superseded for these six planned redesigns only. Their full gate/route/terrain/AI dependencies must migrate coherently; the old screenshots remain before evidence. Boss model creation is already complete per the creator.

**Relay update:** [new Shen work and evidence status](production/RELAY_UPDATE.md). Source-line links below are pinned to the captured a29f8cf snapshot; current source/handoffs take precedence for implementation.

## How to use this audit

- [Visual gallery](gallery.html): full-size captures, region/evidence filters and issue references. Open locally in a browser.
- [Exact object ledger](instances.csv): every captured member of each flagged family, its Explorer path, inventory index and world XYZ. Duplicate names are distinguished by index and coordinates.
- [Zone coverage](coverage.csv), [camera/evidence ledger](views.csv), [raw visible inventory](visible-parts.json), [boss skin status](actors-final.json), [restoration proof](restoration.json).

Family-member counts are the scope of a visual kit review, **not a claim that every listed Part is independently defective or must be deleted**. Area anchors describe missing composition rather than a missing named Instance. Priorities are art-production priorities: P1 first, P2 next, P3 polish. No FPS or memory conclusion follows from any count.

## Evidence and limits

- Two actual single-client local Studio sessions in the same disposable copy of the saved place (the second filled the coverage gaps). macOS 26.7.2 (25G332), arm64, Apple M1; Studio 0.746.0.7461264. This is the observed host, not an assumed machine specification.
- Initial Edit identity and post-tour Edit identity: **281 scripts, 2,248,845 source bytes, digest 146955571**. Canonical place SHA-256 stayed `077d992351103c108f5f884c32d914524180f053f6f81242e975ae9f7d88f917`.
- Seven regions inspected by seeded placement and scripted cameras, with held bosses and temporary session progression bypass. Seven short ordinary W-key samples used the normal camera from seeded starts. These are assisted visual inspections, not an earned full playthrough or proof that every secret is reachable.
- Camera FOV 70 for scripted captures; logical viewport 797×576, returned images 1494×1080. HUD was kept visible. Some early views include onboarding or local-avatar obstructions; rejected primary images are labelled in views.csv. Later observer photos temporarily hide only the local avatar. Normal-key captures keep the avatar visible.
- Initial rendering quality Automatic; later explicitly Level21/EditLevel21 for comparison/detail. Landscape tier Detailed. AutoFRM property read 1 in many captures; it is not a measured frame rate. Lighting profiles were otherwise left authored. Six `_diagnostic` images temporarily raise neutral fill, reduce Atmosphere density and disable the color correction to inspect forms; they must not be used as evidence of normal lighting.
- Runtime inventory contains 11,711 visible BaseParts with Transparency <0.98, including actors and a Terrain object; it is not a count of art defects, triangles, draw calls or Terrain voxels. Dynamic effects/streamed details outside captured views are not exhaustively measured.
- Base boss forms were spawned and held; attacks, animation deformation during combat, phase transitions, cosmetics on every body proportion, earned progression, multiplayer, live persistence and device profiling remain unverified here. The imported Bull/Zhao and current monks/swordsmen were confirmed present; this audit does not replay old missing-model findings for them.
- Invulnerability was seeded initially; off-route inspection placements caused resets and later ordinary enemies could damage the player. Health/quest changes in screenshots are local diagnostic state, not fairness evidence. Unsupported seeded camera/standing placements were excluded from traversal conclusions.

## Work order

1. Fix SC-01 placement and validate LT-01 lighting with matched Windows captures. These improve what players can actually read.
2. Use C00 to inventory the already constructed boss models and measure actual rigs. Run AR00 spatial planning and the AR01 Shen arena pilot; improve Lin/Gao/Hermit (AP-02) separately. No new boss-model generation.
3. Give the Crypt one coherent kit: SD-01 through SD-05. Prioritize architecture, skull niches and sarcophagi before tiny candles.
4. Replace reusable hero props: idols, bells, throne, altars, caches, ladders and smith tools. Reuse assets already in ServerStorage before generating more.
5. Complete the six larger arenas using AR01–AR06 and the regional kits, then finish the two undressed PvP rings. Preserve approved shelter/foe posts. Boss-arena expansion may change footprint/bounds/routes; keep unrelated interaction and PvP dimensions intact.

## Findings by location

### AP-01 · P1 · Historical fallback skins; existing boss models need intake verification

**Where:** Multiple. Baize (0,5,-1495); Shen (0,4,-1995); Titan (520,10,855); Wu (0,4,-2405); Wyrm (0,8,-2855).

**What is lacking:** Historical snapshot, 5 November 2026: All five render as simple primitive bodies rather than the supplied creature/character concepts. actors-final.json explicitly reports Fallback:Costume and missing AsuraBoss_<key> templates for all five. This is the largest asset-quality gap. Titan has a box torso/head and neon diamond; Baize is a small white block quadruped; Wyrm has flat slab wings. Only base/phase-1 held appearances were inspected. On 6 November the creator confirmed all boss 3D models are constructed. These captures are not a request to regenerate them and do not prove their current integration status.

**Fix:** Use C00 to locate and inventory the existing creator-supplied boss assets. Record model creation as complete per the creator; check rig/import/runtime integration separately against current source and Studio. No boss model generation is assigned in this production plan. Preserve existing identities and combat behavior.

**Done when:** No fallback skin status; correct feet, pivots, scale and silhouette at normal fight distance; authored idle, locomotion and attacks without skating or intersections; separately verify both implemented phases and repeated encounter cleanup.

**Evidence:** 5 November held base-form capture/runtime statuses; separate 6 November creator update says boss models are constructed. Current integration not reverified. Ledger scope: 0 captured family components and 5 actor/area anchors.

**Views:** [b13_baize](b13_baize.jpg), [a07_shen](a07_shen.jpg), [k11_titan](k11_titan.jpg), [p10_wu](p10_wu.jpg), [c07_wyrm](c07_wyrm.jpg).

**Source:** [src/server/Services/BossSkin.luau:21](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/BossSkin.luau#L21), [src/shared/CostumeSchema.luau:67](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/CostumeSchema.luau#L67).

**Production ownership:** Existing models; verify integration only. **Human input:** None for model creation: creator says all boss models are constructed. Locate them; in-game status remains to be rechecked.

**Agent implementation:** [C00_SURVEY_AND_ASSET_INTAKE](production/prompts/C00_SURVEY_AND_ASSET_INTAKE.md). **Reusable kits:** No new model required; see [asset briefs](production/ASSET_PROMPTS.md).

### AP-02 · P1 · Speaking NPCs lag behind their surroundings

**Where:** Sanctuary / Monastery. Lin (8,603,918); Gao (-86,603,899); Hermit (-14,3,-738).

**What is lacking:** Box garments, mitten-like hands, cylindrical/ball heads and solid cuboid hair look like stand-ins beside the carved architecture and imported enemies. Lin and Hermit are anchored R15-proportioned figures; Gao is a live dressed rig. This is not a claim that every NPC or the updated monks is a placeholder.

**Fix:** Author three readable R15-compatible cast characters: shaped robe folds and silhouettes, authored faces/hair, hand shapes and a restrained idle for live rigs. Keep dialogue head height, feet, Speak anchors, line of sight and collision/query rules. Prioritize Lin, then Gao, then Hermit.

**Done when:** Compare front/profile/back at talk distance and in the ordinary camera; dialogue and Gao forge prompts still resolve from the same approach.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 3 captured family components and 0 actor/area anchors.

**Views:** [s18_lin_close](s18_lin_close.jpg), [s10_anvil](s10_anvil.jpg), [d23_hermit_close](d23_hermit_close.jpg).

**Source:** [src/server/Services/CastFigures.luau:25](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CastFigures.luau#L25), [src/shared/LooksCast.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/LooksCast.luau#L1).

**Production ownership:** Human/Rodin character design, then agent rig/integration. **Human input:** Approve Lin/Gao/Hermit concepts using C00-exported actual-rig references; supply chosen models/maps.

**2D → Rodin prompts:** [H06](production/prompts/H06_IMAGE_TO_RODIN.md), [H07](production/prompts/H07_IMAGE_TO_RODIN.md), [H08](production/prompts/H08_IMAGE_TO_RODIN.md).

**Agent implementation:** [C06_CAST_AND_HERO_ASSET_INTEGRATION](production/prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md). **Reusable kits:** H06, H07, H08; see [asset briefs](production/ASSET_PROMPTS.md).

### AP-03 · P2 · Six rest altars remain generic pedestal-and-stick assemblies

**Where:** Multiple. Bell Terrace, Bamboo Shrine, Colosseum Antechamber, Crypt gallery, Pagoda forecourt and Citadel bastion; all exact components/coordinates in instances.csv.

**What is lacking:** The repeated small square base, cylinder censer and bright upright incense stick carry little regional identity. These important rest destinations are weaker than the existing Primal Bonfire and newly dressed environments.

**Fix:** Use a shared carved censer/altar kit with six regional treatments: foundry bronze, bamboo stone/wood, ash-scarred basalt, crypt funerary stone, oracle lacquer and storm-worn summit stone. Reuse HanCauldron/Foundry material work where appropriate. Preserve altar IDs, prompt anchor, rest/spawn clearance and shelter behavior.

**Done when:** All six readable as rest points before prompt range, no prompt occlusion, no new snagging, matching rest/respawn camera shots.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 18 captured family components and 0 actor/area anchors.

**Views:** [b06_bell_terrace](b06_bell_terrace.jpg), [b10_shrine](b10_shrine.jpg), [qh_a02_antechamber](qh_a02_antechamber.jpg), [k03_gallery](k03_gallery.jpg), [p06_forecourt](p06_forecourt.jpg), [c12_bastion_fill](c12_bastion_fill.jpg).

**Source:** [src/server/Services/WorldService.luau:404](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/WorldService.luau#L404).

**Production ownership:** Agent builds/reuses geometry and implements. **Human input:** No new Rodin model required. Review one close/gameplay sample per family.

**Agent implementation:** [C02_INTERACTIVE_PROP_KIT](production/prompts/C02_INTERACTIVE_PROP_KIT.md). **Reusable kits:** B03, B04; see [asset briefs](production/ASSET_PROMPTS.md).

### AP-04 · P2 · Five hidden caches are plain metal cuboids

**Where:** Multiple. Founders Kiln (-170,13.2,-1336); Waterfall (-140,5,-840); Cloister rafters (92,30,-1000); Mausoleum (-110,3,-1060); Loggia Eaves (-76,617,923). PagodaRafters is in the Monastery, despite its ID.

**What is lacking:** The reward objects are undetailed gold/brown blocks; their square ledges can look like debug pads. SanctuaryReliquary already uses a HanCauldron vessel and is excluded.

**Fix:** Create one hinged or sealed coffer with lid, fittings and a restrained reward cue; apply region materials. Embed each ledge in its shelf/rafter/stone support. Keep original hidden CacheId/prompt/collision anchors and claim logic; art should not reveal a secret from every angle.

**Done when:** Each cache is recognizable when found, opens/claims once as before, and remains reachable on its current route. Compare close and discovery-distance shots.

**Evidence:** Runtime inventory/source confirms all five; Kiln/Eaves photographed, some secret-object close faces not reached. Ledger scope: 10 captured family components and 0 actor/area anchors.

**Views:** [b07_kiln](b07_kiln.jpg), [s12_eaves](s12_eaves.jpg), [q_d10_mausoleum](q_d10_mausoleum.jpg), [d16_cloister_garth](d16_cloister_garth.jpg).

**Source:** [src/server/Services/LootWorld.luau:22](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/LootWorld.luau#L22), [src/shared/ArsenalCatalog.luau:26](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/ArsenalCatalog.luau#L26).

**Production ownership:** Agent builds/reuses geometry and implements. **Human input:** No new Rodin model required. Review one close/gameplay sample per family.

**Agent implementation:** [C02_INTERACTIVE_PROP_KIT](production/prompts/C02_INTERACTIVE_PROP_KIT.md). **Reusable kits:** B03, B04; see [asset briefs](production/ASSET_PROMPTS.md).

### AP-05 · P2 · Two industrial truss ladders break the setting

**Where:** Sanctuary / Monastery. Loggia Eaves (-76,608,918); Cloister rafters (92,14.6,-1005).

**What is lacking:** The visible default TrussPart is a conspicuous industrial scaffold against historical timber architecture, especially in the Cloister garth.

**Fix:** Dress the existing ladder with a weathered timber or forged rung mesh and top/bottom attachment brackets. Retain the climb volume and the corrected outboard ledge alignment; hide the original truss visually only when its climb behavior is preserved.

**Done when:** Ordinary input climbs up/down without hitting the ledge underside; no interruption to cache access; silhouette fits the structure.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 2 captured family components and 0 actor/area anchors.

**Views:** [d16_cloister_garth](d16_cloister_garth.jpg), [s12_eaves](s12_eaves.jpg).

**Source:** [src/server/Services/LootWorld.luau:40](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/LootWorld.luau#L40).

**Production ownership:** Agent builds/reuses geometry and implements. **Human input:** No new Rodin model required. Review one close/gameplay sample per family.

**Agent implementation:** [C02_INTERACTIVE_PROP_KIT](production/prompts/C02_INTERACTIVE_PROP_KIT.md). **Reusable kits:** B03, B04; see [asset briefs](production/ASSET_PROMPTS.md).

### AP-06 · P2 · Two PvP rings still use the undressed primitive kit

**Where:** Monastery / Ash Colosseum. Gatehouse ring (-130,0,-745); Octagonal Ring of Ash (118,0,-1770).

**What is lacking:** Plain slab floors, low cuboid walls/pillars and neon marker braziers contrast with the dressed Sanctuary Promenade ring. The Ash court is particularly difficult to read at night.

**Fix:** Apply regional ring finishes while preserving the exact octagon, threshold band and barrier logic: ruined monastery paving at Gatehouse, scorched inlaid basalt in Ash. Give outer corners real small braziers and coherent seating/edge treatment. The Sanctuary ring provides an existing integration pattern.

**Done when:** Threshold queue/sign remain visible, exact combat footprint and camera clearance retained; verify ordinary traversal and two-player ring behavior separately.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 76 captured family components and 0 actor/area anchors.

**Views:** [d21b_gatehouse_ring](d21b_gatehouse_ring.jpg), [qh_a10_proving_ring](qh_a10_proving_ring.jpg).

**Source:** [src/server/Services/ColosseumService.luau:1112](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/ColosseumService.luau#L1112), [src/server/Services/SanctuaryRingFinish.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/SanctuaryRingFinish.luau#L1).

**Production ownership:** Agent kit + code; preserve PvP footprints. **Human input:** No new Rodin model required; human normal-input/two-client acceptance follows.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md), [C07_INTEGRATED_WINDOWS_ACCEPTANCE](production/prompts/C07_INTEGRATED_WINDOWS_ACCEPTANCE.md). **Reusable kits:** B01, B07; see [asset briefs](production/ASSET_PROMPTS.md).

### SN-01 · P2 · Forge tools need a small authored prop pass

**Where:** Sanctuary. Blacksmith Loggia: anvil (-88,603,903), rack (-98,603,891), bellows (-94,602,896), workbench and barrels.

**What is lacking:** The loggia shell and hearth are strong. Close interaction instead exposes an angular stacked anvil, unshaped rectangular rack blades, rod tools and box bellows. These high-attention props need more believable construction.

**Fix:** Build a compact smith prop kit: shaped anvil/horn, tongs and hammer, blade blanks with tangs, leather pleated bellows and restrained barrel details. Reuse the current PBR surfaces and keep all forge/standing clearances. Keep the existing loggia architecture.

**Done when:** Recognizable at Gao conversation distance with correct hand/tool scale, no path obstruction or prompt competition.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 18 captured family components and 0 actor/area anchors.

**Views:** [s10_anvil](s10_anvil.jpg), [s11_forge_rack](s11_forge_rack.jpg).

**Source:** [src/server/Services/SanctuaryForge.luau:68](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/SanctuaryForge.luau#L68).

**Production ownership:** Agent builds/reuses geometry and implements. **Human input:** No new Rodin model required. Review one close/gameplay sample per family.

**Agent implementation:** [C02_INTERACTIVE_PROP_KIT](production/prompts/C02_INTERACTIVE_PROP_KIT.md). **Reusable kits:** B03, B04; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-01 · P2 · Ruined roof and column kit has blunt repeated profiles

**Where:** DesecratedMonastery. Gatehouse, both prayer halls, Cloister and associated roof wreckage; representative East hall (63,6,-899), West hall (-95,5,-900), Cloister (74,6,-1050).

**What is lacking:** T-shaped column capitals, rectangular roof strips and identical straight eaves remain easy to read as constructed Parts. Broken roofs often end in broad flat plates rather than fractured tile, snapped rafters and supported eaves.

**Fix:** Author a small ruined-temple mesh kit with base/shaft/capital, bracket junctions, intact and broken tile/eave sections and two or three snapped rafters. Reuse material scale and architecture language from the Han/lobby kit, but keep the monastery ruin identity. Replace visual families rather than individually ornamenting hundreds of Parts.

**Done when:** Normal-camera approaches to both halls and Cloister show varied supported roof breaks and legible capitals; silhouette improves without changing paths, sightlines, shelter or foe posts.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 490 captured family components and 0 actor/area anchors.

**Views:** [q_d04_east_hall](q_d04_east_hall.jpg), [q_d05_west_idol](q_d05_west_idol.jpg), [d16_cloister_garth](d16_cloister_garth.jpg), [d24_idol_close](d24_idol_close.jpg).

**Source:** [src/server/Services/MonasteryRuins.luau:54](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/MonasteryRuins.luau#L54), [src/server/Services/MonasteryHalls.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/MonasteryHalls.luau#L1).

**Production ownership:** Agent Blender modular construction + code. **Human input:** No new Rodin model required.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md). **Reusable kits:** B01; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-02 · P2 · Ruin walls and rubble repeat square construction breaks

**Where:** DesecratedMonastery. Courtyard perimeter, prayer halls, Cloister galleries and south road.

**What is lacking:** The masonry has material detail, but many damaged walls end at square courses/coping blocks; small rubble is mostly rectangular scatter. Repetition weakens the feeling of a naturally collapsed monastery.

**Fix:** Add a few authored broken wall crowns, exposed brick cores, wedge/fractured rubble piles and root-to-wall transitions. Keep selected intact courses and open negative space. Match the current walkable boundaries and approved Cloister shelter; do not erase all modular construction.

**Done when:** Compare the same route cameras; varied fracture silhouettes and convincing supports, no new collision lips or cover affecting encounters.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 631 captured family components and 0 actor/area anchors.

**Views:** [q_d03_courtyard](q_d03_courtyard.jpg), [q_d04_east_hall](q_d04_east_hall.jpg), [d16_cloister_garth](d16_cloister_garth.jpg), [d13_south_road](d13_south_road.jpg).

**Source:** [src/server/Services/MonasteryRuins.luau:24](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/MonasteryRuins.luau#L24).

**Production ownership:** Agent Blender damage/grounding kit + code. **Human input:** No new Rodin model required.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md). **Reusable kits:** B01, B09; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-03 · P1 · Both prayer-hall idols are unrecognizable boxes

**Where:** DesecratedMonastery. West IdolBody (-95,5.2,-900); East IdolBody (111,5.2,-902), plus displaced heads.

**What is lacking:** The shrine focal points consist of a torso block and a detached cuboid head. They do not communicate a carved destroyed idol or a recognizable sacred figure.

**Fix:** Create one original shattered devotional statue with a clear head/hand/robe fragment and two placement variants. Use sculpted fracture surfaces, a fitted dais and a few matching chips. Preserve the existing cover volumes and traversable side aisles.

**Done when:** At hall entry a player can recognize a desecrated idol without a label; broken pieces share believable anatomy and material scale.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 6 captured family components and 0 actor/area anchors.

**Views:** [q_d05_west_idol](q_d05_west_idol.jpg), [d19_idol_east](d19_idol_east.jpg), [d24_idol_close](d24_idol_close.jpg).

**Source:** [src/server/Services/MonasteryHalls.luau:76](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/MonasteryHalls.luau#L76).

**Production ownership:** Human/Rodin hero sculpture + agent kit/integration. **Human input:** Approve and supply H01; agent can finish the daises/ruins while waiting.

**2D → Rodin prompts:** [H01](production/prompts/H01_IMAGE_TO_RODIN.md).

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](production/prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md). **Reusable kits:** H01, B01; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-04 · P2 · Bell tower and fallen bell read as a frame and capped drum

**Where:** DesecratedMonastery. Tower (64,0,-772); fallen bell (58,4,-843).

**What is lacking:** The tower is four square posts, a diagonal beam and a plate roof shard. The fallen bronze bell is assembled from solid cylinders with no believable hollow mouth, split lip, hanging crown or relief.

**Fix:** Reuse/derive a damaged version of AsuraFoundryKit.Foundry_Bell and its bronze treatment; add a fractured mouth, crown and impact rubble. Build a small ruined belfry frame with credible joints and broken eaves. Keep these distinct from the new Foundry wing, which already has an authored bell.

**Done when:** Bell recognized on its side from the courtyard; hollow mouth and impact damage read up close; tower silhouette has credible failure points.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 21 captured family components and 0 actor/area anchors.

**Views:** [d17_bell_tower](d17_bell_tower.jpg), [d18_fallen_bell](d18_fallen_bell.jpg).

**Source:** [src/server/Services/MonasteryLandmarks.luau:40](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/MonasteryLandmarks.luau#L40), [src/server/Services/MonasteryLandmarks.luau:54](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/MonasteryLandmarks.luau#L54).

**Production ownership:** Reuse supplied Foundry_Bell/HanCauldron; agent derives variants. **Human input:** No new Rodin model required.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md). **Reusable kits:** B04; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-05 · P2 · Courtyard cauldron is a solid disc stack

**Where:** DesecratedMonastery. IronCauldron at (0,4,-836).

**What is lacking:** The ritual vessel is built from cylinder discs and cuboid legs; the rim/body do not have the silhouette of a cast vessel.

**Fix:** Reuse a suitably scaled HanCauldron or an original damaged bronze variant, retaining the glow and safe perimeter. Keep ember intensity below telegraph importance.

**Done when:** Reads as an open vessel from normal camera, fits the same footprint and does not hide nearby enemies.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 7 captured family components and 0 actor/area anchors.

**Views:** [q_d03_courtyard](q_d03_courtyard.jpg), [q_d07_bridge](q_d07_bridge.jpg).

**Source:** [src/server/Services/MonasteryLandmarks.luau:65](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/MonasteryLandmarks.luau#L65).

**Production ownership:** Reuse supplied Foundry_Bell/HanCauldron; agent derives variants. **Human input:** No new Rodin model required.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md). **Reusable kits:** B04; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-06 · P2 · Toppled pagoda remains a stack of cubes and plates

**Where:** DesecratedMonastery. Grave field, base (-62,6,-1052), broken tiers extending west to about x=-105.

**What is lacking:** The grave-field landmark lacks convincing storey construction and crushed connections; the standing tier is a large plain box beneath a simple roof.

**Fix:** Author a damaged stupa/pagoda module with carved storey openings and interlocking broken eaves, then lay matching tiers through an impact scar. Keep the grave path and existing cover clearance.

**Done when:** Recognizable as one collapsed building, with shared construction and supported debris rather than unrelated boxes.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 26 captured family components and 0 actor/area anchors.

**Views:** [q_d09_graves](q_d09_graves.jpg).

**Source:** [src/server/Services/MonasteryLandmarks.luau:82](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/MonasteryLandmarks.luau#L82).

**Production ownership:** Agent modular architecture + code. **Human input:** No new Rodin model required.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md). **Reusable kits:** B01, B09; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-07 · P3 · Six grave stupas have a ball-on-box silhouette

**Where:** DesecratedMonastery. Grave field around x=-130..-26, z=-998..-1108; exact six assemblies in ledger.

**What is lacking:** The bases, spherical domes and thin pole spires read as primitive markers at close range. This is secondary to idols and bosses.

**Fix:** Create two weathered funerary marker variants with tiered profiles, cracked inscription faces and occasional broken finials; scatter sparingly with settled bases.

**Done when:** Grave markers read at walking distance and do not obscure the grave path or cache clues.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 18 captured family components and 0 actor/area anchors.

**Views:** [q_d09_graves](q_d09_graves.jpg).

**Source:** [src/server/Services/MonasteryLandmarks.luau:97](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/MonasteryLandmarks.luau#L97).

**Production ownership:** Agent small prop kit + code. **Human input:** No new Rodin model required.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md). **Reusable kits:** B10; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-08 · P2 · Secret mausoleum shell is unfinished

**Where:** DesecratedMonastery. Mausoleum walls x=-115/-105, y=5,z=-1060; flat roof at (-110,9,-1060).

**What is lacking:** Two thin side wall boxes and a flat lid surround a plain cache; the reward destination has no convincing tomb facade, entrance or roof construction. Nearby seal dressing exists and should be kept.

**Fix:** Integrate a compact ruined tomb entrance with carved lintel, sealed-door remnants and a damaged roof supported by the existing walls. Tie in existing talismans and broken seal instead of replacing the entire secret.

**Done when:** The clue, entrance and reward form one believable small structure; prompt visibility and original route remain intact.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 3 captured family components and 0 actor/area anchors.

**Views:** [q_d10_mausoleum](q_d10_mausoleum.jpg).

**Source:** [src/server/Services/LootWorld.luau:43](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/LootWorld.luau#L43).

**Production ownership:** Human/Rodin relief, agent exact facade/door frame. **Human input:** Supply H04 carving; agent handles the entire precise structure and route.

**2D → Rodin prompts:** [H04](production/prompts/H04_IMAGE_TO_RODIN.md).

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](production/prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md). **Reusable kits:** H04, B01; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-09 · P2 · Waterfall secret is a glass screen between rock boxes

**Where:** DesecratedMonastery. SecretWaterfall (-140,14,-835); AlcoveRock x=-146/-134,y=8,z=-840.

**What is lacking:** A single 12×25×0.5 Glass plate and two cuboid rocks serve as the waterfall/alcove facade. The side view exposes the thin plane and weak connection to a water source and catch basin.

**Fix:** Author a restrained ribbon/water-sheet effect with an upstream rock notch, mist at impact, wet stone and a basin/drainage route. Build fitted alcove rock around the cache. Keep query/collision and the concealed route intact.

**Done when:** Front and side walking views show a grounded cascade and continuous water flow; cache remains discoverable and reachable. Hidden-route traversal still needs a normal-input check.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 3 captured family components and 0 actor/area anchors.

**Views:** [d15b_waterfall](d15b_waterfall.jpg).

**Source:** [src/server/Services/LootWorld.luau:33](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/LootWorld.luau#L33).

**Production ownership:** Agent terrain/water/VFX and fitting. **Human input:** No Rodin waterfall or whole alcove model required.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md), [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](production/prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md). **Reusable kits:** B06, B09; see [asset briefs](production/ASSET_PROMPTS.md).

### DM-10 · P2 · Twin Sentinels arena lacks a finished setting

**Where:** DesecratedMonastery. Large battle floor around (300,0,-955).

**What is lacking:** The current Bull and Zhao are imported templates and look substantially stronger than the mostly empty grey battle platform around them. The floor and distant cliff do not yet establish a distinct sentinels courtyard.

**Fix:** Add a perimeter composition of ruined fortified temple architecture, broken ceremonial standards and a deliberate entry/reveal. Use the Bull/Zhao scale as reference. Keep the central duo footprint clear and retain camera retreat space, encounter bounds and the ridge approach.

**Done when:** Entry and 360-degree normal-camera views feel like a defended courtyard rather than a test pad; both bosses remain fully readable together.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 0 captured family components and 1 actor/area anchors.

**Views:** [d12_twins_arena](d12_twins_arena.jpg), [d22_twins_both](d22_twins_both.jpg).

**Source:** [src/server/Services/BossArenas.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/BossArenas.luau#L1), [src/shared/WorldDefinitions.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/WorldDefinitions.luau#L1).

**Production ownership:** Arena redesign: agent layout/architecture; human taste review. **Human input:** No new boss model. Hero sculpture optional, existing statue assets can be reused.

**Agent implementation:** [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](production/prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR02_TWINSENTINELS_ARENA](production/prompts/AR02_TWINSENTINELS_ARENA.md). **Reusable kits:** B01, B07, B09; see [asset briefs](production/ASSET_PROMPTS.md).

### BP-01 · P2 · Baize arena needs a deliberate edge and encounter identity

**Where:** BambooPass. Arena approach (0,0,-1380), main court around (0,0,-1470), moon gate south.

**What is lacking:** The new stone/timber perimeter bays are present, but the broad tiled court and thin grass border still feel uniform and disconnected from a mythic frost beast. The open floor itself is necessary for the fight.

**Fix:** Keep the recent perimeter upgrade. Add a restrained frost boundary, damaged shrine/court details, scuffed or broken paving at the margins and layered bamboo/rock transitions outside the fight lane. Use a few strong focal props instead of filling the arena with obstacles.

**Done when:** Normal camera reads court boundaries and a frost-beast setting at entrance; pounce landings, sidesteps and camera remain clear.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 0 captured family components and 1 actor/area anchors.

**Views:** [b12_arena](b12_arena.jpg), [b14_boundary](b14_boundary.jpg), [b15_moon_gate](b15_moon_gate.jpg).

**Source:** [src/server/Services/BambooDressing.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/BambooDressing.luau#L1), [src/server/Services/BossArenas.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/BossArenas.luau#L1).

**Production ownership:** Arena redesign: agent layout/terrain/foliage. **Human input:** No new boss model. H03 root module is optional and reusable from Titan.

**2D → Rodin prompts:** [H03](production/prompts/H03_IMAGE_TO_RODIN.md).

**Agent implementation:** [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](production/prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR03_VENERABLEBAIZE_ARENA](production/prompts/AR03_VENERABLEBAIZE_ARENA.md). **Reusable kits:** B06, B09, H03 optional; see [asset briefs](production/ASSET_PROMPTS.md).

### LT-01 · P1 · Exploration lighting hides route and prop form

**Where:** Ash / Crypt / Citadel. Ash Antechamber/Hall/Proving Court; Crypt ossuary/pit route; Citadel descending saddle stair.

**What is lacking:** These routes fall into large near-black shapes in normal profile captures. Matched Ash/Crypt camera retakes at QualityLevel.Level21 still have the problem, and ordinary-key walks reproduce dark Ash/Citadel approaches. Bright arena pools do not light the approaches. This is a finding on this Mac/Studio setup, not a universal device conclusion or a test of active combat profiles.

**Fix:** Add controlled local fill/rim lights and visible light fixtures at turns, stair edges, niche faces and court thresholds; retune local exposure/contrast only after matched captures. Keep night/dusk palettes and bright telegraphs. Test exploration, active encounter and unbound profiles independently on Windows and low/high device settings.

**Done when:** Player feet, next traversable edge, prop silhouette and enemy silhouette remain legible without attack effects; no blown-out lanterns or flattened atmosphere. Use identical camera/display conditions for comparisons.

**Evidence:** Normal-profile assisted captures at Automatic and Level21, plus ordinary-key samples; not device profiling. Ledger scope: 0 captured family components and 3 actor/area anchors.

**Views:** [qh_a02_antechamber](qh_a02_antechamber.jpg), [qh_a09_proving_court](qh_a09_proving_court.jpg), [qh_k06_ossuary](qh_k06_ossuary.jpg), [qh_k07_pit](qh_k07_pit.jpg), [w04_ash_after](w04_ash_after.jpg), [w07_citadel_before](w07_citadel_before.jpg), [k19_gallery_stair](k19_gallery_stair.jpg).

**Source:** [src/shared/EnvironmentProfiles.luau:35](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/EnvironmentProfiles.luau#L35), [src/server/Services/CryptDressing.luau:78](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CryptDressing.luau#L78), [src/server/Services/CitadelDressing.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CitadelDressing.luau#L1).

**Production ownership:** Direct code/fixture placement and real-view calibration. **Human input:** Compare normal-profile captures; no new 3D model needed. No need to approve routine numeric fixes before they are made reviewable.

**Agent implementation:** [C01_CHAIN_PLACEMENT_AND_READABILITY](production/prompts/C01_CHAIN_PLACEMENT_AND_READABILITY.md), [C07_INTEGRATED_WINDOWS_ACCEPTANCE](production/prompts/C07_INTEGRATED_WINDOWS_ACCEPTANCE.md). **Reusable kits:** No new model required; see [asset briefs](production/ASSET_PROMPTS.md).

### AC-01 · P2 · Champions hall and facade still read as block architecture

**Where:** AshColosseum. Antechamber -1712..-1768, Champions hall -1776..-1877, facade z=-1877.

**What is lacking:** Long straight walls, rectangular piers and slab jambs have little ruin construction detail. Imported arches/statues already exist elsewhere, making these approach elements look unfinished. Some ground/tier mass is already Terrain; this finding does not treat hidden layout boxes as visible art.

**Fix:** Use a restrained ruined arcade kit: shaped piers/capitals, fractured wall crowns, soot and ash grounding, a stronger facade with readable central passage. Reuse existing AsuraRuinArch and stone language, then author only missing transitions. Keep doorway width and camera setback.

**Done when:** Approach reads as a ruined martial arena with coherent construction under normal lighting; original hall encounters and fog-gate clearance unchanged.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 20 captured family components and 0 actor/area anchors.

**Views:** [qh_a03_champions_n](qh_a03_champions_n.jpg), [qh_a04_champions_s](qh_a04_champions_s.jpg), [a11_facade_diagnostic](a11_facade_diagnostic.jpg).

**Source:** [src/shared/AshColosseumLayout.luau:25](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/AshColosseumLayout.luau#L25), [src/server/Services/ColosseumDressing.luau:28](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/ColosseumDressing.luau#L28).

**Production ownership:** Agent architecture kit; coordinate with larger Shen arena. **Human input:** No new Rodin model required.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md), [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](production/prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR01_GRANDMASTERSHEN_ARENA](production/prompts/AR01_GRANDMASTERSHEN_ARENA.md). **Reusable kits:** B01, B07; see [asset briefs](production/ASSET_PROMPTS.md).

### AC-02 · P2 · Last-stand props need recognizable sculpted forms

**Where:** AshColosseum. Fallen champion (24,1.4,-1702); spears and shields in hall margins z=-1782..-1878.

**What is lacking:** The fallen champion is one 8×3×3 block while its standing counterpart uses an imported statue. Spears are unheaded narrow beams and shields are undetailed cylinders.

**Fix:** Use a broken variant of the standing statue and a small shared weathered weapon/shield kit. Partially bury props in ash with impact orientation; retain clean playable center lanes.

**Done when:** Player can identify the collapsed champion and last stand from normal walking distance; source statues and fragments visibly match.

**Evidence:** Static constructor + live instance inventory; dark/partial views limit close-face assessment. Ledger scope: 21 captured family components and 0 actor/area anchors.

**Views:** [a01_ash_entry](a01_ash_entry.jpg), [qh_a03_champions_n](qh_a03_champions_n.jpg), [qh_a04_champions_s](qh_a04_champions_s.jpg).

**Source:** [src/server/Services/ColosseumDressing.luau:32](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/ColosseumDressing.luau#L32).

**Production ownership:** Reuse matching existing statue source; agent small prop variants. **Human input:** No new statue commission required if standing statue source is available.

**Agent implementation:** [C03_MONASTERY_RUIN_KIT](production/prompts/C03_MONASTERY_RUIN_KIT.md). **Reusable kits:** B09, B10; see [asset briefs](production/ASSET_PROMPTS.md).

### AC-03 · P2 · Shen arena perimeter has weak colosseum hierarchy

**Where:** AshColosseum. Battle area x=-60..60,z=-1895..-2025; tiers and south Victor gate around it.

**What is lacking:** The bright open battle floor is surrounded by low dark/rocky mass and isolated arches. The overall bowl, spectator tiers and Victor gate are less legible than the name and boss importance suggest.

**Fix:** Dress the existing perimeter with readable stepped stone seating/retaining fronts, broken arcade clusters, ash deposits and a strong south exit focal point. Preserve open sky, low podium, all combat clearances and the existing Terrain mass.

**Done when:** At entry and from the center the arena reads as one ruined colosseum; walls never crowd the camera in either Shen form.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 0 captured family components and 1 actor/area anchors.

**Views:** [a06_arena](a06_arena.jpg), [a08_victor](a08_victor.jpg), [a11_facade_diagnostic](a11_facade_diagnostic.jpg).

**Source:** [src/shared/AshColosseumLayout.luau:55](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/AshColosseumLayout.luau#L55), [src/server/Services/ColosseumDressing.luau:34](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/ColosseumDressing.luau#L34).

**Production ownership:** Arena redesign: agent terrain/arcades/seating/landmark. **Human input:** Approve the rendered scene composition; no whole-scene Rodin asset.

**Agent implementation:** [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](production/prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR01_GRANDMASTERSHEN_ARENA](production/prompts/AR01_GRANDMASTERSHEN_ARENA.md). **Reusable kits:** B01, B07, B09; see [asset briefs](production/ASSET_PROMPTS.md).

### SD-01 · P1 · Crypt ceiling and enclosing walls need real architectural form

**Where:** SanctuaryDepths. Nave roof (492,47,1010), ossuary roof (380,47,874), ribs x=364..620 at y44; high flat enclosure walls.

**What is lacking:** The promised ribbed vault is actually two flat ceiling slabs with 17 straight beams. The exposed slab ends and flat enclosing walls leave a box-room impression, particularly at the nave/arena transition. The Titan hall is intentionally open to sky and should remain so.

**Fix:** Build an original modular crypt kit: real arch-shaped ribs, a few broken vault bays, heavy imposts, fitted wall recesses and settled cracks/root intrusion. Dress the current envelopes without lowering camera clearance or roofing over the Titan arena. Use diagnostic views only to judge geometry; validate final art under real lighting.

**Done when:** Nave/ossuary read as a constructed ancient burial space from player height; no disconnected overhead strips or visible slab cut edges on the intended route.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 24 captured family components and 0 actor/area anchors.

**Views:** [k04_nave](k04_nave.jpg), [k12_vault](k12_vault.jpg), [k16_vault_diagnostic](k16_vault_diagnostic.jpg), [w05_crypt_after](w05_crypt_after.jpg).

**Source:** [src/server/Services/CryptDressing.luau:35](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CryptDressing.luau#L35), [src/shared/SunkenCryptLayout.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/SunkenCryptLayout.luau#L1).

**Production ownership:** Agent crypt kit + human hero root module; enlarged Titan chamber. **Human input:** Supply H03 after the measured room prototype. Optional H04 is reusable.

**2D → Rodin prompts:** [H03](production/prompts/H03_IMAGE_TO_RODIN.md).

**Agent implementation:** [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](production/prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](production/prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md), [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](production/prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR04_SLUMBERINGTITAN_ARENA](production/prompts/AR04_SLUMBERINGTITAN_ARENA.md). **Reusable kits:** H03, B01, B02; see [asset briefs](production/ASSET_PROMPTS.md).

### SD-02 · P1 · Ossuary skulls are 60 featureless spheres on 20 flat plaques

**Where:** SanctuaryDepths. West wall x≈359, z790..1040 excluding pit span; all 80 pieces listed.

**What is lacking:** Close inspection confirms pale balls in rows against rectangular black panels. They read as dots, not skulls, bone shelves or carved niches.

**Fix:** Create a small skull/bone kit with actual cavities and a stone niche frame, varied orientations and a few missing/chipped examples. Bake dense clusters into low-cost shelf assets. Keep respectful stylization consistent with the game and avoid unnecessary gore.

**Done when:** Ossuary reads at walking distance as burial storage; repeated shelf modules have controlled variation and correct scale.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 80 captured family components and 0 actor/area anchors.

**Views:** [k06_ossuary](k06_ossuary.jpg), [k14_skulls_diagnostic](k14_skulls_diagnostic.jpg), [k18_reliquary_diagnostic](k18_reliquary_diagnostic.jpg).

**Source:** [src/server/Services/CryptDressing.luau:42](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CryptDressing.luau#L42).

**Production ownership:** Agent skull/niche kit first; optional Rodin fallback. **Human input:** No human model required if the agent sample reads well. H09 is a complete optional image/Rodin prompt if it does not.

**2D → Rodin prompts:** [H09](production/prompts/H09_IMAGE_TO_RODIN.md).

**Agent implementation:** [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](production/prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md). **Reusable kits:** B02, H09 optional; see [asset briefs](production/ASSET_PROMPTS.md).

### SD-03 · P2 · Sarcophagi and crossing lids are plain rectangular masses

**Where:** SanctuaryDepths. Six nave coffins, e.g. (384,1.5,1012); seven pit stepping lids at x366,z≈855..895.

**What is lacking:** The tombs have no separate lid profile, carved end, handles, fracture detail or burial identity. The pit crossing uses tall cuboids whose visible tops also lack lid construction.

**Fix:** Author a matching sarcophagus/lid set with two damaged variants, funerary relief and fitted bases. Keep the seven crossing top heights, widths and distances exactly; render only the exposed portions around existing collision.

**Done when:** Coffins recognizable in normal lighting and crossing remains equally traversable with no collision seam or misleading lip.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 13 captured family components and 0 actor/area anchors.

**Views:** [k05_sarcophagi](k05_sarcophagi.jpg), [k07_pit](k07_pit.jpg), [k15_sarcophagus_diagnostic](k15_sarcophagus_diagnostic.jpg).

**Source:** [src/shared/SunkenCryptLayout.luau:25](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/SunkenCryptLayout.luau#L25), [src/shared/SunkenCryptLayout.luau:60](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/SunkenCryptLayout.luau#L60).

**Production ownership:** Agent coffin/lid modules; preserve or explicitly migrate crossing. **Human input:** No new Rodin model required.

**Agent implementation:** [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](production/prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md). **Reusable kits:** B02; see [asset briefs](production/ASSET_PROMPTS.md).

### SD-04 · P2 · Titan chains are loose solid blocks rather than linked restraints

**Where:** SanctuaryDepths. Four arena corners around x434/606,z794/966; 24 links and four anchors.

**What is lacking:** Each chain link is a solid cuboid scattered on the floor, with no hole or connected sequence. Large anchor blocks do not visually explain a restrained giant.

**Fix:** Use open forged links in connected slack runs, broken end links and fitted anchor rings/stone sockets. Bake/static-place these decorative chains; a physics chain is unnecessary. Relate thickness to the Titan model after its scale is settled.

**Done when:** Each run reads as one broken restraint from fight distance; no snagging/query changes and no simulated prop instability.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 28 captured family components and 0 actor/area anchors.

**Views:** [k13_chains](k13_chains.jpg), [k17_chains_diagnostic](k17_chains_diagnostic.jpg).

**Source:** [src/server/Services/CryptDressing.luau:61](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CryptDressing.luau#L61).

**Production ownership:** Agent open-link restraints + code placement. **Human input:** No new Rodin model required; fit to supplied Titan scale.

**Agent implementation:** [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](production/prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md). **Reusable kits:** B05; see [asset briefs](production/ASSET_PROMPTS.md).

### SD-05 · P2 · Flooded pit needs believable water and shore treatment

**Where:** SanctuaryDepths. Pit x356..404,z850..900; PitWater near y=-12.

**What is lacking:** The water is a flat Glass sheet in a sharp rectangular cut with a weak shoreline/wetness transition. It does not yet sell a sunken flooded crypt.

**Fix:** Keep the pit envelope and crossing geometry, but add a continuous wet rock/stone waterline, restrained ripple surface, submerged rubble silhouettes and localized mist. Keep fall/readability cues distinct from walkable tops.

**Done when:** Ordinary camera clearly distinguishes water, pit edge and all seven stepping lids in low and high rendering settings.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 1 captured family components and 0 actor/area anchors.

**Views:** [qh_k07_pit](qh_k07_pit.jpg).

**Source:** [src/shared/SunkenCryptLayout.luau:18](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/SunkenCryptLayout.luau#L18), [src/server/Services/CryptDressing.luau:76](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CryptDressing.luau#L76).

**Production ownership:** Agent water/terrain/grounding. **Human input:** No new Rodin model required.

**Agent implementation:** [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](production/prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md), [AR04_SLUMBERINGTITAN_ARENA](production/prompts/AR04_SLUMBERINGTITAN_ARENA.md). **Reusable kits:** B06, B09; see [asset briefs](production/ASSET_PROMPTS.md).

### SD-06 · P3 · Thirty candles remain unshaped rods

**Where:** SanctuaryDepths. Six candle clusters: four nave/gallery sites and the reliquary at (366,0.4,812).

**What is lacking:** Close views show straight square candle rods lit by one cluster glow, with little wick, flame or pooled wax detail.

**Fix:** Create two or three simple wax silhouettes with dark wicks, tiny flame treatment and a shared wax-drip base. Keep cluster lighting restrained and avoid many independent dynamic lights.

**Done when:** Read as candles up close without competing with combat indicators; no new effect lifetime or streaming cleanup problems.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 30 captured family components and 0 actor/area anchors.

**Views:** [k15_sarcophagus_diagnostic](k15_sarcophagus_diagnostic.jpg), [k18_reliquary_diagnostic](k18_reliquary_diagnostic.jpg).

**Source:** [src/server/Services/CryptDressing.luau:53](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CryptDressing.luau#L53).

**Production ownership:** Agent small candle/FX kit. **Human input:** No new Rodin model required.

**Agent implementation:** [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](production/prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md). **Reusable kits:** B10; see [asset briefs](production/ASSET_PROMPTS.md).

### CP-01 · P1 · Oracle throne is a box chair beneath a small canopy

**Where:** CelestialPagoda. EmptyThrone (-140,17,-2280), back at y23, on throne loft.

**What is lacking:** The encounter-story focal prop is a six-stud cube seat, flat rectangular back and simple cushion. Its silhouette is dramatically weaker than the pagodas behind it.

**Fix:** Author a distinct imperial oracle throne with a carved seat/back, worn lacquer/gold, a coherent canopy and a recognizable void/star motif. Fit it to the existing loft and preserve the lore point/access route.

**Done when:** Seat reads as a throne from the loft entrance and supports the Oracle identity without floating details or obstructed walking space.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 3 captured family components and 0 actor/area anchors.

**Views:** [p07_throne](p07_throne.jpg), [p14_throne_front](p14_throne_front.jpg).

**Source:** [src/shared/CelestialPagodaLayout.luau:51](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/CelestialPagodaLayout.luau#L51), [src/server/Services/PagodaDressing.luau:84](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/PagodaDressing.luau#L84).

**Production ownership:** Human/Rodin throne + agent loft/frame integration. **Human input:** Approve H02 and supply its chosen export/maps.

**2D → Rodin prompts:** [H02](production/prompts/H02_IMAGE_TO_RODIN.md).

**Agent implementation:** [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](production/prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](production/prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md). **Reusable kits:** H02, B01; see [asset briefs](production/ASSET_PROMPTS.md).

### CP-02 · P2 · Great bell is an unadorned solid cylinder

**Where:** CelestialPagoda. GreatBell (60,11,-2276) and frame posts x54.5/65.5.

**What is lacking:** It reads as a hanging drum with flat closed ends. There is no hollow flared lip, hanging loop or carved bronze relief.

**Fix:** Reuse the existing Foundry_Bell mesh at a fitting scale, with an imperial patina/inscription variant and credible suspension. Dress its frame with bracket joints and a clapper if visible.

**Done when:** Bell silhouette reads from forecourt and close side views; frame connects to the crown and stays outside fight clearance.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 4 captured family components and 0 actor/area anchors.

**Views:** [p08_bell](p08_bell.jpg).

**Source:** [src/server/Services/PagodaDressing.luau:88](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/PagodaDressing.luau#L88).

**Production ownership:** Reuse Foundry_Bell; agent suspension/frame. **Human input:** No new Rodin model required.

**Agent implementation:** [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](production/prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md). **Reusable kits:** B04; see [asset briefs](production/ASSET_PROMPTS.md).

### CP-03 · P2 · Lotus pool looks like a rectangle of water and discs

**Where:** CelestialPagoda. Pool (70,-25.94,-2214), 22 pads on the gorge floor.

**What is lacking:** The water boundary is perfectly rectangular and the lotus pads are flat cylinders with no leaf notch, stems or flowers. The pool has little believable bank construction.

**Fix:** Create a few notched leaf/flower variants, add a coherent stone or broken garden rim, wetness and a drain/source cue. Keep the entire feature off the narrow rafter route and preserve the gorge floor.

**Done when:** Reads as an abandoned lotus garden from above and bank height with no false walkable surfaces.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 23 captured family components and 0 actor/area anchors.

**Views:** [p05_pool](p05_pool.jpg).

**Source:** [src/server/Services/PagodaDressing.luau:70](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/PagodaDressing.luau#L70).

**Production ownership:** Agent small foliage mesh + water/terrain. **Human input:** No new Rodin model required.

**Agent implementation:** [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](production/prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md). **Reusable kits:** B06, B09; see [asset briefs](production/ASSET_PROMPTS.md).

### CP-04 · P2 · Gallery, rafters and loft need crafted timber junctions

**Where:** CelestialPagoda. West gallery (-88,-11,-2210), beam (-37,-6,-2228), central rafter, throne loft (-130,17,-2265).

**What is lacking:** The traversal idea is distinctive, but wide flat decks, square rails/posts and straight beams have little joinery, bracket logic or broken architectural context. Large horizontal areas can feel like floating platforms.

**Fix:** Dress the existing volumes with fitted beam ends, timber braces, authored rail bays and a few hanging prayer cloths/lantern clusters; establish how the gallery was part of a ruined building. Reuse lobby timber pieces scaled coherently. Preserve narrow-beam width, all landing heights and climb/jump distances.

**Done when:** Player can read support and destination while traversing; no new railing or ornament blocks the existing movement route/camera.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 27 captured family components and 0 actor/area anchors.

**Views:** [p03_gallery](p03_gallery.jpg), [p13_rafters_clear](p13_rafters_clear.jpg), [p14_throne_front](p14_throne_front.jpg), [p15_lantern_rafter](p15_lantern_rafter.jpg), [p16_rafter_stair](p16_rafter_stair.jpg), [p17_west_stair](p17_west_stair.jpg).

**Source:** [src/shared/CelestialPagodaLayout.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/CelestialPagodaLayout.luau#L1), [src/server/Services/PagodaDressing.luau:77](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/PagodaDressing.luau#L77).

**Production ownership:** Agent precise timber/stone construction. **Human input:** No new Rodin model required.

**Agent implementation:** [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](production/prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md). **Reusable kits:** B01; see [asset briefs](production/ASSET_PROMPTS.md).

### CP-05 · P2 · Wu arena has little ritual identity at floor level

**Where:** CelestialPagoda. Open hall centered (0,0,-2380), between the four imported pagodas.

**What is lacking:** The skyline and guardians are good, but the very broad uniform floor and widely spaced columns leave a weak focal composition around the small fallback Wu. Boss replacement will help; floor-level ritual context is still missing.

**Fix:** After Wu scale is settled, add a restrained inlaid celestial diagram, damaged ritual stations and hanging cloth/altar clusters at the margins. Retain open telegraph ground, camera room, teleport destinations and the good imported pagodas.

**Done when:** Entry shot clearly frames the Oracle and ritual space; dark effects remain distinct from ground markings and no prop occupies intended teleport/attack lanes.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 0 captured family components and 1 actor/area anchors.

**Views:** [p09_arena](p09_arena.jpg), [p10_wu](p10_wu.jpg), [w06_pagoda_after](w06_pagoda_after.jpg).

**Source:** [src/shared/CelestialPagodaLayout.luau:1](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/CelestialPagodaLayout.luau#L1), [src/server/Services/PagodaDressing.luau:28](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/PagodaDressing.luau#L28).

**Production ownership:** Arena redesign: agent mirror court/lighting/bounds; supplied throne. **Human input:** H02 is the only recommended human focal prop here; whole lake/sky built in engine.

**2D → Rodin prompts:** [H02](production/prompts/H02_IMAGE_TO_RODIN.md).

**Agent implementation:** [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](production/prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR05_SOVEREIGNWU_ARENA](production/prompts/AR05_SOVEREIGNWU_ARENA.md). **Reusable kits:** H02, B06, B07, B08; see [asset briefs](production/ASSET_PROMPTS.md).

### SC-01 · P1 · Ten chain posts float above the descending stair

**Where:** SkyCitadel. x=±5.6,z=-2552,-2560,-2568,-2576,-2584, plus ten connector beams.

**What is lacking:** Observed in normal-key traversal and close-up. At z=-2568, post center y=11.5 has bottom y=10 while neighboring stair top is about y=-10: roughly a 20-stud vertical mismatch. The decor formula y=-(z+2548)/2 rises while the authored stair descends. This is a placement defect, not an art-style preference.

**Fix:** Derive post feet and chain end positions from the same descending stair rise/run or sampled authored tread tops. Re-anchor all ten posts to the stair shoulders; ensure adjacent chain endpoints actually meet. Then replace straight rods with a restrained sagging chain/rope visual.

**Done when:** All post bottoms meet a supported surface at both sides and every step of the descent; no floating beams remain in normal approach/return views; collision layout remains unchanged.

**Evidence:** Visible placement defect + exact runtime coordinates + traced sign mismatch in source. Ledger scope: 20 captured family components and 0 actor/area anchors.

**Views:** [c01_bridge](c01_bridge.jpg), [c11_chain_clear](c11_chain_clear.jpg), [w07_citadel_before](w07_citadel_before.jpg), [w07_citadel_after](w07_citadel_after.jpg).

**Source:** [src/server/Services/CitadelDressing.luau:79](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CitadelDressing.luau#L79), [src/shared/SkyCitadelLayout.luau:17](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/SkyCitadelLayout.luau#L17).

**Production ownership:** Direct code placement; agent simple chain geometry. **Human input:** No human/Rodin work required.

**Agent implementation:** [C01_CHAIN_PLACEMENT_AND_READABILITY](production/prompts/C01_CHAIN_PLACEMENT_AND_READABILITY.md). **Reusable kits:** B05; see [asset briefs](production/ASSET_PROMPTS.md).

### SC-02 · P2 · Dragon perch chains and shed scales are primitive

**Where:** SkyCitadel. Perch near (0,70,-2952); scale scatter x≈-60..60,z=-2900..-2930.

**What is lacking:** Eight perfectly straight beams radiate from one point on the rock pillar like spokes rather than broken chain runs. Twelve Glass cuboids stand in for shed scales; they are poorly tied to the new charcoal wyrm concept.

**Fix:** Author two or three static broken chain runs anchored in believable sockets and a small curved/scarred scale shard kit matching the final Wyrm material. Keep the natural rock perch and open flight space; no live chain physics required.

**Done when:** Perch reads as a former storm-dragon restraint/roost from the arena; close scale props resemble the production creature and never become bright misleading ground cues.

**Evidence:** Perch beams observed; all 12 scale placeholders confirmed in source/runtime inventory, individual shard close-ups limited. Ledger scope: 20 captured family components and 0 actor/area anchors.

**Views:** [c08_scale](c08_scale.jpg), [c09_perch](c09_perch.jpg).

**Source:** [src/server/Services/CitadelDressing.luau:87](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/server/Services/CitadelDressing.luau#L87).

**Production ownership:** Agent chain/scale reuse; optional human organic crown. **Human input:** Reuse the supplied Wyrm model/materials; H05 is optional only if the chosen landmark needs it.

**2D → Rodin prompts:** [H05](production/prompts/H05_IMAGE_TO_RODIN.md).

**Agent implementation:** [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](production/prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md), [AR06_AZUREWYRM_ARENA](production/prompts/AR06_AZUREWYRM_ARENA.md). **Reusable kits:** B05, B07, H05 optional; see [asset briefs](production/ASSET_PROMPTS.md).

### SC-03 · P2 · Bridge and bastion edges need a weathered masonry finish

**Where:** SkyCitadel. Cloud bridge (0,-20,-2604), stair gates and Last Bastion (0,0,-2704).

**What is lacking:** Good imported towers sit beside long plain cuboid bridge rails and battlement/rim strips. Low lighting amplifies the loss of profile and surface hierarchy.

**Fix:** Add fitted coping, damaged parapet modules, buttress/rail terminations and storm-worn joints, reusing the existing stone language. Keep bridge width, rim height, fall protections and summit flight space. Leave intentional open summit ground open.

**Done when:** Approach and return cameras show supported finished edges with readable drops; no new obstacle or camera collision along the narrow bridge.

**Evidence:** Observed Studio appearance + source/runtime inventory; art judgement. Ledger scope: 11 captured family components and 0 actor/area anchors.

**Views:** [c03_gorge](c03_gorge.jpg), [c04_bastion](c04_bastion.jpg), [c10_summit](c10_summit.jpg), [w07_citadel_after](w07_citadel_after.jpg), [c13_heaven_stair](c13_heaven_stair.jpg).

**Source:** [src/shared/SkyCitadelLayout.luau:20](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/src/shared/SkyCitadelLayout.luau#L20).

**Production ownership:** Agent masonry kit; enlarged Wyrm scene. **Human input:** No new Rodin model required; H05 optional.

**Agent implementation:** [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](production/prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md), [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](production/prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR06_AZUREWYRM_ARENA](production/prompts/AR06_AZUREWYRM_ARENA.md). **Reusable kits:** B01, B07; see [asset briefs](production/ASSET_PROMPTS.md).

## Existing work to preserve

- Sanctuary imported sacred tree/ascetic, carved lobby kit, lanterns, colonnades, Promenade ring finish, supported Eaves deck and Reliquary vessel/shelter. The root close-up s14 is a rejected inspection camera, not a claim of a broken normal camera.
- Bamboo living foliage/ground patches, Foundry_Bell/KilnStack/Crucible/SlagHeap/BellMould/HallWall, ridge gate framing, new frost steps/supports and the new arena stone/timber bays. The former bare arena strip/support findings are already addressed. The current moon gate is a dressed segmented arch; it is not treated as an urgent rebuild.
- Han high-detail gates/pagodas/watchtowers and bixie guardians in Pagoda/Citadel, real Terrain cliffs/perch and existing imported ruin arches/statues in Ash. Invisible collision fallback boxes are not visible-art findings.
- Current template-skinned Iron Bull, General Zhao, Corrupt Wandering Monk, Cursed Swordsman and Hollow Bell Warden library assets. Only held Bull/Zhao base appearance was examined, not full animation/fight quality.
- Creator-approved Cloister altar shelter and foe positions. All proposed dressing must preserve their gameplay effect.

## Missing context and explicit coverage gaps

Every named campaign layout zone has a source/inventory entry in coverage.csv; columns distinguish settled actor samples from scripted camera positions inside its bounds. All 53 named campaign zones have at least one of these; the western eave gallery had a camera inside it while the seeded player stood below the platform, so it has no earned traversal claim. A nearby shot is not a completed traversal. Sanctuary service areas, main stair, terrace, ascetic/canopy, forge, Eaves, descent, reliquary, duel ring and spectator balcony have dedicated views. All three PvP ring settings were observed; no match was played.

Hidden cache fronts, every roof underside, every return direction and every possible camera angle were not all walked. Phase-2 forms and boss cinematics were not triggered. Sunken Crypt shaft details and the Citadel rim need a second normal-input pass after lighting/asset fixes. This document records all identified issue families and matching inventory instances; it does not certify that no other defect exists.

## Restoration and verification

The helper restored its saved session boss flags, original placement/invulnerability value and seeded attribute, and despawned all audit-owned bosses. Diagnostic lighting and avatar overrides were released; Studio rendering preferences returned to Automatic. The Play session was then stopped. Edit mode contains neither QA_VisualAudit nor AsuraVisualAudit, and its digest matches the pre-tour digest. The canonical place file is byte-identical. No production source, asset, collision, enemy setting, profile store or published game was changed.

| Evidence type | Result |
|---|---|
| Static/source review | Art constructors, asset libraries and mappings examined; exact references above. |
| Local artifact checks | JSON/CSV, image references, source links and generated gallery checked. No gameplay regression suite claimed. |
| Studio integration | Actual boot, assisted captures, seven short keyboard/normal-camera samples, held model inspection and cleanup/digest checks. |
| Earned human playthrough / combat feel | Not established. |
| Multiplayer / live persistence | Not run; local mock persistence only. |
| Device performance profiling | Not run. Rendering-setting comparisons are appearance evidence only. |

No place rebuild is required: this task only adds unmapped audit documentation/evidence and temporary tooling. Future art implementation must follow the pinned build/verification workflow and repeat normal-camera/encounter checks.

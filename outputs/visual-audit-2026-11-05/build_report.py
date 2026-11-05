"""Build audit documentation and exact-instance ledger from captured evidence. No game writes."""
from pathlib import Path
import json,csv,html,collections,math
P=Path(__file__).parent
D=json.loads((P/'visible-parts.json').read_text())
V=[json.loads(l) for l in (P/'views.jsonl').read_text().splitlines()]
W=json.loads((P/'world-inventory.json').read_text())
F=[];R=[]
def issue(id,priority,region,title,where,problem,fix,accept,sources,images,pred=None,points=None,evidence='Observed Studio appearance + source/runtime inventory; art judgement'):
 parts=[(i,d) for i,d in enumerate(D) if pred and pred(d)]
 for i,d in parts:
  R.append(dict(issue=id,priority=priority,region=region,kind='family member to review',inventory_index=i,path=d['path'],x=d['position'][0],y=d['position'][1],z=d['position'][2],class_name=d['class'],name=d['name'],evidence='visible-parts.json',fix=fix))
 for path,xyz in points or []:
  R.append(dict(issue=id,priority=priority,region=region,kind='actor or area anchor',inventory_index='',path=path,x=xyz[0],y=xyz[1],z=xyz[2],class_name='Actor/Area',name=title,evidence=evidence,fix=fix))
 F.append(dict(id=id,priority=priority,region=region,title=title,where=where,problem=problem,fix=fix,acceptance=accept,sources=sources,images=images,evidence=evidence,family_members=len(parts),area_actor_anchors=len(points or [])))
def prefix(root,names=None):return lambda d:d['path'].startswith(root) and (names is None or d['name'] in names)
def names(root,items):return prefix(root,set(items.split('|')))
S='src/server/Services/';H='src/shared/'
issue('AP-01','P1','Multiple','Five boss designs are still fallback costumes',
'Baize (0,5,-1495); Shen (0,4,-1995); Titan (520,10,855); Wu (0,4,-2405); Wyrm (0,8,-2855).',
'All five render as simple primitive bodies rather than the supplied creature/character concepts. actors-final.json explicitly reports Fallback:Costume and missing AsuraBoss_<key> templates for all five. This is the largest asset-quality gap. Titan has a box torso/head and neon diamond; Baize is a small white block quadruped; Wyrm has flat slab wings. Only base/phase-1 held appearances were inspected.',
'Finish five production character assets from the approved concepts. Retopologize and bake the generated source models, separate weapons/effects where needed, rig to the existing animation/bone contract (or author and validate a compatible creature rig), and integrate through BossSkin/CostumeSchema. Preserve server roots, hurt geometry, attack timing and phase logic. Do one complete boss first; apply its validated pipeline to the rest. A downloaded GLB alone does not complete this work.',
'No fallback skin status; correct feet, pivots, scale and silhouette at normal fight distance; authored idle, locomotion and attacks without skating or intersections; separately verify both implemented phases and repeated encounter cleanup.',
[S+'BossSkin.luau:21',H+'CostumeSchema.luau:67'],['b13_baize','a07_shen','k11_titan','p10_wu','c07_wyrm'],points=[('Workspace.AsurasPath.Entities.'+n,xyz) for n,xyz in [('Venerable Baize',[0,5,-1495]),('Grandmaster Shen',[0,4,-1995]),('The Slumbering Titan',[520,10,855]),('Sovereign Wu',[0,4,-2405]),('Azure Wyrm',[0,8,-2855])]],evidence='Observed held base forms + explicit runtime Fallback:Costume status; phase 2 not played')
issue('AP-02','P1','Sanctuary / Monastery','Speaking NPCs lag behind their surroundings',
'Lin (8,603,918); Gao (-86,603,899); Hermit (-14,3,-738).',
'Box garments, mitten-like hands, cylindrical/ball heads and solid cuboid hair look like stand-ins beside the carved architecture and imported enemies. Lin and Hermit are anchored R15-proportioned figures; Gao is a live dressed rig. This is not a claim that every NPC or the updated monks is a placeholder.',
'Author three readable R15-compatible cast characters: shaped robe folds and silhouettes, authored faces/hair, hand shapes and a restrained idle for live rigs. Keep dialogue head height, feet, Speak anchors, line of sight and collision/query rules. Prioritize Lin, then Gao, then Hermit.',
'Compare front/profile/back at talk distance and in the ordinary camera; dialogue and Gao forge prompts still resolve from the same approach.',
[S+'CastFigures.luau:25',H+'LooksCast.luau:1'],['s18_lin_close','s10_anvil','d23_hermit_close'],pred=lambda d:d['path'] in ['Workspace.JadeCataclysm.Lin.Head','Workspace.JadeCataclysm.Hermit.Head','Workspace.Sanctuary.BlacksmithLoggia.MasterSmithGao.Head'])
issue('AP-03','P2','Multiple','Six rest altars remain generic pedestal-and-stick assemblies',
'Bell Terrace, Bamboo Shrine, Colosseum Antechamber, Crypt gallery, Pagoda forecourt and Citadel bastion; all exact components/coordinates in instances.csv.',
'The repeated small square base, cylinder censer and bright upright incense stick carry little regional identity. These important rest destinations are weaker than the existing Primal Bonfire and newly dressed environments.',
'Use a shared carved censer/altar kit with six regional treatments: foundry bronze, bamboo stone/wood, ash-scarred basalt, crypt funerary stone, oracle lacquer and storm-worn summit stone. Reuse HanCauldron/Foundry material work where appropriate. Preserve altar IDs, prompt anchor, rest/spawn clearance and shelter behavior.',
'All six readable as rest points before prompt range, no prompt occlusion, no new snagging, matching rest/respawn camera shots.',
[S+'WorldService.luau:404'],['b06_bell_terrace','b10_shrine','qh_a02_antechamber','k03_gallery','p06_forecourt','c12_bastion_fill'],pred=lambda d:'.World.Altars.IncenseAltar_' in d['path'])
cache_ids={'FoundersKiln','WaterfallAlcove','PagodaRafters','SealedMausoleum','SanctuaryEaves'}
issue('AP-04','P2','Multiple','Five hidden caches are plain metal cuboids',
'Founders Kiln (-170,13.2,-1336); Waterfall (-140,5,-840); Cloister rafters (92,30,-1000); Mausoleum (-110,3,-1060); Loggia Eaves (-76,617,923). PagodaRafters is in the Monastery, despite its ID.',
'The reward objects are undetailed gold/brown blocks; their square ledges can look like debug pads. SanctuaryReliquary already uses a HanCauldron vessel and is excluded.',
'Create one hinged or sealed coffer with lid, fittings and a restrained reward cue; apply region materials. Embed each ledge in its shelf/rafter/stone support. Keep original hidden CacheId/prompt/collision anchors and claim logic; art should not reveal a secret from every angle.',
'Each cache is recognizable when found, opens/claims once as before, and remains reachable on its current route. Compare close and discovery-distance shots.',
[S+'LootWorld.luau:22',H+'ArsenalCatalog.luau:26'],['b07_kiln','s12_eaves','q_d10_mausoleum','d16_cloister_garth'],pred=lambda d:d['path'].startswith('Workspace.WorldDiscoveryCaches.') and (d['name'] in cache_ids or d['name'] in {x+'Ledge' for x in cache_ids}),evidence='Runtime inventory/source confirms all five; Kiln/Eaves photographed, some secret-object close faces not reached')
issue('AP-05','P2','Sanctuary / Monastery','Two industrial truss ladders break the setting',
'Loggia Eaves (-76,608,918); Cloister rafters (92,14.6,-1005).',
'The visible default TrussPart is a conspicuous industrial scaffold against historical timber architecture, especially in the Cloister garth.',
'Dress the existing ladder with a weathered timber or forged rung mesh and top/bottom attachment brackets. Retain the climb volume and the corrected outboard ledge alignment; hide the original truss visually only when its climb behavior is preserved.',
'Ordinary input climbs up/down without hitting the ledge underside; no interruption to cache access; silhouette fits the structure.',
[S+'LootWorld.luau:40'],['d16_cloister_garth','s12_eaves'],pred=names('Workspace.WorldDiscoveryCaches.','HiddenRafterLadder'))
issue('AP-06','P2','Monastery / Ash Colosseum','Two PvP rings still use the undressed primitive kit',
'Gatehouse ring (-130,0,-745); Octagonal Ring of Ash (118,0,-1770).',
'Plain slab floors, low cuboid walls/pillars and neon marker braziers contrast with the dressed Sanctuary Promenade ring. The Ash court is particularly difficult to read at night.',
'Apply regional ring finishes while preserving the exact octagon, threshold band and barrier logic: ruined monastery paving at Gatehouse, scorched inlaid basalt in Ash. Give outer corners real small braziers and coherent seating/edge treatment. The Sanctuary ring provides an existing integration pattern.',
'Threshold queue/sign remain visible, exact combat footprint and camera clearance retained; verify ordinary traversal and two-player ring behavior separately.',
[S+'ColosseumService.luau:1112',S+'SanctuaryRingFinish.luau:1'],['d21b_gatehouse_ring','qh_a10_proving_ring'],pred=lambda d:any(('.'+x+'.') in d['path'] for x in ['Ring_GatehouseCircle','Ring_OctagonOfAsh']))
issue('SN-01','P2','Sanctuary','Forge tools need a small authored prop pass',
'Blacksmith Loggia: anvil (-88,603,903), rack (-98,603,891), bellows (-94,602,896), workbench and barrels.',
'The loggia shell and hearth are strong. Close interaction instead exposes an angular stacked anvil, unshaped rectangular rack blades, rod tools and box bellows. These high-attention props need more believable construction.',
'Build a compact smith prop kit: shaped anvil/horn, tongs and hammer, blade blanks with tangs, leather pleated bellows and restrained barrel details. Reuse the current PBR surfaces and keep all forge/standing clearances. Keep the existing loggia architecture.',
'Recognizable at Gao conversation distance with correct hand/tool scale, no path obstruction or prompt competition.',
[S+'SanctuaryForge.luau:68'],['s10_anvil','s11_forge_rack'],pred=lambda d:d['path'].startswith('Workspace.Sanctuary.BlacksmithLoggia.') and (d['name'].startswith(('Anvil','RackBlade','Barrel')) or d['name'] in {'Bellows','BellowsHide','Tool'}))
issue('DM-01','P2','DesecratedMonastery','Ruined roof and column kit has blunt repeated profiles',
'Gatehouse, both prayer halls, Cloister and associated roof wreckage; representative East hall (63,6,-899), West hall (-95,5,-900), Cloister (74,6,-1050).',
'T-shaped column capitals, rectangular roof strips and identical straight eaves remain easy to read as constructed Parts. Broken roofs often end in broad flat plates rather than fractured tile, snapped rafters and supported eaves.',
'Author a small ruined-temple mesh kit with base/shaft/capital, bracket junctions, intact and broken tile/eave sections and two or three snapped rafters. Reuse material scale and architecture language from the Han/lobby kit, but keep the monastery ruin identity. Replace visual families rather than individually ornamenting hundreds of Parts.',
'Normal-camera approaches to both halls and Cloister show varied supported roof breaks and legible capitals; silhouette improves without changing paths, sightlines, shelter or foe posts.',
[S+'MonasteryRuins.luau:54',S+'MonasteryHalls.luau:1'],['q_d04_east_hall','q_d05_west_idol','d16_cloister_garth','d24_idol_close'],pred=lambda d:d['path'].startswith('Workspace.Map_DesecratedMonastery.') and d['name'] in {'Column','ColumnBase','Bracket','Tiles','Rib','Rafter','Eave','FallenEave','FallenRoof','EaveHorn'})
issue('DM-02','P2','DesecratedMonastery','Ruin walls and rubble repeat square construction breaks',
'Courtyard perimeter, prayer halls, Cloister galleries and south road.',
'The masonry has material detail, but many damaged walls end at square courses/coping blocks; small rubble is mostly rectangular scatter. Repetition weakens the feeling of a naturally collapsed monastery.',
'Add a few authored broken wall crowns, exposed brick cores, wedge/fractured rubble piles and root-to-wall transitions. Keep selected intact courses and open negative space. Match the current walkable boundaries and approved Cloister shelter; do not erase all modular construction.',
'Compare the same route cameras; varied fracture silhouettes and convincing supports, no new collision lips or cover affecting encounters.',
[S+'MonasteryRuins.luau:24'],['q_d03_courtyard','q_d04_east_hall','d16_cloister_garth','d13_south_road'],pred=lambda d:d['path'].startswith('Workspace.Map_DesecratedMonastery.') and d['name'] in {'Course','Coping','CopingRidge','Rubble'})
issue('DM-03','P1','DesecratedMonastery','Both prayer-hall idols are unrecognizable boxes',
'West IdolBody (-95,5.2,-900); East IdolBody (111,5.2,-902), plus displaced heads.',
'The shrine focal points consist of a torso block and a detached cuboid head. They do not communicate a carved destroyed idol or a recognizable sacred figure.',
'Create one original shattered devotional statue with a clear head/hand/robe fragment and two placement variants. Use sculpted fracture surfaces, a fitted dais and a few matching chips. Preserve the existing cover volumes and traversable side aisles.',
'At hall entry a player can recognize a desecrated idol without a label; broken pieces share believable anatomy and material scale.',
[S+'MonasteryHalls.luau:76'],['q_d05_west_idol','d19_idol_east','d24_idol_close'],pred=names('Workspace.Map_DesecratedMonastery.','IdolBody|IdolHead|IdolDais'))
issue('DM-04','P2','DesecratedMonastery','Bell tower and fallen bell read as a frame and capped drum',
'Tower (64,0,-772); fallen bell (58,4,-843).',
'The tower is four square posts, a diagonal beam and a plate roof shard. The fallen bronze bell is assembled from solid cylinders with no believable hollow mouth, split lip, hanging crown or relief.',
'Reuse/derive a damaged version of AsuraFoundryKit.Foundry_Bell and its bronze treatment; add a fractured mouth, crown and impact rubble. Build a small ruined belfry frame with credible joints and broken eaves. Keep these distinct from the new Foundry wing, which already has an authored bell.',
'Bell recognized on its side from the courtyard; hollow mouth and impact damage read up close; tower silhouette has credible failure points.',
[S+'MonasteryLandmarks.luau:40',S+'MonasteryLandmarks.luau:54'],['d17_bell_tower','d18_fallen_bell'],pred=lambda d:d['path'].startswith(('Workspace.Map_DesecratedMonastery.BellTower.','Workspace.Map_DesecratedMonastery.FallenBell.')))
issue('DM-05','P2','DesecratedMonastery','Courtyard cauldron is a solid disc stack',
'IronCauldron at (0,4,-836).',
'The ritual vessel is built from cylinder discs and cuboid legs; the rim/body do not have the silhouette of a cast vessel.',
'Reuse a suitably scaled HanCauldron or an original damaged bronze variant, retaining the glow and safe perimeter. Keep ember intensity below telegraph importance.',
'Reads as an open vessel from normal camera, fits the same footprint and does not hide nearby enemies.',
[S+'MonasteryLandmarks.luau:65'],['q_d03_courtyard','q_d07_bridge'],pred=prefix('Workspace.Map_DesecratedMonastery.IronCauldron.'))
issue('DM-06','P2','DesecratedMonastery','Toppled pagoda remains a stack of cubes and plates',
'Grave field, base (-62,6,-1052), broken tiers extending west to about x=-105.',
'The grave-field landmark lacks convincing storey construction and crushed connections; the standing tier is a large plain box beneath a simple roof.',
'Author a damaged stupa/pagoda module with carved storey openings and interlocking broken eaves, then lay matching tiers through an impact scar. Keep the grave path and existing cover clearance.',
'Recognizable as one collapsed building, with shared construction and supported debris rather than unrelated boxes.',
[S+'MonasteryLandmarks.luau:82'],['q_d09_graves'],pred=prefix('Workspace.Map_DesecratedMonastery.ToppledPagoda.'))
issue('DM-07','P3','DesecratedMonastery','Six grave stupas have a ball-on-box silhouette',
'Grave field around x=-130..-26, z=-998..-1108; exact six assemblies in ledger.',
'The bases, spherical domes and thin pole spires read as primitive markers at close range. This is secondary to idols and bosses.',
'Create two weathered funerary marker variants with tiered profiles, cracked inscription faces and occasional broken finials; scatter sparingly with settled bases.',
'Grave markers read at walking distance and do not obscure the grave path or cache clues.',
[S+'MonasteryLandmarks.luau:97'],['q_d09_graves'],pred=prefix('Workspace.Map_DesecratedMonastery.GraveStupas.'))
issue('DM-08','P2','DesecratedMonastery','Secret mausoleum shell is unfinished',
'Mausoleum walls x=-115/-105, y=5,z=-1060; flat roof at (-110,9,-1060).',
'Two thin side wall boxes and a flat lid surround a plain cache; the reward destination has no convincing tomb facade, entrance or roof construction. Nearby seal dressing exists and should be kept.',
'Integrate a compact ruined tomb entrance with carved lintel, sealed-door remnants and a damaged roof supported by the existing walls. Tie in existing talismans and broken seal instead of replacing the entire secret.',
'The clue, entrance and reward form one believable small structure; prompt visibility and original route remain intact.',
[S+'LootWorld.luau:43'],['q_d10_mausoleum'],pred=names('Workspace.WorldDiscoveryCaches.','MausoleumWall|MausoleumRoof'))
issue('DM-09','P2','DesecratedMonastery','Waterfall secret is a glass screen between rock boxes',
'SecretWaterfall (-140,14,-835); AlcoveRock x=-146/-134,y=8,z=-840.',
'A single 12×25×0.5 Glass plate and two cuboid rocks serve as the waterfall/alcove facade. The side view exposes the thin plane and weak connection to a water source and catch basin.',
'Author a restrained ribbon/water-sheet effect with an upstream rock notch, mist at impact, wet stone and a basin/drainage route. Build fitted alcove rock around the cache. Keep query/collision and the concealed route intact.',
'Front and side walking views show a grounded cascade and continuous water flow; cache remains discoverable and reachable. Hidden-route traversal still needs a normal-input check.',
[S+'LootWorld.luau:33'],['d15b_waterfall'],pred=names('Workspace.WorldDiscoveryCaches.','SecretWaterfall|AlcoveRock'))
issue('DM-10','P2','DesecratedMonastery','Twin Sentinels arena lacks a finished setting',
'Large battle floor around (300,0,-955).',
'The current Bull and Zhao are imported templates and look substantially stronger than the mostly empty grey battle platform around them. The floor and distant cliff do not yet establish a distinct sentinels courtyard.',
'Add a perimeter composition of ruined fortified temple architecture, broken ceremonial standards and a deliberate entry/reveal. Use the Bull/Zhao scale as reference. Keep the central duo footprint clear and retain camera retreat space, encounter bounds and the ridge approach.',
'Entry and 360-degree normal-camera views feel like a defended courtyard rather than a test pad; both bosses remain fully readable together.',
[S+'BossArenas.luau:1',H+'WorldDefinitions.luau:1'],['d12_twins_arena','d22_twins_both'],points=[('Area:TwinSentinels arena',[300,0,-955])])
issue('BP-01','P2','BambooPass','Baize arena needs a deliberate edge and encounter identity',
'Arena approach (0,0,-1380), main court around (0,0,-1470), moon gate south.',
'The new stone/timber perimeter bays are present, but the broad tiled court and thin grass border still feel uniform and disconnected from a mythic frost beast. The open floor itself is necessary for the fight.',
'Keep the recent perimeter upgrade. Add a restrained frost boundary, damaged shrine/court details, scuffed or broken paving at the margins and layered bamboo/rock transitions outside the fight lane. Use a few strong focal props instead of filling the arena with obstacles.',
'Normal camera reads court boundaries and a frost-beast setting at entrance; pounce landings, sidesteps and camera remain clear.',
[S+'BambooDressing.luau:1',S+'BossArenas.luau:1'],['b12_arena','b14_boundary','b15_moon_gate'],points=[('Area:Baize arena',[0,0,-1470])])
issue('LT-01','P1','Ash / Crypt / Citadel','Exploration lighting hides route and prop form',
'Ash Antechamber/Hall/Proving Court; Crypt ossuary/pit route; Citadel descending saddle stair.',
'These routes fall into large near-black shapes in normal profile captures. Matched Ash/Crypt camera retakes at QualityLevel.Level21 still have the problem, and ordinary-key walks reproduce dark Ash/Citadel approaches. Bright arena pools do not light the approaches. This is a finding on this Mac/Studio setup, not a universal device conclusion or a test of active combat profiles.',
'Add controlled local fill/rim lights and visible light fixtures at turns, stair edges, niche faces and court thresholds; retune local exposure/contrast only after matched captures. Keep night/dusk palettes and bright telegraphs. Test exploration, active encounter and unbound profiles independently on Windows and low/high device settings.',
'Player feet, next traversable edge, prop silhouette and enemy silhouette remain legible without attack effects; no blown-out lanterns or flattened atmosphere. Use identical camera/display conditions for comparisons.',
[H+'EnvironmentProfiles.luau:35',S+'CryptDressing.luau:78',S+'CitadelDressing.luau:1'],['qh_a02_antechamber','qh_a09_proving_court','qh_k06_ossuary','qh_k07_pit','w04_ash_after','w07_citadel_before'],points=[('Area:Ash hall',[0,4,-1800]),('Area:Crypt ossuary',[378,3,940]),('Area:Citadel saddle stair',[0,-10,-2568])],evidence='Normal-profile assisted captures at Automatic and Level21, plus ordinary-key samples; not device profiling')
issue('AC-01','P2','AshColosseum','Champions hall and facade still read as block architecture',
'Antechamber -1712..-1768, Champions hall -1776..-1877, facade z=-1877.',
'Long straight walls, rectangular piers and slab jambs have little ruin construction detail. Imported arches/statues already exist elsewhere, making these approach elements look unfinished. Some ground/tier mass is already Terrain; this finding does not treat hidden layout boxes as visible art.',
'Use a restrained ruined arcade kit: shaped piers/capitals, fractured wall crowns, soot and ash grounding, a stronger facade with readable central passage. Reuse existing AsuraRuinArch and stone language, then author only missing transitions. Keep doorway width and camera setback.',
'Approach reads as a ruined martial arena with coherent construction under normal lighting; original hall encounters and fog-gate clearance unchanged.',
[H+'AshColosseumLayout.luau:25',S+'ColosseumDressing.luau:28'],['qh_a03_champions_n','qh_a04_champions_s','a11_facade_diagnostic'],pred=lambda d:d['path'].startswith('Workspace.Map_AshColosseum.Structure.') and d['name'] in {'AnteWall','AnteFront','AnteBack','HallWall','BrokenWall','Facade','GateTower','GatePassage','VictorJamb','ToppledColumn'})
issue('AC-02','P2','AshColosseum','Last-stand props need recognizable sculpted forms',
'Fallen champion (24,1.4,-1702); spears and shields in hall margins z=-1782..-1878.',
'The fallen champion is one 8×3×3 block while its standing counterpart uses an imported statue. Spears are unheaded narrow beams and shields are undetailed cylinders.',
'Use a broken variant of the standing statue and a small shared weathered weapon/shield kit. Partially bury props in ash with impact orientation; retain clean playable center lanes.',
'Player can identify the collapsed champion and last stand from normal walking distance; source statues and fragments visibly match.',
[S+'ColosseumDressing.luau:32'],['a01_ash_entry','qh_a03_champions_n','qh_a04_champions_s'],pred=names('Workspace.Map_AshColosseum.ColosseumDressing.','FallenChampion|FallenSpear|DiscardedShield'),evidence='Static constructor + live instance inventory; dark/partial views limit close-face assessment')
issue('AC-03','P2','AshColosseum','Shen arena perimeter has weak colosseum hierarchy',
'Battle area x=-60..60,z=-1895..-2025; tiers and south Victor gate around it.',
'The bright open battle floor is surrounded by low dark/rocky mass and isolated arches. The overall bowl, spectator tiers and Victor gate are less legible than the name and boss importance suggest.',
'Dress the existing perimeter with readable stepped stone seating/retaining fronts, broken arcade clusters, ash deposits and a strong south exit focal point. Preserve open sky, low podium, all combat clearances and the existing Terrain mass.',
'At entry and from the center the arena reads as one ruined colosseum; walls never crowd the camera in either Shen form.',
[H+'AshColosseumLayout.luau:55',S+'ColosseumDressing.luau:34'],['a06_arena','a08_victor','a11_facade_diagnostic'],points=[('Area:Shen arena',[0,0,-1960])])
issue('SD-01','P1','SanctuaryDepths','Crypt ceiling and enclosing walls need real architectural form',
'Nave roof (492,47,1010), ossuary roof (380,47,874), ribs x=364..620 at y44; high flat enclosure walls.',
'The promised ribbed vault is actually two flat ceiling slabs with 17 straight beams. The exposed slab ends and flat enclosing walls leave a box-room impression, particularly at the nave/arena transition. The Titan hall is intentionally open to sky and should remain so.',
'Build an original modular crypt kit: real arch-shaped ribs, a few broken vault bays, heavy imposts, fitted wall recesses and settled cracks/root intrusion. Dress the current envelopes without lowering camera clearance or roofing over the Titan arena. Use diagnostic views only to judge geometry; validate final art under real lighting.',
'Nave/ossuary read as a constructed ancient burial space from player height; no disconnected overhead strips or visible slab cut edges on the intended route.',
[S+'CryptDressing.luau:35',H+'SunkenCryptLayout.luau:1'],['k04_nave','k12_vault','k16_vault_diagnostic','w05_crypt_after'],pred=lambda d:d['path'].startswith('Workspace.Map_SanctuaryDepths.') and d['name'] in {'VaultRib','VaultShell','CryptWall','BalconyWall'})
issue('SD-02','P1','SanctuaryDepths','Ossuary skulls are 60 featureless spheres on 20 flat plaques',
'West wall x≈359, z790..1040 excluding pit span; all 80 pieces listed.',
'Close inspection confirms pale balls in rows against rectangular black panels. They read as dots, not skulls, bone shelves or carved niches.',
'Create a small skull/bone kit with actual cavities and a stone niche frame, varied orientations and a few missing/chipped examples. Bake dense clusters into low-cost shelf assets. Keep respectful stylization consistent with the game and avoid unnecessary gore.',
'Ossuary reads at walking distance as burial storage; repeated shelf modules have controlled variation and correct scale.',
[S+'CryptDressing.luau:42'],['k06_ossuary','k14_skulls_diagnostic','k18_reliquary_diagnostic'],pred=names('Workspace.Map_SanctuaryDepths.CryptDressing.','Skull|BoneNiche'))
issue('SD-03','P2','SanctuaryDepths','Sarcophagi and crossing lids are plain rectangular masses',
'Six nave coffins, e.g. (384,1.5,1012); seven pit stepping lids at x366,z≈855..895.',
'The tombs have no separate lid profile, carved end, handles, fracture detail or burial identity. The pit crossing uses tall cuboids whose visible tops also lack lid construction.',
'Author a matching sarcophagus/lid set with two damaged variants, funerary relief and fitted bases. Keep the seven crossing top heights, widths and distances exactly; render only the exposed portions around existing collision.',
'Coffins recognizable in normal lighting and crossing remains equally traversable with no collision seam or misleading lip.',
[H+'SunkenCryptLayout.luau:25',H+'SunkenCryptLayout.luau:60'],['k05_sarcophagi','k07_pit','k15_sarcophagus_diagnostic'],pred=names('Workspace.Map_SanctuaryDepths.Structure.','Sarcophagus|SarcophagusLid'))
issue('SD-04','P2','SanctuaryDepths','Titan chains are loose solid blocks rather than linked restraints',
'Four arena corners around x434/606,z794/966; 24 links and four anchors.',
'Each chain link is a solid cuboid scattered on the floor, with no hole or connected sequence. Large anchor blocks do not visually explain a restrained giant.',
'Use open forged links in connected slack runs, broken end links and fitted anchor rings/stone sockets. Bake/static-place these decorative chains; a physics chain is unnecessary. Relate thickness to the Titan model after its scale is settled.',
'Each run reads as one broken restraint from fight distance; no snagging/query changes and no simulated prop instability.',
[S+'CryptDressing.luau:61'],['k13_chains','k17_chains_diagnostic'],pred=names('Workspace.Map_SanctuaryDepths.CryptDressing.','ChainLink|ChainAnchor'))
issue('SD-05','P2','SanctuaryDepths','Flooded pit needs believable water and shore treatment',
'Pit x356..404,z850..900; PitWater near y=-12.',
'The water is a flat Glass sheet in a sharp rectangular cut with a weak shoreline/wetness transition. It does not yet sell a sunken flooded crypt.',
'Keep the pit envelope and crossing geometry, but add a continuous wet rock/stone waterline, restrained ripple surface, submerged rubble silhouettes and localized mist. Keep fall/readability cues distinct from walkable tops.',
'Ordinary camera clearly distinguishes water, pit edge and all seven stepping lids in low and high rendering settings.',
[H+'SunkenCryptLayout.luau:18',S+'CryptDressing.luau:76'],['qh_k07_pit'],pred=names('Workspace.Map_SanctuaryDepths.Structure.','PitWater'))
issue('SD-06','P3','SanctuaryDepths','Thirty candles remain unshaped rods',
'Six candle clusters: four nave/gallery sites and the reliquary at (366,0.4,812).',
'Close views show straight square candle rods lit by one cluster glow, with little wick, flame or pooled wax detail.',
'Create two or three simple wax silhouettes with dark wicks, tiny flame treatment and a shared wax-drip base. Keep cluster lighting restrained and avoid many independent dynamic lights.',
'Read as candles up close without competing with combat indicators; no new effect lifetime or streaming cleanup problems.',
[S+'CryptDressing.luau:53'],['k15_sarcophagus_diagnostic','k18_reliquary_diagnostic'],pred=names('Workspace.Map_SanctuaryDepths.CryptDressing.','Candle'))
issue('CP-01','P1','CelestialPagoda','Oracle throne is a box chair beneath a small canopy',
'EmptyThrone (-140,17,-2280), back at y23, on throne loft.',
'The encounter-story focal prop is a six-stud cube seat, flat rectangular back and simple cushion. Its silhouette is dramatically weaker than the pagodas behind it.',
'Author a distinct imperial oracle throne with a carved seat/back, worn lacquer/gold, a coherent canopy and a recognizable void/star motif. Fit it to the existing loft and preserve the lore point/access route.',
'Seat reads as a throne from the loft entrance and supports the Oracle identity without floating details or obstructed walking space.',
[H+'CelestialPagodaLayout.luau:51',S+'PagodaDressing.luau:84'],['p07_throne','p14_throne_front'],pred=lambda d:d['path'].startswith('Workspace.Map_CelestialPagoda.') and d['name'] in {'EmptyThrone','ThroneBack','ThroneCushion'})
issue('CP-02','P2','CelestialPagoda','Great bell is an unadorned solid cylinder',
'GreatBell (60,11,-2276) and frame posts x54.5/65.5.',
'It reads as a hanging drum with flat closed ends. There is no hollow flared lip, hanging loop or carved bronze relief.',
'Reuse the existing Foundry_Bell mesh at a fitting scale, with an imperial patina/inscription variant and credible suspension. Dress its frame with bracket joints and a clapper if visible.',
'Bell silhouette reads from forecourt and close side views; frame connects to the crown and stays outside fight clearance.',
[S+'PagodaDressing.luau:88'],['p08_bell'],pred=names('Workspace.Map_CelestialPagoda.PagodaDressing.','GreatBell|BellFrame|BellPost'))
issue('CP-03','P2','CelestialPagoda','Lotus pool looks like a rectangle of water and discs',
'Pool (70,-25.94,-2214), 22 pads on the gorge floor.',
'The water boundary is perfectly rectangular and the lotus pads are flat cylinders with no leaf notch, stems or flowers. The pool has little believable bank construction.',
'Create a few notched leaf/flower variants, add a coherent stone or broken garden rim, wetness and a drain/source cue. Keep the entire feature off the narrow rafter route and preserve the gorge floor.',
'Reads as an abandoned lotus garden from above and bank height with no false walkable surfaces.',
[S+'PagodaDressing.luau:70'],['p05_pool'],pred=names('Workspace.Map_CelestialPagoda.PagodaDressing.','LotusPool|LotusPad'))
issue('CP-04','P2','CelestialPagoda','Gallery, rafters and loft need crafted timber junctions',
'West gallery (-88,-11,-2210), beam (-37,-6,-2228), central rafter, throne loft (-130,17,-2265).',
'The traversal idea is distinctive, but wide flat decks, square rails/posts and straight beams have little joinery, bracket logic or broken architectural context. Large horizontal areas can feel like floating platforms.',
'Dress the existing volumes with fitted beam ends, timber braces, authored rail bays and a few hanging prayer cloths/lantern clusters; establish how the gallery was part of a ruined building. Reuse lobby timber pieces scaled coherently. Preserve narrow-beam width, all landing heights and climb/jump distances.',
'Player can read support and destination while traversing; no new railing or ornament blocks the existing movement route/camera.',
[H+'CelestialPagodaLayout.luau:1',S+'PagodaDressing.luau:77'],['p03_gallery','p13_rafters_clear','p14_throne_front'],pred=lambda d:d['path'].startswith('Workspace.Map_CelestialPagoda.Structure.') and d['name'] in {'EaveGallery','GalleryPost','GalleryRail','RafterBeam','RafterEnd','RafterPost','LanternRafter','ThroneLoft','LoftPost','LoftRail'})
issue('CP-05','P2','CelestialPagoda','Wu arena has little ritual identity at floor level',
'Open hall centered (0,0,-2380), between the four imported pagodas.',
'The skyline and guardians are good, but the very broad uniform floor and widely spaced columns leave a weak focal composition around the small fallback Wu. Boss replacement will help; floor-level ritual context is still missing.',
'After Wu scale is settled, add a restrained inlaid celestial diagram, damaged ritual stations and hanging cloth/altar clusters at the margins. Retain open telegraph ground, camera room, teleport destinations and the good imported pagodas.',
'Entry shot clearly frames the Oracle and ritual space; dark effects remain distinct from ground markings and no prop occupies intended teleport/attack lanes.',
[H+'CelestialPagodaLayout.luau:1',S+'PagodaDressing.luau:28'],['p09_arena','p10_wu','w06_pagoda_after'],points=[('Area:Wu open hall',[0,0,-2380])])
issue('SC-01','P1','SkyCitadel','Ten chain posts float above the descending stair',
'x=±5.6,z=-2552,-2560,-2568,-2576,-2584, plus ten connector beams.',
'Observed in normal-key traversal and close-up. At z=-2568, post center y=11.5 has bottom y=10 while neighboring stair top is about y=-10: roughly a 20-stud vertical mismatch. The decor formula y=-(z+2548)/2 rises while the authored stair descends. This is a placement defect, not an art-style preference.',
'Derive post feet and chain end positions from the same descending stair rise/run or sampled authored tread tops. Re-anchor all ten posts to the stair shoulders; ensure adjacent chain endpoints actually meet. Then replace straight rods with a restrained sagging chain/rope visual.',
'All post bottoms meet a supported surface at both sides and every step of the descent; no floating beams remain in normal approach/return views; collision layout remains unchanged.',
[S+'CitadelDressing.luau:79',H+'SkyCitadelLayout.luau:17'],['c01_bridge','c11_chain_clear','w07_citadel_before','w07_citadel_after'],pred=names('Workspace.Map_SkyCitadel.CitadelDressing.','ChainPost|Chain'),evidence='Visible placement defect + exact runtime coordinates + traced sign mismatch in source')
issue('SC-02','P2','SkyCitadel','Dragon perch chains and shed scales are primitive',
'Perch near (0,70,-2952); scale scatter x≈-60..60,z=-2900..-2930.',
'Eight perfectly straight beams radiate from one point on the rock pillar like spokes rather than broken chain runs. Twelve Glass cuboids stand in for shed scales; they are poorly tied to the new charcoal wyrm concept.',
'Author two or three static broken chain runs anchored in believable sockets and a small curved/scarred scale shard kit matching the final Wyrm material. Keep the natural rock perch and open flight space; no live chain physics required.',
'Perch reads as a former storm-dragon restraint/roost from the arena; close scale props resemble the production creature and never become bright misleading ground cues.',
[S+'CitadelDressing.luau:87'],['c08_scale','c09_perch'],pred=names('Workspace.Map_SkyCitadel.CitadelDressing.','PerchChain|ShedScale'),evidence='Perch beams observed; all 12 scale placeholders confirmed in source/runtime inventory, individual shard close-ups limited')
issue('SC-03','P2','SkyCitadel','Bridge and bastion edges need a weathered masonry finish',
'Cloud bridge (0,-20,-2604), stair gates and Last Bastion (0,0,-2704).',
'Good imported towers sit beside long plain cuboid bridge rails and battlement/rim strips. Low lighting amplifies the loss of profile and surface hierarchy.',
'Add fitted coping, damaged parapet modules, buttress/rail terminations and storm-worn joints, reusing the existing stone language. Keep bridge width, rim height, fall protections and summit flight space. Leave intentional open summit ground open.',
'Approach and return cameras show supported finished edges with readable drops; no new obstacle or camera collision along the narrow bridge.',
[H+'SkyCitadelLayout.luau:20'],['c03_gorge','c04_bastion','c10_summit','w07_citadel_after'],pred=lambda d:d['path'].startswith('Workspace.Map_SkyCitadel.Structure.') and d['name'] in {'BridgeRail','Battlement','SummitRim'})

# All identified issue families have an exhaustive listing against the captured inventory.
for f in F:
 if f['id']=='CP-04': f['images'] += ['p15_lantern_rafter','p16_rafter_stair','p17_west_stair']
 if f['id']=='SC-03': f['images'] += ['c13_heaven_stair']
 if f['id']=='LT-01': f['images'] += ['k19_gallery_stair']
routing_path=P/'production/routing.json'
routing=json.loads(routing_path.read_text()) if routing_path.exists() else {}
for f in F:
 if f['id']=='AP-01':
  f['title']='Historical fallback skins; existing boss models need intake verification'
  f['problem']='Historical snapshot, 5 November 2026: '+f['problem']+' On 6 November the creator confirmed all boss 3D models are constructed. These captures are not a request to regenerate them and do not prove their current integration status.'
  f['fix']='Use C00 to locate and inventory the existing creator-supplied boss assets. Record model creation as complete per the creator; check rig/import/runtime integration separately against current source and Studio. No boss model generation is assigned in this production plan. Preserve existing identities and combat behavior.'
  f['evidence']='5 November held base-form capture/runtime statuses; separate 6 November creator update says boss models are constructed. Current integration not reverified'
 f['production']=routing.get(f['id'],{})
by_id={f['id']:f for f in F}
for r in R:r['fix']=by_id[r['issue']]['fix']
(P/'findings.json').write_text(json.dumps(F,indent=2)+'\n')
cols=['issue','priority','region','kind','inventory_index','path','x','y','z','class_name','name','evidence','fix']
with (P/'instances.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=cols,lineterminator='\n');w.writeheader();w.writerows(R)
# Coverage describes captures, not completed movement challenges.
coverage=[]
layouts=[{'region':'DesecratedMonastery','zones':W['monastery']}]+W['layouts']
for l in layouts:
 for z in l['zones']:
  x0,x1=sorted([z['X0'],z['X1']]);z0,z1=sorted([z['Z0'],z['Z1']])
  hits=[v['id'] for v in V if v['region']==l['region'] and x0-.01<=v['conditions']['position'][0]<=x1+.01 and z0-.01<=v['conditions']['position'][2]<=z1+.01 and (z.get('Y0') is None or v['conditions']['position'][1]>=z['Y0']-.01) and (z.get('Y1') is None or v['conditions']['position'][1]<=z['Y1']+.01)]
  eyes=[v['id'] for v in V if v['region']==l['region'] and x0<=v['eye'][0]<=x1 and z0<=v['eye'][2]<=z1 and (z.get('Y0') is None or v['eye'][1]>=z['Y0']) and (z.get('Y1') is None or v['eye'][1]<=z['Y1'])]
  coverage.append(dict(region=l['region'],zone=z['Id'],name=z['Name'],bounds=json.dumps(z),capture_starts_in_zone='; '.join(hits),camera_eye_in_zone='; '.join(eyes),status='settled actor and/or scripted camera sampled inside zone' if hits or eyes else 'adjacent view/source only'))
with (P/'coverage.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(coverage[0]),lineterminator='\n');w.writeheader();w.writerows(coverage)
rejected={
's04_forge_tools':'scripted camera inside forge geometry',
'd02_hermit':'camera/roof obstruction and training card',
'd06_waterfall':'foreground obstruction plus modal',
'd08_cloister':'foreground roof and modal',
'c02_chain':'local avatar/foreground blocks view; replaced by c11',
'c03_gorge':'local avatar blocks most of frame; use normal-key walk',
's14_ascetic':'scripted camera inside the large fused asset, not a normal-camera defect',
'd01_landing':'avatar and onboarding obstruction; replacement available',
'd03_courtyard':'central onboarding modal',
'd04_east_hall':'central onboarding modal',
'd05_west_idol':'central onboarding modal',
'd07_bridge':'central onboarding modal',
'a04_champions_s':'local avatar obstructs; replaced by qh camera',
'a05_facade':'local avatar obstructs; replaced by qh/a11 camera',
'a10_proving_ring':'avatar silhouette; qh retake available',
'p04_rafters':'foreground/own avatar obstruction; replaced by p13',
'k08_reliquary':'scripted angle blocks route; diagnostic replacement available',
}
viewrows=[]
for v in V:
 status='rejected as primary evidence' if v['id'] in rejected else 'usable'
 if v['id'].startswith('d') or v['id'].startswith('q_d'):
  note='Training card may cover the center; assess unobscured geometry only.' if v['id'] in {'d14_hermit_front','q_d01_landing','q_d03_courtyard'} else ''
 else:note=''
 viewrows.append(dict(id=v['id'],region=v['region'],status=status,note=rejected.get(v['id'],note),eye=json.dumps(v['eye']),look=json.dumps(v['look']),stand=json.dumps(v['stand']),quality=v['conditions'].get('quality','Automatic (initial setting)'),diagnostic_fill=bool(v.get('diagnosticFill')),avatar_hidden=v['conditions'].get('localAvatarHidden',False),image=v['id']+'.jpg'))
with (P/'views.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(viewrows[0]),lineterminator='\n');w.writeheader();w.writerows(viewrows)
(P/'reviewed-evidence.json').write_text(json.dumps({'rejected_primary':rejected,'failed_capture_starts':['d15_waterfall: seeded off-route position fell/reset; no screenshot accepted','d21_gatehouse_ring: seeded unsupported start reset; replaced by d21b'], 'note':'These failed seeded positions do not establish an ordinary-route traversal bug.'},indent=2))

def source_link(ref):
 file,line=ref.rsplit(':',1)
 return f'[{file}:{line}](https://github.com/digontoroychowdhury101-cmd/asuras-path/blob/a29f8cf/{file}#L{line})'
md=['# Asura’s Path — environment and model audit','',
'Captured 5 November 2026 on source baseline `a29f8cf` (`ux/onboarding-overhaul`). This is a repair backlog with evidence, not an implementation change.','',
'## Main finding','',
'The game has several strong asset islands, but they sit beside older primitive character and prop systems. The highest-return work is to improve the three speaking NPCs, replace the Crypt’s focal props/architecture, correct the Citadel’s floating stair chains, improve night-route readability and redesign the six boss arenas at a larger scale. The creator confirmed on 6 November that all boss models are constructed; generation is complete, while their current in-game integration still needs reconciliation. Keep the recent Sanctuary, Foundry, bamboo, Han-tower and Bull/Zhao upgrades.','',
'## Production extension — 6 November 2026','',
'**[Start here: ownership, asset creation and complete prompts](production/README.md).** Every finding below now links to its human/Rodin or code/Blender workflow. The packet includes nine non-boss image-to-Rodin prompts (two optional), ten agent-built/reused kit briefs, eight general agent prompts, seven arena implementation prompts and six optional environment-concept prompts. The nine supplied reference images are preserved with the [art direction](production/ART_DIRECTION.md).','',
'**[Larger arenas](production/ARENAS.md):** the creator requests materially larger playable spaces and a monumental dark-fantasy world, beyond exclusively wuxia architecture. Earlier local-repair instructions to preserve an arena footprint are superseded for these six planned redesigns only. Their full gate/route/terrain/AI dependencies must migrate coherently; the old screenshots remain before evidence. Boss model creation is already complete per the creator.','',
'**Relay update:** [new Shen work and evidence status](production/RELAY_UPDATE.md). Source-line links below are pinned to the captured a29f8cf snapshot; current source/handoffs take precedence for implementation.', '', '## How to use this audit','',
'- [Visual gallery](gallery.html): full-size captures, region/evidence filters and issue references. Open locally in a browser.','- [Exact object ledger](instances.csv): every captured member of each flagged family, its Explorer path, inventory index and world XYZ. Duplicate names are distinguished by index and coordinates.','- [Zone coverage](coverage.csv), [camera/evidence ledger](views.csv), [raw visible inventory](visible-parts.json), [boss skin status](actors-final.json), [restoration proof](restoration.json).','',
'Family-member counts are the scope of a visual kit review, **not a claim that every listed Part is independently defective or must be deleted**. Area anchors describe missing composition rather than a missing named Instance. Priorities are art-production priorities: P1 first, P2 next, P3 polish. No FPS or memory conclusion follows from any count.','',
'## Evidence and limits','',
'- Two actual single-client local Studio sessions in the same disposable copy of the saved place (the second filled the coverage gaps). macOS 26.7.2 (25G332), arm64, Apple M1; Studio 0.746.0.7461264. This is the observed host, not an assumed machine specification.','- Initial Edit identity and post-tour Edit identity: **281 scripts, 2,248,845 source bytes, digest 146955571**. Canonical place SHA-256 stayed `077d992351103c108f5f884c32d914524180f053f6f81242e975ae9f7d88f917`.','- Seven regions inspected by seeded placement and scripted cameras, with held bosses and temporary session progression bypass. Seven short ordinary W-key samples used the normal camera from seeded starts. These are assisted visual inspections, not an earned full playthrough or proof that every secret is reachable.','- Camera FOV 70 for scripted captures; logical viewport 797×576, returned images 1494×1080. HUD was kept visible. Some early views include onboarding or local-avatar obstructions; rejected primary images are labelled in views.csv. Later observer photos temporarily hide only the local avatar. Normal-key captures keep the avatar visible.','- Initial rendering quality Automatic; later explicitly Level21/EditLevel21 for comparison/detail. Landscape tier Detailed. AutoFRM property read 1 in many captures; it is not a measured frame rate. Lighting profiles were otherwise left authored. Six `_diagnostic` images temporarily raise neutral fill, reduce Atmosphere density and disable the color correction to inspect forms; they must not be used as evidence of normal lighting.','- Runtime inventory contains 11,711 visible BaseParts with Transparency <0.98, including actors and a Terrain object; it is not a count of art defects, triangles, draw calls or Terrain voxels. Dynamic effects/streamed details outside captured views are not exhaustively measured.','- Base boss forms were spawned and held; attacks, animation deformation during combat, phase transitions, cosmetics on every body proportion, earned progression, multiplayer, live persistence and device profiling remain unverified here. The imported Bull/Zhao and current monks/swordsmen were confirmed present; this audit does not replay old missing-model findings for them.','- Invulnerability was seeded initially; off-route inspection placements caused resets and later ordinary enemies could damage the player. Health/quest changes in screenshots are local diagnostic state, not fairness evidence. Unsupported seeded camera/standing placements were excluded from traversal conclusions.','',
'## Work order','',
'1. Fix SC-01 placement and validate LT-01 lighting with matched Windows captures. These improve what players can actually read.','2. Use C00 to inventory the already constructed boss models and measure actual rigs. Run AR00 spatial planning and the AR01 Shen arena pilot; improve Lin/Gao/Hermit (AP-02) separately. No new boss-model generation.','3. Give the Crypt one coherent kit: SD-01 through SD-05. Prioritize architecture, skull niches and sarcophagi before tiny candles.','4. Replace reusable hero props: idols, bells, throne, altars, caches, ladders and smith tools. Reuse assets already in ServerStorage before generating more.','5. Complete the six larger arenas using AR01–AR06 and the regional kits, then finish the two undressed PvP rings. Preserve approved shelter/foe posts. Boss-arena expansion may change footprint/bounds/routes; keep unrelated interaction and PvP dimensions intact.','',
'## Findings by location','']
for f in F:
 md += [f"### {f['id']} · {f['priority']} · {f['title']}",'',f"**Where:** {f['region']}. {f['where']}",'',f"**What is lacking:** {f['problem']}",'',f"**Fix:** {f['fix']}",'',f"**Done when:** {f['acceptance']}",'',f"**Evidence:** {f['evidence']}. Ledger scope: {f['family_members']} captured family components and {f['area_actor_anchors']} actor/area anchors.",'', '**Views:** '+', '.join(f'[{x}]({x}.jpg)' for x in f['images'])+'.', '', '**Source:** '+', '.join(source_link(s) for s in f['sources'])+'.','']
md += ['## Existing work to preserve','',
'- Sanctuary imported sacred tree/ascetic, carved lobby kit, lanterns, colonnades, Promenade ring finish, supported Eaves deck and Reliquary vessel/shelter. The root close-up s14 is a rejected inspection camera, not a claim of a broken normal camera.','- Bamboo living foliage/ground patches, Foundry_Bell/KilnStack/Crucible/SlagHeap/BellMould/HallWall, ridge gate framing, new frost steps/supports and the new arena stone/timber bays. The former bare arena strip/support findings are already addressed. The current moon gate is a dressed segmented arch; it is not treated as an urgent rebuild.','- Han high-detail gates/pagodas/watchtowers and bixie guardians in Pagoda/Citadel, real Terrain cliffs/perch and existing imported ruin arches/statues in Ash. Invisible collision fallback boxes are not visible-art findings.','- Current template-skinned Iron Bull, General Zhao, Corrupt Wandering Monk, Cursed Swordsman and Hollow Bell Warden library assets. Only held Bull/Zhao base appearance was examined, not full animation/fight quality.','- Creator-approved Cloister altar shelter and foe positions. All proposed dressing must preserve their gameplay effect.','',
'## Missing context and explicit coverage gaps','',
'Every named campaign layout zone has a source/inventory entry in coverage.csv; columns distinguish settled actor samples from scripted camera positions inside its bounds. All 53 named campaign zones have at least one of these; the western eave gallery had a camera inside it while the seeded player stood below the platform, so it has no earned traversal claim. A nearby shot is not a completed traversal. Sanctuary service areas, main stair, terrace, ascetic/canopy, forge, Eaves, descent, reliquary, duel ring and spectator balcony have dedicated views. All three PvP ring settings were observed; no match was played.','',
'Hidden cache fronts, every roof underside, every return direction and every possible camera angle were not all walked. Phase-2 forms and boss cinematics were not triggered. Sunken Crypt shaft details and the Citadel rim need a second normal-input pass after lighting/asset fixes. This document records all identified issue families and matching inventory instances; it does not certify that no other defect exists.','',
'## Restoration and verification','',
'The helper restored its saved session boss flags, original placement/invulnerability value and seeded attribute, and despawned all audit-owned bosses. Diagnostic lighting and avatar overrides were released; Studio rendering preferences returned to Automatic. The Play session was then stopped. Edit mode contains neither QA_VisualAudit nor AsuraVisualAudit, and its digest matches the pre-tour digest. The canonical place file is byte-identical. No production source, asset, collision, enemy setting, profile store or published game was changed.','',
'| Evidence type | Result |','|---|---|','| Static/source review | Art constructors, asset libraries and mappings examined; exact references above. |','| Local artifact checks | JSON/CSV, image references, source links and generated gallery checked. No gameplay regression suite claimed. |','| Studio integration | Actual boot, assisted captures, seven short keyboard/normal-camera samples, held model inspection and cleanup/digest checks. |','| Earned human playthrough / combat feel | Not established. |','| Multiplayer / live persistence | Not run; local mock persistence only. |','| Device performance profiling | Not run. Rendering-setting comparisons are appearance evidence only. |','',
'No place rebuild is required: this task only adds unmapped audit documentation/evidence and temporary tooling. Future art implementation must follow the pinned build/verification workflow and repeat normal-camera/encounter checks.','']
# Insert production routing directly into every finding block.
for f in F:
 route=f.get('production',{})
 if not route:continue
 hs=[x.split()[0] for x in route['assets'] if x.startswith('H')]
 pro=['**Production ownership:** '+route['method']+'. **Human input:** '+route['human_input'],'']
 if hs:pro += ['**2D → Rodin prompts:** '+', '.join(f'[{h}](production/prompts/{h}_IMAGE_TO_RODIN.md)' for h in hs)+'.','']
 pro += ['**Agent implementation:** '+', '.join(f'[{Path(x).stem}](production/{x})' for x in route['agent_prompts'])+'. **Reusable kits:** '+(', '.join(route['assets']) or 'No new model required')+'; see [asset briefs](production/ASSET_PROMPTS.md).','']
 # Source paragraph is unique to most findings but identical in a few; locate by the heading slice.
 start=md.index(f"### {f['id']} · {f['priority']} · {f['title']}")
 end=next((i for i in range(start+1,len(md)) if md[i].startswith('### ') or md[i].startswith('## Existing')),len(md))
 md[end:end]=pro
(P/'README.md').write_text('\n'.join(md))
# Browser gallery with a reviewable compact issue index and explicit capture provenance.
e=html.escape
index=''.join(f'<tr class="index-row" data-find="{f["id"]}"><td><a href="#issue-{f["id"]}">{f["id"]}</a></td><td>{f["priority"]}</td><td>{e(f["region"])}</td><td>{e(f["title"])}</td></tr>' for f in F)
sections=[]
for f in F:
 route=f.get('production',{})
 links=', '.join(f'<a href="production/{x}">{html.escape(Path(x).stem)}</a>' for x in route.get('agent_prompts',[]))
 hlinks=', '.join(f'<a href="production/prompts/{x.split()[0]}_IMAGE_TO_RODIN.md">{html.escape(x)}</a>' for x in route.get('assets',[]) if x.startswith('H'))
 prod=f'<p><b>Production:</b> {html.escape(route.get("method",""))}. {html.escape(route.get("human_input",""))}</p><p><b>Agent prompts:</b> {links}</p>'+(f'<p><b>Image → Rodin:</b> {hlinks}</p>' if hlinks else '')
 ims=''.join(f'<a href="{x}.jpg"><img loading="lazy" src="{x}.jpg" alt="{x}"><span>{x}'+(' — DIAGNOSTIC FILL' if 'diagnostic' in x else '')+'</span></a>' for x in f['images'])
 sections.append(f'<section class="issue" id="issue-{f["id"]}" data-search="{e((f["id"]+" "+f["region"]+" "+f["title"]).lower())}"><h2>{f["id"]} · {f["priority"]} · {e(f["title"])}</h2><p class="where">{e(f["region"]+" · "+f["where"])}</p><p>{e(f["problem"])}</p><p><b>Fix:</b> {e(f["fix"])}</p>{prod}<details><summary>Acceptance / evidence</summary><p>{e(f["acceptance"])}</p><p>{e(f["evidence"])}</p></details><div class="grid">{ims}</div></section>')
walk=json.loads((P/'ordinary-walks.json').read_text())
walks=''.join(f'<article><h3>{e(x["expected"])}</h3><div class="grid">'+''.join(f'<a href="{x["id"]}_{t}.jpg"><img loading="lazy" src="{x["id"]}_{t}.jpg"><span>Normal camera · {t} W key</span></a>' for t in ['before','after'])+'</div></article>' for x in walk)
allviews=''.join(f'<tr><td><a href="{r["image"]}">{r["id"]}</a></td><td>{e(r["region"])}</td><td>{e(r["status"])}</td><td>{e(r["note"])}</td></tr>' for r in viewrows)
gallery='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Asura’s Path — visual audit</title><style>
:root{color-scheme:dark}body{margin:0;background:#111315;color:#e9e7df;font:16px/1.6 system-ui,sans-serif}main{max-width:1320px;margin:auto;padding:28px}h1{font-size:36px;line-height:1.2}h2{font-size:24px}a{color:#dfbb7a}section,article{border-top:1px solid #424240;padding:24px 0}.where{color:#c8b68c}table{width:100%;border-collapse:collapse}td,th{padding:9px;border-bottom:1px solid #333;text-align:left}input{padding:14px;width:min(620px,90%);font:inherit;background:#222;border:1px solid #666;color:white}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:14px;margin:20px 0}.grid a{background:#202326;display:block;text-decoration:none}.grid img{width:100%;display:block}.grid span{display:block;padding:8px;font-size:13px}.notice{border-left:4px solid #dfbb7a;background:#22211d;padding:16px}details{margin:14px 0}nav{display:flex;gap:20px;flex-wrap:wrap}.hidden{display:none}
</style><main><h1>Asura’s Path<br>Environment & model audit</h1><p>5 November 2026 · source a29f8cf · one local Studio client · seven regions</p><nav><a href="production/README.md">Production plan & prompts</a><a href="production/ARENAS.md">Larger arenas</a><a href="README.md">Detailed report</a><a href="instances.csv">Exact object ledger</a><a href="coverage.csv">Zone coverage</a><a href="restoration.json">Cleanup proof</a></nav><p class="notice">Assisted visual tour with seeded placement, scripted cameras and held bosses. The seven keyboard samples use a normal camera from seeded starts. Images labelled DIAGNOSTIC FILL use temporary neutral inspection lighting; they do not show normal game lighting. No earned progression, multiplayer or performance certification. Production files were unchanged and the test is stopped.</p><h2>Issue index</h2><input id="search" type="search" placeholder="Filter findings: Crypt, boss, P1, chains…"><table><thead><tr><th>ID</th><th>Priority</th><th>Region</th><th>Finding</th></tr></thead><tbody>'''+index+'</tbody></table>'+''.join(sections)+'<h2>Ordinary-key samples</h2><p>Normal camera, W held 1.8 seconds from seeded starts. Boss bypass remained active; local enemies could still interrupt later samples. These are short appearance checks, not full route completion.</p>'+walks+'<details><summary>All capture files, including rejected primary views</summary><table><tr><th>Capture</th><th>Region</th><th>Use</th><th>Reason / limit</th></tr>'+allviews+'</table></details><script>document.getElementById("search").addEventListener("input",function(){let q=this.value.toLowerCase();document.querySelectorAll(".issue").forEach(s=>s.classList.toggle("hidden",!s.textContent.toLowerCase().includes(q)));document.querySelectorAll(".index-row").forEach(r=>r.classList.toggle("hidden",document.getElementById("issue-"+r.dataset.find).classList.contains("hidden")))})</script></main></html>'
(P/'gallery.html').write_text(gallery)
print(f'{len(F)} issue families; {len(R)} ledger rows; {len(V)} scripted captures; {len(coverage)} named zones; {sum(not (x["capture_starts_in_zone"] or x["camera_eye_in_zone"]) for x in coverage)} zones without an actor/camera sample')

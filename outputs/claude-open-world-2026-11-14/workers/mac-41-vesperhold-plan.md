# mac-41 Vesperhold plan — massing vs mesh kit, tiers, kit list (engineering lead, 2026-11-19)

Supersedes: nothing (first castle plan). Linked from CONTINUATION.md "Vesperhold — 2026-11-19". Work order:
workers/mac-40-vesperhold-verdict.md. Code map: GothicCitadel.luau / GothicMarch.luau (Codex e8be23c), read by mac-41r1.

## Frame and scale facts
- Local frame: origin = Overworld.Vesperhold (-2800, 650, -6400, yaw -90). Local +Z = approach (world -X, toward Snow Refuge),
  castle at local -Z, Y 0 = gate threshold (world 650). Snow Refuge altar (-3400, 620, -6400) is ~600 studs out.
- At FOV 70, 16:9, distance d: frame ~2.47d wide, ~1.40d tall. From ~620 studs: 45% width ~ 690 studs, 35% height ~ 300 studs.
  => the body (no spires) needs a ~650-700 stud frontage along local X and >= 300 visible height. Today: 343 x 435 bbox,
  curtains at x +-55..81, gatehouse 40-60 studs high. Exact eye = Codex's view-01 camera (work/vesperhold/camera.luau /
  document_views.py); the massing test computes the real fractions from it.
- Look-up rule: for the last 400 road studs the first parapet is >= 25 deg up: at 400 studs out it must stand >= ~190 above
  the eye. The road falls to about -18 on the viaduct, so the Tier-1 front parapet sits at about +190 (local Y).

## What stays as Part massing / collision (Luau keeps layout, walk paths, collision, shelter tags)
Kept (re-dimensioned to the tiers below, made invisible where a mesh clads them: Transparency 1, CastShadow false):
gate PortalWing / GateCoping, CurtainFooting, curtain masonry cores, stair/ramp parts, upper-ward foundation, WatchGallery
deck, nave/aisle/transept walls, piers, vaults with AsuraShelter (NaveVault, CathedralVault, AisleRoof, GateCoping), altar dais,
retaining walls, ArchiveBridge deck; March: pilgrimLane deck, viaduct deck + parapet + battered piers, posternWalk deck +
handrails, chapel/dwelling floors and walls, sealBridge plinths, waystone. Add a portal floor slab (2-stud gap z 1.5..3.65 today).
Becomes mesh kit (Part shells deleted where a kit piece covers them): every spire/needle/openSpire/belfry stage, tower upper
stages and battlements, tracery, lancets, greatWheel x5 (-> Rose_Window_Great / Rose_Window_Small), flyers, buttress
weathering, pinnacles, pitched roofs, gables, statue/niche dressing, viaduct arch vaults/tympana/guard piers, snag beeches
(-> withered trees), cart/journey dressing. Delete outright: white limestone cone-capped turrets, neat crenels, the two-palette
limestone material (Limestone 4415 parts), the stray red post in view 01.

## Tier / terrace layout (local studs; Y relative to the gate threshold)
| Tier | Floor Y | Front line z | Extent x | Front | Top of front |
|---|---|---|---|---|---|
| T0 gorge bastions | terrain (>= -150) | -10..-40 | -340..+340 | battered bastion faces + base arcade, buttress run into the gorge | 0 (road) |
| T1 gate terrace (the close) | +12 | -30 | -330..+330 | 3 stacked arcade galleries (arches 60/60/50) + balustrade + pinnacle row; great gate 26 tall in a 40-deep passage | +190 |
| T2 cloister terrace | +190 | -110 | -260..+260 | 2-level arcade gallery (arches 50/40), 8+ flying-buttress pairs springing toward T3 | +260 |
| T3 cathedral terrace | +260 | -180 | -200..+200 | west front: deep portal 28 tall, Rose_Window_Great 48 dia centred ~+300, lancet rows; nave ridge >= +330 | +330 ridge |
| Crown | — | -180..-330 | | 2 west towers to ~+690 / ~+640 (asymmetric), crossing spire ~+560, 6 tier-corner towers +300..+450, 8+ buttress-pinnacle towers +220..+300, 14+ gallery needles +150..+250, one broken east spire => >= 32 spires | ~+690 |
Walk route kept: viaduct -> great gate -> close (T1) -> ramp/stair flights -> T2 cloister -> stair -> T3 west portal -> nave.
Viaduct: existing deck path kept; becomes tall many-arched (30-stud bays, piers to terrain), balustrade, Hooded_Statue every
~30 studs both sides (>= 10), candle clusters at each plinth; near gate tower carries 2-3 torn crimson banners.
Graveyard: below the T0 bastions on the gorge-side shelf (flank view 05) + the chapel yard; gibbets on the gorge rim.

## Mesh kit (tools/blender/vesperhold/; studs = units; pivot foot-centre; every sub-mesh < 18k tris, never decimated)
Materials (procedural numpy/Blender bakes at 2048, one atlas per material; Metal map ALWAYS linked: black for non-metal,
mac-28 lesson): Vesp_Soot (black ashlar, value 0.08-0.15, grime streaks), Vesp_Charcoal (wet dark stone 0.15-0.25),
Vesp_Frost (ledge frost, separate top-face sub-mesh), Vesp_Iron (metal), Vesp_Verdigris (metal), Vesp_Slate (roof),
Vesp_Glass (stained crimson/amber; uploaded as a plain sub-mesh, set Neon + Color at runtime for glow), Vesp_Wax,
Vesp_Banner (crimson cloth, double-sided), Vesp_DeadBark (frosted), Vesp_Rope.
| Group | Pieces (size studs) | Subs per piece (tris each, cap 18k) |
|---|---|---|
| A arches/walls | Arcade_Bay_60 (40w x 60h x 14d), Arcade_Bay_50, Arcade_Bay_40, Arcade_Corner, Bastion_Face (40 x 80, battered), Balustrade_20, Parapet_Gothic_20, Cornice_20 | Stone 6-12k, Tracery 4-8k, Frost 1-2k |
| B buttress | Buttress_Pier (12 x 70), Flying_Buttress_40, Flying_Buttress_60, Pinnacle_Crocket_S/M/L (12/24/40 h), Finial | Stone 6-14k, Crockets 6-12k, Frost 1k |
| C spires/towers | Spire_Base_Oct, Spire_Belfry_Stage, Spire_Lucarne_Mid, Spire_Needle_Tip (crockets), Spire_Broken_Top, Tower_Corner_Stage | 8-16k each, stacked/instanced to 150-690 heights |
| D windows/portal | Lancet_Tall (8 x 40), Lancet_Pair, Rose_Window_Great (48 dia), Rose_Window_Small (16), Portal_Great (28h, 5 archivolts), Portcullis, Door_Iron | Stone 10-16k, Tracery 8-16k, Glass 1-4k, Iron 2-6k |
| E viaduct | Viaduct_Bay (30w x 120h pier + arch), Viaduct_Balustrade_30, Statue_Plinth | Stone 8-14k |
| F figures/props | Hooded_Statue_A/B (10 h), Gargoyle_A/B, Candle_Cluster_A/B, Brazier_Iron, Banner_Torn_A/B (8 x 30), Chain_Hang, Gibbet_Cage, Iron_Fence_10, Gravestone_A..D, Tomb_Slab, Rubble_Pile, Masonry_Chunk_A/B | 1-12k |
| G withered trees (own generator) | Dead_Oak_Gnarled (60-90), Dead_Pine_Snapped (60-80), Thorn_Twisted (25-40), Dead_Stump, Dead_Log | Bark 8-16k split by height band, Frost 1-3k |
Instancing: 32+ spires from ~6 spire modules; arcades from 4 bays; statues/candles/graves from variants.
Textures: procedural (numpy + baked Blender noise), consistent with the existing kits. CC0 downloads (Poly Haven / ambientCG)
or third-party tree generators are allowed by the creator per oversight, but any download needs the creator's own chat
approval in this session (my safety rule), so the first pass is fully procedural; THIRD_PARTY.md stays empty unless used.

## Lanes (max two workers, one heavy job)
| Lane | Model | Slot | Owns |
|---|---|---|---|
| mac-42 kit A-E: materials + architecture modules, headless Blender run, renders, manifest, upload pack | sonnet | HEAVY (Blender) | tools/blender/vesperhold/vesperhold_kit.py, assets/source/vesperhold/** |
| mac-43 massing rework to tiers/scale + viaduct + walk/collision + view-fraction test (source only) | sonnet | light | GothicCitadel.luau, GothicMarch.luau, Overworld.luau (Vesperhold ridge only), tools/test_vesperhold_massing.luau |
| mac-44 kit F + withered-tree generator (writes scripts while 42 runs; runs Blender after 42) | sonnet | light -> HEAVY | tools/blender/vesperhold/vesperhold_props.py, vesperhold_trees.py |
| mac-45 local atmosphere: eclipse, storm cloud, fog banks, grade, lightning, crows, candles glow, snow size fix | sonnet | light | EnvironmentProfiles (Vesperhold input only), WeatherController (ridge only), new client VesperholdAtmosphere if needed |
| mac-46 ONE cloud-window upload session: castle kit + mac-30 retone2 forest (101) | sonnet | HEAVY | assets/VESPERHOLD_KIT_UPLOADED.json, existing *_KIT_UPLOADED.json, kit_registry outputs |
| mac-47 loader reuse + kit placement + local Play: 7 views, frame time x3, MeshParts/tris, console | sonnet | HEAVY | GothicCitadel/March kit placement, SliceDressingService public clone helper, VesperholdKitRegistry wiring |
Acceptance numbers are the verdict's targets 1-8; the massing test asserts frame fractions, look-up angle, spire count,
buttress pairs, statue spacing, portal/door sizes and walkability (gate floor continuity).

## Added targets (oversight 1403f7c, ref_02..05) — plan update
Massing pass 2 (mac-48, light): (a) SPRAWL — the main citadel on pinnacle P1 (existing tiers) plus >= 2 more cliff pinnacles
(P2 chapter-house/belfry rock flanking north, P3 ossuary/watch rock south) each carrying a tiered keep built from the same
kit, linked by >= 3 arched viaducts at clearly different levels (V1 existing processional at road level; V2 mid-level
P1-T2 <-> P2 ~+150; V3 high P1-T3 <-> P3 ~+280), plus >= 2 distant spired outposts on far crags (spire stacks on rock,
skyline only, no walk); (b) GRAND STAIR >= 60 steps (rise <= 1.6, tread >= 2.5, width >= 24) from the last viaduct landing
up to the T3 glowing portal, landings every ~20 steps, Brazier_Post + Pedestal_Statue pairs every ~20 studs, Banner_Pole
pairs; it replaces part of the close->T2->T3 ramp route as the player's main climb (ramps stay as alternates);
(c) WATERFALL slots on the gorge walls under P1/P2 (>= 3 falls, 80-200 studs tall) + spray/mist emitters at the base;
(d) RUINED-ARCH VIEWPOINT at the 01/02 reveal (a broken gothic arch on the cliff edge framing the citadel, dead trees,
2 tattered banners, graves on the lower terrace). Test asserts all of these from layout data.
Kit additions (mac-44, heavy Blender): Banner_Torn_A/B + Banner_Pole (our sigil: crimson field, black six-spoked Asura
wheel enclosing a flame-eye, tarnished gold edging; NO tree emblem), Brazier_Post, Pedestal_Statue_Staff (hooded,
staff-bearing), Ruined_Arch (broken gothic arch 30-40 tall), Waterfall_Sheet (layered alpha cards, scrolling done at
runtime via TextureID offset is impossible on MeshParts -> use stacked translucent card meshes + ParticleEmitter mist),
Crag_Pinnacle rock shells (optional; terrain may carry them), plus group F and the withered trees from mac-41.
Upload readiness: GLBs must carry embedded textures for the importer to build SurfaceAppearance; embed Color/Roughness/
Metal as JPEG q90 and Normal as PNG, or share trim atlases so each piece uses <= 3 materials; report per-GLB size.
Atmosphere (mac-45, light, after mac-48): add (e) lightning flashes that briefly light the silhouette (Lighting brightness/
colour pulse + a far PointLight burst, local to the Vesperhold weight).

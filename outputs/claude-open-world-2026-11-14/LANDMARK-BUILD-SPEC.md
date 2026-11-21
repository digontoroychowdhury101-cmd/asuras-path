# Landmark build spec: from the creator's concept art to in-game Roblox (2026-11-21)

This is the design and build contract for the landmark loop. The concept art is in `outputs/claude-open-world-2026-11-14/concepts/` (committed, so both machines have it). Open each image before building its landmark. The art defines the silhouette, materials, palette and composition. Match it as closely as real-time Roblox allows.

## 0. How to build: the same way Vesperhold was built
Vesperhold was made procedurally in Blender Python on the Mac, not with AI image-to-3D. Do the same here:

**Builders:**
- Model each landmark as a kit script in `tools/blender/landmarks/<region>_<landmark>.py`, cloned from the Vesperhold builders: `tools/blender/vesperhold/vesperhold_kit.py`, `vesp_common.py`, `vesperhold_props.py`, `vesperhold_figures.py`, `vesperhold_gargoyles.py`, `vesperhold_trees.py`, `vesp_bake.py` and `vesp_embed.py`. Reuse `vesp_common` helpers rather than copying them.
- Geometry is real, built from welded primitives: prism-with-holes, sweep, loft and lathe. Arches are true pointed arches, mouldings follow curves, and tracery is cusped.
- Use triplanar UVs. Auto-split each sub-mesh at about 18k tris; never decimate kit geometry.
- Units: 1 Blender unit = 1 stud, Z up (Y up in the GLB). The pivot is the foot centre.

**Organic forms** (the giant face, the colossus pieces, the hand, lion statues, the dragon skull, gargoyles, roots):
- Sculpt them procedurally in Blender the way `vesperhold_figures.py` and `vesperhold_gargoyles.py` do: SDF/metaball blockout, then displacement and sculpt modifiers.
- Bake the high-poly onto an under-20k low-poly with `tools/blender/ingest_sculpt.py` or `vesp_bake.py`, following the section 4 procedure in NEXT-VISUAL-PASS-PROMPT.md.

**Textures:**
- Use CC0 Poly Haven textures through the same GitHub tooling as Vesperhold: **kevinbadi/blender-skills**, pinned at commit `b2f0f816d320b56ae86d52597a35284e0e6cc929`.
  - It is cloned at `work/third_party/blender-skills` and installed in `~/.claude/skills/`. Re-clone at that commit if it's missing.
  - Use its `polyhaven-texture-apply` and `polyhaven-material-swap` skills over the blender-mcp socket (127.0.0.1:9876, Blender in GUI mode). Send searches with `query`, not `categories`.
  - Do not use its Meshy skills. The creator's rule is free parts only.
- Tone-map every texture with the `tools/blender/vesperhold/vesp_polyhaven.py` approach: desaturate, set value targets, add grime runs and lift roughness to matte. Then match the concept's palette.
- Reuse the 8 Vesp_* materials for anything gothic. Add new materials per region:
  - red-lacquer timber with gold leaf
  - oxidised bronze and verdigris
  - bleached salt sandstone
  - blue glacier ice (a translucent SurfaceAppearance plus Terrain Glacier)
  - ember-cracked basalt (emissive cracks as a separate Neon or LightEmission sub)
- Log every Poly Haven asset in a `THIRD_PARTY.md` next to the landmark's outputs (same format as `outputs/vesperhold/THIRD_PARTY.md`).

**Render before importing.** Render a contact sheet per kit (`vesp_contact_sheet.py` pattern) and compare it side by side with the concept image. Iterate until the silhouette and material read match.

**Import:**
1. Export GLB: meshes plus material names, maps embedded with `VESP_EMBED=jpeg`, and each GLB under 20 MB (`glb_split.py`).
2. Upload with `tools/assets/upload_batch.py` (pilot piece first; ledger in `workers/`).
3. Register the pieces in a registry Luau.
4. Place them through a layout module plus SliceDressingService (or VesperholdKit for the Vesperhold extension).

**Raw sources:** `assets/source/` and `*.blend` are gitignored. When a landmark's kit is finished, push its raw outputs (GLBs, maps, renders; no single file over 100 MB) to an asset snapshot branch, `landmark-assets-2026-11-21`, the same way `codex/vesperhold-assets-2026-11-19` holds Vesperhold's, so the other machine can rebuild it.

## Shared rules for every landmark
- **Placement:**
  - Every landmark gets a pure-number layout module (`src/shared/LandmarkLayout.luau`, Vesperhold style: local frame, origin, yaw, slots) plus a Lune test.
  - The test checks that it sits inside its region box (`src/shared/Overworld.luau`), doesn't overlap altars, collectibles or roads, and keeps 250 studs or more from the existing landmarks unless it's meant to attach.
  - Sample the terrain height in Studio before fixing Y.
- **Composition:** each landmark gets a road sightline, a lit focal point (lanterns tagged `AsuraLanternLight`), a foreground frame and one ambient life kind.
- **Budget:** at most 250k tris per landmark, 18–20k per MeshPart, 1024 maps, and no new shadow-casting lights. LOD comes from `RenderFidelity=Automatic`.
- **Collision:** walkable shells use Hull or PreciseConvexDecomposition only on floors and stairs you walk on. Decor gets `CanCollide=false`.

## 1. Bellwood (Forest): the Fallen Giant's Eye and the hidden Sunken Temple ★ first
**Images:** `bellwood_1_fallen_giant_face.webp` (3/4 key art), `bellwood_2_fallen_giant_face_turnaround.webp` (side, front and back), `bellwood_3_sunken_temple_reveal.webp` (what you see after the tunnel). Also see the Bellwood row of `saltreach_1_region_sheet.webp` for the root-split gate and alternative angles.

**Gameplay intent (creator):** the player finds a colossal fallen stone face lying on its side in the forest. **The real temple is only seen after walking through the eye of the fallen giant's face.** The tunnel through the eye socket leads into a hidden, cliff-enclosed lake basin, where the sunken temple is revealed in one composed shot.

**Fallen Giant's Face**, about 45 studs high, 130 long and 90 deep:
- **The face:**
  - Granite with crack networks and heavy moss on its upward planes.
  - Eyes closed, a broad nose and a slack mouth, lying on its side (turnaround image).
  - The eye/cheek socket opens into a **walkable tunnel** at least 14 studs wide and 16 high, with a rubble-strewn dirt floor and dark rock walls.
- **The crown and headdress:**
  - A red-lacquered band with gold vine inlay.
  - A bronze-and-jade lotus medallion with three hanging bronze talisman tags.
  - Gothic tracery spires (quatrefoil arches) rising from the crown, plus a Chinese eave corner with a hanging bronze bell and red tassel.
  - Broken red-lacquer panels on the side.
  - An iron ring set in the stone at the temple ear.
- **Roots:** thick roots pour over the head and down to the ground, with ferns, rocks and red-painted stone shards at the base.
- **Kit pieces:** FaceShell (baked sculpt, split into 6–8 subs), TunnelInterior (walkable, Precise collision on the floor), Crown_Band, Crown_Medallion, Crown_Spires, Crown_Eave+Bell, Roots (2–3 variants), BaseRubble.
- **Tunnel:**
  - 60–90 studs long, curving so you can't see through it from outside.
  - Dim light: two warm lantern niches tagged `AsuraLanternLight`, and dripping-water and moss particles.
  - Light bloom at the exit.

**The hidden basin:** terrain-sculpt a bowl enclosed by cliffs, about 350 × 300 studs, directly behind the face. Rim cliffs must block every outside line of sight to the temple; test this with raycasts from 8 road points.

**Sunken Temple** (`bellwood_3`), about 120 studs wide:
- **Main hall:**
  - A two-tier hall with heavy curved tile roofs, moss and hanging vines, flooded to the top of its stairs.
  - Red lacquer columns behind the stone base, with red banners carrying a gold wheel sigil.
  - A bronze gong inside, and a stone balustrade.
- **The tree:** a giant crimson-maple tree grows out of the roof ridge, with roots strangling the roof tiers. It gets red leaf particles (the OverworldAmbience Leaves kind, tinted crimson in this zone).
- **Left side:** twin stone gate towers (paifang-pagoda hybrids) with a moss stair rising between them into the forest, wrapped in roots, with red prayer ribbons.
- **Midground:** a toppled stone colonnade standing in the water, with carved columns and broken lintels, some tilted.
- **Right foreground:** a headless guardian lion on a plinth, draped in red ivy.
- **Water:** a wrecked wooden boat or raft, lily pads and pink lotus flowers (decal or mesh cards).
- **Water settings:** Terrain water in dark teal (WaterColor about 40,58,52), WaterTransparency 0.3, Reflectance 0.6, WaveSize 0.05. Low mist sheet particles over the water, and god rays (SunRays) through the canopy.
- **Kit pieces:** Hall_Base, Hall_RoofLower, Hall_RoofUpper, Hall_Columns, Hall_Banners, Tree_Trunk, Tree_Roots, Tree_Canopy (leaf cards), GateTower ×2, MossStair, Colonnade_Standing, Colonnade_Toppled, Lion_Headless+Plinth, BoatWreck, LotusCards.

**The reveal:** the tunnel exit frames the temple on the right third and the gate towers on the left third (as in `bellwood_3`). Capture this exact view as the acceptance shot.

## 2. Amberfall (Golden Ravine): Cliff Monastery + Broken Ravine Bridge
**Images:** `amberfall_1_cliff_monastery_kit.webp` (key art plus kit: gothic-base pagoda tower, cantilever balcony, rope bridge between gothic pylons, bell eave) and `amberfall_2_broken_ravine_bridge.webp`. Also see the top half of `saltreach_2_kit_sheet.webp` and the Amberfall row of `saltreach_1_region_sheet.webp`.
- **Cliff Monastery:**
  - Pagoda tiers bolted to a golden ravine wall, built on gothic stone bases with pointed windows.
  - Red lacquer timber balconies on diagonal braces, plank walkways and rope bridges between buildings.
  - Bronze bell clusters, red and gold banners, a waterfall below.
  - **Pieces:** PagodaTower (gothic base plus 3–5 tiers), CantileverBalcony, PlankWalkway, RopeBridge (with gothic pylons), BellEave, BellCluster, Banner.
- **Broken Ravine Bridge:**
  - A gothic stone arch bridge with balustrades and pagoda-capped gothic towers at both ends.
  - The centre span has collapsed. Rusted chains and torn red lotus banners hang across the gap.
  - Mist in the gorge below.
  - **Pieces:** BridgeTower ×2, ArchSpan_Intact, ArchSpan_BrokenEnd ×2, ChainSwag, Banner.
  - Integrate it with the existing Amberfall aqueduct region kit.
- **Look:** warm amber backlight, falling amber leaves, warm haze.

## 3. Saltreach (Arid Basin): Buried Salt Palace, Colossal Sword, Canyon Tomb
**Images:** `saltreach_1_region_sheet.webp` (bottom row) and `saltreach_2_kit_sheet.webp` (bottom half plus its turnaround panels).
- **Buried Salt Palace:**
  - Ornate domes (a gilded main dome) and minaret spires, with an arched gateway half buried in white salt-crusted dunes.
  - A giant stone hand rises from the sand nearby.
  - **Pieces:** MainDome, MinaretSpire ×2, GateArch, Facade, SaltDrift, GiantHand.
- **Colossal Sword:**
  - A three-storey greatsword driven at a slight angle into a ruined shrine platform.
  - Four small pillared shrines stand on the platform, with steps.
  - **Pieces:** Sword, ShrinePlatform, PillarShrine.
- **Canyon Tomb:**
  - A temple facade carved into a sandstone cliff, with two armoured guardian reliefs, columns, a pediment and steps.
  - **Pieces:** TombFacade, CliffMass ×2, Steps.
- **Look:** bleached salt glare, blue shadows, heat shimmer.

## 4. Frostmere (Snowfields): Frozen Waterfall Shrine, Ice Dragon, Ruined Observatory
**Image:** `frostmere_1_sheet.webp`.
- **Frozen Waterfall Shrine:**
  - A stone bell tower with a bronze bell, encased in a frozen waterfall with blue ice curtains and icicles.
  - At its foot: a red-and-gold shrine with lit lanterns, stone lanterns, a stair and banners.
  - **Pieces:** BellTower_Iced, IceCurtain ×3, Shrine, StoneLantern, Stair.
- **Ice Dragon:**
  - A serpentine skeleton arching out of a frozen lake: horned skull, rib arches, then spine and tail, glazed in ice.
  - **Pieces:** Skull, RibArch ×2 variants, SpineTail.
- **Ruined Observatory:**
  - A broken bronze-ribbed dome on a colonnaded rotunda, with a large bronze armillary sphere on a stepped plinth in the courtyard, snow and icicles.
  - **Pieces:** Dome_Broken, Rotunda, ArmillarySphere, ArchModule, ArchFragment, Column, StairModule, Balustrade, BannerPole.
- **Look:** cold blue fill, glitter, crisp long shadows.

## 5. Ashen Stair (Mountain Ascent): Thousand Steps, Chained Floating Rocks, Burning Fortress Gate
**Image:** `ashen_stair_1_sheet.webp`.
- **Thousand-Step Stair:**
  - A monumental stone stair up the slope, with balustrades, collapsed gap sections and ember-glow cracks.
  - Guardian-lion pillars at the landings, red banners with gold sigils, ash drifts and burnt pines.
  - **Pieces:** StairStraight, StairBroken, StairCollapsedGap, LionPillar, Banner.
  - The stair must be walkable: Precise collision on treads, or an invisible ramp.
- **Chained Floating Rocks:**
  - Inverted rock shards with glowing gold sigils, hanging in the air.
  - They're bound by huge rusted chains to tall sealing pillars with iron rings and banners.
  - **Pieces:** FloatRock (L/M/S), Chain segment, SealingPillar (two heights).
  - Add a slow bob (client-side TweenService on CFrame, anchored, no physics).
- **Burning Fortress Gate:**
  - A stone fortress gate with pagoda roofs (some burning) and armoured general statues in niches.
  - One studded door hangs on its hinge and the other is torn off and leaning. Ember cracks, broken timber.
  - **Pieces:** GateCore, GateTowerSide, Door_Hung, Door_Torn, Statue_General, WallSection ×2, BannerPole.
  - Fire: ParticleEmitter fire and smoke and ember motes. Lights stay shadowless.
- **Look:** grey-violet ash fall, ember motes, storm cloud deck.

## 6. Vesperhold extension: ATTACH TO THE EXISTING CASTLE (do not build a separate site)
**Image:** `vesperhold_ext_1_sheet.webp`. These are new parts of the existing Vesperhold, not a new landmark:
- **Read first:** `src/shared/VesperholdLayout.luau` (local frame: origin `Overworld.Vesperhold`, +Z toward the approach, castle at −Z; P1 citadel, P2 west chapter-house/belfry keep, P3 east ossuary/watch keep, viaducts V1–V3, grand stair, views 01/02), `src/shared/VesperholdKitRegistry.luau`, `src/server/Services/VesperholdKit.luau` and the `tools/blender/vesperhold/` builders.
- **Build:** extend `vesperhold_kit.py` (new group F) and use the existing Vesp_Soot, Vesp_Charcoal, Vesp_Weathered, Vesp_Slate, Vesp_Iron and Vesp_Frost materials. Reuse the existing gargoyle and figure generators.
- **Placement:** add the new slots to VesperholdLayout (extend `tools/test_vesperhold_massing.luau` first) and register them in VesperholdKitRegistry so VesperholdKit places them. Keep the view 01/02 framing, the single Shen barrier and `Kit.MaxLights`.

| Part | Attach to | Pieces |
|---|---|---|
| Roofless Cathedral Nave | Adjoins the **P2 chapter-house/belfry keep**: nave aisle open to the sky, rose-window wall facing the approach | NaveArch module, RoseWindowWall, ArchFragment, Pew, Column, WallSection |
| Gargoyle Bridge | Upgrade the **V2 or V3 viaduct** into the gargoyle bridge | BridgeSpan, BrokenSpan with hanging chains, Gargoyle on a pier, BannerPole |
| Mausoleum and graveyard | Beside the **P3 ossuary/watch keep** (it fits the ossuary) | Mausoleum, Gravestone tall, Gravestone leaning, IronFence, Gate, Celtic cross, broken slabs, grave lantern (tagged AsuraLanternLight), Sarcophagus, DeadTree (reuse `vesperhold_trees.py` dead oak), Rubble |

## 7. Anywhere (lore glue): Asura Colossus, Sealing Pillars, Waystone Shrines
**Image:** `lore_glue_1_sheet.webp`.
- **Asura Colossus fragments:**
  - A shattered giant statue: a crowned head with chain-bound gold-lined cracks and ear rings, an open hand, an armoured torso, and a sword arm gripping a blade.
  - Scatter them along the Forest–Amberfall ridge (the N-S divide) among red-maple trees and mist.
  - **Pieces:** Head, Hand, Torso, SwordArm, rubble.
- **Sealing Pillars:**
  - Tall carved pillars with glowing gold sigils, a spiked halo ring on top, iron rings, chain swags between pillars, talisman banners and stone bases.
  - Use them as visual waypoints along major roads.
  - **Pieces:** Pillar (A/B), HaloTop, Ring+Tag, ChainLink, TalismanBanner, BaseBlock.
- **Waystone Shrines:**
  - A small pagoda-roofed stone shrine with a glowing lantern and sigil door on a stepped base, with signposts, cairns and stele stones.
  - Put one at **every road fork** in every region. The lanterns are tagged `AsuraLanternLight`, so the night system lights them (see the night inset).
  - **Pieces:** Shrine (front, side and back angles), Lantern ×2, Stele ×3, Signpost, Cairn.

## Order
1. Bellwood face → tunnel → hidden basin → sunken temple (one landmark, several loop iterations).
2. Amberfall.
3. Saltreach.
4. Frostmere.
5. Ashen Stair.
6. The Vesperhold extension.
7. The lore glue. Do the waystone shrines early if a quick win is needed between heavy jobs.

Each iteration finishes one kit or one placement step, verified and pushed.

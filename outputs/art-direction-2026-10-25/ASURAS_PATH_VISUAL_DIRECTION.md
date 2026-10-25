# Asura's Path — The Six Broken Vows

**Visual direction for 2D concept, Rodin, Blender and Roblox** · 25 October 2026  
**Status:** art proposal for the current seven playable regions. It does not change the map, lighting or shipped assets.

## Creative premise

The world was built to **hold a vow**. Stone carries weight; timber carries roofs; six celestial pillars once held the Abyss. Shen's betrayal made each system fail in a different way. Show the wound through construction and use: a bell with its striker removed, roof brackets still bearing a collapsed span, a throne prepared for someone who cannot sit in it. The Asura Emissary is a small, dark figure moving through places that remember their purpose.

The look is **ritual architecture under physical strain**: Southern Chinese and mountain wuxia forms, cut stone, dark cedar, clay tile, hammered bronze, incense and rainwater. Grandeur comes from proportion and empty space. Corruption is a break in an otherwise credible building, not a layer of spikes or symbols on every surface. Keep the existing Sanctuary veiled figure and crimson tree as the exceptional image; their red is a story landmark, not the color of the whole world.

**Three reads, in order:** (1) where the route and floor go, (2) who is attacking and what their body is doing, (3) the lore in the surface and props. A beautiful painting that reverses this order is not an approved game concept.

### Source anchors and scope

- `src/shared/NarrativeCatalog.luau`: Shen consumed his disciples; six fallen sovereigns are bound to broken pillars; the Emissary cannot cross the river of souls until they rest. The eight inscriptions establish the bell, jade splinters, blood wraith and empty throne.
- `src/shared/WorldDefinitions.luau`, `BossRoster.luau` and the five campaign layout modules: current routes, altars, arenas and bosses. **Sunken Crypt** is the player-facing art name for the `SanctuaryDepths` region.
- `src/shared/EnvironmentProfiles.luau`: Sanctuary golden hour, cool Monastery, green Bamboo Pass, ashen night Colosseum, pale Crypt, dusk Pagoda and blue Citadel. The combat profiles already thin mist and raise neutral fill; this direction gives that rule a visual reason.
- Existing Sanctuary concepts in `outputs/lobby-concept-2026-10-21/` and `outputs/lobby-references-2026-10-22/` show the veiled figure/tree, flagstones, basin, forge and duel court. Current Studio captures in `outputs/lobby-monumental-2026-10-23/` and `outputs/claude-followup-2026-10-21/` show the actual player camera and the need for brighter combat floors.
- `outputs/world-design/World-Design-Revision-02.md` proposes a different future atlas. Its grounded construction and quiet-space principles are useful, but its geography does not replace the seven-region campaign in this brief.

## Color and value contract

These **hex colors are concept swatches**, not a mandate to set every Roblox part to an exact RGB. Check their value after regional Lighting and ColorCorrection. Roughly 65% of a frame is local stone/earth/wood, 25% is sky or recess, 8% is warm or cool identity color, and at most 2% is supernatural emission. Characters and attack warnings get first claim on the brightest and most saturated pixels.

| Role | Swatch | Where it belongs |
|---|---|---|
| Ink charcoal | `#252B30` | Deep timber, unlit eaves, seams; never the entire walkable floor. |
| Storm slate | `#4E5B61` | Main blue-grey masonry and distant rock. |
| Worn limestone | `#A7A79B` | Stair nosings, altar edges, carved faces and safe route highlights. |
| Smoked cedar | `#4A3631` | Beams, brackets, doors and shutters. |
| Dull bronze | `#877151` | Bells, hinges, inlay and one or two sacred edges. |
| Weathered jade | `#668B7F` | Qi traces, wet stone mineral, small route accents. |
| Vow crimson | `#9E4041` | Sanctuary crown, wraith/blood-memory, a few seals and phase breaks. |
| Incense ember | `#D18A56` | Rest points, hand lanterns and forge heat. |
| Cold sky fill | `#B7C6CA` | Edge light on bodies, pale fog and readable negative space. |

**Value ladder:** environmental recess 15–25/100; traversable stone 35–55; interactable rims and actor highlights 60–75; effects and emissive accents 80–95 for a moment only. Do not make wet black stone the default floor. In a grayscale paintover, the route must remain clear, and the boss must separate from the arena wall without its VFX.

## Material grammar and modular construction

| Material | Concept treatment | 3D/Roblox translation |
|---|---|---|
| Cut stone | Large irregular courses, hand-cut bevels, drainage channels, chips concentrated on exposed edges. | Reusable wall, stair, plinth, coping and broken-end modules; detail in normal/roughness maps, simple collision hulls. Stone texture grain should read at player height, not turn into noise at distance. |
| Cedar and lacquer | Beam ends and joinery visible; lacquer survives on protected faces and wears at grips/feet. | One bracket family and two beam sizes shared across regions; use a limited dark vermilion accent in Sanctuary/Pagoda. Keep roof outlines broad. |
| Fired tile | Charcoal, uneven courses and a few missing units, with recognizable ridge caps. | Repeated eave/hip/ridge pieces with silhouette variation; avoid sculpting every tile on distant roofs. |
| Bronze and iron | Oxidized, rubbed bright only where touched or struck. | Bell, hinge, chain and incense modules. No uniform gold trim or mirror metal. |
| Water, ice, ash | Water pools in a believable low point; ice gathers on windward ledges; ash settles in sheltered pockets. | Decals/texture masks and restrained particles rather than covering every floor. Water should show depth and a readable edge. |
| Cloth and paper | Faded banners and prayer slips have distinct hanging direction and scale. | Broad shapes with a few frayed tears; avoid dense animated strings in the camera path. |

The common kit should make the seven places related: **stone plinth → timber post/bracket → tiled roof → bronze ritual fitting**. Alter the proportions, state of damage and local material mix by region. Build an architectural bay that can stand cleanly before damage is added. A broken component should still explain how the intact one worked.

## Seven regional identities

| Region | One-line read | Dominant / accent | Landmark silhouette | Weather boundary |
|---|---|---|---|---|
| **Sanctuary** | A last held breath above the cloud sea. | Warm limestone / singular crimson crown, amber incense. | Long central stair, low roofs, veiled seated figure nested in a vast twisted tree. | Dry terrace; clouds stay below the floor. |
| **Desecrated Monastery** | A teaching place abandoned mid-ritual. | Rain slate and black cedar / dull bronze bell. | Broken bell tower against an uneven cloister roofline. | Intermittent cold rain and roof drip; fight courts stay optically clear. |
| **Bamboo Pass** | Living verticals press against a hard mountain route. | Moss green and mist grey / white frost, jade splinters. | Narrow bamboo rhythm interrupted by fluted karst and a moon gate. | Damp air and low valley mist; crest and Baize arena open up. |
| **Ash Colosseum** | A sacred contest converted into judgment. | Soot basalt and chalk ash / cinder orange. | Low concentric terraces cut by a single victor's gate. | Dry falling ash, never rain; clear combat air. |
| **Sunken Crypt** | The foundations were lowered into a drowned memory. | Blue black stone and bone limestone / oxidized teal. | Descending well, heavy vault ribs and one immense Titan hall. | Seep, condensation and ankle-low vapor; no ceiling-high fog. |
| **Celestial Pagoda** | An empty throne held above a missing floor. | Smoked cedar and dusk rose / quiet brass and starless indigo. | Tiered eaves with exposed rafters and a visible void beneath them. | Windblown rain only on exposed approach; interior dust and thin haze. |
| **Sky Citadel** | The final defense clings to broken heaven. | Rime slate and cold silver / small lightning blue. | Asymmetric battlements and a fractured pillar crown beyond a bridge. | Wind and sparse sleet; bridge and Wyrm landing stay sharply visible. |

### Sanctuary — refuge with one impossible image

Preserve the bonfire → stair → gate → veiled figure/tree axis, with Gao's forge and optional duel court as legible side destinations. Large pale flagstones and a low fire lead the eye; charcoal roofs and dark vermilion posts frame, rather than compete with, the figure. Keep the tree's crimson canopy sparse enough for the pale face and body to read. Rain is absent here: show old wet marks in stone seams if desired, but no continuous glossy plaza. Jade is reserved for the travel threshold and water depth. From player distance, the tree, statue and central stair must resolve as **three** shapes, not one red silhouette. Concept keyframe: shoulder-height arrival with route, forge entrance and court branch visible; companion cutaway for the well/reliquary descent.

### Desecrated Monastery — disciplined geometry interrupted

Use a once-ordered sequence of gatehouse, teaching court, bell, cloisters and bridge. The corruption appears in empty seven-place dining remains, split prayer tablets, one failed roof span and bell hardware with no striker. A broken tower should be an off-center beacon from the first court; keep the Twin Sentinels' separate side court distinct from Shen's later arena. Rain strikes tiles and runs down drains; it does not turn the duel floor into a mirror. Light the playable courtyard with cool sky bounce and pale edge stones, while warm lanterns mark rest and human occupation. Concept keyframe: the first gate court in light rain, a lone monk fully silhouetted on the route and the bell beyond.

### Bamboo Pass — pressure, then release

Keep the existing three leafy bamboo variants and fluted frost-capped karst towers as the local vocabulary. Stems form vertical curtains beside, not across, the route; an occasional fallen culm makes a strong diagonal. Jade splinters live in roots and cut rock, connecting to inscription V without coating the pass in green emission. A small roofed shrine pocket gives a pause before Baize's mouth. Make the ridge snow a location cue, not a uniformly white arena. Baize's arena is a low-contrast **stone and frost floor** with an open center and the bamboo palisade outside camera reach; its frost pillars have clear bases and gaps for dodge paths. Concept keyframe: crest looking down to the shrine and beast mouth, with one human figure for scale.

### Ash Colosseum — witness without a crowd

The ring and processional halls were built for contests. Repeated low terraces, scorched seats, tally notches and a broken victor gate show this history; resist a generic Roman amphitheater. Shen's fighting plane is matte charcoal-brown stone dusted unevenly with pale ash. Warm cinders stay at the edge, so a red peril cue and Shen's jian-to-chimera silhouette change remain unmistakable. If the second phase stains the sky, preserve the same floor brightness and neutral edge fill. Ash drifts in slow sparse flakes beyond combat center; no smoke column crosses the camera. Concept keyframe: low entrance view through the gate into a wide, empty, readable ring with Shen small but isolated.

### Sunken Crypt — weight and withheld air

The descent from the Sanctuary well should feel structural: stair, upper incense gallery, lower nave, bone causeway and Titan hall. Use broad depressed vaults and stacked sarcophagus niches, with water staining that traces gravity. The pit has a visible lip and dark water far below; do not disguise the drop with fog. Titan scale comes from the span of the hall and low ribs, not dense clutter. Give its ankles and weapon arc a clean background; keep sarcophagi outside the active fight lane. Cool reflected fill and a few amber incense lamps reveal stone planes. Concept keyframe: gallery looking down across the causeway toward the Titan's hall, with route edges illuminated.

### Celestial Pagoda — height made precarious

Use layered roof eaves, joinery and open rafter bays to make the climb understandable at a glance. The cloud stair descends into a gorge; the west stair, beam, lantern rafter and optional loft are different elevations with visible support. The throne is small and empty, framed by a missing wall rather than a giant glowing seat. Wu's sorcery can bend the starless air for a beat; the resting environment is cedar, faded lacquer and late dusk. Do not fill the rafter route with hanging tassels or fog. Concept keyframe: a cutaway three-quarter view with a human figure on each route level, then a separate player-height view toward Wu's gate.

### Sky Citadel — exposed defense, not floating luxury

The summit bridge and Heaven's stair lead to a bastion whose towers use the same stone-and-timber ancestry as the Monastery, now stripped by wind. A fractured celestial-pillar crown gives the far skyline its purpose; do not add many competing spires. Rime catches windward coping, and a few torn standards indicate air flow. The Azure Wyrm should land against a lighter sky or pale wall, never against a same-value dark mountain. Keep the bridge edge, stair landings and bastion combat plane visible through sparse sleet. Lightning is a brief directional event with a clear source and impact, not ambient neon. Concept keyframe: player-height bridge approach with the Wyrm's landing space and safe floor readable before the creature appears.

## Rain, fog and motion rules

1. **Weather explains place.** Monastery rain comes from an overcast sky; Bamboo Pass mist collects below the crest; Crypt moisture comes from seep and condensation; Ash Colosseum is dry; the Sanctuary cloud sea stays below its terrace. Pagoda and Citadel wind drive rain/sleet sideways only in exposed segments.
2. **Three depth bands.** Foreground silhouettes remain crisp. Midground uses modest desaturation and value separation. Distant skyline may disappear into haze. Never put a uniform translucent veil over the player, enemies, ground telegraphs or a jump landing.
3. **Combat override.** At arena entry, reduce local particle density and ground fog; keep ambient sound/weather identity. A phase change may shift hue, but it cannot reduce the neutral fill or erase the floor boundary. Existing combat lighting profiles are the practical baseline.
4. **Wetness is selective.** Eave drip, puddles below drains and streaks on downhill stone communicate rain better than universal high specular. Wet floors remain matte enough to show attack shapes.
5. **Only one ambient motion signature per view:** leaf drift, rain, ash, incense, dust or sleet. Do not run all of them together. Keep the central fight plane almost still between attacks.

## VFX hierarchy and restraint

**Tier 1, gameplay:** weapon arcs, peril warnings, deflect contacts, ground targets and hit response. They must be identifiable by silhouette/timing as well as hue, including in grayscale or reduced effects. Deflect sparks are sharp and short; a sustained trail must not persist long enough to look like the next attack.

**Tier 2, narrative:** a rest incense thread, a jade fracture in stone, a single pillar memory, a one-time phase rupture. These are localized and stop when gameplay resumes. Crimson signals sacrifice, blood memory or the broken vow; jade signals trapped Qi; cold blue signals height and storm. Avoid broad chromatic washes on ordinary enemies.

**Tier 3, spectacle:** the existing cinematic showcase sorceries may briefly occupy the frame, but their charge, strike and recovery must be separated by a readable beat. Nearby players still need an intelligible actor and hit area; respect reduced motion and flashes. Never design environmental fog or ambient emitters to compete with these spells.

At a single gameplay moment, allow **one primary effect and one small contact response** near the player. Put particles and debris at the strike, not in front of the camera. Boss phase changes may momentarily exceed this, then clear before control and telegraphs return.

## Player-camera acceptance

Draw every regional keyframe twice: **cinematic wide** for mood and **player-height gameplay** with a roughly Roblox third-person figure and HUD-safe top/bottom margins. Judge the latter first. On a 720p phone view, the player, enemy head/weapon, nearest route edge and next landmark should remain distinguishable; repeat at the normal desktop camera. Validate also with lock-on, dodge, a close wall and the largest boss animation.

- At **thumbnail size** (about 160 px wide), each region should be identifiable from its outer shape: tree/figure, bell, bamboo/karst, ring, vault, tiered rafter, broken crown.
- At **mid-distance**, a doorway is a single readable opening; route stone differs in value/texture rhythm from walls and voids. Railings and foliage must not bisect the enemy's torso at the common fight camera.
- At **combat distance**, the floor edge, enemy feet and active weapon stay separate from VFX. Reserve a clean contrast pocket behind the boss. Use background lighting, not a permanent outline glow, to achieve it.
- On a **vertical or mobile crop**, the primary landmark should still read and the boss cannot merge with the sky/roof line. Do not hide necessary information beneath the existing top boss bar or lower action cards.

## 2D concept package and handoff

Commission or make **one master tone key, seven region keyframes, seven gameplay paintovers and one shared material/kit sheet** before individual prop renders. For each region, show: arrival, next route landmark, arena from actual player height, weather-on and combat-cleared versions, grayscale pass, and one 6-stud-tall Roblox avatar for scale. Include an elevation/cutaway wherever the route changes height (Crypt, Pagoda, Citadel). Label what is **existing** versus **proposed** on the concept margin, not inside the final artwork.

For Rodin/Blender handoff, isolate each proposed asset in an orthographic front/side/back sheet with neutral light, unoccluded joinery, approximate stud dimensions, material IDs, pivot/orientation and collision intent. Prioritize the shared roof bracket/eave, stair/coping, bell, bamboo clump, karst, colosseum tier, crypt rib/sarcophagus, pagoda rafter and citadel battlement kits. Use hero sculpting only where the silhouette or story demands it. Keep separate textured MeshParts and simple collision for interactive structures; verify texture scale and legibility in Studio before multiplying a kit across a region.

**First approval gate:** grayscale gameplay paintovers of Sanctuary, Monastery first court, Baize arena and Shen arena at phone and desktop crops. If actor, route and floor are clear there, proceed to the remaining seven keyframes and kit sheets. Any concept whose beauty depends on full-screen fog, constant glow, dense foreground leaves or pure-black floors needs revision before 3D.

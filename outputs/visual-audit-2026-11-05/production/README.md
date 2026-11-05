# Start here — production plan and complete prompts

6 November 2026 · extends the [5 November visual audit](../README.md). This is an execution-ready prompt/asset plan; it does not mean those fixes or arena enlargements have already been implemented. All six encounters keep the already constructed boss models.

## The practical split

**Let the agents build the world and precision geometry. Use human-led image/Rodin generation for a few hero sculptures and speaking characters.** A convincing arch, dome, chain, coffer, bell frame or arena layout is feasible with Blender scripts/MCP plus visual iteration. Reliable faces, hands, layered clothing and distinctive large organic sculpture benefit more from an approved image and a chosen generated model. Nobody should promise unattended AAA results from a prompt or perfect Roblox rig fit from a painting.

| You handle | Claude/ChatGPT handles |
|---|---|
| Select the visual direction from concrete comparisons; approve the few H-assets you want. | Inventory existing assets, measure rigs/routes/camera, export cast proportion references, prepare layout prototypes and all independent code. |
| Generate the approved H01/H02/H03/H04 images and Rodin objects when needed; H05 is optional. | Reusable B01–B10 modules, terrain, arches/domes, prop variants, material setup, lighting, water/foliage, larger arena coordinates and route integration. |
| Approve the three cast designs H06/H07/H08 and supply their chosen exports; H09 is only a fallback for a poor small skull sample. | Retopology/baking/cleanup, import/mapping, actual-rig adaptation, prompt/collision preservation, placement and engine checks. |
| Judge the final visual direction and normal fight feel. | Provide recorded before/after, meaningful regressions, target-device and genuine multiplayer checks; mark any missing evidence honestly. |

**Do not generate the whole arena as a single Rodin model.** Generate sculptural modules; let the agent assemble precise rooms, paths, support, collision, lighting and scenery. No new boss-model generation is in this queue. The old AP-01 captures remain historical evidence; first reconcile runtime integration of the existing assets.

## Open these files

- [RELAY_UPDATE.md](RELAY_UPDATE.md): reconcile the newer Shen source/cloth/animation commit; its Studio integration remains unverified.
- [ART_DIRECTION.md](ART_DIRECTION.md): how all nine supplied references translate into a coherent, broader dark-fantasy world. Includes the images.
- [ASSET_PROMPTS.md](ASSET_PROMPTS.md): H-assets with complete copy-paste image → Rodin → integration prompts; B-kits the agents can make themselves.
- [ARENAS.md](ARENAS.md): six larger playable arenas, current/proposed dimensions, overlap risks, distinct compositions, optional scene concept prompts and complete implementation prompts.
- [OWNERSHIP_MATRIX.csv](OWNERSHIP_MATRIX.csv): every original finding mapped to human/code/Blender work. The same routing appears beside each finding in the main audit.

## Run order

1. **Reconcile first:** give the agent [prompts/C00_SURVEY_AND_ASSET_INTAKE.md](prompts/C00_SURVEY_AND_ASSET_INTAKE.md). It measures current assets and exports actual-rig mannequin references for the cast concepts. No new boss designs. Then [prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md) produces the coherent six-arena coordinate plan and reversible larger prototypes.
2. **Quick concrete repair:** run C01 for the floating chains and route readability. It can proceed before any Rodin asset.
3. **Pilot the new scale:** run AR01 for Shen, then check the normal-camera scene and fight. Use that result to settle shared architectural/material quality before producing all six. A larger floor alone does not pass.
4. **Reusable asset batches:** C02 interactive props; C03 monastery/ruin kit and PvP rings; C04 crypt funerary kit; C05 galleries/citadel/water/ground detail. These have work available without H-assets. If a batch depends on an arena relocation, use AR00’s chosen manifest first.
5. **Hero assets in parallel with that work:** H01 idol and H02 throne first; H03 root module after Titan room dimensions; H04 relief as needed. H05 optional. H06/H07/H08 cast concepts only after proportion references exist. Use C06 to integrate supplied H-assets. H09 only if the agent-made skull looks inadequate.
6. **Finish the larger scenes sequentially:** AR02 Twins, AR03 Baize, AR04 Titan, AR05 Wu, AR06 Wyrm; reuse the validated kits and preserve completed work. Each prompt includes its own route/bounds/combat checks.
7. **Integrated acceptance:** C07 on the gaming Windows machine for foreground play, relevant real two-client checks and profiling; compare Mac appearance at declared settings. Stop passing batches based only on seeded screenshots.

One repository writer at a time. The creator can generate art independently while an agent edits source. For relay work, complete a coherent batch, build/verify as required, commit/push only its files and have the next machine pull the same branch before editing. Mac can author code/kits and do bounded Studio checks; it cannot stand in for unperformed Windows/multiplayer/profile evidence.

## Direct agent prompts

| ID | Task | Full copy-paste file |
|---|---|---|
| C00 | Current-state/asset/scale intake | [C00_SURVEY_AND_ASSET_INTAKE.md](prompts/C00_SURVEY_AND_ASSET_INTAKE.md) |
| C01 | Floating chains + route readability | [C01_CHAIN_PLACEMENT_AND_READABILITY.md](prompts/C01_CHAIN_PLACEMENT_AND_READABILITY.md) |
| C02 | Altars, coffers, ladders, smith kit | [C02_INTERACTIVE_PROP_KIT.md](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| C03 | Monastery ruins + two PvP ring finishes | [C03_MONASTERY_RUIN_KIT.md](prompts/C03_MONASTERY_RUIN_KIT.md) |
| C04 | Crypt architecture/funerary/water/chain kit | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| C05 | Pagoda/Citadel joinery, bell, garden/foliage | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| C06 | Supplied hero/cast mesh cleanup, rigging and integration | [C06_CAST_AND_HERO_ASSET_INTEGRATION.md](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md) |
| C07 | Integrated Windows/normal-input/multiplayer/profile acceptance | [C07_INTEGRATED_WINDOWS_ACCEPTANCE.md](prompts/C07_INTEGRATED_WINDOWS_ACCEPTANCE.md) |
| AR00 | Spatial plan + larger prototypes | [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md) |
| AR01 | The Ashen Covenant | [AR01_GRANDMASTERSHEN_ARENA.md](prompts/AR01_GRANDMASTERSHEN_ARENA.md) |
| AR02 | The Broken Processional Court | [AR02_TWINSENTINELS_ARENA.md](prompts/AR02_TWINSENTINELS_ARENA.md) |
| AR03 | The Frost-Hollow Hunting Ground | [AR03_VENERABLEBAIZE_ARENA.md](prompts/AR03_VENERABLEBAIZE_ARENA.md) |
| AR04 | The Cathedral Beneath the Roots | [AR04_SLUMBERINGTITAN_ARENA.md](prompts/AR04_SLUMBERINGTITAN_ARENA.md) |
| AR05 | The Starless Mirror Court | [AR05_SOVEREIGNWU_ARENA.md](prompts/AR05_SOVEREIGNWU_ARENA.md) |
| AR06 | The Storm-Crowned Expanse | [AR06_AZUREWYRM_ARENA.md](prompts/AR06_AZUREWYRM_ARENA.md) |

Each agent file is standalone: copy the full fenced text. It includes project context, scope, exact source/evidence to read, implementation expectations, tests and handoff. Do not paste all 15 implementation prompts into one unbounded job. Finish and inspect each coherent batch before starting the next.

## Every audited finding: ownership and prompt

| Finding | Production route | Human input | Assets | Agent files |
|---|---|---|---|---|
| AP-01 · Historical fallback skins; existing boss models need intake verification | Existing models; verify integration only | None for model creation: creator says all boss models are constructed. Locate them; in-game status remains to be rechecked. |  | [C00_SURVEY_AND_ASSET_INTAKE](prompts/C00_SURVEY_AND_ASSET_INTAKE.md) |
| AP-02 · Speaking NPCs lag behind their surroundings | Human/Rodin character design, then agent rig/integration | Approve Lin/Gao/Hermit concepts using C00-exported actual-rig references; supply chosen models/maps. | H06, H07, H08 | [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md) |
| AP-03 · Six rest altars remain generic pedestal-and-stick assemblies | Agent builds/reuses geometry and implements | No new Rodin model required. Review one close/gameplay sample per family. | B03, B04 | [C02_INTERACTIVE_PROP_KIT](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| AP-04 · Five hidden caches are plain metal cuboids | Agent builds/reuses geometry and implements | No new Rodin model required. Review one close/gameplay sample per family. | B03, B04 | [C02_INTERACTIVE_PROP_KIT](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| AP-05 · Two industrial truss ladders break the setting | Agent builds/reuses geometry and implements | No new Rodin model required. Review one close/gameplay sample per family. | B03, B04 | [C02_INTERACTIVE_PROP_KIT](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| AP-06 · Two PvP rings still use the undressed primitive kit | Agent kit + code; preserve PvP footprints | No new Rodin model required; human normal-input/two-client acceptance follows. | B01, B07 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [C07_INTEGRATED_WINDOWS_ACCEPTANCE](prompts/C07_INTEGRATED_WINDOWS_ACCEPTANCE.md) |
| SN-01 · Forge tools need a small authored prop pass | Agent builds/reuses geometry and implements | No new Rodin model required. Review one close/gameplay sample per family. | B03, B04 | [C02_INTERACTIVE_PROP_KIT](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| DM-01 · Ruined roof and column kit has blunt repeated profiles | Agent Blender modular construction + code | No new Rodin model required. | B01 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-02 · Ruin walls and rubble repeat square construction breaks | Agent Blender damage/grounding kit + code | No new Rodin model required. | B01, B09 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-03 · Both prayer-hall idols are unrecognizable boxes | Human/Rodin hero sculpture + agent kit/integration | Approve and supply H01; agent can finish the daises/ruins while waiting. | H01, B01 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md) |
| DM-04 · Bell tower and fallen bell read as a frame and capped drum | Reuse supplied Foundry_Bell/HanCauldron; agent derives variants | No new Rodin model required. | B04 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-05 · Courtyard cauldron is a solid disc stack | Reuse supplied Foundry_Bell/HanCauldron; agent derives variants | No new Rodin model required. | B04 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-06 · Toppled pagoda remains a stack of cubes and plates | Agent modular architecture + code | No new Rodin model required. | B01, B09 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-07 · Six grave stupas have a ball-on-box silhouette | Agent small prop kit + code | No new Rodin model required. | B10 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-08 · Secret mausoleum shell is unfinished | Human/Rodin relief, agent exact facade/door frame | Supply H04 carving; agent handles the entire precise structure and route. | H04, B01 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md) |
| DM-09 · Waterfall secret is a glass screen between rock boxes | Agent terrain/water/VFX and fitting | No Rodin waterfall or whole alcove model required. | B06, B09 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| DM-10 · Twin Sentinels arena lacks a finished setting | Arena redesign: agent layout/architecture; human taste review | No new boss model. Hero sculpture optional, existing statue assets can be reused. | B01, B07, B09 | [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR02_TWINSENTINELS_ARENA](prompts/AR02_TWINSENTINELS_ARENA.md) |
| BP-01 · Baize arena needs a deliberate edge and encounter identity | Arena redesign: agent layout/terrain/foliage | No new boss model. H03 root module is optional and reusable from Titan. | B06, B09, H03 optional | [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR03_VENERABLEBAIZE_ARENA](prompts/AR03_VENERABLEBAIZE_ARENA.md) |
| LT-01 · Exploration lighting hides route and prop form | Direct code/fixture placement and real-view calibration | Compare normal-profile captures; no new 3D model needed. No need to approve routine numeric fixes before they are made reviewable. |  | [C01_CHAIN_PLACEMENT_AND_READABILITY](prompts/C01_CHAIN_PLACEMENT_AND_READABILITY.md), [C07_INTEGRATED_WINDOWS_ACCEPTANCE](prompts/C07_INTEGRATED_WINDOWS_ACCEPTANCE.md) |
| AC-01 · Champions hall and facade still read as block architecture | Agent architecture kit; coordinate with larger Shen arena | No new Rodin model required. | B01, B07 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR01_GRANDMASTERSHEN_ARENA](prompts/AR01_GRANDMASTERSHEN_ARENA.md) |
| AC-02 · Last-stand props need recognizable sculpted forms | Reuse matching existing statue source; agent small prop variants | No new statue commission required if standing statue source is available. | B09, B10 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| AC-03 · Shen arena perimeter has weak colosseum hierarchy | Arena redesign: agent terrain/arcades/seating/landmark | Approve the rendered scene composition; no whole-scene Rodin asset. | B01, B07, B09 | [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR01_GRANDMASTERSHEN_ARENA](prompts/AR01_GRANDMASTERSHEN_ARENA.md) |
| SD-01 · Crypt ceiling and enclosing walls need real architectural form | Agent crypt kit + human hero root module; enlarged Titan chamber | Supply H03 after the measured room prototype. Optional H04 is reusable. | H03, B01, B02 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md), [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR04_SLUMBERINGTITAN_ARENA](prompts/AR04_SLUMBERINGTITAN_ARENA.md) |
| SD-02 · Ossuary skulls are 60 featureless spheres on 20 flat plaques | Agent skull/niche kit first; optional Rodin fallback | No human model required if the agent sample reads well. H09 is a complete optional image/Rodin prompt if it does not. | B02, H09 optional | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| SD-03 · Sarcophagi and crossing lids are plain rectangular masses | Agent coffin/lid modules; preserve or explicitly migrate crossing | No new Rodin model required. | B02 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| SD-04 · Titan chains are loose solid blocks rather than linked restraints | Agent open-link restraints + code placement | No new Rodin model required; fit to supplied Titan scale. | B05 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| SD-05 · Flooded pit needs believable water and shore treatment | Agent water/terrain/grounding | No new Rodin model required. | B06, B09 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md), [AR04_SLUMBERINGTITAN_ARENA](prompts/AR04_SLUMBERINGTITAN_ARENA.md) |
| SD-06 · Thirty candles remain unshaped rods | Agent small candle/FX kit | No new Rodin model required. | B10 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| CP-01 · Oracle throne is a box chair beneath a small canopy | Human/Rodin throne + agent loft/frame integration | Approve H02 and supply its chosen export/maps. | H02, B01 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md) |
| CP-02 · Great bell is an unadorned solid cylinder | Reuse Foundry_Bell; agent suspension/frame | No new Rodin model required. | B04 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| CP-03 · Lotus pool looks like a rectangle of water and discs | Agent small foliage mesh + water/terrain | No new Rodin model required. | B06, B09 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| CP-04 · Gallery, rafters and loft need crafted timber junctions | Agent precise timber/stone construction | No new Rodin model required. | B01 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| CP-05 · Wu arena has little ritual identity at floor level | Arena redesign: agent mirror court/lighting/bounds; supplied throne | H02 is the only recommended human focal prop here; whole lake/sky built in engine. | H02, B06, B07, B08 | [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR05_SOVEREIGNWU_ARENA](prompts/AR05_SOVEREIGNWU_ARENA.md) |
| SC-01 · Ten chain posts float above the descending stair | Direct code placement; agent simple chain geometry | No human/Rodin work required. | B05 | [C01_CHAIN_PLACEMENT_AND_READABILITY](prompts/C01_CHAIN_PLACEMENT_AND_READABILITY.md) |
| SC-02 · Dragon perch chains and shed scales are primitive | Agent chain/scale reuse; optional human organic crown | Reuse the supplied Wyrm model/materials; H05 is optional only if the chosen landmark needs it. | B05, B07, H05 optional | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md), [AR06_AZUREWYRM_ARENA](prompts/AR06_AZUREWYRM_ARENA.md) |
| SC-03 · Bridge and bastion edges need a weathered masonry finish | Agent masonry kit; enlarged Wyrm scene | No new Rodin model required; H05 optional. | B01, B07 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md), [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR06_AZUREWYRM_ARENA](prompts/AR06_AZUREWYRM_ARENA.md) |

## Current evidence status

The existing tour covers seven regions and 53 named campaign layout zones with settled actor and/or scripted-camera samples, 135 scripted captures and seven short normal-camera keyboard samples. This remains an assisted visual audit, not an earned all-secrets playthrough. The temporary helper/cheats were restored and both owned Play sessions stopped; the post-tour script digest and canonical place bytes match the pre-tour state. See [restoration.json](../restoration.json).

This production extension adds prompts and references only. Boss assets are creator-reported constructed; their new in-game integration has not been reverified by this document. Proposed arena dimensions are not tested facts. No paid model/image generation or production game change was performed to prepare the packet.

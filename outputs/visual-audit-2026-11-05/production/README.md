# Start here — production plan and complete prompts

Updated 7 November 2026. Extends the [5 November visual audit](../README.md). This packet specifies work; it does not claim the environments or larger arenas are already implemented. All nine H-assets and all boss designs are already created. Reconcile current integration against the latest journal.

## ForgeGUI and Blender

Read [ASSET_WORKFLOW.md](ASSET_WORKFLOW.md) before executing any batch. Inspect project/imported/supplied assets and search the connected ForgeGUI account library, public catalog and past MCP jobs before creating an asset. Reuse a suitable existing model rather than generating a duplicate. ForgeGUI supplies genuinely missing decorative/sculptural components; Blender handles exact architecture, modular joins, optimization, UVs, baking, collision proxies and rig adaptation. Roblox code assembles the playable world, terrain, lighting, VFX and encounter systems.

Preserve the approved H01-H09 and boss designs. Missing local files require a handoff, not regeneration. The raw-model transfer is AsurasPath_Asset_Handoff_2026-11-07.zip; it does not replace current rigged Shen templates. Most inspected source exports contain one million triangles. Prepare measured game copies and profile actual scenes.

## Open these files

- [ASSET_WORKFLOW.md](ASSET_WORKFLOW.md): ForgeGUI search/reuse, actual capabilities, Blender responsibilities, credits, source preservation, game preparation and parallel work.
- [WINDOWS_START_HERE.md](WINDOWS_START_HERE.md): current Windows C00 → AR00 → AR01 assignment while Mac debugs Shen.
- [RELAY_UPDATE.md](RELAY_UPDATE.md): historical relay note; newer PROJECT_STATE and Shen handoffs supersede its old integration status.
- [ART_DIRECTION.md](ART_DIRECTION.md): all nine scene references and their composition/material lessons.
- [ASSET_PROMPTS.md](ASSET_PROMPTS.md): the nine already-created H-assets and B-kit reuse/construction briefs. Legacy IMAGE_TO_RODIN filenames remain stable; their workflow is updated.
- [ARENAS.md](ARENAS.md): six larger scenes, measured-plan requirements, dependencies and full prompts.
- [OWNERSHIP_MATRIX.csv](OWNERSHIP_MATRIX.csv): all 36 original finding families, asset routes and prompt files.

## Run order and current parallel work

1. C00 reconciles the latest source, existing project and ForgeGUI assets, supplied model intake and rig/scale/camera measurements. Skip completed work and refresh only stale measurements.
2. AR00 creates a coherent six-arena coordinate manifest and two reversible larger prototypes per arena. Record provisional clearances where the final boss implementation is unavailable.
3. C01 fixes the traced chain placement and route readability. AR01 is the first finished arena pilot; inspect its normal-camera composition before extending shared architectural/material treatment across all scenes.
4. C02 → C03 → C04 → C05 builds/reuses the required kits. C06 prepares the nine supplied H-assets, including H05/H09, and stages arena-specific models until their final anchors exist. Reuse existing ForgeGUI/project results throughout.
5. AR02 → AR03 → AR04 → AR05 → AR06 finishes the remaining scenes sequentially using AR00 and the validated kits.
6. C07 provides final integrated Windows, normal-input, genuine multiplayer and profiling evidence, plus declared Mac/device comparison. It cannot replace outstanding combat verification stages.

Currently Mac owns Shen integration; Windows may complete C00 → AR00 → AR01 on codex/windows-arenas in an isolated checkout/Studio build. Boss debugging need not finish before independent environment construction. Combine completed boss/arena pairs at deliberate checkpoints and refresh affected measurements; keep combined fight acceptance pending until checked. This overrides older blanket instructions to push every task directly to ux/onboarding-overhaul.

Commit/push only owned files, with task-specific handoffs and required checks. One integration owner combines shared mappings, bounds, spawns and camera changes. Avoid automatic rebase/autostash, broad staging and force-push during parallel editing. Git does not transfer ignored raw models or .blend files.

## Reading an ID such as AR03

Claude needs the repository on its current computer and filesystem permission. Prompt IDs are labels, not remote file access. Start Claude Code in the correct clone/worktree, read the repository-root ENVIRONMENT_PROMPTS.md index, then open the full mapped file. Regular chat without file access needs the prompt attached or pasted; implementation also needs repository and Studio/tool access. ForgeGUI must be connected on that computer separately.

For AR03, read outputs/visual-audit-2026-11-05/production/prompts/AR03_VENERABLEBAIZE_ARENA.md in full, plus ASSET_WORKFLOW.md and the current C00/AR00 results. Do not infer the detailed task from its ID.

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
| AP-02 · Speaking NPCs lag behind their surroundings | Supplied approved H06/H07/H08; ForgeGUI/project lookup and Blender preparation/integration | Sources already created. Locate approved exports; creator judges actual in-game appearance/rig fit after a concrete comparison. No automatic regeneration. | H06, H07, H08 | [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md) |
| AP-03 · Six rest altars remain generic pedestal-and-stick assemblies | ForgeGUI/project reuse where suitable; Agent builds/reuses geometry and implements | No new Rodin model required. Review one close/gameplay sample per family. | B03, B04 | [C02_INTERACTIVE_PROP_KIT](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| AP-04 · Five hidden caches are plain metal cuboids | ForgeGUI/project reuse where suitable; Agent builds/reuses geometry and implements | No new Rodin model required. Review one close/gameplay sample per family. | B03, B04 | [C02_INTERACTIVE_PROP_KIT](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| AP-05 · Two industrial truss ladders break the setting | ForgeGUI/project reuse where suitable; Agent builds/reuses geometry and implements | No new Rodin model required. Review one close/gameplay sample per family. | B03, B04 | [C02_INTERACTIVE_PROP_KIT](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| AP-06 · Two PvP rings still use the undressed primitive kit | ForgeGUI/project reuse where suitable; Agent kit + code; preserve PvP footprints | No new Rodin model required; human normal-input/two-client acceptance follows. | B01, B07 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [C07_INTEGRATED_WINDOWS_ACCEPTANCE](prompts/C07_INTEGRATED_WINDOWS_ACCEPTANCE.md) |
| SN-01 · Forge tools need a small authored prop pass | ForgeGUI/project reuse where suitable; Agent builds/reuses geometry and implements | No new Rodin model required. Review one close/gameplay sample per family. | B03, B04 | [C02_INTERACTIVE_PROP_KIT](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| DM-01 · Ruined roof and column kit has blunt repeated profiles | ForgeGUI/project reuse where suitable; Agent Blender modular construction + code | No new Rodin model required. | B01 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-02 · Ruin walls and rubble repeat square construction breaks | ForgeGUI/project reuse where suitable; Agent Blender damage/grounding kit + code | No new Rodin model required. | B01, B09 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-03 · Both prayer-hall idols are unrecognizable boxes | Supplied approved H01; ForgeGUI/project lookup and Blender preparation/integration | Sources already created. Locate approved exports; creator judges actual in-game appearance/rig fit after a concrete comparison. No automatic regeneration. | H01, B01 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md) |
| DM-04 · Bell tower and fallen bell read as a frame and capped drum | Reuse supplied Foundry_Bell/HanCauldron; agent derives variants | No new Rodin model required. | B04 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-05 · Courtyard cauldron is a solid disc stack | Reuse supplied Foundry_Bell/HanCauldron; agent derives variants | No new Rodin model required. | B04 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-06 · Toppled pagoda remains a stack of cubes and plates | ForgeGUI/project reuse where suitable; Agent modular architecture + code | No new Rodin model required. | B01, B09 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-07 · Six grave stupas have a ball-on-box silhouette | ForgeGUI/project reuse where suitable; Agent small prop kit + code | No new Rodin model required. | B10 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| DM-08 · Secret mausoleum shell is unfinished | Supplied approved H04; ForgeGUI/project lookup and Blender preparation/integration | Sources already created. Locate approved exports; creator judges actual in-game appearance/rig fit after a concrete comparison. No automatic regeneration. | H04, B01 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md) |
| DM-09 · Waterfall secret is a glass screen between rock boxes | ForgeGUI/project reuse where suitable; Agent terrain/water/VFX and fitting | No Rodin waterfall or whole alcove model required. | B06, B09 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| DM-10 · Twin Sentinels arena lacks a finished setting | Arena redesign: agent layout/architecture; human taste review | No new boss model. Hero sculpture optional, existing statue assets can be reused. | B01, B07, B09 | [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR02_TWINSENTINELS_ARENA](prompts/AR02_TWINSENTINELS_ARENA.md) |
| BP-01 · Baize arena needs a deliberate edge and encounter identity | Arena redesign: agent layout/terrain/foliage | No new boss model. H03 root module is optional and reusable from Titan. | B06, B09, H03 optional | [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR03_VENERABLEBAIZE_ARENA](prompts/AR03_VENERABLEBAIZE_ARENA.md) |
| LT-01 · Exploration lighting hides route and prop form | Direct code/fixture placement and real-view calibration | Compare normal-profile captures; no new 3D model needed. No need to approve routine numeric fixes before they are made reviewable. |  | [C01_CHAIN_PLACEMENT_AND_READABILITY](prompts/C01_CHAIN_PLACEMENT_AND_READABILITY.md), [C07_INTEGRATED_WINDOWS_ACCEPTANCE](prompts/C07_INTEGRATED_WINDOWS_ACCEPTANCE.md) |
| AC-01 · Champions hall and facade still read as block architecture | ForgeGUI/project reuse where suitable; Agent architecture kit; coordinate with larger Shen arena | No new Rodin model required. | B01, B07 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md), [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR01_GRANDMASTERSHEN_ARENA](prompts/AR01_GRANDMASTERSHEN_ARENA.md) |
| AC-02 · Last-stand props need recognizable sculpted forms | Reuse matching existing statue source; agent small prop variants | No new statue commission required if standing statue source is available. | B09, B10 | [C03_MONASTERY_RUIN_KIT](prompts/C03_MONASTERY_RUIN_KIT.md) |
| AC-03 · Shen arena perimeter has weak colosseum hierarchy | Arena redesign: agent terrain/arcades/seating/landmark | Approve the rendered scene composition; no whole-scene Rodin asset. | B01, B07, B09 | [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR01_GRANDMASTERSHEN_ARENA](prompts/AR01_GRANDMASTERSHEN_ARENA.md) |
| SD-01 · Crypt ceiling and enclosing walls need real architectural form | Supplied approved H03/H04; ForgeGUI/project lookup and Blender preparation/integration | Sources already created. Locate approved exports; creator judges actual in-game appearance/rig fit after a concrete comparison. No automatic regeneration. | H03, B01, B02 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md), [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR04_SLUMBERINGTITAN_ARENA](prompts/AR04_SLUMBERINGTITAN_ARENA.md) |
| SD-02 · Ossuary skulls are 60 featureless spheres on 20 flat plaques | Supplied approved H09; ForgeGUI/project lookup and Blender preparation/integration | Sources already created. Locate approved exports; creator judges actual in-game appearance/rig fit after a concrete comparison. No automatic regeneration. | B02, H09 optional | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| SD-03 · Sarcophagi and crossing lids are plain rectangular masses | ForgeGUI/project reuse where suitable; Agent coffin/lid modules; preserve or explicitly migrate crossing | No new Rodin model required. | B02 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| SD-04 · Titan chains are loose solid blocks rather than linked restraints | ForgeGUI/project reuse where suitable; Agent open-link restraints + code placement | No new Rodin model required; fit to supplied Titan scale. | B05 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| SD-05 · Flooded pit needs believable water and shore treatment | ForgeGUI/project reuse where suitable; Agent water/terrain/grounding | No new Rodin model required. | B06, B09 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md), [AR04_SLUMBERINGTITAN_ARENA](prompts/AR04_SLUMBERINGTITAN_ARENA.md) |
| SD-06 · Thirty candles remain unshaped rods | ForgeGUI/project reuse where suitable; Agent small candle/FX kit | No new Rodin model required. | B10 | [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| CP-01 · Oracle throne is a box chair beneath a small canopy | Supplied approved H02; ForgeGUI/project lookup and Blender preparation/integration | Sources already created. Locate approved exports; creator judges actual in-game appearance/rig fit after a concrete comparison. No automatic regeneration. | H02, B01 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md), [C06_CAST_AND_HERO_ASSET_INTEGRATION](prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md) |
| CP-02 · Great bell is an unadorned solid cylinder | Reuse Foundry_Bell; agent suspension/frame | No new Rodin model required. | B04 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| CP-03 · Lotus pool looks like a rectangle of water and discs | ForgeGUI/project reuse where suitable; Agent small foliage mesh + water/terrain | No new Rodin model required. | B06, B09 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| CP-04 · Gallery, rafters and loft need crafted timber junctions | ForgeGUI/project reuse where suitable; Agent precise timber/stone construction | No new Rodin model required. | B01 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| CP-05 · Wu arena has little ritual identity at floor level | Arena redesign: agent mirror court/lighting/bounds; supplied throne | H02 is the only recommended human focal prop here; whole lake/sky built in engine. | H02, B06, B07, B08 | [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR05_SOVEREIGNWU_ARENA](prompts/AR05_SOVEREIGNWU_ARENA.md) |
| SC-01 · Ten chain posts float above the descending stair | Direct code placement; agent simple chain geometry | No human/Rodin work required. | B05 | [C01_CHAIN_PLACEMENT_AND_READABILITY](prompts/C01_CHAIN_PLACEMENT_AND_READABILITY.md) |
| SC-02 · Dragon perch chains and shed scales are primitive | ForgeGUI/project reuse where suitable; Agent chain/scale reuse; optional human organic crown | Reuse the supplied Wyrm model/materials; H05 is already created; place only if the chosen landmark needs it. | B05, B07, H05 optional | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md), [AR06_AZUREWYRM_ARENA](prompts/AR06_AZUREWYRM_ARENA.md) |
| SC-03 · Bridge and bastion edges need a weathered masonry finish | ForgeGUI/project reuse where suitable; Agent masonry kit; enlarged Wyrm scene | No new Rodin model required; H05 already created; place only if useful. | B01, B07 | [C05_PAGODA_CITADEL_AND_GROUND_DETAIL](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md), [AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES](prompts/AR00_SPATIAL_PLAN_AND_SCALE_PROTOTYPES.md), [AR06_AZUREWYRM_ARENA](prompts/AR06_AZUREWYRM_ARENA.md) |

## Current evidence status

The existing tour covers seven regions and 53 named campaign layout zones with settled actor and/or scripted-camera samples, 135 scripted captures and seven short normal-camera keyboard samples. This remains an assisted visual audit, not an earned all-secrets playthrough. The temporary helper/cheats were restored and both owned Play sessions stopped; the post-tour script digest and canonical place bytes match the pre-tour state. See [restoration.json](../restoration.json).

This production extension adds prompts and references only. Boss assets are creator-reported constructed; their new in-game integration has not been reverified by this document. Proposed arena dimensions are not tested facts. No paid model/image generation or production game change was performed to prepare the packet.

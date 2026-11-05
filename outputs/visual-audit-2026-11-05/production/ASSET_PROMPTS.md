# Asset prompts and division of labour

Updated 6 November 2026. All boss models are creator-supplied: no boss generation jobs are included. H-IDs are proposed non-boss assets; B-IDs are agent-built/reused kits. Asset dimensions are authoring targets, to be adjusted to C00’s measured rig and final AR00 layout.

## Human/Rodin queue

Human input means choosing the design and supplying the approved generated asset, not hand-writing mesh code. Run one H-asset at a time. H01/H02 are the first useful pair; H03 becomes useful after the Titan blockout. H05 is optional. The three cast models can follow independently. Agents should continue code/modular work while an H-asset is pending.

## H01 — Shattered Votive Idol

**Who:** Human concept + Rodin; agent cleanup/placement. **When:** First hero asset. **Fixes:** DM-03.

**Image → Rodin → integration prompt:** [H01_IMAGE_TO_RODIN.md](prompts/H01_IMAGE_TO_RODIN.md).

**Size/construction:** about 11 studs tall intact; approve beside a measured 5–6-stud project rig. One statue body per generation. Agent duplicates/poses matching stone fragments from the same asset; do not generate disconnected heads and body variants in a single image.

## H02 — Throne of the Starless Oracle

**Who:** Human concept + Rodin; agent cleanup/placement. **When:** First hero asset. **Fixes:** CP-01, CP-05.

**Image → Rodin → integration prompt:** [H02_IMAGE_TO_RODIN.md](prompts/H02_IMAGE_TO_RODIN.md).

**Size/construction:** seat top fitted to the measured loft; back roughly 10–14 studs high, not an avatar-sized dining chair. Throne is one asset; its canopy, loft, collision and magical effects are built by the agent. Keep arm/seat negative spaces open.

## H03 — Petrified Root Buttress

**Who:** Human concept + Rodin; agent builds the cathedral from modules. **When:** Titan arena hero detail. **Fixes:** SD-01, SD-05.

**Image → Rodin → integration prompt:** [H03_IMAGE_TO_RODIN.md](prompts/H03_IMAGE_TO_RODIN.md).

**Size/construction:** one 25–40-stud hero segment, not a whole 300-stud room. Generate one segment. The agent makes a few edited/rotated variants and procedural secondary roots; never scale a full-room Rodin lump into the playable crypt.

## H04 — Mourning Gate Relief

**Who:** Human concept + Rodin relief; agent constructs the doorway. **When:** After H01/H02. **Fixes:** DM-08, SD-01.

**Image → Rodin → integration prompt:** [H04_IMAGE_TO_RODIN.md](prompts/H04_IMAGE_TO_RODIN.md).

**Size/construction:** a 10–14-stud-wide relief panel/pediment; fit the frame to the existing secret entrance. One sculpted panel; the agent builds exact modular jambs, doorway opening, supports, roof and collision. Reuse it sparingly, not on every wall.

## H05 — Storm-Eroded Memorial Crown

**Who:** Optional human/Rodin organic accent; agent can omit or approximate. **When:** Optional after arena pilot proves need. **Fixes:** SC-02, SC-03.

**Image → Rodin → integration prompt:** [H05_IMAGE_TO_RODIN.md](prompts/H05_IMAGE_TO_RODIN.md).

**Size/construction:** one 20–30-stud-high crown fragment fixed to a larger agent-built monolith. Optional sculpted top only. Agent builds/reuses the supporting perch/spire and chain sockets; existing Wyrm model is untouched.

## H06 — Lady Lin — Shrine Cast

**Who:** Human approved character concept + Rodin; agent rig/adaptation. **When:** Cast after first environment hero assets. **Fixes:** AP-02.

**Image → Rodin → integration prompt:** [H06_IMAGE_TO_RODIN.md](prompts/H06_IMAGE_TO_RODIN.md).

**Size/construction:** actual CastFigures/CostumeSchema R15 dimensions, not generic realistic adult anatomy. Attach the actual project rig mannequin as the proportion reference. Make the approved front/side/rear consistent; rigging is a separate agent step. No automatic Roblox fit is implied by a concept image.

## H07 — Master Smith Gao — Shrine Cast

**Who:** Human approved character concept + Rodin; agent rig/adaptation. **When:** Cast. **Fixes:** AP-02, SN-01.

**Image → Rodin → integration prompt:** [H07_IMAGE_TO_RODIN.md](prompts/H07_IMAGE_TO_RODIN.md).

**Size/construction:** match Gao live rig and dialogue head/feet anchors. Body/clothing only. Tools remain separate so existing live rig and animations can use them. Preserve actual project proportions instead of baking a pose or held tool into the mesh.

## H08 — The Hermit — Monastery Cast

**Who:** Human approved character concept + Rodin; agent rig/adaptation. **When:** Cast. **Fixes:** AP-02.

**Image → Rodin → integration prompt:** [H08_IMAGE_TO_RODIN.md](prompts/H08_IMAGE_TO_RODIN.md).

**Size/construction:** match the actual Hermit rig and feet-to-head portrait height. One cast body, no permanent dramatic pose; subtle stoop/idle is authored after rigging. Keep face and hands visible for dialogue.

## H09 — Ossuary Skull — optional fallback

**Who:** Agent Blender first; human/Rodin only if the sample is inadequate. **When:** Optional small-asset fallback, not required up front. **Fixes:** SD-02.

**Image → Rodin → integration prompt:** [H09_IMAGE_TO_RODIN.md](prompts/H09_IMAGE_TO_RODIN.md).

**Size/construction:** about one stud at the existing niche scale; verify at actual walking distance. Only use if the one-sample procedural Blender skull fails the gameplay-distance comparison. Generate one skull, then let the agent bake and vary shelf clusters with it.

## What Claude/ChatGPT can model directly with Blender

These are production construction briefs. Use their linked full agent prompts; no preliminary human image generation is required. Ask the agent for one rendered sample before it replicates a family across the world. Procedural geometry is useful for exact profiles and repetition; faces, hands, cloth and hero organic sculpture are the less reliable unattended work.

| ID | Kit | Exact agent construction brief | Prompt |
|---|---|---|---|
| B01 | Ruined architecture kit | Pilaster/base/capital, round/pointed arch segment, broken wall crown, curved eave, snapped timber and half/quarter dome modules. Build exact dimensions and openings procedurally in Blender, with large believable fractures, bevels, solid rear/interior faces, trim/material reuse. Reuse existing Han/lobby/ruin meshes where they already meet the brief. | [C03](prompts/C03_MONASTERY_RUIN_KIT.md) |
| B02 | Funerary kit | One body/lid sarcophagus pair and damaged variant; skull with real cavities and a jaw silhouette; bake 3 bone-shelf cluster variants into niche modules. Produce a one-module walking-distance proof before multiplying it. Human/Rodin skull is optional only if that proof fails, using the single-subject H prompt pattern. | [C04](prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md) |
| B03 | Interaction and smith kit | Coffer with shaped lid/hinges/feet; regional censer shell; timber ladder overlay; shaped anvil/horn, tongs/hammer, tang-bearing blade blanks, pleated bellows and barrel. Separate operational pieces from anchored decoration; exact proxy/interaction dimensions remain controlled in code. | [C02](prompts/C02_INTERACTIVE_PROP_KIT.md) |
| B04 | Bells and vessels | Reuse Foundry_Bell and HanCauldron. Derive a cracked horizontal bell from the same construction, add a crown/clapper/suspension frame. Do not commission duplicate simple bells/censers before examining the asset library. | [C03](prompts/C03_MONASTERY_RUIN_KIT.md) |
| B05 | Forged chain and restraint kit | One open link, alternating-orientation linked static curves, broken link, socket/anchor plate and post joint. Blender curve-instanced/baked geometry is suitable; no physics chain or per-link update loop. Anchor positions come from authored geometry. | [C01](prompts/C01_CHAIN_PLACEMENT_AND_READABILITY.md) |
| B06 | Foliage, garden and water kit | Two notched lotus leaves, one closed/open flower, sparse stems, silver-reed/grass clumps and wet-bank transitions. Agents make meshes/cards and code restrained water/ripple/mist/lighting. Do not send entire water surfaces, fog, skies or particle fields to Rodin. | [C05](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| B07 | Monument and citadel construction | Split cenotaph shaft, basalt terraces, broken aqueduct/arcade, giant modular pier, coped parapet, radial seating fronts, bridge/roof terminations. These are exact geometric construction: an agent with Blender can create them. Hero organic H05 is optional on top, not required for a compelling silhouette. | [C05](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| B08 | Ritual floor and survey materials | Non-glowing readable inlaid stone rings, damaged star chart panels and low ritual stations outside movement lanes. Use UV/material/normal detail and separate authored emissive effects when required. Avoid bright decals that resemble danger telegraphs. | [C05](prompts/C05_PAGODA_CITADEL_AND_GROUND_DETAIL.md) |
| B09 | Grounding and damage kit | A few fractured rubble meshes, fractured tile clusters, coarse ash/snow bank profiles, wet edges, sediment/root seams and material blends. Seeded placement must be surface-aware, varied by scale/rotation within believable constraints, and clear of navigation/interaction volumes. | [C03](prompts/C03_MONASTERY_RUIN_KIT.md) |
| B10 | Small narrative props | Reuse existing weapons/shields where possible; add spearheads, shield rims/grips, broken statue fragments, carved grave-marker profiles, candles with wick/wax. Low-cost static props; prioritize silhouettes visible at walking distance over dense microscopic ornament. | [C03](prompts/C03_MONASTERY_RUIN_KIT.md) |

## Import and color contract

The handoff is an approved appearance plus a game asset, not “1:1 guaranteed.” Neutral source lighting, PBR base-color/normal/roughness/metal maps and consistent material scale help reproduce the reference. Compare in neutral inspection light and the actual authored scene light; shaded/baked highlights can look wrong when the game light changes. Rodin output may need topology, back-face, silhouette, UV and color cleanup.

For export/intake, preserve the high-detail source; make a separate game version with intentional material slots, triangulated exports, named components, pivot and orientation, clean topology and suitable collision proxies. A starting estimate, **not a Roblox limit**: roughly 0.5–4k triangles for reusable ordinary modules, 2–10k for a close interactive prop, and 10–30k per large hero section, followed by on-device measurement. Share textures/mesh IDs instead of uploading every duplicate as a unique asset. Do not force every small object to use a unique high-resolution texture.

Roblox’s [Importer](https://create.roblox.com/docs/studio/importer) supports rigged/PBR 3D intake; check its actual result and hierarchy. [SurfaceAppearance](https://create.roblox.com/docs/art/modeling/surface-appearance) supplies PBR maps; most map setup belongs in the authored asset/import pipeline. Collision shape is a separate choice from visual mesh detail; [mesh collision guidance](https://create.roblox.com/docs/parts/meshes) describes the tradeoff.

Rodin [Gen-2.5 documentation](https://docs.hyper3d.ai/en/api-specification/rodin-gen2-5) permits up to five reference images and recommends little or no additional image-to-3D prompt. Use consistent isolated views of one asset. The connected Agentic tool describes procedural geometry support but is beta; for exact modular dimensions, the repeatable local Blender construction path is preferable here. No claim is made that either route will automatically match Roblox proportions, import correctly or meet the performance budget.

# Claude boss integration prompt pack

Revised on **5 November 2026** using the downloaded GLB metadata, current integration paths and the actual boss-art history in **Review Asura’s Path combat system**. This pack creates prompts only; no game source, model, saved place or uploaded asset was modified.

## Use

Open the matching numbered Markdown file and paste its **entire contents** into Claude with access to this project and the Downloads inputs. Each file is self-contained, including project constraints, asset preparation, rigging, animation, VFX, SFX, integration and acceptance checks. Run **one boss at a time** so changes to shared animation/effect/import code can be reviewed and reused. Claude should implement the prompt, not merely summarize it. `ALL-PROMPTS.md` contains the same six prompts in one file if that is easier to browse. Keep the bundled `references/` folder and [CONCEPT-ART.md](CONCEPT-ART.md) with the prompts: they contain the nine selected concept images, including Shen’s recovered original phase 2 and Iron Bull’s original reference. For a different machine, update the absolute workspace/reference paths to the extracted folder.

| Prompt | Supplied models | Final requested encounter |
|---|---|---|
| [01 Grandmaster Shen](01-grandmaster-shen.md) | Phase 1 + Phase 2 | Two phases; weapons/choreography/hitboxes match the created models, including the P1 guandao if confirmed in the GLB |
| [02 Venerable Baize](02-venerable-baize.md) | Phase 1 + Crimson Phase 2 | Two phases; final crimson crystal form |
| [03 Sovereign Wu](03-sovereign-wu.md) | Phase 1 + Phase 2 | Two phases; five moving charms/orbs, eight P2 halo sections and animated crown strings |
| [04 Slumbering Titan](04-slumbering-titan.md) | One GLB | **One phase**; heavy stone/root articulation, ankle readability, tremors and MagmaWake as an attack |
| [05 Azure Wyrm](05-azure-wyrm.md) | One Grimdark GLB | **One phase**; final charcoal design, animated legs/wings/neck/tail and storm attacks |
| [06 Iron Bull](06-iron-bull.md) | One GLB, additional Downloads discovery | Preserve/polish the existing Twin Sentinels integration and survivor oath |

## High-fidelity Blender workflow, now explicit

All six prompts now require **geometry-preserving modular splitting**, with no decimation or lower-poly replacement of the primary boss asset. Each final triangulated chunk targets at most 18,000 triangles and must remain strictly below 20,000. The prompts require preservation of 2K maps, original normals/UVs, silhouette and sculpt detail, plus coherent rig weights/rest transforms across deforming chunk boundaries.

Blender edits are explicitly part of the task: separate weapons and flying objects, fix fused limbs/jaws, repair local articulation surfaces, build usable cloth/wing/tail rigs, and iterate with source/concept/Studio comparisons. Claude must deliver an editable versioned `.blend` master with source collections, packed or relative textures, named animation Actions, final export collections and per-chunk manifests. A global remesh or blanket smoothing is not the default repair method.

The tree/statue example is treated as a reference workflow. Its static anchoring, tree fusion, colors and broad Workspace cleanup are not copied into boss integration. Boss roots, animated limbs, skin chunks and cosmetic props retain appropriate separate ownership.

Legal per-mesh sizes do not establish total scene performance. The fidelity-preserving approach still requires measured profiling; the prompts retain that evidence requirement and prioritize culling, shared resources and bounded effects over hidden quality reduction.

## What the actual files contain

All nine GLBs contain **one mesh node, no skeleton/skin and no animation clips**. They are high-detail source sculpts, not animation-ready game rigs. Each has one opaque double-sided PBR material and three embedded 2048×2048 PNGs: color, normal and packed metallic/roughness. No material declares an emissive texture. Mesh connectivity, recoverability of individual props and actual GLB appearance still need DCC/Studio inspection; one node does not prove that every surface is connected.

| Download | Source triangles |
|---|---:|
| Grandmaster-Shen-Phase-1-PBR.glb | 500,000 |
| Grandmaster-Shen-Phase-2-PBR.glb | 500,000 |
| Venerable-Baize-Phase-1-PBR.glb | 1,000,000 |
| Venerable-Baize-Phase-2-Crimson-PBR.glb | 1,000,000 |
| Sovereign-Wu-Phase-1-PBR.glb | 1,000,000 |
| Sovereign-Wu-Phase-2-PBR.glb | 1,000,000 |
| Slumbering-Titan-PBR.glb | 1,000,000 |
| Azure-Wyrm-Grimdark-PBR.glb | 1,000,000 |
| Iron-Bull-PBR.glb | 500,000 |

See [asset-audit.json](asset-audit.json) for exact paths, SHA-256 hashes, byte sizes, metadata and texture dimensions. Source files were read, not altered. The audit is metadata inspection, not an import or animation test.

## Decisions already resolved in the prompts

- Titan and Wyrm become single-phase encounters even though BossRoster currently creates two phases for them. Their prompts include final-defeat/HUD/reward regression checks.
- Shen follows the created models. The P1 reference carries a guandao while current code specifies Jian; his prompt directs inspection of the GLB and targeted weapon/animation/hitbox reconciliation rather than substituting a jian to satisfy old code.
- Wyrm uses the latest grimdark charcoal design. Older bright azure/gold and exposed Storm Heart/Thunder Charge concepts do not set this brief.
- Baize uses the final crimson P2 download, with Frost hazard behavior preserved where the gameplay code relies on that tag.
- Wu's source props must be separated or recreated and their frozen duplicates removed. Halo, idle orbit, attack projectiles and staff sphere are distinct owned objects.
- Iron Bull is already mapped and has custom rig/published animation work. His prompt starts with an audit and reuse instead of rebuilding that work blindly.

## Technical sources checked

- [Roblox general model specifications](https://create.roblox.com/docs/art/modeling/specifications): current per-mesh geometry cap and rig requirements. Legal piece sizes do not establish a device performance budget.
- [Roblox PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance) and [SurfaceAppearance](https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance): supported maps, tangent-space normal format and authoring restrictions.
- [Roblox importer](https://create.roblox.com/docs/studio/importer) and [Animation Editor](https://create.roblox.com/docs/animation/editor): actual import/rig/animation workflow and ownership.
- [Khronos glTF specification](https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc): packed roughness in green and metalness in blue.

## Evidence boundary

Completed: static repository inspection, affected integration/caller/source-mapping inspection, GLB/PNG metadata and hashes, paginated reading of the relevant other-chat art history, visual inspection of the selected concepts, unchanged recovery/copying of nine PNGs, and prompt/reference consistency checks. The proposed animation, choreography, VFX and SFX are creative integration briefs, not features claimed to exist today.

Not performed: game implementation, GLB render/import, retopology, rigging, animation/audio production, publishing, Studio integration/play, multiplayer tests or device profiling. No code tests were needed or run for creating these Markdown prompts. Each implementation prompt requires Claude to report those evidence categories separately and keep unavailable capabilities explicit.

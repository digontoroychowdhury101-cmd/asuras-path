# ForgeGUI and Blender production workflow

Updated 7 November 2026. Applies to C00-C07, AR00-AR06, H01-H09 and the optional arena concepts. This changes the implementation instructions; it does not claim that new art, models, imports or performance improvements have been produced.

## Reuse and tool assignment

1. Inspect the existing Roblox libraries, registered models, asset manifests and supplied exports. All nine H-assets and the boss designs already exist. Missing local files are a transfer dependency, not permission to replace the approved design.
2. Search the connected ForgeGUI account's existing website assets, previous MCP generations and the public ForgeGUI published catalog before creating any new asset. Use suitable existing results, including already-published versions, after checking appearance, dimensions, ownership and actual model availability. Keep working project versions when a proposed substitute offers no demonstrated improvement.
3. Use ForgeGUI for genuinely missing decorative/sculptural props and supported asset imagery or material work that improves the current batch. Use an isolated object brief and consistent reference images. Record the candidate comparison and why the retained result fits the region. A generated image of a prop does not supply its geometry.
4. Use Blender for exact construction and adaptation: modular architecture, vaults, arches, domes, stairs, floors, architectural openings, chain runs, support joins, damage variants, UVs, retopology, baking, LODs, pivots, collision proxies and rig fitting. A suitable ForgeGUI mesh can be the starting component for this work.
5. Build the actual arena layout, terrain, traversal, encounter logic, water, atmospheric effects, lighting and gameplay VFX through the existing Roblox systems. Assemble assets into editable architecture. Preserve the measured combat core, camera retreat space and visual hierarchy.

| Family | ForgeGUI role | Blender / Roblox role |
|---|---|---|
| C02 interactive props | Reuse existing coffers, censers and tools; generate only a missing sculptural family | Fit lids, hinges, feet, tool clearances and collision to existing interaction anchors |
| C03 monastery and ruins | Reuse suitable stone ornaments, bells, vessels and architectural components | Construct precise modular ruins, roofs, openings, fractures and PvP ring dressing |
| C04 crypt | Reuse the supplied H03/H04/H09 and suitable existing funerary props | Build vaults/niches, simplify skull clusters, fit coffins, restraints and reliable floors |
| C05 Pagoda/Citadel | Reuse/generate missing decorative fixtures, foliage components or sculpted trim | Fit timber joints, parapets, chains, gardens, surfaces and in-engine water/lighting |
| C06 hero/cast | Search for registered copies of the approved supplied assets; no new designs | Optimize/fix the actual supplied models, fit cast rigs and validate import |
| AR01-AR06 | Reuse suitable owned architectural/sculptural assets; generate missing focal components | Build precise arenas, routes, scenic layers, gates, collision, lighting and camera clearances |
| C00 / C01 / AR00 / C07 | Read/search/inventory only; no paid generation | Survey, numeric repair, measured prototypes and actual acceptance checks |

## Discover capabilities instead of assuming them

On each computer, discover the actual ForgeGUI, Blender and Studio connections before relying on them. Record account/creator identity without exposing tokens or credentials. A usable connection on Mac does not establish a usable connection on Windows. If a tool is absent or a route is unavailable, record the limitation and continue independent work.

The ForgeGUI tools exposed during the 7 November inspection provide:

- `library_search` and `library_details` for the public published ForgeGUI catalog. Search relevant families/synonyms and inspect candidates by the returned slug. Record actual model download/type and reuse terms; do not pass a public slug to a tool that requires an owned artifact reference.
- `personal_assets_search` and `personal_asset_details` for this account's completed website/chat assets. Search by family and synonyms, inspect candidate details and retain the returned artifact references.
- `generation_list` and `generation_status` for earlier MCP jobs. Check relevant completed and in-progress jobs before issuing another request.
- `asset_capabilities` for enabled preparation/publication routes and their limits. Recheck it during execution; availability can change.
- `generation_model_3d` for missing model generation and `generation_remesh_3d` for compatible account-owned ForgeGUI generation results. Do not assume the remesh tool accepts an arbitrary local Rodin GLB; use Blender for those exports unless a compatible intake route is actually verified.

The connected-account website model search and previous MCP model-job listing both returned no items during this read-only inspection. Public library searches for ruins, stone and statue also returned no items with search_status=complete. These are bounded query results at that time, not evidence that every asset family or the whole catalog is empty. Search for each actual batch's needs during execution. The exposed toolbox_search can also inspect Roblox Toolbox candidates through ForgeGUI when appropriate; record complete/partial/stale coverage and inspect imported content before retaining it. Never invent a catalog match, download or asset ID.

At the inspected capability version `asset-capabilities-v5`, GLB preparation, tiled texture preparation and skybox preparation were enabled. Mesh-UV validation and provider-animation-to-Roblox retargeting/upload were unavailable. These are historical capability observations, not guarantees for a later session. Check UVs in Blender and preserve the established animation pipeline. Provider rigs and stock clips are not automatically compatible with the game's custom bosses or Roblox R15.

For optional 16:9 scene concepts, use a supported opaque image route; the currently exposed `thumbnail` family is suitable. Do not request a whole scene as a transparent GUI cutout. Ordinary PBR materials need correct maps and UVs; a GUI image or a single shaded color image is not a complete material set.

## Completed model handoff and performance

The supplied archive is `AsurasPath_Asset_Handoff_2026-11-07.zip`. It contains all nine H01-H09 source models, nine boss source GLBs, an alternate H01 PBR export, references, an inventory and checksums. It is available through the creator's transfer folder; do not assume it is tracked in Git. It does not contain the latest rigged/animated Shen implementation being debugged on Mac.

The inspected source GLBs declare mostly 1,000,000 triangles; Shen P1/P2 and Iron Bull declare 500,000 each. They have no skins or clips. These are static source metadata counts. Preserve masters and prepare separate game copies before widespread production placement. The H01/H02 files named shaded contain one image; inspect their actual material treatment and preserve the supplied appearance while preparing correct game materials.

Record unique and instantiated geometry counts, mesh/material counts, texture dimensions, skeleton/animation costs, collision choices and reuse counts. Select budgets by object size, screen coverage, repetition and target device; an importer's maximum is not a recommended runtime budget. Bake small surface detail, retain silhouette-critical geometry, use simpler collision and reuse uploaded mesh/material IDs. Splitting a million-triangle object into many MeshParts does not remove its overall geometry cost.

Compare one representative game version against the original at normal gameplay distance before replicating it. Profile comparable scenes with the same camera, graphics settings and workload, including boss animation/VFX and repeated encounters. Report frame times, spikes and memory separately for Windows, Mac and other supported target devices. Static counts, a successful remesh/import, and a powerful-PC screenshot do not prove FPS or gameplay feel.

## Job handling and publication

The creator requested ForgeGUI use for missing in-scope assets. Complete one representative candidate per needed family, inspect it and reuse successful results before requesting variants. Keep the established visual direction; do not expand this into unrelated GUI/music work or a new generation queue for the nine finished models. C00, C01, AR00 and C07 make no paid generation calls; C06 integrates approved existing models.

Record the request ID, job/artifact ID, prompt, references, version, quoted/reported credit cost and final status. Use stable idempotency keys and poll an existing job. Never regenerate an `outcome_unknown` job. On `insufficient_credits` or `upgrade_url`, explain that ForgeGUI credits ran out, link [ForgeGUI plans](https://forgegui.com/plans), stop paid calls and continue independent work. After credits are replenished, a refused request needs a new request ID. Do not purchase credits or change subscriptions automatically.

Use direct/file delivery while preparing and inspecting new assets. If publication of the chosen game asset is necessary, discover the eligible existing Roblox creator connection, verify it is the intended creator and record the resulting asset IDs. Do not assume an asset is usable by this experience merely because publication succeeded. Verify permissions/loading and actual Studio integration. Do not publish the game itself as part of these prompts, create new credentials or expose secrets in reports.

## Parallel work and evidence

Windows arena work uses `codex/windows-arenas` in an isolated checkout/build while Mac owns active Shen integration, unless the creator explicitly assigns otherwise. This overrides older blanket relay-branch instructions. One integration owner combines shared mapping, bounds, spawn and camera changes at a deliberate checkpoint. Commit only owned files; no broad staging, automatic rebase/autostash or force-push.

Continue independent art with measured/provisional proxies when necessary, recording the boss version and dimensions used. Refresh affected measurements when a stable rig arrives. Preserve server authority and existing timings, rewards and hurtboxes; ornamental geometry must not force gameplay changes. Keep source inventory, prepared assets, imported assets, normal-input acceptance, real multiplayer and profiling as separate statuses. The asset manifest must distinguish project reuse, ForgeGUI reuse, new ForgeGUI generation, supplied Rodin source and Blender-authored components.

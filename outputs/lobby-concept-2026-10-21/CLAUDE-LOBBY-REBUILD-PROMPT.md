Implement the attached lobby concepts in my existing Roblox game. I want the finished environment built and visually checked, not just a plan.

Project: /Users/digonto/Documents/ChatGPT/Roblox game 2

Open and inspect these images before editing:
- outputs/lobby-concept-2026-10-21/01-entrance-keyframe.png
- outputs/lobby-concept-2026-10-21/02-elevated-layout.png
- outputs/lobby-concept-2026-10-21/current-lobby-reference.jpg
Read outputs/lobby-concept-2026-10-21/DESIGN-BRIEF.md, PROJECT_STATE.md, CLAUDE.md, docs/PROJECT_VERSIONS.md and applicable AGENTS.md instructions.

ART DIRECTION
Rebuild the Shrine of the Ascendant as a richly crafted Chinese wuxia sanctuary above clouds. Preserve the existing imported veiled woman statue and enormous sacred tree, including their proportions, textures and composition. Keep the bonfire → stairs → gateway → statue sightline.

Match the images through architectural silhouettes, layered terraces, materials and lighting:
- Weathered blue-grey paving, carved stone balustrades and substantial layered rock foundations.
- Charcoal tiled roofs with convincing curved eaves, dark vermilion timber, restrained bronze details.
- Shallow reflective jade-grey pools with readable rims and sparse crimson leaves.
- A low central bonfire, warm lantern light and bright enough ambient fill to see floors and characters.
- Connected covered galleries: working forge on the west, recognizable accessible duel court on the east.
- Broad connected stair flights and landings; a modest gateway that frames the statue.
- A few distinctive carved stelae and ruins around the upper terrace instead of repetitive plain columns.

Treat the images as art direction, not surveyed geometry. Preserve actual statue/tree scale even where the paintings crop the canopy. Resolve circulation from the existing source. Keep the Well of Descent and reliquary reachable; the aerial painting shifts their location for presentation. Distant waterfalls and buildings are optional atmosphere.

IMPLEMENTATION
First inspect the live lobby and identify the active source/build. Preserve unrelated existing edits. Work from this checkout, not old Studio snapshots. Inspect SanctuaryService, SanctuaryColossus, SanctuaryTitan, SanctuaryDressing, SanctuaryApproach, shared SanctuaryRoutes/WorldDefinitions, EnvironmentProfiles, EnvironmentController and the asset registry/library.

Make persistent source and asset changes. Workspace-only edits that disappear on Play or rebuilding are insufficient. Use small strict Luau modules, following the project's module-size conventions. Preserve gameplay services and interactions: spawn, rest/checkpoint, Lady Lin, forge, story travel, optional crypt/reliquary routes and PvP. If visual placement changes, update the relevant anchors and collision deliberately while retaining gameplay identifiers.

ASSET WORK
Use Roblox Studio for assembly, layout, lighting, water, interaction and collision. Use Blender for the custom modular architecture and rockwork needed to approach the concept. Blender is installed at /Applications/Blender.app/Contents/MacOS/Blender; inspect and reuse the existing tools/blender pipeline.

Build a coherent reusable kit: roof/eave sections, timber columns/brackets, carved railing bays, stair/landing pieces, lanterns, paving variants and layered cliff modules. Reuse suitable existing assets first. Use primitives for simple construction and collision; model the curves, profiles and silhouette details that matter. Avoid replacing every detail with hundreds of small blocks.

Automate repeatable modeling/export with Blender Python where practical. Keep editable sources, generation scripts and exports. Apply transforms, check normals/UVs and scale, preserve material seams, and use shared materials/textures. Follow existing project mesh budgets and PBR conventions; bake unsupported shader detail to maps. Do not reprocess the existing statue/tree.

Import through the available supported workflow, verify actual uploaded mesh/texture IDs, and persist the templates in the Rojo-mapped asset library. A GLB on disk is not an integrated asset. Track reused external asset provenance. If an account-controlled import step is unavailable, finish the export package and unaffected work, then identify the precise remaining step without claiming integration is complete.

WORK ORDER
1. Establish camera sightlines and player-scale circulation.
2. Build one polished representative courtyard section with final paving, water, railing, roof and lantern materials.
3. Inspect it in Studio and correct it against the reference before repeating the kit.
4. Extend the kit through the courtyard, forge, duel promenade, stair/gateway and statue terrace.
5. Finish Sanctuary lighting, sparse foliage and environmental dressing.

Edit the existing Sanctuary environment profile so lighting survives client updates and travel. Verify other regions retain their intended appearance.

ACCEPTANCE
Build and run the current game. Visually compare before/after screenshots from the same entrance camera, an elevated layout camera, and normal gameplay height. Check spawn, rest, NPC/forge interactions, story portal, duel access, optional routes, falls, camera clearance and output errors. Use relevant existing checks; add tests only for meaningful changed behavior.

Inspect real Studio frame-time/rendering statistics where available. Reuse meshes/materials, simplify decorative collision and control lights, transparency and particles. Report measured results and anything still unverified.

Deliver the integrated lobby, reusable asset sources, before/after screenshots, changed-file summary and remaining limitations. Continue through implementation and visual correction; do not stop after planning or call a primitive blockout finished. Do not publish the experience.


# H04 — Mourning Gate Relief

**Owner:** Approved source already created; ForgeGUI lookup/reuse; Blender game preparation

## Existing asset first — 7 November update

This H-asset has already been created. Locate the approved export in the supplied handoff or registered project assets, and search existing ForgeGUI assets/jobs before authoring anything. Do not generate it again because it is absent from this machine. Preserve the approved design and source, then use Blender for the game copy, UVs, baking, fitting and any required rig adaptation. The image/3D briefs below are retained design references; run a replacement only if the creator explicitly requests a new design. Read [ASSET_WORKFLOW.md](../ASSET_WORKFLOW.md).


**Priority:** After H01/H02

**Target scale:** a 10–14-stud-wide relief panel/pediment; fit the frame to the existing secret entrance

**Audit:** DM-08, SD-01

## Retained image design brief — not a new generation task

```text
Create a single-object 3D asset concept render for an original grim dark fantasy game. Show one complete subject in a neutral front three-quarter view, fully within frame with generous padding. Neutral mid-grey studio background, even soft white lighting, sharp surface description with readable shadows and natural material colors. Do not bake dramatic colored light into the design. No text, labels, watermark, game HUD, dramatic camera distortion, collage, multiple unrelated objects, stand, cast-shadow floor or scenery. Separate materials by believable construction. Show robust physically connected forms, intended negative spaces and sufficient thickness; fine wear belongs in the surface, not hundreds of detached specks. This is an object reference for image-to-3D, not an environment painting.

One original weathered limestone funerary relief panel from an ancient grim fantasy tomb, substantial and thick enough to be a real architectural fragment. Two hooded mourners kneel in profile around an unlit hanging bronze censer; their draped stone hands point downward into an empty central circular recess. Broad legible low relief, worn faces, broken upper left corner, chisel marks, soot-dark recesses, restrained pale mineral runoff and old root pressure cracks. The panel has a squared flat rear mounting face and a heavy chipped perimeter. Classical sepulchral construction with no modern symbols; not a flat illustration painted on stone. No complete doorway, no stairs, no room, no inscription text.
```

## Optional additional view prompt

```text
Using the approved image as the only design authority, render a true side view of the exact same object, unchanged proportions, silhouette details, material assignments and damage locations. Neutral matching studio lighting/background. One full object, no labels or other views. Do not redesign its hidden side. If the reference cannot determine a hidden construction detail, choose the simplest physically consistent continuation. Then repeat this request separately for a rear three-quarter view and visually compare for contradictions before using them as additional Rodin references.
```

## Existing 3D asset and conditional ForgeGUI route

Reuse the approved export first. If the creator explicitly requests a replacement later, search existing ForgeGUI models/jobs before using its verified 3D generation route. Blender handles precise fitting, UVs, baking and rig adaptation. The IMAGE_TO_RODIN filename is retained for existing links; this workflow now follows ASSET_WORKFLOW.md.

For any separately authorized replacement, use the approved single-object image as the primary reference. Additional images must be consistent views of that same object, not this whole document or a moodboard. Inspect geometry and textures before export. For image-to-3D, the image should carry the design; a long second descriptive prompt is unnecessary. If orientation guidance is needed, use only this short prompt:

```text
Reconstruct only the approved object. Preserve its silhouette, material separation, proportions, damage and open negative spaces. Keep a clean mounting/base plane; omit backdrop and ground. No extra ornament or geometry.
```

One sculpted panel; the agent builds exact modular jambs, doorway opening, supports, roof and collision. Reuse it sparingly, not on every wall.

## Agent intake and integration

Locate the already-approved source image(s), chosen result/version and GLB or FBX with available material maps, and any rejected parts/repair notes under the repository's asset intake convention. The agent performs scale/pivot cleanup, retopology/baking where needed, maps/import/registration, placement, collision proxies or rig adaptation, and Studio checks using [C06_CAST_AND_HERO_ASSET_INTEGRATION.md](../prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md). A 2D image or Rodin export does not itself prove rigging, body-proportion fit or correct Roblox materials. Do not regenerate the asset just because a map slot is empty: resolve file handoff first.

# H01 — Shattered Votive Idol

**Owner:** Human concept + Rodin; agent cleanup/placement

**Priority:** First hero asset

**Target scale:** about 11 studs tall intact; approve beside a measured 5–6-stud project rig

**Audit:** DM-03

## Copy into ChatGPT image generation

```text
Create a single-object 3D asset concept render for an original grim dark fantasy game. Show one complete subject in a neutral front three-quarter view, fully within frame with generous padding. Neutral mid-grey studio background, even soft white lighting, sharp surface description with readable shadows and natural material colors. Do not bake dramatic colored light into the design. No text, labels, watermark, game HUD, dramatic camera distortion, collage, multiple unrelated objects, stand, cast-shadow floor or scenery. Separate materials by believable construction. Show robust physically connected forms, intended negative spaces and sufficient thickness; fine wear belongs in the surface, not hundreds of detached specks. This is an object reference for image-to-3D, not an environment painting.

An original ancient votive idol for a grim fantasy burial monastery: a stooped faceless pilgrim carved from weathered grey limestone, heavy layered stone robes, long hands enclosing an extinguished lantern at the sternum, an eroded empty hood, restrained bronze collar stains. One shoulder and the lower robe are broken away, with thick believable fracture surfaces; the remaining body is a coherent recognizable figure. Quietly disturbing and heavy, not a generic heroic knight. Subtle sediment, age-darkened recesses, large readable folds and few meaningful carved marks. No sword, no boss character, no wings. Design the statue itself, not its environment or pedestal.
```

## Optional additional view prompt

```text
Using the approved image as the only design authority, render a true side view of the exact same object, unchanged proportions, silhouette details, material assignments and damage locations. Neutral matching studio lighting/background. One full object, no labels or other views. Do not redesign its hidden side. If the reference cannot determine a hidden construction detail, choose the simplest physically consistent continuation. Then repeat this request separately for a rear three-quarter view and visually compare for contradictions before using them as additional Rodin references.
```

## Feed into Rodin

Use the approved single-object image as the primary reference. Additional images must be consistent views of that same object, not this whole document or a moodboard. Inspect geometry and textures before export. For image-to-3D, the image should carry the design; a long second descriptive prompt is unnecessary. If orientation guidance is needed, use only this short prompt:

```text
Reconstruct only the approved object. Preserve its silhouette, material separation, proportions, damage and open negative spaces. Keep a clean mounting/base plane; omit backdrop and ground. No extra ornament or geometry.
```

One statue body per generation. Agent duplicates/poses matching stone fragments from the same asset; do not generate disconnected heads and body variants in a single image.

## Human supplies / agent completes

Supply the approved source image(s), chosen result/version, GLB or FBX with PBR maps, and any rejected parts/repair notes under the repository's asset intake convention. The agent performs scale/pivot cleanup, retopology/baking where needed, maps/import/registration, placement, collision proxies or rig adaptation, and Studio checks using [C06_CAST_AND_HERO_ASSET_INTEGRATION.md](../prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md). A 2D image or Rodin export does not itself prove rigging, body-proportion fit or correct Roblox materials. Do not regenerate the asset just because a map slot is empty: resolve file handoff first.

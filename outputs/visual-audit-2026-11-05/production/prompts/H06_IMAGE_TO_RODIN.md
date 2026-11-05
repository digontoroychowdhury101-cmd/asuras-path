# H06 — Lady Lin — Shrine Cast

**Owner:** Human approved character concept + Rodin; agent rig/adaptation

**Priority:** Cast after first environment hero assets

**Target scale:** actual CastFigures/CostumeSchema R15 dimensions, not generic realistic adult anatomy

**Audit:** AP-02

## Copy into ChatGPT image generation

```text
Create a single-object 3D asset concept render for an original grim dark fantasy game. Show one complete subject in a neutral front three-quarter view, fully within frame with generous padding. Neutral mid-grey studio background, even soft white lighting, sharp surface description with readable shadows and natural material colors. Do not bake dramatic colored light into the design. No text, labels, watermark, game HUD, dramatic camera distortion, collage, multiple unrelated objects, stand, cast-shadow floor or scenery. Separate materials by believable construction. Show robust physically connected forms, intended negative spaces and sufficient thickness; fine wear belongs in the surface, not hundreds of detached specks. This is an object reference for image-to-3D, not an environment painting.

One original female shrine attendant for Asura’s Path, a restrained grim fantasy character. Calm weathered face, dark hair tied into a simple practical knot with a dull bronze pin, layered ash-cream robes beneath a faded cinnabar outer garment, charcoal sash, small worn jade pendant and cloth shoes. A memorable clean silhouette, believable heavy cloth folds, human hands visible and separated from the torso, practical modest clothing, no jewelry clutter. Front three-quarter neutral A-pose with feet apart and elbows slightly bent so shoulders, wrists, hips, knees and ankles are all distinct. Adapt proportions to the attached actual Roblox project rig: preserve its head/torso/limb lengths and joint centers. No photoreal tall fashion-model proportions, no weapon, floor, props or scenery.
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

Attach the actual project rig mannequin as the proportion reference. Make the approved front/side/rear consistent; rigging is a separate agent step. No automatic Roblox fit is implied by a concept image.

## Human supplies / agent completes

Supply the approved source image(s), chosen result/version, GLB or FBX with PBR maps, and any rejected parts/repair notes under the repository's asset intake convention. The agent performs scale/pivot cleanup, retopology/baking where needed, maps/import/registration, placement, collision proxies or rig adaptation, and Studio checks using [C06_CAST_AND_HERO_ASSET_INTEGRATION.md](../prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md). A 2D image or Rodin export does not itself prove rigging, body-proportion fit or correct Roblox materials. Do not regenerate the asset just because a map slot is empty: resolve file handoff first.

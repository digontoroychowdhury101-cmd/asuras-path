# H09 — Ossuary Skull — optional fallback

**Owner:** Agent Blender first; human/Rodin only if the sample is inadequate

**Priority:** Optional small-asset fallback, not required up front

**Target scale:** about one stud at the existing niche scale; verify at actual walking distance

**Audit:** SD-02

## Copy into ChatGPT image generation

```text
Create a single-object 3D asset concept render for an original grim dark fantasy game. Show one complete subject in a neutral front three-quarter view, fully within frame with generous padding. Neutral mid-grey studio background, even soft white lighting, sharp surface description with readable shadows and natural material colors. Do not bake dramatic colored light into the design. No text, labels, watermark, game HUD, dramatic camera distortion, collage, multiple unrelated objects, stand, cast-shadow floor or scenery. Separate materials by believable construction. Show robust physically connected forms, intended negative spaces and sufficient thickness; fine wear belongs in the surface, not hundreds of detached specks. This is an object reference for image-to-3D, not an environment painting.

One original weathered human skull for a non-gory dark fantasy ossuary prop. A coherent anatomically recognizable cranium, deep paired eye cavities, triangular nasal cavity, readable cheekbones, upper teeth and a partly damaged separate-looking lower jaw. Dry aged ivory bone with pale mineral deposits, fine restrained cracks and dark cavities, no flesh or blood. Large shapes must read at small game-prop scale. Full skull, slight front three-quarter angle with rear cranium visible, empty negative spaces, no stand, plaque, bones, candle, scenery or dramatic lighting. Not a sphere with features painted onto it.
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

Only use if the one-sample procedural Blender skull fails the gameplay-distance comparison. Generate one skull, then let the agent bake and vary shelf clusters with it.

## Human supplies / agent completes

Supply the approved source image(s), chosen result/version, GLB or FBX with PBR maps, and any rejected parts/repair notes under the repository's asset intake convention. The agent performs scale/pivot cleanup, retopology/baking where needed, maps/import/registration, placement, collision proxies or rig adaptation, and Studio checks using [C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md](../prompts/C04_CRYPT_ARCHITECTURE_AND_FUNERARY_KIT.md). A 2D image or Rodin export does not itself prove rigging, body-proportion fit or correct Roblox materials. Do not regenerate the asset just because a map slot is empty: resolve file handoff first.

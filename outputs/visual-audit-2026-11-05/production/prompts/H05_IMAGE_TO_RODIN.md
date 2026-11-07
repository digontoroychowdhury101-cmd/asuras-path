# H05 — Storm-Eroded Memorial Crown

**Owner:** Approved source already created; ForgeGUI lookup/reuse; Blender game preparation

## Existing asset first — 7 November update

This H-asset has already been created. Locate the approved export in the supplied handoff or registered project assets, and search existing ForgeGUI assets/jobs before authoring anything. Do not generate it again because it is absent from this machine. Preserve the approved design and source, then use Blender for the game copy, UVs, baking, fitting and any required rig adaptation. The image/3D briefs below are retained design references; run a replacement only if the creator explicitly requests a new design. Read [ASSET_WORKFLOW.md](../ASSET_WORKFLOW.md).


**Priority:** Optional after arena pilot proves need

**Target scale:** one 20–30-stud-high crown fragment fixed to a larger agent-built monolith

**Audit:** SC-02, SC-03

## Retained image design brief — not a new generation task

```text
Create a single-object 3D asset concept render for an original grim dark fantasy game. Show one complete subject in a neutral front three-quarter view, fully within frame with generous padding. Neutral mid-grey studio background, even soft white lighting, sharp surface description with readable shadows and natural material colors. Do not bake dramatic colored light into the design. No text, labels, watermark, game HUD, dramatic camera distortion, collage, multiple unrelated objects, stand, cast-shadow floor or scenery. Separate materials by believable construction. Show robust physically connected forms, intended negative spaces and sufficient thickness; fine wear belongs in the surface, not hundreds of detached specks. This is an object reference for image-to-3D, not an environment painting.

One original storm-eroded architectural crown fragment for a grim fantasy mountaintop ruin. Charcoal-grey basalt and fossilized ivory stone have fused into a single skeletal arch crest: three thick swept ribs emerge from a broad cracked stone socket and converge around a large off-center empty aperture. Ancient weight and wind erosion, blunt broken ends, a few inset oxidized bronze binding plates, thin natural silver mineral seams. The outline feels like a dead civilization’s weather-beaten beacon, never a living dragon, skull boss, throne, weapon or generic spiky demon. Strong chunky silhouette with a few deep negative spaces. No lightning, glow, hanging chains, floor, rock mountain or surrounding ruins.
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

Optional sculpted top only. Agent builds/reuses the supporting perch/spire and chain sockets; existing Wyrm model is untouched.

## Agent intake and integration

Locate the already-approved source image(s), chosen result/version and GLB or FBX with available material maps, and any rejected parts/repair notes under the repository's asset intake convention. The agent performs scale/pivot cleanup, retopology/baking where needed, maps/import/registration, placement, collision proxies or rig adaptation, and Studio checks using [C06_CAST_AND_HERO_ASSET_INTEGRATION.md](../prompts/C06_CAST_AND_HERO_ASSET_INTEGRATION.md). A 2D image or Rodin export does not itself prove rigging, body-proportion fit or correct Roblox materials. Do not regenerate the asset just because a map slot is empty: resolve file handoff first.

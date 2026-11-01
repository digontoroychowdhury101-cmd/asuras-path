# Frost-step source and imported calibration

Variant A is uploaded and integrated as the three optional ridge landing visuals. B/C remain local
source variants. The actual native library is `assets/models/AsuraBambooFrostSteps.rbxmx`; real mesh and
PBR IDs, scale, source hash and permission checks are in `assets/BAMBOO_FROST_STEPS_UPLOADED.json`.
The representative import is 384 triangles, upright at 1:1 scale, with its pivot at the foot. Actual
EditableMesh readback finds a maximum landing-corner error of 0.0000024 studs. Mesh preload and four
correctly typed ImageLabel image preloads succeeded. Untyped URI-string image checks were insufficient.

The separate factory-startup Blender source is `assets/build/frost_steps_v1/FrostSteps_Master.blend`;
three GLBs, 2048 colour/normal and 1024 roughness maps remain beside it. Repository convention keeps
those local masters ignored. `tools/blender/frost_steps.py` reproduces them into a new directory; the
existing live Blender scene and earlier source masters were preserved. Each actual GLB reimports as
384 triangles / one UV set / one material, 1,152 triangles across all three source options. The offline
review raycasts all four landing corners and centre at Z=4. Offline previews are source checks only.

The stone treatment reuses already credited Terrain3D / ambientCG Rock023 maps; original geometry and
frost blending were added. Three decorative copies form the caps; three scaled copies with existing
CragC maps form supports: six meshes / 2,304 triangles. The supports visibly stretch those maps and
remain a refinement task. The first pointed CragC support attempt was rejected and retained separately.

The three original 4x4x4 landing colliders, transforms, top heights and jump gaps are preserved.
Three additional 3.5x3.5 footings extend from Y=-2 into their undersides, bringing Bamboo collision
parts from 73 to 76. All six mesh visuals are noncolliding, nonqueryable and nontouching. Actual normal
jump/return regression remains PENDING; offline collision checks do not establish playable completion.

Actual Play comparisons are in `../frost-steps/`, including the ground view showing the original
floating white cubes. Before and after use the same camera poses, but window sizes and Automatic
FRM quality differ; these are placement/material diagnostics, not matched final-quality acceptance.
No public game publication, spending or paid generation occurred. The native import snapshot remains
local under ignored `../frost-import/`; the extracted library is included in the canonical build.

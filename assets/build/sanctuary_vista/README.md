# Sanctuary vista landscape kit

Generated 22 October 2026 with installed Blender 5.2.2 LTS using `tools/blender/sanctuary_vista.py`.

- `AsuraSanctuaryVista.glb`: Studio 3D Importer input, 4 pieces / 7 single-material meshes.
- `AsuraSanctuaryVista.blend`: editable original geometry and materials before QA cameras/lights.
- `manifest.json`: base-centre piece pivots, imported Roblox-space bounds, individual part centres/sizes, triangle counts.
- `validation.json`: checks of the actual GLB primitive triangle counts, normals, UVs and material splitting.
- `preview_sheet.png`, `preview_crown.png`: final Blender QA renders. These are asset previews, not in-game screenshots.
- `VistaRock_Color.png`, `VistaRock_Normal.png`, `VistaRock_Roughness.png`: reused source scan resized to 1024 for this kit; embedded in GLB. Black metalness uses the existing lobby kit map.

## Models

`Vista_Crown` contains a massive broad summit and three subordinate buttresses. `Vista_Ridge` contains an asymmetrical four-peak saddle. `Vista_Needle` contains a tall narrow summit and two attached shoulders. Each has a separate olive moss-crown MeshPart. These are non-colliding distant scenery, intended for varied rotations and sizes among the existing cloud kit. Sink their broad bases into the cloud layer. Place small existing pavilion assets on selected summits to sell scale; alternate mountains with more distant smaller versions and atmospheric depth rather than using all peaks at one uniform distance.

`Vista_Waterfall` contains five thin ribbons and a flared foot. This intentionally uses an opaque pale material in the export. In Studio set DoubleSided, no shadow, no collision, color near (185,210,212), transparency 0.55–0.7, and supplement sparingly with the existing authored mist particle texture. The mesh sits at foot origin, extends 120 studs upward, and is 12.5 studs wide. Do not use it as movement collision.

The rock meshes are closed, shaded with explicit sharp-angle boundaries, and contain real layered erosion/fissure/summit geometry. No statue or sacred-tree files were modified. Max part triangle count is 18,928; whole kit is 53,002 triangles. Repeated distant placement should use Automatic render fidelity, no collision/query/touch/shadows where appropriate and a bounded instance count.

## Persistent Studio integration

Import as Creator Me, World Forward Front / World Up Top, matching the existing lobby import orientation. Original Blender coordinates map to Roblox (-x,z,y). Mesh geometry is laid out in separate slots; `layoutOrigin` describes each slot. Build each template from its manifest parts with identity part rotation, the manifest centre as Position and manifest size as Size. Its WorldPivot is origin. The new template names are `Vista_Crown`, `Vista_Ridge`, `Vista_Needle`, `Vista_Waterfall`, with part names such as `Vista_Crown__Rock`.

Reuse uploaded maps from this GLB's imported rock SurfaceAppearance. The plain moss and water material parts intentionally have no SurfaceAppearance. `SanctuaryKit.place` supports these parts. The older generic `PbrAssets.place` requires complete PBR on every MeshPart and is unsuitable without adapting its policy. Existing `extract_lobby_kit.py` has a fixed expected set and rejects new names, so extend that manifest set deliberately or preserve this kit in a separate library; do not discard the current lobby library or its shared strings. Capture real imported IDs, persist the model in a Rojo-mapped library, rebuild/reopen, and visually verify in Studio before claiming integration.

## Provenance

Geometry is newly authored procedural Blender work for this project. Rock textures reuse the project's existing Poly Haven `rock_face_03` CC0 source files in `assets/source/tex`, whose provenance is already documented in `assets/CREDITS.md`. No new external asset was downloaded.

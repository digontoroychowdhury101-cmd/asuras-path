# Root material investigation — 31 October 2026

The world goal remains active and unfinished. Production still has **261 scripts / 1,943,649 bytes /
digest 458197530**; the connected canonical place matches in Edit. This batch changes tools and prepares
an **uninstalled** art candidate. It does not claim another region is finished or a new performance pass.

## What the inspection found

The previous actual Sanctuary views show a blurred lower root mass, angular canopy leaves and a
crowded east reveal. Studio's permission-checked EditableMesh API successfully recovered 16 original
lower-trunk sections, plus a separate root and leaf sample, with exact vertices, corner normals, UVs,
template transforms and PBR references. Existing uploads, source masters and the game library remain intact.

The original lower sections have approximately **0.75 pixels per production stud at 1024**, or 1.5 at
2048, measured by surface-area-weighted median. The template figure is 100.000002 studs and production
is 150, confirming the 1.5 scale used by this calculation. The separate tendril root has about 29.4
pixels/stud at 1024. Adding polygons would not fix this density difference.

The readback maps are 1024×1024 because EditableImage is capped at that size. **This does not establish
the native renderer's texture resolution.** Macro colour and existing normal detail were retained as
read back, then rebaked with new detail. Original higher-resolution sources were not overwritten.

## Candidate and rejected attempts

- The first 16-section smart-projection atlas looked worse: approximately 0.33 pixels/stud at 2048,
  blurred detail and dark seams. Rejected; never uploaded or installed. A connected UV carrier improves
  chart continuity, but the second full-base atlas still failed its density gate before baking.
- The four-section pilot (`Titan_Canopy_13`–`16`) retains the original UV charts and packs them on a
  temporary connected carrier. Original exported vertices, faces and custom normals are untouched.
  The final atlas has about **3.8 pixels/stud at 2048** (2.5× the original at the same map size).
- Version 3's grain was too faint. `root-detail-offline-v4/` shows the revised offline comparison:
  visible bark grain and the original broad shading, with no first-attempt dark triangles. Broad soft
  colour patches remain. These are material crops of one section, whose cut edges are exposed because
  neighbouring sections are hidden; **they are not game views or silhouette-completion evidence**.
- The actual GLB, then its tangent-enabled copy, were imported into a separate factory Blender process:
  **62,405 evaluated triangles / four meshes / max 15,602 per mesh**, one UV set and material each,
  maximum vertex-position delta **0.0**. Bake-time custom-normal delta is **0.0**. See the round-trip JSONs.
  The pilot still requires Studio import, scale/normal/seam checks and an actual gameplay comparison.

Local sources (normal repository convention keeps `assets/build/` ignored):

- `assets/build/fused_tree_base_recovered_2026-10-31/`: 16 sections, 249,622 triangles, checksummed
  geometry and the capped map readbacks.
- `assets/build/fused_tree_recovered_2026-10-31-b/`: root, lower trunk and leaf samples, 32,491 triangles.
- `assets/build/fused_root_detail_pilot_v4/`: separate `.blend`, 2048 colour/normal masters, 1024
  roughness, GLB and **`FusedRootDetail_Tangents.glb`** (preferred import candidate).
- `root-candidate.json` and `root-material-audit.json` copy the manifests, checksums and conditions.

Reproduction uses `recover_fused_tree.py`, `recovered_monument.py`, `fused_root_detail.py`,
`review_fused_root_detail.py` and `validate_fused_root_detail.py`. Run Blender helpers in a separate
factory-startup background process. The detail uses the existing licensed Poly Haven
[bark_platanus](https://polyhaven.com/a/bark_platanus) CC0 source, already credited in `assets/CREDITS.md`.

## Capture and editor state

Computer control still reports the Mac locked after the focus reply. A new owned Play attempt could
not finish normal startup, produced no images and was stopped. The empty Ash attempts remain local
under ignored paths. New camera JSONs for Ash, Crypt, Citadel, Monastery and Pagoda are **capture
candidates**, not accepted views. The recorder helper now owns startup/cleanup and rejects inactive
viewports; it has not recorded video yet.

Blender 5.2.2 crashed when writing an inactive temporary Scene with `bpy.data.libraries.write`.
The crash was reproduced headlessly and traced to Scene/view-layer copying. Collection-only writing
then passed in separate processes. The helpers now require headless mode. The saved General Zhao v2
master remains untouched on disk, but its editor needs reopening after unlock. This is an editor
crash, not a game/source regression. Unrelated General Zhao working-tree changes remain excluded.

No new art upload, public publishing, spending, gameplay-source change or saved-place replacement.
The last full 14-stage verifier still applies to unchanged production. New Python syntax checks,
actual mesh/map readback, Blender baking and GLB round-trip checks passed; no fresh game validation.

## Next concrete actions

1. Unlock the Mac; reopen the existing General Zhao master and restore its editor. Bring the local
   `AsurasPath.rbxlx` viewport forward. The pending unlock request is still required.
2. Import one root-pilot section, verify actual scale/UVs/tangent normal/permissions, then compare the
   same Sanctuary cameras before deciding whether to install the four-section treatment. Judge
   grain, seams and added texture cost; do not multiply it from offline renders alone.
3. Record continuous Bamboo wind and normal-camera traversal into the project video folder. Complete
   the representative 60-second traversal/combat measurement, full route checks and remaining regions.

All earlier incomplete gates remain open: desktop ≤16.7 ms (last qualified run 17.57), physical mobile
Balanced ≤33.3 ms, full traversal/combat/respawn, continuous video, root/canopy composition and broader
world finish. No target has been relaxed.

API references checked: [EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh),
[EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage),
[EncodingService](https://create.roblox.com/docs/reference/engine/classes/EncodingService),
[AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService),
[texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications).

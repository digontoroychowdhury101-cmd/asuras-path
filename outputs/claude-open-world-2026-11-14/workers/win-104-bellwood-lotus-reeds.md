# win-104: Bellwood lotus and lily-pad kit, Reed_Clump_B rebake (Windows)

Art only. Nothing was uploaded, registered, placed or committed; the lead does those steps.

## Reed_Clump_B rebake
- Command: `VEG_ONLY=Reed_Clump_B VEG_CAP=work/win-104/reed VEG_NOTE=work/win-104/reed/progress.md "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --python-exit-code 1 -P tools/blender/overworld/bellwood_veg.py`
- `bellwood_veg.py` change: `VEG_CAP` and `VEG_NOTE` overrides, so a one-piece rebuild leaves the committed captures and the 21a notes alone. The docstring now points to Blender 5.3. Geometry and the `paint()` fix are unchanged.
- Upload GLB: `assets/source/overworld/upload/bellwood_veg/Reed_Clump_B.glb` (346 kB, sha256 `ed8a3142…05db`). The same file is in `assets/source/overworld/bellwood_veg/`. The script also rewrote `upload_manifest.json` in that folder; the other 26 pieces were carried over from the restored copy.
- Sub-meshes: Blades 270 tris (Bell_Reed, 128x256), Heads 608 tris (Bell_Bloom, 256 atlas). These are the veg kit's existing small atlases, not 2048 maps.
- UV check on the exported GLB (`work/win-104/reed/check_reed_glb.py`): the Heads UVs fall on only two atlas points, stem (0.375, 0.375) ×1248 loops and brown (0.125, 0.625) ×576. The candy stripes are gone.
- Previews: `work/win-104/reed/eye_Reed_Clump_B.png`, plus `work/win-104/reed/close_Reed_Clump_B_heads.png`, rendered from the GLB re-imported into Blender.
- Registry: `assets/BELLWOOD_KIT_UPLOADED.json` still holds the old Heads/Blades IDs. Upload the new GLB, then replace both sub entries.

## Lotus kit: `tools/blender/landmarks/bellwood_lotus.py`
- No lotus recipe existed in the tree or on any origin branch (`git grep -i lotus` over all remotes, `git log --all -- '*lotus*'`).
- Everything is procedural. The geometry is built in the script, and two 2048 atlases are painted with numpy. No third-party assets are used, so nothing needs crediting.
  - Pad atlas quadrants: fresh lily-pad top, aged top, maroon underside, lotus leaf.
    - The fresh top has 22 radial veins forking twice toward the rim, a fine net between them, rust freckles and a browned rim.
    - The aged top yellows from the rim, with necrotic patches.
    - The lotus leaf is glaucous blue-green with a pale navel.
  - Bloom atlas quadrants: inner petal, outer petal/sepal, seed-pod disc, and a strip quadrant holding the stem, stamens and spent pod.
    - The inner petal runs from a cream heart to a magenta tip, with longitudinal veins.
    - The outer petal/sepal has a green base, a dusky rose tip and weathered blemishes.
    - The seed-pod disc has 18 sunken seed holes.
- Pads (Nymphaea) float 0.02–0.05 above the water.
  - Each pad has a slit that narrows toward the petiole, rounded lobe tips, an upturned rim and a slow ripple.
  - Each pad has a 0.05-stud body with a maroon underside and rim, so its edge catches light.
  - Old pads fray, roll up on one side and some have a V tear. Pads are relaxed apart so no two overlap, which would z-fight.
- Lotus (Nelumbo) parts:
  - Open flowers have a seed pod, 26 stamen cards and petal whorls of 7, 8, 8 and 4 sepals. The petals are boat-shaped and cupped toward the axis.
  - The kit also has a closed bud, a spent brown pod nodding with one withered petal, emergent cupped leaves on stalks, and loose petals drifting on the water.
- Every card is real two-sided geometry, with no alpha and no reliance on DoubleSided.
  - The script splits each quad on its 0-2 diagonal, and the back sheet reuses the front's diagonal.
  - Letting the exporter choose diagonals made the two sheets of a cupped petal cross, showing dark squares.
- Units and pivot: units are studs. The pivot is **the water surface** at the cluster centre (glTF y = 0). This differs from the colonnade, whose pivot is the lake bed. Stalks reach 0.68 below the surface.
- Collision: none on either role (cosmetic).

| Piece | Pad tris | Bloom tris | Size studs (x, y, up) |
|---|---|---|---|
| Bellwood_LotusClusterA (hero: flower, bud, emergent leaf) | 7,102 | 6,080 | 11.4 × 11.7 × 4.1 |
| Bellwood_LotusClusterB (wider, older: 2 flowers, spent pod, 2 leaves) | 9,452 | 9,400 | 15.1 × 12.6 × 5.0 |
| Bellwood_LilyPadsDrift (12 pads, 3 drifting petals) | 9,502 | 432 | 14.6 × 9.6 × 0.4 |
| Bellwood_LotusBloom (one flower, two pads; causeway accent) | 1,584 | 4,376 | 6.9 × 4.9 × 2.9 |

- Maps: both roles have Color, Normal, Roughness and Metal (black) at 2048. Both materials, `Vesp_Bellwood_Lotus__Pad` and `Vesp_Bellwood_Lotus__Bloom`, are shared by all four pieces, so `maps/` holds one set.
- Outputs: `assets/source/landmarks/bellwood_lotus/` holds `<Piece>.glb` (no images), `maps/`, `manifest.json` (landmark format) and `renders/`.
- Build: `"C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_lotus.py`. The build takes about 15 s and ran under `work/vesperhold-claude/heavy.lock`. Optional env: `LOTUS_PIECES=ClusterA,…`, `LOTUS_NORENDER=1`, `LOTUS_ENGINE=CYCLES`.

## Embed and split
- Pillow is not installed on this PC: not in system Python, `work/.venv`, or Blender's Python. Installing it was not attempted, because that is a download.
  - `work/win-104/pilshim/PIL` is a small Pillow stand-in over Blender's bundled OpenImageIO. It covers open, convert, save PNG/JPEG and fromarray.
  - `work/win-104/embed_split.py` runs `vesp_embed.embed` unchanged, then `tools/assets/glb_split.py`.
- Command: `VESP_NORMAL=jpeg "C:/Program Files/Blender Foundation/Blender 5.3/5.3/python/bin/python.exe" work/win-104/embed_split.py`
  - With PNG normals each embedded GLB was about 23.6 MB and split into two parts. With JPEG q92 4:4:4 normals (vesp_embed's own size option) each fits one part.
- Upload-ready (one part each, `__p1` holds both sub-meshes, `.split.json` beside it):
  - `assets/build/bellwood_lotus/upload/Bellwood_LotusClusterA__p1.glb` 14.2 MB
  - `assets/build/bellwood_lotus/upload/Bellwood_LotusClusterB__p1.glb` 14.4 MB
  - `assets/build/bellwood_lotus/upload/Bellwood_LilyPadsDrift__p1.glb` 14.1 MB
  - `assets/build/bellwood_lotus/upload/Bellwood_LotusBloom__p1.glb` 14.0 MB
- Check: `work/win-104/check_upload_glb.py` re-imported ClusterA__p1. It found six 2048 images, both materials OPAQUE, and no node transforms. The render (`work/win-104/lotus/upload_check_ClusterA.png`) matches the source preview.
- For the lead: `upload_batch.py <ledger> landmark=assets/build/bellwood_lotus/upload`. Then add `bellwood_lotus` to the `landmark` packs in `kit_registry.py` and to the `test_kit_registry` fixture.

## Previews
- `assets/source/landmarks/bellwood_lotus/renders/`: `<Piece>_q34.png` and `<Piece>_eye.png` for each piece, `_close.png` for the three pieces with flowers, and `Bellwood_Lotus_vignette_eye.png` (all four pieces from a standing eye at 5 studs).
- Renders use EEVEE with the Standard view transform, a dark preview water plane and a 5.5-stud block figure.

## Not verified
- Nothing was seen in Roblox Studio: not the import, the SurfaceAppearance result, the look at Bellwood fog distance, or the scale beside the colonnade (placed at Scale 2.5).
  - At Scale 1 a pad is 2–4.4 studs across, and a flower is about 2.4 studs across and 1–1.9 studs above the water.
  - The concept reads at about Scale 1.5–2 from the exit.
- The OpenImageIO JPEG/PNG encoders replace Pillow's. Bytes differ from a Mac embed; the format and channel layout are the same.
- No LODs and no wind data.
- Floating red maple leaves from the concept are not in this kit.

## Lead integration (Windows, 27 Nov 2026)
- The maps were re-embedded with real Pillow 13.0 (`work/.venv`) before upload, replacing the OpenImageIO stand-in. `VESP_NORMAL=jpeg` gives one part per piece, about 14 MB each.
- **Uploads (all Approved):**
  - Bellwood_LotusBloom: 73375860819538 (the pilot)
  - Bellwood_LilyPadsDrift: 82060593706812
  - Bellwood_LotusClusterA: 105734158129529
  - Bellwood_LotusClusterB: 114998259350855
  - Reed_Clump_B: 128825562497257, replacing 120166223011291
  - The ledgers are `uploads/win_lotus_landmark_ledger.json` and `uploads/win_reed_b_ledger.json`. The reed retone was a no-op, so the source GLB was uploaded as it is.
- **Registry:** the lotus readback was merged into `LANDMARK_KIT_UPLOADED.json` (additions only). The forest readback updated only Reed_Clump_B in `BELLWOOD_KIT_UPLOADED.json`. `kit_registry.py landmark` and `kit_registry.py bellwood_veg` were regenerated.
- **Placement:** 9 floating pieces (`Float` 0.15) and Reed_Clump_B are in `Basin.Shallows`. Model names and R values were measured from the manifest at Scale 1. In Play, the water raycast read 150.50 at every Shallows spot, which matches the computed level.
- **Tests:** `test_kit_registry` 19 OK, `test_vesperhold_loader` 233/233, `test_landmark_layout` 80/80. `verify_all` passed all 14 stages; digest 295/3939010/418865786, and Studio Edit matched it.
- **Play:** single client. AsuraCavern was set at about 320–400 s, against about 200 s on the Mac. All 17 Shallows pieces placed with no warnings. The client held 669 landmark MeshParts, including the crown and tree, at the exit view.
  - Capture: `captures/win/bellwood_lotus/win104_exit_reveal_lotus.jpg`. The lotus and lilies float on both sides of the walk, the reed heads are solid brown, and the temple tiers and tree are present.
  - Saved to Roblox Development as version 69. Not published.
- **Reconstructed manifest:** `assets/source/landmarks/bellwood_colonnade/manifest.json` (ignored) was rebuilt from the registry keys and the mac-103 tri table for registry use only. The Mac original was not recovered.

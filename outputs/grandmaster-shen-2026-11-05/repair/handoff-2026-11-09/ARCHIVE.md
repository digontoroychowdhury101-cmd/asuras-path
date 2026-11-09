# Files Git does not carry: the separate archive

## What comes from where

| Comes from Git (pull `ux/onboarding-overhaul`) | Comes only from the archive `shen-untracked-2026-11-09.zip` |
|---|---|
| All code. Bake and repair: `tools/animation/opening_cast/` (shen_lib, shen_clips, cloth_bake, export). Import, skinning, cloth and review: `tools/blender/shen_import/` | `assets/source/bosses/grandmaster_shen/`: the original uploaded PBR GLBs for both phases, their concept PNGs, and `GrandmasterShen_Master.blend` (213 MB, saved 2026-11-06 02:53) |
| The exported clips now in the game: `assets/animations/opening_cast/shen/*.rbxmx` plus `manifest.json`. These are from before this repair pass | `assets/build/grandmaster_shen/Shen_P{1,2}_{Game,Props}.glb`: the prepared game and props meshes (2026-11-06 02:47) |
| The Shen models `assets/models/AsuraBoss_GrandmasterShen_P{1,2}.rbxmx`, the game source (`src/shared/ClothSim.luau`, `ShenClothData.luau`) and the place files | `work/shen_import/` (35 data files plus measure/pose/sheets/shots/source_views): the rig (`rig_p*.glb`), labels, shells, textures and survey; the later repair data: `skin_p*.npz`, `surface_p*.npz`, `sdf_p*.npz`, `sdf_p*_Weapon.npz`, `wcloud_p*.npz`, `haft_p*.json`, `clothskin_p*.json`, `clothskin_reach_p*.json` |
| Already force-tracked inputs: `work/shen_import/cloth_p{1,2}.json` and `samples_p{1,2}.npz`, and `work/opening_cast_bake/shen{1,2}/pieces.json` | `work/opening_cast_bake/shen/*.json`: the 64 frame files of the current export (Idle is read by the review-shot tools) |
| This handoff folder: the scripts, logs, saved bakes (`bakes/`), results, `HANDOFF.md`, `ARCHIVE_MANIFEST.sha256` and `ENVIRONMENT.txt` | |

- **Left out on purpose:**
  - `GrandmasterShen_Master.blend1`: Blender's backup of the previous save.
  - `work/shen_import/preview/` (277 MB): review renders that no pipeline step reads.
  - `work/opening_cast_bake/shen_shots/` (1.2 GB of cloth review shots): `cloth_bake.py` rebuilds them from frame JSON (the "before" set from `bakes/pre4_export`).
- **Contents:** 167 files, 689.0 MB uncompressed, at their project-relative paths. Each file's SHA-256 is in `ARCHIVE_MANIFEST.sha256`, in this folder and inside the zip.
- **Zip:** SHA-256 `7d7a045ce8c5bbf75b41f9b179e02ec8853693af8bf86dc2a6616b5c531355c2`, 525.6 MB.

## The original sculpt and Master.blend do not hold the later repairs

`Master.blend` and the uploaded PBR GLBs predate this work: they are from 2026-11-05/06. Every later repair lives elsewhere:

- **Motion, grips and clipping repairs:** in the code. The exported clips in Git are pre-repair; the repaired motion is in `bakes/` and comes back out of the code.
- **Skinning and arm/torso measures:** the skin and surface samples and the distance fields (`skin_p*`, `surface_p*`, `sdf_p*`). `skin_rig.py`, `skin_points.py` and `body_sdf.py` made them on 2026-11-07, from `rig_p*.glb`.
- **Weapon surface:** `wcloud_p*` and `haft_p*`, made by `weapon_cloud.py` and `haft_axis.py`.
- **Cloth fixes:** butt cap, robe knee, beard and the free cloth live in `ClothSim.luau`, `ShenClothData.luau` and `cloth_p*.json` (all in Git), plus `clothskin_p*` and `clothskin_reach_p*` (2026-11-07/09; `cloth_skin.py`, `cloth_skin_reach.py`).

So restore these derived files from the archive, not by re-running the import from `Master.blend` or the sculpt. Re-running it would rebuild 2026-11-05/06 data without the later steps.

## Where the archive is and how to move it

**Transfer: Git, on its own branch `shen-assets-2026-11-09`** (no USB needed). GitHub refuses files over 100 MB, so the zip is pushed as six
parts (`shen-untracked-2026-11-09.zip.part000`-`part005`). The branch also holds the zip's `.sha256`, `ARCHIVE_MANIFEST.sha256` and a
README. It has no history shared with `ux/onboarding-overhaul` and is never merged into it. The repo is public, so these files are public
too (the owner chose that on 2026-11-09).

**Also on Computer A:** `/Users/digonto/Documents/ShenHandoff-2026-11-09/` holds the whole zip, its `.sha256`, the manifest,
`ENVIRONMENT.txt` and this guide.

The restore and check scripts come with the code branch, in this handoff folder's `scripts/`. Run them from the repo root.

## Restore on the other computer (nothing is overwritten automatically)

Windows PowerShell commands are in `WINDOWS_START.md`. On a Mac use `python3` in place of `py`, with the same arguments.

1. Pull the code: `git pull --rebase origin ux/onboarding-overhaul`. Then fetch the assets (about 526 MB): `git fetch origin shen-assets-2026-11-09`.
   Do not check that branch out.
2. Dry run, from the repo root: `py outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/scripts/restore_untracked.py --from-branch origin/shen-assets-2026-11-09`.
   - It reads the six parts straight from Git, joins them into `work/shen_repair/shen-untracked-2026-11-09.zip` and checks its SHA-256
     (`7d7a045c…355c2`).
   - It checks every entry against the manifest. It also stops if the zip's manifest differs from the one in Git.
   - It lists each file as `add` (missing), `same` (identical) or `DIFFERENT` (a file already there differs).
   - A zip copied by hand works too: pass its path in place of `--from-branch …`.
3. Apply: re-run with `--apply`. Only the missing files are written.
   - `DIFFERENT` files are left alone. Look at them first; they may be newer work from that computer.
   - Replace them only if you are sure, by adding `--replace-different`. That keeps each old file as `<name>.before-handoff-2026-11-09`.
4. Install the Python packages: `py -m pip install numpy==2.5.3 scipy==1.18.1`. Computer A used these; see `ENVIRONMENT.txt`.

## Reproduce one known clip before changing anything

From the repo root:

```
py outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/scripts/repro_check.py
```

This does three things:

1. It hashes the 98 bake inputs (`work/shen_import`, the prepared GLBs) against the manifest.
2. It rebakes P1_GuardHit with the repo code and compares every part's transform, frame by frame, with Computer A's saved bake (`bakes/dp11/P1_GuardHit.pkl`).
3. It runs the validator.

On Computer A it printed `REPRODUCED`: largest difference 0.00e+00, validator clean. On Windows, `REPRODUCED WITHIN ROUNDING`
(1e-3 or less, from a different maths library) is also a pass.

Then run `repro_check.py P1_Guandao_L1`, a full attack clip with contacts, as a second check.

If either says `NOT REPRODUCED`, change nothing until the cause is found. Compare the input list it prints, then the Python, numpy and SciPy versions. A different numpy or BLAS can move results by tiny amounts; a missing or different input file is a real mismatch.

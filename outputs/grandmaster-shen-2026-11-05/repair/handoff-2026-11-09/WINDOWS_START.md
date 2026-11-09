# Starting the Shen repair on the Windows computer

Run these in **PowerShell, in the repo folder** (the one where you ran `git pull`). Every command uses repo-relative paths, so the
Windows user name (`dishan`) does not matter.

## 1. Get the latest code and the asset branch

```powershell
git pull --rebase origin ux/onboarding-overhaul
Test-Path outputs\grandmaster-shen-2026-11-05\repair\handoff-2026-11-09\WINDOWS_START.md
git fetch origin shen-assets-2026-11-09:refs/remotes/origin/shen-assets-2026-11-09
```

- `Test-Path` must print `True`; if it prints `False`, the pull did not bring the latest commit.
- The fetch downloads about 526 MB.
- Do **not** check out `shen-assets-2026-11-09`; the restore script reads it straight from Git.

## 2. Python with numpy and SciPy

```powershell
py --version
```

If that fails, install Python 3.14 (64-bit) from python.org and tick "Add python.exe to PATH". Then:

```powershell
py -m pip install numpy==2.5.3 scipy==1.18.1
py -c "import numpy, scipy; print(numpy.__version__, scipy.__version__)"
```

If pip has no build of those exact versions for your Python, run `py -m pip install numpy scipy` and note the versions printed.
If `py` is not found but `python --version` works, use `python` wherever these steps say `py`.

## 3. Restore the files Git does not carry (nothing is overwritten)

Dry run first:

```powershell
py outputs\grandmaster-shen-2026-11-05\repair\handoff-2026-11-09\scripts\restore_untracked.py --from-branch origin/shen-assets-2026-11-09
```

- It joins the 6 parts into `work\shen_repair\shen-untracked-2026-11-09.zip`.
- It checks the zip SHA-256 (`7d7a045c…355c2`), then every file against the manifest committed in Git.
- It then lists each file:
  - `add`: missing here;
  - `same`: identical;
  - `DIFFERENT`: a file already exists and differs.

Write only the missing files:

```powershell
py outputs\grandmaster-shen-2026-11-05\repair\handoff-2026-11-09\scripts\restore_untracked.py --from-branch origin/shen-assets-2026-11-09 --apply
```

If any file is `DIFFERENT`, it is left alone. It may be newer work from this computer, so look at it before deciding. Only if you are
sure, re-run with `--replace-different` as well; that keeps each old file as `<name>.before-handoff-2026-11-09`.

## 4. Prove this computer reproduces Computer A before changing anything

```powershell
py outputs\grandmaster-shen-2026-11-05\repair\handoff-2026-11-09\scripts\repro_check.py
py outputs\grandmaster-shen-2026-11-05\repair\handoff-2026-11-09\scripts\repro_check.py P1_Guandao_L1
```

Each takes about 30 s. Both must end in one of these:

- `REPRODUCED`: identical.
- `REPRODUCED WITHIN ROUNDING`: Windows numpy rounds the last digits differently, and the difference is 1e-3 or less.

`NOT REPRODUCED` means stop: something differs (an input file or the package versions). Fix that before any repair work.

## 5. Put Computer A's saved bakes where the tools look for them

```powershell
$h = "outputs\grandmaster-shen-2026-11-05\repair\handoff-2026-11-09\bakes"
New-Item -ItemType Directory -Force work\shen_repair | Out-Null
foreach ($d in "dp11","dp15","dp16") { if (-not (Test-Path "work\shen_repair\baked_$d")) { Copy-Item -Recurse "$h\$d" "work\shen_repair\baked_$d" } }
if (-not (Test-Path "work\shen_repair\pre4_export")) { Copy-Item -Recurse "$h\pre4_export" "work\shen_repair\pre4_export" }
```

This copies into `work\shen_repair` (gitignored) and skips any folder that already exists.

## 6. Start Claude Code in the repo folder and paste this prompt

---

Continue the Grandmaster Shen (boss 01) clipping repair exactly where Computer A (the Mac) stopped on 2026-11-09.

This is the Windows computer. The repo is on branch `ux/onboarding-overhaul`. The untracked assets have been restored from branch `shen-assets-2026-11-09`, and
Computer A's saved bakes have been copied to `work/shen_repair/baked_dp11`, `baked_dp15`, `baked_dp16` and `pre4_export` (WINDOWS_START.md steps 1-5).

**Read first:**

- `AGENTS.md` and `.agents/skills/ro-engineer/SKILL.md`, then `CLAUDE.md`.
- The top of `PROJECT_STATE.md`.
- `outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/HANDOFF.md`, `ARCHIVE.md` and `ENVIRONMENT.txt`.

**Gate:** run `scripts/repro_check.py` and `scripts/repro_check.py P1_Guandao_L1` from that handoff folder. Both must print
REPRODUCED, or REPRODUCED WITHIN ROUNDING. If not, stop and report why before changing anything.

**Fixed rules (do not change them):**

- Keep the current approach, the grip style, the validator thresholds and the dense measure, which counts every arm skin sample.
  The arm-in-torso wall is 0.17; the validator flags anything over 0.18.
- Keep the between-frame and fade-in checks and the pop limits (`POP_LIMIT`).
- Do not loosen a test. Do not exclude visibly failing geometry. Do not declare a defect an accepted limitation.
- Do not change GLB bones or skin weights; cloth tuning only through `skin_rig --cloth-only` or the cloth JSON.
- Preserve gameplay timing, rig interfaces, the exporter, the cloth system and unrelated work.
- Do not publish, and never invent asset IDs. Bosses 02-06 wait.
- Never open `.rbxl`, `.rbxlx`, `.glb` or `.obj` files, or images, with text tools; viewing rendered review PNGs is fine.
- Never rebuild the `work/shen_import` data from Master.blend or the original sculpt. They predate the later repairs; the restored files are the current ones.
- Passing numbers are not proof. Watch before/after renders of every repaired clip.
- Cloth must deform, not hinge.

**Windows notes:**

- Use `py`, not `python3`. The SciPy you installed is required: without it the joint polish stage skips itself.
- For several clips in parallel, use `scripts/runall.py TAG CLIP ...`; it writes bakes and logs under `work/shen_repair`.
  The `.sh` scripts (zsh) do not run here, so port to Python any you need (`render_cmp.sh`, `render_pass4.sh`, `measure_set2.sh`).
- Set the `BLENDER` environment variable to `blender.exe` for the renders.
- Keep each bake process single-threaded; runall sets that up.

**Current state (local bakes, nothing exported):**

- 49 clips are clean as baked in `bakes/dp11`.
- 12 rebaked clips now pass, in `bakes/dp15`. Take P1_Guandao_Running from dp15, not dp16.
- Still failing or unconfirmed:
  - P2_Death: right arm 0.23 in his chest at f21-26 and f34-36.
  - P2_RendingArc: needs a rebake on the current code.
  - P1_PrayerBeads: passes, but needs a rebake on the current code.
  - P1_FlowingJian: blade pop 0.58 at f43, left wrist 173° at f84-85, arms 0.21-0.23 over f32-65.
  - About a dozen Idle fade boundaries at 0.184-0.189.

**Work in this order**, following HANDOFF.md steps 2-8 (steps 0-1 are done):

1. Rebake RendingArc and PrayerBeads (`runall.py dp18 P2_RendingArc P1_PrayerBeads`), then run `revalidate.py`.
2. Fix Death. Option A: make `clear_torso` find and score its frames with the dense measure the validator uses.
   Option B: adjust the Death keys (the 0.75 s stagger and the 1.15 s knee). The uncorrupt timing was already tried and made it worse.
3. Fix FlowingJian:
   - **Blade pop at f43:** ease a blow frame's haft tilt over its neighbours. Rending Arc f59-60 must keep its tilt; the earlier guard
     that dropped it was removed for that reason (probe data in `logs/wyprobe_*.log`).
   - **Left wrist at f84-85:** the flip comes from the third swivel. The diagnosis is in `logs/swprobe_fj.log` and `logs/lwtrace_fj.log`.
   - **Arms over f32-65:** split that 33-frame polish window, or re-measure after the other two fixes.
4. Fix the Idle fade boundaries past 0.18 (`fadecheck2.py`).
5. Assemble the final set (dp11, dp15 and the new bakes), then run `revalidate.py` on all 64 and `fadecheck2.py`.
6. Export with `export_baked.py`. Check pops and face pops against `bakes/pre4_export` (`popjson.py`, `facepop.py`).
7. Measure the cloth before and after.
8. Render x-ray before/after videos of every repaired clip into `outputs/grandmaster-shen-2026-11-05/repair/` and watch them.
9. In Studio, play the clips back locally (KeyframeSequence) with screen captures, no publishing. Two-client tests are allowed on this computer.

**Each turn**, per CLAUDE.md:

- Run `py tools/build.py` when code or assets change.
- Add a note of 60 words or fewer to the top of `PROJECT_STATE.md`.
- Commit (ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`) and push to `ux/onboarding-overhaul`, or run `tools\handoff.cmd`.
- Confirm `git status` is clean.

**Before finishing:**

- Run `bash tools/verify_all.sh` (Git Bash) and `py tools/test_cloth_sim.py`.
- Report static review, local regression, Studio integration, multiplayer and device profiling separately.
- Never invent results.
- Give a concise update each time a repair is visibly verified or a concrete blocker is found. Keep implementing; don't end with a plan.

---

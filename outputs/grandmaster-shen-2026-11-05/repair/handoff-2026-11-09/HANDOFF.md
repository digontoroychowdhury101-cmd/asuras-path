# Grandmaster Shen clipping repair: handoff (2026-11-09, Computer A → other computer)

Branch `ux/onboarding-overhaul`. Nothing has been published and no new export was made. Everything below is in this folder or in the repo code.

## Paste this as the prompt on the other computer

> Continue the Grandmaster Shen (boss 01) clipping repair exactly where Computer A stopped on 2026-11-09. Read
> `outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/HANDOFF.md` first, then follow AGENTS.md and
> `.agents/skills/ro-engineer/SKILL.md`. Do not restart the approach. Keep the grip style, the validator thresholds, and the
> dense (every-skin-sample) torso measure exactly as they are. Do not change GLB bones or skin weights. Do not publish. Bosses 02-06 wait.
>
> Work in this order:
> 0. Restore the files Git does not carry, following `handoff-2026-11-09/ARCHIVE.md`. That means the archive
>    `shen-untracked-2026-11-09.zip`, holding the source and Master assets, the prepared Game/Props GLBs, `work/shen_import` and the frame JSON.
>    Use `scripts/restore_untracked.py`: a dry run first, it never overwrites. Then run `scripts/repro_check.py`.
>    Both P1_GuardHit and P1_Guandao_L1 must print REPRODUCED before anything is changed.
>    Do not rebuild those inputs from Master.blend or the uploaded sculpt: neither holds the later repairs (see ARCHIVE.md).
> 1. Install SciPy for the Python you bake with (`python -m pip install scipy numpy`); joint_polish skips itself without it.
>    Copy `handoff-2026-11-09/bakes/*` into `work/shen_repair/` (gitignored) as `baked_dp11`, `baked_dp15`, `baked_dp16`, `pre4_export`.
> 2. Rebake P2_RendingArc and P1_PrayerBeads with the current repo code
>    (`zsh scripts/runall10.sh dp18 <listfile>` or `python scripts/torsotest_patch.py on <clip>` with `SHEN_SAVE_BAKED`), then run
>    `scripts/revalidate.py` on them. RendingArc's earlier dp15 bake used a guard that has since been removed, so it is not valid.
>    PrayerBeads' dp15 bake passes (0.175), but under the current code its seeded retry also runs, so it must be rebaked.
> 3. Fix P2_Death. Its right arm is 0.23 in his chest in two places. The first is the stagger, f21-26: the back of the
>    upper arm. The second is the kneel, f34-36: the front armpit fold, a skin sample the thinned measure skipped.
>    joint_polish (window 17-39) can't solve either one. The plain run worsens clash, reach and grip rows. The seeded run gets
>    0.237 and worsens clash and grip. In the de1 test of the f36 window, the seeded run reached 0.166 but was rejected for a
>    slightly worse clash.
>    At f36 the right arm is at full stretch, so only a 0.1-0.2 fist move toward his front or right clears it (probe `scripts/line36.py`).
>    Next: make `clear_torso` (shen_lib) find and score its frames with `arm_torso(..., dense)` (the validator's measure), or change the
>    Death keys (`shen_clips.py death()`: the 0.75 s stagger and the 1.15 s `knee` pose, rp/relb).
>    The uncorrupt timing was already tried (`uncorrupt=(0.24, 0.9)`, the de1 test): it made it worse (0.254). Don't repeat it.
> 4. Fix P1_FlowingJian, the worst clip. It has three faults:
>    (a) A blade pop of 0.58 at f43, the second blow (contacts at 0.8, 1.45, 2.1 and 2.75 s). wrist_yield tilts the haft 30 deg on
>        f43 while its neighbours get about 6 deg, and depop never smooths a contact frame.
>        A guard that dropped blow-frame tilts made RendingArc worse: its f59 and f60 both need the tilt. It was removed.
>        The probe data is in `logs/wyprobe_*.log`. A fix must leave RendingArc's f59-60 alone. Candidate: at a blow frame, ease the
>        tilt over the neighbouring frames as an envelope (gaussian, full height at the blow) instead of the averaged spread.
>    (b) The left wrist turns 173 deg at f84-85. The third `swivel` call creates it: the left elbow pole swings about 90 deg per frame
>        over f83-87, and _lroll jumps -83 → 0 → 0 → -7 → 70 (`logs/lwtrace_fj.log`).
>        Run `scripts/swprobe.py P1_FlowingJian 3 80 88` to see which cost makes the continuous path dearer than the walls it pays.
>    (c) Both arms sit in his torso over f32-65, at 0.21 on frames and 0.23 between them. The polish window 32-65 has 33 frames;
>        the plain run gets "Inequality constraints incompatible", and the elbows-only run is stuck.
>        Split the window, or fix (a) and (b) first and re-measure.
> 5. Fix the Idle fade boundaries still past 0.18 (`results/fade_dp11.txt`, `scripts/fadecheck2.py`, game 0.15 s joint fade).
>    Game in: P2_HitLightFront 0.189, P2_TurnRight 0.187, P2_HitLightLeft 0.185.
>    Game out: P2_CrimsonEmbrace, P2_PhantomDrift and P2_WalkBackward 0.186; P2_GuandaoSkyfall and P2_TurnRight 0.185;
>    P2_BloodWave, P2_Feint and P2_RendingArc 0.184; P1_Guandao_L3 0.180.
>    Recheck these on the final set first: some clips were rebaked since.
> 6. Assemble the final bake set:
>    - dp11 for the 49 clips that never pass 0.17;
>    - dp15 for P2_PostureBreak, P2_Feint, P2_HitLightRight, P2_CrimsonEmbrace, P2_Guandao_Heavy, P2_Guandao_L3,
>      P2_Guandao_Running, P2_Strike, P2_GuandaoSkyfall, P2_DeathblowVictim and P1_Guandao_Running
>      (the dp15 one, not dp16, which has a 0.27 fist pop);
>    - the new bakes for RendingArc, PrayerBeads, Death and FlowingJian.
>    Then run `revalidate.py` on all 64 and `fadecheck2.py`.
> 7. Export: `python scripts/export_baked.py <finaldir> <all 64>`. Then check pops against `pre4_export` (`popjson.py`, `facepop.py`) and
>    measure the cloth before and after (`measure_set2.sh` with `BDIR`, then `msetcmp.py`).
>    Make x-ray before/after videos of every repaired clip (`render_cmp.sh` / `render_pass4.sh`) into `outputs/grandmaster-shen-2026-11-05/repair/`
>    and watch them. A passing number is not proof.
> 8. Studio: local KeyframeSequence playback in the ShenQA place, with screen captures. Report static review, local regression,
>    Studio integration, multiplayer and device profiling separately. Run `bash tools/verify_all.sh` and `python3 tools/test_cloth_sim.py`.
>    Then build, add the PROJECT_STATE note, commit and push.

## What is in the repo code now (tools/animation/opening_cast/shen_lib.py)

- **joint_polish (SciPy SLSQP)** is the bake's last stage, after close_loop.
  - It solves each run of frames still past the wall (0.17 on frames, halfway between frames, and the 0.15 s fade in) together.
  - Controls per frame (8): fist point 3, haft tilt 2, right and left elbow swing 2, free-arm roll 1.
  - Constraints per frame (9): dense torso depth for each arm, clash, reach, grip and lead reach, both wrists, and the weapon floor.
  - Objective: least change plus its second difference.
- **Retries**, in this order:
  1. the plain run;
  2. elbows only, if the plain run isn't kept;
  3. **a seeded start (new today)**, if no run reached feasibility. It begins from clear_torso's least fist move per frame.
- **In-order acceptance check (new today).**
  - A kept window is re-solved the way the export solves it: in order, with haft-side memory (`_solved`).
  - It is dropped if the arms aren't shallower there, or if any pop goes past its limit (`POP_LIMIT`).
  - Why: on phase-1 Running a 0.017 fist change flipped f3's haft side in the final solve, giving a 0.27 fist pop.
- **Validator:**
  - it uses every arm skin sample;
  - it checks poses between frames (`joint_mix`, the Animator's joint blend) and the fade in.
- **wrist_yield** is back to the committed behaviour; the blow guard was tried and removed.
- `cloth_bake.py` review shots fade joint by joint (`fade_pose`).

## Results so far (local only, no export, no Studio check of this pass)

| Clip | Before (dp11) | Now | Bake |
|---|---|---|---|
| P2_CrimsonEmbrace | 0.351 arm in chest | 0.136, passes | dp15 |
| P2_DeathblowVictim | 0.205, fade in 0.257 | 0.16, passes | dp15 |
| P2_PostureBreak, P2_Feint | 0.18-0.19 entry/between | 0.16, passes | dp15 |
| P1_Guandao_Running | 0.214 fade in | 0.179, passes (marginal) | dp15 |
| P1_PrayerBeads | 0.184 between | 0.175, passes | dp15 (needs a rebake, step 2) |
| P2_Guandao_Heavy/L3/Running, Strike, Skyfall, HitLightRight | 0.17-0.19 | 0.16, passes | dp15 |
| P2_Death | 0.231 | 0.231, **fails** | dp16 (polish not kept) |
| P2_RendingArc | 0.189 between f61-62 | **not rebaked on final code** | — |
| P1_FlowingJian | pop 0.58, wrist 173, arms 0.20-0.23 | **fails** | — |

- **Mesh check:** the prototype got Crimson Embrace f47-48 from 0.358 to 0.148 on the rendered mesh, and Deathblow Victim from 0.204 to 0.160.
- **Videos:** `repair/polish_c2_*_uppertorso.mp4`, `repair/slsqp_c2_*`.
- **In-order check of today's code on the dp15 bakes** (`results/confirm_dp15.txt`): every kept window's final bake equals its plan, and no pop is past its limit.

## Folder contents

- `scripts/`: every scratch tool from this pass.
  - Paths are portable: `SHEN_ROOT` (default: five folders up), `SHEN_SCRATCH` (default `work/shen_repair`), `BLENDER`.
  - Key scripts:
    - `torsotest_patch.py on CLIP`: bake and validate one clip; with `SHEN_SAVE_BAKED=dir` it saves the bake.
    - `runall10.sh TAG LIST`: 7 clips in parallel.
    - `revalidate.py`, `fadecheck2.py`, `confirmcheck.py`.
    - `polishtest.py CLIP PKL`: joint_polish alone on a saved bake.
    - `polishdbg2.py`: the rows a window is stuck on.
    - `seedtest.py`.
    - `deepest.py` / `deathprobe.py`: which skin sample is deepest.
    - `lwtrace.py`, `swprobe.py`, `wyprobe.py`: stage traces.
    - `export_baked.py`, `render_cmp.sh`, `measure_set2.sh`, `msetcmp.py`, `popjson.py`, `facepop.py`.
  - Exceptions: `cloth_sweep.sh` and `tune.sh` still hold Mac paths, and `guard_search.py` was already broken.
- `bakes/`: the saved bakes (pickles: `[t, local, world, diag, ctrl]` per frame; load with numpy 2.x).
  - `dp11`: all 64 clips, before today's polish fixes.
  - `dp15`: 13 rebakes.
  - `dp16`: Death, Running.
  - `pre4_export`: the export this pass started from, the "before" baseline.
- `logs/`: bake logs.
  - `ttdp11_*`, `ttdp15_*`, `ttdp16_*`: per-clip stage pops, polish window reports and problems.
  - `ttde1_P2_Death.log`: the uncorrupt test.
  - `seedtest_death.log`, `lwtrace_fj.log`, `wyprobe_*.log`, `polishtest_pb.log`.
- `results/`: revalidation tables (`reval3_dp11.txt`), fade tables (`fade_dp11.txt`), SLSQP prototype JSON, and the draft report
  `report8_pass4.md` (its AFTER_* placeholders are still unfilled).

## Machine notes

- A bake takes 2-40 min per clip; the polish dominates on failing clips (Death's plain window took 20-30 min).
- Use `VECLIB_MAXIMUM_THREADS=1 OMP_NUM_THREADS=1` and at most about 7 parallel bakes on a 10-core/16 GB machine.
- Never run two-client tests on Computer A.

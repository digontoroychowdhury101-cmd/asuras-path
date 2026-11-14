# Next boss integration: fast-path prompt

Written 2026-11-09 from the Grandmaster Shen post-mortem. Revised 2026-11-14 after Shen's final verification on the Windows computer: the fade
facts were wrong, and the last days went into problems this prompt did not prevent (measures that disagreed, three-decimal passes, phantom
fade failures, cloth contacts no one could see, a place file with stray Studio edits, a clean clone that could not build).

**Before pasting:** set the boss on the line below. For a different boss, change only that line.

`BOSS: 02 Venerable Baize (look key VenerableBaize, brief 02-venerable-baize.md)`

Paste everything under the line into Claude Code, started in the repo folder.

---

You are integrating **BOSS** (the line above) into Asura's Path (Roblox/Luau), end to end. That covers:

- model preparation, rig and skin;
- secondary motion (cloth, hair, mane, tail);
- every animation clip, with clipping and penetration solved;
- VFX, SFX and music;
- game integration, asset upload and Studio proof.

**What to build** is in the boss's numbered brief in the prompt pack: the brief itself, `CONCEPT-ART.md`, `references/` and `asset-audit.json`.
Day 0 restores the pack to `work/boss_inputs/prompt-pack/`. **How to build it** is in this prompt, so that it takes days, not weeks:

- On look, moves and gameplay, the brief wins.
- On process, order and tooling, this prompt wins.

## Why this prompt exists

Grandmaster Shen (boss 01) took over a week. All 64 clips were published and Studio-tested on 2026-11-13, and one clip was still past the
x-ray limit by 0.00014 on 2026-11-14.

- **The first day went well.** Import, rig, cloth, 64 clips, asset upload and a single-client Studio fight were done in about 20 hours.
- **The rest went into arm, weapon, torso and cloth clipping, and into proving it was gone.**

What cost the time, and what you will do instead:

1. **Greedy repair stages that fought each other.**
   - Motion was authored as key poses with no body-collision measure. About fifteen sequential repair stages then tried to clean it up
     (settle, swivel, wrist_yield, clear_torso, slide_fist, tilt_haft, depop, seam nudge/polish/swing…).
   - Each stage undid another. Stage traces proved it: Crimson Embrace went 0.07 after swivel, 0.27 after clear_torso, 0.34 after slide_fist.
   - A single constrained optimiser (SciPy SLSQP) over a window fixed in one pass what hours of stage tuning could not (0.351 → 0.136).
     It arrived last.
   - **Instead:** the optimiser is the main solver from day one.
2. **The clipping measure changed four times, and two measures disagreed.**
   - It went from capsule proxies, to a 250-point weapon cloud, to a dense cloud, to thinned skin samples, to every skin sample.
   - The validator left out skin that sits near the chest in the bind pose; the review x-ray counted it. Seven clips passed one and failed
     the other, and a day went into tracing "the shoulder seam".
   - **Instead:** build the final, dense, real-mesh measure before the first clip, with its exclusion rules written once, and freeze it.
3. **Clip boundaries were checked late, and checked with the wrong fades.**
   - The review renders faded every clip in from Idle over 0.2 s. The game does something else (see M3), so the two worst "failures"
     (the glaive in his chest, 0.342 and 0.293) were the review's own fade, while the game's real transitions went unchecked.
   - **Instead:** read the fades and transitions from the game code into the measure from the start.
4. **Keys were authored without the body's real proportions.**
   - Phase 2's broader torso, shorter arms and hover put keyed fists inside the chest. No solver rescues an infeasible key; rewriting
     the key did.
   - **Instead:** measure each phase's body first, author keys relative to it, and lint keys before baking.
5. **Wasted compute.**
   - About ten full 64-clip bake or export runs, 1-3 h each, several while code was still changing. One run mixed two code versions.
   - Dozens of variants per problem (hv1-14, ra1-13, bd1-11). Runs overwrote each other's outputs.
   - The review x-ray ran in Blender: 35 minutes for 64 clips on 4 processes. A numpy port gave the same numbers in seconds.
   - All 64 clips were re-published because every file had changed.
   - **Instead:** iterate on a small worst-offenders set, measure in numpy, cache and publish only what changed, freeze code per run,
     and cap the variants.
6. **Passes were reported at three decimals.** P2 Guandao_L3 printed "0.180" against a limit of "past 0.18" and was read as a pass. It
   was 0.18014.
   - **Instead:** one gate, full precision, one PASS/FAIL table over everything.
7. **Validator passes were reported as quality.** The creator rejected the motion twice: not organic, rigid cloak, gait, knees, grip.
   - **Instead:** rendered motion is the judge. Get the creator's verdict on a pilot of 8 clips, not on 64.
8. **Contacts no one can see stayed "open" for days.** The deepest cloth contacts at the end were a sleeve inside the arm it covers and the
   beard's root inside the chin, about 0.19 deep, invisible from any camera.
   - **Instead:** agree with the creator, once, which contacts count (M3), and measure that.
9. **Shell and Studio friction cost hours.** zsh word splitting, no `timeout` on macOS, the 600 s tool limit, buffered output, relative
   paths after `chdir`, memory thrash, the importer's quirks, the Studio MCP sandbox, a hook that asked for "facts" before every edit.
   - **Instead:** use the facts below, and set up the session on day 0.
10. **The two computers drifted.**
    - Gitignored inputs reached the other computer only through a last-minute 526 MB archive (`work/`, `assets/source/`, `assets/build/`,
      `.blend` files).
    - The canonical place held uncommitted Studio edits with an old ClothSim.
    - A clean clone could not run the checks: Rojo missing, Luau not in `work/bin/luau`, a generated audio manifest absent.
    - **Instead:** push inputs to an asset branch at every milestone, treat the place as build output only, bootstrap tools with one
      script, and prove the result with a fingerprint on each computer.

## Rules that always apply

- **Project rules:** follow `CLAUDE.md`, `AGENTS.md` and `.agents/skills/ro-engineer/SKILL.md`.
- **Commit every turn:**
  - Run `tools/build.py` when code or assets change, and add a PROJECT_STATE note of 60 words or fewer.
  - End the commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, push to `ux/onboarding-overhaul`, then confirm a clean status.
  - Stage explicit paths; never sweep in another task's untracked folders.
  - This overrides any "do not commit" line in the brief.
- **Files you never read:**
  - Never open `.rbxl`, `.rbxlx`, `.glb`, `.obj` or images with text tools. View renders as images.
  - Never touch `Codex`, `Obsidian Vault` or `Cagebound_Archive`.
- **The place file is build output:**
  - Never edit or save `places/*.rbxlx` in Studio. It is always what `tools/build.py` writes.
  - Studio QA uses temporary builds (`tools/build.py --output <temp>`), deleted afterwards.
  - `*.rbxlx` is `-text` in `.gitattributes`, so the file is byte-identical on every computer; its SHA-256 is part of the handoff.
- **Visual quality first:**
  - Never decimate or remesh. Split into MeshParts under 20k triangles (target 18k or fewer).
  - Keep the 2048 maps, the UVs and the normals.
- **Organic motion:**
  - Cloth, hair, manes, plumes and tails deform as skinned surfaces driven by simulation, never rigid plates on one hinge.
  - Bodies move with weight transfer, lead and lag, overlap, and gait patterns taken from real anatomy.
- **Tests stay honest:**
  - Never loosen a test, thin a measure, or exclude failing geometry.
  - Every threshold is compared at full precision, and numbers near a limit are printed to five decimals.
  - Nothing becomes an "accepted limitation" without the creator's word.
- **Uploads:**
  - Never invent asset IDs.
  - Uploading this boss's own meshes, animations and audio through Studio is part of the job, as it was for Shen.
  - Never publish or overwrite the game place.
- **Multi-client tests:** two-client and multi-server tests run only on the Windows computer. On the Mac, stop at single-client evidence.
- **Shen's files belong to Shen's own task (P2 Guandao_L3 is still open there); leave them alone:**
  - Do not edit `tools/animation/opening_cast/shen_lib.py`, `shen_clips.py`, `shen_seam.py`, `tools/blender/shen_import/*` or Shen data.
  - Copy what you need into boss-agnostic modules.
  - After changing any shared file (`castlib.py`, `export.py`, `ClothSim.luau`, `BossCloth.luau`, `BossSkin.luau`, `BossAnimations.luau`):
    Shen's `outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/scripts/repro_check.py` must still print REPRODUCED,
    `tools/test_cloth_sim.py` must pass, and `tools/qa/ShenFingerprint.luau` must still print the lines in
    `outputs/grandmaster-shen-2026-11-05/repair/windows-pass-2026-11-09/HANDOFF_1113.md` step 4 (a changed module changes its last digest:
    say so, and re-record it only for an intended change).
- **Check the skin in play:** start every character test by reading each actor's `AsuraSkinStatus`. A fallback while our model exists is a bug.

## Day 0: setup (one hour, before any asset work)

1. Run `git pull --rebase origin ux/onboarding-overhaul`, then read the top of `PROJECT_STATE.md`.
2. **Get the inputs from Git.** The prompt pack and all nine source GLBs are on the data-only branch `boss-inputs-2026-11-05`.
   - Fetch it: `git fetch origin boss-inputs-2026-11-05:refs/remotes/origin/boss-inputs-2026-11-05`.
   - Run `py tools/assets/fetch_boss_inputs.py` (a dry run), then again with `--apply`. On a Mac, use `python3`.
   - The files land in `work/boss_inputs/prompt-pack/` and `work/boss_inputs/glb/`. Each is checked against the branch's SHA-256 manifest,
     which has the same hashes as `asset-audit.json`.
   - The brief's absolute paths belong to another machine. Read them as `work/boss_inputs/glb/` and `work/boss_inputs/prompt-pack/`.
   - If anything is missing, ask now and do the rest while you wait.
3. **Bootstrap with one script.** Write `tools/bootstrap.py` (Python, so both computers run it) if it does not exist yet. It must:
   - make one Python environment under `work/` with pinned numpy, scipy and pillow (the system Python had no SciPy and no PIL last time);
   - put the pinned Luau (0.742: `luau`, `luau-compile`, `luau-analyze`) in `work/bin/luau/` and Rojo (7.7.1) in `work/bin/rojo/`
     (`tools/test_asura_stage2.py` calls `work/bin/luau/luau` directly; PATH is not enough);
   - build every generated input the checks need (for example `python3 tools/assets/build_shen_audio.py`);
   - run `bash tools/verify_all.sh` and print its result.
   Record the versions in `ENVIRONMENT.txt`.
4. **Tools:**
   - Check Blender 5.x (set `BLENDER`), the Blender MCP and the Studio MCP (`list_roblox_studios`).
   - Find a screen-capture route that works on this machine. On the Mac, Terminal runs a `.command` script that has Screen Recording permission.
   - List what is missing and ask once.
5. **Session friction:** ask the creator once whether to exempt this task's scratch and output folders from the GateGuard fact-forcing
   hook (`GATEGUARD_EXEMPT_GLOBS`, for example `work/**`, `outputs/<boss-slug>-*/**`, `tools/animation/boss_motion/**`,
   `tools/blender/boss_import/**`). Destructive-command checks stay on. Do not change hook settings without that answer.
6. **Create `outputs/<boss-slug>-<date>/`** with:
   - `HANDOFF.md`: current state, next step, exact commands, open issues, the expected place SHA-256 and fingerprint lines. Update it at every
     milestone. It is what a new session, or the other computer, reads first; Shen's session was compacted more than 26 times.
   - `ENVIRONMENT.txt`: OS, Python and package versions, Blender, Rojo, Luau, Studio version.
   - `experiments.md`: one row per experiment (hypothesis, change, result, kept or rejected).
7. **Ask the creator once** before the first push of asset files: the repo is public, and Shen's assets went to a public orphan branch by choice.

## Reuse map: adapt Shen's tools, don't rewrite them

Put new generic code in `tools/blender/boss_import/` and `tools/animation/boss_motion/`, with one config per boss
(`configs/<look>.py`: skeleton, labels, sheets, colliders, props, thresholds, bind-pose contact regions, visibility rules). Generalise only
what this boss needs.

| Need | Start from | Lesson already learned |
|---|---|---|
| Inspect the GLB; render against the concept | `tools/blender/shen_import/survey.py`, `render_source.py`, `views.py` | Check shell connectivity before cutting. Bright paint is not emissive. |
| Split and label the mesh | `tools/blender/bull_import/glb.py`, `shen_import/segment.py`, `landmarks.py` | Seeds plus flood fill with colour and crease costs, then connected-component clean-up. Stray islands float when limbs move. |
| Skeleton and rig space | `rigdef.py`, `rigspace.py` | Shen: a flat `Root` → `Sk_<limb>` + `Cl_<sheet>_<c>_<r>` skeleton, 123/125 bones per form. The real bone limit is unverified, so check it in M2. |
| Weights, seams, cloth lattices | `skin_rig.py` (`heal()`, sheets, `--cloth-only`) | At most 4 influences per vertex. Shared boundary vertices get identical weights. Healing weight jumps took the worst stretch from 43× to 7.8×. |
| Game chunks and master `.blend` | `build_game.py`, `build_master.py`, `textures.py` | 18k-triangle chunks with a manifest. Recolour per texel: Shen's whole face went black when a label was recoloured. |
| Deformation checks | `pose_test.py`, `check_stretch.py`, `seam_check.py` | Verify every rotation sign with a one-frame render. A lunge with the wrong sign cost a round trip. |
| Dense measures | `skin_points.py`, `body_sdf.py`, `weapon_cloud.py`, `haft_axis.py`, `mesh_clash.py`, `cloth_skin.py`, `cloth_skin_reach.py`, `xray_dump.py --cloth` + `shen_seam.XRay` | Use the real skinned mesh, every sample. Give outputs unique names: one tool once overwrote another's `.npz`. The numpy x-ray (`windows-pass-2026-11-09/scripts/xray_exact.py`) matches Blender's to five decimals in seconds. |
| Review renders and video | `review.py` (x-ray clash mode), `compare_video.py`, `montage.py`, `reel_proxy.py`, `reel_encode.py`, `work/shen_repair/lookpair.sh` pattern | Renders caught a beard flipped over the face that the mesh check missed. The player's camera at 640×360 hides what a close-up shows: render both. |
| Clip authoring and solving | `tools/animation/opening_cast/shen_clips.py` (key language), `shen_lib.py` (`Clip.bake`, `swivel` Viterbi, `joint_polish` SLSQP, `bake_pops`, dense `arm_torso`), `castlib.py` (validate, `.rbxmx`) | The Viterbi search over discrete elbow and fist states fixed wrist flips. SLSQP fixed clipping. The greedy stages caused most of the trouble. |
| Export, upload, register | `export.py`, `publish.py`, `register_shen.py`, `studio_luau.py`, `tools/studio_mcp.py` | Uploads need Studio signed in to the account that owns the game's assets. IDs go to `published.json`. `tools/studio_mcp.py calls.json` runs a committed Luau file in Studio exactly as written. |
| Bind and check in Studio | `bind_skin.py`, `check_skin.py`, `tools/assets/extract_skin.py`, `tools/qa/BossTemplateCheck.luau` | Template names must match `AsuraBoss_<Look>_P<n>` and `_Props`. |
| Runtime skin and cloth | `src/shared/ClothSim.luau`, `ShenClothData.luau` (from `write_cloth_data.py`), `src/client/Controllers/BossCloth.luau`, `src/server/Services/BossSkin.luau`, `tools/test_cloth_sim.py`, `cloth_bake.py` (runs the same Luau sim offline) | Keep the rest-drift and sprint tests, and add this boss's own cases. Measure the cost per step early: Shen's grew from 1.1 ms to 3.6 ms. |
| Play-test, playback proof and reels in Studio | `tools/qa/ShenProbe.server.luau`, `windows-pass-2026-11-09/scripts/studio_preview.luau`, `tools/qa/shen_reel.luau` | See "Studio facts". |
| Same build on every computer | `tools/qa/SourceDigest.luau`, `tools/qa/ShenFingerprint.luau`, `python3 tools/studio_mcp.py --digest` | Hash the place file, digest the scripts, fingerprint the boss and preload all of its assets. |
| Handoff and reproduction | `outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/scripts/` (`pack_untracked.py`, `restore_untracked.py`, `repro_check.py`, `runall.py`) | Copy the pattern for this boss from day one. |

## Milestones

Target pace: M1-M2 on day 1, M3-M4 on day 2, M5-M7 on days 3-4, M8 on the Windows computer.

### M1: model preparation in Blender

1. Import each GLB once into `<Boss>_Master.blend`. Keep an untouched source collection and work on copies.
2. Render front, side, back and three-quarter views beside the concept PNGs.
3. **Write the convention sheet first:** rig space, sculpt pose as rest, ground height, scale, and the sign of every control. Shen used
   +X his right, +Y up, −Z his front.
4. **Split the mesh in this order:**
   - by function: deforming body, rigid armour or crystal, props, cloth/hair/mane/tail, glow;
   - then label and clean islands;
   - then cut chunks under 18k triangles.
5. **Fit the skeleton and measure each phase:** limb and segment lengths, torso width and depth, reach envelope, ground clearance.
   Write them into the config; authoring uses them.
6. **Catalogue the bind-pose contacts:** every region where two body parts, or a garment and a body part, already touch or overlap at
   rest (shoulder seams, armpits, chin and beard, sleeve linings, mane roots). Render them. They go into the config and are handled by one
   rule in M3; on Shen they were handled differently by two measures.
7. **Skin and recolour:**
   - Skin with at most 4 influences, then heal the seams.
   - Build secondary surfaces as bone lattices.
   - Do any phase-2 recolour per texel.
8. **Exit checks:**
   - The turnarounds match the source.
   - An extreme-pose test, with each joint at its range limits, shows no tearing, no exposed underlayers and stretch of about 8× or less.
   - A short wind or secondary-motion test clip moves the soft parts believably.
   - The chunk manifest has triangle counts.
9. **Gate A:** send these renders to the creator (`SendUserFile`), together with the bind-pose contact renders and the proposed visibility
   rules (M3 step 7). Carry on with M2-M3.

### M2: Studio pilot, on day 1, right after the first rig export

Prove the runtime path before building on it.

1. **Import:**
   - Use the 3D Importer with Set Pivot to Scene Origin and 1 stud per unit.
   - Re-tick "Keep Zero Influence Bones" on every import; it resets.
   - Rename through Luau, because the importer's name field garbles typed text.
2. **Bind and play:** bind with `bind_skin.py`, check with `check_skin.py`, then play one test clip in a temporary Rojo-built probe place.
3. **Confirm these, which local tests never caught on Shen:**
   - one shared skeleton across all chunks, and the real bone count;
   - root bone orientation (Shen's sat 180° about Y, which mirrored the mesh until `BossCloth` read it live);
   - `Weld`, not `WeldConstraint`, for skinned chunks;
   - which rig drives the limbs (AnimationConstraints or Motor6D).
4. **Non-humanoid bosses** (Baize, Titan, Wyrm): Shen's skin follows R15 limbs through `BossCloth`. Decide here how clips drive this
   skeleton: map to R15, use a custom rig in `BossRigs`, or extend `CreatureMotion`. Prove it moves in Studio.
5. **Build the Studio harness now, generic, not at the end:**
   - `tools/qa/BossProbe.server.luau` from `ShenProbe.server.luau` (ops: enter, spawn, protect, hold, damage, posture, face, status, cues, heal);
   - `boss_preview.luau` from `studio_preview.luau`: play each clip by its **published** ID, pause at every exported frame time, and compare
     every part with the solver's frame (Shen's worst was 0.0174 rig units);
   - `tools/qa/BossFingerprint.luau` from `ShenFingerprint.luau`: digests of each phase template, the animation IDs and the boss's modules,
     plus a preload of every mesh, texture, animation and sound.
6. **Exit:** a screen capture of the pilot moving in Studio, and the first fingerprint recorded in `HANDOFF.md`.

### M3: the measurement kit, built before any clip and then frozen

1. **Inputs:** dense surface samples per bone from the real skinned mesh (every skin sample, no thinning), signed distance fields per
   body part, and dense point clouds for props.
2. **One function produces every clearance and penetration number.** The solver, the validator, the reports, the review x-ray and the stage
   traces all call it. Its exclusion rules (the bind-pose contacts from M1) live in that function only. A second measure with its own
   rules is a bug, not a cross-check.
3. **It is pure numpy on dumped mesh data.** Blender renders frames for people to watch; it never produces a pass/fail number. Sweeping
   every clip must take minutes.
4. **Read the fades and transitions from the game code, per clip class.** At the time of writing, `src/client/Controllers/BossAnimations.luau`:
   - attacks with contact times: `Play(0.1)` (line 72), and they may start part-way into the clip or hold at rate 0 so the contact lands
     on the server's impact (`Rules.startPlan`): measure those start offsets and holds, including a late start when latency eats the lead;
   - other actions: `Play(0.15)` (line 78); the outgoing action: `Stop(0.15)` (line 42);
   - gaits: `Play(0.2)` / `Stop(0.2)` (lines 179, 115);
   - KO: the clip ends on its last frame and never returns to Idle (line 226), so Death has no fade-out;
   - Blockstun holds its last frame (line 189).
   Build the transition list from the encounter AI and these rules: every clip pair the game can produce, no invented ones. The measure
   blends the way the Animator does (each joint's transform relative to its parent, as `cloth_bake.py`'s `fade_pose`), never in world space.
   Print the source line each fade came from, and re-check the lines whenever `BossAnimations.luau` changes.
5. **It checks:** every frame and the midpoint between frames; every transition from step 4; loop seams.
6. **Pops:** a frame's departure from its neighbours' midpoint beyond what the keys already have ("final minus keyed spikiness"), with
   contact frames anchored. Add angular jumps per bone and prop (degrees per frame) and joint-limit violations (wrists, knees, neck, jaw).
7. **Visibility rules, agreed once with the creator at Gate A:** body or prop coming out through cloth or through another body part is a
   defect. A garment's inner face inside the limb it covers, or a beard or mane root inside the skin it grows from, is not, when renders at
   game distance and close up show it hidden. Write the rules into the config with the example renders. Nothing else is waived.
8. **Ground:** feet, paws and tail stay above ground, and stance feet don't slide.
9. **Calibrate thresholds once, against renders:** pick the depth at which penetration becomes visible in an x-ray render at game distance.
   - For reference, Shen's limits in rig units were a 0.17 wall, a flag past 0.18, and pop limits of 0.2 (fist) and 0.45 (blade).
   - Changing them later needs the creator's OK.
10. **`gate.py`: the only definition of "passes".** One command over every clip, every transition from step 4 and every soft-part pair.
    It compares at full precision, prints a PASS/FAIL row per item (five decimals near a limit) and a one-line total. A milestone is done
    only when the total is 0 FAIL on the whole set, not on the clips being worked on.
11. **Cross-check with `mesh_clash`** on the rendered mesh for a few clips. If the two disagree, fix the measure before anything else.
12. **Keep it fast:** vectorised numpy and cached grids, about 10 s or less to validate a clip. Profile it.
13. **Review tooling:**
    - x-ray renders with clashes highlighted, fixed region cameras, and same-pose before/after stills;
    - the player's camera and a close-up camera for every flagged region;
    - the game's own fades from step 4 (Shen's preview used a world-space fade that invented failures at frames 20-22, and a 0.2 s fade
      from Idle that invented the glaive-in-chest);
    - clip-frame numbering, never shot-frame numbering.

### M4: motion pilot of 6-8 clips that cover every failure class

1. **Pick the clips:** Idle, the main travel gait, one turn, the hardest attack, one hit reaction, Death (ground contact) and the phase transition.
2. **Solve them** with the design in "How the motion solver works" below.
3. **Make a reel** at game camera distance, plus close-ups of the trouble regions.
4. **Gate B:** send the reel to the creator. Get the verdict on these clips before authoring the rest.
5. **The pilot also includes:** one attack end to end in game (server contact time, cue, VFX/SFX), as the brief asks, published and
   played by its published ID through the M2 harness.

### M5: production of every clip

1. **Author the rest.** Lint every key before baking: a key inside the body, or out of reach for that phase, is an authoring error.
   Fix the key, not the solver.
2. **Iterate on a worst-offenders set.** Do full runs only at milestones, with frozen code.
3. **One incremental runner, `runall.py --changed`,** over bake → cloth → measure → export → publish → register. Each step is keyed by
   the content hash of its inputs and code, so unchanged clips are reused at every step, including the upload. On Shen, 49 of 64 clips
   baked identically across a day of solver changes, and all 64 were re-published anyway.
4. **Exit:** `gate.py` prints 0 FAIL, and the reel looks right.

### M6: secondary motion across every clip

1. **Colliders:** fit them to the real body from the distance fields: several small spheres or capsules per region, not one round torso proxy.
   - Give each garment or soft part its own collider list.
   - Shen's beard needed its own chest sphere. Adding chest tiles to every garment caused regressions.
2. **Check surfaces, not only particles.** Particles can clear the body while the surface between them cuts through; check link midpoints too.
3. **Anchor soft parts to the right bones.** Robes need thigh follow; hair and beard tips need chest follow. Hip-crease pinch beyond
   110° thigh flex was a known Shen case.
4. **Run it everywhere:**
   - Run `cloth_bake.py` plus the M3 measure on all clips in one batch, inside `runall.py`.
   - Tune through the cloth JSON or config only.
   - Keep and extend `tools/test_cloth_sim.py`.
5. **Measure the cost** per simulation step and per graphics tier.

### M7: game integration

1. Export, upload (changed clips only), `published.json`, then register. The registration step prints a diff of the IDs.
2. Align contacts with server impact times (`Rules.Contacts`) and keep locomotion rates (`Rules.Locomotion`).
3. **Phase transition:** pre-warm the next phase's skin. A cold cache stalled Shen by 0.6 s.
4. VFX, SFX and music per the brief.
5. **Single-client Studio fight through every state, with captures:**
   - every clip by its published ID against the solver (the M2 harness);
   - both phases and the transition;
   - posture break, deathblow and death;
   - reset, retry and participant death;
   - the Output window: no warnings except the Rojo plugin's own sound preload (`rbxassetid://203785492 ... Asset type does not match`).
6. Run `bash tools/verify_all.sh` and `gate.py`.
7. **Rebuild the canonical place** with `tools/build.py`, then record in `HANDOFF.md`: its SHA-256, `tools/qa/SourceDigest.luau`'s line and
   `BossFingerprint.luau`'s lines (run on that place in Studio, never saved).
8. **Clean-clone check:** clone the pushed branch into a temporary folder, run `tools/bootstrap.py` and `tools/build.py` there, and confirm
   the place is byte-identical with no change in `git status`.

### M8: on the Windows computer

1. Pull, run `tools/bootstrap.py`, and confirm the place SHA-256, the script digest and the fingerprint lines from `HANDOFF.md`.
2. Run the two-client test and device profiling.
3. Write the final report, with evidence split into static review, local regression, Studio integration, multiplayer and device profiling.
4. Push the asset branch.
5. Make `HANDOFF.md` say "done", or list exactly what is left.

## How the motion solver works

1. **A clip is intent, not a finished pose list:**
   - key poses, in a body-relative frame (the chest frame for attacks);
   - timings and contact events (position and time);
   - grips, planted feet and style curves.

   Authoring numbers scale with the phase's measured proportions, so a key valid for phase 1 stays valid for phase 2.
2. **The organic layer turns the intent into a reference trajectory:** overlap, lag, breathing, weight shift and footwork from real gait
   data. Shen's `organic`, `step_feet` and gait code are the model.
3. **One constrained optimisation per clip** then solves it, in overlapping windows for long clips.
   - **Variables per frame:** the controls (pelvis, spine, neck and head, limb IK targets, pole or swivel angles, roll, prop pose, and
     tail or jaw where they are solved). Scale them to similar magnitudes; Shen's first SLSQP moved only one control because of bad scaling.
   - **Objective:** stay close to the reference, plus second-difference smoothness.
   - **Constraints, all from the M3 measure (the same function `gate.py` calls):**
     - clearance of at least the wall plus a 0.01 margin, on every dense sample, at frames, midpoints and every transition the game can
       produce (M3 step 4);
     - contacts within tolerance at their times, and grips;
     - stance feet planted and above ground;
     - joint limits, loop closure, and pops within limits.
   - **Seed it** with one or two cheap heuristic passes: the Viterbi state search for elbows and wrists works well. Never stack greedy
     corrections that each fix one constraint.
4. **Accept a solve only after the full bake/export path re-runs on it** and `gate.py` shows nothing got worse anywhere (Shen's "in-order
   check"). Later stages undid the optimiser on Shen until that check existed.
5. **If it is infeasible**, print which constraint rows bind (Shen's `polishdbg2.py`) and fix the key or the timing.

## Studio facts learned on Shen

- **The MCP Luau thread is sandboxed.** It cannot insert scripts, require game modules, call FireServer or read HttpEnabled. Play-tests
  use a throwaway Rojo build that adds a probe server script (the `ShenProbe` pattern):
  - write a ServerStorage attribute as `op arg xNONCE` (an unchanged value does not fire);
  - read the reply from a result attribute.
- **Run committed Luau exactly:** `tools/studio_mcp.py calls.json` with `[["execute_luau", {"code": <file text>, ...}]]`, so the evidence
  comes from the file in the repo, not a pasted copy.
- **Bones:** `Bone.WorldPosition` excludes `Transform`; use `TransformedWorldCFrame`.
- **Player input from a probe:** ActionIntent packets need a sequence number within 4096 of the last one (`MAX_SEQUENCE_GAP`).
- **Probe order:** a posture blow on a boss seeded to 1 HP kills it. Seed HP after the posture break, not before.
- **Preloading:** `ContentProvider:PreloadAsync` fetches a bare ID string as an image. Preload meshes through their MeshPart, animations
  and sounds through Animation and Sound instances, and texture maps through an ImageLabel (preloading a SurfaceAppearance reports nothing).
- **Frame rate:** Studio throttles to about 15 fps when unfocused, so measure frame times with it focused.
- **Uploads:** "Asset content representation is being generated" right after an upload is transient.
- **Asset access:** every computer must be signed in to the account that owns the uploads (Shen: user 3148600636). Otherwise the place
  shows the same IDs and no meshes; the fingerprint's preload count catches it.
- **Opening places:** never `open -a RobloxStudio <file>`; it starts a second Studio that confuses the MCP and computer use. Use File > Open,
  or on Windows `RobloxStudioBeta.exe -task EditFile -localPlaceFile <path>` when no Studio is running.
- **Closing:** never save. Close Studio without saving, and delete any `content\<boss>preview` folder you created.
- **MCP parameter names:** `datamodel_type`, `is_start`, `capture_id`, `studio_id`.
- **Recording on the Mac:** use the Terminal `.command` route, one capture stream at a time.

## Compute and experiment hygiene

- **Long jobs:**
  - Anything over a minute runs in the background.
  - Wait with until-loops under about 9 minutes; the tool limit is 600 s and foreground `sleep` is blocked.
  - Use `python -u` and absolute paths.
- **Portability:**
  - macOS has no `timeout` and no GNU `split -n`; Windows Git Bash has no `pkill`.
  - zsh does not word-split `$var`.
  - Write runners in Python, not shell, so both computers run them.
- **Parallelism:** run at most cores − 3 bakes at once, each with single-threaded maths (`OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`,
  `MKL_NUM_THREADS`, `VECLIB_MAXIMUM_THREADS` = 1). Watch swap: Shen hit 10 GB of swap at a load of 235.
- **Runs:**
  - Every run gets its own tag folder and a code snapshot.
  - Never edit code a running job imports.
  - Never share output file names between runs.
  - Put NaN guards in every measure: NaN cloth bones once reported "clean".
- **Tools fail loudly** on unknown clip names, empty lists and missing inputs. Check every clip and shot name against the manifest before
  launching anything. Shen's export silently skipped short names and a list that lacked a trailing newline, and one render batch went out
  with wrong names and had to be killed.
- **Processes:** kill only your own PIDs. A broad `pkill -f` once killed the shell.
- **Before trying any variant:**
  - Print a stage trace (depth and pops per stage, per frame) for the failing clip.
  - Try at most three variants per hypothesis, logged in `experiments.md`.
  - After two hours on one defect without progress, write the diagnosis with renders, ask the creator one specific question, and move on.
- **Specialist subagents, with fixed jobs:** at each milestone, one fresh-context subagent re-runs `gate.py` and watches the worst renders,
  and reports only evidence. Others may investigate a measurement question or review code. The main agent owns every edit and the final
  integration; never two writers on the same files.
- **Output:** keep tool output short with `tail` and `grep`, and send long logs to files.

## Communication

- **Updates:**
  - Give one short update at each milestone, each visibly verified fix and each concrete blocker.
  - Send renders and videos with `SendUserFile`.
- **Ask early.** Ask the creator about anything that changes the look (proportions, palette, grip, which parts move freely) or what counts
  as a defect (M3 step 7) before building clips on it.
- **Report evidence by kind:** static review, local regression, Studio integration, multiplayer, device. Never let one stand in for another.
- **Never claim completion** while clipping is visible or `gate.py` prints a FAIL. Keep implementing rather than ending with a plan.

## Boss notes

| Boss | What changes from Shen |
|---|---|
| 02 Venerable Baize | **Body:** quadruped, no weapon; decide the rig in M2. **Gait:** four-legged footfall patterns (walk, trot or stalk, pounce), not R15. **Soft parts:** multi-bone neck and jaw; tail, mane and plumes as secondary lattices; ruby crystals rigid. **Clipping to watch:** legs through the body, tail through legs, jaw and mane. **Bind-pose contacts to catalogue:** mane roots, legs against the belly, jaw. **Gameplay:** keep the Frost hazard logic. |
| 03 Sovereign Wu | **Body:** humanoid, the closest to Shen; reuse the arm and grip solver for the staff. **Props:** charms, orbs, halo and crown strings are separate owned props. |
| 04 Slumbering Titan | **One phase.** **Body:** mostly rigid stone articulation, with real pivots and hidden caps, plus roots. **Clipping to watch:** ground contact and ankle readability. |
| 05 Azure Wyrm | **One phase.** **Body:** long neck, tail and wing chains, with skinned membranes. **Clipping to watch:** tail and wings against the body. |
| 06 Iron Bull | **Existing integration:** audit and reuse it first. **Model:** use only the supplied GLB; the creator rejected a scripted Bull model. |

**Definition of done:**

- The supplied model plays its whole encounter in the real game, with readable authoritative contacts.
- `gate.py` prints 0 FAIL over every clip, every transition the game can produce and every soft-part pair, at full precision, and the
  rendered motion looks organic at game distance and close up.
- Soft parts move without visibly cutting through the body.
- Studio evidence is captured: published-ID playback against the solver, every encounter state, a clean Output.
- The place SHA-256, script digest and boss fingerprint in `HANDOFF.md` match on both computers.
- The asset branch and `HANDOFF.md` let the other computer continue at once.

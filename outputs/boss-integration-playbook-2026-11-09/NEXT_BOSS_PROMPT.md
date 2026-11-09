# Next boss integration: fast-path prompt

Written 2026-11-09 from the Grandmaster Shen post-mortem.

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

**What to build** is in the boss's numbered brief in the prompt pack `Asuras-Path-Claude-Boss-Prompts/` (the brief, `CONCEPT-ART.md`,
`references/`, `asset-audit.json`). **How to build it** is in this prompt, so that it takes days, not weeks:

- On look, moves and gameplay, the brief wins.
- On process, order and tooling, this prompt wins.

## Why this prompt exists

Grandmaster Shen (boss 01) took over four days and is still not finished.

- **The first day went well.** Import, rig, cloth, 64 clips, asset upload and a single-client Studio fight were done in about 20 hours.
- **The next three days went into arm, weapon and torso clipping.** Three clips and about a dozen fade boundaries still fail.

What cost the time, and what you will do instead:

1. **Greedy repair stages that fought each other.**
   - Motion was authored as key poses with no body-collision measure. About fifteen sequential repair stages then tried to clean it up
     (settle, swivel, wrist_yield, clear_torso, slide_fist, tilt_haft, depop…).
   - Each stage undid another. Stage traces proved it: Crimson Embrace went 0.07 after swivel, 0.27 after clear_torso, 0.34 after slide_fist.
   - A single constrained optimiser (SciPy SLSQP) over a window fixed in one pass what hours of stage tuning could not (0.351 → 0.136).
     It arrived last.
   - **Instead:** the optimiser is the main solver from day one.
2. **The clipping measure changed four times.**
   - It went from capsule proxies, to a 250-point weapon cloud, to a dense cloud, to thinned skin samples, to every skin sample.
   - Each change exposed new failures and forced a full re-bake. The optimiser even exploited the thinned samples.
   - **Instead:** build the final, dense, real-mesh measure before the first clip, and freeze it.
3. **Clip boundaries were checked late.** The game's 0.15 s joint-blend fade into and out of Idle, and the poses between frames, failed
   after the clips themselves passed.
   - **Instead:** boundaries and in-between poses are in the measure from the start.
4. **Keys were authored without the body's real proportions.**
   - Phase 2's broader torso, shorter arms and hover put keyed fists inside the chest. No solver rescues an infeasible key; rewriting
     the key did.
   - **Instead:** measure each phase's body first, author keys relative to it, and lint keys before baking.
5. **Wasted compute.**
   - About ten full 64-clip bake or export runs, 1-3 h each, several while code was still changing. One run mixed two code versions.
   - Dozens of variants per problem (hv1-14, ra1-13, bd1-11). Runs overwrote each other's outputs.
   - **Instead:** iterate on a small worst-offenders set, cache unchanged clips, freeze code per run, and cap the variants.
6. **Validator passes were reported as quality.** The creator rejected the motion twice: not organic, rigid cloak, gait, knees, grip.
   - **Instead:** rendered motion is the judge. Get the creator's verdict on a pilot of 8 clips, not on 64.
7. **Shell and Studio friction cost hours.** zsh word splitting, no `timeout` on macOS, the 600 s tool limit, buffered output, relative
   paths after `chdir`, memory thrash, the importer's quirks, the Studio MCP sandbox.
   - **Instead:** use the facts below.
8. **Gitignored inputs reached the other computer only through a last-minute 526 MB archive.** That means `work/`, `assets/source/`,
   `assets/build/` and `.blend` files.
   - **Instead:** push them to an asset branch at every milestone.

## Rules that always apply

- **Project rules:** follow `CLAUDE.md`, `AGENTS.md` and `.agents/skills/ro-engineer/SKILL.md`.
- **Commit every turn:**
  - Run `tools/build.py` when code or assets change, and add a PROJECT_STATE note of 60 words or fewer.
  - End the commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, push to `ux/onboarding-overhaul`, then confirm a clean status.
  - This overrides any "do not commit" line in the brief.
- **Files you never read:**
  - Never open `.rbxl`, `.rbxlx`, `.glb`, `.obj` or images with text tools. View renders as images.
  - Never touch `Codex`, `Obsidian Vault` or `Cagebound_Archive`.
- **Visual quality first:**
  - Never decimate or remesh. Split into MeshParts under 20k triangles (target 18k or fewer).
  - Keep the 2048 maps, the UVs and the normals.
- **Organic motion:**
  - Cloth, hair, manes, plumes and tails deform as skinned surfaces driven by simulation, never rigid plates on one hinge.
  - Bodies move with weight transfer, lead and lag, overlap, and gait patterns taken from real anatomy.
- **Tests stay honest:**
  - Never loosen a test, thin a measure, or exclude failing geometry.
  - Nothing becomes an "accepted limitation" without the creator's word.
- **Uploads:**
  - Never invent asset IDs.
  - Uploading this boss's own meshes, animations and audio through Studio is part of the job, as it was for Shen.
  - Never publish or overwrite the game place.
- **Multi-client tests:** two-client and multi-server tests run only on the Windows computer. On the Mac, stop at single-client evidence.
- **Shen is still being repaired on the other computer:**
  - Do not edit Shen's files: `tools/animation/opening_cast/shen_lib.py`, `shen_clips.py`, `tools/blender/shen_import/*` and Shen data.
  - Copy what you need into boss-agnostic modules.
  - After changing any shared file (`castlib.py`, `export.py`, `ClothSim.luau`, `BossCloth.luau`, `BossSkin.luau`, `BossAnimations.luau`),
    Shen's `outputs/grandmaster-shen-2026-11-05/repair/handoff-2026-11-09/scripts/repro_check.py` must still print REPRODUCED, and
    `tools/test_cloth_sim.py` must pass.
- **Check the skin in play:** start every character test by reading each actor's `AsuraSkinStatus`. A fallback while our model exists is a bug.

## Day 0: setup (one hour, before any asset work)

1. Run `git pull --rebase origin ux/onboarding-overhaul`, then read the top of `PROJECT_STATE.md`.
2. **Find the inputs.**
   - The boss GLBs are usually in this user's Downloads. The brief's `/Users/dishanroy/...` paths belong to another machine.
   - Also find the prompt pack.
   - Check each GLB's SHA-256 against `asset-audit.json`.
   - If anything is missing, ask now and do the rest while you wait.
3. **Make one Python environment** under `work/` with numpy, scipy and pillow. The system Python had no SciPy and no PIL last time.
   Record the versions.
4. **Tools:**
   - Check Blender 5.x (set `BLENDER`), the platform's `work/bin/luau` binary and Rojo.
   - Check the Blender MCP and the Studio MCP (`list_roblox_studios`).
   - Find a screen-capture route that works on this machine. On the Mac, Terminal runs a `.command` script that has Screen Recording permission.
   - List what is missing and ask once.
5. **Create `outputs/<boss-slug>-<date>/`** with:
   - `HANDOFF.md`: current state, next step, exact commands and open issues. Update it at every milestone. It is what a new session,
     or the other computer, reads first; Shen's session was compacted 26 times.
   - `ENVIRONMENT.txt`: OS, Python and package versions, Blender, Rojo.
   - `experiments.md`: one row per experiment (hypothesis, change, result, kept or rejected).
6. **Ask the creator once** before the first push of asset files: the repo is public, and Shen's assets went to a public orphan branch by choice.

## Reuse map: adapt Shen's tools, don't rewrite them

Put new generic code in `tools/blender/boss_import/` and `tools/animation/boss_motion/`, with one config per boss
(`configs/<look>.py`: skeleton, labels, sheets, colliders, props, thresholds). Generalise only what this boss needs.

| Need | Start from | Lesson already learned |
|---|---|---|
| Inspect the GLB; render against the concept | `tools/blender/shen_import/survey.py`, `render_source.py`, `views.py` | Check shell connectivity before cutting. Bright paint is not emissive. |
| Split and label the mesh | `tools/blender/bull_import/glb.py`, `shen_import/segment.py`, `landmarks.py` | Seeds plus flood fill with colour and crease costs, then connected-component clean-up. Stray islands float when limbs move. |
| Skeleton and rig space | `rigdef.py`, `rigspace.py` | Shen: a flat `Root` → `Sk_<limb>` + `Cl_<sheet>_<c>_<r>` skeleton, 123/125 bones per form. The real bone limit is unverified, so check it in M2. |
| Weights, seams, cloth lattices | `skin_rig.py` (`heal()`, sheets, `--cloth-only`) | At most 4 influences per vertex. Shared boundary vertices get identical weights. Healing weight jumps took the worst stretch from 43× to 7.8×. |
| Game chunks and master `.blend` | `build_game.py`, `build_master.py`, `textures.py` | 18k-triangle chunks with a manifest. Recolour per texel: Shen's whole face went black when a label was recoloured. |
| Deformation checks | `pose_test.py`, `check_stretch.py`, `seam_check.py` | Verify every rotation sign with a one-frame render. A lunge with the wrong sign cost a round trip. |
| Dense measures | `skin_points.py`, `body_sdf.py`, `weapon_cloud.py`, `haft_axis.py`, `mesh_clash.py`, `cloth_skin.py`, `cloth_skin_reach.py` | Use the real skinned mesh, every sample. Give outputs unique names: one tool once overwrote another's `.npz`. |
| Review renders and video | `review.py` (x-ray clash mode), `compare_video.py`, `montage.py`, `reel_proxy.py`, `reel_encode.py` | Renders caught a beard flipped over the face that the mesh check missed. |
| Clip authoring and solving | `tools/animation/opening_cast/shen_clips.py` (key language), `shen_lib.py` (`Clip.bake`, `swivel` Viterbi, `joint_polish` SLSQP, `bake_pops`, dense `arm_torso`), `castlib.py` (validate, `.rbxmx`) | The Viterbi search over discrete elbow and fist states fixed wrist flips. SLSQP fixed clipping. The greedy stages caused most of the trouble. |
| Export, upload, register | `export.py`, `publish.py`, `register_shen.py`, `studio_luau.py`, `tools/studio_mcp.py` | Uploads need Studio signed in to the account that owns the game's assets. IDs go to `published.json`. |
| Bind and check in Studio | `bind_skin.py`, `check_skin.py`, `tools/assets/extract_skin.py` | Template names must match `AsuraBoss_<Look>_P<n>` and `_Props`. |
| Runtime skin and cloth | `src/shared/ClothSim.luau`, `ShenClothData.luau` (from `write_cloth_data.py`), `src/client/Controllers/BossCloth.luau`, `src/server/Services/BossSkin.luau`, `tools/test_cloth_sim.py`, `cloth_bake.py` (runs the same Luau sim offline) | Keep the rest-drift and sprint tests, and add this boss's own cases. Measure the cost per step early: Shen's grew from 1.1 ms to 3.6 ms. |
| Play-test and reels in Studio | `tools/qa/ShenProbe.server.luau`, `tools/qa/shen_reel.luau` | See "Studio facts". |
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
6. **Skin and recolour:**
   - Skin with at most 4 influences, then heal the seams.
   - Build secondary surfaces as bone lattices.
   - Do any phase-2 recolour per texel.
7. **Exit checks:**
   - The turnarounds match the source.
   - An extreme-pose test, with each joint at its range limits, shows no tearing, no exposed underlayers and stretch of about 8× or less.
   - A short wind or secondary-motion test clip moves the soft parts believably.
   - The chunk manifest has triangle counts.
8. **Gate A:** send these renders to the creator (`SendUserFile`) and carry on with M2-M3.

### M2: Studio pilot, on day 1, right after the first rig export

Prove the runtime path before building on it.

1. **Import:**
   - Use the 3D Importer with Set Pivot to Scene Origin and 1 stud per unit.
   - Re-tick "Keep Zero Influence Bones" on every import; it resets.
   - Rename through Luau, because the importer's name field garbles typed text.
2. **Bind and play:** bind with `bind_skin.py`, check with `check_skin.py`, then play one test clip in a Rojo-built probe place.
3. **Confirm these, which local tests never caught on Shen:**
   - one shared skeleton across all chunks, and the real bone count;
   - root bone orientation (Shen's sat 180° about Y, which mirrored the mesh until `BossCloth` read it live);
   - `Weld`, not `WeldConstraint`, for skinned chunks;
   - which rig drives the limbs (AnimationConstraints or Motor6D).
4. **Non-humanoid bosses** (Baize, Titan, Wyrm): Shen's skin follows R15 limbs through `BossCloth`. Decide here how clips drive this
   skeleton: map to R15, use a custom rig in `BossRigs`, or extend `CreatureMotion`. Prove it moves in Studio.
5. **Exit:** a screen capture of the pilot moving in Studio.

### M3: the measurement kit, built before any clip and then frozen

1. **Inputs:** dense surface samples per bone from the real skinned mesh (every skin sample, no thinning), signed distance fields per
   body part, and dense point clouds for props.
2. **One function produces every clearance and penetration number.** The solver, the validator, the reports and the stage traces all call it.
3. **It checks:**
   - every frame, and the midpoint between frames;
   - the game's 0.15 s linear joint-blend fade into and out of Idle, and between clips that follow each other in the encounter
     (for example PostureBreak into DeathblowVictim);
   - loop seams.
4. **Pops:** a frame's departure from its neighbours' midpoint beyond what the keys already have ("final minus keyed spikiness"), with
   contact frames anchored. Add angular jumps per bone and prop (degrees per frame) and joint-limit violations (wrists, knees, neck, jaw).
5. **Ground:** feet, paws and tail stay above ground, and stance feet don't slide.
6. **Calibrate thresholds once, against renders:** pick the depth at which penetration becomes visible in an x-ray render at game distance.
   - For reference, Shen's limits in rig units were a 0.17 wall, a flag at 0.18, and pop limits of 0.2 (fist) and 0.45 (blade).
   - Changing them later needs the creator's OK.
7. **Cross-check with `mesh_clash`** on the rendered mesh for a few clips. If the two disagree, fix the measure before anything else.
8. **Keep it fast:** vectorised numpy and cached grids, about 10 s or less to validate a clip. Profile it.
9. **Review tooling:**
   - x-ray renders with clashes highlighted, fixed region cameras, and same-pose before/after stills;
   - the game's own fade (Shen's preview used a world-space fade that invented failures at frames 20-22);
   - clip-frame numbering, never shot-frame numbering.

### M4: motion pilot of 6-8 clips that cover every failure class

1. **Pick the clips:** Idle, the main travel gait, one turn, the hardest attack, one hit reaction, Death (ground contact) and the phase transition.
2. **Solve them** with the design in "How the motion solver works" below.
3. **Make a reel** at game camera distance, plus close-ups of the trouble regions.
4. **Gate B:** send the reel to the creator. Get the verdict on these clips before authoring the rest.
5. **The pilot also includes:** one attack end to end in game (server contact time, cue, VFX/SFX), as the brief asks.

### M5: production of every clip

1. **Author the rest.** Lint every key before baking: a key inside the body, or out of reach for that phase, is an authoring error.
   Fix the key, not the solver.
2. **Iterate on a worst-offenders set.** Do full runs only at milestones, with frozen code.
3. **Make bakes deterministic and cached** by content hash (clip source, library code, inputs), so unchanged clips are reused.
   On Shen, 49 of 64 clips baked identically across a day of solver changes.
4. **Exit:** every clip passes the measurement kit, including boundaries and pops, and the reel looks right.

### M6: secondary motion across every clip

1. **Colliders:** fit them to the real body from the distance fields: several small spheres or capsules per region, not one round torso proxy.
   - Give each garment or soft part its own collider list.
   - Shen's beard needed its own chest sphere. Adding chest tiles to every garment caused regressions.
2. **Check surfaces, not only particles.** Particles can clear the body while the surface between them cuts through; check link midpoints too.
3. **Anchor soft parts to the right bones.** Robes need thigh follow; hair and beard tips need chest follow. Hip-crease pinch beyond
   110° thigh flex was a known Shen case.
4. **Run it everywhere:**
   - Run `cloth_bake.py` plus `mesh_clash` on all clips in one batch.
   - Tune through the cloth JSON or config only.
   - Keep and extend `tools/test_cloth_sim.py`.
5. **Measure the cost** per simulation step and per graphics tier.

### M7: game integration

1. Export, upload, `published.json`, then register.
2. Align contacts with server impact times (`Rules.Contacts`) and keep locomotion rates (`Rules.Locomotion`).
3. **Phase transition:** pre-warm the next phase's skin. A cold cache stalled Shen by 0.6 s.
4. VFX, SFX and music per the brief.
5. **Single-client Studio fight through every state, with captures:**
   - both phases and the transition;
   - posture break, deathblow and death;
   - reset, retry and participant death.
6. Run `bash tools/verify_all.sh`.

### M8: on the Windows computer

1. Run the two-client test and device profiling.
2. Write the final report, with evidence split into static review, local regression, Studio integration, multiplayer and device profiling.
3. Push the asset branch.
4. Make `HANDOFF.md` say "done", or list exactly what is left.

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
   - **Constraints, all from the measurement kit:**
     - clearance of at least the wall plus a 0.01 margin, on every dense sample, at frames, midpoints and fades;
     - contacts within tolerance at their times, and grips;
     - stance feet planted and above ground;
     - joint limits, loop closure, and pops within limits.
   - **Seed it** with one or two cheap heuristic passes: the Viterbi state search for elbows and wrists works well. Never stack greedy
     corrections that each fix one constraint.
4. **Accept a solve only after the full bake/export path re-runs on it** and nothing got worse (Shen's "in-order check"). Later stages
   undid the optimiser on Shen until that check existed.
5. **If it is infeasible**, print which constraint rows bind (Shen's `polishdbg2.py`) and fix the key or the timing.

## Studio facts learned on Shen

- **The MCP Luau thread is sandboxed.** It cannot insert scripts, require game modules, call FireServer or read HttpEnabled. Play-tests
  use a throwaway Rojo build that adds a probe server script (the `ShenProbe` pattern):
  - write a ServerStorage attribute as `op arg xNONCE` (an unchanged value does not fire);
  - read the reply from a result attribute.
- **Bones:** `Bone.WorldPosition` excludes `Transform`; use `TransformedWorldCFrame`.
- **Frame rate:** Studio throttles to about 15 fps when unfocused, so measure frame times with it focused.
- **Uploads:** "Asset content representation is being generated" right after an upload is transient.
- **Opening places:** never `open -a RobloxStudio <file>`; it starts a second Studio that confuses the MCP and computer use. Use File > Open.
- **MCP parameter names:** `datamodel_type`, `is_start`, `capture_id`, `studio_id`.
- **Recording on the Mac:** use the Terminal `.command` route, one capture stream at a time.

## Compute and experiment hygiene

- **Long jobs:**
  - Anything over a minute runs in the background.
  - Wait with until-loops under about 9 minutes; the tool limit is 600 s and foreground `sleep` is blocked.
  - Use `python -u` and absolute paths.
- **Portability:**
  - macOS has no `timeout` and no GNU `split -n`.
  - zsh does not word-split `$var`.
  - Write runners in Python, not shell, so Windows can run them too.
- **Parallelism:** run at most cores − 3 bakes at once, each with single-threaded maths (`OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`,
  `VECLIB_MAXIMUM_THREADS` = 1). Watch swap: Shen hit 10 GB of swap at a load of 235.
- **Runs:**
  - Every run gets its own tag folder and a code snapshot.
  - Never edit code a running job imports.
  - Never share output file names between runs.
  - Put NaN guards in every measure: NaN cloth bones once reported "clean".
- **Tools fail loudly** on unknown clip names, empty lists and missing inputs. Shen's export silently skipped short names and a list
  that lacked a trailing newline.
- **Processes:** kill only your own PIDs. A broad `pkill -f` once killed the shell.
- **Before trying any variant:**
  - Print a stage trace (depth and pops per stage, per frame) for the failing clip.
  - Try at most three variants per hypothesis, logged in `experiments.md`.
  - After two hours on one defect without progress, write the diagnosis with renders, ask the creator one specific question, and move on.
- **Output:** keep tool output short with `tail` and `grep`, and send long logs to files.

## Communication

- **Updates:**
  - Give one short update at each milestone, each visibly verified fix and each concrete blocker.
  - Send renders and videos with `SendUserFile`.
- **Ask early.** Ask the creator about anything that changes the look (proportions, palette, grip, which parts move freely) before
  building clips on it.
- **Never claim completion** while clipping is visible. Keep implementing rather than ending with a plan.

## Boss notes

| Boss | What changes from Shen |
|---|---|
| 02 Venerable Baize | **Body:** quadruped, no weapon; decide the rig in M2. **Gait:** four-legged footfall patterns (walk, trot or stalk, pounce), not R15. **Soft parts:** multi-bone neck and jaw; tail, mane and plumes as secondary lattices; ruby crystals rigid. **Clipping to watch:** legs through the body, tail through legs, jaw and mane. **Gameplay:** keep the Frost hazard logic. |
| 03 Sovereign Wu | **Body:** humanoid, the closest to Shen; reuse the arm and grip solver for the staff. **Props:** charms, orbs, halo and crown strings are separate owned props. |
| 04 Slumbering Titan | **One phase.** **Body:** mostly rigid stone articulation, with real pivots and hidden caps, plus roots. **Clipping to watch:** ground contact and ankle readability. |
| 05 Azure Wyrm | **One phase.** **Body:** long neck, tail and wing chains, with skinned membranes. **Clipping to watch:** tail and wings against the body. |
| 06 Iron Bull | **Existing integration:** audit and reuse it first. **Model:** use only the supplied GLB; the creator rejected a scripted Bull model. |

**Definition of done:**

- The supplied model plays its whole encounter in the real game, with readable authoritative contacts.
- Every clip and boundary passes the frozen measurement kit, and the rendered motion looks organic.
- Soft parts move without cutting through the body.
- Studio evidence is captured.
- The asset branch and `HANDOFF.md` let the other computer continue at once.


### One-handed trial (2026-11-09): not adopted

The user allowed a consistent one-handed style if it gave a cleaner result. Trial: `onehand_trial` (reversible, nothing in the repo's clips changed). It strips the lead hand's channels from P2 Idle, WalkForward, Guandao_Heavy and Rending Arc, gives the free left arm a guard pose with a counterbalance through each cut, and bakes them with the same solver as the two-handed set.

| Clip (phase 2) | Two-handed R / L in chest | One-handed R / L | Mesh, deepest arm vertex in chest (2H -> 1H) |
|---|---|---|---|
| Idle | 0.138 / 0.017 | 0.138 / 0.000 | 0.110 -> 0.110 (walk2 shot) |
| WalkForward | 0.106 / 0.001 | 0.106 / 0.000 | (same shot) |
| Guandao_Heavy | 0.212 / 0.206 | **0.320** / 0.000 | 0.199 -> **0.244** |
| Rending Arc | 0.228 / 0.210 | **0.263** / 0.000 | 0.200 -> **0.261** |

Videos: `repair/onehand_trial_p2_{idle_walk,heavy,rendingarc}.mp4` (top two-handed, bottom one-handed, x-ray).

Why not: of the 12 clips then failing, only two were the lead arm alone (P1 Wheel of Heaven, P2 Blood Wave); ten were the right arm. The weapon paths put the right fist where a rear hand sits, by the hip with the haft across him. Without the lead hand turning the chest behind the cut, the right arm crossed the chest deeper at the contact frames, which are fixed by gameplay. Converting would mean re-authoring every attack's fist path and moving the grip to the haft's balance point (a glaive held one-handed at its butt reads weightless), which changes reach and contacts. Two-handed was kept; the trial module stays in the scratch harness only.

### Fourth pass (2026-11-09): causes found and fixed

Solver (`shen_lib.py`):

| Problem | Cause | Change |
|---|---|---|
| P2 Death right arm 0.14 -> 0.19 after the edge-flip fix | the elbow and knee poles were also splined as unit vectors; their key lengths shape the in-betweens | only the blade edge is interpolated as a unit vector |
| P2 Skyfall right arm 0.31 at f51 alone | depop averaged the bare edge vectors and squared the result to the haft: where they nearly cancelled, the blade rolled at random and the wrist followed | each neighbour's edge is laid into the frame's haft plane before averaging |
| P2 Flourish fist 0.44 out on f17 | depop's last pass was written and never solved; the export's solve put it back | every pass is solved before the next writes; the clip keeps the best pass |
| Elbow smoothing put arms in his chest (P2 Deathblow Victim 0.00 -> 0.17 at f39) | swivel smoothed the elbow over 5 frames and checked the result against the weapon only | the smoothed arm is measured in the torso too, and the frame's own choice is restored where it was shallower |
| Right hand rolled into his chest just before Heavy's blow (P2 f11: 0.10 -> 0.25 in swivel) | swivel weighed each elbow turn's torso depth with one untilted fist; the fist's turns roll the knuckles a hand's width, so the hand it chose was never measured | the hand's torso depth is weighed for each turn of the fist (all 80), with the arm's for each elbow turn |

Found and not changed: `slide_fist` spreads each frame's slide over its neighbours without checking them; where the lead hand is half back on the haft (P2 Heavy's regrip, f21) the spread drew the right arm from 0.10 to 0.33 into the chest. A guard made the slide uneven (0.32 to 0 in a frame); re-authoring Heavy's follow-through removed the case instead.

Tried and rejected: scoring every grip turn's whole arm exactly in swivel (no gain on L3/Heavy, Deathblow 0.20 -> 0.29; the hand alone per turn is what was missing); doubling swivel's torso cost (no change); restoring the final settle (no change); roll-angle edge smoothing (edge pops 2.49).

Authoring (`shen_clips.py`), the pattern this pass: in phase 2 the corruption layer pitches the chest 8 deg and the hips 6 further and turns the trunk more, so arms that clear in phase 1 fold into the broader phase 2 chest. Fixes put the hands where the chest faces, or bow the chest less, rather than loosening anything.

| Clip | Before (R / L) | Change | After |
|---|---|---|---|
| P2 Returning Tide (L2) | 0.30 / 0.10 | follow-through carried to where his chest faces (78 deg to his right) | AFTER_L2 |
| P2 Heaven Cleave (L3) | 0.19 / 0.14 | 6 deg less bow at the blow | AFTER_L3 |
| P1/P2 Feint | 0.29 / 0.14 | blade picked up over 0.3 s, not 4 frames (the haft flipped 110 deg f3-4) | AFTER_FE |
| P1/P2 Flourish | fist pop 0.44 | the wheel leans out as the blade passes behind him | AFTER_FL |
| P1 Wheel of Heaven | 0.17 / 0.19 | both cuts forward with the lunge | AFTER_WH |
| P2 Rending Arc | 0.23 / 0.21 | first cut's approach toward the chest's facing, lead hand chokes up for the second, overhead wind-up raised | AFTER_RA |
| P2 Deathblow Victim | 0.27 / 0.02 | the blow drives the corruption out of him (as Death does), plus the swivel guard | AFTER_DB |
| P2 Death, Skyfall | 0.19, 0.31 | solver fixes above | AFTER_DS |
| P2 Blood Wave | 0.14 / 0.20 | the haul bows 8 deg, not 14, and the lead hand chokes up (span 1.6) | AFTER_BW |
| P2 Green Dragon (Heavy) | 0.21 / 0.21 | wind 82 deg, not 100, and more upright; blow eased in; follow-through carried round to his right with his chest (it had unwound 116 deg past the hands: keyed right arm 0.37 in, f15-21) | AFTER_HV |
| P2 Rending Arc (again) | 0.20 / 0.18 | 6 deg less bow at the second blow, 8 less at the third (keyed 0.25-0.32, f58-64, cleared by the bake only by chance) | AFTER_RA2 |
| P1 Hesitant Moon | 0.183 / 0.15 | the rising cut picks the blade up over 0.3 s as he turns (the fist swung back past his right hip, f6) | AFTER_HM |
| P1 Flowing Glaive | 0.18 / 0.20 | the overhead finish lands 0.35 further forward with his 1.1 lunge (lead forearm in his belly, f83-90) | AFTER_FJ |

### Joint solve (SciPy SLSQP), denser measures and clip boundaries (2026-11-09)

**Are conflicting sequential corrections still the cause?** Yes, for the arm-in-torso failures left after dp11. Stage traces (each frame solved alone after every pass, as the export solves it):

| Clip, frame | keys | swivel | clear_torso | slide_fist | depop | final |
|---|---|---|---|---|---|---|
| P2 Crimson Embrace f48 | 0.07 | 0.34 | 0.27 | 0.34 | 0.34 | 0.351 |
| P2 Deathblow Victim f38-39 | 0.00 | 0.17 | 0.14 | 0.15 | 0.20 | 0.202 |

Each pass optimizes its own measure and a later one undoes an earlier one.

**Offline prototype** (`slsqp_proto.py`, the dp11 bakes, nothing changed in the repo): SciPy `minimize(method="SLSQP")` over the frames of one window solved together, ends held. Controls per frame: fist point (3), haft tilt about the fist with both grips riding it (2), right elbow swing (1). Constraints are the pipeline's own measures from the export's solve: arms in the torso under the wall, arms/weapon clash no deeper, reach/grip misses, wrist and weapon floor no worse; frames at a contact keep the weapon. Objective: least change plus its second difference.

| Window | Termination | Iterations / evals | Runtime | Internal violations before → after | Validator arm-in-torso before → after | Other validator rows |
|---|---|---|---|---|---|---|
| P2 Crimson Embrace f44-52 | status 9, iteration limit (150) | 150 / 909 fun, 151 jac, 16,218 frame solves | 608 s (machine loaded) | f47 0.161, f48 0.181 → f48 0.001 | 0.351 → 0.171 | unchanged; right wrist 78 → 94 deg |
| P2 Deathblow Victim f35-43 | status 9, iteration limit (150) | 150 / 838 fun, 151 jac, 15,635 frame solves | 635 s | f37-40 up to 0.032 → none | 0.202 → 0.170 (a 6 deg elbow swing) | unchanged |

**Visual check of the deformed mesh** (review.py x-ray, skinned arm vertices inside UpperTorso, same camera and frames): Crimson Embrace deepest 0.358 → 0.219 (f48 still visibly in his chest); Deathblow Victim f37-40 0.188-0.204 → 0.160-0.185. The optimizer's return was not the whole story: the pipeline's arm measure used every other sample of the upper arm, and the solve settled where the skin between samples stayed deep (f48: 0.171 thinned, 0.199 on every sample, 0.219 on the mesh). The same thinning under-counted the current bakes (Deathblow Victim f40: 0.174 thinned, 0.201 every sample).

**Clip boundaries.** The review shots faded clips by mixing each part's place in the world; the game's Animator mixes each joint's own transform. A Python check of the boundaries reproduces the mesh x-ray exactly (Idle → Deathblow Victim, world-place mix: 0.364 both). With the joint mix the game uses, Deathblow Victim's entry is still 0.26 from Idle and 0.34 from Posture Break (the only state the game enters it from). The validator also checked keyframes only; the game draws halfway between them (Deathblow Victim f2/f3: 0.127/0.108, halfway 0.183).

**Integrated (smallest change that addresses what the prototype showed):**
- `shen_lib.joint_polish`: the SLSQP solve as the bake's last stage, only on runs of frames (or halfway poses) still past the wall; every skin sample; 0.01 under the wall; halfway poses between frames constrained too; left-elbow swing and free-left-arm roll added; stops once feasible and settled; a window is kept only when shallower with no other constraint worse. SciPy is imported lazily: without it the stage is skipped and validate still flags the clip.
- `shen_lib.validate`: arm-in-torso on every skin sample, and halfway between frames (joint mix). Stricter, not looser.
- `cloth_bake.fade_pose`: review shots fade clips joint by joint, as the game does.
- Mink was used only as a reference (its collision-avoidance limits and frame tasks map onto the constraints above); no MuJoCo migration. Blender MCP (5.2.2, protocol 15) and Studio MCP (ShenQA, ShenQA2) were checked and reused; no servers added.

Under the stricter validator dp11 has 9 failing clips of 64 (55 pass); 12 have something past the wall and were rebaked with the polish (dp13).

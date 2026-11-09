
## 8. Clipping repair (2026-11-08 to 11-09, Computer A)

All results here are local: Blender renders of the real skinned GLB driven by the exported frames, the game's own `ClothSim.luau` on the Luau CLI, and the clip validator. Nothing in this section was played in Studio (the clips are unpublished; see section 7).

### Demonstrated repairs (before/after videos in `repair/`)

| Repair | Clip, region | Before | After | Video |
|---|---|---|---|---|
| Arm/weapon | P2 Idle (3.4 s loop), glaive butt cap in the right forearm | inside the forearm on 40 of 81 rendered frames, up to 0.109 deep (106 vertices) | 0 of 81 | `arm_p2_idle_buttcap_forearm_before_after.mp4` |
| Robe/body | P2 Idle, RobeRight over the right knee and shin | knee through the robe on 95% of frames, 0.28 deep | no garment clash on the full mesh | `robe_p2_idle_knee_before_after.mp4` |
| Beard/chest | P2 Deathblow Victim f6-44, beard into the chest | 32,557 beard vertex-frames inside the chest, 0.378 deep | 5,262, 0.164 deep; no flip over the face | `beard_p2_deathblowvictim_before_after.mp4` |

- Arm/weapon cause: the pipeline checked the glaive with 250 of its 1,500 sample points. Over the butt cap that left 3 points across 0.2 of length, so it read 0.006 where the mesh had 0.109. It now uses a dense cloud of the real weapon surface (`weapon_cloud.py`).
- Robe cause (confirmed): the cloth particles cleared the body, but the drawn robe surface between them did not. The fix keeps the drawn surface itself out of the body volumes it can reach (`cloth_skin_reach.py`, `skinPass` in `ClothSim`).
- Beard cause: the shared chest sphere held the beard at the robe's clearance. The beard now has its own least-squares chest sphere and skin-only tiles. A particle-tile variant was rejected: it threw the beard over the face in f23-32.
  - Trade-off: a small patch under the chin sits in the jaw (Running 0.03 -> 0.15).
  - No robe regression. Phase 1 is neutral.

### Remaining failures found and repaired in this pass

| Problem | Cause | Change |
|---|---|---|
| Spine turned twice its limit (P2 Crimson Embrace: chest 86 deg on the hips and bowed 55, keyed 32 and 28) | `spine_reach` capped each of its two passes, not their sum | cap the total (`shen_lib.spine_reach`) |
| Crimson Embrace both arms 0.38 in the chest, left hand 1.2 off the haft | the regrip ramped in from 0.5 s, so the lead hand chased a haft held behind him | regrip only after the reach (`shen_clips.crimson_embrace`) |
| Lead arm in the chest when it crosses his front | no shoulder-blade glide round the ribs | lead shoulder glides up to 0.35 as the hand crosses the midline, eased by the grip weight |
| Loop seams in P2 TurnLeft/TurnRight | post passes and swivel paths did not wrap | `close_loop` distributes the end-to-start difference |
| P2 Crescent Reap neck 122 deg on the chest | head held on target through a 52 deg chest turn | look 0.77 at the follow-through (104.7) |
| One-frame jumps of the fist, haft or grip slide (new check) | per-frame passes (`clear_torso`, `wrist_yield`) and the solver's per-frame corrections | see below |

**Pops.** The validator had no pop check, and the user asked for one. `bake_pops` now flags a frame that leaves the midpoint of its neighbours by more than the keys do there:
- limits: fist 0.2, haft line 0.45 (a point 2.5 up it), slide 0.2, lead-hand reach 0.2;
- a fast keyed swing does not count, and neither does a keyed peak the solver only flattens.

Fixes:
- `clear_torso` now chooses moves its neighbouring frames can share.
- It also limits the change per frame (0.3) and the bump over the neighbours' mean (0.1).
- A final `settle` covers the later passes.
- A new last stage, `depop`, solves the frames as the export will. Where the weapon still jumps, it smooths the bake's correction over the frame and two either side, then solves again. Contact frames are kept.

### Results by evidence type

- **Static review (validator, all 64 clips, in-process bake)**: RESULTS_TABLE
- **Exported final poses** (frame JSON, after every pass and the export): out-and-back jumps of 0.5 or more in a hand, forearm or the glaive, POPJSON_RESULT.
- **Mesh level** (renders, x-ray: arm vertices inside the chest lit magenta): MESH_RESULT
- **Local regression**: VERIFY_RESULT; `test_cloth_sim.py` passes (rest drift 1.143 P1, 1.187 P2, limit 1.2).
- **Studio**: not run for these clips (unpublished).
- **Multiplayer**: not run on this computer.
- **Device profiling**: not run.

### Still open

OPEN_LIST

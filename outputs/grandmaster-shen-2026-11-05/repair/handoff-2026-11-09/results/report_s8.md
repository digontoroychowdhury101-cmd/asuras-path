
## 8. Third pass: clipping measured on the real mesh (2026-11-07)

Request: no cloth clipping, and no arm passing through the weapon. Measured, not judged by eye.

**How it is measured** (`tools/blender/shen_import/mesh_clash.py`):
- Every clip is baked as its own shot, after a 0.6 s idle (`cloth_bake.py c1_<clip>` / `c2_<clip>`), through the game's own cloth simulation.
- Every second frame is posed on the real skinned GLB, and all vertices of the body, hands, garments and glaive are tested.
- Inside means inside the signed distance field of a real body part or of the glaive (`body_sdf.py`, winding-number signs), carried by its bone.
- It counts past 0.03 rig units (hands 0.05, since they hold the wood), only where that part's own skin is rigid on its bone, and not what already overlaps at the shot's first frame.
- Body vertices are grouped by the bone they follow most. The heel of the palm and the wrist crease are sculpted on the arm meshes but skinned to the hand, so they count as hand.
- "Before" is the clip set at the start of this pass, re-baked and re-checked with the same rules.

**Solver (`shen_lib.py`, every clip)**
- Real solids replace guessed capsules: each body part's distance field and the glaive's own field, tested both ways (the weapon in the body, and the body's surface in the weapon), because the haft is thinner than the gaps between sample points.
- The haft's real centreline (`haft_axis.py`): the sculpted haft is S-bent up to 0.065 off the landmark line, so the fist and lead hand are placed on the wood itself.
- Skinned surface (`skin_points.py`, new): the solver poses his surface the way the game skins it, by blending each point's bones. Rigid samples were up to 0.49 off at a bent elbow, so an arm could look clear to the solver and still sit in the wood. A rigid solid near a joint is only trusted where its skin follows its own bone (the same rule as the mesh check).
- Grip choice (`swivel`): the arm in the weapon costs far more than wrist bend past a graze of 0.015, and the frames that smoothing puts back into the wood are checked again.
- After the grips are chosen:
  - the free lead arm swings clear of the haft as one gesture (`clear_free_arm`);
  - the fist slides down the haft when the wood behind it, or the butt end, meets an arm, his hip or his belt (`slide_fist`);
  - the haft tips about the fist where it still sweeps through an arm (`tilt_haft`). Every candidate must keep both hands on the haft.
- His legs are solved before the weapon, which now keeps out of them as it keeps out of his body.
- Pinwheels (Flourish, Wheel of Heaven, Prayer Beads): the fist spins 0.25 further out to his right and 0.1 forward (`PINWHEEL_OUT`). The spin plane passed through his right upper arm on every turn and the butt through his thigh; tilting cannot clear wood that close to the fist.
- Heavy, phase 1: the lead hand lets go at 0.34-0.42 s instead of 0.47-0.55 s. Held longer, the butt swept through his left arm.

**Cloth (`skin_rig.py --cloth-only`, `ClothSim.luau`)**
- Volumes fitted to the real surface (a tapered radius per limb from the mesh, was one guessed radius). A new chest volume keeps the beard, hair and beads out of his chest.
- Each particle keeps out by what its whole patch of cloth needs, not only its own centre. The middles of links are kept out as well, twice on the last pass.
- Phase 1 keeps the wide guessed blousing below the knee (0.76). The fitted one let the coat's lower rows into his right knee and shin (20-67% of frames, same motion). Phase 2's torn robe does better with the fitted one.
- Same motion, old cloth -> new cloth (8 shots, summed share of frames with any garment through him): RESULT_ISO.
- `tools/test_cloth_sim.py`: phase 1 passes (rest drift 1.14). Phase 2 still settles 1.27 off the sculpt at rest, against the test's bound of 1.2, as it did before this pass. Limiting the firm clearance brought it to 1.20, but let the robe 30% further into his legs, so it was not kept.

RESULT_TABLE

Remaining from this pass: RESULT_REMAINING

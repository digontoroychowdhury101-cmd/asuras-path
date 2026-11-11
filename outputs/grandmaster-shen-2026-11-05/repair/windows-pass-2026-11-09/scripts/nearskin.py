# nearskin.py BAKEDDIR CLIP... : (Windows pass 2026-11-12) per frame of a saved bake, how deep each arm's "near" skin sits in his torso:
# arm skin that lay within 0.05 of the torso solid in the bind pose but outside it (sdf in [-0.05, 0)), which the validator leaves out
# (shen_lib._torso_free) and the review x-ray counts (results/xray_why.md). Printed beside the validator's own kind of skin (dense) and for
# the thinned samples the solver's passes weigh (rg.SKIN): the frames past 0.17 and the deepest. Measures only.
import os, sys, pickle
import numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L


def depth(rg, world, pose, dense, lo, hi):
    out = {}
    for side in ("Right", "Left"):
        m = 0.0
        for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
            W = world[part]
            P, mix = (rg.SKIN_FULL if dense else rg.SKIN)[part]
            B = np.zeros_like(P)
            for bone, wt in mix:
                wt = np.broadcast_to(np.asarray(wt, float), (len(P),))
                (Rb, ab), jb = (pose[bone], rg.JOINT[bone]) if bone in pose else ((W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3]), rg.JOINT[part])
                B += wt[:, None] * ((P - jb) @ Rb.T + ab)
            for t in ("UpperTorso", "LowerTorso"):
                rest = L.sdf_depth(rg, t, P)
                keep = (rest >= lo) & (rest < hi)
                if keep.any():
                    Wt = world[t]
                    m = max(m, float(L.part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], B[keep]).max()))
        out[side] = max(0.0, m)
    return out


D = sys.argv[1]
lib = {c.name: c for c in SC.library()}
for name in sys.argv[2:]:
    clip = lib["GrandmasterShen_" + name]
    rg = clip.rig
    baked = pickle.load(open("%s/%s.pkl" % (D, name), "rb"))
    rows = []
    for i, fr in enumerate(baked):
        world = fr[2]
        pose = L.pose_of(rg, world)
        near_d = depth(rg, world, pose, True, -0.05, 0.0)
        near_t = depth(rg, world, pose, False, -0.05, 0.0)
        free_d = depth(rg, world, pose, True, -1e9, -0.05)
        rows.append((i, near_d, near_t, free_d))
    for side in ("Right", "Left"):
        nd = [r[1][side] for r in rows]; nt = [r[2][side] for r in rows]; fd = [r[3][side] for r in rows]
        k = int(np.argmax(nd))
        past = [r[0] for r in rows if r[1][side] > 0.17]
        print("%-22s %s near dense %.3f f%d (thinned %.3f there, %.3f max) | counted skin %.3f | near past 0.17: %s"
              % (name, side[0], nd[k], k, nt[k], max(nt), max(fd), (",".join("f%d" % f for f in past)) or "-"))

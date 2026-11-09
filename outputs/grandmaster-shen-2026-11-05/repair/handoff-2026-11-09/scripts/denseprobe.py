# denseprobe.py CLIP F,F TAG=PKL ... : each arm's depth in the torso by the pipeline's measure (thinned skin, 0.05 bind margin) against the full surface
# sample (every point of surface_pN.npz) with the mesh check's bind rule (only skin already 0.03 inside at bind left out), per part, and the band
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name = sys.argv[1]; fr = [int(v) for v in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); rg = clip.rig
sk = np.load(ROOT + "/work/shen_import/surface_p%s.npz" % name[1]); bones = [str(b) for b in sk["bones"]]
FULL = {}
for part in ("RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"):
    P, W, B = sk[part + "_P"].astype(float), sk[part + "_W"].astype(float), sk[part + "_B"]
    FULL[part] = (P, [(bones[b], (W * (B == b)).sum(1)) for b in np.unique(B) if float((W * (B == b)).sum()) > 1e-6])
def pts(part, pose, src):
    P, mix = src[part]; out = np.zeros_like(P)
    for bone, w in mix:
        (Rb, ab), jb = (pose[bone], rg.JOINT[bone]) if bone in pose else (pose[part], rg.JOINT[part])
        out += w[:, None] * ((P - jb) @ Rb.T + ab)
    return out
for spec in sys.argv[3:]:
    tag, pk = spec.split("=", 1); out = pickle.load(open(pk, "rb"))
    for f in fr:
        world = out[f][2]; pose = L.pose_of(rg, world); row = []
        for side in ("Right", "Left"):
            best = (0, "", 0, 0)
            for part in (side + "UpperArm", side + "LowerArm", side + "Hand"):
                X = pts(part, pose, FULL)
                for t in ("UpperTorso", "LowerTorso"):
                    bind = L.sdf_depth(rg, t, FULL[part][0])
                    Wt = world[t]; d = L.part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], X)
                    for rule, keep in (("pipe0.05", bind < -0.05), ("mesh0.03", bind <= 0.03)):
                        if keep.any():
                            j = int(np.argmax(np.where(keep, d, -9))); 
                            if d[j] > best[0] and rule == "mesh0.03": best = (float(d[j]), part + ">" + t, float(bind[j]), rule)
                            row.append((side, part[len(side):], t[:-5], rule, round(float(d[keep].max()), 3)))
            pipe = L.arm_torso_world(rg, world)[side]
            print("%s f%d %s pipeline %.3f | full-sample mesh rule %.3f at %s (bind depth %.3f)" % (tag, f, side, pipe, best[0], best[1], best[2]))

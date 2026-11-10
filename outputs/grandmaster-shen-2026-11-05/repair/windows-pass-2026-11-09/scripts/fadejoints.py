# fadejoints.py BAKEDDIR CLIP in|out STEP : (Windows pass 2026-11-09) at one step of an Idle fade (fadeprobe.py's numbering), how far apart the two
# ends are joint by joint (each joint's own rotation relative to its parent, degrees, and the axis it turns about in the parent's frame), and which
# arm part is deepest in which torso part in the blend: the joints the blend swings the arm through his chest by.
import os, sys, pickle, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L

D, name, which, step = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
ph = int(name[1])
rg = L.Rig(ph)


def W(n):
    return [o[2] for o in pickle.load(open("%s/%s.pkl" % (D, n), "rb"))]


def at(frames, f):
    i = min(int(f), len(frames) - 1)
    return L.joint_mix(rg, frames[i], frames[min(i + 1, len(frames) - 1)], f - int(f))


idle, X = W("P%d_Idle" % ph), W(name)
k = int(round(0.6 * 30)) - 1
A, B = (idle[k:] + idle[:k], X) if which == "in" else (X[-1:] * 12, idle)
f = step / 60.0 * 30
wa, wb = at(A, f), at(B, f)
u = step / 9.0
for j in ["LowerTorso", "UpperTorso", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"]:
    p = rg.PARENT.get(j)
    la = np.linalg.inv(wa[p]) @ wa[j]
    lb = np.linalg.inv(wb[p]) @ wb[j]
    Rd = la[:3, :3].T @ lb[:3, :3]
    ang = float(np.degrees(np.arccos(np.clip((np.trace(Rd) - 1) / 2, -1, 1))))
    ax = np.array([Rd[2, 1] - Rd[1, 2], Rd[0, 2] - Rd[2, 0], Rd[1, 0] - Rd[0, 1]])
    ax = la[:3, :3] @ (ax / (np.linalg.norm(ax) + 1e-12))
    print("%-14s %6.1f deg about %s (parent frame)" % (j, ang, np.round(ax, 2)))
for uu in (0.0, 0.25, 0.4, 0.5, 0.6, 0.75, 1.0):
    w = L.joint_mix(rg, wa, wb, uu)
    pose = L.pose_of(rg, w)
    row = []
    for part in ("RightUpperArm", "RightLowerArm", "RightHand"):
        P, mix = rg.SKIN_FULL[part]
        Bp = np.zeros_like(P)
        for bone, wt in mix:
            (Rb, ab), jb = (pose[bone], rg.JOINT[bone]) if bone in pose else ((w[part][:3, :3], (w[part] @ np.append(rg.JOINT[part], 1))[:3]), rg.JOINT[part])
            Bp += wt[:, None] * ((P - jb) @ Rb.T + ab)
        for t in ("UpperTorso", "LowerTorso"):
            keep = L._torso_free(rg, part, t, True)
            Wt = w[t]
            d = L.part_depth(rg, t, Wt[:3, :3], (Wt @ np.append(rg.JOINT[t], 1))[:3], Bp[keep]) if keep.any() else np.zeros(1)
            row.append("%s/%s %.3f" % (part.replace("Right", "R"), t[:5], float(max(0.0, d.max()))))
    print("u %.2f  %s" % (uu, "  ".join(row)))

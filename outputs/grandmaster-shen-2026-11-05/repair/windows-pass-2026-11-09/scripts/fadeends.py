# fadeends.py BAKEDDIR PHASE : (Windows pass 2026-11-09) every clip's first and last frame against the Idle frames the game fades from and to
# (fadecheck2.py: Idle 0.6 s in for a fade in, Idle's start for a fade out): the right and left upper arm's own turn away from Idle's (degrees), and where
# each elbow and fist sit in his chest's frame (front -z, his right +x, up +y), so an Idle (or a clip end) that holds its arms unlike the rest shows.
import os, sys, pickle, glob, numpy as np
ROOT = os.environ.get("SHEN_ROOT") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L

D, ph = sys.argv[1], int(sys.argv[2])
rg = L.Rig(ph)


def W(n):
    return [o[2] for o in pickle.load(open("%s/%s.pkl" % (D, n), "rb"))]


def local(w, j):
    return (np.linalg.inv(w[rg.PARENT[j]]) @ w[j])[:3, :3]


def ang(Ra, Rb):
    Rd = Ra.T @ Rb
    return float(np.degrees(np.arccos(np.clip((np.trace(Rd) - 1) / 2, -1, 1))))


def inchest(w, part):
    U = w["UpperTorso"]
    a = (U @ np.append(rg.JOINT["UpperTorso"], 1))[:3]
    p = (w[part] @ np.append(rg.JOINT[part], 1))[:3]
    return U[:3, :3].T @ (p - a)


def fmt(v):
    return "(%5.2f %5.2f %5.2f)" % tuple(v)


idle = W("P%d_Idle" % ph)
k = int(round(0.6 * 30)) - 1
for lab, w in (("Idle@0.6", idle[k]), ("Idle@0", idle[0])):
    print("%-26s elbowR %s fistR %s elbowL %s" % (lab, fmt(inchest(w, "RightLowerArm")), fmt(inchest(w, "RightHand")), fmt(inchest(w, "LeftLowerArm"))))
for p in sorted(glob.glob(D + "/P%d_*.pkl" % ph)):
    n = os.path.basename(p)[:-4]
    if n.endswith("_Idle"):
        continue
    X = W(n)
    for lab, w, ref in (("first", X[0], idle[k]), ("last", X[-1], idle[0])):
        print("%-20s %-5s RUA %5.1f RLA %5.1f LUA %5.1f | elbowR %s fistR %s elbowL %s" % (n, lab, ang(local(w, "RightUpperArm"), local(ref, "RightUpperArm")), ang(local(w, "RightLowerArm"), local(ref, "RightLowerArm")),
                                                                                   ang(local(w, "LeftUpperArm"), local(ref, "LeftUpperArm")), fmt(inchest(w, "RightLowerArm")), fmt(inchest(w, "RightHand")), fmt(inchest(w, "LeftLowerArm"))))

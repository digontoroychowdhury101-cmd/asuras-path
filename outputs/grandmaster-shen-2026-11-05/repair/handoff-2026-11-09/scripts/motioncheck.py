"""Before/after on one exported clip: per part, peak angular speed and angular acceleration (deg/frame, deg/frame^2), wrist bend, the loop seam, and
the grip (fist on the haft, lead palm on the haft)."""
import sys, os, json, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast")
import shen_clips as SC, shen_lib as L
phase, name, A, B = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
clip = [c for c in SC.build(phase) if c.name.endswith("_" + name)][0]; rg = clip.rig
PARTS = ("RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand", "UpperTorso", "Glaive")
def ang(R):
    return np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1)))
def stats(path):
    d = json.load(open(path)); F = d["frames"]
    W = [{k: np.array(v).reshape(4, 4) for k, v in f["parts"].items()} for f in F]
    out = {}
    for p in PARTS:
        R = [w[p][:3, :3] for w in W]
        v = np.array([ang(R[i].T @ R[i + 1]) for i in range(len(R) - 1)])
        a = np.abs(np.diff(v))
        pos = np.array([w[p][:3, 3] for w in W]); pa = np.linalg.norm(pos[2:] - 2 * pos[1:-1] + pos[:-2], axis=1)
        out[p] = (v.max(), a.max(), pa.max())
    # wrist bend: hand relative to forearm
    wr = [ang(w["RightLowerArm"][:3, :3].T @ w["RightHand"][:3, :3]) for w in W]
    wl = [ang(w["LeftLowerArm"][:3, :3].T @ w["LeftHand"][:3, :3]) for w in W]
    seam = max(ang(W[0][p][:3, :3].T @ W[-1][p][:3, :3]) for p in PARTS)
    return out, (max(wr), max(wl)), seam, len(F)
sa, sb = stats(A), stats(B)
print("%-14s %28s | %28s" % ("part", "before: speed accel posacc", "after: speed accel posacc"))
for p in PARTS:
    print("%-14s %8.2f %8.2f %8.4f | %8.2f %8.2f %8.4f" % ((p,) + sa[0][p] + sb[0][p]))
print("wrist bend (right, left) max deg: before %.1f %.1f  after %.1f %.1f (WRIST_LIMIT %s)" % (sa[1] + sb[1] + (L.WRIST_LIMIT,)))
print("loop seam deg: before %.2f after %.2f; frames %d / %d" % (sa[2], sb[2], sa[3], sb[3]))

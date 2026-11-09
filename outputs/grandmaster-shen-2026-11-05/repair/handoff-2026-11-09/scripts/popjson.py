# popjson.py DIR [DIR2]: in exported frame JSON (root space), frames where a hand, forearm or the glaive (origin, and points 2.5 along each of its axes)
# goes out and comes straight back (both steps >= 0.3 rig units, turning by more than 120 deg). Same measure on both dirs, side by side.
import json, glob, os, sys, numpy as np
def pops(f):
    fr = json.load(open(f))["frames"]; n = len(fr)
    out = []
    for p in ("RightHand", "LeftHand", "RightLowerArm", "LeftLowerArm", "Glaive"):
        M = np.array([np.array(x["parts"][p]).reshape(4, 4) for x in fr])
        tracks = [M[:, :3, 3]] + ([M[:, :3, 3] + M[:, :3, k] * 2.5 for k in range(3)] if p == "Glaive" else [])
        for P in tracks:
            for i in range(1, n - 1):
                a, c = P[i] - P[i - 1], P[i + 1] - P[i]
                la, lc = np.linalg.norm(a), np.linalg.norm(c)
                if min(la, lc) < 0.3: continue
                if a @ c / (la * lc) < -0.5: out.append((min(la, lc), i, p))
    out.sort(reverse=True)
    return out
dirs = sys.argv[1:]
names = sorted(os.path.basename(f) for f in glob.glob(os.path.join(dirs[0], "GrandmasterShen_P*.json")))
tot = [0] * len(dirs)
for nm in names:
    cols = []
    for k, d in enumerate(dirs):
        f = os.path.join(d, nm)
        if not os.path.exists(f): cols.append("-"); continue
        r = [x for x in pops(f) if x[0] >= 0.5]
        tot[k] += len({x[1] for x in r})
        cols.append("%2d fr, worst %s" % (len({x[1] for x in r}), "%.2f f%d %s" % r[0] if r else "-"))
    print("%-28s %s" % (nm[16:-5], " | ".join("%-34s" % c for c in cols)))
print("frames with a >=0.5 out-and-back:", tot)

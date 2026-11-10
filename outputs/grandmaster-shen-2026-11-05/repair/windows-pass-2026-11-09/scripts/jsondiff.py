# jsondiff.py DIRA DIRB : (Windows pass 2026-11-10) how far each exported clip moved between two sets of frame JSON (root space, rig units: about
# 0.27 m each at his scale): per clip, the largest change over all frames of each hand, each forearm and the glaive tip/butt (points 2.5 along
# its haft both ways), with its frame, and the largest joint turn change. Says which re-exported clips really changed and which only drifted.
import json, glob, os, sys
import numpy as np

A, B = sys.argv[1], sys.argv[2]
PARTS = ("RightHand", "LeftHand", "RightLowerArm", "LeftLowerArm")
rows = []
for fb in sorted(glob.glob(os.path.join(B, "GrandmasterShen_P*.json"))):
    nm = os.path.basename(fb)
    fa = os.path.join(A, nm)
    if not os.path.exists(fa):
        continue
    ja, jb = json.load(open(fa))["frames"], json.load(open(fb))["frames"]
    if len(ja) != len(jb):
        rows.append((9.0, nm[16:-5], "frame count %d -> %d" % (len(ja), len(jb))))
        continue
    worst, where, turn = 0.0, "", 0.0
    for i, (x, y) in enumerate(zip(ja, jb)):
        for p in PARTS + ("Glaive",):
            if p not in x["parts"] or p not in y["parts"]:
                continue
            Ma, Mb = np.array(x["parts"][p]).reshape(4, 4), np.array(y["parts"][p]).reshape(4, 4)
            pts = [(Ma[:3, 3], Mb[:3, 3])]
            if p == "Glaive":
                pts += [(Ma[:3, 3] + Ma[:3, k] * s, Mb[:3, 3] + Mb[:3, k] * s) for k in range(3) for s in (2.5, -2.5)]
            for a, b in pts:
                d = float(np.linalg.norm(a - b))
                if d > worst:
                    worst, where = d, "%s f%d" % (p, i)
        for p in x["parts"]:
            if p in y["parts"]:
                Ra, Rb = np.array(x["parts"][p]).reshape(4, 4)[:3, :3], np.array(y["parts"][p]).reshape(4, 4)[:3, :3]
                c = (np.trace(Ra.T @ Rb) - 1.0) / 2.0
                turn = max(turn, float(np.degrees(np.arccos(np.clip(c, -1.0, 1.0)))))
    rows.append((worst, nm[16:-5], "moved up to %.3f (%s), joints up to %.1f deg" % (worst, where, turn)))
for w, n, s in sorted(rows, reverse=True):
    print("%-28s %s" % (n, s))

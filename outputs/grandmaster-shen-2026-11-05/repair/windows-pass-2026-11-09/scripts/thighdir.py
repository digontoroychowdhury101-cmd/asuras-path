# thighdir.py BAKEDDIR CLIP F0 F1 : (Windows pass 2026-11-11) where the glaive sits in his legs on F0..F1 of a saved bake, and which way it has to
# go to leave: per frame the deepest weapon sample inside a leg solid (every sample, as legsall.py), its distance along the haft from the right
# fist (+ toward the blade), the leg solid's outward direction there (the distance field's gradient), and the fist and haft direction, all in
# his own frame (x his right, y up, z forward negative, as ctmoves.py prints moves). Diagnostics only; writes nothing.
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle
import numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_lib as L

D, name, f0, f1 = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
baked = pickle.load(open("%s/%s.pkl" % (D, name), "rb"))
rg = L.Rig(int(name[1]))
EPS = 0.01


def leg_depth(world, part, P):
    W = world[part]
    return L.part_depth(rg, part, W[:3, :3], (W @ np.append(rg.JOINT[part], 1))[:3], P)


print("frame  leg             depth  along  out(his frame)        fist(his frame)        haft(his frame)")
for f in range(f0, min(f1, len(baked) - 1) + 1):
    t, local, world, diag, c = baked[f]
    Rr = world["HumanoidRootPart"][:3, :3]
    P = L.place(rg, world, "Weapon")
    best = None
    for part in L.LEG_SOLIDS:
        d = leg_depth(world, part, P)
        i = int(np.argmax(d))
        if d[i] > 0 and (best is None or d[i] > best[1]):
            best = (part, float(d[i]), i)
    fist = (world["RightHand"] @ np.append(rg.GRIP0, 1))[:3]
    haft = L.unit(np.asarray(c["haft"], float))
    root = world["HumanoidRootPart"][:3, 3]
    if best is None:
        print("f%-4d  clear" % f)
        continue
    part, dep, i = best
    p = P[i]
    g = np.array([(leg_depth(world, part, (p + e)[None])[0] - leg_depth(world, part, (p - e)[None])[0]) / (2 * EPS) for e in np.eye(3) * EPS])
    out = -L.unit(g)     # depth falls fastest this way: out of the leg
    along = float(np.dot(p - fist, haft))
    loc = lambda v: Rr.T @ v
    print("f%-4d  %-14s  %.3f  %+.2f  (%+.2f %+.2f %+.2f)    (%+.2f %+.2f %+.2f)    (%+.2f %+.2f %+.2f)" % (
        (f, part, dep, along) + tuple(loc(out)) + tuple(loc(fist - root)) + tuple(loc(haft))))

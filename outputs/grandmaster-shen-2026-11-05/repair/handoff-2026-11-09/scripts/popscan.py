# usage: popscan.py CLIP...  -> per clip: the worst frame where a hand/elbow/blade point leaves the midpoint of its neighbours (rig units)
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
lib = {c.name: c for c in SC.library()}
for name in sys.argv[1:]:
    clip = lib["GrandmasterShen_" + name]; rg = clip.rig
    pk = os.environ.get("PKL") or "%s/final_%s.pkl" % (S, name)
    if not os.path.exists(pk): print(name, "no pkl"); continue
    ctrl = pickle.load(open(pk, "rb"))
    clip._side = {}
    pts = []
    for c in ctrl:
        _l, world, _d = clip.solve(dict(c))
        row = []
        for part in ("RightHand", "LeftHand", "RightLowerArm", "LeftLowerArm"):
            row.append((world[part] @ np.append(rg.JOINT[part], 1))[:3])
        wp = L.place(rg, world, "Weapon"); row.append(wp[np.argmax(np.linalg.norm(wp - wp.mean(0), axis=1))] if False else wp.mean(0))
        pts.append(row)
    clip._side = None
    P = np.array(pts)    # n x 5 x 3
    n = len(P)
    lab = ("Rhand", "Lhand", "Relb", "Lelb", "weapon")
    if clip.loop:
        mid = 0.5 * (np.roll(P, 1, 0) + np.roll(P, -1, 0)); dev = np.linalg.norm(P - mid, axis=2)
    else:
        dev = np.zeros((n, 5)); dev[1:-1] = np.linalg.norm(P[1:-1] - 0.5 * (P[:-2] + P[2:]), axis=2)
    np.save(os.path.join(S, "pts_%s.npy" % name), P)
    i, j = np.unravel_index(np.argmax(dev), dev.shape)
    top = sorted(((dev[a, b], a, lab[b]) for a in range(n) for b in range(5)), reverse=True)[:4]
    print("%-24s worst %.3f at f%d %s | %s" % (name, dev[i, j], i, lab[j], " ".join("f%d %s %.2f" % (a, l, v) for v, a, l in top)), flush=True)

# usage: popkey.py CLIP...  -> frames where the bake's change to the weapon (final minus keyed: origin and a point 2.5 up the haft) jumps out and back
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
lib = {c.name: c for c in SC.library()}
def pts(rg, c):
    h = L.unit(np.asarray(c["haft"], float)); o = rg.weapon_origin(np.asarray(c["rp"], float), h, np.asarray(c["face"], float), float(c["rsl"]))
    return np.array([np.asarray(c["rp"], float), o + h * 2.5, o - h * 0.5])
for name in sys.argv[1:]:
    clip = lib["GrandmasterShen_" + name]; rg = clip.rig
    pk = os.environ.get("PKL") or "%s/final_%s.pkl" % (S, name)
    if not os.path.exists(pk): print(name, "no pkl"); continue
    fin = pickle.load(open(pk, "rb")); times = clip.frames(); key = [clip.controls(t) for t in times]
    D = np.array([pts(rg, f) - pts(rg, k) for f, k in zip(fin, key)])    # n x 3 x 3
    n = len(D)
    if clip.loop: sp = np.linalg.norm(D - 0.5 * (np.roll(D, 1, 0) + np.roll(D, -1, 0)), axis=2)
    else: sp = np.zeros((n, 3)); sp[1:-1] = np.linalg.norm(D[1:-1] - 0.5 * (D[:-2] + D[2:]), axis=2)
    top = sorted(((sp[i].max(), i, ("fist", "blade", "butt")[int(np.argmax(sp[i]))]) for i in range(n)), reverse=True)[:4]
    print("%-24s worst %.3f | %s" % (name, top[0][0], " ".join("f%d %s %.2f" % (i, l, v) for v, i, l in top)), flush=True)

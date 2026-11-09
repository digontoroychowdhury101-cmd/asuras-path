import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, lo, hi = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
out = clip.bake()
def deg(a, b): return np.degrees(np.arccos(np.clip(a @ b, -1, 1)))
prev = None
for i in range(lo, hi + 1):
    c = out[i][4]
    lt = L.unit(np.asarray(c["lt"], float))
    g = L.orth(L.unit(c["lpole"]), lt) if "lpole" in c else None
    k = L.orth(L.unit(c["lelb"]), lt)
    print("f%d hold %.2f reach %.2f carry %.2f  grip-pole vs keyed %s  lpole turn %s" % (i, c["lhw"], c["ltw"], c.get("_lcarry", -1), "%.0f" % deg(g, k) if g is not None else "-", "%.0f" % deg(L.unit(prev), L.unit(c["lpole"])) if prev is not None else "-"))
    prev = c.get("lpole")

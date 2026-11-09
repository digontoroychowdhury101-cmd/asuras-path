# keydiff.py DEVDIR CLIP...: largest per-frame difference of the keyed controls, repo vs DEVDIR (directions compared as unit vectors)
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
dev, names = sys.argv[1], sys.argv[2:]
def ctl(lib):
    out = {}
    for c in lib.library():
        s = c.name.replace("GrandmasterShen_", "")
        if s in names: out[s] = [c.controls(t) for t in c.frames()]
    return out
A = ctl(SC)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + dev); [sys.modules.pop(m) for m in ("shen_lib", "shen_clips")]; import shen_clips as SC2, shen_lib as L2
B = ctl(SC2)
for s in names:
    res = {}
    for k in A[s][0]:
        try:
            d = [np.linalg.norm((L.unit(np.asarray(a[k], float)) - L.unit(np.asarray(b[k], float))) if k in L.DIRECTION else (np.asarray(a[k], float) - np.asarray(b[k], float))) for a, b in zip(A[s], B[s])]
        except Exception: continue
        j = int(np.argmax(d))
        if d[j] > 0.02: res[k] = (round(float(d[j]), 3), j)
    print(s, res)

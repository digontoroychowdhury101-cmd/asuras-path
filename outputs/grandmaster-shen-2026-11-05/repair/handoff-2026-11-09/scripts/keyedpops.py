# keyedpops.py: one-frame out-and-back in the KEYED controls (face, haft point 2.5 up, rp), current channel() vs non-uniform tangents
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
def scan(clips):
    res = {}
    for clip in clips:
        T = clip.frames(); C = [clip.controls(t) for t in T]
        tr = {"face": np.array([L.unit(np.asarray(c["face"], float)) for c in C]), "blade": np.array([L.unit(np.asarray(c["haft"], float)) * 2.5 for c in C]),
              "rp": np.array([np.asarray(c["rp"], float) for c in C])}
        worst = {}
        for k, X in tr.items():
            d = [float(np.linalg.norm(X[i] - 0.5 * (X[i-1] + X[i+1]))) for i in range(1, len(X) - 1)]
            j = int(np.argmax(d)) if d else 0
            worst[k] = (round(d[j], 2), j + 1) if d else (0, 0)
        res[clip.name.replace("GrandmasterShen_", "")] = worst
    return res
before = scan(SC.library())
import keyfix  # noqa
after = scan(SC.library())
lim = {"face": 0.4, "blade": 0.6, "rp": 0.15}
for n in before:
    b, a = before[n], after[n]
    flag = [k for k in lim if b[k][0] > lim[k] or a[k][0] > lim[k]]
    if flag: print("%-22s " % n + "  ".join("%s %s -> %s" % (k, b[k], a[k]) for k in flag))

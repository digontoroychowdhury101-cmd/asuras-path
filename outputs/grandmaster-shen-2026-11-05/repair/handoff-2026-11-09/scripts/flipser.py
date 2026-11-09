import json, sys, numpy as np, os
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
S = (__import__("os").environ.get("SHEN_SCRATCH") or ROOT + "/work/shen_repair")
def ang(R): return np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1)))
def ser(path, h):
    F = json.load(open(path))["frames"]
    W = [{k: np.array(v).reshape(4, 4)[:3, :3] for k, v in fr["parts"].items()} for fr in F]
    out = []
    for i in range(1, len(W)):
        a = ang(W[i-1][h].T @ W[i][h]); b = ang((W[i-1]["Glaive"].T @ W[i-1][h]).T @ (W[i]["Glaive"].T @ W[i][h]))
        out.append((a, b))
    return out
n, h = sys.argv[1], sys.argv[2]
f = "GrandmasterShen_%s.json" % n
A = ser(os.path.join(S + "/bake_dc", f), h); B = ser(os.path.join(ROOT + "/work/opening_cast_bake/shen", f), h)
for i, (a, b) in enumerate(zip(A, B)):
    print("f%2d  dc world %6.1f haft %6.1f | now world %6.1f haft %6.1f" % (i + 1, a[0], a[1], b[0], b[1]))

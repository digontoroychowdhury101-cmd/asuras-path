# polishdbg.py CLIP CTRL.pkl : run joint_polish's windows on saved ctrl (stopat.py CLIP joint_polish) printing the baseline violated rows
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
from scipy.optimize import minimize as real
name = sys.argv[1]; d = pickle.load(open(sys.argv[2], "rb")); ctrl = d["ctrl"]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); times = clip.frames()
def wrap(fun, x0, jac=None, constraints=(), **k):
    c = constraints[0]; v = c["fun"](x0); J = c["jac"](x0)
    NV, NC = 8, 9
    for r in np.nonzero(v < 1e-4)[0]:
        print("row %d val %.4f |J| %.4f %s" % (r, v[r], np.abs(J[r]).max(), ("frame-row %d kind %d" % (r // NC, r % NC)) if r < len(x0) // NV * NC else "mid %d side %d" % ((r - len(x0) // NV * NC) // 2, r % 2)))
    res = real(fun, x0, jac=jac, constraints=constraints, **k)
    v1 = c["fun"](res.x); print("after", res.status, res.message, "viol rows", [(int(r), round(float(v1[r]), 4)) for r in np.nonzero(v1 < -1e-4)[0]])
    return res
sides, worlds, depth, mids = L._polish_sweep(clip, ctrl)
wall = L.ARM_TORSO_REST + L.TORSO_WALL
n = len(ctrl)
bad = sorted({i for i in range(1, n - 1) if depth[i] > wall} | {j for i in range(n - 1) if mids[i] > wall for j in (i, i + 1) if 0 < j < n - 1})
print("bad", bad, "depth", [round(x, 3) for x in depth[:12]], "mids", [round(x, 3) for x in mids[:12]])
A, B = max(0, bad[0] - L.POLISH_PAD), min(n - 1, bad[-1] + L.POLISH_PAD)
print(L._polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, wall - L.POLISH_MARGIN, wrap))

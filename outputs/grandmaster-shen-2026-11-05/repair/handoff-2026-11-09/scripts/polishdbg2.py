# polishdbg2.py CLIP BAKED.pkl [MAXITER] : rerun joint_polish's first window on a saved bake's controls, printing the rows violated at the start (and their
# Jacobian size) and after a short SLSQP run: what the solver is held by
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
from scipy.optimize import minimize as real
name = sys.argv[1]; out = pickle.load(open(sys.argv[2], "rb")); ctrl = [dict(o[4]) for o in out]
MAXIT = int(sys.argv[3]) if len(sys.argv) > 3 else 15
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); times = clip.frames()
NV, NC = 8, 9
KIND = ["torsoR", "torsoL", "clash", "arm_reach", "left_grip", "left_reach", "wristR", "wristL", "floor"]
def wrap(fun, x0, jac=None, constraints=(), options=None, **k):
    c = constraints[0]; v = c["fun"](x0); J = c["jac"](x0); nfr = len(x0) // NV
    def lab(r):
        return ("f+%d %s" % (r // NC, KIND[r % NC])) if r < nfr * NC else "pair %d %s" % ((r - nfr * NC) // 2, "RL"[r % 2])
    print("start violated:", [(lab(r), round(float(v[r]), 4), round(float(np.abs(J[r]).max()), 3)) for r in np.nonzero(v < 1e-4)[0]])
    o = dict(options or {}); o["maxiter"] = MAXIT
    res = real(fun, x0, jac=jac, constraints=constraints, options=o, **k)
    v1 = c["fun"](res.x)
    print("after", res.status, res.message, "violated:", [(lab(r), round(float(v1[r]), 4)) for r in np.nonzero(v1 < -1e-4)[0]])
    return res
sides, worlds, depth, mids, entry = L._polish_sweep(clip, ctrl)
wall = L.ARM_TORSO_REST + L.TORSO_WALL; n = len(ctrl)
bad = sorted({i for i in range(1, n - 1) if depth[i] > wall} | {j for i in range(n - 1) if mids[i] > wall for j in (i, i + 1) if 0 < j < n - 1})
print("bad", bad, "depth>0.15", [(i, round(d, 3)) for i, d in enumerate(depth) if d > 0.15], "mids>0.15", [(i, round(d, 3)) for i, d in enumerate(mids) if d > 0.15])
if bad:
    A, B = max(0, bad[0] - L.POLISH_PAD), min(n - 1, bad[-1] + L.POLISH_PAD)
    r = L._polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, entry, wall - L.POLISH_MARGIN, wrap)
    r.pop("message", None); print(r)

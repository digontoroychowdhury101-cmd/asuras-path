import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
D = os.path.dirname(os.path.abspath(__file__)) + "/dev3"
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); sys.path.insert(0, D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_P1_HesitantMoon"); times = clip.frames()
log = []
cb = clip.clear_body
def wrap(rp, haft, rsl, world):
    out = cb(rp, haft, rsl, world); log.append(np.round(out - rp, 2)); return out
clip.clear_body = wrap
clip._side = {}
a, b = [int(x) for x in os.environ.get("FR", "10:45").split(":")]
for i in range(a, b):
    log.clear()
    k = clip.controls(times[i]); c = dict(k); clip.solve(c)
    print("f%d keyed rp %s haft %s | solved rp %s | cb1 %s cb2 %s" % (i, np.round(k["rp"], 2), np.round(L.unit(k["haft"]), 2), np.round(c["rp"], 2), log[0], log[1] if len(log) > 1 else None))

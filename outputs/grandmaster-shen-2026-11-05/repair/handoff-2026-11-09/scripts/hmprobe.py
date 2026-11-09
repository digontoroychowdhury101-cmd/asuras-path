import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
D = os.path.dirname(os.path.abspath(__file__)) + "/dev3"
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); sys.path.insert(0, D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_P1_HesitantMoon"); times = clip.frames()
clip._side = {}
prev = None; worst = 0; out = []
for i in range(10, 45):
    k = clip.controls(times[i]); c = dict(k); clip.solve(c)
    dv = np.asarray(c["rp"]) - np.asarray(k["rp"])
    jump = 0 if prev is None else float(np.linalg.norm(dv - prev))
    prev = dv; worst = max(worst, jump)
    out.append("f%d push %.2f jump %.2f" % (i, np.linalg.norm(dv), jump))
clip._side = None
jf = max(range(len(out)), key=lambda j: float(out[j].split("jump ")[1])); mp = max(float(o.split("push ")[1].split()[0]) for o in out[15:]) ; print(os.environ.get("TAG",""), "worst jump %.2f (%s) max push f25+ %.2f" % (worst, out[jf].split()[0], mp))
if os.environ.get("V"): print("\n".join(out))

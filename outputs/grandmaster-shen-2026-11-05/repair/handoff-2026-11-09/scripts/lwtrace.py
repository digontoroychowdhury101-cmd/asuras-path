# lwtrace.py CLIP F0 F1 : bake CLIP (to close_loop); after every stage the left wrist angle on the arm, the left pole and the lead hand's palm axis on frames F0..F1
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
os.environ["SHEN_JOINT_POLISH"] = "0"
import shen_clips as SC, shen_lib as L
name, F0, F1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
def show(tag, ctrl):
    keep = clip._side; clip._side = {}
    try:
        row = []
        for f in range(F0, F1 + 1):
            loc = clip.solve(dict(ctrl[f]))[0]
            row.append("%d:%3.0f %s" % (f, L.ZR.angle_of(loc["LeftHand"][:3, :3]), np.round(ctrl[f].get("lpole", ctrl[f].get("lelb")), 1).tolist()))
        print("%-15s %s" % (tag, " | ".join(row)), flush=True)
    finally:
        clip._side = keep
class Stop(Exception): pass
for _st in ("organic", "spine_reach", "settle", "swivel", "wrist_yield", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop"):
    _f = getattr(L, _st)
    def _w(*a, _f=_f, _n=_st, **k):
        r = _f(*a, **k)
        show(_n, a[2] if _n == "organic" else a[1])
        if _n == "close_loop": raise Stop
        return r
    setattr(L, _st, _w)
try:
    clip.bake()
except Stop:
    pass

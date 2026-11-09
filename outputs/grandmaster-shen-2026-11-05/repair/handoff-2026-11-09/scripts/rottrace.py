# rottrace.py CLIP N : bake CLIP and after every stage the right upper arm's and hand's own turn (local rotation) frame to frame over f0..N
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, N = sys.argv[1], int(sys.argv[2])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
def ang(R): return float(np.degrees(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1))))
def show(tag, ctrl):
    keep = clip._side; clip._side = {}
    try:
        loc = [clip.solve(dict(ctrl[f]))[0] for f in range(N + 1)]
        ua = [round(ang(loc[i]["RightUpperArm"][:3, :3].T @ loc[i + 1]["RightUpperArm"][:3, :3])) for i in range(N)]
        ha = [round(ang(loc[i]["RightHand"][:3, :3].T @ loc[i + 1]["RightHand"][:3, :3])) for i in range(N)]
        po = [np.round(ctrl[f].get("rpole", ctrl[f].get("relb")), 2).tolist() for f in range(N + 1)]
        print("%-15s upperarm %s sum %d | hand %s | pole %s" % (tag, ua, sum(ua), ha, po), flush=True)
    finally:
        clip._side = keep
show("keyed", [clip.controls(t) for t in clip.frames()])
for _st in ("organic", "spine_reach", "settle", "swivel", "clear_free_arm", "clear_torso", "slide_fist", "tilt_haft", "depop", "close_loop", "joint_polish"):
    _f = getattr(L, _st)
    def _w(*a, _f=_f, _n=_st, **k):
        r = _f(*a, **k)
        show(_n, a[2] if _n == "organic" else a[1])
        return r
    setattr(L, _st, _w)
out = clip.bake()

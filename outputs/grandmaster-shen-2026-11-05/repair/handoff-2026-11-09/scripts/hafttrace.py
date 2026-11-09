# hafttrace.py CLIP F,F : bake CLIP; after every stage the controls' haft line and fist, and the solved haft (Glaive's axis), for the given frames
import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, frs = sys.argv[1], [int(x) for x in sys.argv[2].split(",")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
def show(tag, ctrl):
    keep = clip._side; clip._side = {}
    try:
        row = []
        for f in frs:
            c = dict(ctrl[f]); w = clip.solve(c)[1]
            ax = w["Glaive"][:3, :3] @ clip.rig.HAFT0
            row.append("f%d haft %s solved %s" % (f, np.round(np.asarray(ctrl[f]["haft"], float) / np.linalg.norm(ctrl[f]["haft"]), 2).tolist(), np.round(ax, 2).tolist()))
        print("%-15s %s" % (tag, " | ".join(row)), flush=True)
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

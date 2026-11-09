# seedtest.py CLIP BAKED.pkl A B : joint_polish's seeded retry alone on a saved bake's controls, window A..B; saves the polished controls' bake
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle, numpy as np
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
from scipy.optimize import minimize
name = sys.argv[1]; out = pickle.load(open(sys.argv[2], "rb")); ctrl = [dict(o[4]) for o in out]; A, B = int(sys.argv[3]), int(sys.argv[4])
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); times = clip.frames()
sides, worlds, depth, mids, entry = L._polish_sweep(clip, ctrl)
wall = L.ARM_TORSO_REST + L.TORSO_WALL
r = L._polish_window(clip, ctrl, times, A, B, sides, worlds, depth, mids, entry, wall - L.POLISH_MARGIN, minimize, seed=True)
r.pop("message", None); print(r, flush=True)
sides, worlds, depth, mids, entry = L._polish_sweep(clip, ctrl)
print("after: depth>0.15", [(i, round(d, 3)) for i, d in enumerate(depth) if d > 0.15], "mids>0.15", [(i, round(d, 3)) for i, d in enumerate(mids) if d > 0.15])
pickle.dump({"ctrl": ctrl}, open(os.path.dirname(os.path.abspath(__file__)) + "/seedtest_%s_%d_%d.pkl" % (name, A, B), "wb"))

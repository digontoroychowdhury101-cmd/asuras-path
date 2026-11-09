import sys, os, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT); os.environ["SHEN_DEBUG_TORSO"] = "1"
import shen_clips as SC, shen_lib as L
name = sys.argv[1]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
# run the bake up to clear_torso, then the pass with prints, stop after
real = L.clear_torso
def stop(clip_, ctrl, times, **k):
    real(clip_, ctrl, times, **k); raise SystemExit
L.clear_torso = stop
clip.bake()

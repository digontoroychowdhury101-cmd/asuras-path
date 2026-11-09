# stopat.py CLIP STAGE OUT.pkl : bake CLIP (DEV honoured) and pickle ctrl as it enters STAGE, then stop
import sys, os, pickle
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
D = os.environ.get("DEV")
if D: sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/" + D)
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
name, st, outp = sys.argv[1:4]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
class Stop(Exception): pass
def grab(*a, **k):
    pickle.dump({"ctrl": a[1], "side": clip._side}, open(outp, "wb")); raise Stop()
setattr(L, st, grab)
try: clip.bake()
except Stop: print("saved", outp)

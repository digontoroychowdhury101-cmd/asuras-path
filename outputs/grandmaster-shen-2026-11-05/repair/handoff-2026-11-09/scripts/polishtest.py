# polishtest.py CLIP BAKED.pkl : joint_polish (final code: retries, seeded start, in-order acceptance) on a saved bake's controls; prints each window
# report and the validator's problems before and after
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, pickle
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L, castlib as C
name = sys.argv[1]; out = pickle.load(open(sys.argv[2], "rb")); ctrl = [dict(o[4]) for o in out]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name); times = clip.frames()
val = getattr(SC, "validate", C.validate)
print("before", val(clip, L._solved(clip, ctrl, times))[1], flush=True)
rep = L.joint_polish(clip, ctrl, times)
o = L._solved(clip, ctrl, times); L.derive_helpers(clip, o)
print("after", val(clip, o)[1], flush=True)

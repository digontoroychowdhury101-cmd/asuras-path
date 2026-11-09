# revalidate.py BAKEDDIR [CLIP ...] : the repo's validate (as export runs it) on saved bakes, one line per clip
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
import sys, os, glob, pickle, time
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao"); os.chdir(ROOT)
import shen_clips as SC, castlib as C
val = getattr(SC, "validate", C.validate)
D = sys.argv[1]
names = sys.argv[2:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(D + "/P*.pkl"))
lib = {c.name: c for c in SC.library()}
for name in names:
    t0 = time.time()
    clip = lib["GrandmasterShen_" + name]
    s, p = val(clip, pickle.load(open("%s/%s.pkl" % (D, name), "rb")))
    print("%-24s R %.3f L %.3f entry %.3f/%.3f between R %s L %s | %s  (%.0fs)" % (name, s.get("arm_in_torso_right", 0), s.get("arm_in_torso_left", 0), s.get("arm_in_torso_entry_right", 0), s.get("arm_in_torso_entry_left", 0), s.get("arm_in_torso_between_right"),
          s.get("arm_in_torso_between_left"), p, time.time() - t0), flush=True)

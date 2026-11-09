import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
name = sys.argv[1]; a, b = [int(x) for x in sys.argv[2].split(":")]
clip = next(c for c in SC.library() if c.name == "GrandmasterShen_" + name)
fin = pickle.load(open("%s/final_%s.pkl" % (S, name), "rb")); times = clip.frames()
print("contacts", clip.contacts, "active", clip.active)
for i in range(a, b + 1):
    k = clip.controls(times[i]); c = fin[i]
    F, K = L.pop_tracks(c), L.pop_tracks(k)
    ex = L.pop_excess(np.array([L.pop_tracks(fin[j]) for j in range(len(fin))]), np.array([L.pop_tracks(clip.controls(times[j])) for j in range(len(fin))]), i, i - 1, i + 1) if 0 < i < len(fin) - 1 else None
    print("f%-3d t%.3f fistF %s fistK %s rslF %.2f rslK %.2f excess %s" % (i, times[i], np.round(F[:3], 2), np.round(K[:3], 2), F[6], K[6], np.round(ex, 2) if ex is not None else "-"))

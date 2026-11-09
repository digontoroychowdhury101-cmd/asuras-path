# bake_pops on saved final pkls (re-solved): popcheck_pkl.py CLIP...
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
lib = {c.name: c for c in SC.library()}
for name in sys.argv[1:]:
    clip = lib["GrandmasterShen_" + name]
    fin = pickle.load(open("%s/final_%s.pkl" % (S, name), "rb")); times = clip.frames()
    baked = [[t, None, None, None, c] for t, c in zip(times, fin)]
    p = L.bake_pops(clip, baked)
    bad = {k: v for k, v in p.items() if v[0] > L.POP_LIMIT[k]}
    print("%-24s %s %s" % (name, " ".join("%s %.2f@f%d" % (k, v[0], v[1]) for k, v in p.items()), "POP" if bad else ""), flush=True)

import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
S = os.path.dirname(os.path.abspath(__file__))
lib = {c.name: c for c in SC.library()}
for name in sys.argv[1:]:
    clip = lib["GrandmasterShen_" + name]
    pk = "%s/final_%s.pkl" % (S, name)
    if not os.path.exists(pk): continue
    fin = pickle.load(open(pk, "rb")); times = clip.frames(); key = [clip.controls(t) for t in times]
    d = np.array([np.asarray(f["chest"], float) - np.asarray(k["chest"], float) for f, k in zip(fin, key)])
    i = int(np.argmax(np.abs(d[:, 1]))); j = int(np.argmax(np.abs(d[:, 0])))
    print("%-24s yaw+ %6.1f (f%d) pitch+ %6.1f (f%d) frames>25yaw %d >14pitch %d" % (name, d[i, 1], i, d[j, 0], j, int((np.abs(d[:, 1]) > 25.5).sum()), int((np.abs(d[:, 0]) > 14.5).sum())))

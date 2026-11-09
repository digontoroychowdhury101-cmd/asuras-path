# facepop.py DIR [names]: blade roll (face vector square to the haft) leaving its neighbours' midpoint, final minus keyed, per clip
import sys, os, pickle, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
sys.path.insert(0, ROOT + "/tools/animation/opening_cast"); sys.path.insert(0, ROOT + "/tools/animation/general_zhao")
d = os.path.abspath(sys.argv[1]); os.chdir(ROOT)
import shen_clips as SC, shen_lib as L
names = sys.argv[2:] or sorted(f[:-4] for f in os.listdir(d))
lib = {c.name.replace("GrandmasterShen_", ""): c for c in SC.library()}
tot = 0
for n in names:
    clip = lib[n]; out = pickle.load(open(os.path.join(d, n + ".pkl"), "rb"))
    F = np.array([L.unit(np.asarray(o[4]["face"], float)) for o in out]); K = np.array([L.unit(np.asarray(clip.controls(o[0])["face"], float)) for o in out])
    held = [float(o[4].get("wfree", 0)) < 0.01 for o in out]
    bad = []
    for i in range(1, len(out) - 1):
        if clip.loop is False and not (held[i-1] and held[i] and held[i+1]): continue
        e = np.linalg.norm(F[i] - 0.5 * (F[i-1] + F[i+1])) - np.linalg.norm(K[i] - 0.5 * (K[i-1] + K[i+1]))
        if e > 0.3: bad.append((round(float(e), 2), i))
    if bad:
        tot += 1
        print("%-22s %d frames, worst %s" % (n, len(bad), max(bad)), sorted(bad, key=lambda x: x[1])[:8])
print("clips with a roll pop > 0.3:", tot)

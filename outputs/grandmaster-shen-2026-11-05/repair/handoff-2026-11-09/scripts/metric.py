import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import skinlib as L
ph = int(sys.argv[1]); names = sys.argv[2:]
sm = L.load_samples(ph); g = np.array([s["g"] for s in sm]); sdf = L.load_sdf(ph)
for name in names:
    fr = L.shot(name)["frames"]; P = L.skin(sm, fr)
    acc = np.linalg.norm(P[2:] - 2 * P[1:-1] + P[:-2], axis=2)
    D = np.zeros((len(fr), len(sm)))
    for f in range(0, len(fr), 2):
        for p in sdf:
            D[f] = np.maximum(D[f], L.depth(sdf[p], L.to_rest(P[f], fr[f], p)))
    deep = D.max(1)
    print("%-20s depth max %.3f, frames>0.03 %3d | jitter " % (name, deep.max(), (deep[::2] > 0.03).sum()) + " ".join("%s %.3f/%.3f" % (gg[:5], np.median(acc[:, g == gg].max(1)), acc[:, g == gg].max()) for gg in sorted(set(g))))

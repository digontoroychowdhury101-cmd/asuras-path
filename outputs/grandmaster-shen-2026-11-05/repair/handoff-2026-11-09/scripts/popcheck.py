"""Popping check: per frame, the largest frame-to-frame acceleration of the drawn garment samples and of the cloth bones (rig units / frame^2)."""
import sys, os, numpy as np, json
sys.path.insert(0, os.path.dirname(__file__))
import skinlib as L
ph = int(sys.argv[1][1]); names = sys.argv[1:]
sm = L.load_samples(ph)
g = np.array([s["g"] for s in sm])
for name in names:
    fr = L.shot(name)["frames"]
    P = L.skin(sm, fr)
    acc = np.linalg.norm(P[2:] - 2 * P[1:-1] + P[:-2], axis=2)      # (F-2, N)
    vel = np.linalg.norm(P[1:] - P[:-1], axis=2)
    a = acc.max(1)
    print("%-22s sample accel: median %.4f  p99 %.4f  max %.4f (frame %d)  | speed max %.4f  | mean accel %.5f" % (name, np.median(a), np.percentile(a, 99), a.max(), a.argmax() + 1, vel.max(), acc.mean()))

"""Where a garment's skinned surface samples go inside his body parts in baked shots, by the parts' real signed distance fields (sdf_p2.npz), in each part's rest space."""
import json, os, sys, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
os.chdir(ROOT)
phase = 2
group = os.environ.get("GROUP", "Beard")
sdf = np.load("work/shen_import/sdf_p%d.npz" % phase)
def sample(part, X):
    G, o, st = sdf[part + "_grid"], sdf[part + "_origin"], float(sdf[part + "_step"])
    f = (X - o) / st
    i0 = np.floor(f).astype(int); t = f - i0
    out = np.zeros(len(X))
    sh = np.array(G.shape)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                idx = np.clip(i0 + (dx, dy, dz), 0, sh - 1)
                w = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                out += w * G[idx[:, 0], idx[:, 1], idx[:, 2]]
    outside = ((f < 0) | (f > sh - 1)).any(1)
    out[outside] = 0.5
    return out
samples = json.load(open(os.environ.get("SAMPLES", "work/shen_import/clothskin_p2.json")))["samples"]
sm = [s for s in samples if s["g"] == group]
Vs = np.array([s["v"] for s in sm])
parts = sys.argv[2].split(",")
rest_d = {p: sample(p, Vs) for p in parts}      # the sculpt's own overlaps (a beard lying on the chest) do not count
for shot in sys.argv[1].split(","):
    frames = json.load(open("work/opening_cast_bake/shen_shots/%s.json" % shot))["frames"]
    worst = {}
    share = {p: 0 for p in parts}
    for fi, fr in enumerate(frames):
        B = fr["bones"]
        X = np.zeros((len(sm), 3))
        for k, s in enumerate(sm):
            for b, w in s["w"]:
                v = B[b]; R = np.array(v[:9]).reshape(3, 3); X[k] += w * (R @ Vs[k] + np.array(v[9:12]))
        for part in parts:
            v = B["Sk_" + part]; R = np.array(v[:9]).reshape(3, 3); T = np.array(v[9:12])
            L = (X - T) @ R
            depth = -sample(part, L)
            depth[rest_d[part] < -0.03] = 0.0
            k = int(depth.argmax())
            if depth[k] > 0.03: share[part] += 1
            if depth[k] > worst.get(part, (0,))[0]:
                worst[part] = (float(depth[k]), fi, k, np.round(Vs[k], 2), np.round(L[k], 2), int((depth > 0.03).sum()), [w for w in sm[k]["w"]])
            if os.environ.get("ALL") and depth[k] > 0.1:
                print("   %s f%d %s %.3f sample %d rest %s at %s (%d >0.03)" % (shot, fi, part, depth[k], k, np.round(Vs[k], 2), np.round(L[k], 2), int((depth > 0.03).sum())))
    for part, w in worst.items():
        print("%s %s in %s: %.3f at frame %d (%d of %d frames), sample %d rest %s -> part-rest %s; %d samples >0.03; w %s" % (shot, group, part, w[0], w[1], share[part], len(frames), w[2], w[3], w[4], w[5], w[6]))

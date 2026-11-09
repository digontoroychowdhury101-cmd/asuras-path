"""Skin samples near a rest point: their weights, their capsule clearance rule, and at a frame their capsule depth vs the real (SDF) depth."""
import json, sys, numpy as np
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
shot, f, cdir, limb = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
X = np.array([float(v) for v in sys.argv[5].split(",")])
data = json.load(open(ROOT + "/work/opening_cast_bake/shen_shots/%s.json" % shot)); phase = data["phase"]; fr = data["frames"][f]
cloth = json.load(open(cdir + "/cloth_p%d.json" % phase)); sm = json.load(open(cdir + "/clothskin_p%d.json" % phase))["samples"]
cols = cloth["colliders"]
B = {k: (np.array(v[:9]).reshape(3, 3), np.array(v[9:12])) for k, v in fr["bones"].items()}
sd = np.load(ROOT + "/work/shen_import/sdf_p%d.npz" % phase); grid, lo, st = sd[limb + "_grid"], sd[limb + "_origin"], float(sd[limb + "_step"])
def depth(P):
    q = (P - lo) / st; n = np.array(grid.shape) - 1; i0 = np.clip(np.floor(q).astype(int), 0, n - 1); fq = np.clip(q - i0, 0, 1); v = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                v += (fq[0] if dx else 1 - fq[0]) * (fq[1] if dy else 1 - fq[1]) * (fq[2] if dz else 1 - fq[2]) * grid[i0[0] + dx, i0[1] + dy, i0[2] + dz]
    return -v if not np.any((q < 0) | (q > n)) else -1.0
Rl, tl = B["Sk_" + limb]
caps = [(ci, c) for ci, c in enumerate(cols) if c.get("limb") == limb]
for k, s in sorted(enumerate(sm), key=lambda ks: np.linalg.norm(np.array(ks[1]["v"]) - X))[:6]:
    v = np.array(s["v"])
    if np.linalg.norm(v - X) > 0.25: break
    S = sum(x * (B[n][0] @ v + B[n][1]) for n, x in s["w"])
    Q = Rl.T @ (S - tl)
    line = "sample %d %s dist %.2f w %s | rest sdf %+.3f now sdf %+.3f |" % (k, s["g"], np.linalg.norm(v - X), [(n, x) for n, x in s["w"]], depth(v), depth(Q))
    for ci, c in caps:
        a, b = np.array(c["a"]), np.array(c["b"]); d = b - a
        def cd(P):
            u = float(np.clip((P - a) @ d / (d @ d), 0, 1)); r = c["r"] + (c.get("rb", c["r"]) - c["r"]) * u
            return np.linalg.norm(P - a - u * d), r
        d0, r0 = cd(v); d1, r1 = cd(Q)
        hr = min(0.02, (d0 - r0) * 0.985) if d0 >= r0 else d0 * 0.985 - r0
        line += " cap%d rest d-r %+.3f need %+.3f now d-r %+.3f" % (ci, d0 - r0, hr, d1 - r1)
    print(line)

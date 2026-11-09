"""numpy skinning of the clothskin samples from a baked shot: positions per frame, capsule distances, SDF depth."""
import json, numpy as np, sys
import os as _os; ROOT = _os.environ.get("SHEN_ROOT") or _os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "../../../../.."))
def load_samples(phase):
    return json.load(open(ROOT + "/work/shen_import/clothskin_p%d.json" % phase))["samples"]
def shot(name, suffix=""):
    return json.load(open(ROOT + "/work/opening_cast_bake/shen_shots/%s%s.json" % (name, suffix)))
def skin(samples, frames):
    """(F, N, 3) skinned sample positions in root space."""
    bones = sorted({b for s in samples for b, _ in s["w"]})
    bi = {b: i for i, b in enumerate(bones)}
    V = np.array([s["v"] for s in samples])
    N = len(samples)
    Wm = np.zeros((N, 4)); Bm = np.zeros((N, 4), int)
    for k, s in enumerate(samples):
        for j, (b, w) in enumerate(s["w"]):
            Wm[k, j] = w; Bm[k, j] = bi[b]
    out = np.zeros((len(frames), N, 3))
    for f, fr in enumerate(frames):
        R = np.zeros((len(bones), 3, 3)); T = np.zeros((len(bones), 3))
        for b, i in bi.items():
            v = fr["bones"].get(b)
            if v is None:
                R[i] = np.eye(3); continue
            R[i] = np.array(v[:9]).reshape(3, 3); T[i] = v[9:12]
        for j in range(4):
            out[f] += Wm[:, j, None] * (np.einsum("nij,nj->ni", R[Bm[:, j]], V) + T[Bm[:, j]])
    return out
def to_rest(P, fr, limb):
    v = fr["bones"]["Sk_" + limb]; R = np.array(v[:9]).reshape(3, 3); t = np.array(v[9:12])
    return (P - t) @ R
def capdist(Q, c):
    a, b = np.array(c["a"]), np.array(c["b"]); d = b - a
    u = np.clip((Q - a) @ d / max(d @ d, 1e-9), 0, 1)
    return np.linalg.norm(Q - a - np.outer(u, d), axis=1), u, c["r"] + (c["rb"] - c["r"]) * u
def load_sdf(phase):
    d = np.load(ROOT + "/work/shen_import/sdf_p%d.npz" % phase)
    return {k[:-5]: (d[k], d[k[:-5] + "_origin"], float(d[k[:-5] + "_step"])) for k in d.files if k.endswith("_grid")}
def depth(sdf, P):
    grid, lo, st = sdf
    q = (P - lo) / st
    n = np.array(grid.shape) - 1
    i0 = np.clip(np.floor(q).astype(int), 0, n - 1)
    f = np.clip(q - i0, 0.0, 1.0)
    v = np.zeros(len(P))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                v += w * grid[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
    v[np.any((q < 0) | (q > n), axis=1)] = 1.0
    return -v

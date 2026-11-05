"""Label every triangle of a fused Shen sculpt with the bone that carries it. No triangle is created, moved or removed here.

Seed volumes mark what certainly belongs to each bone, using position and the sculpt's own painted materials; a priority flood over the surface assigns the rest, and
crossing a colour boundary or concave crease is cheap, so cuts settle along trim edges and folds rather than across open cloth.

    python3 tools/blender/shen_import/segment.py [1 2]
Writes work/shen_import/labels_p<n>.npy and work/shen_import/labelled_p<n>.glb (one node per bone, for views.py).
"""
import colorsys
import heapq
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path[:0] = [HERE, os.path.join(ROOT, "tools/blender/bull_import")]
import glb  # noqa: E402
import rigspace as RS  # noqa: E402
import landmarks as LM  # noqa: E402


def source(phase):
    return os.path.join(ROOT, f"assets/source/bosses/grandmaster_shen/Grandmaster-Shen-Phase-{phase}-PBR.glb")


def sample_colour(g, phase):
    """Mean base colour of each triangle, plus hue, saturation, value."""
    tex = np.load(os.path.join(ROOT, f"work/shen_import/tex_p{phase}_color.npy"))
    h, w = tex.shape[:2]
    uv = g.uv[g.idx].mean(1)
    px = tex[np.clip((uv[:, 1] * h).astype(int), 0, h - 1), np.clip((uv[:, 0] * w).astype(int), 0, w - 1)].astype(np.float64) / 255
    mx, mn = px.max(1), px.min(1)
    v = mx
    s = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    d = np.maximum(mx - mn, 1e-6)
    r, gg, b = px[:, 0], px[:, 1], px[:, 2]
    hue = np.where(mx == r, ((gg - b) / d) % 6, np.where(mx == gg, (b - r) / d + 2, (r - gg) / d + 4)) * 60
    return px, hue, s, v


def adjacency(g, ids):
    t = ids[g.idx]
    e = np.concatenate((t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]))
    e.sort(axis=1)
    tri = np.tile(np.arange(len(t)), 3)
    key = e[:, 0] * (ids.max() + 1) + e[:, 1]
    o = np.argsort(key, kind="stable")
    key, tri = key[o], tri[o]
    same = np.nonzero(key[1:] == key[:-1])[0]
    return tri[same], tri[same + 1]


def flood(cen, a, b, w, lab, limits):
    n = len(cen)
    deg = np.bincount(np.concatenate((a, b)), minlength=n)
    start = np.zeros(n + 1, np.int64)
    start[1:] = np.cumsum(deg)
    nb, wt = np.zeros(start[-1], np.int64), np.zeros(start[-1])
    fill = start[:-1].copy()
    for x, y, c in zip(a.tolist(), b.tolist(), w.tolist()):
        nb[fill[x]], wt[fill[x]] = y, c
        fill[x] += 1
        nb[fill[y]], wt[fill[y]] = x, c
        fill[y] += 1
    dist = np.full(n, np.inf)
    seeded = np.nonzero(lab >= 0)[0]
    dist[seeded] = 0
    heap = [(0.0, int(t)) for t in seeded]
    heapq.heapify(heap)
    lab_l, dist_l, nb_l, wt_l, st = lab.tolist(), dist.tolist(), nb.tolist(), wt.tolist(), start.tolist()
    while heap:
        dd, t = heapq.heappop(heap)
        if dd > dist_l[t]:
            continue
        la = lab_l[t]
        lim = limits.get(la)
        for k in range(st[t], st[t + 1]):
            o = nb_l[k]
            if lim is not None and not lim[o]:
                continue
            nd = dd + wt_l[k]
            if nd < dist_l[o]:
                dist_l[o], lab_l[o] = nd, la
                heapq.heappush(heap, (nd, o))
    return np.array(lab_l), nb_l, st


def despeckle(lab, a, b, keep, small=400):
    """A small connected island of one bone inside another joins what it borders most. `keep` labels are exempt (beads, weapon)."""
    n = len(lab)
    for _ in range(3):
        parent = np.arange(n)

        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x
        same = lab[a] == lab[b]
        for x, y in zip(a[same].tolist(), b[same].tolist()):
            rx, ry = find(x), find(y)
            if rx != ry:
                parent[ry] = rx
        root = np.fromiter((find(t) for t in range(n)), np.int64, n)
        size = np.bincount(root, minlength=n)
        border = {}
        for x, y in zip(a[~same].tolist(), b[~same].tolist()):
            rx, ry = root[x], root[y]
            if size[rx] < small:
                border.setdefault(rx, {}).setdefault(lab[y], 0)
                border[rx][lab[y]] += 1
            if size[ry] < small:
                border.setdefault(ry, {}).setdefault(lab[x], 0)
                border[ry][lab[x]] += 1
        changed = 0
        for r, counts in border.items():
            if lab[r] in keep:
                continue
            lab[root == r] = max(counts, key=counts.get)
            changed += 1
        if not changed:
            break
    return lab


def main_islands(lab, a, b, keep, minimum=1500):
    """A bone's triangles must be one body: any connected island that is not its bone's largest and is under `minimum` triangles joins what it borders, so nothing floats off when the bone moves."""
    n = len(lab)
    parent = np.arange(n)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    same = lab[a] == lab[b]
    for x, y in zip(a[same].tolist(), b[same].tolist()):
        rx, ry = find(x), find(y)
        if rx != ry:
            parent[ry] = rx
    root = np.fromiter((find(t) for t in range(n)), np.int64, n)
    size = np.bincount(root, minlength=n)
    largest = {}
    for r in np.nonzero(size)[0]:
        if size[r] > largest.get(lab[r], (0, -1))[0]:
            largest[lab[r]] = (size[r], r)
    border = {}
    for x, y in zip(a[~same].tolist(), b[~same].tolist()):
        for p, q in ((x, y), (y, x)):
            r = root[p]
            if size[r] < minimum and largest[lab[r]][1] != r:
                border.setdefault(r, {}).setdefault(lab[q], 0)
                border[r][lab[q]] += 1
    moved = 0
    for r, counts in border.items():
        if lab[r] in keep:
            continue
        lab[root == r] = max(counts, key=counts.get)
        moved += int(size[r])
    return lab, moved


def label(g, phase):
    defs = LM.PHASES[phase]
    names = defs.NAMES
    ids = glb.weld(g.pos, 1e-4)
    tp = RS.to_rig(g.pos, phase)[g.idx]
    cen = tp.mean(1)
    fn = np.cross(tp[:, 1] - tp[:, 0], tp[:, 2] - tp[:, 0])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    a, b = adjacency(g, ids)
    px, hue, sat, val = sample_colour(g, phase)
    dc = cen[b] - cen[a]
    d = np.linalg.norm(dc, axis=1)
    concave = ((fn[a] - fn[b]) * dc).sum(1) / np.maximum(d, 1e-9)
    bend = 1 - np.clip((fn[a] * fn[b]).sum(1), -1, 1)
    w = d * (1.0 + 40.0 * np.exp(-bend * 30))
    w = np.where(concave > 0, d * 4.0, w)
    colour_step = np.linalg.norm(px[a] - px[b], axis=1)
    w = np.where(colour_step > 0.22, d * 2.0, w)
    ctx = LM.Ctx(cen, hue, sat, val, px)
    lab = np.full(len(cen), -1, np.int64)
    for bone, mask in defs.seeds(ctx):
        lab[mask] = names.index(bone)
    limits = {names.index(k): f(ctx) for k, f in defs.LIMITS.items()}
    lab, nb_l, st = flood(cen, a, b, w, lab, limits)
    missing = lab < 0
    if missing.any():
        lab[missing] = names.index(defs.DEFAULT)
    lab = defs.clean(lab, ctx, names)
    keep = {names.index(k) for k in defs.KEEP}
    lab = despeckle(lab, a, b, keep)
    for _ in range(3):
        lab, moved = main_islands(lab, a, b, keep)
        if not moved:
            break
    return lab, cen


def main():
    for phase in [int(x) for x in sys.argv[1:]] or [1, 2]:
        g = glb.Glb(source(phase))
        lab, cen = label(g, phase)
        names = LM.PHASES[phase].NAMES
        np.save(os.path.join(ROOT, f"work/shen_import/labels_p{phase}.npy"), lab)
        vp, vn = RS.to_rig(g.pos, phase), RS.normal_to_rig(g.nrm)
        pieces = []
        for i, n in enumerate(names):
            tri = g.idx[lab == i]
            print(phase, n, len(tri))
            if len(tri):
                used, inv = np.unique(tri, return_inverse=True)
                pieces.append((n, vp[used], vn[used], g.uv[used], inv.reshape(-1, 3)))
        glb.write(os.path.join(ROOT, f"work/shen_import/labelled_p{phase}.glb"), g, pieces)


if __name__ == "__main__":
    main()

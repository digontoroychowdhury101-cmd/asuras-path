"""Label every triangle of the fused sculpt with the bone that carries it.

The sculpt is one watertight shell, so limbs meet in places with no seam. Seed volumes mark what certainly belongs to each bone; a priority flood over
the surface assigns the rest, and crossing a concave crease costs far more than crossing a flat surface, so cuts settle in the armour's own grooves.
"""
import heapq
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import glb  # noqa: E402
import rigdef as R  # noqa: E402

SOURCE = os.path.expanduser(os.environ.get("BULL_GLB", "~/Downloads/Iron-Bull-PBR.glb"))
J = {k: np.array(v[1], float) for k, v in R.JOINT.items()}


def caps(p, a, b, r):
    a, b = np.array(a, float), np.array(b, float)
    d = b - a
    t = np.clip(((p - a) @ d) / (d @ d), 0, 1)
    return np.linalg.norm(p - (a + t[:, None] * d), axis=1) < r


# The tower shield is a separate bent plate: its centreline in plan view, then its height. Everything on the far side of the inner face is shield.
SH_PLAN = np.array([[-0.66, -1.17], [-1.58, -0.62], [-1.98, 0.64]])
SH_END = 0.55


def plan_side(p):
    """Signed distance outward from the shield's centreline (+ away from the body) and the distance past its ends."""
    best, along = None, None
    xz = p[:, [0, 2]]
    for a, b in zip(SH_PLAN[:-1], SH_PLAN[1:]):
        d = b - a
        L = np.linalg.norm(d)
        u = d / L
        n = np.array([-u[1], u[0]])
        if n @ (a - np.array([0.1, 0.0])) < 0:
            n = -n
        q = xz - a
        t = q @ u
        w = q @ n
        over = np.maximum(np.maximum(-t, t - L), 0)
        dist = np.abs(w) + over
        if best is None:
            best, side, along = dist, w, over
        else:
            m = dist < best
            best, side, along = np.where(m, dist, best), np.where(m, w, side), np.where(m, over, along)
    return side, along


def shield_mask(p):
    w, over = plan_side(p)
    inner = np.where(p[:, 2] < -0.62, -0.28, -0.25)
    return (w > inner) & (w < 0.62) & (over < SH_END) & (p[:, 1] > -2.32) & (p[:, 1] < 1.78)


# The maul: pommel and grip behind the fist, haft ahead of it, then the block and its chains. Fused to the fist only under the fingers.
HAFT_A = np.array([1.27, -0.70, 0.55])
HAFT_B = np.array([1.62, -1.34, -0.87])


def maul_mask(p):
    # the block's back side in the side view runs from (z -1.22, y -1.10) to (z -0.51, y -2.16); chains cling just behind it
    head = (p[:, 0] > 1.27) & (p[:, 1] < -0.95) & (p[:, 1] > -2.72) & (p[:, 2] < -0.3) & ((p[:, 2] + 1.22) * -0.831 + (p[:, 1] + 1.10) * -0.556 > -0.12)
    grip = caps(p, HAFT_A, HAFT_B, 0.24) & ((p[:, 2] > 0.14) | (p[:, 2] < -0.32))
    return head | grip


def right_hand(p):
    fingers = (p[:, 0] > 1.2) & (p[:, 0] < 1.64) & (p[:, 1] > -1.16) & (p[:, 1] < -0.6) & (p[:, 2] > -0.66) & (p[:, 2] < -0.2)
    palm = (p[:, 0] > 1.26) & (p[:, 0] < 1.5) & (p[:, 1] > -1.12) & (p[:, 1] < -0.92) & (p[:, 2] > -0.66) & (p[:, 2] < 0.14)
    return fingers | palm


def left_hand(p):
    back = (p[:, 0] < -0.98) & (p[:, 0] > -1.42) & (p[:, 1] > -1.14) & (p[:, 1] < -0.62) & (p[:, 2] > -0.46) & (p[:, 2] < 0.30)
    fingers = (p[:, 0] < -0.84) & (p[:, 0] > -1.42) & (p[:, 1] > -1.14) & (p[:, 1] < -0.62) & (p[:, 2] > -0.8) & (p[:, 2] < -0.22)
    return back | fingers


def seeds(p):
    """(bone, mask): later entries win."""
    out = []
    add = lambda b, m: out.append((b, m))
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    add("LowerTorso", (np.abs(x - 0.1) < 1.0) & (y < 0.02) & (y > -0.42))
    add("UpperTorso", (np.abs(x - 0.1) < 1.0) & (y > 0.16) & (y < 1.34))
    add("ClothFront", (x > -0.12) & (x < 0.66) & (y > -2.55) & (y < -0.62) & (z < -0.38))
    add("ClothBack", (x > -0.76) & (x < 0.98) & (y > -2.78) & (y < -0.52) & (z > 0.42) & ((np.abs(x - 0.15) < 0.55) | (y > -2.05)))
    for side, s in (("Right", 1), ("Left", -1)):
        hip, knee, ankle = J[side + "UpperLeg"], J[side + "LowerLeg"], J[side + "Foot"]
        add(side + "UpperLeg", caps(p, hip + (s * .15, -.3, -0.05), knee + (0, .25, -0.1), .36))
        add(side + "LowerLeg", caps(p, knee + (0, -.05, -0.05), ankle + (0, .12, -0.05), .38) | ((np.abs(x - knee[0]) < .52) & (y < -1.74) & (y > -2.82) & (z < 0.4)))
        add(side + "Foot", (y < -2.84) & (s * x > 0.2))
        tx = (x > 0.66) & (x < 1.42) if s > 0 else (x < -0.28) & (x > -1.08)
        add(side + "UpperLeg", tx & (y < -0.54) & (y > -1.52) & (z > -0.82) & (z < 0.52))    # the tassets ride the thighs
        sh, el, wr = J[side + "UpperArm"], J[side + "LowerArm"], J[side + "Hand"]
        add(side + "UpperArm", caps(p, sh + (s * .1, -.3, 0), el + (0, .2, 0), .4))
        add(side + "LowerArm", caps(p, el + (0, -.12, 0), wr + (0, .12, 0), .46))
    add("RightLowerArm", (x > 1.76) & (y < 0.22) & (y > -1.04))
    # helpers, then what overrules them
    pauld = lambda s: ((s * (x - 0.1)) > 1.06) & (y > 0.92) & (y < 2.4) | ((s * (x - 0.1)) > 0.72) & (y > 1.0) & (y < 1.5) & (z > -0.75)
    add("RightPauldron", pauld(1))
    add("LeftPauldron", pauld(-1))
    add("Head", (np.abs(x - .16) < .62) & (y > 1.62) & (z < .62) | (y > 1.72) & (np.abs(x - .16) < 1.65) & (z > -1.25) & (z < -0.15) | (z < -.72) & (y > 1.12) & (np.abs(x - .16) < .55))
    add("RightHand", right_hand(p))
    add("LeftHand", left_hand(p))
    add("Weapon", maul_mask(p))
    add("Shield", shield_mask(p))
    return out


FLOOD_LIMITS = {
    "Shield": shield_mask,
    "Weapon": maul_mask,
}
NAMES = ["Head", "UpperTorso", "LowerTorso", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
         "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
         "RightPauldron", "LeftPauldron", "ClothFront", "ClothBack", "Weapon", "Shield"]


def adjacency(g, ids):
    t = ids[g.idx]
    n = len(t)
    e = np.concatenate((t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]))
    e.sort(axis=1)
    tri = np.tile(np.arange(n), 3)
    key = e[:, 0] * (ids.max() + 1) + e[:, 1]
    o = np.argsort(key, kind="stable")
    key, tri, e = key[o], tri[o], e[o]
    same = np.nonzero(key[1:] == key[:-1])[0]
    return tri[same], tri[same + 1], e[same]


def clean_cuts(lab, cen):
    """A flood wanders on a smooth surface, and a jagged edge shows once the joint bends. Where two bones meet on open surface, re-cut along a clean line."""
    x, y, z = cen[:, 0], cen[:, 1], cen[:, 2]
    L = {n: i for i, n in enumerate(NAMES)}

    def cut(a, b, is_a, where=None):
        m = ((lab == L[a]) | (lab == L[b]))
        if where is not None:
            m &= where
        lab[m] = np.where(is_a[m], L[a], L[b])
    near_r, near_l = np.abs(x - 1.0) < 0.75, np.abs(x + 0.8) < 0.75
    # knees: along the poleyn's top edge
    cut("RightUpperLeg", "RightLowerLeg", y > -1.66 - 0.0 * x, near_r)
    cut("LeftUpperLeg", "LeftLowerLeg", y > -1.66, near_l)
    # elbows: along the vambrace's slanted top
    cut("RightUpperArm", "RightLowerArm", y > 0.12 + 0.30 * (x - 1.42))
    cut("LeftUpperArm", "LeftLowerArm", y > 0.10 - 0.30 * (x + 1.33))
    # waist: the belt's top rises to the front centre and falls away round the back
    front = 0.13 - 0.16 * ((x - 0.1) / 0.9) ** 2
    cut("UpperTorso", "LowerTorso", y > np.where(z < 0.1, front, -0.01))
    # belt to what hangs from it
    for bone in ("RightUpperLeg", "LeftUpperLeg", "ClothFront", "ClothBack"):
        cut(bone, "LowerTorso", y < -0.52, z > -2)
    # apron and cape against the tassets
    cut("ClothFront", "RightUpperLeg", x < 0.66, y < -0.5)
    cut("ClothFront", "LeftUpperLeg", x > -0.12, y < -0.5)
    cut("ClothBack", "RightUpperLeg", z > 0.42, y < -0.5)
    cut("ClothBack", "LeftUpperLeg", z > 0.42, y < -0.5)
    # neck, at the back and sides where the skin is smooth
    cut("Head", "UpperTorso", y > 1.6, (z > -0.25) & (np.abs(x - 0.16) < 0.95))
    # armpit
    cut("RightUpperArm", "UpperTorso", x > 1.02, y < 1.0)
    cut("LeftUpperArm", "UpperTorso", x < -0.82, y < 1.0)
    return lab


def despeckle(lab, a, b, small=900):
    """Union triangles of equal label through edges; any island under `small` triangles takes the label it borders most."""
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
        cross = ~same
        for x, y in zip(a[cross].tolist(), b[cross].tolist()):
            rx, ry = root[x], root[y]
            if size[rx] < small:
                border.setdefault(rx, {}).setdefault(lab[y], 0)
                border[rx][lab[y]] += 1
            if size[ry] < small:
                border.setdefault(ry, {}).setdefault(lab[x], 0)
                border[ry][lab[x]] += 1
        changed = 0
        for r, counts in border.items():
            if lab[r] == NAMES.index("Shield") or lab[r] == NAMES.index("Weapon"):
                continue
            target = max(counts, key=counts.get)
            lab[root == r] = target
            changed += 1
        if not changed:
            break
    return lab


def label(g, p):
    ids = glb.weld(g.pos, 1e-4)
    vp = R.to_rig(g.pos)
    tp = vp[g.idx]
    cen = tp.mean(1)
    fn = np.cross(tp[:, 1] - tp[:, 0], tp[:, 2] - tp[:, 0])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    a, b, ev = adjacency(g, ids)
    # concave crease: neighbours whose normals turn toward each other across the edge
    dc = cen[b] - cen[a]
    d = np.linalg.norm(dc, axis=1)
    concave = np.clip(((fn[a] - fn[b]) * dc).sum(1) / np.maximum(d, 1e-9) * -1, 0, None)
    bend = 1 - np.clip((fn[a] * fn[b]).sum(1), -1, 1)
    w = d * (1 + 60 * np.where(concave > 0, 0, 1.0)) * 1.0
    w = d * (1.0 + 40.0 * np.exp(-bend * 30) )
    w = np.where(concave <= 0, w, d * 4.0)
    # labels
    lab = np.full(len(cen), -1, np.int64)
    for bone, m in seeds(cen):
        lab[m] = NAMES.index(bone)
    limit = {NAMES.index(k): f(cen) for k, f in FLOOD_LIMITS.items()}
    # adjacency lists
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
    # flood from the seed borders
    heap = [(0.0, int(t)) for t in seeded]
    heapq.heapify(heap)
    lab_l, dist_l, nb_l, wt_l, st = lab.tolist(), dist.tolist(), nb.tolist(), wt.tolist(), start.tolist()
    while heap:
        dd, t = heapq.heappop(heap)
        if dd > dist_l[t]:
            continue
        la = lab_l[t]
        for k in range(st[t], st[t + 1]):
            o = nb_l[k]
            if la in limit and not limit[la][o]:
                continue
            nd = dd + wt_l[k]
            if nd < dist_l[o]:
                dist_l[o], lab_l[o] = nd, la
                heapq.heappush(heap, (nd, o))
    lab = np.array(lab_l)
    # triangles a limit fenced off from every flood: same flood, no fences
    stuck = np.nonzero(lab < 0)[0]
    while len(stuck):
        for t in stuck.tolist():
            near = [lab_l[nb_l[k]] for k in range(st[t], st[t + 1]) if lab_l[nb_l[k]] >= 0]
            if near:
                lab_l[t] = near[0]
        lab = np.array(lab_l)
        again = np.nonzero(lab < 0)[0]
        if len(again) == len(stuck):
            lab[again] = NAMES.index("UpperTorso")
            break
        stuck = again
    # stray specks of one bone stranded inside another: a small connected island joins its surroundings
    lab = clean_cuts(lab, cen)
    lab = despeckle(lab, a, b)
    return lab, cen, (a, b)


def main():
    g = glb.Glb(SOURCE)
    lab, cen, _ = label(g, None)
    os.makedirs("work/bull_import", exist_ok=True)
    np.save("work/bull_import/labels.npy", lab)
    for i, n in enumerate(NAMES):
        print(n, int((lab == i).sum()))
    pieces = []
    vp, vn = R.to_rig(g.pos), R.normal_to_rig(g.nrm)
    for i, n in enumerate(NAMES):
        tri = g.idx[lab == i]
        if not len(tri):
            continue
        used, inv = np.unique(tri, return_inverse=True)
        pieces.append((n, vp[used], vn[used], g.uv[used], inv.reshape(-1, 3)))
    # debug: rig Roblox axes -> Blender handled by viewer
    glb.write("work/bull_import/labelled.glb", g, pieces)


if __name__ == "__main__":
    main()

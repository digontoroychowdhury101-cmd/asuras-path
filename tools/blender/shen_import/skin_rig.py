"""Grandmaster Shen's skin: every body and garment vertex weighted to one shared skeleton, so robes, hair and sleeves bend with him instead of hinging as plates.

    python3 tools/blender/shen_import/skin_rig.py [1 2]
Writes work/shen_import/skin_p<n>.npz     per source vertex: joints (4 skeleton indices), weights (sum 1)
       work/shen_import/cloth_p<n>.json   skeleton, sheets, particles, links and colliders for ClothSim (bake and game)

Skeleton: Root at the origin with no influences, then a flat list of translate-only bones: Sk_<limb> for the 15 R15 limbs, Cl_<sheet>_<col>_<row> for each free cloth particle.
Body: smooth blends across each joint, computed from position so a UV or normal split never cracks. Garments: a lattice laid on the sculpted surface, bilinear over its particles (4 influences), the top row
pinned to the body so cloth grows out of him. Weights hang off welded position, so chunks that share an edge always agree.
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path[:0] = [HERE, os.path.join(ROOT, "tools/blender/bull_import")]
import glb  # noqa: E402
import landmarks as LM  # noqa: E402
import rigdef as RD  # noqa: E402
import rigspace as RS  # noqa: E402
import segment as Seg  # noqa: E402

LIMBS = ["LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
         "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]
RIGID = {"Weapon"}          # welded to its own joint, not skinned
CARRIER = {"RobeBack": "LowerTorso", "RobeRight": "LowerTorso", "RobeLeft": "LowerTorso", "RobeInner": "LowerTorso", "RobeFront": "LowerTorso", "HairBack": "Head", "Beard": "Head", "Beads": "UpperTorso",
           "RightMantle": "UpperTorso", "LeftMantle": "UpperTorso", "LeftSleeve": "LeftUpperArm", "RibbonRight": "RightLowerArm", "RibbonLeft": "LeftLowerArm", "Bead1": "Head", "Bead2": "Head", "Bead3": "Head"}
ROBE = ("RobeBack", "RobeRight", "RobeLeft", "RobeInner", "RobeFront")


def sstep(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def unit(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-9)


# ------------------------------------------------------------------------------------------------ body weights
def limb_weights(J, P, name):
    """Up to four (skeleton index, weight) for hidden volumes on a limb, by the same joint blends the sculpt's own surface uses, so they stay inside it."""
    body = body_weights(J, P, np.full(len(P), LIMBS.index(name)))
    order = np.argsort(-body, axis=1)[:, :4]
    w = np.take_along_axis(body, order, 1)
    return (order + 1).astype(np.uint8), (w / w.sum(1, keepdims=True)).astype(np.float32)


def body_weights(J, P, vlabel):
    """A dense limb weight per vertex: its carrier limb, blended across each joint by position along the child bone."""
    limb = {n: i for i, n in enumerate(LIMBS)}
    W = np.zeros((len(P), len(LIMBS)))
    W[np.arange(len(P)), vlabel] = 1
    a = lambda v: np.array(v, float)
    joints = [  # parent, child, joint, child axis, half-width of the blend, reach of the blend around the joint
        ("LowerTorso", "UpperTorso", a(J.WAIST), a((0, 1, 0)), 0.2, 9.0),
        ("UpperTorso", "Head", a(J.NECK), a((0, 1, 0)), 0.1, 0.55),
        ("UpperTorso", "RightUpperArm", a(J.RSH), unit(a(J.REL) - a(J.RSH)), 0.24, 0.62), ("RightUpperArm", "RightLowerArm", a(J.REL), unit(a(J.RWR) - a(J.REL)), 0.2, 0.6), ("RightLowerArm", "RightHand", a(J.RWR), unit(a(J.RWR) - a(J.REL)), 0.07, 0.4),
        ("UpperTorso", "LeftUpperArm", a(J.LSH), unit(a(J.LEL) - a(J.LSH)), 0.24, 0.62), ("LeftUpperArm", "LeftLowerArm", a(J.LEL), unit(a(J.LWR) - a(J.LEL)), 0.2, 0.6), ("LeftLowerArm", "LeftHand", a(J.LWR), unit(a(J.LWR) - a(J.LEL)), 0.07, 0.4),
        ("LowerTorso", "RightUpperLeg", a(J.RHIP), unit(a(J.RKN) - a(J.RHIP)), 0.26, 0.7), ("RightUpperLeg", "RightLowerLeg", a(J.RKN), unit(a(J.RAN) - a(J.RKN)), 0.3, 0.8), ("RightLowerLeg", "RightFoot", a(J.RAN), a((0, -1, 0)), 0.07, 0.6),
        ("LowerTorso", "LeftUpperLeg", a(J.LHIP), unit(a(J.LKN) - a(J.LHIP)), 0.26, 0.7), ("LeftUpperLeg", "LeftLowerLeg", a(J.LKN), unit(a(J.LAN) - a(J.LKN)), 0.3, 0.8), ("LeftLowerLeg", "LeftFoot", a(J.LAN), a((0, -1, 0)), 0.07, 0.6),
    ]
    for pa, ch, j, ax, half, reach in joints:
        ip, ic = limb[pa], limb[ch]
        ix = np.nonzero((vlabel == ip) | (vlabel == ic))[0]
        d = (P[ix] - j) @ ax
        dist = np.linalg.norm(P[ix] - j, axis=1)
        mask = 1 - sstep(dist, reach * 0.7, reach)
        frac = mask * sstep(d, -half, half) + (1 - mask) * (vlabel[ix] == ic)
        total = W[ix, ip] + W[ix, ic]
        W[ix, ic], W[ix, ip] = total * frac, total * (1 - frac)
    return W


# ------------------------------------------------------------------------------------------------ cloth lattices
class Sheet:
    """A lattice of particles over a set of vertices: u across (columns), v along the fall (rows). Row 0 is pinned to the anchor limb."""

    def __init__(self, name, ids, P, cols, rows, u, v, closed=False, anchor="LowerTorso", keep=0.25, tail_pin=None):
        self.name, self.ids, self.cols, self.rows, self.closed, self.anchor = name, ids, cols, rows, closed, anchor
        self.keep = keep   # the first fraction of the first row band blends from the body's own weights into the lattice
        self.tail_pin = tail_pin
        self.P = P[ids]
        self.u, self.v = u, v      # lattice coordinates: u in [0, cols) when closed, else [0, cols-1]; v in [0, rows]
        self.rest = self._fit()

    def _fit(self):
        """Rest position of each particle: the tent-weighted mean of the surface around it, so the lattice lies on the sculpt."""
        C, Rw = self.cols, self.rows + 1
        acc, tot = np.zeros((C, Rw, 3)), np.zeros((C, Rw))
        c0 = np.floor(self.u).astype(int)
        r0 = np.clip(np.floor(self.v).astype(int), 0, Rw - 2)
        fu, fv = self.u - c0, self.v - r0
        c0 %= C
        c1 = (c0 + 1) % C if self.closed else np.minimum(c0 + 1, C - 1)
        for cc, rr, w in ((c0, r0, (1 - fu) * (1 - fv)), (c1, r0, fu * (1 - fv)), (c0, r0 + 1, (1 - fu) * fv), (c1, r0 + 1, fu * fv)):
            np.add.at(acc, (cc, rr), self.P * w[:, None])
            np.add.at(tot, (cc, rr), w)
        rest = np.full((C, Rw, 3), np.nan)
        ok = tot > 1e-3
        rest[ok] = acc[ok] / tot[ok][:, None]
        for _ in range(C + Rw):   # an empty cell takes its neighbours' mean, so a torn hem still has a lattice
            bad = np.argwhere(np.isnan(rest[:, :, 0]))
            if not len(bad):
                break
            for c, r in bad:
                near = [rest[(c + d) % C if self.closed else min(max(c + d, 0), C - 1), r] for d in (-1, 1)] + [rest[c, max(r - 1, 0)], rest[c, min(r + 1, Rw - 1)]]
                near = [n for n in near if not np.isnan(n[0])]
                if near:
                    rest[c, r] = np.mean(near, axis=0)
        # a light relaxation: the mean of a noisy column makes a lumpy lattice, and a lumpy lattice folds under load
        out = rest.copy()
        for _ in range(2):
            nxt = out.copy()
            for r in range(1, Rw):
                for c in range(C):
                    a, b = out[(c - 1) % C if self.closed else max(c - 1, 0), r], out[(c + 1) % C if self.closed else min(c + 1, C - 1), r]
                    nxt[c, r] = out[c, r] * 0.7 + (a + b) * 0.15
            out = nxt
        return out

    def influences(self):
        """(column, row, weight) quadruple per vertex."""
        C, Rw = self.cols, self.rows + 1
        c0 = np.floor(self.u).astype(int)
        r0 = np.clip(np.floor(self.v).astype(int), 0, Rw - 2)
        fu, fv = self.u - c0, np.clip(self.v - r0, 0, 1)
        c0 %= C
        c1 = (c0 + 1) % C if self.closed else np.minimum(c0 + 1, C - 1)
        return [(c0, r0, (1 - fu) * (1 - fv)), (c1, r0, fu * (1 - fv)), (c0, r0 + 1, (1 - fu) * fv), (c1, r0 + 1, fu * fv)]


def ring(name, ids, P, origin, down, back, cols, rows, r0, closed, span=None, anchor="LowerTorso", vscale=None):
    """A lattice around an axis: u is the angle about it, v the distance from the attachment ring in the radial plane, normalized to each column's hem."""
    origin, down, back = np.array(origin, float), unit(down), unit(back)
    side = np.cross(down, back)
    Q = P[ids] - origin
    h = Q @ down
    x, y = Q @ side, Q @ back
    r = np.hypot(x, y)
    th = np.arctan2(x, y)     # 0 at the back
    dist = np.hypot(np.maximum(r - r0, 0), h)
    if closed:
        u = (th + math.pi) / (2 * math.pi) * cols
        u = np.mod(u, cols)
    else:
        lo, hi = span if span else (np.percentile(th, 0.5), np.percentile(th, 99.5))
        u = np.clip((th - lo) / (hi - lo), 0, 1) * (cols - 1)
    nb = max(cols * 3, 12)
    edges = np.linspace(u.min(), u.max() + 1e-6, nb + 1)
    bin_ = np.clip(np.digitize(u, edges) - 1, 0, nb - 1)
    hem = np.array([np.percentile(dist[bin_ == i], 97) if (bin_ == i).sum() > 20 else np.nan for i in range(nb)])
    hem = np.where(np.isnan(hem), np.nanmedian(hem), hem)
    for _ in range(2):    # the hem line is smooth around the body
        hem = (np.roll(hem, 1) + hem * 2 + np.roll(hem, -1)) / 4 if closed else np.convolve(np.pad(hem, 1, mode="edge"), (0.25, 0.5, 0.25), "valid")
    hem_v = np.interp(u, (edges[:-1] + edges[1:]) / 2, hem)
    v = np.clip(dist / np.maximum(hem_v, 0.15), 0, 1.0) * rows
    return Sheet(name, ids, P, cols, rows, u, v, closed, anchor)


def fan(name, ids, P, origin, across, fall, cols, rows, anchor, span=None):
    """A fall of strands from one point (hair, beard): u is the bearing in the plane of `across` and `fall`, v the distance from the origin."""
    origin, across, fall = np.array(origin, float), unit(across), unit(fall)
    Q = P[ids] - origin
    a, b = Q @ across, Q @ fall
    th = np.arctan2(a, np.maximum(b, 0.02))
    lo, hi = span if span else (np.percentile(th, 1), np.percentile(th, 99))
    u = np.clip((th - lo) / (hi - lo), 0, 1) * (cols - 1)
    dist = np.linalg.norm(Q, axis=1)
    v = np.clip(dist / np.percentile(dist, 98), 0, 1) * rows
    return Sheet(name, ids, P, cols, rows, u, v, False, anchor)


def spans(name, ids, P, start, end, cols, rows, anchor, across=None):
    """A strip along a straight line: a sash, a bead string, a ribbon. u is the offset across, v the fraction along."""
    start, end = np.array(start, float), np.array(end, float)
    ax = end - start
    L = np.linalg.norm(ax)
    ax = ax / L
    Q = P[ids] - start
    v = np.clip((Q @ ax) / L, 0, 1) * rows
    if cols > 1:
        side = unit(across if across is not None else np.cross(ax, (0, 0, 1)))
        s = Q @ side
        lo, hi = np.percentile(s, 2), np.percentile(s, 98)
        u = np.clip((s - lo) / max(hi - lo, 1e-3), 0, 1) * (cols - 1)
    else:
        u = np.zeros(len(ids))
    return Sheet(name, ids, P, cols, rows, u, v, False, anchor)


def heal(joints, weights, tv, nbones, jump=0.1, hops=14, passes=70):
    """Weights must not jump across a mesh edge, or the sculpt's dense surface tears as soon as the two sides move apart. Finds every jump and solves the band of surface around it as a smooth ramp
    (Laplace over the mesh, the surface outside the band fixed), so a robe's edge flows into whatever it is sewn to, over real distance, and connected things stay connected."""
    n = len(joints)
    W = np.zeros((n, nbones), np.float32)
    for k in range(4):
        np.add.at(W, (np.arange(n), joints[:, k]), weights[:, k].astype(np.float32))
    e = np.vstack((tv[:, [0, 1]], tv[:, [1, 2]], tv[:, [2, 0]]))
    e = e[e[:, 0] != e[:, 1]]
    e = np.unique(np.sort(e, axis=1), axis=0)
    dist = np.zeros(len(e), np.float32)
    for i in range(0, len(e), 100000):
        c = e[i:i + 100000]
        dist[i:i + 100000] = np.abs(W[c[:, 0]] - W[c[:, 1]]).sum(1)
    band = np.zeros(n, bool)
    band[e[dist > jump].ravel()] = True
    for _ in range(hops):
        grow = band[e[:, 0]] | band[e[:, 1]]
        band[e[grow].ravel()] = True
    ix = np.nonzero(band)[0]
    if not len(ix):
        return joints, weights
    # the neighbours of every band vertex
    both = np.vstack((e, e[:, ::-1]))
    both = both[band[both[:, 0]]]
    both = both[np.argsort(both[:, 0], kind="stable")]
    starts = np.searchsorted(both[:, 0], ix)
    valence = np.diff(np.append(starts, len(both))).astype(np.float32)[:, None]
    nbr = both[:, 1]
    used = np.nonzero(W[ix].max(0) > 1e-4)[0]     # only the bones this band touches
    used = np.union1d(used, np.nonzero(W[np.unique(nbr)].max(0) > 1e-4)[0])
    sub = W[:, used]
    for _ in range(passes):
        sub[ix] = sub[ix] * 0.25 + 0.75 * np.add.reduceat(sub[nbr], starts, axis=0) / valence
    W[:, used] = sub
    print(f"    healed {int((dist > jump).sum())} jumps in a band of {len(ix)} vertices over {len(used)} bones")
    order = np.argsort(-W[ix], axis=1)[:, :4]
    w = np.take_along_axis(W[ix], order, 1)
    joints, weights = joints.copy(), weights.copy()
    joints[ix] = order
    weights[ix] = w / np.maximum(w.sum(1, keepdims=True), 1e-6)
    return joints, weights


# ------------------------------------------------------------------------------------------------ a whole form
CLOTH_ONLY = "--cloth-only" in sys.argv   # rewrite cloth_p<n>.json alone, for tuning
TUNE = {
    # row 0 pinned. shape: pull back to the sculpt per 60 Hz step, root to hem. reach: how far from the sculpt it may roam (rig studs). drag: air, root to hem. legs: how far it follows the nearest thigh, root to hem
    "Coat": dict(shape=(0.08, 0.003), reach=(0.26, 1.9), drag=(0.55, 1.25), legs=(0.06, 0.04), along=0.95, across=0.42, bend=0.12),
    "Under": dict(shape=(0.12, 0.012), reach=(0.2, 1.25), drag=(0.45, 1.05), legs=(0.22, 0.3), along=0.95, across=0.38, bend=0.14),
    "Hair": dict(shape=(0.08, 0.01), reach=(0.16, 1.3), drag=(0.45, 1.15), legs=(0, 0), along=0.96, across=0.34, bend=0.3),
    "Beard": dict(shape=(0.16, 0.05), reach=(0.06, 0.35), drag=(0.25, 0.5), legs=(0, 0), along=0.97, across=0.4, bend=0.3),
    "Beads": dict(shape=(0.2, 0.09), reach=(0.05, 0.28), drag=(0.03, 0.05), legs=(0, 0), along=0.98, across=0.4, bend=0.1),
    "Mantle": dict(shape=(0.18, 0.05), reach=(0.07, 0.5), drag=(0.3, 0.7), legs=(0, 0), along=0.95, across=0.4, bend=0.1),
    "Sleeve": dict(shape=(0.16, 0.08), reach=(0.08, 0.55), drag=(0.3, 0.6), legs=(0, 0), along=0.9, across=0.4, bend=0.1),
    "Rag": dict(shape=(0.1, 0.02), reach=(0.1, 0.9), drag=(0.5, 1.2), legs=(0, 0), along=0.96, across=0.4, bend=0.15),
}


def tune_of(sheet):
    for k in ("Rag", "Coat", "Under", "Hair", "Beard", "Beads", "Mantle", "Sleeve"):
        if k in sheet:
            return k, TUNE[k]
    raise KeyError(sheet)


def coat_split(J, P, ids, phase):
    """The outer coat flares clear of the tiers beneath it: above a cone from the waist it is coat, below it the under-robe."""
    O = np.array(J.PELVIS, float) + (0, 0.13, 0)
    Q = P[ids] - O
    r = np.hypot(Q[:, 0], Q[:, 2])
    th = np.arctan2(Q[:, 0], Q[:, 2])
    h = np.maximum(-Q[:, 1], 1e-3)
    phi = np.degrees(np.arctan2(np.maximum(r - 0.45, 0), h))
    # the cone opens at the front, where the coat parts around the under-robe
    front = np.abs(th) / math.pi
    limit = (24 + 22 * sstep(front, 0.55, 0.95)) if phase == 1 else (17 + 22 * sstep(front, 0.55, 0.95))
    return phi >= limit, O


def components(tv, mask, n_w):
    """Connected groups of the masked triangles through their welded vertices: an array of group ids, -1 outside the mask."""
    ids = np.nonzero(mask)[0]
    parent = np.arange(n_w)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for a, b, c in tv[ids]:
        ra, rb, rc = find(a), find(b), find(c)
        parent[rb] = ra
        parent[rc] = ra
    out = np.full(len(tv), -1)
    out[ids] = [find(a) for a in tv[ids, 0]]
    return out


def trouser_triangles(J, g, lab, V, weld, phase):
    """The sculpt fused the dark trousers into the robe tiers. A triangle is trouser if it is dark and wraps a thigh; stray dark folds out on the robe are not, and small pale holes inside the trouser are."""
    _, _, sat, val = Seg.sample_colour(g, phase)
    tv = weld[g.idx]
    n_w = int(weld.max()) + 1
    cen = V[g.idx].mean(1)
    robe = np.isin(lab, [J.NAMES.index(n) for n in ROBE if n in J.NAMES])
    near = np.full(len(cen), 9.0)
    for hip, kn, an in ((J.RHIP, J.RKN, J.RAN), (J.LHIP, J.LKN, J.LAN)):
        for a_, b_ in ((np.array(hip, float) + (0, 0.25, 0), np.array(kn, float) + (0, -0.2, 0)),):
            d = b_ - a_
            u = np.clip((cen - a_) @ d / (d @ d), 0, 1)
            near = np.minimum(near, np.linalg.norm(cen - a_ - np.outer(u, d), axis=1))
    # trousers are near-black or a neutral grey where the bake fades them into the ivory; the navy coat is just as dark but strongly coloured
    tr = robe & (near < 0.72) & (val < 0.3) & (sat < 0.3)
    # one clean edge: each triangle takes the side most of its neighbours are on, so the painted blotches on either side go with their own garment
    e = np.vstack((tv[:, [0, 1]], tv[:, [1, 2]], tv[:, [2, 0]]))
    e.sort(axis=1)
    key = e[:, 0] * (n_w + 1) + e[:, 1]
    tri = np.tile(np.arange(len(tv)), 3)
    order = np.argsort(key, kind="stable")
    same = key[order][1:] == key[order][:-1]
    a_, b_ = tri[order][:-1][same], tri[order][1:][same]
    keep = robe[a_] & robe[b_]
    a_, b_ = a_[keep], b_[keep]
    for _ in range(12):
        votes, total = np.zeros(len(tv)), np.zeros(len(tv))
        np.add.at(votes, a_, tr[b_])
        np.add.at(votes, b_, tr[a_])
        np.add.at(total, a_, 1)
        np.add.at(total, b_, 1)
        flip = robe & (total > 0) & (near < 0.72)
        tr[flip] = votes[flip] * 2 > total[flip]
    group = components(tv, tr, n_w)
    ids, counts = np.unique(group[tr], return_counts=True)
    tr &= np.isin(group, ids[counts >= 600])
    other = robe & ~tr & (near < 0.72)     # and no ivory crumbs left stranded on the trouser
    group = components(tv, other, n_w)
    ids, counts = np.unique(group[other], return_counts=True)
    tr |= other & np.isin(group, ids[counts < 150])
    return tr


def split_trousers(g, lab, phase):
    """Parts the trousers from the robe: their triangles join the thighs and every vertex the two shared is doubled, so each side moves on its own weights with no skin stretched between them. Every source triangle, normal and UV is kept. Returns the new weld."""
    J = LM.PHASES[phase]
    V = RS.to_rig(g.pos, phase)
    weld = glb.weld(V, 1e-4)
    tr = trouser_triangles(J, g, lab, V, weld, phase)
    cen = V[g.idx].mean(1)
    right, left = J.NAMES.index("RightUpperLeg"), J.NAMES.index("LeftUpperLeg")
    tv = weld[g.idx]
    n_w = int(weld.max()) + 1
    in_t, in_o = np.zeros(n_w, bool), np.zeros(n_w, bool)
    in_t[tv[tr].ravel()] = True
    in_o[tv[~tr].ravel()] = True
    shared = in_t & in_o
    new_ids = np.full(n_w, -1)
    new_ids[shared] = n_w + np.arange(shared.sum())
    idx = g.idx.copy()
    corners = g.idx[tr]
    used = np.unique(corners[shared[weld[corners]]])     # source vertices the trouser side must have a copy of
    remap = np.full(len(g.pos), -1)
    remap[used] = len(g.pos) + np.arange(len(used))
    hit = remap[corners] >= 0
    corners[hit] = remap[corners][hit]
    idx[tr] = corners
    g.pos = np.vstack((g.pos, g.pos[used]))
    g.nrm = np.vstack((g.nrm, g.nrm[used]))
    g.uv = np.vstack((g.uv, g.uv[used]))
    g.idx = idx
    weld2 = np.concatenate((weld, new_ids[weld[used]]))
    lab = lab.copy()
    lab[tr] = np.where(cen[tr, 0] > J.PELVIS[0], right, left)
    print(f"  P{phase}: {int(tr.sum())} trouser triangles parted from the robe, {len(used)} vertices doubled along the seam")
    # phase 2's orbs: the sculpt strung them together on the ribbon and the blade. Each comes free as its own body, or a triangle bridging two would stretch across his head
    for n in ("Bead1", "Bead2", "Bead3"):
        if n not in J.NAMES:
            continue
        m = lab == J.NAMES.index(n)
        tv = weld2[g.idx]
        count = int(weld2.max()) + 1
        in_m, in_o = np.zeros(count, bool), np.zeros(count, bool)
        in_m[tv[m].ravel()] = True
        in_o[tv[~m].ravel()] = True
        shared = in_m & in_o
        ids = np.full(count, -1)
        ids[shared] = count + np.arange(shared.sum())
        corners = g.idx[m]
        used = np.unique(corners[shared[weld2[corners]]])
        remap = np.full(len(g.pos), -1)
        remap[used] = len(g.pos) + np.arange(len(used))
        hit = remap[corners] >= 0
        corners[hit] = remap[corners][hit]
        g.idx[m] = corners
        g.pos, g.nrm, g.uv = np.vstack((g.pos, g.pos[used])), np.vstack((g.nrm, g.nrm[used])), np.vstack((g.uv, g.uv[used]))
        weld2 = np.concatenate((weld2, ids[weld2[used]]))
    lab, weld2 = close_orbs(g, lab, weld2, J)
    return lab, weld2


ORB_RADIUS = 0.27
ORB_REST = {"Bead1": (1.78, 0.32, 0.5), "Bead2": (1.3, 0.0, 0.25), "Bead3": (1.78, -0.3, 0.25)}


def free_patch(g, keep):
    """The largest square of the colour map no kept triangle uses (the old lumps' paint is free now): the new orbs' own paint goes there, in phase 2's copy of the maps."""
    n = 512
    used = np.zeros((n, n), bool)
    uv = g.uv[g.idx[keep]]
    lo = np.clip((uv.min(1) * n).astype(int), 0, n - 1)
    hi = np.clip((uv.max(1) * n).astype(int) + 1, 1, n)
    for (x0, y0), (x1, y1) in zip(lo, hi):
        used[y0:y1, x0:x1] = True
    table = np.zeros((n + 1, n + 1), int)
    table[1:, 1:] = used.cumsum(0).cumsum(1)
    for cells in (64, 48, 40, 32, 26, 20, 16, 12, 8):
        filled = table[cells:, cells:] - table[:-cells, cells:] - table[cells:, :-cells] + table[:-cells, :-cells]
        free = np.argwhere(filled == 0)
        if len(free):
            y, x = free[len(free) // 2]
            print(f"  orb patch {cells * 4} texels square")
            return (x + cells / 2) / n, (y + cells / 2) / n, (cells - 3) / n / 2
    raise SystemExit("no free square in the colour map for the orbs")


def close_orbs(g, lab, weld2, J):
    """Remade orbs: the sculpt fused its beads into one lumpy mass and into the ribbon, so they could never read as orbs. The strand trailing from them goes back to the ribbon, the lumps leave the game mesh (the source GLB is untouched), and three true spheres take their labels, smooth normals and their own painted patch of the maps."""
    if "Bead1" not in J.NAMES:
        return lab, weld2
    V = RS.to_rig(g.pos, 2)
    rows = np.linspace(0, len(g.pos) - 1, 400).astype(int)
    fit, *_ = np.linalg.lstsq(np.column_stack((g.pos[rows], np.ones(len(rows)))), V[rows], rcond=None)
    A, b = fit[:3].T, fit[3]
    Ai = np.linalg.inv(A)
    ribbon = J.NAMES.index("RibbonRight")
    drop = np.zeros(len(lab), bool)
    for n in ORB_REST:
        tris = np.nonzero(lab == J.NAMES.index(n))[0]
        cen = V[g.idx[tris]].mean(1)
        drop[tris[np.linalg.norm(cen - np.median(cen, axis=0), axis=1) <= 0.25]] = True
    # the shed fragment and scraps of ribbon stuck to the lumps would float alone once the orbs have gone: they go with them
    cen = V[g.idx].mean(1)
    drop |= (lab == ribbon) & (np.linalg.norm(cen - np.array((1.68, 0.15, 0.4)), axis=1) < 0.4)
    for n in ORB_REST:
        drop |= lab == J.NAMES.index(n)
    cx, cy, half = free_patch(g, ~drop)
    g.orb_patch = (cx, cy, half)
    pos, nrm, uv, wl, idx, labs = [], [], [], [], [], []
    base = len(g.pos)
    next_weld = int(weld2.max()) + 1
    rings, sides = 18, 32
    for n, rest in ORB_REST.items():
        code = J.NAMES.index(n)
        tris = np.nonzero(lab == code)[0]
        start = base + len(pos)
        for r in range(rings + 1):
            th = math.pi * r / rings
            for c in range(sides):
                ph = 2 * math.pi * c / sides
                d = np.array([math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)])
                pos.append(Ai @ (np.array(rest) + d * ORB_RADIUS - b))
                nn = Ai @ d
                nrm.append(nn / np.linalg.norm(nn))
                uv.append((cx + d[0] * half * 0.9, cy + d[1] * half * 0.9))
                wl.append(next_weld)
                next_weld += 1
        for r in range(rings):
            for c in range(sides):
                p, q = start + r * sides + c, start + r * sides + (c + 1) % sides
                u, w = p + sides, q + sides
                idx.extend(((p, q, u), (q, w, u)))
                labs.extend((code, code))
    g.orb_replaced = int(drop.sum())
    g.orb_new = len(idx)
    g.pos = np.vstack((g.pos, np.array(pos, g.pos.dtype)))
    g.nrm = np.vstack((g.nrm, np.array(nrm, g.nrm.dtype)))
    g.uv = np.vstack((g.uv, np.array(uv, g.uv.dtype)))
    g.idx = np.vstack((g.idx[~drop], np.array(idx, g.idx.dtype)))
    weld2 = np.concatenate((weld2, np.array(wl, weld2.dtype)))
    lab = np.concatenate((lab[~drop], np.array(labs, lab.dtype)))
    print(f"  orbs remade: {g.orb_replaced} lumpy source triangles out of the game mesh, {g.orb_new} sphere triangles in; patch at {cx:.3f},{cy:.3f}")
    return lab, weld2


def build(phase):
    J = LM.PHASES[phase]
    g = glb.Glb(Seg.source(phase))
    lab = np.load(os.path.join(ROOT, f"work/shen_import/labels_p{phase}.npy"))
    lab, weld = split_trousers(g, lab, phase)
    V = RS.to_rig(g.pos, phase)
    n_w = int(weld.max()) + 1
    # one position per welded vertex and the label most of its triangles carry
    P = np.zeros((n_w, 3))
    P[weld] = V
    votes = np.zeros((n_w, len(J.NAMES)), np.int32)
    tv = weld[g.idx]
    for c in range(3):
        np.add.at(votes, (tv[:, c], lab), 1)
    vname = votes.argmax(1)
    names = np.array(J.NAMES)
    limb = {n: i for i, n in enumerate(LIMBS)}
    carrier = np.array([limb[CARRIER.get(n, n)] if n not in RIGID else limb["RightHand"] for n in J.NAMES])
    body = body_weights(J, P, carrier[vname])
    of = lambda *ns: np.nonzero(np.isin(vname, [J.NAMES.index(n) for n in ns if n in J.NAMES]))[0]

    a = lambda v: np.array(v, float)
    sheets = []
    robe = of("RobeBack", "RobeRight", "RobeLeft", "RobeInner", "RobeFront")
    coat, O = coat_split(J, P, robe, phase)
    ids_c, ids_u = robe[coat], robe[~coat]
    sheets.append(ring("Coat", ids_c, P, O, (0, -1, 0), (0, 0, 1), 10, 4, 0.42, False, span=(-2.75, 2.75)))
    sheets.append(ring("Under", ids_u, P, O, (0, -1, 0), (0, 0, 1), 10, 3, 0.42, True))
    head, chest = a(J.NECK), a(J.WAIST)
    if phase == 1:
        sheets.append(fan("Hair", of("HairBack"), P, (-0.12, 2.05, 0.2), (1, 0, 0), (0, -0.9, 0.42), 5, 3, "Head"))
        sheets.append(fan("Beard", of("Beard"), P, (-0.12, 1.75, -0.45), (1, 0, 0), (0, -1, -0.1), 2, 2, "Head"))
        sheets.append(spans("Beads", of("Beads"), P, (-0.1, 1.8, -0.35), (0.25, 0.65, -0.72), 1, 4, "UpperTorso"))
        for side, sh, el, wr in (("Right", J.RSH, J.REL, J.RWR), ("Left", J.LSH, J.LEL, J.LWR)):
            sh, el = a(sh), a(el)
            sheets.append(fan(side[0] + "Mantle", of(side + "Mantle"), P, sh + (0, 0.5, 0), (0, 0, 1), unit(el - sh), 3, 1, "UpperTorso"))
            sheets.append(ring(side[0] + "Sleeve", of(side + "UpperArm"), P, sh, el - sh, (0, 0, 1), 3, 1, 0.24, True, anchor=side + "UpperArm"))
    else:
        sheets.append(fan("Hair", of("HairBack"), P, (0.0, 1.75, -0.05), (1, 0, 0), (0, 0.45, 0.9), 5, 3, "Head", span=(-1.5, 1.5)))
        sheets.append(fan("Beard", of("Beard"), P, (-0.05, 1.5, -0.3), (1, 0, 0), (0, -0.7, 0.2), 3, 2, "Head"))
        sheets.append(fan("RagSleeve", of("LeftSleeve"), P, a(J.LSH) + (0, 0.15, 0), (0, 0, 1), (-0.55, -0.85, 0), 3, 2, "LeftUpperArm"))
        sheets.append(spans("RagRibbonR", of("RibbonRight"), P, a(J.RWR) + (0.1, 0.05, 0.05), (1.45, -0.8, 0.2), 1, 3, "RightLowerArm"))
        sheets.append(spans("RagRibbonL", of("RibbonLeft"), P, a(J.LWR) + (-0.15, 0.2, 0), (-1.75, -0.95, -0.4), 2, 2, "LeftLowerArm", across=(0, 1, 0)))
    # ------------------------------------------------------------ skeleton
    bones = [{"name": "Root", "at": [0, 0, 0]}]
    index = {"Root": 0}
    for n in LIMBS:
        index["Sk_" + n] = len(bones)
        bones.append({"name": "Sk_" + n, "limb": n})
    limb_at = {"LowerTorso": J.PELVIS, "UpperTorso": J.WAIST, "Head": J.NECK, "RightUpperArm": J.RSH, "RightLowerArm": J.REL, "RightHand": J.RWR, "LeftUpperArm": J.LSH, "LeftLowerArm": J.LEL, "LeftHand": J.LWR,
               "RightUpperLeg": J.RHIP, "RightLowerLeg": J.RKN, "RightFoot": J.RAN, "LeftUpperLeg": J.LHIP, "LeftLowerLeg": J.LKN, "LeftFoot": J.LAN}
    for b in bones[1:]:
        b["at"] = [float(x) for x in limb_at[b["limb"]]]
    particles, links, cloth_sheets = [], [], []
    hip = {"Right": a(J.RHIP), "Left": a(J.LHIP)}
    knee = {"Right": a(J.RKN), "Left": a(J.LKN)}
    pid = {}
    for s in sheets:
        kind, T = tune_of(s.name)
        C, Rw = s.cols, s.rows + 1
        for r in range(Rw):
            for c in range(C):
                f = r / max(Rw - 1, 1)
                p = s.rest[c, r]
                pin = r == 0
                part = {"sheet": s.name, "c": c, "r": r, "at": [round(float(x), 4) for x in p], "pin": pin, "anchor": s.anchor,
                        "shape": round(T["shape"][0] + (T["shape"][1] - T["shape"][0]) * f, 4), "reach": round(T["reach"][0] + (T["reach"][1] - T["reach"][0]) * f, 3),
                        "drag": round(T["drag"][0] + (T["drag"][1] - T["drag"][0]) * f, 3)}
                if T["legs"][0] > 0 and r > 0:
                    side = "Right" if p[0] - J.PELVIS[0] > 0 else "Left"
                    below = max(0.0, min(1.0, (hip[side][1] - p[1]) / max(hip[side][1] - knee[side][1], 0.1)))
                    # how much it follows the leg: strongest in front and at the sides, off the legs behind, and only near the leg itself
                    th = abs(math.atan2(p[0] - J.PELVIS[0], p[2] - J.PELVIS[2])) / math.pi
                    away = float(np.linalg.norm(p - knee[side]))
                    mix = (T["legs"][0] + (T["legs"][1] - T["legs"][0]) * f) * below * float(sstep(np.array(th), 0.28, 0.6)) * float(1 - sstep(np.array(away), 1.1, 2.0))
                    if mix > 0.02:
                        part["anchor2"], part["mix"] = side + "UpperLeg", round(mix, 3)
                if s.name in ("Hair",) and r > 0:
                    part["anchor2"], part["mix"] = "UpperTorso", round(0.72 * f, 3)   # a head turn slides over hair that lies on his back
                if s.name.endswith("Sleeve") and "Mantle" not in s.name and phase == 1:
                    part["anchor2"], part["mix"] = s.anchor.replace("Upper", "Lower"), 0.5
                pid[(s.name, c, r)] = len(particles)
                if not pin:
                    part["bone"] = len(bones)
                    bones.append({"name": f"Cl_{s.name}_{c}_{r}", "at": part["at"]})
                    index[bones[-1]["name"]] = part["bone"]
                particles.append(part)
        ncol = C if s.closed else C - 1
        for r in range(Rw):
            for c in range(C):
                here = pid[(s.name, c, r)]
                if r + 1 < Rw:
                    links.append((here, pid[(s.name, c, r + 1)], T["along"]))
                if r + 2 < Rw:
                    links.append((here, pid[(s.name, c, r + 2)], T["bend"]))
                if c < ncol and C > 1:
                    links.append((here, pid[(s.name, (c + 1) % C, r)], T["across"]))
                    if r + 1 < Rw:
                        links.append((here, pid[(s.name, (c + 1) % C, r + 1)], T["across"] * 0.45))
        cloth_sheets.append({"name": s.name, "kind": kind, "cols": C, "rows": s.rows, "closed": s.closed, "first": pid[(s.name, 0, 0)]})
    orbs = [n for n in ("Bead1", "Bead2", "Bead3") if n in J.NAMES]
    orb_bone = {}
    for k, n in enumerate(orbs):    # phase 2's floating orbs: free bodies circling his head, one bone each
        at = P[of(n)].mean(0)
        i = len(particles)
        orb_bone[n] = len(bones)
        bones.append({"name": f"Orb_{k + 1}", "at": [round(float(x), 4) for x in at]})
        index[bones[-1]["name"]] = orb_bone[n]
        particles.append({"sheet": "Orbs", "c": k, "r": 0, "at": bones[-1]["at"], "pin": False, "anchor": "Head", "shape": 0, "reach": 99, "drag": 0, "bone": orb_bone[n], "uA": i, "uB": i, "vA": i, "vB": i,
                          "orb": {"k": k, "n": len(orbs), "around": [round(float(x), 3) for x in a(J.NECK) + (0, 0.6, 0)], "radius": 1.45}})
    # the left hand closes on the haft: two bones through the fingers, curled whenever the palm is on the wood
    hw, ha, hx, hp, hk, hm, hg = RD.left_hand(J, P[of("LeftHand")])
    finger_bone = {}
    for k, (nm, dist, curl) in enumerate((("Fing1", hk, 62.0), ("Fing2", hm, 70.0))):
        at = hw + ha * dist + hp * 0.02
        i = len(particles)
        finger_bone[nm] = len(bones)
        bones.append({"name": f"Sk_L{nm}", "at": [round(float(x), 4) for x in at]})
        index[bones[-1]["name"]] = finger_bone[nm]
        particles.append({"sheet": "Fingers", "c": k, "r": 0, "at": bones[-1]["at"], "pin": False, "anchor": "LeftHand", "shape": 0, "reach": 99, "drag": 0, "bone": finger_bone[nm], "uA": i, "uB": i, "vA": i, "vB": i,
                          "finger": {"chain": k, "curl": curl, "axis": [round(float(x), 4) for x in hx]}})
    cloth_sheets.append({"name": "Fingers", "kind": "Fingers", "cols": 2, "rows": 0, "closed": False, "first": len(particles) - 2})
    grip = {"palm": [round(float(x), 4) for x in hg], "butt": [float(x) for x in J.BUTT], "socket": [float(x) for x in J.SOCKET], "tip": [float(x) for x in np.array(J.SOCKET) + 2.4 * unit(np.array(J.SOCKET) - np.array(J.BUTT))]}
    if orbs:
        cloth_sheets.append({"name": "Orbs", "kind": "Orbs", "cols": len(orbs), "rows": 0, "closed": False, "first": len(particles) - len(orbs)})
    # the frame of each free particle: its neighbours across and along
    for s in sheets:
        C, Rw = s.cols, s.rows + 1
        for r in range(1, Rw):
            for c in range(C):
                here = particles[pid[(s.name, c, r)]]
                cp = (c - 1) % C if s.closed else max(c - 1, 0)
                cn = (c + 1) % C if s.closed else min(c + 1, C - 1)
                here["uA"], here["uB"] = pid[(s.name, cp, r)], pid[(s.name, cn, r)]
                here["vA"], here["vB"] = pid[(s.name, c, r - 1)], pid[(s.name, c, min(r + 1, Rw - 1))]
    out = os.path.join(ROOT, "work/shen_import")
    if not CLOTH_ONLY:   # weights never depend on the tuning, and healing them takes minutes
        # ------------------------------------------------------------ weights
        joints = np.zeros((n_w, 4), np.int32)
        weights = np.zeros((n_w, 4))
        # start from the body
        order = np.argsort(-body, axis=1)[:, :4]
        bw = np.take_along_axis(body, order, 1)
        joints[:, :] = order + 1      # Sk_ bones follow Root in LIMBS order
        weights[:, :] = bw / bw.sum(1, keepdims=True)
        for s in sheets:
            C = s.cols
            inf = s.influences()
            mix = sstep(s.v, 0.0, 0.55)      # the attachment grows from the body's own weights into the lattice, so nothing tears at the belt or the scalp
            anchor_bone = index["Sk_" + s.anchor]
            for k, vid in enumerate(s.ids):
                w = {}
                b0 = body[vid]
                for i in np.nonzero(b0 > 1e-4)[0]:
                    w[int(i) + 1] = w.get(int(i) + 1, 0) + float(b0[i]) * (1 - mix[k])
                for cc, rr, tent in inf:
                    t = float(tent[k])
                    if t < 1e-5:
                        continue
                    r_, c_ = int(rr[k]), int(cc[k])
                    bone = anchor_bone if r_ == 0 else index[f"Cl_{s.name}_{c_}_{r_}"]
                    w[bone] = w.get(bone, 0) + t * mix[k]
                top = sorted(w.items(), key=lambda x: -x[1])[:4]
                tot = sum(x[1] for x in top)
                joints[vid] = [x[0] for x in top] + [0] * (4 - len(top))
                weights[vid] = [x[1] / tot for x in top] + [0] * (4 - len(top))
        joints, weights = heal(joints, weights, tv, len(bones))
        # the fingers: the hand's far half follows the two curl bones, blending across each knuckle
        at = of("LeftHand")
        dist = (P[at] - hw) @ ha
        w1 = sstep(dist, hk - 0.03, hk + 0.03) * (1 - sstep(dist, hm - 0.03, hm + 0.03))
        w2 = sstep(dist, hm - 0.03, hm + 0.03)
        w0 = 1 - w1 - w2
        moved = (w1 + w2) > 1e-3
        ids = at[moved]
        hand_bone = index["Sk_LeftHand"]
        joints[ids] = 0
        weights[ids] = 0
        joints[ids, 0], joints[ids, 1], joints[ids, 2] = hand_bone, finger_bone["Fing1"], finger_bone["Fing2"]
        weights[ids, 0], weights[ids, 1], weights[ids, 2] = w0[moved], w1[moved], w2[moved]
        for n in orbs:
            at = of(n)
            joints[at] = 0
            weights[at] = 0
            joints[at, 0] = orb_bone[n]
            weights[at, 0] = 1
        weights[weights < 1e-4] = 0
        weights /= weights.sum(1, keepdims=True)
        joints[weights == 0] = 0
        np.savez_compressed(os.path.join(out, f"skin_p{phase}.npz"), joints=joints[weld].astype(np.uint8), weights=weights[weld].astype(np.float32))
    # ------------------------------------------------------------ colliders: rest-space capsules on limbs (a, b, radius)
    def cap(n, x, y, r, firm=True):   # firm: the cloth stays out at the full radius even where the sculpt had it closer: the sculpt stood wide-legged, he does not
        return {"limb": n, "a": [round(float(v), 3) for v in x], "b": [round(float(v), 3) for v in y], "r": r, "firm": firm}
    colliders = [cap("RightUpperLeg", J.RHIP, J.RKN, 0.5), cap("LeftUpperLeg", J.LHIP, J.LKN, 0.5), cap("RightLowerLeg", J.RKN, J.RAN, 0.34), cap("LeftLowerLeg", J.LKN, J.LAN, 0.34),
                 cap("LowerTorso", a(J.PELVIS) + (0, -0.25, 0), J.WAIST, 0.58, False), cap("UpperTorso", J.WAIST, a(J.NECK) + (0, -0.2, 0), 0.62, False), cap("Head", a(J.NECK) + (0, 0.3, 0), a(J.NECK) + (0, 0.6, -0.05), 0.42, False),
                 cap("RightLowerLeg", a(J.RKN) + (0, -0.2, 0), a(J.RKN) + (0, -0.5, 0), 0.76), cap("LeftLowerLeg", a(J.LKN) + (0, -0.2, 0), a(J.LKN) + (0, -0.5, 0), 0.76),   # the baggy trouser blousing below the knee
                 # what the arms and the glaive sweep through: the cloth lattice is coarse, so these stand a little proud of the arm itself
                 # (2026-11-06) not firm: a sleeve, rag or mantle that rests on an arm in the sculpt keeps that clearance instead of being lifted off it
                 cap("RightUpperArm", J.RSH, J.REL, 0.34, False), cap("RightLowerArm", J.REL, J.RWR, 0.34, False), cap("RightHand", J.RWR, a(J.RWR) + unit(a(J.RGRIP) - a(J.RWR)) * 0.3, 0.42, False),
                 cap("LeftUpperArm", J.LSH, J.LEL, 0.34, False), cap("LeftLowerArm", J.LEL, J.LWR, 0.34, False), cap("LeftHand", J.LWR, J.LHAND, 0.42, False),
                 cap("Glaive", J.BUTT, J.SOCKET, 0.3),
                 # (2026-11-06) the blade is solid to the cloth as well as the haft
                 cap("Glaive", a(J.SOCKET) + unit(a(J.SOCKET) - a(J.BUTT)) * 0.2, a(J.SOCKET) + unit(a(J.SOCKET) - a(J.BUTT)) * 2.2, 0.22, False)]
    arms = [9, 10, 11, 12, 13, 14, 15, 16]
    # (2026-11-06) every garment avoids every volume it can reach: hair and beads the arms and weapon, sleeves the torso and weapon; the mantle lies on the upper arm, whose firm volume would lift it off (a garment resting inside a volume at rest keeps that clearance, ClothSim)
    # (2026-11-06, later) the arm volumes are no longer firm, so every garment avoids both arms too: the torn phase 2 sleeves (Rag) also the legs and hips
    legs = [0, 1, 2, 3, 4, 7, 8]
    hits = {"Coat": legs + arms, "Under": legs + arms, "Hair": [5, 6, 15, 16] + arms, "Beard": [5, 15, 16] + arms, "Beads": [5, 15, 16] + arms,
            "Mantle": [5, 15, 16] + arms, "Sleeve": [4, 5, 15, 16] + arms, "Rag": [5, 15, 16] + legs + arms, "Orbs": [], "Fingers": []}
    cloth = {"phase": phase, "bones": bones, "sheets": cloth_sheets, "particles": particles, "links": [[i, j, round(k, 3)] for i, j, k in links], "colliders": colliders, "hits": hits, "limbs": LIMBS + ["Glaive"], "grip": grip}
    # rest length of every link
    for L in cloth["links"]:
        L.insert(2, round(float(np.linalg.norm(np.array(particles[L[0]]["at"]) - np.array(particles[L[1]]["at"]))), 4))
    with open(os.path.join(out, f"cloth_p{phase}.json"), "w") as f:
        json.dump(cloth, f)
    if CLOTH_ONLY:
        print(f"P{phase}: cloth tuning rewritten, {len(bones)} bones, weights untouched")
        return cloth
    nb = (joints > 0).sum(1)
    print(f"P{phase}: {len(bones)} bones ({sum('bone' in p for p in particles)} cloth), {len(particles)} particles, {len(links)} links; welded verts {n_w}, influences max {nb.max()} mean {nb.mean():.2f}; coat {len(ids_c)} under {len(ids_u)}")
    return cloth


if __name__ == "__main__":
    for ph in [int(x) for x in sys.argv[1:] if x.isdigit()] or [1, 2]:
        build(ph)

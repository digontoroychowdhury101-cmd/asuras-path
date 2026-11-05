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
import rigspace as RS  # noqa: E402
import segment as Seg  # noqa: E402

LIMBS = ["LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
         "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]
RIGID = {"Weapon", "Bead1", "Bead2", "Bead3"}          # welded props, not skinned
CARRIER = {"RobeBack": "LowerTorso", "RobeRight": "LowerTorso", "RobeLeft": "LowerTorso", "RobeInner": "LowerTorso", "RobeFront": "LowerTorso", "HairBack": "Head", "Beard": "Head", "Beads": "UpperTorso",
           "RightMantle": "UpperTorso", "LeftMantle": "UpperTorso", "LeftSleeve": "LeftUpperArm", "RibbonRight": "RightLowerArm", "RibbonLeft": "LeftLowerArm"}


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
    "Coat": dict(shape=(0.1, 0.005), reach=(0.22, 1.5), drag=(0.5, 1.15), legs=(0.12, 0.1), along=0.95, across=0.5, bend=0.18),
    "Under": dict(shape=(0.2, 0.05), reach=(0.18, 0.7), drag=(0.4, 0.7), legs=(0.5, 0.8), along=0.95, across=0.42, bend=0.2),
    "Hair": dict(shape=(0.1, 0.018), reach=(0.14, 1.1), drag=(0.4, 1.05), legs=(0, 0), along=0.96, across=0.34, bend=0.3),
    "Beard": dict(shape=(0.16, 0.05), reach=(0.06, 0.35), drag=(0.25, 0.5), legs=(0, 0), along=0.97, across=0.4, bend=0.3),
    "Beads": dict(shape=(0.2, 0.09), reach=(0.05, 0.28), drag=(0.03, 0.05), legs=(0, 0), along=0.98, across=0.4, bend=0.1),
    "Mantle": dict(shape=(0.24, 0.1), reach=(0.05, 0.3), drag=(0.25, 0.55), legs=(0, 0), along=0.95, across=0.4, bend=0.1),
    "Sleeve": dict(shape=(0.26, 0.18), reach=(0.05, 0.3), drag=(0.25, 0.45), legs=(0, 0), along=0.9, across=0.4, bend=0.1),
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


def build(phase):
    J = LM.PHASES[phase]
    g = glb.Glb(Seg.source(phase))
    lab = np.load(os.path.join(ROOT, f"work/shen_import/labels_p{phase}.npy"))
    V = RS.to_rig(g.pos, phase)
    weld = glb.weld(V, 1e-4)
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
    carrier = np.array([limb[CARRIER.get(n, n)] if n not in RIGID else limb.get("RightHand") for n in J.NAMES])
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
        sheets.append(fan("Hair", of("HairBack"), P, (-0.12, 2.05, 0.2), (1, 0, 0), (0, -0.9, 0.42), 5, 4, "Head"))
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
                        if s.name == "Under":   # the panel over the knee rides the leg closely, so the baggy trouser stays under it instead of through it; only the back of this tier flows
                            part["mix"] = round(min(1.0, mix * 1.3), 3)
                            part["shape"] = round(max(part["shape"], 0.34 * min(1.0, mix * 1.3)), 4)
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
        # the trouser the sculpt fused into the robe tier: near-black and inside the robe, it belongs to the thigh. Left on the lattice it would stretch across the ivory as a black smear.
        _, _, _, val = Seg.sample_colour(g, phase)
        shade, count = np.zeros(n_w), np.zeros(n_w)
        for c in range(3):
            np.add.at(shade, tv[:, c], val)
            np.add.at(count, tv[:, c], 1)
        shade /= np.maximum(count, 1)
        hipline = max(J.RHIP[1], J.LHIP[1]) - 0.15
        trouser = np.zeros(n_w, bool)
        trouser[ids_u] = (shade[ids_u] < 0.2) & (P[ids_u, 1] < hipline) & (np.linalg.norm(P[ids_u][:, [0, 2]] - a(J.PELVIS)[[0, 2]], axis=1) < 0.95)
        thigh = np.where(P[:, 0] - J.PELVIS[0] > 0, limb["RightUpperLeg"], limb["LeftUpperLeg"])
        at_thigh = np.nonzero(trouser)[0]
        body[at_thigh] = body_weights(J, P[at_thigh], thigh[at_thigh])
        print(f"  {len(at_thigh)} trouser vertices returned to the thighs")
        order = np.argsort(-body, axis=1)[:, :4]
        bw = np.take_along_axis(body, order, 1)
        joints[:, :] = order + 1      # Sk_ bones follow Root in LIMBS order
        weights[:, :] = bw / bw.sum(1, keepdims=True)
        for s in sheets:
            C = s.cols
            inf = s.influences()
            mix = sstep(s.v, 0.0, 0.55) * ~trouser[s.ids]      # the attachment grows from the body's own weights into the lattice, so nothing tears at the belt or the scalp
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
        weights[weights < 1e-4] = 0
        weights /= weights.sum(1, keepdims=True)
        joints[weights == 0] = 0
        np.savez_compressed(os.path.join(out, f"skin_p{phase}.npz"), joints=joints[weld].astype(np.uint8), weights=weights[weld].astype(np.float32))
    # ------------------------------------------------------------ colliders: rest-space capsules on limbs (a, b, radius)
    def cap(n, x, y, r):
        return {"limb": n, "a": [round(float(v), 3) for v in x], "b": [round(float(v), 3) for v in y], "r": r}
    colliders = [cap("RightUpperLeg", J.RHIP, J.RKN, 0.38), cap("LeftUpperLeg", J.LHIP, J.LKN, 0.38), cap("RightLowerLeg", J.RKN, J.RAN, 0.28), cap("LeftLowerLeg", J.LKN, J.LAN, 0.28),
                 cap("LowerTorso", a(J.PELVIS) + (0, -0.25, 0), J.WAIST, 0.58), cap("UpperTorso", J.WAIST, a(J.NECK) + (0, -0.2, 0), 0.62), cap("Head", a(J.NECK) + (0, 0.3, 0), a(J.NECK) + (0, 0.6, -0.05), 0.42),
                 cap("RightUpperLeg", a(J.RKN) + (0, 0.1, 0), a(J.RKN) + (0, -0.1, 0), 0.56), cap("LeftUpperLeg", a(J.LKN) + (0, 0.1, 0), a(J.LKN) + (0, -0.1, 0), 0.56)]   # the baggy trouser at the knee
    hits = {"Coat": [0, 1, 2, 3, 4, 7, 8], "Under": [0, 1, 2, 3, 4, 7, 8], "Hair": [5, 6], "Beard": [5], "Beads": [5], "Mantle": [], "Sleeve": [], "Rag": []}
    cloth = {"phase": phase, "bones": bones, "sheets": cloth_sheets, "particles": particles, "links": [[i, j, round(k, 3)] for i, j, k in links], "colliders": colliders, "hits": hits, "limbs": LIMBS}
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

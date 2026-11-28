"""Bellwood landmark: the hero tree's root grip on the colossal temple's lower terraces (WINDOWS_HANDOFF_2026-11-26 open
item 3, CLAUDE_BELLWOOD_REPLACEMENT_HANDOFF "Finish the art" step 2). Below z 160 the v20 pack's roots are thin, even,
round sweeps lying side by side on the treads, and in game they look like hoses. This model replaces every bark face
under z 160 (the pack's Roots02-07 and BarkTwigs03/05/07 sections) with braided, flattened roots that melt onto the stone.

  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_root_grip.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_root_grip      env: ROOT_MODE=clay|bake, ROOT_FLOWS=RootL1,RootR2

Method (replaces the v12/v13 procedural cling and the v17-v20 swept tubes):
  1. Rebuild the temple's stone, then run the recipe's own aged_tree from stair_reference.py, unchanged, to read SPINE.
     SPINE gives the centreline and radius of every root at the z 160 cut. Each new root starts on those rings, a
     little thicker, so it swallows the cut end of the section kept above.
  2. Route each strand through authored stations on the flank terraces: the platform lip, then each terrace lip, face
     and foot. Then drape it: snap every sample onto the nearest stone (a BVH of the recipe's masonry, crags, tiles and
     soffits), smooth, and snap again. No span is left hanging in the air.
  3. Build each flow as one SDF. A strand is a capsule chain whose cross-section flattens along the stone normal. A thin,
     wide sole under each strand melts it onto the stone. The strands of a flow weave about each other and fuse with a
     smooth union, then part into a net. Gripping fingers fan out across the treads and bury their tips in the joints.
  4. LOW is the surface net of that field. HIGH is the LOW subdivided, with fluted bark grain cut along each strand plus
     fine bark noise. Cycles bakes HIGH to LOW at 2048 per flow, on Poly Haven bark_willow_02 (CC0).
Units are studs, Z up, in the recipe's own axes and origin. The model places in the temple pack's frame (LandmarkWorld).
"""
import math
import os
import random
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "vesperhold"))
ROOT = HERE.parents[2]
REC = ROOT / "assets/source/landmarks/bellwood_temple_colossal"
sys.path.insert(0, str(REC))
import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402
from mathutils.kdtree import KDTree  # noqa: E402

import bellwood_colonnade as C  # noqa: E402  (high)
import bellwood_footings as FT  # noqa: E402  (cpu_cycles)
import bellwood_temple_hall as H  # noqa: E402  (src)
import vesperhold_figures as FG  # noqa: E402
import vesperhold_gargoyles as G  # noqa: E402  (SDF field, surface nets, bake + export)
from vesperhold_figures import log  # noqa: E402

NAME = "Bellwood_RootGrip"
BUILDER = "tools/blender/landmarks/bellwood_root_grip.py (win-113, braided SDF roots draped on the recipe's stone)"
ZCUT = 160.0  # preserve_pack bins bark faces by floor(z / 160): everything under this is Roots02-07 / BarkTwigs03-07
H_LOW = 0.95
STONE = ("Masonry", "Crag", "Tile", "Soffit", "DarkStone")
# Where the pack cut the eight terrace roots (recipe coords, read from SPINE in work/win-113/spine.json)
CUTS = {"A": (114.3, -86.7, 161.2), "B": (146.9, -84.0, 162.4), "C": (86.2, -70.8, 163.9), "D": (158.0, -47.8, 160.8),
        "E": (-128.6, -89.9, 160.8), "F": (-141.2, -77.7, 162.9), "G": (-81.4, -75.7, 161.1), "H": (-164.5, -61.5, 162.8)}


# --------------------------------------------------------------------------------------------- recipe and stone
def recipe():
    """The temple's stone and tree exactly as the recipe builds them (same call order as its main)."""
    import stair_reference as S
    bpy.ops.wm.read_factory_settings(use_empty=True)
    temple = S.Hall()
    S.stonework(temple)
    for x, y, z, w, d, ht, bays, arch in S.TIERS:
        S.pavilion(temple, (x, y, z), w, d, ht, bays, arch=arch)
    S.galleries(temple)
    for x, y, z in ((-34, -44, 113), (34, -44, 113), (-84, -44, 113), (84, -44, 113)):
        S.lantern(temple, (x, y, z), 1.0)
    for x in (-22, 22):
        S.gate_lantern(temple, x, -46, 146)
    S.crags(temple)
    S.root_buttress(temple)
    S.aged_tree(temple)
    return S, temple


class Stone:
    """Nearest stone surface over the recipe's architecture, with outward normals."""

    def __init__(self, temple):
        self.trees = []
        for r in STONE:
            if r not in temple.meshes:
                continue
            src = temple.m(r)
            bm = src.finish()  # recalculates the closed blocks' normals outward
            bm.faces.ensure_lookup_table()
            opened = [bool(f[src.open]) for f in bm.faces]
            self.trees.append((BVHTree.FromBMesh(bm), opened))

    def nearest(self, p, reach):
        """(point, outward normal, distance) or None. Open sheets have no inside: their normal faces the query."""
        best = None
        for t, opened in self.trees:
            q, n, i, d = t.find_nearest(p, reach)
            if q is not None and (best is None or d < best[2]):
                if opened[i] and (p - q).dot(n) < 0:
                    n = -n
                best = (q, n.normalized(), d)
        return best


def terraces(S, side):
    """[(front, top, x0, x1)] for the platform (index 0) and the seven flank terraces on one side, highest first."""
    fl = sorted((f for f in S.FLANKS if f[0] * side > 0), key=lambda f: f[4], reverse=True)
    return [(-40.0, 112.4, -260.0, 260.0)] + [(f[3], f[4], f[0], f[1]) for f in fl]


def seam(S, letter, lo=ZCUT - 6.0, hi=ZCUT + 14.0):
    """The cut root's own rings from z 174 down to z 154, trunk side first: (centres, sleeve radii).
    The sleeve starts inside the kept tube (0.9x) and grows to 1.12x + 0.4 by z 166, so it hides the open cut at z 160."""
    cut = Vector(CUTS[letter])
    near = min((r for r in S.SPINE if 156 <= r[0].z <= 168), key=lambda r: (r[0] - cut).length)
    assert (near[0] - cut).length < 3.0, f"root {letter}: nearest ring {tuple(near[0])} is off the recorded cut"
    path = sorted((r for r in S.SPINE if r[7] == near[7]), key=lambda r: r[5])
    i = path.index(near)
    a = i
    while a > 0 and lo <= path[a - 1][0].z <= hi:
        a -= 1
    b = i
    while b < len(path) - 1 and lo <= path[b + 1][0].z <= hi:
        b += 1
    run = path[a:b + 1]
    if run[0][0].z < run[-1][0].z:
        run.reverse()
    assert len(run) >= 3, f"root {letter} has no rings at the cut"
    Cs, Rs = [], []
    for r in run:
        t = min(1.0, max(0.0, (hi - r[0].z) / 8.0))
        Cs.append(Vector(r[0]))
        Rs.append(float(r[4]) * (0.9 + 0.22 * t) + 0.4 * t)
    return Cs, Rs


def v20_route(S, letter, step=10.0, stop_y=-46.0):
    """The v20 guide's own course from under the cut to the platform lip, every `step` studs. Those guides were drawn
    around the side shrines and the hall's supports; the new roots keep that route and only change form below it."""
    cut = Vector(CUTS[letter])
    near = min((r for r in S.SPINE if 156 <= r[0].z <= 168), key=lambda r: (r[0] - cut).length)
    path = sorted((r for r in S.SPINE if r[7] == near[7]), key=lambda r: r[5])
    i = path.index(near)
    seq = path[i:] if i + 1 < len(path) and path[i + 1][0].z < path[i][0].z else path[:i + 1][::-1]
    out, last = [], None
    for r in seq:
        if r[0].y > stop_y:
            break
        if r[0].z < ZCUT - 9.0 and (last is None or (r[0] - last).length >= step):
            out.append(Vector(r[0]))
            last = r[0]
    return out


# ------------------------------------------------------------------------------------------------- routes
def course(T, side, start, lips, end, rng, wander=2.5):
    """Waypoints from start down the terraces. lips = [(j, x)] or [(j, x, x_from)]: cross the lip of terrace j at x and
    descend its face to terrace j + 1; with x_from the root first runs along the coping from x_from. end = ("toe", x)
    runs off the last terrace into the water; ("tread", x, back) stops on the tread below the last lip, `back` studs in
    front of that lip's wall."""
    W = [Vector(p) for p in start]
    jit = lambda a: rng.uniform(-a, a)  # noqa: E731
    for n, lip in enumerate(lips):
        j, x = lip[0], lip[1]
        front, top = T[j][0], T[j][1]
        lo = T[j + 1][1] if j + 1 < len(T) else 0.0
        h = top - lo
        nxt = lips[n + 1][1] if n + 1 < len(lips) else end[1]
        d = math.copysign(1.0, nxt - x) if abs(nxt - x) > 1.0 else rng.choice((-1.0, 1.0))
        drift = min(abs(nxt - x), 0.45 * h) * d  # the root slants across the face toward where it goes next
        if len(lip) > 2:
            W += [Vector((lip[2], front - 1.0, top + 2.2)), Vector(((lip[2] + x) / 2, front - 0.8, top + 2.3))]
        elif j > 0 or n > 0:
            ty = (T[j - 1][0] if j > 0 else front - 20.0)
            W.append(Vector((x - drift * 0.6 + jit(wander), (ty + front) / 2 + jit(3.0), top + 2.0)))  # S across the tread
        W.append(Vector((x, front - 2.5, top + 2.0)))  # on the coping
        if h > 18.0:  # a tall face: the root snakes down it in an S instead of hanging straight
            sw = rng.uniform(0.12, 0.22) * h * rng.choice((-1.0, 1.0))
            W += [Vector((x + drift * 0.25 + sw, front + 2.0, top - 0.3 * h)),
                  Vector((x + drift * 0.7 - sw * 0.8, front + 2.0, top - 0.68 * h))]
        else:
            W.append(Vector((x + drift * 0.5 + jit(0.8), front + 2.0, top - 0.45 * h)))  # slanting down the face
        W.append(Vector((x + drift + jit(0.8), front + 6.0, lo + 2.5)))  # a wide elbow onto the tread below
    if end[0] == "toe":
        if lips[-1][0] + 1 < len(T):
            W += [Vector((end[1], T[-1][0] + 1.3, 3.2)), Vector((end[1] + side * 1.5, T[-1][0] + 5.8, 0.6))]
        W.append(Vector((end[1] + side * 2.5, T[-1][0] + 11.0, -1.2)))
    else:
        j = lips[-1][0] + 1
        W.append(Vector((end[1], T[j - 1][0] + end[2], T[j][1] + 1.0)))
    return W


def catmull(W, step):
    P = []
    for i in range(len(W) - 1):
        p0, p1, p2, p3 = (W[min(len(W) - 1, max(0, k))] for k in (i - 1, i, i + 1, i + 2))
        n = max(1, int(math.ceil((p2 - p1).length / step)))
        for k in range(n):
            t = k / n
            P.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                            + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t))
    P.append(W[-1].copy())
    return P


class Strand:
    def __init__(self, name, W, r0, r1, lock=0, seam_r=None, braid=None, flat=0.55, wide=1.45, tip=False):
        self.name, self.W, self.r0, self.r1, self.lock = name, W, r0, r1, lock
        self.seam_r, self.braid, self.flat, self.wide, self.tip = seam_r, braid, flat, wide, tip


def drape(st, stone):
    """Dense centreline on the stone. Returns dict: C centres, R radii, N contact normals, F flat, W wide, s arc length,
    lock (samples kept on the recipe's rings), gap (worst distance from the stone after draping)."""
    P = catmull(st.W, 0.9)
    n = len(P)
    s = np.concatenate([[0.0], np.cumsum([(P[i + 1] - P[i]).length for i in range(n - 1)])])
    L = max(s[-1], 1e-3)
    lock = 0
    if st.lock:
        end = st.W[st.lock - 1]
        lock = 1 + max(k for k in range(n) if (P[k] - end).length < 1e-3 or k == 0)
    ph = (hash(st.name) % 628) / 100.0
    R = np.array([st.r1 + (st.r0 - st.r1) * (1 - si / L) ** 0.65 for si in s]) * (
        1 + 0.14 * np.sin(s * 0.045 + ph) + 0.05 * np.sin(s * 0.17 + 2 * ph))
    if st.seam_r is not None and lock:
        ring = st.W[:st.lock]
        for k in range(lock):
            R[k] = st.seam_r[min(range(len(ring)), key=lambda i: (ring[i] - P[k]).length)]
        for k in range(lock, n):
            t = min(1.0, (s[k] - s[lock - 1]) / 26.0)
            R[k] = R[lock - 1] * (1 - t) + R[k] * t
    if st.braid is not None:  # lateral weave about the shared course: strands that cross fuse into a braid
        amp, wl, phase, s0, s1 = st.braid
        for k in range(lock, n):
            if s0 <= s[k] <= s1:
                t = P[min(n - 1, k + 1)] - P[max(0, k - 1)]
                b = t.cross(Vector((0, 0, 1)))
                if b.length > 1e-3:
                    env = math.sin(math.pi * (s[k] - s0) / max(1.0, s1 - s0)) ** 0.5
                    P[k] = P[k] + b.normalized() * amp * env * math.sin(math.tau * s[k] / wl + phase)
    N = [Vector((0, 0, 1)) for _ in range(n)]
    for k in range(lock):  # seam rings: their own contact normal is wherever the stone is, if near
        hit = stone.nearest(P[k], R[k] * 2.5)
        if hit:
            N[k] = hit[1].copy()
    off = lambda k: R[k] * 0.42  # noqa: E731  the back of the root sits a little into the stone
    passes = 7
    for it in range(passes):
        for k in range(lock, n):
            hit = stone.nearest(P[k], max(4.0 * R[k], 24.0))
            if hit is None:
                continue
            v = P[k] - hit[0]
            # outside the stone the direction from its nearest point is the rounded normal: over a lip the root
            # wraps the edge at its own thickness instead of flipping between the top and front faces
            nr = v.normalized() if v.length > 0.05 and v.dot(hit[1]) > 0 else hit[1]
            P[k] = hit[0] + nr * off(k)
            N[k] = nr.copy()
        if it < passes - 1:
            Q = [p.copy() for p in P]
            for k in range(max(lock, 1), n - 1):
                P[k] = Q[k] * 0.4 + (Q[k - 1] + Q[k + 1]) * 0.3
    for _ in range(6):  # smooth the contact normals so the flattening turns gently over a lip
        M = [v.copy() for v in N]
        for k in range(max(lock, 1), n - 1):
            N[k] = (M[k - 1] + 2 * M[k] + M[k + 1]).normalized()
    if st.tip:  # the last samples dive into a joint
        for k in range(max(lock, n - 4), n):
            P[k] = P[k] - N[k] * R[k] * 1.4 * (k - (n - 5)) / 4
    up = np.array([max(0.0, min(1.0, (N[k].z - 0.45) / 0.45)) for k in range(n)])
    flat = 0.68 + (st.flat - 0.68) * up  # pressed to a face where it hangs, plank-flat where it lies on a tread
    wide = 1.28 + (st.wide - 1.28) * up
    for k in range(lock):
        flat[k] = wide[k] = 1.0
    for k in range(lock, min(n, lock + 16)):
        t = (k - lock) / 16
        flat[k] = 1.0 + (flat[k] - 1.0) * t
        wide[k] = 1.0 + (wide[k] - 1.0) * t
    gap, gp = 0.0, None
    for k in range(lock, n):
        hit = stone.nearest(P[k], 40.0)
        g = (hit[2] if hit else 40.0) - off(k)
        if g > gap:
            gap, gp = g, tuple(round(c) for c in P[k])
    return {"C": np.array([tuple(p) for p in P]), "R": np.maximum(R, 0.45), "N": np.array([tuple(v) for v in N]),
            "F": flat, "W": wide, "s": s, "lock": lock, "gap": gap, "gp": gp}


# --------------------------------------------------------------------------------------------------- the SDF
def _block(Cb, Rb, Nb, Fb, Wb):
    """Chain of flattened capsules: per sample the cross-section is an ellipse, short along the stone normal."""
    A, B = Cb[:-1], Cb[1:]
    T = B - A
    Ln = np.maximum(np.linalg.norm(T, axis=1), 1e-6)
    T = T / Ln[:, None]

    def fn(P):
        D = np.full(len(P), G.BIG)
        for i in range(len(A)):
            t, l = T[i], Ln[i]
            d = P - A[i]
            u = np.clip(d @ t / l, 0.0, 1.0)
            r = Rb[i] + (Rb[i + 1] - Rb[i]) * u
            f = Fb[i] + (Fb[i + 1] - Fb[i]) * u
            w = Wb[i] + (Wb[i + 1] - Wb[i]) * u
            nn = Nb[i][None, :] * (1 - u)[:, None] + Nb[i + 1][None, :] * u[:, None]
            nn = nn - (nn @ t)[:, None] * t[None, :]
            nn = nn / np.maximum(np.linalg.norm(nn, axis=1), 1e-6)[:, None]
            c = d - (u * l)[:, None] * t[None, :]
            bb = np.cross(t[None, :], nn)
            dn, dw, da = (c * nn).sum(1), (c * bb).sum(1), c @ t
            e = np.sqrt((dn / (r * f)) ** 2 + (dw / (r * w)) ** 2 + (da / (r * f)) ** 2)
            D = np.minimum(D, (e - 1.0) * r * np.minimum(f, w))
        return D
    return fn


def strand_prim(C_, R, N, F, W, block=10):
    parts = []
    for i0 in range(0, len(C_) - 1, block):
        i1 = min(len(C_) - 1, i0 + block)
        sl = slice(i0, i1 + 1)
        ext = (R[sl] * np.maximum(F[sl], W[sl])).max() + 0.3
        parts.append((C_[sl].min(0) - ext, C_[sl].max(0) + ext, _block(C_[sl], R[sl], N[sl], F[sl], W[sl])))
    return G._multi(parts)


def sole(d):
    """A thin, wide sole on the stone under a strand: the root spreads where it grips."""
    C_ = d["C"] - d["N"] * (d["R"] * d["F"] * 0.9)[:, None]
    R = d["R"]
    F = np.full(len(R), 0.16)
    W = np.full(len(R), 1.55)
    return strand_prim(C_[d["lock"]:], R[d["lock"]:], d["N"][d["lock"]:], F[d["lock"]:], W[d["lock"]:])


def fingers(d, rng, every=(40, 64)):
    """Gripping roots. At every foot, where a root comes off a face onto the tread below, it splays: two or three
    spreaders fan across the tread. Sparser ones leave the long runs. Every tip ends buried in a joint."""
    out = []
    C_, R, N = d["C"], d["R"], d["N"]
    n = len(C_)

    def spawn(k, count, scale):
        p, r, nr = Vector(C_[k]), R[k], Vector(N[k])
        t = Vector(C_[min(n - 1, k + 7)]) - p  # where the parent goes next: at a foot, along the tread
        t = (t - nr * t.dot(nr)).normalized()
        b = t.cross(nr).normalized()
        for i in range(count):
            sgn = (1, -1, rng.choice((1, -1)))[i]
            ln = rng.uniform(10, 24) * scale * min(1.6, r / 2.6)
            fw = (t * rng.uniform(0.2, 0.9) + b * sgn * rng.uniform(0.6, 1.0)).normalized()
            bend = b * sgn * rng.uniform(-3, 3)
            W = [p - nr * r * 0.25, p + fw * ln * 0.3 + nr * 0.4, p + fw * ln * 0.65 + bend, p + fw * ln + bend * 1.5]
            out.append(Strand(f"spread{k}_{i}", W, r * rng.uniform(0.42, 0.55), 0.24, flat=0.5, wide=1.4, tip=True))

    feet = [k for k in range(d["lock"] + 6, n - 8) if N[k - 6][2] < 0.35 and N[k][2] > 0.75 and N[k - 1][2] <= 0.75]
    for k in feet:
        if R[k] > 1.2:
            spawn(k, 3 if R[k] > 3.0 else 2, 1.0)
    k = d["lock"] + int(rng.uniform(*every) / 0.9)
    while k < n - 6:
        if R[k] > 1.6 and N[k][2] > 0.75 and all(abs(k - f) > 12 for f in feet):
            spawn(k, 1, 0.8)
        k += int(rng.uniform(*every) / 0.9)
    return out


# ---------------------------------------------------------------------------------------------------- flows
def flows(S):
    """The four flows (left = +x carries the reference's heavy sweep), each a list of Strands."""
    rng = random.Random(1131)
    TL, TR = terraces(S, 1), terraces(S, -1)

    def strand(name, T, side, lips, end, r0, r1, braid=None, wander=2.5):
        """A root from the cut of `name[0]`. Branches of one cut share its seam and the v20 run over the platform, where
        they fuse into one trunk-thick root, and part at the terrace lips into a spreading net."""
        C0, sr = seam(S, name[0])
        W = course(T, side, [*C0, *v20_route(S, name[0])], lips, end, rng, wander)
        return Strand(name, W, r0, r1, lock=len(C0), seam_r=sr, braid=braid)

    F = {}
    # Left main: A (the thickest cut) and C pour down between the hall and the left shrine as one fused mass, then
    # fan out. A wraps the guardian plinth's outer side (plinth x 41-68) and reaches the lake; its branches grip
    # terraces 5 and 6; C and its branch grip the terraces behind the plinth.
    F["RootL1"] = [
        strand("A", TL, 1, [(0, 111), (1, 100), (2, 92), (3, 84), (4, 78), (5, 73), (6, 75), (7, 79)], ("toe", 81), 5.4, 0.9,
               braid=(1.8, 38.0, 0.0, 20.0, 200.0)),
        strand("Aa", TL, 1, [(0, 111), (1, 100), (2, 104), (3, 118), (4, 122)], ("tread", 118, 14.0), 3.2, 0.5, braid=(1.6, 38.0, 2.1, 20.0, 120.0)),
        strand("Ab", TL, 1, [(0, 111), (1, 100), (2, 92), (3, 96), (4, 98), (5, 92)], ("tread", 88, 12.0), 3.0, 0.5, braid=(1.6, 38.0, 4.2, 20.0, 150.0)),
        strand("C", TL, 1, [(0, 96), (1, 89), (2, 80), (3, 66), (4, 60)], ("tread", 56, 8.0), 4.4, 0.7,
               braid=(1.8, 38.0, math.pi, 20.0, 170.0)),
        strand("Ca", TL, 1, [(0, 96), (1, 89), (2, 74), (3, 58)], ("tread", 50, 10.0), 2.6, 0.45, braid=(1.6, 38.0, 5.2, 20.0, 110.0)),
    ]
    # Left outer: B takes the long descent to the water past the shrine; D grips terrace 3; their branches and B2 knit
    # the outer end of the flank into a net.
    F["RootL2"] = [
        strand("B", TL, 1, [(0, 130), (1, 146), (2, 160), (3, 150), (4, 128), (5, 118), (6, 104)], ("toe", 102), 4.6, 0.85, braid=(1.6, 40.0, 0.0, 20.0, 140.0)),
        strand("Ba", TL, 1, [(0, 130), (1, 146), (2, 144), (3, 136)], ("tread", 132, 18.0), 2.8, 0.45, braid=(1.6, 40.0, math.pi, 20.0, 110.0)),
        strand("D", TL, 1, [(0, 152), (1, 170), (2, 176)], ("tread", 178, 24.0), 4.0, 0.7, braid=(1.4, 36.0, 0.0, 20.0, 80.0)),
        strand("Da", TL, 1, [(0, 152), (1, 170), (2, 182)], ("tread", 182, 14.0), 2.6, 0.45, braid=(1.4, 36.0, math.pi, 20.0, 80.0)),
        Strand("B2", course(TL, 1, [Vector((158, 80, 64)), Vector((150, 90, 64))],
                            [(2, 138), (3, 140)], ("tread", 134, 18.0), rng), 2.6, 0.5),
    ]
    # Right main: E and G meet on terrace 1 and braid. E passes the other guardian's plinth (x -68 to -41) and reaches
    # the water; G parts outward and grips terrace 6; their branches spread to either side.
    F["RootR1"] = [
        strand("E", TR, -1, [(0, -109), (1, -104), (2, -96), (3, -86), (4, -80), (5, -74), (6, -76), (7, -78)], ("toe", -80),
               5.0, 0.85, braid=(1.8, 50.0, 0.0, 40.0, 200.0)),
        strand("Ea", TR, -1, [(0, -109), (1, -104), (2, -118), (3, -128), (4, -126)], ("tread", -122, 14.0), 3.0, 0.5, braid=(1.6, 38.0, 2.1, 20.0, 110.0)),
        strand("G", TR, -1, [(0, -89), (1, -96), (2, -92), (3, -88), (4, -110), (5, -118)], ("tread", -120, 12.0), 4.4, 0.6,
               braid=(1.8, 50.0, math.pi, 40.0, 180.0)),
        strand("Ga", TR, -1, [(0, -89), (1, -96), (2, -84), (3, -68), (4, -60)], ("tread", -56, 9.0), 2.6, 0.45, braid=(1.6, 38.0, 4.2, 20.0, 120.0)),
    ]
    # Right outer: F runs along terrace 2's coping before it drops; H keeps to the outer ends with a branch to the
    # flank's far corner. They knot on terrace 4.
    F["RootR2"] = [
        strand("F", TR, -1, [(0, -136), (1, -150), (2, -118, -148), (3, -124)], ("tread", -130, 14.0), 3.4, 0.55, wander=1.0),
        strand("H", TR, -1, [(0, -155), (1, -180), (2, -172), (3, -150)], ("tread", -144, 20.0), 3.0, 0.5),
        strand("Ha", TR, -1, [(0, -155), (1, -180), (2, -190)], ("tread", -172, 16.0), 2.2, 0.4, braid=(1.4, 36.0, math.pi, 20.0, 80.0)),
    ]
    return F


def build_flow(role, strands, stone, rng):
    Fd = G.Field()
    spines, report, nf = [], [], 0
    for n, st in enumerate(strands):
        d = drape(st, stone)
        report.append(f"{st.name} {len(d['C'])} samples r {d['R'].max():.1f}->{d['R'][-1]:.2f} gap {d['gap']:.1f}" + (f" at {d['gp']}" if d['gap'] > 1.0 else ""))
        Fd.u(strand_prim(d["C"], d["R"], d["N"], d["F"], d["W"]), k=0.0 if n == 0 else 1.6)
        Fd.u(sole(d), k=1.2)
        spines.append(d)
        for fg in fingers(d, rng):
            e = drape(fg, stone)
            if e["gap"] > 1.2:
                continue
            Fd.u(strand_prim(e["C"], e["R"], e["N"], e["F"], e["W"]), k=0.8)
            spines.append(e)
            nf += 1
    log(f"{role}: " + "; ".join(report) + f"; {nf} fingers")
    t = time.time()
    D, lo = Fd.grid(H_LOW)
    log(f"{role}: grid {D.shape} {time.time() - t:.0f}s")
    V, Q = G.surface_nets(D, lo, H_LOW)
    del D
    V = G.project(Fd, V, H_LOW)
    ob = G.mesh_from(f"{NAME}__{role}", V, Q)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.02)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.02)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.validate(clean_customdata=False)
    ob.data.shade_smooth()
    return ob, spines


def bury(ob, stone):
    """Drop LOW faces lying deep inside the stone (the root's buried back): they would only cost triangles."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    dead = []
    for f in bm.faces:
        c = f.calc_center_median()
        hit = stone.nearest(c, 3.0)
        if hit is not None and (c - hit[0]).dot(hit[1]) < -1.4 and f.normal.dot(hit[1]) < -0.6:
            dead.append(f)
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.validate(clean_customdata=False)
    return len(dead)


def grain_high(lo, spines, seed):
    """HIGH: the LOW subdivided, with flutes running along each strand and fine bark noise."""
    C.MAX_EDGE = 0.3
    hi = C.high(lo, seed)
    co, nr = G._co_nr(hi)
    pts = np.vstack([d["C"] for d in spines])
    rad = np.concatenate([d["R"] for d in spines])
    nrm = np.vstack([d["N"] for d in spines])
    tan = np.vstack([np.gradient(d["C"], axis=0) for d in spines])
    tan /= np.maximum(np.linalg.norm(tan, axis=1), 1e-6)[:, None]
    kd = KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    idx = np.array([kd.find(p)[1] for p in co])
    c, r, n, t = pts[idx], rad[idx], nrm[idx], tan[idx]
    d = co - c
    d -= (d * t).sum(1)[:, None] * t
    b = np.cross(t, n)
    th = np.arctan2((d * b).sum(1), (d * n).sum(1))
    along = (co * t).sum(1)
    flutes = np.clip(np.round(r * 1.6), 4, 11)
    wob = FG.fbm(co * 0.05, 2, seed + 3)
    groove = np.abs(np.sin(flutes * th * 0.5 + along * 0.035 + 2.0 * wob))
    depth = np.minimum(0.11 * r, 0.55)
    disp = -depth * (1 - FG.sst(0.08, 0.5, groove)) + 0.06 * FG.fbm(co * 0.9, 3, seed + 5)
    hi.data.vertices.foreach_set("co", (co + nr * disp[:, None]).astype(np.float32).ravel())
    hi.data.update()
    return hi


# ---------------------------------------------------------------------------------------------- context render
def context_render(temple, out, tag):
    """The roots in place on the recipe's stone and the kept tree above the cut, from the hero view and close-ups."""
    grey = bpy.data.materials.new("ArchClay")
    grey.use_nodes = True
    bsdf = next(n for n in grey.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.32, 0.33, 0.35, 1)
    bsdf.inputs["Roughness"].default_value = 0.9
    bark = bpy.data.materials.new("KeptBark")
    bark.use_nodes = True
    bsdf = next(n for n in bark.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.16, 0.13, 0.1, 1)
    arch = []
    for role in ("Masonry", "Tile", "Soffit", "Lacquer", "Crag", "DarkStone", "Gold", "Bark", "BarkTwigs", "Ivy", "Moss"):
        if role not in temple.meshes:
            continue
        bm = temple.m(role).finish()
        if role in ("Bark", "BarkTwigs"):  # the pack keeps only the bark above the cut
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < ZCUT], context="FACES")
        me = bpy.data.meshes.new("ctx_" + role)
        bm.to_mesh(me)
        ob = bpy.data.objects.new("ctx_" + role, me)
        ob.data.materials.append(bark if role in ("Bark", "BarkTwigs") else grey)
        bpy.context.scene.collection.objects.link(ob)
        arch.append(ob)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.render.resolution_x, sc.render.resolution_y = 1500, 1000
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.55, 0.6, 0.68, 1)
    bg.inputs[1].default_value = 0.8
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(48), 0, math.radians(200))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    files = []
    for view, eye, look, lens in (("hero", (40, 470, 60), (40, 40, 110), 28), ("left", (215, 255, 70), (100, 110, 50), 30),
                                  ("right", (-215, 250, 72), (-100, 110, 50), 30), ("plinth", (120, 255, 45), (65, 190, 18), 34),
                                  ("cut", (240, 60, 190), (125, -60, 135), 30), ("cutR", (-240, 60, 190), (-125, -60, 135), 30)):
        cam.location = eye
        cam.rotation_euler = (Vector(look) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        cam.data.clip_end = 3000
        f = out / "renders" / f"{NAME}_{tag}_{view}.png"
        sc.render.filepath = str(f)
        bpy.ops.render.render(write_still=True)
        files.append(f.name)
    for ob in arch:
        bpy.data.objects.remove(ob)
    return files


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_root_grip").resolve()
    (out / "renders").mkdir(parents=True, exist_ok=True)
    mode = os.environ.get("ROOT_MODE", "clay")
    only = [s for s in os.environ.get("ROOT_FLOWS", "").split(",") if s]
    FT.cpu_cycles()
    t = time.time()
    S, temple = recipe()
    stone = Stone(temple)
    log(f"recipe rebuilt {time.time() - t:.0f}s; tree roles {sorted(temple.meshes)}")
    rng = random.Random(77)
    lows, spines = {}, {}
    for role, strands in flows(S).items():
        if only and role not in only:
            continue
        lows[role], spines[role] = build_flow(role, strands, stone, rng)
        log(f"{role}: buried {bury(lows[role], stone)} faces; LOW {len(lows[role].data.polygons)} tris")
    if mode == "clay":
        cm = G.clay_mat()
        for o in lows.values():
            o.data.materials.append(cm)
        log("renders", context_render(temple, out, "clay"))
        return
    import vesp_bake as VB
    highs = {}
    for k, (role, lo) in enumerate(lows.items()):
        highs[role] = grain_high(lo, spines[role], 300 + 11 * k)
        highs[role].data.materials.append(VB.hi_material(f"Hi_{role}", H.src("bark_willow_02", "root bark"), tile=7.0))
        VB.unwrap(lo)
        log(f"HIGH {role} {VB.tris(highs[role])} tris")
    look = VB.Look(base=0.2, grime=0.45, edge=0.3, sat=0.45, stone_tint=(0.95, 0.9, 0.84), moss=0.7, moss_open=0.45,
                   moss_col=(0.25, 0.32, 0.12), lichen=0.2, cavity=1.0, rough_base=0.88)
    rkw = {"views": (("q34", 200.0), ("front", 180.0)), "ez": 12.0, "res": (1600, 1000)}
    files, entry = G.finish(NAME, "Bellwood", lows, highs, out, {r: look for r in lows}, {r: (0.5, 1.0) for r in lows},
                            "Poly Haven bark_willow_02 (CC0)",
                            extra={"collision": {}, "replaces": "Bellwood_ColossalTemple Roots02-07 and BarkTwigs03/05/07"},
                            builder=BUILDER, render_kw=rkw)
    G.merge_manifest(out, {NAME: entry}, "Bellwood landmark: hero tree root grip")
    log("files", files, context_render(temple, out, "baked"))


if __name__ == "__main__":
    main()

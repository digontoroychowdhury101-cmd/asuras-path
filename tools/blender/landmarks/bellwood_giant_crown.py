"""Bellwood landmark: the Fallen Giant's crown, roots and rubble (LANDMARK-BUILD-SPEC section 1; concepts bellwood_1/_2).

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_giant_crown.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_face     env: CROWN_MODE=clay|bake  VESP_BAKE_SIZE  VESP_RENDER_SAMPLES

Built on the face's head frame (bellwood_giant_face.py: u crown, v face forward, w ear to ear, +w buried) so every prop hugs the
same skull: a red lacquer band with gold rims round the forehead, a bronze lotus medallion with hanging gold tags, five gothic
tracery spires standing up from the band, a green-tiled eave with gold scroll corners and a bronze bell + red tassel, a bronze
door ring beside the cave, roots draped over the skull onto the ground, and faceted rubble with broken lacquer panels (kept off
the tunnel walkway). Each role is its own SDF -> LOW (projected) + HIGH (weathered) and gets its own 2048 bake; never decimated.
The face GLB is imported for context renders only. Materials: Poly Haven CC0 (rock_04, metal_plate_02, roof_slates_02,
bark_willow_02) graded by vesp_bake.Look.
"""
import math
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "vesperhold"))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
import vesperhold_figures as FG  # noqa: E402
import vesperhold_gargoyles as G  # noqa: E402
from vesperhold_figures import fbm, log  # noqa: E402
import bellwood_giant_face as H  # noqa: E402

ROOT = HERE.parents[2]
NAME = "Bellwood_GiantCrown"
BUILDER = "tools/blender/landmarks/bellwood_giant_crown.py (mac-85, SDF props on the face's head frame, Cycles-baked)"
U0, HW, TH = 20.0, 4.5, 1.0  # band centre (head u, just above the brow as in the concept), half-width, half-thickness
CEN = np.array([0.0, -10.0, 0.0])  # the skull's cross-section centre (v, w); ring rays start at (u, CEN.v, CEN.w)
UP = H.to_head(np.array([0.0, 0.0, 1.0])) - H.to_head(np.zeros(3))  # world up, in the head frame
RNG = np.random.default_rng(85)


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def skull():
    """The face's first three masses (cranium, face, brow): the only ones that reach the band (u 15..25)."""
    F = G.Field()
    E = G.ellip
    F.u(E((22, -14, 0), (42, 36, 32)))
    F.u(E((-16, 10, 0), (44, 34, 31)), k=12)
    F.u(E((9, 34, 0), (8, 8, 28)), k=6)
    return F


def cuts(F):
    """Keep every prop out of the walkable tunnel and below-ground."""
    F.c(H.world_prim(G.tube(H.TUNNEL, [H.TUNNEL_R + 0.5] * len(H.TUNNEL), step=0.6)), k=1.0)
    F.c(H.world_prim((np.array([-200.0, -200.0, -120.0]), np.array([200.0, 200.0, -0.6]), lambda P: P[:, 2] + 0.6)))
    return F


def grad(F, P, e=0.15):
    P = np.atleast_2d(P)
    g = np.stack([(F.eval(P + e * a) - F.eval(P - e * a)) / (2 * e) for a in np.eye(3)], 1)
    return g / np.maximum(np.linalg.norm(g, axis=1), 1e-9)[:, None]


def surf(F, u, th):
    """Surface points + normals of F on rays from the skull axis at head-u `u`, ring angle `th` (0 face-forward, -pi/2 top)."""
    u, th = np.broadcast_arrays(np.atleast_1d(np.asarray(u, float)), np.atleast_1d(np.asarray(th, float)))
    o = np.stack([u, np.full(u.shape, CEN[1]), np.full(u.shape, CEN[2])], -1)
    d = np.stack([np.zeros(u.shape), np.cos(th), np.sin(th)], -1)
    lo, hi = np.zeros(u.shape), np.full(u.shape, 90.0)
    for _ in range(36):
        m = (lo + hi) / 2
        inside = F.eval(o + d * m[:, None]) < 0
        lo, hi = np.where(inside, m, lo), np.where(inside, hi, m)
    p = o + d * lo[:, None]
    return p, grad(F, p)


def surf1(F, u, th):
    p, n = surf(F, u, th)
    return p[0], n[0]


def tangent(th):
    return np.array([0.0, -math.sin(th), math.cos(th)])


def loop(c, e1, e2, r, tr, n=28):
    ph = np.linspace(0, 2 * math.pi, n + 1)
    pts = [c + r * (math.cos(a) * e1 + math.sin(a) * e2) for a in ph]
    return G.tube(pts + [pts[1]], [tr] * (n + 2), step=0.2)


def arch_outline(a, h1, n=9):
    """Equilateral pointed arch of half-span a, springing at h1 (apex h1 + sqrt(3) a); legs run 1.2 below the base."""
    left = [(a + 2 * a * math.cos(f), h1 + 2 * a * math.sin(f)) for f in np.linspace(math.pi, 2 * math.pi / 3, n)]
    right = [(-a + 2 * a * math.cos(f), h1 + 2 * a * math.sin(f)) for f in np.linspace(math.pi / 3, 0, n)]
    return [(-a, -1.2)] + left + right[1:] + [(a, -1.2)]


# --- the parts: each returns {role: [(Field, low_h, high_h), ...]} -----------------------------------------------------------

def band(Fs):
    lo, hi = np.array([U0 - HW - 2, -62.0, -42.0]), np.array([U0 + HW + 2, 52.0, 42.0])
    B = G.Field()
    B.u((lo, hi, lambda P: np.maximum(np.abs(P[:, 0] - U0) - HW, np.abs(Fs.eval(P) - TH) - TH)))
    for th in np.radians(np.arange(-200, 70, 24)):  # raised lacquer cartouches round the band
        p, n = surf1(Fs, U0, th)
        t = tangent(th)
        B.u(G.ellip(p + n * (2 * TH), (2.6, 3.4, 0.7), np.stack([np.array([1.0, 0, 0]), unit(t - n * (t @ n)), n], 1)), k=0.6)
    Gd = []
    for s in (-1, 1):
        uc = U0 + s * HW
        R = G.Field()
        R.u((np.array([uc - 1.6, lo[1], lo[2]]), np.array([uc + 1.6, hi[1], hi[2]]),
             lambda P, uc=uc: np.maximum(np.abs(P[:, 0] - uc) - 0.8, np.abs(Fs.eval(P) - 1.55) - 1.55)))
        Gd.append((cuts(R), 0.3, 0.18))
    return {"Band": [(cuts(B), 0.45, 0.3)], "Gold": Gd}


def medallion(Fs):
    th = math.radians(-20)
    k = 1.35  # concept: the medallion is a quarter of the band's visible length
    p, n = surf1(Fs, U0 + 2.0, th)
    a = unit(np.array([1.0, 0, 0]) - n * n[0])
    b = np.cross(n, a)
    c = p + n * (2 * TH + 0.6)
    M = G.Field()
    M.u(G.ellip(c, (7.5 * k, 7.5 * k, 1.6), np.stack([a, b, n], 1)))
    for r, tr in ((7.0 * k, 0.7), (4.7 * k, 0.55)):
        M.u(loop(c + n * (1.6 * math.sqrt(max(0.0, 1 - (r / (7.5 * k)) ** 2)) + 0.1), a, b, r, tr), k=0.3)
    for i in range(8):  # lotus petals
        f = 2 * math.pi * i / 8
        rad = math.cos(f) * a + math.sin(f) * b
        M.u(G.ellip(c + n * 1.5 + rad * 2.6 * k, (2.0 * k, 0.95 * k, 0.75), np.stack([rad, np.cross(n, rad), n], 1)), k=0.4)
    M.u(G.sphere(c + n * 2.0, 1.1 * k), k=0.4)
    T = G.Field()
    for off, L in ((-3.3, 0.85), (0.0, 1.15), (3.3, 0.85)):  # hanging tags toward the nose (concept)
        top = c - a * 7.2 * k + b * off
        q, nq = surf1(Fs, U0 + 2.0 - 7.5 * k - 3.6 * L, th + off * 0.012)
        mid = q + nq * 0.55 + b * off
        T.u(G.tube([top + n * 0.2, mid + a * 3.6 * L + nq * 0.2], [0.32, 0.32], step=0.2))
        aq = unit(a - nq * (a @ nq))
        T.u(G.ellip(mid, (1.25, 3.6 * L, 0.32), np.stack([np.cross(nq, aq), aq, nq], 1)), k=0.3)
    return {"Bronze": [(cuts(M), 0.28, 0.16)], "Gold": [(cuts(T), 0.25, 0.15)]}


def spires(Fs):
    y = unit(UP)
    out = []
    for deg, a, h1 in ((-120, 4.4, 8.5), (-105, 5.6, 11.5), (-90, 7.0, 15.0), (-75, 5.6, 11.5), (-60, 4.4, 8.5)):
        th = math.radians(deg)
        p, n = surf1(Fs, U0, th)
        t = tangent(th)
        x = unit(t - y * (t @ y))
        b0 = p + n * (2 * TH - 0.4)
        S = G.Field()

        def to3(pts, x=x, b0=b0):
            return [b0 + px * x + py * y for px, py in pts]
        S.u(G.tube(to3(arch_outline(a, h1)), [0.95], step=0.2))
        for s in (-1, 1):  # two lancets under an oculus, pinnacles on the springers
            S.u(G.tube(to3([(px + s * a / 2, py) for px, py in arch_outline(0.42 * a, h1)]), [0.6], step=0.2), k=0.2)
            S.u(G.tube(to3([(s * a, h1 - 0.6), (s * a, h1 + 2.4), (s * a, h1 + 5.0)]), [0.85, 0.6, 0.05], step=0.2), k=0.2)
        S.u(loop(b0 + y * (h1 + 1.18 * a), x, y, 0.42 * a, 0.5), k=0.2)
        apex = b0 + y * (h1 + math.sqrt(3) * a)
        S.u(G.tube([apex - y * 0.3, apex + y * 2.6, apex + y * 5.5], [1.05, 0.65, 0.05], step=0.2), k=0.3)
        S.u(G.ellip(b0 + y * 0.2, (a + 1.4, 1.4, 1.8), np.stack([x, y, np.cross(x, y)], 1)), k=0.4)  # plinth
        out.append((cuts(S), 0.3, 0.18))
    return {"Bronze": out}


def eave(Fs):
    th = math.radians(-138)
    p, n = surf1(Fs, U0, th)
    y = unit(UP)
    o = unit(n - y * (n @ y))
    tl = unit(np.cross(y, o))
    base = p + n * (2 * TH) + y * 2.0

    def P(s, d):
        lift = 4.6 * (1 - d) + 3.6 * abs(s) ** 3 * (0.35 + d) + 0.3 * math.cos(math.pi * s * 9) * d
        return base + tl * 12.5 * s + o * 10.5 * d + y * lift
    grid = np.array([[P(s, d) for d in np.linspace(0, 1, 8)] for s in np.linspace(-1, 1, 17)])
    Ev = G.Field()
    Ev.u(G.sheet(grid, 0.45))
    Ev.u(G.tube([P(s, 0.0) + y * 0.5 for s in np.linspace(-1.05, 1.05, 9)], [0.75], step=0.2), k=0.3)  # ridge
    Rd = G.Field()
    Rd.u(G.tube([P(s, 1.0) - y * 0.25 for s in np.linspace(-1.02, 1.02, 15)], [0.48], step=0.2))  # red fascia
    for s in (-0.55, 0.55):  # struts down to the band
        Rd.u(G.tube([P(s, 0.55) - y * 0.4, base + tl * 12.5 * s * 0.8 - y * 3.0], [0.6, 0.75], step=0.2), k=0.3)
    Gd = G.Field()
    for s in (-1, 1):  # gold scroll curls on the upturned corners
        K = P(s * 1.02, 1.0)
        pts = [K + (1.5 - 0.35 * f) * (math.cos(f * 2.2) * o + math.sin(f * 2.2) * y) - o * 1.5 for f in np.linspace(0, 3.0, 14)]
        Gd.u(G.tube(pts, [0.42, 0.34, 0.26], step=0.12))
    K = P(1.0, 1.0)
    Gd.u(G.tube([K - y * 0.4, K - y * 2.6], [0.3], step=0.15))  # bell chain
    T = K - y * 2.6
    Bl = G.Field()
    Bl.u(G.tube([T - y * f for f in (0.0, 1.1, 2.4, 3.9, 5.2)], [0.75, 1.45, 1.75, 1.95, 2.45], step=0.12))
    Bl.u(G.tube([T - y * 4.9, T - y * 5.6], [2.6, 2.3], step=0.1), k=0.15)  # lip
    Rd.u(G.tube([T - y * 5.3, T - y * 7.4], [0.35], step=0.15))  # tassel cord
    Rd.u(G.tube([T - y * 7.2, T - y * 8.7, T - y * 10.8], [0.5, 0.85, 1.0], step=0.12), k=0.2)
    return {"Eave": [(cuts(Ev), 0.25, 0.15)], "Band": [(cuts(Rd), 0.2, 0.12)], "Gold": [(cuts(Gd), 0.16, 0.1)],
            "Bronze": [(cuts(Bl), 0.2, 0.12)]}


def door_ring(Fs):
    y = unit(UP)
    ths = np.radians(np.linspace(0, 70, 36))
    pw = H.to_world(surf(Fs, np.full(ths.shape, U0 - 1.0), ths)[0])
    th = float(ths[np.argmin(np.abs(pw[:, 2] - 10.0))])  # the band point ~10 studs up, beside the cave (concept)
    p, n = surf1(Fs, U0 - 1.0, th)
    e1 = unit(np.cross(y, n))
    R = G.Field()
    boss = p + n * (2 * TH + 0.5)
    R.u(G.sphere(boss, 1.35))
    R.u(G.tube([boss, boss + n * 0.6 - y * 1.1], [0.55], step=0.15), k=0.3)
    R.u(loop(boss - y * 4.4 + n * 0.9, e1, y, 3.4, 0.62))
    log(f"door ring at ring angle {math.degrees(th):.0f} deg, world z {H.to_world(p)[2]:.1f}")
    return {"Bronze": [(cuts(R), 0.24, 0.14)]}


def roots(Hf):
    # (u start, u end, ring angle start, end (deg), radius): front roots stay at u > 34 (clear of medallion and cave),
    # back roots wrap round the cranium to the ground behind; two cross the band at the back (concept).
    spec = [(58, 52, -96, 40, 2.5), (47, 40, -102, 28, 2.1), (40, 34, -80, 12, 1.6), (61, 57, -84, -228, 2.6),
            (51, 45, -96, -222, 2.2), (36, 30, -92, -214, 1.9), (22, 16, -112, -208, 1.7), (55, 46, -70, -10, 1.7),
            (44, 50, -66, -238, 2.3), (30, 25, -100, -232, 1.8), (62, 60, -110, 30, 2.0)]
    out = []
    for i, (ua, ub, ta, tb, r0) in enumerate(spec):
        f = np.linspace(0, 1, 34)
        u = ua + (ub - ua) * f + 1.5 * np.sin(f * 7 + i)
        p, nr = surf(Hf, u, np.radians(ta + (tb - ta) * f))
        rad = r0 * (1 - 0.55 * f)
        w = H.to_world(p + nr * (0.55 * rad)[:, None])
        keep = np.flatnonzero(w[:, 2] > 0.6 * rad)
        if len(keep) < 6:
            continue
        w, rad = w[: keep[-1] + 1], rad[: keep[-1] + 1]
        outh = unit(np.array([w[-1, 0] - 3.0, w[-1, 1] - 1.0, 0.0]))  # wander off the skull along the ground
        side = np.array([-outh[1], outh[0], 0.0])
        foot = w[-1] * np.array([1.0, 1.0, 0.0]) + np.array([0.0, 0.0, 0.45 * rad[-1]])
        tail = [foot + outh * d + side * (1.6 * math.sin(d * 0.4 + i)) for d in (2.5, 6.0, 10.0, 14.0)]
        path = np.vstack([w, tail])
        path += 0.45 * np.stack([fbm(path * 0.18 + k * 7.0, 2, 30 + i) for k in range(3)], 1)
        rr = np.maximum(np.concatenate([rad, rad[-1] * np.array([0.85, 0.7, 0.55, 0.42])]), 0.42)
        Rt = G.Field()
        Rt.u(H.world_prim(G.tube(list(path), list(rr), step=0.35)))
        j = int(len(w) * 0.7)  # a side runner splitting off toward the ground
        br = [path[j], path[j] + side * 3 + np.array([0, 0, -0.3 * rad[j]]), tail[1] + side * 6.0, tail[2] + side * 9.0]
        br = [np.array([q[0], q[1], max(q[2], 0.4)]) for q in br]
        Rt.u(H.world_prim(G.tube(br, [rad[j] * 0.6, 0.6, 0.5, 0.42], step=0.35)), k=0.4)
        out.append((cuts(Rt), 0.3, 0.2))
    return {"Roots": out}


def rubble(Hf):
    rocks, panels = G.Field(), G.Field()
    cx = np.array([3.0, 1.0])
    n_rock = 0
    rr = np.linspace(2, 95, 160)
    for phi in np.radians(np.arange(0, 360, 9)):
        dirn = np.array([math.cos(phi), math.sin(phi)])
        P = np.stack([cx[0] + dirn[0] * rr, cx[1] + dirn[1] * rr, np.full(rr.shape, 1.0)], 1)
        inside = np.flatnonzero(Hf.eval(H.to_head(P)) < 0)
        if not len(inside) or inside[-1] + 1 >= len(rr):
            continue
        edge = P[inside[-1] + 1, :2]  # the outermost skull/ground contact on this bearing (the tunnel bore is inside)
        for _ in range(RNG.integers(1, 4)):
            r = float(RNG.uniform(1.5, 4.2)) * (2.0 if RNG.random() < 0.15 else 1.0)
            q = edge + dirn * RNG.uniform(0.5, 7.0) + np.array([-dirn[1], dirn[0]]) * RNG.uniform(-3, 3)
            if (abs(q[0] + 4) < 12 + r and q[1] > 18 - r) or (abs(q[0] + 7) < 14 + r and q[1] < -24 + r):
                continue  # keep the tunnel mouth and exit walkways clear
            c = np.array([q[0], q[1], r * 0.3])
            Rm = np.linalg.qr(RNG.normal(size=(3, 3)))[0]
            rocks.u(H.world_prim(G.ellip(c, (r, r * 0.75, r * 0.55), Rm)), k=0.3)
            nrm = unit(RNG.normal(size=3))
            off = r * 0.35
            rocks.c(H.world_prim((c - r * 1.2, c + r * 1.2, lambda X, c=c, nrm=nrm, off=off: off - (X - c) @ nrm)), k=0.25)
            n_rock += 1
        if RNG.random() < 0.22:  # broken lacquer panels from the band
            c = np.array([*(edge + dirn * RNG.uniform(1, 4)), 0.5])
            e1 = unit(np.array([*RNG.normal(size=2), RNG.uniform(-0.3, 0.3)]))
            e2 = unit(np.cross(e1, np.array([0.1, 0.0, 1.0])))
            w_, h_ = RNG.uniform(2.0, 3.4), RNG.uniform(1.3, 2.2)
            grid = np.array([[c + e1 * w_ * s + e2 * h_ * t + np.array([0, 0, 0.6 * (t + 1)]) for t in (-1, 1)] for s in (-1, 1)])
            panels.u(H.world_prim(G.sheet(grid, 0.3)))
    log(f"rubble: {n_rock} rocks")
    return {"Rubble": [(cuts(rocks), 0.35, 0.2)], "Band": [(cuts(panels), 0.25, 0.15)]}


# --- polygonise + materials ---------------------------------------------------------------------------------------------------

def polygonise(role, parts):
    out = {}
    for tag, which in (("LOW", 1), ("HIGH", 2)):
        Vs, Qs, n = [], [], 0
        for part in parts:
            F, h = part[0], part[which]
            V, Q = G.surface_nets(*F.grid(h), h)
            if not len(Q):
                continue
            if which == 1:
                V = G.project(F, V, h)
            Vs.append(H.to_world(V))
            Qs.append(np.asarray(Q) + n)
            n += len(V)
        nm = f"{NAME}__{role}" if which == 1 else f"HI_{NAME}__{role}"
        out[tag] = G.mesh_from(nm, np.vstack(Vs), np.vstack(Qs))
        log(f"{role} {tag} {sum(len(q) for q in Qs) * 2} tris")
    return out["LOW"], out["HIGH"]


DETAIL = {"Band": (0.035, 0.03, 1.1), "Gold": (0.015, 0.012, 2.2), "Bronze": (0.02, 0.015, 2.0), "Eave": (0.03, 0.02, 1.6),
          "Roots": (0.12, 0.05, 0.7), "Rubble": (0.08, 0.05, 0.9)}


def build():
    Fs, Hf = skull(), H.head_field()
    roles = {}
    for fn, arg in ((band, Fs), (medallion, Fs), (spires, Fs), (eave, Fs), (door_ring, Fs), (roots, Hf), (rubble, Hf)):
        t = time.time()
        for role, parts in fn(arg).items():
            roles.setdefault(role, []).extend(parts)
        log(f"{fn.__name__}: fields {time.time() - t:.1f}s")
    lows, highs = {}, {}
    for role, parts in roles.items():
        t = time.time()
        lo, hi = polygonise(role, parts)
        bump, pit, freq = DETAIL[role]
        if role in ("Roots", "Rubble"):
            FG.weather(hi, chip=0.05, erode=0.01, freq=0.8, seed=31, edge_pct=(88, 99.5))
        G.detail(hi, bump=bump, pit=pit, freq=freq, seed=sorted(DETAIL).index(role))
        FG.weighted_normals(lo)
        lows[role], highs[role] = lo, hi
        log(f"{role}: polygonised {time.time() - t:.1f}s")
    return lows, highs


def materials(out):
    import vesp_bake as VB
    maps = out / "maps"
    rock = VB.stone_source("Vesp_Weathered", maps)
    metal = VB.stone_source("Vesp_Iron", maps)
    slate = VB.stone_source("Vesp_Slate", maps)
    bark = VB.stone_source("Vesp_DeadBark", maps)
    moss = dict(moss_col=(0.27, 0.34, 0.13))
    hi = {"Band": VB.hi_material("Hi_Lacquer", rock, tile=3.0, rough=0.55),
          "Gold": VB.hi_material("Hi_Gold", metal, tile=1.2, tint=(1.0, 0.74, 0.32), metal=0.9, rough=0.42),
          "Bronze": VB.hi_material("Hi_Bronze", metal, tile=1.2, tint=(0.42, 0.55, 0.42), metal=0.6, rough=0.55),
          "Eave": VB.hi_material("Hi_Tiles", slate, tile=2.5, tint=(0.75, 0.95, 0.8)),
          "Roots": VB.hi_material("Hi_Root", bark, tile=1.5),
          "Rubble": VB.hi_material("Hi_Rubble", rock, tile=6.0)}
    looks = {"Band": VB.Look(base=0.5, sat=0.05, stone_tint=(1.12, 0.36, 0.30), edge=0.5, grime=0.4, cavity=0.6, moss=0.6,
                             moss_open=0.5, lichen=0.15, rough_base=0.6, **moss),
             "Gold": VB.Look(base=0.3, cavity=0.5),
             "Bronze": VB.Look(base=0.3, sat=0.4, stone_tint=(0.6, 0.75, 0.6), moss=0.5, cavity=0.6, **moss),
             "Eave": VB.Look(base=0.22, sat=0.3, stone_tint=(0.55, 0.85, 0.62), moss=0.8, moss_open=0.8, cavity=0.6,
                             rough_base=0.75, **moss),
             "Roots": VB.Look(base=0.2, sat=0.6, stone_tint=(1.0, 0.85, 0.7), edge=0.4, moss=0.7, moss_open=0.6, cavity=0.6, **moss),
             "Rubble": VB.Look(base=0.34, grime=0.35, edge=0.30, streak_dark=0.15, sat=0.15, stone_tint=(0.96, 0.98, 1.0),
                               moss=0.85, moss_open=0.9, lichen=0.3, cavity=0.75, rough_base=0.86, **moss)}
    rays = {"Band": (0.4, 0.9), "Gold": (0.25, 0.5), "Bronze": (0.25, 0.5), "Eave": (0.3, 0.6), "Roots": (0.4, 0.9),
            "Rubble": (0.5, 1.2)}
    return hi, looks, rays, rock["source"]


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_face").resolve()
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    mode = os.environ.get("CROWN_MODE", "clay")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lows, highs = build()
    face = out / "Bellwood_GiantFace.glb"
    ctx = []
    if face.exists():  # context only: the baked face shell the crown sits on
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(face))
        ctx = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    lo_b, hi_b = FG.bbox(list(highs.values()))
    rkw = {"views": (("q34", 150.0), ("front", 180.0), ("back", 20.0)), "ez": 6.0, "res": (1600, 1000),
           "close": (195.0, lo_b, hi_b, 60.0)}
    if mode == "clay":
        cm = G.clay_mat()
        for o in list(highs.values()) + ctx:
            o.data.materials.clear()
            o.data.materials.append(cm)
        for o in lows.values():
            o.hide_render = True
        files = G.render_set(NAME, list(highs.values()) + ctx, rdir, "clayhi", **rkw)
    else:
        import vesp_bake as VB
        hm, looks, rays, base = materials(out)
        for r, o in highs.items():
            o.data.materials.append(hm[r])
        for o in lows.values():
            VB.unwrap(o)
        files, _entry = G.finish(NAME, "Bellwood", lows, highs, out, looks, rays,
                                 base + " + metal_plate_02, roof_slates_02, bark_willow_02", builder=BUILDER, render_kw=rkw)
        G.merge_manifest(out, {NAME: _entry}, "Bellwood landmark: Fallen Giant's Face")
    dst = rdir / f"{NAME}_{'clay' if mode == 'clay' else 'baked'}_sheet.jpg"
    FG.sheet([files], dst)
    log("sheet", dst)


if __name__ == "__main__":
    main()

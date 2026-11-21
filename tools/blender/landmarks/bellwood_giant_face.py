"""Bellwood landmark: the Fallen Giant's Face (LANDMARK-BUILD-SPEC section 1; concepts bellwood_1/_2).

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_giant_face.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_face     env: FACE_MODE=clay|bake  VESP_BAKE_SIZE  VESP_RENDER_SAMPLES

A colossal stone head lying on its side in the forest (about 130 x 90 studs, 45 high), eyes closed, broad nose, slack mouth.
The lower eye socket opens into a walkable tunnel (>= 14 wide, 16 high) that curves through the skull and exits behind it,
so the hidden basin is unseen from outside. Built the Vesperhold way (vesperhold_gargoyles.py): one signed-distance sculpt
in a head frame (u = chin->crown, v = face forward, w = ear to ear), carved by world-frame tunnel and ground cuts, polygonised
twice with surface nets: LOW (shipped, projected onto the exact field) and HIGH (finer, with weathering, a crack network and
erosion pits). vesp_bake bakes HIGH -> LOW on the CC0 Poly Haven rock_04 base with moss in the folds; never decimated; the
shell is split into <18k-tri subs sharing one origin. Crown, roots and rubble are later steps of this kit.
Units studs, Z up, pivot = footprint centre at ground (z = 0); the tunnel mouth faces +Y.
"""
import math
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "vesperhold"))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
import vesperhold_figures as FG  # noqa: E402
import vesperhold_gargoyles as G  # noqa: E402
from vesperhold_figures import fbm, log, sst  # noqa: E402

ROOT = HERE.parents[2]
NAME = "Bellwood_GiantFace"
BUILDER = "tools/blender/landmarks/bellwood_giant_face.py (mac-84, SDF sculpt, Cycles-baked)"
TILT = math.radians(16.0)  # the head lies on its side, face near-vertical toward +Y (concept), tipped slightly skyward
# Head frame -> world: columns are the world directions of u (crown), v (face forward), w (ear to ear; +w is the buried side).
U = np.array([-1.0, 0.0, 0.0])
V = np.array([0.0, math.cos(TILT), math.sin(TILT)])
W = np.cross(U, V)
R = np.stack([U, V, W], 1)
O = np.array([4.0, -2.0, 13.0 * -W[2]])  # sink the head until w = +13 (the lower cheek) meets the ground
TUNNEL_R = 8.2  # round crown of the bore: 16.4 high at the centre line (centre 8 above ground)
# Bore centre line (floor = centre - 8): level into the lower eye socket, then down under the ground toward the sunken basin
# (creator 2026-11-22: the eye leads underground, not straight through). Grades 0.21..0.35 <= road MaxGrade 0.46; it bends
# so the far end is never visible from the mouth. Past the last point the passage continues as carved terrain (Studio).
TUNNEL = [(-4.0, 60.0, 8.0), (-4.0, 34.0, 8.0), (2.0, 14.0, 3.0), (8.0, -8.0, -5.0), (4.0, -32.0, -13.0), (-8.0, -56.0, -21.0),
          (-24.0, -80.0, -27.0)]
# The next point of the terrain passage (LandmarkLayout Bellwood Tunnel.Passage[2], level). The bore carve runs on to it so the
# sleeve's rounded end cap is cut open: mac-88's in-engine walk hit that cap 5.5 studs past the last TUNNEL point.
PASSAGE_ON = (-28.0, -104.0, -27.0)
LOW_H, HIGH_H = 0.6, 0.32  # surface-net cell sizes (studs); no total tri cap (creator): LOW fine enough to carry the fractures
# The round bore alone is only ~5.6 wide at the floor; two lower side lobes flatten it into an arch >= 14 wide at foot level.
LOBE_OFF, LOBE_R, LOBE_Z = 4.0, 6.0, 5.5
WALK_W, WALK_H = 14.0, 16.0  # spec minimum walkable width and height


def tunnel_prims(extra=0.0):
    """World-frame carve primitives of the walkable bore: the round crown plus two side lobes offset along the path normal."""
    P = np.asarray(TUNNEL + [PASSAGE_ON], float)
    tg = np.gradient(P[:, :2], axis=0)
    nr = np.stack([-tg[:, 1], tg[:, 0]], 1) / np.linalg.norm(tg, axis=1)[:, None]
    prims = [G.tube(list(P), [TUNNEL_R + extra] * len(P), step=0.6)]
    for s in (-1.0, 1.0):
        side = np.c_[P[:, :2] + nr * s * LOBE_OFF, P[:, 2] - (8.0 - LOBE_Z)]
        prims.append(G.tube(list(side), [LOBE_R + extra] * len(P), step=0.6))
    return prims


def tunnel_path(n=80, ext=8.0):
    """Walk line on the bore floor (centre - 8) from just outside the mouth to ext past the last point, level toward the passage."""
    P = np.asarray(TUNNEL, float)
    on = np.asarray(PASSAGE_ON, float) - P[-1]
    a, b = P[0] + (P[0] - P[1]) / np.linalg.norm(P[0] - P[1]) * ext, P[-1] + on / np.linalg.norm(on) * ext
    C = FG.spline(np.vstack([a, P, b]), n)[0]
    C[:, 2] -= 8.0
    return C


def to_head(Pw):
    return (np.asarray(Pw, float) - O) @ R


def to_world(Ph):
    return O + np.asarray(Ph, float) @ R.T


def world_prim(prim):
    """A (lo, hi, fn) primitive defined in world space, used inside the head-frame Field."""
    lo_w, hi_w, fn_w = prim
    cor = np.array([[x, y, z] for x in (lo_w[0], hi_w[0]) for y in (lo_w[1], hi_w[1]) for z in (lo_w[2], hi_w[2])])
    ch = to_head(cor)
    return ch.min(0), ch.max(0), (lambda Ph: fn_w(to_world(Ph)))


def head_field():
    F = G.Field()
    E = G.ellip
    # Masses: cranium, face, jaw/chin.
    # The face dominates (concept): a smaller, deeper cranium behind a broad, forward face plane.
    F.u(E((22, -14, 0), (42, 36, 32)))
    F.u(E((-16, 10, 0), (44, 34, 31)), k=12)
    F.u(E((-47, 17, 0), (14, 17, 21)), k=9)
    # Heavy brow ridge and cheekbones.
    F.u(E((9, 34, 0), (8, 8, 28)), k=6)
    for s in (-1, 1):
        F.u(E((-16, 30, 18 * s), (18, 12, 12)), k=10)  # fleshy cheeks
    # Eye sockets, then heavy closed lids with a crease and an upper fold under the brow.
    # The lower eye (w = +14) becomes the tunnel mouth (concept): socket only, no lids to splinter.
    for s in (-1, 1):
        F.c(E((3, 37, 14 * s), (7, 5, 10)), k=4)
        if s < 0:
            F.u(E((2, 33.5, 14 * s), (5.2, 4.2, 8.6)), k=2.5)
            F.c(E((1.2, 37.4, 14 * s), (0.7, 1.4, 8.4)), k=0.6)
            F.u(E((7.5, 35.5, 14 * s), (2.5, 2.5, 9.5)), k=2)
    # Nose: bridge to a broad tip, alae, nostrils.
    F.u(G.tube([(4, 37, 0), (-8, 41, 0), (-20, 46, 0)], [7.0, 8.0, 10.5], step=0.5), k=5)  # massive, bulbous (concept)
    for s in (-1, 1):
        F.u(E((-21, 39.5, 8.5 * s), (7, 6, 6)), k=4)
        F.c(G.sphere((-26, 45.5, 5.0 * s), 2.8), k=1.0)
    # Philtrum, slack lips, the parted mouth and its corners.
    F.u(E((-30, 40, 0), (3, 2.5, 4)), k=2)
    F.u(E((-34, 39.5, 0), (3.6, 3.6, 12.5)), k=3)
    F.u(E((-40.5, 38.5, 0), (4.2, 4, 11)), k=3)
    F.c(E((-37.2, 41.5, 0), (1.3, 4.5, 10)), k=1.2)
    for s in (-1, 1):
        F.c(E((-37, 37, 12.5 * s), (2.5, 2.5, 2)), k=1.5)
    # Ears (the upper one shows; the lower one is mostly buried).
    for s in (-1, 1):
        F.u(E((2, -6, 33.5 * s), (14, 7, 4)), k=4)
        F.c(E((2, -4, 36.5 * s), (8, 3.5, 2)), k=1.5)
    # Spalled chunks: flat-faced chips broken off the exposed edges (nose tip, chin, lips, ear, brow, cranium).
    rng = np.random.default_rng(13)
    for c, r in (((-21, 57, 2), 5.5), ((-54, 27, -6), 6.5), ((-40, 43, -11), 4.0), ((2, -6, -38), 5.0), ((13, 41, -22), 5.0),
                 ((44, -12, -30), 7.0), ((58, -20, -8), 6.0), ((-10, 38, -27), 4.5), ((30, 22, -28), 5.5)):
        F.c(E(c, (r, r, r * 0.38), np.linalg.qr(rng.normal(size=(3, 3)))[0]), k=0.6)
    # Underground: a rock sleeve round the descending bore, spared by the ground cut, so the throat has stone walls below grade.
    sleeve = G.tube(TUNNEL[2:], [TUNNEL_R + 4.0] * len(TUNNEL[2:]), step=0.6)
    F.u(world_prim(sleeve), k=3.0)
    sfn = sleeve[2]
    F.c(world_prim((np.array([-200.0, -200.0, -120.0]), np.array([200.0, 200.0, -0.6]),
                    lambda P: np.maximum(P[:, 2] + 0.6, -sfn(P)))))
    # The walkable bore from the lower eye socket down under the ground, with a rough arched mouth flaring out of the socket.
    for pr in tunnel_prims():
        F.c(world_prim(pr), k=2.5)
    eye = to_world((3, 37, 14))
    F.c(world_prim(G.ellip((eye[0] - 5.0, eye[1] - 6.0, 10.0), (9.5, 9.0, 12.0))), k=6)
    return Weathered(F)


class Weathered:
    """The head field plus large-scale weathering IN the shape (creator: too smooth): a fracture network 2-3 studs deep, finer
    secondary cracks and broad lumps. Being part of the field, the LOW silhouette carries it, not only the baked normals."""

    def __init__(self, F):
        self.F, self.ops = F, F.ops

    def bounds(self):
        return self.F.bounds()

    @staticmethod
    def disp(Ph):
        Pw = to_world(Ph)
        # Amplitudes stay under the feature scale (mac-86b: 0.9 lumps + 2.4 cracks buried the nose, lips and eye).
        grain = 0.35 * fbm(Pw / 7.0, 3, 41)
        warp = Pw / 38.0 + 0.6 * fbm(Pw / 30.0, 2, 45)[:, None]  # long, wandering fractures, not closed cells
        major = sst(0.03, 0.0, np.abs(fbm(warp, 3, 43)))
        mask = sst(-0.05, 0.15, fbm(Pw / 50.0 + 3.0, 2, 46))  # secondary cracking in patches only
        minor = sst(0.025, 0.0, np.abs(fbm(Pw / 13.0 + 7.0, 2, 44))) * mask
        return grain + 1.6 * major + 0.6 * minor  # + = eroded inward

    def eval(self, P):
        return self.F.eval(P) + self.disp(P)

    def grid(self, h, pad=4):
        D, lo = self.F.grid(h, pad)
        ys, zs = lo[1] + h * np.arange(D.shape[1]), lo[2] + h * np.arange(D.shape[2])
        for i in range(D.shape[0]):
            sl = D[i]
            m = np.abs(sl) < 4.5  # displacement only matters near the surface
            if m.any():
                yy, zz = np.meshgrid(ys, zs, indexing="ij")
                P = np.stack([np.full(m.sum(), lo[0] + h * i), yy[m], zz[m]], 1)
                sl[m] += self.disp(P).astype(sl.dtype)
        return D, lo


def weather_high(obj, seed=3):
    """Granite on the HIGH: broad lumps, a crack network (zero-crossings of a ridged field), erosion pits."""
    co, nr = G._co_nr(obj)
    p = co / 9.0
    lumps = 0.35 * fbm(p, 3, seed)
    n1, n2 = fbm(p * 0.9 + 11.0, 3, seed + 1), fbm(p * 2.1 + 5.0, 2, seed + 2)
    crack = np.maximum(sst(0.05, 0.0, np.abs(n1)) * 0.9, sst(0.035, 0.0, np.abs(n2)) * 0.45)
    pits = sst(0.32, 0.6, fbm(co * 0.9, 2, seed + 5) * 0.5 + 0.5) * 0.12
    d = lumps - 0.65 * crack - pits
    obj.data.vertices.foreach_set("co", (co + nr * d[:, None]).astype(np.float32).ravel())
    obj.data.update()


def check_walkable(F):
    """Self-check: the bore is open (air, F > 0) across WALK_W at foot and head height and WALK_H at the centre line."""
    C = tunnel_path(60, ext=16.0)  # 16 past the end: through where the sleeve's end cap sealed the bore (mac-88)
    tg = np.gradient(C[:, :2], axis=0)
    nr = np.c_[np.stack([-tg[:, 1], tg[:, 0]], 1) / np.linalg.norm(tg, axis=1)[:, None], np.zeros(len(C))]
    probes = [C + nr * t + np.array([0, 0, z]) for t in np.linspace(-WALK_W / 2 + 0.5, WALK_W / 2 - 0.5, 7) for z in (0.8, 5.5)]
    probes.append(C + np.array([0, 0, WALK_H - 0.5]))
    d = F.eval(to_head(np.vstack(probes)))
    assert d.min() > 0, f"tunnel not walkable: {int((d <= 0).sum())} probes inside stone (min {d.min():.2f})"
    log(f"tunnel walkable: {len(d)} probes clear, {WALK_W:.0f} wide x {WALK_H:.0f} high")


def tunnel_floor(F):
    """Rubble-strewn dirt floor ribbon along the descending walk line (own role: Precise collision in Roblox), stones kept off
    the walkway. Starts at the mouth: points with open sky 20 studs above them are outside and get dropped."""
    rng = np.random.default_rng(7)
    C = tunnel_path(70)
    roof = F.eval(to_head(C + np.array([0.0, 0.0, 20.0]))) < 0
    C = C[max(int(np.argmax(roof)) - 1, 0):]
    tg = np.gradient(C[:, :2], axis=0)
    nr = np.c_[np.stack([-tg[:, 1], tg[:, 0]], 1) / np.linalg.norm(tg, axis=1)[:, None], np.zeros(len(C))]
    grid = np.array([[c + n * t for t in np.linspace(-9.0, 9.0, 11)] for c, n in zip(C, nr)])
    grid[..., 2] = C[:, None, 2] + 0.1 + 0.3 * fbm(grid.reshape(-1, 3) * 0.22, 2, 11).reshape(grid.shape[:2])
    F = G.Field()
    F.u(G.sheet(grid, 0.45))
    for i in range(2, len(C) - 2, 3):
        for s in (-1, 1):
            r = rng.uniform(0.5, 1.3)
            c = C[i] + nr[i] * s * rng.uniform(5.5, 8.0) + np.array([0, 0, 0.35 + r * 0.25])
            F.u(G.ellip(c, (r, r * 0.8, r * 0.6), np.linalg.qr(rng.normal(size=(3, 3)))[0]), k=0.3)
    out = []
    for nm, h in ((f"{NAME}__Floor", 0.5), (f"HI_{NAME}__Floor", 0.25)):
        V, Q = G.surface_nets(*F.grid(h), h)
        if nm.startswith(NAME):
            V = G.project(F, V, h)
        out.append(G.mesh_from(nm, V, Q))
        log(f"{nm} {len(Q) * 2} tris")
    lo, hi = out
    G.detail(hi, bump=0.05, pit=0.04, freq=1.4, seed=8)
    FG.weighted_normals(lo)
    return lo, hi


def sculpt():
    F = head_field()
    check_walkable(F)
    t = time.time()
    V, Q = G.surface_nets(*F.grid(LOW_H), LOW_H)
    V = G.project(F, V, LOW_H)
    lo = G.mesh_from(f"{NAME}__Shell", to_world(V), Q)
    log(f"LOW {len(Q) * 2} tris  {time.time() - t:.1f}s")
    t = time.time()
    V, Q = G.surface_nets(*F.grid(HIGH_H), HIGH_H)
    hi = G.mesh_from(f"HI_{NAME}__Shell", to_world(V), Q)
    # Thin walls (< ~1.2 studs) keep their shape: weathering there frays them into floating shards.
    co0, nr0 = G._co_nr(hi)
    thin = sst(-1.2, -0.4, F.eval(to_head(co0 - nr0 * 1.2)))
    weather_high(hi)
    FG.weather(hi, chip=0.05, erode=0.01, freq=0.6, seed=21, edge_pct=(90, 99.6))
    G.detail(hi, bump=0.05, pit=0.04, freq=0.9, seed=4)
    co1, _ = G._co_nr(hi)
    hi.data.vertices.foreach_set("co", (co0 + (co1 - co0) * (1 - thin)[:, None]).astype(np.float32).ravel())
    hi.data.update()
    log(f"HIGH {len(Q) * 2} tris  {time.time() - t:.1f}s")
    FG.weighted_normals(lo)
    return lo, hi, F


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_face").resolve()
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    mode = os.environ.get("FACE_MODE", "clay")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lo, hi, F = sculpt()
    flo, fhi = tunnel_floor(F)
    lo_b, hi_b = FG.bbox([hi])
    lo_b[2] = max(lo_b[2], 0.0)  # frame the visible head, not the buried rock sleeve
    high34 = (195.0, lo_b, hi_b, 60.0)  # the concept's elevated 3/4 camera (no mannequin)
    rkw = {"views": (("q34", 150.0), ("front", 180.0), ("back", 20.0)), "ez": 6.0, "res": (1600, 1000), "close": high34}
    if mode == "clay":
        cm = G.clay_mat()
        hi.data.materials.append(cm)
        fhi.data.materials.append(cm)
        lo.hide_render = flo.hide_render = True
        files = G.render_set(NAME, [hi, fhi], rdir, "clayhi", **rkw)
        entry = None
    else:
        import vesp_bake as VB
        src = VB.stone_source("Vesp_Weathered", out / "maps")
        hi.data.materials.append(VB.hi_material("Hi_Granite", src, tile=8.0, tint=(1.0, 1.0, 0.97)))
        fhi.data.materials.append(VB.hi_material("Hi_Dirt", src, tile=4.0, tint=(1.0, 0.95, 0.9)))
        VB.unwrap(lo)
        VB.unwrap(flo)
        # Grey granite (concept), dark cracks not lit lips (low edge wear, strong cavity), green moss blanketing the tops.
        look = VB.Look(base=0.34, grime=0.35, edge=0.30, streak_dark=0.15, sat=0.15, stone_tint=(0.96, 0.98, 1.0),
                       moss=0.85, moss_open=0.9, moss_col=(0.27, 0.34, 0.13), lichen=0.3, cavity=0.75, rough_base=0.86)
        dirt = VB.Look(base=0.17, grime=0.5, edge=0.3, sat=0.22, stone_tint=(0.93, 0.86, 0.76), moss=0.35, moss_col=(0.27, 0.34, 0.13),
                       cavity=0.7, rough_base=0.95)
        files, entry = G.finish(NAME, "Bellwood", {"Shell": lo, "Floor": flo}, {"Shell": hi, "Floor": fhi}, out,
                                {"*": look, "Floor": dirt}, {"Shell": (0.6, 1.4), "Floor": (0.4, 0.8)}, src["source"],
                                extra={"collision": {"Floor": "PreciseConvexDecomposition", "Shell": "Hull"}},
                                builder=BUILDER, render_kw=rkw)
        G.merge_manifest(out, {NAME: entry}, "Bellwood landmark: Fallen Giant's Face")
    dst = rdir / f"{NAME}_{'clay' if mode == 'clay' else 'baked'}_sheet.jpg"
    FG.sheet([files], dst)
    log("sheet", dst)


if __name__ == "__main__":
    main()

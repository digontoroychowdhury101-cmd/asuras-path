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
TUNNEL_R = 8.2  # 16.4 wide and high; centre 8 above ground (the walkable floor piece sits on the 0.2 dip)
TUNNEL = [(-4.0, 60.0, 8.0), (-4.0, 34.0, 8.0), (4.0, 12.0, 8.0), (10.0, -10.0, 8.0), (0.0, -34.0, 8.0), (-14.0, -64.0, 8.0)]
LOW_H, HIGH_H = 0.8, 0.42  # surface-net cell sizes (studs)


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
    # World-frame cuts: the curved walkable tunnel from the lower eye through the skull, then the ground plane.
    F.c(world_prim(G.tube(TUNNEL, [TUNNEL_R] * len(TUNNEL), step=0.6)), k=2.5)
    # A rough arched cave mouth flaring out of the lower eye socket (not a clean round bore), and a flared exit.
    eye = to_world((3, 37, 14))
    F.c(world_prim(G.ellip((eye[0] - 5.0, eye[1] - 6.0, 10.0), (9.5, 9.0, 12.0))), k=6)
    F.c(world_prim(G.ellip((TUNNEL[-2][0] - 6.0, TUNNEL[-2][1] - 16.0, 9.0), (12.0, 10.0, 10.5))), k=5)
    F.c(world_prim((np.array([-200.0, -200.0, -120.0]), np.array([200.0, 200.0, -0.6]), lambda P: P[:, 2] + 0.6)))
    return F


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


def sculpt():
    F = head_field()
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
    return lo, hi


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_face").resolve()
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    mode = os.environ.get("FACE_MODE", "clay")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lo, hi = sculpt()
    lo_b, hi_b = FG.bbox([hi])
    high34 = (195.0, lo_b, hi_b, 60.0)  # the concept's elevated 3/4 camera (no mannequin)
    rkw = {"views": (("q34", 150.0), ("front", 180.0), ("back", 20.0)), "ez": 6.0, "res": (1600, 1000), "close": high34}
    if mode == "clay":
        cm = G.clay_mat()
        hi.data.materials.append(cm)
        lo.hide_render = True
        files = G.render_set(NAME, [hi], rdir, "clayhi", **rkw)
        entry = None
    else:
        import vesp_bake as VB
        src = VB.stone_source("Vesp_Weathered", out / "maps")
        hi.data.materials.append(VB.hi_material("Hi_Granite", src, tile=8.0, tint=(1.0, 1.0, 0.97)))
        VB.unwrap(lo)
        look = VB.Look(base=0.30, grime=0.35, streak_dark=0.18, sat=0.55, moss=0.55, lichen=0.25, cavity=0.35, rough_base=0.86)
        files, entry = G.finish(NAME, "Bellwood", {"Shell": lo}, {"Shell": hi}, out, {"*": look}, {"Shell": (0.6, 1.4)},
                                src["source"], builder=BUILDER, render_kw=rkw)
        G.merge_manifest(out, {NAME: entry}, "Bellwood landmark: Fallen Giant's Face")
    dst = rdir / f"{NAME}_{'clay' if mode == 'clay' else 'baked'}_sheet.jpg"
    FG.sheet([files], dst)
    log("sheet", dst)


if __name__ == "__main__":
    main()

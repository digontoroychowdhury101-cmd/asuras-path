"""Bellwood landmark: the Sunken Temple's twin gate towers and moss stair (LANDMARK-BUILD-SPEC section 1; concept bellwood_3, left third).

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_gate_towers.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_gate     env: GATE_MODE=clay|bake  VESP_RENDER_SAMPLES

Two three-tier stone towers flank a stair that climbs out of the lake into the forest; a stone lintel with its own small roof
spans them as a gate. Each tier carries a curved tile roof (lobby_kit_roofs.hall); faces have raised panels, string courses
and round medallions; the ground tiers open an arched niche toward the lake. Roots pour down the towers onto the ground and
red prayer ribbons hang from the lintel cord and the cornices.
Hard-surface LOW -> HIGH (bellwood_temple_hall.high_copy) -> vesp_bake per role on CC0 Poly Haven bases (outputs/vesperhold/THIRD_PARTY.md):
  Stone   medieval_blocks_03, grey-green, heavy moss          (collision: precise, the stair is walkable)
  Tiles   ceramic_roof_01, wet grey, blanket moss              (no collision)
  Soffit  distressed_painted_planks, dark red-brown eaves      (no collision)
  Root    bark_willow_02, dark wet bark with moss              (collision: hull)
  Ribbon  distressed_painted_planks re-tinted faded vermilion  (no collision)
Units studs, Z up. Pivot: stair-foot centre on the lake bed (z = 0). The stair climbs toward -Y; the kit front (+Y) faces the lake.
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
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import bellwood_temple_hall as H  # noqa: E402  (objects / high_copy / src)
import lobby_kit_roofs as roofs  # noqa: E402
import vesperhold_figures as FG  # noqa: E402
import vesperhold_gargoyles as G  # noqa: E402
from lobby_kit_geo import Mesh  # noqa: E402
from vesperhold_figures import log  # noqa: E402

ROOT = HERE.parents[2]
NAME = "Bellwood_GateTowers"
BUILDER = "tools/blender/landmarks/bellwood_gate_towers.py (mac-91, hard-surface + Cycles bake)"
ROLES = ("Stone", "Tiles", "Soffit", "Root", "Ribbon")

TX = 13.0  # tower centre x (each side)
TIERS = ((12.0, 18.0), (9.6, 12.0), (7.6, 9.0))  # (plan width, height) per tier, bottom up
STAIR_W, STEPS, RUN, RISE = 12.0, 28, 1.6, 0.5  # climbs 14 studs over 44.8 toward -Y
STAIR_Y0 = 10.0  # front edge of the lowest step
LINTEL_Z = 19.5


class Piece:
    def __init__(self):
        self.meshes = {}

    def m(self, role):
        role = {"Roof": "Tiles", "Timber": "Soffit"}.get(role, role)
        if role not in self.meshes:
            self.meshes[role] = Mesh(f"{NAME}__{role}", role, 8.0)
        return self.meshes[role]


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def panels(s, cx, w, z0, z1, medallion):
    """Raised frame panels on the four faces of a square tier centred (cx, 0), and an optional round medallion per face."""
    h = w / 2
    zc, ph, pw = (z0 + z1) / 2, (z1 - z0) - 2.4, w - 3.0
    for ang in (0.0, 0.5 * math.pi, math.pi, 1.5 * math.pi):
        R = T(cx, 0, 0) @ Matrix.Rotation(ang, 4, "Z")
        for sx in (-1, 1):
            s.box((sx * (pw / 2 - 0.3), h + 0.17, zc), (0.6, 0.35, ph), R, bevel=0.06)
        for sz in (-1, 1):
            s.box((0, h + 0.17, zc + sz * (ph / 2 - 0.3)), (pw, 0.35, 0.6), R, bevel=0.06)
        if medallion:
            M = R @ T(0, h + 0.05, zc) @ Matrix.Rotation(-0.5 * math.pi, 4, "X")
            s.lathe([(1.9, 0.0), (1.9, 0.25), (1.5, 0.45), (0.6, 0.55), (0.0, 0.6)], 20, M)


def tower(pc, sx):
    s = pc.m("Stone")
    cx = sx * TX
    z = 0.0
    for i, (w, h) in enumerate(TIERS):
        if i == 0:
            # ground tier: back block, two piers and a head block round an arched niche facing the lake
            ow, oh, depth = 5.0, 10.5, 4.0
            s.box((cx, -depth / 2, h / 2), (w, w - depth, h), bevel=0.12)
            pw = (w - ow) / 2
            for px in (-1, 1):
                s.box((cx + px * (ow / 2 + pw / 2), w / 2 - depth / 2, h / 2), (pw, depth, h), bevel=0.12)
            s.box((cx, w / 2 - depth / 2, (oh + h) / 2), (ow + 0.1, depth, h - oh), bevel=0.08)
            ring = [Vector((cx + ow / 2 * math.cos(a), w / 2 + 0.2, oh - ow / 2 + ow / 2 * math.sin(a)))
                    for a in [math.pi * k / 16 for k in range(17)]]
            s.sweep([(-0.45, -0.3), (0.45, -0.3), (0.45, 0.3), (-0.45, 0.3)], ring, up=Vector((0, 1, 0)))
            for px in (-1, 1):
                s.box((cx + px * (ow / 2 + 0.2), w / 2 + 0.2, (oh - ow / 2) / 2), (0.7, 0.6, oh - ow / 2), bevel=0.06)
            s.box((cx, w / 2 - depth / 2, 0.5), (ow, depth, 1.0), bevel=0.05)
        else:
            s.box((cx, 0.0, z + h / 2), (w, w, h), bevel=0.12)
            panels(s, cx, w, z, z + h, i == 1)
        s.box((cx, 0.0, z + 0.4), (w + 0.8, w + 0.8, 0.8), bevel=0.1)  # plinth course
        for grow, zz in ((0.6, h - 0.9), (1.2, h - 0.45)):  # corbelled string course
            s.box((cx, 0.0, z + zz), (w + grow, w + grow, 0.45), bevel=0.06)
        for px in (-1, 1):  # corner pilasters
            for py in (-1, 1):
                s.box((cx + px * (w / 2 - 0.2), py * (w / 2 - 0.2), z + h / 2), (1.1, 1.1, h - 1.6), bevel=0.08)
        sub = Piece()
        rw = w + 6.0
        roofs.hall(sub, rw, rw, 3.2 + 0.4 * i, 0.55, 1.6, 1.0, (0.45, 0.9), top="Roof", under="Timber",
                   ridge_scale=0.9, finial=None, nu=28, nt=(7, 7))
        for role, mesh in sub.meshes.items():
            pc.m(role).merge(mesh.bm, T(cx, 0.0, z + h))
        z += h + (2.2 if i < len(TIERS) - 1 else 0.0)  # the next tier rises out of this roof
    top = z + 3.6 + 0.4 * (len(TIERS) - 1)
    s.lathe([(1.0, 0.0), (1.2, 0.6), (0.7, 1.4), (0.9, 2.2), (0.0, 3.6)], 12, T(cx, 0.0, top - 1.2))  # stone finial
    return top + 2.4


def stair_and_gate(pc):
    s = pc.m("Stone")
    for k in range(STEPS):
        top = RISE * (k + 1)
        s.box((0, STAIR_Y0 - RUN * (k + 0.5), top / 2), (STAIR_W, RUN + 0.04, top), bevel=0.06)
    L = RUN * STEPS
    for sx in (-1, 1):  # stepped cheek walls up the flight
        for k in range(0, STEPS, 4):
            hgt = RISE * (k + 4) + 1.2
            s.box((sx * (STAIR_W / 2 + 0.7), STAIR_Y0 - RUN * (k + 2), hgt / 2), (1.4, RUN * 4 + 0.04, hgt), bevel=0.08)
    s.box((0, STAIR_Y0 - L - 3.0, RISE * STEPS / 2), (STAIR_W + 3.0, 6.0, RISE * STEPS), bevel=0.1)  # landing into the forest
    span = 2 * TX - TIERS[0][0] + 1.0
    s.box((0, 0.0, LINTEL_Z), (span, 2.2, 1.6), bevel=0.1)
    s.box((0, 0.0, LINTEL_Z + 1.4), (span + 1.2, 2.8, 0.9), bevel=0.08)
    s.box((0, 1.15, LINTEL_Z - 2.0), (6.0, 0.4, 2.6), bevel=0.08)  # name board
    sub = Piece()
    roofs.hall(sub, span + 4.0, 6.0, 2.6, 0.6, 1.2, 0.8, (0.4, 0.8), top="Roof", under="Timber",
               ridge_scale=0.8, finial=None, nu=30, nt=(6, 4))
    for role, mesh in sub.meshes.items():
        pc.m(role).merge(mesh.bm, T(0, 0.0, LINTEL_Z + 1.85))


def roots(pc, seed=7):
    """Roots pour down each tower's outer and front faces and splay onto the ground (radius ~1.3 at the top, ~0.5 at the tips)."""
    r = pc.m("Root")
    rng = random.Random(seed)
    prof = [(math.cos(a), math.sin(a)) for a in [2 * math.pi * k / 9 for k in range(9)]]
    w0, h0 = TIERS[0]
    for sx in (-1, 1):
        cx = sx * TX
        for face, off in (("side", -3.0), ("side", 2.5), ("front", -3.0 * sx), ("front", 3.4 * sx), ("side", 0.0)):
            top = h0 + TIERS[1][1] * rng.uniform(0.3, 0.9)
            pts, sc = [], []
            for k in range(17):
                t = k / 16
                zc = top * (1 - t) ** 1.15 - 0.3 * t
                wall = (w0 / 2 if zc < h0 else TIERS[1][0] / 2) + 0.9
                wob = 0.9 * math.sin(t * 7.0 + off) + rng.uniform(-0.2, 0.2)
                spread = max(0.0, t - 0.7) / 0.3 * rng.uniform(4.0, 7.5)
                if face == "side":
                    p = Vector((cx + sx * (wall + spread), off + wob, max(zc, 0.0)))
                else:
                    p = Vector((cx + off + wob, wall + spread, max(zc, 0.0)))
                pts.append(p)
                sc.append(1.3 - 0.8 * t + 0.25 * math.sin(t * 9.0 + off))
            r.sweep(prof, pts, scales=sc)


def ribbons(pc, seed=11):
    """A sagging cord under the lintel with strips hanging from it, plus strips from the ground-tier cornices."""
    rb = pc.m("Ribbon")
    rng = random.Random(seed)
    span = 2 * TX - TIERS[0][0] + 1.0
    cord = [Vector((-span / 2 + span * k / 20, 1.3, LINTEL_Z - 1.1 - 1.6 * math.sin(math.pi * k / 20))) for k in range(21)]
    rb.sweep([(-0.08, -0.08), (0.08, -0.08), (0.08, 0.08), (-0.08, 0.08)], cord)
    strip = [(-0.32, -0.03), (0.32, -0.03), (0.32, 0.03), (-0.32, 0.03)]

    def hang(at, length):
        sway = rng.uniform(-0.6, 0.6)
        rb.sweep(strip, [at + Vector((sway * (k / 6) ** 2, 0.15 * math.sin(k), -length * k / 6)) for k in range(7)],
                 up=Vector((0, 1, 0)))

    for k in range(1, 20, 2):
        hang(cord[k], rng.uniform(2.5, 5.5))
    w, h = TIERS[0]
    for sx in (-1, 1):
        for k in range(5):
            hang(Vector((sx * TX + (k - 2) * w / 5, w / 2 + 0.9, h - 0.6)), rng.uniform(3.0, 7.0))


def build(pc):
    tops = [tower(pc, sx) for sx in (-1, 1)]
    stair_and_gate(pc)
    roots(pc)
    ribbons(pc)
    return max(tops)


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_gate").resolve()
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    mode = os.environ.get("GATE_MODE", "clay")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t = time.time()
    pc = Piece()
    top = build(pc)
    H.NAME, H.ROLES = NAME, ROLES  # the hall's objects() iterates its module ROLES
    lows = H.objects(pc)
    log("LOW " + " ".join(f"{r}={sum(len(p.vertices) - 2 for p in o.data.polygons)}" for r, o in lows.items())
        + f"  top={top:.1f}  {time.time() - t:.1f}s")
    lo_b, hi_b = FG.bbox(list(lows.values()))
    rkw = {"views": (("q34", 150.0), ("front", 180.0), ("side", 90.0)), "ez": 6.0, "res": (1600, 1000),
           "close": (155.0, lo_b, hi_b, 12.0)}
    if mode == "clay":
        cm = G.clay_mat()
        for o in lows.values():
            o.data.materials.append(cm)
        files = G.render_set(NAME, list(lows.values()), rdir, "clay", **rkw)
    else:
        import vesp_bake as VB
        stone, wood = H.src("medieval_blocks_03", "stone"), H.src("distressed_painted_planks", "lacquer")
        tile, bark = H.src("ceramic_roof_01", "tiles"), H.src("bark_willow_02", "roots")
        highs = {}
        for i, (role, s, tl) in enumerate((("Stone", stone, 6.0), ("Tiles", tile, 7.0), ("Soffit", wood, 5.0),
                                           ("Root", bark, 4.0), ("Ribbon", wood, 3.0))):
            highs[role] = H.high_copy(lows[role], 53 + 7 * i)
            highs[role].data.materials.append(VB.hi_material(f"Hi_Gate{role}", s, tile=tl))
            VB.unwrap(lows[role])
            log(f"HIGH {role} {VB.tris(highs[role])} tris")
        moss = (0.25, 0.32, 0.12)
        looks = {
            "Stone": VB.Look(base=0.28, grime=0.45, edge=0.35, sat=0.15, stone_tint=(0.95, 1.0, 0.98), moss=1.0, moss_open=0.6,
                             moss_col=moss, lichen=0.3, cavity=0.65, rough_base=0.86),
            "Tiles": VB.Look(base=0.17, grime=0.45, edge=0.2, sat=0.12, stone_tint=(0.95, 1.0, 1.04), moss=0.9, moss_open=0.65,
                             moss_col=moss, lichen=0.2, cavity=0.7, rough_base=0.8),
            "Soffit": VB.Look(base=0.16, grime=0.6, edge=0.15, sat=0.5, stone_tint=(0.75, 0.32, 0.25), cavity=0.5, rough_base=0.8),
            "Root": VB.Look(base=0.22, grime=0.5, edge=0.2, sat=0.35, stone_tint=(0.85, 0.72, 0.6), moss=0.6, moss_open=0.4,
                            moss_col=moss, cavity=0.7, rough_base=0.9),
            "Ribbon": VB.Look(base=0.42, grime=0.35, edge=0.1, sat=0.75, stone_tint=(1.0, 0.22, 0.16), cavity=0.3, rough_base=0.9),
        }
        files, entry = G.finish(NAME, "Bellwood", lows, highs, out, looks, {r: (0.35, 0.7) for r in ROLES},
                                "Poly Haven medieval_blocks_03, ceramic_roof_01, distressed_painted_planks, bark_willow_02 (CC0)",
                                extra={"collision": {"Stone": "PreciseConvexDecomposition", "Root": "Hull"}},
                                builder=BUILDER, render_kw=rkw)
        G.merge_manifest(out, {NAME: entry}, "Bellwood landmark: Sunken Temple gate towers")
    dst = rdir / f"{NAME}_{mode}_sheet.jpg"
    FG.sheet([files], dst)
    log("sheet", dst)


if __name__ == "__main__":
    main()

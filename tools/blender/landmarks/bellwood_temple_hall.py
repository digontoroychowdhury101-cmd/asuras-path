"""Bellwood landmark: the Sunken Temple main hall (LANDMARK-BUILD-SPEC section 1; concept bellwood_3).

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/landmarks/bellwood_temple_hall.py -- [out_dir]
  default out_dir: assets/source/landmarks/bellwood_temple     env: HALL_MODE=clay|bake  VESP_RENDER_SAMPLES

A two-tier hall standing in the basin lake, flooded to the top of its stairs: a stone platform with a front stair and a
balustrade, red-lacquered columns, beams and bracket sets, lattice doors, and two heavy curved tile roofs (the lobby kit's
hip-and-gable builder, lobby_kit_roofs.hall, scaled up). The crimson maple, banners, gong and vines are later kit pieces.
Hard-surface LOW (lobby_kit_geo solids) -> HIGH = LOW subdivided to <= MAX_EDGE with chipped edges and pitting -> vesp_bake per
role on CC0 Poly Haven bases (outputs/vesperhold/THIRD_PARTY.md):
  Stone   medieval_blocks_03, grey, moss in the folds and on the treads    (collision: precise, walkable platform and stair)
  Lacquer distressed_painted_planks re-tinted deep red, worn               (collision: default)
  Tiles   ceramic_roof_01 darkened to wet grey, blanket moss              (no collision)
  Soffit  distressed_painted_planks dark brown-red under the eaves       (no collision)
Units studs, Z up, pivot = footprint centre on the lake bed (z = 0); the stair faces +Y (the kit front, as bellwood_giant_face).
"""
import math
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "vesperhold"))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import lobby_kit_roofs as roofs  # noqa: E402
import vesperhold_figures as FG  # noqa: E402
import vesperhold_gargoyles as G  # noqa: E402
from lobby_kit_geo import Mesh  # noqa: E402
from vesperhold_figures import log  # noqa: E402

ROOT = HERE.parents[2]
NAME = "Bellwood_TempleHall"
BUILDER = "tools/blender/landmarks/bellwood_temple_hall.py (mac-89, hard-surface + Cycles bake)"
PH = ROOT / "assets/source/vesperhold/polyhaven"
ROLES = ("Stone", "Lacquer", "Tiles", "Soffit")
MAX_EDGE = 0.55  # HIGH subdivision (studs): dense enough for the AO prepass and chipped edges

# Plan (studs). Platform top sits 1.1 over the lake (bed 0, water 2.5): flooded to the top of its stair.
PLAT_W, PLAT_D, PLAT_Z = 88.0, 60.0, 3.6
COL_X, COL_Y = (-30.0, -18.0, -6.0, 6.0, 18.0, 30.0), (-18.0, -6.0, 6.0, 18.0)
COL_R, COL_TOP = 1.25, 19.6
EAVE1 = 23.0  # lower roof eave line
UP_X, UP_Y, UP_Z0, UP_TOP = (-18.0, -6.0, 6.0, 18.0), (-10.0, 10.0), 27.0, 39.0
EAVE2 = 41.4
STAIR_W, STEPS, RUN = 26.0, 8, 1.15
RISE = PLAT_Z / STEPS


class Piece:
    def __init__(self):
        self.meshes = {}

    def m(self, role):
        role = {"Roof": "Tiles", "Timber": "Soffit"}.get(role, role)  # lobby_kit_roofs material names -> temple roles
        if role not in self.meshes:
            self.meshes[role] = Mesh(f"{NAME}__{role}", role, 8.0)
        return self.meshes[role]


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


# ------------------------------------------------------------------------------------------------- stone
def platform(pc):
    s = pc.m("Stone")
    # Stepped base: a plinth course on the bed, the main block, a moulded coping lip.
    s.box((0, 0, 0.6), (PLAT_W + 2.4, PLAT_D + 2.4, 1.2), bevel=0.15)
    s.box((0, 0, (1.2 + PLAT_Z - 0.5) / 2), (PLAT_W, PLAT_D, PLAT_Z - 0.5 - 1.2 + 0.04), bevel=0.1)
    s.box((0, 0, PLAT_Z - 0.25), (PLAT_W + 0.9, PLAT_D + 0.9, 0.5), bevel=0.12)
    # Front stair down into the lake, with cheek walls.
    y0 = PLAT_D / 2 + 0.45
    for k in range(STEPS):
        top = PLAT_Z - RISE * k
        s.box((0, y0 + RUN * (k + 0.5), top / 2), (STAIR_W, RUN + 0.04, top), bevel=0.06)
    L = RUN * STEPS
    for sx in (-1, 1):
        s.box((sx * (STAIR_W / 2 + 0.9), y0 + L / 2, PLAT_Z / 2 + 0.3), (1.8, L, PLAT_Z + 0.6), bevel=0.1)
    # Column bases (round drums) under every column of the ground storey.
    for x in COL_X:
        for y in COL_Y:
            if x in (COL_X[0], COL_X[-1]) or y in (COL_Y[0], COL_Y[-1]):
                s.lathe([(2.0, 0.0), (2.0, 0.35), (1.7, 0.6), (1.55, 0.95)], 16, T(x, y, PLAT_Z))
    # Balustrade: posts every ~4 studs along the platform edge, a top and a bottom rail, short balusters; open at the stair.
    hx, hy, hgt = PLAT_W / 2 - 1.2, PLAT_D / 2 - 1.2, 2.8
    runs = [((-hx, -hy), (hx, -hy)), ((hx, -hy), (hx, hy)), ((-hx, -hy), (-hx, hy)),
            ((-hx, hy), (-STAIR_W / 2 - 1.0, hy)), ((STAIR_W / 2 + 1.0, hy), (hx, hy))]
    for (ax, ay), (bx, by) in runs:
        a, b = Vector((ax, ay, 0)), Vector((bx, by, 0))
        span = (b - a).length
        n = max(1, round(span / 4.0))
        ang = math.atan2(b.y - a.y, b.x - a.x)
        for k in range(n + 1):
            p = a + (b - a) * (k / n)
            s.box((p.x, p.y, PLAT_Z + hgt / 2), (0.8, 0.8, hgt), bevel=0.08)
            s.lathe([(0.5, 0.0), (0.55, 0.2), (0.3, 0.45), (0.0, 0.6)], 8, T(p.x, p.y, PLAT_Z + hgt))
        mid = (a + b) / 2
        R = T(mid.x, mid.y, 0) @ Matrix.Rotation(ang, 4, "Z")
        s.box((0, 0, PLAT_Z + hgt - 0.25), (span, 0.55, 0.45), R, bevel=0.07)
        s.box((0, 0, PLAT_Z + 0.55), (span, 0.5, 0.35), R, bevel=0.05)
        m = n * 3
        for k in range(m):
            if k % 3 == 0:
                continue  # a post stands there
            p = a + (b - a) * (k / m)
            s.lathe([(0.2, 0.0), (0.26, 0.35), (0.14, 0.9), (0.22, 1.5), (0.2, 1.65)], 6, T(p.x, p.y, PLAT_Z + 0.72))


# ------------------------------------------------------------------------------------------------- timber frame
def frame_storey(pc, xs, ys, z0, z1, r, beam_h):
    """Columns on the perimeter of the xs x ys grid, a two-level architrave and bracket sets on top; returns the bracket top."""
    w = pc.m("Lacquer")
    perim = [(x, y) for x in xs for y in ys if x in (xs[0], xs[-1]) or y in (ys[0], ys[-1])]
    for x, y in perim:
        w.lathe([(r * 1.05, 0.0), (r, 0.4), (r, z1 - z0 - 0.3), (r * 1.08, z1 - z0)], 14, T(x, y, z0))
    hx, hy = xs[-1], ys[-1]
    z2 = z1 + beam_h + 0.55
    for z, h, t in ((z1, beam_h, r * 1.1), (z2, beam_h * 0.75, r * 0.95)):
        for sy in (-1, 1):
            w.box((0, sy * hy, z + h / 2), (2 * hx + 2 * r, t, h), bevel=0.06)
        for sx in (-1, 1):
            w.box((sx * hx, 0, z + h / 2), (t, 2 * hy + 2 * r, h), bevel=0.06)
    # Bracket sets (dougong, simplified): stacked widening blocks with an arm toward the eave, on and between the columns.
    top = z2 + beam_h * 0.75
    spots = [(x, y, abs(y) >= hy - 1e-6) for x, y in perim]
    for x0, x1 in zip(xs, xs[1:]):
        spots += [((x0 + x1) / 2, ys[0], True), ((x0 + x1) / 2, ys[-1], True)]
    for y0, y1 in zip(ys, ys[1:]):
        spots += [(xs[0], (y0 + y1) / 2, False), (xs[-1], (y0 + y1) / 2, False)]
    for x, y, along_x in spots:
        for k, (wd, h) in enumerate(((1.6, 0.6), (2.6, 0.5), (3.6, 0.5))):
            z = top + k * 0.55
            w.box((x, y, z + h / 2), (wd, 1.3, h) if along_x else (1.3, wd, h), bevel=0.05)
            reach = 0.5 + 0.45 * k
            if along_x:
                w.box((x, y + math.copysign(reach, y), z + h * 0.4), (1.0, 1.4 + 0.9 * k, h * 0.8), bevel=0.05)
            else:
                w.box((x + math.copysign(reach, x), y, z + h * 0.4), (1.4 + 0.9 * k, 1.0, h * 0.8), bevel=0.05)
    return top + 3 * 0.55


def walls(pc, xs, ys, z0, z1, front_doors):
    """Infill between the wall-line columns: a low dado, lattice above with a dark backing; the front's centre bays stand open."""
    w, dark = pc.m("Lacquer"), pc.m("Soffit")
    sides = [(xs, ys[0], "x"), (xs, ys[-1], "x"), (ys, xs[0], "y"), (ys, xs[-1], "y")]

    def put(mesh, axis, along, across, zc, length, thick, h):
        if axis == "x":
            mesh.box((along, across, zc), (length, thick, h), bevel=0.04 if thick > 0.3 else 0.0)
        else:
            mesh.box((across, along, zc), (thick, length, h), bevel=0.04 if thick > 0.3 else 0.0)

    for line, c, axis in sides:
        front = axis == "x" and c == ys[-1]
        for a, b in zip(line, line[1:]):
            mid, span = (a + b) / 2, b - a - 2.6
            put(w, axis, mid, c, z1 - 0.8, span, 0.35, 1.6)  # header
            if front and front_doors and abs(mid) < 13.0:
                put(w, axis, mid, c, z0 + 0.25, span, 0.5, 0.5)  # threshold of an open doorway
                continue
            put(w, axis, mid, c, z0 + 1.2, span, 0.5, 2.4)  # dado
            zl0, zl1 = z0 + 2.4, z1 - 1.6
            nm = max(3, round(span / 1.1))
            for k in range(1, nm):
                put(w, axis, a + 1.3 + span * k / nm, c, (zl0 + zl1) / 2, 0.16, 0.22, zl1 - zl0)
            nr = max(3, round((zl1 - zl0) / 1.1))
            for k in range(1, nr):
                put(w, axis, mid, c, zl0 + (zl1 - zl0) * k / nr, span, 0.22, 0.16)
            put(dark, axis, mid, c - math.copysign(0.5, c), (zl0 + zl1) / 2, span, 0.2, zl1 - zl0)  # unlit hall behind
    dark.box((0, 0, z1 + 0.1), (2 * xs[-1], 2 * ys[-1], 0.2))  # ceiling


def hall(pc):
    platform(pc)
    top1 = frame_storey(pc, COL_X, COL_Y, PLAT_Z, COL_TOP, COL_R, 1.3)
    walls(pc, (-24.0, -12.0, 0.0, 12.0, 24.0), (-14.0, 14.0), PLAT_Z, COL_TOP, True)
    for (W, D, H, tg, lift, kick, thick, rs, nu, nt), z, upper in (
            ((82.0, 56.0, 10.0, 0.62, 2.8, 1.8, (0.8, 1.7), 1.5, 64, (11, 7)), max(EAVE1, top1 - 0.2), None),
            ((56.0, 36.0, 11.5, 0.55, 2.4, 1.5, (0.7, 1.5), 1.9, 52, (10, 7)), None, (UP_X, UP_Y, UP_Z0, UP_TOP, 1.0, 1.0))):
        if upper:  # upper storey rising out of the lower roof
            xs, ys, z0, z1, r, bh = upper
            top2 = frame_storey(pc, xs, ys, z0, z1, r, bh)
            walls(pc, xs, ys, z0, z1, False)
            z = max(EAVE2, top2 - 0.2)
        sub = Piece()
        roofs.hall(sub, W=W, D=D, H=H, tg=tg, lift=lift, kick=kick, thick=thick, top="Roof", under="Timber",
                   ridge_scale=rs, finial=None, nu=nu, nt=nt)
        for role, mesh in sub.meshes.items():
            pc.m(role).merge(mesh.bm, T(0, 0, z))


# ------------------------------------------------------------------------------------------------- LOW / HIGH
def objects(pc):
    out = {}
    for role in ROLES:
        mesh = pc.meshes[role]
        bm = mesh.finish()
        me = bpy.data.meshes.new(mesh.name)
        bm.to_mesh(me)
        bm.free()
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(38))
        me.validate(clean_customdata=False)
        ob = bpy.data.objects.new(mesh.name, me)
        bpy.context.scene.collection.objects.link(ob)
        out[role] = ob
    return out


def high_copy(lo, seed):
    """HIGH = LOW subdivided until no edge exceeds MAX_EDGE, then chipped edges and pitting (weathering in the shape)."""
    me = lo.data.copy()
    me.name = "HI_" + lo.data.name
    ob = bpy.data.objects.new("HI_" + lo.name, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    for _ in range(9):
        long = [e for e in bm.edges if e.calc_length() > MAX_EDGE]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    FG.weather(ob, chip=0.06, erode=0.012, freq=0.8, seed=seed, edge_pct=(88, 99.5))
    G.detail(ob, bump=0.035, pit=0.03, freq=1.3, seed=seed + 1)
    return ob


def src(asset, label):
    d = PH / asset
    return {"Color": d / f"{asset}_Diffuse_2k.jpg", "Roughness": d / f"{asset}_Rough_2k.jpg", "source": f"Poly Haven {asset} 2K ({label})"}


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(a[0] if a else ROOT / "assets/source/landmarks/bellwood_temple").resolve()
    rdir = out / "renders"
    rdir.mkdir(parents=True, exist_ok=True)
    mode = os.environ.get("HALL_MODE", "clay")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t = time.time()
    pc = Piece()
    hall(pc)
    lows = objects(pc)
    log("LOW " + " ".join(f"{r}={sum(len(p.vertices) - 2 for p in o.data.polygons)}" for r, o in lows.items()) + f"  {time.time() - t:.1f}s")
    lo_b, hi_b = FG.bbox(list(lows.values()))
    rkw = {"views": (("q34", 150.0), ("front", 180.0), ("side", 90.0)), "ez": 6.0, "res": (1600, 1000),
           "close": (150.0, lo_b, hi_b, 14.0)}
    if mode == "clay":
        cm = G.clay_mat()
        for o in lows.values():
            o.data.materials.append(cm)
        files = G.render_set(NAME, list(lows.values()), rdir, "clay", **rkw)
    else:
        import vesp_bake as VB
        stone, wood, tile = src("medieval_blocks_03", "stone"), src("distressed_painted_planks", "lacquer"), src("ceramic_roof_01", "tiles")
        highs = {}
        for i, (role, s, tl) in enumerate((("Stone", stone, 6.0), ("Lacquer", wood, 5.0), ("Tiles", tile, 7.0), ("Soffit", wood, 5.0))):
            highs[role] = high_copy(lows[role], 31 + 7 * i)
            highs[role].data.materials.append(VB.hi_material(f"Hi_Temple{role}", s, tile=tl))
            VB.unwrap(lows[role])
            log(f"HIGH {role} {VB.tris(highs[role])} tris")
        moss = (0.25, 0.32, 0.12)
        looks = {
            "Stone": VB.Look(base=0.30, grime=0.40, edge=0.35, sat=0.15, stone_tint=(0.97, 0.99, 1.0), moss=0.9, moss_open=0.55,
                             moss_col=moss, lichen=0.25, cavity=0.6, rough_base=0.85),
            # deep vermilion lacquer: the grey plank photo keeps its grain, peeling and rust flecks; the tint makes it red
            "Lacquer": VB.Look(base=0.36, grime=0.45, edge=0.25, sat=0.6, stone_tint=(1.0, 0.27, 0.2), moss=0.35, moss_col=moss,
                               cavity=0.55, rough_base=0.62, streak_dark=0.25),
            "Tiles": VB.Look(base=0.17, grime=0.45, edge=0.2, sat=0.12, stone_tint=(0.95, 1.0, 1.04), moss=0.9, moss_open=0.65,
                             moss_col=moss, lichen=0.2, cavity=0.7, rough_base=0.8),
            "Soffit": VB.Look(base=0.16, grime=0.6, edge=0.15, sat=0.5, stone_tint=(0.75, 0.32, 0.25), cavity=0.5, rough_base=0.8),
        }
        files, entry = G.finish(NAME, "Bellwood", lows, highs, out, looks, {r: (0.35, 0.7) for r in ROLES},
                                "Poly Haven medieval_blocks_03, distressed_painted_planks, ceramic_roof_01 (CC0)",
                                extra={"collision": {"Stone": "PreciseConvexDecomposition", "Lacquer": "Default"}},
                                builder=BUILDER, render_kw=rkw)
        G.merge_manifest(out, {NAME: entry}, "Bellwood landmark: Sunken Temple")
    dst = rdir / f"{NAME}_{mode}_sheet.jpg"
    FG.sheet([files], dst)
    log("sheet", dst)


if __name__ == "__main__":
    main()

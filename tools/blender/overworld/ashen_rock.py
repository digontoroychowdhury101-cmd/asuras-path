"""Ashen Stair rock family (lane M7): basalt boulders, switchback cliff faces (2) + corner, scree, ledge, basalt crag.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/ashen_rock.py
  env ASH_ONLY=Name1,Name2 builds a subset; ASH_NORENDER=1 skips renders.

Supersedes: nothing (first Ashen rock script; amberfall_rock.py is the pattern and slice_kit.rock() is reused, neither replaced). Linked via
workers/23d-ashen-kit.md (lead links it from LEDGER.md). New file because the lane run rules want one script run per family.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Ash_Basalt is a 1024 atlas of four 512 quadrants (slice_kit.rock() picks one per face by UV, never tiled): dark columnar basalt, pale ash dust on up-facing
patches, soot-dark scoured base, grey lichen with rust and yellow-green spots.
"""
from pathlib import Path

FAMILY = "rock"
exec(compile((Path(__file__).resolve().parent / "ashen_common.py").read_text(encoding="utf-8"), "ashen_common.py", "exec"), globals())


def basalt_mat():
    n = 512
    g1, g2, grain, vein = field(n, 1.3, 671), field(n, 0.8, 672), field(n, 0.1, 673), field(n, 1.0, 674, 6.0)
    col_ = field(n, 1.0, 675, 8.0)  # vertical streaks: columnar jointing
    bas = np.array([0.33, 0.32, 0.34]) * (0.86 + 0.09 * g1[..., None] + 0.04 * g2[..., None])
    bas = bas * np.where(grain[..., None] > 1.5, 0.7, np.where(grain[..., None] < -1.6, 1.25, 1.0))
    bas = bas * (1 - 0.3 * np.exp(-(col_[..., None] / 0.16) ** 2))
    bas = bas * (1 - 0.25 * np.exp(-(vein[..., None] / 0.14) ** 2)) + np.array([0.10, 0.06, 0.04]) * 0.1 * np.clip(g2[..., None], 0, 2)
    h_b = 0.5 + 0.1 * g1 + 0.04 * g2 + 0.02 * grain - 0.12 * np.exp(-(col_ / 0.16) ** 2) - 0.08 * np.exp(-(vein / 0.14) ** 2)
    m1, m2 = field(n, 1.0, 676), field(n, 1.6, 677)
    dust = np.array([0.60, 0.58, 0.54]) * (0.88 + 0.12 * m1[..., None])
    dust = np.where(m2[..., None] > 1.2, dust * 0.6, dust)  # dark cinder grit in the ash
    h_m = 0.5 + 0.1 * m1 + 0.04 * grain
    mf = field(n, 1.2, 678)
    mud = np.array([0.15, 0.14, 0.14]) * (0.8 + 0.3 * mf[..., None])
    h_d = 0.5 + 0.05 * mf
    lf = field(n, 0.6, 680)
    lich = np.array([0.56, 0.56, 0.53]) * (0.9 + 0.08 * g1[..., None])
    lich = np.where(lf[..., None] > 1.4, np.array([0.54, 0.58, 0.30]), lich)
    lich = np.where(lf[..., None] > 2.0, np.array([0.74, 0.42, 0.14]), lich)
    h_l = 0.5 + 0.08 * g1
    col, hh, rough = np.zeros((2 * n, 2 * n, 3)), np.zeros((2 * n, 2 * n)), np.zeros((2 * n, 2 * n))
    for (qu, qv), c, h, r in (((0, 0), bas, h_b, 0.8 + 0.05 * g1), ((1, 0), dust, h_m, 0.93 + 0.04 * m1), ((0, 1), mud, h_d, 0.62 + 0.05 * mf),
                              ((1, 1), lich, h_l, 0.86 + 0.05 * g1)):
        sl = (slice(qv * n, qv * n + n), slice(qu * n, qu * n + n))
        col[sl], hh[sl], rough[sl] = np.clip(c, 0, 1), h, np.clip(r, 0, 1)
    return mk("Ash_Basalt", col, hh, rough, 5.0)


def block(bm, c, size, rr, cuts=8, rz=0.0, disp=0.1, S=16.0, mud_h=1.2, dust=0.0, flat_top=False, bottom=-3.0):
    """Subdivided, noise-displaced slab centred at c (size sx, sy, sz). Faces pick an Ash_Basalt quadrant (dust up, soot base, lichen, basalt)."""
    sx, sy, sz = size
    c, uvl = Vector(c), _uvl(bm)
    ox = Vector((rr.uniform(0, 80), rr.uniform(0, 80), rr.uniform(0, 80)))
    fb = set(bm.faces)
    eb = set(bm.edges)
    bmesh.ops.create_cube(bm, size=1.0)
    ed = [e for e in bm.edges if e not in eb]
    bmesh.ops.subdivide_edges(bm, edges=ed, cuts=cuts, use_grid_fill=True)
    new = [f for f in bm.faces if f not in fb]
    vs = list({v for f in new for v in f.verts})
    rot = Matrix.Rotation(rz, 3, "Z")
    m = min(sx, sy, sz)
    for v in vs:
        p = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
        q = p / max(sx, sy, sz)
        d = (disp * m) * fbm(q * 5.0 + ox, 3) * 2.0 + 0.04 * m * fbm(q * 18.0 + ox, 2)
        nrm = Vector((v.co.x, v.co.y, v.co.z)).normalized()
        p = p + nrm * d
        if flat_top and v.co.z > 0.45:
            p.z = sz / 2 + 0.04 * noise.noise(Vector((p.x * 0.3, p.y * 0.3, 1.0)))
        v.co = rot @ p + c
        v.co.z = max(v.co.z, bottom)
    bm.normal_update()
    lo = [min(v.co[i] for v in vs) for i in range(3)]
    ex = max(max(v.co[i] for v in vs) - lo[i] for i in range(3))
    S = max(S, ex * 1.02) if ex < S * 2 else S
    offs = {q: (rr.uniform(0, 0.5), rr.uniform(0, 0.5)) for q in QUAD}
    for f in new:
        n, fc = f.normal, f.calc_center_median()
        if n.z > 0.55 and 0.8 * n.z + 0.7 * fbm(fc * 0.1 + ox, 2) + dust > 0.55:
            q = "moss"
        elif fc.z < mud_h * (1 + 0.6 * fbm(fc * 0.3 + ox, 2)):
            q = "mud"
        elif fbm(fc * 0.12 + ox * 2, 2) > 0.7:
            q = "lichen"
        else:
            q = "granite"
        qu, qv = QUAD[q]
        ua, va = ((1, 2), (0, 2), (0, 1))[max(range(3), key=lambda i: abs(n[i]))]
        for l in f.loops:
            co = l.vert.co
            fu, fv = ((co[ua] - lo[ua]) / S) % 1.0 * 0.94 + 0.03, ((co[va] - lo[va]) / S) % 1.0 * 0.94 + 0.03
            l[uvl].uv = ((qu + fu) * 0.5, (qv + fv) * 0.5)
    return new


def shift(bm, n0, dx=0.0, dy=0.0, dz=0.0, rz=0.0):
    bm.faces.ensure_lookup_table()
    vs = list({v for f in bm.faces[n0:] for v in f.verts})
    bmesh.ops.rotate(bm, verts=vs, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(rz, 3, "Z"))
    bmesh.ops.translate(bm, verts=vs, vec=Vector((dx, dy, dz)))


def talus(bm, rr, x0, x1, y0, y1, n, s0, s1, sub=2):
    for _ in range(n):
        r = rr.uniform(s0, s1)
        rock(bm, (rr.uniform(x0, x1), rr.uniform(y0, y1), r * 0.15), (r, r * rr.uniform(0.7, 1.0), r * rr.uniform(0.6, 0.85)), rr, sub=sub, planes=3, bottom=-0.5,
             lump=0.2, rough=0.08, rz=rr.uniform(0, 3.14), mud_h=0.6, S=6.0)


def columns(bm, rr, W, D, Ht, wmin=3.4, wmax=5.0):
    """Face of basalt columns, front toward -Y, x in [-W/2, W/2]: columns of uneven height and protrusion, like jointed lava."""
    x = -W / 2
    while x < W / 2 - 0.5:
        w = min(rr.uniform(wmin, wmax), W / 2 - x)
        h = Ht * rr.uniform(0.72, 1.0)
        d = D * rr.uniform(0.75, 1.0)
        yf = rr.uniform(-1.8, 0.3)
        block(bm, (x + w / 2, yf + d / 2, h / 2 - 2.0), (w * 1.04, d, h + 2.0), rr, cuts=5, disp=0.07, mud_h=1.4, dust=0.15, rz=rr.uniform(-0.04, 0.04))
        x += w


def switchback(bm, rr, x0, x1, z0, z1, y, n):
    """A pilgrim trail cut into the face: n stepped slabs climbing from (x0, z0) to (x1, z1), standing proud of the columns."""
    for i in range(n):
        t = i / (n - 1)
        block(bm, (x0 + (x1 - x0) * t, y, z0 + (z1 - z0) * t + 0.8), ((abs(x1 - x0) / n) * 1.5 + 1.5, 5.0, 1.8), rr, cuts=4, disp=0.04, flat_top=True,
              mud_h=0.0, dust=0.4, rz=rr.uniform(-0.04, 0.04))


# ------------------------------------------------------------------------------------------ pieces
def boulder_a():
    rr = random.Random(2801)
    a = bmesh.new()
    rock(a, (0, 0, 4.0), (6.4, 5.0, 4.6), rr, sub=5, planes=4, rough=0.08, lump=0.2, moss_bias=0.1)
    rock(a, (7.0, 2.6, 1.6), (3.4, 2.8, 2.4), rr, sub=4, planes=3)
    rock(a, (-6.2, -3.0, 0.7), (2.4, 2.1, 1.7), rr, sub=4, planes=3)
    rock(a, (3.2, -5.0, 0.3), (1.5, 1.3, 1.0), rr, sub=3)
    obj("Ash_Boulder_A", "Stone", a, MATS["Ash_Basalt"], smooth=False)


def boulder_b():
    rr = random.Random(2802)
    b = bmesh.new()
    rock(b, (0, 0, 5.6), (3.9, 3.4, 6.5), rr, sub=5, planes=9, lump=0.16, rough=0.05, rz=0.4, moss_bias=-0.5)
    rock(b, (4.6, 2.0, 2.0), (3.0, 2.6, 3.0), rr, sub=4, planes=7, lump=0.16, rough=0.05, moss_bias=-0.3)
    rock(b, (-4.0, -2.6, 1.0), (2.0, 1.7, 1.8), rr, sub=4, planes=6, lump=0.14, rough=0.05)
    obj("Ash_Boulder_B", "Stone", b, MATS["Ash_Basalt"], smooth=False)


def boulder_c():
    rr = random.Random(2803)
    cc = bmesh.new()
    rock(cc, (0, 0, 1.8), (10.0, 5.5, 3.4), rr, sub=5, planes=5, flat_top=3.6, lump=0.14, rough=0.06, moss_bias=0.5)
    rock(cc, (13.0, -1.4, 1.1), (5.6, 3.8, 2.4), rr, sub=4, planes=4, flat_top=2.4, lump=0.14, rough=0.06, moss_bias=0.4)
    rock(cc, (-9.5, 4.5, 0.5), (2.2, 1.9, 1.3), rr, sub=3)
    obj("Ash_Boulder_C", "Stone", cc, MATS["Ash_Basalt"], smooth=False)


def scree(name, seed, n, big, R):
    rr = random.Random(seed)
    bm = bmesh.new()
    talus(bm, rr, -R * 0.4, R * 0.4, -R * 0.4, R * 0.4, big, 1.6, 2.6, sub=2)
    for _ in range(n):
        a, d = rr.uniform(0, TAU), R * rr.uniform(0, 1) ** 0.7
        r = rr.uniform(0.4, 1.1)
        rock(bm, (math.cos(a) * d, math.sin(a) * d, r * 0.1), (r, r * rr.uniform(0.7, 1.0), r * rr.uniform(0.5, 0.8)), rr, sub=1, planes=2, bottom=-0.3,
             lump=0.25, rough=0.1, rz=rr.uniform(0, 3.14), mud_h=0.3, S=4.0)
    obj(name, "Stone", bm, MATS["Ash_Basalt"], smooth=False)


def cliff_a():
    rr = random.Random(2811)
    bm = bmesh.new()
    columns(bm, rr, 40.0, 12.0, 34.0)
    switchback(bm, rr, -15.0, 15.0, 2.0, 20.0, -7.0, 7)
    talus(bm, rr, -20, 20, -11.0, -7.5, 5, 1.8, 3.2)
    obj("Ash_Cliff_Switchback_A", "Stone", bm, MATS["Ash_Basalt"], smooth=False)


def cliff_b():
    rr = random.Random(2812)
    bm = bmesh.new()
    columns(bm, rr, 30.0, 10.0, 48.0)
    switchback(bm, rr, -10.0, 10.0, 2.0, 15.0, -6.5, 5)  # lower run climbs east
    switchback(bm, rr, 10.0, -10.0, 17.0, 30.0, -6.5, 5)  # upper run doubles back west
    talus(bm, rr, -15, 15, -10.0, -6.5, 5, 1.8, 3.0)
    obj("Ash_Cliff_Switchback_B", "Stone", bm, MATS["Ash_Basalt"], smooth=False)


def cliff_corner():
    rr = random.Random(2815)
    bm = bmesh.new()
    W, D = 30.0, 10.0
    columns(bm, rr, W, D, 30.0)
    n0 = len(bm.faces)
    columns(bm, rr, W, D, 28.0)
    shift(bm, n0, dx=W / 2 + D / 2 - 1.0, dy=W / 2 - D / 2 + 1.0, rz=-math.pi / 2)  # second face turned 90 degrees; corner block fills the join
    block(bm, (W / 2 - 1.0, 0.0, 13.0), (D + 4, D + 4, 30.0), rr, cuts=9, disp=0.08, dust=0.1, mud_h=1.5)
    talus(bm, rr, -W / 2, W / 2, -D / 2 - 5.0, -D / 2 - 1.0, 4, 1.8, 3.0)
    obj("Ash_Cliff_Corner", "Stone", bm, MATS["Ash_Basalt"], smooth=False)


def ledge():
    rr = random.Random(2821)
    bm = bmesh.new()
    block(bm, (0, 0, 1.2), (32.0, 9.0, 3.8), rr, cuts=10, disp=0.05, flat_top=True, mud_h=1.0, dust=0.4)
    block(bm, (-10.0, 3.5, -0.2), (14.0, 6.0, 3.0), rr, cuts=6, disp=0.1, mud_h=1.0)
    block(bm, (9.0, -3.0, -0.4), (12.0, 5.0, 2.6), rr, cuts=6, disp=0.1, mud_h=1.0)
    talus(bm, rr, -16, 16, -7.5, -5.0, 4, 1.4, 2.4)
    obj("Ash_Ledge", "Stone", bm, MATS["Ash_Basalt"], smooth=False)


def crag():
    rr = random.Random(2831)
    bm = bmesh.new()
    for x, y, w, h in ((0.0, 0.0, 6.0, 38.0), (4.6, 1.6, 4.6, 29.0), (-4.4, 1.2, 4.8, 24.0), (2.0, -3.2, 4.0, 14.0), (-2.4, -3.4, 3.6, 9.0)):
        z, wi = -2.0, w
        while z < h - 4.0:
            hh = rr.uniform(4.0, 5.6)
            block(bm, (x + rr.uniform(-0.25, 0.25), y + rr.uniform(-0.25, 0.25), z + hh / 2), (wi, wi * rr.uniform(0.85, 1.0), hh + 0.4), rr, cuts=6, disp=0.09,
                  rz=rr.uniform(0, 1.0), mud_h=1.5, dust=-0.2)
            z += hh
            wi *= rr.uniform(0.9, 0.97)
        block(bm, (x, y, z + 1.6), (wi * 0.8, wi * 0.8, 4.0), rr, cuts=5, disp=0.12, rz=rr.uniform(0, 1.0), dust=-0.3)
    talus(bm, rr, -6, 6, -6, 4, 4, 1.6, 2.6)
    obj("Ash_Crag", "Stone", bm, MATS["Ash_Basalt"], smooth=False)


BUILD = [
    ("Ash_Boulder_A", boulder_a), ("Ash_Boulder_B", boulder_b), ("Ash_Boulder_C", boulder_c),
    ("Ash_Scree_A", lambda: scree("Ash_Scree_A", 2811, 45, 9, 11.0)), ("Ash_Scree_B", lambda: scree("Ash_Scree_B", 2812, 90, 5, 9.0)),
    ("Ash_Cliff_Switchback_A", cliff_a), ("Ash_Cliff_Switchback_B", cliff_b), ("Ash_Cliff_Corner", cliff_corner),
    ("Ash_Ledge", ledge), ("Ash_Crag", crag),
]

prep()
basalt_mat()
run_family(BUILD)

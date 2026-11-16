"""Amberfall Ravine rock family (lane M4): ravine boulders, scree, layered cliff walls / corner, ledges, spire.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/amberfall_rock.py
  env AMBER_ONLY=Name1,Name2 builds a subset; AMBER_NORENDER=1 skips renders.

Supersedes: nothing (first Amberfall rock script; slice_kit.rock() is reused, not replaced). Linked via workers/23a-amber-kit.md (lead links it from LEDGER.md).
New file because the lane run rules want one script run per family.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Amb_Sandstone is a 1024 atlas of four 512 quadrants (slice_kit.rock() picks one per face by UV, never tiled): banded amber sandstone,
sun-bleached dust crust on up-facing patches, dark red-brown stained base, ochre lichen.
"""
from pathlib import Path

FAMILY = "rock"
exec(compile((Path(__file__).resolve().parent / "amberfall_common.py").read_text(encoding="utf-8"), "amberfall_common.py", "exec"), globals())


def sandstone_mat():
    n = 512
    yy = np.mgrid[0:n, 0:n][0]
    g1, g2, grain, vein = field(n, 1.3, 371), field(n, 0.8, 372), field(n, 0.1, 373), field(n, 1.0, 374)
    st = np.sin(yy / n * TAU * 9 + g2 * 1.1)
    st2 = np.sin(yy / n * TAU * 23 + g1 * 0.7)
    band = np.clip(np.sin(yy / n * TAU * 4 + g2 * 0.8) * 2.2, -1, 1)
    gran = np.array([0.78, 0.57, 0.36]) * (0.88 + 0.08 * g1[..., None] + 0.16 * band[..., None] + 0.04 * st2[..., None])
    gran = gran * np.where(st[..., None] > 0.82, np.array([0.8, 0.62, 0.55]), 1.0)  # darker iron bands
    gran *= np.where(grain[..., None] > 1.5, 0.7, 1.0)
    gran = gran * (1 - 0.25 * np.exp(-(vein[..., None] / 0.14) ** 2))
    h_g = 0.5 + 0.1 * g1 + 0.04 * g2 + 0.05 * st + 0.02 * grain - 0.1 * np.exp(-(vein / 0.14) ** 2)
    m1, m2 = field(n, 1.0, 376), field(n, 1.6, 377)
    dust = np.array([0.86, 0.74, 0.54]) * (0.88 + 0.12 * m1[..., None])
    dust = dust * np.where(m2[..., None] > 1.2, np.array([0.55, 0.60, 0.30]) / 0.8, 1.0)  # dry-grass flecks in the crust
    h_m = 0.5 + 0.1 * m1 + 0.04 * grain
    mf = field(n, 1.2, 378)
    mud = np.array([0.34, 0.20, 0.13]) * (0.8 + 0.3 * mf[..., None]) * (0.9 + 0.1 * st[..., None])
    h_d = 0.5 + 0.05 * mf
    lf = field(n, 0.6, 380)
    lich = np.array([0.72, 0.52, 0.34]) * (0.9 + 0.08 * g1[..., None])
    lich = np.where(lf[..., None] > 1.4, np.array([0.80, 0.62, 0.20]), lich)
    lich = np.where(lf[..., None] > 2.0, np.array([0.80, 0.36, 0.12]), lich)
    h_l = 0.5 + 0.08 * g1
    col, hh, rough = np.zeros((2 * n, 2 * n, 3)), np.zeros((2 * n, 2 * n)), np.zeros((2 * n, 2 * n))
    for (qu, qv), c, h, r in (((0, 0), gran, h_g, 0.86 + 0.05 * g1), ((1, 0), dust, h_m, 0.92 + 0.04 * m1), ((0, 1), mud, h_d, 0.7 + 0.05 * mf),
                              ((1, 1), lich, h_l, 0.86 + 0.05 * g1)):
        sl = (slice(qv * n, qv * n + n), slice(qu * n, qu * n + n))
        col[sl], hh[sl], rough[sl] = np.clip(c, 0, 1), h, np.clip(r, 0, 1)
    return mk("Amb_Sandstone", col, hh, rough, 5.0)


def block(bm, c, size, rr, cuts=8, rz=0.0, disp=0.1, S=16.0, mud_h=1.2, dust=0.0, flat_top=False, bottom=-3.0):
    """Subdivided, noise-displaced slab centred at c (size sx, sy, sz). Faces pick a Amb_Sandstone quadrant (dust up, mud base, lichen, strata)."""
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


def wall(bm, rr, W, D, Ht, nl, ledge=2.4, base_mud=1.5):
    """Layered strata wall, front toward -Y, x in [-W/2, W/2]: nl strata, each split into 2-4 columns with their own protrusion, width and
    depth so the face steps in and out like fractured sandstone beds."""
    hs = [rr.uniform(0.7, 1.3) for _ in range(nl)]
    k = (Ht + 2.0) / sum(hs)
    z = -2.0
    for i, h in enumerate(hs):
        h *= k
        nc = rr.choice((2, 3, 3, 4))
        wcol = W * rr.uniform(0.9, 1.0) / nc
        x = -W / 2 + (W - wcol * nc) / 2 + wcol / 2
        for j in range(nc):
            d = D * rr.uniform(0.7, 1.0)
            yf = rr.uniform(-ledge, 0.4 * ledge)
            block(bm, (x + rr.uniform(-0.3, 0.3), yf + d / 2, z + h / 2 + rr.uniform(-0.3, 0.3)), (wcol * 1.04, d, h + 0.5), rr, cuts=5, disp=0.09,
                  mud_h=base_mud, dust=0.15, rz=rr.uniform(-0.03, 0.03))
            x += wcol
        z += h


def talus(bm, rr, x0, x1, y0, y1, n, s0, s1, sub=2):
    for _ in range(n):
        r = rr.uniform(s0, s1)
        rock(bm, (rr.uniform(x0, x1), rr.uniform(y0, y1), r * 0.15), (r, r * rr.uniform(0.7, 1.0), r * rr.uniform(0.6, 0.85)), rr, sub=sub, planes=3, bottom=-0.5,
             lump=0.2, rough=0.08, rz=rr.uniform(0, 3.14), mud_h=0.6, S=6.0)


# ------------------------------------------------------------------------------------------ pieces
def boulder_a():
    rr = random.Random(2401)
    a = bmesh.new()
    rock(a, (0, 0, 3.6), (6.5, 5.2, 4.4), rr, sub=5, planes=3, rough=0.08, lump=0.2, moss_bias=-0.2)
    rock(a, (8.0, 3.0, 1.4), (3.6, 3.0, 2.4), rr, sub=4, planes=3)
    rock(a, (-6.5, -3.5, 0.6), (2.4, 2.1, 1.7), rr, sub=4)
    rock(a, (3.5, -5.5, 0.2), (1.5, 1.3, 1.0), rr, sub=3)
    obj("Amber_Boulder_A", "Stone", a, MATS["Amb_Sandstone"], smooth=True)


def boulder_b():
    rr = random.Random(2402)
    b = bmesh.new()
    rock(b, (0, 0, 5.8), (4.0, 3.5, 6.5), rr, sub=5, planes=9, lump=0.16, rough=0.05, rz=0.4, moss_bias=-0.6)
    rock(b, (5.0, 2.0, 1.8), (3.0, 2.6, 2.8), rr, sub=4, planes=7, lump=0.16, rough=0.05, moss_bias=-0.4)
    rock(b, (-4.2, -2.8, 0.9), (2.0, 1.7, 1.7), rr, sub=4, planes=6, lump=0.14, rough=0.05)
    obj("Amber_Boulder_B", "Stone", b, MATS["Amb_Sandstone"], smooth=False)


def boulder_c():
    rr = random.Random(2403)
    cc = bmesh.new()
    rock(cc, (0, 0, 1.6), (11.0, 5.5, 3.2), rr, sub=5, planes=5, flat_top=3.4, lump=0.14, rough=0.06, moss_bias=0.2)
    rock(cc, (14.0, -1.4, 1.0), (6.0, 3.8, 2.2), rr, sub=4, planes=4, flat_top=2.2, lump=0.14, rough=0.06, moss_bias=0.15)
    rock(cc, (-10.5, 4.5, 0.4), (2.2, 1.9, 1.3), rr, sub=3)
    obj("Amber_Boulder_C", "Stone", cc, MATS["Amb_Sandstone"], smooth=False)


def scree(name, seed, n, big, R):
    rr = random.Random(seed)
    bm = bmesh.new()
    talus(bm, rr, -R * 0.4, R * 0.4, -R * 0.4, R * 0.4, big, 1.6, 2.6, sub=2)
    for _ in range(n):
        a, d = rr.uniform(0, TAU), R * rr.uniform(0, 1) ** 0.7
        r = rr.uniform(0.4, 1.1)
        rock(bm, (math.cos(a) * d, math.sin(a) * d, r * 0.1), (r, r * rr.uniform(0.7, 1.0), r * rr.uniform(0.5, 0.8)), rr, sub=1, planes=2, bottom=-0.3,
             lump=0.25, rough=0.1, rz=rr.uniform(0, 3.14), mud_h=0.3, S=4.0)
    obj(name, "Stone", bm, MATS["Amb_Sandstone"], smooth=False)


def cliff_wall(name, seed, W, D, Ht, nl):
    rr = random.Random(seed)
    bm = bmesh.new()
    wall(bm, rr, W, D, Ht, nl)
    talus(bm, rr, -W / 2, W / 2, -D / 2 - 5.0, -D / 2 - 1.0, 5, 1.8, 3.2)
    obj(name, "Stone", bm, MATS["Amb_Sandstone"], smooth=False)


def cliff_corner():
    rr = random.Random(2415)
    bm = bmesh.new()
    W, D = 30.0, 10.0
    wall(bm, rr, W, D, 26.0, 6)
    n0 = len(bm.faces)
    wall(bm, rr, W, D, 24.0, 6)
    shift(bm, n0, dx=W / 2 + D / 2 - 1.0, dy=W / 2 - D / 2 + 1.0, rz=-math.pi / 2)  # second wall turned 90 degrees; corner block fills the join
    block(bm, (W / 2 - 1.0, 0.0, 11.0), (D + 4, D + 4, 26.0), rr, cuts=9, disp=0.08, dust=0.1, mud_h=1.5)
    talus(bm, rr, -W / 2, W / 2, -D / 2 - 5.0, -D / 2 - 1.0, 4, 1.8, 3.0)
    obj("Amber_Cliff_Corner", "Stone", bm, MATS["Amb_Sandstone"], smooth=False)


def ledge_long():
    rr = random.Random(2421)
    bm = bmesh.new()
    block(bm, (0, 0, 1.2), (32.0, 9.0, 3.8), rr, cuts=10, disp=0.05, flat_top=True, mud_h=1.0, dust=0.3)
    block(bm, (-10.0, 3.5, -0.2), (14.0, 6.0, 3.0), rr, cuts=6, disp=0.1, mud_h=1.0)
    block(bm, (9.0, -3.0, -0.4), (12.0, 5.0, 2.6), rr, cuts=6, disp=0.1, mud_h=1.0)
    talus(bm, rr, -16, 16, -7.5, -5.0, 4, 1.4, 2.4)
    obj("Amber_Ledge_Long", "Stone", bm, MATS["Amb_Sandstone"], smooth=False)


def ledge_overhang():
    rr = random.Random(2422)
    bm = bmesh.new()
    block(bm, (0, 5.0, 7.0), (26.0, 10.0, 18.0), rr, cuts=9, disp=0.06, mud_h=1.5, dust=0.1)  # wall mass behind
    block(bm, (0, -2.5, 15.0), (26.0, 16.0, 3.4), rr, cuts=10, disp=0.05, flat_top=True, mud_h=0.0, dust=0.3)  # overhanging slab, walkable top
    block(bm, (-9.5, -1.0, 11.0), (5.0, 5.0, 8.0), rr, cuts=6, disp=0.1, mud_h=0.0)  # lumps under the lip
    block(bm, (8.5, 0.0, 11.4), (4.0, 5.0, 7.0), rr, cuts=6, disp=0.1, mud_h=0.0)
    talus(bm, rr, -13, 13, -6.0, -2.5, 5, 1.6, 2.8)
    obj("Amber_Ledge_Overhang", "Stone", bm, MATS["Amb_Sandstone"], smooth=False)


def spire():
    rr = random.Random(2431)
    bm = bmesh.new()
    z, w = -2.0, 9.0
    for i in range(7):
        h = rr.uniform(4.2, 6.2)
        block(bm, (rr.uniform(-0.6, 0.6), rr.uniform(-0.6, 0.6), z + h / 2), (w, w * rr.uniform(0.85, 1.0), h + 0.5), rr, cuts=8, disp=0.1,
              rz=rr.uniform(0, 1.0), mud_h=1.5, dust=-0.2)
        z += h
        w *= rr.uniform(0.82, 0.9)
    talus(bm, rr, -5, 5, -5, 5, 4, 1.6, 2.6)
    obj("Amber_Spire", "Stone", bm, MATS["Amb_Sandstone"], smooth=False)


BUILD = [
    ("Amber_Boulder_A", boulder_a), ("Amber_Boulder_B", boulder_b), ("Amber_Boulder_C", boulder_c),
    ("Amber_Scree_A", lambda: scree("Amber_Scree_A", 2411, 45, 9, 11.0)), ("Amber_Scree_B", lambda: scree("Amber_Scree_B", 2412, 90, 5, 9.0)),
    ("Amber_Cliff_Wall_A", lambda: cliff_wall("Amber_Cliff_Wall_A", 2413, 40.0, 12.0, 30.0, 7)),
    ("Amber_Cliff_Wall_B", lambda: cliff_wall("Amber_Cliff_Wall_B", 2414, 28.0, 10.0, 44.0, 9)),
    ("Amber_Cliff_Corner", cliff_corner), ("Amber_Ledge_Long", ledge_long), ("Amber_Ledge_Overhang", ledge_overhang), ("Amber_Spire", spire),
]

prep()
sandstone_mat()
run_family(BUILD)

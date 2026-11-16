"""Frostmere Heads built family (lane M6): ice-fishing hut, stone cairn, frozen dock section, prayer-flag line, brazier, stair run, retaining wall, sled, lantern.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b --python tools/blender/overworld/frostmere_built.py
  env FROST_ONLY=Name1,Name2 builds a subset; FROST_NORENDER=1 skips renders.

Supersedes: nothing (searched first: no earlier Frostmere scripts; amberfall_built.py is the pattern, not replaced). Linked via workers/23c-frost-kit.md
(the lane lead links it from LEDGER.md). New file because the lane run rules want one script run per family; the hero beacon is its own run (frostmere_hero.py).
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Each piece carries a Snow sub-mesh (Frost_Snow) where snow would lie; Iron is the only metal map (Frost_Iron_Metal); Frost_Glow is the ember / lantern emitter
(set Material = Neon in Studio). Frost_Flag is a 512 atlas of five weathered colour bands, one per flag.
"""
from pathlib import Path

FAMILY = "built"
exec(compile((Path(__file__).resolve().parent / "frostmere_common.py").read_text(encoding="utf-8"), "frostmere_common.py", "exec"), globals())


def place(bm, n0, dx=0.0, dy=0.0, dz=0.0, rz=0.0):
    bm.faces.ensure_lookup_table()
    vs = list({v for f in bm.faces[n0:] for v in f.verts})
    if rz:
        bmesh.ops.rotate(bm, verts=vs, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(rz, 3, "Z"))
    bmesh.ops.translate(bm, verts=vs, vec=Vector((dx, dy, dz)))


def slab(bm, xe, ze, xr, zr, t, y0, y1):
    """Roof panel running along Y: eave (xe, ze) to ridge (xr, zr), thickness t."""
    solid(bm, [Vector(p) for y in (y0, y1) for p in ((xe, y, ze), (xr, y, zr), (xr, y, zr - t), (xe, y, ze - t))], 6.0)


# ------------------------------------------------------------------------------------------ ice-fishing hut
def fishing_hut():
    rr = random.Random(2801)
    rng.seed(2801)
    tm, rf, sn, ir, ice, rp = (bmesh.new() for _ in range(6))
    W, D, z0, ph = 9.0, 7.0, 1.4, 0.75
    for sx in (-1, 1):  # skids and sleepers
        bx(tm, sx * 3.6, 0, 0.0, 1.1, D + 3.0, 0.9, mode="timber", bev=0.1, uvs=6.0)
    for y in (-2.6, 2.6):
        bx(tm, 0, y, 0.9, W + 0.6, 0.9, 0.5, mode="timber", bev=0.06, uvs=6.0)
    bx(tm, 0, 0, 0.9, W, D, 0.5, mode="timber", bev=0.05, uvs=6.0)  # floor
    for r in range(8):  # planked walls, horizontal boards
        z = z0 + r * ph
        bx(tm, 0, D / 2 - 0.25, z, W, 0.5, ph - 0.03, mode="timber", bev=0.05, uvs=6.0, rz=rr.uniform(-0.004, 0.004))
        for sx in (-1, 1):
            if sx > 0 and r in (4, 5):  # window slot on the east wall
                for lo, hi in ((-D / 2, -1.3), (1.3, D / 2)):
                    bx(tm, sx * (W / 2 - 0.25), (lo + hi) / 2, z, 0.5, hi - lo, ph - 0.03, mode="timber", bev=0.05, uvs=6.0)
            else:
                bx(tm, sx * (W / 2 - 0.25), 0, z, 0.5, D, ph - 0.03, mode="timber", bev=0.05, uvs=6.0, rz=rr.uniform(-0.004, 0.004))
        if r >= 6:
            bx(tm, 0, -D / 2 + 0.25, z, W, 0.5, ph - 0.03, mode="timber", bev=0.05, uvs=6.0)
        else:
            for sx in (-1, 1):  # front wall either side of the door
                bx(tm, sx * (W / 4 + 0.65), -D / 2 + 0.25, z, W / 2 - 1.3, 0.5, ph - 0.03, mode="timber", bev=0.05, uvs=6.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(tm, sx * (W / 2 - 0.1), sy * (D / 2 - 0.1), 1.0, 0.8, 0.8, 6.9, mode="timber", bev=0.08, uvs=6.0)  # corner posts
    for sx in (-1, 1):  # door frame
        bx(tm, sx * 1.4, -D / 2 - 0.05, z0, 0.35, 0.8, 4.5, mode="timber", bev=0.05, uvs=6.0)
    bx(tm, -1.9, -D / 2 - 1.1, z0, 2.4, 0.3, 4.4, rz=1.1, mode="timber", bev=0.04, uvs=6.0)  # door swung open
    for r in range(4):  # gable boards, front and back
        w = W * (1 - (r + 1) * ph / 3.4)
        for y in (-D / 2 + 0.25, D / 2 - 0.25):
            bx(tm, 0, y, z0 + 8 * ph + r * ph, w, 0.5, ph - 0.03, mode="timber", bev=0.05, uvs=6.0)
    ze, zr = z0 + 8 * ph - 0.2, z0 + 8 * ph + 3.3
    for sx in (-1, 1):
        slab(rf, sx * (W / 2 + 0.9), ze, 0.0, zr, 0.45, -D / 2 - 1.0, D / 2 + 1.0)
        slab(sn, sx * (W / 2 + 0.3), ze + 0.5, 0.0, zr + 0.4, 0.8, -D / 2 - 0.6, D / 2 + 0.6)
    cyl(ir, 2.4, 1.4, ze + 0.6, 0.38, 0.38, 4.4, seg=8, uvs=4.0)  # stove pipe and rain cap
    cyl(ir, 2.4, 1.4, ze + 5.0, 0.62, 0.1, 0.45, seg=8, uvs=4.0)
    for k, (cx, cy, s) in enumerate(((0.0, -D / 2 - 2.6, 4.6), (-W / 2 - 1.8, 0.0, 4.0), (W / 2 + 1.8, 1.0, 3.6), (0.0, D / 2 + 2.2, 4.4))):
        skirt(sn, Vector((cx, cy, -0.4)), s, 1.3, 1.5, 7, k, nseg=16, rings=2, rr=rr, uvs=6.0)
    legs = ((4.6, -8.0), (6.6, -8.0), (5.6, -6.2))  # fishing tripod with a line over the hole
    ap = Vector((5.6, -7.4, 5.4))
    for lx, ly in legs:
        tube(tm, [Vector((lx, ly, 0.0)), ap], [0.22, 0.14], sides=5, uvs=4.0)
    tube(rp, [ap, ap - Vector((0, 0, 2.5)), ap - Vector((0, 0, 5.2))], [0.07, 0.06, 0.05], sides=3, uvs=2.0)
    cyl(ice, 5.6, -7.4, -0.15, 2.0, 1.8, 0.3, seg=12, uvs=4.0)
    obj("Frost_Fishing_Hut", "Timber", tm, MATS["Frost_Timber"])
    obj("Frost_Fishing_Hut", "Roof", rf, MATS["Frost_Roof"])
    obj("Frost_Fishing_Hut", "Iron", ir, MATS["Frost_Iron"])
    obj("Frost_Fishing_Hut", "Rope", rp, MATS["Frost_Rope"])
    obj("Frost_Fishing_Hut", "Ice", ice, MATS["Frost_Ice"])
    obj("Frost_Fishing_Hut", "Snow", sn, MATS["Frost_Snow"], smooth=True)


# ------------------------------------------------------------------------------------------ cairn
def cairn():
    rr = random.Random(2802)
    bm = bmesh.new()
    z = -0.6
    for i in range(8):
        rx, hz = 3.4 * (1 - i * 0.1), 1.2 * (1 - i * 0.05)
        rock(bm, (rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.3), z + hz), (rx * rr.uniform(0.9, 1.1), rx * rr.uniform(0.85, 1.0), hz), rr, sub=3, planes=4,
             bottom=-1.0, lump=0.12, rough=0.05, rz=rr.uniform(0, 3.14), moss_bias=0.3, mud_h=0.8, S=8.0)
        z += hz * 1.75
    rock(bm, (0.0, 0.0, z + 1.4), (0.9, 0.8, 1.9), rr, sub=3, planes=5, bottom=-1.0, lump=0.1, rough=0.04, moss_bias=0.3, S=6.0)  # capstone standing on edge
    for k in range(6):  # tumbled base stones
        a = k * TAU / 6 + rr.uniform(-0.3, 0.3)
        rock(bm, (math.cos(a) * 4.3, math.sin(a) * 4.3, 0.1), (rr.uniform(1.0, 1.6), rr.uniform(0.9, 1.4), rr.uniform(0.7, 1.0)), rr, sub=3, bottom=-0.6,
             lump=0.2, rz=rr.uniform(0, 3.14), moss_bias=0.35, S=6.0)
    obj("Frost_Cairn", "Stone", bm, MATS["Frost_Slate"], smooth=False)


# ------------------------------------------------------------------------------------------ frozen dock
def dock_section():
    rr = random.Random(2803)
    rng.seed(2803)
    tm, ice, sn = bmesh.new(), bmesh.new(), bmesh.new()
    L, Wd = 24.0, 8.0
    for sy in (-3.4, 0.0, 3.4):  # stringers
        bx(tm, 0, sy, 1.8, L, 0.8, 0.7, mode="timber", bev=0.08, uvs=6.0)
    x = -L / 2 + 0.9
    while x < L / 2:  # deck boards across
        bx(tm, x, 0, 2.5, 1.7, Wd, 0.5, mode="timber", bev=0.05, uvs=6.0, rz=rr.uniform(-0.01, 0.01))
        x += 1.85
    for px in (-10.2, -3.4, 3.4, 10.2):
        for sy in (-3.6, 3.6):
            cyl(tm, px, sy, -1.5, 0.6, 0.52, 5.3, seg=8, uvs=6.0)
            cyl(ice, px, sy, -1.0, 1.9, 1.5, 1.1, seg=10, uvs=4.0)  # ice collar frozen round each post
    for sx in (-1, 1):
        cyl(tm, sx * 10.8, 3.2, 3.0, 0.5, 0.4, 1.1, seg=8, uvs=4.0)  # bollards
    for i, (cx, ln, ang) in enumerate(((-6.0, 15.0, 0.06), (8.0, 14.0, -0.05))):  # cracked ice sheet the dock is frozen into
        bx(ice, cx, 0.0, -1.0, ln, Wd + 5.0, 1.15, rz=ang, bev=0.3, jag=0.25, uvs=8.0)
    bx(ice, 0.0, 0.0, -1.0, L + 3.0, 3.0, 1.1, bev=0.3, jag=0.2, uvs=8.0)
    for i in range(5):
        cx = -9.5 + i * 4.8
        skirt(sn, Vector((cx, rr.uniform(-1.5, 1.5), 3.0)), 3.5, 0.5, 0.5, 6, i, nseg=12, rings=2, rr=rr, uvs=6.0)
    for sy in (-6.5, 6.5):
        for i in range(3):
            skirt(sn, Vector((-8.0 + 8.0 * i, sy, 0.1)), 3.4, 0.7, 0.8, 6, i + sy, nseg=12, rings=2, rr=rr, uvs=6.0)
    obj("Frost_Dock_Section", "Timber", tm, MATS["Frost_Timber"])
    obj("Frost_Dock_Section", "Ice", ice, MATS["Frost_Ice"])
    obj("Frost_Dock_Section", "Snow", sn, MATS["Frost_Snow"], smooth=True)


# ------------------------------------------------------------------------------------------ prayer-flag line
def flag(bm, x0, zr, W, H, b, ph):
    uvl = _uvl(bm)
    nu, nv = 4, 2

    def pt(i, j, s):
        u, v = i / nu, j / nv
        return Vector((x0 + u * W, 0.4 * math.sin(u * 5.5 + ph) * u + s * 0.015, zr - v * H * (1 - 0.12 * u) - 0.1 * u * math.sin(ph)))

    for s in (1, -1):
        g = [[bm.verts.new(pt(i, j, s)) for i in range(nu + 1)] for j in range(nv + 1)]
        for j in range(nv):
            for i in range(nu):
                qs = [g[j][i], g[j][i + 1], g[j + 1][i + 1], g[j + 1][i]]
                f = bm.faces.new(qs if s > 0 else qs[::-1])
                for l in f.loops:
                    iu = [k for k, v in enumerate(qs) if v is l.vert][0]
                    uu, vv = (i + (1 if iu in (1, 2) else 0)) / nu, (j + (1 if iu in (2, 3) else 0)) / nv
                    l[uvl].uv = (0.01 + 0.98 * uu, (b * 102 + 6 + (1 - vv) * 90) / 512)


def prayer_flags():
    rr = random.Random(2804)
    rng.seed(2804)
    tm, rp, fl, ft = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    zt, sag = 14.2, 2.8
    for sx in (-1, 1):
        cyl(tm, sx * 11.0, 0, -1.0, 0.7, 0.42, 16.0, seg=8, uvs=6.0)
        bx(tm, sx * 11.0, 0, 12.4, 0.4, 2.6, 0.35, mode="timber", bev=0.05, uvs=4.0)  # crossbar
        for k in range(4):
            a = k * TAU / 4 + 0.4
            rock(ft, (sx * 11.0 + math.cos(a) * 1.5, math.sin(a) * 1.5, 0.1), (1.0, 0.9, 0.8), rr, sub=3, bottom=-0.5, lump=0.2, moss_bias=0.4, S=5.0)
    zr = lambda x: zt - sag * (1 - (x / 11.0) ** 2)
    pts = [Vector((-11.0 + 22.0 * k / 12, 0, zr(-11.0 + 22.0 * k / 12))) for k in range(13)]
    tube(rp, pts, [0.1] * 13, sides=4, uvs=2.0)
    for sx in (-1, 1):  # guy ropes to ground stakes
        tube(rp, [Vector((sx * 11.0, 0, 15.0)), Vector((sx * 14.5, 3.2, 7.5)), Vector((sx * 17.0, 6.0, 0.2))], [0.09, 0.08, 0.07], sides=4, uvs=2.0)
        cyl(tm, sx * 17.0, 6.0, -0.5, 0.25, 0.2, 1.4, seg=6, uvs=4.0)
    for i in range(15):
        x0 = -9.6 + i * 1.28
        flag(fl, x0, zr(x0 + 0.65) - 0.1, 1.2, 1.6, i % 5, rr.uniform(0, 6))
    obj("Frost_Prayer_Flags", "Poles", tm, MATS["Frost_Timber"])
    obj("Frost_Prayer_Flags", "Rope", rp, MATS["Frost_Rope"])
    obj("Frost_Prayer_Flags", "Flags", fl, MATS["Frost_Flag"], recalc=False)
    obj("Frost_Prayer_Flags", "Footing", ft, MATS["Frost_Slate"], smooth=True)


# ------------------------------------------------------------------------------------------ brazier
def brazier():
    rr = random.Random(2805)
    st, ir, fi, sn = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    cyl(st, 0, 0, -0.5, 2.7, 2.4, 1.0, seg=12, uvs=6.0)
    for k in range(3):  # tripod legs
        a = k * TAU / 3 + 0.5
        tube(ir, [Vector((math.cos(a) * 2.2, math.sin(a) * 2.2, 0.4)), Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, 1.8)), Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 3.1))],
             [0.22, 0.2, 0.17], sides=5, uvs=3.0)
    lathe(ir, [(0.01, 2.9), (1.0, 2.95), (1.8, 3.5), (2.05, 4.1), (1.95, 4.3), (1.75, 4.15), (1.6, 3.65), (0.9, 3.3), (0.01, 3.25)], z0=0.0, seg=16, turns=3, uvs=4.0)
    for sg in (-1, 1):  # side handles
        tube(ir, [Vector((sg * 1.95, 0, 4.0)), Vector((sg * 2.5, 0, 4.0)), Vector((sg * 2.8, 0, 3.6))], [0.13, 0.13, 0.11], sides=4, uvs=3.0)
    for (fx, fy, hh, rw) in ((0.0, 0.0, 5.0, 1.0), (0.7, 0.4, 3.1, 0.7), (-0.6, -0.5, 3.6, 0.75)):  # flames
        lathe(fi, [(0.01, 3.7), (rw, 3.9), (rw * 1.12, 4.0 + hh * 0.25), (rw * 0.75, 4.0 + hh * 0.55), (rw * 0.3, 4.0 + hh * 0.85), (0.02, 4.0 + hh)], x=fx, y=fy, seg=10, turns=1, uvs=4.0)
    lathe(fi, [(0.01, 3.5), (1.5, 3.6), (1.2, 3.95), (0.01, 4.0)], seg=12, turns=1, uvs=4.0)  # ember bed
    skirt(sn, Vector((0, 0, -0.3)), 4.2, 0.9, 1.2, 6, 0.3, nseg=14, rings=2, rr=rr, uvs=6.0)
    obj("Frost_Brazier", "Stone", st, MATS["Frost_Stone"])
    obj("Frost_Brazier", "Iron", ir, MATS["Frost_Iron"], smooth=True)
    obj("Frost_Brazier", "Fire", fi, MATS["Frost_Glow"], smooth=True)
    obj("Frost_Brazier", "Snow", sn, MATS["Frost_Snow"], smooth=True)


# ------------------------------------------------------------------------------------------ stairs, wall
def stair_run():
    rr = random.Random(2806)
    s, w, sn = bmesh.new(), bmesh.new(), bmesh.new()
    n, tread, rise = 12, 2.0, 0.9
    for i in range(n):
        top = (i + 1) * rise
        bx(s, 0, i * tread + tread / 2, -1.0, 9.0, tread, top + 1.0, bev=0.14)
        for sx in (-1, 1):
            bx(w, sx * 5.25, i * tread + tread / 2, -1.0, 1.5, tread, top + 2.4, bev=0.15)
            bx(w, sx * 5.25, i * tread + tread / 2, top + 1.4, 1.9, tread + 0.15, 0.4, bev=0.08)
            if rr.random() < 0.8:
                bx(sn, sx * 5.25, i * tread + tread / 2, top + 1.8, 1.7, tread * 0.9, 0.3, bev=0.1, uvs=4.0)
        if rr.random() < 0.7:  # wind-drifted snow on the treads
            bx(sn, rr.uniform(-2.0, 2.0), i * tread + tread / 2, top, rr.uniform(3.0, 6.5), tread * 0.8, 0.28, bev=0.1, uvs=4.0)
    obj("Frost_Stair_Run", "Steps", s, MATS["Frost_Stone"])
    obj("Frost_Stair_Run", "Walls", w, MATS["Frost_StoneDark"])
    obj("Frost_Stair_Run", "Snow", sn, MATS["Frost_Snow"], smooth=True)


def retaining_wall():
    rr = random.Random(2807)
    s, cap, sn = bmesh.new(), bmesh.new(), bmesh.new()
    L, H, rows = 24.0, 8.0, 5
    ch = H / rows
    for r in range(rows):
        x = -L / 2 + (rr.uniform(-1.4, 0) if r % 2 else 0)
        z0 = r * ch - (1.5 if r == 0 else 0.0)
        while x < L / 2 - 0.2:
            w = rr.uniform(2.0, 3.8)
            lo, hi = max(x, -L / 2), min(x + w, L / 2)
            if hi - lo > 0.4:
                bx(s, (lo + hi) / 2, rr.uniform(-0.1, 0.1) - 0.12 * (4 - r), z0, hi - lo - 0.08, 3.4 + 0.2 * (4 - r), ch + (1.5 if r == 0 else 0.0) - 0.06, bev=0.14,
                   rz=rr.uniform(-0.015, 0.015))
            x += w
    for bxp in (-L / 2 + 1.0, 0.0, L / 2 - 1.0):  # buttresses on the back
        bx(s, bxp, 3.0, -1.5, 2.2, 2.6, H * 0.8, bev=0.12)
    x = -L / 2
    while x < L / 2 - 0.3:
        w = min(rr.uniform(3.0, 3.8), L / 2 - x)
        bx(cap, x + w / 2, 0, H, w - 0.08, 4.2, 0.6, bev=0.08)
        if rr.random() < 0.85:
            bx(sn, x + w / 2, 0, H + 0.6, w - 0.3, 3.8, 0.45, bev=0.1, uvs=4.0)
        x += w
    for i in range(4):
        skirt(sn, Vector((-9.0 + 6.0 * i, -3.2, -0.3)), 3.8, 0.8, 0.9, 6, i, nseg=12, rings=2, rr=rr, uvs=6.0)
    obj("Frost_Retaining_Wall", "Wall", s, MATS["Frost_Stone"])
    obj("Frost_Retaining_Wall", "Coping", cap, MATS["Frost_StoneDark"])
    obj("Frost_Retaining_Wall", "Snow", sn, MATS["Frost_Snow"], smooth=True)


# ------------------------------------------------------------------------------------------ sled
def sled():
    rr = random.Random(2808)
    rng.seed(2808)
    tm, ir, rp, sn = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    warp = lambda x: 2.4 * max(0.0, (x - 3.6) / 1.9) ** 2 + 0.5 * max(0.0, (-x - 4.4) / 1.1) ** 2
    for sy in (-1.5, 1.5):
        loft_beam(tm, 11.0, 0.5, 0.7, warp, z0=0.18, x0=0.0, y0=sy, m=14, uvs=6.0)
        loft_beam(ir, 10.2, 0.34, 0.18, warp, z0=0.0, x0=0.0, y0=sy, m=14, uvs=4.0)  # iron shoes
        for sx in (-3.5, 3.5):
            bx(tm, sx, sy, 0.88, 0.5, 0.5, 0.9, mode="timber", bev=0.05, uvs=4.0)
    x = -4.2
    while x < 4.3:
        bx(tm, x, 0, 1.78, 0.9, 3.9, 0.35, mode="timber", bev=0.05, uvs=4.0, rz=rr.uniform(-0.01, 0.01))
        x += 1.05
    for sy in (-1.2, 1.2):
        bx(tm, 0, sy, 1.55, 9.4, 0.35, 0.23, mode="timber", bev=0.04, uvs=4.0)
    bx(tm, -1.7, 0.0, 2.13, 3.4, 3.0, 2.2, bev=0.08, mode="timber", uvs=5.0)  # crates
    bx(tm, 1.9, 0.2, 2.13, 2.6, 2.6, 1.6, bev=0.08, mode="timber", uvs=5.0, rz=0.1)
    for cx, top in ((-1.7, 4.4), (1.9, 3.8)):  # lashings over the cargo
        tube(rp, [Vector((cx, -1.7, 2.1)), Vector((cx, -1.7, top)), Vector((cx, 1.7, top)), Vector((cx, 1.7, 2.1))], [0.1] * 4, sides=4, uvs=2.0)
    tube(rp, [Vector((5.2, -1.5, 2.9)), Vector((7.0, -0.8, 2.6)), Vector((8.4, 0.0, 1.2)), Vector((9.6, 0.8, 0.2))], [0.12, 0.11, 0.1, 0.09], sides=4, uvs=2.0)
    tube(rp, [Vector((5.2, 1.5, 2.9)), Vector((7.0, 0.8, 2.6)), Vector((8.4, 0.0, 1.2))], [0.12, 0.11, 0.1], sides=4, uvs=2.0)
    skirt(sn, Vector((-1.7, 0, 4.2)), 2.4, 0.4, 0.4, 5, 0.3, nseg=10, rings=2, rr=rr, uvs=4.0)
    skirt(sn, Vector((1.9, 0.2, 3.6)), 2.0, 0.4, 0.4, 5, 0.9, nseg=10, rings=2, rr=rr, uvs=4.0)
    skirt(sn, Vector((-4.4, 0, 2.0)), 1.8, 0.3, 0.3, 5, 1.4, nseg=8, rings=1, rr=rr, uvs=4.0)
    obj("Frost_Sled", "Timber", tm, MATS["Frost_Timber"])
    obj("Frost_Sled", "Iron", ir, MATS["Frost_Iron"])
    obj("Frost_Sled", "Rope", rp, MATS["Frost_Rope"])
    obj("Frost_Sled", "Snow", sn, MATS["Frost_Snow"], smooth=True)


# ------------------------------------------------------------------------------------------ lantern
def lantern():
    s, b, g, sn = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    rr = random.Random(2809)
    bx(s, 0, 0, -0.5, 2.8, 2.8, 1.2, bev=0.18)
    bx(s, 0, 0, 0.7, 2.1, 2.1, 0.5, bev=0.12)
    bx(s, 0, 0, 1.2, 1.2, 1.2, 4.6, bev=0.18)
    bx(s, 0, 0, 5.8, 1.9, 1.9, 0.45, bev=0.12)
    bx(s, 0, 0, 6.25, 2.2, 2.2, 0.4, bev=0.1)
    z = 6.65
    for dx in (-1, 1):
        for dy in (-1, 1):
            bx(b, dx * 0.9, dy * 0.9, z, 0.24, 0.24, 1.7, bev=0.04, uvs=4.0)
    bx(b, 0, 0, z + 1.7, 2.3, 2.3, 0.24, bev=0.05, uvs=4.0)
    bx(g, 0, 0, z + 0.1, 1.3, 1.3, 1.5, bev=0.05, uvs=4.0)
    uvl = _uvl(s)
    before = set(s.faces)
    cone = bmesh.ops.create_cone(s, cap_ends=True, segments=4, radius1=3.1, radius2=0.45, depth=1.5)
    for v in cone["verts"]:
        v.co = Matrix.Rotation(math.pi / 4, 3, "Z") @ v.co + Vector((0, 0, z + 1.94 + 0.75))
    for f in [f for f in s.faces if f not in before]:
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x / 8, l.vert.co.y / 8 + l.vert.co.z / 16)
    cyl(b, 0, 0, z + 3.35, 0.3, 0.12, 0.7, seg=8, uvs=4.0)
    skirt(sn, Vector((0, 0, z + 2.7)), 2.0, 0.45, 0.35, 5, 0.4, nseg=10, rings=2, rr=rr, uvs=4.0)  # snow on the cap
    skirt(sn, Vector((0, 0, 0.7)), 2.2, 0.35, 0.3, 5, 1.2, nseg=10, rings=1, rr=rr, uvs=4.0)  # and on the plinth
    skirt(sn, Vector((0, 0, -0.5)), 3.8, 0.9, 1.1, 6, 0.8, nseg=12, rings=2, rr=rr, uvs=6.0)
    obj("Frost_Lantern", "Stone", s, MATS["Frost_Stone"])
    obj("Frost_Lantern", "Iron", b, MATS["Frost_Iron"])
    obj("Frost_Lantern", "Glow", g, MATS["Frost_Glow"])
    obj("Frost_Lantern", "Snow", sn, MATS["Frost_Snow"], smooth=True)


BUILD = [
    ("Frost_Fishing_Hut", fishing_hut), ("Frost_Cairn", cairn), ("Frost_Dock_Section", dock_section), ("Frost_Prayer_Flags", prayer_flags),
    ("Frost_Brazier", brazier), ("Frost_Stair_Run", stair_run), ("Frost_Retaining_Wall", retaining_wall), ("Frost_Sled", sled), ("Frost_Lantern", lantern),
]

prep()
frost_built_mats()
run_family(BUILD)

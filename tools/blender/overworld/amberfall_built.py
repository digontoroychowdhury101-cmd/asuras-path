"""Amberfall Ravine built family (lane M4): aqueduct span sections, abutment, stairs, retaining walls, rope footbridge, shrine, lanterns, rope rails, cart, crates.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/amberfall_built.py
  env AMBER_ONLY=Name1,Name2 builds a subset; AMBER_NORENDER=1 skips renders.

Supersedes: nothing (first Amberfall built script). Linked via workers/23a-amber-kit.md (the lead links it from LEDGER.md). New file because the lane run
rules want one script run per family; the hero aqueduct is a separate family run (amberfall_hero.py).
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Aqueduct span sections are 24 studs on the pitch with HALF piers (2.5 wide) at both ends, so they tile edge to edge into 5 stud piers.
"""
from pathlib import Path

FAMILY = "built"
_here = Path(__file__).resolve().parent
exec(compile((_here / "amberfall_common.py").read_text(encoding="utf-8"), "amberfall_common.py", "exec"), globals())
exec(compile((_here / "amberfall_aqueduct_lib.py").read_text(encoding="utf-8"), "amberfall_aqueduct_lib.py", "exec"), globals())


def place(bm, n0, dx=0.0, dy=0.0, dz=0.0, rz=0.0, rx=0.0):
    """Rotate (about Z then X, through the origin) and translate every face created after index n0."""
    bm.faces.ensure_lookup_table()
    vs = list({v for f in bm.faces[n0:] for v in f.verts})
    if rz:
        bmesh.ops.rotate(bm, verts=vs, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(rz, 3, "Z"))
    if rx:
        bmesh.ops.rotate(bm, verts=vs, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(rx, 3, "X"))
    bmesh.ops.translate(bm, verts=vs, vec=Vector((dx, dy, dz)))


def three(name, P, A, D, mp="Amb_Stone", ma="Amb_StoneDark", md="Amb_Stone"):
    obj(name, "Piers", P, MATS[mp])
    obj(name, "Arches", A, MATS[ma])
    obj(name, "Deck", D, MATS[md])


# ------------------------------------------------------------------------------------------ aqueduct sections
def span_a():
    rr = random.Random(2501)
    P, A, D = bmesh.new(), bmesh.new(), bmesh.new()
    bay(P, A, D, rr, 0.0, 19.0, 5.0, 0.0, 8.0, 7.6, 14.0, 9.5, 2.2, -2.0, 27.0, bw_=0.5, bd=0.4, clip=(-12.0, 12.0), with_deck=True, d_deck=8.0)
    three("Amber_Aqueduct_Span_A", P, A, D)


def span_tall():
    rr = random.Random(2502)
    P, A, D = bmesh.new(), bmesh.new(), bmesh.new()
    bay(P, A, D, rr, 0.0, 19.0, 5.0, 0.0, 9.0, 8.0, 16.0, 9.5, 2.2, -2.0, 28.0, bw_=0.6, bd=0.5, clip=(-12.0, 12.0))
    brick_h(D, -12.0, 12.0, 28.0, 30.4, 0.0, 9.6, rr, bw=(4.0, 6.0))  # cornice course
    for sx, pr in ((-6.0, (True, False)), (6.0, (True, True))):  # upper arcade: two 9 stud arches on a 12 pitch, piers at -12, 0, 12
        bay(P, A, D, rr, sx, 9.0, 3.0, 0.0, 6.4, 5.6, 37.0, 4.5, 1.4, 30.4, 45.0, clip=(-12.0, 12.0), piers=pr, n=9, ch=1.8, with_deck=True, d_deck=6.4)
    three("Amber_Aqueduct_Span_Tall", P, A, D)


def span_ruined():
    rr = random.Random(2503)
    P, A, D = bmesh.new(), bmesh.new(), bmesh.new()
    clip = (-12.0, 12.0)
    pier(P, rr, 12.0, 0.0, 5.0, 8.0, -2.0, 24.0, 0.5, 0.4, 2.0, clip)  # right pier survives high, left pier is snapped lower
    pier(P, rr, -12.0, 0.0, 5.0, 8.0, -2.0, 15.5, 0.5, 0.4, 2.0, clip)
    bx(P, 10.5, 0.0, 14.0, 3.0, 8.5, 0.9, bev=0.1)
    ring = bmesh.new()
    arch(A, 0.0, 0.0, 14.0, 9.5, 2.2, 8.0, n=11, a0=0.0, a1=math.pi * 6 / 11)  # right 6 voussoirs
    arch(A, 0.0, 0.0, 14.0, 9.5, 2.2, 8.0, n=11, a0=math.pi * 9 / 11, a1=math.pi)  # left springers
    ring.free()
    z = 14.0
    while z < 24.5:  # right spandrel stub, ragged
        h = rr.uniform(1.7, 2.1)
        w = 7.0 - 0.9 * (z - 14.0) / 2.0 + rr.uniform(-0.6, 0.6)
        brick_h(A, 9.5 - max(w, 1.5), 9.5, z, z + h, 0.0, 7.6, rr, bw=(2.0, 3.0))
        z += h
    deck(D, rr, 8.0, 12.0, 24.0, 0.0, 7.6)
    for _ in range(16):  # fallen blocks
        x, y = rr.uniform(-9.5, 8.0), rr.uniform(-6.0, 6.0)
        bx(A, x, y, -0.6 + rr.uniform(0, 1.2), rr.uniform(1.8, 3.6), rr.uniform(1.4, 2.4), rr.uniform(1.0, 1.8), rz=rr.uniform(0, 3.14), bev=0.14, jag=0.2)
    three("Amber_Aqueduct_Span_Ruined", P, A, D)


def abutment():
    rr = random.Random(2504)
    P, A, D = bmesh.new(), bmesh.new(), bmesh.new()
    pier(P, rr, 0.0, 0.0, 16.0, 14.0, -2.0, 27.0, 1.0, 0.8, 2.0)  # massive end block, battered
    # culvert arch at the foot: opening 6 wide on the front face
    arch(A, 0.0, -7.6, 3.5, 3.0, 1.4, 1.6, n=9)
    for sx in (-1, 1):
        bx(A, sx * 4.6, -7.8, -0.6, 1.6, 1.8, 4.2, bev=0.1)
    deck(D, rr, -8.0, 8.0, 27.0, 0.0, 14.0)
    for sx in (-1, 1):  # corner buttresses stepping up
        for i in range(3):
            bx(P, sx * (8.7 + 0.3 * (2 - i)), -5.0, -2.0 + i * 6.0, 2.4 + 1.0 * (2 - i), 4.0, 8.0 + 3.0 * (2 - i) * 0.0, bev=0.12)
    for i in range(6):  # spill steps at the channel mouth
        bx(D, 0.0, -8.0 - 1.2 * i, 27.0 - 0.9 * i - 0.4, 5.0, 1.4, 0.9, bev=0.08)
    three("Amber_Aqueduct_Abutment", P, A, D)


# ------------------------------------------------------------------------------------------ stairs, walls
def stair_run(name, seed, n=12, worn=False):
    rr = random.Random(seed)
    s, w = bmesh.new(), bmesh.new()
    tread, rise = 2.0, 0.9
    for i in range(n):
        top = (i + 1) * rise
        if worn and i in (4, 5, 9):
            continue  # missing treads
        dz = rr.uniform(-0.25, 0.1) if worn else 0.0
        bx(s, 0, i * tread + tread / 2, -1.0, 9.0, tread, top + 1.0 + dz, bev=0.14, rz=rr.uniform(-0.02, 0.02) if worn else 0.0)
        for sx in (-1, 1):
            if worn and rr.random() < 0.3:
                continue
            bx(w, sx * 5.25, i * tread + tread / 2, -1.0, 1.5, tread, top + 2.4 - (rr.uniform(0, 1.2) if worn else 0), bev=0.15)
            if not worn or rr.random() < 0.6:
                bx(w, sx * 5.25, i * tread + tread / 2, top + 1.4 if not worn else top + 0.8, 1.9, tread + 0.15, 0.4, bev=0.08)
    obj(name, "Steps", s, MATS["Amb_Stone"])
    obj(name, "Walls", w, MATS["Amb_StoneDark"])


def retaining(name, seed, L, H, corner=False, broken=False):
    rr = random.Random(seed)
    s, cap = bmesh.new(), bmesh.new()

    def arm(length, hh, cut):
        ch = hh / 5
        for r in range(5):
            x = -length / 2 + (rr.uniform(-1.4, 0) if r % 2 else 0)
            z0 = r * ch - (1.5 if r == 0 else 0.0)
            while x < length / 2 - 0.2:
                w = rr.uniform(2.0, 3.8)
                lo, hi = max(x, -length / 2), min(x + w, length / 2)
                skip = (broken and r >= 3 and rr.random() < 0.35) or (cut and r == 4 and hi > length / 2 - 5)
                if hi - lo > 0.4 and not skip:
                    bx(s, (lo + hi) / 2, rr.uniform(-0.1, 0.1) + 0.12 * (4 - r) * -1, z0, hi - lo - 0.08, 3.4 + 0.2 * (4 - r), ch + (1.5 if r == 0 else 0.0) - 0.06,
                       bev=0.14, rz=rr.uniform(-0.015, 0.015))
                x += w
        for bxp in (-length / 2 + 1.0, 0.0, length / 2 - 1.0):  # buttresses on the back
            bx(s, bxp, 3.0, -1.5, 2.2, 2.6, hh * 0.8, bev=0.12)
        x = -length / 2
        while x < length / 2 - 0.3:
            w = min(rr.uniform(3.0, 3.8), length / 2 - x)
            if not (broken and rr.random() < 0.3):
                bx(cap, x + w / 2, 0, hh, w - 0.08, 4.2, 0.6, bev=0.08)
            x += w

    arm(L, H, False)
    if corner:
        n0, nc = len(s.faces), len(cap.faces)
        arm(L * 0.7, H * 0.85, True)
        place(s, n0, dx=L / 2 + 1.7, dy=L * 0.35 - 1.7, rz=-math.pi / 2)
        place(cap, nc, dx=L / 2 + 1.7, dy=L * 0.35 - 1.7, rz=-math.pi / 2)
    obj(name, "Wall", s, MATS["Amb_Stone"])
    obj(name, "Coping", cap, MATS["Amb_StoneDark"])


# ------------------------------------------------------------------------------------------ footbridge, rails
def footbridge():
    rr = random.Random(2531)
    st, tm, rp = bmesh.new(), bmesh.new(), bmesh.new()
    L, Wd, sag = 44.0, 6.0, 2.6
    zd = lambda x: 5.0 - sag * (1 - (2 * x / L) ** 2)
    for sx in (-1, 1):  # stone abutments with a stepped top
        bx(st, sx * (L / 2 + 4.0), 0, -2.0, 9.0, 9.0, 7.2, bev=0.15)
        bx(st, sx * (L / 2 + 4.0), 0, 5.2, 9.4, 9.4, 0.8, bev=0.1)
        for i in range(2):
            bx(st, sx * (L / 2 + 7.2 + 1.4 * i), 0, -2.0, 3.0, 8.0 - 2 * i, 3.4 - 1.4 * i, bev=0.12)
    x = -L / 2
    while x < L / 2:  # planks, each a flat board at the local sag height
        xm = x + 1.1
        bx(tm, xm, 0, zd(xm) - 0.3, 2.0, Wd, 0.6, mode="timber", bev=0.05, uvs=6.0, rz=rr.uniform(-0.01, 0.01))
        x += 2.25
    for sy in (-1, 1):
        for sx in (-1, 1):
            bx(tm, sx * (L / 2 - 0.4), sy * (Wd / 2 + 0.4), 4.0, 0.9, 0.9, 5.5, mode="timber", bev=0.05, uvs=4.0)  # end posts
        pts_h = [Vector((xx, sy * (Wd / 2 + 0.4), zd(xx) + 3.6)) for xx in np.linspace(-L / 2 + 0.4, L / 2 - 0.4, 14)]
        pts_l = [Vector((xx, sy * (Wd / 2 + 0.4), zd(xx) + 0.9)) for xx in np.linspace(-L / 2 + 0.4, L / 2 - 0.4, 14)]
        rope(rp, pts_h, 0.2)
        rope(rp, pts_l, 0.16)
        for i in range(1, 13):  # vertical hangers
            rope(rp, [pts_l[i], pts_h[i]], 0.09, sides=4)
        for i in (0, 13):
            rope(rp, [pts_h[i], pts_h[i] + Vector((0, 0, -0.6))], 0.2)
    for sy in (-1, 1):  # two stringer ropes under the deck
        rope(rp, [Vector((xx, sy * 2.0, zd(xx) - 0.8)) for xx in np.linspace(-L / 2, L / 2, 10)], 0.22)
    obj("Amber_Footbridge_Rope", "Stone", st, MATS["Amb_Stone"])
    obj("Amber_Footbridge_Rope", "Timber", tm, MATS["Amb_Timber"])
    obj("Amber_Footbridge_Rope", "Rope", rp, MATS["Amb_Rope"], smooth=True)


def rope_rail():
    rr = random.Random(2532)
    tm, rp = bmesh.new(), bmesh.new()
    for sx in (-1, 1):
        cyl(tm, sx * 6.0, 0, -0.6, 0.55, 0.45, 5.0, seg=8, uvs=4.0)
        cyl(tm, sx * 6.0, 0, 4.3, 0.7, 0.7, 0.35, seg=8, uvs=4.0)
    for z, sag in ((3.6, 1.2), (1.9, 0.9)):
        pts = [Vector((x, 0, z - sag * (1 - (x / 6.0) ** 2))) for x in np.linspace(-6.0, 6.0, 9)]
        rope(rp, pts, 0.16)
    obj("Amber_Rope_Rail", "Timber", tm, MATS["Amb_Timber"])
    obj("Amber_Rope_Rail", "Rope", rp, MATS["Amb_Rope"], smooth=True)


# ------------------------------------------------------------------------------------------ shrine, lanterns
def shrine():
    rr = random.Random(2541)
    s, t, rf, b, g = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for w, z0, top in ((15.0, -1.0, 1.4), (12.6, 1.4, 2.8)):
        bx(s, 0, 0, z0, w, w, top - z0, bev=0.2)
    for k in range(4):  # front steps (-Y)
        bx(s, 0, -7.0 - (3 - k) * 1.2, -1.0, 5.0, 1.2, 0.7 * (k + 1) + 0.4, bev=0.1)
    P = 4.0
    for px in (-P, P):
        for py in (-P, P):
            bx(s, px, py, 2.8, 2.4, 2.4, 0.6, bev=0.1)
            bx(s, px, py, 3.4, 1.7, 1.7, 8.6, bev=0.1)
            bx(t, px, py, 12.0, 2.4, 2.4, 0.6, mode="timber", bev=0.08)
    for z in (11.0,):
        for sx in (-P, P):
            bx(t, sx, 0, z, 1.0, 2 * P + 2.4, 1.0, mode="timber", bev=0.06)
        for sy in (-P, P):
            bx(t, 0, sy, z, 2 * P + 2.4, 1.0, 1.0, mode="timber", bev=0.06)
    bx(s, 0, 0, 2.8, 3.6, 2.6, 2.0, bev=0.12)  # offering block
    lathe(b, [(0.9, 4.8), (1.4, 5.0), (1.5, 5.6), (1.0, 6.2), (0.8, 5.6), (0.7, 5.0)], z0=0.0, seg=16)  # bronze bowl on it
    bx(g, 0, 0, 5.8, 0.9, 0.9, 0.9, bev=0.05, uvs=4.0)  # small flame
    zr = 13.1
    R = dict(hw=8.3, z0=zr, h=5.5, flat=0.2, p=1.6, curl=2.2, thick=1.1)
    roof(rf, R, n=14)
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        c = roof_pt(R, sx, sy)
        o = Vector((sx, sy, 0)).normalized()
        tube(b, [c - o * 0.4, c + o * 1.0 + Vector((0, 0, 1.0)), c + o * 1.8 + Vector((0, 0, 2.4))], [0.5, 0.32, 0.1], sides=5, uvs=4.0)
    lathe(b, [(0.05, 0), (1.3, 0), (1.1, 0.5), (0.6, 1.1), (0.7, 1.8), (0.3, 2.5), (0.05, 3.0)], z0=zr + R["h"] - 0.3, seg=10)  # finial
    obj("Amber_Shrine", "Stone", s, MATS["Amb_Stone"])
    obj("Amber_Shrine", "Timber", t, MATS["Amb_Timber"])
    obj("Amber_Shrine", "Roof", rf, MATS["Amb_Roof"])
    obj("Amber_Shrine", "Bronze", b, MATS["Amb_Bronze"])
    obj("Amber_Shrine", "Glow", g, MATS["Amb_Glow"])


def lantern_stone():
    s, b, g = bmesh.new(), bmesh.new(), bmesh.new()
    bx(s, 0, 0, -0.5, 2.6, 2.6, 1.2, bev=0.18)
    bx(s, 0, 0, 0.7, 2.0, 2.0, 0.5, bev=0.12)
    bx(s, 0, 0, 1.2, 1.2, 1.2, 4.2, bev=0.18)
    bx(s, 0, 0, 5.4, 1.7, 1.7, 0.45, bev=0.12)
    bx(s, 0, 0, 5.85, 2.0, 2.0, 0.4, bev=0.1)
    z = 6.25
    for dx in (-1, 1):
        for dy in (-1, 1):
            bx(b, dx * 0.82, dy * 0.82, z, 0.22, 0.22, 1.5, mode="timber", bev=0.04, uvs=4.0)
    bx(b, 0, 0, z + 1.5, 2.1, 2.1, 0.22, bev=0.05, uvs=4.0)
    bx(g, 0, 0, z + 0.1, 1.2, 1.2, 1.3, bev=0.05, uvs=4.0)
    uvl = _uvl(s)
    before = set(s.faces)
    cone = bmesh.ops.create_cone(s, cap_ends=True, segments=4, radius1=2.9, radius2=0.4, depth=1.4)
    for v in cone["verts"]:
        v.co = Matrix.Rotation(math.pi / 4, 3, "Z") @ v.co + Vector((0, 0, z + 1.72 + 0.7))
    for f in [f for f in s.faces if f not in before]:
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x / 8, l.vert.co.y / 8 + l.vert.co.z / 16)
    cyl(b, 0, 0, z + 3.1, 0.28, 0.12, 0.7, seg=8, uvs=4.0)
    obj("Amber_Lantern_Stone", "Stone", s, MATS["Amb_Stone"])
    obj("Amber_Lantern_Stone", "Bronze", b, MATS["Amb_Bronze"])
    obj("Amber_Lantern_Stone", "Glow", g, MATS["Amb_Glow"])


def lantern_hanging():
    t, b, g, rp = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    cyl(t, 0, 0, -0.8, 0.6, 0.42, 10.8, seg=8, uvs=4.0)
    bx(t, 0, 0, -0.8, 2.2, 2.2, 0.8, mode="timber", bev=0.1, uvs=4.0)
    tube(t, [Vector((0, 0, 9.6)), Vector((1.4, 0, 10.8)), Vector((3.2, 0, 11.2)), Vector((4.6, 0, 10.9))], [0.4, 0.32, 0.26, 0.22], sides=6, uvs=4.0)
    rope(rp, [Vector((4.6, 0, 10.9)), Vector((4.6, 0, 9.2))], 0.1, sides=4)
    for dx in (-1, 1):
        for dy in (-1, 1):
            bx(b, 4.6 + dx * 0.55, dy * 0.55, 6.6, 0.14, 0.14, 2.6, bev=0.02, uvs=4.0)
    bx(b, 4.6, 0, 9.0, 1.5, 1.5, 0.2, bev=0.03, uvs=4.0)
    bx(b, 4.6, 0, 6.4, 1.3, 1.3, 0.2, bev=0.03, uvs=4.0)
    bx(g, 4.6, 0, 6.7, 0.9, 0.9, 2.3, bev=0.04, uvs=4.0)
    obj("Amber_Lantern_Hanging", "Timber", t, MATS["Amb_Timber"])
    obj("Amber_Lantern_Hanging", "Rope", rp, MATS["Amb_Rope"])
    obj("Amber_Lantern_Hanging", "Bronze", b, MATS["Amb_Bronze"])
    obj("Amber_Lantern_Hanging", "Glow", g, MATS["Amb_Glow"])


# ------------------------------------------------------------------------------------------ cart, crates
def wheel(bm, rad, x, y, z, rr):
    """Spoked wheel in the XZ plane at (x, y, z): built flat then stood up."""
    n0 = len(bm.faces)
    lathe(bm, [(rad - 0.7, -0.35), (rad, -0.35), (rad, 0.35), (rad - 0.7, 0.35)], seg=20, turns=4, uvs=4.0)
    lathe(bm, [(0.0, -0.45), (0.9, -0.45), (0.9, 0.45), (0.0, 0.45)], seg=10, turns=2, uvs=4.0)
    for k in range(6):
        bx(bm, math.cos(k * math.pi / 6 * 2) * rad / 2, math.sin(k * math.pi / 6 * 2) * rad / 2, -0.2, rad - 1.0, 0.42, 0.4, rz=k * math.pi / 3 + math.pi / 2,
           mode="timber", bev=0.0, uvs=4.0)
    place(bm, n0, dx=x, dy=y, dz=z, rx=math.pi / 2)


def cart():
    rr = random.Random(2551)
    t = bmesh.new()
    for i in range(8):  # bed planks
        bx(t, -5.0 + i * 1.45, 0, 3.0, 1.35, 6.0, 0.35, mode="timber", bev=0.04, uvs=4.0)
    for sy in (-1, 1):
        bx(t, 0, sy * 3.0, 3.35, 11.8, 0.4, 0.5, mode="timber", bev=0.04, uvs=4.0)  # chassis rails
        for k in range(5):
            bx(t, -5.0 + k * 2.5, sy * 3.0, 3.8, 0.4, 0.4, 2.2, mode="timber", bev=0.03, uvs=4.0)  # side stakes
        bx(t, 0, sy * 3.0, 5.7, 11.8, 0.4, 0.4, mode="timber", bev=0.03, uvs=4.0)
        bx(t, 4.0, sy * 1.5, 3.0, 8.0 + 0.0, 0.4, 0.4, rz=sy * -0.08, mode="timber", bev=0.03, uvs=4.0)  # shaft (front, +X)
        tube(t, [Vector((5.5, sy * 1.6, 3.3)), Vector((10.5, sy * 1.2, 3.6)), Vector((15.0, sy * 0.9, 4.2))], [0.34, 0.3, 0.26], sides=6, uvs=4.0)
        wheel(t, 3.4, 0.0, sy * 3.9, 3.4, rr)
    bx(t, 0, 0, 2.7, 0.5, 8.4, 0.5, mode="timber", bev=0.04, uvs=4.0)  # axle
    bx(t, -6.2, 0, 3.4, 0.4, 6.0, 2.4, mode="timber", bev=0.03, uvs=4.0)  # tail board
    for sy in (-1, 1):
        bx(t, 6.0, sy * 1.5, 3.0, 0.5, 0.5, 2.4, mode="timber", bev=0.03, uvs=4.0)
    obj("Amber_Cart", "Timber", t, MATS["Amb_Timber"])


def crate(bm, x, y, z0, s, rz):
    h = s
    n0 = len(bm.faces)
    bx(bm, 0, 0, 0, s, s, h, mode="timber", bev=0.08, uvs=3.0)
    for dx in (-1, 1):
        for dy in (-1, 1):
            bx(bm, dx * (s / 2 - 0.18), dy * (s / 2 - 0.18), 0, 0.36, 0.36, h + 0.05, mode="timber", bev=0.0, uvs=3.0)
    for k in (0.3, 0.7):
        bx(bm, 0, 0, h * k - 0.1, s + 0.2, s + 0.2, 0.2, mode="timber", bev=0.0, uvs=3.0)
    place(bm, n0, dx=x, dy=y, dz=z0, rz=rz)


def barrel(bm, x, y, r=1.5, h=3.6):
    lathe(bm, [(0.01, 0.0), (r * 0.82, 0.0), (r * 0.98, h * 0.2), (r, h * 0.5), (r * 0.98, h * 0.8), (r * 0.82, h), (0.01, h)], x=x, y=y, seg=14, turns=3, uvs=4.0)
    for z in (0.35, 0.85):
        lathe(bm, [(r * (0.84 if z < 0.5 else 0.84) + 0.1, h * z - 0.15), (r + 0.18, h * z - 0.15), (r + 0.18, h * z + 0.15), (r * 0.84 + 0.1, h * z + 0.15)], x=x, y=y, seg=14, turns=3, uvs=4.0)


def crate_stack():
    rr = random.Random(2552)
    t, rp = bmesh.new(), bmesh.new()
    crate(t, 0, 0, 0, 3.6, 0.05)
    crate(t, 4.2, 0.3, 0, 3.2, -0.12)
    crate(t, -0.3, 0.1, 3.6, 3.0, 0.3)
    crate(t, 4.0, 0.4, 3.2, 2.6, 0.5)
    crate(t, -3.8, 1.2, 0, 2.4, 0.9)
    barrel(t, -2.0, -4.4)
    barrel(t, 1.6, -4.6, 1.4, 3.3)
    barrel(t, 5.6, -3.6, 1.5, 3.6)
    # coiled rope on top of the barrel
    for k in range(3):
        rope(rp, [Vector((-2.0 + math.cos(a) * (1.0 - 0.1 * k), -4.4 + math.sin(a) * (1.0 - 0.1 * k), 3.8 + 0.22 * k)) for a in np.linspace(0, TAU, 14)], 0.18)
    obj("Amber_Crate_Stack", "Timber", t, MATS["Amb_Timber"])
    obj("Amber_Crate_Stack", "Rope", rp, MATS["Amb_Rope"], smooth=True)


BUILD = [
    ("Amber_Aqueduct_Span_A", span_a), ("Amber_Aqueduct_Span_Tall", span_tall), ("Amber_Aqueduct_Span_Ruined", span_ruined),
    ("Amber_Aqueduct_Abutment", abutment),
    ("Amber_Stair_Run", lambda: stair_run("Amber_Stair_Run", 2511)), ("Amber_Stair_Worn", lambda: stair_run("Amber_Stair_Worn", 2512, worn=True)),
    ("Amber_Retaining_Wall_A", lambda: retaining("Amber_Retaining_Wall_A", 2521, 22.0, 9.0)),
    ("Amber_Retaining_Wall_B", lambda: retaining("Amber_Retaining_Wall_B", 2522, 18.0, 8.0, corner=True, broken=True)),
    ("Amber_Footbridge_Rope", footbridge), ("Amber_Shrine", shrine), ("Amber_Lantern_Stone", lantern_stone),
    ("Amber_Lantern_Hanging", lantern_hanging), ("Amber_Rope_Rail", rope_rail), ("Amber_Cart", cart), ("Amber_Crate_Stack", crate_stack),
]

prep()
built_mats()
run_family(BUILD)

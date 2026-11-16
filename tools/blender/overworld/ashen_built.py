"""Ashen Stair built family (lane M7): stair runs (straight, long, turning), retaining walls, pilgrim shrine, prayer-flag line, stone lantern, rest pavilion, broken gate.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/ashen_built.py
  env ASH_ONLY=Name1,Name2 builds a subset; ASH_NORENDER=1 skips renders.

Supersedes: nothing (first Ashen built script; amberfall_built.py is the pattern, not replaced). Linked via workers/23d-ashen-kit.md (the lead links it from LEDGER.md).
New file because the lane run rules want one script run per family; the hero temple is a separate family run (ashen_hero.py).
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Stair runs climb +Y from the origin (first tread's front edge at y = 0); Mtn_Stair_Run slot is 14 x 12 x 22 (14 steps, rise 0.85, tread 1.6, width 14).
"""
from pathlib import Path

FAMILY = "built"
exec(compile((Path(__file__).resolve().parent / "ashen_common.py").read_text(encoding="utf-8"), "ashen_common.py", "exec"), globals())


def beam(bm, p0, p1, w, h, uvs=6.0):
    """Timber (or stone) bar of cross-section w x h from p0 to p1 at any angle (hexahedron; obj() fixes the winding)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    side = d.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 0.01 else Vector((1, 0, 0))
    up = side.cross(d).normalized()
    q = [side * w / 2 + up * h / 2, -side * w / 2 + up * h / 2, -side * w / 2 - up * h / 2, side * w / 2 - up * h / 2]
    solid(bm, [p0 + o for o in q] + [p1 + o for o in q], uvs)


# ------------------------------------------------------------------------------------------ stairs
def flight(s, w, n, tread, rise, win, z_base=0.0, rr=None, worn=0.0):
    """n treads climbing +Y from y = 0; treads in `s`, cheek walls + coping in `w`. Tread tops sit at z_base + (i + 1) * rise."""
    for i in range(n):
        top = z_base + (i + 1) * rise
        dz = -rr.uniform(0, worn) if worn else 0.0
        bx(s, 0, i * tread + tread / 2, -1.0, win, tread, top + 1.0 + dz, bev=0.14, rz=rr.uniform(-0.015, 0.015) if worn else 0.0)
        for sx in (-1, 1):
            bx(w, sx * (win / 2 + 0.75), i * tread + tread / 2, -1.0, 1.5, tread, top + 2.4, bev=0.15)
            bx(w, sx * (win / 2 + 0.75), i * tread + tread / 2, top + 1.4, 1.9, tread + 0.15, 0.4, bev=0.08)


def stair_run(name, n, win, seed, worn=0.0):
    rr = random.Random(seed)
    s, w = bmesh.new(), bmesh.new()
    flight(s, w, n, 1.6, 0.85, win, 0.0, rr, worn)
    obj(name, "Steps", s, MATS["Ash_Stone"])
    obj(name, "Walls", w, MATS["Ash_StoneDark"])


def stair_turn():
    rr = random.Random(2903)
    s, w = bmesh.new(), bmesh.new()
    n, tread, rise, win = 8, 1.6, 0.85, 9.0
    wt = win + 3.0
    flight(s, w, n, tread, rise, win, 0.0, rr, 0.12)
    top = n * rise
    yl = n * tread + wt / 2
    bx(s, 0, yl, -1.0, wt, wt, top + 1.0, bev=0.14)  # landing
    bx(w, 0, yl + wt / 2 - 0.75, -1.0, wt, 1.5, top + 2.4, bev=0.15)  # back parapet
    bx(w, 0, yl + wt / 2 - 0.75, top + 1.4, wt + 0.4, 1.9, 0.4, bev=0.08)
    bx(w, -wt / 2 + 0.75, yl, -1.0, 1.5, wt - 1.5, top + 2.4, bev=0.15)  # west parapet
    bx(w, -wt / 2 + 0.75, yl, top + 1.4, 1.9, wt - 1.5, 0.4, bev=0.08)
    ns, nw = len(s.faces), len(w.faces)
    flight(s, w, n, tread, rise, win, top, rr, 0.12)  # second flight turns right (+X)
    place(s, ns, dx=wt / 2, dy=yl, rz=-math.pi / 2)
    place(w, nw, dx=wt / 2, dy=yl, rz=-math.pi / 2)
    obj("Ash_Stair_Run_Turn", "Steps", s, MATS["Ash_Stone"])
    obj("Ash_Stair_Run_Turn", "Walls", w, MATS["Ash_StoneDark"])


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
    obj(name, "Wall", s, MATS["Ash_Stone"])
    obj(name, "Coping", cap, MATS["Ash_StoneDark"])


# ------------------------------------------------------------------------------------------ shrine, flags, lantern
def bell(b, x, y, z0, k=1.0):
    lathe(b, [(0.3 * k, 2.2 * k), (0.55 * k, 2.1 * k), (0.9 * k, 1.6 * k), (1.2 * k, 0.7 * k), (1.35 * k, 0.2 * k), (1.4 * k, 0), (1.15 * k, 0), (0.95 * k, 0.6 * k),
              (0.6 * k, 1.5 * k), (0.2 * k, 1.9 * k)], x=x, y=y, z0=z0, seg=14)


def shrine():
    s, t, rf, b, g = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for w, z0, top in ((13.0, -1.0, 1.4), (10.6, 1.4, 2.6)):
        bx(s, 0, 0, z0, w, w, top - z0, bev=0.2)
    for k in range(3):  # front steps (-Y)
        bx(s, 0, -5.8 - (2 - k) * 1.2, -1.0, 4.0, 1.2, 0.7 * (k + 1) + 0.4, bev=0.1)
    bx(s, 0, 0.6, 2.6, 5.6, 4.6, 4.2, bev=0.12)  # the little shrine house (stone)
    bx(t, 0, -1.8, 2.6, 2.4, 0.5, 3.6, mode="timber", bev=0.06, uvs=4.0)  # door frame in its front face
    for px in (-3.0, 3.0):
        for py in (-1.9, 3.1):
            bx(t, px, py, 2.6, 0.7, 0.7, 5.0, mode="timber", bev=0.06, uvs=4.0)
    bx(t, 0, 0.6, 7.6, 7.2, 6.2, 0.7, mode="timber", bev=0.08, uvs=4.0)
    R = dict(hw=4.8, z0=8.3, h=3.6, flat=0.2, p=1.6, curl=1.4, thick=0.9)
    roof(rf, R, n=12)
    tails(t, R, 7, 0.45)
    horns(b, R, 0.4)
    finial(b, R["z0"] + R["h"] - 0.2, 0.28, seg=10)
    bell(b, 0, -4.2, 4.9, 1.0)  # bronze bell hung under the front eave
    tube(b, [Vector((0, -4.2, 7.2)), Vector((0, -4.2, 8.4))], [0.12, 0.12], sides=4, uvs=2.0)
    lathe(b, [(0.9, 0.0), (1.4, 0.2), (1.5, 0.8), (1.0, 1.2), (0.8, 0.8), (0.7, 0.2)], x=3.0, y=-3.4, z0=2.6, seg=14)  # offering bowl
    bx(g, 3.0, -3.4, 3.1, 0.7, 0.7, 0.8, bev=0.05, uvs=4.0)  # small flame
    obj("Ash_Shrine_Pilgrim", "Stone", s, MATS["Ash_Stone"])
    obj("Ash_Shrine_Pilgrim", "Timber", t, MATS["Ash_Timber"])
    obj("Ash_Shrine_Pilgrim", "Roof", rf, MATS["Ash_Roof"])
    obj("Ash_Shrine_Pilgrim", "Bronze", b, MATS["Ash_Bronze"])
    obj("Ash_Shrine_Pilgrim", "Glow", g, MATS["Ash_Glow"])


def prayer_flags():
    rr = random.Random(2951)
    st, t, rp, fl = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    L, zt, sag = 26.0, 14.0, 2.6
    zr = lambda x: zt - sag * (1 - (2 * x / L) ** 2)
    for sx in (-1, 1):
        bx(st, sx * L / 2, 0, -1.0, 3.6, 3.6, 1.8, bev=0.2)  # cairn footing
        bx(st, sx * L / 2 + sx * 0.4, 0.4, 0.8, 2.4, 2.4, 1.0, rz=0.4, bev=0.15)
        cyl(t, sx * L / 2, 0, 0.8, 0.6, 0.4, zt + 1.4, seg=8, uvs=4.0)
        bx(t, sx * L / 2, 0, zt + 2.0, 1.8, 0.5, 0.4, mode="timber", bev=0.04, uvs=4.0)
    rope(rp, [Vector((x, 0, zr(x))) for x in np.linspace(-L / 2, L / 2, 14)], 0.16)
    nf, fw, fh = 14, 1.5, 1.9
    uvl = _uvl(fl)
    for i in range(nf):
        xc = -L / 2 + 1.4 + (L - 2.8) * i / (nf - 1)
        ph, cell = rr.uniform(0, TAU), i % 5
        u0, u1 = (cell + 0.12) / 5, (cell + 0.88) / 5
        for side in (1, -1):
            gv = [[fl.verts.new(Vector((xc - fw / 2 + fw * ix / 3, 0.55 * math.sin(xc * 0.9 + ph + iy) * (iy / 2) + 0.04 * side,
                                        zr(xc - fw / 2 + fw * ix / 3) - 0.15 - fh * iy / 2 - 0.25 * math.sin(ix + ph) * (iy / 2)))) for iy in range(3)] for ix in range(4)]
            for ix in range(3):
                for iy in range(2):
                    q = [gv[ix][iy], gv[ix + 1][iy], gv[ix + 1][iy + 1], gv[ix][iy + 1]]
                    f = fl.faces.new(q if side == 1 else q[::-1])
                    uvs = [(u0 + (u1 - u0) * a / 3, 0.1 + 0.8 * (1 - b_ / 2)) for a, b_ in ((ix, iy), (ix + 1, iy), (ix + 1, iy + 1), (ix, iy + 1))]
                    for l, uv in zip(f.loops, uvs if side == 1 else uvs[::-1]):
                        l[uvl].uv = uv
    obj("Ash_Prayer_Flags", "Stone", st, MATS["Ash_Stone"])
    obj("Ash_Prayer_Flags", "Poles", t, MATS["Ash_Timber"])
    obj("Ash_Prayer_Flags", "Rope", rp, MATS["Ash_Rope"], smooth=True)
    obj("Ash_Prayer_Flags", "Flags", fl, MATS["Ash_Flag"], recalc=False)


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
    obj("Ash_Lantern_Stone", "Stone", s, MATS["Ash_Stone"])
    obj("Ash_Lantern_Stone", "Bronze", b, MATS["Ash_Bronze"])
    obj("Ash_Lantern_Stone", "Glow", g, MATS["Ash_Glow"])


# ------------------------------------------------------------------------------------------ pavilion, gate
def pavilion():
    """Open rest pavilion for pilgrims: stone platform + front steps, six vermilion posts, low stone bench along the back, hipped basalt-tile roof."""
    rr = random.Random(2961)
    s, t, rf, b = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    bx(s, 0, 0, -1.0, 24.0, 24.0, 2.4, bev=0.22)
    bx(s, 0, 0, 1.4, 21.0, 21.0, 1.6, bev=0.18)
    for k in range(3):
        bx(s, 0, -12.0 - (2 - k) * 1.3, -1.0, 8.0, 1.3, 0.8 * (k + 1) + 0.6, bev=0.1)
    P, zt = 7.0, 11.2
    for px, py in ((-P, -P), (0, -P), (P, -P), (-P, P), (0, P), (P, P)):
        bx(s, px, py, 3.0, 2.6, 2.6, 0.7, bev=0.12)
        cyl(t, px, py, 3.6, 0.95, 0.8, zt - 3.6, seg=10)
        for i in range(2):
            bx(t, px, py, zt - 0.2 + i * 0.8, 2.6 + 1.0 * i, 2.6 + 1.0 * i, 0.7, mode="timber", bev=0.06, uvs=4.0)
    for sy in (-P, P):
        bx(t, 0, sy, zt + 1.4, 2 * P + 3.0, 1.2, 1.0, mode="timber", bev=0.06, uvs=4.0)
    for sx in (-P, P):
        bx(t, sx, 0, zt + 1.4, 1.2, 2 * P + 3.0, 1.0, mode="timber", bev=0.06, uvs=4.0)
    bx(t, 0, 0, 8.0, 2 * P, 0.7, 0.7, mode="timber", bev=0.05, uvs=4.0)  # tie beam
    bx(s, 0, P - 1.6, 3.0, 2 * P - 3.0, 1.4, 1.5, bev=0.1)  # bench along the back
    R = dict(hw=12.5, z0=zt + 2.4, h=5.5, flat=0.2, p=1.6, curl=2.6, thick=1.3)
    roof(rf, R, n=16)
    tails(t, R, 13, 0.6)
    horns(b, R, 0.55)
    finial(b, R["z0"] + R["h"] - 0.3, 0.38)
    obj("Ash_Rest_Pavilion", "Stone", s, MATS["Ash_Stone"])
    obj("Ash_Rest_Pavilion", "Timber", t, MATS["Ash_Timber"])
    obj("Ash_Rest_Pavilion", "Roof", rf, MATS["Ash_Roof"])
    obj("Ash_Rest_Pavilion", "Bronze", b, MATS["Ash_Bronze"])


def gate_broken():
    """A pass gate that lost its right pier and lintel: left pier standing, right pier snapped at half height, the lintel slumped between them."""
    rr = random.Random(2971)
    s, t = bmesh.new(), bmesh.new()
    bx(s, -8.5, 0, -1.0, 5.4, 5.4, 2.2, bev=0.2)
    bx(s, 8.5, 0, -1.0, 5.4, 5.4, 2.2, bev=0.2)
    for sx, top in ((-1, 14.0), (1, 7.6)):
        z = 1.2
        while z < top - 0.4:
            h = min(rr.uniform(2.2, 3.0), top - z)
            last = z + h >= top - 0.05
            bx(s, sx * 8.5 + rr.uniform(-0.08, 0.08), rr.uniform(-0.08, 0.08), z, 4.0, 4.0, h, bev=0.12, rz=rr.uniform(-0.03, 0.03), jag=1.1 if (sx == 1 and last) else 0.0)
            z += h
    bx(s, -8.5, 0, 14.0, 5.6, 5.2, 1.2, bev=0.14)  # cap of the standing pier
    bx(s, -8.5, 0, 15.2, 4.2, 4.2, 0.8, bev=0.1)
    beam(t, (-8.5, 0, 16.4), (7.4, 0, 8.8), 2.6, 1.8)  # lintel, one end on the standing cap, the other dropped onto the broken pier
    beam(t, (-8.5, 0.0, 10.2), (-1.2, 0.0, 10.2), 1.0, 1.0)  # tie beam stub
    beam(t, (2.0, -3.4, 0.7), (11.5, -2.4, 1.1), 1.6, 1.4)  # a fallen timber on the ground
    for _ in range(14):  # fallen blocks
        x, y = rr.uniform(3.5, 13.0), rr.uniform(-5.5, 5.0)
        bx(s, x, y, -0.4 + rr.uniform(0, 0.6), rr.uniform(1.6, 3.2), rr.uniform(1.4, 2.4), rr.uniform(1.0, 1.8), rz=rr.uniform(0, 3.14), bev=0.14, jag=0.2)
    obj("Ash_Gate_Broken", "Stone", s, MATS["Ash_Stone"])
    obj("Ash_Gate_Broken", "Timber", t, MATS["Ash_Timber"])


BUILD = [
    ("Ash_Stair_Run_Straight", lambda: stair_run("Ash_Stair_Run_Straight", 14, 11.0, 2901)),
    ("Ash_Stair_Run_Long", lambda: stair_run("Ash_Stair_Run_Long", 28, 7.4, 2902, 0.1)),
    ("Ash_Stair_Run_Turn", stair_turn),
    ("Ash_Retaining_Wall_A", lambda: retaining("Ash_Retaining_Wall_A", 2911, 18.0, 10.0)),
    ("Ash_Retaining_Wall_B", lambda: retaining("Ash_Retaining_Wall_B", 2912, 16.0, 9.0, corner=True, broken=True)),
    ("Ash_Shrine_Pilgrim", shrine), ("Ash_Prayer_Flags", prayer_flags), ("Ash_Lantern_Stone", lantern_stone),
    ("Ash_Rest_Pavilion", pavilion), ("Ash_Gate_Broken", gate_broken),
]

prep()
built_mats()
run_family(BUILD)

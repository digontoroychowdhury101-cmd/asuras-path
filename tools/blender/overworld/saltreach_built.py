"""Saltreach built family (lane M5): salt pans, boardwalks, piers, net rack, boat hulls, fisher huts, stone lantern, gate pieces.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b --python tools/blender/overworld/saltreach_built.py     (env SALT_ONLY=A,B subset, SALT_NORENDER=1)

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Supersedes: nothing (no earlier saltreach built script; searched first). Linked from LEDGER.md: not yet (outside this lane's write set; integrator adds the row for workers/23b-salt-kit.md).
Why new: the built-structure family run of the Saltreach kit; writes only assets/source/overworld/saltreach/built/ + family_built.json (pack merge via saltreach_lib).
"""
from pathlib import Path

exec(compile((Path(__file__).resolve().parent / "saltreach_lib.py").read_text(encoding="utf-8"), "saltreach_lib.py", "exec"))

T, S, I, R, C, G, K, V = "Salt_Timber", "Salt_Stone", "Salt_Iron", "Salt_Rope", "Salt_Crust", "Salt_Glow", "Salt_Canvas", "Salt_Driftwood"


def plate(bm, x, y, z0, sx, sy, sz, rz=0.0, tx=0.0, ty=0.0, mode="timber", bev=0.06, uvs=4.0):
    before = set(bm.verts)
    bx(bm, x, y, z0, sx, sy, sz, rz=rz, mode=mode, bev=bev, uvs=uvs)
    pivot = Vector((x, y, z0 + sz / 2))
    M = Matrix.Rotation(tx, 3, "X") @ Matrix.Rotation(ty, 3, "Y")
    for v in set(bm.verts) - before:
        v.co = M @ (v.co - pivot) + pivot


def post(bm, x, y, z0, h, r=0.5, seg=8):
    cyl(bm, x, y, z0, r, r * 0.88, h, seg=seg, uvs=4.0)


def rope(bm, pts, r=0.12):
    tube(bm, pts, [r] * len(pts), sides=4, uvs=2.0)


def sag(p0, p1, drop, n=4):
    return [p0.lerp(p1, k / n) - Vector((0, 0, drop * 4 * (k / n) * (1 - k / n))) for k in range(n + 1)]


# ------------------------------------------------------------------------------------------ salt pans
def salt_pan_frame():
    t, c, s = bmesh.new(), bmesh.new(), bmesh.new()
    W, D = 26.0, 16.0
    for sy in (-1, 1):
        bx(t, 0, sy * D / 2, 0, W + 1.2, 1.0, 1.1, mode="timber", bev=0.08, uvs=4.0)
    for sx in (-1, 1):
        bx(t, sx * W / 2, 0, 0, 1.0, D, 1.1, mode="timber", bev=0.08, uvs=4.0)
    for i in range(6):
        for sy in (-1, 1):
            post(t, -W / 2 + i * W / 5, sy * D / 2, -1.5, 3.6, 0.42)
    for x in (-W / 6, W / 6):
        blk(s, x, 0, 0, 0.9, D - 1.0, 0.8, bev=0.1, disp=0.04, mode="stone")
    blk(s, 0, 0, 0, W - 1.0, 0.8, 0.8, bev=0.1, disp=0.04)
    for cx in (-W / 3, 0, W / 3):
        for cy in (-D / 4, D / 4):
            bx(c, cx, cy, 0.05, W / 3 - 1.6, D / 2 - 1.5, 0.5, bev=0.18, uvs=8.0)
    tube(t, [Vector((-10.5, -6.5, 0.5)), Vector((-8.2, -4.4, 3.8)), Vector((-6.2, -2.6, 7.4))], [0.2, 0.18, 0.15], sides=5, uvs=2.0)  # leaning rake
    plate(t, -10.9, -6.9, 0.2, 3.6, 0.35, 0.9, 0.7, bev=0.04)
    done("Salt_Pan_Frame", [("Timber", t, T, False), ("Bund", s, S, False), ("Crust", c, C, False)])


def salt_pan_channel():
    t, c, s = bmesh.new(), bmesh.new(), bmesh.new()
    rr = random.Random(611)
    L, Wc = 32.0, 7.0
    for sy in (-1, 1):
        for row in range(2):
            x = -L / 2
            while x < L / 2 - 0.5:
                w = min(rr.uniform(2.6, 4.2), L / 2 - x)
                blk(s, x + w / 2, sy * (Wc / 2 + 0.9), row * 1.4 - 0.3, w - 0.08, 1.8, 1.45, bev=0.12, disp=0.06)
                x += w
    bx(c, 0, 0, -0.3, L, Wc, 0.4, bev=0.12, uvs=8.0)
    for sy in (-1, 1):
        post(t, 0, sy * (Wc / 2 - 0.3), -0.5, 8.0, 0.55)
        for k in range(3):
            plate(t, 0, sy * (Wc / 2 - 0.3), 0.8 + k * 1.1, 1.2, 0.5, 0.9, mode="timber")
    bx(t, 0, 0, 7.4, 0.9, Wc + 1.4, 0.8, mode="timber", bev=0.06)
    for k in range(3):  # sluice boards in the slot
        bx(t, 0.4, 0, 0.1 + k * 1.15, 0.4, Wc - 1.2, 1.05, mode="timber", bev=0.04, uvs=4.0)
    for i in range(6):  # footbridge planks across the channel
        bx(t, -2.5 + i * 1.0, 0, 3.2, 0.85, Wc + 5.0, 0.35, mode="timber", bev=0.04, uvs=4.0)
    done("Salt_Pan_Channel", [("Stone", s, S, False), ("Timber", t, T, False), ("Crust", c, C, False)])


# ------------------------------------------------------------------------------------------ boardwalk, pier
def boardwalk_straight():
    t, rp = bmesh.new(), bmesh.new()
    L, W, H = 16.0, 5.0, 2.2
    for sy in (-1, 1):
        bx(t, 0, sy * 1.7, H - 0.6, L, 0.5, 0.6, mode="timber", bev=0.05, uvs=4.0)
    for i in range(int(L)):
        bx(t, -L / 2 + 0.5 + i, 0, H, 0.88, W, 0.35, mode="timber", bev=0.04, uvs=4.0)
    xs = [-L / 2 + 1 + 4 * k for k in range(4)] + [L / 2 - 1]
    xs = sorted(set(xs))
    for x in xs:
        for sy in (-1, 1):
            post(t, x, sy * 2.2, -2.5, 7.0, 0.5)
    for sy in (-1, 1):
        for a, b in zip(xs, xs[1:]):
            rope(rp, sag(Vector((a, sy * 2.2, 4.2)), Vector((b, sy * 2.2, 4.2)), 0.35))
    done("Boardwalk_Straight", [("Timber", t, T, False), ("Rope", rp, R, True)])


def boardwalk_steps():
    t, rp = bmesh.new(), bmesh.new()
    n, run, rise, W = 6, 1.7, 0.85, 5.0
    for k in range(n):
        x = k * run
        bx(t, x, 0, (k + 1) * rise - 0.35, run + 0.1, W, 0.35, mode="timber", bev=0.04, uvs=4.0)
        bx(t, x - run / 2 + 0.2, 0, k * rise, 0.3, W - 0.3, rise, mode="timber", bev=0.03, uvs=4.0)
    ang = math.atan2(n * rise, n * run)
    for sy in (-1, 1):
        plate(t, (n - 1) * run / 2, sy * 2.0, 0.6, math.hypot(n * run, n * rise) + 1.0, 0.45, 0.7, 0.0, 0.0, -ang)
        for k in (0, 3, 5):
            post(t, k * run, sy * 2.35, -1.2, (k + 1) * rise + 4.2, 0.4)
        rope(rp, sag(Vector((0, sy * 2.35, 4.3)), Vector((5 * run, sy * 2.35, 5 * rise + 4.5)), 0.3, 5))
    done("Boardwalk_Steps", [("Timber", t, T, False), ("Rope", rp, R, True)])


def pier_section():
    t, rp = bmesh.new(), bmesh.new()
    L, W, H = 22.0, 8.0, 5.0
    xs = [-L / 2 + 2.0 + 5.5 * k for k in range(4)]
    for y in (-W / 2 + 0.8, 0, W / 2 - 0.8):
        bx(t, 0, y, H - 0.7, L, 0.6, 0.7, mode="timber", bev=0.05, uvs=4.0)
    for i in range(int(L)):
        bx(t, -L / 2 + 0.5 + i, 0, H, 0.9, W, 0.4, mode="timber", bev=0.04, uvs=4.0)
    for x in xs:
        for sy in (-1, 1):
            post(t, x, sy * (W / 2 - 0.5), -4.0, 12.0, 0.8, seg=9)
        bx(t, x, 0, H - 1.2, 0.7, W, 0.5, mode="timber", bev=0.05, uvs=4.0)
    for a, b in zip(xs, xs[1:]):
        for sy in (-1, 1):
            tube(t, [Vector((a, sy * (W / 2 - 0.5), -1.0)), Vector((b, sy * (W / 2 - 0.5), H - 1.2))], [0.28, 0.28], sides=5, uvs=4.0)
    for sy in (-1, 1):
        bx(t, 0, sy * (W / 2 - 0.3), H + 2.0, L, 0.35, 0.35, mode="timber", bev=0.04, uvs=4.0)
        bx(t, 0, sy * (W / 2 - 0.3), H + 3.0, L, 0.35, 0.35, mode="timber", bev=0.04, uvs=4.0)
        for x in xs:
            post(t, x, sy * (W / 2 - 0.3), H, 3.6, 0.3, seg=6)
    done("Pier_Section", [("Timber", t, T, False)])


def pier_end():
    t, rp, iron, gl = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    L, W, H = 12.0, 8.0, 5.0
    xs = [-L / 2 + 1.5, 0.0, L / 2 - 1.0]
    for y in (-W / 2 + 0.8, 0, W / 2 - 0.8):
        bx(t, 0, y, H - 0.7, L, 0.6, 0.7, mode="timber", bev=0.05, uvs=4.0)
    for i in range(int(L)):
        bx(t, -L / 2 + 0.5 + i, 0, H, 0.9, W, 0.4, mode="timber", bev=0.04, uvs=4.0)
    for x in xs:
        for sy in (-1, 1):
            post(t, x, sy * (W / 2 - 0.5), -4.0, 12.0, 0.8, seg=9)
    for sy in (-1, 1):  # bollards
        cyl(iron, L / 2 - 1.2, sy * 2.6, H + 0.4, 0.7, 0.55, 1.6, seg=8, uvs=2.0)
        cyl(iron, L / 2 - 1.2, sy * 2.6, H + 2.0, 0.95, 0.95, 0.35, seg=8, uvs=2.0)
    post(t, -L / 2 + 1.0, W / 2 - 0.6, H, 9.0, 0.35)  # lantern post with glow box
    bx(gl, -L / 2 + 1.0, W / 2 - 0.6, H + 8.0, 1.5, 1.5, 1.7, bev=0.15, uvs=2.0)
    bx(iron, -L / 2 + 1.0, W / 2 - 0.6, H + 9.7, 2.2, 2.2, 0.3, bev=0.05, uvs=2.0)
    for r_ in (-1, 1):  # ladder over the end
        tube(t, [Vector((L / 2 - 0.4, r_ * 0.9, H + 0.6)), Vector((L / 2 - 0.4, r_ * 0.9, H - 7.0))], [0.18, 0.18], sides=5, uvs=2.0)
    for k in range(7):
        tube(t, [Vector((L / 2 - 0.4, -0.9, H - 0.6 - k * 1.0)), Vector((L / 2 - 0.4, 0.9, H - 0.6 - k * 1.0))], [0.12, 0.12], sides=4, uvs=2.0)
    for (x, y, sx, sy_, sz) in ((-2.0, -2.6, 2.6, 2.2, 2.0), (-2.4, 0.2, 2.2, 2.0, 1.6), (-0.6, -2.4, 1.8, 1.8, 1.5)):  # crates
        bx(t, x, y, H + 0.4, sx, sy_, sz, mode="timber", bev=0.08, uvs=4.0)
    pts = [Vector((math.cos(a) * 1.5 + 1.0, math.sin(a) * 1.5 + 0.6, H + 0.5 + a * 0.08)) for a in np.linspace(0, 4 * math.pi, 22)]
    rope(rp, pts, 0.18)
    done("Pier_End", [("Timber", t, T, False), ("Rope", rp, R, True), ("Iron", iron, I, False), ("Lantern", gl, G, False)])


def net_rack():
    t, rp = bmesh.new(), bmesh.new()
    rr = random.Random(631)
    for sx in (-9.5, 9.5):
        for sy in (-1, 1):
            tube(t, [Vector((sx, sy * 2.2, -0.6)), Vector((sx, 0, 11.0))], [0.55, 0.45], sides=6, uvs=4.0)
        tube(t, [Vector((sx, -2.0, 3.0)), Vector((sx, 2.0, 3.0))], [0.25, 0.25], sides=5, uvs=4.0)
    tube(t, [Vector((-11.5, 0, 10.4)), Vector((11.5, 0, 10.4))], [0.5, 0.5], sides=7, uvs=4.0)
    for i in range(21):
        x = -9.0 + i * 0.9
        bot = 3.2 + rr.uniform(0, 1.6)
        rope(rp, [Vector((x, 0.1, 10.0)), Vector((x + 0.15, 0.2, (10.0 + bot) / 2)), Vector((x, 0.1, bot))], 0.07)
    for k, z in enumerate((9.0, 7.6, 6.2, 4.8)):
        rope(rp, sag(Vector((-9.0, 0.1, z)), Vector((9.0, 0.1, z - 0.4)), 0.3, 8), 0.07)
    pts = [Vector((math.cos(a) * (2.2 - a * 0.1) + 6.0, math.sin(a) * (1.5 - a * 0.06) + 3.2, 0.3 + 0.25 * (a / 6.28))) for a in np.linspace(0, 12.5, 40)]
    rope(rp, pts, 0.3)  # net heap
    done("Net_Rack", [("Timber", t, T, False), ("Net", rp, R, True)])


# ------------------------------------------------------------------------------------------ boat hulls
def hull_pt(L, B, g0, g1, t, u, inner=False):
    w = B * math.sin(math.pi * (0.02 + 0.96 * t)) ** 0.65 / 2
    g = g0 + (g1 - g0) * (2 * t - 1) ** 2
    ph = u * math.pi / 2
    rock = 1.1 * (2 * t - 1) ** 4
    if inner:
        y = (w - 0.45) * math.sin(ph) if w > 0.5 else w * math.sin(ph) * 0.5
        z = 0.5 + (g - 0.55) * (1 - math.cos(ph)) + rock
    else:
        y = w * math.sin(ph) + (0.1 * ((abs(u) * 6) % 1.0) * (1 if u > 0 else -1))
        z = g * (1 - math.cos(ph)) + rock
    return Vector((-L / 2 + L * t, y, z))


def hull_shell(bm, L, B, g0, g1, nt, ns, inner=False, keep=None):
    uvl = _uvl(bm)
    grid = [[bm.verts.new(hull_pt(L, B, g0, g1, i / nt, -1 + 2 * j / ns, inner)) for j in range(ns + 1)] for i in range(nt + 1)]
    for i in range(nt):
        for j in range(ns):
            u = -1 + 2 * (j + 0.5) / ns
            if keep and not keep(i / nt, u):
                continue
            f = bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
            for l, (a, b) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                l[uvl].uv = (a / nt * L / 8.0, abs(-1 + 2 * b / ns) * B / 5.0 + (0.5 if b > ns / 2 else 0))
    bm.normal_update()
    zmid = (g0 + g1) / 2
    for f in bm.faces:
        c = f.calc_center_median()
        o = Vector((0, c.y, c.z - zmid * 0.6))
        if (f.normal.dot(o) < 0) != inner:
            f.normal_flip()
    return grid


def hull_rib(bm, L, B, g0, g1, t, r=0.24):
    pts = [hull_pt(L, B, g0, g1, t, -1 + 2 * j / 8, True) * 1.0 for j in range(9)]
    pts = [Vector((p.x, p.y * 1.02, p.z)) for p in pts]
    tube(bm, pts, [r] * 9, sides=4, uvs=4.0)


def boat_hull_a():
    L, B, g0, g1 = 24.0, 7.0, 3.0, 5.4
    h, rb, cv = bmesh.new(), bmesh.new(), bmesh.new()
    hull_shell(h, L, B, g0, g1, 24, 14)
    hull_shell(h, L, B, g0, g1, 24, 14, inner=True)
    for i in range(24):  # gunwale strip
        a, b = hull_pt(L, B, g0, g1, i / 24, -1), hull_pt(L, B, g0, g1, (i + 1) / 24, -1)
        for sg in (1, -1):
            pa, pb = Vector((a.x, sg * a.y, a.z)), Vector((b.x, sg * b.y, b.z))
            q = [h.verts.new(pa), h.verts.new(pb), h.verts.new(Vector((pb.x, pb.y - sg * 0.45, pb.z + 0.1))), h.verts.new(Vector((pa.x, pa.y - sg * 0.45, pa.z + 0.1)))]
            if sg < 0:
                q = q[::-1]
            f = h.faces.new(q)
            for l in f.loops:
                l[_uvl(h)].uv = (l.vert.co.x / 8.0, 0.3)
    for k in range(10):
        hull_rib(rb, L, B, g0, g1, 0.1 + 0.08 * k)
    for x in (-5.5, -0.5, 4.5):
        w = B * math.sin(math.pi * (0.02 + 0.96 * (x / L + 0.5))) ** 0.65 / 2
        bx(rb, x, 0, 2.6 + 0.0 * x, 1.1, 2 * w - 0.6, 0.35, mode="timber", bev=0.04, uvs=4.0)
    bx(rb, 0, 0, 0.0, L - 3.0, 0.7, 0.9, mode="timber", bev=0.05, uvs=4.0)  # keel
    tube(rb, [Vector((-L / 2 - 0.1, 0, 0.8 + 1.1)), Vector((-L / 2 - 0.4, 0, g1 + 1.1)), Vector((-L / 2 - 0.1, 0, g1 + 1.8))], [0.35, 0.3, 0.2], sides=5, uvs=4.0)
    tube(rb, [Vector((-2.0, 1.2, 3.0)), Vector((6.0, 2.0, 6.4))], [0.16, 0.14], sides=5, uvs=4.0)  # oar shaft
    plate(rb, 6.6, 2.1, 6.3, 2.2, 0.45, 0.14, 0.2, 0.0, -0.5)
    uvl = _uvl(cv)  # canvas draped over the stern half
    nt, ns = 8, 10
    gr = []
    for i in range(nt + 1):
        t_ = 0.58 + 0.34 * i / nt
        row = []
        for j in range(ns + 1):
            u = -1 + 2 * j / ns
            p = hull_pt(L, B, g0, g1, t_, u)
            gtop = g0 + (g1 - g0) * (2 * t_ - 1) ** 2
            row.append(cv.verts.new(Vector((p.x, p.y * 1.12, gtop + 0.35 + 1.5 * math.cos(u * math.pi / 2) ** 1.3 - abs(u) * 0.2 + 0.2 * math.sin(i * 1.9 + j)))))
        gr.append(row)
    for i in range(nt):
        for j in range(ns):
            f = cv.faces.new((gr[i][j], gr[i + 1][j], gr[i + 1][j + 1], gr[i][j + 1]))
            for l, (a, b) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                l[uvl].uv = (a / nt, b / ns)
    done("Boat_Hull_A", [("Hull", h, T, True), ("Ribs", rb, T, False), ("Canvas", cv, K, True)])


def boat_hull_b():
    L, B, g0, g1 = 21.0, 6.6, 2.8, 4.8
    rr = random.Random(641)
    h, rb = bmesh.new(), bmesh.new()

    def keep(t, u):
        if t > 0.62 and abs(u) > 0.35:
            return False
        return not ((int(t * 24) * 7 + int((u + 1) * 7) * 3) % 6 == 0 and abs(u) > 0.25)

    hull_shell(h, L, B, g0, g1, 24, 14, keep=keep)
    hull_shell(h, L, B, g0, g1, 24, 14, inner=True, keep=keep)
    for k in range(13):
        hull_rib(rb, L, B, g0, g1, 0.06 + 0.075 * k, 0.28)
    bx(rb, 0, 0, 0.0, L - 2.0, 0.8, 1.0, mode="timber", bev=0.05, uvs=4.0)
    for _ in range(6):  # splintered plank ends
        t_, u = rr.uniform(0.62, 0.9), rr.choice((-1, 1)) * rr.uniform(0.4, 0.9)
        p = hull_pt(L, B, g0, g1, t_, u)
        tube(rb, [p, p + Vector((0.3, 0, 1.0)), p + Vector((0.5, rr.uniform(-.3, .3), 1.9))], [0.35, 0.25, 0.04], sides=4, uvs=2.0)
    M = Matrix.Rotation(0.32, 3, "X")
    for bm in (h, rb):
        for v in bm.verts:
            v.co = M @ v.co + Vector((0, 0, 0.4))
            v.co.z = max(v.co.z, -1.2)
    done("Boat_Hull_B", [("Hull", h, T, True), ("Ribs", rb, T, False)])


# ------------------------------------------------------------------------------------------ fisher huts
def board_wall(bm, p0, p1, z0, h, gaps, gable=0.0, step=0.95):
    """Vertical board wall from p0 to p1; gaps = [(s0, s1, zlo, zhi)] leave openings (sill/lintel boards remain); gable = extra apex height."""
    d = p1 - p0
    Lw, ang = d.length, math.atan2(d.y, d.x)
    d.normalize()
    n = int(Lw / step + 0.5)
    st = Lw / n
    for k in range(n):
        s = (k + 0.5) * st
        c = p0 + d * s
        top = h + (gable * (1 - abs(s - Lw / 2) / (Lw / 2)) if gable else 0.0)
        gp = next(((g[2], g[3]) for g in gaps if g[0] <= s <= g[1]), None)
        if gp is None:
            bx(bm, c.x, c.y, z0, st - 0.06, 0.4, top, rz=ang, mode="timber", bev=0.04, uvs=4.0)
        else:
            if gp[0] > 0.1:
                bx(bm, c.x, c.y, z0, st - 0.06, 0.4, gp[0], rz=ang, mode="timber", bev=0.04, uvs=4.0)
            bx(bm, c.x, c.y, z0 + gp[1], st - 0.06, 0.4, top - gp[1], rz=ang, mode="timber", bev=0.04, uvs=4.0)


def gable_roof(bm, L, halfD, z_eave, rise, over=1.6, rows=9):
    a = math.atan2(rise, halfD)
    slope = (halfD + over) / math.cos(a)
    for side in (-1, 1):
        for r_ in range(rows):
            s = (r_ + 0.5) * slope / rows
            plate(bm, 0, side * (halfD + over - s * math.cos(a)), z_eave - over * math.tan(a) + s * math.sin(a) - 0.15, L + 2 * over, slope / rows + 0.35, 0.3, 0.0, -side * a, 0.0,
                  bev=0.05, uvs=4.0)
    bx(bm, 0, 0, z_eave + rise - 0.2, L + 2 * over, 0.9, 0.5, mode="timber", bev=0.06, uvs=4.0)  # ridge cap


def fisher_hut_a():
    t, rf, st = bmesh.new(), bmesh.new(), bmesh.new()
    rr = random.Random(651)
    W, D, H = 14.0, 11.0, 7.5
    for x in np.arange(-W / 2, W / 2, 2.6):  # stone footing
        for sy in (-1, 1):
            blk(st, x + 1.3, sy * D / 2, -0.8, 2.5, 0.9, 1.4, bev=0.1, disp=0.05)
    for sx in (-1, 1):
        for y in np.arange(-D / 2 + 1.3, D / 2 - 1.0, 2.6):
            blk(st, sx * W / 2, y + 1.3, -0.8, 0.9, 2.5, 1.4, bev=0.1, disp=0.05)
    bx(t, 0, 0, 0.5, W, D, 0.4, mode="timber", bev=0.04, uvs=4.0)
    board_wall(t, Vector((-W / 2, -D / 2, 0)), Vector((W / 2, -D / 2, 0)), 0.5, H, [(8.2, 11.4, 0.0, 6.6), (2.0, 4.2, 3.0, 5.4)])
    board_wall(t, Vector((W / 2, D / 2, 0)), Vector((-W / 2, D / 2, 0)), 0.5, H, [(4.2, 6.4, 3.0, 5.4)])
    board_wall(t, Vector((-W / 2, D / 2, 0)), Vector((-W / 2, -D / 2, 0)), 0.5, H, [], gable=4.4)
    board_wall(t, Vector((W / 2, -D / 2, 0)), Vector((W / 2, D / 2, 0)), 0.5, H, [], gable=4.4)
    gable_roof(rf, W, D / 2, H + 0.5, 4.4)
    for (x, y, z, sx, sy, sz) in ((-4.0, -D / 2 - 0.4, 2.8, 2.6, 0.2, 0.4), (-4.0, -D / 2 - 0.4, 5.4, 2.6, 0.2, 0.4)):  # window frames
        bx(t, x, y, z, sx, sy, sz, mode="timber", bev=0.03, uvs=4.0)
    plate(t, 6.6, -D / 2 - 1.3, 0.6, 3.0, 0.3, 6.0, 0.0, 0.0, 0.0)  # door leaf ajar
    t_door = t
    bx(st, W / 2 - 2.0, D / 2 - 2.0, 0.5, 2.6, 2.6, 13.0, bev=0.12, mode="stone")  # chimney
    bx(st, W / 2 - 2.0, D / 2 - 2.0, 13.4, 3.2, 3.2, 0.6, bev=0.1, mode="stone")
    tube(t, [Vector((-7.6, -D / 2 - 0.5, 1.0)), Vector((-7.6, -D / 2 - 0.5, 6.4))], [0.2, 0.2], sides=5, uvs=2.0)  # drying pole
    for k in range(4):
        tube(t, [Vector((-7.6, -D / 2 - 0.5, 6.0 - k * 0.0)), Vector((-4.8 + k * 0.8, -D / 2 - 1.6, 6.2))], [0.08, 0.06], sides=4, uvs=2.0)
    done("Fisher_Hut_A", [("Timber", t, T, False), ("Roof", rf, T, False), ("Stone", st, S, False)])


def fisher_hut_b():
    t, rf, st = bmesh.new(), bmesh.new(), bmesh.new()
    W, D, H, Z = 10.0, 8.0, 6.5, 6.0
    for x in (-W / 2 + 0.6, 0, W / 2 - 0.6):
        for sy in (-1, 1):
            post(t, x, sy * (D / 2 - 0.6), -2.5, Z + 3.0, 0.55, seg=8)
            blk(st, x, sy * (D / 2 - 0.6), -1.0, 1.6, 1.6, 0.9, bev=0.1, disp=0.04)
    for y in (-D / 2 + 0.6, 0, D / 2 - 0.6):
        bx(t, 0, y, Z - 0.7, W + 1.6, 0.6, 0.7, mode="timber", bev=0.04, uvs=4.0)
    for i in range(int((W + 4.0) / 0.95)):
        bx(t, -W / 2 - 2.0 + 0.5 + i * 0.95, 0, Z, 0.9, D + 2.0, 0.35, mode="timber", bev=0.04, uvs=4.0)
    z0 = Z + 0.35
    board_wall(t, Vector((-W / 2, -D / 2, 0)), Vector((W / 2, -D / 2, 0)), z0, H, [(3.2, 6.4, 0.0, 5.4)])
    board_wall(t, Vector((W / 2, D / 2, 0)), Vector((-W / 2, D / 2, 0)), z0, H, [(3.4, 5.4, 2.6, 4.8)])
    board_wall(t, Vector((-W / 2, D / 2, 0)), Vector((-W / 2, -D / 2, 0)), z0, H, [])
    board_wall(t, Vector((W / 2, -D / 2, 0)), Vector((W / 2, D / 2, 0)), z0, H, [(2.5, 5.0, 2.6, 4.8)])
    a = 0.24  # lean-to roof, high at the back
    for r_ in range(9):
        s = (r_ + 0.5) * (D + 3.2) / math.cos(a) / 9
        plate(rf, 0, -D / 2 - 1.6 + s * math.cos(a), z0 + H - 0.4 + s * math.sin(a) - 0.2, W + 3.2, (D + 3.2) / math.cos(a) / 9 + 0.35, 0.3, 0.0, a, 0.0, bev=0.05, uvs=4.0)
    for r_ in (-1, 1):  # ladder at the front
        tube(t, [Vector((W / 2 + 1.6 + r_ * 0.9, -D / 2 - 1.2, Z + 0.5)), Vector((W / 2 + 3.4 + r_ * 0.9, -D / 2 - 3.4, -1.0))], [0.2, 0.2], sides=5, uvs=2.0)
    for k in range(8):
        f_ = k / 7
        p0 = Vector((W / 2 + 1.6 - 0.9, -D / 2 - 1.2, Z + 0.5)).lerp(Vector((W / 2 + 3.4 - 0.9, -D / 2 - 3.4, -1.0)), f_)
        tube(t, [p0, p0 + Vector((1.8, 0, 0))], [0.12, 0.12], sides=4, uvs=2.0)
    done("Fisher_Hut_B", [("Timber", t, T, False), ("Roof", rf, T, False), ("Stone", st, S, False)])


# ------------------------------------------------------------------------------------------ lantern, gate
def stone_lantern():
    s, g, ir = bmesh.new(), bmesh.new(), bmesh.new()
    blk(s, 0, 0, -0.6, 5.4, 5.4, 1.6, bev=0.2, disp=0.05)
    cyl(s, 0, 0, 1.0, 2.3, 1.9, 1.0, seg=6, uvs=4.0)
    cyl(s, 0, 0, 2.0, 0.95, 0.85, 4.2, seg=8, uvs=4.0)
    cyl(s, 0, 0, 6.2, 2.5, 2.3, 0.7, seg=6, uvs=4.0)
    for k in range(6):
        a = k * TAU / 6 + 0.52
        cyl(s, math.cos(a) * 1.55, math.sin(a) * 1.55, 6.9, 0.32, 0.3, 3.0, seg=5, uvs=2.0)
    cyl(g, 0, 0, 7.1, 1.25, 1.25, 2.6, seg=8, uvs=2.0)
    cyl(s, 0, 0, 9.9, 3.5, 0.9, 1.9, seg=6, uvs=4.0)
    cyl(s, 0, 0, 11.7, 0.5, 0.35, 0.8, seg=6, uvs=2.0)
    vs = bmesh.ops.create_icosphere(s, subdivisions=2, radius=0.55)["verts"]
    for v in vs:
        v.co += Vector((0, 0, 12.7))
    cyl(ir, 0, 0, 6.9, 1.9, 1.9, 0.14, seg=8, uvs=2.0)
    done("Stone_Lantern_Salt", [("Stone", s, S, False), ("Glow", g, G, False), ("Iron", ir, I, False)])


def pier_stone(bm, x, y, h, w=7.2, rr=None):
    rr = rr or random.Random(661)
    z = -1.0
    k = 0
    while z < h:
        ch = rr.uniform(1.7, 2.2)
        for sgn in (-1, 1):
            if k % 2:
                blk(bm, x + sgn * w / 4, y, z, w / 2 - 0.08, w, ch - 0.06, bev=0.14, disp=0.07)
            else:
                blk(bm, x, y + sgn * w / 4, z, w, w / 2 - 0.08, ch - 0.06, bev=0.14, disp=0.07)
        z += ch
        k += 1
    blk(bm, x, y, z, w + 1.6, w + 1.6, 1.3, bev=0.2, disp=0.05)  # cap
    return z + 1.3


def gate_pier():
    s, t, ir = bmesh.new(), bmesh.new(), bmesh.new()
    top = pier_stone(s, 0, 0, 22.0)
    for z in (6.0, 13.0):  # iron bands
        bx(ir, 0, 0, z, 8.0, 8.0, 0.5, bev=0.06, uvs=2.0)
    bx(t, 4.6, 0, 17.0, 3.4, 0.5, 0.5, mode="timber", bev=0.05, uvs=2.0)  # lantern bracket
    tube(ir, [Vector((5.6, 0, 16.9)), Vector((5.6, 0, 14.6))], [0.1, 0.1], sides=4, uvs=2.0)
    bx(ir, 5.6, 0, 12.9, 1.4, 1.4, 1.7, bev=0.15, uvs=2.0)
    done("Gate_Pier", [("Stone", s, S, False), ("Timber", t, T, False), ("Iron", ir, I, False)])


def gate_arch():
    s, t, ir = bmesh.new(), bmesh.new(), bmesh.new()
    rr = random.Random(671)
    for sx in (-14.0, 14.0):
        top = pier_stone(s, sx, 0, 21.0, rr=rr)
        for z in (5.5, 12.0):
            bx(ir, sx, 0, z, 8.0, 8.0, 0.5, bev=0.06, uvs=2.0)
    bx(t, 0, 0, top - 0.2, 34.0, 2.4, 2.2, mode="timber", bev=0.1, uvs=4.0)  # lintel
    bx(t, 0, 0, top + 2.0, 26.0, 1.8, 1.5, mode="timber", bev=0.08, uvs=4.0)
    for sx in (-1, 1):
        tube(t, [Vector((sx * 10.4, 0, top - 0.2)), Vector((sx * 5.0, 0, top + 2.4))], [0.5, 0.45], sides=6, uvs=4.0)
    for k in range(5):  # net floats and rope
        x = -9 + k * 4.5
        tube(ir, [Vector((x, 0, top - 0.2)), Vector((x, 0, top - 3.0 - (k % 2)))], [0.07, 0.07], sides=4, uvs=2.0)
        bx(ir, x, 0, top - 4.6 - (k % 2), 0.9, 0.9, 1.5, bev=0.1, uvs=2.0)
    done("Gate_Arch", [("Stone", s, S, False), ("Timber", t, T, False), ("Iron", ir, I, False)], centre=True)


BUILD = [
    ("Salt_Pan_Frame", salt_pan_frame), ("Salt_Pan_Channel", salt_pan_channel), ("Boardwalk_Straight", boardwalk_straight),
    ("Boardwalk_Steps", boardwalk_steps), ("Pier_Section", pier_section), ("Pier_End", pier_end), ("Net_Rack", net_rack),
    ("Boat_Hull_A", boat_hull_a), ("Boat_Hull_B", boat_hull_b), ("Fisher_Hut_A", fisher_hut_a), ("Fisher_Hut_B", fisher_hut_b),
    ("Stone_Lantern_Salt", stone_lantern), ("Gate_Pier", gate_pier), ("Gate_Arch", gate_arch),
]

run("built", BUILD, ["Salt_Timber", "Salt_Stone", "Salt_Crust", "Salt_Iron", "Salt_Rope", "Salt_Canvas", "Salt_Glow"])

"""Saltreach hero family (lane M5): Saltreach_Gate_Statue, the refined tide-warden colossus for the Basin gate slot (70 x 140 x 44 studs).

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b --python tools/blender/overworld/saltreach_hero.py     (env SALT_NORENDER=1)

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Supersedes: the Basin_Gate_Statue blockout (hero_silhouettes.py / assets/source/overworld/hero/) at swap time only; that blockout is not touched. No other earlier file (searched first).
Linked from LEDGER.md: not yet (outside this lane's write set; integrator adds the row for workers/23b-salt-kit.md).
Why new: the hero family run of the Saltreach kit; writes only assets/source/overworld/saltreach/hero/ + family_hero.json (pack merge via saltreach_lib).
Original design: a hooded, salt-eaten robed warden resting both hands on a great rusted anchor, standing on a three-tier stone plinth; front faces Blender -Y (glTF/Roblox +Z).
Sub-meshes: Base, Body, Head, Arms (all Salt_Stone, cylindrical UV on the lofts), Anchor (Salt_Iron), Cords (Salt_Rope).
"""
from pathlib import Path

exec(compile((Path(__file__).resolve().parent / "saltreach_lib.py").read_text(encoding="utf-8"), "saltreach_lib.py", "exec"))

AY = -12.0  # anchor / hand line (in front of the robe)


def loft_body(bm, keys, n=48, nz=56, uvs=22.0, amp=0.5, seed=0, mod=None, cap_top=True):
    """Lofted robe: keys = (zs, rx, ry, cy) piecewise-linear profile; vertical fold ridges + noise; cylindrical UVs (integer tile count round the ring)."""
    uvl = _uvl(bm)
    zs, rxs, rys, cys = keys
    ox = Vector((seed, seed * 0.7, seed * 1.3))
    rings = []
    for z in np.linspace(zs[0], zs[-1], nz):
        rx, ry, cy = (float(np.interp(z, zs, v)) for v in (rxs, rys, cys))
        ring = []
        for k in range(n):
            a = TAU * k / n
            fold = 1 + 0.045 * math.sin(a * 14 + z * 0.04) + 0.03 * math.sin(a * 23 - z * 0.07)
            d = amp * fbm(Vector((math.cos(a) * 3, math.sin(a) * 3, z * 0.05)) + ox, 2)
            m = mod(a, z) if mod else 1.0
            ring.append(bm.verts.new(Vector((math.cos(a) * (rx * fold + d) * m, math.sin(a) * (ry * fold + d) * m + cy, z))))
        rings.append(ring)
    Pn = max(1, round(TAU * (max(rxs) + max(rys)) / 2 / uvs))
    zr = [r[0].co.z for r in rings]
    for i in range(len(rings) - 1):
        for k in range(n):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % n], rings[i + 1][(k + 1) % n], rings[i + 1][k]))
            for l, (kk, zz) in zip(f.loops, ((k, zr[i]), (k + 1, zr[i]), (k + 1, zr[i + 1]), (k, zr[i + 1]))):
                l[uvl].uv = (kk / n * Pn, zz / uvs)
    if cap_top:
        c = bm.verts.new(Vector((0, cys[-1], zs[-1])))
        for k in range(n):
            f = bm.faces.new((c, rings[-1][k], rings[-1][(k + 1) % n]) if False else (c, rings[-1][(k + 1) % n], rings[-1][k]))
            for l in f.loops:
                l[uvl].uv = (l.vert.co.x / uvs, l.vert.co.y / uvs)


def to_atlas(bm, up=0.6):
    """Remap a sculpt's tiling UVs into the Salt_Rock atlas: limestone quadrant, salt-bloom quadrant on up-facing faces (shoulders, hood crown, sleeves).
    Per-face floor keeps each face continuous; the source noise is periodic so tile repeats stay soft."""
    bm.normal_update()
    uvl = _uvl(bm)
    for f in bm.faces:
        qu = 0.5 if f.normal.z > up else 0.0
        us = [l[uvl].uv.x for l in f.loops]
        vs = [l[uvl].uv.y for l in f.loops]
        fu, fv = math.floor(sum(us) / len(us)), math.floor(sum(vs) / len(vs))
        for l in f.loops:
            l[uvl].uv = (qu + 0.02 + 0.46 * (l[uvl].uv.x - fu), 0.02 + 0.46 * (l[uvl].uv.y - fv))


def blob(bm, c, R, seed, sub=3, k=0.2):
    uvl = _uvl(bm)
    ox = Vector((seed, seed * 1.3, seed * 0.7))
    vs = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)["verts"]
    for v in vs:
        u = v.co.copy()
        kk = 1 + k * fbm(u * 2 + ox, 2)
        v.co = Vector((u.x * R[0] * kk, u.y * R[1] * kk, u.z * R[2] * kk)) + Vector(c)
    for f in {f for v in vs for f in v.link_faces}:
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x / 8.0 + 0.3, l.vert.co.z / 8.0 + 0.3)


def statue():
    P = "Saltreach_Gate_Statue"
    base, body, head, arms, anchor, cords = (bmesh.new() for _ in range(6))
    rr = random.Random(990)
    # three-tier plinth, blocks hewn and salt-pitted; front steps broken
    for (w, d, z0, h, nx, ny) in ((70.0, 44.0, -2.0, 8.0, 6, 4), (58.0, 36.0, 6.0, 6.0, 5, 3), (48.0, 30.0, 12.0, 5.0, 4, 3)):
        for i in range(nx):
            for j in range(ny):
                bw, bd = w / nx, d / ny
                blk(base, -w / 2 + bw * (i + 0.5), -d / 2 + bd * (j + 0.5), z0 + rr.uniform(-0.15, 0.1), bw - 0.12, bd - 0.12, h + rr.uniform(-0.2, 0.15), bev=0.45,
                    disp=0.25, cuts=1)
    for k, (w, x) in enumerate(((26.0, 6.0), (20.0, 8.0))):  # broken front steps
        blk(base, x, -20.8 - k * 0.6, -2.0, w, 5.0, 4.0 - k * 1.5, rz=0.03 * (k + 1), bev=0.4, disp=0.2, cuts=1)
    # robe: flared hem, narrow waist, broad shoulders, closed at the neck
    loft_body(body, ([17, 24, 42, 62, 82, 94, 99, 103], [20, 18.5, 15.5, 13.8, 18.5, 23.5, 17.0, 8.0], [14, 13, 10.5, 9.5, 11, 11.5, 9.0, 6.5], [0, 0, 0, -1, -2, -1.5, -1, 0]),
              n=48, nz=60, amp=0.5, seed=3)
    for k in range(14):  # salt-crusted barnacle lumps round the hem
        a = k * TAU / 14 + rr.uniform(-0.1, 0.1)
        blob(body, (math.cos(a) * 19.6, math.sin(a) * 13.6, 19.0 + rr.uniform(0, 4.0)), (rr.uniform(1.2, 2.4),) * 2 + (rr.uniform(1.0, 2.0),), k, sub=2, k=0.3)
    # hood with a recessed face opening
    def hood(a, z):
        front = max(0.0, -math.sin(a) - 0.1) / 0.9
        win = min(1.0, max(0.0, (z - 105) / 2.0)) * min(1.0, max(0.0, (128 - z) / 3.0))
        return 1 - 0.74 * front ** 0.8 * win

    loft_body(head, ([99, 103, 106, 112, 122, 132, 139.5, 140.5], [8, 12.5, 12.8, 13.0, 10.6, 7.0, 3.0, 0.5], [7, 11.5, 12.0, 12.2, 10.2, 7.0, 3.0, 0.5], [0, -0.5, -0.5, -0.3, 0, 0.5, 0.5, 0.5]),
              n=40, nz=44, amp=0.35, seed=7, mod=hood)
    blob(head, (0, -4.8, 114.5), (6.4, 4.6, 8.8), 11, sub=3, k=0.12)  # face
    bx(head, 0, -8.6, 111.4, 2.2, 3.6, 5.0, bev=0.4, mode="stone")  # nose
    bx(head, 0, -7.2, 117.8, 13.0, 3.0, 2.0, bev=0.4, mode="stone")  # brow
    bx(head, 0, -6.4, 108.4, 6.0, 2.4, 1.2, bev=0.4, mode="stone")  # mouth line
    for sx in (-1, 1):  # sunken eyes under the brow
        bx(head, sx * 2.8, -8.0, 115.4, 2.2, 1.0, 0.7, bev=0.1, mode="stone")
    # arms: heavy sleeves from the shoulders down to hands on the anchor shaft
    for sx in (-1, 1):
        pts = [Vector((sx * 20.5, 0, 93)), Vector((sx * 26.0, -5, 80)), Vector((sx * 18.0, -11, 70)), Vector((sx * 5.5, AY, 67 + (1 if sx > 0 else -3)))]
        tube(arms, pts, [6.4, 5.9, 5.2, 4.2], sides=14, uvs=8.0)
        blob(arms, (sx * 3.3, AY, 68.5 if sx > 0 else 64.5), (4.4, 3.8, 4.6), 20 + sx, sub=3, k=0.15)
        for k in range(3):  # sleeve hem lumps
            blob(arms, (sx * (16 - k * 3), -11.5 + k * 0.2, 70 - k * 0.5), (1.5, 1.5, 1.6), 40 + k, sub=2, k=0.3)
    # anchor: shaft, ring, stock, curved flukes (rusted iron)
    cyl(anchor, 0, AY, 17.0, 1.7, 1.5, 75.0, seg=10, uvs=4.0)  # stops at chest height so the carved face stays clear
    ring = [Vector((math.cos(a) * 4.6, AY, 97.0 + 4.6 * math.sin(a))) for a in np.linspace(0, TAU * 1.02, 22)]
    tube(anchor, ring, [0.95] * len(ring), sides=6, uvs=4.0)
    bx(anchor, 0, AY, 83.0, 28.0, 2.2, 2.2, bev=0.3, uvs=4.0)
    for sx in (-1, 1):
        pts = [Vector((sx * 2.0, AY, 19.5)), Vector((sx * 9.0, AY, 18.4)), Vector((sx * 16.0, AY, 22.0)), Vector((sx * 19.0, AY, 29.0))]
        tube(anchor, pts, [1.9, 1.7, 1.5, 1.2], sides=7, uvs=4.0)
        bx(anchor, sx * 19.0, AY, 27.0, 4.2, 1.2, 8.0, bev=0.2, uvs=4.0)
    # cords: net-line mantle hanging from the shoulders
    for sx in (-1, 1):
        for k in range(3):
            x0 = sx * (6 + k * 5)
            tube(cords, [Vector((x0, -8.0, 98 - k * 1.5)), Vector((x0 + sx * 1.5, -12.0, 86 - k * 4)), Vector((x0 + sx * 0.5, -13.0, 72 - k * 5))], [0.55] * 3, sides=5, uvs=2.0)
    for bm in (body, head, arms):
        to_atlas(bm)
    for k, (sub, bm, mat, sm) in enumerate((("Base", base, "Salt_Stone", False), ("Body", body, "Salt_Rock", True), ("Head", head, "Salt_Rock", True),
                                            ("Arms", arms, "Salt_Rock", True), ("Anchor", anchor, "Salt_Iron", True), ("Cords", cords, "Salt_Rope", True))):
        obj(P, sub, bm, MATS[mat], smooth=sm)


_sc, _cam, _ground, _fig = run("hero", [("Saltreach_Gate_Statue", statue)], ["Salt_Stone", "Salt_Rock", "Salt_Iron", "Salt_Rope"])
if not NORENDER and "Saltreach_Gate_Statue" in PIECES:  # head/hands close-up so the carved face and anchor grip can be judged
    _fig.location = (40, -30, 0)
    shoot(_sc, _cam, Vector((0, -95, 100)), Vector((0, 0, 108)), 50, CAPD / "closeup_Saltreach_Gate_Statue.png")

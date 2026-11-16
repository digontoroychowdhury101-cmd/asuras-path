"""Saltreach vegetation family (lane M5): wind-bent pines, salt grass, dune scrub, driftwood, kelp, shore reeds.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b --python tools/blender/overworld/saltreach_veg.py     (env SALT_ONLY=A,B subset, SALT_NORENDER=1)

Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Supersedes: nothing (no earlier saltreach script; searched first). Linked from LEDGER.md: not yet (outside this lane's write set; integrator adds the row for workers/23b-salt-kit.md).
Why new: the vegetation family run of the Saltreach kit; writes only assets/source/overworld/saltreach/veg/ + family_veg.json (pack merge via saltreach_lib).
"""
from pathlib import Path

exec(compile((Path(__file__).resolve().parent / "saltreach_lib.py").read_text(encoding="utf-8"), "saltreach_lib.py", "exec"))

LEE = math.atan2(WIND.y, WIND.x)  # direction the wind streams the crowns toward


def blade(bm, base, bend, hgt, wid, nseg=4, sag=0.12):
    """Tapering single-sided blade strip bending along `bend`; u across, v along (0 base .. 1 tip)."""
    uvl = _uvl(bm)
    side = Vector((-bend.y, bend.x, 0))
    side = side.normalized() if side.length > 1e-5 else Vector((1, 0, 0))
    P = [base + bend * (k / nseg) ** 2 * 1.4 + Vector((0, 0, hgt * k / nseg - sag * hgt * (k / nseg) ** 2)) for k in range(nseg + 1)]
    for k in range(nseg):
        w0, w1 = wid * (1 - k / nseg), wid * (1 - (k + 1) / nseg)
        if k < nseg - 1:
            vs = [bm.verts.new(P[k] - side * w0), bm.verts.new(P[k] + side * w0), bm.verts.new(P[k + 1] + side * w1), bm.verts.new(P[k + 1] - side * w1)]
            uvs = ((0, k / nseg), (1, k / nseg), (1, (k + 1) / nseg), (0, (k + 1) / nseg))
        else:
            vs = [bm.verts.new(P[k] - side * w0), bm.verts.new(P[k] + side * w0), bm.verts.new(P[nseg])]
            uvs = ((0, k / nseg), (1, k / nseg), (0.5, 1))
        f = bm.faces.new(vs)
        for l, uv in zip(f.loops, uvs):
            l[uvl].uv = uv


# ------------------------------------------------------------------------------------------ pines
def needles(det, c, n, L, rr):
    pts = NEEDLE_PTS["Salt_Needle"]
    for _ in range(n):
        a = rr.uniform(0, TAU)
        d = Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, rr.uniform(-0.25, 0.6))) + WIND * 0.7
        leaf(det, c + Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-0.5, 0.5))) * L * 0.25, d, L * rr.uniform(0.8, 1.2), L * 0.2, 0.3,
             rr.choice(pts), kite=True, tex=0.006)


def pine(name, seed, H, amt, nlvl, spread, dead=False, r0=None):
    """Wind-flagged shore pine: trunk leans and curves downwind, crown limbs stream toward WNW, thin windward side, needle pads + stroke cards."""
    rng.seed(seed)
    rr = random.Random(seed)
    bark, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    zs = [-1.0] + [H * f for f in (0.1, 0.28, 0.48, 0.68, 0.86, 1.0)]
    P = [Vector((noise.noise(Vector((z * 0.09, seed, 0))) * 1.6, noise.noise(Vector((0, seed, z * 0.09))) * 1.6, z)) + wlean(z, H, amt) for z in zs]
    r0 = r0 or H * 0.075
    rad = [r0 * f for f in (1.0, 0.82, 0.64, 0.5, 0.36, 0.22, 0.06)]
    tube(bark, P, rad, sides=8, uvs=8.0)
    for i in range(5):  # surface roots
        a = i * TAU / 5 + rr.uniform(-0.2, 0.2)
        c, s = math.cos(a), math.sin(a)
        tube(bark, [Vector((c * r0 * 0.7, s * r0 * 0.7, 2.6)), Vector((c * r0 * 2.0, s * r0 * 2.0, 0.9)), Vector((c * r0 * 3.4, s * r0 * 3.4, -0.7))],
             [r0 * 0.5, r0 * 0.32, r0 * 0.12], sides=6)

    def tp(z):
        return Vector((float(np.interp(z, zs, [p.x for p in P])), float(np.interp(z, zs, [p.y for p in P])), z))

    for lv in range(nlvl):
        z = H * (0.3 + 0.62 * lv / max(nlvl - 1, 1))
        st = tp(z)
        for j in range(4):
            lee = j < 3
            az = (LEE if lee else LEE + math.pi) + rr.uniform(-spread, spread)
            L = H * 0.27 * (1 - 0.45 * lv / nlvl) * rr.uniform(0.8, 1.2) * (1 if lee else 0.4)
            pts = limb(bark, st, az, L, 0.22, r0 * 0.2 * (1 - 0.4 * lv / nlvl), steps=4, droop=0.25, sides=5)
            if dead:
                limb(bark, pts[2], az + 0.7, L * 0.4, 0.3, r0 * 0.08, steps=3, droop=0.3, sides=4)
                continue
            p = pad_p(pts[-1] + Vector((0, 0, 0.6)), max(3.0, L * 0.68), 2.3, 1.3, (-0.1 * math.cos(az), -0.1 * math.sin(az)))
            pad(mass, p, nseg=12, rings=3)
            needles(det, pts[-1] + Vector((0, 0, 0.8)), 80, 4.0, rr)
            needles(det, pts[-2], 34, 3.2, rr)
            for fr in (0.3, 0.6):  # a pad and burst partway along the limb so crowns read as layered boughs, not lone tufts
                q = pad_p(pts[2].lerp(pts[-1], fr) + Vector((0, 0, 0.4)), max(2.2, L * 0.38), 1.6, 1.0)
                pad(mass, q, nseg=10, rings=3)
                needles(det, q["c"], 30, 3.2, rr)
    top = tp(H)
    if dead:  # snapped crown: ragged splinters
        for i in range(6):
            a = i * TAU / 6
            b = top + Vector((math.cos(a) * r0 * 0.1, math.sin(a) * r0 * 0.1, 0))
            ln = rr.uniform(1.2, 5.0)
            tube(bark, [b, b + Vector((math.cos(a) * 0.1, math.sin(a) * 0.1, ln * 0.5)), b + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, ln))], [0.5, 0.35, 0.04], sides=4)
    else:
        needles(det, top, 24, 3.6, rr)
    obj(name, "Bark", bark, MATS["Salt_Bark"], smooth=True)
    if not dead:
        obj(name, "Needles_Mass", mass, MATS["Salt_Needle"], smooth=True)
        obj(name, "Needles_Detail", det, MATS["Salt_Needle"], recalc=False)


# ------------------------------------------------------------------------------------------ scrub
def scrub(name, S, nstems, seed, el=(0.35, 0.9), L0=3.6, leafk=1.0):
    """Low dune scrub: a splayed vase of wiry stems streaming downwind, small grey-green leaf cards on the outer nodes."""
    rr = random.Random(seed)
    stems, det = bmesh.new(), bmesh.new()
    pts_uv = NEEDLE_PTS["Salt_Scrub"]
    for i in range(nstems):
        az, e = i * TAU / nstems + rr.uniform(-0.3, 0.3), rr.uniform(*el)
        d = Vector((math.cos(az) * math.cos(e), math.sin(az) * math.cos(e), math.sin(e)))
        p0 = Vector((rr.uniform(-0.3, 0.3) * S, rr.uniform(-0.3, 0.3) * S, -0.3))
        pts = [p0]
        for k in range(4):
            d = (d + Vector((rr.uniform(-0.25, 0.25), rr.uniform(-0.25, 0.25), rr.uniform(-0.3, 0.05)))).normalized()
            pts.append(pts[-1] + d * (L0 * S / 4))
        pts = [q + wlean(q.z, 5.0 * S, 1.3 * S) for q in pts]
        tube(stems, pts, [0.36 * S, 0.3 * S, 0.22 * S, 0.14 * S, 0.07 * S], sides=5, uvs=4.0)
        for k in (2, 3, 4):
            for sg in (-1, 1):
                sd = (pts[k] - pts[k - 1]).cross(Vector((0, 0, 1))).normalized()
                leaf(det, pts[k], (pts[k] - pts[k - 1]).normalized() * 0.5 + sd * 0.8 * sg + Vector((0, 0, 0.3)), 1.5 * S * leafk * rr.uniform(0.8, 1.2),
                     0.55 * S * leafk, 0.25, rr.choice(pts_uv), tex=0.006)
            for _ in range(3):
                dd = Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(0, 1)))
                leaf(det, pts[k], dd, 1.3 * S * leafk, 0.5 * S * leafk, 0.25, rr.choice(pts_uv), tex=0.006)
    obj(name, "Stems", stems, MATS["Salt_Bark"], smooth=True)
    obj(name, "Leaves", det, MATS["Salt_Scrub"], recalc=False)


# ------------------------------------------------------------------------------------------ driftwood
def drift_log(bm, c, yaw, tilt, L, r, rr, seg=10, sides=8, stubs=3, root=False):
    """Bleached log centred on c: bent, tapering, knobbly, with branch stubs and (optionally) a root-fan end."""
    ox = rr.uniform(0, 50)
    M = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(tilt, 3, "Y")
    pts, rads = [], []
    for i in range(seg + 1):
        t = i / seg
        rad = r * (1 - 0.35 * t) * (1 + 0.1 * noise.noise(Vector((t * 5, ox, 1))))
        pts.append(M @ Vector((-L / 2 + L * t, 0.6 * math.sin(math.pi * t * 1.1 + ox) + 0.3 * noise.noise(Vector((t * 3, ox, 2))), 0)) + c)
        rads.append(rad)
    tube(bm, pts, rads, sides=sides, uvs=8.0)
    for _ in range(stubs):
        i = rr.randint(2, seg - 2)
        a, ln = rr.uniform(0, TAU), rr.uniform(1.2, 3.4)
        b = pts[i]
        d = M @ Vector((rr.uniform(-0.3, 0.3), math.cos(a), math.sin(a) * 0.6 + 0.4)).normalized()
        tube(bm, [b - d * 0.3, b + d * ln * 0.5, b + d * ln], [rads[i] * 0.4, rads[i] * 0.3, rads[i] * 0.08], sides=5)
    if root:
        for k in range(7):
            a = k * TAU / 7 + rr.uniform(-0.2, 0.2)
            q0 = pts[0]
            d = (M @ Vector((-1.0, math.cos(a) * 1.2, math.sin(a) * 1.0))).normalized() * rads[0]
            tube(bm, [q0, q0 + d * 1.0, q0 + d * 2.0 + M @ Vector((0, 0, -0.5)), q0 + d * 2.8 + M @ Vector((0, 0, -0.9))],
                 [rads[0] * 0.45, rads[0] * 0.3, rads[0] * 0.17, rads[0] * 0.06], sides=5)


def driftwood_log(name, seed, L, r, root=True):
    rr = random.Random(seed)
    bm = bmesh.new()
    drift_log(bm, Vector((0, 0, r * 0.7)), 0.0, 0.0, L, r, rr, seg=12, sides=9, stubs=4, root=root)
    obj(name, "Wood", bm, MATS["Salt_Driftwood"], smooth=True)


def driftwood_pile():
    rr = random.Random(721)
    bm = bmesh.new()
    spec = [((0, 0, 1.3), 0.2, 0.0, 15.0, 1.3), ((1.0, 1.6, 3.0), 1.3, 0.12, 13.0, 1.1), ((-1.2, -1.4, 2.8), 2.7, -0.15, 12.0, 1.0),
            ((2.2, -2.0, 1.0), 0.8, 0.05, 11.0, 0.95), ((-2.5, 2.2, 0.9), 2.2, 0.05, 10.0, 0.85), ((0.4, 0.2, 4.4), 0.7, 0.2, 9.0, 0.8),
            ((3.5, 2.6, 0.6), 1.9, 0.0, 6.5, 0.6)]
    for c, yaw, tilt, L, r in spec:
        drift_log(bm, Vector(c), yaw, tilt, L, r, rr, seg=8, sides=7, stubs=2, root=(L > 12))
    obj("Driftwood_Pile", "Wood", bm, MATS["Salt_Driftwood"], smooth=True)


# ------------------------------------------------------------------------------------------ grass, reeds, kelp
def grass_piece(name, mat, seed, n, hr, wr, spread, tufts, windk=1.0):
    rr = random.Random(seed)
    bm = bmesh.new()
    cs = [Vector((rr.uniform(-spread, spread), rr.uniform(-spread, spread), -0.1)) for _ in range(tufts)]
    for _ in range(n):
        c = rr.choice(cs) + Vector((rr.uniform(-0.7, 0.7), rr.uniform(-0.7, 0.7), 0))
        a = rr.uniform(0, TAU)
        bend = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(0.3, 1.2) + WIND * rr.uniform(0.7, 1.7) * windk
        blade(bm, c, bend, rr.uniform(*hr), rr.uniform(*wr), 4, 0.12)
    obj(name, "Blades", bm, MATS[mat], smooth=True, recalc=False)


def reeds():
    rr = random.Random(741)
    bm, hd = bmesh.new(), bmesh.new()
    for i in range(70):
        a, d = rr.uniform(0, TAU), rr.uniform(0, 3.4) ** 1.05
        c = Vector((math.cos(a) * d, math.sin(a) * d, -0.2))
        h = rr.uniform(7.0, 12.0)
        bend = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(0.2, 0.9) + WIND * rr.uniform(1.0, 2.2)
        blade(bm, c, bend, h, rr.uniform(0.22, 0.34), 5, 0.1)
    for i in range(14):  # seed plumes: tapered tufts on a few tall stems
        a, d = rr.uniform(0, TAU), rr.uniform(0, 2.4)
        c = Vector((math.cos(a) * d, math.sin(a) * d, 0))
        h = rr.uniform(9.0, 12.5)
        top = c + Vector((0, 0, h)) + WIND * 1.6
        n0 = len(hd.faces)
        tube(hd, [c, c + Vector((0, 0, h * 0.5)) + WIND * 0.5, top], [0.1, 0.08, 0.05], sides=4, uvs=1.0)
        paint(hd, n0, (0.5, 0.45))
        n0 = len(hd.faces)
        vs = bmesh.ops.create_cone(hd, cap_ends=True, segments=6, radius1=0.2, radius2=0.04, depth=1.9)["verts"]
        for v in vs:
            v.co += top + Vector((0, 0, 0.7))
        paint(hd, n0, (0.5, 0.3))
    obj("Shore_Reeds", "Blades", bm, MATS["Salt_Reed"], smooth=True, recalc=False)
    obj("Shore_Reeds", "Heads", hd, MATS["Salt_Reed"], smooth=True)


def kelp_wrack():
    """Washed-up kelp: flat wavy ribbons lying on the sand with a few holdfast bulbs."""
    rr = random.Random(751)
    bm, hf = bmesh.new(), bmesh.new()
    uvl = _uvl(bm)
    for s in range(12):
        a0, L = rr.uniform(0, TAU), rr.uniform(7.0, 15.0)
        c0 = Vector((rr.uniform(-3, 3), rr.uniform(-3, 3), 0))
        w, N = rr.uniform(1.2, 2.0), 14
        path = []
        for i in range(N + 1):
            t = i / N
            ang = a0 + 0.9 * math.sin(t * 4 + s)
            path.append((c0 + Vector((math.cos(ang), math.sin(ang), 0)) * (L * t) + Vector((0, 0, 0.1 + 0.22 * abs(math.sin(t * 9 + s)) + 0.15 * t))))
        rows = []
        for i, p in enumerate(path):
            tan = (path[min(i + 1, N)] - path[max(i - 1, 0)]).normalized()
            sd = tan.cross(Vector((0, 0, 1))).normalized()
            ww = w * (0.3 + 0.7 * math.sin(math.pi * min(i / N * 0.9 + 0.1, 1.0)) ** 0.6) * (1 + 0.25 * math.sin(i * 2.3 + s))
            rows.append((bm.verts.new(p - sd * ww), bm.verts.new(p + sd * ww)))
        for i in range(N):
            f = bm.faces.new((rows[i][0], rows[i][1], rows[i + 1][1], rows[i + 1][0]))
            for l, uv in zip(f.loops, ((0, i / N), (1, i / N), (1, (i + 1) / N), (0, (i + 1) / N))):
                l[uvl].uv = uv
        if s % 3 == 0:  # holdfast
            n0 = len(hf.faces)
            vs = bmesh.ops.create_icosphere(hf, subdivisions=2, radius=1.0)["verts"]
            for v in vs:
                u = v.co.copy()
                k = 1 + 0.3 * fbm(u * 2 + Vector((s, 0, 0)), 2)
                v.co = Vector((u.x * 1.5 * k, u.y * 1.3 * k, max(u.z, -0.1) * 0.9 * k)) + path[0]
            paint(hf, n0, (0.5, 0.55))
    obj("Kelp_Wrack", "Blades", bm, MATS["Salt_Kelp"], smooth=True, recalc=False)
    obj("Kelp_Wrack", "Holdfast", hf, MATS["Salt_Kelp"], smooth=True)


BUILD = [
    ("Salt_Pine_A", lambda: pine("Salt_Pine_A", 801, 50.0, 13.0, 5, 0.55)),
    ("Salt_Pine_B", lambda: pine("Salt_Pine_B", 802, 32.0, 10.0, 4, 0.7, r0=2.6)),
    ("Salt_Pine_Dead", lambda: pine("Salt_Pine_Dead", 803, 36.0, 9.0, 4, 0.8, dead=True, r0=2.5)),
    ("Salt_Grass_Tuft", lambda: grass_piece("Salt_Grass_Tuft", "Salt_Grass", 811, 110, (2.0, 3.8), (0.14, 0.22), 1.4, 3)),
    ("Salt_Grass_Tall", lambda: grass_piece("Salt_Grass_Tall", "Salt_Grass", 812, 90, (4.0, 7.0), (0.18, 0.28), 2.6, 5, 1.2)),
    ("Dune_Scrub_A", lambda: scrub("Dune_Scrub_A", 1.0, 9, 821)),
    ("Dune_Scrub_B", lambda: scrub("Dune_Scrub_B", 0.6, 7, 822, el=(0.2, 0.6), L0=3.2)),
    ("Driftwood_Log", lambda: driftwood_log("Driftwood_Log", 831, 20.0, 1.7)),
    ("Driftwood_Pile", driftwood_pile),
    ("Kelp_Wrack", kelp_wrack),
    ("Shore_Reeds", reeds),
]

run("veg", BUILD, ["Salt_Bark", "Salt_Needle", "Salt_Scrub", "Salt_Grass", "Salt_Reed", "Salt_Kelp", "Salt_Driftwood"])

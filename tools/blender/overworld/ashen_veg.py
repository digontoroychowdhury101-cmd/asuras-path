"""Ashen Stair vegetation family (lane M7): wind-twisted alpine pines, burnt / ashen snags, alpine shrubs, tussock grass, lichen patches.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/ashen_veg.py
  env ASH_ONLY=Name1,Name2 builds a subset; ASH_NORENDER=1 skips renders.

Supersedes: nothing (first Ashen kit script; amberfall_veg.py is the pattern, not replaced). Linked via workers/23d-ashen-kit.md (lead links it from LEDGER.md).
New file because the lane run rules want one script run per family.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.
"""
from pathlib import Path

FAMILY = "veg"
exec(compile((Path(__file__).resolve().parent / "ashen_common.py").read_text(encoding="utf-8"), "ashen_common.py", "exec"), globals())

AZ_W = math.atan2(WIND.y, WIND.x)  # downwind azimuth: the crowns stream this way (flag form)


# ------------------------------------------------------------------------------------------ pines
def pine(name, seed, H, zs, radii, limbs, amt, wob, sd, stubs=(), th=1.3, pal=(("pine", 4), ("blue", 2), ("dry", 1)), top_R=2.6,
         roots=5, rn=(2.4, 2.6, 1.0, 5.0, 1.1), sides=8, n_top=5, tuft_n=9):
    """Wind-twisted alpine pine: leaning wobbling trunk, flat needle shelves only on the downwind side (flag form), bare windward stubs."""
    rng.seed(seed)
    use_pal(*pal)
    bk, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    P = trunk_pts(zs, H, amt, wob, sd)
    trunk_tube(bk, P, radii, sides, [(rn, 0.3 + 0.5 * i) for i in range(roots)], H)
    for z, a in stubs:
        limb(bk, trunk_pts([z], H, amt, wob, sd)[0], a, 4.0, 0.3, 0.6, steps=3, droop=0.3, sides=5)
    for z, daz, ln, el, R in limbs:
        r0 = float(np.interp(z, zs, radii)) * 0.55
        az = AZ_W + daz
        pts = limb(bk, trunk_pts([z], H, amt, wob, sd)[0], az, ln, el, r0, steps=5, droop=0.45, sides=6)
        crown_pad(mass, det, pts[-1], R, th, 1.0, (-0.05 * math.cos(az), -0.05 * math.sin(az)), n_top=n_top, n_under=2, L=(2.0, 3.0))
    crown_pad(mass, det, P[-1], top_R, th, 0.8, (0, 0), n_top=4, n_under=1, L=(2.0, 3.0))
    tuft(det, P[-1] + Vector((0, 0, 2.2)), Vector((WIND.x * 0.4, WIND.y * 0.4, 1.0)), n=tuft_n, L=2.6)
    band_uv(mass, pal[0][0])
    obj(name, "Bark", bk, MATS["Ash_Bark"], smooth=True)
    obj(name, "Boughs", mass, MATS["Ash_Leaf"], smooth=True)
    obj(name, "Boughs_Detail", det, MATS["Ash_Leaf"], recalc=False)


def pine_a():
    pine("Ash_Pine_A", 2701, 50.0, [-1.5, 4, 10, 17, 24, 31, 38, 44, 49], [2.8, 2.2, 1.8, 1.5, 1.25, 1.0, 0.8, 0.55, 0.3],
         ((14, 0.5, 8.0, 0.25, 4.0), (19, -0.7, 7.5, 0.3, 3.8), (24, 1.0, 7.0, 0.35, 3.6), (29, -0.2, 6.0, 0.35, 3.3),
          (34, 0.6, 5.5, 0.4, 3.0), (39, -0.9, 4.5, 0.45, 2.6), (43, 0.2, 3.5, 0.5, 2.2)), 6.0, 1.4, 11, stubs=((12, 5.9), (20, 5.6), (27, 0.2)))


def pine_b():
    pine("Ash_Pine_B", 2702, 64.0, [-1.5, 5, 13, 22, 31, 40, 48, 55, 60, 63], [2.4, 1.9, 1.55, 1.3, 1.1, 0.9, 0.7, 0.5, 0.35, 0.2],
         ((18, 0.4, 6.0, 0.25, 3.2), (23, -0.6, 6.0, 0.3, 3.2), (28, 0.9, 5.5, 0.3, 3.0), (33, -0.3, 5.5, 0.35, 3.0), (38, 0.5, 5.0, 0.4, 2.8),
          (43, -0.8, 4.5, 0.4, 2.6), (48, 0.2, 4.0, 0.45, 2.4), (53, 0.7, 3.5, 0.5, 2.0), (57, -0.4, 3.0, 0.5, 1.8)), 4.0, 0.9, 8,
         stubs=((15, 5.8), (26, 5.4), (35, 0.1)), top_R=2.0, tuft_n=7)


def pine_c():
    """Krummholz: a gnarled, bent, low pine pressed down by the wind."""
    pine("Ash_Pine_C", 2703, 26.0, [-1.5, 2, 6, 10, 14, 18, 22, 25], [2.6, 2.1, 1.7, 1.4, 1.15, 0.9, 0.6, 0.3],
         ((6, 0.3, 10.0, 0.12, 3.8), (9, -0.5, 9.0, 0.15, 3.6), (12, 0.7, 8.0, 0.2, 3.4), (15, -0.2, 7.0, 0.22, 3.0), (19, 0.4, 5.5, 0.3, 2.6)),
         9.0, 2.0, 29, stubs=((5, 5.7), (11, 5.4)), th=1.1, top_R=2.4, sides=7)


# ------------------------------------------------------------------------------------------ snags
def snag(name, seed, H, zs, radii, mat, amt, wob, sd, stubs, fork=None, splinters=7):
    rng.seed(seed)
    bark, ends = bmesh.new(), bmesh.new()
    P = trunk_pts(zs, H, amt, wob, sd)
    trunk_tube(bark, P, radii, 9, [((3.6, 3.4, 1.1, 6.0, 1.2), 0.3 + 0.12 * i) for i in range(5)], H)
    top = P[-1]
    for i in range(splinters):  # snapped top: ragged splinters standing on the break
        a = i * TAU / splinters + rng.uniform(-0.2, 0.2)
        ln = rng.uniform(1.5, 6.0) if i % 2 == 0 else rng.uniform(0.6, 2.2)
        b = top + Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, 0))
        tube(bark, [b, b + Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, ln * 0.5)), b + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, ln))], [0.6, 0.45, 0.04], sides=4)
    disc(ends, top + Vector((0, 0, 0.04)), (0, 0, 1), radii[-1] * 0.95, sides=14, jit=0.5, bulge=-0.5)
    for z, az, ln, el in stubs:
        pts = limb(bark, trunk_pts([z], H, amt, wob, sd)[0], az, ln, el, 0.7, steps=4, droop=0.5)
        limb(bark, pts[2], az + 0.8, ln * 0.5, 0.3, 0.3, steps=3, droop=0.5, sides=5)
    if fork:
        z, az, ln, el, r0 = fork  # a second leader splits off and ends in its own break
        pts = limb(bark, trunk_pts([z], H, amt, wob, sd)[0], az, ln, el, r0, steps=6, droop=0.0, sides=7)
        for k in range(4):
            a = k * TAU / 4
            b = pts[-1] + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0))
            tube(bark, [b, b + Vector((0, 0, 1.4 + k * 0.5)), b + Vector((0.1, 0, 2.4 + k * 0.8))], [0.45, 0.33, 0.04], sides=4)
    obj(name, "Bark", bark, MATS[mat], smooth=True)
    obj(name, "Ends", ends, MATS["Ash_WoodEnd"], recalc=False)


def snag_a():
    snag("Ash_Snag_A", 2711, 34.0, [-1.5, 3, 9, 15, 21, 27, 33], [2.4, 1.9, 1.6, 1.35, 1.15, 0.95, 0.8], "Ash_Char", 2.0, 0.5, 83,
         ((11, 0.5, 8.0, 0.35), (16, 3.4, 6.5, 0.45), (22, 5.4, 5.0, 0.5), (27, 1.9, 3.5, 0.5)))


def snag_b():
    snag("Ash_Snag_B", 2712, 26.0, [-1.5, 3, 8, 13, 18, 23, 25.5], [2.6, 2.1, 1.8, 1.55, 1.3, 1.0, 0.8], "Ash_Deadwood", 3.0, 0.7, 41,
         ((8, 4.0, 6.0, 0.4), (14, 0.2, 5.0, 0.5)), fork=(13.0, 2.2, 13.0, 1.0, 0.9), splinters=6)


def snag_fallen():
    rr = random.Random(2713)
    rng.seed(2713)
    bark, ends = bmesh.new(), bmesh.new()
    L, seg = 20.0, 14
    pts, rad = [], []
    for i in range(seg + 1):
        t = i / seg
        r = (1.7 + (1.2 - 1.7) * t) * (1 + 0.07 * noise.noise(Vector((t * 5, 3.1, 1))))
        pts.append(Vector((-L / 2 + L * t, 0.7 * math.sin(math.pi * t * 1.2 + 3.1) + 0.5 * noise.noise(Vector((t * 3, 3.1, 2))),
                           r * 0.95 - 0.35 + 0.25 * noise.noise(Vector((t * 4, 3.1, 3))))))
        rad.append(r)
    tube(bark, pts, rad, sides=10, uvs=8.0)
    base = pts[0]
    for k in range(7):  # splayed, burnt root stubs at the butt end
        a = k * TAU / 7 + rr.uniform(-0.2, 0.2)
        c, s = math.cos(a), math.sin(a)
        p0 = base + Vector((-0.2, c * rad[0] * 0.9, s * rad[0] * 0.9))
        p1 = p0 + Vector((-1.6, c * 2.0, s * 1.4))
        p2 = p1 + Vector((-1.2, c * 1.2, s * 0.6 - 0.6))
        for q in (p1, p2):
            q.z = max(q.z, -0.6)
        tube(bark, [p0, p1, p2], [0.7, 0.45, 0.16], sides=6)
    for p, r, n in ((pts[0], rad[0], Vector((-1, 0, 0))), (pts[-1], rad[-1], Vector((1, 0, 0)))):
        disc(ends, p + n * 0.04, n, r * 0.96, sides=14, jit=0.45, bulge=0.1, rr=rr)
    for _ in range(5):  # broken limb stubs standing up off the log
        i = rr.randint(2, seg - 3)
        a, ln = rr.uniform(0, TAU), rr.uniform(1.2, 3.0)
        b = Vector((pts[i].x, pts[i].y, pts[i].z + rad[i] * 0.7))
        d = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 1)).normalized()
        tube(bark, [b - d * 0.4, b + d * ln * 0.5, b + d * ln], [0.7, 0.5, 0.2], sides=6)
    obj("Ash_Snag_Fallen", "Bark", bark, MATS["Ash_Char"], smooth=True)
    obj("Ash_Snag_Fallen", "Ends", ends, MATS["Ash_WoodEnd"], recalc=False)


# ------------------------------------------------------------------------------------------ shrubs, tussock, lichen
def shrub_ash(name, S, nstems, seed, pal, el=(0.55, 1.0), L0=3.2, depth=2):
    """Wind-cropped alpine shrub: a low vase of forking stems, leaf clusters on the twig tips (same recipe as Amberfall shrubs)."""
    rr = random.Random(seed)
    rng.seed(seed)
    use_pal(*pal)
    stems, det = bmesh.new(), bmesh.new()

    def lf(p, d, L):
        leaf(det, p, d, L, L * rr.uniform(0.42, 0.55), rr.uniform(0.15, 0.4), rr.choice(LEAF_PTS), tex=0.006)

    def burst(p, ax, n, L):
        ax = ax.normalized()
        e1 = ax.cross(Vector((0, 0, 1)))
        if e1.length < 0.2:
            e1 = ax.cross(Vector((1, 0, 0)))
        e1.normalize()
        e2 = ax.cross(e1)
        for _ in range(n):
            t, ph = rr.uniform(0.2, 1.1), rr.uniform(0, 6.283)
            lf(p, ax * math.cos(t) + (e1 * math.cos(ph) + e2 * math.sin(ph)) * math.sin(t), L * rr.uniform(0.75, 1.15))

    def branch(p, d, L, r, dep):
        pts, dd = [p], d.normalized()
        for _ in range(3):
            dd = (dd + Vector((rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.05)))).normalized()
            pts.append(pts[-1] + dd * (L / 3))
        pts = [q + lean(q.z, 6.0 * S, 0.6 * S) for q in pts]
        tube(stems, pts, [r, r * 0.82, r * 0.64, r * 0.45], sides=5, uvs=4.0)
        side = dd.cross(Vector((0, 0, 1))).normalized()
        if dep > 0:
            for _ in range(rr.choice((2, 3))):
                branch(pts[rr.choice((1, 2, 3))], dd * 0.7 + Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-0.2, 0.6))), L * 0.62, r * 0.5, dep - 1)
            if dep == depth:
                lf(pts[1], dd * 0.4 + side * 0.9, 1.7 * S)
                lf(pts[1], dd * 0.4 - side * 0.9, 1.7 * S)
        else:
            for i in (2, 3):
                for sg in (-1, 1):
                    lf(pts[i], dd * 0.45 + side * 0.8 * sg + Vector((0, 0, 0.25)), 1.6 * S)
            burst(pts[-1], dd + Vector((0, 0, 0.3)), 6, 1.9 * S)

    for i in range(nstems):
        az, e = i * TAU / nstems + rr.uniform(-0.3, 0.3), rr.uniform(*el)
        branch(Vector((rr.uniform(-0.3, 0.3) * S, rr.uniform(-0.3, 0.3) * S, -0.3)),
               Vector((math.cos(az) * math.cos(e), math.sin(az) * math.cos(e), math.sin(e))), L0 * S * rr.uniform(0.9, 1.15), 0.4 * S, depth)
    obj(name, "Stems", stems, MATS["Ash_Bark"], smooth=True)
    obj(name, "Leaves", det, MATS["Ash_Leaf"], recalc=False)


def grass_piece(name, seed, n, hr, wr, spread, br, nseg):
    rr = random.Random(seed)
    rng.seed(seed)
    bm = bmesh.new()
    for _ in range(n):
        a, r = rr.uniform(0, TAU), rr.uniform(0, spread)
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.05))
        bend = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(*br) + WIND * 0.4
        blade(bm, base, bend, rr.uniform(*hr), rr.uniform(*wr), nseg)
    obj(name, "Blades", bm, MATS["Ash_Grass"], smooth=True, recalc=False)


def lichen_patch(name, seed, R, n, rmin, rmax):
    """Low crusty lichen mounds hugging the ground: n flattened domes (<= 0.9 high) clustered inside radius R."""
    rr = random.Random(seed)
    bm = bmesh.new()
    for i in range(n):
        a, d = rr.uniform(0, TAU), R * rr.uniform(0, 1) ** 0.7
        c = Vector((math.cos(a) * d, math.sin(a) * d, 0.0))
        rx, ry, h = rr.uniform(rmin, rmax), rr.uniform(rmin, rmax) * 0.8, rr.uniform(0.35, 0.8)
        ox, rz = Vector((rr.uniform(0, 50), rr.uniform(0, 50), 0)), rr.uniform(0, 3.14)
        vs = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)["verts"]
        rot = Matrix.Rotation(rz, 3, "Z")
        for v in vs:
            u = v.co.copy()
            k = 1 + 0.18 * noise.noise(u * 2.5 + ox)
            p = rot @ Vector((u.x * rx * k, u.y * ry * k, u.z * h * k))
            v.co = Vector((c.x + p.x, c.y + p.y, max(p.z - 0.15, -0.1)))
        uv_planar(bm, list({f for v in vs for f in v.link_faces}), 6.0, (rr.random(), rr.random()))
    obj(name, "Crust", bm, MATS["Ash_Lichen"], smooth=True)


BUILD = [
    ("Ash_Pine_A", pine_a), ("Ash_Pine_B", pine_b), ("Ash_Pine_C", pine_c),
    ("Ash_Snag_A", snag_a), ("Ash_Snag_B", snag_b), ("Ash_Snag_Fallen", snag_fallen),
    ("Ash_Shrub", lambda: shrub_ash("Ash_Shrub", 1.0, 7, 2721, (("blue", 3), ("pine", 2), ("dry", 1)), el=(0.6, 1.0), L0=3.2)),
    ("Ash_Shrub_Small", lambda: shrub_ash("Ash_Shrub_Small", 0.55, 5, 2722, (("blue", 2), ("pine", 2), ("lichen", 1)), el=(0.6, 1.0), L0=3.2)),
    ("Ash_Tussock_A", lambda: grass_piece("Ash_Tussock_A", 2731, 130, (2.2, 3.4), (0.2, 0.3), 2.2, (0.5, 1.6), 4)),
    ("Ash_Tussock_B", lambda: grass_piece("Ash_Tussock_B", 2732, 70, (1.6, 2.8), (0.18, 0.26), 1.5, (0.4, 1.2), 3)),
    ("Ash_Lichen_A", lambda: lichen_patch("Ash_Lichen_A", 2741, 5.0, 9, 1.8, 3.4)),
    ("Ash_Lichen_B", lambda: lichen_patch("Ash_Lichen_B", 2742, 3.0, 5, 1.2, 2.4)),
]

prep()
veg_mats()
run_family(BUILD)

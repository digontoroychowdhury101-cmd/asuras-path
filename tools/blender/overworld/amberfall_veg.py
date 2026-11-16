"""Amberfall Ravine vegetation family (lane M4): maples (red / gold), red-trunk trees, cliff pine, deadwood, shrubs, bronze ferns, leaf litter, pale grasses.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/amberfall_veg.py
  env AMBER_ONLY=Name1,Name2 builds a subset; AMBER_NORENDER=1 skips renders.

Supersedes: nothing (first Amberfall kit script; the Bellwood scripts are the pattern, not replaced). Linked via workers/23a-amber-kit.md (lead links it from LEDGER.md).
New file because the lane run rules want one script run per family.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.
"""
from pathlib import Path

FAMILY = "veg"
exec(compile((Path(__file__).resolve().parent / "amberfall_common.py").read_text(encoding="utf-8"), "amberfall_common.py", "exec"), globals())


# ------------------------------------------------------------------------------------------ trees
def broadleaf(name, seed, H, zs, radii, sides, tiers, pal, bark="Amb_Bark", amt=4.5, wob=0.6, sd=3, roots=5, rn=(3.5, 3.5, 1.2, 6.0, 1.2),
              top=(5.0, 3.0, 1.1), stubs=(), th=2.2, ntop=8):
    rng.seed(seed)
    use_pal(*pal)
    bk, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    trunk_tube(bk, trunk_pts(zs, H, amt, wob, sd), radii, sides, [(rn, 0.3 + 0.12 * i) for i in range(roots)], H)
    for z, a in stubs:
        limb(bk, trunk_pts([z], H, amt, wob, sd)[0], a, 4.5, 0.35, 0.8, steps=3, droop=0.3)
    for ti, (z, nb, ln, el, R) in enumerate(tiers):
        tier_limbs(bk, mass, det, H, amt, wob, sd, z, nb, ln, el, 1.1 - 0.12 * ti, R, th, ti * 0.8)
    t = trunk_pts([zs[-1] + 0.5], H, amt, wob, sd)[0]
    crown_pad(mass, det, t, top[0], top[1], top[2], (0, 0), n_top=ntop)
    tuft(det, t + Vector((0, 0, 3.0)), Vector((0, 0, 1)), n=12, L=3.2)
    band_uv(mass, pal[0][0])
    obj(name, "Bark", bk, MATS[bark], smooth=True)
    obj(name, "Leaves_Mass", mass, MATS["Amb_Leaf"], smooth=True)
    obj(name, "Leaves_Detail", det, MATS["Amb_Leaf"], recalc=False)


def maple_red():
    broadleaf("Amber_Maple_Red", 2301, 36.0, [-1, 4, 9, 15, 22, 29, 35], [3.0, 2.1, 1.7, 1.4, 1.1, 0.8, 0.45], 9,
              ((13.0, 4, 10.5, 0.5, 7.6), (20.0, 4, 9.5, 0.58, 6.8), (27.0, 3, 7.5, 0.65, 5.6)),
              (("scarlet", 4), ("orange", 1)), amt=4.5, wob=0.6, sd=5, top=(5.0, 3.0, 1.1), stubs=((7.0, 0.4), (10.5, 3.6)))


def maple_gold():
    broadleaf("Amber_Maple_Gold", 2302, 30.0, [-1, 3, 7, 12, 18, 24, 29], [3.8, 2.7, 2.3, 1.9, 1.5, 1.1, 0.6], 10,
              ((11.0, 5, 12.5, 0.38, 8.2), (17.0, 5, 11.0, 0.46, 7.6), (23.0, 4, 8.5, 0.55, 6.2)),
              (("gold", 3), ("orange", 2)), amt=4.0, wob=0.8, sd=21, roots=6, rn=(4.0, 4.0, 1.4, 7.0, 1.4), top=(6.0, 3.0, 1.2), stubs=((5.5, 1.0), (9.0, 4.4)))


def maple_sapling():
    broadleaf("Amber_Maple_Sapling", 2303, 13.0, [-0.5, 2.5, 6, 9.5, 12.5], [0.85, 0.6, 0.45, 0.3, 0.12], 6,
              ((5.5, 3, 5.5, 0.65, 3.4), (9.0, 3, 4.0, 0.7, 2.6)), (("scarlet", 2), ("orange", 2), ("gold", 1)), amt=2.5, wob=0.3, sd=71,
              roots=4, rn=(1.6, 1.6, 0.6, 3.0, 0.45), top=(2.4, 1.5, 0.6), th=1.4, ntop=6)


def red_trunk(name, seed, H, zs, radii, tiers, top):
    """Tall smooth red trunk, sparse high crown of dry yellow-green leaves (the 'sparse reddish trunks' of the dry-grass transition)."""
    broadleaf(name, seed, H, zs, radii, 8, tiers, (("dry", 3), ("gold", 1), ("pine", 1)), bark="Amb_RedBark", amt=3.0, wob=0.4, sd=seed % 40,
              roots=5, rn=(2.8, 2.8, 1.0, 5.0, 0.9), top=top, th=1.8, ntop=6)


def cliff_pine():
    rng.seed(2309)
    use_pal(("pine", 4), ("dry", 1))
    bk, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    H = 28.0
    zs = [-1.5, 2, 6, 10, 14, 18, 22, 26]
    P = trunk_pts(zs, H, 8.0, 1.6, 57)
    trunk_tube(bk, P, [3.2, 2.6, 2.1, 1.8, 1.5, 1.2, 0.9, 0.5], 9, [((3.4, 3.4, 1.3, 6.5, 1.5), 0.2 * i) for i in range(6)], H)
    for i, (z, az, ln, el) in enumerate(((9, 0.3, 11, 0.25), (13, 2.6, 9, 0.35), (16.5, 4.9, 8, 0.3), (20, 1.4, 7, 0.4), (23, 3.9, 5.5, 0.45))):
        pts = limb(bk, trunk_pts([z], H, 8.0, 1.6, 57)[0], az, ln, el, 1.3 - 0.12 * i, steps=5, droop=0.5, sides=7)
        crown_pad(mass, det, pts[-1], 4.6 - 0.3 * i, 1.6, 1.3, (0, 0), n_top=6, n_under=2, L=(2.2, 3.4))
    limb(bk, trunk_pts([12], H, 8.0, 1.6, 57)[0], 5.5, 5.0, 0.3, 0.6, steps=3, droop=0.5, sides=5)  # bare dead stub
    crown_pad(mass, det, P[-1], 3.4, 1.6, 0.9, (0, 0), n_top=6, n_under=1, L=(2.2, 3.2))
    band_uv(mass, "pine")
    obj("Amber_Cliff_Pine", "Bark", bk, MATS["Amb_Bark"], smooth=True)
    obj("Amber_Cliff_Pine", "Leaves_Mass", mass, MATS["Amb_Leaf"], smooth=True)
    obj("Amber_Cliff_Pine", "Leaves_Detail", det, MATS["Amb_Leaf"], recalc=False)


# ------------------------------------------------------------------------------------------ deadwood
def root_arch(bark, a, r_in, reach, h, rad, ph=0.0, sides=6):
    pts, rs = [], []
    for t in (0, 0.14, 0.32, 0.52, 0.72, 0.88, 1.0):
        d = r_in + (reach - r_in) * t
        z = h * (1 - t) ** 1.8 + 0.35 * math.sin(math.pi * t) - 1.1 * t ** 3
        aa = a + 0.22 * math.sin(3 * t + ph)
        pts.append(Vector((math.cos(aa) * d, math.sin(aa) * d, z)))
        rs.append(rad * (1 - 0.72 * t ** 0.7))
    tube(bark, pts, rs, sides=sides)
    return pts


def dead_snag():
    rng.seed(2311)
    H = 32.0
    bark, ends = bmesh.new(), bmesh.new()
    zs = [-1.5, 3, 9, 15, 21, 27, 30.5]
    P = trunk_pts(zs, H, 1.5, 0.45, 83)
    trunk_tube(bark, P, [3.0, 2.3, 2.0, 1.7, 1.45, 1.2, 1.0], 9, [((3.6, 3.4, 1.1, 6.0, 1.2), 0.3 + 0.12 * i) for i in range(5)], H)
    top = P[-1]
    for i in range(7):  # snapped top: ragged splinters standing on the break
        a = i * TAU / 7 + rng.uniform(-0.2, 0.2)
        ln = rng.uniform(1.5, 6.0) if i % 2 == 0 else rng.uniform(0.6, 2.2)
        b = top + Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, 0))
        tube(bark, [b, b + Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, ln * 0.5)), b + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, ln))], [0.6, 0.45, 0.04], sides=4)
    disc(ends, top + Vector((0, 0, 0.04)), (0, 0, 1), 0.95, sides=14, jit=0.5, bulge=-0.5)
    for z, az, ln, el in ((12, 0.5, 9, 0.35), (17, 3.4, 7.5, 0.45), (22, 5.4, 6, 0.5)):
        pts = limb(bark, trunk_pts([z], H, 1.5, 0.45, 83)[0], az, ln, el, 0.7, steps=4, droop=0.5)
        limb(bark, pts[2], az + 0.8, ln * 0.5, 0.3, 0.3, steps=3, droop=0.5, sides=5)
    obj("Amber_Dead_Snag", "Bark", bark, MATS["Amb_Deadwood"], smooth=True)
    obj("Amber_Dead_Snag", "Ends", ends, MATS["Amb_WoodEnd"], recalc=False)


def fallen_log():
    rng.seed(2312)
    rr = random.Random(2312)
    bark, ends = bmesh.new(), bmesh.new()
    L, seg = 22.0, 14
    pts, rad = [], []
    for i in range(seg + 1):
        t = i / seg
        r = (1.9 + (1.5 - 1.9) * t) * (1 + 0.07 * noise.noise(Vector((t * 5, 3.1, 1))))
        pts.append(Vector((-L / 2 + L * t, 0.8 * math.sin(math.pi * t * 1.2 + 3.1) + 0.5 * noise.noise(Vector((t * 3, 3.1, 2))),
                           r * 0.95 - 0.35 + 0.25 * noise.noise(Vector((t * 4, 3.1, 3))))))
        rad.append(r)
    tube(bark, pts, rad, sides=10, uvs=8.0)
    base = pts[0]
    for k in range(8):  # splayed root stubs at the butt end
        a = k * TAU / 8 + rr.uniform(-0.2, 0.2)
        c, s = math.cos(a), math.sin(a)
        p0 = base + Vector((-0.2, c * rad[0] * 0.9, s * rad[0] * 0.9))
        p1 = p0 + Vector((-1.6, c * 2.0, s * 1.4))
        p2 = p1 + Vector((-1.4, c * 1.4, s * 0.6 - 0.6))
        for q in (p1, p2):
            q.z = max(q.z, -0.6)
        tube(bark, [p0, p1, p2], [0.8, 0.5, 0.18], sides=6)
    for p, r, n in ((pts[0], rad[0], Vector((-1, 0, 0))), (pts[-1], rad[-1], Vector((1, 0, 0)))):
        disc(ends, p + n * 0.04, n, r * 0.96, sides=14, jit=0.45, bulge=0.1, rr=rr)
        e1 = n.cross(Vector((0, 0, 1))).normalized()
        e2 = n.cross(e1)
        for _ in range(4):
            a = rr.uniform(0, TAU)
            b = p + (e1 * math.cos(a) + e2 * math.sin(a)) * r * 0.8
            tube(bark, [b, b + n * 0.7, b + n * 1.5], [0.5, 0.35, 0.04], sides=4)
    for _ in range(4):
        i = rr.randint(2, seg - 3)
        a, ln = rr.uniform(0, TAU), rr.uniform(1.4, 3.4)
        b = Vector((pts[i].x, pts[i].y, pts[i].z + rad[i] * 0.7))
        d = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 1)).normalized()
        tube(bark, [b - d * 0.4, b + d * ln * 0.5, b + d * ln], [0.8, 0.6, 0.45], sides=6)
    obj("Amber_Fallen_Log", "Bark", bark, MATS["Amb_Deadwood"], smooth=True)
    obj("Amber_Fallen_Log", "Ends", ends, MATS["Amb_WoodEnd"], recalc=False)


def stump():
    rng.seed(2313)
    rr = random.Random(2313)
    h, r = 4.2, 2.8
    bark, ends = bmesh.new(), bmesh.new()
    tube(bark, [Vector((0, 0, -1.0)), Vector((0.1, 0, 0.4)), Vector((0.15, 0.1, h * 0.55)), Vector((0.1, 0, h))], [r * 1.35, r * 1.12, r, r * 0.96], sides=12)
    for k in range(7):
        root_arch(bark, k * TAU / 7 + rr.uniform(-0.2, 0.2), r * 0.7, r * 2.8, h * 0.45, r * 0.42, ph=rr.uniform(0, 6))
    for _ in range(4):
        a = rr.uniform(0, TAU)
        b = Vector((0.1 + math.cos(a) * r * 0.85, math.sin(a) * r * 0.85, h))
        ln = rr.uniform(0.7, 2.0)
        tube(bark, [b, b + Vector((0, 0, ln * 0.5)), b + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, ln))], [0.8, 0.65, 0.12], sides=5)
    disc(ends, Vector((0.1, 0, h + 0.04)), (0, 0, 1), r * 0.92, sides=18, jit=0.4, bulge=-1.0, rr=rr)
    obj("Amber_Stump", "Bark", bark, MATS["Amb_Deadwood"], smooth=True)
    obj("Amber_Stump", "Ends", ends, MATS["Amb_WoodEnd"], recalc=False)


def root_tangle():
    rng.seed(2314)
    bark = bmesh.new()
    cyl(bark, 0, 0, -0.8, 2.4, 1.8, 3.6, seg=10, uvs=8.0)
    for k in range(9):
        a = k * TAU / 9 + rng.uniform(-0.15, 0.15)
        pts = root_arch(bark, a, 1.2, rng.uniform(8.0, 11.5), 3.0, 1.4, ph=rng.uniform(0, 6))
        if k % 3 == 0:
            p = pts[3]
            d = Vector((math.cos(a + 0.9), math.sin(a + 0.9), 0))
            tube(bark, [p, p + d * 2.2 + Vector((0, 0, 0.3)), p + d * 4.4 + Vector((0, 0, -0.4)), p + d * 6.0 + Vector((0, 0, -0.9))], [0.4, 0.32, 0.2, 0.1], sides=5)
    obj("Amber_Root_Tangle", "Bark", bark, MATS["Amb_Deadwood"], smooth=True)


# ------------------------------------------------------------------------------------------ shrubs, ferns
def shrub_amb(name, S, nstems, seed, pal, el=(0.85, 1.25), L0=3.4, leafk=1.0, depth=2):
    rr = random.Random(seed)
    rng.seed(seed)
    use_pal(*pal)
    stems, det = bmesh.new(), bmesh.new()

    def lf(p, d, L):
        L *= leafk
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
        pts = [q + lean(q.z, 6.0 * S, 0.5 * S) for q in pts]
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
               Vector((math.cos(az) * math.cos(e), math.sin(az) * math.cos(e), math.sin(e))), L0 * S * rr.uniform(0.9, 1.15), 0.45 * S, depth)
    obj(name, "Stems", stems, MATS["Amb_Bark"], smooth=True)
    obj(name, "Leaves", det, MATS["Amb_Leaf"], recalc=False)


def fern_bronze(name, seed, nf, Lo, Li, tho, thi, arch, npin, pang, plen, pw, every=3):
    rng.seed(seed)
    bm = bmesh.new()
    uvl = _uvl(bm)
    for i in range(nf):
        az = i * TAU / nf + rng.uniform(-0.2, 0.2)
        out = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-math.sin(az), math.cos(az), 0))
        inner = i % every == 0
        Lf = rng.uniform(*(Li if inner else Lo))
        th = rng.uniform(*(thi if inner else tho))
        pts = [Vector((0, 0, 0))]
        for k in range(1, 9):
            th_k = th - (k / 8) * arch
            pts.append(pts[-1] + (out * math.cos(th_k) + Vector((0, 0, math.sin(th_k)))) * (Lf / 8))
        pts = [p + lean(p.z, 6.0, 0.5) for p in pts]
        for k in range(8):
            w0, w1 = 0.13 * (1 - k / 9), 0.13 * (1 - (k + 1) / 9)
            q = [bm.verts.new(pts[k] - side * w0), bm.verts.new(pts[k + 1] - side * w1), bm.verts.new(pts[k + 1] + side * w1), bm.verts.new(pts[k] + side * w0)]
            qb = [bm.verts.new(v.co) for v in q]
            uv = ((0.44, k / 8), (0.44, (k + 1) / 8), (0.56, (k + 1) / 8), (0.56, k / 8))
            for f, order in ((bm.faces.new(q), range(4)), (bm.faces.new(qb[::-1]), range(3, -1, -1))):
                for l, j in zip(f.loops, order):
                    l[uvl].uv = uv[j]
        for j in range(npin):
            t = 0.1 + 0.88 * j / (npin - 1)
            kk = min(int(t * 8), 7)
            pos = pts[kk].lerp(pts[kk + 1], t * 8 - kk)
            tan = (pts[kk + 1] - pts[kk]).normalized()
            ln = Lf * plen * max(0.18, math.sin(math.pi * t ** 0.65) ** 0.9)
            for sg in (-1, 1):
                leaf(bm, pos, tan * math.cos(pang) + side * sg * math.sin(pang), ln, ln * pw, 0.45, kite=True, uvf=lambda tt, ss: (0.5 + ss * 0.45, tt))
    obj(name, "Fronds", bm, MATS["Amb_Fern"], smooth=True, recalc=False)


# ------------------------------------------------------------------------------------------ litter, grass
def litter(name, seed, R, n, mound, pal, twigs=0):
    rr = random.Random(seed)
    rng.seed(seed)
    use_pal(*pal)
    bm, tw = bmesh.new(), bmesh.new()
    for _ in range(n):
        a, d = rr.uniform(0, TAU), R * rr.uniform(0, 1) ** 0.6
        z = 0.06 + mound * max(0.0, 1 - (d / R) ** 2) + rr.uniform(0, 0.12)
        b = rr.uniform(0, TAU)
        dv = Vector((math.cos(b), math.sin(b), rr.uniform(-0.1, 0.35) * (1.0 if mound else 0.3)))
        L = rr.uniform(1.4, 2.4)
        leaf(bm, Vector((math.cos(a) * d, math.sin(a) * d, z)), dv, L, L * rr.uniform(0.5, 0.7), 0.06, rr.choice(LEAF_PTS), tex=0.006)
    for _ in range(twigs):
        a, d = rr.uniform(0, TAU), R * rr.uniform(0, 0.9)
        p = Vector((math.cos(a) * d, math.sin(a) * d, 0.25))
        b = rr.uniform(0, TAU)
        e = Vector((math.cos(b), math.sin(b), 0)) * rr.uniform(1.5, 3.5)
        tube(tw, [p, p + e * 0.5 + Vector((0, 0, 0.1)), p + e], [0.14, 0.12, 0.06], sides=4, uvs=4.0)
    obj(name, "Leaves", bm, MATS["Amb_Leaf"], recalc=False)
    if twigs:
        obj(name, "Twigs", tw, MATS["Amb_Deadwood"])


def clump(bm, n, hr, wr, spread, br, nseg, rr):
    for _ in range(n):
        a, r = rr.uniform(0, TAU), rr.uniform(0, spread)
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.05))
        bend = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(*br) + WIND * 0.4
        blade(bm, base, bend, rr.uniform(*hr), rr.uniform(*wr), nseg)


def grass_piece(name, seed, n, hr, wr, spread, br, nseg, seeds=0):
    rr = random.Random(seed)
    rng.seed(seed)
    use_pal(("dry", 1))
    bm, sd = bmesh.new(), bmesh.new()
    clump(bm, n, hr, wr, spread, br, nseg, rr)
    for _ in range(seeds):
        a, r = rr.uniform(0, TAU), rr.uniform(0, spread)
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.05))
        h = rr.uniform(3.2, 5.0)
        bend = Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(0.3, 0.9) + WIND * 0.4
        pts = [base + bend * (k / 3) ** 2 * 1.2 + Vector((0, 0, h * k / 3)) for k in range(4)]
        tube(sd, pts, [0.05, 0.045, 0.04, 0.03], sides=3, uvs=1.0)
        d = (pts[-1] - pts[-2]).normalized()
        for _ in range(7):
            leaf(sd, pts[-1] - d * rr.uniform(0, 0.9), d + Vector((rr.uniform(-0.5, 0.5), rr.uniform(-0.5, 0.5), 0)), 0.6, 0.15, 0.1,
                 rr.choice(LEAF_PTS), kite=True, tex=0.006)
    obj(name, "Blades", bm, MATS["Amb_Grass"], smooth=True, recalc=False)
    if seeds:
        obj(name, "Seeds", sd, MATS["Amb_Leaf"], recalc=False)


BUILD = [
    ("Amber_Maple_Red", maple_red), ("Amber_Maple_Gold", maple_gold),
    ("Amber_RedTrunk_A", lambda: red_trunk("Amber_RedTrunk_A", 2305, 40.0, [-1, 6, 14, 22, 30, 38], [2.4, 1.7, 1.4, 1.1, 0.8, 0.4],
                                           ((27.0, 4, 9.0, 0.45, 6.5), (33.0, 3, 7.0, 0.55, 5.5)), (4.6, 2.6, 1.0))),
    ("Amber_RedTrunk_B", lambda: red_trunk("Amber_RedTrunk_B", 2306, 52.0, [-1, 8, 18, 28, 38, 46, 51], [2.0, 1.4, 1.15, 0.95, 0.75, 0.5, 0.25],
                                           ((36.0, 3, 7.0, 0.5, 5.0), (43.0, 3, 6.0, 0.55, 4.2)), (3.6, 2.2, 0.9))),
    ("Amber_Cliff_Pine", cliff_pine), ("Amber_Maple_Sapling", maple_sapling),
    ("Amber_Dead_Snag", dead_snag), ("Amber_Fallen_Log", fallen_log), ("Amber_Stump", stump), ("Amber_Root_Tangle", root_tangle),
    ("Amber_Shrub_Dry", lambda: shrub_amb("Amber_Shrub_Dry", 1.0, 7, 2321, (("dry", 3), ("gold", 1)), el=(0.9, 1.3), L0=3.4, leafk=1.0)),
    ("Amber_Shrub_Sumac", lambda: shrub_amb("Amber_Shrub_Sumac", 0.9, 6, 2322, (("scarlet", 3), ("orange", 2)), el=(1.0, 1.4), L0=3.6, leafk=1.2)),
    ("Amber_Fern_Bronze", lambda: fern_bronze("Amber_Fern_Bronze", 2331, 11, (5.0, 7.5), (4.0, 6.0), (1.0, 1.3), (1.3, 1.45), 1.4, 20, 0.95, 0.26, 0.2)),
    ("Amber_Leaf_Litter_A", lambda: litter("Amber_Leaf_Litter_A", 2341, 9.0, 720, 0.0, (("scarlet", 2), ("orange", 2), ("gold", 2), ("dry", 1)), twigs=10)),
    ("Amber_Leaf_Litter_B", lambda: litter("Amber_Leaf_Litter_B", 2342, 7.0, 900, 1.6, (("scarlet", 3), ("orange", 2), ("gold", 1)))),
    ("Amber_Grass_Pale", lambda: grass_piece("Amber_Grass_Pale", 2351, 110, (3.4, 5.8), (0.2, 0.3), 1.8, (0.5, 1.6), 4)),
    ("Amber_Grass_Dry", lambda: grass_piece("Amber_Grass_Dry", 2352, 120, (1.4, 2.8), (0.18, 0.26), 1.8, (0.4, 1.1), 3)),
    ("Amber_Grass_Seed", lambda: grass_piece("Amber_Grass_Seed", 2353, 56, (2.6, 4.4), (0.16, 0.24), 1.6, (0.4, 1.3), 4, seeds=16)),
]

prep()
veg_mats()
run_family(BUILD)

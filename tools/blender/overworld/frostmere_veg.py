"""Frostmere Heads vegetation family (lane M6): snow-laden firs (A, B, broad, sapling), bare birch, frozen shrubs, snow grass tufts, dead snag, fallen log under snow.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b --python tools/blender/overworld/frostmere_veg.py
  env FROST_ONLY=Name1,Name2 builds a subset; FROST_NORENDER=1 skips renders.

Supersedes: nothing (searched first: no earlier Frostmere scripts; amberfall_veg.py is the pattern, not replaced). Linked via workers/23c-frost-kit.md
(the lane lead links it from LEDGER.md). New file because the lane run rules want one script run per family.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

Fir_A / Fir_B match the BiomeDressing slots Snow_Pine_A (16 x 46 x 16) and Snow_Pine_B (12 x 60 x 12). Each fir has Bark, Boughs (dark needle skirts) and Snow (white blankets on the skirts).
"""
from pathlib import Path

FAMILY = "veg"
exec(compile((Path(__file__).resolve().parent / "frostmere_common.py").read_text(encoding="utf-8"), "frostmere_common.py", "exec"), globals())


# ------------------------------------------------------------------------------------------ firs
def fir(name, seed, H, ntier, Rmax, z0f=0.2, dk=0.55, lobes=9, amt=2.5, cover=0.9, taper=0.85, thick_k=0.16, r0=None):
    rng.seed(seed)
    rr = random.Random(seed)
    bk, bg, sn = bmesh.new(), bmesh.new(), bmesh.new()
    r0 = r0 or max(0.9, Rmax * 0.24)
    sd = seed % 50
    zs = [-1.5] + [H * k for k in (0.12, 0.3, 0.5, 0.7, 0.88)] + [H]
    trunk_tube(bk, trunk_pts(zs, H, amt, 0.3, sd), [r0, r0 * 0.88, r0 * 0.7, r0 * 0.52, r0 * 0.34, r0 * 0.2, 0.05], 7,
               [((r0 * 1.2, r0 * 1.1, 0.8, r0 * 2.2, r0 * 0.4), 0.3 + 0.12 * i) for i in range(5)], H)
    zlo, zhi = z0f * H, H * 0.97
    for i in range(ntier):
        t = i / (ntier - 1)
        z = zlo + (zhi - zlo) * t
        R = Rmax * (1 - t) ** taper + 0.7
        p = trunk_pts([z], H, amt, 0.3, sd)[0]
        ph, nseg = rr.uniform(0, 6.28), 20 + int(R * 1.2)
        skirt(bg, p, R, R * dk, 0.9 + thick_k * R, lobes, ph, nseg=nseg, rings=3, rr=rr)
        skirt(sn, p + Vector((0, 0, 0.28)), R, R * dk, 0.5, lobes, ph + 0.2, nseg=nseg, rings=3, shrink=min(1.0, cover * rr.uniform(0.82, 0.97)), rr=rr, rim_noise=0.18)
    obj(name, "Bark", bk, MATS["Frost_Bark"], smooth=True)
    obj(name, "Boughs", bg, MATS["Frost_Fir"], smooth=True)
    obj(name, "Snow", sn, MATS["Frost_Snow"], smooth=True)


# ------------------------------------------------------------------------------------------ birch
def birch(name, seed, H, nlimb, r0=1.5, lean_amt=1.5):
    rng.seed(seed)
    rr = random.Random(seed)
    bk, tw = bmesh.new(), bmesh.new()
    sd = seed % 60
    zs = [-1, H * 0.12, H * 0.3, H * 0.5, H * 0.7, H * 0.88, H]
    trunk_tube(bk, trunk_pts(zs, H, lean_amt, 0.7, sd), [r0, r0 * 0.8, r0 * 0.62, r0 * 0.48, r0 * 0.34, r0 * 0.2, 0.06], 8,
               [((r0 * 1.3, r0 * 1.3, 0.8, r0 * 2.4, r0 * 0.45), 0.3 + 0.2 * i) for i in range(4)], H)

    def twig(p, d, L):
        d = d.normalized()
        tube(tw, [p, p + d * L * 0.5 + Vector((0, 0, -0.1 * L)), p + d * L + Vector((0, 0, -0.35 * L))], [0.11, 0.07, 0.02], sides=3, uvs=2.0)

    for _ in range(nlimb):
        z, az = rr.uniform(H * 0.3, H * 0.92), rr.uniform(0, TAU)
        ln = (H - z) * rr.uniform(0.45, 0.8) + 3.0
        st = trunk_pts([z], H, lean_amt, 0.7, sd)[0]
        pts = limb(bk, st, az, ln, rr.uniform(0.6, 0.95), 0.22 + 0.35 * (1 - z / H), steps=5, droop=rr.uniform(0.3, 0.9), sides=5)
        for j in (1, 2, 3, 4, 5):
            for _ in range(3):
                b = rr.uniform(0, TAU)
                twig(pts[j], Vector((math.cos(b), math.sin(b), rr.uniform(0.0, 0.7))), rr.uniform(1.6, 3.0))
        for _ in range(5):  # weeping tip twigs
            b = rr.uniform(0, TAU)
            twig(pts[-1], Vector((math.cos(b) * 0.5, math.sin(b) * 0.5, -0.2)), rr.uniform(2.0, 3.6))
    obj(name, "Bark", bk, MATS["Frost_Birch"], smooth=True)
    obj(name, "Twigs", tw, MATS["Frost_Twig"], smooth=True)


# ------------------------------------------------------------------------------------------ shrubs
def shrub_frozen(name, S, nstems, seed, depth=2, L0=3.2):
    rr = random.Random(seed)
    rng.seed(seed)
    stems, sn, ice = bmesh.new(), bmesh.new(), bmesh.new()

    def clump(p, k=1.0):
        skirt(sn, p + Vector((0, 0, 0.1)), 0.42 * S * k * rr.uniform(0.7, 1.2), 0.15, 0.2, 5, rr.uniform(0, 6), nseg=10, rings=1, rr=rr, uvs=4.0)

    def branch(p, d, L, r, dep):
        pts, dd = [p], d.normalized()
        for _ in range(3):
            dd = (dd + Vector((rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.3), rr.uniform(-0.3, 0.05)))).normalized()
            pts.append(pts[-1] + dd * (L / 3))
        pts = [q + lean(q.z, 6.0 * S, 0.5 * S) for q in pts]
        tube(stems, pts, [r, r * 0.82, r * 0.64, r * 0.45], sides=4, uvs=4.0)
        if dep > 0:
            for _ in range(rr.choice((2, 3))):
                branch(pts[rr.choice((1, 2, 3))], dd * 0.7 + Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-0.2, 0.6))), L * 0.62, r * 0.5, dep - 1)
            if rr.random() < 0.6:
                clump(pts[2], 0.8)
        else:
            clump(pts[-1])
            q = pts[rr.choice((2, 3))]  # glaze icicle on the tip
            ln = rr.uniform(0.4, 0.9) * S
            tube(ice, [q, q - Vector((0, 0, ln * 0.6)), q - Vector((0, 0, ln))], [0.09 * S, 0.06 * S, 0.01], sides=4, uvs=2.0)

    for i in range(nstems):
        az, e = i * TAU / nstems + rr.uniform(-0.3, 0.3), rr.uniform(0.8, 1.3)
        branch(Vector((rr.uniform(-0.3, 0.3) * S, rr.uniform(-0.3, 0.3) * S, -0.3)),
               Vector((math.cos(az) * math.cos(e), math.sin(az) * math.cos(e), math.sin(e))), L0 * S * rr.uniform(0.9, 1.15), 0.4 * S, depth)
    skirt(sn, Vector((0, 0, -0.2)), 2.6 * S, 0.9 * S, 0.8, 7, 0.3, nseg=14, rings=2, rr=rr, uvs=6.0)
    obj(name, "Stems", stems, MATS["Frost_Twig"], smooth=True)
    obj(name, "Snow", sn, MATS["Frost_Snow"], smooth=True)
    obj(name, "Ice", ice, MATS["Frost_Ice"], smooth=True)


# ------------------------------------------------------------------------------------------ grass
def tuft(name, seed, n, hr, wr, spread, br, nseg):
    rr = random.Random(seed)
    rng.seed(seed)
    bm, sn = bmesh.new(), bmesh.new()
    for _ in range(n):
        a, r = rr.uniform(0, TAU), rr.uniform(0, spread)
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.05))
        blade(bm, base, Vector((math.cos(a), math.sin(a), 0)) * rr.uniform(*br) + WIND * 0.4, rr.uniform(*hr), rr.uniform(*wr), nseg)
    skirt(sn, Vector((0, 0, -0.1)), spread * 1.5, 0.6, 0.6, 6, 0.4, nseg=12, rings=2, rr=rr, uvs=4.0)
    obj(name, "Blades", bm, MATS["Frost_Grass"], smooth=True, recalc=False)
    obj(name, "Snow", sn, MATS["Frost_Snow"], smooth=True)


# ------------------------------------------------------------------------------------------ deadwood
def dead_snag():
    rng.seed(2611)
    H = 30.0
    bark, ends, sn = bmesh.new(), bmesh.new(), bmesh.new()
    zs = [-1.5, 3, 9, 15, 21, 26, 29.5]
    P = trunk_pts(zs, H, 1.5, 0.45, 83)
    trunk_tube(bark, P, [2.8, 2.2, 1.9, 1.6, 1.35, 1.1, 0.9], 9, [((3.4, 3.2, 1.1, 5.6, 1.1), 0.3 + 0.12 * i) for i in range(5)], H)
    top = P[-1]
    for i in range(7):  # snapped top
        a = i * TAU / 7 + rng.uniform(-0.2, 0.2)
        ln = rng.uniform(1.5, 5.5) if i % 2 == 0 else rng.uniform(0.6, 2.0)
        b = top + Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, 0))
        tube(bark, [b, b + Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, ln * 0.5)), b + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, ln))], [0.55, 0.42, 0.04], sides=4)
    disc(ends, top + Vector((0, 0, 0.04)), (0, 0, 1), 0.88, sides=14, jit=0.5, bulge=-0.5)
    skirt(sn, top + Vector((0, 0, 0.3)), 1.0, 0.45, 0.4, 5, 0.2, nseg=8, rings=1, uvs=4.0)
    for z, az, ln, el in ((11, 0.5, 8.5, 0.35), (16, 3.4, 7.0, 0.45), (21, 5.4, 5.5, 0.5)):
        pts = limb(bark, trunk_pts([z], H, 1.5, 0.45, 83)[0], az, ln, el, 0.65, steps=4, droop=0.5)
        limb(bark, pts[2], az + 0.8, ln * 0.5, 0.3, 0.28, steps=3, droop=0.5, sides=5)
        skirt(sn, pts[1] + Vector((0, 0, 0.5)), 1.4, 0.4, 0.35, 5, az, nseg=8, rings=1, uvs=4.0)  # snow resting on the limb
    skirt(sn, Vector((0, 0, -0.3)), 5.2, 1.4, 1.6, 7, 0.1, nseg=18, rings=3, uvs=7.0)  # drift round the foot
    obj("Frost_Dead_Snag", "Bark", bark, MATS["Frost_Deadwood"], smooth=True)
    obj("Frost_Dead_Snag", "Ends", ends, MATS["Frost_WoodEnd"], recalc=False)
    obj("Frost_Dead_Snag", "Snow", sn, MATS["Frost_Snow"], smooth=True)


def fallen_log():
    rng.seed(2612)
    rr = random.Random(2612)
    bark, ends, sn = bmesh.new(), bmesh.new(), bmesh.new()
    L, seg = 22.0, 14
    pts, rad = [], []
    for i in range(seg + 1):
        t = i / seg
        r = (1.9 + (1.5 - 1.9) * t) * (1 + 0.07 * noise.noise(Vector((t * 5, 3.1, 1))))
        pts.append(Vector((-L / 2 + L * t, 0.8 * math.sin(math.pi * t * 1.2 + 3.1) + 0.5 * noise.noise(Vector((t * 3, 3.1, 2))), r * 0.95 - 0.35)))
        rad.append(r)
    tube(bark, pts, rad, sides=10, uvs=8.0)
    for p, r, n in ((pts[0], rad[0], Vector((-1, 0, 0))), (pts[-1], rad[-1], Vector((1, 0, 0)))):
        disc(ends, p + n * 0.04, n, r * 0.96, sides=14, jit=0.45, bulge=0.1, rr=rr)
    for k in range(7):  # splayed root stubs at the butt end
        a = k * TAU / 7 + rr.uniform(-0.2, 0.2)
        c, s = math.cos(a), math.sin(a)
        p0 = pts[0] + Vector((-0.2, c * rad[0] * 0.9, s * rad[0] * 0.9))
        p1 = p0 + Vector((-1.6, c * 2.0, s * 1.4))
        p2 = p1 + Vector((-1.4, c * 1.4, s * 0.6 - 0.6))
        for q in (p1, p2):
            q.z = max(q.z, -0.6)
        tube(bark, [p0, p1, p2], [0.8, 0.5, 0.18], sides=6)
    for i in range(1, seg - 1, 2):  # snow blanket along the top, drifts banked on both flanks
        p = pts[i]
        skirt(sn, Vector((p.x, p.y, p.z + rad[i] * 0.45)), 4.0, 0.9, 0.9, 6, i, nseg=16, rings=2, rr=rr, uvs=6.0)
    for sg in (-1, 1):
        for i in range(2, seg - 1, 2):
            skirt(sn, Vector((pts[i].x, pts[i].y + sg * 3.0, -0.4)), 3.4, 0.9, 1.6, 6, i + sg, nseg=14, rings=2, rr=rr, uvs=6.0)
    obj("Frost_Fallen_Log", "Bark", bark, MATS["Frost_Deadwood"], smooth=True)
    obj("Frost_Fallen_Log", "Ends", ends, MATS["Frost_WoodEnd"], recalc=False)
    obj("Frost_Fallen_Log", "Snow", sn, MATS["Frost_Snow"], smooth=True)


BUILD = [
    ("Frost_Fir_A", lambda: fir("Frost_Fir_A", 2601, 46.0, 15, 7.6, dk=0.85, lobes=9)),
    ("Frost_Fir_B", lambda: fir("Frost_Fir_B", 2602, 60.0, 19, 5.6, z0f=0.16, dk=1.0, lobes=7, amt=3.0, taper=0.9)),
    ("Frost_Fir_Broad", lambda: fir("Frost_Fir_Broad", 2603, 34.0, 10, 10.0, z0f=0.1, dk=0.6, lobes=11, cover=1.0, taper=0.8, thick_k=0.2)),
    ("Frost_Fir_Sapling", lambda: fir("Frost_Fir_Sapling", 2604, 14.0, 6, 3.6, z0f=0.12, dk=0.75, lobes=7, amt=1.0, r0=0.5)),
    ("Frost_Birch_A", lambda: birch("Frost_Birch_A", 2611, 30.0, 12)),
    ("Frost_Birch_B", lambda: birch("Frost_Birch_B", 2612, 22.0, 10, r0=1.1, lean_amt=3.0)),
    ("Frost_Shrub_Frozen", lambda: shrub_frozen("Frost_Shrub_Frozen", 1.0, 7, 2621)),
    ("Frost_Shrub_Small", lambda: shrub_frozen("Frost_Shrub_Small", 0.5, 5, 2622, depth=1)),
    ("Frost_Grass_Tuft_A", lambda: tuft("Frost_Grass_Tuft_A", 2631, 70, (1.6, 2.7), (0.18, 0.26), 1.2, (0.3, 1.0), 3)),
    ("Frost_Grass_Tuft_B", lambda: tuft("Frost_Grass_Tuft_B", 2632, 90, (3.0, 4.8), (0.16, 0.24), 1.7, (0.5, 1.5), 4)),
    ("Frost_Dead_Snag", dead_snag), ("Frost_Fallen_Log", fallen_log),
]

prep()
frost_veg_mats()
run_family(BUILD)

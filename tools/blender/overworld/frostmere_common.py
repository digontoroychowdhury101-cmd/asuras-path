"""Frostmere Heads kit, shared helpers (lane M6). exec'd by frostmere_veg / _rock / _built / _hero (each sets FAMILY first).

Supersedes: nothing (searched first: no earlier Frostmere kit scripts exist; the Snow_Watch_Beacon blockout in hero_silhouettes.py stays as the placeholder).
Linked via outputs/claude-open-world-2026-11-14/workers/23c-frost-kit.md (the lane lead links that note from LEDGER.md).
New file because the four family scripts share one set of helpers; it execs amberfall_common.py (which execs slice_kit.py helpers) and then repoints
paths, registry, part file, studio target and render look at Frostmere, and adds the cold-palette materials. Nothing in the Amberfall files is edited.
Read C:/Users/disha/Documents/asuras-path/outputs/claude-open-world-2026-11-14/CLAUDE_OPEN_WORLD_PROMPT.md and implement its complete world replacement, following its authorisation, model delegation, preservation requirements and acceptance criteria.

1 BU = 1 stud, base centre at the origin, Blender Z up (glTF export makes it Y up).
Env: FROST_ONLY=Name1,Name2 builds a subset; FROST_NORENDER=1 skips renders.
"""
from pathlib import Path

exec(compile((Path(__file__).resolve().parent / "amberfall_common.py").read_text(encoding="utf-8"), "amberfall_common.py", "exec"), globals())

# ------------------------------------------------------------------------------------------ repoint Amberfall's globals at Frostmere
OUT = ROOT / "assets/source/overworld/frostmere"
UP = ROOT / "assets/source/overworld/upload/frostmere"
CAP = ROOT / "outputs/claude-open-world-2026-11-14/captures/kit/frostmere"
NOTE = ROOT / "outputs/claude-open-world-2026-11-14/workers/23c-frost-kit.md"
PARTS = OUT / "parts"
REGISTRY = "assets/FROSTMERE_KIT_UPLOADED.json"
ONLY = {s for s in os.environ.get("FROST_ONLY", "").split(",") if s}
NORENDER = bool(os.environ.get("FROST_NORENDER"))
PART_FILE = PARTS / f"{FAMILY}.json"
PACK = json.loads(PART_FILE.read_text())["pieces"] if PART_FILE.exists() else {}  # the Amberfall PACK read at exec time is discarded
_amber_export = export_piece


def export_piece(name, objs):
    info = _amber_export(name, objs)
    info["studio_target"] = f"ServerStorage/FrostmereKit/{name}"
    info["registry_file"] = REGISTRY
    PART_FILE.write_text(json.dumps({"family": FAMILY, "pieces": PACK}, indent=2) + "\n")
    return info


def render_setup():
    sc, cam, ground = setup_render()
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.72, 0.84, 1)  # cold overcast
    next(n for n in ground.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.74, 0.78, 0.84, 1)
    bpy.data.lights["sun"].energy = 1.7  # snow ground otherwise blows out
    return sc, cam, ground, make_figure()


# ------------------------------------------------------------------------------------------ materials
def snow_mat():
    n = 512
    f1, f2, sp = field(n, 1.6, 401), field(n, 0.6, 402), field(n, 0.1, 403)
    col = np.array([0.93, 0.95, 0.98]) * (0.95 + 0.035 * f1[..., None])
    col = col * np.where(f2[..., None] < -0.9, np.array([0.86, 0.91, 1.0]), 1.0)  # blue shade in hollows
    col = np.where(sp[..., None] > 2.1, 1.0, col)  # sparkle
    return mk("Frost_Snow", col, 0.5 + 0.06 * f1 + 0.02 * f2, 0.55 + 0.1 * f2, 3.0)


def ice_mat():
    n = 512
    f1, f2, cr = field(n, 1.2, 411), field(n, 0.7, 412), field(n, 0.9, 413, 5.0)
    line = np.exp(-(cr / 0.1) ** 2)  # fracture lines
    col = np.array([0.52, 0.76, 0.90]) * (0.9 + 0.08 * f1[..., None])
    col = col * (1 - 0.5 * line[..., None]) + np.array([0.92, 0.97, 1.0]) * 0.5 * line[..., None]
    return mk("Frost_Ice", col, 0.5 + 0.04 * f1 - 0.08 * line, 0.14 + 0.08 * f2 + 0.3 * line, 3.0)


def slate_mat():
    """Frost_Slate 1024 atlas of four 512 quadrants (slice_kit.rock() picks one per face by UV): dark cold slate, wind-packed snow
    (the 'moss' quadrant), damp dark base, pale lichen."""
    n = 512
    yy = np.mgrid[0:n, 0:n][0]
    g1, g2, grain, vein = field(n, 1.3, 461), field(n, 0.8, 462), field(n, 0.1, 463), field(n, 1.0, 464)
    st = np.sin(yy / n * TAU * 11 + g2 * 1.0)
    gran = np.array([0.34, 0.36, 0.40]) * (0.86 + 0.1 * g1[..., None] + 0.07 * st[..., None])
    gran = gran * np.where(grain[..., None] > 1.5, 0.7, 1.0)
    gran = gran * (1 - 0.3 * np.exp(-(vein[..., None] / 0.14) ** 2)) + 0.16 * np.exp(-(vein[..., None] / 0.05) ** 2) * np.array([0.8, 0.85, 0.9])  # pale quartz veins
    h_g = 0.5 + 0.1 * g1 + 0.04 * g2 + 0.05 * st + 0.02 * grain - 0.1 * np.exp(-(vein / 0.14) ** 2)
    m1 = field(n, 1.0, 466)
    snow = np.array([0.92, 0.94, 0.98]) * (0.93 + 0.05 * m1[..., None]) * np.where(m1[..., None] < -0.8, np.array([0.88, 0.92, 1.0]), 1.0)
    h_s = 0.5 + 0.06 * m1
    mf = field(n, 1.2, 468)
    mud = np.array([0.15, 0.16, 0.19]) * (0.8 + 0.3 * mf[..., None])
    mud = np.where(mf[..., None] > 1.3, np.array([0.55, 0.62, 0.70]), mud)  # rime
    h_d = 0.5 + 0.05 * mf
    lf = field(n, 0.6, 470)
    lich = np.array([0.50, 0.54, 0.52]) * (0.9 + 0.08 * g1[..., None])
    lich = np.where(lf[..., None] > 1.3, np.array([0.62, 0.68, 0.50]), lich)
    lich = np.where(lf[..., None] > 2.0, np.array([0.80, 0.62, 0.22]), lich)
    h_l = 0.5 + 0.08 * g1
    col, hh, rough = np.zeros((2 * n, 2 * n, 3)), np.zeros((2 * n, 2 * n)), np.zeros((2 * n, 2 * n))
    for (qu, qv), c, h, r in (((0, 0), gran, h_g, 0.8 + 0.06 * g1), ((1, 0), snow, h_s, 0.62 + 0.05 * m1), ((0, 1), mud, h_d, 0.5 + 0.05 * mf),
                              ((1, 1), lich, h_l, 0.88 + 0.04 * g1)):
        sl = (slice(qv * n, qv * n + n), slice(qu * n, qu * n + n))
        col[sl], hh[sl], rough[sl] = np.clip(c, 0, 1), h, np.clip(r, 0, 1)
    return mk("Frost_Slate", col, hh, rough, 5.0)


def fir_mat():
    n = 512
    fine, low = field(n, 0.4, 481), field(n, 1.2, 482)
    t = np.clip(0.5 + 0.25 * fine + 0.15 * low, 0, 1)[..., None]
    col = np.array([0.05, 0.13, 0.08]) * (1 - t) + np.array([0.15, 0.27, 0.15]) * t
    col = np.where(fine[..., None] > 1.6, np.array([0.28, 0.42, 0.30]), col)
    return mk("Frost_Fir", col, 0.5 + 0.12 * fine, 0.78 - 0.05 * fine, 4.0)


def birch_mat():
    n = 512
    mark, f, fine = field(n, 0.8, 431, 0.12), field(n, 1.2, 432), field(n, 0.6, 433, 6.0)
    col = np.array([0.88, 0.87, 0.83]) * (0.93 + 0.05 * f[..., None]) * np.where(fine[..., None] > 1.0, 0.9, 1.0)
    dark = np.clip((mark - 1.1) * 3, 0, 1)[..., None]  # horizontal lenticel dashes
    col = col * (1 - dark) + np.array([0.09, 0.08, 0.07]) * dark
    peel = np.clip((f - 1.4) * 3, 0, 1)[..., None]
    col = col * (1 - 0.6 * peel) + np.array([0.55, 0.40, 0.26]) * 0.6 * peel
    return mk("Frost_Birch", col, 0.5 + 0.04 * f - 0.2 * dark[..., 0] + 0.05 * peel[..., 0], 0.72 - 0.1 * dark[..., 0], 5.0)


def wood_end_frost():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n]
    x, y = (xx + 0.5) / n * 2 - 1, (yy + 0.5) / n * 2 - 1
    r, ang = np.hypot(x, y), np.arctan2(y, x)
    wp = field(n, 1.2, 441) * 0.035
    ring = (0.5 + 0.5 * np.sin((r + wp) * TAU * 12)) ** 2
    col = np.array([0.66, 0.60, 0.52]) * (1 - ring[..., None] * 0.34)
    crack = np.exp(-((((ang / TAU * 9 + wp * 20) % 1.0) - 0.5) / 0.025) ** 2) * np.clip((r - 0.12) * 3, 0, 1)
    col *= 1 - 0.5 * crack[..., None]
    bark = np.clip((r - 0.9) / 0.04, 0, 1)[..., None]
    col = col * (1 - bark) + np.array([0.26, 0.21, 0.18]) * bark
    return mk("Frost_WoodEnd", col, 0.5 + 0.05 * ring - 0.25 * crack, 0.88 + 0.04 * field(n, 1.0, 442), 5.0)


def common_mats():
    snow_mat()
    ice_mat()


def frost_veg_mats():
    common_mats()
    fir_mat()
    birch_mat()
    bark_tile("Frost_Bark", (0.31, 0.24, 0.20), 421, 6.0, 0.55)
    bark_tile("Frost_Twig", (0.34, 0.27, 0.22), 435, 4.0, 0.6)
    bark_tile("Frost_Deadwood", (0.56, 0.54, 0.50), 425, 5.0, 0.6)
    wood_end_frost()
    blade_mat("Frost_Grass", 128, 256, (0.50, 0.44, 0.26), (0.96, 0.96, 0.92), 443)


def frost_built_mats():
    common_mats()
    slate_mat()
    sand_tile("Frost_Stone", (0.56, 0.58, 0.62), 451, band=0.04, streak=0.15)
    sand_tile("Frost_StoneDark", (0.40, 0.42, 0.46), 453, band=0.04, streak=0.15)
    n = 512
    grain, tone = field(n, 0.9, 321, 16.0), field(n, 1.6, 322)
    mk("Frost_Timber", np.array([0.36, 0.30, 0.26]) * (0.8 + 0.14 * grain[..., None] + 0.08 * tone[..., None]), 0.5 + 0.08 * grain, 0.74 + 0.06 * grain, 4.0)
    yy, xx = np.mgrid[0:n, 0:n]
    tw = 0.5 + 0.5 * np.sin((xx / n * 24 + yy / n * 24) * math.pi)
    mk("Frost_Rope", np.array([0.58, 0.52, 0.40]) * (0.65 + 0.35 * tw[..., None]) * (0.9 + 0.08 * field(n, 1.0, 323)[..., None]), 0.3 + 0.4 * tw, np.full((n, n), 0.9), 5.0)
    r = np.random.default_rng(51)
    ri, fy = yy // 32, (yy % 32) / 32
    xs = (xx + (ri % 2) * 32) % n
    ti, fx = xs // 64, (xs % 64) / 64
    tone_ = r.uniform(0.8, 1.15, (16, 8))[ri, ti][..., None]
    shade = 1 - 0.5 * np.clip((fy - 0.78) / 0.22, 0, 1) - 0.4 * np.clip((0.07 - fx) / 0.07, 0, 1)
    mk("Frost_Roof", np.array([0.27, 0.23, 0.21]) * tone_ * shade[..., None], 0.35 + 0.4 * fy - 0.25 * np.clip((0.07 - fx) / 0.07, 0, 1), np.full((n, n), 0.76), 4.0)
    rf = field(256, 1.5, 341)
    rust = np.clip((rf - 1.0) * 0.8, 0, 0.8)
    col = np.array([0.11, 0.11, 0.12]) * (1 - rust[..., None]) + np.array([0.32, 0.17, 0.09]) * rust[..., None]
    material("Frost_Iron", save("Frost_Iron_Color", col), save("Frost_Iron_Roughness", 0.45 + 0.4 * rust, True),
             save("Frost_Iron_Normal", nmap(0.5 + 0.1 * field(256, 1.2, 342), 3.0), True), save("Frost_Iron_Metal", 0.9 - 0.6 * rust, True))
    g = np.linspace(-1, 1, 128)
    v, u = np.meshgrid(g, g, indexing="ij")
    gl = np.clip(1 - np.sqrt(u ** 2 + v ** 2) * 0.7, 0, 1)[..., None]
    mk("Frost_Glow", np.array([0.80, 0.30, 0.05]) * (1 - gl) + np.array([1.0, 0.84, 0.50]) * gl, np.full((128, 128), 0.5), np.full((128, 128), 0.4), 1.0)
    cols = [(0.30, 0.45, 0.62), (0.85, 0.86, 0.84), (0.66, 0.22, 0.18), (0.32, 0.52, 0.34), (0.82, 0.66, 0.24)]  # weathered blue, white, red, green, yellow
    fl = field(n, 1.0, 345)
    weave = 0.92 + 0.08 * np.sin(xx * 0.9) * np.sin(yy * 0.9)
    col = np.zeros((n, n, 3))
    for b, c in enumerate(cols):
        col[b * 102:(b + 1) * 102] = np.array(c)
    col[510:] = np.array(cols[-1])
    mk("Frost_Flag", col * weave[..., None] * (0.94 + 0.05 * fl[..., None]), 0.5 + 0.1 * weave, np.full((n, n), 0.85), 3.0)


# ------------------------------------------------------------------------------------------ geometry helpers
def slate_uv(bm, faces, rr, S=16.0, mud_h=1.2, dust=0.0, dark=()):
    """Frost_Slate quadrant UVs (never tiled): snow on up-facing faces, damp dark base below mud_h, dark for `dark` faces, a little lichen, slate elsewhere."""
    uvl = _uvl(bm)
    bm.normal_update()
    ox = Vector((rr.uniform(0, 80), rr.uniform(0, 80), rr.uniform(0, 80)))
    for f in faces:
        n, fc = f.normal, f.calc_center_median()
        if f in dark:
            q = "mud"
        elif n.z > 0.5 and 0.8 * n.z + 0.5 * fbm(fc * 0.1 + ox, 2) + dust > 0.5:
            q = "moss"
        elif fc.z < mud_h * (1 + 0.6 * fbm(fc * 0.3 + ox, 2)):
            q = "mud"
        elif fbm(fc * 0.12 + ox * 2, 2) > 0.75:
            q = "lichen"
        else:
            q = "granite"
        qu, qv = QUAD[q]
        ua, va = ((1, 2), (0, 2), (0, 1))[max(range(3), key=lambda i: abs(n[i]))]
        us, vs = [l.vert.co[ua] for l in f.loops], [l.vert.co[va] for l in f.loops]
        eu, ev = max(us) - min(us), max(vs) - min(vs)
        s = max(S, max(eu, ev) * 1.02)
        ou, ov = rr.uniform(0, max(0.0, 1 - eu / s)), rr.uniform(0, max(0.0, 1 - ev / s))
        for l in f.loops:
            co = l.vert.co
            l[uvl].uv = ((qu + 0.03 + ((co[ua] - min(us)) / s + ou) * 0.94) * 0.5, (qv + 0.03 + ((co[va] - min(vs)) / s + ov) * 0.94) * 0.5)


def skirt(bm, c, R, drop, thick, lobes, ph, nseg=22, rings=3, uvs=9.0, shrink=1.0, rr=None, rim_noise=0.1):
    """Closed drooping skirt (fir bough tier / snow blanket / snow clump): conical top from the centre c (rises `drop`) down to a scalloped rim of
    radius R*shrink, underside `thick` below, thin rim. Planar world-stud UVs."""
    rr = rr or rng
    uvl = _uvl(bm)
    ox = rr.uniform(0, 50)

    def rim(a):
        return R * (0.80 + 0.20 * abs(math.cos(lobes * a / 2 + ph)) ** 1.4) * (1 + rim_noise * noise.noise(Vector((math.cos(a) * 1.7 + ox, math.sin(a) * 1.7, ox))))

    def pt(fr, a, top):
        r = fr * rim(a) * shrink
        f2 = min(1.0, fr * shrink)
        z = c.z + drop * (1 - f2 ** 1.15) - 0.22 * R * f2 ** 3
        if not top:
            z -= thick * (1.0 - 0.8 * fr)
        return Vector((c.x + math.cos(a) * r, c.y + math.sin(a) * r, z))

    def grid(top):
        return bm.verts.new(pt(0, 0, top)), [[bm.verts.new(pt(j / rings, TAU * k / nseg, top)) for k in range(nseg)] for j in range(1, rings + 1)]

    ct, T = grid(True)
    cb, B = grid(False)
    new = []
    for k in range(nseg):
        k2 = (k + 1) % nseg
        new += [bm.faces.new((ct, T[0][k], T[0][k2])), bm.faces.new((cb, B[0][k2], B[0][k]))]
        for j in range(rings - 1):
            new.append(bm.faces.new((T[j][k], T[j + 1][k], T[j + 1][k2], T[j][k2])))
            new.append(bm.faces.new((B[j][k2], B[j + 1][k2], B[j + 1][k], B[j][k])))
        new.append(bm.faces.new((T[-1][k], B[-1][k], B[-1][k2], T[-1][k2])))
    for f in new:
        for l in f.loops:
            l[uvl].uv = ((l.vert.co.x - c.x) / uvs + 0.5, (l.vert.co.y - c.y) / uvs + 0.5)


# ------------------------------------------------------------------------------------------ prep
def prep():
    for d in (OUT / "maps", UP / "maps", CAP, PARTS):
        d.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)

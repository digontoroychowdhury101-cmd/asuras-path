"""Tileable PBR texture sets for the Shrine of the Ascendant lobby kit (numpy, deterministic).

Each set is four exact square PNG maps (Color sRGB, Normal OpenGL +Y, Roughness, Metalness) so the
same images serve the kit's SurfaceAppearances and the matching MaterialVariants on primitives.
Arrays are indexed [v][u] with v = 0 at the bottom, which is Blender's pixel order.
Imported by lobby_kit.py inside Blender; save() needs bpy, synthesis does not.
"""
import numpy as np

TAU = 2 * np.pi
# Studs covered by one texture repeat; lobby_kit.py maps UVs with these and the MaterialVariants
# use them as StudsPerTile, so meshes and primitives share one scale.
STUDS = {"Paving": 16, "Stone": 8, "Roof": 17.6, "Lacquer": 8, "Timber": 8, "Bronze": 4, "Rock": 32}
ROOF_TILES = (16, 16)  # cover-tile columns across and tile courses along one repeat


def noise(n, beta, seed, aniso=(1.0, 1.0)):
    """Periodic 1/f^beta noise in [0, 1]; `aniso` stretches the spectrum (u, v)."""
    rng = np.random.default_rng(seed)
    spectrum = np.fft.fft2(rng.standard_normal((n, n)))
    fv = np.fft.fftfreq(n)[:, None] * aniso[1]
    fu = np.fft.fftfreq(n)[None, :] * aniso[0]
    f = np.sqrt(fu * fu + fv * fv)
    f[0, 0] = 1
    spectrum *= f ** (-beta)
    spectrum[0, 0] = 0
    field = np.real(np.fft.ifft2(spectrum))
    lo, hi = np.percentile(field, 0.5), np.percentile(field, 99.5)
    return np.clip((field - lo) / (hi - lo), 0, 1)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def rgb(*c):
    return np.array(c, dtype=np.float64) / 255.0


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def normal_map(height, strength):
    """Tangent-space OpenGL normal from a periodic height field (studs of relief per texel)."""
    du = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * strength
    dv = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * strength
    n = np.stack([-du, -dv, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def bands(n, count, seed, jitter=0.45):
    rng = np.random.default_rng(seed)
    w = rng.uniform(1 - jitter, 1 + jitter, count)
    return np.concatenate([[0], np.cumsum(w / w.sum())])


def paving(n, seed=11):
    """Weathered blue-grey flagstones in running courses, recessed joints, a little moss and wet sheen."""
    u = (np.arange(n) + 0.5) / n
    uu, vv = np.meshgrid(u, u)
    warp = 0.006
    uw = (uu + warp * (noise(n, 1.6, seed + 1) - 0.5)) % 1
    vw = (vv + warp * (noise(n, 1.6, seed + 2) - 0.5)) % 1
    rows = bands(n, 6, seed)
    r = np.clip(np.searchsorted(rows, vw, side="right") - 1, 0, 5)
    rng = np.random.default_rng(seed + 3)
    stone_id = np.zeros((n, n), int)
    edge = np.full((n, n), 1.0)
    for k in range(6):
        cuts = bands(n, int(rng.integers(3, 6)), seed + 10 + k, 0.55)
        phase = rng.uniform(0, 1)
        mask = r == k
        lu = (uw[mask] + phase) % 1
        s = np.clip(np.searchsorted(cuts, lu, side="right") - 1, 0, len(cuts) - 2)
        du = np.minimum(lu - cuts[s], cuts[s + 1] - lu)
        dv = np.minimum(vw[mask] - rows[k], rows[k + 1] - vw[mask])
        edge[mask] = np.minimum(du, dv)
        stone_id[mask] = k * 16 + s
    joint = 0.0022
    chip = noise(n, 1.2, seed + 4)
    interior = smooth(joint * 0.5, joint * (1.4 + 2.2 * chip), edge)
    rim = smooth(0.0, 0.035, edge)
    ids = np.unique(stone_id)
    tone = dict(zip(ids, rng.uniform(-1, 1, len(ids))))
    tint = np.vectorize(tone.get)(stone_id)
    grain = noise(n, 1.0, seed + 5)
    fine = noise(n, 0.6, seed + 6)
    height = interior * (0.65 + 0.25 * grain + 0.1 * fine) + 0.03 * tint
    base = mix(rgb(104, 110, 114), rgb(146, 148, 148), 0.5 + 0.5 * tint * 0.7)
    base = mix(base, rgb(132, 124, 112), smooth(0.5, 0.9, noise(n, 1.8, seed + 7)) * 0.5)
    stain = smooth(0.6, 0.95, noise(n, 1.5, seed + 12))
    base = mix(base, rgb(78, 82, 82), stain * 0.45)
    base *= (0.8 + 0.3 * grain)[..., None] * (0.8 + 0.2 * rim)[..., None]
    moss = smooth(0.7, 0.9, noise(n, 1.4, seed + 8)) * (1 - interior)
    joints = mix(rgb(58, 60, 60), rgb(60, 70, 48), moss)
    color = mix(joints, base, interior)
    wet = smooth(0.55, 0.8, noise(n, 1.7, seed + 9))
    rough = np.clip(0.78 - 0.32 * wet * interior + 0.12 * (1 - interior) + 0.06 * (fine - 0.5), 0.3, 0.95)
    return color, normal_map(height, 10.0), rough, np.zeros((n, n))


def stone(n, seed=21):
    """Carved blue-grey limestone with rain streaks and pitting, for rails, lanterns and stelae."""
    a = noise(n, 1.1, seed)
    b = noise(n, 0.5, seed + 1)
    streak = noise(n, 1.3, seed + 2, aniso=(0.12, 1.0))
    pit = smooth(0.82, 0.95, noise(n, 0.3, seed + 3))
    base = mix(rgb(118, 124, 128), rgb(150, 154, 156), a)
    base = mix(base, rgb(80, 86, 88), smooth(0.6, 0.95, streak) * 0.55)
    base = mix(base, rgb(98, 104, 92), smooth(0.7, 0.95, noise(n, 1.6, seed + 4)) * 0.35)
    color = base * (0.9 + 0.18 * b)[..., None] * (1 - 0.35 * pit)[..., None]
    height = 0.5 * a + 0.3 * b - 0.6 * pit
    rough = np.clip(0.82 + 0.1 * (b - 0.5) - 0.12 * smooth(0.6, 0.95, streak), 0.4, 0.95)
    return color, normal_map(height, 3.0), rough, np.zeros((n, n))


def roof(n, seed=31):
    """Charcoal glazed tiles: semicircular cover tiles over pan tiles, overlapping courses along v."""
    cols, rows = ROOF_TILES
    u = (np.arange(n) + 0.5) / n
    uu, vv = np.meshgrid(u, u)
    pu = (uu * cols) % 1
    pv = (vv * rows) % 1
    ci = np.floor(uu * cols).astype(int)
    ri = np.floor(vv * rows).astype(int)
    cover = np.clip(1 - ((pu - 0.5) / 0.24) ** 2, 0, 1) ** 0.5
    pan = 0.35 * (1 - np.cos(TAU * pu)) * 0.5
    is_cover = cover > 0
    profile = np.where(is_cover, 0.45 + 0.55 * cover, 0.45 - pan)
    # v runs up the slope: each course's lower lip (pv ~ 0) overhangs the course below it.
    lap = smooth(0.0, 0.85, pv)
    lip = 1 - smooth(0.0, 0.06, pv)
    shade = smooth(0.9, 1.0, pv)
    height = profile * (0.75 + 0.25 * lap) + 0.15 * lip
    rng = np.random.default_rng(seed)
    tone = rng.uniform(-1, 1, (rows, cols))[ri % rows, ci % cols]
    glaze = noise(n, 1.0, seed + 1)
    base = mix(rgb(46, 50, 55), rgb(64, 68, 72), 0.5 + 0.18 * tone)
    base = mix(base, rgb(26, 27, 29), np.clip((1 - profile) * 0.55 + shade * 0.5, 0, 1))
    base = mix(base, rgb(86, 90, 94), lip * np.where(is_cover, 0.55, 0.25))
    dust = smooth(0.62, 0.9, noise(n, 1.4, seed + 2, aniso=(0.25, 1.0))) * 0.22
    color = mix(base * (0.9 + 0.2 * glaze)[..., None], rgb(112, 106, 96), dust)
    rough = np.clip(0.42 + 0.25 * (1 - profile) + 0.2 * dust + 0.08 * (glaze - 0.5), 0.25, 0.9)
    return color, normal_map(height, 14.0), rough, np.zeros((n, n))


def lacquer(n, seed=41):
    """Dark vermilion lacquer over timber: grain along v, worn rubs and fine crazing."""
    grain = noise(n, 1.2, seed, aniso=(0.06, 1.0))
    fine = noise(n, 0.7, seed + 1, aniso=(0.2, 1.0))
    wear = smooth(0.8, 0.95, noise(n, 0.9, seed + 2))
    base = mix(rgb(104, 26, 22), rgb(138, 36, 28), grain)
    base = mix(base, rgb(70, 30, 24), wear * 0.5)
    color = base * (0.92 + 0.12 * fine)[..., None]
    height = 0.6 * grain + 0.3 * fine - 0.3 * wear
    rough = np.clip(0.38 + 0.12 * fine + 0.3 * wear, 0.25, 0.85)
    return color, normal_map(height, 2.0), rough, np.zeros((n, n))


def timber(n, seed=51):
    """Smoke-darkened bare timber for beams, brackets, soffits and lattice."""
    grain = noise(n, 1.25, seed, aniso=(0.05, 1.0))
    fine = noise(n, 0.6, seed + 1, aniso=(0.15, 1.0))
    knots = smooth(0.85, 0.97, noise(n, 1.0, seed + 2))
    base = mix(rgb(40, 30, 25), rgb(70, 54, 42), grain)
    color = base * (0.88 + 0.2 * fine)[..., None] * (1 - 0.4 * knots)[..., None]
    height = 0.7 * grain + 0.4 * fine - 0.5 * knots
    rough = np.clip(0.72 + 0.1 * fine, 0.5, 0.95)
    return color, normal_map(height, 3.5), rough, np.zeros((n, n))


def bronze(n, seed=61):
    """Dark temple bronze: warm metal on raised areas, matte verdigris in the recesses."""
    a = noise(n, 1.2, seed)
    b = noise(n, 0.6, seed + 1)
    patina = smooth(0.55, 0.8, a)
    metal = mix(rgb(118, 88, 52), rgb(150, 116, 70), b)
    color = mix(metal, rgb(72, 102, 88), patina * 0.85)
    rough = np.clip(0.35 + 0.45 * patina + 0.1 * (b - 0.5), 0.2, 0.9)
    metalness = np.clip(0.92 - 0.75 * patina, 0, 1)
    return color, normal_map(0.6 * a + 0.4 * b, 2.5), rough, metalness


def rock(n, seed=71):
    """Layered karst limestone: warped strata along v (world height), cracks, moss on ledges."""
    u = (np.arange(n) + 0.5) / n
    uu, vv = np.meshgrid(u, u)
    warp = noise(n, 1.8, seed, aniso=(1.0, 0.5))
    layer_v = (vv + 0.05 * (warp - 0.5)) % 1
    edges = bands(n, 9, seed + 1, 0.6)
    k = np.clip(np.searchsorted(edges, layer_v, side="right") - 1, 0, 8)
    frac = (layer_v - edges[k]) / (edges[k + 1] - edges[k])
    rng = np.random.default_rng(seed + 2)
    tone = rng.uniform(-1, 1, 9)[k]
    detail = noise(n, 0.9, seed + 3)
    crack = smooth(0.0, 0.025, np.abs(noise(n, 1.9, seed + 4, aniso=(1.0, 0.18)) - 0.5))
    ledge = smooth(0.82, 1.0, frac)
    height = 0.55 * (1 - 0.5 * ledge) + 0.3 * detail - 0.35 * (1 - crack) + 0.1 * tone
    base = mix(rgb(112, 108, 102), rgb(146, 140, 128), 0.5 + 0.4 * tone)
    base = mix(base, rgb(86, 92, 98), smooth(0.4, 0.9, noise(n, 1.4, seed + 5)) * 0.45)
    base = base * (0.82 + 0.3 * detail)[..., None]
    moss = ledge * smooth(0.45, 0.7, noise(n, 1.3, seed + 6))
    color = mix(base, rgb(62, 78, 46), moss * 0.85)
    color = mix(rgb(58, 56, 54), color, 0.55 + 0.45 * crack)
    rough = np.clip(0.88 + 0.08 * (detail - 0.5), 0.6, 1)
    return color, normal_map(height, 9.0), rough, np.zeros((n, n))


def cloud(n, seed=81):
    """Sunset cumulus: warm white tops grading to lavender undersides along v (mesh height)."""
    v = ((np.arange(n) + 0.5) / n)[:, None] * np.ones((1, n))
    puff = noise(n, 1.4, seed)
    base = mix(rgb(178, 170, 198), rgb(255, 244, 232), smooth(0.05, 0.85, v))
    color = base * (0.94 + 0.1 * puff)[..., None]
    return color, normal_map(puff, 6.0), np.full((n, n), 0.98), np.zeros((n, n))


def foliage(n, seed=91):
    """Crimson maple canopy: clustered leaves with dark gaps, a few ember-orange highlights."""
    u = (np.arange(n) + 0.5) / n
    uu, vv = np.meshgrid(u, u)
    rng = np.random.default_rng(seed)
    pts = rng.random((260, 2))
    d1 = np.full((n, n), 9.0)
    d2 = np.full((n, n), 9.0)
    tone = np.zeros((n, n))
    for i, (px, py) in enumerate(pts):
        dx = np.abs(uu - px)
        dx = np.minimum(dx, 1 - dx)
        dy = np.abs(vv - py)
        dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        tone = np.where(closer, (i * 0.618) % 1, tone)
        d1 = np.minimum(d1, d)
    edge = smooth(0.0, 0.012, d2 - d1)
    leaf = 1 - smooth(0.02, 0.045, d1)
    height = 0.6 * leaf + 0.4 * edge
    base = mix(rgb(132, 18, 24), rgb(196, 40, 32), tone)
    base = mix(base, rgb(214, 92, 40), smooth(0.85, 1.0, tone) * 0.7)
    color = mix(rgb(52, 10, 14), base, 0.35 + 0.65 * edge * (0.4 + 0.6 * leaf))
    rough = np.clip(0.62 + 0.25 * (1 - edge), 0, 1)
    return color, normal_map(height, 8.0), rough, np.zeros((n, n))


def bark(n, seed=101):
    """Weathered grey-brown bark with long vertical fissures."""
    fiss = noise(n, 1.6, seed, aniso=(0.08, 1.0))
    fine = noise(n, 0.8, seed + 1, aniso=(0.3, 1.0))
    crack = smooth(0.0, 0.08, np.abs(fiss - 0.5))
    base = mix(rgb(54, 46, 42), rgb(108, 98, 90), 0.4 * fine + 0.6 * crack)
    return base, normal_map(0.7 * crack + 0.3 * fine, 7.0), np.full((n, n), 0.92), np.zeros((n, n))


def banner(n, seed=111):
    """Oxblood silk banner: gold border bands and a lotus seal; u across, v up the cloth."""
    u = (np.arange(n) + 0.5) / n
    uu, vv = np.meshgrid(u, u)
    weave = noise(n, 0.4, seed)
    folds = 0.5 + 0.5 * np.cos(uu * TAU * 3)
    base = mix(rgb(86, 14, 18), rgb(128, 22, 24), 0.55 + 0.25 * folds)
    gold = np.zeros((n, n))
    for edge in (0.06, 0.94):
        gold = np.maximum(gold, 1 - smooth(0.0, 0.012, np.abs(uu - edge)))
    for edge in (0.12, 0.86):
        gold = np.maximum(gold, 1 - smooth(0.0, 0.01, np.abs(vv - edge)))
    cx, cy = uu - 0.5, (vv - 0.56) * 1.0
    r = np.sqrt(cx * cx + cy * cy)
    th = np.arctan2(cy, cx)
    petal = 0.17 + 0.06 * np.abs(np.cos(th * 4))
    gold = np.maximum(gold, 1 - smooth(0.0, 0.01, np.abs(r - 0.24)))
    gold = np.maximum(gold, (1 - smooth(petal - 0.01, petal, r)) * smooth(0.04, 0.05, r))
    gold = np.maximum(gold, 1 - smooth(0.0, 0.02, r))
    color = mix(base * (0.92 + 0.12 * weave)[..., None], rgb(212, 166, 86), gold * 0.95)
    rough = np.clip(0.8 - 0.35 * gold, 0, 1)
    return color, normal_map(0.4 * weave + 0.3 * folds + 0.3 * gold, 3.0), rough, gold * 0.6


SETS = {"Paving": paving, "Stone": stone, "Roof": roof, "Lacquer": lacquer, "Timber": timber,
        "Bronze": bronze, "Rock": rock}
NATURE = {"Cloud": cloud, "Foliage": foliage, "Bark": bark, "Banner": banner}
SIZES = {"Bronze": 512, "Cloud": 512, "Bark": 512, "Foliage": 512}
STUDS.update({"Cloud": 1.0, "Foliage": 10, "Bark": 6, "Banner": 1.0})


def save(directory, size=1024, sets=None):
    """Writes every set as <Set>_<Map>.png; returns {set: {map: image}}."""
    import bpy
    out = {}
    for name, fn in (sets or SETS).items():
        n = SIZES.get(name, size)
        color, normal, rough, metal = fn(n)
        maps = {"Color": color, "Normal": normal, "Roughness": rough, "Metalness": metal}
        out[name] = {}
        for label, data in maps.items():
            data = np.clip(data, 0, 1)
            if data.ndim == 2:
                data = np.repeat(data[..., None], 3, -1)
            pixels = np.concatenate([data, np.ones((n, n, 1))], -1).astype(np.float32)
            image = bpy.data.images.new(f"Kit_{name}_{label}", n, n, alpha=False)
            # Byte images store the authored (sRGB-encoded) values as they are; no conversion.
            image.colorspace_settings.name = "sRGB" if label == "Color" else "Non-Color"
            image.pixels.foreach_set(pixels.ravel())
            path = f"{directory}/{name}_{label}.png"
            image.filepath_raw, image.file_format = path, "PNG"
            image.save()
            out[name][label] = image
    return out

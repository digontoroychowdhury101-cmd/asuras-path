"""Vesperhold gothic castle mesh kit, groups A-E (arcades, buttresses, spires, windows/portal, viaduct).

  /Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 -P tools/blender/vesperhold/vesperhold_kit.py -- <out_dir>
  default out_dir: assets/source/vesperhold/kit      env: VESP_ONLY=Piece,Piece  VESP_REUSE_MAPS=1  VESP_EMBED=jpeg|png  VESP_NORENDER=1

Units: 1 Blender unit = 1 stud. Pivot = foot centre (x/y centre, z = 0), Z up in Blender -> Y up in the GLB.
Geometry is real: pointed (two-centred) arches, mouldings swept along arch curves, cusped tracery, crockets, finials.
Builder: welded primitives (prism-with-holes, sweep, loft, lathe) -> bmesh normal recalc -> triplanar UV -> auto-split at
SPLIT_AT tris per sub-mesh (never decimated; every sub asserted < TRI_CAP). Frost = up-facing faces copied into a Frost sub.
Textures: procedural numpy 2048 PBR (Color/Normal/Roughness/Metal; Metal is ALWAYS linked, black for non-metal: mac-28).
GLBs carry meshes + material names only unless VESP_EMBED is set (the 2048 maps live once in maps/; embedding them in 31 GLBs
would be ~1 GB of duplicates and the Studio import route uploads maps per material by hand).
"""
import json
import math
import os
import sys
import time
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, geometry

ROOT = Path(__file__).resolve().parents[3]
_a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(_a[0] if _a else ROOT / "assets/source/vesperhold/kit").resolve()
ONLY = {s for s in os.environ.get("VESP_ONLY", "").split(",") if s}
REUSE = os.environ.get("VESP_REUSE_MAPS") == "1"
EMBED = os.environ.get("VESP_EMBED", "")
TRI_CAP, SPLIT_AT, N = 18000, 15500, 2048
T0 = time.time()
MATS, PIECES, META = {}, {}, {}
manifest = {"kit": "Vesperhold gothic kit A-E", "build": "blender -b -P tools/blender/vesperhold/vesperhold_kit.py",
            "tri_cap_per_sub_mesh": TRI_CAP, "units": "studs (1 BU = 1 stud)", "pivot": "foot centre at origin, z=0 (Blender Z up, GLB Y up)",
            "pieces": {}}
SUBMAT = {"Stone": "Vesp_Soot", "Tracery": "Vesp_Charcoal", "Pinnacles": "Vesp_Charcoal", "Crockets": "Vesp_Charcoal",
          "Dress": "Vesp_Charcoal", "Roof": "Vesp_Slate", "Frost": "Vesp_Frost", "Glass": "Vesp_Glass", "Iron": "Vesp_Iron",
          "Verdigris": "Vesp_Verdigris", "GlassR": "Vesp_Glass"}
# studs per texture repeat (mac-53): castle_wall_slates has ~26 rubble courses per tile -> 64 gives ~2.5-stud courses;
# medieval_blocks_03 has 5 ashlar courses per tile -> 15 gives 3-stud courses on the dressings.
TILE = {"Vesp_Soot": 64.0, "Vesp_Charcoal": 15.0, "Vesp_Frost": 12.0, "Vesp_Slate": 14.0, "Vesp_Iron": 8.0,
        "Vesp_Verdigris": 8.0, "Vesp_Glass": 12.0}
NOFROST = {"Frost", "Glass", "GlassR", "Iron", "Verdigris", "Roof"}
NOWEATHER = {"Frost", "Glass", "GlassR", "Iron", "Verdigris"}


def log(*a):
    print(f"[{time.time() - T0:6.1f}s]", *a, flush=True)


# ============================================================================================ textures
def field(n, beta, seed, stretch=1.0):
    f = (np.fft.fftfreq(n) * n).astype(np.float32)
    fu, fv = np.meshgrid(f, f)
    spec = np.fft.fft2(np.random.default_rng(seed).standard_normal((n, n)).astype(np.float32))
    out = np.real(np.fft.ifft2(spec / (np.sqrt(fu ** 2 + (fv * stretch) ** 2) + 1.0) ** beta)).astype(np.float32)
    return (out - out.mean()) / out.std()


def fld(beta, seed, stretch=1.0):
    return field(N, beta, seed, stretch)


def nmap(h, k):
    dx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
    dy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    nm = np.dstack([-dx * k, -dy * k, np.ones_like(dx)])
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    return (nm * 0.5 + 0.5).astype(np.float32)


def ashlar(rows, wmin, wmax, seed):
    """Staggered ashlar courses: returns (distance in px to nearest joint, block id, block count). Tileable."""
    r = np.random.default_rng(seed)
    rh = N // rows
    bid = np.empty((N, N), np.int32)
    dx = np.empty((N, N), np.float32)
    xs = np.arange(N)
    cnt = 0
    for ri in range(rows):
        ws = []
        while sum(ws) < N:
            ws.append(int(r.integers(wmin, wmax)))
        ws = np.array(ws, float)
        ws = np.round(ws * N / ws.sum()).astype(int)
        ws[-1] += N - ws.sum()
        b = np.concatenate([[0], np.cumsum(ws)])
        k = np.searchsorted(b, xs, "right") - 1
        sl = slice(ri * rh, (ri + 1) * rh)
        bid[sl] = (cnt + k)[None, :]
        dx[sl] = np.minimum(xs - b[k], b[k + 1] - 1 - xs)[None, :]
        cnt += len(ws)
    yy = np.arange(N) % rh
    dy = np.minimum(yy, rh - 1 - yy).astype(np.float32)[:, None]
    return np.minimum(dx, dy), bid, cnt


def worley(G, seed):
    """Tileable cell noise: F1, F2 (in cell units) and cell id."""
    jit = np.random.default_rng(seed).random((G, G, 2)).astype(np.float32)
    y, x = np.mgrid[0:N, 0:N]
    x = x.astype(np.float32) * (G / N)
    y = y.astype(np.float32) * (G / N)
    ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
    fx, fy = x - ix, y - iy
    d1 = np.full((N, N), 9.0, np.float32)
    d2 = d1.copy()
    cid = np.zeros((N, N), np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx, cy = (ix + dx) % G, (iy + dy) % G
            j = jit[cy, cx]
            d = np.sqrt((dx + j[..., 0] - fx) ** 2 + (dy + j[..., 1] - fy) ** 2)
            c = d < d1
            d2 = np.where(c, d1, np.minimum(d2, d))
            cid = np.where(c, cy * G + cx, cid)
            d1 = np.where(c, d, d1)
    return d1, d2, cid


def gen_soot():
    d, bid, nb = ashlar(8, 300, 640, 11)
    rr = np.random.default_rng(12)
    tone = rr.uniform(0.72, 1.28, nb).astype(np.float32)[bid]
    warm = rr.uniform(-1, 1, nb).astype(np.float32)[bid]
    f1, f2, f3, pit = fld(1.5, 21), fld(0.9, 22), fld(0.35, 23), fld(0.6, 24)
    st, st2 = fld(1.0, 25, 18.0), fld(1.3, 26, 7.0)  # vertical streaks: grime runs
    dark = np.clip(st * 0.55 + 0.05, 0, 1)
    light = np.clip(-st2 * 0.5 - 0.1, 0, 1)
    edge = np.clip(1 - d / 14, 0, 1)
    v = 0.105 * tone * (1 + 0.20 * f1 + 0.10 * f2 + 0.06 * f3) * (1 + 0.35 * edge)
    v = np.where(d < 4.5, 0.055 * (1 + 0.3 * f2), v)
    v = np.clip(v * (1 - 0.5 * dark) * (1 + 0.55 * light), 0.04, 0.17)
    col = np.stack([v * (0.98 + 0.02 * warm), v * 0.99, v * (1.06 - 0.02 * warm)], -1)
    h = 0.5 + 0.30 * np.clip(d / 9, 0, 1) ** 0.6 + 0.04 * f1 + 0.02 * f3 - 0.05 * np.clip(pit - 1.5, 0, 2)
    h = np.where(d < 4.5, 0.12 + 0.04 * f2, h)
    return dict(Color=col, Normal=nmap(h, 16), Roughness=np.clip(0.86 - 0.32 * dark + 0.05 * f2 - 0.06 * edge, 0.3, 1))


def gen_charcoal():
    d, bid, nb = ashlar(16, 150, 420, 31)
    rr = np.random.default_rng(32)
    tone = rr.uniform(0.85, 1.18, nb).astype(np.float32)[bid]
    f1, f2, f3, pit = fld(1.4, 33), fld(0.9, 34), fld(0.35, 35), fld(0.7, 36)
    wet = np.clip(fld(1.2, 37, 10.0) * 0.7 + 0.25, 0, 1)
    edge = np.clip(1 - d / 10, 0, 1)
    v = 0.20 * tone * (1 + 0.14 * f1 + 0.08 * f2 + 0.05 * f3) * (1 + 0.25 * edge) * (1 - 0.3 * wet)
    v = np.where(d < 3, 0.10 * (1 + 0.2 * f2), v)
    v = np.clip(v, 0.08, 0.26)
    col = np.stack([v * 0.96, v * 0.99, v * 1.08], -1)
    h = 0.5 + 0.26 * np.clip(d / 7, 0, 1) ** 0.6 + 0.04 * f1 + 0.02 * f3 - 0.05 * np.clip(pit - 1.4, 0, 2)
    h = np.where(d < 3, 0.14, h)
    return dict(Color=col, Normal=nmap(h, 14), Roughness=np.clip(0.78 - 0.38 * wet + 0.05 * f2, 0.3, 1))


def gen_frost():
    f1, f2, f3 = fld(1.7, 41), fld(1.0, 42), fld(0.3, 43)
    hollow = np.clip(-f1 - 0.3, 0, 1)[..., None]
    col = np.array([0.86, 0.90, 0.95], np.float32) * (0.92 + 0.05 * f1[..., None] + 0.03 * f2[..., None])
    col = col * (1 - 0.18 * hollow) + np.array([0.55, 0.65, 0.82], np.float32) * 0.18 * hollow
    dirt = np.clip((fld(1.4, 44) - 1.6) * 1.5, 0, 0.5)[..., None]
    col = col * (1 - dirt) + np.array([0.32, 0.33, 0.36], np.float32) * dirt
    spark = (f3 > 2.3)[..., None]
    col = np.clip(np.where(spark, col + 0.1, col), 0, 0.97)
    h = 0.5 + 0.22 * f1 + 0.07 * f2 + 0.015 * f3
    return dict(Color=col, Normal=nmap(h, 10), Roughness=np.clip(0.62 + 0.08 * f2 - 0.2 * spark[..., 0], 0.3, 1))


def gen_slate():
    y, x = np.mgrid[0:N, 0:N]
    ri = y // 128
    xs = (x + (ri % 2) * 128) % N
    ti, fx, fy = xs // 256, (xs % 256) / 256.0, (y % 128) / 128.0
    rr = np.random.default_rng(51)
    tone = rr.uniform(0.7, 1.2, (16, 8)).astype(np.float32)[ri, ti]
    f1, f2 = fld(1.3, 52), fld(0.8, 53)
    wetst = np.clip(fld(1.0, 54, 12.0) * 0.5, 0, 1)
    v = 0.085 * tone * (1 + 0.15 * f1 + 0.07 * f2)
    shade = 1 - 0.55 * np.clip((fy - 0.78) / 0.22, 0, 1) - 0.4 * np.clip((0.03 - fx) / 0.03, 0, 1)
    v = np.clip(v * shade * (1 + 0.3 * wetst), 0.02, 0.16)
    col = np.stack([v * 0.95, v * 1.0, v * 1.1], -1).astype(np.float32)
    h = 0.35 + 0.4 * fy - 0.3 * np.clip((0.03 - fx) / 0.03, 0, 1) + 0.03 * f2
    return dict(Color=col, Normal=nmap(h.astype(np.float32), 12), Roughness=np.clip(0.6 + 0.1 * f1 - 0.2 * wetst, 0.3, 1))


def gen_iron():
    f1, f2, f3 = fld(1.2, 71), fld(0.8, 72), fld(0.5, 73)
    rust = np.clip((fld(1.4, 74, 6.0) - 0.9) * 1.6, 0, 1)
    v = 0.14 * (1 + 0.2 * f1 + 0.1 * f3)
    col = np.stack([v * 0.95, v * 0.98, v * 1.08], -1)
    rc = np.array([0.34, 0.14, 0.06], np.float32) * (0.8 + 0.3 * f2[..., None])
    col = col * (1 - 0.8 * rust[..., None]) + rc * 0.8 * rust[..., None]
    h = 0.5 + 0.1 * f1 + 0.05 * f2 + 0.03 * np.clip(fld(0.7, 75), -1, 2)
    return dict(Color=np.clip(col, 0, 1), Normal=nmap(h, 4), Roughness=np.clip(0.4 + 0.35 * rust + 0.08 * f2, 0.2, 1),
                Metal=np.clip(0.95 - 0.6 * rust + 0.03 * f3, 0, 1))


def gen_verdigris():
    f1, f2, f3 = fld(1.4, 81), fld(0.9, 82), fld(0.4, 83)
    wear = np.clip((fld(1.5, 84) - 0.7) * 1.4, 0, 1)[..., None]
    pat = np.array([0.16, 0.40, 0.34], np.float32) * (0.8 + 0.2 * f1[..., None] + 0.06 * f3[..., None])
    bro = np.array([0.30, 0.18, 0.08], np.float32) * (0.8 + 0.2 * f2[..., None])
    col = np.clip(pat * (1 - wear) + bro * wear, 0, 1)
    h = 0.5 + 0.12 * f1 + 0.06 * f2 + 0.03 * f3
    w = wear[..., 0]
    return dict(Color=col, Normal=nmap(h, 9), Roughness=np.clip(0.62 - 0.3 * w + 0.08 * f2, 0.2, 1), Metal=np.clip(0.08 + 0.6 * w, 0, 1))


def gen_glass():
    """Medallion glazing (mac-53): 4x4 cells per tile (3 studs at TILE 12). Each cell holds a leaded medallion -- a haloed standing
    figure (circle cells) or an eight-petal rosette (quatrefoil cells) on crimson -- set in a deep blue-violet diamond-quarry
    ground, with iron saddle bars on the cell rows. Panes are lead-bounded regions with one tone each (no per-pixel confetti).
    Polar UVs (rose windows, see rose_glass) wrap the same cells into concentric rings of radiating panes."""
    C = 4
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    cs = N / C
    gx, gy = x / cs, y / cs
    ci, cj = np.floor(gx).astype(np.int32), np.floor(gy).astype(np.int32)
    lx, ly = gx - ci - 0.5, gy - cj - 0.5  # cell-local, y up (row 0 = v 0)
    r = np.hypot(lx, ly)
    th = np.arctan2(ly, lx)
    quat = ((ci + cj) % 2) == 1
    rmed = np.where(quat, 0.31 + 0.10 * np.abs(np.cos(2 * th)), 0.41)
    w = 0.012  # lead half-width in cell units (~6 px)
    inside = r < rmed
    lead = np.abs(r - rmed) < w * 1.5
    band = inside & (r > rmed - 0.055)
    lead |= inside & (np.abs(r - (rmed - 0.055)) < w)
    # figure (circle cells): halo, head, robe; rosette (quatrefoil cells): 8 radial petals around a boss
    hx, hy = lx, ly - 0.15
    halo, head = np.hypot(hx, hy) < 0.095, np.hypot(hx, hy) < 0.055
    robe = (ly < 0.09) & (ly > -0.30) & (np.abs(lx) < 0.05 + (0.09 - ly) * 0.22)
    fig = ~quat & inside & ~band
    lead |= fig & (np.abs(np.hypot(hx, hy) - 0.095) < w) | fig & (np.abs(np.hypot(hx, hy) - 0.055) < w)
    rob_e = (np.abs(np.abs(lx) - (0.05 + (0.09 - ly) * 0.22)) < w) & (ly < 0.09) & (ly > -0.30)
    lead |= fig & (rob_e | ((np.abs(ly - 0.09) < w) & (np.abs(lx) < 0.07)) | ((np.abs(ly + 0.30) < w) & (np.abs(lx) < 0.13)))
    lead |= fig & (np.abs(lx) < w * 0.8) & (ly < 0.0) & (ly > -0.30)  # robe fold
    ros = quat & inside & ~band
    sec = np.floor((th + np.pi) / (np.pi / 4)).astype(np.int32) % 8
    lead |= ros & (np.abs(np.sin(4 * th)) * r < w * 1.2) & (r > 0.07)
    lead |= ros & (np.abs(r - 0.07) < w)
    # ground: diamond quarries, lead on both diagonals; pane id per diamond
    s = 0.16
    pu, pv = (gx + gy) / s, (gx - gy) / s
    ground = ~inside
    lead |= ground & ((np.abs((pu % 1.0) - 0.5) > 0.5 - w / s * 1.2) | (np.abs((pv % 1.0) - 0.5) > 0.5 - w / s * 1.2))
    sad = np.abs(((gy + 0.5) % 1.0) - 0.5) > 0.5 - 0.016  # iron saddle bars between cell rows (thicker than lead)
    lead |= sad
    # pane ids -> one tone each
    pid = np.where(ground, (np.floor(pu).astype(np.int64) * 7919 + np.floor(pv).astype(np.int64) * 104729) % 9973, 0)
    pid = np.where(band, 20000 + (np.floor((th + np.pi) / (np.pi / 8)).astype(np.int64) % 16) + (ci * 31 + cj) * 17, pid)
    pid = np.where(ros, 30000 + sec + (ci * 31 + cj) * 13, pid)
    pid = np.where(fig, 40000 + (ci * 31 + cj) * 11 + halo * 1 + head * 2 + robe * 3, pid)
    rng = np.random.default_rng(62)
    tone = rng.uniform(0.80, 1.12, 50000).astype(np.float32)[pid % 50000]
    crim, crim2 = np.array([0.40, 0.025, 0.035], np.float32), np.array([0.26, 0.015, 0.03], np.float32)
    amber, gold = np.array([0.72, 0.36, 0.05], np.float32), np.array([0.80, 0.55, 0.14], np.float32)
    blue, viol = np.array([0.07, 0.05, 0.26], np.float32), np.array([0.17, 0.04, 0.22], np.float32)
    flesh, green = np.array([0.62, 0.42, 0.24], np.float32), np.array([0.05, 0.16, 0.08], np.float32)
    col = np.zeros((N, N, 3), np.float32)
    gsel = (pid % 11)[..., None]
    col = np.where(ground[..., None], np.where(gsel < 7, blue, np.where(gsel < 9, viol, np.where(gsel < 10, crim2, green))), col)
    col = np.where(band[..., None], np.where(((pid % 2) == 0)[..., None], amber * 0.85, crim2), col)
    col = np.where(ros[..., None], np.where((sec % 2 == 0)[..., None], amber, crim), col)
    col = np.where(fig[..., None], crim, col)
    robe_c = np.where((((ci + cj) // 2) % 2 == 0)[..., None], blue * 1.3, viol * 1.2)
    col = np.where((fig & robe)[..., None], robe_c, col)
    col = np.where((fig & halo)[..., None], gold, col)
    col = np.where((fig & head)[..., None], flesh, col)
    col = np.where((ros & (r < 0.07))[..., None], gold, col)
    f1, f2 = fld(1.4, 63), fld(0.6, 64)
    thick = 0.92 + 0.10 * f1 * 0.5 + 0.03 * f2  # gentle glass thickness variation, no per-pane speckle
    col = col * (tone * thick)[..., None]
    grime = np.clip(fld(1.2, 65) * 0.3 + 0.1, 0, 0.35)[..., None]  # soot film, darker toward the leads
    col = col * (1 - grime)
    leadc = np.array([0.022, 0.02, 0.024], np.float32)
    col = np.where(lead[..., None], leadc, col)
    h = np.where(lead, 0.85, 0.42 + 0.03 * f1)
    return dict(Color=np.clip(col, 0, 1).astype(np.float32), Normal=nmap(h.astype(np.float32), 5),
                Roughness=np.where(lead, 0.75, 0.12 + 0.05 * np.abs(f2)).astype(np.float32))


GENS = {"Vesp_Soot": gen_soot, "Vesp_Charcoal": gen_charcoal, "Vesp_Frost": gen_frost, "Vesp_Slate": gen_slate,
        "Vesp_Iron": gen_iron, "Vesp_Verdigris": gen_verdigris, "Vesp_Glass": gen_glass}
KIND = {"Color": False, "Normal": True, "Roughness": True, "Metal": True}


def get_image(name, kind, arr):
    path = OUT / "maps" / f"{name}_{kind}.png"
    if REUSE and path.exists():
        im = bpy.data.images.load(str(path))
        im.name = f"{name}_{kind}"
        if KIND[kind]:
            im.colorspace_settings.name = "Non-Color"
        im.pack()
        return im
    if arr is None:
        arr = np.zeros((N, N), np.float32)
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, 2)
    im = bpy.data.images.new(f"{name}_{kind}", N, N, alpha=False, is_data=KIND[kind])
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((N, N, 1), np.float32)], 2)
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = str(path)
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im


def _ph_maps(name):
    """CC0 Poly Haven base layer when downloaded (tools/blender/vesperhold/vesp_polyhaven.py), else None -> procedural."""
    if os.environ.get("VESP_PROCEDURAL") == "1":
        return None
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import vesp_polyhaven
    return vesp_polyhaven.maps(name, N)


def build_material(name):
    t = time.time()
    maps = {} if (REUSE and all((OUT / "maps" / f"{name}_{k}.png").exists() for k in KIND)) else (_ph_maps(name) or GENS[name]())
    ims = {k: get_image(name, k, maps.get(k)) for k in KIND}
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    m.use_backface_culling = True
    nt = m.node_tree
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    def tex(im, sock):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = im
        nt.links.new(n.outputs["Color"], p.inputs[sock])

    tex(ims["Color"], "Base Color")
    tex(ims["Roughness"], "Roughness")
    tex(ims["Metal"], "Metallic")  # always linked (black for non-metal): Roblox ignores metallicFactor (mac-28)
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = ims["Normal"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    MATS[name] = m
    log(f"material {name} {N}px {time.time() - t:.1f}s")


# ============================================================================================ primitives
class Sub:
    def __init__(self, mat, owner=None):
        self.mat, self.prims, self.owner = mat, [], owner

    def add(self, prim, T=None):
        vs, fs = prim
        if T is not None:
            vs = [tuple(T @ Vector(p)) for p in vs]
        self.prims.append((vs, fs))


class Subs(dict):
    def __missing__(self, k):
        self[k] = Sub(SUBMAT[k], self)
        return self[k]

    def shift(self, dx=0.0, dy=0.0, dz=0.0):
        for s in self.values():
            s.prims = [([(x + dx, y + dy, z + dz) for x, y, z in vs], fs) for vs, fs in s.prims]


def Tr(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def Rz(a):
    return Matrix.Rotation(a, 4, "Z")


def Ry(a):
    return Matrix.Rotation(a, 4, "Y")


def clean(pts, closed=True, eps=1e-4):
    out = []
    for p in pts:
        if not out or abs(p[0] - out[-1][0]) + abs(p[1] - out[-1][1]) > eps:
            out.append(p)
    if closed and len(out) > 1 and abs(out[0][0] - out[-1][0]) + abs(out[0][1] - out[-1][1]) <= eps:
        out.pop()
    return out


def loft(rings, cap0=True, cap1=True, apex=None):
    n = len(rings[0])
    vs = [p for r in rings for p in r]
    fs = [(i * n + k, (i + 1) * n + k, (i + 1) * n + (k + 1) % n, i * n + (k + 1) % n) for i in range(len(rings) - 1) for k in range(n)]
    if cap0:
        fs.append(tuple(range(n)))
    last = (len(rings) - 1) * n
    if apex is not None:
        vs.append(apex)
        fs += [(last + k, last + (k + 1) % n, len(vs) - 1) for k in range(n)]
    elif cap1:
        fs.append(tuple(range(last, last + n)))
    return vs, fs


def box(x0, x1, y0, y1, z0, z1):
    return loft([[(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]])


def bxm(sx, xa, xb, y0, y1, z0, z1):
    return box(min(sx * xa, sx * xb), max(sx * xa, sx * xb), y0, y1, z0, z1)


def rect(cx, cy, z, hx, hy):
    return [(cx - hx, cy - hy, z), (cx + hx, cy - hy, z), (cx + hx, cy + hy, z), (cx - hx, cy + hy, z)]


def frust(cx, cy, z0, hx0, hy0, z1, hx1, hy1):
    return loft([rect(cx, cy, z0, hx0, hy0), rect(cx, cy, z1, hx1, hy1)])


def pyr(cx, cy, z0, hx, hy, z1):
    return loft([rect(cx, cy, z0, hx, hy)], cap1=False, apex=(cx, cy, z1))


def ngon(cx, cy, z, r, n=8, rot=math.pi / 8):
    return [(cx + r * math.cos(rot + 2 * math.pi * k / n), cy + r * math.sin(rot + 2 * math.pi * k / n), z) for k in range(n)]


def xext(poly_yz, x0, x1):
    return loft([[(x0, y, z) for y, z in poly_yz], [(x1, y, z) for y, z in poly_yz]])


def lathe(prof, seg=8, rot=0.0):
    apex = None
    if prof[-1][0] < 1e-6:
        apex = (0.0, 0.0, prof[-1][1])
        prof = prof[:-1]
    rings = [[(r * math.cos(rot + 2 * math.pi * k / seg), r * math.sin(rot + 2 * math.pi * k / seg), z) for k in range(seg)] for r, z in prof]
    return loft(rings, apex=apex)


def prism(loops, y0, y1):
    """Polygon (outer + holes, XZ plane) extruded from y0 to y1; closed manifold."""
    loops = [clean(l) for l in loops]
    tris = geometry.tessellate_polygon([[Vector((x, z, 0.0)) for x, z in l] for l in loops])
    flat = [p for l in loops for p in l]
    M = len(flat)
    vs = [(x, y0, z) for x, z in flat] + [(x, y1, z) for x, z in flat]
    fs = [tuple(t) for t in tris] + [tuple(M + i for i in t) for t in tris]
    o = 0
    for l in loops:
        m = len(l)
        fs += [(o + i, o + (i + 1) % m, M + o + (i + 1) % m, M + o + i) for i in range(m)]
        o += m
    return vs, fs


def sweep(path, prof, y=0.0, sgn=1.0, closed=False, flip=False):
    """Sweep profile [(d outward along the path normal, dy protrusion along sgn*Y)] along a polyline in the XZ plane at y."""
    path, prof = clean(path, closed), clean(prof)
    n, m = len(path), len(prof)
    vs = []
    for i in range(n):
        a = path[(i - 1) % n] if closed else path[max(i - 1, 0)]
        b = path[(i + 1) % n] if closed else path[min(i + 1, n - 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, tz) or 1.0
        nx, nz = -tz / L, tx / L
        if flip:
            nx, nz = -nx, -nz
        vs += [(path[i][0] + nx * d, y + sgn * dy, path[i][1] + nz * d) for d, dy in prof]
    fs = []
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        fs += [(i * m + k, j * m + k, j * m + (k + 1) % m, i * m + (k + 1) % m) for k in range(m)]
    if not closed:
        fs += [tuple(range(m)), tuple(range((n - 1) * m, n * m))]
    return vs, fs


# ---------------------------------------------------------------------------------------- 2D gothic curves
def arch(a, zs, R, d=0.0, n=10):
    """Two-centred pointed arch, half-width a at springing zs, radius R (>= a); d offsets outward. Left->right, apex once."""
    cxl, r = -a + R, R + d
    thm = math.acos(max(-1.0, min(1.0, -cxl / r)))
    left = [(cxl + r * math.cos(math.pi + (thm - math.pi) * i / (n - 1)), zs + r * math.sin(math.pi + (thm - math.pi) * i / (n - 1))) for i in range(n)]
    return left + [(-x, z) for x, z in reversed(left[:-1])]


def arch_h(a, R):
    return math.sqrt(R * R - (R - a) ** 2)


def archz(x, a, zs, R, d=0.0):
    return zs + math.sqrt(max((R + d) ** 2 - (-abs(x) - (-a + R)) ** 2, 0.0))


def arch_ext(a, zs, R, d=0.0, z0=None, n=10, cx=0.0):
    pts = [(cx + x, z) for x, z in arch(a, zs, R, d, n)]
    return ([(cx - a - d, z0)] + pts + [(cx + a + d, z0)]) if z0 is not None else pts


def circle(cx, cz, r, n=24):
    return [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def barf(w, h):  # bar standing on its plane (protrudes h)
    return [(-w / 2, 0), (w / 2, 0), (w / 2, h * 0.6), (w * 0.25, h), (-w * 0.25, h), (-w / 2, h * 0.6)]


def barc(w, t):  # bar centred on its plane (thickness t)
    return [(-w / 2, -t / 2), (w / 2, -t / 2), (w / 2, t * 0.25), (w * 0.25, t / 2), (-w * 0.25, t / 2), (-w / 2, t * 0.25)]


def mould(spec, base=0.5, n=5):
    """Closed moulding profile (d outward, h protrusion) from [(kind, width, height)]: roll / flat / cove."""
    d, pts = 0.0, [(0.0, 0.0), (0.0, base)]
    for k, w, h in spec:
        if k == "roll":
            pts += [(d + w / 2 * (1 - math.cos(math.pi * i / n)), base + h * math.sin(math.pi * i / n)) for i in range(1, n)]
        elif k == "flat":
            pts += [(d, base + h), (d + w, base + h)]
        elif k == "cove":
            pts += [(d + w * (1 - math.cos(math.pi / 2 * i / n)), base + h * (1 - math.sin(math.pi / 2 * i / n))) for i in range(n + 1)]
        d += w
        pts.append((d, base))
    return pts + [(d, 0.0)]


def col_prof(r, z0, z1):
    return [(r * 1.5, z0), (r * 1.5, z0 + 0.5 * r), (r * 1.12, z0 + 0.9 * r), (r, z0 + 1.25 * r), (r, z1 - 1.9 * r), (r * 1.1, z1 - 1.45 * r),
            (r * 1.35, z1 - 1.0 * r), (r * 1.55, z1 - 0.55 * r), (r * 1.55, z1)]


def colonnette(sub, x, y, z0, z1, r, seg=8):
    sub.add(lathe(col_prof(r, z0, z1), seg), Tr(x, y, 0))


def spear(w, ln, th):
    return prism([[(-w / 2, 0), (w / 2, 0), (0, ln)]], -th / 2, th / 2)


def place_spear(sub, px, y, pz, dx, dz, w, ln, th):
    sub.add(spear(w, ln, th), Tr(px, y, pz) @ Ry(math.atan2(dx, dz)))


def foil(sub, cx, cz, r, n, y, sgn, bw=0.5, h=0.9, centred=False):
    """Cusped ring (foil): swept circle + n spearhead cusps pointing at the centre."""
    sub.add(sweep(circle(cx, cz, r, 28 if r > 2 else 16), barc(bw, h) if centred else barf(bw, h), y, sgn, closed=True))
    for k in range(n):
        ang = 2 * math.pi * (k + 0.5) / n
        place_spear(sub, cx + (r - bw * 0.4) * math.cos(ang), y + (0 if centred else sgn * h * 0.5), cz + (r - bw * 0.4) * math.sin(ang),
                    -math.cos(ang), -math.sin(ang), bw * 2.3, max(r * 0.42, bw * 2), h)


def frame(pos, x, z):
    x, z = Vector(x).normalized(), Vector(z).normalized()
    y = z.cross(x)
    return Matrix(((x.x, y.x, z.x, pos[0]), (x.y, y.y, z.y, pos[1]), (x.z, y.z, z.z, pos[2]), (0, 0, 0, 1)))


def crock(s):
    """Curled leaf crocket (~36 tris): base at origin, +X outward, +Z along the edge."""
    path = [(0.0, 0.0), (0.35, 0.3), (0.75, 0.75), (0.95, 1.3), (0.85, 1.85)]
    wid = [0.55, 0.5, 0.4, 0.28, 0.12]
    rings = []
    for i, ((px, pz), w) in enumerate(zip(path, wid)):
        a, b = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, tz)
        nx, nz = -tz / L, tx / L
        w *= s * 0.5
        hh = w * 0.8
        px, pz = px * s, pz * s
        rings.append([(px + nx * w, -hh, pz + nz * w), (px + nx * w, hh, pz + nz * w), (px - nx * w, hh, pz - nz * w), (px - nx * w, -hh, pz - nz * w)])
    return loft(rings)


def crockets(sub, p0, p1, out, size, step, t0=0.12, t1=0.88, taper=0.5):
    p0, p1, out = Vector(p0), Vector(p1), Vector(out)
    along = (p1 - p0).normalized()
    out = (out - along * out.dot(along)).normalized()
    ln = (p1 - p0).length
    n = max(1, int(ln * (t1 - t0) / step))
    for i in range(n):
        t = t0 + (t1 - t0) * (i + 0.5) / n
        sub.add(crock(size * (1 - taper * t)), frame(p0 + along * ln * t, out, along))


def finial(sub, x, y, z0, s):
    if sub.owner is not None and sub.mat != "Vesp_Verdigris":  # copper-capped finials: the Verdigris sub
        crk = sub.owner["Verdigris"]
        sub.owner["Verdigris"].add(lathe([(s * 0.55, z0), (s * 0.55, z0 + s * 0.5), (s * 0.3, z0 + s * 0.9), (s * 0.3, z0 + s * 1.4), (s * 0.7, z0 + s * 1.9),
                   (s * 0.75, z0 + s * 2.4), (s * 0.45, z0 + s * 3.0), (s * 0.12, z0 + s * 3.5), (0.0, z0 + s * 4.6)], 8), Tr(x, y, 0))
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            crk.add(crock(s * 1.1), frame((x + math.cos(a) * s * 0.3, y + math.sin(a) * s * 0.3, z0 + s * 1.2), (math.cos(a), math.sin(a), 0), (0, 0, 1)))
        return
    sub.add(lathe([(s * 0.55, z0), (s * 0.55, z0 + s * 0.5), (s * 0.3, z0 + s * 0.9), (s * 0.3, z0 + s * 1.4), (s * 0.7, z0 + s * 1.9),
                   (s * 0.75, z0 + s * 2.4), (s * 0.45, z0 + s * 3.0), (s * 0.12, z0 + s * 3.5), (0.0, z0 + s * 4.6)], 8), Tr(x, y, 0))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        sub.add(crock(s * 1.1), frame((x + math.cos(a) * s * 0.3, y + math.sin(a) * s * 0.3, z0 + s * 1.2), (math.cos(a), math.sin(a), 0), (0, 0, 1)))


def pinnacle(D, C, cx, cy, z0, w, h, lvl=1):
    """Square crocketed pinnacle. D body, C crockets+finial. lvl 1 plain, 2 niches+gablets, 3 + corner colonnettes."""
    hw = w / 2
    hp, hs, hr = 0.10 * h, 0.40 * h, 0.38 * h
    D.add(box(cx - hw * 1.25, cx + hw * 1.25, cy - hw * 1.25, cy + hw * 1.25, z0, z0 + hp))
    zb = z0 + hp
    D.add(box(cx - hw, cx + hw, cy - hw, cy + hw, zb, zb + hs))
    D.add(box(cx - hw * 1.12, cx + hw * 1.12, cy - hw * 1.12, cy + hw * 1.12, zb + hs * 0.5, zb + hs * 0.5 + 0.05 * h))
    zt = zb + hs
    D.add(box(cx - hw * 1.12, cx + hw * 1.12, cy - hw * 1.12, cy + hw * 1.12, zt - 0.04 * h, zt))
    if lvl >= 2:
        a = hw * 0.42
        for k in range(4):
            T = Tr(cx, cy, 0) @ Rz(k * math.pi / 2)
            sill, zs = zb + hs * 0.18, zb + hs * 0.18 + hs * 0.22
            Rr = 2 * a
            hole = [(-a, sill)] + arch(a, zs, Rr, 0, 6) + [(a, sill)]
            D.add(prism([[(-hw * 0.78, zb + hs * 0.08), (hw * 0.78, zb + hs * 0.08), (hw * 0.78, zt - hs * 0.1), (-hw * 0.78, zt - hs * 0.1)], hole],
                        -hw - 0.2 * w, -hw), T)
            D.add(prism([[(-hw * 1.05, zt - 0.04 * h), (hw * 1.05, zt - 0.04 * h), (0, zt + 0.2 * h)]], -hw - 0.12 * w, -hw + 0.1 * w), T)
    if lvl >= 3:
        for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
            colonnette(D, cx + sx * hw * 0.98, cy + sy * hw * 0.98, zb, zt, 0.075 * w, 6)
    D.add(pyr(cx, cy, zt, hw * 0.86, hw * 0.86, zt + hr))
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        crockets(C, (cx + sx * hw * 0.86, cy + sy * hw * 0.86, zt), (cx, cy, zt + hr), (sx, sy, 0.0), 0.3 * w, max(0.55 * w, 1.0), 0.1, 0.82)
    finial(C, cx, cy, zt + hr - 0.02 * h, max(0.045 * h, 0.4))


def head_tracery(tr, cx, zs, a, R, y, bw, z_tr):
    """Y-tracery in a pointed opening: transom, mullion, two cusped sub-arches, cusped oculus. Open (no glass)."""
    th = bw * 1.7
    rise = arch_h(a, R)
    tr.add(box(cx - a + 0.05, cx + a - 0.05, y - th / 2, y + th / 2, z_tr - bw / 2, z_tr + bw / 2))
    b = a / 2 - bw * 0.5
    zsub = z_tr + bw / 2
    rc = 0.3 * a
    zc = min(zs + rise - 1.8 * bw - rc - 0.6 * bw, zsub + 1.732 * b + rc * 0.6)
    tr.add(box(cx - bw / 2, cx + bw / 2, y - th / 2, y + th / 2, z_tr, zc - rc))
    for sx in (-1, 1):
        pts = [(cx + sx * a / 2 + x, z) for x, z in arch(b, zsub, 2 * b, 0, 8)]
        tr.add(sweep(pts, barc(bw, th), y, 1.0))
        for f in (0.3, 0.7):
            i = int(f * (len(pts) - 1))
            p, q = pts[i], pts[min(i + 1, len(pts) - 1)]
            tx, tz = q[0] - pts[i - 1][0], q[1] - pts[i - 1][1]
            L = math.hypot(tx, tz) or 1
            place_spear(tr, p[0], y, p[1], tz / L, -tx / L, bw * 2.4, bw * 3.4, th)
    foil(tr, cx, zc, rc, 5, y, 1.0, bw, th, True)


def balustrade(St, Tr_, x0, x1, z0, y, h=7.0, hole_a=1.3, depth=1.6):
    """Pierced balustrade: base rail, cusped pointed-arch panel, coping."""
    St.add(box(x0, x1, y - depth / 2, y + depth / 2, z0, z0 + 0.9))
    St.add(loft([[(x0, y - depth / 2 - 0.15, z0 + h - 1.1), (x1, y - depth / 2 - 0.15, z0 + h - 1.1), (x1, y + depth / 2 + 0.15, z0 + h - 1.1), (x0, y + depth / 2 + 0.15, z0 + h - 1.1)],
                 [(x0, y - depth / 2 - 0.15, z0 + h - 0.35), (x1, y - depth / 2 - 0.15, z0 + h - 0.35), (x1, y + depth / 2 + 0.15, z0 + h - 0.35), (x0, y + depth / 2 + 0.15, z0 + h - 0.35)],
                 [(x0, y - depth / 2 + 0.2, z0 + h), (x1, y - depth / 2 + 0.2, z0 + h), (x1, y + depth / 2 - 0.2, z0 + h), (x0, y + depth / 2 - 0.2, z0 + h)]]))
    n = max(1, int((x1 - x0) // 3.6))
    pitch = (x1 - x0) / n
    holes = []
    sill, zs = z0 + 1.5, z0 + 1.5 + h * 0.26
    for i in range(n):
        c = x0 + pitch * (i + 0.5)
        holes.append([(c - hole_a, sill)] + [(c + x, z) for x, z in arch(hole_a, zs, hole_a * 2, 0, 6)] + [(c + hole_a, sill)])
        for sx in (-1, 1):
            q = arch(hole_a, zs, hole_a * 2, 0, 6)[1 if sx < 0 else -2]
            place_spear(Tr_, c + q[0], y, q[1], -sx * 0.5, -0.85, 0.7, 0.9, depth * 0.7)
    St.add(prism([[(x0, z0 + 0.9), (x1, z0 + 0.9), (x1, z0 + h - 1.1), (x0, z0 + h - 1.1)]] + holes, y - depth * 0.3, y + depth * 0.3))


def parapet_gothic(S, x0, x1, z0, yc, th=2.4):
    """Gothic battlement: corbel table, blind trefoil band, gabled merlons with arrow-slit lancets."""
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    n = max(1, int(round((x1 - x0) / 2.6)))
    pitch = (x1 - x0) / n
    for i in range(n):
        c = x0 + pitch * (i + 0.5)
        st.add(loft([[(c - 0.9, yc - th / 2 - 1.3, z0 + 3.0), (c + 0.9, yc - th / 2 - 1.3, z0 + 3.0), (c + 0.9, yc + th / 2, z0 + 3.0), (c - 0.9, yc + th / 2, z0 + 3.0)],
                     [(c - 0.9, yc - th / 2 - 0.2, z0 + 0.4), (c + 0.9, yc - th / 2 - 0.2, z0 + 0.4), (c + 0.9, yc + th / 2, z0 + 0.4), (c - 0.9, yc + th / 2, z0 + 0.4)]]))
    tr.add(box(x0, x1, yc - th / 2 - 1.3, yc + th / 2 + 0.2, z0 + 3.0, z0 + 3.9))
    st.add(box(x0, x1, yc - th / 2, yc + th / 2, z0 + 3.9, z0 + 8.6))
    holes = []
    for i in range(n):
        c = x0 + pitch * (i + 0.5)
        ha = 0.85
        holes.append([(c - ha, z0 + 4.6)] + [(c + x, z) for x, z in arch(ha, z0 + 6.4, ha * 2.2, 0, 5)] + [(c + ha, z0 + 4.6)])
    tr.add(prism([[(x0, z0 + 4.0), (x1, z0 + 4.0), (x1, z0 + 8.4), (x0, z0 + 8.4)]] + holes, yc - th / 2 - 0.5, yc - th / 2))
    tr.add(box(x0, x1, yc - th / 2 - 0.4, yc + th / 2 + 0.4, z0 + 8.6, z0 + 9.3))
    mw = 3.2 if (x1 - x0) / max(1, int(round((x1 - x0) / 5.0))) >= 5 else 2.0
    m = max(1, int(round((x1 - x0) / 5.0)))
    mp = (x1 - x0) / m
    for i in range(m):
        c = x0 + mp * (i + 0.5)
        slit = [(-0.38, 1.0)] + [(x, z + 0.0) for x, z in arch(0.38, 3.0, 0.8, 0, 4)] + [(0.38, 1.0)]
        st.add(prism([[(-mw / 2, 0), (mw / 2, 0), (mw / 2, 3.6), (0, 5.8), (-mw / 2, 3.6)], slit], -th / 2 - 0.2, th / 2 + 0.2), Tr(c, yc, z0 + 9.3))
        finial(cr, c, yc, z0 + 9.3 + 5.7, 0.35)


def path_crockets(sub, path, y, size, step):
    """Crockets along a left->right arch path, all curling toward the apex, standing outward from the extrados."""
    pts = clean(path, False)
    segs = [(pts[i], pts[i + 1], math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])) for i in range(len(pts) - 1)]
    total = sum(g[2] for g in segs)
    n = max(1, int(total / step))
    xm = (pts[0][0] + pts[-1][0]) / 2
    for i in range(n):
        s, acc = (i + 0.5) / n * total, 0.0
        for p, q, l in segs:
            if acc + l >= s:
                u = (s - acc) / l
                pos, t = (p[0] + u * (q[0] - p[0]), p[1] + u * (q[1] - p[1])), ((q[0] - p[0]) / l, (q[1] - p[1]) / l)
                break
            acc += l
        sg = -1.0 if pos[0] > xm else 1.0
        sub.add(crock(size), frame((pos[0], y, pos[1]), (-t[1], 0.0, t[0]), (sg * t[0], 0.0, sg * t[1])))


def archivolt(tr, a, zs, R, orders, y, sgn, z0=None, cx=0.0, n=12, crock=None):
    for d0, spec in orders:
        tr.add(sweep(arch_ext(a, zs, R, d0, z0, n, cx), mould(spec), y, sgn))
    if crock:  # (size, step, extra protrusion offset): crocketed hood mould + apex finial
        d_out = max(d0 + sum(w for _, w, _ in spec) for d0, spec in orders)
        cr = tr.owner["Crockets"] if tr.owner is not None else tr
        path = [(cx + x, z) for x, z in arch(a, zs, R, d_out, 16)]
        path_crockets(cr, path, y + sgn * crock[2], crock[0], crock[1])
        finial(cr, cx, y + sgn * crock[2], archz(0, a, zs, R, d_out) - 0.2, crock[0] * 0.45)


# ============================================================================================ GROUP A
def bay(S, open_h):
    a, R = 16.0, 32.0
    rise = arch_h(a, R)
    zs, zt = open_h - rise, open_h + 12.0
    ar = arch(a, zs, R, 0, 12)
    st, tr, pn = S["Stone"], S["Tracery"], S["Pinnacles"]
    st.add(prism([[(-20, 0), (-20, zt), (20, zt), (20, 0), (a, 0)] + ar[::-1] + [(-a, 0)]], -4, 4))
    for sx in (-1, 1):
        st.add(bxm(sx, 16, 20, -6, 6, 0, zt))
        st.add(bxm(sx, 15.4, 20, -6.6, 6.6, 0, 2.6))
        st.add(bxm(sx, 15.7, 20, -6.3, 6.3, 2.6, 4.0))
        tr.add(bxm(sx, 15.2, 20, -6.4, 6.4, zs - 1.5, zs))
        for yy in (-6, 6):
            for xo, rr in ((16.9, 0.55), (18.0, 1.0), (19.1, 0.55)):
                colonnette(st, sx * xo, yy, 4.0, zs - 1.5, rr, 8)
            colonnette(st, sx * 16.1, yy * 0.93, 4.0, zs, 0.6, 6)
    for sgn, y in ((-1, -4.0), (1, 4.0)):
        archivolt(tr, a, zs, R, [(0.0, [("roll", 1.0, 0.9), ("cove", 0.8, 0.7), ("roll", 1.4, 1.2)]), (3.2, [("flat", 0.5, 0.4), ("roll", 0.3, 0.3)])], y, sgn, crock=(1.8, 3.6, 0.35))
        for sx in (-1, 1):
            xq = sx * 13.3
            za = archz(xq, a, zs, R, 4.0)
            zq = (za + zt) / 2
            rq = min(4.6, (zt - za) / 2 - 1.4)
            foil(tr, xq, zq, rq, 4, y, sgn, 0.7, 1.0)
    head_tracery(tr, 0.0, zs, a, R, 0.0, 1.0, zs + 2.0)
    # string course + corbel table + cornice slab
    prof = [(-7.4, zt), (7.4, zt), (7.4, zt + 0.7), (6.5, zt + 1.3), (7.0, zt + 1.7), (7.0, zt + 2.4), (6.2, zt + 3.0), (-6.2, zt + 3.0), (-7.0, zt + 2.4), (-7.0, zt + 1.7), (-6.5, zt + 1.3), (-7.4, zt + 0.7)]
    tr.add(xext(prof, -20, 20))
    for yy in (-1, 1):
        for i in range(15):
            c = -18.67 + i * 2.667
            tr.add(loft([[(c - 0.55, yy * 7.3 - 0.6, zt - 0.1), (c + 0.55, yy * 7.3 - 0.6, zt - 0.1), (c + 0.55, yy * 7.3 + 0.6, zt - 0.1), (c - 0.55, yy * 7.3 + 0.6, zt - 0.1)],
                         [(c - 0.3, yy * 6.6 - 0.3, zt - 2.4), (c + 0.3, yy * 6.6 - 0.3, zt - 2.4), (c + 0.3, yy * 6.6 + 0.3, zt - 2.4), (c - 0.3, yy * 6.6 + 0.3, zt - 2.4)]]))
    ztop = zt + 3.0
    for yy in (-5.4, 5.4):
        balustrade(pn, pn, -16.0, 16.0, ztop, yy, 7.0)
        for sx in (-1, 1):
            pinnacle(pn, S["Crockets"], sx * 18.0, yy, ztop, 3.0, 14.0, 1)


def bastion_face(S):
    st, tr, pn, cr = S["Stone"], S["Tracery"], S["Pinnacles"], S["Crockets"]
    yf = lambda i: -7.0 + 0.875 * i
    for i in range(8):
        z0, z1 = i * 10.0, i * 10.0 + 10.0
        st.add(xext([(7.0, z0), (yf(i), z0), (yf(i), z1 - 1.0), (yf(i + 1), z1), (7.0, z1)], -20, 20))
        tr.add(xext([(yf(i) - 0.5, z0 + 0.0), (yf(i), z0 + 0.0), (yf(i), z0 + 1.0), (yf(i) - 0.5, z0 + 0.7)], -20, 20)) if i else None
        for cx in (-13.3, 0.0, 13.3):
            a, zsb = 3.2, z0 + 3.0
            Rr = 2 * a
            for sgn_leg in (0,):
                tr.add(sweep(arch_ext(a, zsb, Rr, 0.0, z0 + 1.4, 7, cx), mould([("roll", 0.6, 0.6), ("cove", 0.5, 0.4)]), yf(i), -1))
            for sx in (-1, 1):
                q = arch(a, zsb, Rr, 0, 7)[2 if sx < 0 else -3]
                place_spear(tr, cx + q[0], yf(i) - 0.3, q[1], -sx * 0.5, -0.85, 0.9, 1.3, 0.6)
            tr.add(box(cx - a - 0.5, cx + a + 0.5, yf(i) - 0.7, yf(i), z0 + 1.1, z0 + 1.4))
        for px in (-6.65, 6.65, -19.2, 19.2):
            tr.add(box(px - 0.7, px + 0.7, yf(i) - 0.8, yf(i), z0 + 0.0, z1 - 1.0))
    ytop = yf(8)
    parapet_gothic(S, -20, 20, 80.0, ytop + 1.2)
    for px in (-18.5, -6.65, 6.65, 18.5):
        pinnacle(pn, cr, px, ytop + 1.2, 80.0 + 0.0, 2.4, 11.0, 1)


def balustrade_run(S, L, posts=True, z0=0.0):
    st, tr, pn, cr = S["Stone"], S["Tracery"], S["Pinnacles"], S["Crockets"]
    h = 7.0
    balustrade(st, tr, -L / 2 + 1.6, L / 2 - 1.6, z0, 0.0, h)
    for sx in (-1, 1):
        px = sx * (L / 2 - 0.8)
        st.add(box(px - 0.8, px + 0.8, -1.0, 1.0, z0, z0 + 8.6))
        st.add(box(px - 0.95, px + 0.95, -1.15, 1.15, z0 + 8.6, z0 + 9.2))
        pinnacle(pn, cr, px, 0, z0 + 9.2, 1.5, 6.0, 1)


def parapet_piece(S):
    parapet_gothic(S, -10, 10, 0.0, 0.0)


# ============================================================================================ GROUP B
def flying_buttress(S, L):
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    rise = 0.42 * L
    Ra = (L * L + rise * rise) / (2 * rise)
    thm = math.asin(min(1.0, L / Ra))
    m = 14
    intr = [(Ra * math.sin(thm * i / m), Ra * (1 - math.cos(thm * i / m))) for i in range(m + 1)]
    tlo, thi = 5.5, 7.0
    ramp = lambda x: tlo + (rise + thi - tlo) * x / L
    poly = intr + [(L, rise + thi), (0.0, tlo)]
    zi = lambda x: min(intr, key=lambda p: abs(p[0] - x))[1]
    holes, rings = [], []
    for u in (0.3, 0.5, 0.7):
        x = u * L
        zin = Ra * (1 - math.cos(math.asin(min(1.0, x / Ra))))
        r = 0.3 * (ramp(x) - zin)
        holes.append(circle(x, (zin + ramp(x)) / 2, r, 14))
        rings.append((x, (zin + ramp(x)) / 2, r))
    st.add(prism([poly] + holes, -2.5, 2.5))
    for sgn, y in ((-1, -2.5), (1, 2.5)):
        for x, zc, r in rings:
            foil(tr, x, zc, r + 0.4, 3, y, sgn, 0.7, 0.9)
        tr.add(sweep(intr, mould([("roll", 0.7, 0.7)]), y, sgn, flip=True))
    tr.add(prism([[(0.0, tlo), (L, rise + thi), (L, rise + thi + 1.1), (0.0, tlo + 1.1)]], -3.1, 3.1))
    for sy in (-1, 1):
        crockets(cr, (0.0, sy * 3.0, tlo + 1.1), (L, sy * 3.0, rise + thi + 1.1), (0, sy, 0.4), 2.0, 4.0, 0.06, 0.94, 0.3)
    st.add(box(L - 1.2, L + 3.5, -3.6, 3.6, rise + 2.0, rise + thi + 2.4))
    tr.add(box(-3.0, 0.8, -3.4, 3.4, 0.0, 1.2))
    S.shift(-L / 2)


def pinnacle_piece(S, w, h, lvl):
    pinnacle(S["Stone"], S["Crockets"], 0, 0, 0, w, h, lvl)


def finial_piece(S):
    S["Stone"].add(box(-1.6, 1.6, -1.6, 1.6, 0, 1.2))
    S["Stone"].add(frust(0, 0, 1.2, 1.3, 1.3, 3.2, 0.8, 0.8))
    finial(S["Crockets"], 0, 0, 3.2, 1.5)


# ============================================================================================ GROUP C
def facet_T(k, ap, n=8):
    return Rz(k * 2 * math.pi / n + math.pi / 2) @ Tr(0, -ap, 0)


def lancet_hole(a, sill, apex, k=1.1):
    Rr = 2 * a * k
    zs = apex - arch_h(a, Rr)
    return [(-a, sill)] + arch(a, zs, Rr, 0, 9) + [(a, sill)], zs, Rr


def gable(sub, cr, hw, z0, hgt, th, y, a=None, z_hole=None, crock_size=1.0, apex=None):
    """Gable face: triangle prism (optionally pierced by a pointed lancet) with crocketed rakes and apex finial. Local frame (x,z)."""
    loops = [[(-hw, z0), (hw, z0), (0, z0 + hgt)]]
    if a:
        hole, zs, Rr = lancet_hole(a, z_hole, apex if apex else z0 + hgt * 0.72)
        loops.append(hole)
    sub.add(prism(loops, y - th / 2, y + th / 2))
    for sx in (-1, 1):
        p0, p1 = (sx * hw, y, z0), (0, y, z0 + hgt)
        d = Vector((-sx * hw, 0, hgt))
        crockets(cr, p0, p1, (sx * hgt, 0, hw), crock_size, crock_size * 2.4, 0.1, 0.9)
    finial(cr, 0, y, z0 + hgt - 0.1, crock_size * 0.6)


def edge_rib(sub, p0, p1, w, radial):
    p0, p1, radial = Vector(p0), Vector(p1), Vector(radial)
    e = (p1 - p0).normalized()
    o = (radial - e * radial.dot(e)).normalized()
    t = e.cross(o)
    def ring(p, s):
        return [tuple(p + o * a * s + t * b * s) for a, b in ((0.5, 0.35), (0.5, -0.35), (-0.4, -0.35), (-0.4, 0.35))]
    sub.add(loft([ring(p0, w), ring(p1, w * 0.6)]))


def spire_needle_tip(S):
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    R0, R1, H = 5.4, 0.5, 52.0
    st.add(loft([ngon(0, 0, 0, R0), ngon(0, 0, H, R1)]))
    rad = lambda z: R0 + (R1 - R0) * z / H
    for k in range(8):
        th = k * math.pi / 4 + math.pi / 8
        p0, p1 = (R0 * math.cos(th), R0 * math.sin(th), 0.0), (R1 * math.cos(th), R1 * math.sin(th), H)
        crockets(cr, p0, p1, (math.cos(th), math.sin(th), 0.0), 1.2, 3.4, 0.06, 0.94, 0.55)
        edge_rib(tr, p0, p1, 0.9, (math.cos(th), math.sin(th), 0))
    for z in (10.0, 26.0, 40.0):
        r = rad(z)
        tr.add(loft([ngon(0, 0, z, r + 0.6), ngon(0, 0, z + 0.7, r + 0.6), ngon(0, 0, z + 1.3, r + 0.05)]))
    finial(cr, 0, 0, H - 0.5, 0.9)


def spire_broken_top(S):
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    rng = np.random.default_rng(5)
    R0, R1, H = 5.4, 3.8, 28.0
    st.add(loft([ngon(0, 0, 0, R0), ngon(0, 0, 14.0, R0 - 0.5)]))
    for k in range(8):
        th = k * math.pi / 4
        tops = [max(16.0, H - rng.uniform(1.0, 9.0) * (1 if k not in (2, 3) else 2.2)) for _ in range(5)]
        w0 = 2 * R0 * math.sin(math.pi / 8)
        w1 = w0 * (R1 / R0)
        poly = [(-w0 / 2, 14.0), (w0 / 2, 14.0)] + [((w1 / 2) * (1 - 2 * i / 4), tops[i]) for i in range(5)]
        ap = (R0 + R1) / 2 * math.cos(math.pi / 8) - 0.4
        st.add(prism([poly], -0.8, 0.8), Rz(th + math.pi / 2) @ Tr(0, -ap, 0))
    for k in (0, 1, 3, 5, 6):
        th = k * math.pi / 4 + math.pi / 8
        z1 = H - rng.uniform(0.5, 6.0)
        p0, p1 = (R0 * math.cos(th) * 0.95, R0 * math.sin(th) * 0.95, 14.0), (R1 * math.cos(th), R1 * math.sin(th), z1)
        edge_rib(tr, p0, p1, 1.2, (math.cos(th), math.sin(th), 0))
        crockets(cr, p0, p1, (math.cos(th), math.sin(th), 0.0), 1.3, 4.0, 0.1, 0.8, 0.5)
    tr.add(loft([ngon(0, 0, 13.4, R0 + 0.7), ngon(0, 0, 14.3, R0 + 0.7), ngon(0, 0, 15.0, R0 - 0.2)]))
    for i in range(6):
        a, r = rng.uniform(0, 6.28), rng.uniform(1.0, 3.2)
        st.add(frust(math.cos(a) * r, math.sin(a) * r, 13.9, rng.uniform(0.6, 1.2), rng.uniform(0.6, 1.2), 13.9 + rng.uniform(0.8, 2.4), 0.35, 0.4))


# ============================================================================================ GROUP D
def lancet_unit(S, cx, a, y0=-2.0, y1=2.0, z_sill=1.5, apex=41.5, wall=None):
    st, tr, gl = S["Stone"], S["Tracery"], S["Glass"]
    hole, zs, Rr = lancet_hole(a, z_sill, apex, 1.2)
    hole = [(cx + x, z) for x, z in hole]
    for sgn, y in ((-1, y0), (1, y1)):
        archivolt(tr, a, zs, Rr, [(0.0, [("roll", 0.7, 0.6), ("cove", 0.7, 0.5), ("roll", 1.2, 1.0)])], y, sgn, z0=z_sill, cx=cx, n=10, crock=(0.9, 2.3, 0.2))
    gl.add(prism([hole], 0.4, 0.7))
    head_tracery(tr, cx, zs, a, Rr, 0.0, 0.5, zs + 0.9)
    tr.add(box(cx - 0.25, cx + 0.25, -0.45, 0.45, z_sill, zs + 0.9))
    for zt_ in (zs * 0.34, zs * 0.66):
        tr.add(box(cx - a + 0.05, cx + a - 0.05, -0.4, 0.4, zt_, zt_ + 0.45))
    tr.add(xext([(y0 - 0.9, z_sill - 1.2), (y1 + 0.2, z_sill - 1.2), (y1 + 0.2, z_sill), (y0 - 0.9, z_sill - 0.4)], cx - a - 1.2, cx + a + 1.2))
    return hole


def lancet_tall(S):
    hole = lancet_unit(S, 0.0, 4.0)
    S["Stone"].add(prism([[(-7, 0), (7, 0), (7, 46), (-7, 46)], hole], -2.0, 2.0))
    S["Tracery"].add(box(-7.4, 7.4, -2.4, 2.4, 0.0, 0.5))


def lancet_pair(S):
    h1 = lancet_unit(S, -5.5, 4.0, apex=41.5)
    h2 = lancet_unit(S, 5.5, 4.0, apex=41.5)
    ah, Rh = 10.6, 21.2
    zsh = 41.5 - arch_h(4.0, 9.6)
    cz = 45.2
    circ = circle(0, cz, 3.2, 16)
    S["Stone"].add(prism([[(-13, 0), (13, 0), (13, 58), (-13, 58)], h1, h2, circ], -2.0, 2.0))
    S["Glass"].add(prism([circ], 0.4, 0.7))
    for sgn, y in ((-1, -2.0), (1, 2.0)):
        archivolt(S["Tracery"], ah, zsh, Rh, [(0.0, [("roll", 0.8, 0.7), ("cove", 0.7, 0.5), ("roll", 1.4, 1.1)])], y, sgn, z0=1.5, n=12, crock=(1.2, 2.8, 0.2))
        foil(S["Tracery"], 0, cz, 3.7, 5, y, sgn, 0.7, 0.9)
    foil(S["Tracery"], 0, cz, 3.0, 4, 0.0, 1.0, 0.45, 0.8, True)
    S["Tracery"].add(box(-7.4, 7.4, -2.4, 2.4, 0.0, 0.5))


def rose(T, G, cx, cz, R, n, y=0.0):
    bw, h = max(0.5, R * 0.022), max(0.9, R * 0.04)
    r1, r2, r3 = R * 0.94, R * 0.60, R * 0.20
    for r, wd in ((r1, bw * 3.2), (r2, bw * 2.2), (r3, bw * 2.4)):
        T.add(sweep(circle(cx, cz, r, max(36, n * 4)), barf(wd, h * 1.2), y, -1, closed=True))

    def petals(r_in, r_out, m, with_foil):
        bh = r_in * math.sin(math.pi / m) - bw * 1.1
        rs = r_in * math.cos(math.pi / m)
        rise = r_out - rs
        Rr = max(bh * 1.02, (rise * rise + bh * bh) / (2 * bh))
        ar = arch(bh, 0.0, Rr, 0, 7)
        for k in range(m):
            ph = 2 * math.pi * (k + 0.5) / m
            c, s = math.cos(ph), math.sin(ph)
            pts = [(cx + (rs + v) * c - u * s, cz + (rs + v) * s + u * c) for u, v in ar]
            T.add(sweep(pts, barf(bw * 1.4, h), y, -1))
            if with_foil:
                rr = bh * 0.55
                rc = rs + 0.42 * rise
                foil(T, cx + rc * c, cz + rc * s, rr, 3, y, -1, bw * 0.9, h * 0.9)
            ang = 2 * math.pi * k / m
            ca, sa = math.cos(ang), math.sin(ang)
            T.add(box(-bw * 0.45, bw * 0.45, y - h, y, r_in * math.cos(math.pi / m) * 0.9, r_out), Tr(cx, 0, cz) @ Ry(math.atan2(ca, sa)))

    petals(r2 + bw, r1 - bw * 1.4, n, True)
    petals(r3 + bw, r2 - bw, max(4, n // 2), False)
    foil(T, cx, cz, r3 - bw * 1.4, 8, y, -1, bw * 0.9, h)
    G.add(prism([circle(cx, cz, r1 + bw, 72)], y + 0.15, y + 0.5))


def rose_unit(S, R, W, Hh):
    cz = Hh / 2
    circ = circle(0, cz, R, 72)
    S["Stone"].add(prism([[(-W / 2, 0), (W / 2, 0), (W / 2, Hh), (-W / 2, Hh)], circ], -4.0, 4.0))
    for sgn, y in ((-1, -4.0), (1, 4.0)):
        S["Tracery"].add(sweep(circle(0, cz, R, 72), mould([("roll", R * 0.03 + 0.4, R * 0.03 + 0.4), ("cove", R * 0.025 + 0.3, R * 0.02 + 0.3), ("roll", R * 0.05 + 0.6, R * 0.05 + 0.5), ("flat", R * 0.03 + 0.3, 0.4)]), y, sgn, closed=True, flip=True))
    rose(S["Tracery"], S["Glass"], 0.0, cz, R, 16 if R > 12 else 8)


def rose_great(S):
    rose_unit(S, 24.0, 56.0, 56.0)
    for sx in (-1, 1):
        pinnacle(S["Pinnacles"], S["Crockets"], sx * 25.0, 0.0, 56.0, 4.0, 18.0, 2)


def rose_small(S):
    rose_unit(S, 8.0, 20.0, 20.0)
    for sx in (-1, 1):
        pinnacle(S["Pinnacles"], S["Crockets"], sx * 9.0, 0.0, 20.0, 2.0, 8.0, 1)


# ============================================================================================ GROUP E
def viaduct_balustrade(S):
    L = 30.0
    st, tr, pn, cr = S["Stone"], S["Tracery"], S["Pinnacles"], S["Crockets"]
    balustrade(st, tr, -L / 2 + 1.5, L / 2 - 1.5, 0.0, 0.0, 7.5, 1.4, 1.8)
    for sx in (-1, 1):
        px = sx * (L / 2 - 0.75)
        st.add(box(px - 0.75, px + 0.75, -1.1, 1.1, 0.0, 9.2))
        st.add(box(px - 0.9, px + 0.9, -1.25, 1.25, 9.2, 9.8))
        pinnacle(pn, cr, px, 0, 9.8, 1.4, 6.0, 1)
    st.add(box(-1.1, 1.1, -1.2, 1.2, 0.0, 9.0))
    st.add(box(-1.4, 1.4, -1.5, 1.5, 9.0, 9.7))
    pinnacle(pn, cr, 0, 0, 9.7, 2.2, 9.0, 1)


# ---- clean rebuilds of the composite pieces (use local() frames)
def local(S, T, fn):
    """Build fn(L) in a local frame and add the result to S transformed by T."""
    L = Subs()
    fn(L)
    for k, s in L.items():
        for vs, fs in s.prims:
            S[k].prims.append(([tuple(T @ Vector(p)) for p in vs], fs))


def half_w(z, a, zs, Rr):
    return a if z <= zs else -(-a + Rr - math.sqrt(max(Rr * Rr - (z - zs) ** 2, 0.0)))


def arcade_corner(S):
    """Corner turret pier: octagonal shaft, blind lancet faces, vertex shafts, machicolated top, pierced balustrade, pinnacle cluster."""
    st, tr, pn, cr = S["Stone"], S["Tracery"], S["Pinnacles"], S["Crockets"]
    zt, R = 72.0, 9.6
    ap, sw = R * math.cos(math.pi / 8), R * math.sin(math.pi / 8)
    st.add(loft([ngon(0, 0, 0, 12.4), ngon(0, 0, 2.6, 12.0)]))
    st.add(loft([ngon(0, 0, 2.6, 11.2), ngon(0, 0, 4.2, 10.6)]))
    st.add(loft([ngon(0, 0, 4.2, R), ngon(0, 0, zt, R)]))
    hole, zsa, Ra = lancet_hole(1.8, 8.0, 44.0, 1.2)

    def face(L):
        L["Stone"].add(prism([[(-sw - 0.2, 5.0), (sw + 0.2, 5.0), (sw + 0.2, zt - 3.0), (-sw - 0.2, zt - 3.0)], hole], -0.9, 0.0))
        archivolt(L["Tracery"], 1.8, zsa, Ra, [(0.0, [("roll", 0.6, 0.6), ("cove", 0.5, 0.4), ("roll", 0.8, 0.8)])], -0.9, -1, z0=8.0, n=8)
        L["Tracery"].add(box(-2.4, 2.4, -1.3, 0.0, 7.2, 8.0))
        head_tracery(L["Tracery"], 0.0, zsa, 1.8, Ra, -0.45, 0.35, zsa + 0.8)
        L["Tracery"].add(box(-0.18, 0.18, -0.7, -0.2, 8.0, zsa + 0.8))
    for k in range(8):
        local(S, facet_T(k, ap), face)
        th = k * math.pi / 4 + math.pi / 8
        colonnette(st, R * math.cos(th), R * math.sin(th), 4.2, zt - 2.0, 0.95, 8)
    for z in (32.0, zt - 12.0):
        tr.add(loft([ngon(0, 0, z, 9.9), ngon(0, 0, z + 1.2, 10.3), ngon(0, 0, z + 2.3, 9.7)]))
    tr.add(loft([ngon(0, 0, zt, 10.2), ngon(0, 0, zt + 1.2, 11.5), ngon(0, 0, zt + 2.6, 11.7), ngon(0, 0, zt + 3.2, 10.8)]))
    for k in range(16):
        th = k * math.pi / 8
        tr.add(loft([rect(0, 0, 0.0, 0.3, 0.3), rect(0, 0, 1.8, 0.7, 0.9)]), Tr(math.cos(th) * 10.0, math.sin(th) * 10.0, zt - 1.8) @ Rz(th))
    ztp = zt + 3.2
    for k in range(8):
        local(S, facet_T(k, 10.4), lambda L: balustrade(L["Pinnacles"], L["Pinnacles"], -3.8, 3.8, ztp, 0.0, 7.0))
        th = k * math.pi / 4 + math.pi / 8
        pinnacle(pn, cr, 11.0 * math.cos(th), 11.0 * math.sin(th), ztp, 2.4, 12.0, 1)
    pinnacle(pn, cr, 0, 0, ztp, 6.0, 30.0, 3)


def cornice_piece(S):
    st, tr = S["Stone"], S["Tracery"]
    st.add(xext([(0.0, 0.0), (2.6, 0.0), (2.6, 8.4), (0.0, 8.4)], -10, 10))
    arcs = []
    for i in range(8):
        c = -8.75 + i * 2.5
        arcs.append([(c - 0.95, 0.6)] + [(c + x, z) for x, z in arch(0.95, 2.1, 1.9, 0, 5)] + [(c + 0.95, 0.6)])
    st.add(prism([[(-10, 0.0), (10, 0.0), (10, 4.0), (-10, 4.0)]] + arcs, -1.6, 0.0))
    tr.add(xext([(-1.9, 4.0), (2.6, 4.0), (2.6, 4.7), (-2.1, 4.7)], -10, 10))
    for i in range(8):
        c = -8.75 + i * 2.5
        tr.add(loft([[(c - 0.3, -0.9, 4.7), (c + 0.3, -0.9, 4.7), (c + 0.3, -0.4, 4.7), (c - 0.3, -0.4, 4.7)],
                     [(c - 0.9, -2.2, 6.6), (c + 0.9, -2.2, 6.6), (c + 0.9, 0.4, 6.6), (c - 0.9, 0.4, 6.6)]]))
    tr.add(xext([(-2.7, 6.6), (2.6, 6.6), (2.6, 8.4), (-1.0, 8.4), (-2.7, 7.4)], -10, 10))
    for i in range(20):
        c = -9.5 + i
        tr.add(box(c - 0.3, c + 0.3, -2.95, -2.7, 6.7, 7.3))


def spire_base_oct(S):
    st, tr, cr, pn = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"]
    st.add(frust(0, 0, 0, 14.0, 14.0, 4.0, 14.0, 14.0))
    C = [(14.0 * sx, 14.0 * sy, 4.0) for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    V = [(12.0 * math.cos(math.radians(22.5 + 45 * k)), 12.0 * math.sin(math.radians(22.5 + 45 * k)), 26.0) for k in range(8)]
    vs = C + V
    fs = [(0, 4, 5), (1, 6, 7), (2, 8, 9), (3, 10, 11), (3, 0, 4, 11), (0, 1, 6, 5), (1, 2, 8, 7), (2, 3, 10, 9),
          (0, 1, 2, 3), tuple(range(4, 12))]
    st.add((vs, fs))
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        pinnacle(pn, cr, sx * 12.2, sy * 12.2, 4.0, 3.2, 22.0, 2)
    tr.add(loft([rect(0, 0, 0.0, 14.4, 14.4), rect(0, 0, 1.0, 14.4, 14.4), rect(0, 0, 1.8, 14.0, 14.0)]))
    for ci, (cx_, cy_, cz_) in enumerate(C):
        for vi in (4 + 2 * ci, 5 + 2 * ci):
            vx, vy, vz = V[vi - 4]
            crockets(cr, (cx_, cy_, cz_), (vx, vy, vz), (cx_, cy_, 0.0), 1.8, 4.2, 0.12, 0.9, 0.3)
    for k in range(4):
        local(S, Rz(k * math.pi / 2), lambda L: gable(L["Tracery"], L["Crockets"], 4.4, 4.0, 9.0, 1.3, -14.3, crock_size=0.8))


def spire_belfry_stage(S):
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    R = 12.0
    ap, sw = R * math.cos(math.pi / 8), R * math.sin(math.pi / 8)
    st.add(loft([ngon(0, 0, 0, 12.6), ngon(0, 0, 3.0, 12.6)]))
    st.add(loft([ngon(0, 0, 3.0, 8.0), ngon(0, 0, 31.0, 8.0)]))  # central pier: the lancets are genuinely open onto it
    st.add(loft([ngon(0, 0, 28.5, 10.8), ngon(0, 0, 31.0, 10.8)]))
    hole, zs, Rr = lancet_hole(2.8, 8.0, 28.0)

    def face(L):
        L["Stone"].add(prism([[(-sw - 0.2, 3.0), (sw + 0.2, 3.0), (sw + 0.2, 31.0), (-sw - 0.2, 31.0)], hole], -1.2, 1.2))
        archivolt(L["Tracery"], 2.8, zs, Rr, [(0.0, [("roll", 0.6, 0.6), ("cove", 0.5, 0.4), ("roll", 0.8, 0.8)])], -1.2, -1, z0=8.0, n=9)
        head_tracery(L["Tracery"], 0.0, zs, 2.8, Rr, 0.0, 0.45, zs + 1.0)
        L["Tracery"].add(box(-0.22, 0.22, -0.4, 0.4, 8.0, zs + 1.0))
        L["Tracery"].add(box(-3.5, 3.5, -2.0, -1.0, 7.3, 8.0))
        gable(L["Tracery"], L["Crockets"], sw * 0.95, 31.0, 7.0, 1.4, -1.9, a=1.5, z_hole=33.0, crock_size=0.8)
    for k in range(8):
        local(S, facet_T(k, ap), face)
        th = k * math.pi / 4 + math.pi / 8
        colonnette(st, R * math.cos(th), R * math.sin(th), 3.0, 31.0, 0.95, 8)
    tr.add(loft([ngon(0, 0, 31.0, 11.6), ngon(0, 0, 31.4, 12.8), ngon(0, 0, 33.4, 12.9), ngon(0, 0, 34.0, 12.2), ngon(0, 0, 36.0, 11.4)]))
    tr.add(loft([ngon(0, 0, 3.0, 12.9), ngon(0, 0, 4.0, 12.9), ngon(0, 0, 4.8, 12.2)]))


def spire_lucarne_mid(S):
    st, tr, cr, rf = S["Stone"], S["Tracery"], S["Crockets"], S["Roof"]
    R0, R1, H = 11.4, 5.4, 44.0
    rf.add(loft([ngon(0, 0, 0, R0), ngon(0, 0, H, R1)]))
    rad = lambda z: R0 + (R1 - R0) * z / H
    for k in range(8):
        th = k * math.pi / 4 + math.pi / 8
        p0, p1 = (R0 * math.cos(th), R0 * math.sin(th), 0.0), (R1 * math.cos(th), R1 * math.sin(th), H)
        edge_rib(st, p0, p1, 1.5, (math.cos(th), math.sin(th), 0))
        crockets(cr, p0, p1, (math.cos(th), math.sin(th), 0.0), 1.7, 4.4, 0.08, 0.92, 0.5)
    for z in (14.0, 28.0):
        r = rad(z)
        tr.add(loft([ngon(0, 0, z, r + 0.9), ngon(0, 0, z + 0.9, r + 0.9), ngon(0, 0, z + 1.7, r + 0.05)]))
    hole, zs, Rr = lancet_hole(1.0, 1.2, 5.0, 1.2)

    def dormer(L):
        L["Stone"].add(box(-2.2, 2.2, -2.6, 2.6, 0, 6.0))
        L["Stone"].add(prism([[(-2.2, 0), (2.2, 0), (2.2, 6.0), (-2.2, 6.0)], hole], -3.3, -2.6))
        L["Roof"].add(prism([[(-2.5, 6.0), (2.5, 6.0), (0, 10.0)]], -3.2, 2.0))
        gable(L["Tracery"], L["Crockets"], 2.5, 6.0, 4.0, 0.9, -3.5, crock_size=0.55)
    for k in range(8):
        z0 = 8.0 if k % 2 == 0 else 24.0
        local(S, Rz(k * math.pi / 4 + math.pi / 2) @ Tr(0, -(rad(z0) * math.cos(math.pi / 8) + 2.0), z0), dormer)


def tower_stage(S):
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    st.add(frust(0, 0, 0, 14.0, 14.0, 3.0, 14.0, 14.0))
    st.add(frust(0, 0, 3.0, 13.0, 13.0, 55.0, 12.7, 12.7))
    hl, zs, Rr = lancet_hole(2.4, 14.0, 46.0)

    def face(L):
        holes = []
        for cx in (-6.2, 6.2):
            holes.append([(cx + x, z) for x, z in hl])
            archivolt(L["Tracery"], 2.4, zs, Rr, [(0.0, [("roll", 0.6, 0.6), ("cove", 0.5, 0.4), ("roll", 0.8, 0.8)])], -14.2, -1, z0=14.0, cx=cx, n=9)
            head_tracery(L["Tracery"], cx, zs, 2.4, Rr, -13.6, 0.4, zs + 0.8)
            L["Tracery"].add(box(cx - 0.2, cx + 0.2, -13.9, -13.3, 14.0, zs + 0.8))
            L["Tracery"].add(box(cx - 3.0, cx + 3.0, -14.9, -13.0, 13.2, 14.0))
        L["Stone"].add(prism([[(-12.4, 3.0), (12.4, 3.0), (12.4, 55.0), (-12.4, 55.0)]] + holes, -14.2, -13.0))
        L["Tracery"].add(box(-1.0, 1.0, -14.5, -13.0, 6.0, 50.0))
        for i in range(10):
            L["Tracery"].add(loft([rect(-12.6 + i * 2.8, -14.0, 55.2, 0.3, 0.3), rect(-12.6 + i * 2.8, -14.0, 57.4, 0.55, 0.85)]))
    for k in range(4):
        local(S, Rz(k * math.pi / 2), face)
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        for z, hw, h in ((0.0, 3.4, 20.0), (20.0, 2.8, 20.0), (40.0, 2.1, 15.0)):
            st.add(box(sx * 13.6 - hw / 2, sx * 13.6 + hw / 2, sy * 13.6 - hw / 2, sy * 13.6 + hw / 2, z, z + h))
            tr.add(frust(sx * 13.6, sy * 13.6, z + h, hw / 2, hw / 2, z + h + 1.2, hw / 2 - 0.45, hw / 2 - 0.45))
    tr.add(loft([rect(0, 0, 29.0, 14.2, 14.2), rect(0, 0, 30.2, 14.2, 14.2), rect(0, 0, 31.0, 13.2, 13.2)]))
    tr.add(loft([rect(0, 0, 55.0, 13.4, 13.4), rect(0, 0, 56.0, 14.8, 14.8), rect(0, 0, 58.4, 14.8, 14.8), rect(0, 0, 60.0, 14.2, 14.2)]))


def buttress_pier(S):
    st, tr, cr, pn = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"]
    z = 0.0
    for j, h in enumerate([13, 12, 11, 10, 8]):
        hw, yf = 6.0 - 0.55 * j, -18.0 + 3.2 * j
        z1 = z + h
        st.add(box(-hw, hw, yf, 6.0, z, z1))
        if j < 4:
            yn = -18.0 + 3.2 * (j + 1)
            tr.add(xext([(yf, z1), (yn, z1), (yn, z1 + 1.3)], -hw, hw))
        a = hw * 0.42
        sill, zs = z + 2.6, z + 1.5 + 0.35 * (h - 3) + 1.4
        hole = [(-a, sill)] + arch(a, zs, 2 * a, 0, 7) + [(a, sill)]
        tr.add(prism([[(-hw + 0.5, z + 1.5), (hw - 0.5, z + 1.5), (hw - 0.5, z1 - 1.5), (-hw + 0.5, z1 - 1.5)], hole], yf - 0.5, yf))
        archivolt(tr, a, zs, 2 * a, [(0.0, [("roll", 0.5, 0.5)])], yf - 0.5, -1, z0=sill, n=7)
        if j < 3:
            for sx in (-1, 1):
                colonnette(st, sx * (hw - 0.3), yf + 0.1, z, z1 - 0.2, 0.55, 6)
        if j:
            tr.add(xext([(yf - 0.4, z), (yf, z), (yf, z + 0.9), (yf - 0.4, z + 0.6)], -hw, hw))
        z = z1
    pinnacle(pn, cr, 0.0, 0.4, z, 4.4, 16.0, 3)


def portal_great(S):
    st, tr, cr, pn, gl = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"], S["Glass"]
    a, Rr = 7.0, 15.4
    zs = 28.0 - arch_h(a, Rr)
    for i in range(6):  # 5 receding orders (front widest) + the door passage
        d = 3.4 * (4 - i) if i < 5 else 0.0
        y0 = -10.0 + 2.0 * i if i < 5 else 0.0
        ar = arch(a, zs, Rr, d, 12)
        st.add(prism([[(-28, 0), (-28, 44), (28, 44), (28, 0), (a + d, 0)] + ar[::-1] + [(-(a + d), 0)]], y0, y0 + 2.0 if i < 5 else 10.0))
    for i in range(4):  # jamb shafts + archivolt rolls on the four steps
        dc = 3.4 * (3 - i) + 1.7
        yc = -10.0 + 2.0 * (i + 1) - 0.45
        for sx in (-1, 1):
            colonnette(st, sx * (a + dc), yc, 0.0, zs, 0.9, 10)
        tr.add(sweep(arch(a, zs, Rr, dc, 12), [(0.9 * math.cos(2 * math.pi * q / 10), 0.9 * math.sin(2 * math.pi * q / 10)) for q in range(10)], yc, 1.0))
    archivolt(tr, a, zs, Rr, [(13.6, [("roll", 1.0, 0.9), ("cove", 0.8, 0.6), ("roll", 1.6, 1.4), ("flat", 1.0, 0.6)])], -10.0, -1, z0=0.0, n=14, crock=(2.4, 4.6, 0.3))
    tr.add(xext([(-10.9, 44.0), (-5.5, 44.0), (-5.5, 45.6), (-10.4, 45.6), (-10.9, 44.8)], -28, 28))
    tr.add(xext([(-10.9, 0.0), (-7.0, 0.0), (-7.0, 3.0), (-10.4, 3.0)], -28, 28))
    st.add(prism([[(-28, 44), (28, 44), (0, 86)]], -6.0, -3.0))
    gable(tr, cr, 28.0, 44.0, 42.0, 3.0, -8.5, a=5.5, z_hole=50.0, crock_size=2.6, apex=74.0)
    gh, gzs, gR = lancet_hole(5.5, 50.0, 74.0)
    gl.add(prism([gh], -8.9, -8.6))
    archivolt(tr, 5.5, gzs, gR, [(0.0, [("roll", 0.8, 0.7), ("cove", 0.6, 0.5), ("roll", 1.2, 1.1)])], -10.0, -1, z0=50.0, n=10)
    head_tracery(tr, 0.0, gzs, 5.5, gR, -8.7, 0.6, gzs + 1.0)
    for sx in (-1, 1):
        pinnacle(pn, cr, sx * 27.0, -7.0, 44.0, 5.0, 34.0, 2)


def portcullis(S):
    ir = S["Iron"]
    a, Rr = 6.7, 14.7
    zs = 27.4 - arch_h(a, Rr)
    ir.add(sweep(arch_ext(a, zs, Rr, 0.0, 0.0, 12), barc(1.2, 1.6), 0.0, 1.0))
    xs = [-a + 0.8 + i * (2 * a - 1.6) / 8 for i in range(9)]
    for x in xs:
        ir.add(box(x - 0.35, x + 0.35, -0.7, 0.7, 1.8, min(archz(x, a, zs, Rr, 0.0) - 0.5, 27.0)))
        ir.add(pyr(x, 0.0, 1.8, 0.35, 0.7, 0.0))
    for zh in (3.0, 8.0, 13.0, 18.0, 23.0):
        hw = half_w(zh, a, zs, Rr) - 0.3
        ir.add(box(-hw, hw, -0.45, 0.45, zh - 0.35, zh + 0.35))
        for x in xs:
            if abs(x) < hw:
                ir.add(frust(x, -0.7, zh - 0.3, 0.45, 0.2, zh + 0.3, 0.2, 0.05))


def door_iron(S):
    ir = S["Iron"]
    a, Rr = 6.9, 15.2
    zs = 27.6 - arch_h(a, Rr)
    ar = arch(a, zs, Rr, 0, 12)
    lf = [(-a, 0.0)] + ar[:12] + [(0.0, 0.0)]
    for sx in (-1, 1):
        ir.add(prism([[(min(x, -0.04) if sx < 0 else max(-x, 0.04), z) for x, z in lf]], -0.6, 0.6))
        for zh in (4.0, 12.0, 20.0):
            hw = half_w(zh, a, zs, Rr) - 0.4
            x0, x1 = (-hw, -0.4) if sx < 0 else (0.4, hw)
            ir.add(box(x0, x1, -0.95, -0.55, zh - 0.5, zh + 0.5))
            for i in range(int((x1 - x0) // 1.2)):
                ir.add(frust(x0 + 0.7 + i * 1.2, -0.95, zh - 0.15, 0.25, 0.25, zh + 0.25, 0.1, 0.1))
        for q in range(1, 7):
            xq = sx * (0.5 + q * (a - 0.7) / 7)
            ir.add(box(xq - 0.08, xq + 0.08, -0.65, -0.58, 0.3, min(archz(xq, a, zs, Rr, 0.0) - 0.8, 27.0)))
        ir.add(sweep(circle(sx * 1.3, 14.0, 0.9, 14), [(-0.18, -0.18), (0.18, -0.18), (0.18, 0.18), (-0.18, 0.18)], -1.2, 1.0, closed=True))
    ir.add(box(-0.4, 0.4, -0.95, 0.95, 0.2, zs + 3.0))
    ir.add(sweep(arch_ext(a, zs, Rr, 0.0, 0.0, 12), barc(0.9, 2.0), 0.0, 1.0))


def viaduct_bay(S):
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    a, Rr, zs, zdk = 12.0, 24.0, 88.0, 116.0
    ar = arch(a, zs, Rr, 0, 14)
    st.add(prism([[(-15, zs - 8), (-15, zdk), (15, zdk), (15, zs - 8), (a, zs - 8)] + ar[::-1] + [(-a, zs - 8)]], -5.0, 5.0))
    for sx in (-1, 1):
        st.add(loft([[(sx * 15.0, -7.0, 0), (sx * 10.0, -7.0, 0), (sx * 10.0, 7.0, 0), (sx * 15.0, 7.0, 0)],
                     [(sx * 15.0, -6.2, 40), (sx * 11.6, -6.2, 40), (sx * 11.6, 6.2, 40), (sx * 15.0, 6.2, 40)],
                     [(sx * 15.0, -5.6, 80), (sx * 12.0, -5.6, 80), (sx * 12.0, 5.6, 80), (sx * 15.0, 5.6, 80)]]))
        for yy in (-1, 1):  # half cutwater (the neighbour bay mirrors it); tip tapers to the pier face at z=60
            st.add(loft([[(sx * 10.0, yy * 7.0, 0), (sx * 15.0, yy * 7.0, 0), (sx * 15.0, yy * 14.5, 0)],
                         [(sx * 11.6, yy * 6.2, 40), (sx * 15.0, yy * 6.2, 40), (sx * 15.0, yy * 10.2, 40)],
                         [(sx * 11.4, yy * 5.8, 60), (sx * 15.0, yy * 5.8, 60), (sx * 15.0, yy * 5.95, 60)]]))
            tr.add(box(min(sx * 13.4, sx * 15.0), max(sx * 13.4, sx * 15.0), min(yy * 5.0, yy * 5.9), max(yy * 5.0, yy * 5.9), 80.0, zdk))
        tr.add(bxm(sx, 11.2, 15.0, -5.6, 5.6, zs - 1.6, zs))
    for sgn, y in ((-1, -5.0), (1, 5.0)):
        archivolt(tr, a, zs, Rr, [(0.0, [("roll", 0.8, 0.8), ("cove", 0.6, 0.6), ("roll", 1.2, 1.1)]), (2.6, [("flat", 0.4, 0.4)])], y, sgn, n=14, crock=(1.4, 3.4, 0.3))
        for sx in (-1, 1):
            xq = sx * 12.8
            za = archz(xq, a, zs, Rr, 3.0)
            rq = min(4.4, (zdk - za) / 2 - 1.3)
            if rq > 1.5:
                foil(tr, xq, (za + zdk) / 2, rq, 4, y, sgn, 0.8, 1.0)
    for yy in (-3.6, 0.0, 3.6):  # soffit ribs
        tr.add(sweep(arch(a, zs, Rr, 0.0, 14), [(-0.3, -0.7), (0.5, -0.7), (0.95, -0.35), (0.95, 0.35), (0.5, 0.7), (-0.3, 0.7)], yy, 1.0, flip=True))
    tr.add(xext([(-7.6, zdk), (7.6, zdk), (7.6, zdk + 1.0), (6.4, zdk + 1.7), (7.0, zdk + 2.2), (7.0, zdk + 3.4), (6.0, zdk + 4.0), (-6.0, zdk + 4.0),
                 (-7.0, zdk + 3.4), (-7.0, zdk + 2.2), (-6.4, zdk + 1.7), (-7.6, zdk + 1.0)], -15, 15))
    for yy in (-1, 1):
        for i in range(11):
            c = -13.5 + i * 2.7
            tr.add(loft([[(c - 0.6, yy * 7.0 - 0.6, zdk), (c + 0.6, yy * 7.0 - 0.6, zdk), (c + 0.6, yy * 7.0 + 0.6, zdk), (c - 0.6, yy * 7.0 + 0.6, zdk)],
                         [(c - 0.3, yy * 6.0 - 0.3, zdk - 2.4), (c + 0.3, yy * 6.0 - 0.3, zdk - 2.4), (c + 0.3, yy * 6.0 + 0.3, zdk - 2.4), (c - 0.3, yy * 6.0 + 0.3, zdk - 2.4)]]))


def statue_plinth(S):
    st, tr = S["Stone"], S["Tracery"]
    st.add(frust(0, 0, 0, 4.6, 4.6, 1.6, 4.6, 4.6))
    tr.add(loft([rect(0, 0, 1.6, 4.6, 4.6), rect(0, 0, 2.2, 4.0, 4.0), rect(0, 0, 3.0, 3.8, 3.8)]))
    st.add(frust(0, 0, 3.0, 3.5, 3.5, 9.6, 3.4, 3.4))
    hole = [(-1.5, 4.6)] + arch(1.5, 6.6, 3.0, 0, 7) + [(1.5, 4.6)]
    for k in range(4):
        tr.add(prism([[(-2.7, 3.6), (2.7, 3.6), (2.7, 9.0), (-2.7, 9.0)], hole], -3.9, -3.4), Rz(k * math.pi / 2))
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        colonnette(st, sx * 3.45, sy * 3.45, 3.0, 9.6, 0.45, 6)
    tr.add(loft([rect(0, 0, 9.6, 3.8, 3.8), rect(0, 0, 10.2, 4.4, 4.4), rect(0, 0, 11.2, 4.5, 4.5), rect(0, 0, 11.9, 3.7, 3.7)]))


# ============================================================================================ build / export
PLAN = [
    ("Arcade_Bay_60", "A", lambda S: bay(S, 60.0)), ("Arcade_Bay_50", "A", lambda S: bay(S, 50.0)), ("Arcade_Bay_40", "A", lambda S: bay(S, 40.0)),
    ("Arcade_Corner", "A", arcade_corner), ("Bastion_Face", "A", bastion_face), ("Balustrade_20", "A", lambda S: balustrade_run(S, 20.0)),
    ("Parapet_Gothic_20", "A", parapet_piece), ("Cornice_20", "A", cornice_piece),
    ("Buttress_Pier", "B", buttress_pier), ("Flying_Buttress_40", "B", lambda S: flying_buttress(S, 40.0)),
    ("Flying_Buttress_60", "B", lambda S: flying_buttress(S, 60.0)), ("Pinnacle_Crocket_S", "B", lambda S: pinnacle_piece(S, 3.2, 12.0, 1)),
    ("Pinnacle_Crocket_M", "B", lambda S: pinnacle_piece(S, 6.0, 24.0, 2)), ("Pinnacle_Crocket_L", "B", lambda S: pinnacle_piece(S, 9.0, 40.0, 3)),
    ("Finial", "B", finial_piece),
    ("Spire_Base_Oct", "C", spire_base_oct), ("Spire_Belfry_Stage", "C", spire_belfry_stage), ("Spire_Lucarne_Mid", "C", spire_lucarne_mid),
    ("Spire_Needle_Tip", "C", spire_needle_tip), ("Spire_Broken_Top", "C", spire_broken_top), ("Tower_Corner_Stage", "C", tower_stage),
    ("Lancet_Tall", "D", lancet_tall), ("Lancet_Pair", "D", lancet_pair), ("Rose_Window_Great", "D", rose_great),
    ("Rose_Window_Small", "D", rose_small), ("Portal_Great", "D", portal_great), ("Portcullis", "D", portcullis), ("Door_Iron", "D", door_iron),
    ("Viaduct_Bay", "E", viaduct_bay), ("Viaduct_Balustrade_30", "E", viaduct_balustrade), ("Statue_Plinth", "E", statue_plinth),
]
STACK = {"Tower_Corner_Stage": {"h": 60.0, "bottom": "square 28 (plinth 28)", "top": "square 28 flat"},
         "Spire_Base_Oct": {"h": 26.0, "bottom": "square 28", "top": "octagon R12 (vertices at 22.5+k*45 deg)"},
         "Spire_Belfry_Stage": {"h": 36.0, "bottom": "octagon R12", "top": "octagon R11.4"},
         "Spire_Lucarne_Mid": {"h": 44.0, "bottom": "octagon R11.4", "top": "octagon R5.4"},
         "Spire_Needle_Tip": {"h": 52.0, "bottom": "octagon R5.4", "top": "point"},
         "Spire_Broken_Top": {"h": 28.0, "bottom": "octagon R5.4", "top": "broken"}}


def commit(sub):
    bm = bmesh.new()
    for vs, fs in sub.prims:
        bv = [bm.verts.new(p) for p in vs]
        for f in fs:
            idx = list(dict.fromkeys(f))
            if len(idx) < 3:
                continue
            try:
                bm.faces.new([bv[i] for i in idx])
            except ValueError:
                pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    out = [([tuple(v.co) for v in f.verts], tuple(f.normal), f.calc_area()) for f in bm.faces]
    bm.free()
    return out


def chunks(faces):
    tri = lambda f: len(f[0]) - 2
    tot = sum(tri(f) for f in faces)
    if tot <= SPLIT_AT:
        return [faces]
    k = -(-tot // SPLIT_AT)
    cs = [tuple(sum(c[i] for c in f[0]) / len(f[0]) for i in range(3)) for f in faces]
    ax = max(range(3), key=lambda i: max(c[i] for c in cs) - min(c[i] for c in cs))
    order = sorted(range(len(faces)), key=lambda i: cs[i][ax])
    out, cur, n = [], [], 0
    for i in order:
        cur.append(faces[i])
        n += tri(faces[i])
        if n >= tot / k and len(out) < k - 1:
            out.append(cur)
            cur, n = [], 0
    out.append(cur)
    return out


def make_obj(name, mat, faces):
    tile = TILE[mat]
    verts, polys, uvs = [], [], []
    for co, nrm, _ in faces:
        b = len(verts)
        verts += co
        polys.append(tuple(range(b, b + len(co))))
        ax, ay, az = abs(nrm[0]), abs(nrm[1]), abs(nrm[2])
        for c in co:
            u, v = (c[0], c[1]) if (az >= ax and az >= ay) else ((c[1], c[2]) if ax >= ay else (c[0], c[2]))
            uvs += (u / tile, v / tile)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], polys)
    me.update()
    me.uv_layers.new(name="UVMap").data.foreach_set("uv", uvs)
    me.materials.append(MATS[mat])
    me.shade_flat()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.calc_loop_triangles()
    tris = len(me.loop_triangles)
    assert tris < TRI_CAP, (name, tris)
    return o, tris


def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))), Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))


def finish(name, group, S):
    data = {}
    for sname, sub in list(S.items()):
        if sname != "Frost" and sub.prims:
            data[sname] = commit(sub)
    frost = []
    for sname, faces in data.items():
        if sname in NOFROST:
            continue
        for co, nrm, area in faces:
            if nrm[2] >= 0.6 and area >= 1.0:
                dz = 0.12 if nrm[2] >= 0.8 else 0.08
                frost.append(([(x, y, z + dz) for x, y, z in co], nrm, area))
    if frost:
        data["Frost"] = frost
    objs, subs = [], {}
    for sname, faces in data.items():
        for i, ch in enumerate(chunks(faces)):
            o, tris = make_obj(f"{name}__{sname}" + (f"_{i + 1}" if i else ""), SUBMAT[sname], ch)
            objs.append(o)
            subs[o.name] = tris
    PIECES[name] = objs
    lo, hi = bbox(objs)
    manifest["pieces"][name] = {"group": group, "sub_meshes": subs, "tris_total": sum(subs.values()),
                                "size_studs_xyz": [round(hi.x - lo.x, 1), round(hi.y - lo.y, 1), round(hi.z - lo.z, 1)],
                                "bbox_min": [round(c, 2) for c in lo], "bbox_max": [round(c, 2) for c in hi],
                                "materials": sorted({m.name for o in objs for m in o.data.materials})}
    if name in STACK:
        manifest["pieces"][name]["stack"] = STACK[name]
    log(f"{name:22s} " + " ".join(f"{k.split('__')[1]}={v}" for k, v in subs.items()) + f"  size {manifest['pieces'][name]['size_studs_xyz']}")


def export_piece(name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in PIECES[name]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = PIECES[name][0]
    fmt = {"": "NONE", "jpeg": "JPEG", "png": "AUTO"}[EMBED.lower()]
    kw = dict(filepath=str(OUT / f"{name}.glb"), export_format="GLB", use_selection=True, export_apply=False, export_image_format=fmt)
    bpy.ops.export_scene.gltf(**kw)
    manifest["pieces"][name]["file"] = f"{name}.glb"


# ============================================================================================ renders
def setup_render():
    sc = bpy.context.scene
    ids = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES") if e in ids)
    if sc.render.engine == "CYCLES":
        sc.cycles.samples = 24
    else:
        try:
            sc.eevee.taa_render_samples = 24
        except Exception:
            pass
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.05, 0.052, 0.058, 1)
    bg.inputs["Strength"].default_value = 1.0
    sc.world = w
    for nm, e, rot, col in (("key", 5.0, (math.radians(68), 0, math.radians(-38)), (1.0, 0.82, 0.66)),
                            ("rim", 2.2, (math.radians(55), 0, math.radians(52)), (0.62, 0.72, 1.0))):
        L = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN"))
        L.data.energy, L.data.color, L.rotation_euler = e, col, rot
        sc.collection.objects.link(L)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.clip_start, cam.data.clip_end, cam.data.lens = 1.0, 6000, 35
    sc.collection.objects.link(cam)
    sc.camera = cam
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.12, 0.125, 0.135, 1)
    me = bpy.data.meshes.new("Ground")
    me.from_pydata([(-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(gm)
    g = bpy.data.objects.new("Ground", me)
    sc.collection.objects.link(g)
    # render-only glow on the glass (added after export so the GLBs stay clean)
    gmat = MATS.get("Vesp_Glass")
    if gmat:
        nt = gmat.node_tree
        p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        img = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name.endswith("_Color"))
        nt.links.new(img.outputs["Color"], p.inputs["Emission Color"])
        p.inputs["Emission Strength"].default_value = 2.0
    return sc, cam, g


def sheet(sc, cam, ground, tag, items, az=24.0, scale=None):
    V, x, boxes = [], 0.0, []
    for name, s in items:
        lo, hi = bbox(PIECES[name])
        w = (hi.x - lo.x) * s
        cx = x + w / 2 + 0.06 * w
        for o in PIECES[name]:
            c = bpy.data.objects.new("V_" + o.name, o.data)
            c.matrix_world = Matrix.Translation((cx - (lo.x + hi.x) / 2 * s, -(lo.y + hi.y) / 2 * s, 0)) @ Matrix.Scale(s, 4)
            sc.collection.objects.link(c)
            V.append(c)
        boxes.append((cx - w / 2, 0.0, cx + w / 2, (hi.z) * s))
        x = cx + w / 2 + 0.06 * w
    W, H = max(b[2] for b in boxes), max(b[3] for b in boxes)
    cxm = W / 2
    for o in V:
        o.hide_render = False
    ground.scale, ground.location = (W * 2 + 40, W * 2 + 40, 1), Vector((cxm, 0, 0))
    d = 1.15 * max(0.98 * W, 1.57 * H * 1.0)
    ang = math.radians(az)
    tgt = Vector((cxm, 0, H * 0.46))
    cam.location = tgt + Vector((math.sin(ang) * d, -math.cos(ang) * d, -H * 0.2 + d * 0.06))
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
    sc.render.filepath = str(OUT / "renders" / f"{tag}.png")
    bpy.ops.render.render(write_still=True)
    for o in V:
        bpy.data.objects.remove(o)


def main():
    (OUT / "maps").mkdir(parents=True, exist_ok=True)
    (OUT / "renders").mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for m in GENS:
        build_material(m)
    for name, group, fn in PLAN:
        if ONLY and name not in ONLY:
            continue
        S = Subs()
        fn(S)
        finish(name, group, S)
    for name in PIECES:
        export_piece(name)
    manifest["textures"] = {i.name: list(i.size) for i in bpy.data.images if i.name.startswith("Vesp_")}
    manifest["glb_images"] = EMBED or "none (maps/ is the single source; see module docstring)"
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
    log("exported", len(PIECES), "pieces")
    if os.environ.get("VESP_NORENDER"):
        return
    sc, cam, ground = setup_render()
    for o in [o for objs in PIECES.values() for o in objs]:
        o.hide_render = True
    SHEETS = [("A1_arcade_bays", [("Arcade_Bay_60", 1), ("Arcade_Bay_50", 1), ("Arcade_Bay_40", 1)]),
              ("A2_corner_bastion", [("Arcade_Corner", 1), ("Bastion_Face", 1)]),
              ("A3_balustrade_parapet_cornice", [("Balustrade_20", 2.5), ("Parapet_Gothic_20", 2.5), ("Cornice_20", 2.5)]),
              ("B1_buttress_flyers", [("Buttress_Pier", 1), ("Flying_Buttress_40", 1), ("Flying_Buttress_60", 1)]),
              ("B2_pinnacles_finial", [("Pinnacle_Crocket_S", 2.5), ("Pinnacle_Crocket_M", 2.5), ("Pinnacle_Crocket_L", 2.5), ("Finial", 2.5)]),
              ("C1_spire_modules", [("Spire_Base_Oct", 1), ("Spire_Belfry_Stage", 1), ("Spire_Lucarne_Mid", 1)]),
              ("C2_needle_broken_tower", [("Spire_Needle_Tip", 1), ("Spire_Broken_Top", 1), ("Tower_Corner_Stage", 1)]),
              ("D1_lancets_roses", [("Lancet_Tall", 1), ("Lancet_Pair", 1), ("Rose_Window_Small", 1)]),
              ("D2_rose_great_portal", [("Rose_Window_Great", 1), ("Portal_Great", 1)]),
              ("D3_portcullis_door", [("Portcullis", 1), ("Door_Iron", 1)]),
              ("E1_viaduct", [("Viaduct_Bay", 1), ("Viaduct_Balustrade_30", 1.5), ("Statue_Plinth", 3)])]
    for tag, items in SHEETS:
        items = [(n, s) for n, s in items if n in PIECES]
        if items:
            t = time.time()
            sheet(sc, cam, ground, tag, items)
            log(f"render {tag} {time.time() - t:.1f}s")
    # stacked tower for the stack-interface check (Tower x2, Base, Belfry, Lucarne, Needle)
    stack = [("Tower_Corner_Stage", 0.0), ("Tower_Corner_Stage", 60.0), ("Spire_Base_Oct", 120.0), ("Spire_Belfry_Stage", 146.0),
             ("Spire_Lucarne_Mid", 182.0), ("Spire_Needle_Tip", 226.0)]
    if all(n in PIECES for n, _ in stack):
        V = []
        for n, z in stack:
            for o in PIECES[n]:
                c = bpy.data.objects.new("V_" + o.name, o.data)
                c.location = (0, 0, z)
                sc.collection.objects.link(c)
                V.append(c)
        ground.scale, ground.location = (400, 400, 1), Vector((0, 0, 0))
        tgt = Vector((0, 0, 135))
        cam.location = tgt + Vector((150, -520, 20))
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = str(OUT / "renders" / "C3_spire_stack.png")
        bpy.ops.render.render(write_still=True)
        for o in V:
            bpy.data.objects.remove(o)
    log("renders done")


if os.environ.get("VESP_NOMAIN") != "1":
    main()

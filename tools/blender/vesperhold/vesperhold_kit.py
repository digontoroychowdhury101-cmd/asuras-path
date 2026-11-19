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
FINIAL_COPPER = False  # mac-53: soot-black stone finials (oversight: green copper read as toy-like); True restores verdigris caps


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
    gsel = (pid % 11)[..., None]  # warm-dominant ground (ref_01 glows amber/crimson), blue-violet as the cool accent
    col = np.where(ground[..., None], np.where(gsel < 4, crim2, np.where(gsel < 6, amber * 0.55, np.where(gsel < 9, blue, viol))), col)
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
        self.mat, self.prims, self.owner, self.uvfn = mat, [], owner, None  # uvfn(co, centroid) -> (u, v) overrides triplanar

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
    if FINIAL_COPPER and sub.owner is not None and sub.mat != "Vesp_Verdigris":  # copper-capped finials: the Verdigris sub
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


# ============================================================================================ GROUP D


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
    pin_cluster(pn, cr, 0, 0, ztp, 6.0, 32.0, 3, 4, rot=math.pi / 8)
    for k in range(0, 8, 2):
        th = k * math.pi / 4 + math.pi / 8
        gargoyle(S["Dress"], (10.2 * math.cos(th), 10.2 * math.sin(th), zt - 4.0), (math.cos(th), math.sin(th)), 1.2)


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


# ============================================================================================ mac-53 detail helpers
def Rx(a):
    return Matrix.Rotation(a, 4, "X")


def blind_arcade(sub, x0, x1, z0, h, y, n=None, depth=0.5, cusp=True):
    """Blind arcade relief on a wall plane at y (relief toward -y): pointed recesses, cusped heads. Local XZ frame."""
    n = n or max(1, int(round((x1 - x0) / 3.0)))
    p = (x1 - x0) / n
    a = p / 2 - min(0.35, p * 0.12)
    holes = []
    for i in range(n):
        c = x0 + p * (i + 0.5)
        hole, zs, Rr = lancet_hole(a, z0 + 0.35, z0 + h - 0.35, 1.1)
        holes.append([(c + x, z) for x, z in hole])
        if cusp and a > 0.45:
            ar = arch(a, zs, Rr, 0, 9)
            for j in (2, len(ar) - 3):
                q = ar[j]
                dx = 0.6 if q[0] < 0 else -0.6
                place_spear(sub, c + q[0], y - depth / 2, q[1], dx, -0.8, a * 0.45, a * 0.5, depth * 0.8)
    sub.add(prism([[(x0, z0), (x1, z0), (x1, z0 + h), (x0, z0 + h)]] + holes, y - depth, y))


def wimperg(sub, cr, hw, zb, hgt, y, th, arc=None, foil_r=0.0, foil_z=None, crock=1.0, cx=0.0, fin=True):
    """Crocketed gable (wimperg) in the XZ plane centred at y. arc: extrados (x, z) left->right cut out of its foot so it sits
    over an archivolt. foil_r > 0 adds a blind cusped trefoil in the field."""
    poly = [(cx - hw, zb)]
    if arc:
        poly += [(x, z) for x, z in arc if z > zb + 0.05 and abs(x - cx) < hw * (1 - (z - zb) / hgt) - 0.3]
    poly += [(cx + hw, zb), (cx, zb + hgt)]
    sub.add(prism([clean(poly)], y - th / 2, y + th / 2))
    for sx in (-1, 1):
        p0, p1 = (cx + sx * hw, y, zb), (cx, y, zb + hgt)
        edge_rib(sub, p0, p1, th + 0.5, (sx * hgt, 0, hw))
        crockets(cr, p0, p1, (sx * hgt, 0, hw), crock, crock * 2.0, 0.07, 0.9, 0.35)
    if fin:
        finial(cr, cx, y, zb + hgt - 0.2, crock * 0.75)
    if foil_r > 0:
        foil(sub, cx, foil_z if foil_z is not None else zb + hgt * 0.45, foil_r, 3, y - th / 2, -1, max(0.3, foil_r * 0.14), max(0.4, foil_r * 0.2))


def pin_cluster(D, C, cx, cy, z0, w, h, lvl=2, minis=4, rot=0.0):
    """Main crocketed pinnacle with smaller pinnacles crowding its base (gothic stage-transition cluster)."""
    pinnacle(D, C, cx, cy, z0, w, h, lvl)
    for k in range(minis):
        a = rot + math.pi / 4 + k * 2 * math.pi / minis
        pinnacle(D, C, cx + math.cos(a) * w * 0.78, cy + math.sin(a) * w * 0.78, z0, w * 0.42, h * 0.58, 1)


def gargoyle(sub, pos, d, s=1.0):
    """Simple water-spout beast on a corbel: base at pos (on the wall), projecting along horizontal direction d."""
    T = Tr(*pos) @ Rz(math.atan2(d[1], d[0]))
    spec = [(-0.4, 0.62, 0.62, 0.0), (0.0, 0.6, 0.55, 0.0), (0.9, 0.52, 0.46, 0.12), (1.6, 0.34, 0.32, 0.3), (2.05, 0.44, 0.38, 0.38),
            (2.6, 0.3, 0.26, 0.26), (3.1, 0.13, 0.12, 0.14)]
    sub.add(loft([[(x * s, -hy * s, (zc - hz) * s), (x * s, hy * s, (zc - hz) * s), (x * s, hy * s, (zc + hz) * s), (x * s, -hy * s, (zc + hz) * s)]
                  for x, hy, hz, zc in spec]), T)
    for sy in (-1, 1):
        sub.add(prism([[(0.1 * s, 0.3 * s), (1.5 * s, 0.45 * s), (0.4 * s, 1.7 * s)]], (sy * 0.55 - 0.07) * s, (sy * 0.55 + 0.07) * s), T)
        sub.add(loft([rect(0, 0, 0, 0.09 * s, 0.09 * s)], cap1=False, apex=(0, 0, 0.7 * s)), T @ Tr(2.0 * s, sy * 0.24 * s, 0.68 * s) @ Ry(-0.6))
        sub.add(box(1.0 * s, 1.35 * s, (sy * 0.32 - 0.12) * s, (sy * 0.32 + 0.12) * s, -0.75 * s, -0.2 * s), T)
    sub.add(loft([rect(-0.25 * s, 0, -1.5 * s, 0.35 * s, 0.55 * s), rect(0.25 * s, 0, -0.5 * s, 0.85 * s, 0.62 * s)]), T)


def statuette(h, seg=6):
    """Robed hooded figure as a lathe, foot at origin, up +Z (voussoir / jamb / niche figures)."""
    return lathe([(0.19 * h, 0.0), (0.18 * h, 0.06 * h), (0.14 * h, 0.40 * h), (0.115 * h, 0.60 * h), (0.14 * h, 0.68 * h), (0.11 * h, 0.77 * h),
                  (0.095 * h, 0.85 * h), (0.07 * h, 0.95 * h), (0.0, 1.0 * h)], seg)


def canopy(sub, T, w, h):
    """Gabled niche canopy over a figure (local frame, base at origin)."""
    sub.add(box(-w / 2, w / 2, -w / 2, w / 2, 0, h * 0.35), T)
    sub.add(loft([rect(0, 0, h * 0.35, w * 0.5, w * 0.5)], cap1=False, apex=(0, 0, h)), T)


def statue_niche(st, cr, cx, y, z0, h, w=None):
    """Figure on a corbel under a canopy, standing in front of a wall plane at y (faces -y)."""
    w = w or h * 0.42
    st.add(loft([rect(cx, y - w * 0.35, z0 - h * 0.18, w * 0.25, w * 0.2), rect(cx, y - w * 0.45, z0, w * 0.45, w * 0.45)]))
    st.add(statuette(h, 8), Tr(cx, y - w * 0.45, z0))
    canopy(cr, Tr(cx, y - w * 0.45, z0 + h * 1.04), w * 1.05, h * 0.45)


def louvres(sub, cx, a, z0, z1, y, step=1.25):
    z = z0 + 0.6
    while z < z1:
        sub.add(box(-a, a, -0.06, 0.06, -0.55, 0.55), Tr(cx, y, z) @ Rx(0.62))
        z += step


def spire_tracery(S, R0, R1, H, tiers, faces=range(8), bw=0.34):
    """Blind lancet panels (outline, mullion, trefoil) lying on the sloped faces of an octagonal spire (vertices at 22.5+45k)."""
    c8 = math.cos(math.pi / 8)
    for k in faces:
        ph = k * math.pi / 4
        n = Vector((math.cos(ph), math.sin(ph), 0.0))
        P0, P1 = n * (R0 * c8), n * (R1 * c8) + Vector((0, 0, H))
        L = (P1 - P0).length
        T = frame(P0, (-math.sin(ph), math.cos(ph), 0.0), tuple(P1 - P0))
        for z0, z1 in tiers:
            t0, t1 = z0 / H * L, z1 / H * L
            w = (R0 + (R1 - R0) * z1 / H) * math.sin(math.pi / 8)
            a = w * 0.6
            if a < 0.5 or t1 - t0 < 3.0:
                continue
            hole, zs, Rr = lancet_hole(a, t0 + 0.6, t1 - 0.7, 1.15)

            def fn(Lc, hole=hole, zs=zs, a=a, t0=t0, Rr=Rr):
                Lc["Tracery"].add(sweep(hole, barf(bw, bw * 1.5), 0.0, -1, closed=True))
                Lc["Tracery"].add(box(-bw / 2, bw / 2, -bw * 1.2, 0.0, t0 + 0.6, zs + 0.2))
                if a > 0.9:
                    foil(Lc["Tracery"], 0.0, zs + arch_h(a, Rr) * 0.42, a * 0.42, 3, 0.0, -1, bw * 0.8, bw * 1.2)
            local(S, T, fn)


def dormer(L, w=2.4, h=6.5, roof=4.2, depth=7.0, crock=0.55, pins=True):
    """Gabled lucarne: front plane y=0, body runs +y into the spire, lancet recess, slate roof, crocketed gable, corner pinnacles."""
    hole, zs, Rr = lancet_hole(w * 0.42, 1.0, h - 0.6, 1.2)
    L["Stone"].add(box(-w, w, 0.0, depth, 0, h))
    L["Stone"].add(prism([[(-w, 0), (w, 0), (w, h), (-w, h)], hole], -0.7, 0.0))
    L["Tracery"].add(box(-w - 0.35, w + 0.35, -1.2, 0.0, -0.5, 0.0))
    L["Roof"].add(prism([[(-w - 0.4, h), (w + 0.4, h), (0, h + roof)]], -0.6, depth))
    wimperg(L["Tracery"], L["Crockets"], w + 0.5, h - 0.3, roof + 2.0, -1.0, 0.5, crock=crock)
    if pins:
        for sx in (-1, 1):
            pinnacle(L["Pinnacles"], L["Crockets"], sx * (w + 0.1), -0.9, 0.0, 0.8, h + 2.2, 1)


def corner_pier(S, sx, sy, z0, z1, ph=(30.0, 48.0), gar_z=None):
    """Tower corner pier x,y in [13.6, 19.0] (signed): blind panels on its two outer faces, angle shafts, engaged pinnacles."""
    st, tr, pn, cr = S["Stone"], S["Tracery"], S["Pinnacles"], S["Crockets"]
    st.add(box(min(sx * 13.6, sx * 19.0), max(sx * 13.6, sx * 19.0), min(sy * 13.6, sy * 19.0), max(sy * 13.6, sy * 19.0), z0, z1))
    colonnette(st, sx * 19.0, sy * 19.0, z0 + 0.5, z1 - 0.5, 0.55, 6)
    for (fx, fy) in ((1, 0), (0, 1)):  # the two outer faces, each in a local frame whose -y points out of the face
        ang = math.atan2(sy * fy, sx * fx) + math.pi / 2
        T = Tr(sx * 16.3 if fx == 0 else sx * 19.0, sy * 16.3 if fy == 0 else sy * 19.0, 0) @ Rz(ang)

        def fn(L, z0=z0, z1=z1):
            for za, zb in ((z0 + 3.0, z0 + (z1 - z0) * 0.45), (z0 + (z1 - z0) * 0.5 + 1.5, z1 - 3.0)):
                if zb - za > 6:
                    blind_arcade(L["Tracery"], -1.9, 1.9, za, zb - za, 0.0, 1, 0.45)
            for zp in ph:
                if z0 + 2 < zp < z1 - 6:
                    pinnacle(L["Pinnacles"], L["Crockets"], 0.0, -0.9, zp, 1.5, 9.0, 1)
        local(S, T, fn)
    for zb in (z0 + 12.0, z0 + 30.0):
        if zb < z1 - 1:
            tr.add(frust(sx * 16.3, sy * 16.3, zb, 2.95, 2.95, zb + 0.9, 2.95, 2.95))
    if gar_z is not None:
        gargoyle(S["Dress"], (sx * 19.0, sy * 19.0, gar_z), (sx, sy), 1.0)


# ============================================================================================ GROUP C (mac-53 rebuild)
C8, S8 = math.cos(math.pi / 8), math.sin(math.pi / 8)


def tower_stage(S):
    """Square tower stage 32 x 32 x 60 with corner piers (interface: square 32 + piers 13.6..19.0 at z 0 and 60)."""
    st, tr, cr, pn = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"]
    st.add(frust(0, 0, 0, 16.4, 16.4, 3.0, 16.4, 16.4))
    st.add(frust(0, 0, 3.0, 14.8, 14.8, 60.0, 14.8, 14.8))
    hl, zs, Rr = lancet_hole(2.7, 15.0, 47.0)

    def face(L):
        holes = []
        for cx in (-6.4, 6.4):
            holes.append([(cx + x, z) for x, z in hl])
            archivolt(L["Tracery"], 2.7, zs, Rr, [(0.0, [("roll", 0.6, 0.6), ("cove", 0.5, 0.4), ("roll", 0.8, 0.8)])], -16.0, -1, z0=15.0,
                      cx=cx, n=10)
            head_tracery(L["Tracery"], cx, zs, 2.7, Rr, -15.4, 0.4, zs + 0.8)
            L["Tracery"].add(box(cx - 0.2, cx + 0.2, -15.7, -15.1, 15.0, zs + 0.8))
            for zt_ in (24.0, 33.0):
                L["Tracery"].add(box(cx - 2.6, cx + 2.6, -15.6, -15.1, zt_, zt_ + 0.4))
            L["Tracery"].add(box(cx - 3.3, cx + 3.3, -17.0, -15.8, 14.2, 15.0))
            ext = arch(2.7, zs, Rr, 2.4, 14)
            wimperg(L["Tracery"], L["Crockets"], 5.6, 43.0, 14.0, -16.9, 0.7, arc=[(cx + x, z) for x, z in ext], foil_r=1.1,
                    foil_z=52.4, crock=0.75, cx=cx)
        L["Stone"].add(prism([[(-13.6, 3.0), (13.6, 3.0), (13.6, 60.0), (-13.6, 60.0)]] + holes, -16.0, -14.8))
        blind_arcade(L["Tracery"], -13.6, 13.6, 4.0, 8.4, -16.0, 9, 0.5)
        blind_arcade(L["Tracery"], -1.5, 1.5, 15.0, 31.0, -16.0, 1, 0.5)
        for zb, wdt in ((12.4, 1.0), (36.0, 0.8), (57.2, 1.4)):
            L["Tracery"].add(xext([(-16.0, zb), (-17.1, zb + 0.3), (-17.1, zb + wdt), (-16.0, zb + wdt + 0.4)], -13.6, 13.6))
        for i in range(12):
            c = -12.65 + i * 2.3
            L["Tracery"].add(loft([rect(c, -16.4, 55.6, 0.3, 0.3), rect(c, -16.6, 57.2, 0.55, 0.6)]))
    for k in range(4):
        local(S, Rz(k * math.pi / 2), face)
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        corner_pier(S, sx, sy, 0.0, 60.0, (26.0, 44.0), gar_z=54.0)
    tr.add(loft([rect(0, 0, 0.0, 16.8, 16.8), rect(0, 0, 1.0, 16.8, 16.8), rect(0, 0, 1.8, 16.4, 16.4)]))
    st.add(frust(0, 0, 59.0, 16.0, 16.0, 60.0, 16.0, 16.0))


def spire_base_oct(S):
    """Square 32 (+ corner piers) -> octagon R14, h 30: blind-arcaded square stage, octagonal drum with twin blind lancets,
    crocketed wimpergs on the cardinal faces, pinnacle clusters on the four corner piers."""
    st, tr, cr, pn = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"]
    st.add(frust(0, 0, 0, 16.0, 16.0, 9.0, 16.0, 16.0))
    tr.add(loft([rect(0, 0, 8.4, 16.0, 16.0), rect(0, 0, 9.0, 16.8, 16.8), rect(0, 0, 9.8, 16.8, 16.8), rect(0, 0, 10.2, 15.6, 15.6)]))
    st.add(loft([ngon(0, 0, 9.0, 14.0), ngon(0, 0, 30.0, 14.0)]))
    ap = 14.0 * C8
    hd, zsd, Rd = lancet_hole(4.6, 11.0, 27.6, 1.05)

    def oface(L):
        blind_arcade(L["Tracery"], -4.6, 4.6, 11.0, 15.0, 0.0, 2, 0.6)
        archivolt(L["Tracery"], 4.6, zsd, Rd, [(0.2, [("roll", 0.5, 0.5), ("cove", 0.4, 0.4)])], 0.0, -1, z0=None, n=12, crock=(0.7, 1.9, 0.25))
    for k in range(8):
        local(S, facet_T(k, ap), oface)

    def sface(L):
        blind_arcade(L["Tracery"], -13.6, 13.6, 1.0, 7.0, -16.0, 8, 0.5)
        wimperg(L["Tracery"], L["Crockets"], 7.4, 10.2, 16.0, -16.2, 1.2, foil_r=3.0, foil_z=16.4, crock=1.0)
    for k in range(4):
        local(S, Rz(k * math.pi / 2), sface)
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        corner_pier(S, sx, sy, 0.0, 11.0, (), gar_z=None)
        tr.add(frust(sx * 16.3, sy * 16.3, 10.2, 3.2, 3.2, 11.0, 3.2, 3.2))
        pin_cluster(pn, cr, sx * 16.3, sy * 16.3, 11.0, 4.6, 30.0, 2, 4, rot=0.0)
        gargoyle(S["Dress"], (sx * 19.0, sy * 19.0, 8.6), (sx, sy), 1.1)
    tr.add(loft([ngon(0, 0, 28.4, 14.0), ngon(0, 0, 29.2, 14.8), ngon(0, 0, 30.0, 14.8), ngon(0, 0, 30.0, 14.0)]))
    tr.add(loft([rect(0, 0, 0.0, 16.8, 16.8), rect(0, 0, 0.9, 16.8, 16.8), rect(0, 0, 1.6, 16.3, 16.3)]))


def spire_belfry_stage(S):
    """Octagon R14 -> deck R13.6 at z 40: tall paired louvred openings under crocketed hoods, wimpergs, pierced balustrade,
    pinnacle clusters on the eight angle buttresses (the stage-transition crown rises above the z 40 interface)."""
    st, tr, cr, pn = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"]
    st.add(loft([ngon(0, 0, 0, 14.4), ngon(0, 0, 2.4, 14.4)]))
    st.add(loft([ngon(0, 0, 2.4, 9.5), ngon(0, 0, 40.0, 9.5)]))
    ap = 14.0 * C8
    sw = 14.0 * S8
    hl, zs, Rr = lancet_hole(1.75, 9.6, 31.0, 1.25)
    ho, zso, Ro = lancet_hole(4.2, 9.6, 34.6, 1.0)

    def face(L):
        holes = [[(cx + x, z) for x, z in hl] for cx in (-2.35, 2.35)]
        L["Stone"].add(prism([[(-sw - 0.1, 2.4), (sw + 0.1, 2.4), (sw + 0.1, 40.0), (-sw - 0.1, 40.0)]] + holes, -0.9, 0.9))
        for cx in (-2.35, 2.35):
            archivolt(L["Tracery"], 1.75, zs, Rr, [(0.0, [("roll", 0.4, 0.4), ("cove", 0.3, 0.3)])], -0.9, -1, z0=9.6, cx=cx, n=9)
            louvres(L["Tracery"], cx, 1.7, 9.6, zs + 1.0, 0.2)
            L["Tracery"].add(box(cx - 2.1, cx + 2.1, -1.8, -0.8, 9.0, 9.6))
        archivolt(L["Tracery"], 4.2, zso, Ro, [(0.2, [("roll", 0.5, 0.6), ("cove", 0.4, 0.4), ("roll", 0.6, 0.7)])], -0.9, -1, z0=None, n=12,
                  crock=(0.8, 2.0, 0.3))
        foil(L["Tracery"], 0.0, 32.6, 1.15, 4, -0.9, -1, 0.3, 0.6)
        blind_arcade(L["Tracery"], -sw + 0.6, sw - 0.6, 3.0, 5.6, -0.9, 4, 0.45)
        ext = arch(4.2, zso, Ro, 2.2, 14)
        wimperg(L["Tracery"], L["Crockets"], 5.1, 33.0, 14.0, -1.7, 0.7, arc=ext, foil_r=1.5, foil_z=40.6, crock=0.85)
        balustrade(L["Pinnacles"], L["Pinnacles"], -sw + 0.8, sw - 0.8, 40.0, 0.2, 5.4, 1.0, 1.2)
    for k in range(8):
        local(S, facet_T(k, ap), face)
        th = k * math.pi / 4 + math.pi / 8
        vx, vy = 14.2 * math.cos(th), 14.2 * math.sin(th)
        for dt in (-0.07, 0.07):
            colonnette(st, 14.3 * math.cos(th + dt), 14.3 * math.sin(th + dt), 2.4, 38.0, 0.6, 6)
        st.add(frust(vx, vy, 2.4, 1.3, 1.3, 40.0, 1.3, 1.3))
        pin_cluster(pn, cr, 14.6 * math.cos(th), 14.6 * math.sin(th), 40.0, 2.6, 16.0, 2, 2, rot=th + math.pi / 4)
        gargoyle(S["Dress"], (14.6 * math.cos(th), 14.6 * math.sin(th), 37.0), (math.cos(th), math.sin(th)), 0.85)
    tr.add(loft([ngon(0, 0, 8.6, 14.5), ngon(0, 0, 9.0, 14.9), ngon(0, 0, 9.6, 14.3)]))
    tr.add(loft([ngon(0, 0, 36.8, 14.0), ngon(0, 0, 38.0, 14.8), ngon(0, 0, 39.4, 14.9), ngon(0, 0, 40.0, 14.2)]))
    for k in range(24):
        a = k * 2 * math.pi / 24
        tr.add(loft([rect(0, 0, 0.0, 0.3, 0.3), rect(0, 0, 1.3, 0.55, 0.7)]), Tr(13.9 * math.cos(a), 13.9 * math.sin(a), 36.6) @ Rz(a))
    st.add(loft([ngon(0, 0, 39.2, 13.6), ngon(0, 0, 40.0, 13.6)]))
    tr.add(loft([ngon(0, 0, 0.0, 14.8), ngon(0, 0, 1.0, 14.8), ngon(0, 0, 1.8, 14.4)]))


def spire_lucarne_mid(S):
    """Stone spire frustum R13 -> R6.5 over 48: crocketed edge ribs, three bands, blind tracery on every face, two tiers of
    gabled lucarnes, a ring of small pinnacles at the top transition."""
    st, tr, cr, pn = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"]
    R0, R1, H = 13.0, 6.5, 48.0
    st.add(loft([ngon(0, 0, 0, R0), ngon(0, 0, H, R1)]))
    rad = lambda z: R0 + (R1 - R0) * z / H
    for k in range(8):
        th = k * math.pi / 4 + math.pi / 8
        p0, p1 = (R0 * math.cos(th), R0 * math.sin(th), 0.0), (R1 * math.cos(th), R1 * math.sin(th), H)
        edge_rib(tr, p0, p1, 1.5, (math.cos(th), math.sin(th), 0))
        crockets(cr, p0, p1, (math.cos(th), math.sin(th), 0.0), 1.6, 3.2, 0.04, 0.96, 0.45)
    for z in (16.0, 32.0):
        r = rad(z)
        tr.add(loft([ngon(0, 0, z, r + 0.9), ngon(0, 0, z + 0.8, r + 0.95), ngon(0, 0, z + 1.6, r + 0.05)]))
    spire_tracery(S, R0, R1, H, [(1.6, 15.6), (17.6, 31.6), (33.6, 46.0)], bw=0.4)
    for k in range(8):
        ph = k * math.pi / 4
        z0, w = (2.0, 2.5) if k % 2 == 0 else (19.0, 2.0)
        local(S, Rz(ph + math.pi / 2) @ Tr(0, -(rad(z0 + 3.0) * C8 + 1.6), z0), lambda L, w=w: dormer(L, w, 6.2 if w > 2.2 else 5.2, 3.8, 7.0))
    tr.add(loft([ngon(0, 0, H - 1.4, R1 + 0.9), ngon(0, 0, H - 0.6, R1 + 1.2), ngon(0, 0, H, R1 + 1.2), ngon(0, 0, H, R1)]))
    for k in range(8):
        ph = k * math.pi / 4
        pinnacle(pn, cr, (R1 * C8 + 1.1) * math.cos(ph), (R1 * C8 + 1.1) * math.sin(ph), H, 1.1, 7.0, 1)


def spire_needle_tip(S):
    """Needle R6.5 -> point over 56: crocketed ribs, bands, blind tracery, gabled lucarnes on alternate faces, finial + iron cross."""
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    R0, R1, H = 6.5, 0.35, 56.0
    st.add(loft([ngon(0, 0, 0, R0), ngon(0, 0, H, R1)]))
    rad = lambda z: R0 + (R1 - R0) * z / H
    for k in range(8):
        th = k * math.pi / 4 + math.pi / 8
        p0, p1 = (R0 * math.cos(th), R0 * math.sin(th), 0.0), (R1 * math.cos(th), R1 * math.sin(th), H)
        crockets(cr, p0, p1, (math.cos(th), math.sin(th), 0.0), 1.15, 2.6, 0.05, 0.95, 0.55)
        edge_rib(tr, p0, p1, 0.95, (math.cos(th), math.sin(th), 0))
    for z in (14.0, 28.0, 42.0):
        r = rad(z)
        tr.add(loft([ngon(0, 0, z, r + 0.6), ngon(0, 0, z + 0.6, r + 0.65), ngon(0, 0, z + 1.2, r + 0.05)]))
    spire_tracery(S, R0, R1, H, [(1.2, 13.6), (15.2, 27.6)], bw=0.28)
    for k in range(8):
        ph = k * math.pi / 4
        z0, w = (3.0, 1.5) if k % 2 == 0 else (17.0, 1.1)
        local(S, Rz(ph + math.pi / 2) @ Tr(0, -(rad(z0 + 2.0) * C8 + 1.0), z0), lambda L, w=w: dormer(L, w, 3.6 * w / 1.5 + 0.6, 2.4, 4.0, 0.4, False))
    finial(cr, 0, 0, H - 0.6, 1.1)
    ir = S["Iron"]
    zc = H - 0.6 + 1.1 * 4.6
    ir.add(box(-0.22, 0.22, -0.22, 0.22, zc - 0.6, zc + 7.0))
    ir.add(box(-2.0, 2.0, -0.2, 0.2, zc + 4.2, zc + 4.7))
    ir.add(sweep(circle(0, zc + 4.45, 1.1, 16), barc(0.18, 0.3), 0.0, 1.0, closed=True))


def spire_broken_top(S):
    """Needle snapped at ~28: shell plates with ragged tops (inner faces show the thickness), broken ribs, one lucarne, rubble."""
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    rng = np.random.default_rng(5)
    R0, H = 6.5, 56.0
    rad = lambda z: R0 + (0.35 - R0) * z / H
    st.add(loft([ngon(0, 0, 0, R0), ngon(0, 0, 9.0, rad(9.0))]))
    tops = [27.0, 21.5, 15.0, 12.0, 17.5, 24.5, 29.0, 26.0]
    for k in range(8):
        ph = k * math.pi / 4
        zt = tops[k]
        w0, w1 = rad(9.0) * S8, rad(zt) * S8
        prof = [(-w0, 9.0), (w0, 9.0)] + [(w1 * (1 - 2 * i / 5) + rng.uniform(-0.25, 0.25), zt - rng.uniform(0.0, 4.5) * (i % 2 + 0.4)) for i in range(6)]
        ap0 = rad(9.0) * C8
        sl = (rad(9.0) - rad(zt)) * C8 / (zt - 9.0)
        # plate leaning with the spire slope (shear in y by z)
        M = Matrix(((1, 0, 0, 0), (0, 1, sl, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
        st.add(prism([clean(prof)], -0.45, 0.45), Rz(ph + math.pi / 2) @ Tr(0, -ap0 + 0.45, 0) @ Tr(0, 0, 9.0) @ M @ Tr(0, 0, -9.0))
    for k in (0, 1, 5, 6, 7):
        th = k * math.pi / 4 + math.pi / 8
        z1 = min(tops[k], tops[(k + 1) % 8]) - rng.uniform(0.5, 3.0)
        p0, p1 = (R0 * math.cos(th), R0 * math.sin(th), 0.0), (rad(z1) * math.cos(th), rad(z1) * math.sin(th), z1)
        edge_rib(tr, p0, p1, 0.95, (math.cos(th), math.sin(th), 0))
        crockets(cr, p0, p1, (math.cos(th), math.sin(th), 0.0), 1.15, 2.6, 0.08, 0.85, 0.3)
    r = rad(14.0)
    tr.add(loft([ngon(0, 0, 14.0, r + 0.6), ngon(0, 0, 14.6, r + 0.65), ngon(0, 0, 15.2, r + 0.05)]))
    spire_tracery(S, R0, 0.35, H, [(1.2, 13.6)], faces=(0, 1, 2, 3, 5, 6, 7), bw=0.28)
    local(S, Rz(math.pi / 2) @ Tr(0, -(rad(5.0) * C8 + 1.0), 3.0), lambda L: dormer(L, 1.5, 4.2, 2.4, 4.0, 0.4, False))
    for i in range(9):
        a, rr = rng.uniform(0, 6.28), rng.uniform(1.0, 3.6)
        st.add(frust(math.cos(a) * rr, math.sin(a) * rr, 8.8, rng.uniform(0.4, 0.9), rng.uniform(0.4, 0.9), 8.8 + rng.uniform(0.6, 1.8), 0.3, 0.35))
    for i in range(6):  # broken crocket stubs and fragments lodged on the band
        a = rng.uniform(0, 6.28)
        st.add(box(-0.5, 0.5, -0.4, 0.4, 0, rng.uniform(0.5, 1.2)), Tr(math.cos(a) * (r + 0.3), math.sin(a) * (r + 0.3), 15.2) @ Rz(a))


# ============================================================================================ GROUP D (mac-53 rebuild)
def rose_glass(G, cx, cz, R, y0, y1, cells=24, nseg=96, nring=12):
    """Dense annulus disc (both faces + rim) so the polar UVs interpolate: u = cells/4 tiles around, v = r/R (4 cell rings)."""
    vs, fs = [], []
    for side, y in ((0, y0), (1, y1)):
        b = len(vs)
        vs.append((cx, y, cz))
        for i in range(1, nring + 1):
            r = R * i / nring
            vs += [(cx + r * math.cos(2 * math.pi * k / nseg), y, cz + r * math.sin(2 * math.pi * k / nseg)) for k in range(nseg)]
        ring = lambda i, k: b + 1 + (i - 1) * nseg + k % nseg
        for k in range(nseg):
            fs.append((b, ring(1, k), ring(1, k + 1)) if side else (b, ring(1, k + 1), ring(1, k)))
            for i in range(1, nring):
                q = (ring(i, k), ring(i + 1, k), ring(i + 1, k + 1), ring(i, k + 1))
                fs.append(q if side else q[::-1])
    o0, o1 = 1 + (nring - 1) * nseg, len(vs) // 2 + 1 + (nring - 1) * nseg
    for k in range(nseg):
        fs.append((o0 + k, o0 + (k + 1) % nseg, o1 + (k + 1) % nseg, o1 + k))
    G.add((vs, fs))
    K = cells / 4.0

    def uvfn(c, ctr):
        dx, dz = c[0] - cx, c[2] - cz
        r = math.hypot(dx, dz)
        tc = math.atan2(ctr[2] - cz, ctr[0] - cx)
        t = math.atan2(dz, dx) if r > 1e-4 else tc
        t += 2 * math.pi * round((tc - t) / (2 * math.pi))
        return (t / (2 * math.pi) * K, r / R)
    G.uvfn = uvfn


def rose(T, G, cx, cz, R, n, y=0.0):
    """Rayonnant rose (mac-53): hub six-foil, n radiating colonnette spokes, a middle ring, cusped pointed heads at the outer ends
    of the lights, a ring of cusped roundels between the heads. G: the GlassR sub (polar-UV disc)."""
    bw, h = max(0.32, R * 0.017), max(0.7, R * 0.045)
    r_hub, r_mid, r_spr, r_head = 0.20 * R, 0.55 * R, 0.70 * R, 0.84 * R
    T.add(sweep(circle(cx, cz, R * 0.985, max(48, n * 6)), barf(bw * 3.4, h * 1.25), y, -1, closed=True))
    T.add(sweep(circle(cx, cz, r_mid, max(48, n * 4)), barf(bw * 1.7, h), y, -1, closed=True))
    T.add(sweep(circle(cx, cz, r_hub, 32), barf(bw * 2.2, h * 1.1), y, -1, closed=True))
    T.add(lathe([(r_hub * 0.45, 0.0), (r_hub * 0.4, h * 0.9), (r_hub * 0.15, h * 1.5), (0.0, h * 1.7)], 12), Tr(cx, y, cz) @ Rx(math.pi / 2))
    foil(T, cx, cz, r_hub * 0.82, 6, y, -1, bw * 0.9, h * 0.9)
    m = n
    for k in range(m):  # spokes on the light boundaries
        ang = 2 * math.pi * k / m
        T.add(box(-bw * 0.5, bw * 0.5, y - h, y, r_hub, r_spr + 0.2), Tr(cx, 0, cz) @ Ry(math.atan2(math.cos(ang), math.sin(ang))))
    bh = r_spr * math.sin(math.pi / m) - bw * 0.6
    rs = r_spr * math.cos(math.pi / m)
    rise = r_head - rs
    Rr = max(bh * 1.02, (rise * rise + bh * bh) / (2 * bh))
    ar = arch(bh, 0.0, Rr, 0, 9)
    for k in range(m):
        ph = 2 * math.pi * (k + 0.5) / m
        c, s = math.cos(ph), math.sin(ph)
        loc = lambda u, v: (cx + (rs + v) * c - u * s, cz + (rs + v) * s + u * c)
        T.add(sweep([loc(u, v) for u, v in ar], barf(bw * 1.3, h * 0.95), y, -1))
        for j in (2, len(ar) - 3):  # cusps inside the head (trefoil)
            u, v = ar[j]
            px, pz = loc(u, v)
            du, dv = (-0.7 if u > 0 else 0.7), -0.7
            place_spear(T, px, y - h * 0.5, pz, du * -s + dv * c, du * c + dv * s, bw * 1.6, bw * 2.4, h * 0.8)
        for rr in (r_mid,):  # trefoil cusps on the middle ring inside each light
            px, pz = cx + (rr + bw) * c, cz + (rr + bw) * s
            place_spear(T, px, y - h * 0.5, pz, c, s, bw * 1.8, bw * 2.2, h * 0.8)
        rc = (r_head + R * 0.985) / 2 + bw * 0.4  # roundel between this head and the outer ring, on the spoke line
        pa = 2 * math.pi * (k + 1) / m
        rr_ = min((R * 0.985 - r_head) * 0.48, rc * math.sin(math.pi / m) * 0.8)
        if rr_ > bw * 2:
            foil(T, cx + rc * math.cos(pa), cz + rc * math.sin(pa), rr_, 4, y, -1, bw * 0.9, h * 0.85)
    rose_glass(G, cx, cz, R + bw, y + 0.15, y + 0.5, cells=24)


def rose_unit(S, R, W, Hh):
    cz = Hh / 2
    circ = circle(0, cz, R, 72)
    S["Stone"].add(prism([[(-W / 2, 0), (W / 2, 0), (W / 2, Hh), (-W / 2, Hh)], circ], -4.0, 4.0))
    for sgn, y in ((-1, -4.0), (1, 4.0)):
        S["Tracery"].add(sweep(circle(0, cz, R, 72), mould([("roll", R * 0.03 + 0.4, R * 0.03 + 0.4), ("cove", R * 0.025 + 0.3, R * 0.02 + 0.3), ("roll", R * 0.05 + 0.6, R * 0.05 + 0.5), ("flat", R * 0.03 + 0.3, 0.4)]), y, sgn, closed=True, flip=True))
    rose(S["Tracery"], S["GlassR"], 0.0, cz, R, 16 if R > 12 else 8)


def rose_great(S):
    """56 x 56 rose module: rose R24, crocketed hood over the upper half, cusped spandrel foils, gallery of blind arcading,
    angle buttresses with niches, pierced balustrade and pinnacle clusters on the crown."""
    st, tr, cr, pn = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"]
    rose_unit(S, 24.0, 56.0, 56.0)
    cz, R = 28.0, 24.0
    up = [(x, z) for x, z in circle(0, cz, R + 3.6, 64) if z > cz + 2]
    up.sort(key=lambda p: p[0])
    path_crockets(cr, up, -5.6, 1.5, 3.4)
    for sx in (-1, 1):
        for sz in (-1, 1):
            foil(tr, sx * 23.2, cz + sz * 23.2, 3.0, 3, -4.0, -1, 0.4, 0.7)
        st.add(bxm(sx, 26.0, 30.0, -6.0, 4.0, 0.0, 56.0))
        local(S, Tr(sx * 28.0, -6.0, 0.0), lambda L: (blind_arcade(L["Tracery"], -1.8, 1.8, 3.0, 22.0, 0.0, 1, 0.45),
                                                     statue_niche(L["Stone"], L["Crockets"], 0.0, 0.0, 30.0, 6.0, 2.8),
                                                     blind_arcade(L["Tracery"], -1.8, 1.8, 42.0, 12.0, 0.0, 1, 0.45)))
        for zb in (26.0, 56.0):
            tr.add(bxm(sx, 25.6, 30.4, -6.5, 4.4, zb - 0.9, zb))
        pin_cluster(pn, cr, sx * 28.0, -1.0, 56.0, 4.2, 22.0, 2, 4)
        gargoyle(S["Dress"], (sx * 28.0, -6.0, 53.0), (0, -1), 1.0)
    blind_arcade(tr, -22.0, 22.0, 0.6, 3.6, -4.0, 14, 0.4, False)
    balustrade(pn, pn, -25.5, 25.5, 56.0, -1.0, 6.2, 1.2, 1.4)
    tr.add(box(-26.0, 26.0, -5.0, 3.0, 55.0, 56.0))


def rose_small(S):
    rose_unit(S, 8.0, 20.0, 20.0)
    for sx in (-1, 1):
        pin_cluster(S["Pinnacles"], S["Crockets"], sx * 9.0, 0.0, 20.0, 2.0, 9.0, 2, 2)
    up = [(x, z) for x, z in circle(0, 10.0, 8.0 + 1.6, 40) if z > 11.0]
    up.sort(key=lambda p: p[0])
    path_crockets(S["Crockets"], up, -5.0, 0.8, 1.9)


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
    """Lancet light under a crocketed wimperg, angle shafts and pinnacles on the wall ends (14 wide)."""
    hole = lancet_unit(S, 0.0, 4.0)
    _, zs, Rr = lancet_hole(4.0, 1.5, 41.5, 1.2)
    S["Stone"].add(prism([[(-7, 0), (7, 0), (7, 46), (-7, 46)], hole], -2.0, 2.0))
    S["Tracery"].add(box(-7.4, 7.4, -2.4, 2.4, 0.0, 0.5))
    wimperg(S["Tracery"], S["Crockets"], 8.2, 31.0, 28.0, -3.4, 0.9, arc=arch(4.0, zs, Rr, 2.8, 16), foil_r=1.8, foil_z=50.5, crock=1.0)
    for sx in (-1, 1):
        colonnette(S["Stone"], sx * 6.4, -2.3, 0.5, 45.5, 0.55, 6)
        pinnacle(S["Pinnacles"], S["Crockets"], sx * 6.2, -0.4, 46.0, 1.9, 12.0, 1)
    S["Tracery"].add(box(-7.3, 7.3, -2.5, 2.5, 45.2, 46.0))


def lancet_pair(S):
    h1 = lancet_unit(S, -5.5, 4.0, apex=41.5)
    h2 = lancet_unit(S, 5.5, 4.0, apex=41.5)
    ah, Rh = 10.6, 21.2
    zsh = 41.5 - arch_h(4.0, 9.6)
    cz = 45.2
    circ = circle(0, cz, 3.2, 16)
    S["Stone"].add(prism([[(-13, 0), (13, 0), (13, 58), (-13, 58)], h1, h2, circ], -2.0, 2.0))
    rose_glass(S["GlassR"], 0.0, cz, 3.4, 0.4, 0.7, cells=8, nseg=48, nring=5)
    for sgn, y in ((-1, -2.0), (1, 2.0)):
        archivolt(S["Tracery"], ah, zsh, Rh, [(0.0, [("roll", 0.8, 0.7), ("cove", 0.7, 0.5), ("roll", 1.4, 1.1)])], y, sgn, z0=1.5, n=12, crock=(1.2, 2.8, 0.2))
        foil(S["Tracery"], 0, cz, 3.7, 5, y, sgn, 0.7, 0.9)
    foil(S["Tracery"], 0, cz, 3.0, 4, 0.0, 1.0, 0.45, 0.8, True)
    S["Tracery"].add(box(-13.4, 13.4, -2.4, 2.4, 0.0, 0.5))
    wimperg(S["Tracery"], S["Crockets"], 14.0, 42.0, 26.0, -3.6, 1.0, arc=arch(ah, zsh, Rh, 3.6, 18), foil_r=2.4, foil_z=60.0, crock=1.3)
    for sx in (-1, 1):
        colonnette(S["Stone"], sx * 12.4, -2.3, 0.5, 57.5, 0.6, 6)
        pin_cluster(S["Pinnacles"], S["Crockets"], sx * 11.8, -0.2, 58.0, 2.4, 15.0, 2, 2)
    S["Tracery"].add(box(-13.3, 13.3, -2.5, 2.5, 57.2, 58.0))


def portal_great(S):
    """West portal (ref_01/03/05): six receding orders (voussoir figures on 1/3/5, foliage crockets on 2/4), jamb statues,
    trumeau with figure, lintel + tympanum (mandorla figure, rows of small figures), crocketed wimperg with a glazed rose,
    flanking buttress towers with niches and pinnacle clusters. Doorways: two 5.6 x 17 openings beside the trumeau; the rear
    passage keeps the a=7 / apex 28 arch for Door_Iron and Portcullis."""
    st, tr, cr, pn, ds = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"], S["Dress"]
    a0, R0 = 7.0, 16.8
    zs = 34.0 - arch_h(a0, R0)
    nord, dstep, ystep = 6, 2.9, 2.0
    yfront = lambda i: -1.5 - ystep * (i + 1)  # front face of order slab i
    ar_pass = arch(7.0, 28.0 - arch_h(7.0, 15.4), 15.4, 0, 12)
    st.add(prism([[(-24, 0), (-24, 58), (24, 58), (24, 0), (7.0, 0)] + ar_pass[::-1] + [(-7.0, 0)]], -1.5, 8.0))
    for i in range(nord):
        d = dstep * i
        ar = arch(a0, zs, R0, d, 16)
        st.add(prism([[(-24, 0), (-24, 58), (24, 58), (24, 0), (a0 + d, 0)] + ar[::-1] + [(-(a0 + d), 0)]], yfront(i), yfront(i) + ystep))
        tr.add(sweep(arch_ext(a0, zs, R0, d, 0.0, 16), [(0.0, 0.0), (0.45, 0.0), (0.45, -0.35), (0.0, -0.6)], yfront(i), 1.0))
        dc = d + dstep - 0.95  # step corner between order i and order i+1
        yc = yfront(i) - 0.95 + 0.3
        st.add(bxm(1, a0 + d, a0 + d + dstep, yfront(i) - 0.6, yfront(i) + 0.2, 0.0, 3.2))
        st.add(bxm(-1, a0 + d, a0 + d + dstep, yfront(i) - 0.6, yfront(i) + 0.2, 0.0, 3.2))
        for sx in (-1, 1):
            if 1 <= i <= 4:
                colonnette(st, sx * (a0 + dc), yc, 15.2, zs, 0.75, 8)
                statue_niche(ds, cr, sx * (a0 + dc), yc + 0.6, 4.6, 8.4, 2.2)
            else:
                colonnette(st, sx * (a0 + dc), yc, 3.2, zs, 0.75, 8)
        path = arch(a0, zs, R0, dc, 24)
        if i % 2 == 1:  # voussoir figures standing along the arc, heads toward the apex, each under a small canopy
            pts = clean(path, False)
            segs = [(pts[j], pts[j + 1], math.hypot(pts[j + 1][0] - pts[j][0], pts[j + 1][1] - pts[j][1])) for j in range(len(pts) - 1)]
            tot = sum(g[2] for g in segs)
            nf = max(4, int(tot / 3.1))
            for f in range(nf):
                s_, acc = (f + 0.5) / nf * tot, 0.0
                for p, q, l in segs:
                    if acc + l >= s_:
                        u = (s_ - acc) / l
                        pos, t = (p[0] + u * (q[0] - p[0]), p[1] + u * (q[1] - p[1])), ((q[0] - p[0]) / l, (q[1] - p[1]) / l)
                        break
                    acc += l
                if pos[0] > 0:
                    t = (-t[0], -t[1])
                Tf = frame((pos[0], yc - 0.4, pos[1]), (t[1], 0.0, -t[0]), (t[0], 0.0, t[1]))
                ds.add(statuette(2.3, 6), Tf)
                canopy(cr, Tf @ Tr(0, 0, 2.4), 1.2, 0.9)
        else:
            tr.add(sweep(path, [(0.75 * math.cos(2 * math.pi * q / 10), 0.75 * math.sin(2 * math.pi * q / 10)) for q in range(10)], yc, 1.0))
            if i in (2, 4):
                path_crockets(cr, path, yc - 0.6, 0.9, 1.6)
    archivolt(tr, a0, zs, R0, [(dstep * nord, [("roll", 1.0, 0.9), ("cove", 0.8, 0.6), ("roll", 1.6, 1.4), ("flat", 1.0, 0.6)])], yfront(nord - 1), -1,
              z0=0.0, n=18)
    # trumeau, lintel, tympanum
    yt = yfront(0)
    st.add(box(-1.25, 1.25, yt - 0.6, -1.5, 0.0, 17.0))
    statue_niche(ds, cr, 0.0, yt - 0.6, 4.4, 7.6, 2.3)
    st.add(box(-a0 - 0.2, a0 + 0.2, yt - 0.4, -1.5, 17.0, 19.0))
    tym = [(x, z) for x, z in arch(a0, zs, R0, 0, 16) if z > 19.0]
    st.add(prism([clean([(-a0, 19.0)] + tym + [(a0, 19.0)])], yt + 0.4, -1.5))
    ds.add(statuette(6.2, 8), Tr(0.0, yt + 0.1, 20.2))
    tr.add(sweep([(math.cos(2 * math.pi * q / 28) * 2.4, 24.0 + math.sin(2 * math.pi * q / 28) * 4.6) for q in range(28)], barf(0.4, 0.6), yt + 0.4, -1, closed=True))
    for sx in (-1, 1):
        for j in range(3):
            ds.add(statuette(2.2, 6), Tr(sx * (3.5 + j * 1.15), yt + 0.2, 19.2))
        for j in range(2):
            ds.add(statuette(2.0, 6), Tr(sx * (3.4 + j * 1.1), yt + 0.2, 22.4))
        tr.add(box(sx * 2.9, sx * 6.9, yt, yt + 0.4, 21.6, 22.0) if sx > 0 else box(-6.9, -2.9, yt, yt + 0.4, 21.6, 22.0))
        for cxd in (sx * 4.1,):  # cusped doorway heads under the lintel
            for dx in (-1, 1):
                place_spear(tr, cxd + dx * 2.6, yt - 0.2, 16.6, -dx * 0.5, -0.86, 1.0, 1.3, 0.5)
    # gable (wimperg) over the portal with a glazed rose
    zb, hw, hg, yg = 40.0, 25.5, 47.0, yfront(nord - 1) - 1.8
    ext = arch(a0, zs, R0, dstep * nord + 4.6, 24)
    rz, rr = 67.0, 6.6
    loops_poly = [(-hw, zb)] + [(x, z) for x, z in ext if z > zb + 0.05 and abs(x) < hw * (1 - (z - zb) / hg) - 0.3] + [(hw, zb), (0.0, zb + hg)]
    st.add(prism([clean(loops_poly), circle(0, rz, rr, 40)], yg - 0.9, yg + 0.9))
    for sx in (-1, 1):
        p0, p1 = (sx * hw, yg, zb), (0.0, yg, zb + hg)
        edge_rib(tr, p0, p1, 2.4, (sx * hg, 0, hw))
        crockets(cr, p0, p1, (sx * hg, 0, hw), 2.2, 3.6, 0.06, 0.92, 0.35)
    finial(cr, 0.0, yg, zb + hg - 0.3, 1.6)
    tr.add(sweep(circle(0, rz, rr, 40), mould([("roll", 0.5, 0.5), ("cove", 0.4, 0.4), ("roll", 0.7, 0.7)]), yg - 0.9, -1, closed=True, flip=True))
    rose(tr, S["GlassR"], 0.0, rz, rr, 8, yg)
    for sx in (-1, 1):
        foil(tr, sx * 9.0, 52.0, 2.6, 3, yg - 0.9, -1, 0.35, 0.6)
    # flanking buttress towers
    yb = yfront(nord - 1) - 2.6
    for sx in (-1, 1):
        st.add(bxm(sx, 22.0, 29.0, yb, 8.0, 0.0, 62.0))
        local(S, Tr(sx * 25.5, yb, 0.0), lambda L: (blind_arcade(L["Tracery"], -3.2, 3.2, 3.0, 14.0, 0.0, 2, 0.5),
                                                    statue_niche(L["Stone"], L["Crockets"], 0.0, 0.0, 22.0, 7.5, 3.0),
                                                    blind_arcade(L["Tracery"], -3.2, 3.2, 36.0, 22.0, 0.0, 2, 0.5)))
        for zb_ in (19.5, 34.0, 61.0):
            tr.add(bxm(sx, 21.6, 29.4, yb - 0.6, 8.4, zb_ - 1.0, zb_))
        pin_cluster(pn, cr, sx * 25.5, yb + 3.6, 62.0, 5.2, 32.0, 2, 4)
        gargoyle(S["Dress"], (sx * 25.5, yb, 58.0), (0, -1), 1.3)
        colonnette(st, sx * 22.2, yb - 0.2, 0.5, 60.5, 0.7, 8)
        colonnette(st, sx * 28.8, yb - 0.2, 0.5, 60.5, 0.7, 8)
    blind_arcade(tr, -22.0, 22.0, 51.5, 6.5, yfront(nord - 1), 12, 0.5)
    tr.add(box(-22.0, 22.0, yfront(nord - 1) - 1.2, 8.0, 57.4, 58.6))
    tr.add(xext([(yfront(nord - 1) - 1.4, 0.0), (8.0, 0.0), (8.0, 0.8), (yfront(nord - 1) - 1.0, 0.8)], -29.0, 29.0))


# ============================================================================================ GROUP A/B/E (mac-53 density pass)
def bay(S, open_h):
    """Arcade bay 40 wide: pointed arch with crocketed archivolts and Y tracery, cusped spandrel foils, crocketed wimperg over the
    arch on both faces, pier buttresses with set-off gablets, blind panels and gargoyles, corbel-table cornice, pierced
    balustrade with pinnacle clusters."""
    a, R = 16.0, 32.0
    rise = arch_h(a, R)
    zs, zt = open_h - rise, open_h + 12.0
    ar = arch(a, zs, R, 0, 12)
    st, tr, pn, cr = S["Stone"], S["Tracery"], S["Pinnacles"], S["Crockets"]
    st.add(prism([[(-20, 0), (-20, zt), (20, zt), (20, 0), (a, 0)] + ar[::-1] + [(-a, 0)]], -4, 4))
    for sx in (-1, 1):
        st.add(bxm(sx, 16, 20, -6, 6, 0, zt))
        st.add(bxm(sx, 15.4, 20, -6.6, 6.6, 0, 2.6))
        st.add(bxm(sx, 15.7, 20, -6.3, 6.3, 2.6, 4.0))
        tr.add(bxm(sx, 15.2, 20, -6.4, 6.4, zs - 1.5, zs))
        for yy in (-6, 6):
            for xo, rr in ((16.9, 0.55), (19.1, 0.55)):
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
    prof = [(-7.4, zt), (7.4, zt), (7.4, zt + 0.7), (6.5, zt + 1.3), (7.0, zt + 1.7), (7.0, zt + 2.4), (6.2, zt + 3.0), (-6.2, zt + 3.0), (-7.0, zt + 2.4), (-7.0, zt + 1.7), (-6.5, zt + 1.3), (-7.4, zt + 0.7)]
    tr.add(xext(prof, -20, 20))
    for yy in (-1, 1):
        for i in range(15):
            c = -18.67 + i * 2.667
            tr.add(loft([[(c - 0.55, yy * 7.3 - 0.6, zt - 0.1), (c + 0.55, yy * 7.3 - 0.6, zt - 0.1), (c + 0.55, yy * 7.3 + 0.6, zt - 0.1), (c - 0.55, yy * 7.3 + 0.6, zt - 0.1)],
                         [(c - 0.3, yy * 6.6 - 0.3, zt - 2.4), (c + 0.3, yy * 6.6 - 0.3, zt - 2.4), (c + 0.3, yy * 6.6 + 0.3, zt - 2.4), (c - 0.3, yy * 6.6 + 0.3, zt - 2.4)]]))
    ztop = zt + 3.0

    def face(L):  # one long face (front; the back is the same rotated 180 deg)
        for sx in (-1, 1):  # pier buttress with two set-offs, gablets, blind panel, gargoyle
            xa, xb = sorted((sx * 16.4, sx * 19.6))
            z1 = max(zs * 0.5, 14.0)
            L["Stone"].add(box(xa, xb, -8.8, -6.0, 0.0, z1))
            L["Tracery"].add(xext([(-8.8, z1), (-6.0, z1), (-6.0, z1 + 1.8), (-8.0, z1 + 0.4)], xa, xb))
            L["Stone"].add(box(xa + 0.2, xb - 0.2, -8.0, -6.0, z1, zt - 0.2))
            blind_arcade(L["Tracery"], xa + 0.4, xb - 0.4, 3.0, z1 - 5.0, -8.8, 1, 0.4)
            k = max(1, math.ceil((zt - z1 - 6.0) / 18.0))
            hz = (zt - z1 - 6.0) / k
            for q in range(k):
                blind_arcade(L["Tracery"], xa + 0.6, xb - 0.6, z1 + 3.0 + q * hz, hz - 0.4, -8.0, 1, 0.4)
            wimperg(L["Tracery"], L["Crockets"], 1.5, z1 + 0.4, 4.2, -8.6, 0.4, crock=0.5, cx=sx * 18.0)
            gargoyle(L["Dress"], (sx * 18.0, -8.0, zt - 3.2), (0, -1), 1.0)
        ext = arch(a, zs, R, 6.0, 18)
        hw_, zb_, hg_ = 16.0, open_h - 6.0, 22.0
        back = [(-hw_, zb_)] + [(x, z) for x, z in ext if z > zb_ + 0.05 and abs(x) < hw_ * (1 - (z - zb_) / hg_) - 0.3] + [(hw_, zb_), (0.0, zb_ + hg_)]
        L["Stone"].add(prism([clean(back)], -8.0, -4.0))  # backing so the gable stands on the wall, in front of the cornice
        wimperg(L["Tracery"], L["Crockets"], hw_, zb_, hg_, -8.4, 0.8, arc=ext, foil_r=2.0, foil_z=open_h + 10.0, crock=1.5)
    local(S, Matrix.Identity(4), face)
    local(S, Rz(math.pi), face)
    for yy in (-5.4, 5.4):
        balustrade(pn, pn, -16.0, 16.0, ztop, yy, 7.0)
        for sx in (-1, 1):
            pin_cluster(pn, S["Crockets"], sx * 18.0, yy, ztop, 3.0, 17.0, 2, 2, rot=math.pi / 4)


def bastion_face(S):
    """Battered bastion 40 x 80: irregular coursed rubble-ashlar (random course heights, block lengths and proud faces, chamfered
    arrises, a few missing blocks), blind relieving arch, string course, machicolation, gargoyles, gothic parapet."""
    st, tr, pn, cr = S["Stone"], S["Tracery"], S["Pinnacles"], S["Crockets"]
    rng = np.random.default_rng(17)
    yf = lambda z: -7.0 + 7.0 * z / 80.0
    st.add(loft([[(-20, yf(0) + 0.7, 0), (20, yf(0) + 0.7, 0), (20, 7.0, 0), (-20, 7.0, 0)],
                 [(-20, yf(72) + 0.7, 72), (20, yf(72) + 0.7, 72), (20, 7.0, 72), (-20, 7.0, 72)]]))
    z, row = 0.0, 0
    while z < 71.9:
        hh = min(rng.uniform(2.1, 3.5) * (1.3 if z < 9 else 1.0), 72.0 - z)
        if 72.0 - z - hh < 1.2:
            hh = 72.0 - z
        x = -20.0
        first = True
        while x < 19.95:
            ln = (4.6 if row % 2 else 2.9) if first else rng.uniform(2.6, 6.8)
            if x + ln > 18.6:
                ln = 20.0 - x
            first = False
            if 3.0 < z < 66 and -17 < x < 16 and rng.random() < 0.035:
                x += ln
                continue
            pr = rng.uniform(0.0, 0.5)
            y0 = yf(z + hh / 2) - pr
            ins = rng.uniform(0.12, 0.32)
            j = 0.07
            x0, x1, z0, z1 = x + j, x + ln - j, z + j, z + hh - j
            st.add(loft([[(x0, y0 + 1.6, z0), (x1, y0 + 1.6, z0), (x1, y0 + 1.6, z1), (x0, y0 + 1.6, z1)],
                         [(x0, y0 + ins, z0), (x1, y0 + ins, z0), (x1, y0 + ins, z1), (x0, y0 + ins, z1)],
                         [(x0 + ins, y0, z0 + ins), (x1 - ins, y0, z0 + ins), (x1 - ins, y0, z1 - ins), (x0 + ins, y0, z1 - ins)]]))
            x += ln
        z += hh
        row += 1
    # blind relieving arch (voussoirs proud of the rubble) with a recessed tympanum
    a, zsa = 7.0, 8.0
    vin, vout = arch(a, zsa, 2 * a, 0.0, 15), arch(a, zsa, 2 * a, 2.2, 15)
    for i in range(len(vin) - 1):
        yv = yf((vin[i][1] + vin[i + 1][1]) / 2) - 0.8
        tr.add(prism([[vin[i], vout[i], vout[i + 1], vin[i + 1]]], yv, yv + 1.6))
    for sx in (-1, 1):
        tr.add(bxm(sx, a - 1.0, a + 1.2, yf(4) - 0.8, yf(4) + 1.0, 0.0, zsa))
    # string course following the batter, gargoyles, machicolation and the parapet
    tr.add(xext([(yf(40) - 0.8, 39.6), (yf(40) + 0.6, 39.6), (yf(41.6) + 0.6, 41.6), (yf(41.6) - 0.4, 41.3)], -20, 20))
    for gx in (-12.0, 0.0, 12.0):
        gargoyle(S["Dress"], (gx, yf(68) - 0.4, 68.0), (0, -1), 1.3)
    st.add(loft([[(-20, yf(72) - 0.2, 72), (20, yf(72) - 0.2, 72), (20, 7.0, 72), (-20, 7.0, 72)],
                 [(-20, yf(80) - 0.2, 80), (20, yf(80) - 0.2, 80), (20, 7.0, 80), (-20, 7.0, 80)]]))
    for i in range(16):
        c = -18.75 + i * 2.5
        tr.add(loft([rect(c, yf(73) - 0.6, 73.0, 0.45, 0.6), rect(c, yf(77) - 1.6, 77.0, 0.65, 1.4)]))
    tr.add(box(-20.0, 20.0, yf(80) - 2.6, yf(80) + 0.2, 77.0, 80.0))
    ytop = yf(80)
    parapet_gothic(S, -20, 20, 80.0, ytop + 1.2)
    for px in (-18.5, -6.65, 6.65, 18.5):
        pinnacle(pn, cr, px, ytop + 1.2, 80.0, 2.4, 13.0, 2)


def buttress_pier(S):
    """Five-stage buttress: blind cusped panels, angle shafts, crocketed gablets on every set-off, engaged pinnacles, gargoyles,
    crowned by a pinnacle cluster."""
    st, tr, cr, pn = S["Stone"], S["Tracery"], S["Crockets"], S["Pinnacles"]
    z = 0.0
    for j, h in enumerate([13, 12, 11, 10, 8]):
        hw, yf = 6.0 - 0.55 * j, -18.0 + 3.2 * j
        z1 = z + h
        st.add(box(-hw, hw, yf, 6.0, z, z1))
        if j < 4:
            yn = -18.0 + 3.2 * (j + 1)
            tr.add(xext([(yf, z1), (yn, z1), (yn, z1 + 1.3)], -hw, hw))
            wimperg(tr, cr, (6.0 - 0.55 * (j + 1)) * 0.7, z1 + 0.6, 4.6 - 0.4 * j, yn - 0.35, 0.5, foil_r=0.7, foil_z=z1 + 2.2, crock=0.6)
            for sx in (-1, 1):
                pinnacle(pn, cr, sx * (hw - 0.6), yf + 0.7, z1, 1.1, 6.0 - 0.6 * j, 1)
        a = hw * 0.42
        sill, zs = z + 2.6, z + 1.5 + 0.35 * (h - 3) + 1.4
        hole = [(-a, sill)] + arch(a, zs, 2 * a, 0, 7) + [(a, sill)]
        tr.add(prism([[(-hw + 0.5, z + 1.5), (hw - 0.5, z + 1.5), (hw - 0.5, z1 - 1.5), (-hw + 0.5, z1 - 1.5)], hole], yf - 0.5, yf))
        archivolt(tr, a, zs, 2 * a, [(0.0, [("roll", 0.5, 0.5)])], yf - 0.5, -1, z0=sill, n=7, crock=(0.5, 1.3, 0.15))
        ar = arch(a, zs, 2 * a, 0, 9)
        for q in (ar[2], ar[-3]):
            place_spear(tr, q[0], yf - 0.25, q[1], 0.6 if q[0] < 0 else -0.6, -0.8, a * 0.4, a * 0.45, 0.4)
        for sx in (-1, 1):  # blind panels on the flanks
            T = Tr(sx * hw, (yf + 6.0) / 2, 0) @ Rz(sx * math.pi / 2)
            local(S, T, lambda L, z=z, h=h, yf=yf: blind_arcade(L["Tracery"], -(6.0 - yf) / 2 + 0.8, (6.0 - yf) / 2 - 0.8, z + 1.4, h - 2.8, 0.0,
                                                               max(1, int((6.0 - yf) / 4.5)), 0.35))
        if j < 3:
            for sx in (-1, 1):
                colonnette(st, sx * (hw - 0.3), yf + 0.1, z, z1 - 0.2, 0.55, 6)
        if j:
            tr.add(xext([(yf - 0.4, z), (yf, z), (yf, z + 0.9), (yf - 0.4, z + 0.6)], -hw, hw))
        if j in (1, 3):
            gargoyle(S["Dress"], (0.0, yf, z1 - 1.0), (0, -1), 1.0 - 0.15 * j)
        z = z1
    pin_cluster(pn, cr, 0.0, 0.4, z, 4.4, 18.0, 3, 4)


def flying_buttress(S, L):
    """Flyer: intrados roll, web pierced by a row of cusped lancet lights with moulded surrounds, crocketed coping with finials,
    gargoyle spout at the low end."""
    st, tr, cr = S["Stone"], S["Tracery"], S["Crockets"]
    rise = 0.42 * L
    Ra = (L * L + rise * rise) / (2 * rise)
    thm = math.asin(min(1.0, L / Ra))
    m = 18
    intr = [(Ra * math.sin(thm * i / m), Ra * (1 - math.cos(thm * i / m))) for i in range(m + 1)]
    tlo, thi = 5.5, 7.0
    ramp = lambda x: tlo + (rise + thi - tlo) * x / L
    zin = lambda x: Ra * (1 - math.cos(math.asin(max(-1.0, min(1.0, x / Ra)))))
    poly = intr + [(L, rise + thi), (0.0, tlo)]
    n = max(4, int(L / 8.0))
    pitch = L * 0.84 / n
    holes, lights = [], []
    for i in range(n):
        x = L * 0.08 + pitch * (i + 0.5)
        a = pitch * 0.3
        zl = max(zin(x - a), zin(x + a)) + 0.9
        zt = min(ramp(x - a), ramp(x + a)) - 0.9
        if zt - zl < arch_h(a, 2.2 * a) + 0.8:
            continue
        hole, zs, Rr = lancet_hole(a, zl, zt, 1.1)
        holes.append([(x + px, pz) for px, pz in hole])
        lights.append((x, a, zs, Rr, zl))
    st.add(prism([poly] + holes, -2.5, 2.5))
    for sgn, y in ((-1, -2.5), (1, 2.5)):
        for (x, a, zs, Rr, zl), hole in zip(lights, holes):
            tr.add(sweep(hole, barf(0.45, 0.5), y, sgn, closed=True))
            ar = arch(a, zs, Rr, 0, 9)
            for q in (ar[2], ar[-3]):
                place_spear(tr, x + q[0], y, q[1], 0.6 if q[0] < 0 else -0.6, -0.8, a * 0.45, a * 0.5, 1.0)
        tr.add(sweep(intr, mould([("roll", 0.7, 0.7)]), y, sgn, flip=True))
    tr.add(prism([[(0.0, tlo), (L, rise + thi), (L, rise + thi + 1.1), (0.0, tlo + 1.1)]], -3.1, 3.1))
    for sy in (-1, 1):
        crockets(cr, (0.0, sy * 3.0, tlo + 1.1), (L, sy * 3.0, rise + thi + 1.1), (0, sy, 0.4), 2.0, 3.2, 0.06, 0.94, 0.3)
    for i in range(1, int(L / 10.0) + 1):
        x = i * L / (int(L / 10.0) + 1)
        finial(cr, x, 0.0, ramp(x) + 1.0, 0.6)
    st.add(box(L - 1.2, L + 3.5, -3.6, 3.6, rise + 2.0, rise + thi + 2.4))
    tr.add(box(-3.0, 0.8, -3.4, 3.4, 0.0, 1.2))
    gargoyle(S["Dress"], (0.0, 0.0, tlo + 0.2), (-1, 0), 1.1)
    S.shift(-L / 2)


def viaduct_bay(S):
    """Viaduct bay 30 x 120: four-order pointed arch (each order rolled, outer order crocketed), clustered-shaft piers with
    stepped cutwaters (weathered offsets, pyramidal caps), blind-panelled pier faces, cusped spandrel foils, corbel-table deck."""
    st, tr, cr, ds = S["Stone"], S["Tracery"], S["Crockets"], S["Dress"]
    a, Rr, zs, zdk = 12.0, 24.0, 88.0, 116.0
    base = [(-15, zs), (-15, zdk), (15, zdk), (15, zs)]
    roll = [(0.45 * math.cos(2 * math.pi * q / 8), 0.45 * math.sin(2 * math.pi * q / 8)) for q in range(8)]
    for d, y0, y1 in ((0.0, -2.0, 2.0), (0.9, -3.0, -2.0), (1.8, -4.0, -3.0), (2.7, -5.0, -4.0), (0.9, 2.0, 3.0), (1.8, 3.0, 4.0), (2.7, 4.0, 5.0)):
        st.add(prism([base + arch(a, zs, Rr, d, 16)[::-1]], y0, y1))
        if d > 0:  # rolled arris on each stepped order
            tr.add(sweep(arch(a, zs, Rr, d - 0.45, 16), roll, y0 if y0 < 0 else y1, 1.0))
    for sgn, y in ((-1, -5.0), (1, 5.0)):
        archivolt(tr, a, zs, Rr, [(2.7, [("roll", 0.6, 0.6), ("cove", 0.5, 0.4), ("roll", 0.8, 0.8)])], y, sgn, n=16, crock=(1.4, 3.0, 0.3))
        for sx in (-1, 1):
            xq = sx * 12.6
            za = archz(xq, a, zs, Rr, 4.6)
            rq = min(2.2, (zdk - za) / 2 - 1.2)
            if rq > 1.2:
                foil(tr, xq, (za + zdk) / 2, rq, 4, y, sgn, 0.6, 0.8)
    for sx in (-1, 1):
        st.add(bxm(sx, 12.0, 15.0, -5.0, 5.0, 0.0, zs))
        st.add(bxm(sx, 10.8, 15.0, -6.4, 6.4, 0.0, 6.0))
        tr.add(xext([(-6.4, 6.0), (6.4, 6.0), (5.2, 7.2), (-5.2, 7.2)], *sorted((sx * 10.8, sx * 15.0))))
        tr.add(bxm(sx, 11.2, 15.0, -5.6, 5.6, zs - 1.6, zs))
        tr.add(bxm(sx, 11.6, 15.0, -5.5, 5.5, zs - 9.0, zs - 8.0))
        for yy in (-3.2, 0.0, 3.2):
            colonnette(st, sx * 12.2, yy, 7.2, zs - 1.6, 0.62 if yy else 0.8, 8)
        for yy in (-1, 1):  # half cutwater (the neighbour bay mirrors it): stepped prow, weathered offset, pyramidal cap
            rings = [(0.0, 12.5), (30.0, 12.0), (31.6, 10.8), (48.0, 10.8), (56.0, 5.2)]
            st.add(loft([[(sx * 12.0, yy * 5.0, z), (sx * 15.0, yy * 5.0, z), (sx * 15.0, yy * tip, z)] for z, tip in rings]))
            tr.add(loft([[(sx * 11.8, yy * 5.0, z), (sx * 15.0, yy * 5.0, z), (sx * 15.0, yy * (tip + 0.4), z)] for z, tip in ((29.4, 12.0), (30.4, 12.5), (31.2, 12.5))]))
            T = Tr(sx * 13.5, yy * 5.0, 0) @ Rz(0.0 if yy < 0 else math.pi)
            local(S, T, lambda L: blind_arcade(L["Tracery"], -1.3, 1.3, 58.0, zs - 10.0 - 58.0, 0.0, 1, 0.4))
            gargoyle(ds, (sx * 13.5, yy * 5.6, zdk - 3.4), (0, yy), 1.1)
            finial(cr, sx * 15.0, yy * 5.6, 56.0, 0.7)
    for yy in (-3.6, 0.0, 3.6):
        tr.add(sweep(arch(a, zs, Rr, 0.0, 14), [(-0.3, -0.7), (0.5, -0.7), (0.95, -0.35), (0.95, 0.35), (0.5, 0.7), (-0.3, 0.7)], yy, 1.0, flip=True))
    tr.add(xext([(-7.6, zdk), (7.6, zdk), (7.6, zdk + 1.0), (6.4, zdk + 1.7), (7.0, zdk + 2.2), (7.0, zdk + 3.4), (6.0, zdk + 4.0), (-6.0, zdk + 4.0),
                 (-7.0, zdk + 3.4), (-7.0, zdk + 2.2), (-6.4, zdk + 1.7), (-7.6, zdk + 1.0)], -15, 15))
    for yy in (-1, 1):
        for i in range(11):
            c = -13.5 + i * 2.7
            tr.add(loft([[(c - 0.6, yy * 7.0 - 0.6, zdk), (c + 0.6, yy * 7.0 - 0.6, zdk), (c + 0.6, yy * 7.0 + 0.6, zdk), (c - 0.6, yy * 7.0 + 0.6, zdk)],
                         [(c - 0.3, yy * 6.0 - 0.3, zdk - 2.4), (c + 0.3, yy * 6.0 - 0.3, zdk - 2.4), (c + 0.3, yy * 6.0 + 0.3, zdk - 2.4), (c - 0.3, yy * 6.0 + 0.3, zdk - 2.4)]]))


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
STACK = {"Tower_Corner_Stage": {"h": 60.0, "bottom": "square 32 core (walls +-16) + corner piers x,y in +-[13.6, 19.0]", "top": "same, flat at z 60"},
         "Spire_Base_Oct": {"h": 30.0, "bottom": "square 32 + corner piers (sits on Tower_Corner_Stage)", "top": "octagon R14 (vertices at 22.5+k*45 deg)",
                            "crown": "corner pinnacle clusters rise to z ~45"},
         "Spire_Belfry_Stage": {"h": 40.0, "bottom": "octagon R14", "top": "deck octagon R13.6 (Lucarne R13 sits on it)", "crown": "wimpergs, balustrade, 8 pinnacle clusters to z ~58"},
         "Spire_Lucarne_Mid": {"h": 48.0, "bottom": "octagon R13", "top": "octagon R6.5", "crown": "ring of 8 small pinnacles to z ~56"},
         "Spire_Needle_Tip": {"h": 56.0, "bottom": "octagon R6.5", "top": "point; finial + iron cross to z ~68"},
         "Spire_Broken_Top": {"h": 29.0, "bottom": "octagon R6.5", "top": "broken"}}


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


def _wn(x, y, z):
    """Cheap continuous noise ~[-1.9, 1.9] (sum of incommensurate sines): same input -> same output, so welded seams stay closed."""
    return math.sin(x * 0.71 + y * 1.13 + z * 0.37) + 0.5 * math.sin(x * 1.9 - z * 1.3 + y * 0.5 + 1.7) + 0.35 * math.sin(y * 2.3 + z * 2.9 - x * 0.8 + 0.4)


def weather_co(c, amp, zlo=0.0, zhi=None):
    """Erode masonry out of true: displace by smooth noise, faded to zero within 1.5 studs of the stacking planes zlo/zhi."""
    x, y, z = c
    f = min(1.0, max(0.0, (z - zlo) / 1.5))
    if zhi is not None:
        f = min(f, max(0.0, abs(z - zhi) / 1.5))
    if f <= 0.0:
        return c
    q = 0.45
    return (x + amp * f * _wn(x * q, y * q, z * q) * 0.5, y + amp * f * _wn(y * q + 3.1, z * q, x * q) * 0.5, z + amp * f * 0.3 * _wn(z * q, x * q + 1.3, y * q))


def make_obj(name, mat, faces, uvfn=None, weather=None):
    tile = TILE[mat]
    verts, polys, uvs = [], [], []
    for co, nrm, _ in faces:
        b = len(verts)
        if weather:
            co = [weather_co(c, *weather) for c in co]
        verts += co
        polys.append(tuple(range(b, b + len(co))))
        ax, ay, az = abs(nrm[0]), abs(nrm[1]), abs(nrm[2])
        if uvfn is not None:
            ctr = tuple(sum(c[i] for c in co) / len(co) for i in range(3))
            for c in co:
                uvs += uvfn(c, ctr)
            continue
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


WEATHER_AMP = 0.16


def ledge(co, nrm, area):
    """Frost only on ledges (mac-53): up-facing, narrow in plan (sills, copings, set-offs, string courses), patchy."""
    if nrm[2] < 0.72 or area < 0.25:
        return False
    xs, ys = [c[0] for c in co], [c[1] for c in co]
    if min(max(xs) - min(xs), max(ys) - min(ys)) > 4.2:
        return False
    cx, cy, cz = (sum(xs) / len(xs), sum(ys) / len(ys), sum(c[2] for c in co) / len(co))
    return _wn(cx * 0.21, cy * 0.21, cz * 0.21) > -0.75


def write_manifest(man=None):
    """Merge into <OUT>/manifest.json: pieces built this run replace their entries, pieces not built (VESP_ONLY runs, pieces
    owned by other scripts) are kept. shortcut: a piece deleted from every PLAN lingers until removed by hand."""
    man = manifest if man is None else man
    mf = OUT / "manifest.json"
    if mf.exists():
        try:
            old = json.loads(mf.read_text())
        except ValueError:
            old = {}
        for k, v in old.get("pieces", {}).items():
            man["pieces"].setdefault(k, v)
    mf.write_text(json.dumps(man, indent=2))


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
            if ledge(co, nrm, area):
                dz = 0.12 if nrm[2] >= 0.8 else 0.08
                frost.append(([(x, y, z + dz) for x, y, z in co], nrm, area))
    if frost:
        data["Frost"] = frost
    objs, subs = [], {}
    hst = STACK.get(name, {}).get("h")
    for sname, faces in data.items():
        wz = None if sname in NOWEATHER else (WEATHER_AMP, 0.0, hst)
        for i, ch in enumerate(chunks(faces)):
            o, tris = make_obj(f"{name}__{sname}" + (f"_{i + 1}" if i else ""), SUBMAT[sname], ch, getattr(S.get(sname), "uvfn", None), wz)
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


def mannequin(sc, loc):
    """Render-only 5-stud figure for scale (not exported)."""
    vs, fs = lathe([(0.55, 0.0), (0.6, 0.4), (0.5, 2.4), (0.78, 3.5), (0.45, 3.95), (0.3, 4.1), (0.42, 4.45), (0.35, 4.85), (0.0, 5.0)], 12)
    me = bpy.data.meshes.new("Mannequin")
    me.from_pydata(vs, [], fs)
    me.update()
    m = bpy.data.materials.new("Mannequin")
    m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.55, 0.5, 0.42, 1)
    me.materials.append(m)
    me.shade_smooth()
    o = bpy.data.objects.new("Mannequin", me)
    o.location = loc
    sc.collection.objects.link(o)
    return o


def backdrop(sc, x0, x1, y0, y1, z0, z1):
    """Render-only soot wall behind an assembly (fills the gaps a real facade would fill)."""
    b = Sub("Vesp_Soot")
    b.add(box(x0, x1, y0, y1, z0, z1))
    o, _ = make_obj("Backdrop", "Vesp_Soot", commit(b))
    return o


def composite(sc, cam, ground, tag, items, tgt, off, res=(1600, 1000), man=None, lens=35):
    """Assembly render: items [(piece, (x, y, z), rotz)] placed in one scene; optional 5-stud mannequin at man."""
    if not all(n in PIECES for n, _, _ in items if not n.startswith("@")):
        return
    V = []
    for n, (x, y, z), rz in items:
        if n.startswith("@backdrop"):
            V.append(backdrop(sc, *x))
            continue
        for o in PIECES[n]:
            c = bpy.data.objects.new("V_" + o.name, o.data)
            c.matrix_world = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z")
            sc.collection.objects.link(c)
            V.append(c)
    if man:
        V.append(mannequin(sc, man))
    ground.scale, ground.location = (900, 900, 1), Vector((0, 0, 0))
    cam.data.lens = lens
    cam.location = Vector(tgt) + Vector(off)
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = str(OUT / "renders" / f"{tag}.png")
    t = time.time()
    bpy.ops.render.render(write_still=True)
    log(f"render {tag} {time.time() - t:.1f}s")
    for o in V:
        bpy.data.objects.remove(o)
    cam.data.lens = 35


# C3: the spire stack Base_Oct + Belfry + Lucarne + Needle (~186 studs to the cross); C3b the lower stages close; D4 the west front.
STK = [("Spire_Base_Oct", (0, 0, 0.0), 0.0), ("Spire_Belfry_Stage", (0, 0, 30.0), 0.0), ("Spire_Lucarne_Mid", (0, 0, 70.0), 0.0),
       ("Spire_Needle_Tip", (0, 0, 118.0), 0.0)]
WEST = [("Portal_Great", (0, 0, 0), 0.0), ("Rose_Window_Great", (0, 8.0, 84.0), 0.0), ("Buttress_Pier", (-36.0, 4.0, 0), 0.0),
        ("Buttress_Pier", (36.0, 4.0, 0), 0.0), ("Lancet_Pair", (-55.0, 6.0, 0), 0.0), ("Lancet_Pair", (55.0, 6.0, 0), 0.0),
        ("Lancet_Tall", (-55.0, 6.0, 72.0), 0.0), ("Lancet_Tall", (55.0, 6.0, 72.0), 0.0), ("Buttress_Pier", (-74.0, 4.0, 0), 0.0),
        ("Buttress_Pier", (74.0, 4.0, 0), 0.0), ("@backdrop", ((-82.0, 82.0, 8.0, 14.0, 0.0, 140.0), 0, 0), 0.0)]
COMPOSITES = [("C3_spire_stack", STK, (0, 0, 92.0), (95.0, -255.0, -62.0), (1000, 1600), (19.0, -24.0, 0.0)),
              ("C3b_spire_stack_low", STK, (0, 0, 40.0), (52.0, -92.0, -30.0), (1600, 1000), (19.0, -24.0, 0.0)),
              ("D4_west_front", WEST, (0, 0, 72.0), (48.0, -235.0, -50.0), (1600, 1000), (8.0, -22.0, 0.0))]


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
    write_manifest()
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
    SHEETS = [t for t in SHEETS if not ONLY or any(n in ONLY for n, _ in t[1])]
    for tag, items in SHEETS:
        items = [(n, s) for n, s in items if n in PIECES]
        if items:
            t = time.time()
            sheet(sc, cam, ground, tag, items)
            log(f"render {tag} {time.time() - t:.1f}s")
    for tag, items, tgt, off, res, man in COMPOSITES:
        composite(sc, cam, ground, tag, items, tgt, off, res, man)
    log("renders done")


if os.environ.get("VESP_NOMAIN") != "1":
    main()

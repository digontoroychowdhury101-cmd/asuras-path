"""Shared helpers for the Vesperhold props / trees scripts (mac-44). Reuses vesperhold_kit.py (mac-42) unchanged by importing
it as a module (VESP_NOMAIN=1): its welded-primitive builder, materials, naming, manifest, GLB export and render sheets.

Adds: new material generators (Wax, Flame, Banner with our sigil, Rope, Water RGBA, DeadBark, Weathered stone), a UV-carrying
primitive path (tubes, revolves, cloth shells) with smooth shading, a mixed finish() and a run() driver.
Arrays are indexed [row = v (bottom first), col = u]; PNGs are saved flipped so they match Blender's UV convention.
"""
import importlib.util
import json
import math
import os
import random
import sys
import time
from pathlib import Path

os.environ["VESP_NOMAIN"] = "1"
HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("vesperhold_kit", HERE / "vesperhold_kit.py")
K = importlib.util.module_from_spec(_spec)
sys.modules["vesperhold_kit"] = K
_spec.loader.exec_module(K)

import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

log, OUT, N = K.log, K.OUT, K.N
SMOOTH_SPLIT = 15500

K.SUBMAT.update({"Figure": "Vesp_Weathered", "Wax": "Vesp_Wax", "Flame": "Vesp_Flame", "Banner": "Vesp_Banner", "Rope": "Vesp_Rope",
                 "Water": "Vesp_Water", "Bark": "Vesp_DeadBark"})
K.TILE.update({"Vesp_Weathered": 16.0, "Vesp_Wax": 6.0, "Vesp_Flame": 8.0, "Vesp_Banner": 8.0, "Vesp_Rope": 4.0, "Vesp_Water": 40.0,
               "Vesp_DeadBark": 16.0})
K.NOFROST.update({"Flame", "Wax", "Banner", "Rope", "Water"})
KIT_MATS = set(K.GENS)


# ============================================================================================ noise
def _h(i, j, k):
    return (math.sin(i * 127.1 + j * 311.7 + k * 74.7 + 1.3) * 43758.5453) % 1.0


def vnoise(x, y=0.0, z=0.0):
    """Smooth value noise in [-1, 1]."""
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = x - xi, y - yi, z - zi
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    c = lambda a, b, d: _h(xi + a, yi + b, zi + d)
    x00, x10 = c(0, 0, 0) + (c(1, 0, 0) - c(0, 0, 0)) * fx, c(0, 1, 0) + (c(1, 1, 0) - c(0, 1, 0)) * fx
    x01, x11 = c(0, 0, 1) + (c(1, 0, 1) - c(0, 0, 1)) * fx, c(0, 1, 1) + (c(1, 1, 1) - c(0, 1, 1)) * fx
    a, b = x00 + (x10 - x00) * fy, x01 + (x11 - x01) * fy
    return (a + (b - a) * fz) * 2 - 1


def fbm(x, y=0.0, z=0.0, o=3):
    s, a, f = 0.0, 1.0, 1.0
    for _ in range(o):
        s += a * vnoise(x * f, y * f, z * f)
        a *= 0.5
        f *= 2.0
    return s / 1.75


# ============================================================================================ new material maps
def field2(h, w, beta, seed, stretch=1.0):
    fy = (np.fft.fftfreq(h) * h).astype(np.float32)
    fx = (np.fft.fftfreq(w) * w).astype(np.float32)
    fu, fv = np.meshgrid(fx, fy)
    spec = np.fft.fft2(np.random.default_rng(seed).standard_normal((h, w)).astype(np.float32))
    out = np.real(np.fft.ifft2(spec / (np.sqrt(fu ** 2 + (fv * stretch) ** 2) + 1.0) ** beta)).astype(np.float32)
    return (out - out.mean()) / out.std()


def gen_weathered():
    f1, f2, f3, pit = K.fld(1.5, 201), K.fld(0.9, 202), K.fld(0.35, 203), K.fld(0.6, 204)
    st = K.fld(1.1, 205, 16.0)
    dark = np.clip(st * 0.5 + 0.1, 0, 1)
    vein = np.clip(1 - np.abs(K.fld(1.3, 206)) * 6, 0, 1)
    v = 0.17 * (1 + 0.22 * f1 + 0.10 * f2 + 0.05 * f3) * (1 - 0.45 * dark) * (1 + 0.35 * vein)
    v = np.clip(v, 0.05, 0.30)
    lich = np.clip((K.fld(1.0, 207) - 1.5) * 1.4, 0, 0.6)[..., None]  # pale frost/lichen patches
    col = np.stack([v * 0.97, v * 1.0, v * 1.07], -1)
    col = col * (1 - lich) + np.array([0.40, 0.42, 0.45], np.float32) * lich
    h = 0.5 + 0.10 * f1 + 0.05 * f2 + 0.03 * f3 - 0.08 * np.clip(pit - 1.3, 0, 2) + 0.05 * vein
    return dict(Color=col, Normal=K.nmap(h.astype(np.float32), 12), Roughness=np.clip(0.80 - 0.2 * dark + 0.06 * f2, 0.3, 1))


def gen_wax():
    f1, f2, f3 = K.fld(1.4, 211), K.fld(0.8, 212), K.fld(0.4, 213)
    drip = K.fld(1.3, 214, 14.0)
    soot = np.clip(drip * 0.45 - 0.3, 0, 0.7)[..., None]
    col = np.array([0.80, 0.74, 0.55], np.float32) * (0.92 + 0.05 * f1[..., None] + 0.03 * f2[..., None])
    col = col * (1 - 0.65 * soot) + np.array([0.05, 0.045, 0.04], np.float32) * 0.65 * soot
    h = 0.5 + 0.12 * f1 + 0.05 * f2 + 0.03 * drip
    return dict(Color=np.clip(col, 0, 1), Normal=K.nmap(h.astype(np.float32), 5), Roughness=np.clip(0.48 + 0.1 * f2, 0.2, 1))


def gen_flame():
    y, x = np.mgrid[0:N, 0:N]
    v, u = y / (N - 1.0), x / (N - 1.0)
    f1, f2 = K.fld(1.1, 221, 6.0), K.fld(0.7, 222)
    g = np.clip(v + 0.05 * f1, 0, 1)[..., None]
    base = np.array([1.0, 0.82, 0.42], np.float32)
    mid = np.array([1.0, 0.50, 0.10], np.float32)
    tip = np.array([0.85, 0.20, 0.03], np.float32)
    col = np.where(g < 0.5, base + (mid - base) * (g / 0.5), mid + (tip - mid) * ((g - 0.5) / 0.5))
    col = col * (0.92 + 0.08 * f2[..., None])
    return dict(Color=np.clip(col, 0, 1), Normal=K.nmap((0.5 + 0.02 * f2).astype(np.float32), 2), Roughness=np.full((N, N), 0.9, np.float32))


def gen_rope():
    y, x = np.mgrid[0:N, 0:N]
    u, v = x / N, y / N
    f1, f2 = K.fld(1.2, 231), K.fld(0.7, 232)
    st = 0.5 + 0.5 * np.sin(2 * np.pi * (u * 4 + v * 48))
    st2 = 0.5 + 0.5 * np.sin(2 * np.pi * (u * 8 - v * 96)) * 0.4
    h = 0.5 + 0.25 * st + 0.05 * st2 + 0.04 * f1
    base = 0.20 * (0.55 + 0.45 * st) * (1 + 0.2 * f1 + 0.1 * f2)
    col = np.stack([base * 1.12, base * 0.88, base * 0.60], -1)
    return dict(Color=np.clip(col, 0, 1), Normal=K.nmap(h.astype(np.float32), 9), Roughness=np.clip(0.9 + 0.05 * f2, 0.6, 1))


def gen_deadbark():
    """u around the trunk, v along it: vertical furrows (stretched noise), ridge plates, frost specks, soot-black fissures."""
    st1, st2, st3 = K.fld(0.9, 241, 9.0), K.fld(1.2, 242, 5.0), K.fld(0.5, 243, 3.0)
    f1, f2, f3 = K.fld(1.4, 244), K.fld(0.8, 245), K.fld(0.35, 246)
    ridge = 1.0 - np.clip(np.abs(st1) * 1.7, 0, 1)  # 1 on plate crest, 0 in the fissure
    ridge = ridge ** 0.8
    cross = np.clip(1 - np.abs(st3) * 2.2, 0, 1) * 0.5  # sparse cross cracks
    h = 0.15 + 0.62 * ridge - 0.12 * cross + 0.05 * st2 + 0.03 * f2 + 0.02 * f3
    crest = np.clip(ridge * 1.2 - 0.1, 0, 1)
    v = (0.060 + 0.115 * crest) * (1 + 0.20 * f1 + 0.08 * f3) * (1 - 0.25 * cross)
    v = np.clip(v, 0.025, 0.23)
    col = np.stack([v * 1.00, v * 0.98, v * 0.96], -1)
    gray = np.array([0.40, 0.42, 0.44], np.float32)
    frost = np.clip((st2 * 0.8 + f2 * 0.5 + crest * 1.2 - 1.55) * 2.5, 0, 0.8)[..., None]  # pale frost on high plates
    spk = (f3 > 2.0)[..., None]
    col = col * (1 - frost) + gray * frost
    col = np.where(spk, col + 0.15, col)
    return dict(Color=np.clip(col, 0, 1), Normal=K.nmap(h.astype(np.float32), 26), Roughness=np.clip(0.93 - 0.12 * frost[..., 0] + 0.04 * f2, 0.4, 1))


def gen_water():
    """Water cards (mac-53): u holds 4 card columns (u = (col + across) / 4), each feathered to alpha 0 at its side edges so the
    overlapping staggered cards cross-fade with no hard strip edge; v = arclength up the fall (0 base .. 1 lip), streaks run along v,
    foam bands at both ends."""
    y, x = np.mgrid[0:N, 0:N]
    v = y / (N - 1.0)
    cu = (x * 4.0 / N) % 1.0
    edge = np.sin(np.pi * np.clip((cu - 0.02) / 0.96, 0, 1)) ** 0.7
    s1, s2, s3 = K.fld(0.9, 251, 30.0), K.fld(1.2, 252, 12.0), K.fld(0.6, 253, 4.0)
    f1 = K.fld(1.2, 254)
    streak = np.clip(0.5 + 0.38 * s1 + 0.22 * s2, 0, 1)
    foam = np.clip((s3 - 0.6) * 0.8, 0, 1) * 0.5
    top = np.clip((v - 0.955) / 0.03, 0, 1)
    bot = np.clip((0.07 - v) / 0.05, 0, 1)
    fm = np.clip(np.maximum(top, bot) * (0.75 + 0.25 * np.clip(f1 * 0.5 + 0.5, 0, 1)) + foam * 0.5, 0, 1)
    base = np.array([0.45, 0.62, 0.80], np.float32)
    white = np.array([0.93, 0.97, 1.0], np.float32)
    k = np.clip(streak * 0.9 + fm * 0.8, 0, 1)[..., None]
    col = base + (white - base) * k
    alpha = np.clip(0.22 + 0.40 * streak + 0.55 * fm, 0.12, 0.96) * edge
    h = 0.5 + 0.12 * s1 + 0.05 * s2 + 0.05 * fm
    return dict(Color=np.clip(col, 0, 1), Alpha=alpha.astype(np.float32), Normal=K.nmap(h.astype(np.float32), 5), Roughness=np.clip(0.10 + 0.25 * fm, 0.05, 1))


# ---- banner (512 wide x 2048 tall; 8 x 30 studs = 64 / 68 px per stud): crimson field, black six-spoked Asura wheel + flame-eye, tarnished gold
BW, BH, BWS, BHS = 512, 2048, 8.0, 30.0


def _sd_seg(X, Y, ax, ay, bx, by):
    px, py, dx, dy = X - ax, Y - ay, bx - ax, by - ay
    t = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - dx * t, py - dy * t)


def gen_banner():
    yy, xx = np.mgrid[0:BH, 0:BW].astype(np.float32)
    X, Y = (xx + 0.5) / BW * BWS, (yy + 0.5) / BH * BHS  # studs from bottom-left
    f1, f2, f3 = field2(BH, BW, 1.3, 261), field2(BH, BW, 0.8, 262), field2(BH, BW, 0.4, 263)
    drip = field2(BH, BW, 1.1, 264, 12.0)
    weave = 0.5 + 0.5 * np.sin(xx * 2.1) * np.sin(yy * 2.1)
    crim = np.array([0.40, 0.025, 0.04], np.float32)
    col = crim * (0.85 + 0.12 * f1[..., None] + 0.04 * f3[..., None]) * (0.92 + 0.08 * weave[..., None])
    stain = np.clip((drip - 0.4) * 0.7, 0, 0.7) * np.clip((22 - Y) / 22 + 0.25, 0, 1)
    col = col * (1 - 0.65 * stain[..., None]) + np.array([0.03, 0.012, 0.012], np.float32) * 0.65 * stain[..., None]
    gold = np.array([0.50, 0.37, 0.12], np.float32)
    tar = np.clip((f2 + 0.3) * 0.6, 0, 1)[..., None]  # tarnish
    goldc = gold * (0.75 + 0.25 * weave[..., None]) * (1 - 0.55 * tar) + np.array([0.12, 0.09, 0.05], np.float32) * 0.55 * tar
    black = np.array([0.015, 0.012, 0.014], np.float32) * (0.9 + 0.2 * weave[..., None])
    mark = np.zeros((BH, BW), np.float32)  # 1 = gold, 2 = black (relief height uses it)
    cx, cy = BWS / 2, 17.2
    # edging: side borders (two lines), top hem bar with teeth, bottom hem line
    border = (X < 0.55) | (X > BWS - 0.55)
    border2 = ((X > 0.8) & (X < 0.95)) | ((X > BWS - 0.95) & (X < BWS - 0.8))
    top = (Y > BHS - 1.9)
    teeth = (Y > BHS - 3.1) & (Y <= BHS - 1.9) & (np.abs(((X * 2.0) % 1.0) - 0.5) * 2.0 < (BHS - 1.9 - Y) / 1.2 * -1 + 1.0)
    bottom = (Y < 0.8) & (Y > 0.45)
    # sigil: gold outer ring, black rim, six black spokes, hub, gold flame-eye on black
    r = np.hypot(X - cx, Y - cy)
    ang = np.arctan2(Y - cy, X - cx)
    ring_o = (r > 3.45) & (r < 3.62)
    rim = (r > 2.95) & (r < 3.32)
    studs = np.zeros_like(r, bool)
    for k in range(6):
        a = k * np.pi / 3 + np.pi / 6
        studs |= np.hypot(X - (cx + 3.14 * math.cos(a)), Y - (cy + 3.14 * math.sin(a))) < 0.2
    spk = np.zeros_like(r, bool)
    for k in range(6):
        a = k * np.pi / 3 + np.pi / 6
        spk |= _sd_seg(X, Y, cx + 1.3 * math.cos(a), cy + 1.3 * math.sin(a), cx + 3.0 * math.cos(a), cy + 3.0 * math.sin(a)) < 0.27
        spk |= (np.hypot(X - (cx + 2.2 * math.cos(a)), Y - (cy + 2.2 * math.sin(a))) < 0.4)  # spoke bead
    hub = r < 1.55
    hub_ring = (r > 1.40) & (r < 1.58)
    ex, ey = (X - cx) / 1.20, (Y - cy) / 0.62  # almond eye: intersection of two circles
    eyew = np.abs(ey) < 1.0 - (ex * ex) * 1.0
    eyeo = (np.abs(ey) < 1.0 - ex * ex) & ~(np.abs(ey) < 0.82 - ex * ex * 0.82)  # gold outline of the eye
    tt = np.clip((Y - (cy - 0.50)) / 1.15, 0, 1)
    fw = 0.36 * (tt ** 0.4) * ((1 - tt) ** 0.95) * 1.9
    flame = (np.abs(X - (cx + 0.14 * np.sin(3.0 * tt))) < fw) & (Y > cy - 0.50) & (Y < cy + 0.65)
    # lower: three descending chevrons + a vertical sword line; upper: three small flames
    chev = np.zeros_like(r, bool)
    for i in range(3):
        y0 = 11.6 - i * 1.35
        chev |= (np.abs(Y - (y0 - 0.9 * np.abs(X - cx))) < 0.17) & (np.abs(X - cx) < 2.2)
    sword = (np.abs(X - cx) < 0.13) & (Y > 4.2) & (Y < 7.4)
    sword |= (np.abs(Y - 6.5) < 0.12) & (np.abs(X - cx) < 0.7)
    gold_m = border | border2 | top | teeth | bottom | ring_o | studs | hub_ring | eyeo | chev | sword
    black_m = (rim | spk | hub) & ~gold_m
    col = np.where(black_m[..., None], black, col)
    col = np.where(gold_m[..., None], goldc, col)
    col = np.where((eyew & hub & ~eyeo)[..., None], black * 1.1, col)
    ember = np.array([0.95, 0.50, 0.08], np.float32) * (0.9 + 0.1 * f3[..., None])
    col = np.where((flame & eyew)[..., None], ember, col)
    mark = np.where(black_m, 1.0, 0.0) + np.where(gold_m, 1.6, 0.0)
    # fray: darken close to the hem and vertical edges (geometry carries the ragged outline)
    wear = np.clip((6 - Y) / 6, 0, 1)[..., None] * 0.35
    col = col * (1 - wear)
    h = 0.5 + 0.10 * weave + 0.10 * mark + 0.03 * f2
    return dict(Color=np.clip(col, 0, 1), Normal=K.nmap(h.astype(np.float32), 7), Roughness=np.clip(0.88 - 0.14 * (mark > 1.0) + 0.04 * f2, 0.3, 1))


GENS2 = {"Vesp_Weathered": gen_weathered, "Vesp_Wax": gen_wax, "Vesp_Flame": gen_flame, "Vesp_Rope": gen_rope, "Vesp_DeadBark": gen_deadbark,
         "Vesp_Water": gen_water, "Vesp_Banner": gen_banner}
KINDS = ("Color", "Normal", "Roughness", "Metal")


def save_png(path, arr, kind, alpha=None):
    """Write via bpy (Blender's python has no PIL). arr: (H, W) or (H, W, 3), row 0 = v 0 (bottom), like kit get_image."""
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, 2)
    h, w = arr.shape[:2]
    a = np.ones((h, w, 1), np.float32) if alpha is None else alpha[..., None].astype(np.float32)
    im = bpy.data.images.new("tmp_save", w, h, alpha=alpha is not None, is_data=(kind != "Color"))
    if alpha is not None:
        im.alpha_mode = "STRAIGHT"
    im.pixels.foreach_set(np.concatenate([np.clip(arr, 0, 1), a], 2).astype(np.float32).ravel())
    im.filepath_raw = str(path)
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def build_custom(name):
    t = time.time()
    mp = OUT / "maps"
    paths = {k: mp / f"{name}_{k}.png" for k in KINDS}
    if not (K.REUSE and all(p.exists() for p in paths.values())):
        m = K._ph_maps(name) or GENS2[name]()
        c = m["Color"]
        h, w = c.shape[:2]
        save_png(paths["Color"], c, "Color", m.get("Alpha"))
        save_png(paths["Normal"], m["Normal"], "Normal")
        save_png(paths["Roughness"], m["Roughness"], "Roughness")
        save_png(paths["Metal"], np.zeros((h, w), np.float32) if "Metal" not in m else m["Metal"], "Metal")  # black for non-metal, always present
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    mat.use_backface_culling = name != "Vesp_Banner"  # water cards carry explicit back faces (two coplanar unculled sides z-fought)
    nt = mat.node_tree
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    ims = {}
    for k in KINDS:
        im = bpy.data.images.load(str(paths[k]))
        im.name = f"{name}_{k}"
        if k != "Color":
            im.colorspace_settings.name = "Non-Color"
        im.pack()
        ims[k] = im
    nodes = {}
    for k, sock in (("Color", "Base Color"), ("Roughness", "Roughness"), ("Metal", "Metallic")):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = ims[k]
        nt.links.new(n.outputs["Color"], p.inputs[sock])
        nodes[k] = n
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = ims["Normal"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    if name == "Vesp_Water":
        nt.links.new(nodes["Color"].outputs["Alpha"], p.inputs["Alpha"])
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            pass
    K.MATS[name] = mat
    log(f"material {name} {time.time() - t:.1f}s")


def init_materials(names):
    for n in names:
        if n in KIT_MATS:
            K.build_material(n)
        else:
            build_custom(n)


# ============================================================================================ UV primitives
class USub:
    def __init__(self, mat, recalc=True):
        self.mat, self.prims, self.recalc, self.smooth = mat, [], recalc, True

    def add(self, prim, T=None):
        vs, fs = prim[0], prim[1]
        fuv = prim[2] if len(prim) > 2 else None
        if T is not None:
            vs = [tuple(T @ Vector(p)) for p in vs]
        self.prims.append((vs, fs, fuv))


class USubs(dict):
    def __missing__(self, k):
        self[k] = USub(K.SUBMAT[k])
        return self[k]


def tube(pts, radii, seg=8, mult=None, tile=16.0, cap0=False, cap1=True, jag=0.0, rng=None, uvfn=None, twist=0.0, min_circ=3.0):
    """Skinned tapered tube along a polyline (rotation-minimising frames). UV: u around (circumference / tile), v along (length / tile).
    mult(i, angle) -> radial multiplier (gnarl/bark ridges); jag > 0 splinters the end ring (broken stub)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    T = [(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(n)]
    ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    Nk = (ref - T[0] * ref.dot(T[0])).normalized()
    frames, dist = [], [0.0]
    for i in range(n):
        if i:
            Nk = Nk - T[i] * Nk.dot(T[i])
            Nk = Nk.normalized() if Nk.length > 1e-6 else T[i].cross(ref).normalized()
            dist.append(dist[-1] + (pts[i] - pts[i - 1]).length)
        frames.append((Nk, T[i].cross(Nk)))
    vs, fs, fuv = [], [], []
    for i in range(n):
        Nv, Bv = frames[i]
        for k in range(seg):
            a = 2 * math.pi * k / seg + twist * i
            r = radii[i] * (mult(i, a) if mult else 1.0)
            vs.append(tuple(pts[i] + (Nv * math.cos(a) + Bv * math.sin(a)) * r))
    if jag > 0 and rng is not None:
        last = (n - 1) * seg
        for k in range(seg):
            ah = jag * (rng.random() ** 2) * (1.0 + (k % 2) * 0.8)
            vs[last + k] = tuple(Vector(vs[last + k]) + T[n - 1] * ah)
    for i in range(n - 1):
        c0, c1 = max(2 * math.pi * radii[i], min_circ), max(2 * math.pi * radii[i + 1], min_circ)
        for k in range(seg):
            k2 = (k + 1) % seg
            fs.append((i * seg + k, (i + 1) * seg + k, (i + 1) * seg + k2, i * seg + k2))
            if uvfn:
                fuv.append([uvfn(i, k / seg, dist[i], radii[i]), uvfn(i + 1, k / seg, dist[i + 1], radii[i + 1]),
                            uvfn(i + 1, (k + 1) / seg, dist[i + 1], radii[i + 1]), uvfn(i, (k + 1) / seg, dist[i], radii[i])])
            else:
                fuv.append([(k / seg * c0 / tile, dist[i] / tile), (k / seg * c1 / tile, dist[i + 1] / tile),
                            ((k + 1) / seg * c1 / tile, dist[i + 1] / tile), ((k + 1) / seg * c0 / tile, dist[i] / tile)])

    def cap(ring_i, flip, centre):
        base = len(vs)
        for k in range(seg):
            vs.append(vs[ring_i * seg + k])
        vs.append(tuple(centre))
        c = len(vs) - 1
        r = max(radii[ring_i], 0.05)
        for k in range(seg):
            k2 = (k + 1) % seg
            fs.append((base + k2, base + k, c) if not flip else (base + k, base + k2, c))
            a1, a2 = 2 * math.pi * k / seg, 2 * math.pi * k2 / seg
            fuv.append([(math.cos(a2) * r / tile, math.sin(a2) * r / tile), (math.cos(a1) * r / tile, math.sin(a1) * r / tile), (0.0, 0.0)])

    if cap0:
        cap(0, True, pts[0])
    if cap1:
        ctr = pts[n - 1] + T[n - 1] * (-(jag * 0.35) if jag > 0 else 0.0)
        cap(n - 1, False, ctr)
    return vs, fs, fuv


def revolve(prof, seg=16, tile=None, rot=0.0, closed_top=True):
    """Smooth lathe with UVs: u around, v = arclength. tile=None -> u,v in 0..1; else studs per texture."""
    apex = prof[-1][0] < 1e-6
    arc = [0.0]
    for i in range(1, len(prof)):
        arc.append(arc[-1] + math.hypot(prof[i][0] - prof[i - 1][0], prof[i][1] - prof[i - 1][1]))
    tot = arc[-1] or 1.0
    vs, fs, fuv = [], [], []
    rings = len(prof) - (1 if apex else 0)
    for i in range(rings):
        r, z = prof[i]
        for k in range(seg):
            a = rot + 2 * math.pi * k / seg
            vs.append((r * math.cos(a), r * math.sin(a), z))
    if apex:
        vs.append((0.0, 0.0, prof[-1][1]))
    sc = lambda i, f: ((f, arc[i] / tot) if tile is None else (f * max(2 * math.pi * prof[i][0], 1.0) / tile, arc[i] / tile))
    for i in range(rings - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            fs.append((i * seg + k, (i + 1) * seg + k, (i + 1) * seg + k2, i * seg + k2))
            fuv.append([sc(i, k / seg), sc(i + 1, k / seg), sc(i + 1, (k + 1) / seg), sc(i, (k + 1) / seg)])
    if apex:
        i = rings - 1
        for k in range(seg):
            k2 = (k + 1) % seg
            fs.append((i * seg + k2, i * seg + k, len(vs) - 1))
            fuv.append([sc(i, (k + 1) / seg), sc(i, k / seg), sc(len(prof) - 1, (k + 0.5) / seg)])
    return vs, fs, fuv


def cloth(w, h, xs, zs, present, disp, thick, uvf, back_uv=None):
    """Closed two-layer cloth shell (double-sided geometry). xs/zs: strictly increasing grid lines. present(xc, zc) -> bool cell exists.
    disp(x, z) -> (dx, dy, dz) displacement; uvf(x, z) -> (u, v); back surface mirrors u. Faces on the rim join front and back."""
    nx, nz = len(xs) - 1, len(zs) - 1
    cells = [[present((xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2) for j in range(nz)] for i in range(nx)]
    vs, fs, fuv = [], [], []
    vid = {}

    def vert(i, j, side):
        key = (i, j, side)
        if key not in vid:
            x, z = xs[i], zs[j]
            dx, dy, dz = disp(x, z)
            vid[key] = len(vs)
            vs.append((x + dx, dy + side * thick / 2, z + dz))
        return vid[key]

    for i in range(nx):
        for j in range(nz):
            if not cells[i][j]:
                continue
            q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            uvs = [uvf(xs[a], zs[b]) for a, b in q]
            fs.append(tuple(vert(a, b, -1) for a, b in q))
            fuv.append(uvs)
            fs.append(tuple(vert(a, b, 1) for a, b in reversed(q)))
            fuv.append([(1.0 - u if back_uv is None else back_uv(u), v) for u, v in reversed(uvs)])
            for (di, dj, e0, e1) in ((0, -1, 0, 1), (1, 0, 1, 2), (0, 1, 2, 3), (-1, 0, 3, 0)):
                ni, nj = i + di, j + dj
                if 0 <= ni < nx and 0 <= nj < nz and cells[ni][nj]:
                    continue
                a, b = q[e0], q[e1]
                fs.append((vert(a[0], a[1], -1), vert(b[0], b[1], -1), vert(b[0], b[1], 1), vert(a[0], a[1], 1)))
                ua, va = uvf(xs[a[0]], zs[a[1]])
                ub, vb = uvf(xs[b[0]], zs[b[1]])
                fuv.append([(ua, va), (ub, vb), (ub, vb), (ua, va)])
    return vs, fs, fuv


# ============================================================================================ build / finish
def commit_u(sub):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    tp = bm.faces.layers.int.new("tp")
    for vs, fs, fuv in sub.prims:
        bv = [bm.verts.new(p) for p in vs]
        for fi, f in enumerate(fs):
            idx = list(dict.fromkeys(f))
            if len(idx) < 3:
                continue
            try:
                face = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            if fuv is None:
                face[tp] = 1
            else:
                m = {}
                for i, uv in zip(f, fuv[fi]):
                    m.setdefault(i, uv)
                for lp, i in zip(face.loops, idx):
                    lp[uvl].uv = m[i]
    if sub.recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    bm.verts.index_update()
    tile = K.TILE[sub.mat]
    vco = [tuple(v.co) for v in bm.verts]
    faces = []
    for f in bm.faces:
        nrm = tuple(f.normal)
        if f[tp]:
            ax, ay, az = abs(nrm[0]), abs(nrm[1]), abs(nrm[2])
            uvs = []
            for v in f.verts:
                c = v.co
                u, vv = (c.x, c.y) if (az >= ax and az >= ay) else ((c.y, c.z) if ax >= ay else (c.x, c.z))
                uvs.append((u / tile, vv / tile))
        else:
            uvs = [tuple(lp[uvl].uv) for lp in f.loops]
        faces.append(([tuple(v.co) for v in f.verts], nrm, f.calc_area(), uvs, [v.index for v in f.verts]))
    bm.free()
    return faces, vco


def chunks_axis(faces, axis=None, cap=SMOOTH_SPLIT):
    tri = lambda f: len(f[0]) - 2
    tot = sum(tri(f) for f in faces)
    if tot <= cap:
        return [faces]
    k = -(-tot // cap)
    cs = [tuple(sum(c[i] for c in f[0]) / len(f[0]) for i in range(3)) for f in faces]
    ax = axis if axis is not None else max(range(3), key=lambda i: max(c[i] for c in cs) - min(c[i] for c in cs))
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


def make_obj_u(name, mat, faces, vco, smooth=True):
    remap, verts, polys, uvs = {}, [], [], []
    for co, nrm, area, uv, vidx in faces:
        p = []
        for i in vidx:
            if i not in remap:
                remap[i] = len(verts)
                verts.append(vco[i])
            p.append(remap[i])
        polys.append(tuple(p))
        for u, v in uv:
            uvs += (u, v)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], polys)
    me.update()
    me.uv_layers.new(name="UVMap").data.foreach_set("uv", uvs)
    me.materials.append(K.MATS[mat])
    (me.shade_smooth if smooth else me.shade_flat)()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.calc_loop_triangles()
    tris = len(me.loop_triangles)
    assert tris < K.TRI_CAP, (name, tris)
    return o, tris


def finish_mixed(name, group, S, U, frost_from=(), frost_uv=(), axis=None, frost_nz=0.62, frost_area=1.0, frost_keep=1.0, frost_off=0.08,
                 flat_subs=(), frost_amax=1e9, weather=None):
    """S: kit Subs (flat, triplanar). U: USubs (smooth, UV). Frost = up-facing faces of the listed subs copied into one Frost sub."""
    objs, subs = [], {}
    kdata = {s: K.commit(sub) for s, sub in S.items() if s != "Frost" and sub.prims}
    udata = {s: commit_u(sub) for s, sub in U.items() if sub.prims}
    frost = []
    for s in frost_from:
        for co, nrm, area in kdata.get(s, []):
            if nrm[2] >= 0.6 and area >= frost_area:
                dz = 0.12 if nrm[2] >= 0.8 else 0.08
                frost.append(([(x, y, z + dz) for x, y, z in co], nrm, area))
    for s in frost_uv:
        if s not in udata:
            continue
        for co, nrm, area, uv, vidx in udata[s][0]:
            if nrm[2] >= frost_nz and frost_area <= area <= frost_amax:
                c = [sum(p[i] for p in co) / len(co) for i in range(3)]
                if frost_keep < 1.0 and (vnoise(c[0] * 0.12, c[1] * 0.12, c[2] * 0.12) * 0.5 + 0.5) > frost_keep:
                    continue
                frost.append(([(x + nrm[0] * frost_off, y + nrm[1] * frost_off, z + nrm[2] * frost_off) for x, y, z in co], nrm, area))
    if frost:
        kdata["Frost"] = frost
    for s, faces in kdata.items():
        for i, ch in enumerate(chunks_axis(faces, axis) if axis is not None else K.chunks(faces)):
            wz = None if weather is None or s in K.NOWEATHER else (weather, 0.0, None)  # opt-in noise weathering (mac-53)
            o, t = K.make_obj(f"{name}__{s}" + (f"_{i + 1}" if i else ""), K.SUBMAT[s], ch, None, wz)
            objs.append(o)
            subs[o.name] = t
    for s, (faces, vco) in udata.items():
        sn = s + "Smooth" if s in kdata else s  # a name used by both the flat and the smooth path gets a suffix
        for i, ch in enumerate(chunks_axis(faces, axis)):
            o, t = make_obj_u(f"{name}__{sn}" + (f"_{i + 1}" if i else ""), K.SUBMAT[s], ch, vco, smooth=s not in flat_subs)
            objs.append(o)
            subs[o.name] = t
    K.PIECES[name] = objs
    lo, hi = K.bbox(objs)
    K.manifest["pieces"][name] = {"group": group, "sub_meshes": subs, "tris_total": sum(subs.values()),
                                  "size_studs_xyz": [round(hi.x - lo.x, 1), round(hi.y - lo.y, 1), round(hi.z - lo.z, 1)],
                                  "bbox_min": [round(c, 2) for c in lo], "bbox_max": [round(c, 2) for c in hi],
                                  "materials": sorted({m.name for o in objs for m in o.data.materials})}
    log(f"{name:24s} " + " ".join(f"{k.split('__')[1]}={v}" for k, v in subs.items()) + f"  size {K.manifest['pieces'][name]['size_studs_xyz']}")


def render_glow():
    for nm, strength in (("Vesp_Flame", 6.0), ("Vesp_Glass", 2.0)):
        m = K.MATS.get(nm)
        if not m:
            continue
        nt = m.node_tree
        p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        img = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name.endswith("_Color"))
        nt.links.new(img.outputs["Color"], p.inputs["Emission Color"])
        p.inputs["Emission Strength"].default_value = strength


def run(title, plan, mat_names, sheets, extra_sheets=None):
    """plan: [(name, group, fn(S, U) or fn(S))]. Builds, exports GLBs, writes manifest.json, renders contact sheets."""
    K.manifest["kit"] = title
    K.manifest["glb_images"] = "none (maps/ is the source; vesp_embed.py embeds Color/ORM JPEG q90 + Normal PNG into upload/ GLBs)"
    (OUT / "maps").mkdir(parents=True, exist_ok=True)
    (OUT / "renders").mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    init_materials(mat_names)
    for name, group, fn in plan:
        if K.ONLY and name not in K.ONLY:
            continue
        t = time.time()
        S, U = K.Subs(), USubs()
        fn(S, U)
        finish_cfg = getattr(fn, "cfg", {})
        finish_mixed(name, group, S, U, **finish_cfg)
        log(f"   built {name} {time.time() - t:.1f}s")
    for name in K.PIECES:
        K.export_piece(name)
    K.manifest["textures"] = {i.name: list(i.size) for i in bpy.data.images if i.name.startswith("Vesp_")}
    K.write_manifest()  # merges: a VESP_ONLY run keeps the pieces it did not build (mac-53)
    log("exported", len(K.PIECES), "pieces")
    if os.environ.get("VESP_NORENDER"):
        return
    sc, cam, ground = K.setup_render()
    render_glow()
    for o in [o for objs in K.PIECES.values() for o in objs]:
        o.hide_render = True
    for tag, items, kw in sheets:
        items = [(n, s) for n, s in items if n in K.PIECES]
        if items:
            t = time.time()
            K.sheet(sc, cam, ground, tag, items, **kw)
            log(f"render {tag} {time.time() - t:.1f}s")
    log("renders done")


def cfg(**kw):
    def deco(fn):
        fn.cfg = kw
        return fn
    return deco

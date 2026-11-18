"""Bellwood slice kit (Gateway Glade -> Bell Terrace): 5 structure pieces + hero bell pavilion + 5 vegetation pieces.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/slice_kit.py
  (optional: -- <out_dir> <captures_dir>; env SLICE_R1=<dir of round-1 GLBs> adds old-vs-new eye-height comparison renders)

Units: 1 Blender unit = 1 stud. Every piece stands on the origin (foot/base centre, z = 0) so it can be scaled and
swayed from the base. Procedural geometry + numpy PBR maps (Color / Normal / Roughness / Metal) as in
tools/blender/bamboo_karst_kit.py. Writes one GLB per piece (textures embedded), maps/, manifest.json, a .blend,
per-piece previews and the assembled vignette renders. Every sub-mesh is asserted < 18000 triangles.
"""
import json
import math
import os
import random
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[3]
_a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(_a[0] if _a else ROOT / "assets/source/overworld/slice").resolve()
CAP = Path(_a[1] if len(_a) > 1 else ROOT / "outputs/claude-open-world-2026-11-14/captures/slice").resolve()
R1 = Path(os.environ["SLICE_R1"]) if os.environ.get("SLICE_R1") else None
TRI_CAP = 18000
rng = random.Random(7)
WIND = Vector((-0.92, 0.38, 0))  # ESE wind blows toward WNW (Blender -X, +Y == Roblox -X, -Z)
manifest = {"round": 3, "build": "blender -b -P tools/blender/overworld/slice_kit.py", "tri_cap_per_sub_mesh": TRI_CAP,
            "units": "studs (1 BU = 1 stud)", "pivot": "foot/base centre at origin, z=0", "pieces": {}}
PIECES = {}
MATS = {}
LEAF_PTS = []  # (u, v) samples that fall inside a painted leaf on the Leaf tile; leaf cards pick their colour from these


# ------------------------------------------------------------------------------------------ textures
def field(n, beta, seed, stretch=1.0):
    fu, fv = np.meshgrid(np.fft.fftfreq(n) * n, np.fft.fftfreq(n) * n)
    spec = np.fft.fft2(np.random.default_rng(seed).standard_normal((n, n)))
    out = np.real(np.fft.ifft2(spec / (np.sqrt(fu ** 2 + (fv * stretch) ** 2) + 1.0) ** beta))
    return (out - out.mean()) / out.std()


def nmap(h, k):
    dx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
    dy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    nm = np.dstack([-dx * k, -dy * k, np.ones_like(dx)])
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    return nm * 0.5 + 0.5


def save(name, arr, non_color=False):
    nv, nu = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, 2)
    im = bpy.data.images.new(name, nu, nv, alpha=False, is_data=non_color)
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((nv, nu, 1))], 2)
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = str(OUT / "maps" / f"{name}.png")
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im


def material(name, color, rough, normal=None, metal=None, double=False):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    m.use_backface_culling = not double
    nt = m.node_tree
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    def tex(im, sock):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = im
        nt.links.new(t.outputs["Color"], p.inputs[sock])
        return t

    tex(color, "Base Color")
    tex(rough, "Roughness")
    if metal is None:  # unlinked Metallic: glTF exporter fills MR.B with 255 and Roblox renders full metal; pack a black map instead
        metal = bpy.data.images.new(name + "_Metal0", *rough.size, alpha=False, is_data=True)
        metal.pixels.foreach_set(np.tile(np.array([0, 0, 0, 1], np.float32), rough.size[0] * rough.size[1]))
        metal.pack()
    tex(metal, "Metallic")
    if normal is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = normal
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    MATS[name] = m
    return m


def stone_mat():
    n = 512
    f1, f2, pit = field(n, 1.4, 1), field(n, 0.9, 2), field(n, 0.5, 3)
    moss = np.clip((field(n, 1.8, 4) - 0.35) * 1.6, 0, 1)
    wet = np.clip(field(n, 1.2, 5, 14) * 0.6, 0, 1)
    col = np.array([0.40, 0.43, 0.46]) * (0.86 + 0.08 * f1[..., None] + 0.04 * f2[..., None])
    col = col * (1 - 0.7 * moss[..., None]) + np.array([0.17, 0.27, 0.09]) * 0.7 * moss[..., None]
    col *= 1 - 0.2 * wet[..., None]
    h = 0.5 + 0.12 * f1 + 0.05 * f2 - 0.1 * np.clip(pit - 1.4, 0, 2) + 0.06 * moss
    rough = np.clip(0.8 - 0.2 * wet + 0.1 * moss, 0, 1)
    return material("Bell_Stone", save("Bell_Stone_Color", col), save("Bell_Stone_Roughness", rough, True),
                    save("Bell_Stone_Normal", nmap(h, 5.0), True))


def timber_mat():
    n = 512
    grain, tone = field(n, 0.9, 31, 16.0), field(n, 1.6, 32)
    paint = np.clip((field(n, 1.3, 33) - 0.55) * 3, 0, 1)[..., None]
    col = np.array([0.17, 0.115, 0.08]) * (0.8 + 0.14 * grain[..., None] + 0.08 * tone[..., None])
    col = col * (1 - paint) + np.array([0.42, 0.13, 0.08]) * (0.75 + 0.15 * grain[..., None]) * paint
    h = 0.5 + 0.08 * grain
    rough = np.clip(0.72 + 0.06 * grain, 0, 1)
    return material("Bell_Timber", save("Bell_Timber_Color", col), save("Bell_Timber_Roughness", rough, True),
                    save("Bell_Timber_Normal", nmap(h, 4.0), True))


def bronze_mat():
    n = 256
    pat = np.clip((field(n, 1.5, 41) - 0.35) * 0.7, 0, 0.85)  # patina only in the hollows; bell/lanterns stay mostly bronze
    col = np.array([0.50, 0.32, 0.15]) * (1 - pat[..., None]) + np.array([0.20, 0.50, 0.42]) * pat[..., None]
    metal = 1 - 0.85 * pat
    rough = 0.35 + 0.45 * pat
    h = 0.5 + 0.1 * field(n, 1.2, 42)
    return material("Bell_Bronze", save("Bell_Bronze_Color", col), save("Bell_Bronze_Roughness", rough, True),
                    save("Bell_Bronze_Normal", nmap(h, 3.0), True), save("Bell_Bronze_Metal", metal, True))


def glow_mat():
    n = 128
    v, u = np.meshgrid(np.linspace(-1, 1, n), np.linspace(-1, 1, n), indexing="ij")
    g = np.clip(1 - np.sqrt(u ** 2 + v ** 2) * 0.7, 0, 1)[..., None]
    col = np.array([0.55, 0.25, 0.05]) * (1 - g) + np.array([1.0, 0.78, 0.38]) * g
    return material("Bell_LanternGlow", save("Bell_LanternGlow_Color", col), save("Bell_LanternGlow_Roughness", np.full((n, n), 0.4), True))


def bark_mat():
    n = 512
    ridge, fine = field(n, 1.0, 21, 9.0), field(n, 1.5, 22, 3.0)
    moss = np.clip((field(n, 1.8, 23) - 0.6) * 1.5, 0, 1)[..., None]
    h = 0.5 + 0.25 * np.tanh(ridge) + 0.06 * fine
    col = np.array([0.30, 0.25, 0.20]) * (0.75 + 0.7 * (h[..., None] - 0.5))
    col = col * (1 - 0.6 * moss) + np.array([0.14, 0.24, 0.08]) * 0.6 * moss
    col *= np.where(ridge[..., None] < -1.2, 0.55, 1.0)
    rough = np.clip(0.85 - 0.1 * h, 0, 1)
    return material("Bell_Bark", save("Bell_Bark_Color", col), save("Bell_Bark_Roughness", rough, True),
                    save("Bell_Bark_Normal", nmap(h, 6.0), True))


def leaf_mat():
    """Painted leaf-litter tile: ~520 overlapping lanceolate leaves in five greens over a dark gap colour."""
    n = 512
    r = np.random.default_rng(9)
    col = np.zeros((n, n, 3))
    col[:] = (0.05, 0.11, 0.04)
    h = np.full((n, n), 0.25)
    tones = [(0.16, 0.32, 0.08), (0.22, 0.40, 0.10), (0.28, 0.44, 0.12), (0.12, 0.26, 0.07), (0.40, 0.46, 0.14)]
    yy, xx = np.mgrid[-18:19, -18:19]
    for i in range(520):
        cx, cy = r.integers(0, n, 2)
        a, L = r.uniform(0, np.pi), r.uniform(11, 17)
        wd = L * r.uniform(0.32, 0.45)
        u, v = xx * np.cos(a) + yy * np.sin(a), -xx * np.sin(a) + yy * np.cos(a)
        t = u / L
        ins = (np.abs(t) < 1) & (np.abs(v) < wd * np.clip(1 - t ** 2, 0, 1) ** 0.8)
        rows, cols = (cy + yy) % n, (cx + xx) % n
        tone = np.array(tones[r.choice(5, p=[0.28, 0.30, 0.22, 0.12, 0.08])])
        shade = 0.8 + 0.3 * (0.5 + 0.5 * t) + np.where(np.abs(v) < 0.9, 0.12, 0.0)
        col[rows[ins], cols[ins]] = tone * shade[ins][:, None]
        h[rows[ins], cols[ins]] = 0.5 + 0.3 * (1 - np.abs(v[ins]) / wd) + 0.02 * i / 520
    rough = 0.62 + 0.1 * field(n, 1.0, 11)
    ys, xs = np.nonzero(h > 0.55)
    sel = np.random.default_rng(3).choice(len(ys), 600)
    LEAF_PTS.extend(zip(((xs[sel] + 0.5) / n).tolist(), ((ys[sel] + 0.5) / n).tolist()))
    col = np.clip(col * 1.25, 0, 1)
    return material("Bell_Leaf", save("Bell_Leaf_Color", col), save("Bell_Leaf_Roughness", np.clip(rough, 0, 1), True),
                    save("Bell_Leaf_Normal", nmap(h, 3.0), True))


def roof_mat():
    """Staggered slate/clay roof tiles (16 rows x 8 per tile), mossy, a few weathered terracotta tiles."""
    n = 512
    r = np.random.default_rng(51)
    yy, xx = np.mgrid[0:n, 0:n]
    ri, fy = yy // 32, (yy % 32) / 32
    xs = (xx + (ri % 2) * 32) % n
    ti, fx = xs // 64, (xs % 64) / 64
    tone = r.uniform(0.8, 1.15, (16, 8))[ri, ti][..., None]
    clay = (r.random((16, 8)) < 0.06)[ri, ti][..., None]
    moss = np.clip((field(n, 1.8, 52) - 0.3) * 1.6, 0, 1)[..., None]
    col = np.where(clay, np.array([0.34, 0.19, 0.13]), np.array([0.17, 0.20, 0.23])) * tone
    shade = 1 - 0.5 * np.clip((fy - 0.78) / 0.22, 0, 1) - 0.4 * np.clip((0.07 - fx) / 0.07, 0, 1)
    col = (col * (1 - 0.65 * moss) + np.array([0.15, 0.25, 0.08]) * 0.65 * moss) * shade[..., None]
    h = 0.35 + 0.4 * fy - 0.25 * np.clip((0.07 - fx) / 0.07, 0, 1) + 0.04 * field(n, 1.2, 53)
    rough = np.clip(0.72 + 0.1 * field(n, 1.0, 54), 0, 1)
    return material("Bell_Roof", save("Bell_Roof_Color", col), save("Bell_Roof_Roughness", rough, True),
                    save("Bell_Roof_Normal", nmap(h, 4.0), True))


def granite_mat():
    """Bell_Granite 1024x1024 atlas of four 512 quadrants chosen per face by UV (no tiling): granite, moss, mud-stained base,
    lichen granite. Matches the Forest terrain palette (Overworld.materialAt: Rock steep, LeafyGrass/Grass flat, Mud low)."""
    n = 512
    g1, g2, grain, vein = field(n, 1.3, 71), field(n, 0.8, 72), field(n, 0.1, 73), field(n, 1.0, 74)
    warm = np.clip(g2 * 0.5 + 0.5, 0, 1)[..., None]
    gran = np.array([0.40, 0.40, 0.41]) * (0.86 + 0.09 * g1[..., None] + 0.04 * g2[..., None])
    gran = gran * (1 - warm * 0.25) + np.array([0.46, 0.41, 0.36]) * warm * 0.25
    gran = gran * np.where(grain[..., None] > 1.4, 0.6, np.where(grain[..., None] < -1.5, 1.28, 1.0))
    gran = gran * (1 - 0.28 * np.exp(-(vein[..., None] / 0.14) ** 2))
    cr = np.clip((field(n, 1.8, 75) - 0.9) * 1.2, 0, 0.5)[..., None]
    gran = gran * (1 - cr) + np.array([0.15, 0.26, 0.08]) * cr
    h_g = 0.5 + 0.1 * g1 + 0.04 * g2 + 0.02 * grain - 0.1 * np.exp(-(vein / 0.14) ** 2)
    m1, m2 = field(n, 1.0, 76), field(n, 1.6, 77)
    moss = np.array([0.16, 0.30, 0.07]) * (0.8 + 0.2 * m1[..., None])
    moss = moss + np.array([0.12, 0.10, 0.04]) * np.clip(m1 - 0.7, 0, 1)[..., None]
    moss = moss * np.where(m1[..., None] < -0.9, 0.45, 1.0)
    pk = np.clip((m2 - 1.0) * 2, 0, 1)[..., None]
    moss = moss * (1 - pk) + gran * pk
    h_m = 0.5 + 0.12 * m1 + 0.04 * grain
    mf = field(n, 1.2, 78)
    mud = np.array([0.24, 0.19, 0.12]) * (0.8 + 0.3 * mf[..., None])
    alg = np.clip((field(n, 1.6, 79) - 0.3) * 1.2, 0, 0.7)[..., None]
    mud = mud * (1 - alg) + np.array([0.22, 0.30, 0.12]) * alg
    h_d = 0.5 + 0.05 * mf
    lf_ = field(n, 0.6, 80)
    lich = np.array([0.53, 0.52, 0.49]) * (0.9 + 0.08 * g1[..., None])
    lich = np.where(lf_[..., None] > 1.5, np.array([0.52, 0.55, 0.26]), lich)
    lich = np.where(lf_[..., None] > 2.1, np.array([0.60, 0.38, 0.14]), lich)
    h_l = 0.5 + 0.08 * g1
    rg = np.clip(0.84 + 0.05 * g1, 0, 1)
    rm = np.clip(0.9 + 0.04 * m1, 0, 1)
    rd = np.clip(0.68 + 0.05 * mf, 0, 1)
    col, hh, rough = np.zeros((2 * n, 2 * n, 3)), np.zeros((2 * n, 2 * n)), np.zeros((2 * n, 2 * n))
    for (qu, qv), c, h, r in (((0, 0), gran, h_g, rg), ((1, 0), moss, h_m, rm), ((0, 1), mud, h_d, rd), ((1, 1), lich, h_l, rg)):
        sl = (slice(qv * n, qv * n + n), slice(qu * n, qu * n + n))
        col[sl], hh[sl], rough[sl] = np.clip(c, 0, 1), h, r
    return material("Bell_Granite", save("Bell_Granite_Color", col), save("Bell_Granite_Roughness", rough, True),
                    save("Bell_Granite_Normal", nmap(hh, 5.0), True))


def blade_mat(name, n_u, n_v, base, tip, seed, double=True):
    v, u = np.meshgrid(np.linspace(0, 1, n_v), np.linspace(0, 1, n_u), indexing="ij")
    vein = np.exp(-((u - 0.5) / 0.05) ** 2)
    g = field(n_u, 1.2, seed)[:n_v] if n_v <= n_u else np.resize(field(n_u, 1.2, seed), (n_v, n_u))
    col = (np.array(base)[None, None] * (1 - v[..., None]) + np.array(tip)[None, None] * v[..., None])
    col = col * (0.9 + 0.06 * g[..., None]) + 0.08 * vein[..., None]
    h = 0.5 + 0.3 * vein
    return material(name, save(name + "_Color", col), save(name + "_Roughness", np.full((n_v, n_u), 0.5), True),
                    save(name + "_Normal", nmap(h, 4.0), True), double=double)


# ------------------------------------------------------------------------------------------ geometry
def obj(piece, sub, bm, mat, smooth=False, recalc=True):
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(f"{piece}__{sub}")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    (me.shade_smooth if smooth else me.shade_flat)()
    o = bpy.data.objects.new(f"{piece}__{sub}", me)
    bpy.context.scene.collection.objects.link(o)
    me.calc_loop_triangles()
    tris = len(me.loop_triangles)
    assert tris < TRI_CAP, (o.name, tris)
    PIECES.setdefault(piece, []).append(o)
    manifest["pieces"].setdefault(piece, {"sub_meshes": {}})["sub_meshes"][o.name] = tris
    return o


def _uvl(bm):
    return bm.loops.layers.uv.verify()


def bx(bm, x, y, z0, sx, sy, sz, rz=0.0, mode="stone", bev=0.12, jag=0.0, uvs=8.0):
    """Box with bottom centre (x, y, z0); chamfered edges; UVs in world studs (grain along the long axis for timber)."""
    uvl = _uvl(bm)
    before = set(bm.faces)
    vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in vs:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz + sz / 2))
    bm.normal_update()
    b = min(bev, 0.3 * min(sx, sy, sz))
    if b > 0.02:
        edges = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=b, segments=1, affect="EDGES")
    new = [f for f in bm.faces if f not in before]
    bm.normal_update()
    off = (rng.random(), rng.random())
    long_ax = max(range(3), key=lambda i: (sx, sy, sz)[i])
    for f in new:
        a = max(range(3), key=lambda i: abs(f.normal[i]))
        axes = [i for i in range(3) if i != a]
        pref = long_ax if mode == "timber" else 2
        if pref in axes:
            vax, uax = pref, [i for i in axes if i != pref][0]
        else:
            uax, vax = axes
        for l in f.loops:
            c = l.vert.co
            l[uvl].uv = (c[uax] / uvs + off[0], c[vax] / uvs + off[1])
    verts = {v for f in new for v in f.verts}
    if jag:
        for v in verts:
            if v.co.z > sz * 0.6:
                v.co.z -= rng.uniform(0, jag)
    bmesh.ops.rotate(bm, verts=list(verts), cent=(0, 0, 0), matrix=Matrix.Rotation(rz, 3, "Z"))
    bmesh.ops.translate(bm, verts=list(verts), vec=Vector((x, y, z0)))


def cyl(bm, x, y, z0, r0, r1, h, seg=10, uvs=8.0):
    uvl = _uvl(bm)
    before = set(bm.faces)
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r0, radius2=r1, depth=h)
    new = [f for f in bm.faces if f not in before]
    verts = {v for f in new for v in f.verts}
    for v in verts:
        v.co += Vector((x, y, z0 + h / 2))
    for f in new:
        for l in f.loops:
            c = l.vert.co
            if abs(f.normal.z) > 0.9:
                l[uvl].uv = ((c.x - x) / uvs, (c.y - y) / uvs)
            else:
                l[uvl].uv = (round(2 * math.pi * max(r0, r1) / uvs + 0.5) * (math.atan2(c.y - y, c.x - x) / (2 * math.pi) % 1.0), (c.z - z0) / uvs)
        # fix the angular seam: faces whose u spans the wrap get their low values lifted by one period
        us = [l[uvl].uv.x for l in f.loops]
        if abs(f.normal.z) < 0.9 and max(us) - min(us) > 0.5 * round(2 * math.pi * max(r0, r1) / uvs + 0.5):
            per = round(2 * math.pi * max(r0, r1) / uvs + 0.5)
            for l in f.loops:
                if l[uvl].uv.x < per / 2:
                    l[uvl].uv.x += per


def loft_beam(bm, length, d, t, warp, z0=0.0, x0=0.0, y0=0.0, m=14, uvs=8.0):
    """Timber beam along X, cross-section d (y) x t (z), z-offset warp(x) for upturned ends. Grain along the beam."""
    uvl = _uvl(bm)
    per = [0, d, d + t, 2 * d + t, 2 * d + 2 * t]
    sec = []
    for i in range(m + 1):
        x = -length / 2 + length * i / m
        dz = warp(x)
        sec.append([bm.verts.new(Vector((x0 + x, y0 + yy, z0 + dz + zz))) for yy, zz in
                    ((-d / 2, 0), (d / 2, 0), (d / 2, t), (-d / 2, t))])
    for i in range(m):
        for k in range(4):
            k2 = (k + 1) % 4
            f = bm.faces.new((sec[i][k], sec[i + 1][k], sec[i + 1][k2], sec[i][k2]))
            xs = (-length / 2 + length * i / m, -length / 2 + length * (i + 1) / m)
            for l, (xx, pp) in zip(f.loops, ((xs[0], per[k]), (xs[1], per[k]), (xs[1], per[k + 1]), (xs[0], per[k + 1]))):
                l[uvl].uv = (pp / uvs, xx / uvs)
    for ring in (sec[0], sec[-1]):
        f = bm.faces.new(ring)
        for l in f.loops:
            l[uvl].uv = (0.5 + l.vert.co.y / uvs, 0.5 + l.vert.co.z / uvs)


def lathe(bm, prof, x=0.0, y=0.0, z0=0.0, seg=20, turns=5, uvs=4.0):
    """Closed lathe: prof is a closed loop of (r, z); u wraps `turns` times round, v follows the profile."""
    uvl = _uvl(bm)
    rings = [[bm.verts.new(Vector((x + r * math.cos(2 * math.pi * k / seg), y + r * math.sin(2 * math.pi * k / seg), z0 + z)))
              for k in range(seg)] for r, z in prof]
    acc = [0.0]
    for (r0, z0_), (r1, z1) in zip(prof, prof[1:] + prof[:1]):
        acc.append(acc[-1] + math.hypot(r1 - r0, z1 - z0_))
    for j in range(len(prof)):
        j2 = (j + 1) % len(prof)
        for k in range(seg):
            k2 = (k + 1) % seg
            f = bm.faces.new((rings[j][k], rings[j][k2], rings[j2][k2], rings[j2][k]))
            for l, (kk, aa) in zip(f.loops, ((k, acc[j]), (k + 1, acc[j]), (k + 1, acc[j + 1]), (k, acc[j + 1]))):
                l[uvl].uv = (kk / seg * turns, aa / uvs)


def tube(bm, pts, radii, sides=7, uvs=8.0):
    uvl = _uvl(bm)
    n = len(pts)
    t0 = (pts[1] - pts[0]).normalized()
    side = t0.cross(Vector((1, 0, 0)))
    if side.length < 0.1:
        side = t0.cross(Vector((0, 1, 0)))
    side.normalize()
    rings, length = [], [0.0]
    for i, (p, r) in enumerate(zip(pts, radii)):
        t = ((pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])).normalized()
        side = (side - t * side.dot(t)).normalized()
        up = t.cross(side)
        rings.append([bm.verts.new(p + (side * math.cos(2 * math.pi * k / sides) + up * math.sin(2 * math.pi * k / sides)) * r)
                      for k in range(sides)])
        if i:
            length.append(length[-1] + (p - pts[i - 1]).length)
    tiles = max(1, round(2 * math.pi * max(radii) / uvs * 1.5))
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            f = bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
            for l, (kk, ll) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                l[uvl].uv = (kk / sides * tiles, length[ll] / uvs)
    for ring, c in ((rings[0], pts[0]), (rings[-1], pts[-1])):
        f = bm.faces.new(ring)
        for l in f.loops:
            l[uvl].uv = (0.5 + (l.vert.co.x - c.x) / uvs, 0.5 + (l.vert.co.y - c.y) / uvs)


def leaf(bm, b, d, L, W, droop, uv0=None, kite=False, uvf=None, tex=0.02):
    """Two-sided lanceolate leaf card (hex; kite for fine fern pinnae): base b, direction d, length L, width W, tip sags
    by droop*L. Real geometry both sides (no alpha, no reliance on DoubleSided). UVs: a tiny patch at uv0 on the Leaf
    tile (one flat painted-leaf colour per card) or uvf(t, side) for mapped cards."""
    uvl = _uvl(bm)
    d = d.normalized()
    sd = Vector((0, 0, 1)).cross(d)
    if sd.length < 0.15:
        sd = Vector((1, 0, 0)).cross(d)
    sd.normalize()
    prof = ((0, 0), (0.4, -1), (1, 0), (0.4, 1)) if kite else ((0, 0), (0.3, -1), (0.7, -0.6), (1, 0), (0.7, 0.6), (0.3, 1))
    top = [bm.verts.new(b + d * L * t - Vector((0, 0, droop * L * t * t)) + sd * (s * W / 2)) for t, s in prof]
    bot = [bm.verts.new(v.co) for v in top]
    uvs = [uvf(t, s) if uvf else (uv0[0] + s * tex, uv0[1] + (t - 0.5) * tex * 2) for t, s in prof]
    n = len(prof)
    for f, order in ((bm.faces.new(top), range(n)), (bm.faces.new(bot[::-1]), range(n - 1, -1, -1))):
        for l, i in zip(f.loops, order):
            l[uvl].uv = uvs[i]


def spray(bm, base, axis, n, L, spread, droop=0.3, wr=0.5):
    """Fan of n leaf cards bursting from `base` around `axis` (cone half-angle `spread`)."""
    axis = axis.normalized()
    e1 = axis.cross(Vector((0, 0, 1)))
    if e1.length < 0.2:
        e1 = axis.cross(Vector((1, 0, 0)))
    e1.normalize()
    e2 = axis.cross(e1)
    for _ in range(n):
        t, ph = rng.uniform(0.15, spread), rng.uniform(0, 2 * math.pi)
        d = axis * math.cos(t) + (e1 * math.cos(ph) + e2 * math.sin(ph)) * math.sin(t)
        ln = L * rng.uniform(0.75, 1.15)
        leaf(bm, base, d, ln, ln * wr, droop, rng.choice(LEAF_PTS))


def pad_p(c, R, th, droop, tilt=(0.0, 0.0)):
    return dict(c=Vector(c), R=R, th=th, droop=droop, tilt=tilt, ph=rng.uniform(0, 6.28))


def pad_pt(p, fr, a, top=True):
    """Point on a foliage pad: fr 0..1 from centre to the ragged rim, a = azimuth."""
    ph = p["ph"]
    rr = p["R"] * min(1.25, max(0.45, 0.8 + 0.3 * noise.noise(Vector((math.cos(a) * 1.6 + ph, math.sin(a) * 1.6, ph)))
                                + 0.12 * math.cos(3 * a + ph) + 0.08 * math.cos(5 * a + 2 * ph)))
    x, y = math.cos(a) * rr * fr, math.sin(a) * rr * fr
    z = p["th"] * (1 - fr ** 2) ** 0.5 * (0.8 + 0.3 * noise.noise(Vector((x * 0.25 + ph, y * 0.25, 0.7)))) - p["droop"] * fr ** 2.5
    if not top:
        z -= 0.5 + 0.3 * p["th"] * (1 - fr)
    return p["c"] + Vector((x, y, z + p["tilt"][0] * x + p["tilt"][1] * y))


def pad(bm, p, nseg=18, rings=4, uvs=7.0):
    """Flat ragged foliage shelf (closed shell: domed top, concave underside, thin drooping rim). Not a ball."""
    uvl = _uvl(bm)

    def grid(top):
        g = [[bm.verts.new(pad_pt(p, j / rings, 2 * math.pi * k / nseg, top)) for k in range(nseg)] for j in range(1, rings + 1)]
        return bm.verts.new(pad_pt(p, 0, 0, top)), g

    ct, T = grid(True)
    cb, B = grid(False)
    new, rim = [], []
    for k in range(nseg):
        k2 = (k + 1) % nseg
        new += [bm.faces.new((ct, T[0][k], T[0][k2])), bm.faces.new((cb, B[0][k2], B[0][k]))]
        for j in range(rings - 1):
            new.append(bm.faces.new((T[j][k], T[j + 1][k], T[j + 1][k2], T[j][k2])))
            new.append(bm.faces.new((B[j][k2], B[j + 1][k2], B[j + 1][k], B[j][k])))
        rim.append(bm.faces.new((T[-1][k], B[-1][k], B[-1][k2], T[-1][k2])))
    c = p["c"]
    for f in new:
        for l in f.loops:
            l[uvl].uv = ((l.vert.co.x - c.x) / uvs, (l.vert.co.y - c.y) / uvs)
    for f in rim:
        for l in f.loops:
            d = l.vert.co - c
            l[uvl].uv = ((math.atan2(d.y, d.x) / (2 * math.pi) + 0.5) * 6, d.z / uvs)  # seam faces smear once; acceptable on a rim


def crown_pad(mass, det, tip, R, th, droop, tilt, n_top=9, n_under=3, L=(3.0, 4.6)):
    """Pad hung on a branch tip, plus leaf sprays standing on its top surface and beards under its rim."""
    p = pad_p(tip + Vector((0, 0, 0.8)), R, th, droop, tilt)
    pad(mass, p)
    for _ in range(n_top):
        a, fr = rng.uniform(0, 6.283), rng.uniform(0.25, 1.0) ** 0.7
        spray(det, pad_pt(p, fr, a) - Vector((0, 0, 0.3)),
              Vector((math.cos(a), math.sin(a), 0)) * (0.35 + 0.6 * fr) + Vector((0, 0, 1.0 - 0.5 * fr)), 8, rng.uniform(*L), 1.0)
    for _ in range(n_under):
        a, fr = rng.uniform(0, 6.283), rng.uniform(0.5, 1.0)
        spray(det, pad_pt(p, fr, a, False), Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, -1)), 6, rng.uniform(1.8, 2.8), 0.8, droop=0.1)
    return p


def tuft(det, tip, axis, n=11, L=3.2):
    spray(det, tip, axis, n, L, 1.2)


def limb(bark, start, az, length, elev, r0, steps=5, droop=0.6, sides=6):
    """Tapering, drooping branch tube; returns its points so children can fork from them."""
    d0 = Vector((math.cos(az) * math.cos(elev), math.sin(az) * math.cos(elev), math.sin(elev)))
    pts = [start]
    for i in range(1, steps + 1):
        pts.append(pts[-1] + (d0 - Vector((0, 0, droop * i / steps))).normalized() * (length / steps))
    tube(bark, pts, [r0 * (1 - 0.8 * i / steps) for i in range(steps + 1)], sides=sides)
    return pts


def lean(z, h, amount):
    return WIND * (max(z, 0) / h) ** 1.8 * amount


# ------------------------------------------------------------------------------------------ structure pieces
def stair():
    s = bmesh.new()
    n, tread, rise = 10, 2.0, 0.8
    for i in range(n):
        top = (i + 1) * rise
        bx(s, 0, i * tread + tread / 2, -1.0, 9.0, tread, top + 1.0, bev=0.14)
        for sx in (-1, 1):
            bx(s, sx * 5.25, i * tread + tread / 2, -1.0, 1.5, tread, top + 2.6, bev=0.15, rz=sx * rng.uniform(-0.01, 0.01))
            bx(s, sx * 5.25, i * tread + tread / 2, top + 1.6, 1.9, tread + 0.15, 0.4, bev=0.08)
    obj("Bell_Stair_Segment", "Stone", s, MATS["Bell_Stone"])


def lantern():
    s, b, g = bmesh.new(), bmesh.new(), bmesh.new()
    bx(s, 0, 0, -0.5, 2.6, 2.6, 1.2, bev=0.18)
    bx(s, 0, 0, 0.7, 2.0, 2.0, 0.5, bev=0.12)
    bx(s, 0, 0, 1.2, 1.2, 1.2, 4.2, bev=0.18)
    bx(s, 0, 0, 5.4, 1.7, 1.7, 0.45, bev=0.12)
    bx(s, 0, 0, 5.85, 2.0, 2.0, 0.4, bev=0.1)
    z = 6.25
    for dx in (-1, 1):
        for dy in (-1, 1):
            bx(b, dx * 0.82, dy * 0.82, z, 0.22, 0.22, 1.5, mode="timber", bev=0.04, uvs=4.0)
    bx(b, 0, 0, z + 1.5, 2.1, 2.1, 0.22, bev=0.05, uvs=4.0)
    bx(g, 0, 0, z + 0.1, 1.2, 1.2, 1.3, bev=0.05, uvs=4.0)
    uvl = _uvl(s)
    before = set(s.faces)
    cone = bmesh.ops.create_cone(s, cap_ends=True, segments=4, radius1=2.9, radius2=0.4, depth=1.4)
    for v in cone["verts"]:
        v.co = Matrix.Rotation(math.pi / 4, 3, "Z") @ v.co + Vector((0, 0, z + 1.72 + 0.7))
    for f in [f for f in s.faces if f not in before]:
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x / 8, l.vert.co.y / 8 + l.vert.co.z / 16)
    cyl(b, 0, 0, z + 3.1, 0.28, 0.12, 0.7, seg=8, uvs=4.0)
    obj("Bell_Lantern_Post", "Stone", s, MATS["Bell_Stone"])
    obj("Bell_Lantern_Post", "Bronze", b, MATS["Bell_Bronze"])
    obj("Bell_Lantern_Post", "Glow", g, MATS["Bell_LanternGlow"])


def gate():
    t, s, b = bmesh.new(), bmesh.new(), bmesh.new()
    for sx in (-1, 1):
        bx(s, sx * 5.5, 0, -0.6, 3.2, 3.2, 1.4, bev=0.2)
        cyl(t, sx * 5.5, 0, 0.8, 1.05, 0.85, 13.2, seg=10)
        cyl(b, sx * 5.5, 0, 12.4, 1.18, 1.18, 0.6, seg=10, uvs=4.0)
        cyl(b, sx * 5.5, 0, 1.2, 1.15, 1.15, 0.5, seg=10, uvs=4.0)
    bx(t, 0, 0, 9.3, 16.8, 0.9, 1.3, mode="timber", bev=0.1)
    loft_beam(t, 19.0, 2.4, 1.3, lambda x: 2.0 * max(0, (abs(x) - 6.5) / 3.0) ** 2, z0=13.7)
    loft_beam(t, 17.0, 1.8, 0.8, lambda x: 0.9 * max(0, (abs(x) - 6.5) / 2.0) ** 2, z0=12.7)
    bx(t, 0, 0, 10.7, 2.2, 0.35, 2.0, mode="timber", bev=0.05)
    obj("Bell_Timber_Gate", "Timber", t, MATS["Bell_Timber"], recalc=True)
    obj("Bell_Timber_Gate", "Stone", s, MATS["Bell_Stone"])
    obj("Bell_Timber_Gate", "Bronze", b, MATS["Bell_Bronze"])


def terrace_wall(length=16.0, height=7.5, depth=3.0):
    s = bmesh.new()
    rows = 5
    ch = height / rows
    for r in range(rows):
        x = -length / 2
        if r % 2:
            x -= rng.uniform(0.8, 1.6)
        while x < length / 2 - 0.2:
            w = rng.uniform(1.8, 3.6)
            lo, hi = max(x, -length / 2), min(x + w, length / 2)
            if hi - lo > 0.4 and not (r == rows - 1 and hi < -length / 2 + 4 and rng.random() < 0.5):
                z0 = r * ch - (1.0 if r == 0 else 0.0)
                bx(s, (lo + hi) / 2, rng.uniform(-0.1, 0.1), z0, hi - lo - 0.08, depth, ch + (1.0 if r == 0 else 0.0) - 0.06,
                   bev=0.14, rz=rng.uniform(-0.015, 0.015))
            x += w
    x = -length / 2
    while x < length / 2 - 0.3:
        w = min(rng.uniform(2.6, 3.4), length / 2 - x)
        if not (rng.random() < 0.12):
            bx(s, x + w / 2, 0, height, w - 0.08, depth + 0.6, 0.5, bev=0.08)
        x += w
    obj("Bell_Terrace_Wall", "Stone", s, MATS["Bell_Stone"])


def bell_tower():
    s, t, b = bmesh.new(), bmesh.new(), bmesh.new()
    for i, w in enumerate((29.0, 26.0, 23.0)):
        bx(s, 0, 0, -1.0 + i * 1.3, w, w, 2.3, bev=0.2)
    base = 2.9
    P = 8.5
    for (px, py, hh) in ((-P, -P, 24.0), (-P, P, 24.0), (P, -P, 14.5), (P, P, 8.0)):
        z, cap = base, 0
        while z < base + hh - 0.5:
            h = min(rng.uniform(2.8, 3.6), base + hh - z)
            bx(s, px + rng.uniform(-0.1, 0.1), py + rng.uniform(-0.1, 0.1), z, 3.6, 3.6, h, bev=0.18, rz=rng.uniform(-0.03, 0.03),
               jag=1.2 if z + h >= base + hh - 0.6 and hh < 20 else 0.0)
            z += h
        if hh > 20:
            bx(s, px, py, z, 4.8, 4.8, 0.9, bev=0.14)
    for k in range(7):
        a = rng.uniform(0, 6.28)
        bx(s, math.cos(a) * rng.uniform(6, 12), math.sin(a) * rng.uniform(6, 12), 2.9, rng.uniform(1.6, 3), rng.uniform(1.6, 3),
           rng.uniform(1.0, 2.0), rz=rng.uniform(0, 3), bev=0.15, jag=0.4)
    zb = base + 24.0 + 0.9
    # bell beam between the two tall piers, bracing, and broken rafters
    bx(t, -P, 0, zb - 3.0, 1.5, 2 * P, 1.5, mode="timber", bev=0.1)
    for sy in (-1, 1):
        bx(t, -P, sy * (P - 3.2), zb - 5.5, 1.1, 5.0, 1.0, rz=0, mode="timber", bev=0.08)
    bx(t, -P, -P + 4.0, zb, 1.2, 9.0, 0.9, mode="timber", bev=0.08, jag=0.5)  # broken top plate stub, seated on a pier cap
    lathe(b, [(0.45, 4.5), (0.75, 4.35), (1.2, 4.0), (1.65, 3.5), (2.0, 2.5), (2.4, 1.2), (2.85, 0.25), (3.05, 0.0),
              (2.6, 0.0), (2.2, 1.0), (1.8, 2.3), (1.4, 3.2), (0.7, 3.7), (0.3, 3.9)], x=-P, z0=zb - 3.0 - 4.5 - 0.2, seg=20)
    bx(b, -P, 0, zb - 3.2, 0.8, 0.8, 0.4, bev=0.06, mode="timber", uvs=4.0)
    obj("Bell_Tower_Broken", "Stone", s, MATS["Bell_Stone"])
    obj("Bell_Tower_Broken", "Timber", t, MATS["Bell_Timber"])
    obj("Bell_Tower_Broken", "Bronze", b, MATS["Bell_Bronze"])


def roof_pt(R, u, v, top=True):
    """Hipped roof surface: eave square (half-width hw) at z0, flat ridge top, concave slope, eave corners swept out and up."""
    m = max(abs(u), abs(v))
    s = min(1.0, max(0.0, (m - R["flat"]) / (1 - R["flat"])))
    cf = min(abs(u), abs(v)) / m if m > 1e-6 else 0.0
    k = 1 + 0.10 * cf ** 2 * s ** 3
    z = R["z0"] + R["h"] * (1 - s) ** R["p"] + R["curl"] * s ** 3 * (0.18 + 0.82 * cf ** 3)
    if not top:
        z -= R["thick"] * (1 - 0.35 * s)
    return Vector((u * R["hw"] * k, v * R["hw"] * k, z))


def roof(bm, R, n=18, uvs=12.0):
    """Closed roof shell (top skin, ceiling, fascia) + four hip ridge tubes."""
    uvl = _uvl(bm)
    before = set(bm.faces)
    us = [-1 + 2 * i / n for i in range(n + 1)]
    T = [[bm.verts.new(roof_pt(R, u, v)) for v in us] for u in us]
    B = [[bm.verts.new(roof_pt(R, u, v, False)) for v in us] for u in us]
    for i in range(n):
        for j in range(n):
            bm.faces.new((T[i][j], T[i + 1][j], T[i + 1][j + 1], T[i][j + 1]))
            bm.faces.new((B[i][j], B[i][j + 1], B[i + 1][j + 1], B[i + 1][j]))
    ring = [(i, 0) for i in range(n)] + [(n, j) for j in range(n)] + [(i, n) for i in range(n, 0, -1)] + [(0, j) for j in range(n, 0, -1)]
    for (ai, aj), (bi, bj) in zip(ring, ring[1:] + ring[:1]):
        bm.faces.new((T[ai][aj], B[ai][aj], B[bi][bj], T[bi][bj]))
    new = [f for f in bm.faces if f not in before]
    bm.normal_update()
    for f in new:
        c = f.calc_center_median()
        for l in f.loops:
            x, y, z = l.vert.co
            if abs(f.normal.z) > 0.5:  # tile rows run parallel to the eave on every face
                l[uvl].uv = (x / uvs, abs(y) * 1.15 / uvs) if abs(c.y) >= abs(c.x) else (y / uvs, abs(x) * 1.15 / uvs)
            else:
                l[uvl].uv = ((x + y) / uvs, z / uvs)
    for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        ms = [R["flat"] + (1 - R["flat"]) * k / 8 for k in range(9)]
        tube(bm, [roof_pt(R, sx * m, sy * m) + Vector((0, 0, 0.35)) for m in ms], [0.55 - 0.08 * k / 8 for k in range(9)], sides=6)


def pavilion():
    """Bell Terrace hero landmark: stepped stone plinth + stair (-Y front), 4 vermilion-weathered timber pillars, open bell
    storey, two upturned hipped tile roofs, bronze finial spire and an original bronze temple bell with its striker log.
    ~55 x 55 x 84 studs (eave corners swept out), readable from ~1000 studs by the double upturned roof + spire silhouette."""
    s, t, rf, b = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for w, z0, top in ((48, -1.0, 2.3), (42, 2.3, 4.6), (36, 4.6, 7.0)):
        bx(s, 0, 0, z0, w, w, top - z0, bev=0.25)
    for k in range(8):  # 8 steps rise 0.875 / tread 2, climbing +Y into the plinth front
        top = (k + 1) * 0.875
        yc = -18 - (8 - k) * 2.0 + 1.0
        bx(s, 0, yc, -1.0, 10, 2.0, top + 1.0, bev=0.12)
        for sx in (-1, 1):
            bx(s, sx * 5.75, yc, -1.0, 1.5, 2.0, top + 1.9, bev=0.14)
    P, zt = 12.0, 28.4  # pillar spacing 24, pillar top (21 high above the deck)
    zr = zt + 4.7  # lower roof eave level
    R1 = dict(hw=28.0, z0=zr, h=18.0, flat=0.22, p=1.6, curl=8.0, thick=3.0)
    zu = zr + R1["h"] - 0.5
    R2 = dict(hw=16.0, z0=zu + 6.7, h=14.0, flat=0.2, p=1.6, curl=6.0, thick=2.4)
    zbeam = 24.6  # underside of the bell beam
    for px in (-P, P):
        for py in (-P, P):
            bx(s, px, py, 6.95, 5.0, 5.0, 0.7, bev=0.15)
            cyl(t, px, py, 7.4, 1.7, 1.4, zt - 7.4, seg=12)
            cyl(b, px, py, 7.5, 1.9, 1.9, 0.5, seg=12, uvs=4.0)
            cyl(b, px, py, zt - 0.7, 1.6, 1.6, 0.5, seg=12, uvs=4.0)
            for i in range(3):  # stepped bracket capital
                bx(t, px, py, zt - 0.1 + i * 1.1, 3.8 + 1.7 * i, 3.8 + 1.7 * i, 1.0, mode="timber", bev=0.08)
    for z in (10.0, 25.0):  # tie beams through the pillars (low one clears the bell lip)
        bx(t, 0, -P, z, 2 * P + 0.6, 1.0, 1.2, mode="timber", bev=0.08)
        bx(t, 0, P, z, 2 * P + 0.6, 1.0, 1.2, mode="timber", bev=0.08)
        bx(t, -P, 0, z, 1.0, 2 * P + 0.6, 1.2, mode="timber", bev=0.08)
        bx(t, P, 0, z, 1.0, 2 * P + 0.6, 1.2, mode="timber", bev=0.08)
    for sy in (-P, P):
        bx(t, 0, sy, zt + 3.0, 2 * P + 4, 1.8, 1.4, mode="timber", bev=0.08)
    for sx in (-P, P):
        bx(t, sx, 0, zt + 3.0, 1.8, 2 * P + 4, 1.4, mode="timber", bev=0.08)
    bx(t, 0, 0, zbeam, 2 * P + 0.6, 1.8, 1.8, mode="timber", bev=0.1)  # bell beam
    bx(t, 0, 0, zu, 11.4, 11.4, 6.6, mode="timber", bev=0.15)  # solid upper drum on the lower roof's flat top (no sky gap in the silhouette)
    bx(t, 0, 0, zu + 6.0, 13.0, 13.0, 1.2, mode="timber", bev=0.1)
    roof(rf, R1, n=22)
    roof(rf, R2, n=16)
    for R, nt in ((R1, 27), (R2, 17)):  # rafter tails under the eave and bronze up-curled hip ornaments
        for q in range(nt):
            u = -0.92 + 1.84 * q / (nt - 1)
            for uu, vv, sw in ((u, -1, 0), (u, 1, 0), (-1, u, 1), (1, u, 1)):
                pt = roof_pt(R, uu, vv)
                o = Vector((math.copysign(1, uu), 0, 0)) if sw else Vector((0, math.copysign(1, vv), 0))
                c = pt - o * 1.0
                bx(t, c.x, c.y, pt.z - R["thick"] * 0.65 - 0.55, 2.4 if sw else 0.7, 0.7 if sw else 2.4, 0.7, mode="timber", bev=0)
        for sx, sy in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
            c = roof_pt(R, sx, sy)
            o = Vector((sx, sy, 0)).normalized()
            tube(b, [c - o * 0.6, c + o * 1.8 + Vector((0, 0, 2.2)), c + o * 3.4 + Vector((0, 0, 5.5))], [1.0, 0.65, 0.15], sides=6, uvs=4.0)
    ztop = R2["z0"] + R2["h"]  # finial spire (bold on purpose: it carries the skyline at 1000 studs)
    lathe(b, [(0.05 * 1.5, 0), (2.4 * 1.5, 0), (2.6 * 1.5, 0.5 * 1.55), (2.2 * 1.5, 1.2 * 1.55), (1.0 * 1.5, 1.6 * 1.55), (0.7 * 1.5, 2.0 * 1.55),
              (1.9 * 1.5, 2.6 * 1.55), (1.9 * 1.5, 3.0 * 1.55), (0.6 * 1.5, 3.3 * 1.55), (0.5 * 1.5, 4.5 * 1.55), (1.6 * 1.5, 5.0 * 1.55),
              (1.6 * 1.5, 5.3 * 1.55), (0.5 * 1.5, 5.7 * 1.55), (0.4 * 1.5, 6.8 * 1.55), (1.3 * 1.5, 7.3 * 1.55), (1.3 * 1.5, 7.6 * 1.55),
              (0.4 * 1.5, 8.0 * 1.55), (0.35 * 1.5, 9.0 * 1.55), (0.9 * 1.5, 9.6 * 1.55), (0.9 * 1.5, 10.0 * 1.55), (0.4 * 1.5, 10.8 * 1.55),
              (0.05 * 1.5, 11.2 * 1.55)], z0=ztop - 0.5, seg=12)
    zb = zbeam - 1.0 - 11.6  # bell lip height: hangs from the beam on a bronze loop, 5 studs clear above the deck
    lathe(b, [(0.55, 11.6), (0.85, 11.4), (0.9, 10.9), (0.6, 10.6), (1.5, 10.4), (2.3, 9.8), (2.85, 9.0), (3.0, 8.6), (3.25, 8.5),
              (3.25, 8.0), (3.02, 7.9), (3.12, 6.4), (3.22, 4.6), (3.45, 4.4), (3.45, 3.9), (3.25, 3.8), (3.4, 2.2), (3.62, 1.0),
              (3.95, 0.45), (4.05, 0.0), (3.55, 0.0), (3.4, 0.9), (3.05, 3.0), (2.8, 6.0), (2.3, 8.2), (1.5, 9.4), (0.5, 10.0)],
          z0=zb, seg=28)
    cyl(b, 0, 0, zb + 11.4, 0.5, 0.5, zbeam + 0.4 - zb - 11.4, seg=8, uvs=4.0)
    zl = zb + 2.1  # striker log on two chains, aimed at the bell's strike band
    tube(t, [Vector((4.3, 0, zl)), Vector((11.8, 0, zl))], [0.7, 0.7], sides=8)
    for cx in (6.2, 10.2):
        tube(b, [Vector((cx, 0, zl + 0.6)), Vector((cx, 0, zbeam + 0.5))], [0.18, 0.18], sides=4, uvs=4.0)
    obj("Bell_Terrace_Pavilion", "Stone", s, MATS["Bell_Stone"])
    obj("Bell_Terrace_Pavilion", "Timber", t, MATS["Bell_Timber"])
    obj("Bell_Terrace_Pavilion", "Roof", rf, MATS["Bell_Roof"])
    obj("Bell_Terrace_Pavilion", "Bronze", b, MATS["Bell_Bronze"])


# ------------------------------------------------------------------------------------------ vegetation pieces
def trunk_pts(zs, h, amount, wob=0.5, sd=0):
    out = []
    for z in zs:
        out.append(Vector((noise.noise(Vector((z * 0.15, sd, 0))) * wob, noise.noise(Vector((0, sd, z * 0.15))) * wob, z)) + lean(z, h, amount))
    return out


def trunk_tube(bark, pts, radii, sides, roots, H):
    tube(bark, pts, radii, sides=sides)
    for i, (n, ph) in enumerate(roots):
        a = i * (2 * math.pi / len(roots)) + ph
        tube(bark, [Vector((math.cos(a), math.sin(a), n[0])), Vector((math.cos(a) * n[1], math.sin(a) * n[1], n[2])),
                    Vector((math.cos(a) * n[3], math.sin(a) * n[3], -0.7))], [n[4], n[4] * 0.75, n[4] * 0.42], sides=6)


def tier_limbs(bark, mass, det, H, amt, wob, sd, z, nb, ln, el, r0, R, th, ph, fork=True):
    """One tier: nb limbs leave the trunk at height z; each ends in a foliage pad and (optionally) forks a bare tufted twig."""
    st = trunk_pts([z], H, amt, wob, sd)[0]
    for i in range(nb):
        az = ph + i * (2 * math.pi / nb) + rng.uniform(-0.25, 0.25)
        pts = limb(bark, st, az, ln * rng.uniform(0.9, 1.15), el, r0, steps=5)
        if fork:
            sub = limb(bark, pts[3], az + rng.choice((-0.7, 0.7)), ln * 0.45, 0.25, r0 * 0.4, steps=3)
            tuft(det, sub[-1], Vector((math.cos(az), math.sin(az), 0.8)))
        crown_pad(mass, det, pts[-1], R * rng.uniform(0.85, 1.1), th, 2.0,
                  (-0.07 * math.cos(az), -0.07 * math.sin(az)))


def tree_a():
    bark, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    H = 38.0
    zs = [-1, 3, 9, 16, 23, 30, 37]
    trunk_tube(bark, trunk_pts(zs, H, 5.0, 0.5, 3), [3.8, 2.5, 2.0, 1.65, 1.35, 1.0, 0.6], 9,
               [((3.5, 3.5, 1.2, 6.0, 1.2), 0.3)] * 5, H)
    for z, a in ((9.0, 0.6), (13.0, 3.1), (15.5, 4.8)):  # snapped stubs: branch structure readable at player height
        limb(bark, trunk_pts([z], H, 5.0, 0.5, 3)[0], a, 4.5, 0.35, 0.8, steps=3, droop=0.3)
    for ti, (z, nb, ln, el, R) in enumerate(((18.5, 4, 12.0, 0.55, 8.5), (25.5, 4, 10.0, 0.6, 7.5), (32.0, 3, 8.0, 0.65, 6.2))):
        tier_limbs(bark, mass, det, H, 5.0, 0.5, 3, z, nb, ln, el, 1.1 - 0.12 * ti, R, 2.2, ti * 0.8)
    top = trunk_pts([37.5], H, 5.0, 0.5, 3)[0]
    crown_pad(mass, det, top, 6.0, 3.2, 1.2, (0, 0), n_top=8)
    tuft(det, top + Vector((0, 0, 3.5)), Vector((0, 0, 1)), n=12, L=3.4)
    obj("Canopy_Tree_A", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Canopy_Tree_A", "Leaves_Mass", mass, MATS["Bell_Leaf"], smooth=True)
    obj("Canopy_Tree_A", "Leaves_Detail", det, MATS["Bell_Leaf"], recalc=False)


def tree_b():
    bark, mass, det = bmesh.new(), bmesh.new(), bmesh.new()
    H = 54.0
    zs = [-1, 4, 12, 22, 32, 42, 50, 54.5]
    trunk_tube(bark, trunk_pts(zs, H, 6.0, 0.35, 8), [3.0, 2.0, 1.6, 1.3, 1.0, 0.75, 0.45, 0.2], 8,
               [((3.0, 3.0, 0.8, 5.0, 0.9), 0.8)] * 4, H)
    for z, a in ((7.0, 1.0), (11.5, 4.0)):
        limb(bark, trunk_pts([z], H, 6.0, 0.35, 8)[0], a, 4.0, 0.3, 0.7, steps=3, droop=0.3)
    for ti, z in enumerate((17, 24, 31, 38, 45)):
        tier_limbs(bark, mass, det, H, 6.0, 0.35, 8, z, 4 if ti == 0 else 3, 8.5 - ti * 1.2, 0.18, 0.75 - ti * 0.08,
                   7.5 - ti * 0.9, 2.0, ti * 0.95, fork=ti < 3)
    top = trunk_pts([53.0], H, 6.0, 0.35, 8)[0]
    crown_pad(mass, det, top, 2.8, 2.2, 0.8, (0, 0), n_top=5, n_under=2)
    tuft(det, top + Vector((0, 0, 2.5)), Vector((0, 0, 1)), n=10, L=3.0)
    obj("Canopy_Tree_B", "Bark", bark, MATS["Bell_Bark"], smooth=True)
    obj("Canopy_Tree_B", "Leaves_Mass", mass, MATS["Bell_Leaf"], smooth=True)
    obj("Canopy_Tree_B", "Leaves_Detail", det, MATS["Bell_Leaf"], recalc=False)


def shrub(name, S, nstems, seed, depth=2):
    """Round-3 woody shrub, no foliage pads: vase of forking, drooping stems (depth levels of forks), leaf clusters only on twig
    tips and as leaf pairs on the last twigs, so the branch structure and sky gaps read at player height. S = size scale."""
    rr = random.Random(seed)
    stems, det = bmesh.new(), bmesh.new()

    def lf(p, d, L):
        leaf(det, p, d, L, L * rr.uniform(0.42, 0.55), rr.uniform(0.15, 0.4), rr.choice(LEAF_PTS), tex=0.006)  # tiny UV patch = flat leaf colour, no dark edge blotches

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
        if dep > 0:
            for _ in range(rr.choice((2, 3))):
                nd = dd * 0.7 + Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-0.2, 0.6)))
                branch(pts[rr.choice((1, 2, 3))], nd, L * 0.62, r * 0.5, dep - 1)
            if dep == depth:  # a few leaves low on the main stems, so there is foliage at player height
                side = dd.cross(Vector((0, 0, 1))).normalized()
                lf(pts[1], dd * 0.4 + side * 0.9, 1.7 * S)
                lf(pts[1], dd * 0.4 - side * 0.9, 1.7 * S)
        else:
            side = dd.cross(Vector((0, 0, 1))).normalized()
            for i in (2, 3):
                for sg in (-1, 1):
                    lf(pts[i], dd * 0.45 + side * 0.8 * sg + Vector((0, 0, 0.25)), 1.6 * S)
            burst(pts[-1], dd + Vector((0, 0, 0.3)), 6, 1.9 * S)

    for i in range(nstems):
        az, el = i * 2 * math.pi / nstems + rr.uniform(-0.3, 0.3), rr.uniform(0.85, 1.25)
        branch(Vector((rr.uniform(-0.3, 0.3) * S, rr.uniform(-0.3, 0.3) * S, -0.3)),
               Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el))), 3.4 * S * rr.uniform(0.9, 1.15), 0.45 * S, depth)
    obj(name, "Stems", stems, MATS["Bell_Bark"], smooth=True)
    obj(name, "Leaves", det, MATS["Bell_Leaf"], recalc=False)


def shrubs():
    shrub("Understory_Shrub", 0.75, 6, 101)
    shrub("Understory_Shrub_Small", 0.4, 4, 102)


def fern():
    """Pinnate fronds: arched rachis with 17 narrow pinna pairs each (two-sided kites), inner fronds taller and more upright."""
    bm = bmesh.new()
    uvl = _uvl(bm)
    for i in range(12):
        az = i * 2 * math.pi / 12 + rng.uniform(-0.2, 0.2)
        out = Vector((math.cos(az), math.sin(az), 0))
        side = Vector((-math.sin(az), math.cos(az), 0))
        inner = i % 3 == 0
        Lf = rng.uniform(3.2, 4.4) if inner else rng.uniform(4.4, 6.4)
        th = rng.uniform(1.15, 1.35) if inner else rng.uniform(0.6, 1.0)
        pts = [Vector((0, 0, 0))]
        for k in range(1, 9):
            th_k = th - (k / 8) * 1.9
            pts.append(pts[-1] + (out * math.cos(th_k) + Vector((0, 0, math.sin(th_k)))) * (Lf / 8))
        pts = [p + lean(p.z, 6.0, 0.5) for p in pts]
        for k in range(8):  # rachis: thin two-sided strip
            w0, w1 = 0.13 * (1 - k / 9), 0.13 * (1 - (k + 1) / 9)
            q = [bm.verts.new(pts[k] - side * w0), bm.verts.new(pts[k + 1] - side * w1), bm.verts.new(pts[k + 1] + side * w1), bm.verts.new(pts[k] + side * w0)]
            qb = [bm.verts.new(v.co) for v in q]
            uv = ((0.44, k / 8), (0.44, (k + 1) / 8), (0.56, (k + 1) / 8), (0.56, k / 8))
            for f, order in ((bm.faces.new(q), range(4)), (bm.faces.new(qb[::-1]), range(3, -1, -1))):
                for l, j in zip(f.loops, order):
                    l[uvl].uv = uv[j]
        for j in range(17):
            t = 0.1 + 0.88 * j / 16
            kk = min(int(t * 8), 7)
            pos = pts[kk].lerp(pts[kk + 1], t * 8 - kk)
            tan = (pts[kk + 1] - pts[kk]).normalized()
            ln = Lf * 0.3 * max(0.18, math.sin(math.pi * t ** 0.65) ** 0.9)
            for sg in (-1, 1):
                leaf(bm, pos, tan * math.cos(1.0) + side * sg * math.sin(1.0), ln, ln * 0.26, 0.45, kite=True,
                     uvf=lambda tt, ss: (0.5 + ss * 0.45, tt))
    obj("Fern_Clump", "Fronds", bm, MATS["Bell_Fern"], smooth=True, recalc=False)


def grass():
    bm = bmesh.new()
    uvl = _uvl(bm)
    for i in range(44):
        a, r = rng.uniform(0, 6.28), rng.uniform(0, 1.2) ** 1.2
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        hgt = rng.uniform(2.2, 3.9)
        bend = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0.3, 1.0) + WIND * 0.5
        wid = rng.uniform(0.2, 0.3)
        side = Vector((-bend.y, bend.x, 0)).normalized()
        P = [base + bend * (k / 3) ** 2 * 1.4 + Vector((0, 0, hgt * k / 3)) for k in range(4)]
        P = [p - Vector((0, 0, 0.12 * (k / 3) ** 2 * hgt)) for k, p in enumerate(P)]
        for k in range(3):
            w0, w1 = wid * (1 - k / 3), wid * (1 - (k + 1) / 3)
            vs = [bm.verts.new(P[k] - side * w0), bm.verts.new(P[k] + side * w0)]
            if k < 2:
                vs += [bm.verts.new(P[k + 1] + side * w1), bm.verts.new(P[k + 1] - side * w1)]
                uvs = ((0, k / 3), (1, k / 3), (1, (k + 1) / 3), (0, (k + 1) / 3))
            else:
                vs += [bm.verts.new(P[3])]
                uvs = ((0, k / 3), (1, k / 3), (0.5, 1))
            f = bm.faces.new(vs)
            for l, uv in zip(f.loops, uvs):
                l[uvl].uv = uv
    obj("Grass_Clump", "Blades", bm, MATS["Bell_Grass"], smooth=True, recalc=False)


# ------------------------------------------------------------------------------------------ rocks (round 3)
QUAD = {"granite": (0, 0), "moss": (1, 0), "mud": (0, 1), "lichen": (1, 1)}


def fbm(p, o=3):
    s, a, f = 0.0, 1.0, 1.0
    for _ in range(o):
        s += a * noise.noise(p * f)
        a *= 0.5
        f *= 2.1
    return s


def rock(bm, c, R, rr, sub=4, planes=0, flat_top=None, bottom=-1.0, rough=0.12, lump=0.28, rz=0.0, moss_bias=0.0, mud_h=0.9, S=16.0):
    """Noise-displaced ellipsoid at c, radii R, optionally cut by random planes (facets), flattened at flat_top, clamped at
    z >= bottom (buried). UVs (never tiled, 32 px/stud) pick a Bell_Granite quadrant per face: moss on up-facing patches, mud-stained
    base below mud_h, a little lichen, granite elsewhere."""
    c, uvl = Vector(c), _uvl(bm)
    ox = Vector((rr.uniform(0, 80), rr.uniform(0, 80), rr.uniform(0, 80)))
    rot = Matrix.Rotation(rz, 3, "Z")
    cuts = []
    for _ in range(planes):
        n = Vector((rr.uniform(-1, 1), rr.uniform(-1, 1), rr.uniform(-0.35, 1.0))).normalized()
        cuts.append((n, math.sqrt((n.x * R[0]) ** 2 + (n.y * R[1]) ** 2 + (n.z * R[2]) ** 2) * rr.uniform(0.6, 0.85)))
    vs = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)["verts"]
    for v in vs:
        u = v.co.copy()
        k = 1 + lump * fbm(u * 1.4 + ox, 2) + rough * fbm(u * 5.0 + ox, 3)
        p = Vector((u.x * R[0] * k, u.y * R[1] * k, u.z * R[2] * k))
        for n, d in cuts:
            e = p.dot(n)
            if e > d:
                p -= n * (e - d)
        if flat_top is not None:
            p.z = min(p.z, flat_top - c.z)
        v.co = rot @ p + c
        v.co.z = max(v.co.z, bottom)
    bm.normal_update()
    lo = [min(v.co[i] for v in vs) for i in range(3)]
    ex = max(max(v.co[i] for v in vs) - lo[i] for i in range(3))
    S = max(S, ex * 1.02)
    offs = {q: (rr.uniform(0, 1 - ex / S), rr.uniform(0, 1 - ex / S)) for q in QUAD}
    pad_ = 0.03
    for f in {f for v in vs for f in v.link_faces}:
        n, fc = f.normal, f.calc_center_median()
        up = 0.7 * Vector(((fc.x - c.x) / R[0], (fc.y - c.y) / R[1], (fc.z - c.z) / R[2])).normalized().z + 0.3 * n.z  # mostly the macro (ellipsoid-direction) slope, so moss patches stay contiguous
        if (up - 0.45) * 2.2 + 0.7 * fbm(fc * 0.14 + ox, 2) + moss_bias > 0:  # low-frequency noise: moss in patches, not per-triangle speckle
            q = "moss"
        elif fc.z < mud_h * (1 + 0.6 * fbm(fc * 0.3 + ox, 2)):  # ragged mud line
            q = "mud"
        elif fbm(fc * 0.12 + ox * 2, 2) > 0.8:
            q = "lichen"
        else:
            q = "granite"
        qu, qv = QUAD[q]
        ua, va = ((1, 2), (0, 2), (0, 1))[max(range(3), key=lambda i: abs(n[i]))]
        for l in f.loops:
            co = l.vert.co
            fu, fv = (co[ua] - lo[ua]) / S + offs[q][0], (co[va] - lo[va]) / S + offs[q][1]
            l[uvl].uv = ((qu + pad_ + fu * (1 - 2 * pad_)) * 0.5, (qv + pad_ + fv * (1 - 2 * pad_)) * 0.5)


def boulders():
    """Three Bellwood forest rocks, each a cluster on a buried base: A rounded mossy boulder + companions, B tall angular
    faceted outcrop, C low flat-topped ledge (split in two, walkable top)."""
    rr = random.Random(301)
    a = bmesh.new()
    rock(a, (0, 0, 2.4), (5.0, 4.4, 3.8), rr, sub=5, rough=0.1)
    rock(a, (6.2, 2.4, 1.0), (3.0, 2.6, 2.2), rr, sub=4)
    rock(a, (-5.6, -3.0, 0.5), (1.9, 1.7, 1.5), rr, sub=4)
    rock(a, (3.2, -4.4, 0.2), (1.2, 1.1, 0.9), rr, sub=3)
    obj("Boulder_Granite_A", "Stone", a, MATS["Bell_Granite"], smooth=True)
    b = bmesh.new()
    rock(b, (0, 0, 4.2), (3.4, 2.5, 5.4), rr, sub=5, planes=9, lump=0.18, rough=0.05, rz=0.4, moss_bias=-0.6)
    rock(b, (4.4, 1.6, 1.4), (2.5, 2.1, 2.5), rr, sub=4, planes=7, lump=0.18, rough=0.05, moss_bias=-0.4)
    rock(b, (-3.8, -2.6, 0.7), (1.8, 1.5, 1.5), rr, sub=4, planes=6, lump=0.15, rough=0.05)
    obj("Boulder_Granite_B", "Stone", b, MATS["Bell_Granite"], smooth=False)
    cc = bmesh.new()
    rock(cc, (0, 0, 1.4), (7.0, 4.8, 3.0), rr, sub=5, planes=5, flat_top=3.1, lump=0.15, rough=0.07, moss_bias=0.15)
    rock(cc, (10.4, -1.4, 0.9), (4.2, 3.4, 2.2), rr, sub=4, planes=4, flat_top=2.2, lump=0.15, rough=0.07, moss_bias=0.1)
    rock(cc, (-8.0, 4.2, 0.3), (1.8, 1.6, 1.2), rr, sub=3)
    obj("Boulder_Granite_C", "Stone", cc, MATS["Bell_Granite"], smooth=False)


def stepping_stones():
    """Path set along +Y (18 studs, gentle S curve): 7 flat-topped stepping stones (top 0.6 above ground) with half-buried edge cobbles
    on both sides. Centre of the path at the origin; stones sit on z = 0."""
    rr = random.Random(401)
    bm = bmesh.new()
    px = lambda y: 2.2 * math.sin(y * 0.35)
    for i in range(7):
        y = -9.0 + 3.0 * i
        rock(bm, (px(y) + rr.uniform(-0.4, 0.4), y + rr.uniform(-0.3, 0.3), 0.0), (rr.uniform(1.7, 2.3), rr.uniform(1.4, 1.9), 0.9), rr, sub=3,
             flat_top=0.6 + rr.uniform(0, 0.12), bottom=-0.9, lump=0.12, rough=0.06, rz=rr.uniform(0, 3.14), moss_bias=-1.1, mud_h=0.25, S=8.0)
    for sg in (-1, 1):
        y = -9.5
        while y < 9.5:
            if rr.random() > 0.2:
                rock(bm, (px(y) + sg * rr.uniform(3.8, 5.0), y, 0.1), (rr.uniform(0.9, 1.5), rr.uniform(0.9, 1.4), rr.uniform(0.7, 1.1)), rr, sub=3,
                     bottom=-0.8, lump=0.2, rz=rr.uniform(0, 3.14), moss_bias=-0.7, mud_h=0.4, S=8.0)
            y += rr.uniform(2.0, 2.8)
    obj("Stepping_Stones", "Stone", bm, MATS["Bell_Granite"], smooth=True)


# ------------------------------------------------------------------------------------------ scene, export, renders
def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def setup_render():
    sc = bpy.context.scene
    ids = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in ids)
    sc.render.resolution_x, sc.render.resolution_y = 960, 720
    w = bpy.data.worlds.new("w")
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.55, 0.64, 0.72, 1)
    bg.inputs["Strength"].default_value = 0.9
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.4
    sun.rotation_euler = (0.9, 0.15, 2.2)
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.clip_start, cam.data.clip_end = 0.5, 6000  # the 1000-stud shot otherwise clips the far half of the landmark
    sc.collection.objects.link(cam)
    sc.camera = cam
    gm = bpy.data.materials.new("Ground")
    try:
        gm.use_nodes = True
    except Exception:
        pass
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.10, 0.15, 0.06, 1)
    me = bpy.data.meshes.new("Ground")
    me.from_pydata([(-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(gm)
    g = bpy.data.objects.new("Ground", me)
    sc.collection.objects.link(g)
    return sc, cam, g


V = []  # vignette / comparison instances (share mesh data with the piece originals)


def put(name, x, y, z, rz=0.0, s=1.0):
    sc = bpy.context.scene
    for o in PIECES[name]:
        c = bpy.data.objects.new("V_" + o.name, o.data)
        c.matrix_world = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Scale(s, 4)
        sc.collection.objects.link(c)
        V.append(c)


def clear_put():
    for c in V:
        bpy.data.objects.remove(c)
    V.clear()


def shoot(sc, cam, eye, target, lens, path, res=(960, 720), vert=False):
    cam.data.sensor_fit = "VERTICAL" if vert else "AUTO"  # vert: lens is chosen for the 24 mm sensor height
    cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.location = eye
    cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    (OUT / "maps").mkdir(parents=True, exist_ok=True)
    CAP.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    stone_mat(), timber_mat(), bronze_mat(), glow_mat(), bark_mat(), leaf_mat(), roof_mat(), granite_mat()
    blade_mat("Bell_Fern", 256, 256, (0.08, 0.24, 0.07), (0.30, 0.50, 0.15), 61, double=False)  # pinnae carry real back faces
    blade_mat("Bell_Grass", 128, 256, (0.11, 0.20, 0.06), (0.60, 0.58, 0.30), 62)
    for fn in (stair, lantern, gate, terrace_wall, bell_tower, pavilion, tree_a, tree_b, shrubs, fern, grass, boulders, stepping_stones):
        fn()
    # export: one GLB per piece, textures embedded
    for name, objs in PIECES.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        kw = dict(filepath=str(OUT / f"{name}.glb"), export_format="GLB", use_selection=True, export_apply=False)
        bpy.ops.export_scene.gltf(**kw)
        lo, hi = bbox(objs)
        info = manifest["pieces"][name]
        info["file"] = f"{name}.glb"
        info["size_studs_xyz"] = [round(hi.x - lo.x, 1), round(hi.y - lo.y, 1), round(hi.z - lo.z, 1)]
        info["materials"] = sorted({m.name for o in objs for m in o.data.materials})
        info["tris_total"] = sum(info["sub_meshes"].values())
    manifest["textures"] = {i.name: list(i.size) for i in bpy.data.images if i.name.startswith("Bell_")}
    manifest["lod"] = {"Canopy_Tree_A / Canopy_Tree_B": "Bark + Leaves_Mass is the distance LOD (flat shelves read as tiered crowns); Leaves_Detail (leaf sprays) can be dropped or faded beyond ~150 studs",
                       "Understory_Shrub / Understory_Shrub_Small": "Stems + Leaves, no mass sub-mesh: cull whole piece beyond ~120 studs",
                       "Boulder_Granite_A/B/C, Stepping_Stones": "single Stone sub-mesh each; Bell_Granite is a 1024 atlas (granite / moss / mud / lichen quadrants chosen per face by UV, never tiled: leave SurfaceAppearance StudsPerTile at default)",
                       "Bell_Terrace_Pavilion": "Roof + Stone + Timber carry the 1000-stud silhouette; Bronze (bell, finial) is the close detail"}
    manifest["studio_import_notes"] = ["Import each GLB with the 3D Importer; one MeshPart per sub-mesh (names are Piece__Sub), keep pivot at origin",
                                       "Per-material PBR maps are in maps/ (Color, Normal OpenGL, Roughness, Metal for Bell_Bronze): build one SurfaceAppearance per material",
                                       "Fern and leaf sprays are real two-sided geometry (no alpha, no DoubleSided needed); Grass_Clump blades are single sided: set DoubleSided = true",
                                       "Foliage is opaque: apply the sway from height above the base pivot (no COLOR_0 exported)"]
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))

    sc, cam, ground = setup_render()
    allobjs = [o for objs in PIECES.values() for o in objs]
    for name, objs in PIECES.items():
        for o in allobjs:
            o.hide_render = o not in objs
        lo, hi = bbox(objs)
        c, d = (lo + hi) / 2, (hi - lo).length
        ground.scale = (d * 0.9 + 6, d * 0.9 + 6, 1)
        ground.location = Vector((c.x, c.y, 0))
        shoot(sc, cam, c + Vector((0.75, -1.0, 0.42)).normalized() * d * (0.8 if d < 20 else 1.25), c, 42, CAP / f"{name}.png")
    for name, eye, tgt, lens in (("Understory_Shrub", (0, -12, 5), (0, 0, 3), 34), ("Understory_Shrub_Small", (0, -8, 5), (0, 0, 1.6), 34),
                                 ("Boulder_Granite_A", (0, -24, 5), (0, 0, 3.5), 30), ("Boulder_Granite_B", (0, -22, 5), (1, 0, 5), 30),
                                 ("Boulder_Granite_C", (0, -28, 5), (1, 0, 2), 30), ("Stepping_Stones", (0, -17, 5), (0, 0, 0.3), 34)):
        for o in allobjs:  # player-height (5 stud eye) render of each round-3 piece
            o.hide_render = o not in PIECES[name]
        ground.scale, ground.location = (200, 200, 1), Vector((0, 0, 0))
        shoot(sc, cam, Vector(eye), Vector(tgt), lens, CAP / f"eye_{name}.png")
    for o in allobjs:
        o.hide_render = True
    if R1:  # old (round 1 GLB) on the left, new on the right, camera at player eye height (5 studs)
        for name, dx, eye, tgt, lens in (("Canopy_Tree_A", 27, (0, -66, 5), (0, 0, 20), 24), ("Canopy_Tree_B", 20, (0, -72, 5), (0, 0, 24), 24),
                                         ("Fern_Clump", 5.5, (0, -13, 5), (0, 0, 1.2), 34), ("Understory_Shrub", 5.5, (0, -15, 5), (0, 0, 2.5), 34)):
            ground.scale, ground.location = (200, 200, 1), Vector((0, 0, 0))
            before = set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=str(R1 / f"{name}.glb"))
            old = [o for o in bpy.data.objects if o not in before]
            for o in old:
                if o.parent is None:
                    o.location.x -= dx
            put(name, dx, 0, 0)
            shoot(sc, cam, Vector(eye), Vector(tgt), lens, CAP / f"eye_compare_{name}.png")
            for o in old:
                bpy.data.objects.remove(o)
            clear_put()
    # vignette: stair up to a plateau, gate, wall flanks, lanterns, broken tower, trees, understory, and the pavilion beyond
    vm = bpy.data.materials["Ground"]
    pl = bmesh.new()
    bmesh.ops.create_cube(pl, size=1.0)
    plm = bpy.data.meshes.new("Plateau")
    pl.to_mesh(plm)
    plm.materials.append(vm)
    plo = bpy.data.objects.new("Plateau", plm)
    plo.scale, plo.location = (500, 190, 8.0), (0, 20 + 95, 4.0)
    sc.collection.objects.link(plo)
    ground.scale, ground.location = (2500, 2500, 1), Vector((0, 300, 0))
    put("Bell_Stair_Segment", 0, 0, 0)
    for sx in (-1, 1):
        put("Bell_Terrace_Wall", sx * (6.0 + 8.0 + 0.5), 18.5, 0.0)
        put("Bell_Terrace_Wall", sx * (6.0 + 24.0 + 0.5), 18.5, 0.0)
        put("Bell_Lantern_Post", sx * 8.0, 2.0, 0)
        put("Bell_Lantern_Post", sx * 9.5, 25.0, 8.0)
    put("Bell_Timber_Gate", 0, 36, 8.0)
    put("Bell_Tower_Broken", -45, 62, 8.0, 0.3)
    put("Bell_Terrace_Pavilion", 0, 160, 8.0)
    for (x, y, z, rz, nm) in ((-30, 42, 8, 0.4, "Canopy_Tree_A"), (32, 50, 8, 1.5, "Canopy_Tree_B"), (52, 30, 0, 2.0, "Canopy_Tree_A"),
                              (-55, 12, 0, 0.9, "Canopy_Tree_B"), (30, 72, 8, 0.3, "Canopy_Tree_A"), (-32, 64, 8, 2.2, "Canopy_Tree_B")):
        put(nm, x, y, z, rz)
    put("Stepping_Stones", 0, -12, 0)
    for nm, x, y, rz in (("Boulder_Granite_A", -24, -2, 0.5), ("Boulder_Granite_B", 22, -12, 2.0), ("Boulder_Granite_C", -40, 8, 0.2)):
        put(nm, x, y, 0, rz)
    for i in range(26):
        x, y = rng.uniform(-60, 60), rng.uniform(-8, 46)
        z = 8.0 if y > 22 else 0.0
        if abs(x) < 8 and y < 24:
            continue
        put(rng.choice(["Fern_Clump", "Understory_Shrub", "Understory_Shrub_Small", "Understory_Shrub_Small", "Grass_Clump", "Grass_Clump"]),
            x, y, z, rng.uniform(0, 6.28), rng.uniform(0.9, 1.4))
    shoot(sc, cam, Vector((0, -32, 5.0)), Vector((0, 36, 14)), 28, CAP / "vignette_player.png")
    shoot(sc, cam, Vector((-85, -70, 75)), Vector((0, 110, 25)), 30, CAP / "vignette_high.png")
    shoot(sc, cam, Vector((0, 70, 13.0)), Vector((0, 160, 44)), 22, CAP / "eye_pavilion_approach.png")
    for nm, dx, dy, rz in (("Stepping_Stones", 0, 0, 0), ("Boulder_Granite_A", -22, 14, 0.5), ("Boulder_Granite_B", 20, 12, 2.0), ("Boulder_Granite_C", 14, -8, 0.4),
                           ("Understory_Shrub", -10, 10, 0.3), ("Understory_Shrub", 12, 20, 2.0), ("Understory_Shrub_Small", -6, 4, 1.0),
                           ("Understory_Shrub_Small", 8, 6, 2.5), ("Understory_Shrub_Small", -16, 22, 0.2), ("Fern_Clump", 5, 8, 0.7), ("Fern_Clump", -8, 14, 2.1),
                           ("Grass_Clump", 7, 3, 0), ("Grass_Clump", -4, 9, 1.0), ("Grass_Clump", 10, 14, 2.0), ("Canopy_Tree_A", 34, 40, 0.3), ("Canopy_Tree_B", -36, 34, 1.4)):
        put(nm, -1500 + dx, dy, 0, rz)  # forest-floor clearing far to the side (outside the 1000-stud shot), eye-height read of understory + rocks
    shoot(sc, cam, Vector((-1500, -26, 5.0)), Vector((-1500, 8, 3.0)), 28, CAP / "vignette_floor_player.png")
    for i in range(18):  # far forest framing for the 1000-stud read
        put(rng.choice(("Canopy_Tree_A", "Canopy_Tree_B")), rng.choice((-1, 1)) * rng.uniform(70, 280), rng.uniform(-700, -60), 0, rng.uniform(0, 6.28))
    # Roblox default 70 degree vertical FOV on a 1920x1080 frame: lens = 12 / tan(35 deg) on the 24 mm sensor height
    shoot(sc, cam, Vector((0, -850, 5.0)), Vector((0, 160, 45)), 12 / math.tan(math.radians(35)), CAP / "pavilion_1000studs.png",
          res=(1920, 1080), vert=True)
    for o in allobjs:
        o.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "bellwood_slice_kit.blend"), compress=True)
    print("SLICE_OK", json.dumps({k: v["sub_meshes"] for k, v in manifest["pieces"].items()}), flush=True)


main()

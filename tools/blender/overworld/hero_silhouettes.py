"""Silhouette-first hero landmarks (blockout level) for the four far biomes.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender" -b -P tools/blender/overworld/hero_silhouettes.py

Names, sizes and sub-mesh names match the placeholder kit slots in src/shared/BiomeDressing.luau
(Ravine_Aqueduct_Arch, Basin_Gate_Statue, Snow_Watch_Beacon, Summit_Temple_Pagoda, Summit_Temple_Wing), so the swap is data only.
1 Blender unit = 1 stud, Z up in Blender (glTF Y up), base centre at the origin. Simple baked-PBR materials, flat shaded.
Every sub-mesh asserted < 18000 tris. Writes GLB + maps/ + manifest.json to assets/source/overworld/hero and eye-height
renders (plus one far silhouette of the temple) to outputs/claude-open-world-2026-11-14/captures/slice/.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/source/overworld/hero"
CAP = ROOT / "outputs/claude-open-world-2026-11-14/captures/slice"
TRI_CAP = 18000
PIECES, MATS, MANIFEST = {}, {}, {"round": 1, "build": "blender -b -P tools/blender/overworld/hero_silhouettes.py", "tri_cap_per_sub_mesh": TRI_CAP,
                                 "units": "studs (1 BU = 1 stud)", "pivot": "base centre at origin, z=0", "pieces": {}}


# ------------------------------------------------------------------ materials (small tileable baked PBR)
def _blur(g, k=3):
    for _ in range(k):
        g = (g + np.roll(g, 1, 0) + np.roll(g, -1, 0) + np.roll(g, 1, 1) + np.roll(g, -1, 1)) / 5
    return g


def _save(name, arr, non_color):
    nv, nu = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, 2)
    im = bpy.data.images.new(name, nu, nv, alpha=False, is_data=non_color)
    im.pixels.foreach_set(np.concatenate([np.clip(arr, 0, 1), np.ones((nv, nu, 1))], 2).astype(np.float32).ravel())
    im.filepath_raw = str(OUT / "maps" / f"{name}.png")
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im


def material(name, rgb, rough, metal=0.0, emit=None, seed=1, n=128):
    r = np.random.RandomState(seed)
    low = _blur(np.kron(r.rand(16, 16), np.ones((n // 16, n // 16))), 4)
    low = (low - low.min()) / (np.ptp(low) + 1e-6)
    fine = _blur(r.rand(n, n), 1)
    h = 0.6 * low + 0.4 * fine
    col = np.array(rgb)[None, None, :] * (0.86 + 0.28 * h[..., None])
    gx, gy = np.roll(h, -1, 1) - np.roll(h, 1, 1), np.roll(h, -1, 0) - np.roll(h, 1, 0)
    nrm = np.stack([-gx * 6, -gy * 6, np.ones_like(h)], 2)
    nrm = nrm / np.linalg.norm(nrm, axis=2, keepdims=True) * 0.5 + 0.5
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    p = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")

    def tex(im, sock):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = im
        nt.links.new(t.outputs["Color"], p.inputs[sock])

    tex(_save(f"{name}_Color", col, False), "Base Color")
    tex(_save(f"{name}_Roughness", np.clip(rough + 0.12 * (h - 0.5), 0, 1), True), "Roughness")
    if metal > 0:
        tex(_save(f"{name}_Metal", np.full((n, n), metal), True), "Metallic")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = _save(f"{name}_Normal", nrm, True)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(t.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    if emit:
        sock = "Emission Color" if "Emission Color" in p.inputs else "Emission"
        p.inputs[sock].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = 3.0
    m.use_backface_culling = True
    MATS[name] = m
    return m


# ------------------------------------------------------------------ geometry
def V(x, y, z):
    return Vector((x, y, z))


def loft(bm, rings, caps=True):
    """Closed shell through equal-length rings (each a list of Vectors)."""
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(vs[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    if caps:
        bm.faces.new(vs[0][::-1])
        bm.faces.new(vs[-1])


def rect(cx, cy, z, w, d):
    return [V(cx - w / 2, cy - d / 2, z), V(cx + w / 2, cy - d / 2, z), V(cx + w / 2, cy + d / 2, z), V(cx - w / 2, cy + d / 2, z)]


def _place(bm, start, cx, cy, z0, rz):
    for v in list(bm.verts)[start:]:
        v.co = Matrix.Rotation(rz, 3, "Z") @ v.co + V(cx, cy, z0)


def box(bm, cx, cy, z0, w, d, h, rz=0.0):
    s = len(bm.verts)
    loft(bm, [rect(0, 0, 0, w, d), rect(0, 0, h, w, d)])
    _place(bm, s, cx, cy, z0, rz)


def tapered(bm, cx, cy, z0, w0, d0, w1, d1, h, rz=0.0):
    s = len(bm.verts)
    loft(bm, [rect(0, 0, 0, w0, d0), rect(0, 0, h, w1, d1)])
    _place(bm, s, cx, cy, z0, rz)


def poly_ring(cx, cy, z, r, n, rot=0.0, sq=1.0):
    return [V(cx + r * math.cos(rot + 2 * math.pi * i / n), cy + r * sq * math.sin(rot + 2 * math.pi * i / n), z) for i in range(n)]


def cone(bm, cx, cy, z0, r0, r1, h, n=8, rot=0.0):
    s = len(bm.verts)
    loft(bm, [poly_ring(0, 0, 0, r0, n, rot), poly_ring(0, 0, h, max(r1, 0.001), n, rot)])
    _place(bm, s, cx, cy, z0, 0.0)


def arch(bm, cx, z_spring, r_in, thick, depth, a0=180.0, a1=0.0, steps=14):
    """Stone arch ring (extruded along Y) from angle a0 to a1 degrees about (cx, z_spring)."""
    ang = [math.radians(a0 + (a1 - a0) * i / steps) for i in range(steps + 1)]
    outer = [(cx + (r_in + thick) * math.cos(a), z_spring + (r_in + thick) * math.sin(a)) for a in ang]
    inner = [(cx + r_in * math.cos(a), z_spring + r_in * math.sin(a)) for a in ang][::-1]
    prof = outer + inner
    loft(bm, [[V(x, -depth / 2, z) for x, z in prof], [V(x, depth / 2, z) for x, z in prof]])


def roof(bm, cx, cy, z0, hx, hy, rise, curl, th=1.2):
    """Hip roof with raised corners (upturned eaves); closed solid, apex at centre."""
    ring = [(hx, -hy, curl), (hx, 0, 0), (hx, hy, curl), (0, hy, 0), (-hx, hy, curl), (-hx, 0, 0), (-hx, -hy, curl), (0, -hy, 0)]
    t = [bm.verts.new(V(cx + x, cy + y, z0 + z)) for x, y, z in ring]
    b = [bm.verts.new(V(cx + x * 0.9, cy + y * 0.9, z0 + z - th)) for x, y, z in ring]
    a = bm.verts.new(V(cx, cy, z0 + rise))
    ab = bm.verts.new(V(cx, cy, z0 + rise - th * 1.4))
    for i in range(8):
        j = (i + 1) % 8
        bm.faces.new((a, t[i], t[j]))
        bm.faces.new((ab, b[j], b[i]))
        bm.faces.new((t[i], b[i], b[j], t[j]))


def build(piece, sub, mat, fn):
    bm = bmesh.new()
    fn(bm)
    # box-projected UVs, 1 tile per 16 studs
    uvl = bm.loops.layers.uv.verify()
    bm.normal_update()
    for f in bm.faces:
        a = max(range(3), key=lambda i: abs(f.normal[i]))
        ax = [i for i in range(3) if i != a]
        for l in f.loops:
            l[uvl].uv = (l.vert.co[ax[0]] / 16.0, l.vert.co[ax[1]] / 16.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(f"{piece}__{sub}")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MATS[mat])
    me.shade_flat()
    o = bpy.data.objects.new(f"{piece}__{sub}", me)
    bpy.context.scene.collection.objects.link(o)
    tris = len(me.polygons)
    assert tris < TRI_CAP, (o.name, tris)
    PIECES.setdefault(piece, []).append(o)
    MANIFEST["pieces"].setdefault(piece, {"sub_meshes": {}, "materials": []})["sub_meshes"][o.name] = tris
    MANIFEST["pieces"][piece]["materials"].append(mat)


# ------------------------------------------------------------------ pieces
def aqueduct():
    P = "Ravine_Aqueduct_Arch"
    spring, rin, th = 28.0, 12.0, 5.0
    centres = [-54, -18, 18, 54]
    spans = [(-36, a0, a1) for a0, a1 in [(180, 118)]] + [(0, 180, 0), (36, 180, 0)]  # left arch broken: only its springer survives

    def piers(bm):
        for cx in centres:
            box(bm, cx, 0, 0, 14, 18, 3)
            box(bm, cx, 0, 3, 12, 16, spring - 3)
            box(bm, cx, 0, spring - 1.5, 13.5, 17.5, 2)
        box(bm, 53, 0, 3, 15, 17, 49)  # tower shaft grows out of the end pier
        tapered(bm, 53, 0, 52, 15, 17, 12, 14, 18)
        tapered(bm, 53, 0, 70, 19, 21, 22, 24, 4)  # flared lantern gallery
        tapered(bm, 53, 0, 74, 14, 16, 3, 3, 8)  # stepped crown
        box(bm, -33, -4, 0, 6, 5, 5, 0.4), box(bm, -28, 5, 0, 5, 6, 3.5, -0.3)  # fallen blocks

    def arches(bm):
        for cx, a0, a1 in spans:
            arch(bm, cx, spring, rin, th, 15, a0, a1)

    def deck(bm):
        box(bm, 13, 0, 45, 94, 20, 4)
        for sy in (-9, 9):
            for i in range(9):
                if i not in (1, 5):  # broken parapet gaps
                    box(bm, -28 + i * 10.5, sy, 49, 9.5, 2, 3.5 + (i % 3 == 0) * 1.5)

    build(P, "Piers", "Hero_Sandstone", piers)
    build(P, "Arches", "Hero_SandstoneDark", arches)
    build(P, "Deck", "Hero_Slate", deck)


def beacon():
    P = "Snow_Watch_Beacon"

    def stone(bm):
        loft(bm, [poly_ring(0, 0, 0, 8.4, 8, 0.39), poly_ring(0, 0, 20, 7.0, 8, 0.39), poly_ring(0, 0, 52, 5.6, 8, 0.39)])
        loft(bm, [poly_ring(0, 0, 52, 6.0, 8, 0.39), poly_ring(0, 0, 52.6, 9.0, 8, 0.39), poly_ring(0, 0, 55.2, 9.0, 8, 0.39), poly_ring(0, 0, 55.4, 7.2, 8, 0.39)])

    def timber(bm):
        for i in range(4):
            a = math.pi / 4 + i * math.pi / 2
            box(bm, 7.2 * math.cos(a), 7.2 * math.sin(a), 55.4, 1.4, 1.4, 16)
        loft(bm, [poly_ring(0, 0, 71, 10, 8, 0.39), poly_ring(0, 0, 72.5, 8.4, 8, 0.39), poly_ring(0, 0, 84, 0.8, 8, 0.39)])
        box(bm, 0, 0, 83, 1.4, 1.4, 17)  # signal mast
        box(bm, 3.2, 0, 94, 6.4, 0.5, 3.4)  # pennant
        box(bm, 0, 0, 56.5, 9, 9, 1.0)  # brazier table

    def fire(bm):
        loft(bm, [poly_ring(0, 0, 57.5, 3.0, 7), poly_ring(0, 0, 61, 2.2, 7), poly_ring(0, 0, 67, 0.2, 7)])

    def ice(bm):
        for i in range(10):  # ice shards leaning out from the footing
            a = i * 2 * math.pi / 10
            L = 11 + 5 * ((i * 7) % 3)
            s0 = len(bm.verts)
            loft(bm, [poly_ring(0, 0, 0, 2.2, 5, a), poly_ring(0, 0, L, 0.15, 5, a)])
            for v in list(bm.verts)[s0:]:
                v.co = Vector((v.co.x + 6.4 * math.cos(a) + 0.18 * v.co.z * math.cos(a), v.co.y + 6.4 * math.sin(a) + 0.18 * v.co.z * math.sin(a), v.co.z - 1))
        for i in range(14):  # icicles under the gallery
            a = i * 2 * math.pi / 14
            L = 3 + 5 * ((i * 5) % 3) / 2
            s0 = len(bm.verts)
            loft(bm, [poly_ring(0, 0, 0, 0.8, 4, a), poly_ring(0, 0, -L, 0.05, 4, a)])
            for v in list(bm.verts)[s0:]:
                v.co += V(8.2 * math.cos(a), 8.2 * math.sin(a), 52.2)

    build(P, "Stone", "Hero_FrostSlate", stone)
    build(P, "Timber", "Hero_DarkTimber", timber)
    build(P, "Fire", "Hero_Fire", fire)
    build(P, "Ice", "Hero_Ice", ice)


def statue():
    P = "Basin_Gate_Statue"

    def base(bm):
        box(bm, 0, 0, 0, 70, 44, 12)
        box(bm, 0, 0, 12, 60, 38, 4)
        box(bm, -27, -6, 16, 12, 14, 26, 0.05)  # broken gate pylon
        box(bm, -27, -6, 42, 10, 11, 5, 0.25)  # jagged crown stub
        box(bm, 25, 8, 16, 14, 9, 7, -0.3)
        s0 = len(bm.verts)
        box(bm, -8, -6, 40, 40, 9, 7)  # fallen lintel leaning off the pylon
        bmesh.ops.rotate(bm, verts=list(bm.verts)[s0:], cent=V(-27, -6, 47), matrix=Matrix.Rotation(0.55, 3, "Y"))
        box(bm, 17, -14, 16, 8, 7, 4.5, 0.6)
        box(bm, -10, 12, 16, 10, 8, 3, 0.2)

    def body(bm):
        for sx in (-9, 9):
            box(bm, sx, 0, 16, 13, 15, 28)  # legs
        loft(bm, [rect(0, 0, 44, 40, 26), rect(0, 0, 60, 34, 21), rect(0, 0, 72, 31, 19)])  # kilt
        loft(bm, [rect(0, 0, 72, 30, 19), rect(0, 0, 88, 28, 17), rect(0, 0, 100, 42, 19)])  # chest to shoulders
        box(bm, 0, 0, 100, 9, 9, 6)  # neck
        box(bm, -26, 0, 62, 8, 9, 38)  # left arm hanging
        box(bm, 26.5, 0, 82, 8, 9, 18)  # right arm broken at the elbow
        box(bm, 27, 0, 99, 7, 8, 1.5, 0.2)
        box(bm, -31, 4, 16, 3.4, 3.4, 78, 0.0)  # staff

    def head(bm):
        loft(bm, [rect(0, 0, 106, 12, 13), rect(0, 0, 112, 15, 15), rect(0, 0, 122, 13, 14)])
        loft(bm, [rect(0, 0, 122, 12, 12), rect(0, 0, 134, 8, 8), rect(0, 0, 139, 4.5, 4.5)])  # tall broken crown
        box(bm, 0, -7.2, 112, 4, 2.4, 6)  # brow/nose block
        c = Vector((0, 0, 106))
        bmesh.ops.rotate(bm, verts=list(bm.verts), cent=c, matrix=Matrix.Rotation(0.13, 3, "Y"))  # head leans: the statue is cracked

    build(P, "Base", "Hero_SaltStoneDark", base)
    build(P, "Body", "Hero_SaltStone", body)
    build(P, "Head", "Hero_SaltStone", head)


def tiered(P, plinth, tiers, spire, rooftop_bells=True, stair=True):
    """plinth=(w,d); tiers=[(wx, wy, wall_h, overhang, rise)]; spire=(height, base_r)."""
    z = 0.0
    zs = []

    def stone(bm):
        nonlocal z
        box(bm, 0, 0, 0, plinth[0], plinth[1], 4)
        box(bm, 0, 0, 4, plinth[0] - 8, plinth[1] - 8, 4)
        if stair:
            for k in range(4):
                box(bm, 0, -(plinth[1] - 8) / 2 - 1 - (3 - k) * 2.2, 0, 12, 2.4 + 0, 2 + k * 1.5)
        z = 8.0
        for wx, wy, wh, oh, rise in tiers:
            zs.append(z)
            box(bm, 0, 0, z, wx - 3, wy - 3, wh)
            z += wh + rise * 0.78

    def timber(bm):
        for (wx, wy, wh, oh, rise), z0 in zip(tiers, zs):
            for sx in (-1, 1):
                for sy in (-1, 1):
                    box(bm, sx * (wx / 2 - 0.9), sy * (wy / 2 - 0.9), z0, 2.2, 2.2, wh)
            box(bm, 0, 0, z0 + wh - 1.8, wx + 1.2, wy + 1.2, 1.8)

    def roofs(bm):
        for (wx, wy, wh, oh, rise), z0 in zip(tiers, zs):
            roof(bm, 0, 0, z0 + wh, wx / 2 + oh, wy / 2 + oh, rise, 3.0)

    def bronze(bm):
        top = zs[-1] + tiers[-1][2] + tiers[-1][4]
        h, r = spire
        n = 0
        cone(bm, 0, 0, top - 1, r * 1.8, r * 1.1, 3, 8)
        cone(bm, 0, 0, top + 2, r * 1.1, r * 0.55, h - 14, 8)
        for k in range(5):  # stacked rings read as a stupa spire
            cone(bm, 0, 0, top + 4 + k * ((h - 18) / 5), r * (1.7 - 0.22 * k), r * (0.9 - 0.1 * k), 1.6, 8)
        cone(bm, 0, 0, top + h - 10, r * 0.9, 0.1, 10, 8)
        if rooftop_bells:
            for (wx, wy, wh, oh, rise), z0 in zip(tiers, zs):
                for sx in (-1, 1):
                    for sy in (-1, 1):
                        cone(bm, sx * (wx / 2 + oh), sy * (wy / 2 + oh), z0 + wh - 3, 0.9, 0.1, 3.4, 6)

    build(P, "Stone", "Hero_AshStone", stone)
    build(P, "Timber", "Hero_Vermilion", timber)
    build(P, "Roof", "Hero_RoofSlate", roofs)
    build(P, "Bronze", "Hero_TempleGold", bronze)


def temple():
    tiered("Summit_Temple_Pagoda", (60, 60), [(40, 40, 18, 10, 9), (34, 34, 16, 9, 8), (28, 28, 14, 8, 7), (22, 22, 12, 7, 6), (16, 16, 10, 6, 5)], (54.5, 2.2))
    tiered("Summit_Temple_Wing", (40, 50), [(28, 38, 18, 6, 8), (20, 26, 12, 5, 6)], (10, 1.2), rooftop_bells=False)


# ------------------------------------------------------------------ export + render
def bbox(objs):
    pts = [Vector(c) for o in objs for c in o.bound_box]
    return Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))), Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))


def render_setup():
    sc = bpy.context.scene
    ids = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in ids)
    w = bpy.data.worlds.new("w")
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.68, 0.76, 0.86, 1)
    bg.inputs["Strength"].default_value = 1.1
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (0.95, 0.2, 0.7)
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.clip_start, cam.data.clip_end = 0.5, 20000
    sc.collection.objects.link(cam)
    sc.camera = cam
    gm = bpy.data.materials.new("Ground")
    try:
        gm.use_nodes = True
    except Exception:
        pass
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.22, 0.2, 0.16, 1)
    me = bpy.data.meshes.new("Ground")
    me.from_pydata([(-30000, -30000, 0), (30000, -30000, 0), (30000, 30000, 0), (-30000, 30000, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(gm)
    sc.collection.objects.link(bpy.data.objects.new("Ground", me))
    return sc, cam


def shoot(sc, cam, only, eye, target, lens, path, res=(960, 720)):
    for name, objs in PIECES.items():
        for o in objs:
            o.hide_render = name not in only
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.data.lens = lens
    cam.location = Vector(eye)
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    (OUT / "maps").mkdir(parents=True, exist_ok=True)
    CAP.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    material("Hero_Sandstone", (0.66, 0.46, 0.27), 0.85, seed=1)
    material("Hero_SandstoneDark", (0.52, 0.34, 0.20), 0.85, seed=2)
    material("Hero_Slate", (0.30, 0.31, 0.33), 0.8, seed=3)
    material("Hero_FrostSlate", (0.38, 0.41, 0.46), 0.8, seed=4)
    material("Hero_DarkTimber", (0.17, 0.12, 0.09), 0.75, seed=5)
    material("Hero_Fire", (1.0, 0.55, 0.15), 0.5, emit=(1.0, 0.5, 0.12), seed=6)
    material("Hero_Ice", (0.72, 0.86, 0.95), 0.18, seed=7)
    material("Hero_SaltStone", (0.74, 0.65, 0.50), 0.85, seed=8)
    material("Hero_SaltStoneDark", (0.62, 0.56, 0.46), 0.9, seed=9)
    material("Hero_AshStone", (0.33, 0.32, 0.33), 0.85, seed=10)
    material("Hero_Vermilion", (0.46, 0.12, 0.08), 0.7, seed=11)
    material("Hero_RoofSlate", (0.16, 0.18, 0.22), 0.6, seed=12)
    material("Hero_TempleGold", (0.78, 0.60, 0.22), 0.35, metal=1.0, seed=13)
    for fn in (aqueduct, beacon, statue, temple):
        fn()
    for name, objs in PIECES.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB", use_selection=True, export_apply=False)
        lo, hi = bbox(objs)
        info = MANIFEST["pieces"][name]
        info["file"] = f"{name}.glb"
        info["size_studs_xyz"] = [round(hi[i] - lo[i], 1) for i in range(3)]
        info["materials"] = sorted(set(info["materials"]))
        info["tris_total"] = sum(info["sub_meshes"].values())
        print(name, info["size_studs_xyz"], info["sub_meshes"])
    (OUT / "manifest.json").write_text(json.dumps(MANIFEST, indent=2) + "\n")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "hero_silhouettes.blend"))
    sc, cam = render_setup()
    eye = {  # player-height eye (5 studs), looking at the piece from a distance where its silhouette is judged
        "Ravine_Aqueduct_Arch": ((40, -170, 5), (0, 0, 38), 24),
        "Snow_Watch_Beacon": ((34, -150, 5), (0, 0, 45), 24),
        "Basin_Gate_Statue": ((60, -190, 5), (0, 0, 62), 24),
        "Summit_Temple_Pagoda": ((55, -230, 5), (0, 0, 78), 24),
        "Summit_Temple_Wing": ((35, -120, 5), (0, 0, 28), 24),
    }
    for name, (e, t, lens) in eye.items():
        shoot(sc, cam, {name}, e, t, lens, CAP / f"hero_eye_{name}.png")
    # far read: temple (pagoda + wing) from 4000 studs, 70 deg vFOV equivalent crop, bright sky = silhouette test
    for o in PIECES["Summit_Temple_Pagoda"] + PIECES["Summit_Temple_Wing"]:  # landmark placed at Scale 5 (800 studs tall), 6000 studs away
        o.scale = (5, 5, 5)
    shoot(sc, cam, {"Summit_Temple_Pagoda", "Summit_Temple_Wing"}, (0, -6000, 5), (0, 0, 380), 85, CAP / "hero_far_Summit_Temple_scale5.png", res=(1280, 540))
    for o in PIECES["Summit_Temple_Pagoda"] + PIECES["Summit_Temple_Wing"]:
        o.scale = (1, 1, 1)
    shoot(sc, cam, {"Ravine_Aqueduct_Arch"}, (0, -1500, 5), (0, 0, 40), 85, CAP / "hero_far_Ravine_Aqueduct_Arch.png", res=(1280, 540))


main()

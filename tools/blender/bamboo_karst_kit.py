"""Bamboo Pass kit: bamboo stalks and frost-capped karst spires, one GLB for the Studio 3D Importer.

Usage:
  Blender -b --python-exit-code 1 -P tools/blender/bamboo_karst_kit.py -- <out_dir>

Units are studs, every piece stands on the origin (its foot at z = 0) so RegionDecor / BambooDressing
place and scale it from the ground up. All decoration (no collision); collision stays in BambooPassLayout.
  Bamboo_A/B/C   40-stud stalk: tapered, slightly bowed culm whose node bands come from a tiling
                 texture (no extra rings), short side branches on the upper nodes and drooping
                 lanceolate leaves (real geometry, no alpha). ~350 triangles: 640 of them line the pass.
  Karst_A/B/C    100-stud limestone tower: fluted, stepped ledges, a broken crown; snow lies on the
                 crown as its own mesh (__Snow). Rock reuses the terrace cliffs' scanned
                 maps (assets/build/sanctuary_vista/VistaRock_*.png), tinted cool grey.
Writes <out_dir>/bamboo_karst_kit.glb, maps, preview.png and manifest.json (triangles per mesh).
"""
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
VISTA = ROOT / "assets/build/sanctuary_vista"
BAMBOO_H = 40.0
KARST_H = 100.0
NODES = 16  # culm node bands per stalk height (the culm texture tiles this many times)
manifest = {"units": "studs", "pivot": "foot centre at the origin", "pieces": {}}


# ------------------------------------------------------------------------------------------ helpers
def save(name, arr, non_color=False):
    n_v, n_u = arr.shape[:2]
    im = bpy.data.images.new(name, n_u, n_v, alpha=False, is_data=non_color)
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((n_v, n_u, 1))], 2)
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = str(OUT / "maps" / f"{name}.png")
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im


def load(path, non_color=False):
    im = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    return im


def material(name, color, rough, normal=None, tint=None, double=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = not double
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = color
    if tint is not None:
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs["B"].default_value = (*tint, 1)
        nt.links.new(t.outputs["Color"], mix.inputs["A"])
        nt.links.new(mix.outputs["Result"], p.inputs["Base Color"])
    else:
        nt.links.new(t.outputs["Color"], p.inputs["Base Color"])
    if rough is not None:
        r = nt.nodes.new("ShaderNodeTexImage")
        r.image = rough
        nt.links.new(r.outputs["Color"], p.inputs["Roughness"])
    if normal is not None:
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = normal
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    return m


def obj(name, bm, mat, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    me.polygons.foreach_set("use_smooth", [smooth] * len(me.polygons))
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.calc_loop_triangles()
    piece = name.split("__")[0]
    manifest["pieces"].setdefault(piece, {})[name] = len(me.loop_triangles)
    return o


def field(n, beta, seed, stretch=1.0):
    fu, fv = np.meshgrid(np.fft.fftfreq(n) * n, np.fft.fftfreq(n) * n)
    spec = np.fft.fft2(np.random.default_rng(seed).standard_normal((n, n)))
    out = np.real(np.fft.ifft2(spec / (np.sqrt(fu ** 2 + (fv * stretch) ** 2) + 1.0) ** beta))
    return (out - out.mean()) / out.std()


def normal_map(height, strength):
    dx = np.roll(height, -1, 1) - np.roll(height, 1, 1)
    dy = np.roll(height, -1, 0) - np.roll(height, 1, 0)
    nm = np.dstack([-dx * strength, -dy * strength, np.ones_like(dx)])
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    return nm * 0.5 + 0.5


# ------------------------------------------------------------------------------------------ textures
def culm_maps():
    """One node interval of culm, tiling vertically: green with fine vertical fibres, a pale waxy
    band just under the node and the dark raised node ring itself."""
    n = 512
    v, u = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n), indexing="ij")
    fibre = field(n, 0.8, 41, stretch=12.0)
    mottle = field(n, 1.6, 42)
    green = np.array([0.36, 0.47, 0.22]) * (0.92 + 0.05 * fibre[..., None] + 0.06 * mottle[..., None])
    node = np.exp(-((v - 0.03) / 0.018) ** 2) + np.exp(-((v - 1.03) / 0.018) ** 2)
    wax = np.clip(1 - np.abs(v - 0.09) / 0.06, 0, 1) * 0.5
    col = green * (1 - 0.45 * node[..., None]) + np.array([0.72, 0.74, 0.58]) * 0.25 * wax[..., None]
    col = col * (1 - 0.2 * node[..., None]) + np.array([0.3, 0.28, 0.16]) * 0.2 * node[..., None]
    height = 0.5 + 0.35 * node + 0.02 * fibre
    rough = np.clip(0.48 + 0.2 * node - 0.15 * wax + 0.03 * fibre, 0, 1)
    return (save("Bamboo_Culm_Color", col), save("Bamboo_Culm_Normal", normal_map(height, 4.0), True),
            save("Bamboo_Culm_Roughness", np.repeat(rough[..., None], 3, 2), True))


def leaf_maps():
    """2x2 atlas of bamboo leaf blades: fresh green, deep green, yellowing, and a dry frost-bitten one."""
    n, tile = 1024, 512
    tones = [np.array([0.30, 0.48, 0.16]), np.array([0.20, 0.36, 0.13]), np.array([0.52, 0.55, 0.20]),
             np.array([0.62, 0.55, 0.36])]
    v, u = np.meshgrid(np.linspace(0, 1, tile), np.linspace(-0.5, 0.5, tile), indexing="ij")
    grain = field(tile, 1.0, 51, stretch=6.0)
    col = np.zeros((n, n, 3))
    height = np.zeros((n, n))
    for t, tone in enumerate(tones):
        mid = np.exp(-(u / 0.02) ** 2)
        veins = (np.abs(np.sin(u * math.pi * 9)) < 0.08) * 0.4
        shade = (0.82 + 0.25 * v) * (0.95 + 0.05 * grain)
        c = tone * shade[..., None] * (1 - 0.25 * mid[..., None] - 0.1 * veins[..., None])
        y0, x0 = (t // 2) * tile, (t % 2) * tile
        col[y0:y0 + tile, x0:x0 + tile] = c
        height[y0:y0 + tile, x0:x0 + tile] = 0.5 - 0.2 * mid - 0.05 * veins + 0.02 * grain
    return save("Bamboo_Leaf_Color", col), save("Bamboo_Leaf_Normal", normal_map(height, 2.5), True)


# ------------------------------------------------------------------------------------------ bamboo
def bamboo(tag, seed):
    rng = random.Random(seed)
    bow = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * rng.uniform(0.8, 1.8)

    def axis(t):  # the culm's centre line, bowing gently
        return Vector((0, 0, BAMBOO_H * t)) + bow * (t * t)

    culm = bmesh.new()
    uv = culm.loops.layers.uv.new("UVMap")
    sides, rings = 7, 13
    prev = None
    for j in range(rings + 1):
        t = j / rings
        c = axis(t)
        r = 0.46 * (1 - 0.45 * t) + 0.05
        ring = [culm.verts.new(c + Vector((math.cos(a) * r, math.sin(a) * r, 0)))
                for a in (2 * math.pi * k / sides for k in range(sides))]
        if prev:
            for k in range(sides):
                k2 = (k + 1) % sides
                f = culm.faces.new((prev[k], prev[k2], ring[k2], ring[k]))
                for loop, uu, vv in zip(f.loops, (k / sides, (k + 1) / sides, (k + 1) / sides, k / sides),
                                        ((j - 1) / rings, (j - 1) / rings, j / rings, j / rings)):
                    loop[uv].uv = (uu, vv * NODES)
        prev = ring
    culm.faces.new(prev)
    culm_o = obj(f"Bamboo_{tag}__Culm", culm, CULM)

    leaves = bmesh.new()
    luv = leaves.loops.layers.uv.new("UVMap")
    twigs = bmesh.new()
    tuv = twigs.loops.layers.uv.new("UVMap")
    # Branches from the upper nodes, alternating sides; each ends in a drooping spray.
    nodes = [k / NODES for k in range(int(NODES * 0.38), NODES)] + [1.0, 1.0, 1.0]  # tip: crown sprays
    for i, t in enumerate(nodes):
        if rng.random() < 0.1:
            continue
        a = i * 2.4 + rng.uniform(-0.4, 0.4)
        out = Vector((math.cos(a), math.sin(a), 0))
        start = axis(t)
        length = rng.uniform(2.2, 4.2) * (1.15 - 0.5 * t)
        tip = start + out * length + Vector((0, 0, length * rng.uniform(0.25, 0.6)))
        # three-sided twig
        r0 = 0.07
        side = out.cross(Vector((0, 0, 1))).normalized()
        base = [twigs.verts.new(start + (side * math.cos(b) + Vector((0, 0, 1)) * math.sin(b)) * r0) for b in (0, 2.1, 4.2)]
        end = twigs.verts.new(tip)
        for k in range(3):
            f = twigs.faces.new((base[k], base[(k + 1) % 3], end))
            for loop in f.loops:
                loop[tuv].uv = (0.5, 0.5 / NODES)
        for _ in range(rng.randint(9, 14)):
            stem = start.lerp(tip, rng.uniform(0.45, 1.0))
            heading = (out * rng.uniform(0.3, 1.0) + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), -rng.uniform(0.3, 0.9)))).normalized()
            L, W = rng.uniform(1.6, 2.5), rng.uniform(0.26, 0.36)
            across = heading.cross(Vector((0, 0, 1)))
            if across.length < 1e-3:
                across = Vector((1, 0, 0))
            across.normalize()
            up = across.cross(heading).normalized()
            tile = rng.choices((0, 1, 2, 3), weights=(5, 4, 2, 1))[0]
            tu, tv = (tile % 2) * 0.5, (tile // 2) * 0.5
            pts = [(0.0, 0.0), (-0.5, 0.28), (0.0, 1.0), (0.5, 0.28)]
            vs = []
            for s, l in pts:
                droop = -0.18 * l * l * L
                vs.append(leaves.verts.new(stem + heading * (l * L) + across * (s * W) + up * droop))
            f = leaves.faces.new(vs)
            for loop, (s, l) in zip(f.loops, pts):
                loop[luv].uv = (tu + 0.02 + (s + 0.5) * 0.46, tv + 0.02 + l * 0.46)
    leaf_o = obj(f"Bamboo_{tag}__Leaves", leaves, LEAF, smooth=False)
    twig_o = obj(f"Bamboo_{tag}__Twigs", twigs, CULM, smooth=False)
    return [culm_o, leaf_o, twig_o]


# ------------------------------------------------------------------------------------------ karst
def karst(tag, seed, girth):
    """Limestone tower: steep fluted walls, a lumpy drifting cross-section and partial, tilted
    shelves (each covers only part of the circumference, so the tower steps unevenly), deep
    vertical solution grooves and a broken crown under a frost cap (__Snow)."""
    rng = random.Random(seed)
    base_r = KARST_H * girth * 0.5
    sides, rings = 36, 56
    grooves = [rng.uniform(0, 2 * math.pi) for _ in range(10)]
    # Shelves: height, angular centre, angular half-width, inward step, tilt.
    shelves = [(rng.uniform(0.18, 0.88), rng.uniform(0, 2 * math.pi), rng.uniform(0.9, 2.4),
                rng.uniform(0.12, 0.24), rng.uniform(-0.03, 0.03)) for _ in range(6)]
    lumps = [(rng.randint(2, 4), rng.uniform(0, 6.28), rng.uniform(0.08, 0.16)) for _ in range(3)]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    drift, heading = Vector((0, 0, 0)), rng.uniform(0, 6.28)
    rows = []
    for j in range(rings + 1):
        t = j / rings
        heading += rng.uniform(-0.4, 0.4)
        if j:
            drift += Vector((math.cos(heading), math.sin(heading), 0)) * base_r * 0.012
        r = base_r * (1.0 - 0.42 * t ** 1.4)
        if t > 0.93:
            r *= max(0.25, 1 - (t - 0.93) / 0.07 * 0.75)
        row = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            dirv = Vector((math.cos(a), math.sin(a), 0))
            rr = r
            for lt, centre, half, step, tilt in shelves:
                d = abs(math.atan2(math.sin(a - centre), math.cos(a - centre)))
                cover = max(0.0, 1 - d / half) ** 0.5
                h = lt + tilt * math.cos(a - centre)
                rr *= 1 - step * cover / (1 + math.exp(-(t - h) * 140))
            for n, ph, amp in lumps:
                rr *= 1 + amp * math.sin(a * n + ph + t * 2.0)
            groove = sum(math.exp(-(math.atan2(math.sin(a - g), math.cos(a - g)) / 0.08) ** 2) for g in grooves)
            rr *= 1 - 0.14 * groove + noise.noise(Vector((dirv.x * 1.8 + seed, dirv.y * 1.8, t * 5))) * 0.1
            zz = KARST_H * t
            if t > 0.93:
                zz += noise.noise(Vector((dirv.x * 2.5, dirv.y * 2.5, seed))) * 6 + 4 * math.sin(a * 3 + seed)
            row.append(bm.verts.new(drift + dirv * rr + Vector((0, 0, zz))))
        rows.append(row)
    for j in range(rings):
        for k in range(sides):
            k2 = (k + 1) % sides
            f = bm.faces.new((rows[j][k], rows[j][k2], rows[j + 1][k2], rows[j + 1][k]))
            for loop, kk, jj in zip(f.loops, (k, k + 1, k + 1, k), (j, j, j + 1, j + 1)):
                loop[uv].uv = (kk / sides * 4, jj / rings * 10)
    top = bm.verts.new(drift + Vector((0, 0, KARST_H * 0.975)))
    for k in range(sides):
        f = bm.faces.new((rows[-1][k], rows[-1][(k + 1) % sides], top))
        for loop in f.loops:
            loop[uv].uv = (0.5, 10)
    bm.faces.new(list(reversed(rows[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    rock = obj(f"Karst_{tag}__Rock", bm, ROCK)
    sb = bmesh.new()
    me = rock.data
    vmap = {}
    for poly in me.polygons:
        if poly.normal.z > 0.2 and poly.center.z > KARST_H * 0.86:  # a frost cap on the crown only
            vs = []
            for vi in poly.vertices:
                if vi not in vmap:
                    v = me.vertices[vi]
                    vmap[vi] = sb.verts.new(v.co + v.normal * 0.35 + Vector((0, 0, 0.25)))
                vs.append(vmap[vi])
            try:
                sb.faces.new(vs)
            except ValueError:
                pass
    bmesh.ops.solidify(sb, geom=sb.faces[:], thickness=0.6)
    snow = obj(f"Karst_{tag}__Snow", sb, SNOW)
    return [rock, snow]


def main():
    global CULM, LEAF, ROCK, SNOW
    (OUT / "maps").mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    c = culm_maps()
    lf = leaf_maps()
    CULM = material("Bamboo_Culm", c[0], c[2], c[1])
    LEAF = material("Bamboo_Leaf", lf[0], None, lf[1], double=True)
    LEAF.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.55
    ROCK = material("Karst_Rock", load(VISTA / "VistaRock_Color.png"), load(VISTA / "VistaRock_Roughness.png", True),
                    load(VISTA / "VistaRock_Normal.png", True), tint=(0.62, 0.66, 0.72))
    SNOW = bpy.data.materials.new("Karst_Snow")
    SNOW.use_nodes = True
    sp = SNOW.node_tree.nodes["Principled BSDF"]
    sp.inputs["Base Color"].default_value = (0.86, 0.9, 0.95, 1)
    sp.inputs["Roughness"].default_value = 0.8
    pieces = []
    for tag, seed in (("A", 11), ("B", 23), ("C", 37)):
        pieces += bamboo(tag, seed)
    for tag, seed, girth in (("A", 5, 0.26), ("B", 9, 0.31), ("C", 13, 0.22)):
        pieces += karst(tag, seed, girth)
    bpy.ops.object.select_all(action="SELECT")
    glb = OUT / "bamboo_karst_kit.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))

    # Preview: three stalks and three spires in a row.
    for o in bpy.data.objects:
        if o.name.startswith("Bamboo_"):
            o.location.x = {"A": -10, "B": 0, "C": 10}[o.name[7]]
            o.location.y = -60
        elif o.name.startswith("Karst_"):
            o.location.x = {"A": -45, "B": 0, "C": 45}[o.name[6]]
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in engines)
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.48, 0.55, 1)
    sc.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.85, 0.2, 0.6)
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 30
    cam.location = Vector((0, -150, 38))
    cam.rotation_euler = (Vector((0, 0, 40)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(OUT / "preview.png")
    bpy.ops.render.render(write_still=True)
    cam.location = Vector((8, -82, 30))
    cam.rotation_euler = (Vector((0, -60, 30)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(OUT / "preview_bamboo.png")
    bpy.ops.render.render(write_still=True)
    print("KIT_OK", glb, json.dumps(manifest["pieces"]), flush=True)


main()

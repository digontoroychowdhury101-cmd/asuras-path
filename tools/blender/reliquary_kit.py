"""Cloud Reliquary kit and the mirrored guardian lion, one GLB for the Studio 3D Importer (headless Blender).

Usage:
  Blender -b --python-exit-code 1 -P tools/blender/reliquary_kit.py -- <out_dir> [--lion assets/build/guardian_lion/AsuraGuardianLionMirror.glb]

Units are studs. Every piece is authored about the scene origin with its walkable top at z = 0 (Roblox
Y = 0), so SanctuaryKit places it with the route box's top as the pivot; the route boxes in
SanctuaryRoutes stay the collision and walk surface, these meshes are decoration (no collision).
  Reliquary_Shard  carved 4.4 x 6.4 stepping stone on an inverted floating-karst root, hanging roots
                   and a few crimson leaves (route box 4 x 6).
  Reliquary_Isle   12.4 x 16.4 dais with a carved border and an inlaid ring round the cache, a stone
                   hokora (shrine) on its east end, on a deeper karst mass with hanging roots.
Rock reuses the terrace cliffs' scanned maps (assets/build/sanctuary_vista/VistaRock_*.png); dressed
stone gets a generated 1K granite set. Writes <out_dir>/sanctuary_fixes.glb, maps, preview and manifest.
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
ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = Path(ARGS[0]).resolve()
LION = Path(ARGS[ARGS.index("--lion") + 1]).resolve() if "--lion" in ARGS else None
VISTA = ROOT / "assets/build/sanctuary_vista"
rng = random.Random(1987)
manifest = {"units": "studs", "pivot": "walkable top centre at the origin", "pieces": {}}


def image(path, non_color=False):
    im = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    return im


def material(name, color, rough, normal=None, tint=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
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


def flat(name, rgb, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = rough
    m.use_backface_culling = False
    return m


def granite():
    """Tileable 1K pale granite for the dressed stone: speckle, soft veining, chisel bumps."""
    n = 1024
    fu, fv = np.meshgrid(np.fft.fftfreq(n) * n, np.fft.fftfreq(n) * n)

    def field(beta, seed):
        spec = np.fft.fft2(np.random.default_rng(seed).standard_normal((n, n)))
        out = np.real(np.fft.ifft2(spec / (np.sqrt(fu ** 2 + fv ** 2) + 1.0) ** beta))
        return (out - out.mean()) / out.std()

    broad, fine, vein = field(1.6, 3), field(0.4, 4), 1 - np.abs(field(1.2, 5))
    speck = (fine > 1.6).astype(float)
    shade = 0.6 + 0.05 * broad - 0.12 * speck + 0.04 * np.clip((vein - 0.9) / 0.1, 0, 1)
    col = np.stack([shade * 1.0, shade * 1.01, shade * 1.03], 2)
    height = 0.5 + 0.06 * broad + 0.02 * fine
    dx = np.roll(height, -1, 1) - np.roll(height, 1, 1)
    dy = np.roll(height, -1, 0) - np.roll(height, 1, 0)
    nm = np.dstack([-dx * 4, -dy * 4, np.ones_like(dx)])
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    rough = np.clip(0.78 + 0.08 * fine, 0, 1)
    out = []
    for name, arr, nc in (("Reliquary_Stone_Color", col, False), ("Reliquary_Stone_Normal", nm * 0.5 + 0.5, True),
                          ("Reliquary_Stone_Roughness", np.repeat(rough[..., None], 3, 2), True)):
        im = bpy.data.images.new(name, n, n, alpha=False, is_data=nc)
        im.pixels.foreach_set(np.concatenate([np.clip(arr, 0, 1), np.ones((n, n, 1))], 2).astype(np.float32).ravel())
        im.filepath_raw = str(OUT / "maps" / f"{name}.png")
        im.file_format = "PNG"
        im.save()
        im.pack()
        out.append(im)
    return out


def obj(name, bm, mat, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    me.polygons.foreach_set("use_smooth", [smooth] * len(me.polygons))
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def box_uv(o, size):
    """Cube projection in world units: textures keep one scale across pieces."""
    me = o.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        nrm = poly.normal
        axis = max(range(3), key=lambda i: abs(nrm[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (co[a] / size, co[b] / size)


def karst(name, w, d, depth, mat, seed):
    """Inverted floating-karst root: a broad, broken lip under the slab narrowing to fractured tips."""
    bm = bmesh.new()
    sides, rings = 28, 14
    prev = None
    rows = []
    for j in range(rings + 1):
        t = j / rings
        z = -0.5 - depth * t ** 1.15
        shrink = (1 - t) ** 0.85 * 0.92 + 0.08
        row = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            dirx, diry = math.cos(a), math.sin(a)
            # superellipse fits the rectangular slab; noise breaks it into ledges and clefts
            sx = math.copysign(abs(dirx) ** 0.6, dirx) * w * 0.5
            sy = math.copysign(abs(diry) ** 0.6, diry) * d * 0.5
            p = Vector((sx, sy, 0))
            n3 = noise.noise(Vector((dirx * 1.7 + seed, diry * 1.7, t * 3.1))) * 0.28 + \
                noise.noise(Vector((dirx * 5 + seed, diry * 5, t * 9))) * 0.08
            ledge = 0.12 * math.floor(t * 5) / 5
            scale = max(0.04, shrink * (1 + n3) - ledge * (1 - t))
            row.append(bm.verts.new((p.x * scale + noise.noise(Vector((seed, t * 4, 0))) * 0.3 * t,
                                     p.y * scale, z + noise.noise(Vector((dirx * 3, diry * 3, seed))) * 0.5 * t)))
        rows.append(row)
    for j in range(rings):
        for i in range(sides):
            i2 = (i + 1) % sides
            bm.faces.new((rows[j][i], rows[j][i2], rows[j + 1][i2], rows[j + 1][i]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[-1])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=0.6)
    for v in bm.verts:  # fine fracture detail after the subdivision
        v.co += v.normal * noise.noise(v.co * 0.9 + Vector((seed, 0, 0))) * 0.18 if v.co.z < -0.8 else Vector()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    o = obj(name, bm, mat)
    box_uv(o, 6.0)
    return o


def slab(name, w, d, h, mat, bevel=0.18):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(w, d, h), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, -h / 2), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, affect="EDGES", profile=0.6)
    o = obj(name, bm, mat, smooth=False)
    box_uv(o, 4.0)
    return o


def merge(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = o.data.name = name
    return o


def roots(name, anchor_pts, mat):
    """Thin hanging roots under the karst: tapered tubes swaying down."""
    bm = bmesh.new()
    for p0 in anchor_pts:
        length = rng.uniform(2.5, 6.0)
        r0 = rng.uniform(0.12, 0.22)
        prev = None
        sides = 6
        for k in range(9):
            t = k / 8
            c = p0 + Vector((math.sin(t * 3 + p0.x) * 0.35 * t, math.cos(t * 2.4 + p0.y) * 0.3 * t, -length * t))
            r = r0 * (1 - t * 0.85)
            ring = [bm.verts.new(c + Vector((math.cos(a) * r, math.sin(a) * r, 0))) for a in (2 * math.pi * i / sides for i in range(sides))]
            if prev:
                for i in range(sides):
                    bm.faces.new((prev[i], prev[(i + 1) % sides], ring[(i + 1) % sides], ring[i]))
            else:
                bm.faces.new(list(reversed(ring)))
            prev = ring
        bm.faces.new(prev)
    o = obj(name, bm, mat)
    box_uv(o, 3.0)
    return o


def leaves(name, w, d, count, mat):
    bm = bmesh.new()
    for _ in range(count):
        c = Vector((rng.uniform(-w / 2, w / 2), rng.uniform(-d / 2, d / 2), 0.03))
        a = rng.uniform(0, math.tau)
        ax, side = Vector((math.cos(a), math.sin(a), 0)), Vector((-math.sin(a), math.cos(a), 0))
        L = rng.uniform(0.45, 0.7)
        pts = [c, c + ax * L * 0.4 + side * L * 0.22, c + ax * L, c + ax * L * 0.4 - side * L * 0.22]
        vs = [bm.verts.new(p + Vector((0, 0, 0.02 * i % 2))) for i, p in enumerate(pts)]
        bm.faces.new(vs)
    return obj(name, bm, mat, smooth=False)


def hokora(stone):
    """Small stone shrine: plinth, body with a dark niche, gabled roof with swept eaves, ridge."""
    parts = [slab("h_plinth", 2.8, 3.6, 0.6, stone, 0.08)]
    body = slab("h_body", 2.0, 2.8, 2.4, stone, 0.06)
    body.location.z = 0.6 + 2.4
    parts.append(body)
    roof = bmesh.new()
    w, d, rise, over = 3.0, 4.0, 1.25, 0.0
    v = [roof.verts.new(p) for p in [(-w / 2, -d / 2, 0), (w / 2, -d / 2, 0), (w / 2, d / 2, 0), (-w / 2, d / 2, 0),
                                       (0, -d / 2 - 0.15, rise), (0, d / 2 + 0.15, rise)]]
    for f in [(0, 1, 4), (2, 3, 5), (0, 4, 5, 3), (1, 2, 5, 4), (0, 3, 2, 1)]:
        roof.faces.new([v[i] for i in f])
    for vert in v[:4]:  # swept eaves
        vert.co.x *= 1.08
        vert.co.z += 0.12
    bmesh.ops.solidify(roof, geom=roof.faces[:], thickness=0.18)
    r = obj("h_roof", roof, stone, smooth=False)
    box_uv(r, 4.0)
    r.location.z = 3.0
    parts.append(r)
    ridge = slab("h_ridge", 0.3, 4.5, 0.3, stone, 0.05)
    ridge.location.z = 3.0 + 1.25 + 0.32
    parts.append(ridge)
    step = slab("h_step", 0.9, 2.2, 0.3, stone, 0.05)
    step.location = (-1.85, 0, 0.3)
    parts.append(step)
    for o in parts:
        o.data.transform(o.matrix_basis)
        o.matrix_basis = Matrix.Identity(4)
    return merge("h", parts)


def shimenawa(crimson, gold):
    """Crimson rope band across the shrine front with two hanging paper tassels, and a gilt finial."""
    bm = bmesh.new()
    seg, sides = 20, 6
    rows = []
    for i in range(seg + 1):
        t = i / seg
        c = Vector((-1.12, -1.45 + 2.9 * t, 3.05 - 0.25 * math.sin(math.pi * t)))
        rows.append([bm.verts.new(c + Vector((math.cos(a) * 0.09, 0, math.sin(a) * 0.09)))
                     for a in (2 * math.pi * k / sides for k in range(sides))])
    for i in range(seg):
        for k in range(sides):
            bm.faces.new((rows[i][k], rows[i][(k + 1) % sides], rows[i + 1][(k + 1) % sides], rows[i + 1][k]))
    rope = obj("Reliquary_Isle__Rope", bm, crimson)
    bm = bmesh.new()
    for y in (-0.7, 0.7):
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((-1.14, y, 2.62)) @ Matrix.Diagonal((0.03, 0.18, 0.55, 1)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.16, radius2=0.0, depth=0.5,
                          matrix=Matrix.Translation((0, 0, 4.85)))
    ornament = obj("Reliquary_Isle__Gilt2", bm, gold, smooth=False)
    return rope, ornament


def niche(dark):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(0.06, 1.3, 1.5), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(-1.02, 0, 1.75), verts=bm.verts)
    return obj("h_niche", bm, dark, smooth=False)


def ring_inlay(name, radius, mat):
    bm = bmesh.new()
    seg = 48
    inner = [bm.verts.new((math.cos(a) * radius, math.sin(a) * radius, 0.04)) for a in (2 * math.pi * i / seg for i in range(seg))]
    outer = [bm.verts.new((math.cos(a) * (radius + 0.35), math.sin(a) * (radius + 0.35), 0.04)) for a in (2 * math.pi * i / seg for i in range(seg))]
    for i in range(seg):
        bm.faces.new((inner[i], outer[i], outer[(i + 1) % seg], inner[(i + 1) % seg]))
    return obj(name, bm, mat, smooth=False)


def finish(o, piece):
    me = o.data
    me.calc_loop_triangles()
    manifest["pieces"].setdefault(piece, {})[o.name] = len(me.loop_triangles)


def main():
    (OUT / "maps").mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rock = material("Reliquary_Rock", image(VISTA / "VistaRock_Color.png"), image(VISTA / "VistaRock_Roughness.png", True),
                    image(VISTA / "VistaRock_Normal.png", True))
    g = granite()
    stone = material("Reliquary_Stone", g[0], g[2], g[1])
    root_mat = material("Reliquary_Root", image(VISTA / "VistaRock_Color.png"), image(VISTA / "VistaRock_Roughness.png", True),
                        tint=(0.55, 0.45, 0.4))
    crimson = flat("Reliquary_Leaf", (0.5, 0.02, 0.045), 0.5)
    shadow = flat("Reliquary_Niche", (0.04, 0.035, 0.035), 0.95)
    gold = flat("Reliquary_Gilt", (0.75, 0.55, 0.22), 0.35)

    # Stepping shard: route box 4 x 6 (Roblox X x Z) -> Blender x 4, y 6.
    top = slab("Reliquary_Shard__Stone", 4.4, 6.4, 0.9, stone)
    k = karst("Reliquary_Shard__Rock", 4.6, 6.6, 7.5, rock, 3.0)
    hang = roots("Reliquary_Shard__Roots", [Vector((rng.uniform(-1.3, 1.3), rng.uniform(-2.2, 2.2), -2.5)) for _ in range(5)], root_mat)
    lv = leaves("Reliquary_Shard__Leaves", 4.0, 6.0, 9, crimson)
    for o in (top, k, hang, lv):
        finish(o, "Reliquary_Shard")

    # Reliquary isle: route box 12 x 16 at the cache; the hokora stands on its east (+X) end.
    dais = slab("Reliquary_Isle__Stone", 12.4, 16.4, 1.2, stone, 0.25)
    border = slab("b", 12.9, 16.9, 0.5, stone, 0.12)
    border.data.transform(Matrix.Translation((0, 0, -1.0)))
    shrine = hokora(stone)
    shrine.data.transform(Matrix.Translation((4.4, 0, 0)))
    dais = merge("Reliquary_Isle__Stone", [dais, border, shrine])
    box_uv(dais, 4.0)
    nic = niche(shadow)
    nic.data.transform(Matrix.Translation((4.4, 0, 0.6)))
    nic.name = nic.data.name = "Reliquary_Isle__Niche"
    inlay = ring_inlay("Reliquary_Isle__Gilt", 2.0, gold)
    rope, finial = shimenawa(crimson, gold)
    for o in (rope, finial):
        o.data.transform(Matrix.Translation((4.4, 0, 0)))
    inlay = merge("Reliquary_Isle__Gilt", [inlay, finial])
    finish(rope, "Reliquary_Isle")
    k2 = karst("Reliquary_Isle__Rock", 13.4, 17.4, 17.0, rock, 7.0)
    hang2 = roots("Reliquary_Isle__Roots", [Vector((rng.uniform(-4, 4), rng.uniform(-6, 6), -3.5)) for _ in range(10)], root_mat)
    lv2 = leaves("Reliquary_Isle__Leaves", 11.5, 15.5, 26, crimson)
    for o in (dais, nic, inlay, k2, hang2, lv2):
        finish(o, "Reliquary_Isle")

    if LION:
        bpy.ops.import_scene.gltf(filepath=str(LION))
        for o in [o for o in bpy.data.objects if o.type != "MESH"]:
            bpy.data.objects.remove(o)
        lion = next(o for o in bpy.data.objects if o.name.startswith("AsuraGuardianLionMirror"))
        lion.name = "AsuraGuardianLionMirror"
        finish(lion, "AsuraGuardianLionMirror")

    bpy.ops.object.select_all(action="SELECT")
    glb = OUT / "sanctuary_fixes.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))

    # Preview: shard and isle side by side (the lion is hidden).
    sc = bpy.context.scene
    sc.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT")
                            if e in {i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items})
    sc.render.resolution_x, sc.render.resolution_y = 1200, 800
    for o in bpy.data.objects:
        if o.name.startswith("Reliquary_Shard"):
            o.location.x = -12
        if o.name.startswith("AsuraGuardianLion"):
            o.hide_render = True
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.42, 0.42, 1)
    sc.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.9, 0.2, 0.7)
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = Vector((-6, -30, 8))
    cam.rotation_euler = (Vector((-4, 0, -5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(OUT / "preview.png")
    bpy.ops.render.render(write_still=True)
    cam.location = Vector((-14, -12, 7))
    cam.rotation_euler = (Vector((3, 0, 1.8)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(OUT / "preview_shrine.png")
    bpy.ops.render.render(write_still=True)
    print("KIT_OK", glb, json.dumps(manifest["pieces"]), flush=True)


main()

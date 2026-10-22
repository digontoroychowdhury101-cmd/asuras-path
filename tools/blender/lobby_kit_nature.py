"""Second lobby kit batch: sea-of-cloud puffs, crimson maples and shrubs, and a cloth banner.

Built by lobby_kit.py --batch nature into AsuraLobbyNature.glb with its own texture sets (Cloud,
Foliage, Bark, Banner), so the first batch's uploaded maps are never duplicated. Organic masses are
Blender metaballs converted to meshes, lumped with noise, given flat cloud bases where needed, then
decimated to budget; UVs are spherical (canopies) or height-based (clouds: the colour map grades from
lavender undersides to warm tops along v). Origins: base centre on the ground; cloud base centre.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

from lobby_kit_geo import Mesh
from lobby_kit_pieces import Piece

UP = Vector((0, 0, 1))


def _blob_mesh(balls, resolution=0.6, seed=1, lump=0.12, flat=None, target=None):
    """Metaball union -> bmesh with noisy lumps; `balls` are (centre, radius, (sx, sy, sz))."""
    mb = bpy.data.metaballs.new("blob")
    mb.resolution = resolution
    mb.render_resolution = resolution
    for centre, radius, scale in balls:
        e = mb.elements.new(type="ELLIPSOID")
        e.co, e.radius = centre, radius
        e.size_x, e.size_y, e.size_z = scale  # relative to the radius
    ob = bpy.data.objects.new("blob", mb)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(ob)
    bpy.data.metaballs.remove(mb)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    rng = np.random.default_rng(seed)
    dirs = rng.normal(size=(9, 3))
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    freqs, phases = rng.uniform(0.35, 1.1, 9), rng.uniform(0, 2 * math.pi, 9)
    centre = sum((Vector(c) for c, _, _ in balls), Vector()) / len(balls)
    for v in bm.verts:
        p = np.array(v.co)
        bump = sum(math.sin(f * float(p @ d) + ph) for d, f, ph in zip(dirs, freqs, phases)) / 9
        outward = (v.co - centre).normalized()
        v.co += outward * lump * bump * max((v.co - centre).length, 1) * 0.35
        if flat is not None and v.co.z < flat:
            v.co.z = flat + (v.co.z - flat) * 0.08
    if target:
        faces = len(bm.faces)
        if faces > target:
            bmesh.ops.triangulate(bm, faces=list(bm.faces))
            ratio = target / max(len(bm.faces), 1)
            tmp = bpy.data.meshes.new("tmp")
            bm.to_mesh(tmp)
            obj = bpy.data.objects.new("tmp", tmp)
            bpy.context.scene.collection.objects.link(obj)
            mod = obj.modifiers.new("dec", "DECIMATE")
            mod.ratio = ratio
            bpy.context.view_layer.update()
            done = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
            bpy.data.objects.remove(obj)
            bpy.data.meshes.remove(tmp)
            bm.free()
            bm = bmesh.new()
            bm.from_mesh(done)
            bpy.data.meshes.remove(done)
    return bm


def _adopt(mesh: Mesh, bm, uv):
    """Copies a bmesh into a kit Mesh with authored UVs from uv(co) -> (u, v)."""
    remap = {v: mesh.bm.verts.new(v.co) for v in bm.verts}
    for f in bm.faces:
        g = mesh._face([remap[v] for v in f.verts], [uv(v.co) for v in f.verts])
        if g is not None:
            g[mesh.open] = 0
    bm.free()


def _spherical(centre, scale):
    def uv(co):
        d = co - centre
        return (math.atan2(d.y, d.x) / (2 * math.pi) * scale, d.z / 10 * scale * 0.5 + 0.5)
    return uv


def cloud(seed, size, piece):
    rng = np.random.default_rng(seed)
    balls = [((0, 0, size * 0.16), size * 0.36, (1.6, 1.1, 0.6))]
    for _ in range(15):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.15, 0.85) * size
        z = rng.uniform(0.08, 0.5) * size * (1.1 - r / size)
        balls.append(((math.cos(a) * r, math.sin(a) * r * 0.55, z), rng.uniform(0.16, 0.3) * size, (1.1, 1.0, 0.95)))
    bm = _blob_mesh(balls, resolution=size * 0.04, seed=seed, lump=0.3, flat=0.0, target=2000)
    top = max(v.co.z for v in bm.verts)
    m = piece.m("Cloud")
    _adopt(m, bm, lambda co: (0.5 + co.x / (size * 4), max(0.0, min(1.0, co.z / max(top, 1e-3)))))


def cloud_a(pc):
    cloud(3, 30, pc)


def cloud_b(pc):
    cloud(7, 22, pc)


def cloud_c(pc):
    cloud(11, 40, pc)


def _trunk(m: Mesh, path, r0, r1):
    ring = [(math.cos(2 * math.pi * k / 8), math.sin(2 * math.pi * k / 8)) for k in range(8)]
    n = len(path)
    m.sweep([(x, y) for x, y in ring], path, scales=[r0 + (r1 - r0) * (i / (n - 1)) for i in range(n)])


def maple(pc, seed=5, height=15.0):
    rng = np.random.default_rng(seed)
    bark = pc.m("Bark")
    lean = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * 1.6
    path = [Vector((0, 0, -0.6))] + [Vector((lean.x * (t ** 1.4) + 0.5 * math.sin(t * 5), lean.y * (t ** 1.4), t * height * 0.62)) for t in np.linspace(0.1, 1, 8)]
    _trunk(bark, path, 1.6, 0.7)
    bark.lathe([(2.6, -0.5), (2.0, 0.3), (1.6, 1.0)], 8)  # root flare
    tips = []
    for k in range(6):
        a = k * 2 * math.pi / 6 + rng.uniform(-0.3, 0.3)
        start = path[4 + k % 4]
        out = Vector((math.cos(a), math.sin(a), 0.0))
        end = start + out * rng.uniform(4.5, 6.5) + UP * rng.uniform(2.0, 4.0)
        mid = start.lerp(end, 0.5) + UP * 0.8
        _trunk(bark, [start, mid, end], 0.55, 0.2)
        tips.append(end)
    top = path[-1]
    tips += [top + UP * 2.2, top + Vector((1.5, -1, 1.2)), top + Vector((-1.5, 1.2, 0.8))]
    balls = [((t.x, t.y, t.z + 0.4), rng.uniform(3.0, 4.0), (1.15, 1.15, 1.0)) for t in tips]
    balls.append(((top.x, top.y, top.z - 0.5), 5.5, (1.5, 1.5, 0.9)))
    for k in range(5):  # drooping lower clumps under the crown
        a = rng.uniform(0, 2 * math.pi)
        p = top + Vector((math.cos(a) * 5.5, math.sin(a) * 5.5, -2.4))
        balls.append(((p.x, p.y, p.z), rng.uniform(2.0, 2.8), (1.1, 1.1, 0.9)))
    bm = _blob_mesh(balls, resolution=0.8, seed=seed + 3, lump=0.3, target=3600)
    centre = Vector((path[-1].x, path[-1].y, path[-1].z))
    _adopt(pc.m("Foliage"), bm, _spherical(centre, 3.0))


def maple_b(pc):
    maple(pc, seed=13, height=12.0)


def shrub(pc):
    rng = np.random.default_rng(21)
    balls = [((rng.uniform(-1.6, 1.6), rng.uniform(-1.2, 1.2), rng.uniform(0.6, 1.4)), rng.uniform(1.4, 2.0), (1.2, 1.1, 0.8)) for _ in range(4)]
    bm = _blob_mesh(balls, resolution=0.35, seed=22, lump=0.25, flat=-0.2, target=700)
    _adopt(pc.m("Foliage"), bm, _spherical(Vector((0, 0, 1)), 1.5))


def banner_cloth(pc):
    """3.2 x 8.6 cloth hanging from its top centre (origin), gentle folds, swallowtail hem."""
    m = pc.m("Banner")
    cols, rows = 12, 24
    P, UV = [], []
    for i in range(rows + 1):
        v = i / rows
        row, uvs = [], []
        for j in range(cols + 1):
            u = j / cols
            x = (u - 0.5) * 3.2
            z = -v * 8.6
            z += (1 - abs(u - 0.5) * 2) * max(0.0, v - 0.88) / 0.12 * 1.4  # swallowtail hem
            y = 0.16 * math.sin(u * math.pi * 3 + v * 1.4) * (0.4 + v) + 0.12 * v * v
            row.append(Vector((x, y, z)))
            uvs.append((u, 1 - v))
        P.append(row)
        UV.append(uvs)
    m.grid(P, UV, expect=Vector((0, -1, 0)), open_surface=True)
    back = [[p + Vector((0, 0.04, 0)) for p in row] for row in P]
    m.grid(back, UV, expect=Vector((0, 1, 0)), open_surface=True)


PIECES = [("Cloud_A", cloud_a), ("Cloud_B", cloud_b), ("Cloud_C", cloud_c), ("Tree_Maple", maple), ("Tree_MapleSmall", maple_b),
          ("Shrub_Crimson", shrub), ("Banner_Cloth", banner_cloth)]

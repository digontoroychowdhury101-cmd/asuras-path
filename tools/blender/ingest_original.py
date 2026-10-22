"""Turns the original AI statue + tree GLBs into Roblox MeshParts with no surface breakage.

Usage:
  Blender -b --python-exit-code 1 -P tools/blender/ingest_original.py -- <statue.glb> <tree.glb> <out_dir>
      [--keep 190000] [--tex 1024]

Why: generator GLBs are triangle soup (every triangle its own UV island, ~850k open edges per
500k tris). Decimating that unwelded tears the surface into floating shards. So each model is:
  1. welded (positions merged; UVs stay per-loop, so the original texture layout is untouched),
  2. decimated lightly to --keep tris (closed surface, so collapse stays clean),
  3. given smooth normals from the whole mesh (no lighting seams where it is cut),
  4. cut into <=19k-tri chunks by recursive median splits (Roblox MeshPart limit), no further
     decimation, all chunks sharing the source's own material (textures downsized to --tex).
Output: <out_dir>/veiled_titan_original.glb with Titan_Figure_NN and Titan_Canopy_NN (tree behind
her, +Y), and preview_original.png.
"""
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
STATUE, TREE, OUT = Path(ARGS[0]), Path(ARGS[1]), Path(ARGS[2])
KEEP = int(ARGS[ARGS.index("--keep") + 1]) if "--keep" in ARGS else 190000
TEX = int(ARGS[ARGS.index("--tex") + 1]) if "--tex" in ARGS else 1024
CAP = 19000


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def select(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def load(path, name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    select(meshes)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    return o


def bounds(o):
    co = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    return co, co.min(0), co.max(0)


def stand(o, height, offset=Vector()):
    """Height `height`, centred on x/y, base on z=0, then moved by offset."""
    _, lo, hi = bounds(o)
    s = height / (hi[2] - lo[2])
    o.data.transform(Matrix.Translation(offset) @ Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
    o.data.update()


def heal(o):
    select([o])
    if o.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bm = bmesh.new()
    bm.from_mesh(o.data)
    open_before = sum(1 for e in bm.edges if e.is_boundary)
    _, lo, hi = bounds(o)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=float(np.linalg.norm(hi - lo)) * 1e-6)
    open_after = sum(1 for e in bm.edges if e.is_boundary)
    bm.to_mesh(o.data)
    bm.free()
    print(f"WELD {o.name}: open edges {open_before} -> {open_after}", flush=True)
    if tris(o) > KEEP:
        m = o.modifiers.new("Dec", "DECIMATE")
        m.ratio = KEEP / tris(o)
        m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.shade_smooth()
    # Freeze whole-mesh smooth normals so chunk cuts don't show as lighting seams.
    me = o.data
    vn = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", vn)
    me.normals_split_custom_set_from_vertices(vn.reshape(-1, 3).tolist())
    for mat in me.materials:
        for n in (mat.node_tree.nodes if mat and mat.node_tree else []):
            if n.type == "TEX_IMAGE" and n.image and max(n.image.size) > TEX:
                n.image.scale(TEX, TEX)
                n.image.pack()


def chunks(o, name):
    """Recursive median split on face centres until every chunk is <= CAP tris."""
    me = o.data
    n = len(me.polygons)
    cen = np.empty(n * 3)
    me.polygons.foreach_get("center", cen)
    cen = cen.reshape(-1, 3)
    tri = np.array([len(p.vertices) - 2 for p in me.polygons])
    leaves, stack = [], [np.arange(n)]
    while stack:
        idx = stack.pop()
        if tri[idx].sum() <= CAP:
            leaves.append(idx)
            continue
        c = cen[idx]
        axis = int(np.argmax(c.max(0) - c.min(0)))
        order = idx[np.argsort(c[:, axis], kind="stable")]
        half = len(order) // 2
        stack += [order[half:], order[:half]]
    leaves.sort(key=lambda i: (cen[i, 2].mean(), cen[i, 0].mean()))
    out = []
    for k, idx in enumerate(leaves):
        part = o.copy()
        part.data = me.copy()
        part.name = part.data.name = f"{name}_{k + 1:02d}"
        bpy.context.scene.collection.objects.link(part)
        keep = np.zeros(n, bool)
        keep[idx] = True
        bm = bmesh.new()
        bm.from_mesh(part.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep[f.index]], context="FACES")
        bm.to_mesh(part.data)
        bm.free()
        out.append(part)
    bpy.data.objects.remove(o)
    return out


def preview(parts, path):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1000, 1300
    sc.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("Dusk")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.25, 0.3, 0.38, 1)
    sc.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy, sun.data.color = 4.0, (1.0, 0.8, 0.6)
    sun.rotation_euler = (0.9, 0, 0.5)
    sc.collection.objects.link(sun)
    cs = [o.matrix_world @ Vector(c) for o in parts for c in o.bound_box]
    lo = Vector([min(c[i] for c in cs) for i in range(3)])
    hi = Vector([max(c[i] for c in cs) for i in range(3)])
    ctr = (lo + hi) / 2
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = ctr + Vector((0.25, -1, 0.05)).normalized() * (hi - lo).length * 1.25
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True, exist_ok=True)
    statue = load(STATUE, "Titan_Figure")
    stand(statue, 1.0)
    heal(statue)
    _, lo, hi = bounds(statue)
    parts = chunks(statue, "Titan_Figure")
    tree = load(TREE, "Titan_Canopy")
    stand(tree, 1.0)
    co, _, _ = bounds(tree)
    base = co[co[:, 2] < 0.06 * co[:, 2].max()].mean(0)   # trunk foot
    tree.data.transform(Matrix.Translation(Vector((-base[0], hi[1] - base[1] + 0.1, 0))))  # behind her (+Y)
    tree.data.update()
    heal(tree)
    parts += chunks(tree, "Titan_Canopy")
    for o in parts:
        print("PART", o.name, tris(o), flush=True)
    select(parts)
    glb = OUT / "veiled_titan_original.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True)
    preview(parts, OUT / "preview_original.png")
    print("INGEST_OK", glb, len(parts), "parts", round(glb.stat().st_size / 1e6, 2), "MB")


main()

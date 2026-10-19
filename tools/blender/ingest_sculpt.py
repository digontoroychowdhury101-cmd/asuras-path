"""Turns a high-poly AI-generated (or scanned) statue into Roblox-ready MeshParts (headless Blender).

Usage:
  Blender -b --python-exit-code 1 -P tools/blender/ingest_sculpt.py -- <statue.glb> <out_dir>
      [--tree tree.glb] [--yaw 0] [--parts 2] [--grade 0.6] [--tex-dir assets/source/tex]

What it does:
  1. Imports the sculpt, joins it, faces it -Y (glTF +Z), stands it on z=0, height 1 m.
  2. Splits it by height into --parts slices so each MeshPart can use the full ~19k triangle budget,
     decimates each slice (seams protected), unwraps it, and bakes the high-poly detail into
     1024 Color / Normal / Roughness maps (selected-to-active from the original mesh).
  3. --grade pulls the generated colours toward weathered dark granite (0 = untouched, 1 = full).
  4. Optional --tree: same treatment as Titan_Canopy, placed behind her and scaled over her head,
     with crimson leaf cards on its outer branch tips and fallen leaves on the robe and ground.
  5. Writes <out_dir>/veiled_titan.glb, the leaf PNGs, maps, and a golden-hour preview.png.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).parent))
import bake_titan as bt  # noqa: E402  (shared bake/texture helpers)
import titan_dressing as td  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:]


def opt(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default


SRC, OUT = Path(ARGS[0]), Path(ARGS[1])
TREE = opt("--tree", "")
YAW = opt("--yaw", 0.0)
PARTS = opt("--parts", 2)
GRADE = opt("--grade", 0.6)
CAP = 19000
bt.configure(opt("--tex-dir", "assets/source/tex"), OUT)


def import_joined(path, name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    bt.select(meshes)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    return obj


def normalize(obj, height, yaw=0.0):
    obj.data.transform(Matrix.Rotation(math.radians(yaw), 4, "Z"))
    co = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    lo, hi = co.min(0), co.max(0)
    s = height / (hi[2] - lo[2])
    obj.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
    obj.data.update()


def slice_by_height(src, parts):
    """Copies of src split at face-count quantiles of height (each face lands in exactly one slice)."""
    probe = bmesh.new()
    probe.from_mesh(src.data)
    zs = np.array([f.calc_center_median().z for f in probe.faces])
    probe.free()
    cuts = [-1e9] + [float(np.quantile(zs, k / parts)) for k in range(1, parts)] + [1e9]
    out = []
    for k in range(parts):
        o = src.copy()
        o.data = src.data.copy()
        bpy.context.scene.collection.objects.link(o)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        kill = [f for f in bm.faces if not (cuts[k] <= f.calc_center_median().z < cuts[k + 1])]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        seam = [v.index for v in bm.verts if v.is_boundary]
        bm.to_mesh(o.data)
        bm.free()
        vg = o.vertex_groups.new(name="seam")
        vg.add(seam, 1.0, "REPLACE")
        out.append(o)
    return out


def decimate_keep_seams(o, cap):
    # Seam vertices are protected from collapsing; protection is relaxed only if the cap is missed.
    for factor in (1.0, 0.6, 0.3, 0.0):
        n = bt.tris(o)
        if n <= cap:
            break
        m = o.modifiers.new("Dec", "DECIMATE")
        m.ratio = cap / n * 0.97
        m.vertex_group = "seam"
        m.invert_vertex_group = True
        m.vertex_group_factor = factor
        bt.select([o])
        bpy.ops.object.modifier_apply(modifier=m.name)
    if bt.tris(o) > cap:
        raise SystemExit(f"{o.name}: {bt.tris(o)} tris still over cap {cap}")
    for g in list(o.vertex_groups):
        o.vertex_groups.remove(g)


def bake_from(hi, lo, name, grade):
    """Bakes hi's own materials onto lo's fresh UVs: Color (diffuse colour), Roughness, Normal."""
    bt.select([lo])
    # Decimation leaves the generator's custom split normals garbled; smooth normals bake cleanly.
    if lo.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.shade_smooth()
    if not lo.data.uv_layers:
        # Only when the source has no UVs; smart projection fragments decimated scans badly.
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
        bpy.ops.object.mode_set(mode="OBJECT")
    else:
        # Keep the generator's own layout (decimation carries it over); bake into the first map.
        while len(lo.data.uv_layers) > 1:
            lo.data.uv_layers.remove(lo.data.uv_layers[-1])
    lo.data.materials.clear()
    mat = bpy.data.materials.new(name + "_Mat")
    mat.use_nodes = True
    nt = mat.node_tree
    p = nt.nodes["Principled BSDF"]
    lo.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 4
    bk = sc.render.bake
    bk.use_selected_to_active = True
    size = max(hi.dimensions)
    bk.cage_extrusion = size * 0.015
    bk.max_ray_distance = size * 0.045
    bk.margin = 12
    bk.use_pass_direct = bk.use_pass_indirect = False
    bk.use_pass_color = True
    nodes = {}
    for key, kind, nc in (("Color", "DIFFUSE", False), ("Roughness", "ROUGHNESS", True), ("Normal", "NORMAL", True)):
        img = bt.new_image(f"{name}_{key}", non_color=nc)
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.nodes.active = node
        bt.select([hi, lo], active=lo)
        bpy.ops.object.bake(type=kind)
        if key == "Color" and grade > 0:
            a = bt.pixels(img)
            lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
            granite = lum[..., None] * np.array([0.62, 0.64, 0.68])      # cool, darker grey
            a[..., :3] = a[..., :3] * (1 - grade) + granite * grade
            img.pixels.foreach_set(a.ravel())
        bt.save(img, OUT / "maps" / f"{name}_{key}.png")
        nodes[key] = node
        print(f"BAKED {name} {key}", flush=True)
    nt.links.new(nodes["Color"].outputs["Color"], p.inputs["Base Color"])
    nt.links.new(nodes["Roughness"].outputs["Color"], p.inputs["Roughness"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nodes["Normal"].outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    p.inputs["Metallic"].default_value = 0.0


def place_tree(tree, statue):
    """Tree ~1.8x her height, trunk base just behind her back, crown over her head."""
    normalize(tree, statue.dimensions.z * 1.8)
    spread = max(tree.dimensions.x, tree.dimensions.y) / (max(statue.dimensions.x, statue.dimensions.y) * 2.4)
    if spread > 1:  # keep the canopy footprint within ~2.4x her width
        tree.data.transform(Matrix.Scale(1 / spread, 4))
        tree.data.update()
    co = np.array([v.co[:] for v in tree.data.vertices])
    base = co[co[:, 2] < 0.06 * co[:, 2].max()].mean(0)
    back = statue.dimensions.y * 0.5 + 0.04
    tree.data.transform(Matrix.Translation(Vector((-base[0], back - base[1], -0.02))))
    tree.data.update()


def leaf_tips(tree, count=70):
    co = np.array([v.co[:] for v in tree.data.vertices])
    top = co[:, 2].max()
    axis = co[co[:, 2] < 0.2 * top][:, :2].mean(0)
    radial = np.linalg.norm(co[:, :2] - axis, axis=1)
    pick = co[(co[:, 2] > 0.62 * top) & (radial > np.quantile(radial, 0.6))]
    if len(pick) == 0:
        pick = co[co[:, 2] > 0.8 * top]
    idx = np.random.default_rng(3).choice(len(pick), size=min(count, len(pick)), replace=False)
    return [Vector(pick[i]) for i in idx]


def preview(parts, path):
    """Golden-hour three-quarter render (Eevee) for visual QA."""
    sc = bpy.context.scene
    for o in list(sc.objects):
        if o not in parts:
            o.hide_render = True
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1100, 1300
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("Dusk")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.03, 0.025, 0.03, 1)
    sc.world = world
    for energy, rot, col in ((5.5, (55, 0, 35), (1.0, 0.72, 0.45)), (1.2, (65, 0, -150), (0.45, 0.55, 0.85)),
                             (3.0, (20, 0, 160), (1.0, 0.35, 0.25))):
        sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
        sun.data.energy, sun.data.color = energy, col
        sun.data.angle = math.radians(3)
        sun.rotation_euler = [math.radians(a) for a in rot]
        sc.collection.objects.link(sun)
    cs = [o.matrix_world @ Vector(c) for o in parts for c in o.bound_box]
    lo = Vector([min(c[i] for c in cs) for i in range(3)])
    hi = Vector([max(c[i] for c in cs) for i in range(3)])
    ctr = (lo + hi) / 2
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 50
    sc.collection.objects.link(cam)
    sc.camera = cam
    d = Vector((math.sin(math.radians(28)), -math.cos(math.radians(28)), 0.12)).normalized()
    cam.location = ctr + d * (hi - lo).length * 1.25
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    statue = import_joined(SRC, "StatueHigh")
    normalize(statue, 1.0, YAW)
    print("SOURCE", SRC.name, bt.tris(statue), "tris", flush=True)
    # Decimate the whole sculpt once and bake onto its original UVs, then slice it into MeshParts
    # that share the same Color/Normal/Roughness maps.
    whole = statue.copy()
    whole.data = statue.data.copy()
    bpy.context.scene.collection.objects.link(whole)
    whole.name = "Titan_Figure"
    bt.decimate(whole, int(CAP * PARTS * 0.97))
    bake_from(statue, whole, "Titan_Figure", GRADE)
    parts = []
    if PARTS == 1:
        parts.append(whole)
    else:
        for k, piece in enumerate(slice_by_height(whole, PARTS)):
            piece.name = f"Titan_Figure_{k + 1}"
            decimate_keep_seams(piece, CAP)
            parts.append(piece)
        bpy.data.objects.remove(whole)
    rest = [statue]
    if TREE:
        tree_hi = import_joined(TREE, "TreeHigh")
        place_tree(tree_hi, statue)
        canopy = tree_hi.copy()
        canopy.data = tree_hi.data.copy()
        bpy.context.scene.collection.objects.link(canopy)
        canopy.name = "Titan_Canopy"
        bt.decimate(canopy, CAP)
        bake_from(tree_hi, canopy, "Titan_Canopy", 0.0)
        parts.append(canopy)
        rest.append(tree_hi)
        leaves = td.leaves(leaf_tips(tree_hi), td.statue_bvh(rest))
        leaves.name = "Titan_Leaves"
        leaves.data.materials.append(bt.textured_material("CrimsonLeaves", bt.crimson_leaves(), alpha=True))
        parts.append(leaves)
    else:
        bt.crimson_leaves()  # still write the particle + decal PNGs
    bpy.context.view_layer.update()
    for o in parts:
        print("PART", o.name, bt.tris(o), [round(d, 3) for d in o.dimensions], flush=True)
    bt.select(parts)
    glb = OUT / "veiled_titan.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True)
    for o in rest:
        o.hide_render = True
    preview(parts, OUT / "preview.png")
    print("INGEST_OK", glb, round(glb.stat().st_size / 1e6, 2), "MB")


main()

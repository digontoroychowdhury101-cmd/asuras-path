"""Original, opaque-geometry bamboo ecology kit. Run in the dedicated live Blender scene.

Preserves other scenes/collections and existing masters. Stud units, Z-up source / Y-up GLB,
foot pivots, one material per mesh, no modifiers or decimation. 2048 PBR masters; 1024 export maps.
"""
from pathlib import Path
import bpy
import json
import math
import random
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/build/living_bamboo_v1"
OUT.mkdir(parents=True, exist_ok=True)
SCENE = "Asura Living Bamboo Master v1"
assert bpy.context.scene.name == SCENE, "Select the dedicated scene; original scenes are preserved"
assert not (OUT / "LivingBambooMaster.blend").exists(), "Master exists; use a versioned output for revisions"
collection = bpy.data.collections.new("LivingBamboo_v1")
bpy.context.scene.collection.children.link(collection)
rng = random.Random(291026)
manifest = {"units": "studs", "source_up": "Z", "export_up": "Y", "pivot": "authored foot origin",
            "provenance": "Original project-authored geometry and procedural PBR maps; no external art",
            "master_resolution": 2048, "export_resolution": 1024, "meshes": {}, "materials": {}}


def save_map(name, pixels, data=False):
    h, w = pixels.shape[:2]
    image = bpy.data.images.new(name, w, h, alpha=False, is_data=data)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = pixels
    image.pixels.foreach_set(rgba.ravel())
    path = OUT / "masters" / f"{name}.png"
    path.parent.mkdir(exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def surface(name, dry=False):
    n = 2048
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    u, v = (xx % (n // 8)) / (n // 8 - 1), (yy % (n // 4)) / (n // 4 - 1)
    tile = np.floor(xx / (n // 8)) + np.floor(yy / (n // 4)) * 8
    grain = np.sin(u * 173 + v * 11) * np.sin(u * 41 - v * 19)
    vein = np.exp(-((u - 0.5) / 0.022) ** 2)
    secondary = np.maximum(0, np.cos((u - 0.5) * 47 + v * 39)) ** 18
    mottling = np.sin(u * 13 + tile) * np.sin(v * 21 - tile * 0.3)
    tint = np.array((0.34, 0.25, 0.105) if dry else (0.12, 0.25, 0.055), dtype=np.float32)
    variation = 0.76 + (tile % 8) * 0.045 + 0.12 * v + grain * 0.035 + mottling * 0.025
    color = np.clip(tint * variation[:, :, None] * (1 - vein[:, :, None] * 0.13), 0, 1)
    if not dry:
        warm = (tile >= 27).astype(np.float32)[:, :, None]
        color = color * (1 - warm * 0.55) + np.array((0.30, 0.28, 0.08)) * warm * 0.55
    height = 0.012 * grain + 0.032 * vein + 0.008 * secondary
    dx, dy = np.gradient(height)
    normal = np.dstack((-dy * 8, -dx * 8, np.ones_like(height)))
    normal /= np.linalg.norm(normal, axis=2)[:, :, None]
    normal = normal * 0.5 + 0.5  # tangent-space OpenGL (+Y)
    rough = np.clip((0.88 if dry else 0.71) + grain * 0.035 + mottling * 0.035, 0, 1)
    maps = {
        "Color": save_map(name + "_Color", color),
        "Normal": save_map(name + "_Normal", normal, True),
        "Roughness": save_map(name + "_Roughness", np.repeat(rough[:, :, None], 3, 2), True),
        "Metalness": save_map(name + "_Metalness", np.zeros_like(color), True),
    }
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.use_backface_culling = False
    nodes = material.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    for kind, image in maps.items():
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        if kind == "Normal":
            node = nodes.new("ShaderNodeNormalMap")
            material.node_tree.links.new(tex.outputs["Color"], node.inputs["Color"])
            material.node_tree.links.new(node.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs[
                {"Color": "Base Color", "Roughness": "Roughness", "Metalness": "Metallic"}[kind]])
    manifest["materials"][name] = {k: str(Path(im.filepath_raw).relative_to(ROOT)) for k, im in maps.items()}
    return material


green, litter = surface("BambooLivingGreen"), surface("BambooDryLitter", True)


def uv(tile, u, v):
    # Six master pixels of padding stay inside the tile after the 2:1 upload resize.
    return ((tile % 8 + 0.024 + u * 0.952) / 8, (tile // 8 + 0.012 + v * 0.976) / 4)


class Mesh:
    def __init__(self):
        self.v, self.f, self.uv = [], [], []

    def leaf(self, start, direction, length, width, tile, curl=0.06):
        direction = Vector(direction).normalized()
        across = direction.cross(Vector((0, 0, 1)))
        if across.length < 0.01:
            across = Vector((1, 0, 0))
        across.normalize()
        normal = across.cross(direction).normalized()
        outline = [(0, 0, 0), (.28, -.5, .04), (.28, 0, .09), (.28, .5, .04),
                   (.72, -.35, -.01), (.72, 0, .04), (.72, .35, -.01), (1, 0, -curl)]
        offset = len(self.v)
        for t, s, h in outline:
            self.v.append(tuple(Vector(start) + direction * (t * length) + across * (s * width) + normal * (h * length)))
            self.uv.append(uv(tile, s + .5, t))
        self.f.extend(tuple(offset + i for i in face) for face in
                      [(0, 1, 2), (0, 2, 3), (1, 4, 5, 2), (2, 5, 6, 3), (4, 7, 5), (5, 7, 6)])

    def tube(self, points, radii, tile=28, sides=5):
        offset = len(self.v)
        for j, point in enumerate(points):
            tangent = (Vector(points[min(j + 1, len(points) - 1)]) - Vector(points[max(j - 1, 0)])).normalized()
            across = tangent.cross(Vector((0, 0, 1)))
            if across.length < .01:
                across = tangent.cross(Vector((0, 1, 0)))
            across.normalize()
            normal = tangent.cross(across).normalized()
            for k in range(sides):
                a = k * math.tau / sides
                self.v.append(tuple(Vector(point) + (across * math.cos(a) + normal * math.sin(a)) * radii[j]))
                self.uv.append(uv(tile, k / sides, j / (len(points) - 1)))
                if j:
                    b = offset + j * sides + k
                    bn = offset + j * sides + (k + 1) % sides
                    self.f.append((b - sides, bn - sides, bn, b))
        self.f.append(tuple(offset + k for k in reversed(range(sides))))
        self.f.append(tuple(offset + (len(points) - 1) * sides + k for k in range(sides)))

    def finish(self, name, material):
        data = bpy.data.meshes.new(name)
        data.from_pydata(self.v, [], self.f)
        data.update()
        layer = data.uv_layers.new(name="UVMap")
        for poly in data.polygons:
            poly.use_smooth = True
            for li, vi in zip(poly.loop_indices, poly.vertices):
                layer.data[li].uv = self.uv[vi]
        data.materials.append(material)
        ob = bpy.data.objects.new(name, data)
        collection.objects.link(ob)
        bpy.context.view_layer.update()
        evaluated = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        evaluated.calc_loop_triangles()
        triangles = len(evaluated.loop_triangles)
        ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
        assert triangles <= 18000, (name, triangles)
        manifest["meshes"][name] = {"evaluated_triangles": triangles, "vertices": len(self.v),
                                    "material": material.name, "pivot": [0, 0, 0]}
        return ob


mesh = Mesh()
for i in range(170):
    a = i * 2.39996
    r = math.sqrt(rng.random()) * 4.3
    start = (math.cos(a) * r, math.sin(a) * r, rng.uniform(.035, .11))
    heading = rng.uniform(0, math.tau)
    mesh.leaf(start, (math.cos(heading), math.sin(heading), rng.uniform(-.01, .06)),
              rng.uniform(.7, 1.7), rng.uniform(.10, .24), rng.randrange(32), curl=rng.uniform(-.03, .015))
mesh.finish("Ground_LeafLitter", litter)

mesh = Mesh()
for i in range(88):
    a = i * 2.39996
    r = math.sqrt(rng.random()) * 1.65
    mesh.leaf((math.cos(a) * r, math.sin(a) * r, 0), (math.cos(a) * .4, math.sin(a) * .4, 1),
              rng.uniform(1.05, 2.3), rng.uniform(.06, .13), rng.randrange(27), curl=.18)
mesh.finish("Ground_GrassTuft", green)

mesh = Mesh()
for i in range(8):
    yaw = i * 2.39996
    length = rng.uniform(2.1, 2.8)
    axis = Vector((math.cos(yaw), math.sin(yaw), 0))
    points = [axis * (length * t * .88) + Vector((0, 0, math.sin(t * 2.05) * 1.65)) for t in np.linspace(0, 1, 12)]
    mesh.tube(points, [.028 * (1 - j / 13) for j in range(12)], 22)
    for j in range(1, 15):
        t = j / 16
        start = axis * (length * t * .88) + Vector((0, 0, math.sin(t * 2.05) * 1.65))
        for side in (-1, 1):
            direction = (math.cos(yaw + side * 1.12), math.sin(yaw + side * 1.12), .12 - t * .23)
            mesh.leaf(start, direction, (1 - t) * .78 + .08, (1 - t) * .12 + .018, rng.randrange(24), curl=.02)
mesh.finish("Ground_Fern", green)

mesh = Mesh()
for branch in range(16):
    a = branch * 2.39996
    direction = Vector((math.cos(a), math.sin(a), -.08))
    tip = direction * rng.uniform(3.1, 5) + Vector((0, 0, rng.uniform(1.1, 2.2)))
    mesh.tube([Vector((0, 0, 0)), tip * .5 + Vector((0, 0, .6)), tip], [.04, .025, .008], 21)
    for i in range(12):
        t = rng.uniform(.45, 1)
        start = tip * t + Vector((0, 0, .3 * math.sin(t * math.pi)))
        a2 = a + rng.uniform(-.75, .75)
        mesh.leaf(start, (math.cos(a2), math.sin(a2), rng.uniform(-.45, -.1)),
                  rng.uniform(1.0, 1.9), rng.uniform(.12, .23), rng.randrange(32), curl=.12)
mesh.finish("Bamboo_LeafSpray", green)

mesh = Mesh()
for i in range(5):
    a = i * 2.39996
    base = Vector((math.cos(a) * i * .3, math.sin(a) * i * .3, 0))
    h = rng.uniform(2.3, 5.2)
    points = [base + Vector((.12 * t * t, 0, h * t)) for t in np.linspace(0, 1, 9)]
    mesh.tube(points, [.18 * (1 - j / 8) + .008 for j in range(9)], 28 + i % 4, 8)
    for j in range(3):
        yaw = a + j * 2.2
        mesh.leaf(base + Vector((0, 0, h * (.42 + j * .15))), (math.cos(yaw), math.sin(yaw), .3),
                  .55 + j * .12, .11, 5 + j * 6, curl=.13)
mesh.finish("Bamboo_YoungShoots", green)

manifest["total_triangles"] = sum(v["evaluated_triangles"] for v in manifest["meshes"].values())
manifest["part_count"] = len(manifest["meshes"])
master = OUT / "LivingBambooMaster.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(master))

# Upload maps are separate images; preserve the original master pixels and material links.
relinks = []
export_maps = OUT / "maps"
export_maps.mkdir(exist_ok=True)
for material in (green, litter):
    for node in material.node_tree.nodes:
        if node.type != "TEX_IMAGE":
            continue
        original = node.image
        copy = bpy.data.images.load(original.filepath_raw, check_existing=False)
        copy.colorspace_settings.name = original.colorspace_settings.name
        copy.scale(1024, 1024)
        copy.filepath_raw = str(export_maps / Path(original.filepath_raw).name)
        copy.file_format = "PNG"
        copy.save()
        node.image = copy
        relinks.append((node, original))
for ob in bpy.context.selected_objects:
    ob.select_set(False)
for ob in collection.objects:
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT / "LivingBambooGround.glb"), export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True, export_animations=False)
for ob in collection.objects:
    ob.select_set(ob.name == "Ground_LeafLitter")
bpy.ops.export_scene.gltf(filepath=str(OUT / "LeafLitterCalibration.glb"), export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True, export_animations=False)
for node, original in relinks:
    node.image = original
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))

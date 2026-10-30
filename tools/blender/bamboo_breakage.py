"""Original hollow, splintered bamboo: one broken clump and one fallen pole.

Run through live Blender MCP. Preserves all existing scenes and masters; creates a dedicated
scene/version, 2048 PBR masters and separate 1024 export maps. No decimation or alpha cards.
"""
from pathlib import Path
import bpy
import json
import math
import random
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/build/bamboo_breakage_v2"
assert not (OUT / "BambooBreakageMaster.blend").exists(), "Preserve the existing master; version revisions"
OUT.mkdir(parents=True, exist_ok=True)
previous_scene = bpy.context.scene.name
scene = bpy.data.scenes.new("Asura Bamboo Breakage Master v2")
bpy.context.window.scene = scene
collection = bpy.data.collections.new("BambooBreakage_v2")
scene.collection.children.link(collection)
rng = random.Random(291027)
manifest = {"provenance": "Original project-authored geometry and procedural PBR maps",
            "units": "studs", "source_up": "Z", "export_up": "Y", "pivot": "ground origin",
            "previous_scene_preserved": previous_scene, "master_resolution": 2048,
            "upload_resolution": 1024, "parts": {}, "materials": {}}


def material(name, cut=False):
    n = 2048
    yy, xx = np.mgrid[:n, :n].astype(np.float32)
    u, v = (xx % 256) / 255, (yy % 512) / 511
    tile = np.floor(xx / 256) + np.floor(yy / 512) * 8
    streak = np.sin(u * 151 + np.sin(v * 11) * .4) * np.sin(u * 39 + tile)
    if cut:
        radius = np.sqrt((u - .5) ** 2 + (v - .5) ** 2)
        fiber = np.sin(radius * 151 + streak * .12)
        color = np.array((.57, .43, .22)) * (.87 + .10 * fiber[:, :, None])
        height = fiber * .013 + streak * .003
        roughness = np.clip(.91 + fiber * .025, 0, 1)
    else:
        band = np.exp(-(np.sin(v * math.pi * 5) / .15) ** 2)
        pale = np.maximum(0, np.sin(u * 29 + v * 71 + tile)) ** 18
        variation = .78 + (tile % 7) * .037 + streak * .035
        color = np.array((.19, .30, .09)) * variation[:, :, None]
        color *= (1 - band[:, :, None] * .36)
        color += pale[:, :, None] * np.array((.07, .065, .04))
        height = streak * .009 + band * .032
        roughness = np.clip(.78 + streak * .04 + pale * .05, 0, 1)
    dv, du = np.gradient(height)
    normal = np.dstack((-du * 9, -dv * 9, np.ones_like(height)))
    normal /= np.linalg.norm(normal, axis=2)[:, :, None]
    maps = {"Color": color, "Normal": normal * .5 + .5,
            "Roughness": np.repeat(roughness[:, :, None], 3, axis=2), "Metalness": np.zeros_like(color)}
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(x for x in mat.node_tree.nodes if x.type == "BSDF_PRINCIPLED")
    files = {}
    for kind, pixels in maps.items():
        image = bpy.data.images.new(f"{name}_{kind}", n, n, alpha=False, is_data=kind != "Color")
        rgba = np.ones((n, n, 4), dtype=np.float32)
        rgba[:, :, :3] = np.clip(pixels, 0, 1)
        image.pixels.foreach_set(rgba.ravel())
        path = OUT / "masters" / f"{name}_{kind}.png"
        path.parent.mkdir(exist_ok=True)
        image.filepath_raw, image.file_format = str(path), "PNG"
        image.save(); image.pack()
        node = mat.node_tree.nodes.new("ShaderNodeTexImage"); node.image = image
        if kind == "Normal":
            bump = mat.node_tree.nodes.new("ShaderNodeNormalMap")
            mat.node_tree.links.new(node.outputs["Color"], bump.inputs["Color"])
            mat.node_tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs[
                {"Color": "Base Color", "Roughness": "Roughness", "Metalness": "Metallic"}[kind]])
        files[kind] = str(path.relative_to(ROOT))
    manifest["materials"][name] = files
    return mat


green, cut = material("BrokenBambooCulm"), material("BrokenBambooCut", True)


def uv(tile, u, v):
    return ((tile % 8 + .025 + .95 * u) / 8, (tile // 8 + .012 + .976 * v) / 4)


class Mesh:
    def __init__(self):
        self.v, self.f, self.uv, self.normals = [], [], [], []

    def vertex(self, point, tex, normal):
        self.v.append(tuple(point)); self.uv.append(tex); self.normals.append(tuple(normal))
        return len(self.v) - 1

    def finish(self, name, mat, smooth=True):
        name = name.replace("__", "_V2__")
        data = bpy.data.meshes.new(name)
        data.from_pydata(self.v, [], self.f); data.update()
        layer = data.uv_layers.new(name="UVMap")
        for poly in data.polygons:
            poly.use_smooth = smooth
            for li, vi in zip(poly.loop_indices, poly.vertices): layer.data[li].uv = self.uv[vi]
        if smooth: data.normals_split_custom_set_from_vertices(self.normals)
        data.materials.append(mat)
        ob = bpy.data.objects.new(name, data); collection.objects.link(ob)
        data.calc_loop_triangles()
        count = len(data.loop_triangles)
        assert count <= 18000, (name, count)
        manifest["parts"][name] = {"evaluated_triangles": count, "vertices": len(data.vertices),
                                    "material": mat.name, "pivot": [0, 0, 0]}
        return ob


def hollow(wall, rim, frame, height, radius, tile, torn=True):
    sides = 20
    # Closely spaced profile rings make modeled nodes, rather than dark painted stripes alone.
    levels = [(0, 1), (.08, 1)]
    for j in range(1, 5):
        z = height * j / 5
        levels += [(z - .06, 1), (z, 1.13), (z + .06, 1)]
    levels.append((height, .86))
    radii = [radius * swell * (1 - .10 * z / height) for z, swell in levels]
    rows = []
    prongs = ({3, 12}, {1, 7, 14}, {5, 16}, {2, 9, 17})[(tile // 7) % 4]
    jagged = [(.13 * math.sin(k * 2.7 + tile) + (.32 if k in prongs else 0)) if torn else 0 for k in range(sides)]
    for j, (z, swell) in enumerate(levels):
        row = []
        for k in range(sides + 1):
            a = math.tau * k / sides
            top = j == len(levels) - 1
            zz = z + (jagged[k % sides] if top else 0)
            r = radii[j]
            radial = Vector((math.cos(a), math.sin(a), 0))
            point = Vector((radial.x * r + .08 * (z / height) ** 2, radial.y * r, zz))
            lo, hi = max(j - 1, 0), min(j + 1, len(levels) - 1)
            slope = (radii[hi] - radii[lo]) / max(levels[hi][0] - levels[lo][0], .01)
            normal = Vector((radial.x, radial.y, -slope)).normalized()
            row.append(wall.vertex(frame @ point, uv(tile, k / sides, z / height), frame.to_3x3() @ normal))
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for k in range(sides): wall.f.append((a[k], a[k + 1], b[k + 1], b[k]))
    # Dark inside wall ends at a solid node below the broken mouth. The cut ring is a separate
    # compatible material section, sharing exactly the outer/inner boundary positions.
    inner, bottom = [], []
    for k in range(sides + 1):
        a = math.tau * k / sides
        r = radius * .86 * .90 * .68
        radial = Vector((math.cos(a), math.sin(a), 0))
        point = Vector((radial.x * r + .08, radial.y * r, height + jagged[k % sides]))
        inner.append(wall.vertex(frame @ point, uv(tile, k / sides, .85), -(frame.to_3x3() @ radial)))
        low = Vector((point.x, point.y, height - min(height * .45, 1.25)))
        bottom.append(wall.vertex(frame @ low, uv(tile, k / sides, .65), -(frame.to_3x3() @ radial)))
        outer = wall.v[rows[-1][k]]
        inner_point = wall.v[inner[-1]]
        for p, rr in ((outer, 1), (inner_point, .68)):
            rim.vertex(p, uv(2, .5 + math.cos(a) * rr * .46, .5 + math.sin(a) * rr * .46), frame.to_3x3() @ Vector((0, 0, 1)))
    for k in range(sides):
        wall.f.append((inner[k], inner[k + 1], bottom[k + 1], bottom[k]))
        rim.f.append((k * 2, (k + 1) * 2, (k + 1) * 2 + 1, k * 2 + 1))
    # Offset face indices for subsequent culms added to this same material section.
    offset = len(rim.v) - (sides + 1) * 2
    if offset:
        rim.f[-sides:] = [tuple(v + offset for v in f) for f in rim.f[-sides:]]
    wall.f.append(tuple(reversed(rows[0][:-1])))
    disk = []
    for k in range(sides):
        a = math.tau * k / sides
        disk.append(rim.vertex(wall.v[bottom[k]], uv(2, .5 + math.cos(a) * .31, .5 + math.sin(a) * .31),
                               frame.to_3x3() @ Vector((0, 0, 1))))
    rim.f.append(tuple(disk))


for unit in ("Bamboo_BrokenClump", "Bamboo_FallenPole"):
    wall, rim = Mesh(), Mesh()
    if unit.endswith("Clump"):
        for i, (x, y, h, r) in enumerate(((-.7, -.4, 3.1, .37), (.5, .3, 7.8, .31), (1.1, -.5, 5.2, .27))):
            frame = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(math.radians((-3, 7, -9)[i]), 4, "Y")
            hollow(wall, rim, frame, h, r, i * 7)
    else:
        frame = Matrix.Translation((0, 0, .39)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
        hollow(wall, rim, frame, 11.2, .39, 21)
    wall.finish(unit + "__Culm", green)
    rim.finish(unit + "__Cut", cut, False)

bpy.context.view_layer.update()
manifest["part_count"] = len(manifest["parts"])
manifest["total_triangles"] = sum(x["evaluated_triangles"] for x in manifest["parts"].values())
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "BambooBreakageMaster.blend"))
links = []
for mat in (green, cut):
    for node in mat.node_tree.nodes:
        if node.type != "TEX_IMAGE": continue
        original = node.image
        image = bpy.data.images.load(original.filepath_raw, check_existing=False)
        image.colorspace_settings.name = original.colorspace_settings.name
        image.scale(1024, 1024)
        path = OUT / "maps" / Path(original.filepath_raw).name; path.parent.mkdir(exist_ok=True)
        image.filepath_raw, image.file_format = str(path), "PNG"; image.save()
        links.append((node, original)); node.image = image
for ob in scene.objects: ob.select_set(ob.type == "MESH")
bpy.ops.export_scene.gltf(filepath=str(OUT / "BambooBreakage.glb"), export_format="GLB", use_selection=True,
                          use_active_scene=True, export_apply=True, export_yup=True, export_animations=False)
for node, original in links: node.image = original
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))

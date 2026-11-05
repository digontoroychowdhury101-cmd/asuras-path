"""Author one full-height limestone support with measured, nearly isotropic UVs.

Connected Blender: import this module and call prepare_source(NEW_DIRECTORY).
Separate process: Blender --background --factory-startup --python this.py -- bake DIRECTORY
Masters are versioned and original landing/physics geometry is never edited.
"""
from pathlib import Path
import hashlib
import json
import math
import random
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
HEIGHT = 14.2
COLLECTION = "AsuraFrostSupport_Source"


def enum_set(owner, prop, value):
    assert value in {item.identifier for item in owner.bl_rna.properties[prop].enum_items}, (prop, value)
    setattr(owner, prop, value)


def geometry(collection):
    rng = random.Random(511026)
    count = 24
    profile = [(0, 2.10), (1, 2.24), (2.9, 2.11), (4.8, 2.02),
               (7, 1.98), (9.5, 2.06), (12.2, 2.13), (HEIGHT, 2.07)]
    vertices, faces = [], []
    for ring, (height, radius) in enumerate(profile):
        for j in range(count):
            angle = j * math.tau / count
            c, s = math.cos(angle), math.sin(angle)
            r = radius + (rng.uniform(-.055, .055) if ring not in (0, len(profile) - 1) else 0)
            z = height + (rng.uniform(-.065, .065) if ring not in (0, len(profile) - 1) else 0)
            vertices.append((math.copysign(abs(c) ** .5, c) * r,
                             math.copysign(abs(s) ** .5, s) * r, z))
    for ring in range(len(profile) - 1):
        for j in range(count):
            a, b = ring * count + j, ring * count + (j + 1) % count
            faces.append((a, b, b + count, a + count))
    bottom, top = len(vertices), len(vertices) + 1
    vertices.extend([(0, 0, 0), (0, 0, HEIGHT)])
    for j in range(count):
        faces.extend([(bottom, (j + 1) % count, j),
                      (top, (len(profile) - 1) * count + j, (len(profile) - 1) * count + (j + 1) % count)])
    mesh = bpy.data.meshes.new("FrostSupport_A")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("FrostSupport_A__Limestone", mesh)
    collection.objects.link(obj)
    rock, atlas = mesh.uv_layers.new(name="RockUV"), mesh.uv_layers.new(name="AtlasUV")
    density, tile = .047, 8.0
    for poly in mesh.polygons:
        poly.use_smooth = len(poly.vertices) == 4
        if len(poly.vertices) == 4:
            j = poly.index % count
            chart, start = j // 6, (j // 6) * 6
            for loop_index in poly.loop_indices:
                vi = mesh.loops[loop_index].vertex_index
                ring, k = divmod(vi, count)
                if k == 0 and j == count - 1:
                    k = count
                def arc(first, last):
                    return sum((mesh.vertices[ring * count + (a + 1) % count].co
                                - mesh.vertices[ring * count + a % count].co).length
                               for a in range(first, last))
                z = mesh.vertices[vi].co.z
                # Exactly two repeats close the source texture at the back seam.
                # Normalising each ring also avoids a seam as its radius varies.
                rock.data[loop_index].uv = (arc(0, k) / arc(0, count) * 2.0, z / tile)
                atlas.data[loop_index].uv = (.025 + chart * .24 + arc(start, k) * density,
                                             .05 + z * density)
        else:
            upper = poly.center.z > HEIGHT / 2
            for loop_index in poly.loop_indices:
                p = mesh.vertices[mesh.loops[loop_index].vertex_index].co
                rock.data[loop_index].uv = (p.x / tile, p.y / tile)
                atlas.data[loop_index].uv = ((.30 if upper else .05) + (p.x / 4.7 + .5) * .18,
                                             .78 + (p.y / 4.7 + .5) * .18)
    mesh.uv_layers.active_index = 1
    mesh.calc_loop_triangles()
    return obj


def material():
    mat = bpy.data.materials.new("FrostSupport_Limestone_Source")
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    uv = tree.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "RockUV"
    for kind in ("Color", "Normal", "Roughness"):
        img = bpy.data.images.load(str(ROOT / "assets/github/terrain_ready" / f"AsuraCliff_{kind}.png"), check_existing=False)
        img.name = "FrostSupport_Source_" + kind
        if kind != "Color":
            img.colorspace_settings.name = "Non-Color"
        img.pack()
        n = tree.nodes.new("ShaderNodeTexImage")
        n.image = img
        enum_set(n, "extension", "REPEAT")
        tree.links.new(uv.outputs["UV"], n.inputs["Vector"])
        if kind == "Normal":
            normal = tree.nodes.new("ShaderNodeNormalMap")
            normal.uv_map = "RockUV"
            tree.links.new(n.outputs["Color"], normal.inputs["Color"])
            tree.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            tree.links.new(n.outputs["Color"], bsdf.inputs["Base Color" if kind == "Color" else kind])
    return mat


def uv_report(obj, uv_name, scale=(1, 1, 1)):
    mesh = obj.data
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers[uv_name]
    ratios = []
    for tri in mesh.loop_triangles:
        p = [Vector(tuple(mesh.vertices[i].co[j] * scale[j] for j in range(3))) for i in tri.vertices]
        e1, e2 = p[1] - p[0], p[2] - p[0]
        normal = e1.cross(e2)
        area = normal.length / 2
        if area < 1e-9 or abs(normal.normalized().z) > .9:
            continue
        t = [uv.data[i].uv for i in tri.loops]
        a, b = t[1] - t[0], t[2] - t[0]
        det = a.x * b.y - b.x * a.y
        if abs(det) < 1e-12:
            raise AssertionError("degenerate side UV")
        u, v = (e1 * b.y - e2 * a.y) / det, (e2 * a.x - e1 * b.x) / det
        aa, bb, cc = u.dot(u), u.dot(v), v.dot(v)
        d = math.sqrt((aa - cc) ** 2 + 4 * bb * bb)
        low, high = (aa + cc - d) / 2, (aa + cc + d) / 2
        assert low > 0
        ratios.append((math.sqrt(high / low), area))
    ratios.sort()
    total = sum(w for _, w in ratios)
    def quantile(q):
        cumulative = 0
        for value, weight in ratios:
            cumulative += weight
            if cumulative >= total * q:
                return value
        return ratios[-1][0]
    return {"areaWeightedMedianSideAnisotropy": quantile(.5), "p95SideAnisotropy": quantile(.95),
            "maxSideAnisotropy": ratios[-1][0], "sideTriangles": len(ratios)}


def source_seam_report(obj):
    """Compare the two source-UV coordinates sharing each seam vertex."""
    mesh = obj.data
    uv = mesh.uv_layers["RockUV"]
    errors = []
    for vi in range(0, 24 * 8, 24):
        coords = [uv.data[li].uv.copy() for p in mesh.polygons if len(p.vertices) == 4
                  for li in p.loop_indices if mesh.loops[li].vertex_index == vi]
        low, high = min(coords, key=lambda p: p.x), max(coords, key=lambda p: p.x)
        errors.append(max(abs(high.x - low.x - 2.0), abs(high.y - low.y)))
    assert max(errors) < 1e-6, errors
    return {"sourceRepeats": 2, "maxWrappedCoordinateError": max(errors), "seamVertices": len(errors)}


def prepare_source(out, revision="v2"):
    """Small live-MCP authoring step; leaves every object in the original scene intact."""
    out = Path(out).resolve()
    assert not out.exists(), "choose a new directory; original masters are never overwritten"
    collection_name = COLLECTION + "_" + revision
    assert collection_name not in bpy.data.collections, "source collection already exists; resume it"
    out.mkdir(parents=True)
    original_scene = bpy.context.scene.name
    scene = bpy.data.scenes.new("AsuraFrostSupport_Review_" + revision)
    collection = bpy.data.collections.new(collection_name)
    scene.collection.children.link(collection)
    obj = geometry(collection)
    obj.data.materials.append(material())
    if bpy.context.window:
        bpy.context.window.scene = scene
    scene.view_layers[0].update()
    bpy.data.libraries.write(str(out / "FrostSupport_Source.blend"), {collection}, fake_user=True)
    report = {"kind": "editable uninstalled support source; existing landing meshes and colliders untouched",
              "originalScenePreserved": original_scene, "reviewScene": scene.name,
              "object": obj.name, "collection": collection.name, "revision": revision,
              "sourceHeight": HEIGHT, "dimensions": list(obj.dimensions), "sourceSeam": source_seam_report(obj),
              "triangles": len(obj.data.loop_triangles), "sourceUV": uv_report(obj, "AtlasUV")}
    (out / "source.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def bake(out):
    assert bpy.app.background and not bpy.data.filepath, "separate factory-startup process required"
    out = Path(out).resolve()
    assert not (out / "FrostSupport_A.glb").exists(), "resume/review existing export rather than overwrite it"
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    source_report = json.loads((out / "source.json").read_text())
    collection_name = source_report.get("collection", COLLECTION)
    with bpy.data.libraries.load(str(out / "FrostSupport_Source.blend"), link=False) as (source, target):
        assert collection_name in source.collections
        target.collections = [collection_name]
    collection = target.collections[0]
    bpy.context.scene.collection.children.link(collection)
    obj = next(o for o in collection.objects if o.type == "MESH")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mat = obj.data.materials[0]
    scene = bpy.context.scene
    try:
        scene.render.engine = "CYCLES"
    except TypeError as error:
        raise RuntimeError("Cycles unavailable") from error
    scene.cycles.samples = 8
    maps = {}
    for kind, pixels, bake_type in [("Color", 2048, "DIFFUSE"), ("Normal", 2048, "NORMAL"), ("Roughness", 1024, "ROUGHNESS")]:
        image = bpy.data.images.new("FrostSupport_" + kind, pixels, pixels, alpha=False)
        if kind != "Color":
            image.colorspace_settings.name = "Non-Color"
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        mat.node_tree.nodes.active = node
        scene.render.bake.margin = 20 if pixels == 2048 else 10
        scene.render.bake.use_pass_direct = scene.render.bake.use_pass_indirect = False
        scene.render.bake.use_pass_color = True
        bpy.ops.object.bake(type=bake_type)
        image.filepath_raw = str(out / (kind + ".png"))
        enum_set(image, "file_format", "PNG")
        image.save()
        maps[kind] = image
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "FrostSupport_Baked_Master.blend"))
    final = bpy.data.materials.new("FrostSupport_PBR")
    final.use_nodes = True
    tree = final.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    for kind, image in maps.items():
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        if kind == "Normal":
            normal = tree.nodes.new("ShaderNodeNormalMap")
            tree.links.new(node.outputs["Color"], normal.inputs["Color"])
            tree.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color" if kind == "Color" else kind])
    obj.data = obj.data.copy()
    obj.data.uv_layers.remove(obj.data.uv_layers["RockUV"])
    obj.data.materials.clear()
    obj.data.materials.append(final)
    obj.data.calc_loop_triangles()
    count = len(obj.data.loop_triangles)
    assert count == 384 and len(obj.data.uv_layers) == len(obj.data.materials) == 1
    path = out / "FrostSupport_A.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_tangents=True)
    variants = []
    for height in (12.7, 14.2, 15.7):
        scale = (4.7 / obj.dimensions.x, 4.7 / obj.dimensions.y, height / HEIGHT)
        variants.append({"runtimeHeight": height, "resize": scale, "UV": uv_report(obj, "AtlasUV", scale)})
    assert max(v["UV"]["p95SideAnisotropy"] for v in variants) < 1.3, variants
    manifest = {"kind": "uninstalled full-height frost-support candidate", "file": path.name,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size,
                "units": "project studs; Blender Z-up to glTF Y-up; verify representative import against 14.2-stud source",
                "dimensions": list(obj.dimensions), "triangles": count, "UVSets": 1, "materials": 1,
                "runtimeReuse": variants, "totalSupportTriangles": count * 3,
                "sourceSeam": source_report.get("sourceSeam"),
                "maps": {k: {"file": k + ".png", "pixels": list(v.size),
                    "sha256": hashlib.sha256((out / (k + ".png")).read_bytes()).hexdigest()} for k, v in maps.items()},
                "credits": "Original project geometry/UVs; already credited Terrain3D / ambientCG Rock023 CC0 maps",
                "collision": "decorative support only; original three landing and footing colliders unchanged",
                "importLimitSource": "https://create.roblox.com/docs/art/modeling/specifications",
                "currentImportLimitTriangles": 20000}
    assert path.stat().st_size < 20_000_000
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("FROST_SUPPORT_READY", json.dumps(manifest))


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1:]
    assert arguments[0] == "bake"
    bake(arguments[1])

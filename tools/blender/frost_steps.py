"""Separate-process frost-worn shells for Bamboo's three unchanged 4x4 climb colliders.

Blender --background --factory-startup --python tools/blender/frost_steps.py -- NEW_OUTPUT
Original geometry, one shared PBR atlas, no decimation. Source master is separate from exports.
This is an import candidate, not installed game art or gameplay evidence.
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


def enum_set(obj, prop, value):
    assert value in {x.identifier for x in obj.bl_rna.properties[prop].enum_items}, (prop, value)
    setattr(obj, prop, value)


def image_node(tree, path, uv):
    node = tree.nodes.new("ShaderNodeTexImage")
    node.image = bpy.data.images.load(str(path), check_existing=True)
    tree.links.new(uv.outputs["UV"], node.inputs["Vector"])
    return node


def geometry(name, seed):
    rng = random.Random(seed)
    count = 32
    vertices, faces = [], []
    for ring, (height, radius) in enumerate([(0, 1.95), (.85, 2.18), (1.8, 2.3), (2.7, 2.23), (3.58, 2.16), (4, 2.025)]):
        for j in range(count):
            angle = j * 2 * math.pi / count
            c, s = math.cos(angle), math.sin(angle)
            scale = 1 / max(abs(c), abs(s))
            # The complete 4x4 landing square stays flat and covered. Irregularity belongs below it.
            r = radius + (rng.uniform(-.16, .15) if ring < 5 else 0)
            z = height + (rng.uniform(-.12, .12) if 0 < ring < 5 else 0)
            vertices.append((c * scale * r, s * scale * r, z))
    for ring in range(5):
        for j in range(count):
            a, b = ring * count + j, ring * count + (j + 1) % count
            faces.append((a, b, b + count, a + count))
    bottom, top = len(vertices), len(vertices) + 1
    vertices.extend([(0, 0, 0), (0, 0, 4)])
    for j in range(count):
        faces.extend([(bottom, (j + 1) % count, j), (top, 160 + j, 160 + (j + 1) % count)])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name + "__Stone", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    return obj


def source_material():
    mat = bpy.data.materials.new("FrostStep_Source")
    mat.use_nodes = True
    t = mat.node_tree
    bsdf = next(n for n in t.nodes if n.type == "BSDF_PRINCIPLED")
    uv = t.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "RockUV"
    source = ROOT / "assets/github/terrain_ready"
    color = image_node(t, source / "AsuraCliff_Color.png", uv)
    normal = image_node(t, source / "AsuraCliff_Normal.png", uv)
    rough = image_node(t, source / "AsuraCliff_Roughness.png", uv)
    for n in (normal, rough):
        n.image.colorspace_settings.name = "Non-Color"
    coord = t.nodes.new("ShaderNodeTexCoord")
    xyz = t.nodes.new("ShaderNodeSeparateXYZ")
    t.links.new(coord.outputs["Generated"], xyz.inputs[0])
    noise = t.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 8
    noise.inputs["Detail"].default_value = 3
    t.links.new(coord.outputs["Generated"], noise.inputs["Vector"])
    amount = t.nodes.new("ShaderNodeMath")
    enum_set(amount, "operation", "MULTIPLY_ADD")
    amount.inputs[1].default_value, amount.inputs[2].default_value = .09, -.045
    t.links.new(noise.outputs["Fac"], amount.inputs[0])
    height = t.nodes.new("ShaderNodeMath")
    enum_set(height, "operation", "ADD")
    t.links.new(xyz.outputs["Z"], height.inputs[0])
    t.links.new(amount.outputs[0], height.inputs[1])
    mask = t.nodes.new("ShaderNodeMapRange")
    mask.inputs["From Min"].default_value, mask.inputs["From Max"].default_value = .86, .98
    mask.clamp = True
    t.links.new(height.outputs[0], mask.inputs["Value"])
    mix = t.nodes.new("ShaderNodeMixRGB")
    mix.inputs[2].default_value = (.69, .75, .77, 1)
    t.links.new(mask.outputs[0], mix.inputs[0])
    t.links.new(color.outputs["Color"], mix.inputs[1])
    t.links.new(mix.outputs[0], bsdf.inputs["Base Color"])
    nm = t.nodes.new("ShaderNodeNormalMap")
    nm.uv_map = "RockUV"
    t.links.new(normal.outputs["Color"], nm.inputs["Color"])
    t.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    rmix = t.nodes.new("ShaderNodeMixRGB")
    rmix.inputs[2].default_value = (.94, .94, .94, 1)
    t.links.new(mask.outputs[0], rmix.inputs[0])
    t.links.new(rough.outputs["Color"], rmix.inputs[1])
    t.links.new(rmix.outputs[0], bsdf.inputs["Roughness"])
    return mat, bsdf


def main(out):
    assert bpy.app.background and not bpy.data.filepath, "separate factory-startup process required"
    out = Path(out).resolve()
    if out.exists():
        raise FileExistsError("choose a new directory; never overwrite a source master")
    out.mkdir(parents=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    objects = [geometry("FrostStep_" + letter, 301101 + i * 103) for i, letter in enumerate("ABC")]
    first = objects[0]
    bpy.context.view_layer.objects.active = first
    first.select_set(True)
    first.data.uv_layers.new(name="RockUV")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=4)
    bpy.ops.object.mode_set(mode="OBJECT")
    first.data.uv_layers.new(name="BakeUV")
    first.data.uv_layers.active_index = 1
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(65), island_margin=.025)
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj in objects[1:]:
        for layer in first.data.uv_layers:
            target = obj.data.uv_layers.new(name=layer.name)
            for a, b in zip(target.data, layer.data):
                a.uv = b.uv
        obj.data.uv_layers.active_index = 1
    mat, bsdf = source_material()
    for obj in objects:
        obj.data.materials.append(mat)
    for obj in objects:
        obj.select_set(obj == first)
    scene = bpy.context.scene
    try:
        scene.render.engine = "CYCLES"
    except TypeError as error:
        raise RuntimeError("Cycles unavailable; source preserved") from error
    scene.cycles.samples = 8
    scene.render.bake.margin = 24
    atlas = {}
    for kind, size, bake in [("Color", 2048, "DIFFUSE"), ("Normal", 2048, "NORMAL"), ("Roughness", 1024, "ROUGHNESS")]:
        img = bpy.data.images.new("FrostStep_" + kind, size, size, alpha=False)
        if kind != "Color":
            img.colorspace_settings.name = "Non-Color"
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        mat.node_tree.nodes.active = node
        scene.render.bake.use_pass_direct = scene.render.bake.use_pass_indirect = False
        scene.render.bake.use_pass_color = True
        bpy.ops.object.bake(type=bake)
        img.filepath_raw = str(out / (kind + ".png"))
        enum_set(img, "file_format", "PNG")
        img.save()
        atlas[kind] = img
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "FrostSteps_Master.blend"))
    # Export copies have exactly one UV set, one material and the baked supported maps.
    final = bpy.data.materials.new("FrostStep_PBR")
    final.use_nodes = True
    t = final.node_tree
    p = next(n for n in t.nodes if n.type == "BSDF_PRINCIPLED")
    for kind, img in atlas.items():
        n = t.nodes.new("ShaderNodeTexImage")
        n.image = img
        if kind == "Normal":
            nm = t.nodes.new("ShaderNodeNormalMap")
            t.links.new(n.outputs["Color"], nm.inputs["Color"])
            t.links.new(nm.outputs["Normal"], p.inputs["Normal"])
        else:
            t.links.new(n.outputs["Color"], p.inputs["Base Color" if kind == "Color" else kind])
    parts = []
    for i, obj in enumerate(objects):
        obj.data = obj.data.copy()
        obj.data.uv_layers.remove(obj.data.uv_layers["RockUV"])
        obj.data.materials.clear()
        obj.data.materials.append(final)
        obj.data.calc_loop_triangles()
        tris = len(obj.data.loop_triangles)
        assert tris <= 18000 and len(obj.data.uv_layers) == len(obj.data.materials) == 1
        for other in objects:
            other.select_set(other == obj)
        bpy.context.view_layer.objects.active = obj
        path = out / ("FrostStep_" + "ABC"[i] + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                                  export_yup=True, export_apply=True, export_tangents=True)
        parts.append({"name":obj.name,"triangles":tris,"dimensions":list(obj.dimensions),
                      "file":path.name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
    manifest = {"kind":"uninstalled frost-step import candidate","units":"studs; Blender Z up, export Y up",
                "landingSquare":4,"landingTop":4,"totalTriangles":sum(p["triangles"] for p in parts),
                "parts":parts,"maps":{k:{"file":Path(v.filepath_raw).name,"pixels":list(v.size),
                    "sha256":hashlib.sha256((out / Path(v.filepath_raw).name).read_bytes()).hexdigest()} for k,v in atlas.items()},
                "credits":"Original project geometry; existing MIT Terrain3D / ambientCG Rock023 maps; see assets/CREDITS.md",
                "collision":"decor only; exact existing 4x4 climb colliders retained; not yet integrated"}
    (out / "manifest.json").write_text(json.dumps(manifest,indent=2) + "\n")
    print("FROST_STEPS_READY", json.dumps(manifest))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1])

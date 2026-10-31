"""Headless-only UV/material pilot for recovered lower monument sections.

Blender --background --factory-startup --python tools/blender/fused_root_detail.py -- RECOVERY NEW_OUTPUT [name,name,...]
Keeps every vertex, triangle and custom normal. Re-bakes the existing macro colour and normal
onto a shared 2K atlas, adding restrained, world-aligned CC0 bark grain. Originals stay separate.
This prepares an import candidate; it does not install it or certify its appearance in Roblox.
"""
import gzip
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
from recovered_monument import build

ROOT = Path(__file__).resolve().parents[2]


def enum_set(obj, prop, value):
    options = {e.identifier for e in obj.bl_rna.properties[prop].enum_items}
    assert value in options, (prop, options)
    setattr(obj, prop, value)


def main(source, destination, parts="Titan_Canopy_13,Titan_Canopy_14,Titan_Canopy_15,Titan_Canopy_16"):
    assert bpy.app.background and not bpy.data.filepath, "run in a separate factory-startup process"
    source, out = Path(source).resolve(), Path(destination).resolve()
    if out.exists():
        raise FileExistsError("choose a new output directory; original copies are never overwritten")
    out.mkdir(parents=True)
    original = out / "original_geometry"
    build(source, original)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    with bpy.data.libraries.load(str(original / "RecoveredMonument.blend")) as (available, target):
        assert "RecoveredMonument" in available.collections
        target.collections = ["RecoveredMonument"]
    collection = target.collections[0]
    bpy.context.scene.collection.children.link(collection)
    wanted = set(parts.split(",")) if parts else {obj.name for obj in collection.objects}
    assert wanted <= {obj.name for obj in collection.objects}, "unknown recovered section"
    for obj in list(collection.objects):
        if obj.name not in wanted:
            bpy.data.objects.remove(obj, do_unlink=True)
    objects = list(collection.objects)
    manifest = json.loads((source / "manifest.json").read_text())
    sample = json.loads(gzip.decompress((source / manifest["parts"][0]["file"]).read_bytes()))
    snapshots = {}
    carrier_positions, carrier_faces, carrier_uvs, point_ids = [], [], [], {}
    for obj in objects:
        snapshots[obj.name] = ([tuple(v.co) for v in obj.data.vertices], [tuple(n.vector) for n in obj.data.corner_normals])
        obj.data.uv_layers[0].name = "SourceUV"
        obj.data.uv_layers.new(name="DetailUV", do_init=True)
        obj.data.uv_layers.active_index = 1
        # Reconnect only a temporary UV carrier across importer and part seams. The exported
        # objects keep their exact original vertices, faces and normals. Packing charts on
        # the separate chunks would create thousands of tiny islands and waste the atlas.
        vertex_ids = []
        for vertex in obj.data.vertices:
            point = obj.matrix_world @ vertex.co
            key = tuple(round(x, 4) for x in point)
            if key not in point_ids:
                point_ids[key] = len(carrier_positions)
                carrier_positions.append(tuple(point))
            vertex_ids.append(point_ids[key])
        for face in obj.data.polygons:
            carrier_faces.append([vertex_ids[i] for i in face.vertices])
            carrier_uvs.extend(tuple(obj.data.uv_layers[0].data[i].uv) for i in face.loop_indices)
        obj.select_set(False)
    carrier_mesh = bpy.data.meshes.new("RootUVCarrier")
    carrier_mesh.from_pydata(carrier_positions, [], carrier_faces)
    carrier_uv = carrier_mesh.uv_layers.new(name="UVMap")
    carrier_uv.data.foreach_set("uv", [x for uv in carrier_uvs for x in uv])
    carrier = bpy.data.objects.new("RootUVCarrier", carrier_mesh)
    bpy.context.scene.collection.objects.link(carrier)
    carrier.select_set(True)
    bpy.context.view_layer.objects.active = carrier
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=.004, merge_overlap=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    packed = [tuple(uv.uv) for uv in carrier_mesh.uv_layers[0].data]
    offset = 0
    for obj in objects:
        count = len(obj.data.loops)
        obj.data.uv_layers[1].data.foreach_set("uv", [x for uv in packed[offset:offset+count] for x in uv])
        offset += count
        obj.select_set(True)
    assert offset == len(packed)
    bpy.data.objects.remove(carrier, do_unlink=True)
    bpy.data.meshes.remove(carrier_mesh)
    bpy.context.view_layer.objects.active = objects[0]
    densities = []
    for obj in objects:
        for face in obj.data.polygons:
            a,b,c = [obj.data.vertices[i].co for i in face.vertices]
            u,v,w = [obj.data.uv_layers[1].data[i].uv for i in face.loop_indices]
            area = (b-a).cross(c-a).length*.5*1.5**2
            uvarea = abs((v.x-u.x)*(w.y-u.y)-(v.y-u.y)*(w.x-u.x))*.5
            if area>1e-9:
                densities.append((2048*math.sqrt(uvarea/area),area))
    densities.sort()
    threshold, accumulated, median = sum(a for _,a in densities)*.5,0,None
    for density,area in densities:
        accumulated += area
        if accumulated>=threshold:
            median=density
            break
    print("ATLAS_DENSITY_2048",median,flush=True)
    assert median>1.8,"atlas density failed to improve enough; do not bake or upload"
    anchor = bpy.data.objects.new("BarkDetailCoordinates", None)
    bpy.context.scene.collection.objects.link(anchor)
    material = bpy.data.materials.new("RootDetailBakeSource")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    output, shader = nodes.new("ShaderNodeOutputMaterial"), nodes.new("ShaderNodeBsdfPrincipled")
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    source_uv = nodes.new("ShaderNodeUVMap")
    source_uv.uv_map = "SourceUV"
    def image_node(path, colour=True):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(str(path), check_existing=True)
        if not colour:
            node.image.colorspace_settings.name = "Non-Color"
        links.new(source_uv.outputs["UV"], node.inputs["Vector"])
        return node
    def original_map(key, colour=True):
        asset = sample["maps"][key].split("//")[-1]
        return image_node(source / "maps" / (asset + ".png"), colour)
    colour = original_map("ColorMapContent")
    normal = original_map("NormalMapContent", False)
    roughness = original_map("RoughnessMapContent", False)
    coordinates = nodes.new("ShaderNodeTexCoord")
    coordinates.object = anchor
    scale = nodes.new("ShaderNodeVectorMath")
    enum_set(scale, "operation", "SCALE")
    scale.inputs[3].default_value = 1/64
    links.new(coordinates.outputs["Object"], scale.inputs[0])
    grain = image_node(ROOT / "assets/source/tex/bark_platanus_Diffuse.png")
    enum_set(grain, "projection", "BOX")
    grain.projection_blend = .25
    links.new(scale.outputs["Vector"], grain.inputs["Vector"])
    multiply = nodes.new("ShaderNodeMixRGB")
    enum_set(multiply, "blend_type", "MULTIPLY")
    multiply.inputs[0].default_value = .30
    links.new(colour.outputs["Color"], multiply.inputs[1])
    links.new(grain.outputs["Color"], multiply.inputs[2])
    links.new(multiply.outputs["Color"], shader.inputs["Base Color"])
    links.new(roughness.outputs["Color"], shader.inputs["Roughness"])
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.uv_map = "SourceUV"
    links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = .8
    bump.inputs["Strength"].default_value = .8
    links.new(grain.outputs["Color"], bump.inputs["Height"])
    links.new(normal_map.outputs["Normal"], bump.inputs["Normal"])
    links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    for obj in objects:
        obj.data.materials.clear()
        obj.data.materials.append(material)
        obj.data.uv_layers[1].active_render = True
    scene = bpy.context.scene
    try:
        scene.render.engine = "CYCLES"
    except TypeError as exc:
        raise RuntimeError("Cycles required for the separate texture bake") from exc
    scene.cycles.samples = 8
    scene.render.bake.use_clear = False
    scene.render.bake.margin = 8
    maps = out / "maps"
    maps.mkdir()
    baked = {}
    emission = nodes.new("ShaderNodeEmission")
    for kind, size, value in [("Color", 2048, multiply.outputs["Color"]),
                               ("Normal", 2048, None), ("Roughness", 1024, roughness.outputs["Color"])]:
        image = bpy.data.images.new("FusedRootDetail_" + kind, size, size, alpha=False)
        if kind != "Color":
            image.colorspace_settings.name = "Non-Color"
        target_image = nodes.new("ShaderNodeTexImage")
        target_image.image = image
        nodes.active = target_image
        if value:
            links.new(value, emission.inputs["Color"])
            links.new(emission.outputs["Emission"], output.inputs["Surface"])
        else:
            links.new(shader.outputs["BSDF"], output.inputs["Surface"])
        print("BAKING", kind, flush=True)
        bpy.ops.object.bake(type="NORMAL" if kind == "Normal" else "EMIT")
        image.filepath_raw = str(maps / ("FusedRootDetail_" + kind + ".png"))
        enum_set(image, "file_format", "PNG")
        image.save()
        image.pack()
        baked[kind] = image
        nodes.remove(target_image)
    export = bpy.data.materials.new("FusedRootDetail")
    export.use_nodes = True
    en, el = export.node_tree.nodes, export.node_tree.links
    bsdf = next(n for n in en if n.type == "BSDF_PRINCIPLED")
    for kind, image in baked.items():
        texture = en.new("ShaderNodeTexImage")
        texture.image = image
        if kind == "Normal":
            norm = en.new("ShaderNodeNormalMap")
            el.new(texture.outputs["Color"], norm.inputs["Color"])
            el.new(norm.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            el.new(texture.outputs["Color"], bsdf.inputs["Base Color" if kind == "Color" else "Roughness"])
    bsdf.inputs["Metallic"].default_value = 0
    report = {"kind": "uninstalled UV/material candidate; requires Studio import and visual validation",
              "density2048PixelsPerProductionStudMedian":median,
              "sourceRecovery": str(source), "mapReadbackLimit": 1024, "masterMaps": {"Color": 2048, "Normal": 2048, "Roughness": 1024},
              "detailSource": "Poly Haven bark_platanus, CC0, existing licensed project source", "parts": []}
    for obj in objects:
        original_positions, original_normals = snapshots[obj.name]
        position_delta = max((Vector(a)-v.co).length for a, v in zip(original_positions, obj.data.vertices))
        normal_delta = max((Vector(a)-n.vector).length for a, n in zip(original_normals, obj.data.corner_normals))
        assert position_delta == 0 and normal_delta < 1e-5
        assert len(obj.data.polygons) <= 18000
        obj.data.uv_layers.remove(obj.data.uv_layers["SourceUV"])
        obj.data.materials.clear()
        obj.data.materials.append(export)
        report["parts"].append({"name": obj.name, "triangles": len(obj.data.polygons),
                                "positionMaxDelta": position_delta, "normalMaxDelta": normal_delta})
    report["totalTriangles"] = sum(row["triangles"] for row in report["parts"])
    bpy.ops.export_scene.gltf(filepath=str(out / "FusedRootDetail.glb"), use_selection=True,
                              export_normals=True, export_tangents=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "FusedRootDetail.blend"))
    report["files"] = {str(p.relative_to(out)): hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in out.rglob("*") if p.is_file()}
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("READY", report["totalTriangles"], "triangles, geometry unchanged", flush=True)


if __name__ == "__main__":
    main(*sys.argv[sys.argv.index("--")+1:])

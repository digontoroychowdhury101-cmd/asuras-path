"""Static PBR glTF -> validated Roblox GLB + four exact 1024 PNG maps per material.
Blender -b --python-exit-code 1 -P tools/blender/process_asset.py -- input.gltf assets/build/name
Supports glTF image/separate-channel/factor graphs; rejects unsupported shaders and rigged inputs
instead of silently damaging them. Open scan borders are reported, not blindly filled.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake_socket import bake_socket


def triangle_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def clean_mesh(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-8, edges=list(bm.edges))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # Split edges shared by >2 faces; preserve deliberate scan/leaf boundaries and UV seams.
    tangled = [e for e in bm.edges if len(e.link_faces) > 2]
    if tangled:
        bmesh.ops.split_edges(bm, edges=tangled)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    report = {"split_nonmanifold_edges": len(tangled), "boundary_edges": sum(e.is_boundary for e in bm.edges)}
    bm.to_mesh(obj.data)
    bm.free()
    return report


def decimate(obj, cap):
    before = triangle_count(obj)
    if before <= cap:
        return before, before
    modifier = obj.modifiers.new("RobloxCap", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.use_collapse_triangulate = True
    ratio = cap / before * 0.99
    bpy.context.view_layer.objects.active = obj
    for _ in range(10):
        modifier.ratio = ratio
        bpy.context.view_layer.update()
        evaluated_obj = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated_obj.to_mesh()
        mesh.calc_loop_triangles()
        after = len(mesh.loop_triangles)
        evaluated_obj.to_mesh_clear()
        if after <= cap:
            break
        ratio *= cap / after * 0.97
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return before, triangle_count(obj)


def export_maps(material, directory, size):
    """Evaluate imported glTF maps without assuming that standalone scalar maps are ARM textures."""
    tree = material.node_tree
    bsdf = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if tree else None
    if bsdf is None:
        raise ValueError(f"{material.name}: requires a Principled material")
    cache = {}

    def image_pixels(image):
        if image.name not in cache:
            copy = image.copy()
            copy.scale(size, size)
            pixels = np.empty(size * size * 4, dtype=np.float32)
            copy.pixels.foreach_get(pixels)
            cache[image.name] = pixels.reshape(-1, 4)
            bpy.data.images.remove(copy)
        return cache[image.name].copy()

    def evaluate(socket, depth=0):
        if depth > 24:
            raise ValueError("Cyclic/deep shader graph")
        if not socket.is_linked:
            value = socket.default_value
            if isinstance(value, (float, int)):
                return np.full((size*size, 4), value, dtype=np.float32)
            values = list(value)
            return np.tile(values + [1.0] * (4-len(values)), (size*size, 1)).astype(np.float32)
        link = socket.links[0]
        node = link.from_node
        if node.type == "TEX_IMAGE" and node.image:
            result = image_pixels(node.image)
            if link.from_socket.name == "Alpha":
                result = np.repeat(result[:, 3:4], 4, axis=1)
            return result
        if node.type in ("NORMAL_MAP", "BUMP"):
            if node.type == "BUMP":
                raise ValueError(f"{material.name}: bake procedural bump to a tangent normal map first")
            return evaluate(node.inputs["Color"], depth+1)
        if node.type == "REROUTE":
            return evaluate(node.inputs[0], depth+1)
        if node.type in ("SEPARATE_COLOR", "SEPRGB"):
            channel = {"Red": 0, "Green": 1, "Blue": 2, "R": 0, "G": 1, "B": 2}[link.from_socket.name]
            result = evaluate(node.inputs[0], depth+1)
            return np.repeat(result[:, channel:channel+1], 4, axis=1)
        if node.type == "MATH":
            a, b = evaluate(node.inputs[0], depth+1), evaluate(node.inputs[1], depth+1)
            if node.operation == "MULTIPLY": return a*b
            if node.operation == "ADD": return a+b
            if node.operation == "SUBTRACT": return a-b
        if node.type == "MIX" and node.data_type == "RGBA" and node.blend_type == "MULTIPLY":
            a, b = evaluate(node.inputs[6], depth+1), evaluate(node.inputs[7], depth+1)
            f = evaluate(node.inputs[0], depth+1)
            return a*(1-f) + a*b*f
        raise ValueError(f"{material.name}: unsupported {node.type}; bake this shader before import")

    pixels = {}
    for socket_name, label in (("Base Color", "Color"), ("Normal", "Normal"), ("Roughness", "Roughness"), ("Metallic", "Metalness")):
        socket = bsdf.inputs[socket_name]
        if label == "Normal" and not socket.is_linked:
            data = np.tile([0.5, 0.5, 1, 1], (size*size, 1)).astype(np.float32)
        else:
            try:
                data = evaluate(socket)
            except ValueError:
                if label == "Normal": raise
                data = bake_socket(material, socket, size)
        if label == "Color":
            try:
                data[:, 3] = evaluate(bsdf.inputs["Alpha"])[:, 0]
            except ValueError:
                data[:, 3] = bake_socket(material, bsdf.inputs["Alpha"], size)[:, 0]
        else:
            data[:, 3] = 1
        pixels[label] = np.clip(data, 0, 1)
    paths, images = {}, {}
    safe = re.sub(r"[^A-Za-z0-9_-]", "_", material.name)
    for label, data in pixels.items():
        image = bpy.data.images.new(f"{safe}_{label}", size, size, alpha=True)
        image.colorspace_settings.name = "sRGB" if label == "Color" else "Non-Color"
        image.pixels.foreach_set(data.ravel())
        image.filepath_raw, image.file_format = str(directory / f"{safe}_{label}.png"), "PNG"
        image.save()
        paths[label], images[label] = Path(image.filepath_raw).name, image
    # Rebind the GLB to the resized PNGs, rather than shipping the untouched high-resolution maps.
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    shader = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    for label, image in images.items():
        texture = tree.nodes.new("ShaderNodeTexImage"); texture.image = image
        if label == "Normal":
            normal = tree.nodes.new("ShaderNodeNormalMap")
            tree.links.new(texture.outputs["Color"], normal.inputs["Color"])
            tree.links.new(normal.outputs["Normal"], shader.inputs["Normal"])
        else:
            socket = {"Color": "Base Color", "Roughness": "Roughness", "Metalness": "Metallic"}[label]
            tree.links.new(texture.outputs["Color"], shader.inputs[socket])
            if label == "Color" and pixels[label][:,3].min() < 0.999:
                tree.links.new(texture.outputs["Alpha"], shader.inputs["Alpha"])
                if hasattr(material, "surface_render_method"): material.surface_render_method = "DITHERED"
    return paths


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input"); parser.add_argument("out_dir")
    parser.add_argument("--max-tris", type=int, default=19500)
    parser.add_argument("--tex", type=int, default=1024)
    parser.add_argument("--join", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    if not 100 <= args.max_tris <= 19500 or not 16 <= args.tex <= 1024:
        parser.error("triangle cap must be 100..19500 and texture size 16..1024")
    source, directory = Path(args.input).resolve(), Path(args.out_dir).resolve()
    maps = directory / "maps"; maps.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    if any(o.type == "ARMATURE" for o in bpy.context.scene.objects):
        raise ValueError("Rigged asset: use a skin-preserving rig pipeline; static processing would destroy animation")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes: raise ValueError("Source contains no meshes")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
        if not obj.data.uv_layers: raise ValueError(f"{obj.name}: no UV coordinates")
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH": bpy.data.objects.remove(obj, do_unlink=True)
    if args.join:
        groups = {}
        for obj in meshes:
            groups.setdefault(tuple(m.name if m else "" for m in obj.data.materials), []).append(obj)
        meshes = []
        for group in groups.values():
            bpy.ops.object.select_all(action="DESELECT")
            for obj in group: obj.select_set(True)
            bpy.context.view_layer.objects.active = group[0]
            if len(group) > 1: bpy.ops.object.join()
            meshes.append(group[0])
    report = {"source": source.name, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "cap": args.max_tris, "texture_size": args.tex, "meshes": [], "maps": {}}
    for obj in meshes:
        topology = clean_mesh(obj)
        before, after = decimate(obj, args.max_tris)
        if not 0 < after <= args.max_tris: raise ValueError(f"{obj.name}: invalid triangle count {after}")
        if not obj.data.materials: raise ValueError(f"{obj.name}: missing PBR material")
        report["meshes"].append(dict(name=obj.name, tris_before=before, tris_after=after,
                                      size_m=[round(d, 4) for d in obj.dimensions], **topology))
    materials = {m for obj in meshes for m in obj.data.materials if m}
    for material in sorted(materials, key=lambda m: m.name):
        report["maps"][material.name] = export_maps(material, maps, args.tex)
    name = re.sub(r"_[1248]k$", "", source.stem)
    glb = directory / f"{name}.glb"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True,
                             export_animations=False, export_extras=False, export_image_format="AUTO")
    report.update(glb=glb.name, glb_mb=round(glb.stat().st_size/1e6, 3),
                  sha256=hashlib.sha256(glb.read_bytes()).hexdigest(),
                  total_triangles=sum(m["tris_after"] for m in report["meshes"]),
                  estimated_rgba_map_bytes=len(materials)*4*args.tex*args.tex*4)
    (directory/"report.json").write_text(json.dumps(report, indent=2)+"\n")
    print("PROCESS_ASSET_REPORT", json.dumps(report))


if __name__ == "__main__": main()

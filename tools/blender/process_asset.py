"""Headless Blender cleanup for Roblox-bound glTF assets.

Usage:
  Blender -b --python-exit-code 1 -P tools/blender/process_asset.py -- \
      <input.gltf> <out_dir> [--max-tris 19500] [--tex 1024] [--join]

Per mesh object it: applies transforms, removes loose geometry, decimates to the triangle cap
(Roblox MeshParts allow ~20k; we keep headroom), and resizes every PBR texture to <= --tex.
Outputs:
  <out_dir>/<name>.glb               importable with Studio's 3D Importer (PBR -> SurfaceAppearance)
  <out_dir>/maps/<material>_<map>.png  Color / Normal / Roughness / Metalness fallbacks
  <out_dir>/report.json              per-mesh triangle counts and bounds (metres)
"""
import argparse
import json
import sys
from pathlib import Path

import bpy
import bmesh


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("out_dir")
    parser.add_argument("--max-tris", type=int, default=19500)
    parser.add_argument("--tex", type=int, default=1024)
    parser.add_argument("--join", action="store_true", help="join all meshes sharing a material")
    return parser.parse_args(argv)


def triangle_count(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def clean_mesh(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def decimate(obj, cap):
    before = triangle_count(obj)
    if before <= cap:
        return before, before
    modifier = obj.modifiers.new("RobloxCap", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.use_collapse_triangulate = True
    # Collapse overshoots slightly on UV seams; iterate the ratio down until under the cap.
    ratio = cap / before
    bpy.context.view_layer.objects.active = obj
    for _ in range(6):
        modifier.ratio = ratio
        depsgraph = bpy.context.evaluated_depsgraph_get()
        evaluated = obj.evaluated_get(depsgraph).to_mesh()
        evaluated.calc_loop_triangles()
        after = len(evaluated.loop_triangles)
        obj.evaluated_get(depsgraph).to_mesh_clear()
        if after <= cap:
            break
        ratio *= cap / after * 0.98
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return before, triangle_count(obj)


def export_maps(material, out_maps, size):
    """Writes Roblox SurfaceAppearance-ready maps from the Principled BSDF inputs."""
    written = {}
    tree = material.node_tree
    if tree is None:
        return written
    principled = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if principled is None:
        return written

    def source_image(socket_name):
        socket = principled.inputs.get(socket_name)
        stack = [socket.links[0].from_node] if socket and socket.is_linked else []
        while stack:
            node = stack.pop()
            if node.type == "TEX_IMAGE" and node.image:
                return node.image
            for inp in node.inputs:
                if inp.is_linked:
                    stack.append(inp.links[0].from_node)
        return None

    for socket_name, label, channel in (
        ("Base Color", "Color", None),
        ("Normal", "Normal", None),
        ("Roughness", "Roughness", 1),  # glTF ARM: G = roughness
        ("Metallic", "Metalness", 2),   # glTF ARM: B = metalness
    ):
        image = source_image(socket_name)
        if image is None:
            continue
        if image.size[0] > size or image.size[1] > size:
            image.scale(size, size)
        pixels = list(image.pixels)
        out = bpy.data.images.new(f"{material.name}_{label}", image.size[0], image.size[1], alpha=False)
        # Colourspace must be set before writing pixels: changing it later regenerates the buffer.
        if label in ("Normal", "Roughness", "Metalness"):
            out.colorspace_settings.name = "Non-Color"
        if channel is not None:
            gray = pixels[channel::4]
            rgba = [0.0] * len(pixels)
            rgba[0::4] = gray
            rgba[1::4] = gray
            rgba[2::4] = gray
            rgba[3::4] = [1.0] * len(gray)
            out.pixels.foreach_set(rgba)
        else:
            out.pixels.foreach_set(pixels)
        path = out_maps / f"{material.name}_{label}.png"
        out.filepath_raw = str(path)
        out.file_format = "PNG"
        out.save()
        written[label] = path.name
    return written


def main():
    args = parse_args()
    source = Path(args.input).resolve()
    out_dir = Path(args.out_dir).resolve()
    maps_dir = out_dir / "maps"
    maps_dir.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for obj in [o for o in bpy.context.scene.objects if o.type not in ("MESH", "EMPTY")]:
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    if args.join:
        by_material = {}
        for obj in meshes:
            key = obj.active_material.name if obj.active_material else ""
            by_material.setdefault(key, []).append(obj)
        joined = []
        for group in by_material.values():
            bpy.ops.object.select_all(action="DESELECT")
            for obj in group:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = group[0]
            if len(group) > 1:
                bpy.ops.object.join()
            joined.append(bpy.context.view_layer.objects.active)
        meshes = joined

    report = {"source": source.name, "cap": args.max_tris, "meshes": [], "maps": {}}
    for obj in meshes:
        clean_mesh(obj)
        before, after = decimate(obj, args.max_tris)
        dims = [round(d, 3) for d in obj.dimensions]
        report["meshes"].append({"name": obj.name, "tris_before": before, "tris_after": after, "size_m": dims})
        if after > args.max_tris:
            raise SystemExit(f"{obj.name}: {after} tris still over cap {args.max_tris}")

    for material in bpy.data.materials:
        if material.users:
            report["maps"][material.name] = export_maps(material, maps_dir, args.tex)

    name = source.stem.replace("_2k", "")
    glb = out_dir / f"{name}.glb"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=True)
    report["glb"] = glb.name
    report["glb_mb"] = round(glb.stat().st_size / 1e6, 2)
    (out_dir / "report.json").write_text(json.dumps(report, indent=2))
    print("PROCESS_ASSET_REPORT " + json.dumps(report))


main()

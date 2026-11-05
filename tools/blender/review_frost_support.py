"""Validate a frost-support GLB round trip and render an offline material review.

Use a separate factory-startup Blender; these images are never gameplay evidence.
"""
from pathlib import Path
import importlib.util
import json
import math
import sys

import bpy
import bmesh
from mathutils import Vector

assert bpy.app.background and not bpy.data.filepath
folder = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
assert not (folder / "roundtrip.json").exists(), "preserve prior validation"
spec = importlib.util.spec_from_file_location("support", Path(__file__).with_name("frost_support.py"))
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(folder / "FrostSupport_A.glb"))
obj = next(o for o in bpy.context.selected_objects if o.type == "MESH")
bpy.context.view_layer.update()
mesh = obj.data
mesh.calc_loop_triangles()
assert len(mesh.loop_triangles) == 384
assert len(mesh.uv_layers) == len(mesh.materials) == 1
assert abs(obj.dimensions.z - support.HEIGHT) < 1e-5
assert abs(min(v.co.z for v in mesh.vertices)) < 1e-5
assert abs(max(v.co.z for v in mesh.vertices) - support.HEIGHT) < 1e-5
bm = bmesh.new()
bm.from_mesh(mesh)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
assert all(e.is_manifold for e in bm.edges), "export has an open boundary"
assert bm.calc_volume(signed=True) > 0, "winding faces inward"
volume = bm.calc_volume()
bm.free()
images = [n.image for n in mesh.materials[0].node_tree.nodes if n.type == "TEX_IMAGE"]
assert len(images) == 3 and all(i.size[0] >= 1024 and i.packed_file for i in images)
uv_name = mesh.uv_layers[0].name
variants = []
for height in (12.7, 14.2, 15.7):
    scale = (4.7 / obj.dimensions.x, 4.7 / obj.dimensions.y, height / support.HEIGHT)
    uv = support.uv_report(obj, uv_name, scale)
    assert uv["p95SideAnisotropy"] < 1.3
    variants.append({"height": height, "sideUV": uv})
report = {"kind": "offline GLB roundtrip; not uploaded, not Studio appearance",
          "object": obj.name, "triangles": len(mesh.loop_triangles), "dimensions": list(obj.dimensions),
          "uvSets": len(mesh.uv_layers), "materials": len(mesh.materials), "closedOutwardVolume": volume,
          "footZ": 0, "topZ": support.HEIGHT, "embeddedTextures": [list(i.size) for i in images],
          "runtimeVariants": variants}
(folder / "roundtrip.json").write_text(json.dumps(report, indent=2) + "\n")

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.render.resolution_x, scene.render.resolution_y = 1400, 950
scene.render.resolution_percentage = 100
scene.world.color = (.18, .18, .18)
# A wide sheet shows all four faces, including the source wrap seam.
for index, angle in enumerate((0, math.pi / 2, math.pi, math.pi * 1.5)):
    item = obj if index == 0 else obj.copy()
    if index:
        scene.collection.objects.link(item)
    item.location.x = (index - 1.5) * 6.5
    item.rotation_euler.z = angle + math.pi / 8
for pos, energy in [((0, -10, 18), 4500), ((-12, 5, 16), 3500)]:
    light = bpy.data.lights.new("OfflineReviewArea", "AREA")
    light.energy, light.size = energy, 12
    item = bpy.data.objects.new("OfflineReviewArea", light)
    scene.collection.objects.link(item)
    item.location = pos
    item.rotation_euler = (Vector((0, 0, 7)) - item.location).to_track_quat("-Z", "Y").to_euler()
camera = bpy.data.objects.new("OfflineReviewCamera", bpy.data.cameras.new("OfflineReviewCamera"))
scene.collection.objects.link(camera)
camera.location = (0, -34, 14)
camera.rotation_euler = (Vector((0, 0, 7.1)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type, camera.data.ortho_scale = "ORTHO", 31
scene.camera = camera
scene.render.filepath = str(folder / "offline-roundtrip.png")
bpy.ops.render.render(write_still=True)
print("ROUNDTRIP_PASSED", json.dumps(report))

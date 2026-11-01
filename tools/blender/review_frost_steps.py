"""Headless GLB round-trip and offline material preview; never game-appearance evidence."""
from pathlib import Path
import json
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

assert bpy.app.background and not bpy.data.filepath
folder = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
report = []
for i, name in enumerate("ABC"):
    bpy.ops.import_scene.gltf(filepath=str(folder / ("FrostStep_" + name + ".glb")))
    obj = next(o for o in bpy.context.selected_objects if o.type == "MESH")
    obj.data.calc_loop_triangles()
    assert len(obj.data.uv_layers) == len(obj.data.materials) == 1
    tree = BVHTree.FromPolygons([v.co for v in obj.data.vertices], [p.vertices[:] for p in obj.data.polygons])
    hits = []
    for x, y in [(-2, -2), (-2, 2), (2, -2), (2, 2), (0, 0)]:
        hit, normal, _, _ = tree.ray_cast(Vector((x, y, 8)), Vector((0, 0, -1)), 8)
        assert hit is not None and abs(hit.z - 4) < .00001 and normal.z > .999, (name, x, y, hit)
        hits.append({"x":x,"y":y,"surfaceZ":hit.z,"normalZ":normal.z})
    report.append({"name":obj.name,"triangles":len(obj.data.loop_triangles),"dimensions":list(obj.dimensions),
                   "uvSets":len(obj.data.uv_layers),"materials":len(obj.data.materials),"landingHits":hits})
    obj.location.x = (i - 1) * 7
scene = bpy.context.scene
try:
    scene.render.engine = "CYCLES"
except TypeError as error:
    raise RuntimeError("Cycles unavailable") from error
scene.cycles.samples = 24
scene.render.resolution_x, scene.render.resolution_y = 1440, 700
scene.render.resolution_percentage = 100
scene.world.color = (.2, .22, .25)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.04))
plane = bpy.context.object
mat = bpy.data.materials.new("NeutralReviewFloor")
mat.diffuse_color = (.12, .14, .12, 1)
plane.data.materials.append(mat)
for location, power, size in [((1, -6, 12), 1800, 8), ((-10, 3, 8), 1200, 8)]:
    light = bpy.data.lights.new("ReviewArea", "AREA")
    light.energy, light.shape, light.size = power, "DISK", size
    obj = bpy.data.objects.new("ReviewArea", light)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0, 0, 2)) - obj.location).to_track_quat("-Z", "Y").to_euler()
cam = bpy.data.objects.new("ReviewCamera", bpy.data.cameras.new("ReviewCamera"))
scene.collection.objects.link(cam)
cam.location = (11, -20, 11)
cam.rotation_euler = (Vector((0, 0, 2)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.type, cam.data.ortho_scale = "ORTHO", 25
scene.camera = cam
scene.render.filepath = str(folder / "offline-roundtrip.png")
if not (folder / "offline-roundtrip.png").exists():
    bpy.ops.render.render(write_still=True)
(folder / "roundtrip.json").write_text(json.dumps(report, indent=2) + "\n")
print("ROUNDTRIP_PASSED", json.dumps(report))

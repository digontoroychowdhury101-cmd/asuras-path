"""Headless turnarounds of the untouched sculpts, so every cut is judged against the source at a matched camera.

    Blender -b --factory-startup --python tools/blender/shen_import/render_source.py -- PHASE OUTDIR
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
phase, outdir = int(argv[0]), argv[1]
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../.."))
os.makedirs(outdir, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, f"assets/source/bosses/grandmaster_shen/Grandmaster-Shen-Phase-{phase}-PBR.glb"))
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
print("MESH", [(o.name, len(o.data.polygons), tuple(o.location), tuple(o.rotation_quaternion), tuple(o.scale)) for o in objs])
pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
cen, size = (lo + hi) / 2, hi - lo
print("BOUNDS blender", tuple(lo), tuple(hi))
scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x, scene.render.resolution_y = 1100, 1300
scene.render.film_transparent = False
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.62, 0.64, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
scene.world = world
for name, rot, energy in (("key", (55, 0, 35), 3.2), ("fill", (70, 0, -60), 1.2), ("rim", (120, 0, 170), 1.6)):
    light = bpy.data.lights.new(name, "SUN")
    light.energy = energy
    ob = bpy.data.objects.new(name, light)
    ob.rotation_euler = tuple(math.radians(a) for a in rot)
    scene.collection.objects.link(ob)
cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
cam.ortho_scale = max(size.x, size.y, size.z) * 1.08
camob = bpy.data.objects.new("cam", cam)
scene.collection.objects.link(camob)
scene.camera = camob
for label, deg in (("front", 0), ("q1", 45), ("right", 90), ("q2", 135), ("back", 180), ("q3", 225), ("left", 270), ("q4", 315)):
    a = math.radians(deg)
    # glTF +Z (facing the viewer) imports as Blender -Y
    d = Vector((math.sin(a), -math.cos(a), 0))
    camob.location = cen + d * (max(size) * 3)
    camob.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(outdir, f"p{phase}_{label}.png")
    bpy.ops.render.render(write_still=True)
print("DONE")

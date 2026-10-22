"""Renders a quick three-quarter preview of a processed GLB for visual QA.

Usage: Blender -b -P tools/blender/preview_asset.py -- <model.glb> <out.png>
"""
import math
import sys

import bpy
from mathutils import Vector

glb, out = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
center, radius = (lo + hi) / 2, (hi - lo).length / 2

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items} else "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 640, 640
if hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
    scene.eevee.taa_render_samples = 24
scene.render.filepath = out
world = bpy.data.worlds.new("Dusk")
world.color = (0.05, 0.05, 0.06)
scene.world = world

camera = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(camera)
scene.camera = camera
direction = Vector((math.sin(math.radians(35)), -math.cos(math.radians(35)), 0.35)).normalized()
camera.location = center + direction * radius * 2.6
camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = max(radius * 2.3, 0.01)  # entire bounding sphere fits; no cropped chains/pillars

for energy, angle, color in ((4.0, (50, 0, 40), (1.0, 0.86, 0.7)), (1.2, (60, 0, -140), (0.6, 0.7, 0.9))):
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy, sun.data.color = energy, color
    sun.rotation_euler = [math.radians(a) for a in angle]
    scene.collection.objects.link(sun)

bpy.ops.render.render(write_still=True)
print("PREVIEW_WRITTEN", out)

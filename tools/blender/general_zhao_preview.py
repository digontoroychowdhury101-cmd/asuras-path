"""Preview renders for General Zhao (run after tools/blender/general_zhao.py).

    Blender -b assets/source/bosses/general_zhao/GeneralZhao_Master.blend -P tools/blender/general_zhao_preview.py -- \
        <collection> <prefix> [--gray] [--engine EEVEE|WORKBENCH]

Orthographic front/side/back/three-quarter views on neutral grey, plus a combined sheet.
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/source/bosses/general_zhao/previews"
args = sys.argv[sys.argv.index("--") + 1:]
coll, prefix = args[0], args[1]
gray, engine = "--gray" in args, (args[args.index("--engine") + 1] if "--engine" in args else "EEVEE")
scene = bpy.context.scene
for c in scene.collection.children:
    c.hide_render = c.name != coll
objs = [o for o in bpy.data.collections[coll].objects if o.type == "MESH"]
for c in scene.collection.children:
    for o in c.objects: o.hide_render = c.name != coll
scene.render.resolution_x, scene.render.resolution_y = 900, 1100
scene.render.film_transparent = False
if engine == "WORKBENCH":
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"; scene.display.shading.color_type = "MATERIAL"
else:
    for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try: scene.render.engine = e; break
        except TypeError: continue
world = bpy.data.worlds.new("ZhaoPreview"); scene.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (.32, .36, .38, 1); bg.inputs["Strength"].default_value = .9
scene.view_settings.view_transform = "Standard"
for name, rot, energy, col in (("Key", (50, 0, 35), 3.2, (1, .97, .92)), ("Rim", (60, 0, 200), 2.0, (.75, .85, 1.0))):
    L = bpy.data.lights.new(name, "SUN"); L.energy = energy; L.color = col
    o = bpy.data.objects.new(name, L); o.rotation_euler = [math.radians(a) for a in rot]; scene.collection.objects.link(o)
lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
for o in objs:
    for c in o.bound_box:
        p = o.matrix_world @ Vector(c); lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
centre = (lo + hi) / 2
cam_data = bpy.data.cameras.new("Cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) * 1.04
cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
views = {"front": Vector((0, 1, 0)), "side": Vector((1, 0, 0)), "back": Vector((0, -1, 0)), "threequarter": Vector((.7, .7, .12)).normalized()}
# Roblox forward (-Z) is Blender +Y, so the front camera sits at +Y looking back toward -Y.
paths = []
for name, d in views.items():
    cam.location = centre + d * 30
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    path = OUT / f"{prefix}_{name}{'_gray' if gray else ''}.png"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    if gray:
        img = bpy.data.images.load(str(path)); px = np.array(img.pixels[:]).reshape(-1, 4)
        g = px[:, 0] * .2126 + px[:, 1] * .7152 + px[:, 2] * .0722
        px[:, 0] = px[:, 1] = px[:, 2] = g; img.pixels.foreach_set(px.astype(np.float32).ravel()); img.save()
    paths.append(path)
# combined sheet
imgs = [np.array(bpy.data.images.load(str(p)).pixels[:]).reshape(1100, 900, 4) for p in paths]
sheet = np.concatenate(imgs, axis=1).astype(np.float32)
out = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0]); out.pixels.foreach_set(sheet.ravel())
out.filepath_raw = str(OUT / f"{prefix}_sheet{'_gray' if gray else ''}.png"); out.file_format = "PNG"; out.save()
print("sheet", out.filepath_raw)

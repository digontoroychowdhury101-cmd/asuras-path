"""Blender contact sheets of the Iron Bull's baked clips on the production pieces (review only).

    Blender -b -P tools/animation/opening_cast/bull_preview.py -- OUT.png '[["Clip", [t, ...]], ...]' [az=35] [el=8] [ortho=11] [cols=8]

Reads work/opening_cast_bake/bull/<Clip>.json (export.py). Workbench with base colour only: this checks the motion, not the final look.
"""
import json
import math
import os
import sys

import bpy
import mathutils
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
out, spec = argv[0], json.loads(argv[1])
opts = dict(a.split("=") for a in argv[2:])
az, el, ortho, cols = float(opts.get("az", 35)), float(opts.get("el", 8)), float(opts.get("ortho", 11)), int(opts.get("cols", 8))
W, HT = int(opts.get("w", 260)), int(opts.get("h", 300))
BAKE = os.path.abspath("work/opening_cast_bake/bull")
info = json.load(open(os.path.join(BAKE, "pieces.json")))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("assets/build/opening_cast/bull/Bull_v1_Game.glb"))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_shadows = True
sc.display.shading.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = W, HT
sc.view_settings.exposure = 1.3
world = bpy.data.worlds.new("w")
sc.world = world
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
cam.ortho_scale = ortho
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
CONV = mathutils.Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
objs = [o for o in bpy.data.objects if o.type == "MESH"]
base = {o.name: o.matrix_world.copy() for o in objs}
bone = {o.name: info[o.name.split(".")[0]]["bone"] for o in objs}
# ground: a flat plane at sole height
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, -3.1924))
tiles = []
a, e = math.radians(az), math.radians(el)
d = mathutils.Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)))  # his front is +Y here; az + is toward his right
for clip, times in spec:
    data = json.load(open(os.path.join(BAKE, clip + ".json")))
    for t in times:
        fr = min(data["frames"], key=lambda f: abs(f["t"] - t))
        for o in objs:
            M = mathutils.Matrix(np.array(fr["parts"][bone[o.name]]).reshape(4, 4).tolist())
            o.matrix_world = CONV @ M @ CONV.inverted() @ base[o.name]
        bpy.context.view_layer.update()
        target = mathutils.Vector((0, 1.0, -0.5))
        co.location = target + d * 30
        co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        path = out + ".tile%03d.png" % len(tiles)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        tiles.append(path)
rows = int(math.ceil(len(tiles) / cols))
sheet = np.zeros((rows * HT, cols * W, 4), np.float32)
for i, p in enumerate(tiles):
    im = bpy.data.images.load(p)
    px = np.array(im.pixels[:], np.float32).reshape(HT, W, 4)
    r, c = i // cols, i % cols
    sheet[(rows - 1 - r) * HT:(rows - r) * HT, c * W:(c + 1) * W] = px
    bpy.data.images.remove(im)
    os.remove(p)
img = bpy.data.images.new("sheet", cols * W, rows * HT, alpha=True)
img.pixels = sheet.ravel().tolist()
img.filepath_raw, img.file_format = out, "PNG"
img.save()

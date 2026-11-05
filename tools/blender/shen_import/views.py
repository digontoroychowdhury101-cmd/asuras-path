"""Orthographic review views in rig (clip) space with a labelled grid, textured or coloured by piece name. Headless, nothing is saved.

    GLB=path.glb Blender -b --factory-startup --python tools/blender/shen_import/views.py -- TAG OUTDIR '[["front",0,tx,ty,tz,size],...]' [color|tex] [hide,names] [grid|nogrid]
Azimuth 0 looks at his front (rig -Z toward the camera); image right is his left. Rig (x, y, z) -> Blender (x, -z, y), as the glTF importer does.
"""
import colorsys
import hashlib
import json
import math
import os
import sys

import bpy
import mathutils

PALETTE = {"Head": (0.95, 0.25, 0.25), "UpperTorso": (0.2, 0.75, 0.2), "LowerTorso": (0.95, 0.9, 0.15), "RightUpperArm": (0.15, 0.3, 1), "RightLowerArm": (0.1, 0.85, 0.9), "RightHand": (1, 0.45, 0),
           "LeftUpperArm": (0.55, 0.15, 1), "LeftLowerArm": (0.1, 0.8, 0.55), "LeftHand": (1, 0.7, 0.3), "RightUpperLeg": (1, 0.3, 0.7), "RightLowerLeg": (0.5, 0.25, 0.1), "RightFoot": (0.85, 0.85, 0.85),
           "LeftUpperLeg": (0.8, 0.5, 0.8), "LeftLowerLeg": (0.3, 0.5, 0.3), "LeftFoot": (0.5, 0.5, 0.5), "HairBack": (0.98, 0.98, 0.75), "Beard": (0.75, 0.05, 0.45), "Beads": (0.05, 0.05, 0.05), "Bead1": (0.05, 0.05, 0.05), "Bead2": (0.25, 0.25, 0.25),
           "RightMantle": (0.05, 0.1, 0.45), "LeftMantle": (0.3, 0.05, 0.45), "RobeBack": (0.45, 0.65, 0.95), "RobeRight": (0.65, 0.95, 0.45), "RobeLeft": (0.95, 0.55, 0.55), "RobeInner": (0.95, 0.85, 0.65), "RobeFront": (0.0, 0.45, 0.45), "Bead3": (0.5, 0.5, 0.5),
           "LeftSleeve": (0.0, 0.35, 0.2), "RibbonRight": (1, 0, 0.2), "RibbonLeft": (0.6, 0, 0), "Weapon": (0.65, 0.5, 0.2), "Sock": (0, 0, 0)}
args = sys.argv[sys.argv.index("--") + 1:]
tag, out, views = args[0], args[1], json.loads(args[2])
mode = args[3] if len(args) > 3 else "color"
hide = set(args[4].split(",")) if len(args) > 4 and args[4] else set()
grid = (args[5] if len(args) > 5 else "grid") == "grid"
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(os.environ["GLB"]))
sc = bpy.context.scene
for o in list(bpy.data.objects):
    if o.type != "MESH":
        continue
    base = o.name.split(".")[0]
    if base in hide or base.rsplit("_", 1)[0] in hide:
        bpy.data.objects.remove(o)
        continue
    if mode == "color":
        key = base.rsplit("_", 1)[0] if base.rsplit("_", 1)[-1].isdigit() else base
        rgb = PALETTE.get(key)
        if rgb is None:
            h = int(hashlib.md5(key.encode()).hexdigest()[:6], 16) / 0xFFFFFF
            rgb = colorsys.hsv_to_rgb(h, 0.7, 0.8)
        m = bpy.data.materials.new(base)
        m.diffuse_color = (*rgb, 1)
        o.data.materials.clear()
        o.data.materials.append(m)
if mode == "color":
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = True
    sc.display.shading.show_backface_culling = False
else:
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = w
    for name, rot, energy in (("key", (55, 0, 35), 3.0), ("fill", (70, 0, -60), 1.2), ("rim", (120, 0, 170), 1.5)):
        li = bpy.data.lights.new(name, "SUN")
        li.energy = energy
        ob = bpy.data.objects.new(name, li)
        ob.rotation_euler = tuple(math.radians(a) for a in rot)
        sc.collection.objects.link(ob)
sc.render.resolution_x = sc.render.resolution_y = 1000
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
LN = bpy.data.materials.new("l")
LN.diffuse_color = (1, 1, 1, 1)
LN.use_nodes = True
pr = next(n for n in LN.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
pr.inputs["Base Color"].default_value = (1, 1, 1, 1)
pr.inputs["Emission Color"].default_value = (1, 1, 0.4, 1)
pr.inputs["Emission Strength"].default_value = 2
col = bpy.data.collections.new("g")
sc.collection.children.link(col)
for name, az, tx, ty, tz, sz in views:
    for k in list(col.objects):
        bpy.data.objects.remove(k)
    a = math.radians(az)
    d = mathutils.Vector((math.sin(a), math.cos(a), 0))
    up = mathutils.Vector((0, 0, 1))
    r = up.cross(d)
    t = mathutils.Vector((tx, -tz, ty))
    cam.ortho_scale = sz
    co.location = t + d * 12
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    if grid:
        step = 0.25 if sz <= 4 else 0.5
        n = int(sz / step / 2) + 2
        cenh, cenv = t.dot(r), t.z
        axis_x = abs(r.x) > 0.5
        P = t + d * 8
        th = sz * 0.0008

        def line(a_, b_):
            bpy.ops.mesh.primitive_cube_add(size=1)
            c = bpy.context.object
            c.location = (a_ + b_) / 2
            c.scale = (th, th, (b_ - a_).length)
            c.rotation_euler = (b_ - a_).to_track_quat("Z", "Y").to_euler()
            c.data.materials.append(LN)
            for cc in list(c.users_collection):
                cc.objects.unlink(c)
            col.objects.link(c)
        for i in range(-n, n + 1):
            v = round(cenv / step) * step + i * step
            line(P + r * (-sz) + up * (v - cenv), P + r * sz + up * (v - cenv))
            h = round(cenh / step) * step + i * step
            line(P + r * (h - cenh) + up * (-sz), P + r * (h - cenh) + up * sz)
            for txt, loc in ((f"{v:.2f}", P + r * (-sz * 0.49) + up * (v - cenv)), (("x" if axis_x else "z") + f"{(h * (r.x if axis_x else -r.y)):.2f}", P + r * (h - cenh) + up * (-sz * 0.48))):
                cu = bpy.data.curves.new("t", "FONT")
                cu.body = txt
                cu.size = sz * 0.017
                ob = bpy.data.objects.new("t", cu)
                ob.location = loc
                ob.rotation_euler = co.rotation_euler
                ob.data.materials.append(LN)
                col.objects.link(ob)
    sc.render.filepath = os.path.join(os.path.abspath(out), f"{tag}_{name}.png")
    bpy.ops.render.render(write_still=True)
print("VIEWS DONE", tag)

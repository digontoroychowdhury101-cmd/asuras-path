"""Turnaround renders of an armour set on the measured body, laid out like its concept sheet.

    Blender -b assets/source/armour/<set>/<set>.blend -P tools/blender/armour/review.py -- <set> [master|game] [tag] [ghost] [samples]

Writes assets/source/armour/<set>/review/<tag>_{front,left,back}.png and a contact sheet. The head is a neutral stand-in of the
measured Head size: in the game the player's own head and hat stay on.
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parent / "zhao_v2")]
import kit  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
SET, LEVEL, TAG = args[0], args[1] if len(args) > 1 else "master", args[2] if len(args) > 2 else "t"
GHOST = len(args) > 3 and args[3] == "ghost"
SAMPLES = int(args[4]) if len(args) > 4 else 48
ROOT = HERE.parents[2]
OUT = ROOT / "assets/source/armour" / SET / "review"
OUT.mkdir(parents=True, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "METAL"
    prefs.get_devices()
    for d in prefs.devices:
        d.use = True
    sc.cycles.device = "GPU"
except Exception:  # noqa: BLE001
    pass
sc.cycles.samples, sc.cycles.use_denoising = SAMPLES, True
sc.view_settings.view_transform, sc.view_settings.look = "AgX", "AgX - Medium High Contrast"
sc.render.film_transparent = False
wanted = "Master" if LEVEL == "master" else "Game"
for c in bpy.data.collections:
    if c.name in ("Master", "Game"):
        c.hide_render = c.name != wanted
        c.hide_viewport = c.name != wanted


def flat(name, col, rough=0.8, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Alpha"].default_value = alpha
    return m


def cube(name, size, loc, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name, o.scale = name, size
    o.data.materials.append(mat)
    return o


world = bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.20, 0.20, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
for name, loc, e, s, c in (("Key", (4.5, 6.5, 6.0), 620, 3.0, (1.0, 0.95, 0.88)), ("Fill", (-6.0, 5.0, 2.0), 170, 4.0, (0.85, 0.88, 1.0)),
                           ("Back", (-2.5, -6.5, 6.5), 520, 3.0, (0.95, 0.95, 1.0)), ("Back2", (5, -5.0, 2.0), 220, 3.0, (1.0, 0.92, 0.85))):
    li = bpy.data.lights.new(name, "AREA")
    li.energy, li.size, li.color = e, s, c
    ob = bpy.data.objects.new(name, li)
    sc.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 0.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
head_mat = flat("headmat", (0.12, 0.12, 0.12), 0.75)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=0.5, location=(0, 0, 1.586))
head = bpy.context.object
head.scale = (1.0, 1.0, 1.203)
bpy.ops.object.shade_smooth()
head.data.materials.append(head_mat)
ground = flat("floor", (0.20, 0.20, 0.20), 0.9)
cube("floor", (40, 40, 0.1), (0, 0, -3.05), ground)
if GHOST:
    g = flat("ghost", (0.1, 0.65, 0.95), 0.5, 1.0)
    for limb, (size, c) in kit.LIMBS.items():
        o = cube("ghost_" + limb, (size[0], size[2], size[1]), kit.PIVOT[limb], g)
        o.display_type = "WIRE"
        o.modifiers.new("w", "WIREFRAME").thickness = 0.018

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 85
sc.render.resolution_x, sc.render.resolution_y = 620, 1000
target = Vector((0, 0, -0.45))
paths = []
for name, d in (("front", (0.0, 1, 0.03)), ("left", (-1, 0.0, 0.03)), ("back", (0.0, -1, 0.03)), ("three", (-0.55, 0.85, 0.12))):
    v = Vector(d).normalized()
    cam.location = target + v * 17.5
    cam.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
    p = OUT / f"{TAG}_{name}.png"
    sc.render.filepath = str(p)
    bpy.ops.render.render(write_still=True)
    paths.append(p)
cam.data.lens = 85
sc.render.resolution_x, sc.render.resolution_y = 1000, 1000
v = Vector((-0.42, 1, 0.08)).normalized()
t = Vector((-0.18, 0, 0.22))
cam.location = t + v * 8.2
cam.rotation_euler = (-v).to_track_quat("-Z", "Y").to_euler()
sc.render.filepath = str(OUT / f"{TAG}_detail.png")
bpy.ops.render.render(write_still=True)
print("wrote", [str(p) for p in paths])

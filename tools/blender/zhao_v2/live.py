"""Iteration helpers for a live Blender session (MCP): load the v2 blend under a neutral studio light and
render explicit close-up shots. Not part of the build."""
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

BLEND = Path(__file__).resolve().parents[3] / "assets/source/bosses/general_zhao/v2_design/GeneralZhao_v2.blend"


def load():
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    sc = bpy.context.scene
    w = bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (.3, .33, .36, 1)
    bg.inputs[1].default_value = 0.8
    for name, r, e, c in (("Key", (50, 0, 35), 3.5, (1, .97, .92)), ("Rim", (60, 0, 200), 2.5, (.75, .85, 1))):
        L = bpy.data.lights.new(name, "SUN")
        L.energy, L.color = e, c
        o = bpy.data.objects.new(name, L)
        o.rotation_euler = [math.radians(a) for a in r]
        sc.collection.objects.link(o)
    sc.view_settings.view_transform = "AgX"


def shot(path, target, direction, dist, lens=85, res=(600, 600), game=False):
    sc = bpy.context.scene
    for o in sc.objects:
        if o.type == "MESH":
            o.hide_render = (not o.name.endswith("_Master")) != game
    cam = bpy.data.objects.get("ShotCam")
    if not cam:
        cam = bpy.data.objects.new("ShotCam", bpy.data.cameras.new("ShotCam"))
        sc.collection.objects.link(cam)
    cam.data.lens, cam.data.clip_start = lens, 0.01
    d, t = Vector(direction).normalized(), Vector(target)
    cam.location = t + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return path


def tile(paths, out, cols=None):
    imgs = [bpy.data.images.load(str(p), check_existing=False) for p in paths]
    arrs = [np.array(i.pixels[:]).reshape(i.size[1], i.size[0], 4) for i in imgs]
    h = max(a.shape[0] for a in arrs)
    arrs = [np.pad(a, ((0, h - a.shape[0]), (0, 0), (0, 0))) for a in arrs]
    cols = cols or len(arrs)
    rows = [np.concatenate(arrs[i:i + cols] + [np.zeros_like(arrs[0])] * (cols - len(arrs[i:i + cols])), axis=1)
            for i in range(0, len(arrs), cols)]
    sheet = np.concatenate(rows[::-1], axis=0).astype(np.float32)
    o = bpy.data.images.new("tile", sheet.shape[1], sheet.shape[0])
    o.pixels.foreach_set(sheet.ravel())
    o.filepath_raw, o.file_format = str(out), "PNG"
    o.save()
    for i in imgs:
        bpy.data.images.remove(i)
    return out


def studio(samples=48, engine="CYCLES"):
    """Three-point area-light studio on a dark graded backdrop, Cycles GPU with denoising."""
    sc = bpy.context.scene
    for o in [o for o in sc.objects if o.type == "LIGHT"]:
        bpy.data.objects.remove(o)
    sc.render.engine = engine
    if engine == "CYCLES":
        try:
            prefs = bpy.context.preferences.addons["cycles"].preferences
            prefs.compute_device_type = "METAL"
            prefs.get_devices()
            for d in prefs.devices:
                d.use = True
            sc.cycles.device = "GPU"
        except Exception:  # noqa: BLE001
            pass
        sc.cycles.samples = samples
        sc.cycles.use_denoising = True
    w = sc.world
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (.16, .18, .2, 1)
    bg.inputs[1].default_value = 0.35
    for name, loc, energy, size, col in (("Key", (4.5, 6.5, 6.0), 900, 3.0, (1.0, .93, .85)),
                                         ("Fill", (-6.0, 4.0, 2.0), 220, 4.0, (.75, .82, 1.0)),
                                         ("Rim", (-2.5, -6.5, 6.5), 900, 2.0, (.8, .9, 1.0)),
                                         ("Rim2", (4.0, -5.0, 3.0), 400, 2.0, (1.0, .9, .8))):
        L = bpy.data.lights.new(name, "AREA")
        L.energy, L.size, L.color = energy, size, col
        o = bpy.data.objects.new(name, L)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 0.6)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(o)
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"

"""Render an opening-cast clip on the character's production game mesh (posed rigidly per R15 part).

    blender -b assets/source/opening_cast/monk/Monk_v1.blend -P tools/animation/opening_cast/preview_blender.py -- monk Monk_L1 [Monk_L2 ...]

Reads work/opening_cast_bake/<key>/<Clip>.json (export.py) and writes outputs/opening-cast/<key>/<Clip>.png: a strip of
frames (windup, contact, recovery) seen from the front three-quarter, with the contact frame marked. Each mesh piece
moves exactly as its R15 part does in Roblox: world(part, t) * rest(part)^-1 * the piece's rest placement.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(ROOT / "tools/animation/general_zhao"))
import rig  # noqa: E402

REST = rig.fk({})
P = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], float)  # Roblox (x, y, z) -> Blender (x, -z, y)


def to_blender(M):
    out = np.eye(4)
    out[:3, :3] = P @ M[:3, :3] @ P.T
    out[:3, 3] = P @ M[:3, 3]
    return Matrix(out.tolist())


def setup(name):
    sc = bpy.context.scene
    for o in sc.objects:
        if o.type == "MESH":
            o.hide_render = o.name.endswith("_Master")
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
                prefs.get_devices()
                if any(d.type == kind for d in prefs.devices):
                    for d in prefs.devices:
                        d.use = d.type == kind
                    sc.cycles.device = "GPU"
                    break
            except TypeError:
                continue
    except Exception:  # noqa: BLE001
        pass
    sc.cycles.samples, sc.cycles.use_denoising = 24, True
    w = bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value, bg.inputs[1].default_value = (0.13, 0.12, 0.11, 1), 0.5
    for nm, loc, e, size in (("Key", (4, 6, 6), 900, 3), ("Fill", (-6, 3, 2), 250, 4), ("Rim", (-2, -6, 6), 800, 2)):
        L = bpy.data.lights.new(nm, "AREA")
        L.energy, L.size = e, size
        o = bpy.data.objects.new(nm, L)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(o)
    me = bpy.data.meshes.new("Floor")
    me.from_pydata([(-8, -8, -3.19), (8, -8, -3.19), (8, 8, -3.19), (-8, 8, -3.19)], [], [(0, 1, 2, 3)])
    fl = bpy.data.objects.new("Floor", me)
    sc.collection.objects.link(fl)
    m = bpy.data.materials.new("FloorM")
    m.use_nodes = True
    next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.05, 0.045, 0.04, 1)
    me.materials.append(m)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.data.lens = 50
    d = Vector((0.75, 1.0, 0.18)).normalized()
    t = Vector((0, 0.6, -0.9))
    cam.location = t + d * 12.5
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = 380, 520
    sc.view_settings.view_transform = "AgX"
    return [o for o in bpy.data.collections[f"{name}_Game"].all_objects if o.type == "MESH"]


def render_clip(key, clip, objs, picks=7):
    data = json.loads((ROOT / "work/opening_cast_bake" / key / f"{clip}.json").read_text())
    frames = data["frames"]
    contact = data["contacts"][0] if data["contacts"] else None
    n = len(frames)
    idx = sorted({int(round(i * (n - 1) / (picks - 1))) for i in range(picks)})
    if contact is not None:
        c = int(np.argmin([abs(f["t"] - contact) for f in frames]))
        idx = sorted(set(idx) | {c})
    rest_mw = {o.name: o.matrix_world.copy() for o in objs}
    out_dir = ROOT / "outputs/opening-cast" / key / "frames"
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for i in idx:
        f = frames[i]
        for o in objs:
            part = o["AsuraBone"]
            W = np.array(f["parts"][part]).reshape(4, 4)
            o.matrix_world = to_blender(W @ np.linalg.inv(REST[part])) @ rest_mw[o.name]
        p = out_dir / f"{clip}_{i:03d}.png"
        bpy.context.scene.render.filepath = str(p)
        bpy.ops.render.render(write_still=True)
        paths.append((p, contact is not None and abs(f["t"] - contact) < 1 / 120, f["t"]))
    for o in objs:
        o.matrix_world = rest_mw[o.name]
    imgs = [bpy.data.images.load(str(p)) for p, _, _ in paths]
    arrs = []
    for img, (_, hit, _) in zip(imgs, paths):
        a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        if hit:  # ember bar under the contact frame
            a[:10, :, :3] = (1.0, 0.35, 0.21)
        arrs.append(a)
    sheet = np.concatenate(arrs, axis=1)
    o = bpy.data.images.new(clip, sheet.shape[1], sheet.shape[0])
    o.pixels.foreach_set(sheet.ravel())
    dst = ROOT / "outputs/opening-cast" / key / f"{clip}.png"
    o.filepath_raw, o.file_format = str(dst), "PNG"
    o.save()
    print("wrote", dst)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    key, clips = args[0], args[1:]
    name = {"monk": "Monk"}[key]
    objs = setup(name)
    for clip in clips:
        render_clip(key, clip, objs)

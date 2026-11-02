"""Close-up look renders of an opening-cast character for art review.

    blender -b assets/source/opening_cast/monk/Monk_v1.blend -P tools/blender/opening_cast/review.py -- monk [game] [shot ...]

Renders the master (or with `game`, the baked game mesh) under a key/fill/rim rig into
outputs/opening-cast/<key>/review_<shot>_<master|game>.png. Shots: face_front, face_34, face_side, body_front, body_34, hand_34.
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
NAMES = {"monk": "Monk", "swordsman": "Swordsman", "warden": "Warden"}
# shot: target, direction from target, distance, lens
SHOTS = {
    "face_front": ((0, 0, 1.5), (0, 1, 0.05), 3.2, 85),
    "face_34": ((0, 0, 1.5), (0.8, 0.9, 0.1), 3.2, 85),
    "face_side": ((0, 0, 1.5), (1, 0.05, 0.05), 3.2, 85),
    "body_front": ((0, 0, -0.75), (0, 1, 0.1), 13, 50),
    "body_34": ((0, 0, -0.75), (0.75, 1, 0.15), 13, 50),
    "hand_34": ((1.0, 0, -0.95), (0.9, 0.8, 0.15), 3.6, 85),   # the right fist and a weapon's grip
    "body_side": ((0, 0, -0.5), (1, 0.03, 0.1), 13, 50),
    "body_back": ((0, 0, -0.5), (-0.6, -1, 0.15), 13, 50),
}


def setup(name, game):
    sc = bpy.context.scene
    for o in sc.objects:
        if o.type == "MESH":
            master = o.users_collection[0].name == f"{name}_Master"
            o.hide_render = master == game
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
    sc.cycles.samples, sc.cycles.use_denoising = 64, True
    w = bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value, bg.inputs[1].default_value = (0.13, 0.12, 0.11, 1), 0.4
    for nm, loc, e, size in (("Key", (3, 5, 4), 700, 2.5), ("Fill", (-5, 3, 1.5), 160, 4), ("Rim", (-2, -5, 4), 650, 2)):
        L = bpy.data.lights.new(nm, "AREA")
        L.energy, L.size = e, size
        o = bpy.data.objects.new(nm, L)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 1)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(o)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.resolution_x = sc.render.resolution_y = 600
    sc.view_settings.view_transform = "AgX"
    return cam


def render(key, game, shots):
    cam = setup(NAMES[key], game)
    out = ROOT / "outputs/opening-cast" / key
    out.mkdir(parents=True, exist_ok=True)
    for shot in shots:
        t, d, dist, lens = SHOTS[shot]
        d = Vector(d).normalized()   # Blender +Y is the character's front (Roblox -Z)
        cam.location = Vector(t) + d * dist
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        p = out / f"review_{shot}_{'game' if game else 'master'}.png"
        bpy.context.scene.render.filepath = str(p)
        bpy.ops.render.render(write_still=True)
        print("wrote", p)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    game = "game" in args
    shots = [a for a in args[1:] if a in SHOTS] or ["face_front", "face_34"]
    render(args[0], game, shots)

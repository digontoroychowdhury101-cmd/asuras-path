"""Cut reel_proxy.py's frames into one captioned MP4: front view left, side view right, one title card per clip.

    Blender -b --factory-startup --python tools/blender/shen_import/reel_encode.py -- FRAMEDIR OUT.mp4 [QUALITY]
QUALITY is Blender's constant rate factor, default MEDIUM (keeps the full reel under GitHub's 100 MB).
"""
import json
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
frames, out = args[:2]
quality = args[2] if len(args) > 2 else "MEDIUM"
log = json.load(open(os.path.join(frames, "frames.json")))
W, H, FPS = 1920, 540, 30
sc = bpy.context.scene
sc.render.resolution_x, sc.render.resolution_y, sc.render.fps = W, H, FPS
sc.view_settings.view_transform = "Standard"   # the frames are already display colour
seq = sc.sequence_editor_create()
strips = seq.strips if hasattr(seq, "strips") else seq.sequences
names = sorted(n for n in os.listdir(os.path.join(frames, "front")) if n.endswith(".png"))
total = len(names)


def images(view, channel, offset):
    s = strips.new_image(name=view, filepath=os.path.join(frames, view, names[0]), channel=channel, frame_start=1)
    for n in names[1:]:
        s.elements.append(n)
    s.transform.offset_x = offset
    s.blend_type = "ALPHA_OVER"
    return s


images("front", 1, -W // 4)   # strips sit centred, so shift each half a frame-quarter
images("side", 2, W // 4)


def text(label, start, end, channel, y, size, colour=(1, 1, 1, 1), x=0.012):
    t = strips.new_effect(name=label[:60], type="TEXT", channel=channel, frame_start=start, length=end - start + 1)
    t.text = label
    t.font_size = size
    t.color = colour
    t.use_shadow = True
    t.location = (x, y)
    t.anchor_x, t.anchor_y = "LEFT", "TOP"
    return t


text("FRONT (combat camera)", 1, total, 3, 0.985, 18, (0.9, 0.9, 0.9, 1))
text("SIDE", 1, total, 4, 0.985, 18, (0.9, 0.9, 0.9, 1), x=0.512)
for n, e in enumerate(log):
    a, b = e["first"] + 1, e["last"] + 1
    step = e.get("step", 1)
    head = "%d/%d   P%d  %s   %.2fs%s" % (n + 1, len(log), e["phase"], e["clip"], e["length"], "  loop" if e["loop"] else "")
    text(head, a, b, 5, 0.93, 30)
    if e["problems"]:
        text("validator FIX: " + "; ".join(e["problems"]), a, b, 6, 0.86, 20, (1, 0.45, 0.35, 1))
    # the clip itself, as opposed to the idle blending in and out
    ca, cb = a + e["clip_first"] // step, min(a + e["clip_last"] // step, b)
    text("▶ playing", ca, cb, 7, 0.08, 22, (0.5, 1, 0.55, 1))
    if ca > a:
        text("idle blend", a, ca - 1, 8, 0.08, 22, (0.7, 0.7, 0.7, 1))
    if cb < b:
        text("idle blend", cb + 1, b, 8, 0.08, 22, (0.7, 0.7, 0.7, 1))
sc.frame_start, sc.frame_end = 1, total
sc.render.image_settings.media_type = "VIDEO"
sc.render.image_settings.file_format = "FFMPEG"
sc.render.ffmpeg.format = "MPEG4"
sc.render.ffmpeg.codec = "H264"
sc.render.ffmpeg.constant_rate_factor = quality
sc.render.use_sequencer = True
sc.render.filepath = out
bpy.ops.render.render(animation=True)
print("ENCODED", out, total)

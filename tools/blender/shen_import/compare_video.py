"""Before/after comparison video from review.py frame folders: one row per version, one column per camera, labelled, with Blender's own ffmpeg.

    Blender -b --factory-startup --python tools/blender/shen_import/compare_video.py -- OUT.mp4 FPS TITLE ROWLABEL=dir1,dir2,... [ROWLABEL=dir...]

Every folder holds f_<n>.png frames of the same shot (same count, same size). FPS 30 is normal speed; 15 plays the same frames at 0.5x.
Column labels come from the folder names' last _part (side, front, combat). Blender preview evidence only: not Studio, no VFX or sound.
"""
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
out, fps, title = args[0], int(args[1]), args[2]
rows = []
for spec in args[3:]:
    label, dirs = spec.split("=", 1)
    rows.append((label, dirs.split(",")))
first = rows[0][1][0]
names = sorted(n for n in os.listdir(first) if n.endswith(".png"))
img = bpy.data.images.load(os.path.join(first, names[0]))
w, h = img.size
cols = max(len(d) for _, d in rows)
band = 34
sc = bpy.context.scene
sc.render.resolution_x, sc.render.resolution_y = w * cols, h * len(rows) + band
sc.render.resolution_percentage = 100
sc.render.fps = fps
seq = sc.sequence_editor_create()
strips = seq.strips if hasattr(seq, "strips") else seq.sequences
channel = 1


def text_strip(name, ch, length):
    try:
        return strips.new_effect(name=name, type="TEXT", channel=ch, frame_start=1, length=length)
    except TypeError:
        return strips.new_effect(name=name, type="TEXT", channel=ch, frame_start=1, frame_end=length + 1)


for r, (label, dirs) in enumerate(rows):
    for c, d in enumerate(dirs):
        frames = sorted(n for n in os.listdir(d) if n.endswith(".png"))
        try:
            s = strips.new_image(name="%d_%d" % (r, c), filepath=os.path.join(d, frames[0]), channel=channel, frame_start=1, fit_method="ORIGINAL")
        except TypeError:
            s = strips.new_image(name="%d_%d" % (r, c), filepath=os.path.join(d, frames[0]), channel=channel, frame_start=1)
            s.fit_method = "ORIGINAL"
        for n in frames[1:]:
            s.elements.append(n)
        channel += 1
        s.transform.offset_x = (c - (cols - 1) / 2) * w
        s.transform.offset_y = ((len(rows) - 1) / 2 - r) * h - band / 2
        t = text_strip("t%d_%d" % (r, c), channel, len(frames))
        channel += 1
        t.text = "%s - %s" % (label, os.path.basename(d.rstrip("/")).split("_")[-1])
        t.font_size = 22
        t.use_shadow = True
        t.location = ((c + 0.02) / cols, 1 - (r * h + band + 6) / sc.render.resolution_y)
        t.anchor_y = "TOP"
        t.anchor_x = "LEFT"
n = len(names)
head = text_strip("title", channel, n)
speed = "normal speed" if fps == 30 else "%.2fx speed" % (fps / 30)
head.text = "%s  |  %s" % (title, speed) + ("  |  fixed cameras, Blender skinned-mesh preview, root travelling" if cols > 1 else "")
head.font_size = 20 if cols > 1 else 16
head.location = (0.01, 1 - 6 / sc.render.resolution_y)
head.anchor_y = "TOP"
head.anchor_x = "LEFT"
sc.frame_start, sc.frame_end = 1, n
sc.render.image_settings.media_type = "VIDEO"
sc.render.image_settings.file_format = "FFMPEG"
sc.render.ffmpeg.format = "MPEG4"
sc.render.ffmpeg.codec = "H264"
sc.render.ffmpeg.constant_rate_factor = "HIGH"
sc.render.use_sequencer = True
sc.render.filepath = out
bpy.ops.render.render(animation=True)
print("ENCODED", out, n)

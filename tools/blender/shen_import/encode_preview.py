"""Encode preview.py's frames to an MP4 with Blender's own ffmpeg (this machine has no ffmpeg).

    Blender -b --factory-startup --python tools/blender/shen_import/encode_preview.py -- FRAMES OUT.mp4
"""
import os
import sys

import bpy

frames, out = sys.argv[sys.argv.index("--") + 1:][:2]
names = sorted(n for n in os.listdir(frames) if n.endswith(".png"))
sc = bpy.context.scene
sc.render.resolution_x, sc.render.resolution_y, sc.render.fps = 854, 480, 30
seq = sc.sequence_editor_create()
strips = seq.strips if hasattr(seq, "strips") else seq.sequences
strip = strips.new_image(name="f", filepath=os.path.join(frames, names[0]), channel=1, frame_start=1)
for name in names[1:]:
    strip.elements.append(name)
sc.frame_start, sc.frame_end = 1, len(names)
sc.render.image_settings.media_type = "VIDEO"
sc.render.image_settings.file_format = "FFMPEG"
sc.render.ffmpeg.format = "MPEG4"
sc.render.ffmpeg.codec = "H264"
sc.render.ffmpeg.constant_rate_factor = "HIGH"
sc.render.use_sequencer = True
sc.render.filepath = out
bpy.ops.render.render(animation=True)
print("ENCODED", out, len(names))

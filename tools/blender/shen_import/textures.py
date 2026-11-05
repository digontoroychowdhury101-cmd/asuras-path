"""Decode a sculpt's embedded maps to numpy for the segmenter and author-time masks. Unchanged pixels; the GLB's own PNGs stay what is exported.

    Blender -b --factory-startup --python tools/blender/shen_import/textures.py
Writes work/shen_import/tex_p<n>_{color,normal,orm}.npy (uint8 H x W x 3, row 0 = top of image, as glTF UV v=0).
"""
import io
import json
import os
import struct
import tempfile

import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../.."))
OUT = os.path.join(ROOT, "work/shen_import")
KIND = {"texture_diffuse": "color", "texture_normal": "normal", "texture_metallic-texture_roughness": "orm"}
for phase in (1, 2):
    with open(os.path.join(ROOT, f"assets/source/bosses/grandmaster_shen/Grandmaster-Shen-Phase-{phase}-PBR.glb"), "rb") as f:
        f.read(12)
        n, _ = struct.unpack("<II", f.read(8))
        j = json.loads(f.read(n))
        n, _ = struct.unpack("<II", f.read(8))
        blob = f.read(n)
    for im in j["images"]:
        bv = j["bufferViews"][im["bufferView"]]
        data = blob[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as t:
            t.write(data)
        img = bpy.data.images.load(t.name)
        img.colorspace_settings.name = "Non-Color"
        w, h = img.size
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        arr = (px.reshape(h, w, 4)[::-1, :, :3] * 255 + 0.5).astype(np.uint8)
        np.save(os.path.join(OUT, f"tex_p{phase}_{KIND[im['name']]}.npy"), arr)
        print("TEX", phase, im["name"], arr.shape, arr.mean((0, 1)).round(1))
        bpy.data.images.remove(img)
        os.unlink(t.name)

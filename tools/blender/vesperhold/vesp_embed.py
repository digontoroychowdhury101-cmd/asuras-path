"""Embed the loose PBR maps into Vesperhold GLBs so the Roblox 3D importer builds a SurfaceAppearance per material (no Blender needed).

Per material (Vesp_*): Color -> JPEG q90 (PNG RGBA only when the map has real alpha, e.g. Vesp_Water, alphaMode BLEND),
Roughness+Metal -> one glTF metallicRoughness image (G = roughness, B = metalness; metal is black for non-metals), Normal -> PNG (OpenGL, 2048 kept).
Stdlib + numpy + PIL. Usage: embed(src_glb, dst_glb, maps_dir) -> bytes written. Texture encodes are cached per maps_dir.
"""
import io
import json
import os
import struct
from pathlib import Path

import numpy as np
from PIL import Image

_CACHE = {}


def _load(path):
    return Image.open(path)


def _encode(maps, mat):
    key = (str(maps), mat)
    if key in _CACHE:
        return _CACHE[key]
    col = _load(maps / f"{mat}_Color.png")
    alpha = col.mode == "RGBA" and np.asarray(col)[..., 3].min() < 250
    buf = io.BytesIO()
    if alpha:
        col.save(buf, "PNG", optimize=True)
        cmime = "image/png"
    else:
        col.convert("RGB").save(buf, "JPEG", quality=90, optimize=True)
        cmime = "image/jpeg"
    color = (buf.getvalue(), cmime)
    rough = np.asarray(_load(maps / f"{mat}_Roughness.png").convert("L"))
    metal = np.asarray(_load(maps / f"{mat}_Metal.png").convert("L"))
    orm = np.stack([np.full_like(rough, 255), rough, metal], -1)
    buf = io.BytesIO()
    Image.fromarray(orm, "RGB").save(buf, "JPEG", quality=90, optimize=True, subsampling=0)  # 4:4:4 so metal/rough edges stay clean
    rm = (buf.getvalue(), "image/jpeg")
    buf = io.BytesIO()
    if os.environ.get("VESP_NORMAL") == "jpeg":  # size fix: 6 MB instead of 11 MB per 2048 normal map (lossy; default is PNG)
        _load(maps / f"{mat}_Normal.png").convert("RGB").save(buf, "JPEG", quality=92, subsampling=0, optimize=True)
        nrm = (buf.getvalue(), "image/jpeg")
    else:
        _load(maps / f"{mat}_Normal.png").convert("RGB").save(buf, "PNG", optimize=True, compress_level=9)
        nrm = (buf.getvalue(), "image/png")
    _CACHE[key] = dict(color=color, rm=rm, normal=nrm, alpha=alpha, metal_max=int(metal.max()))
    return _CACHE[key]


def embed(src, dst, maps):
    maps = Path(maps)
    data = Path(src).read_bytes()
    magic, ver, _ = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and ver == 2, src
    jlen, jtype = struct.unpack_from("<I4s", data, 12)
    g = json.loads(data[20:20 + jlen])
    boff = 20 + jlen
    blen, btype = struct.unpack_from("<I4s", data, boff)
    assert btype == b"BIN\x00", src
    binary = bytearray(data[boff + 8:boff + 8 + blen])
    g.setdefault("images", [])
    g.setdefault("textures", [])
    g.setdefault("bufferViews", [])
    g["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]

    def add_image(payload, mime):
        while len(binary) % 4:
            binary.append(0)
        g["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(payload)})
        binary.extend(payload)
        g["images"].append({"bufferView": len(g["bufferViews"]) - 1, "mimeType": mime})
        g["textures"].append({"sampler": 0, "source": len(g["images"]) - 1})
        return len(g["textures"]) - 1

    done = {}
    for m in g["materials"]:
        name = m["name"].split(".")[0]
        if not (maps / f"{name}_Color.png").exists():
            continue
        if name not in done:
            e = _encode(maps, name)
            done[name] = (add_image(*e["color"]), add_image(*e["rm"]), add_image(*e["normal"]), e["alpha"])
        c, rm, n, alpha = done[name]
        pbr = m.setdefault("pbrMetallicRoughness", {})
        pbr["baseColorTexture"] = {"index": c, "texCoord": 0}
        pbr["metallicRoughnessTexture"] = {"index": rm, "texCoord": 0}
        pbr["baseColorFactor"] = [1.0, 1.0, 1.0, 1.0]
        pbr["metallicFactor"] = 1.0
        pbr["roughnessFactor"] = 1.0
        m["normalTexture"] = {"index": n, "texCoord": 0}
        if alpha:
            m["alphaMode"] = "BLEND"
    g["buffers"][0]["byteLength"] = len(binary)
    while len(binary) % 4:
        binary.append(0)
    g["buffers"][0]["byteLength"] = len(binary)
    j = json.dumps(g, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(j) + 8 + len(binary))
    out += struct.pack("<I4s", len(j), b"JSON") + j + struct.pack("<I4s", len(binary), b"BIN\x00") + bytes(binary)
    Path(dst).write_bytes(out)
    return len(out)

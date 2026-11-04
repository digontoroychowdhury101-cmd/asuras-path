"""Read and write the Iron Bull's supplied GLB with numpy alone, so positions, split normals, UVs and the three maps pass through exactly."""
import json
import struct

import numpy as np


class Glb:
    def __init__(self, path):
        with open(path, "rb") as f:
            _, _, _ = struct.unpack("<III", f.read(12))
            n, _ = struct.unpack("<II", f.read(8))
            self.json = json.loads(f.read(n))
            n, _ = struct.unpack("<II", f.read(8))
            self.bin = f.read(n)
        prim = self.json["meshes"][0]["primitives"][0]
        self.pos = self.acc(prim["attributes"]["POSITION"]).astype(np.float64)
        self.nrm = self.acc(prim["attributes"]["NORMAL"]).astype(np.float64)
        self.uv = self.acc(prim["attributes"]["TEXCOORD_0"])
        self.idx = self.acc(prim["indices"]).reshape(-1, 3).astype(np.int64)

    def acc(self, i):
        a = self.json["accessors"][i]
        bv = self.json["bufferViews"][a["bufferView"]]
        kind = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a["componentType"]]
        comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[a["type"]]
        out = np.frombuffer(self.bin, kind, a["count"] * comps, bv.get("byteOffset", 0) + a.get("byteOffset", 0))
        return out.reshape(-1, comps) if comps > 1 else out

    def image(self, i):
        bv = self.json["bufferViews"][self.json["images"][i]["bufferView"]]
        return self.bin[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]


def weld(pos, tol=1e-5):
    """A shared id per position, so shells are found through the UV and normal splits."""
    key = np.round(pos / tol).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    return inv.ravel()


def shells(idx, ids):
    """Connected component of every triangle through welded vertices."""
    parent = np.arange(ids.max() + 1)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    t = ids[idx]
    for a, b, c in t:
        ra, rb, rc = find(a), find(b), find(c)
        if ra != rb:
            parent[rb] = ra
        if ra != rc:
            parent[rc] = ra
    return np.fromiter((find(a) for a in t[:, 0]), np.int64, len(t))


def write(path, src, pieces, world=None, nrm_world=None):
    """pieces: list of (name, positions, normals, uvs, indices). Each piece is a node at the origin; the source's material and images are shared."""
    j = {"asset": {"version": "2.0", "generator": "tools/blender/bull_import"}, "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [],
         "accessors": [], "bufferViews": [], "buffers": [{}], "samplers": src.json.get("samplers", [{}]), "textures": src.json["textures"], "materials": src.json["materials"], "images": []}
    blob = bytearray()

    def view(data, target=None):
        while len(blob) % 4:
            blob.append(0)
        bv = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
        if target:
            bv["target"] = target
        blob.extend(data)
        j["bufferViews"].append(bv)
        return len(j["bufferViews"]) - 1

    def accessor(arr, kind, typ, target, minmax=False):
        a = {"bufferView": view(arr.tobytes(), target), "componentType": kind, "count": len(arr) if typ != "SCALAR" else arr.size, "type": typ}
        if minmax:
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        j["accessors"].append(a)
        return len(j["accessors"]) - 1
    for i, im in enumerate(src.json["images"]):
        j["images"].append({"name": im.get("name", f"image{i}"), "mimeType": im["mimeType"], "bufferView": view(src.image(i))})
    for name, p, n, u, tri in pieces:
        prim = {"attributes": {"POSITION": accessor(p.astype(np.float32), 5126, "VEC3", 34962, True), "NORMAL": accessor(n.astype(np.float32), 5126, "VEC3", 34962),
                               "TEXCOORD_0": accessor(u.astype(np.float32), 5126, "VEC2", 34962)},
                "indices": accessor(tri.astype(np.uint32).ravel(), 5125, "SCALAR", 34963), "material": 0}
        j["meshes"].append({"name": name, "primitives": [prim]})
        j["nodes"].append({"name": name, "mesh": len(j["meshes"]) - 1})
        j["scenes"][0]["nodes"].append(len(j["nodes"]) - 1)
    while len(blob) % 4:
        blob.append(0)
    j["buffers"][0]["byteLength"] = len(blob)
    head = json.dumps(j, separators=(",", ":")).encode()
    head += b" " * (-len(head) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(head) + 8 + len(blob)))
        f.write(struct.pack("<II", len(head), 0x4E4F534A))
        f.write(head)
        f.write(struct.pack("<II", len(blob), 0x004E4942))
        f.write(blob)

"""Package the preserved temple for Studio using the existing Vesperhold GLB format."""
import json
from mmap import ACCESS_READ, mmap
from pathlib import Path
from shutil import copyfile
import struct
import sys
from tempfile import TemporaryFile

from PIL import Image

ROOT = Path.cwd()
sys.path[:0] = [str(ROOT / "tools/assets"), str(ROOT / "tools/blender/vesperhold")]
import glb_split
import vesp_embed

TASK = ROOT / "work/sol-bellwood-v20"
SOURCE = TASK / "preserved"
ALREADY = TASK / "pilot/split/Bellwood_ColossalTemple__p1.glb"
STEM = "Bellwood_ColossalTemple"
LIMIT = 19_500_000
OUT = TASK / "upload/temple"


def describe(node, doc):
    mesh = doc["meshes"][node["mesh"]]
    shapes = []
    for primitive in mesh["primitives"]:
        assert primitive.get("mode", 4) == 4, node["name"]
        assert {"POSITION", "TANGENT", "NORMAL", "TEXCOORD_0"} <= set(primitive["attributes"]), node["name"]
        index_count = doc["accessors"][primitive["indices"]]["count"]
        assert index_count % 3 == 0
        position = doc["accessors"][primitive["attributes"]["POSITION"]]
        shapes.append((index_count // 3, position["count"], position["min"], position["max"]))
    return shapes


def write_binary(doc, raw, byte_start, byte_length, spool):
    for i in range(byte_start, byte_start + byte_length, 4 * 1024 * 1024):
        spool.write(raw[i:min(i + 4 * 1024 * 1024, byte_start + byte_length)])
    doc["images"] = []
    doc["textures"] = []
    doc["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]

    def texture(data, mime):
        spool.write(b"\0" * (-spool.tell() % 4))
        doc["bufferViews"].append({"buffer": 0, "byteOffset": spool.tell(), "byteLength": len(data)})
        spool.write(data)
        doc["images"].append({"bufferView": len(doc["bufferViews"]) - 1, "mimeType": mime})
        doc["textures"].append({"sampler": 0, "source": len(doc["images"]) - 1})
        return {"index": len(doc["textures"]) - 1, "texCoord": 0}

    for material in doc["materials"]:
        name = material["name"]
        for channel in ("Color", "Normal", "Roughness", "Metal"):
            path = SOURCE / "maps" / f"{name}_{channel}.png"
            with Image.open(path) as img:
                assert img.size == (2048, 2048), path
        encoded = vesp_embed._encode(SOURCE / "maps", name)
        vesp_embed._CACHE.clear()
        material["pbrMetallicRoughness"] = {
            "baseColorTexture": texture(*encoded["color"]),
            "metallicRoughnessTexture": texture(*encoded["rm"]),
            "baseColorFactor": [1, 1, 1, 1],
            "metallicFactor": 1,
            "roughnessFactor": 1,
        }
        material["normalTexture"] = texture(*encoded["normal"])
        if encoded["alpha"]:
            material["alphaMode"] = "BLEND"
    doc["buffers"][0]["byteLength"] = spool.tell()
    spool.flush()


def pack(doc, blob):
    nodes_by_name = {node["name"]: i for i, node in enumerate(doc["nodes"])}
    nodes = list(nodes_by_name.values())
    assert len(nodes) == len(doc["nodes"])
    assert all("mesh" in node and not any(key in node for key in ("matrix", "translation", "rotation", "scale", "children"))
               for node in doc["nodes"])
    pilot, _ = glb_split.read(ALREADY)
    first = [nodes_by_name[node["name"]] for node in pilot["nodes"]]
    for node, index in zip(pilot["nodes"], first):
        assert describe(node, pilot) == describe(doc["nodes"][index], doc), node["name"]
    entry = json.loads((SOURCE / "manifest.json").read_text())["pieces"][STEM]
    counts = {node["name"]: sum(shape[0] for shape in describe(node, doc)) for node in doc["nodes"]}
    assert counts == entry["sub_meshes"] and max(counts.values()) <= 18000
    foot_centres = glb_split.centres(doc, nodes)

    groups = []
    remainder = sorted((i for i in nodes if i not in first),
                       key=lambda i: (sorted(glb_split.deps(doc, i)[1]), doc["nodes"][i]["name"]))
    for i in remainder:
        assert glb_split.size(doc, [i]) <= LIMIT - 65536, doc["nodes"][i]["name"]
        group = next((p for p in groups if glb_split.size(doc, p + [i]) <= LIMIT - 65536), None)
        if group is None:
            groups.append([i])
        else:
            group.append(i)
    OUT.mkdir(parents=True, exist_ok=True)
    parts = {}
    for i, group in enumerate([first] + groups, 1):
        target = OUT / f"{STEM}__p{i}.glb"
        if i == 1:
            copyfile(ALREADY, target)
        else:
            glb_split.write(doc, blob, group, target)
        written, _ = glb_split.read(target)
        names = sorted(doc["nodes"][n]["name"] for n in group)
        assert target.stat().st_size <= LIMIT and names == sorted(n["name"] for n in written["nodes"]), target
        parts[target.name] = names
    assert sorted(sum(parts.values(), [])) == sorted(foot_centres)
    (OUT / f"{STEM}.split.json").write_text(json.dumps({"parts": parts, "centres": foot_centres}, indent=2) + "\n")
    print(f"Staged {len(parts)} GLBs with {len(counts)} meshes and {sum(counts.values()):,} triangles.")


def main():
    with (SOURCE / f"{STEM}.glb").open("rb") as f, mmap(f.fileno(), 0, access=ACCESS_READ) as raw, TemporaryFile(dir=TASK) as spool:
        assert raw[:4] == b"glTF"
        length, kind = struct.unpack_from("<I4s", raw, 12)
        assert kind == b"JSON"
        doc = json.loads(raw[20:20 + length])
        byte_start = 20 + length + 8
        byte_length, kind = struct.unpack_from("<I4s", raw, byte_start - 8)
        assert kind == b"BIN\0"
        write_binary(doc, raw, byte_start, byte_length, spool)
        with mmap(spool.fileno(), 0, access=ACCESS_READ) as binary:
            pack(doc, binary)


if __name__ == "__main__":
    main()

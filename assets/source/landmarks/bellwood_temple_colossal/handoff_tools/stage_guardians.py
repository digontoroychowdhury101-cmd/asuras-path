"""Stage the approved baked guardians, keeping all four meshes per statue."""
import io
import json
from pathlib import Path
import sys

from PIL import Image

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tools/assets"))
import glb_split

source = ROOT / "work/claude-bellwood-guardians"
output = Path(__file__).resolve().parent
pieces = {}
for side in ("East", "West"):
    piece = f"Bellwood_ColossalGuardian{side}"
    doc, blob = glb_split.read(source / f"bellwood_guardian_{side.lower()}_parts.glb")
    nodes = [i for i, node in enumerate(doc["nodes"]) if "mesh" in node]
    assert len(nodes) == 4
    tris = {}
    for index in nodes:
        node = doc["nodes"][index]
        assert not any(k in node for k in ("translation", "rotation", "scale", "matrix")), node
        original = f"Bellwood_Guardian_{side}"
        assert node["name"].startswith(original + "_")
        node["name"] = piece + "__" + node["name"][len(original) + 1:]
        doc["meshes"][node["mesh"]]["name"] = node["name"]
        prim = doc["meshes"][node["mesh"]]["primitives"]
        count = sum(doc["accessors"][p["indices"]]["count"] // 3 for p in prim)
        assert 0 < count <= 18000
        tris[node["name"]] = count
    for image in doc["images"]:
        with Image.open(io.BytesIO(glb_split.view_bytes(doc, blob, image["bufferView"]))) as decoded:
            assert decoded.size == (2048, 2048), (side, decoded.size)
    path = output / f"{piece}.glb"
    glb_split.write(doc, blob, nodes, path)
    pieces[piece] = {"file": path.name, "sub_meshes": tris}
    print(piece, tris)
(output / "manifest.json").write_text(json.dumps({"kit": "Bellwood colossal guardians", "pieces": pieces}, indent=2) + "\n")

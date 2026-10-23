"""Extract one uploaded ServerStorage guardian Model from a Studio-saved XML place.
Usage: python3 tools/assets/extract_guardian_lion.py outputs/AsurasPath.rbxlx
Preserves the complete imported subtree and referenced SharedStrings; never uploads or invents IDs.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = re.compile(r"rbxassetid://[1-9][0-9]{5,19}")
MAPS = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")
TOLERANCE = 0.001


def name(item: ET.Element) -> str:
    return item.findtext('Properties/string[@name="Name"]') or ""


def content(item: ET.Element, key: str) -> str:
    return item.findtext(f'Properties/Content[@name="{key}"]/url') or ""


def values(node: ET.Element | None, keys: tuple[str, ...], label: str) -> list[float]:
    if node is None:
        raise ValueError(f"{label}: missing saved property")
    try:
        result = [float(node.findtext(key, "nan")) for key in keys]
    except ValueError as exc:
        raise ValueError(f"{label}: invalid numeric property") from exc
    if not all(math.isfinite(v) for v in result):
        raise ValueError(f"{label}: missing or non-finite values")
    return result


def frame(node: ET.Element | None, expected_position: tuple[float, float, float], label: str) -> None:
    xyz = values(node, ("X", "Y", "Z"), label)
    rotation = values(node, tuple(f"R{r}{c}" for r in range(3) for c in range(3)), label)
    identity = [1.0 if r == c else 0.0 for r in range(3) for c in range(3)]
    if any(abs(a-b) > TOLERANCE for a, b in zip(xyz, expected_position)):
        raise ValueError(f"{label}: expected position {expected_position}, got {xyz}")
    if any(abs(a-b) > TOLERANCE for a, b in zip(rotation, identity)):
        raise ValueError(f"{label}: rotation is not identity")


def extract(place: Path, model_name: str, height: float) -> tuple[ET.Element, dict]:
    tree = ET.parse(place).getroot()
    servers = [i for i in tree.findall("Item") if i.attrib.get("class") == "ServerStorage"]
    if len(servers) != 1:
        raise ValueError("Expected exactly one ServerStorage")
    models = [i for i in servers[0].findall("Item") if name(i) == model_name and i.attrib.get("class") == "Model"]
    if len(models) != 1:
        raise ValueError(f"Expected one ServerStorage.{model_name} Model, found {len(models)}")
    model = models[0]
    meshes = [i for i in model.iter("Item") if i.attrib.get("class") == "MeshPart"]
    if len(meshes) != 1:
        raise ValueError(f"{model_name}: expected one MeshPart, found {len(meshes)}")
    mesh = meshes[0]
    size = values(mesh.find('Properties/Vector3[@name="size"]'), ("X", "Y", "Z"), "MeshPart.Size")
    if any(v <= 0 for v in size) or abs(size[1]-height) > TOLERANCE:
        raise ValueError(f"{model_name}: expected positive dimensions and height {height}, got {size}")
    frame(model.find('Properties/OptionalCoordinateFrame[@name="WorldPivotData"]/CFrame'), (0, 0, 0), "Model.WorldPivot")
    frame(mesh.find('Properties/CoordinateFrame[@name="CFrame"]'), (0, height/2, 0), "MeshPart.CFrame")
    frame(mesh.find('Properties/CoordinateFrame[@name="PivotOffset"]'), (0, 0, 0), "MeshPart.PivotOffset")
    primary = model.findtext('Properties/Ref[@name="PrimaryPart"]')
    if primary not in (None, "null", "nil"):
        raise ValueError("Expected explicit floor WorldPivot without a PrimaryPart override")
    surfaces = [i for i in mesh.findall("Item") if i.attrib.get("class") == "SurfaceAppearance"]
    if len(surfaces) != 1:
        raise ValueError(f"{name(mesh)}: expected one SurfaceAppearance")
    surface = surfaces[0]
    ids = {"MeshId": content(mesh, "MeshId"), **{key: content(surface, key) for key in MAPS}}
    for key, value in ids.items():
        if not ID.fullmatch(value):
            raise ValueError(f"{name(mesh)}: missing real uploaded {key}")
    pack = content(surface, "TexturePack")
    if pack:
        if not ID.fullmatch(pack): raise ValueError("Invalid saved TexturePack ID")
        ids["TexturePack"] = pack
    # Copy the exact template, including importer collision/mesh metadata and material tint.
    root = ET.Element("roblox", {"version": "4"})
    ET.SubElement(root, "External").text = "null"
    ET.SubElement(root, "External").text = "nil"
    root.append(copy.deepcopy(model))
    references = {v.text.strip() for v in model.iter("SharedString") if v.text and v.text.strip()}
    source_shared = tree.find("SharedStrings")
    found = set()
    if references:
        target = ET.SubElement(root, "SharedStrings")
        if source_shared is not None:
            for shared in source_shared:
                key = shared.attrib.get("md5", "")
                if key in references:
                    target.append(copy.deepcopy(shared)); found.add(key)
        if references-found:
            raise ValueError("Missing imported SharedStrings: " + ", ".join(sorted(references-found)))
    cleaned = ROOT / "assets/build/guardian_lion/Asuraguardianlion.glb"
    record = {"source": "assets/build/guardian_lion/Asuraguardianlion.glb", "source_sha256": hashlib.sha256(cleaned.read_bytes()).hexdigest() if cleaned.exists() else None,
              "raw_source": "assets/build/guardian_lion/source/AsuraGuardianLion_TRELLIS_raw.glb",
              "importer": "Roblox Studio 3D Importer, Creator: Me", "model": model_name,
              "parts": {name(mesh): ids}, "size": size, "height": size[1], "footY": 0,
              "worldPivot": [0, 0, 0], "identityOrientation": True, "sharedStringCount": len(found),
              "validation": "Single uploaded MeshPart; complete PBR; height 8; centred foot at origin; identity WorldPivot and part rotation"}
    return root, record


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place", type=Path)
    parser.add_argument("--model", default="AsuraGuardianLion")
    parser.add_argument("--height", type=float, default=8)
    parser.add_argument("--output", type=Path, default=ROOT / "assets/models/AsuraGuardianLion.rbxmx")
    parser.add_argument("--registry", type=Path, default=ROOT / "assets/GUARDIAN_LION_UPLOADED.json")
    args = parser.parse_args()
    root, record = extract(args.place, args.model, args.height)
    record["savedPlace"] = str(args.place)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(args.output.suffix + ".tmp")
    ET.ElementTree(root).write(temporary, encoding="utf-8", xml_declaration=True)
    # Parse the staged serialization before replacing the persistent model.
    ET.parse(temporary)
    temporary.replace(args.output)
    args.registry.write_text(json.dumps(record, indent=2) + "\n")
    print(f"EXTRACTED {args.model}: {len(record['parts'])} MeshPart, complete uploaded PBR, height {record['height']}, foot 0, {record['sharedStringCount']} SharedStrings -> {args.output}")


if __name__ == "__main__":
    main()

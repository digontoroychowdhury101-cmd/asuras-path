"""Extract the uploaded Han kits from a Studio-saved XML place into their own Rojo libraries.

    python -I tools/assets/extract_han_kits.py outputs/han-kit-2026-10-26/import/AsurasPath_hankit.rbxlx

Takes ServerStorage.AsuraHanHD (tools/blender/han_hd.py) and ServerStorage.AsuraHanKit
(tools/blender/han_kit.py), checks every manifest part is present with an uploaded MeshId and an
uploaded SurfaceAppearance (four maps or the importer's TexturePack), keeps the referenced
SharedStrings (importer physics data) and writes assets/models/<Kit>.rbxmx plus the ID registry
assets/HAN_KITS_UPLOADED.json. Never uploads or invents IDs.
"""
import argparse
import copy
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = re.compile(r"rbxassetid://[1-9][0-9]{5,19}")
MAPS = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")
KITS = {"AsuraHanHD": "assets/build/han_hd/manifest.json", "AsuraHanKit": "assets/build/han_kit/manifest.json"}


def name(item):
    return item.findtext('Properties/string[@name="Name"]')


def content(item, key):
    return item.findtext(f'Properties/Content[@name="{key}"]/url') or ""


def extract(tree, server, kit_name, manifest_path):
    kit = next((i for i in server.findall("Item") if name(i) == kit_name), None)
    if kit is None:
        raise SystemExit(f"ServerStorage.{kit_name} not found")
    manifest = json.loads((ROOT / manifest_path).read_text())
    expected = {part: piece for piece, info in manifest["pieces"].items() for part in info["parts"]}
    registry, seen = {}, set()
    for piece in kit.findall("Item"):
        if piece.attrib.get("class") != "Model":
            raise SystemExit(f"Unexpected {kit_name} child {name(piece)}")
        for mesh in piece.iter("Item"):
            if mesh.attrib.get("class") != "MeshPart":
                continue
            part = name(mesh)
            if expected.get(part) != name(piece):
                raise SystemExit(f"{part} is not a manifest part of {name(piece)}")
            surface = next((s for s in mesh.findall("Item") if s.attrib.get("class") == "SurfaceAppearance"), None)
            if surface is None:
                raise SystemExit(f"{part}: no SurfaceAppearance")
            ids = {"MeshId": content(mesh, "MeshId")}
            ids.update({k: content(surface, k) for k in MAPS if content(surface, k)})
            pack = content(surface, "TexturePack")
            if pack:
                ids["TexturePack"] = pack
            needed = ("MeshId",) + (("TexturePack",) if pack and not ids.get("ColorMap") else MAPS)
            bad = [k for k in needed if not ID.fullmatch(ids.get(k, ""))]
            if bad:
                raise SystemExit(f"{part}: missing uploaded {', '.join(bad)}")
            registry.setdefault(name(piece), {})[part] = ids
            seen.add(part)
    missing = sorted(set(expected) - seen)
    if missing:
        raise SystemExit(f"{kit_name} parts missing from the place: " + ", ".join(missing))
    root = ET.Element("roblox", {"version": "4"})
    ET.SubElement(root, "External").text = "null"
    ET.SubElement(root, "External").text = "nil"
    root.append(copy.deepcopy(kit))
    references = {v.text for v in kit.iter("SharedString")}
    shared = tree.find("SharedStrings")
    if shared is not None and references:
        target = ET.SubElement(root, "SharedStrings")
        for string in shared:
            if string.attrib.get("md5") in references:
                target.append(copy.deepcopy(string))
    out = ROOT / f"assets/models/{kit_name}.rbxmx"
    ET.ElementTree(root).write(out, encoding="utf-8", xml_declaration=True)
    print(f"EXTRACTED {kit_name}: {len(registry)} pieces, {len(seen)} MeshParts -> {out.relative_to(ROOT)}")
    return registry


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("place")
    args = parser.parse_args()
    tree = ET.parse(args.place).getroot()
    server = next(i for i in tree.findall("Item") if i.attrib.get("class") == "ServerStorage")
    registry = {kit: extract(tree, server, kit, path) for kit, path in KITS.items()}
    (ROOT / "assets/HAN_KITS_UPLOADED.json").write_text(json.dumps(
        {"sources": {"AsuraHanHD": "assets/build/han_hd/AsuraHanHD.glb", "AsuraHanKit": "assets/build/han_kit/AsuraHanKit.glb"},
         "importer": "Studio 3D Importer, Creator: Me", "kits": registry}, indent=2) + "\n")


if __name__ == "__main__":
    main()

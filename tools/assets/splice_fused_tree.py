"""Splice the uploaded FusedTreeStatue into the asset library, replacing the old AsuraVeiledTitan.
Usage: python3 tools/assets/splice_fused_tree.py places/AsurasPath.rbxlx
Reads ServerStorage.AsuraAssets.FusedTreeStatue from a Studio-saved XML place (imported with the Studio 3D
Importer from assets/build/fused_tree_statue/fused_tree_statue.glb) and writes it into
assets/models/AsuraAssets_Phase5.rbxmx with its SharedStrings; never uploads or invents IDs.
"""
from __future__ import annotations

import argparse
import copy
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = re.compile(r"rbxassetid://[1-9][0-9]{5,19}")
CAP = 20000
OLD, NEW = "AsuraVeiledTitan", "FusedTreeStatue"


def name(item: ET.Element) -> str:
    return item.findtext('Properties/string[@name="Name"]') or ""


def content(item: ET.Element, key: str) -> str:
    return item.findtext(f'Properties/Content[@name="{key}"]/url') or ""


def find_model(place: Path) -> tuple[ET.Element, ET.Element]:
    root = ET.parse(place).getroot()
    storage = [i for i in root.findall("Item") if i.attrib.get("class") == "ServerStorage"]
    assets = [i for s in storage for i in s.findall("Item") if name(i) == "AsuraAssets"]
    models = [i for a in assets for i in a.findall("Item") if name(i) == NEW and i.attrib.get("class") == "Model"]
    if len(models) != 1:
        raise ValueError(f"Expected one ServerStorage.AsuraAssets.{NEW}, found {len(models)}")
    return root, models[0]


def validate(model: ET.Element, stats: dict) -> dict:
    parts = {}
    for mesh in (i for i in model.iter("Item") if i.attrib.get("class") == "MeshPart"):
        surfaces = [i for i in mesh.findall("Item") if i.attrib.get("class") == "SurfaceAppearance"]
        if len(surfaces) != 1:
            raise ValueError(f"{name(mesh)}: expected one SurfaceAppearance")
        ids = {"MeshId": content(mesh, "MeshId")}
        ids.update({k: content(surfaces[0], k) for k in ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")})
        for key in ("MeshId", "ColorMap", "NormalMap", "RoughnessMap"):
            if not ID.fullmatch(ids[key]):
                raise ValueError(f"{name(mesh)}: missing real uploaded {key}")
        tris = stats["parts"].get(name(mesh))
        if tris is None:
            raise ValueError(f"{name(mesh)}: not a part of the Blender export")
        if tris >= CAP:
            raise ValueError(f"{name(mesh)}: {tris} triangles")
        parts[name(mesh)] = {**ids, "triangles": tris}
    missing = set(stats["parts"]) - set(parts)
    if missing:
        raise ValueError("Parts missing from the import: " + ", ".join(sorted(missing)))
    return parts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place", type=Path)
    parser.add_argument("--library", type=Path, default=ROOT / "assets/models/AsuraAssets_Phase5.rbxmx")
    parser.add_argument("--stats", type=Path, default=ROOT / "assets/build/fused_tree_statue/stats.json")
    parser.add_argument("--registry", type=Path, default=ROOT / "assets/FUSED_TREE_STATUE_UPLOADED.json")
    args = parser.parse_args()
    stats = json.loads(args.stats.read_text())
    source, model = find_model(args.place)
    parts = validate(model, stats)

    lib_tree = ET.parse(args.library)
    lib = lib_tree.getroot()
    folder = next(i for i in lib.iter("Item") if any(name(c) == OLD or name(c) == NEW for c in i.findall("Item")))
    for child in [c for c in folder.findall("Item") if name(c) in (OLD, NEW)]:
        folder.remove(child)
    folder.append(copy.deepcopy(model))

    refs = {v.text.strip() for v in model.iter("SharedString") if v.text and v.text.strip()}
    if refs:
        target = lib.find("SharedStrings")
        if target is None:
            target = ET.SubElement(lib, "SharedStrings")
        have = {s.attrib.get("md5") for s in target}
        found = set()
        shared_strings = source.find("SharedStrings")
        for shared in (shared_strings if shared_strings is not None else []):
            key = shared.attrib.get("md5", "")
            if key in refs:
                found.add(key)
                if key not in have:
                    target.append(copy.deepcopy(shared))
        if refs - found:
            raise ValueError("Missing imported SharedStrings: " + ", ".join(sorted(refs - found)))

    temporary = args.library.with_suffix(args.library.suffix + ".tmp")
    lib_tree.write(temporary, encoding="utf-8", xml_declaration=True)
    ET.parse(temporary)  # the staged serialization must parse before it replaces the library
    temporary.replace(args.library)
    record = {"source": "assets/build/fused_tree_statue/fused_tree_statue.glb", "builder": "tools/blender/fuse_tree_woman.py",
              "importer": "Roblox Studio 3D Importer, Creator: Me", "model": NEW, "replaces": OLD,
              "savedPlace": str(args.place), "partCount": len(parts), "totalTriangles": stats["totalTris"],
              "maxPartTriangles": stats["maxPartTris"], "treeSpanStuds": stats["treeSpanStuds"], "parts": parts}
    args.registry.write_text(json.dumps(record, indent=2) + "\n")
    print(f"SPLICED {NEW}: {len(parts)} MeshParts (max {stats['maxPartTris']} tris), replaced {OLD} -> {args.library}")


if __name__ == "__main__":
    main()

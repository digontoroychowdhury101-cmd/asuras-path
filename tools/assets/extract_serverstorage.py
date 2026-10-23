"""Extract top-level ServerStorage children from a Studio-saved XML place into their own .rbxmx files.
Usage: python3 tools/assets/extract_serverstorage.py places/AsurasPath.rbxlx NAME=assets/models/NAME.rbxmx [...]
Keeps the complete imported subtree and the SharedStrings it references; every MeshPart must carry a real
uploaded MeshId (and, under a SurfaceAppearance, real map IDs). Never uploads or invents IDs.
"""
from __future__ import annotations

import argparse
import copy
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = re.compile(r"rbxassetid://[1-9][0-9]{5,19}")


def name(item: ET.Element) -> str:
    return item.findtext('Properties/string[@name="Name"]') or ""


def content(item: ET.Element, key: str) -> str:
    return item.findtext(f'Properties/Content[@name="{key}"]/url') or ""


def check(model: ET.Element) -> int:
    meshes = [i for i in model.iter("Item") if i.attrib.get("class") == "MeshPart"]
    if not meshes:
        raise ValueError(f"{name(model)}: no MeshParts")
    for mesh in meshes:
        if not ID.fullmatch(content(mesh, "MeshId")):
            raise ValueError(f"{name(model)}.{name(mesh)}: missing uploaded MeshId")
        for surface in (i for i in mesh.findall("Item") if i.attrib.get("class") == "SurfaceAppearance"):
            for key in ("ColorMap", "NormalMap", "RoughnessMap"):
                value = content(surface, key)
                if value and not ID.fullmatch(value):
                    raise ValueError(f"{name(model)}.{name(mesh)}: {key} is not an uploaded ID")
    return len(meshes)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place", type=Path)
    parser.add_argument("targets", nargs="+", help="NAME=output.rbxmx")
    args = parser.parse_args()
    source = ET.parse(args.place).getroot()
    storage = next(i for i in source.findall("Item") if i.attrib.get("class") == "ServerStorage")
    shared = source.find("SharedStrings")
    for target in args.targets:
        key, out = target.split("=", 1)
        found = [i for i in storage.findall("Item") if name(i) == key]
        if len(found) != 1:
            raise ValueError(f"Expected one ServerStorage.{key}, found {len(found)}")
        item = found[0]
        count = check(item)
        root = ET.Element("roblox", {"version": "4"})
        ET.SubElement(root, "External").text = "null"
        ET.SubElement(root, "External").text = "nil"
        root.append(copy.deepcopy(item))
        refs = {v.text.strip() for v in item.iter("SharedString") if v.text and v.text.strip()}
        if refs:
            block = ET.SubElement(root, "SharedStrings")
            have = set()
            for s in (shared if shared is not None else []):
                if s.attrib.get("md5", "") in refs:
                    block.append(copy.deepcopy(s))
                    have.add(s.attrib["md5"])
            if refs - have:
                raise ValueError(f"{key}: missing SharedStrings " + ", ".join(sorted(refs - have)))
        path = ROOT / out if not Path(out).is_absolute() else Path(out)
        temporary = path.with_suffix(path.suffix + ".tmp")
        ET.ElementTree(root).write(temporary, encoding="utf-8", xml_declaration=True)
        ET.parse(temporary)  # the staged file must parse before it replaces the model
        temporary.replace(path)
        print(f"EXTRACTED {key}: {count} MeshParts -> {out}")


if __name__ == "__main__":
    main()

"""Extract the uploaded Shrine lobby kit from a Studio-saved XML place into its own Rojo library.
python3 tools/assets/extract_lobby_kit.py outputs/lobby-rebuild-2026-10-21/import/AsurasPath_kitimport.rbxlx
Takes ServerStorage.AsuraLobbyKit only (the Phase 5 library is untouched), checks every part of
both kit manifests is present with an uploaded MeshId and four uploaded SurfaceAppearance maps, bakes
the agreed SurfaceAppearance tints, keeps the
referenced SharedStrings (importer physics data), and writes assets/models/AsuraLobbyKit.rbxmx plus
the verified ID registry assets/LOBBY_KIT_UPLOADED.json. Never uploads or invents IDs.
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
MANIFESTS = ("manifest.json", "manifest_nature.json")
# SurfaceAppearance.Color per texture set, chosen in Studio against the golden-hour lighting
# (lobby rebuild iterations 3-4): greyer stone, deeper vermilion lacquer. Others stay white.
TINTS = {"Stone": (0.68, 0.7, 0.73), "Lacquer": (0.6, 0.4, 0.38), "Paving": (0.8, 0.82, 0.85), "Rock": (0.86, 0.84, 0.82),
         "Roof": (0.94, 0.95, 1.0), "Foliage": (0.62, 0.44, 0.44)}


def tint(surface, material):
    rgb = TINTS.get(material, (1.0, 1.0, 1.0))
    props = surface.find("Properties")
    color = props.find('Color3[@name="Color"]')
    if color is None:
        color = ET.SubElement(props, "Color3", {"name": "Color"})
        for axis in "RGB":
            ET.SubElement(color, axis)
    for axis, value in zip("RGB", rgb):
        color.find(axis).text = repr(value)


def name(item):
    return item.findtext('Properties/string[@name="Name"]')


def content(item, key):
    return item.findtext(f'Properties/Content[@name="{key}"]/url') or ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("place")
    args = parser.parse_args()
    tree = ET.parse(args.place).getroot()
    server = next(i for i in tree.findall("Item") if i.attrib.get("class") == "ServerStorage")
    kit = next((i for i in server.findall("Item") if name(i) == "AsuraLobbyKit"), None)
    if kit is None:
        raise SystemExit("ServerStorage.AsuraLobbyKit not found in " + args.place)
    expected = {}
    for file in MANIFESTS:
        manifest = json.loads((ROOT / "assets/build/lobby_kit" / file).read_text())
        expected.update({part: piece for piece, info in manifest["pieces"].items() for part in info["parts"]})
    registry, seen = {}, set()
    for piece in kit.findall("Item"):
        if piece.attrib.get("class") != "Model":
            raise SystemExit("Unexpected kit child " + str(name(piece)))
        for mesh in piece.findall("Item"):
            if mesh.attrib.get("class") != "MeshPart":
                continue
            part = name(mesh)
            if expected.get(part) != name(piece):
                raise SystemExit(f"{part} is not a manifest part of {name(piece)}")
            surface = next((s for s in mesh.findall("Item") if s.attrib.get("class") == "SurfaceAppearance"), None)
            ids = {"MeshId": content(mesh, "MeshId")}
            if surface is not None:
                ids.update({key: content(surface, key) for key in MAPS})
                tint(surface, part.split("__")[-1])
                pack = content(surface, "TexturePack")
                if pack:
                    ids["TexturePack"] = pack
            bad = [k for k in ("MeshId",) + MAPS if not ID.fullmatch(ids.get(k, ""))]
            if bad:
                raise SystemExit(f"{part}: missing uploaded {', '.join(bad)}")
            registry.setdefault(name(piece), {})[part] = ids
            seen.add(part)
    missing = sorted(set(expected) - seen)
    if missing:
        raise SystemExit("Kit parts missing from the place: " + ", ".join(missing))
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
    out = ROOT / "assets/models/AsuraLobbyKit.rbxmx"
    ET.ElementTree(root).write(out, encoding="utf-8", xml_declaration=True)
    textures = sorted({v for parts in registry.values() for ids in parts.values() for k, v in ids.items() if k != "MeshId"})
    (ROOT / "assets/LOBBY_KIT_UPLOADED.json").write_text(json.dumps(
        {"source": ["assets/build/lobby_kit/AsuraLobbyKit.glb", "assets/build/lobby_kit/AsuraLobbyNature.glb"],
         "importer": "Studio 3D Importer, Creator: Me", "tints": TINTS,
         "pieces": registry, "distinctTextureIds": len(textures)}, indent=2) + "\n")
    print(f"EXTRACTED {len(registry)} pieces, {len(seen)} MeshParts, {len(textures)} texture/pack IDs -> {out}")


if __name__ == "__main__":
    main()

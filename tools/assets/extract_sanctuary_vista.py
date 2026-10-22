"""Persist the uploaded Sanctuary vista kit from a Studio-saved XML place.

    python3 tools/assets/extract_sanctuary_vista.py [outputs/AsurasPath.rbxlx] [--dry-run]

Reads only ServerStorage.AsuraSanctuaryVista. Checks the manifest's four models / seven meshes,
uploaded IDs, rock PBR maps, local transforms and sizes before writing the separate Rojo library
and ID registry. Referenced importer SharedStrings are copied verbatim. Does not upload, change
the project mapping, or touch the Phase 5 / lobby libraries. Save the reorganized Studio place first.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets/build/sanctuary_vista/manifest.json"
LIBRARY = ROOT / "assets/models/AsuraSanctuaryVista.rbxmx"
REGISTRY = ROOT / "assets/SANCTUARY_VISTA_UPLOADED.json"
LIBRARY_NAME = "AsuraSanctuaryVista"
MAPS = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")
REQUIRED_ROCK_MAPS = MAPS[:3]
ASSET_ID = re.compile(r"(?:rbxassetid://|https?://(?:www\.)?roblox\.com/asset/\?id=)([1-9][0-9]{5,19})")
POSITION_TOLERANCE = 0.02
SIZE_TOLERANCE = 0.02


def name(item: ET.Element) -> str:
    return item.findtext('Properties/string[@name="Name"]') or ""


def content(item: ET.Element, key: str) -> str:
    # Studio currently writes both the older Content/url and newer Content/uri property forms.
    keys = ("MeshId", "MeshContent") if key == "MeshId" else (key, key + "Content")
    for candidate in keys:
        node = item.find(f'Properties/Content[@name="{candidate}"]')
        if node is not None:
            value = node.findtext("url") or node.findtext("uri")
            if value:
                return value.strip()
    return ""


def uploaded(item: ET.Element, key: str, label: str, required: bool = True) -> str:
    value = content(item, key)
    if not value and not required:
        return ""
    match = ASSET_ID.fullmatch(value)
    if not match:
        raise ValueError(f"{label}: {key} has no real uploaded asset reference: {value!r}")
    return "rbxassetid://" + match.group(1)


def vector(item: ET.Element, prop: str) -> list[float]:
    node = item.find(f'Properties/Vector3[@name="{prop}"]')
    if node is None and prop == "size":
        node = item.find('Properties/Vector3[@name="Size"]')
    if node is None:
        raise ValueError(f"{name(item)}: missing {prop}")
    return [float(node.findtext(axis) or "nan") for axis in "XYZ"]


def transform(item: ET.Element) -> list[float]:
    frame = item.find('Properties/CoordinateFrame[@name="CFrame"]')
    if frame is None:
        raise ValueError(f"{name(item)}: missing CFrame")
    for row in range(3):
        for col in range(3):
            expected = 1.0 if row == col else 0.0
            actual = float(frame.findtext(f"R{row}{col}") or "nan")
            if not abs(actual - expected) <= 0.0001:
                raise ValueError(f"{name(item)}: expected identity part rotation, R{row}{col}={actual}")
    return [float(frame.findtext(axis) or "nan") for axis in "XYZ"]


def close(actual: list[float], expected: list[float], tolerance: float, label: str) -> None:
    if len(actual) != len(expected) or any(not abs(a - e) <= tolerance for a, e in zip(actual, expected)):
        raise ValueError(f"{label}: actual {actual}, manifest {expected} (tolerance {tolerance} studs)")


def extract(place: Path) -> tuple[ET.Element, dict]:
    manifest = json.loads(MANIFEST.read_text())
    document = ET.parse(place).getroot()
    server = next((item for item in document.findall("Item") if item.get("class") == "ServerStorage"), None)
    if server is None:
        raise ValueError(f"{place}: ServerStorage not found")
    matches = [item for item in server.findall("Item") if name(item) == LIBRARY_NAME]
    if len(matches) != 1:
        raise ValueError(f"Expected one ServerStorage.{LIBRARY_NAME}; found {len(matches)}")
    library = matches[0]
    pieces: dict = {}
    seen_parts: set[str] = set()
    mesh_ids: set[str] = set()
    texture_ids: set[str] = set()
    for model in library.findall("Item"):
        piece_name = name(model)
        if model.get("class") != "Model" or piece_name not in manifest["pieces"] or piece_name in pieces:
            raise ValueError(f"Unexpected or duplicate vista model: {piece_name!r} ({model.get('class')})")
        expected = manifest["pieces"][piece_name]["parts"]
        parts = {}
        for mesh in model.findall("Item"):
            if mesh.get("class") != "MeshPart":
                raise ValueError(f"{piece_name}: unexpected child {name(mesh)!r} ({mesh.get('class')})")
            part_name = name(mesh)
            if part_name not in expected or part_name in seen_parts:
                raise ValueError(f"Unexpected or duplicate vista mesh: {part_name!r}")
            info = expected[part_name]
            position, size = transform(mesh), vector(mesh, "size")
            close(position, info["center"], POSITION_TOLERANCE, part_name + " centre")
            close(size, info["size"], SIZE_TOLERANCE, part_name + " size")
            ids = {"MeshId": uploaded(mesh, "MeshId", part_name)}
            if ids["MeshId"] in mesh_ids:
                raise ValueError(f"{part_name}: duplicate MeshId {ids['MeshId']}; each manifest mesh must have its own upload")
            mesh_ids.add(ids["MeshId"])
            surfaces = [item for item in mesh.findall("Item") if item.get("class") == "SurfaceAppearance"]
            if len(surfaces) > 1:
                raise ValueError(f"{part_name}: more than one SurfaceAppearance")
            rock = info["material"] == "Rock"
            if rock and not surfaces:
                raise ValueError(f"{part_name}: rock SurfaceAppearance missing")
            if surfaces:
                for key in MAPS:
                    value = uploaded(surfaces[0], key, part_name, required=rock and key in REQUIRED_ROCK_MAPS)
                    if value:
                        ids[key] = value
                        texture_ids.add(value)
                pack = uploaded(surfaces[0], "TexturePack", part_name, required=False)
                if pack:
                    ids["TexturePack"] = pack
                    texture_ids.add(pack)
            parts[part_name] = {**ids, "material": info["material"], "center": position, "size": size,
                                "triangles": info["triangles"]}
            seen_parts.add(part_name)
        missing = set(expected) - set(parts)
        if missing:
            raise ValueError(f"{piece_name}: missing manifest meshes {sorted(missing)}")
        pieces[piece_name] = parts
    missing_models = set(manifest["pieces"]) - set(pieces)
    if missing_models:
        raise ValueError(f"Missing vista models: {sorted(missing_models)}")
    if len(seen_parts) != manifest["totals"]["meshParts"]:
        raise ValueError("Extracted mesh count does not match the manifest")

    output = ET.Element("roblox", {"version": "4"})
    ET.SubElement(output, "External").text = "null"
    ET.SubElement(output, "External").text = "nil"
    output.append(copy.deepcopy(library))
    references = {item.text for item in library.iter("SharedString") if item.text}
    source_shared = document.find("SharedStrings")
    available = {item.get("md5"): item for item in source_shared} if source_shared is not None else {}
    if references - set(available):
        raise ValueError(f"Missing referenced SharedStrings: {sorted(references - set(available))}")
    if references:
        target = ET.SubElement(output, "SharedStrings")
        for key in sorted(references):
            target.append(copy.deepcopy(available[key]))
    source = ROOT / "assets/build/sanctuary_vista/AsuraSanctuaryVista.glb"
    registry = {
        "source": "assets/build/sanctuary_vista/AsuraSanctuaryVista.glb",
        "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "sourcePlace": str(place.relative_to(ROOT)) if place.is_relative_to(ROOT) else str(place),
        "manifest": "assets/build/sanctuary_vista/manifest.json",
        "importer": "Studio 3D Importer, Creator: Me",
        "provenance": manifest["source"],
        "pieces": pieces,
        "meshParts": len(seen_parts), "distinctMeshIds": len(mesh_ids),
        "distinctTextureIds": len(texture_ids), "referencedSharedStrings": len(references),
    }
    return output, registry


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("place", nargs="?", type=Path, default=ROOT / "outputs/AsurasPath.rbxlx")
    parser.add_argument("--dry-run", action="store_true", help="Validate only; write no library or registry")
    args = parser.parse_args()
    try:
        output, registry = extract(args.place.resolve())
    except (ValueError, OSError, ET.ParseError, KeyError) as error:
        raise SystemExit(str(error)) from error
    if not args.dry_run:
        LIBRARY.parent.mkdir(parents=True, exist_ok=True)
        xml_temp = LIBRARY.with_suffix(".rbxmx.tmp")
        registry_temp = REGISTRY.with_suffix(".json.tmp")
        ET.ElementTree(output).write(xml_temp, encoding="utf-8", xml_declaration=True)
        registry_temp.write_text(json.dumps(registry, indent=2) + "\n")
        xml_temp.replace(LIBRARY)
        registry_temp.replace(REGISTRY)
    print(f"{'VALIDATED' if args.dry_run else 'EXTRACTED'} {len(registry['pieces'])} vista models, "
          f"{registry['meshParts']} uploaded meshes, {registry['distinctTextureIds']} texture/pack IDs, "
          f"{registry['referencedSharedStrings']} SharedStrings" + ("" if args.dry_run else f" -> {LIBRARY}"))


if __name__ == "__main__":
    main()

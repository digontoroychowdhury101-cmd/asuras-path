"""Extract one bound production skin template (ServerStorage.AsuraAssets.<name>) from a Studio-saved XML place.

    python tools/assets/extract_skin.py outputs/opening-cast/monk/monk_import_capture.rbxlx AsuraBoss_CorruptWanderingMonk

Same rules as extract_guardian_lion.py: copies the complete imported subtree and its SharedStrings, never uploads or
invents ids. Validates what BossSkin.attach needs: every MeshPart has a real uploaded MeshId, a SurfaceAppearance with
all four uploaded PBR maps, an AsuraBone attribute and an AsuraBind Attachment, nothing collides, and all 15 R15 limbs
are covered. Writes assets/models/<name>.rbxmx and assets/opening_cast/<name>.uploaded.json (the id registry).
"""
from __future__ import annotations

import argparse
import base64
import copy
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = re.compile(r"rbxassetid://[1-9][0-9]{5,19}")
MAPS = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")
R15 = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
       "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
HELPERS = {"RightPauldron", "LeftPauldron", "ClothFront", "ClothBack"}  # BossRigs builds these on the actor


def name(item: ET.Element) -> str:
    return item.findtext('Properties/string[@name="Name"]') or ""


def content(item: ET.Element, key: str) -> str:
    return (item.findtext(f'Properties/Content[@name="{key}"]/url')
            or item.findtext(f'Properties/ContentId[@name="{key}"]/url') or "").strip()


def attributes(item: ET.Element) -> dict[str, str]:
    """String attributes from the serialized AttributesSerialize blob (u32 count, then key / type / value)."""
    blob = item.findtext('Properties/BinaryString[@name="AttributesSerialize"]') or ""
    raw = base64.b64decode(blob) if blob.strip() else b""
    out, i = {}, 0

    def u32():
        nonlocal i
        v = int.from_bytes(raw[i:i + 4], "little")
        i += 4
        return v
    if not raw:
        return out
    for _ in range(u32()):
        n = u32()
        k = raw[i:i + n].decode()
        i += n
        kind = raw[i]
        i += 1
        if kind == 0x02:      # string
            n = u32()
            out[k] = raw[i:i + n].decode()
            i += n
        elif kind == 0x03:    # bool
            i += 1
        elif kind == 0x06:    # double
            i += 8
        else:
            break
    return out


def boolean(item: ET.Element, key: str) -> bool:
    return (item.findtext(f'Properties/bool[@name="{key}"]') or "").strip() == "true"


def extract(place: Path, model_name: str) -> tuple[ET.Element, dict]:
    tree = ET.parse(place).getroot()
    servers = [i for i in tree.findall("Item") if i.attrib.get("class") == "ServerStorage"]
    if len(servers) != 1:
        raise ValueError("Expected exactly one ServerStorage")
    found = [i for i in servers[0].iter("Item") if i.attrib.get("class") == "Model" and name(i) == model_name]
    if len(found) != 1:
        raise ValueError(f"Expected one ServerStorage Model {model_name}, found {len(found)}")
    model = found[0]
    parts, bones = {}, set()
    for mesh in model.iter("Item"):
        if mesh.attrib.get("class") != "MeshPart":
            continue
        label = name(mesh)
        ids = {"MeshId": content(mesh, "MeshId")}
        surfaces = [i for i in mesh.findall("Item") if i.attrib.get("class") == "SurfaceAppearance"]
        if len(surfaces) != 1:
            raise ValueError(f"{label}: expected one SurfaceAppearance")
        ids.update({key: content(surfaces[0], key) for key in MAPS})
        for key, value in ids.items():
            if not ID.fullmatch(value):
                raise ValueError(f"{label}: missing real uploaded {key} ({value!r})")
        bone = attributes(mesh).get("AsuraBone")
        if bone not in R15 | HELPERS:
            raise ValueError(f"{label}: AsuraBone {bone!r} is not an R15 limb or BossRigs helper")
        if not any(i.attrib.get("class") == "Attachment" and name(i) == "AsuraBind" for i in mesh.findall("Item")):
            raise ValueError(f"{label}: missing AsuraBind Attachment")
        if boolean(mesh, "CanCollide") or boolean(mesh, "CanQuery") or boolean(mesh, "CanTouch"):
            raise ValueError(f"{label}: skin geometry must not collide, query or touch")
        bones.add(bone)
        parts[label] = {"bone": bone, **ids}
    if R15 - bones:
        raise ValueError("Missing R15 limbs: " + ", ".join(sorted(R15 - bones)))
    root = ET.Element("roblox", {"version": "4"})
    ET.SubElement(root, "External").text = "null"
    ET.SubElement(root, "External").text = "nil"
    root.append(copy.deepcopy(model))
    references = {v.text.strip() for v in model.iter("SharedString") if v.text and v.text.strip()}
    have = set()
    if references:
        target = ET.SubElement(root, "SharedStrings")
        source = tree.find("SharedStrings")
        for shared in source if source is not None else []:
            if shared.attrib.get("md5", "") in references:
                target.append(copy.deepcopy(shared))
                have.add(shared.attrib["md5"])
        if references - have:
            raise ValueError("Missing imported SharedStrings: " + ", ".join(sorted(references - have)))
    record = {"model": model_name, "importer": "Roblox Studio 3D Importer, Creator: Me", "parts": parts,
              "sharedStringCount": len(have),
              "validation": "15 uploaded MeshParts, complete uploaded PBR, AsuraBone + AsuraBind on each, non-colliding"}
    return root, record


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place", type=Path)
    parser.add_argument("model")
    args = parser.parse_args()
    root, record = extract(args.place, args.model)
    record["savedPlace"] = str(args.place)
    out = ROOT / "assets/models" / f"{args.model}.rbxmx"
    temporary = out.with_suffix(".rbxmx.tmp")
    ET.ElementTree(root).write(temporary, encoding="utf-8", xml_declaration=True)
    ET.parse(temporary)
    temporary.replace(out)
    registry = ROOT / "assets/opening_cast" / f"{args.model}.uploaded.json"
    registry.write_text(json.dumps(record, indent=2) + "\n")
    print(f"EXTRACTED {args.model}: {len(record['parts'])} MeshParts, {record['sharedStringCount']} SharedStrings -> {out}")


if __name__ == "__main__":
    main()

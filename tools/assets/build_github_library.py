"""Build a browsable Roblox media library from verified uploaded GitHub asset IDs."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
uploaded = json.loads((ROOT / "assets/GITHUB_UPLOADED.json").read_text())
root = ET.Element("roblox", version="4")
folder = ET.SubElement(root, "Item", {"class": "Folder", "referent": "GithubAssets"})
props = ET.SubElement(folder, "Properties")
ET.SubElement(props, "string", name="Name").text = "GithubAssets"
count = 0
for section, kind, field in [("Textures", "Decal", "Texture"), ("Audio", "Sound", "SoundId")]:
    for name, asset_id in uploaded[section].items():
        item = ET.SubElement(folder, "Item", {"class": kind, "referent": name})
        props = ET.SubElement(item, "Properties")
        ET.SubElement(props, "string", name="Name").text = name
        content = ET.SubElement(props, "Content", name=field)
        ET.SubElement(content, "url").text = asset_id
        if kind == "Sound":
            ET.SubElement(props, "float", name="Volume").text = "0.45"
            ET.SubElement(props, "bool", name="Playing").text = "false"
        by = "Effekseer / AndrewFM" if kind == "Decal" else "Godot demo sources / FFeller / dorian.mastin" if name.endswith("Impact") else "Sparklin Labs / Pixel-boy"
        credit = ET.SubElement(item, "Item", {"class": "StringValue", "referent": name + "_Credit"})
        credit_props = ET.SubElement(credit, "Properties")
        ET.SubElement(credit_props, "string", name="Name").text = "LicenseAndSource"
        ET.SubElement(credit_props, "string", name="Value").text = "CC0-1.0 | " + by + " | assets/GITHUB_REUSE.json; assets/GITHUB_SUPERPOWERS.json"
        count += 1
ET.indent(root)
ET.ElementTree(root).write(ROOT / "assets/models/AsuraGithubMedia.rbxmx", encoding="utf-8", xml_declaration=True)
print(f"Built GitHub media library: {count} templates; no auto-playing sounds")

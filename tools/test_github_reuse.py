"""Verify source provenance and the actual prepared PNG/WAV payloads, then run Luau rules."""
from pathlib import Path
import array
import hashlib
import json
import re
import struct
import subprocess
import wave
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "assets/GITHUB_REUSE.json").read_text())
shared_tree = json.loads((ROOT / "default.project.json").read_text())["tree"]["ReplicatedStorage"]["AsurasPath"]["Shared"]
for module in ("EffectEasing", "MonasteryRidgeProfile"):
    assert shared_tree[module]["$path"] == f"src/shared/{module}.luau", f"Unmapped runtime dependency: {module}"
for entry in json.loads((ROOT / "assets/GITHUB_CODE_SOURCES.json").read_text()):
    data = (ROOT / entry["file"]).read_bytes()
    assert hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest() == entry["blob_sha"], entry["file"]
for repo in manifest["repositories"]:
    assert repo["stars"] > 1000 and len(repo["commit"]) == 40
uploaded = json.loads((ROOT / "assets/GITHUB_UPLOADED.json").read_text())
registry = (ROOT / "src/shared/PresentationAssets.luau").read_text()
for section in ("Textures", "Audio"):
    for slot, asset_id in uploaded[section].items():
        assert re.fullmatch(r"rbxassetid://[1-9][0-9]+", asset_id)
        assert f'{slot} = "{asset_id}"' in registry, slot
for entry in manifest["files"]:
    raw = (ROOT / entry["file"]).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == entry["sha256"], entry["file"]
    assert entry["license"] == "CC0-1.0"
    if "lfs_sha256" in entry:
        assert hashlib.sha256(raw).hexdigest() == entry["lfs_sha256"]
    else:
        assert hashlib.sha1(f"blob {len(raw)}\0".encode() + raw).hexdigest() == entry["blob_sha"]
    prepared = ROOT / entry["prepared_file"]
    assert hashlib.sha256(prepared.read_bytes()).hexdigest() == entry["prepared_sha256"]
    if entry["section"] == "Textures":
        header = prepared.read_bytes()[:29]
        assert header[:8] == b"\x89PNG\r\n\x1a\n"
        width, height, depth, color = struct.unpack(">IIBB", header[16:26])
        assert 0 < width <= 1024 and 0 < height <= 1024 and (depth, color) == (8, 6)
    else:
        with wave.open(str(prepared)) as wav:
            assert (wav.getnchannels(), wav.getframerate(), wav.getsampwidth()) == (1, 48000, 2)
            samples = array.array("h", wav.readframes(wav.getnframes()))
            assert len(samples) > 0 and max(abs(s) for s in samples) <= 16423
            assert abs(sum(samples) / len(samples) / 32768) < 0.003
library = ET.parse(ROOT / "assets/models/AsuraGithubMedia.rbxmx").getroot().find("Item")
expected_ids = set(uploaded["Audio"].values()) | set(uploaded["Textures"].values())
library_ids = {item.findtext("Properties/Content/url") for item in library.findall("Item")}
assert expected_ids == library_ids, "Studio library and source registry differ"
extra = json.loads((ROOT / "assets/GITHUB_SUPERPOWERS.json").read_text())
assert extra["stars"] > 1000 and extra["license"] == "CC0-1.0"
for entry in extra["files"]:
    raw = (ROOT / entry["file"]).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == entry["sha256"]
    assert hashlib.sha1(f"blob {len(raw)}\0".encode() + raw).hexdigest() == entry["blob_sha"]
    if entry["kind"] == "animation-source":
        assert ET.parse(ROOT / entry["file"]).getroot().tag.endswith("COLLADA")
    else:
        prepared = (ROOT / entry["prepared_file"]).read_bytes()
        assert hashlib.sha256(prepared).hexdigest() == entry["prepared_sha256"]
research = json.loads((ROOT / "assets/GITHUB_RESEARCH.json").read_text())
assert research["counts"]["candidates"] == len(research["repositories"])
assert research["counts"]["above_1000_stars"] == sum(r.get("stars", 0) > 1000 for r in research["repositories"])
print(f"PASS: {len(manifest['repositories'])} qualifying pinned repositories, {len(manifest['files'])} verified CC0 assets")
subprocess.run([str(ROOT / "work/bin/luau/luau"), "tools/test_github_reuse.luau"], cwd=ROOT, check=True)

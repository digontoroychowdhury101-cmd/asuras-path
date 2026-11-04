"""Add the Iron Bull's read-back ids to the boss animation folder the game loads.

    python3 tools/animation/opening_cast/register_bull.py

Reads assets/animations/opening_cast/bull/published.json (publish.py: only clips whose keyframe count read back) and merges them into
assets/animations/general_zhao/AsuraBossAnimations.model.json next to Zhao's; his entries are untouched.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FOLDER = ROOT / "assets/animations/general_zhao/AsuraBossAnimations.model.json"
published = json.loads((ROOT / "assets/animations/opening_cast/bull/published.json").read_text())
manifest = json.loads((ROOT / "assets/animations/opening_cast/bull/manifest.json").read_text())["clips"]
missing = sorted(set(manifest) - set(published))
if missing:
    raise SystemExit("not published: " + ", ".join(missing))
data = json.loads(FOLDER.read_text())
data["children"] = [c for c in data["children"] if not c["name"].startswith("IronBull_")]
for name, record in sorted(published.items()):
    data["children"].append({"name": name, "className": "Animation", "properties": {"AnimationId": record["id"]}})
FOLDER.write_text(json.dumps(data, indent=2) + "\n")
print(len(data["children"]), "animations,", len(published), "IronBull")

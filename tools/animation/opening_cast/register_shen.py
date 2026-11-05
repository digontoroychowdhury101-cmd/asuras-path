"""Add Grandmaster Shen's read-back ids to the boss animation folder the game loads.

    python3 tools/animation/opening_cast/register_shen.py

Reads assets/animations/opening_cast/shen/published.json (publish.py: only clips whose keyframe count read back) and merges them into
assets/animations/general_zhao/AsuraBossAnimations.model.json; Zhao's and the Bull's entries are untouched.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FOLDER = ROOT / "assets/animations/general_zhao/AsuraBossAnimations.model.json"
published = json.loads((ROOT / "assets/animations/opening_cast/shen/published.json").read_text())
manifest = json.loads((ROOT / "assets/animations/opening_cast/shen/manifest.json").read_text())["clips"]
missing = sorted(set(manifest) - set(published))
if missing:
    raise SystemExit("not published: " + ", ".join(missing))
data = json.loads(FOLDER.read_text())
data["children"] = [c for c in data["children"] if not c["name"].startswith("GrandmasterShen_")]
for name, record in sorted(published.items()):
    data["children"].append({"name": name, "className": "Animation", "properties": {"AnimationId": record["id"]}})
FOLDER.write_text(json.dumps(data, indent=2) + "\n")
print(len(data["children"]), "animations,", len(published), "GrandmasterShen")

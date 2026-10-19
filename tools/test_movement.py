#!/usr/bin/env python3
"""Exercise the real movement, procedural effects and input modules with deterministic engine fakes."""
from pathlib import Path
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sources = [
    ("CombatSettings", "src/shared/CombatSettings.luau"),
    ("InputBuffer", "src/simulation/InputBuffer.luau"),
    ("MovementMath", "src/client/Controllers/MovementMath.luau"),
    ("MovementEffects", "src/client/Controllers/MovementEffects.luau"),
    ("MovementController", "src/client/Controllers/MovementController.luau"),
    ("InputController", "src/client/Controllers/InputController.luau"),
]
harness = (ROOT / "tools/test_movement.luau").read_text()
def replica(node, name=""):
    if "$path" in node:
        return json.dumps(name)
    children = [f"[{json.dumps(key)}]={replica(value, key)}" for key, value in node.items()
                if not key.startswith("$") and isinstance(value, dict)]
    return "tree({" + ",".join(children) + "})"

project = json.loads((ROOT / "default.project.json").read_text())
harness = harness.replace("tree({}) -- REPLICATION_INSERT", replica(project["tree"]["ReplicatedStorage"]))
chunks = []
for name, path in sources:
    source = (ROOT / path).read_text()
    source = re.sub(r"^export type", "type", source, flags=re.MULTILINE)
    if name == "InputBuffer":
        source = source.replace("require(script.Parent.Parent.Shared.CombatSettings)", 'require("CombatSettings")')
    chunks.append(f'registry["{name}"] = (function()\n{source}\nend)()')
generated = ROOT / "work/test_movement.generated.luau"
generated.parent.mkdir(exist_ok=True)
generated.write_text(harness.replace("-- MODULES_INSERT", "\n".join(chunks)))
sys.exit(subprocess.run([str(ROOT / "work/bin/luau/luau"), str(generated)], cwd=ROOT).returncode)

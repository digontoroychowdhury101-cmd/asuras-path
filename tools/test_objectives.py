#!/usr/bin/env python3
"""Runs tools/test_objectives.luau with src/shared/Objectives.luau inlined after the Vector3 shim."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
name = sys.argv[1] if len(sys.argv) > 1 else "test_objectives"
test = (root / "tools" / (name + ".luau")).read_text()
module = (root / "src" / "shared" / "Objectives.luau").read_text()
marker = 'local Objectives = require("../src/shared/Objectives")'
assert marker in test, "require marker missing from test"
# Type exports are only legal at chunk scope; inlined inside a function they become local types.
module = re.sub(r"^export type", "type", module, flags=re.MULTILINE)
ending = (root / "src" / "shared" / "EndingRules.luau").read_text()
ending = re.sub(r"^export type", "type", ending, flags=re.MULTILINE)
module = module.replace('if hasScript then require(script.Parent.EndingRules) else require("./EndingRules")', "(function()\n" + ending + "\nend)()", 1)
overworld = (root / "src" / "shared" / "Overworld.luau").read_text()
if name == "test_objectives": # the archived-corridor objectives run on the pre-cutover world; the overworld suite keeps Active
    overworld = overworld.replace("Overworld.Active = true", "Overworld.Active = false", 1)
module = module.replace('if hasScript then require(script.Parent.Overworld) else require("./Overworld")', "(function()\n" + overworld + "\nend)()", 1)
inlined = "local Objectives = (function()\n" + module + "\nend)()"
generated = root / "work" / (name + ".generated.luau")
generated.write_text(test.replace(marker, inlined, 1))
luau = root / "work" / "bin" / "luau" / "luau"
result = subprocess.run([str(luau), str(generated.relative_to(root))], cwd=root)
sys.exit(result.returncode)

#!/usr/bin/env python3
"""Runs tools/test_objectives.luau with src/shared/Objectives.luau inlined after the Vector3 shim."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
test = (root / "tools" / "test_objectives.luau").read_text()
module = (root / "src" / "shared" / "Objectives.luau").read_text()
marker = 'local Objectives = require("../src/shared/Objectives")'
assert marker in test, "require marker missing from test"
# Type exports are only legal at chunk scope; inlined inside a function they become local types.
module = re.sub(r"^export type", "type", module, flags=re.MULTILINE)
inlined = "local Objectives = (function()\n" + module + "\nend)()"
generated = root / "work" / "test_objectives.generated.luau"
generated.write_text(test.replace(marker, inlined, 1))
luau = root / "work" / "bin" / "luau" / "luau"
result = subprocess.run([str(luau), str(generated.relative_to(root))], cwd=root)
sys.exit(result.returncode)

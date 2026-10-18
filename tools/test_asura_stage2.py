#!/usr/bin/env python3
"""Runs tools/test_asura_stage2.luau with src/server/LagCompensation.luau inlined after the Roblox type shim."""
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
test = (root / "tools" / "test_asura_stage2.luau").read_text()
module = (root / "src" / "server" / "LagCompensation.luau").read_text()
marker = 'local Lag = require("../src/server/LagCompensation")'
assert marker in test, "require marker missing from test"
inlined = "local Lag = (function()\n" + module + "\nend)()"
generated = root / "work" / "test_asura_stage2.generated.luau"
generated.write_text(test.replace(marker, inlined, 1))
luau = root / "work" / "bin" / "luau" / "luau"
result = subprocess.run([str(luau), str(generated.relative_to(root))], cwd=root)
sys.exit(result.returncode)

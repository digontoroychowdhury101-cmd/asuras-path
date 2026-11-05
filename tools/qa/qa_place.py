#!/usr/bin/env python3
"""Build a private QA copy of the place with unmapped probe scripts already in ServerScriptService.

    python3 tools/qa/qa_place.py OUTPUT.rbxlx tools/qa/ArmorProbe.server.luau [more probes]

Newer Studio builds refuse `qa_inject.py` (the MCP thread may not parent a Script into ServerScriptService), so a probe has to be in the
file Studio opens. The copy lives wherever OUTPUT says, outside the repository; the canonical place and project file are never written.
Never publish it and never save it back. Evidence type of anything a probe does: seeded Studio diagnostic.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from build import binary  # noqa: E402


def absolute(node: dict) -> None:
    for key, value in node.items():
        if key == '$path':
            node[key] = str(ROOT / value)
        elif isinstance(value, dict):
            absolute(value)


def main() -> int:
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    project = json.loads((ROOT / 'default.project.json').read_text())
    absolute(project['tree'])
    service = project['tree']['ServerScriptService']
    for probe in sys.argv[2:]:
        path = (ROOT / probe).resolve()
        service['QA_' + path.name.split('.')[0]] = {'$path': str(path)}
    with tempfile.TemporaryDirectory() as tmp:
        spec = Path(tmp) / 'qa.project.json'
        spec.write_text(json.dumps(project))
        subprocess.run([binary('rojo', 'rojo'), 'build', str(spec), '--output', sys.argv[1]], check=True)
    print('QA place (seeded diagnostics only, never publish):', os.path.abspath(sys.argv[1]))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Insert one unmapped QA script into a running Studio Play session (local QA only).

    python3 tools/qa/qa_inject.py tools/qa/TwinsProbe.server.luau [STUDIO]

A `.server.luau` file goes into ServerScriptService as a Script, a `.client.luau` file into the
player's PlayerScripts as a LocalScript. Nothing is saved or published; Stop removes it. Re-run
after every Play. Evidence type of anything the script does: seeded Studio diagnostic.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import studio_mcp  # noqa: E402
from human_playtest import INSERT, call  # noqa: E402


def main() -> int:
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    path = Path(sys.argv[1])
    want = sys.argv[2] if len(sys.argv) > 2 else 'AsurasPath'
    client = studio_mcp.Client()
    studios = json.loads(client.call('list_roblox_studios', {})[1])['studios']
    match = [s for s in studios if want in (s.get('name') or '')] or studios
    if not match:
        raise SystemExit('No Studio is open.')
    sid = match[0]['id']
    name = 'QA_' + path.name.split('.')[0]
    source = path.read_text()
    if path.name.endswith('.server.luau'):
        print(call(client, sid, 'Server', INSERT % ('game:GetService("ServerScriptService")', name, 'Script', name, source, name)))
    else:
        holder = 'game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")'
        print(call(client, sid, 'Client', INSERT % (holder, name, 'LocalScript', name, source, name)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

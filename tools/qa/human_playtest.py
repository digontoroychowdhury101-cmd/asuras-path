#!/usr/bin/env python3
"""Load the human-playtest station panel into a running Studio Play session (local QA only).

    python3 tools/qa/human_playtest.py [STUDIO]

Press Play in Studio first (one player). This inserts tools/qa/HumanPlaytest.server.luau into
ServerScriptService and HumanPlaytest.client.luau into the player's PlayerScripts. Nothing is saved
or published; pressing Stop removes both. Re-run after every Play. Evidence type of anything done
with the panel: seeded placement + real human input, never earned play.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import studio_mcp  # noqa: E402

HERE = Path(__file__).resolve().parent
INSERT = '''local holder = %s
local old = holder:FindFirstChild("%s")
if old then old:Destroy() end
local s = Instance.new("%s")
s.Name = "%s"
s.Source = [==[%s]==]
s.Parent = holder
return "inserted %s"'''


def call(client: studio_mcp.Client, sid: str, model: str, code: str) -> str:
    reply = client.request('tools/call', {'name': 'execute_luau', 'arguments':
                                          {'code': code, 'datamodel_type': model, 'studio_id': sid}}, timeout=60)
    result = reply.get('result') or {}
    text = ' '.join(c.get('text', '') for c in result.get('content') or [] if c.get('type') == 'text')
    if reply.get('error') or result.get('isError'):
        raise SystemExit(f'{model} failed: {reply.get("error") or text}')
    return text


def main() -> int:
    want = sys.argv[1] if len(sys.argv) > 1 else 'AsurasPath'
    client = studio_mcp.Client()
    studios = json.loads(client.call('list_roblox_studios', {})[1])['studios']
    match = [s for s in studios if want in (s.get('name') or '')] or studios
    if not match:
        raise SystemExit('No Studio is open. Open places/AsurasPath.rbxlx in Studio and press Play.')
    sid = match[0]['id']
    state = client.call('get_studio_state', {'studio_id': sid})[1]
    if 'Server' not in state or 'Client' not in state:
        raise SystemExit('Studio is not in Play. Press Play (one player), wait for the world, then run this again.')
    server = (HERE / 'HumanPlaytest.server.luau').read_text()
    panel = (HERE / 'HumanPlaytest.client.luau').read_text()
    print(call(client, sid, 'Server', INSERT % ('game:GetService("ServerScriptService")', 'AsuraHumanPlaytest', 'Script',
                                                'AsuraHumanPlaytest', server, 'server kit')))
    print(call(client, sid, 'Client', INSERT % ('game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")',
                                                'AsuraHumanPlaytestPanel', 'LocalScript', 'AsuraHumanPlaytestPanel', panel,
                                                'panel')))
    print('Playtest panel loaded. In Studio: hold Alt and click a station on the left.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Push this checkout's scripts (and MaterialService variants) into an open Studio place (Edit mode).

    python3 tools/qa/studio_sync.py STUDIO [--dry-run]

A one-way, script-only stand-in for Rojo live sync during local QA: it never touches models,
MeshParts or the asset libraries (live sync cannot populate MeshIds), never saves the place and
never publishes. Scripts are compared with the same 31-multiplier hash as tools/qa/SourceDigest.luau
and only differing or missing ones are written. Run `python3 tools/build.py` for the real place.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import studio_mcp  # noqa: E402
from lobby_capture import run, studio_id  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SERVICES = {'Lighting', 'Players', 'ReplicatedFirst', 'ReplicatedStorage', 'ServerScriptService', 'ServerStorage',
            'StarterPlayer', 'Workspace', 'MaterialService', 'StarterGui', 'SoundService'}


def scripts() -> dict[tuple[str, ...], tuple[str, str]]:
    found: dict[tuple[str, ...], tuple[str, str]] = {}

    def walk(node: dict, trail: tuple[str, ...]) -> None:
        path = node.get('$path')
        if path and path.endswith('.luau'):
            cls = 'Script' if path.endswith('.server.luau') else 'LocalScript' if path.endswith('.client.luau') else 'ModuleScript'
            found[trail] = (cls, (ROOT / path).read_text())
        for key, child in node.items():
            if not key.startswith('$') and isinstance(child, dict):
                walk(child, trail + (key,))
    tree = json.loads((ROOT / 'default.project.json').read_text())['tree']
    for key, child in tree.items():
        if key in SERVICES and isinstance(child, dict):
            walk(child, (key,))
    return found


def digest(source: str) -> int:
    value = 0
    for byte in source.replace('\r', '').encode('utf-8'):
        value = (value * 31 + byte) % 2147483647
    return value


def lua_string(text: str) -> str:
    level = 1
    while f']{"=" * level}]' in text:
        level += 1
    return f'[{"=" * level}[\n{text}]{"=" * level}]'


HASH = """local HttpService = game:GetService("HttpService")
local out = {}
for _, root in { game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer"), game:GetService("ReplicatedFirst") } do
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			local s, v = (d :: any).Source, 0
			for i = 1, #s do v = (v * 31 + string.byte(s, i)) % 2147483647 end
			out[d:GetFullName()] = v
		end
		if _ % 2000 == 0 then task.wait() end
	end
end
return HttpService:JSONEncode(out)
"""

ENSURE = """local function ensure(path, class)
	local node = game:GetService(path[1])
	for i = 2, #path do
		local child = node:FindFirstChild(path[i])
		if not child then
			child = Instance.new(if i == #path then class else "Folder")
			child.Name = path[i]
			child.Parent = node
		end
		node = child
	end
	return node
end
"""


def variants() -> str:
    tree = json.loads((ROOT / 'default.project.json').read_text())['tree']
    lines = ['local ms = game:GetService("MaterialService")']
    for name, node in (tree.get('MaterialService') or {}).items():
        if name.startswith('$'):
            continue
        p = node['$properties']
        lines.append(f'do local v = ms:FindFirstChild("{name}") or Instance.new("MaterialVariant") v.Name = "{name}" '
                     f'v.BaseMaterial = Enum.Material.{p["BaseMaterial"]} v.StudsPerTile = {p["StudsPerTile"]}')
        for key in ('ColorMapContent', 'NormalMapContent', 'RoughnessMapContent', 'MetalnessMapContent'):
            lines.append(f'v.{key} = Content.fromUri("{p[key]}")')
        lines.append('v.Parent = ms end')
    lines.append('return "variants " .. #ms:GetChildren()')
    return '\n'.join(lines)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    client = studio_mcp.Client()
    try:
        sid = studio_id(client, sys.argv[1])
        ok, text = client.call('execute_luau', {'code': HASH, 'datamodel_type': 'Edit', 'studio_id': sid})
        if not ok:
            raise SystemExit('hash failed: ' + text)
        remote = json.loads(text)
        pending = [(trail, cls, src) for trail, (cls, src) in scripts().items() if remote.get('.'.join(trail)) != digest(src)]
        print(f'{len(pending)} scripts differ:', ', '.join(t[-1] for t, _, _ in pending))
        if '--dry-run' in sys.argv:
            return 0
        batch, size, calls = [], 0, []
        for trail, cls, src in pending:
            path = '{' + ', '.join(json.dumps(t) for t in trail) + '}'
            chunk = f'ensure({path}, "{cls}").Source = {lua_string(src)}\n'
            if size + len(chunk) > 150_000 and batch:
                calls.append(['__lua', 'Edit', ENSURE + ''.join(batch) + 'return "synced"'])
                batch, size = [], 0
            batch.append(chunk)
            size += len(chunk)
        if batch:
            calls.append(['__lua', 'Edit', ENSURE + ''.join(batch) + 'return "synced"'])
        calls.append(['__lua', 'Edit', variants()])
        return 1 if run(client, sid, calls, ROOT / 'outputs') else 0
    finally:
        client.close()


if __name__ == '__main__':
    sys.exit(main())

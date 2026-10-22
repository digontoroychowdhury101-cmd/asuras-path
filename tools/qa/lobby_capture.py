#!/usr/bin/env python3
"""Sanctuary lobby QA through Studio's bundled MCP proxy (local only; never publishes).

    python3 tools/qa/lobby_capture.py studios
    python3 tools/qa/lobby_capture.py shots STUDIO OUTDIR PREFIX [entrance,elevated,...]
    python3 tools/qa/lobby_capture.py calls STUDIO calls.json [OUTDIR]

STUDIO is a substring of the Studio place name (list_roblox_studios) or an id prefix.
`shots` must run during Play: it hides the local ScreenGuis, pins the client camera to each fixed
comparison camera below with a late RenderStep binding, captures, then restores camera and HUD.
The same cameras produced the before and after images in outputs/lobby-rebuild-2026-10-21/.
`calls` runs [["tool", {args}] | ["__sleep", s] | ["__lua", "Edit|Server|Client", code-or-file]].
Evidence type: seeded Studio captures, not earned play.
"""
from __future__ import annotations

import base64
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import studio_mcp  # noqa: E402

# name: (camera position, look-at, field of view); plaza centre is (0, 600, 900), north is -Z.
CAMERAS = {
    'entrance': ((0, 609, 950), (0, 619, 850), 70),
    'elevated': ((70, 700, 1040), (0, 610, 860), 60),
    'gameplay': ((0, 606.5, 934), (0, 607, 880), 70),
    'terrace': ((0, 636, 786), (0, 668, 700), 70),
    'forge': ((-40, 612, 915), (-84, 606, 900), 70),
    'duel': ((40, 612, 915), (94, 606, 900), 70),
    'aerial': ((0, 900, 1150), (0, 620, 800), 60),
}

PIN = """local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
for _, g in pg:GetChildren() do
	if g:IsA("ScreenGui") and g.Enabled then g:SetAttribute("ShotHidden", true); g.Enabled = false end
end
pcall(function() RunService:UnbindFromRenderStep("AsuraShot") end)
local cf = CFrame.lookAt(Vector3.new(%s), Vector3.new(%s))
RunService:BindToRenderStep("AsuraShot", Enum.RenderPriority.Last.Value + 50, function()
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = %s
	cam.CFrame = cf
end)
return "pinned"
"""

RELEASE = """local RunService = game:GetService("RunService")
pcall(function() RunService:UnbindFromRenderStep("AsuraShot") end)
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
for _, g in pg:GetChildren() do
	if g:IsA("ScreenGui") and g:GetAttribute("ShotHidden") then g:SetAttribute("ShotHidden", nil); g.Enabled = true end
end
return "released"
"""


def studio_id(client: studio_mcp.Client, want: str) -> str:
    studios = json.loads(client.call('list_roblox_studios', {})[1])['studios']
    for s in studios:
        if want in (s.get('name') or '') or s['id'].startswith(want):
            return s['id']
    raise SystemExit(f'No Studio matches {want!r}: {studios}')


def run(client: studio_mcp.Client, sid: str, calls: list, outdir: Path) -> int:
    failed = 0
    for i, call in enumerate(calls):
        name = call[0]
        if name == '__sleep':
            time.sleep(float(call[1]))
            continue
        if name == '__lua':
            code = call[2]
            if code.endswith('.luau') and os.path.exists(code):
                code = Path(code).read_text()
            name, args = 'execute_luau', {'code': code, 'datamodel_type': call[1]}
        else:
            args = dict(call[1])
        args['studio_id'] = sid
        reply = client.request('tools/call', {'name': name, 'arguments': args}, timeout=float(os.environ.get('MCP_TIMEOUT', '240')))
        result = reply.get('result') or {}
        error = bool(reply.get('error') or result.get('isError'))
        failed += error
        lines = []
        for k, content in enumerate(result.get('content') or []):
            if content.get('type') == 'text':
                lines.append(content.get('text', ''))
            elif content.get('type') == 'image':
                ext = 'png' if 'png' in content.get('mimeType', '') else 'jpg'
                stem = args.get('capture_id', f'call{i}') + ('' if k == 0 else f'_{k}')
                path = outdir / f'{stem}.{ext}'
                path.write_bytes(base64.b64decode(content['data']))
                lines.append(f'[image {path}]')
        if reply.get('error'):
            lines.append(json.dumps(reply['error']))
        print(f'CALL {name} {"ERROR" if error else "ok"}\n' + '\n'.join(lines)[:int(os.environ.get('MCP_LIMIT', '8000'))])
    return failed


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    client = studio_mcp.Client()
    try:
        if sys.argv[1] == 'studios':
            print(client.call('list_roblox_studios', {})[1])
            return 0
        sid = studio_id(client, sys.argv[2])
        if sys.argv[1] == 'shots':
            outdir, prefix = Path(sys.argv[3]), sys.argv[4]
            only = sys.argv[5].split(',') if len(sys.argv) > 5 else list(CAMERAS)
            outdir.mkdir(parents=True, exist_ok=True)
            calls = []
            for name in only:
                cam, look, fov = CAMERAS[name]
                calls += [['__lua', 'Client', PIN % (','.join(map(str, cam)), ','.join(map(str, look)), fov)],
                          ['__sleep', 2.5], ['screen_capture', {'capture_id': f'{prefix}_{name}'}]]
            calls.append(['__lua', 'Client', RELEASE])
            return 1 if run(client, sid, calls, outdir) else 0
        if sys.argv[1] == 'calls':
            outdir = Path(sys.argv[4]) if len(sys.argv) > 4 else Path(sys.argv[3]).resolve().parent
            outdir.mkdir(parents=True, exist_ok=True)
            return 1 if run(client, sid, json.loads(Path(sys.argv[3]).read_text()), outdir) else 0
        print(__doc__)
        return 2
    finally:
        client.close()


if __name__ == '__main__':
    sys.exit(main())

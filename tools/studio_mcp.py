#!/usr/bin/env python3
"""Minimal stdio client for Roblox Studio's bundled MCP proxy (local QA only; never publishes).

Use it when the agent session has no Studio MCP tools registered. It spawns
/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP, which joins the local Studio hub, then
runs an ordered list of tool calls from a JSON file: [["tool", {args}], ["__sleep", seconds], ...].

    python3 tools/studio_mcp.py --list                      # tool names + connected Studio ids
    python3 tools/studio_mcp.py calls.json                  # run calls, print each text result
    python3 tools/studio_mcp.py --digest PLACE.rbxlx        # expected script digest of a build

--digest matches tools/qa/SourceDigest.luau run in Studio (execute_luau, Edit): equal script count,
byte count and digest prove the open place holds exactly that build's scripts. Evidence type:
seeded Studio diagnostic. It is not real or earned play.
"""
from __future__ import annotations
import argparse
import json
import select
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

BIN = '/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP'
ROOTS = ('Lighting', 'Players', 'ReplicatedFirst', 'ReplicatedStorage', 'ServerScriptService',
         'ServerStorage', 'StarterPlayer', 'Workspace')
SCRIPTS = {'Script', 'LocalScript', 'ModuleScript'}


class Client:
    def __init__(self) -> None:
        self.proc = subprocess.Popen([BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL, text=True, bufsize=1)
        self.next_id = 1
        self.request('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {},
                                    'clientInfo': {'name': 'asura-qa', 'version': '1'}})
        self.send({'jsonrpc': '2.0', 'method': 'notifications/initialized'})
        time.sleep(1.5)  # the proxy fills its tool list from the hub after initialisation

    def send(self, message: dict) -> None:
        assert self.proc.stdin
        self.proc.stdin.write(json.dumps(message) + '\n')
        self.proc.stdin.flush()

    def request(self, method: str, params: dict, timeout: float = 120) -> dict:
        ident, self.next_id = self.next_id, self.next_id + 1
        self.send({'jsonrpc': '2.0', 'id': ident, 'method': method, 'params': params})
        deadline = time.time() + timeout
        assert self.proc.stdout
        while time.time() < deadline:
            ready, _, _ = select.select([self.proc.stdout], [], [], 0.5)
            if not ready:
                continue
            line = self.proc.stdout.readline()
            if not line:
                break
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if message.get('id') == ident:
                return message
        raise SystemExit(f'StudioMCP: no reply to {method} within {timeout:.0f}s')

    def call(self, name: str, args: dict) -> tuple[bool, str]:
        reply = self.request('tools/call', {'name': name, 'arguments': args})
        result = reply.get('result') or {}
        text = '\n'.join(c.get('text', '') for c in result.get('content') or [] if c.get('type') == 'text')
        return not (reply.get('error') or result.get('isError')), text or json.dumps(reply)

    def close(self) -> None:
        self.proc.terminate()


def digest(place: str) -> str:
    rows: list[tuple[str, str]] = []

    def walk(item: ET.Element, trail: str) -> None:
        props = item.find('Properties')
        props = list(props) if props is not None else []
        name = next((p.text or '' for p in props if p.attrib.get('name') == 'Name'), item.attrib['class'])
        full = f'{trail}.{name}' if trail else name
        if item.attrib['class'] in SCRIPTS:
            source = next((p.text or '' for p in props if p.attrib.get('name') == 'Source'), '')
            rows.append((full, source.replace('\r', '')))
        for child in item.findall('Item'):
            walk(child, full)

    for top in ET.parse(place).getroot().findall('Item'):
        if top.attrib['class'] in ROOTS:
            walk(top, '')
    rows.sort()
    value = 0
    for full, source in rows:
        for byte in (full + '\0' + source + '\0').encode('utf-8'):
            value = (value * 31 + byte) % 2147483647
    return f'scripts {len(rows)} bytes {sum(len(s.encode()) for _, s in rows)} digest {value}'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('calls', nargs='?')
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--digest')
    parser.add_argument('--limit', type=int, default=6000, help='max characters printed per result')
    args = parser.parse_args()
    if args.digest:
        print(digest(args.digest))
        return 0
    client = Client()
    try:
        if args.list or not args.calls:
            tools = client.request('tools/list', {}).get('result', {}).get('tools', [])
            print(f'{len(tools)} tools:', ', '.join(t['name'] for t in tools))
            if tools:
                print(client.call('list_roblox_studios', {})[1])
            return 0 if tools else 1
        failed = 0
        for name, call_args in json.load(open(args.calls)):
            if name == '__sleep':
                time.sleep(float(call_args))
                continue
            ok, text = client.call(name, call_args)
            failed += not ok
            print(f'CALL {name} {"ok" if ok else "error"}\n{text[:args.limit]}')
        return 1 if failed else 0
    finally:
        client.close()


if __name__ == '__main__':
    sys.exit(main())

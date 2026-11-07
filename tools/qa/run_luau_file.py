#!/usr/bin/env python3
"""Run one Luau file in a connected Studio through the bundled MCP proxy and save the result.

    python tools/qa/run_luau_file.py SCRIPT.luau OUT.txt [--mode Edit|Server|Client] [--studio NAME]

Local QA helper for the environment-production batches (read-mostly measurement probes). It never
publishes or saves the place; whatever the probe changes is the probe's own responsibility.
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import Client  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('script')
    ap.add_argument('out')
    ap.add_argument('--mode', default='Edit')
    ap.add_argument('--studio', default='')
    a = ap.parse_args()
    client = Client()
    try:
        ok, listing = client.call('list_roblox_studios', {})
        studios = json.loads(listing).get('studios', [])
        pick = [s for s in studios if a.studio in s.get('name', '')] or studios
        if not pick:
            print('no studio connected')
            return 2
        sid = pick[0]['id']
        code = Path(a.script).read_text(encoding='utf-8')
        ok, text = client.call('execute_luau', {'studio_id': sid, 'datamodel_type': a.mode, 'code': code})
        Path(a.out).write_text(text, encoding='utf-8')
        print(('ok ' if ok else 'error ') + f'{len(text)} chars -> {a.out}')
        if not ok:
            print(text[:2000])
        return 0 if ok else 1
    finally:
        client.close()


if __name__ == '__main__':
    raise SystemExit(main())

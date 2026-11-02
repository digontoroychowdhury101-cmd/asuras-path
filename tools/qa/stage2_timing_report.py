#!/usr/bin/env python3
"""Collect and summarise a Stage2Timing probe run (combat recovery Stage 2).

    python tools/qa/stage2_timing_report.py STUDIO_NAME_PART LABEL [--foreground NAME]

Reads LocalPlayer.AsuraStage2Probe (client) and ServerStorage.AsuraStage2Probe (server) from the running
Play session, saves both raw logs to outputs/combat-recovery-2026-11-02/logs/LABEL_{client,server}.json and
prints a JSON summary (also saved as LABEL_summary.json):
  frames      client frame dt p50/p95/p99 (ms) and the share of frames with the Roblox window focused
  ticks       wall time between server simulation ticks p50/p95/p99 (ms)
  presses     per press: press -> its AsuraAck seen on the client (round trip, client clock only),
              server receipt -> action start (server clock only, paired by the acked sequence number),
              press -> first local Action-priority track (A1, client clock), and the terminal AsuraResult
Clocks are never mixed: server simTime runs in bursts and is only re-synced past 250 ms of drift, so it
is not comparable with the client's GetServerTimeNow (a 1.5 s offset was observed). Evidence: seeded
Studio diagnostic. `--from-logs` re-analyses saved LABEL_{client,server}.json without Studio.
"""
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import studio_mcp  # noqa: E402

LOGS = ROOT / 'outputs' / 'combat-recovery-2026-11-02' / 'logs'
START_STATES = {'Startup', 'Dashing', 'Rolling', 'Deflecting', 'Active'}


def pct(values, q):
    if not values:
        return None
    ordered = sorted(values)
    return round(ordered[min(len(ordered) - 1, int(q * (len(ordered) - 1) + 0.5))], 2)


def fetch(client, sid, dm, code):
    ok, text = client.call('execute_luau', {'studio_id': sid, 'datamodel_type': dm, 'code': code})
    if not ok or not text.strip() or text.strip() == 'nil':
        raise SystemExit(f'{dm} probe not ready: {text[:200]}')
    return json.loads(text)


def terminal(server, seq):
    # Stage 2 terminal record for an intent seq from the server's AsuraIntent values ("seq:status:reason:tick").
    for value in (a['value'] for a in server['acks'] if a['name'] == 'AsuraIntent'):
        for record in str(value).split(';'):
            parts = record.split(':')
            if len(parts) >= 3 and parts[0] == str(seq):
                return parts[1] + ':' + parts[2]
    return None


def main() -> int:
    want, label = sys.argv[1], sys.argv[2]
    foreground = sys.argv[sys.argv.index('--foreground') + 1] if '--foreground' in sys.argv else 'not recorded'
    if '--from-logs' in sys.argv:
        c = json.loads((LOGS / f'{label}_client.json').read_text())
        s = json.loads((LOGS / f'{label}_server.json').read_text())
    else:
        client = studio_mcp.Client()
        studios = json.loads(client.call('list_roblox_studios', {})[1])['studios']
        sid = next(s['id'] for s in studios if want in (s.get('name') or ''))
        c = fetch(client, sid, 'Client', 'return game.Players.LocalPlayer:GetAttribute("AsuraStage2Probe")')
        s = fetch(client, sid, 'Server', 'return game.ServerStorage.AsuraStage2Probe.Value')
        client.close()
        LOGS.mkdir(parents=True, exist_ok=True)
        (LOGS / f'{label}_client.json').write_text(json.dumps(c))
        (LOGS / f'{label}_server.json').write_text(json.dumps(s))

    dts = [f['dt'] for f in c['frames']]
    focus = sum(1 for f in c['frames'] if f['f']) / max(1, len(c['frames']))
    seen_acks = [a for a in c['acks'] if a['name'] == 'AsuraAck']
    server_acks = {a['value']: a for a in s['acks'] if a['name'] == 'AsuraAck'}
    results = [a for a in s['acks'] if a['name'] == 'AsuraResult']
    rows = []
    for press in c['presses']:
        seen = next((a for a in seen_acks if a['t'] >= press['t']), None)
        receipt = server_acks.get(seen['value']) if seen else None
        start = next((st for st in s['states'] if receipt and st['s'] >= receipt['s'] - 1e-6 and st['state'] in START_STATES), None)
        local = next((st for st in c['starts'] if st['t'] >= press['t']), None)
        later = [r for r in results if receipt and r['s'] >= receipt['s'] - 1e-6]
        rows.append({
            'kind': press['kind'],
            'seq': seen['value'] if seen else None,
            'press_to_ack_seen_ms': round((seen['t'] - press['t']) * 1000, 1) if seen and seen['t'] - press['t'] < 1.5 else None,
            'receipt_to_start_ms': round((start['s'] - receipt['s']) * 1000, 1) if start and start['s'] - receipt['s'] < 1.5 else None,
            'start_state': start['state'] if start else None,
            'press_to_local_pose_ms': round((local['t'] - press['t']) * 1000, 1) if local and local['t'] - press['t'] < 1.5 else None,
            'results_after_receipt': [r['value'] for r in later[:2]],
            'terminal': terminal(s, seen['value']) if seen else None,
        })
    summary = {
        'label': label,
        'os_foreground': foreground,
        'frames': {'n': len(dts), 'p50': pct(dts, .5), 'p95': pct(dts, .95), 'p99': pct(dts, .99), 'focused_share': round(focus, 3)},
        'server_ticks': {'n': len(s['ticks']), 'p50': pct(s['ticks'], .5), 'p95': pct(s['ticks'], .95), 'p99': pct(s['ticks'], .99),
                         'heartbeat_ms': s.get('heartbeatMs')},
        'presses': rows,
    }
    for key in ('press_to_ack_seen_ms', 'receipt_to_start_ms', 'press_to_local_pose_ms'):
        values = [r[key] for r in rows if r[key] is not None]
        summary[key] = {'n': len(values), 'p50': pct(values, .5), 'p95': pct(values, .95), 'max': max(values) if values else None}
    (LOGS / f'{label}_summary.json').write_text(json.dumps(summary, indent=1))
    print(json.dumps(summary, indent=1))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

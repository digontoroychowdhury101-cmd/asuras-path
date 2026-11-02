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

Probe version 2 (closure pass) logs are analysed by intent ID instead of by time: each press is tied to the
intent seq its Sent trace record carries, and every later fact is looked up by that seq (prediction outcome,
the animation occurrence for that intent, the server start whose actionIntent is that seq, the terminal
record). Four presentation measures are kept apart and named for what they are:
  occurrence_ms         the animation layer starts or adopts the occurrence for this intent (trace)
  track_start_proxy_ms  first new Action-priority track after the press (Stage 2's "2 ms" figure: a proxy)
  pose_change_ms        first frame the right hand moved >= 0.25 stud relative to the root
  body_move_ms          first frame the root moved >= 0.25 stud horizontally (dash and roll presses)
Each is a RenderStepped reading before that frame renders (display latency excluded). Missing values stay
null with a reason, and each summary lists n, missing, every value and the outliers.
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


POSE_STUDS = 0.25
SENT_MATCH = {'Light': {'Light', 'RunningAttack'}, 'Heavy': {'Heavy'}, 'Dash': {'Dash', 'Roll'}, 'Deflect': {'Deflect'}}


def describe(values, missing):
    values = sorted(values)
    p50 = pct(values, .5)
    outliers = [v for v in values if p50 is not None and v > 2 * p50 and v > p50 + 50]
    return {'n': len(values), 'missing': len(missing), 'missing_seqs': missing, 'p50': p50, 'p95': pct(values, .95),
            'max': values[-1] if values else None, 'values': values, 'outliers': outliers}


def first_after(rows, t, key=lambda r: True, within=1.5):
    return next((r for r in rows if r['t'] >= t - 1e-9 and r['t'] - t <= within and key(r)), None)


def analyse_v2(c, s, label, foreground):
    trace, poses = c['trace'], c['poses']
    server_ack, client_ack = {}, {}
    for a in s['acks']:
        if a['name'] == 'AsuraAck':
            server_ack.setdefault(str(a['value']), a)
    for a in c['acks']:
        if a['name'] == 'AsuraAck':
            client_ack.setdefault(str(a['value']), a)
    used, rows = set(), []
    for press in c['presses']:
        kinds = SENT_MATCH.get(press['kind'], {press['kind']})
        sent = first_after(trace, press['t'], lambda r: r['e'] == 'Sent' and r['d'] in kinds and r['seq'] not in used, 0.3)
        row = {'kind': press['kind'], 't': round(press['t'], 3), 'seq': None, 'missing': []}
        rows.append(row)
        if not sent:
            row['missing'].append('no Sent trace within 300 ms (press not sent: menu, focus or coalesced)')
            continue
        seq = sent['seq']
        used.add(seq)
        row['seq'] = seq
        mine = [r for r in trace if r['seq'] == seq]
        names = {r['e'] for r in mine}
        row['prediction'] = next((e for e in ('Predicted', 'Unpredicted') if e in names), None)
        row['prediction_end'] = next((e for e in ('Confirmed', 'Ended', 'RolledBack') if e in names), None)
        occurrence = next((r for r in mine if r['e'] == 'Occurrence'), None)
        row['occurrence_ms'] = round((occurrence['t'] - press['t']) * 1000, 1) if occurrence else None
        row['occurrence'] = occurrence['d'] if occurrence else None
        track = first_after(c['starts'], press['t'])
        row['track_start_proxy_ms'] = round((track['t'] - press['t']) * 1000, 1) if track else None
        before = next((q for q in reversed(poses) if q['t'] < press['t']), None)
        pose = body = None
        if before:
            def hand_moved(q):
                return sum((a - b) ** 2 for a, b in zip(q['h'], before['h'])) ** 0.5 >= POSE_STUDS

            def root_moved(q):
                return ((q['r'][0] - before['r'][0]) ** 2 + (q['r'][1] - before['r'][1]) ** 2) ** 0.5 >= POSE_STUDS
            pose = first_after(poses, press['t'], hand_moved)
            if press['kind'] == 'Dash':
                body = first_after(poses, press['t'], root_moved)
        row['pose_change_ms'] = round((pose['t'] - press['t']) * 1000, 1) if pose else None
        row['body_move_ms'] = round((body['t'] - press['t']) * 1000, 1) if body else None
        seen = client_ack.get(str(seq))
        row['press_to_ack_seen_ms'] = round((seen['t'] - press['t']) * 1000, 1) if seen else None
        receipt = server_ack.get(str(seq))
        start = next((st for st in s['states'] if st.get('intent') == seq), None)
        row['start_state'] = start['state'] if start else None
        row['start_move'] = start.get('move') if start else None
        row['receipt_to_start_ms'] = round((start['entered'] - receipt['s']) * 1000, 1) if start and receipt else None
        row['terminal'] = terminal(s, seq)
        for key in ('occurrence_ms', 'track_start_proxy_ms', 'pose_change_ms', 'receipt_to_start_ms', 'press_to_ack_seen_ms'):
            if row[key] is None:
                row['missing'].append(key)
        if press['kind'] == 'Dash' and row['body_move_ms'] is None:
            row['missing'].append('body_move_ms')
    dts = [f['dt'] for f in c['frames']]
    focus = sum(1 for f in c['frames'] if f['f']) / max(1, len(c['frames']))
    summary = {
        'label': label, 'probe_version': 2, 'os_foreground': foreground,
        'frames': {'n': len(dts), 'p50': pct(dts, .5), 'p95': pct(dts, .95), 'p99': pct(dts, .99), 'focused_share': round(focus, 3)},
        'server_ticks': {'n': len(s['ticks']), 'p50': pct(s['ticks'], .5), 'p95': pct(s['ticks'], .95), 'p99': pct(s['ticks'], .99),
                         'heartbeat_ms': s.get('heartbeatMs')},
        'presses': rows,
        'server_moves': [{'entered': st['entered'], 'state': st['state'], 'move': st.get('move'), 'intent': st.get('intent')}
                         for st in s['states'] if st['state'] in ('Startup', 'Dashing', 'Deflecting')],
    }
    for key in ('press_to_ack_seen_ms', 'receipt_to_start_ms', 'occurrence_ms', 'track_start_proxy_ms', 'pose_change_ms', 'body_move_ms'):
        relevant = [r for r in rows if r['seq'] is not None and (key != 'body_move_ms' or r['kind'] == 'Dash')]
        summary[key] = describe([r[key] for r in relevant if r.get(key) is not None],
                                [r['seq'] for r in relevant if r.get(key) is None])
    summary['unsent_presses'] = sum(1 for r in rows if r['seq'] is None)
    (LOGS / f'{label}_summary.json').write_text(json.dumps(summary, indent=1))
    print(json.dumps({k: v for k, v in summary.items() if k not in ('presses', 'server_moves')}, indent=1))
    return 0


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

    if c.get('version') == 2:
        return analyse_v2(c, s, label, foreground)
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

#!/usr/bin/env python3
"""Collect selected final-build QA output without copying authentication/HTTP logs."""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--log-dir', type=Path, default=Path.home() / 'Library/Logs/Roblox')
parser.add_argument('--native-log', help='Studio log containing a complete chunked native benchmark report')
parser.add_argument('--native-normal-log', help='Latest native two-client normal server log')
parser.add_argument('--native-latency-log', help='Latest native two-client latency server log')
parser.add_argument('--additional-evidence-log', action='append', default=[], help='Preserve selected QA output from failed attempts or parent logs')
args = parser.parse_args()
if args.native_normal_log or args.native_latency_log:
    records, evidence, scenarios = [], [], {}
    pattern = re.compile(r'\[Cagebound QA12 Evidence\] (-?\d+) (Combat|Rapid) (\{.*\})$')
    applied = None
    selected = [('normal', args.native_normal_log), ('latency', args.native_latency_log)]
    selected += [('additional', name) for name in args.additional_evidence_log]
    for scenario, name in selected:
        if not name:
            continue
        evidence.append(f'=== {scenario}: {name} ===')
        lines = []
        for line in (args.log_dir / name).read_text(errors='replace').splitlines():
            if 'Embedded Web Browser Navigation Url: www.roblox.com/login' in line:
                evidence.append(line.split('www.roblox.com/login')[0]+'www.roblox.com/login')
                continue
            if '> ' in line or '[FLog::Creator' not in line:
                continue
            if not any(tag in line for tag in ['[Cagebound QA12', '[QA12 Native', '[QA12 Plugin]']):
                continue
            lines.append(line); evidence.append(line)
            match = pattern.search(line)
            if match and scenario != 'additional':
                records.append({'scenario': scenario, 'log': name, 'userId': int(match[1]),
                                'command': match[2], 'report': json.loads(match[3])})
            match = re.search(r'\[QA12 Native Latency Active\] ([\d. ]+)$', line)
            if match:
                values = [float(v) for v in match[1].split()]
                if len(values) == 6:
                    applied = dict(zip(['inboundDelayMs','outboundDelayMs','inboundJitterMs',
                                        'outboundJitterMs','inboundLossPercent','outboundLossPercent'], values))
        if scenario != 'additional':
            joined = '\n'.join(lines)
            required = ['Two clients READY','Receipts PASS','preflight PASS Ranked1v1','preflight PASS Casual1v1',
                        'Practice isolation PASS','Ranked completion PASS','Disconnect/forfeit/arena release PASS',
                        'Reconnect storage recovery PASS']
            scenarios[scenario] = {'coreLifecyclePassed': all(tag in joined for tag in required),
                                   'wholeSuitePassed': any(line.endswith('[Cagebound QA12] PASS') for line in lines)}
    whole = all(scenarios.get(s, {}).get('wholeSuitePassed', False) for s in ['normal','latency'])
    exact = bool(applied and list(applied.values()) == [100,100,20,20,1,1])
    report = {'wholeSuitePassed': whole, 'requestedLatencyConditionPassed': whole and exact,
              'foregroundRenderingCertified': False, 'scenarios': scenarios,
              'nativeAppliedSettings': applied, 'records': records,
              'scope': 'Actual Studio clients and Heartbeat QA. Native rendering, physical input and same-account rejoin are separate. Missing samples/timeouts/nil are never passes. Profile reload is not a network reconnect.'}
    (ROOT/'outputs/Phase12-Native-Multiplayer-Evidence.txt').write_text('\n'.join(evidence)+'\n')
    (ROOT/'outputs/Phase12-Native-Multiplayer-Metrics.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Collected {len(records)} native functional records; wholeSuitePassed={whole}; exact requested impairment={whole and exact}')
    raise SystemExit(0)
logs = {
    'normal': '0.743.0.7431133_20261015T055119Z_Studio_6a22a_last.log',
    'latency': '0.743.0.7431133_20261015T060340Z_Studio_5ad92_last.log',
    'launcher': '0.743.0.7431133_20261015T043654Z_Studio_00090_last.log',
}
pattern = re.compile(r'\[Cagebound QA12 Evidence\] (-?\d+) (Combat|Rapid) (\{.*\})$')
records, evidence = [], []
for scenario, name in logs.items():
    evidence.append(f'=== {scenario}: {name} ===')
    for line in (args.log_dir / name).read_text(errors='replace').splitlines():
        if '[Cagebound QA12' not in line or '[FLog::Creator' not in line or '> ' in line:
            continue
        evidence.append(line)
        match = pattern.search(line)
        if match:
            records.append({'scenario': scenario, 'userId': int(match[1]),
                            'test': match[2], 'metrics': json.loads(match[3])})
assert len(records) == 8, f'Expected eight final-build Combat/Rapid records, got {len(records)}'
report = {
    'studioVersion': '0.743.0.7431133',
    'wholeSuitePassed': False,
    'requestedLatencyConditionPassed': False,
    'nativeForegroundCertified': False,
    'physicalIPhoneMeasured': False,
    'normal': {'delayEachDirectionMs': 0, 'jitterEachDirectionMs': 0, 'lossEachDirectionPercent': 0},
    'latency': {'requested': {'delayEachDirectionMs': 100, 'jitterEachDirectionMs': 20, 'lossEachDirectionPercent': 1},
                'applied': {'delayEachDirectionMs': 100, 'jitterEachDirectionMs': 20, 'lossEachDirectionPercent': 0.5}},
    'limitations': [
        'Heartbeat QA drives functional controllers; raw RenderStepped timing includes background/startup windows.',
        'Every recorded foreground frame/action distribution has n=0; none certifies native rendering or physical input latency.',
        'Server resolution includes accepted and rejected requests; unresolved tail requests are retained in sent/resolved counts.',
        'Normal suite timed out waiting for an actual replacement client. Same-account rejoin is unverified.',
        'Latency launcher returned nil before the child completed. Child logs show core checks and forfeit success, not full-suite success.',
        'Profile reload/result recovery is distinct from a genuine network reconnect.',
    ],
    'records': records,
}
if args.native_log:
    chunks, expected, complete, native_lines = {}, {}, [], []
    for line in (args.log_dir / args.native_log).read_text(errors='replace').splitlines():
        if '[Cagebound Native Benchmark]' not in line or '[FLog::Creator' not in line or '> ' in line:
            continue
        native_lines.append(line)
        begin = re.search(r'REPORT_BEGIN (\S+) (\d+)$', line)
        chunk = re.search(r'REPORT_CHUNK (\S+) (\d+) (.*)$', line)
        end = re.search(r'REPORT_END (\S+)$', line)
        if begin:
            expected[begin[1]] = int(begin[2]); chunks[begin[1]] = {}
        if chunk:
            assert chunk[1] in chunks, 'Chunk without report beginning'
            chunks[chunk[1]][int(chunk[2])] = chunk[3]
        if end:
            run = end[1]
            assert set(chunks[run]) == set(range(1, expected[run]+1)), 'Missing native report chunk'
            native = json.loads(''.join(chunks[run][i] for i in range(1, expected[run]+1)))
            native['runId'] = run; complete.append(native)
    assert complete, 'No complete native benchmark report'
    native = complete[-1]
    assert native['driver'] == 'RenderStep' and native['focusObserved'], 'Not observed native foreground'
    sufficient = (native['foregroundFrameMs']['n'] >= 900 and native['foregroundSampleSeconds'] >= 30
                  and native['foregroundInputToPreviewMs']['n'] >= 100 and native['foregroundServerResolutionMs']['n'] >= 100)
    passed = (sufficient and native['foregroundFrameMs']['p95'] <= 33.3
              and native['foregroundInputToPreviewMs']['p95'] <= 50 and native['foregroundCorrectionStuds']['max'] <= 3)
    assert native['sufficient'] == sufficient and native['performancePassed'] == passed
    report['nativeForegroundCertified'] = passed
    report['nativeBenchmark'] = native
    report['limitations'].append('Separate native benchmark covers one Studio desktop viewport and scripted stationary strikes, not multiplayer rendering, moving reconciliation, physical input or iPhone performance.')
    (ROOT / 'outputs/Phase12-Native-Benchmark-Evidence.txt').write_text('\n'.join(native_lines)+'\n')
    (ROOT / 'outputs/Phase12-Native-Benchmark.json').write_text(json.dumps(native, indent=2)+'\n')
(ROOT / 'outputs/Phase12-FinalStudio-Evidence.txt').write_text('\n'.join(evidence) + '\n')
(ROOT / 'outputs/Phase12-FinalStudio-Metrics.json').write_text(json.dumps(report, indent=2) + '\n')
print(f'Collected {len(records)} functional timing records; wholeSuitePassed=false; native proposed checks={report["nativeForegroundCertified"]}')

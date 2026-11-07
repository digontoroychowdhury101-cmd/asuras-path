#!/usr/bin/env python3
"""C00: reconcile the 36 audit findings against current source and write the routing ledger.

Run from the repository root:  python outputs/environment-production-2026-11-06/C00/build_ledger.py
Inputs: outputs/visual-audit-2026-11-05/findings.json, production/routing.json (if present), git.
Outputs (next to this script): ROUTING_LEDGER.csv, ROUTING_LEDGER.md.
"""
from __future__ import annotations
import csv
import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
AUDIT_COMMIT = 'a29f8cf'
FINDINGS = json.loads((ROOT / 'outputs/visual-audit-2026-11-05/findings.json').read_text(encoding='utf-8'))

# Status vocabulary (C00 step 1): open | already fixed | superseded by arena redesign | awaiting supplied asset.
# A finding can carry two when part is agent work and part waits on a supplied hero asset.
STATUS = {
    'AP-01': ('partly fixed; awaiting supplied asset', 'Shen P1/P2 templates imported, skinned and single-client verified (Shen RESULTS); Zhao and Iron Bull templates present. Baize, Titan, Wu and Wyrm have no AsuraBoss_* template in assets/models or the built place and no source file on this machine.', 'C06 (integration once files arrive)'),
    'AP-02': ('awaiting supplied asset', 'H06/H07/H08 exports not found in the repository, assets/, Downloads or Desktop. Mannequin references exported (C00/references).', 'C06'),
    'AP-03': ('open', '', 'C02'), 'AP-04': ('open', '', 'C02'), 'AP-05': ('open', '', 'C02'),
    'AP-06': ('open', 'Octagon of Ash ring sits in the Proving Court; AR01 keeps its footprint.', 'C03, C07'),
    'SN-01': ('open', '', 'C02'), 'DM-01': ('open', '', 'C03'), 'DM-02': ('open', '', 'C03'),
    'DM-03': ('open; awaiting supplied asset', 'Dais/ruin work is agent work now; idol waits on H01 (not found).', 'C03, C06'),
    'DM-04': ('open', 'Reuse AsuraFoundryKit.Foundry_Bell (6.95x9.67x6.95).', 'C03'),
    'DM-05': ('open', 'Reuse AsuraHanKit.HanCauldron (scale up) before any new cauldron.', 'C03'),
    'DM-06': ('open', '', 'C03'), 'DM-07': ('open', '', 'C03'),
    'DM-08': ('open; awaiting supplied asset', 'Facade/door frame agent work; relief waits on H04 (not found).', 'C03, C06'),
    'DM-09': ('open', '', 'C03, C05'),
    'DM-10': ('superseded by arena redesign', 'AR02 (Twin Sentinels) owns the arena setting.', 'AR00, AR02'),
    'BP-01': ('superseded by arena redesign', 'AR03 (Baize) owns the arena edge and identity.', 'AR00, AR03'),
    'LT-01': ('open', 'Ash lighting is touched by AR01 only inside the colosseum; Crypt/Citadel remain C01.', 'C01, C07'),
    'AC-01': ('open; partly superseded by arena redesign', 'Facade/arena mouth rebuilt by AR01; antechamber and hall kit remain C03.', 'C03, AR01'),
    'AC-02': ('open', '', 'C03'),
    'AC-03': ('superseded by arena redesign', 'AR01 (The Ashen Covenant) replaces the perimeter.', 'AR00, AR01'),
    'SD-01': ('superseded by arena redesign; awaiting supplied asset', 'Titan chamber by AR04; root buttress waits on H03 (not found).', 'C04, AR04, C06'),
    'SD-02': ('open', '', 'C04'), 'SD-03': ('open', '', 'C04'), 'SD-04': ('open', 'Fit to Titan once its model file is supplied.', 'C04'),
    'SD-05': ('open', '', 'C04, AR04'), 'SD-06': ('open', '', 'C04'),
    'CP-01': ('awaiting supplied asset', 'Throne waits on H02 (not found); loft framing is agent work.', 'C05, C06'),
    'CP-02': ('open', 'Reuse AsuraFoundryKit.Foundry_Bell.', 'C05'), 'CP-03': ('open', '', 'C05'), 'CP-04': ('open', '', 'C05'),
    'CP-05': ('superseded by arena redesign', 'AR05 (Wu) owns the mirror court.', 'AR00, AR05'),
    'SC-01': ('open', 'Small code defect; C01 is a separate instruction.', 'C01'),
    'SC-02': ('open', 'Perch chains/scales; landmark revisited by AR06.', 'C05, AR06'),
    'SC-03': ('open; partly superseded by arena redesign', 'Bridge masonry C05; bastion reveal AR06.', 'C05, AR06'),
}


def changed_since_audit(paths: list[str]) -> str:
    if not paths:
        return 'n/a'
    out = subprocess.run(['git', 'diff', '--name-only', AUDIT_COMMIT, 'HEAD', '--', *paths], cwd=ROOT,
                         capture_output=True, text=True).stdout.split()
    return ' '.join(out) if out else 'unchanged'


def main() -> None:
    rows = []
    for f in FINDINGS:
        srcs = []
        for s in f.get('sources', []):
            m = re.match(r'(src/[^\s:#]+\.luau)', s)
            if m and (ROOT / m.group(1)).exists():
                srcs.append(m.group(1))
        status, note, route = STATUS[f['id']]
        rows.append({'id': f['id'], 'priority': f['priority'], 'region': f['region'], 'title': f['title'],
                     'status': status, 'source_since_audit': changed_since_audit(sorted(set(srcs))),
                     'route': route, 'note': note, 'owning_sources': ' '.join(sorted(set(srcs)))})
    assert len(rows) == 36, len(rows)
    with (HERE / 'ROUTING_LEDGER.csv').open('w', newline='', encoding='utf-8') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    lines = ['# C00 routing ledger: all 36 audit findings', '',
             f'Generated by `build_ledger.py` against `HEAD` vs the audit commit `{AUDIT_COMMIT}`. "unchanged" means none of the',
             'finding\'s owning source files changed since the audit, so the audited state still stands in source. Runtime spot',
             'checks are recorded in ASSET_INTAKE.md.', '',
             '| ID | P | Status | Owning source since audit | Route | Note |', '|---|---|---|---|---|---|']
    for r in rows:
        lines.append(f"| {r['id']} · {r['title']} | {r['priority']} | {r['status']} | {r['source_since_audit']} | {r['route']} | {r['note']} |")
    counts: dict[str, int] = {}
    for r in rows:
        counts[r['status']] = counts.get(r['status'], 0) + 1
    lines += ['', 'Totals: ' + '; '.join(f'{k}: {v}' for k, v in sorted(counts.items()))]
    (HERE / 'ROUTING_LEDGER.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(counts)


if __name__ == '__main__':
    main()

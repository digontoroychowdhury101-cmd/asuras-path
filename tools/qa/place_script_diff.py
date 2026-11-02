#!/usr/bin/env python3
"""Compare the scripts in two .rbxlx places (XML parser, the same walk as studio_mcp --digest).

    python tools/qa/place_script_diff.py A.rbxlx B.rbxlx

Prints scripts only in A, only in B, and those whose Source differs (with the first differing line),
so a provenance mismatch is explained by actual source differences rather than by script counts.
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from studio_mcp import ROOTS, SCRIPTS  # noqa: E402


def scripts(place: str) -> dict[str, str]:
    rows: dict[str, str] = {}

    def walk(item: ET.Element, trail: str) -> None:
        props = item.find('Properties')
        props = list(props) if props is not None else []
        name = next((p.text or '' for p in props if p.attrib.get('name') == 'Name'), item.attrib['class'])
        full = f'{trail}.{name}' if trail else name
        if item.attrib['class'] in SCRIPTS:
            rows[full] = next((p.text or '' for p in props if p.attrib.get('name') == 'Source'), '').replace('\r', '')
        for child in item.findall('Item'):
            walk(child, full)

    for top in ET.parse(place).getroot().findall('Item'):
        if top.attrib['class'] in ROOTS:
            walk(top, '')
    return rows


def main() -> int:
    a, b = scripts(sys.argv[1]), scripts(sys.argv[2])
    for path in sorted(set(a) - set(b)):
        print(f'only in A: {path}')
    for path in sorted(set(b) - set(a)):
        print(f'only in B: {path} ({len(b[path])} chars)')
    for path in sorted(set(a) & set(b)):
        if a[path] != b[path]:
            la, lb = a[path].split('\n'), b[path].split('\n')
            line = next((i for i, (x, y) in enumerate(zip(la, lb)) if x != y), min(len(la), len(lb)))
            print(f'differs: {path} (A {len(la)} lines, B {len(lb)} lines, first difference at line {line + 1})')
    print(f'A {len(a)} scripts, B {len(b)} scripts')
    return 0


if __name__ == '__main__':
    sys.exit(main())

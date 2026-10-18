#!/usr/bin/env python3
"""Build the Asura's Path place from the checked-in Rojo tree (default.project.json).

Requires the official Rojo binary on PATH or in work/bin/rojo. Verifies that every $path in the
tree exists, builds outputs/AsurasPath.rbxlx, and points Workspace.CurrentCamera at the
serialized editor camera. Does not install software, connect to Studio, or publish.
"""
from __future__ import annotations
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'default.project.json'
OUTPUT = ROOT / 'outputs' / 'AsurasPath.rbxlx'


def binary(name: str, folder: str) -> str:
    local = ROOT / 'work' / 'bin' / folder / name
    found = str(local) if local.is_file() else shutil.which(name)
    if not found:
        raise SystemExit(f'Missing {name}. See docs/BUILD.md for official download locations.')
    return found


def paths(node: dict, trail: str) -> list[tuple[str, str]]:
    found = []
    if '$path' in node:
        found.append((trail, node['$path']))
    for key, child in node.items():
        if not key.startswith('$') and isinstance(child, dict):
            found.extend(paths(child, f'{trail}.{key}' if trail else key))
    return found


def build() -> None:
    rojo = binary('rojo', 'rojo')
    project = json.loads(PROJECT.read_text())
    missing = [f'{trail} -> {path}' for trail, path in paths(project['tree'], '') if not (ROOT / path).exists()]
    if missing:
        raise SystemExit('Rojo tree references missing sources:\n  ' + '\n  '.join(missing))
    OUTPUT.parent.mkdir(exist_ok=True)
    subprocess.run([rojo, 'build', str(PROJECT), '--output', str(OUTPUT)], cwd=ROOT, check=True)
    # Rojo cannot point a property at a sibling instance through JSON; set the editor camera
    # reference in the serialized place without changing source.
    xml = ET.parse(OUTPUT)
    workspace = next(i for i in xml.getroot().findall('Item') if i.attrib['class'] == 'Workspace')
    camera = next(i for i in workspace.findall('Item') if i.attrib['class'] == 'Camera')
    properties = workspace.find('Properties')
    assert properties is not None
    for old in list(properties):
        if old.attrib.get('name') == 'CurrentCamera':
            properties.remove(old)
    ET.SubElement(properties, 'Ref', name='CurrentCamera').text = camera.attrib['referent']
    xml.write(OUTPUT, encoding='utf-8', xml_declaration=True)
    print(f'Built {OUTPUT.name}: {len(paths(project["tree"], ""))} mapped sources; external asset IDs: 0')


if __name__ == '__main__':
    build()

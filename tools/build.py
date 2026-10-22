#!/usr/bin/env python3
"""Build the Asura's Path place from the checked-in Rojo tree (default.project.json).

Requires the official Rojo binary on PATH or in work/bin/rojo. Verifies that every $path in the
tree exists, builds outputs/AsurasPath.rbxlx (or --output PATH / $ASURA_BUILD_OUTPUT, so a
verification build can leave the saved place untouched), points Workspace.CurrentCamera at the
serialized editor camera and reports the distinct Roblox asset IDs the built place references.
Does not install software, connect to Studio, or publish.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'default.project.json'
OUTPUT = ROOT / 'outputs' / 'AsurasPath.rbxlx'
ASSET_ID = re.compile(r'(?:rbxassetid://|roblox\.com/asset/\?id=)(\d+)')


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


def build(output: Path = OUTPUT) -> None:
    rojo = binary('rojo', 'rojo')
    project = json.loads(PROJECT.read_text())
    missing = [f'{trail} -> {path}' for trail, path in paths(project['tree'], '') if not (ROOT / path).exists()]
    if missing:
        raise SystemExit('Rojo tree references missing sources:\n  ' + '\n  '.join(missing))
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([rojo, 'build', str(PROJECT), '--output', str(output)], cwd=ROOT, check=True)
    # Rojo cannot point a property at a sibling instance through JSON; set the editor camera
    # reference in the serialized place without changing source.
    xml = ET.parse(output)
    workspace = next(i for i in xml.getroot().findall('Item') if i.attrib['class'] == 'Workspace')
    camera = next(i for i in workspace.findall('Item') if i.attrib['class'] == 'Camera')
    properties = workspace.find('Properties')
    assert properties is not None
    for old in list(properties):
        if old.attrib.get('name') == 'CurrentCamera':
            properties.remove(old)
    ET.SubElement(properties, 'Ref', name='CurrentCamera').text = camera.attrib['referent']
    xml.write(output, encoding='utf-8', xml_declaration=True)
    assets = set(ASSET_ID.findall(output.read_text(encoding='utf-8')))
    print(f'Built {output}: {len(paths(project["tree"], ""))} mapped sources; '
          f'{len(assets)} distinct Roblox asset IDs referenced')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--output', type=Path, default=Path(os.environ.get('ASURA_BUILD_OUTPUT') or OUTPUT))
    build(parser.parse_args().output.resolve())

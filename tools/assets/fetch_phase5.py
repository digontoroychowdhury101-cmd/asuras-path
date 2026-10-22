"""Fetch original CC0 PBR/audio sources, verify hashes, and record reproducible provenance.
python3 tools/assets/fetch_phase5.py [--process] [--preview]
Uses system curl (system certificate store), public manifests and official publisher downloads.
"""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLENDER = '/Applications/Blender.app/Contents/MacOS/Blender'
MODELS = ('stone_01', 'stone_fire_pit', 'brass_diya_lantern')
AUDIO = ('impact-sounds', 'rpg-audio')


def fetch(url, target, md5=None):
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and (not md5 or hashlib.md5(target.read_bytes()).hexdigest() == md5): return
    temporary = target.with_suffix(target.suffix+'.partial')
    subprocess.run(['curl', '-fLsS', '--retry', '2', '--max-time', '180', url, '-o', str(temporary)], check=True)
    if md5 and hashlib.md5(temporary.read_bytes()).hexdigest() != md5:
        temporary.unlink(); raise ValueError('Download checksum mismatch: '+url)
    temporary.replace(target)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--process', action='store_true'); parser.add_argument('--preview', action='store_true')
    args = parser.parse_args()
    registry = []
    for asset in MODELS:
        source = ROOT/'assets/source'/asset
        manifest = source/'download.json'
        fetch('https://api.polyhaven.com/files/'+asset, manifest)
        data = json.loads(manifest.read_text())['gltf']['1k']['gltf']
        input_file = source/(asset+'_1k.gltf')
        fetch(data['url'], input_file, data['md5'])
        for path, entry in data['include'].items():
            if Path(path).is_absolute() or '..' in Path(path).parts: raise ValueError('Unsafe publisher path')
            fetch(entry['url'], source/path, entry['md5'])
        registry.append(dict(key=asset, publisher='Poly Haven', license='CC0-1.0',
                             source='https://polyhaven.com/a/'+asset, files_url='https://api.polyhaven.com/files/'+asset,
                             input=str(input_file.relative_to(ROOT)), input_sha256=hashlib.sha256(input_file.read_bytes()).hexdigest()))
        if args.process:
            subprocess.run([BLENDER,'-b','--python-exit-code','1','-P',str(ROOT/'tools/blender/process_asset.py'),
                            '--',str(input_file),str(ROOT/'assets/build'/asset),
                            '--max-tris','2400' if asset == 'stone_01' else '19500'], check=True)
        glb = ROOT/'assets/build'/asset/(asset+'.glb')
        if args.preview and glb.exists():
            subprocess.run([BLENDER,'-b','--python-exit-code','1','-P',str(ROOT/'tools/blender/preview_asset.py'),
                            '--',str(glb),str(glb.parent/'preview.png')],check=True)
    for pack in AUDIO:
        source = ROOT/'assets/source/audio'/pack
        page = source/'source.html'; fetch('https://kenney.nl/assets/'+pack,page)
        matches = re.findall(r"href=['\"](https://kenney\.nl/[^'\"]+\.zip)['\"]",page.read_text())
        if not matches: raise ValueError('Publisher download not found for '+pack)
        archive = source/(pack+'.zip'); fetch(matches[0],archive)
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                if Path(info.filename).is_absolute() or '..' in Path(info.filename).parts: raise ValueError('Unsafe ZIP')
            z.extractall(source/'files')
        registry.append(dict(key=pack, publisher='Kenney', license='CC0-1.0', source='https://kenney.nl/assets/'+pack,
                             download=matches[0], sha256=hashlib.sha256(archive.read_bytes()).hexdigest()))
    source = ROOT/'assets/source/3td_ruins'
    archive = source/'ruins.zip'
    url = 'https://opengameart.org/sites/default/files/Fantasy%20Ruins%20Pack.zip'
    fetch(url, archive)
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            if Path(info.filename).is_absolute() or '..' in Path(info.filename).parts: raise ValueError('Unsafe ZIP')
        z.extractall(source)
    registry.append(dict(key='3td_fantasy_ruins', publisher='Ron Kapaun / 3TD Studios', license='CC0-1.0',
                         source='https://opengameart.org/content/3td-fantasy-ruins-pack', download=url,
                         sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                         note='Authored architecture with diffuse/normal maps; roughness and metalness are authored defaults, not scans.'))
    manifest = ROOT/'assets/PHASE5_SOURCES.json' 
    manifest.write_text(json.dumps({'retrieved':'2026-10-19','sources':registry},indent=2)+'\n')
    credits = ROOT/'assets/CREDITS.md'; text = credits.read_text()
    for entry in registry:
        if entry['source'] not in text:
            text += f"\n| {entry['key']} | {entry['source']} | {entry['license']} | Phase 5 scenery / sound design (upload pending) |\n"
    credits.write_text(text)
    print('SOURCE_REGISTRY',manifest)


if __name__ == '__main__': main()

"""Run the actual Phase 5 presentation modules under deterministic engine fakes; validate media.
python3 tools/test_audiovisual.py
"""
from pathlib import Path
import json
import re
import struct
import subprocess
import wave

ROOT=Path(__file__).resolve().parents[1]
modules=('PresentationAssets','EnvironmentProfiles','SpatialAudio','EnvironmentController','WeaponTrails','PbrAssets')
chunks=[]
for name in modules:
    folder='shared' if name in modules[:2] else 'server/Services' if name=='PbrAssets' else 'client/Controllers'
    source=(ROOT/'src'/folder/(name+'.luau')).read_text()
    chunks.append(f'registry["{name}"] = (function()\n{source}\nend)()')
harness=(ROOT/'tools/test_audiovisual.luau').read_text().replace('-- MODULES_INSERT','\n'.join(chunks))
output=ROOT/'work/test_audiovisual.generated.luau';output.parent.mkdir(exist_ok=True);output.write_text(harness)
subprocess.run([str(ROOT/'work/bin/luau/luau'),str(output)],cwd=ROOT,check=True)
media=0
for report_path in (ROOT/'assets/build').glob('*/report.json'):
    if report_path.parent.name not in ('stone_01','stone_fire_pit','brass_diya_lantern','RuinArch_01','RomanRail_01','PillarSegment_01','FoundationRuin_01','TempleRuin_01'): continue
    report=json.loads(report_path.read_text());assert all(0<m['tris_after']<=19500 for m in report['meshes'])
    for maps in report['maps'].values():
        assert set(maps)=={'Color','Normal','Roughness','Metalness'}
        for name in maps.values():
            data=(report_path.parent/'maps'/name).read_bytes()
            assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(1024,1024)
    path=report_path.parent/report['glb'];glb=path.read_bytes()
    assert glb[:4]==b'glTF' and struct.unpack_from('<I',glb,8)[0]==len(glb)
    length=struct.unpack_from('<I',glb,12)[0];doc=json.loads(glb[20:20+length])
    for mesh in doc['meshes']:
        tris=sum(doc['accessors'][p['indices']]['count']//3 for p in mesh['primitives'])
        assert tris<=19500
    for material in doc['materials']:
        assert 'normalTexture' in material and 'baseColorTexture' in material['pbrMetallicRoughness']
        assert 'metallicRoughnessTexture' in material['pbrMetallicRoughness']
    assert (path.parent/'preview.png').exists(),f'Missing preview: {path}'
    media+=1
manifest=ROOT/'assets/build/phase5_audio/manifest.json'
if manifest.exists():
    cues=json.loads(manifest.read_text())['cues'];assert len(cues)==12
    for key,cue in cues.items():
        with wave.open(str(ROOT/cue['file'])) as w:
            assert (w.getnchannels(),w.getframerate(),w.getsampwidth())==(1,48000,2)
        assert cue['peak_dbfs']<=-2.9 and abs(cue['dc'])<.003 and cue['duration']>0
print(f'PASS: {media} PBR exports validated; audio format/peak/DC checks passed (available media only)')

#!/usr/bin/env python3
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import hashlib,json
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'outputs/Phase12-Manifest.json').read_text())
for path,digest in manifest['sourceSha256'].items(): assert hashlib.sha256((root/path).read_bytes()).hexdigest()==digest,path
for path,digest in manifest.get('testAndBuildSha256',{}).items(): assert hashlib.sha256((root/path).read_bytes()).hexdigest()==digest,path
for path,digest in manifest.get('evidenceSha256',{}).items(): assert hashlib.sha256((root/path).read_bytes()).hexdigest()==digest,path
for name,entry in manifest['artifacts'].items(): assert hashlib.sha256((root/'outputs'/name).read_bytes()).hexdigest()==entry['sha256'],name
paths=[root/'README.md',root/'default.project.json']
for directory in ['src','tools','docs']:
 paths.extend(p for p in (root/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
paths.extend(p for p in (root/'outputs').glob('Phase12-*') if p.is_file())
with ZipFile(root/'outputs/Cagebound-Phase12-Source.zip','w',ZIP_DEFLATED) as archive:
 for p in sorted(set(paths)): archive.write(p,p.relative_to(root))
print('Packaged',len(set(paths)),'source/test/document files; downloaded tools and prior milestone artifacts excluded')

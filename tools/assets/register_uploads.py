"""Apply verified Roblox image/audio IDs exported from Studio. Never uploads or invents IDs.
python3 tools/assets/register_uploads.py /path/to/uploads.json
JSON: {"Audio":{"Clash":"rbxassetid://123"},"Textures":{"Leaf":"rbxassetid://456"}}
"""
import argparse
import json
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('registry');args=parser.parse_args()
    data=json.loads(Path(args.registry).read_text());path=ROOT/'src/shared/PresentationAssets.luau';source=path.read_text()
    queued=ROOT/'assets/PHASE5_IMPORT_QUEUE.json';queue=json.loads(queued.read_text())
    updates=[]
    for section in ('Audio','Textures','Sky'):
        block=re.search(r'(Assets\.'+section+r' = \{)(.*?)(\n?\})',source,re.S)
        text=block[2]
        for key,value in data.get(section,{}).items():
            if not re.fullmatch(r'rbxassetid://[1-9][0-9]{5,19}',str(value)): raise ValueError(f'Invalid owned asset ID for {section}.{key}')
            pattern=r'(\b'+re.escape(key)+r'\s*=\s*)"[^"]*"'
            if not re.search(pattern,text): raise ValueError(f'Unknown slot {section}.{key}')
            text=re.sub(pattern,lambda m:m[1]+json.dumps(value),text,count=1)
            if section in queue:
                queue[section][key].update(id=value,uploaded=True)
            updates.append((section,key,value))
        source=source[:block.start(2)]+text+source[block.end(2):]
    path.write_text(source);queued.write_text(json.dumps(queue,indent=2)+'\n')
    registry=ROOT/'assets/PHASE5_UPLOADED.json'
    previous=json.loads(registry.read_text()) if registry.exists() else {}
    for section,key,value in updates: previous.setdefault(section,{})[key]=value
    registry.write_text(json.dumps(previous,indent=2)+'\n')
    doc=ROOT/'assets/ASSET_IDS.md';text=doc.read_text().split('<!-- PHASE5_UPLOADED -->')[0].rstrip()
    rows=['\n\n<!-- PHASE5_UPLOADED -->','## Registered Phase 5 uploads','', '| Type | Slot | Owned asset ID |','|---|---|---|']
    for section,entries in previous.items():
        for key,value in entries.items(): rows.append(f'| {section} | {key} | {value} |')
    doc.write_text(text+'\n'.join(rows)+'\n')
    print('Registered',len(updates),'uploaded IDs. Verify experience permissions in Studio.')
if __name__=='__main__':main()

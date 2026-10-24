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
            if key in queue.get(section,{}):  # skill cues are not in the phase-5 queue
                queue[section][key].update(id=value,uploaded=True)
            updates.append((section,key,value))
        source=source[:block.start(2)]+text+source[block.end(2):]
    models=data.get('Models',{})
    for name,parts in models.items():
        if not isinstance(parts,list) or not parts: raise ValueError('Empty imported model '+name)
        for part in parts:
            for field in ('MeshId','ColorMap','NormalMap','RoughnessMap','MetalnessMap'):
                if not re.fullmatch(r'rbxassetid://[1-9][0-9]{5,19}',str(part.get(field,''))):
                    raise ValueError(f'{name}: missing/invalid {field}')
        for entry in queue['models']:
            if entry['name']==name:entry['uploaded']=True;entry['parts']=parts
    path.write_text(source);queued.write_text(json.dumps(queue,indent=2)+'\n')
    registry=ROOT/'assets/PHASE5_UPLOADED.json'
    previous=json.loads(registry.read_text()) if registry.exists() else {}
    for section,key,value in updates: previous.setdefault(section,{})[key]=value
    previous.setdefault('Models',{}).update(models)
    registry.write_text(json.dumps(previous,indent=2)+'\n')
    doc=ROOT/'assets/ASSET_IDS.md';text,_,generated=doc.read_text().partition('<!-- PHASE5_UPLOADED -->');text=text.rstrip()
    after=generated.find('\n## ',generated.find('## Registered Phase 5 uploads')+1)  # hand-written sections after the table survive
    rest=generated[after:] if after>=0 else ''
    rows=['\n\n<!-- PHASE5_UPLOADED -->','## Registered Phase 5 uploads','', '| Type | Slot | Owned asset ID |','|---|---|---|']
    for section,entries in previous.items():
        if section=='Models': continue
        for key,value in entries.items(): rows.append(f'| {section} | {key} | {value} |')
    rows+=['', '| Model | MeshPart | MeshId | Color / Normal / Roughness / Metalness |','|---|---|---|---|']
    for name,parts in previous.get('Models',{}).items():
        for part in parts:
            maps=' / '.join(part[k] for k in ('ColorMap','NormalMap','RoughnessMap','MetalnessMap'))
            rows.append(f"| {name} | {part.get('Name','MeshPart')} | {part['MeshId']} | {maps} |")
    doc.write_text(text+'\n'.join(rows)+'\n'+rest)
    print('Registered',len(updates),'uploaded IDs. Verify experience permissions in Studio.')
if __name__=='__main__':main()

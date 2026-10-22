"""Extract the real, uploaded asset library from a Studio-saved XML place without replacing originals.
python3 tools/assets/extract_studio_assets.py /tmp/AsurasPath_Phase5.rbxlx
Preserves referenced SharedStrings, model hierarchy and uploaded PBR references.
"""
import argparse
import copy
import json
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def name(item):return item.findtext('Properties/string[@name="Name"]')
def content(item,key):return item.findtext(f'Properties/Content[@name="{key}"]/url') or ''
def main():
    parser=argparse.ArgumentParser();parser.add_argument('place');args=parser.parse_args()
    tree=ET.parse(args.place).getroot()
    server=next(i for i in tree.findall('Item') if i.attrib.get('class')=='ServerStorage')
    library=next(i for i in server.findall('Item') if name(i)=='AsuraAssets')
    models={};valid_models=[];invalid=[]
    for model in library.findall('Item'):
        if model.attrib.get('class')!='Model':continue
        parts=[];complete=True
        for mesh in model.iter('Item'):
            if mesh.attrib.get('class')!='MeshPart':continue
            surface=next((s for s in mesh.findall('Item') if s.attrib.get('class')=='SurfaceAppearance'),None)
            if surface is None:complete=False;break
            part={'Name':name(mesh),'MeshId':content(mesh,'MeshId')}
            part.update({key:content(surface,key) for key in ('ColorMap','NormalMap','RoughnessMap','MetalnessMap')})
            if not all(part.values()):complete=False;break
            parts.append(part)
        if not complete or not parts:invalid.append(name(model));continue
        if name(model) in models:raise ValueError('Duplicate valid model '+name(model))
        models[name(model)]=parts;valid_models.append(model)
    for model_name in invalid:
        if model_name not in models:raise ValueError(model_name+': missing uploaded reference')
    if invalid:print('Skipped incomplete live-sync duplicates:',', '.join(invalid))
    # Rebuilding the place loads MeshId natively; new MeshPart MeshIds cannot be assigned by live sync.
    library=copy.deepcopy(library)
    for child in list(library):
        if child.tag=='Item':library.remove(child)
    for model in valid_models:library.append(copy.deepcopy(model))
    root=ET.Element('roblox',{'version':'4'})
    ET.SubElement(root,'External').text='null';ET.SubElement(root,'External').text='nil'
    root.append(copy.deepcopy(library))
    references={v.text for v in library.iter('SharedString')}
    shared=tree.find('SharedStrings')
    if shared is not None and references:
        target=ET.SubElement(root,'SharedStrings')
        for string in shared:
            if string.attrib.get('md5') in references:target.append(copy.deepcopy(string))
    out=ROOT/'assets/models/AsuraAssets_Phase5.rbxmx'
    ET.ElementTree(root).write(out,encoding='utf-8',xml_declaration=True)
    registry=ROOT/'assets/PHASE5_UPLOADED.json'
    existing=json.loads(registry.read_text()) if registry.exists() else {}
    existing['Models']=models;registry.write_text(json.dumps(existing,indent=2)+'\n')
    extracted=ROOT/'assets/build/phase5_import/studio_registry.json';extracted.write_text(json.dumps({'Models':models},indent=2)+'\n')
    print('EXTRACTED',len(models),'models,',sum(map(len,models.values())),'PBR MeshParts;',out)
if __name__=='__main__':main()

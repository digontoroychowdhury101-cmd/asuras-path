"""Prepare a named Studio import folder and an honest queue of pending Roblox uploads."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
MODELS={
 'stone_01':'AsuraStone','stone_fire_pit':'AsuraFirePit','brass_diya_lantern':'AsuraBrassLantern',
 'RuinArch_01':'AsuraRuinArch','RomanRail_01':'AsuraRomanRail','PillarSegment_01':'AsuraRuinPillar',
 'FoundationRuin_01':'AsuraFoundationRuin','TempleRuin_01':'AsuraTempleRuin',
}
def main():
    directory=ROOT/'assets/build/phase5_import';(directory/'meshes').mkdir(parents=True,exist_ok=True)
    queue={'status':'pending_roblox_upload','models':[],'Audio':{},'Textures':{}}
    for source,name in MODELS.items():
        folder=ROOT/'assets/build'/source
        report=json.loads((folder/'report.json').read_text())
        target=directory/'meshes'/(name+'.glb');shutil.copy2(folder/report['glb'],target)
        queue['models'].append({'name':name,'file':str(target.relative_to(ROOT)),'mesh_objects':len(report['meshes']),
                                'materials':len(report['maps']),'triangles':report['total_triangles'],
                                'source':source,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'uploaded':False})
    for section,path in (('Audio','phase5_audio'),('Textures','phase5_vfx')):
        target=directory/section.lower();target.mkdir(exist_ok=True)
        manifest=json.loads((ROOT/'assets/build'/path/'manifest.json').read_text())
        entries=manifest['cues'] if section=='Audio' else manifest['textures']
        for key,item in entries.items():
            source=ROOT/(item['file'] if isinstance(item,dict) else item)
            out=target/source.name;shutil.copy2(source,out)
            queue[section][key]={'file':str(out.relative_to(ROOT)),'id':'','uploaded':False}
    (ROOT/'assets/PHASE5_IMPORT_QUEUE.json').write_text(json.dumps(queue,indent=2)+'\n')
    (directory/'README.txt').write_text('ASURA PHASE 5 IMPORTS\n\n'
      'Meshes: import the GLBs with Studio 3D Importer. Keep their Asura names and PBR materials.\n'
      'Move the models into ServerStorage.AsuraAssets. Export that folder to assets/models/AsuraAssets.rbxm after import.\n'
      'Audio: upload WAV files in Creator Hub; put named Sound templates with the uploaded IDs in SoundService.AsuraAudio.\n'
      'Textures: upload PNG files, then register their image IDs with tools/assets/register_uploads.py.\n'
      'Do not use decal catalog IDs in place of their underlying image IDs.\n'
      'Read assets/PHASE5.md for the verification checklist and unfinished boss sculpt requirements.\n')
    print('IMPORT_PACKAGE',directory,len(queue['models']),'models,',len(queue['Audio']),'sounds,',len(queue['Textures']),'textures')
if __name__=='__main__':main()

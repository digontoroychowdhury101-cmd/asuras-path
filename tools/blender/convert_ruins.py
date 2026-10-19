"""Convert the CC0 3TD Collada ruins to modern static PBR glTF without legacy executable scripts.
Blender -b --python-exit-code 1 -P tools/blender/convert_ruins.py -- <source.dae> <out.glb>
Keeps highest detail visual LOD, UVs, material assignments and transforms; discards collision/LOD
helpers. Legacy diffuse+normal materials receive authored stone roughness=.86 / metalness=0.
"""
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote
import bpy
from mathutils import Matrix, Vector

source, output = map(Path,sys.argv[sys.argv.index('--')+1:][:2])
r=ET.parse(source).getroot(); ns={'c':r.tag.split('}')[0][1:]}
def all_(e,path): return e.findall(path,ns)
def one(e,path): return e.find(path,ns)
def text(e,path,default=''):
    node=one(e,path); return node.text.strip() if node is not None and node.text else default
bpy.ops.wm.read_factory_settings(use_empty=True)
images={n.attrib['id']:text(n,'c:init_from') for n in all_(r,'c:library_images/c:image')}
effects={n.attrib['id']:n for n in all_(r,'c:library_effects/c:effect')}
materials={}
legacy=(source.parent/'materials.cs').read_text(errors='replace') if (source.parent/'materials.cs').exists() else ''
blocks=re.findall(r'singleton Material\([^)]*\)\s*\{(.*?)\};',legacy,re.S)
paths={p.name.lower():p for p in source.parent.iterdir() if p.is_file()}
def findfile(name):
    base=Path(unquote(name).replace('\\','/')).name
    if base.lower() in paths: return paths[base.lower()]
    return next((p for p in paths.values() if p.stem.lower()==Path(base).stem.lower() and p.suffix.lower() in ('.jpg','.png')),None)
for entry in all_(r,'c:library_materials/c:material'):
    eid=one(entry,'c:instance_effect').attrib['url'].lstrip('#'); effect=effects[eid]
    params={n.attrib['sid']:n for n in all_(effect,'c:profile_COMMON/c:newparam')}
    tex=one(effect,'.//c:diffuse/c:texture'); color_path=None
    if tex is not None:
        sampler=params.get(tex.attrib['texture'])
        surface=params.get(text(sampler,'c:sampler2D/c:source')) if sampler is not None else None
        if surface is not None: color_path=findfile(images.get(text(surface,'c:surface/c:init_from'),''))
    normal_path=None
    for block in blocks:
        if re.search(r'mapTo\s*=\s*"'+re.escape(eid)+r'"',block):
            diffuse=re.search(r'diffuseMap\[0\]\s*=\s*"([^"]+)"',block)
            normal=re.search(r'normalMap\[0\]\s*=\s*"([^"]+)"',block)
            if diffuse: color_path=findfile(diffuse[1]) or color_path
            if normal: normal_path=findfile(normal[1])
    if not normal_path and color_path: normal_path=findfile(color_path.stem+'_NRM.png')
    mat=bpy.data.materials.new(eid);mat.use_nodes=True;shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value=0.86;shader.inputs['Metallic'].default_value=0
    if color_path:
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(color_path),check_existing=True)
        mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
    else: shader.inputs['Base Color'].default_value=(0.24,0.22,0.19,1)
    if normal_path:
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(normal_path),check_existing=True)
        tex.image.colorspace_settings.name='Non-Color'
        normal=mat.node_tree.nodes.new('ShaderNodeNormalMap')
        mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],shader.inputs['Normal'])
    materials[entry.attrib['id']]=mat
geometries={g.attrib['id']:g for g in all_(r,'c:library_geometries/c:geometry') if not any(x in g.attrib.get('name','').lower() for x in ('collision','loscol'))}
# Torque names LODs with a trailing distance/size number; retain the highest visual LOD.
groups={}
for gid,g in geometries.items():
    name=g.attrib.get('name',gid); match=re.match(r'(.*?)(\d+)$',name)
    key=match[1] if match else name; rank=int(match[2]) if match else 0
    if key not in groups or rank>groups[key][0]: groups[key]=(rank,gid)
keep={v[1] for v in groups.values()}
def walk(node,parent):
    transform=Matrix.Identity(4)
    for el in node:
        tag=el.tag.split('}')[-1]; values=list(map(float,el.text.split())) if el.text and el.text.strip() and tag in ('matrix','translate','scale','rotate') else []
        if tag=='matrix': transform @= Matrix([values[i:i+4] for i in range(0,16,4)])
        elif tag=='translate': transform @= Matrix.Translation(Vector(values))
        elif tag=='scale': transform @= Matrix.Diagonal(Vector(values+[1]))
        elif tag=='rotate': transform @= Matrix.Rotation(math.radians(values[3]),4,Vector(values[:3]))
    world=parent@transform
    for inst in all_(node,'c:instance_geometry'):
        gid=inst.attrib['url'].lstrip('#')
        if gid not in keep: continue
        geo=geometries[gid];mesh=one(geo,'c:mesh')
        arrays={}
        for src in all_(mesh,'c:source'):
            accessor=one(src,'c:technique_common/c:accessor'); stride=int(accessor.attrib.get('stride','1'))
            vals=list(map(float,text(src,'c:float_array').split()));arrays[src.attrib['id']]=[vals[i:i+stride] for i in range(0,len(vals),stride)]
        vertices={v.attrib['id']:one(v,'c:input').attrib['source'].lstrip('#') for v in all_(mesh,'c:vertices')}
        bindings={m.attrib['symbol']:m.attrib['target'].lstrip('#') for m in all_(inst,'.//c:instance_material')}
        positions=[];uvs=[];faces=[];face_materials=[];slots=[]
        for tri in all_(mesh,'c:triangles'):
            inputs=all_(tri,'c:input');stride=max(int(i.attrib['offset']) for i in inputs)+1
            v=next(i for i in inputs if i.attrib['semantic']=='VERTEX');vo=int(v.attrib['offset'])
            coords=arrays[vertices[v.attrib['source'].lstrip('#')]]
            uv=next((i for i in inputs if i.attrib['semantic']=='TEXCOORD'),None)
            indices=list(map(int,text(tri,'c:p').split()))
            key=bindings.get(tri.attrib.get('material',''))
            if key not in slots: slots.append(key)
            for start in range(0,len(indices),stride*3):
                base=len(positions)
                for corner in range(3):
                    index=start+corner*stride;positions.append(coords[indices[index+vo]][:3])
                    uvs.append(arrays[uv.attrib['source'].lstrip('#')][indices[index+int(uv.attrib['offset'])]][:2] if uv is not None else (0,0))
                faces.append((base,base+1,base+2));face_materials.append(slots.index(key))
        data=bpy.data.meshes.new(gid);data.from_pydata(positions,[],faces);data.update()
        layer=data.uv_layers.new(name='UVMap')
        for loop in data.loops: layer.data[loop.index].uv=uvs[loop.vertex_index]
        for key in slots:
            if key not in materials: raise ValueError('Missing material binding '+str(key))
            data.materials.append(materials[key])
        for face,index in zip(data.polygons,face_materials): face.material_index=index
        obj=bpy.data.objects.new(geo.attrib.get('name',gid),data);bpy.context.collection.objects.link(obj);obj.matrix_world=world
    for child in all_(node,'c:node'): walk(child,world)
for node in all_(r,'c:library_visual_scenes/c:visual_scene/c:node'): walk(node,Matrix.Identity(4))
if not list(bpy.context.scene.objects): raise ValueError('No visual geometry found')
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_animations=False)
print('CONVERTED_CC0_RUINS',source.name,output)

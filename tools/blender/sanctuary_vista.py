"""Asura sanctuary distant landscape kit, authored in Blender; 1 unit = 1 Roblox stud.
Run Blender -b --python-exit-code 1 -P tools/blender/sanctuary_vista.py
Outputs: editable .blend, importer GLB, part/pivot manifest and textured QA renders.
Existing Rock PBR maps are reused from lobby_kit, with no changes to statue/tree assets.
Each mesh is single-material and individually checked below 19,500 triangles.
"""
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/build/sanctuary_vista'
TEX = ROOT / 'assets/build/lobby_kit/textures'
SCAN = ROOT / 'assets/source/tex'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
COL = bpy.data.collections.new('AsuraSanctuaryVista')
bpy.context.scene.collection.children.link(COL)


def material(name, color, textured=False):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .88
    if textured:
        for typ, socket in [('Color','Base Color'),('Roughness','Roughness'),('Metalness','Metallic'),('Normal','Normal')]:
            source = SCAN / {'Color':'rock_face_03_Diffuse.png','Normal':'rock_face_03_nor_gl.png','Roughness':'rock_face_03_Rough.png'}.get(typ,'unused') if typ != 'Metalness' else TEX / 'Rock_Metalness.png'
            im = bpy.data.images.load(str(source), check_existing=True)
            if typ != 'Metalness':
                im.scale(1024,1024)
                im.filepath_raw = str(OUT / f'VistaRock_{typ}.png')
                im.file_format = 'PNG'
                im.save()
            if typ != 'Color': im.colorspace_settings.name = 'Non-Color'
            tx = mat.node_tree.nodes.new('ShaderNodeTexImage')
            tx.image = im
            if typ == 'Normal':
                nm = mat.node_tree.nodes.new('ShaderNodeNormalMap')
                mat.node_tree.links.new(tx.outputs['Color'], nm.inputs['Color'])
                mat.node_tree.links.new(nm.outputs['Normal'], bs.inputs['Normal'])
            else: mat.node_tree.links.new(tx.outputs['Color'], bs.inputs[socket])
    return mat


MATS = {'Rock': material('Vista_Rock', (.32,.36,.39), True),
        'Moss': material('Vista_Moss', (.17,.235,.11)),
        'Water': material('Vista_Water', (.68,.82,.82))}


class Part:
    def __init__(self, name, mat):
        self.name, self.mat = name, mat
        self.v, self.f, self.uv = [], [], []

    def add(self, vertices, faces, uv=None):
        n = len(self.v)
        self.v.extend(vertices)
        self.f.extend([[i+n for i in f] for f in faces])
        self.uv.extend(uv or [[(vertices[i][0]/32,vertices[i][2]/32) for i in f] for f in faces])

    def finish(self, layout):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.v, [], self.f)
        me.update()
        layer = me.uv_layers.new(name='UVMap')
        for face, uv in zip(me.polygons, self.uv):
            for loop, point in zip(face.loop_indices, uv): layer.data[loop].uv = point
            face.use_smooth = True
        me.validate()
        if self.mat == 'Rock': me.set_sharp_from_angle(angle=math.radians(38))
        ob = bpy.data.objects.new(self.name, me)
        ob.data.materials.append(MATS[self.mat])
        COL.objects.link(ob)
        lo = Vector(tuple(min(p[k] for p in self.v) for k in range(3)))
        hi = Vector(tuple(max(p[k] for p in self.v) for k in range(3)))
        ob.data.transform(Matrix.Translation(layout))
        tris = sum(len(f)-2 for f in self.f)
        assert tris <= 19500, (self.name, tris)
        return {'material':self.mat,'center':roblox((lo+hi)/2),'size':[hi.x-lo.x,hi.z-lo.z,hi.y-lo.y],
                'triangles':tris,'vertices':len(self.v),'uv':True,'singleMaterial':True}


def roblox(v): return [round(-v[0],4),round(v[2],4),round(v[1],4)]


def tower(part, center, rx, ry, height, seed, crown=.27, lean=(0,0)):
    """Layered, fractured bedrock: asymmetrical crown, deep persistent vertical ravines,
    cantilever strata, twisting flutes and terraced erosion. Mesh is closed with authored UVs.
    The silhouette contains real top/side variation, not stacked primitive cones.
    """
    rng = random.Random(seed)
    sides, rows = 64, 37
    phases = [rng.random()*math.tau for _ in range(12)]
    strata = [(.18,.065),(.32,.045),(.48,.075),(.64,.045),(.78,.06),(.87,.035)]
    vertices, faces, uvs = [], [], []
    for j in range(rows):
        t=j/(rows-1)
        # Broad weathered bases, sheer body, narrow broken summit rather than a cone.
        radius = 1.0 - .24*min(t/.2,1) - .13*min(max((t-.2)/.55,0),1)
        if t > .83: radius *= 1-(1-max(crown,.48))*((t-.83)/.17)**.8
        radius += sum(a*math.exp(-((t-s)/.022)**2) for s,a in strata)
        for i in range(sides):
            a=i/sides*math.tau
            macro = .11*math.sin(3*a+phases[0])+.08*math.sin(5*a+phases[1])
            fissure = sum(.042*abs(math.sin(k*a+phases[k%12]+t*.3))**9 for k in (7,11,13))
            flute = .035*math.sin(17*a+phases[4]+t*.5)+.023*math.sin(23*a+phases[5]-t*.7)
            sediment=.015*math.sin(t*58+math.sin(a*7))+.009*math.sin(t*110+a*3)
            r=radius*(1+macro-fissure+flute+sediment)
            top=.94+.009*math.sin(a*3+phases[6])+.004*math.sin(a*9+phases[7])
            z=height*t*top
            x=center[0]+rx*r*math.cos(a)+lean[0]*t*t
            y=center[1]+ry*r*math.sin(a)+lean[1]*t*t
            vertices.append((x,y,center[2]+z))
    per=math.pi*(rx+ry)
    for j in range(rows-1):
        for i in range(sides):
            ni=(i+1)%sides
            faces.append((j*sides+i,j*sides+ni,(j+1)*sides+ni,(j+1)*sides+i))
            uvs.append([(per*i/sides/32,height*j/(rows-1)/32),(per*(i+1)/sides/32,height*j/(rows-1)/32),
                        (per*(i+1)/sides/32,height*(j+1)/(rows-1)/32),(per*i/sides/32,height*(j+1)/(rows-1)/32)])
    faces += [tuple(reversed(range(sides))),tuple(range((rows-1)*sides,rows*sides))]
    uvs += [[(vertices[i][0]/32,vertices[i][1]/32) for i in f] for f in faces[-2:]]
    part.add(vertices,faces,uvs)
    return (center[0]+lean[0],center[1]+lean[1],center[2]+height*.94)


def moss_lobe(part, center, rx, ry, seed):
    rng=random.Random(seed)
    rings, sides=3,14
    vs=[(center[0],center[1],center[2]+.8)]
    for j in range(1,rings+1):
        t=j/rings
        for k in range(sides):
            a=k/sides*math.tau
            wob=1+.18*math.sin(a*5+seed)+.08*rng.random()
            vs.append((center[0]+rx*t*math.cos(a)*wob,center[1]+ry*t*math.sin(a)*wob,
                       center[2]+.8*(1-t*t)+.24*math.sin(a*3+seed)*t))
    fs=[]
    for i in range(sides): fs.append((0,1+i,1+(i+1)%sides))
    for j in range(rings-1):
        b=1+j*sides;c=b+sides
        for i in range(sides): fs.append((b+i,c+i,c+(i+1)%sides,b+(i+1)%sides))
    part.add(vs,fs)


def mountain(kind):
    pc={'Rock':Part(kind+'__Rock','Rock'),'Moss':Part(kind+'__Moss','Moss')}
    if kind=='Vista_Crown':
        top=tower(pc['Rock'],(0,0,0),45,35,182,51,.72,(-5,2))
        tower(pc['Rock'],(-31,10,0),23,22,128,55,.65,(-7,3))
        tower(pc['Rock'],(31,14,0),20,22,150,59,.65,(5,-3))
        tower(pc['Rock'],(12,-22,0),24,20,102,62,.4,(2,-3))
        moss_lobe(pc['Moss'],(-5,2,172),15,12,42)
        moss_lobe(pc['Moss'],(-38,13,121),8,7,43)
        moss_lobe(pc['Moss'],(36,11,142),7,7,44)
    elif kind=='Vista_Ridge':
        tower(pc['Rock'],(-32,0,0),42,27,142,71,.32,(-4,0))
        tower(pc['Rock'],(27,5,0),45,28,116,72,.55,(8,2))
        tower(pc['Rock'],(6,8,0),26,24,163,75,.3,(0,1))
        tower(pc['Rock'],(61,7,0),20,22,77,79,.4,(4,2))
        for xyz,rx,ry,s in [((-36,0,134),10,9,9),((35,7,110),15,11,10),((6,9,154),8,7,11),((65,9,73),5,6,13)]:moss_lobe(pc['Moss'],xyz,rx,ry,s)
    else:
        tower(pc['Rock'],(0,0,0),29,27,235,81,.22,(-5,1))
        tower(pc['Rock'],(21,3,0),20,19,180,82,.22,(5,-4))
        tower(pc['Rock'],(-20,4,0),18,16,137,84,.32,(-7,2))
        moss_lobe(pc['Moss'],(-5,1,222),5.5,5,18)
        moss_lobe(pc['Moss'],(26,-1,170),5,5,20)
    return pc


def waterfall():
    p=Part('Vista_Waterfall__Water','Water')
    # Thin layered cascades, subtly separated edges and curved flared foot; instantiate beside cliffs.
    for stream in range(5):
        vs=[]
        for j in range(33):
            t=j/32; x=(stream-2)*1.3+.3*math.sin(t*10+stream)
            width=.62+.12*math.sin(t*20+stream)+2.8*t**8
            y=.6*math.sin(t*5+stream*.3)+4*t**6
            z=120*(1-t)
            vs.extend([(x-width,y,z),(x+width,y,z)])
        fs=[(j*2,j*2+1,j*2+3,j*2+2) for j in range(32)]
        p.add(vs,fs)
    return {'Water':p}


def build():
    manifest={'units':'studs','axes':'Roblox (-BlenderX, BlenderZ, BlenderY), pivots at mountain foot centre',
              'source':'original procedural Blender geometry; reused CC0 Poly Haven rock_face_03 source scan already present in assets/source/tex. New resized 1024 maps are embedded in GLB.',
              'textureReuse':{'Rock':'Existing source scan rock_face_03 color, normal, roughness; existing lobby kit black Metalness map. New importer maps preferred; lobby Rock IDs are a fallback.'},
              'import':'Studio 3D Importer, Creator Me, World Forward Front, World Up Top. Meshes single material; no collision.',
              'pieces':{}}
    for name,at in [('Vista_Crown',(0,0,0)),('Vista_Ridge',(210,0,0)),('Vista_Needle',(410,0,0)),('Vista_Waterfall',(520,0,0))]:
        pcs=waterfall() if name=='Vista_Waterfall' else mountain(name)
        parts={}
        for part in pcs.values(): parts[part.name]=part.finish(Vector(at))
        lo=[min(p['center'][k]-p['size'][k]/2 for p in parts.values()) for k in range(3)]
        hi=[max(p['center'][k]+p['size'][k]/2 for p in parts.values()) for k in range(3)]
        manifest['pieces'][name]={'layoutOrigin':roblox(at),'bounds':[lo,hi],'size':[hi[k]-lo[k] for k in range(3)],'parts':parts}
    manifest['totals']={'pieces':len(manifest['pieces']),'meshParts':sum(len(x['parts']) for x in manifest['pieces'].values()),
                        'triangles':sum(q['triangles'] for x in manifest['pieces'].values() for q in x['parts'].values())}
    manifest['problems']=[]
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for ob in COL.objects:ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'AsuraSanctuaryVista.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'AsuraSanctuaryVista.blend'))
    print('VISTA_MANIFEST',json.dumps(manifest['totals']))
    return manifest


def preview():
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=1800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('WarmClouds');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.44,.55,.68,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    sun=bpy.data.lights.new('Sunset','SUN');sun.energy=3.2;sun.color=(1,.76,.5);sun.angle=.12
    ob=bpy.data.objects.new('Sunset',sun);scene.collection.objects.link(ob);ob.rotation_euler=(.45,-.6,-.6)
    light=bpy.data.lights.new('Fill','AREA');light.energy=80000;light.shape='DISK';light.size=180
    ob=bpy.data.objects.new('Fill',light);scene.collection.objects.link(ob);ob.location=(220,-150,250)
    ob.rotation_euler=(Vector((220,0,100))-ob.location).to_track_quat('-Z','Y').to_euler()
    cam=bpy.data.cameras.new('Vista_QA');cam.type='ORTHO';cam.ortho_scale=650;cam.clip_end=4000
    ob=bpy.data.objects.new('Vista_QA',cam);scene.collection.objects.link(ob);ob.location=(620,-800,370)
    ob.rotation_euler=(Vector((235,0,100))-ob.location).to_track_quat('-Z','Y').to_euler();scene.camera=ob
    scene.render.filepath=str(OUT/'preview_sheet.png');bpy.ops.render.render(write_still=True)
    cam.ortho_scale=280;ob.location=(250,-340,215);ob.rotation_euler=(Vector((0,0,100))-ob.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.filepath=str(OUT/'preview_crown.png');bpy.ops.render.render(write_still=True)


if __name__=='__main__':
    build();preview()

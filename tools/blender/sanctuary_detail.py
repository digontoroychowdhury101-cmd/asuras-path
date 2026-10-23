"""Original modular erosion/plant kit. Blender -> GLB -> Studio 3D Importer.
Small shared pieces, no collision and no new texture downloads. Rock scan CC0 Poly Haven.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/build/sanctuary_detail';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name,color,texture=None):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.9
 if texture:
  for kind,socket in [('Color','Base Color'),('Normal','Normal'),('Roughness','Roughness')]:
   im=bpy.data.images.load(str(ROOT/'assets/build/sanctuary_vista'/f'VistaRock_{kind}.png'),check_existing=True)
   tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im
   if kind!='Color':im.colorspace_settings.name='Non-Color'
   if kind=='Normal':
    n=m.node_tree.nodes.new('ShaderNodeNormalMap');m.node_tree.links.new(tx.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],bs.inputs[socket])
   else:m.node_tree.links.new(tx.outputs['Color'],bs.inputs[socket])
 return m
rock=mat('DetailRock',(.5,.55,.6),True);moss=mat('Moss',(.19,.26,.12));red=mat('Crimson',(.43,.035,.055))
manifest={}
def mesh(name,vs,fs,material,at=(0,0,0),uv=None):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
 layer=me.uv_layers.new(name='UVMap')
 for f in me.polygons:
  for li,vi in zip(f.loop_indices,f.vertices):layer.data[li].uv=(uv[vi] if uv else (vs[vi][0]/8,vs[vi][2]/8+vs[vi][1]/12))
  f.use_smooth=material==rock
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);ob.data.materials.append(material);ob.location=at
 me.calc_loop_triangles();manifest[name]={'triangles':len(me.loop_triangles),'vertices':len(vs),'material':material.name,'blenderLayout':at}
 return ob
# closed, cantilevered bedding sheets, fractured tips; deep diagonal clefts and terraced ribs.
rng=random.Random(22023);vs=[];fs=[]
for k in range(6):
 n=len(vs);length=rng.uniform(7,12);depth=rng.uniform(2.7,4.5);cx=rng.uniform(-1.6,1.6);y=k*.37
 ring=[]
 for i in range(9):
  a=i/9*math.tau;r=rng.uniform(.8,1.15);ring.append((cx+math.cos(a)*length*.5*r,math.sin(a)*depth*.5*r,y+rng.uniform(-.1,.1)))
 vs+=ring+[(x*.96,z*.96,h-.38-rng.random()*.2) for x,z,h in ring]
 fs+=[tuple(n+i for i in range(9)),tuple(n+9+i for i in reversed(range(9)))]
 for i in range(9):fs.append((n+i,n+(i+1)%9,n+9+(i+1)%9,n+9+i))
mesh('Detail_Strata',vs,fs,rock)
# slim weathered fin/ravine relief, distinct from mountain silhouette.
vs=[];fs=[];sides=13;rows=16
for j in range(rows):
 t=j/(rows-1)
 for i in range(sides):
  a=i/sides*math.tau;r=1+.14*math.sin(a*4+t*8)+.07*math.sin(t*49+i)
  vs.append((math.cos(a)*1.9*r*(.7+.3*math.sin(t*math.pi)),math.sin(a)*1.35*r,14*t))
for j in range(rows-1):
 for i in range(sides):a=j*sides+i;b=j*sides+(i+1)%sides;fs.append((a,b,b+sides,a+sides))
fs+=[tuple(reversed(range(sides))),tuple(range((rows-1)*sides,rows*sides))]
mesh('Detail_Fissure',vs,fs,rock,(18,0,0))
# Ferns are actual pointed leaf blades, no alpha fill, 300 triangles per reusable clump.
vs=[];fs=[]
for plant in range(5):
 yaw=plant*2.4
 for row in range(8):
  t=(row+1)/9;stem=Vector((math.cos(yaw)*t*1.5,math.sin(yaw)*t*1.5,math.sin(t*2.1)*1.8));length=(1-t)*.72+.12
  for side in [-1,1]:
   d=Vector((math.cos(yaw+side*1.1),math.sin(yaw+side*1.1),.18));tip=stem+d*length;cross=Vector((-d.y,d.x,0))*.11*(1-t*.6)
   n=len(vs);vs += [tuple(stem),tuple(stem+d*length*.45+cross),tuple(tip),tuple(stem+d*length*.45-cross)]
   fs.append((n,n+1,n+2,n+3))
mesh('Detail_Fern',vs,fs,moss,(30,0,0))
# Pointed, lobed maple leaves in a low spilling clump, all in one mesh/material.
vs=[];fs=[]
for i in range(44):
 a=i*2.39996;r=math.sqrt(rng.random())*2.2;p=Vector((math.cos(a)*r,math.sin(a)*r,rng.uniform(.15,.85)+(1-r/2.5)*.5))
 x=Vector((math.cos(a),math.sin(a),.2));y=Vector((-math.sin(a)*.6,math.cos(a)*.6,rng.uniform(-.2,.6)));s=rng.uniform(.28,.5);n=len(vs);vs.append(tuple(p))
 outline=[(0,1.5),(.25,.55),(.85,.9),(.5,.15),(1,.15),(.45,-.3),(.4,-.8),(0,-.5),(-.4,-.8),(-.45,-.3),(-1,.15),(-.5,.15),(-.85,.9),(-.25,.55)]
 for xx,yy in outline:vs.append(tuple(p+(x*xx+y*yy)*s))
 for j in range(len(outline)):fs.append((n,n+1+j,n+1+(j+1)%len(outline)))
mesh('Detail_MapleSpray',vs,fs,red,(40,0,0))
# Shared two-sided branch card; existing uploaded branch texture is assigned on the saved template.
mesh('Detail_BranchCard',[(-1,0,-.5),(1,0,-.5),(1,0,.5),(-1,0,.5)],[(0,1,2,3)],red,(50,0,1),[(0,0),(1,0),(1,1),(0,1)])
for ob in bpy.context.scene.objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'AsuraSanctuaryDetail.glb'),export_format='GLB',export_apply=True,export_yup=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'AsuraSanctuaryDetail.blend'))
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest))

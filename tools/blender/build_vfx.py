"""Author deterministic optical VFX masks; no stock Roblox particles. Run through Blender -b -P.
The masks are white with alpha for runtime tinting, except the sourced crimson leaf.
"""
import json
from pathlib import Path
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/build/phase5_vfx'; OUT.mkdir(parents=True,exist_ok=True)
N=512
axis=np.linspace(-1,1,N,dtype=np.float32)
x,y=np.meshgrid(axis,axis)
r=np.sqrt(x*x+y*y); theta=np.arctan2(y,x)
rng=np.random.default_rng(519)
files={}
def write(name,alpha):
    rgba=np.ones((N,N,4),dtype=np.float32); rgba[:,:,3]=np.clip(alpha,0,1)
    im=bpy.data.images.new(name,N,N,alpha=True)
    im.pixels.foreach_set(rgba.ravel()); im.filepath_raw=str(OUT/(name+'.png')); im.file_format='PNG'; im.save()
    files[name]=str((OUT/(name+'.png')).relative_to(ROOT))
write('Ember',np.exp(-((x/0.08)**2+(y/0.64)**2)*3))
write('Ribbon',np.exp(-(y/0.24)**2*3)*np.clip(1-np.abs(x),0,1)**0.35)
write('Shockwave',np.exp(-((r-0.77)/0.022)**2))
write('Ash',np.exp(-((x/0.25)**2+(y/0.16)**2)*4)*(0.7+0.3*np.sin(x*33+y*22)))
noise=np.zeros_like(x)
for _ in range(32):
    fx,fy=rng.uniform(2,22,2); phase=rng.uniform(0,6.28)
    noise+=np.sin(x*fx+y*fy+phase)/32
write('Smoke',np.exp(-r*r*4)*np.clip(0.55+noise*1.7,0,1)*np.clip((1-r)*5,0,1))
write('Flame',np.exp(-((x/(0.15+(1-y)*0.15))**2+(y/0.82)**2)*3)*(0.7+0.3*np.sin(y*18+x*12)))
blood=np.zeros_like(x)
for _ in range(40):
    a,b=rng.normal(0,0.32,2); size=rng.uniform(0.012,0.11)
    blood=np.maximum(blood,np.clip((size-np.sqrt((x-a)**2+(y-b)**2))*N/2,0,1))
write('BloodStain',blood)
write('Blood',np.exp(-((x/0.12)**2+(y/0.44)**2)*3))
ring=np.exp(-((r-0.7)/0.012)**2)+np.exp(-((r-0.87)/0.009)**2)
# Discontinuous radial bars form an authored circular seal rather than borrowed sacred script.
glyph=(np.abs(np.sin(theta*12))<0.13)&(r>0.72)&(r<0.85)
write('Rune',np.maximum(ring,glyph.astype(np.float32)))
leaf=ROOT/'assets/build/veiled_titan/leaves/crimson_leaf.png'
scatter=ROOT/'assets/build/veiled_titan/leaves/leaf_scatter.png'
for key,path in (('Leaf',leaf),('LeafScatter',scatter)):
    if path.exists():
        import shutil
        shutil.copy2(path,OUT/(key+'.png'));files[key]=str((OUT/(key+'.png')).relative_to(ROOT))
(OUT/'manifest.json').write_text(json.dumps({'textures':files,'authored':'Asura Phase 5 analytic masks; leaf source: ambientCG LeafSet024, CC0'},indent=2)+'\n')
print('VFX_TEXTURES',len(files),OUT)

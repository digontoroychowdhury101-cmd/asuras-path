#!/usr/bin/env python3
"""Project the original sanctuary panorama onto six Roblox sky faces. No asset upload.
North faces panorama centre; golden sun is west. Preserve source panorama untouched.
"""
from pathlib import Path
import math
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/build/sanctuary_sky'
FACES = {
 'px':((1,0,0),(0,0,1),(0,1,0)),
 'nx':((-1,0,0),(0,0,-1),(0,1,0)),
 'pz':((0,0,1),(-1,0,0),(0,1,0)),
 'nz':((0,0,-1),(1,0,0),(0,1,0)),
 'py':((0,1,0),(1,0,0),(0,0,-1)),
 'ny':((0,-1,0),(1,0,0),(0,0,1)),
}

def build():
 source=np.asarray(Image.open(OUT/'panorama.png').convert('RGB'),dtype=np.float64)
 h,w,_=source.shape
 # Lat-long wrap is placed behind the arrival camera. Blend the wrap's 12px boundary only.
 n=12
 seam=(source[:,:n]+source[:,-n:][:,::-1])/2
 for k in range(n):
  a=(n-k)/n
  source[:,k]=source[:,k]*(1-a)+seam[:,k]*a
  source[:,-k-1]=source[:,-k-1]*(1-a)+seam[:,k]*a
 axis=(np.arange(1024)+.5)/1024*2-1
 u,v=np.meshgrid(axis,-axis)
 for name,(forward,right,up) in FACES.items():
  d=np.asarray(forward)+u[...,None]*np.asarray(right)+v[...,None]*np.asarray(up)
  d/=np.linalg.norm(d,axis=-1,keepdims=True)
  px=(.5+np.arctan2(d[...,0],-d[...,2])/(2*math.pi))%1*w
  py=np.clip(.445-np.arcsin(d[...,1])/math.pi,0,1)*(h-1)
  x0=np.floor(px).astype(int)%w;y0=np.floor(py).astype(int);x1=(x0+1)%w;y1=np.minimum(y0+1,h-1)
  fx=(px-np.floor(px))[...,None];fy=(py-y0)[...,None]
  img=(source[y0,x0]*(1-fx)+source[y0,x1]*fx)*(1-fy)+(source[y1,x0]*(1-fx)+source[y1,x1]*fx)*fy
  Image.fromarray(np.clip(img,0,255).astype('uint8')).save(OUT/f'Sanctuary_{name}.png')
 print('Projected six 1024-square faces; source unchanged')
if __name__=='__main__':build()

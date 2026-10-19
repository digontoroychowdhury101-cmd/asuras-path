"""Blender -b --python-exit-code 1 -P tools/assets/build_audio.py
Create mono 48 kHz PCM16 upload masters from CC0 Kenney recordings and authored synthesis.
Seeded, peak-normalized (-3 dBFS), DC-removed. Sources and QA metrics are recorded per cue.
"""
import hashlib
import json
import wave
from pathlib import Path
import aud
import numpy as np

ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/build/phase5_audio';OUT.mkdir(parents=True,exist_ok=True)
SR=48000;rng=np.random.default_rng(50019);manifest={};waves={}
def load(pack,name):
    s=aud.Sound.file(str(ROOT/'assets/source/audio'/pack/'files/Audio'/name)).rechannel(1).resample(SR)
    return s.data().reshape(-1).astype(np.float64)
def noise(duration,low=80,high=1200):
    n=int(duration*SR);freq=np.fft.rfftfreq(n,1/SR);spectrum=np.fft.rfft(rng.normal(0,1,n))
    spectrum*=np.exp(-(freq/high)**4)*(1-np.exp(-(freq/max(low,1))**4))
    a=np.fft.irfft(spectrum,n);return a/(np.std(a)+1e-9)
def kick(duration=0.4):
    t=np.arange(int(duration*SR))/SR; phase=np.cumsum(48+70*np.exp(-t*25))/SR
    return np.sin(2*np.pi*phase)*np.exp(-t*16)
def mix(duration,*items):
    out=np.zeros(int(duration*SR))
    for data,at,gain in items:
        start=int(at*SR);length=min(len(data),len(out)-start)
        if length>0:out[start:start+length]+=data[:length]*gain
    return out
def save(key,a,sources,loop=False):
    a=np.asarray(a);a-=a.mean()
    if not loop:
        count=min(int(0.005*SR),len(a)//3);a[:count]*=np.linspace(0,1,count)
        count=min(int(0.05*SR),len(a)//3);a[-count:]*=np.linspace(1,0,count)
    else:
        # Periodic end correction, spread over 30ms to avoid a sample discontinuity at loop.
        count=min(1440,len(a)//4);a[-count:]-=np.linspace(0,a[-1]-a[0],count)
    a*=0.707/max(np.max(np.abs(a)),1e-9)
    path=OUT/(key+'.wav')
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(np.round(a*32767).astype('<i2').tobytes())
    manifest[key]=dict(file=str(path.relative_to(ROOT)),duration=round(len(a)/SR,3),peak_dbfs=round(20*np.log10(np.max(np.abs(a))),2),
                       rms_dbfs=round(20*np.log10(np.sqrt(np.mean(a*a))+1e-12),2),dc=round(float(a.mean()),7),loop=loop,
                       sources=sources,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    waves[key]=a
impact=lambda name:load('impact-sounds',name+'.ogg')
rpg=lambda name:load('rpg-audio',name+'.ogg')
save('Clash',mix(1.4,(impact('impactMetal_heavy_000'),0,1),(impact('impactPlate_heavy_001'),0.01,0.35)),['Kenney impactMetal_heavy_000, impactPlate_heavy_001; CC0'])
save('ParryBass',kick(0.45),['Authored descending sine impulse'])
save('Flesh',mix(0.8,(rpg('knifeSlice'),0,0.7),(rpg('chop'),0.015,0.8),(impact('impactSoft_medium_002'),0.02,0.3)),['Kenney knifeSlice, chop, impactSoft_medium_002; CC0'])
save('Blunt',mix(0.8,(impact('impactPunch_heavy_004'),0,1),(kick(),0,0.4)),['Kenney impactPunch_heavy_004; CC0; authored sine layer'])
save('Stone',mix(1.2,(impact('impactMining_004'),0,1),(impact('impactWood_heavy_003'),0.015,0.4),(kick(),0,0.5)),['Kenney impactMining_004, impactWood_heavy_003; CC0; authored sine layer'])
t=np.arange(int(0.65*SR))/SR
save('BulletJump',noise(0.65,200,3800)*np.sin(np.pi*t/0.65)**2*np.exp(-t*3),['Authored filtered wind synthesis'])
cloth=rpg('cloth2')
glide=mix(4,*[(cloth,i*0.7,0.25) for i in range(6)])+noise(4,300,2200)*0.08
save('Glide',glide,['Kenney cloth2; CC0; authored wind layer'],True)
foot=impact('footstep_concrete_003')
slide=mix(3,*[(foot,i*0.14,0.25) for i in range(21)])+noise(3,160,3500)*0.07
save('Slide',slide,['Kenney footstep_concrete_003; CC0; authored grit layer'],True)
t=np.arange(12*SR)/SR
save('Wind',noise(12,65,1800)*(0.24+0.08*np.sin(2*np.pi*t/12)+0.04*np.sin(2*np.pi*t/4)),['Authored periodic alpine wind synthesis'],True)
t=np.arange(7*SR)/SR;bell=np.zeros_like(t)
for ratio,level,decay in ((1,1,0.55),(2.756,0.65,0.8),(5.404,0.3,1.1),(8.93,0.12,1.6)):
    bell+=np.sin(2*np.pi*98*ratio*t)*np.exp(-t*decay)*level
save('Bell',bell,['Authored inharmonic bronze-bell physical synthesis'])
water=np.zeros(6*SR)
for at in rng.uniform(0,5.7,36):
    t=np.arange(int(.3*SR))/SR;freq=rng.uniform(1200,2400)
    drop=np.sin(2*np.pi*(freq*t-700*t*t))*np.exp(-t*30)*0.14
    start=int(at*SR);water[start:start+len(drop)]+=drop
save('Water',water+noise(6,1000,7000)*0.006,['Authored resonant water droplets'],True)
t=np.arange(16*SR)/SR;drone=np.zeros_like(t)
for fundamental,weight in ((55,0.6),(73.4375,0.7),(77.8125,0.15)):
    for harmonic in range(1,14):
        frequency=round(fundamental*harmonic*16)/16
        drone+=weight*np.sin(2*np.pi*frequency*t+0.12*np.sin(2*np.pi*t/8))/harmonic**1.45
save('BossDrone',drone*(0.7+0.12*np.sin(2*np.pi*t/16)),['Authored bowed-string harmonic drone synthesis (not a cello recording)'],True)
(OUT/'manifest.json').write_text(json.dumps({'sample_rate':SR,'channels':1,'bits':16,'cues':manifest},indent=2)+'\n')
preview=np.concatenate([np.concatenate([waves[k],np.zeros(int(.25*SR))]) for k in ('Clash','ParryBass','Flesh','Blunt','Stone','BulletJump')])
with wave.open(str(OUT/'CombatPreview.wav'),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(np.round(preview*32767).astype('<i2').tobytes())
print('AUDIO_MASTERS',len(manifest),OUT)

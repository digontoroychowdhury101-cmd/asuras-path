import sys, subprocess
from pathlib import Path
sim=Path(sys.argv[1]).read_text(); data=Path(sys.argv[2]).read_text()
t="local Sim=(function()\n"+sim+"\nend)()\nlocal Data=(function()\n"+data+r"""
end)()
local function identity(n,x,y,z) local m=table.create(n*12,0) for i=1,n do local o=(i-1)*12 m[o+1],m[o+2],m[o+3]=x or 0,y or 0,z or 0 m[o+4],m[o+8],m[o+12]=1,1,1 end return m end
for phase=1,2 do
 local def=Data[phase]; local n=#def.limbs; local s=Sim.new(def,1.3)
 local ms={} for f=1,600 do ms[f]=identity(n,math.sin(f*0.05),0,-f*0.2) end
 Sim.reset(s,ms[1])
 local t0=os.clock()
 for f=1,600 do Sim.step(s,ms[f],1/60,Sim.DefaultWind,3) end
 print('P'..phase, string.format('%.1f us/step (3 passes)', (os.clock()-t0)/600*1e6))
end
"""
p=Path("work/opening_cast_bake/_bench.luau"); p.write_text(t)
r=subprocess.run(["work/bin/luau/luau","-O2",str(p)],capture_output=True,text=True); print(r.stdout, r.stderr[-300:]); p.unlink()

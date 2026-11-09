import sys, subprocess
from pathlib import Path
sim=Path(sys.argv[1]).read_text(); data=Path(sys.argv[2]).read_text()
t="local Sim=(function()\n"+sim+"\nend)()\nlocal Data=(function()\n"+data+r"""
end)()
local function identity(n,x,y,z) local m=table.create(n*12,0) for i=1,n do local o=(i-1)*12 m[o+1],m[o+2],m[o+3]=x or 0,y or 0,z or 0 m[o+4],m[o+8],m[o+12]=1,1,1 end return m end
local still={x=0,y=0,z=0,gust=0,flutter=0}
for phase=1,1 do
 local def=Data[phase]; local n=#def.limbs; local s=Sim.new(def,1.3); local rest=identity(n); Sim.reset(s,rest)
 for _=1,240 do Sim.step(s,rest,1/60,still,3) end
 local z=0 local per={} 
 for f=1,300 do z-=12/60 Sim.step(s,identity(n,0,0,z),1/60,Sim.DefaultWind,2) end
 local tot,cnt=0,0
 for i=1,s.n do if not s.isOrb[i] and not s.pin[i] then local sh=def.particles[i].sheet if sh=='Coat' then sh='Coat'..def.particles[i].c end if sh=='Under' then sh='U'..def.particles[i].c end local v=s.z[i]-s.rz[i]-z per[sh]=per[sh] or {0,0} per[sh][1]+=v per[sh][2]+=1 tot+=v cnt+=1 end end
 local out={} for k,v in per do table.insert(out,k..'='..string.format('%.2f',v[1]/v[2])) end table.sort(out)
 print('P'..phase, string.format('%.3f',tot/cnt), table.concat(out,' '))
end
"""
p=Path("work/opening_cast_bake/_trail.luau"); p.write_text(t)
r=subprocess.run(["work/bin/luau/luau",str(p)],capture_output=True,text=True); print(r.stdout, r.stderr[-300:]); p.unlink()

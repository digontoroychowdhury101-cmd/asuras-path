#!/usr/bin/env python3
"""Exercise the actual server effect scheduler with engine shims and real CombatRules."""
from pathlib import Path
import re
import subprocess
ROOT = Path(__file__).resolve().parents[1]
HEADER = r'''--!nonstrict
local Combat=require("../src/simulation/CombatRules")
local Spells=require("../src/simulation/SpellSchema")
local Rules=require("../src/simulation/SpellRules")
local World=require("../src/shared/WorldDefinitions")
local V={};V.__index=function(v,k)
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=="Unit" then return v/v.Magnitude end
 return V[k]
end
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},V) end
V.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__mul=function(a,b) if type(a)=="number" then a,b=b,a end;return vec(a.X*b,a.Y*b,a.Z*b) end
V.__div=function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
function V:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
local Vector3={new=vec,zero=vec(0,0,0)}
local CFrame={lookAt=function(p,t) return {Position=p,LookVector=(t-p).Unit} end}
local RaycastParams={new=function() return {} end}
local Enum={RaycastFilterType={Exclude=1}}
local wall=nil
local Workspace={Raycast=function(_,a,d,params)
 if wall and d.Z<0 and a.Z>=wall and a.Z+d.Z<=wall then
  local t=(wall-a.Z)/d.Z;return {Position=a+d*t,Normal=vec(0,0,1)}
 end
 if d.Y<0 and a.Y>=0 and a.Y+d.Y<=0 then return {Position=a+d*(-a.Y/d.Y),Normal=vec(0,1,0)} end
 return nil
end}
local actors={};local now=0;local cues={}
local Characters={Entities=function() return actors end,GetActor=function(id) return actors[id] end,
 IsHostile=function(a,b) return a~=b and actors[a]~=nil and actors[b]~=nil end,
 Cue=function(kind,id,data) table.insert(cues,{Kind=kind,Id=id,Data=data}) end,
 Teleport=function(id,cf) actors[id].Root.Position=cf.Position;actors[id].Root.CFrame=cf end,
 ApplyArea=function(a,b,damage,posture,unblockable)
  return Combat.applyArea(actors[a].Fighter,actors[b].Fighter,now,damage,posture,unblockable,true,nil)
 end}
local function actor(id,z,weapon)
 local e={Id=id,Fighter=Combat.new(id,weapon or "Jian",0),Duel=nil,Model={Attributes={}},Root={Position=vec(0,3,z),CFrame={LookVector=vec(0,0,-1)},Parent=true}}
 function e.Model:SetAttribute(k,v) self.Attributes[k]=v end
 actors[id]=e;return e
end
'''
def inline(name, path):
    source = (ROOT / path).read_text()
    source = re.sub(r'^export type', 'type', source, flags=re.M)
    source = '\n'.join(line for line in source.splitlines() if not (line.startswith('local ') and ('require(' in line or 'game:GetService' in line)))
    return f'local {name}=(function()\n{source}\nend)()\n'
TESTS = r'''
local function reset()
 Effects.clear();table.clear(actors);table.clear(cues);wall=nil;now=0
 return actor(1,-900),actor(2,-906)
end
local function step(t,dt) now=t;Effects.step(t,dt or 1/60) end
local a,b=reset();b.Fighter.PoiseArmor=1;b.Fighter.State="Startup"
Effects.release(a,"ThunderclapPalm",1,0);step(0)
assert(b.Fighter.ActiveHP<100 and b.Fighter.State=="Hitstun","Palm interrupts actual armored target")
a,b=reset();b.Fighter.State="Blocking";Effects.release(a,"BlackflameSurge",1,0);step(0)
assert(b.Fighter.ActiveHP==72,"Void bypasses real guarded resolver")
a,b=reset();b.Root.Position=vec(0,3,-912);local c=actor(3,-925)
Effects.release(a,"HeavenlyLightningSpear",1,0)
for t=1,60 do step(t/60) end
assert(b.Fighter.ActiveHP==70 and c.Fighter.ActiveHP==70,"Swept spear pierces two victims once")
a,b=reset();wall=-909;b.Root.Position=vec(0,3,-912)
Effects.release(a,"HeavenlyLightningSpear",1,0);for t=1,60 do step(t/60) end
assert(b.Fighter.ActiveHP==100,"Projectile blocked by wall")
a,b=reset();Effects.release(a,"EmberCataclysm",1,0);step(0.59)
assert(b.Fighter.ActiveHP==100,"Pillars respect delay")
step(0.61);assert(b.Fighter.ActiveHP<100,"First pillar resolves")
local hp=b.Fighter.ActiveHP;step(1.21);assert(b.Fighter.ActiveHP<hp,"Second pillar resolves")
a,b=reset();Effects.release(a,"DragonsMaw",1,0);step(0);step(0.23);step(0.45)
local burned=b.Fighter.ActiveHP;step(1.5)
assert(b.Fighter.ActiveHP<=burned-6,"Burn stacks tick through server resolver")
a,b=reset();Effects.release(a,"GraveTendrils",1,0);step(0)
assert(b.Fighter.RootUntil==2 and b.Model.Attributes.RootUntil==2,"Root replicated for movement")
a,b=reset();Effects.release(a,"JadeAegis",1,0)
assert(a.Fighter.WardUntil==30 and Combat.applyDamage(a.Fighter,999,"Heavy",1)==0,"Runtime ward")
a,b=reset();Effects.release(a,"GaleStep",1,0)
assert(a.Root.Position.Z==-918 and a.Model.Attributes.PhantomUntil==2,"Safe dash with AI decoy")
a,b=reset();b.Root.Position=vec(0,3,-925);Effects.release(a,"Thunderfall",1,0)
for t=1,30 do step(t/60) end
assert(b.Fighter.ActiveHP<100 and a.Root.Position.Z>-950,"Thunderfall impacts first enemy and teleports")
a,b=reset();Effects.release(a,"HeavenlyLightningSpear",1,0);a.Duel="new-match"
for t=1,60 do step(t/60) end
assert(b.Fighter.ActiveHP==100,"Scheduled effect cannot enter another match")
a,b=reset();b.Fighter=Combat.new(2,"WarFan",0);b.Fighter.Qi=0;b.Fighter.State="Blocking"
Effects.release(a,"HeavenlyLightningSpear",1,0);for t=1,60 do step(t/60) end
assert(b.Fighter.ActiveHP==100 and b.Fighter.Qi==15,"Fan projectile parry")
a,b=reset();Effects.release(a,"HeavenlyLightningSpear",1,0);a.Fighter.State="KO"
for t=1,60 do step(t/60) end
assert(b.Fighter.ActiveHP==100,"Death cancels scheduled projectile")
print("Phase 2 server effects: 14 scenarios passed")
'''
source = HEADER + inline('Geometry', 'src/server/Services/SpellGeometry.luau') + inline('Effects', 'src/server/Services/SpellEffects.luau') + TESTS
output = ROOT / 'work' / 'test_weapons_and_spells_runtime.generated.luau'
output.parent.mkdir(exist_ok=True)
output.write_text(source)
subprocess.run([str(ROOT / 'work/bin/luau/luau'), str(output.relative_to(ROOT))], cwd=ROOT, check=True)

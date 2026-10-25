#!/usr/bin/env python3
"""Run real boss scheduler, motion, hazards, tactics and duo modules with deterministic engine fakes."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
HEADER = r'''--!strict
local Combat=require("../src/simulation/CombatRules")
local World=require("../src/shared/WorldDefinitions")
local Rules=require("../src/shared/BossEncounterRules")
local Types=require("../src/shared/BossTypes")
local AttackCatalog=require("../src/shared/BossAttackCatalog")
local Bodies=require("../src/shared/BossBodies")
local HandoffRules=require("../src/shared/BossHandoff")
local checks=0
local function check(value:any, label:string) assert(value,label); checks+=1 end
local V:any={}
V.__index=function(v:any,k:string):any
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=="Unit" then return v/v.Magnitude end
 return V[k]
end
local function vec(x:number,y:number,z:number):any return setmetatable({X=x,Y=y,Z=z},V) end
V.__add=function(a:any,b:any) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V.__sub=function(a:any,b:any) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__mul=function(a:any,b:any) if type(a)=="number" then a,b=b,a end;return vec(a.X*b,a.Y*b,a.Z*b) end
V.__div=function(a:any,b:any) return vec(a.X/b,a.Y/b,a.Z/b) end
function V:Dot(b:any) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function V:Lerp(b:any,t:number) return self+(b-self)*t end
local Vector3:any={new=vec,zero=vec(0,0,0),zAxis=vec(0,0,1)}
local CFrame:any={new=function(p:any) return {Position=p,LookVector=vec(0,0,-1)} end,
 lookAt=function(p:any,t:any) return {Position=p,LookVector=(t-p).Unit} end}
local actors:any={}; local now=0; local cues:any={}; local hits:any={}
local Characters:any={}
function Characters.GetEntity(id:number) return actors[id] end
function Characters.Entities() return actors end
function Characters.Now() return now end
function Characters.StopMoving(_id:number) end
function Characters.SetGuard(_id:number,_held:boolean) end
function Characters.Face(_id:number,_p:any) end
function Characters.Teleport(id:number,cf:any) actors[id].Root.Position=cf.Position end
function Characters.Cue(kind:string,id:number,data:any) table.insert(cues,{Kind=kind,Id=id,Data=data}) end
function Characters.ApplyBossAttack(id:number,target:number,damage:number,posture:number,kind:string)
 local outcome=Combat.applyBossAttack(actors[id].Fighter,actors[target].Fighter,now,damage,posture,kind,true,{})
 table.insert(hits,{Source=id,Target=target,Kind=kind,Outcome=outcome});return outcome
end
function Characters.RestoreFighter(id:number) actors[id].Fighter.ActiveHP=actors[id].Fighter.MaxHP end
function Characters.Cinematic(id:number,duration:number) Combat.cinematic(actors[id].Fighter,now,duration) end
local function actor(id:number,x:number,y:number,z:number):any
 local root:any={Position=vec(x,y,z),CFrame=CFrame.lookAt(vec(x,y,z),vec(x,y,z-1)),Anchored=false,AssemblyLinearVelocity=Vector3.zero}
 local model:any={Attributes={}}
 function model:SetAttribute(k:string,v:any) self.Attributes[k]=v end
 function model:GetAttribute(k:string) return self.Attributes[k] end
 function model:GetScale() return self.Attributes.__scale or 1 end
 function model:PivotTo(cf:any) root.Position,root.CFrame=cf.Position,cf end
 local e:any={Id=id,Root=root,Model=model,Fighter=Combat.new(id,"Jian",0),Kind=if id>0 then "Player" else "Enemy",Humanoid={HipHeight=2}}
 actors[id]=e;return e
end
local registry:any={World=World,Types=Types,Rules=Rules,Combat=Combat,Characters=Characters,Bodies=Bodies,HandoffRules=HandoffRules}
'''
MODULES = ["BossMotion", "BossHazards", "EncounterHandoff", "BossAttackService", "BossTactics", "BossDuo"]
chunks = [HEADER]
for name in MODULES:
    source = (ROOT / "src/server/Services" / f"{name}.luau").read_text()
    source = re.sub(r"^export type", "type", source, flags=re.MULTILINE)
    source = re.sub(r"^local (?:Shared|Replicated) = game:GetService.*$", "", source, flags=re.MULTILINE)
    bindings = {"Motion": "BossMotion", "Hazards": "BossHazards", "Attacks": "BossAttackService", "Tactics": "BossTactics", "Handoff": "EncounterHandoff"}
    def bind(match):
        variable = match.group(1)
        return f"local {variable} = registry.{bindings.get(variable, variable)}"
    source = re.sub(r"^local (\w+) = require\(.*\)$", bind, source, flags=re.MULTILINE)
    chunks.append(f"registry.{name}=(function()\n{source}\nend)()")
chunks.append(r'''
local Scheduler=registry.BossAttackService
local Hazards=registry.BossHazards
local Motion=registry.BossMotion
local Tactics=registry.BossTactics
local Duo=registry.BossDuo
local source=actor(-1,0,3,0)
local player=actor(1,4,3,0)
local outsider=actor(2,4,3,0)
local allowed={[1]=true}
local sweep={Id="Sweep",Kind="PerilousSweep",Windup=0.8,Radius=10,Damage=20,Posture=20}
Scheduler.start(-1,sweep,1,allowed,0)
now=0.79;Scheduler.step(-1,now)
check(#hits==0,"no damage before warning expires")
now=0.8;Scheduler.step(-1,now)
check(#hits==1 and hits[1].Target==1,"only participants take sweep damage")
check(outsider.Fighter.ActiveHP==100,"outsider remains safe")
player.Fighter=Combat.new(1,"Jian",1);player.Root.Position=vec(4,12,0)
Scheduler.start(-1,sweep,1,allowed,1)
now=1.8;Scheduler.step(-1,now)
check(#hits==1,"jump clears the ground sweep")
player.Root.Position=vec(4,3,0)
local thrust={Id="Thrust",Kind="PerilousThrust",Windup=1,Radius=15,Damage=20,Posture=30,Motion="Lunge"}
Scheduler.start(-1,thrust,1,allowed,2)
check(source.Root.Anchored,"lunge motion takes deterministic ownership")
player.Fighter.State="Deflecting";player.Fighter.DeflectPressedAt=2.91
now=3;Scheduler.step(-1,now)
check(hits[#hits].Outcome=="Deflected" and source.Fighter.Posture>=75,"scheduled thrust supports tight deflect")
check(not source.Root.Anchored,"lunge returns physics ownership")
local gap=player.Root.Position-source.Root.Position
check(math.abs(Vector3.new(gap.X,0,gap.Z).Magnitude-3)<0.01,"lunge ends a body short of the target, not inside it")
source.Root.Position=vec(0,3,0)
source.Fighter=Combat.new(-1,"Jian",3)
Scheduler.start(-1,thrust,1,allowed,4);Scheduler.cancel(-1)
check(not source.Root.Anchored and source.Model:GetAttribute("AsuraBossAttack")==nil,"reset cancels warning and releases anchor")
local prior=#hits
now=8;check(not Scheduler.step(-1,now) and #hits==prior,"canceled attack cannot fire later")
-- Expanding rings apply exactly once per pulse, including frame jumps.
player.Fighter=Combat.new(1,"Jian",0);player.Root.Position=vec(20,3,0)
local tremor={Id="Tremor",Kind="Shockwave",Windup=1,Radius=100,Damage=10,Posture=10,Speed=20,Height=9,Repeats=2,Interval=1.2}
local wave=Hazards.new(tremor,vec(0,3,0),vec(0,3,0),10,allowed)
now=10.5;Hazards.step(-1,wave,now);check(#hits==prior,"ring has not arrived")
now=11.1;Hazards.step(-1,wave,now);check(#hits==prior+1,"first ring arrives")
now=11.15;Hazards.step(-1,wave,now);check(#hits==prior+1,"same ring cannot hit twice")
player.Fighter.State="Idle";now=12.3;Hazards.step(-1,wave,now)
check(#hits==prior+2,"second stomp produces an independent ring")
player.Root.Position=vec(20,15,0);prior=#hits
local airborne=Hazards.new(tremor,vec(0,3,0),vec(0,3,0),13,allowed)
now=14.1;Hazards.step(-1,airborne,now);check(#hits==prior,"glide clears tremor")
-- A real tracking projectile follows its assigned participant; expiry limits lifetime.
player.Root.Position=vec(20,3,0);player.Fighter=Combat.new(1,"Jian",0)
local spear={Id="Spears",Kind="Barrage",Windup=1,Radius=60,Damage=10,Posture=10,Count=1,Speed=30}
local barrage=Hazards.new(spear,vec(0,3,0),vec(20,3,0),20,allowed)
for i=1,30 do now=20+i*0.1;Hazards.step(-1,barrage,now) end
check(#hits==prior+1,"tracking spear hits exactly one assigned target")
-- Aerial traversal includes a high perch and is fully cancelable.
source.Root.Position=vec(0,3,0)
Motion.begin(-1,"Pillar",vec(30,3,0),30,32)
Motion.step(-1,31)
check(source.Root.Position.Y>=30,"meteor pounce hangs above the arena")
Motion.step(-1,32)
check((source.Root.Position-vec(30,source.Root.Position.Y,0)).Magnitude>=2.99,"meteor pounce lands beside the mark, not on it")
Motion.cancel(-1);check(not source.Root.Anchored,"interruption releases perched beast")
Motion.begin(-1,"Aerial",vec(30,3,0),33,35);Motion.step(-1,34)
source.Fighter.State="KO";source.Root.Anchored=true -- settleCorpse pinned the felled body
Motion.cancel(-1);check(source.Root.Anchored,"a boss felled in flight stays pinned where it was set down")
source.Fighter=Combat.new(-1,"Jian",0);source.Root.Anchored=false
-- Kill either duo member; the other heals once, inherits attacks, and defers victory.
local first=actor(-10,0,3,0);local second=actor(-11,10,3,0)
local definition=World.Bosses.TwinSentinels
Duo.register(definition,{-10,-11})
second.Fighter.ActiveHP=25;first.Fighter.State="KO"
check(not Duo.onKO(definition.Id,-10),"one sentinel death does not finish encounter")
check(second.Fighter.ActiveHP==100,"survivor restores full HP")
check(second.Model:GetAttribute("AsuraAffinity")=="Lightning+Iron","survivor inherits elemental affinity")
second.Fighter.ActiveHP=40;Duo.onKO(definition.Id,-10)
check(second.Fighter.ActiveHP==40,"duplicate KO cannot heal twice")
second.Fighter.State="KO"
check(Duo.onKO(definition.Id,-11),"both sentinel deaths finish encounter")
check(not Duo.onKO(definition.Id,-11),"victory callback is emitted once")
Duo.forget(definition.Id);check(#Duo.members(definition.Id)==0,"reset clears both member registrations")
-- Sustained distant targeting invokes a telegraphed pursuit rather than passive ranged kiting.
source.Fighter=Combat.new(-1,"Jian",0);source.Root.Position=vec(0,3,0)
player.Fighter=Combat.new(1,"Jian",0);player.Root.Position=vec(80,3,0)
Tactics.reset(-1);now=40
Tactics.step(-1,World.Bosses.GrandmasterShen,1,1,allowed,now)
now=42.5;Tactics.step(-1,World.Bosses.GrandmasterShen,1,1,allowed,now)
check(cues[#cues].Data.move=="Pursuit","range clamp schedules pursuit after dwell time")
Tactics.reset(-1)
-- The Titan kneels to deathblow height and rises back to its own scaled standing height.
source.Humanoid.HipHeight=6.577;source.Fighter.State="StanceBroken";now=50
Tactics.step(-1,World.Bosses.SlumberingTitan,1,1,allowed,now)
check(source.Humanoid.HipHeight==0 and source.Model:GetAttribute("AsuraVisceralTarget")=="Head","titan kneels for the head deathblow")
source.Fighter.State="Idle";now=53
Tactics.step(-1,World.Bosses.SlumberingTitan,1,1,allowed,now)
check(source.Humanoid.HipHeight==6.577 and source.Model:GetAttribute("AsuraVisceralTarget")=="Ankles","titan rises to its own standing height")
Tactics.reset(-1)
print(string.format("Boss runtime: %d checks passed",checks))
''')
hud_source = (ROOT / "src/client/Controllers/BossHud.luau").read_text()
hud_source = re.sub(r"^local \w+ = require\(.*\)$", "", hud_source, flags=re.MULTILINE)
chunks.append("local BossHud=(function()\nlocal Kit:any={}\n" + hud_source + "\nend)()")
chunks.append(r'''
local hudFrame:any={FindFirstChild=function(_self:any,_name:string) return nil end}
local hudState:any={Get=function(_self:any,id:number) return actors[id] end}
actors[-10].Snapshot={State="KO",MaxHP=100,ActiveHP=0,RecoverableHP=0,Posture=0,PostureCapacity=100}
actors[-11].Snapshot={State="Idle",MaxHP=100,ActiveHP=100,RecoverableHP=0,Posture=50,PostureCapacity=100}
local hp,recoverable,posture=BossHud.values(hudFrame,hudState,{-10,-11})
check(hp==1 and recoverable==1 and posture==0.5,"duo HUD shows survivor full HP after enrage")
actors[-11].Snapshot.State="KO"
local defeatedHP=BossHud.values(hudFrame,hudState,{-10,-11})
check(defeatedHP==0,"duo HUD reaches zero when both members fall")
print("Boss HUD: 2 checks passed")
''')
# Exercise the existing private phase coordinator directly, without rewriting its logic.
ai = (ROOT / "src/server/Services/AIService.luau").read_text()
phase_source = ai[ai.index("local function scheduleShockwave"):ai.index("-- Agent loop")]
chunks.append(r'''
function Characters.ApplyStats(id:number,stats:any,refill:boolean) Combat.applyStats(actors[id].Fighter,stats,refill) end
function Characters.ForceWeapon(id:number,weapon:any) Combat.forceWeapon(actors[id].Fighter,weapon) end
function Characters.Tint(_id:number,_rgb:any) end
function Characters.ApplyArea(id:number,target:number,damage:number,posture:number,unblockable:boolean)
 return Combat.applyArea(actors[id].Fighter,actors[target].Fighter,now,damage,posture,unblockable,true,{})
end
local PhaseCoordinator=(function()
 local BossTactics=registry.BossTactics
 local Handoff=registry.EncounterHandoff
 local BossAppearance={phase=function(model:any,set:any) model:SetAttribute("AsuraAnimationSet",set) end}
 local Schema={isStunned=function(state:string) return state=="StanceBroken" or state=="Hitstun" end}
 local Telegraph={shockwave=function(wave:any,t:number) return t,t+math.max(0.45,wave.Windup) end}
 local function setMode(agent:any,mode:string,_time:number) agent.Mode=mode end
''')
chunks.append(phase_source)
chunks.append(r'''
 return {Apply=applyPhase,Update=updateBoss}
end)()
source.Fighter=Combat.new(-1,"Jian",0)
local agent:any={Id=-1,Phase=1,Deathblows=0,Allowed={[1]=true},TransitionEnd=math.huge,NextSpecial=math.huge,Target=1,Mode="Combat",HoldUntil=-math.huge}
PhaseCoordinator.Apply(agent,World.Bosses.GrandmasterShen,1,source)
source.Fighter.ActiveHP=source.Fighter.MaxHP*0.5
now=60
check(PhaseCoordinator.Update(agent,World.Bosses.GrandmasterShen,source,now),"threshold begins phase sequence")
check(agent.Mode=="Cinematic" and Combat.isInvulnerable(source.Fighter,now+1),"phase freezes AI and grants invulnerability")
check(source.Fighter.Weapon=="Jian","weapon remains intact until transformation completes")
now=62.4
PhaseCoordinator.Update(agent,World.Bosses.GrandmasterShen,source,now)
check(source.Fighter.Weapon=="Guandao" and agent.Phase==2,"completed transformation swaps weapon schema")
check(source.Model:GetAttribute("AsuraAnimationSet")=="DemonicChimera","completed transformation selects phase animation set")
check(not source.Fighter.KOProtected and agent.Mode=="Combat","final phase reopens combat and allows defeat")
source.Fighter=Combat.new(-1,"Jian",0)
agent.Phase,agent.Deathblows,agent.TransitionEnd=1,1,math.huge
source.Fighter.State="DeathblowVictim"
now=70
PhaseCoordinator.Update(agent,World.Bosses.GrandmasterShen,source,now)
check(agent.Phase==1,"deathblow animation completes before transformation begins")
source.Fighter.State="Idle"
PhaseCoordinator.Update(agent,World.Bosses.GrandmasterShen,source,now)
check(agent.Phase==2,"deathblow threshold transitions after cinematic victim state")
print("Boss phase coordinator: 8 checks passed")
''')
# Use the real WorldService entry/participation/reset/reward functions with fake engine boundaries.
world_source = (ROOT / "src/server/Services/WorldService.luau").read_text()
fog_source = world_source[world_source.index("local function endFight"):world_source.index("-- Event wiring")]
chunks.append(r'''
local GateCoordinator=(function()
 local BossRules=Rules
 local EncounterHandoff=registry.EncounterHandoff
 local sessions:any={};local fights:any={};local sealed:any={};local awards:any={};local drops=0;local present=true;local failSpawn=false
 local AI={SpawnBoss=function(_id:string,_participants:any) return if failSpawn then nil else -99 end,
  DespawnBoss=function(_id:string) present=false end,GetBossEntity=function(_id:string) return if present then -99 else nil end,
  SetBossTargets=function(_id:string,_participants:any) end}
 local BossArenas={loot=function(_position:any,_essence:number) drops+=1 end}
 local function setGate(id:string,value:boolean) sealed[id]=value end
 local function vec(p:any) return Vector3.new(p.X,p.Y,p.Z) end
 local function toCFrame(p:any) return CFrame.new(vec(p)) end
 local function inBounds(b:any,p:any) return World.contains(b,p.X,p.Y,p.Z) end
 local function entityPosition(id:number) return actors[id] and actors[id].Root.Position end
 local function session(id:number) return sessions[id] end
 local function flush(_s:any) end
 local function publish(s:any)
  local ids={};for id in s.Bosses do table.insert(ids,id) end;table.sort(ids)
  s.Player:SetAttribute("AsuraBosses",table.concat(ids,","))
 end
 local function enqueue(s:any,_label:string,run:any)
  run({RecordBossDefeat=function(_store:any,id:number,boss:string,_amount:number) awards[id]=(awards[id] or 0)+1;return true end})
 end
 function Characters.IsInDuel(_id:number) return false end
''')
chunks.append(fog_source)
chunks.append(r'''
 local function setup(ids:any)
  table.clear(sessions);table.clear(fights);table.clear(sealed);table.clear(awards);drops=0;present=true;failSpawn=false
  for _,id in ids do
   local e=actor(id,0,3,-1880)
   sessions[id]={UserId=id,Player=e.Model,Bosses={},Fight=nil}
  end
 end
 return {Setup=setup,Enter=traverseGate,Update=updateGates,End=endFight,Sessions=sessions,Sealed=sealed,Awards=awards,
  Drops=function() return drops end,FailSpawn=function() failSpawn=true end}
end)()
local gate=World.FogGates.Gate_AshColosseum
GateCoordinator.Setup({1,2})
actors[2].Root.Position=vec(0,3,-1920)
check(GateCoordinator.Enter(1,gate),"interacting with fog begins encounter")
check(GateCoordinator.Sealed[gate.Id] and GateCoordinator.Sessions[2].Fight==gate.Id,"fog seals and includes living allies already inside")
check(actors[1].Model:GetAttribute("AsuraEncounter")=="GrandmasterShen","encounter identity replicates to participant")
actors[1].Root.Position=vec(300,3,-1900);GateCoordinator.Update()
check(actors[1].Root.Position.X==gate.Inside.X,"participant cannot escape arena perimeter")
actors[1].Fighter.State="KO";GateCoordinator.Update()
check(GateCoordinator.Sealed[gate.Id] and GateCoordinator.Sessions[1].Fight==nil,"one death releases that player while co-op encounter stays sealed")
GateCoordinator.End(gate.Id,true)
check(not GateCoordinator.Sealed[gate.Id],"victory unlocks fog")
check(GateCoordinator.Awards[2]==1 and GateCoordinator.Awards[1]==nil and GateCoordinator.Drops()==1,"victory rewards living participants and disperses loot once")
check(actors[2].Model:GetAttribute("AsuraBosses")=="GrandmasterShen","victory mirrors boss flag immediately")
GateCoordinator.End(gate.Id,true)
check(GateCoordinator.Awards[2]==1 and GateCoordinator.Drops()==1,"duplicate defeat event cannot repeat loot")
GateCoordinator.Setup({1});GateCoordinator.Enter(1,gate)
actors[1].Fighter.State="KO";GateCoordinator.Update()
check(not GateCoordinator.Sealed[gate.Id] and GateCoordinator.Drops()==0,"party wipe opens fog without rewards")
GateCoordinator.Setup({1});GateCoordinator.FailSpawn()
check(not GateCoordinator.Enter(1,gate) and actors[1].Root.Position.Z==gate.Outside.Z,"failed spawn returns entrant outside safely")
print("Boss fog coordinator: 11 checks passed")
''')
generated = ROOT / "work/test_boss_runtime.generated.luau"
generated.parent.mkdir(exist_ok=True)
generated.write_text("\n".join(chunks))
raise SystemExit(subprocess.run([str(ROOT / "work/bin/luau/luau"), str(generated)], cwd=ROOT).returncode)

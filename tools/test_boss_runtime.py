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
local LakeRules=require("../src/shared/ShenLakeRules")
local Types=require("../src/shared/BossTypes")
local AttackCatalog=require("../src/shared/BossAttackCatalog")
local Bodies=require("../src/shared/BossBodies")
local HandoffRules=require("../src/shared/BossHandoff")
local Weapons=require("../src/simulation/WeaponSchema")
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
local Vector3:any={new=vec,zero=vec(0,0,0),yAxis=vec(0,1,0),zAxis=vec(0,0,1)}
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
local registry:any={World=World,Types=Types,Rules=Rules,Combat=Combat,Characters=Characters,Bodies=Bodies,HandoffRules=HandoffRules,Weapons=Weapons}
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
-- Run Shen's authored attacks at the live Bellwood elevation.
local lakeSpawn=World.Bosses.GrandmasterShen.Spawn
local lakeY=lakeSpawn.Y
source.Model:SetAttribute("AsuraEncounter","GrandmasterShen")
source.Root.Position=vec(lakeSpawn.X,lakeY,lakeSpawn.Z)
player.Root.Position=source.Root.Position+vec(4,0,0)
player.Fighter=Combat.new(1,"Jian",0)
local lakeHits=#hits
local abbotSweep=AttackCatalog.Shen[5]
Scheduler.start(-1,abbotSweep,1,allowed,23)
check(math.abs(cues[#cues].Data.y-(lakeY-3))<1e-6,"Shen's sweep warning marks the lake surface")
now=23+abbotSweep.Windup;Scheduler.step(-1,now)
check(#hits==lakeHits+1,"a grounded participant takes Shen's sweep on the lake")
player.Root.Position=source.Root.Position+vec(4,8,0)
Scheduler.start(-1,abbotSweep,1,allowed,25)
now=25+abbotSweep.Windup;Scheduler.step(-1,now)
check(#hits==lakeHits+1,"jump clears Shen's sweep on the lake")
player.Root.Position=source.Root.Position+vec(20,0,0)
player.Fighter=Combat.new(1,"Jian",0)
local bloodWave=AttackCatalog.Chimera[1]
Scheduler.start(-1,bloodWave,1,allowed,27)
now=27+bloodWave.Windup+20/bloodWave.Speed+0.05;Scheduler.step(-1,now)
check(#hits==lakeHits+2,"Blood Wave reaches a grounded participant on the lake")
check(cues[#cues].Kind=="BossHazard" and math.abs(cues[#cues].Data.y-(lakeY-2.7))<1e-6,"Blood Wave renders above the lake surface")
Scheduler.cancel(-1)
local beads=AttackCatalog.Shen[4]
Scheduler.start(-1,beads,1,allowed,29)
now=29+beads.Windup;Scheduler.step(-1,now)
check(cues[#cues].Kind=="BossProjectile" and math.abs(cues[#cues].Data.y-(lakeY+beads.Rise))<1e-6,
 "Prayer Beads launch above water at Shen's cast height")
Scheduler.cancel(-1)
source.Model:SetAttribute("AsuraEncounter",nil)
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
-- Post-F26 Step 4: the Twins never have two perilous attacks pending at once (Studio: Zhao's thrust and
-- the Bull's charge landed in the same frame after the entry hold); the Bull's lands a lead after Zhao's.
local zhao=actor(-20,0,3,0);local bull=actor(-21,8,3,0)
zhao.Model:SetAttribute("AsuraEncounter","TwinSentinels");bull.Model:SetAttribute("AsuraEncounter","TwinSentinels")
zhao.Model.Attributes.__scale=1.2;bull.Model.Attributes.__scale=1.7
player.Fighter=Combat.new(1,"Jian",0);player.Root.Position=vec(4,3,6)
local twins=World.Bosses.TwinSentinels
local bullBoss=table.clone(twins);bullBoss.Phases={table.clone(twins.Phases[1])};bullBoss.Phases[1].Attacks=twins.Partner.Attacks
now=60;Tactics.hold(-20,now);Tactics.hold(-21,now)
check(Tactics.step(-20,twins,1,1,allowed,now),"Zhao opens with his perilous")
check(not Tactics.step(-21,bullBoss,1,1,allowed,now),"the Bull holds while Zhao's is pending")
local zhaoLast=Scheduler.lastImpact(-20)
check(zhaoLast~=nil and zhaoLast>=now+0.8,"Zhao's last pulse is known")
local bullStart=nil
while now<70 and not bullStart do
 now+=1/60
 Tactics.step(-20,twins,1,1,allowed,now)
 Tactics.step(-21,bullBoss,1,1,allowed,now)
 if Scheduler.lastImpact(-21) then bullStart=now end
end
check(bullStart~=nil,"the Bull's perilous follows")
local bullImpact=Scheduler.lastImpact(-21)
check(bullImpact and zhaoLast and bullImpact>=zhaoLast+Rules.DuoPerilousGap-1e-6,"the Bull's lands at least the readable lead after Zhao's last pulse")
Tactics.reset(-20);Tactics.reset(-21);actors[-20]=nil;actors[-21]=nil
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
 local BossAppearance={phase=function(model:any,set:any) model:SetAttribute("AsuraAnimationSet",set) end,stage=function(model:any,index:number) model:SetAttribute("AsuraStagedPhase",index) end}
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
check(source.Fighter.Weapon=="Guandao","his guandao stays in hand through the transformation")
check(source.Model:GetAttribute("AsuraAnimationSet")=="DisciplinedMaster" and agent.RevealAt==60.9,"the old body holds until the transition's reveal")
now=60.95
PhaseCoordinator.Update(agent,World.Bosses.GrandmasterShen,source,now)
check(source.Model:GetAttribute("AsuraAnimationSet")=="DemonicChimera" and agent.RevealAt==nil and agent.Mode=="Cinematic","the new body appears at the reveal, still under the cinematic")
check(agent.Profile==World.Bosses.GrandmasterShen.Phases[1].AI,"the moveset waits for the end of the transition")
now=62.4
PhaseCoordinator.Update(agent,World.Bosses.GrandmasterShen,source,now)
check(source.Fighter.Weapon=="Guandao" and agent.Phase==2 and agent.Profile==World.Bosses.GrandmasterShen.Phases[2].AI,"completed transformation adopts the second phase's moveset")
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
local phaseWaveHits={}
function Characters.ApplyArea(id:number,target:number,damage:number,posture:number,unblockable:boolean)
 table.insert(phaseWaveHits,target)
 return Combat.applyArea(actors[id].Fighter,actors[target].Fighter,now,damage,posture,unblockable,true,{})
end
local shen=World.Bosses.GrandmasterShen
source.Root.Position=vec(shen.Spawn.X,shen.Spawn.Y,shen.Spawn.Z)
player.Root.Position=source.Root.Position+vec(4,0,0)
outsider.Root.Position=source.Root.Position+vec(4,7,0)
player.Model.Parent=true;outsider.Model.Parent=true
source.Fighter=Combat.new(-1,"Jian",0)
agent.Boss,agent.Kind,agent.Allowed=shen,"Boss",{[1]=true,[2]=true}
agent.TransitionEnd=math.huge
agent.Shockwave={At=71,Wave=shen.Phases[2].Transition.Shockwave,Cancelable=false}
now=71;PhaseCoordinator.Update(agent,shen,source,now)
check(#phaseWaveHits==1 and phaseWaveHits[1]==1,"Shen's phase wave reaches a grounded lake participant and misses a jump")
print("Boss phase coordinator: 9 checks passed")
''')
# Use the real WorldService entry/participation/reset/reward functions with fake engine boundaries.
world_source = (ROOT / "src/server/Services/WorldService.luau").read_text()
fog_source = world_source[world_source.index("local function lakeGate"):world_source.index("-- Event wiring")]
chunks.append(r'''
local GateCoordinator=(function()
 local BossRules=Rules
 local EncounterHandoff=registry.EncounterHandoff
 local sessions:any={};local fights:any={};local sealed:any={};local awards:any={};local drops=0;local present=false;local failSpawn=false
 local running, walkable = true, false
 local AI={SpawnBoss=function(_id:string,_participants:any) if failSpawn then return nil end; present=true; return -99 end,
  PreviewBoss=function(_id:string) present=true; return -99 end,
  DespawnBoss=function(_id:string) present=false end,IsBossPresent=function(_id:string) return present end,GetBossEntity=function(_id:string) return if present then -99 else nil end,
  SetBossTargets=function(_id:string,_participants:any) end}
 local BossArenas={loot=function(_position:any,_essence:number) drops+=1 end,still=function(_id:string,on:boolean) walkable=on end}
 local Workspace:any={Attributes={},SetAttribute=function(self,k,v) self.Attributes[k]=v end,GetServerTimeNow=function() return 1000+now end}
 local task={spawn=function(fn,arg) fn(arg) end}
 local os={clock=function() return now end}
 local LAKE_RELIC_DISTANCE=14
 local lake:any={State="Dormant",Since=0,Summoners={}}
 local anchor:any={IsA=function(_,class) return class=="BasePart" end,Position=Vector3.new(10,20,30)}
 local prompt:any={Parent=anchor,IsDescendantOf=function(_,root) return root==Workspace end}
 local relicPrompts:any={[prompt]=true}
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
 local spells:any={};local refreshed:any={}
 local function souls(id:number) spells[id]=spells[id] or {};return {inventory={spells=spells[id]}} end
 local function enqueue(s:any,_label:string,run:any)
  run({RecordBossDefeat=function(_store:any,id:number,boss:string,_amount:number) awards[id]=(awards[id] or 0)+1;return true end,
   UnlockSpell=function(_store:any,id:number,spell:string) souls(id).inventory.spells[spell]=true;return true end})
 end
 function Characters.IsInDuel(_id:number) return false end
 function Characters.RefreshProgression(id:number) refreshed[id]=(refreshed[id] or 0)+1 end
''')
chunks.append(fog_source)
chunks.append(r'''
 local function setup(ids:any)
  table.clear(sessions);table.clear(fights);table.clear(sealed);table.clear(awards);table.clear(spells);table.clear(refreshed);drops=0;present=false;failSpawn=false
  setLake("Dormant")
  for _,id in ids do
   local o=World.FogGates[World.Bosses.GrandmasterShen.FogGate].Outside;local e=actor(id,o.X,o.Y,o.Z)
   sessions[id]={UserId=id,Player=e.Model,Bosses={},Fight=nil}
  end
 end
 return {Setup=setup,Enter=traverseGate,Update=updateGates,End=endFight,Sessions=sessions,Sealed=sealed,Awards=awards,Lake=lake,
  Drops=function() return drops end,FailSpawn=function() failSpawn=true end,Present=AI.IsBossPresent,Walkable=function() return walkable end,
  RelicPosition=anchor.Position,TakeRelic=function(id) return takeRelic(id,prompt) end,Spells=spells,Refreshed=refreshed,Phase=function() return Workspace.Attributes[LakeRules.PhaseAttribute] end}
end)()
local gate=World.FogGates[World.Bosses.GrandmasterShen.FogGate]
local G=GateCoordinator
local function put(id:number,p:any,dz:number?) actors[id].Root.Position=vec(p.X,p.Y,p.Z+(dz or 0)) end
check(gate.Summons==true,"Shen's gate is the summoned lake")
G.Setup({1,2});G.Update()
put(1,gate.Inside);put(2,gate.Inside,-10);G.Update()
check(not G.Present(gate.Boss) and not G.Walkable() and G.Sessions[1].Fight==nil,"Dormant holds no boss, walkway or fight")
check(not G.TakeRelic(1),"relic cannot be taken from the arena")
put(1,G.RelicPosition)
check(G.TakeRelic(1) and G.Lake.State=="Summoning" and G.Present(gate.Boss) and not G.Walkable(),"a nearby relic holder wakes a waiting Shen")
check(G.Spells[1].SutraOfMending==true and G.Refreshed[1]==1 and G.Spells[2]==nil,"lifting the beads teaches the holder the Sutra of Mending")
check(string.match(G.Phase(),"^Summoning:%d") and not G.TakeRelic(1),"summon time replicates with phase and duplicate takes fail")
put(1,gate.Outside);put(2,gate.Outside);G.Update()
now+=LakeRules.SummonSeconds;G.Update()
check(G.Lake.State=="Stilled" and G.Walkable() and G.Sessions[1].Fight==nil,"after the summon the water supports players without starting combat")
local submerged=vec(gate.Inside.X,gate.Inside.Y-12,gate.Inside.Z)
put(1,submerged);G.Update()
check(G.Sessions[1].Fight==nil,"entering below the waterline cannot start combat")
put(1,gate.Outside);G.Update()
put(1,gate.Inside);put(2,gate.Inside,-10);G.Update()
check(G.Sealed[gate.Id] and G.Sessions[1].Fight==gate.Id and G.Sessions[2].Fight==gate.Id,"the stilled lake seals as they walk in, allies included")
check(G.Lake.State=="Fight","the trial enters its fight")
check(actors[1].Model:GetAttribute("AsuraEncounter")=="GrandmasterShen","encounter identity replicates to participant")
actors[1].Root.Position=vec(gate.Inside.X+300,gate.Inside.Y,gate.Inside.Z);G.Update()
check(actors[1].Root.Position.X==gate.Inside.X,"participant cannot escape arena perimeter")
actors[1].Fighter.State="KO";G.Update()
check(G.Sealed[gate.Id] and G.Sessions[1].Fight==nil,"one death releases that player while co-op encounter stays sealed")
G.End(gate.Id,true)
check(not G.Sealed[gate.Id] and G.Lake.State=="Dormant","victory unlocks the arena and the lake sleeps")
check(not G.Walkable() and actors[2].Root.Position.X==gate.Outside.X,"victory returns survivors to the causeway before the water releases")
check(G.Awards[2]==1 and G.Awards[1]==nil and G.Drops()==1,"victory rewards living participants and disperses loot once")
check(actors[2].Model:GetAttribute("AsuraBosses")=="GrandmasterShen","victory mirrors boss flag immediately")
G.End(gate.Id,true)
check(G.Awards[2]==1 and G.Drops()==1,"duplicate defeat event cannot repeat loot")
G.Setup({1});put(1,G.RelicPosition);check(G.TakeRelic(1),"relic is available after the encounter");put(1,gate.Outside)
now+=LakeRules.SummonSeconds;G.Update();put(1,gate.Inside);G.Update()
actors[1].Fighter.State="KO";G.Update()
check(not G.Sealed[gate.Id] and G.Drops()==0 and G.Lake.State=="Stilled" and G.Present(gate.Boss),"party wipe reopens a stilled lake with Shen waiting")
G.Sessions[1]=nil;G.Update()
check(G.Lake.State=="Dormant" and not G.Present(gate.Boss) and not G.Walkable(),"the last summoner leaving resets a waiting lake")
G.Setup({1});put(1,G.RelicPosition);G.Sessions[1].Bosses[gate.Boss]=true
local ok,why=G.TakeRelic(1)
check(ok and why=="BeadsTaken" and G.Spells[1].SutraOfMending and G.Lake.State=="Dormant" and not G.Present(gate.Boss),"a Shen victor who never took the beads learns the Sutra and the lake stays asleep")
ok,why=G.TakeRelic(1)
check(not ok and why=="BossFelled" and G.Refreshed[1]==1,"a victor who already knows the Sutra is refused as before")
G.Setup({1});G.FailSpawn()
check(not G.Enter(1,gate) and actors[1].Root.Position.Z==gate.Outside.Z,"failed spawn returns entrant outside safely")
print("Boss fog coordinator: encounter and lake lifecycle passed")
''')
generated = ROOT / "work/test_boss_runtime.generated.luau"
generated.parent.mkdir(exist_ok=True)
generated.write_text("\n".join(chunks))
raise SystemExit(subprocess.run([str(ROOT / "work/bin/luau/luau"), str(generated)], cwd=ROOT).returncode)

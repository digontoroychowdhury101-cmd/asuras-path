--!strict
-- Server-owned pulses and swept projectiles; no client can select a victim or damage amount.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Spells=require(Shared.Simulation.SpellSchema)
local Rules=require(Shared.Simulation.SpellRules)
local Characters=require(script.Parent.CharacterService)
local Geometry=require(script.Parent.SpellGeometry)
local Effects={}
type Job={Source: any,Fighter: any,Duel: string?,Spell: any,Potency: number,Origin: Vector3,Direction: Vector3,Point: Vector3,At: number,Travel: number,Hits: {[number]: boolean}}
type Burn={Source: any,SourceFighter: any,Target: any,Fighter: any,Duel: string?,Stacks: number,At: number,Until: number}
local jobs: {Job}={}
local burns: {[string]: Burn}={}
local function valid(j: Job): boolean
 return Characters.GetActor(j.Source.Id)==j.Source and j.Source.Fighter==j.Fighter and j.Fighter.State~="KO" and j.Source.Duel==j.Duel and j.Source.Root.Parent~=nil
end
local function strike(j: Job,target: any,now: number)
 local s=j.Spell
 if not Characters.IsHostile(j.Source.Id,target.Id) or target.Duel~=j.Duel then return end
 if s.Speed>0 and Rules.projectileParry(target.Fighter,now) then
  local held=target.Fighter.State=="Blocking"
  Characters.ApplyArea(j.Source.Id,target.Id,0,0,false)
  Characters.Cue("ProjectileParry",target.Id,{position=target.Root.Position})
  if held then target.Fighter.Qi=math.min(100,target.Fighter.Qi+15) end
  return
 end
 local outcome=Characters.ApplyArea(j.Source.Id,target.Id,s.Damage*j.Potency,s.Posture*j.Potency,s.Status.IgnoreGuard)
 if outcome~="Hit" and outcome~="KO" and outcome~="GuardBroken" then return end
 Rules.status(target.Fighter,s.Id,now)
 target.Model:SetAttribute("RootUntil",target.Fighter.RootUntil)
 if s.Status.Burn>0 and outcome~="KO" then
  local key=j.Source.Id..":"..target.Id;local old=burns[key]
  burns[key]={Source=j.Source,SourceFighter=j.Fighter,Target=target,Fighter=target.Fighter,Duel=j.Duel,Stacks=math.min(5,(if old then old.Stacks else 0)+s.Status.Burn),At=now+1,Until=now+4}
 end
 Characters.Cue("SpellHit",j.Source.Id,{spell=s.Id,position=target.Root.Position,root=s.Status.Root})
end
local function pulse(j: Job,now: number)
 local s=j.Spell
 local origin=if s.Shape=="Pillars" or s.Shape=="Impact" then j.Point else j.Origin
 local range=if s.Shape=="Pillars" or s.Shape=="Impact" then s.Radius else s.Range
 for _,e in Geometry.targets(j.Source,origin,range) do
  local delta=e.Root.Position-origin
  local inside=s.Shape~="Cone" or delta.Magnitude<0.1 or delta.Unit:Dot(j.Direction)>=math.cos(math.rad(s.Arc/2))
  if inside then strike(j,e,now) end
 end
 Characters.Cue("SpellPulse",j.Source.Id,{spell=s.Id,position=origin,direction=j.Direction,range=range})
end
function Effects.release(source: any,id: string,potency: number,now: number)
 local s=Spells.get(id);if not s or not source.Root.Parent then return end
 local origin=source.Root.Position;local direction=source.Root.CFrame.LookVector
 local point=Geometry.endpoint(origin,direction,s.Range)
 if s.Shape=="Self" then
  if s.Status.Ward then Rules.ward(source.Fighter,now);source.Model:SetAttribute("JadeAegisUntil",now+30) end
  if s.Status.Teleport then
   Geometry.teleport(source,point)
   if s.Status.Decoy then source.Model:SetAttribute("PhantomPosition",origin);source.Model:SetAttribute("PhantomUntil",now+2) end
  end
 end
 local targets=if s.Shape=="Pillars" then Geometry.targets(source,origin,s.Range) else {}
 for n=1,s.Pulses do
  local target=targets[((n-1)%math.max(1,#targets))+1]
  local impact=if target then target.Root.Position else point
  if s.Shape~="Self" then
   table.insert(jobs,{Source=source,Fighter=source.Fighter,Duel=source.Duel,Spell=s,Potency=potency,Origin=origin,Direction=direction,
    Point=if s.Shape=="Pillars" then impact else point,At=now+(if s.Shape=="Pillars" then n else n-1)*s.Delay,Travel=0,Hits={}})
  end
 end
 Characters.Cue("SpellRelease",source.Id,{spell=id,position=origin,destination=point,direction=direction,travel=if s.Speed>0 then (point-origin).Magnitude/s.Speed else 0})
end
function Effects.step(now: number,dt: number)
 for index=#jobs,1,-1 do
  local j=jobs[index];local s=j.Spell;local remove=not valid(j)
  if not remove and now>=j.At then
   if s.Speed>0 or s.Shape=="Line" then
    local distance=(j.Point-j.Origin).Magnitude
    local previous=j.Origin+j.Direction*j.Travel
    j.Travel=math.min(distance,j.Travel+(if s.Speed>0 then s.Speed*dt else distance))
    local current=j.Origin+j.Direction*j.Travel
    do
     local hitTargets=Geometry.targets(j.Source,(previous+current)/2,(current-previous).Magnitude/2+s.Radius+3)
     table.sort(hitTargets,function(a: any,b: any): boolean return (a.Root.Position-previous).Magnitude<(b.Root.Position-previous).Magnitude end)
     for _,e in hitTargets do
      if not j.Hits[e.Id] and Geometry.segment(e.Root.Position,previous,current)<=s.Radius+1.5 then
       j.Hits[e.Id]=true
       if s.Shape=="Impact" then
        j.Point=e.Root.Position;Geometry.teleport(j.Source,j.Point);pulse(j,now);remove=true;break
       else strike(j,e,now) end
       if not s.Pierces then remove=true;break end
      end
     end
    end
    if not remove and j.Travel>=distance then
     if s.Shape=="Impact" then Geometry.teleport(j.Source,j.Point);pulse(j,now) end
     remove=true
    end
   else pulse(j,now);remove=true end
  end
  if remove then table.remove(jobs,index) end
 end
 for key,b in burns do
  if now>b.Until or Characters.GetActor(b.Source.Id)~=b.Source or Characters.GetActor(b.Target.Id)~=b.Target or b.Target.Fighter~=b.Fighter
   or b.Source.Fighter~=b.SourceFighter or b.Source.Fighter.State=="KO" or b.Fighter.State=="KO" or b.Source.Duel~=b.Duel or b.Target.Duel~=b.Duel then burns[key]=nil
  elseif now>=b.At then b.At=now+1;Characters.ApplyArea(b.Source.Id,b.Target.Id,b.Stacks*2,0,true) end
 end
end
function Effects.clear()
 table.clear(jobs);table.clear(burns)
end
return Effects

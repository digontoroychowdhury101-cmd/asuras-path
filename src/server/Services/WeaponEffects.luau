--!strict
local Debris=game:GetService("Debris")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Combat=require(Shared.Simulation.CombatRules)
local Characters=require(script.Parent.CharacterService)
local Magic=require(script.Parent.MagicService)
local Geometry=require(script.Parent.SpellGeometry)
local Effects={}
local seen: {[number]: number}={}
local telegraphs: {[number]: number}={}
local disconnect: (() -> ())?=nil
local removed: (() -> ())?=nil
local function pull(e: any,point: Vector3)
 local delta=point-e.Root.Position;if delta.Magnitude<0.1 then return end
 local endpoint=Geometry.endpoint(e.Root.Position,delta.Unit,delta.Magnitude)
 local attachment=Instance.new("Attachment");attachment.Parent=e.Root
 local velocity=Instance.new("LinearVelocity");velocity.Attachment0=attachment;velocity.RelativeTo=Enum.ActuatorRelativeTo.World
 velocity.VectorVelocity=(endpoint-e.Root.Position)/0.18;velocity.MaxForce=math.max(50000,e.Root.AssemblyMass*6000);velocity.Parent=e.Root
 Debris:AddItem(velocity,0.18);Debris:AddItem(attachment,0.2)
 local root=e.Root
 task.delay(0.18,function()
  if root.Parent and e.Root==root then local v=root.AssemblyLinearVelocity;root.AssemblyLinearVelocity=Vector3.new(0,v.Y,0) end
 end)
end
function Effects.Start()
 assert(not disconnect,"WeaponEffects already started")
 removed=Characters.OnEntityRemoved(function(id: number) seen[id]=nil;telegraphs[id]=nil end)
 disconnect=Characters.OnStep(function(now: number,_dt: number)
  for id,e in Characters.Entities() do
   local f=e.Fighter;local move=f.Move
   if move and move.Effect and f.State=="Startup" and telegraphs[id]~=f.MoveStart then
    telegraphs[id]=f.MoveStart
    Characters.Cue("SpellStartup",id,{spell=move.Effect,release=f.MoveStart+move.Timing.StartupSeconds,finish=f.MoveStart+move.Timing.TotalSeconds,position=e.Root.Position})
    if move.Effect=="FissureSlam" then e.Root.AssemblyLinearVelocity+=Vector3.new(0,24,0) end
   end
   if not move or f.State~="Active" or not move.Effect or seen[id]==f.MoveStart then continue end
   seen[id]=f.MoveStart
   if move.Effect=="Pull" or move.Effect=="Launch" then
    for _,target in Geometry.targets(e,e.Root.Position,move.Reach+f.ReachBonus) do
     local delta=target.Root.Position-e.Root.Position
     if delta.Magnitude>0.1 and delta.Unit:Dot(e.Root.CFrame.LookVector)>0.5 and not Combat.isInvulnerable(target.Fighter,now) then
      local outcome=Characters.ResolveWeaponHit(e.Id,target.Id)
      if outcome~="Hit" and outcome~="CounterHit" and outcome~="Armored" then break end
      if move.Effect=="Pull" and not target.Boss then
       pull(target,e.Root.Position+e.Root.CFrame.LookVector*4)
      elseif move.Effect=="Pull" then
       pull(e,target.Root.Position-delta.Unit*4)
      else target.Root.AssemblyLinearVelocity+=Vector3.new(0,40,0) end
      break
     end
    end
   else
    Magic.ReleaseArt(e,move.Effect,now)
   end
  end
 end)
end
function Effects.Destroy()
 if disconnect then disconnect();disconnect=nil end
 if removed then removed();removed=nil end
 table.clear(seen);table.clear(telegraphs)
end
return Effects

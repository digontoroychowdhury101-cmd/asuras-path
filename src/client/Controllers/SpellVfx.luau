--!strict
local Debris=game:GetService("Debris")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local simFolder=Shared:WaitForChild("Simulation")
local Spells=require(simFolder:WaitForChild("SpellSchema") :: ModuleScript)
local Assets=require(Shared.Shared.PresentationAssets)
local Qi=require(script.Parent.QiVfx)
local Vfx={}
local colors: {[string]: Color3}={CelestialThunder=Color3.fromRGB(112,210,255),CrimsonFlame=Color3.fromRGB(255,91,42),AbyssalVoid=Color3.fromRGB(113,66,172),SpiritTalismans=Color3.fromRGB(91,236,194)}
local casting: {[number]: {Instance}}={}
local live: {[Instance]: boolean}={}
local function part(name: string,position: Vector3,color: Color3,lifetime: number): Part
 local p=Instance.new("Part");p.Name=name;p.Size=Vector3.one*0.2;p.Position=position;p.Color=color;p.Material=Enum.Material.Neon
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=Workspace
 live[p]=true;p.Destroying:Once(function() live[p]=nil end);Debris:AddItem(p,lifetime);return p
end
local function ring(position: Vector3,color: Color3,radius: number,duration: number): Part
 local p=part("QiCastRing",position,color,duration+0.1);p.Shape=Enum.PartType.Cylinder
 p.Size=Vector3.new(0.08,1,1);p.CFrame=CFrame.new(position)*CFrame.Angles(0,0,math.pi/2);p.Transparency=0.35
 TweenService:Create(p,TweenInfo.new(duration),{Size=Vector3.new(0.04,radius*2,radius*2),Transparency=1}):Play()
 return p
end
local function beam(a: Vector3,b: Vector3,color: Color3,duration: number,thunder: boolean)
 local first=part("QiBeamOrigin",a,color,duration+0.3);first.Transparency=1
 local last=part("QiBeamHead",a,color,duration+0.3)
 Qi.tail(last,color)
 local aa=Instance.new("Attachment");aa.Parent=first;local ab=Instance.new("Attachment");ab.Parent=last
 local v=Instance.new("Beam");v.Attachment0=aa;v.Attachment1=ab;v.Color=ColorSequence.new(color);v.Width0=0.35;v.Width1=0.65
 v.FaceCamera=true;v.LightEmission=1;v.Parent=first
 if thunder then v.Texture=Assets.Textures.GithubThunderHorizontal;v.TextureMode=Enum.TextureMode.Stretch;v.TextureSpeed=0 end
 TweenService:Create(last,TweenInfo.new(math.max(0.05,duration),Enum.EasingStyle.Linear),{Position=b}):Play()
end
function Vfx.cancel(id: number)
 local items: {Instance}=casting[id] or {}
 for _,p in items do p:Destroy() end;casting[id]=nil
end
function Vfx.cue(cue: any,state: any)
 local own=state:Own()
 local d=cue.Data
 if own and own.Root and typeof(d.position)=="Vector3" and (own.Root.Position-d.position).Magnitude>100 then return end
 local s=if type(d.spell)=="string" then Spells.get(d.spell) else nil
 local color=if s then colors[s.Discipline] else colors.SpiritTalismans
 if cue.Kind=="SpellInterrupted" then Vfx.cancel(cue.Source);return end
 if typeof(d.position)~="Vector3" then return end
 if cue.Kind=="SpellStartup" then
  Vfx.cancel(cue.Source)
  local duration=math.max(0.1,(d.release or cue.Time+0.3)-cue.Time)
  local p=ring(d.position-Vector3.new(0,2.6,0),color,4,duration)
  casting[cue.Source]={p}
  local e=state:Get(cue.Source);local hand=if e then e.Model:FindFirstChild("RightHand") else nil
  if hand and hand:IsA("BasePart") then
   local seal=Qi.seal(hand,color,duration);if seal then table.insert(casting[cue.Source],seal) end
   local glow=Instance.new("Highlight");glow.Adornee=hand;glow.FillColor=color;glow.FillTransparency=0.2;glow.OutlineTransparency=1;glow.Parent=p
   local light=Instance.new("PointLight");light.Color=color;light.Range=10;light.Brightness=2;light.Parent=hand
   Debris:AddItem(light,duration);table.insert(casting[cue.Source],light)
  end
 elseif cue.Kind=="SpellRelease" then
  Vfx.cancel(cue.Source);ring(d.position,color,5,0.45)
  if s and (s.Shape=="Line" or s.Shape=="Impact") and typeof(d.destination)=="Vector3" then beam(d.position,d.destination,color,d.travel or 0.2,s.Discipline=="CelestialThunder") end
  if s and s.Status.Decoy then
   local e=state:Get(cue.Source)
   if e then
    local clone=Instance.new("Model");clone.Name="GalePhantom";clone.Parent=Workspace;live[clone]=true
    clone.Destroying:Once(function() live[clone]=nil end);Debris:AddItem(clone,2)
    local root=e.Root
    for _,limb in e.Model:GetChildren() do
     if limb:IsA("BasePart") and limb.Name~="HumanoidRootPart" and root then
      local ghost=part("Phantom",limb.Position,color,2);ghost.Size=limb.Size;ghost.CFrame=CFrame.new(d.position)*root.CFrame:ToObjectSpace(limb.CFrame)
      ghost.Transparency=0.65;ghost.Parent=clone;TweenService:Create(ghost,TweenInfo.new(2),{Transparency=1}):Play()
     end
    end
   end
  end
  if s and s.Status.Ward then
   local e=state:Get(cue.Source)
   if e then
    local ward=part("JadeAegisTalisman",d.position,color,30);ward.Size=Vector3.new(1,1.6,0.15)
    task.spawn(function()
     while ward.Parent and e.Root and e.Root.Parent and (e.Model:GetAttribute("JadeAegisUntil") or 0)>Workspace:GetServerTimeNow() do
      ward.CFrame=e.Root.CFrame*CFrame.new(1.7,1.2,0)*CFrame.Angles(0,0,math.rad(15));task.wait(0.05)
     end
     ward:Destroy()
    end)
   end
  end
 elseif cue.Kind=="SpellPulse" then
  if d.spell=="FissureSlam" then
   local e=state:Get(cue.Source);local p=part("FissureAnchor",d.position,color,1.6);p.Transparency=1
   Qi.rupture(p,d.position,if e and e.Root then e.Root.CFrame.LookVector else Vector3.zAxis,color,if e then e.Model else nil)
  end
  ring(d.position-Vector3.new(0,2.4,0),color,math.min(d.range or 5,20),0.65)
  if s and s.Id=="GraveTendrils" then
   for n=1,5 do
    local angle=n*math.pi*2/5;local spike=part("GraveClaw",d.position+Vector3.new(math.cos(angle)*2,-1,math.sin(angle)*2),color,2)
    spike.Size=Vector3.new(0.35,5,0.35);spike.CFrame=CFrame.new(spike.Position)*CFrame.Angles(math.sin(angle)*0.3,0,-math.cos(angle)*0.3)
    TweenService:Create(spike,TweenInfo.new(0.25),{Position=spike.Position+Vector3.new(0,2,0)}):Play()
   end
  elseif s and s.Shape=="Pillars" then
   local column=part("SorceryPillar",d.position,color,0.6);column.Size=Vector3.new(s.Radius,12,s.Radius)
   TweenService:Create(column,TweenInfo.new(0.55),{Transparency=1}):Play()
  end
 elseif cue.Kind=="SpellHit" or cue.Kind=="ProjectileParry" then ring(d.position,color,3,0.3) end
end
function Vfx.destroy()
 for id in casting do Vfx.cancel(id) end
 for p in live do p:Destroy() end;table.clear(live)
end
return table.freeze(Vfx)

--!strict
-- Authoritative events drive presentation; damage and timing stay on the server.
local Players = game:GetService("Players")
local Audio = require(script.Parent.SpatialAudio)
local Vfx = require(script.Parent.CombatVfx)
local Feedback = require(script.Parent.CombatFeedback)
local Trails = require(script.Parent.WeaponTrails)
local Controller = {}
Controller.__index = Controller
export type GameFeel = any
function Controller.new(state: any, camera: any): GameFeel
 local folder = Instance.new("Folder"); folder.Name, folder.Parent = "AsuraFeel", workspace
 local self = setmetatable({State=state, Camera=camera, Folder=folder, Vfx=Vfx.new(folder),
  Feedback=Feedback.new(state,camera), Trails=Trails.new(state), Disconnects={}}, Controller)
 table.insert(self.Disconnects,state:OnEvent(function(event: any) self:OnEvent(event) end))
 table.insert(self.Disconnects,state:OnCue(function(cue: any) self:OnCue(cue) end))
 return self
end
function Controller.OnEvent(self: GameFeel, event: any)
 local source,target,own = self.State:Get(event.Source),self.State:Get(event.Target),self.State:Own()
 local point = event.Point or (if target and target.Root then target.Root.Position else nil)
 if not point or not own or not own.Root or (point-own.Root.Position).Magnitude>70 then return end
 local direction = if source and source.Root and target and target.Root then target.Root.Position-source.Root.Position else Vector3.yAxis
 if direction.Magnitude>0.1 then direction=direction.Unit end
 local kind=event.Kind
 if kind=="DeflectSpark" then
  self.Vfx:burst(point,direction+Vector3.yAxis*0.5,Color3.fromRGB(255,173,65),math.random(25,40),55)
  self.Vfx:ring(point,direction,Color3.fromRGB(255,200,105),4)
  Audio.at("Clash",point,0.85); Audio.at("ParryBass",point,0.65)
 elseif kind=="Block" or kind=="GuardBreak" or kind=="StanceBreak" then
  self.Vfx:burst(point,-direction,Color3.fromRGB(247,196,127),if kind=="Block" then 12 else 30,34)
  Audio.at("Clash",point,if kind=="Block" then 0.5 else 0.9)
 elseif kind=="Hit" or kind=="CounterHit" or kind=="Armored" or kind=="BleedProc" or kind=="Deathblow" then
  local weapon=if source and source.Snapshot then source.Snapshot.Weapon else ""
  local stone=weapon=="CalamityBoneCleaver" or (source and source.Model:FindFirstChild("ColossalWarhammer",true)~=nil)
  if stone or weapon=="Unarmed" or kind=="Armored" then
   self.Vfx:burst(point,direction,Color3.fromRGB(192,173,142),22,26)
   Audio.at(if stone then "Stone" elseif kind=="Armored" then "Clash" else "Blunt",point,0.75)
  else
   local excludes: {Instance}={}
   if source then table.insert(excludes,source.Model) end
   if target then table.insert(excludes,target.Model) end
   self.Vfx:blood(point,direction,excludes); Audio.at("Flesh",point,0.7)
  end
 end
 self.Feedback:Event(event,direction)
end
function Controller.OnCue(self: GameFeel, cue: any)
 local own=self.State:Own()
 if not own or not own.Root then return end
 if cue.Kind=="Shockwave" then
  local d=cue.Data; local at=Vector3.new(tonumber(d.x) or 0,tonumber(d.y) or 0,tonumber(d.z) or 0)
  local radius=tonumber(d.radius) or 16
  local strength=math.clamp(1.2-(own.Root.Position-at).Magnitude/(radius*2.5),0,1)
  if strength<=0 then return end
  self.Camera:Impulse(own.Root.Position-at,strength,4*strength)
  self.Vfx:ring(at,Vector3.yAxis,Color3.fromRGB(237,93,44),math.min(radius,24))
  self.Vfx:rupture(at,own.Root.Position-at); Audio.at("Stone",at,0.9)
 elseif cue.Kind=="BossPhase" and Players.LocalPlayer:GetAttribute("AsuraEncounter")==cue.Data.boss then
  self.Camera:Impulse(Vector3.yAxis,0.7,-5)
 end
end
function Controller.Update(self: GameFeel,dt: number)
 self.Feedback:Update(dt); self.Vfx:Update(dt); self.Trails:Update(dt)
end
function Controller.Destroy(self: GameFeel)
 for _,disconnect in self.Disconnects do disconnect() end
 self.Feedback:Destroy();self.Trails:Destroy();self.Vfx:Destroy();self.Folder:Destroy()
end
return Controller

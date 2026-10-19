--!strict
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Kit=require(script.Parent.HudKit)
local Effects={}
function Effects.new(state: any,camera: any): any
 local disconnect=state:OnCue(function(cue: any)
  if cue.Kind~="SignatureFinisher" then return end
  local d=cue.Data;local actor=state:Get(cue.Source)
  local own=state:Own();local point=d.position
  if typeof(point)~="Vector3" then return end
  if own and own.Root and (own.Root.Position-point).Magnitude>140 then return end
  if own and actor==own then camera:BossShot(d.target,1.1,true) end
  local sound=Instance.new("Sound");sound.Name="SignatureStanceClash"
  sound.SoundId="rbxasset://sounds/impact_explosion_03.mp3";sound.PlaybackSpeed=0.65;sound.Volume=0.65
  sound.Parent=workspace.CurrentCamera;sound:Play();Debris:AddItem(sound,3)
  Kit.cue(Kit.Sounds.Objective,0.25,0.5)
  for n=1,24 do
   local angle=n*math.pi*2/24
   local p=Instance.new("Part");p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
   p.Material=Enum.Material.Neon;p.Color=Kit.Palette.Gold;p.Size=Vector3.new(0.5,0.15,1.5)
   p.CFrame=CFrame.new(point)*CFrame.Angles(0,-angle,0);p.Parent=workspace.CurrentCamera
   Tween:Create(p,TweenInfo.new(0.6),{Position=point+Vector3.new(math.cos(angle)*17,0,math.sin(angle)*17),Transparency=1}):Play()
   Debris:AddItem(p,0.7)
  end
 end)
 return {Destroy=function() disconnect() end}
end
return table.freeze(Effects)

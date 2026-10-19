--!strict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Weapons=require(Shared.Simulation.WeaponSchema)
local Models={}
local STEEL=Color3.fromRGB(164,176,178)
local JADE=Color3.fromRGB(81,221,205)
local function piece(parent: Instance,hand: BasePart,name: string,size: Vector3,offset: CFrame,color: Color3,shape: Enum.PartType?): Part
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=hand.CFrame*offset;p.Color=color;p.Material=Enum.Material.Metal
 p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 if shape then p.Shape=shape end
 local weld=Instance.new("WeldConstraint");weld.Part0=hand;weld.Part1=p;weld.Parent=p;p.Parent=parent
 return p
end
function Models.attach(model: Model,id: string): boolean
 local old=model:FindFirstChild("ArsenalWeapon");if old then old:Destroy() end
 local w=Weapons.Weapons[id]
 if not w or table.find({"Unarmed","Jian","Dao","Guandao"},id) then return false end
 local hand=model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
 if not hand or not hand:IsA("BasePart") then return true end
 local folder=Instance.new("Folder");folder.Name="ArsenalWeapon";folder.Parent=model
 if id=="PrayerOfTheDefiled" then
  piece(folder,hand,"BronzeCenser",Vector3.new(1.8,1.8,1.8),CFrame.new(0,-3.3,-0.6),Color3.fromRGB(105,82,44),Enum.PartType.Ball)
  for n=1,6 do piece(folder,hand,"ChainLink",Vector3.new(0.15,0.35,0.15),CFrame.new(0,-n*0.45,-0.6),STEEL) end
 elseif w.Type=="TwinDaggers" then
  for _,name in {"RightHand","LeftHand"} do
   local limb=model:FindFirstChild(name);if limb and limb:IsA("BasePart") then
    piece(folder,limb,"ShadowSai",Vector3.new(0.12,0.2,2.3),CFrame.new(0,-0.1,-1.1),STEEL)
    piece(folder,limb,"SaiGuard",Vector3.new(1,0.15,0.15),CFrame.new(0,-0.1,-0.5),STEEL)
   end
  end
 elseif w.Type=="WarFan" then
  for n=-3,3 do piece(folder,hand,"FanRib",Vector3.new(0.16,0.14,2.4),CFrame.Angles(0,math.rad(n*14),0)*CFrame.new(0,0,-1.2),STEEL) end
 elseif w.Type=="Catalyst" then
  piece(folder,hand,"JadeStaff",Vector3.new(0.25,5,0.25),CFrame.new(0,-0.3,-0.5),Color3.fromRGB(75,63,47))
  local gem=piece(folder,hand,"FocusJade",Vector3.new(0.8,0.8,0.8),CFrame.new(0,2.4,-0.5),JADE,Enum.PartType.Ball);gem.Material=Enum.Material.Neon
 elseif w.Type=="ChainScythe" then
  piece(folder,hand,"SickleBlade",Vector3.new(2,0.18,0.4),CFrame.new(0.9,0,-1.8),STEEL)
  piece(folder,hand,"SickleGrip",Vector3.new(0.2,0.2,2),CFrame.new(0,0,-0.8),STEEL)
  for n=1,8 do piece(folder,hand,"WeightedChain",Vector3.new(0.14,0.35,0.14),CFrame.new(0,-n*0.4,0),STEEL) end
 else
  local bone=id=="CalamityBoneCleaver";local guandao=w.Type=="Guandao"
  piece(folder,hand,"GreatBlade",Vector3.new(0.25,if guandao then 0.6 else 1.2,if guandao then 7 else 6),CFrame.new(0,0,-3),if bone then Color3.fromRGB(194,175,138) else STEEL)
  piece(folder,hand,"CrossGuard",Vector3.new(0.3,2,0.2),CFrame.new(0,0,-0.7),Color3.fromRGB(125,98,45))
  if guandao then local edge=piece(folder,hand,"LightningEdge",Vector3.new(0.3,0.7,2),CFrame.new(0,0,-6),JADE);edge.Material=Enum.Material.Neon end
 end
 return true
end
return table.freeze(Models)

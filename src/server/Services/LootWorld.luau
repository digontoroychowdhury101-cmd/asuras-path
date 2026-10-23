--!strict
local Workspace=game:GetService("Workspace")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Catalog=require(Shared.Shared.ArsenalCatalog)
local World=require(Shared.Shared.WorldDefinitions)
local InputMap=require(Shared.Shared.InputMap)
local LootWorld={}
local function part(parent: Instance,name: string,size: Vector3,position: Vector3): Part
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Anchored=true
 p.Material=Enum.Material.Slate;p.Color=Color3.fromRGB(54,60,58);p.Parent=parent
 return p
end
function LootWorld.build(claim: (Player,string)->(),openSmith: (Player)->()): (Folder,{RBXScriptConnection})
 local root=Instance.new("Folder");root.Name="WorldDiscoveryCaches";root.Parent=Workspace
 local connections: {RBXScriptConnection}={}
 for id,c in Catalog.Caches do
  local position=Vector3.new(c.X,c.Y,c.Z)
  part(root,id.."Ledge",Vector3.new(8,1,8),position-Vector3.new(0,1.5,0))
  local chest=part(root,id,Vector3.new(3,1.8,2),position)
  chest.Material=Enum.Material.Metal;chest.Color=Color3.fromRGB(111,93,49)
  chest:SetAttribute("CacheId",id)
  local prompt=Instance.new("ProximityPrompt");prompt.ActionText="Open Hidden Cache";prompt.ObjectText=c.Name
  prompt.HoldDuration=0.6;prompt.MaxActivationDistance=9;InputMap.applyPrompt(prompt)
  prompt.RequiresLineOfSight=true;prompt.Parent=chest
  table.insert(connections,prompt.Triggered:Connect(function(player: Player) claim(player,id) end))
  if id=="WaterfallAlcove" then
   local water=part(root,"SecretWaterfall",Vector3.new(12,25,0.5),position+Vector3.new(0,9,5))
   water.CanCollide=false;water.CanQuery=false;water.Transparency=0.65;water.Material=Enum.Material.Glass;water.Color=Color3.fromRGB(89,168,177)
   for _,side in {-1,1} do part(root,"AlcoveRock",Vector3.new(4,12,12),position+Vector3.new(side*6,3,0)) end
  elseif id=="PagodaRafters" or id=="SanctuaryEaves" then
   -- The ladder stands flush outside the ledge's south edge and ends at its top (batch 15, #44):
   -- it used to rise inside the 8x8 ledge, so a climber met the ledge's underside.
   local ground=if c.Region=="Sanctuary" then 600 else 0.2
   local floor=c.Y-1;local ladder=Instance.new("TrussPart");ladder.Name="HiddenRafterLadder";ladder.Size=Vector3.new(2,floor-ground,2)
   ladder.Position=Vector3.new(c.X,ground+(floor-ground)/2,c.Z-5);ladder.Anchored=true;ladder.Parent=root
   part(root,"RafterBeam",Vector3.new(14,0.8,1.5),position-Vector3.new(0,1.5,0))
  elseif id=="SealedMausoleum" then
   for _,side in {-1,1} do part(root,"MausoleumWall",Vector3.new(1,8,9),position+Vector3.new(side*5,2,0)) end
   part(root,"MausoleumRoof",Vector3.new(12,1,11),position+Vector3.new(0,6,0))
  end
 end
 -- Shrine caches (eaves deck, ladder, rafter, reliquary ledge) wear the lobby kit's timber.
 for _,d in root:GetDescendants() do
  if d:IsA("BasePart") and d.Material~=Enum.Material.Metal and d.Material~=Enum.Material.Neon and World.regionAt(d.Position.X,d.Position.Y,d.Position.Z)=="Sanctuary" then
   d.Material=Enum.Material.Wood;d.MaterialVariant="AsuraTimber";d.Color=Color3.fromRGB(255,255,255)
  end
 end
 local l=World.Sanctuary.Loggia
 local smith=part(root,"TransmutationSeal",Vector3.new(2,2,2),Vector3.new(l.X+5,l.Y+3,l.Z))
 -- Keep the original prompt/collision anchor, housed inside a carved smith's seal.
 smith.Material=Enum.Material.Slate;smith.MaterialVariant="AsuraStone";smith.Color=Color3.fromRGB(126,141,158)
 local styled,kit=pcall(function() return require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript) end)
 if styled then
  local base=CFrame.new(l.X+5,l.Y+1,l.Z)*CFrame.Angles(0,math.rad(90),0)
  local seal=kit.place(root,"Stele_Dragon",base,Vector3.new(0.55,0.5,0.55))
  if seal then smith.Transparency=1 end
  kit.slab(root,"SmithSealPlinth",Vector3.new(2.55,1,2.55),CFrame.new(l.X+5,l.Y+0.5,l.Z),"StoneDark",kit.decor())
 end
 local prompt=Instance.new("ProximityPrompt");prompt.Name="TransmutePrompt";prompt.ActionText="Transmute Remembrance"
 prompt.ObjectText="Master Smith Gao";InputMap.applyPrompt(prompt)
 prompt.MaxActivationDistance=12;prompt.HoldDuration=0.4;prompt.Parent=smith
 table.insert(connections,prompt.Triggered:Connect(openSmith))
 return root,connections
end
return table.freeze(LootWorld)

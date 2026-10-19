--!strict
local Workspace=game:GetService("Workspace")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Catalog=require(Shared.Shared.ArsenalCatalog)
local World=require(Shared.Shared.WorldDefinitions)
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
  prompt.HoldDuration=0.6;prompt.MaxActivationDistance=9;prompt.KeyboardKeyCode=Enum.KeyCode.Z;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
  prompt.RequiresLineOfSight=true;prompt.Parent=chest
  table.insert(connections,prompt.Triggered:Connect(function(player: Player) claim(player,id) end))
  if id=="WaterfallAlcove" then
   local water=part(root,"SecretWaterfall",Vector3.new(12,25,0.5),position+Vector3.new(0,9,5))
   water.CanCollide=false;water.CanQuery=false;water.Transparency=0.65;water.Material=Enum.Material.Glass;water.Color=Color3.fromRGB(89,168,177)
   for _,side in {-1,1} do part(root,"AlcoveRock",Vector3.new(4,12,12),position+Vector3.new(side*6,3,0)) end
  elseif id=="PagodaRafters" or id=="SanctuaryEaves" then
   local ground=if c.Region=="Sanctuary" then 600 else 0
   local ladder=Instance.new("TrussPart");ladder.Name="HiddenRafterLadder";ladder.Size=Vector3.new(2,c.Y-ground,2)
   ladder.Position=Vector3.new(c.X+3,ground+(c.Y-ground)/2,c.Z+3);ladder.Anchored=true;ladder.Parent=root
   part(root,"RafterBeam",Vector3.new(14,0.8,1.5),position-Vector3.new(0,1.5,0))
  elseif id=="SealedMausoleum" then
   for _,side in {-1,1} do part(root,"MausoleumWall",Vector3.new(1,8,9),position+Vector3.new(side*5,2,0)) end
   part(root,"MausoleumRoof",Vector3.new(12,1,11),position+Vector3.new(0,6,0))
  end
 end
 local l=World.Sanctuary.Loggia
 local smith=part(root,"TransmutationSeal",Vector3.new(2,2,2),Vector3.new(l.X+5,l.Y+3,l.Z))
 smith.Material=Enum.Material.Neon;smith.Color=Color3.fromRGB(97,218,207)
 local prompt=Instance.new("ProximityPrompt");prompt.Name="TransmutePrompt";prompt.ActionText="Transmute Remembrance"
 prompt.ObjectText="Master Smith Gao";prompt.KeyboardKeyCode=Enum.KeyCode.N;prompt.GamepadKeyCode=Enum.KeyCode.ButtonY
 prompt.MaxActivationDistance=12;prompt.HoldDuration=0.4;prompt.Parent=smith
 table.insert(connections,prompt.Triggered:Connect(openSmith))
 return root,connections
end
return table.freeze(LootWorld)

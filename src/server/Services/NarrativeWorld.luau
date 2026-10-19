--!strict
local World=game:GetService("Workspace")
local Shared=game:GetService("ReplicatedStorage").AsurasPath.Shared
local Catalog=require(Shared.NarrativeCatalog)
local Kit={}
local function part(parent: Instance,name: string,size: Vector3,cf: CFrame,color: Color3): Part
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Anchored=true;p.Color=color;p.Material=Enum.Material.Slate;p.Parent=parent;return p
end
local function prompt(parent: BasePart,label: string,name: string,run: (Player)->(),links: {RBXScriptConnection})
 local p=Instance.new("ProximityPrompt");p.Name="NarrativePrompt";p.ActionText=label;p.ObjectText=name;p.HoldDuration=0.25
 p.KeyboardKeyCode=Enum.KeyCode.Z;p.GamepadKeyCode=Enum.KeyCode.ButtonX;p.MaxActivationDistance=12;p.RequiresLineOfSight=true;p.Parent=parent
 table.insert(links,p.Triggered:Connect(run))
end
function Kit.build(open: (Player,string)->(),lore: (Player,string)->()): (Folder,{RBXScriptConnection})
 local root=Instance.new("Folder");root.Name="JadeCataclysm";root.Parent=World
 local links: {RBXScriptConnection}={}
 for id,n in Catalog.NPCs do
  if id=="Gao" then continue end
  local model=Instance.new("Model");model.Name=id;model:SetAttribute("DialogueNPC",id);model.Parent=root
  local cf=CFrame.new(n.X,n.Y,n.Z);local color=Color3.fromRGB(n.Color[1],n.Color[2],n.Color[3])
  local torso=part(model,"Robe",Vector3.new(2.4,3.6,1.3),cf,color);model.PrimaryPart=torso
  local head=part(model,"Head",Vector3.new(1.2,1.2,1.2),cf*CFrame.new(0,2.3,0),Color3.fromRGB(172,153,126));head.Shape=Enum.PartType.Ball
  for _,side in {-1,1} do part(model,"Sleeve",Vector3.new(0.8,2.8,1.2),cf*CFrame.new(side*1.5,0.2,0),color) end
  if id=="Gao" then part(model,"Blindfold",Vector3.new(1.3,0.25,1.25),cf*CFrame.new(0,2.4,0),Color3.fromRGB(24,19,18)) end
  local label=Instance.new("BillboardGui");label.Size=UDim2.fromOffset(220,36);label.StudsOffset=Vector3.new(0,4,0);label.MaxDistance=36;label.Parent=head
  local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.Font=Enum.Font.Antique;text.Text=n.Name
  text.TextColor3=Color3.fromRGB(224,202,153);text.TextSize=15;text.Parent=label
  prompt(torso,"Speak",n.Name,function(player: Player) open(player,id) end,links)
 end
 for id,l in Catalog.Lore do
  local cf=CFrame.new(l.X,l.Y,l.Z)
  part(root,id.."Pedestal",Vector3.new(4.5,1,3),cf*CFrame.new(0,-2.5,0),Color3.fromRGB(43,45,41))
  local stone=part(root,id,Vector3.new(2.6,5,0.8),cf,Color3.fromRGB(38,49,47));stone:SetAttribute("LoreId",id)
  local rune=part(stone,"JadeInscription",Vector3.new(0.12,3,0.08),cf*CFrame.new(0,0,-0.45),Color3.fromRGB(113,207,172));rune.Material=Enum.Material.Neon;rune.CanCollide=false
  local light=Instance.new("PointLight");light.Color=rune.Color;light.Range=9;light.Brightness=0.6;light.Parent=rune
  prompt(stone,"Read Memorial",l.Title,function(player: Player) lore(player,id) end,links)
 end
 return root,links
end
return table.freeze(Kit)

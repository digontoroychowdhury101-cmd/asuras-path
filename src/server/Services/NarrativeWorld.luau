--!strict
local World=game:GetService("Workspace")
local Shared=game:GetService("ReplicatedStorage").AsurasPath.Shared
local Catalog=require(Shared.NarrativeCatalog)
local InputMap=require(Shared.InputMap)
local Figures=require(script.Parent.CastFigures)
local Kit={}
local function part(parent: Instance,name: string,size: Vector3,cf: CFrame,color: Color3): Part
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Anchored=true;p.Color=color;p.Material=Enum.Material.Slate;p.Parent=parent;return p
end
local function prompt(parent: BasePart,label: string,name: string,run: (Player)->(),links: {RBXScriptConnection})
 local p=Instance.new("ProximityPrompt");p.Name="NarrativePrompt";p.ActionText=label;p.ObjectText=name;p.HoldDuration=0.25
 InputMap.applyPrompt(p);p.MaxActivationDistance=12;p.RequiresLineOfSight=true;p.Parent=parent
 table.insert(links,p.Triggered:Connect(run))
end
function Kit.build(open: (Player,string)->(),lore: (Player,string)->()): (Folder,{RBXScriptConnection})
 local root=Instance.new("Folder");root.Name="JadeCataclysm";root.Parent=World
 local links: {RBXScriptConnection}={}
 for id,n in Catalog.NPCs do
  if id=="Gao" then continue end -- the smith is a live rig dressed by SanctuaryService
  -- Authored figure (LooksCast) where the robe block stood: feet at its hem, head at portrait height.
  local model,torso,head=Figures.statue(root,id,Vector3.new(n.X,n.Y-1.8,n.Z));model:SetAttribute("DialogueNPC",id)
  local label=Instance.new("BillboardGui");label.Size=UDim2.fromOffset(220,36);label.StudsOffset=Vector3.new(0,4,0);label.MaxDistance=36;label.Parent=head
  local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.Font=Enum.Font.Antique;text.Text=n.Name
  text.TextColor3=Color3.fromRGB(224,202,153);text.TextSize=15;text.Parent=label
  prompt(torso,"Speak",n.Name,function(player: Player) open(player,id) end,links)
 end
 for id,l in Catalog.Lore do
  local cf=CFrame.new(l.X,l.Y,l.Z)
  part(root,id.."Pedestal",Vector3.new(4.5,1,3),cf*CFrame.new(0,-2.5,0),Color3.fromRGB(43,45,41))
  local stone=part(root,id,Vector3.new(2.6,5,0.8),cf,Color3.fromRGB(38,49,47));stone:SetAttribute("LoreId",id)
  -- Jade script on both faces so a memorial reads from the path whichever way it is walked (#44).
  local rune=part(stone,"JadeInscription",Vector3.new(0.12,3,0.08),cf*CFrame.new(0,0,-0.45),Color3.fromRGB(113,207,172));rune.Material=Enum.Material.Neon;rune.CanCollide=false
  local back=part(stone,"JadeInscription",Vector3.new(0.12,3,0.08),cf*CFrame.new(0,0,0.45),rune.Color);back.Material=Enum.Material.Neon;back.CanCollide=false
  local light=Instance.new("PointLight");light.Color=rune.Color;light.Range=if id==Catalog.LoreOrder[1] then 16 else 9;light.Brightness=if id==Catalog.LoreOrder[1] then 1.2 else 0.6;light.Parent=rune
  prompt(stone,"Read Memorial",l.Title,function(player: Player) lore(player,id) end,links)
 end
 return root,links
end
return table.freeze(Kit)

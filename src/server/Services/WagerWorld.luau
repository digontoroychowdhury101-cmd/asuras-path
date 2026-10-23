--!strict
local Definitions=require(game:GetService("ReplicatedStorage").AsurasPath.Shared.WorldDefinitions)
local InputMap=require(game:GetService("ReplicatedStorage").AsurasPath.Shared.InputMap)
local Build={}
-- Cosmetic load paths only: the original balcony, stair shaft, rail collision and wager interaction
-- below retain their exact dimensions and positions. The kit is optional for detached fixtures.
local function supports(root: Folder,c: any)
 local styled,kit=pcall(function() return require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript) end)
 local visual=Instance.new("Folder");visual.Name="BalconySupports";visual.Parent=root
 local function decor(name: string,size: Vector3,cf: CFrame,surface: string): BasePart
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Anchored=true
  p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=false,false,false,true
  if styled then
   local s=kit.Surface[surface];p.Material,p.MaterialVariant,p.Color=s.Material,s.Variant,s.Color
  else
   p.Material=if surface=="Lacquer" or surface=="Timber" then Enum.Material.Wood else Enum.Material.Slate
   p.MaterialVariant="Asura"..surface;p.Color=if surface=="Lacquer" then Color3.fromRGB(91,37,32) else Color3.fromRGB(120,133,146)
  end
  p.Parent=visual;return p
 end
 local function beam(name: string,a: Vector3,b: Vector3,width: number,surface: string)
  decor(name,Vector3.new(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),surface)
 end
 local function mesh(name: string,cf: CFrame,scale: (number|Vector3)?): Model?
  if not styled then return nil end
  local model=kit.place(visual,name,cf,scale)
  if model then
   for _,p in model:GetDescendants() do
    if p:IsA("BasePart") then p.CanCollide,p.CanQuery,p.CanTouch=false,false,false end
   end
  end
  return model
 end
 for _,z in {-12,12} do
  -- The outer pair sits on masonry corbels rooted under the existing terrace lip.
  beam("BalconyStoneCorbel",Vector3.new(c.X+27,c.Y-3.3,c.Z+z),Vector3.new(c.X+35,c.Y-0.5,c.Z+z),1.8,"StoneDark")
  decor("BalconyBearing",Vector3.new(14,0.8,1.3),CFrame.new(c.X+30,c.Y+11.1,c.Z+z),"Timber")
  for _,x in {25,35} do
   local foot=CFrame.new(c.X+x,c.Y,c.Z+z)
   if not mesh("Column_Base",foot) then decor("BalconyStoneFoot",Vector3.new(2.1,0.9,2.1),foot*CFrame.new(0,0.45,0),"Stone") end
   if not mesh("Column_Lacquer",foot*CFrame.new(0,0.9,0),Vector3.new(1,0.93,1)) then
    decor("BalconyLacquerPost",Vector3.new(1.2,9.3,1.2),foot*CFrame.new(0,5.55,0),"Lacquer")
   end
   mesh("Bracket_Set",foot*CFrame.new(0,10.15,0),Vector3.new(0.62,0.45,0.62))
  end
 end
 -- This stringer is outside the full eight-stud stair shaft (x+26..34, z+18..40).
 beam("SpectatorStairStoneCheek",Vector3.new(c.X+35,c.Y+0.2,c.Z+40.5),Vector3.new(c.X+35,c.Y+11.25,c.Z+18),0.9,"StoneDark")
 if styled and kit.available() then
  for _,rail in root:GetChildren() do
   if rail:IsA("BasePart") and (rail.Name=="Balustrade" or rail.Name=="OuterRail") then
    local along=if rail.Size.X>rail.Size.Z then Vector3.new(1,0,0) else Vector3.new(0,0,1)
    local length=math.max(rail.Size.X,rail.Size.Z)
    local a=rail.Position-along*length/2-Vector3.yAxis*rail.Size.Y/2
    local cf=kit.along(a,a+along*length,a)
    local n=math.max(1,math.round(length/6));local step=length/n
    for i=0,n do mesh("Rail_Post",cf*CFrame.new(i*step,0,0),Vector3.new(1,3/4.16,1)) end
    for i=1,n do mesh("Rail_Bay",cf*CFrame.new((i-0.5)*step,0,0),Vector3.new((step-0.86)/5.1,1,1)) end
    rail.Transparency=1
   end
  end
 end
end
function Build.make(open: (Player)->()): (Folder,RBXScriptConnection)
 local c=Definitions.Sanctuary.Promenade
 local root=Instance.new("Folder");root.Name="SpectatorBalcony";root.Parent=workspace
 local function part(name: string,size: Vector3,position: Vector3): Part
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Anchored=true;p.Material=Enum.Material.Slate
  p.Color=Color3.fromRGB(150,156,160);p.MaterialVariant="AsuraStone";p.Parent=root;return p
 end
 part("Balcony",Vector3.new(14,1,32),Vector3.new(c.X+30,c.Y+12,c.Z))
 for _,z in {-16,16} do part("Balustrade",Vector3.new(14,3,0.6),Vector3.new(c.X+30,c.Y+14,c.Z+z)) end
 part("OuterRail",Vector3.new(0.6,3,32),Vector3.new(c.X+37,c.Y+14,c.Z))
 for n=1,12 do part("Stair"..n,Vector3.new(8,1,2),Vector3.new(c.X+30,c.Y+n,c.Z+42-n*2)) end
 local brazier=part("WagerBrazier",Vector3.new(1,3,1),Vector3.new(c.X+30,c.Y+14,c.Z+8))
 brazier.Material=Enum.Material.Slate;brazier.Transparency=1
 local prompt=Instance.new("ProximityPrompt");prompt.ActionText="Watch & Wager";prompt.ObjectText="Colosseum Balcony"
 prompt.MaxActivationDistance=14;InputMap.applyPrompt(prompt);prompt.Parent=brazier
 supports(root,c)
 local styled,kit=pcall(function() return require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript) end)
 if styled then
  local lamp=CFrame.new(c.X+30,c.Y+12.5,c.Z+8)
  if not kit.place(root,"Lantern_Stone",lamp) then kit.lanternFallback(root,lamp,false) end
  kit.glow(root,lamp*CFrame.new(0,3.35,0),Vector3.new(1.04,1.12,1.04),15,1.35)
 end
 return root,prompt.Triggered:Connect(open)
end
function Build.near(position: Vector3): boolean
 local c=Definitions.Sanctuary.Promenade
 return math.abs(position.X-(c.X+30))<=12 and math.abs(position.Z-c.Z)<=20 and position.Y>=c.Y+11 and position.Y<=c.Y+24
end
return table.freeze(Build)

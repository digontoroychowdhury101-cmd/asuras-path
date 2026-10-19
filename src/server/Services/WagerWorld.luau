--!strict
local Definitions=require(game:GetService("ReplicatedStorage").AsurasPath.Shared.WorldDefinitions)
local Build={}
function Build.make(open: (Player)->()): (Folder,RBXScriptConnection)
 local c=Definitions.Sanctuary.Promenade
 local root=Instance.new("Folder");root.Name="SpectatorBalcony";root.Parent=workspace
 local function part(name: string,size: Vector3,position: Vector3): Part
  local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Anchored=true;p.Material=Enum.Material.Slate
  p.Color=Color3.fromRGB(48,42,41);p.Parent=root;return p
 end
 part("Balcony",Vector3.new(14,1,32),Vector3.new(c.X+30,c.Y+12,c.Z))
 for _,z in {-16,16} do part("Balustrade",Vector3.new(14,3,0.6),Vector3.new(c.X+30,c.Y+14,c.Z+z)) end
 part("OuterRail",Vector3.new(0.6,3,32),Vector3.new(c.X+37,c.Y+14,c.Z))
 for n=1,12 do part("Stair"..n,Vector3.new(8,1,2),Vector3.new(c.X+30,c.Y+n,c.Z+42-n*2)) end
 local brazier=part("WagerBrazier",Vector3.new(1,3,1),Vector3.new(c.X+30,c.Y+14,c.Z+8))
 brazier.Material=Enum.Material.Neon;brazier.Color=Color3.fromRGB(190,76,46)
 local prompt=Instance.new("ProximityPrompt");prompt.ActionText="Watch & Wager";prompt.ObjectText="Colosseum Balcony"
 prompt.MaxActivationDistance=14;prompt.KeyboardKeyCode=Enum.KeyCode.Z;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX;prompt.Parent=brazier
 return root,prompt.Triggered:Connect(open)
end
function Build.near(position: Vector3): boolean
 local c=Definitions.Sanctuary.Promenade
 return math.abs(position.X-(c.X+30))<=12 and math.abs(position.Z-c.Z)<=20 and position.Y>=c.Y+11 and position.Y<=c.Y+24
end
return table.freeze(Build)

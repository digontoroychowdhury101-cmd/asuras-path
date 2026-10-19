--!strict
local CollectionService = game:GetService("CollectionService")
local World = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.WorldDefinitions)
local Pbr = require(script.Parent.PbrAssets)
local Lighting = {}
function Lighting.Build(): Folder
	local old = workspace:FindFirstChild("AsuraArenaLighting")
	if old then old:Destroy() end
	local folder = Instance.new("Folder"); folder.Name,folder.Parent="AsuraArenaLighting",workspace
	for _, boss in World.Bosses do
		for i, corner in {Vector2.new(-1,-1),Vector2.new(1,-1),Vector2.new(-1,1),Vector2.new(1,1)} do
			local c,s=boss.Arena.Center,boss.Arena.Size
			local at=Vector3.new(c.X+corner.X*s.X*0.34,0.35,c.Z+corner.Y*s.Z*0.34)
			Pbr.place(folder,"AsuraFirePit",CFrame.new(at),5,"Longest")
			local anchor=Instance.new("Part")
			anchor.Name,anchor.Size,anchor.Position,anchor.Transparency="ArenaBrazierLight",Vector3.one*0.1,at+Vector3.yAxis*3,1
			anchor.Anchored,anchor.CanCollide,anchor.CanQuery,anchor.CanTouch,anchor.CastShadow=true,false,false,false,false
			anchor.Parent=folder
			local light=Instance.new("PointLight")
			light.Color,light.Range,light.Brightness,light.Shadows=Color3.fromRGB(255,161,84),55,3,i<=2
			light.Parent=anchor;CollectionService:AddTag(light,"AsuraArenaLight")
		end
	end
	return folder
end
return Lighting

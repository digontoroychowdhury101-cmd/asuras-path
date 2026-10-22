--!strict
-- Corner braziers give each arena its firelight; overhead fill lanterns (ArenaLightPlan) keep the
-- whole floor and both fighters readable in the arena's biome colour. Clients retint braziers.
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").AsurasPath.Shared
local World = require(Shared.WorldDefinitions)
local Plan = require(Shared.ArenaLightPlan)
local Profiles = require(Shared.EnvironmentProfiles)
local Pbr = require(script.Parent.PbrAssets)
local Lighting = {}
local function anchor(folder: Instance, name: string, at: Vector3): Part
	local part=Instance.new("Part")
	part.Name,part.Size,part.Position,part.Transparency=name,Vector3.one*0.1,at,1
	part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch,part.CastShadow=true,false,false,false,false
	part.Parent=folder
	return part
end
function Lighting.Build(): Folder
	local old = workspace:FindFirstChild("AsuraArenaLighting")
	if old then old:Destroy() end
	local folder = Instance.new("Folder"); folder.Name,folder.Parent="AsuraArenaLighting",workspace
	for _, boss in World.Bosses do
		for i, at in Plan.braziers(boss.Arena) do
			Pbr.place(folder,"AsuraFirePit",CFrame.new(at),5,"Longest")
			local light=Instance.new("PointLight")
			light.Color,light.Range,light.Brightness,light.Shadows=Profiles.arena(boss.Region).Brazier,Plan.Brazier.Range,Plan.Brazier.Brightness,i<=2
			light.Parent=anchor(folder,"ArenaBrazierLight",at+Vector3.yAxis*Plan.Brazier.Height);CollectionService:AddTag(light,"AsuraArenaLight")
		end
		for _, at in Plan.fills(boss.Arena) do
			local light=Instance.new("PointLight")
			light.Color,light.Range,light.Brightness,light.Shadows=Profiles.arena(boss.Region).Fill,Plan.Fill.Range,Plan.Fill.Brightness,false
			light.Parent=anchor(folder,"ArenaFillLight",at);CollectionService:AddTag(light,"AsuraArenaFill")
		end
	end
	return folder
end
return Lighting

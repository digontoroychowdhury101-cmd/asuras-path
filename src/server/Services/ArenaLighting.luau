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
-- ArenaLightPlan places lights for a floor at Y 0 (arena centre Y 20). A relocated arena (Shen's summit domain, floor Y 1580)
-- sits higher, so every light is lifted by the centre's offset; a Y 20 arena gets no lift.
local CENTER_ABOVE_FLOOR = 20
function Lighting.lift(arena: { Center: { Y: number } }): Vector3
	return Vector3.yAxis * (arena.Center.Y - CENTER_ABOVE_FLOOR)
end
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
		if boss.Inactive then continue end
		local lift = Lighting.lift(boss.Arena)
		for i, base in Plan.braziers(boss.Arena) do
			local at = base + lift
			Pbr.place(folder,"AsuraFirePit",CFrame.new(at),5,"Longest")
			local light=Instance.new("PointLight")
			light.Color,light.Range,light.Brightness,light.Shadows=Profiles.arena(boss.Region).Brazier,Plan.Brazier.Range,Plan.Brazier.Brightness*(if boss.Region=="BambooPass" then 0.65 else 1),i<=2
			light.Parent=anchor(folder,"ArenaBrazierLight",at+Vector3.yAxis*Plan.Brazier.Height);CollectionService:AddTag(light,"AsuraArenaLight")
		end
		for _, base in Plan.fills(boss.Arena) do
			local at = base + lift
			local light=Instance.new("PointLight")
			light.Color,light.Range,light.Brightness,light.Shadows=Profiles.arena(boss.Region).Fill,Plan.Fill.Range,Plan.Fill.Brightness,false
			light.Parent=anchor(folder,"ArenaFillLight",at);CollectionService:AddTag(light,"AsuraArenaFill")
		end
	end
	return folder
end
return Lighting

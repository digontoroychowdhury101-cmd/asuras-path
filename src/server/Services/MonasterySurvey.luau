--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasterySurvey
-- Walkability check for a procedurally built region: raycasts every altar surround, altar spawn,
-- mob spawn and patrol point down to the walkable top, and every patrol leg sideways at knee and
-- chest height. Each altar's rest pocket (Kit.POCKET, shrine excluded) and the walk from its spawn
-- to its Exit (batch 07) must be free of solid geometry. Returns human-readable problems.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("AsurasPath").Shared.WorldDefinitions)
local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)

local Survey = {}

local GROUND_TOLERANCE = 0.6
local PROBE_HEIGHT = 60

-- Every altar, spawn and patrol point must stand on stone at Kit.GROUND with nothing solid on top,
-- and every patrol leg must be walkable in a straight line.
function Survey.Run(regionId: World.RegionId): { string }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	-- Characters (players and the region's spawned enemies) are not terrain; look through them.
	local characters: { Instance } = {}
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Humanoid") and d.Parent then
			table.insert(characters, d.Parent)
		end
	end
	params.FilterDescendantsInstances = characters
	local problems: { string } = {}
	local function ground(label: string, x: number, z: number)
		local hit = Workspace:Raycast(Vector3.new(x, Kit.GROUND + PROBE_HEIGHT, z), Vector3.new(0, -PROBE_HEIGHT * 2, 0), params)
		if not hit then
			table.insert(problems, string.format("%s (%.0f, %.0f): no ground", label, x, z))
		elseif math.abs(hit.Position.Y - Kit.GROUND) > GROUND_TOLERANCE then
			table.insert(problems, string.format("%s (%.0f, %.0f): surface at Y %.1f (%s)", label, x, z, hit.Position.Y, hit.Instance.Name))
		end
	end
	local function leg(label: string, a: World.Placement, b: World.Placement)
		for _, lift in { 1.2, 3.5 } do
			local from = Vector3.new(a.X, Kit.GROUND + lift, a.Z)
			local hit = Workspace:Raycast(from, Vector3.new(b.X, Kit.GROUND + lift, b.Z) - from, params)
			if hit then
				table.insert(problems, string.format("%s leg blocked by %s at (%.0f, %.0f)", label, hit.Instance.Name, hit.Position.X, hit.Position.Z))
				return
			end
		end
	end
	for id, altar in World.Regions[regionId].Altars do -- The shrine fills the altar point; survey its diagonals.
		for k = 0, 3 do
			local a = math.pi / 4 + k * math.pi / 2
			ground(id .. " altar ring", altar.Placement.X + math.cos(a) * 5.5, altar.Placement.Z + math.sin(a) * 5.5)
		end
		ground(id .. " spawn", altar.Spawn.X, altar.Spawn.Z)
		local shrine = Workspace:FindFirstChild("Shrine_" .. altar.Id, true)
		local saved = params.FilterDescendantsInstances
		local ignore = table.clone(characters)
		if shrine then table.insert(ignore, shrine) end
		params.FilterDescendantsInstances = ignore
		for k = 0, 11 do -- pocket: spokes from the shrine's edge out to the pocket radius
			local a = k * math.pi / 6
			local from = Vector3.new(altar.Placement.X + math.cos(a) * 3.5, 0, altar.Placement.Z + math.sin(a) * 3.5)
			local to = Vector3.new(altar.Placement.X + math.cos(a) * Kit.POCKET, 0, altar.Placement.Z + math.sin(a) * Kit.POCKET)
			leg(id .. " pocket", { X = from.X, Y = 3, Z = from.Z, Yaw = 0 }, { X = to.X, Y = 3, Z = to.Z, Yaw = 0 })
		end
		if altar.Exit then
			leg(id .. " departure", altar.Spawn, altar.Exit)
		end
		params.FilterDescendantsInstances = saved
	end
	for _, entry in World.spawnsIn(regionId) do
		ground(entry.Id, entry.Placement.X, entry.Placement.Z)
		for index, point in entry.Patrol do
			ground(entry.Id .. " patrol " .. index, point.X, point.Z)
			leg(entry.Id .. " patrol " .. index, point, entry.Patrol[index % #entry.Patrol + 1])
		end
	end
	return problems
end

return Survey

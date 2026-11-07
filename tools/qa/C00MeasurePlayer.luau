-- C00 intake probe (Play, Server, read-only; run through execute_luau): the spawned player's rig,
-- standing height, root offset and live movement settings. Output: JSON (C00/player-measure.json).
local HS = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local function r2(v) return math.floor(v * 100 + 0.5) / 100 end
local deadline = os.clock() + 20
local player = Players:GetPlayers()[1]
while (not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart")) and os.clock() < deadline do
	task.wait(0.25)
	player = Players:GetPlayers()[1]
end
if not player or not player.Character then return "no character" end
task.wait(1)
local ch = player.Character
local root = ch:FindFirstChild("HumanoidRootPart")
local hum = ch:FindFirstChildOfClass("Humanoid")
local minY, maxY = math.huge, -math.huge
local headTop
for _, d in ch:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		local h = d.Size / 2
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			local p = d.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
			minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
		end end end
		if d.Name == "Head" then headTop = d.Position.Y + d.Size.Y / 2 end
	end
end
local params = RaycastParams.new()
params.FilterDescendantsInstances = { ch }
local hit = workspace:Raycast(root.Position, Vector3.new(0, -20, 0), params)
local _, box = ch:GetBoundingBox()
local Settings = require(RS.AsurasPath.Shared.CombatSettings)
return HS:JSONEncode({
	rigType = tostring(hum.RigType), hipHeight = r2(hum.HipHeight), walkSpeedLive = r2(hum.WalkSpeed),
	rootSize = { r2(root.Size.X), r2(root.Size.Y), r2(root.Size.Z) },
	visibleHeight = r2(maxY - minY), headTopAboveFeet = headTop and r2(headTop - minY) or nil,
	groundY = hit and r2(hit.Position.Y) or nil, rootAboveGround = hit and r2(root.Position.Y - hit.Position.Y) or nil,
	bbox = { r2(box.X), r2(box.Y), r2(box.Z) },
	movement = { Walk = Settings.Movement.WalkSpeed, Sprint = Settings.Movement.SprintSpeed, Dash = Settings.Movement.DashDistance,
		DashDuration = Settings.Movement.DashDuration, Roll = Settings.Movement.RollDistance, RollDuration = Settings.Movement.RollDuration },
})

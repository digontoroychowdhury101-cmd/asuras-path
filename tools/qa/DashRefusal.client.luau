--!nonstrict
-- Unmapped Studio-only probe (Windows acceptance W-07, 2026-11-03), paired with DashRefusal.server.luau. For
-- AsuraDashSeconds (default 6) it records, every rendered frame: the root position, the floor height under the
-- root (downward raycast) and whether the root's box overlaps level geometry, plus LocalPrediction's trace
-- (Sent / Predicted / RolledBack ...) so the refused dash is matched by intent seq. JSON lands in the player
-- attribute AsuraDashProbe. Evidence type: seeded Studio diagnostic.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not RunService:IsStudio() then
	return
end
local Prediction = require(ReplicatedStorage.AsurasPath.Simulation.LocalPrediction)
local player = Players.LocalPlayer
local SECONDS = tonumber(player:GetAttribute("AsuraDashSeconds")) or 6
local trace = Prediction.Trace
table.clear(trace.Records)
trace.Enabled = true
player:SetAttribute("AsuraDashProbe", nil)

local t0 = os.clock()
local frames = {}
local function round(v: number): number
	return math.floor(v * 1000 + 0.5) / 1000
end
local connection
connection = RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if t > SECONDS then
		connection:Disconnect()
		trace.Enabled = false
		local records = {}
		for _, r in trace.Records do
			table.insert(records, { seq = r.seq, e = r.e, d = r.d, t = round(r.t - t0) })
		end
		table.clear(trace.Records)
		player:SetAttribute("AsuraDashProbe", HttpService:JSONEncode({ frames = frames, trace = records }))
		return
	end
	if not root then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local down = Workspace:Raycast(root.Position, Vector3.new(0, -50, 0), params)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local touching = Workspace:GetPartBoundsInBox(root.CFrame, root.Size * 0.9, overlap)
	local solid = 0
	for _, part in touching do
		if part.CanCollide then
			solid += 1
		end
	end
	local p = root.Position
	table.insert(frames, { t = round(t), p = { round(p.X), round(p.Y), round(p.Z) },
		floor = if down then round(down.Position.Y) else nil, inside = solid })
end)

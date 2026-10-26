--!nonstrict
-- Studio-only camera-clearance sampler for the Twin Sentinels (post-F26 Step 4). Run with
-- execute_luau in the Client datamodel during Play; returns one line. Read-only: it samples the real
-- game camera every render frame for SECONDS and reports, per Twin, how often its body crosses the
-- camera -> player sight line (head and root), how much of the screen its bounding box covers, and
-- the body's local transparency (what CameraClearance fades). Evidence type: seeded Studio diagnostic.
local SECONDS = 12
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local camera = workspace.CurrentCamera
local me = Players.LocalPlayer.Character
local function twins()
	local list = {}
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("AsuraEncounter") == "TwinSentinels" and m:FindFirstChild("HumanoidRootPart") then table.insert(list, m) end
	end
	return list
end
local function coverage(model)
	local cf, size = model:GetBoundingBox()
	local vp = camera.ViewportSize
	local x0, y0, x1, y1, any = math.huge, math.huge, -math.huge, -math.huge, false
	for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
		local p, on = camera:WorldToViewportPoint((cf * CFrame.new(size.X / 2 * sx, size.Y / 2 * sy, size.Z / 2 * sz)).Position)
		if p.Z > 0 then any = true; x0, y0, x1, y1 = math.min(x0, p.X), math.min(y0, p.Y), math.max(x1, p.X), math.max(y1, p.Y) end
		local _ = on
	end end end
	if not any then return 0 end
	x0, y0, x1, y1 = math.clamp(x0, 0, vp.X), math.clamp(y0, 0, vp.Y), math.clamp(x1, 0, vp.X), math.clamp(y1, 0, vp.Y)
	return math.max(0, x1 - x0) * math.max(0, y1 - y0) / (vp.X * vp.Y)
end
local stats, frames = {}, 0
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local conn = Run.RenderStepped:Connect(function()
	if not me or not me:FindFirstChild("Head") then return end
	frames += 1
	for _, m in twins() do
		local s = stats[m.Name] or { block = 0, cover = 0, maxCover = 0, faded = 0, dist = 0, front = 0 }
		stats[m.Name] = s
		params.FilterDescendantsInstances = { m }
		local origin = camera.CFrame.Position
		local blocked = false
		for _, point in { me.Head.Position, me.HumanoidRootPart.Position } do
			if workspace:Raycast(origin, point - origin, params) then blocked = true end
		end
		if blocked then s.block += 1 end
		local c = coverage(m)
		s.cover += c
		s.maxCover = math.max(s.maxCover, c)
		local root = m.HumanoidRootPart
		s.dist += (root.Position - origin).Magnitude
		if (root.Position - origin).Magnitude < (me.HumanoidRootPart.Position - origin).Magnitude - 1.5 then s.front += 1 end
		local fade = 0
		for _, part in m:GetDescendants() do if part:IsA("BasePart") then fade = math.max(fade, part.LocalTransparencyModifier) end end
		if fade > 0.3 then s.faded += 1 end
	end
end)
task.wait(SECONDS)
conn:Disconnect()
local out = { string.format("frames %d", frames) }
for name, s in stats do
	table.insert(out, string.format("%s: sightline blocked %.0f%% | screen cover mean %.0f%% max %.0f%% | nearer lens than player %.0f%% | faded %.0f%% | cam dist %.1f", name,
		100 * s.block / frames, 100 * s.cover / frames, 100 * s.maxCover, 100 * s.front / frames, 100 * s.faded / frames, s.dist / frames))
end
return table.concat(out, "\n")

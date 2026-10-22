-- Studio QA (Client, during Play; run through tools/qa/lobby_capture.py calls): frame time on the
-- Shrine lobby at fixed cameras, then the same cameras with Workspace.Sanctuary hidden on this client
-- only, so the difference is the lobby's own cost. Studio must be the frontmost app or macOS throttles
-- it (about 15 fps) and the numbers mean nothing. Restores the camera, HUD and the lobby afterwards.
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local cam = workspace.CurrentCamera
local gui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local VIEWS = {
	{ "entrance", Vector3.new(0, 609, 950), Vector3.new(0, 619, 850) },
	{ "elevated", Vector3.new(70, 700, 1040), Vector3.new(0, 610, 860) },
	{ "gameplay", Vector3.new(0, 606.5, 934), Vector3.new(0, 607, 880) },
	{ "terrace", Vector3.new(0, 636, 786), Vector3.new(0, 668, 700) },
}
local FRAMES = 240

local hidden = {}
for _, g in gui:GetChildren() do
	if g:IsA("ScreenGui") and g.Enabled then
		g.Enabled = false
		table.insert(hidden, g)
	end
end
local pose = CFrame.new()
RunService:BindToRenderStep("AsuraFrameTime", Enum.RenderPriority.Last.Value + 50, function()
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 70
	cam.CFrame = pose
end)

local function sample(): string
	task.wait(2)
	local dts, cpu = {}, 0
	for _ = 1, FRAMES do
		table.insert(dts, RunService.RenderStepped:Wait())
		cpu += Stats.RenderCPUFrameTime
	end
	table.sort(dts)
	local sum = 0
	for _, d in dts do
		sum += d
	end
	return string.format("avg %.1fms p95 %.1fms (%.0f fps) renderCPU %.1fms", sum / #dts * 1000, dts[math.ceil(#dts * 0.95)] * 1000,
		#dts / sum, cpu / FRAMES * 1000)
end

local out = {}
for _, mode in { "lobby", "hidden" } do
	local lobby = workspace:FindFirstChild("Sanctuary")
	if mode == "hidden" and lobby then
		lobby.Parent = nil
	end
	for _, v in VIEWS do
		pose = CFrame.lookAt(v[2], v[3])
		table.insert(out, string.format("%s/%s: %s", mode, v[1], sample()))
	end
	if mode == "hidden" and lobby then
		lobby.Parent = workspace
	end
end
RunService:UnbindFromRenderStep("AsuraFrameTime")
cam.CameraType = Enum.CameraType.Custom
for _, g in hidden do
	g.Enabled = true
end
local okQ, quality = pcall(function() return settings().Rendering.QualityLevel.Name end)
return string.format("quality %s | mem %dMB | ", if okQ then quality else "?", math.floor(Stats:GetTotalMemoryUsageMb())) .. table.concat(out, "\n")

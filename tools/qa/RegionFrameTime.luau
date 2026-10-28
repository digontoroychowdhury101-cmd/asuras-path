-- Studio QA (Client, during Play; run with execute_luau after setting _G.AsuraFrameTimeRegion): frame
-- time for one campaign region at fixed cameras, then the same cameras with the uploaded Han / lobby
-- kit models hidden on this client only, so the difference is the kits' own cost. Moves the local
-- character into the region first so its lighting applies. Studio must be the foreground window or the
-- OS may throttle it. Restores the camera, HUD and the models afterwards. Evidence type: seeded Studio
-- diagnostic on this machine, not a device benchmark. When Studio is frame-capped (every view the same
-- wall time), compare renderGPU: the GPU's own time per frame, which the cap does not hide.
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local cam = workspace.CurrentCamera
local gui = Players.LocalPlayer:WaitForChild("PlayerGui")

local REGIONS = {
	CelestialPagoda = { map = "Map_CelestialPagoda", stand = Vector3.new(0, -20, -2200), views = {
		{ "gate", Vector3.new(0, 30, -2080), Vector3.new(0, 20, -2300) },
		{ "aerial", Vector3.new(-230, 120, -2200), Vector3.new(40, 10, -2390) },
		{ "hall", Vector3.new(60, 18, -2262), Vector3.new(140, 45, -2318) },
	} },
	SkyCitadel = { map = "Map_SkyCitadel", stand = Vector3.new(0, 4, -2700), views = {
		{ "saddle", Vector3.new(0, 14, -2542), Vector3.new(0, 0, -2700) },
		{ "aerial", Vector3.new(-260, 110, -2560), Vector3.new(0, 0, -2780) },
		{ "bastion", Vector3.new(-30, 25, -2655), Vector3.new(-120, 40, -2700) },
	} },
	BambooPass = { map = "Map_BambooPass", stand = Vector3.new(0, 4, -1300), views = {
		{ "valley", Vector3.new(-40, 40, -1180), Vector3.new(150, 50, -1340) },
		{ "arena", Vector3.new(40, 40, -1430), Vector3.new(-246, 70, -1490) },
		{ "shrine", Vector3.new(-10, 10, -1322), Vector3.new(-36, 4, -1342) },
	} },
}
local FRAMES = 240
local KIT = { HanPagodaHD = true, HanGateHD = true, Pine = true, CragA = true, CragB = true, CragC = true }

local region = REGIONS[_G.AsuraFrameTimeRegion]
assert(region, "set _G.AsuraFrameTimeRegion to CelestialPagoda, SkyCitadel or BambooPass")
local character = Players.LocalPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
if root then
	root.Anchored = true
	character:PivotTo(CFrame.new(region.stand))
end
task.wait(8) -- region lighting blends in

local hidden = {}
for _, g in gui:GetChildren() do
	if g:IsA("ScreenGui") and g.Enabled then
		g.Enabled = false
		table.insert(hidden, g)
	end
end
local pose = CFrame.new()
RunService:BindToRenderStep("AsuraRegionFrameTime", Enum.RenderPriority.Last.Value + 50, function()
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 70
	cam.CFrame = pose
end)

local function sample(): string
	task.wait(2)
	local dts, cpu, gpu = {}, 0, 0
	for _ = 1, FRAMES do
		table.insert(dts, RunService.RenderStepped:Wait())
		cpu += Stats.RenderCPUFrameTime
		gpu += Stats.RenderGPUFrameTime
	end
	table.sort(dts)
	local sum = 0
	for _, d in dts do
		sum += d
	end
	return string.format("avg %.1fms p95 %.1fms (%.0f fps) renderCPU %.1fms renderGPU %.2fms", sum / #dts * 1000,
		dts[math.ceil(#dts * 0.95)] * 1000, #dts / sum, cpu / FRAMES * 1000, gpu / FRAMES * 1000)
end

local map = workspace:FindFirstChild(region.map)
local kits, triangles = {}, 0
for _, m in if map then map:GetDescendants() else {} do
	if m:IsA("Model") and (KIT[m.Name] or m.Name:match("^Han") or m.Name:match("^Column_") or m.Name:match("^Bracket_")) then
		table.insert(kits, { m, m.Parent })
	end
end
local out = {}
for _, mode in { "full", "kits hidden" } do
	if mode == "kits hidden" then
		for _, k in kits do
			k[1].Parent = nil
		end
	end
	for _, v in region.views do
		pose = CFrame.lookAt(v[2], v[3])
		table.insert(out, string.format("%s/%s: %s", mode, v[1], sample()))
	end
end
for _, k in kits do
	k[1].Parent = k[2]
end
RunService:UnbindFromRenderStep("AsuraRegionFrameTime")
cam.CameraType = Enum.CameraType.Custom
for _, g in hidden do
	g.Enabled = true
end
local okQ, quality = pcall(function() return settings().Rendering.QualityLevel.Name end)
return string.format("%s | %d kit models | quality %s | mem %dMB\n", _G.AsuraFrameTimeRegion, #kits, if okQ then quality else "?",
	math.floor(Stats:GetTotalMemoryUsageMb())) .. table.concat(out, "\n")

local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local out = {}
local function try(label, fn)
	local ok, v = pcall(fn)
	table.insert(out, label .. "=" .. (if ok then tostring(v) else "n/a"))
end
try("quality", function() return settings().Rendering.QualityLevel end)
try("savedQuality", function() return UserSettings().GameSettings.SavedQualityLevel end)
try("meshDetail", function() return settings().Rendering.MeshPartDetailLevel end)
try("frameTime", function() return Stats.FrameTime end)
try("renderCPU", function() return Stats.RenderCPUFrameTime end)
try("renderGPU", function() return Stats.RenderGPUFrameTime end)
try("heartbeatMs", function() return Stats.HeartbeatTimeMs end)
try("memMb", function() return math.floor(Stats:GetTotalMemoryUsageMb()) end)
try("instances", function() return Stats.InstanceCount end)
try("primitives", function() return Stats.PrimitivesCount end)
try("drawcalls", function() return Stats:FindFirstChild("Render") and "has" or "none" end)
local dts, t0 = {}, os.clock()
for i = 1, 60 do table.insert(dts, RunService.RenderStepped:Wait()) end
local sum = 0
for _, d in dts do sum += d end
table.insert(out, string.format("avgFrame=%.1fms fps=%.0f", sum / #dts * 1000, #dts / sum))
return table.concat(out, " | ")

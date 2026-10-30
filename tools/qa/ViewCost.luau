-- Read-only running Client diagnostic at the current normal camera. Short samples identify costs;
-- they do not replace the required 60-second traversal/combat acceptance run.
local run, stats = game:GetService("RunService"), game:GetService("Stats")
local duration = math.clamp(tonumber(_G.AsuraViewCostSeconds) or 6, 1, 10)
_G.AsuraViewCostSeconds = nil
local function safe(read)
	local ok, value = pcall(read)
	return if ok then tostring(value) else "unavailable"
end
local function dist(values)
	table.sort(values)
	local total = 0
	for _, v in values do total += v end
	return { count = #values, meanMs = total / #values, p95Ms = values[math.ceil(#values * 0.95)] }
end
local function composition()
	local ok, value = pcall(function() return game:GetService("SceneAnalysisService"):GetTriangleCompositionAsync() end)
	return if ok then value else { error = tostring(value) }
end
local observer = _G.AsuraFocusProbe
local prior = observer and observer.events and observer.events[#observer.events]
local focused, unknown, unfocused = prior and prior.focused, 0, 0
local a = game.UserInputService.WindowFocused:Connect(function() focused = true end)
local b = game.UserInputService.WindowFocusReleased:Connect(function() focused = false end)
local frames, cpu, gpu = {}, {}, {}
local started = os.clock()
while os.clock() - started < duration do
	local dt = run.RenderStepped:Wait()
	table.insert(frames, dt * 1000)
	table.insert(cpu, stats.RenderCPUFrameTime * 1000)
	table.insert(gpu, stats.RenderGPUFrameTime * 1000)
	if focused == nil then unknown += 1 elseif not focused then unfocused += 1 end
end
a:Disconnect(); b:Disconnect()
local rendering = settings().Rendering
return game.HttpService:JSONEncode({ kind = "short fixed-view Studio diagnostic; not acceptance",
	seconds = os.clock() - started, frame = dist(frames), cpu = dist(cpu), gpu = dist(gpu),
	unknownFocusFrames = unknown, unfocusedFrames = unfocused, composition = composition(),
	quality = safe(function() return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Name end),
	autoFRM = safe(function() return rendering.AutoFRMLevel end), frm = safe(function() return rendering.EnableFRM end),
	foliageShadows = game.Players.LocalPlayer:GetAttribute("LandscapeFoliageShadows"),
	memoryMb = stats:GetTotalMemoryUsageMb() })

-- Running Client diagnostic. Starts a bounded 60-second sampler and returns immediately so ordinary
-- gameplay/input can continue. Read _G.AsuraEnvironmentSample.Result afterwards. No scene, camera,
-- quality, combat, movement or preference changes. Not a physical-mobile or published-client test.
local Run = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
assert(not _G.AsuraEnvironmentSample or not _G.AsuraEnvironmentSample.Running, "sample already running")
local player = Players.LocalPlayer
local state = { Running = true, Result = nil, Error = nil }
_G.AsuraEnvironmentSample = state

local function safe(read)
	local ok, value = pcall(read)
	return if ok then tostring(value) else "unavailable"
end
local function distribution(values)
	if #values == 0 then return { count = 0 } end
	local sorted = table.clone(values)
	table.sort(sorted)
	local sum = 0
	for _, v in sorted do sum += v end
	return { count = #sorted, meanMs = sum / #sorted, p50Ms = sorted[math.ceil(#sorted * 0.5)],
		p95Ms = sorted[math.ceil(#sorted * 0.95)], p99Ms = sorted[math.ceil(#sorted * 0.99)], maxMs = sorted[#sorted] }
end
local function composition()
	local ok, value = pcall(function() return game:GetService("SceneAnalysisService"):GetTriangleCompositionAsync() end)
	return if ok then value else { error = tostring(value) }
end

task.spawn(function()
	local focused = nil -- initial focus unknown; subsequent focus events are measured explicitly
	local links = {
		UIS.WindowFocused:Connect(function() focused = true end),
		UIS.WindowFocusReleased:Connect(function() focused = false end),
	}
	local ok, err = xpcall(function()
		local camera = workspace.CurrentCamera
		local viewport = camera.ViewportSize
		local frames, cpu, gpu, foreground = {}, {}, {}, {}
		local snapshots = {}
		local skipped, unknownFocus, unfocused = 0, 0, 0
		local startComposition = composition()
		local started, nextSnapshot = os.clock(), 0
		local lastPosition = nil
		local distance = 0
		while os.clock() - started < 60 do
			local dt = Run.RenderStepped:Wait()
			if #frames < 36000 then
				table.insert(frames, dt * 1000)
				table.insert(cpu, Stats.RenderCPUFrameTime * 1000)
				table.insert(gpu, Stats.RenderGPUFrameTime * 1000)
				if focused == true then table.insert(foreground, dt * 1000)
				elseif focused == false then unfocused += 1 else unknownFocus += 1 end
			else skipped += 1 end
			local elapsed = os.clock() - started
			if elapsed >= nextSnapshot then
				nextSnapshot = elapsed + 1
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local position = if root and root:IsA("BasePart") then root.Position else nil
				if position and lastPosition then distance += (position - lastPosition).Magnitude end
				lastPosition = position
				table.insert(snapshots, { seconds = elapsed, position = position and { position.X, position.Y, position.Z },
					region = player:GetAttribute("AsuraRegion"), encounter = player:GetAttribute("AsuraEncounter"),
					memoryMb = Stats:GetTotalMemoryUsageMb(), tier = player:GetAttribute("LandscapeTier"),
					foliageRegistered = player:GetAttribute("FoliageRegistered"), foliageActive = player:GetAttribute("FoliageActive"),
					foliageUpdateMs = player:GetAttribute("FoliageUpdateMs"), focused = focused })
			end
		end
		local seconds = os.clock() - started
		local parts, meshes = 0, 0
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") then parts += 1 end
			if d:IsA("MeshPart") then meshes += 1 end
		end
		state.Result = { kind = "Studio client 60-second ordinary-gameplay sample; no scene overrides",
			studioVersion = version(), place = game.Name, seconds = seconds, viewport = { viewport.X, viewport.Y },
			quality = safe(function() return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Name end),
			renderQuality = safe(function() return settings().Rendering.QualityLevel.Name end),
			frameCap = safe(function() return UserSettings():GetService("UserGameSettings").FramerateCap end),
			frames = distribution(frames), renderCPU = distribution(cpu), renderGPU = distribution(gpu),
			knownForegroundFrames = distribution(foreground), unknownFocusFrames = unknownFocus,
			unfocusedFrames = unfocused, droppedSamples = skipped, sampledTravelStuds = distance,
			workspaceParts = parts, workspaceMeshParts = meshes, snapshots = snapshots,
			startComposition = startComposition, endComposition = composition() }
	end, debug.traceback)
	for _, link in links do link:Disconnect() end
	state.Running = false
	if not ok then state.Error = tostring(err); warn("Environment sample: " .. tostring(err))
	else print("[Asura environment sample] " .. Http:JSONEncode(state.Result)) end
end)
return "Started 60-second sample. Play normally; read _G.AsuraEnvironmentSample after completion."

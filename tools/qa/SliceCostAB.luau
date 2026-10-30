-- Running Client diagnostic: alternating A/B frame cost of the v9 Bamboo slice additions at a pinned
-- ordinary-height camera. "hidden" reparents only this slice's decor client-side (no server state,
-- colliders or gameplay change) and restores it in every outcome. Inputs (_G.AsuraSliceAB):
-- { Eye = Vector3, Target = Vector3, Seconds = number?, Rounds = number? }. Returns JSON.
local Run = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UIS = game:GetService("UserInputService")
local args = _G.AsuraSliceAB
_G.AsuraSliceAB = nil
assert(args and args.Eye and args.Target, "set _G.AsuraSliceAB first")
local seconds = math.clamp(args.Seconds or 8, 2, 15)
local rounds = math.clamp(args.Rounds or 2, 1, 4)
local NEW = { MoonCoping = true, MoonJambShell = true, MoonPlinth = true, MoonImpost = true, ParapetCoping = true }

local map = workspace:FindFirstChild("Map_BambooPass")
assert(map, "Bamboo map missing")
local stash = Instance.new("Folder")
local moved: { { Instance } } = {}
local function hide()
	local south = map:FindFirstChild("LivingBambooSouth", true)
	if south then table.insert(moved, { south, south.Parent :: Instance }) south.Parent = stash end
	local dressing = map:FindFirstChild("PassDressing")
	for _, d in if dressing then dressing:GetChildren() else {} do
		if NEW[d.Name] then table.insert(moved, { d, dressing :: Instance }) d.Parent = stash end
	end
end
local function show()
	for i = #moved, 1, -1 do moved[i][1].Parent = moved[i][2] end
	table.clear(moved)
end
local function dist(values: { number })
	table.sort(values)
	local total = 0
	for _, v in values do total += v end
	return { count = #values, meanMs = total / math.max(1, #values), p50Ms = values[math.ceil(#values * 0.5)], p95Ms = values[math.ceil(#values * 0.95)] }
end
local observer = _G.AsuraFocusProbe -- tools/qa/EnvironmentFocus.luau; only real events count
local prior = observer and observer.events and observer.events[#observer.events]
local focused: boolean?, unknown, unfocused = prior and prior.focused, 0, 0
local fa = UIS.WindowFocused:Connect(function() focused = true end)
local fb = UIS.WindowFocusReleased:Connect(function() focused = false end)
local function sample(label: string)
	task.wait(1.5)
	local frames, cpu, gpu = {}, {}, {}
	local t0 = os.clock()
	local c = Run.RenderStepped:Connect(function(dt)
		table.insert(frames, dt * 1000)
		local okC, vC = pcall(function() return Stats.RenderCPUFrameTime * 1000 end)
		local okG, vG = pcall(function() return Stats.RenderGPUFrameTime * 1000 end)
		if okC then table.insert(cpu, vC) end
		if okG then table.insert(gpu, vG) end
		if focused == nil then unknown += 1 elseif focused == false then unfocused += 1 end
	end)
	while os.clock() - t0 < seconds do task.wait(0.1) end
	c:Disconnect()
	return { label = label, frames = dist(frames), cpu = dist(cpu), gpu = dist(gpu) }
end

local cam = workspace.CurrentCamera
local saved = { Type = cam.CameraType, Frame = cam.CFrame, FOV = cam.FieldOfView }
local frame = CFrame.lookAt(args.Eye, args.Target)
Run:BindToRenderStep("AsuraSliceAB", Enum.RenderPriority.Last.Value + 50, function()
	cam.CameraType = Enum.CameraType.Scriptable cam.FieldOfView = 70 cam.CFrame = frame
end)
local results = {}
local ok, err = pcall(function()
	for _ = 1, rounds do
		table.insert(results, sample("present"))
		hide()
		table.insert(results, sample("hidden"))
		show()
	end
end)
show()
Run:UnbindFromRenderStep("AsuraSliceAB")
cam.CameraType, cam.CFrame, cam.FieldOfView = saved.Type, saved.Frame, saved.FOV
fa:Disconnect() fb:Disconnect()
stash:Destroy()
assert(ok, err)
return game:GetService("HttpService"):JSONEncode({ kind = "Mac Studio client A/B diagnostic; not acceptance",
	eye = tostring(args.Eye), target = tostring(args.Target), seconds = seconds, unknownFocusFrames = unknown,
	unfocusedFrames = unfocused, quality = tostring(settings().Rendering.QualityLevel), results = results })

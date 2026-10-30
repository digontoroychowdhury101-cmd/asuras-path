-- Unmapped Studio-only capture capability probe. Use in PlayerScripts during Play; it records
-- the real viewport for eight seconds. No scene, camera, HUD, quality or combat overrides.
assert(game:GetService("RunService"):IsStudio(), "local Studio QA only")
local capture = game:GetService("CaptureService")
local Http = game:GetService("HttpService")
local state = { kind = "native CaptureService running-client video", events = {} }
local value = nil
local links = {}
local control = Instance.new("BindableFunction")
control.Name = "Result"
control.OnInvoke = function(op)
	if op == "Capture" then return value end
	return Http:JSONEncode(state)
end
control.Parent = script
local function event(name, kind)
	table.insert(state.events, { name = name, kind = tostring(kind), clock = os.clock() })
end
table.insert(links, capture.CaptureBegan:Connect(function(kind) event("began", kind) end))
table.insert(links, capture.CaptureEnded:Connect(function(kind) event("ended", kind) end))
local ok, result = pcall(function()
	return capture:StartVideoCaptureAsync(function(status, video)
		state.result, value = tostring(status), video
		if video then state.seconds, state.localId = video.TimeLength, video.LocalId end
		state.callback = true
	end, {})
end)
state.start = tostring(result)
state.startSucceeded = ok
script:SetAttribute("Ready", true)
if ok and result == Enum.VideoCaptureStartedResult.Success then
	task.wait(8)
	local stopped, err = pcall(function() capture:StopVideoCapture() end)
	state.stopSucceeded = stopped
	if not stopped then state.stopError = tostring(err) end
	local deadline = os.clock() + 20
	repeat task.wait(.1) until state.callback or os.clock() > deadline
end
for _, link in links do link:Disconnect() end
state.finished = true
script:SetAttribute("Finished", true)

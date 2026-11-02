--!nonstrict
-- Unmapped Studio-only probe (combat recovery Stage 2). Insert into PlayerScripts during Play with
-- tools/qa/qa_inject.py (never save). For SECONDS it records, on the client:
--   * every rendered frame's dt and whether the Roblox window had focus (WindowFocused/Released);
--   * every combat press (M1, V, F, Q, LeftShift) with os.clock and Workspace:GetServerTimeNow();
--   * the first frame on which a new Action-priority track starts on the local character;
--   * every AsuraAck / AsuraResult change as it arrives.
-- The JSON log lands in the LocalPlayer attribute AsuraStage2Probe. Evidence type: seeded Studio
-- diagnostic (inputs come from Studio's input injection or a person, never from remotes).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
local SECONDS = tonumber(player:GetAttribute("AsuraStage2Seconds")) or 30
local KEYS = { [Enum.KeyCode.V] = "Heavy", [Enum.KeyCode.F] = "F", [Enum.KeyCode.Q] = "Dash", [Enum.KeyCode.LeftShift] = "Dash" }
local t0 = os.clock()
local frames, presses, starts, acks = {}, {}, {}, {}
local focused = true
local seen: { [AnimationTrack]: boolean } = {}

player:SetAttribute("AsuraStage2Probe", nil)
local connections = {}
table.insert(connections, UserInputService.WindowFocused:Connect(function() focused = true end))
table.insert(connections, UserInputService.WindowFocusReleased:Connect(function() focused = false end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	local kind = if input.UserInputType == Enum.UserInputType.MouseButton1 then "Light" else KEYS[input.KeyCode]
	if kind then
		table.insert(presses, { kind = kind, t = os.clock() - t0, s = Workspace:GetServerTimeNow(), processed = processed })
	end
end))
for _, name in { "AsuraAck", "AsuraResult", "AsuraIntent" } do
	table.insert(connections, player:GetAttributeChangedSignal(name):Connect(function()
		table.insert(acks, { name = name, value = tostring(player:GetAttribute(name)), t = os.clock() - t0, s = Workspace:GetServerTimeNow() })
	end))
end

local function finish()
	for _, c in connections do
		c:Disconnect()
	end
	player:SetAttribute("AsuraStage2Probe", HttpService:JSONEncode({ frames = frames, presses = presses, starts = starts, acks = acks }))
end

table.insert(connections, RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - t0
	if t > SECONDS then
		finish()
		return
	end
	table.insert(frames, { dt = math.floor(dt * 1e5) / 100, f = focused })
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local now = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		now[track] = true
		if not seen[track] and track.Priority.Value >= Enum.AnimationPriority.Action.Value then
			table.insert(starts, { t = t, s = Workspace:GetServerTimeNow(), id = string.match(track.Animation.AnimationId, "%d+$") or "?",
				speed = math.floor(track.Speed * 100) / 100, pos = math.floor(track.TimePosition * 1000) })
		end
	end
	seen = now
end))

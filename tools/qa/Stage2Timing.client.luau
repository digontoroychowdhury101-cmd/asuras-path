--!nonstrict
-- Unmapped Studio-only probe (combat recovery Stage 2; ID correlation added in the closure pass). Insert into
-- PlayerScripts during Play with tools/qa/qa_inject.py (never save). For SECONDS it records, on the client:
--   * every rendered frame's dt and whether the Roblox window had focus (WindowFocused/Released);
--   * every combat press (M1, V, F, Q, LeftShift) with os.clock;
--   * LocalPrediction's trace (enabled here, off in play): Sent / Predicted / Unpredicted / Confirmed / Ended /
--     RolledBack / Occurrence records, each naming the intent seq, so a press is tied to its intent by ID;
--   * per frame, the right hand's offset from the root and the root's position, from which the report finds
--     the first frame the pose changed and the first frame the body moved after each press;
--   * the first frame a new Action-priority track is playing (the Stage 2 "track start" proxy);
--   * every AsuraAck / AsuraResult / AsuraIntent change as it arrives.
-- Each per-frame reading is taken on RenderStepped, before that frame renders: "first frame showing X" excludes
-- render and display latency. JSON lands in the LocalPlayer attribute AsuraStage2Probe. Evidence type: seeded
-- Studio diagnostic (inputs come from Studio's input injection or a person, never from remotes).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not RunService:IsStudio() then
	return
end
local Prediction = require(ReplicatedStorage.AsurasPath.Simulation.LocalPrediction)

local player = Players.LocalPlayer
local SECONDS = tonumber(player:GetAttribute("AsuraStage2Seconds")) or 30
local KEYS = { [Enum.KeyCode.V] = "Heavy", [Enum.KeyCode.F] = "Deflect", [Enum.KeyCode.Q] = "Dash", [Enum.KeyCode.LeftShift] = "Dash" }
local t0 = os.clock()
local frames, presses, starts, acks, poses = {}, {}, {}, {}, {}
local focused = true
local seen: { [AnimationTrack]: boolean } = {}

local trace = Prediction.Trace
table.clear(trace.Records)
trace.Enabled = true

player:SetAttribute("AsuraStage2Probe", nil)
local connections = {}
table.insert(connections, UserInputService.WindowFocused:Connect(function() focused = true end))
table.insert(connections, UserInputService.WindowFocusReleased:Connect(function() focused = false end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	local kind = if input.UserInputType == Enum.UserInputType.MouseButton1 then "Light" else KEYS[input.KeyCode]
	if kind then
		table.insert(presses, { kind = kind, t = os.clock() - t0, processed = processed })
	end
end))
for _, name in { "AsuraAck", "AsuraResult", "AsuraIntent" } do
	table.insert(connections, player:GetAttributeChangedSignal(name):Connect(function()
		table.insert(acks, { name = name, value = tostring(player:GetAttribute(name)), t = os.clock() - t0 })
	end))
end

local function finish()
	for _, c in connections do
		c:Disconnect()
	end
	trace.Enabled = false
	local records = {}
	for _, r in trace.Records do
		table.insert(records, { seq = r.seq, e = r.e, d = r.d, t = r.t - t0 })
	end
	table.clear(trace.Records)
	player:SetAttribute("AsuraStage2Probe", HttpService:JSONEncode({
		version = 2, frames = frames, presses = presses, starts = starts, acks = acks, trace = records, poses = poses,
	}))
end

local function round(v: number): number
	return math.floor(v * 1000 + 0.5) / 1000
end

table.insert(connections, RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - t0
	if t > SECONDS then
		finish()
		return
	end
	table.insert(frames, { dt = math.floor(dt * 1e5) / 100, f = focused })
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if root and hand then
		local offset = root.CFrame:PointToObjectSpace(hand.Position)
		local p = root.Position
		-- The foot channel (Stage 3) is what a dodge moves: its hand barely leaves the root.
		local foot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
		local down = if foot then root.CFrame:PointToObjectSpace(foot.Position) else Vector3.zero
		table.insert(poses, { t = round(t), h = { round(offset.X), round(offset.Y), round(offset.Z) }, r = { round(p.X), round(p.Z) },
			f = { round(down.X), round(down.Y), round(down.Z) } })
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local now = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		now[track] = true
		if not seen[track] and track.Priority.Value >= Enum.AnimationPriority.Action.Value then
			table.insert(starts, { t = t, id = string.match(track.Animation.AnimationId, "%d+$") or "?",
				speed = math.floor(track.Speed * 100) / 100, pos = math.floor(track.TimePosition * 1000) })
		end
	end
	seen = now
end))

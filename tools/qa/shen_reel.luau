--!nonstrict
-- Studio-only QA reel of Grandmaster Shen, run in the Client datamodel of a play session through the Studio MCP (execute_luau),
-- after the probe place (tools/qa/ShenProbe.server.luau) has spawned him and held his AI. Never shipped, never mapped.
-- It installs _G.ShenReel; then:
--   _G.ShenReel.live(seconds, title)  frames the real boss (and the player) with a scripted camera; the AI keeps fighting.
--   _G.ShenReel.catalogue(phase)       hides the live boss, clones him client-side (skin, BossCloth session and all) and
--                                      plays every clip of that phase: loops orbiting at 1x, the rest at 1x then 0.5x from the side.
-- A caption names each clip; validator FIX clips are marked. Progress: LocalPlayer attribute ShenReelState.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local FIX = { -- validator problems still open (assets/animations/opening_cast/shen/manifest.json)
	GrandmasterShen_P1_DeathblowVictim = "weapon through chest", GrandmasterShen_P1_Flourish = "weapon through head",
	GrandmasterShen_P1_FlowingJian = "wrist over 115 deg", GrandmasterShen_P1_RunForward = "validator flag",
	GrandmasterShen_P2_CrimsonEmbrace = "wrist over 115 deg", GrandmasterShen_P2_Guandao_Art = "wrist over 115 deg",
	GrandmasterShen_P2_RendingArc = "wrist over 115 deg",
}
local ORDER = { "Idle", "WalkForward", "WalkBackward", "StrafeLeft", "StrafeRight", "TurnLeft", "TurnRight", "RunForward", "GuardLoop",
	"Guandao_L1", "Guandao_L2", "Guandao_L3", "Guandao_Heavy", "Guandao_Art", "Guandao_Running", "Strike", "Feint", "Flourish" }
local LATE = { GuardHit = 1, HitLightFront = 2, HitLightBack = 3, HitLightLeft = 4, HitLightRight = 5, PostureBreak = 6, Transform = 7, DeathblowVictim = 8, Death = 9 }

local R = {}
_G.ShenReel = R
local shot = { Kind = "none" }
local gui, caption, sub, bar, flag

local function state(s) lp:SetAttribute("ShenReelState", s) end

local function boss()
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("AsuraLookKey") == "GrandmasterShen" and d:FindFirstChild("AsuraBossSkin") and d.Name ~= "ShenReelClone" then return d end
	end
	return nil
end

local hiddenGuis = {}
local function ui()
	if gui and gui.Parent then return end
	local pg = lp:WaitForChild("PlayerGui")
	for _, g in pg:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "ShenReelGui" then g.Enabled = false; table.insert(hiddenGuis, g) end
	end
	gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.DisplayOrder, gui.ResetOnSpawn = "ShenReelGui", true, 1000, false
	local panel = Instance.new("Frame")
	panel.BackgroundColor3, panel.BackgroundTransparency, panel.BorderSizePixel = Color3.new(0, 0, 0), 0.35, 0
	panel.Position, panel.Size = UDim2.fromOffset(24, 72), UDim2.fromOffset(640, 86)
	panel.Parent = gui
	local function label(y, size, bold)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency, t.TextColor3, t.TextXAlignment = 1, Color3.new(1, 1, 1), Enum.TextXAlignment.Left
		t.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
		t.TextSize, t.Position, t.Size = size, UDim2.fromOffset(14, y), UDim2.new(1, -28, 0, size + 4)
		t.Text, t.Parent = "", panel
		return t
	end
	caption, sub = label(8, 26, true), label(40, 18, false)
	flag = label(62, 16, true)
	flag.TextColor3 = Color3.fromRGB(255, 120, 90)
	local track = Instance.new("Frame")
	track.BackgroundColor3, track.BackgroundTransparency, track.BorderSizePixel = Color3.new(0, 0, 0), 0.5, 0
	track.AnchorPoint, track.Position, track.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -18), UDim2.new(0.6, 0, 0, 6)
	track.Parent = gui
	bar = Instance.new("Frame")
	bar.BackgroundColor3, bar.BorderSizePixel, bar.Size = Color3.fromRGB(230, 190, 110), 0, UDim2.fromScale(0, 1)
	bar.Parent = track
	gui.Parent = pg
	pcall(function() game:GetService("ProximityPromptService").Enabled = false end)
end

local function say(title, line, warn, progress)
	ui()
	caption.Text, sub.Text, flag.Text = title, line or "", warn and ("validator: " .. warn) or ""
	bar.Size = UDim2.fromScale(progress or 0, 1)
end

-- One camera driver for every shot; shot.Kind picks the framing.
local camConn
local function camera()
	if camConn then return end
	camConn = RunService.RenderStepped:Connect(function(dt)
		local me = lp.Character
		if shot.HidePlayer and me then
			for _, d in me:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 1 end end
		end
		if shot.Kind == "none" then return end
		cam.CameraType = Enum.CameraType.Scriptable
		local root = shot.Root
		if not root or not root.Parent then return end
		if shot.Kind == "orbit" then
			shot.Angle += (shot.Spin or 0) * dt
			local cf = shot.Base
			local focus = cf.Position + Vector3.new(0, shot.Lift, 0)
			local a = math.rad(shot.Angle)
			local dir = cf.LookVector * math.cos(a) + cf.RightVector * math.sin(a)
			cam.CFrame = CFrame.lookAt(focus + dir * shot.Dist + Vector3.new(0, shot.Height, 0), focus)
		elseif shot.Kind == "duel" then
			local a = root.Position
			local b = me and me:FindFirstChild("HumanoidRootPart") and me.HumanoidRootPart.Position or a
			local mid = (a + b) / 2
			local span = math.max((a - b).Magnitude, 8)
			local axis = (b - a) * Vector3.new(1, 0, 1)
			axis = if axis.Magnitude > 0.1 then axis.Unit else Vector3.zAxis
			local side = axis:Cross(Vector3.yAxis)
			local want = mid + side * (span * 0.9 + 14) + Vector3.new(0, 5, 0) - axis * 4
			shot.Pos = if shot.Pos then shot.Pos:Lerp(want, math.min(1, dt * 2)) else want
			cam.CFrame = CFrame.lookAt(shot.Pos, mid + Vector3.new(0, 2, 0))
		end
	end)
end

-- Real fight footage: the live boss, real AI, real controllers.
function R.live(seconds, title)
	local b = boss()
	if not b then return "no boss" end
	camera()
	shot = { Kind = "duel", Root = b:FindFirstChild("HumanoidRootPart"), HidePlayer = false }
	if lp.Character then
		for _, d in lp.Character:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end end
	end
	state("live")
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < seconds do
			local phase = b:GetAttribute("AsuraBossPhase")
			say("GRANDMASTER SHEN · LIVE FIGHT", string.format("Phase %s · real AI, real cloth · now: %s", tostring(phase),
				(string.gsub(tostring(b:GetAttribute("AsuraAnimationPlaying") or "-"), "|.*", ""))), nil, (os.clock() - t0) / seconds)
			task.wait(0.1)
		end
		state("live done")
	end)
	return "live started"
end

local function hide(model, on)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = if on then 1 else 0
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("BillboardGui") then
			if on and d.Enabled then d:SetAttribute("ShenReelOff", true); d.Enabled = false
			elseif not on and d:GetAttribute("ShenReelOff") then d:SetAttribute("ShenReelOff", nil); d.Enabled = true end
		end
	end
end

local function rank(slot)
	local short = string.match(slot, "_P%d_(.+)$")
	for i, k in ORDER do if k == short then return i end end
	if LATE[short] then return 100 + LATE[short] end
	return 50
end

function R.catalogue(phase)
	local b = boss()
	if not b then return "no boss" end
	local skin = b:FindFirstChild("AsuraBossSkin")
	local want = "AsuraBoss_GrandmasterShen_P" .. phase
	if not skin or skin:GetAttribute("Template") ~= want then return "boss skin is " .. tostring(skin and skin:GetAttribute("Template")) end
	local prefix = "GrandmasterShen_P" .. phase .. "_"
	local slots = {}
	for k, v in b:GetAttributes() do
		local slot = string.match(k, "^AsuraBossAnimation_(.+)$")
		if slot and string.sub(slot, 1, #prefix) == prefix and type(v) == "string" then table.insert(slots, { Slot = slot, Id = v }) end
	end
	table.sort(slots, function(x, y)
		local a, c = rank(x.Slot), rank(y.Slot)
		if a ~= c then return a < c end
		return x.Slot < y.Slot
	end)
	b.Archivable = true
	local old = workspace:FindFirstChild("ShenReelClone")
	if old then old:Destroy() end
	local c = b:Clone()
	c.Name = "ShenReelClone"
	for _, d in c:GetDescendants() do
		if d:IsA("LocalScript") or d:IsA("Script") then d:Destroy()
		elseif d:IsA("BasePart") then d.CanCollide, d.CanQuery, d.CanTouch = false, false, false end
	end
	local root = c:FindFirstChild("HumanoidRootPart")
	local hum = c:FindFirstChildOfClass("Humanoid")
	local base = b.HumanoidRootPart.CFrame
	base = CFrame.new(base.Position) * CFrame.Angles(0, select(2, base:ToEulerAnglesYXZ()), 0)
	root.Anchored = true
	c:PivotTo(c:GetPivot() * (root.CFrame:Inverse() * base))
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end
	c.Parent = workspace
	hide(b, true)
	camera()
	local size = c:GetExtentsSize()
	local h = math.min(size.Y, 12)
	local tracks = {}
	for _, s in slots do
		local a = Instance.new("Animation")
		a.AnimationId = s.Id
		s.Track = animator:LoadAnimation(a)
		tracks[s.Slot] = s.Track
	end
	local t0 = os.clock()
	while os.clock() - t0 < 10 do
		local ready = true
		for _, s in slots do if s.Track.Length <= 0 then ready = false end end
		if ready then break end
		task.wait(0.1)
	end
	local idle = tracks[prefix .. "Idle"]
	state("catalogue " .. phase .. " 0/" .. #slots)
	task.spawn(function()
		local function frame(angle, spin, dist)
			shot = { Kind = "orbit", Root = root, Base = base, Angle = angle, Spin = spin, Dist = dist or h * 1.55, Lift = h * 0.02, Height = h * 0.18, HidePlayer = true }
		end
		-- Opening turnaround on the idle.
		if idle then idle.Priority = Enum.AnimationPriority.Core; idle.Looped = true; idle:Play(0.2) end
		frame(30, 36)
		for i = 1, 100 do
			say(string.format("GRANDMASTER SHEN · PHASE %d", phase), "Turnaround on idle: model, cloth, weapon, hair", nil, i / 100)
			task.wait(0.1)
		end
		for n, s in slots do
			local short = string.match(s.Slot, "_P%d_(.+)$")
			local tr = s.Track
			local len = tr.Length
			local loop = rank(s.Slot) <= 9
			tr.Priority = Enum.AnimationPriority.Action4
			state(string.format("catalogue %d %d/%d %s", phase, n, #slots, short))
			local function play(speed, label, angle, spin, seconds)
				frame(angle, spin)
				tr.Looped = loop
				tr:Play(0.12, 1, speed)
				local start = os.clock()
				while os.clock() - start < seconds do
					local p = tr.IsPlaying and (tr.TimePosition / math.max(len, 0.01)) or 1
					say(string.format("P%d · %d/%d · %s", phase, n, #slots, short), string.format("%s · %.2fs clip · %s", label, len, if loop then "loop" else "one-shot"), FIX[s.Slot], p)
					task.wait(1 / 30)
				end
			end
			if short == "Idle" then
				play(1, "1x, orbit", 20, 40, math.max(len, 6))
			elseif loop then
				play(1, "1x, orbit", 25, 360 / math.max(len * 2, 6), math.max(len * 2, 6))
			else
				play(1, "1x, front three-quarter", 35, 0, len / 1 + 0.5)
				tr:Stop(0.1)
				task.wait(0.25)
				play(0.5, "0.5x, side", -80, 0, len / 0.5 + 0.5)
			end
			tr:Stop(0.15)
			task.wait(0.3)
		end
		if idle then idle:Stop(0.2) end
		state("catalogue " .. phase .. " done")
	end)
	return string.format("catalogue %d: %d clips, height %.1f", phase, #slots, h)
end

-- The whole reel in one unattended pass. The server half (ReplicatedStorage.ShenReelRemote, wired by the MCP server
-- thread to the probe's ShenQACmd) releases or holds the AI and triggers the phase change on cue.
local function server(cmd)
	local remote = game:GetService("ReplicatedStorage"):FindFirstChild("ShenReelRemote")
	if remote then remote:FireServer(cmd) end
end
local function waitState(pattern, limit)
	local t0 = os.clock()
	while os.clock() - t0 < limit do
		if string.find(tostring(lp:GetAttribute("ShenReelState")), pattern) then return true end
		task.wait(0.2)
	end
	return false
end
function R.run(liveSeconds)
	liveSeconds = liveSeconds or 25
	task.spawn(function()
		state("run start")
		local b = boss()
		say("GRANDMASTER SHEN · MOVEMENT REEL", "Studio play, real skin and cloth · live fight, then every clip", nil, 0)
		task.wait(3)
		server("hold 0")
		R.live(liveSeconds)
		waitState("live done", liveSeconds + 5)
		server("hold 99999")
		task.wait(1.5)
		R.catalogue(1)
		waitState("catalogue 1 done", 600)
		R.restore()
		R.live(18)
		task.wait(2)
		server("damage 0")
		waitState("live done", 25)
		local t0 = os.clock()
		while os.clock() - t0 < 20 do
			b = boss()
			local skin = b and b:FindFirstChild("AsuraBossSkin")
			if skin and skin:GetAttribute("Template") == "AsuraBoss_GrandmasterShen_P2" then break end
			task.wait(0.2)
		end
		server("hold 0")
		R.live(liveSeconds)
		waitState("live done", liveSeconds + 5)
		server("hold 99999")
		task.wait(1.5)
		local ok = R.catalogue(2)
		if string.find(ok, "^catalogue") then waitState("catalogue 2 done", 600) end
		R.restore()
		say("GRANDMASTER SHEN · END OF REEL", "Live fight, phase change and all clips of both forms", nil, 1)
		task.wait(3)
		state("run done")
	end)
	return "reel running"
end

-- Put the live boss back and hand the camera back to the game.
function R.restore()
	local c = workspace:FindFirstChild("ShenReelClone")
	if c then c:Destroy() end
	local b = boss()
	if b then hide(b, false) end
	shot = { Kind = "none" }
	cam.CameraType = Enum.CameraType.Custom
	state("restored")
	return "restored"
end

function R.finish()
	R.restore()
	if camConn then camConn:Disconnect(); camConn = nil end
	if gui then gui:Destroy(); gui = nil end
	for _, g in hiddenGuis do g.Enabled = true end
	table.clear(hiddenGuis)
	return "finished"
end

return "ShenReel installed"

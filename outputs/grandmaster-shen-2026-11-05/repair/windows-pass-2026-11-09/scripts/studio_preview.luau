--!nonstrict
-- studio_preview.luau (Windows pass 2026-11-10): Studio-only local playback check of exported Shen clips. Never shipped, never mapped.
-- Runs in the Client datamodel of a play session through the Studio MCP, after tools/qa/ShenProbe.server.luau has spawned and held him.
-- Clips load from Studio's own content folder (content/shenpreview/<clip>.rbxmx, game:GetObjects) and register locally
-- (AnimationClipProvider:RegisterAnimationClip): nothing is uploaded. ShenExpected.rbxmx (studio_expected.py) holds the solver's frames.
--   SP.clone()        a client copy of the live boss: his skin, cloth tag and rig pivots. Humanoid auto-scaling is off before parenting
--                     (it reset the custom pivots to stock R15 ones), and the live rig's attachments and limb sizes are copied back as a check.
--   SP.calibrate()    the rest pose (every joint Transform zero) in root space, rig units.
--   SP.measure(clip)  plays the clip paused at every solver frame time and compares each limb, the glaive (and points 2.5 out along
--                     its axes) with solver world * rest: the engine's playback of the export against what was validated.
--   SP.run(list)      measure in the background (SP.progress, SP.results).
--   SP.shot(clip, t)  plays the clip at 1x over the idle, freezes it at t, frames a scripted camera (SP.view) for screen_capture.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local ACP = game:GetService("AnimationClipProvider")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local SP = _G.SP or {}
_G.SP = SP
SP.ids, SP.kfs, SP.results = SP.ids or {}, SP.kfs or {}, SP.results or {}

function SP.load(n)
	if SP.ids[n] then return SP.ids[n] end
	local k = game:GetObjects("rbxasset://shenpreview/" .. n .. ".rbxmx")[1]
	SP.kfs[n] = k
	SP.ids[n] = ACP:RegisterAnimationClip(k)
	return SP.ids[n]
end

function SP.boss()
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("AsuraLookKey") == "GrandmasterShen" and d:FindFirstChild("AsuraBossSkin") and d.Name ~= "ShenPreviewClone" and d.Name ~= "ShenReelClone" then return d end
	end
	return nil
end

function SP.hide(model, on)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = if on then 1 else 0
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("BillboardGui") then
			if on and d.Enabled then d:SetAttribute("SPOff", true); d.Enabled = false
			elseif not on and d:GetAttribute("SPOff") then d:SetAttribute("SPOff", nil); d.Enabled = true end
		end
	end
end

local function path(inst, root)
	local parts = {}
	while inst and inst ~= root do table.insert(parts, 1, inst.Name) inst = inst.Parent end
	return parts
end
local function find(root, parts)
	local cur = root
	for _, n in parts do cur = cur and cur:FindFirstChild(n) if not cur then return nil end end
	return cur
end

function SP.compare(live, c)
	local nAtt, nDiff, maxd, nSize, maxs = 0, 0, 0, 0, 0
	for _, d in live:GetDescendants() do
		if d:IsA("Attachment") and not d:IsDescendantOf(live.AsuraBossSkin) then
			local twin = find(c, path(d, live))
			if twin then
				nAtt += 1
				local dd = (twin.CFrame.Position - d.CFrame.Position).Magnitude + (twin.CFrame.LookVector - d.CFrame.LookVector).Magnitude
				if dd > 1e-4 then nDiff += 1 maxd = math.max(maxd, dd) end
			end
		elseif d:IsA("BasePart") and d.Parent == live then
			local twin = c:FindFirstChild(d.Name)
			if twin then
				local ds = (twin.Size - d.Size).Magnitude
				if ds > 1e-4 then nSize += 1 maxs = math.max(maxs, ds) end
			end
		end
	end
	return string.format("attachments %d differ %d (max %.4f); limb sizes differ %d (max %.4f)", nAtt, nDiff, maxd, nSize, maxs)
end

function SP.clone(groundY)
	local b = SP.boss()
	if not b then return "no boss" end
	b.Archivable = true
	local old = workspace:FindFirstChild("ShenPreviewClone")
	if old then old:Destroy() end
	local c = b:Clone()
	c.Name = "ShenPreviewClone"
	for _, d in c:GetDescendants() do
		if d:IsA("LocalScript") or d:IsA("Script") then d:Destroy()
		elseif d:IsA("BasePart") then d.CanCollide, d.CanQuery, d.CanTouch = false, false, false end
	end
	local root = c:FindFirstChild("HumanoidRootPart")
	local hum = c:FindFirstChildOfClass("Humanoid")
	hum.AutomaticScalingEnabled = false
	local base = b.HumanoidRootPart.CFrame
	base = CFrame.new(base.Position.X, groundY or base.Position.Y, base.Position.Z) * CFrame.Angles(0, select(2, base:ToEulerAnglesYXZ()), 0)
	root.Anchored = true
	c:PivotTo(c:GetPivot() * (root.CFrame:Inverse() * base))
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0) end
	c.Parent = workspace
	for _ = 1, 3 do RunService.Heartbeat:Wait() end
	local after = SP.compare(b, c)
	for _, d in b:GetDescendants() do
		if d:IsA("Attachment") and not d:IsDescendantOf(b.AsuraBossSkin) then
			local twin = find(c, path(d, b))
			if twin then twin.CFrame = d.CFrame end
		elseif d:IsA("BasePart") and d.Parent == b then
			local twin = c:FindFirstChild(d.Name)
			if twin and (twin.Size - d.Size).Magnitude > 1e-4 then twin.Size = d.Size end
		end
	end
	SP.hide(b, true)
	SP.c, SP.root, SP.animator, SP.base, SP.scale, SP.live = c, root, animator, base, c:GetScale(), b
	return string.format("clone scale %.3f skin %s | rig vs live after parenting: %s", SP.scale, tostring(c.AsuraBossSkin:GetAttribute("Template")), after)
end

function SP.calibrate()
	for _, t in SP.animator:GetPlayingAnimationTracks() do t:Stop(0) end
	for _, d in SP.c:GetDescendants() do
		if d:IsA("AnimationConstraint") or d:IsA("Motor6D") then d.Transform = CFrame.identity end
	end
	for _ = 1, 4 do RunService.Heartbeat:Wait() end
	local rc = SP.root.CFrame
	SP.rest = {}
	for _, p in SP.c:GetChildren() do
		if p:IsA("BasePart") then
			local cf = rc:ToObjectSpace(p.CFrame)
			SP.rest[p.Name] = CFrame.new(cf.Position / SP.scale) * cf.Rotation
		end
	end
	local function at(limb)
		local part = SP.c:FindFirstChild(limb)
		local con = part and part:FindFirstChild(limb == "Glaive" and "Glaive" or "RightShoulder")
		if not con then return "-" end
		local p = rc:PointToObjectSpace(con.Attachment1.WorldPosition) / SP.scale
		return string.format("(%.3f %.3f %.3f)", p.X, p.Y, p.Z)
	end
	return "rest taken; RightShoulder pivot " .. at("RightUpperArm") .. ", Glaive pivot " .. at("Glaive")
end

local function angle(a, b)
	local c = (a[1]*b[1] + a[2]*b[2] + a[3]*b[3] + a[4]*b[4] + a[5]*b[5] + a[6]*b[6] + a[7]*b[7] + a[8]*b[8] + a[9]*b[9] - 1) / 2
	return math.deg(math.acos(math.clamp(c, -1, 1)))
end

function SP.measure(n)
	SP.expected = SP.expected or game:GetObjects("rbxasset://shenpreview/ShenExpected.rbxmx")[1]
	local id = SP.load(n)
	local ev = SP.expected:FindFirstChild(n)
	if not ev then return n .. ": no expected data" end
	local exp = Http:JSONDecode(ev.Value)
	local a = Instance.new("Animation")
	a.AnimationId = id
	local tr = SP.animator:LoadAnimation(a)
	tr.Priority = Enum.AnimationPriority.Action4
	tr.Looped = false
	tr:Play(0, 1, 0)
	local t0 = os.clock()
	while tr.Length <= 0 and os.clock() - t0 < 5 do task.wait() end
	local len = tr.Length
	RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait()
	local worst, rot = {}, {}
	local s = SP.scale
	for i, row in exp do
		tr.TimePosition = math.min(row[1], len - 0.0005)
		RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait()
		local rc = SP.root.CFrame
		for p, e in row[2] do
			local part = SP.c:FindFirstChild(p)
			local rest = SP.rest[p]
			if part and rest then
				local cf = rc:ToObjectSpace(part.CFrame)
				cf = CFrame.new(cf.Position / s) * cf.Rotation
				local W = CFrame.new(e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9], e[10], e[11], e[12])
				local want = W * rest
				local d = (cf.Position - want.Position).Magnitude
				if p == "Glaive" then
					local cols = { cf.RightVector, cf.UpVector, -cf.LookVector }
					local wcols = { want.RightVector, want.UpVector, -want.LookVector }
					for k = 1, 3 do
						for _, sg in { 2.5, -2.5 } do d = math.max(d, ((cf.Position + cols[k] * sg) - (want.Position + wcols[k] * sg)).Magnitude) end
					end
				end
				local _, _, _, a00, a01, a02, a10, a11, a12, a20, a21, a22 = cf:GetComponents()
				local _, _, _, b00, b01, b02, b10, b11, b12, b20, b21, b22 = want:GetComponents()
				local ang = angle({ a00, a01, a02, a10, a11, a12, a20, a21, a22 }, { b00, b01, b02, b10, b11, b12, b20, b21, b22 })
				if not worst[p] or d > worst[p][1] then worst[p] = { d, i - 1 } end
				if not rot[p] or ang > rot[p][1] then rot[p] = { ang, i - 1 } end
			end
		end
	end
	tr:Stop(0)
	tr:Destroy()
	local parts, big = {}, 0
	local order = { "RightHand", "LeftHand", "Glaive", "RightLowerArm", "LeftLowerArm", "UpperTorso", "LowerTorso", "Head", "RightFoot", "LeftFoot" }
	local extra = {}     -- (2026-11-11) and any other part the expected data carries (studio_expected.py LEGS=1: the thighs and shins), by name
	for p in worst do
		if not table.find(order, p) then table.insert(extra, p) end
	end
	table.sort(extra)
	for _, p in extra do table.insert(order, p) end
	for _, p in order do
		if worst[p] then
			big = math.max(big, worst[p][1])
			table.insert(parts, string.format("%s %.4f f%d %.2fdeg", p, worst[p][1], worst[p][2], rot[p][1]))
		end
	end
	local line = string.format("%s len %.3f/%.3f frames %d kfs %d max %.4f | %s", n, len, exp[#exp][1], #exp, #SP.kfs[n]:GetKeyframes(), big, table.concat(parts, "; "))
	SP.results[n] = line
	return line
end

function SP.run(list)
	SP.progress = "running 0/" .. #list
	task.spawn(function()
		for i, n in list do
			local ok, res = pcall(SP.measure, n)
			if not ok then SP.results[n] = n .. ": ERR " .. tostring(res) end
			SP.progress = string.format("running %d/%d", i, #list)
		end
		SP.progress = "done " .. #list
	end)
	return "started"
end

SP.view = SP.view or { angle = 30, dist = 9, height = 1.0, lift = 0.3, follow = true }
function SP.camOn()
	if SP.camBound then return end
	SP.camBound = true
	SP.hiddenGuis = SP.hiddenGuis or {}
	for _, g in lp.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then g.Enabled = false; table.insert(SP.hiddenGuis, g) end
	end
	RunService:BindToRenderStep("ShenPreviewCam", Enum.RenderPriority.Last.Value, function()
		if not SP.c or not SP.c.Parent then return end
		cam.CameraType = Enum.CameraType.Scriptable
		local v = SP.view
		local ut = SP.c:FindFirstChild("UpperTorso")
		local frame = if v.follow and ut then ut.CFrame else SP.base
		local look = frame.LookVector * Vector3.new(1, 0, 1)
		look = if look.Magnitude > 0.1 then look.Unit else SP.base.LookVector
		local right = look:Cross(Vector3.yAxis)
		local fp = v.focus and SP.c:FindFirstChild(v.focus)
		local focus = (if fp then fp.Position elseif ut then ut.Position else SP.base.Position) + Vector3.new(0, v.lift, 0)
		local a = math.rad(v.angle)
		local dir = look * math.cos(a) + right * math.sin(a)
		cam.CFrame = CFrame.lookAt(focus + dir * v.dist + Vector3.new(0, v.height, 0), focus)
		local me = lp.Character
		if me then for _, d in me:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 1 end end end
	end)
end

function SP.camOff()
	if SP.camBound then RunService:UnbindFromRenderStep("ShenPreviewCam") SP.camBound = false end
	cam.CameraType = Enum.CameraType.Custom
	for _, g in SP.hiddenGuis or {} do g.Enabled = true end
	SP.hiddenGuis = {}
	local me = lp.Character
	if me then for _, d in me:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end end end
end

function SP.shot(n, t)
	SP.camOn()
	for _, tr in SP.animator:GetPlayingAnimationTracks() do tr:Stop(0) end
	local prefix = string.match(n, "^(GrandmasterShen_P%d_)")
	local ia = Instance.new("Animation")
	ia.AnimationId = SP.load(prefix .. "Idle")
	local idle = SP.animator:LoadAnimation(ia)
	idle.Priority, idle.Looped = Enum.AnimationPriority.Idle, true
	idle:Play(0)
	task.wait(1.0)
	local a = Instance.new("Animation")
	a.AnimationId = SP.load(n)
	local tr = SP.animator:LoadAnimation(a)
	tr.Priority, tr.Looped = Enum.AnimationPriority.Action, false
	tr:Play(0.1, 1, 1)
	while tr.IsPlaying and tr.TimePosition < t do RunService.Heartbeat:Wait() end
	tr:AdjustSpeed(0)
	SP.held = tr
	return string.format("%s frozen at %.3f (asked %.3f) of %.3f", n, tr.TimePosition, t, tr.Length)
end

return SP

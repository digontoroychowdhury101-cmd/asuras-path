--[[
=====================================================================
 SanguineVFXPreview.client.lua                         (LocalScript)
 Place in : StarterPlayer > StarterPlayerScripts
 Requires : ReplicatedStorage > SanguineVFX_Overhaul  (ModuleScript, untouched)

 Controls
   Z / Left-Click  3-hit Bloodflame combo (inputs are BUFFERED - every click swings)
   X  Sanguine Thrust        C  Bloodflame Ground Eruption
   V  Sekiro Deflect+Riposte B  Ground Telegraph Rune
   N  Blood Meteor Rain      M  Phase Transformation Burst
   Q  Dodge

 What changed vs. the old script
   * NEVER writes Motor6D.C0 / C1 (read-only on AnimationConstraint rigs).
     All posing goes through .Transform on Motor6D *or* AnimationConstraint.
   * No Animation assets, so no "Asset is not trusted for this place".
   * Only built-in rbxasset:// sounds (swordslash / swordlunge). No bad IDs.
   * Works on R6 and R15.
   * Every VFX call is wrapped in pcall; a missing/changed function prints
     ONE warning instead of killing the script.
=====================================================================
]]

----------------------------------------------------------------------
-- 0. SERVICES + CONFIG
----------------------------------------------------------------------
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")
local Workspace         = game:GetService("Workspace")

local player = Players.LocalPlayer

local CONFIG = {
	VFXQuality     = "High",
	DummyDistance  = 14,
	DummyHealth    = 4000,
	DummyRespawn   = 3.2,
	ComboReset     = 1.15,   -- seconds idle before the combo restarts at hit 1
	QueueLimit     = 6,      -- max buffered inputs
	AutoFaceRange  = 70,     -- soft lock-on toward the dummy
	StopDistance   = 5.2,    -- momentum stops this close to the dummy
	GripTilt       = 35,     -- degrees the blade is angled off the forearm
	ShakeScale     = 1,      -- multiplies every VFX.CameraShake intensity
	HitStop        = true,
	SoundsEnabled  = true,
	ImpactStyle    = nil,    -- passed to VFX.Impact (nil = module default)
	TelegraphStyle = nil,    -- passed to VFX.GroundTelegraph
	UseModuleTrail = true,   -- false = skip VFX.AttachWeaponTrail and use the slim built-in trail
	-- Built-in client sounds only (always valid). Paste your own IDs here if you like.
	Sounds = {
		Slash = "rbxasset://sounds/swordslash.wav",
		Heavy = "rbxasset://sounds/swordlunge.wav",
	},
	Damage = { C1 = 160, C2 = 220, C3 = 500, X = 450, C = 350, V = 260, B = 400, N = 580, M = 400 },
}
local DMG = CONFIG.Damage

----------------------------------------------------------------------
-- 1. SMALL HELPERS
----------------------------------------------------------------------
local AX, AY, AZ = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function safeUnit(v, fallback)
	if v.Magnitude < 1e-4 then return fallback end
	return v.Unit
end
local function isNaNCF(cf)
	local r = cf.RightVector
	return cf.X ~= cf.X or r.X ~= r.X or r.Y ~= r.Y or r.Z ~= r.Z
end

-- Rotation built explicitly as Ry * Rx * Rz (degrees). Applied to a hanging arm:
--   rx>0 swings the arm FORWARD, ry>0 sweeps it to the LEFT, rz>0 lifts it OUT to the right.
local function rot(rx, ry, rz)
	return CFrame.fromAxisAngle(AY, math.rad(ry))
		* CFrame.fromAxisAngle(AX, math.rad(rx))
		* CFrame.fromAxisAngle(AZ, math.rad(rz))
end

-- Shortest rotation taking unit vector a onto unit vector b.
local function aimRot(a, b)
	local d = a:Dot(b)
	if d > 0.99999 then return CFrame.identity end
	if d < -0.99999 then
		local axis = a:Cross(AX)
		if axis.Magnitude < 1e-3 then axis = a:Cross(AZ) end
		return CFrame.fromAxisAngle(axis.Unit, math.pi)
	end
	return CFrame.fromAxisAngle(a:Cross(b).Unit, math.acos(d))
end

-- Convert "rotate this limb by R in its PARENT's space" into the joint's Transform.
-- (Part1 = Part0 * C0 * Transform * C1^-1, so Transform = R0^-1 * R * R0.)
local function toTransform(joint, desired)
	local c0 = joint.C0
	local r0 = c0 - c0.Position
	return r0:Inverse() * desired * r0
end

local function setT(joint, T, w)
	if not joint then return end
	if w >= 0.995 then
		joint.Transform = T
	elseif w > 0.005 then
		joint.Transform = joint.Transform:Lerp(T, w)
	end
end

local EASE = {
	lin  = function(a) return a end,
	["in"] = function(a) return a * a * a end,
	out  = function(a) local b = 1 - a return 1 - b * b * b end,
	io   = function(a) return a * a * (3 - 2 * a) end,
}

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[Sanguine] " .. tostring(key) .. ": " .. tostring(msg))
end

----------------------------------------------------------------------
-- 2. VFX MODULE (safe wrappers)
----------------------------------------------------------------------
local VFX = nil
do
	local mod = ReplicatedStorage:WaitForChild("SanguineVFX_Overhaul", 10)
	if mod then
		local ok, res = pcall(require, mod)
		if ok then VFX = res else warn("[Sanguine] VFX module failed to load: " .. tostring(res)) end
	else
		warn("[Sanguine] ReplicatedStorage.SanguineVFX_Overhaul not found - visuals disabled")
	end
	if VFX and type(VFX.Init) == "function" then
		local ok, err = pcall(VFX.Init, CONFIG.VFXQuality)
		if not ok then warnOnce("VFX.Init", err) end
	end
end

local function vfx(name, ...)
	if not VFX then return false end
	local fn = VFX[name]
	if type(fn) ~= "function" then warnOnce(name, "not found in VFX module"); return false end
	local ok, err = pcall(fn, ...)
	if not ok then warnOnce(name, err) end
	return ok
end

----------------------------------------------------------------------
-- 3. POSES + KEYFRAMES  (angles in degrees, torso space)
--    lean/twist : upper-body pitch / yaw        rx,ry,rz : right shoulder
--    re         : right elbow bend (R15)         rw       : right wrist (R15)
--    st         : stride (right hip pitch)       cr       : crouch (knee bend)
--    The LEFT hand is solved by IK onto the sword handle, so it is never keyed.
----------------------------------------------------------------------
local POSE_KEYS = { "lean", "twist", "rx", "ry", "rz", "re", "rw", "st", "cr" }
local STANCE = { lean = 12, twist = -22, rx = 34, ry = -16, rz = 8, re = 78, rw = 0, st = -20, cr = 26 }

local function P(o)
	local p = {}
	for _, k in ipairs(POSE_KEYS) do
		local v = o and o[k]
		if v == nil then v = STANCE[k] end
		p[k] = v
	end
	return p
end
local function K(t, ease, o) return { t = t, ease = ease, pose = P(o) } end

local function samplePose(keys, t, out)
	local n = #keys
	if t <= keys[1].t then
		for _, k in ipairs(POSE_KEYS) do out[k] = keys[1].pose[k] end
		return
	end
	if t >= keys[n].t then
		for _, k in ipairs(POSE_KEYS) do out[k] = keys[n].pose[k] end
		return
	end
	local i = 1
	while keys[i + 1].t < t do i = i + 1 end
	local a, b = keys[i], keys[i + 1]
	local u = EASE[b.ease or "io"]((t - a.t) / (b.t - a.t))
	for _, k in ipairs(POSE_KEYS) do
		out[k] = a.pose[k] + (b.pose[k] - a.pose[k]) * u
	end
end

----------------------------------------------------------------------
-- 4. STATE
----------------------------------------------------------------------
local state = {
	char = nil, hum = nil, root = nil, rig = nil, sword = nil, lv = nil,
	alive = false, running = false, queue = {}, combo = 0, lastEnd = 0, baseWalk = 16,
	pose = {}, anim = nil, actW = 0, clock = 0, stopUntil = 0, surge = 0,
	conns = {}, poseErrors = 0,
}
for _, k in ipairs(POSE_KEYS) do state.pose[k] = STANCE[k] end

local dummy = nil   -- training dummy table (see section 8)
local hud   = nil   -- HUD table (see section 7)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundAt(pos)
	local ignore = {}
	if state.char then ignore[#ignore + 1] = state.char end
	if dummy and dummy.model then ignore[#ignore + 1] = dummy.model end
	rayParams.FilterDescendantsInstances = ignore
	local r = Workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -200, 0), rayParams)
	return r and r.Position or pos
end

local function sfx(kind, vol, pitch)
	if not CONFIG.SoundsEnabled or not state.root then return end
	local id = CONFIG.Sounds[kind]
	if not id or id == "" then return end
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = vol or 0.6
		s.PlaybackSpeed = pitch or 1
		s.RollOffMaxDistance = 150
		s.Parent = state.root
		s:Play()
		Debris:AddItem(s, 3)
	end)
end

local function shake(i, d, f) vfx("CameraShake", i * CONFIG.ShakeScale, d, f) end
local function hitstop(d)
	if CONFIG.HitStop then state.stopUntil = math.max(state.stopUntil, os.clock() + d) end
end

----------------------------------------------------------------------
-- 5. RIG BINDING + POSE APPLICATION (Motor6D *or* AnimationConstraint)
----------------------------------------------------------------------
local R15_JOINTS = {
	root = "Root", waist = "Waist",
	rs = "RightShoulder", re = "RightElbow", rw = "RightWrist",
	ls = "LeftShoulder", le = "LeftElbow", lw = "LeftWrist",
	rh = "RightHip", rk = "RightKnee", lh = "LeftHip", lk = "LeftKnee",
}
local R6_JOINTS = {
	root = "RootJoint", rs = "Right Shoulder", ls = "Left Shoulder",
	rh = "Right Hip", lh = "Left Hip",
}

local function findJoint(char, name)
	for _, d in ipairs(char:GetDescendants()) do
		if d.Name == name and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then
			return d
		end
	end
	return nil
end

local function buildRig(char, hum)
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local rig = { r15 = r15, J = {} }
	for key, name in pairs(r15 and R15_JOINTS or R6_JOINTS) do
		rig.J[key] = findJoint(char, name)
	end
	local need = r15 and { "waist", "rs", "re", "ls", "le", "lw" } or { "root", "rs", "ls" }
	for _, key in ipairs(need) do
		if not rig.J[key] then return nil, key end
	end
	rig.upper = r15 and char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	rig.grip = r15 and char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	rig.gripOffset = r15 and Vector3.new(0, -0.12, 0) or Vector3.new(0, -0.9, 0)
	if not rig.upper or not rig.grip then return nil, "body parts" end
	return rig
end

-- Left-arm IK (R15): two-bone solve that puts the left hand on the sword handle.
local LEFT_POLE = Vector3.new(-0.55, -1, 0.25)
local function solveLeftArm15(rig, target)
	local J, U = rig.J, rig.upper.CFrame
	local S = (U * J.ls.C0).Position
	local a = (J.le.C0.Position - J.ls.C1.Position).Magnitude
	local b = (J.lw.C0.Position - J.le.C1.Position).Magnitude
	local back = S - target
	if back.Magnitude < 1e-3 then return nil end
	local W = target + back.Unit * 0.3
	local v = W - S
	local dist = v.Magnitude
	if dist < 0.05 then return nil end
	local dir = v / dist
	local dd = math.clamp(dist, math.abs(a - b) + 0.05, a + b - 0.03)
	local x = (a * a - b * b + dd * dd) / (2 * dd)
	local h = math.sqrt(math.max(a * a - x * x, 0))
	local pole = U:VectorToWorldSpace(LEFT_POLE)
	pole = pole - dir * pole:Dot(dir)
	if pole.Magnitude < 1e-3 then pole = U:VectorToWorldSpace(Vector3.new(0, -1, 0)) end
	pole = pole.Unit
	local E = S + dir * x + pole * h
	local Wc = S + dir * dd
	local restUp = (J.le.C0.Position - J.ls.C1.Position).Unit
	local Ts = toTransform(J.ls, aimRot(restUp, U:VectorToObjectSpace((E - S).Unit)))
	local upperCF = U * J.ls.C0 * Ts * J.ls.C1:Inverse()
	local restLow = (J.lw.C0.Position - J.le.C1.Position).Unit
	local Te = toTransform(J.le, aimRot(restLow, upperCF:VectorToObjectSpace((Wc - E).Unit)))
	if isNaNCF(Ts) or isNaNCF(Te) then return nil end
	return Ts, Te
end

-- Left-arm aim (R6): the arm is one rigid bone, so just point it at the handle.
local function solveLeftArm6(rig, target)
	local J, U = rig.J, rig.upper.CFrame
	local S = (U * J.ls.C0).Position
	local rest = Vector3.new(0, -0.85, 0) - J.ls.C1.Position
	local v = target - S
	if v.Magnitude < 0.05 or rest.Magnitude < 1e-3 then return nil end
	local Ts = toTransform(J.ls, aimRot(rest.Unit, U:VectorToObjectSpace(v.Unit)))
	if isNaNCF(Ts) then return nil end
	return Ts
end

local function legExtent(h, flex)
	return math.cos(math.rad(h)) + math.cos(math.rad(h - flex))
end

local function applyPose(p, actW)
	local rig = state.rig
	local J = rig.J
	if rig.r15 then
		setT(J.waist, toTransform(J.waist, rot(p.lean, p.twist, 0)), 1)
		setT(J.rs, toTransform(J.rs, rot(p.rx, p.ry, p.rz)), 1)
		setT(J.re, toTransform(J.re, rot(p.re, 0, 0)), 1)
		if J.rw then setT(J.rw, toTransform(J.rw, rot(p.rw, 0, 0)), 1) end
		if actW > 0.005 then
			local rhp, lhp = p.st + p.cr * 0.35, -p.st * 0.8 + p.cr * 0.35
			local rfx, lfx = p.cr * 0.8, p.cr
			setT(J.rh, toTransform(J.rh, rot(rhp, 0, 0)), actW)
			setT(J.lh, toTransform(J.lh, rot(lhp, 0, 0)), actW)
			if J.rk then setT(J.rk, toTransform(J.rk, rot(-rfx, 0, 0)), actW) end
			if J.lk then setT(J.lk, toTransform(J.lk, rot(-lfx, 0, 0)), actW) end
			local drop = 2 - 0.5 * (legExtent(rhp, rfx) + legExtent(lhp, lfx))
			drop = math.clamp(drop, 0, 1.4) * 0.85
			setT(J.root, CFrame.new(0, -drop, 0), actW)
		end
	else
		local body = rot(p.lean, p.twist, 0)
		local rxe = p.rx + p.re * 0.55  -- R6 has no elbow: fold the bend into the shoulder
		setT(J.rs, toTransform(J.rs, rot(rxe, p.ry, p.rz)), 1)
		if actW > 0.005 then
			setT(J.root, toTransform(J.root, body), actW)
			local inv = body:Inverse()
			setT(J.rh, toTransform(J.rh, inv * rot(p.st + p.cr * 0.3, 0, 0)), actW)
			setT(J.lh, toTransform(J.lh, inv * rot(-p.st * 0.8 + p.cr * 0.3, 0, 0)), actW)
		end
	end
	-- Left hand -> sword handle
	local hilt = state.sword and state.sword.hilt
	if hilt and hilt.Parent then
		local target = hilt.CFrame:PointToWorldSpace(Vector3.new(0, -1.25, 0))
		if rig.r15 then
			local Ts, Te = solveLeftArm15(rig, target)
			if Ts then setT(J.ls, Ts, 1); setT(J.le, Te, 1) end
		else
			local Ts = solveLeftArm6(rig, target)
			if Ts then setT(J.ls, Ts, 1) end
		end
	end
end

local function applyPoseSafe()
	if not state.alive or not state.rig then return end
	local ok, err = pcall(applyPose, state.pose, state.actW)
	if not ok then
		state.poseErrors = state.poseErrors + 1
		if state.poseErrors <= 3 then warn("[Sanguine] pose error: " .. tostring(err)) end
		if state.poseErrors > 30 then
			state.rig = nil
			warn("[Sanguine] posing disabled after repeated errors")
		end
	end
end

----------------------------------------------------------------------
-- 6. THE GREATSWORD
--    Sword-local space: origin = right-hand grip, +Y = toward the blade tip.
----------------------------------------------------------------------
local BASALT    = Color3.fromRGB(35, 32, 38)
local BASALT_DK = Color3.fromRGB(24, 22, 28)
local GOLD      = Color3.fromRGB(225, 185, 65)
local LEATHER   = Color3.fromRGB(32, 22, 20)
local CORE_DIM  = Color3.fromRGB(255, 38, 16)
local CORE_HOT  = Color3.fromRGB(255, 150, 80)
local CYL       = Enum.PartType.Cylinder
local BALL      = Enum.PartType.Ball
local ROT_Y     = CFrame.Angles(0, 0, math.pi / 2)  -- stand a cylinder along local Y

local TRAILS = {
	[1] = ColorSequence.new(Color3.fromRGB(255, 50, 35), Color3.fromRGB(110, 0, 10)),
	[2] = ColorSequence.new(Color3.fromRGB(140, 210, 255), Color3.fromRGB(40, 90, 255)),
	[3] = ColorSequence.new(Color3.fromRGB(255, 245, 235), Color3.fromRGB(230, 20, 25)),
	[4] = ColorSequence.new(Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 255, 255)),
}

local function setTrail(i)
	local s = state.sword
	if not s then return end
	for _, t in ipairs(s.trails) do
		pcall(function() t.Color = TRAILS[i] end)
	end
end

local function randSigned(n) return (math.random() * 2 - 1) * n end

local function buildSword(char, rig)
	local old = char:FindFirstChild("SanguineGreatsword")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "SanguineGreatsword"

	local tilt = math.rad(CONFIG.GripTilt)
	local vy = Vector3.new(0, -math.cos(tilt), -math.sin(tilt))
	local vz = AX:Cross(vy)
	local base = rig.grip.CFrame * CFrame.new(rig.gripOffset) * CFrame.fromMatrix(Vector3.zero, AX, vy, vz)

	local parts = {}
	local function mk(name, size, lcf, color, mat, shape, refl)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat
		if shape then p.Shape = shape end
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if refl then p.Reflectance = refl end
		p.CFrame = base * lcf
		p.Parent = model
		parts[#parts + 1] = p
		return p
	end
	local rng = Random.new(1337)

	-- invisible root at the grip point
	local hilt = mk("Hilt", Vector3.new(0.2, 0.2, 0.2), CFrame.identity, GOLD, Enum.Material.Metal)
	hilt.Transparency = 1

	-- two-handed leather grip + wraps
	mk("Grip", Vector3.new(3.1, 0.34, 0.34), CFrame.new(0, -0.65, 0) * ROT_Y, LEATHER, Enum.Material.Fabric, CYL)
	for i = 0, 6 do
		mk("Wrap", Vector3.new(0.1, 0.4, 0.4), CFrame.new(0, -2.0 + i * 0.4, 0) * ROT_Y,
			Color3.fromRGB(16, 11, 11), Enum.Material.Fabric, CYL)
	end

	-- flared crown pommel
	mk("PommelBase", Vector3.new(0.5, 0.7, 0.7), CFrame.new(0, -2.4, 0) * ROT_Y, GOLD, Enum.Material.Metal, CYL, 0.15)
	for i = 0, 5 do
		local ang = i * math.pi / 3
		mk("Crown", Vector3.new(0.12, 0.46, 0.12),
			CFrame.new(0, -2.7, 0) * CFrame.Angles(0, ang, 0) * CFrame.new(0.36, 0, 0) * CFrame.Angles(0, 0, math.rad(-28)),
			GOLD, Enum.Material.Metal, nil, 0.15)
	end
	mk("PommelGem", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, -2.95, 0), CORE_DIM, Enum.Material.Neon, BALL)

	-- gold guard plate + glowing gems
	mk("GuardPlate", Vector3.new(1.5, 0.5, 0.72), CFrame.new(0, 1.0, 0), GOLD, Enum.Material.Metal, nil, 0.2)
	mk("GuardGemF", Vector3.new(0.46, 0.46, 0.46), CFrame.new(0, 1.0, -0.34), CORE_DIM, Enum.Material.Neon, BALL)
	mk("GuardGemB", Vector3.new(0.46, 0.46, 0.46), CFrame.new(0, 1.0, 0.34), CORE_DIM, Enum.Material.Neon, BALL)
	mk("Collar", Vector3.new(1.05, 0.2, 0.6), CFrame.new(0, 1.42, 0), GOLD, Enum.Material.Metal, nil, 0.2)

	-- twin demonic horns, curving out and up, wrapped in braided gold bands
	local pts = {
		Vector3.new(0.7, 1.00, 0), Vector3.new(1.35, 0.96, 0), Vector3.new(2.0, 1.22, 0),
		Vector3.new(2.5, 1.80, 0), Vector3.new(2.68, 2.55, 0),
	}
	for _, side in ipairs({ 1, -1 }) do
		for i = 1, #pts - 1 do
			local a = Vector3.new(pts[i].X * side, pts[i].Y, 0)
			local b = Vector3.new(pts[i + 1].X * side, pts[i + 1].Y, 0)
			local mid, len = (a + b) / 2, (b - a).Magnitude
			local dirv = (b - a).Unit
			local thick = 0.44 - (i - 1) * 0.1
			mk("Horn", Vector3.new(thick, thick, len + 0.08), CFrame.lookAt(mid, mid + dirv), BASALT_DK, Enum.Material.Slate)
			for _, f in ipairs({ 0.3, 0.7 }) do
				local pos = a + (b - a) * f
				mk("HornBand", Vector3.new(0.14, thick + 0.16, thick + 0.16),
					CFrame.lookAt(pos, pos + dirv) * CFrame.Angles(0, math.pi / 2, 0),
					GOLD, Enum.Material.Metal, CYL, 0.2)
			end
		end
	end

	-- blade: ricasso, two basalt slabs, recessed neon fissure core, stepped tip, serrations
	mk("Ricasso", Vector3.new(0.95, 0.7, 0.5), CFrame.new(0, 1.8, 0), BASALT_DK, Enum.Material.Basalt)
	mk("BladeL", Vector3.new(0.55, 5.7, 0.46), CFrame.new(-0.455, 4.75, 0), BASALT, Enum.Material.Basalt)
	mk("BladeR", Vector3.new(0.55, 5.7, 0.46), CFrame.new(0.455, 4.75, 0), BASALT, Enum.Material.Basalt)
	local core = mk("Core", Vector3.new(0.3, 5.3, 0.2), CFrame.new(0, 4.7, 0), CORE_DIM, Enum.Material.Neon)
	local tip = { { 1.3, 7.85, 0.5 }, { 0.95, 8.35, 0.5 }, { 0.6, 8.8, 0.46 }, { 0.3, 9.15, 0.4 } }
	for i, s in ipairs(tip) do
		mk("Tip" .. i, Vector3.new(s[1], s[3], 0.44), CFrame.new(0, s[2], 0), BASALT, Enum.Material.Basalt)
	end
	for _, side in ipairs({ 1, -1 }) do
		for i = 1, 8 do
			local y = 2.25 + (i - 1) * 0.68 + rng:NextNumber(-0.1, 0.1)
			local sz = rng:NextNumber(0.3, 0.44)
			mk("Tooth", Vector3.new(sz, sz * 0.9, 0.42),
				CFrame.new(side * 0.78, y, rng:NextNumber(-0.03, 0.03)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(35, 55))),
				BASALT_DK, Enum.Material.Basalt)
		end
	end
	for i = 1, 6 do -- jagged stone shards on the flat faces
		mk("Shard", Vector3.new(rng:NextNumber(0.14, 0.26), rng:NextNumber(0.3, 0.6), 0.12),
			CFrame.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(2.4, 7.2), (i % 2 == 0 and 1 or -1) * 0.25)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))),
			BASALT_DK, Enum.Material.Basalt)
	end

	-- invisible axis part: trail target + lightning anchor
	local axis = mk("BladeAxis", Vector3.new(0.2, 7.4, 0.2), CFrame.new(0, 5.6, 0), BASALT, Enum.Material.SmoothPlastic)
	axis.Transparency = 1

	-- living bloodflame: pulsing light, embers, vapor, blue sparks
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 30)
	light.Range = 12
	light.Brightness = 2
	light.Parent = core

	local function emitter(props)
		local e = Instance.new("ParticleEmitter")
		for k, v in pairs(props) do e[k] = v end
		e.Parent = core
		return e
	end
	emitter({
		Rate = 38, Lifetime = NumberRange.new(0.9, 1.9), Speed = NumberRange.new(0.5, 2.2),
		Acceleration = Vector3.new(0, 4, 0), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 120, 40), Color3.fromRGB(150, 0, 10)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.24), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	})
	emitter({
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = 9, Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(0.3, 1.2),
		Acceleration = Vector3.new(0, 2.5, 0), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.35,
		Color = ColorSequence.new(Color3.fromRGB(200, 30, 20), Color3.fromRGB(40, 0, 0)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
	})
	emitter({
		Rate = 16, Lifetime = NumberRange.new(0.12, 0.3), Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(150, 210, 255), Color3.fromRGB(60, 120, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0) }),
	})

	-- procedural lightning arcs (flickered from Heartbeat)
	local arcs = {}
	for i = 1, 3 do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = axis, axis
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 0.07, 0.03
		beam.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 7
		beam.CurveSize0, beam.CurveSize1 = randSigned(0.5), randSigned(0.5)
		beam.FaceCamera = true
		beam.Enabled = false
		beam.Parent = axis
		arcs[i] = { beam = beam, a0 = a0, a1 = a1 }
	end

	model.Parent = char
	for _, p in ipairs(parts) do -- weld everything (offsets captured from current CFrames)
		if p ~= hilt then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = hilt, p
			w.Parent = p
		end
	end
	local gw = Instance.new("WeldConstraint")
	gw.Part0, gw.Part1 = rig.grip, hilt
	gw.Parent = hilt

	-- weapon trail from the VFX module; fix its attachments to run along the blade
	local sword = { model = model, hilt = hilt, core = core, light = light, axis = axis, arcs = arcs, trails = {}, arcT = 0 }
	local before = {}
	for _, c in ipairs(axis:GetChildren()) do before[c] = true end
	if CONFIG.UseModuleTrail then vfx("AttachWeaponTrail", axis, TRAILS[1]) end
	local fresh = {}
	for _, c in ipairs(axis:GetChildren()) do
		if not before[c] and c:IsA("Attachment") then fresh[#fresh + 1] = c end
	end
	if #fresh >= 2 then
		fresh[1].Position = Vector3.new(0, -1.2, 0)
		fresh[2].Position = Vector3.new(0, 3.5, 0)
	end
	for _, d in ipairs(axis:GetDescendants()) do
		if d:IsA("Trail") then sword.trails[#sword.trails + 1] = d end
	end
	if #sword.trails == 0 then -- module trail not found: build a simple one
		local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
		t0.Position, t1.Position = Vector3.new(0, 0.6, 0), Vector3.new(0, 3.5, 0)
		t0.Parent, t1.Parent = axis, axis
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = t0, t1
		tr.Lifetime = 0.28
		tr.MinLength = 0.05
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.Color = TRAILS[1]
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		tr.Parent = axis
		sword.trails[1] = tr
	end
	return sword
end

local function updateSword(dt, now)
	local s = state.sword
	if not s or not s.core.Parent then return end
	state.surge = math.max(0, state.surge - dt * 2.5)
	local k = 0.5 + 0.5 * math.sin(now * 2.4)         -- slow "breathing"
	local e = math.min(1, k * 0.5 + state.surge)
	s.core.Color = CORE_DIM:Lerp(CORE_HOT, e)
	s.light.Brightness = 1.2 + 1.6 * k + 3 * state.surge
	s.light.Range = 11 + 4 * k + 6 * state.surge
	s.arcT = s.arcT - dt
	if s.arcT <= 0 then
		s.arcT = 0.05 + math.random() * 0.12
		for _, arc in ipairs(s.arcs) do
			local on = math.random() < 0.7
			arc.beam.Enabled = on
			if on then
				local p0 = Vector3.new(randSigned(0.5), randSigned(3.3), randSigned(0.3))
				arc.a0.Position = p0
				arc.a1.Position = p0 + Vector3.new(randSigned(0.9), randSigned(1.5), randSigned(0.5))
				arc.beam.CurveSize0, arc.beam.CurveSize1 = randSigned(0.5), randSigned(0.5)
			end
		end
	end
end

----------------------------------------------------------------------
-- 7. HUD
----------------------------------------------------------------------
local function buildHUD()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("SanguineHUD")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SanguineHUD"
	gui.ResetOnSpawn = false
	gui.Parent = pg

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(268, 232)
	panel.Position = UDim2.new(0, 16, 1, -248)
	panel.BackgroundColor3 = Color3.fromRGB(14, 10, 12)
	panel.BackgroundTransparency = 0.3
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Font = Enum.Font.Fantasy
	title.Text = "THE SANGUINE SANCTUM"
	title.TextColor3 = GOLD
	title.TextSize = 20
	title.Parent = panel

	local rows = {
		{ "Z / Click", "Bloodflame Combo x3" }, { "X", "Sanguine Thrust" }, { "C", "Ground Eruption" },
		{ "V", "Sekiro Deflect + Riposte" }, { "B", "Telegraph Rune" }, { "N", "Blood Meteor Rain" },
		{ "M", "Phase Burst" }, { "Q", "Dodge" },
	}
	local lines = {}
	for _, r in ipairs(rows) do
		lines[#lines + 1] = '<font color="#E1B941"><b>[' .. r[1] .. ']</b></font>  ' .. r[2]
	end
	local list = Instance.new("TextLabel")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(14, 34)
	list.Size = UDim2.new(1, -28, 1, -40)
	list.Font = Enum.Font.GothamMedium
	list.RichText = true
	list.Text = table.concat(lines, "\n")
	list.TextColor3 = Color3.fromRGB(235, 225, 215)
	list.TextSize = 15
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Parent = panel

	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromOffset(600, 70)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.Fantasy
	banner.Text = ""
	banner.TextColor3 = GOLD
	banner.TextSize = 50
	banner.TextTransparency = 1
	banner.TextStrokeColor3 = Color3.fromRGB(30, 0, 0)
	banner.TextStrokeTransparency = 1
	banner.Parent = gui

	return { gui = gui, banner = banner }
end

local function showBanner(text)
	if not hud then return end
	hud.banner.Text = text
	hud.banner.TextTransparency = 1
	hud.banner.TextStrokeTransparency = 1
	TweenService:Create(hud.banner, TweenInfo.new(0.35), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	task.delay(1.9, function()
		if hud and hud.banner.Parent then
			TweenService:Create(hud.banner, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

----------------------------------------------------------------------
-- 8. TRAINING DUMMY (health bar, flash, floating numbers, recoil spring)
----------------------------------------------------------------------
local function buildDummy(home)
	local old = Workspace:FindFirstChild("SanguineTrainingDummy")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "SanguineTrainingDummy"
	local upper = {}
	local function part(name, size, lcf, color, mat, shape, isUpper)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.Color = color
		p.Material = mat
		if shape then p.Shape = shape end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = home * lcf
		p.Parent = model
		if isUpper then upper[#upper + 1] = { part = p, lcf = lcf } end
		return p
	end
	local up = CFrame.Angles(0, 0, math.pi / 2)
	local base = part("Base", Vector3.new(0.6, 5, 5), CFrame.new(0, 0.3, 0) * up, Color3.fromRGB(58, 52, 60), Enum.Material.Slate, CYL, false)
	part("Post", Vector3.new(4.6, 1.2, 1.2), CFrame.new(0, 2.9, 0) * up, Color3.fromRGB(104, 70, 44), Enum.Material.Wood, CYL, true)
	part("Pad", Vector3.new(2.8, 2.7, 2.7), CFrame.new(0, 3.6, 0) * up, Color3.fromRGB(206, 170, 95), Enum.Material.Fabric, CYL, true)
	part("Band", Vector3.new(0.25, 2.8, 2.8), CFrame.new(0, 3.6, 0) * up, Color3.fromRGB(150, 30, 30), Enum.Material.Fabric, CYL, true)
	part("Arms", Vector3.new(5.6, 0.5, 0.5), CFrame.new(0, 4.5, 0), Color3.fromRGB(104, 70, 44), Enum.Material.Wood, nil, true)
	local head = part("Head", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, 5.9, 0), Color3.fromRGB(190, 160, 110), Enum.Material.Fabric, BALL, true)
	part("HandL", Vector3.new(0.7, 0.7, 0.7), CFrame.new(-2.8, 4.5, 0), Color3.fromRGB(190, 160, 110), Enum.Material.Fabric, BALL, true)
	part("HandR", Vector3.new(0.7, 0.7, 0.7), CFrame.new(2.8, 4.5, 0), Color3.fromRGB(190, 160, 110), Enum.Material.Fabric, BALL, true)
	model.PrimaryPart = base

	local hl = Instance.new("Highlight")
	hl.Adornee = model
	hl.FillColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model

	-- health bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "HealthBar"
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(230, 52)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 250
	bb.Parent = head
	local nameL = Instance.new("TextLabel")
	nameL.BackgroundTransparency = 1
	nameL.Size = UDim2.new(1, 0, 0, 20)
	nameL.Font = Enum.Font.Fantasy
	nameL.Text = "TRAINING DUMMY"
	nameL.TextColor3 = Color3.fromRGB(235, 225, 215)
	nameL.TextSize = 18
	nameL.TextStrokeTransparency = 0.4
	nameL.Parent = bb
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 22)
	back.Size = UDim2.new(1, 0, 0, 12)
	back.BackgroundColor3 = Color3.fromRGB(14, 9, 11)
	back.BorderSizePixel = 0
	back.Parent = bb
	local bs = Instance.new("UIStroke")
	bs.Color = GOLD
	bs.Thickness = 1
	bs.Parent = back
	local chip = Instance.new("Frame")
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = Color3.fromRGB(232, 188, 120)
	chip.BorderSizePixel = 0
	chip.ZIndex = 1
	chip.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(172, 28, 28)
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = back
	local hpText = Instance.new("TextLabel")
	hpText.BackgroundTransparency = 1
	hpText.Position = UDim2.fromOffset(0, 35)
	hpText.Size = UDim2.new(1, 0, 0, 14)
	hpText.Font = Enum.Font.GothamMedium
	hpText.TextColor3 = Color3.fromRGB(235, 225, 215)
	hpText.TextSize = 12
	hpText.TextStrokeTransparency = 0.5
	hpText.Parent = bb

	model.Parent = Workspace
	return {
		model = model, home = home, base = base, head = head, upper = upper, hl = hl,
		fill = fill, chip = chip, hpText = hpText,
		health = CONFIG.DummyHealth, max = CONFIG.DummyHealth, dead = false,
		tilt = 0, tiltV = 0, spin = 0, spinV = 0, dir = Vector3.new(0, 0, -1),
	}
end

local function updateBar(instant)
	local d = dummy
	if not d then return end
	local ratio = math.clamp(d.health / d.max, 0, 1)
	d.hpText.Text = math.floor(d.health) .. " / " .. d.max
	d.fill.Size = UDim2.fromScale(ratio, 1)
	if instant then
		d.chip.Size = UDim2.fromScale(ratio, 1)
	else
		TweenService:Create(d.chip, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.4),
			{ Size = UDim2.fromScale(ratio, 1) }):Play()
	end
end

local function flashDummy(color)
	local d = dummy
	if not d then return end
	d.hl.FillColor = color
	d.hl.FillTransparency = 0.1
	if d.flashTween then d.flashTween:Cancel() end
	d.flashTween = TweenService:Create(d.hl, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1 })
	d.flashTween:Play()
end

local function popNumber(dmg, heavy)
	local d = dummy
	local color = Color3.new(1, 1, 1)
	if dmg >= 450 then color = Color3.fromRGB(255, 70, 60) elseif dmg >= 300 then color = Color3.fromRGB(255, 170, 60) end
	local bb = Instance.new("BillboardGui")
	bb.Adornee = d.head
	bb.Size = UDim2.fromOffset(180, 70)
	bb.StudsOffsetWorldSpace = Vector3.new(randSigned(1.6), 2.4 + math.random() * 0.8, randSigned(1))
	bb.AlwaysOnTop = true
	bb.Parent = d.head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = tostring(dmg)
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.TextSize = heavy and 46 or 32
	t.TextStrokeColor3 = Color3.fromRGB(25, 0, 0)
	t.TextStrokeTransparency = 0.15
	t.Parent = bb
	TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, 3.2, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(bb, 1.3)
end

local function killDummy()
	local d = dummy
	d.dead = true
	showBanner("ENEMY FELLED")
	task.delay(CONFIG.DummyRespawn, function()
		if dummy ~= d or not d.model.Parent then return end
		d.health = d.max
		d.dead = false
		d.tilt, d.tiltV, d.spin, d.spinV = 0, 0, 0, 0
		updateBar(true)
		flashDummy(Color3.fromRGB(255, 225, 120))
	end)
end

-- Core damage function: every move funnels through here.
local function hitDummy(dmg, o)
	local d = dummy
	if not d or d.dead or not state.root then return false end
	o = o or {}
	d.health = math.max(0, d.health - dmg)
	local toP = safeUnit(flat(state.root.Position - d.home.Position), Vector3.new(0, 0, 1))
	d.dir = -toP
	local chest = d.home.Position + Vector3.new(randSigned(0.5), 3.7 + randSigned(0.4), 0) + toP * 1.0
	vfx("BossHit", chest, o.heavy == true, o.parry == true)
	if o.shake then shake(o.shake[1], o.shake[2], o.shake[3]) end
	hitstop(o.stop or 0.05)
	state.surge = 1
	sfx(o.heavy and "Heavy" or "Slash", 0.9, o.heavy and 0.55 or 0.7)
	d.tiltV = d.tiltV + (o.heavy and 5.5 or 3.2)
	d.spinV = d.spinV + (math.random() < 0.5 and -1 or 1) * (o.heavy and 4 or 2.2)
	flashDummy(o.heavy and Color3.fromRGB(255, 236, 222) or Color3.new(1, 1, 1))
	popNumber(dmg, o.heavy)
	updateBar(false)
	if d.health <= 0 then killDummy() end
	return true
end

local function dummyInRadius(center, radius)
	if not dummy or dummy.dead then return false end
	return flat(dummy.home.Position - center).Magnitude <= radius + 1.6
end

local function updateDummy(dt)
	local d = dummy
	if not d or not d.model.Parent then return end
	if d.dead then
		d.tilt = d.tilt + (1.4 - d.tilt) * math.min(1, dt * 5)
	else
		d.tiltV = d.tiltV + (-90 * d.tilt - 9 * d.tiltV) * dt
		d.tilt = math.clamp(d.tilt + d.tiltV * dt, -0.7, 0.7)
		d.spinV = d.spinV + (-60 * d.spin - 7 * d.spinV) * dt
		d.spin = d.spin + d.spinV * dt
	end
	if math.abs(d.tilt) < 1e-4 and math.abs(d.spin) < 1e-4 and not d.moved then return end
	d.moved = math.abs(d.tilt) > 1e-4 or math.abs(d.spin) > 1e-4
	local axis = AY:Cross(d.dir)
	if axis.Magnitude < 1e-3 then return end
	local pp = d.home.Position + Vector3.new(0, 0.6, 0)
	local M = CFrame.new(pp) * CFrame.fromAxisAngle(axis.Unit, d.tilt) * CFrame.fromAxisAngle(AY, d.spin) * CFrame.new(-pp)
	for _, e in ipairs(d.upper) do
		e.part.CFrame = M * (d.home * e.lcf)
	end
end

local function spawnDummy()
	local root = state.root
	local look = safeUnit(flat(root.CFrame.LookVector), Vector3.new(0, 0, -1))
	local pos = groundAt(root.Position + look * CONFIG.DummyDistance)
	local home = CFrame.lookAt(pos, pos - look)   -- dummy faces the player
	dummy = buildDummy(home)
	dummy.dir = look
	updateBar(true)
end

-- the dummy "attacks" so the Sekiro deflect has something to clash with
local function dummyTelegraph()
	local d = dummy
	if not d or d.dead then return end
	flashDummy(Color3.fromRGB(255, 70, 40))
	d.tiltV = d.tiltV + 2.4
	task.delay(0.16, function() if dummy == d and not d.dead then d.tiltV = d.tiltV - 6.5 end end)
	task.delay(0.3, function() if dummy == d and not d.dead then d.tiltV = d.tiltV + 3.6 end end)
end

----------------------------------------------------------------------
-- 9. MOVES
----------------------------------------------------------------------
local function groundTarget(forwardDist)
	local root = state.root
	if dummy and not dummy.dead and flat(dummy.home.Position - root.Position).Magnitude <= 90 then
		return dummy.home.Position
	end
	local look = safeUnit(flat(root.CFrame.LookVector), Vector3.new(0, 0, -1))
	return groundAt(root.Position + look * forwardDist)
end

local function slashFx(combo, heavy)
	vfx("Slash", state.root, combo, heavy)
	sfx(heavy and "Heavy" or "Slash", 0.7, heavy and 0.8 or (1.0 + combo * 0.05))
end

-- melee hit: reach is measured from the root; also needs to be roughly in front
local function meleeHit(dmg, reach, o)
	if not dummy or dummy.dead then return false end
	local to = flat(dummy.home.Position - state.root.Position)
	if to.Magnitude > reach then return false end
	local look = flat(state.root.CFrame.LookVector)
	if look.Magnitude > 0.01 and to.Magnitude > 1 and look.Unit:Dot(to.Unit) < 0.1 then return false end
	return hitDummy(dmg, o)
end

local function doJump()
	pcall(function() state.hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
end

local MOVES = {}

MOVES.C1 = {
	name = "Crimson Cleave", total = 0.80, cancel = 0.56, faceUntil = 0.30, step = { 0.12, 0.40, 26 },
	keys = {
		K(0.20, "out", { lean = 6, twist = -66, rx = 62, ry = -72, rz = 18, re = 52, rw = 0, st = -34, cr = 30 }),
		K(0.33, "in",  { lean = 20, twist = 62, rx = 84, ry = 66, rz = 4, re = 16, rw = -26, st = 30, cr = 36 }),
		K(0.50, "out", { lean = 22, twist = 78, rx = 80, ry = 88, rz = 4, re = 18, rw = -20, st = 34, cr = 38 }),
		K(0.80, "io"),
	},
	events = {
		{ 0.20, function() setTrail(1); slashFx(1, false) end },
		{ 0.30, function() meleeHit(DMG.C1, 13, { stop = 0.05, shake = { 0.7, 0.2, 20 } }) end },
	},
}

MOVES.C2 = {
	name = "Tempest Rising", total = 0.82, cancel = 0.58, faceUntil = 0.30, step = { 0.12, 0.40, 24 },
	keys = {
		K(0.20, "out", { lean = 18, twist = 56, rx = 24, ry = 64, rz = -8, re = 32, rw = -10, st = 22, cr = 44 }),
		K(0.33, "in",  { lean = -6, twist = -60, rx = 128, ry = -34, rz = 22, re = 22, rw = -20, st = -30, cr = 22 }),
		K(0.52, "out", { lean = -12, twist = -72, rx = 152, ry = -28, rz = 26, re = 18, rw = -12, st = -32, cr = 20 }),
		K(0.82, "io"),
	},
	events = {
		{ 0.20, function() setTrail(2); slashFx(2, false) end },
		{ 0.30, function() meleeHit(DMG.C2, 13, { stop = 0.06, shake = { 0.8, 0.22, 20 } }) end },
	},
}

MOVES.C3 = {
	name = "Sanguine Finale", total = 1.18, cancel = 0.86, faceUntil = 0.40, step = { 0.14, 0.58, 30 }, stepPow = 0.35,
	keys = {
		K(0.16, "out", { lean = 30, twist = -30, rx = 18, ry = -20, rz = 12, re = 112, rw = 0, st = -30, cr = 62 }),
		K(0.44, "io",  { lean = -22, twist = 0, rx = 160, ry = 0, rz = 6, re = 24, rw = -10, st = 14, cr = 8 }),
		K(0.55, "in",  { lean = 44, twist = 6, rx = 62, ry = 2, rz = 0, re = 10, rw = -32, st = 36, cr = 54 }),
		K(0.86, "out", { lean = 40, twist = 6, rx = 58, ry = 2, rz = 0, re = 10, rw = -30, st = 36, cr = 50 }),
		K(1.18, "io"),
	},
	events = {
		{ 0.14, doJump },
		{ 0.44, function() setTrail(3); slashFx(3, true) end },
		{ 0.54, function()
			local root = state.root
			local look = safeUnit(flat(root.CFrame.LookVector), Vector3.new(0, 0, -1))
			vfx("Impact", groundAt(root.Position + look * 9), 12, CONFIG.ImpactStyle)
			meleeHit(DMG.C3, 15, { heavy = true, stop = 0.11, shake = { 1.6, 0.5, 18 } })
			shake(1.2, 0.4, 16)
		end },
	},
}

MOVES.X = {
	name = "Sanguine Thrust", total = 0.98, cancel = 0.76, faceUntil = 0.34, step = { 0.28, 0.50, 38 },
	keys = {
		K(0.30, "out", { lean = 4, twist = -72, rx = 44, ry = -58, rz = 14, re = 106, rw = 0, st = -34, cr = 34 }),
		K(0.46, "in",  { lean = 28, twist = 16, rx = 88, ry = -4, rz = 0, re = 6, rw = -34, st = 40, cr = 48 }),
		K(0.72, "out", { lean = 30, twist = 18, rx = 90, ry = -2, rz = 0, re = 4, rw = -34, st = 42, cr = 50 }),
		K(0.98, "io"),
	},
	events = {
		{ 0.30, function() setTrail(4); slashFx(1, true) end },
		{ 0.45, function() meleeHit(DMG.X, 15, { heavy = true, stop = 0.1, shake = { 1.2, 0.35, 22 } }) end },
	},
}

MOVES.C = {
	name = "Bloodflame Ground Eruption", total = 1.22, cancel = 0.92, faceUntil = 0.5,
	keys = {
		K(0.34, "out", { lean = -16, twist = 0, rx = 152, ry = 0, rz = 6, re = 30, rw = -10, st = -8, cr = 18 }),
		K(0.56, "in",  { lean = 46, twist = 0, rx = 54, ry = 0, rz = 0, re = 8, rw = -40, st = 26, cr = 52 }),
		K(0.92, "out", { lean = 42, twist = 0, rx = 52, ry = 0, rz = 0, re = 8, rw = -38, st = 26, cr = 50 }),
		K(1.22, "io"),
	},
	events = {
		{ 0.34, function() setTrail(4) end },
		{ 0.56, function()
			local root = state.root
			local tgt = groundTarget(16)
			local o = flat(root.Position)
			local dist = flat(tgt - root.Position).Magnitude
			local dir = safeUnit(flat(tgt - root.Position), safeUnit(flat(root.CFrame.LookVector), Vector3.new(0, 0, -1)))
			local n = math.max(2, math.floor(dist / 6))
			for i = 1, n do   -- a rolling line of eruptions toward the target
				task.delay(0.07 * (i - 1), function()
					vfx("Impact", groundAt(o + dir * (dist * i / n) + Vector3.new(0, root.Position.Y, 0)), 6 + i, CONFIG.ImpactStyle)
				end)
			end
			task.delay(0.07 * n, function()
				vfx("Impact", tgt, 15, CONFIG.ImpactStyle)
				shake(1.5, 0.45, 18)
				if dummyInRadius(tgt, 15) then hitDummy(DMG.C, { heavy = true, stop = 0.1, shake = { 1.4, 0.4, 20 } }) end
			end)
			sfx("Heavy", 0.9, 0.6)
		end },
	},
}

MOVES.V = {
	name = "Sekiro Deflect", total = 0.95, cancel = 0.74, faceUntil = 0.4, step = { 0.40, 0.62, 30 },
	keys = {
		K(0.12, "out", { lean = 8, twist = -35, rx = 60, ry = -8, rz = -4, re = 92, rw = 0, st = -26, cr = 32 }),
		K(0.28, "in",  { lean = 6, twist = 10, rx = 70, ry = 26, rz = -4, re = 72, rw = 0, st = -22, cr = 34 }),
		K(0.62, "in",  { lean = 30, twist = -20, rx = 90, ry = -6, rz = 0, re = 8, rw = -30, st = 38, cr = 44 }),
		K(0.95, "io"),
	},
	events = {
		{ 0.00, function() dummyTelegraph() end },
		{ 0.28, function()
			local s = state.sword
			local pos = s.hilt.CFrame:PointToWorldSpace(Vector3.new(0, 4.5, 0))
			local dir = Vector3.new(0, 0, -1)
			if dummy then dir = safeUnit(dummy.home.Position - state.root.Position, dir) end
			setTrail(4)
			vfx("PerfectParry", pos, dir)
			hitstop(0.12)
			shake(1.1, 0.3, 24)
			sfx("Heavy", 0.8, 1.2)
			if dummy and not dummy.dead then dummy.tiltV = dummy.tiltV + 3.5 end
		end },
		{ 0.62, function()
			slashFx(1, true)
			meleeHit(DMG.V, 16, { heavy = true, parry = true, stop = 0.12, shake = { 1.0, 0.3, 24 } })
		end },
	},
}

MOVES.B = {
	name = "Ground Telegraph Rune", total = 0.95, cancel = 0.72, faceUntil = 0.4,
	keys = {
		K(0.25, "out", { lean = -8, twist = 0, rx = 120, ry = 0, rz = 6, re = 40, rw = -10, st = -10, cr = 24 }),
		K(0.48, "in",  { lean = 36, twist = 0, rx = 55, ry = 0, rz = 0, re = 6, rw = -40, st = 24, cr = 50 }),
		K(0.72, "out", { lean = 34, twist = 0, rx = 54, ry = 0, rz = 0, re = 6, rw = -40, st = 24, cr = 48 }),
		K(0.95, "io"),
	},
	events = {
		{ 0.48, function()
			local tgt = groundTarget(16)
			setTrail(1)
			vfx("GroundTelegraph", tgt, 14, 1.5, CONFIG.TelegraphStyle)
			sfx("Heavy", 0.6, 0.9)
			task.delay(1.5, function()
				vfx("Impact", tgt, 16, CONFIG.ImpactStyle)
				shake(1.8, 0.5, 18)
				if dummyInRadius(tgt, 14) then hitDummy(DMG.B, { heavy = true, stop = 0.12, shake = { 1.4, 0.4, 20 } }) end
			end)
		end },
	},
}

MOVES.N = {
	name = "Falling Blood Meteor Rain", total = 1.15, cancel = 0.78, faceUntil = 0.4,
	keys = {
		K(0.45, "out", { lean = -26, twist = 0, rx = 168, ry = 0, rz = 4, re = 16, rw = -10, st = -4, cr = 10 }),
		K(0.68, "in",  { lean = 10, twist = 0, rx = 128, ry = 0, rz = 2, re = 14, rw = -20, st = 10, cr = 34 }),
		K(0.92, "out", { lean = 8, twist = 0, rx = 124, ry = 0, rz = 2, re = 14, rw = -20, st = 10, cr = 32 }),
		K(1.15, "io"),
	},
	events = {
		{ 0.45, function()
			local tgt = groundTarget(18)
			setTrail(1)
			vfx("MeteorFall", tgt + Vector3.new(26, 110, -18), tgt, 1.25, 13)
			sfx("Heavy", 0.7, 0.7)
			task.delay(1.25, function()
				shake(2.4, 0.7, 16)
				if dummyInRadius(tgt, 13) then hitDummy(DMG.N, { heavy = true, stop = 0.14, shake = { 1.8, 0.5, 18 } }) end
			end)
		end },
	},
}

MOVES.M = {
	name = "Phase Transformation Burst", total = 1.3, cancel = 1.0, faceUntil = 0.3,
	keys = {
		K(0.40, "out", { lean = 38, twist = 0, rx = 24, ry = 0, rz = 6, re = 118, rw = 0, st = -30, cr = 64 }),
		K(0.62, "in",  { lean = -30, twist = 0, rx = 165, ry = 0, rz = 6, re = 14, rw = -10, st = 6, cr = 6 }),
		K(1.00, "out", { lean = -26, twist = 0, rx = 160, ry = 0, rz = 6, re = 16, rw = -10, st = 6, cr = 10 }),
		K(1.30, "io"),
	},
	events = {
		{ 0.62, function()
			local root = state.root
			setTrail(3)
			if not vfx("PhaseTransition", root, state.char) then vfx("PhaseTransition", root.Position, state.char) end
			vfx("Impact", groundAt(root.Position), 24, CONFIG.ImpactStyle)
			shake(2.0, 0.6, 16)
			sfx("Heavy", 1, 0.5)
			if dummyInRadius(root.Position, 45) then
				hitDummy(DMG.M, { heavy = true, stop = 0.14, shake = { 1.6, 0.45, 18 } })
			end
		end },
	},
}

MOVES.Q = {
	name = "Dodge", total = 0.46, cancel = 0.30, noFace = true, ignoreStop = true, step = { 0.02, 0.32, 54 },
	keys = {
		K(0.12, "out", { lean = 40, twist = 0, rx = 14, ry = 0, rz = 4, re = 96, rw = 0, st = 34, cr = 60 }),
		K(0.46, "io"),
	},
	onStart = function(ctx)
		local md = state.hum.MoveDirection
		if md.Magnitude > 0.1 then
			ctx.dir = flat(md).Unit
		else
			ctx.dir = -safeUnit(flat(state.root.CFrame.LookVector), Vector3.new(0, 0, -1))
		end
		vfx("Dodge", state.char, state.root, ctx.dir, 0.4)
		sfx("Slash", 0.35, 1.4)
	end,
	stepDir = function(ctx) return ctx.dir end,
}

----------------------------------------------------------------------
-- 10. EXECUTOR: input buffer, facing, forward momentum
----------------------------------------------------------------------
local function setupMomentum(root)
	local ok = pcall(function()
		local att = Instance.new("Attachment")
		att.Name = "SanguineMomentumAtt"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "SanguineMomentum"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(1e5, 0, 1e5)
		lv.VectorVelocity = Vector3.zero
		lv.Enabled = false
		lv.Parent = root
		state.lv = lv
	end)
	if not ok then state.lv = nil end
end

local function setMomentum(v)
	local root = state.root
	if not root then return end
	local lv = state.lv
	if lv and lv.Parent then
		if v.Magnitude < 0.01 then
			lv.Enabled = false
			lv.VectorVelocity = Vector3.zero
		else
			lv.VectorVelocity = Vector3.new(v.X, 0, v.Z)
			lv.Enabled = true
		end
	else
		local cur = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, cur.Y, v.Z)
	end
end

local function aimDir()
	local root = state.root
	if dummy and not dummy.dead then
		local to = flat(dummy.home.Position - root.Position)
		if to.Magnitude <= CONFIG.AutoFaceRange and to.Magnitude > 0.5 then return to.Unit end
	end
	local cam = Workspace.CurrentCamera
	if cam then
		local l = flat(cam.CFrame.LookVector)
		if l.Magnitude > 0.05 then return l.Unit end
	end
	return nil
end

local function faceToward(dir, rate, dt)
	local root = state.root
	local look = flat(root.CFrame.LookVector)
	if look.Magnitude < 1e-3 then return end
	local nd = look.Unit:Lerp(dir, 1 - math.exp(-rate * dt))
	if nd.Magnitude < 1e-3 then return end
	local pos = root.Position
	root.CFrame = CFrame.lookAt(pos, pos + nd.Unit)
end

local function executeMove(move)
	local ctx = { fired = {} }
	local from = {}
	for _, k in ipairs(POSE_KEYS) do from[k] = state.pose[k] end   -- blend from wherever we are now
	local keys = { { t = 0, pose = from, ease = "lin" } }
	for _, kf in ipairs(move.keys) do keys[#keys + 1] = kf end
	local t0 = state.clock
	state.anim = { keys = keys, t0 = t0 }
	if move.onStart then move.onStart(ctx) end
	local events = move.events or {}
	local last = t0
	local pow = move.stepPow or 1.15
	local first = true

	while state.alive do
		RunService.Heartbeat:Wait()
		local now = state.clock
		local dt = now - last
		last = now
		local t = now - t0

		for i, ev in ipairs(events) do
			if not ctx.fired[i] and t >= ev[1] then
				ctx.fired[i] = true
				local ok, err = pcall(ev[2], ctx)
				if not ok then warnOnce("event:" .. move.name, err) end
			end
		end

		if not move.noFace and t <= (move.faceUntil or 0.3) then
			local dir = aimDir()
			if dir then faceToward(dir, first and 40 or 16, math.max(dt, 1 / 60)) end
		end
		first = false

		if move.step then
			local s0, s1, sp = move.step[1], move.step[2], move.step[3]
			if t >= s0 and t <= s1 then
				local u = (t - s0) / (s1 - s0)
				local dir = move.stepDir and move.stepDir(ctx) or flat(state.root.CFrame.LookVector)
				dir = safeUnit(dir, Vector3.new(0, 0, -1)).Unit
				local speed = sp * (1 - u) ^ pow
				if dummy and not dummy.dead and not move.ignoreStop then
					local to = flat(dummy.home.Position - state.root.Position)
					if to.Magnitude < CONFIG.StopDistance and dir:Dot(to.Unit) > 0.2 then speed = 0 end
				end
				setMomentum(dir * speed)
			elseif t > s1 and not ctx.stopped then
				ctx.stopped = true
				setMomentum(Vector3.zero)
			end
		end

		local nxt = state.queue[1]
		if nxt and (t >= move.cancel or (nxt == "Q" and t >= move.cancel * 0.5)) then break end
		if t >= move.total then break end
	end
	setMomentum(Vector3.zero)
	state.lastEnd = os.clock()
end

local function resolveMove(req)
	if req == "combo" then
		if os.clock() - state.lastEnd > CONFIG.ComboReset or state.combo >= 3 then state.combo = 0 end
		state.combo = state.combo + 1
		return MOVES["C" .. state.combo]
	end
	state.combo = 0
	return MOVES[req]
end

local function pump()
	if state.running or not state.alive then return end
	state.running = true
	task.spawn(function()
		local hum = state.hum
		hum.AutoRotate = false
		hum.WalkSpeed = 0
		while state.alive and #state.queue > 0 do
			local req = table.remove(state.queue, 1)
			local move = resolveMove(req)
			if move then
				local ok, err = pcall(executeMove, move)
				if not ok then
					warnOnce("move:" .. tostring(req), err)
					setMomentum(Vector3.zero)
				end
			end
		end
		if hum.Parent then
			hum.AutoRotate = true
			hum.WalkSpeed = state.baseWalk
		end
		state.anim = nil
		state.lastEnd = os.clock()
		state.running = false
	end)
end

local function enqueue(req)
	if not state.alive then return end
	if #state.queue >= CONFIG.QueueLimit then return end
	if req == "Q" then
		table.insert(state.queue, 1, req)   -- dodge jumps the line
	else
		table.insert(state.queue, req)
	end
	pump()
end

----------------------------------------------------------------------
-- 11. CHARACTER BINDING, INPUT, MAIN LOOPS
----------------------------------------------------------------------
local function unbind()
	for _, c in ipairs(state.conns) do c:Disconnect() end
	state.conns = {}
	state.alive = false
	state.queue = {}
	state.anim = nil
	state.running = false
	state.rig = nil
	state.lv = nil
	state.poseErrors = 0
	if state.sword and state.sword.model then state.sword.model:Destroy() end
	state.sword = nil
	for _, k in ipairs(POSE_KEYS) do state.pose[k] = STANCE[k] end
end

local function bindCharacter(char)
	unbind()
	local hum = char:WaitForChild("Humanoid", 15)
	local root = char:WaitForChild("HumanoidRootPart", 15)
	if not hum or not root then return end
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	if r15 then
		char:WaitForChild("UpperTorso", 15)
		char:WaitForChild("RightHand", 15)
		char:WaitForChild("LeftHand", 15)
	else
		char:WaitForChild("Torso", 15)
		char:WaitForChild("Right Arm", 15)
	end

	local rig, missing
	for _ = 1, 40 do   -- joints can appear a moment late (AnimationConstraint rigs)
		rig, missing = buildRig(char, hum)
		if rig then break end
		task.wait(0.1)
	end
	if not rig then
		warn("[Sanguine] Could not find rig joint '" .. tostring(missing) .. "'. Joints found on this character:")
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then print("   ", d.ClassName, d.Name) end
		end
		return
	end

	state.char, state.hum, state.root, state.rig = char, hum, root, rig
	state.baseWalk = hum.WalkSpeed > 0 and hum.WalkSpeed or 16
	setupMomentum(root)
	state.sword = buildSword(char, rig)
	state.alive = true
	state.lastEnd = 0
	state.combo = 0

	table.insert(state.conns, hum.Died:Connect(function()
		state.alive = false
		state.queue = {}
		setMomentum(Vector3.zero)
	end))

	if not dummy or not dummy.model.Parent then spawnDummy() end
	print(string.format("[Sanguine] Ready (%s rig). Z/Click combo, X C V B N M, Q dodge.", r15 and "R15" or "R6"))
end

local KEYMAP = {
	[Enum.KeyCode.Z] = "combo", [Enum.KeyCode.X] = "X", [Enum.KeyCode.C] = "C", [Enum.KeyCode.V] = "V",
	[Enum.KeyCode.B] = "B", [Enum.KeyCode.N] = "N", [Enum.KeyCode.M] = "M", [Enum.KeyCode.Q] = "Q",
}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		enqueue("combo")
	elseif input.UserInputType == Enum.UserInputType.Keyboard then
		local req = KEYMAP[input.KeyCode]
		if req then enqueue(req) end
	end
end)

-- pose evaluation + application. We write on BOTH PreRender and PreSimulation so the
-- pose wins over the Animate script on classic Motor6D rigs and on AnimationConstraint rigs.
RunService.PreRender:Connect(function(dt)
	if not state.alive then return end
	state.actW = state.actW + ((state.running and 1 or 0) - state.actW) * (1 - math.exp(-dt * 8))
	if state.anim then
		samplePose(state.anim.keys, state.clock - state.anim.t0, state.pose)
	else
		local a = 1 - math.exp(-dt * 9)
		for _, k in ipairs(POSE_KEYS) do
			state.pose[k] = state.pose[k] + (STANCE[k] - state.pose[k]) * a
		end
	end
	applyPoseSafe()
end)
RunService.PreSimulation:Connect(applyPoseSafe)

RunService.Heartbeat:Connect(function(dt)
	local scale = (os.clock() < state.stopUntil) and 0.06 or 1   -- hit-stop freezes the swing
	state.clock = state.clock + dt * scale
	updateSword(dt, os.clock())
	updateDummy(dt)
end)

hud = buildHUD()
player.CharacterAdded:Connect(function(char)
	task.spawn(function()
		local ok, err = pcall(bindCharacter, char)
		if not ok then warn("[Sanguine] bind failed: " .. tostring(err)) end
	end)
end)
if player.Character then
	task.spawn(function()
		local ok, err = pcall(bindCharacter, player.Character)
		if not ok then warn("[Sanguine] bind failed: " .. tostring(err)) end
	end)
end

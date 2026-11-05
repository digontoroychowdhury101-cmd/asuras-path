--!strict
-- Drives a skinned boss on this client: every limb's bone follows its R15 limb, every garment bone follows the cloth simulation (ClothSim). Cosmetic only: nothing here touches
-- gameplay, and the server never reads a bone. One session per tagged skin (BossSkin.attach tags it), so a phase swap, reset, respawn, streamed-out model or destroyed actor ends its
-- session through the tag itself; there is nothing else to clean up. Graphics tier and reduced effects choose the simulation rate, never whether the body moves.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Sim = require(Shared.ClothSim)
local Rigs = require(Shared.BossRigs)
local Comfort = require(Shared.EffectsPreference) :: any
local PresentationData = require(Shared.ShenPresentationData)

local Cloth = {}
Cloth.Tag = "AsuraSkinnedBoss"
local FAR, VERY_FAR, TELEPORT = 160, 320, 60
Cloth.Rates = table.freeze({ Low = { Step = 1 / 30, Passes = 1 }, Mid = { Step = 1 / 60, Passes = 2 }, High = { Step = 1 / 60, Passes = 3 } })

type Session = { Skin: Model, Actor: Model, Root: BasePart, Bone: Bone, State: any, Limbs: { BasePart }, RestInverse: { CFrame }, LimbBones: { Bone }, LimbAt: { CFrame }, LimbAtInverse: { CFrame },
	ClothBones: { Bone }, ClothAtInverse: { CFrame }, M: { number }, Clock: number, Last: Vector3?, HitMark: any }
local sessions: { [Model]: Session } = {}
local waiting: { [Model]: boolean } = {}
local beat: RBXScriptConnection? = nil

local function clothData(template: string): any
	local look, phase = string.match(template, "^AsuraBoss_(.+)_P(%d)$")
	if look == "GrandmasterShen" then return require(Shared.ShenClothData)[tonumber(phase) :: number] end
	return nil
end

-- Everything a frame needs, or nil while the actor is still streaming in.
local function build(skin: Model): Session?
	local actor = skin.Parent
	if not actor or not actor:IsA("Model") then return nil end
	local template = skin:GetAttribute("Template")
	if type(template) ~= "string" then return nil end
	local data, def = clothData(template), (Rigs.ByTemplate :: any)[template]
	local root = actor:FindFirstChild("HumanoidRootPart")
	if not data or not def or not root or not root:IsA("BasePart") then return nil end
	local found: { [string]: Bone } = {}
	for _, d in skin:GetDescendants() do
		if d:IsA("Bone") then found[d.Name] = d end
	end
	local rootBone = found.Root
	if not rootBone then return nil end
	local scale = actor:GetScale()
	local rest = Rigs.rest(actor, def)
	local s: Session = { Skin = skin, Actor = actor, Root = root, Bone = rootBone, State = Sim.new(data, scale), Limbs = {}, RestInverse = {}, LimbBones = {}, LimbAt = {}, LimbAtInverse = {},
		ClothBones = {}, ClothAtInverse = {}, M = table.create(#data.limbs * 12, 0), Clock = 0, Last = nil }
	for i, name in data.limbs do
		local limb = actor:FindFirstChild(name)
		local bone = found["Sk_" .. name]
		if not limb or not limb:IsA("BasePart") then return nil end
		if name == "Glaive" then -- the weapon is a collider for the cloth; it has its own joint and no skin bone
			s.Limbs[i], s.RestInverse[i] = limb, CFrame.new((def.Helpers :: any)[1].At * scale):Inverse()
			continue
		end
		if not bone or not rest[name] then return nil end
		s.Limbs[i], s.RestInverse[i], s.LimbBones[i] = limb, rest[name]:Inverse(), bone
		s.LimbAt[i], s.LimbAtInverse[i] = bone.CFrame, bone.CFrame:Inverse()
	end
	for k, f in s.State.bones do
		local info = data.bones[f.bone + 1]
		local bone = found[info.name]
		if not bone then return nil end
		s.ClothBones[k], s.ClothAtInverse[k] = bone, bone.CFrame:Inverse()
	end
	return s
end

local function savedQuality(): any
	return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
end

local function rates(): any
	local ok, value = pcall(savedQuality)
	return (Cloth.Rates :: any)[PresentationData.tier(if ok and type(value) == "number" then value else 0, Comfort.reduced())]
end

local function run(s: Session, dt: number, rate: any, eye: Vector3)
	local M, limbs, inverse = s.M, s.Limbs, s.RestInverse
	local rootInverse = s.Bone.WorldCFrame:Inverse()
	local position = s.Root.Position
	local away = (position - eye).Magnitude
	for i = 1, #limbs do
		local d = limbs[i].CFrame * inverse[i]
		local o = (i - 1) * 12
		M[o + 1], M[o + 2], M[o + 3], M[o + 4], M[o + 5], M[o + 6], M[o + 7], M[o + 8], M[o + 9], M[o + 10], M[o + 11], M[o + 12] = d:GetComponents()
		local limbBone = s.LimbBones[i]
		if limbBone then limbBone.Transform = s.LimbAtInverse[i] * rootInverse * d * s.LimbAt[i] end
	end
	-- a teleport is not motion: the cloth arrives with him rather than streaming across the map
	if s.Last and (position - s.Last).Magnitude > TELEPORT then Sim.reset(s.State, M) end
	s.Last = position
	local step = rate.Step
	-- a blow lands: the robe takes it the way the body does (AIService: AsuraHitFrom, AsuraHitMark)
	local mark = s.Actor:GetAttribute("AsuraHitMark")
	if mark ~= s.HitMark then
		local from = s.Actor:GetAttribute("AsuraHitFrom")
		if s.HitMark ~= nil and typeof(from) == "Vector3" then Sim.impulse(s.State, -from.X, 0.15, -from.Z, 11, step) end
		s.HitMark = mark
	end
	if away > VERY_FAR then return end -- too far to read: the body still follows, the cloth rests on its last pose
	if away > FAR then step = math.max(step, 1 / 20) end
	s.Clock = math.min(s.Clock + dt, step * 3)
	local moved = false
	while s.Clock >= step do
		s.Clock -= step
		Sim.step(s.State, M, step, Sim.DefaultWind, rate.Passes)
		moved = true
	end
	if not moved then return end
	local State = s.State
	local X, Y, Z, R = State.x, State.y, State.z, State.R
	for k, f in State.bones do
		local o = (k - 1) * 9
		local i = f.i
		s.ClothBones[k].Transform = s.ClothAtInverse[k] * rootInverse * CFrame.new(X[i], Y[i], Z[i], R[o + 1], R[o + 2], R[o + 3], R[o + 4], R[o + 5], R[o + 6], R[o + 7], R[o + 8], R[o + 9])
	end
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for skin in waiting do
		local s = build(skin)
		if s then
			sessions[skin], waiting[skin] = s, nil
		end
	end
	local rate = rates()
	for skin, s in sessions do
		if not s.Root.Parent or not s.Bone.Parent then
			sessions[skin], waiting[skin] = nil, true -- part of him streamed out; picks up when it returns
			continue
		end
		run(s, dt, rate, eye)
	end
	if not next(sessions) and not next(waiting) and beat then
		beat:Disconnect()
		beat = nil
	end
end

local function add(item: Instance)
	if not item:IsA("Model") then return end
	waiting[item] = true
	if not beat then beat = RunService.Heartbeat:Connect(step) end
end

local function remove(item: Instance)
	if not item:IsA("Model") then return end
	sessions[item], waiting[item] = nil, nil
end

local started = false
function Cloth.start()
	if started then return end
	started = true
	CollectionService:GetInstanceAddedSignal(Cloth.Tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Cloth.Tag):Connect(remove)
	for _, item in CollectionService:GetTagged(Cloth.Tag) do add(item) end
end

return Cloth

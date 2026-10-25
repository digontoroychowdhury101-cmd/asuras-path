--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/CreatureMotion
-- Local procedural poses for creature bosses (batches 12-13) until authored rig animations are
-- imported. Every attire piece with an AsuraJoint is turned about its hinge (AsuraPivot, a
-- fraction of the piece's size) by rewriting its Weld.C1 on this client only, so the server's
-- welds, the root and the rewound hurtboxes never move. Legs trot diagonally with ground speed,
-- the jaw opens for grabs and breath, tails sweep for the tail strike, wings beat while airborne
-- (BossMotion anchors the root in flight) and fold on the ground, and orbiting charms circle.
local Workspace = game:GetService("Workspace")

local Motion = {}
Motion.__index = Motion
Motion.Range = 260 -- studs from the camera beyond which poses rest

type Joint = { Weld: Weld, Part: BasePart, Role: string, Hinge: Vector3, Parent: Vector3? }
type Rig = { Joints: { Joint }, Gait: number, Count: number, Recheck: number }
export type Controller = typeof(setmetatable({} :: { State: any, Rigs: { [Model]: Rig }, Clock: number }, Motion))

local LEG_PHASE = { LegFL = 0, LegHR = 0, LegFR = math.pi, LegHL = math.pi }

function Motion.new(state: any): Controller
	return setmetatable({ State = state, Rigs = {}, Clock = 0 }, Motion)
end

-- Attire replicates piece by piece, so the joint list is rebuilt whenever the piece count changes.
local function collect(attire: Instance, previous: Rig?, now: number): Rig
	local children = attire:GetChildren()
	if previous and previous.Count == #children then previous.Recheck = now + 1; return previous end
	local joints: { Joint } = {}
	for _, part in children do
		local role, hinge, weld = part:GetAttribute("AsuraJoint"), part:GetAttribute("AsuraPivot"), part:FindFirstChild("AsuraBind")
		if part:IsA("BasePart") and type(role) == "string" and typeof(hinge) == "Vector3" and weld and weld:IsA("Weld") then
			local parent = part:GetAttribute("AsuraPivot2")
			table.insert(joints, { Weld = weld, Part = part, Role = role, Hinge = hinge, Parent = if typeof(parent) == "Vector3" then parent else nil })
		end
	end
	return { Joints = joints, Gait = if previous then previous.Gait else 0, Count = #children, Recheck = now + 1 }
end

-- Pure: the hinge rotation (pitch, yaw, roll in radians) for one joint role.
function Motion.angles(role: string, t: number, gait: number, stride: number, attack: string?, airborne: boolean): (number, number, number)
	local leg = LEG_PHASE[role]
	if leg then return math.sin(gait + leg) * math.rad(28) * stride, 0, 0 end
	if role == "Neck" then
		local lunge = if attack == "PerilousGrab" or attack == "Breath" then math.rad(-12) elseif attack then math.rad(-6) else 0
		return math.sin(t * 1.3) * math.rad(3) + lunge, 0, 0
	elseif role == "Jaw" then
		return if attack == "PerilousGrab" or attack == "Breath" then math.rad(28) else math.rad(3) + math.sin(t * 2.1) * math.rad(2), 0, 0
	elseif role == "Mane" then
		return 0, 0, math.sin(t * 1.7) * math.rad(4)
	elseif string.sub(role, 1, 4) == "Tail" then
		local k = tonumber(string.sub(role, 5)) or 1
		local swing = if attack == "Tail" then math.rad(34) else math.rad(8 + k * 3)
		return 0, math.sin(t * (if attack == "Tail" then 7 else 2) - k * 0.6) * swing, 0
	elseif role == "WingL" or role == "WingR" or role == "WingTipL" or role == "WingTipR" then
		local side = if string.sub(role, -1) == "L" then 1 else -1
		local tip = if string.find(role, "Tip") then 0.6 else 1 -- on top of the inner beat
		local beat = if airborne then math.sin(t * 7) * math.rad(34) else math.rad(-14) + math.sin(t * 1.4) * math.rad(3)
		return 0, 0, beat * side * tip
	elseif role == "Orbit" then
		return 0, t * math.rad(40), 0
	end
	return 0, 0, 0
end

function Motion.Update(self: Controller, dt: number)
	self.Clock += dt
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for _, entity in self.State.Entities do
		local model, root = entity.Model, entity.Root
		local attire = if entity.Kind == "Enemy" and root and model:GetAttribute("AsuraCostume") ~= nil then model:FindFirstChild("AsuraAttire") else nil
		if not attire or not root or (root.Position - eye).Magnitude > Motion.Range then continue end
		local known = self.Rigs[model]
		if model:GetAttribute("AsuraAuthoredMotion") == true then -- an authored track owns the joints (BossAnimations)
			if known then for _, joint in known.Joints do joint.Weld.C1 = CFrame.identity end end
			self.Rigs[model] = nil
			continue
		end
		local rig: Rig = if known and self.Clock < known.Recheck then known else collect(attire, known, self.Clock)
		self.Rigs[model] = rig
		if #rig.Joints == 0 then continue end
		local scale = math.max(model:GetScale(), 0.1)
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude / scale
		rig.Gait += dt * speed * 0.9
		local stride = math.clamp(speed / 10, 0, 1)
		local attack = model:GetAttribute("AsuraBossAttack")
		local airborne = root.Anchored or math.abs(velocity.Y) > 12
		for _, joint in rig.Joints do
			local pitch, yaw, roll = Motion.angles(joint.Role, self.Clock, rig.Gait, stride, if type(attack) == "string" then attack else nil, airborne)
			local hinge = joint.Hinge * joint.Part.Size
			local pose = CFrame.new(hinge) * CFrame.Angles(pitch, yaw, roll) * CFrame.new(-hinge)
			if joint.Parent then -- a wing tip also rides its inner wing's beat about the parent hinge
				local inner = joint.Parent * joint.Part.Size
				local p2, y2, r2 = Motion.angles(string.gsub(joint.Role, "Tip", "") :: string, self.Clock, rig.Gait, stride, nil, airborne)
				pose = CFrame.new(inner) * CFrame.Angles(p2, y2, r2) * CFrame.new(-inner) * pose
			end
			joint.Weld.C1 = pose:Inverse()
		end
	end
	for model in self.Rigs do
		if not model.Parent then self.Rigs[model] = nil end
	end
end

function Motion.Destroy(self: Controller)
	for _, rig in self.Rigs do
		for _, joint in rig.Joints do joint.Weld.C1 = CFrame.identity end
	end
	table.clear(self.Rigs)
end

return Motion

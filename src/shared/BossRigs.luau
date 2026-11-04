--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/BossRigs
-- A production skin whose sculpt does not share the stock R15 joint points declares where its joints really are. The limb
-- parts stay exactly where they are (hurtboxes, the humanoid's height and every bound skin piece are untouched); only the pivots
-- move, so a clip turns his shoulder about his shoulder and a zero Transform shows the sculpt as it was designed. Helper bones are
-- extra invisible joints the stock rig lacks, for rigid armour and cloth that must follow a limb only part of the way.
-- Positions are clip space: HumanoidRootPart space at scale 1. Source: tools/blender/bull_import/rigdef.py (export checks them equal).
export type Joint = { Bone: string, Parent: string, Motor: string, At: Vector3 }
export type Helper = { Bone: string, Parent: string, At: Vector3 }
export type Def = { Joints: { Joint }, Helpers: { Helper } }

local V = Vector3.new
local Rigs = {}

Rigs.ByTemplate = {
	AsuraBoss_IronBull = {
		Joints = { -- parents first
			{ Bone = "LowerTorso", Parent = "HumanoidRootPart", Motor = "Root", At = V(0.10, -0.25, 0.05) },
			{ Bone = "UpperTorso", Parent = "LowerTorso", Motor = "Waist", At = V(0.10, 0.08, 0.05) },
			{ Bone = "Head", Parent = "UpperTorso", Motor = "Neck", At = V(0.16, 1.42, -0.20) },
			{ Bone = "RightUpperArm", Parent = "UpperTorso", Motor = "RightShoulder", At = V(1.22, 0.90, 0.10) },
			{ Bone = "RightLowerArm", Parent = "RightUpperArm", Motor = "RightElbow", At = V(1.42, 0.05, 0.12) },
			{ Bone = "RightHand", Parent = "RightLowerArm", Motor = "RightWrist", At = V(1.38, -0.58, 0.02) },
			{ Bone = "LeftUpperArm", Parent = "UpperTorso", Motor = "LeftShoulder", At = V(-1.10, 0.90, 0.10) },
			{ Bone = "LeftLowerArm", Parent = "LeftUpperArm", Motor = "LeftElbow", At = V(-1.33, 0.02, 0.10) },
			{ Bone = "LeftHand", Parent = "LeftLowerArm", Motor = "LeftWrist", At = V(-1.17, -0.58, -0.02) },
			{ Bone = "RightUpperLeg", Parent = "LowerTorso", Motor = "RightHip", At = V(0.62, -0.80, 0.05) },
			{ Bone = "RightLowerLeg", Parent = "RightUpperLeg", Motor = "RightKnee", At = V(1.00, -1.80, 0.10) },
			{ Bone = "RightFoot", Parent = "RightLowerLeg", Motor = "RightAnkle", At = V(1.12, -2.75, 0.20) },
			{ Bone = "LeftUpperLeg", Parent = "LowerTorso", Motor = "LeftHip", At = V(-0.42, -0.80, 0.05) },
			{ Bone = "LeftLowerLeg", Parent = "LeftUpperLeg", Motor = "LeftKnee", At = V(-0.80, -1.80, 0.10) },
			{ Bone = "LeftFoot", Parent = "LeftLowerLeg", Motor = "LeftAnkle", At = V(-1.08, -2.75, 0.20) },
		},
		Helpers = {
			{ Bone = "RightPauldron", Parent = "UpperTorso", At = V(0.86, 1.34, 0.10) },
			{ Bone = "LeftPauldron", Parent = "UpperTorso", At = V(-0.70, 1.34, 0.10) },
			{ Bone = "ClothFront", Parent = "LowerTorso", At = V(0.27, -0.55, -0.55) },
			{ Bone = "ClothBack", Parent = "LowerTorso", At = V(0.15, -0.48, 0.62) },
		},
	} :: Def,
}

-- Moves the pivots on a live actor and builds its helper bones. Actors are AnimationConstraint rigs: Part1 = Part0 * Attachment0 *
-- Transform * Attachment1:Inverse(), so a pivot is a pair of rig attachments and moving both by the same joint point leaves the limb
-- where it was. Safe to repeat, because the rest frames read back from the attachments do not change. Returns false with a reason if
-- the actor is not the rig the definition expects.
function Rigs.apply(actor: Model, def: Def): (boolean, string?)
	local scale = actor:GetScale()
	local rest: { [string]: CFrame } = { HumanoidRootPart = CFrame.identity }
	local constraints: { [string]: AnimationConstraint } = {}
	for _, joint in def.Joints do
		local limb = actor:FindFirstChild(joint.Bone)
		local constraint = limb and limb:FindFirstChild(joint.Motor)
		local parent = rest[joint.Parent]
		if not constraint or not constraint:IsA("AnimationConstraint") or not parent or not constraint.Attachment0 or not constraint.Attachment1 then
			return false, joint.Bone .. " has no " .. joint.Motor .. " joint"
		end
		constraints[joint.Bone] = constraint
		rest[joint.Bone] = parent * constraint.Attachment0.CFrame * constraint.Attachment1.CFrame:Inverse()
	end
	for _, joint in def.Joints do
		local at = CFrame.new(joint.At * scale)
		local constraint = constraints[joint.Bone]
		constraint.Attachment0.CFrame, constraint.Attachment1.CFrame = rest[joint.Parent]:Inverse() * at, rest[joint.Bone]:Inverse() * at
	end
	local root = actor:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false, "no HumanoidRootPart" end
	local rootFrame = root.CFrame
	for _, helper in def.Helpers do
		local parent = actor:FindFirstChild(helper.Parent)
		local parentRest = rest[helper.Parent]
		if not parent or not parent:IsA("BasePart") or not parentRest then return false, helper.Bone .. " has no parent " .. helper.Parent end
		if actor:FindFirstChild(helper.Bone) then continue end
		local at = CFrame.new(helper.At * scale)
		local part = Instance.new("Part")
		part.Name, part.Size, part.Transparency, part.CastShadow = helper.Bone, Vector3.one * 0.1, 1, false
		part.Massless, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.CFrame = rootFrame * at
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = helper.Bone .. "RigAttachment", helper.Bone .. "RigAttachment"
		a0.CFrame, a0.Parent = parentRest:Inverse() * at, parent
		a1.Parent = part
		local constraint = constraints[helper.Parent]:Clone() -- the same kinematic settings as his other joints
		constraint.Name, constraint.Attachment0, constraint.Attachment1 = helper.Bone, a0, a1
		constraint.Parent = part
		part.Parent = actor
	end
	return true
end

return Rigs

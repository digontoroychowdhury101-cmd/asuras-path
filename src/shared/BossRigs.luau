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
Rigs.TurnRate = 220 -- degrees per second: the turn his clips step at (BossAnimationRules.TurnRate)

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
	-- Grandmaster Shen: one rig per sculpt, from tools/blender/shen_import/rigdef.py. The limbs never move, so the two forms share every skin weld and the swap only re-points the pivots;
	-- the glaive helper phase 1 built stays (its part, joint and welds) and apply() re-points it to this form's glaive point.
	AsuraBoss_GrandmasterShen_P1 = {
		Joints = { -- parents first
			{ Bone = "LowerTorso", Parent = "HumanoidRootPart", Motor = "Root", At = V(-0.09, -0.25, -0.10) },
			{ Bone = "UpperTorso", Parent = "LowerTorso", Motor = "Waist", At = V(-0.09, 0.25, -0.10) },
			{ Bone = "Head", Parent = "UpperTorso", Motor = "Neck", At = V(-0.12, 1.65, -0.25) },
			{ Bone = "RightUpperArm", Parent = "UpperTorso", Motor = "RightShoulder", At = V(0.64, 1.14, -0.03) },
			{ Bone = "RightLowerArm", Parent = "RightUpperArm", Motor = "RightElbow", At = V(0.96, 0.38, -0.03) },
			{ Bone = "RightHand", Parent = "RightLowerArm", Motor = "RightWrist", At = V(1.06, -0.20, -0.42) },
			{ Bone = "LeftUpperArm", Parent = "UpperTorso", Motor = "LeftShoulder", At = V(-0.80, 1.14, 0.00) },
			{ Bone = "LeftLowerArm", Parent = "LeftUpperArm", Motor = "LeftElbow", At = V(-1.12, 0.31, 0.00) },
			{ Bone = "LeftHand", Parent = "LeftLowerArm", Motor = "LeftWrist", At = V(-1.15, -0.26, -0.28) },
			{ Bone = "RightUpperLeg", Parent = "LowerTorso", Motor = "RightHip", At = V(0.33, -0.58, -0.10) },
			{ Bone = "RightLowerLeg", Parent = "RightUpperLeg", Motor = "RightKnee", At = V(0.68, -1.85, 0.02) },
			{ Bone = "RightFoot", Parent = "RightLowerLeg", Motor = "RightAnkle", At = V(0.95, -2.85, 0.12) },
			{ Bone = "LeftUpperLeg", Parent = "LowerTorso", Motor = "LeftHip", At = V(-0.45, -0.55, -0.10) },
			{ Bone = "LeftLowerLeg", Parent = "LeftUpperLeg", Motor = "LeftKnee", At = V(-0.66, -1.85, 0.02) },
			{ Bone = "LeftFoot", Parent = "LeftLowerLeg", Motor = "LeftAnkle", At = V(-0.72, -2.85, 0.12) },
		},
		Helpers = {
			{ Bone = "Glaive", Parent = "LowerTorso", At = V(0.96, -0.42, -0.45) },
		},
	} :: Def,
	AsuraBoss_GrandmasterShen_P2 = {
		Joints = { -- parents first
			{ Bone = "LowerTorso", Parent = "HumanoidRootPart", Motor = "Root", At = V(-0.03, -0.25, -0.05) },
			{ Bone = "UpperTorso", Parent = "LowerTorso", Motor = "Waist", At = V(-0.03, 0.30, -0.05) },
			{ Bone = "Head", Parent = "UpperTorso", Motor = "Neck", At = V(0.00, 1.35, -0.20) },
			{ Bone = "RightUpperArm", Parent = "UpperTorso", Motor = "RightShoulder", At = V(0.74, 1.08, 0.00) },
			{ Bone = "RightLowerArm", Parent = "RightUpperArm", Motor = "RightElbow", At = V(1.09, 0.40, -0.10) },
			{ Bone = "RightHand", Parent = "RightLowerArm", Motor = "RightWrist", At = V(1.09, -0.20, -0.28) },
			{ Bone = "LeftUpperArm", Parent = "UpperTorso", Motor = "LeftShoulder", At = V(-0.80, 1.08, 0.00) },
			{ Bone = "LeftLowerArm", Parent = "LeftUpperArm", Motor = "LeftElbow", At = V(-1.05, 0.18, -0.13) },
			{ Bone = "LeftHand", Parent = "LeftLowerArm", Motor = "LeftWrist", At = V(-1.18, -0.39, -0.42) },
			{ Bone = "RightUpperLeg", Parent = "LowerTorso", Motor = "RightHip", At = V(0.30, -0.58, -0.05) },
			{ Bone = "RightLowerLeg", Parent = "RightUpperLeg", Motor = "RightKnee", At = V(0.72, -1.72, 0.10) },
			{ Bone = "RightFoot", Parent = "RightLowerLeg", Motor = "RightAnkle", At = V(1.00, -2.79, 0.19) },
			{ Bone = "LeftUpperLeg", Parent = "LowerTorso", Motor = "LeftHip", At = V(-0.38, -0.55, -0.05) },
			{ Bone = "LeftLowerLeg", Parent = "LeftUpperLeg", Motor = "LeftKnee", At = V(-0.62, -1.72, 0.10) },
			{ Bone = "LeftFoot", Parent = "LeftLowerLeg", Motor = "LeftAnkle", At = V(-0.80, -2.79, 0.19) },
		},
		Helpers = {
			{ Bone = "Glaive", Parent = "LowerTorso", At = V(1.09, -0.39, -0.35) },
		},
	} :: Def,
}

-- The rest frame of each limb in root space, read from the rig's own joints, in studs at this actor's scale.
function Rigs.rest(actor: Model, def: Def): { [string]: CFrame }
	local rest: { [string]: CFrame } = { HumanoidRootPart = CFrame.identity }
	for _, joint in def.Joints do
		local limb = actor:FindFirstChild(joint.Bone)
		local constraint = limb and limb:FindFirstChild(joint.Motor)
		local parent = rest[joint.Parent]
		if constraint and constraint:IsA("AnimationConstraint") and parent and constraint.Attachment0 and constraint.Attachment1 then
			rest[joint.Bone] = parent * constraint.Attachment0.CFrame * constraint.Attachment1.CFrame:Inverse()
		end
	end
	return rest
end

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
		local at = CFrame.new(helper.At * scale)
		local existing = actor:FindFirstChild(helper.Bone)
		if existing then
			-- (2026-11-10) a helper an earlier form built keeps its part, joint and welds, but the pivot is this form's: phase 2 declares its own
			-- glaive point and its clips and weapon meshes are made about it. Skipping the helper left phase 2's glaive on phase 1's point, the
			-- whole weapon 0.17 off his grip in every phase 2 clip (Studio playback of the exported clips against the solver). Its part follows
			-- its joint, so what is welded to it moves with it; attach() swaps the skins in the same step.
			local joint = existing:FindFirstChild(helper.Bone)
			if joint and joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment0.Parent == parent then
				joint.Attachment0.CFrame = parentRest:Inverse() * at
			end
			continue
		end
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

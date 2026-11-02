--!strict
-- The one writer of a fighter's Motor6D.Transform after the Animator (TIMING_CONTRACT §8; RunService.PreSimulation,
-- once per frame, after animations were evaluated). Three corrections, always in this order, on the clip's output:
--   1. Inertialization. A new occurrence switches clip at full weight at once and the difference from the pose last
--      shown decays by a critically damped spring, so a link keeps its follow-through and momentum with no cross-fade
--      and no neutral between clips (Orange Duck spring.h inertialize_transition/update @ 57b7250; offset form as in
--      JLPM22 Inertialization.cs @ 35fc8ee).
--   2. Presentation step. A swing's body travels toward its blade path without moving the root: gameplay position,
--      collision and hurtboxes stay with the root, one movement owner per actor (StrikeTrajectories).
--   3. Foot contact. FootStep's plant or swing is solved onto the legs with an analytic two-bone IK, and the pelvis
--      drops only as far as the planted feet need (ALS-Refactored foot lock and pelvis offset @ b754d6f; see FootStep).
-- Cosmetic and local: Transform does not replicate and nothing here reaches authority.
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Timing = require(Shared.Simulation.AnimationTiming)
local Foot = require(Shared.Simulation.FootStep)

local Pose = {}
Pose.__index = Pose

local JOINTS: { { Part: string, Joint: string } } = {
	{ Part = "LowerTorso", Joint = "Root" }, { Part = "UpperTorso", Joint = "Waist" }, { Part = "Head", Joint = "Neck" },
	{ Part = "LeftUpperArm", Joint = "LeftShoulder" }, { Part = "LeftLowerArm", Joint = "LeftElbow" }, { Part = "LeftHand", Joint = "LeftWrist" },
	{ Part = "RightUpperArm", Joint = "RightShoulder" }, { Part = "RightLowerArm", Joint = "RightElbow" }, { Part = "RightHand", Joint = "RightWrist" },
	{ Part = "LeftUpperLeg", Joint = "LeftHip" }, { Part = "LeftLowerLeg", Joint = "LeftKnee" }, { Part = "LeftFoot", Joint = "LeftAnkle" },
	{ Part = "RightUpperLeg", Joint = "RightHip" }, { Part = "RightLowerLeg", Joint = "RightKnee" }, { Part = "RightFoot", Joint = "RightAnkle" },
}

local HALFLIFE = 0.045 -- seconds for a transition's pose offset to halve
local REST_ANGLE, REST_RATE = 1e-3, 1e-2 -- an offset below these has finished
local MAX_OFFSET_RATE = 25 -- radians/s of carried joint speed: a one-frame pop is not momentum
local MAX_PELVIS_DROP = 0.8 -- studs at scale 1
local LEG_MAX = 0.995 -- fraction of the full leg a solved leg may reach
local KNEE_MIN = 0.1 -- fraction of the shorter bone the hip-to-ankle span keeps, so the knee never folds through
local RAY_RANGE = 6
local STANCE_X, STANCE_Z = 0.55, 0.15 -- moving stance at scale 1: hip width, sword-side foot a little forward
local STANCE_BLEND_SPEED = 4 -- studs/s at which the clip's foot placement has fully given way to the moving stance
local LIFT_FLOOR = 0.02 -- studs: a clip's foot higher than its rest by more than this is lifted on purpose
local UPPER_AT_SCALE_1 = 0.9207 -- a standard R15 upper leg, hip joint to knee joint
local LEAN_MAX = math.rad(9) -- the body's tilt into its travel at full speed, relative to its facing
local LEAN_SPEED = 16 -- studs/s of travel that reaches LEAN_MAX
local LEAN_RATE = 12 -- how quickly the lean follows, per second

type Joint = {
	Motor: Motor6D, C0: CFrame, C1: CFrame,
	Input: CFrame, -- the Animator's value this frame
	Written: CFrame, -- what this module last wrote (an Animator that did not run leaves it in place)
	Out: CFrame, -- this frame's result
	Shown: CFrame, ShownPrevious: CFrame, -- the last two results written
	-- pose offset: rotation vector and its rate, plus translation for the root
	X: Vector3, V: Vector3, PX: Vector3, PV: Vector3, Active: boolean,
}

export type ActorPose = typeof(setmetatable({} :: {
	Model: Model, Root: BasePart,
	Joints: { [string]: Joint }, Order: { Joint },
	Transitioned: boolean,
	Step: Vector3,
	Feet: boolean, Plant: any, Ray: RaycastParams,
	Drop: number, DropV: number, Weight: number, LeanX: number, LeanZ: number,
	Upper: number, Lower: number, AnkleHeight: number, RestAnkleY: number,
	LastDt: number, RootWas: Vector3?, Velocity: Vector3,
	Released: boolean, Idle: boolean,
	Owner: boolean, -- the client's own character: physics moves its root after this write, so contact targets lead it
	ClipFeet: boolean, -- an action owns the stance: the clip's foot placement stays the neutral while moving
	Stats: { Transitions: number, Excess: number, Drift: number },
	Ground: { [string]: { At: Vector3, Y: number, Clock: number } },
}, Pose))

local function rotationVector(c: CFrame): Vector3
	local axis, angle = c:ToAxisAngle()
	if angle > math.pi then
		angle -= 2 * math.pi
	end
	return axis * angle
end

local function fromRotationVector(x: Vector3): CFrame
	local angle = x.Magnitude
	if angle < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(x / angle, angle)
end

local function decayVector(x: Vector3, v: Vector3, dt: number): (Vector3, Vector3)
	local xx, vx = Timing.decay(x.X, v.X, HALFLIFE, dt)
	local xy, vy = Timing.decay(x.Y, v.Y, HALFLIFE, dt)
	local xz, vz = Timing.decay(x.Z, v.Z, HALFLIFE, dt)
	return Vector3.new(xx, xy, xz), Vector3.new(vx, vy, vz)
end

-- Every R15 joint this model has, or nil when it is not an R15 fighter (a creature, a partial rig).
function Pose.attach(model: Model, root: BasePart, owner: boolean): ActorPose?
	local joints: { [string]: Joint } = {}
	local order: { Joint } = {}
	for _, spec in JOINTS do
		local part = model:FindFirstChild(spec.Part)
		local motor = part and part:FindFirstChild(spec.Joint)
		if not motor or not motor:IsA("Motor6D") then
			return nil
		end
		local identity = CFrame.identity
		local joint: Joint = { Motor = motor, C0 = motor.C0, C1 = motor.C1, Input = identity, Written = identity, Out = identity, Shown = identity, ShownPrevious = identity,
			X = Vector3.zero, V = Vector3.zero, PX = Vector3.zero, PV = Vector3.zero, Active = false }
		joints[spec.Joint] = joint
		table.insert(order, joint)
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { model }
	ray.IgnoreWater = true
	local self = setmetatable({ Model = model, Root = root, Joints = joints, Order = order, Transitioned = false, Step = Vector3.zero,
		Feet = false, Plant = Foot.new(), Ray = ray, Drop = 0, DropV = 0, Weight = 0, LeanX = 0, LeanZ = 0, Upper = 0, Lower = 0, AnkleHeight = 0, RestAnkleY = 0,
		LastDt = 1 / 60, RootWas = nil, Velocity = Vector3.zero, Released = false, Idle = false, Owner = owner, ClipFeet = false,
		Stats = { Transitions = 0, Excess = 0, Drift = 0 }, Ground = {} }, Pose)
	self:Measure()
	return self
end

-- Bone lengths, ankle height and the rest ankle height from the rig's own joints: they all scale with the model.
function Pose.Measure(self: ActorPose)
	local j = self.Joints
	for _, joint in self.Order do
		joint.C0, joint.C1 = joint.Motor.C0, joint.Motor.C1
	end
	self.Upper = (j.LeftKnee.C0.Position - j.LeftHip.C1.Position).Magnitude
	self.Lower = (j.LeftAnkle.C0.Position - j.LeftKnee.C1.Position).Magnitude
	local foot = j.LeftAnkle.Motor.Parent
	self.AnkleHeight = j.LeftAnkle.C1.Y + (if foot and foot:IsA("BasePart") then foot.Size.Y * 0.5 else 0)
	local pelvis = j.Root.C0 * j.Root.C1:Inverse()
	local upper = pelvis * j.LeftHip.C0 * j.LeftHip.C1:Inverse()
	local lower = upper * j.LeftKnee.C0 * j.LeftKnee.C1:Inverse()
	self.RestAnkleY = (lower * j.LeftAnkle.C0).Y
end

-- The next Apply starts a pose transition (a new occurrence, a seat, or anything else that jumps the clip).
function Pose.Transition(self: ActorPose)
	self.Transitioned = true
end

-- Root-space offset of the body from the root this frame (a swing's presentation step).
function Pose.SetStep(self: ActorPose, step: Vector3)
	self.Step = step
end

-- Feet follow contact states when true; follow the clip (dodge, airborne, teleport, KO) when false.
function Pose.SetFeet(self: ActorPose, enabled: boolean)
	self.Feet = enabled
end

-- Whether the current action's clip decides where the feet stand even while the body moves (a swing's authored step).
function Pose.SetClipFeet(self: ActorPose, clip: boolean)
	self.ClipFeet = clip
end

-- Stops every write once any offset has finished: a released body belongs to whatever comes next (dissolve, ragdoll).
function Pose.Release(self: ActorPose, released: boolean)
	self.Released = released
	if released then
		self.Feet, self.Step = false, Vector3.zero
	end
end

local function startTransition(self: ActorPose)
	self.Stats.Transitions += 1
	local span = math.max(self.LastDt, 1 / 240)
	for _, joint in self.Order do
		-- The pose last shown against this frame's new clip pose. Its speed comes from the last two frames shown; the new
		-- clip's own speed is in its pose from here on.
		joint.X = rotationVector((joint.Shown * joint.Input:Inverse()).Rotation)
		local rate = rotationVector((joint.Shown * joint.ShownPrevious:Inverse()).Rotation) / span
		joint.V = if rate.Magnitude > MAX_OFFSET_RATE then rate.Unit * MAX_OFFSET_RATE else rate
		joint.PX = joint.Shown.Position - joint.Input.Position
		joint.PV = (joint.Shown.Position - joint.ShownPrevious.Position) / span
		joint.Active = true
	end
end

local function groundBelow(self: ActorPose, key: string, x: number, y: number, z: number, now: number): number?
	-- One cast per foot per a few frames: a planted foot's ground does not change, a moving one's is re-read.
	local cached = self.Ground[key]
	local at = Vector3.new(x, y, z)
	if cached and now - cached.Clock < 0.05 and (cached.At - at).Magnitude < 0.5 then
		return cached.Y
	end
	local hit = Workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -RAY_RANGE - 2, 0), self.Ray)
	if not hit then
		return nil
	end
	self.Ground[key] = { At = at, Y = hit.Position.Y, Clock = now }
	return hit.Position.Y
end

-- Two-bone solve in root space: hip H, ankle target A. Writes the three leg joints. The knee stays on the side the
-- clip's own knee was on, so it can never flip, and the span is clamped so the leg neither locks out nor folds.
local function solveLeg(self: ActorPose, side: string, pelvis: CFrame, target: Vector3, footRotation: CFrame, blend: number)
	local j = self.Joints
	local hip, knee, ankle = j[side .. "Hip"], j[side .. "Knee"], j[side .. "Ankle"]
	local hipAt = (pelvis * hip.C0).Position
	local upperPart = pelvis * hip.C0 * hip.Input * hip.C1:Inverse()
	local lowerPart = upperPart * knee.C0 * knee.Input * knee.C1:Inverse()
	local clipKnee = (upperPart * knee.C0).Position
	local clipAnkle = (lowerPart * ankle.C0).Position

	local toTarget = target - hipAt
	local span = toTarget.Magnitude
	local upper, lower = self.Upper, self.Lower
	local longest = (upper + lower) * LEG_MAX
	local shortest = math.max(math.abs(upper - lower), math.min(upper, lower) * KNEE_MIN)
	if span > longest then
		self.Stats.Excess = math.max(self.Stats.Excess, span - longest)
	end
	span = math.clamp(span, shortest, longest)
	local direction = if toTarget.Magnitude > 1e-4 then toTarget.Unit else Vector3.new(0, -1, 0)

	-- The knee's side: the clip's own bend, or forward along the foot when the clip's leg is straight.
	local clipLeg = clipAnkle - hipAt
	local pole = clipKnee - (hipAt + clipLeg * ((clipKnee - hipAt):Dot(clipLeg) / math.max(clipLeg:Dot(clipLeg), 1e-4)))
	local forward = footRotation.LookVector
	if pole.Magnitude < 0.05 or pole.Unit:Dot(forward) < -0.2 then
		pole = forward
	end
	pole -= direction * pole:Dot(direction)
	pole = if pole.Magnitude > 1e-3 then pole.Unit else forward

	local along = (upper * upper - lower * lower + span * span) / (2 * span)
	local out = math.sqrt(math.max(upper * upper - along * along, 0))
	local kneeAt = hipAt + direction * along + pole * out
	local ankleAt = hipAt + direction * span

	local function aim(partCF: CFrame, fromLocal: Vector3, to: Vector3): CFrame
		-- Shortest rotation of the bone's current direction onto the wanted one; the bone keeps its twist.
		local current = partCF:VectorToWorldSpace(fromLocal).Unit
		local wanted = to.Unit
		local axis = current:Cross(wanted)
		local sine = axis.Magnitude
		local angle = math.atan2(sine, current:Dot(wanted))
		local turn = if sine > 1e-5 then CFrame.fromAxisAngle(axis / sine, angle) else CFrame.identity
		return turn * partCF.Rotation
	end
	local upperLocal = knee.C0.Position - hip.C1.Position
	local lowerLocal = ankle.C0.Position - knee.C1.Position
	local upperRotation = aim(upperPart, upperLocal, kneeAt - hipAt)
	local upperSolved = CFrame.new(hipAt) * upperRotation * CFrame.new(-hip.C1.Position)
	local kneeWorld = (upperSolved * knee.C0).Position
	local lowerRotation = aim(lowerPart, lowerLocal, ankleAt - kneeWorld)
	local lowerSolved = CFrame.new(kneeWorld) * lowerRotation * CFrame.new(-knee.C1.Position)
	local ankleWorld = (lowerSolved * ankle.C0).Position
	local footSolved = CFrame.new(ankleWorld) * footRotation * CFrame.new(-ankle.C1.Position)

	-- Part1 = Part0 * C0 * Transform * C1:Inverse(), so Transform = (Part0 * C0):Inverse() * Part1 * C1.
	local function transform(parent: CFrame, joint: Joint, part: CFrame): CFrame
		local solved = ((parent * joint.C0):Inverse() * part * joint.C1).Rotation
		return if blend >= 0.999 then solved else joint.Input.Rotation:Lerp(solved, blend)
	end
	hip.Out = transform(pelvis, hip, upperSolved)
	knee.Out = transform(upperSolved, knee, lowerSolved)
	ankle.Out = transform(lowerSolved, ankle, footSolved)
end

-- One frame. `now` is os.clock(). Everything is written once, after the Animator evaluated, before physics.
function Pose.Apply(self: ActorPose, dt: number, now: number)
	dt = math.max(dt, 1 / 240)
	local active = false
	for _, joint in self.Order do
		local value = joint.Motor.Transform
		-- An Animator with nothing to evaluate leaves the last write in place: that is not this frame's pose.
		if value ~= joint.Written then
			joint.Input = value
		end
		joint.Out = joint.Input
		active = active or joint.Active
	end
	if self.Transitioned then
		self.Transitioned = false
		if not self.Released then
			startTransition(self)
			active = true
		end
	end
	if self.Released and not active and self.Weight <= 0 then
		self.Idle = true -- nothing of ours is left on this body
		self.LastDt = dt
		return
	end
	self.Idle = false
	local rootJoint = self.Joints.Root
	for _, joint in self.Order do
		if joint.Active then
			joint.X, joint.V = decayVector(joint.X, joint.V, dt)
			if joint == rootJoint then
				joint.PX, joint.PV = decayVector(joint.PX, joint.PV, dt)
			end
			if joint.X.Magnitude < REST_ANGLE and joint.V.Magnitude < REST_RATE and joint.PX.Magnitude < REST_ANGLE then
				joint.Active, joint.X, joint.V, joint.PX, joint.PV = false, Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero
			else
				joint.Out = fromRotationVector(joint.X) * joint.Out
				if joint == rootJoint then
					joint.Out = CFrame.new(joint.PX) * joint.Out
				end
			end
		end
	end
	if self.Step.Magnitude > 1e-3 then
		rootJoint.Out = CFrame.new(self.Step) * rootJoint.Out
	end

	if self.Joints.LeftKnee.Motor.C0 ~= self.Joints.LeftKnee.C0 then
		self:Measure() -- the rig was scaled
	end
	local rootCF = self.Root.CFrame
	local was = self.RootWas
	self.RootWas = rootCF.Position
	if was and (rootCF.Position - was).Magnitude < Foot.TELEPORT then
		self.Velocity = self.Velocity:Lerp((rootCF.Position - was) / dt, math.clamp(dt * 14, 0, 1))
	end
	local wantFeet = self.Feet and not self.Released
	if wantFeet or self.Weight > 0 then
		self.Weight = math.clamp(self.Weight + (if wantFeet then dt else -dt) / 0.08, 0, 1)
	end
	if self.Weight > 0 then
		self:ApplyFeet(rootCF, dt, now, not wantFeet)
	end
	for _, joint in self.Order do
		if joint.Out ~= joint.Input or joint.Written ~= joint.Input then
			joint.Motor.Transform = joint.Out
			joint.Written = joint.Out
		end
		joint.ShownPrevious, joint.Shown = joint.Shown, joint.Out
	end
	self.LastDt = dt
end

local function yawOf(c: CFrame): number
	local look = c.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function wrapped(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

function Pose.ApplyFeet(self: ActorPose, rootCF: CFrame, dt: number, now: number, release: boolean)
	local j = self.Joints
	local rootOut = j.Root
	local scale = self.Upper / UPPER_AT_SCALE_1
	local speed = math.sqrt(self.Velocity.X ^ 2 + self.Velocity.Z ^ 2)
	-- The body tilts toward its travel relative to its facing: forward, back and sideways read differently above the
	-- same legs. An action's clip keeps the torso it authored.
	local follow = math.clamp(dt * LEAN_RATE, 0, 1)
	local localTravel = if self.ClipFeet or release then Vector3.zero else rootCF:VectorToObjectSpace(self.Velocity)
	local amount = LEAN_MAX * self.Weight / LEAN_SPEED
	self.LeanX += (math.clamp(localTravel.Z * amount, -LEAN_MAX, LEAN_MAX) - self.LeanX) * follow
	self.LeanZ += (math.clamp(-localTravel.X * amount, -LEAN_MAX, LEAN_MAX) - self.LeanZ) * follow
	rootOut.Out = CFrame.Angles(self.LeanX, 0, self.LeanZ) * rootOut.Out
	local pelvis = rootOut.C0 * rootOut.Out * rootOut.C1:Inverse()
	-- Neutral: where the clip stands the foot while it owns the stance, a plain moving stance otherwise. A locomotion
	-- clip's swinging foot is not a neutral: the contact state replaces its stride, which is what lets the same feet
	-- run forward, back, sideways or turn.
	local clipShare = if self.ClipFeet then 1 else math.clamp(1 - speed / STANCE_BLEND_SPEED, 0, 1)
	local function neutral(side: string, sign: number): (Vector3, CFrame, number)
		local hip, knee, ankle = j[side .. "Hip"], j[side .. "Knee"], j[side .. "Ankle"]
		local upper = pelvis * hip.C0 * hip.Input * hip.C1:Inverse()
		local lower = upper * knee.C0 * knee.Input * knee.C1:Inverse()
		local ankleFrame = lower * ankle.C0 * ankle.Input
		local stance = Vector3.new(sign * STANCE_X * scale, ankleFrame.Y, -sign * STANCE_Z * scale)
		local at = stance:Lerp(ankleFrame.Position, clipShare)
		local clipLift = math.max(ankleFrame.Y - self.RestAnkleY, 0) * clipShare
		return at, ankleFrame, if clipLift > LIFT_FLOOR then clipLift else 0
	end
	local leftAt, leftClip, leftLift = neutral("Left", -1)
	local rightAt, rightClip, rightLift = neutral("Right", 1)
	local leftWorld, rightWorld = rootCF:PointToWorldSpace(leftAt), rootCF:PointToWorldSpace(rightAt)
	local leftFloor = groundBelow(self, "Left", leftWorld.X, leftWorld.Y, leftWorld.Z, now)
	local rightFloor = groundBelow(self, "Right", rightWorld.X, rightWorld.Y, rightWorld.Z, now)
	release = release or leftFloor == nil or rightFloor == nil
	local rootYaw = yawOf(rootCF)
	local plant = self.Plant
	local height = self.AnkleHeight
	Foot.update(plant, {
		LeftX = leftWorld.X, LeftZ = leftWorld.Z, LeftGround = (leftFloor or leftWorld.Y) + height,
		LeftYaw = rootYaw + wrapped(yawOf(rootCF * leftClip) - rootYaw) * clipShare,
		RightX = rightWorld.X, RightZ = rightWorld.Z, RightGround = (rightFloor or rightWorld.Y) + height,
		RightYaw = rootYaw + wrapped(yawOf(rootCF * rightClip) - rootYaw) * clipShare,
		VX = self.Velocity.X, VZ = self.Velocity.Z, Scale = scale, Release = release,
	}, dt)
	-- A contact point is world space; physics moves an owned root after this write, so it leads by this frame's motion.
	local lead = if self.Owner then self.Velocity * dt else Vector3.zero
	local function target(foot: any, lift: number): Vector3
		return rootCF:PointToObjectSpace(Vector3.new(foot.X, foot.Y + lift, foot.Z) - lead)
	end
	local leftTarget, rightTarget = target(plant.Left, leftLift), target(plant.Right, rightLift)
	-- Pelvis: down only as far as the feet need to stay reachable, never up, on a critically damped spring.
	local longest = (self.Upper + self.Lower) * LEG_MAX
	local function need(hipAt: Vector3, at: Vector3): number
		local flat = (at.X - hipAt.X) ^ 2 + (at.Z - hipAt.Z) ^ 2
		if flat >= longest * longest then
			return 0
		end
		return math.max(0, hipAt.Y - (at.Y + math.sqrt(longest * longest - flat)))
	end
	local wanted = math.min(math.max(need((pelvis * j.LeftHip.C0).Position, leftTarget), need((pelvis * j.RightHip.C0).Position, rightTarget)) * self.Weight, MAX_PELVIS_DROP * scale)
	local x, v = Timing.decay(self.Drop - wanted, self.DropV, 0.05, dt)
	self.Drop, self.DropV = math.max(x + wanted, 0), v
	if self.Drop > 1e-3 then
		rootOut.Out = CFrame.new(0, -self.Drop, 0) * rootOut.Out
		pelvis = rootOut.C0 * rootOut.Out * rootOut.C1:Inverse()
	end
	local function solve(side: string, at: Vector3, foot: any, clipFrame: CFrame)
		local lock = foot.Lock * self.Weight
		if lock <= 0 then
			return
		end
		-- The contact holds the foot's world yaw; a clip that owns the stance keeps its own pitch and roll, a moving foot sits flat.
		local flat = CFrame.Angles(0, foot.Yaw - rootYaw, 0)
		local authored = flat * CFrame.Angles(0, yawOf(clipFrame), 0):Inverse() * clipFrame.Rotation
		solveLeg(self, side, pelvis, at, flat:Lerp(authored, clipShare), lock)
	end
	solve("Left", leftTarget, plant.Left, leftClip)
	solve("Right", rightTarget, plant.Right, rightClip)
end

function Pose.Destroy(self: ActorPose)
	for _, joint in self.Order do
		if joint.Motor.Parent and joint.Written ~= joint.Input then
			joint.Motor.Transform = joint.Input
		end
	end
	table.clear(self.Ground)
end

-- The presented step alone, for a fighter with no full pose writer (past POSE_RANGE or the budget): the server's blade
-- includes the step, so the body has to show it whoever writes the joint. Writes the root joint only, the same way Apply
-- does. Handed back before a pose writer takes over, so there is still one writer.
local StepWriter = {}
StepWriter.__index = StepWriter

function Pose.stepWriter(model: Model): any
	local pelvis = model:FindFirstChild("LowerTorso")
	local motor = pelvis and pelvis:FindFirstChild("Root")
	if not motor or not motor:IsA("Motor6D") then
		return nil
	end
	return setmetatable({ Motor = motor, Input = CFrame.identity, Written = nil }, StepWriter)
end

function StepWriter.Apply(self: any, step: Vector3)
	local value = self.Motor.Transform
	if value ~= self.Written then
		self.Input = value
	end
	if step.Magnitude > 1e-3 then
		self.Written = CFrame.new(step) * self.Input
		self.Motor.Transform = self.Written
	elseif self.Written and self.Written ~= self.Input then
		self.Motor.Transform = self.Input
		self.Written = self.Input
	end
end

function StepWriter.Destroy(self: any)
	if self.Written and self.Written ~= self.Input and self.Motor.Parent then
		self.Motor.Transform = self.Input
	end
end

return Pose

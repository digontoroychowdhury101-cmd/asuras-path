--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/CameraController
-- Third-person over-the-shoulder camera with lock-on. Yaw/pitch/distance are driven by critically
-- damped springs; a spherecast cast as the CameraProbe collision group (which only collides with
-- WorldGeometry) pulls the camera in front of walls and cage bars.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local WorldState = require(script.Parent:WaitForChild("WorldStateController") :: ModuleScript)

type WorldState = WorldState.WorldState
type Entity = WorldState.Entity

local Controller = {}
Controller.__index = Controller

local BASE_OFFSET = Vector3.new(1.8, 1.4, 10.5)
local CORRECTION_SPEED = 22
local MIN_DISTANCE, MAX_DISTANCE = 8, 16
local LOCK_RANGE = 60
local LOCK_BREAK_RANGE = 80
local PITCH_MIN, PITCH_MAX = math.rad(-70), math.rad(55)
local PROBE_RADIUS = 0.6
local PROBE_GROUP = "CameraProbe"
local OCCLUSION_RECOVER = 6
local SWITCH_COOLDOWN = 0.25
local SWITCH_MOUSE = 45
local SWITCH_STICK = 0.85

-- Rotational drag on lock tracking per head injury tier (concussion / eye trauma).
local TRAUMA_DRAG: { [string]: number } = { None = 1, Impaired = 0.75, Injured = 0.5, Severe = 0.3 }
local TRAUMA_WOBBLE: { [string]: number } = { None = 0, Impaired = 0.004, Injured = 0.01, Severe = 0.02 }

type Spring = { Value: number, Velocity: number }

type Fields = {
	State: WorldState,
	Camera: Camera,
	Yaw: Spring,
	Pitch: Spring,
	Distance: Spring,
	TargetYaw: number,
	TargetPitch: number,
	Occluded: number,
	Shoulder: number,
	ShoulderSpring: Spring,
	Locked: number?,
	LastSwitch: number,
	SwitchAccumulator: number,
	Fov: number,
	Sensitivity: number,
	FovPunch: Spring,
	FovClamp: number,
	Shake: Vector3,
	ShakeVelocity: Vector3,
	Roll: number,
	Sway: number,
	HeadTier: string,
	Clock: number,
	Params: RaycastParams,
	Enabled: boolean,
	OnLockChanged: ((id: number?) -> ())?,
}

export type CameraController = typeof(setmetatable({} :: Fields, Controller))

local function spring(value: number): Spring
	return { Value = value, Velocity = 0 }
end

-- Critically damped spring step (semi-implicit, stable at any frame rate up to 1/15 s).
local function stepSpring(s: Spring, target: number, omega: number, dt: number)
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		local acceleration = omega * omega * (target - s.Value) - 2 * omega * s.Velocity
		s.Velocity += acceleration * h
		s.Value += s.Velocity * h
	end
end

local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

function Controller.new(state: WorldState): CameraController
	local camera = Workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local fields: Fields = {
		State = state,
		Camera = camera,
		Yaw = spring(0),
		Pitch = spring(math.rad(-12)),
		Distance = spring(BASE_OFFSET.Z),
		TargetYaw = 0,
		TargetPitch = math.rad(-12),
		Occluded = BASE_OFFSET.Z,
		Shoulder = 1,
		ShoulderSpring = spring(1),
		Locked = nil,
		LastSwitch = 0,
		SwitchAccumulator = 0,
		Fov = Config.Camera.FOV,
		Sensitivity = 1,
		FovPunch = spring(0),
		FovClamp = 0,
		Shake = Vector3.zero,
		ShakeVelocity = Vector3.zero,
		Roll = 0,
		Sway = 0,
		HeadTier = "None",
		Clock = 0,
		Params = params,
		Enabled = true,
		OnLockChanged = nil,
	}
	local self = setmetatable(fields, Controller)
	camera.CameraType = Enum.CameraType.Scriptable
	return self
end

-------------------------------------------------------------------------------------------------
-- Lock-on
-------------------------------------------------------------------------------------------------

local function targetPoint(entity: Entity): Vector3?
	local root = entity.Root
	if not root then
		return nil
	end
	local height = if entity.Boss then 2.4 else 1.2
	return root.Position + Vector3.new(0, height, 0)
end

function Controller.Candidates(self: CameraController): { Entity }
	local own = self.State:Own()
	local origin = if own and own.Root then own.Root.Position else self.Camera.CFrame.Position
	local list: { Entity } = {}
	for _, entity in self.State.Entities do
		if self.State:IsHostile(entity) and self.State:IsAlive(entity) and entity.Root then
			local root = entity.Root :: BasePart
			if (root.Position - origin).Magnitude <= LOCK_RANGE then
				local _, onScreen = self.Camera:WorldToViewportPoint(root.Position)
				if onScreen then
					table.insert(list, entity)
				end
			end
		end
	end
	return list
end

function Controller.SetLock(self: CameraController, id: number?)
	if self.Locked == id then
		return
	end
	self.Locked = id
	local callback = self.OnLockChanged
	if callback then
		callback(id)
	end
end

function Controller.ToggleLock(self: CameraController)
	if self.Locked then
		self:SetLock(nil)
		return
	end
	local viewport = self.Camera.ViewportSize
	local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
	local best: Entity? = nil
	local bestScore = math.huge
	for _, entity in self:Candidates() do
		local root = entity.Root :: BasePart
		local screen = self.Camera:WorldToViewportPoint(root.Position)
		local score = (Vector2.new(screen.X, screen.Y) - center).Magnitude + screen.Z * 4
		if score < bestScore then
			best, bestScore = entity, score
		end
	end
	if best then
		self:SetLock(best.Id)
	end
end

-- Switch to the nearest candidate on the requested screen side (-1 left, +1 right).
function Controller.SwitchTarget(self: CameraController, side: number)
	local current = if self.Locked then self.State:Get(self.Locked) else nil
	if not current or not current.Root then
		return
	end
	local now = os.clock()
	if now - self.LastSwitch < SWITCH_COOLDOWN then
		return
	end
	local origin = self.Camera:WorldToViewportPoint((current.Root :: BasePart).Position)
	local best: Entity? = nil
	local bestGap = math.huge
	for _, entity in self:Candidates() do
		if entity.Id ~= current.Id then
			local screen = self.Camera:WorldToViewportPoint((entity.Root :: BasePart).Position)
			local dx = screen.X - origin.X
			if dx * side > 0 and math.abs(dx) < bestGap then
				best, bestGap = entity, math.abs(dx)
			end
		end
	end
	if best then
		self.LastSwitch = now
		self:SetLock(best.Id)
	end
end

function Controller.LockedEntity(self: CameraController): Entity?
	local id = self.Locked
	if not id then
		return nil
	end
	return self.State:Get(id)
end

-------------------------------------------------------------------------------------------------
-- Input, feel and trauma hooks
-------------------------------------------------------------------------------------------------

-- Mouse/stick delta in pixels (or stick units scaled by the caller). While locked, horizontal
-- flicks switch targets instead of rotating.
function Controller.Look(self: CameraController, delta: Vector2, fromStick: boolean?)
	if self.Locked then
		if fromStick then
			if math.abs(delta.X) >= SWITCH_STICK then
				self:SwitchTarget(if delta.X > 0 then 1 else -1)
			end
			return
		end
		self.SwitchAccumulator = self.SwitchAccumulator * 0.85 + delta.X
		if math.abs(self.SwitchAccumulator) >= SWITCH_MOUSE then
			self:SwitchTarget(if self.SwitchAccumulator > 0 then 1 else -1)
			self.SwitchAccumulator = 0
		end
		return
	end
	local scale = Config.Camera.MouseSensitivity * self.Sensitivity
	self.TargetYaw -= delta.X * scale
	self.TargetPitch = math.clamp(self.TargetPitch - delta.Y * scale, PITCH_MIN, PITCH_MAX)
end

function Controller.ToggleShoulder(self: CameraController)
	self.Shoulder = -self.Shoulder
end

-- Directional shake and FOV punch. `direction` is world-space (the shake pushes along it).
function Controller.Impulse(self: CameraController, direction: Vector3?, magnitude: number, fovPunch: number?)
	local push = if direction and direction.Magnitude > 1e-3 then direction.Unit else Vector3.new(0, 1, 0)
	local localPush = self.Camera.CFrame:VectorToObjectSpace(push)
	self.ShakeVelocity += Vector3.new(localPush.X, localPush.Y, 0) * magnitude * 6
	self.Roll += (math.random() - 0.5) * magnitude * 0.05
	if fovPunch then
		self.FovPunch.Velocity += fovPunch * 18
	end
end

function Controller.SetHeadTrauma(self: CameraController, tier: string)
	self.HeadTier = if TRAUMA_DRAG[tier] then tier else "None"
end

function Controller.SetSway(self: CameraController, amplitude: number)
	self.Sway = amplitude
end

function Controller.SetFovClamp(self: CameraController, degrees: number)
	self.FovClamp = math.max(degrees, 0)
end

-------------------------------------------------------------------------------------------------
-- Frame update
-------------------------------------------------------------------------------------------------

function Controller.Update(self: CameraController, dt: number)
	local camera = Workspace.CurrentCamera
	self.Camera = camera
	camera.CameraType = Enum.CameraType.Scriptable
	self.Clock += dt
	local own = self.State:Own()
	local root = own and own.Root
	if not own or not root then
		return
	end

	local target = self:LockedEntity()
	if self.Locked and (not target or not self.State:IsAlive(target) or not target.Root
		or ((target.Root :: BasePart).Position - root.Position).Magnitude > LOCK_BREAK_RANGE) then
		self:SetLock(nil)
		target = nil
	end

	local pivot = root.Position + Vector3.new(0, BASE_OFFSET.Y, 0)
	local omega = CORRECTION_SPEED
	local desiredDistance = BASE_OFFSET.Z
	local humanoid = own.Humanoid
	if target and target.Root then
		local point = targetPoint(target) :: Vector3
		local midpoint = pivot:Lerp(point, 0.5)
		local flat = Vector3.new(midpoint.X - pivot.X, 0, midpoint.Z - pivot.Z)
		if flat.Magnitude > 0.1 then
			self.TargetYaw = yawOf(flat)
		end
		local separation = (point - pivot).Magnitude
		local elevation = point.Y - pivot.Y
		self.TargetPitch = math.clamp(math.atan2(elevation * 0.5, math.max(flat.Magnitude, 1)) - math.rad(10), PITCH_MIN, PITCH_MAX)
		desiredDistance = math.clamp(MIN_DISTANCE + separation * 0.28 + math.max(elevation, 0) * 0.6, MIN_DISTANCE, MAX_DISTANCE)
		omega = CORRECTION_SPEED * TRAUMA_DRAG[self.HeadTier]
		if humanoid then
			humanoid.AutoRotate = false
		end
		local snapshot = own.Snapshot
		local canTurn = snapshot == nil or (snapshot.State ~= "KO" and snapshot.State ~= "Dashing" and snapshot.State ~= "DeathblowVictim")
		if canTurn and flat.Magnitude > 0.1 then
			local look = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
			if look.Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
			end
		end
	elseif humanoid then
		humanoid.AutoRotate = true
	end

	self.Yaw.Value = self.TargetYaw + wrap(self.Yaw.Value - self.TargetYaw)
	stepSpring(self.Yaw, self.TargetYaw, omega, dt)
	stepSpring(self.Pitch, self.TargetPitch, omega, dt)
	stepSpring(self.Distance, desiredDistance, 8, dt)
	stepSpring(self.ShoulderSpring, self.Shoulder, 10, dt)
	stepSpring(self.FovPunch, 0, 14, dt)

	-- Shake: damped oscillator around zero in camera space.
	local shakeAcceleration = -self.Shake * 900 - self.ShakeVelocity * 30
	self.ShakeVelocity += shakeAcceleration * dt
	self.Shake += self.ShakeVelocity * dt
	self.Roll *= math.exp(-dt * 8)

	local wobble = TRAUMA_WOBBLE[self.HeadTier]
	local swayRoll = self.Sway * math.sin(self.Clock * 0.6) + wobble * math.sin(self.Clock * 2.3)
	local swayPitch = self.Sway * 0.5 * math.sin(self.Clock * 0.45 + 1.3) + wobble * math.cos(self.Clock * 1.7)
	local rotation = CFrame.fromEulerAnglesYXZ(self.Pitch.Value + swayPitch, self.Yaw.Value, self.Roll + swayRoll)
	local shoulder = BASE_OFFSET.X * self.ShoulderSpring.Value
	local origin = pivot + rotation:VectorToWorldSpace(Vector3.new(shoulder * 0.35, 0, 0))
	local desired = pivot + rotation:VectorToWorldSpace(Vector3.new(shoulder, 0, self.Distance.Value))

	-- Occlusion: snap in immediately, ease back out. CameraProbe only collides with WorldGeometry;
	-- before the server registers the groups, fall back to excluding every fighter model.
	local params = self.Params
	if PhysicsService:IsCollisionGroupRegistered(PROBE_GROUP) then
		params.CollisionGroup = PROBE_GROUP
		params.FilterDescendantsInstances = {}
	else
		local ignore: { Instance } = {}
		for _, entity in self.State.Entities do
			table.insert(ignore, entity.Model)
		end
		params.FilterDescendantsInstances = ignore
	end
	local offset = desired - origin
	local length = offset.Magnitude
	local allowed = length
	if length > 1e-3 then
		local hit = Workspace:Spherecast(origin, PROBE_RADIUS, offset, params)
		if hit then
			allowed = math.max(hit.Distance - 0.15, 0.5)
		end
	end
	if allowed < self.Occluded then
		self.Occluded = allowed
	else
		self.Occluded = math.min(allowed, self.Occluded + (allowed - self.Occluded) * math.min(1, dt * OCCLUSION_RECOVER) + dt)
	end
	local position = if length > 1e-3 then origin + offset.Unit * math.min(self.Occluded, length) else desired

	local shake = rotation:VectorToWorldSpace(Vector3.new(self.Shake.X, self.Shake.Y, 0))
	camera.CFrame = CFrame.new(position + shake) * rotation
	camera.Focus = CFrame.new(pivot)
	local fov = math.clamp(self.Fov + self.FovPunch.Value - self.FovClamp, Config.Camera.MinFOV - 20, Config.Camera.MaxFOV + 10)
	camera.FieldOfView = fov
end

function Controller.Destroy(self: CameraController)
	self.Enabled = false
	self:SetLock(nil)
	local own = self.State:Own()
	if own and own.Humanoid then
		own.Humanoid.AutoRotate = true
	end
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local player = Players.LocalPlayer
	if player.Character then
		camera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
	end
end

return Controller

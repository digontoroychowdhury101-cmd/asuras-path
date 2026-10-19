--!strict
-- Client-owned locomotion. Combat dash grants retain ownership of stamina and invulnerability.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath"):WaitForChild("Shared"):WaitForChild("CombatSettings") :: ModuleScript).Movement
local WorldState = require(script.Parent:WaitForChild("WorldStateController") :: ModuleScript)
local Camera = require(script.Parent:WaitForChild("CameraController") :: ModuleScript)
local Motion = require(script.Parent:WaitForChild("MovementMath") :: ModuleScript)
local Effects = require(script.Parent:WaitForChild("MovementEffects") :: ModuleScript)
local Controller = {}
Controller.__index = Controller
export type State = "Grounded" | "Airborne" | "Sliding" | "Gliding" | "BulletJumping"
type Fields = {
	World: WorldState.WorldState, Camera: Camera.CameraController, Effects: Effects.MovementEffects,
	State: State, Model: Model?, Humanoid: Humanoid?, Root: BasePart?, Params: RaycastParams,
	Hip: number, AutoJump: boolean, Enabled: boolean, JumpHeld: boolean, AimHeld: boolean, SlideHeld: boolean,
	DoubleUsed: boolean, GlideTime: number, LaunchGrace: number, GroundGap: number, SlideSpeed: number, Direction: Vector3,
}
export type MovementController = typeof(setmetatable({} :: Fields, Controller))

function Controller.new(world: WorldState.WorldState, camera: Camera.CameraController): MovementController
	local params = RaycastParams.new()
	params.FilterType, params.IgnoreWater, params.RespectCanCollide = Enum.RaycastFilterType.Exclude, true, true
	return setmetatable({ World = world, Camera = camera, Effects = Effects.new(camera), State = "Grounded" :: State,
		Model = nil, Humanoid = nil, Root = nil, Params = params, Hip = 0, AutoJump = true, Enabled = true,
		JumpHeld = false, AimHeld = false, SlideHeld = false, DoubleUsed = false, GlideTime = 0,
		LaunchGrace = 0, GroundGap = 0, SlideSpeed = 0, Direction = Vector3.zAxis }, Controller)
end

function Controller.SetState(self: MovementController, state: State)
	self.State = state
	if self.Humanoid then
		local crouched = state == "Sliding" or (state == "Grounded" and self.SlideHeld)
		self.Humanoid.HipHeight = if crouched then math.max(0, self.Hip - Settings.SlideHipDrop) else self.Hip
	end
end

function Controller.Cancel(self: MovementController)
	self.JumpHeld, self.AimHeld, self.SlideHeld = false, false, false
	self:SetState("Airborne")
	self.Effects:Stop()
end

function Controller.SetEnabled(self: MovementController, enabled: boolean)
	if self.Enabled and not enabled then self:Cancel() end
	self.Enabled = enabled
end

function Controller.Bind(self: MovementController)
	local model = Players.LocalPlayer.Character
	if model == self.Model and self.Root and self.Root.Parent then return end
	if self.Humanoid and self.Humanoid.Parent then
		self.Humanoid.HipHeight, self.Humanoid.AutoJumpEnabled = self.Hip, self.AutoJump
	end
	self:Cancel()
	self.Model, self.Humanoid, self.Root = model, nil, nil
	self.DoubleUsed, self.GlideTime, self.LaunchGrace, self.GroundGap = false, 0, 0, 0
	if not model then return end
	local humanoid, root = model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return end
	self.Humanoid, self.Root, self.Hip, self.AutoJump = humanoid, root, humanoid.HipHeight, humanoid.AutoJumpEnabled
	humanoid.AutoJumpEnabled = false
	self.Params.FilterDescendantsInstances = { model }
	self.Effects:Bind(model, root)
end

function Controller.CanMove(self: MovementController): boolean
	local humanoid = self.Humanoid
	local snapshot = self.World:OwnSnapshot()
	local rootUntil = if self.Model then self.Model:GetAttribute("RootUntil") else nil
	return (type(rootUntil)~="number" or rootUntil<=Workspace:GetServerTimeNow()) and self.Enabled and humanoid ~= nil and humanoid.Health > 0 and not humanoid.Sit and not humanoid.PlatformStand
		and (snapshot == nil or snapshot.State == "Idle" or snapshot.State == "Blocking")
		and os.clock() >= self.World.DashEnds
end

function Controller.Grounded(self: MovementController): boolean
	local humanoid = self.Humanoid
	return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air and self.LaunchGrace <= 0
end

function Controller.Press(self: MovementController, command: string)
	self:Bind()
	if not self:CanMove() then return end
	local humanoid, root = self.Humanoid, self.Root
	if not humanoid or not root then return end
	if command == "Aim" then self.AimHeld = true; return end
	if command == "Slide" then
		if self.SlideHeld then return end
		self.SlideHeld = true
		if self:Grounded() and humanoid.MoveDirection.Magnitude > 0.1 then
			local velocity = root.AssemblyLinearVelocity
			self.Direction = Motion.flat(velocity, Motion.flat(humanoid.MoveDirection, root.CFrame.LookVector))
			self.SlideSpeed = math.max(Vector3.new(velocity.X, 0, velocity.Z).Magnitude, humanoid.WalkSpeed) * Settings.SlideBoost
			self.GroundGap = 0
			self:SetState("Sliding")
		elseif self:Grounded() then self:SetState("Grounded")
		end
		return
	end
	if command ~= "Jump" or self.JumpHeld then return end
	self.JumpHeld = true
	if self.State == "Sliding" or (self:Grounded() and self.SlideHeld) then
		self:SetState("BulletJumping")
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = Motion.bullet(self.Camera.Camera.CFrame.LookVector)
		self.LaunchGrace = 0.15
		self.Effects:Launch(root, true)
	elseif self:Grounded() then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		self.LaunchGrace = 0.15
		self:SetState("Airborne")
	elseif not self.DoubleUsed then
		self.DoubleUsed, self.LaunchGrace = true, 0.1
		self:SetState("Airborne")
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = Motion.doubleJump(humanoid.MoveDirection)
		self.Effects:Launch(root, false)
	end
end

function Controller.Release(self: MovementController, command: string)
	if command == "Jump" then self.JumpHeld = false
	elseif command == "Aim" then self.AimHeld = false
	elseif command == "Slide" then
		self.SlideHeld = false
		if self.State == "Sliding" or self.State == "Grounded" then self:SetState(if self:Grounded() then "Grounded" else "Airborne") end
	end
end

-- Called in PreSimulation, so the camera, animation and combat systems never fight velocity writes.
function Controller.Step(self: MovementController, dt: number)
	self:Bind()
	local humanoid, root = self.Humanoid, self.Root
	if not humanoid or not root then return end
	self.LaunchGrace = math.max(0, self.LaunchGrace - dt)
	local grounded = self:Grounded()
	if grounded then self.DoubleUsed, self.GlideTime = false, 0 end
	if not self:CanMove() then
		self:SetState(if grounded then "Grounded" else "Airborne")
		humanoid.HipHeight = self.Hip
		self.Effects:Stop()
		return
	end
	local turn = 0
	if self.State == "Sliding" then
		local reach = root.Size.Y * 0.5 + self.Hip + 2.5
		local hit = Workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), self.Params)
		self.GroundGap = if hit then 0 else self.GroundGap + dt
		if self.GroundGap > Settings.SlideGroundGrace or (hit and hit.Normal.Y < math.cos(math.rad(humanoid.MaxSlopeAngle))) then
			self:SetState("Airborne")
		else
			local normal = if hit then hit.Normal else Vector3.yAxis
			local velocity: Vector3
			self.Direction, self.SlideSpeed, velocity = Motion.slide(self.Direction, self.SlideSpeed, normal, humanoid.MoveDirection, Workspace.Gravity, dt)
			local y = if grounded then velocity.Y else math.min(velocity.Y, root.AssemblyLinearVelocity.Y)
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, y, velocity.Z)
			turn = self.Camera.Camera.CFrame.RightVector:Dot(humanoid.MoveDirection)
			if self.SlideSpeed < Settings.SlideMinSpeed then self:SetState(if grounded then "Grounded" else "Airborne") end
		end
	elseif grounded then self:SetState("Grounded")
	elseif (self.JumpHeld or self.AimHeld) and self.GlideTime < Settings.GlideDuration then
		self:SetState("Gliding")
		local remaining = Settings.GlideDuration - self.GlideTime
		self.GlideTime = math.min(Settings.GlideDuration, self.GlideTime + dt)
		root.AssemblyLinearVelocity = Motion.glide(root.AssemblyLinearVelocity, self.Camera.Camera.CFrame.LookVector, math.min(dt, remaining))
	elseif self.State ~= "BulletJumping" or root.AssemblyLinearVelocity.Y <= 0 then self:SetState("Airborne") end
	self.Effects:Step(dt, self.State, turn, grounded)
end

function Controller.Destroy(self: MovementController)
	self:Cancel()
	self.Effects:Clear()
	if self.Humanoid then self.Humanoid.AutoJumpEnabled = self.AutoJump end
end

return Controller

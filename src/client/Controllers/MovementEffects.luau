--!strict
-- Local procedural cosmetics; no uploaded animation or VFX assets required. R6 and R15.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Camera = require(script.Parent:WaitForChild("CameraController") :: ModuleScript)
local Assets = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath"):WaitForChild("Shared"):WaitForChild("PresentationAssets") :: ModuleScript)
local Effects = {}
Effects.__index = Effects
type Fields = {
	Camera: Camera.CameraController, Items: { Instance }, Trails: { Trail }, Dust: ParticleEmitter?,
	Joint: Motor6D?, Base: CFrame, SpinTime: number, SpinDuration: number, Bullet: boolean,
}
export type MovementEffects = typeof(setmetatable({} :: Fields, Effects))

function Effects.new(camera: Camera.CameraController): MovementEffects
	return setmetatable({ Camera = camera, Items = {}, Trails = {}, Dust = nil, Joint = nil,
		Base = CFrame.identity, SpinTime = 0, SpinDuration = 0, Bullet = false }, Effects)
end

function Effects.Clear(self: MovementEffects)
	if self.Joint and self.Joint.Parent then self.Joint.C0 = self.Base end
	for _, item in self.Items do item:Destroy() end
	table.clear(self.Items)
	table.clear(self.Trails)
	self.Joint, self.Dust, self.SpinDuration = nil, nil, 0
	self.Camera:SetMovement(false, false, 0)
end

function Effects.Stop(self: MovementEffects)
	if self.Joint and self.Joint.Parent then self.Joint.C0 = self.Base end
	self.SpinDuration = 0
	self:Step(0, "Airborne", 0, false)
end

function Effects.Bind(self: MovementEffects, model: Model, root: BasePart)
	self:Clear()
	local candidate = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	local torso: BasePart = if candidate and candidate:IsA("BasePart") then candidate else root
	local joint = model:FindFirstChild("Waist", true) or model:FindFirstChild("RootJoint", true)
	if joint and joint:IsA("Motor6D") then self.Joint, self.Base = joint, joint.C0 end
	for _, side in { -1, 1 } do
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(side * torso.Size.X * 0.45, 0.5, 0)
		a.Parent = torso
		local b = Instance.new("Attachment")
		b.Position = a.Position + Vector3.new(0, -0.18, 0)
		b.Parent = torso
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a, b
		trail.Lifetime, trail.MinLength, trail.FaceCamera = 0.3, 0.1, true
		trail.Color = ColorSequence.new(Color3.fromRGB(195, 223, 230))
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1) })
		trail.Enabled, trail.Parent = false, torso
		table.insert(self.Trails, trail)
		table.insert(self.Items, a)
		table.insert(self.Items, b)
		table.insert(self.Items, trail)
	end
	local foot = Instance.new("Attachment")
	foot.Position = Vector3.new(0, -root.Size.Y * 0.5 - 1.4, 0)
	foot.Parent = root
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = Assets.Textures.Smoke
	dust.Color = ColorSequence.new(Color3.fromRGB(147, 131, 107))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.3) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime, dust.Speed, dust.Rate = NumberRange.new(0.2, 0.45), NumberRange.new(2, 5), 35
	dust.SpreadAngle, dust.Enabled, dust.Parent = Vector2.new(55, 35), false, foot
	self.Dust = dust
	table.insert(self.Items, foot)
end

function Effects.Launch(self: MovementEffects, root: BasePart, bullet: boolean)
	self.SpinTime, self.SpinDuration, self.Bullet = 0, if bullet then 0.5 else 0.4, bullet
	if not bullet then return end
	self.Camera.FovPunch.Value += 10
	self.Camera:Impulse(root.CFrame.LookVector, 0.12)
	local center = root.Position - Vector3.new(0, 1.8, 0)
	for index = 1, 18 do
		local angle = index * math.pi / 9
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local ring = Instance.new("Part")
		ring.Name = "BulletWind"
		ring.Anchored, ring.CanCollide, ring.CanTouch, ring.CanQuery = true, false, false, false
		ring.Material, ring.Color, ring.Transparency = Enum.Material.Neon, Color3.fromRGB(202, 228, 234), 0.55
		ring.Size, ring.CFrame = Vector3.new(0.75, 0.08, 0.12), CFrame.lookAt(center + radial * 2, center + radial * 3)
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(0.35), {
			CFrame = CFrame.lookAt(center + radial * 7, center + radial * 8), Size = Vector3.new(2.5, 0.02, 0.1), Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.4)
	end
end

function Effects.Step(self: MovementEffects, dt: number, state: string, turn: number, grounded: boolean)
	self.Camera:SetMovement(state == "Gliding", state == "Sliding", turn)
	for _, trail in self.Trails do trail.Enabled = state == "Gliding" end
	if self.Dust then self.Dust.Enabled = state == "Sliding" and grounded and self.Dust.Texture ~= "" end
	local joint = self.Joint
	if joint and self.SpinDuration > 0 then
		self.SpinTime = math.min(self.SpinTime + dt, self.SpinDuration)
		local angle = self.SpinTime / self.SpinDuration * math.pi * 2
		joint.C0 = self.Base * (if self.Bullet then CFrame.Angles(0, 0, angle) else CFrame.Angles(-angle, 0, 0))
		if self.SpinTime >= self.SpinDuration or grounded then
			joint.C0, self.SpinDuration = self.Base, 0
		end
	end
end

return Effects

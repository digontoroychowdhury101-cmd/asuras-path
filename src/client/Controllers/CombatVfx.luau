--!strict
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Surfaces = require(script.Parent.CombatSurfaces)
local Vfx = {}
Vfx.__index = Vfx
local rng = Random.new()
function Vfx.new(folder: Folder): any return setmetatable({ Folder = folder, Bursts = {}, Shards = {} }, Vfx) end
local function part(parent: Instance, name: string): Part
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = name, true, false, false, false, false
	p.Transparency, p.Size, p.Parent = 1, Vector3.one * 0.1, parent
	return p
end
function Vfx.ring(self: any, point: Vector3, direction: Vector3, color: Color3, radius: number)
	while #self.Bursts > 0 and self.Bursts[1].Parent == nil do table.remove(self.Bursts, 1) end
	if #self.Bursts >= Assets.Limits.Bursts then table.remove(self.Bursts, 1):Destroy() end
	local p = part(self.Folder, "DeflectShockwave")
	table.insert(self.Bursts, p)
	p.CFrame = CFrame.lookAt(point, point + (if direction.Magnitude > 0.1 then direction.Unit else Vector3.yAxis))
	local nodes: {Attachment} = {}
	for i = 1, 20 do
		local angle = (i - 1) * math.pi / 10
		local a = Instance.new("Attachment"); a.Position, a.Parent = Vector3.new(math.cos(angle), math.sin(angle), 0) * 0.12, p
		table.insert(nodes, a)
		Tween:Create(a, TweenInfo.new(0.18), { Position = a.Position * radius / 0.12 }):Play()
	end
	for i, a in nodes do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1, b.FaceCamera = a, nodes[i % #nodes + 1], true
		b.Color, b.LightEmission, b.Width0, b.Width1 = ColorSequence.new(Color3.new(1,1,1), color), 1, 0.09, 0.09
		b.Parent = p
		Tween:Create(b, TweenInfo.new(0.2), { Width0 = 0, Width1 = 0 }):Play()
	end
	Debris:AddItem(p, 0.23)
end
function Vfx.burst(self: any, point: Vector3, direction: Vector3, color: Color3, count: number, speed: number, blood: boolean?): Part
	while #self.Bursts > 0 and self.Bursts[1].Parent == nil do table.remove(self.Bursts, 1) end
	if #self.Bursts >= Assets.Limits.Bursts then table.remove(self.Bursts, 1):Destroy() end
	local p = part(self.Folder, if blood then "FleshImpact" else "BladeEmbers")
	p.CFrame = CFrame.lookAt(point, point + (if direction.Magnitude > 0.1 then direction.Unit else Vector3.yAxis))
	table.insert(self.Bursts, p)
	local texture = if blood then Assets.Textures.Blood else Assets.Textures.Ember
	if texture ~= "" then
		local e = Instance.new("ParticleEmitter")
		e.Texture, e.Rate = texture, 0
		e.EmissionDirection, e.SpreadAngle = Enum.NormalId.Front, Vector2.new(32, 32)
		e.Lifetime, e.Speed, e.Drag = NumberRange.new(0.1, 0.3), NumberRange.new(speed * 0.6, speed), 3
		e.LightEmission, e.LightInfluence = if blood then 0 else 1, if blood then 1 else 0
		e.Color = ColorSequence.new(if blood then color else Color3.new(1,1,1), color)
		e.Acceleration = Vector3.new(0, -55, 0)
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.26), NumberSequenceKeypoint.new(1, 0)})
		e.Parent = p; e:Emit(math.clamp(count, 1, 40))
	else
		-- Custom geometric streaks keep feedback available before the texture uploads.
		for _ = 1, math.min(count, 40, Assets.Limits.Shards - #self.Shards) do
			local shard = part(p, "RicochetStreak")
			shard.Transparency, shard.Material, shard.Color = 0, if blood then Enum.Material.SmoothPlastic else Enum.Material.Neon, color
			shard.Size = Vector3.new(0.035, 0.035, if blood then 0.18 else 0.4)
			local velocity = p.CFrame:VectorToWorldSpace(Vector3.new(rng:NextNumber(-0.6,0.6), rng:NextNumber(-0.4,0.8), -1).Unit) * rng:NextNumber(speed*0.6,speed)
			table.insert(self.Shards, { Part = shard, At = point, V = velocity, Life = rng:NextNumber(0.12,0.27), Bounced = false })
		end
	end
	if not blood then
		local flash = Instance.new("PointLight")
		flash.Color, flash.Range, flash.Brightness, flash.Parent = color, 10, 3, p
		Tween:Create(flash, TweenInfo.new(0.1), { Brightness = 0 }):Play()
	end
	Debris:AddItem(p, 0.65); return p
end
function Vfx.Update(self: any, dt: number)
	local params = RaycastParams.new(); params.FilterDescendantsInstances = {self.Folder}; params.RespectCanCollide = true
	for i = #self.Shards, 1, -1 do
		local s = self.Shards[i]; s.Life -= dt
		if s.Life <= 0 or not s.Part.Parent then s.Part:Destroy(); table.remove(self.Shards,i); continue end
		s.V += Vector3.new(0,-55,0)*dt
		local delta = s.V * dt
		local hit = if not s.Bounced then workspace:Raycast(s.At, delta, params) else nil
		if hit then s.At = hit.Position + hit.Normal*0.04; s.V = (s.V-2*s.V:Dot(hit.Normal)*hit.Normal)*0.45; s.Bounced = true else s.At += delta end
		if s.V.Magnitude > 0.01 then s.Part.CFrame = CFrame.lookAt(s.At,s.At+s.V) end
		s.Part.Transparency = math.clamp(1-s.Life/0.13,0,1)
	end
end
function Vfx.blood(self: any, point: Vector3, direction: Vector3, excludes: {Instance})
	self:burst(point,direction,Color3.fromRGB(118,8,17),18,22,true)
	Surfaces.stain(self.Folder,point,direction,excludes)
end
function Vfx.rupture(self: any, point: Vector3, direction: Vector3)
	Surfaces.rupture(self.Folder,point,direction,Color3.fromRGB(248,74,36))
end
function Vfx.Destroy(self: any) Surfaces.clear(); self.Folder:ClearAllChildren(); table.clear(self.Shards); table.clear(self.Bursts) end
return Vfx

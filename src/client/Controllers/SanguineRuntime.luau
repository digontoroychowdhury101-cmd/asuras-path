--!strict
-- Bounded client-only rendering for the user's VFX place. No world, actor or camera ownership.
local Tween = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").AsurasPath.Shared
local Assets = require(Shared.PresentationAssets) :: any
local Comfort = require(Shared.EffectsPreference) :: any
local Runtime = {}
Runtime.__index = Runtime
Runtime.Limits = table.freeze({ Groups = 8, Parts = 192, PartsPerGroup = 32, ParticlesPerSecond = 120 })
function Runtime.new(parent: Instance): any
	local folder = Instance.new("Folder")
	folder.Name, folder.Archivable, folder.Parent = "AsuraSanguineVFX", false, parent
	return setmetatable({ Folder = folder, Groups = {}, Parts = 0, Tokens = 60, Alive = true }, Runtime)
end
function Runtime.Drop(self: any, group: Folder)
	local record = self.Groups[group]
	if not record then return end
	self.Groups[group] = nil
	self.Parts -= record.Parts
	group:Destroy()
end
function Runtime.Group(self: any, name: string, lifetime: number): Folder?
	if not self.Alive then return nil end
	local count = 0
	for _ in self.Groups do count += 1 end
	if count >= (if Comfort.reduced() then 4 else Runtime.Limits.Groups) then return nil end
	local group = Instance.new("Folder")
	group.Name, group.Archivable, group.Parent = name, false, self.Folder
	self.Groups[group] = { Parts = 0, Until = os.clock() + math.clamp(lifetime, 0.1, 2.5), Emitters = 0 }
	return group
end
function Runtime.Part(self: any, group: Folder, name: string, size: Vector3, cf: CFrame, color: Color3, alpha: number?): Part?
	local record = self.Groups[group]
	if not record or not group.Parent or self.Parts >= Runtime.Limits.Parts then return nil end
	if record.Parts >= (if Comfort.reduced() then 12 else Runtime.Limits.PartsPerGroup) then return nil end
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.Massless, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, true, false, false, false, false
	p.Archivable, p.Material = false, Enum.Material.Neon
	p.Transparency = 1 - Comfort.flash(1 - (alpha or 0.35))
	p.Parent = group
	record.Parts += 1; self.Parts += 1
	return p
end
function Runtime.Tween(_self: any, item: Instance?, duration: number, goal: any)
	if item and item.Parent then Tween:Create(item, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play() end
end
function Runtime.Emit(self: any, group: Folder, position: Vector3, color: Color3, count: number)
	local record = self.Groups[group]
	if not record or record.Emitters >= 2 then return end
	local amount = math.min(math.floor(self.Tokens), math.floor(count * (if Comfort.reduced() then 0.25 else 0.6)), 24)
	if amount < 1 or Assets.Textures.Ember == "" then return end
	local anchor = self:Part(group, "SanguineBurstAnchor", Vector3.one * 0.1, CFrame.new(position), color, 1)
	if not anchor then return end
	local e = Instance.new("ParticleEmitter")
	e.Texture, e.Enabled, e.Rate = Assets.Textures.Ember, false, 0
	e.Color, e.Lifetime, e.Speed = ColorSequence.new(color), NumberRange.new(0.1, 0.35), NumberRange.new(4, 16)
	e.SpreadAngle, e.Acceleration, e.Drag = Vector2.new(150, 150), Vector3.new(0, -10, 0), 2
	e.Size, e.Transparency = NumberSequence.new(0.22, 0), NumberSequence.new(0.25, 1)
	e.LightEmission, e.LightInfluence, e.Parent = Comfort.flash(0.6), 0, anchor
	record.Emitters += 1; self.Tokens -= amount
	e:Emit(amount)
end
function Runtime.Update(self: any, dt: number)
	self.Tokens = math.min(60, self.Tokens + math.clamp(dt, 0, 0.1) * Runtime.Limits.ParticlesPerSecond)
	local now = os.clock()
	for group, record in self.Groups do
		if not group.Parent or now >= record.Until then self:Drop(group) end
	end
end
function Runtime.Clear(self: any)
	for group in self.Groups do self:Drop(group) end
end
function Runtime.Stats(self: any): any
	local groups = 0
	for _ in self.Groups do groups += 1 end
	return { Groups = groups, Parts = self.Parts, Tokens = self.Tokens }
end
function Runtime.Destroy(self: any)
	if not self.Alive then return end
	self.Alive = false; self:Clear(); self.Folder:Destroy()
end
return Runtime

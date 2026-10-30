--!strict
-- Client-only landscape cost control. Geometry/physics, prompts and authority stay on the server.
-- Small dressing fades by projected size, while the goddess, sacred canopy, roof silhouettes,
-- cliffs, water and real Atmosphere remain. No per-frame descendant walks or new connections.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Tags = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").AsurasPath.Shared
local Effects = require(Shared.EffectsPreference)
local Budget = {}
Budget.__index = Budget
local protected = { "Lantern", "Frosted", "Sheltered", "Paper", "WarmLight", "Candle", "Column_", "Roof_", "Beam_" }

local function position(item: Instance): Vector3?
	local parent = item.Parent
	if parent and parent:IsA("BasePart") then return parent.Position end
	if parent and parent:IsA("Attachment") then return parent.WorldPosition end
	return nil
end

local function keep(part: BasePart): boolean
	if part:GetAttribute("AsuraHeroFoliage") then return true end
	for _, word in protected do if part.Name:find(word, 1, true) then return true end end
	return part.Size.Magnitude > 38
end

function Budget.new(): any
	local self = setmetatable({ Parts = {}, Emitters = {}, Lights = {}, Shadows = {}, Links = {}, Time = 1, Alive = true }, Budget) :: any
	local function register(item: Instance)
		if not item:IsDescendantOf(workspace) then return end
		local root: Instance? = item
		while root and root.Parent ~= workspace do root = root.Parent end
		if not root or (root.Name ~= "Sanctuary" and not root.Name:match("^Map_")) then return end
		if item:IsA("BasePart") and item.Anchored then
			-- Collision/query surfaces keep their visibility; decorative mesh siblings carry the art.
			if item:IsA("MeshPart") or item:GetAttribute("AsuraMicroDetail") then
				table.insert(self.Parts, { Part = item, Original = item.LocalTransparencyModifier,
					Keep = keep(item), Radius = item.Size.Magnitude * 0.5, Sanctuary = root.Name == "Sanctuary" })
			end
		elseif item:IsA("PointLight") and root.Name == "Sanctuary" then
			table.insert(self.Lights, { Light = item, Enabled = item.Enabled })
		elseif item:IsA("ParticleEmitter") and root.Name == "Sanctuary" then
			table.insert(self.Emitters, { Emitter = item, Rate = item.Rate, Enabled = item.Enabled,
				Cloud = item.Name:find("Cloud", 1, true) ~= nil })
		end
	end
	for _, item in workspace:GetDescendants() do register(item) end
	table.insert(self.Links, workspace.DescendantAdded:Connect(register))
	if Tags then
		-- The tag's server contract is CastShadow=true. Reading that property when a tag first
		-- replicates can see a transient default, so it is not used to infer the original state.
		local function shadow(part: Instance)
			if part:IsA("BasePart") then self.Shadows[part] = true end
		end
		for _, part in Tags:GetTagged("AsuraFoliageShadow") do shadow(part) end
		table.insert(self.Links, Tags:GetInstanceAddedSignal("AsuraFoliageShadow"):Connect(shadow))
		table.insert(self.Links, Tags:GetInstanceRemovedSignal("AsuraFoliageShadow"):Connect(function(part)
			if self.Shadows[part] and part.Parent then part.CastShadow = true end
			self.Shadows[part] = nil
		end))
	end
	table.insert(self.Links, RunService.Heartbeat:Connect(function(dt)
		self.Time += dt
		if self.Time >= 0.4 then self.Time = 0; self:Refresh() end
	end))
	self:Refresh()
	return self
end

function Budget.Refresh(self: any)
	local camera = workspace.CurrentCamera
	if not camera or not self.Alive then return end
	local at = camera.CFrame.Position
	local quality = UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	local low = (quality > 0 and quality <= 4) or (quality == 0 and UIS.TouchEnabled)
	local threshold = if low then 0.028 else 0.013
	local hidden, active, particles = 0, 0, 0
	local foliageShadows = 0
	for part in self.Shadows do
		if not part.Parent then self.Shadows[part] = nil; continue end
		local enabled = true
		if part:IsDescendantOf(workspace) then
			local range = (part:GetAttribute("AsuraShadowDistance") or 80) * (if low then 0.6 else 1)
			-- Hysteresis prevents tiny wind movement or a hovering camera from toggling a boundary.
			enabled = (part.Position - at).Magnitude < range + (if part.CastShadow then 6 else -6)
			if enabled then foliageShadows += 1 end
		end
		if part.CastShadow ~= enabled then part.CastShadow = enabled end
	end
	for i = #self.Parts, 1, -1 do
		local row = self.Parts[i]; local part = row.Part
		if not part.Parent then table.remove(self.Parts, i); continue end
		local distance = (part.Position - at).Magnitude
		local fade = if row.Keep then 0 else math.clamp((distance * threshold / math.max(row.Radius, 0.1) - 0.85) / 0.35, 0, 1)
		-- Underground campaign meshes cannot contribute to a cloud-top vista. The 900-stud radius
		-- preloads their visual state long before a portal arrival and follows the camera for shots.
		if not row.Sanctuary and distance > 900 then fade = 1 end
		local value = math.max(row.Original, fade)
		if part.LocalTransparencyModifier ~= value then part.LocalTransparencyModifier = value end
		if fade >= 1 then hidden += 1 end
	end
	local range = if low then 64 else 110
	for i = #self.Lights, 1, -1 do
		local row = self.Lights[i]; local light = row.Light
		if not light.Parent then table.remove(self.Lights, i); continue end
		local pos = position(light)
		local enabled = row.Enabled and pos ~= nil and (pos - at).Magnitude < range
		if light.Enabled ~= enabled then light.Enabled = enabled end
		if enabled then active += 1 end
	end
	for i = #self.Emitters, 1, -1 do
		local row = self.Emitters[i]; local emitter = row.Emitter
		if not emitter.Parent then table.remove(self.Emitters, i); continue end
		local pos = position(emitter)
		local rangeLimit = if row.Cloud then 2800 else 240
		local enabled = row.Enabled and pos ~= nil and (pos - at).Magnitude < rangeLimit
		local density = if row.Cloud then (if low then 0.55 else 1) else Effects.decor(false) * (if low then 0.5 else 1)
		local rate = row.Rate * density
		if emitter.Rate ~= rate then emitter.Rate = rate end
		if emitter.Enabled ~= enabled then emitter.Enabled = enabled end
		if enabled then particles += rate * emitter.Lifetime.Max end
	end
	local player = Players.LocalPlayer
	player:SetAttribute("LandscapeTier", if low then "Balanced" else "Detailed")
	player:SetAttribute("LandscapeHiddenMeshes", hidden)
	player:SetAttribute("LandscapeFoliageShadows", foliageShadows)
	player:SetAttribute("LandscapeActiveLights", active)
	player:SetAttribute("LandscapeParticleCeiling", particles)
end

function Budget.Destroy(self: any)
	self.Alive = false
	for _, link in self.Links do link:Disconnect() end
	for part in self.Shadows do if part.Parent then part.CastShadow = true end end
	for _, row in self.Parts do if row.Part.Parent then row.Part.LocalTransparencyModifier = row.Original end end
	for _, row in self.Lights do if row.Light.Parent then row.Light.Enabled = row.Enabled end end
	for _, row in self.Emitters do if row.Emitter.Parent then row.Emitter.Rate, row.Emitter.Enabled = row.Rate, row.Enabled end end
	table.clear(self.Parts); table.clear(self.Lights); table.clear(self.Emitters); table.clear(self.Shadows); table.clear(self.Links)
end
return Budget

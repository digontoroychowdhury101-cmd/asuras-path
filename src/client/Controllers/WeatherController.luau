--!strict
-- Client weather (ticket 11). Owns only the precipitation FX; it never writes Lighting or GlobalWind.
--   * `:Profile(boss)` gives the single Lighting owner (EnvironmentController) the composed overworld profile,
--     or nil in the lobby, the Ash Colosseum domain, before the world clock arrives, and during a fight.
--   * `.Wind` is the one wind sample (Shared/Wind) for FoliageWind (sole GlobalWind writer), cloth and ambience.
-- Time and weather derive from the server's Workspace attribute AsuraWorldEpoch, so no remote is needed and a late
-- joiner sees the same sky. FX exist only while weather falls on a player in the open: every other state destroys them.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Overworld = require(Shared.Shared.Overworld)
local Profiles = require(Shared.Shared.EnvironmentProfiles)
local Wind = require(Shared.Shared.Wind)
local Effects = require(Shared.Shared.EffectsPreference)

local FX_TAG, SHELTER_TAG = "AsuraWeatherFx", "AsuraShelter"
-- Rate is particles per second at full intensity; Fall is the downward pull, Share how much of the wind carries them.
-- Rain is a velocity-aligned streak: Size is its length in studs (Fall * 0.02 s of motion blur, 1.4 studs), stretched by
-- Squash. VelocityParallel lays the particle along its velocity, and a POSITIVE squash widened it across that axis (the
-- horizontal dashes of 12e), so the sign is negative: tall along the fall line. Alpha is transparency. Live particles = Rate * Life * intensity, and the
-- sum over kinds is capped at BUDGET (rain 594, snow 550, dust 400 at full; comfort multiplies intensity by 0.35).
-- Rain Glow/Influence: bright, pale streaks that stay visible against sky and dark terrain (Influence = LightInfluence).
local KINDS: { [string]: any } = {
	Rain = { Rate = 540, Fall = 70, Share = 0.6, Life = 1.1, Size = 1.4, Squash = -2, Alpha = 0.3, Glow = 0.4, Influence = 0.5, Color = { 200, 215, 235 } },
	Snow = { Rate = 110, Fall = 10, Share = 0.8, Life = 5, Size = 0.6, Alpha = 0.15, Glow = 0.2, Color = { 245, 248, 255 }, Texture = "rbxasset://textures/particles/smoke_main.dds" },
	Dust = { Rate = 100, Fall = 1, Share = 1.5, Life = 4, Size = 2.8, Alpha = 0.55, Glow = 0, Color = { 222, 190, 140 }, Texture = "rbxasset://textures/particles/smoke_main.dds" },
}
-- The emitter box is a tall volume around the player (drops spawn anywhere in it, so rain fills head height).
local FX_SIZE, FX_LIFT = Vector3.new(40, 44, 40), 22
local Controller = {}
Controller.__index = Controller
Controller.Kinds, Controller.Budget = KINDS, 600

function Controller.new(state: any): any
	return setmetatable({ State = state, Elapsed = 1, Active = false, Fx = nil, Emitters = {}, Wind = nil, Composed = nil, Info = nil }, Controller)
end

local function sheltered(position: Vector3): boolean
	local roofs = CollectionService:GetTagged(SHELTER_TAG)
	if #roofs == 0 then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = roofs
	return workspace:Raycast(position, Vector3.yAxis * 60, params) ~= nil
end

function Controller.Counts(_self: any): { Parts: number, Emitters: number }
	local parts, emitters = 0, 0
	for _, part in CollectionService:GetTagged(FX_TAG) do
		parts += 1
		for _, child in part:GetChildren() do
			if child:IsA("ParticleEmitter") then emitters += 1 end
		end
	end
	return { Parts = parts, Emitters = emitters }
end

local function drop(self: any, kind: string)
	local emitter = self.Emitters[kind]
	if emitter then emitter:Destroy() end
	self.Emitters[kind] = nil
end

-- Idle state: no FX, no profile, no wind, no attributes. Lobby, respawn, shelter-less domain and Destroy all land here.
function Controller.Reset(self: any)
	for kind in table.clone(self.Emitters) do drop(self, kind) end
	if self.Fx then self.Fx:Destroy() end
	self.Fx, self.Active, self.Composed, self.Info, self.Wind = nil, false, nil, nil, nil
	local player = Players.LocalPlayer
	player:SetAttribute("AsuraWeather", nil)
	player:SetAttribute("AsuraSheltered", nil)
end

local function precipitation(self: any, position: Vector3, rates: { [string]: number })
	local wanted = false
	for kind, rate in rates do
		if KINDS[kind] and rate > 0.02 then wanted = true end
	end
	if not wanted then
		for kind in table.clone(self.Emitters) do drop(self, kind) end
		if self.Fx then self.Fx:Destroy(); self.Fx = nil end
		return
	end
	if not self.Fx then
		local part = Instance.new("Part")
		part.Name, part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = "AsuraWeatherFx", true, false, false, false
		part.CastShadow, part.Transparency, part.Size = false, 1, FX_SIZE
		part.Parent = workspace
		CollectionService:AddTag(part, FX_TAG)
		self.Fx = part
	end
	self.Fx.CFrame = CFrame.new(position + Vector3.new(0, FX_LIFT, 0))
	local live = 0
	for kind, spec in KINDS do
		local r = rates[kind] or 0
		if r > 0.02 then live += spec.Rate * spec.Life * math.min(r, 1) end
	end
	local fit = if live > Controller.Budget then Controller.Budget / live else 1
	for kind, spec in KINDS do
		local rate = rates[kind] or 0
		if rate <= 0.02 then
			drop(self, kind)
			continue
		end
		local emitter = self.Emitters[kind]
		if not emitter then
			emitter = Instance.new("ParticleEmitter")
			emitter.Name, emitter.EmissionDirection, emitter.LockedToPart = kind, Enum.NormalId.Bottom, false
			emitter.Lifetime, emitter.SpreadAngle = NumberRange.new(spec.Life), Vector2.new(6, 6)
			emitter.Size, emitter.Transparency = NumberSequence.new(spec.Size), NumberSequence.new(spec.Alpha)
			emitter.Color = ColorSequence.new(Color3.fromRGB(spec.Color[1], spec.Color[2], spec.Color[3]))
			emitter.Speed = NumberRange.new(spec.Fall * 0.5, spec.Fall * 0.7)
			emitter.LightEmission, emitter.LightInfluence = spec.Glow, spec.Influence or 1
			-- Snow and dust use the soft smoke sprite; the default texture is an eight-point star that reads as glitter.
			if spec.Texture then emitter.Texture = spec.Texture end
			if spec.Squash then
				emitter.Orientation, emitter.Squash = Enum.ParticleOrientation.VelocityParallel, NumberSequence.new(spec.Squash)
			end
			emitter.Parent = self.Fx
			self.Emitters[kind] = emitter
		end
		emitter.Rate = spec.Rate * math.min(rate, 1) * fit
		-- Sideways drift is the one wind sample, so rain slants the way the grass bends.
		local x, y, z = Wind.drift(self.Wind, spec.Fall * 0.2, spec.Share)
		emitter.Acceleration = Vector3.new(x, y, z)
	end
end

function Controller.Sample(self: any)
	local own = self.State:Own()
	if not own or not own.Root then return self:Reset() end
	local position: Vector3 = own.Root.Position
	local region = Overworld.regionAt(position.X, position.Y, position.Z)
	local epoch = workspace:GetAttribute("AsuraWorldEpoch")
	-- The domain keeps its own night; the lobby is outside every region box.
	if not region or region == "AshColosseum" or type(epoch) ~= "number" then return self:Reset() end
	local weights = Overworld.blendAt(position.X, position.Z, position.Y)
	local t = workspace:GetServerTimeNow() - epoch
	local player = Players.LocalPlayer
	local encounter = player:GetAttribute("AsuraEncounter")
	local covered = sheltered(position)
	local mix = Profiles.weatherBlend(weights, t)
	local profile, info = Profiles.compose({ Weights = weights, Time = t, Mix = mix,
		Sheltered = covered, Comfort = Effects.reducedMotion() or Effects.reduced() })
	self.Active, self.Composed, self.Info = true, profile, info
	self.Wind = Wind.sample(true, Config.Workspace.GlobalWind, info.WindGain)
	-- Weather stays out of a fight: the arena look and readability floor belong to the encounter.
	precipitation(self, position, if type(encounter) == "string" and encounter ~= "" then {} else info.Precip)
	local best, share = "Clear", 0
	for state, w in mix do
		if w > share then best, share = state, w end
	end
	player:SetAttribute("AsuraWeather", best)
	player:SetAttribute("AsuraSheltered", covered)
end

function Controller.Profile(self: any, boss: any?): any?
	return if boss then nil else self.Composed
end

function Controller.Update(self: any, dt: number)
	if self.Fx then
		local own = self.State:Own()
		if own and own.Root then self.Fx.CFrame = CFrame.new(own.Root.Position + Vector3.new(0, FX_LIFT, 0)) end
	end
	self.Elapsed += dt
	if self.Elapsed < 0.2 then return end
	self.Elapsed = 0
	self:Sample()
end

function Controller.Destroy(self: any)
	self:Reset()
end

return Controller

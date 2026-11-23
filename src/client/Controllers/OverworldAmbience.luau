--!strict
-- Overworld ambient life (client, win-80). WeatherController owns one instance and feeds it the 0..1 rates from
-- EnvironmentProfiles.ambience plus the one wind sample; this module never writes Lighting. One invisible box follows the
-- camera and carries an emitter per kind with a non-zero rate (LockedToPart off, so particles stay in the world as it moves):
--   Motes      sunlit pollen and dust drifting in the air (warm glow dots)
--   Leaves     tumbling leaves from the canopy (green in the Bellwood, amber over Amberfall: rates.Amber)
--   Fireflies  slow pulsing yellow-green lights after dusk
--   Glitter    diamond dust twinkling in cold clear sun
-- and switches the server-tagged lantern lights (AsuraLanternLight) by rates.Lanterns.
-- A kind at rate 0 has no emitter; all zero (or Destroy) leaves nothing behind. Live particles are capped at Budget.
local Wind = require(game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared.Wind) :: any
local CollectionService = game:GetService("CollectionService")

local Ambience = {}
Ambience.__index = Ambience

-- Procedural sprites made in the repo (assets/source/ambience), uploaded win-80.
Ambience.Leaf = "rbxassetid://138860325591751"
Ambience.Glow = "rbxassetid://84933589518173"
Ambience.Budget = 420
Ambience.Size = Vector3.new(110, 40, 110)
-- Lantern lights: the server puts one off PointLight tagged LANTERN_TAG on every lantern __Glow sub (SliceDressingService.Template);
-- they follow rates.Lanterns (0 by day, 1 after dusk), checked every LANTERN_STEP seconds so newly streamed lanterns join in.
local LANTERN_TAG, LANTERN_STEP = "AsuraLanternLight", 0.5
Ambience.LanternBrightness = 1.6

local NS, NK, CS = NumberSequence.new, NumberSequenceKeypoint.new, ColorSequence.new
local rgb = Color3.fromRGB

-- Rate = particles/s at full strength, Life = seconds. Live particles at full = Rate * Life.
Ambience.Kinds = {
	Motes = { Rate = 22, Life = 9, Sprite = "Glow", Size = NS({ NK(0, 0), NK(0.15, 0.22), NK(0.85, 0.22), NK(1, 0) }),
		Alpha = NS({ NK(0, 1), NK(0.2, 0.35), NK(0.8, 0.35), NK(1, 1) }), Color = CS(rgb(255, 236, 190)), Glow = 0.7, Influence = 0.4,
		Speed = { 0.2, 0.8 }, Spread = 180, Drift = 0.12, Fall = -0.05 },
	Leaves = { Rate = 9, Life = 9, Sprite = "Leaf", Size = NS({ NK(0, 0.55), NK(1, 0.5) }), Alpha = NS({ NK(0, 1), NK(0.08, 0), NK(0.9, 0), NK(1, 1) }),
		Color = CS(rgb(122, 150, 62)), Glow = 0, Influence = 1, Speed = { 1, 2.5 }, Spread = 40, Drift = 0.45, Fall = 2.2, Tumble = true },
	Fireflies = { Rate = 9, Life = 7, Sprite = "Glow", Size = NS({ NK(0, 0), NK(0.15, 0.5), NK(0.3, 0.12), NK(0.5, 0.55), NK(0.7, 0.1), NK(0.85, 0.5), NK(1, 0) }),
		Alpha = NS(0), Color = CS(rgb(214, 255, 120)), Glow = 1, Influence = 0, Speed = { 0.5, 1.4 }, Spread = 180, Drift = 0.05, Fall = -0.1, Brightness = 3 },
	Glitter = { Rate = 45, Life = 3, Sprite = "Glow", Size = NS({ NK(0, 0), NK(0.4, 0.09), NK(0.5, 0.18), NK(0.6, 0.09), NK(1, 0) }),
		Alpha = NS(0), Color = CS(rgb(235, 245, 255)), Glow = 1, Influence = 0.2, Speed = { 0.1, 0.4 }, Spread = 180, Drift = 0.3, Fall = 0.4, Brightness = 2 },
	-- win-86 night glow. Wisps: slow cold-blue spirit-lights that swell and dim. Spores: teal bioluminescent specks rising off the floor.
	Wisps = { Rate = 4, Life = 10, Sprite = "Glow", Size = NS({ NK(0, 0), NK(0.2, 0.9), NK(0.5, 0.55), NK(0.8, 0.9), NK(1, 0) }),
		Alpha = NS({ NK(0, 1), NK(0.2, 0.1), NK(0.8, 0.1), NK(1, 1) }), Color = CS(rgb(140, 225, 255)), Glow = 1, Influence = 0,
		Speed = { 0.3, 0.9 }, Spread = 180, Drift = 0.08, Fall = -0.06, Brightness = 3 },
	Spores = { Rate = 14, Life = 8, Sprite = "Glow", Size = NS({ NK(0, 0), NK(0.15, 0.2), NK(0.85, 0.14), NK(1, 0) }),
		Alpha = NS({ NK(0, 1), NK(0.15, 0.2), NK(0.85, 0.3), NK(1, 1) }), Color = CS(rgb(110, 255, 210), rgb(150, 200, 255)), Glow = 1,
		Influence = 0, Speed = { 0.2, 0.6 }, Spread = 180, Drift = 0.06, Fall = -0.35, Brightness = 2.5 },
}
local GREEN, AMBER = rgb(122, 150, 62), rgb(214, 132, 44)

function Ambience.new(parent: Instance?): any
	return setmetatable({ Parent = parent or workspace, Box = nil, Emitters = {}, LanternClock = math.huge, Lit = 0 }, Ambience)
end

local function emitter(self: any, kind: string, spec: any): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Texture, e.LockedToPart = kind, if spec.Sprite == "Leaf" then Ambience.Leaf else Ambience.Glow, false
	e.Lifetime, e.Speed = NumberRange.new(spec.Life * 0.7, spec.Life), NumberRange.new(spec.Speed[1], spec.Speed[2])
	e.SpreadAngle, e.Size, e.Transparency, e.Color = Vector2.new(spec.Spread, spec.Spread), spec.Size, spec.Alpha, spec.Color
	e.LightEmission, e.LightInfluence, e.Brightness = spec.Glow, spec.Influence, spec.Brightness or 1
	e.EmissionDirection = if spec.Fall > 1 then Enum.NormalId.Bottom else Enum.NormalId.Top
	e.Drag = if spec.Tumble then 0.6 else 0.2
	if spec.Tumble then
		-- Tumbling: spin plus a squash that flips the leaf edge-on and back.
		e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-120, 120)
		e.Squash = NS({ NK(0, 0), NK(0.2, 0.8), NK(0.4, -0.6), NK(0.6, 0.7), NK(0.8, -0.5), NK(1, 0) })
	end
	e.Rate = 0
	e.Parent = self.Box
	return e
end

-- Glowing mushroom caps (win-86): the server's tagged GlowSpores emitters, lit after dusk within CAP_RANGE of the camera only.
local CAP_TAG, CAP_RANGE = "AsuraGlowCap", 160

local function lanterns(level: number, at: Vector3?)
	for _, light in CollectionService:GetTagged(LANTERN_TAG) do
		local on = level > 0.05
		if light.Enabled ~= on then light.Enabled = on end
		if on then light.Brightness = Ambience.LanternBrightness * level end
	end
	for _, e in CollectionService:GetTagged(CAP_TAG) do
		local part = e.Parent
		local on = level > 0.3 and at ~= nil and part ~= nil and part:IsA("BasePart") and (part.Position - at).Magnitude < CAP_RANGE
		if e.Enabled ~= on then e.Enabled = on end
	end
end

-- Qi aura (win-86): under the canopy at midnight the moon fill alone left the floor black (capture win/vesp86 07). One soft,
-- shadowless cool light on the player's root by the lantern level: the one real light the night budget spends on the player.
Ambience.Aura = { Range = 26, Brightness = 0.85, Color = rgb(196, 218, 255) } -- 1.1 bleached a trunk 6 studs away (capture 09)
local function aura(self: any, level: number, root: BasePart?)
	local light = self.AuraLight
	if root and (not light or light.Parent ~= root) and level > 0.05 then
		if light then light:Destroy() end
		light = Instance.new("PointLight")
		light.Name, light.Shadows, light.Range, light.Color = "AsuraQiAura", false, Ambience.Aura.Range, Ambience.Aura.Color
		light.Parent = root
		self.AuraLight = light
	end
	if light then
		local on = level > 0.05 and root ~= nil and light.Parent == root
		if light.Enabled ~= on then light.Enabled = on end
		if on then light.Brightness = Ambience.Aura.Brightness * level end
	end
end

function Ambience.Update(self: any, dt: number, at: Vector3?, rates: { [string]: number }?, wind: any?, root: BasePart?)
	local level = if rates then math.clamp(rates.Lanterns or 0, 0, 1) else 0
	self.LanternClock += dt
	if self.LanternClock >= LANTERN_STEP or math.abs(level - self.Lit) > 0.1 then
		self.LanternClock, self.Lit = 0, level
		lanterns(level, at)
		aura(self, level, root)
	end
	local wanted = false
	if rates and at then
		for kind, v in rates do if Ambience.Kinds[kind] and v > 0.02 then wanted = true end end
	end
	if not wanted or not rates or not at then return self:Clear() end
	if not self.Box then
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = "AsuraAmbienceFx", true, false, false, false, false
		p.Transparency, p.Size = 1, Ambience.Size
		p.Parent = self.Parent
		self.Box = p
	end
	self.Box.CFrame = CFrame.new(at + Vector3.new(0, 6, 0))
	local live = 0
	for kind, spec in Ambience.Kinds do live += spec.Rate * spec.Life * math.min(rates[kind] or 0, 1) end
	local fit = if live > Ambience.Budget then Ambience.Budget / live else 1
	for kind, spec in Ambience.Kinds do
		local r = rates[kind] or 0
		local e = self.Emitters[kind]
		if r <= 0.02 then
			if e then e:Destroy(); self.Emitters[kind] = nil end
			continue
		end
		if not e then e = emitter(self, kind, spec); self.Emitters[kind] = e end
		e.Rate = spec.Rate * math.min(r, 1) * fit
		local x, y, z = 0, -spec.Fall, 0
		if wind then x, y, z = Wind.drift(wind, spec.Fall, spec.Drift) end
		e.Acceleration = Vector3.new(x, y, z)
		if kind == "Leaves" then e.Color = CS(GREEN:Lerp(AMBER, math.clamp(rates.Amber or 0, 0, 1))) end
	end
end

-- Live particles at the current rates (for the budget test and Studio checks).
function Ambience.Live(self: any): number
	local n = 0
	for kind, e in self.Emitters do n += e.Rate * Ambience.Kinds[kind].Life end
	return n
end

function Ambience.Clear(self: any)
	for _, e in self.Emitters do e:Destroy() end
	table.clear(self.Emitters)
	if self.Box then self.Box:Destroy(); self.Box = nil end
end

function Ambience.Destroy(self: any)
	self:Clear()
	lanterns(0)
	if self.AuraLight then self.AuraLight:Destroy(); self.AuraLight = nil end
end

return Ambience

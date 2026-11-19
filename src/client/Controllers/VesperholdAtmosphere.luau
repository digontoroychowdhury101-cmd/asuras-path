--!strict
-- Vesperhold atmosphere (client). Everything here exists only while Overworld.vesperholdWeight(player) > 0 and scales with that weight,
-- so it blends in over the ridge's flank and is gone (instances destroyed, nothing left running) in the lobby and every other region.
-- WeatherController owns the instance and feeds it the weight; the Lighting grade itself (haze, cold desaturation, red cast) is the
-- Vesperhold input of EnvironmentProfiles.compose, so this module never writes Lighting.
--   fog banks     soft smoke emitters in the gorge and on the ledges between the tiers
--   eclipse       a blood-red disc with a dark core behind the spires (billboard on the sky, follows the camera direction)
--   lightning     rare double flash: sky burst + three far point lights on the towers + its own ColorCorrectionEffect (VesperholdFlash, a Lighting
--                 child only this module creates, pulses and destroys) + a Flash level for the cloud layer
--   crows         a few flapping crows circling the towers (3 Parts each, moved on paths)
--   candle glow   a small pool of warm lights moved onto the nearest candle clusters
--   mist          emitters at the Layout waterfall anchors
-- EnvironmentController tweens only the Lighting children it names (CB_*), so this extra effect is never touched by it.
-- Comfort (reduced motion / effects): no lightning, half the crows and fog.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Overworld = require(Shared.Shared.Overworld) :: any
local Layout = require(Shared.Shared.VesperholdLayout) :: any
local Lighting = game:GetService("Lighting")

local Atmosphere = {}
Atmosphere.__index = Atmosphere

local MIN_WEIGHT = 0.02
local CROWS, CROWS_COMFORT = 8, 4
local GLOW_LIGHTS, GLOW_RANGE = 12, 250
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local NEAR_CASTLE = 1800 -- crows are only moved while the camera is this close to the towers

local V, C, A = Vector3.new, CFrame.new, CFrame.Angles

local static: { Origin: CFrame, Mist: { Vector3 }, Candles: { Vector3 }, Banks: { Vector3 }, Bursts: { Vector3 }, Orbits: { Vector3 } }? = nil

-- Castle-local data to world positions, computed once (the layout slots need the terrain, which is a pure function here).
local function world(): any
	if static then return static end
	local g = Overworld.Vesperhold
	local origin = C(g.X, g.Y, g.Z) * A(0, math.rad(g.Yaw), 0)
	local mist, candles = {}, {}
	for _, s in Layout.slots(function(x: number, z: number): number
		local w = origin * V(x, 0, z)
		return Overworld.surfaceAt(w.X, w.Z) - origin.Y
	end) do
		if s.Group == "Mist" then table.insert(mist, origin * V(s.X, s.Y + 4, s.Z)) end
		if s.Group == "Candle" then table.insert(candles, origin * V(s.X, s.Y + 2, s.Z)) end
	end
	local T, tower = Layout.Tiers, Layout.Tower
	local banks, orbits, bursts = {}, {}, {}
	for _, p in { { 0, -90, 500 }, { -150, -110, 380 }, { 150, -110, 380 } } do table.insert(banks, origin * V(p[1], p[2], p[3])) end
	for _, tier in { T.T1, T.T2, T.T3 } do
		for _, x in { -120, 0, 120 } do table.insert(banks, origin * V(x, tier.FloorY - 18, tier.FrontZ + 30)) end
	end
	for _, s in { -1, 0, 1 } do
		table.insert(bursts, origin * V(s * tower.X, tower.BaseY + 140, tower.Z))
		table.insert(orbits, origin * V(s * tower.X, tower.BaseY + 120, tower.Z))
	end
	static = { Origin = origin, Mist = mist, Candles = candles, Banks = banks, Bursts = bursts, Orbits = orbits }
	return static
end

local function anchor(parent: Instance, name: string, position: Vector3): Part
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = name, true, false, false, false, false
	p.Transparency, p.Size, p.CFrame = 1, V(1, 1, 1), C(position)
	p.Parent = parent
	return p
end

local function smoke(part: BasePart, size: number, life: number, speed: number, color: Color3, alpha: number, spread: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Texture, e.Lifetime, e.Speed, e.SpreadAngle = "Smoke", SMOKE, NumberRange.new(life), NumberRange.new(speed * 0.5, speed), Vector2.new(spread, spread)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, alpha), NumberSequenceKeypoint.new(1, 1) })
	e.Color, e.LightEmission, e.LightInfluence, e.LockedToPart, e.Rate = ColorSequence.new(color), 0, 1, false, 0
	e.Parent = part
	return e
end

local function disc(parent: Instance, size: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint, f.Position, f.Size, f.BackgroundColor3, f.BorderSizePixel = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(size, size), color, 0
	f.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	f.Parent = parent
	return f
end

local function sky(parent: Instance, name: string, diameter: number): (Part, BillboardGui)
	local p = anchor(parent, name, V(0, 0, 0))
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance = "Disc", UDim2.fromScale(diameter, diameter), false, 0, 6000
	gui.Parent = p
	return p, gui
end

function Atmosphere.new(): any
	return setmetatable({ Folder = nil, Weight = 0, Flash = 0, Elapsed = 0, Timer = 0, Strike = 0, GlowTimer = 0, Rng = Random.new(2026) }, Atmosphere)
end

function Atmosphere.Counts(self: any): { Instances: number, Emitters: number, Crows: number, Lights: number }
	local counts = { Instances = 0, Emitters = 0, Crows = #(self.Crows or {}), Lights = 0 }
	if self.Folder then
		for _, d in self.Folder:GetDescendants() do
			counts.Instances += 1
			if d:IsA("ParticleEmitter") then counts.Emitters += 1 end
			if d:IsA("PointLight") then counts.Lights += 1 end
		end
	end
	return counts
end

local function build(self: any, comfort: boolean)
	local w = world()
	local folder = Instance.new("Folder")
	folder.Name = "VesperholdAtmosphere"
	folder.Parent = workspace
	self.Folder, self.Comfort = folder, comfort
	local banks, mists = {}, {}
	for i, p in w.Banks do
		if comfort and i % 2 == 0 then continue end
		local part = anchor(folder, "FogBank", p)
		part.Size = V(120, 20, 120)
		table.insert(banks, { E = smoke(part, 110, 14, 3, Color3.fromRGB(122, 118, 126), 0.84, 180), Rate = 1.3 })
	end
	for _, p in w.Mist do
		local part = anchor(folder, "WaterfallMist", p)
		table.insert(mists, { E = smoke(part, 34, 6, 7, Color3.fromRGB(205, 214, 224), 0.7, 70), Rate = 5 })
	end
	self.Banks, self.Mists = banks, mists
	-- Eclipse: red rim, dark core.
	local eclipsePart, gui = sky(folder, "Eclipse", 520)
	self.EclipsePart = eclipsePart
	self.EclipseGlow, self.EclipseRim, self.EclipseCore = disc(gui, 1, Color3.fromRGB(150, 20, 26)), disc(gui, 0.62, Color3.fromRGB(176, 26, 30)), disc(gui, 0.56, Color3.fromRGB(18, 4, 6))
	-- Lightning: a white-blue sky burst and a point light on each tower.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name, grade.Brightness, grade.Contrast, grade.Saturation, grade.TintColor = "VesperholdFlash", 0, 0, 0, Color3.new(1, 1, 1)
	grade.Parent = Lighting
	self.Grade = grade
	local burstPart, burstGui = sky(folder, "LightningBurst", 900)
	self.BurstPart, self.BurstDisc = burstPart, disc(burstGui, 1, Color3.fromRGB(196, 208, 255))
	self.BurstLights = {}
	for _, p in w.Bursts do
		local lp = anchor(folder, "LightningFlash", p)
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows, light.Enabled = Color3.fromRGB(190, 205, 255), 60, 0, false, false
		light.Parent = lp
		table.insert(self.BurstLights, light)
	end
	-- Crows: body plus two wings, each on its own orbit around a tower.
	local crows = {}
	for i = 1, if comfort then CROWS_COMFORT else CROWS do
		local function bit(name: string, size: Vector3): Part
			local p = anchor(folder, name, V(0, 0, 0))
			p.Size, p.Transparency, p.Color, p.Material = size, 0, Color3.fromRGB(14, 14, 16), Enum.Material.SmoothPlastic
			return p
		end
		local centre = w.Orbits[(i - 1) % #w.Orbits + 1]
		table.insert(crows, { Body = bit("Crow", V(0.7, 0.45, 1.5)), L = bit("CrowWingL", V(2, 0.1, 0.9)), R = bit("CrowWingR", V(2, 0.1, 0.9)), Centre = centre,
			Radius = self.Rng:NextNumber(45, 95), Height = self.Rng:NextNumber(-25, 45), Speed = self.Rng:NextNumber(0.35, 0.6) * (if i % 2 == 0 then 1 else -1),
			Phase = self.Rng:NextNumber(0, math.pi * 2) })
	end
	self.Crows = crows
	-- Candle glow pool.
	local pool = {}
	for _ = 1, GLOW_LIGHTS do
		local p = anchor(folder, "CandleGlow", V(0, -1000, 0))
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows, light.Enabled = Color3.fromRGB(255, 152, 72), 12, 0, false, false
		light.Parent = p
		table.insert(pool, { Part = p, Light = light })
	end
	self.Glow = pool
	self.Timer = self.Rng:NextNumber(10, 28)
end

function Atmosphere.Clear(self: any)
	if self.Folder then self.Folder:Destroy() end
	if self.Grade then self.Grade:Destroy() end
	self.Grade = nil
	self.Folder, self.Banks, self.Mists, self.Crows, self.Glow, self.BurstLights = nil, nil, nil, nil, nil, nil
	self.Weight, self.Flash, self.Strike = 0, 0, 0
end

local function pulse(t: number, at: number, width: number): number
	local x = (t - at) / width
	return if x < 0 or x > 1 then 0 else math.sin(x * math.pi)
end

-- Two quick strikes over ~0.5 s. Public so tests can force one.
function Atmosphere.Lightning(self: any)
	if self.Folder and not self.Comfort then self.Strike = 0.5 end
end

-- weight = Overworld.vesperholdWeight at the player; camera = camera (or root) position; comfort = reduced motion / effects.
function Atmosphere.Update(self: any, weight: number, dt: number, camera: Vector3, comfort: boolean)
	if weight <= MIN_WEIGHT then
		if self.Folder then self:Clear() end
		return
	end
	if self.Folder and self.Comfort ~= comfort then self:Clear() end -- rebuilt with the other budget
	if not self.Folder then build(self, comfort) end
	local w = world()
	self.Weight = weight
	self.Elapsed += dt
	for _, b in self.Banks do b.E.Rate = b.Rate * weight * (if comfort then 0.5 else 1) end
	for _, m in self.Mists do m.E.Rate = m.Rate * weight end
	-- Lightning schedule and envelope.
	if not comfort then
		self.Timer -= dt
		if self.Timer <= 0 then
			self:Lightning()
			self.Timer = self.Rng:NextNumber(14, 42)
		end
	end
	local active = self.Strike > 0
	self.Strike = math.max(self.Strike - dt, 0)
	local t = 0.5 - self.Strike -- seconds into the strike
	self.Flash = if active then math.max(pulse(t, 0, 0.14), 0.7 * pulse(t, 0.22, 0.2)) else 0
	-- Sky discs sit on a fixed bearing toward the spires from wherever the camera is.
	local dir = ((w.Origin * V(0, 380, -900)) - camera).Unit
	self.EclipsePart.CFrame = C(camera + dir * 3500)
	self.BurstPart.CFrame = C(camera + (dir + V(0.03, 0.02, 0)).Unit * 3300)
	self.EclipseGlow.BackgroundTransparency = 1 - 0.28 * weight
	self.EclipseRim.BackgroundTransparency = 1 - 0.85 * weight
	self.EclipseCore.BackgroundTransparency = 1 - 0.96 * weight
	self.BurstDisc.BackgroundTransparency = 1 - 0.8 * self.Flash * weight
	local f = self.Flash * weight
	self.Grade.Brightness, self.Grade.Contrast = 0.2 * f, 0.12 * f
	self.Grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(196, 212, 255), 0.6 * f)
	for _, light in self.BurstLights do
		light.Enabled, light.Brightness = self.Flash > 0, 8 * self.Flash * weight
	end
	-- Crows.
	if (camera - w.Orbits[2]).Magnitude < NEAR_CASTLE then
		for _, c in self.Crows do
			local a = c.Phase + self.Elapsed * c.Speed
			local pos = c.Centre + V(math.cos(a) * c.Radius, c.Height + math.sin(a * 2) * 4, math.sin(a) * c.Radius)
			local ahead = c.Centre + V(math.cos(a + 0.05 * math.sign(c.Speed)) * c.Radius, c.Height + math.sin((a + 0.05) * 2) * 4, math.sin(a + 0.05 * math.sign(c.Speed)) * c.Radius)
			local f = CFrame.lookAt(pos, ahead)
			local flap = math.sin(self.Elapsed * 9 + c.Phase) * 0.7
			c.Body.CFrame = f
			c.L.CFrame = f * C(-1.1, 0, 0) * A(0, 0, flap)
			c.R.CFrame = f * C(1.1, 0, 0) * A(0, 0, -flap)
		end
	end
	-- Candle glow: re-aim the pool at the nearest candle clusters twice a second.
	self.GlowTimer -= dt
	if self.GlowTimer <= 0 then
		self.GlowTimer = 0.5
		local near = {}
		for _, p in w.Candles do
			local d = (p - camera).Magnitude
			if d < GLOW_RANGE then table.insert(near, { P = p, D = d }) end
		end
		table.sort(near, function(a: any, b: any): boolean return a.D < b.D end)
		for i, g in self.Glow do
			local n = near[i]
			g.Light.Enabled = n ~= nil
			if n then g.Part.CFrame = C(n.P) end
		end
	end
	local flicker = 0.85 + 0.15 * math.sin(self.Elapsed * 11)
	for _, g in self.Glow do g.Light.Brightness = 0.9 * weight * flicker end
end

function Atmosphere.Destroy(self: any)
	self:Clear()
end

return Atmosphere

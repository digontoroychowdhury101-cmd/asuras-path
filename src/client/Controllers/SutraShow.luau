--!strict
-- Sutra of Mending (the Fallen Abbot's beads). The caster thumbs the beads and chants; a ring of
-- 54 jade beads opens on the ground and walks with them. Each pulse sends a wave through the ring
-- and lights everyone it mended. The server decides who heals; this only draws it.
--   startup: bead clicks, jade light gathering in the hands, a loop of beads circling the chest
--   release: the ground ring blooms out to the heal radius, motes rise, the chant hum holds
--   pulse:   a jade wave, a chime, and a brief glow on each mended fighter
local RunService = game:GetService("RunService")
local Kit = require(script.Parent.SkillKit)
local Fx = require(script.Parent.SkillFx)
local Sfx = require(script.Parent.SkillAudio)
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Show = {}

local rgb = Color3.fromRGB
-- Neon lifts hue and value, so the glowing jade is mixed darker than the bead texture.
local JADE, PALE, BRONZE = rgb(28, 128, 84), rgb(150, 220, 180), rgb(150, 105, 55)
local GLOW = 0.6 -- jade light on the floor; brighter floods the hall green
local RADIUS = 12 -- SpellSchema SutraOfMending.Radius
local COUNT = 54 -- beads on the Abbot's mala
local HIP = 2.8 -- root to floor
local CHANT = 2.25 -- release to last pulse
local FADE = 0.6

local function root(cast: any): BasePart?
	local r = cast.Entity.Root
	return if r and r.Parent then r else nil
end

-- A small loop of beads that circles the chest while the caster counts them.
local function mala(cast: any, folder: Instance)
	local beads = {}
	for n = 1, 18 do
		local bead = Kit.part(folder, "MalaBead", if n == 1 then PALE else JADE, Vector3.one * (if n == 1 then 0.34 else 0.24), CFrame.identity, Enum.PartType.Ball)
		if n % 6 == 0 then bead.Color, bead.Material = BRONZE, Enum.Material.Metal end
		bead.Transparency = 0.15
		beads[n] = bead
	end
	local spin = 0
	Kit.add(cast.Trove, RunService.Heartbeat:Connect(function(dt: number)
		local base = root(cast)
		if not base then return end
		spin += dt * 1.4
		local center = base.CFrame * CFrame.new(0, 0.6, -0.9)
		for n, bead in beads do
			local a = spin + n / #beads * math.pi * 2
			bead.CFrame = center * CFrame.new(math.cos(a) * 1.15, math.sin(a) * 0.35, math.sin(a) * 0.45)
		end
	end))
end

function Show.startup(cast: any)
	Sfx.score(cast, "Sutra", "Startup")
	if not root(cast) then return end
	local folder = Kit.folder(cast.Trove, "SutraOfMending")
	cast.Bag.Folder = folder
	for _, hand in Kit.hands(cast.Entity.Model) do
		local a = Kit.attach(cast.Trove, hand, Vector3.zero, "SutraGlow")
		Kit.light(a, JADE, 5, 1)
		Kit.emitter(a, { Texture = Assets.Textures.Ember, Color = ColorSequence.new(PALE, JADE), Size = NumberSequence.new(0.22, 0.02),
			Rate = 14, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.4, 1), Spread = 180, Accel = Vector3.new(0, 1.5, 0), Light = 1 })
	end
	mala(cast, folder)
end

-- The ground ring: 54 beads strung on a thin jade cord, following the caster at walking pace.
local function ring(cast: any, folder: Instance): Model
	local model = Instance.new("Model")
	model.Name = "SutraRing"
	local cord = Kit.ring(model, "Cord", RADIUS, 0.08, JADE, 48)
	for _, p in cord:GetChildren() do (p :: BasePart).Transparency = 0.45 end
	Kit.ring(model, "Inner", RADIUS * 0.35, 0.06, PALE, 24)
	for n = 1, COUNT do
		local yaw = n / COUNT * math.pi * 2
		local head = n == COUNT
		local bead = Kit.part(model, "Bead", if head then PALE else JADE, Vector3.one * (if head then 0.75 else 0.5),
			CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.2, -RADIUS), Enum.PartType.Ball)
		bead.Transparency = 0.1
	end
	model.WorldPivot = CFrame.identity
	model.Parent = folder
	return Kit.add(cast.Trove, model)
end

function Show.release(cast: any, at: Vector3)
	local folder = cast.Bag.Folder or Kit.folder(cast.Trove, "SutraOfMending")
	cast.Bag.Folder = folder
	Sfx.score(cast, "Sutra", "Release")
	local model = ring(cast, folder)
	local floor = at - Vector3.new(0, HIP, 0)
	Kit.shockwave(cast.Trove, folder, CFrame.new(floor), PALE, RADIUS, 0.55, 0.35)
	Fx.flash(cast.Trove, folder, at, JADE, 7, 0.5)
	local motes = Kit.part(folder, "Motes", JADE, Vector3.new(RADIUS * 1.6, 0.1, RADIUS * 1.6), CFrame.new(floor))
	motes.Transparency = 1
	local rise = Kit.emitter(motes, { Texture = Assets.Textures.Ember, Color = ColorSequence.new(PALE, JADE), Size = NumberSequence.new(0.3, 0.04),
		Rate = 26, Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(1.5, 3), Spread = 8, Accel = Vector3.new(0, 1, 0), Drag = 0.6, Light = 1 })
	local light = Kit.light(motes, JADE, RADIUS, GLOW)
	cast.Bag.Light = light
	local grow, spin, last = 0, 0, floor
	Kit.add(cast.Trove, RunService.Heartbeat:Connect(function(dt: number)
		local base = root(cast)
		if base then last = base.Position - Vector3.new(0, HIP, 0) end
		grow = math.min(1, grow + dt / 0.45)
		spin += dt * 0.35
		model:ScaleTo(math.max(0.05, 1 - (1 - grow) ^ 3))
		model:PivotTo(CFrame.new(last) * CFrame.Angles(0, spin, 0))
		motes.CFrame = CFrame.new(last)
	end))
	Kit.after(cast.Trove, CHANT + 0.35, function()
		Fx.fade(cast.Trove, model, FADE)
		Kit.tween(cast.Trove, light, FADE, { Brightness = 0 })
		rise.Enabled = false
	end)
	Kit.after(cast.Trove, CHANT + 0.35 + FADE + 1.2, function() Kit.clean(cast.Trove) end)
end

-- Each mended fighter glows jade for a breath.
local function glow(cast: any, entity: any)
	local model = entity and entity.Model
	if not model or not model.Parent then return end
	local h = Kit.add(cast.Trove, Instance.new("Highlight"))
	h.FillColor, h.OutlineColor = JADE, PALE
	h.FillTransparency, h.OutlineTransparency = 0.75, 0.3
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee, h.Parent = model, model
	Kit.tween(cast.Trove, h, 0.7, { FillTransparency = 1, OutlineTransparency = 1 })
	local r = entity.Root
	if r and r.Parent and cast.Bag.Folder then
		local holder = Kit.part(cast.Bag.Folder, "MendBurst", JADE, Vector3.one * 0.1, r.CFrame)
		holder.Transparency = 1
		Fx.burst(holder, ColorSequence.new(PALE, JADE), 12, 5)
	end
end

function Show.pulse(cast: any, at: Vector3, data: any, state: any)
	local folder = cast.Bag.Folder
	if not folder then return end
	Sfx.play(cast, "MendPulse", 0.85 + cast.Pulses * 0.05)
	Kit.shockwave(cast.Trove, folder, CFrame.new(at - Vector3.new(0, HIP, 0)), JADE, RADIUS, 0.7, 0.4)
	if cast.Bag.Light then
		cast.Bag.Light.Brightness = GLOW * 2.5
		Kit.tween(cast.Trove, cast.Bag.Light, 0.5, { Brightness = GLOW })
	end
	if type(data) == "table" and type(data.healed) == "table" and state then
		for _, id in data.healed do glow(cast, state:Get(id)) end
	end
end

return table.freeze(Show)

--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryBonfire
-- The Primal Bonfire on the plaza altar: an ash mound, a teepee of charred logs and a coiled sword
-- driven into the ash, burning with Roblox's built-in Fire (always renders, no upload needed)
-- layered with flame-lick, ember and smoke particles and a warm light.
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)

local Bonfire = {}

local ASH = Color3.fromRGB(58, 54, 52)
local CHAR = Color3.fromRGB(33, 27, 24)
local IRON = Color3.fromRGB(70, 66, 64)
local GLOW = Color3.fromRGB(255, 150, 60)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function keys(points: { { number } }): NumberSequence
	local list = {}
	for _, k in points do
		table.insert(list, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	return NumberSequence.new(list)
end

local function emitter(parent: Instance, texture: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

-- `base` sits on the top of the altar's ash bowl, Y up.
function Bonfire.Build(parent: Instance, base: CFrame): BasePart
	local group = Instance.new("Folder")
	group.Name = "PrimalBonfire"
	group.Parent = parent

	-- Ash mound and banked coals.
	part(group, "AshMound", Vector3.new(3.4, 0.9, 3.4), base * CFrame.new(0, 0.25, 0), ASH, Enum.Material.Sand, Enum.PartType.Ball)
	local coals = part(group, "Coals", Vector3.new(0.5, 2.2, 2.2), base * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
	coals.Transparency = 0.15

	-- Teepee of charred logs leaning in on the sword.
	for k = 0, 5 do
		local a = math.rad(k * 60 + 15)
		local foot = (base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.3, -1.3)).Position
		local tip = (base * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.1, -0.2)).Position
		local cf = CFrame.lookAt((foot + tip) / 2, tip) * CFrame.Angles(0, math.rad(90), 0)
		part(group, "CharredLog", Vector3.new((tip - foot).Magnitude + 0.3, 0.34, 0.34), cf, CHAR, Enum.Material.Wood, Enum.PartType.Cylinder)
	end

	-- Coiled sword: blade, crossguard and grip, a spiral of iron wound round the blade.
	local sword = base * CFrame.new(0, 2.1, 0) * CFrame.Angles(math.rad(6), 0, math.rad(-4))
	part(group, "CoiledBlade", Vector3.new(0.3, 4, 0.08), sword, IRON, Enum.Material.Metal)
	part(group, "Crossguard", Vector3.new(1.3, 0.16, 0.22), sword * CFrame.new(0, 2.05, 0), IRON, Enum.Material.Metal)
	part(group, "Grip", Vector3.new(0.14, 0.9, 0.14), sword * CFrame.new(0, 2.6, 0), CHAR, Enum.Material.Wood)
	part(group, "Pommel", Vector3.new(0.3, 0.3, 0.3), sword * CFrame.new(0, 3.1, 0), IRON, Enum.Material.Metal, Enum.PartType.Ball)
	for k = 0, 13 do
		local t = k / 13
		part(group, "Coil", Vector3.new(0.22, 0.1, 0.42), sword * CFrame.new(0, -1.7 + t * 3.4, 0) * CFrame.Angles(0, t * math.pi * 6, 0) * CFrame.new(0.2, 0, 0), IRON, Enum.Material.Metal)
	end

	-- Fire: the built-in Fire instance always renders; particles add licks, sparks and smoke.
	local heart = part(group, "FireHeart", Vector3.new(1, 1, 1), base * CFrame.new(0, 1.2, 0), GLOW, Enum.Material.SmoothPlastic)
	heart.Transparency = 1
	for _, f in { { 5.5, 9, Color3.fromRGB(255, 120, 40), Color3.fromRGB(150, 30, 10) }, { 3, 13, Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 90, 20) } } do
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = f[1], f[2], f[3], f[4]
		fire.Parent = heart
	end
	if Assets.Textures.Flame ~= "" then
		emitter(heart, Assets.Textures.Flame, {
			Rate = 22, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(12, 12),
			Size = keys({ { 0, 1.4 }, { 0.5, 1.8 }, { 1, 0 } }), Transparency = keys({ { 0, 0.2 }, { 0.7, 0.5 }, { 1, 1 } }),
			Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(220, 60, 20)), LightEmission = 0.9, Rotation = NumberRange.new(-20, 20),
		})
	end
	if Assets.Textures.Ember ~= "" then
		emitter(heart, Assets.Textures.Ember, {
			Rate = 14, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0.6, 1.5, 0.4), Drag = 0.6, Size = keys({ { 0, 0.18 }, { 1, 0.04 } }),
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 80, 30)), LightEmission = 1, LightInfluence = 0,
		})
	end
	if Assets.Textures.Smoke ~= "" then
		emitter(heart, Assets.Textures.Smoke, {
			Rate = 3, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(1.5, 2.5), Acceleration = Vector3.new(0.3, 0.4, 0),
			Size = keys({ { 0, 1 }, { 1, 6 } }), Transparency = keys({ { 0, 1 }, { 0.2, 0.75 }, { 1, 1 } }),
			Color = ColorSequence.new(Color3.fromRGB(110, 104, 100), Color3.fromRGB(70, 74, 80)),
		})
	end

	-- Warm light; the Fire effect itself supplies the flicker (no per-frame server writes).
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 160, 80), 30, 2.4, true
	light.Parent = heart
	return heart
end

return Bonfire

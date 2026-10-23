--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryBonfire
-- The Primal Bonfire: a recessed charcoal bed inside a low, jointed stone hearth, stacked split
-- firewood and the coiled sword. Fire, drifting embers and smoke rise from the logs; the paving
-- never carries a flat orange glow disc or a painted ring standing in for the hearth.
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)

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

-- `base` is the surrounding plaza top, Y up. The charcoal bed stays below the coping.
function Bonfire.Build(parent: Instance, base: CFrame): BasePart
	local group = Instance.new("Folder")
	group.Name = "PrimalBonfire"
	group.Parent = parent

	-- Radial blue-grey masonry has actual depth, staggered joints, a dark recessed bowl, and a
	-- broad weathered coping. Its low profile preserves the altar's walk-up and portrait camera.
	local stoneOptions = { Collide = false, Query = false, Shadow = true }
	for k = 0, 23 do
		local angle = math.pi * 2 * k / 24
		local frame = base * CFrame.Angles(0, angle, 0)
		Kit.slab(group, "HearthFoundation", Vector3.new(1.24, 0.25, 1.2), frame * CFrame.new(0, 0.125, -4.05), "StoneDark", stoneOptions)
		Kit.slab(group, "HearthWall", Vector3.new(1.08, 0.46, 0.88), frame * CFrame.new(0, 0.45, -3.95), "Stone", stoneOptions)
		local cap = base * CFrame.Angles(0, angle + math.pi / 24, 0) * CFrame.new(0, 0.77, -4.0)
		Kit.slab(group, "JointedHearthCoping", Vector3.new(1.19, 0.2, 1.15), cap, "Stone", stoneOptions)
	end
	Kit.disc(group, "RecessedHearthBowl", 3.52, 0.12, base * CFrame.new(0, 0.075, 0), Color3.fromRGB(37, 36, 35), Enum.Material.Slate, Kit.decor()).MaterialVariant = "AsuraStone"
	local rng = Random.new(4281)
	for k = 1, 24 do
		local angle, radius = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.3, 3.25)
		local coal = part(group, "BankedCharcoal", Vector3.new(rng:NextNumber(0.35, 0.8), rng:NextNumber(0.13, 0.3), rng:NextNumber(0.3, 0.7)),
			base * CFrame.new(math.cos(angle) * radius, 0.18, math.sin(angle) * radius) * CFrame.Angles(0, angle, 0), if k % 3 == 0 then ASH else CHAR, Enum.Material.Slate, Enum.PartType.Ball)
		coal.CastShadow = false
	end

	-- Two crossed courses make readable firewood rather than six thin sticks hovering in glow.
	for layer = 0, 1 do
		for k = -1, 1 do
			local cf = base * CFrame.Angles(0, math.rad(22 + layer * 90), 0) * CFrame.new(0, 0.48 + layer * 0.44, k * 0.76)
			local length = 3.6 + (if k == 0 then 0.6 else 0)
			local log = part(group, "StackedCharredFirewood", Vector3.new(length, 0.6, 0.64), cf, Color3.fromRGB(64, 47, 34), Enum.Material.Wood, Enum.PartType.Cylinder)
			log.MaterialVariant = "AsuraTimber"
			for _, side in { -1, 1 } do
				part(group, "SplitLogEnd", Vector3.new(0.024, 0.43, 0.46), cf * CFrame.new(side * (length / 2 + 0.01), 0, 0), Color3.fromRGB(103, 75, 45), Enum.Material.Wood, Enum.PartType.Cylinder)
			end
		end
	end
	for k = 0, 2 do
		local a = math.rad(k * 120 + 15)
		local frame = base * CFrame.Angles(0, a, 0)
		local foot, tip = (frame * CFrame.new(0, 0.6, -1.25)).Position, (frame * CFrame.new(0, 2.3, -0.25)).Position
		local cf = CFrame.lookAt((foot + tip) / 2, tip) * CFrame.Angles(0, math.rad(90), 0)
		part(group, "LeaningCharredLog", Vector3.new((tip - foot).Magnitude + 0.25, 0.48, 0.5), cf, CHAR, Enum.Material.Wood, Enum.PartType.Cylinder).MaterialVariant = "AsuraTimber"
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
	for _, f in { { 3.8, 6, Color3.fromRGB(255, 150, 55), Color3.fromRGB(155, 46, 16) }, { 2.3, 9, Color3.fromRGB(255, 205, 120), Color3.fromRGB(230, 105, 28) } } do
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = f[1], f[2], f[3], f[4]
		fire.Parent = heart
	end
	if Assets.Textures.Flame ~= "" then
		emitter(heart, Assets.Textures.Flame, {
			Rate = 16, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1.4, 3), SpreadAngle = Vector2.new(12, 12),
			Size = keys({ { 0, 1.1 }, { 0.5, 1.5 }, { 1, 0 } }), Transparency = keys({ { 0, 0.3 }, { 0.7, 0.6 }, { 1, 1 } }),
			Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(220, 60, 20)), LightEmission = 0.9, Rotation = NumberRange.new(-20, 20),
		})
	end
	if Assets.Textures.Ember ~= "" then
		emitter(heart, Assets.Textures.Ember, {
			Rate = 8, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(2.2, 4), SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0.6, 1.1, 0.4), Drag = 0.9, Size = keys({ { 0, 0.13 }, { 1, 0.025 } }),
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 80, 30)), LightEmission = 1, LightInfluence = 0,
		})
	end
	if Assets.Textures.Smoke ~= "" then
		emitter(heart, Assets.Textures.Smoke, {
			Rate = 4, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(1.3, 2.2), Acceleration = Vector3.new(0.55, 0.35, 0.2),
			Size = keys({ { 0, 1.8 }, { 1, 8 } }), Transparency = keys({ { 0, 1 }, { 0.2, 0.8 }, { 1, 1 } }),
			Color = ColorSequence.new(Color3.fromRGB(110, 104, 100), Color3.fromRGB(70, 74, 80)),
		})
	end

	-- Warm light; the Fire effect itself supplies the flicker (no per-frame server writes).
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 175, 95), 24, 1.8, true
	light.Parent = heart
	return heart
end

return Bonfire

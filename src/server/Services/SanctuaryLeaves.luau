--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryLeaves
-- Crimson leaves for the Sanctuary: a fluttering ParticleEmitter shed from the Veiled Ascetic's
-- canopy (and the plaza sky), plus fallen-leaf scatter on the dais, basins and stairs.
-- Textures are uploaded Decals (assets/build/veiled_titan/leaves/, ids in assets/ASSET_IDS.md);
-- until they exist the emitter uses the stock spark texture and the scatter uses tiny flat parts.
local Leaves = {}

Leaves.LEAF_TEXTURE = "" -- rbxassetid://<crimson_leaf.png>  (single leaf, alpha)
Leaves.SCATTER_TEXTURE = "" -- rbxassetid://<leaf_scatter.png> (cluster of fallen leaves, alpha)

local FALLBACK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local CRIMSON = { Color3.fromRGB(150, 16, 24), Color3.fromRGB(122, 10, 18), Color3.fromRGB(176, 30, 34), Color3.fromRGB(96, 12, 16) }

export type EmitterProfile = {
	Rate: number?,
	Size: number?,
	Wind: Vector3?,
}

local function keys(points: { { number } }): NumberSequence
	local list = {}
	for _, p in points do
		table.insert(list, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(list)
end

-- Leaves tumble (fast spin), drift on a gentle draft, flutter side to side via high drag + a
-- sideways spread, and fade in/out so there is never a pop at the canopy or the ground.
function Leaves.Emitter(source: BasePart, profile: EmitterProfile?): ParticleEmitter
	local p: EmitterProfile = profile or {}
	local size = p.Size or 0.55
	local textured = Leaves.LEAF_TEXTURE ~= ""
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CrimsonLeaves"
	emitter.Texture = if textured then Leaves.LEAF_TEXTURE else FALLBACK_TEXTURE
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, if textured then Color3.fromRGB(255, 236, 236) else CRIMSON[3]),
		ColorSequenceKeypoint.new(1, if textured then Color3.fromRGB(190, 150, 150) else CRIMSON[2]),
	})
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.Size = keys({ { 0, size * 0.85 }, { 0.5, size }, { 1, size * 0.8 } })
	emitter.Squash = keys({ { 0, 0 }, { 0.25, 0.45 }, { 0.5, -0.35 }, { 0.75, 0.4 }, { 1, 0 } }) -- edge-on flips
	emitter.Transparency = keys({ { 0, 1 }, { 0.08, 0 }, { 0.85, 0.05 }, { 1, 1 } })
	emitter.Lifetime = NumberRange.new(9, 14)
	emitter.Rate = p.Rate or 14
	emitter.Speed = NumberRange.new(0.4, 1.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = p.Wind or Vector3.new(1.1, -0.9, 0.45)
	emitter.Drag = 0.9
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-160, 160)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = source
	return emitter
end

-- Fallen leaves on a surface. With SCATTER_TEXTURE: a few large decal tiles; otherwise
-- individual flat crimson slivers. `surface` is a CFrame on the top face (Y up); `extent` is the
-- ellipse half-size (X, Z) so treads and basins can take narrow strips.
function Leaves.Scatter(parent: Instance, surface: CFrame, extent: Vector2, count: number, seed: number, floating: boolean?)
	local rng = Random.new(seed)
	local group = Instance.new("Folder")
	group.Name = "FallenLeaves"
	group.Parent = parent
	local useDecal = Leaves.SCATTER_TEXTURE ~= ""
	local n = if useDecal then math.max(1, math.floor(count / 25)) else count
	for _ = 1, n do
		local r = math.sqrt(rng:NextNumber())
		local a = rng:NextNumber(0, math.pi * 2)
		local spot = surface * CFrame.new(math.cos(a) * r * extent.X, 0, math.sin(a) * r * extent.Y) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local leaf = Instance.new("Part")
		leaf.Name = "Leaf"
		leaf.Anchored, leaf.CanCollide, leaf.CanQuery, leaf.CanTouch = true, false, false, false
		leaf.CastShadow = false
		leaf.Material = Enum.Material.SmoothPlastic
		if useDecal then
			local s = math.min(rng:NextNumber(4, 7), extent.X * 2, extent.Y * 2)
			leaf.Size = Vector3.new(s, 0.05, s)
			leaf.Transparency = 1
			leaf.CFrame = spot * CFrame.new(0, 0.03, 0)
			local decal = Instance.new("Decal")
			decal.Texture = Leaves.SCATTER_TEXTURE
			decal.Face = Enum.NormalId.Top
			decal.Parent = leaf
		else
			leaf.Size = Vector3.new(rng:NextNumber(0.35, 0.6), 0.05, rng:NextNumber(0.22, 0.34))
			leaf.Color = CRIMSON[rng:NextInteger(1, #CRIMSON)]
			local tilt = if floating then 0 else rng:NextNumber(-0.25, 0.25)
			leaf.CFrame = spot * CFrame.new(0, 0.03, 0) * CFrame.Angles(tilt, 0, tilt * 0.5)
		end
		leaf.Parent = group
	end
	return group
end

return Leaves

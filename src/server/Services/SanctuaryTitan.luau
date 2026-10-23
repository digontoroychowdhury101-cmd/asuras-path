--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryTitan
-- Mounts the fused tree and woman (ServerStorage.AsuraAssets.FusedTreeStatue, built by
-- tools/blender/fuse_tree_woman.py) on the colossus terrace. She stands on the root mass of a sacred
-- tree four times her height, clear of its trunk, its root flare planted on the terrace; roots coil round her hem and reach toward her
-- shoulders, crimson sap runs down the bark and the blood-red crown is solid leaf geometry. Every
-- piece is scaled together (her silhouette FIGURE_HEIGHT studs) so the composition never drifts apart.
-- Imported mesh references, UVs and PBR maps are retained.
local Leaves = require(script.Parent:WaitForChild("SanctuaryLeaves") :: ModuleScript)

local Titan = {}

local FIGURE_HEIGHT = 150
local SINK = 2 -- the root bed beds into the terrace so no root edge hovers
-- Terrace layout (SanctuaryColossus / SanctuaryRoutes): her place `Forward` studs in front of the terrace
-- centre, root platform `Radius`. fuse_tree_woman.py draws the low roots in about a bed centre exactly
-- `Forward` behind her (stats.json: Forward 150, floor reach 227), so the flare sits inside the rim.
Titan.TreeSpan = { Forward = 150, Radius = 240 }
-- The authored floor sits this many figure heights above the lowest point of the piece (buried root
-- stubs dive below it), so the floor, where the root flare meets it, lands on the terrace
-- (stats.json FloorAboveBottom).
local FLOOR_ABOVE_BOTTOM = 0.1476

local function group(model: Model, prefixes: { string }, name: string): Model
	local g = Instance.new("Model")
	g.Name = name
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			for _, prefix in prefixes do
				if p.Name:sub(1, #prefix) == prefix then
					p.Parent = g
					break
				end
			end
		end
	end
	g.Parent = model
	return g
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Centre of the root bed: the tree chunks that reach the lowest tenth of its height.
local function rootBed(tree: Model): Vector3
	local box, size = tree:GetBoundingBox()
	local floor = box.Position.Y - size.Y * 0.5
	local sum, n = Vector3.zero, 0
	for _, p in tree:GetChildren() do
		local part = p :: BasePart
		if part.Position.Y - part.Size.Y * 0.5 < floor + size.Y * 0.1 then
			sum += part.Position
			n += 1
		end
	end
	return if n > 0 then sum / n else box.Position
end

-- Only the trunk's walkable root base collides (PreciseConvexDecomposition, authored in Studio); boughs,
-- leaves, sap and the generated roots are decoration.
local function collisions(tree: Model, roots: Model)
	local box, size = tree:GetBoundingBox()
	local base = box.Position.Y - size.Y * 0.5 + size.Y * 0.15
	for _, p in tree:GetChildren() do
		local part = p :: BasePart
		local solid = not part.Name:find("Leaves") and part.Position.Y - part.Size.Y * 0.5 < base
		part.CanCollide, part.CanQuery = solid, solid
	end
	for _, p in roots:GetChildren() do
		local part = p :: BasePart
		part.CanCollide, part.CanQuery = false, false
	end
end

-- `focus` is where visitors look from (the plaza); the tree ends up on the far side of her.
-- `anchor` is her place: the floor point under the centre of her figure on the terrace top.
function Titan.Mount(statue: Model, anchor: CFrame, focus: Vector3?): boolean
	local cards = statue:FindFirstChild("Titan_Leaves")
	if cards then
		cards:Destroy()
	end
	local figure = group(statue, { "Titan_Figure" }, "Figure")
	local tree = group(statue, { "Titan_Canopy" }, "Tree")
	local roots = group(statue, { "Titan_Roots", "Titan_Sap" }, "Roots")
	if #figure:GetChildren() == 0 or #tree:GetChildren() == 0 then
		return false
	end
	collisions(tree, roots)

	local height = figure:GetExtentsSize().Y
	if height > 0 then
		statue:ScaleTo(statue:GetScale() * FIGURE_HEIGHT / height)
	end

	-- Away-from-plaza direction; turn the piece about her so the tree's root bed lies that way.
	local away = flat(anchor.Position - (focus or (anchor.Position + anchor.LookVector)))
	away = if away.Magnitude > 1e-3 then away.Unit else Vector3.zAxis
	local fc = figure:GetBoundingBox().Position
	local back = flat(rootBed(tree) - fc)
	if back.Magnitude > 1e-3 then
		local turn = math.atan2(away.X, away.Z) - math.atan2(back.X, back.Z)
		statue:PivotTo(CFrame.new(fc) * CFrame.Angles(0, turn, 0) * CFrame.new(-fc) * statue:GetPivot())
	end

	-- Her figure centred over the anchor; the authored floor on the terrace, sunk SINK.
	local box, size = statue:GetBoundingBox()
	local bottom = box.Position.Y - size.Y * 0.5
	local floor = bottom + FLOOR_ABOVE_BOTTOM * FIGURE_HEIGHT
	fc = figure:GetBoundingBox().Position
	statue:PivotTo(statue:GetPivot() + Vector3.new(anchor.X - fc.X, anchor.Y - SINK - floor, anchor.Z - fc.Z))

	local fbox, fsize = figure:GetBoundingBox()
	local depth = math.abs(away.X) * fsize.X + math.abs(away.Z) * fsize.Z
	statue:SetAttribute("FigureHeight", fsize.Y)
	statue:SetAttribute("SacredTreeHeight", tree:GetExtentsSize().Y)

	-- Leaves fall from the crown: the four highest tree chunks each shed a share.
	local parts = tree:GetChildren()
	table.sort(parts, function(a, b)
		return (a :: BasePart).Position.Y > (b :: BasePart).Position.Y
	end)
	for i = 1, math.min(4, #parts) do
		Leaves.Emitter(parts[i] :: BasePart, { Rate = 2, Size = 0.45, Wind = Vector3.new(1.2, -0.5, 0.35) })
	end

	-- Key light from the plaza side: three spots (Roblox caps a light's range at 60 studs) on her
	-- hem, chest and veiled face so she reads against the pale bark instead of as a silhouette. The
	-- hem spot is the closest to her white robe, so it is the dimmest (no blown-out hotspot).
	for i, h in { 0.25, 0.55, 0.85 } do
		local target = fbox.Position + Vector3.yAxis * (fsize.Y * (h - 0.5))
		local lamp = Instance.new("Part")
		lamp.Name = "TitanKeyLight" .. i
		lamp.Anchored, lamp.CanCollide, lamp.CanQuery, lamp.CanTouch = true, false, false, false
		lamp.Transparency, lamp.Size = 1, Vector3.one
		local distance = math.clamp(depth * 0.5 + 10 - (h - 0.25) * 30, 32, 52)
		lamp.CFrame = CFrame.lookAt(target - away * distance - Vector3.yAxis * 4, target)
		local spot = Instance.new("SpotLight")
		spot.Color = Color3.fromRGB(255, 210, 172)
		spot.Range, spot.Brightness, spot.Angle, spot.Shadows = 60, if i == 1 then 0.9 else 2.6, 80, false
		spot.Parent = lamp
		lamp.Parent = statue
	end
	return true
end

return Titan

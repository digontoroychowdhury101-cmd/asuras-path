--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryTitan
-- Mounts the Veiled Ascetic (ServerStorage.AsuraAssets.AsuraVeiledTitan) on the colossus terrace.
-- The asset is pre-composed in Blender (tools/blender/compose_titan.py), in studs: her figure
-- (Titan_Figure_NN, 100 tall), the sacred tree (Titan_Canopy_NN, 4.5x her, trunk 175 behind her,
-- root bed flat on the floor) and the bark roots binding them (Titan_Roots_NN). Model space z = 0 is
-- the floor at her plinth base, so the whole piece moves and scales as one: no per-part fitting.
local Leaves = require(script.Parent:WaitForChild("SanctuaryLeaves") :: ModuleScript)
local Canopy = require(script.Parent:WaitForChild("SanctuaryCanopy") :: ModuleScript)

local Titan = {}

local FIGURE_HEIGHT = 100 -- plinth base to crown spikes (the composed asset's own scale)
local SINK = 2 -- the whole piece beds into the terrace so no plinth or root edge hovers
-- Footprint of the composed tree, for the terrace: its root bed is centred ~150 behind her and
-- spreads ~240 studs from there.
Titan.TreeSpan = { Forward = 150, Radius = 240 }

local function group(model: Model, pattern: string, name: string): Model
	local g = Instance.new("Model")
	g.Name = name
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name:find(pattern) then
			p.Parent = g
		end
	end
	g.Parent = model
	return g
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- `focus` is where visitors look from (the plaza); the tree ends up on the far side of her.
-- `anchor` is her seat: the centre of her plinth on the terrace top.
function Titan.Mount(statue: Model, anchor: CFrame, focus: Vector3?): boolean
	local cards = statue:FindFirstChild("Titan_Leaves")
	if cards then
		cards:Destroy()
	end
	local figure = group(statue, "^Titan_Figure", "Figure")
	local tree = group(statue, "^Titan_Canopy", "Tree")
	local roots = group(statue, "^Titan_Roots", "Roots")
	if #figure:GetChildren() == 0 or #tree:GetChildren() == 0 then
		return false
	end
	for _, g in { tree, roots } do
		for _, p in g:GetChildren() do
			local part = p :: BasePart
			part.CanCollide, part.CanQuery = false, false
		end
	end
	statue:PivotTo(anchor)

	-- Away-from-plaza direction; turn the piece about her so the tree points that way.
	local away = flat(anchor.Position - (focus or (anchor.Position + anchor.LookVector)))
	away = if away.Magnitude > 1e-3 then away.Unit else Vector3.zAxis
	local fc = figure:GetBoundingBox().Position
	local back = flat(tree:GetBoundingBox().Position - fc)
	if back.Magnitude > 1e-3 then
		local turn = math.atan2(away.X, away.Z) - math.atan2(back.X, back.Z)
		statue:PivotTo(CFrame.new(fc) * CFrame.Angles(0, turn, 0) * CFrame.new(-fc) * statue:GetPivot())
	end

	-- One scale for the whole piece (keeps the roots joined), then seat her plinth on the anchor.
	local height = figure:GetExtentsSize().Y
	if height > 0 then
		statue:ScaleTo(statue:GetScale() * FIGURE_HEIGHT / height)
	end
	local fbox0, fsize0 = figure:GetBoundingBox()
	local seat = fbox0.Position - Vector3.yAxis * fsize0.Y * 0.5
	statue:PivotTo(statue:GetPivot() + (anchor.Position - Vector3.yAxis * SINK - seat))
	local fbox, fsize = figure:GetBoundingBox()
	local depth = math.abs(away.X) * fsize.X + math.abs(away.Z) * fsize.Z

	-- Leaves fall from the crown: the four highest tree chunks each shed a share.
	local parts = tree:GetChildren()
	table.sort(parts, function(a, b)
		return (a :: BasePart).Position.Y > (b :: BasePart).Position.Y
	end)
	for i = 1, math.min(4, #parts) do
		Leaves.Emitter(parts[i] :: BasePart, { Rate = 22, Size = 4 })
	end
	Canopy.Build(statue, tree)

	-- Key light from the plaza side: three spots (Roblox caps a light's range at 60 studs) on her
	-- lap, chest and veiled face so she reads against the dusk haze instead of as a silhouette.
	for i, h in { 0.25, 0.55, 0.85 } do
		local target = fbox.Position + Vector3.yAxis * (fsize.Y * (h - 0.5))
		local lamp = Instance.new("Part")
		lamp.Name = "TitanKeyLight" .. i
		lamp.Anchored, lamp.CanCollide, lamp.CanQuery, lamp.CanTouch = true, false, false, false
		lamp.Transparency, lamp.Size = 1, Vector3.one
		lamp.CFrame = CFrame.lookAt(target - away * (depth * 0.5 + 10 - (h - 0.25) * 30) - Vector3.yAxis * 4, target)
		local spot = Instance.new("SpotLight")
		spot.Color = Color3.fromRGB(255, 206, 160)
		spot.Range, spot.Brightness, spot.Angle, spot.Shadows = 60, 5, 80, false
		spot.Parent = lamp
		lamp.Parent = statue
	end
	return true
end

return Titan

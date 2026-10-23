--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryTitan
-- Mounts the Veiled Ascetic (ServerStorage.AsuraAssets.AsuraVeiledTitan) on the colossus terrace.
-- The imported figure and its binding roots are enlarged together around the original plinth base.
-- Her seated silhouette is 150 studs tall; the established 450-stud sacred tree and its root-bed
-- footprint stay at their authored scale. Imported mesh references, UVs and PBR maps are retained.
local Leaves = require(script.Parent:WaitForChild("SanctuaryLeaves") :: ModuleScript)
local Canopy = require(script.Parent:WaitForChild("SanctuaryCanopy") :: ModuleScript)

local Titan = {}

local AUTHORED_FIGURE_HEIGHT = 100
local FIGURE_HEIGHT = 150 -- plinth base to crown spikes, independent of the tree's footprint
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

-- Roots were sculpted onto her robe and shoulders. Moving them with her, rather than stretching
-- individual root pieces, preserves that contact. Their ground ends bed into the much wider tree
-- root mass; neither the tree nor the terrace needs to grow with her.
local function monument(figure: Model, roots: Model)
	local box, size = figure:GetBoundingBox()
	local seat = box.Position - Vector3.yAxis * size.Y * 0.5
	local scale = FIGURE_HEIGHT / size.Y
	for _, model in { figure, roots } do
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				child.Size *= scale
				child.CFrame = CFrame.new(seat + (child.Position - seat) * scale) * child.CFrame.Rotation
			end
		end
	end
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

	-- Normalize the imported composition first, then enlarge only the pale figure and the roots
	-- embracing it. The existing canopy remains approximately 450 studs tall, rather than 675.
	local height = figure:GetExtentsSize().Y
	if height > 0 then
		statue:ScaleTo(statue:GetScale() * AUTHORED_FIGURE_HEIGHT / height)
	end
	monument(figure, roots)
	local fbox0, fsize0 = figure:GetBoundingBox()
	local seat = fbox0.Position - Vector3.yAxis * fsize0.Y * 0.5
	statue:PivotTo(statue:GetPivot() + (anchor.Position - Vector3.yAxis * SINK - seat))
	local fbox, fsize = figure:GetBoundingBox()
	local depth = math.abs(away.X) * fsize.X + math.abs(away.Z) * fsize.Z
	statue:SetAttribute("FigureHeight", fsize.Y)
	statue:SetAttribute("SacredTreeHeight", tree:GetExtentsSize().Y)
	statue:SetAttribute("MonumentalFigureScale", FIGURE_HEIGHT / AUTHORED_FIGURE_HEIGHT)

	-- Leaves fall from the crown: the four highest tree chunks each shed a share.
	local parts = tree:GetChildren()
	table.sort(parts, function(a, b)
		return (a :: BasePart).Position.Y > (b :: BasePart).Position.Y
	end)
	for i = 1, math.min(4, #parts) do
		Leaves.Emitter(parts[i] :: BasePart, { Rate = 2, Size = 0.45, Wind = Vector3.new(1.2, -0.5, 0.35) })
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
		local distance = math.clamp(depth * 0.5 + 10 - (h - 0.25) * 30, 32, 52)
		lamp.CFrame = CFrame.lookAt(target - away * distance - Vector3.yAxis * 4, target)
		local spot = Instance.new("SpotLight")
		spot.Color = Color3.fromRGB(255, 210, 172)
		spot.Range, spot.Brightness, spot.Angle, spot.Shadows = 60, 3.3, 80, false
		spot.Parent = lamp
		lamp.Parent = statue
	end
	return true
end

return Titan

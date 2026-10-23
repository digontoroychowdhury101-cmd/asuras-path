--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryColossus
-- The Veiled Ascetic closes the Sanctuary's main axis. Past the Ascension Stairs and the gate, a
-- rock terrace flush with the landing carries the colossus (150 studs seated) at the foot of the
-- sacred tree (~450 studs, sized by SanctuaryTitan), so every view up the stairs from the bonfire ends on her face. The terrace is a sky-island
-- shard like the plaza: kerbed slab, tapering rock foot; its dressing is SanctuaryTerrace's (lobby kit).
local Dressing = require(script.Parent:WaitForChild("SanctuaryDressing") :: ModuleScript)
local Leaves = require(script.Parent:WaitForChild("SanctuaryLeaves") :: ModuleScript)
local Titan = require(script.Parent:WaitForChild("SanctuaryTitan") :: ModuleScript)
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Terrace = require(script.Parent:WaitForChild("SanctuaryTerrace") :: ModuleScript)

local Colossus = {}

local RADIUS = math.ceil(Titan.TreeSpan.Radius) + 6 -- the tree's whole root platform fits on it
local OVERLAP = 8 -- the terrace runs under the back of the landing so the floor is continuous
local FORWARD = Titan.TreeSpan.Forward -- her seat: the front edge of the roots, toward the plaza
local STONE = Color3.fromRGB(95, 101, 96)
local STONE_DARK = Color3.fromRGB(41, 49, 51)
local ROCK = Color3.fromRGB(49, 60, 64)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, solid: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.CanCollide = solid ~= false
	p.CanQuery = p.CanCollide
	p.Parent = parent
	return p
end

local function disc(parent: Instance, name: string, radius: number, height: number, cf: CFrame, color: Color3, material: Enum.Material): BasePart
	local p = part(parent, name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- `origin` is the plaza centre; `top` and `back` are the landing's height and far edge from it.
function Colossus.Build(parent: Instance, origin: Vector3, top: number, back: number): BasePart
	local group = Instance.new("Folder")
	group.Name = "ColossusSanctuary"
	group.Parent = parent
	local plaza = CFrame.new(origin)
	local centre = plaza * CFrame.new(0, top, -(back + RADIUS - OVERLAP))

	-- Existing slab, kerb and support cylinders retain their exact movement collision. Once all
	-- broad, overlapping cliff masses are present, only those irregular scanned-rock surfaces and
	-- the authored processional paving remain visible; no cylindrical skirt is left around them.
	local slab = disc(group, "ColossusTerrace", RADIUS, 6, centre * CFrame.new(0, -3.03, 0), STONE_DARK, Enum.Material.Slate)
	local kerb = disc(group, "TerraceKerb", RADIUS + 2, 2.5, centre * CFrame.new(0, -6.9, 0), STONE, Enum.Material.Slate)
	local foot = disc(group, "TerraceFoot", RADIUS * 0.84, 70, centre * CFrame.new(0, -41, 0), ROCK, Enum.Material.Rock)
	local root = disc(group, "TerraceRoot", RADIUS * 0.55, 90, centre * CFrame.new(0, -120, 0), ROCK, Enum.Material.Rock)
	for p, surface in { [slab] = "TerracePaving", [kerb] = "StoneDark", [foot] = "Rock", [root] = "Rock" } do
		local s = Kit.Surface[surface]
		p.Color, p.Material, p.MaterialVariant = s.Color, s.Material, s.Variant
	end
	root.Transparency = 1
	slab.Color = Kit.Surface.Paving.Color
	-- Keep the old visible support as a boot-safe fallback if the uploaded cliff library is absent.
	if Terrace.Dress(group, centre, RADIUS, FORWARD) then
		for _, cylinder in { slab, kerb, foot, root } do cylinder.Transparency = 1 end
	end
	Leaves.Scatter(group, centre * CFrame.new(0, 0.02, 0), Vector2.new(RADIUS - 10, RADIUS - 10), 420, 31)

	-- Her seat, facing back down the axis toward the plaza and the bonfire.
	local anchor = part(group, "AsuraColossusAnchor", Vector3.new(4, 4, 4), centre * CFrame.new(0, 0, FORWARD), STONE, Enum.Material.SmoothPlastic, false)
	anchor.Transparency = 1
	Dressing.try("Colossus", Dressing.Colossus, group, anchor.CFrame, nil, origin)
	return anchor
end

return Colossus

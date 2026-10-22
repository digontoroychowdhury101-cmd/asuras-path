--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryDressing
-- Places the uploaded PBR set pieces (ServerStorage.AsuraAssets, see assets/ASSET_IDS.md) into the
-- procedurally built Sanctuary: the Veiled Ascetic colossus (roots and canopy grown into one model,
-- tools/blender/build_titan.py), crimson leaves shed from her canopy, and iron gates flanking the
-- Ascension portal. Older Gothic-statue / loose-roots / dead-tree pieces remain as a fallback.
-- Textures come from each MeshPart's SurfaceAppearance, so materials are never overridden.
-- Calls return false if the asset folder is missing; Dressing.try pcall-wraps them for boot safety.
local ServerStorage = game:GetService("ServerStorage")
local Leaves = require(script.Parent:WaitForChild("SanctuaryLeaves") :: ModuleScript)
local Titan = require(script.Parent:WaitForChild("SanctuaryTitan") :: ModuleScript)

local Dressing = {}

local COLOSSUS_HEIGHT = 48 -- fits between the arch pillars (inner edges at +/-21 studs)
local COLOSSUS_YAW = 180 -- the fallback Gothic statue faces its +Z; the dais anchor looks down -Z
local ROOT_LENGTH = 26
local TREE_HEIGHT = 26
local GATE_HEIGHT = 13

function Dressing.try(label: string, fn: (...any) -> boolean, ...: any): boolean
	local ok, placed = pcall(fn, ...)
	if not ok then
		warn(string.format("[Asura's Path] Sanctuary dressing '%s' skipped: %s", label, tostring(placed)))
	end
	return ok and placed == true
end

local function asset(name: string): Model?
	local folder = ServerStorage:FindFirstChild("AsuraAssets")
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("Model") then found:Clone() else nil
end

-- Static scenery: anchored, no collisions beyond the statue body, cheap queries.
local function settle(model: Model, collide: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide
			d.CanQuery = collide
			d.CanTouch = false
			d.CastShadow = true
		end
	end
end

local function scaleTo(model: Model, axis: "X" | "Y" | "Z", target: number)
	local size = model:GetExtentsSize()
	local current = if axis == "X" then size.X elseif axis == "Y" then size.Y else size.Z
	if current > 0 then
		model:ScaleTo(model:GetScale() * target / current)
	end
end

local unified = false -- true once the Veiled Ascetic is mounted; Roots/SacredTree then add nothing

function Dressing.Colossus(parent: Instance, anchor: CFrame, proxy: Instance?, focus: Vector3?): boolean
	local statue = asset("AsuraVeiledTitan")
	unified = statue ~= nil
	statue = statue or asset("AsuraColossusStatue")
	if not statue then
		return false
	end
	settle(statue, true)
	if unified then
		-- Figure, tree and leaves are laid out against the dais and arch by SanctuaryTitan.
		if not Titan.Mount(statue, anchor, focus) then
			statue:Destroy()
			unified = false
			return false
		end
	else
		scaleTo(statue, "Y", COLOSSUS_HEIGHT)
		statue:PivotTo(anchor * CFrame.Angles(0, math.rad(COLOSSUS_YAW), 0))
	end
	statue.Parent = parent
	if proxy then proxy:Destroy() end
	return true
end

-- Roots radiate from the plinth like they grew out of the stone: tilted, half-sunk, varied.
function Dressing.Roots(parent: Instance, base: CFrame): boolean
	if unified then return true end -- roots are grown onto the Veiled Ascetic itself
	local template = asset("AsuraRoots")
	if not template then
		return false
	end
	scaleTo(template, "X", ROOT_LENGTH)
	settle(template, false)
	for index, yaw in { 20, 95, 160, 215, 290, 340 } do
		local roots = if index == 1 then template else template:Clone()
		local reach = 20 + (index % 3) * 3
		local spot = base * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(0, 0.6, -reach)
		roots:PivotTo(spot * CFrame.Angles(math.rad(-8 - (index % 2) * 6), math.rad(90), 0))
		roots.Parent = parent
	end
	return true
end

-- The fallen trunk stands upright as the dead sacred tree; its crown sheds crimson petals.
function Dressing.SacredTree(parent: Instance, base: CFrame): boolean
	if unified then return true end -- the canopy over her head is the sacred tree
	local tree = asset("AsuraDeadTrunk")
	if not tree then
		return false
	end
	tree:PivotTo(CFrame.Angles(0, 0, math.rad(90)))
	scaleTo(tree, "Y", TREE_HEIGHT)
	settle(tree, true)
	local size = tree:GetExtentsSize()
	tree:PivotTo(base * CFrame.new(0, size.Y * 0.5 - 2, 0) * CFrame.Angles(math.rad(6), 0, math.rad(90)))
	tree.Parent = parent
	local crown = Instance.new("Part")
	crown.Name = "PetalSource"
	crown.Anchored, crown.CanCollide, crown.CanQuery, crown.CanTouch = true, false, false, false
	crown.Transparency = 1
	crown.Size = Vector3.new(16, 4, 16)
	crown.CFrame = base * CFrame.new(0, TREE_HEIGHT - 4, 0)
	crown.Parent = parent
	Leaves.Emitter(crown)
	return true
end

-- A pair of dark iron gates, swung open to frame the Ascension portal.
function Dressing.PortalGates(parent: Instance, portal: CFrame, width: number): boolean
	local template = asset("AsuraIronGate")
	if not template then
		return false
	end
	scaleTo(template, "Y", GATE_HEIGHT)
	settle(template, false)
	local floor = portal * CFrame.new(0, -5.7, 0)
	for side = -1, 1, 2 do
		local gate = if side == 1 then template else template:Clone()
		local hinge = floor * CFrame.new(side * (width * 0.5 + 0.5), 0, 1.5)
		gate:PivotTo(hinge * CFrame.Angles(0, math.rad(side * 70 + (if side == 1 then 180 else 0)), 0) * CFrame.new(side * 3, 0, 0))
		gate.Parent = parent
	end
	return true
end

return Dressing

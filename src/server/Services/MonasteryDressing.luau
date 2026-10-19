--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryDressing
-- Places the uploaded PBR set pieces (ServerStorage.AsuraAssets) into the Desecrated Monastery:
-- iron gates hanging open in the gatehouse, dead sacred trees in the courtyard and cloister
-- garth, a fallen trunk in the ravine and pale roots clutching the shrines and idols. Textures
-- come from each MeshPart's SurfaceAppearance. Every placement is pcall-wrapped and returns false
-- when the asset folder is missing, so cosmetics can never stop the server from booting.
local ServerStorage = game:GetService("ServerStorage")

local Kit = require(script.Parent:WaitForChild("MonasteryKit") :: ModuleScript)

local Dressing = {}

local G = Kit.GROUND

local function try(label: string, fn: () -> boolean): boolean
	local ok, placed = pcall(fn)
	if not ok then
		warn(string.format("[Asura's Path] Monastery dressing '%s' skipped: %s", label, tostring(placed)))
	end
	return ok and placed == true
end

local function asset(name: string): Model?
	local folder = ServerStorage:FindFirstChild("AsuraAssets")
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("Model") then found:Clone() else nil
end

local function settle(model: Model, collide: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, collide, collide, false, true
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

-- The gate leaves hang open inward, as if the monks fled and never closed them.
local function gates(parent: Instance): boolean
	local template = asset("AsuraIronGate")
	if not template then
		return false
	end
	scaleTo(template, "Y", 12.4)
	settle(template, false)
	for side = -1, 1, 2 do
		local gate = if side == 1 then template else template:Clone()
		local hinge = CFrame.new(side * 6.6, G, -753.5)
		gate:PivotTo(hinge * CFrame.Angles(0, math.rad(side * 62 + (if side == 1 then 180 else 0)), 0) * CFrame.new(side * 3, 0, 0))
		local box, extents = gate:GetBoundingBox()
		gate:PivotTo(gate:GetPivot() + Vector3.new(0, G - (box.Position.Y - extents.Y * 0.5), 0))
		gate.Parent = parent
	end
	return true
end

-- Upright dead tree (the trunk asset stood on end) with a crown that sheds crimson leaves.
local function deadTree(parent: Instance, at: Vector3, height: number, lean: number): boolean
	local tree = asset("AsuraDeadTrunk")
	if not tree then
		return false
	end
	tree:PivotTo(CFrame.Angles(0, 0, math.rad(90)))
	scaleTo(tree, "Y", height)
	settle(tree, true)
	local size = tree:GetExtentsSize()
	tree:PivotTo(CFrame.new(at.X, size.Y * 0.5 - 2, at.Z) * CFrame.Angles(math.rad(lean), math.rad(lean * 7), math.rad(90)))
	tree.Parent = parent
	return true
end

local function fallenTrunk(parent: Instance, at: CFrame, length: number): boolean
	local log = asset("AsuraDeadTrunk")
	if not log then
		return false
	end
	scaleTo(log, "X", length)
	settle(log, true)
	log:PivotTo(at)
	log.Parent = parent
	return true
end

local function roots(parent: Instance, center: Vector3, reach: number, length: number, yaws: { number }): boolean
	local template = asset("AsuraRoots")
	if not template then
		return false
	end
	scaleTo(template, "X", length)
	settle(template, false)
	for index, yaw in yaws do
		local cluster = if index == 1 then template else template:Clone()
		local spot = CFrame.new(center.X, G, center.Z) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(0, 0.4, -reach)
		cluster:PivotTo(spot * CFrame.Angles(math.rad(-6 - (index % 2) * 5), math.rad(90), 0))
		cluster.Parent = parent
	end
	return true
end

function Dressing.Build(parent: Instance): number
	local group = Kit.folder("SetPieces", parent)
	local placed = 0
	local jobs: { [string]: () -> boolean } = {
		Gates = function() return gates(group) end,
		CourtyardTree = function() return deadTree(group, Vector3.new(-58, 0, -836), 26, 5) end,
		CloisterTree = function() return deadTree(group, Vector3.new(66, 0, -1048), 22, -4) end,
		RavineLog = function() return fallenTrunk(group, CFrame.new(-58, -9, -960) * CFrame.Angles(0.15, 0.4, 0.1), 30) end,
		GraveLog = function() return fallenTrunk(group, CFrame.new(-40, 1.2, -1086) * CFrame.Angles(0, 1.2, 0.05), 20) end,
		TreeRoots = function() return roots(group, Vector3.new(-58, 0, -836), 7, 14, { 30, 150, 260 }) end,
		CloisterRoots = function() return roots(group, Vector3.new(66, 0, -1048), 6, 12, { 80, 200, 320 }) end,
		GateShrineRoots = function() return roots(group, Vector3.new(0, 0, -716), 5, 10, { 20, 160 }) end,
		CloisterShrineRoots = function() return roots(group, Vector3.new(60, 0, -1006), 5, 10, { 200, 340 }) end,
	}
	for label, job in jobs do
		if try(label, job) then
			placed += 1
		end
	end
	return placed
end

return Dressing

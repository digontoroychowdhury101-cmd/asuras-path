--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryDressing
-- Places the uploaded PBR set pieces (ServerStorage.AsuraAssets, see assets/ASSET_IDS.md) into the
-- procedurally built Sanctuary: the veiled Gothic colossus on the dais, pale roots clutching the
-- plinth, the weeping dead tree shedding crimson petals, and iron gates flanking the Ascension
-- portal. Textures come from each MeshPart's SurfaceAppearance, so materials are never overridden.
-- Every call degrades gracefully (returns false) if the asset folder is missing; callers go
-- through Dressing.try so a cosmetic failure can never stop the server from booting.
local ServerStorage = game:GetService("ServerStorage")

local Dressing = {}

local COLOSSUS_HEIGHT = 48 -- fits between the arch pillars (inner edges at +/-21 studs)
local COLOSSUS_YAW = 180 -- the Poly Haven mesh faces its +Z; the dais anchor looks down -Z
local ROOT_LENGTH = 26
local TREE_HEIGHT = 26
local GATE_HEIGHT = 13
local PETAL = Color3.fromRGB(150, 18, 28)

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

function Dressing.Colossus(parent: Instance, anchor: CFrame, proxy: Instance?): boolean
	local statue = asset("AsuraColossusStatue")
	if not statue then
		return false
	end
	scaleTo(statue, "Y", COLOSSUS_HEIGHT)
	settle(statue, true)
	statue:PivotTo(anchor * CFrame.Angles(0, math.rad(COLOSSUS_YAW), 0))
	statue.Parent = parent
	if proxy then
		proxy:Destroy()
	end
	return true
end

-- Roots radiate from the plinth like they grew out of the stone: tilted, half-sunk, varied.
function Dressing.Roots(parent: Instance, base: CFrame): boolean
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

local function petals(source: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CrimsonPetals"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(PETAL, Color3.fromRGB(90, 10, 16))
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.2) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(7, 11)
	emitter.Rate = 9
	emitter.Speed = NumberRange.new(0.6, 1.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0.9, -1.1, 0.4)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Drag = 0.6
	emitter.Parent = source
end

-- The fallen trunk stands upright as the dead sacred tree; its crown sheds crimson petals.
function Dressing.SacredTree(parent: Instance, base: CFrame): boolean
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
	petals(crown)
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

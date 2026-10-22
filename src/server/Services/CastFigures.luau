--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/CastFigures
-- The speaking cast's bodies (batch 14). `statue` stands a LooksCast figure on the ground: an
-- anchored default-R15-proportioned body (rounded head, solid torso and legs, non-colliding arms)
-- dressed by CostumeKit and scaled about its feet, replacing the old robe-block NPCs; its head
-- stays at the dialogue portrait height (n.Y + ~2.3) and it faces its Look point. `dress` puts a
-- look on a live rig (Master Smith Gao) so the attire binds to the spawned character itself.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Schema = require(Shared.CostumeSchema)
local Looks = require(Shared.LooksCast)
local Kit = require(script.Parent.CostumeKit)

local Figures = {}
Figures.Scale = 0.85 -- portrait height: head centre (3 + 1.8) * 0.85 = 4.1 studs above the feet
local SOLID = { UpperTorso = true, LowerTorso = true, LeftUpperLeg = true, RightUpperLeg = true, LeftLowerLeg = true, RightLowerLeg = true }

local function v3(list: { number }): Vector3 return Vector3.new(list[1], list[2], list[3]) end

function Figures.look(key: string): Schema.Look?
	return (Looks :: any)[key]
end

-- `ground` is the point under the figure's feet; returns the model, its torso and its head.
function Figures.statue(parent: Instance, key: string, ground: Vector3): (Model, BasePart, BasePart)
	local look = assert(Figures.look(key), "No cast look " .. key)
	local model = Instance.new("Model")
	model.Name = key
	local face = look.Look
	local base = if face then CFrame.lookAt(ground, Vector3.new(face[1], ground.Y, face[2])) else CFrame.new(ground)
	local root = base * CFrame.new(0, -Schema.Ground, 0)
	local limbs: { [string]: { Size: { number }, At: { number } } } = Schema.R15 :: any
	for bone, spec in limbs do
		if bone == "HumanoidRootPart" then continue end
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = bone, v3(spec.Size), root * CFrame.new(v3(spec.At))
		p.Anchored, p.CanCollide, p.CanTouch = true, SOLID[bone] == true, false
		p.Material = Enum.Material.SmoothPlastic
		if bone == "Head" then p.Shape = Enum.PartType.Ball end
		p.Parent = model
	end
	model.PrimaryPart = model:FindFirstChild("UpperTorso") :: BasePart
	Kit.build(model, look, 1)
	model.WorldPivot = base -- scale about the feet so the figure stays standing on the ground
	model:ScaleTo(Figures.Scale)
	model.Parent = parent
	return model, model:FindFirstChild("UpperTorso") :: BasePart, model:FindFirstChild("Head") :: BasePart
end

-- Dresses a live rig; returns the limbs the look could not find (empty when fully bound).
function Figures.dress(model: Model, key: string): { string }
	local look = Figures.look(key)
	if not look then return { "look:" .. key } end
	local _, missing = Kit.build(model, look, 1)
	return missing
end

return table.freeze(Figures)

--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/BossAppearance
-- Dresses each boss actor in its authored look (batches 11-13) before scaling it, so costume,
-- hull and rewound hurtboxes scale together; creatures also swap the upright humanoid hurtbox for
-- their BossBodies shape. Replaces the old neon gear blocks. A production skin (BossSkin) still
-- overrides the look when a valid template is imported; the look is the diagnosed fallback.
local PhysicsService = game:GetService("PhysicsService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Characters = require(script.Parent.CharacterService)
local Kit = require(script.Parent.CostumeKit)
local Bodies = require(Shared.BossBodies)
local Schema = require(Shared.CostumeSchema)

local Appearance = {}
Appearance.HullGroup, Appearance.WorldGroup = "AsuraCreatureHull", "WorldGeometry"

local LOOKS: { [string]: Schema.Look } = {}
for _, source in { "LooksDuelists", "LooksBeasts", "LooksSovereigns" } do
	for key, look in require(Shared:WaitForChild(source) :: ModuleScript) :: any do LOOKS[key] = look end
end
-- Archetype -> look key; the Twins' partner is dressed as "IronBull".
Appearance.Keys = table.freeze({ Duelist = "GrandmasterShen", Duo = "GeneralZhao", IronBull = "IronBull", Beast = "VenerableBaize",
	Colossus = "SlumberingTitan", Sorcerer = "SovereignWu", Dragon = "AzureWyrm" })

function Appearance.look(archetype: string?): Schema.Look?
	local key = if archetype then Appearance.Keys[archetype] else nil
	return if key then LOOKS[key] else nil
end

local function registerGroups()
	pcall(function()
		for _, name in { Appearance.HullGroup, Appearance.WorldGroup } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then PhysicsService:RegisterCollisionGroup(name) end
		end
		for _, group in PhysicsService:GetRegisteredCollisionGroups() do
			PhysicsService:CollisionGroupSetCollidable(Appearance.HullGroup, group.name, group.name == Appearance.WorldGroup)
		end
	end)
end

-- One invisible box that only meets world geometry: stops a long creature body at pillars.
local function hull(model: Model, root: BasePart, spec: { number })
	registerGroups()
	local p = Instance.new("Part")
	p.Name, p.Size, p.Transparency = "AsuraHull", Vector3.new(spec[1], spec[2], spec[3]), 1
	p.Anchored, p.Massless, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, true, true, false, false, false
	p.CollisionGroup = Appearance.HullGroup
	local c0 = CFrame.new(spec[4], spec[5], spec[6])
	p.CFrame = root.CFrame * c0
	local weld = Instance.new("Weld")
	weld.Name, weld.Part0, weld.Part1, weld.C0, weld.Parent = "AsuraBind", root, p, c0, p
	p.Parent = model
end

function Appearance.apply(model: Model, archetype: string?, scale: number?)
	local look = Appearance.look(archetype)
	local root = model:FindFirstChild("HumanoidRootPart")
	model:SetAttribute("AsuraArchetype", archetype)
	if look then
		model:SetAttribute("AsuraLookKey", look.Key)
		Kit.build(model, look, 1)
		local spec = if archetype then (Bodies.Hulls :: any)[archetype] else nil
		if spec and root and root:IsA("BasePart") then hull(model, root, spec) end
	end
	local shape = Bodies.shape(archetype)
	local id = Characters.GetEntityByModel(model)
	if id and ((scale and scale ~= 1) or shape) then Characters.ScaleEnemy(id, scale or 1, shape) end
	if archetype == "Colossus" then model:SetAttribute("AsuraVisceralTarget", "Ankles") end
end

function Appearance.phase(model: Model, animationSet: string?, index: number?)
	model:SetAttribute("AsuraAnimationSet", animationSet or "Boss")
	Kit.phase(model, index or 1)
end

return Appearance

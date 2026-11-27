--!strict
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local ArmorRules = require(Shared.Shared.ArmorRules)
local Weapons = require(Shared.Simulation.WeaponSchema)
local Characters = require(script.Parent.CharacterService)
local Dressing = require(script.Parent.PresentationDressing)
local Skin = require(script.Parent.BossSkin)
local ArenaLighting = require(script.Parent.ArenaLighting)
local WeaponModels = require(script.Parent.WeaponModels)
local Service = {}
local disconnect: (() -> ())? = nil
local inspectionModels: Folder? = nil
local watchers: {[Model]: {RBXScriptConnection}} = {}

local function buildInspectionModels()
	local library = Instance.new("Folder")
	library.Name = "ItemInspectionModels"
	local weapons = Instance.new("Folder")
	weapons.Name, weapons.Parent = "Weapon", library
	for id in Weapons.Weapons do
		local model = WeaponModels.inspect(id)
		if model then model.Parent = weapons end
	end
	local armor = Instance.new("Folder")
	armor.Name, armor.Parent = "Armor", library
	local assets = ServerStorage:FindFirstChild("AsuraAssets")
	for _, id in ArmorRules.Order do
		local source = assets and assets:FindFirstChild("AsuraArmor_" .. id)
		if not (source and source:IsA("Model")) then continue end
		local copy = Instance.new("Model")
		copy.Name = id
		for _, piece in source:GetChildren() do
			if not piece:IsA("MeshPart") then continue end
			local mesh = piece:Clone()
			for _, child in mesh:GetChildren() do
				if not child:IsA("SurfaceAppearance") then child:Destroy() end
			end
			mesh.Anchored, mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = true, false, false, false
			mesh.Parent = copy
		end
		if #copy:GetChildren() > 0 then copy.Parent = armor else copy:Destroy() end
	end
	if inspectionModels then inspectionModels:Destroy() end
	inspectionModels = library
	library.Parent = Shared
end

function Service.Start()
	buildInspectionModels()
	ArenaLighting.Build()
	for _, name in {"Sanctuary","Map_DesecratedMonastery","Map_BambooPass","Map_AshColosseum","Map_SanctuaryDepths","Map_CelestialPagoda","Map_SkyCitadel"} do
		local root = Workspace:FindFirstChild(name)
		if root then Dressing.Build(root) end
	end
	local function attach(id: number)
		task.defer(function()
			local e = Characters.GetEntity(id)
			if e and e.Boss then
				local ok, err=pcall(Skin.attach,e.Model)
				if not ok then warn("[Asura AV] Boss skin skipped: "..tostring(err)) end
				if not watchers[e.Model] then
					watchers[e.Model]={e.Model:GetAttributeChangedSignal("AsuraAnimationSet"):Connect(function() attach(id) end),
						e.Model.Destroying:Connect(function()
							local list: {RBXScriptConnection} = watchers[e.Model] or {}
							for _, connection in list do connection:Disconnect() end
							watchers[e.Model]=nil
						end)}
				end
			end
		end)
	end
	disconnect=Characters.OnEntityAdded(function(id: number) attach(id) end)
	for id in Characters.Entities() do attach(id) end
end
function Service.Destroy()
	if disconnect then disconnect();disconnect=nil end
	if inspectionModels then inspectionModels:Destroy(); inspectionModels = nil end
	for _, list in watchers do for _, connection in list do connection:Disconnect() end end
	table.clear(watchers)
	local folder=Workspace:FindFirstChild("AsuraArenaLighting")
	if folder then folder:Destroy() end
end
return Service

--!strict
local Workspace = game:GetService("Workspace")
local Characters = require(script.Parent.CharacterService)
local Dressing = require(script.Parent.PresentationDressing)
local Skin = require(script.Parent.BossSkin)
local ArenaLighting = require(script.Parent.ArenaLighting)
local Service = {}
local disconnect: (() -> ())? = nil
local watchers: {[Model]: {RBXScriptConnection}} = {}
function Service.Start()
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
	for _, list in watchers do for _, connection in list do connection:Disconnect() end end
	table.clear(watchers)
	local folder=Workspace:FindFirstChild("AsuraArenaLighting")
	if folder then folder:Destroy() end
end
return Service

--!strict
local Workspace = game:GetService("Workspace")
local Characters = require(script.Parent.CharacterService)
local Dressing = require(script.Parent.PresentationDressing)
local Skin = require(script.Parent.BossSkin)
local ArenaLighting = require(script.Parent.ArenaLighting)
local Service = {}
local disconnect: (() -> ())? = nil
function Service.Start()
	ArenaLighting.Build()
	for _, name in {"Sanctuary","Map_DesecratedMonastery"} do
		local root = Workspace:FindFirstChild(name)
		if root then Dressing.Build(root) end
	end
	local function attach(id: number)
		task.defer(function()
			local e = Characters.GetEntity(id)
			if e and e.Boss then
				local ok, err=pcall(Skin.attach,e.Model)
				if not ok then warn("[Asura AV] Boss skin skipped: "..tostring(err)) end
			end
		end)
	end
	disconnect=Characters.OnEntityAdded(function(id: number) attach(id) end)
	for id in Characters.Entities() do attach(id) end
end
function Service.Destroy()
	if disconnect then disconnect();disconnect=nil end
	local folder=Workspace:FindFirstChild("AsuraArenaLighting")
	if folder then folder:Destroy() end
end
return Service

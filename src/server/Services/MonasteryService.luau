--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryService
-- The Desecrated Monastery: a ruined grimdark wuxia monastery in a misted mountain valley, built
-- procedurally under Workspace.Map_DesecratedMonastery from the WorldDefinitions layout:
--   gate landing (Altar_MonasteryGate) and gatehouse -> courtyard (bell tower, cauldron, dead tree)
--   -> prayer halls -> bridge over the misted ravine -> cloister (Altar_DesecratedCloister) and
--   graveyard with its toppled pagoda -> south road to the Bamboo Pass.
-- Start() must run before WorldService.Start(): this MapFolder suppresses the region's greybox and
-- the shrines' AltarAnchor_<id> parts receive the rest prompts. If the ground layer fails the map
-- is removed so the greybox returns; the decorative layers fail soft.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("AsurasPath").Shared.WorldDefinitions)
local Services = script.Parent
local Grounds = require(Services:WaitForChild("MonasteryGrounds") :: ModuleScript)
local Ruins = require(Services:WaitForChild("MonasteryRuins") :: ModuleScript)
local Halls = require(Services:WaitForChild("MonasteryHalls") :: ModuleScript)
local Landmarks = require(Services:WaitForChild("MonasteryLandmarks") :: ModuleScript)
local Atmosphere = require(Services:WaitForChild("MonasteryAtmosphere") :: ModuleScript)
local Dressing = require(Services:WaitForChild("MonasteryDressing") :: ModuleScript)
local Survey = require(Services:WaitForChild("MonasterySurvey") :: ModuleScript)

local MonasteryService = {}

local REGION_ID: World.RegionId = "DesecratedMonastery"
local REGION = World.Regions[REGION_ID]
local SEED = 7341
local SURVEY_DELAY = 2
local root: Folder? = nil
local running = false

local function layer(label: string, fn: () -> ()): boolean
	local ok, problem = pcall(fn)
	if not ok then
		warn(string.format("[Asura's Path] Monastery layer '%s' failed: %s", label, tostring(problem)))
	end
	return ok
end

function MonasteryService.Start()
	assert(not running, "MonasteryService already started")
	assert(REGION ~= nil and REGION.Altars.MonasteryGate ~= nil, "Desecrated Monastery layout missing")
	running = true
	local existing = Workspace:FindFirstChild(REGION.MapFolder)
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = REGION.MapFolder
	map:SetAttribute("AsuraRegion", REGION_ID)
	local rng = Random.new(SEED)
	local started = os.clock()
	local grounded = layer("Grounds", function()
		Grounds.Clear()
		Grounds.Build(map, rng)
	end)
	if not grounded then
		map:Destroy()
		pcall(Grounds.Clear)
		return
	end
	root = map
	layer("Ruins", function()
		Ruins.Build(map, rng)
	end)
	layer("Halls", function()
		Halls.Build(map, rng)
	end)
	layer("Landmarks", function()
		Landmarks.Build(map, rng)
	end)
	layer("Atmosphere", function()
		Atmosphere.Build(map, rng)
	end)
	local placed = Dressing.Build(map)
	map.Parent = Workspace

	local parts, elapsed = 0, (os.clock() - started) * 1000
	for _, d in map:GetDescendants() do
		parts += if d:IsA("BasePart") then 1 else 0
	end
	-- New terrain voxels only become raycastable after the next physics steps.
	task.delay(SURVEY_DELAY, function()
		if not running or root ~= map then
			return
		end
		local problems = Survey.Run(REGION_ID)
		for _, problem in problems do
			warn("[Asura's Path] Monastery walkability: " .. problem)
		end
		print(string.format("[Asura's Path] Desecrated Monastery raised: %d parts, %d set pieces, %d walkability issues (%.0f ms).",
			parts, placed, #problems, elapsed))
	end)
end

function MonasteryService.Destroy()
	running = false
	local folderRoot = root
	if folderRoot then
		folderRoot:Destroy()
		root = nil
		pcall(Grounds.Clear)
	end
end

return MonasteryService

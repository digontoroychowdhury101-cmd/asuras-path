--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/CampaignWorld
-- Raises the authored campaign regions (batches 17-21) as Workspace.Map_<Region> from their shared
-- layouts: Bamboo Pass, Ash Colosseum, the Sunken Crypt, the Celestial Pagoda and the Sky Citadel.
-- Every layout box becomes a part (RegionDecor); natural boxes are drawn as Terrain over an invisible
-- collider (CampaignTerrain). Every lantern spot is lit, then the region's own
-- dressing module adds non-colliding silhouettes, landmarks and storytelling. Boss arena floors,
-- seals, frost pillars and portals stay with BossArenas. Start() must run before WorldService.Start():
-- each MapFolder suppresses its region's greybox floor. A failed dressing layer fails soft; a failed
-- structure layer removes that map so the greybox returns.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath").Shared
local World = require(Shared.WorldDefinitions)
local Campaign = require(Shared.CampaignZones)
local Services = script.Parent
local Decor = require(Services:WaitForChild("RegionDecor") :: ModuleScript)
local Bounds = require(Services:WaitForChild("CampaignBounds") :: ModuleScript)
local Ground = require(Services:WaitForChild("CampaignTerrain") :: ModuleScript)
local Dressings: { [string]: any } = {
	BambooPass = require(Services:WaitForChild("BambooDressing") :: ModuleScript),
	AshColosseum = require(Services:WaitForChild("ColosseumDressing") :: ModuleScript),
	SanctuaryDepths = require(Services:WaitForChild("CryptDressing") :: ModuleScript),
	CelestialPagoda = require(Services:WaitForChild("PagodaDressing") :: ModuleScript),
	SkyCitadel = require(Services:WaitForChild("CitadelDressing") :: ModuleScript),
}

local CampaignWorld = {}
local maps: { Folder } = {}
local terrainBoxes: { any } = {}
local running = false

local function build(layout: any): Folder?
	local region = World.Regions[layout.Region]
	local existing = Workspace:FindFirstChild(region.MapFolder)
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = region.MapFolder
	map:SetAttribute("AsuraRegion", layout.Region)
	local ok, problem = pcall(function()
		local structure = Instance.new("Folder")
		structure.Name = "Structure"
		structure.Parent = map
		for _, box in layout.Solids do
			if Ground.convert(Decor.solid(structure, box), box) then
				table.insert(terrainBoxes, box)
			end
		end
		local lights = Instance.new("Folder")
		lights.Name = "Lanterns"
		lights.Parent = map
		for _, l in layout.Lights do
			Decor.lantern(lights, l[1], l[2], l[3])
		end
	end)
	if not ok then
		warn(string.format("[Asura's Path] %s structure failed: %s", layout.Region, tostring(problem)))
		map:Destroy()
		return nil
	end
	for _, wall in Ground.backdrop(layout.Region, region.Bounds) do
		table.insert(terrainBoxes, wall)
	end
	local dressing = Dressings[layout.Region]
	if dressing then
		local dressed, err = pcall(dressing.Build, map, layout, Random.new(#layout.Solids * 7919))
		if not dressed then
			warn(string.format("[Asura's Path] %s dressing skipped: %s", layout.Region, tostring(err)))
		end
	end
	local parts = 0
	for _, d in map:GetDescendants() do
		parts += if d:IsA("BasePart") then 1 else 0
	end
	map:SetAttribute("AsuraParts", parts)
	map.Parent = Workspace
	return map
end

function CampaignWorld.Start()
	assert(not running, "CampaignWorld already started")
	running = true
	local started = os.clock()
	Ground.applyOverrides()
	for _, layout in Campaign.Layouts do
		local map = build(layout)
		if map then
			table.insert(maps, map)
		end
	end
	Bounds.Start(Campaign.Layouts)
	local total = 0
	for _, map in maps do
		total += map:GetAttribute("AsuraParts") or 0
	end
	print(string.format("[Asura's Path] Campaign regions raised: %d maps, %d parts (%.0f ms).", #maps, total, (os.clock() - started) * 1000))
end

function CampaignWorld.Destroy()
	running = false
	Bounds.Stop()
	for _, map in maps do
		map:Destroy()
	end
	table.clear(maps)
	for _, box in terrainBoxes do
		Ground.clear(box)
	end
	table.clear(terrainBoxes)
end

return CampaignWorld

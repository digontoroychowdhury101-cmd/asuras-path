--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/CampaignBounds
-- Fall returns for the authored campaign regions (batches 17-21, finding #27), the counterpart of
-- MonasteryBounds' ravine mist: a body that drops below a layout's catch volume (the crypt's flooded
-- pit, the Citadel's cloud chasm and summit edge) is carried back to that volume's ledge after a short
-- hold. Boundaries themselves are the layouts' Veil boxes (built with the map). A participant in a
-- boss fight is left to the arena's own return, and duels, KO and respawns are never touched.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local Layout = require(Shared.RegionLayout)
local Characters = require(script.Parent:WaitForChild("CharacterService") :: ModuleScript)

local Bounds = {}
Bounds.HOLD = 0.6

local layouts: { any } = {}
local below: { [number]: number } = {}
local running = false

-- Pure: the catch volume holding a root position across all layouts, if any.
function Bounds.returnFor(list: { any }, position: Vector3): any
	for _, layout in list do
		local r = Layout.returnFor(layout, position.X, position.Y, position.Z)
		if r then
			return r
		end
	end
	return nil
end

local function poll(dt: number)
	for _, player in Players:GetPlayers() do
		local id = player.UserId
		local e = Characters.GetEntity(id)
		local catch = if e and e.Fighter.State ~= "KO" and not e.Respawning and not Characters.IsInDuel(id)
			and not Characters.IsSettling(id) and player:GetAttribute("AsuraEncounter") == nil then Bounds.returnFor(layouts, e.Root.Position) else nil
		if catch then
			below[id] = (below[id] or 0) + dt
			if below[id] >= Bounds.HOLD then
				below[id] = nil
				local to = catch.To
				Characters.Teleport(id, CFrame.new(to.X, to.Y + 3, to.Z) * CFrame.Angles(0, math.rad(to.Yaw), 0))
				Characters.Cue("MistReturn", id, { place = catch.Name })
			end
		else
			below[id] = nil
		end
	end
end

function Bounds.Start(list: { any })
	layouts = list
	if running then return end
	running = true
	task.spawn(function()
		while running do
			poll(task.wait(0.2))
		end
	end)
end

function Bounds.Stop()
	running = false
	table.clear(below)
end

return Bounds

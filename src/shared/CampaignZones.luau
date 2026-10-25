--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/CampaignZones
-- One walked graph for the authored campaign regions (batches 17-21): every layout's zones and doors,
-- the Monastery's south road as the shared join ("DM:Road"), and each regional spawn's fighting zone.
-- Zones may carry a height band, so the Pagoda's gorge, galleries and loft are separate places even
-- where they overlap on the map; one-way doors are drops that wayfinding never sends anyone up.
-- Pure data and maths: read by RouteGuide (objective marker) and AIService (leash).
local hasScript = pcall(function() return script.Parent end)
local function load(name: string): any
	if hasScript then return (require :: any)((script.Parent :: any)[name]) end
	return (require :: any)("./" .. name)
end
local Layouts = {
	load("BambooPassLayout"), load("AshColosseumLayout"), load("SunkenCryptLayout"),
	load("CelestialPagodaLayout"), load("SkyCitadelLayout"),
}

export type Zone = { Id: string, Name: string, X0: number, X1: number, Z0: number, Z1: number, Y0: number?, Y1: number?, Region: string? }
export type Door = { A: string, B: string, X: number, Y: number, Z: number, Name: string, OneWay: boolean?, Optional: boolean? }

local Campaign = {}
local list: { Zone } = { { Id = "DM:Road", Name = "the south road", X0 = -14, X1 = 14, Z0 = -988, Z1 = -1120, Region = "DesecratedMonastery" } }
local doors: { Door } = {}
local spawns: { [string]: string } = {}
Campaign.Layouts = Layouts
for _, layout in Layouts do
	for _, z in layout.Zones do
		local copy = table.clone(z) :: any
		copy.Region = layout.Region
		table.insert(list, copy)
	end
	for _, d in layout.Doors do table.insert(doors, d) end
	for spawnId, zoneId in layout.SpawnZones do spawns[spawnId] = zoneId end
end
Campaign.List = table.freeze(list)
Campaign.Doors = table.freeze(doors)
Campaign.Spawns = table.freeze(spawns)
Campaign.Grace = 6

function Campaign.get(id: string): Zone?
	for _, zone in list do
		if zone.Id == id then return zone end
	end
	return nil
end

function Campaign.contains(zone: Zone, x: number, y: number?, z: number, margin: number?): boolean
	local m = margin or 0
	if x < zone.X0 - m or x > zone.X1 + m or z > zone.Z0 + m or z < zone.Z1 - m then return false end
	if y and zone.Y0 and y < zone.Y0 then return false end
	if y and zone.Y1 and y > zone.Y1 then return false end
	return true
end

-- The smallest zone holding a point (height bands decide between stacked levels).
function Campaign.at(x: number, y: number, z: number): Zone?
	local best: Zone? = nil
	local bestArea = math.huge
	for _, zone in list do
		local area = (zone.X1 - zone.X0) * (zone.Z0 - zone.Z1)
		if Campaign.contains(zone, x, y, z) and area < bestArea then
			best, bestArea = zone, area
		end
	end
	return best
end

-- Doorways from zone `from` to zone `to` along the fewest crossings, never up a one-way drop. Optional
-- mobility doors (the Pagoda's rafter-end jumps, the frost stones) are used only when nothing else
-- connects, so main progress never asks for an untaught jump chain (Studio F19).
local function search(from: string, to: string, optional: boolean): { Door }
	local previous: { [string]: { Door: Door, From: string } } = {}
	local seen, queue = { [from] = true }, { from }
	while #queue > 0 do
		local here = table.remove(queue, 1) :: string
		for _, door in doors do
			local usable = optional or not door.Optional
			local other = if not usable then nil elseif door.A == here then door.B elseif door.B == here and not door.OneWay then door.A else nil
			if other and not seen[other] then
				seen[other], previous[other] = true, { Door = door, From = here }
				table.insert(queue, other)
			end
		end
	end
	local result: { Door } = {}
	local cursor = to
	while cursor ~= from do
		local step = previous[cursor]
		if not step then return {} end
		table.insert(result, 1, step.Door)
		cursor = step.From
	end
	return result
end

function Campaign.path(from: string, to: string): { Door }
	if from == to then return {} end
	local plain = search(from, to, false)
	return if #plain > 0 then plain else search(from, to, true)
end

-- Fighting zone for a regional spawn (Monastery spawns keep MonasteryZones).
function Campaign.zoneForSpawn(spawnId: string): Zone?
	local id = spawns[spawnId]
	return if id then Campaign.get(id) else nil
end

-- A layout's named point, e.g. Campaign.mark("SanctuaryDepths", "Arrival").
function Campaign.mark(region: string, key: string): any
	for _, layout in Layouts do
		if layout.Region == region then return layout.Marks[key] end
	end
	return nil
end

return table.freeze(Campaign)

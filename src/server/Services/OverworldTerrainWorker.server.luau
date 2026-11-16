--!strict
-- Script: child of the Actor ServerScriptService/AsurasPath/Services/OverworldTerrainWorker (default.project.json).
-- Computes terrain tiles for OverworldTerrain off the main thread: "Tile" messages (key, x0, z0, nx, nz) are answered by
-- storing the packed tile (OverworldTerrainCompute.tile, as a string) in the shared results table under the tile key.
-- "Ping" (index) answers with results["ping" .. index] so the pool knows the worker has bound. Outside an Actor it does nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local actor = (script :: any):GetActor()
if not actor then
	return
end

local Overworld = require(ReplicatedStorage.AsurasPath.Shared.Overworld) :: any
local Compute = require((script.Parent :: any).Parent.OverworldTerrainCompute) :: any

local RES = 4
local RESULTS = "OverworldTerrainResults" -- same name as OverworldTerrain's RESULTS
local registry: any = game:GetService("SharedTableRegistry") -- a service in Studio, not a global
local results: any = nil
local function shared(): any
	if not results then
		results = registry:GetSharedTable(RESULTS)
	end
	return results
end

actor:BindToMessageParallel("Ping", function(index: number)
	shared()["ping" .. index] = true
end)

actor:BindToMessageParallel("Tile", function(key: string, x0: number, z0: number, nx: number, nz: number)
	local t0 = os.clock()
	local pads = Overworld.padsNear(x0 - RES, z0 - RES, x0 + nx * RES + RES, z0 + nz * RES + RES)
	local buf = Compute.tile(Overworld, x0, z0, nx, nz, Overworld.Frame.WaterY, pads)
	buffer.writeu32(buf, 20, math.floor((os.clock() - t0) * 1e6))
	shared()[key] = buffer.tostring(buf)
end)

-- Build the overworld's terrain data in this worker's own VM now, so the first tile does not pay for it.
task.defer(function()
	task.desynchronize()
	Overworld.terrainData()
end)

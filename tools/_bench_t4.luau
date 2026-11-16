--!nonstrict
-- THROWAWAY (T4): per-phase timing of OverworldTerrain over a fixed sample of tiles, WriteVoxels stubbed to a no-op.
-- python3 tools/lune_compat.py tools/_bench_t4.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local O = require("../src/shared/Overworld")

local services = { Workspace = { Terrain = {} }, ReplicatedStorage = { AsurasPath = { Shared = { Overworld = O } } } }
local game = { GetService = function(_, n) return services[n] end }
local compute
local ok, src = pcall(fs.readFile, "src/server/Services/OverworldTerrainCompute.luau")
if ok then compute = luau.load(src, { debugName = "Compute", environment = { math = math, table = table, string = string, buffer = buffer, type = type, assert = assert, error = error, pairs = pairs, ipairs = ipairs, tostring = tostring, tonumber = tonumber, os = os, select = select, unpack = unpack } })() end
local env = { game = game, require = function(m) return m end, task = { wait = function() end }, os = os, math = math, table = table,
	string = string, Vector3 = roblox.Vector3, Enum = roblox.Enum, buffer = buffer, script = { Parent = { OverworldTerrainCompute = compute } },
	Region3 = { new = function(a, b) return { Min = a, Max = b } end }, CFrame = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }, pairs = pairs, ipairs = ipairs, type = type,
	tostring = tostring, warn = warn, print = print, assert = assert, error = error, setmetatable = setmetatable, select = select, typeof = typeof }
local Terrain = luau.load(fs.readFile("src/server/Services/OverworldTerrain.luau"), { debugName = "OverworldTerrain", environment = env })()
local nWrites, nVox = 0, 0
services.Workspace.Terrain.WriteVoxels = function(_, region, _, mat) nWrites += 1 end
services.Workspace.Terrain.FillBlock = function() end

local gate = O.Altars[O.Gateway].Placement
local plan = Terrain.Plan()
table.sort(plan, function(a, b) return a.Key < b.Key end)
local pick, picked = {}, {}
local function add(t) if not picked[t.Key] then picked[t.Key] = true; table.insert(pick, t) end end
local byGate = table.clone(plan)
table.sort(byGate, function(a, b)
	local function d(t) return ((t.X0 + t.X1) / 2 - gate.X) ^ 2 + ((t.Z0 + t.Z1) / 2 - gate.Z) ^ 2 end
	return d(a) < d(b)
end)
for i = 1, 6 do add(byGate[i]) end
for i = 1, #plan, 16 do add(plan[i]) end
local rank = {}
for i, t in pick do rank[t.Key] = i end
local N = #pick
local label = ...
local stats
pcall(Terrain.Build, nil, function(i, n, tile)
	if i >= N then error("stop") end
end, function(tile) return rank[tile.Key] or 1e9 end, nil)
stats = Terrain.Stats
local ok2 = true
local per = function(k) return stats[k] / math.max(stats.Tiles, 1) end
print(string.format("BENCH tiles %d  compute %.1f ms/tile  [sample %.1f, material %.1f, shell %.1f, fill %.1f]  write(stub) %.2f ms/tile  calls/tile %.0f  boxvox/tile %.0f  solid/tile %.0f",
	stats.Tiles, per("ComputeMs"), per("SampleMs"), per("MaterialMs"), per("ShellMs"), per("FillMs"), per("WriteMs"), per("WriteCalls"), per("BoxVoxels"), per("SolidVoxels")))

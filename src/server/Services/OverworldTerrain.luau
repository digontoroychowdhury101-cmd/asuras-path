--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/OverworldTerrain
-- Writes the canonical overworld ground (Overworld.surfaceAt) as an 8-stud Terrain shell (deeper under steep faces) at resolution 4,
-- one 128-stud tile at a time, plus river and lake water up to Frame.WaterY. A tile is computed off the main thread (a pool of
-- OverworldTerrainWorker Actors; OverworldTerrainCompute packs only the voxels that exist into a buffer) or, with no workers
-- mapped, inline; the main thread only decodes the buffer into tight WriteVoxels boxes. Work is time-sliced: the writer yields one
-- Heartbeat (task.wait) whenever it has used BUDGET seconds of the current frame, mid-tile if need be, so the server keeps its frame rate.
-- Every WriteVoxels / FillBlock is a box of about CALL_TARGET seconds (cost = per call + per voxel, fitted online), reserved
-- against the frame before it runs, and the frame budget halves (floor a quarter) while the last Heartbeat was slower than 1/45 s (it grows to 1.5x while Heartbeats are under 1/55 s).
-- Everything written is listed in Terrain.Manifest (tile XZ boxes and the Y slabs written); Clear only
-- empties those boxes, and nothing is ever written or cleared outside Overworld.Frame.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Overworld = require(ReplicatedStorage.AsurasPath.Shared.Overworld) :: any
local Compute = require(script.Parent:WaitForChild("OverworldTerrainCompute") :: ModuleScript) :: any

local OverworldTerrain = {}

local RES = 4
local TILE = 128 -- studs; 32 columns
local SHELL = 8 -- studs of solid below the lowest of a column and its 8 neighbours (C3 ruling 1a: 202 MB at 12, about 160 MB at 8)
local SLAB = 64 -- studs of height per Manifest slab (Clear empties whole slabs; the writer itself writes only the voxels that exist)
local BUDGET = 0.006 -- seconds of writer work per Heartbeat (C3 ruling 1b: server heartbeat stays at or above 45 Hz)
local CALL_TARGET = 0.0025 -- seconds one WriteVoxels / FillBlock call may be expected to take (24a: a whole slab call stalled frames)
local VOXEL_COST0 = 8e-6 -- seconds per voxel assumed until calls are measured; the fit replaces it
local CALL_COST0 = 60e-6 -- seconds per engine call assumed until measured (a guess: the Studio operator reads the fit, Stats.WriteMs / WriteCalls)
local MIN_V = 16 -- voxels in the smallest call (one column)
local SLOW_DT = 1 / 45 -- a Heartbeat longer than this makes the slicer back off
local MIN_SCALE = 0.25 -- the slicer never works less than this share of BUDGET per frame
local MAX_SCALE = 1.5 -- ... nor more than this share, and only while Heartbeats are faster than GOOD_DT (idle frame time is free)
local GOOD_DT = 1 / 55 -- a Heartbeat this short or shorter lets the slice grow past BUDGET
local WORKERS = 4 -- Actors computing tiles in parallel
local WINDOW = 8 -- tiles requested ahead of the one being written
local WORKER_WAIT = 5 -- seconds before a requested tile is given up on and computed inline (and the pool is dropped)
local RESULTS = "OverworldTerrainResults" -- SharedTableRegistry name of the workers' result table (tile key -> packed string)
local N = TILE // RES

-- { [tileKey] = { X0, Z0, X1, Z1, Regions = { [id] = true }, Slabs = { y0, ... } } }
OverworldTerrain.Manifest = {} :: { [string]: any }

-- Counters for the Studio operator (read OverworldTerrain.Stats): milliseconds are main-thread work time only, never the time
-- spent yielded (YieldMs). ComputeMs = tiles computed inline on the main thread; WorkerMs = compute time on the Actors (off the
-- main thread, summed over workers); DecodeMs = buffer -> WriteVoxels arrays; WriteMs = inside WriteVoxels / FillBlock.
-- Per tile = value / Tiles. BoxVoxels counts what was handed to the engine, SolidVoxels what exists (box ratio = BoxVoxels / SolidVoxels).
local function newStats(): { [string]: number }
	return { Tiles = 0, Parallel = 0, Inline = 0, WriteCalls = 0, BoxVoxels = 0, SolidVoxels = 0,
		ComputeMs = 0, WorkerMs = 0, DecodeMs = 0, WriteMs = 0, YieldMs = 0 }
end
OverworldTerrain.Stats = newStats()

local function terrain(): Terrain
	return Workspace.Terrain
end

-- Tiles (aligned to the frame's minimum corner, clipped to the frame) that overlap the regions' boxes.
local function tilesFor(regionIds: { string }): { any }
	local F = Overworld.Frame
	local out, seen = {}, {}
	for _, id in regionIds do
		local b = Overworld.Regions[id].Bounds
		local x0, x1 = b.Center.X - b.Size.X / 2, b.Center.X + b.Size.X / 2
		local z0, z1 = b.Center.Z - b.Size.Z / 2, b.Center.Z + b.Size.Z / 2
		for i = math.floor((math.max(x0, F.MinX) - F.MinX) / TILE), math.ceil((math.min(x1, F.MaxX) - F.MinX) / TILE) - 1 do
			for j = math.floor((math.max(z0, F.MinZ) - F.MinZ) / TILE), math.ceil((math.min(z1, F.MaxZ) - F.MinZ) / TILE) - 1 do
				local key = i .. "," .. j
				local tile = seen[key]
				if not tile then
					tile = {
						Key = key, Regions = {},
						X0 = F.MinX + i * TILE, Z0 = F.MinZ + j * TILE,
						X1 = math.min(F.MinX + (i + 1) * TILE, F.MaxX), Z1 = math.min(F.MinZ + (j + 1) * TILE, F.MaxZ),
					}
					seen[key] = tile
					table.insert(out, tile)
				end
				tile.Regions[id] = true
			end
		end
	end
	return out
end

local materials: { Enum.Material } = {}
local function materialOf(id: number): Enum.Material -- Compute's material id -> Enum.Material
	local m = materials[id + 1]
	if not m then
		m = (Enum.Material :: any)[Compute.Materials[id + 1]]
		materials[id + 1] = m
	end
	return m
end

export type Slicer = {
	Yields: number, Backoffs: number, Skipped: number, Scale: number,
	Begin: () -> (), Check: () -> boolean, Reserve: (number) -> boolean, Limit: () -> number, Wait: () -> (),
}

-- Frame time slice. Check() yields one frame (yield, task.wait) once the slice limit (budget * Scale) has passed since the
-- slice began, and starts the next slice when it resumes; returns true if it yielded. Reserve(est) is Check for an
-- uninterruptible call expected to take est seconds: it yields first if the call would not fit in the slice. Wait() yields
-- one frame unconditionally (waiting for a worker).
-- Begin() restarts the slice (call after any other wait). With frameDt (last Heartbeat dt) the slice adapts on every
-- resume: a frame longer than SLOW_DT halves Scale (floor MIN_SCALE; at the floor one extra frame is skipped), a good frame
-- grows it back by a quarter up to 1, and up to MAX_SCALE while frames take GOOD_DT or less.
function OverworldTerrain.NewSlicer(budget: number, clock: () -> number, yield: () -> any, frameDt: (() -> number)?): Slicer
	local began = clock()
	local self: Slicer = {
		Yields = 0, Backoffs = 0, Skipped = 0, Scale = 1,
		Begin = function() end, Check = function() return false end, Reserve = function(_: number) return false end, Limit = function() return budget end,
		Wait = function() end,
	}
	local function resume()
		self.Yields += 1
		yield()
		if frameDt then
			if frameDt() > SLOW_DT then
				self.Backoffs += 1
				if self.Scale <= MIN_SCALE then
					self.Skipped += 1
					yield()
				end
				self.Scale = math.max(self.Scale / 2, MIN_SCALE)
			else
				self.Scale = math.min(self.Scale * 1.25, if frameDt() <= GOOD_DT then MAX_SCALE else 1)
			end
		end
		began = clock()
	end
	self.Wait = resume
	self.Limit = function()
		return budget * self.Scale
	end
	self.Begin = function()
		began = clock()
	end
	self.Check = function(): boolean
		if clock() - began < budget * self.Scale then
			return false
		end
		resume()
		return true
	end
	self.Reserve = function(est: number): boolean
		local elapsed = clock() - began
		-- shortcut: a call on a fresh slice (elapsed under 0.1 ms) always runs, even if est alone exceeds the limit
		if elapsed < 1e-4 or elapsed + est <= budget * self.Scale then
			return false
		end
		resume()
		return true
	end
	return self
end

local RunService = game:GetService("RunService") :: any
local lastDt = 0
if RunService then
	RunService.Heartbeat:Connect(function(dt: number)
		lastDt = dt
	end)
end

local clock: () -> number = os.clock
local mark, phase = 0, "DecodeMs"
-- Adds the time since the last lap to a main-thread phase counter.
local function lap(key: string)
	local t = clock()
	OverworldTerrain.Stats[key] += (t - mark) * 1000
	mark, phase = t, key
end
local function counted(y: () -> any): () -> any
	return function()
		lap(phase)
		local t = clock()
		y()
		OverworldTerrain.Stats.YieldMs += (clock() - t) * 1000
		mark = clock()
	end
end
local slicer = OverworldTerrain.NewSlicer(BUDGET, clock, counted(task.wait), function() return lastDt end)
OverworldTerrain.Slicer = slicer

-- Engine call cost model: seconds = callCost + perVoxel * voxels, fitted online (least squares, each sample's weight decays
-- 5% per call). A call 2x slower than the model is believed at once and restarts the fit (rises at once, so a spike never repeats).
local callCost, perVoxel = CALL_COST0, VOXEL_COST0
local fitW, fitV, fitV2, fitT, fitVT = 0, 0, 0, 0, 0
local function learn(v: number, t: number)
	if t > 2 * (callCost + perVoxel * v) then
		perVoxel = math.max(t - callCost, t / 2) / v
		fitW, fitV, fitV2, fitT, fitVT = 0, 0, 0, 0, 0
		return
	end
	fitW, fitV, fitV2, fitT, fitVT = fitW * 0.95 + 1, fitV * 0.95 + v, fitV2 * 0.95 + v * v, fitT * 0.95 + t, fitVT * 0.95 + v * t
	local det = fitW * fitV2 - fitV * fitV
	if det > 1e-3 * fitW * fitV2 then -- the call sizes vary enough to separate the two costs
		perVoxel = math.max((fitW * fitVT - fitV * fitT) / det, 1e-7)
		callCost = math.max((fitT - perVoxel * fitV) / fitW, 0)
	else
		perVoxel = fitT / fitV -- one size so far: the mean rate, which overstates the voxel cost and never understates a call
	end
end

-- Workers: Actors (SendMessage) whose results come back as strings in a table keyed by tile key (a SharedTable in the game).
-- Empty pool = compute inline on the main thread.
local pool: { any } = {}
local results: any = nil
local inflight: { [string]: number } = {}
local nextActor = 1
local poolTried = false
local settled = false -- the boot settle wait (Settle) has run
local pending: { any }? = nil -- actors cloned by startPool, not yet pinged

-- Test hook: use these fake actors / results table instead of the mapped OverworldTerrainWorker Actors.
function OverworldTerrain.UsePool(actors: { any }, shared: any)
	pool, results, poolTried, inflight, nextActor, pending = actors, shared, actors ~= nil, {}, 1, nil
end

-- Test hook: swap the clock, the yield and the frame-time source (fakes), and forget the measured call cost.
function OverworldTerrain.Use(c: () -> number, yield: () -> any, frameDt: (() -> number)?)
	clock, settled, mark = c, true, c()
	slicer = OverworldTerrain.NewSlicer(BUDGET, c, counted(yield), frameDt)
	OverworldTerrain.Slicer = slicer
	callCost, perVoxel = CALL_COST0, VOXEL_COST0
	fitW, fitV, fitV2, fitT, fitVT = 0, 0, 0, 0, 0
	OverworldTerrain.Stats = newStats()
end

-- Maps the worker Actor (default.project.json: Services.OverworldTerrainWorker) into WORKERS copies (awaitWorkers keeps those
-- that answer a ping). Not mapped: no pool, tiles are computed inline.
local function startPool()
	poolTried = true
	local template = (script.Parent :: any):FindFirstChild("OverworldTerrainWorker")
	if not template or not template:IsA("Actor") then
		warn("OverworldTerrain: OverworldTerrainWorker Actor not mapped, computing tiles inline")
		return
	end
	local registry: any, shared: any = game:GetService("SharedTableRegistry"), SharedTable -- the registry is a service, not a global
	results = shared.new()
	registry:SetSharedTable(RESULTS, results)
	local actors: { any } = { template }
	for i = 2, WORKERS do
		local a = template:Clone()
		a.Name = "OverworldTerrainWorker" .. i
		a.Parent = template.Parent
		actors[i] = a
	end
	pending = actors
end

-- Keeps the cloned actors that answer a ping within 3 s. None answers: no pool, tiles are computed inline.
local function awaitWorkers(actors: { any })
	local deadline, answered = clock() + 3, {}
	while #answered < #actors and clock() < deadline do
		answered = {}
		for i, a in actors do
			if results["ping" .. i] then
				table.insert(answered, a)
			else
				a:SendMessage("Ping", i) -- a message sent before the worker has bound is dropped, so ask again each frame
			end
		end
		if #answered < #actors then
			slicer.Wait()
		end
	end
	pool = answered
	if #pool == 0 then
		warn("OverworldTerrain: no worker answered, computing tiles inline")
	end
end

-- Waits (at most 3 s) until 3 consecutive Heartbeats take under 1/45 s, so the boot cost (instances, Actor scripts) and the
-- write cost do not stack. dtOf() is the latest Heartbeat dt.
local function settle(dtOf: () -> number)
	local deadline, calm = clock() + 3, 0
	while calm < 3 and clock() < deadline do
		slicer.Wait()
		calm = if dtOf() < 1 / 45 then calm + 1 else 0
	end
end
OverworldTerrain.Settle = settle

-- Asks the pool for the tile (and the next WINDOW - 1 after it); returns its packed buffer, or nil if no worker delivered.
local function fetch(tiles: { any }, at: number): buffer?
	for k = at, math.min(at + WINDOW - 1, #tiles) do
		local tile = tiles[k]
		if not inflight[tile.Key] and not results[tile.Key] then
			inflight[tile.Key] = clock()
			pool[nextActor]:SendMessage("Tile", tile.Key, tile.X0, tile.Z0, (tile.X1 - tile.X0) // RES, (tile.Z1 - tile.Z0) // RES)
			nextActor = nextActor % #pool + 1
		end
	end
	local key = tiles[at].Key
	local sent = inflight[key] or clock()
	while true do
		local s = results[key]
		if s then
			results[key], inflight[key] = nil, nil
			return buffer.fromstring(s)
		end
		if clock() - sent > WORKER_WAIT then
			warn("OverworldTerrain: worker gave no tile in " .. WORKER_WAIT .. " s, computing inline from now on")
			pool, inflight[key] = {}, nil
			return nil
		end
		slicer.Wait()
	end
end

-- Voxels the next engine call may cover: about CALL_TARGET seconds at the fitted cost, never more than half a slice.
local function callVoxels(): number
	return math.max(math.floor((math.min(CALL_TARGET, slicer.Limit() / 2) - callCost) / perVoxel), MIN_V)
end

-- Runs one engine call of `voxels` voxels: reserves its estimated cost in the slice, then measures it.
local function timed(voxels: number, call: () -> ())
	slicer.Reserve(callCost + perVoxel * voxels)
	lap("DecodeMs")
	local t0 = clock()
	call()
	local t1 = clock()
	local stats = OverworldTerrain.Stats
	stats.WriteCalls += 1
	stats.BoxVoxels += voxels
	stats.WriteMs += (t1 - t0) * 1000
	mark = t1
	learn(voxels, t1 - t0)
end

local HEADER = Compute.Header
local LO, CNT, OFF = table.create(N * N, 0), table.create(N * N, 0), table.create(N * N, 0)

-- Writes columns j0 .. j0 + zc - 1 of row i for voxel heights lo .. hi as one WriteVoxels box (X one column, Y and Z as long as needed).
local function emit(tile: any, buf: buffer, nz: number, i: number, j0: number, zc: number, lo: number, hi: number)
	local ny = hi - lo + 1
	local air = Enum.Material.Air
	local mcol, ocol = table.create(ny), table.create(ny)
	for k = 1, ny do
		mcol[k], ocol[k] = table.create(zc, air), table.create(zc, 0)
	end
	for jj = 1, zc do
		local c = i * nz + j0 + jj - 1
		local at, first = OFF[c], LO[c] - lo + 1
		for n = 0, CNT[c] - 1 do
			local id = buffer.readu8(buf, at + n * 2)
			if id ~= 0 then
				mcol[first + n][jj], ocol[first + n][jj] = materialOf(id), buffer.readu8(buf, at + n * 2 + 1) / 255
			end
		end
	end
	local x0, z0 = tile.X0 + i * RES, tile.Z0 + j0 * RES
	timed(ny * zc, function()
		terrain():WriteVoxels(Region3.new(Vector3.new(x0, lo * RES, z0), Vector3.new(x0 + RES, (hi + 1) * RES, z0 + zc * RES)), RES, { mcol }, { ocol })
	end)
	slicer.Check()
end

-- Decodes a packed tile (OverworldTerrainCompute) and writes it; returns the number of solid or water voxels. Each row of
-- columns is cut into runs that become one box each: a column joins the run while the air its box would add costs less than
-- the engine call it saves (callCost / perVoxel voxels), up to the voxels one call may cover.
local function writeBuffer(tile: any, buf: buffer): number
	local nx, nz = buffer.readu16(buf, 0), buffer.readu16(buf, 2)
	local kMin, kMax, solid = buffer.readi32(buf, 8), buffer.readi32(buf, 12), buffer.readu32(buf, 16)
	tile.Floor, tile.Slabs = buffer.readf32(buf, 4), {}
	if solid == 0 then
		return 0
	end
	local at = HEADER + nx * nz * 4
	for c = 0, nx * nz - 1 do
		LO[c], CNT[c], OFF[c] = buffer.readi16(buf, HEADER + c * 4), buffer.readu16(buf, HEADER + c * 4 + 2), at
		at += CNT[c] * 2
	end
	for y0 = math.floor(kMin * RES / SLAB) * SLAB, kMax * RES + RES - 1, SLAB do
		table.insert(tile.Slabs, y0)
	end
	for i = 0, nx - 1 do
		local j0, runLo, runHi, zc, cap = 0, 0, 0, 0, 0
		for j = 0, nz do -- j == nz only flushes the last run
			local c = i * nz + j
			local count = if j < nz then CNT[c] else 0
			if count > 0 then
				local lo = LO[c]
				local hi = lo + count - 1
				if zc > 0 then
					local nlo, nhi = math.min(runLo, lo), math.max(runHi, hi)
					local merged = (nhi - nlo + 1) * (zc + 1)
					if merged <= cap and (merged - (runHi - runLo + 1) * zc - count) * perVoxel <= callCost then
						runLo, runHi, zc = nlo, nhi, zc + 1
						continue
					end
					emit(tile, buf, nz, i, j0, zc, runLo, runHi)
				end
				j0, runLo, runHi, zc, cap = j, lo, hi, 1, callVoxels()
			elseif zc > 0 then
				emit(tile, buf, nz, i, j0, zc, runLo, runHi)
				zc = 0
			end
		end
	end
	return solid
end

-- Writes one tile (tiles[at]); returns the number of solid or water voxels written.
local function writeTile(tiles: { any }, at: number): number
	local tile, F = tiles[at], Overworld.Frame
	local nx, nz = (tile.X1 - tile.X0) // RES, (tile.Z1 - tile.Z0) // RES
	local stats = OverworldTerrain.Stats
	local buf: buffer? = nil
	if #pool > 0 then
		mark, phase = clock(), "DecodeMs" -- waiting for a worker is YieldMs, not work
		local ok, got = pcall(fetch, tiles, at)
		if ok then
			buf = got
		else
			warn("OverworldTerrain: worker pool failed (" .. tostring(got) .. "), computing inline from now on")
			pool = {}
		end
	end
	if buf then
		stats.Parallel += 1
		stats.WorkerMs += buffer.readu32(buf, 20) / 1000
	else
		mark, phase = clock(), "ComputeMs"
		buf = Compute.tile(Overworld, tile.X0, tile.Z0, nx, nz, F.WaterY, Overworld.padsNear(tile.X0 - RES, tile.Z0 - RES, tile.X1 + RES, tile.Z1 + RES), slicer.Check)
		lap("ComputeMs")
		stats.Inline += 1
	end
	mark, phase = clock(), "DecodeMs"
	local written = writeBuffer(tile, buf :: buffer)
	lap("DecodeMs")
	stats.Tiles += 1
	stats.SolidVoxels += written
	return written
end

-- Tiles (key, box, regions) Build would write for the regions, unordered.
function OverworldTerrain.Plan(regionIds: { string }?): { any }
	return tilesFor(regionIds or Overworld.RegionIds)
end

local SITE_MARGIN = 96 -- a tile within this many studs of an arrival point (altar or barrier node) is a site tile

-- Arrival points whose ground must exist before the player can be sent there (every altar and the barrier node) or a
-- mob can stand on it (every overworld spawn, id "Spawn_<spawnId>"; patrol points sit within a few studs of it).
local function sites(): { [string]: { number } }
	local out: { [string]: { number } } = {}
	for id, a in Overworld.Altars do
		out[id] = { a.Placement.X, a.Placement.Z, a.Spawn.X, a.Spawn.Z }
	end
	local b = Overworld.Nodes[Overworld.BarrierNode].Position
	out[Overworld.BarrierNode] = { b.X, b.Z, b.X, b.Z }
	local spots: { any } = { Overworld.Training }
	for _, m in Overworld.Minibosses do
		table.insert(spots, m)
	end
	for _, m in Overworld.EncounterSpots or {} do -- ticket 09 encounters; AIService waits on each before its first spawn
		table.insert(spots, m)
	end
	for _, m in spots do
		out["Spawn_" .. m.Spawn] = { m.Placement.X, m.Placement.Z, m.Placement.X, m.Placement.Z }
	end
	return out
end

local function near(tile: any, x: number, z: number): boolean
	return math.max(tile.X0 - x, 0, x - tile.X1) ^ 2 + math.max(tile.Z0 - z, 0, z - tile.Z1) ^ 2 <= SITE_MARGIN ^ 2
end

-- { [siteId] = { tileKey } } for the plan's tiles that cover each arrival point.
function OverworldTerrain.SiteTiles(plan: { any }): { [string]: { string } }
	local out: { [string]: { string } } = {}
	for id, p in sites() do
		out[id] = {}
		for _, tile in plan do
			if near(tile, p[1], p[2]) or near(tile, p[3], p[4]) then
				table.insert(out[id], tile.Key)
			end
		end
	end
	return out
end

-- Tile ranking for Build: glade tiles (within gladeRadius of the gateway altar, nearest first), then the
-- site tiles in route order, then everything else along the route (nearest route node's rank).
function OverworldTerrain.Priority(gladeRadius: number): (any) -> number
	local rank: { [string]: number } = {}
	for i, id in Overworld.LongRoute do
		rank[id] = i
	end
	local nodes: { { X: number, Z: number, Rank: number } } = {}
	for id, n in Overworld.Nodes do
		table.insert(nodes, { X = n.Position.X, Z = n.Position.Z, Rank = rank[id] or 40 })
	end
	local gate = Overworld.Altars[Overworld.Gateway].Placement
	local list: { { Rank: number, P: { number } } } = {}
	-- Training and miniboss spawns first (rank 0); the many ordinary encounters after every altar (rank 45), so
	-- respawn and fast travel are not held back by them (measured: altars ready at 19 s instead of 9 s).
	local encounter: { [string]: boolean } = {}
	for _, m in Overworld.EncounterSpots or {} do
		encounter["Spawn_" .. m.Spawn] = true
	end
	for id, p in sites() do
		table.insert(list, { Rank = if encounter[id] then 45 elseif string.sub(id, 1, 6) == "Spawn_" then 0 else rank[id] or 40, P = p })
	end
	return function(tile: any): number
		local cx, cz = (tile.X0 + tile.X1) / 2, (tile.Z0 + tile.Z1) / 2
		local g = math.sqrt((cx - gate.X) ^ 2 + (cz - gate.Z) ^ 2)
		if g <= gladeRadius then
			return g
		end
		local siteRank = math.huge
		for _, s in list do
			if near(tile, s.P[1], s.P[2]) or near(tile, s.P[3], s.P[4]) then
				siteRank = math.min(siteRank, s.Rank)
			end
		end
		if siteRank < math.huge then
			return 1000 + siteRank
		end
		local bestRank, best = 99, math.huge
		for _, n in nodes do
			local d = math.sqrt((cx - n.X) ^ 2 + (cz - n.Z) ^ 2)
			if d < best then
				best, bestRank = d, n.Rank
			end
		end
		-- nearest route node orders the tile along the route; far-off tiles trail it
		return 2000 + bestRank * 1000 + math.min(best, 999) + (if best > 1500 then 100000 else 0)
	end
end

local REST_ORDER = 2000 -- Priority ranks at or above this are "the rest" (route order); below are glade and arrival sites
local REFOCUS_EVERY = 8 -- tiles written between re-ranks of the rest around the players
local URGENT = 256 -- studs (two tiles): unwritten ground this near a player or his look-ahead point outranks even the site tiles
local URGENT_BAND = 1e6 -- rank offset that puts the urgent tiles before every other rank

-- Re-ranks tiles[from..] in place: tiles within URGENT studs of any of points ({ x, z }: each player and where they will
-- be a few seconds on) go first, nearest first, so a sprint or glide never outruns the writer; then glade and
-- arrival-site tiles keep their order; the rest go nearest first to any point, so the unwritten ground always starts
-- as far from every player as it can. No points leaves the route order alone. Needs tile.Order (set by Build when an
-- order function is given).
function OverworldTerrain.Refocus(tiles: { any }, from: number, points: { { number } })
	if #points == 0 or from >= #tiles then
		return
	end
	local tail = table.move(tiles, from, #tiles, 1, {})
	for _, tile in tail do
		local cx, cz = (tile.X0 + tile.X1) / 2, (tile.Z0 + tile.Z1) / 2
		local best = math.huge
		for _, p in points do
			best = math.min(best, (cx - p[1]) ^ 2 + (cz - p[2]) ^ 2)
		end
		best = math.sqrt(best)
		local rank = tile.Order
		if best <= URGENT then
			rank = best - URGENT_BAND
		elseif rank >= REST_ORDER then
			rank = REST_ORDER + best
		end
		tile.Rank = rank
	end
	table.sort(tail, function(a: any, b: any) return a.Rank < b.Rank end)
	table.move(tail, 1, #tail, from, tiles)
end

local FALL_MARGIN = 24 -- studs below a written tile's lowest shell before a body counts as fallen through

local function tileKeyAt(x: number, z: number): string?
	local F = Overworld.Frame
	if x < F.MinX or x >= F.MaxX or z < F.MinZ or z >= F.MaxZ then
		return nil
	end
	return math.floor((x - F.MinX) / TILE) .. "," .. math.floor((z - F.MinZ) / TILE)
end

-- Where the written ground fails a body: "Unwritten" over a tile not yet written, "Fell" below a written tile's
-- floor, nil when it stands on written ground or outside the Frame (nothing outside is judged).
function OverworldTerrain.Verdict(x: number, y: number, z: number): string?
	local key = tileKeyAt(x, z)
	if not key then
		return nil
	end
	local tile = OverworldTerrain.Manifest[key]
	if not tile then
		return "Unwritten"
	end
	if tile.Floor and y < tile.Floor - FALL_MARGIN then
		return "Fell"
	end
	return nil
end

-- Nearest (flat distance) altar for which ready(id) is true, never the barrier-gated Antechamber; nil if none.
function OverworldTerrain.RescueAltar(x: number, z: number, ready: (string) -> boolean): string?
	local best: string?, bestD = nil, math.huge
	for id, a in Overworld.Altars do
		if id ~= "Altar_ColosseumAntechamber" and ready(id) then
			local d = (a.Placement.X - x) ^ 2 + (a.Placement.Z - z) ^ 2
			if d < bestD then
				best, bestD = id, d
			end
		end
	end
	return best
end

-- Builds the listed regions (default: all five). onTile(i, n, tile) runs after each tile; order(tile)
-- ranks tiles (lowest first) so the caller chooses what is written first; focus() (with order) lists the
-- { x, z } points the rest should be written around, re-read every REFOCUS_EVERY tiles. Returns stats:
-- { Tiles, Voxels, Seconds, Yields, TileSeconds = { number } }; times are wall clock and include the slice yields.
function OverworldTerrain.Build(regionIds: { string }?, onTile: ((number, number, any) -> ())?, order: ((any) -> number)?, focus: (() -> { { number } })?): any
	local tiles = tilesFor(regionIds or Overworld.RegionIds)
	if order then
		for _, tile in tiles do tile.Order = order(tile) end
		table.sort(tiles, function(a: any, b: any) return a.Order < b.Order end)
	end
	local stats = { Tiles = #tiles, Voxels = 0, Seconds = 0, Yields = 0, TileSeconds = table.create(#tiles) }
	mark, phase = clock(), "DecodeMs" -- the counters partition the work from here (Clear and the hooks reset it too)
	slicer.Begin()
	if not poolTried then
		local ok, err = pcall(startPool) -- any failure: one warn, tiles are computed inline
		if not ok then
			warn("OverworldTerrain: worker pool failed to start (" .. tostring(err) .. "), computing tiles inline")
			pool, pending = {}, nil
		end
	end
	if not settled then
		settled = true
		settle(function() return lastDt end)
	end
	if pending then
		local actors = pending
		pending = nil
		local ok, err = pcall(awaitWorkers, actors)
		if not ok then
			warn("OverworldTerrain: worker pool failed to start (" .. tostring(err) .. "), computing tiles inline")
			pool = {}
		end
	end
	mark = clock()
	slicer.Begin()
	for i = 1, #tiles do
		if order and focus and i % REFOCUS_EVERY == 0 then
			OverworldTerrain.Refocus(tiles, i, focus())
		end
		local tile = tiles[i]
		local t0 = os.clock()
		stats.Voxels += writeTile(tiles, i)
		local dt = os.clock() - t0
		stats.TileSeconds[i] = dt
		stats.Seconds += dt
		local entry = OverworldTerrain.Manifest[tile.Key]
		if entry then
			for id in tile.Regions do entry.Regions[id] = true end
			entry.Slabs, entry.Floor = tile.Slabs, tile.Floor
		else
			OverworldTerrain.Manifest[tile.Key] = tile
		end
		if onTile then onTile(i, #tiles, tile) end
		slicer.Check() -- a tile that costs less than the budget shares its frame with the next one
	end
	stats.Yields = slicer.Yields
	return stats
end

-- Empties the manifest tiles of the listed regions (default: everything built) and forgets them. A tile
-- shared with another region is emptied for both, so rebuild both.
function OverworldTerrain.Clear(regionIds: { string }?)
	for key, tile in OverworldTerrain.Manifest do
		local hit = regionIds == nil
		for _, id in regionIds or {} do hit = hit or tile.Regions[id] == true end
		if hit then
			mark = clock()
			slicer.Begin()
			for _, y0 in tile.Slabs do
				-- boxes one voxel column wide, sized like the writer's: FillBlock is as uninterruptible as WriteVoxels
				for x = tile.X0, tile.X1 - 1, RES do
					local z = tile.Z0
					while z < tile.Z1 do
						local zc = math.max(math.min(callVoxels() // (SLAB // RES), (tile.Z1 - z) // RES), 1)
						local size = Vector3.new(RES, SLAB, zc * RES)
						timed(zc * (SLAB // RES), function()
							terrain():FillBlock(CFrame.new(x + RES / 2, y0 + SLAB / 2, z + size.Z / 2), size, Enum.Material.Air)
						end)
						slicer.Check()
						z += zc * RES
					end
				end
			end
			OverworldTerrain.Manifest[key] = nil
			task.wait()
		end
	end
end

return OverworldTerrain

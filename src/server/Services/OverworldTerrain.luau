--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/OverworldTerrain
-- Writes the canonical overworld ground (Overworld.surfaceAt) as an 8-stud Terrain shell (deeper under steep faces) at resolution 4,
-- one 128-stud tile at a time, plus river and lake water up to Frame.WaterY. Work is time-sliced: the writer yields one
-- Heartbeat (task.wait) whenever it has used BUDGET seconds of the current frame, mid-tile if need be, so the server keeps its frame rate.
-- Every WriteVoxels / FillBlock is a box of about CALL_TARGET seconds (measured per voxel), reserved against the frame before it runs,
-- and the frame budget halves (floor a quarter) while the last Heartbeat was slower than 1/45 s.
-- Everything written is listed in Terrain.Manifest (tile XZ boxes and the Y slabs written); Clear only
-- empties those boxes, and nothing is ever written or cleared outside Overworld.Frame.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Overworld = require(ReplicatedStorage.AsurasPath.Shared.Overworld) :: any

local OverworldTerrain = {}

local RES = 4
local TILE = 128 -- studs; 32 columns
local SHELL = 8 -- studs of solid below the lowest of a column and its 8 neighbours (C3 ruling 1a: 202 MB at 12, about 160 MB at 8)
local SLAB = 64 -- studs of height written per slab (a slab is written in boxes, one column wide, never in one call)
local BUDGET = 0.006 -- seconds of writer work per Heartbeat (C3 ruling 1b: server heartbeat stays at or above 45 Hz)
local CALL_TARGET = 0.0025 -- seconds one WriteVoxels / FillBlock call may be expected to take (24a: a whole slab call stalled frames)
local VOXEL_COST0 = 8e-6 -- seconds per voxel assumed until the first call is measured; the measurement replaces it
local MIN_V = 16 -- voxels in the smallest call (one column of a slab)
local SLOW_DT = 1 / 45 -- a Heartbeat longer than this makes the slicer back off
local MIN_SCALE = 0.25 -- the slicer never works less than this share of BUDGET per frame
local N = TILE // RES

-- { [tileKey] = { X0, Z0, X1, Z1, Regions = { [id] = true }, Slabs = { y0, ... } } }
OverworldTerrain.Manifest = {} :: { [string]: any }

-- Counters for the Studio operator (read OverworldTerrain.Stats): milliseconds are work time only, never the time spent
-- yielded (YieldMs). ComputeMs = SampleMs + MaterialMs + ShellMs + FillMs; per tile = value / Tiles.
local function newStats(): { [string]: number }
	return { Tiles = 0, WriteCalls = 0, BoxVoxels = 0, SolidVoxels = 0, SampleMs = 0, MaterialMs = 0, ShellMs = 0, FillMs = 0,
		ComputeMs = 0, WriteMs = 0, YieldMs = 0 }
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

local materials: { [string]: Enum.Material } = {}
local function material(name: string): Enum.Material
	local m = materials[name]
	if not m then
		m = (Enum.Material :: any)[name]
		materials[name] = m
	end
	return m
end

export type Slicer = {
	Yields: number, Backoffs: number, Skipped: number, Scale: number,
	Begin: () -> (), Check: () -> boolean, Reserve: (number) -> boolean, Limit: () -> number,
}

-- Frame time slice. Check() yields one frame (yield, task.wait) once the slice limit (budget * Scale) has passed since the
-- slice began, and starts the next slice when it resumes; returns true if it yielded. Reserve(est) is Check for an
-- uninterruptible call expected to take est seconds: it yields first if the call would not fit in the slice.
-- Begin() restarts the slice (call after any other wait). With frameDt (last Heartbeat dt) the slice adapts on every
-- resume: a frame longer than SLOW_DT halves Scale (floor MIN_SCALE; at the floor one extra frame is skipped), a good frame
-- grows it back by a quarter up to 1.
function OverworldTerrain.NewSlicer(budget: number, clock: () -> number, yield: () -> any, frameDt: (() -> number)?): Slicer
	local began = clock()
	local self: Slicer = {
		Yields = 0, Backoffs = 0, Skipped = 0, Scale = 1,
		Begin = function() end, Check = function() return false end, Reserve = function(_: number) return false end, Limit = function() return budget end,
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
				self.Scale = math.min(self.Scale * 1.25, 1)
			end
		end
		began = clock()
	end
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
local mark, phase = 0, "FillMs"
-- Adds the time since the last lap to a phase counter (and to ComputeMs unless it is the write phase).
local function lap(key: string)
	local t = clock()
	local ms = (t - mark) * 1000
	OverworldTerrain.Stats[key] += ms
	if key ~= "WriteMs" then OverworldTerrain.Stats.ComputeMs += ms end
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
local perVoxel = VOXEL_COST0 -- measured seconds per voxel of the slowest recent call (rises at once, decays 10% per call)

-- Test hook: swap the clock, the yield and the frame-time source (fakes), and forget the measured voxel cost.
function OverworldTerrain.Use(c: () -> number, yield: () -> any, frameDt: (() -> number)?)
	clock = c
	slicer = OverworldTerrain.NewSlicer(BUDGET, c, counted(yield), frameDt)
	OverworldTerrain.Slicer = slicer
	perVoxel = VOXEL_COST0
	OverworldTerrain.Stats = newStats()
end

-- Voxels the next engine call may cover: about CALL_TARGET seconds at the measured cost, never more than half a slice.
local function callVoxels(): number
	return math.max(math.floor(math.min(CALL_TARGET, slicer.Limit() / 2) / perVoxel), MIN_V)
end

-- Runs one engine call of `voxels` voxels: reserves its estimated cost in the slice, then measures it.
local function timed(voxels: number, call: () -> ())
	slicer.Reserve(perVoxel * voxels)
	lap(phase)
	local t0 = clock()
	call()
	local t1 = clock()
	local stats = OverworldTerrain.Stats
	stats.WriteCalls += 1
	stats.BoxVoxels += voxels
	stats.WriteMs += (t1 - t0) * 1000
	mark = t1
	local s = (t1 - t0) / voxels
	perVoxel = if s > perVoxel then s else perVoxel * 0.9 + s * 0.1
end

-- Writes one tile; returns the number of solid or water voxels written.
local function writeTile(tile: any): number
	local F = Overworld.Frame
	local nx, nz = (tile.X1 - tile.X0) // RES, (tile.Z1 - tile.Z0) // RES
	mark, phase = clock(), "SampleMs"
	-- Column samples at voxel centres plus a one-column margin all round: forward differences for slope, and
	-- the 8 neighbours that set how deep each column is filled.
	local hs, roadW, channelW, chasmW = {}, {}, {}, {}
	local minH, maxH = math.huge, -math.huge
	for i = -1, nx do
		hs[i], roadW[i], channelW[i], chasmW[i] = {}, {}, {}, {}
		for j = -1, nz do
			local h, r, c, k = Overworld.sampleAt(tile.X0 + (i + 0.5) * RES, tile.Z0 + (j + 0.5) * RES)
			hs[i][j], roadW[i][j], channelW[i][j], chasmW[i][j] = h, r, c, k
			if i >= 0 and i < nx and j >= 0 and j < nz then
				minH, maxH = math.min(minH, h), math.max(maxH, h)
			end
		end
		slicer.Check()
	end
	lap("SampleMs")
	local mats = table.create(nx)
	for i = 0, nx - 1 do
		mats[i + 1] = table.create(nz)
		for j = 0, nz - 1 do
			local h = hs[i][j]
			local slope = math.sqrt((hs[i + 1][j] - h) ^ 2 + (hs[i][j + 1] - h) ^ 2) / RES
			mats[i + 1][j + 1] = material(Overworld.materialAt(
				tile.X0 + (i + 0.5) * RES, tile.Z0 + (j + 0.5) * RES, h, slope, roadW[i][j], channelW[i][j], chasmW[i][j]))
		end
		slicer.Check()
	end

	lap("MaterialMs")
	local top = math.max(maxH, if minH < F.WaterY then F.WaterY else -math.huge)
	local written = 0
	tile.Slabs = {}
	local bottoms, floor = table.create(nx), math.huge
	for i = 1, nx do
		bottoms[i] = table.create(nz)
		for j = 1, nz do
			local b = Overworld.shellBottom(hs, i - 1, j - 1, SHELL)
			bottoms[i][j] = b
			if b < floor then floor = b end
		end
		slicer.Check()
	end
	tile.Floor = floor
	lap("ShellMs")
	phase = "FillMs"
	for y0 = math.floor((floor - RES) / SLAB) * SLAB, top, SLAB do
		local ny = SLAB // RES
		local slabAny = false
		-- A slab is written in boxes one column wide and zc columns long, zc sized so one WriteVoxels call costs about
		-- CALL_TARGET (WriteVoxels cannot be interrupted, so the call itself must be small).
		for i = 1, nx do
			local j0 = 1
			while j0 <= nz do
				local zc = math.min(math.max(callVoxels() // ny, 1), nz - j0 + 1)
				local mcol, ocol = table.create(ny), table.create(ny)
				for k = 1, ny do
					mcol[k], ocol[k] = table.create(zc, Enum.Material.Air), table.create(zc, 0)
				end
				local any = false
				for jj = 1, zc do
					local j = j0 + jj - 1
					local h = hs[i - 1][j - 1]
					local lake = h < F.WaterY and chasmW[i - 1][j - 1] == 0
					local m = mats[i][j]
					local bottom = bottoms[i][j]
					for k = 1, ny do
						local yc = y0 + (k - 0.5) * RES
						local occ = math.min(math.clamp((h - yc) / RES + 0.5, 0, 1), math.clamp((yc - bottom) / RES + 0.5, 0, 1))
						if occ >= 0.02 then
							if occ < 0.5 and lake then
								local w = math.clamp((F.WaterY - yc) / RES + 0.5, 0, 1)
								if w > occ then
									mcol[k][jj], ocol[k][jj] = Enum.Material.Water, w
									written += 1
									any = true
									continue
								end
							end
							mcol[k][jj], ocol[k][jj] = m, occ
							written += 1
							any = true
						elseif lake and yc < F.WaterY then
							mcol[k][jj], ocol[k][jj] = Enum.Material.Water, math.clamp((F.WaterY - yc) / RES + 0.5, 0, 1)
							written += 1
							any = true
						end
					end
				end
				if any then
					slabAny = true
					local x0, z0 = tile.X0 + (i - 1) * RES, tile.Z0 + (j0 - 1) * RES
					timed(ny * zc, function()
						terrain():WriteVoxels(Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + RES, y0 + SLAB, z0 + zc * RES)), RES, { mcol }, { ocol })
					end)
				end
				slicer.Check()
				j0 += zc
			end
		end
		if slabAny then
			table.insert(tile.Slabs, y0)
		end
	end
	lap("FillMs")
	OverworldTerrain.Stats.Tiles += 1
	OverworldTerrain.Stats.SolidVoxels += written
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
	slicer.Begin()
	for i = 1, #tiles do
		if order and focus and i % REFOCUS_EVERY == 0 then
			OverworldTerrain.Refocus(tiles, i, focus())
		end
		local tile = tiles[i]
		local t0 = os.clock()
		stats.Voxels += writeTile(tile)
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

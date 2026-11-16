--!nonstrict
-- Terrain generation order (ticket 03/05 follow-up): OverworldTerrain.Priority ranks the glade tiles first, then
-- every tile around an altar or the barrier node (SiteTiles), then the rest in route order.
-- Run: python3 tools/lune_compat.py tools/test_overworld_order.luau (loads the real module with a stubbed environment).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local O = require("../src/shared/Overworld")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local services = { Workspace = { Terrain = {} }, ReplicatedStorage = { AsurasPath = { Shared = { Overworld = O } } } }
local game = { GetService = function(_, n) return services[n] end }
local env = { game = game, require = function(m) return m end, task = { wait = function() end }, os = os, math = math, table = table,
	string = string, Vector3 = roblox.Vector3, Enum = roblox.Enum,
	Region3 = { new = function(a, b) return { Min = a, Max = b } end }, CFrame = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }, pairs = pairs, ipairs = ipairs, type = type,
	tostring = tostring, warn = warn, print = print, assert = assert, error = error, setmetatable = setmetatable }
local Terrain = luau.load(fs.readFile("src/server/Services/OverworldTerrain.luau"), { debugName = "OverworldTerrain", environment = env })()

local GLADE = 640
local plan = Terrain.Plan()
local rank = Terrain.Priority(GLADE)
local sites = Terrain.SiteTiles(plan)
local isSite = {}
for _, keys in sites do for _, k in keys do isSite[k] = true end end
local gate = O.Altars[O.Gateway].Placement

local gladeMax, siteMax, restMin, siteN, gladeN = -math.huge, -math.huge, math.huge, 0, 0
for _, tile in plan do
	local r = rank(tile)
	local cx, cz = (tile.X0 + tile.X1) / 2, (tile.Z0 + tile.Z1) / 2
	if math.sqrt((cx - gate.X) ^ 2 + (cz - gate.Z) ^ 2) <= GLADE then
		gladeN += 1
		gladeMax = math.max(gladeMax, r)
	elseif isSite[tile.Key] then
		siteN += 1
		siteMax = math.max(siteMax, r)
	else
		restMin = math.min(restMin, r)
	end
end
print(string.format("tiles %d: glade %d, site %d, rest %d", #plan, gladeN, siteN, #plan - gladeN - siteN))

check("glade tiles rank at most the radius", gladeN > 0 and gladeMax <= GLADE)
check("site tiles rank after the glade and before every other tile", siteN > 0 and siteMax < restMin)
local siteMin = math.huge
for _, tile in plan do
	local cx, cz = (tile.X0 + tile.X1) / 2, (tile.Z0 + tile.Z1) / 2
	if isSite[tile.Key] and math.sqrt((cx - gate.X) ^ 2 + (cz - gate.Z) ^ 2) > GLADE then siteMin = math.min(siteMin, rank(tile)) end
end
check("glade ranks before site tiles", gladeMax < siteMin)

local function tileAt(x, z)
	for _, t in plan do
		if x >= t.X0 and x < t.X1 and z >= t.Z0 and z < t.Z1 then return t.Key end
	end
end
local function has(list, key) return table.find(list, key) ~= nil end
for id, a in O.Altars do
	check(id .. " has site tiles", sites[id] and #sites[id] >= 1)
	check(id .. " placement and spawn tiles are site tiles", has(sites[id], tileAt(a.Placement.X, a.Placement.Z)) and has(sites[id], tileAt(a.Spawn.X, a.Spawn.Z)))
end
local b = O.Nodes[O.BarrierNode].Position
check("barrier node tile is a site tile", has(sites[O.BarrierNode], tileAt(b.X, b.Z)))
check("site tiles are a small share of the plan", siteN <= #plan * 0.1)

-- T09a: every overworld mob spawn (and its patrol points) has its ground written before AIService spawns it.
local World = require("../src/shared/WorldDefinitions")
local spawnCount = 0
for _, entry in World.Spawns do
	spawnCount += 1
	local list = sites["Spawn_" .. entry.Id]
	local p = entry.Placement
	check(entry.Id .. " has a spawn site", list ~= nil and #list >= 1)
	check(entry.Id .. " placement tile is a site tile", list ~= nil and has(list, tileAt(p.X, p.Z)))
	for _, point in entry.Patrol do
		check(entry.Id .. " patrol tile is a site tile", list ~= nil and has(list, tileAt(point.X, point.Z)))
	end
	-- Training and miniboss spawns rank first among the site tiles; ordinary encounters (T09) after every altar, still before the rest.
	local ordinary = false
	for _, spot in O.EncounterSpots or {} do ordinary = ordinary or spot.Spawn == entry.Id end
	local spawnRank = rank({ X0 = p.X - 1, X1 = p.X + 1, Z0 = p.Z - 1, Z1 = p.Z + 1 })
	check(entry.Id .. " spawn tile ranks in the glade or first among the site tiles", tileAt(p.X, p.Z) ~= nil and ((ordinary and spawnRank < 2000) or (not ordinary and spawnRank <= 1000)))
end
check("both overworld mobs are spawn sites", spawnCount >= 2)

local keys = {}
for _, t in plan do keys[t.Key] = (keys[t.Key] or 0) + 1 end
local unique = true
for _, c in keys do unique = unique and c == 1 end
check("every tile is ranked once", unique)

-- C3 unwritten ground: Refocus writes the rest nearest the players first; Verdict/RescueAltar decide the guard.
local function rectDistance(tile, x, z)
	return math.sqrt(math.max(tile.X0 - x, 0, x - tile.X1) ^ 2 + math.max(tile.Z0 - z, 0, z - tile.Z1) ^ 2)
end

-- Simulates the generator (rate tiles/s, Refocus every 8 tiles around the player and 3 s ahead of it) against a
-- player who stands at the glade until t = 9 s and then moves at speed (studs/s) along (dx, dz) for 180 s.
-- Returns the smallest distance from the player to any unwritten tile, and the first time the player's own tile was unwritten.
local function sprint(rate, speed, dx, dz)
	local tiles = Terrain.Plan()
	for _, t in tiles do t.Order = rank(t) end
	table.sort(tiles, function(a, b) return a.Order < b.Order end)
	Terrain.Manifest = {}
	local len = math.sqrt(dx * dx + dz * dz)
	local ux, uz = dx / len, dz / len
	local px, pz, vx, vz = gate.X, gate.Z, 0, 0
	local written, owed, margin, onUnwritten = 0, 0, math.huge, nil
	local F = O.Frame
	for step = 1, 720 do
		local t = step * 0.25
		if t > 9 and px + ux * speed * 0.25 > F.MinX + 20 and pz + uz * speed * 0.25 > F.MinZ + 20 and px + ux * speed * 0.25 < F.MaxX - 20 and pz + uz * speed * 0.25 < F.MaxZ - 20 then
			vx, vz = ux * speed, uz * speed
			px, pz = px + vx * 0.25, pz + vz * 0.25
		else
			vx, vz = 0, 0
		end
		owed += rate * 0.25
		while owed >= 1 and written < #tiles do
			if written > 0 and written % 8 == 0 then
				local points = { { px, pz }, { px + vx * 3, pz + vz * 3 } }
				if t >= 9 then Terrain.Refocus(tiles, written + 1, points) end
			end
			written += 1
			Terrain.Manifest[tiles[written].Key] = tiles[written]
			owed -= 1
		end
		if t >= 9 then
			if Terrain.Verdict(px, 100, pz) == "Unwritten" and not onUnwritten then onUnwritten = t end
			for i = written + 1, #tiles do
				margin = math.min(margin, rectDistance(tiles[i], px, pz))
			end
		end
	end
	return margin, onUnwritten
end

-- Time-sliced throughput model (03f). Assumptions, stated: the writer works BUDGET seconds per Heartbeat and the server
-- runs at FRAME_HZ; a tile costs TILE_COST seconds of work. TILE_COST 0.040 is the 12c reading (one tile per frame at
-- 21-26 Hz, 24 tiles/s) with no credit for SHELL 8 (it removes about 21% of the fill, none of the sampling), so this
-- is a worst case; the rate is fractional tiles per second, with the work of a tile carried over between frames.
local src = fs.readFile("src/server/Services/OverworldTerrain.luau")
local BUDGET = tonumber(string.match(src, "local BUDGET = ([%d%.]+)")) :: number
local FRAME_HZ, TILE_COST = 60, 0.040
local modelled = FRAME_HZ * BUDGET / TILE_COST
check("writer constants: SHELL 8, SLAB 64, BUDGET 6 ms", string.match(src, "local SHELL = 8 ") ~= nil and string.match(src, "local SLAB = 64 ") ~= nil and BUDGET == 0.006)
print(string.format("modelled writer throughput: %.1f tiles/s (%d Hz x %.0f ms / %.0f ms per tile); full run of %d tiles takes %.0f s", modelled, FRAME_HZ, BUDGET * 1000, TILE_COST * 1000, #plan, #plan / modelled))
for _, dir in { { "west", -1, 0 }, { "northwest", -1, -1 }, { "north", 0, -1 } } do
	for _, rate in { modelled, 15, 23 } do
		local margin, hit = sprint(rate, 33.6, dir[2], dir[3])
		print(string.format("sprint %s, %.1f tiles/s: smallest gap to unwritten ground %.0f studs%s", dir[1], rate, margin, hit and (" (stood on it at t=" .. hit .. ")") or ""))
		check("sprint " .. dir[1] .. " at " .. string.format("%.1f", rate) .. " tiles/s never reaches unwritten ground", hit == nil and margin > 128)
	end
end
local glideMargin, glideHit = sprint(15, 60, -1, -1)
print(string.format("glide 60 st/s northwest, 15 tiles/s: gap %.0f studs", glideMargin))
check("a 60 st/s glide keeps ahead of the generator", glideHit == nil)
local modelMargin, modelHit = sprint(modelled, 60, -1, -1)
print(string.format("glide 60 st/s northwest, %.1f tiles/s (modelled): gap %.0f studs", modelled, modelMargin))
check("a 60 st/s glide keeps ahead of the time-sliced generator", modelHit == nil)

-- Time slicer (03f): fake clock and yield. Rows of work cost ROW seconds; Check() after each row.
do
	local ROW, BUDGET_T, ROWS = 0.0008, 0.006, 400
	local now, yields, slicer
	local order = {}
	now, yields = 0, 0
	slicer = Terrain.NewSlicer(BUDGET_T, function() return now end, function() yields += 1; now += 1 / 60 end)
	local sinceYield, worstRun, lastN = 0, 0, 0
	for row = 1, ROWS do
		now += ROW
		sinceYield += ROW
		worstRun = math.max(worstRun, sinceYield)
		table.insert(order, row)
		if slicer.Check() then sinceYield = 0 end
	end
	local sorted = true
	for i = 2, #order do sorted = sorted and order[i] == order[i - 1] + 1 end
	local expected = math.floor(ROWS / math.ceil(BUDGET_T / ROW - 1e-9))
	print(string.format("slicer: %d rows of %.1f ms, %d yields (counter %d), worst work run %.1f ms for a 6 ms budget", ROWS, ROW * 1000, yields, slicer.Yields, worstRun * 1000))
	check("slicer: work between yields never exceeds budget plus one row", worstRun <= BUDGET_T + ROW + 1e-9)
	check("slicer: yield count matches the budget (" .. expected .. " +-1) and the counter agrees", math.abs(yields - expected) <= 1 and slicer.Yields == yields)
	check("slicer: row order preserved across yields", sorted and #order == ROWS)
	-- A row that alone exceeds the budget is not split: one yield after it, not several.
	local before = yields
	now += 0.05
	slicer.Check()
	check("slicer: a single long row costs exactly one yield", yields == before + 1)
	-- Begin() after some other wait restarts the slice: no yield on the next Check.
	now += 1
	slicer.Begin()
	check("slicer: Begin() restarts the slice (no yield straight after a long wait)", slicer.Check() == false)
	-- Under budget never yields.
	local quiet = 0
	local s2 = Terrain.NewSlicer(BUDGET_T, function() return now end, function() quiet += 1 end)
	for _ = 1, 5 do now += 0.001; s2.Check() end
	check("slicer: stays quiet under budget", quiet == 0 and s2.Yields == 0)
end

-- Reserve (24a): an uninterruptible call is reserved against the slice before it runs.
do
	local now, yields = 0, 0
	local s = Terrain.NewSlicer(0.006, function() return now end, function() yields += 1 end)
	check("reserve: a call on a fresh slice always runs, even one larger than the budget", s.Reserve(0.05) == false and yields == 0)
	now += 0.002
	check("reserve: fits in the rest of the slice, no yield", s.Reserve(0.003) == false and yields == 0)
	check("reserve: would overrun the slice, yields first", s.Reserve(0.0045) == true and yields == 1 and s.Yields == 1)
	check("reserve: the slice restarted after the yield", s.Reserve(0.005) == false)
end

-- Bounded engine calls (24a, C3 must-fix b): fake clock, fake Terrain, real tiles. Each WriteVoxels / FillBlock advances the
-- fake clock by TRUE x voxels; every yield is one frame of dt. No frame's call work may pass the slice limit.
do
	local BUDGET_S, CALL_MAX = 0.006, 0.0025
	local state = {}
	local function voxelsOf(mat) return #mat * #mat[1] * #mat[1][1] end
	local function run(label, trueCost, frameDtOf, tilesN, withClear)
		local now, frames, work, calls, worstCall = 0, {}, 0, {}, 0
		local fdt = frameDtOf
		local frameN = 0
		local function yield()
			table.insert(frames, { Work = work, Limit = BUDGET_S * state.slicer.Scale, N = frameN })
			work, frameN = 0, frameN + 1
			now += fdt(frameN)
		end
		Terrain.Use(function() return now end, yield, function() return fdt(frameN) end)
		state.slicer = Terrain.Slicer
		local function spend(voxels)
			local c = voxels * trueCost
			now += c
			work += c
			worstCall = math.max(worstCall, c)
		end
		services.Workspace.Terrain.WriteVoxels = function(_, region, _, mat, occ)
			spend(voxelsOf(mat))
			local solid = 0
			for _, col in occ do for _, row in col do for _, v in row do if v > 0 then solid += 1 end end end end
			table.insert(calls, { Min = region.Min, Max = region.Max, Solid = solid })
		end
		services.Workspace.Terrain.FillBlock = function(_, cf, size)
			spend((size.X // 4) * (size.Y // 4) * (size.Z // 4))
			table.insert(calls, { Fill = true, X = cf.X, SizeX = size.X })
		end
		Terrain.Manifest = {}
		local seen, order, boxesOk, inside = 0, {}, true, true
		local function onTile(i, n, tile)
			table.insert(order, tile)
			for _, c in calls do
				if not c.Fill then
					-- every box lies inside its own tile and is one voxel column wide, one slab tall
					inside = inside and c.Min.X >= tile.X0 and c.Max.X <= tile.X1 and c.Min.Z >= tile.Z0 and c.Max.Z <= tile.Z1
					boxesOk = boxesOk and c.Max.X - c.Min.X == 4 and c.Max.Y - c.Min.Y == 64
				end
			end
			seen += #calls
			if i >= tilesN then error("stop") end
		end
		local nCalls, solid, stats = 0, 0, nil
		local t0 = os.clock()
		local ok = pcall(function()
			stats = Terrain.Build(nil, function(i, n, tile)
				local before = #calls
				for _, c in calls do if not c.Fill then solid += c.Solid end end
				nCalls += #calls
				onTile(i, n, tile)
				table.clear(calls)
			end, rank, nil)
		end)
		local compute = os.clock() - t0
		local worst = 0
		for _, f in frames do worst = math.max(worst, f.Work) end
		return { Frames = frames, Worst = worst, WorstCall = worstCall, Order = order, Calls = nCalls, Solid = solid, Box = boxesOk, Inside = inside, Compute = compute, Now = now, Slicer = state.slicer }
	end

	-- a. Normal frames (60 Hz, the cost guess is right): no frame's work passes the budget, no call passes CALL_MAX.
	local a = run("normal", 8e-6, function() return 1 / 60 end, 4)
	local nTiles = #a.Order
	print(string.format("bounded: %d tiles, %d calls, worst frame %.2f ms, worst call %.2f ms, %d frames, %.1f s sim, compute-only %.0f ms/tile",
		nTiles, a.Calls, a.Worst * 1000, a.WorstCall * 1000, #a.Frames, a.Now, a.Compute / math.max(nTiles, 1) * 1000))
	check("bounded: the run wrote tiles", nTiles >= 4 and a.Calls > nTiles * 20)
	check("bounded: no simulated frame passes the 6 ms budget", a.Worst <= BUDGET_S + 1e-9)
	check("bounded: no single engine call passes 2.5 ms", a.WorstCall <= CALL_MAX + 1e-9)
	check("bounded: every box lies in its tile and is one column x one slab", a.Box and a.Inside)
	local solidCount = 0
	for _, t in a.Order do solidCount += #t.Slabs end
	check("bounded: every written tile lists its slabs", solidCount >= nTiles)
	local stateVox = 0
	check("bounded: the boxes write every solid and water voxel the tile owes", a.Solid > 0)
	check("bounded: never a whole-slab call (30+ boxes a tile; a slab was one call)", a.Calls / nTiles >= 30)

	-- b. Priority: tiles come in nondecreasing rank (glade first, nearest first); the first is the glade tile nearest the altar.
	local ordered = true
	for i = 2, nTiles do ordered = ordered and a.Order[i].Order >= a.Order[i - 1].Order end
	check("priority: tiles are written in rank order, glade nearest first", ordered and a.Order[1].Order <= 128)

	-- c. A cost 5x the guess: only the first (learning) call may overrun; after it the estimates follow the measurement.
	local c = run("spike", 40e-6, function() return 1 / 60 end, 2)
	local late = 0
	for i = 2, #c.Frames do late = math.max(late, c.Frames[i].Work) end
	print(string.format("spike: first frame %.1f ms, worst afterwards %.2f ms", c.Frames[1].Work * 1000, late * 1000))
	check("spike: after the first call no frame passes the budget", late <= BUDGET_S + 1e-9)

	-- d. Back-off: 40 Heartbeats at 30 Hz (slow), then 60 Hz. The scale halves to the floor, a frame is skipped, work
	--    per frame follows the scale, and the slice grows back to the full budget.
	local slowUntil = 40
	local scaleMin, floorFrames, floorOver = 1, 0, 0
	local d = run("backoff", 8e-6, function(n) return if n < slowUntil then 1 / 30 else 1 / 60 end, 3)
	for _, f in d.Frames do
		scaleMin = math.min(scaleMin, f.Limit / BUDGET_S)
		if f.Limit / BUDGET_S <= 0.25 + 1e-9 then
			floorFrames += 1
			floorOver = math.max(floorOver, f.Work - f.Limit)
		end
	end
	local sl = d.Slicer
	print(string.format("backoff: %d back-offs, %d frames skipped, scale min %.2f, final scale %.2f, %d floor frames (worst over limit %.2f ms)",
		sl.Backoffs, sl.Skipped, scaleMin, sl.Scale, floorFrames, floorOver * 1000))
	check("backoff: a slow Heartbeat triggers it", sl.Backoffs >= 3)
	check("backoff: the slice halves down to a quarter", math.abs(scaleMin - 0.25) < 1e-9)
	check("backoff: at the floor a frame is skipped", sl.Skipped >= 1)
	check("backoff: at the floor no frame passes its scaled limit", floorFrames >= 10 and floorOver <= 1e-9)
	check("backoff: the slice grows back to the full budget once frames are healthy", sl.Scale == 1)

	-- e. Clear is bounded too: strips of 8 studs, none over 2.5 ms.
	local now2, worst2, n2 = 0, 0, 0
	Terrain.Use(function() return now2 end, function() now2 += 1 / 60 end, nil)
	services.Workspace.Terrain.FillBlock = function(_, cf, size)
		local cst = (size.X // 4) * (size.Y // 4) * (size.Z // 4) * 8e-6
		now2 += cst
		worst2, n2 = math.max(worst2, cst), n2 + 1
	end
	local sample = {}
	for k = 1, 2 do sample[k] = a.Order[k] end
	Terrain.Manifest = {}
	for _, t in sample do Terrain.Manifest[t.Key] = t end
	Terrain.Clear()
	print(string.format("clear: 2 tiles, %d fills, worst %.2f ms", n2, worst2 * 1000))
	check("clear: every FillBlock box is under 2.5 ms and the manifest is emptied", n2 >= 16 and worst2 <= CALL_MAX + 1e-9 and next(Terrain.Manifest) == nil)

	-- f. Guard on freshly written tiles (Floor and Manifest kept by Build).
	Terrain.Manifest = {}
	local w = a.Order[1]
	Terrain.Manifest[w.Key] = w
	local cx, cz = (w.X0 + w.X1) / 2, (w.Z0 + w.Z1) / 2
	check("guard after a bounded write: standing on it", Terrain.Verdict(cx, w.Floor + 40, cz) == nil)
	check("guard after a bounded write: below its floor", Terrain.Verdict(cx, w.Floor - 30, cz) == "Fell")
	check("guard after a bounded write: neighbour not written", (function() local u = a.Order[nTiles]; return Terrain.Verdict((u.X0 + u.X1) / 2, 100, (u.Z0 + u.Z1) / 2) == "Unwritten" end)())

	-- Restore the real clock for the rest of the file.
	Terrain.Use(os.clock, function() end, nil)
end

-- Guard decision.
Terrain.Manifest = {}
local mid = { X = (O.Frame.MinX + O.Frame.MaxX) / 2, Z = (O.Frame.MinZ + O.Frame.MaxZ) / 2 }
check("verdict: over an unwritten tile", Terrain.Verdict(mid.X, 100, mid.Z) == "Unwritten")
check("verdict: the lobby (outside the Frame) is never judged", Terrain.Verdict(0, 602, 920) == nil)
check("verdict: the Frame's max edge is outside", Terrain.Verdict(O.Frame.MaxX, 100, mid.Z) == nil)
local here = tileAt(mid.X, mid.Z)
for _, t in plan do if t.Key == here then t.Floor = 40; Terrain.Manifest[t.Key] = t end end
check("verdict: written tile, standing on it", Terrain.Verdict(mid.X, 120, mid.Z) == nil)
check("verdict: written tile, below its floor", Terrain.Verdict(mid.X, 40 - 25, mid.Z) == "Fell")
check("verdict: written tile, just under the shell is tolerated", Terrain.Verdict(mid.X, 40 - 20, mid.Z) == nil)
local ready = {}
check("rescue: nothing ready, nowhere to go", Terrain.RescueAltar(mid.X, mid.Z, function(id) return ready[id] == true end) == nil)
ready.Altar_MonasteryGate, ready.Altar_BasinCistern, ready.Altar_ColosseumAntechamber = true, true, true
local function rescueFrom(x, z) return Terrain.RescueAltar(x, z, function(id) return ready[id] == true end) end
check("rescue: nearest ready altar by flat distance", rescueFrom(-9000, -2000) == "Altar_BasinCistern" and rescueFrom(-2500, -1500) == "Altar_MonasteryGate")
check("rescue: never the barrier-gated Antechamber, even when it is the nearest", rescueFrom(-7200, -7900) ~= "Altar_ColosseumAntechamber")
check("rescue: an altar whose tiles are not written is skipped", (function() ready.Altar_MonasteryGate = nil; return rescueFrom(-2500, -1500) == "Altar_BasinCistern" end)())

-- Refocus keeps glade and site tiles ahead and leaves the order alone without players.
do
	local tiles = Terrain.Plan()
	for _, t in tiles do t.Order = rank(t) end
	table.sort(tiles, function(a, b) return a.Order < b.Order end)
	local before = {}
	for i, t in tiles do before[i] = t.Key end
	Terrain.Refocus(tiles, 5, {})
	local same = true
	for i, t in tiles do same = same and before[i] == t.Key end
	check("refocus without players keeps route order", same)
	local far = { O.Frame.MinX + 10, O.Frame.MinZ + 10 }
	Terrain.Refocus(tiles, 5, { far })
	local function urgent(t) return math.sqrt(((t.X0 + t.X1) / 2 - far[1]) ^ 2 + ((t.Z0 + t.Z1) / 2 - far[2]) ^ 2) <= 256 end
	local nUrgent, siteOrGlade, firstRest, urgentFirst = 0, 0, nil, true
	for i, t in tiles do
		if urgent(t) then
			nUrgent += 1
			urgentFirst = urgentFirst and i >= 5 and i < 5 + (function() local n = 0 for _, u in tiles do if urgent(u) then n += 1 end end return n end)()
		elseif t.Order < 2000 then
			siteOrGlade += 1
		elseif not firstRest then
			firstRest = i
		end
	end
	check("refocus puts the tiles within 256 studs of a player first", nUrgent >= 1 and urgentFirst)
	check("refocus leaves every other glade and site tile ahead of the rest", firstRest == nUrgent + siteOrGlade + 1)
	check("refocus puts the tile nearest the player first among the rest", rectDistance(tiles[firstRest], far[1], far[2]) < 450)
	check("refocus keeps every tile once", #tiles == #plan)
end

print(string.format("overworld order: %d passed, %d failed", passed, failed))
if failed > 0 then error("overworld order tests failed") end

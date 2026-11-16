--!nonstrict
-- Ticket 09: ordinary encounters on the replacement overworld. Run from the project root:
--   work/bin/luau/luau.exe tools/test_overworld_encounters.luau   (plain Luau CLI; no Lune APIs needed)
-- Pure data: placement per biome on road-side fighting ground, floor convention, clearances from checkpoints,
-- arrival points, rings, caches, the glade and the lobby, and leashes that stay inside the home region.
local O = require("../src/shared/Overworld")
local World = require("../src/shared/WorldDefinitions")

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function count(t) local n = 0 for _ in t do n += 1 end return n end

local E = O.Encounters
local C = E.Clearance
local ROOT_ABOVE_HEIGHT = 5 -- heightAt + 2 (voxel surface) + 3 (root above floor)
local TOLERANCE = { Forest = 1.6, GoldenRavine = 1.6, AridBasin = 1.8, Snowfields = 2.4, MountainAscent = 3.2 } -- height spread over a 10 stud ring
local MAIN_ROUTE = { Forest = 4800, GoldenRavine = 2000, AridBasin = 4000, Snowfields = 4400, MountainAscent = 3600 } -- GEOGRAPHY_PLAN per-biome main-route targets
local liveById = {}
for _, entry in World.Spawns do liveById[entry.Id] = entry end

-- Road centrelines per edge (either direction), from the one terrain definition.
local roads = {}
for _, r in O.terrainData().Roads do roads[r.A .. ">" .. r.B] = r; roads[r.B .. ">" .. r.A] = r end
local function roadDistance(edge, x, z)
	local r = roads[edge]
	if not r then return math.huge end
	local best = math.huge
	for _, p in r.Points do best = math.min(best, flat(x, z, p[1], p[2])) end
	return best
end
local function edgeExists(edge)
	for _, e in O.Edges do if e.A .. ">" .. e.B == edge or e.B .. ">" .. e.A == edge then return true end end
	return false
end
local function insideRegion(id, x, z)
	local b = O.Regions[id].Bounds
	return math.min(x - (b.Center.X - b.Size.X / 2), b.Center.X + b.Size.X / 2 - x, z - (b.Center.Z - b.Size.Z / 2), b.Center.Z + b.Size.Z / 2 - z)
end

local members, groupsByRegion, monks, total, seen = {}, {}, {}, {}, {}
for _, g in E.Groups do
	groupsByRegion[g.Region] = (groupsByRegion[g.Region] or 0) + 1
	check(g.Id .. " has one to three foes", #g.Spawns >= 1 and #g.Spawns <= 3)
	for _, s in g.Spawns do
		table.insert(members, s)
		total[s.Region] = (total[s.Region] or 0) + 1
		if s.Mob == "CorruptWanderingMonk" then monks[s.Region] = (monks[s.Region] or 0) + 1 end
	end
end

-- Each biome's enemy placement matches its fighting-ground sites in the canonical data.
for _, region in O.RegionIds do
	local n = groupsByRegion[region] or 0
	check(region .. " pacing: one group per 900 studs of main route at least", n >= math.ceil(MAIN_ROUTE[region] / 900))
	check(region .. " pacing: no more than one group per 350 studs", n <= math.floor(MAIN_ROUTE[region] / 350))
	local share = (monks[region] or 0) / math.max(total[region] or 0, 1)
	check(region .. " archetype mix tracks its biome target", math.abs(share - E.Mix[region]) <= 0.15 and (monks[region] or 0) > 0 and (monks[region] or 0) < (total[region] or 0))
end
check("no encounters outside the five biomes", count(groupsByRegion) == #O.RegionIds)

check("every encounter spot reaches World.Spawns, once", #O.EncounterSpots == #members and (function()
	for _, s in members do
		local live = liveById[s.Id]
		if not live or live.Mob ~= s.Mob or live.Region ~= s.Region then return false end
	end
	return true
end)())

local sparring = World.spawnById(O.Training.Spawn)
local warden = O.Minibosses.HollowBellWarden
local gate = O.Barrier.Gate
local glade = O.Altars[O.Gateway].Placement
local lobby = { MinX = -300, MaxX = 300, MinZ = 190, MaxZ = 1110 } -- Workspace.Sanctuary footprint (GEOGRAPHY_PLAN clearances)

for _, s in members do
	local mob = World.Mobs[s.Mob]
	local live = liveById[s.Id]
	local tag = s.Id
	check(tag .. " is a unique spawn id", not seen[s.Id]); seen[s.Id] = true
	check(tag .. " uses an existing ordinary archetype", mob ~= nil and s.Mob ~= "HollowBellWarden" and s.Mob ~= "SparringPhantom" and World.Bosses[s.Mob] == nil and mob.Reward == nil)
	check(tag .. " lies inside its region and World agrees", World.regionAt(s.X, s.Y, s.Z) == s.Region and O.regionAt(s.X, s.Y, s.Z) == s.Region)

	-- Ground: authored Y is heightAt; the live root stands floor + 3 with floor = heightAt + 2.
	local h, _, channelW, chasmW = O.sampleAt(s.X, s.Z)
	check(tag .. " Y matches the terrain height", math.abs(s.Y - h) <= 0.5)
	check(tag .. " live root is heightAt + 5 (surface + 3), +-0.5", live ~= nil and math.abs(live.Placement.Y - (h + ROOT_ABOVE_HEIGHT)) <= 0.5)
	check(tag .. " patrol points share the root height", live ~= nil and (function() for _, p in live.Patrol do if math.abs(p.Y - live.Placement.Y) > 0.01 then return false end end return #live.Patrol == 4 end)())
	local spread = 0
	for i = 0, 7 do
		local a = i * math.pi / 4
		spread = math.max(spread, math.abs(O.heightAt(s.X + 10 * math.cos(a), s.Z + 10 * math.sin(a)) - h))
	end
	check(tag .. " stands on level, dry ground off the chasm and channels", spread <= TOLERANCE[s.Region] and h >= 8 and channelW <= 0.03 and chasmW <= 0.02)
end

-- The group's Edge is on the route graph and the group stands by its road.
for _, g in E.Groups do
	check(g.Id .. " names a real route edge", edgeExists(g.Edge))
	for _, s in g.Spawns do
		check(s.Id .. " stands within 40 studs of that edge's road", roadDistance(g.Edge, s.X, s.Z) <= 40)
	end
end

-- Leash test: enemies do not enter checkpoint or lobby radius, and never leave their region.
for _, s in members do
	local leash = World.Mobs[s.Mob].AI.LeashRange
	local reach = leash + C.Margin
	check(s.Id .. " leash disc stays inside its region", insideRegion(s.Region, s.X, s.Z) >= leash + C.Margin)
	for id, a in O.Altars do
		check(s.Id .. " leash clear of " .. id .. " rest ring", flat(s.X, s.Z, a.Placement.X, a.Placement.Z) - a.Radius > reach)
		check(s.Id .. " leash clear of " .. id .. " arrival and exit", flat(s.X, s.Z, a.Spawn.X, a.Spawn.Z) > reach and flat(s.X, s.Z, a.Exit.X, a.Exit.Z) > reach)
	end
	for id, r in O.Rings do
		check(s.Id .. " leash clear of " .. id, flat(s.X, s.Z, r.X, r.Z) - C.Ring > reach)
	end
	for id, c in O.Caches do
		check(s.Id .. " keeps off the " .. id .. " cache", flat(s.X, s.Z, c.Position.X, c.Position.Z) >= C.Cache)
	end
	for _, p in { gate.Placement, gate.Inside, gate.Outside } do
		check(s.Id .. " far from the summit barrier", flat(s.X, s.Z, p.X, p.Z) >= C.Gate)
	end
	check(s.Id .. " outside the glade safe ring", flat(s.X, s.Z, glade.X, glade.Z) >= C.Glade)
	check(s.Id .. " keeps clear of the sparring phantom and the warden", flat(s.X, s.Z, sparring.Placement.X, sparring.Placement.Z) >= C.Miniboss
		and flat(s.X, s.Z, warden.Placement.X, warden.Placement.Z) >= C.Miniboss)
	-- Lobby: nearest point of the Sanctuary footprint must be beyond the leash.
	local dx = math.max(lobby.MinX - s.X, 0, s.X - lobby.MaxX)
	local dz = math.max(lobby.MinZ - s.Z, 0, s.Z - lobby.MaxZ)
	check(s.Id .. " leash never reaches the lobby", math.sqrt(dx * dx + dz * dz) > reach)
end

-- Groups are drawn one at a time: homes of different groups sit out of each other's sight and leash.
for i, g in E.Groups do
	for j = i + 1, #E.Groups do
		local h = E.Groups[j]
		for _, a in g.Spawns do
			for _, b in h.Spawns do
				if flat(a.X, a.Z, b.X, b.Z) < C.Group then check(a.Id .. " and " .. b.Id .. " are in different groups at least " .. C.Group .. " apart", false) end
			end
		end
	end
end
check("groups keep their spacing", true)

-- Archived bosses stay inactive: no encounter spawns one, and the summit barrier is the only fog gate.
for id, boss in World.Bosses do
	if boss.Inactive then check("archived " .. id .. " is not an encounter", seen[id] == nil and (function() for _, s in members do if s.Mob == id or s.Mob == boss.Id then return false end end return true end)()) end
end

print(string.format("overworld encounters: %d groups, %d foes; %d passed, %d failed", #E.Groups, #members, passed, failed))
if failed > 0 then error("overworld encounters regression failed") end

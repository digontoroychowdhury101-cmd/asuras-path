--!nonstrict
-- Lune regression for playtest findings #25, #26, #27, #28, #32 and #44 (batch 15). Builds the
-- Desecrated Monastery offline from the real builders (tools/monastery_scene.luau) together with
-- the real LootWorld caches and NarrativeWorld memorials, models the recorded terrain, and runs a
-- character-height reachability search (2-stud cells, 5-stud body column, 6-stud jump, the truss
-- ladder) from the gate landing: the route walks both ways, every Monastery inscription and cache
-- is reachable with a clear pocket, line of sight and camera room, the exterior is the authored
-- waterfall path rather than open ground, foes stay in their zones, and the objective marker
-- follows doorways and the portal. Not covered: real terrain voxels and physics, uploaded meshes,
-- glide/double-jump arcs, and anything needing Studio play.
-- Run from the project root: lune run tools/test_monastery_discovery.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Scene = require("./monastery_scene")
local Rig = require("./rig_scene")
local Zones = require("../src/shared/MonasteryZones")
local Objectives = Rig.load("src/shared/Objectives.luau", {})
local InputMap = Rig.load("src/shared/InputMap.luau", {})
local Arsenal = require("../src/shared/ArsenalCatalog")
local Narrative = require("../src/shared/NarrativeCatalog")
local Schema = require("../src/shared/CostumeSchema")
local V3, CF, Instance = roblox.Vector3, roblox.CFrame, roblox.Instance

local passed, failed = 0, 0
local VERBOSE = (require("@lune/process").args[1] == "-v")
local function check(name: string, condition: any)
	if condition then passed += 1; if VERBOSE then print("ok   " .. name) end else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end

-- 1. Build the map, the caches and the memorials/figures.
local scene = Scene.build()
local World, G = scene.World, scene.Ground
local fakeSignal = { Connect = function() return { Disconnect = function() end } end }
roblox.implementProperty("ProximityPrompt", "Triggered", function() return fakeSignal end)
for _, class in { "Part", "TrussPart" } do -- LootWorld places by Position, which Lune does not derive from CFrame
	roblox.implementProperty(class, "Position", function(p) return p.CFrame.Position end, function(p, v) p.CFrame = CF.new(v) * p.CFrame.Rotation end)
end
local workspace = Instance.new("Folder")
local shared = { WaitForChild = function() return { Shared = { ArsenalCatalog = Arsenal, WorldDefinitions = World, InputMap = InputMap, NarrativeCatalog = Narrative,
	CostumeSchema = Schema, LooksCast = Rig.load("src/shared/LooksCast.luau", { script = { Parent = { CostumeSchema = Schema } } }) } } end }
shared.AsurasPath = shared:WaitForChild()
local game = { GetService = function(_, n) return if n == "Workspace" then workspace else shared end }
local Loot = Rig.load("src/server/Services/LootWorld.luau", { game = game })
Loot.build(function() end, function() end)
local Kit = Rig.load("src/server/Services/CostumeKit.luau", { game = game })
local Figures = Rig.load("src/server/Services/CastFigures.luau", { game = game, script = { Parent = { CostumeKit = Kit } } })
Rig.load("src/server/Services/NarrativeWorld.luau", { game = game, script = { Parent = { CastFigures = Figures } } }).build(function() end, function() end)
for _, d in workspace:GetDescendants() do -- Lune stores Part.Position without moving the part
	if d:IsA("BasePart") then pcall(function() local at = (d :: any).Position; if at then d.CFrame = CF.new(at) * d.CFrame.Rotation end end) end
end
local entries = table.clone(scene.Parts)
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(entries, { Part = d, CFrame = d.CFrame, Half = d.Size * 0.5, Visible = d.Transparency < 0.9, Collide = d.CanCollide, Name = d.Name,
			Path = d:GetFullName(), Radius = (d.Size * 0.5).Magnitude, Truss = d:IsA("TrussPart") })
	end
end
local names = {}
for _, e in entries do names[e.Name] = (names[e.Name] or 0) + 1 end

-- 2. Architecture vocabulary (#32) and route pockets (#25).
check("no Roman voussoir arch remains", names.Voussoir == nil and names.Stringer == 3 and names.Trestle == 2 and names.Cutwater == 4)
local under = true
for _, e in entries do
	if e.Name == "Stringer" or e.Name == "PierCap" or e.Name == "Trestle" or e.Name == "Cutwater" then
		for _, sy in { -1, 1 } do if (e.CFrame * CF.new(0, e.Half.Y * sy, 0)).Position.Y > G - 1.5 then under = false end end
	end
end
check("bridge structure sits under the deck surface", under)
check("bridge gateway, lions and lotus caps give the crossing a silhouette", names.GatePost == 2 and names.LionBody == 2 and (names.LotusCap or 0) >= 20)
local pocket = {}
for _, e in entries do if string.find(e.Path, "RoutePockets", 1, true) then pocket[e.Name] = (pocket[e.Name] or 0) + 1 end end
check("each stop has its own set piece", names.CloudPillar == 2 and names.LanternShaft == 2 and pocket.Table == 1 and pocket.Bowl == 7 and pocket.Stele == 6 and names.Curb == 2 and names.TowerPost == 4)

-- Spatial hash over solid parts for column queries.
local CELL = 8
local buckets = {}
local function key(i, j) return i * 100000 + j end
for _, e in entries do
	local lo, hi = V3.new(math.huge, 0, math.huge), V3.new(-math.huge, 0, -math.huge)
	for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
		local p = (e.CFrame * CF.new(e.Half.X * sx, e.Half.Y * sy, e.Half.Z * sz)).Position
		lo, hi = V3.new(math.min(lo.X, p.X), 0, math.min(lo.Z, p.Z)), V3.new(math.max(hi.X, p.X), 0, math.max(hi.Z, p.Z))
	end end end
	if e.Collide then
		for i = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do for j = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
			local k = key(i, j); buckets[k] = buckets[k] or {}; table.insert(buckets[k], e)
		end end
	end
end
local function near(x, z) return buckets[key(math.floor(x / CELL), math.floor(z / CELL))] or {} end
local function solidAt(p) for _, e in near(p.X, p.Z) do if Scene.inside(e, p) then return e end end return nil end

-- Terrain from the recorded fills: floor at -0.2 inside Ground blocks, solid Rock/Slate balls,
-- Air balls (ravine) and blocks (the pass) carving them.
local fills = {}
for _, f in scene.Terrain do
	local cx, cz, r = 0, 0, 0
	if f.Kind == "Ball" then cx, cz, r = f.Center.X, f.Center.Z, f.Radius else cx, cz, r = f.CFrame.Position.X, f.CFrame.Position.Z, math.max(f.Size.X, f.Size.Z) / 2 end
	for i = math.floor((cx - r) / 16), math.floor((cx + r) / 16) do for j = math.floor((cz - r) / 16), math.floor((cz + r) / 16) do
		local k = key(i, j); fills[k] = fills[k] or {}; table.insert(fills[k], f)
	end end
end
local function terrainTop(x, z)
	local top, carved = nil, false
	for _, f in fills[key(math.floor(x / 16), math.floor(z / 16))] or {} do
		if f.Kind == "Block" and f.Material == "Ground" then
			local c, s = f.CFrame.Position, f.Size
			if math.abs(x - c.X) <= s.X / 2 and math.abs(z - c.Z) <= s.Z / 2 then top = math.max(top or -math.huge, c.Y + s.Y / 2 + 2) end
		elseif f.Kind == "Ball" then
			local d = math.sqrt((x - f.Center.X) ^ 2 + (z - f.Center.Z) ^ 2)
			if d < f.Radius then
				local h = math.sqrt(f.Radius ^ 2 - d ^ 2)
				if f.Material == "Air" then
					if f.Center.Y - h < 0.5 then carved = true; top = math.min(top or 0, f.Center.Y - h) end
				else
					top = math.max(top or -math.huge, f.Center.Y + h)
				end
			end
		end
	end
	return top, carved
end

-- 3. Character-height reachability (2-stud cells; floors are part tops and the terrain surface).
local STEP, JUMP, BODY = 2, 6, 5
local floors = {}
local function cellKey(i, j) return i * 10000 + j end
local function standable(x, y, z)
	for _, dx in { -0.8, 0, 0.8 } do for _, dz in { -0.8, 0, 0.8 } do
		for h = 0.6, BODY, 1.1 do if solidAt(V3.new(x + dx, y + h, z + dz)) then return false end end
	end end
	return true
end
local X0, X1, Z0, Z1 = -184, 184, -660, -1124
for i = X0 / STEP, X1 / STEP do
	for j = Z1 / STEP, Z0 / STEP do
		local x, z = i * STEP + 0.37, j * STEP + 0.37 -- off the 2-stud lattice so slab seams are not sampled
		local list = {}
		local ground, carved = terrainTop(x, z)
		if ground and not carved and standable(x, ground, z) then table.insert(list, ground) end
		for _, e in near(x, z) do
			local t = Scene.segmentBox(e, V3.new(x, 80, z), V3.new(x, -40, z))
			if t then
				local y = 80 - 120 * t
				if y > -5 and standable(x, y, z) then table.insert(list, y) end
			end
		end
		if #list > 0 then floors[cellKey(i, j)] = list end
	end
end
local trusses = {}
for _, e in entries do if e.Truss then table.insert(trusses, e) end end
local function search(fromX, fromZ)
	local seen, queue = {}, {}
	local function push(i, j, y) local k = cellKey(i, j) .. ":" .. math.floor(y * 4); if not seen[k] then seen[k] = { I = i, J = j, Y = y }; table.insert(queue, seen[k]) end end
	local si, sj = math.round(fromX / STEP), math.round(fromZ / STEP)
	for _, y in floors[cellKey(si, sj)] or {} do if y < 6 then push(si, sj, y) end end
	local head = 1
	while head <= #queue do
		local n = queue[head]; head += 1
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			for _, y in floors[cellKey(n.I + d[1], n.J + d[2])] or {} do
				if y - n.Y <= JUMP and n.Y - y <= 40 then push(n.I + d[1], n.J + d[2], y) end
			end
		end
		for _, t in trusses do -- climb a ladder from its foot to the floor at its top
			local p = t.CFrame.Position
			if math.abs(n.I * STEP - p.X) <= 2.5 and math.abs(n.J * STEP - p.Z) <= 2.5 and math.abs(n.Y - (p.Y - t.Half.Y)) < 1.5 then
				for di = -3, 3 do for dj = -3, 3 do
					for _, y in floors[cellKey(n.I + di, n.J + dj)] or {} do if math.abs(y - (p.Y + t.Half.Y)) < 1.2 then push(n.I + di, n.J + dj, y) end end
				end end
			end
		end
	end
	return seen
end
local gate, cloister = World.Altars.Altar_MonasteryGate, World.Altars.Altar_DesecratedCloister
local forward = search(gate.Spawn.X, gate.Spawn.Z - 4)
local back = search(cloister.Spawn.X, cloister.Spawn.Z)
local function reached(set, x, z, radius, low)
	for _, n in set do
		if (n.I * STEP - x) ^ 2 + (n.J * STEP - z) ^ 2 <= radius * radius and (not low or n.Y < low) then return n end
	end
	return nil
end
check("gate -> courtyard -> bridge -> cloister walks on foot", reached(forward, cloister.Placement.X, cloister.Placement.Z, 6, 6) ~= nil)
check("cloister -> gate walks back the same way", reached(back, gate.Placement.X, gate.Placement.Z, 6, 6) ~= nil)
for _, door in Zones.Doors do
	if door.B ~= "EastPass" then check("doorway '" .. door.Name .. "' stands on walkable ground", reached(forward, door.X, door.Z, 4, 6) ~= nil) end
end

-- 4. Every Monastery inscription and cache (#44): reachable pocket, line of sight, camera room.
local function partNamed(name) for _, e in entries do if e.Name == name and e.Part:FindFirstChildOfClass("ProximityPrompt") then return e end end return nil end
local targets = {}
for id, l in Narrative.Lore do if l.Region == "DesecratedMonastery" then table.insert(targets, { Id = id, Range = 12 }) end end
for id, c in Arsenal.Caches do if c.Region == "DesecratedMonastery" then table.insert(targets, { Id = id, Range = 9 }) end end
check("four inscriptions and three caches in the Monastery", #targets == 7)
for _, target in targets do
	local e = partNamed(target.Id)
	local spots, seen, room = 0, 0, 0
	if e then
		local at = e.CFrame.Position
		for _, n in forward do
			local foot = V3.new(n.I * STEP, n.Y, n.J * STEP)
			local eye = foot + V3.new(0, 4.5, 0)
			if (eye - at).Magnitude <= target.Range - 0.5 then
				spots += 1
				local blocker = Scene.cast({ Parts = near(eye.X, eye.Z) }, eye, at, function(x) return x.Collide and x.Part ~= e.Part and x.Part.Parent ~= e.Part.Parent end)
				if not blocker then
					seen += 1
					local flatAway = V3.new(eye.X - at.X, 0, eye.Z - at.Z)
					local cam = eye + (if flatAway.Magnitude > 0.1 then flatAway.Unit else V3.zAxis) * 8 + V3.new(0, 2, 0)
					if not Scene.cast({ Parts = near(cam.X, cam.Z) }, eye, cam, Scene.solid) and not solidAt(cam) then room += 1 end
				end
			end
		end
	end
	check(string.format("%s reachable with a standing pocket (%d spots), in sight (%d), with camera room (%d)", target.Id, spots, seen, room), e and spots >= 6 and seen >= 4 and room >= 2)
end
local tower = nil
for _, e in entries do if e.Name == "HiddenRafterLadder" and e.CFrame.Position.Z < -990 then tower = e end end
local ledge = partNamed("PagodaRafters")
check("rafter ladder stands outside the loft floor and ends at its top", tower and math.abs(tower.CFrame.Position.Z - (ledge.CFrame.Position.Z - 5)) < 0.01
	and math.abs(tower.CFrame.Position.Y + tower.Half.Y - (ledge.CFrame.Position.Y - 1)) < 0.05)
check("first discovery stays on the arrival walk (batch 10)", Narrative.LoreOrder[1] == "Pillars" and Narrative.Lore.Pillars.Z > -752)

-- 5. The exterior (#26, #27): the waterfall path is the way; elsewhere outside the walls is scree.
local loose, pathCells, outside = 0, 0, 0
for _, n in forward do
	local x, z = n.I * STEP, n.J * STEP
	if n.Y < 2 and (x < -84 or x > 84) and z > -930 and z < -700 and not Zones.contains(Zones.get("Halls"), x, z) then
		outside += 1
		local onPath = Zones.distanceToPath(Zones.WestPath, x, z) <= 12 or (V3.new(x, 0, z) - V3.new(Zones.Alcove.X, 0, Zones.Alcove.Z)).Magnitude <= 14
		local onRoad = math.abs(z + 811) <= 16 and x > 0
		local yard = scene.Modules.MonasteryTerrain.SPARRING_YARD -- batch 24: the sparring ring's yard is authored ground
		if math.sqrt((x - yard.X) ^ 2 + (z - yard.Z) ^ 2) <= yard.Clear + 2 then onPath = true end
		for _, zone in Zones.List do -- the stud or two of footing along a walked zone's edge
			if zone.Id ~= "WestReach" and zone.Id ~= "EastPass" and Zones.contains(zone, x, z, 4) then onRoad = true end
		end
		if onPath or onRoad then pathCells += 1 else loose += 1 end
	end
end
check(string.format("ground outside the walls is the authored path or the pass road (%d loose of %d)", loose, outside), pathCells > 40 and loose <= outside * 0.05)
-- Batch 24: the Gatehouse sparring ring (ColosseumService Ring_GatehouseCircle, centre -130,-745,
-- apothem 16, threshold band 6) stays reachable and its octagon free of Monastery solids.
local ringBlocked = 0
for _, e in entries do
	local c = e.CFrame.Position
	if e.Collide and (c.X + 130) ^ 2 + (c.Z + 745) ^ 2 < 18 ^ 2 and c.Y + e.Half.Y > 1 and c.Y - e.Half.Y < 8 then ringBlocked += 1 end
end
local buried = 0
for _, at in { { 0, 0 }, { 20, 0 }, { -20, 0 }, { 0, 20 }, { 0, -20 }, { 16, 16 }, { -16, 16 }, { 16, -16 }, { -16, -16 } } do
	local top = terrainTop(-130 + at[1], -745 + at[2])
	if top and top > 1 then buried += 1 end
end
check(string.format("the gatehouse sparring ring is reachable on foot at ground level, clear of solids (%d) and terrain (%d)", ringBlocked, buried),
	reached(forward, -130, -745 - 19, 4, 3) ~= nil and ringBlocked == 0 and buried == 0)
check("the secret path rejoins through the west hall", reached(forward, -96, -880, 3, 6) ~= nil and reached(search(-100, -880), Zones.Alcove.X, Zones.Alcove.Z, 9, 6) ~= nil)
for spawnId, zoneId in Zones.Spawns do
	local spawn
	for _, s in World.Spawns do if s.Id == spawnId then spawn = s end end
	local zone = Zones.get(zoneId)
	local inside = spawn ~= nil and Zones.contains(zone, spawn.Placement.X, spawn.Placement.Z)
	for _, p in (spawn and spawn.Patrol) or {} do inside = inside and Zones.contains(zone, p.X, p.Z) end
	check(spawnId .. " patrols inside its fighting zone " .. zoneId, inside)
	local free, total = 0, 0
	for dx = -8, 8, 2 do for dz = -8, 8, 2 do
		if dx * dx + dz * dz <= 64 then
			total += 1
			if reached(forward, spawn.Placement.X + dx, spawn.Placement.Z + dz, 1, 6) then free += 1 end
		end
	end end
	check(string.format("%s fights in an open pocket (%d/%d cells)", spawnId, free, total), free >= total * 0.75)
end
check("no Monastery foe leaves its zone or wakes for a target beyond it", string.find(src("src/server/Services/AIService.luau"), "homeDistance > profile.LeashRange or fled", 1, true)
	and string.find(src("src/server/Services/AIService.luau"), "noticed from beyond the zone", 1, true))
check("the safe landing belongs to no hostile zone", (function() for _, z in Zones.Spawns do if z == "Landing" then return false end end return true end)())

-- 6. Wayfinding (#28): doorways on the walked route, the portal first across the separation.
local Guide = Rig.load("src/shared/RouteGuide.luau", { script = { Parent = { MonasteryZones = Zones, WorldDefinitions = World,
	CampaignZones = require("../src/shared/CampaignZones"), SanctuaryRoutes = require("../src/shared/SanctuaryRoutes") } } }) -- batches 16-21
local stages, cursor = {}, V3.new(gate.Placement.X, 3, gate.Placement.Z)
local goal = V3.new(cloister.Placement.X, 3, cloister.Placement.Z)
for _ = 1, 8 do
	local s = Guide.next(cursor, goal)
	table.insert(stages, s.Label or "goal")
	if not s.Label then break end
	local door = s.Position
	local zoneHere = Zones.at(cursor.X, cursor.Z)
	local nudge = (door - cursor).Unit * 2 -- step through the doorway into the next zone
	cursor = door + V3.new(nudge.X, 0, nudge.Z)
	if Zones.at(cursor.X, cursor.Z) == zoneHere then cursor = door + V3.new(nudge.X, 0, nudge.Z) * 2 end
end
check("gate to cloister marker: " .. table.concat(stages, " > "), table.concat(stages, ",") == "Gatehouse,Processional path,Bridge,Far bridgehead,Cloister gateway,goal")
local first = Guide.next(V3.new(gate.Placement.X, 3, gate.Placement.Z), goal)
check("distance is walked through the doorways, not straight through walls", first.Remaining > (goal - V3.new(gate.Placement.X, 3, gate.Placement.Z)).Magnitude)
local sanctuary = World.startingAltar()
local stain = V3.new(0, 3, -960)
check("a bloodstain beyond the portal points at the northern gate first", Guide.next(V3.new(sanctuary.Placement.X, sanctuary.Placement.Y, sanctuary.Placement.Z), stain).Kind == "Portal")
local function sameZone(p, q)
	for _, z in Zones.List do
		if Zones.contains(z, p.X, p.Z, 3) and Zones.contains(z, q.X, q.Z, 3) then return true end
	end
	return false
end
for _, case in { { gate.Placement, cloister.Placement }, { cloister.Placement, gate.Placement }, { { X = -120, Z = -832 }, { X = 60, Z = -1010 } } } do
	local from, to = V3.new(case[1].X, 3, case[1].Z), V3.new(case[2].X, 3, case[2].Z)
	local cursor, inside = from, true
	for _, point in Guide.next(from, to).Route.Points do
		inside = inside and sameZone(cursor, point)
		cursor = point
	end
	check(string.format("minimap route (%d,%d)->(%d,%d) never crosses a wall", from.X, from.Z, to.X, to.Z), inside and cursor == to)
end
-- Studio F14: the toppled pagoda stands in the grave field; the line to the mausoleum follows the
-- authored grave path instead of crossing it, and never strays more than 3 studs from that path.
do
	local s = Guide.next(V3.new(0, 3, -1040), V3.new(-108, 3, -1064))
	local cursor, onPath, used = V3.new(0, 3, -1040), true, false
	for i, point in s.Route.Points do
		if used then -- segments leaving a grave-path vertex
			for t = 0.1, 0.9, 0.2 do
				local x, z = cursor.X + (point.X - cursor.X) * t, cursor.Z + (point.Z - cursor.Z) * t
				if Zones.distanceToPath(Zones.GravePath, x, z) > 3 and (V3.new(x, 3, z) - V3.new(-108, 3, -1064)).Magnitude > 6 then onPath = false end
			end
		end
		cursor = point
		used = s.Route.Names[i] == "Grave path"
	end
	check("mausoleum route follows the grave path past the toppled pagoda", onPath and table.find(s.Route.Names, "Grave path") ~= nil)
end
check("the northern gate route draws nothing past the portal", Guide.next(V3.new(sanctuary.Placement.X, sanctuary.Placement.Y, sanctuary.Placement.Z), stain).Route.Exit == "Northern gate")
check("from the waterfall path the marker leads back through the postern", Guide.next(V3.new(-120, 3, -832), V3.new(0, 3, -800)).Label == "West postern")
local o = Objectives.resolve({ Region = "Sanctuary", Altars = {}, Bloodstain = stain, StainRegion = "DesecratedMonastery", InBoss = false, InColosseum = false, BossFelled = false, Rested = true })
check("bloodstain objective says to take the gate first", o and string.find(o.Detail, "northern gate first", 1, true) ~= nil)
check("marker shows the stage name and walked distance", string.find(src("src/client/Controllers/WaypointMarker.luau"), '"%s · %dm"', 1, true)
	and string.find(src("src/client/Controllers/ObjectiveController.luau"), "RouteGuide.next(root.Position, goal)", 1, true))
for _, name in { "MonasteryPockets", "MonasterySecrets" } do
	local text = src("src/server/Services/" .. name .. ".luau")
	local _, lines = string.gsub(text, "\n", "")
	check(name .. " strict, under 150 lines and registered", string.sub(text, 1, 9) == "--!strict" and lines < 150 and string.find(src("default.project.json"), name .. ".luau", 1, true))
end

print(string.format("monastery discovery: %d passed, %d failed", passed, failed))
if failed > 0 then error("monastery discovery regression failed") end

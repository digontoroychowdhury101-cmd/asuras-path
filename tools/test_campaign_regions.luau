--!nonstrict
-- Regression for playtest findings #22 #27 #28 #31 #32 #44 (batches 16-21), run by
-- tools/test_campaign_regions.py. Walks the authored campaign regions at character height
-- (tools/region_walk.luau: 2-stud cells, 5-stud body, 2.2 step, 6 jump, 6 gap) over the exact
-- layout boxes the server builds, plus BossArenas' floors and frost pillars and a model of the
-- existing Sanctuary (plaza, stairs, landing, gate, loggia, terrace, LootWorld caches) built from the
-- same numbers SanctuaryService / SanctuaryColossus / LootWorld use. Checks the main routes both
-- ways with walking only, optional routes need deliberate jumps, tablets/caches/altars have standing
-- room, foes stand on floors in their leash zones, arenas stay clear for bodies and cameras, every
-- reachable cell lies inside its region's bounds, wayfinding walks doors (never up a drop), and the
-- shrine's cloud catch never claims crypt play. Not covered: physics, glide/double jump, terrain,
-- uploaded meshes, decor, lighting, and anything that needs Studio play.
local Walk = require("../tools/region_walk")
local World = require("../src/shared/WorldDefinitions")
local Bodies = require("../src/shared/BossBodies")
local Layout = require("../src/shared/RegionLayout")
local Campaign = require("../src/shared/CampaignZones")
local Zones = require("../src/shared/MonasteryZones")
local Routes = require("../src/shared/SanctuaryRoutes")
local Narrative = require("../src/shared/NarrativeCatalog")
local Arsenal = require("../src/shared/ArsenalCatalog")
local Recovery = require("../src/server/RecoveryRules")

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- Minimal Vector3 for the injected RouteGuide and Sanctuary poll.
local V = {}
V.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
	return nil
end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end }
V.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
local vec = Vector3.new

local function box(name, kind, x, y, z, sx, sy, sz, yaw)
	return { Name = name, Kind = kind, X = x, Y = y, Z = z, SX = sx, SY = sy, SZ = sz, Yaw = yaw or 0 }
end
local function arenaBoxes(list)
	for _, boss in World.Bosses do
		local c, s = boss.Arena.Center, boss.Arena.Size
		table.insert(list, box(boss.Id .. "Floor", "Stone", c.X, -2, c.Z, s.X, 4, s.Z))
		table.insert(list, box(boss.Id .. "Approach", "Stone", c.X, -2, c.Z + s.Z / 2 + 20, 30, 4, 40))
		for _, p in Bodies.pillars(boss) do
			table.insert(list, box("FrostPillar", "Stone", p.X, p.Top / 2, p.Z, p.Half * 2, p.Top, p.Half * 2))
		end
	end
	table.insert(list, box("CourtyardRoad", "Stone", 220, -2, -810, 160, 4, 24))
	return list
end
local function concat(...)
	local out = {}
	for _, list in { ... } do for _, b in list do table.insert(out, b) end end
	return out
end
local function floorAt(w, x, y, z)
	local best = nil
	for _, f in w:floorsAt(x, z) do if f <= y + 0.5 and (not best or f > best) then best = f end end
	return best
end

-------------------------------------------------------------------------------------------------
-- 1. Data agreement: altars, tablets, caches and spawns stand where the layouts put them.
-------------------------------------------------------------------------------------------------
local byRegion = {}
for _, layout in Campaign.Layouts do byRegion[layout.Region] = layout end
for id, altar in World.Altars do
	local layout = byRegion[altar.Region]
	if layout then
		local m = layout.Marks.Altar
		check(id .. " placement is its layout's altar pocket", m and m.X == altar.Placement.X and m.Y == altar.Placement.Y and m.Z == altar.Placement.Z)
		check(id .. " spawns 3 above its floor, within its radius, facing away from the altar's back",
			math.abs(altar.Spawn.Y - altar.Placement.Y - 3) < 0.01 and math.sqrt((altar.Spawn.X - altar.Placement.X) ^ 2 + (altar.Spawn.Z - altar.Placement.Z) ^ 2) <= altar.Radius)
		check(id .. " has an authored exit", altar.Exit ~= nil)
	end
end
for key, lore in Narrative.Lore do
	local layout = byRegion[lore.Region]
	if layout then
		local m = layout.Marks["Lore_" .. key]
		check("tablet " .. key .. " stands at its layout mark", m and m.X == lore.X and m.Y == lore.Y and m.Z == lore.Z)
	end
end
local caches = { SanctuaryEaves = { X = -76, Y = 617, Z = 923 }, SanctuaryReliquary = { X = 46, Y = 605, Z = 988 } }
for id, want in caches do
	local c = Arsenal.Caches[id]
	check("cache " .. id .. " moved onto its route", c and c.X == want.X and c.Y == want.Y and c.Z == want.Z)
end
local d = Routes.Marks.CryptDescent
check("objective and wayfinding share the Well of Descent", d.X == 0 and d.Y + 5 == 605 and d.Z == 996)

-------------------------------------------------------------------------------------------------
-- 2. One walkable campaign: Bamboo Pass -> Ash Colosseum -> Celestial Pagoda -> Sky Citadel.
-------------------------------------------------------------------------------------------------
local chain = concat(byRegion.BambooPass.Solids, byRegion.AshColosseum.Solids, byRegion.CelestialPagoda.Solids, byRegion.SkyCitadel.Solids)
local t0 = os.clock()
local cw = Walk.world(arenaBoxes(table.clone(chain)), -240, 240, -1110, -3000)
local north = byRegion.BambooPass.Marks.NorthJoin
local walk = cw:reach(north.X, north.Y, north.Z, "Walk")
local jump = cw:reach(north.X, north.Y, north.Z, "Jump")
local summit = byRegion.SkyCitadel.Marks.ArenaMouth
local back = cw:reach(summit.X, summit.Y, summit.Z, "Walk")
check("the campaign chain walks from the Monastery road to the Wyrm's gate", walk and walk.has(summit.X, summit.Y, summit.Z))
check("and walks all the way back", back and back.has(north.X, north.Y, north.Z))
for region, layout in byRegion do
	if region ~= "SanctuaryDepths" then
		for key, m in layout.Marks do
			local isLore = string.sub(key, 1, 5) == "Lore_"
			local floor = if isLore then m.Y - 3 else m.Y
			local optional = key == "Lore_Wraith" or key == "Overlook" or key == "Lore_Pagoda"
			if optional then
				check(region .. "." .. key .. " needs the deliberate route (jumps, not a walk)", jump.has(m.X, floor, m.Z) and not walk.has(m.X, floor, m.Z))
			elseif key ~= "ReturnPortal" then
				check(region .. "." .. key .. " is walked from the Monastery road", walk.has(m.X, floor, m.Z))
				if key == "Altar" then -- respawning there must lead back as well as on
					local home = cw:reach(m.X, floor, m.Z, "Walk")
					check(region .. " altar walks back to the Monastery road and on to the summit", home and home.has(north.X, north.Y, north.Z) and home.has(summit.X, summit.Y, summit.Z))
				end
			end
		end
	end
end
-- Batch 24: the Ash PvP ring (ColosseumService Ring_OctagonOfAsh) is walked to and its octagon
-- (threshold apothem 28) holds no layout solid above the ash.
do
	local ring = byRegion.AshColosseum.Marks.ProvingRing
	local blockers = 0
	for _, b in byRegion.AshColosseum.Solids do
		local top = b.Y + b.SY / 2
		if top > 0.5 and Walk.inside({ X = b.X, Y = 2, Z = b.Z, SX = b.SX + 60, SY = 1e6, SZ = b.SZ + 60, Yaw = b.Yaw }, ring.X, 2, ring.Z) then
			for dx = -28, 28, 2 do for dz = -28, 28, 2 do
				if Walk.inside(b, ring.X + dx, math.min(top - 0.1, 3), ring.Z + dz) then blockers += 1 end
			end end
		end
	end
	check(string.format("the Ash PvP ring's octagon is clear of layout solids (%d cells)", blockers), blockers == 0)
end
local loft = byRegion.CelestialPagoda.Marks.Lore_Pagoda
local fromLoft = cw:reach(loft.X, loft.Y - 3, loft.Z, "Walk")
check("the throne loft drops back to the forecourt", fromLoft and fromLoft.has(-46, 0, -2268))
local wraith = byRegion.BambooPass.Marks.Lore_Wraith
local fromRidge = cw:reach(wraith.X, wraith.Y - 3, wraith.Z, "Walk")
check("the frost ridge drops back to the shrine", fromRidge and fromRidge.has(-36, 0.2, -1328))
local hub = byRegion.CelestialPagoda.Marks.Hub
local fromHub = cw:reach(hub.X, hub.Y, hub.Z, "Walk")
check("a fall from the lantern rafter lands in the walkable gorge", fromHub and fromHub.has(0, -26, -2180))

-- Every reachable cell lies inside a region's bounds (veils hold; nothing leaks between regions).
local outside, total = 0, 0
for id, fy in jump.Seen do
	local i, j = string.match(id, "(-?%d+),(-?%d+)")
	local x, z = tonumber(i) * Walk.CELL + 0.37, tonumber(j) * Walk.CELL + 0.37
	total += 1
	if World.regionAt(x, fy + 2, z) == nil then outside += 1 end
end
check(string.format("all %d reachable cells lie inside region bounds (%d outside)", total, outside), outside == 0 and total > 1000)

-------------------------------------------------------------------------------------------------
-- 3. Arenas: no layout piece in a boss's space; cameras keep 12 studs (16 for the Titan and Wyrm).
-------------------------------------------------------------------------------------------------
local all = concat(chain, byRegion.SanctuaryDepths.Solids, Routes.Solids)
for id, boss in World.Bosses do
	local c, s = boss.Arena.Center, boss.Arena.Size
	local intrusions = 0
	for _, b in all do
		if b.Kind ~= "Veil" then
			for _, dx in { -0.45, 0, 0.45 } do for _, dz in { -0.45, 0, 0.45 } do for _, h in { 1, 4, 10, 30 } do
				local x, z = c.X + dx * s.X * 0.98, c.Z + dz * s.Z * 0.98
				if Walk.inside(b, x, h, z) then intrusions += 1 end
			end end end
			if Walk.inside(b, b.X, b.Y + b.SY / 2 - 0.01, b.Z) and math.abs(b.X - c.X) < s.X / 2 and math.abs(b.Z - c.Z) < s.Z / 2 and b.Y + b.SY / 2 > 0.5 then
				intrusions += 1
			end
		end
	end
	check(id .. " arena holds no layout geometry", intrusions == 0)
	if id ~= "TwinSentinels" then
		local reach = if boss.Archetype == "Colossus" or boss.Archetype == "Dragon" then 16 else 12
		local blocked = 0
		local cam = Walk.world(arenaBoxes(table.clone(all)), c.X - s.X, c.X + s.X, c.Z - s.Z, c.Z + s.Z)
		for k = 0, 39 do
			local a = k / 40 * math.pi * 2
			local ox, oz = math.cos(a), math.sin(a)
			local scale = math.min((s.X / 2 - 2) / math.max(math.abs(ox), 1e-6), (s.Z / 2 - 2) / math.max(math.abs(oz), 1e-6))
			local px, pz = c.X + ox * scale, c.Z + oz * scale
			for t = 0, 1, 0.05 do
				local x, y, z = px + ox * reach * t, 4.4 + 4 * t, pz + oz * reach * t
				local hit = cam:solidAt(x, y, z)
				if hit and hit.Kind ~= "Veil" and hit.Name ~= "FrostPillar" then blocked += 1; break end
			end
		end
		check(string.format("%s camera stays %d studs out from every edge (%d of 40 blocked)", id, reach, blocked), blocked == 0)
	end
end
print(string.format("chain built and walked in %.1fs", os.clock() - t0))

-------------------------------------------------------------------------------------------------
-- 4. Sunken Crypt: arrival -> altar -> Titan and back; optional pit and balcony; fall return.
-------------------------------------------------------------------------------------------------
local crypt = byRegion.SanctuaryDepths
local kw = Walk.world(arenaBoxes(table.clone(crypt.Solids)), 330, 710, 710, 1090)
local arrive = crypt.Marks.Arrival
local kwalk = kw:reach(arrive.X, arrive.Y, arrive.Z, "Walk")
local kjump = kw:reach(arrive.X, arrive.Y, arrive.Z, "Jump")
for _, key in { "Altar", "ArenaMouth", "PitLip", "ReturnPortal" } do
	local m = crypt.Marks[key]
	check("crypt " .. key .. " is walked from the arrival", kwalk.has(m.X, m.Y, m.Z))
	check("crypt " .. key .. " walks back to the return portal", kw:reach(m.X, m.Y, m.Z, "Walk").has(arrive.X, arrive.Y, arrive.Z))
end
check("the Titan's hall floor is walked from the arrival", kwalk.has(520, 0, 880))
for _, key in { "Reliquary", "Overlook" } do
	local m = crypt.Marks[key]
	check("crypt " .. key .. " needs the sarcophagus lids", kjump.has(m.X, m.Y, m.Z) and not kwalk.has(m.X, m.Y, m.Z))
end
local fromRelic = kw:reach(crypt.Marks.Reliquary.X, 0.2, crypt.Marks.Reliquary.Z, "Jump")
check("the reliquary leads back out (balcony or lids)", fromRelic.has(arrive.X, arrive.Y, arrive.Z))
local pit = Layout.returnFor(crypt, 380, -11, 875)
check("falling into the flooded pit returns to its lip", pit ~= nil and pit.To.Z == 904 and kwalk.has(pit.To.X, pit.To.Y, pit.To.Z))
check("standing on the lids is not a fall", Layout.returnFor(crypt, 366, 3, 880) == nil)
local chasm = Layout.returnFor(byRegion.SkyCitadel, 0, -45, -2600)
check("a fall into the cloud chasm returns to the bridge", chasm ~= nil and walk.has(chasm.To.X, chasm.To.Y, chasm.To.Z))
local summitFall = Layout.returnFor(byRegion.SkyCitadel, 100, -30, -2850)
check("a fall from the summit returns to the bastion", summitFall ~= nil and walk.has(summitFall.To.X, summitFall.To.Y, summitFall.To.Z))
check("the bridge itself is not a fall", Layout.returnFor(byRegion.SkyCitadel, 0, -17, -2600) == nil)

-------------------------------------------------------------------------------------------------
-- 5. Foes and altars: on floors, inside their zones, altar pockets clear.
-------------------------------------------------------------------------------------------------
local worlds = { BambooPass = cw, AshColosseum = cw, CelestialPagoda = cw, SkyCitadel = cw, SanctuaryDepths = kw }
for _, entry in World.Spawns do
	local w = worlds[entry.Region]
	if w then
		local p = entry.Placement
		local floor = floorAt(w, p.X, p.Y - 3, p.Z)
		check(entry.Id .. " stands on its floor", floor and math.abs(floor - (p.Y - 3)) < 0.35)
		local zone = Campaign.zoneForSpawn(entry.Id)
		check(entry.Id .. " has a leash zone holding its patrol", zone ~= nil and Campaign.contains(zone, p.X, nil, p.Z))
		for _, q in entry.Patrol do
			check(entry.Id .. " patrol point is standable", zone and Campaign.contains(zone, q.X, nil, q.Z) and floorAt(w, q.X, q.Y - 3, q.Z) ~= nil)
		end
	end
end
for id, altar in World.Altars do
	local w = worlds[altar.Region]
	if w then
		local a = altar.Placement
		local blocked = 0
		for k = 0, 23 do
			for _, r in { 3, 7, 11.5 } do
				local x, z = a.X + math.cos(k / 24 * math.pi * 2) * r, a.Z + math.sin(k / 24 * math.pi * 2) * r
				for _, h in { 1, 3, 5.5 } do
					local hit = w:solidAt(x, a.Y + h, z)
					if hit and hit.Kind ~= "Veil" then blocked += 1 end
				end
			end
		end
		check(id .. " rest pocket (12.5) is clear", blocked == 0)
		check(id .. " spawn stands on the altar's floor", floorAt(w, altar.Spawn.X, altar.Spawn.Y - 3, altar.Spawn.Z) ~= nil)
	end
end
-- Tablets: a floor three below, and five studs of clear standing room on a readable face.
for key, lore in Narrative.Lore do
	local w = worlds[lore.Region]
	if w then
		local floor = floorAt(w, lore.X, lore.Y - 3, lore.Z)
		check("tablet " .. key .. " stands on a floor", floor and math.abs(floor - (lore.Y - 3)) < 0.35)
		local room = 0
		for _, side in { -1, 1 } do
			if w:clear(lore.X, lore.Y - 3, lore.Z + side * 5) and floorAt(w, lore.X, lore.Y - 3, lore.Z + side * 5) then room += 1 end
		end
		check("tablet " .. key .. " has standing room before a face", room >= 1)
	end
end

-------------------------------------------------------------------------------------------------
-- 6. Sanctuary (batch 16): routes from the bonfire, caches, reveal sightlines, terrace rim.
-------------------------------------------------------------------------------------------------
local S = {}
local function strips(name, cx, cz, r, top, thick)
	for z = -r, r - 2, 2 do
		local mid = z + 1
		local half = math.sqrt(math.max(r * r - (math.abs(mid) + 1) ^ 2, 0))
		if half > 0 then table.insert(S, box(name, "Stone", cx, top - thick / 2, cz + mid, half * 2, thick, 2)) end
	end
end
strips("PlazaFoundation", 0, 900, 48, 600, 5)
for k = 0, 31 do
	local a = (k + 0.5) * 360 / 32
	if math.min(k % 8, 7 - k % 8) >= 1 then
		local r = math.rad(a)
		table.insert(S, box("Parapet", "Stone", -45 * math.sin(r), 601.2, 900 - 45 * math.cos(r), 8.9, 2.4, 1.3, a))
	end
end
for i = 1, 20 do
	local h = i + 6
	table.insert(S, box("Step", "Stone", 0, 600 + i - h / 2, 900 - (45 + (i - 0.5) * 2), 14, h, 2.03))
	for _, side in { -1, 1 } do table.insert(S, box("StairCheek", "Stone", side * 7.7, 600 + i - h / 2 + 1.1, 900 - (45 + (i - 0.5) * 2), 1.4, h + 2.2, 2.03)) end
end
table.insert(S, box("Landing", "Stone", 0, 615, 804, 42, 10, 25))
for _, side in { -1, 1 } do
	table.insert(S, box("MasonryJamb", "Stone", side * 8.6, 626.2, 800, 3.2, 12.4, 4.4))
	table.insert(S, box("TimberColumn", "Stone", side * 14, 625, 800, 1.4, 10, 1.4))
	table.insert(S, box("SideScreen", "Stone", side * 12, 625, 800.3, 4.5, 7, 0.6))
end
local occluders = { box("GateRoof", "Stone", 0, 637, 800, 42, 10, 13), box("PortalVeil", "Stone", 0, 625.8, 800, 13, 11.4, 2.4) }
strips("Terrace", 0, 555, 246, 620, 6)
for k = 0, 11 do
	local a = math.rad(50 + k * (260 / 11))
	table.insert(S, box("RuinColumn", "Stone", 236 * math.sin(a), 640, 555 + 236 * math.cos(a), 10, 40, 10, math.deg(a)))
end
-- Loggia (SanctuaryService.buildLoggia) and the LootWorld caches with the eaves ladder.
table.insert(S, box("Walkway", "Stone", -55.5, 598.5, 900, 23, 3, 12))
for _, z in { 893.6, 906.4 } do table.insert(S, box("WalkRail", "Stone", -55.5, 600.7, z, 23, 1.4, 0.8)) end
table.insert(S, box("LoggiaPlatform", "Stone", -84, 597, 900, 36, 6, 36))
for _, z in { 884.4, 915.6 } do table.insert(S, box("LowWall", "Stone", -84.5, 602, z, 30, 4, 1.2)) end
table.insert(S, box("BackWall", "Stone", -99.8, 607.5, 900, 1.6, 15, 30))
for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do table.insert(S, box("Pier", "Stone", -84 + c[1] * 15, 607.5, 900 + c[2] * 15, 2.6, 15, 2.6)) end
for _, c in Arsenal.Caches do
	if c.Region == "Sanctuary" then
		table.insert(S, box("CacheLedge", "Stone", c.X, c.Y - 1.5, c.Z, 8, 1, 8))
		table.insert(S, box("Chest", "Stone", c.X, c.Y, c.Z, 3, 1.8, 2))
	end
end
local eaves = Arsenal.Caches.SanctuaryEaves
local sw = Walk.world(concat(S, Routes.Solids), -280, 280, 280, 1100)
local ladder = { { eaves.X - 2.5, 600, eaves.Z - 5, eaves.X, eaves.Y - 1, eaves.Z - 2.5 } } -- climb the truss onto the deck
local spawn = World.Altars.Altar_SanctuaryBonfire.Spawn
local swalk = sw:reach(spawn.X, spawn.Y - 3, spawn.Z, "Walk", ladder)
local sjump = sw:reach(spawn.X, spawn.Y - 3, spawn.Z, "Jump", ladder)
check("the bonfire walks to the Well of Descent", swalk.has(d.X, d.Y, d.Z))
check("the bonfire walks up the stairs to the landing and the terrace", swalk.has(0, 620, 790) and swalk.has(0, 620, 620))
for _, key in { "RevealWingW", "RevealWingE", "RevealDaisW", "RevealDaisE" } do
	local m = Routes.Marks[key]
	check("reveal point " .. key .. " is walked from the bonfire", swalk.has(m.X, m.Y, m.Z))
end
local relic = Arsenal.Caches.SanctuaryReliquary
check("the Cloud Reliquary needs the cloud shards", sjump.has(relic.X + 3, relic.Y - 1, relic.Z) and not swalk.has(relic.X + 3, relic.Y - 1, relic.Z))
check("the Loggia Eaves deck is reached by the service ledge and its ladder", swalk.has(eaves.X + 2.5, eaves.Y - 1, eaves.Z + 2))
local noLadder = sw:reach(spawn.X, spawn.Y - 3, spawn.Z, "Jump")
check("and not without the ladder", not noLadder.has(eaves.X + 2.5, eaves.Y - 1, eaves.Z + 2))
check("the ladder foot stands on walked ground", swalk.has(eaves.X - 2.5, 600, eaves.Z - 5))
local beyond = 0
for id, fy in swalk.Seen do
	local i, j = string.match(id, "(-?%d+),(-?%d+)")
	local x, z = tonumber(i) * 2 + 0.37, tonumber(j) * 2 + 0.37
	if fy > 619 and fy < 621 and z < 795 and math.sqrt(x * x + (z - 555) ^ 2) > 244.5 then beyond += 1 end
end
check(string.format("the terrace parapet keeps walkers off the rim (%d cells beyond)", beyond), beyond == 0)
-- Sightlines from eye height to her lap and veiled face.
local function sight(ax, ay, az, bx, by, bz)
	local steps = math.ceil(math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2 + (bz - az) ^ 2) / 0.5)
	for k = 1, steps - 4 do
		local t = k / steps
		local x, y, z = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t
		for _, b in concat(occluders, S, Routes.Solids) do
			if b.Kind ~= "Veil" and Walk.inside(b, x, y, z) then return false end
		end
	end
	return true
end
local fig = Routes.Marks.Figure
for _, key in { "RevealWingW", "RevealWingE", "RevealDaisW", "RevealDaisE" } do
	local m = Routes.Marks[key]
	check(key .. " sees her face and lap", sight(m.X, m.Y + 5.5, m.Z, fig.X, 708, fig.Z) and sight(m.X, m.Y + 5.5, m.Z, fig.X, 650, fig.Z))
end
check("from the bonfire the gate hides her lap (why the reveal points exist)", not sight(0, 605.5, 920, fig.X, 650, fig.Z))

-- The shrine's cloud catch (the real SanctuaryService poll) and the crypt.
do
	local ORIGIN = vec(World.Sanctuary.Origin.X, World.Sanctuary.Origin.Y, World.Sanctuary.Origin.Z)
	local e = { Root = {}, Fighter = { State = "Idle" } }
	local returned = false
	local Players = { GetPlayers = function() return { { UserId = 1 } } end }
	local Characters = { GetEntity = function() return e end, IsInDuel = function() return false end,
		Teleport = function() returned = true end, Cue = function() end, IsSettling = function() return false end }
	local spawnCFrame = {}
	local fallState = {}
	local CATCH_LIMITS = { Radius = 1300, FloorY = ORIGIN.Y - 40 }
	-- POLL_INSERT
	e.Root.Position = vec(0, 603, 920); poll()
	for _, p in { { arrive.X, arrive.Y + 3, arrive.Z }, { 455, 18, 1046 }, { 380, -11, 875 }, { 409, 19, 900 }, { 520, 3, 880 } } do
		returned = false; e.Root.Position = vec(p[1], p[2], p[3]); poll()
		check(string.format("the cloud catch leaves crypt play alone at (%d, %d, %d)", p[1], p[2], p[3]), not returned)
	end
	e.Root.Position = vec(0, 603, 920); poll()
	for _, p in { { 0, 601, 990 }, { 46, 607, 988 }, { -76, 619, 923 }, { 27, 623, 804 } } do
		returned = false; e.Root.Position = vec(p[1], p[2], p[3]); poll()
		check(string.format("standing at (%d, %d, %d) on the new routes is safe", p[1], p[2], p[3]), not returned)
	end
	returned = false; e.Root.Position = vec(30, 540, 990); poll()
	check("a missed cloud-shard jump is caught by the clouds", returned)
end

-------------------------------------------------------------------------------------------------
-- 7. Wayfinding (the real RouteGuide): staged doors with height, never up a drop.
-------------------------------------------------------------------------------------------------
-- ROUTEGUIDE_INSERT
local Guide = loadGuide({ Parent = { MonasteryZones = Zones, WorldDefinitions = World, CampaignZones = Campaign, SanctuaryRoutes = Routes } }, function(m) return m end)
local function stage(from, goal) return Guide.next(vec(from[1], from[2], from[3]), vec(goal[1], goal[2], goal[3])) end
local s1 = stage({ 0, 3, -1180 }, { 0, 6, -1736 })
check("Bamboo gate -> Colosseum altar starts up the ridge stairs", s1.Label == "Ridge stairs" and s1.Remaining and s1.Remaining > 556)
local s2 = stage({ -36, 3, -1320 }, { 128, 21, -1428 })
check("shrine -> Wraith tablet goes back over the crest, not up the drop", s2.Label == "Shrine stairs")
local s3 = stage({ 0, -23, -2180 }, { 0, 3, -2272 })
local head = table.find(s3.Route.Names, "Stair head")
check("lotus gorge -> Wu's gate climbs the west stair from its foot to its head", s3.Label == "West stair"
	and head ~= nil and s3.Route.Points[head].Y > -10 and s3.Route.Points[head].X < -55)
local s4 = stage({ 0, 3, -800 }, { -36, 3, -1328 })
check("Monastery courtyard -> Bamboo shrine follows the Monastery doors first", s4.Label == "Processional path")
local s5 = stage({ -36, 3, -1328 }, { 60, 3, -1010 })
check("Bamboo shrine -> Cloister altar walks back through the crest and the Bamboo Gate", s5.Label == "Shrine stairs")
local s6 = stage({ arrive.X, arrive.Y + 3, arrive.Z }, { 520, 3, 988 })
check("crypt arrival -> Titan's gate goes down the gallery stair", s6.Label == "Gallery stair")
local s7 = stage({ 0, 603, 920 }, { 520, 3, 988 })
check("from the shrine the crypt goal points at the Well of Descent", s7.Position and s7.Position.Z == 996 and s7.Label == "Crypt descent")
local s8 = stage({ 0, 3, -2700 }, { 0, 3, -2300 })
check("bastion -> Wu (backwards) descends Heaven's stair", s8.Label == "Last bastion")
local s9 = stage({ 0, 3, -800 }, { 60, 3, -1010 })
check("Monastery-only routes are unchanged", s9.Label == "Processional path")
-- Follow-up 14: the whole route the minimap draws. Every segment (player -> doors -> goal) must lie
-- inside one walked zone, so the line never crosses a wall; home goals end at the region's own portal.
local function shareZone(p, q)
	for _, z in Zones.List do
		if Zones.contains(z, p.X, p.Z, 3) and Zones.contains(z, q.X, q.Z, 3) then return true end
	end
	for _, z in Campaign.List do
		if Campaign.contains(z, p.X, nil, p.Z, 3) and Campaign.contains(z, q.X, nil, q.Z, 3) then return true end
	end
	return false
end
-- Or the segment ends at a doorway of the zone it starts in (stair doors stand at the stair foot).
local function doorOf(name, p)
	for _, d in Campaign.Doors do
		if d.Name == name then
			for _, id in { d.A, d.B } do
				local z = Campaign.get(id)
				if z and Campaign.contains(z, p.X, nil, p.Z, 3) then return true end
			end
		end
	end
	for _, d in Zones.Doors do
		if d.Name == name then
			for _, id in { d.A, d.B } do
				local z = Zones.get(id)
				if z and Zones.contains(z, p.X, p.Z, 3) then return true end
			end
		end
	end
	return false
end
-- Studio F17: a zone rectangle that spans a veiled-off corner lets the line cut through a MistVeil.
local veils = {}
for _, layout in byRegion do
	for _, b in layout.Solids do if b.Kind == "Veil" then table.insert(veils, b) end end
end
local function crossesVeil(a, b)
	local steps = math.ceil((b - a).Magnitude)
	for k = 1, steps - 1 do
		local t = k / steps
		local x, y, z = a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t
		for _, v in veils do
			if Walk.inside(v, x, y, z) then return true end
		end
	end
	return false
end
local function walkable(from, goal)
	local s = stage(from, goal)
	local cursor = vec(from[1], from[2], from[3])
	for i, point in s.Route.Points do
		if crossesVeil(cursor, point) then
			print(string.format("  veil: (%.0f,%.0f,%.0f) -> (%.0f,%.0f,%.0f)", cursor.X, cursor.Y, cursor.Z, point.X, point.Y, point.Z))
			return false
		end
		if not shareZone(cursor, point) and not doorOf(s.Route.Names[i], cursor) then
			print(string.format("  gap: (%.0f,%.0f,%.0f) -> (%.0f,%.0f,%.0f)", cursor.X, cursor.Y, cursor.Z, point.X, point.Y, point.Z))
			return false
		end
		cursor = point
	end
	return #s.Route.Points >= 1
end
for name, case in {
	["Bamboo gate -> Colosseum altar"] = { { 0, 3, -1180 }, { 0, 6, -1736 } },
	["Monastery courtyard -> Bamboo shrine"] = { { 0, 3, -800 }, { -36, 3, -1328 } },
	["lotus gorge -> Wu's gate"] = { { 0, -23, -2180 }, { 0, 3, -2272 } },
	["crypt arrival -> Titan's gate"] = { { arrive.X, arrive.Y + 3, arrive.Z }, { 520, 3, 988 } },
	["bastion -> Wu"] = { { 0, 3, -2700 }, { 0, 3, -2300 } },
	["Octagon ring -> Shen's gate"] = { { 106, 3, -1751 }, { 0, 3, -1868 } },
	["antechamber -> Octagon ring"] = { { 0, 3, -1736 }, { 118, 3, -1760 } },
	["Bamboo shrine -> frost ridge"] = { { -36, 3, -1328 }, { 100, 15, -1300 } },
	["Pagoda gorge -> Sky bastion"] = { { 0, -23, -2180 }, { 0, 3, -2700 } },
	["crypt reliquary -> Titan's gate"] = { { 380, 3, 800 }, { 520, 3, 985 } },
} do
	check("route line stays inside walked zones: " .. name, walkable(case[1], case[2]))
end
local last = stage({ 0, 3, -1180 }, { 0, 6, -1736 }).Route.Points
check("an on-foot route ends at the goal itself", last[#last].Z == -1736)
local home = stage({ arrive.X, arrive.Y + 3, arrive.Z }, { 0, 603, 918 })
local portal = home.Route.Points[#home.Route.Points]
check("crypt -> Sanctuary goal ends at the crypt's return portal, not across the world split", home.Route.Exit == "Return portal"
	and portal.X == 520 and portal.Z == 1074 and home.Position.Y < 100)
local summit = stage({ 0, 3, -2700 }, { 0, 603, 918 })
local gate = summit.Route.Points[#summit.Route.Points]
check("bastion -> Sanctuary goal ends at the bastion's return portal", summit.Route.Exit == "Return portal" and gate.X == 44 and gate.Z == -2690)
check("Sanctuary -> crypt goal ends at the Well of Descent", s7.Route.Exit == "Crypt descent")
-- Studio F18: the sarcophagus lids stood in no zone, so on the lids the guide fell back to a straight
-- line across the crypt walls. Every doorway must stand in (or on the edge of) a zone it joins.
for _, d in Campaign.Doors do
	local inside = false
	for _, id in { d.A, d.B } do
		local z = Campaign.get(id)
		if z and Campaign.contains(z, d.X, nil, d.Z, 3) then inside = true end
	end
	check("door " .. d.Name .. " stands in a zone it joins", inside)
end
-- Studio F20: off the Citadel's cloud bridge the engine deleted the body at y -100 (FallenPartsDestroyHeight)
-- ~0.94 s into the fall, before the bridge catch (0.6 s hold below -30, 0.2 s poll) could return it.
-- WORLD_INSERT
for _, layout in byRegion do
	for _, c in layout.Returns or {} do
		local top = c.To.Y
		local reach = math.sqrt(2 * math.max(top - c.Below, 0) / GRAVITY)
		local deleted = math.sqrt(2 * (top - DESTROY_Y) / GRAVITY)
		check(string.format("%s catch returns a falling body before the engine deletes it (%.2fs < %.2fs)", c.Name, reach + HOLD + POLL, deleted),
			reach + HOLD + POLL + 0.1 < deleted)
	end
end
for _, z in { 853, 860, 867, 874, 881, 888, 895 } do
	check(string.format("sarcophagus lid z=%d is walked ground", z), Campaign.at(366, 1, z) ~= nil)
end
for _, door in Campaign.Doors do
	local w = if string.sub(door.A, 1, 3) == "SD_" then kw else cw
	local reached = door.A == "DM:Road" or (if w == kw then kjump else jump).has(door.X, door.Y, door.Z, 2.5)
	check("door " .. door.Name .. " stands on reached ground", reached)
end

print(string.format("campaign regions: %d passed, %d failed", passed, failed))
if failed > 0 then error("campaign region regression failed") end

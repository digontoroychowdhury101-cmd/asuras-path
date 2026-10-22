--!nonstrict
-- Lune regression for playtest findings #3, #4, #26, #27, #29 and #30 (batch 07). The Desecrated
-- Monastery is built offline from the real builders (tools/monastery_scene.luau) and queried as
-- oriented boxes: the bridge duel space and both bridge approaches are clear, every Monastery altar
-- has an open pocket, a clear departure walk and clean portrait shots (the real PortraitCamera
-- logic with a probe that sees decor too), the floor stops at the valley, the crest veil encloses
-- every authored point while leaving the south road open, the ravine returns fallers north, the
-- portal arrival faces the checkpoint and the Sanctuary objective names the real destination.
-- Not covered: terrain voxels, uploaded meshes, and anything needing Studio physics or play.
-- Run from the project root: lune run tools/test_monastery_route.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Scene = require("./monastery_scene")
local V3, CF = roblox.Vector3, roblox.CFrame

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local scene = Scene.build()
local World, G = scene.World, scene.Ground
local function near(center, radius)
	local list = {}
	for _, e in scene.Parts do if (e.CFrame.Position - center).Magnitude < radius + e.Radius then table.insert(list, e) end end
	return { Parts = list }
end
local function cast(sub, a, b, filter) return Scene.cast(sub, a, b, filter) end
local function topAt(sub, x, z)
	local p, e = cast(sub, V3.new(x, G + 40, z), V3.new(x, G - 30, z), Scene.solid)
	return p, e
end

-- 1. The bridge duel (#3).
local bridge = near(V3.new(0, 0, -960), 40)
local spine = nil
for _, e in bridge.Parts do
	if e.Visible and e.Name ~= "Flagstone" then
		for x = -7, 7, 1 do for z = -934, -986, -1 do for y = 0.5, 8, 0.75 do
			if not spine and Scene.inside(e, V3.new(x, G + y, z)) then spine = e.Path .. " at " .. x .. "," .. z end
		end end end
	end
end
check("bridge duel space free of any visible stone (was an arch-stone spine)", spine == nil)
if spine then print("   intrusion: " .. spine) end
for _, e in bridge.Parts do
	if e.Name == "Voussoir" then
		local top = -math.huge
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			top = math.max(top, (e.CFrame * CF.new(e.Half.X * sx, e.Half.Y * sy, e.Half.Z * sz)).Position.Y)
		end end end
		check("arch stone stays under the deck surface", top < G - 0.5)
		check("arch stone spans the deck width", math.abs(e.CFrame.RightVector.X) > 0.99)
	end
end
local swordsman
for _, entry in World.spawnsIn("DesecratedMonastery") do if entry.Id == "DM_Swordsman_Bridge" then swordsman = entry end end
for _, point in { swordsman.Placement, table.unpack(swordsman.Patrol) } do
	local hit, e = topAt(bridge, point.X, point.Z)
	check(string.format("swordsman footing on the deck at (%.0f, %.0f)", point.X, point.Z), hit and e.Name == "Deck" and math.abs(hit.Y - G) < 0.05)
end
local guard = V3.new(swordsman.Placement.X, G + 2.5, swordsman.Placement.Z)
for _, z in { -930, -990 } do
	for _, x in { -5, 0, 5 } do
		local from = V3.new(x, G + 2.5, z)
		check(string.format("melee/spell line to the swordsman from (%d, %d)", x, z), cast(bridge, from, guard, Scene.visible) == nil)
	end
end

-- 2. Altar pockets, departure and portraits (#4), with the real PortraitCamera selection.
local Portrait = luau.load(src("src/client/Controllers/PortraitCamera.luau"), { debugName = "PortraitCamera", environment = {
	game = { GetService = function() return {} end }, Vector3 = V3, CFrame = CF, RaycastParams = {}, Enum = roblox.Enum, table = table, math = math } })()
local kit = scene.Modules.MonasteryKit
for id, altar in World.Regions.DesecratedMonastery.Altars do
	local c = V3.new(altar.Placement.X, 0, altar.Placement.Z)
	local sub = near(c, 45)
	local shrine = "Shrine_" .. altar.Id
	local intruder = nil
	for _, e in sub.Parts do
		if e.Collide and string.sub(e.Path, 1, #shrine) ~= shrine and e.Name ~= "Flagstone" then
			for k = 0, 23 do for _, r in { 4, 7, 10, kit.POCKET - 0.5 } do for _, y in { 1, 3, 5 } do
				local a = k * math.pi / 12
				if not intruder and Scene.inside(e, c + V3.new(math.cos(a) * r, G + y, math.sin(a) * r)) then intruder = e.Path end
			end end end
		end
	end
	check(id .. " rest pocket has no pillar or wall", intruder == nil)
	if intruder then print("   in pocket: " .. intruder) end
	check(id .. " has an authored exit", altar.Exit ~= nil)
	local blocked = nil
	for _, lift in { 1.2, 3.5 } do
		for _, offset in { -1, 0, 1 } do
			local a = V3.new(altar.Spawn.X + offset, G + lift, altar.Spawn.Z)
			local b = V3.new(altar.Exit.X + offset, G + lift, altar.Exit.Z)
			local _, e = cast(near((a + b) * 0.5, (b - a).Magnitude), a, b, Scene.solid)
			blocked = blocked or (e and e.Path)
		end
	end
	check(id .. " departure walk to its exit is clear", blocked == nil)
	if blocked then print("   departure blocked by " .. blocked) end
	local point = V3.new(altar.Placement.X, altar.Placement.Y, altar.Placement.Z)
	local probe = function(a, b) return (cast(sub, a, b, Scene.visible)) end
	local viewers, clean, front, frontBoth = 0, 0, 0, 0
	for k = 0, 15 do
		local ang = k * math.pi / 8
		for _, r in { 4.5, 7, 9 } do
			local viewer = point + V3.new(math.cos(ang) * r, 3, math.sin(ang) * r)
			local standing = true
			for _, e in sub.Parts do if e.Collide and Scene.inside(e, viewer - V3.new(0, 1.5, 0)) then standing = false; break end end
			if standing then
				viewers += 1
				local subject = Portrait.spiritSpot(point, viewer, probe) + V3.new(0, 2, 0)
				local _, ok = Portrait.choose(subject, viewer, probe)
				clean += if ok then 1 else 0
				-- The stele stands at +Z; everywhere else both shoulder shots must be clean.
				if math.sin(ang) < 0.5 then
					front += 1
					local both = true
					for i = 1, 2 do
						local cam = Portrait.candidates(subject, viewer)[i]
						local past = cam + (cam - subject).Unit * Portrait.Margin
						both = both and not probe(subject, past) and not probe(subject - V3.new(0, Portrait.Chest, 0), past)
					end
					frontBoth += if both then 1 else 0
				end
			end
		end
	end
	check(id .. " portrait clean from every standing spot (" .. clean .. "/" .. viewers .. ")", viewers >= 40 and clean == viewers)
	check(id .. " both shoulder shots clean away from the stele (" .. frontBoth .. "/" .. front .. ")", front >= 30 and frontBoth == front)
end
check("colonnade honours the altar pocket", string.find(src("src/server/Services/MonasteryHalls.luau"), "Kit.keepClear(at.X, at.Z, 1.7)", 1, true) ~= nil)
check("spirit stands in plain view of the player", string.find(src("src/client/Controllers/PortraitCamera.luau"), "not probe(chest, eye)", 1, true) ~= nil)

-- 3. Floor extent and the east pass (#26).
local T = scene.Modules.MonasteryTerrain
local plateau, pass = T.PLATEAU, T.EAST_PASS
for _, call in scene.Terrain do
	if call.Kind == "Block" and call.Material == "Ground" and call.Size.Y > 10 then
		local x0, x1 = call.CFrame.Position.X - call.Size.X / 2, call.CFrame.Position.X + call.Size.X / 2
		local inValley = x0 >= -T.VALLEY_HALF - 1e-6 and x1 <= T.VALLEY_HALF + 1e-6
		local onPlateau = x0 >= plateau.X0 - 1e-6 and x1 <= plateau.X1 + 1e-6
		check(string.format("floor fill stays in the valley or plateau (x %.0f..%.0f)", x0, x1), inValley or onPlateau)
	end
end
local twins = World.Bosses.TwinSentinels
check("plateau holds the Twins arena", twins.Arena.Center.X - twins.Arena.Size.X / 2 >= plateau.X0 and twins.Arena.Center.X + twins.Arena.Size.X / 2 <= plateau.X1
	and twins.Arena.Center.Z + twins.Arena.Size.Z / 2 <= plateau.Z0 and twins.Arena.Center.Z - twins.Arena.Size.Z / 2 >= plateau.Z1)
local carved = false
for _, call in scene.Terrain do
	if call.Kind == "Block" and call.Material == "Air" and math.abs(call.CFrame.Position.Z + 810) < 1 and call.Size.X >= 90 then carved = true end
end
check("ridge cut open for the courtyard road", carved)
local wallGap = true
for _, e in near(V3.new(82, 0, -811), 14).Parts do
	if e.Collide and e.Name ~= "Flagstone" and Scene.inside(e, V3.new(82, G + 3, -811)) then wallGap = false end
end
check("courtyard east wall opens onto the pass road", wallGap)

-- 4. Crest veil and ravine (#27).
local Bounds = luau.load(src("src/server/Services/MonasteryBounds.luau"), { debugName = "MonasteryBounds", environment = {
	game = { GetService = function() return { GetPlayers = function() return {} end } end },
	script = { Parent = { WaitForChild = function(_, name) return if name == "MonasteryKit" then kit elseif name == "MonasteryTerrain" then T else {} end } },
	require = function(m) return m end, Vector3 = V3, CFrame = CF, Enum = roblox.Enum, math = math, table = table, task = {} } })()
local poly = { { -T.VALLEY_HALF, -646 }, { T.VALLEY_HALF, -646 }, { T.VALLEY_HALF, plateau.Z0 }, { plateau.X1, plateau.Z0 }, { plateau.X1, plateau.Z1 },
	{ plateau.X0, plateau.Z1 }, { plateau.X0, -1200 }, { -T.VALLEY_HALF, -1200 } }
local function inside(x, z)
	local inPoly = false
	local j = #poly
	for i = 1, #poly do
		local xi, zi, xj, zj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
		if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then inPoly = not inPoly end
		j = i
	end
	return inPoly
end
local function onWall(x, z)
	for _, w in Bounds.Walls do
		local ax, az, bx, bz = w[1], w[2], w[3], w[4]
		local dx, dz = bx - ax, bz - az
		local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
		if math.sqrt((x - ax - dx * t) ^ 2 + (z - az - dz * t) ^ 2) < 0.5 then return true end
	end
	return false
end
local gaps = {}
for i = 1, #poly do
	local a, b = poly[i], poly[i % #poly + 1]
	for s = 0, 1, 0.02 do
		local x, z = a[1] + (b[1] - a[1]) * s, a[2] + (b[2] - a[2]) * s
		if not onWall(x, z) then table.insert(gaps, { x, z }) end
	end
end
local roadOnly = #gaps > 0
for _, g in gaps do roadOnly = roadOnly and math.abs(g[2] + 1200) < 1e-6 and math.abs(g[1]) < 130 end
check("veil closes the crest everywhere except the south road", roadOnly)
local authored = {}
for _, a in World.Regions.DesecratedMonastery.Altars do table.insert(authored, a.Spawn); table.insert(authored, a.Exit) end
for _, s in World.spawnsIn("DesecratedMonastery") do table.insert(authored, s.Placement); for _, p in s.Patrol do table.insert(authored, p) end end
for _, gate in { World.FogGates[twins.FogGate] } do table.insert(authored, gate.Inside); table.insert(authored, gate.Outside) end
local Catalog = require("../src/shared/ArsenalCatalog")
local Narrative = require("../src/shared/NarrativeCatalog")
for _, c in Catalog.Caches do if c.Region == "DesecratedMonastery" then table.insert(authored, c) end end
for _, l in Narrative.Lore do if l.Region == "DesecratedMonastery" then table.insert(authored, l) end end
local outside = 0
for _, p in authored do if not inside(p.X, p.Z) then outside += 1; print(string.format("   outside veil: %.0f, %.0f", p.X, p.Z)) end end
check("every authored monastery point lies inside the veil (" .. #authored .. ")", outside == 0)
check("veil is invisible, solid and ignored by queries", string.find(src("src/server/Services/MonasteryBounds.luau"), "Collide = true, Query = false, Transparency = 1", 1, true) ~= nil)
check("ravine floor detected", Bounds.inRavine(V3.new(-40, -9, -960)) and Bounds.inRavine(V3.new(60, -6, -955)))
check("bridge deck and banks are not the ravine", not Bounds.inRavine(V3.new(0, 3, -960)) and not Bounds.inRavine(V3.new(-40, 3, -930)) and not Bounds.inRavine(V3.new(-40, 3, -992)))
local head, e = topAt(near(Bounds.Bridgehead.Position, 20), Bounds.Bridgehead.Position.X + 1.5, Bounds.Bridgehead.Position.Z) -- off the tile joint
check("ravine return lands on stone north of the bridge", head and e.Name == "Flagstone" and Bounds.Bridgehead.Position.Z > -932)
check("bounds started with the map and stopped on teardown", string.find(src("src/server/Services/MonasteryService.luau"), "Bounds.Start()", 1, true) and string.find(src("src/server/Services/MonasteryService.luau"), "Bounds.Stop()", 1, true))

-- 5. Arrival and wording (#29, #30).
local dest = World.Altars[World.Sanctuary.PortalDestination]
local at = V3.new(dest.Spawn.X, dest.Spawn.Y, dest.Spawn.Z)
local arrival = CF.lookAt(at, V3.new(dest.Placement.X, at.Y, dest.Placement.Z))
local toAltar = (V3.new(dest.Placement.X, at.Y, dest.Placement.Z) - at).Unit
check("portal arrival faces its altar", arrival.LookVector:Dot(toAltar) > 0.99 and (V3.new(dest.Placement.X, 0, dest.Placement.Z) - V3.new(at.X, 0, at.Z)).Magnitude < 12)
local ss = src("src/server/Services/SanctuaryService.luau")
check("server uses the arrival framing", string.find(ss, "Characters.Teleport(userId, arrivalCFrame(DESTINATION))", 1, true) ~= nil)
check("camera turns with the arrival", string.find(src("src/client/Controllers/InterfaceController.luau"), "self.Camera:Face(body.Root.CFrame.LookVector)", 1, true)
	and string.find(src("src/client/Controllers/CameraController.luau"), "function Controller.Face", 1, true))
local Ending = luau.load(src("src/shared/EndingRules.luau"), { debugName = "EndingRules", environment = { Vector3 = V3, table = table, math = math } })()
local Objectives = luau.load(src("src/shared/Objectives.luau"), { debugName = "Objectives", environment = { Vector3 = V3, string = string, type = type, table = table,
	script = { Parent = { EndingRules = Ending } }, require = function(m) return m end } })()
local function sanctuary(altars)
	return Objectives.resolve({ Region = "Sanctuary", Altars = altars, InBoss = false, InColosseum = false, BossFelled = false, Rested = true })
end
local o1 = sanctuary({ Altar_SanctuaryBonfire = true })
check("first leg names the Monastery Gate", o1.Target.Kind == "Portal" and string.find(o1.Detail, "opens on the Monastery Gate", 1, true))
local o2 = sanctuary({ Altar_SanctuaryBonfire = true, Altar_MonasteryGate = true, Altar_DesecratedCloister = true })
check("later leg states the portal destination, then the next altar", string.find(o2.Detail, "opens on the Monastery Gate", 1, true)
	and string.find(o2.Detail, "then travel on to the Whispering Bamboo Shrine", 1, true) and not string.find(o2.Detail, "reach the Whispering", 1, true))
local o3 = sanctuary({ Altar_SanctuaryBonfire = true, Altar_MonasteryGate = true })
check("monastery leg says press on through the monastery", string.find(o3.Detail, "press on through the monastery to the Desecrated Cloister", 1, true) ~= nil)
local o4 = Objectives.resolve({ Region = "DesecratedMonastery", Altars = { Altar_SanctuaryBonfire = true }, InBoss = false, InColosseum = false, BossFelled = false, Rested = true })
check("arrival objective points at the altar just ahead", o4.Target.Id == "Altar_MonasteryGate" and string.find(o4.Detail, "just ahead", 1, true))

-- 6. Hygiene.
local project = src("default.project.json")
for _, name in { "MonasteryTerrain", "MonasteryBounds", "MonasteryGrounds", "MonasteryHalls", "MonasteryKit", "MonasteryRuins", "MonasterySurvey", "MonasteryService" } do
	local text = src("src/server/Services/" .. name .. ".luau")
	local _, lines = string.gsub(text, "\n", "")
	check(name .. " strict and under 150 lines", string.sub(text, 1, 9) == "--!strict" and lines < 150)
	check(name .. " registered", string.find(project, "Services/" .. name .. ".luau", 1, true) ~= nil)
end

print(string.format("monastery route: %d passed, %d failed", passed, failed))
if failed > 0 then error("monastery route regression failed") end

--!nonstrict
-- World fit of the colossal Bellwood temple (CLAUDE_BELLWOOD_REPLACEMENT_HANDOFF, "Replace the actual temple", step 1).
-- Pure numbers against src/shared/LandmarkLayout and the real Overworld. Run:
-- python3 tools/lune_compat.py tools/test_bellwood_fit.luau
local O = require("../src/shared/Overworld")
local L = require("../src/shared/LandmarkLayout")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local bw = L.Landmarks.Bellwood
local B = bw.Basin
local floorY = L.basinLevels(bw)
local C = L.basinCentre(bw)
local fx, fz = L.front(bw)
local ax, az = -fz, fx -- basin Across axis (LandmarkLayout.basinSpot)

-- Study bounds, Blender units = studs, from work/sol-bellwood-v10/audit/geometry.json. Core = everything a player or the sky sees except the
-- Crag/Pine backdrop. Blender (x, y, z) -> Roblox model (-x, z, y); the stair climbs from y = +257 (foot, +Y = toward the viewer) to y = -41.
local STUDY = {
	Core = { x0 = -404, x1 = 440, y0 = -326, y1 = 347, z1 = 758 }, -- bark twigs envelope: crown 758 high
	Masonry = { x0 = -250.7, x1 = 274.5, y0 = -300, y1 = 262 }, -- solid base: stair, terraces, pavilions
	Backdrop = { x0 = -694, x1 = 725, y0 = -932, y1 = -174 }, -- Crag + Pine, behind the temple
}
-- Sight targets in Blender coordinates (tier 0 floor z 113 at the stair head; top roof = tier 5 tile line; crown = leader tip).
local TARGETS = { Threshold = { 0, -41, 113 }, Roof = { 34, -237, 505 }, Crown = { -52, -130, 750 } }

local roads, rivers = {}, {}
for _, road in O.terrainData().Roads do
	for k = 2, #road.Points do table.insert(roads, { road.Points[k - 1], road.Points[k] }) end
end
for _, rv in O.TerrainDef.Rivers do for k = 2, #rv.Points do table.insert(rivers, { rv.Points[k - 1], rv.Points[k] }) end end
local function segDist(x, z, segs)
	local best = math.huge
	for _, s in segs do
		local a, b = s[1], s[2]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local t = math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / math.max(dx * dx + dz * dz, 1e-6), 0, 1)
		best = math.min(best, math.sqrt((x - a[1] - t * dx) ^ 2 + (z - a[2] - t * dz) ^ 2))
	end
	return best
end

-- The eight road eyes of work/sol-bellwood-v9/world_fit.luau: road samples every 20 studs, nearest the basin centre first, 80 apart.
local eyes = {}
do
	local cands = {}
	for _, sg in roads do
		local p, q = sg[1], sg[2]
		local dx, dz = q[1] - p[1], q[2] - p[2]
		local n = math.max(1, math.ceil(math.sqrt(dx * dx + dz * dz) / 20))
		for j = 0, n do
			local x, z = p[1] + j * dx / n, p[2] + j * dz / n
			table.insert(cands, { x, z, (x - C.X) ^ 2 + (z - C.Z) ^ 2 })
		end
	end
	table.sort(cands, function(p, q) return p[3] < q[3] end)
	for _, p in cands do
		local far = true
		for _, e in eyes do if (p[1] - e[1]) ^ 2 + (p[2] - e[2]) ^ 2 < 80 ^ 2 then far = false; break end end
		if far then table.insert(eyes, p) end
		if #eyes == 8 then break end
	end
end

-- Temple frame, mirroring LandmarkWorld.templeFrame (kept in step by hand: that module needs Roblox types): up is world Y, model +Z is the
-- unit XZ vector from the temple to the passage exit, model +X = up x +Z.
local exitX, exitZ
do
	local q, a = bw.Tunnel.Passage[#bw.Tunnel.Passage], math.rad(bw.Yaw)
	exitX = bw.Origin.X + (-q[1]) * math.cos(a) + q[2] * math.sin(a)
	exitZ = bw.Origin.Z - (-q[1]) * math.sin(a) + q[2] * math.cos(a)
end
local function place(P)
	local x, z = C.X + ax * P.Across + fx * P.Along, C.Z + az * P.Across + fz * P.Along
	local y = bw.Origin.Y + B.Bed + P.Lift
	local zx, zz = exitX - x, exitZ - z
	local l = math.sqrt(zx * zx + zz * zz)
	zx, zz = zx / l, zz / l
	-- Blender (bx, by, bz) -> world
	return function(bx, by, bz)
		local mx, my, mz = -bx, bz, by
		return x + zz * mx + zx * mz, y + my, z - zx * mx + zz * mz
	end, x, z, y
end

-- Terrain-only occluder: carved basin and rim as the layout writes them, written ground + 2 elsewhere, plus a candidate's rock screen.
-- Screen = { Pad, Width, Height, Gaps = { { theta0, theta1 } (degrees on the shore ring) } }: a rock band Width studs wide whose inner
-- edge stands Pad studs outside the rim's outer edge, Height over the written ground, open across each gap.
local function ringAngle(x, z)
	local dx, dz = x - C.X, z - C.Z
	return math.deg(math.atan2((dx * fx + dz * fz) / (B.Depth / 2), (dx * ax + dz * az) / (B.Width / 2))) % 360
end
local function inScreen(S, x, z, margin)
	if not S then return false end
	local m = margin or 0
	if L.basinEllipse(bw, x, z, B.Thick + S.Pad - m) < 1 or L.basinEllipse(bw, x, z, B.Thick + S.Pad + S.Width + m) >= 1 then return false end
	local th = ringAngle(x, z)
	for _, g in S.Gaps do
		if th >= g[1] and th <= g[2] then return false end
	end
	return true
end
local function surface(S, x, z)
	local s = L.carvedSurface(x, z, O.heightAt) or (O.heightAt(x, z) + 2)
	if inScreen(S, x, z) then s = math.max(s, O.heightAt(x, z) + S.Height) end
	return s
end
local function visible(S, e, tx, tz, ty)
	local ey = O.heightAt(e[1], e[2]) + 7.5
	for j = 1, 250 do
		local k = j / 250
		if surface(S, e[1] + (tx - e[1]) * k, e[2] + (tz - e[2]) * k) >= ey + (ty - ey) * k then return false end
	end
	return true
end

-- Reports { Threshold = n, Roof = n, Crown = n } (eyes of 8 that see it) and the eight-row table.
local function visibility(P, S)
	local at = place(P)
	local count, rows = { Threshold = 0, Roof = 0, Crown = 0 }, {}
	for i, e in eyes do
		local row = {}
		for _, name in { "Threshold", "Roof", "Crown" } do
			local t = TARGETS[name]
			local x, y, z = at(t[1], t[2], t[3])
			local v = visible(S, e, x, z, y)
			if v then count[name] += 1 end
			table.insert(row, v and "V" or ".")
		end
		rows[i] = table.concat(row)
	end
	return count, rows
end

-- Footprint samples of the solid base (and the whole envelope) in world XZ.
local function footprint(P, box)
	local at = place(P)
	local out = {}
	for i = 0, 8 do for j = 0, 8 do
		local x, _, z = at(box.x0 + (box.x1 - box.x0) * i / 8, box.y0 + (box.y1 - box.y0) * j / 8, 0)
		table.insert(out, { x, z })
	end end
	return out
end

-- Everything the fit must keep clear of, as { x, z, radius, label }.
local others = {}
for id, a in O.Altars do table.insert(others, { (a.Placement or a.Position).X, (a.Placement or a.Position).Z, 0, "altar " .. id }) end
for id, n in O.Nodes do table.insert(others, { n.Position.X, n.Position.Z, 0, "node " .. id }) end
for _, p in O.POIs do table.insert(others, { p.Position.X, p.Position.Z, 0, "poi " .. p.Id }) end
for id, l in O.Landmarks do table.insert(others, { l.Position.X, l.Position.Z, 0, "landmark " .. id }) end
table.insert(others, { O.Vesperhold.X, O.Vesperhold.Z, 600, "Vesperhold" })
table.insert(others, { O.Barrier.Arena.Center.X, O.Barrier.Arena.Center.Z, 100, "Shen arena" })
table.insert(others, { O.Barrier.Gate.Placement.X, O.Barrier.Gate.Placement.Z, 100, "Shen barrier gate" })
table.insert(others, { O.Barrier.Gate.Outside.X, O.Barrier.Gate.Outside.Z, 100, "Shen barrier approach" })
for id, ra in O.ReservedArenas do table.insert(others, { ra.Arena.Center.X, ra.Arena.Center.Z, 90, "arena " .. id }) end
local okW, W = pcall(require, "../src/shared/WorldDefinitions")
local sanct = if okW then (W :: any).Regions.Sanctuary.Bounds else { Center = { X = 0, Z = 650 }, Size = { X = 600, Z = 920 } }

local gate, route = L.gateSpot(bw), L.route(bw, O.heightAt)
local MARGIN = 20 -- studs between the temple's solid base and any gate, causeway, route point or the shore shelf

-- Every geometric check one candidate must pass; returns the list of failure labels (empty = passes).
local function fits(P, S)
	local bad = {}
	local base = footprint(P, STUDY.Masonry)
	local env = footprint(P, STUDY.Core)
	local function note(label) table.insert(bad, label) end
	-- solid base: inside the bowl clear of the shelf, off the gate, causeway, route and tunnel exit
	local inLake, gateD, routeD, exitD, causeD = true, math.huge, math.huge, math.huge, math.huge
	local ca, cb = route.Causeway.A, route.Causeway.B
	for _, p in base do
		if L.basinEllipse(bw, p[1], p[2], -B.Shelf) >= 1 then inLake = false end
		gateD = math.min(gateD, math.sqrt((p[1] - gate.X) ^ 2 + (p[2] - gate.Z) ^ 2) - B.Gate.Radius)
		exitD = math.min(exitD, math.sqrt((p[1] - exitX) ^ 2 + (p[2] - exitZ) ^ 2) - bw.Tunnel.Width)
		causeD = math.min(causeD, segDist(p[1], p[2], { { { ca.X, ca.Z }, { cb.X, cb.Z } } }))
		for _, q in route.Points do
			if q.Kind == "causeway" or q.Kind == "leg" or q.Kind == "landing" then
				routeD = math.min(routeD, math.sqrt((p[1] - q.X) ^ 2 + (p[2] - q.Z) ^ 2))
			end
		end
	end
	if not inLake then note("base leaves the lake shelf") end
	if gateD < MARGIN then note(string.format("gate %.0f", gateD)) end
	if causeD < MARGIN + B.Route.Width / 2 then note(string.format("causeway %.0f", causeD)) end
	if routeD < MARGIN then note(string.format("route %.0f", routeD)) end
	if exitD < 3 * MARGIN then note(string.format("tunnel exit %.0f", exitD)) end
	-- envelope (twigs) is only airborne: it may cross the shore but not the neighbours' ground footprints
	for _, p in env do
		for _, o in others do
			if math.sqrt((p[1] - o[1]) ^ 2 + (p[2] - o[2]) ^ 2) < o[3] + 100 then note("envelope near " .. o[4]); break end
		end
	end
	for _, p in base do
		for _, o in others do
			if math.sqrt((p[1] - o[1]) ^ 2 + (p[2] - o[2]) ^ 2) < o[3] + 100 then note("base near " .. o[4]); break end
		end
		if math.abs(p[1] - sanct.Center.X) < sanct.Size.X / 2 + 100 and math.abs(p[2] - sanct.Center.Z) < sanct.Size.Z / 2 + 100 then note("lobby box") end
	end
	-- a pit under the temple needs a walkable ramp (Route.Slope) from the stair foot out to the lake bed before the shelf starts
	if P.Lift < 0 then
		local at = place(P)
		local x0, _, z0 = at(0, STUDY.Masonry.y1, 0)
		local x1, _, z1 = at(0, STUDY.Masonry.y1 + 1, 0)
		local dx, dz = x1 - x0, z1 - z0
		local free = 0
		while L.basinEllipse(bw, x0 + dx * free, z0 + dz * free, -B.Shelf) < 1 do free += 4 end
		if -P.Lift / B.Route.Slope > free then note(string.format("pit ramp %.0f > %.0f free", -P.Lift / B.Route.Slope, free)) end
	end
	-- the rock screen stays off roads, rivers, the route, the placed things and the lobby
	if S then
		local minRoad, minRiver, onRoute, nearOther = math.huge, math.huge, false, nil
		for k = 0, 359 do
			for _, f in { 0.0, 0.25, 0.5, 0.75, 1.0 } do
				local out = B.Thick + S.Pad + S.Width * f
				local x, z = L.basinRing(bw, math.rad(k), out)
				if inScreen(S, x, z) then
					minRoad, minRiver = math.min(minRoad, (segDist(x, z, roads))), math.min(minRiver, (segDist(x, z, rivers)))
					for _, o in others do
						if math.sqrt((x - o[1]) ^ 2 + (z - o[2]) ^ 2) < o[3] + 60 then nearOther = o[4] end
					end
				end
			end
		end
		for _, q in route.Points do
			if inScreen(S, q.X, q.Z, 30) then onRoute = true end
		end
		local lobby = false
		for _, sx in { -1, 0, 1 } do for _, sz in { -1, 0, 1 } do
			if inScreen(S, sanct.Center.X + sx * sanct.Size.X / 2, sanct.Center.Z + sz * sanct.Size.Z / 2, 100) then lobby = true end
		end end
		if minRoad < 110 then note(string.format("screen road %.0f", minRoad)) end
		if minRiver < 110 then note(string.format("screen river %.0f", minRiver)) end
		if onRoute then note("screen on route") end
		if nearOther then note("screen near " .. nearOther) end
		if lobby then note("screen in lobby") end
		-- the eye passage and its open apron (Basin.Apron: Back studs behind the face, HalfWidth either side) stay clear of rock
		local apron = false
		for d = 0, 200, 20 do for u = -B.Apron.HalfWidth, B.Apron.HalfWidth, 24 do
			if inScreen(S, bw.Origin.X - fx * d + ax * u, bw.Origin.Z - fz * d + az * u) then apron = true end
		end end
		if apron then note("screen on the eye apron") end
	end
	return bad
end


-- Best seat for the solid base: the grid point inside the lake shelf, clear of gate, causeway, route and exit, nearest the bowl centre.
local seat, seatE, seats = nil, math.huge, 0
for across = -500, 300, 20 do
	for along = -400, 300, 20 do
		local P = { Across = across, Along = along, Lift = 0 }
		if #fits(P, nil) == 0 then
			seats += 1
			local e = across ^ 2 / (B.Width / 2) ^ 2 + along ^ 2 / (B.Depth / 2) ^ 2
			if e < seatE then seat, seatE = P, e end
		end
	end
end
print(string.format("  seats for the %d x %d base: %d grid points%s", STUDY.Masonry.x1 - STUDY.Masonry.x0, STUDY.Masonry.y1 - STUDY.Masonry.y0, seats,
	seat and string.format(", best Across %d Along %d", seat.Across, seat.Along) or ""))
check("the solid base has at least one seat in the bowl clear of gate, causeway, route and exit", seat ~= nil)
seat = seat or { Across = 0, Along = 0, Lift = 0 }

-- Candidates. Across/Along/Lift are basin-frame offsets like Basin.Temple (Lift = studs over the lake bed; negative = a pit dug under the
-- temple). Current is the live Basin.Temple spot carrying the colossal study, the baseline the handoff measured.
local T = B.Temple
local function at(lift) return { Across = seat.Across, Along = seat.Along, Lift = lift } end
-- Rock screen between the road and the rim: Pad past the rim's outer edge, open over the ring angles that hold the face and tunnel lane.
local function screen(pad, height) return { Pad = pad, Width = 60, Height = height, Gaps = { { 70, 110 } } } end
local CANDIDATES = {
	{ Name = "Current", P = { Across = T.Across, Along = T.Along, Lift = T.Lift } },
	{ Name = "Seated", P = at(0) },
	{ Name = "ScreenPad20", P = at(0), S = screen(20, 250) },
	{ Name = "ScreenPad200", P = at(0), S = screen(200, 250) },
	{ Name = "Deep380", P = at(-380) },
	{ Name = "Deep80", P = at(-80) },
	{ Name = "ScreenSides250", P = at(0), S = { Pad = 20, Width = 60, Height = 250, Gaps = { { 55, 66 }, { 70, 110 } } } },
	{ Name = "ScreenSides150", P = at(0), S = { Pad = 20, Width = 60, Height = 150, Gaps = { { 55, 66 }, { 70, 110 } } } },
	{ Name = "Deep80+ScreenSides150", P = at(-80), S = { Pad = 20, Width = 60, Height = 150, Gaps = { { 55, 66 }, { 70, 110 } } } },
}
local winners = {}
for _, c in CANDIDATES do
	local count, rows = visibility(c.P, c.S)
	local bad = fits(c.P, c.S)
	print(string.format("  %s: sees Threshold %d/8 Roof %d/8 Crown %d/8; fit %s", c.Name, count.Threshold, count.Roof, count.Crown,
		#bad == 0 and "ok" or table.concat(bad, ", ")))
	print("    eyes T/R/C: " .. table.concat(rows, " "))
	if #bad == 0 and count.Threshold == 0 and count.Roof == 0 and count.Crown >= 4 then table.insert(winners, c.Name) end
end
print("  candidates that pass every check: " .. (#winners > 0 and table.concat(winners, ", ") or "none"))

-- Regression guards on the baseline measurement (Sol, v9 probe): the rim hides the threshold, nothing hides roof or crown.
local cur = visibility(CANDIDATES[1].P, nil)
check("baseline: the rim hides the threshold from all 8 eyes", cur.Threshold == 0)
check("baseline: the roof and crown stand over the rim from all 8 eyes (the problem to solve)", cur.Roof == 8 and cur.Crown == 8)
check("the original hall remains available as a fallback", T.Model == "Bellwood_TempleHall")

-- Use the same cell centres and footprint as the gameplay fills so a continuous
-- analytic curve cannot hide a sightline through a gap between terrain cells.
local configured = B.ColossalTemple or { Across = 30, Along = -115, Lift = 2 }
local transform = place(configured)
local function ridgeTerrain(x: number, z: number): number
	local dx, dz = x - C.X, z - C.Z
	local lane, along = dx * ax + dz * az, dx * fx + dz * fz
	local fillLane = -620 + 20 * math.floor((lane + 630) / 20)
	local fillAlong = 574 + 14 * math.floor((along - 567) / 14)
	local base = L.carvedSurface(x, z, O.heightAt) or (O.heightAt(x, z) + 2)
	if fillLane < -620 or fillLane > 420 or fillAlong < 574 or fillAlong > 728 then return base end
	local height = L.colossalRidgeHeight(bw, C.X + ax * fillLane + fx * fillAlong, C.Z + az * fillLane + fz * fillAlong)
	return math.max(base, height or -math.huge)
end

local roadSightlines, exitSightlines = 0, 0
local exitEyeY = bw.Origin.Y + bw.Tunnel.Passage[#bw.Tunnel.Passage][3]
for _, t in TARGETS do
	local tx, ty, tz = transform(t[1], t[2], t[3])
	for _, e in eyes do
		local ey = O.heightAt(e[1], e[2]) + 7.5
		local clear = true
		for i = 1, 250 do
			local a = i / 250
			if ridgeTerrain(e[1] + a * (tx - e[1]), e[2] + a * (tz - e[2])) >= ey + a * (ty - ey) then
				clear = false
				break
			end
		end
		if clear then roadSightlines += 1 end
	end
	local distance = math.sqrt((tx - exitX) ^ 2 + (tz - exitZ) ^ 2)
	local clear = true
	for i = 1, 250 do
		local a = (12 + (distance - 12) * i / 250) / distance
		if ridgeTerrain(exitX + a * (tx - exitX), exitZ + a * (tz - exitZ)) >= exitEyeY + a * (ty - exitEyeY) then
			clear = false
			break
		end
	end
	if clear then exitSightlines += 1 end
end
check("the ridge screens all 24 model sightlines from the road", roadSightlines == 0)
check("the stairs, top roof and crown emerge together past the passage", exitSightlines == 3)
print(string.format("  stepped crest: %d/%d road sightlines clear, %d/3 exit sightlines clear",
	roadSightlines, #eyes * 3, exitSightlines))

-- Footings (win-112): each piece's scaled footprint sits inside the shore, off the gate towers, the causeway and the stair, against
-- the back (Z <= -300) or a flank (|X| >= 230).
do
	local F = B.ColossalTemple.Footings
	local toWorld = place(B.ColossalTemple)
	local ca, cb = route.Causeway.A, route.Causeway.B
	local function segD(x, z)
		local dx, dz = cb.X - ca.X, cb.Z - ca.Z
		local t = math.clamp(((x - ca.X) * dx + (z - ca.Z) * dz) / (dx * dx + dz * dz), 0, 1)
		return math.sqrt((x - ca.X - t * dx) ^ 2 + (z - ca.Z - t * dz) ^ 2)
	end
	local inside, offGate, offCause, onWall, offStair, minGate = true, true, true, true, true, math.huge
	for _, f in F.Pieces do
		local x, _, z = toWorld(-f.X, f.Z, 0)
		inside = inside and L.basinEllipse(bw, x, z, -f.R) < 1
		local g = math.sqrt((x - gate.X) ^ 2 + (z - gate.Z) ^ 2) - B.Gate.Radius - f.R
		minGate = math.min(minGate, g)
		if g < 0 then print(string.format("    gate overlap %s X%d Z%d: %.0f", f.Model, f.X, f.Z, g)) end
		offGate = offGate and g >= 0
		offCause = offCause and segD(x, z) >= f.R + 8
		onWall = onWall and (f.Z <= -300 or math.abs(f.X) >= 230)
		offStair = offStair and not (math.abs(f.X) < 120 and f.Z > 150)
	end
	check("footings: every piece inside the shore by its footprint", inside)
	check("footings: clear of the gate towers", offGate)
	check("footings: clear of the causeway", offCause)
	check("footings: each stands against the back or a flank, never on the stair", onWall and offStair)
	print(string.format("  footings: %d pieces, nearest gate clearance %.0f studs", #F.Pieces, minGate))
end

print(string.format("bellwood fit: %d passed, %d failed", passed, failed))
if failed > 0 then error("bellwood fit failed") end

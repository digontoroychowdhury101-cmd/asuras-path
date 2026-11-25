--!nonstrict
-- Landmark placement (LANDMARK-BUILD-SPEC "Shared rules"): src/shared/LandmarkLayout against the real Overworld.
-- Run: python3 tools/lune_compat.py tools/test_landmark_layout.luau
local O = require("../src/shared/Overworld")
local L = require("../src/shared/LandmarkLayout")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- Everything the spec says a landmark must keep clear of.
local points = {}
local function add(kind, p) if p then table.insert(points, { kind = kind, x = p.X, z = p.Z }) end end
for id, a in O.Altars do add("altar " .. id, a.Placement or a.Position) end
for id, n in O.Nodes do add("node " .. id, n.Position) end
for _, p in O.POIs do add("poi " .. p.Id, p.Position) end
for id, l in O.Landmarks do add("landmark " .. id, l.Position) end
for id, c in O.Caches do add("cache " .. id, c.Position) end
for id, l in O.Lore do add("lore " .. id, l.Position) end
for id, r in O.Rings do add("ring " .. id, r) end
for id, m in O.Minibosses do add("miniboss " .. id, m.Placement) end
for _, s in O.EncounterSpots do add("encounter " .. s.Spawn, s.Placement) end
add("Vesperhold", O.Vesperhold)

local D = O.terrainData()
local roads, rivers = {}, {}
for _, r in D.Roads do for k = 2, #r.Points do table.insert(roads, { r.Points[k - 1], r.Points[k] }) end end
for _, rv in O.TerrainDef.Rivers do for k = 2, #rv.Points do table.insert(rivers, { rv.Points[k - 1], rv.Points[k] }) end end
local function segDist(x, z, segs)
	local best, bx, bz = math.huge, 0, 0
	for _, s in segs do
		local a, b = s[1], s[2]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local t = math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / math.max(dx * dx + dz * dz, 1e-6), 0, 1)
		local px, pz = a[1] + t * dx, a[2] + t * dz
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < best then best, bx, bz = d, px, pz end
	end
	return best, bx, bz
end

for id, lm in L.Landmarks do
	local o = lm.Origin
	local region = O.Regions[lm.Region].Bounds
	local function inside(x, z, margin)
		return math.abs(x - region.Center.X) <= region.Size.X / 2 - margin and math.abs(z - region.Center.Z) <= region.Size.Z / 2 - margin
	end
	-- 1. Region box: the footprint and the whole hidden basin sit inside the region with a border band to spare.
	check(id .. " origin inside its region box", inside(o.X, o.Z, 150))
	local b = L.basinCentre(lm)
	for _, c in L.basinCorners(lm) do check(id .. " basin corner inside the region box", inside(c.X, c.Z, 100)) end

	-- 2. Clearance: >= 250 studs from every altar, node, POI, landmark, cache, lore, ring and encounter (face and basin).
	local nearest, nearestKind = math.huge, ""
	for _, p in points do
		for _, q in { o, b } do
			local d = math.sqrt((q.X - p.x) ^ 2 + (q.Z - p.z) ^ 2)
			if d < nearest then nearest, nearestKind = d, p.kind end
		end
	end
	print(string.format("  %s: nearest placed thing %.0f studs (%s)", id, nearest, nearestKind))
	check(id .. " keeps >= 250 studs from altars, collectibles and landmarks", nearest >= lm.MinClearance)

	-- 3. Roads: in sight but not on it; the basin is far from every road and river (hidden from the route).
	local dr, rx, rz = segDist(o.X, o.Z, roads)
	print(string.format("  %s: road %.0f studs from the face, basin %.0f from roads / %.0f from rivers", id, dr,
		(segDist(b.X, b.Z, roads)), (segDist(b.X, b.Z, rivers))))
	check(id .. " footprint stays off the road (road half + blend + footprint radius)",
		dr >= lm.FootprintRadius + O.TerrainDef.Road.Half + 40)
	check(id .. " face is within road sight (<= 250 studs)", dr <= 250)
	check(id .. " basin is >= 250 studs from every road", segDist(b.X, b.Z, roads) >= 250)
	check(id .. " basin is >= 200 studs from every river", segDist(b.X, b.Z, rivers) >= 200)

	-- 4. Orientation: the tunnel mouth faces the nearest road; the basin lies directly behind it.
	local fx, fz = L.front(lm)
	local tx, tz = (rx - o.X) / dr, (rz - o.Z) / dr
	check(id .. " tunnel mouth faces the nearest road (dot >= 0.9)", fx * tx + fz * tz >= 0.9)
	local bx, bz = (b.X - o.X), (b.Z - o.Z)
	local bl = math.sqrt(bx * bx + bz * bz)
	check(id .. " basin is directly behind the face", (bx * fx + bz * fz) / bl <= -0.99)

	-- 5. Ground: origin Y on the terrain and the footprint flat enough to seat the shell (it sinks 0.6 below grade).
	local h = O.heightAt(o.X, o.Z)
	check(id .. " origin Y matches terrain height (+-3)", math.abs(o.Y - h) <= 3)
	local spread = 0
	for _, off in { { 60, 0 }, { -60, 0 }, { 0, 50 }, { 0, -50 }, { 45, 40 }, { -45, -40 } } do
		spread = math.max(spread, math.abs(O.heightAt(o.X + off[1], o.Z + off[2]) - h))
	end
	check(id .. " footprint terrain within +-8 studs", spread <= 8)
end

-- 6. Landmarks keep 250 studs from each other unless one attaches to another.
local ids = {}
for id in L.Landmarks do table.insert(ids, id) end
for i = 1, #ids do
	for j = i + 1, #ids do
		local a, b = L.Landmarks[ids[i]].Origin, L.Landmarks[ids[j]].Origin
		check(ids[i] .. " / " .. ids[j] .. " >= 250 studs apart", math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) >= 250)
	end
end

-- 7. Bellwood kit numbers stay in step with the Blender kit (tools/blender/landmarks/bellwood_giant_face.py).
local bw = L.Landmarks.Bellwood
check("Bellwood tunnel >= 14 wide and 16 high", bw.Tunnel.Width >= 14 and bw.Tunnel.Height >= 16)
check("Bellwood basin is 1400 x 1120 (BELLWOOD_EXPANSION_PLAN)", bw.Basin.Width == 1400 and bw.Basin.Depth == 1120 and bw.Basin.Back == 750
	and bw.Basin.Thick == 40 and bw.Basin.RimRise == 60 and bw.Basin.Segments == 320 and bw.Basin.Shelf == 60)
check("Bellwood tunnel leads down underground at a walkable grade", bw.Tunnel.End.Z < -20
	and bw.Tunnel.Descent / bw.Tunnel.Run <= O.TerrainDef.Road.MaxGrade)
check("Bellwood kit pieces carry a foot frame", bw.Pieces.Face.Foot ~= nil and bw.Pieces.Crown.Foot ~= nil)
local last = bw.Tunnel.Path[#bw.Tunnel.Path]
check("Bellwood tunnel path ends 8 above the End floor point", last[1] == bw.Tunnel.End.X and last[2] == bw.Tunnel.End.Y
	and last[3] - 8 == bw.Tunnel.End.Z)

-- Lantern niches sit inside the bore, off the walk line: 3..Radius-2 studs from the centre polyline (3D, kit axes).
local function toPath(q)
	local best = math.huge
	local P = bw.Tunnel.Path
	for i = 2, #P do
		local a, b = P[i - 1], P[i]
		local d = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
		local len2 = d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2
		local t = math.clamp(((q[1] - a[1]) * d[1] + (q[2] - a[2]) * d[2] + (q[3] - a[3]) * d[3]) / len2, 0, 1)
		best = math.min(best, math.sqrt((a[1] + d[1] * t - q[1]) ^ 2 + (a[2] + d[2] * t - q[2]) ^ 2 + (a[3] + d[3] * t - q[3]) ^ 2))
	end
	return best
end
local lit = #bw.Tunnel.Lanterns >= 2
for _, q in bw.Tunnel.Lanterns do
	local d = toPath(q)
	if d < 3 or d > bw.Tunnel.Radius - 2 then lit = false end
end
check("Bellwood tunnel has two lantern niches inside the bore, off the walk line", lit)
check("Bellwood grove clears the face footprint and reaches past it", bw.Grove.Clear < bw.FootprintRadius and bw.Grove.R > bw.FootprintRadius + 30)

-- Hidden basin (spec): rim cliffs block every road's view of the temple. The 8 road points nearest the basin centre (80+ apart)
-- look from eye height at three temple-top targets (centre and +-50 across); the surface along each line is the basin floor inside,
-- the rim top in the rim band and the written ground (heightAt + 2) outside, and it must rise to the line somewhere.
do
	local floorY = L.basinLevels(bw)
	local c = L.basinCentre(bw)
	local fx, fz = L.front(bw)
	local rx, rz = -fz, fx
	local function surface(x, z)
		if L.basinEllipse(bw, x, z) < 1 then return floorY end
		if L.basinEllipse(bw, x, z, bw.Basin.Thick) < 1 then
			local dx, dz = x - c.X, z - c.Z
			local theta = math.atan2((dx * fx + dz * fz) / (bw.Basin.Depth / 2), (dx * rx + dz * rz) / (bw.Basin.Width / 2))
			return L.rimTop(bw, theta, O.heightAt)
		end
		return O.heightAt(x, z) + 2
	end
	local cands = {}
	for _, sg in roads do
		local p, q = sg[1], sg[2]
		local n = math.max(1, math.floor(math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2) / 20))
		for k = 0, n do
			local x, z = p[1] + (q[1] - p[1]) * k / n, p[2] + (q[2] - p[2]) * k / n
			table.insert(cands, { x, z, math.sqrt((x - c.X) ^ 2 + (z - c.Z) ^ 2) })
		end
	end
	table.sort(cands, function(u, v) return u[3] < v[3] end)
	local eyes = {}
	for _, e in cands do
		local far = true
		for _, k in eyes do if math.sqrt((k[1] - e[1]) ^ 2 + (k[2] - e[2]) ^ 2) < 80 then far = false end end
		if far then table.insert(eyes, e) end
		if #eyes == 8 then break end
	end
	local seen = {}
	for _, e in eyes do
		local ey = O.heightAt(e[1], e[2]) + 7.5
		for _, off in { -50, 0, 50 } do
			local tx, tz, ty = c.X + rx * off, c.Z + rz * off, floorY + bw.Basin.TempleTop
			local blocked = false
			for i = 1, 199 do
				local t = i / 200
				local x, z = e[1] + (tx - e[1]) * t, e[2] + (tz - e[2]) * t
				if surface(x, z) >= ey + (ty - ey) * t then blocked = true; break end
			end
			if not blocked then table.insert(seen, string.format("(%.0f,%.0f)->%d", e[1], e[2], off)) end
		end
	end
	print(string.format("  Bellwood basin: %d road eyes, nearest %.0f studs; unblocked %s", #eyes, eyes[1][3], table.concat(seen, " ")))
	check("8 road points sample the basin's surroundings", #eyes == 8)
	check("rim cliffs hide the temple from all 8 road points", #seen == 0)
	local ok = true
	for _, th in { 0, math.pi / 2, math.pi, 3 * math.pi / 2 } do
		local x, z = L.basinRing(bw, th, 0)
		if O.heightAt(x, z) - floorY < 20 then ok = false end
	end
	check("the basin floor is sunk 20+ studs under the surrounding ground", ok)
	local pa, last = bw.Tunnel.Passage, bw.Tunnel.Path[#bw.Tunnel.Path]
	local endW = { X = 0, Z = 0 }
	do
		local q = pa[#pa]
		local o, a = bw.Origin, math.rad(bw.Yaw)
		-- kit (x, y) -> world XZ: model (-x, ., y) rotated by Yaw
		endW.X = o.X + (-q[1]) * math.cos(a) + q[2] * math.sin(a)
		endW.Z = o.Z - (-q[1]) * math.sin(a) + q[2] * math.cos(a)
	end
	local level = true
	for _, q in pa do if q[3] ~= last[3] then level = false end end
	check("passage continues the bore from its End", pa[1][1] == last[1] and pa[1][2] == last[2] and pa[1][3] == last[3])
	local walk = bw.Origin.Y + last[3] - 8
	check("passage is level, its floor 0..2 over the lake bed (wading in)", level and walk - floorY >= 0 and walk - floorY <= 2)
	check("lake bed top is on the 4-stud voxel grid (water shares no voxel with the bed)", floorY % 4 == 0)
	check("passage ends inside the basin", L.basinEllipse(bw, endW.X, endW.Z) < 1)
end

-- 8. The Sunken Temple hall (tools/blender/landmarks/bellwood_temple_hall.py) stands in the deep middle of the lake, its stone
-- platform just over the water, its roof under TempleTop so no road sees it.
do
	local T = bw.Basin.Temple
	local floorY, waterY = L.basinLevels(bw)
	local s = L.templeSpot(bw)
	check("temple hall is a kit piece with a foot frame", T and T.Model == "Bellwood_TempleHall" and T.Foot ~= nil)
	local inDish = true
	for k = 0, 15 do
		local a = k / 16 * 2 * math.pi
		if L.basinEllipse(bw, s.X + T.Radius * math.cos(a), s.Z + T.Radius * math.sin(a), -bw.Basin.Shelf) >= 1 then inDish = false end
	end
	check("temple footprint stays in the deep middle of the lake", inDish)
	check("temple platform top is just over the water (0..1.5 above)", s.Y + T.Deck - waterY >= 0 and s.Y + T.Deck - waterY <= 1.5)
	check("temple roof stays under TempleTop", s.Y + T.Height <= floorY + bw.Basin.TempleTop)
end

-- The assembled temple keeps the old hall placement as a fallback.
do
	local floor = L.basinLevels(bw)
	local c = L.basinCentre(bw)
	local fx, fz = L.front(bw)
	local function height(across, along)
		return L.colossalRidgeHeight(bw, c.X - fz * across + fx * along, c.Z + fx * across + fz * along)
	end
	check("colossal ridge stands above the old basin rim on the road side", height(-100, 631) > floor + 240)
	check("colossal ridge leaves the passage mouth and inner lake clear", height(0, 750) == nil and height(0, 535) == nil)
	local candidate = L.templeSpot(bw, { Across = 30, Along = -115, Lift = 0 })
	check("colossal temple origin stays in deep water", L.basinEllipse(bw, candidate.X, candidate.Z, -bw.Basin.Shelf) < 1
		and candidate.Y == floor)
end

-- 9. The Sunken Temple's gate towers (tools/blender/landmarks/bellwood_gate_towers.py, concept bellwood_3 left third): on the left of
-- the exit view, front steps wading in at the shore, the stair climbing away from the lake to a landing inside the bowl near the shore.
do
	local G, T = bw.Basin.Gate, bw.Basin.Temple
	local floorY, waterY = L.basinLevels(bw)
	local s, t, c = L.gateSpot(bw), L.templeSpot(bw), L.basinCentre(bw)
	check("gate towers are a kit piece with a foot frame", G and G.Model == "Bellwood_GateTowers" and G.Foot ~= nil)
	-- the passage exit in world XZ (kit x, y -> model -x, y; yawed)
	local q, o, a = bw.Tunnel.Passage[#bw.Tunnel.Passage], bw.Origin, math.rad(bw.Yaw)
	local ex, ez = o.X + (-q[1]) * math.cos(a) + q[2] * math.sin(a), o.Z - (-q[1]) * math.sin(a) + q[2] * math.cos(a)
	local lx, lz = c.X - ex, c.Z - ez
	local ll = math.sqrt(lx * lx + lz * lz)
	lx, lz = lx / ll, lz / ll
	local vx, vz = s.X - ex, s.Z - ez
	local vl = math.sqrt(vx * vx + vz * vz)
	vx, vz = vx / vl, vz / vl
	local ang = math.deg(math.acos(math.clamp(vx * lx + vz * lz, -1, 1)))
	-- view right = look x up = (-lz, lx) in XZ
	check(string.format("gate stands left of centre in the exit view (%.1f deg)", ang), vx * -lz + vz * lx < 0 and ang >= 6 and ang <= 35)
	-- gate model axes in world XZ: front (+Z) toward the basin centre, side across it
	local ux, uz = c.X - s.X, c.Z - s.Z
	local ul = math.sqrt(ux * ux + uz * uz)
	ux, uz = ux / ul, uz / ul
	local function at(x, z) return s.X + ux * z - uz * x, s.Z + uz * z + ux * x end
	local sx, sz = at(0, G.Steps)
	check("gate pivot is under the water and its front step stands in the lake", s.Y < waterY and s.Y >= floorY - 1
		and L.basinEllipse(bw, sx, sz) < 1)
	local inside, nearShore = true, false
	for _, side in { -1, 1 } do
		local bx, bz = at(side * G.Width / 2, G.Back)
		if L.basinEllipse(bw, bx, bz) >= 1 then inside = false end
		if L.basinEllipse(bw, bx, bz, -10) >= 1 then nearShore = true end
	end
	-- the enlarged basin puts the gate in the lake (plan: across 150 left of centre, 140 toward the face); the causeway (section 10) links it to the shore
	check("gate landing stays inside the bowl (not buried in the rim); a causeway, not the shore, carries it out", inside and not nearShore)
	check("gate landing stands over the water", s.Y + G.Landing > waterY + 8)
	-- TempleTop kept the old open-sky hall hidden from the roads; under the Hollow's vault nothing shows, so it binds only without Cavern
	check("gate towers stay under TempleTop (open-sky basin only)", bw.Basin.Cavern ~= nil or s.Y + G.Height <= floorY + bw.Basin.TempleTop)
	-- mac-99 reveal capture: at 1x the towers stood 51 studs beside a 795-stud colossal temple, a speck at its foot instead of the
	-- bellwood_3 left-third mass; the kit is placed at Scale, and every gate number here is already in scaled studs.
	local S = G.Scale or 1
	check(string.format("gate towers read beside the colossal temple (%.0f studs tall, scale %.1f)", G.Height, S), G.Height >= 140 and S >= 2.5)
	check(string.format("scaled gate stair stays walkable (riser %.2f studs)", 0.5 * S), 0.5 * S <= 1.6)
	check("gate numbers are the 1x kit's at Scale", math.abs(G.Landing - 14 * S) < 1e-6 and math.abs(G.Back + 40.8 * S) < 1e-6
		and math.abs(G.Steps - 10 * S) < 1e-6 and math.abs(G.Foot.Z + 13.655 * S) < 1e-6)
	check("gate and temple footprints do not overlap", math.sqrt((s.X - t.X) ^ 2 + (s.Z - t.Z) ^ 2) > G.Radius + T.Radius)
	check("gate keeps clear of the tunnel exit", math.sqrt((s.X - ex) ^ 2 + (s.Z - ez) ^ 2) > G.Radius + bw.Tunnel.Width)
end


-- 10. Enlarged 1400 x 1120 basin, pre-carve gates (BELLWOOD_EXPANSION_PLAN sections 3 and 5): footprint, exit/gate/temple, the walkable route.
do
	local Thick, Margin = bw.Basin.Thick, 110
	local c = L.basinCentre(bw)
	check(string.format("basin centre is the plan's best fit near -4178 / -2298 (%.0f / %.0f)", c.X, c.Z), math.abs(c.X + 4178) < 2 and math.abs(c.Z + 2298) < 2)
	-- the whole footprint (bowl + rim + a 110-stud margin) keeps clear of every placed thing, not just its centre
	local function clear(x: number, z: number, extra: number?): boolean
		return L.basinEllipse(bw, x, z, Thick + Margin + (extra or 0)) >= 1
	end
	local worstKind, worstE = "", math.huge
	for _, p in points do
		local e = L.basinEllipse(bw, p.x, p.z, Thick + Margin)
		if e < worstE then worstE, worstKind = e, p.kind end
	end
	check("basin footprint + 110 stays clear of every altar, node, POI, landmark, cache, lore, ring, miniboss, encounter and Vesperhold (" .. worstKind .. ")", worstE >= 1)
	local V = O.Vesperhold
	check("basin footprint is clear of Vesperhold's gate and ridge (ellipse " .. string.format("%.1f", L.basinEllipse(bw, V.X, V.Z, Thick + Margin)) .. ")",
		clear(V.X, V.Z) and clear(V.X - 490, V.Z) and clear(V.X + 430, V.Z))
	local arena, gate = O.Barrier.Arena, O.Barrier.Gate
	check("basin footprint is clear of the Shen arena, barrier gate and its approach", clear(arena.Center.X, arena.Center.Z, 100)
		and clear(gate.Placement.X, gate.Placement.Z, 100) and clear(gate.Outside.X, gate.Outside.Z, 100))
	local reservedOk = true
	for _, ra in O.ReservedArenas do reservedOk = reservedOk and clear(ra.Arena.Center.X, ra.Arena.Center.Z, 90) end
	check("basin footprint is clear of every reserved boss arena", reservedOk)
	local okW, W = pcall(require, "../src/shared/WorldDefinitions")
	local sanct = if okW then (W :: any).Regions.Sanctuary.Bounds else { Center = { X = 0, Z = 650 }, Size = { X = 600, Z = 920 } }
	local sOk = true
	for _, sx in { -1, 0, 1 } do for _, sz in { -1, 0, 1 } do
		sOk = sOk and clear(sanct.Center.X + sx * sanct.Size.X / 2, sanct.Center.Z + sz * sanct.Size.Z / 2)
	end end
	check("basin footprint is clear of the lobby / Sanctuary region box", sOk)
	-- roads and rivers: the outer slope's foot (Thick + 120 out) and the rim stay off every road and river
	local minRoad, minRiver = math.huge, math.huge
	for k = 0, 359 do
		for _, out in { 0, Thick, Thick + 120 } do
			local x, z = L.basinRing(bw, math.rad(k), out)
			minRoad, minRiver = math.min(minRoad, (segDist(x, z, roads))), math.min(minRiver, (segDist(x, z, rivers)))
		end
	end
	print(string.format("  Bellwood basin outer edge: %.0f studs from the nearest road, %.0f from a river", minRoad, minRiver))
	check("the basin's outer slope foot is >= 110 studs from every road", minRoad >= Margin)
	check("the basin's outer slope foot is >= 110 studs from every river", minRiver >= Margin)
	-- the whole ellipse stays in the region box with a border band
	local rb = O.Regions[bw.Region].Bounds
	local inBox = true
	for k = 0, 359 do
		local x, z = L.basinRing(bw, math.rad(k), Thick + 120)
		inBox = inBox and math.abs(x - rb.Center.X) <= rb.Size.X / 2 - 100 and math.abs(z - rb.Center.Z) <= rb.Size.Z / 2 - 100
	end
	check("the basin and its slopes sit inside the Forest region box", inBox)
	-- the carve strips air to the highest rim top: no ground may stand above it inside the bowl
	local maxTop, maxGround = -math.huge, -math.huge
	for k = 0, bw.Basin.Segments - 1 do maxTop = math.max(maxTop, L.rimTop(bw, k / bw.Basin.Segments * 2 * math.pi, O.heightAt)) end
	for k = 0, 359, 3 do for f = 0.05, 1, 0.05 do
		local rx, rz = L.basinRing(bw, math.rad(k), 0)
		maxGround = math.max(maxGround, O.heightAt(c.X + (rx - c.X) * f, c.Z + (rz - c.Z) * f))
	end end
	check("no ground inside the bowl rises above the highest rim top (the air strips would leave a hill)", maxGround < maxTop)
	-- the Giant Face keeps its footprint free of the rim itself (the slope foot may rise behind it; reported)
	local ox2, oz2 = bw.Origin.X, bw.Origin.Z
	local rimNear = math.huge
	for k = 0, 719 do
		local x, z = L.basinRing(bw, k / 720 * 2 * math.pi, Thick)
		rimNear = math.min(rimNear, math.sqrt((x - ox2) ^ 2 + (z - oz2) ^ 2))
	end
	check(string.format("the rim's outer edge stays outside the face footprint (%.0f > %d)", rimNear, bw.FootprintRadius), rimNear > bw.FootprintRadius + 40)

	-- tunnel exit: the passage crosses the rim, the exit opens inside the bowl at the front shore
	local pa = bw.Tunnel.Passage
	local function kitXZ(q: { number }): (number, number)
		local a = math.rad(bw.Yaw)
		return bw.Origin.X + (-q[1]) * math.cos(a) + q[2] * math.sin(a), bw.Origin.Z - (-q[1]) * math.sin(a) + q[2] * math.cos(a)
	end
	local ex, ez = kitXZ(pa[#pa])
	local shoreDist = math.huge
	for k = 0, 719 do
		local x, z = L.basinRing(bw, k / 720 * 2 * math.pi, 0)
		shoreDist = math.min(shoreDist, math.sqrt((x - ex) ^ 2 + (z - ez) ^ 2))
	end
	check(string.format("tunnel exit is inside the bowl, %.0f studs from the front shore (10..40)", shoreDist), L.basinEllipse(bw, ex, ez) < 1 and shoreDist >= 10 and shoreDist <= 40)
	local pre = pa[#pa - 1]
	local px, pz = kitXZ(pre)
	local crossed = false
	for i = 1, #pa do
		local qx, qz = kitXZ(pa[i])
		if L.basinEllipse(bw, qx, qz) >= 1 and L.basinEllipse(bw, qx, qz, Thick) < 1 then crossed = true end
	end
	check("the passage crosses the rim band before it opens into the bowl", crossed and L.basinEllipse(bw, px, pz) >= 0.5)
	local tx, tz = L.templeSpot(bw).X, L.templeSpot(bw).Z
	check("temple hall stands in the bowl, right of the exit axis (plan: stair foot at 20, -110)", L.basinEllipse(bw, tx, tz) < 0.2 and
		(tx - c.X) * -select(2, L.front(bw)) + (tz - c.Z) * (L.front(bw)) < 0)
	local gs = L.gateSpot(bw)
	check("gate towers stand in the bowl, left third of the exit view", L.basinEllipse(bw, gs.X, gs.Z) < 0.2)

	-- the route (plan section 3)
	local R = bw.Basin.Route
	local r = L.route(bw, O.heightAt)
	local pts = r.Points
	local first, last = pts[1], pts[#pts]
	local frontX, frontZ = L.front(bw)
	local g = L.gateSpot(bw)
	check("route starts at the gate stair's landing level", math.abs(first.Y - (g.Y + bw.Basin.Gate.Landing)) < 0.01
		and math.sqrt((first.X - g.X) ^ 2 + (first.Z - g.Z) ^ 2) < 60 * (bw.Basin.Gate.Scale or 1))
	local worst, worstRamp, maxGap, jump = 0, 0, 0, 0
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local d = math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2)
		maxGap = math.max(maxGap, d)
		if d > 1e-6 then
			local deg = math.deg(math.atan(math.abs(b.Y - a.Y) / d))
			worst = math.max(worst, deg)
			if b.Kind == "leg" or b.Kind == "causeway" or b.Kind == "landing" or b.Kind == "crest" then worstRamp = math.max(worstRamp, deg) end
		end
	end
	print(string.format("  Bellwood route: %d points, %d legs of %.1f rise, steepest %.1f deg (built ramps %.1f), crest %.1f", #pts, #r.Legs, r.Rise, worst, worstRamp, r.Crest))
	check(string.format("route gradient never exceeds %d deg between samples (%.1f)", R.Max, worst), worst <= R.Max)
	check(string.format("built ramps stay within the 28 deg target (%.1f)", worstRamp), worstRamp <= 28)
	check("route is continuous: no sample gap over Step + 0.01", maxGap <= R.Step + 0.01)
	check("route is at least 12 wide, landings at least 16 x 16", R.Width >= 12 and R.Pad >= 16 and #r.Landings == #r.Legs)
	local landOk, treadOk, prevZ = true, true, r.Deck
	for i, leg in r.Legs do
		treadOk = treadOk and math.abs(leg.Z0 - prevZ) <= 1 and leg.Z1 > leg.Z0 and math.abs(leg.T1 - leg.T0 - r.Run * (if leg.T1 > leg.T0 then 1 else -1)) < 1e-6
		prevZ = leg.Z1
		local ld = r.Landings[i]
		if ld then landOk = landOk and math.abs(ld.Z - leg.Z1) <= 1 and ld.T1 - ld.T0 >= 16 and ld.N1 - ld.N0 >= 16 end
	end
	check("no gap over 1 stud between a landing and its treads; each tread climbs one Rise", landOk and treadOk)
	check("the last tread tops out on the rim segment's cap", math.abs(r.Legs[#r.Legs].Z1 - r.Crest) < 0.01
		and math.abs(r.Crest - L.rimTop(bw, r.Segment / bw.Basin.Segments * 2 * math.pi, O.heightAt)) < 0.01)
	-- every tread and landing corner stands inside the bowl with a margin (nothing is carved into the rim or built outside it)
	local inside = true
	local function corner(t, n) local x, z = L.routeAt(r, t, n) inside = inside and L.basinEllipse(bw, x, z, -4) < 1 end
	for _, leg in r.Legs do for _, t in { leg.T0, leg.T1 } do for _, s in { -1, 1 } do corner(t, leg.Lane + s * R.Width / 2) end end end
	for _, ld in r.Landings do if not ld.Rim then for _, t in { ld.T0, ld.T1 } do for _, n in { ld.N0, ld.N1 } do corner(t, n) end end end end
	for _, p in pts do
		if p.Kind == "causeway" or p.Kind == "leg" or p.Kind == "landing" then inside = inside and L.basinEllipse(bw, p.X, p.Z, -4) < 1 end
	end
	check("treads, landings and causeway stay inside the bowl", inside)
	-- lanes are one tread wide apart, so legs never overlap
	local lanesOk = true
	for i = 2, #r.Legs do lanesOk = lanesOk and math.abs(r.Legs[i - 1].Lane - r.Legs[i].Lane) >= R.Width - 1e-6 end
	check("neighbouring legs sit a full width apart", lanesOk)
	-- the crossing runs through the middle of the rim segment (t = 0): the top landing is centred on it and reaches back into the cap
	local top = r.Landings[#r.Landings]
	check("the top landing is centred on the rim segment and reaches the cap", top.Rim and math.abs((top.T0 + top.T1) / 2) < 1e-6 and top.N0 <= 0 and top.Z == r.Crest)
	-- the route reaches the rim cap flat, goes down the slope and ends on natural forest ground
	local kinds = {}
	for _, p in pts do kinds[p.Kind] = (kinds[p.Kind] or 0) + 1 end
	check("route runs causeway, legs, landings, crest, slope and forest", kinds.causeway and kinds.leg and kinds.landing and kinds.crest and kinds.slope and kinds.forest)
	check("route ends in the forest, outside the rim and slope, on the written ground", last.Kind == "forest" and L.basinEllipse(bw, last.X, last.Z, Thick + 100) >= 1
		and math.abs(last.Y - O.heightAt(last.X, last.Z)) < 0.01)
	local lane = L.routeLane(r)
	check("the forest lane is a segment outside the basin for SliceDressing", math.sqrt((lane[3] - lane[1]) ^ 2 + (lane[4] - lane[2]) ^ 2) >= R.Forest - 10
		and L.basinEllipse(bw, lane[1], lane[2], Thick) >= 1)
	local firstSlope
	for _, p in pts do
		if p.Kind == "slope" then firstSlope = p; break end
	end
	check("the dressing lane protects the descent as well as the forest stretch",
		firstSlope and lane[1] == firstSlope.X and lane[2] == firstSlope.Z)
	-- the route follows the slope wedge World.basin writes; carvedSurface quantises to the same chord
	local agree = true
	for _, p in pts do
		if p.Kind == "slope" then
			local cs = L.carvedSurface(p.X, p.Z, O.heightAt)
			if cs and math.abs(cs - p.Y) > 4 then agree = false end
		end
	end
	check("route slope samples match LandmarkLayout.carvedSurface within 4 studs", agree)
	-- not on a road: the route stays off the road band, and clear of every placed thing by 60
	local nearest = math.huge
	for _, p in pts do
		for _, q in points do nearest = math.min(nearest, math.sqrt((p.X - q.x) ^ 2 + (p.Z - q.z) ^ 2)) end
	end
	check(string.format("route keeps 60 studs from every altar, node and landmark (%.0f)", nearest), nearest >= 60)
end

-- win-85: the Hollow temple's maps rendered white for ~30 s when first seen. Clients start the download on the forest approach.
do
	local fake = {
		Bellwood_ColossalTemple = { A = { ColorMap = "rbxassetid://1", NormalMap = "rbxassetid://2", RoughnessMap = "rbxassetid://3", MetalnessMap = "rbxassetid://4" },
			B = { ColorMap = "rbxassetid://1", NormalMap = "rbxassetid://5", RoughnessMap = "rbxassetid://3" } },
		Bellwood_GateTowers = { C = { ColorMap = "rbxassetid://6" } },
		Bellwood_GiantFace = { D = { ColorMap = "rbxassetid://7" } },
	}
	local got, set = L.hollowMaps(fake), {}
	for _, id in got do set[id] = (set[id] or 0) + 1 end
	local ok = #got == 6 and not set["rbxassetid://7"]
	for i = 1, 6 do ok = ok and set["rbxassetid://" .. i] == 1 end
	check("hollowMaps: each temple and gate map once, nothing from other pieces", ok)
	local real = L.hollowMaps(require("../src/shared/LandmarkKitRegistry"))
	local hasStair = false
	for _, id in real do if id == "rbxassetid://101954435353952" then hasStair = true end end
	check(string.format("hollowMaps on the real registry covers the colossal pack (%d maps)", #real), #real > 400 and hasStair)
	local bw = L.Landmarks.Bellwood
	check("the Hollow preload starts at least 600 studs before the giant's face", (bw.Basin.Cavern.Preload or 0) >= bw.Basin.Back + 600)
end

print(string.format("landmark layout: %d passed, %d failed", passed, failed))
if failed > 0 then error("landmark layout failed") end

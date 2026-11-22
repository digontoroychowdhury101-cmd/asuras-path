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
check("Bellwood basin is 350 x 300", bw.Basin.Width == 350 and bw.Basin.Depth == 300)
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

print(string.format("landmark layout: %d passed, %d failed", passed, failed))
if failed > 0 then error("landmark layout failed") end

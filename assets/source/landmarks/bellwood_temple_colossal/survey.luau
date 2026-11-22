--!nonstrict
-- Landmark placement (LANDMARK-BUILD-SPEC "Shared rules"): src/shared/LandmarkLayout against the real Overworld.
-- Run: python3 tools/lune_compat.py tools/test_landmark_layout.luau
local O = require("../../src/shared/Overworld")
local L = require("../../src/shared/LandmarkLayout")

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


local lm = L.Landmarks.Bellwood
local fx, fz = L.front(lm)
local rx, rz = -fz, fx
local origin = lm.Origin
local forest = O.Regions.Forest.Bounds
local function sampleSegments(segments, margin)
	local out = {}
	for _, s in segments do
		local a, b = s[1], s[2]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local count = math.max(1, math.ceil(math.sqrt(dx * dx + dz * dz) / 12))
		for i = 0, count do
			table.insert(out, {x = a[1] + dx * i / count, z = a[2] + dz * i / count, margin = margin})
		end
	end
	return out
end
local corridors = sampleSegments(roads, 80)
for _, point in sampleSegments(rivers, 90) do table.insert(corridors, point) end
for _, point in points do table.insert(corridors, {x=point.x,z=point.z,margin=110}) end

local candidates = {}
for _, width in {1400, 1250, 1120, 1000, 900} do
	for _, depth in {1120, 1000, 900, 800} do
		for back = 650, 1150, 25 do
			for across = -400, 400, 25 do
				local x, z = origin.X - back * fx + across * rx, origin.Z - back * fz + across * rz
				local a, b = width / 2, depth / 2
				local halfX = math.abs(a * rx) + math.abs(b * fx)
				local halfZ = math.abs(a * rz) + math.abs(b * fz)
				if math.abs(x - forest.Center.X) + halfX > forest.Size.X / 2 - 120
					or math.abs(z - forest.Center.Z) + halfZ > forest.Size.Z / 2 - 120 then continue end
				local nearest = math.huge
				for _, p in corridors do
					local dx, dz = p.x - x, p.z - z
					local acrossDist, alongDist = dx * rx + dz * rz, dx * fx + dz * fz
					local score = (acrossDist / (a + p.margin)) ^ 2 + (alongDist / (b + p.margin)) ^ 2
					nearest = math.min(nearest, score)
					if nearest < 1 then break end
				end
				if nearest >= 1 then
					local front = back - b
					if front >= 190 then
						table.insert(candidates, {width=width,depth=depth,back=back,across=across,x=x,z=z,front=front,margin=nearest,
							score=width*depth - front*1000 - math.abs(across)*400})
					end
				end
			end
		end
	end
end
table.sort(candidates, function(a,b) return a.score > b.score end)
print(#candidates,"candidate footprints")
for i = 1, math.min(18,#candidates) do
	local c = candidates[i]
	print(string.format("%d by %d | back %d across %d centre %.0f %.0f | front %d | clearance %.2f", c.width,c.depth,c.back,c.across,c.x,c.z,c.front,c.margin))
end

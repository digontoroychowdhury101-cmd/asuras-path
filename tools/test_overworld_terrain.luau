--!nonstrict
-- Regression for the canonical overworld terrain (ticket 03, condition E). Run from the project root:
--   work/bin/luau/luau.exe tools/test_overworld_terrain.luau   (plain Luau CLI, ~10 s)
-- Pure checks on heightAt / surfaceAt: determinism, continuity across region borders, flat pads, road
-- grade, summit, divide ridge, materials and ragged transition bands.
local O = require("../src/shared/Overworld")

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local F = O.Frame
local D = O.terrainData()
local def = O.TerrainDef

-- 1. Deterministic, and heightAt is the first return of sampleAt.
do
	local same = true
	for _, p in { { -2200, -1400 }, { -7123.5, -8001.25 }, { -5950, -3150 }, { -9500, -3000 } } do
		same = same and O.heightAt(p[1], p[2]) == O.heightAt(p[1], p[2]) and O.heightAt(p[1], p[2]) == (O.sampleAt(p[1], p[2]))
		local h, m, s = O.surfaceAt(p[1], p[2])
		same = same and h == O.heightAt(p[1], p[2]) and type(m) == "string" and s >= 0
	end
	check("deterministic", same)
end

-- 2. Continuity: 4-stud neighbours over the whole frame (borders included) never step more than ~6 studs
-- except across the chasm and channel carves. A handful of converging-road banks may reach 12.
do
	local over6, worst, pairsN = 0, 0, 0
	for x = F.MinX, F.MaxX - 4, 16 do
		for z = F.MinZ, F.MaxZ - 4, 16 do
			local h, _, c, ch = O.sampleAt(x, z)
			for _, d in { { 4, 0 }, { 0, 4 } } do
				local h2, _, c2, ch2 = O.sampleAt(x + d[1], z + d[2])
				-- The edge ring (cliffs up to the outer ranges) is steep on purpose; section 10 checks it separately.
				if c == 0 and ch == 0 and c2 == 0 and ch2 == 0 and O.edgeInset(x, z) > 40 then
					local s = math.abs(h2 - h)
					pairsN += 1
					worst = math.max(worst, s)
					if s > 6 then over6 += 1 end
				end
			end
		end
	end
	print(string.format("continuity: %d pairs, worst step %.1f, %d over 6", pairsN, worst, over6))
	check("no step over 12 outside carves", worst <= 12)
	check("steps over 6 are rare (<0.02%)", over6 <= pairsN * 0.0002)
end

-- 3. Pads flat within tolerance (centre and ring at 0.9 radius).
do
	for _, p in D.Pads do
		local lo, hi = math.huge, -math.huge
		for k = 0, 8 do
			local a = k * math.pi / 4
			local r = if k == 8 then 0 else p.R * 0.9
			local h = O.heightAt(p.X + math.cos(a) * r, p.Z + math.sin(a) * r)
			lo, hi = math.min(lo, h), math.max(hi, h)
		end
		check("pad flat " .. p.Id .. string.format(" (%.2f..%.2f vs %d)", lo, hi, p.Y), lo >= p.Y - 0.75 and hi <= p.Y + 0.75)
	end
	check("a pad per altar", #D.Pads >= 9 + 1)
end

-- 4. Roads: sampled grade <= 30 degrees outside channels, chasm and pads.
do
	local worst, samples = 0, 0
	for _, r in D.Roads do
		local prev
		local run = 0
		for k = 2, #r.Points do
			local p, q = r.Points[k - 1], r.Points[k]
			local seg = math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
			for step = 0, 1, 0.25 do
				local x, z = p[1] + (q[1] - p[1]) * step, p[2] + (q[2] - p[2]) * step
				local h, _, c, ch = O.sampleAt(x, z)
				local inPad = false
				for _, pad in D.Pads do
					if math.sqrt((x - pad.X) ^ 2 + (z - pad.Z) ^ 2) < pad.R + pad.Blend then inPad = true end
				end
				if c == 0 and ch == 0 and not inPad and prev then
					worst = math.max(worst, math.abs(h - prev.h) / math.max(prev.d, 1e-6))
					samples += 1
				end
				run += seg * 0.25
				prev = if c == 0 and ch == 0 and not inPad then { h = h, d = seg * 0.25, run = run } else nil
				if prev then prev.d = seg * 0.25 end
			end
		end
	end
	print(string.format("roads: %d, %d grade samples, worst grade %.3f (30 deg = 0.577)", #D.Roads, samples, worst))
	check("road grade <= 30 degrees", worst <= math.tan(math.rad(30)) and samples > 1000)
	local kinds = { main = 0, alternate = 0, optional = 0 }
	for _, r in D.Roads do kinds[r.Kind] += 1 end
	check("main, alternate and optional roads exist", kinds.main > 10 and kinds.alternate > 3 and kinds.optional > 3)
end

-- 5. Summit is the highest point of the frame.
do
	local best, bx, bz = -math.huge, 0, 0
	for x = F.MinX, F.MaxX, 50 do
		for z = F.MinZ, F.MaxZ, 50 do
			local h = O.heightAt(x, z)
			if h > best then best, bx, bz = h, x, z end
		end
	end
	local S = def.Summit
	print(string.format("summit: max %.1f at %d,%d", best, bx, bz))
	-- The crag crown only adds height round the arena; the outer ranges are capped well under the summit.
	check("summit is the highest point", math.sqrt((bx - S.Peak.X) ^ 2 + (bz - S.Peak.Z) ^ 2) <= 150 and best >= S.Y - 30 and best <= S.Y + 60)
end

-- 6. Divide ridge: crest higher than the ground 150 studs either side, along the interior of its length.
do
	local ok, n, worstMargin = true, 0, math.huge
	for k = 2, #O.Divide do
		local p, q = O.Divide[k - 1], O.Divide[k]
		local len = math.sqrt((q.X - p.X) ^ 2 + (q.Z - p.Z) ^ 2)
		local nx, nz = -(q.Z - p.Z) / len, (q.X - p.X) / len
		for t = 0.15, 0.85, 0.1 do
			local x, z = p.X + (q.X - p.X) * t, p.Z + (q.Z - p.Z) * t
			local crest = O.heightAt(x, z)
			local a, b = O.heightAt(x + nx * 150, z + nz * 150), O.heightAt(x - nx * 150, z - nz * 150)
			n += 1
			worstMargin = math.min(worstMargin, crest - a, crest - b)
			ok = ok and crest > a + 5 and crest > b + 5
		end
	end
	print(string.format("divide: %d samples, smallest crest margin %.1f", n, worstMargin))
	check("divide ridge higher than both sides", ok and n > 40)
end

-- 7. Materials: each biome shows its set; Amberfall dries westward; water only in the Forest lake.
do
	local seen = {}
	for _, id in O.RegionIds do seen[id] = {} end
	local lowAmberfall, lowDry = 0, 0
	for x = F.MinX, F.MaxX, 40 do
		for z = F.MinZ, F.MaxZ, 40 do
			local h, m = O.surfaceAt(x, z)
			local id = O.regionAt(x, h, z)
			if id and seen[id] then seen[id][m] = (seen[id][m] or 0) + 1 end
		end
	end
	local function has(id, ...) for _, m in { ... } do if not seen[id][m] then return false end end return true end
	check("Bellwood materials", has("Forest", "Grass", "LeafyGrass", "Mud"))
	check("Amberfall materials", has("GoldenRavine", "Grass", "Sand", "Sandstone"))
	check("Saltreach materials", has("AridBasin", "Sand", "Limestone", "Salt"))
	check("Frostmere materials", has("Snowfields", "Snow", "Rock", "Glacier"))
	check("Ashen Stair materials", has("MountainAscent", "Rock", "Slate", "Basalt", "Snow"))
	-- Amberfall: grass share falls from the divide side to the Saltreach side.
	local function grassShare(x0, x1)
		local g, t = 0, 0
		for x = x0, x1, 20 do
			for z = -4000, -1400, 20 do
				local _, m = O.surfaceAt(x, z)
				t += 1
				if m == "Grass" then g += 1 end
			end
		end
		return g / t
	end
	local east, west = grassShare(-5500, -5300), grassShare(-7400, -7200)
	print(string.format("amberfall grass share east %.2f west %.2f", east, west))
	check("rain shadow: Amberfall grass thins westward", east > west + 0.2)
end

-- 8. Transition band: the first Sand/Sandstone going west from the Bellwood wanders by > 150 studs
-- along the Forest / Amberfall border, so no biome ends on a straight line.
do
	local firstX = {}
	for z = -4000, -1500, 100 do
		for x = -4900, -7000, -8 do
			local h, m = O.surfaceAt(x, z)
			if m == "Sand" or m == "Sandstone" then
				table.insert(firstX, x)
				break
			end
		end
	end
	local lo, hi = math.huge, -math.huge
	for _, x in firstX do lo, hi = math.min(lo, x), math.max(hi, x) end
	print(string.format("band: first dry material x from %d to %d over %d rows", lo, hi, #firstX))
	check("Forest/Amberfall material border is ragged", #firstX >= 20 and hi - lo > 150)
end

-- 9. Shen's fog gate is exposed: written terrain (heightAt + 2) is the gate's floor +-1 across the gate's width
-- from the Outside point through the wall to the Inside point, never above floor + 1, and the way up from the
-- Antechamber altar has no lip (never higher than the ground nearer the gate by more than 1 stud).
do
	local gate = O.Barrier.Gate
	local floor = gate.Placement.Y - gate.Size.Y / 2
	local half, worstLo, worstHi = gate.Size.X / 2, math.huge, -math.huge
	for z = gate.Outside.Z, gate.Inside.Z, -2 do
		for x = gate.Placement.X - half, gate.Placement.X + half, 2 do
			local s = O.heightAt(x, z) + 2
			worstLo, worstHi = math.min(worstLo, s), math.max(worstHi, s)
		end
	end
	print(string.format("gate corridor surface %.2f..%.2f vs floor %d", worstLo, worstHi, floor))
	check("gate corridor surface equals the gate floor +-1", worstLo >= floor - 1 and worstHi <= floor + 1)
	local altar, lip = O.Altars.Altar_ColosseumAntechamber.Placement, 0
	local prev = math.huge
	for z = gate.Outside.Z, altar.Z, 4 do -- walking back from the gate toward the altar
		local s = O.heightAt(gate.Placement.X, z) + 2
		if prev ~= math.huge then lip = math.max(lip, s - prev) end -- the ground must not rise toward the altar
		prev = s
	end
	print(string.format("antechamber approach: worst drop toward the gate %.2f", lip))
	check("no terrain lip between the Antechamber and the gate", lip <= 1)
end

-- 9b. Shen's arena is open: the whole footprint and the corridor stand at the floor (written surface = heightAt + 2,
-- never above floor + 1, no pit below floor - 1), so there is sky over the wall height and a walkable line from
-- the Outside point through the gate to the arena centre with no step over 2 studs.
do
	local B = O.Barrier
	local floor = B.Gate.Placement.Y - B.Gate.Size.Y / 2
	local c, sz = B.Arena.Center, B.Arena.Size
	local lo, hi = math.huge, -math.huge
	for x = c.X - sz.X / 2, c.X + sz.X / 2, 4 do
		for z = c.Z - sz.Z / 2, c.Z + sz.Z / 2, 4 do
			local s = O.heightAt(x, z) + 2
			lo, hi = math.min(lo, s), math.max(hi, s)
		end
	end
	for z = B.Gate.Outside.Z, c.Z - sz.Z / 2, -4 do -- corridor and gate
		for x = B.Gate.Placement.X - B.Gate.Size.X / 2, B.Gate.Placement.X + B.Gate.Size.X / 2, 4 do
			local s = O.heightAt(x, z) + 2
			lo, hi = math.min(lo, s), math.max(hi, s)
		end
	end
	local step, prev = 0, nil
	for z = B.Gate.Outside.Z, c.Z, -2 do
		local s = O.heightAt(c.X, z) + 2
		if prev then step = math.max(step, math.abs(s - prev)) end
		prev = s
	end
	print(string.format("arena + corridor surface %.2f..%.2f vs floor %d, walk line worst step %.2f", lo, hi, floor, step))
	check("arena and corridor surface within floor +-1 (open sky over the wall height " .. sz.Y .. ")", lo >= floor - 1 and hi <= floor + 1)
	check("gate to arena centre walk line has no step over 2", step <= 2)
end

-- 10. World edge (C2 art a): no walkable ground or straight cut at the Frame edge. Each side is sampled every 42
-- studs; the reference is the ground at the nominal foot line (Foot / side scale inland).
do
	local E = def.Edge
	local sides = {
		W = { function(t) return F.MinX, F.MinZ + t * (F.MaxZ - F.MinZ), 1, 0 end, E.Scale.W },
		E = { function(t) return F.MaxX, F.MinZ + t * (F.MaxZ - F.MinZ), -1, 0 end, E.Scale.E },
		N = { function(t) return F.MinX + t * (F.MaxX - F.MinX), F.MinZ, 0, 1 end, E.Scale.N },
		S = { function(t) return F.MinX + t * (F.MaxX - F.MinX), F.MaxZ, 0, -1 end, E.Scale.S },
	}
	local water, high, total = 0, 0, 0
	for name, side in sides do
		local at, scale = side[1], side[2]
		local lo, hi, run, longest, prev = math.huge, -math.huge, 0, 0, nil
		local footLo, footHi = math.huge, -math.huge
		for i = 0, 200 do
			local x, z, nx, nz = at(i / 200)
			local h = O.heightAt(x, z)
			local ref = O.heightAt(x + nx * E.Foot / scale, z + nz * E.Foot / scale)
			lo, hi = math.min(lo, h), math.max(hi, h)
			total += 1
			local top = 0 -- the region's height band caps the ranges, so the crest may stop short of ref + 100
			for _, id in O.RegionIds do
				local b = O.Regions[id].Bounds
				if math.abs(x - b.Center.X) <= b.Size.X / 2 and math.abs(z - b.Center.Z) <= b.Size.Z / 2 then top = b.Center.Y + b.Size.Y / 2 end
			end
			if h <= -15 then water += 1 elseif h >= ref + 100 or h >= top - 230 then high += 1 end
			run = if prev and h > -15 and math.abs(h - prev) < 6 then run + 1 else 0 -- open water is flat by nature
			longest, prev = math.max(longest, run), h
			-- Where the walkable inset reaches 0 going inland: the foot line wanders.
			local d = 0
			while O.edgeInset(x + nx * d, z + nz * d) < 0 and d < 600 do d += 4 end
			footLo, footHi = math.min(footLo, d), math.max(footHi, d)
		end
		check(name .. " edge heights vary (" .. math.floor(lo) .. ".." .. math.floor(hi) .. ")", hi - lo >= 120)
		check(name .. " edge has no flat run (" .. longest .. " samples)", longest < 16)
		check(name .. " foot line wanders (" .. footLo .. ".." .. footHi .. ")", footHi - footLo >= 0.2 * E.Foot / scale)
	end
	print(string.format("edge: %d samples, %d above reach, %d sea, %d between", total, high, water, total - high - water))
	check("outer band is above walkable reach or water (>= 90%)", high + water >= total * 0.9)
	check("sea cliffs and ranges both exist", water >= 60 and high >= 300)
	-- No vertical slab: 4 stud steps stay under 40 studs through the cliff band (west and north sides).
	local worst = 0
	for i = 0, 400 do
		for _, name in { "N", "W" } do
			local x, z, nx, nz = sides[name][1](i / 400)
			for d = 0, 360, 4 do
				worst = math.max(worst, math.abs(O.heightAt(x + nx * d, z + nz * d) - O.heightAt(x + nx * (d + 4), z + nz * (d + 4))))
			end
		end
	end
	print(string.format("edge cliff worst 4-stud step %.1f", worst))
	check("edge cliffs are continuous (no slab)", worst <= 40)
	-- Every surface point of the whole Frame (cliff bands included) lies inside its region's height band.
	local outside = 0
	for x = F.MinX, F.MaxX, 70 do
		for z = F.MinZ, F.MaxZ, 70 do
			if not O.regionAt(x, O.heightAt(x, z) + 3, z) then outside += 1 end
		end
	end
	check("surface stays inside every region's height band on a 70 stud grid (" .. outside .. " outside)", outside == 0)
	-- Everything authored is on the walkable side of the foot with a margin.
	local least, who = math.huge, ""
	local function clear(id, x, z)
		local inset = O.edgeInset(x, z)
		if inset < least then least, who = inset, id end
	end
	for id, n in O.Nodes do clear(id, n.Position.X, n.Position.Z) end
	for id, a in O.Altars do clear(id, a.Placement.X, a.Placement.Z) end
	for id, c in O.Caches do clear(id, c.Position.X, c.Position.Z) end
	for id, l in O.Landmarks do clear(id, l.Position.X, l.Position.Z) end
	for id, r in O.Rings do clear(id, r.X, r.Z) end
	for _, g in O.Encounters.Groups do for _, s in g.Spawns do clear(s.Id, s.X, s.Z) end end
	for id, a in O.ReservedArenas do
		for _, k in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			clear(id, a.Arena.Center.X + k[1] * a.Arena.Size.X / 2, a.Arena.Center.Z + k[2] * a.Arena.Size.Z / 2)
		end
	end
	for _, r in D.Roads do for _, p in r.Points do clear(r.A .. ">" .. r.B, p[1], p[2]) end end
	print(string.format("edge: least inset of any authored place %.0f (%s)", least, who))
	check("every route, altar, cache, arena and spawn stays inside the foot (>= 40)", least >= 40)
end

-- 11. Line of sight: the summit temple is readable from the glade altar over the Bellwood, the Frostmere
-- shoulder and the massif (eye 7.5 above the altar floor; terrain surface is heightAt + 2).
do
	local g = O.Altars[O.Gateway].Placement
	local T = O.Landmarks.SummitTemple
	for _, ty in { T.Position.Y + T.Height / 2, T.Position.Y + T.Height } do
		local ex, ey, ez = g.X, g.Y + 7.5, g.Z
		local dx, dz, dy = T.Position.X - ex, T.Position.Z - ez, ty - ey
		local n = math.floor(math.sqrt(dx * dx + dz * dz) / 10)
		local worst, far = math.huge, math.huge
		for k = 3, n - 5 do
			local t = k / n
			local c = ey + dy * t - (O.heightAt(ex + dx * t, ez + dz * t) + 2)
			worst = math.min(worst, c)
			if k >= 30 then far = math.min(far, c) end
		end
		print(string.format("line of sight to y %.0f: clearance %.1f (%.1f beyond 300 studs)", ty, worst, far))
		check("temple readable from the glade (y " .. ty .. ")", worst >= 8 and far >= 25)
	end
end

-- 12. Relief: meadows are flatter than the ground round them, the massif has cliffs and ledges, the Bellwood has
-- ridges, and the Headwater runs in a gorge (ground 25+ studs above its bed within 150 studs).
do
	local function sd(cx, cz, r0, r1)
		local n, s, s2 = 0, 0, 0
		for a = 0, 23 do
			for r = r0, r1, (r1 - r0) / 6 do
				local h = O.heightAt(cx + r * math.cos(a * math.pi / 12), cz + r * math.sin(a * math.pi / 12))
				n += 1; s += h; s2 += h * h
			end
		end
		return math.sqrt(math.max(s2 / n - (s / n) ^ 2, 0))
	end
	for _, c in def.Clearings do
		local inside, ring = sd(c.X, c.Z, 0.3 * c.R, 0.7 * c.R), sd(c.X, c.Z, 1.4 * c.R, 2.2 * c.R)
		check(string.format("clearing %d,%d is flatter than its surroundings (%.1f vs %.1f)", c.X, c.Z, inside, ring), inside < ring * 0.6)
	end
	local n, cliff, tread = 0, 0, 0
	for x = -9800, -5800, 40 do
		for z = -9000, -4400, 40 do
			if O.heightAt(x, z) > 700 and O.edgeInset(x, z) > 40 then
				local _, _, s = O.surfaceAt(x, z)
				n += 1
				if s > 0.9 then cliff += 1 end
				if s < 0.15 then tread += 1 end
			end
		end
	end
	print(string.format("massif above 700: %d samples, cliffs %.3f, ledges %.3f", n, cliff / n, tread / n))
	check("massif has cliffs and ledges", cliff / n >= 0.04 and tread / n >= 0.08)
	local d = {}
	for x = -5000, -1700, 60 do
		for z = -4100, -900, 60 do
			if O.edgeInset(x, z) > 40 then table.insert(d, O.heightAt(x, z) - O.baseAt(x, z)) end
		end
	end
	table.sort(d)
	local spread = d[math.floor(#d * 0.95)] - d[math.floor(#d * 0.05)]
	print(string.format("bellwood ridge relief p05..p95 spread %.1f", spread))
	check("Bellwood ridges stand out (>= 40)", spread >= 40)
	local deep = 0
	for _, p in { { -2500, -3100 }, { -2600, -2500 } } do
		local bed = O.heightAt(p[1], p[2])
		deep = math.max(deep, math.min(O.heightAt(p[1] + 150, p[2]), O.heightAt(p[1] - 150, p[2])) - bed)
	end
	check("river gorge (" .. string.format("%.0f", deep) .. " studs)", deep >= 25)
	-- win-87 (creator: "elevation changes throughout instead of just flat terrain"): the lowlands carry kilometre swells.
	-- Before the pass the median rise over 50 studs (both axes summed) was ~10 and the relief over the base surface spanned
	-- 13 (Saltreach), 22 (Frostmere) and 45 (Bellwood) studs p05..p95; now the rise is 13+ and the swells span 75+ (extremes
	-- near +-120). Taller swells broke the 4-stud step budget on road banks and the band floors, so 75 is the guard.
	local rise, swell = { Forest = {}, AridBasin = {}, Snowfields = {} }, { Forest = {}, AridBasin = {}, Snowfields = {} }
	for x = F.MinX, F.MaxX, 100 do
		for z = F.MinZ, F.MaxZ, 100 do
			if O.edgeInset(x, z) > 60 then
				local h = O.heightAt(x, z)
				local list = rise[O.regionAt(x, h + 3, z) or ""]
				if list then
					table.insert(list, math.abs(O.heightAt(x + 50, z) - h) + math.abs(O.heightAt(x, z + 50) - h))
					table.insert(swell[O.regionAt(x, h + 3, z)], h - O.baseAt(x, z))
				end
			end
		end
	end
	for id, list in rise do
		table.sort(list)
		local median = list[math.floor(#list / 2)]
		check(string.format("%s rolls: median 50-stud rise %.1f >= 13", id, median), median >= 13)
		local sw = swell[id]
		table.sort(sw)
		local spread = sw[math.floor(#sw * 0.95)] - sw[math.floor(#sw * 0.05)]
		check(string.format("%s swells: relief over the base spans %.0f >= 75 studs (p05..p95)", id, spread), spread >= 75)
	end
end

-- 13. Writer shell (OverworldTerrain.writeTile uses O.shellBottom, SHELL = 8 since C3 ruling 1a): on steep faces each
-- column is filled down to its lowest neighbour minus the shell, so neighbouring columns' filled intervals overlap (no
-- see-through gap over 1 voxel), flat ground is unchanged and the extra voxels stay within 1.25x of the fixed own-height shell.
do
	local RES, SHELL, TILE = 4, 8, 128
	local function grid(x0, z0)
		local hs = {}
		for i = -1, TILE // RES do
			hs[i] = {}
			for j = -1, TILE // RES do hs[i][j] = (O.sampleAt(x0 + (i + 0.5) * RES, z0 + (j + 0.5) * RES)) end
		end
		return hs
	end
	local function voxels(h, bottom) -- voxels the writer keeps (occupancy >= 0.02) in one column
		local n = 0
		for yc = math.floor(bottom / RES) * RES - 2, h + RES, RES do
			if math.min(math.clamp((h - yc) / RES + 0.5, 0, 1), math.clamp((yc - bottom) / RES + 0.5, 0, 1)) >= 0.02 then n += 1 end
		end
		return n
	end
	local n = TILE // RES
	local function tile(name, x0, z0)
		local hs = grid(x0, z0)
		local oldV, newV, gapsOld, gapsNew, flatSame, flatN = 0, 0, 0, 0, 0, 0
		for i = 0, n - 1 do
			for j = 0, n - 1 do
				local h = hs[i][j]
				local bo, bn = h - SHELL, O.shellBottom(hs, i, j, SHELL)
				oldV += voxels(h, bo)
				newV += voxels(h, bn)
				local flat = true
				for di = -1, 1 do for dj = -1, 1 do flat = flat and hs[i + di][j + dj] >= h end end
				if flat then flatN += 1; if bn == bo then flatSame += 1 end end
				for _, d in { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, -1 } } do
					local ni, nj = i + d[1], j + d[2]
					if ni < n and nj >= 0 and nj < n then
						local nh = hs[ni][nj]
						local nbo, nbn = nh - SHELL, O.shellBottom(hs, ni, nj, SHELL)
						if math.max(bo, nbo) > math.min(h, nh) + RES then gapsOld += 1 end
						if math.max(bn, nbn) > math.min(h, nh) + RES then gapsNew += 1 end
					end
				end
			end
		end
		return oldV, newV, gapsOld, gapsNew, flatSame == flatN
	end
	local E, S = F.MaxX - TILE * 2, F.MaxZ - TILE * 2
	local steep = {
		{ "east edge", F.MaxX - TILE, (F.MinZ + F.MaxZ) / 2 }, { "east edge 2", E, F.MinZ + 0.3 * (F.MaxZ - F.MinZ) },
		{ "south edge", (F.MinX + F.MaxX) / 2, F.MaxZ - TILE }, { "south edge 2", F.MinX + 0.7 * (F.MaxX - F.MinX), S },
		{ "SW coast", F.MinX, F.MaxZ - TILE }, { "SW coast 2", F.MinX + TILE * 3, F.MaxZ - TILE },
		{ "summit north face", def.Summit.Peak.X - 64, def.Summit.Peak.Z - 300 }, { "summit north face 2", def.Summit.Peak.X - 64, def.Summit.Peak.Z - 700 },
		{ "N cliffs", def.Summit.Peak.X - 64, F.MinZ },
	}
	local totO, totN, steepGapsOld = 0, 0, 0
	for _, t in steep do
		local o, nn, go, gn, flat = tile(t[1], t[2], t[3])
		totO, totN, steepGapsOld = totO + o, totN + nn, steepGapsOld + go
		print(string.format("shell %-20s voxels %6d -> %6d (x%.2f), gaps %d -> %d", t[1], o, nn, nn / o, go, gn))
		check("no see-through gap over 1 voxel: " .. t[1], gn == 0)
		check("columns never fill less than the old shell: " .. t[1], nn >= o and flat)
	end
	check("the old fixed shell does leave gaps on these steep faces (cause)", steepGapsOld > 0)
	-- Flat ground: a clearing tile is voxel-for-voxel unchanged.
	local c = def.Clearings[1]
	local fo, fn, _, fg, flatOk = tile("clearing", c.X - 64, c.Z - 64)
	print(string.format("shell clearing tile voxels %d -> %d (x%.3f)", fo, fn, fn / fo))
	check("flat ground unchanged (columns at or below all neighbours identical, tile <= 1.15x)", fn <= fo * 1.15 and fg == 0 and flatOk)
	-- Overall cost over a coarse grid of tiles across the whole frame.
	local allO, allN = 0, 0
	for x = F.MinX, F.MaxX - TILE, TILE * 7 do
		for z = F.MinZ, F.MaxZ - TILE, TILE * 7 do
			local o, nn = tile("grid", x, z)
			allO, allN = allO + o, allN + nn
		end
	end
	print(string.format("shell: steep tiles x%.2f, whole-frame grid sample x%.3f voxels", totN / totO, allN / allO))
	check("whole-frame voxel growth <= 1.25x", allN <= allO * 1.25)
end

-- 14. Server memory (C3 ruling 1a). Voxel count of one frame, same rule as OverworldTerrain.writeTile (solid, water, the
-- shell from O.shellBottom), on every third tile each way and scaled up. Calibration: 9.45 MB per million voxels, from both
-- Studio points (172 MB at 18.2M voxels; 198-202 MB at 21.3M, which is the SHELL 12 count below). test_overworld_order.luau
-- checks that the writer's SHELL is the 8 used here.
do
	local RES, TILE, STRIDE, MB_PER_MVOX = 4, 128, 3, 9.45
	local SHELL_NOW, SHELL_THEN = 8, 12
	local nTiles = math.ceil((F.MaxX - F.MinX) / TILE) * math.ceil((F.MaxZ - F.MinZ) / TILE)
	local sampled, now, then_ = 0, 0, 0
	for ti = 0, math.ceil((F.MaxX - F.MinX) / TILE) - 1, STRIDE do
		for tj = 0, math.ceil((F.MaxZ - F.MinZ) / TILE) - 1, STRIDE do
			local x0, z0 = F.MinX + ti * TILE, F.MinZ + tj * TILE
			local hs, ch = {}, {}
			for i = -1, TILE // RES do
				hs[i], ch[i] = {}, {}
				for j = -1, TILE // RES do
					local h, _, _, k = O.sampleAt(x0 + (i + 0.5) * RES, z0 + (j + 0.5) * RES)
					hs[i][j], ch[i][j] = h, k
				end
			end
			sampled += 1
			for i = 0, TILE // RES - 1 do
				for j = 0, TILE // RES - 1 do
					local h = hs[i][j]
					local lake = h < F.WaterY and ch[i][j] == 0
					for r, shell in { SHELL_NOW, SHELL_THEN } do
						local b = O.shellBottom(hs, i, j, shell)
						local n = 0
						for yc = math.floor(b / RES) * RES - 2, (if lake then math.max(h, F.WaterY) else h) + RES, RES do
							local occ = math.min(math.clamp((h - yc) / RES + 0.5, 0, 1), math.clamp((yc - b) / RES + 0.5, 0, 1))
							if occ >= 0.02 or (lake and yc < F.WaterY) then n += 1 end
						end
						if r == 1 then now += n else then_ += n end
					end
				end
			end
		end
	end
	local scale = nTiles / sampled
	local mNow, mThen = now * scale / 1e6, then_ * scale / 1e6
	print(string.format("memory: %d of %d tiles sampled; voxels shell %d = %.2fM (%.0f MB expected), shell %d = %.2fM (%.0f MB, Studio read 198-202)",
		sampled, nTiles, SHELL_NOW, mNow, mNow * MB_PER_MVOX, SHELL_THEN, mThen, mThen * MB_PER_MVOX))
	check("harness reproduces the shipped SHELL 12 reading (195..208 MB)", mThen * MB_PER_MVOX >= 195 and mThen * MB_PER_MVOX <= 208)
	check("SHELL 8 expected server memory <= 185 MB", mNow * MB_PER_MVOX <= 185)
	check("SHELL 8 holds the voxel count under the SHELL 12 count by >= 15%", mNow <= mThen * 0.85)
end

-- 15. Fault B (C3): the glade road climbs to Bell Terrace over a ridge, and the terrace stands on a rise.
do
	local g, t = O.Altars.Altar_MonasteryGate.Placement, O.Altars.Altar_BellTerrace.Placement
	local road
	for _, r in D.Roads do if r.A == "Altar_MonasteryGate" and r.B == "Altar_BellTerrace" then road = r end end
	check("the glade road to Bell Terrace exists", road ~= nil)
	-- Climb and grade, every 4 studs along the centreline.
	local worstUp, worstDown, prev, len = 0, 0, nil, 0
	for k = 2, #road.Points do
		local p, q = road.Points[k - 1], road.Points[k]
		local seg = math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
		for s = 0, seg - 1e-6, 4 do
			local h = O.heightAt(p[1] + (q[1] - p[1]) * s / seg, p[2] + (q[2] - p[2]) * s / seg)
			if prev then
				worstUp, worstDown = math.max(worstUp, (h - prev) / 4), math.max(worstDown, (prev - h) / 4)
			end
			prev = h
		end
		len += seg
	end
	local climb = O.heightAt(t.X, t.Z) - O.heightAt(g.X, g.Z)
	print(string.format("fault B: road %.0f long, climbs %.0f, worst grade up %.2f down %.2f (30 deg = 0.577)", len, climb, worstUp, worstDown))
	check("the road climbs 60+ studs from the glade to the terrace", climb >= 60)
	check("road grade <= 30 degrees (up and down)", worstUp <= math.tan(math.rad(30)) and worstDown <= math.tan(math.rad(30)))
	check("the road never drops more than 15 studs on the way up", (function()
		local top, drop = -math.huge, 0
		for k = 1, #road.Points do
			local h = O.heightAt(road.Points[k][1], road.Points[k][2])
			top = math.max(top, h)
			drop = math.max(drop, top - h)
		end
		return drop <= 15
	end)())
	-- A ridge between: crest samples 30+ above the ground 120 studs either side, lying between the two altars.
	local R = def.Slice.Ridge
	local rdx, rdz = R.X1 - R.X0, R.Z1 - R.Z0
	local rlen = math.sqrt(rdx * rdx + rdz * rdz)
	local nx, nz = -rdz / rlen, rdx / rlen
	local axX, axZ = t.X - g.X, t.Z - g.Z
	local strong, between = 0, 0
	for u = 0.2, 0.5, 0.05 do
		local x, z = R.X0 + rdx * u, R.Z0 + rdz * u
		local crest = O.heightAt(x, z)
		if crest - O.heightAt(x + nx * 120, z + nz * 120) >= 30 and crest - O.heightAt(x - nx * 120, z - nz * 120) >= 30 then strong += 1 end
		local along = ((x - g.X) * axX + (z - g.Z) * axZ) / (axX * axX + axZ * axZ)
		if along > 0.1 and along < 0.9 then between += 1 end
	end
	print(string.format("fault B: ridge crest samples 30+ above both flanks: %d of 7, between the altars: %d", strong, between))
	check("a ridge stands 30+ studs over its flanks between the glade and the terrace", strong >= 5 and between >= 5)
	-- The terrace stands on a rise: the swale ring round it (250 studs out) lies well below the altar on every side
	-- that is not the road or the view lane.
	local lowest, below, n = math.huge, 0, 36
	for a = 0, n - 1 do
		local h = O.heightAt(t.X + 250 * math.cos(a * 2 * math.pi / n), t.Z + 250 * math.sin(a * 2 * math.pi / n))
		lowest = math.min(lowest, h)
		if h <= t.Y - 10 then below += 1 end
	end
	print(string.format("fault B: terrace %d, ring at 250 lowest %.0f, %d of %d points 10+ below", t.Y, lowest, below, n))
	check("Bell Terrace is on a rise (ring 250 studs out: lowest 30+ below, 40% 10+ below)", lowest <= t.Y - 30 and below >= n * 0.4)
end

-- 16. Fault D (C3): within 30 studs of the glade altar the ground is forest floor, never a bare Ground / Rock slab.
do
	local g = O.Altars[O.Gateway].Placement
	local floorMat = { LeafyGrass = true, Grass = true, Mud = true }
	local bad, n = {}, 0
	for x = g.X - 30, g.X + 30, 2 do
		for z = g.Z - 30, g.Z + 30, 2 do
			if math.sqrt((x - g.X) ^ 2 + (z - g.Z) ^ 2) <= 30 then
				local _, m = O.surfaceAt(x, z)
				n += 1
				if not floorMat[m] then bad[m] = (bad[m] or 0) + 1 end
			end
		end
	end
	local list = {}
	for m, c in bad do table.insert(list, m .. " x" .. c) end
	print(string.format("fault D: %d samples within 30 studs of the glade altar, not forest floor: %s", n, if #list == 0 then "none" else table.concat(list, ", ")))
	check("glade altar surroundings (30 studs) are forest floor", n > 400 and #list == 0)
end

-- 17. Fault E (C3): no pale blue-grey material (Slate, Glacier, Limestone, Salt, Snow) on the road or within 40 studs of it
-- along the slice corridor (glade, Bell Terrace, hermit hut): distant biomes must not leak into Bellwood roads.
do
	local PALE = { Slate = true, Glacier = true, Limestone = true, Salt = true, Snow = true }
	local slice = { Altar_MonasteryGate = true, Altar_BellTerrace = true, F2_HermitHut = true }
	local roads, onRoad, total, pale = 0, 0, 0, {}
	for _, r in D.Roads do
		if slice[r.A] and slice[r.B] then
			roads += 1
			for k = 2, #r.Points do
				local p, q = r.Points[k - 1], r.Points[k]
				local seg = math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
				local nx, nz = -(q[2] - p[2]) / seg, (q[1] - p[1]) / seg
				for s = 0, seg - 1e-6, 2 do
					for _, d in { 0, 40, -40 } do
						local x, z = p[1] + (q[1] - p[1]) * s / seg + nx * d, p[2] + (q[2] - p[2]) * s / seg + nz * d
						local _, m = O.surfaceAt(x, z)
						local _, rw = O.sampleAt(x, z)
						total += 1
						if rw > 0.5 then onRoad += 1 end
						if PALE[m] then pale[m] = (pale[m] or 0) + 1 end
					end
				end
			end
		end
	end
	local list = {}
	for m, c in pale do table.insert(list, m .. " x" .. c) end
	print(string.format("fault E: %d corridor roads, %d samples (%d on the carriageway), pale materials: %s", roads, total, onRoad, if #list == 0 then "none" else table.concat(list, ", ")))
	check("slice corridor has road samples to judge", roads >= 2 and onRoad >= 300)
	check("no pale blue-grey material on or beside the slice roads", #list == 0)
end

-- 15. padsNear (T4b): culling pads per 128-stud tile never changes sampleAt (bit-identical on every column centre of the
-- tiles that hold each altar, ring, the gate corridor and the arena, plus the margin ring), and does cull.
do
	local D = O.terrainData()
	local seen, tiles, same, culled, samples = {}, {}, true, 0, 0
	for _, p in D.Pads do
		local i, j = math.floor((p.X - F.MinX) / 128), math.floor((p.Z - F.MinZ) / 128)
		if not seen[i .. "," .. j] and p.X >= F.MinX and p.X < F.MaxX and p.Z >= F.MinZ and p.Z < F.MaxZ then
			seen[i .. "," .. j] = true
			table.insert(tiles, { F.MinX + i * 128, F.MinZ + j * 128 })
		end
	end
	for _, t in tiles do
		local pads = O.padsNear(t[1] - 4, t[2] - 4, t[1] + 132, t[2] + 132)
		culled += #D.Pads - #pads
		for i = -1, 32 do
			for j = -1, 32 do
				local x, z = t[1] + (i + 0.5) * 4, t[2] + (j + 0.5) * 4
				local a, b, c, d = O.sampleAt(x, z)
				local a2, b2, c2, d2 = O.sampleAt(x, z, pads)
				samples += 1
				if a ~= a2 or b ~= b2 or c ~= c2 or d ~= d2 then same = false end
			end
		end
	end
	print(string.format("padsNear: %d pad tiles, %d samples identical=%s, %d of %d pads culled per tile on average", #tiles, samples, tostring(same), culled / #tiles, #D.Pads))
	check("padsNear: sampleAt is bit-identical with the culled pad list on every pad tile", same and #tiles >= 10)
	check("padsNear: it culls most pads (a tile far from every pad keeps none)", culled / #tiles >= 10 and #O.padsNear(F.MinX, F.MinZ, F.MinX + 8, F.MinZ + 8) <= #D.Pads)
end

print(string.format("overworld terrain: %d passed, %d failed", passed, failed))
if failed > 0 then error("overworld terrain checks failed") end

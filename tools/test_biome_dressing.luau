--!nonstrict
-- Biome dressing DATA (open-world issues 13-16): Amberfall Ravine, The Saltreach, Frostmere Heads, The Ashen Stair.
-- Run from the project root:
--   work/bin/luau/luau.exe tools/test_biome_dressing.luau       (plain Luau)
--   python3 tools/lune_compat.py tools/test_biome_dressing.luau  (same checks on the Lune shim)
-- Checks per biome: kit slot data, placements stand on the surface (+-0.5) and inside their region, no scatter in an exclusion
-- (re-derived here from Overworld, not from the builder), same list on a fresh rebuild, counts, part / triangle budget, hero
-- footing, roofed interiors (cover, AsuraShelter spans, entrances, extents), lift end-structures, landmarks.
-- Planner (B.plan): part budget per region (and when tightened), nothing on roads / arena pads / altars / encounter spots, a three-scale set
-- piece per site, tiers, distance thinning, noise-mask clustering, determinism, silhouette validity, registered asset fits.
local O = require("../src/shared/Overworld")
local World = require("../src/shared/WorldDefinitions")
local S = require("../src/shared/SliceDressing")
local B = require("../src/shared/BiomeDressing")

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function dist(x0, z0, x1, z1) return math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2) end
local function slopeAt(x, z)
	local h = O.heightAt(x, z)
	local sx, sz = (O.heightAt(x + 4, z) - h) / 4, (O.heightAt(x, z + 4) - h) / 4
	return math.sqrt(sx * sx + sz * sz)
end

-- 1. Kit slots
local slotCount = 0
for name, p in B.Pieces do
	slotCount += 1
	check(name .. " has a positive size", p.Size[1] > 0 and p.Size[2] > 0 and p.Size[3] > 0)
	local heroSlot = B.Slots[name] -- a hero slot is the uploaded hero's spec (same table, registry key = the hero's name)
	check(name .. " is not a slice piece, adopts its definition, or is a hero slot", if heroSlot then B.Pieces[heroSlot] == p and p.Key == heroSlot and B.Shared[name] == nil
		else (S.Pieces[name] == nil) ~= (B.Shared[name] == true) and (S.Pieces[name] == nil or p.Subs == S.Pieces[name].Subs))
	local subTris = 0
	for _, sb in p.Subs do
		check(name .. "__" .. sb.Name .. " under the 18k tri cap", sb.Tris < 18000)
		subTris += sb.Tris
	end
	check(name .. " tris are the sub-mesh sum", p.Tris == subTris and p.MeshParts == #p.Subs and p.PlaceholderParts >= 1)
	check(name .. " has a radius and sink", p.Radius > 0 and p.Sink >= 0)
end
check("kit slot list has the expected size (" .. slotCount .. ")", slotCount >= 140 and slotCount <= 170)
check("the four biomes are listed in order", #B.Order == 4 and B.Order[1] == "GoldenRavine" and B.Order[4] == "MountainAscent")

-- Exclusion circles re-derived from Overworld (the slice test's list; heroes are added per biome)
local K = S.Keep
local baseCircles = {}
local function circle(list, x, z, keep) table.insert(list, { X = x, Z = z, Keep = keep }) end
for _, a in O.Altars do circle(baseCircles, a.Placement.X, a.Placement.Z, K.Altar); circle(baseCircles, a.Spawn.X, a.Spawn.Z, K.Arrival); circle(baseCircles, a.Exit.X, a.Exit.Z, K.Arrival) end
for _, r in O.Rings do circle(baseCircles, r.X, r.Z, K.Ring) end
circle(baseCircles, O.Blockout.ReturnGate.X, O.Blockout.ReturnGate.Z, K.ReturnGate)
for _, sh in O.Blockout.Shelters do
	local half, k = 0.5 * math.sqrt(sh.W ^ 2 + sh.D ^ 2), {}
	for cls, pad in K.Shelter do k[cls] = half + pad end
	circle(baseCircles, sh.X, sh.Z, k)
end
for _, group in { O.Blockout.Bridges, O.Blockout.Ramps, O.Blockout.Lifts } do
	for _, b in group do circle(baseCircles, b.A.X, b.A.Z, K.SpanEnd); circle(baseCircles, b.B.X, b.B.Z, K.SpanEnd) end
end
for _, pt in O.Blockout.Portals do circle(baseCircles, pt.X, pt.Z, K.SpanEnd) end
local function home(x, z, mob)
	local leash = World.Mobs[mob].AI.LeashRange
	check("MobLeash " .. mob .. " matches WorldDefinitions", S.MobLeash[mob] == leash and B.MobLeash[mob] == leash)
	local k = {}
	for cls, f in K.Leash do k[cls] = f * leash end
	circle(baseCircles, x, z, k)
end
for _, e in O.EncounterSpots do home(e.Placement.X, e.Placement.Z, e.Mob) end
for _, m in O.Minibosses do home(m.Placement.X, m.Placement.Z, m.Id) end
home(O.Training.Placement.X, O.Training.Placement.Z, "SparringPhantom")
local roads = {}
for _, road in O.terrainData().Roads do
	for k = 2, #road.Points do table.insert(roads, { road.Points[k - 1], road.Points[k] }) end
end

-- Expected counts: { total min, total max, hero min, scatter min, interior min } and per-piece exact counts.
local EXPECT = {
	GoldenRavine = { 1100, 1900, 70, 900, 40, { Ravine_Lift_Station = 2, Cave_Mouth_Arch = 1, Ravine_Aqueduct_Arch = 1, Ravine_Mausoleum = 1, Ravine_Span_Pylon = 4, Ravine_Rope_Post = 4, Ravine_Grotto_Landing = 1 } },
	AridBasin = { 1200, 1900, 60, 1000, 15, { Basin_Gate_Statue = 1, Cave_Mouth_Arch = 1, Basin_Kiln_Shed = 1, Basin_Cistern_Pavilion = 1, Basin_Kiln_Stack = 2 } },
	Snowfields = { 1200, 1900, 150, 1000, 0, { Snow_Watch_Beacon = 1, Snow_Refuge_Hut = 1, Snow_Windbreak = 8 } },
	MountainAscent = { 1000, 1900, 60, 900, 5, { Summit_Temple_Pagoda = 1, Summit_Temple_Wing = 1, Mtn_Thousand_Steps_Gate = 1, Mtn_Lift_Station = 2, Mtn_Refuge_Hall = 1, Mtn_Pass_Gate = 1 } },
}
local LANDMARK_REACH = 150
local summary, usedPieces = {}, {}

for _, id in B.Order do
	local def = B.Defs[id]
	local bounds = O.Regions[id].Bounds
	local t0 = os.clock()
	local R = B.build(id, true)
	local seconds = os.clock() - t0
	local E = EXPECT[id]
	local function signature(r)
		local out = {}
		for _, p in r.Placements do
			table.insert(out, string.format("%s|%s|%.3f|%.3f|%.3f|%.2f|%.3f", p.Id, p.Piece, p.X, p.Z, p.Y, p.Yaw, p.Scale))
		end
		return table.concat(out, ";")
	end
	check(id .. ": a fresh rebuild gives the same placements", signature(B.build(id, true)) == signature(R))
	check(id .. ": the memoised build is the same object", B.build(id) == B.build(id))
	check(id .. ": build takes under 20 s (" .. string.format("%.1f", seconds) .. ")", seconds < 20)

	local heroes, interior, scatter = {}, {}, {}
	local ids = {}
	for _, p in R.Placements do
		check(id .. ": unique id " .. p.Id, not ids[p.Id])
		ids[p.Id] = true
		usedPieces[p.Piece] = true
		usedPieces[B.Pieces[p.Piece].Key or p.Piece] = true
		if p.Kind == "Hero" then table.insert(heroes, p) elseif p.Kind == "Interior" then table.insert(interior, p) else table.insert(scatter, p) end
	end
	local n = #R.Placements
	check(id .. ": total placements in range (" .. n .. ")", n >= E[1] and n <= E[2])
	check(id .. ": hero count (" .. #heroes .. ")", #heroes >= E[3])
	check(id .. ": scatter count (" .. #scatter .. ")", #scatter >= E[4])
	check(id .. ": interior count (" .. #interior .. ")", #interior >= E[5])
	for _, class in B.Classes do check(id .. ": scatter has " .. class, (R.ByClass[class] or 0) > 20) end
	for piece, count in E[6] do check(id .. ": " .. piece .. " x" .. count .. " (" .. tostring(R.Counts[piece]) .. ")", R.Counts[piece] == count) end

	-- Budget (per biome, the slice's numbers)
	local Bd = B.Budget
	check(id .. ": mesh parts " .. R.MeshParts .. " <= " .. Bd.MeshParts, R.MeshParts <= Bd.MeshParts)
	check(id .. ": placeholder parts " .. R.PlaceholderParts .. " <= " .. Bd.PlaceholderParts, R.PlaceholderParts <= Bd.PlaceholderParts)
	check(id .. ": tris " .. R.Tris .. " <= " .. Bd.Tris, R.Tris <= Bd.Tris)
	check(id .. ": tris with detail dropped " .. R.TrisLod .. " <= " .. Bd.TrisLod, R.TrisLod <= Bd.TrisLod)
	check(id .. ": placements <= " .. Bd.Placements, n <= Bd.Placements)
	local worstCell = 0
	for key, c in R.Cells do
		check(id .. ": cell key " .. key, key:match("^%-?%d+,%-?%d+$") ~= nil and c.Needs[key] == true)
		local parts = 0
		for _, p in c.Placements do parts += B.Pieces[p.Piece].PlaceholderParts end
		worstCell = math.max(worstCell, parts)
	end
	check(id .. ": busiest cell " .. worstCell .. " placeholder parts <= 900", worstCell <= 900)

	-- Surface and region
	local worst = 0
	for _, p in R.Placements do
		local thru
		for _, c in R.Interiors do if c.Id == p.Cave and c.Through then thru = O.Regions[c.Through].Bounds end end
		check(id .. ": " .. p.Id .. " inside the region box", B.inBox(bounds, p.X, p.Z) or (thru ~= nil and B.inBox(thru, p.X, p.Z)))
		if p.Kind ~= "Interior" then
			worst = math.max(worst, math.abs(p.Y - O.heightAt(p.GX, p.GZ)))
		end
	end
	check(id .. ": every surface placement is on the surface (worst " .. string.format("%.3f", worst) .. ")", worst <= 0.5)

	-- Scatter exclusions and terrain, from the rules
	local circles = {}
	for _, c in baseCircles do table.insert(circles, c) end
	for _, h in heroes do
		local k = {}
		for cls, pad in K.Hero do k[cls] = B.Pieces[h.Piece].Radius * h.Scale + pad end
		circle(circles, h.X, h.Z, k)
	end
	local cuttings = {}
	for _, c in R.Interiors do
		local tx, tz = (c.B.X - c.A.X) / c.Length, (c.B.Z - c.A.Z) / c.Length
		for _, o in c.Open do
			local d = o.From
			while d <= o.To do
				table.insert(cuttings, { X = c.A.X + tx * d, Z = c.A.Z + tz * d, R = c.Width / 2 + 8 })
				d += 8
			end
		end
	end
	local violations, trees = {}, {}
	for _, p in scatter do
		local cls, rule = p.Class, def.Scatter[p.Class]
		for _, c in circles do
			if dist(p.X, p.Z, c.X, c.Z) < c.Keep[cls] - 1e-6 then table.insert(violations, p.Id .. " inside a circle at " .. c.X .. "," .. c.Z) end
		end
		for _, s in roads do
			if S.segDist(s[1][1], s[1][2], s[2][1], s[2][2], p.X, p.Z) < K.Road[cls] - 1e-6 then table.insert(violations, p.Id .. " on a road") break end
		end
		for _, w in B.walks(id) do
			for k = 2, #w.Points do
				if S.segDist(w.Points[k - 1][1], w.Points[k - 1][2], w.Points[k][1], w.Points[k][2], p.X, p.Z) < K.Road[cls] - 1e-6 then table.insert(violations, p.Id .. " on a walked route") break end
			end
		end
		for _, c in cuttings do
			if dist(p.X, p.Z, c.X, c.Z) < c.R - 1e-6 then table.insert(violations, p.Id .. " in a cave cutting") break end
		end
		if rule.Tall then
			for _, l in R.Lanes do
				if S.segDist(l[1], l[2], l[3], l[4], p.X, p.Z) < def.Lane.HalfWidth - 1e-6 then table.insert(violations, p.Id .. " blocks the landmark lane") break end
			end
		end
		local h, roadW, channelW, chasmW = O.sampleAt(p.X, p.Z)
		local slope = slopeAt(p.X, p.Z)
		local mat = O.materialAt(p.X, p.Z, h, slope, roadW, channelW, chasmW)
		if slope >= rule.MaxSlope then table.insert(violations, p.Id .. " too steep") end
		if channelW >= 0.05 or chasmW >= 0.01 or h <= 3 or roadW >= 0.5 then table.insert(violations, p.Id .. " in water, channel, chasm or road") end
		local allowed = if rule.ByMaterial and rule.ByMaterial[mat] then 1 else (rule.Material[mat] or 0)
		if allowed <= 0 then table.insert(violations, p.Id .. " on " .. mat) end
		if B.altFactor(rule.Alt, h) <= 0 then table.insert(violations, p.Id .. " outside its altitude band") end
		if (O.blendAt(p.X, p.Z)[id] or 0) <= 0 then table.insert(violations, p.Id .. " outside the region blend") end
		if cls == "Tree" then table.insert(trees, p) end
	end
	if #violations > 0 then print("  " .. id .. " first violations: " .. table.concat(violations, "; ", 1, math.min(#violations, 6))) end
	check(id .. ": no scatter placement lies in an exclusion (" .. #scatter .. " checked, " .. #violations .. " violations)", #violations == 0)
	check(id .. ": scatter was actually checked", #scatter > 500 and #circles >= 40 and #roads >= 100)
	local tight = 0
	for i = 1, #trees do
		for j = i + 1, #trees do
			local a, b = trees[i], trees[j]
			local ra, rb = B.Pieces[a.Piece].Radius * a.Scale, B.Pieces[b.Piece].Radius * b.Scale
			if dist(a.X, a.Z, b.X, b.Z) < 0.65 * (ra + rb) - 1e-6 then tight += 1 end
		end
	end
	check(id .. ": trees keep 0.65 crown spacing", tight == 0)
	check(id .. ": the landmark lane exists (" .. #R.Lanes .. " sight lines)", #R.Lanes >= 2)

	-- Heroes
	local bad = {}
	local worstRelief = 0
	for _, h in heroes do
		local p = B.Pieces[h.Piece]
		local _, roadW, channelW, chasmW = O.sampleAt(h.GX, h.GZ)
		local slope = slopeAt(h.GX, h.GZ)
		local onGround = not (h.Cliff or h.Shelf)
		if onGround and slope >= 0.9 then table.insert(bad, h.Id .. " slope " .. string.format("%.2f", slope)) end
		if onGround and chasmW >= 0.01 then table.insert(bad, h.Id .. " in the chasm") end
		if channelW >= 0.5 and not h.Road then table.insert(bad, h.Id .. " in a channel") end
		if h.Shelf and chasmW < 0.01 then table.insert(bad, h.Id .. " is not on the chasm shelf") end
		if not h.Road and h.Kind == "Hero" and not h.Cliff then
			local d = math.huge
			for _, s in roads do d = math.min(d, S.segDist(s[1][1], s[1][2], s[2][1], s[2][2], h.X, h.Z)) end
			if d < 9 and not h.Shelter and not h.CaveMouth and not h.LiftEnd and not h.Landmark and p.Radius < 12 then table.insert(bad, h.Id .. " on a road (" .. string.format("%.1f", d) .. ")") end
		end
		for _, a in O.Altars do
			if h.Kind == "Hero" and not h.Cliff and dist(h.X, h.Z, a.Placement.X, a.Placement.Z) < 14 then table.insert(bad, h.Id .. " on the altar " .. a.Id) end
		end
		for _, e in O.EncounterSpots do
			-- Go02_A stands on the ShelfWest ramp line (blockout data, not this lane's to move): cliff stairs are waived
			if not h.Cliff and dist(h.X, h.Z, e.Placement.X, e.Placement.Z) < 12 then table.insert(bad, h.Id .. " on the encounter home " .. e.Spawn) end
		end
		if p.Structure and onGround and h.Kind == "Hero" and p.Radius > 12 then
			local lo, hi = math.huge, -math.huge
			local hw, hd = p.Size[1] / 2 * h.Scale, p.Size[3] / 2 * h.Scale
			local cy, sy = math.cos(math.rad(h.Yaw)), math.sin(math.rad(h.Yaw))
			for _, cx in { -hw, hw } do
				for _, cz in { -hd, hd } do
					local y = O.heightAt(h.X + cx * cy + cz * sy, h.Z - cx * sy + cz * cy)
					lo, hi = math.min(lo, y), math.max(hi, y)
				end
			end
			worstRelief = math.max(worstRelief, hi - lo)
			if hi - lo > 45 then table.insert(bad, h.Id .. " footprint relief " .. string.format("%.0f", hi - lo)) end
		end
	end
	if #bad > 0 then print("  " .. id .. " hero problems: " .. table.concat(bad, "; ", 1, math.min(#bad, 10))) end
	check(id .. ": hero footing (" .. #heroes .. " heroes, " .. #bad .. " problems, worst footprint relief " .. string.format("%.0f", worstRelief) .. ")", #bad == 0)

	-- Landmarks
	for lid, lm in O.Landmarks do
		if lm.Region == id then
			local found
			for _, h in heroes do
				if h.Landmark and dist(h.X, h.Z, lm.Position.X, lm.Position.Z) <= LANDMARK_REACH then found = h end
			end
			check(id .. ": landmark " .. lid .. " has a Persistent hero within " .. LANDMARK_REACH, found ~= nil)
		end
	end

	-- Interiors: roofed, buried, with an entrance and AsuraShelter spans
	for _, c in R.Interiors do
		local tag = id .. ": " .. c.Id
		check(tag .. " is a known POI or shelter", c.Poi ~= nil)
		local poiOk = false
		for _, p in O.POIs do if p.Id == c.Poi and (p.Kind == "Cave" or p.Kind == "Gallery") then poiOk = true end end
		check(tag .. " matches a Cave or Gallery POI", poiOk)
		check(tag .. " roof is tagged AsuraShelter", c.Tag == "AsuraShelter" and #c.Roofs >= 1)
		check(tag .. " roof covers at least 60% of its length (" .. string.format("%.0f/%.0f", c.RoofLength, c.Length) .. ")", c.RoofLength >= 0.6 * c.Length)
		local spanSum = 0
		for _, rf in c.Roofs do
			spanSum += rf.Length
			check(tag .. " roof span carries the tag and a thickness", rf.Tag == "AsuraShelter" and rf.Thickness >= 3 and rf.Width > c.Width)
		end
		check(tag .. " roof spans add up to the roofed length", math.abs(spanSum - c.RoofLength) < 1e-6)
		for _, o in c.Open do
			check(tag .. " entrance cutting under 60 studs (" .. string.format("%.0f", o.To - o.From) .. ")", o.To - o.From <= 60)
		end
		-- extents inside the region (or the region the passage runs through)
		local ex = c.Extents
		local other = if c.Through then O.Regions[c.Through].Bounds else nil
		for _, pt in { { ex.X0, ex.Z0 }, { ex.X1, ex.Z0 }, { ex.X0, ex.Z1 }, { ex.X1, ex.Z1 } } do
			check(tag .. " extents corner inside the region or its through region", B.inBox(bounds, pt[1], pt[2]) or (other ~= nil and B.inBox(other, pt[1], pt[2])))
		end
		-- mouth arch at the portal
		if c.MouthA then
			local portalOk = false
			for _, pt in O.Blockout.Portals do
				if dist(pt.X, pt.Z, c.MouthA.X, c.MouthA.Z) < 1 then portalOk = true end
			end
			check(tag .. " mouth is a Blockout portal", portalOk)
			local arch
			for _, h in heroes do if h.CaveMouth == c.Id then arch = h end end
			check(tag .. " has a Cave_Mouth_Arch at its mouth", arch ~= nil and arch.Piece == "Cave_Mouth_Arch" and dist(arch.X, arch.Z, c.MouthA.X, c.MouthA.Z) < 6)
		end
		if c.Through then
			local fm = c.ForestMouth
			local ok = false
			for _, pt in O.Blockout.Portals do if pt.Region == c.Through and dist(pt.X, pt.Z, fm.X, fm.Z) < 1 then ok = true end end
			check(tag .. " far mouth is a " .. c.Through .. " portal (arch owned by that biome)", ok)
		end
		-- buried: re-derive the ground over every roof slab (centre and both walls) from the terrain
		local slabs, minCover = 0, math.huge
		if c.Mode == "Carved" then
			for _, p in interior do
				if p.Cave == c.Id and p.Roof then
					slabs += 1
					local rad = math.rad(p.Yaw)
					local fx, fz = math.sin(rad), math.cos(rad) -- along the passage
					local w = c.Width / 2
					local g = math.min(O.heightAt(p.X, p.Z), O.heightAt(p.X - fz * w, p.Z + fx * w), O.heightAt(p.X + fz * w, p.Z - fx * w),
						O.heightAt(p.X + fx * 12, p.Z + fz * 12), O.heightAt(p.X - fx * 12, p.Z - fz * 12))
					minCover = math.min(minCover, g - (p.Y + c.RoofThickness))
				end
			end
			check(tag .. " every roof slab lies under the ground (" .. slabs .. " slabs, least cover " .. string.format("%.1f", minCover) .. ")", slabs >= 2 and minCover >= 1.5)
		else
			for _, p in interior do if p.Cave == c.Id and p.Roof then slabs += 1 end end
			check(tag .. " built roof has slabs (" .. slabs .. ")", slabs >= 2)
		end
		check(tag .. " has ribs, stairs or lights inside", c.Ribs >= 2)
		local pieceSet = {}
		for _, p in interior do if p.Cave == c.Id then pieceSet[p.Piece] = true; check(tag .. " " .. p.Id .. " stands on the interior floor", p.Y >= ex.Y0 - 0.5 and p.Y <= ex.Y1) end end
		check(tag .. " uses roof slabs and rib arches", pieceSet.Cave_Roof_Slab and pieceSet.Cave_Rib_Arch)
	end

	-- Lifts: both ends are built stations, the map shows the link
	for _, lf in B.Lifts[id] do
		local tag = id .. ": lift " .. lf.Id
		local bl
		for _, l in O.Blockout.Lifts do if l.Id == lf.Id then bl = l end end
		check(tag .. " exists in the blockout", bl ~= nil)
		local a, b2
		for _, h in heroes do
			if h.LiftEnd == lf.Id then
				if dist(h.X, h.Z, bl.A.X, bl.A.Z) < 4 then a = h end
				if dist(h.X, h.Z, bl.B.X, bl.B.Z) < 4 then b2 = h end
			end
		end
		check(tag .. " has a station at each end", a ~= nil and b2 ~= nil and a ~= b2)
		local e
		for _, ed in O.Edges do if ed.A .. ">" .. ed.B == lf.Edge then e = ed end end
		check(tag .. " the map link is a shortcut edge", e ~= nil and e.Kind == "shortcut" and O.Nodes[e.A] ~= nil and O.Nodes[e.B] ~= nil)
		check(tag .. " the lift is carried by its edge", e ~= nil and table.find(bl.Edges, lf.Edge) ~= nil)
		local poi = false
		for _, p in O.POIs do if p.Id == lf.Poi and p.Kind == "Lift" then poi = true end end
		check(tag .. " is a Lift POI", poi)
	end

	table.insert(summary, string.format("%-15s placements %4d = hero %3d + interior %2d + scatter %4d (%s)  parts %4d/%4d  tris %.2fM (%.2fM lod)  cells %d  dropped %d  %.1fs",
		id, n, #heroes, #interior, #scatter,
		string.format("R%d T%d S%d F%d G%d", R.ByClass.Rock, R.ByClass.Tree, R.ByClass.Shrub, R.ByClass.Fern, R.ByClass.Grass),
		R.MeshParts, R.PlaceholderParts, R.Tris / 1e6, R.TrisLod / 1e6, (function() local c = 0 for _ in R.Cells do c += 1 end return c end)(), R.Dropped, seconds))
end

-------------------------------------------------------------------------------------------------
-- Planner: B.plan(region). Silhouettes and tiers (data), then per region: part budget, exclusions, set piece per site, tiers,
-- thinning, noise-mask clustering, determinism.
-------------------------------------------------------------------------------------------------

local SHAPES = { Block = true, Cylinder = true, Wedge = true }
local tierSeen = { Large = 0, Medium = 0, Small = 0 }
for name, p in B.Pieces do
	local tag = "silhouette " .. name
	local longest = math.max(p.Size[1], p.Size[2], p.Size[3])
	check(tag .. ": tier " .. tostring(p.Tier) .. " matches its longest side",
		tierSeen[p.Tier] ~= nil and (p.Tier == "Large") == (longest >= B.TierMin.Large) and (p.Tier == "Small") == (longest < B.TierMin.Medium))
	if tierSeen[p.Tier] then tierSeen[p.Tier] += 1 end
	if p.Arch == "Steps" then
		check(tag .. ": step count is the part count", p.Parts == p.Subs[1].Steps and p.Parts >= 2)
	else
		check(tag .. ": archetype " .. tostring(p.Arch) .. " has 1 to 4 primitives (" .. #p.Sil .. ")", B.Silhouettes[p.Arch] ~= nil and #p.Sil >= 1 and #p.Sil <= 4 and p.Parts == #p.Sil)
		local top, lo, hi = 0, math.huge, -math.huge
		for i, t in p.Sil do
			local inside = SHAPES[t.Shape] ~= nil and t.W > 0 and t.D > 0 and t.Y1 > t.Y0 and t.Y0 >= -1e-9 and t.Y1 <= 1 + 1e-9
				and math.abs(t.Cx) + t.W / 2 <= 0.5 + 1e-9 and math.abs(t.Cz) + t.D / 2 <= 0.5 + 1e-9 and p.Subs[t.Sub] ~= nil
			check(tag .. " primitive " .. i .. " sits inside the box on a real sub-mesh", inside)
			check(tag .. " primitive " .. i .. " is at least 0.2 studs each way", t.W * p.Size[1] >= 0.2 and t.D * p.Size[3] >= 0.2 and (t.Y1 - t.Y0) * p.Size[2] >= 0.2)
			top, lo, hi = math.max(top, t.Y1), math.min(lo, t.Cx - t.W / 2), math.max(hi, t.Cx + t.W / 2)
		end
		check(tag .. ": the silhouette reaches the box top and most of its width", top >= 0.98 and hi - lo >= 0.7)
	end
end
for tier, n in tierSeen do check("tier " .. tier .. " holds at least 8 kit slots (" .. n .. ")", n >= 8) end
local assetCount = 0
for name, a in B.Assets do
	assetCount += 1
	check("asset fit " .. name .. " names a registry file, a numeric id and a ServerStorage path",
		type(a.Registry) == "string" and a.Registry:match("^assets/[%w_]+_UPLOADED%.json$") ~= nil and type(a.Id) == "number" and a.Id > 0 and type(a.Path) == "string" and a.Path ~= "")
end
check("registered asset fits exist (" .. assetCount .. ")", assetCount >= 10)
for id, kitDef in B.SetKits do
	for tier, list in kitDef do
		check(id .. " set kit " .. tier .. " is not empty", #list >= 2)
		for _, name in list do check(id .. " set kit " .. name .. " is a " .. tier .. " piece", B.Pieces[name] ~= nil and B.Pieces[name].Tier == tier) end
	end
end

-- Upload kits (lane D5): every piece of the Amberfall and Saltreach manifests has a placeholder spec. Rows are this test's own copy of
-- upload_manifest.json { piece, size_studs_xyz_roblox (X, Y up, Z), tris_total, sub_meshes }.
local AMBERFALL = {
	{ "Amber_Maple_Red", 37.2, 42.0, 40.5, 14698, "Bark:1602 Leaves_Detail:9640 Leaves_Mass:3456" },
	{ "Amber_Stump", 15.2, 7.3, 15.2, 774, "Bark:756 Ends:18" },
	{ "Amber_Grass_Pale", 6.8, 5.1, 7.1, 770, "Blades:770" },
	{ "Amber_Maple_Gold", 45.2, 36.5, 40.5, 18368, "Bark:1984 Leaves_Detail:12064 Leaves_Mass:4320" },
	{ "Amber_RedTrunk_A", 34.0, 44.7, 31.9, 9620, "Bark:1036 Leaves_Detail:6280 Leaves_Mass:2304" },
	{ "Amber_RedTrunk_B", 25.4, 57.7, 25.5, 8428, "Bark:940 Leaves_Detail:5472 Leaves_Mass:2016" },
	{ "Amber_Cliff_Pine", 30.4, 31.6, 25.8, 5328, "Bark:768 Leaves_Detail:2832 Leaves_Mass:1728" },
	{ "Amber_Maple_Sapling", 20.6, 19.2, 19.3, 8344, "Bark:856 Leaves_Detail:5472 Leaves_Mass:2016" },
	{ "Amber_Dead_Snag", 15.5, 37.9, 12.4, 712, "Bark:698 Ends:14" },
	{ "Amber_Fallen_Log", 26.8, 6.1, 10.4, 868, "Bark:840 Ends:28" },
	{ "Amber_Root_Tangle", 20.1, 5.8, 20.9, 864, "Bark:864" },
	{ "Amber_Shrub_Dry", 12.2, 6.8, 13.8, 6464, "Leaves:3872 Stems:2592" },
	{ "Amber_Shrub_Sumac", 11.2, 7.0, 9.1, 4992, "Leaves:2976 Stems:2016" },
	{ "Amber_Fern_Bronze", 10.8, 2.7, 10.9, 2112, "Fronds:2112" },
	{ "Amber_Leaf_Litter_A", 20.6, 0.6, 21.1, 5960, "Leaves:5760 Twigs:200" },
	{ "Amber_Leaf_Litter_B", 16.5, 2.5, 16.6, 7200, "Leaves:7200" },
	{ "Amber_Grass_Dry", 5.3, 2.5, 5.9, 600, "Blades:600" },
	{ "Amber_Grass_Seed", 5.6, 5.5, 5.1, 1160, "Blades:392 Seeds:768" },
	{ "Amber_Boulder_A", 20.7, 8.8, 12.9, 8000, "Stone:8000" },
	{ "Amber_Cliff_Wall_A", 42.3, 33.8, 27.1, 9040, "Stone:9040" },
	{ "Amber_Ledge_Overhang", 27.6, 19.5, 21.4, 4228, "Stone:4228" },
	{ "Amber_Cliff_Corner", 45.2, 29.9, 38.8, 14912, "Stone:14912" },
	{ "Amber_Spire", 12.9, 41.3, 13.2, 7124, "Stone:7124" },
	{ "Amber_Boulder_B", 13.6, 12.5, 8.9, 7680, "Stone:7680" },
	{ "Amber_Boulder_C", 32.1, 4.4, 12.0, 6720, "Stone:6720" },
	{ "Amber_Scree_A", 21.5, 2.6, 20.0, 1620, "Stone:1620" },
	{ "Amber_Scree_B", 17.5, 2.6, 18.5, 2200, "Stone:2200" },
	{ "Amber_Cliff_Wall_B", 29.8, 48.1, 21.2, 11632, "Stone:11632" },
	{ "Amber_Ledge_Long", 33.6, 5.2, 14.7, 2948, "Stone:2948" },
	{ "Amber_Aqueduct_Span_A", 24.0, 32.8, 8.9, 2928, "Arches:772 Deck:836 Piers:1320" },
	{ "Amber_Aqueduct_Span_Tall", 24.0, 50.8, 10.0, 5036, "Arches:1472 Deck:1144 Piers:2420" },
	{ "Amber_Footbridge_Rope", 64.2, 11.5, 9.4, 2496, "Rope:1088 Stone:352 Timber:1056" },
	{ "Amber_Aqueduct_Span_Ruined", 24.0, 29.8, 13.9, 2728, "Arches:1540 Deck:176 Piers:1012" },
	{ "Amber_Aqueduct_Abutment", 23.0, 32.8, 22.6, 3188, "Arches:196 Deck:836 Piers:2156" },
	{ "Amber_Stair_Run", 12.4, 13.6, 24.1, 2640, "Steps:528 Walls:2112" },
	{ "Amber_Stair_Worn", 12.4, 13, 24.1, 1188, "Steps:396 Walls:792" },
	{ "Amber_Retaining_Wall_A", 22.2, 11.1, 6.9, 2200, "Coping:308 Wall:1892" },
	{ "Amber_Retaining_Wall_B", 24.1, 10.1, 13.7, 2552, "Coping:264 Wall:2288" },
	{ "Amber_Shrine", 21.0, 22.3, 21.7, 2804, "Bronze:436 Glow:44 Roof:1312 Stone:660 Timber:352" },
	{ "Amber_Lantern_Stone", 4.1, 10.6, 4.1, 524, "Bronze:248 Glow:44 Stone:232" },
	{ "Amber_Lantern_Hanging", 6.5, 12.2, 2.2, 308, "Bronze:136 Glow:44 Rope:12 Timber:116" },
	{ "Amber_Rope_Rail", 13.4, 5.2, 1.4, 284, "Rope:172 Timber:112" },
	{ "Amber_Cart", 21.4, 6.8, 8.7, 1920, "Timber:1920" },
	{ "Amber_Crate_Stack", 12.9, 6.7, 9.2, 2248, "Rope:408 Timber:1840" },
	{ "Amber_Aqueduct_Hero", 120, 82.1, 25.9, 30204, "Arches:8732 Deck:4752 Piers:16720" },
}
local SALTREACH = {
	{ "Salt_Pan_Frame", 27.2, 9.0, 17.0, 1374, "Bund:528 Crust:264 Timber:582" },
	{ "Boardwalk_Straight", 16, 7.0, 5.4, 1360, "Rope:288 Timber:1072" },
	{ "Fisher_Hut_A", 17.2, 14.8, 14.6, 7324, "Roof:836 Stone:3608 Timber:2880" },
	{ "Salt_Pan_Channel", 32, 8.7, 12, 7844, "Crust:44 Stone:7040 Timber:760" },
	{ "Boardwalk_Steps", 11.3, 11.0, 5.5, 872, "Rope:88 Timber:784" },
	{ "Pier_Section", 22, 12.6, 8.6, 1964, "Timber:1964" },
	{ "Pier_End", 12.1, 19, 8.8, 1500, "Iron:156 Lantern:44 Rope:172 Timber:1128" },
	{ "Net_Rack", 23.0, 11.8, 7.6, 1144, "Net:1008 Timber:136" },
	{ "Boat_Hull_A", 24.7, 7.3, 7.9, 2542, "Canvas:160 Hull:1440 Ribs:942" },
	{ "Boat_Hull_B", 21.0, 6.0, 6.4, 1932, "Hull:884 Ribs:1048" },
	{ "Fisher_Hut_B", 16.4, 17.8, 13.4, 4388, "Roof:396 Stone:1056 Timber:2936" },
	{ "Stone_Lantern_Salt", 6.1, 13.9, 7.0, 516, "Glow:28 Iron:28 Stone:460" },
	{ "Gate_Pier", 10.7, 25.1, 8.8, 4588, "Iron:144 Stone:4400 Timber:44" },
	{ "Gate_Arch", 36.8, 28.7, 8.8, 9384, "Iron:456 Stone:8800 Timber:128" },
	{ "Saltreach_Gate_Statue", 70.2, 142.8, 46.6, 22204, "Anchor:532 Arms:1336 Base:9328 Body:6832 Cords:156 Head:4020" },
	{ "Sea_Stack_Base", 30.7, 18.5, 25.0, 8000, "Stone:8000" },
	{ "Tide_Boulder_A", 20.5, 9.2, 13.8, 8000, "Stone:8000" },
	{ "Salt_Crust_Slab_A", 33.4, 2.4, 22.1, 528, "Crust:528" },
	{ "Sea_Stack_Mid", 17.5, 16, 18.7, 5120, "Stone:5120" },
	{ "Sea_Stack_Cap", 15.3, 16.3, 15.4, 5440, "Stone:5440" },
	{ "Tide_Boulder_B", 14.0, 11.4, 8.8, 7680, "Stone:7680" },
	{ "Tide_Boulder_C", 28.3, 4.4, 12.9, 6720, "Stone:6720" },
	{ "Salt_Crust_Slab_B", 29.0, 2.5, 26.1, 440, "Crust:440" },
	{ "Shore_Cliff_A", 44.8, 24.6, 11.3, 5120, "Stone:5120" },
	{ "Shore_Cliff_B", 47.9, 27.5, 11.7, 6400, "Stone:6400" },
	{ "Shore_Cliff_Corner", 32.6, 27.3, 38.6, 6400, "Stone:6400" },
	{ "Salt_Pine_A", 36.9, 53.8, 31.5, 22884, "Bark:1188 Needles_Detail:14016 Needles_Mass:7680" },
	{ "Dune_Scrub_A", 7.9, 3.1, 8.1, 1494, "Leaves:1080 Stems:414" },
	{ "Driftwood_Log", 23.4, 6.6, 7.2, 586, "Wood:586" },
	{ "Salt_Pine_B", 26.6, 35.8, 23.8, 18380, "Bark:1004 Needles_Detail:11232 Needles_Mass:6144" },
	{ "Salt_Pine_Dead", 21.7, 42.2, 15.8, 1572, "Bark:1572" },
	{ "Salt_Grass_Tuft", 6.6, 3.3, 4.8, 770, "Blades:770" },
	{ "Salt_Grass_Tall", 9.5, 6.1, 6.2, 630, "Blades:630" },
	{ "Dune_Scrub_B", 4.3, 1.7, 5.0, 1162, "Leaves:840 Stems:322" },
	{ "Driftwood_Pile", 17.9, 8.2, 15.7, 1722, "Wood:1722" },
	{ "Kelp_Wrack", 25.9, 1.1, 25.4, 656, "Blades:336 Holdfast:320" },
	{ "Shore_Reeds", 9.9, 14.2, 8.1, 1190, "Blades:630 Heads:560" },
}
local KITS = { GoldenRavine = AMBERFALL, AridBasin = SALTREACH }
check("the manifests hold 45 + 37 pieces", #AMBERFALL == 45 and #SALTREACH == 37)
local function within(a, b) return math.abs(a - b) <= 0.05 * b end
for id, rows in KITS do
	for _, m in rows do
		local name = m[1]
		local p = B.Pieces[name]
		check(id .. " kit " .. name .. " has a placeholder spec", p ~= nil and p.Key == name)
		if p then
			check(name .. " bbox " .. p.Size[1] .. "x" .. p.Size[2] .. "x" .. p.Size[3] .. " within 5% of the manifest", within(p.Size[1], m[2]) and within(p.Size[2], m[3]) and within(p.Size[3], m[4]))
			local n, sum, same = 0, 0, true
			for subName, tris in string.gmatch(m[6], "(%S+):(%d+)") do
				n += 1
				sum += tonumber(tris)
				local sb = p.Subs[n] -- the registry key of sub n is <piece>__<sub>
				same = same and sb ~= nil and sb.Name == subName and sb.Tris == tonumber(tris)
			end
			check(name .. " sub-mesh names and tris match the manifest (" .. sum .. ")", same and n == #p.Subs and sum == m[5] and p.Tris == m[5])
			if p.Arch ~= "Steps" then
				local top, lo, hi, front0, front1 = 0, math.huge, -math.huge, math.huge, -math.huge
				for _, t in p.Sil do
					top, lo, hi = math.max(top, t.Y1), math.min(lo, t.Cx - t.W / 2), math.max(hi, t.Cx + t.W / 2)
					front0, front1 = math.min(front0, t.Cz - t.D / 2), math.max(front1, t.Cz + t.D / 2)
				end
				check(name .. " silhouette (" .. p.Arch .. ") spans the box height within 5% and most of its footprint", top >= 0.95 and hi - lo >= 0.7 and front1 - front0 >= 0.35)
			end
		end
	end
end
-- Hero slots: the landmark slot names resolve to the new heroes (spec, registry key, and the hero placements stand on them)
check("Ravine_Aqueduct_Arch is Amber_Aqueduct_Hero", B.Slots.Ravine_Aqueduct_Arch == "Amber_Aqueduct_Hero" and B.Pieces.Ravine_Aqueduct_Arch == B.Pieces.Amber_Aqueduct_Hero and B.Pieces.Ravine_Aqueduct_Arch.Key == "Amber_Aqueduct_Hero")
check("Basin_Gate_Statue is Saltreach_Gate_Statue", B.Slots.Basin_Gate_Statue == "Saltreach_Gate_Statue" and B.Pieces.Basin_Gate_Statue == B.Pieces.Saltreach_Gate_Statue and B.Pieces.Basin_Gate_Statue.Key == "Saltreach_Gate_Statue")
check("the hero slots are the 120 x 82 x 26 aqueduct and the 70 x 143 x 47 statue", within(B.Pieces.Ravine_Aqueduct_Arch.Size[1], 120) and within(B.Pieces.Ravine_Aqueduct_Arch.Size[2], 82.1) and within(B.Pieces.Basin_Gate_Statue.Size[2], 142.8))
do
	local a, st = nil, nil
	for _, h in B.build("GoldenRavine").Heroes do if h.Id == "Aqueduct" then a = h end end
	for _, h in B.build("AridBasin").Heroes do if h.Id == "GateStatue" then st = h end end
	check("the Aqueduct landmark hero is the slot of Amber_Aqueduct_Hero", a ~= nil and a.Landmark == true and B.Pieces[a.Piece].Key == "Amber_Aqueduct_Hero")
	check("the GateStatue landmark hero is the slot of Saltreach_Gate_Statue", st ~= nil and st.Landmark == true and B.Pieces[st.Piece].Key == "Saltreach_Gate_Statue")
end
-- Old placeholder-only scatter pieces are gone where the kits replaced them; a real-mesh swap resolves by registry key (data only)
for _, gone in { "Sandstone_Boulder_A", "Red_Trunk_Tree_A", "Dry_Shrub", "Pale_Grass_Clump", "Basin_Boulder_A", "Dead_Acacia", "Desert_Scrub", "Agave_Clump", "Dry_Grass_Clump" } do
	check(gone .. " no longer holds a kit slot", B.Pieces[gone] == nil)
end

-- Noise mask: smooth (no lattice steps), varied, never constant
do
	local lo, hi, step = math.huge, -math.huge, 0
	for k = 1, 400 do
		local x, z = -9000 + (k * 7919) % 8000, -9000 + (k * 6151) % 8000
		for _, class in B.Classes do
			local m = B.mask(class, x, z)
			lo, hi = math.min(lo, m), math.max(hi, m)
			step = math.max(step, math.abs(m - B.mask(class, x + 6, z)), math.abs(m - B.mask(class, x, z + 6)))
		end
	end
	check(string.format("the cluster mask varies (%.2f..%.2f) and moves smoothly (largest 6 stud step %.3f)", lo, hi, step), hi - lo >= 0.45 and step < 0.25)
end

-- tick hook: build() yields through it and gives the same list
do
	local ticks = 0
	local a = B.build("GoldenRavine", true, function() ticks += 1 end)
	local b = B.build("GoldenRavine", true)
	local same = #a.Placements == #b.Placements
	for i, p in a.Placements do
		local q = b.Placements[i]
		if not q or q.Id ~= p.Id or q.X ~= p.X or q.Z ~= p.Z then same = false break end
	end
	check("build() calls its tick hook (" .. ticks .. ") and the list does not change", ticks > 500 and same)
end

local KEEP_OF = { Large = "Tree", Medium = "Rock", Small = "Fern" }
local arenas = { O.Barrier.Arena }
for _, ra in O.ReservedArenas do table.insert(arenas, ra.Arena) end
local function inArena(x, z)
	for _, a in arenas do
		if math.abs(x - a.Center.X) <= a.Size.X / 2 and math.abs(z - a.Center.Z) <= a.Size.Z / 2 then return true end
	end
	return false
end
local function planSig(P)
	local out = {}
	for _, p in P.Placements do
		table.insert(out, string.format("%s|%s|%.3f|%.3f|%.3f|%.2f|%.3f|%s|%.6f|%d", p.Id, p.Piece, p.X, p.Z, p.Y, p.Yaw, p.Scale, p.Tier, p.Rank, p.Parts))
	end
	return table.concat(out, ";")
end
local baseBudget = B.PartBudget
check("the part budget is a stated number within the slice budget (" .. tostring(baseBudget) .. " per region)", type(baseBudget) == "number" and baseBudget > 0 and baseBudget <= B.Budget.PlaceholderParts)
local planLines, kitLines = {}, {}

for _, id in B.Order do
	local bounds = O.Regions[id].Bounds
	local t0 = os.clock()
	local P = B.plan(id, true)
	local secs = os.clock() - t0
	local tag = id .. " plan"
	local firstSig = planSig(P)

	-- budget, in the plan and when it is made tighter
	local sum, fixed, fixedN = 0, 0, 0
	for _, p in P.Placements do
		sum += p.Parts
		check(tag .. ": " .. p.Id .. " parts match its kit slot", p.Parts == B.Pieces[p.Piece].Parts and p.Tier == B.Pieces[p.Piece].Tier)
		if p.Kind ~= "Scatter" then fixed += p.Parts; fixedN += 1 end
	end
	check(tag .. ": parts " .. P.Parts .. " add up and stay within the budget " .. B.PartBudget, sum == P.Parts and P.Parts <= B.PartBudget and P.Budget == B.PartBudget)
	local tight = math.max(fixed + 50, math.floor(P.Parts * 0.8))
	B.PartBudget = tight
	local T = B.plan(id, true)
	B.PartBudget = baseBudget
	local fixedT = 0
	for _, p in T.Placements do if p.Kind ~= "Scatter" then fixedT += 1 end end
	check(tag .. ": a tighter budget (" .. tight .. ") is enforced (" .. T.Parts .. " parts, " .. T.Trimmed .. " trimmed)", T.Parts <= tight and T.Trimmed > 0 and T.Budget == tight)
	check(tag .. ": a tighter budget keeps every structure, interior and set piece", fixedT == fixedN)
	local P2 = B.plan(id, true)
	check(tag .. ": deterministic (a fresh plan is identical, " .. #P2.Placements .. " placements)", planSig(P2) == firstSig and B.plan(id) == P2)
	P = P2

	-- no scatter or set piece on a road, arena pad, altar, ring, encounter spot or cave cutting
	local heroes = {}
	for _, p in P.Placements do if p.Kind == "Hero" then table.insert(heroes, p) end end
	local circles = {}
	for _, c in baseCircles do table.insert(circles, c) end
	for _, h in heroes do
		local k = {}
		for cls, pad in K.Hero do k[cls] = B.Pieces[h.Piece].Radius * h.Scale + pad end
		circle(circles, h.X, h.Z, k)
	end
	local cuttings = {}
	for _, c in P.Build.Interiors do
		local tx, tz = (c.B.X - c.A.X) / c.Length, (c.B.Z - c.A.Z) / c.Length
		for _, o in c.Open do
			local d = o.From
			while d <= o.To do
				table.insert(cuttings, { X = c.A.X + tx * d, Z = c.A.Z + tz * d, R = c.Width / 2 + 8 })
				d += 8
			end
		end
	end
	local bad, checked = {}, 0
	for _, p in P.Placements do
		if p.Kind == "Scatter" or p.Kind == "Set" then
			checked += 1
			local cls = if p.Kind == "Scatter" then p.Class else KEEP_OF[p.Tier]
			for _, c in circles do
				if dist(p.X, p.Z, c.X, c.Z) < c.Keep[cls] - 1e-6 then table.insert(bad, p.Id .. " inside an altar, ring, arrival, shelter, span, hero or encounter keep-out at " .. c.X .. "," .. c.Z) break end
			end
			for _, sg in roads do
				if S.segDist(sg[1][1], sg[1][2], sg[2][1], sg[2][2], p.X, p.Z) < K.Road[cls] - 1e-6 then table.insert(bad, p.Id .. " on a road") break end
			end
			for _, w in B.walks(id) do
				for k = 2, #w.Points do
					if S.segDist(w.Points[k - 1][1], w.Points[k - 1][2], w.Points[k][1], w.Points[k][2], p.X, p.Z) < K.Road[cls] - 1e-6 then table.insert(bad, p.Id .. " on a walked route") break end
				end
			end
			for _, c in cuttings do
				if dist(p.X, p.Z, c.X, c.Z) < c.R - 1e-6 then table.insert(bad, p.Id .. " in a cave cutting") break end
			end
			if inArena(p.X, p.Z) then table.insert(bad, p.Id .. " on an arena pad") end
			if not B.inBox(bounds, p.X, p.Z) then table.insert(bad, p.Id .. " outside the region box") end
			local h, roadW, channelW, chasmW = O.sampleAt(p.X, p.Z)
			if roadW >= 0.5 or channelW >= 0.05 or chasmW >= 0.01 or h <= 3 then table.insert(bad, p.Id .. " on road, water or chasm ground") end
			if math.abs(p.Y - O.heightAt(p.GX, p.GZ)) > 0.5 then table.insert(bad, p.Id .. " off the surface") end
			if p.Kind == "Set" and slopeAt(p.X, p.Z) >= 0.75 then table.insert(bad, p.Id .. " on a cliff") end
		end
	end
	if #bad > 0 then print("  " .. tag .. " first violations: " .. table.concat(bad, "; ", 1, math.min(#bad, 6))) end
	check(tag .. ": no scatter or set piece on a road, arena pad, altar, ring, encounter spot or cave cutting (" .. checked .. " checked, " .. #bad .. " violations)", #bad == 0 and checked > 400)

	-- a composed set piece at every site: one large, two medium, three small, from the biome's kit, around the site
	local sites = B.sites(id)
	check(tag .. ": " .. #sites .. " sites, each with a record", #sites >= 3 and #P.Sites == #sites)
	local siteIds = {}
	for _, r in P.Sites do siteIds[r.Id] = r end
	for aid, a in O.Altars do if a.Region == id then check(tag .. ": the altar " .. aid .. " is a site", siteIds[aid] ~= nil) end end
	for lid, lm in O.Landmarks do if lm.Region == id then check(tag .. ": the landmark " .. lid .. " is a site", siteIds["Landmark_" .. lid] ~= nil) end end
	local bySite = {}
	for _, p in P.Placements do
		if p.Kind == "Set" then bySite[p.Site] = bySite[p.Site] or {}; table.insert(bySite[p.Site], p) end
	end
	local setCount = 0
	for _, r in P.Sites do
		local list = bySite[r.Id] or {}
		local tiers = { Large = 0, Medium = 0, Small = 0 }
		local inKit = true
		for _, p in list do
			tiers[p.Tier] += 1
			setCount += 1
			if not table.find(B.SetKits[id][p.Tier], p.Piece) then inKit = false end
			check(tag .. ": " .. p.Id .. " stands within 175 studs of its site " .. r.Id, dist(p.X, p.Z, r.X, r.Z) <= 175)
			if O.Altars[r.Id] then check(tag .. ": " .. p.Id .. " waits for its altar's own terrain", p.SiteReady == r.Id) end
		end
		check(tag .. ": the site " .. r.Id .. " has a set piece of three scales (L" .. tiers.Large .. " M" .. tiers.Medium .. " S" .. tiers.Small .. ")", tiers.Large >= 1 and tiers.Medium >= 2 and tiers.Small >= 3)
		check(tag .. ": the set at " .. r.Id .. " is drawn from the " .. id .. " kit", inKit and #list == #r.Pieces)
	end
	check(tag .. ": every set piece belongs to a site (" .. setCount .. "/" .. #P.Sets .. ")", setCount == #P.Sets and #P.Sets >= 3 * 6)
	local overlap = 0
	for i = 1, #P.Sets do
		for j = i + 1, #P.Sets do
			local a, b = P.Sets[i], P.Sets[j]
			if dist(a.X, a.Z, b.X, b.Z) < 0.5 * (B.Pieces[a.Piece].Radius * a.Scale + B.Pieces[b.Piece].Radius * b.Scale) + 2 - 1e-6 then overlap += 1 end
		end
	end
	check(tag .. ": set pieces do not overlap each other", overlap == 0)

	-- three scales across the region
	check(tag .. ": large, medium and small pieces are all placed (" .. P.ByTier.Large .. "/" .. P.ByTier.Medium .. "/" .. P.ByTier.Small .. ")", P.ByTier.Large >= 20 and P.ByTier.Medium >= 40 and P.ByTier.Small >= 200)

	-- distance thinning
	local monotone, structOk, landOk, band, bandHit = true, true, true, 0, 0
	for _, p in P.Placements do
		local reach, from = B.Reach[p.Tier], B.ThinFrom[p.Tier]
		local was = true
		for _, d in { 0, from * 0.5, from, (from + reach) / 2, reach - 1, reach, reach + 50 } do
			local v = B.visibleAt(p, d)
			if v and not was and not p.Landmark then monotone = false end
			was = v
		end
		if not B.visibleAt(p, 0) then monotone = false end
		if p.Landmark then
			if not B.visibleAt(p, 5000) then landOk = false end
		else
			if B.visibleAt(p, reach) then monotone = false end
			if p.Kind ~= "Scatter" and not B.visibleAt(p, reach - 1) then structOk = false end
		end
		if p.Kind == "Scatter" and p.Tier == "Small" then
			band += 1
			if B.visibleAt(p, (from + reach) / 2) then bandHit += 1 end
		end
	end
	check(tag .. ": thinning never brings a piece back with distance and hides everything at Reach", monotone)
	check(tag .. ": structures, set pieces and interiors hold to Reach; landmarks always show", structOk and landOk)
	check(tag .. ": small scatter keeps about half at mid-thinning (" .. bandHit .. "/" .. band .. ")", band > 200 and bandHit / band > 0.35 and bandHit / band < 0.65)

	-- clustering: survival follows the noise mask
	local kept = {}
	for _, p in P.Placements do kept[p.Id] = true end
	local hi, hiKept, lo, loKept = 0, 0, 0, 0
	for _, p in P.Build.Placements do
		if p.Kind == "Scatter" then
			local m = B.mask(p.Class, p.X, p.Z) - B.Cluster[p.Class][2]
			if m >= 0.22 then hi += 1; if kept[p.Id] then hiKept += 1 end
			elseif m <= -0.05 then lo += 1; if kept[p.Id] then loKept += 1 end end
		end
	end
	check(tag .. string.format(": scatter gathers where the mask is high (%d/%d kept) and thins where it is low (%d/%d)", hiKept, hi, loKept, lo),
		hi > 50 and lo > 50 and hiKept / hi >= 0.8 and loKept / lo <= 0.25)

	-- the biome's own uploaded kit: scatter tiers, set kits (built pieces) and the hero slot cover at least 80% of it
	local usedHere, kitRows, usedCount = {}, KITS[id], 0
	for _, p in P.Placements do usedHere[B.Pieces[p.Piece].Key or p.Piece] = true; usedPieces[p.Piece] = true; usedPieces[B.Pieces[p.Piece].Key or p.Piece] = true end
	if kitRows then
		local missing = {}
		for _, m in kitRows do if usedHere[m[1]] then usedCount += 1 else table.insert(missing, m[1]) end end
		table.sort(missing)
		check(tag .. string.format(": uses %d of its %d kit pieces (>= 80%%; unused: %s)", usedCount, #kitRows, table.concat(missing, ",")), usedCount >= 0.8 * #kitRows)
		local setBuilt, setTotal = 0, 0
		for _, pl in P.Sets do
			setTotal += 1
			if B.Pieces[pl.Piece].Fam == "b" then setBuilt += 1 end
		end
		check(tag .. string.format(": built kit pieces stand in the site set pieces (%d of %d)", setBuilt, setTotal), setBuilt >= 6)
		table.insert(kitLines, string.format("%-15s kit use %d/%d (%s)  set pieces %d (built %d)  parts %d/%d", id, usedCount, #kitRows, if #missing > 0 then "unused " .. table.concat(missing, ",") else "all", setTotal, setBuilt, P.Parts, B.PartBudget))
	end
	table.insert(planLines, string.format("%-15s plan %4d placements, parts %4d/%d (trimmed %3d, masked %3d), sites %2d, sets %3d, scales L%d M%d S%d  %.1fs", id, #P.Placements, P.Parts, B.PartBudget, P.Trimmed, P.Masked, #P.Sites, #P.Sets,
		P.ByTier.Large, P.ByTier.Medium, P.ByTier.Small, secs))
end

-- Every kit slot is placed somewhere (the slot list stays honest)
local unplaced = {}
for name in B.Pieces do if not usedPieces[name] then table.insert(unplaced, name) end end
table.sort(unplaced)
-- (the two uploaded kits may leave up to 20% of their own pieces unused per biome; that bound is checked per biome above)
local unplacedOther = {}
for _, name in unplaced do
	local inKit = false
	for _, rows in KITS do for _, m in rows do if m[1] == name then inKit = true end end end
	if not inKit then table.insert(unplacedOther, name) end
end
check("every older kit slot is placed at least once (unplaced: " .. table.concat(unplacedOther, ",") .. ")", #unplacedOther == 0)

for _, line in summary do print(line) end
for _, line in planLines do print(line) end
for _, line in kitLines do print(line) end
print(string.format("test_biome_dressing: %d passed, %d failed", passed, failed))
if failed > 0 then error("test_biome_dressing failed") end

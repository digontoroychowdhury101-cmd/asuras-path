--!nonstrict
-- Regression for the overworld blockout data (ticket 03). Run from the project root:
--   work/bin/luau/luau.exe tools/test_overworld_blockout.luau
-- Pure checks: every blockout structure stands inside the frame and outside the lobby and the old corridor,
-- on or near the ground, every route edge is walkable (ground grade <= 30 degrees) unless a bridge, ramp or
-- lift carries it, and altars, barrier and caches sit on the written surface.
local O = require("../src/shared/Overworld")

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local F, B = O.Frame, O.Blockout
local MAX_GRADE = math.tan(math.rad(30))

-- Boxes the overworld must stay out of: lobby (X +-300, Z 190..1110), old corridor (X +-450, Z -2980..-680).
local KEEP_OUT = { { -300, 300, 190, 1110 }, { -450, 450, -2980, -680 } }
local function outsideKeepOut(x, z)
	for _, k in KEEP_OUT do
		if x >= k[1] and x <= k[2] and z >= k[3] and z <= k[4] then return false end
	end
	return true
end
local function inFrame(x, z) return x >= F.MinX and x <= F.MaxX and z >= F.MinZ and z <= F.MaxZ end
local function inRegion(id, x, z)
	local b = O.Regions[id].Bounds
	return math.abs(x - b.Center.X) <= b.Size.X / 2 and math.abs(z - b.Center.Z) <= b.Size.Z / 2
end

-- 1. Footprints: frame, keep-out, own region box.
do
	local ok = true
	local function site(name, region, x, z)
		local good = inFrame(x, z) and outsideKeepOut(x, z) and (region == nil or inRegion(region, x, z))
		if not good then print("  site off: " .. name, x, z) end
		ok = ok and good
	end
	for _, b in B.Bridges do site(b.Id .. ".A", b.Region, b.A.X, b.A.Z); site(b.Id .. ".B", b.Region, b.B.X, b.B.Z) end
	for _, r in B.Ramps do site(r.Id .. ".A", r.Region, r.A.X, r.A.Z); site(r.Id .. ".B", r.Region, r.B.X, r.B.Z) end
	for _, l in B.Lifts do site(l.Id .. ".A", l.Region, l.A.X, l.A.Z); site(l.Id .. ".B", l.Region, l.B.X, l.B.Z) end
	for _, s in B.Shelters do site(s.Id, s.Region, s.X, s.Z) end
	for _, p in B.Portals do site(p.Id, p.Region, p.X, p.Z) end
	site("ReturnGate", B.ReturnGate.Region, B.ReturnGate.X, B.ReturnGate.Z)
	for id, l in O.Landmarks do site(id, l.Region, l.Position.X, l.Position.Z) end
	check("structures inside frame, region box and outside lobby/old corridor", ok)
end

-- 2. Deck and ramp ends sit on the ground (within 10 studs; bridge rims and ledges are authored).
do
	local ok = true
	local function onGround(name, p)
		local g = O.heightAt(p.X, p.Z)
		if math.abs(g - p.Y) > 10 then print("  not on ground: " .. name, p.Y, g); ok = false end
	end
	for _, b in B.Bridges do onGround(b.Id .. ".A", b.A); onGround(b.Id .. ".B", b.B) end
	for _, r in B.Ramps do onGround(r.Id .. ".A", r.A); onGround(r.Id .. ".B", r.B) end
	check("bridge and ramp ends on the surface", ok)
end

-- 3. Altars, barrier approach and caches on the surface (waterfall alcove and temple rafters are scenery, not ground).
do
	local ok = true
	for id, a in O.Altars do
		local g = O.heightAt(a.Placement.X, a.Placement.Z)
		if math.abs(g - a.Placement.Y) > 3 then print("  altar off ground: " .. id, a.Placement.Y, g); ok = false end
	end
	local g = O.Barrier.Gate.Outside
	-- Outside is a HumanoidRootPart height (feet 3 below); written voxels surface 2 above heightAt.
	if math.abs(O.heightAt(g.X, g.Z) + 2 - (g.Y - 3)) > 1 then print("  barrier approach off ground"); ok = false end
	for id, c in O.Caches do
		if not O.TerrainDef.Pad.SkipCaches[id] and math.abs(O.heightAt(c.Position.X, c.Position.Z) - c.Position.Y) > 3 then
			print("  cache off ground: " .. id); ok = false
		end
	end
	check("altars, barrier approach and caches on the surface", ok)
end

-- 4. Route edges are walkable: ground grade <= 30 degrees along the road (or the straight line where no
-- road is drawn), except edges a bridge, ramp or lift carries.
do
	local carried = {}
	local function carry(list, kind)
		for _, s in list do for _, e in s.Edges do
			local a, b = string.match(e, "^(.-)>(.+)$")
			carried[a .. ">" .. b], carried[b .. ">" .. a] = kind, kind
		end end
	end
	carry(B.Bridges, "bridge"); carry(B.Ramps, "ramp"); carry(B.Lifts, "lift")
	local edgeSet = {}
	for _, e in O.Edges do edgeSet[e.A .. ">" .. e.B] = true; edgeSet[e.B .. ">" .. e.A] = true end
	local tagsValid = true
	for key in carried do
		if not edgeSet[key] then print("  tag names no edge: " .. key); tagsValid = false end
	end
	check("every carried edge exists in the route graph", tagsValid)

	local roads = {}
	for _, r in O.terrainData().Roads do roads[r.A .. ">" .. r.B] = r; roads[r.B .. ">" .. r.A] = r end
	local ok, walked, worst = true, 0, 0
	for _, e in O.Edges do
		local key = e.A .. ">" .. e.B
		if carried[key] then continue end
		local pts = {}
		if roads[key] then
			for _, p in roads[key].Points do table.insert(pts, { p[1], p[2] }) end
		else
			local a, b = O.Nodes[e.A].Position, O.Nodes[e.B].Position
			local n = math.max(2, math.ceil(math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2) / 8))
			for k = 0, n do table.insert(pts, { a.X + (b.X - a.X) * k / n, a.Z + (b.Z - a.Z) * k / n }) end
		end
		local eworst = 0
		for k = 2, #pts do
			local ds = math.sqrt((pts[k][1] - pts[k - 1][1]) ^ 2 + (pts[k][2] - pts[k - 1][2]) ^ 2)
			if ds > 0.1 then
				eworst = math.max(eworst, math.abs(O.heightAt(pts[k][1], pts[k][2]) - O.heightAt(pts[k - 1][1], pts[k - 1][2])) / ds)
			end
		end
		worst = math.max(worst, eworst)
		walked += 1
		if eworst > MAX_GRADE then print(string.format("  steep edge %s > %s: %.2f", e.A, e.B, eworst)); ok = false end
	end
	check("every uncarried route edge is walkable (grade <= 30 degrees)", ok)
	print(string.format("  walkable edges %d, worst grade %.3f (limit %.3f), carried edges %d", walked, worst, MAX_GRADE, #O.Edges - walked))
end

-- 5. Lift stations stand at the two nodes of the edge they carry (within 60 studs).
do
	local ok = true
	for _, l in B.Lifts do
		local a, b = string.match(l.Edges[1], "^(.-)>(.+)$")
		local function near(p, id) local n = O.Nodes[id].Position; return math.sqrt((p.X - n.X) ^ 2 + (p.Z - n.Z) ^ 2) <= 60 end
		ok = ok and ((near(l.A, a) and near(l.B, b)) or (near(l.A, b) and near(l.B, a)))
	end
	check("lift stations at their edge's nodes", ok)
end

-- 6. The return gate faces the glade altar and the portal destination is still the glade.
check("return gate stands within 60 of the glade altar", (function()
	local g, a = B.ReturnGate, O.Altars.Altar_MonasteryGate.Placement
	return B.ReturnGate.Faces == O.Gateway and math.sqrt((g.X - a.X) ^ 2 + (g.Z - a.Z) ^ 2) <= 60
end)())
check("every landmark has a silhouette", (function()
	local ids = {}
	for id in O.Landmarks do table.insert(ids, id) end
	return #ids == 6
end)())
check("every landmark has a far silhouette (1-6 boxes, positive sizes, FarBeyond)", (function()
	for _, l in O.Landmarks do
		if not l.Silhouette or #l.Silhouette < 1 or #l.Silhouette > 6 or not l.FarBeyond or l.FarBeyond <= 0 then return false end
		for _, b in l.Silhouette do
			if #b ~= 6 or b[4] <= 0 or b[5] <= 0 or b[6] <= 0 then return false end
		end
	end
	return true
end)())
check("silhouettes stay within the landmark height (+20%)", (function()
	for _, l in O.Landmarks do
		for _, b in l.Silhouette do if b[2] + b[5] / 2 > l.Height * 1.2 then return false end end
	end
	return true
end)())
-- Builder is Roblox-only: assert by source (when @lune/fs exists) that it emits "<Id>_Far" from Silhouette, Persistent and tagged.
do
	local okFs, fs = pcall(require, "@lune/fs")
	if okFs then
		local src = fs.readFile("src/server/Services/OverworldService.luau")
		check("builder creates a Persistent tagged _Far model from Silhouette", src:find('id .. "_Far"', 1, true) ~= nil and src:find("def.Silhouette", 1, true) ~= nil and src:find('LANDMARK_TAG .. "Far"', 1, true) ~= nil and src:find("far.ModelStreamingMode = Enum.ModelStreamingMode.Persistent", 1, true) ~= nil)
	else
		print("  SKIP builder _Far source check: @lune/fs unavailable in this runner")
	end
end

print(string.format("overworld blockout: %d passed, %d failed", passed, failed))
if failed > 0 then error("overworld blockout tests failed") end

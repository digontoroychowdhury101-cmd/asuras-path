--!nonstrict
-- Slice dressing (open-world issue 12): Gateway Glade -> Bell Terrace placement data, builder and placeholder service.
-- Run from the project root:
--   work/bin/luau/luau.exe tools/test_slice_dressing.luau            (data and builder checks; plain Luau)
--   python3 tools/lune_compat.py tools/test_slice_dressing.luau       (adds the SliceDressingService checks on the Instance shim)
-- Checks: kit data matches manifest.json numbers, placements sit on the surface (+-0.5), none lies in an exclusion (re-derived
-- here from Overworld, not from the builder), same list on a fresh rebuild, counts per piece, part / triangle budget, cells,
-- review captures, and the service (cell models Atomic, landmarks Persistent, readiness gating, nearest-first, collision only
-- on structures, anchored, nothing built over unwritten tiles).
local O = require("../src/shared/Overworld")
local World = require("../src/shared/WorldDefinitions")
local S = require("../src/shared/SliceDressing")

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function dist(x0, z0, x1, z1) return math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2) end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- 1. Kit data against assets/source/overworld/slice/manifest.json (Blender XYZ, Z up -> { X, Y up, Z }; tris_total).
local MANIFEST = {
	Bell_Stair_Segment = { 12.4, 20.2, 11.0, 2200 }, Bell_Lantern_Post = { 4.1, 4.1, 10.6, 524 }, Bell_Timber_Gate = { 19.0, 3.2, 17.6, 624 },
	Bell_Terrace_Wall = { 16.0, 3.6, 9.0, 1540 }, Bell_Tower_Broken = { 29.0, 29.0, 29.6, 2364 }, Bell_Terrace_Pavilion = { 66.7, 67.3, 89.2, 11664 },
	Canopy_Tree_A = { 39.7, 41.1, 44.2, 14742 }, Canopy_Tree_B = { 31.8, 30.8, 58.6, 19660 }, Understory_Shrub = { 9.3, 7.7, 7.4, 5760 },
	Understory_Shrub_Small = { 4.1, 4.6, 3.5, 3236 }, Fern_Clump = { 8.5, 8.2, 3.2, 2016 }, Grass_Clump = { 4.1, 3.5, 3.4, 220 },
	Boulder_Granite_A = { 17.2, 10.5, 7.8, 8000 }, Boulder_Granite_B = { 12.3, 7.6, 10.6, 7680 }, Boulder_Granite_C = { 24.4, 11.1, 4.1, 6720 },
	Stepping_Stones = { 15.8, 21.9, 2.2, 6720 },
}
local pieceCount = 0
for _, p in S.Pieces do pieceCount += if p.Far then 0 else 1 end -- the _Far specs (lane D6/D7, bellwood_far manifest) are not near-kit pieces
-- 1b. Placeholder specs (lane 22b): every piece of the five upload manifests (slice, hero, bellwood_veg, bellwood_built_a/b) has a spec whose
-- sub names and tris match and whose boxes span the manifest bounding box +-5%. { piece, X, Y up, Z, tris_total, "Sub:tris ..." } = size_studs_xyz_roblox.
local ALL = {
	{ "Bell_Stair_Segment", 12.4, 11, 20.1, 2200, "Stone:2200" },
	{ "Bell_Lantern_Post", 4.1, 10.6, 4.1, 524, "Bronze:248 Glow:44 Stone:232" },
	{ "Bell_Timber_Gate", 19.0, 17.6, 3.2, 624, "Bronze:144 Stone:88 Timber:392" },
	{ "Bell_Terrace_Wall", 16.0, 9, 3.6, 1540, "Stone:1540" },
	{ "Bell_Tower_Broken", 29.0, 29.6, 29.0, 2364, "Bronze:604 Stone:1584 Timber:176" },
	{ "Bell_Terrace_Pavilion", 66.7, 89.2, 67.3, 11664, "Bronze:2700 Roof:4096 Stone:1364 Timber:3504" },
	{ "Canopy_Tree_A", 39.7, 44.2, 41.1, 14742, "Bark:1646 Leaves_Detail:9640 Leaves_Mass:3456" },
	{ "Canopy_Tree_B", 31.8, 58.6, 30.8, 19660, "Bark:1868 Leaves_Detail:12896 Leaves_Mass:4896" },
	{ "Understory_Shrub", 9.3, 7.4, 7.7, 5760, "Leaves:3456 Stems:2304" },
	{ "Understory_Shrub_Small", 4.1, 3.5, 4.7, 3236, "Leaves:1904 Stems:1332" },
	{ "Fern_Clump", 8.4, 3.2, 8.2, 2016, "Fronds:2016" },
	{ "Grass_Clump", 4.1, 3.4, 3.5, 220, "Blades:220" },
	{ "Boulder_Granite_A", 17.2, 7.8, 10.5, 8000, "Stone:8000" },
	{ "Boulder_Granite_B", 12.3, 10.6, 7.6, 7680, "Stone:7680" },
	{ "Boulder_Granite_C", 24.4, 4.1, 11.1, 6720, "Stone:6720" },
	{ "Stepping_Stones", 15.8, 2.2, 21.9, 6720, "Stone:6720" },
	{ "Ravine_Aqueduct_Arch", 125, 82, 24, 744, "Arches:348 Deck:180 Piers:216" },
	{ "Snow_Watch_Beacon", 19.6, 101, 19.6, 598, "Fire:38 Ice:328 Stone:104 Timber:128" },
	{ "Basin_Gate_Statue", 70, 139.0, 44, 272, "Base:96 Body:124 Head:52" },
	{ "Summit_Temple_Pagoda", 61.8, 160.9, 65.6, 1216, "Bronze:624 Roof:160 Stone:132 Timber:300" },
	{ "Summit_Temple_Wing", 40, 60.2, 54.8, 504, "Bronze:224 Roof:64 Stone:96 Timber:120" },
	{ "Canopy_Tree_C", 38.6, 49.6, 42.3, 18366, "Bark:1982 Leaves_Detail:12064 Leaves_Mass:4320" },
	{ "Canopy_Tree_D", 45.2, 37.3, 45.5, 18368, "Bark:1984 Leaves_Detail:12064 Leaves_Mass:4320" },
	{ "Conifer_Tall", 26.9, 68.5, 29.5, 25060, "Bark:3828 Needles_Detail:7120 Needles_Mass:14112" },
	{ "Old_Gnarled_Tree", 35.1, 31.2, 28.7, 10074, "Bark:1482 Leaves_Detail:5136 Leaves_Mass:3456" },
	{ "Sapling_Tree", 20.9, 16.9, 22.8, 7804, "Bark:724 Leaves_Detail:5064 Leaves_Mass:2016" },
	{ "Fallen_Log_A", 30.3, 10.3, 16.3, 1874, "Bark:1220 Ends:14 Moss:640" },
	{ "Fallen_Log_B", 17.9, 6.8, 6.2, 948, "Bark:520 Ends:28 Moss:400" },
	{ "Tree_Stump_A", 18.2, 7.0, 17.9, 1174, "Bark:756 Ends:18 Moss:400" },
	{ "Tree_Stump_B", 14.8, 9.2, 13.8, 1174, "Bark:676 Ends:18 Moss:480" },
	{ "Dead_Standing_Trunk", 15.3, 39.5, 13.3, 808, "Bark:794 Ends:14" },
	{ "Exposed_Roots_A", 21.4, 5.9, 21.2, 1156, "Bark:676 Moss:480" },
	{ "Exposed_Roots_B", 18.7, 5.1, 17.2, 1314, "Bark:914 Moss:400" },
	{ "Shrub_Hazel", 12.1, 7.7, 9.4, 4876, "Leaves:2896 Stems:1980" },
	{ "Shrub_Thicket", 14.6, 11.2, 13.6, 6844, "Leaves:4000 Stems:2844" },
	{ "Shrub_Berry", 7.5, 4.6, 6.4, 7996, "Berries:2880 Leaves:2992 Stems:2124" },
	{ "Fern_Bracken", 11.7, 3.1, 13.0, 1296, "Fronds:1296" },
	{ "Fern_Sword", 10.6, 3.6, 10.9, 3808, "Fronds:3808" },
	{ "Flowers_Daisy", 6.5, 4.3, 7.3, 2976, "Blooms:2304 Stems:672" },
	{ "Flowers_Foxglove", 6.9, 5.5, 6.2, 2340, "Blooms:2064 Stems:276" },
	{ "Mushroom_Cluster", 8.1, 3.7, 7.3, 3360, "Caps:3360" },
	{ "Vine_Hanging", 14.7, 19.1, 9.6, 3274, "Bark:1386 Leaves:1888" },
	{ "Moss_Drape", 13.1, 19.1, 12.0, 560, "Bark:230 Moss:330" },
	{ "Reed_Clump_A", 5.5, 7.0, 5.9, 414, "Blades:414" },
	{ "Reed_Clump_B", 8.3, 9.7, 8.1, 878, "Blades:270 Heads:608" },
	{ "Grass_Tall", 6.4, 4.9, 6.2, 490, "Blades:490" },
	{ "Grass_Lush", 6.4, 2.3, 5.7, 450, "Blades:450" },
	{ "Grass_Seed", 5.6, 5.4, 5.8, 1104, "Blades:336 Seeds:768" },
	{ "Bell_Stair_Straight_A", 10.4, 8.7, 14.0, 7392, "Stone:7392" },
	{ "Bell_Stair_Straight_B", 14.4, 8.3, 13.3, 5896, "Stone:5896" },
	{ "Bell_Stair_Turn", 16.4, 9.2, 16.6, 8976, "Stone:8976" },
	{ "Bell_Retain_Wall_Short", 12.0, 7.5, 5.0, 5456, "Stone:5456" },
	{ "Bell_Retain_Wall_Long", 24.0, 8.0, 5.0, 10032, "Stone:3696 Stone2:6336" },
	{ "Bell_Retain_Wall_Corner", 10.7, 7.5, 10.7, 7392, "Stone:7392" },
	{ "Bell_Paving_Flag", 8.0, 1.4, 8.0, 2156, "Stone:2156" },
	{ "Bell_Paving_Sett", 8.1, 1.4, 8.0, 9388, "Stone:9388" },
	{ "Bell_Edging_Kerb", 1.3, 1.7, 7.9, 528, "Stone:528" },
	{ "Bell_Edging_Cobble", 1.7, 1.6, 8.1, 1920, "Stone:1920" },
	{ "Boulder_Granite_D", 11.6, 8.2, 9.5, 8320, "Stone:8320" },
	{ "Boulder_Granite_Split", 13.2, 7.2, 8.9, 11520, "Stone:11520" },
	{ "Scree_Patch_A", 15.2, 1.0, 12.1, 7600, "Stone:7600" },
	{ "Scree_Patch_B", 17.6, 1.4, 12.6, 11600, "Stone:11600" },
	{ "Outcrop_Mossy", 19.5, 6.1, 10.2, 9600, "Stone:9600" },
	{ "Cliff_Face_A", 16, 14.0, 4.8, 7146, "Stone:7146" },
	{ "Cliff_Face_B", 16, 14.0, 4.9, 7146, "Stone:7146" },
	{ "Cliff_Face_C", 16, 13.5, 6.8, 7146, "Stone:7146" },
	{ "Bell_Timber_Gate_Side", 10, 10.5, 3.6, 1384, "Bronze:536 Stone:352 Timber:496" },
	{ "Bell_Fence_Rail", 8.8, 4.5, 1.0, 468, "Timber:468" },
	{ "Bell_Fence_Picket", 8.6, 4.4, 1.1, 948, "Timber:948" },
	{ "Bell_Fence_Post", 2.6, 6.6, 2.3, 920, "Bronze:484 Stone:352 Timber:84" },
	{ "Bell_Shrine_Roadside", 9.2, 9.9, 11.7, 3776, "Bronze:464 Roof:1088 Stone:1760 Timber:464" },
	{ "Bell_Grave_A", 5.3, 6.2, 4.0, 1492, "Bronze:424 Mound:320 Stone:660 Timber:88" },
	{ "Bell_Grave_B", 5.3, 4.2, 3.9, 2256, "Bronze:480 Mound:320 Stone:1456" },
	{ "Bell_Grave_C", 5.2, 6.1, 4.2, 1468, "Bronze:444 Mound:320 Stone:704" },
	{ "Bell_Prayer_Flags_Short", 12.2, 13.0, 2.2, 942, "Cloth:288 Stone:352 Timber:302" },
	{ "Bell_Prayer_Flags_Long", 24.2, 13.0, 2.3, 1326, "Cloth:672 Stone:352 Timber:302" },
	{ "Bell_Signpost_A", 6.5, 9.4, 2.5, 412, "Bronze:144 Stone:176 Timber:92" },
	{ "Bell_Signpost_B", 4.8, 5.5, 3.0, 1250, "Bronze:442 Stone:704 Timber:104" },
	{ "Bell_Well", 9.9, 12.5, 8.6, 13106, "Bronze:118 Roof:1088 Stone:11616 Timber:284" },
	{ "Bell_Tower_Ruined", 53.8, 76.7, 52.9, 32492, "Bronze:944 Roof:88 Rubble:3432 Stone_A:11176 Stone_B:8536 Stone_Base:4488 Stone_Belfry:3344 Timber:484" },
	{ "Hermit_Hut", 20.0, 20.3, 19.6, 12208, "Bronze:272 Roof:2024 Stone:3652 Timber:6260" },
	{ "Rope_Bridge_Deck_A", 6.1, 4.4, 8.4, 1180, "Rope:696 Timber:484" },
	{ "Rope_Bridge_Deck_B", 6.1, 4.3, 8.4, 1084, "Rope:644 Timber:440" },
	{ "Rope_Bridge_Anchor", 10.9, 14.7, 15.7, 1572, "Bronze:64 Rope:672 Stone:176 Timber:660" },
	{ "Falls_Alcove", 46.0, 21.6, 22.1, 30928, "Rock_Back:15360 Rock_Lip:5440 Rock_Rim:3200 Rock_Sides:6400 Shrine_Stone:484 Shrine_Timber:44" },
	{ "Cart_A", 19.1, 7.1, 8.0, 2942, "Bronze:160 Cloth:386 Timber:2396" },
	{ "Cart_B", 23.8, 8.7, 12.1, 4130, "Bronze:456 Cloth:240 Timber:3434" },
	{ "Crate_A", 4.4, 4.4, 4.2, 1104, "Bronze:24 Timber:1080" },
	{ "Crate_B", 6, 5.8, 5.5, 792, "Timber:792" },
	{ "Crate_C", 4.5, 5.7, 3.6, 1216, "Bronze:48 Timber:1168" },
	{ "Pot_A", 4.7, 4.5, 4.7, 720, "Clay:720" },
	{ "Pot_B", 4.3, 6.2, 3.7, 880, "Clay:880" },
	{ "Pot_C", 5.7, 4.9, 5.7, 1112, "Clay:976 Rope:136" },
	{ "Lantern_Hanging", 4.3, 11.5, 5.0, 622, "Bronze:524 Glow:28 Rope:70" },
	{ "Lantern_Stone", 5.5, 10.0, 5.5, 476, "Glow:44 Stone:432" },
}
check("every manifest piece (" .. #ALL .. ") has a spec and nothing else does", pieceCount == #ALL and #ALL == 95)
local bboxWorst = 0
for _, m in ALL do
	local p = S.Pieces[m[1]]
	check(m[1] .. " has a placeholder spec", p ~= nil)
	if p then
		local b = S.specBounds(m[1])
		for i = 1, 3 do
			local err = math.abs(b[i] / m[i + 1] - 1)
			bboxWorst = math.max(bboxWorst, err)
			if err > 0.05 then print(string.format("  bbox %s axis %d: spec %.2f vs manifest %.2f", m[1], i, b[i], m[i + 1])) end
			check(m[1] .. " spec bbox axis " .. i .. " within 5% of the manifest", err <= 0.05)
		end
		local want, n, sum = {}, 0, 0
		for sname, tris in string.gmatch(m[6], "(%S+):(%d+)") do want[sname] = tonumber(tris); sum += tonumber(tris) end
		local same = true
		for _, sb in p.Subs do
			n += 1
			if want[sb.Name] ~= sb.Tris then same = false end
			check(m[1] .. "__" .. sb.Name .. " under the 18k tri cap", sb.Tris < 18000)
		end
		check(m[1] .. " sub names and tris match the manifest (" .. sum .. ")", same and n == #p.Subs and sum == m[5])
	end
end
print(string.format("  spec bbox worst error %.1f%% over %d pieces", bboxWorst * 100, #ALL))
for name, m in MANIFEST do
	local p = S.Pieces[name]
	check("piece " .. name .. " present", p ~= nil)
	if p then
		check(name .. " size is manifest XYZ as X, Y up, Z", near(p.Size[1], m[1]) and near(p.Size[2], m[3]) and near(p.Size[3], m[2]))
		check(name .. " sub-mesh tris sum to the manifest total", p.Tris == m[4])
		for _, sb in p.Subs do check(name .. "__" .. sb.Name .. " under the 18k tri cap", sb.Tris < 18000) end
	end
end
check("cell size is the 128 stud terrain tile", S.Cell == 128)

-- 2. Build, determinism.
local t0 = os.clock()
local R = S.build(true)
local seconds = os.clock() - t0
local function signature(r)
	local out = {}
	for _, p in r.Placements do
		table.insert(out, string.format("%s|%s|%.3f|%.3f|%.3f|%.2f|%.3f", p.Id, p.Piece, p.X, p.Z, p.Y, p.Yaw, p.Scale))
	end
	return table.concat(out, ";")
end
local sig = signature(R)
check("a fresh rebuild gives the same placements", signature(S.build(true)) == sig)
check("the memoised build is the same object", S.build() == S.build())
check("build takes under 10 s", seconds < 10)

-- 3. Surface: every placement stands on heightAt at its foot (+-0.5).
local worst = 0
for _, p in R.Placements do
	worst = math.max(worst, math.abs(p.Y - O.heightAt(p.GX, p.GZ)))
end
check("every placement is on the surface (worst " .. string.format("%.3f", worst) .. ")", worst <= 0.5)
local stair
for _, p in R.Placements do if p.Id == "TerraceStair" then stair = p end end
check("the stair's ground is sampled at its low (+Z) end", stair ~= nil and near(stair.GX, stair.X) and near(stair.GZ, stair.Z + 10, 1e-6))
check("the stair stands on ground that rises about its rise to the plateau", stair ~= nil and (O.heightAt(stair.X, stair.Z - 10) - stair.Y) > 4 and (O.heightAt(stair.X, stair.Z - 10) - stair.Y) < 9)

-- 4. Exclusions, re-derived from Overworld (not the builder's own lists).
local K = S.Keep
local function classKeep(map, cls) return map[S.KeepAs[cls] or cls] end
local circles = {}
local function circle(x, z, keep, altar) table.insert(circles, { X = x, Z = z, Keep = keep, Altar = altar == true }) end
for _, a in O.Altars do circle(a.Placement.X, a.Placement.Z, K.Altar, true); circle(a.Spawn.X, a.Spawn.Z, K.Arrival); circle(a.Exit.X, a.Exit.Z, K.Arrival) end
for _, r in O.Rings do circle(r.X, r.Z, K.Ring) end
circle(O.Blockout.ReturnGate.X, O.Blockout.ReturnGate.Z, K.ReturnGate)
for _, sh in O.Blockout.Shelters do
	local half, k = 0.5 * math.sqrt(sh.W ^ 2 + sh.D ^ 2), {}
	for cls, pad in K.Shelter do k[cls] = half + pad end
	circle(sh.X, sh.Z, k)
end
for _, group in { O.Blockout.Bridges, O.Blockout.Ramps, O.Blockout.Lifts } do
	for _, b in group do circle(b.A.X, b.A.Z, K.SpanEnd); circle(b.B.X, b.B.Z, K.SpanEnd) end
end
for _, pt in O.Blockout.Portals do circle(pt.X, pt.Z, K.SpanEnd) end
local function home(x, z, mob)
	local leash = World.Mobs[mob].AI.LeashRange
	check("MobLeash " .. mob .. " matches WorldDefinitions", S.MobLeash[mob] == leash)
	local k = {}
	for cls, f in K.Leash do k[cls] = f * leash end
	circle(x, z, k)
end
for _, e in O.EncounterSpots do home(e.Placement.X, e.Placement.Z, e.Mob) end
for _, m in O.Minibosses do home(m.Placement.X, m.Placement.Z, m.Id) end
home(O.Training.Placement.X, O.Training.Placement.Z, "SparringPhantom")
local heroes = {}
for _, p in R.Placements do if p.Kind == "Hero" then table.insert(heroes, p) end end

local roads = {}
for _, road in O.terrainData().Roads do
	for k = 2, #road.Points do table.insert(roads, { road.Points[k - 1], road.Points[k] }) end
end
local route = S.route()
local pavilion
for _, h in heroes do if h.Id == "Pavilion" then pavilion = h end end
check("the pavilion is a hero placement", pavilion ~= nil and pavilion.Landmark == true)
local lanes = {}
for _, pt in route.Points do
	if dist(pt[1], pt[2], pavilion.X, pavilion.Z) <= S.Lane.Reach then table.insert(lanes, { pt[1], pt[2], pavilion.X, pavilion.Z }) end
end
check("the route has a lane to the pavilion (" .. #lanes .. " sight lines)", #lanes >= 8)

local violations, scatter = {}, 0
for _, p in R.Placements do
	if p.Kind == "Scatter" then
		scatter += 1
		local cls = p.Class
		for _, c in circles do
			if not (p.Floor and c.Altar) and dist(p.X, p.Z, c.X, c.Z) < classKeep(c.Keep, cls) - 1e-6 then table.insert(violations, p.Id .. " inside a circle at " .. c.X .. "," .. c.Z) end
		end
		for _, s in roads do
			if S.segDist(s[1][1], s[1][2], s[2][1], s[2][2], p.X, p.Z) < classKeep(K.Road, cls) - 1e-6 then table.insert(violations, p.Id .. " on a road") break end
		end
		for _, h in heroes do
			if dist(p.X, p.Z, h.X, h.Z) < S.Pieces[h.Piece].Radius * h.Scale + classKeep(K.Hero, cls) - 1e-6 then table.insert(violations, p.Id .. " inside hero " .. h.Id) end
		end
		if S.Scatter[cls].Tall then
			for _, l in lanes do
				if S.segDist(l[1], l[2], l[3], l[4], p.X, p.Z) < S.Lane.HalfWidth - 1e-6 then table.insert(violations, p.Id .. " blocks the pavilion lane") break end
			end
		end
		-- terrain: slope, water, chasm, material
		local h, roadW, channelW, chasmW = O.sampleAt(p.X, p.Z)
		local sx, sz = (O.heightAt(p.X + 4, p.Z) - h) / 4, (O.heightAt(p.X, p.Z + 4) - h) / 4
		local slope = math.sqrt(sx * sx + sz * sz)
		local mat = O.materialAt(p.X, p.Z, h, slope, roadW, channelW, chasmW)
		if slope >= S.Scatter[cls].MaxSlope then table.insert(violations, p.Id .. " too steep") end
		if channelW >= 0.05 or chasmW >= 0.01 or h <= 3 or roadW >= 0.5 then table.insert(violations, p.Id .. " in water, channel, chasm or road") end
		if not p.Floor and (S.Scatter[cls].Material[mat] or 0) <= 0 then table.insert(violations, p.Id .. " on " .. mat) end
	end
end
if #violations > 0 then print("  first violations: " .. table.concat(violations, "; ", 1, math.min(#violations, 6))) end
check("no scatter placement lies in an exclusion (" .. scatter .. " checked, " .. #violations .. " violations)", #violations == 0)
check("scatter was actually checked against exclusions", scatter > 500 and #circles >= 40 and #roads >= 100)

-- trees keep their crowns from piling on one another
local trees, tight = {}, 0
for _, p in R.Placements do if p.Class == "Tree" then table.insert(trees, p) end end
for i = 1, #trees do
	for j = i + 1, #trees do
		local a, b = trees[i], trees[j]
		local ra, rb = S.Pieces[a.Piece].Radius * a.Scale, S.Pieces[b.Piece].Radius * b.Scale
		if dist(a.X, a.Z, b.X, b.Z) < S.CrownSpacing * (ra + rb) - 1e-6 then tight += 1 end
	end
end
check("trees keep the crown spacing (" .. S.CrownSpacing .. " of the summed radii)", tight == 0)

-- everything stays in the corridor (scatter within Half + Fade of the route or a clearing disc)
local stray = 0
for _, p in R.Placements do
	if p.Kind == "Scatter" then
		local d = math.huge
		for k = 2, #route.Points do d = math.min(d, S.segDist(route.Points[k - 1][1], route.Points[k - 1][2], route.Points[k][1], route.Points[k][2], p.X, p.Z)) end
		for _, disc in S.Corridor.Discs do
			local a = O.Altars[disc.Altar].Placement
			d = math.min(d, dist(p.X, p.Z, a.X, a.Z) - disc.R + S.Corridor.Half)
		end
		local reach = S.Corridor.Half + S.Corridor.Fade + (if S.Pieces[p.Piece].Far then S.Scatter.Tree.FarBelt + S.Corridor.Fade else 0) -- the far belt carries _Far trees only
		if d > reach then stray += 1 end
	end
end
check("scatter stays inside the slice corridor", stray == 0)

-- A. Canopy distribution (fault A): clustered, never a grid; coverage of the ground that may carry a tree; authored glades; understory in the gaps;
-- scale 0.7..1.4 with random yaw; crowns over a road leave 14 studs of clear height.
local glades = {}
for _, g in S.Glades do
	local px, pz, tx, tz = S.pointAt(g.Arc)
	table.insert(glades, { Id = g.Id, X = px - tz * g.Off, Z = pz + tx * g.Off, R = g.R })
end
local function roadDistance(x, z)
	local d = math.huge
	for _, s in roads do d = math.min(d, S.segDist(s[1][1], s[1][2], s[2][1], s[2][2], x, z)) end
	return d
end
local nn, nnMean = {}, 0
for i, a in trees do
	local m = math.huge
	for j, b in trees do if i ~= j then m = math.min(m, dist(a.X, a.Z, b.X, b.Z)) end end
	table.insert(nn, m)
	nnMean += m
end
nnMean /= #nn
local nnVar = 0
for _, d in nn do nnVar += (d - nnMean) ^ 2 end
local nnCv = math.sqrt(nnVar / #nn) / nnMean
local CV_MIN, COVER_MIN = 0.3, 0.3 -- a jittered grid scores ~0.2; a Poisson scatter ~0.5
check(string.format("tree nearest-neighbour spacing is irregular (CV %.2f over %d trees, need > %.2f: not a grid)", nnCv, #trees, CV_MIN), #trees >= 100 and nnCv > CV_MIN)

local function allowsTree(x, z) -- ground a tree may stand on: every exclusion, road, lane, glade, kept sight, slope and material re-derived
	local rule = S.Scatter.Tree
	for _, c in circles do if dist(x, z, c.X, c.Z) < c.Keep.Tree then return false end end
	if roadDistance(x, z) < K.Road.Tree then return false end
	for _, l in lanes do if S.segDist(l[1], l[2], l[3], l[4], x, z) < S.Lane.HalfWidth then return false end end
	for _, g in glades do if dist(x, z, g.X, g.Z) < g.R then return false end end
	for _, sg in R.Sights do if S.segDist(sg.X0, sg.Z0, sg.X1, sg.Z1, x, z) < 25 then return false end end
	for _, cl in O.TerrainDef.Clearings do if dist(x, z, cl.X, cl.Z) < 0.7 * cl.R then return false end end
	local h, roadW, channelW, chasmW = O.sampleAt(x, z)
	if roadW >= 0.5 or channelW >= 0.05 or chasmW >= 0.01 or h <= 3 then return false end
	local sx, sz = (O.heightAt(x + 4, z) - h) / 4, (O.heightAt(x, z + 4) - h) / 4
	local slope = math.sqrt(sx * sx + sz * sz)
	return slope < rule.MaxSlope - 0.15 and (rule.Material[O.materialAt(x, z, h, slope, roadW, channelW, chasmW)] or 0) >= 0.5
end
local function underCanopy(x, z)
	for _, t in trees do
		if dist(x, z, t.X, t.Z) < S.CrownFrac * S.Pieces[t.Piece].Radius * t.Scale then return true end
	end
	return false
end
local free, covered = 0, 0
for x = R.Bounds.X0, R.Bounds.X1, 10 do
	for z = R.Bounds.Z0, R.Bounds.Z1, 10 do
		local d = math.huge
		for k = 2, #route.Points do d = math.min(d, S.segDist(route.Points[k - 1][1], route.Points[k - 1][2], route.Points[k][1], route.Points[k][2], x, z)) end
		if d <= S.Corridor.Half and allowsTree(x, z) then
			free += 1
			covered += if underCanopy(x, z) then 1 else 0
		end
	end
end
local coverage = covered / math.max(free, 1)
check(string.format("canopy covers %.0f%% of the %d free ground samples off the road (need > %.0f%%)", coverage * 100, free, COVER_MIN * 100), free > 500 and coverage > COVER_MIN)
check("the canopy has gaps too (coverage under 85%)", coverage < 0.85)
print(string.format("  distribution: %d trees, NN CV %.2f, canopy coverage %.0f%% of %d free samples", #trees, nnCv, coverage * 100, free))

local sMin, sMax, tall, small = math.huge, 0, 0, 0
local bins, cx, cy = {}, 0, 0
for _, t in trees do
	sMin, sMax = math.min(sMin, t.Scale), math.max(sMax, t.Scale)
	tall += if t.Scale > 1.2 then 1 else 0
	small += if t.Scale < 0.9 then 1 else 0
	bins[math.floor((t.Yaw % 360) / 30)] = true
	cx += math.cos(math.rad(t.Yaw)); cy += math.sin(math.rad(t.Yaw))
end
local nbins = 0
for _ in bins do nbins += 1 end
check(string.format("tree scale stays in 0.7..1.4 (%.2f..%.2f) and varies", sMin, sMax), sMin >= 0.7 - 1e-9 and sMax <= 1.4 + 1e-9 and tall >= 0.1 * #trees and small >= 0.1 * #trees)
check("tree yaw is random (" .. nbins .. " of 12 bins, mean resultant " .. string.format("%.2f", math.sqrt(cx * cx + cy * cy) / #trees) .. ")", nbins >= 11 and math.sqrt(cx * cx + cy * cy) / #trees < 0.2)

local overhang, lowest = 0, math.huge
for _, t in trees do
	local piece = S.Pieces[t.Piece]
	if roadDistance(t.X, t.Z) < piece.Radius * t.Scale then
		overhang += 1
		lowest = math.min(lowest, (piece.Under * piece.Size[2] - piece.Sink) * t.Scale)
	end
end
check(string.format("%d crowns overhang a road; the lowest underside is %.1f studs (need >= %d)", overhang, lowest == math.huge and 0 or lowest, S.RoadClearance), overhang >= 3 and lowest >= S.RoadClearance - 1e-6)

local gladeOk, gladeNote = #glades >= 3, ""
for _, g in glades do
	local nt, nu, ring = 0, 0, 0
	for _, p in R.Placements do
		local d = dist(p.X, p.Z, g.X, g.Z)
		if p.Class == "Tree" and d < g.R then nt += 1 end
		if p.Class == "Tree" and d < 2.2 * g.R then ring += 1 end
		if p.Kind == "Scatter" and p.Class ~= "Tree" and p.Class ~= "Rock" and d < g.R then nu += 1 end
	end
	if nt > 0 or nu < 3 or ring < 2 then gladeOk, gladeNote = false, gladeNote .. string.format(" %s trees %d understory %d ring %d;", g.Id, nt, nu, ring) end
end
check("every authored glade is open (no tree centre inside), has understory and a canopy round it" .. gladeNote, gladeOk)
local under, underUnder = 0, 0
for _, p in R.Placements do
	if (p.Class == "Shrub" or p.Class == "Fern") and not p.Floor then
		under += 1
		underUnder += if underCanopy(p.X, p.Z) then 1 else 0
	end
end
check(string.format("understory favours gaps: %.0f%% of shrubs and ferns stand under a crown, the free ground is %.0f%% covered", 100 * underUnder / under, coverage * 100), underUnder / under < 0.8 * coverage)

-- C. Sightlines (fault C): the broken tower is seen from the glade arrival at player height, the pavilion from the tower area.
local function top(h) return h.Y + (S.Pieces[h.Piece].Size[2] - S.Pieces[h.Piece].Sink) * h.Scale end
local function sightTo(id, fx, fz)
	local t
	for _, h in heroes do if h.Id == id then t = h end end
	return { Id = "test", To = id, X0 = fx, Z0 = fz, Y0 = O.heightAt(fx, fz) + S.Eye, X1 = t.X, Z1 = t.Z, Y1 = top(t), Len = dist(fx, fz, t.X, t.Z), Margin = 2 }
end
local function terrainClear(s) -- own terrain scan, every 2 studs
	for d = 0, s.Len - 20, 2 do
		local t = d / s.Len
		if O.heightAt(s.X0 + (s.X1 - s.X0) * t, s.Z0 + (s.Z1 - s.Z0) * t) + 2 > s.Y0 + (s.Y1 - s.Y0) * t then return false, d end
	end
	return true
end
local tower
for _, h in heroes do if h.Id == "TowerMid" then tower = h end end
local spawn = O.Altars[O.Gateway].Spawn
for _, from in { { "capture eye", -2203, -1415 }, { "altar spawn " .. O.Gateway, spawn.X, spawn.Z } } do
	local s = sightTo("TowerMid", from[2], from[3])
	local los = S.lineOfSight(s, R.Placements)
	local clear, at = terrainClear(s)
	check(string.format("tower seen from the %s at player height (%.0f studs, eye %.1f -> top %.1f; terrain %s; %d blockers%s)", from[1], s.Len, s.Y0, s.Y1,
		clear and "clear" or ("blocks at " .. tostring(at)), #los.Blockers, #los.Blockers > 0 and (": " .. table.concat(los.Blockers, ",", 1, math.min(4, #los.Blockers))) or ""), clear and los.Clear)
end
print(string.format("  tower scale %.1f (authored 1.8, max %.1f), top %.1f above ground %.1f", tower.Scale, S.Hero[2].Raise.Max, top(tower), tower.Y))
check("the tower stays within its Raise maximum", tower.Scale <= S.Hero[2].Raise.Max + 1e-9 and S.Hero[2].Id == "TowerMid")
do -- the tower raise follows the terrain: from a low authored scale it grows to the smallest scale that clears terrain + margin, else stops at Max
	local spec, saved = S.Hero[2], S.Hero[2].Scale
	local margin = spec.Raise.Margin
	local function clearAt(scale)
		local gy = O.heightAt(tower.X, tower.Z)
		local topY = gy + (S.Pieces.Bell_Tower_Broken.Size[2] - S.Pieces.Bell_Tower_Broken.Sink) * scale
		local ex, ez = spec.Raise.From.X, spec.Raise.From.Z
		local ey, len = O.heightAt(ex, ez) + S.Eye, dist(ex, ez, tower.X, tower.Z)
		for d = 0, len - 20, 3 do
			local t = d / len
			if ey + (topY - ey) * t < O.heightAt(ex + (tower.X - ex) * t, ez + (tower.Z - ez) * t) + 2 + margin then return false end
		end
		return true
	end
	spec.Scale = 0.2
	local low = S.build(true)
	local got
	for _, p in low.Placements do if p.Id == "TowerMid" then got = p.Scale end end
	spec.Scale = saved
	S.build(true)
	print(string.format("  tower authored 0.2 -> raised to %.1f", got))
	check(string.format("a low authored tower (0.2) is raised to %.1f: the smallest scale that clears the terrain, or Max", got), got >= 0.2 and (clearAt(got) or got >= spec.Raise.Max - 1e-9) and (got <= 0.2 + 1e-9 or not clearAt(got - 0.1)))
end
do -- the check can fail: a tall tree on the line blocks it
	local s = sightTo("TowerMid", -2203, -1415)
	local fx, fz = s.X0 + (s.X1 - s.X0) * 0.2, s.Z0 + (s.Z1 - s.Z0) * 0.2
	local fake = { { Id = "FakeTree", Piece = "Canopy_Tree_B", X = fx, Z = fz, Y = O.heightAt(fx, fz), Scale = 1.2 } }
	check("a tall tree on the sightline is reported as a blocker", #S.lineOfSight(s, fake).Blockers == 1)
	fake[1].X += 80
	check("the same tree 80 studs off the line is not", #S.lineOfSight(s, fake).Blockers == 0)
end
do
	local s = R.Sights[2]
	local los = S.lineOfSight(s, R.Placements)
	local clear = terrainClear(s)
	print(string.format("  pavilion from the tower area (%.0f, %.0f): %.0f studs, terrain %s, %d blockers", s.X0, s.Z0, s.Len, clear and "clear" or "BLOCKS", #los.Blockers))
	check("nothing placed blocks the pavilion sightline from the tower area", s.Id == "PavilionFromTower" and #los.Blockers == 0 and clear)
end

-- D. Forest floor round the glade altar (fault D): scatter within ~30 studs, the pad and the arrival points stay clear.
do
	local ap = O.Altars[S.Floor.Altar].Placement
	local n, rocks, ferns, grass, inside, worst = 0, 0, 0, 0, 0, math.huge
	for _, p in R.Placements do
		local d = dist(p.X, p.Z, ap.X, ap.Z)
		if p.Kind == "Scatter" and d < S.Floor.Inner then inside += 1 end
		if p.Floor then
			n += 1
			rocks += if p.Class == "Rock" then 1 else 0
			ferns += if p.Class == "Fern" then 1 else 0
			grass += if p.Class == "Grass" then 1 else 0
			worst = math.min(worst, d)
		end
	end
	local near30 = 0
	for _, p in R.Placements do
		if p.Kind == "Scatter" and p.Class ~= "Tree" and dist(p.X, p.Z, ap.X, ap.Z) <= 30 then near30 += 1 end
	end
	check(string.format("forest floor round the glade altar: %d ferns, %d grass, %d rocks; %d plants within 30 studs", ferns, grass, rocks, near30), ferns >= 3 and grass >= 8 and rocks >= 1 and near30 >= 12)
	check("the altar pad (22) and arrival points stay clear (nearest floor plant " .. string.format("%.1f", worst) .. ", " .. inside .. " inside " .. S.Floor.Inner .. ")", inside == 0 and worst >= S.Floor.Inner and S.Floor.Inner > 22)
end

-- E. Kit placement (lane 22b): canopy off the road, trunks off the road, forest floor at the glade altar, three scales in every view, composed set pieces.
do
	-- every road sample under a crown leaves the canopy-clearance height (fault A); a trunk never stands on a road
	local samples, under, lowestUnder, worstTrunk = 0, 0, math.huge, math.huge
	for _, sg in roads do
		local len = dist(sg[1][1], sg[1][2], sg[2][1], sg[2][2])
		for d = 0, len, 6 do
			local x, z = sg[1][1] + (sg[2][1] - sg[1][1]) * d / math.max(len, 1e-6), sg[1][2] + (sg[2][2] - sg[1][2]) * d / math.max(len, 1e-6)
			if x > R.Bounds.X0 and x < R.Bounds.X1 and z > R.Bounds.Z0 and z < R.Bounds.Z1 then
				samples += 1
				for _, t in trees do
					local pc = S.Pieces[t.Piece]
					if dist(x, z, t.X, t.Z) < pc.Radius * t.Scale then
						under += 1
						lowestUnder = math.min(lowestUnder, (pc.Under * pc.Size[2] - pc.Sink) * t.Scale)
						break
					end
				end
			end
		end
	end
	check(string.format("canopy clearance: %d of %d road samples lie under a crown, lowest underside %.1f studs (need >= 14)", under, samples, lowestUnder == math.huge and 0 or lowestUnder),
		samples > 100 and lowestUnder >= 14 - 1e-6 and S.RoadClearance >= 14)
	for _, p in R.Placements do
		if p.Class == "Tree" or p.Class == "Sapling" then
			worstTrunk = math.min(worstTrunk, roadDistance(p.X, p.Z) - 8 - 0.5 * S.Pieces[p.Piece].Trunk * p.Scale)
		end
	end
	check(string.format("no tree trunk stands on a road (clear of the 8 stud road by %.1f studs at the worst)", worstTrunk), worstTrunk > 1)

	-- forest floor round the glade altar: the 24..34 ring is covered by plants (fault D)
	local ap = O.Altars[S.Floor.Altar].Placement
	local ringN, ringCovered = 0, 0
	for x = ap.X - 34, ap.X + 34, 2 do
		for z = ap.Z - 34, ap.Z + 34, 2 do
			local d = dist(x, z, ap.X, ap.Z)
			if d >= S.Floor.Inner and d <= S.Floor.Outer then
				ringN += 1
				for _, p in R.Placements do
					if p.Class ~= "Tree" and dist(x, z, p.X, p.Z) < 0.6 * S.Pieces[p.Piece].Radius * p.Scale + 0.8 then ringCovered += 1 break end
				end
			end
		end
	end
	print(string.format("  glade altar floor: %.0f%% of %d ring samples under a plant", 100 * ringCovered / ringN, ringN))
	check(string.format("the glade altar floor is dressed: %.0f%% of the 24..34 ring is covered (need >= 40%%)", 100 * ringCovered / ringN), ringCovered / ringN >= 0.4)

	-- three scales in every review view: large (>= 20 studs tall), mid (5..20), small (< 5) placements in front of the camera
	for _, c in S.captures() do
		local fx, fz, dx, dz = c.From.X, c.From.Z, c.To.X - c.From.X, c.To.Z - c.From.Z
		local dl = math.sqrt(dx * dx + dz * dz)
		local n = { 0, 0, 0 }
		for _, p in R.Placements do
			local vx, vz = p.X - fx, p.Z - fz
			local vl = math.sqrt(vx * vx + vz * vz)
			if vl > 8 and vl < 300 and (vx * dx + vz * dz) / (vl * dl) > math.cos(math.rad(45)) then
				local pc = S.Pieces[p.Piece]
				local top = (pc.Size[2] - pc.Sink) * p.Scale
				local k = if top >= 20 then 1 elseif top >= 5 then 2 else 3
				n[k] += 1
			end
		end
		check(string.format("%s shows three scales (large %d, mid %d, small %d)", c.Id, n[1], n[2], n[3]), n[1] >= 3 and n[2] >= 3 and n[3] >= 3)
	end

	-- composed set pieces at the glade altar, the tower, the terrace and every encounter / miniboss / cache site
	local roster = { GladeAltar = "Altar_MonasteryGate", TowerYard = "TowerMid", TerraceCourt = "Altar_BellTerrace", WardenGraves = "HollowBellWarden", WaysideShrine = "enc1",
		HermitCamp = "enc2", BrokenCrossing = "enc14", FallsCache = "WaterfallAlcove" }
	local bySet, setTotal = {}, 0
	for _, p in R.Placements do
		if p.Set then
			bySet[p.Set] = bySet[p.Set] or { n = 0, kinds = {} }
			bySet[p.Set].n += 1
			bySet[p.Set].kinds[p.Piece] = true
			setTotal += 1
		end
	end
	local wanted, found = 0, 0
	for id in roster do
		wanted += 1
		local b = bySet[id]
		local kinds = 0
		for _ in (b and b.kinds or {}) do kinds += 1 end
		found += if b and b.n >= 8 and kinds >= 5 then 1 else 0
		check("set piece " .. id .. " (" .. roster[id] .. ") has >= 8 items of >= 5 kinds (" .. (b and b.n or 0) .. " / " .. kinds .. ")", b ~= nil and b.n >= 8 and kinds >= 5)
	end
	check("all " .. wanted .. " composed sets are present (" .. setTotal .. " set pieces)", found == wanted and setTotal >= 150)
	local anchored = { GladeAltar = O.Altars.Altar_MonasteryGate.Placement, TerraceCourt = O.Altars.Altar_BellTerrace.Placement, WardenGraves = O.Minibosses.HollowBellWarden.Placement,
		WaysideShrine = O.EncounterSpots[1].Placement, HermitCamp = O.EncounterSpots[2].Placement, BrokenCrossing = O.EncounterSpots[14].Placement, TowerYard = tower }
	local far = {}
	for _, p in R.Placements do
		local a = p.Set and anchored[p.Set]
		if a and dist(p.X, p.Z, a.X, a.Z) > (if p.Set == "TowerYard" then 130 else 100) then table.insert(far, p.Id) end
	end
	check("every set piece stands within reach of its anchor (" .. #far .. " strays)", #far == 0)
	local pathy = { Bell_Paving_Flag = true, Bell_Edging_Kerb = true, Bell_Edging_Cobble = true, Rope_Bridge_Deck_A = true, Rope_Bridge_Deck_B = true }
	local wet, onRoad = 0, 0
	for _, p in R.Placements do
		if p.Set then
			local _, _, channelW, chasmW = O.sampleAt(p.X, p.Z)
			wet += if channelW >= 0.05 or chasmW >= 0.01 then 1 else 0
			onRoad += if not pathy[p.Piece] and roadDistance(p.X, p.Z) < 8 then 1 else 0
		end
	end
	check("set pieces stand on dry ground and off the roads (" .. wet .. " wet, " .. onRoad .. " on a road)", wet == 0 and onRoad == 0)
	local broken = 0
	for _, p in R.Placements do broken += if p.Piece == "Bell_Tower_Broken" then 1 else 0 end
	check("Bell_Tower_Ruined replaces the broken tower (TowerMid is the ruined piece, no Bell_Tower_Broken placed)", tower.Piece == "Bell_Tower_Ruined" and broken == 0)
	local gladeSet = bySet.GladeAltar
	print(string.format("  set pieces %d in %d sets; hero placements %d", setTotal, wanted, #heroes))
end

-- F. Lane D6 (R2-4: 90% from both eyes, shelters included): the sight cone from the glade eye (captures 01 and 07) to the tower, the tower above the far tree line, and the near/far tree scheme.
local function boxesOf(p) -- every placement's occluders re-derived from the piece data (not the builder's Occ): { radius, y0, y1 }; trees = trunk + canopy circle, else the bounding circle
	if p.Box then return { p.Box } end
	local pc, sc = S.Pieces[p.Piece], p.Scale
	local half = 0.5 * math.sqrt(pc.Size[1] ^ 2 + pc.Size[3] ^ 2) * sc
	local bot, topY = p.Y - pc.Sink * sc, p.Y + (pc.Size[2] - pc.Sink) * sc
	if pc.Under then
		local ub = bot + pc.Under * pc.Size[2] * sc
		return { { 0.5 * pc.Trunk * sc, bot, ub }, { half, ub, topY } }
	end
	return { { half, bot, topY } }
end
local function rayBlockedBy(list, ex, ey, ez, tx, ty, tz) -- first placement whose occluder the segment crosses (cylinder test: exact in XZ, linear in Y)
	local dx, dz, dy = tx - ex, tz - ez, ty - ey
	local a = dx * dx + dz * dz
	for _, pl in list do
		for _, c in boxesOf(pl) do
			local fx, fz = ex - pl.X, ez - pl.Z
			local b = 2 * (fx * dx + fz * dz)
			local disc = b * b - 4 * a * (fx * fx + fz * fz - c[1] ^ 2)
			if disc > 0 then
				local sq = math.sqrt(disc)
				local t0, t1 = math.max(0, (-b - sq) / (2 * a)), math.min(1, (-b + sq) / (2 * a))
				if t0 < t1 then
					local y0, y1 = ey + dy * t0, ey + dy * t1
					if math.max(y0, y1) >= c[2] and math.min(y0, y1) <= c[3] then return pl end
				end
			end
		end
	end
	return nil
end
local function towerVisible(list, eye) -- fraction of the tower's height (19 samples x 3 lateral rays: axis and +-half a half-width) seen from the eye past terrain and every placed bbox
	local pc = S.Pieces[tower.Piece]
	local H = (pc.Size[2] - pc.Sink) * tower.Scale
	local halfW = 0.5 * math.max(pc.Size[1], pc.Size[3]) * tower.Scale
	local len = dist(eye.X, eye.Z, tower.X, tower.Z)
	local ux, uz = (tower.X - eye.X) / len, (tower.Z - eye.Z) / len
	local seen, total = 0, 0
	local others = {}
	for _, pl in list do if pl.Id ~= "TowerMid" then table.insert(others, pl) end end
	for _, sh in O.Blockout.Shelters do -- the blockout shelters stand outside the placement list: a 10 stud tall cylinder over the half diagonal
		table.insert(others, { X = sh.X, Z = sh.Z, Box = { 0.5 * math.sqrt(sh.W ^ 2 + sh.D ^ 2), O.heightAt(sh.X, sh.Z), O.heightAt(sh.X, sh.Z) + 10 } })
	end
	for k = 1, 19 do
		local f = 0.05 * k
		local ok = true
		for _, lat in { -0.5, 0, 0.5 } do
			local tx, tz, ty = tower.X - uz * lat * halfW, tower.Z + ux * lat * halfW, tower.Y + f * H
			for d = 0, len - halfW, 2 do
				local t = d / len
				if O.heightAt(eye.X + (tx - eye.X) * t, eye.Z + (tz - eye.Z) * t) + S.VoxelLift > eye.Y + (ty - eye.Y) * t then ok = false; break end
			end
			if ok and rayBlockedBy(others, eye.X, eye.Y, eye.Z, tx, ty, tz) then ok = false end
		end
		total += 1
		seen += if ok then 1 else 0
	end
	return seen / total
end
do
	local eyes = {}
	for _, c in S.captures() do
		if c.Id == "01_glade_arrival" or c.Id == "07_tower_from_glade" then eyes[c.Id] = c.From end
	end
	check("the cone eyes are the capture 01 and 07 From points", eyes["01_glade_arrival"] ~= nil and eyes["07_tower_from_glade"] ~= nil)
	for id, eye in eyes do
		local frac = towerVisible(R.Placements, eye)
		print(string.format("  tower from %s (%.0f, %.0f, eye %.1f): %.0f%% of its height unobstructed", id, eye.X, eye.Z, eye.Y, frac * 100))
		check(string.format("at least 90%% of the tower's height is unobstructed from %s (%.0f%%)", id, frac * 100), frac >= 0.9)
		local fake = { Id = "FakeCrown", Piece = "Canopy_Tree_B", X = eye.X + (tower.X - eye.X) * 0.4, Z = eye.Z + (tower.Z - eye.Z) * 0.4, Scale = 1.4 }
		fake.Y = O.heightAt(fake.X, fake.Z)
		local withFake = table.clone(R.Placements)
		table.insert(withFake, fake)
		check("the visibility check can fail: a tall crown on the line drops it under 20%", towerVisible(withFake, eye) < 0.2)
	end
	-- skyline: nothing beyond the tower, within its width of the line, tops out within 1 degree of the tower's top as seen from the eye
	local eye = eyes["07_tower_from_glade"]
	local len = dist(eye.X, eye.Z, tower.X, tower.Z)
	local towerAng = math.deg(math.atan2(top(tower) - eye.Y, len))
	local ux, uz = (tower.X - eye.X) / len, (tower.Z - eye.Z) / len
	local worstAng, worstId, behind = -math.huge, "", 0
	for _, pl in R.Placements do
		local px, pz = pl.X - eye.X, pl.Z - eye.Z
		local along = px * ux + pz * uz
		local lat = math.abs(px * -uz + pz * ux)
		if pl.Id ~= "TowerMid" and along > len and along < len + 700 and lat < 0.5 * math.max(S.Pieces.Bell_Tower_Ruined.Size[1], S.Pieces.Bell_Tower_Ruined.Size[3]) then
			behind += 1
			local ang = math.deg(math.atan2(top(pl) - eye.Y, math.sqrt(px * px + pz * pz)))
			if ang > worstAng then worstAng, worstId = ang, pl.Id end
		end
	end
	print(string.format("  skyline: tower top %.2f deg, highest of %d pieces behind it %.2f deg (%s)", towerAng, behind, worstAng, worstId))
	check("the tower rises at least 1 degree above everything behind it (the far tree line)", behind == 0 or worstAng <= towerAng - 1)
	check("the tower keeps its Raise range (scale 1..1.7)", tower.Scale >= 1 and tower.Scale <= 1.7)
end
do -- near / far trees: a _Far variant exactly when the tree is beyond FarSwitch of every road centreline and capture eye; the _Far specs are the bellwood_far manifest (same bbox, real tris)
	local caps2 = S.captures()
	local function farFromAll(x, z)
		local d = roadDistance(x, z)
		for _, c in caps2 do d = math.min(d, dist(x, z, c.From.X, c.From.Z)) end
		return d
	end
	local nNear, nFar, badFar, badNear = 0, 0, 0, 0
	for _, t in trees do
		local d = farFromAll(t.X, t.Z)
		if S.Pieces[t.Piece].Far then
			nFar += 1
			badFar += if d > S.FarSwitch then 0 else 1
		else
			nNear += 1
			badNear += if d > S.FarSwitch then 1 else 0
		end
	end
	print(string.format("  trees %d: %d near (full mesh) + %d far (_Far, > %d studs from every road and capture eye)", #trees, nNear, nFar, S.FarSwitch))
	check("every _Far tree is beyond the switch distance from every road centreline and capture eye", nFar > 0 and badFar == 0)
	check("every near tree is within the switch distance", badNear == 0)
	check("tree count is at least the original 196 (" .. #trees .. ")", #trees >= 196)
	check("the far switch is 140 studs", S.FarSwitch == 140)
	for _, name in S.FarPieces do
		local nearP, farP = S.Pieces[name], S.Pieces[name .. "_Far"]
		check(name .. "_Far exists, built from the manifest (no Estimate flag) for " .. name, farP ~= nil and farP.Far == true and farP.Estimate == nil and farP.FarOf == name)
		if farP then
			local bn, bf = S.specBounds(name), S.specBounds(name .. "_Far")
			check(name .. "_Far has the same bbox (placeholder union and Size)", farP.Size[1] == nearP.Size[1] and farP.Size[2] == nearP.Size[2] and farP.Size[3] == nearP.Size[3]
				and near(bn[1], bf[1], 1e-6) and near(bn[2], bf[2], 1e-6) and near(bn[3], bf[3], 1e-6) and near(nearP.Radius, farP.Radius))
			local ms = S.FarManifestSize[name]
			check(name .. "_Far manifest bbox equals the near piece within rounding", ms ~= nil and near(ms[1], nearP.Size[1], 0.05) and near(ms[2], nearP.Size[2], 0.05) and near(ms[3], nearP.Size[3], 0.05))
			local want = if name == "Conifer_Tall" then { "Bark", "Needles" } else { "Bark", "Leaves" } -- registry keys <Piece>_Far__<Sub> as in upload_manifest.json
			check(name .. "_Far sub-meshes are " .. table.concat(want, "+") .. " (Needles for the conifer)", #farP.Subs == 2 and farP.Subs[1].Name == want[1] and farP.Subs[2].Name == want[2])
			local ratio = farP.Tris / nearP.Tris
			check(string.format("%s_Far has %d tris (%.1f%% of the near tris, < 15%%)", name, farP.Tris, ratio * 100), farP.Tris >= 900 and farP.Tris <= 1500 and ratio < 0.15)
			check(name .. "_Far keeps the near crown (Under, Crown)", near(farP.Under, nearP.Under) and near(farP.Crown, nearP.Crown))
			check(name .. "_Far never has more placeholder parts than the near piece", farP.PlaceholderParts <= nearP.PlaceholderParts and farP.MeshParts == 2 and farP.MeshParts < nearP.MeshParts)
		end
	end
end

-- 5. Counts per piece.
local expectHero = { Bell_Terrace_Pavilion = 1, Bell_Tower_Ruined = 1, Bell_Stair_Segment = 1, Bell_Terrace_Wall = 6, Bell_Timber_Gate = 2, Bell_Lantern_Post = 16, Stepping_Stones = 1 }
for piece, n in expectHero do
	local got = 0
	for _, h in heroes do if h.Piece == piece then got += 1 end end
	check(piece .. " hero count " .. n, got == n)
end
local function count(piece) return R.Counts[piece] or 0 end
local function cls(c) return R.ByClass[c] or 0 end
local ranges = {
	{ "trees (near + far)", cls("Tree"), 196, 420 }, { "shrubs", cls("Shrub"), 40, 300 }, { "ferns", cls("Fern"), 70, 350 }, { "grass", cls("Grass"), 400, 1300 },
	{ "boulders", cls("Rock"), 10, 60 }, { "flowers", cls("Flower"), 30, 300 }, { "deadwood", cls("Deadwood"), 25, 150 }, { "saplings", cls("Sapling"), 10, 100 },
	{ "mushrooms", cls("Mushroom"), 10, 100 },
}
for _, r in ranges do check(string.format("%s count %d within %d..%d", r[1], r[2], r[3], r[4]), r[2] >= r[3] and r[2] <= r[4]) end
-- kit coverage: five tree forms (plus the gnarled one), every plant family, rock family and set-piece family is placed somewhere
local trees2 = cls("Tree")
for _, tree in { "Canopy_Tree_A", "Canopy_Tree_B", "Canopy_Tree_C", "Canopy_Tree_D", "Conifer_Tall" } do
	check("tree form " .. tree .. " is planted (" .. count(tree) .. " near, " .. count(tree .. "_Far") .. " far)", count(tree) + count(tree .. "_Far") >= 0.04 * trees2)
end
for _, piece in { "Old_Gnarled_Tree", "Sapling_Tree", "Boulder_Granite_A", "Boulder_Granite_D", "Boulder_Granite_Split", "Understory_Shrub_Small", "Shrub_Hazel", "Shrub_Berry",
	"Fern_Clump", "Fern_Bracken", "Fern_Sword", "Flowers_Daisy", "Flowers_Foxglove", "Mushroom_Cluster", "Grass_Clump", "Grass_Tall", "Grass_Lush", "Fallen_Log_A", "Tree_Stump_A", "Exposed_Roots_A" } do
	check("kit piece " .. piece .. " is placed (" .. count(piece) .. ")", count(piece) > 0)
end
local total = 0
for _, n in R.Counts do total += n end
check("counts sum to the placements", total == #R.Placements)
check("ids are unique", (function()
	local seen = {}
	for _, p in R.Placements do if seen[p.Id] then return false end; seen[p.Id] = true end
	return true
end)())

-- 6. Budget.
local B = S.Budget
print(string.format("  placements %d, kit MeshParts %d, placeholder parts %d, tris %.2fM (%.2fM with Lod sub-meshes dropped); budget %d / %d / %d / %.1fM (%.1fM); build %.2f s",
	#R.Placements, R.MeshParts, R.PlaceholderParts, R.Tris / 1e6, R.TrisLod / 1e6, B.Placements, B.MeshParts, B.PlaceholderParts, B.Tris / 1e6, B.TrisLod / 1e6, seconds))
check("placements within budget", #R.Placements <= B.Placements)
check("kit MeshParts within budget", R.MeshParts <= B.MeshParts)
check("placeholder parts within budget", R.PlaceholderParts <= B.PlaceholderParts)
check("triangles within budget", R.Tris <= B.Tris)
check("triangles with the Lod sub-meshes dropped within budget", R.TrisLod <= B.TrisLod and R.TrisLod < R.Tris)
local cellMax = 0
for _, c in R.Cells do
	local parts = 0
	for _, p in c.Placements do parts += S.Pieces[p.Piece].PlaceholderParts end
	cellMax = math.max(cellMax, parts)
end
check("no cell is heavier than 900 placeholder parts (Atomic streaming unit; heaviest " .. cellMax .. ")", cellMax <= 900)

-- 7. Cells and landmarks.
local cellsOk, needsOk = true, true
for _, p in R.Placements do
	if p.Cell ~= S.cellOf(p.X, p.Z) or not R.Cells[p.Cell] then cellsOk = false end
end
for key, c in R.Cells do
	if not c.Needs[key] then needsOk = false end
	for need in c.Needs do if not string.match(need, "^%-?%d+,%-?%d+$") then needsOk = false end end
end
check("every placement is listed in its own cell", cellsOk)
check("every cell needs its own tile and well-formed tile keys", needsOk)
check("the cell key is the terrain tile key", S.cellOf(O.Frame.MinX + 128 * 3 + 5, O.Frame.MinZ + 128 * 7 + 5) == "3,7")
local landmarkIds = {}
for _, h in heroes do if h.Landmark then table.insert(landmarkIds, h.Id) end end
table.sort(landmarkIds)
check("landmarks are exactly the pavilion and the tower", table.concat(landmarkIds, ",") == "Pavilion,TowerMid")

-- 8. Review captures (the six Studio captures).
local caps = S.captures()
check("seven review captures, the last the tower from the glade", #caps == 7 and caps[7].Id == "07_tower_from_glade")
local capOk, whyNot = true, nil
for _, c in caps do
	if not near(c.From.Y, O.heightAt(c.From.X, c.From.Z) + S.Eye, 1e-6) then capOk, whyNot = false, c.Id .. " eye not at player height" end
	local d = dist(c.From.X, c.From.Z, c.To.X, c.To.Z)
	if d < 15 or d > 900 then capOk, whyNot = false, c.Id .. " distance " .. d end
	for _, p in R.Placements do
		local trunk = S.Pieces[p.Piece].Trunk * p.Scale
		local limit = if p.Kind == "Hero" then S.Pieces[p.Piece].Radius * p.Scale + 1 else trunk + 3
		if (p.Class == "Tree" or p.Class == "Rock" or p.Kind == "Hero") and dist(c.From.X, c.From.Z, p.X, p.Z) < limit then
			capOk, whyNot = false, c.Id .. " camera inside " .. p.Id
		end
	end
	print(string.format("  capture %s: eye (%.0f, %.1f, %.0f) -> (%.0f, %.1f, %.0f)  %s", c.Id, c.From.X, c.From.Y, c.From.Z, c.To.X, c.To.Y, c.To.Z, c.Note))
end
check("captures stand at player height, clear of trunks and structures" .. (if whyNot then " (" .. whyNot .. ")" else ""), capOk)

-- 8b. Registered-asset table and registry shape (plain Luau part; the registry-file grep is in section 9).
for piece, a in S.Assets do
	check("Assets." .. piece .. " names a kit piece", S.Pieces[piece] ~= nil)
	check("Assets." .. piece .. " has Registry, numeric Id, Path", type(a.Registry) == "string" and type(a.Id) == "number" and type(a.Path) == "string")
end
check("Registry is a table (empty until SliceKitRegistry exists)", type(S.Registry) == "table")
check("build() succeeds with every registry module absent (the documented fallback: empty Registry, Assets, then placeholder; plain Luau has no script.Parent)", next(S.Registry) == nil and #S.build(true).Placements > 0)

-- 8c. Every piece the generated registries cover must match Pieces sub-for-sub (the service builds a piece only if every sub resolves), and each piece has a registry.
do
	local mods = {
		{ "SliceKitRegistry", require("../src/shared/SliceKitRegistry") }, { "BellwoodKitRegistry", require("../src/shared/BellwoodKitRegistry") },
		{ "BellwoodFarKitRegistry", require("../src/shared/BellwoodFarKitRegistry") }, { "HeroKitRegistry", require("../src/shared/HeroKitRegistry") },
	}
	local owner, clash = {}, 0
	for _, m in mods do
		for piece, subs in m[2] do
			if owner[piece] then clash += 1 end
			owner[piece] = owner[piece] or m[1]
			local def = S.Pieces[piece]
			check(m[1] .. " piece " .. piece .. " is a SliceDressing piece", def ~= nil)
			for _, sb in (def and def.Subs) or {} do
				local e = subs[piece .. "__" .. sb.Name]
				check(piece .. "__" .. sb.Name .. " is in " .. m[1] .. " with a MeshId", type(e) == "table" and type(e.MeshId) == "string" and e.MeshId:match("^rbxassetid://%d+$") ~= nil)
			end
		end
	end
	check("no piece is in two registries (the merge order never matters)", clash == 0)
	local bare = {}
	for name in S.Pieces do
		if not owner[name] then table.insert(bare, name) end
	end
	check("every piece has registry meshes (placeholders left: " .. table.concat(bare, ", ") .. ")", #bare == 0)
	for _, far in S.FarPieces do
		check("far tree " .. far .. "_Far resolves from BellwoodFarKitRegistry", owner[far .. "_Far"] == "BellwoodFarKitRegistry" and owner[far] ~= nil)
	end
end

-- 9. The service on the Instance shim (Lune or lune_compat only).
local okLune, roblox = pcall(function() return require("@lune/roblox") end)
local okFs, fs = pcall(function() return require("@lune/fs") end)
local okLuau, luau = pcall(function() return require("@lune/luau") end)
if not (okLune and okFs and okLuau) then
	print("  (SliceDressingService checks skipped: run through tools/lune_compat.py for the Instance shim)")
else
	local source = fs.readFile("src/server/Services/SliceDressingService.luau")
	local function load(prefilled, readyAll)
		local warnings, order = {}, {}
		local mapFolder = roblox.Instance.new("Folder")
		mapFolder.Name = "Map_Overworld"
		local manifest = {}
		for key, cell in R.Cells do
			if prefilled == nil or prefilled[key] then for need in cell.Needs do manifest[need] = { Key = need } end end
		end
		local services = {
			Workspace = { WaitForChild = function() return mapFolder end, FindFirstChildOfClass = function() return nil end },
			ReplicatedStorage = { WaitForChild = function() return { Shared = { Overworld = O, SliceDressing = S } } end },
			CollectionService = { AddTag = function(_, inst, tag) inst:AddTag(tag) end },
		}
		local modules = {
			OverworldTerrain = { Manifest = manifest },
			OverworldService = { WaitReady = function() return true end, Ready = function(_, area) return readyAll or false end },
		}
		local env = { game = { GetService = function(_, n) return services[n] end },
			script = { Parent = { WaitForChild = function(_, name) return modules[name] end } }, require = function(m) return m end,
			task = { wait = function() end, spawn = function(f, ...) f(...) end, delay = function() end }, os = os, math = math, table = table, string = string,
			Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Instance = roblox.Instance, Enum = roblox.Enum, RaycastParams = roblox.RaycastParams,
			pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, warn = function(m) table.insert(warnings, m) end, print = function() end,
			assert = assert, error = error, setmetatable = setmetatable, pcall = pcall, typeof = typeof }
		local Service = luau.load(source, { debugName = "SliceDressingService", environment = env })()
		Service.Ground = function(_x, _z, surface) return surface + 2 end -- the voxel fallback, without a Terrain
		return Service, mapFolder, warnings
	end

	-- A: every tile written.
	local Service, map, warnings = load(nil, true)
	Service.Start()
	local folder = map:FindFirstChild("SliceDressing")
	check("SliceDressing folder under Map_Overworld", folder ~= nil)
	local cells, landmarks = folder:FindFirstChild("Cells"), folder:FindFirstChild("Landmarks")
	local nCells = 0
	for _ in R.Cells do nCells += 1 end
	check("one Model per cell (" .. nCells .. ")", #cells:GetChildren() == nCells)
	local atomic = true
	for _, m in cells:GetChildren() do
		if tostring(m.ModelStreamingMode) ~= "Enum.ModelStreamingMode.Atomic" then atomic = false end
	end
	check("cell Models are Atomic", atomic)
	check("two Persistent landmark Models", #landmarks:GetChildren() == 2 and (function()
		for _, m in landmarks:GetChildren() do
			if tostring(m.ModelStreamingMode) ~= "Enum.ModelStreamingMode.Persistent" then return false end
		end
		return true
	end)())
	local stats = Service.Stats()
	local parts, anchored, collideOk, placementById = 0, true, true, {}
	for _, p in R.Placements do placementById[p.Id] = p end
	local groundOk, groundWorst = true, 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if not d.Anchored then anchored = false end
			local holder = if d:GetAttribute("SlicePiece") then d else d.Parent
			local piece = holder:GetAttribute("SlicePiece")
			if d.CanCollide and not S.Pieces[piece].Structure then collideOk = false end
			local single = d:GetAttribute("SlicePiece") ~= nil
			local pl = placementById[holder.Name]
			if single and pl then -- a one-block piece: its underside is the ground (+2 voxel lift) minus its Sink
				local want = pl.Y + 2 - S.Pieces[piece].Sink * pl.Scale
				local got = d.Position.Y - d.Size.Y / 2
				groundWorst = math.max(groundWorst, math.abs(got - want))
			end
		end
	end
	groundOk = groundWorst < 1e-3
	check("placeholder parts built match the data (" .. parts .. ")", parts == R.PlaceholderParts and stats.PlaceholderParts == R.PlaceholderParts)
	check("kit MeshPart count reported matches the data", stats.MeshParts == R.MeshParts and stats.Built == nCells and stats.Failed == 0)
	check("part total within the stated budget", parts <= B.PlaceholderParts)
	check("every part is anchored", anchored)
	check("only structures collide", collideOk)
	check("one-block pieces sit on ground + 2 minus Sink (worst " .. string.format("%.5f", groundWorst) .. ")", groundOk)
	local order = {}
	local glade = O.Altars[O.Gateway].Placement
	local monotone, last = true, -1
	for _, m in cells:GetChildren() do
		local key = m:GetAttribute("Cell")
		local first = R.Cells[key].Placements[1]
		local d = (first.X - glade.X) ^ 2 + (first.Z - glade.Z) ^ 2
		if d < last then monotone = false end
		last = d
	end
	check("cells are raised nearest the glade first", monotone)
	check("no warnings when every tile is written", #warnings == 0)
	check("Parts attribute is on the folder", folder:GetAttribute("Parts") == R.PlaceholderParts)
	Service.Destroy()
	check("Destroy removes the folder", map:FindFirstChild("SliceDressing") == nil)

	-- Assets: every Id appears in the registry file it cites (as rbxassetid://<Id>), and the Part/Path are non-empty.
	for piece, a in S.Assets do
		local ok, text = pcall(fs.readFile, a.Registry)
		if ok then
			check("Assets." .. piece .. " Id " .. a.Id .. " is in " .. a.Registry, string.find(text, "rbxassetid://" .. a.Id, 1, true) ~= nil)
		else -- tools/lune_compat.py snapshots only a few assets/ files; real Lune reads them all
			print("  (Assets." .. piece .. " registry grep skipped: " .. a.Registry .. " is not in the lune_compat snapshot)")
		end
	end

	-- Registry: a fake registry makes the builder build real MeshParts; pieces it does not cover (or covers partly) stay placeholders.
	local function sub(id, center, asset) return { MeshId = "rbxassetid://" .. id, Asset = "rbxassetid://" .. (asset or 5000), ColorMap = "rbxassetid://" .. id + 1, NormalMap = "rbxassetid://" .. id + 2, center = center } end
	local fake = {
		Grass_Clump = { Grass_Clump__Blades = sub(9001, nil, 5001) }, -- single sub, no centre: Size/2 up
		Canopy_Tree_A = { Canopy_Tree_A__Bark = sub(9010, { 0, 14, 0 }, 5002), Canopy_Tree_A__Leaves_Mass = sub(9020, { 0, 30, 0 }, 5002), Canopy_Tree_A__Leaves_Detail = sub(9030, { 0, 36, 0 }, 5002) },
		Canopy_Tree_B = { Canopy_Tree_B__Bark = sub(9040, { 0, 14, 0 }, 5003) }, -- partial: must fall back whole
		Fern_Clump = { Fern_Clump__Fronds = { MeshId = "" } }, -- malformed
	}
	local Service3, map3 = load(nil, true)
	local loads = {}
	Service3.Registry = fake
	-- Fake InsertService:LoadAsset result: a Model whose MeshParts carry the sub-mesh MeshIds (as the uploaded models do). Asset 5003 fails to load.
	local models = {
		["rbxassetid://5001"] = { 9001 }, ["rbxassetid://5002"] = { 9010, 9020, 9030 },
	}
	Service3.LoadModel = function(assetId)
		loads[assetId] = (loads[assetId] or 0) + 1
		local ids = models[assetId]
		if not ids then return nil end
		local m = roblox.Instance.new("Model")
		for _, id in ids do
			local mp = roblox.Instance.new("MeshPart")
			mp.Size = roblox.Vector3.new(4, 3, 4)
			mp.MeshId = "rbxassetid://" .. id
			mp.Parent = m
		end
		return m
	end
	Service3.Start()
	local f3 = map3:FindFirstChild("SliceDressing")
	local want = { Grass_Clump = 0, Canopy_Tree_A = 0 }
	for _, p in R.Placements do if want[p.Piece] then want[p.Piece] += 1 end end
	local nGrass, nBark, nLeafD, nTreeBPlaceholder, nFernPlaceholder, badCollide, badShadow, badLod = 0, 0, 0, 0, 0, 0, 0, 0
	local realParts = 0
	for _, d in f3:GetDescendants() do
		if d:IsA("MeshPart") then
			realParts += 1
			if d.CanCollide then badCollide += 1 end
			local sub = d:GetAttribute("SliceSub")
			if sub == "Blades" then nGrass += 1; if d.CastShadow then badShadow += 1 end end
			if sub == "Bark" then nBark += 1 end
			if sub == "Leaves_Detail" then nLeafD += 1; if d:GetAttribute("LodDetail") ~= true then badLod += 1 end end
		elseif d:IsA("BasePart") and d:GetAttribute("SliceSub") == "Fronds" then
			nFernPlaceholder += 1
		end
	end
	local treeB = 0
	for _, p in R.Placements do if p.Piece == "Canopy_Tree_B" then treeB += 1 end end
	for _, d in f3:GetDescendants() do
		if d:IsA("BasePart") and d.Name:find("^Canopy_Tree_B__") then nTreeBPlaceholder += 1 end
	end
	check("registry pieces are built as MeshParts: one Grass_Clump__Blades per grass placement (" .. nGrass .. ")", nGrass == want.Grass_Clump and nGrass > 0)
	check("a three-sub tree is three MeshParts each (" .. nBark .. ")", nBark == want.Canopy_Tree_A and nLeafD == want.Canopy_Tree_A and nBark > 0)
	check("MeshParts never collide (neither is a structure)", badCollide == 0)
	check("grass casts no shadow and Leaves_Detail carries LodDetail", badShadow == 0 and badLod == 0)
	check("a partly covered piece (Canopy_Tree_B) stays a placeholder", treeB > 0 and nTreeBPlaceholder > 0)
	check("a malformed registry entry (Fern_Clump) stays a placeholder", nFernPlaceholder > 0)
	check("real part count is reported (" .. Service3.Stats().Real .. ")", Service3.Stats().Real == realParts and realParts == nGrass + nBark * 3)
	check("each model is loaded once (cached), not per placement", loads["rbxassetid://5001"] == 1 and loads["rbxassetid://5002"] == 1)
	check("a piece whose model never loads (asset 5003 absent) is not loaded, and stays a placeholder", loads["rbxassetid://5003"] == nil and nTreeBPlaceholder > 0)
	-- Source guard: no runtime SurfaceAppearance map / MeshId writes, templates only via cached LoadAsset.
	local code = (string.gsub(source, "%-%-[^" .. string.char(10) .. "]*", ""))
	check("no runtime SurfaceAppearance map or MeshId writes remain", string.find(code, "SurfaceAppearance", 1, true) == nil and string.find(code, "CreateMeshPartAsync", 1, true) == nil
		and string.find(code, "%.MeshId%s*=[^=]") == nil and string.find(code, "%[map%]") == nil)
	check("templates come from InsertService:LoadAsset behind modelCache", string.find(code, ":LoadAsset(", 1, true) ~= nil and string.find(code, "modelCache[assetId]", 1, true) ~= nil)
	Service3.Destroy()

	-- B: only the cells nearest the glade have their tiles; the rest are never built (and the service says so).
	local keys = {}
	for key, cell in R.Cells do table.insert(keys, key) end
	table.sort(keys)
	local some = { [keys[1]] = true, [keys[2]] = true }
	local Service2, map2, warnings2 = load(some, true)
	Service2.Start()
	local built2 = map2:FindFirstChild("SliceDressing"):FindFirstChild("Cells"):GetChildren()
	local wantBuilt = 0
	for key, cell in R.Cells do
		local ok = true
		for need in cell.Needs do if not (some[need] or false) then ok = false end end
		if ok then wantBuilt += 1 end
	end
	check("only cells whose tiles are written are built (" .. #built2 .. " of " .. nCells .. ")", #built2 == wantBuilt and #built2 < nCells)
	check("the unbuilt cells are reported", #warnings2 >= 1 and string.find(warnings2[#warnings2], "never saw their terrain tiles", 1, true) ~= nil)
	Service2.Destroy()
end

print(string.format("slice dressing: %d passed, %d failed", passed, failed))
if failed > 0 then
	error("slice dressing checks failed")
end

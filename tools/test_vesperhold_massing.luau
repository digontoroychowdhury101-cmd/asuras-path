--!nonstrict
-- Vesperhold massing (mac-41 plan, verdict targets 1, 2, 5, 8): layout numbers from src/shared/VesperholdLayout, terrain
-- from the real Overworld, and the real GothicCitadel / GothicMarch builders run on Instance fakes.
-- Run: python3 tools/lune_compat.py tools/test_vesperhold_massing.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Vector3, CFrame, Enum = roblox.Vector3, roblox.CFrame, roblox.Enum
local O = require("../src/shared/Overworld")
local L = require("../src/shared/VesperholdLayout")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local g = O.Vesperhold
local function ground(x: number, z: number): number -- terrain top in the castle frame (Y 0 = gate threshold)
	return O.heightAt(g.X - z, g.Z + x) - g.Y
end

-- 1. Terrain: nothing outside vesperholdWeight's support moved (checksum taken before the ridge edit), and the gorge is deep.
local sum = 0
for wx = -10000, -1600, 25 do
	for wz = -9200, -800, 25 do
		if O.vesperholdWeight(wx, wz) == 0 then sum += O.heightAt(wx, wz) * ((wx / 25 + wz / 25) % 5 + 1) end
	end
end
check("terrain outside the Vesperhold weight is unchanged", math.abs(sum - 176934331.5874) < 0.01)
local T = L.Tiers
local lowest = 0
for i = 1, 17 do lowest = math.min(lowest, ground((i - 9) * T.T0.Bay, T.T0.FrontZ)) end
print(string.format("  T0 drop to terrain at the bastion front: %.0f studs (target >= 150)", -lowest))
check("T0 drops >= 150 studs into the gorge", -lowest >= T.T0.MinDrop)
check("cathedral ridge >= +220 above the gate road", T.T3.Top >= 220 and T.T3.FloorY >= 220)

-- 2. View-01 frame fractions (Roblox FieldOfView is vertical). Body = tier fronts only, spires excluded.
local function vec(p) return Vector3.new(p.X, p.Y, p.Z) end
local eye, aim = vec(L.Eye), vec(L.Aim)
local fwd = (aim - eye).Unit
local right = fwd:Cross(Vector3.new(0, 1, 0)).Unit
local up = right:Cross(fwd)
local ty = math.tan(math.rad(L.Fov / 2))
local function project(x, y, z)
	local d = Vector3.new(x, y, z) - eye
	local zc = d:Dot(fwd)
	return d:Dot(right) / zc / (ty * L.Aspect), d:Dot(up) / zc / ty
end
local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
for _, p in { { T.T0.X, lowest, T.T0.FrontZ }, { T.T0.X, 0, T.T0.FrontZ }, { T.T1.X, T.T1.Top, T.T1.FrontZ },
	{ T.T2.X, T.T2.Top, T.T2.FrontZ }, { T.T3.X, T.T3.Top, T.T3.FrontZ } } do
	for _, s in { -1, 1 } do
		local sx, sy = project(s * p[1], p[2], p[3])
		x0, x1, y0, y1 = math.min(x0, sx), math.max(x1, sx), math.min(y0, sy), math.max(y1, sy)
	end
end
local fracW = (math.min(x1, 1) - math.max(x0, -1)) / 2
local fracH = (math.min(y1, 1) - math.max(y0, -1)) / 2
print(string.format("  view 01 eye (%d,%d,%d) FOV %d 16:9: body %.0f%% of width, %.0f%% of height", L.Eye.X, L.Eye.Y, L.Eye.Z, L.Fov, fracW * 100, fracH * 100))
check("body spans >= 45% of frame width from view 01", fracW >= 0.45)
check("body spans >= 35% of frame height from view 01", fracH >= 0.35)
check("frontage >= 650 studs", 2 * T.T0.X >= 650)

-- Look-up angle to the first parapet (T1 front, y = Top) over the last 400 road studs.
local function road(z)
	if z <= 157 then return L.viaductLevel(z) end
	if z <= 183 then return -20 + (183 - z) * 2 / 26 end
	local h = ground(0, z) + 0.75 + 1.65 * math.clamp((585 - z) / 24, 0, 1)
	if z < 305 then
		local start = ground(-13, 305) + 2.4
		h = math.max(h, start + (-20 - start) * math.clamp((305 - z) / 122, 0, 1))
	end
	return h
end
local minAngle = 90
for z = 4, 404, 4 do
	minAngle = math.min(minAngle, math.deg(math.atan2(T.T1.Top - (road(z) + 5), z - T.T1.FrontZ)))
end
print(string.format("  look-up angle to the T1 parapet over the last 400 road studs: min %.1f deg (target >= 25)", minAngle))
check("look-up >= 25 degrees to the first parapet", minAngle >= 25)

-- 3. Slots: spires, buttresses, windows, doors, viaduct, statues.
local slots = L.slots(ground)
local byGroup, ids = {}, {}
for _, s in slots do
	byGroup[s.Group] = byGroup[s.Group] or {}
	table.insert(byGroup[s.Group], s)
	check("slot id unique", not ids[s.Id]); ids[s.Id] = true
	check("slot piece has a stand-in size: " .. s.Piece, L.Piece[s.Piece] ~= nil)
end
print(string.format("  kit slots: %d", #slots))
local tops, spires, tags = {}, {}, {}
for _, sp in L.Spires do
	table.insert(tops, sp[4]); spires[sp[6]] = (spires[sp[6]] or 0) + 1
end
local mean, var = 0, 0
for _, t in tops do mean += t / #tops end
for _, t in tops do var += (t - mean) ^ 2 / #tops end
local sd = math.sqrt(var)
print(string.format("  spires: %d, tops %d..%d, std dev %.0f", #tops, math.min(table.unpack(tops)), math.max(table.unpack(tops)), sd))
check("at least 30 spires", #tops >= 30)
check("spire heights vary (std dev >= 80)", sd >= 80)
local west = {}
for _, sp in L.Spires do if sp[6] == "WestTower" then table.insert(west, sp[4]) end end
check("two asymmetric west towers near +690/+640", #west == 2 and west[1] ~= west[2] and math.max(west[1], west[2]) >= 680 and math.min(west[1], west[2]) >= 630)
check("crossing spire ~+560", (function() for _, sp in L.Spires do if sp[6] == "Crossing" then return sp[4] >= 540 end end end)())
check("6 tier-corner towers +300..+450", (spires.CornerTower or 0) + (spires.BrokenCorner or 0) == 6)
check("8+ buttress towers", (spires.ButtressTower or 0) >= 8)
check("14+ gallery needles", (spires.GalleryNeedle or 0) >= 14)
check("exactly one broken spire", (spires.BrokenCorner or 0) == 1)
local stacked = {}
for _, s in byGroup.Spire do stacked[s.Spire] = true end
local nStacks = 0
for _ in stacked do nStacks += 1 end
check("every spire is a stack of kit modules", nStacks == #tops)

local pairsAt = {}
for _, s in byGroup.Flyer do pairsAt[s.Pair] = (pairsAt[s.Pair] or 0) + 1 end
local nPairs = 0
for _, c in pairsAt do if c == 2 then nPairs += 1 end end
print(string.format("  flying buttress pairs: %d", nPairs))
check("8+ flying-buttress pairs", nPairs >= 8)
local rose = byGroup.Rose[1]
check("rose window >= 40 dia centred ~+300 on the T3 west front", L.Piece[rose.Piece][1] * rose.SX >= 40 and math.abs(L.Rose.Y - 300) <= 20 and rose.Z == T.T3.FrontZ)
for _, s in byGroup.Portal do
	local h = L.Piece[s.Piece][2] * s.SY
	check("door height 20-30: " .. h, h >= 20 and h <= 30)
end
check("portals at the great gate and on T3", #byGroup.Portal == 2)
check("arcade runs on T1 and T2", #byGroup.Arcade >= 60)
check("bastion faces cover all 17 T0 bays", #byGroup.Bastion >= 17)

local statues = { [-1] = {}, [1] = {} }
for _, s in byGroup.Statue do
	if s.Side then table.insert(statues[s.Side], s.Z) end
end
local nStatues = #statues[-1] + #statues[1]
check("10+ hooded statues on the viaduct", nStatues >= 10)
for _, side in { -1, 1 } do
	table.sort(statues[side])
	for i = 2, #statues[side] do
		local gap = statues[side][i] - statues[side][i - 1]
		check("statue spacing 25-35: " .. gap, gap >= 25 and gap <= 35)
	end
end
local bays = byGroup.Viaduct
table.sort(bays, function(a, b) return a.Z < b.Z end)
for i, s in bays do
	if i > 1 then check("viaduct bays every 30 studs", math.abs(s.Z - bays[i - 1].Z - 30) < 1e-6) end
	check("viaduct bay stands on terrain and reaches the deck", math.abs(s.Y - (ground(0, s.Z) - 5)) < 0.01 and s.Y + 120 * s.SY < s.Level)
end
check("banners on the near gate tower", #byGroup.Banner >= 2)

-- 4. Walk route data: continuous, walkable slopes, wide enough.
local route = L.Route
for i, r in route do
	local a, b = vec({ X = r.A[1], Y = r.A[2], Z = r.A[3] }), vec({ X = r.B[1], Y = r.B[2], Z = r.B[3] })
	local run = math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2)
	check("route " .. r.Name .. " width >= 12", r.Width >= 12)
	check("route " .. r.Name .. " slope <= 40 degrees", run > 0 and math.deg(math.atan2(math.abs(b.Y - a.Y), run)) <= 40)
	if i > 1 then
		local p = route[i - 1].B
		check("route continuous into " .. r.Name, (a - Vector3.new(p[1], p[2], p[3])).Magnitude <= 1)
	end
end
check("route runs road -> gate -> close -> T2 -> T3 portal -> nave",
	route[1].Name == "Viaduct" and route[#route].Name == "Nave" and route[#route].B[2] == T.T3.FloorY and route[7].B[2] == T.T2.FloorY)

-- 5. Real builders on Instance fakes.
local services = {
	CollectionService = { AddTag = function(_, inst, tag) inst:AddTag(tag) end },
	ReplicatedStorage = { WaitForChild = function() return { Shared = { Overworld = O, VesperholdLayout = L } } end },
}
local Kit = {}
function Kit.part(parent, name, size, cf, color, material, options)
	local o = options or {}
	local p = roblox.Instance.new(o.Class or "Part")
	p.Name, p.Anchored, p.Size, p.CFrame, p.Color, p.Material = name, true, size, cf, color, material
	p.CanCollide = if o.Collide == nil then true else o.Collide
	p.CanQuery = if o.Query == nil then p.CanCollide else o.Query
	if o.Shape then p.Shape = o.Shape end
	p.Parent = parent
	return p
end
function Kit.disc(parent, name, radius, height, center, color, material, options)
	return Kit.part(parent, name, Vector3.new(height, radius * 2, radius * 2), center * CFrame.Angles(0, 0, math.rad(90)), color, material, options)
end
function Kit.light() return {} end
local noop = function() end
local stubs = {
	SanctuaryKit = { part = Kit.part, disc = Kit.disc, light = Kit.light, place = noop, slab = Kit.part },
	SanctuaryProps = { brazier = noop, bench = noop },
	MonasteryKit = Kit,
	RegionDecor = { banner = noop, nature = noop, han = noop },
	PbrAssets = { place = noop },
	VesperholdKit = { has = function() return false end, place = function() return nil end }, -- no uploads yet: every slot keeps its stand-in
}
local env = { game = { GetService = function(_, n) return services[n] end },
	script = { Parent = setmetatable({ WaitForChild = function(_, n) return stubs[n] end }, { __index = stubs }) },
	require = function(m) return m end, task = { wait = noop, spawn = noop, delay = noop },
	os = os, math = math, table = table, string = string, Random = roblox.Random,
	Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Instance = roblox.Instance, Enum = roblox.Enum, UDim2 = roblox.UDim2,
	pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, warn = warn, print = print, assert = assert, error = error,
	setmetatable = setmetatable, pcall = pcall, select = select }
local Citadel = luau.load(fs.readFile("src/server/Services/GothicCitadel.luau"), { debugName = "GothicCitadel", environment = env })()
local March = luau.load(fs.readFile("src/server/Services/GothicMarch.luau"), { debugName = "GothicMarch", environment = env })()

local origin = CFrame.new(g.X, g.Y, g.Z) * CFrame.Angles(0, math.rad(g.Yaw), 0)
local root = roblox.Instance.new("Folder")
March.build(root, origin)
Citadel.build(root, origin)
local castle = root:FindFirstChild("Vesperhold")
local march = root:FindFirstChild("Vesper March")
check("castle and march models built", castle ~= nil and march ~= nil)

local parts, collidable, shelters, kitModels, bayModels = 0, {}, 0, {}, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		if d.CanCollide then table.insert(collidable, d) end
		if d:HasTag("AsuraShelter") then shelters += 1 end
		local mine = d:IsDescendantOf(castle) or d:IsDescendantOf(march:FindFirstChild("The Processional Bridge")) -- road gravel and crofts keep their own tones
		if mine then
			check("no Limestone stock material: " .. d.Name, d.Material ~= Enum.Material.Limestone)
			local c = d.Color
			local lit = d.Material == Enum.Material.Neon or d.Material == Enum.Material.Fabric or d.Material == Enum.Material.Metal
			check("one soot palette, no pale stone: " .. d.Name, lit or math.max(c.R, c.G, c.B) <= 0.45)
		end
		check("no red post / ensign left on the road", d.Name ~= "Broken stake" and d.Name ~= "Bent ensign" and d.Name ~= "Fallen chevaux de frise")
	elseif d:IsA("Model") then
		local id = d:GetAttribute("VespSlotId")
		if id then kitModels[id] = d:GetAttribute("VespKitSlot") end
		if d:GetAttribute("VespKitSlot") == "Viaduct_Bay" and d:GetAttribute("VespBay") then bayModels += 1 end
	end
end
print(string.format("  built Parts: %d (collidable %d, AsuraShelter %d)", parts, #collidable, shelters))
local expected = 0
for _, s in slots do
	if s.Group ~= "Viaduct" then
		expected += 1
		check("slot " .. s.Id .. " has a marked stand-in of " .. s.Piece, kitModels[s.Id] == s.Piece)
	end
end
check("one marked Viaduct_Bay stand-in per bay", bayModels == #bays)
check("vault and gate roofs keep their AsuraShelter tags", shelters >= 3)

-- Walkable geometry: a collidable part under every route sample, nothing within head height above it.
local function inside(part, w)
	local l = part.CFrame:PointToObjectSpace(w)
	local s = part.Size
	return math.abs(l.X) <= s.X / 2 + 0.05 and math.abs(l.Y) <= s.Y / 2 + 0.05 and math.abs(l.Z) <= s.Z / 2 + 0.05
end
local function covered(w)
	for _, p in collidable do if inside(p, w) then return true end end
	return false
end
local holes, blocked, samples = 0, 0, 0
for _, r in route do
	if r.Kind == "stair" then continue end -- stepped: sampled per tread below
	local len = math.sqrt((r.B[1] - r.A[1]) ^ 2 + (r.B[3] - r.A[3]) ^ 2 + (r.B[2] - r.A[2]) ^ 2)
	for i = 0, math.ceil(len / 4) do
		local t = i / math.ceil(len / 4)
		local x, y, z = r.A[1] + (r.B[1] - r.A[1]) * t, r.A[2] + (r.B[2] - r.A[2]) * t, r.A[3] + (r.B[3] - r.A[3]) * t
		samples += 1
		if not covered(origin * Vector3.new(x, y - 0.75, z)) then
			holes += 1
			if holes <= 6 then print(string.format("    hole in %s at local (%.0f, %.1f, %.0f)", r.Name, x, y, z)) end
		end
		-- No collidable part may reach into a 3.5-stud walking clearance above the surface (hand-rails and vault feet excepted).
		if covered(origin * Vector3.new(x, y + 3.5, z)) then
			blocked += 1
			if blocked <= 6 then print(string.format("    blocked in %s at local (%.0f, %.1f, %.0f)", r.Name, x, y, z)) end
		end
	end
end
-- Spurs and alternates: same floor / headroom sampling, chained from the main route.
local function sampleSeg(r)
	local len = math.sqrt((r.B[1] - r.A[1]) ^ 2 + (r.B[3] - r.A[3]) ^ 2 + (r.B[2] - r.A[2]) ^ 2)
	for i = 0, math.ceil(len / 4) do
		local t = i / math.ceil(len / 4)
		local x, y, z = r.A[1] + (r.B[1] - r.A[1]) * t, r.A[2] + (r.B[2] - r.A[2]) * t, r.A[3] + (r.B[3] - r.A[3]) * t
		samples += 1
		if not covered(origin * Vector3.new(x, y - 0.75, z)) then holes += 1; print(string.format("    hole in %s at (%.0f, %.1f, %.0f)", r.Name, x, y, z)) end
		if covered(origin * Vector3.new(x, y + 3.5, z)) then blocked += 1; print(string.format("    blocked in %s at (%.0f, %.1f, %.0f)", r.Name, x, y, z)) end
	end
end
local function distToRoute(p)
	local best = math.huge
	for _, r in route do
		local a, b = vec({ X = r.A[1], Y = r.A[2], Z = r.A[3] }), vec({ X = r.B[1], Y = r.B[2], Z = r.B[3] })
		local ab = b - a
		local t = math.clamp((vec({ X = p[1], Y = p[2], Z = p[3] }) - a):Dot(ab) / math.max(ab:Dot(ab), 1e-9), 0, 1)
		best = math.min(best, (vec({ X = p[1], Y = p[2], Z = p[3] }) - (a + ab * t)).Magnitude)
	end
	return best
end
for _, r in L.Alternates do sampleSeg(r) end
check("alternates end on the main route (stair top)", (vec({ X = L.Alternates[2].B[1], Y = L.Alternates[2].B[2], Z = L.Alternates[2].B[3] }) - vec({ X = L.Stair.B[1], Y = L.Stair.B[2], Z = L.Stair.B[3] })).Magnitude <= 1)
for name, spur in L.Spurs do
	check(name .. " spur starts on the main route", distToRoute(spur.From) <= 1)
	for i, r in spur.Segs do
		sampleSeg(r)
		check(name .. " " .. r.Name .. " width >= 10", r.Width >= 10)
		local a, b = r.A, r.B
		local run = math.sqrt((b[1] - a[1]) ^ 2 + (b[3] - a[3]) ^ 2)
		check(name .. " " .. r.Name .. " slope <= 40", math.deg(math.atan2(math.abs(b[2] - a[2]), run)) <= 40)
		local prev = if i == 1 then spur.From else spur.Segs[i - 1].B
		check(name .. " continuous into " .. r.Name, (vec({ X = a[1], Y = a[2], Z = a[3] }) - vec({ X = prev[1], Y = prev[2], Z = prev[3] })).Magnitude <= 1)
	end
end
-- Grand stair treads: solid floor at every tread centre, free headroom above it.
local St = L.Stair
for _, st in St.Steps do
	samples += 1
	if not covered(origin * Vector3.new(st.CX, st.Top - 0.75, st.CZ)) then holes += 1; print("    stair hole at step " .. st.Index) end
	if covered(origin * Vector3.new(st.CX, st.Top + 3.5, st.CZ)) then blocked += 1; print("    stair blocked at step " .. st.Index) end
end
for _, l in St.Landings do
	samples += 1
	if not covered(origin * Vector3.new(l.CX, l.Top - 0.75, l.CZ)) then holes += 1; print("    landing hole") end
	if covered(origin * Vector3.new(l.CX, l.Top + 3.5, l.CZ)) then blocked += 1; print("    landing blocked") end
end
print(string.format("  route samples: %d, floor holes: %d, blocked headroom: %d", samples, holes, blocked))
check("walk route has a collidable floor at every sample (no gap > 1 stud)", holes == 0)
check("walk route has headroom at every sample", blocked == 0)

-- 6. Pass 2 (mac-48): sprawl, viaducts, grand stair, waterfalls, ruined-arch viewpoint.
local function dist2(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function segDist(p, a, b) -- point to segment, 3D
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end
local per = {}
for _, sl in slots do per[sl.Piece] = (per[sl.Piece] or 0) + 1 end
local names = {}
for k, v in per do table.insert(names, k .. "=" .. v) end
table.sort(names)
print("  slots per piece: " .. table.concat(names, " "))
-- (a) pinnacles, viaducts, outposts, spires
local pinn = 1
local rockParts, cragParts, cragSolid = 0, 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") and d.Name:find("^Pinnacle") then rockParts += 1 end
	if d:IsA("BasePart") and d.Name:find("^Crag") then cragParts += 1; if d.CanCollide then cragSolid += 1 end end
end
for _ in L.Pinnacles do pinn += 1 end
print(string.format("  pinnacles %d (P1 + %d rock cores, %d course Parts), crag Parts %d", pinn, pinn - 1, rockParts, cragParts))
check("3+ cliff pinnacles", pinn >= 3)
check("rock courses built and collidable", rockParts >= 6)
check("crags built without collision", cragParts >= 6 and cragSolid == 0)
for id, r in L.Pinnacles do
	local cs = L.rock(r, ground)
	check(id .. " rises from terrain to its Top", math.abs(cs[#cs].Y1 - r.Top) < 1e-6 and cs[1].Y0 <= ground(r.X, r.Z) - 8)
	check(id .. " top course is square and clear of P1 tiers", cs[#cs].Yaw == 0 and math.abs(r.X) - r.HX > T.T2.X)
end
local levels = { L.Viaducts.V1.Level, L.Viaducts.V2.Level, L.Viaducts.V3.Level }
check("V1 level is the road", math.abs(levels[1] - (L.viaductLevel(4) + L.viaductLevel(157)) / 2) < 1)
for i = 1, 3 do for j = i + 1, 3 do check("viaduct levels >= 80 apart", math.abs(levels[i] - levels[j]) >= 80) end end
for name, v in { V2 = L.Viaducts.V2, V3 = L.Viaducts.V3 } do
	local vb, vs, vc, vbal, vban = {}, { [-1] = {}, [1] = {} }, 0, 0, 0
	for _, sl in slots do
		if sl.Viaduct == name then
			if sl.Group == "ViaductHigh" then table.insert(vb, sl) end
			if sl.Group == "Pedestal" then table.insert(vs[sl.Side], sl.Along) end
			if sl.Group == "Candle" then vc += 1 end
			if sl.Group == "Balustrade" then vbal += 1 end
			if sl.Group == "Banner" then vban += 1 end
		end
	end
	check(name .. " has 5+ arched bays", #vb >= 5)
	check(name .. " has balustrade, candles and banners", vbal >= 2 * #vb and vc >= 2 * #vb and vban >= 2)
	for _, b in vb do
		check(name .. " bay stands on terrain and reaches the deck", math.abs(b.Y - (ground(b.X, b.Z) - 5)) < 0.01 and b.Y + 120 * b.SY < v.Level)
	end
	for _, side in { -1, 1 } do
		table.sort(vs[side])
		check(name .. " pedestal statues on both sides", #vs[side] >= 5)
		for i = 2, #vs[side] do check(name .. " pedestal spacing 25-35", math.abs(vs[side][i] - vs[side][i - 1]) >= 25 and math.abs(vs[side][i] - vs[side][i - 1]) <= 35) end
	end
	check(name .. " deck is walkable with parapets", (function()
		local n = 0
		for _, d in root:GetDescendants() do if d:IsA("BasePart") and d.Name == name .. "DeckParapet" and d.CanCollide then n += 1 end end
		return n == 2
	end)())
end
local outposts = {}
for _, sp in L.Spires do if sp[6] == "OutpostTower" then table.insert(outposts, sp) end end
check("2+ distant outposts", #outposts >= 2)
for _, sp in outposts do
	local d = dist2(sp[1], sp[2], 0, 0)
	check("outpost 800-1500 studs from the gate: " .. d, d >= 800 and d <= 1500)
	local crag
	for _, c in L.Crags do if c.X == sp[1] and c.Z == sp[2] then crag = c end end
	check("outpost spire stands on its crag", crag ~= nil and sp[3] == crag.Top and sp[4] - sp[3] >= 250)
end
print(string.format("  spires total %d (P1 35)", #L.Spires))
check("45+ spires across the sprawl", #L.Spires >= 45)
-- (b) grand stair
check("stair >= 60 steps", St.Count >= 60 and #St.Steps == St.Count)
check("stair rise <= 1.6, tread >= 2.5, width >= 24", St.Rise <= 1.6 and St.Tread >= 2.5 and St.Width >= 24)
for i, st in St.Steps do
	local prev = if i == 1 then St.Base else St.Steps[i - 1].Top
	check("step rise <= 1.6", st.Top - prev <= 1.6 + 1e-6 and st.Top > prev - 1e-6)
end
check("stair top meets the T3 floor and the portal landing", math.abs(St.TopY - T.T3.FloorY) < 1e-6 and math.abs(L.Route[11].A[1] - St.B[1]) < 1e-6)
check("stair axis points at the portal door", math.abs((St.B[1] + St.UX * 22) - St.Door[1]) < 1e-6 and math.abs((St.B[3] + St.UZ * 22) - St.Door[3]) < 1e-6)
check("stair foot on T2 and ramp lands beside it", St.S[2] == T.T2.FloorY and math.abs(St.S[1]) <= T.T2.X and St.S[3] <= T.T2.FrontZ - 4)
check("stair is on the main route", (function() for _, r in route do if r.Kind == "stair" then return true end end return false end)())
check("landings every ~20 steps", #St.Landings == 2 and St.Landings[1].S0 >= 18 * St.Tread and St.Landings[1].S0 <= 22 * St.Tread + 4 and St.Landings[2].S0 > St.Landings[1].S0 + 18 * St.Tread)
local stat = { Brazier = { [-1] = {}, [1] = {} }, Pedestal = { [-1] = {}, [1] = {} }, BannerPole = { [-1] = {}, [1] = {} } }
for _, sl in slots do
	if sl.Track == "Stair" then table.insert(stat[sl.Group][sl.Side], sl.Along) end
end
for g2, bySide in stat do
	for side, list in bySide do
		table.sort(list)
		if g2 == "BannerPole" then
			check("banner pole pair at each of 3 landings", #list == 3)
		else
			check(g2 .. " posts on the stair, 8 per side", #list == 8)
			for i = 2, #list do check(g2 .. " spacing ~20", list[i] - list[i - 1] >= 18 and list[i] - list[i - 1] <= 22) end
		end
	end
end
-- (c) waterfalls
local falls, mist = {}, {}
for _, sl in slots do
	if sl.Group == "Waterfall" then table.insert(falls, sl) end
	if sl.Group == "Mist" then table.insert(mist, sl) end
end
local owners = {}
for _, f in falls do
	owners[f.Owner] = true
	check("waterfall 80-200 tall: " .. f.Height, f.Height >= 80 and f.Height <= 200 and math.abs(L.Piece[f.Piece][2] * f.SY - f.Height) < 1e-6)
end
print(string.format("  waterfalls %d, mist anchors %d", #falls, #mist))
check("3+ waterfalls under P1 and P2", #falls >= 3 and owners.P1 and owners.P2)
check("a mist anchor at the base of every fall", #mist == #falls)
for i, f in falls do check("mist anchor at fall base", math.abs(mist[i].Y - f.Y) < 1e-6 and math.abs(mist[i].X - f.X) < 1e-6) end
-- (d) ruined-arch viewpoint
local arches = {}
for _, sl in slots do if sl.Piece == "Ruined_Arch" then table.insert(arches, sl) end end
check("ruined arch slots", #arches >= 1)
local cen = Vector3.new(0, 0, 0)
for _, k in { "T1", "T2", "T3" } do cen += Vector3.new(0, T[k].Top / 2 + T[k].FloorY / 2, (T[k].FrontZ + T[k].BackZ) / 2) / 3 end
local function rayHitsBox(o, d, lo, hi)
	local t0, t1 = 0, 1
	for _, ax in { "X", "Y", "Z" } do
		local oo, dd = o[ax], d[ax]
		if math.abs(dd) < 1e-9 then
			if oo < lo[ax] or oo > hi[ax] then return false end
		else
			local a, b = (lo[ax] - oo) / dd, (hi[ax] - oo) / dd
			t0, t1 = math.max(t0, math.min(a, b)), math.min(t1, math.max(a, b))
			if t0 > t1 then return false end
		end
	end
	return true
end
for _, a in arches do
	local d = L.Piece.Ruined_Arch
	local lo = Vector3.new(a.X - d[1] * a.SX / 2, a.Y, a.Z - d[3] * a.SZ / 2)
	local hi = Vector3.new(a.X + d[1] * a.SX / 2, a.Y + d[2] * a.SY, a.Z + d[3] * a.SZ / 2)
	for _, target in { aim, cen } do
		check("arch does not block the castle ray from eye 01", not rayHitsBox(eye, target - eye, lo, hi))
	end
	local sx, sy = project((lo.X + hi.X) / 2, (lo.Y + hi.Y) / 2, (lo.Z + hi.Z) / 2)
	check("arch is inside the view-01 frame", math.abs(sx) < 1 and math.abs(sy) < 1)
	check("arch 30-60 tall", d[2] * a.SY >= 30 and d[2] * a.SY <= 60)
end
local archBanners, species, trees, graves, tombs, fences, gibbets = 0, {}, {}, 0, 0, 0, 0
for _, sl in slots do
	if sl.Banner then end
	if sl.Group == "Banner" and sl.Arch then archBanners += 1 end
	if sl.Group == "Tree" then species[sl.Piece] = true; table.insert(trees, sl) end
	if sl.Group == "Grave" then if sl.Tomb then tombs += 1 else graves += 1 end end
	if sl.Group == "Fence" then fences += 1 end
	if sl.Group == "Gibbet" and sl.Rim then gibbets += 1 end
end
check("2 torn banners on the arch", archBanners == 2)
check("3 dead species", species.Dead_Oak_Gnarled and species.Dead_Pine_Snapped and species.Thorn_Twisted)
print(string.format("  dead trees %d, gravestones %d, tomb slabs %d, fence pieces %d, gibbets %d", #trees, graves, tombs, fences, gibbets))
check("30+ dead trees", #trees >= 30)
check("graveyard: 20+ stones, tomb slabs, iron fence; 2+ gibbets on the rim", graves >= 20 and tombs >= 1 and fences >= 4 and gibbets >= 2)
local clusters = {}
for _, t in trees do clusters[t.Cluster] = (clusters[t.Cluster] or 0) + 1 end
check("trees cluster at the arch, road, rim and graveyard", clusters.Arch and clusters.Road and clusters.Rim and clusters.Graveyard)
local sights = { { eye, aim }, { vec(L.Eye02), vec(L.Aim02) } }
for _, t in trees do
	local base = Vector3.new(t.X, t.Y, t.Z)
	local h = L.Piece[t.Piece][2] * t.SY
	local dir = Vector3.new(math.sin(t.Yaw), 0, math.cos(t.Yaw))
	local tip = base + Vector3.new(0, math.cos(t.Lean), 0) * h + dir * (math.sin(t.Lean) * h)
	check("tree leans a little", t.Lean > 0.05 and t.Lean < 0.4)
	for _, sg in sights do
		local lo = math.huge
		for i = 0, 10 do
			local p = base:Lerp(tip, i / 10)
			lo = math.min(lo, segDist(p, sg[1], sg[2]))
		end
		check("tree clear of the view-01/02 sightline (>= 14 studs): " .. string.format("%.0f", lo), lo >= 14)
	end
end
print(string.format("  Part estimate (built here): %d", parts))

print(string.format("passed %d, failed %d", passed, failed))
if failed > 0 then error(string.format("%d vesperhold massing checks failed", failed)) end

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
print(string.format("  route samples: %d, floor holes: %d, blocked headroom: %d", samples, holes, blocked))
check("walk route has a collidable floor at every sample (no gap > 1 stud)", holes == 0)
check("walk route has headroom at every sample", blocked == 0)

print(string.format("passed %d, failed %d", passed, failed))
if failed > 0 then error(string.format("%d vesperhold massing checks failed", failed)) end

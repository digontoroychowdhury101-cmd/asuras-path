--!nonstrict
-- Amberfall ravine crossing (art direction d): the stone viaduct builder in OverworldService, run on Instance fakes.
-- Run: python3 tools/lune_compat.py tools/test_ravine_span.luau
-- Checks: a collidable deck path from endpoint A to B (no gap > 1 stud, no step > 2, ends on the written surface,
-- width >= 10, grade <= 30 degrees), parapets on both sides, piers seated in the ground and reaching the deck,
-- arches present, and every shelter roof / cave-mouth lintel tagged AsuraShelter.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local O = require("../src/shared/Overworld")

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local services = {
	Workspace = {},
	Players = {},
	CollectionService = { AddTag = function(_, inst, tag) inst:AddTag(tag) end },
	ReplicatedStorage = { WaitForChild = function() return { Shared = { Overworld = O, WorldDefinitions = {}, InputMap = {} } } end },
}
local env = { game = { GetService = function(_, n) return services[n] end },
	script = { Parent = { WaitForChild = function() return {} end } }, require = function(m) return m end,
	task = { wait = function() end, spawn = function() end, delay = function() end }, os = os, math = math, table = table, string = string,
	Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Instance = roblox.Instance, Enum = roblox.Enum,
	pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, warn = warn, print = print, assert = assert, error = error,
	setmetatable = setmetatable, pcall = pcall }
local Service = luau.load(fs.readFile("src/server/Services/OverworldService.luau"), { debugName = "OverworldService", environment = env })()

local B = O.Blockout
local def
for _, b in B.Bridges do if b.Id == "AmberfallCrossing" then def = b end end
check("AmberfallCrossing is still authored with its route edges", def ~= nil and #def.Edges == 2 and def.Kind == "stone")

local folder = roblox.Instance.new("Folder")
Service.Build.StoneBridge(def, folder)
local model = folder:FindFirstChild(def.Id)
check("bridge model keeps its id", model ~= nil)

local parts, byName = {}, {}
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
		byName[d.Name] = byName[d.Name] or {}
		table.insert(byName[d.Name], d)
	end
end
local function count(n) return #(byName[n] or {}) end
print(string.format("  AmberfallCrossing parts: %d (Deck %d, Parapet %d, Pier %d, Abutment %d, Voussoir %d, Spandrel %d, Pilaster %d)",
	#parts, count("Deck"), count("ParapetL") + count("ParapetR"), count("Pier"), count("Abutment"), count("Voussoir"), count("Spandrel"), count("Pilaster")))
check("every part is anchored", (function()
	for _, p in parts do if not p.Anchored then return false end end
	return true
end)())

-- Deck path: horizontal axis A to B, then every deck slab as (u start, u end, top y at each end).
local ax, az = def.A.X, def.A.Z
local dx, dz = def.B.X - ax, def.B.Z - az
local hlen = math.sqrt(dx * dx + dz * dz)
local hx, hz = dx / hlen, dz / hlen
local function u(p) return (p.X - ax) * hx + (p.Z - az) * hz end
local function lateral(p) return -(p.X - ax) * hz + (p.Z - az) * hx end

local slabs = {}
for _, p in byName.Deck or {} do
	local e1 = p.CFrame:PointToWorldSpace(roblox.Vector3.new(0, p.Size.Y / 2, -p.Size.Z / 2))
	local e2 = p.CFrame:PointToWorldSpace(roblox.Vector3.new(0, p.Size.Y / 2, p.Size.Z / 2))
	if u(e1) > u(e2) then e1, e2 = e2, e1 end
	table.insert(slabs, { part = p, a = e1, b = e2 })
end
table.sort(slabs, function(l, r) return u(l.a) < u(r.a) end)
check("deck exists and collides", #slabs >= 1 and (function()
	for _, s in slabs do if not s.part.CanCollide then return false end end
	return true
end)())

local gap, step, grade, minWidth = 0, 0, 0, math.huge
for i, s in slabs do
	minWidth = math.min(minWidth, s.part.Size.X)
	local run = u(s.b) - u(s.a)
	grade = math.max(grade, math.deg(math.atan2(math.abs(s.b.Y - s.a.Y), run)))
	if i > 1 then
		local prev = slabs[i - 1]
		gap = math.max(gap, u(s.a) - u(prev.b))
		step = math.max(step, math.abs(s.a.Y - prev.b.Y))
	end
end
local first, last = slabs[1], slabs[#slabs]
check("deck starts at A and ends at B (within 1 stud)", first ~= nil and math.abs(u(first.a)) <= 1 and math.abs(lateral(first.a)) <= 1
	and math.abs(u(last.b) - hlen) <= 1 and math.abs(lateral(last.b)) <= 1)
check("deck has no gap over 1 stud", gap <= 1)
check("deck has no step over 2 studs", step <= 2)
local surfA, surfB = O.surfaceAt(def.A.X, def.A.Z), O.surfaceAt(def.B.X, def.B.Z)
check("deck meets the written surface at both ends (within 2)", first ~= nil and math.abs(first.a.Y - surfA) <= 2 and math.abs(last.b.Y - surfB) <= 2)
check("deck width at least 10", minWidth >= 10)
check("deck grade at most 30 degrees", grade <= 30)
print(string.format("  deck: %d slab(s), width %.0f, gap %.2f, step %.2f, grade %.2f deg, ends %.1f/%.1f vs ground %.1f/%.1f",
	#slabs, minWidth, gap, step, grade, first.a.Y, last.b.Y, surfA, surfB))

local function deckTop(at)
	local f = math.clamp(at / hlen, 0, 1)
	return first.a.Y + (last.b.Y - first.a.Y) * f
end

-- Parapets: both sides, collidable, along the whole deck and standing above it.
local sides = {}
for _, n in { "ParapetL", "ParapetR" } do
	local p = (byName[n] or {})[1]
	check(n .. " exists and collides", p ~= nil and p.CanCollide)
	if p then
		local lat = lateral(p.Position)
		table.insert(sides, lat)
		check(n .. " spans the deck and rises above it", p.Size.Z >= hlen * 0.95 and p.Position.Y + p.Size.Y / 2 >= deckTop(u(p.Position)) + 2)
		check(n .. " sits at the deck edge", math.abs(math.abs(lat) - (def.Width / 2 - 0.8)) <= 0.5)
	end
end
check("parapets on opposite sides", #sides == 2 and sides[1] * sides[2] < 0)

-- Mass: piers stand in the ground and reach the deck underside; arches and abutments exist.
local piers = {}
for _, p in byName.Pier or {} do
	local key = string.format("%.1f", u(p.Position))
	piers[key] = piers[key] or { lo = math.huge, hi = -math.huge, x = p.Position.X, z = p.Position.Z, u = u(p.Position) }
	piers[key].lo = math.min(piers[key].lo, p.Position.Y - p.Size.Y / 2)
	piers[key].hi = math.max(piers[key].hi, p.Position.Y + p.Size.Y / 2)
end
local npiers, seated, reaching = 0, true, true
for _, pr in piers do
	npiers += 1
	seated = seated and pr.lo <= O.heightAt(pr.x, pr.z) - 1
	reaching = reaching and math.abs(pr.hi - (deckTop(pr.u) - 4)) <= 0.6
end
check("at least 6 piers", npiers >= 6)
check("every pier is seated in the ground", seated)
check("every pier reaches the deck underside", reaching)
check("two abutments seated at the rims", count("Abutment") == 2)
check("arches: 8 voussoirs per bay with spandrel fill", count("Voussoir") >= 8 * (npiers + 1) and count("Spandrel") >= 4 * (npiers + 1))
check("parapet pilasters at every pier and abutment", count("Pilaster") >= 2 * (npiers + 2))

-- Weather cover: every shelter roof and cave-mouth lintel carries AsuraShelter.
local roofs, tagged = 0, 0
for _, s in B.Shelters do
	local f = roblox.Instance.new("Folder")
	Service.Build.Shelter(s, f)
	local roof = f:FindFirstChild(s.Id) and f[s.Id]:FindFirstChild("Roof")
	roofs += 1
	if roof and roof:HasTag("AsuraShelter") then tagged += 1 end
end
check("every shelter roof is tagged AsuraShelter", roofs == #B.Shelters and tagged == roofs)
local mouths, mouthTagged = 0, 0
for _, pdef in B.Portals do
	local f = roblox.Instance.new("Folder")
	Service.Build.Portal(pdef, f)
	local lintel = f:FindFirstChild(pdef.Id) and f[pdef.Id]:FindFirstChild("Lintel")
	mouths += 1
	if lintel and lintel:HasTag("AsuraShelter") then mouthTagged += 1 end
end
check("every cave-mouth lintel is tagged AsuraShelter", mouths == #B.Portals and mouthTagged == mouths)

print(string.format("ravine span: %d passed, %d failed", passed, failed))
if failed > 0 then error("ravine span tests failed") end

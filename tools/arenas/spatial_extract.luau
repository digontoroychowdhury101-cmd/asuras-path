--!nonstrict
-- Local Luau runner (no Explorer location): AR00 spatial survey. Prints one JSON document with every
-- region bound, boss arena, fog gate, altar, foe spawn, campaign/monastery zone and door, layout mark,
-- catch volume, lore tablet, cache and solid layout box, read from the same modules the game builds
-- from. Run from the repository root:
--   work/bin/luau/luau tools/arenas/spatial_extract.luau > outputs/.../AR00/spatial-current.json
local World = require("../../src/shared/WorldDefinitions")
local Campaign = require("../../src/shared/CampaignZones")
local Zones = require("../../src/shared/MonasteryZones")
local Narrative = require("../../src/shared/NarrativeCatalog")
local Arsenal = require("../../src/shared/ArsenalCatalog")

local function q(s) return '"' .. string.gsub(tostring(s), '[%c"\\]', function(c) return string.format("\\u%04x", string.byte(c)) end) .. '"' end
local function enc(v)
	local t = type(v)
	if t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in ipairs(v) do table.insert(parts, enc(x)) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for k in pairs(v) do table.insert(keys, tostring(k)) end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do
			local x = v[k]
			if x == nil then x = v[tonumber(k)] end
			if type(x) ~= "function" then table.insert(parts, q(k) .. ":" .. enc(x)) end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		return string.format("%.4g", v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "nil" then
		return "null"
	end
	return q(v)
end
local function vec(v) return v and { v.X, v.Y, v.Z } or nil end
local function pl(p) return p and { p.X, p.Y, p.Z, p.Yaw or 0 } or nil end

local out = { regions = {}, bosses = {}, fogGates = {}, altars = {}, spawns = {}, zones = {}, doors = {}, layouts = {}, lore = {}, caches = {}, monastery = {} }
for id, r in World.Regions do
	out.regions[id] = { centre = vec(r.Bounds.Center), size = vec(r.Bounds.Size) }
end
out.regionOrder = World.RegionOrder
for id, b in World.Bosses do
	out.bosses[id] = { region = b.Region, centre = vec(b.Arena.Center), size = vec(b.Arena.Size), spawn = pl(b.Spawn), fogGate = b.FogGate,
		scale = b.Scale or 1, archetype = b.Archetype }
end
for id, g in World.FogGates do
	out.fogGates[id] = { boss = g.Boss, placement = pl(g.Placement), size = vec(g.Size), trigger = { centre = vec(g.Trigger.Center), size = vec(g.Trigger.Size) },
		inside = pl(g.Inside), outside = pl(g.Outside) }
end
for id, a in World.Altars do
	out.altars[id] = { region = a.Region, placement = pl(a.Placement), spawn = pl(a.Spawn), exit = pl(a.Exit), radius = a.Radius }
end
for _, s in World.Spawns do
	table.insert(out.spawns, { id = s.Id, kind = s.Kind or s.Enemy or s.Archetype, region = s.Region, placement = pl(s.Placement) })
end
for _, z in Campaign.List do
	table.insert(out.zones, { id = z.Id, name = z.Name, region = z.Region, x0 = z.X0, x1 = z.X1, z0 = z.Z0, z1 = z.Z1, y0 = z.Y0, y1 = z.Y1 })
end
for _, d in Campaign.Doors do
	table.insert(out.doors, { a = d.A, b = d.B, x = d.X, y = d.Y, z = d.Z, name = d.Name, oneWay = d.OneWay, optional = d.Optional })
end
for _, z in Zones.List do
	table.insert(out.monastery, { id = z.Id, name = z.Name, x0 = z.X0, x1 = z.X1, z0 = z.Z0, z1 = z.Z1 })
end
for _, layout in Campaign.Layouts do
	local solids = {}
	for _, b in layout.Solids do
		table.insert(solids, { b.Name, b.Kind, b.X, b.Y, b.Z, b.SX, b.SY, b.SZ, b.Yaw or 0 })
	end
	local marks = {}
	for k, m in layout.Marks do marks[k] = { m.X, m.Y, m.Z, m.Yaw or 0, m.Name } end
	local catches = {}
	for _, c in layout.Catches or {} do
		table.insert(catches, { name = c.Name, x0 = c.X0, x1 = c.X1, z0 = c.Z0, z1 = c.Z1, below = c.Below, to = c.To and { c.To.X, c.To.Y, c.To.Z, c.To.Yaw } })
	end
	out.layouts[layout.Region] = { solids = solids, marks = marks, catches = catches }
end
for key, l in Narrative.Lore do out.lore[key] = { region = l.Region, at = { l.X, l.Y, l.Z } } end
for key, c in Arsenal.Caches do out.caches[key] = { region = c.Region, at = { c.X, c.Y, c.Z } } end
out.rings = {
	{ id = "Ring_OctagonOfAsh", region = "AshColosseum", centre = { 118, 0, -1770 }, apothem = 20, band = 7 },
	{ id = "Ring_GatehouseCircle", region = "DesecratedMonastery", centre = { -130, 0, -745 }, apothem = 16, band = 6 },
}
print(enc(out))

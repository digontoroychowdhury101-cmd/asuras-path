--!nonstrict
-- Regression for the canonical overworld data (ticket 01). Run from the project root:
--   work/bin/luau/luau.exe tools/test_overworld_data.luau   (plain Luau CLI; no Lune APIs needed)
-- Pure data checks: IDs, containment, clearances, route graph, blend, map transform, integration.
local O = require("../src/shared/Overworld")
local World = require("../src/shared/WorldDefinitions")
local Narrative = require("../src/shared/NarrativeCatalog")

local passed, failed = 0, 0
local function check(name, condition)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function inside(bounds, p) return O.contains(bounds, p.X, p.Y, p.Z) end
local function xzOverlap(a, b) -- positive-area overlap in XZ (touching borders do not count)
	local function span(box, axis) return box.Center[axis] - box.Size[axis] / 2, box.Center[axis] + box.Size[axis] / 2 end
	local ax0, ax1 = span(a, "X"); local bx0, bx1 = span(b, "X")
	local az0, az1 = span(a, "Z"); local bz0, bz1 = span(b, "Z")
	return math.min(ax1, bx1) > math.max(ax0, bx0) and math.min(az1, bz1) > math.max(az0, bz0)
end
local function overlap3(a, b)
	local ay0, ay1 = a.Center.Y - a.Size.Y / 2, a.Center.Y + a.Size.Y / 2
	local by0, by1 = b.Center.Y - b.Size.Y / 2, b.Center.Y + b.Size.Y / 2
	return xzOverlap(a, b) and math.min(ay1, by1) > math.max(ay0, by0)
end
local function count(t) local n = 0 for _ in t do n += 1 end return n end
local F = O.Frame
local function inFrame(p) return p.X >= F.MinX and p.X <= F.MaxX and p.Z >= F.MinZ and p.Z <= F.MaxZ end
local all = { "AshColosseum", table.unpack(O.RegionIds) }

-- 1. Kept and new IDs (test: ids present and exact).
for _, id in { "Altar_MonasteryGate", "Altar_BellTerrace", "Altar_BambooShrine", "Altar_DesecratedCloister", "Altar_ColosseumAntechamber",
	"Altar_RavineOverlook", "Altar_BasinCistern", "Altar_SnowRefuge", "Altar_MountainRefuge" } do
	check("altar id " .. id, O.Altars[id] ~= nil and O.Altars[id].Id == id and O.Nodes[id] ~= nil)
end
for _, id in { "WaterfallAlcove", "SealedMausoleum", "FoundersKiln", "PagodaRafters", "FrostWatchpost", "SaltCaravan" } do
	check("cache id " .. id, O.Caches[id] ~= nil and O.Caches[id].Id == id)
end
check("gate id", O.Barrier.Gate.Id == "Gate_AshColosseum" and O.Barrier.Gate.Boss == "GrandmasterShen" and O.Barrier.Boss == "GrandmasterShen")
check("miniboss id", O.Minibosses.HollowBellWarden ~= nil and O.Minibosses.HollowBellWarden.Id == "HollowBellWarden" and O.Minibosses.HollowBellWarden.Region == "Forest")
check("kept caches exist in ArsenalCatalog", (function()
	local Arsenal = require("../src/shared/ArsenalCatalog")
	for _, id in { "WaterfallAlcove", "SealedMausoleum", "FoundersKiln", "PagodaRafters" } do
		if Arsenal.Caches[id] == nil then return false end
	end
	return true
end)())
check("nine lore ids exact", count(O.Lore) == 9 and (function()
	for _, id in Narrative.LoreOrder do
		if O.Lore[id] == nil or O.Lore[id].Id ~= id then return false end
	end
	return true
end)())
check("lore regions: monastery F5, bamboo F4, pagoda M5", O.Lore.Pillars.Subarea == "F5" and O.Lore.Emissary.Subarea == "F5" and O.Lore.Bamboo.Subarea == "F4"
	and O.Lore.Wraith.Subarea == "F4" and O.Lore.Pagoda.Subarea == "M5" and O.Lore.Dawn.Subarea == "M5")

-- 2. Containment: altars, caches, lore, POIs, barrier, nodes, landmarks inside region bounds and the Frame.
for id, a in O.Altars do
	local b = O.Regions[a.Region].Bounds
	check("altar in region " .. id, inside(b, a.Placement) and inside(b, a.Spawn) and inside(b, a.Exit) and inFrame(a.Placement))
	check("altar node matches " .. id, near(O.Nodes[id].Position.X, a.Placement.X) and near(O.Nodes[id].Position.Z, a.Placement.Z) and O.Nodes[id].Region == a.Region)
end
for id, c in O.Caches do check("cache in region " .. id, inside(O.Regions[c.Region].Bounds, c.Position) and inFrame(c.Position)) end
for id, l in O.Lore do check("lore in region " .. id, inside(O.Regions[l.Region].Bounds, l.Position) and inFrame(l.Position)) end
do
	local m = O.Minibosses.HollowBellWarden
	check("miniboss in region", inside(O.Regions[m.Region].Bounds, m.Placement))
end
for _, p in O.POIs do
	check("poi in region " .. p.Id, inside(O.Regions[p.Region].Bounds, p.Position) and inFrame(p.Position) and (p.Level == "Surface" or p.Level == "Underground") and type(p.Hidden) == "boolean")
end
check("has underground and hidden pois", (function()
	local u, h = false, false
	for _, p in O.POIs do u = u or p.Level == "Underground"; h = h or p.Hidden end
	return u and h
end)())
for id, n in O.Nodes do check("node in region " .. id, inside(O.Regions[n.Region].Bounds, n.Position) and inFrame(n.Position)) end
for id, l in O.Landmarks do check("landmark " .. id, l.Persistent == true and l.Height > 0 and inside(O.Regions[l.Region].Bounds, l.Position) and O.Nodes[l.Node] ~= nil) end
check("five landmarks plus summit", count(O.Landmarks) >= 6 and O.Landmarks[O.SummitId] ~= nil)
do
	local g, domain, arena = O.Barrier.Gate, O.Regions.AshColosseum.Bounds, O.Barrier.Arena
	check("barrier in domain", inside(domain, g.Placement) and inside(domain, arena.Center) and inside(arena, O.Barrier.BossSpawn))
	check("barrier arena fits domain", inside(domain, { X = arena.Center.X - arena.Size.X / 2, Y = arena.Center.Y - arena.Size.Y / 2, Z = arena.Center.Z - arena.Size.Z / 2 })
		and inside(domain, { X = arena.Center.X + arena.Size.X / 2, Y = arena.Center.Y + arena.Size.Y / 2, Z = arena.Center.Z + arena.Size.Z / 2 }))
	check("barrier trigger/inside in arena, outside outside", inside(arena, g.Trigger.Center) and inside(arena, g.Inside) and not inside(arena, g.Outside))
	check("barrier outside on temple side", O.regionAt(g.Outside.X, g.Outside.Y, g.Outside.Z) == "MountainAscent")
	check("domain inside mountain box", O.regionAt(-7200, 1600, -8250) == "AshColosseum")
end
for id, r in O.ReservedArenas do
	check("reserved arena " .. id, inside(O.Regions[r.Region].Bounds, r.Arena.Center) and World.Bosses[id] ~= nil)
end

-- 3. Clearances: lobby, reserved depths, old corridor.
local clearances = {
	Lobby = { Center = { X = 0, Y = 800, Z = 650 }, Size = { X = 600, Y = 800, Z = 920 } },
	Depths = { Center = { X = 520, Y = 0, Z = 900 }, Size = { X = 360, Y = 4000, Z = 360 } },
	OldCorridor = { Center = { X = 0, Y = 0, Z = -1830 }, Size = { X = 900, Y = 4000, Z = 2300 } },
}
for rid, r in O.Regions do
	for cid, c in clearances do check(rid .. " clear of " .. cid, not xzOverlap(r.Bounds, c)) end
	check(rid .. " inside Frame", r.Bounds.Center.X - r.Bounds.Size.X / 2 >= F.MinX and r.Bounds.Center.X + r.Bounds.Size.X / 2 <= F.MaxX
		and r.Bounds.Center.Z - r.Bounds.Size.Z / 2 >= F.MinZ and r.Bounds.Center.Z + r.Bounds.Size.Z / 2 <= F.MaxZ)
end
check("frame clear of lobby and corridor", F.MaxX < -450 and F.MaxZ < -680)
for i, a in O.RegionIds do
	for j = i + 1, #O.RegionIds do
		local b = O.RegionIds[j]
		check("regions overlap only if height-disjoint " .. a .. "/" .. b, not overlap3(O.Regions[a].Bounds, O.Regions[b].Bounds))
	end
end

-- 3b. Total coverage (T09a): every surface point of the Frame resolves to an overworld region, the same one
-- through Overworld.regionAt and the applied World.regionAt.
do
	local steps, missing, differs = 50, 0, 0
	for i = 0, steps do
		for j = 0, steps do
			local x, z = F.MinX + (F.MaxX - F.MinX) * i / steps, F.MinZ + (F.MaxZ - F.MinZ) * j / steps
			local y = O.heightAt(x, z) + 3
			local id = O.regionAt(x, y, z)
			if id == nil then missing += 1 elseif World.regionAt(x, y, z) ~= id then differs += 1 end
		end
	end
	check("every surface point in the frame has a region (" .. missing .. " missing of " .. (steps + 1) ^ 2 .. ")", missing == 0)
	check("World.regionAt agrees with Overworld.regionAt on the grid", differs == 0)
end

-- 4. Display names, no reference-game words.
local names = { Forest = "The Bellwood", GoldenRavine = "Amberfall Ravine", AridBasin = "The Saltreach", Snowfields = "Frostmere Heads", MountainAscent = "The Ashen Stair", AshColosseum = "Ash Colosseum" }
for id, name in names do check("display name " .. id, O.Regions[id].Name == name) end
local function words(t, out) -- every string value in the data
	for k, val in t do
		if type(val) == "string" then table.insert(out, val) elseif type(val) == "table" then words(val, out) end
		if type(k) == "string" then table.insert(out, k) end
	end
	return out
end
for _, text in words(O, {}) do
	local lower = string.lower(text)
	check("no reference-game word in " .. text, not (string.find(lower, "goldland") or string.find(lower, "thonia") or string.find(lower, "fragment")))
end
for _, id in all do check("map folder " .. id, O.Regions[id].MapFolder == "Map_Overworld" and O.Regions[id].Blend == 200) end
check("blend margin ~200", O.Blend == 200)

-- 5. Divide ridge: continuous, N-S, X -5400..-5000, Z -5000..-1200.
do
	local d, ok = O.Divide, true
	for i, p in d do
		ok = ok and p.X >= -5400 and p.X <= -5000
		if i > 1 then ok = ok and p.Z > d[i - 1].Z and (p.Z - d[i - 1].Z) <= 700 end
	end
	check("divide continuous N-S ridge", ok and d[1].Z == -5000 and d[#d].Z == -1200)
end

-- 6. Transition bands: every shared border has one (150..400 studs).
do
	local function span(box, axis) return box.Center[axis] - box.Size[axis] / 2, box.Center[axis] + box.Size[axis] / 2 end
	local function bandFor(a, b)
		for _, band in O.Bands do
			if (band.A == a and band.B == b) or (band.A == b and band.B == a) then return band end
		end
		return nil
	end
	local borders = 0
	for i, a in O.RegionIds do
		for j = i + 1, #O.RegionIds do
			local b = O.RegionIds[j]
			local ax0, ax1 = span(O.Regions[a].Bounds, "X"); local bx0, bx1 = span(O.Regions[b].Bounds, "X")
			local az0, az1 = span(O.Regions[a].Bounds, "Z"); local bz0, bz1 = span(O.Regions[b].Bounds, "Z")
			local xo, zo = math.min(ax1, bx1) - math.max(ax0, bx0), math.min(az1, bz1) - math.max(az0, bz0)
			if xo >= 0 and zo >= 0 and not (xo == 0 and zo == 0) then
				borders += 1
				local band = bandFor(a, b)
				check("band for border " .. a .. "/" .. b, band ~= nil and band.Width >= 150 and band.Width <= 400
					and (band.Kind == "foothills" or band.Kind == "river" or band.Kind == "dry channel" or band.Kind == "ridge"))
			end
		end
	end
	check("bands match borders", borders == #O.Bands and borders >= 5)
end

-- 7. Retired altars: map is total, targets exist, and they leave World.Altars once applied.
for _, id in { "Altar_SanctuaryDepths", "Altar_CelestialPagoda", "Altar_SkyCitadel" } do
	local target = O.RetiredAltars[id]
	check("retired map total " .. id, target ~= nil and O.Altars[target] ~= nil)
end
check("retired map has no extras", count(O.RetiredAltars) == 3 and count(O.RetiredRegions) == 5)

-- 8. Route graph.
do
	local adj, kinds = {}, {}
	for id in O.Nodes do adj[id] = {} end
	local edgeKey = {}
	for _, e in O.Edges do
		local a, b = O.Nodes[e.A], O.Nodes[e.B]
		check("edge endpoints " .. e.A .. "-" .. e.B, a ~= nil and b ~= nil)
		if a and b then
			table.insert(adj[e.A], e.B); table.insert(adj[e.B], e.A)
			local d = math.sqrt((a.Position.X - b.Position.X) ^ 2 + (a.Position.Z - b.Position.Z) ^ 2)
			check("edge length >= straight line " .. e.A .. "-" .. e.B .. " (" .. e.Length .. " vs " .. math.floor(d) .. ")", e.Length >= d)
			check("edge kind " .. e.A .. "-" .. e.B, e.Kind == "main" or e.Kind == "alternate" or e.Kind == "optional" or e.Kind == "shortcut")
			kinds[e.Region] = kinds[e.Region] or {}
			kinds[e.Region][e.Kind] = (kinds[e.Region][e.Kind] or 0) + 1
			edgeKey[e.A .. "|" .. e.B .. "|" .. e.Kind], edgeKey[e.B .. "|" .. e.A .. "|" .. e.Kind] = e, e
		end
	end
	local seen, queue = { [O.Gateway] = true }, { O.Gateway }
	while #queue > 0 do
		local cur = table.remove(queue)
		for _, nxt in adj[cur] do
			if not seen[nxt] then seen[nxt] = true; table.insert(queue, nxt) end
		end
	end
	check("route graph connected from gateway", count(seen) == count(O.Nodes) and seen[O.BarrierNode] == true)
	local total, ok = 0, #O.LongRoute >= 2 and O.LongRoute[1] == O.Gateway and O.LongRoute[#O.LongRoute] == O.BarrierNode
	for i = 2, #O.LongRoute do
		local e = edgeKey[O.LongRoute[i - 1] .. "|" .. O.LongRoute[i] .. "|main"]
		if e == nil then ok = false else total += e.Length end
	end
	check("long route exists on main edges (" .. total .. ")", ok and total >= 14000 and total <= 17500)
	for _, id in O.RegionIds do
		local k = kinds[id] or {}
		check("region route kinds " .. id, (k.main or 0) >= 1 and (k.alternate or 0) >= 1 and (k.optional or 0) >= 1 and (k.shortcut or 0) >= 1)
		local subareas, n = {}, 0
		for _, node in O.Nodes do
			if node.Region == id and node.Subarea and not subareas[node.Subarea] then subareas[node.Subarea] = true; n += 1 end
		end
		check("region subareas >= 3 " .. id, n >= 3)
	end
	check("BambooRidge shortcut locked", edgeKey["Altar_BambooShrine|Altar_BellTerrace|shortcut"] ~= nil and edgeKey["Altar_BambooShrine|Altar_BellTerrace|shortcut"].Lock == "BambooRidge")
end

-- 9. Map transform and blend.
do
	local u, w = O.toMap(F.MinX, F.MinZ)
	check("map NW corner", near(u, 0) and near(w, 0))
	u, w = O.toMap(F.MaxX, F.MaxZ)
	check("map SE corner", near(u, 1) and near(w, 1))
	local x, z = O.fromMap(0.25, 0.75)
	local u2, w2 = O.toMap(x, z)
	check("map round trip", near(u2, 0.25) and near(w2, 0.75))
	local x2, z2 = O.fromMap(O.toMap(-3000, -2000))
	check("map round trip world", near(x2, -3000) and near(z2, -2000))
	local _, vNorth = O.toMap(-5000, F.MinZ + 100)
	local _, vSouth = O.toMap(-5000, F.MaxZ - 100)
	check("north is top of map", vNorth < vSouth)
end
do
	local function sum(t) local s = 0 for _, w in t do s += w end return s end
	local bad = 0
	for gx = F.MinX, F.MaxX, 200 do
		for gz = F.MinZ, F.MaxZ, 200 do
			if math.abs(sum(O.blendAt(gx, gz)) - 1) > 1e-9 or math.abs(sum(O.blendAt(gx, gz, 100)) - 1) > 1e-9 then bad += 1 end
		end
	end
	check("blend weights sum to 1 over the frame", bad == 0)
	for _, id in O.RegionIds do
		local b = O.Regions[id].Bounds
		local w = O.blendAt(b.Center.X, b.Center.Z, b.Center.Y)
		check("blend is 1 at centre of " .. id, near(w[id] or 0, 1))
	end
	local border = O.blendAt(-5200, -2500) -- Forest / GoldenRavine border
	check("blend splits at a border", near(border.Forest or 0, 0.5) and near(border.GoldenRavine or 0, 0.5))
	local near100 = O.blendAt(-5200 + 120, -2500)
	check("blend is pure past half the margin", near(near100.Forest or 0, 1))
	local pass = O.blendAt(-8300, -4700, 280) -- pass foot: Basin and Mountain overlap, Y separates them
	check("blend uses height where regions overlap", near(pass.MountainAscent or 0, 1) and pass.AridBasin == nil)
	check("regionAt overworld points", O.regionAt(-2200, 60, -1400) == "Forest" and O.regionAt(-8100, 40, -2300) == "AridBasin" and O.regionAt(-8300, 280, -4700) == "MountainAscent"
		and O.regionAt(0, 600, 900) == nil)
end

-- 10. Active by default: loading the real World is the overworld.
check("active by default", O.Active == true and World.Regions.Forest ~= nil and World.Altars.Altar_SanctuaryDepths == nil
	and World.Altars.Altar_MonasteryGate.Region == "Forest")

-- 11. The applied World (WorldDefinitions calls apply() while Active).
do
	local w = World
	for id in O.RetiredAltars do
		check("retired absent from Altars " .. id, w.Altars[id] == nil)
		check("retired absent from its region " .. id, (function()
			for _, region in w.Regions do
				if region.Altars[(string.gsub(id, "^Altar_", ""))] ~= nil then return false end
			end
			return true
		end)())
	end
	for id, a in O.Altars do
		check("applied altar " .. id, w.Altars[id] == a and w.Regions[a.Region].Altars[(string.gsub(id, "^Altar_", ""))] == a)
	end
	for _, region in w.Regions do
		for short, a in region.Altars do check("region altar index consistent " .. short, a.Region == region.Id and w.Altars[a.Id] ~= nil) end
	end
	local starting = 0
	for id, a in w.Altars do
		local region = w.Regions[a.Region]
		check("applied altar inside its region " .. id, region ~= nil and O.contains(region.Bounds, a.Placement.X, a.Placement.Y, a.Placement.Z)
			and O.contains(region.Bounds, a.Spawn.X, a.Spawn.Y, a.Spawn.Z))
		if a.Starting then starting += 1 end
	end
	check("one starting altar after apply", starting == 1)
	check("portal destination still exists", w.Altars[w.Sanctuary.PortalDestination] ~= nil and w.Altars.Altar_MonasteryGate.Region == "Forest")
	local shen, gate = w.Bosses.GrandmasterShen, w.FogGates.Gate_AshColosseum
	check("shen arena in domain", w.Regions[shen.Region].Bounds == O.Regions.AshColosseum.Bounds and O.contains(w.Regions.AshColosseum.Bounds, shen.Arena.Center.X, shen.Arena.Center.Y, shen.Arena.Center.Z)
		and O.contains(shen.Arena, shen.Spawn.X, shen.Spawn.Y, shen.Spawn.Z))
	check("gate valid after apply", gate.Boss == "GrandmasterShen" and O.contains(shen.Arena, gate.Trigger.Center.X, gate.Trigger.Center.Y, gate.Trigger.Center.Z)
		and O.contains(shen.Arena, gate.Inside.X, gate.Inside.Y, gate.Inside.Z) and not O.contains(shen.Arena, gate.Outside.X, gate.Outside.Y, gate.Outside.Z))
	check("old regions retired by apply", w.Regions.DesecratedMonastery == nil and w.Regions.BambooPass == nil and w.Regions.SanctuaryDepths == nil
		and w.Regions.CelestialPagoda == nil and w.Regions.SkyCitadel == nil and table.find(w.RegionOrder, "BambooPass") == nil)
	for id, boss in w.Bosses do
		if id ~= "GrandmasterShen" then
			local region = w.Regions[boss.Region]
			check("inactive boss kept on a reserved site " .. id, boss.Inactive == true and w.FogGates[boss.FogGate] == nil and region ~= nil
				and O.contains(region.Bounds, boss.Arena.Center.X, boss.Arena.Center.Y, boss.Arena.Center.Z) and O.contains(boss.Arena, boss.Spawn.X, boss.Spawn.Y, boss.Spawn.Z))
		end
	end
	check("regions registered in order", table.find(w.RegionOrder, "Forest") ~= nil and table.find(w.RegionOrder, "MountainAscent") ~= nil and w.Caches == O.Caches)
end

print(string.format("overworld data: %d passed, %d failed", passed, failed))
if failed > 0 then error("overworld data checks failed") end

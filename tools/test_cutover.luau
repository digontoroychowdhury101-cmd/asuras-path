--!nonstrict
-- Ticket 08 cutover regression: with Overworld.Active the world is the lobby, five overworld regions and
-- Shen's domain only; the old corridor is gone from regions, altars, spawns, gates and the server boot.
-- Run: python3 tools/lune_compat.py tools/test_cutover.luau  (reads Bootstrap/BossArenas sources via @lune/fs)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local O = require("../src/shared/Overworld") :: any
local World = require("../src/shared/WorldDefinitions") :: any

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function count(t) local n = 0 for _ in t do n += 1 end return n end
local function inside(b, x, y, z)
	return math.abs(x - b.Center.X) <= b.Size.X / 2 and math.abs(y - b.Center.Y) <= b.Size.Y / 2 and math.abs(z - b.Center.Z) <= b.Size.Z / 2
end

-- 1. Regions: the lobby, the five overworld regions and the domain, nothing else.
local expected = { "Sanctuary", "Forest", "GoldenRavine", "AridBasin", "Snowfields", "MountainAscent", "AshColosseum" }
check("active", O.Active == true)
check("seven regions", count(World.Regions) == 7 and #World.RegionOrder == 7)
for _, id in expected do
	check("region " .. id, World.Regions[id] ~= nil and table.find(World.RegionOrder, id) ~= nil)
end
for _, id in O.RetiredRegions do
	check("retired region gone " .. id, World.Regions[id] == nil and table.find(World.RegionOrder, id) == nil)
end
check("domain is found before its host box", table.find(World.RegionOrder, "AshColosseum") < table.find(World.RegionOrder, "MountainAscent"))

-- 2. Altars: every altar sits in a live region; the retired ones are gone, the glade is the portal destination.
for id, altar in World.Altars do
	check("altar region live " .. id, World.Regions[altar.Region] ~= nil and inside(World.Regions[altar.Region].Bounds, altar.Placement.X, altar.Placement.Y, altar.Placement.Z))
end
for _, id in { "Altar_SanctuaryDepths", "Altar_CelestialPagoda", "Altar_SkyCitadel" } do
	check("retired altar gone " .. id, World.Altars[id] == nil)
end
check("portal lands on the glade", World.Altars[World.Sanctuary.PortalDestination].Region == "Forest")

-- 3. Gates and bosses: only Shen's barrier exists; the five archived bosses keep ids but have no gate or live arena.
check("one fog gate", count(World.FogGates) == 1 and World.FogGates.Gate_BellwoodLake ~= nil) -- win-106: Shen moved to the Bellwood lake
for id, boss in World.Bosses do
	if id == "GrandmasterShen" then
		check("shen is live", boss.Inactive == nil and boss.Region == "Forest" and World.FogGates[boss.FogGate] ~= nil)
	else
		check("archived boss " .. id, boss.Inactive == true and World.FogGates[boss.FogGate] == nil and World.Regions[boss.Region] ~= nil)
	end
end
check("six bosses keep their ids", count(World.Bosses) == 6)

-- 4. Spawns: the relocated warden, the training phantom and (ticket 09) exactly the authored ordinary encounters, each inside its region (patrol included).
check("warden, phantom and the authored encounters only", count(World.Spawns) == 2 + #O.EncounterSpots and World.spawnById("DM_Warden_Graves") ~= nil and World.spawnById("DM_Sparring_Phantom") ~= nil
	and (function() for _, spot in O.EncounterSpots do if World.spawnById(spot.Spawn) == nil then return false end end return true end)())
for _, entry in World.Spawns do
	local region = World.Regions[entry.Region]
	check("spawn in region " .. entry.Id, region ~= nil and inside(region.Bounds, entry.Placement.X, entry.Placement.Y, entry.Placement.Z))
	for _, point in entry.Patrol do check("patrol in region " .. entry.Id, inside(region.Bounds, point.X, point.Y, point.Z)) end
end

-- 5. Rings keep their ids; the two corridor rings stand on flat pads inside live regions, clear of altars and spawns.
local source = { Ring_GatehouseCircle = { 16, 6 }, Ring_OctagonOfAsh = { 20, 7 } } -- apothem, band (ColosseumService)
for id, def in source do
	local site = O.Rings[id]
	check("ring moved " .. id, site ~= nil and World.Regions[site.Region] ~= nil)
	local reach = (def[1] + 1 + def[2]) / math.cos(math.rad(22.5))
	local region = World.Regions[site.Region]
	for _, corner in { { reach, reach }, { -reach, reach }, { reach, -reach }, { -reach, -reach } } do
		check("ring corner in region " .. id, inside(region.Bounds, site.X + corner[1], site.Y, site.Z + corner[2]))
	end
	for aid, altar in World.Altars do
		local p = altar.Placement
		check("ring clear of altar " .. id .. " " .. aid, math.sqrt((p.X - site.X) ^ 2 + (p.Z - site.Z) ^ 2) > reach + altar.Radius + 4)
	end
	for _, entry in World.Spawns do
		check("ring clear of spawn " .. id .. " " .. entry.Id, math.sqrt((entry.Placement.X - site.X) ^ 2 + (entry.Placement.Z - site.Z) ^ 2) > reach + 12)
	end
	local worst = 0
	for a = 0, 15 do
		for _, r in { 0, reach * 0.5, reach } do
			local h = O.heightAt(site.X + r * math.cos(a * math.pi / 8), site.Z + r * math.sin(a * math.pi / 8))
			worst = math.max(worst, math.abs(h - (site.Y - 2))) -- voxel surface lies ~2 above heightAt
		end
	end
	check(string.format("ring pad is flat %s (worst %.2f)", id, worst), worst <= 0.5)
end
local colosseum = fs.readFile("src/server/Services/ColosseumService.luau")
for _, id in { "Ring_SanctuaryPromenade", "Ring_OctagonOfAsh", "Ring_GatehouseCircle" } do
	check("ring id kept " .. id, string.find(colosseum, 'Id = "' .. id .. '"', 1, true) ~= nil)
end

-- 6. Server boot and the archived arenas.
local boot = fs.readFile("src/server/Bootstrap.server.luau")
check("bootstrap does not require or start the old builders", not string.find(boot, 'WaitForChild("MonasteryService")', 1, true) and not string.find(boot, 'WaitForChild("CampaignWorld")', 1, true)
	and not string.find(boot, "Monastery.Start", 1, true) and not string.find(boot, "Campaign.Start", 1, true))
check("bootstrap starts the overworld before WorldService", (string.find(boot, "OverworldWorld.Start()", 1, true) or 1e9) < (string.find(boot, "WorldService.Start()", 1, true) or 0))
check("arenas skip archived bosses", string.find(fs.readFile("src/server/Services/BossArenas.luau"), "if boss.Inactive then continue end", 1, true) ~= nil
	and string.find(fs.readFile("src/server/Services/ArenaLighting.luau"), "if boss.Inactive then continue end", 1, true) ~= nil)

-- 7. Discoveries and presentation minimum.
for _, poi in O.POIs do
	local found = O.revealedAt(poi.Position.X, poi.Position.Y, poi.Position.Z)
	check("poi discoverable " .. poi.Id, table.find(found, poi.Id) ~= nil)
end
for id, landmark in O.Landmarks do
	check("landmark discoverable " .. id, table.find(O.revealedAt(landmark.Position.X, landmark.Position.Y, landmark.Position.Z), id) ~= nil)
end
check("lobby discovers nothing", #O.revealedAt(0, 603, 920) == 0)
local Profiles = luau.load(fs.readFile("src/shared/EnvironmentProfiles.luau"), { debugName = "EnvironmentProfiles", environment = { Color3 = roblox.Color3, Vector3 = roblox.Vector3 } })()
local clocks = {}
for _, id in O.RegionIds do
	check("profile resolves " .. id, Profiles.resolve(id, false, 1) == id and Profiles.resolve(id, true, 1, id) == "Combat:" .. id and Profiles.get("Unbound:" .. id) ~= nil)
	clocks[Profiles[id].Lighting.ClockTime] = true
end
check("five distinct daylights", count(clocks) == 5)
check("chasm rings like a ravine", Profiles.acoustics("GoldenRavine", roblox.Vector3.new(-5990, 100, -3000)) == "Ravine" and Profiles.acoustics("GoldenRavine", roblox.Vector3.new(-5990, 300, -3000)) == "Open"
	and Profiles.acoustics("Forest", roblox.Vector3.new(-2200, 60, -1400)) == "Open")

print(string.format("cutover: %d passed, %d failed", passed, failed))
if failed > 0 then error("cutover regression failed") end

--!nonstrict
-- Ticket 07 persistence migration through the real ProfileStore / ArsenalInventory / Objectives.
-- Runs against whichever world Overworld.Active selects: checks marked ACTIVE run only after the
-- cutover (CI runs this file on a copy of src with the flag set; see the 07 worker notes).
-- Run from the project root: work/bin/luau/luau tools/test_persistence_migration.luau
local World = require("../src/shared/WorldDefinitions")
local Overworld = require("../src/shared/Overworld")
local Catalog = require("../src/shared/ArsenalCatalog")
local Inventory = require("../src/simulation/ArsenalInventory")
local Narrative = require("../src/shared/NarrativeCatalog")
local Store = require("../src/server/ProfileStore")
local Profiles = require("../src/shared/ProfileSchema")
local ACTIVE = Overworld.Active

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local data: { [string]: any } = {}
local db = { UpdateAsync = function(_self: any, key: string, fn: (any) -> any): any
	local updated = fn(Store.Copy(data[key])); if updated then data[key] = Store.Copy(updated) end; return Store.Copy(updated)
end }
local function engine(owner: string)
	return Store.new(db, Profiles, { owner = owner, now = function() return 1000 end, wait = function() end, attempts = 1, leaseSeconds = 180 })
end
local function raw(mutate: (any) -> ()): any
	local souls: any = Store.DefaultSouls(nil)
	mutate(souls)
	return souls
end

-- 1. Retired activeAltar: respawns at the glade, retired ids stay kindled, never offered for travel.
local retired = raw(function(s)
	s.world.altars.Altar_MonasteryGate = true
	s.world.altars.Altar_SkyCitadel = true
	s.world.activeAltar = "Altar_SkyCitadel"
end)
local migrated = Store.MigrateSouls(retired, nil)
if ACTIVE then
	check("retired activeAltar maps to the glade", migrated.world.activeAltar == "Altar_MonasteryGate")
	check("fast travel never offers a retired altar", World.Altars.Altar_SkyCitadel == nil and World.Altars.Altar_SanctuaryDepths == nil and World.Altars.Altar_CelestialPagoda == nil)
else
	check("live altar is untouched before the cutover", migrated.world.activeAltar == "Altar_SkyCitadel")
end
check("retired ids stay in altars", migrated.world.altars.Altar_SkyCitadel == true and migrated.world.altars.Altar_MonasteryGate == true)
local unkindled = Store.MigrateSouls(raw(function(s) s.world.altars.Altar_SkyCitadel = true; s.world.activeAltar = "Altar_SkyCitadel" end), nil)
check("unkindled successor falls back to the bonfire", ACTIVE and unkindled.world.activeAltar == "Altar_SanctuaryBonfire" or not ACTIVE)
check("migrated retired profile validates", Store.ValidateSouls(migrated))

-- 2. Stranded bloodstain.
local home = World.Altars.Altar_MonasteryGate.Placement
local function stained(x, y, z)
	return raw(function(s)
		s.world.altars.Altar_MonasteryGate = true
		s.world.activeAltar = "Altar_MonasteryGate"
		s.world.bloodstain = { region = "Gone", x = x, y = y, z = z, essence = 4321, death = 7 }
	end)
end
local inside = Store.MigrateSouls(stained(home.X, home.Y, home.Z), nil).world.bloodstain
check("stain inside an active region stays", inside.x == home.X and inside.z == home.Z and inside.essence == 4321)
local stranded = Store.MigrateSouls(stained(5000, 5000, 5000), nil)
local relocated = stranded.world.bloodstain
local spawn = World.Altars.Altar_MonasteryGate.Spawn
check("stranded stain relocates to the altar spawn", relocated.x == spawn.X and relocated.y == spawn.Y and relocated.z == spawn.Z)
check("stranded stain keeps its essence and death index", relocated.essence == 4321 and relocated.death == 7)
check("relocated stain lies in an active region", World.regionAt(relocated.x, relocated.y, relocated.z) ~= nil and Store.ValidateSouls(stranded))

-- 3. Caches (the two new ids exist only once the overworld is active).
local reloaded
if ACTIVE then
	local function claimBoth(i: any): any
		check("claim FrostWatchpost", (Inventory.claim(i, "FrostWatchpost")))
		check("claim SaltCaravan", (Inventory.claim(i, "SaltCaravan")))
		return i
	end
	local fresh = claimBoth(Inventory.defaults())
	check("fresh profile earns WindSlash and Thunderfall", fresh.spells.WindSlash == true and fresh.spells.Thunderfall == true)
	check("double claim grants once", (Inventory.claim(fresh, "FrostWatchpost")) == false and Inventory.validate(fresh))
	local owner = Inventory.defaults()
	owner.spells.WindSlash = true
	owner.spells.Thunderfall = true
	local spellsBefore = 0
	for _ in owner.spells do spellsBefore += 1 end
	claimBoth(owner)
	local spellsAfter = 0
	for _ in owner.spells do spellsAfter += 1 end
	check("owner of both spells gets no duplicate", spellsAfter == spellsBefore and owner.caches.FrostWatchpost == true)
	reloaded = Inventory.migrate(fresh)
	check("claimed new caches survive migrate and validate", reloaded.caches.FrostWatchpost and reloaded.caches.SaltCaravan and Inventory.validate(reloaded))
	for _, id in { "WaterfallAlcove", "SealedMausoleum", "FoundersKiln", "PagodaRafters", "FrostWatchpost", "SaltCaravan" } do
		local at, c = Overworld.Caches[id].Position, Catalog.Caches[id]
		check("cache " .. id .. " placed from Overworld", c.X == at.X and c.Y == at.Y and c.Z == at.Z and c.Region == Overworld.Caches[id].Region)
	end
	check("moved caches keep their rewards", Catalog.Caches.FoundersKiln.Materials.StarfallShard == 2 and Catalog.Caches.SealedMausoleum.Weapon == "Odachi")
else
	check("caches keep the old placement before the cutover", Catalog.Caches.WaterfallAlcove.Z == -840 and Catalog.Caches.FrostWatchpost == nil)
end
check("unknown cache ids are still dropped", Inventory.migrate({ caches = { NoSuchCache = true } }).caches.NoSuchCache == nil)

-- 4. Lore, miniboss, objectives.
if ACTIVE then
	for id, at in Overworld.Lore do
		local l = Narrative.Lore[id]
		check("lore " .. id .. " placed", l and l.X == at.Position.X and l.Y == at.Position.Y and l.Z == at.Position.Z and l.Qi > 0)
	end
	local hut
	for _, poi in Overworld.POIs do if poi.Id == "HermitHut" then hut = poi end end
	check("hermit moved to his hut", Narrative.NPCs.Hermit.X == hut.Position.X and Narrative.NPCs.Hermit.Z == hut.Position.Z)
	local warden
	for _, entry in World.Spawns do if entry.Id == "DM_Warden_Graves" then warden = entry end end
	local want = Overworld.Minibosses.HollowBellWarden.Placement
	check("warden spawn keeps id and mob, new ground", warden and warden.Mob == "HollowBellWarden" and warden.Placement.X == want.X and warden.Placement.Z == want.Z)
	check("warden reward flag unchanged", World.Mobs.HollowBellWarden.Reward.Flag == "HollowBellWarden")
	check("inactive bosses keep their definitions", World.Bosses.TwinSentinels ~= nil and World.Bosses.AzureWyrm ~= nil)
else
	check("lore keeps the old placement before the cutover", Narrative.Lore.Pillars.Z == -740)
end

-- 5. Discoveries.
local old = Store.MigrateSouls(raw(function(s) s.world.discoveries = nil end), nil)
check("old save without discoveries loads empty", type(old.world.discoveries) == "table" and next(old.world.discoveries) == nil and Store.ValidateSouls(old))
local kept = Store.MigrateSouls(raw(function(s) s.world.discoveries = { F3_Cave = true, B6_Camp = true } end), nil)
check("discoveries round-trip migrate", kept.world.discoveries.F3_Cave and kept.world.discoveries.B6_Camp)
check("bad discoveries are dropped, not loaded", next(Store.MigrateSouls(raw(function(s) s.world.discoveries = { ["bad id!"] = true } end), nil).world.discoveries) == nil)
local store = engine("persist")
assert(store:Load(41))
local ok, _, recorded = store:RecordDiscovery(41, "F3_Cave")
check("first discovery records", ok and recorded)
ok, _, recorded = store:RecordDiscovery(41, "F3_Cave")
check("repeat discovery is idempotent", ok and not recorded)
check("bad discovery id refused", not (store:RecordDiscovery(41, "bad id!")))
for n = 1, 600 do store:RecordDiscovery(41, "D" .. n) end
local count = 0
for _ in store:Souls(41).world.discoveries do count += 1 end
check("discoveries are capped like other world maps", count == 512 and Store.ValidateSouls(store:Souls(41)))

-- 6. Preservation across save, release and reload on another server.
store = engine("persist-a")
assert(store:Load(42))
assert(store:Transaction(42, function(p)
	p.routeFlags.Gate_Test = true
	p.inventory.LoreEntries.Pillars = true
	p.souls.world.minibosses.HollowBellWarden = true
	p.souls.world.bosses.GrandmasterShen = true
	p.souls.world.altars.Altar_SkyCitadel = true
	p.souls.world.altars.Altar_BellTerrace = true
	p.souls.world.activeAltar = "Altar_BellTerrace"
	p.souls.essence = 777
	Inventory.claim(p.souls.inventory, "WaterfallAlcove")
end))
assert(store:Release(42))
local other = engine("persist-b")
local loaded = assert(other:Load(42))
local s = loaded.souls
check("routeFlags preserved", loaded.routeFlags.Gate_Test == true)
check("lore preserved", loaded.inventory.LoreEntries.Pillars == true)
check("minibosses and bosses preserved", s.world.minibosses.HollowBellWarden and s.world.bosses.GrandmasterShen and loaded.defeatedBosses.GrandmasterShen)
check("retired and kept altars preserved", s.world.altars.Altar_SkyCitadel and s.world.altars.Altar_BellTerrace and loaded.unlockedAltars.Altar_SkyCitadel)
check("caches preserved", s.inventory.caches.WaterfallAlcove)
check("essence preserved in the inner and mirrored outer field", s.essence == 777 and loaded.qiEssence == 777)
check("no sovereign progress from migration", next(s.world.story) == nil and s.world.bosses.TwinSentinels == nil and s.world.bosses.AzureWyrm == nil)

print(string.format("persistence migration (%s): %d passed, %d failed", if ACTIVE then "Overworld.Active" else "legacy world", passed, failed))
if failed > 0 then error("persistence migration failed") end

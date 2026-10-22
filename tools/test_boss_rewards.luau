--!nonstrict
-- Lune regression for playtest findings #8 and #9 (batch 08): remembrance ownership is a token
-- object, every current sovereign has an authored weapon-or-spell choice at Gao, the retired Ash
-- Pagoda General id migrates to General Zhao's token, and transmutation is exactly-once through
-- the real ProfileStore transactions (defeat replay, competing recipes, release/rejoin).
-- Run from the project root: lune run tools/test_boss_rewards.luau
local fs = require("@lune/fs")
local Inventory = require("../src/simulation/ArsenalInventory")
local Catalog = require("../src/shared/ArsenalCatalog")
local Narrative = require("../src/shared/NarrativeCatalog")
local World = require("../src/shared/WorldDefinitions")
local Weapons = require("../src/simulation/WeaponSchema")
local Spells = require("../src/simulation/SpellSchema")
local Store = require("../src/server/ProfileStore")
local Profiles = require("../src/shared/ProfileSchema")

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- 1. Content: six sovereigns, each with one weapon and one spell; the 12-weapon registry is intact.
check("weapon registry still 12", #Weapons.WeaponKeys == 12)
local bossCount = 0
for id in World.Bosses do
	bossCount += 1
	check("live boss is a sovereign: " .. id, table.find(Narrative.Sovereigns, id) ~= nil)
end
check("exactly six live bosses", bossCount == 6 and World.Bosses.AshPagodaGeneral == nil and World.FogGates.Gate_AshPagoda == nil)
for _, boss in Narrative.Sovereigns do
	local kinds = {}
	for _, r in Catalog.Recipes do if r.Boss == boss then kinds[r.Kind] = (kinds[r.Kind] or 0) + 1 end end
	check(boss .. " offers one weapon and one spell", kinds.Weapon == 1 and kinds.Spell == 1)
	check(boss .. " is in the forge order", table.find(Catalog.TokenOrder, boss) ~= nil)
end
for id, r in Catalog.Recipes do
	check("recipe reward exists: " .. id, if r.Kind == "Weapon" then Weapons.Weapons[r.Reward] ~= nil else Spells.ById[r.Reward] ~= nil)
	check("recipe boss is current: " .. id, World.Bosses[r.Boss] ~= nil or r.Boss == "DemonicChimera")
	check("recipe has no obsolete boss: " .. id, r.Boss ~= "AshPagodaGeneral")
end
check("Shen's intentional double token kept", table.concat(Catalog.BossTokens.GrandmasterShen, ",") == "GrandmasterShen,DemonicChimera")
check("General's rewards now General Zhao's", Catalog.Recipes.HeavenPiercingGuandao.Boss == "TwinSentinels" and Catalog.Recipes.Thunderfall.Boss == "TwinSentinels")
check("legacy alias declared", Catalog.LegacyBosses.AshPagodaGeneral == "TwinSentinels")
check("no Ash Pagoda wording left in descriptions", not string.find(Catalog.WeaponUses.HeavenPiercingGuandao, "Ash Pagoda", 1, true))

-- 2. Ownership is the token object; a boolean is not a token (finding #8).
local i = Inventory.defaults(); i.weapons = { Unarmed = true, Jian = true }
check("unearned recipe is locked", Inventory.recipeState(i, "BaizeTessen") == "Locked")
Inventory.award(i, "VenerableBaize")
check("token object counts as owned", Inventory.owns(i, "VenerableBaize") and Inventory.recipeState(i, "BaizeTessen") == "Ready")
check("old UI test would have failed", i.remembrances.VenerableBaize ~= true)
local fake = Inventory.defaults(); fake.weapons = { Unarmed = true }; fake.remembrances.SovereignWu = true
check("boolean flag is not ownership", not Inventory.owns(fake, "SovereignWu") and Inventory.recipeState(fake, "WuSpellStaff") == "Locked")
check("boolean flag fails validation", not Inventory.validate(fake))
i.weapons.WarFan = true
check("owned reward points to the other gift", Inventory.recipeState(i, "BaizeTessen") == "Owned" and Inventory.recipeState(i, "BaizeWindSlash") == "Ready")
check("forging an owned reward refused", select(2, Inventory.forge(i, "BaizeTessen")) == "Already owned")
check("other gift forges", Inventory.forge(i, "BaizeWindSlash") and i.spells.WindSlash and Inventory.recipeState(i, "BaizeTessen") == "Spent")

-- 3. Exactly-once through real store transactions, for every sovereign.
local data: { [string]: any } = {}
local db = { UpdateAsync = function(_self: any, key: string, fn: (any) -> any): any
	local updated = fn(Store.Copy(data[key])); if updated then data[key] = Store.Copy(updated) end; return Store.Copy(updated)
end }
local function open(owner: string, now: number) return Store.new(db, Profiles, { owner = owner, now = function() return now end, wait = function() end, attempts = 1, leaseSeconds = 180 }) end
local store = open("rewards-a", 1000)
assert(store:Load(77))
for _, boss in Narrative.Sovereigns do
	check(boss .. " defeat commits", store:RecordBossDefeat(77, boss, World.Bosses[boss].Essence))
	local essence = store:Souls(77).essence
	local weapon, spell
	for id, r in Catalog.Recipes do if r.Boss == boss then if r.Kind == "Weapon" then weapon = id else spell = id end end end
	check(boss .. " forge commits", store:Transaction(77, function(p) assert(Inventory.forge(p.souls.inventory, spell)) end))
	check(boss .. " competing recipe rejected", not store:Transaction(77, function(p) assert(Inventory.forge(p.souls.inventory, weapon)) end))
	check(boss .. " replayed defeat grants nothing", store:RecordBossDefeat(77, boss, World.Bosses[boss].Essence) and store:Souls(77).essence == essence)
	local inv = store:Souls(77).inventory
	check(boss .. " still spent after replay", Inventory.recipeState(inv, weapon) == "Spent" and not Inventory.forge(Store.Copy(inv), weapon))
	check(boss .. " spell granted once", inv.spells[Catalog.Recipes[spell].Reward] == true)
end
check("Chimera token from Shen still forgeable", Inventory.recipeState(store:Souls(77).inventory, "CalamityBoneCleaver") == "Ready")
check("store validates", Store.ValidateSouls(store:Souls(77)))
assert(store:Release(77))
local rejoined = open("rewards-b", 2000)
local back = assert(rejoined:Load(77)).souls.inventory
for _, boss in Narrative.Sovereigns do check(boss .. " spent survives rejoin", back.spentRemembrances[boss] == true and Inventory.owns(back, boss)) end
assert(rejoined:Release(77))

-- 4. Retired Ash Pagoda General: old tokens, spent flags and defeat records migrate.
local function legacy(id: number, spent: boolean)
	local s = open("legacy-seed", 3000); assert(s:Load(id)); assert(s:Release(id))
	local souls = data["Player_" .. id].profile.souls
	souls.inventory.remembrances.AshPagodaGeneral = { Id = "BossRemembrance_AshPagodaGeneral", Kind = "BossRemembrance", Boss = "AshPagodaGeneral" }
	if spent then souls.inventory.spentRemembrances.AshPagodaGeneral = true; souls.inventory.weapons.HeavenPiercingGuandao = true end
	souls.world.bosses.AshPagodaGeneral = true
	check("seeded legacy record is accepted as stored data", Inventory.validate(souls.inventory))
	local loaded = open("legacy-load", 4000)
	local p = loaded:Load(id)
	return loaded, p
end
local l1, p1 = legacy(501, true)
check("legacy profile loads", p1 ~= nil)
local inv1 = p1.souls.inventory
check("legacy token re-keyed to General Zhao", Inventory.owns(inv1, "TwinSentinels") and inv1.remembrances.AshPagodaGeneral == nil)
check("legacy spent flag keeps the right consumed", inv1.spentRemembrances.TwinSentinels == true and Inventory.recipeState(inv1, "Thunderfall") == "Spent")
check("legacy forged weapon kept", inv1.weapons.HeavenPiercingGuandao == true)
check("later Twins victory cannot renew", l1:RecordBossDefeat(501, "TwinSentinels", 4000) and l1:Souls(501).inventory.spentRemembrances.TwinSentinels == true)
check("migrated record validates", Store.ValidateSouls(l1:Souls(501)))
local l2, p2 = legacy(502, false)
check("unspent legacy token forges exactly once", Inventory.recipeState(p2.souls.inventory, "HeavenPiercingGuandao") == "Ready"
	and l2:Transaction(502, function(p) assert(Inventory.forge(p.souls.inventory, "HeavenPiercingGuandao")) end)
	and not l2:Transaction(502, function(p) assert(Inventory.forge(p.souls.inventory, "Thunderfall")) end))
local onlyDefeat = Inventory.defaults(); Inventory.award(onlyDefeat, "AshPagodaGeneral")
check("legacy defeat record awards the canonical token", Inventory.owns(onlyDefeat, "TwinSentinels") and onlyDefeat.remembrances.AshPagodaGeneral == nil)

-- 5. UI uses the shared rule.
local tabs = fs.readFile("src/client/Controllers/ArsenalTabs.luau")
check("forge tab reads recipeState", string.find(tabs, "Inventory.recipeState(inv, id)", 1, true) ~= nil)
check("no boolean token comparison", not string.find(tabs, "remembrances%[.-%] == true"))
local _, lines = string.gsub(tabs, "\n", "")
check("ArsenalTabs strict and under 150 lines", string.sub(tabs, 1, 9) == "--!strict" and lines < 150)

print(string.format("boss rewards: %d passed, %d failed", passed, failed))
if failed > 0 then error("boss rewards regression failed") end

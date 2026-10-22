--!nonstrict
-- Batch 23: seeded campaign ledger across the repaired seams. One fresh profile is driven through the
-- whole solo campaign as server state on the real ProfileStore/ProfileSchema transactions (with a
-- double-invoking mock DataStore), releasing and reloading the profile after each milestone, while the
-- real Objectives resolver, EndingRules, ArsenalInventory forge/claim, ProgressionRules and CodexView
-- read that state. It checks the joins between batches (altar ids/regions/objective targets, encounter
-- targets against the authored arena mouths, rewards and the ending). Seeded flags and direct store
-- calls: this is integration evidence for state and guidance, NOT an earned playthrough.
-- Run: lune run tools/test_campaign_ledger.luau  (locally: python3 tools/lune_compat.py tools/test_campaign_ledger.luau)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Store = require("../src/server/ProfileStore")
local Schema = require("../src/shared/ProfileSchema")
local World = require("../src/shared/WorldDefinitions")
local Narrative = require("../src/shared/NarrativeCatalog")
local Arsenal = require("../src/shared/ArsenalCatalog")
local Inventory = require("../src/simulation/ArsenalInventory")
local Progress = require("../src/shared/ProgressionRules")
local Campaign = require("../src/shared/CampaignZones")
local V3 = roblox.Vector3

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function load(path: string, env: { [string]: any }): any
	env.Vector3, env.table, env.math, env.string, env.type, env.require = V3, table, math, string, type, function(m) return m end
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local Ending = load("src/shared/EndingRules.luau", {})
local Objectives = load("src/shared/Objectives.luau", { script = { Parent = { EndingRules = Ending } } })
local Codex = load("src/client/Controllers/CodexView.luau", { game = { GetService = function() return { AsurasPath = { Shared = {
	NarrativeCatalog = Narrative, WorldDefinitions = World, InputMap = require("../src/shared/InputMap"), EndingRules = Ending } } } end } })

-- A DataStore whose UpdateAsync runs the callback twice (retry) and keeps only the second result.
local db = {}
local store = { UpdateAsync = function(_, key, fn)
	fn(Store.Copy(db[key]))
	local result = fn(Store.Copy(db[key]))
	if result ~= nil then db[key] = Store.Copy(result) end
	return Store.Copy(result)
end }
local clock = 1000
local engine = Store.new(store, Schema, { owner = "Ledger", now = function() return clock end, wait = function() end, attempts = 2, leaseSeconds = 180 })
local ID = 4242
assert(engine:Load(ID))
local function rejoin(label: string)
	local before = Store.Copy(engine:Get(ID))
	assert(engine:Release(ID)); clock += 5; assert(engine:Load(ID))
	local after = engine:Get(ID)
	local same = after.qiEssence == before.qiEssence and after.souls.world.activeAltar == before.souls.world.activeAltar
	for _, key in { "defeatedBosses", "unlockedAltars" } do for k in before[key] do same = same and after[key][k] == true end end
	for k in before.inventory.LoreEntries do same = same and after.inventory.LoreEntries[k] == true end
	for k in before.souls.inventory.weapons do same = same and after.souls.inventory.weapons[k] == true end
	for k in before.souls.inventory.caches do same = same and after.souls.inventory.caches[k] == true end
	for k in before.souls.world.story or {} do same = same and after.souls.world.story[k] == true end
	check("rejoin keeps progress: " .. label, same)
end
local function profile() return engine:Get(ID) end
local function facts(region: string?, overrides: any?): any
	local p = profile()
	local f = { Region = region, Bosses = table.clone(p.defeatedBosses), Altars = table.clone(p.unlockedAltars), InBoss = false, InColosseum = false,
		BossFelled = p.defeatedBosses.GrandmasterShen == true, Rested = true, Story = table.clone(p.souls.world.story or {}),
		Bloodstain = if p.souls.world.bloodstain then V3.new(p.souls.world.bloodstain.x, p.souls.world.bloodstain.y, p.souls.world.bloodstain.z) else nil }
	for k, v in overrides or {} do f[k] = v end
	return f
end

-- 1. Data joins between batches.
local altarOrder = { "Altar_SanctuaryBonfire", "Altar_MonasteryGate", "Altar_DesecratedCloister", "Altar_BambooShrine",
	"Altar_ColosseumAntechamber", "Altar_SanctuaryDepths", "Altar_CelestialPagoda", "Altar_SkyCitadel" }
local altarCount = 0
for _ in World.Altars do altarCount += 1 end
check("ledger covers every authored altar", altarCount == #altarOrder)
for _, id in altarOrder do
	local a = World.Altars[id]
	check(id .. " exists", a ~= nil)
	if a then
		check(id .. ": objective region matches the altar's region", Objectives.regionOf(id) == a.Region)
		local b = World.Regions[a.Region] and World.Regions[a.Region].Bounds
		local s = a.Spawn
		check(id .. ": travel spawn lies inside its region", b ~= nil and math.abs(s.X - b.Center.X) <= b.Size.X / 2 and math.abs(s.Z - b.Center.Z) <= b.Size.Z / 2)
	end
end
for _, e in Objectives.Encounters do
	check(e.Id .. " is a live sovereign", World.Bosses[e.Id] ~= nil and table.find(Narrative.Sovereigns, e.Id) ~= nil)
	local mouth = Campaign.mark(e.Region, "ArenaMouth")
	if mouth then
		check(e.Id .. ": objective target is the authored arena mouth", math.abs(mouth.X - e.Position.X) < 1 and math.abs(mouth.Z - e.Position.Z) < 1)
	end
end
check("six encounters, one per sovereign", #Objectives.Encounters == #Narrative.Sovereigns)

-- 2. Fresh profile and the altar route (rest sets the checkpoint, refills, survives rejoin).
local p0 = profile()
check("fresh: bonfire kindled and active, no story choice", p0.souls.world.activeAltar == "Altar_SanctuaryBonfire" and next(p0.souls.world.story) == nil)
local first = Objectives.resolve(facts("Sanctuary", { Rested = false }))
check("fresh: first objective is the bonfire rest", first and first.Key == "FirstRest")
for i, id in altarOrder do
	assert(engine:ActivateAltar(ID, id, true, true))
	check(id .. " becomes the active checkpoint", profile().souls.world.activeAltar == id and profile().unlockedAltars[id])
	if i == 3 or i == #altarOrder then rejoin("after " .. id) end
end

-- 3. Later-checkpoint death, bloodstain recovery and the double-death stake.
assert(engine:Transaction(ID, function(p) p.qiEssence = 500 end))
local _, _, dropped = engine:RecordDeath(ID, "CelestialPagoda", -46, 3, -2268, 120)
check("death drops banked and carried Essence into one bloodstain", dropped == 620 and profile().qiEssence == 0 and profile().souls.world.bloodstain.essence == 620)
check("death keeps the later altar as the checkpoint", profile().souls.world.activeAltar == "Altar_SkyCitadel")
local stained = Objectives.resolve(facts("CelestialPagoda"))
check("the bloodstain is the objective after a death", stained and stained.Key == "Bloodstain")
rejoin("with a bloodstain")
local _, _, back = engine:RecoverBloodstain(ID, profile().souls.deaths)
check("recovering the stain returns it once", back == 620 and profile().qiEssence == 620 and profile().souls.world.bloodstain == nil)
check("a second recovery of the same stain is refused", not engine:RecoverBloodstain(ID, profile().souls.deaths))
engine:RecordDeath(ID, "CelestialPagoda", -40, 3, -2260, 0)
engine:RecordDeath(ID, "CelestialPagoda", -30, 3, -2250, 0)
check("dying again before recovery forfeits the earlier stain", profile().souls.world.bloodstain == nil and profile().qiEssence == 0)

-- 4. Six sovereigns in route order: objective, remembrance, materials once, rejoin.
for index, e in Objectives.Encounters do
	local before = Objectives.resolve(facts(e.Region))
	check(e.Id .. " is the objective in its region", before and before.Key == "Boss:" .. e.Id)
	assert(engine:RecordBossDefeat(ID, e.Id, 1000))
	local ore = profile().inventory.Materials.SpiritIronOre
	assert(engine:RecordBossDefeat(ID, e.Id, 1000)) -- replayed defeat delivery
	check(e.Id .. ": a replayed defeat grants nothing twice", profile().inventory.Materials.SpiritIronOre == ore)
	check(e.Id .. ": remembrance owned", Inventory.owns(profile().souls.inventory, e.Id) and profile().defeatedBosses[e.Id])
	if index == 3 or index == 6 then rejoin("after " .. e.Id) end
end
check("Shen also yields the Chimera remembrance", Inventory.owns(profile().souls.inventory, "DemonicChimera"))

-- 5. Gao: one weapon and one spell remembrance forged exactly once; reinforce and infuse.
local function forge(recipe: string): boolean
	local ok = engine:Transaction(ID, function(p) assert(Inventory.forge(p.souls.inventory, recipe)) end)
	return ok
end
check("forge a sovereign weapon", forge("TitanOdachi") and profile().souls.inventory.weapons.Odachi)
check("the same remembrance cannot forge its other reward", not forge("TitanGraveTendrils"))
check("forge a sovereign spell", forge("WuBlackflameSurge") and profile().souls.inventory.spells.BlackflameSurge)
assert(engine:Transaction(ID, function(p) p.qiEssence = 5000; p.inventory.Materials.CrimsonFireGem = 1 end))
check("reinforce the wielded weapon", engine:Transaction(ID, function(p) Progress.upgrade(p, p.equippedLoadout.MainWeapon) end) and profile().inventory.Weapons.Jian.Level == 1)
check("infuse it", engine:Transaction(ID, function(p) Progress.infuse(p, p.equippedLoadout.MainWeapon, "CrimsonFire") end) and profile().inventory.Weapons.Jian.Infusion == "CrimsonFire")
rejoin("after forging")
check("forged items and spent remembrances survive rejoin", profile().souls.inventory.weapons.Odachi and profile().souls.inventory.spentRemembrances.SlumberingTitan)

-- 6. All eight inscriptions and all five caches, each once.
local qi = profile().qiEssence
for _, id in Narrative.LoreOrder do
	assert(engine:Transaction(ID, function(p) Progress.discover(p, id, Narrative.Lore[id].Qi) end))
	assert(engine:Transaction(ID, function(p) Progress.discover(p, id, Narrative.Lore[id].Qi) end))
end
local expected = qi
for _, id in Narrative.LoreOrder do expected += Narrative.Lore[id].Qi end
check("eight inscriptions recorded, each paying once", profile().qiEssence == expected)
local cacheCount = 0
for id, c in Arsenal.Caches do
	cacheCount += 1
	check(id .. " claims once", engine:Transaction(ID, function(p) assert(Inventory.claim(p.souls.inventory, id)) end)
		and not engine:Transaction(ID, function(p) assert(Inventory.claim(p.souls.inventory, id)) end) and profile().souls.inventory.weapons[c.Weapon])
end
check("five caches", cacheCount == 5)
rejoin("after collectibles")
local codex = Codex.summary({ inventory = profile().inventory, bosses = profile().defeatedBosses, story = profile().souls.world.story })
check("Codex: 8/8 inscriptions and 6/6 sovereigns", codex.Found == 8 and codex.Rested == 6)

-- 7. The ending: home to Lin, the choice, postgame; flags survive rejoin and grant nothing.
local home = Objectives.resolve(facts("SkyCitadel"))
check("after six the citadel objective leads home through the bastion portal", home and home.Key == "Ending:Return" and home.Target.Kind == "Point")
local bank = profile().qiEssence
check("cross recorded in person", engine:Transaction(ID, function(p)
	local s = p.souls.world.story
	assert(Ending.decide(s, Ending.stage(p.defeatedBosses, s), "Cross", false))
end))
check("crossing grants nothing", profile().qiEssence == bank)
rejoin("after crossing")
local post = Objectives.resolve(facts("Sanctuary"))
check("postgame objective after crossing (PvP optional)", post and post.Key == "Postgame")
check("Codex records the crossing", string.find(Codex.summary({ inventory = profile().inventory, bosses = profile().defeatedBosses, story = profile().souls.world.story }).Crossing, "made", 1, true) ~= nil)

print(string.format("campaign ledger: %d passed, %d failed (seeded state, not earned play)", passed, failed))
if failed > 0 then error("campaign ledger regression failed") end

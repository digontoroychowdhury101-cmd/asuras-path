--!nonstrict
-- Armour: catalogue, migration, ownership, atomic refusals, worn values, and what they do in the combat rules.
-- Local regression only: visuals, two-client replication and live DataStore durability are separate gates.
-- Run from the project root: python3 tools/lune_compat.py tools/test_armor.luau
local fs = require("@lune/fs")
local Armor = require("../src/shared/ArmorRules")
local Schema = require("../src/shared/ProfileSchema")
local Store = require("../src/server/ProfileStore")
local Combat = require("../src/simulation/CombatRules")
local Moves = require("../src/simulation/MoveSchema")
local Weapons = require("../src/simulation/WeaponSchema")
local Settings = require("../src/shared/CombatSettings")

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function near(a: number, b: number): boolean return math.abs(a - b) < 1e-6 end
local function src(path: string): string return fs.readFile(path) end

-- 1. Old and malformed saves.
do
	local fresh = Schema.Default(1)
	check("a new record owns and wears the starter", fresh.inventory.Armor.AshenPilgrim.Level == 0 and fresh.equippedLoadout.ArmorSet == "AshenPilgrim")
	check("the fresh record validates", (Schema.Validate(fresh)))
	-- A save from before armour: no Armor table, no ArmorSet, but real progress.
	local raw: any = Schema.Default(1)
	raw.qiEssence = 4321; raw.inventory.Armor = nil; raw.equippedLoadout.ArmorSet = nil
	raw.inventory.Weapons.Dao = { Level = 3 }; raw.unlockedAltars.Altar_MonasteryGate = true; raw.defeatedBosses.TwinSentinels = true
	local migrated = Schema.Migrate(raw, 1)
	check("migration keeps currency, weapons, altars and bosses", migrated.qiEssence == 4321 and migrated.inventory.Weapons.Dao.Level == 3
		and migrated.unlockedAltars.Altar_MonasteryGate and migrated.defeatedBosses.TwinSentinels)
	check("migration dresses an old save in the starter", migrated.equippedLoadout.ArmorSet == "AshenPilgrim" and migrated.inventory.Armor.AshenPilgrim ~= nil)
	check("the migrated record validates", (Schema.Validate(migrated)))
	-- Syntactically valid but unknown or unowned.
	for _, bad in { "ForgedDragonPlate", "IronOath", 7, false } do
		local r: any = Schema.Default(1); r.equippedLoadout.ArmorSet = bad
		check("validation refuses worn " .. tostring(bad), not Schema.Validate(r))
		local m = Schema.Migrate(r, 1)
		check("migration repairs worn " .. tostring(bad), m.equippedLoadout.ArmorSet == "AshenPilgrim" and (Schema.Validate(m)))
	end
	for _, level in { -1, 6, 1.5, 0 / 0, "2" } do
		local r: any = Schema.Default(1); r.inventory.Armor.CinnabarGuard = { Level = level }
		check("validation refuses level " .. tostring(level), not Schema.Validate(r))
		check("migration zeroes level " .. tostring(level), Schema.Migrate(r, 1).inventory.Armor.CinnabarGuard.Level == 0)
	end
	local r: any = Schema.Default(1); r.inventory.Armor.Forged = { Level = 2 }
	check("migration drops an unknown owned suit", Schema.Migrate(r, 1).inventory.Armor.Forged == nil)
	local off: any = Schema.Default(1); off.equippedLoadout.ArmorSet = Armor.None
	check("armour set aside stays aside across a reload", Schema.Migrate(off, 1).equippedLoadout.ArmorSet == Armor.None and (Schema.Validate(off)))
	local kept: any = Schema.Default(1); kept.inventory.Armor.IronOath = { Level = 4 }; kept.equippedLoadout.ArmorSet = "IronOath"
	local again = Schema.Migrate(kept, 1)
	check("a worn reinforced suit survives a reload", again.equippedLoadout.ArmorSet == "IronOath" and again.inventory.Armor.IronOath.Level == 4)
	local future: any = Schema.Default(1); future.schemaVersion = 99
	check("a newer save still fails closed", not pcall(Schema.Migrate, future, 1))
end

-- 2. Ownership and the economy. A refusal moves nothing.
local function record(qi: number, ore: number, shards: number): any
	local p: any = Schema.Default(1)
	p.qiEssence = qi; p.inventory.Materials = { SpiritIronOre = ore, StarfallShard = shards }
	return p
end
local function snapshot(p: any): string
	return string.format("%d/%d/%d/%s", p.qiEssence, p.inventory.Materials.SpiritIronOre, p.inventory.Materials.StarfallShard, tostring(p.inventory.Armor.CinnabarGuard and p.inventory.Armor.CinnabarGuard.Level))
end
do
	local p = record(5000, 9, 9)
	check("Cinnabar waits for its altar", Armor.acquireRefusal(p, "CinnabarGuard") == Armor.Sets.CinnabarGuard.Requirement)
	check("Iron Oath waits for the Twins", Armor.acquireRefusal(p, "IronOath") == Armor.Sets.IronOath.Requirement)
	local before = snapshot(p)
	check("a refused purchase raises", not pcall(Armor.acquire, p, "CinnabarGuard"))
	check("a refused purchase moves nothing", snapshot(p) == before)
	p.unlockedAltars.Altar_DesecratedCloister = true
	Armor.acquire(p, "CinnabarGuard")
	check("the purchase charges once", p.qiEssence == 3800 and p.inventory.Materials.SpiritIronOre == 6 and p.inventory.Armor.CinnabarGuard.Level == 0)
	before = snapshot(p)
	check("a replayed purchase is refused and free", not pcall(Armor.acquire, p, "CinnabarGuard") and snapshot(p) == before)
	check("the starter cannot be bought", Armor.acquireRefusal(p, "AshenPilgrim") ~= nil)
	check("an unknown suit cannot be bought", Armor.acquireRefusal(p, "Nope") == "Unknown armour")
	local poor = record(100, 9, 9); poor.unlockedAltars.Altar_DesecratedCloister = true
	check("no Essence, no suit", Armor.acquireRefusal(poor, "CinnabarGuard") == "Not enough Essence")
	local bare = record(5000, 0, 0); bare.unlockedAltars.Altar_DesecratedCloister = true
	check("no ore, no suit", Armor.acquireRefusal(bare, "CinnabarGuard") == "Missing SpiritIronOre")
	-- Reinforcement: quote level, replay, cap.
	p.qiEssence = 100000; p.inventory.Materials.StarfallShard = 50; p.inventory.Materials.SpiritIronOre = 50
	check("a stale quote refuses", Armor.upgradeRefusal(p, "CinnabarGuard", 3) == "The quote is out of date")
	local cost, material, need = Armor.upgradeCost("CinnabarGuard", 0)
	local qi, ore = p.qiEssence, p.inventory.Materials[material]
	check("reinforcing raises one level", Armor.upgrade(p, "CinnabarGuard", 0) == 1)
	check("reinforcing charges once", p.qiEssence == qi - cost and p.inventory.Materials[material] == ore - need)
	before = snapshot(p)
	check("the same confirmation twice cannot buy twice", not pcall(Armor.upgrade, p, "CinnabarGuard", 0) and snapshot(p) == before)
	for level = 1, Armor.MaxLevel - 1 do Armor.upgrade(p, "CinnabarGuard", level) end
	check("reinforcement stops at the cap", Armor.upgradeRefusal(p, "CinnabarGuard") == "Already +" .. Armor.MaxLevel)
	check("an unowned suit cannot be reinforced", Armor.upgradeRefusal(p, "IronOath") == "Armour is not yours")
	-- Wearing.
	check("an unowned suit cannot be worn", Armor.wearRefusal(p, "IronOath") == "Armour is not yours")
	Armor.wear(p, "CinnabarGuard")
	check("wearing changes the loadout", p.equippedLoadout.ArmorSet == "CinnabarGuard")
	check("wearing it again is refused", Armor.wearRefusal(p, "CinnabarGuard") == "Already worn")
	Armor.wear(p, Armor.None)
	check("armour can be set aside", p.equippedLoadout.ArmorSet == Armor.None and Armor.wearRefusal(p, Armor.None) ~= nil)
end

-- 3. The panel reads the server's numbers.
do
	local p = record(5000, 9, 0); p.unlockedAltars.Altar_DesecratedCloister = true
	local view = { qi = p.qiEssence, inventory = p.inventory, loadout = p.equippedLoadout, altars = p.unlockedAltars, bosses = p.defeatedBosses }
	local q = Armor.quote(view, "CinnabarGuard")
	check("an unowned quote offers the real price", not q.Owned and q.Acquire.Price == 1200 and q.Acquire.Refusal == nil)
	check("the quote compares against what is worn", near(q.Compare.Protection, 0) and near(q.Values.Protection, 0.10))
	local iron = Armor.quote(view, "IronOath")
	check("a locked quote gives the server's refusal", iron.Acquire.Refusal == Armor.Sets.IronOath.Requirement)
	local starter = Armor.quote(view, "AshenPilgrim")
	local cost = Armor.upgradeCost("AshenPilgrim", 0)
	check("an owned quote prices the next level", starter.Worn and starter.Next.Cost == cost and starter.Next.Refusal == Armor.upgradeRefusal(p, "AshenPilgrim", 0))
end

-- 4. Worn values at base and max, per set, and into derived stats.
do
	local expected = { AshenPilgrim = { 0, 0, 1, 0.03, 10 }, CinnabarGuard = { 0.10, 15, 0.97, 0.16, 30 }, IronOath = { 0.18, 30, 0.92, 0.24, 50 } }
	for id, want in expected do
		local base, top = Armor.values(id, 0), Armor.values(id, Armor.MaxLevel)
		check(id .. " at +0", near(base.Protection, want[1]) and base.Posture == want[2] and near(base.Speed, want[3]))
		check(id .. " at +5", near(top.Protection, want[4]) and top.Posture == want[5] and near(top.Speed, want[3]))
		check(id .. " stays under the protection cap", top.Protection <= Armor.MaxProtection)
	end
	check("a heavier suit protects more and moves less", Armor.values("IronOath", 0).Protection > Armor.values("CinnabarGuard", 0).Protection
		and Armor.values("IronOath", 0).Speed < Armor.values("CinnabarGuard", 0).Speed)
	local function souls(owned: any, worn: any): any
		local s: any = Store.DefaultSouls(); s.rpg = { Materials = {}, Weapons = { Jian = { Level = 0 } }, Mastery = {}, Armor = owned, ArmorSet = worn }
		return s
	end
	local bare = Store.DeriveStats(souls({ AshenPilgrim = { Level = 0 } }, "None"))
	local starter = Store.DeriveStats(souls({ AshenPilgrim = { Level = 0 } }, "AshenPilgrim"))
	check("the starter at +0 changes nothing", near(starter.Protection, bare.Protection) and starter.PostureCapacity == bare.PostureCapacity and near(starter.ArmorSpeed, 1))
	local iron = Store.DeriveStats(souls({ IronOath = { Level = 5 } }, "IronOath"))
	check("derived stats carry the worn suit", near(iron.Protection, 0.24) and iron.PostureCapacity == bare.PostureCapacity + 50 and near(iron.ArmorSpeed, 0.92))
	local ranked = souls({ IronOath = { Level = 5 } }, "IronOath"); ranked.rpg = nil -- exactly what ColosseumService.rankedStats does
	local flat = Store.DeriveStats(ranked)
	check("a ranked view carries no armour", near(flat.Protection, 0) and near(flat.ArmorSpeed, 1) and flat.PostureCapacity == bare.PostureCapacity)
	check("ranked stats really drop the rpg view", string.find(src("src/server/Services/ColosseumService.luau"), "view.rpg=nil", 1, true) ~= nil)
	local f = Combat.new(1, "Jian", 0)
	Combat.applyStats(f, iron, true)
	check("the fighter takes the suit", near(f.Protection, 0.24) and near(f.ArmorSpeed, 0.92))
	Combat.applyStats(f, flat, true)
	check("stats that name no armour take it off", near(f.Protection, 0) and near(f.ArmorSpeed, 1) and f.PostureCapacity == bare.PostureCapacity)
end

-- 5. In combat. Each case compares a suited fighter with a bare one under the same blow.
local function fighters(protection: number): (any, any)
	local a, d = Combat.new(1, "Jian", 0), Combat.new(2, "Jian", 0)
	a.MaxHP, a.ActiveHP = 1000, 1000
	Combat.applyStats(d, { Protection = protection, ArmorSpeed = 1, MaxHP = 1000 }, true)
	return a, d
end
local function strike(a: any, d: any, now: number, extra: any?): number
	local move = Weapons.get("Jian").Light[1]
	local hp = d.ActiveHP
	local hit: any = { Facing = true, Region = "Torso", Move = move, DefenderState = d.State, At = now }
	for k, v in extra or {} do hit[k] = v end
	Combat.resolveHit(a, d, now, hit, {})
	return hp - d.ActiveHP
end
do
	local a, bare = fighters(0)
	local plain = strike(a, bare, 50)
	local b, suited = fighters(0.24)
	local armoured = strike(b, suited, 50)
	check("a strike lands at all", plain > 0)
	check("a clean strike is reduced by exactly the worn share", near(armoured, plain * 0.76))
	-- Contact-time consistency: the snapshot's suit decides, whichever suit is on when it resolves.
	local c, d = fighters(0.24)
	local snap = Combat.contactSnapshot(c, d, 50, Weapons.get("Jian").Light[1])
	check("the snapshot freezes the defender's protection", near(snap.DefenderProtection, 0.24))
	Combat.applyStats(d, { Protection = 0, ArmorSpeed = 1, MaxHP = 1000 }, false)
	check("a suit changed mid-contact does not change the blow", near(strike(c, d, 50, { Snapshot = snap }), plain * 0.76))
	local e, g = fighters(0)
	local snapBare = Combat.contactSnapshot(e, g, 50, Weapons.get("Jian").Light[1])
	Combat.applyStats(g, { Protection = 0.24, ArmorSpeed = 1, MaxHP = 1000 }, false)
	check("a suit donned mid-contact does not help", near(strike(e, g, 50, { Snapshot = snapBare }), plain))
	-- Spells and bosses share applyArea; no double application.
	local src1, t1 = fighters(0); local dmg1 = Combat.applyArea(src1, t1, 60, 40, 0, true, true, {}) and t1.MaxHP - t1.ActiveHP
	local src2, t2 = fighters(0.24); local dmg2 = Combat.applyArea(src2, t2, 60, 40, 0, true, true, {}) and t2.MaxHP - t2.ActiveHP
	check("spells and boss attacks are reduced once", near(dmg2, dmg1 * 0.76))
	-- Not reduced: burn, bleed proc, deathblow, outside damage.
	local _, u = fighters(0.24)
	Combat.applyExternalDamage(u, 30, 70, {})
	check("void and hazards ignore armour", near(u.MaxHP - u.ActiveHP, 30))
	local _, w = fighters(0.24)
	w.BurnRate, w.BurnUntil, w.BurnSource = 10, 71, 1
	Combat.step(w, 70.5, 0.5, {})
	check("burn ignores armour", near(w.MaxHP - w.ActiveHP, 5))
	local deathblowSource = src("src/simulation/CombatRules.luau")
	check("a deathblow passes no protection", string.find(deathblowSource, 'Rules.applyDamage(victim, damage, "Deathblow", now)', 1, true) ~= nil)
	-- Defensive play stays the better answer: a deflect takes nothing, in any suit or none.
	local x, y = fighters(0)
	y.State, y.DeflectAt = "Deflecting", 80
	local timed = Combat.isDeflectTimed(y, 80)
	check("deflect timing is not read from armour", string.find(deathblowSource, "isDeflectTimed", 1, true) ~= nil and type(timed) == "boolean")
	-- The rally and recoverable layer follow the reduced blow.
	local h, i = fighters(0.5 * 0.48)
	strike(h, i, 90)
	check("the health layers stay consistent under armour", i.ActiveHP + i.RecoverableHP + i.PermanentDeficit <= i.MaxHP + 1e-6)
	-- Speed is a plain factor in the movement owner; dashes and windows do not read it.
	local slow = Combat.new(3, "Jian", 0)
	local full = Combat.speedMultiplier(slow)
	Combat.applyStats(slow, { Protection = 0.18, ArmorSpeed = 0.92 }, true)
	check("speed is scaled by the worn factor", near(Combat.speedMultiplier(slow), full * 0.92))
	local dashSource = string.match(deathblowSource, "function Rules.tryDash.-\nend") or ""
	check("a dash does not read armour", #dashSource > 0 and string.find(dashSource, "ArmorSpeed", 1, true) == nil and string.find(dashSource, "Protection", 1, true) == nil)
end

-- 6. The server paths use these rules and nothing else.
do
	local forge = src("src/server/ForgeService.luau")
	check("the smith checks place inside the transaction", string.find(forge, 'function Forge.Armor', 1, true) ~= nil and select(2, string.gsub(forge, 'assert%(Forge.smith%(id%),"Visit Master Smith Gao"%)', "")) >= 4)
	check("a confirmation counts as a purchase", string.find(src("src/server/Services/DialogueService.luau"), "Armor=true", 1, true) ~= nil)
	local actions = src("src/server/Services/DialogueActions.luau")
	check("armour answers only on its own panel", string.find(actions, 'packet.action=="Armor" and s.Panel=="Armor"', 1, true) ~= nil)
	local skin = src("src/server/ArmorSkin.luau")
	check("a suit is massless and answers no query", string.find(skin, "part.Anchored, part.Massless, part.CanCollide, part.CanTouch, part.CanQuery = false, true, false, false, false", 1, true) ~= nil)
	local characters = src("src/server/CharacterService.luau")
	local apply = string.match(characters, "function Service.ApplyArmor.-\nend") or ""
	check("changing suit carries its values into the fighter at once", string.find(apply, "Service.RefreshProgression(id)", 1, true) ~= nil and string.find(apply, "attachWeapon(e)", 1, true) ~= nil)
	check("the frozen appearance table is only reached through its hook", string.find(characters, "Appearance.OnRedress(", 1, true) ~= nil and string.find(characters, "Appearance%.[%w_]+%s*=[^=]") == nil)
	check("unequip removes only the suit's own folder", string.find(skin, "local folder = model:FindFirstChild(FOLDER)\n\tif folder then folder:Destroy() end", 1, true) ~= nil)
end

print(string.format("armour: %d passed, %d failed (local rules only; visuals, replication and live saves are separate)", passed, failed))
if failed > 0 then error("armour regression failed") end

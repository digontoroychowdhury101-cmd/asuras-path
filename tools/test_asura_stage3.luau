--!nonstrict
-- Local Luau runner; no Explorer location. Stage 3 (Asura's Path) world manifest, Souls profile
-- progression and the combat extensions used by bosses and elixirs.
local World = require("../src/shared/WorldDefinitions")
local Schema = require("../src/shared/ProfileSchema")
local Store = require("../src/server/ProfileStore")
local Combat = require("../src/simulation/CombatRules")
local Weapons = require("../src/simulation/WeaponSchema")
local Settings = require("../src/shared/CombatSettings")

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-------------------------------------------------------------------------------------------------
-- World manifest
-------------------------------------------------------------------------------------------------
assert(World.Regions.DesecratedMonastery and World.Regions.BambooPass and World.Regions.AshColosseum)
assert(World.regionAt(0, 3, -900) == "DesecratedMonastery" and World.regionAt(0, 3, -1400) == "BambooPass")
assert(World.regionAt(0, 3, -1960) == "AshColosseum" and World.regionAt(0, 3, 0) == nil)
assert(World.startingAltar().Id == "Altar_SanctuaryBonfire")
assert(World.Regions.Sanctuary.Altars.SanctuaryBonfire == World.Altars.Altar_SanctuaryBonfire)
assert(World.Regions.DesecratedMonastery.Altars.MonasteryGate.Id == World.Sanctuary.PortalDestination)
local origin = World.Sanctuary.Origin
assert(World.regionAt(origin.X, origin.Y + 3, origin.Z) == "Sanctuary")
assert(World.RegionOrder[1] == "Sanctuary" and not World.Altars.Altar_MonasteryGate.Starting)
local monks, swordsmen = 0, 0
for _, entry in World.Spawns do
	if entry.Mob == "CorruptWanderingMonk" then
		monks += 1
	elseif entry.Mob == "CursedSwordsman" then
		swordsmen += 1
	end
end
assert(monks > 0 and swordsmen > 0, "both mob archetypes are placed")
local shen = World.Bosses.GrandmasterShen
assert(shen.Phases[1].Weapon == "Jian" and shen.Phases[2].Weapon == "Guandao")
assert(World.phaseFor(shen, 1, 0.8, 0) == 1, "healthy, no deathblow: phase 1")
assert(World.phaseFor(shen, 1, 0.5, 0) == 2, "50% HP: phase 2")
assert(World.phaseFor(shen, 1, 0.9, 1) == 2, "first deathblow: phase 2")
assert(World.phaseFor(shen, 2, 1.0, 0) == 2, "phases never regress")
local gate = World.FogGates[shen.FogGate]
assert(World.contains(shen.Arena, gate.Inside.X, gate.Inside.Y, gate.Inside.Z))
assert(not World.contains(shen.Arena, gate.Outside.X, gate.Outside.Y, gate.Outside.Z))
assert(table.isfrozen(World.Mobs.CursedSwordsman.AI), "manifest is frozen")

-------------------------------------------------------------------------------------------------
-- Souls profile
-------------------------------------------------------------------------------------------------
local data = {}
local db = {
	UpdateAsync = function(_, key, fn)
		local value = fn(Store.Copy(data[key]))
		if value ~= nil then
			data[key] = Store.Copy(value)
		end
		return Store.Copy(value)
	end,
}
local now = 1000
local store = Store.new(db, Schema, { owner = "A", now = function() return now end, wait = function() end, attempts = 3, leaseSeconds = 180 })

-- Legacy (pre-Souls) record migrates with defaults.
data["Player_7"] = Schema.Default(7)
local profile = assert(store:Load(7))
local souls = profile.souls
assert(souls.level == 1 and souls.essence == 0 and souls.attributes.Vitality == 10)
assert(souls.inventory.mainhand == "Jian" and souls.inventory.weapons.Unarmed and souls.inventory.weapons.Jian)
assert(souls.world.activeAltar == "Altar_SanctuaryBonfire" and souls.world.altars.Altar_SanctuaryBonfire)
assert(souls.version == 2 and next(souls.inventory.reinforcement) == nil)
assert(souls.inventory.elixirs.charges == Settings.Elixir.BaseCharges)

-- Death drops carried + unbanked essence into a bloodstain.
assert(store:GrantEssence(7, 500))
local ok, err, dropped = store:RecordDeath(7, "BambooPass", 10, 3, -1400, 120)
assert(ok and dropped == 620, tostring(err))
souls = store:Souls(7)
assert(souls.essence == 0 and souls.world.bloodstain.essence == 620 and souls.deaths == 1)
local firstDeath = souls.world.bloodstain.death

-- Dying again before retrieval destroys the old essence.
assert(store:GrantEssence(7, 40))
ok, err, dropped = store:RecordDeath(7, "BambooPass", 20, 3, -1450, 0)
assert(ok and dropped == 40)
souls = store:Souls(7)
assert(souls.world.bloodstain.essence == 40 and souls.world.bloodstain.x == 20)
assert(not store:RecoverBloodstain(7, firstDeath), "stale bloodstain cannot be recovered")
local recovered
ok, err, recovered = store:RecoverBloodstain(7, souls.world.bloodstain.death)
assert(ok and recovered == 40)
souls = store:Souls(7)
assert(souls.world.bloodstain == nil and souls.essence == 40)
-- Recovered essence is carried again and drops on the next death; a death carrying nothing
-- destroys the old stain and leaves none.
ok, err, dropped = store:RecordDeath(7, "BambooPass", 0, 3, -1400, 0)
assert(ok and dropped == 40 and store:Souls(7).world.bloodstain ~= nil)
ok, err, dropped = store:RecordDeath(7, "BambooPass", 0, 3, -1400, 0)
assert(ok and dropped == 0 and store:Souls(7).world.bloodstain == nil and store:Souls(7).essence == 0)

-- Levelling spends essence and raises derived stats.
assert(not store:LevelAttribute(7, "Vitality"), "cannot afford level 2")
assert(store:GrantEssence(7, 5000))
local before = Store.DeriveStats(store:Souls(7))
local cost = Store.LevelCost(1)
assert(store:LevelAttribute(7, "Vitality"))
assert(store:LevelAttribute(7, "Qi"))
assert(store:LevelAttribute(7, "Dexterity"))
souls = store:Souls(7)
assert(souls.level == 4 and souls.attributes.Vitality == 11 and souls.essence == 5000 - cost - Store.LevelCost(2) - Store.LevelCost(3))
local after = Store.DeriveStats(souls)
assert(after.MaxHP > before.MaxHP and after.MaxStamina > before.MaxStamina and after.PostureCapacity > before.PostureCapacity)
assert(after.DexterityScale > before.DexterityScale and after.StrengthScale == before.StrengthScale)
assert(not store:LevelAttribute(7, "Charisma"), "unknown attribute refused")

-- Altars, bosses, inventory, gourd.
assert(store:ActivateAltar(7, "Altar_BambooShrine", true, true))
souls = store:Souls(7)
assert(souls.world.activeAltar == "Altar_BambooShrine" and souls.world.altars.Altar_SanctuaryBonfire)
assert(store:SetElixirCharges(7, 1) and store:Souls(7).inventory.elixirs.charges == 1)
assert(store:ActivateAltar(7, "Altar_BambooShrine", true, true) and store:Souls(7).inventory.elixirs.charges == Settings.Elixir.BaseCharges)
assert(store:AddElixirCapacity(7) and store:Souls(7).inventory.elixirs.max == Settings.Elixir.BaseCharges + 1)
local essence = store:Souls(7).essence
assert(store:RecordBossDefeat(7, "GrandmasterShen", 4000))
assert(store:RecordBossDefeat(7, "GrandmasterShen", 4000))
assert(store:Souls(7).essence == essence + 4000, "boss essence granted once")
assert(not store:EquipLoadout(7, "Guandao", "None"), "locked weapon refused")
assert(store:UnlockWeapon(7, "Guandao") and store:EquipLoadout(7, "Guandao", "Jian"))
assert(store:Souls(7).inventory.mainhand == "Guandao" and store:Souls(7).inventory.offhand == "Jian")
assert(not store:UnlockWeapon(7, "Nunchaku"))

-- Blacksmith reinforcement: costs banked essence, scales damage for the equipped weapon only.
do
	local unforged = Store.DeriveStats(store:Souls(7))
	local bank = store:Souls(7).essence
	assert(bank >= Store.ReinforceCost(0), "test needs essence for one reinforcement")
	local okForge, forgeErr, level = store:ReinforceWeapon(7, "Guandao")
	assert(okForge and level == 1, tostring(forgeErr))
	assert(store:Souls(7).essence == bank - Store.ReinforceCost(0))
	local forged = Store.DeriveStats(store:Souls(7))
	assert(math.abs(forged.StrengthScale / unforged.StrengthScale - 1.06) < 1e-9)
	assert(forged.MaxHP == unforged.MaxHP)
	assert(store:EquipLoadout(7, "Jian", "Guandao"))
	assert(math.abs(Store.DeriveStats(store:Souls(7)).StrengthScale - unforged.StrengthScale) < 1e-9, "bonus follows the weapon")
	assert(not store:ReinforceWeapon(7, "Dao"), "locked weapon cannot be reinforced")
	assert(store:GrantEssence(7, 0) and Store.ReinforceCost(1) > Store.ReinforceCost(0))
	assert(store:EquipLoadout(7, "Guandao", "Jian"))
end

-- Corrupt souls data is repaired on migration; validation rejects tampering.
local raw = Schema.Default(8)
raw.souls = {
	version = 1,
	attributes = { Vitality = 500, Qi = 12, Strength = "x", Dexterity = 10 },
	essence = -5,
	inventory = { weapons = { Jian = true, Nunchaku = true }, mainhand = "Nunchaku", offhand = "Jian", elixirs = { charges = 99, max = 4, potency = 1 } },
	world = { altars = { Altar_BambooShrine = true }, activeAltar = "Altar_BambooShrine", bosses = {}, bloodstain = { region = "X", x = 0 / 0 } },
	deaths = 3,
}
data["Player_8"] = raw
local repaired = assert(store:Load(8)).souls
assert(repaired.attributes.Vitality == 10 and repaired.attributes.Qi == 12 and repaired.level == 3)
assert(repaired.essence == 0 and repaired.deaths == 3)
assert(repaired.inventory.weapons.Nunchaku == nil and repaired.inventory.mainhand == "Jian")
assert(repaired.inventory.elixirs.max == 4 and repaired.inventory.elixirs.charges == 4)
assert(repaired.world.bloodstain == nil and repaired.world.activeAltar == "Altar_BambooShrine")
assert(repaired.world.altars.Altar_SanctuaryBonfire, "migration kindles the starting altar")
local tampered = Store.Copy(repaired)
tampered.inventory.reinforcement.Jian = 9
assert(not Store.ValidateSouls(tampered), "reinforcement capped")
tampered = Store.Copy(repaired)
tampered.level = 50
assert(not Store.ValidateSouls(tampered), "level must match attributes")
tampered = Store.Copy(repaired)
tampered.inventory.weapons.Unarmed = nil
assert(not Store.ValidateSouls(tampered), "unarmed cannot be removed")
assert(not Store.ValidateSouls(nil))

-------------------------------------------------------------------------------------------------
-- Combat extensions
-------------------------------------------------------------------------------------------------
local T = 50
local events = {}
local function advance(f, from, to)
	local t = from
	while t < to - 1e-9 do
		t = math.min(to, t + 1 / 60)
		Combat.step(f, t, 1 / 60, events)
	end
end
local function activate(f, kind, at)
	assert(Combat.tryAttack(f, kind, at))
	local active = at + f.Move.Timing.StartupSeconds + 1e-4
	advance(f, at, active)
	return active
end
local front = { Facing = true, Region = "Torso" }

-- Stats: derived pools and attribute scaling.
local player = Combat.new(1, "Jian", T)
Combat.applyStats(player, after, true)
assert(player.MaxHP == after.MaxHP and player.ActiveHP == after.MaxHP and player.Stamina == after.MaxStamina)
local dummy = Combat.new(2, "Unarmed", T)
local t = activate(player, "Light", T)
Combat.resolveHit(player, dummy, t, front, events)
local base = Weapons.get("Jian").Light[1].BaseDamage
assert(near(100 - dummy.ActiveHP, base * after.DexterityScale), "dexterity scales blade damage")

-- Boss pools beyond 100 survive the replication codec.
local boss = Combat.new(-1, "Jian", T)
Combat.applyStats(boss, shen.Phases[1].Stats, true)
boss.KOProtected = true
assert(boss.MaxHP == 900 and boss.ActiveHP == 900)
local snap = Combat.unpackString(Combat.packString(boss, T))
assert(snap and near(snap.MaxHP, 900, 0.05) and near(snap.ActiveHP, 900, 0.05) and snap.KOProtected)
assert(near(snap.PostureCapacity, 240, 0.01))

-- KO protection floors HP at 1 (multi-phase bosses).
boss.ActiveHP = 5
local attacker = Combat.new(3, "Guandao", T)
t = activate(attacker, "Heavy", T)
assert(Combat.resolveHit(attacker, boss, t, front, events) ~= "KO" and boss.ActiveHP >= 1)
boss.KOProtected = false

-- Poise armor shrugs off light hitstun.
local brute = Combat.new(4, "Guandao", T)
Combat.applyStats(brute, { PoiseArmor = 0.65 }, true)
local jab = Combat.new(5, "Unarmed", T)
t = activate(jab, "Light", T)
assert(Combat.resolveHit(jab, brute, t, front, events) == "Armored" and brute.State == "Idle", brute.State)

-- Elixir: heals at the end of the drink; interruption forfeits it.
local drinker = Combat.new(6, "Jian", T)
drinker.ActiveHP = 40
assert(Combat.tryHeal(drinker, T))
advance(drinker, T, T + Settings.Elixir.DrinkDuration + 0.05)
assert(near(drinker.ActiveHP, 40 + 100 * Settings.Elixir.HealFraction, 1e-6) and drinker.State == "Idle")
drinker.ActiveHP = 40
assert(Combat.tryHeal(drinker, T + 2))
local hitter = Combat.new(7, "Dao", T + 2)
t = activate(hitter, "Light", T + 2.1)
Combat.resolveHit(hitter, drinker, t, front, events)
local hpAfterHit = drinker.ActiveHP
advance(drinker, t, t + 1.5)
assert(drinker.ActiveHP <= hpAfterHit + 1e-6, "interrupted drink does not heal")

-- Cinematic lock is invulnerable; area strikes respect i-frames and guards.
local chimera = Combat.new(-2, "Guandao", T)
Combat.cinematic(chimera, T, 2.4)
assert(Combat.isInvulnerable(chimera, T + 1) and not Combat.isInvulnerable(chimera, T + 2.5))
local victim = Combat.new(8, "Jian", T)
assert(Combat.applyArea(chimera, victim, T, 28, 45, true, true, events) == "Hit" and victim.ActiveHP < 100)
local roller = Combat.new(9, "Jian", T)
local grant = Combat.tryDash(roller, "Roll", T, 0, 1, events)
assert(grant and Combat.applyArea(chimera, roller, grant.IFrameStart + 0.01, 28, 45, true, true, events) == "Whiff")
local guard = Combat.new(10, "Jian", T)
assert(Combat.setGuard(guard, true, T))
assert(Combat.applyArea(chimera, guard, T, 22, 20, false, true, events) == "Blocked")
local guard2 = Combat.new(11, "Jian", T)
assert(Combat.setGuard(guard2, true, T))
assert(Combat.applyArea(chimera, guard2, T, 22, 20, true, true, events) == "Hit", "perilous ignores guard")

-- Forced weapon swap (phase transition) bypasses Equip eligibility.
local swapper = Combat.new(12, "Jian", T)
assert(Combat.tryAttack(swapper, "Light", T))
Combat.forceWeapon(swapper, "Guandao")
assert(swapper.Weapon == "Guandao" and swapper.Move == nil)

print("Asura Stage 3: all checks passed")

--!strict
-- Engine-free checks run directly with work/bin/luau/luau. Runtime components use the companion runner.
local World = require("../src/shared/WorldDefinitions")
local Rules = require("../src/shared/BossEncounterRules")
local Combat = require("../src/simulation/CombatRules")
local Weapons = require("../src/simulation/WeaponSchema")
local Store = require("../src/server/ProfileStore")
local Profile = require("../src/shared/ProfileSchema")
local checks = 0
local function check(value: any, message: string)
	assert(value, message); checks += 1
end
local function near(a: number, b: number): boolean return math.abs(a - b) < 1e-6 end
local roster = { "GrandmasterShen", "VenerableBaize", "SlumberingTitan", "SovereignWu", "TwinSentinels", "AzureWyrm" }
local kinds: { [string]: boolean } = {}
for _, id in roster do
	local boss = assert(World.Bosses[id])
	local gate = assert(World.FogGates[boss.FogGate])
	check(gate.Boss == id, "gate binds the right encounter")
	check(World.contains(boss.Arena, gate.Inside.X, gate.Inside.Y, gate.Inside.Z), "entrant lands inside")
	check(not World.contains(boss.Arena, gate.Outside.X, gate.Outside.Y, gate.Outside.Z), "outsider lands outside")
	check(World.regionAt(boss.Arena.Center.X, 3, boss.Arena.Center.Z) == boss.Region, "arena has a reachable region")
	for index, phase in boss.Phases do
		check(Weapons.Weapons[phase.Weapon] ~= nil, "phase weapon exists")
		check(phase.Attacks and #phase.Attacks >= 2, "archetype has multiple attacks")
		check(World.phaseFor(boss, index, 1, 0) == index, "phase cannot regress")
		if index > 1 then
			check(World.phaseFor(boss, index - 1, 0.51, 0) == index - 1, "phase holds above threshold")
			check(World.phaseFor(boss, index - 1, 0.5, 0) == index, "phase fires on threshold")
			check(World.phaseFor(boss, index - 1, 0.9, 1) == index, "deathblow also transitions")
		end
		for _, attack in phase.Attacks or {} do
			check(Rules.AttackKinds[attack.Kind] == true, "known attack classification")
			check(Rules.impact(10, attack.Windup) >= 10.65, "warning precedes impact")
			check(not attack.Repeats or (attack.Interval or 1) >= Rules.MinimumWarning, "each repeated strike remains reactable")
			kinds[attack.Kind] = true
		end
	end
end
for _, kind in { "PerilousSweep", "PerilousThrust", "PerilousGrab", "Shockwave", "Barrage", "Gravity", "Ritual", "Breath", "Tail" } do
	check(kinds[kind], "roster covers " .. kind)
end
local unblockable, counter = Rules.classify("PerilousSweep")
check(unblockable and counter == "Double Jump", "sweep requires jump")
check(select(2, Rules.classify("PerilousThrust")) == "Deflect", "thrust has a deflect counter")
check(select(2, Rules.classify("PerilousGrab")) == "Slide Dash", "grab has a slide counter")
check(Rules.tightDeflect(5, 5.1) and not Rules.tightDeflect(5, 5.1001) and not Rules.tightDeflect(5.01, 5), "100ms inclusive boundary")
local function fighter(id: number): Combat.Fighter return Combat.new(id, "Jian", 0) end
for _, kind in { "PerilousSweep", "PerilousGrab" } do
	local source, target = fighter(1), fighter(2)
	target.State = "Blocking"
	check(Combat.applyBossAttack(source, target, 5, 20, 20, kind, true, {}) == "Hit", "perilous bypasses guard")
	check(target.ActiveHP < target.MaxHP, "blocked perilous still deals damage")
	if kind == "PerilousGrab" then check(target.State == "Recovery" and target.InvulnerableUntil > 5, "grab locks cinematic victim") end
end
for _, timing in { 0, 0.05, 0.1, 0.1001, -0.001 } do
	local source, target = fighter(1), fighter(2)
	source.PostureCapacity = 400
	target.State, target.DeflectPressedAt, target.DeflectWindow = "Deflecting", 5, 0.4
	local outcome = Combat.applyBossAttack(source, target, 5 + timing, 20, 30, "PerilousThrust", true, {})
	local valid = timing >= 0 and timing <= 0.1
	check((outcome == "Deflected") == valid, "boss thrust ignores the ordinary wide deflect window")
	if valid then check(source.Posture >= 75 and target.ActiveHP == target.MaxHP, "tight deflect reflects massive posture") end
end
do
	local source, target = fighter(1), fighter(2)
	Combat.cinematic(target, 10, 2.4)
	check(Combat.applyBossAttack(source, target, 11, 40, 30, "PerilousGrab", true, {}) == "Whiff", "phase sequence is invulnerable")
	check(not Combat.isInvulnerable(target, 12.5), "invulnerability expires")
end
check(not Rules.waveHit(30, 0, 0.5, 0.4, 30, 100, 9), "wave does not hit before arrival")
check(Rules.waveHit(30, 0, 1, 0.9, 30, 100, 9), "wave hits on arrival")
check(Rules.waveHit(30, 0, 1.5, 0.5, 30, 100, 9), "swept collision survives a delayed frame")
check(not Rules.waveHit(30, 10, 1, 0.9, 30, 100, 9), "air glide clears frost")
check(not Rules.waveHit(105, 0, 4, 3, 30, 100, 9), "wave respects its radius")
check(Rules.segmentHit(10, 2, 0, 0, 30, 0, 3) and not Rules.segmentHit(10, 5, 0, 0, 30, 0, 3), "thrust corridor collision")
check(not Rules.shouldClose(60, 10, 12, 40, 2.5) and Rules.shouldClose(60, 10, 12.5, 40, 2.5), "range clamp needs sustained distance")
check(not Rules.shouldClose(39, 0, 20, 40, 2.5), "range clamp stops in melee")
check(Rules.enrage(1, false) and not Rules.enrage(1, true) and not Rules.enrage(2, false), "survivor enrages once")
check(Rules.lifecycle(1, false, true) == "Sealed", "fog remains sealed with a survivor")
check(Rules.lifecycle(0, false, true) == "Reset", "party wipe releases fog")
check(Rules.lifecycle(1, true, true) == "Victory", "defeat releases fog")
check(Rules.lifecycle(1, false, false) == "Reset", "missing boss releases fog")
for _, amount in { 0, 1, 4000, 6401 } do
	local total = 0
	local drops = Rules.loot(amount, 12)
	for _, drop in drops do total += drop.Amount; check(near(drop.X^2 + drop.Z^2, 49), "loot disperses radially") end
	check(#drops == 12 and total == amount, "loot conserves reward")
end
-- Persistence is the actual store transaction, including replay and rejoin behavior.
local data: any = {}
local db: any = { UpdateAsync = function(_self: any, key: string, transform: any): any
	local value = transform(Store.Copy(data[key])); if value ~= nil then data[key] = Store.Copy(value) end
	return Store.Copy(data[key])
end }
local store = Store.new(db, Profile, { owner = "boss-tests", attempts = 3, leaseSeconds = 180, now = function() return 1000 end, wait = function() end })
check(store:Load(901) ~= nil, "profile opens")
local before = store:Souls(901).essence
for _, id in roster do
	check(store:RecordBossDefeat(901, id, World.Bosses[id].Essence), "boss reward commits")
	check(store:Souls(901).world.bosses[id], "boss flag persists")
end
local banked = store:Souls(901).essence
check(banked > before, "victory banks essence")
check(store:RecordBossDefeat(901, "GrandmasterShen", World.Bosses.GrandmasterShen.Essence), "duplicate victory is idempotent")
check(store:Souls(901).essence == banked, "duplicate victory does not duplicate loot")
check(store:Release(901), "profile closes durably")
local rejoined = Store.new(db, Profile, { owner = "boss-rejoin", attempts = 3, leaseSeconds = 180, now = function() return 1001 end, wait = function() end })
check(rejoined:Load(901) ~= nil, "profile rejoins")
for _, id in roster do check(rejoined:Souls(901).world.bosses[id], "all six boss flags survive rejoin") end
check(rejoined:Souls(901).essence == banked, "banked essence survives rejoin")
print(string.format("Boss encounters: %d checks passed", checks))

--!nonstrict
-- Local Luau runner; no Explorer location. Objective tracker resolver checks.
-- Minimal Vector3 shim: the resolver only constructs and passes positions through.
local Vector3 = { new = function(x, y, z)
	return { X = x, Y = y, Z = z }
end }

local Objectives = require("../src/shared/Objectives")

local function facts(overrides)
	local base = {
		Region = "Sanctuary",
		Altars = { Altar_SanctuaryBonfire = true },
		Bloodstain = nil,
		InBoss = false,
		InColosseum = false,
		BossFelled = false,
		Rested = false,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

-- Parsing the replicated comma list.
local parsed = Objectives.parseAltars("Altar_MonasteryGate,Altar_SanctuaryBonfire")
assert(parsed.Altar_MonasteryGate and parsed.Altar_SanctuaryBonfire and not parsed.Altar_BambooShrine, "parse altars")
assert(next(Objectives.parseAltars(nil)) == nil and next(Objectives.parseAltars("")) == nil, "parse empty")

-- Brand-new player: rest at the pre-kindled bonfire first.
local first = Objectives.resolve(facts())
assert(first and first.Key == "FirstRest" and first.Target.Kind == "Altar" and first.Target.Id == "Altar_SanctuaryBonfire", "first rest")

-- After resting: head for the Ascension portal.
local ascend = Objectives.resolve(facts({ Rested = true }))
assert(ascend and ascend.Target.Kind == "Portal" and ascend.Key == "Ascend:Altar_MonasteryGate", "ascend")

-- Returning veteran (already past the gate) is never sent back to the bonfire tutorial.
local veteran = Objectives.resolve(facts({ Altars = { Altar_SanctuaryBonfire = true, Altar_MonasteryGate = true } }))
assert(veteran and veteran.Key == "Ascend:Altar_DesecratedCloister", "veteran skips first rest")

-- In the monastery: kindle the next altar in route order.
local monastery = Objectives.resolve(facts({ Region = "DesecratedMonastery", Rested = true }))
assert(monastery and monastery.Key == "Altar_MonasteryGate" and monastery.Target.Id == "Altar_MonasteryGate", "kindle gate")

-- Bloodstain outranks the route.
local stain = Vector3.new(1, 2, 3)
local reclaim = Objectives.resolve(facts({ Region = "BambooPass", Bloodstain = stain, Rested = true }))
assert(reclaim and reclaim.Key == "Bloodstain" and reclaim.Target.Position == stain, "bloodstain priority")

-- Boss fights and duels hide the tracker.
assert(Objectives.resolve(facts({ InBoss = true })) == nil, "hidden in boss")
assert(Objectives.resolve(facts({ InColosseum = true })) == nil, "hidden in colosseum")

-- All altars kindled: boss, then the Colosseum.
local all = {}
for _, altar in Objectives.Route do
	all[altar.Id] = true
end
local boss = Objectives.resolve(facts({ Region = "AshColosseum", Altars = all, Rested = true }))
assert(boss and boss.Key == "Boss" and boss.Target.Kind == "Point", "boss objective")
local duel = Objectives.resolve(facts({ Region = "AshColosseum", Altars = all, Rested = true, BossFelled = true }))
assert(duel and duel.Key == "Duel" and duel.Target == nil, "duel objective")

assert(Objectives.regionOf("Altar_BambooShrine") == "BambooPass" and Objectives.regionOf("nope") == nil, "regionOf")

print("Objectives: all checks passed")

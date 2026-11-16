--!nonstrict
-- Ticket 07: the Objectives route once Overworld.Active is set ends at Grandmaster Shen and never names an inactive boss.
-- Run via: python3 tools/test_objectives.py test_objectives_overworld (inlines Objectives; no-op while the flag is false).
local Vector3 = { new = function(x, y, z)
	return { X = x, Y = y, Z = z }
end }
local Objectives = require("../src/shared/Objectives")
local Overworld = require("../src/shared/Overworld")

if not Overworld.Active then
	print("Objectives overworld route: skipped (Overworld.Active is false)")
	return
end
local function facts(overrides)
	local base = { Region = "MountainAscent", Bosses = {}, Altars = { Altar_SanctuaryBonfire = true }, InBoss = false, InColosseum = false, BossFelled = false, Rested = true }
	for key, value in overrides do base[key] = value end
	return base
end
local altars = { Altar_SanctuaryBonfire = true }
for _, a in Objectives.Route do altars[a.Id] = true end
local step = Objectives.resolve(facts({ Altars = altars }))
assert(step and step.Key == "Boss:GrandmasterShen", "route ends at Shen")
assert(Objectives.Route[2].Id == Overworld.Gateway and Objectives.Route[#Objectives.Route].Id == "Altar_ColosseumAntechamber", "long route order")
local newcomer = Objectives.resolve(facts({ Region = "Sanctuary", Altars = { Altar_SanctuaryBonfire = true } }))
assert(newcomer and newcomer.Key == "Ascend:" .. Overworld.Gateway, "newcomer climbs to the glade")
local mid = Objectives.resolve(facts({ Region = "Forest", Altars = { Altar_SanctuaryBonfire = true, Altar_MonasteryGate = true, Altar_BellTerrace = true, Altar_BambooShrine = true, Altar_DesecratedCloister = true } }))
assert(mid and mid.Key == "Altar_RavineOverlook", "next altar in route order across regions")
for _, e in Objectives.Encounters do assert(e.Id == "GrandmasterShen", "inactive boss " .. e.Id) end
assert(Objectives.regionOf("Altar_BellTerrace") == "Forest")
print("Objectives overworld route: all checks passed")

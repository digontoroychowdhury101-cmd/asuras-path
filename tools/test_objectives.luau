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
-- The card names the leg the marker stages (follow-up 14): the Well for a crypt stain, the return portal home.
local well = Objectives.resolve(facts({ Region = "Sanctuary", Bloodstain = stain, StainRegion = "SanctuaryDepths", Rested = true }))
assert(well and string.find(well.Detail, "Well of Descent", 1, true), "crypt stain names the Well, not the northern gate")
local gateStain = Objectives.resolve(facts({ Region = "Sanctuary", Bloodstain = stain, StainRegion = "BambooPass", Rested = true }))
assert(gateStain and string.find(gateStain.Detail, "northern gate", 1, true), "campaign stain still names the northern gate")
local homeStain = Objectives.resolve(facts({ Region = "SanctuaryDepths", Bloodstain = stain, StainRegion = "Sanctuary", Rested = true }))
assert(homeStain and string.find(homeStain.Detail, "return portal", 1, true), "Sanctuary stain from the crypt names the return portal")
-- Same key, new wording (Studio F14: a death moved the player home and the card kept the old leg).
assert(Objectives.changed(reclaim, gateStain), "the tracker redraws when only the bloodstain detail changes")
assert(not Objectives.changed(gateStain, Objectives.resolve(facts({ Region = "Sanctuary", Bloodstain = stain, StainRegion = "BambooPass", Rested = true }))), "an identical step does not redraw")
assert(Objectives.changed(nil, reclaim) and Objectives.changed(reclaim, nil) and not Objectives.changed(nil, nil), "appearing and clearing redraw")

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

local defeated = {}
for _, encounter in Objectives.Encounters do
 local active = Objectives.resolve(facts({Region=encounter.Region,Altars=all,Rested=true,Bosses=defeated}))
 assert(active and active.Key=="Boss:"..encounter.Id, "regional boss objective "..encounter.Id)
 defeated[encounter.Id]=true
end
-- Batch 22: six sovereigns lead home to Lin and the choice, never straight to PvP.
local five=table.clone(defeated);five.AzureWyrm=nil
local lastOne=Objectives.resolve(facts({Region="SkyCitadel",Altars=all,Rested=true,Bosses=five}))
assert(lastOne and lastOne.Key=="Boss:AzureWyrm", "five of six still points at the last sovereign")
local campaignDone=Objectives.resolve(facts({Region="SkyCitadel",Altars=all,Rested=true,Bosses=defeated}))
assert(campaignDone and campaignDone.Key=="Ending:Return" and campaignDone.Target.Kind=="Point" and campaignDone.Target.Position.Z==-2690, "citadel: take the bastion portal home")
local home=Objectives.resolve(facts({Region="Sanctuary",Altars=all,Rested=true,Bosses=defeated}))
assert(home and home.Key=="Ending:Return" and home.Target.Position.X==8 and home.Target.Position.Z==918, "sanctuary: Lin beside the bonfire")
local bamboo=Objectives.resolve(facts({Region="BambooPass",Altars=all,Rested=true,Bosses=defeated}))
assert(bamboo and bamboo.Target.Kind=="Altar" and bamboo.Target.Id=="Altar_BambooShrine", "other regions: travel from the local altar")
local crypt=Objectives.resolve(facts({Region="SanctuaryDepths",Altars=all,Rested=true,Bosses=defeated}))
assert(crypt and crypt.Target.Position.Z==1074, "crypt: return portal")
local remain=Objectives.resolve(facts({Region="Sanctuary",Altars=all,Rested=true,Bosses=defeated,Story={Released=true,Remained=true}}))
assert(remain and remain.Key=="Ending:Remain" and remain.Target==nil and string.find(remain.Detail,"optional",1,true), "remain: free roam, crossing still offered, duels optional")
local crossed=Objectives.resolve(facts({Region="AshColosseum",Altars=all,Rested=true,Bosses=defeated,Story={Released=true,Remained=true,Crossed=true}}))
assert(crossed and crossed.Key=="Postgame" and crossed.Target==nil and string.find(crossed.Detail,"optional",1,true), "crossed: postgame, duels optional")
local stained=Objectives.resolve(facts({Region="Sanctuary",Altars=all,Rested=true,Bosses=defeated,Bloodstain=Vector3.new(1,2,3)}))
assert(stained and stained.Key=="Bloodstain", "a bloodstain still comes first after six")
local seeded=Objectives.resolve(facts({Region="Sanctuary",Altars=all,Rested=true,Bosses=five,Story={Crossed=true}}))
assert(seeded and seeded.Key=="Boss:AzureWyrm", "story flags never count without six defeated-boss flags")
local revived=Objectives.parseAltars("GrandmasterShen,AzureWyrm")
assert(revived.GrandmasterShen and revived.AzureWyrm and not revived.TwinSentinels, "boss attribute flags parse")
print("Objectives: all checks passed (including six encounter routes)")

--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/Objectives
-- Pure "what should I do next?" resolver for the HUD objective tracker. It reads only facts the
-- server already replicates to the owning player (region, kindled altars, bloodstain, boss/duel
-- flags) and returns presentation text plus a waypoint target. No authority lives here: the
-- server still validates every rest, travel and recovery.
local Objectives = {}

export type Facts = {
	Region: string?,
	Altars: { [string]: boolean },
	Bloodstain: Vector3?,
	InBoss: boolean,
	InColosseum: boolean,
	BossFelled: boolean,
	-- True once the player has rested at any altar this session (teaches the rest loop first).
	Rested: boolean,
}

-- Target kinds the client knows how to locate in the world.
export type Target = { Kind: "Altar", Id: string } | { Kind: "Portal" } | { Kind: "Point", Position: Vector3 }

export type Objective = {
	Key: string,
	Title: string,
	Detail: string,
	Target: Target?,
}

type AltarInfo = { Id: string, Name: string, Region: string }

-- Story order of altars; the first unkindled one is the next destination.
local ROUTE: { AltarInfo } = {
	{ Id = "Altar_SanctuaryBonfire", Name = "Primal Bonfire", Region = "Sanctuary" },
	{ Id = "Altar_MonasteryGate", Name = "Monastery Gate", Region = "DesecratedMonastery" },
	{ Id = "Altar_DesecratedCloister", Name = "Desecrated Cloister", Region = "DesecratedMonastery" },
	{ Id = "Altar_BambooShrine", Name = "Whispering Bamboo Shrine", Region = "BambooPass" },
	{ Id = "Altar_ColosseumAntechamber", Name = "Colosseum Antechamber", Region = "AshColosseum" },
}
Objectives.Route = ROUTE

-- Fog gate in front of Grandmaster Shen (WorldDefinitions.FogGates.Gate_AshColosseum.Outside).
local BOSS_APPROACH = Vector3.new(0, 3, -1880)

function Objectives.parseAltars(value: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

function Objectives.regionOf(altarId: string): string?
	for _, altar in ROUTE do
		if altar.Id == altarId then
			return altar.Region
		end
	end
	return nil
end

function Objectives.resolve(facts: Facts): Objective?
	if facts.InColosseum or facts.InBoss then
		return nil
	end
	if facts.Bloodstain then
		return {
			Key = "Bloodstain",
			Title = "Reclaim your lost essence",
			Detail = "Return to your bloodstain before you fall again",
			Target = { Kind = "Point", Position = facts.Bloodstain },
		}
	end
	-- New profiles start with the bonfire pre-kindled; still walk a newcomer through one rest.
	local bonfire = ROUTE[1]
	if not facts.Rested and not facts.Altars[ROUTE[2].Id] and (facts.Region == "Sanctuary" or facts.Region == nil) then
		return {
			Key = "FirstRest",
			Title = "Kneel at the " .. bonfire.Name,
			Detail = "Resting sets your respawn point and refills your gourd",
			Target = { Kind = "Altar", Id = bonfire.Id },
		}
	end
	for _, altar in ROUTE do
		if not facts.Altars[altar.Id] then
			if altar.Region == "Sanctuary" then
				return {
					Key = altar.Id,
					Title = "Kneel at the " .. altar.Name,
					Detail = "Resting sets your respawn point and refills your gourd",
					Target = { Kind = "Altar", Id = altar.Id },
				}
			elseif facts.Region == "Sanctuary" or facts.Region == nil then
				return {
					Key = "Ascend:" .. altar.Id,
					Title = "Climb the Ascension Stairs",
					Detail = "Pass through the northern gate to reach the " .. altar.Name,
					Target = { Kind = "Portal" },
				}
			end
			return {
				Key = altar.Id,
				Title = "Kindle the " .. altar.Name,
				Detail = "Fight your way forward — altars mark safe ground",
				Target = { Kind = "Altar", Id = altar.Id },
			}
		end
	end
	if not facts.BossFelled then
		return {
			Key = "Boss",
			Title = "Pass the fog gate",
			Detail = "Grandmaster Shen awaits beyond the Ash Colosseum",
			Target = { Kind = "Point", Position = BOSS_APPROACH },
		}
	end
	return {
		Key = "Duel",
		Title = "Prove yourself in the Colosseum",
		Detail = "Travel to the Sanctuary and challenge a rival on the east balcony",
		Target = nil,
	}
end

return Objectives

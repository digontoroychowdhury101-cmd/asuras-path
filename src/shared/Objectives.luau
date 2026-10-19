--!strict
local Objectives = {}

export type Facts = {
	Region: string?,
	Bosses: { [string]: boolean }?,
	Altars: { [string]: boolean },
	Bloodstain: Vector3?,
	InBoss: boolean,
	InColosseum: boolean,
	BossFelled: boolean,
	-- True once the player has rested at any altar this session (teaches the rest loop first).
	Rested: boolean,
}

export type Target = { Kind: "Altar", Id: string } | { Kind: "Portal" } | { Kind: "Point", Position: Vector3 }

export type Objective = {
	Key: string,
	Title: string,
	Detail: string,
	Target: Target?,
}

type AltarInfo = { Id: string, Name: string, Region: string }

local ROUTE: { AltarInfo } = {
	{ Id = "Altar_SanctuaryBonfire", Name = "Primal Bonfire", Region = "Sanctuary" },
	{ Id = "Altar_MonasteryGate", Name = "Monastery Gate", Region = "DesecratedMonastery" },
	{ Id = "Altar_DesecratedCloister", Name = "Desecrated Cloister", Region = "DesecratedMonastery" },
	{ Id = "Altar_BambooShrine", Name = "Whispering Bamboo Shrine", Region = "BambooPass" },
	{ Id = "Altar_ColosseumAntechamber", Name = "Colosseum Antechamber", Region = "AshColosseum" },
}
Objectives.Route = ROUTE

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
	local expanded: { [string]: string } = { Altar_SanctuaryDepths = "SanctuaryDepths", Altar_CelestialPagoda = "CelestialPagoda", Altar_SkyCitadel = "SkyCitadel" }
	if expanded[altarId] then return expanded[altarId] end
	for _, altar in ROUTE do
		if altar.Id == altarId then
			return altar.Region
		end
	end
	return nil
end

local ENCOUNTERS = {
	{ Id = "TwinSentinels", Name = "The Twin Sentinels", Region = "DesecratedMonastery", Position = Vector3.new(300, 3, -822) },
	{ Id = "VenerableBaize", Name = "Venerable Baize", Region = "BambooPass", Position = Vector3.new(0, 3, -1362) },
	{ Id = "GrandmasterShen", Name = "Grandmaster Shen", Region = "AshColosseum", Position = BOSS_APPROACH },
	{ Id = "SlumberingTitan", Name = "The Slumbering Titan", Region = "SanctuaryDepths", Position = Vector3.new(520, 3, 988) },
	{ Id = "SovereignWu", Name = "Sovereign Wu", Region = "CelestialPagoda", Position = Vector3.new(0, 3, -2272) },
	{ Id = "AzureWyrm", Name = "Azure Wyrm", Region = "SkyCitadel", Position = Vector3.new(0, 3, -2722) },
}
Objectives.Encounters = ENCOUNTERS

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
		if not facts.Altars[altar.Id] and (not facts.Bosses or altar.Region == facts.Region or facts.Region == "Sanctuary" or facts.Region == nil) then
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
	if facts.Bosses then
		local nextBoss = nil
		for _, boss in ENCOUNTERS do
			if not facts.Bosses[boss.Id] then
				nextBoss = nextBoss or boss
				if boss.Region == facts.Region then nextBoss = boss; break end
			end
		end
		if nextBoss then
			local approach = nextBoss.Position
			if nextBoss.Id == "SlumberingTitan" and facts.Region == "Sanctuary" then approach = Vector3.new(-35, 605, 900) end
			return { Key = "Boss:" .. nextBoss.Id, Title = "Challenge " .. nextBoss.Name,
				Detail = "Traverse the arena mist in " .. string.gsub(nextBoss.Region, "(%l)(%u)", "%1 %2"), Target = { Kind = "Point", Position = approach } }
		end
	elseif not facts.BossFelled then
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

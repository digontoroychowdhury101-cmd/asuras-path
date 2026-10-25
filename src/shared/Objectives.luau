--!strict
local hasScript = pcall(function() return script.Parent end)
local Ending: any = if hasScript then require(script.Parent.EndingRules) else require("./EndingRules")
local Objectives = {}

export type Facts = {
	Region: string?,
	Bosses: { [string]: boolean }?,
	Altars: { [string]: boolean },
	Bloodstain: Vector3?,
	StainRegion: string?, -- region the bloodstain lies in (portal-aware guidance, #28)
	InBoss: boolean,
	InColosseum: boolean,
	BossFelled: boolean,
	-- True once the player has rested at any altar this session (teaches the rest loop first).
	Rested: boolean,
	Story: { [string]: boolean }?, -- six-sovereign ending flags (batch 22)
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
-- The Sanctuary's northern gate always delivers to this altar (WorldDefinitions.Sanctuary.PortalDestination).
local PORTAL_ARRIVAL = ROUTE[2]

-- Sanctuary wording (batch 07, #29): name the portal's real destination first, then the next leg.
function Objectives.portalDetail(altar: AltarInfo): string
	if altar.Id == PORTAL_ARRIVAL.Id then
		return "The northern gate opens on the " .. PORTAL_ARRIVAL.Name .. " · kneel at its altar"
	end
	local leg = if altar.Region == PORTAL_ARRIVAL.Region then "press on through the monastery" else "travel on"
	return "The northern gate opens on the " .. PORTAL_ARRIVAL.Name .. " · then " .. leg .. " to the " .. altar.Name
end

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

-- Whether the tracker must redraw: a new step, or the same step with new wording (the bloodstain
-- card names a different leg after a death moves the player to another region; follow-up 14).
function Objectives.changed(shown: Objective?, latest: Objective?): boolean
	if shown == nil or latest == nil then return shown ~= latest end
	return shown.Key ~= latest.Key or shown.Title ~= latest.Title or shown.Detail ~= latest.Detail
end

function Objectives.resolve(facts: Facts): Objective?
	if facts.InColosseum or facts.InBoss then
		return nil
	end
	if facts.Bloodstain then
		return {
			Key = "Bloodstain",
			Title = "Reclaim your lost essence",
			-- Name the leg the marker stages (RouteGuide): the Well for the crypt, the return portal home.
			Detail = if facts.Region == "Sanctuary" and facts.StainRegion == "SanctuaryDepths"
				then "Take the Well of Descent first · the marker then leads to your bloodstain"
				elseif facts.Region == "Sanctuary" and facts.StainRegion ~= nil and facts.StainRegion ~= "Sanctuary"
				then "Take the northern gate first · the marker then leads to your bloodstain"
				elseif facts.StainRegion == "Sanctuary" and (facts.Region == "SanctuaryDepths" or facts.Region == "SkyCitadel")
				then "Take the return portal first · the marker then leads to your bloodstain"
				else "Return to your bloodstain before you fall again",
			Target = { Kind = "Point", Position = facts.Bloodstain },
		}
	end
	-- Six sovereigns at rest (batch 22): home to Lin, then the choice; PvP is never the conclusion.
	if facts.Bosses then
		local home = nil
		for _, id in { ROUTE[2].Id, ROUTE[3].Id, ROUTE[4].Id, ROUTE[5].Id, "Altar_SanctuaryDepths", "Altar_CelestialPagoda", "Altar_SkyCitadel" } do
			if not home and facts.Altars[id] and Objectives.regionOf(id) == facts.Region then home = id end
		end
		local ending = Ending.objective(Ending.stage(facts.Bosses, facts.Story), facts.Region, home)
		if ending then return ending end
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
					Detail = Objectives.portalDetail(altar),
					Target = { Kind = "Portal" },
				}
			end
			return {
				Key = altar.Id,
				Title = "Kindle the " .. altar.Name,
				Detail = if altar.Id == PORTAL_ARRIVAL.Id then "The altar stands just ahead of the portal · rest to set your checkpoint"
					else "Fight your way forward — altars mark safe ground",
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
			-- The Well of Descent south of the plaza (SanctuaryRoutes.Marks.CryptDescent, batch 16).
			if nextBoss.Id == "SlumberingTitan" and facts.Region == "Sanctuary" then approach = Vector3.new(0, 605, 996) end
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

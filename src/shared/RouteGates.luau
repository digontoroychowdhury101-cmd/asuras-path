--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/RouteGates
-- Shortcut gates: which ones a profile has opened. A gate counts as open once its flag is saved, or once the profile already holds progress
-- that lies past it, so a save from before the gate existed is never turned back. Pure: read by the server service and by tests.
local Gates = {}

export type Gate = { Id: string, Past: { Altars: { string }, Bosses: { string } } }

Gates.List = table.freeze({
	BambooRidge = { Id = "BambooRidge", Past = {
		Altars = { "Altar_BambooShrine", "Altar_ColosseumAntechamber" },
		Bosses = { "VenerableBaize" },
	} },
} :: { [string]: Gate })

function Gates.isOpen(profile: any, id: string): boolean
	local gate = Gates.List[id]
	if not gate or type(profile) ~= "table" then return false end
	if type(profile.routeFlags) == "table" and profile.routeFlags[id] == true then return true end
	for _, altar in gate.Past.Altars do
		if type(profile.unlockedAltars) == "table" and profile.unlockedAltars[altar] == true then return true end
	end
	for _, boss in gate.Past.Bosses do
		if type(profile.defeatedBosses) == "table" and profile.defeatedBosses[boss] == true then return true end
	end
	return false
end

-- What a player attribute carries to the client's route marker: "A,B".
function Gates.encode(profile: any): string
	local open = {}
	for id in Gates.List do
		if Gates.isOpen(profile, id) then table.insert(open, id) end
	end
	table.sort(open)
	return table.concat(open, ",")
end

function Gates.decode(text: any): { [string]: boolean }
	local open: { [string]: boolean } = {}
	if type(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do open[id] = true end
	end
	return open
end

return table.freeze(Gates)

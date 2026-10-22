--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/CodexView
-- The Codex inside the conversation panel: discovered/total counts for inscriptions and
-- sovereigns, a discovery instruction, and two sections. Entries come only from the server's
-- discovery flags (LoreEntries, defeated bosses). An undiscovered inscription shows only where to
-- look (its region), never its title or text; an unbound sovereign shows only its region.
local Shared = game:GetService("ReplicatedStorage").AsurasPath.Shared
local Catalog = require(Shared.NarrativeCatalog) :: any
local World = require(Shared.WorldDefinitions) :: any
local InputMap = require(Shared.InputMap) :: any
local Ending = require(Shared.EndingRules) :: any

local Codex = {}
Codex.Title = "MEMORIES OF THE JADE CATACLYSM"
Codex.Tagline = "Eight inscriptions. Six souls. One path beyond death." -- the existing narrative line
Codex.Instruction = "Read the jade memorial stones along the path (look for the glowing green script) to recover an inscription; "
	.. "each first reading also grants Essence. Lay the six sovereigns to rest to fill the second ledger."

export type Entry = { Id: string, Title: string, Hint: string, Known: boolean }
export type Summary = { Found: number, Total: number, Rested: number, Sovereigns: number, Inscriptions: { Entry }, Souls: { Entry }, Crossing: string }
export type Ui = { button: (v: any, label: string, run: () -> (), variant: string?, enabled: boolean?, height: number?) -> (),
	note: (v: any, text: string, color: Color3) -> (), reopen: (id: string) -> (), Gold: Color3, Muted: Color3, Ivory: Color3 }

local function regionName(id: string?): string
	local region = if id then World.Regions[id] else nil
	return if region then region.Name else "an unexplored region"
end

local function bossName(id: string): string
	local boss = World.Bosses[id]
	if not boss then return id end
	return if id == "TwinSentinels" then (string.match(boss.Title or "", "^([^:]+)") or "The Twin Sentinels") else boss.Name
end

-- The ending ledger line (batch 22): the same server flags as Lin and the objective tracker.
Codex.Crossing = table.freeze({
	Bound = "◇  The crossing · the ferryman waits for six silent chains",
	Release = "◆  The crossing · Lady Lin waits beside the Primal Bonfire",
	Remained = "◆  You chose to remain · Lady Lin keeps the crossing open",
	Crossed = "◆  The crossing is made · the Asura's Path is walked",
})

-- Pure: what the Codex may show for this discovery state.
function Codex.summary(data: any): Summary
	local lore = (data.inventory and data.inventory.LoreEntries) or {}
	local bosses = data.bosses or {}
	local result: Summary = { Found = 0, Total = #Catalog.LoreOrder, Rested = 0, Sovereigns = #Catalog.Sovereigns, Inscriptions = {}, Souls = {},
		Crossing = Codex.Crossing[Ending.stage(bosses, data.story)] }
	for _, id in Catalog.LoreOrder do
		local l = Catalog.Lore[id]
		local known = lore[id] == true
		if known then result.Found += 1 end
		table.insert(result.Inscriptions, { Id = id, Title = if known then l.Title else "Undiscovered inscription", Hint = regionName(l.Region), Known = known })
	end
	for _, id in Catalog.Sovereigns do
		local known = bosses[id] == true
		if known then result.Rested += 1 end
		local boss = World.Bosses[id]
		table.insert(result.Souls, { Id = id, Title = if known then bossName(id) else "Unbound sovereign", Hint = if known then "at rest" else regionName(boss and boss.Region), Known = known })
	end
	return result
end

function Codex.status(sum: Summary): string
	return string.format("%d / %d Inscriptions  ·  %d / %d Sovereigns at rest", sum.Found, sum.Total, sum.Rested, sum.Sovereigns)
end

-- Body text: a discovered entry's own words, or the tagline plus what to do next.
function Codex.body(sum: Summary, selected: string?): string
	for _, entry in sum.Inscriptions do
		if entry.Id == selected and entry.Known then
			-- The first reading teaches where it went (batch 10, #44).
			if sum.Found == 1 then
				local key = InputMap.get("Codex")
				return Catalog.Lore[selected].Text .. string.format("\n\nFirst inscription recorded in your Codex; each one also grants Essence. Reopen it any time with [%s].", if key then key.Key else "J")
			end
			return Catalog.Lore[selected].Text
		end
	end
	if sum.Found == sum.Total then return Codex.Tagline .. "\nEvery inscription is recovered. Choose one below to read it again." end
	if sum.Found == 0 then return Codex.Tagline .. "\n" .. Codex.Instruction end
	return Codex.Tagline .. string.format("\n%d inscriptions remain. ", sum.Total - sum.Found) .. Codex.Instruction
end

function Codex.render(v: any, data: any, selected: string?, ui: Ui)
	local sum = Codex.summary(data)
	v.Title.Text, v.Status.Text, v.Subtitle.Text = Codex.Title, Codex.status(sum), Codex.body(sum, selected)
	ui.note(v, string.format("INSCRIPTIONS  ·  %d / %d", sum.Found, sum.Total), ui.Gold)
	for _, entry in sum.Inscriptions do
		if entry.Known then
			local id = entry.Id
			ui.button(v, entry.Title .. "  ·  " .. entry.Hint, function() ui.reopen(id) end, if id == selected then "Primary" else "Secondary")
		else
			ui.button(v, "◇  " .. entry.Title .. "  ·  " .. entry.Hint, function() end, "Ghost", false)
		end
	end
	ui.note(v, string.format("SOVEREIGNS AT REST  ·  %d / %d", sum.Rested, sum.Sovereigns), ui.Gold)
	for _, entry in sum.Souls do
		ui.note(v, (if entry.Known then "◆  " else "◇  ") .. entry.Title .. "  ·  " .. entry.Hint, if entry.Known then ui.Ivory else ui.Muted)
	end
	ui.note(v, sum.Crossing, if sum.Rested == sum.Sovereigns then ui.Gold else ui.Muted)
end

return table.freeze(Codex)

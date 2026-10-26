--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/BossAnimationRules
-- The boss animation contract (F10): one resolver for every boss actor, phase and attack. A slot
-- key is "<LookKey>_P<phase>_<Action>" where Action is Idle, Strike (ordinary weapon moves),
-- Transform (phase change / Twins' oath) or a BossAttackCatalog move id. Each request walks
--   <Look>_P<n>_<Action>, <Look>_<Action>, then (attacks only) <Look>_P<n>_Strike, <Look>_Strike
-- and at each key takes, in order: the actor's AsuraBossAnimation_<key> attribute (copied by
-- BossAppearance from ServerStorage.AsuraAssets.AsuraBossAnimations, so it survives phase changes
-- and retries), then an authored id in `Custom` below (Shen's four legacy AnimationCatalog slots
-- count too). With nothing authored a humanoid plays the stock stand-in for the move's kind and a
-- creature keeps its procedural CreatureMotion pose. Animation is cosmetic only: no gameplay
-- reads tracks or markers; damage stays on the server's impact times.
local hasScript = pcall(function() return script.Parent end)
local Catalog: any, Attacks: any
if hasScript then
	Catalog, Attacks = require(script.Parent.AnimationCatalog), require(script.Parent.BossAttackCatalog)
else
	Catalog, Attacks = require("./AnimationCatalog"), require("./BossAttackCatalog")
end

local Rules = {}

export type Source = "Override" | "Custom" | "Stock" | "Procedural"
export type Resolved = { Key: string, Id: string?, Source: Source, Speed: number, Looped: boolean, Priority: string }

-- Paste published ids here ("rbxassetid://<digits>") under the slot key, e.g.
-- ["SovereignWu_P1_SoulSpears"] = "rbxassetid://1234567890". Empty means nothing is authored yet.
Rules.Custom = table.freeze({} :: { [string]: string })

-- Move lists per look and phase (the Twins' survivor also borrows the partner's on the oath).
Rules.Moves = table.freeze({
	GrandmasterShen = { "Shen", "Chimera" }, GeneralZhao = { "Zhao" }, IronBull = { "Bull" },
	VenerableBaize = { "Baize", "Baize" }, SlumberingTitan = { "Titan", "Titan" },
	SovereignWu = { "Wu", "Wu" }, AzureWyrm = { "Wyrm", "Wyrm" },
} :: { [string]: { string } })
Rules.Oath = table.freeze({ GeneralZhao = true, IronBull = true } :: { [string]: boolean })
-- Boss-only melee sets whose every swing is its own clip slot (post-F26 step 6, D1: the Bull's maul and
-- shield). Ids are WeaponSchema's IronBullMaul moves; AIService cues each swing as "BossSwing".
Rules.Melee = table.freeze({
	IronBull = table.freeze({ "IronBullMaul_L1", "IronBullMaul_L2", "IronBullMaul_L3", "IronBullMaul_Heavy", "IronBullMaul_Running", "IronBullMaul_Art" }),
} :: { [string]: { string } })

-- Shen's original catalog slots (and their AsuraBossAnimation_<legacy> attributes) still count.
local LEGACY: { [string]: { Slot: string, Speed: number } } = {
	GrandmasterShen_P1_Idle = { Slot = "Shen_Phase1_Idle", Speed = 1 },
	GrandmasterShen_P2_Idle = { Slot = "Shen_Phase1_Idle", Speed = 1.4 },
	GrandmasterShen_P1_Strike = { Slot = "Shen_Phase1_SwordCombo", Speed = 1 },
	GrandmasterShen_P2_Strike = { Slot = "Shen_Phase2_GlaiveCombo", Speed = 1 },
	GrandmasterShen_P2_Transform = { Slot = "Shen_Phase2_Transform", Speed = 1 },
}

-- Stock stand-in per action/kind: { stock slot in AnimationCatalog.Enemies style, speed }.
local STOCK: { [string]: { string | number } } = {
	Idle = { "ToolHold", 1 }, Transform = { "Cheer", 0.6 }, Strike = { "ToolSlash", 1.25 },
	PerilousThrust = { "ToolLunge", 1.1 }, PerilousGrab = { "ToolLunge", 0.9 }, ShieldCharge = { "ToolLunge", 1 },
	PerilousSweep = { "ToolSlash", 1 }, Tail = { "ToolSlash", 0.9 }, Shockwave = { "ToolSlash", 0.8 }, Leap = { "ToolSlash", 0.8 },
	Barrage = { "Cheer", 1.2 }, Gravity = { "Cheer", 0.8 }, Ritual = { "Cheer", 0.7 }, Breath = { "Cheer", 0.9 },
}
local STOCK_IDS = {
	R15 = { ToolHold = Catalog.Enemies.Shen_Phase1_Idle.Fallback, ToolSlash = Catalog.Enemies.Shen_Phase1_SwordCombo.Fallback,
		ToolLunge = Catalog.Enemies.Shen_Phase2_GlaiveCombo.Fallback, Cheer = Catalog.Enemies.Shen_Phase2_Transform.Fallback },
	R6 = { ToolHold = Catalog.Enemies.Shen_Phase1_Idle.FallbackR6, ToolSlash = Catalog.Enemies.Shen_Phase1_SwordCombo.FallbackR6,
		ToolLunge = Catalog.Enemies.Shen_Phase2_GlaiveCombo.FallbackR6, Cheer = Catalog.Enemies.Shen_Phase2_Transform.FallbackR6 },
}

function Rules.validId(id: any): boolean
	return type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end
for key, id in Rules.Custom do assert(Rules.validId(id), "BossAnimationRules.Custom." .. key .. " must be \"rbxassetid://<digits>\"") end

-- The kind of a catalogued boss move, for stock fallbacks when a cue does not carry it.
local KINDS: { [string]: string } = {}
for _, list in Attacks do for _, move in list do KINDS[move.Id] = move.Kind end end
function Rules.kind(move: string): string? return KINDS[move] end

local function keys(look: string, phase: number, action: string): { string }
	local list = { look .. "_P" .. phase .. "_" .. action, look .. "_" .. action }
	if action ~= "Idle" and action ~= "Transform" and action ~= "Strike" then
		table.insert(list, look .. "_P" .. phase .. "_Strike"); table.insert(list, look .. "_Strike")
	end
	return list
end

-- rig: "R15" | "R6" | "Creature"; attribute reads the actor (nil-safe for pure use).
function Rules.resolve(look: string, phase: number, action: string, kind: string?, rig: string, attribute: (string) -> any): Resolved
	local looped = action == "Idle"
	local priority = if looped then "Idle" elseif action == "Transform" then "Action4" else "Action"
	for _, key in keys(look, phase, action) do
		local legacy = LEGACY[key]
		local override = attribute("AsuraBossAnimation_" .. key)
		if not Rules.validId(override) and legacy then override = attribute("AsuraBossAnimation_" .. legacy.Slot) end
		if Rules.validId(override) then
			return { Key = key, Id = override, Source = "Override", Speed = 1, Looped = looped, Priority = priority }
		end
		local custom = Rules.Custom[key] or (legacy and Catalog.Enemies[legacy.Slot].Custom)
		if custom then
			return { Key = key, Id = custom, Source = "Custom", Speed = if legacy and not Rules.Custom[key] then legacy.Speed else 1, Looped = looped, Priority = priority }
		end
	end
	local key = keys(look, phase, action)[1]
	if rig == "Creature" then
		return { Key = key, Id = nil, Source = "Procedural", Speed = 1, Looped = looped, Priority = priority }
	end
	local stock = STOCK[action] or STOCK[kind or Rules.kind(action) or "Strike"] or STOCK.Strike
	local legacy = LEGACY[look .. "_P" .. phase .. "_" .. action]
	local ids = if rig == "R6" then STOCK_IDS.R6 else STOCK_IDS.R15
	return { Key = key, Id = (ids :: any)[stock[1]], Source = "Stock", Speed = if legacy then legacy.Speed else stock[2] :: number,
		Looped = looped, Priority = priority }
end

-- Every slot this actor can request in a phase.
function Rules.slots(look: string, phase: number): { string }
	local list = { "Idle", "Strike" }
	if phase > 1 or Rules.Oath[look] then table.insert(list, "Transform") end
	local sets = Rules.Moves[look]
	local set = sets and Attacks[sets[math.clamp(phase, 1, #sets)]]
	for _, move in set or {} do table.insert(list, move.Id) end
	for _, id in Rules.Melee[look] or {} do table.insert(list, id) end
	return list
end

-- Honest one-line status for the AsuraAnimationStatus attribute.
function Rules.status(look: string, phase: number, rig: string, attribute: (string) -> any): string
	local slots = Rules.slots(look, phase)
	local authored, missing = 0, nil
	for _, action in slots do
		local r = Rules.resolve(look, phase, action, nil, rig, attribute)
		if r.Source == "Override" or r.Source == "Custom" then authored += 1 elseif not missing then missing = r.Key end
	end
	if authored == #slots then return string.format("Authored %d/%d", authored, #slots) end
	return string.format("Fallback:%s %d/%d authored (first missing %s)", if rig == "Creature" then "CreatureMotion" else "Stock",
		authored, #slots, tostring(missing))
end

return table.freeze(Rules)

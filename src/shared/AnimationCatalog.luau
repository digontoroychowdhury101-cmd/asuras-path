--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/AnimationCatalog
-- Single source of truth for every animation slot in Asura's Path.
--
-- SWAPPING IN CUSTOM ANIMATIONS
--   1. Publish the animation to Roblox (Avatar > Animation Editor > Publish to Roblox) under the
--      account or group that owns this experience; Roblox only plays animations the owner can use.
--   2. Paste its id into that slot's `Custom` field below, e.g. Custom = "rbxassetid://1234567890".
--      Leave `Custom = nil` to keep the stock fallback.
--   3. Run `work/bin/luau/luau tools/test_asura_stage1.luau` (which loads this module) or start
--      Play: the catalog validates every id at require time and reports the slot that is wrong.
--
-- FALLBACKS
--   `Fallback` ids are Roblox's own R15 Animate-script animations (idle, tool hold/slash/lunge,
--   fall, jump, sit, cheer); `FallbackR6` are the R6 equivalents. They exist so no rig ever
--   T-poses while custom work is pending. They are stand-ins only: the stock library contains
--   no rolls, parries or glaive strings, so each fallback is the closest stock motion.
--
-- Callers should resolve through `Catalog.resolve`/`Catalog.weapon` rather than reading fields,
-- so custom ids, rig type and weapon fallbacks are applied consistently.

export type Priority = "Core" | "Idle" | "Movement" | "Action" | "Action2" | "Action3" | "Action4"
export type Rig = "R15" | "R6"
export type WeaponName = "Unarmed" | "Jian" | "Dao" | "Guandao"

export type Slot = {
	Name: string,
	-- Your published animation ("rbxassetid://<id>"). nil plays the stock fallback.
	Custom: string?,
	Fallback: string,
	FallbackR6: string,
	Looped: boolean,
	Priority: Priority,
	-- Playback speed applied to the fallback only; custom animations play at their authored speed.
	FallbackSpeed: number,
}

export type UniversalKey =
	"Roll"
	| "Backdash"
	| "Deflect"
	| "Hitstun_Light"
	| "Hitstun_Heavy"
	| "StanceBroken"
	| "Deathblow_Attacker"
	| "Deathblow_Victim"
	| "AltarRest"

export type WeaponKey = "Idle" | "Equip" | "Light1" | "Light2" | "Light3" | "Light4" | "Heavy" | "WeaponArt"

export type EnemyKey = "Shen_Phase1_Idle" | "Shen_Phase1_SwordCombo" | "Shen_Phase2_Transform" | "Shen_Phase2_GlaiveCombo"

local Catalog = {}

-------------------------------------------------------------------------------------------------
-- Stock Roblox animations (owned by Roblox, playable in every experience)
-------------------------------------------------------------------------------------------------

type StockName = "Idle" | "IdleLook" | "Jump" | "Fall" | "ToolHold" | "ToolSlash" | "ToolLunge" | "Sit" | "Cheer"
type StockSet = { [StockName]: string }

local STOCK: { R15: StockSet, R6: StockSet } = table.freeze({
	R15 = table.freeze({
		Idle = "rbxassetid://507766666",
		IdleLook = "rbxassetid://507766951",
		Jump = "rbxassetid://507765000",
		Fall = "rbxassetid://507767968",
		ToolHold = "rbxassetid://507768375",
		ToolSlash = "rbxassetid://522635514",
		ToolLunge = "rbxassetid://522638767",
		Sit = "rbxassetid://2506281703",
		Cheer = "rbxassetid://507770677",
	}),
	R6 = table.freeze({
		Idle = "rbxassetid://180435571",
		IdleLook = "rbxassetid://180435792",
		Jump = "rbxassetid://125750702",
		Fall = "rbxassetid://180436148",
		ToolHold = "rbxassetid://182393478",
		ToolSlash = "rbxassetid://129967390",
		ToolLunge = "rbxassetid://129967478",
		Sit = "rbxassetid://178130996",
		Cheer = "rbxassetid://129423030",
	}),
}) :: any

local function slot(name: string, custom: string?, stock: StockName, looped: boolean, priority: Priority, speed: number?): Slot
	return {
		Name = name,
		Custom = custom,
		Fallback = STOCK.R15[stock],
		FallbackR6 = STOCK.R6[stock],
		Looped = looped,
		Priority = priority,
		FallbackSpeed = speed or 1,
	}
end

-------------------------------------------------------------------------------------------------
-- Universal actions (every fighter, any weapon)
-- Swap ids in the second argument.
-------------------------------------------------------------------------------------------------

Catalog.Universal = {
	Roll = slot("Roll", nil, "Fall", false, "Action2", 1.6),
	Backdash = slot("Backdash", nil, "Jump", false, "Action2", 1.4),
	Deflect = slot("Deflect", nil, "ToolHold", false, "Action3", 1.8),
	Hitstun_Light = slot("Hitstun_Light", nil, "Fall", false, "Action3", 2.0),
	Hitstun_Heavy = slot("Hitstun_Heavy", nil, "Fall", false, "Action3", 1.2),
	StanceBroken = slot("StanceBroken", nil, "Sit", true, "Action4", 1),
	Deathblow_Attacker = slot("Deathblow_Attacker", nil, "ToolLunge", false, "Action4", 0.7),
	Deathblow_Victim = slot("Deathblow_Victim", nil, "Sit", false, "Action4", 1),
	AltarRest = slot("AltarRest", nil, "Sit", true, "Action", 1),
} :: { [UniversalKey]: Slot }

-------------------------------------------------------------------------------------------------
-- Per-weapon movesets. Guandao's light string is three hits; its Light4 slot is reserved for a
-- future fourth hit and is never requested by the current move data.
-------------------------------------------------------------------------------------------------

Catalog.Weapons = {
	Unarmed = {
		Idle = slot("Unarmed.Idle", nil, "Idle", true, "Idle"),
		Equip = slot("Unarmed.Equip", nil, "IdleLook", false, "Action", 1.5),
		Light1 = slot("Unarmed.Light1", nil, "ToolSlash", false, "Action", 1.6),
		Light2 = slot("Unarmed.Light2", nil, "ToolLunge", false, "Action", 1.6),
		Light3 = slot("Unarmed.Light3", nil, "ToolSlash", false, "Action", 1.5),
		Light4 = slot("Unarmed.Light4", nil, "ToolLunge", false, "Action", 1.3),
		Heavy = slot("Unarmed.Heavy", nil, "ToolLunge", false, "Action", 0.9),
		WeaponArt = slot("Unarmed.WeaponArt", nil, "ToolSlash", false, "Action2", 0.8),
	},
	Jian = {
		Idle = slot("Jian.Idle", nil, "ToolHold", true, "Idle"),
		Equip = slot("Jian.Equip", nil, "ToolHold", false, "Action", 1.5),
		Light1 = slot("Jian.Light1", nil, "ToolSlash", false, "Action", 1.4),
		Light2 = slot("Jian.Light2", nil, "ToolSlash", false, "Action", 1.5),
		Light3 = slot("Jian.Light3", nil, "ToolLunge", false, "Action", 1.4),
		Light4 = slot("Jian.Light4", nil, "ToolSlash", false, "Action", 1.2),
		Heavy = slot("Jian.Heavy", nil, "ToolLunge", false, "Action", 0.85),
		WeaponArt = slot("Jian.WeaponArt", nil, "ToolLunge", false, "Action2", 0.7),
	},
	Dao = {
		Idle = slot("Dao.Idle", nil, "ToolHold", true, "Idle"),
		Equip = slot("Dao.Equip", nil, "ToolHold", false, "Action", 1.4),
		Light1 = slot("Dao.Light1", nil, "ToolSlash", false, "Action", 1.3),
		Light2 = slot("Dao.Light2", nil, "ToolSlash", false, "Action", 1.35),
		Light3 = slot("Dao.Light3", nil, "ToolSlash", false, "Action", 1.25),
		Light4 = slot("Dao.Light4", nil, "ToolLunge", false, "Action", 1.1),
		Heavy = slot("Dao.Heavy", nil, "ToolSlash", false, "Action", 0.8),
		WeaponArt = slot("Dao.WeaponArt", nil, "ToolSlash", false, "Action2", 0.65),
	},
	Guandao = {
		Idle = slot("Guandao.Idle", nil, "ToolHold", true, "Idle"),
		Equip = slot("Guandao.Equip", nil, "ToolHold", false, "Action", 1.2),
		Light1 = slot("Guandao.Light1", nil, "ToolSlash", false, "Action", 1.1),
		Light2 = slot("Guandao.Light2", nil, "ToolLunge", false, "Action", 1.1),
		Light3 = slot("Guandao.Light3", nil, "ToolSlash", false, "Action", 1.0),
		Light4 = slot("Guandao.Light4", nil, "ToolLunge", false, "Action", 1.0),
		Heavy = slot("Guandao.Heavy", nil, "ToolLunge", false, "Action", 0.7),
		WeaponArt = slot("Guandao.WeaponArt", nil, "ToolSlash", false, "Action2", 0.6),
	},
} :: { [WeaponName]: { [WeaponKey]: Slot } }

-------------------------------------------------------------------------------------------------
-- Enemy-specific animations
-------------------------------------------------------------------------------------------------

Catalog.Enemies = {
	Shen_Phase1_Idle = slot("Shen_Phase1_Idle", nil, "ToolHold", true, "Idle"),
	Shen_Phase1_SwordCombo = slot("Shen_Phase1_SwordCombo", nil, "ToolSlash", false, "Action", 1.25),
	Shen_Phase2_Transform = slot("Shen_Phase2_Transform", nil, "Cheer", false, "Action4", 0.6),
	Shen_Phase2_GlaiveCombo = slot("Shen_Phase2_GlaiveCombo", nil, "ToolLunge", false, "Action", 1.0),
} :: { [EnemyKey]: Slot }

Catalog.UniversalKeys = table.freeze({
	"Roll",
	"Backdash",
	"Deflect",
	"Hitstun_Light",
	"Hitstun_Heavy",
	"StanceBroken",
	"Deathblow_Attacker",
	"Deathblow_Victim",
	"AltarRest",
} :: { UniversalKey })
Catalog.WeaponNames = table.freeze({ "Unarmed", "Jian", "Dao", "Guandao" } :: { WeaponName })
Catalog.WeaponKeys = table.freeze({ "Idle", "Equip", "Light1", "Light2", "Light3", "Light4", "Heavy", "WeaponArt" } :: { WeaponKey })
Catalog.EnemyKeys = table.freeze({
	"Shen_Phase1_Idle",
	"Shen_Phase1_SwordCombo",
	"Shen_Phase2_Transform",
	"Shen_Phase2_GlaiveCombo",
} :: { EnemyKey })

-------------------------------------------------------------------------------------------------
-- Resolution
-------------------------------------------------------------------------------------------------

-- The id to load for a slot on the given rig: the custom id when set, else the stock fallback.
function Catalog.resolve(entry: Slot, rig: Rig?): string
	local custom = entry.Custom
	if custom then
		return custom
	end
	return if rig == "R6" then entry.FallbackR6 else entry.Fallback
end

-- Playback speed for a slot: authored speed for custom ids, tuned speed for stock stand-ins.
function Catalog.speed(entry: Slot): number
	return if entry.Custom then 1 else entry.FallbackSpeed
end

function Catalog.isCustom(entry: Slot): boolean
	return entry.Custom ~= nil
end

function Catalog.universal(key: UniversalKey): Slot
	return Catalog.Universal[key]
end

-- Weapon slot lookup; unknown weapons use the Unarmed set so a new weapon never T-poses.
function Catalog.weapon(weapon: string, key: WeaponKey): Slot
	local set = Catalog.Weapons[weapon :: WeaponName] or Catalog.Weapons.Unarmed
	return set[key]
end

-- Light-string slot for a 1-based combo index, clamped to the four authored hits.
function Catalog.light(weapon: string, index: number): Slot
	local clamped = math.clamp(math.floor(index), 1, 4)
	return Catalog.weapon(weapon, ("Light" .. clamped) :: any)
end

function Catalog.enemy(key: EnemyKey): Slot
	return Catalog.Enemies[key]
end

-- Every slot still playing a stock fallback, for content audits.
function Catalog.pending(): { string }
	local result: { string } = {}
	for _, key in Catalog.UniversalKeys do
		if not Catalog.Universal[key].Custom then
			table.insert(result, Catalog.Universal[key].Name)
		end
	end
	for _, weapon in Catalog.WeaponNames do
		for _, key in Catalog.WeaponKeys do
			local entry = Catalog.Weapons[weapon][key]
			if not entry.Custom then
				table.insert(result, entry.Name)
			end
		end
	end
	for _, key in Catalog.EnemyKeys do
		if not Catalog.Enemies[key].Custom then
			table.insert(result, Catalog.Enemies[key].Name)
		end
	end
	return result
end

-- Every distinct id the catalog can resolve to on a rig, for ContentProvider preloading.
function Catalog.allIds(rig: Rig?): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	local function add(entry: Slot)
		local id = Catalog.resolve(entry, rig)
		if not seen[id] then
			seen[id] = true
			table.insert(result, id)
		end
	end
	for _, entry in Catalog.Universal do
		add(entry)
	end
	for _, set in Catalog.Weapons do
		for _, entry in set do
			add(entry)
		end
	end
	for _, entry in Catalog.Enemies do
		add(entry)
	end
	table.sort(result)
	return result
end

-------------------------------------------------------------------------------------------------
-- Validation (runs at require time)
-------------------------------------------------------------------------------------------------

local PRIORITIES: { [string]: boolean } = {
	Core = true,
	Idle = true,
	Movement = true,
	Action = true,
	Action2 = true,
	Action3 = true,
	Action4 = true,
}

local function validId(id: any): boolean
	return type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

local function check(entry: Slot?, label: string)
	assert(entry ~= nil, "AnimationCatalog is missing slot " .. label)
	assert(entry.Custom == nil or validId(entry.Custom), "AnimationCatalog." .. label .. ".Custom must be \"rbxassetid://<digits>\"")
	assert(validId(entry.Fallback) and validId(entry.FallbackR6), "AnimationCatalog." .. label .. " has an invalid fallback id")
	assert(PRIORITIES[entry.Priority], "AnimationCatalog." .. label .. " has an unknown priority")
	assert(entry.FallbackSpeed > 0 and entry.FallbackSpeed <= 4, "AnimationCatalog." .. label .. " fallback speed out of range")
end

for _, key in Catalog.UniversalKeys do
	check(Catalog.Universal[key], "Universal." .. key)
end
for _, weapon in Catalog.WeaponNames do
	assert(Catalog.Weapons[weapon] ~= nil, "AnimationCatalog is missing weapon " .. weapon)
	for _, key in Catalog.WeaponKeys do
		check(Catalog.Weapons[weapon][key], "Weapons." .. weapon .. "." .. key)
	end
end
for _, key in Catalog.EnemyKeys do
	check(Catalog.Enemies[key], "Enemies." .. key)
end

local function deepFreeze(value: any)
	if type(value) ~= "table" or table.isfrozen(value) then
		return
	end
	for _, child in value do
		deepFreeze(child)
	end
	table.freeze(value)
end
deepFreeze(Catalog.Universal)
deepFreeze(Catalog.Weapons)
deepFreeze(Catalog.Enemies)

return table.freeze(Catalog)

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
export type WeaponName = "Unarmed" | "Jian" | "Dao" | "Guandao" | "Odachi" | "TwinDaggers" | "ChainScythe" | "WarFan" | "Catalyst" | "PrayerOfTheDefiled" | "HeavenPiercingGuandao"

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
	| "DashForward"
	| "DashLeft"
	| "DashRight"
	| "Backdash"
	| "Deflect"
	| "Hitstun_Light"
	| "Hitstun_Heavy"
	| "StanceBroken"
	| "Deathblow_Attacker"
	| "Deathblow_Victim"
	| "AltarRest"
	| "Recover"

export type WeaponKey = "Idle" | "Move" | "Equip" | "Light1" | "Light2" | "Light3" | "Light4" | "Heavy" | "Running" | "WeaponArt" | "Guard" | "GuardImpact"

export type EnemyKey = "Shen_Phase1_Idle" | "Shen_Phase1_SwordCombo" | "Shen_Phase2_Transform" | "Shen_Phase2_GlaiveCombo"

local Catalog = {}
local hasScript = pcall(function()
	return script.Parent
end)
local Families: any = if hasScript then require(script.Parent.AnimationFamilyIds) else require("./AnimationFamilyIds")

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
	Roll = slot("Roll", "rbxassetid://76668598902693", "Fall", false, "Action2", 1.6),
	DashForward = slot("DashForward", nil, "Fall", false, "Action2", 1.6),
	DashLeft = slot("DashLeft", nil, "Fall", false, "Action2", 1.6),
	DashRight = slot("DashRight", nil, "Fall", false, "Action2", 1.6),
	Backdash = slot("Backdash", "rbxassetid://135695988461681", "Jump", false, "Action2", 1.4),
	Deflect = slot("Deflect", "rbxassetid://111115189726174", "ToolHold", false, "Action3", 1.8),
	Hitstun_Light = slot("Hitstun_Light", "rbxassetid://74668214273745", "Fall", false, "Action3", 2.0),
	Hitstun_Heavy = slot("Hitstun_Heavy", "rbxassetid://139439892303244", "Fall", false, "Action3", 1.2),
	StanceBroken = slot("StanceBroken", "rbxassetid://120106199751337", "Sit", true, "Action4", 1),
	Deathblow_Attacker = slot("Deathblow_Attacker", nil, "ToolLunge", false, "Action4", 0.7),
	Deathblow_Victim = slot("Deathblow_Victim", nil, "Sit", false, "Action4", 1),
	AltarRest = slot("AltarRest", nil, "Sit", true, "Action", 1),
	Recover = slot("Recover", "rbxassetid://129007326029291", "IdleLook", false, "Action3", 1.4),
} :: { [UniversalKey]: Slot }

-------------------------------------------------------------------------------------------------
-- Per-weapon movesets. Guandao's light string is three hits; its Light4 slot is reserved for a
-- future fourth hit and is never requested by the current move data. Idle is the full-body ready
-- stance while standing; Move is an arms-only carry layered over Roblox's walk/run; Guard is
-- upper-body only, so a guarding fighter can still walk. Client playback: FighterAnimations, which
-- plays only authored (Custom) slots and leaves stock stand-ins off.
-------------------------------------------------------------------------------------------------

Catalog.Weapons = {
	Unarmed = {
		Idle = slot("Unarmed.Idle", nil, "Idle", true, "Idle"),
		Move = slot("Unarmed.Move", nil, "ToolHold", true, "Movement"),
		Equip = slot("Unarmed.Equip", nil, "IdleLook", false, "Action", 1.5),
		Light1 = slot("Unarmed.Light1", nil, "ToolSlash", false, "Action", 1.6),
		Light2 = slot("Unarmed.Light2", nil, "ToolLunge", false, "Action", 1.6),
		Light3 = slot("Unarmed.Light3", nil, "ToolSlash", false, "Action", 1.5),
		Light4 = slot("Unarmed.Light4", nil, "ToolLunge", false, "Action", 1.3),
		Heavy = slot("Unarmed.Heavy", nil, "ToolLunge", false, "Action", 0.9),
		Running = slot("Unarmed.Running", nil, "ToolLunge", false, "Action", 1.0),
		WeaponArt = slot("Unarmed.WeaponArt", nil, "ToolSlash", false, "Action2", 0.8),
		Guard = slot("Unarmed.Guard", nil, "ToolHold", true, "Action"),
		GuardImpact = slot("Unarmed.GuardImpact", nil, "ToolHold", false, "Action2", 1.5),
	},
	Jian = {
		Idle = slot("Jian.Idle", "rbxassetid://97729334147895", "ToolHold", true, "Movement"),
		Move = slot("Jian.Move", "rbxassetid://135406303189832", "ToolHold", true, "Movement"),
		Equip = slot("Jian.Equip", "rbxassetid://138487014275939", "ToolHold", false, "Action", 1.5),
		Light1 = slot("Jian.Light1", "rbxassetid://87800015669250", "ToolSlash", false, "Action2", 1.4),
		Light2 = slot("Jian.Light2", "rbxassetid://113542530241474", "ToolSlash", false, "Action2", 1.5),
		Light3 = slot("Jian.Light3", "rbxassetid://115589583211296", "ToolLunge", false, "Action2", 1.4),
		Light4 = slot("Jian.Light4", "rbxassetid://88372590503565", "ToolSlash", false, "Action2", 1.2),
		Heavy = slot("Jian.Heavy", "rbxassetid://137612205425483", "ToolLunge", false, "Action2", 0.85),
		Running = slot("Jian.Running", "rbxassetid://124446470934584", "ToolLunge", false, "Action2", 1.0),
		WeaponArt = slot("Jian.WeaponArt", "rbxassetid://96229215657784", "ToolLunge", false, "Action2", 0.7),
		Guard = slot("Jian.Guard", "rbxassetid://71182885805704", "ToolHold", true, "Action"),
		GuardImpact = slot("Jian.GuardImpact", "rbxassetid://76420751200151", "ToolHold", false, "Action3", 1.5),
	},
	Dao = {
		Idle = slot("Dao.Idle", nil, "ToolHold", true, "Idle"),
		Move = slot("Dao.Move", nil, "ToolHold", true, "Movement"),
		Equip = slot("Dao.Equip", nil, "ToolHold", false, "Action", 1.4),
		Light1 = slot("Dao.Light1", nil, "ToolSlash", false, "Action", 1.3),
		Light2 = slot("Dao.Light2", nil, "ToolSlash", false, "Action", 1.35),
		Light3 = slot("Dao.Light3", nil, "ToolSlash", false, "Action", 1.25),
		Light4 = slot("Dao.Light4", nil, "ToolLunge", false, "Action", 1.1),
		Heavy = slot("Dao.Heavy", nil, "ToolSlash", false, "Action", 0.8),
		Running = slot("Dao.Running", nil, "ToolLunge", false, "Action", 1.0),
		WeaponArt = slot("Dao.WeaponArt", nil, "ToolSlash", false, "Action2", 0.65),
		Guard = slot("Dao.Guard", nil, "ToolHold", true, "Action"),
		GuardImpact = slot("Dao.GuardImpact", nil, "ToolHold", false, "Action2", 1.5),
	},
	Guandao = {
		Idle = slot("Guandao.Idle", nil, "ToolHold", true, "Idle"),
		Move = slot("Guandao.Move", nil, "ToolHold", true, "Movement"),
		Equip = slot("Guandao.Equip", nil, "ToolHold", false, "Action", 1.2),
		Light1 = slot("Guandao.Light1", nil, "ToolSlash", false, "Action", 1.1),
		Light2 = slot("Guandao.Light2", nil, "ToolLunge", false, "Action", 1.1),
		Light3 = slot("Guandao.Light3", nil, "ToolSlash", false, "Action", 1.0),
		Light4 = slot("Guandao.Light4", nil, "ToolLunge", false, "Action", 1.0),
		Heavy = slot("Guandao.Heavy", nil, "ToolLunge", false, "Action", 0.7),
		Running = slot("Guandao.Running", nil, "ToolLunge", false, "Action", 1.0),
		WeaponArt = slot("Guandao.WeaponArt", nil, "ToolSlash", false, "Action2", 0.6),
		Guard = slot("Guandao.Guard", nil, "ToolHold", true, "Action"),
		GuardImpact = slot("Guandao.GuardImpact", nil, "ToolHold", false, "Action2", 1.5),
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

-------------------------------------------------------------------------------------------------
-- Per-character sets for production enemies, keyed by the fighter's AsuraDefinition. A character's
-- authored slot replaces the weapon or universal slot of the same key; a key it lacks (or one not yet
-- published) falls back to the weapon set, so dodges and deflects stay shared. Death plays on KO and
-- holds its last frame until the corpse dissolves. Timings are authored against the definition's
-- weapon at 1.4x tempo (tools/animation/opening_cast).
-------------------------------------------------------------------------------------------------

export type CharacterKey = WeaponKey | "Hitstun_Light" | "Hitstun_Heavy" | "StanceBroken" | "Death" | "Signature" | "Walk" | "Run"

local function character(definition: string, ids: { [string]: string }): { [CharacterKey]: Slot }
	local function c(key: string, stock: StockName, looped: boolean, priority: Priority): Slot
		return slot(definition .. "." .. key, ids[key], stock, looped, priority)
	end
	return {
		Idle = c("Idle", "Idle", true, "Idle"),
		Move = c("Move", "ToolHold", true, "Movement"),
		Light1 = c("Light1", "ToolSlash", false, "Action2"),
		Light2 = c("Light2", "ToolSlash", false, "Action2"),
		Light3 = c("Light3", "ToolSlash", false, "Action2"),
		Light4 = c("Light4", "ToolLunge", false, "Action2"),
		Heavy = c("Heavy", "ToolLunge", false, "Action2"),
		Running = c("Running", "ToolLunge", false, "Action2"),
		WeaponArt = c("WeaponArt", "ToolSlash", false, "Action2"),
		Guard = c("Guard", "ToolHold", true, "Action"),
		GuardImpact = c("GuardImpact", "ToolHold", false, "Action3"),
		Hitstun_Light = c("Hitstun_Light", "Fall", false, "Action3"),
		Hitstun_Heavy = c("Hitstun_Heavy", "Fall", false, "Action3"),
		StanceBroken = c("StanceBroken", "Sit", true, "Action4"),
		Death = c("Death", "Sit", false, "Action4"),
		-- Optional: a foe's signature move (World.Mobs[...].Signature), contact at its shockwave's Windup.
		Signature = if ids.Signature then c("Signature", "ToolLunge", false, "Action2") else nil,
		-- Optional: full-body in-place gait cycles (a foe has no Animate script to move its legs); played at the
		-- measured ground speed over Catalog.Gaits[definition] so the planted feet hold the ground.
		Walk = if ids.Walk then c("Walk", "ToolHold", true, "Movement") else nil,
		Run = if ids.Run then c("Run", "ToolHold", true, "Movement") else nil,
	} :: any
end

-- Published ids per character (tools/animation/opening_cast/<key>/published.json mirrors these).
Catalog.Characters = {
	CorruptWanderingMonk = character("CorruptWanderingMonk", {
		Death = "rbxassetid://82065381623710",
		Guard = "rbxassetid://89391756631562",
		GuardImpact = "rbxassetid://96590951733793",
		Heavy = "rbxassetid://76312818754143",
		Hitstun_Heavy = "rbxassetid://71073626356373",
		Hitstun_Light = "rbxassetid://81542772922509",
		Idle = "rbxassetid://101598140758714",
		Light1 = "rbxassetid://90748494920364",
		Light2 = "rbxassetid://76346092169919",
		Light3 = "rbxassetid://108062301374603",
		Light4 = "rbxassetid://103272727896878",
		Move = "rbxassetid://112262064404137",
		Run = "rbxassetid://81883804287252",
		Running = "rbxassetid://115921357540400",
		StanceBroken = "rbxassetid://108521705818233",
		Walk = "rbxassetid://119439610866025",
		WeaponArt = "rbxassetid://135854349242310",
	}),
	CursedSwordsman = character("CursedSwordsman", {
		Death = "rbxassetid://97875436719077",
		Guard = "rbxassetid://130795857635813",
		GuardImpact = "rbxassetid://72996160202085",
		Heavy = "rbxassetid://71766330781056",
		Hitstun_Heavy = "rbxassetid://85881768455696",
		Hitstun_Light = "rbxassetid://79845182367548",
		Idle = "rbxassetid://92733401704195",
		Light1 = "rbxassetid://137250040297302",
		Light2 = "rbxassetid://137835669576121",
		Light3 = "rbxassetid://81317418914365",
		Light4 = "rbxassetid://108101370082647",
		Move = "rbxassetid://75315756560710",
		Run = "rbxassetid://110196475389156",
		Running = "rbxassetid://93013217748649",
		StanceBroken = "rbxassetid://92933887269942",
		Walk = "rbxassetid://122806607020356",
		WeaponArt = "rbxassetid://125540053579064",
	}),
	-- The Guandao chain is three lights long: Light4 never plays, it shares the cleave's clip.
	HollowBellWarden = character("HollowBellWarden", {
		Death = "rbxassetid://135796526374193",
		Guard = "rbxassetid://111594189369970",
		GuardImpact = "rbxassetid://89274945535822",
		Heavy = "rbxassetid://125815452854563",
		Hitstun_Heavy = "rbxassetid://120364294554446",
		Hitstun_Light = "rbxassetid://123540264050232",
		Idle = "rbxassetid://124722344286007",
		Light1 = "rbxassetid://139901685924316",
		Light2 = "rbxassetid://95901465911475",
		Light3 = "rbxassetid://85593628340035",
		Light4 = "rbxassetid://85593628340035",
		Move = "rbxassetid://113707235032422",
		Run = "rbxassetid://92072596908213",
		Running = "rbxassetid://80666322516323",
		Signature = "rbxassetid://121126042509475",
		StanceBroken = "rbxassetid://89400894565036",
		Walk = "rbxassetid://92491485517905",
		WeaponArt = "rbxassetid://105743978323726",
	}),
} :: { [string]: { [CharacterKey]: Slot } }
-- Ground speed (studs/s at model scale 1) each gait cycle was authored for (monk_clips.py, swordsman_clips.py, warden_clips.py WALK_SPEED/RUN_SPEED).
Catalog.Gaits = {
	CorruptWanderingMonk = { Walk = 6.4, Run = 11.0 },
	CursedSwordsman = { Walk = 6.4, Run = 11.0 },
	HollowBellWarden = { Walk = 5.6, Run = 9.5 },
} :: { [string]: { Walk: number, Run: number? } }
Catalog.CharacterKeys = table.freeze({ "Idle", "Move", "Light1", "Light2", "Light3", "Light4", "Heavy", "Running", "WeaponArt",
	"Guard", "GuardImpact", "Hitstun_Light", "Hitstun_Heavy", "StanceBroken", "Death" } :: { CharacterKey })

Catalog.UniversalKeys = table.freeze({
	"Roll",
	"DashForward",
	"DashLeft",
	"DashRight",
	"Backdash",
	"Deflect",
	"Hitstun_Light",
	"Hitstun_Heavy",
	"StanceBroken",
	"Deathblow_Attacker",
	"Deathblow_Victim",
	"AltarRest",
	"Recover",
} :: { UniversalKey })
Catalog.WeaponNames = table.freeze({ "Unarmed", "Jian", "Dao", "Guandao", "Odachi", "TwinDaggers", "ChainScythe", "WarFan", "Catalyst", "PrayerOfTheDefiled", "HeavenPiercingGuandao" } :: { WeaponName })
Catalog.WeaponKeys = table.freeze({ "Idle", "Move", "Equip", "Light1", "Light2", "Light3", "Light4", "Heavy", "Running", "WeaponArt", "Guard", "GuardImpact" } :: { WeaponKey })

-- The published family and universal clips (AnimationFamilyIds, read back after upload). Every set takes its priorities,
-- looping and stock stand-ins from the Jian's, the set the rest were authored to match; a clip not yet published stays nil.
for _, weapon in Catalog.WeaponNames do
	if weapon ~= "Jian" then
		local ids = (Families.Weapons :: any)[weapon] or {}
		local set = {}
		for _, key in Catalog.WeaponKeys do
			local model = (Catalog.Weapons.Jian :: any)[key]
			set[key] = table.clone(model)
			set[key].Name = weapon .. "." .. key
			set[key].Custom = ids[key]
		end
		(Catalog.Weapons :: any)[weapon] = set
	end
end
for key, id in Families.Universal :: any do
	(Catalog.Universal :: any)[key].Custom = id
end
Catalog.EnemyKeys = table.freeze({
	"Shen_Phase1_Idle",
	"Shen_Phase1_SwordCombo",
	"Shen_Phase2_Transform",
	"Shen_Phase2_GlaiveCombo",
} :: { EnemyKey })

-------------------------------------------------------------------------------------------------
-- Resolution
-------------------------------------------------------------------------------------------------

-- The id to load for a slot on the given rig: the custom id when set (authored on R15, so R6 rigs keep
-- their stock stand-in), else the stock fallback.
function Catalog.resolve(entry: Slot, rig: Rig?): string
	local custom = entry.Custom
	if custom and rig ~= "R6" then
		return custom
	end
	return if rig == "R6" then entry.FallbackR6 else entry.Fallback
end

-- Playback speed for a slot: authored speed for custom ids, tuned speed for stock stand-ins.
function Catalog.speed(entry: Slot, rig: Rig?): number
	return if entry.Custom and rig ~= "R6" then 1 else entry.FallbackSpeed
end

function Catalog.isCustom(entry: Slot): boolean
	return entry.Custom ~= nil
end

function Catalog.universal(key: UniversalKey): Slot
	return Catalog.Universal[key]
end

-- Weapon slot lookup; unknown weapons use the Unarmed set so a new weapon never T-poses.
function Catalog.weapon(weapon: string, key: WeaponKey): Slot
	-- Each weapon has its own set, except the Bone Cleaver: the Odachi's blade, grip and frame data exactly, so its clips.
	local family = if weapon == "CalamityBoneCleaver" then "Odachi" else weapon
	local set = Catalog.Weapons[family :: WeaponName] or Catalog.Weapons.Unarmed
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

-- The character's own slot for a key, or nil when the definition has no set or lacks the key.
function Catalog.character(definition: string?, key: string): Slot?
	local set = if definition then Catalog.Characters[definition] else nil
	return if set then (set :: any)[key] else nil
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
	for _, set in Catalog.Characters do
		for _, entry in set do
			if entry.Custom then
				add(entry)
			end
		end
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
for definition, set in Catalog.Characters do
	for _, key in Catalog.CharacterKeys do
		check(set[key], "Characters." .. definition .. "." .. key)
	end
	for _, key in { "Walk", "Run" } do
		if (set :: any)[key] then
			check((set :: any)[key], "Characters." .. definition .. "." .. key)
			assert(Catalog.Gaits[definition] and (Catalog.Gaits[definition] :: any)[key], "Characters." .. definition .. "." .. key .. " has no authored gait speed")
		end
	end
	if set.Signature then
		check(set.Signature, "Characters." .. definition .. ".Signature")
	end
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
deepFreeze(Catalog.Characters)

return table.freeze(Catalog)

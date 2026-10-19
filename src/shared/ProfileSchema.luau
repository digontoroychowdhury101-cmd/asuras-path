--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/ProfileSchema
-- Server-authoritative data schema, migration rules, and integrity validation for player persistence.

local hasScript = pcall(function() return script.Parent end)
local RPG: any = if hasScript then require(script.Parent.Shared.RPGProfile) else require("./RPGProfile")

export type StyleEntry = {
	unlocked: boolean,
	xp: number,
	level: number,
}

export type Profile = {
	schemaVersion: number,
	userId: number,
	elo: number,
	peakElo: number,
	wins: number,
	losses: number,
	draws: number,
	winStreak: number,
	qiEssence: number,
	attributes: {[string]: number},
	inventory: {Weapons: {[string]: {Level: number, Infusion: string?}}, Spells: {[string]: boolean}, Materials: {[string]: number}, LoreEntries: {[string]: boolean}},
	equippedLoadout: {MainWeapon: string, OffWeapon: string?, SpellSlot1: string?, SpellSlot2: string?, ArmorSet: string?},
	defeatedBosses: {[string]: boolean}, unlockedAltars: {[string]: boolean},
	colosseum: {Elo: number, Rank: string, Wins: number, Losses: number, WinStreak: number},
	weaponMastery: {[string]: number}, arenaWagers: {[string]: {Fighter: number, Amount: number, State: string}},
	styleSpins: number,
	pityCounter: number,
	activeStyle: string,
	styles: { [string]: StyleEntry },
	ownedCosmetics: { [string]: boolean },
	equippedCosmetics: {
		Trunks: string,
		Gloves: string,
		Taunt: string, Wrap: string, Accessory: string, Skin: string, Hair: string,
	},
	settings: {
		fov: number,
		sensitivity: number,
		leftHanded: boolean, keybinds: {[string]: string},
	},
	lastSaveTime: number,
 receipts: {[string]: number}, appliedMatches: {[string]: boolean}, pendingMatches: {[string]: boolean},
}

local ProfileSchema = {}

local CURRENT_SCHEMA_VERSION = 4
local DEFAULT_ELO = 1000

function ProfileSchema.Level(xp: number): number
 local level=1
 for i,threshold in {0,500,1500,3500,7500} do if xp>=threshold then level=i end end
 return level
end

function ProfileSchema.Default(userId: number): Profile
	local profile: any = {
		schemaVersion = CURRENT_SCHEMA_VERSION,
		userId = userId,
		elo = DEFAULT_ELO,
		peakElo = DEFAULT_ELO,
		wins = 0,
		losses = 0,
		draws = 0,
		winStreak = 0,
		styleSpins = 5,  -- 5 free initial rolls
		pityCounter = 0,
		activeStyle = "Ironline",
		styles = {
			Ironline = { unlocked = true, xp = 0, level = 1 },
			Groundforge = { unlocked = false, xp = 0, level = 1 },
			ApexStriker = { unlocked = false, xp = 0, level = 1 },
			CobraFlow = { unlocked = false, xp = 0, level = 1 },
			DragonClaw = { unlocked = false, xp = 0, level = 1 },
		},
		ownedCosmetics = {
			Trunks_Charcoal = true,
			Gloves_Black = true,
			Taunt_Bow = true, Wrap_White = true, Accessory_None = true, Skin_Tan = true, Skin_Light = true, Skin_Deep = true, Hair_Crop = true, Hair_None = true, Hair_Sweep = true,
		},
		equippedCosmetics = {
			Trunks = "Trunks_Charcoal",
			Gloves = "Gloves_Black",
			Taunt = "Taunt_Bow", Wrap="Wrap_White", Accessory="Accessory_None", Skin="Skin_Tan", Hair="Hair_Crop",
		},
		settings = {
			fov = 70,
			sensitivity = 1.0,
			leftHanded = false, keybinds = {},
		},
		lastSaveTime = 0, receipts = {}, appliedMatches = {}, pendingMatches = {},
	}
	RPG.apply(profile, nil)
	return profile
end

-- Storage bounds preserve exact integer arithmetic; these are not progression caps.
local MAX_SAFE_INTEGER = 9007199254740991
local MAX_ELO = 5000
local MAX_STYLE_LEVEL = 5
local MAX_IDENTIFIER_LENGTH = 64
local MIN_FOV, MAX_FOV = 70, 90
local MIN_SENSITIVITY, MAX_SENSITIVITY = 0.5, 2
local COUNTERS = table.freeze({
	"wins", "losses", "draws", "winStreak", "styleSpins", "pityCounter", "lastSaveTime",
})
local COSMETIC_SLOTS = table.freeze({ "Trunks", "Gloves", "Taunt", "Wrap", "Accessory", "Skin", "Hair" })

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function integer(value: any, minimum: number, maximum: number): boolean
	return finite(value) and value >= minimum and value <= maximum and value % 1 == 0
end

local function repairInteger(value: any, fallback: number, minimum: number, maximum: number): number
	return if integer(value, minimum, maximum) then value else fallback
end

local function identifier(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= MAX_IDENTIFIER_LENGTH
		and string.match(value, "^[%w_]+$") ~= nil
end

local ACTIONS={LeftHand=true,RightHand=true,LeftLeg=true,RightLeg=true,Alternate=true,Body=true,Guard=true,Grapple=true,Evade=true,Tap=true,Style=true}
local DEFAULT_KEYS: {[string]: string}={LeftHand="MouseLeftButton",RightHand="MouseRightButton",LeftLeg="Q",RightLeg="E",Alternate="LeftAlt",Body="LeftControl",Guard="Space",Grapple="F",Evade="LeftShift",Tap="T",Style="R"}
local VALID_KEYS={MouseLeftButton=true,MouseRightButton=true,Space=true,LeftAlt=true,RightAlt=true,LeftControl=true,RightControl=true,LeftShift=true,RightShift=true,One=true,Two=true,Three=true,Four=true,Five=true,Six=true,Seven=true,Eight=true,Nine=true,Zero=true,Minus=true,Equals=true,LeftBracket=true,RightBracket=true,Semicolon=true,Quote=true,Comma=true,Period=true,BackSlash=true}
for key in string.gmatch("C E F G H I J K L N O P Q R T U V X Y Z", "%S+") do VALID_KEYS[key]=true end
function ProfileSchema.ValidKeybinds(bindings: any): boolean
 if type(bindings)~="table" then return false end
 for name,key in bindings do if not ACTIONS[name] or type(key)~="string" or not VALID_KEYS[key] then return false end end
 local used: {[string]: boolean}={}
 for name,key in DEFAULT_KEYS do
  local chosen=bindings[name] or key
  if used[chosen] then return false end
  used[chosen]=true
 end
 return true
end
function ProfileSchema.Validate(raw: any): (boolean, string?)
	if type(raw) ~= "table" then return false, "Profile must be a table" end
	if raw.schemaVersion ~= CURRENT_SCHEMA_VERSION then return false, "Unsupported schemaVersion" end
	-- Negative user IDs are used by Studio's local multiplayer sessions.
	if not integer(raw.userId, -MAX_SAFE_INTEGER, MAX_SAFE_INTEGER) then return false, "Invalid userId" end
	if not integer(raw.elo, 0, MAX_ELO) then return false, "Invalid elo rating" end
	if not integer(raw.peakElo, raw.elo, MAX_ELO) then return false, "Invalid peakElo rating" end
	for _, field in COUNTERS do
		if not integer(raw[field], 0, MAX_SAFE_INTEGER) then return false, "Invalid " .. field end
	end
	if type(raw.styles) ~= "table" then return false, "Missing styles table" end
	local defaults = ProfileSchema.Default(raw.userId)
	for name in defaults.styles do
		if type(raw.styles[name]) ~= "table" then return false, "Missing style: " .. name end
	end
	for name, entry in pairs(raw.styles) do
		if type(name) ~= "string" or defaults.styles[name] == nil or type(entry) ~= "table" then
			return false, "Unknown or malformed style"
		end
		local data = entry :: { [string]: any }
		if type(data.unlocked) ~= "boolean" or not integer(data.xp, 0, MAX_SAFE_INTEGER)
			or not integer(data.level, 1, MAX_STYLE_LEVEL) or data.level ~= ProfileSchema.Level(data.xp) then
			return false, "Invalid style stats: " .. name
		end
	end
	if not identifier(raw.activeStyle) or not raw.styles[raw.activeStyle]
		or not raw.styles[raw.activeStyle].unlocked then return false, "Active style must be unlocked" end
	if type(raw.ownedCosmetics) ~= "table" or type(raw.equippedCosmetics) ~= "table" then
		return false, "Missing cosmetics table"
	end
	for id, owned in pairs(raw.ownedCosmetics) do
		if not identifier(id) or type(owned) ~= "boolean" then return false, "Invalid cosmetic ownership" end
	end
	for _, slot in COSMETIC_SLOTS do
		local id = raw.equippedCosmetics[slot]
		if not identifier(id) or raw.ownedCosmetics[id] ~= true then
			return false, "Equipped cosmetic must be owned: " .. slot
		end
	end
	if type(raw.settings) ~= "table" or type(raw.settings.leftHanded) ~= "boolean" then
		return false, "Invalid settings"
	end
	if not finite(raw.settings.fov) or raw.settings.fov < MIN_FOV or raw.settings.fov > MAX_FOV then
		return false, "Invalid fov"
	end
	if not finite(raw.settings.sensitivity) or raw.settings.sensitivity < MIN_SENSITIVITY
		or raw.settings.sensitivity > MAX_SENSITIVITY then return false, "Invalid sensitivity" end
	if not ProfileSchema.ValidKeybinds(raw.settings.keybinds) then return false,"Invalid keybinds" end
	for _, field in {"receipts", "appliedMatches", "pendingMatches"} do
  if type(raw[field])~="table" then return false,"Missing ledger: "..field end
  local count=0
  for id,value in raw[field] do
   count+=1
   if type(id)~="string" or #id==0 or #id>200 or count>10000 then return false,"Invalid ledger" end
   if field=="receipts" then
    if not integer(value,1,MAX_SAFE_INTEGER) then return false,"Invalid receipt product" end
   elseif value~=true then return false,"Invalid result ledger" end
  end
 end
 return RPG.validate(raw)
end

function ProfileSchema.Migrate(raw: any, userId: number): Profile
	assert(integer(userId, -MAX_SAFE_INTEGER, MAX_SAFE_INTEGER), "Invalid profile owner")
	local migrated = ProfileSchema.Default(userId)
	if type(raw) ~= "table" then return migrated end
	-- An older server must never rewrite a newer schema with missing fields.
	if finite(raw.schemaVersion) and raw.schemaVersion > CURRENT_SCHEMA_VERSION then
		error("Profile schema is newer than this server supports", 0)
	end
	migrated.elo = repairInteger(raw.elo, migrated.elo, 0, MAX_ELO)
	migrated.peakElo = math.max(migrated.elo, repairInteger(raw.peakElo, migrated.elo, 0, MAX_ELO))
	for _, field in COUNTERS do
		(migrated :: any)[field] = repairInteger(raw[field], (migrated :: any)[field], 0, MAX_SAFE_INTEGER)
	end
	-- Build fresh nested tables; neither the input nor another profile shares these entries.
	if type(raw.styles) == "table" then
		for name, entry in migrated.styles do
			local saved = raw.styles[name]
			if type(saved) == "table" then
				entry.unlocked = if type(saved.unlocked) == "boolean" then saved.unlocked else entry.unlocked
				entry.xp = repairInteger(saved.xp, entry.xp, 0, MAX_SAFE_INTEGER)
				entry.level = ProfileSchema.Level(entry.xp)
			end
		end
	end
	if identifier(raw.activeStyle) and migrated.styles[raw.activeStyle]
		and migrated.styles[raw.activeStyle].unlocked then
		migrated.activeStyle = raw.activeStyle
	else
		migrated.styles.Ironline.unlocked = true
	end
	if type(raw.ownedCosmetics) == "table" then
		for id, owned in pairs(raw.ownedCosmetics) do
			if type(id) == "string" and identifier(id) and owned == true then migrated.ownedCosmetics[id] = true end
		end
	end
	if type(raw.equippedCosmetics) == "table" then
		for _, slot in COSMETIC_SLOTS do
			local id = raw.equippedCosmetics[slot]
			if identifier(id) and migrated.ownedCosmetics[id] then
				(migrated.equippedCosmetics :: any)[slot] = id
			end
		end
	end
	if type(raw.settings) == "table" then
		if finite(raw.settings.fov) then migrated.settings.fov = math.clamp(raw.settings.fov, MIN_FOV, MAX_FOV) end
		if finite(raw.settings.sensitivity) then
			migrated.settings.sensitivity = math.clamp(raw.settings.sensitivity, MIN_SENSITIVITY, MAX_SENSITIVITY)
		end
		if type(raw.settings.leftHanded) == "boolean" then migrated.settings.leftHanded = raw.settings.leftHanded end
  if raw.settings.keybinds~=nil then
   assert(ProfileSchema.ValidKeybinds(raw.settings.keybinds),"Corrupt keybinds")
   for name,key in raw.settings.keybinds do migrated.settings.keybinds[name]=key end
  end
	end
 -- Durable ledgers are never silently repaired/dropped: losing a key could duplicate a grant.
 for _,field in {"receipts","appliedMatches","pendingMatches"} do
  if raw[field]~=nil then
   assert(type(raw[field])=="table","Corrupt durable ledger")
   for id,value in raw[field] do (migrated :: any)[field][id]=value end
  end
 end
 RPG.apply(migrated, raw)
 assert(ProfileSchema.Validate(migrated))
 return migrated
end

return table.freeze(ProfileSchema)

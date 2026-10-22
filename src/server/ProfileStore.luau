--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/ProfileStore
-- Pure, injectable storage engine plus the Asura's Path Souls progression record. Update callbacks
-- never yield or grant outside the stored record. Every profile carries a `souls` section that the
-- engine migrates and validates alongside the account schema it is constructed with.
local hasScript = pcall(function()
	return script.Parent
end)
local Settings: any, Weapons: any, World: any, Arsenal: any
if hasScript then
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
	Settings = require(Shared.Shared.CombatSettings)
	Weapons = require(Shared.Simulation.WeaponSchema)
	World = require(Shared.Shared.WorldDefinitions)
	Arsenal = require(Shared.Simulation.ArsenalInventory)
else
	Settings = require("../shared/CombatSettings")
	Weapons = require("../simulation/WeaponSchema")
	World = require("../shared/WorldDefinitions")
	Arsenal = require("../simulation/ArsenalInventory")
end

local Bridge: any = if hasScript then require(script.Parent.ProfileBridge) else require("./ProfileBridge")
local Progression: any = if hasScript then require(game:GetService("ReplicatedStorage").AsurasPath.Shared.ProgressionRules) else require("../shared/ProgressionRules")

export type AttributeName = "Vigor" | "Endurance" | "Strength" | "Dexterity" | "ArcaneQi"
export type Attributes = { [AttributeName]: number }
export type Bloodstain = { region: string, x: number, y: number, z: number, essence: number, death: number }
export type Elixirs = { charges: number, max: number, potency: number }
-- reinforcement: blacksmith upgrade level per weapon (absent = 0), 1..Store.ReinforceMax.
export type Inventory = {
	spells: {[string]: boolean}, spellSlots: {string}, remembrances: {[string]: any}, spentRemembrances: {[string]: boolean}, caches: {[string]: boolean},
	weapons: { [string]: boolean },
	mainhand: string,
	offhand: string,
	elixirs: Elixirs,
	reinforcement: { [string]: number },
}
export type WorldState = { altars: { [string]: boolean }, activeAltar: string, bosses: { [string]: boolean }, bloodstain: Bloodstain?, tutorial: { [string]: boolean }?, story: { [string]: boolean }? }
export type Souls = {
	version: number,
	level: number,
	attributes: Attributes,
	essence: number,
	inventory: Inventory,
	world: WorldState,
	deaths: number,
}
export type DerivedStats = {
	MaxQi: number, RallyScale: number, SpellScale: number, InfusionBurn: number, InfusionStun: number, GuardPierce: number, VoidScale: number, SignatureFinisher: boolean,
	MaxHP: number,
	MaxStamina: number,
	PostureCapacity: number,
	StrengthScale: number,
	DexterityScale: number,
}

type Schema = {
	Migrate: (raw: any, id: number) -> any,
	Validate: (profile: any) -> (boolean, string?),
	Level: (xp: number) -> number,
}

type Options = {
	owner: string,
	now: () -> number,
	wait: (seconds: number) -> any,
	attempts: number,
	leaseSeconds: number,
	startingAltar: string?,
}

type DataStore = { UpdateAsync: (self: any, key: string, transform: (old: any) -> any) -> any }

local Store = {}
Store.__index = Store

export type Engine = typeof(setmetatable(
	{} :: {
		dataStore: DataStore,
		schema: Schema,
		options: Options,
		profiles: { [number]: any },
		busy: { [number]: boolean },
		closed: boolean,
		operation: number,
	},
	Store
))

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, child in v do
		out[k] = copy(child)
	end
	return out
end
Store.Copy = copy

-- Conservative JSON upper bound: even fully escaped keys fit below the platform
-- record limit. Never remove deduplication keys to make a record fit.
local MAX_RECORD_BYTES = 3500000
local function jsonBound(value: any): number
	if type(value) == "string" then
		return #value * 6 + 2
	end
	if type(value) ~= "table" then
		return 32
	end
	local bytes = 2
	for key, child in value do
		bytes += jsonBound(key) + 1 + jsonBound(child) + 1
		if bytes > MAX_RECORD_BYTES then
			break
		end
	end
	return bytes
end
Store.JsonByteUpperBound = jsonBound

local function bounded(record: any): any
	assert(jsonBound(record) <= MAX_RECORD_BYTES, "Profile byte budget exceeded; archival required")
	return record
end

-------------------------------------------------------------------------------------------------
-- Souls progression schema
-------------------------------------------------------------------------------------------------

-- v2: weapon reinforcement levels.
local SOULS_VERSION = 4
local MAX_SAFE_INTEGER = 9007199254740991
local ATTRIBUTE_BASE = 10
local ATTRIBUTE_MAX = 99
local ATTRIBUTES: { AttributeName } = { "Vigor", "Endurance", "Strength", "Dexterity", "ArcaneQi" }
local MAX_IDENTIFIER = 64
local MAX_WORLD_ENTRIES = 512
local COORDINATE_LIMIT = 1e6
-- New records begin at the Sanctuary bonfire; the id lives only in WorldDefinitions.
local DEFAULT_ALTAR: string = World.Regions.Sanctuary.Altars.SanctuaryBonfire.Id
assert(DEFAULT_ALTAR == (World :: any).startingAltar().Id, "The Sanctuary bonfire must remain the starting altar")
local STARTING_WEAPONS = { "Unarmed", "Jian" }
local REINFORCE_MAX = 10
local REINFORCE_STEP = 0.1
local ELIXIR = Settings.Elixir

Store.Attributes = table.freeze(table.clone(ATTRIBUTES))
Store.AttributeBase = ATTRIBUTE_BASE
Store.AttributeMax = ATTRIBUTE_MAX

local WEAPON_SET: { [string]: boolean } = {}
for _, name in Weapons.WeaponKeys do
	WEAPON_SET[name] = true
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function integer(value: any, low: number, high: number): boolean
	return finite(value) and value >= low and value <= high and value % 1 == 0
end

local function identifier(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= MAX_IDENTIFIER and string.match(value, "^[%w_]+$") ~= nil
end

function Store.SoulLevel(attributes: Attributes): number
	local total = 0
	for _, name in ATTRIBUTES do
		total += attributes[name]
	end
	return total - ATTRIBUTE_BASE * #ATTRIBUTES + 1
end

-- Essence required to advance from `level` to `level + 1`.
function Store.LevelCost(level: number): number
	return Progression.levelCost(level)
end

-- Piecewise soft caps: full value per point to 40, reduced to 60, minimal beyond.
local function softCap(points: number, early: number, mid: number, late: number): number
	local spent = math.max(points - ATTRIBUTE_BASE, 0)
	local first = math.min(spent, 30)
	local second = math.clamp(spent - 30, 0, 20)
	local third = math.max(spent - 50, 0)
	return first * early + second * mid + third * late
end

Store.ReinforceMax = REINFORCE_MAX

-- Essence the blacksmith asks to raise a weapon from `level` to `level + 1`.
function Store.ReinforceCost(level: number): number
	local cost = Progression.upgradeCost(level)
 return cost
end

function Store.ReinforceLevel(souls: Souls, weapon: string): number
	local levels = souls.inventory.reinforcement
	return if levels then levels[weapon] or 0 else 0
end

function Store.DeriveStats(souls: Souls): DerivedStats
 local stats = Progression.stats(souls.attributes, Store.ReinforceLevel(souls, souls.inventory.mainhand))
 local rpg=(souls :: any).rpg
 local weapon=souls.inventory.mainhand
 local infusion=if rpg and rpg.Weapons[weapon] then rpg.Weapons[weapon].Infusion else nil
 local affinity=Progression.affinity(infusion,souls.attributes)
 local signature=rpg~=nil and Progression.masteryRank(rpg.Mastery[weapon] or 0)>=5
 return {InfusionBurn=affinity.Burn,InfusionStun=affinity.Stun,GuardPierce=affinity.GuardPierce,VoidScale=affinity.VoidScale,SignatureFinisher=signature,
  MaxHP=Settings.Health.MaxHP+stats.HPBonus, MaxStamina=Settings.Stamina.Max+stats.StaminaBonus,
  PostureCapacity=Settings.Posture.StanceBreakThreshold+stats.PostureBonus, StrengthScale=stats.StrengthScale,
  DexterityScale=stats.DexterityScale, MaxQi=stats.MaxQi, RallyScale=stats.RallyScale, SpellScale=stats.SpellScale}
end

function Store.DefaultSouls(startingAltar: string?): Souls
	local weapons: { [string]: boolean } = {}
	for _, name in STARTING_WEAPONS do
		weapons[name] = true
	end
	local altar = startingAltar or DEFAULT_ALTAR
	return {
		version = SOULS_VERSION,
		level = 1,
		attributes = { Vigor = ATTRIBUTE_BASE, Endurance = ATTRIBUTE_BASE, ArcaneQi = ATTRIBUTE_BASE, Strength = ATTRIBUTE_BASE, Dexterity = ATTRIBUTE_BASE },
		essence = 0,
		inventory = {
			weapons = weapons,
			mainhand = "Jian",
			offhand = "Unarmed",
			elixirs = { charges = ELIXIR.BaseCharges, max = ELIXIR.BaseCharges, potency = 0 },
			reinforcement = {},
			spells = {ThunderclapPalm=true,GaleStep=true}, spellSlots={"ThunderclapPalm","GaleStep"}, remembrances={}, spentRemembrances={}, caches={},
		},
		-- tutorial: opening-training steps completed (TutorialRules ids, "Skipped" when declined).
		-- story: six-sovereign ending flags (EndingRules.Flags); they only ever gain entries.
		world = { altars = { [altar] = true }, activeAltar = altar, bosses = {}, bloodstain = nil, tutorial = {}, story = {} },
		deaths = 0,
	}
end

local function validBloodstain(stain: any): boolean
	if type(stain) ~= "table" then
		return false
	end
	for key in stain do
		if key ~= "region" and key ~= "x" and key ~= "y" and key ~= "z" and key ~= "essence" and key ~= "death" then
			return false
		end
	end
	return identifier(stain.region)
		and finite(stain.x) and math.abs(stain.x) <= COORDINATE_LIMIT
		and finite(stain.y) and math.abs(stain.y) <= COORDINATE_LIMIT
		and finite(stain.z) and math.abs(stain.z) <= COORDINATE_LIMIT
		and integer(stain.essence, 0, MAX_SAFE_INTEGER)
		and integer(stain.death, 0, MAX_SAFE_INTEGER)
end

local function validFlagSet(set: any): boolean
	if type(set) ~= "table" then
		return false
	end
	local count = 0
	for key, value in set do
		count += 1
		if count > MAX_WORLD_ENTRIES or not identifier(key) or value ~= true then
			return false
		end
	end
	return true
end

function Store.ValidateSouls(raw: any): (boolean, string?)
	if type(raw) ~= "table" then
		return false, "Missing souls record"
	end
	if raw.version ~= SOULS_VERSION then
		return false, "Unsupported souls version"
	end
	local attributes = raw.attributes
	if type(attributes) ~= "table" then
		return false, "Missing attributes"
	end
	for _, name in ATTRIBUTES do
		if not integer(attributes[name], ATTRIBUTE_BASE, ATTRIBUTE_MAX) then
			return false, "Invalid attribute " .. name
		end
	end
	for key in attributes do
		if table.find(ATTRIBUTES, key) == nil then
			return false, "Unknown attribute"
		end
	end
	if raw.level ~= Store.SoulLevel(attributes) then
		return false, "Level does not match attributes"
	end
	if not integer(raw.essence, 0, MAX_SAFE_INTEGER) or not integer(raw.deaths, 0, MAX_SAFE_INTEGER) then
		return false, "Invalid essence or deaths"
	end
	local inventory = raw.inventory
	if type(inventory) ~= "table" or type(inventory.weapons) ~= "table" then
		return false, "Missing inventory"
	end
	if not Arsenal.validate(inventory) then return false, "Invalid arsenal inventory" end
	for name, owned in inventory.weapons do
		if not WEAPON_SET[name] or owned ~= true then
			return false, "Invalid weapon ownership"
		end
	end
	if inventory.weapons.Unarmed ~= true then
		return false, "Unarmed discipline must remain unlocked"
	end
	if type(inventory.mainhand) ~= "string" or inventory.weapons[inventory.mainhand] ~= true then
		return false, "Mainhand must be unlocked"
	end
	if inventory.offhand ~= "None" and (type(inventory.offhand) ~= "string" or inventory.weapons[inventory.offhand] ~= true) then
		return false, "Offhand must be unlocked or None"
	end
	local elixirs = inventory.elixirs
	if type(elixirs) ~= "table" or not integer(elixirs.max, ELIXIR.BaseCharges, ELIXIR.MaxCharges)
		or not integer(elixirs.charges, 0, elixirs.max) or not integer(elixirs.potency, 0, 10) then
		return false, "Invalid elixirs"
	end
	if type(inventory.reinforcement) ~= "table" then
		return false, "Missing reinforcement"
	end
	for name, level in inventory.reinforcement do
		if not WEAPON_SET[name] or not integer(level, 1, REINFORCE_MAX) then
			return false, "Invalid reinforcement"
		end
	end
	local world = raw.world
	if type(world) ~= "table" or not validFlagSet(world.altars) or not validFlagSet(world.bosses) then
		return false, "Invalid world state"
	end
	if not identifier(world.activeAltar) or world.altars[world.activeAltar] ~= true then
		return false, "Active altar must be activated"
	end
	if world.tutorial ~= nil and not validFlagSet(world.tutorial) then
		return false, "Invalid tutorial progress"
	end
	if world.story ~= nil and not validFlagSet(world.story) then
		return false, "Invalid story progress"
	end
	if world.bloodstain ~= nil and not validBloodstain(world.bloodstain) then
		return false, "Invalid bloodstain"
	end
	return true, nil
end

function Store.MigrateSouls(raw: any, startingAltar: string?): Souls
	local souls = Store.DefaultSouls(startingAltar)
	if type(raw) ~= "table" then
		return souls
	end
	if finite(raw.version) and raw.version > SOULS_VERSION then
		error("Souls record is newer than this server supports", 0)
	end
	if raw.version == SOULS_VERSION then assert(Arsenal.validate(raw.inventory),"Corrupt arsenal inventory") end
	if type(raw.attributes) == "table" then
		for _, name in ATTRIBUTES do
			local value = raw.attributes[name]
            if value == nil then value = if name == "Vigor" then raw.attributes.Vitality elseif name == "Endurance" then raw.attributes.Qi else nil end
			if integer(value, ATTRIBUTE_BASE, ATTRIBUTE_MAX) then
				souls.attributes[name] = value
			end
		end
	end
	souls.level = Store.SoulLevel(souls.attributes)
	if integer(raw.essence, 0, MAX_SAFE_INTEGER) then
		souls.essence = raw.essence
	end
	if integer(raw.deaths, 0, MAX_SAFE_INTEGER) then
		souls.deaths = raw.deaths
	end
	local inventory = raw.inventory
	if type(inventory) == "table" then
		if type(inventory.weapons) == "table" then
			for name, owned in inventory.weapons do
				if WEAPON_SET[name] and owned == true then
					souls.inventory.weapons[name] = true
				end
			end
		end
		if type(inventory.mainhand) == "string" and souls.inventory.weapons[inventory.mainhand] then
			souls.inventory.mainhand = inventory.mainhand
		end
		if inventory.offhand == "None" or (type(inventory.offhand) == "string" and souls.inventory.weapons[inventory.offhand]) then
			souls.inventory.offhand = inventory.offhand
		end
		local elixirs = inventory.elixirs
		if type(elixirs) == "table" then
			if integer(elixirs.max, ELIXIR.BaseCharges, ELIXIR.MaxCharges) then
				souls.inventory.elixirs.max = elixirs.max
			end
			if integer(elixirs.charges, 0, souls.inventory.elixirs.max) then
				souls.inventory.elixirs.charges = elixirs.charges
			else
				souls.inventory.elixirs.charges = souls.inventory.elixirs.max
			end
			if integer(elixirs.potency, 0, 10) then
				souls.inventory.elixirs.potency = elixirs.potency
			end
		end
		if type(inventory.reinforcement) == "table" then
			for name, level in inventory.reinforcement do
				if WEAPON_SET[name] and integer(level, 1, REINFORCE_MAX) then
					souls.inventory.reinforcement[name] = level
				end
			end
		end
	end
	local world = raw.world
	if type(world) == "table" then
		if validFlagSet(world.altars) then
			for id in world.altars do
				souls.world.altars[id] = true
			end
		end
		if validFlagSet(world.tutorial) then -- older records simply start the training fresh
			for id in world.tutorial do
				(souls.world.tutorial :: { [string]: boolean })[id] = true
			end
		end
		if validFlagSet(world.story) then -- older records have made no ending choice yet
			for id in world.story do
				(souls.world.story :: { [string]: boolean })[id] = true
			end
		end
		if validFlagSet(world.bosses) then
			for id in world.bosses do
				souls.world.bosses[id] = true
			end
		end
		if identifier(world.activeAltar) and souls.world.altars[world.activeAltar] then
			souls.world.activeAltar = world.activeAltar
		end
		-- A corrupt bloodstain is dropped rather than repaired: its essence was already forfeit.
		if world.bloodstain ~= nil and validBloodstain(world.bloodstain) then
			souls.world.bloodstain = copy(world.bloodstain)
		end
	end
	local migratedArsenal = Arsenal.migrate(if type(raw)=="table" then raw.inventory else nil)
	for key,value in migratedArsenal do (souls.inventory :: any)[key]=value end
	for bossId in souls.world.bosses do Arsenal.award(souls.inventory,bossId) end
	assert(Store.ValidateSouls(souls))
	return souls
end

-- Wraps an account schema so every migrated profile carries a validated `souls` section.
function Store.WithSouls(schema: Schema, startingAltar: string?): Schema
	return {
		Migrate = function(raw: any, id: number): any
			local profile = schema.Migrate(raw, id)
			profile.souls = Store.MigrateSouls(if type(raw) == "table" then raw.souls else nil, startingAltar)
			Bridge.toSouls(profile)
			return profile
		end,
		Validate = function(profile: any): (boolean, string?)
			local ok, err = schema.Validate(profile)
			if not ok then
				return ok, err
			end
			return Store.ValidateSouls(profile.souls)
		end,
		Level = schema.Level,
	}
end

-------------------------------------------------------------------------------------------------
-- Storage engine
-------------------------------------------------------------------------------------------------

function Store.new(dataStore: DataStore, schema: Schema, options: Options): Engine
	local self = {
		dataStore = dataStore,
		schema = Store.WithSouls(schema, options.startingAltar),
		options = options,
		profiles = {},
		busy = {},
		closed = false,
		operation = 0,
	}
	return setmetatable(self, Store) :: any
end

function Store.Retry(self: Engine, fn: () -> any): (boolean, any)
	local err: any
	for attempt = 1, self.options.attempts do
		local ok, value = pcall(fn)
		if ok then
			return true, value
		end
		err = value
		if attempt < self.options.attempts then
			self.options.wait(math.min(2 ^ (attempt - 1), 4))
		end
	end
	return false, tostring(err)
end

function Store.Load(self: Engine, id: number): (any, string?)
	if self.closed then
		return nil, "Server is closing"
	end
	if self.profiles[id] then
		return self:Get(id), nil
	end
	if self.busy[id] then
		return nil, "Profile is busy"
	end
	self.busy[id] = true
	local now = self.options.now
	local ok, record = self:Retry(function()
		return self.dataStore:UpdateAsync("Player_" .. id, function(old: any): any
			if old ~= nil and type(old) ~= "table" then
				error("Corrupt profile record")
			end
			local envelope = old and old.storageVersion ~= nil
			if envelope and old.storageVersion ~= 2 then
				error("Unsupported storage version")
			end
			if envelope and (type(old.profile) ~= "table" or type(old.revision) ~= "number") then
				error("Invalid storage envelope")
			end
			local lease = envelope and old.session
			if lease and (type(lease) ~= "table" or type(lease.id) ~= "string" or type(lease.expires) ~= "number") then
				error("Invalid lease")
			end
			if lease and lease.id ~= self.options.owner and lease.expires > now() then
				return nil
			end
			local raw = if envelope then old.profile else old
			if raw and raw.userId ~= nil and raw.userId ~= id then
				error("Profile owner mismatch")
			end
			local profile = self.schema.Migrate(raw, id)
			assert(self.schema.Validate(profile))
			return bounded({
				storageVersion = 2,
				revision = (if envelope then old.revision else 0) + 1,
				profile = profile,
				session = { id = self.options.owner, expires = now() + self.options.leaseSeconds },
			})
		end)
	end)
	self.busy[id] = nil
	if not ok or not record then
		return nil, if ok then "Profile is active on another server" else record
	end
	self.profiles[id] = record
	return self:Get(id), nil
end

function Store.Get(self: Engine, id: number): any
	local record = self.profiles[id]
	if not record or not record.session or record.session.expires <= self.options.now() then
		return nil
	end
	return copy(record.profile)
end

-- One transaction per user. Failed/ambiguous writes never expose speculative rewards to gameplay.
function Store.Transaction(self: Engine, id: number, mutate: (profile: any) -> (), release: boolean?): (boolean, string?)
	local localRecord = self.profiles[id]
	if not localRecord or not self:Get(id) then
		return false, "Profile session unavailable"
	end
	if self.busy[id] then
		return false, "Profile is busy"
	end
	self.busy[id] = true
	self.operation += 1
	local operationId = self.options.owner .. ":" .. self.operation
	local ok, result = self:Retry(function()
		return self.dataStore:UpdateAsync("Player_" .. id, function(old: any): any
			if not old or old.storageVersion ~= 2 or not old.session or old.session.id ~= self.options.owner
				or old.session.expires <= self.options.now() then
				return nil
			end
			if old.lastOperation == operationId then
				return old
			end
			local candidate = self.schema.Migrate(old.profile, id)
			local baseline = Bridge.snapshot(candidate)
			mutate(candidate)
			Bridge.reconcile(candidate, baseline)
			candidate.lastSaveTime = self.options.now()
			assert(self.schema.Validate(candidate))
			return bounded({
				storageVersion = 2,
				revision = old.revision + 1,
				profile = candidate,
				lastOperation = operationId,
				session = if release then nil else { id = self.options.owner, expires = self.options.now() + self.options.leaseSeconds },
			})
		end)
	end)
	self.busy[id] = nil
	if not ok or not result then
		-- Ownership refusal invalidates local access immediately. API errors leave only the last confirmed cache.
		if ok then
			self.profiles[id] = nil
		end
		return false, if ok then "Profile ownership lost" else result
	end
	self.profiles[id] = if release then nil else result
	return true, nil
end

function Store.Save(self: Engine, id: number): (boolean, string?)
	return self:Transaction(id, function() end)
end

function Store.Release(self: Engine, id: number): (boolean, string?)
	return self:Transaction(id, function() end, true)
end

function Store.Receipt(self: Engine, id: number, purchaseId: any, productId: number, grant: (profile: any) -> ()): (boolean, string?)
	if type(purchaseId) ~= "string" or #purchaseId == 0 or #purchaseId > 200 then
		return false, "Invalid receipt ID"
	end
	return self:Transaction(id, function(p)
		local previous = p.receipts[purchaseId]
		if previous then
			assert(previous == productId, "Receipt product mismatch")
			return
		end
		local count = 0
		for _ in p.receipts do
			count += 1
		end
		assert(count < 10000, "Receipt ledger full; archival required") -- Never evict an idempotency key.
		grant(p)
		p.receipts[purchaseId] = productId
	end)
end

function Store.ApplyResult(self: Engine, id: number, matchId: string, result: any): (boolean, string?)
	return self:Transaction(id, function(p)
		if p.appliedMatches[matchId] then
			p.pendingMatches[matchId] = nil
			return
		end
		assert(p.pendingMatches[matchId], "Result was not registered before match start")
		assert(result.userId == id and result.mode == "Ranked1v1", "Invalid ranked result")
		local count = 0
		for _ in p.appliedMatches do
			count += 1
		end
		assert(count < 10000, "Result ledger full; archival required")
		p.elo = math.clamp(p.elo + result.eloDelta, 0, 5000)
		p.peakElo = math.max(p.peakElo, p.elo)
		p.qiEssence += result.cash
		if result.outcome == "Win" then
			p.wins += 1
			p.winStreak += 1
		elseif result.outcome == "Draw" then
			p.draws += 1
			p.winStreak = 0
		else
			p.losses += 1
			p.winStreak = 0
		end
		local style = assert(p.styles[result.style])
		assert(style.unlocked)
		local multiplier = if p.ownedCosmetics.VIP_Pass then 2 else 1
		style.xp += result.xp * multiplier
		style.level = self.schema.Level(style.xp)
		p.appliedMatches[matchId] = true
		p.pendingMatches[matchId] = nil
	end)
end

-------------------------------------------------------------------------------------------------
-- Souls progression transactions. Each pre-checks against the confirmed cache, then re-checks
-- inside the write so a refused change is a no-op rather than a retried error.
-------------------------------------------------------------------------------------------------

function Store.Souls(self: Engine, id: number): Souls?
	local profile = self:Get(id)
	return if profile then profile.souls else nil
end

function Store.ActivateAltar(self: Engine, id: number, altarId: string, setActive: boolean, refillElixirs: boolean): (boolean, string?)
	if not identifier(altarId) then
		return false, "Invalid altar"
	end
	return self:Transaction(id, function(p)
		local world = p.souls.world
		local count = 0
		for _ in world.altars do
			count += 1
		end
		if not world.altars[altarId] and count < MAX_WORLD_ENTRIES then
			world.altars[altarId] = true
		end
		if setActive and world.altars[altarId] then
			world.activeAltar = altarId
		end
		if refillElixirs then
			p.souls.inventory.elixirs.charges = p.souls.inventory.elixirs.max
		end
	end)
end

function Store.SetElixirCharges(self: Engine, id: number, charges: number): (boolean, string?)
	if not integer(charges, 0, ELIXIR.MaxCharges) then
		return false, "Invalid charges"
	end
	return self:Transaction(id, function(p)
		local elixirs = p.souls.inventory.elixirs
		elixirs.charges = math.min(charges, elixirs.max)
	end)
end

function Store.AddElixirCapacity(self: Engine, id: number): (boolean, string?)
	local souls = self:Souls(id)
	if not souls then
		return false, "Profile session unavailable"
	end
	if souls.inventory.elixirs.max >= ELIXIR.MaxCharges then
		return false, "Gourd already at capacity"
	end
	return self:Transaction(id, function(p)
		local elixirs = p.souls.inventory.elixirs
		if elixirs.max < ELIXIR.MaxCharges then
			elixirs.max += 1
			elixirs.charges = math.min(elixirs.charges + 1, elixirs.max)
		end
	end)
end

function Store.GrantEssence(self: Engine, id: number, amount: number): (boolean, string?)
	if not integer(amount, 0, MAX_SAFE_INTEGER) then
		return false, "Invalid essence amount"
	end
	if amount == 0 then
		return true, nil
	end
	return self:Transaction(id, function(p)
		p.souls.essence = math.min(MAX_SAFE_INTEGER, p.souls.essence + amount)
	end)
end

-- Death: unbanked session essence joins the carried total, all of it drops into a new bloodstain,
-- and any previous unrecovered bloodstain is destroyed. Returns the essence now in the stain.
function Store.RecordDeath(self: Engine, id: number, region: string, x: number, y: number, z: number, unbanked: number): (boolean, string?, number)
	if not identifier(region) or not finite(x) or not finite(y) or not finite(z) or not integer(unbanked, 0, MAX_SAFE_INTEGER) then
		return false, "Invalid death record", 0
	end
	local dropped = 0
	local ok, err = self:Transaction(id, function(p)
		local souls = p.souls
		souls.deaths = math.min(MAX_SAFE_INTEGER, souls.deaths + 1)
		dropped = math.min(MAX_SAFE_INTEGER, souls.essence + unbanked)
		souls.essence = 0
		souls.world.bloodstain = if dropped > 0
			then {
				region = region,
				x = math.clamp(x, -COORDINATE_LIMIT, COORDINATE_LIMIT),
				y = math.clamp(y, -COORDINATE_LIMIT, COORDINATE_LIMIT),
				z = math.clamp(z, -COORDINATE_LIMIT, COORDINATE_LIMIT),
				essence = dropped,
				death = souls.deaths,
			}
			else nil
	end)
	return ok, err, if ok then dropped else 0
end

function Store.RecoverBloodstain(self: Engine, id: number, deathIndex: number): (boolean, string?, number)
	local souls = self:Souls(id)
	local stain = souls and souls.world.bloodstain
	if not stain or stain.death ~= deathIndex then
		return false, "No matching bloodstain", 0
	end
	local recovered = 0
	local ok, err = self:Transaction(id, function(p)
		local current = p.souls.world.bloodstain
		if current and current.death == deathIndex then
			recovered = current.essence
			p.souls.essence = math.min(MAX_SAFE_INTEGER, p.souls.essence + current.essence)
			p.souls.world.bloodstain = nil
		end
	end)
	return ok, err, if ok then recovered else 0
end

function Store.LevelAttribute(self: Engine, id: number, attribute: AttributeName): (boolean, string?)
	local canonical: any = attribute
	if canonical == "Vitality" then canonical = "Vigor" end
	if canonical == "Qi" then canonical = "Endurance" end
	if table.find(ATTRIBUTES, canonical) == nil then
		return false, "Unknown attribute"
	end
	attribute = canonical
	local souls = self:Souls(id)
	if not souls then
		return false, "Profile session unavailable"
	end
	if souls.attributes[attribute] >= ATTRIBUTE_MAX then
		return false, "Attribute at maximum"
	end
	local cost = Store.LevelCost(souls.level)
	if souls.essence < cost then
		return false, "Not enough essence"
	end
	local applied = false
	local ok, err = self:Transaction(id, function(p)
		local s = p.souls
		local price = Store.LevelCost(s.level)
		if s.essence >= price and s.attributes[attribute] < ATTRIBUTE_MAX then
			s.essence -= price
			s.attributes[attribute] += 1
			s.level = Store.SoulLevel(s.attributes)
			applied = true
		end
	end)
	if ok and not applied then
		return false, "Level refused"
	end
	return ok, err
end

function Store.RecordBossDefeat(self: Engine, id: number, bossId: string, essence: number): (boolean, string?)
	if not identifier(bossId) or not integer(essence, 0, MAX_SAFE_INTEGER) then
		return false, "Invalid boss record"
	end
	return self:Transaction(id, function(p)
		Arsenal.award(p.souls.inventory, bossId)
		local bosses = p.souls.world.bosses
		local count = 0
		for _ in bosses do
			count += 1
		end
		if not bosses[bossId] and count < MAX_WORLD_ENTRIES then
			bosses[bossId] = true
            local materials=p.inventory.Materials
            materials.SpiritIronOre=(materials.SpiritIronOre or 0)+8
            materials.StarfallShard=(materials.StarfallShard or 0)+4
            materials.DragoniteCore=(materials.DragoniteCore or 0)+2
            local gems={"CrimsonFireGem","CelestialLightningGem","AbyssalVoidGem"}
            local gem=gems[(count%3)+1];materials[gem]=(materials[gem] or 0)+1
			p.souls.essence = math.min(MAX_SAFE_INTEGER, p.souls.essence + essence)
		end
	end)
end

function Store.UnlockWeapon(self: Engine, id: number, weapon: string): (boolean, string?)
	if not WEAPON_SET[weapon] then
		return false, "Unknown weapon"
	end
	return self:Transaction(id, function(p)
		p.souls.inventory.weapons[weapon] = true
	end)
end

-- Blacksmith: spends banked essence to raise one weapon's reinforcement by a level.
-- Returns the new level on success.
function Store.ReinforceWeapon(self: Engine, id: number, weapon: string): (boolean, string?, number)
	if not WEAPON_SET[weapon] then
		return false, "Unknown weapon", 0
	end
 local reached=0
 local ok,err=self:Transaction(id,function(p: any)
  Progression.upgrade(p,weapon);reached=p.inventory.Weapons[weapon].Level
 end)
 return ok,err,reached
end

function Store.EquipLoadout(self: Engine, id: number, mainhand: string, offhand: string): (boolean, string?)
	local souls = self:Souls(id)
	if not souls then
		return false, "Profile session unavailable"
	end
	local weapons = souls.inventory.weapons
	if not weapons[mainhand] or (offhand ~= "None" and not weapons[offhand]) then
		return false, "Weapon is locked"
	end
	return self:Transaction(id, function(p)
		local inventory = p.souls.inventory
		if inventory.weapons[mainhand] and (offhand == "None" or inventory.weapons[offhand]) then
			inventory.mainhand = mainhand
			inventory.offhand = offhand
		end
	end)
end

return Store

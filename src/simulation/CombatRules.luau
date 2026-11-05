--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Simulation/CombatRules
-- Authoritative combat resolution for Asura's Path. Deterministic and engine-free: every function
-- takes explicit `now` timestamps, touches only the fighter records passed to it and reports
-- what happened through Event records. Geometry (range, facing, struck region) is supplied by callers.
local hasScript = pcall(function()
	return script.Parent
end)
local Settings: any, Schema: any, Weapons: any, Tempo: any
if hasScript then
	Settings = require(script.Parent.Parent.Shared.CombatSettings)
	Schema = require(script.Parent.MoveSchema)
	Weapons = require(script.Parent.WeaponSchema)
	Tempo = require(script.Parent.Tempo)
else
	Settings = require("../shared/CombatSettings")
	Schema = require("./MoveSchema")
	Weapons = require("./WeaponSchema")
	Tempo = require("./Tempo")
end

export type State =
	"Idle"
	| "Startup"
	| "Active"
	| "Recovery"
	| "Deflecting"
	| "Blocking"
	| "Blockstun"
	| "Dashing"
	| "Hitstun"
	| "GuardBroken"
	| "StaminaBroken"
	| "StanceBroken"
	| "DeathblowAttacker"
	| "DeathblowVictim"
	| "RestingAtShrine"
	| "KO"
type Context = { [string]: any }
export type InjuryTier = "None" | "Impaired" | "Injured" | "Severe"
export type InjuryRegion = "Head" | "Torso" | "LeftArm" | "RightArm" | "LeftLeg" | "RightLeg"
export type WeaponType = "Unarmed" | "Jian" | "Dao" | "Guandao" | "Odachi" | "TwinDaggers" | "ChainScythe" | "WarFan" | "Catalyst" | "PrayerOfTheDefiled" | "CalamityBoneCleaver" | "HeavenPiercingGuandao"
export type MoveKind = "Light" | "Heavy" | "RunningAttack" | "WeaponArt"
export type DamageCategory = "Chip" | "Light" | "Heavy" | "RunningAttack" | "WeaponArt" | "Bleed" | "Deathblow"

export type EventKind =
	"DeflectSpark"
	| "Block"
	| "GuardBreak"
	| "Hit"
	| "CounterHit"
	| "Armored"
	| "StanceBreak"
	| "Deathblow"
	| "Rally"
	| "BleedProc"
	| "InjuryTier"
	| "StaminaBreak"
	| "Feint"
	| "Dash"
	| "KO"
	| "Rest"
	| "Whiff"
	| "Evade"

export type Event = { Kind: EventKind, Source: number, Target: number, Value: number, Region: string? }

export type MoveTiming = {
	StartupSeconds: number,
	ActiveSeconds: number,
	RecoverySeconds: number,
	ComboWindowSeconds: number,
	CancelFrame: number,
	TotalSeconds: number,
}

export type MoveData = {
	Effect: string?,
	Id: string,
	Kind: MoveKind,
	ComboIndex: number,
	BaseDamage: number,
	PostureDamage: number,
	Bleed: number,
	DeflectVulnerability: number,
	Deflectable: boolean,
	Unblockable: boolean,
	HyperArmor: boolean,
	StaminaCost: number,
	QiCost: number,
	Reach: number,
	Arc: number,
	Lunge: number,
	DamageType: "Blunt" | "Slash" | "Pierce",
	Trauma: { Head: number, Torso: number, Arms: number, Legs: number },
	Timing: MoveTiming,
}

export type Penalties = {
	StaminaCostMultiplier: number,
	DamageMultiplier: number,
	SpeedMultiplier: number,
	DashDistanceMultiplier: number,
	DeflectWindowMultiplier: number,
	PostureDecayMultiplier: number,
	StaminaRegenMultiplier: number,
	MaxPostureMultiplier: number,
	VisionBlur: number,
	EyeVignette: number,
}

export type Fighter = {
	Id: number,
	Weapon: WeaponType,
	MainHand: "Left" | "Right",
	State: State,
	StateStart: number,
	StateEnd: number,
	Move: MoveData?,
	MoveStart: number,
	HitRegistry: { [number]: boolean },
	ActiveHP: number,
	RecoverableHP: number,
	PermanentDeficit: number,
	RallyUntil: number,
	Stamina: number,
	StaminaRegenAt: number,
	Posture: number,
	PostureDecayAt: number,
 MaxQi: number, RallyScale: number, SpellScale: number,
 InfusionBurn: number, InfusionStun: number, GuardPierce: number, VoidScale: number, SignatureFinisher: boolean,
 BurnRate: number, BurnUntil: number, BurnSource: number,
	Qi: number,
	WardUntil: number, RootUntil: number,
	Bleed: number,
	BleedDecayAt: number,
	Trauma: { [InjuryRegion]: number },
	Injuries: { [InjuryRegion]: InjuryTier },
	TraumaAt: number,
	Penalties: Penalties,
	GuardHeld: boolean,
	Sprinting: boolean,
	DeflectPressedAt: number,
	DeflectWindow: number,
	LastDeflectPress: number,
	DeflectChain: number,
	DashChain: number,
	LastDashAt: number,
	DashSeq: number,
	ActionSeq: number,
	ActionMark: number,
	ActionState: string,
	-- The intent that started the action identified by IntentMark/IntentState (Rules.markIntent); 0 = none.
	IntentSeq: number,
	IntentMark: number,
	IntentState: string,
	-- Accepted press time of the current dash (its i-frames may cover an earlier contact through the grace).
	DashPressedAt: number,
	DashDistance: number,
	DashDuration: number,
	DashDirX: number,
	DashDirZ: number,
	IFrameStart: number,
	IFrameEnd: number,
	DeathblowPartner: number,
	PendingKO: boolean,
	EventSeq: number,
	LastEvent: number,
	MaxHP: number,
	MaxStamina: number,
	PostureCapacity: number,
	Protection: number, -- worn armour: the share taken off strikes, chip, spells and boss attacks
	ArmorSpeed: number, -- worn armour: one more factor in speedMultiplier
	StrengthScale: number,
	DexterityScale: number,
	PoiseArmor: number,
	ReachBonus: number,
	-- ActiveHP floors at 1 (multi-phase bosses); cleared for the final phase.
	KOProtected: boolean,
	InvulnerableUntil: number,
	PendingHeal: number,
	PendingHealAt: number,
}

export type Stats = {
 MaxQi: number?, RallyScale: number?, SpellScale: number?, InfusionBurn: number?, InfusionStun: number?,
 GuardPierce: number?, VoidScale: number?, SignatureFinisher: boolean?,
	MaxHP: number?,
	MaxStamina: number?,
	PostureCapacity: number?,
	Protection: number?,
	ArmorSpeed: number?,
	StrengthScale: number?,
	DexterityScale: number?,
	PoiseArmor: number?,
	ReachBonus: number?,
}

export type HitContext = {
	-- Defender is facing the attacker closely enough to guard (front arc).
	Facing: boolean,
	-- Hurtbox region struck by the lag-compensated query.
	Region: InjuryRegion,
	-- Server-authored weak-point bonus, applied only after defenses accept a clean hit.
	PostureBonus: number?,
	-- A contact resolved after a bounded defender grace (TIMING_CONTRACT §5.3): the move that made it and the
	-- defender's state at the contact instant. `now` is then the contact time t_c. The defender's guard and
	-- counter state are judged as of t_c; only a deflect or dash pressed at or before t_c can change it.
	Move: MoveData?,
	DefenderState: State?,
	-- t_c when resolution happens later than the contact: invulnerability and deflect timing are judged at it,
	-- while the stun or recoil the outcome applies starts at `now`.
	At: number?,
	-- Everything else the outcome depends on, frozen at t_c (Rules.contactSnapshot). Built from the present
	-- when absent, which is the same thing for a contact resolved on its own tick.
	Snapshot: ContactSnapshot?,
}

-- A contact as of t_c (combat recovery Stage 2 closure, TIMING_CONTRACT §0). Frozen at detection: the defender's
-- state, move, weapon, poise armor and invulnerability, and the attacker's weapon, arm tier, damage scale and
-- infusions. Judged at resolution: a deflect or a dash whose accepted press is at or before t_c (the grace).
-- Applied at resolution: HP, posture, stamina and Qi changes (running totals) and the stun, which starts then.
export type ContactSnapshot = {
	At: number,
	DefenderState: State,
	DefenderMove: MoveData?,
	DefenderWeapon: WeaponType,
	DefenderPoise: number,
	DefenderProtection: number,
	Invulnerable: boolean,
	AttackerWeapon: WeaponType,
	ArmTier: InjuryTier,
	DamageScale: number,
	InfusionStun: number,
	InfusionBurn: number,
	GuardPierce: number,
}

export type HitOutcome = "Ignored" | "Whiff" | "Deflected" | "Blocked" | "GuardBroken" | "Hit" | "CounterHit" | "Armored" | "KO"

export type DashGrant = { Distance: number, Duration: number, IFrameStart: number, IFrameEnd: number, Seq: number }

local Rules = {}
-- Move effects that resolve as spells/projectiles rather than weapon contact.
Rules.RangedEffects = table.freeze({ AbbotDirge = true, FissureSlam = true, Thunderfall = true, WindSlash = true }) :: { [string]: boolean }

local REGIONS: { InjuryRegion } = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local GROUP: { [InjuryRegion]: "Head" | "Torso" | "Arms" | "Legs" } = {
	Head = "Head",
	Torso = "Torso",
	LeftArm = "Arms",
	RightArm = "Arms",
	LeftLeg = "Legs",
	RightLeg = "Legs",
}
local NEVER = math.huge
local FLOOR_TRAUMA = 0.02

local EVENT_CODES: { [EventKind]: number } = {
	DeflectSpark = 1,
	Block = 2,
	GuardBreak = 3,
	Hit = 4,
	CounterHit = 5,
	Armored = 6,
	StanceBreak = 7,
	Deathblow = 8,
	Rally = 9,
	BleedProc = 10,
	InjuryTier = 11,
	StaminaBreak = 12,
	Feint = 13,
	Dash = 14,
	KO = 15,
	Rest = 16,
	-- Contact legibility (batch 09): an attack window that closed without touching anyone, and
	-- a strike that passed through dodge i-frames (Source = the evader, Target = the attacker).
	Whiff = 17,
	Evade = 18,
}
local EVENT_NAMES: { [number]: EventKind } = {}
for name, code in EVENT_CODES do
	EVENT_NAMES[code] = name
end
Rules.EventCodes = table.freeze(EVENT_CODES)
Rules.EventNames = table.freeze(EVENT_NAMES)

-- Fraction of base walk speed allowed in each state (dash displacement is granted separately).
local STATE_SPEED: { [State]: number } = {
	Idle = 1,
	Startup = 0.35,
	Active = 0.25,
	Recovery = 0.5,
	Deflecting = 0.6,
	Blocking = 0.5,
	Blockstun = 0.2,
	Dashing = 0,
	Hitstun = 0,
	GuardBroken = 0,
	StaminaBroken = 0.35,
	StanceBroken = 0,
	DeathblowAttacker = 0,
	DeathblowVictim = 0,
	RestingAtShrine = 0,
	KO = 0,
}
Rules.StateSpeed = table.freeze(STATE_SPEED)

local function emit(f: Fighter, events: { Event }?, kind: EventKind, source: number, target: number, value: number, region: string?)
	f.EventSeq = (f.EventSeq + 1) % 65536
	f.LastEvent = EVENT_CODES[kind]
	if events then
		table.insert(events, { Kind = kind, Source = source, Target = target, Value = value, Region = region })
	end
end

local function weaponOf(f: Fighter): any
	return Weapons.get(f.Weapon)
end

local function refreshPenalties(f: Fighter)
	f.Penalties = Schema.penalties(f.Injuries, Weapons.isTwoHanded(weaponOf(f)), f.MainHand)
end

local function enter(f: Fighter, state: State, now: number, duration: number?)
	f.State = state
	f.StateStart = now
	f.StateEnd = if duration then now + duration else NEVER
end

local function clearMove(f: Fighter)
	f.Move = nil
	table.clear(f.HitRegistry)
end

function Rules.new(id: number, weapon: WeaponType?, now: number): Fighter
	local trauma: { [InjuryRegion]: number } = {}
	local injuries: { [InjuryRegion]: InjuryTier } = {}
	for _, region in REGIONS do
		trauma[region] = 0
		injuries[region] = "None"
	end
	local fighter: Fighter = {
		Id = id,
		Weapon = weapon or "Unarmed",
		MainHand = "Right",
		State = "Idle",
		StateStart = now,
		StateEnd = NEVER,
		Move = nil,
		MoveStart = now,
		HitRegistry = {},
		ActiveHP = Settings.Health.MaxHP,
		RecoverableHP = 0,
		PermanentDeficit = 0,
		RallyUntil = -NEVER,
		Stamina = Settings.Stamina.Max,
		StaminaRegenAt = now,
		Posture = 0,
		PostureDecayAt = now,
  MaxQi=Settings.Qi.Max,RallyScale=1,SpellScale=1,InfusionBurn=0,InfusionStun=0,GuardPierce=0,VoidScale=1,SignatureFinisher=false,
  BurnRate=0,BurnUntil=0,BurnSource=0,
		Qi = Settings.Qi.Initial,
		WardUntil = 0, RootUntil = 0,
		Bleed = 0,
		BleedDecayAt = now,
		Trauma = trauma,
		Injuries = injuries,
		TraumaAt = -NEVER,
		Penalties = Schema.penalties(injuries, false, "Right"),
		GuardHeld = false,
		Sprinting = false,
		DeflectPressedAt = -NEVER,
		DeflectWindow = Settings.Posture.DeflectWindow,
		LastDeflectPress = -NEVER,
		DeflectChain = 0,
		DashChain = 0,
		LastDashAt = -NEVER,
		DashSeq = 0,
		ActionSeq = 0,
		ActionMark = -NEVER,
		ActionState = "",
		IntentSeq = 0,
		IntentMark = -NEVER,
		IntentState = "",
		DashPressedAt = -NEVER,
		DashDistance = 0,
		DashDuration = 0,
		DashDirX = 0,
		DashDirZ = 0,
		IFrameStart = -NEVER,
		IFrameEnd = -NEVER,
		DeathblowPartner = 0,
		PendingKO = false,
		EventSeq = 0,
		LastEvent = 0,
		MaxHP = Settings.Health.MaxHP,
		MaxStamina = Settings.Stamina.Max,
		PostureCapacity = Settings.Posture.StanceBreakThreshold,
		Protection = 0,
		ArmorSpeed = 1,
		StrengthScale = 1,
		DexterityScale = 1,
		PoiseArmor = 0,
		ReachBonus = 0,
		KOProtected = false,
		InvulnerableUntil = -NEVER,
		PendingHeal = 0,
		PendingHealAt = NEVER,
	}
	refreshPenalties(fighter)
	return fighter
end

-- Shrine rest / respawn restoration. `full` clears every layer regardless of shrine settings.
function Rules.restore(f: Fighter, now: number, full: boolean?)
	f.WardUntil = 0; f.RootUntil = 0
	local shrine = Settings.Health.Shrine
	if full or shrine.ClearsPermanentDeficit then
		f.PermanentDeficit = 0
	end
	if full or shrine.ClearsRecoverableHP then
		f.RecoverableHP = 0
	end
	if full or shrine.RestoresActiveHP then
		f.ActiveHP = Rules.effectiveMaxHP(f) - f.RecoverableHP
	end
	if full or shrine.ClearsInjuries then
		for _, region in REGIONS do
			f.Trauma[region] = 0
			f.Injuries[region] = "None"
		end
		refreshPenalties(f)
	end
	if full or Settings.Qi.ClearOnShrine then
		f.Qi = if full then f.MaxQi else Settings.Qi.Initial
	end
	f.Stamina = f.MaxStamina
	f.Posture = 0
	f.Bleed = 0
	f.PendingHeal = 0
	f.PendingHealAt = NEVER
	f.InvulnerableUntil = -NEVER
	f.BurnRate=0;f.BurnUntil=0;f.BurnSource=0
	f.RallyUntil = -NEVER
	f.DashChain = 0
	f.DeflectChain = 0
	f.PendingKO = false
	f.DeathblowPartner = 0
	f.GuardHeld = false
	f.Sprinting = false
	clearMove(f)
end

function Rules.effectiveMaxHP(f: Fighter): number
	local health = Settings.Health
	local ratio = f.MaxHP / health.MaxHP
	return math.max(health.MinEffectiveMaxHP * ratio, f.MaxHP - f.PermanentDeficit)
end

function Rules.maxPermanentDeficit(f: Fighter): number
	return Settings.Health.MaxPermanentDeficit * f.MaxHP / Settings.Health.MaxHP
end

-- Applies attribute- or definition-derived pools. `refill` tops every pool up to its new maximum.
function Rules.applyStats(f: Fighter, stats: Stats, refill: boolean?)
 f.MaxQi=stats.MaxQi or f.MaxQi;f.RallyScale=stats.RallyScale or f.RallyScale;f.SpellScale=stats.SpellScale or f.SpellScale
 f.InfusionBurn=stats.InfusionBurn or 0;f.InfusionStun=stats.InfusionStun or 0
 f.GuardPierce=stats.GuardPierce or 0;f.VoidScale=stats.VoidScale or 1;f.SignatureFinisher=stats.SignatureFinisher or false
 f.Qi=math.min(f.Qi,f.MaxQi)
	local hpRatio = if f.MaxHP > 0 then f.ActiveHP / f.MaxHP else 1
	f.MaxHP = math.clamp(stats.MaxHP or f.MaxHP, 1, 1600)
	f.MaxStamina = math.clamp(stats.MaxStamina or f.MaxStamina, 1, 600)
	f.PostureCapacity = math.clamp(stats.PostureCapacity or f.PostureCapacity, 1, 600)
	-- Absent means bare, as with infusions: stats that do not name armour (ranked, foes) must not inherit a suit.
	f.Protection = math.clamp(stats.Protection or 0, 0, 0.3)
	f.ArmorSpeed = math.clamp(stats.ArmorSpeed or 1, 0.8, 1)
	f.StrengthScale = math.clamp(stats.StrengthScale or f.StrengthScale, 0.1, 5)
	f.DexterityScale = math.clamp(stats.DexterityScale or f.DexterityScale, 0.1, 5)
	f.PoiseArmor = math.clamp(stats.PoiseArmor or f.PoiseArmor, 0, 1)
	f.ReachBonus = math.clamp(stats.ReachBonus or f.ReachBonus, 0, 8)
	f.PermanentDeficit = math.min(f.PermanentDeficit, Rules.maxPermanentDeficit(f))
	if refill then
		f.ActiveHP = Rules.effectiveMaxHP(f) - f.RecoverableHP
		f.Stamina = f.MaxStamina
	else
		f.ActiveHP = math.min(Rules.effectiveMaxHP(f), hpRatio * f.MaxHP)
		f.Stamina = math.min(f.Stamina, f.MaxStamina)
	end
	f.ActiveHP = math.max(f.ActiveHP, 0)
	f.RecoverableHP = math.clamp(f.RecoverableHP, 0, math.max(Rules.effectiveMaxHP(f) - f.ActiveHP, 0))
	f.Posture = math.min(f.Posture, Rules.maxPosture(f))
end

-- Attribute scaling: Strength drives unarmed and heavy strikes, Dexterity drives bladed technique.
local STRENGTH_WEAPONS: { [string]: boolean } = { Unarmed = true, Guandao = true, Odachi = true, CalamityBoneCleaver = true, HeavenPiercingGuandao = true, IronBullMaul = true }
function Rules.scalingAttribute(weapon: string): string
	return if STRENGTH_WEAPONS[weapon] then "Strength" else "Dexterity"
end

function Rules.damageScale(f: Fighter, move: MoveData): number
	if Rules.scalingAttribute(f.Weapon) == "Strength" then
		return f.StrengthScale*f.VoidScale
	end
	return f.DexterityScale*f.VoidScale
end

function Rules.maxPosture(f: Fighter): number
	return f.PostureCapacity * f.Penalties.MaxPostureMultiplier
end

function Rules.armTier(f: Fighter): InjuryTier
	return Schema.attackArmTier(f.Injuries, Weapons.isTwoHanded(weaponOf(f)), f.MainHand)
end

function Rules.isAlive(f: Fighter): boolean
	return f.State ~= "KO"
end

function Rules.isInvulnerable(f: Fighter, now: number): boolean
	if Schema.isInvulnerable(f.State) or now < f.InvulnerableUntil then
		return true
	end
	return f.State == "Dashing" and now >= f.IFrameStart and now <= f.IFrameEnd
end

function Rules.speedMultiplier(f: Fighter): number
	local weapon = weaponOf(f)
	local sprint = if f.Sprinting and f.State == "Idle" then Settings.Movement.SprintSpeed / Settings.Movement.WalkSpeed else 1
	return STATE_SPEED[f.State] * f.Penalties.SpeedMultiplier * weapon.MoveSpeedMultiplier * sprint * f.ArmorSpeed
end

function Rules.recoveryStart(f: Fighter): number
	local move = f.Move
	if move == nil then
		return f.StateStart
	end
	return f.MoveStart + move.Timing.StartupSeconds + move.Timing.ActiveSeconds
end

function Rules.comboWindowOpen(f: Fighter, now: number): boolean
	local move = f.Move
	if f.State ~= "Recovery" or move == nil or move.Timing.ComboWindowSeconds <= 0 then
		return false
	end
	return now - Rules.recoveryStart(f) <= move.Timing.ComboWindowSeconds + Tempo.HalfTick
end

-- A light hitstun (shorter than the heavy one) opens to Deflect/Block after Stun.LightDefendCancel.
function Rules.lightHitstunDefendable(f: Fighter, now: number): boolean
	return f.State == "Hitstun" and f.StateEnd - f.StateStart < Settings.Stun.HitstunHeavy - 1e-6
		and now - f.StateStart >= Settings.Stun.LightDefendCancel - Tempo.HalfTick
end

-- Earliest time the fighter can answer a new attack (deflect, guard or dodge): the light-hitstun defend point,
-- the end of a heavy hitstun, otherwise now. AI telegraphs count their reaction lead from here, not from the
-- moment they decide, so a swing chosen while the target still reels cannot land inside its reaction floor.
function Rules.defendableAt(f: Fighter, now: number): number
	if f.State ~= "Hitstun" then
		return now
	end
	if f.StateEnd - f.StateStart < Settings.Stun.HitstunHeavy - 1e-6 then
		return math.max(now, f.StateStart + Settings.Stun.LightDefendCancel)
	end
	return math.max(now, f.StateEnd)
end

function Rules.cancelWindowOpen(f: Fighter, now: number): boolean
	if f.State == "Hitstun" then
		return Rules.lightHitstunDefendable(f, now)
	elseif f.State == "Recovery" then
		local move = f.Move
		return move ~= nil and now - f.MoveStart >= Tempo.framesToSeconds(move.Timing.CancelFrame) - Tempo.HalfTick
	elseif f.State == "Dashing" then
		return now - f.StateStart >= f.DashDuration * Settings.Backdash.CancelFraction
	end
	return false
end

-- 0..1 progress through the active frames (drives procedural weapon arcs); nil outside Active.
function Rules.activeProgress(f: Fighter, now: number): number?
	local move = f.Move
	if f.State ~= "Active" or move == nil then
		return nil
	end
	local start = f.MoveStart + move.Timing.StartupSeconds
	return math.clamp((now - start) / math.max(move.Timing.ActiveSeconds, Tempo.TickSeconds), 0, 1)
end

function Rules.context(f: Fighter, now: number, extra: Context?): Context
	local ctx: Context = {
		ComboWindowOpen = Rules.comboWindowOpen(f, now),
		CancelWindowOpen = Rules.cancelWindowOpen(f, now),
		Sprinting = f.Sprinting,
		DeflectReady = true,
		Qi = f.Qi,
		ArmTier = Rules.armTier(f),
	}
	if extra then
		for key, value in extra :: any do
			(ctx :: any)[key] = value
		end
	end
	return ctx
end

-------------------------------------------------------------------------------------------------
-- 1. Stamina & posture expenditure
-------------------------------------------------------------------------------------------------

function Rules.attackStaminaCost(f: Fighter, move: MoveData): number
	return move.StaminaCost * Schema.armStaminaMultiplier(Rules.armTier(f))
end

-- Spends stamina; returns true when the fighter is now at or below the break threshold.
function Rules.spendStamina(f: Fighter, amount: number, now: number): boolean
	if amount <= 0 then
		return f.Stamina <= Settings.Stamina.BreakThreshold
	end
	f.Stamina = math.max(f.Stamina - amount, Settings.Stamina.BreakThreshold - f.MaxStamina)
	f.StaminaRegenAt = now + Settings.Stamina.RegenDelay
	return f.Stamina <= Settings.Stamina.BreakThreshold
end

local function staminaBreak(f: Fighter, now: number, events: { Event }?, source: number)
	if f.State == "KO" or f.State == "StanceBroken" or f.State == "DeathblowVictim" or f.State == "DeathblowAttacker" then
		return
	end
	clearMove(f)
	f.Stamina = math.max(f.Stamina, 0)
	f.Sprinting = false
	enter(f, "StaminaBroken", now, Settings.Stun.StaminaBroken)
	emit(f, events, "StaminaBreak", source, f.Id, f.Stamina)
end

local function stanceBreak(f: Fighter, now: number, events: { Event }?, source: number)
	clearMove(f)
	f.Posture = Rules.maxPosture(f)
	f.Sprinting = false
	enter(f, "StanceBroken", now, Settings.Stun.StanceBroken)
	emit(f, events, "StanceBreak", source, f.Id, f.Posture)
end

-- Adds posture; returns true if this triggered a StanceBreak. `cap` keeps posture below the break line.
function Rules.addPosture(f: Fighter, amount: number, now: number, events: { Event }?, source: number, cap: boolean?): boolean
	if amount <= 0 or f.State == "KO" or f.State == "StanceBroken" or f.State == "DeathblowVictim" or f.State == "DeathblowAttacker" then
		return false
	end
	local limit = Rules.maxPosture(f)
	if not cap and f.WardUntil > now and f.Posture + amount >= limit then
		f.WardUntil = 0; return false
	end
	f.Posture = if cap then math.min(f.Posture + amount, limit - 1) else f.Posture + amount
	f.PostureDecayAt = now + Settings.Posture.DecayDelay
	if f.Posture >= limit then
		stanceBreak(f, now, events, source)
		return true
	end
	return false
end

-------------------------------------------------------------------------------------------------
-- 4. Blood Rally / tri-layer health
-------------------------------------------------------------------------------------------------

local function convertRecoverable(f: Fighter)
	if f.RecoverableHP <= 0 then
		return
	end
	f.PermanentDeficit = math.min(Rules.maxPermanentDeficit(f), f.PermanentDeficit + f.RecoverableHP)
	f.RecoverableHP = 0
end

local function clampLayers(f: Fighter)
	local cap = Rules.effectiveMaxHP(f)
	f.ActiveHP = math.min(f.ActiveHP, cap)
	f.RecoverableHP = math.clamp(f.RecoverableHP, 0, math.max(cap - math.max(f.ActiveHP, 0), 0))
end

-- Applies damage to ActiveHP and distributes it into the recoverable and permanent layers.
-- Returns ActiveHP actually removed.
-- `protection` is the armour share the caller says applies; burn, bleed, deathblows and outside damage pass none.
function Rules.applyDamage(f: Fighter, amount: number, category: DamageCategory, now: number, protection: number?): number
	amount *= 1 - (protection or 0)
	if amount <= 0 or f.State == "KO" then
		return 0
	end
	if f.WardUntil > now and amount >= f.ActiveHP then f.WardUntil = 0; return 0 end
	local health = Settings.Health
	if category == "Heavy" or category == "Deathblow" then
		convertRecoverable(f)
	end
	local dealt = math.min(amount, math.max(f.ActiveHP, 0))
	if f.KOProtected then
		dealt = math.min(dealt, math.max(f.ActiveHP - 1, 0))
	end
	f.ActiveHP -= dealt
	f.RecoverableHP += dealt * (health.RecoverableFraction[category] or 0)
	f.PermanentDeficit = math.min(Rules.maxPermanentDeficit(f), f.PermanentDeficit + dealt * (health.PermanentFraction[category] or 0))
	f.RallyUntil = now + health.Rally.Window
	clampLayers(f)
	return dealt
end

-- Striking back inside the rally window returns RecoverableHP proportional to damage dealt.
function Rules.rally(f: Fighter, dealt: number, now: number, events: { Event }?, target: number): number
	if dealt <= 0 or now > f.RallyUntil or f.RecoverableHP <= 0 or f.State == "KO" then
		return 0
	end
	local restored = math.min(f.RecoverableHP, dealt * Settings.Health.Rally.ReturnRatio * f.RallyScale)
	f.RecoverableHP -= restored
	f.ActiveHP += restored
	clampLayers(f)
	emit(f, events, "Rally", f.Id, target, restored)
	return restored
end

function Rules.heal(f: Fighter, amount: number)
	if f.State == "KO" or amount <= 0 then
		return
	end
	local fromRecoverable = math.min(f.RecoverableHP, amount)
	f.RecoverableHP -= fromRecoverable
	f.ActiveHP += amount
	clampLayers(f)
end

-------------------------------------------------------------------------------------------------
-- Injury trauma
-------------------------------------------------------------------------------------------------

local function addTrauma(f: Fighter, region: InjuryRegion, amount: number, now: number, events: { Event }?, source: number)
	if amount <= 0 then
		return
	end
	f.Trauma[region] = math.min(1, f.Trauma[region] + amount)
	f.TraumaAt = now
	local tier: InjuryTier = Schema.tierFromCoefficient(region, f.Trauma[region])
	if tier ~= f.Injuries[region] then
		local rose = Schema.tierIndex(tier) > Schema.tierIndex(f.Injuries[region])
		f.Injuries[region] = tier
		refreshPenalties(f)
		if rose then
			emit(f, events, "InjuryTier", source, f.Id, Schema.tierIndex(tier), region)
		end
	end
end

function Rules.traumaFor(move: MoveData, region: InjuryRegion): number
	local amount: number = (move.Trauma :: any)[GROUP[region]]
	if amount <= 0 then
		amount = FLOOR_TRAUMA
	end
	if region == "Head" and move.DamageType == "Blunt" then
		amount *= Settings.Injury.BluntHeadConcussionScale
	end
	return amount
end

-------------------------------------------------------------------------------------------------
-- Timed simulation
-------------------------------------------------------------------------------------------------

local function expire(f: Fighter, now: number, events: { Event }?)
	local state = f.State
	local move = f.Move
	if state == "Startup" and move then
		f.State = "Active"
		f.StateStart = f.MoveStart + move.Timing.StartupSeconds
		f.StateEnd = f.StateStart + move.Timing.ActiveSeconds
		table.clear(f.HitRegistry)
	elseif state == "Active" and move then
		f.State = "Recovery"
		f.StateStart = f.StateEnd
		f.StateEnd = f.StateStart + move.Timing.RecoverySeconds
		if next(f.HitRegistry) == nil and not Rules.RangedEffects[move.Effect or ""] then
			emit(f, events, "Whiff", f.Id, 0, 0) -- the server fills in the nearest foe and the reach gap
		end
	elseif state == "Deflecting" or state == "Blockstun" then
		local guard = f.GuardHeld and f.Stamina > Settings.Stamina.BreakThreshold
		enter(f, if guard then "Blocking" else "Idle", f.StateEnd)
	elseif state == "StaminaBroken" then
		f.Stamina = math.max(f.Stamina, f.MaxStamina * Settings.Stamina.RecoverToFraction)
		enter(f, "Idle", f.StateEnd)
	elseif state == "StanceBroken" then
		f.Posture = Settings.Posture.StanceBreakResetValue
		enter(f, "Idle", f.StateEnd)
	elseif state == "DeathblowVictim" then
		-- F07: the KO names its executioner. With source 0 a killing deathblow paid no Essence, mastery
		-- or ore (WorldService credits the KO's source), so finishing a foe properly earned nothing.
		local executioner = f.DeathblowPartner
		f.Posture = 0
		f.DeathblowPartner = 0
		if f.PendingKO or f.ActiveHP <= 0 then
			f.PendingKO = false
			enter(f, "KO", f.StateEnd)
			emit(f, events, "KO", executioner, f.Id, 0)
		else
			enter(f, "Idle", f.StateEnd)
		end
	elseif state == "DeathblowAttacker" then
		f.DeathblowPartner = 0
		enter(f, "Idle", f.StateEnd)
	elseif state ~= "KO" then
		clearMove(f)
		enter(f, "Idle", f.StateEnd)
	end
	if f.State == "Idle" then
		clearMove(f)
	end
end

local function regenerate(f: Fighter, now: number, dt: number)
	if f.State ~= "KO" then f.Qi = math.min(f.MaxQi, f.Qi + Settings.Qi.PassiveRegen * dt) end
	if f.State == "KO" then
		return
	end
	local stamina = Settings.Stamina
	local posture = Settings.Posture
	local health = Settings.Health

	if f.Sprinting then
		if f.State == "Idle" then
			f.Stamina -= stamina.SprintCostPerSecond * dt
			f.StaminaRegenAt = now + stamina.RegenDelay * 0.5
			if f.Stamina <= 1 then
				f.Stamina = math.max(f.Stamina, 1)
				f.Sprinting = false
			end
		elseif f.State ~= "Startup" and f.State ~= "Active" and f.State ~= "Recovery" then
			f.Sprinting = false
		end
	end

	if now >= f.StaminaRegenAt and f.Stamina < f.MaxStamina then
		local rate = stamina.RegenRate * f.Penalties.StaminaRegenMultiplier
		if Schema.isGuarding(f.State) then
			rate *= stamina.GuardRegenMultiplier
		elseif f.State == "StaminaBroken" then
			rate *= stamina.BrokenRegenMultiplier
		end
		f.Stamina = math.min(f.MaxStamina, f.Stamina + rate * dt)
	end

	if now >= f.PostureDecayAt and f.Posture > 0 and f.State ~= "StanceBroken" then
		local hpRatio = math.clamp(f.ActiveHP / Rules.effectiveMaxHP(f), 0, 1)
		local scale = posture.LowHealthDecayScale
		local hpScale = scale.AtZeroHP + (scale.AtFullHP - scale.AtZeroHP) * hpRatio
		local rate = posture.DecayRate * Schema.postureDecayMultiplier(f.State) * hpScale * f.Penalties.PostureDecayMultiplier
		f.Posture = math.max(0, f.Posture - rate * dt)
	end

	if now > f.RallyUntil + (health.Rally.DecayDelay - health.Rally.Window) and f.RecoverableHP > 0 then
		f.RecoverableHP = math.max(0, f.RecoverableHP - health.Rally.DecayRate * dt)
	end

	if now >= f.BleedDecayAt and f.Bleed > 0 then
		f.Bleed = math.max(0, f.Bleed - Settings.Bleed.DecayRate * dt)
	end

	if Settings.Qi.DecayRate > 0 and f.Qi > 0 then
		f.Qi = math.max(0, f.Qi - Settings.Qi.DecayRate * dt)
	end

	if now >= f.TraumaAt + Settings.Injury.RecoveryDelay then
		local changed = false
		for _, region in REGIONS do
			local value = f.Trauma[region]
			if value > 0 then
				local group = Settings.Injury.Group[region]
				local floor = Schema.recoveryFloor(region, value)
				local nextValue = math.max(floor, value - Settings.Injury.RecoveryPerSecond[group] * dt)
				if nextValue ~= value then
					f.Trauma[region] = nextValue
					local tier: InjuryTier = Schema.tierFromCoefficient(region, nextValue)
					if tier ~= f.Injuries[region] then
						f.Injuries[region] = tier
						changed = true
					end
				end
			end
		end
		if changed then
			refreshPenalties(f)
		end
	end
end

-- Advances timers, state expiry and passive regeneration by one tick ending at `now`.
function Rules.step(f: Fighter, now: number, dt: number, events: { Event }?)
 if f.BurnUntil>now-dt and f.State~="KO" then
  local dealt=Rules.applyDamage(f,f.BurnRate*math.min(dt,math.max(0,f.BurnUntil-(now-dt))),"Chip",now)
  if f.ActiveHP<=0 then clearMove(f);enter(f,"KO",now);emit(f,events,"KO",f.BurnSource,f.Id,dealt) end
 end
	for _ = 1, 4 do
		if now < f.StateEnd then
			break
		end
		local before = f.State
		expire(f, now, events)
		if f.State == before and f.StateEnd == NEVER then
			break
		end
	end
	-- Elixir resolves at the end of the drink unless the drink was interrupted.
	if f.PendingHeal > 0 and now >= f.PendingHealAt then
		if f.State == "Recovery" and f.Move == nil then
			Rules.heal(f, f.PendingHeal)
		end
		f.PendingHeal = 0
		f.PendingHealAt = NEVER
	elseif f.PendingHeal > 0 and (f.State ~= "Recovery" or f.Move ~= nil) then
		f.PendingHeal = 0
		f.PendingHealAt = NEVER
	end
	-- An action that spent the last stamina leaves the fighter winded once it resolves.
	if f.State == "Idle" and f.Stamina <= Settings.Stamina.BreakThreshold then
		staminaBreak(f, now, events, f.Id)
	end
	regenerate(f, now, dt)
end

-------------------------------------------------------------------------------------------------
-- Intents
-------------------------------------------------------------------------------------------------

function Rules.selectMove(f: Fighter, kind: MoveKind, now: number): MoveData
	local weapon = weaponOf(f)
	if kind == "Light" then
		local current = f.Move
		if current ~= nil and current.Kind == "Light" and Rules.comboWindowOpen(f, now) then
			return Weapons.nextLight(weapon, current)
		end
		return weapon.Light[1]
	end
	return Weapons.moveForKind(weapon, kind, nil)
end

function Rules.tryAttack(f: Fighter, kind: MoveKind, now: number): (boolean, string)
	local move = Rules.selectMove(f, kind, now)
	local ctx = Rules.context(f, now, { StaminaCost = move.StaminaCost, QiCost = if move.QiCost > 0 then move.QiCost else nil })
	local ok, reason = Schema.canAct(f.State, kind, f.Stamina, f.Posture, ctx)
	if not ok then
		return false, reason
	end
	Rules.spendStamina(f, Rules.attackStaminaCost(f, move), now)
	if move.QiCost > 0 then
		f.Qi = math.max(0, f.Qi - move.QiCost)
	end
	if kind ~= "RunningAttack" then
		f.Sprinting = false
	end
	table.clear(f.HitRegistry)
	f.Move = move
	f.MoveStart = now
	f.State = "Startup"
	f.StateStart = now
	f.StateEnd = now + move.Timing.StartupSeconds
	return true, move.Id
end

-- 5b. Feint: a Heavy or Weapon Art may be abandoned inside the feint window for a flat stamina cost.
function Rules.tryFeint(f: Fighter, now: number, events: { Event }?): (boolean, string)
	local move = f.Move
	if f.State ~= "Startup" or move == nil then
		return false, "NotInStartup"
	end
	if not Settings.Feint.Kinds[move.Kind] then
		return false, "NotFeintable"
	end
	if now - f.MoveStart > Settings.Feint.Window + Tempo.HalfTick then
		return false, "FeintWindowClosed"
	end
	local cost = Settings.Stamina.Costs.Feint
	if f.Stamina < cost then
		return false, Schema.Reasons.InsufficientStamina
	end
	Rules.spendStamina(f, cost, now)
	clearMove(f)
	enter(f, "Idle", now)
	emit(f, events, "Feint", f.Id, f.Id, cost)
	return true, "Feint"
end

function Rules.tryDeflect(f: Fighter, now: number, pressTime: number?): (boolean, string)
	local ok, reason = Schema.canAct(f.State, "Deflect", f.Stamina, f.Posture, Rules.context(f, now))
	if not ok then
		return false, reason
	end
	local posture = Settings.Posture
	local pressed = math.min(pressTime or now, now)
	if f.State == "Hitstun" or f.State == "Blockstun" then
		pressed = math.max(pressed, f.StateStart) -- never retroactive: a window cannot cover a contact already resolved
	end
	if pressed - f.LastDeflectPress <= posture.DeflectSpamLockout then
		f.DeflectChain += 1
	else
		f.DeflectChain = 0
	end
	f.LastDeflectPress = pressed
	local base = Schema.headDeflectWindow(f.Injuries.Head)
	f.DeflectWindow = math.max(posture.DeflectChainFloor, base * (1 - posture.DeflectSpamDecay) ^ f.DeflectChain)
	f.DeflectPressedAt = pressed
	clearMove(f)
	f.Sprinting = false
	f.State = "Deflecting"
	f.StateStart = pressed
	f.StateEnd = math.max(now + Tempo.TickSeconds, pressed + f.DeflectWindow + posture.DeflectRecovery)
	return true, "Deflect"
end

-- Whether a deflect or a dash started now would be legal: a contact on a player may then wait for one that is
-- still in flight (CharacterService bounded grace).
function Rules.couldDefend(f: Fighter, now: number): boolean
	local ctx = Rules.context(f, now)
	return (Schema.canAct(f.State, "Deflect", f.Stamina, f.Posture, ctx))
		or (f.RootUntil <= now and (Schema.canAct(f.State, "Dash", f.Stamina, f.Posture, ctx)))
end

function Rules.setGuard(f: Fighter, held: boolean, now: number): (boolean, string)
	f.GuardHeld = held
	if held then
		if f.State == "Blocking" then
			return true, "Blocking"
		end
		if f.State ~= "Idle" and f.State ~= "Recovery" and f.State ~= "Hitstun" then
			return false, Schema.Reasons.NotInWindow
		end
		local ok, reason = Schema.canAct(f.State, "Block", f.Stamina, f.Posture, Rules.context(f, now))
		if not ok then
			return false, reason
		end
		clearMove(f)
		f.Sprinting = false
		enter(f, "Blocking", now)
		return true, "Blocking"
	end
	if f.State == "Blocking" then
		enter(f, "Idle", now)
	end
	return true, "Released"
end

function Rules.setSprint(f: Fighter, on: boolean, now: number): boolean
	if not on then
		f.Sprinting = false
		return true
	end
	local ok = Schema.canAct(f.State, "Sprint", f.Stamina, f.Posture, Rules.context(f, now))
	f.Sprinting = ok
	return ok
end

-- 6. Evasion with backdash decay: rapid Roll/Dash spam shortens distance and i-frames.
-- Touchdown after an aerial strike (StrikeGeometry): the landing costs `seconds` of move-less
-- Recovery (guard and deflect stay open, no combo or dodge cancel). Returns "Wait" while the swing or
-- an air dodge is still out (dodging into the ground does not skip the landing), "Applied" once paid,
-- "Dropped" when a stun or KO already took over.
function Rules.landingRecovery(f: Fighter, now: number, seconds: number): "Applied" | "Wait" | "Dropped"
	if f.State == "Startup" or f.State == "Active" or f.State == "Dashing" then
		return "Wait"
	elseif (f.State ~= "Idle" and f.State ~= "Recovery") or f.PendingHeal > 0 then
		return "Dropped"
	end
	local remaining = if f.State == "Recovery" then math.max(f.StateEnd - now, seconds) else seconds
	clearMove(f)
	enter(f, "Recovery", now, remaining)
	return "Applied"
end

-- `pressedAt` is the accepted press time (default `now`); it only anchors i-frames for a contact held in the
-- defender's grace (Rules.dashCovers). Distance, duration and the grant's own i-frames start at `now`.
function Rules.tryDash(f: Fighter, kind: "Roll" | "Dash", now: number, dirX: number, dirZ: number, events: { Event }?, pressedAt: number?): (DashGrant?, string)
	if f.RootUntil > now then return nil, "Rooted" end
	local ok, reason = Schema.canAct(f.State, kind, f.Stamina, f.Posture, Rules.context(f, now))
	if not ok then
		return nil, reason
	end
	local decay = Settings.Backdash
	local movement = Settings.Movement
	if now - f.LastDashAt <= decay.SpamWindow then
		f.DashChain += 1
	else
		f.DashChain = 0
	end
	f.LastDashAt = now
	local distanceScale = math.max(decay.MinDistanceScale, 1 - decay.DecayPerUse * f.DashChain)
	local iframeScale = math.max(decay.MinIFrameScale, 1 - decay.IFrameDecayPerUse * f.DashChain)
	local roll = kind == "Roll"
	local baseDistance = if roll then movement.RollDistance else movement.DashDistance
	local duration = if roll then movement.RollDuration else movement.DashDuration
	local window = if roll then movement.RollInvulnerable else movement.DashInvulnerable
	Rules.spendStamina(f, Schema.staminaCost(kind, nil), now)
	clearMove(f)
	f.Sprinting = false
	local magnitude = math.sqrt(dirX * dirX + dirZ * dirZ)
	f.DashDirX = if magnitude > 1e-6 then dirX / magnitude else 0
	f.DashDirZ = if magnitude > 1e-6 then dirZ / magnitude else 0
	f.DashDistance = baseDistance * distanceScale * f.Penalties.DashDistanceMultiplier
	f.DashDuration = duration
	f.DashPressedAt = math.min(pressedAt or now, now)
	f.IFrameStart = now + window.Start
	f.IFrameEnd = now + window.Start + (window.Finish - window.Start) * iframeScale
	if iframeScale <= 0 then
		f.IFrameEnd = f.IFrameStart - 1
	end
	f.DashSeq = (f.DashSeq + 1) % 256
	enter(f, "Dashing", now, duration)
	emit(f, events, "Dash", f.Id, f.Id, f.DashDistance)
	return { Distance = f.DashDistance, Duration = duration, IFrameStart = f.IFrameStart, IFrameEnd = f.IFrameEnd, Seq = f.DashSeq }, kind
end

function Rules.tryEquip(f: Fighter, weapon: WeaponType, now: number): (boolean, string)
	if Weapons.Weapons[weapon] == nil then
		return false, "UnknownWeapon"
	end
	local ok, reason = Schema.canAct(f.State, "Equip", f.Stamina, f.Posture, Rules.context(f, now))
	if not ok then
		return false, reason
	end
	f.Weapon = weapon
	clearMove(f)
	refreshPenalties(f)
	return true, weapon
end

function Rules.tryRest(f: Fighter, now: number, atShrine: boolean, events: { Event }?): (boolean, string)
	if f.State == "RestingAtShrine" then
		enter(f, "Idle", now)
		return true, "Rose"
	end
	local ok, reason = Schema.canAct(f.State, "RestAtShrine", f.Stamina, f.Posture, Rules.context(f, now, { AtShrine = atShrine }))
	if not ok then
		return false, reason
	end
	Rules.restore(f, now, false)
	enter(f, "RestingAtShrine", now, Settings.Health.Shrine.RestDuration)
	emit(f, events, "Rest", f.Id, f.Id, 0)
	return true, "Rest"
end

-- Health a drink could restore right now: up to the current ceiling (effective max HP), which a
-- permanent deficit lowers until rest. Below one point the drink would be wasted.
function Rules.healRoom(f: Fighter): number
	return math.max(0, Rules.effectiveMaxHP(f) - math.max(f.ActiveHP, 0))
end

-- Elixir drink: a short interruptible Recovery; the heal lands when the drink completes.
-- Refused with nothing spent when there is no room below the ceiling ("FullHealth", or
-- "AtCeiling" when the ceiling itself is lowered); wounded fighters below a lowered ceiling drink.
function Rules.tryHeal(f: Fighter, now: number, fraction: number?, duration: number?): (boolean, string)
	if f.State ~= "KO" and Rules.healRoom(f) < 1 then
		return false, if Rules.effectiveMaxHP(f) < f.MaxHP - 0.5 then "AtCeiling" else "FullHealth"
	end
	local ok, reason = Schema.canAct(f.State, "Heal", f.Stamina, f.Posture, Rules.context(f, now, { HasHealCharge = true }))
	if not ok then
		return false, reason
	end
	local elixir = Settings.Elixir
	local drink = duration or elixir.DrinkDuration
	clearMove(f)
	f.Sprinting = false
	enter(f, "Recovery", now, drink)
	f.PendingHeal = f.MaxHP * (fraction or elixir.HealFraction)
	f.PendingHealAt = now + drink - Tempo.HalfTick
	return true, "Heal"
end

-- Cinematic lock (boss metamorphosis, scripted beats): cannot act or be struck for `duration`.
function Rules.cinematic(f: Fighter, now: number, duration: number)
	clearMove(f)
	f.Sprinting = false
	f.GuardHeld = false
	enter(f, "Recovery", now, duration)
	f.InvulnerableUntil = now + duration
end

-- Swaps weapon outside the Equip eligibility rules (phase transitions, scripted loadouts).
function Rules.forceWeapon(f: Fighter, weapon: WeaponType)
	assert(Weapons.Weapons[weapon] ~= nil, "Unknown weapon")
	f.Weapon = weapon
	clearMove(f)
	refreshPenalties(f)
end

-- Area strike (shockwaves, hazards). I-frames evade; a timed deflect or guard absorbs unless unblockable.
function Rules.applyArea(source: Fighter, target: Fighter, now: number, damage: number, posture: number, unblockable: boolean, facing: boolean, events: { Event }?): HitOutcome
	if target.State == "KO" or target.Id == source.Id then
		return "Ignored"
	end
	if Rules.isInvulnerable(target, now) then
		emit(target, events, "Evade", target.Id, source.Id, 0)
		return "Whiff"
	end
	if not unblockable and facing and Rules.isDeflectTimed(target, now) then
		Rules.addPosture(target, posture * Settings.Posture.DeflectSelfScale, now, events, source.Id, true)
		target.Qi = math.min(target.MaxQi, target.Qi + Settings.Qi.GainOnDeflect)
		local reflect = weaponOf(target).PostureReflect or 0
		if reflect > 0 then Rules.addPosture(source,posture*reflect,now,events,target.Id) end
	emit(target, events, "DeflectSpark", target.Id, source.Id, 0)
		return "Deflected"
	end
	if not unblockable and facing and (target.State == "Blocking" or target.State == "Blockstun") then
		local depleted = Rules.spendStamina(target, Settings.Stamina.Costs.Block, now)
		Rules.applyDamage(target, damage * 0.2, "Chip", now, target.Protection)
		if Rules.addPosture(target, posture, now, events, source.Id) then
			return "Blocked"
		end
		if depleted then
			clearMove(target)
			enter(target, "GuardBroken", now, Settings.Stun.GuardBroken)
			emit(target, events, "GuardBreak", source.Id, target.Id, posture)
			return "GuardBroken"
		end
		enter(target, "Blockstun", now, Settings.Stun.Blockstun)
		emit(target, events, "Block", source.Id, target.Id, damage * 0.2)
		return "Blocked"
	end
	local dealt = Rules.applyDamage(target, damage, "WeaponArt", now, target.Protection)
	emit(target, events, "Hit", source.Id, target.Id, dealt, "Torso")
	if target.ActiveHP <= 0 then
		clearMove(target)
		enter(target, "KO", now)
		emit(target, events, "KO", source.Id, target.Id, dealt)
		return "KO"
	end
	if Rules.addPosture(target, posture * (1 - target.PoiseArmor * Settings.Poise.PostureReduction), now, events, source.Id) then
		return "Hit"
	end
	if target.PoiseArmor < Settings.Poise.HeavyThreshold then
		clearMove(target)
		target.Sprinting = false
		enter(target, "Hitstun", now, Settings.Stun.HitstunHeavy)
	end
	return "Hit"
end

-- Boss perilous contracts use the same damage, posture and event pipeline as all combat.
function Rules.applyBossAttack(source: Fighter, target: Fighter, now: number, damage: number, posture: number, kind: string, facing: boolean, events: { Event }?): HitOutcome
	-- Same deflect rule as every other contact (Stage 2): the press's own window, scaled by head injury and spam
	-- decay, with half-tick tolerance, never wider than the baseline window. A success resets the spam chain.
	if (kind == "PerilousThrust" or kind == "PerilousCut") and facing and Rules.isDeflectTimed(target, now, Settings.Posture.DeflectWindow) then
		if not Rules.isInvulnerable(target, now) then
			target.DeflectChain = 0
			target.LastDeflectPress = -NEVER
			Rules.addPosture(source, posture * 2.5, now, events, target.Id)
			Rules.addPosture(target, posture * Settings.Posture.DeflectSelfScale, now, events, source.Id, true)
			target.Qi = math.min(target.MaxQi, target.Qi + Settings.Qi.GainOnDeflect)
			emit(target, events, "DeflectSpark", target.Id, source.Id, posture * 2.5)
			return "Deflected"
		end
	end
	local unblockable = kind ~= "Barrage" and kind ~= "ShieldCharge"
	local result = Rules.applyArea(source, target, now, damage, posture, unblockable, facing, events)
	if kind == "PerilousGrab" and result == "Hit" then Rules.cinematic(target, now, 1.2) end
	return result
end

-------------------------------------------------------------------------------------------------
-- 3. StanceBreak & Deathblow
-------------------------------------------------------------------------------------------------

function Rules.canDeathblow(attacker: Fighter, victim: Fighter, distance: number, facingDot: number, now: number): (boolean, string)
	if victim.State ~= "StanceBroken" then
		return false, Schema.Reasons.NoDeathblowTarget
	end
	local deathblow = Settings.Deathblow
	if distance > deathblow.Range or facingDot < deathblow.FacingDot then
		return false, Schema.Reasons.NoDeathblowTarget
	end
	return Schema.canAct(attacker.State, "Deathblow", attacker.Stamina, attacker.Posture, Rules.context(attacker, now, { TargetDeathblowable = true }))
end

function Rules.executeDeathblow(attacker: Fighter, victim: Fighter, now: number, events: { Event }?): number
	local deathblow = Settings.Deathblow
	clearMove(attacker)
	clearMove(victim)
	attacker.Sprinting = false
	victim.Sprinting = false
	enter(attacker, "DeathblowAttacker", now, Settings.Stun.DeathblowAttacker)
	enter(victim, "DeathblowVictim", now, Settings.Stun.DeathblowVictim)
	attacker.DeathblowPartner = victim.Id
	victim.DeathblowPartner = attacker.Id
	local damage = math.max(deathblow.MinimumDamage, victim.MaxHP * deathblow.DamageFraction) * (if attacker.SignatureFinisher then 1.2 else 1)
	local dealt = Rules.applyDamage(victim, damage, "Deathblow", now)
	if deathblow.ClearsPosture then
		victim.Posture = 0
		attacker.Posture = 0
	end
	victim.PendingKO = victim.ActiveHP <= 0
	attacker.Qi = math.min(attacker.MaxQi, attacker.Qi + Settings.Qi.GainOnDeathblow)
	attacker.DashChain = 0
	Rules.rally(attacker, dealt, now, events, victim.Id)
	emit(attacker, events, "Deathblow", attacker.Id, victim.Id, dealt)
	emit(victim, nil, "Deathblow", attacker.Id, victim.Id, dealt)
	return dealt
end

-------------------------------------------------------------------------------------------------
-- 2 + 4 + 5. Hit resolution: deflect -> block -> counter-hit -> damage, rally, posture, bleed, trauma
-------------------------------------------------------------------------------------------------

-- A dash granted after `at` whose accepted press was at or before it: the same i-frame window, anchored to the
-- press instead of the grant, covers `at`. Only a contact held in the defender's grace can ask this, so a press
-- in flight evades as it would have at t_c; the dash's own i-frames from the grant are Rules.isInvulnerable.
function Rules.dashCovers(f: Fighter, at: number): boolean
	if f.State ~= "Dashing" or at >= f.StateStart or f.DashPressedAt > at + Tempo.HalfTick then
		return false
	end
	local from = f.DashPressedAt + (f.IFrameStart - f.StateStart)
	local to = f.DashPressedAt + (f.IFrameEnd - f.StateStart)
	return to >= from and at >= from - Tempo.HalfTick and at <= to + Tempo.HalfTick
end

function Rules.contactSnapshot(attacker: Fighter, defender: Fighter, at: number, move: MoveData): ContactSnapshot
	return {
		At = at,
		DefenderState = defender.State,
		DefenderMove = defender.Move,
		DefenderWeapon = defender.Weapon,
		DefenderPoise = defender.PoiseArmor,
		DefenderProtection = defender.Protection,
		Invulnerable = Rules.isInvulnerable(defender, at),
		AttackerWeapon = attacker.Weapon,
		ArmTier = Rules.armTier(attacker),
		DamageScale = Rules.damageScale(attacker, move),
		InfusionStun = attacker.InfusionStun,
		InfusionBurn = attacker.InfusionBurn,
		GuardPierce = attacker.GuardPierce,
	}
end

-- `cap` bounds the press's window (a perilous thrust never deflects wider than the baseline window).
function Rules.isDeflectTimed(defender: Fighter, hitTime: number, cap: number?): boolean
	if defender.State ~= "Deflecting" then
		return false
	end
	local delta = hitTime - defender.DeflectPressedAt
	local window = if cap then math.min(defender.DeflectWindow, cap) else defender.DeflectWindow
	return delta >= -Tempo.HalfTick and delta <= window + Tempo.HalfTick
end

local function hitstunFor(move: MoveData): number
	return if move.Kind == "Light" then Settings.Stun.HitstunLight else Settings.Stun.HitstunHeavy
end

function Rules.resolveHit(attacker: Fighter, defender: Fighter, now: number, hit: HitContext, events: { Event }?): HitOutcome
	local deferred = hit.Move
	local move = deferred or attacker.Move
	if deferred == nil and (attacker.State ~= "Active" or attacker.HitRegistry[defender.Id]) then
		return "Ignored" -- a deferred contact already claimed its HitRegistry entry when it was detected
	end
	if move == nil or defender.Id == attacker.Id or defender.State == "KO" then
		return "Ignored"
	end
	if deferred == nil then
		-- A deferred contact claimed its entry at detection; writing it now would land in the registry of any
		-- newer swing the attacker started meanwhile and stop that swing from hitting this defender.
		attacker.HitRegistry[defender.Id] = true
	end
	local at = hit.At or now
	local snap = hit.Snapshot or Rules.contactSnapshot(attacker, defender, at, move)
	local defenderState: State = hit.DefenderState or snap.DefenderState
	if snap.Invulnerable or Rules.dashCovers(defender, at) then
		emit(defender, events, "Evade", defender.Id, attacker.Id, 0)
		return "Whiff"
	end

	local attackerWeapon = Weapons.Weapons[snap.AttackerWeapon]
	local defenderWeapon = Weapons.Weapons[snap.DefenderWeapon]

	-- 2. Perfect deflect: negate damage, heavy posture onto the attacker, spark.
	if hit.Facing and move.Deflectable and Rules.isDeflectTimed(defender, at) then
		local outcome = Weapons.deflectOutcome(move, attackerWeapon, defenderWeapon)
		local bonus = Weapons.postureDamage(move,attackerWeapon)*(defenderWeapon.PostureReflect or 0)
		local reflected = math.max(outcome.AttackerPosture-bonus, Settings.Posture.DeflectMinimumReflect)+bonus
		Rules.addPosture(defender, outcome.DefenderPosture, now, events, attacker.Id, true)
		defender.Qi = math.min(defender.MaxQi, defender.Qi + Settings.Qi.GainOnDeflect)
		defender.DeflectChain = 0
		defender.LastDeflectPress = -NEVER
		if now <= defender.RallyUntil and defender.RecoverableHP > 0 then
			local restored = math.min(defender.RecoverableHP, Settings.Health.Rally.DeflectBonus)
			defender.RecoverableHP -= restored
			defender.ActiveHP += restored
			clampLayers(defender)
			emit(defender, events, "Rally", defender.Id, attacker.Id, restored)
		end
		emit(defender, events, "DeflectSpark", defender.Id, attacker.Id, reflected)
		-- An attacker KO'd while the contact waited is not stood back up into recoil. One that started a newer
		-- action meanwhile is recoiled out of it: as of t_c the deflect came first, so that action could not start.
		if (attacker.State :: State) ~= "KO" and not Rules.addPosture(attacker, reflected, now, events, defender.Id) then
			clearMove(attacker)
			enter(attacker, "Blockstun", now, Settings.Stun.DeflectRecoil)
		end
		return "Deflected"
	end

	-- Guard (held block, blockstun, or a mistimed deflect), as of the contact instant.
	local guarding = hit.Facing and (defenderState == "Blocking" or defenderState == "Blockstun" or defenderState == "Deflecting")
	local guardShattered = false
	if guarding and not move.Unblockable then
		local outcome = Weapons.blockOutcome(move, attackerWeapon, defenderWeapon, defender.Stamina)
		local cost = if defenderState == "Deflecting" then Settings.Stamina.Costs.DeflectMiss else outcome.DefenderStamina
		local depleted = Rules.spendStamina(defender, cost, now)
		local pierce = move.BaseDamage * snap.DamageScale * snap.GuardPierce
  local chip = Rules.applyDamage(defender, outcome.DefenderChip+pierce, "Chip", now, snap.DefenderProtection)
		Rules.rally(attacker, chip, now, events, defender.Id)
		attacker.Qi = math.min(attacker.MaxQi, attacker.Qi + Settings.Qi.GainOnHit * 0.5)
		if defender.ActiveHP <= 0 then
			clearMove(defender)
			enter(defender, "KO", now)
			emit(defender, events, "KO", attacker.Id, defender.Id, chip)
			return "KO"
		end
		if Rules.addPosture(defender, outcome.DefenderPosture + snap.InfusionStun, now, events, attacker.Id) then
			return "Blocked"
		end
		if depleted or outcome.GuardBreak then
			clearMove(defender)
			defender.Stamina = math.max(defender.Stamina, 0)
			enter(defender, "GuardBroken", now, Settings.Stun.GuardBroken)
			emit(defender, events, "GuardBreak", attacker.Id, defender.Id, outcome.DefenderPosture)
			return "GuardBroken"
		end
		clearMove(defender) -- a move begun after a guarded t_c is overridden by the blockstun
		enter(defender, "Blockstun", now, Settings.Stun.Blockstun)
		emit(defender, events, "Block", attacker.Id, defender.Id, chip)
		return "Blocked"
	elseif guarding and move.Unblockable then
		-- Perilous strike through a guard: shatter it, then resolve as a clean hit.
		local outcome = Weapons.blockOutcome(move, attackerWeapon, defenderWeapon, defender.Stamina)
		Rules.spendStamina(defender, outcome.DefenderStamina, now)
		Rules.addPosture(defender, outcome.DefenderPosture, now, events, attacker.Id)
		guardShattered = true
		emit(defender, events, "GuardBreak", attacker.Id, defender.Id, outcome.DefenderPosture)
	end

	-- 5a. Counter-hit: struck during Startup cancels the move for bonus damage.
	local defenderMove = snap.DefenderMove
	local poise = Settings.Poise
	local poiseThreshold = if move.Kind == "Light" then poise.LightThreshold else poise.HeavyThreshold
	local armored = (defenderMove ~= nil and defenderMove.HyperArmor and (defenderState == "Startup" or defenderState == "Active"))
		or snap.DefenderPoise >= poiseThreshold
	local counter = defenderState == "Startup" and not armored
	local counterScale = Settings.Counter
	local critical = if hit.Facing then 1 else (attackerWeapon.CriticalMultiplier or 1.5)
	local damage = critical * Schema.damage(move.BaseDamage, snap.ArmTier) * snap.DamageScale * (if counter then counterScale.HitMultiplier else 1)
	local category: DamageCategory = move.Kind
	local dealt = Rules.applyDamage(defender, damage, category, now, snap.DefenderProtection)
	if dealt > 0 and snap.InfusionBurn > 0 then
		defender.BurnRate, defender.BurnUntil, defender.BurnSource = snap.InfusionBurn, now + 4, attacker.Id
	end
	Rules.rally(attacker, dealt, now, events, defender.Id)
	attacker.Qi = math.min(attacker.MaxQi, attacker.Qi + Settings.Qi.GainOnHit)
	attacker.DashChain = 0

	-- Bleed accumulation and proc.
	local bleed = Weapons.bleedBuildup(move, attackerWeapon)
	if bleed > 0 then
		defender.Bleed += bleed
		defender.BleedDecayAt = now + Settings.Bleed.DecayDelay
		if defender.Bleed >= Settings.Bleed.Max then
			local burst = Rules.applyDamage(defender, Rules.effectiveMaxHP(defender) * Settings.Bleed.ProcDamageFraction, "Bleed", now)
			dealt += burst
			if Settings.Bleed.ResetOnProc then
				defender.Bleed = 0
			else
				defender.Bleed = Settings.Bleed.Max
			end
			emit(defender, events, "BleedProc", attacker.Id, defender.Id, burst)
		end
	end

	addTrauma(defender, hit.Region, Rules.traumaFor(move, hit.Region), now, events, attacker.Id)

	local kind: EventKind = if counter then "CounterHit" elseif armored then "Armored" else "Hit"
	emit(defender, events, kind, attacker.Id, defender.Id, dealt, hit.Region)

	if defender.ActiveHP <= 0 then
		clearMove(defender)
		enter(defender, "KO", now)
		emit(defender, events, "KO", attacker.Id, defender.Id, dealt)
		return "KO"
	end

	if defender.State == "StanceBroken" then
		-- Already broken (guard shattered into a full posture bar): keep the Deathblow opening.
		return if counter then "CounterHit" else "Hit"
	end

	local posture = snap.InfusionStun + Weapons.postureDamage(move, attackerWeapon) * Settings.Posture.HitScale * (if counter then counterScale.PostureMultiplier else 1)
		* (1 - snap.DefenderPoise * poise.PostureReduction)
	posture += hit.PostureBonus or 0
	if Rules.addPosture(defender, posture, now, events, attacker.Id) then
		return if counter then "CounterHit" else "Hit"
	end

	if guardShattered then
		clearMove(defender)
		enter(defender, "GuardBroken", now, Settings.Stun.GuardBroken)
		return "GuardBroken"
	end
	if armored then
		return "Armored"
	end
	clearMove(defender)
	defender.Sprinting = false
	enter(defender, "Hitstun", now, hitstunFor(move) + (if snap.InfusionStun > 0 then 0.15 else 0))
	return if counter then "CounterHit" else "Hit"
end

-- Environmental or scripted damage (falls, hazards) through the same layered health.
function Rules.applyExternalDamage(f: Fighter, amount: number, now: number, events: { Event }?): number
	local dealt = Rules.applyDamage(f, amount, "Heavy", now)
	if f.ActiveHP <= 0 and f.State ~= "KO" then
		clearMove(f)
		enter(f, "KO", now)
		emit(f, events, "KO", 0, f.Id, dealt)
	end
	return dealt
end

function Rules.knockOut(f: Fighter, now: number, events: { Event }?)
	if f.State == "KO" then
		return
	end
	f.ActiveHP = 0
	clearMove(f)
	enter(f, "KO", now)
	emit(f, events, "KO", 0, f.Id, 0)
end

-------------------------------------------------------------------------------------------------
-- Replication codec: fixed 58-byte little-endian record, base64-wrapped for string attributes.
-------------------------------------------------------------------------------------------------

export type Snapshot = {
	State: State,
	Weapon: WeaponType,
	Move: string?,
	ComboIndex: number,
	ActiveHP: number,
	RecoverableHP: number,
	PermanentDeficit: number,
	Stamina: number,
	Posture: number,
	Qi: number,
	Bleed: number,
	Injuries: { [InjuryRegion]: InjuryTier },
	StateElapsed: number,
	StateDuration: number,
	Blocking: boolean,
	Sprinting: boolean,
	Invulnerable: boolean,
	Armored: boolean,
	RallyActive: boolean,
	DeathblowLocked: boolean,
	DashSeq: number,
	ActionSeq: number,
	DashDistance: number,
	DashDuration: number,
	DashDirX: number,
	DashDirZ: number,
	RallyRemaining: number,
	EventSeq: number,
	LastEvent: EventKind?,
	DeathblowPartner: number,
	MaxHP: number,
	MaxStamina: number,
	PostureCapacity: number,
	PoiseArmor: number,
	KOProtected: boolean,
	SampleTick: number,
	SampleStamp: number,
	IntentSeq: number,
}

-- v4 (combat recovery Stage 2, TIMING_CONTRACT §4): byte 39 carries ActionSeq, a wrapping id that changes
-- whenever a new action starts (a move, or entry to a non-move state), so a repeated identical move and a
-- skipped update are distinguishable. Bytes 58-61 carry the server tick of the sample and 62-69 its server
-- clock (Workspace:GetServerTimeNow at sampling) so a client can age StateElapsed across transit.
-- v5 (Stage 2 closure): bytes 70-73 carry the client intent that started the current action (0 = none).
Rules.PACKET_SIZE = 74
Rules.PACKET_VERSION = 5
local HP_SCALE = 40

local STATE_INDEX: { [string]: number } = {}
for index, name in Schema.StateList do
	STATE_INDEX[name] = index
end
local WEAPON_INDEX: { [string]: number } = {}
for index, name in Weapons.WireKeys do -- player registry, then boss-only arms (IronBullMaul)
	WEAPON_INDEX[name] = index
end
local MOVE_LIST: { string } = {}
for _, weapon in Weapons.Weapons do
	for id in weapon.Moves do
		table.insert(MOVE_LIST, id)
	end
end
table.sort(MOVE_LIST)
local MOVE_INDEX: { [string]: number } = {}
for index, id in MOVE_LIST do
	MOVE_INDEX[id] = index
end
local TIER_LIST: { InjuryTier } = { "None", "Impaired", "Injured", "Severe" }

local function u16(value: number, scale: number): number
	return math.clamp(math.floor(value * scale + 0.5), 0, 65535)
end

local function i16(value: number, scale: number): number
	return math.clamp(math.floor(value * scale + 0.5), -32768, 32767)
end

-- The identity of the action a fighter is in: a move is one action from Startup through Recovery; any other
-- state is one action per entry. Bumps the fighter's wrapping ActionSeq when that identity changes.
local function actionSeq(f: Fighter): number
	local mark = if f.Move then f.MoveStart else f.StateStart
	local state = if f.Move then "Move" else f.State
	if mark ~= f.ActionMark or state ~= f.ActionState then
		f.ActionMark, f.ActionState = mark, state
		f.ActionSeq = (f.ActionSeq + 1) % 256
	end
	return f.ActionSeq
end
Rules.actionSeq = actionSeq

-- Records that client intent `seq` started the fighter's current action (CharacterService, after a buffered
-- intent executes), so a snapshot of exactly that action names it and a prediction is confirmed by its own
-- intent rather than by any action change (combat recovery Stage 2 closure).
function Rules.markIntent(f: Fighter, seq: number)
	f.IntentSeq = seq
	f.IntentMark = if f.Move then f.MoveStart else f.StateStart
	f.IntentState = if f.Move then "Move" else f.State
end

-- The intent that started the current action, or 0 once the fighter is in any other action.
function Rules.actionIntent(f: Fighter): number
	local mark = if f.Move then f.MoveStart else f.StateStart
	local state = if f.Move then "Move" else f.State
	return if mark == f.IntentMark and state == f.IntentState then f.IntentSeq else 0
end

-- `tick` and `stamp` name the sample (server tick, server clock); both default to 0 for offline packing.
function Rules.pack(f: Fighter, now: number, into: buffer?, tick: number?, stamp: number?): buffer
	local b = into or buffer.create(Rules.PACKET_SIZE)
	local move = f.Move
	buffer.writeu8(b, 0, Rules.PACKET_VERSION)
	buffer.writeu8(b, 1, STATE_INDEX[f.State])
	buffer.writeu8(b, 2, WEAPON_INDEX[f.Weapon])
	buffer.writeu8(b, 3, if move then move.ComboIndex else 0)
	buffer.writeu16(b, 4, if move then MOVE_INDEX[move.Id] or 0 else 0)
	buffer.writeu16(b, 6, u16(math.max(f.ActiveHP, 0), HP_SCALE))
	buffer.writeu16(b, 8, u16(f.RecoverableHP, HP_SCALE))
	buffer.writeu16(b, 10, u16(f.PermanentDeficit, HP_SCALE))
	buffer.writeu16(b, 12, u16(math.max(f.Stamina, 0), 100))
	buffer.writeu16(b, 14, u16(f.Posture, 100))
	buffer.writeu16(b, 16, u16(f.Qi, 100))
	buffer.writeu16(b, 18, u16(f.Bleed, 100))
	local injuries = 0
	for index, region in REGIONS do
		injuries += (Schema.tierIndex(f.Injuries[region]) :: number) * 4 ^ (index - 1)
	end
	buffer.writeu16(b, 20, injuries)
	buffer.writeu16(b, 22, u16(math.max(now - f.StateStart, 0), 1000))
	buffer.writeu16(b, 24, if f.StateEnd == NEVER then 0 else u16(math.max(f.StateEnd - f.StateStart, 0), 1000))
	local flags = 0
	if f.State == "Blocking" or f.GuardHeld then
		flags += 1
	end
	if f.Sprinting then
		flags += 2
	end
	if Rules.isInvulnerable(f, now) then
		flags += 4
	end
	if move ~= nil and move.HyperArmor and (f.State == "Startup" or f.State == "Active") then
		flags += 8
	end
	if now <= f.RallyUntil and f.RecoverableHP > 0 then
		flags += 16
	end
	if f.State == "DeathblowAttacker" or f.State == "DeathblowVictim" then
		flags += 32
	end
	buffer.writeu8(b, 26, flags)
	buffer.writeu8(b, 27, f.DashSeq)
	buffer.writeu16(b, 28, u16(f.DashDistance, 100))
	buffer.writei16(b, 30, i16(f.DashDirX, 10000))
	buffer.writei16(b, 32, i16(f.DashDirZ, 10000))
	buffer.writeu16(b, 34, u16(math.max(f.RallyUntil - now, 0), 1000))
	buffer.writeu16(b, 36, f.EventSeq)
	buffer.writeu8(b, 38, f.LastEvent)
	buffer.writeu8(b, 39, actionSeq(f))
	buffer.writeu16(b, 40, u16(f.DashDuration, 1000))
	buffer.writef64(b, 42, f.DeathblowPartner)
	buffer.writeu16(b, 50, u16(f.MaxHP, HP_SCALE))
	buffer.writeu16(b, 52, u16(f.MaxStamina, 100))
	buffer.writeu16(b, 54, u16(f.PostureCapacity, 100))
	buffer.writeu8(b, 56, math.clamp(math.floor(f.PoiseArmor * 255 + 0.5), 0, 255))
	buffer.writeu8(b, 57, if f.KOProtected then 1 else 0)
	buffer.writeu32(b, 58, (tick or 0) % 4294967296)
	buffer.writef64(b, 62, stamp or 0)
	buffer.writeu32(b, 70, Rules.actionIntent(f) % 4294967296)
	return b
end

function Rules.unpack(b: buffer): Snapshot?
	if buffer.len(b) < Rules.PACKET_SIZE or buffer.readu8(b, 0) ~= Rules.PACKET_VERSION then
		return nil
	end
	local state = Schema.StateList[buffer.readu8(b, 1)]
	local weapon = Weapons.WireKeys[buffer.readu8(b, 2)]
	if state == nil or weapon == nil then
		return nil
	end
	local moveIndex = buffer.readu16(b, 4)
	local packed = buffer.readu16(b, 20)
	local injuries: { [InjuryRegion]: InjuryTier } = {}
	for index, region in REGIONS do
		injuries[region] = TIER_LIST[(packed // 4 ^ (index - 1)) % 4 + 1]
	end
	local flags = buffer.readu8(b, 26)
	local function flag(bit: number): boolean
		return (flags // bit) % 2 == 1
	end
	local duration = buffer.readu16(b, 24)
	local eventCode = buffer.readu8(b, 38)
	return {
		State = state,
		Weapon = weapon,
		Move = if moveIndex > 0 then MOVE_LIST[moveIndex] else nil,
		ComboIndex = buffer.readu8(b, 3),
		ActiveHP = buffer.readu16(b, 6) / HP_SCALE,
		RecoverableHP = buffer.readu16(b, 8) / HP_SCALE,
		PermanentDeficit = buffer.readu16(b, 10) / HP_SCALE,
		Stamina = buffer.readu16(b, 12) / 100,
		Posture = buffer.readu16(b, 14) / 100,
		Qi = buffer.readu16(b, 16) / 100,
		Bleed = buffer.readu16(b, 18) / 100,
		Injuries = injuries,
		StateElapsed = buffer.readu16(b, 22) / 1000,
		StateDuration = if duration == 0 then math.huge else duration / 1000,
		Blocking = flag(1),
		Sprinting = flag(2),
		Invulnerable = flag(4),
		Armored = flag(8),
		RallyActive = flag(16),
		DeathblowLocked = flag(32),
		DashSeq = buffer.readu8(b, 27),
		DashDistance = buffer.readu16(b, 28) / 100,
		DashDirX = buffer.readi16(b, 30) / 10000,
		DashDirZ = buffer.readi16(b, 32) / 10000,
		RallyRemaining = buffer.readu16(b, 34) / 1000,
		EventSeq = buffer.readu16(b, 36),
		LastEvent = EVENT_NAMES[eventCode],
		DashDuration = buffer.readu16(b, 40) / 1000,
		DeathblowPartner = buffer.readf64(b, 42),
		MaxHP = buffer.readu16(b, 50) / HP_SCALE,
		MaxStamina = buffer.readu16(b, 52) / 100,
		PostureCapacity = buffer.readu16(b, 54) / 100,
		PoiseArmor = buffer.readu8(b, 56) / 255,
		KOProtected = buffer.readu8(b, 57) == 1,
		ActionSeq = buffer.readu8(b, 39),
		SampleTick = buffer.readu32(b, 58),
		SampleStamp = buffer.readf64(b, 62),
		IntentSeq = buffer.readu32(b, 70),
	}
end

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENCODE: { number } = {}
local DECODE: { [number]: number } = {}
for index = 1, 64 do
	local byte = string.byte(ALPHABET, index)
	ENCODE[index - 1] = byte
	DECODE[byte] = index - 1
end
local PAD = string.byte("=")

-- Attributes cannot hold buffers; base64 keeps the packed record replication-safe as a string.
function Rules.encode(b: buffer): string
	local length = buffer.len(b)
	local out = buffer.create(((length + 2) // 3) * 4)
	local o = 0
	for i = 0, length - 1, 3 do
		local remain = length - i
		local b0 = buffer.readu8(b, i)
		local b1 = if remain > 1 then buffer.readu8(b, i + 1) else 0
		local b2 = if remain > 2 then buffer.readu8(b, i + 2) else 0
		local n = b0 * 65536 + b1 * 256 + b2
		buffer.writeu8(out, o, ENCODE[n // 262144])
		buffer.writeu8(out, o + 1, ENCODE[(n // 4096) % 64])
		buffer.writeu8(out, o + 2, if remain > 1 then ENCODE[(n // 64) % 64] else PAD)
		buffer.writeu8(out, o + 3, if remain > 2 then ENCODE[n % 64] else PAD)
		o += 4
	end
	return buffer.tostring(out)
end

function Rules.decode(text: string): buffer?
	local length = #text
	if length == 0 or length % 4 ~= 0 then
		return nil
	end
	local padding = (if string.byte(text, length) == PAD then 1 else 0) + (if string.byte(text, length - 1) == PAD then 1 else 0)
	local out = buffer.create(length // 4 * 3 - padding)
	local o = 0
	for i = 1, length, 4 do
		local values = 0
		for k = 0, 3 do
			local byte = string.byte(text, i + k)
			local value = if byte == PAD then 0 else DECODE[byte]
			if value == nil then
				return nil
			end
			values = values * 64 + value
		end
		local bytes = { values // 65536, (values // 256) % 256, values % 256 }
		for k = 1, 3 do
			if o < buffer.len(out) then
				buffer.writeu8(out, o, bytes[k])
				o += 1
			end
		end
	end
	return out
end

function Rules.packString(f: Fighter, now: number, scratch: buffer?, tick: number?, stamp: number?): string
	return Rules.encode(Rules.pack(f, now, scratch, tick, stamp))
end

function Rules.unpackString(text: string): Snapshot?
	local b = Rules.decode(text)
	if b == nil then
		return nil
	end
	return Rules.unpack(b)
end

return table.freeze(Rules)

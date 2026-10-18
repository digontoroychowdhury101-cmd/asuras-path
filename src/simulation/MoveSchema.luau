--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Simulation/MoveSchema
-- Pure combat state enumeration, transition graph, action eligibility and injury penalties.
local hasScript = pcall(function()
	return script.Parent
end)
local Settings: any
if hasScript then
	Settings = require(script.Parent.Parent.Shared.CombatSettings)
else
	Settings = require("../shared/CombatSettings")
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

export type Action =
	"Move"
	| "Sprint"
	| "Light"
	| "Heavy"
	| "RunningAttack"
	| "WeaponArt"
	| "Roll"
	| "Dash"
	| "Deflect"
	| "Block"
	| "Deathblow"
	| "Heal"
	| "Equip"
	| "RestAtShrine"

export type InjuryTier = "None" | "Impaired" | "Injured" | "Severe"
export type InjuryRegion = "Head" | "Torso" | "LeftArm" | "RightArm" | "LeftLeg" | "RightLeg"
export type InjuryGroup = "Head" | "Torso" | "Arm" | "Leg"

export type Context = {
	ComboWindowOpen: boolean?,
	CancelWindowOpen: boolean?,
	Sprinting: boolean?,
	DeflectReady: boolean?,
	TargetDeathblowable: boolean?,
	AtShrine: boolean?,
	HasHealCharge: boolean?,
	Qi: number?,
	QiCost: number?,
	ArmTier: InjuryTier?,
	StaminaCost: number?,
}

export type Injuries = { [InjuryRegion]: InjuryTier }

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

local Schema = {}

local STATE_LIST: { State } = {
	"Idle",
	"Startup",
	"Active",
	"Recovery",
	"Deflecting",
	"Blocking",
	"Blockstun",
	"Dashing",
	"Hitstun",
	"GuardBroken",
	"StaminaBroken",
	"StanceBroken",
	"DeathblowAttacker",
	"DeathblowVictim",
	"RestingAtShrine",
	"KO",
}

local ACTION_LIST: { Action } = {
	"Move",
	"Sprint",
	"Light",
	"Heavy",
	"RunningAttack",
	"WeaponArt",
	"Roll",
	"Dash",
	"Deflect",
	"Block",
	"Deathblow",
	"Heal",
	"Equip",
	"RestAtShrine",
}

local function enumerate<T>(list: { T }): { [T]: T }
	local result: { [T]: T } = {}
	for _, value in list do
		result[value] = value
	end
	return table.freeze(result)
end

local function set<T>(list: { T }): { [T]: boolean }
	local result: { [T]: boolean } = {}
	for _, value in list do
		result[value] = true
	end
	return table.freeze(result)
end

Schema.States = enumerate(STATE_LIST)
Schema.Actions = enumerate(ACTION_LIST)
Schema.StateList = table.freeze(table.clone(STATE_LIST))
Schema.ActionList = table.freeze(table.clone(ACTION_LIST))

-- Actions permitted unconditionally in each state.
local ALLOWED: { [State]: { [Action]: boolean } } = {
	Idle = set({ "Move", "Sprint", "Light", "Heavy", "RunningAttack", "WeaponArt", "Roll", "Dash", "Deflect", "Block", "Deathblow", "Heal", "Equip", "RestAtShrine" } :: { Action }),
	Startup = set({} :: { Action }),
	Active = set({} :: { Action }),
	Recovery = set({ "Deflect", "Block" } :: { Action }),
	Deflecting = set({ "Move", "Block", "Deflect", "Light", "Heavy", "Deathblow" } :: { Action }),
	Blocking = set({ "Move", "Block", "Deflect", "Light", "Heavy", "WeaponArt", "Roll", "Dash", "Deathblow" } :: { Action }),
	Blockstun = set({ "Deflect", "Block" } :: { Action }),
	Dashing = set({} :: { Action }),
	Hitstun = set({} :: { Action }),
	GuardBroken = set({} :: { Action }),
	StaminaBroken = set({} :: { Action }),
	StanceBroken = set({} :: { Action }),
	DeathblowAttacker = set({} :: { Action }),
	DeathblowVictim = set({} :: { Action }),
	RestingAtShrine = set({ "Equip", "RestAtShrine" } :: { Action }),
	KO = set({} :: { Action }),
}

-- Actions unlocked by a context window (combo chain or cancel frames).
local COMBO_UNLOCKS: { [State]: { [Action]: boolean } } = {
	Recovery = set({ "Light", "Heavy" } :: { Action }),
}

local CANCEL_UNLOCKS: { [State]: { [Action]: boolean } } = {
	Startup = set({ "Deflect", "Roll", "Dash" } :: { Action }),
	Recovery = set({ "Roll", "Dash", "WeaponArt" } :: { Action }),
	Dashing = set({ "Light", "Heavy", "RunningAttack", "Deflect", "Block" } :: { Action }),
}

local TRANSITIONS: { [State]: { [State]: boolean } } = {
	Idle = set({ "Startup", "Deflecting", "Blocking", "Dashing", "Hitstun", "GuardBroken", "StaminaBroken", "StanceBroken", "DeathblowAttacker", "RestingAtShrine", "KO" } :: { State }),
	Startup = set({ "Active", "Idle", "Deflecting", "Dashing", "Hitstun", "StaminaBroken", "StanceBroken", "KO" } :: { State }),
	Active = set({ "Recovery", "Blockstun", "Hitstun", "StaminaBroken", "StanceBroken", "KO" } :: { State }),
	Recovery = set({ "Idle", "Startup", "Deflecting", "Blocking", "Dashing", "Hitstun", "StaminaBroken", "StanceBroken", "KO" } :: { State }),
	Deflecting = set({ "Idle", "Deflecting", "Blocking", "Startup", "Blockstun", "Hitstun", "StaminaBroken", "StanceBroken", "DeathblowAttacker", "KO" } :: { State }),
	Blocking = set({ "Idle", "Deflecting", "Startup", "Dashing", "Blockstun", "GuardBroken", "Hitstun", "StaminaBroken", "StanceBroken", "DeathblowAttacker", "KO" } :: { State }),
	Blockstun = set({ "Idle", "Blocking", "Deflecting", "GuardBroken", "Hitstun", "StaminaBroken", "StanceBroken", "KO" } :: { State }),
	Dashing = set({ "Idle", "Startup", "Deflecting", "Blocking", "Hitstun", "StaminaBroken", "StanceBroken", "KO" } :: { State }),
	Hitstun = set({ "Idle", "Hitstun", "StaminaBroken", "StanceBroken", "KO" } :: { State }),
	GuardBroken = set({ "Idle", "Hitstun", "StanceBroken", "KO" } :: { State }),
	StaminaBroken = set({ "Idle", "Hitstun", "StanceBroken", "KO" } :: { State }),
	StanceBroken = set({ "Idle", "Hitstun", "DeathblowVictim", "KO" } :: { State }),
	DeathblowAttacker = set({ "Idle" } :: { State }),
	DeathblowVictim = set({ "Idle", "KO" } :: { State }),
	RestingAtShrine = set({ "Idle" } :: { State }),
	KO = set({ "Idle", "RestingAtShrine" } :: { State }),
}

local GUARDING = set({ "Deflecting", "Blocking", "Blockstun" } :: { State })
local STUNNED = set({ "Hitstun", "Blockstun", "GuardBroken", "StaminaBroken", "StanceBroken", "DeathblowVictim" } :: { State })
local ATTACKING = set({ "Startup", "Active", "Recovery" } :: { State })
local LOCKED = set({ "DeathblowAttacker", "DeathblowVictim", "RestingAtShrine", "KO" } :: { State })
local STATIC_INVULNERABLE = set({ "DeathblowAttacker", "DeathblowVictim", "RestingAtShrine", "KO" } :: { State })
local STAMINA_FREE = set({ "Move", "Equip", "RestAtShrine", "Deathblow", "Heal" } :: { Action })

Schema.Allowed = ALLOWED
Schema.Transitions = TRANSITIONS

-- Reasons returned alongside eligibility verdicts.
Schema.Reasons = table.freeze({
	Ok = "Ok",
	UnknownState = "UnknownState",
	UnknownAction = "UnknownAction",
	StateLocked = "StateLocked",
	NotInWindow = "NotInWindow",
	PostureBroken = "PostureBroken",
	InsufficientStamina = "InsufficientStamina",
	RequiresSprint = "RequiresSprint",
	DeflectCooldown = "DeflectCooldown",
	NoDeathblowTarget = "NoDeathblowTarget",
	NotAtShrine = "NotAtShrine",
	NoHealCharge = "NoHealCharge",
	InsufficientQi = "InsufficientQi",
})

local function tierT(tier: InjuryTier): number?
	if tier == "Impaired" then
		return 0
	elseif tier == "Injured" then
		return 0.5
	elseif tier == "Severe" then
		return 1
	end
	return nil
end

-- Interpolates a {Min, Max} penalty range across Impaired..Severe; None yields zero.
function Schema.penalty(range: { Min: number, Max: number }, tier: InjuryTier): number
	local t = tierT(tier)
	if t == nil then
		return 0
	end
	return range.Min + (range.Max - range.Min) * t
end

local function worse(a: InjuryTier, b: InjuryTier): InjuryTier
	local index = Settings.Injury.TierIndex
	return if index[a] >= index[b] then a else b
end

function Schema.tierIndex(tier: InjuryTier): number
	return Settings.Injury.TierIndex[tier]
end

function Schema.tierFromCoefficient(region: InjuryRegion, coefficient: number): InjuryTier
	local group: InjuryGroup = Settings.Injury.Group[region]
	assert(group ~= nil, "Unknown injury region")
	local thresholds = Settings.Injury.Thresholds[group]
	if coefficient >= thresholds.Severe then
		return "Severe"
	elseif coefficient >= thresholds.Injured then
		return "Injured"
	elseif coefficient >= thresholds.Impaired then
		return "Impaired"
	end
	return "None"
end

-- Lowest coefficient natural recovery may reach once a region has crossed the persistent tier.
function Schema.recoveryFloor(region: InjuryRegion, coefficient: number): number
	local group: InjuryGroup = Settings.Injury.Group[region]
	local tier = Schema.tierFromCoefficient(region, coefficient)
	local persistent: InjuryTier = Settings.Injury.PersistentTier
	if Schema.tierIndex(tier) < Schema.tierIndex(persistent) or persistent == "None" then
		return 0
	end
	return Settings.Injury.Thresholds[group][persistent :: any]
end

function Schema.armStaminaMultiplier(tier: InjuryTier): number
	return 1 + Schema.penalty(Settings.Injury.Penalties.Arm.StaminaCostIncrease, tier)
end

function Schema.armDamageMultiplier(tier: InjuryTier): number
	return 1 - Schema.penalty(Settings.Injury.Penalties.Arm.DamageReduction, tier)
end

function Schema.legSpeedMultiplier(tier: InjuryTier): number
	return 1 - Schema.penalty(Settings.Injury.Penalties.Leg.SpeedReduction, tier)
end

function Schema.legDashMultiplier(tier: InjuryTier): number
	return 1 - Schema.penalty(Settings.Injury.Penalties.Leg.DashDistanceReduction, tier)
end

function Schema.headDeflectWindow(tier: InjuryTier): number
	local window = Settings.Posture.DeflectWindow * (1 - Schema.penalty(Settings.Injury.Penalties.Head.DeflectWindowReduction, tier))
	return math.max(window, Settings.Posture.DeflectWindowMin)
end

-- Effective arm tier for an attack: two-handed grips suffer the worse arm, one-handed the weapon arm.
function Schema.attackArmTier(injuries: Injuries, twoHanded: boolean, mainHand: "Left" | "Right"?): InjuryTier
	local left = injuries.LeftArm or "None"
	local right = injuries.RightArm or "None"
	if twoHanded then
		return worse(left, right)
	end
	return if mainHand == "Left" then left else right
end

function Schema.penalties(injuries: Injuries, twoHanded: boolean?, mainHand: "Left" | "Right"?): Penalties
	local p = Settings.Injury.Penalties
	local arm = Schema.attackArmTier(injuries, twoHanded == true, mainHand)
	local leg = worse(injuries.LeftLeg or "None", injuries.RightLeg or "None")
	local head = injuries.Head or "None"
	local torso = injuries.Torso or "None"
	return {
		StaminaCostMultiplier = Schema.armStaminaMultiplier(arm),
		DamageMultiplier = Schema.armDamageMultiplier(arm),
		SpeedMultiplier = Schema.legSpeedMultiplier(leg),
		DashDistanceMultiplier = Schema.legDashMultiplier(leg),
		DeflectWindowMultiplier = Schema.headDeflectWindow(head) / Settings.Posture.DeflectWindow,
		PostureDecayMultiplier = 1 - Schema.penalty(p.Head.PostureDecayReduction, head),
		StaminaRegenMultiplier = 1 - Schema.penalty(p.Torso.StaminaRegenReduction, torso),
		MaxPostureMultiplier = 1 - Schema.penalty(p.Torso.MaxPostureReduction, torso),
		VisionBlur = Schema.penalty(p.Head.VisionBlur, head),
		EyeVignette = Schema.penalty(p.Head.EyeVignette, head),
	}
end

function Schema.baseStaminaCost(action: Action): number
	local costs = Settings.Stamina.Costs
	if action == "Light" then
		return costs.Light
	elseif action == "Heavy" then
		return costs.Heavy
	elseif action == "Roll" then
		return costs.Roll
	elseif action == "Dash" then
		return costs.Dash
	elseif action == "RunningAttack" then
		return costs.RunningAttack
	elseif action == "WeaponArt" then
		return costs.WeaponArt
	elseif action == "Deflect" then
		return costs.DeflectSuccess
	elseif action == "Block" then
		return 0
	end
	return 0
end

local function isAttack(action: Action): boolean
	return action == "Light" or action == "Heavy" or action == "RunningAttack" or action == "WeaponArt"
end

-- Final stamina cost, applying arm trauma to offensive actions only.
function Schema.staminaCost(action: Action, armTier: InjuryTier?, override: number?): number
	local base = override or Schema.baseStaminaCost(action)
	if isAttack(action) then
		return base * Schema.armStaminaMultiplier(armTier or "None")
	end
	return base
end

function Schema.damage(baseDamage: number, armTier: InjuryTier?): number
	return baseDamage * Schema.armDamageMultiplier(armTier or "None")
end

-- Real-time duration of timed lockout states; nil means the state is driven by move frames or input.
function Schema.stateDuration(state: State): number?
	local stun = Settings.Stun
	if state == "StaminaBroken" then
		return stun.StaminaBroken
	elseif state == "GuardBroken" then
		return stun.GuardBroken
	elseif state == "StanceBroken" then
		return stun.StanceBroken
	elseif state == "Blockstun" then
		return stun.Blockstun
	elseif state == "DeathblowAttacker" then
		return stun.DeathblowAttacker
	elseif state == "DeathblowVictim" then
		return stun.DeathblowVictim
	elseif state == "Deflecting" then
		return Settings.Posture.DeflectWindow + Settings.Posture.DeflectRecovery
	elseif state == "RestingAtShrine" then
		return Settings.Health.Shrine.RestDuration
	end
	return nil
end

function Schema.isValidState(state: any): boolean
	return type(state) == "string" and ALLOWED[state :: State] ~= nil
end

function Schema.isValidAction(action: any): boolean
	return type(action) == "string" and (Schema.Actions :: any)[action] ~= nil
end

function Schema.canTransition(from: State, to: State): boolean
	local edges = TRANSITIONS[from]
	return edges ~= nil and edges[to] == true
end

function Schema.isGuarding(state: State): boolean
	return GUARDING[state] == true
end

function Schema.isStunned(state: State): boolean
	return STUNNED[state] == true
end

function Schema.isAttacking(state: State): boolean
	return ATTACKING[state] == true
end

function Schema.isLocked(state: State): boolean
	return LOCKED[state] == true
end

function Schema.isDeathblowVulnerable(state: State): boolean
	return state == "StanceBroken"
end

-- Invulnerability independent of i-frame windows (rolls/dashes resolve those from Movement timings).
function Schema.isInvulnerable(state: State): boolean
	return STATIC_INVULNERABLE[state] == true
end

function Schema.canTakeHits(state: State): boolean
	return not Schema.isInvulnerable(state)
end

function Schema.postureDecayMultiplier(state: State): number
	if Schema.isStunned(state) and state ~= "Blockstun" then
		return 0
	end
	if Schema.isGuarding(state) then
		return Settings.Posture.GuardingDecayMultiplier
	end
	return 1
end

function Schema.canAct(state: State, action: Action, stamina: number, posture: number, context: Context?): (boolean, string)
	local reasons = Schema.Reasons
	local allowed = ALLOWED[state]
	if allowed == nil then
		return false, reasons.UnknownState
	end
	if not Schema.isValidAction(action) then
		return false, reasons.UnknownAction
	end
	if Schema.isLocked(state) and not allowed[action] then
		return false, reasons.StateLocked
	end

	local ctx: Context = context or {}
	local permitted = allowed[action] == true
	if not permitted and ctx.ComboWindowOpen then
		local combo = COMBO_UNLOCKS[state]
		permitted = combo ~= nil and combo[action] == true
	end
	if not permitted and ctx.CancelWindowOpen then
		local cancel = CANCEL_UNLOCKS[state]
		permitted = cancel ~= nil and cancel[action] == true
	end
	if not permitted then
		return false, if Schema.isStunned(state) or Schema.isLocked(state) then reasons.StateLocked else reasons.NotInWindow
	end

	if posture >= Settings.Posture.StanceBreakThreshold and action ~= "Move" and action ~= "Equip" then
		return false, reasons.PostureBroken
	end

	if action == "RunningAttack" and not ctx.Sprinting and state ~= "Dashing" then
		return false, reasons.RequiresSprint
	end
	if action == "Deathblow" and not ctx.TargetDeathblowable then
		return false, reasons.NoDeathblowTarget
	end
	if action == "RestAtShrine" and state ~= "RestingAtShrine" and not ctx.AtShrine then
		return false, reasons.NotAtShrine
	end
	if action == "Heal" and ctx.HasHealCharge == false then
		return false, reasons.NoHealCharge
	end
	if action == "Deflect" and ctx.DeflectReady == false then
		return false, reasons.DeflectCooldown
	end
	if action == "WeaponArt" and ctx.QiCost ~= nil and (ctx.Qi or 0) < ctx.QiCost then
		return false, reasons.InsufficientQi
	end

	if not STAMINA_FREE[action] then
		local floor = Settings.Stamina.BreakThreshold
		if action == "Deflect" or action == "Block" then
			-- Guarding is attempted on any positive stamina; a missed deflect may overdraw into StaminaBroken.
			if stamina <= floor then
				return false, reasons.InsufficientStamina
			end
		elseif action == "Sprint" then
			if stamina < Settings.Stamina.SprintMinimum then
				return false, reasons.InsufficientStamina
			end
		else
			local cost = Schema.staminaCost(action, ctx.ArmTier, ctx.StaminaCost)
			if stamina <= floor or stamina < cost then
				return false, reasons.InsufficientStamina
			end
		end
	end

	return true, reasons.Ok
end

-- Validates the static tables at load so a malformed edit fails immediately.
do
	for _, state in STATE_LIST do
		assert(ALLOWED[state] ~= nil, "Missing action row for state " .. state)
		assert(TRANSITIONS[state] ~= nil, "Missing transition row for state " .. state)
		for target in TRANSITIONS[state] do
			assert(ALLOWED[target] ~= nil, "Transition to unknown state " .. tostring(target))
		end
	end
	for _, rows in { ALLOWED, COMBO_UNLOCKS, CANCEL_UNLOCKS } do
		for state, row in rows do
			assert(ALLOWED[state] ~= nil, "Unknown state " .. tostring(state))
			for action in row do
				assert((Schema.Actions :: any)[action] ~= nil, "Unknown action " .. tostring(action))
			end
		end
	end
	for _, region in Settings.Injury.Regions do
		local thresholds = Settings.Injury.Thresholds[Settings.Injury.Group[region]]
		assert(thresholds.Impaired < thresholds.Injured and thresholds.Injured < thresholds.Severe and thresholds.Severe <= 1, "Injury thresholds must ascend for " .. region)
	end
end

table.freeze(ALLOWED)
table.freeze(COMBO_UNLOCKS)
table.freeze(CANCEL_UNLOCKS)
table.freeze(TRANSITIONS)

return table.freeze(Schema)

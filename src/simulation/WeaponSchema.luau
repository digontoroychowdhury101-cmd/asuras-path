--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Simulation/WeaponSchema
-- Weapon contracts and move trees. Frame data is authored at the 60 Hz baseline and resolved
-- through Tempo (1.4x) with reactable telegraph floors enforced at load.
local hasScript = pcall(function()
	return script.Parent
end)
local Settings: any, Tempo: any, Expansion: any
if hasScript then
	local simFolder = script.Parent :: Instance
	local asuraFolder = simFolder.Parent
	local sharedFolder = if asuraFolder then asuraFolder:WaitForChild("Shared") else nil
	Settings = if sharedFolder then require(sharedFolder:WaitForChild("CombatSettings") :: ModuleScript) else require(script.Parent.Parent.Shared.CombatSettings)
	Tempo = require(simFolder:WaitForChild("Tempo") :: ModuleScript)
	Expansion = require(simFolder:WaitForChild("WeaponExpansion") :: ModuleScript)
else
	Settings = require("../shared/CombatSettings")
	Tempo = require("./Tempo")
	Expansion = require("./WeaponExpansion")
end

export type WeaponType = "Unarmed" | "Jian" | "Dao" | "Guandao" | "Odachi" | "TwinDaggers" | "ChainScythe" | "WarFan" | "Catalyst" | "PrayerOfTheDefiled" | "CalamityBoneCleaver" | "HeavenPiercingGuandao" | "IronBullMaul"
export type Grip = "Fist" | "OneHanded" | "TwoHanded"
export type MoveKind = "Light" | "Heavy" | "RunningAttack" | "WeaponArt"
export type DamageType = "Blunt" | "Slash" | "Pierce"

export type Trauma = { Head: number, Torso: number, Arms: number, Legs: number }

export type Timing = {
	StartupFrames: number,
	ActiveFrames: number,
	RecoveryFrames: number,
	ComboWindowFrames: number,
	CancelFrame: number,
	TotalFrames: number,
	StartupSeconds: number,
	ActiveSeconds: number,
	RecoverySeconds: number,
	ComboWindowSeconds: number,
	TotalSeconds: number,
	Reactable: boolean,
}

export type MoveSpec = {
	Id: string,
	Name: string,
	Kind: MoveKind,
	ComboIndex: number,
	Startup: number,
	Active: number,
	Recovery: number,
	ComboWindow: number,
	CancelFrom: number,
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
	DamageType: DamageType,
	Trauma: Trauma,
	Animation: string,
	Effect: string?,
}

export type Move = MoveSpec & { Timing: Timing }

export type WeaponSpec = {
	Stance: string?, WeightClass: string?, CriticalMultiplier: number?, SpellPotency: number?, QuickCast: boolean?, ProjectileParry: boolean?, PostureReflect: number?,
	Id: string,
	Type: WeaponType,
	Name: string,
	Grip: Grip,
	Reach: number,
	Weight: number,
	DeflectEfficiency: number,
	GuardChip: number,
	BleedMultiplier: number,
	PostureMultiplier: number,
	BlockPostureResistance: number,
	MoveSpeedMultiplier: number,
	Light: { MoveSpec },
	Heavy: MoveSpec,
	RunningAttack: MoveSpec,
	WeaponArt: MoveSpec,
}

export type Weapon = {
	Stance: string?, WeightClass: string?, CriticalMultiplier: number?, SpellPotency: number?, QuickCast: boolean?, ProjectileParry: boolean?, PostureReflect: number?,
	Id: string,
	Type: WeaponType,
	Name: string,
	Grip: Grip,
	Reach: number,
	Weight: number,
	DeflectEfficiency: number,
	GuardChip: number,
	BleedMultiplier: number,
	PostureMultiplier: number,
	BlockPostureResistance: number,
	MoveSpeedMultiplier: number,
	Light: { Move },
	Heavy: Move,
	RunningAttack: Move,
	WeaponArt: Move,
	Moves: { [string]: Move },
}

export type DeflectOutcome = { AttackerPosture: number, DefenderPosture: number, DefenderStamina: number }
export type BlockOutcome = { DefenderPosture: number, DefenderChip: number, DefenderStamina: number, GuardBreak: boolean }

local Schema = {}

Schema.WeaponTypes = table.freeze({ "Unarmed", "Jian", "Dao", "Guandao", "Odachi", "TwinDaggers", "ChainScythe", "WarFan", "Catalyst" } :: { WeaponType })
Schema.MoveKinds = table.freeze({ "Light", "Heavy", "RunningAttack", "WeaponArt" } :: { MoveKind })

local function trauma(head: number, torso: number, arms: number, legs: number): Trauma
	return { Head = head, Torso = torso, Arms = arms, Legs = legs }
end

local function check(condition: boolean, message: string)
	if not condition then
		error("WeaponSchema: " .. message, 3)
	end
end

local function inRange(value: number, low: number, high: number): boolean
	return value == value and value >= low and value <= high
end

function Schema.resolveTiming(spec: MoveSpec): Timing
	local startup = Tempo.enforceTelegraph(spec.Kind, Tempo.scaleFrames(spec.Startup))
	local active = Tempo.scaleFrames(spec.Active)
	local recovery = Tempo.scaleFrames(spec.Recovery)
	local combo = math.min(Tempo.scaleFrames(spec.ComboWindow), recovery)
	local cancel = startup + active + math.min(Tempo.scaleFrames(spec.CancelFrom), recovery)
	local total = startup + active + recovery
	local timing: Timing = {
		StartupFrames = startup,
		ActiveFrames = active,
		RecoveryFrames = recovery,
		ComboWindowFrames = combo,
		CancelFrame = cancel,
		TotalFrames = total,
		StartupSeconds = Tempo.framesToSeconds(startup),
		ActiveSeconds = Tempo.framesToSeconds(active),
		RecoverySeconds = Tempo.framesToSeconds(recovery),
		ComboWindowSeconds = Tempo.framesToSeconds(combo),
		TotalSeconds = Tempo.framesToSeconds(total),
		Reactable = Tempo.isReactable(spec.Kind, startup),
	}
	table.freeze(timing :: any)
	return timing
end

function Schema.validateMove(spec: MoveSpec, weaponId: string)
	local label = weaponId .. "." .. tostring(spec.Id)
	check(type(spec.Id) == "string" and #spec.Id > 0, label .. " requires Id")
	check(type(spec.Name) == "string" and #spec.Name > 0, label .. " requires Name")
	check(spec.Kind == "Light" or spec.Kind == "Heavy" or spec.Kind == "RunningAttack" or spec.Kind == "WeaponArt", label .. " unknown Kind")
	check(spec.DamageType == "Blunt" or spec.DamageType == "Slash" or spec.DamageType == "Pierce", label .. " unknown DamageType")
	for _, key in { "Startup", "Active", "Recovery" } do
		local value = (spec :: any)[key]
		check(type(value) == "number" and value % 1 == 0 and inRange(value, 1, 120), label .. " invalid " .. key)
	end
	check(spec.ComboWindow % 1 == 0 and inRange(spec.ComboWindow, 0, spec.Recovery), label .. " ComboWindow exceeds Recovery")
	check(spec.CancelFrom % 1 == 0 and inRange(spec.CancelFrom, 0, spec.Recovery), label .. " CancelFrom exceeds Recovery")
	check(inRange(spec.BaseDamage, 0, 60), label .. " invalid BaseDamage")
	check(inRange(spec.PostureDamage, 0, 80), label .. " invalid PostureDamage")
	check(inRange(spec.Bleed, 0, 1), label .. " Bleed must be 0..1")
	check(inRange(spec.DeflectVulnerability, 0, 1), label .. " DeflectVulnerability must be 0..1")
	check(type(spec.Deflectable) == "boolean" and type(spec.Unblockable) == "boolean" and type(spec.HyperArmor) == "boolean", label .. " flags must be boolean")
	check(spec.Deflectable or not spec.Unblockable, label .. " cannot be both undeflectable and unblockable")
	check(inRange(spec.QiCost, 0, Settings.Qi.Max), label .. " invalid QiCost")
	check(inRange(spec.Reach, 1, 16) and inRange(spec.Arc, 0, 360) and inRange(spec.Lunge, 0, 20), label .. " invalid spatial data")
	check(type(spec.Animation) == "string" and #spec.Animation > 0, label .. " requires Animation key")
	for _, part in { "Head", "Torso", "Arms", "Legs" } do
		check(inRange((spec.Trauma :: any)[part], 0, 0.5), label .. " invalid Trauma." .. part)
	end
	local stamina = Settings.Stamina
	if spec.Kind == "Light" then
		check(inRange(spec.StaminaCost, stamina.LightRange.Min, stamina.LightRange.Max), label .. " light stamina outside range")
		check(spec.ComboIndex >= 1, label .. " light requires ComboIndex")
		check(spec.QiCost == 0, label .. " light cannot cost Qi")
	elseif spec.Kind == "Heavy" then
		check(inRange(spec.StaminaCost, stamina.HeavyRange.Min, stamina.HeavyRange.Max), label .. " heavy stamina outside range")
		check(spec.ComboIndex == 0, label .. " heavy ComboIndex must be 0")
	elseif spec.Kind == "RunningAttack" then
		check(inRange(spec.StaminaCost, stamina.LightRange.Min, stamina.HeavyRange.Max), label .. " running stamina outside range")
		check(spec.ComboIndex == 0, label .. " running ComboIndex must be 0")
	else
		check(inRange(spec.StaminaCost, stamina.HeavyRange.Min, stamina.Costs.WeaponArt * 1.25), label .. " art stamina outside range")
		check(spec.QiCost > 0, label .. " weapon art requires QiCost")
		check(spec.ComboIndex == 0, label .. " art ComboIndex must be 0")
	end
	local timing = Schema.resolveTiming(spec)
	check(timing.Reactable, label .. " startup is below the reactable telegraph floor")
end

function Schema.validateWeapon(spec: WeaponSpec)
	local id = tostring(spec.Id)
	check(spec.CriticalMultiplier == nil or inRange(spec.CriticalMultiplier,1,4), id .. " invalid critical multiplier")
	check(spec.SpellPotency == nil or inRange(spec.SpellPotency,1,1.5), id .. " invalid spell potency")
	check(spec.PostureReflect == nil or inRange(spec.PostureReflect,0,0.25), id .. " invalid posture reflection")
	check(type(spec.Id) == "string" and #spec.Id > 0, "weapon requires Id")
	check(table.find(Schema.WeaponTypes, spec.Type) ~= nil, id .. " unknown Type")
	check(spec.Grip == "Fist" or spec.Grip == "OneHanded" or spec.Grip == "TwoHanded", id .. " unknown Grip")
	check(inRange(spec.Reach, 1, 16) and inRange(spec.Weight, 0, 10), id .. " invalid Reach/Weight")
	check(inRange(spec.DeflectEfficiency, 0.5, 2), id .. " invalid DeflectEfficiency")
	check(inRange(spec.GuardChip, 0, 0.5), id .. " invalid GuardChip")
	check(inRange(spec.BleedMultiplier, 0, 2) and inRange(spec.PostureMultiplier, 0.5, 2), id .. " invalid multipliers")
	check(inRange(spec.BlockPostureResistance, 0.5, 1.5), id .. " invalid BlockPostureResistance")
	check(inRange(spec.MoveSpeedMultiplier, 0.7, 1.1), id .. " invalid MoveSpeedMultiplier")
	check(#spec.Light >= 3 and #spec.Light <= 4, id .. " light string must be 3-4 hits")
	local seen: { [string]: boolean } = {}
	local function visit(move: MoveSpec, kind: MoveKind)
		check(move.Kind == kind, id .. "." .. move.Id .. " kind mismatch")
		check(not seen[move.Id], id .. " duplicate move id " .. move.Id)
		seen[move.Id] = true
		Schema.validateMove(move, id)
	end
	for index, move in spec.Light do
		check(move.ComboIndex == index, id .. " light ComboIndex out of order")
		visit(move, "Light")
	end
	check(spec.Light[#spec.Light].ComboWindow == 0, id .. " final light cannot chain")
	visit(spec.Heavy, "Heavy")
	visit(spec.RunningAttack, "RunningAttack")
	visit(spec.WeaponArt, "WeaponArt")
end

local function resolveMove(spec: MoveSpec): Move
	local move = table.clone(spec) :: any
	move.Trauma = table.freeze(table.clone(spec.Trauma))
	move.Timing = Schema.resolveTiming(spec)
	return table.freeze(move) :: Move
end

function Schema.build(spec: WeaponSpec): Weapon
	Schema.validateWeapon(spec)
	local light: { Move } = {}
	local moves: { [string]: Move } = {}
	for index, entry in spec.Light do
		local move = resolveMove(entry)
		light[index] = move
		moves[move.Id] = move
	end
	local heavy = resolveMove(spec.Heavy)
	local running = resolveMove(spec.RunningAttack)
	local art = resolveMove(spec.WeaponArt)
	moves[heavy.Id] = heavy
	moves[running.Id] = running
	moves[art.Id] = art
	table.freeze(light)
	table.freeze(moves)
	local weapon: Weapon = {
		Id = spec.Id,
		Type = spec.Type,
		Name = spec.Name,
		Grip = spec.Grip,
		Reach = spec.Reach,
		Weight = spec.Weight,
		DeflectEfficiency = spec.DeflectEfficiency,
		GuardChip = spec.GuardChip,
		BleedMultiplier = spec.BleedMultiplier,
		PostureMultiplier = spec.PostureMultiplier,
		BlockPostureResistance = spec.BlockPostureResistance,
		MoveSpeedMultiplier = spec.MoveSpeedMultiplier,
		Light = light,
		Heavy = heavy,
		RunningAttack = running,
		WeaponArt = art,
		Moves = moves,
		Stance = spec.Stance or "Balanced", WeightClass = spec.WeightClass or "Medium",
		CriticalMultiplier = spec.CriticalMultiplier or 1.5, SpellPotency = spec.SpellPotency or 1,
		QuickCast = spec.QuickCast or false, ProjectileParry = spec.ProjectileParry or false, PostureReflect = spec.PostureReflect or 0,
	}
	table.freeze(weapon :: any)
	return weapon
end

local UNARMED: WeaponSpec = {
	Id = "Unarmed",
	Type = "Unarmed",
	Name = "Iron Fist Discipline",
	Grip = "Fist",
	Reach = 4.5,
	Weight = 0,
	DeflectEfficiency = 0.9,
	GuardChip = 0.05,
	BleedMultiplier = 0.2,
	PostureMultiplier = 1.0,
	BlockPostureResistance = 1.15,
	MoveSpeedMultiplier = 1.05,
	Light = {
		{
			Id = "Unarmed_L1", Name = "Flicker Jab", Kind = "Light", ComboIndex = 1,
			Startup = 7, Active = 3, Recovery = 10, ComboWindow = 7, CancelFrom = 5,
			BaseDamage = 4, PostureDamage = 6, Bleed = 0, DeflectVulnerability = 0.55,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 3.0, QiCost = 0, Reach = 4.0, Arc = 20, Lunge = 1.0,
			DamageType = "Blunt", Trauma = trauma(0.03, 0.01, 0, 0), Animation = "Unarmed.FlickerJab",
		},
		{
			Id = "Unarmed_L2", Name = "Snapping Cross", Kind = "Light", ComboIndex = 2,
			Startup = 7, Active = 3, Recovery = 11, ComboWindow = 7, CancelFrom = 5,
			BaseDamage = 5, PostureDamage = 7, Bleed = 0, DeflectVulnerability = 0.55,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 3.0, QiCost = 0, Reach = 4.2, Arc = 20, Lunge = 1.2,
			DamageType = "Blunt", Trauma = trauma(0.04, 0.01, 0, 0), Animation = "Unarmed.SnappingCross",
		},
		{
			Id = "Unarmed_L3", Name = "Temple Hook", Kind = "Light", ComboIndex = 3,
			Startup = 8, Active = 3, Recovery = 13, ComboWindow = 8, CancelFrom = 6,
			BaseDamage = 6, PostureDamage = 9, Bleed = 0, DeflectVulnerability = 0.6,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 3.5, QiCost = 0, Reach = 4.0, Arc = 60, Lunge = 0.8,
			DamageType = "Blunt", Trauma = trauma(0.07, 0, 0.01, 0), Animation = "Unarmed.TempleHook",
		},
		{
			Id = "Unarmed_L4", Name = "Collapsing Palm", Kind = "Light", ComboIndex = 4,
			Startup = 9, Active = 4, Recovery = 16, ComboWindow = 0, CancelFrom = 9,
			BaseDamage = 8, PostureDamage = 14, Bleed = 0, DeflectVulnerability = 0.7,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 4.0, QiCost = 0, Reach = 4.5, Arc = 25, Lunge = 2.0,
			DamageType = "Blunt", Trauma = trauma(0.02, 0.05, 0, 0), Animation = "Unarmed.CollapsingPalm",
		},
	},
	Heavy = {
		Id = "Unarmed_Heavy", Name = "Iron Mountain Elbow", Kind = "Heavy", ComboIndex = 0,
		Startup = 24, Active = 4, Recovery = 24, ComboWindow = 0, CancelFrom = 14,
		BaseDamage = 14, PostureDamage = 26, Bleed = 0, DeflectVulnerability = 0.85,
		Deflectable = true, Unblockable = false, HyperArmor = false,
		StaminaCost = 8.0, QiCost = 0, Reach = 4.2, Arc = 30, Lunge = 3.0,
		DamageType = "Blunt", Trauma = trauma(0.10, 0.06, 0, 0), Animation = "Unarmed.IronMountainElbow",
	},
	RunningAttack = {
		Id = "Unarmed_Running", Name = "Flying Knee", Kind = "RunningAttack", ComboIndex = 0,
		Startup = 14, Active = 5, Recovery = 20, ComboWindow = 0, CancelFrom = 12,
		BaseDamage = 10, PostureDamage = 18, Bleed = 0, DeflectVulnerability = 0.8,
		Deflectable = true, Unblockable = false, HyperArmor = false,
		StaminaCost = 6.0, QiCost = 0, Reach = 4.8, Arc = 30, Lunge = 6.0,
		DamageType = "Blunt", Trauma = trauma(0.09, 0.04, 0, 0), Animation = "Unarmed.FlyingKnee",
	},
	WeaponArt = {
		Id = "Unarmed_Art", Name = "Sundering Qi Palm", Kind = "WeaponArt", ComboIndex = 0,
		Startup = 20, Active = 4, Recovery = 26, ComboWindow = 0, CancelFrom = 18,
		BaseDamage = 12, PostureDamage = 42, Bleed = 0, DeflectVulnerability = 0.9,
		Deflectable = true, Unblockable = true, HyperArmor = true,
		StaminaCost = 10.0, QiCost = 35, Reach = 5.0, Arc = 25, Lunge = 2.5,
		DamageType = "Blunt", Trauma = trauma(0.04, 0.12, 0, 0), Animation = "Unarmed.SunderingQiPalm",
	},
}

local JIAN: WeaponSpec = {
	Id = "Jian_Sword",
	Type = "Jian",
	Name = "Jian Sword",
	Grip = "OneHanded",
	Reach = 7.5,
	Weight = 1.2,
	DeflectEfficiency = 1.35,
	GuardChip = 0.10,
	BleedMultiplier = 0.8,
	PostureMultiplier = 1.0,
	BlockPostureResistance = 1.0,
	MoveSpeedMultiplier = 1.0,
	Light = {
		{
			Id = "Jian_L1", Name = "Darting Thrust", Kind = "Light", ComboIndex = 1,
			Startup = 8, Active = 3, Recovery = 12, ComboWindow = 8, CancelFrom = 6,
			BaseDamage = 8, PostureDamage = 8, Bleed = 0.25, DeflectVulnerability = 0.5,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 3.5, QiCost = 0, Reach = 7.5, Arc = 10, Lunge = 1.5,
			DamageType = "Pierce", Trauma = trauma(0.02, 0.04, 0, 0), Animation = "Jian.DartingThrust",
		},
		{
			Id = "Jian_L2", Name = "Rising Willow Cut", Kind = "Light", ComboIndex = 2,
			Startup = 8, Active = 4, Recovery = 12, ComboWindow = 8, CancelFrom = 6,
			BaseDamage = 9, PostureDamage = 9, Bleed = 0.3, DeflectVulnerability = 0.5,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 3.5, QiCost = 0, Reach = 7.0, Arc = 70, Lunge = 1.0,
			DamageType = "Slash", Trauma = trauma(0, 0.02, 0.04, 0), Animation = "Jian.RisingWillowCut",
		},
		{
			Id = "Jian_L3", Name = "Horizon Sweep", Kind = "Light", ComboIndex = 3,
			Startup = 9, Active = 4, Recovery = 14, ComboWindow = 8, CancelFrom = 7,
			BaseDamage = 10, PostureDamage = 10, Bleed = 0.3, DeflectVulnerability = 0.55,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 3.5, QiCost = 0, Reach = 7.2, Arc = 120, Lunge = 1.0,
			DamageType = "Slash", Trauma = trauma(0, 0.04, 0.03, 0), Animation = "Jian.HorizonSweep",
		},
		{
			Id = "Jian_L4", Name = "Piercing Heron Lunge", Kind = "Light", ComboIndex = 4,
			Startup = 11, Active = 4, Recovery = 18, ComboWindow = 0, CancelFrom = 10,
			BaseDamage = 13, PostureDamage = 14, Bleed = 0.35, DeflectVulnerability = 0.65,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 4.0, QiCost = 0, Reach = 8.5, Arc = 10, Lunge = 4.0,
			DamageType = "Pierce", Trauma = trauma(0.02, 0.06, 0, 0), Animation = "Jian.PiercingHeronLunge",
		},
	},
	Heavy = {
		Id = "Jian_Heavy", Name = "Falling Star Thrust", Kind = "Heavy", ComboIndex = 0,
		Startup = 26, Active = 4, Recovery = 26, ComboWindow = 0, CancelFrom = 16,
		BaseDamage = 20, PostureDamage = 28, Bleed = 0.4, DeflectVulnerability = 0.8,
		Deflectable = true, Unblockable = false, HyperArmor = false,
		StaminaCost = 9.0, QiCost = 0, Reach = 9.0, Arc = 12, Lunge = 3.5,
		DamageType = "Pierce", Trauma = trauma(0.03, 0.10, 0, 0), Animation = "Jian.FallingStarThrust",
	},
	RunningAttack = {
		Id = "Jian_Running", Name = "Swallow Skims Water", Kind = "RunningAttack", ComboIndex = 0,
		Startup = 15, Active = 5, Recovery = 20, ComboWindow = 0, CancelFrom = 12,
		BaseDamage = 14, PostureDamage = 16, Bleed = 0.35, DeflectVulnerability = 0.7,
		Deflectable = true, Unblockable = false, HyperArmor = false,
		StaminaCost = 6.5, QiCost = 0, Reach = 8.0, Arc = 40, Lunge = 7.0,
		DamageType = "Slash", Trauma = trauma(0, 0.03, 0, 0.06), Animation = "Jian.SwallowSkimsWater",
	},
	WeaponArt = {
		Id = "Jian_Art", Name = "Seven Star Flurry", Kind = "WeaponArt", ComboIndex = 0,
		Startup = 20, Active = 12, Recovery = 28, ComboWindow = 0, CancelFrom = 20,
		BaseDamage = 24, PostureDamage = 30, Bleed = 0.45, DeflectVulnerability = 0.6,
		Deflectable = true, Unblockable = false, HyperArmor = false,
		StaminaCost = 12.0, QiCost = 40, Reach = 8.0, Arc = 30, Lunge = 3.0,
		DamageType = "Pierce", Trauma = trauma(0.04, 0.08, 0.04, 0), Animation = "Jian.SevenStarFlurry",
	},
}

local DAO: WeaponSpec = {
	Id = "Dao_Sabre",
	Type = "Dao",
	Name = "Dao Sabre",
	Grip = "OneHanded",
	Reach = 7.0,
	Weight = 1.8,
	DeflectEfficiency = 1.0,
	GuardChip = 0.25,
	BleedMultiplier = 1.35,
	PostureMultiplier = 1.1,
	BlockPostureResistance = 0.95,
	MoveSpeedMultiplier = 0.98,
	Light = {
		{
			Id = "Dao_L1", Name = "Rising Crescent", Kind = "Light", ComboIndex = 1,
			Startup = 8, Active = 4, Recovery = 13, ComboWindow = 8, CancelFrom = 7,
			BaseDamage = 9, PostureDamage = 9, Bleed = 0.45, DeflectVulnerability = 0.6,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 3.5, QiCost = 0, Reach = 6.8, Arc = 90, Lunge = 1.2,
			DamageType = "Slash", Trauma = trauma(0, 0.03, 0.04, 0), Animation = "Dao.RisingCrescent",
		},
		{
			Id = "Dao_L2", Name = "Descending Crescent", Kind = "Light", ComboIndex = 2,
			Startup = 9, Active = 4, Recovery = 13, ComboWindow = 8, CancelFrom = 7,
			BaseDamage = 10, PostureDamage = 10, Bleed = 0.45, DeflectVulnerability = 0.6,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 3.5, QiCost = 0, Reach = 6.8, Arc = 90, Lunge = 1.2,
			DamageType = "Slash", Trauma = trauma(0.03, 0.04, 0.02, 0), Animation = "Dao.DescendingCrescent",
		},
		{
			Id = "Dao_L3", Name = "Whirling Butcher Cut", Kind = "Light", ComboIndex = 3,
			Startup = 10, Active = 5, Recovery = 15, ComboWindow = 8, CancelFrom = 8,
			BaseDamage = 11, PostureDamage = 12, Bleed = 0.5, DeflectVulnerability = 0.65,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 4.0, QiCost = 0, Reach = 7.0, Arc = 150, Lunge = 1.5,
			DamageType = "Slash", Trauma = trauma(0, 0.05, 0.03, 0), Animation = "Dao.WhirlingButcherCut",
		},
		{
			Id = "Dao_L4", Name = "Tiger Tail Cleave", Kind = "Light", ComboIndex = 4,
			Startup = 12, Active = 5, Recovery = 19, ComboWindow = 0, CancelFrom = 11,
			BaseDamage = 14, PostureDamage = 16, Bleed = 0.55, DeflectVulnerability = 0.75,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 4.0, QiCost = 0, Reach = 7.2, Arc = 60, Lunge = 2.5,
			DamageType = "Slash", Trauma = trauma(0.03, 0.04, 0.04, 0), Animation = "Dao.TigerTailCleave",
		},
	},
	Heavy = {
		Id = "Dao_Heavy", Name = "Butcher's Moon Arc", Kind = "Heavy", ComboIndex = 0,
		Startup = 27, Active = 5, Recovery = 27, ComboWindow = 0, CancelFrom = 17,
		BaseDamage = 22, PostureDamage = 26, Bleed = 0.6, DeflectVulnerability = 0.85,
		Deflectable = true, Unblockable = false, HyperArmor = true,
		StaminaCost = 9.5, QiCost = 0, Reach = 7.5, Arc = 110, Lunge = 2.5,
		DamageType = "Slash", Trauma = trauma(0.02, 0.08, 0.06, 0), Animation = "Dao.ButchersMoonArc",
	},
	RunningAttack = {
		Id = "Dao_Running", Name = "Charging Tiger", Kind = "RunningAttack", ComboIndex = 0,
		Startup = 15, Active = 6, Recovery = 22, ComboWindow = 0, CancelFrom = 13,
		BaseDamage = 15, PostureDamage = 18, Bleed = 0.5, DeflectVulnerability = 0.75,
		Deflectable = true, Unblockable = false, HyperArmor = false,
		StaminaCost = 6.5, QiCost = 0, Reach = 7.5, Arc = 80, Lunge = 7.5,
		DamageType = "Slash", Trauma = trauma(0, 0.05, 0.04, 0), Animation = "Dao.ChargingTiger",
	},
	WeaponArt = {
		Id = "Dao_Art", Name = "Crimson Gale Massacre", Kind = "WeaponArt", ComboIndex = 0,
		Startup = 22, Active = 14, Recovery = 30, ComboWindow = 0, CancelFrom = 22,
		BaseDamage = 28, PostureDamage = 24, Bleed = 0.8, DeflectVulnerability = 0.7,
		Deflectable = true, Unblockable = false, HyperArmor = true,
		StaminaCost = 12.0, QiCost = 40, Reach = 7.5, Arc = 180, Lunge = 4.0,
		DamageType = "Slash", Trauma = trauma(0.02, 0.07, 0.07, 0.03), Animation = "Dao.CrimsonGaleMassacre",
	},
}

local GUANDAO: WeaponSpec = {
	Id = "Guandao_Glaive",
	Type = "Guandao",
	Name = "Guandao Glaive",
	Grip = "TwoHanded",
	Reach = 11.0,
	Weight = 4.5,
	DeflectEfficiency = 0.85,
	GuardChip = 0.20,
	BleedMultiplier = 1.1,
	PostureMultiplier = 1.3,
	BlockPostureResistance = 1.2,
	MoveSpeedMultiplier = 0.9,
	Light = {
		{
			Id = "Guandao_L1", Name = "Crescent Reap", Kind = "Light", ComboIndex = 1,
			Startup = 12, Active = 5, Recovery = 16, ComboWindow = 9, CancelFrom = 9,
			BaseDamage = 12, PostureDamage = 14, Bleed = 0.35, DeflectVulnerability = 0.7,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 4.0, QiCost = 0, Reach = 10.5, Arc = 120, Lunge = 1.0,
			DamageType = "Slash", Trauma = trauma(0, 0.04, 0.02, 0.03), Animation = "Guandao.CrescentReap",
		},
		{
			Id = "Guandao_L2", Name = "Returning Tide", Kind = "Light", ComboIndex = 2,
			Startup = 12, Active = 5, Recovery = 17, ComboWindow = 9, CancelFrom = 9,
			BaseDamage = 12, PostureDamage = 15, Bleed = 0.35, DeflectVulnerability = 0.7,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 4.0, QiCost = 0, Reach = 10.5, Arc = 120, Lunge = 1.0,
			DamageType = "Slash", Trauma = trauma(0, 0.04, 0.03, 0.02), Animation = "Guandao.ReturningTide",
		},
		{
			Id = "Guandao_L3", Name = "Heaven-Splitting Cleave", Kind = "Light", ComboIndex = 3,
			Startup = 15, Active = 5, Recovery = 22, ComboWindow = 0, CancelFrom = 13,
			BaseDamage = 16, PostureDamage = 22, Bleed = 0.4, DeflectVulnerability = 0.8,
			Deflectable = true, Unblockable = false, HyperArmor = false,
			StaminaCost = 4.0, QiCost = 0, Reach = 11.0, Arc = 30, Lunge = 2.0,
			DamageType = "Slash", Trauma = trauma(0.06, 0.05, 0.03, 0), Animation = "Guandao.HeavenSplittingCleave",
		},
	},
	Heavy = {
		Id = "Guandao_Heavy", Name = "Green Dragon Reaping", Kind = "Heavy", ComboIndex = 0,
		Startup = 32, Active = 6, Recovery = 32, ComboWindow = 0, CancelFrom = 22,
		BaseDamage = 30, PostureDamage = 42, Bleed = 0.45, DeflectVulnerability = 0.95,
		Deflectable = true, Unblockable = false, HyperArmor = true,
		StaminaCost = 10.0, QiCost = 0, Reach = 12.0, Arc = 160, Lunge = 2.0,
		DamageType = "Slash", Trauma = trauma(0.03, 0.10, 0.04, 0.05), Animation = "Guandao.GreenDragonReaping",
	},
	RunningAttack = {
		Id = "Guandao_Running", Name = "Charging Dragon Thrust", Kind = "RunningAttack", ComboIndex = 0,
		Startup = 18, Active = 6, Recovery = 26, ComboWindow = 0, CancelFrom = 16,
		BaseDamage = 20, PostureDamage = 26, Bleed = 0.35, DeflectVulnerability = 0.85,
		Deflectable = true, Unblockable = false, HyperArmor = false,
		StaminaCost = 7.0, QiCost = 0, Reach = 12.5, Arc = 15, Lunge = 8.0,
		DamageType = "Pierce", Trauma = trauma(0.02, 0.09, 0, 0), Animation = "Guandao.ChargingDragonThrust",
	},
	WeaponArt = {
		Id = "Guandao_Art", Name = "Crescent Moon Cyclone", Kind = "WeaponArt", ComboIndex = 0,
		Startup = 26, Active = 16, Recovery = 34, ComboWindow = 0, CancelFrom = 26,
		BaseDamage = 32, PostureDamage = 48, Bleed = 0.5, DeflectVulnerability = 0.8,
		Deflectable = true, Unblockable = true, HyperArmor = true,
		StaminaCost = 14.0, QiCost = 50, Reach = 11.5, Arc = 360, Lunge = 1.5,
		DamageType = "Slash", Trauma = trauma(0, 0.06, 0.04, 0.10), Animation = "Guandao.CrescentMoonCyclone",
	},
}

local WEAPONS: { [WeaponType]: Weapon } = {
	Unarmed = Schema.build(UNARMED),
	Jian = Schema.build(JIAN),
	Dao = Schema.build(DAO),
	Guandao = Schema.build(GUANDAO),
}
local keys: {WeaponType} = table.clone(Schema.WeaponTypes)
for _, spec in Expansion.specs() do
	WEAPONS[spec.Id] = Schema.build(spec)
	if not table.find(keys, spec.Id) then table.insert(keys, spec.Id) end
end
Schema.WeaponKeys = table.freeze(keys)
-- Boss-only arms: built and validated like any weapon, but outside the 12-key player registry.
local bossKeys: {WeaponType} = {}
for _, spec in Expansion.bossSpecs() do
	assert(WEAPONS[spec.Id] == nil, "Boss weapon shadows a player weapon " .. spec.Id)
	WEAPONS[spec.Id] = Schema.build(spec)
	table.insert(bossKeys, spec.Id)
end
Schema.BossWeaponKeys = table.freeze(bossKeys)
-- Snapshot wire order: the player registry first (its indices never move), then boss-only arms.
local wire = table.clone(keys)
for _, id in bossKeys do table.insert(wire, id) end
Schema.WireKeys = table.freeze(wire)
function Schema.isBossOnly(id: string): boolean
	return table.find(bossKeys, id :: any) ~= nil
end
local BY_ID: { [string]: Weapon } = {}
for _, weapon in WEAPONS do
	assert(BY_ID[weapon.Id] == nil, "Duplicate weapon id " .. weapon.Id)
	BY_ID[weapon.Id] = weapon
end
table.freeze(WEAPONS)
table.freeze(BY_ID)

Schema.Weapons = WEAPONS
Schema.ById = BY_ID

function Schema.get(weaponType: WeaponType): Weapon
	local weapon = WEAPONS[weaponType]
	assert(weapon ~= nil, "Unknown weapon type")
	return weapon
end

function Schema.getById(id: string): Weapon?
	return BY_ID[id]
end

function Schema.findMove(weapon: Weapon, moveId: string): Move?
	return weapon.Moves[moveId]
end

-- Next light in the string; wraps to the opener once the finisher has played.
function Schema.nextLight(weapon: Weapon, current: Move?): Move
	if current == nil or current.Kind ~= "Light" or current.ComboIndex >= #weapon.Light then
		return weapon.Light[1]
	end
	return weapon.Light[current.ComboIndex + 1]
end

function Schema.moveForKind(weapon: Weapon, kind: MoveKind, current: Move?): Move
	if kind == "Light" then
		return Schema.nextLight(weapon, current)
	elseif kind == "Heavy" then
		return weapon.Heavy
	elseif kind == "RunningAttack" then
		return weapon.RunningAttack
	end
	return weapon.WeaponArt
end

function Schema.isTwoHanded(weapon: Weapon): boolean
	return weapon.Grip == "TwoHanded"
end

function Schema.postureDamage(move: Move, attacker: Weapon): number
	return move.PostureDamage * attacker.PostureMultiplier
end

function Schema.bleedBuildup(move: Move, attacker: Weapon): number
	return move.BaseDamage * move.Bleed * attacker.BleedMultiplier * Settings.Bleed.BuildupScale
end

-- Successful deflect: the attacker absorbs reflected posture, the defender pays a small share and no stamina.
function Schema.deflectOutcome(move: Move, attacker: Weapon, defender: Weapon): DeflectOutcome
	local posture = Schema.postureDamage(move, attacker)
	local p = Settings.Posture
	local outcome: DeflectOutcome = {
		AttackerPosture = posture * move.DeflectVulnerability * defender.DeflectEfficiency * p.DeflectReflectScale + posture * (defender.PostureReflect or 0),
		DefenderPosture = posture * p.DeflectSelfScale / defender.DeflectEfficiency,
		DefenderStamina = Settings.Stamina.Costs.DeflectSuccess,
	}
	return table.freeze(outcome) :: DeflectOutcome
end

-- Held guard: full posture pressure, guard-chip into RecoverableHP and the block stamina cost.
function Schema.blockOutcome(move: Move, attacker: Weapon, defender: Weapon, defenderStamina: number): BlockOutcome
	local p = Settings.Posture
	local scale = if move.Unblockable then p.UnblockableBlockScale else p.BlockScale
	local posture = Schema.postureDamage(move, attacker) * scale / defender.BlockPostureResistance
	local stamina: number = Settings.Stamina.Costs.Block
	local outcome: BlockOutcome = {
		DefenderPosture = posture,
		DefenderChip = if move.Unblockable then move.BaseDamage else move.BaseDamage * attacker.GuardChip,
		DefenderStamina = stamina,
		GuardBreak = move.Unblockable or defenderStamina - stamina <= Settings.Stamina.BreakThreshold,
	}
	return table.freeze(outcome) :: BlockOutcome
end

return table.freeze(Schema)

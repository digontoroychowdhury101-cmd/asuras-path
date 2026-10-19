--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/WorldDefinitions
-- Story Mode world manifest. Engine-free data (plain numbers, yaw in degrees) so the manifest is
-- validated identically by the server, the client and the local Luau runner.

local hasScript = pcall(function() return script.Parent end)
local Roster: any
if hasScript then Roster = require(script.Parent.BossRoster) else Roster = require("./BossRoster") end

type AttackKind = "PerilousSweep" | "PerilousThrust" | "PerilousGrab" | "Shockwave" | "Barrage" | "Gravity" | "Ritual" | "Leap" | "Breath" | "Tail" | "ShieldCharge"
type Motion = "Pillar" | "Aerial" | "Lunge" | "Teleport"
export type BossAttack = {
	Id: string, Kind: AttackKind, Windup: number, Radius: number, Damage: number, Posture: number,
	Height: number?, Speed: number?, Repeats: number?, Interval: number?, Duration: number?,
	Count: number?, Motion: Motion?, Element: string?, Unblockable: boolean?,
}
type GapCloser = { Range: number, Delay: number, Cooldown: number, Motion: Motion }

export type Vec3 = { X: number, Y: number, Z: number }
export type Placement = { X: number, Y: number, Z: number, Yaw: number }
export type Bounds = { Center: Vec3, Size: Vec3 }
export type RegionId = "Sanctuary" | "DesecratedMonastery" | "BambooPass" | "AshColosseum" | "SanctuaryDepths" | "CelestialPagoda" | "SkyCitadel"
export type WeaponType = "Unarmed" | "Jian" | "Dao" | "Guandao" | "Catalyst" | "PrayerOfTheDefiled" | "CalamityBoneCleaver" | "HeavenPiercingGuandao"

export type Stats = {
	MaxHP: number?,
	MaxStamina: number?,
	PostureCapacity: number?,
	StrengthScale: number?,
	DexterityScale: number?,
	PoiseArmor: number?,
	ReachBonus: number?,
}

export type AIProfile = {
	SightRange: number,
	FieldOfView: number,
	HearingRange: number,
	AlertTime: number,
	SearchTime: number,
	Aggression: number,
	DeflectChance: number,
	GuardChance: number,
	ReactionTime: number,
	TimingJitter: number,
	PatrolRadius: number,
	LeashRange: number,
	ComboContinueChance: number,
	HeavyChance: number,
	ArtChance: number,
	StrafeChance: number,
	RetreatStamina: number,
	PostureGuard: number,
	ThinkRate: number,
}

export type Region = {
	Id: RegionId,
	Name: string,
	Bounds: Bounds,
	MapFolder: string,
	Greybox: { Color: { number }, Material: string },
	Ambience: string,
	-- Region-scoped view of World.Altars keyed without the "Altar_" prefix, e.g.
	-- World.Regions.DesecratedMonastery.Altars.MonasteryGate. Filled from World.Altars at load.
	Altars: { [string]: Altar },
}

export type Altar = {
	Id: string,
	Name: string,
	Region: RegionId,
	Placement: Placement,
	Spawn: Placement,
	Radius: number,
	Starting: boolean,
}

export type MobDef = {
	Id: string,
	Name: string,
	Weapon: WeaponType,
	Stats: Stats,
	AI: AIProfile,
	Essence: number,
	BodyColor: { number },
}

export type MobSpawn = {
	Id: string,
	Mob: string,
	Region: RegionId,
	Placement: Placement,
	Patrol: { Placement },
}

export type Shockwave = {
	Windup: number,
	Radius: number,
	Damage: number,
	Posture: number,
	Unblockable: boolean,
}

export type BossPhase = {
	Attacks: { BossAttack }?,
	AttackInterval: number?,
	AnimationSet: string?,
	GapCloser: GapCloser?,
	Index: number,
	Name: string,
	Weapon: WeaponType,
	-- Enter this phase when HP falls to this fraction of max (nil for the opening phase).
	HPFraction: number?,
	-- Enter this phase on the first Deathblow received in the previous phase.
	OnDeathblow: boolean,
	Stats: Stats,
	AI: AIProfile,
	Transition: { Duration: number, Shockwave: Shockwave, BodyColor: { number } }?,
	Special: { IntervalMin: number, IntervalMax: number, Shockwave: Shockwave }?,
}

export type BossDef = {
	Archetype: string?, Scale: number?, Victory: string?, Affinity: string?,
	Partner: { Name: string, Weapon: WeaponType, Stats: Stats, Attacks: { BossAttack }, Affinity: string, Scale: number }?,
	Id: string,
	Name: string,
	Title: string,
	Region: RegionId,
	Arena: Bounds,
	Spawn: Placement,
	FogGate: string,
	Essence: number,
	Phases: { BossPhase },
	BodyColor: { number },
}

export type FogGate = {
	Id: string,
	Boss: string,
	Placement: Placement,
	Size: Vec3,
	-- Crossing into this volume (inside the arena) starts the encounter.
	Trigger: Bounds,
	-- Where trapped fighters are returned when they leave the arena, and where outsiders are ejected to.
	Inside: Placement,
	Outside: Placement,
}

-- Layout anchors for the Shrine of the Ascendant, the sky lobby above the sea of clouds. The
-- SanctuaryService builds around these points; the Colosseum ring and the bonfire altar read them.
export type SanctuaryLayout = {
	Origin: Vec3, -- Plaza centre at flagstone level
	PlazaRadius: number,
	PlinthHeight: number,
	Loggia: Vec3, -- West alcove centre (Blacksmith)
	Promenade: Vec3, -- East balcony centre (Colosseum ring)
	StairSteps: number,
	StairRise: number,
	StairRun: number,
	StairWidth: number,
	PortalDestination: string, -- Altar the Ascension Gateway delivers to
	CloudRadius: number,
}

local World = {}

local function v(x: number, y: number, z: number): Vec3
	return { X = x, Y = y, Z = z }
end

local function at(x: number, y: number, z: number, yaw: number?): Placement
	return { X = x, Y = y, Z = z, Yaw = yaw or 0 }
end

local function profile(overrides: { [string]: number }): AIProfile
	local base: AIProfile = {
		SightRange = 60,
		FieldOfView = 110,
		HearingRange = 28,
		AlertTime = 0.9,
		SearchTime = 6,
		Aggression = 0.6,
		DeflectChance = 0.3,
		GuardChance = 0.4,
		ReactionTime = 0.24,
		TimingJitter = 0.035,
		PatrolRadius = 12,
		LeashRange = 100,
		ComboContinueChance = 0.65,
		HeavyChance = 0.2,
		ArtChance = 0.06,
		StrafeChance = 0.35,
		RetreatStamina = 20,
		PostureGuard = 0.8,
		ThinkRate = 10,
	}
	local writable = base :: any
	for key, value in overrides do
		assert(writable[key] ~= nil, "Unknown AI profile field " .. key)
		writable[key] = value
	end
	return base
end

local SANCTUARY_ORIGIN = v(0, 600, 900)
local PLINTH_HEIGHT = 1.2

World.Sanctuary = {
	Origin = SANCTUARY_ORIGIN,
	PlazaRadius = 46,
	PlinthHeight = PLINTH_HEIGHT,
	Loggia = v(SANCTUARY_ORIGIN.X - 84, SANCTUARY_ORIGIN.Y, SANCTUARY_ORIGIN.Z),
	Promenade = v(SANCTUARY_ORIGIN.X + 94, SANCTUARY_ORIGIN.Y, SANCTUARY_ORIGIN.Z),
	StairSteps = 20,
	StairRise = 1,
	StairRun = 2,
	StairWidth = 14,
	PortalDestination = "Altar_MonasteryGate",
	CloudRadius = 1200,
} :: SanctuaryLayout

World.Regions = {
	Sanctuary = {
		Id = "Sanctuary",
		Name = "The Shrine of the Ascendant",
		Bounds = { Center = v(SANCTUARY_ORIGIN.X, SANCTUARY_ORIGIN.Y + 20, SANCTUARY_ORIGIN.Z), Size = v(420, 260, 420) },
		-- Built at runtime by SanctuaryService as Workspace.Sanctuary; its presence suppresses greybox.
		MapFolder = "Sanctuary",
		Greybox = { Color = { 120, 112, 104 }, Material = "Slate" },
		Ambience = "SkyShrine",
		Altars = {},
	},
	DesecratedMonastery = {
		Id = "DesecratedMonastery",
		Name = "Desecrated Monastery",
		Bounds = { Center = v(0, 40, -900), Size = v(400, 200, 440) },
		MapFolder = "Map_DesecratedMonastery",
		Greybox = { Color = { 74, 66, 60 }, Material = "Slate" },
		Ambience = "TempleBells",
		Altars = {},
	},
	BambooPass = {
		Id = "BambooPass",
		Name = "Bamboo Pass",
		Bounds = { Center = v(0, 40, -1400), Size = v(240, 200, 560) },
		MapFolder = "Map_BambooPass",
		Greybox = { Color = { 68, 92, 58 }, Material = "Grass" },
		Ambience = "WindReeds",
		Altars = {},
	},
	AshColosseum = {
		Id = "AshColosseum",
		Name = "Ash Colosseum",
		Bounds = { Center = v(0, 40, -1900), Size = v(360, 200, 440) },
		MapFolder = "Map_AshColosseum",
		Greybox = { Color = { 58, 54, 52 }, Material = "Basalt" },
		Ambience = "EmberCrowd",
		Altars = {},
	},
} :: { [RegionId]: Region }

World.RegionOrder = { "Sanctuary", "DesecratedMonastery", "BambooPass", "AshColosseum" } :: { RegionId }

World.Altars = {
	-- First-time players kneel here: the spawn stands before the bonfire, facing the staircase (-Z).
	Altar_SanctuaryBonfire = {
		Id = "Altar_SanctuaryBonfire",
		Name = "Primal Bonfire",
		Region = "Sanctuary",
		Placement = at(SANCTUARY_ORIGIN.X, SANCTUARY_ORIGIN.Y + PLINTH_HEIGHT, SANCTUARY_ORIGIN.Z),
		Spawn = at(SANCTUARY_ORIGIN.X, SANCTUARY_ORIGIN.Y + 3, SANCTUARY_ORIGIN.Z + 20, 0),
		Radius = 9,
		Starting = true,
	},
	Altar_MonasteryGate = {
		Id = "Altar_MonasteryGate",
		Name = "Monastery Gate",
		Region = "DesecratedMonastery",
		Placement = at(0, 0, -720),
		Spawn = at(0, 3, -728, 0),
		Radius = 9,
		Starting = false,
	},
	Altar_DesecratedCloister = {
		Id = "Altar_DesecratedCloister",
		Name = "Desecrated Cloister",
		Region = "DesecratedMonastery",
		Placement = at(60, 0, -1010),
		Spawn = at(60, 3, -1018, 0),
		Radius = 9,
		Starting = false,
	},
	Altar_BambooShrine = {
		Id = "Altar_BambooShrine",
		Name = "Whispering Bamboo Shrine",
		Region = "BambooPass",
		Placement = at(-30, 0, -1380),
		Spawn = at(-30, 3, -1388, 0),
		Radius = 9,
		Starting = false,
	},
	Altar_ColosseumAntechamber = {
		Id = "Altar_ColosseumAntechamber",
		Name = "Colosseum Antechamber",
		Region = "AshColosseum",
		Placement = at(0, 0, -1730),
		Spawn = at(0, 3, -1738, 0),
		Radius = 9,
		Starting = false,
	},
} :: { [string]: Altar }

for id, altar in World.Altars do
	local short = string.gsub(id, "^Altar_", "")
	local region = World.Regions[altar.Region]
	assert(region ~= nil, "Altar region missing " .. id)
	assert(region.Altars[short] == nil, "Duplicate region altar name " .. short)
	region.Altars[short] = altar
end

World.Mobs = {
	CorruptWanderingMonk = {
		Id = "CorruptWanderingMonk",
		Name = "Corrupt Wandering Monk",
		Weapon = "Unarmed",
		Stats = { MaxHP = 85, MaxStamina = 90, PostureCapacity = 80, StrengthScale = 0.9, DexterityScale = 0.9, PoiseArmor = 0.1 },
		AI = profile({
			SightRange = 55,
			HearingRange = 26,
			Aggression = 0.55,
			DeflectChance = 0.2,
			GuardChance = 0.45,
			ReactionTime = 0.28,
			PatrolRadius = 14,
			LeashRange = 90,
			ComboContinueChance = 0.6,
			HeavyChance = 0.25,
			ArtChance = 0.05,
			StrafeChance = 0.3,
		}),
		Essence = 45,
		BodyColor = { 112, 84, 60 },
	},
	CursedSwordsman = {
		Id = "CursedSwordsman",
		Name = "Cursed Swordsman",
		Weapon = "Dao",
		Stats = { MaxHP = 120, MaxStamina = 110, PostureCapacity = 110, StrengthScale = 1.0, DexterityScale = 1.0, PoiseArmor = 0.2 },
		AI = profile({
			SightRange = 65,
			FieldOfView = 100,
			HearingRange = 30,
			Aggression = 0.7,
			DeflectChance = 0.4,
			GuardChance = 0.35,
			ReactionTime = 0.22,
			PatrolRadius = 10,
			LeashRange = 110,
			ComboContinueChance = 0.75,
			HeavyChance = 0.2,
			ArtChance = 0.08,
			StrafeChance = 0.4,
		}),
		Essence = 80,
		BodyColor = { 46, 50, 62 },
	},
} :: { [string]: MobDef }

local function patrol(x: number, z: number, radius: number): { Placement }
	return {
		at(x + radius, 3, z),
		at(x, 3, z + radius),
		at(x - radius, 3, z),
		at(x, 3, z - radius),
	}
end

local function spawn(id: string, mob: string, region: RegionId, x: number, z: number, yaw: number, radius: number): MobSpawn
	return { Id = id, Mob = mob, Region = region, Placement = at(x, 3, z, yaw), Patrol = patrol(x, z, radius) }
end

World.Spawns = {
	spawn("DM_Monk_Courtyard_A", "CorruptWanderingMonk", "DesecratedMonastery", -30, -790, 180, 10),
	spawn("DM_Monk_Courtyard_B", "CorruptWanderingMonk", "DesecratedMonastery", 34, -812, 200, 12),
	spawn("DM_Monk_Hall_A", "CorruptWanderingMonk", "DesecratedMonastery", -70, -900, 90, 8),
	spawn("DM_Monk_Hall_B", "CorruptWanderingMonk", "DesecratedMonastery", 78, -920, 270, 8),
	spawn("DM_Swordsman_Bridge", "CursedSwordsman", "DesecratedMonastery", 0, -960, 180, 6),
	spawn("DM_Monk_Cloister", "CorruptWanderingMonk", "DesecratedMonastery", 40, -1060, 180, 10),
	spawn("DM_Swordsman_Cloister", "CursedSwordsman", "DesecratedMonastery", 90, -1080, 220, 8),
	spawn("BP_Swordsman_Trail_A", "CursedSwordsman", "BambooPass", 20, -1200, 180, 10),
	spawn("BP_Monk_Trail", "CorruptWanderingMonk", "BambooPass", -40, -1270, 160, 12),
	spawn("BP_Swordsman_Grove_A", "CursedSwordsman", "BambooPass", 50, -1450, 200, 8),
	spawn("BP_Swordsman_Grove_B", "CursedSwordsman", "BambooPass", -60, -1500, 140, 8),
	spawn("BP_Monk_Ridge", "CorruptWanderingMonk", "BambooPass", 10, -1590, 180, 10),
	spawn("AC_Swordsman_Gate_A", "CursedSwordsman", "AshColosseum", -24, -1800, 180, 6),
	spawn("AC_Swordsman_Gate_B", "CursedSwordsman", "AshColosseum", 24, -1810, 180, 6),
} :: { MobSpawn }

World.Bosses = {
	GrandmasterShen = {
		Id = "GrandmasterShen",
		Name = "Grandmaster Shen",
		Title = "Grandmaster Shen, the Fallen Abbot",
		Region = "AshColosseum",
		Arena = { Center = v(0, 20, -1960), Size = v(120, 60, 130) },
		Spawn = at(0, 3, -1995, 180),
		FogGate = "Gate_AshColosseum",
		Essence = 4000,
		BodyColor = { 210, 196, 168 },
		Phases = {
			{
				Index = 1,
				Name = "Disciplined Master",
				Weapon = "Jian",
				HPFraction = nil,
				OnDeathblow = false,
				Stats = {
					MaxHP = 900,
					MaxStamina = 220,
					PostureCapacity = 240,
					StrengthScale = 1.4,
					DexterityScale = 1.6,
					PoiseArmor = 0.3,
					ReachBonus = 0,
				},
				AI = profile({
					SightRange = 200,
					FieldOfView = 360,
					HearingRange = 200,
					AlertTime = 0.2,
					Aggression = 0.75,
					DeflectChance = 0.75,
					GuardChance = 0.6,
					ReactionTime = 0.16,
					TimingJitter = 0.02,
					PatrolRadius = 0,
					LeashRange = 1000,
					ComboContinueChance = 0.85,
					HeavyChance = 0.2,
					ArtChance = 0.12,
					StrafeChance = 0.5,
					RetreatStamina = 40,
					PostureGuard = 0.7,
					ThinkRate = 15,
				}),
				Transition = nil,
				Special = nil,
			},
			{
				Index = 2,
				Name = "Demonic Chimera",
				Weapon = "Guandao",
				HPFraction = 0.5,
				OnDeathblow = true,
				Stats = {
					PostureCapacity = 280,
					StrengthScale = 1.8,
					DexterityScale = 1.7,
					PoiseArmor = 0.65,
					ReachBonus = 2.5,
				},
				AI = profile({
					SightRange = 200,
					FieldOfView = 360,
					HearingRange = 200,
					AlertTime = 0.1,
					Aggression = 0.9,
					DeflectChance = 0.35,
					GuardChance = 0.25,
					ReactionTime = 0.2,
					TimingJitter = 0.03,
					PatrolRadius = 0,
					LeashRange = 1000,
					ComboContinueChance = 0.9,
					HeavyChance = 0.3,
					ArtChance = 0.25,
					StrafeChance = 0.25,
					RetreatStamina = 25,
					PostureGuard = 0.9,
					ThinkRate = 15,
				}),
				Transition = {
					Duration = 2.4,
					Shockwave = { Windup = 1.6, Radius = 22, Damage = 28, Posture = 45, Unblockable = true },
					BodyColor = { 120, 22, 24 },
				},
				Special = {
					IntervalMin = 12,
					IntervalMax = 18,
					Shockwave = { Windup = 0.9, Radius = 16, Damage = 22, Posture = 38, Unblockable = true },
				},
			},
		},
	},
} :: { [string]: BossDef }

World.FogGates = {
	Gate_AshColosseum = {
		Id = "Gate_AshColosseum",
		Boss = "GrandmasterShen",
		Placement = at(0, 10, -1893, 0),
		Size = v(26, 20, 1.5),
		Trigger = { Center = v(0, 10, -1905), Size = v(30, 20, 14) },
		Inside = at(0, 3, -1910, 180),
		Outside = at(0, 3, -1880, 0),
	},
} :: { [string]: FogGate }

Roster.apply(World, profile)
local Armaments: any
if hasScript then Armaments = require(script.Parent.BossArmaments) else Armaments = require("./BossArmaments") end
Armaments.apply(World)

-------------------------------------------------------------------------------------------------
-- Queries
-------------------------------------------------------------------------------------------------

function World.contains(bounds: Bounds, x: number, y: number, z: number): boolean
	local c, s = bounds.Center, bounds.Size
	return math.abs(x - c.X) <= s.X * 0.5 and math.abs(y - c.Y) <= s.Y * 0.5 and math.abs(z - c.Z) <= s.Z * 0.5
end

function World.regionAt(x: number, y: number, z: number): RegionId?
	for _, id in World.RegionOrder do
		if World.contains(World.Regions[id].Bounds, x, y, z) then
			return id
		end
	end
	return nil
end

function World.startingAltar(): Altar
	for _, altar in World.Altars do
		if altar.Starting then
			return altar
		end
	end
	error("World manifest has no starting altar")
end

function World.spawnsIn(region: RegionId): { MobSpawn }
	local result: { MobSpawn } = {}
	for _, entry in World.Spawns do
		if entry.Region == region then
			table.insert(result, entry)
		end
	end
	return result
end

function World.spawnById(id: string): MobSpawn?
	for _, entry in World.Spawns do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

-- Phase that should be active at an HP fraction and deathblow count (monotonic: never regresses).
function World.phaseFor(boss: BossDef, current: number, hpFraction: number, deathblows: number): number
	local phase = current
	for index = current + 1, #boss.Phases do
		local candidate = boss.Phases[index]
		local byHealth = candidate.HPFraction ~= nil and hpFraction <= candidate.HPFraction
		local byDeathblow = candidate.OnDeathblow and deathblows > 0
		if byHealth or byDeathblow then
			phase = index
		else
			break
		end
	end
	return phase
end

-------------------------------------------------------------------------------------------------
-- Manifest validation (runs at load on every peer)
-------------------------------------------------------------------------------------------------

local WEAPONS = { Unarmed = true, Jian = true, Dao = true, Guandao = true, Catalyst = true, PrayerOfTheDefiled=true, CalamityBoneCleaver=true, HeavenPiercingGuandao=true }

local function inside(bounds: Bounds, p: Placement | Vec3): boolean
	return World.contains(bounds, p.X, p.Y, p.Z)
end

local function validateProfile(ai: AIProfile, label: string)
	for _, key in { "Aggression", "DeflectChance", "GuardChance", "ComboContinueChance", "HeavyChance", "ArtChance", "StrafeChance", "PostureGuard" } do
		local value = (ai :: any)[key]
		assert(type(value) == "number" and value >= 0 and value <= 1, label .. " " .. key .. " must be 0..1")
	end
	assert(ai.FieldOfView > 0 and ai.FieldOfView <= 360, label .. " FieldOfView")
	assert(ai.ReactionTime >= 0.1, label .. " ReactionTime below human-fair floor")
	assert(ai.ThinkRate >= 1 and ai.ThinkRate <= 30, label .. " ThinkRate")
end

do
	for id, region in World.Regions do
		assert(region.Id == id, "Region id mismatch " .. id)
		assert(table.find(World.RegionOrder, id) ~= nil, "Region missing from order " .. id)
	end
	local starting = 0
	for id, altar in World.Altars do
		assert(altar.Id == id, "Altar id mismatch " .. id)
		local region = World.Regions[altar.Region]
		assert(region ~= nil, "Altar region missing " .. id)
		assert(inside(region.Bounds, altar.Placement) and inside(region.Bounds, altar.Spawn), "Altar outside region " .. id)
		if altar.Starting then
			starting += 1
		end
	end
	assert(starting == 1, "Exactly one starting altar required")
	for id, mob in World.Mobs do
		assert(mob.Id == id and WEAPONS[mob.Weapon], "Invalid mob " .. id)
		assert(mob.Essence > 0, "Mob essence " .. id)
		validateProfile(mob.AI, id)
	end
	local seen: { [string]: boolean } = {}
	for _, entry in World.Spawns do
		assert(not seen[entry.Id], "Duplicate spawn " .. entry.Id)
		seen[entry.Id] = true
		assert(World.Mobs[entry.Mob] ~= nil, "Spawn references unknown mob " .. entry.Id)
		local region = World.Regions[entry.Region]
		assert(region and inside(region.Bounds, entry.Placement), "Spawn outside region " .. entry.Id)
		for _, point in entry.Patrol do
			assert(inside(region.Bounds, point), "Patrol point outside region " .. entry.Id)
		end
	end
	for id, boss in World.Bosses do
		assert(boss.Id == id, "Boss id mismatch " .. id)
		local region = World.Regions[boss.Region]
		assert(region and inside(region.Bounds, boss.Arena.Center), "Boss arena outside region " .. id)
		assert(inside(boss.Arena, boss.Spawn), "Boss spawn outside arena " .. id)
		local gate = World.FogGates[boss.FogGate]
		assert(gate and gate.Boss == id, "Boss fog gate mismatch " .. id)
		assert(#boss.Phases >= 1 and boss.Phases[1].Stats.MaxHP ~= nil, "Boss opening phase needs MaxHP " .. id)
		for index, phase in boss.Phases do
			for _, attack in phase.Attacks or {} do
				assert(attack.Windup >= 0.65 and attack.Radius > 0 and attack.Damage >= 0, "Invalid boss attack " .. attack.Id)
			end
			assert(phase.Index == index and WEAPONS[phase.Weapon], "Boss phase order " .. id)
			validateProfile(phase.AI, id .. ".Phase" .. index)
			if index > 1 then
				assert(phase.HPFraction ~= nil or phase.OnDeathblow, "Later phase needs a trigger " .. id)
			end
		end
	end
	for id, gate in World.FogGates do
		assert(gate.Id == id and World.Bosses[gate.Boss] ~= nil, "Fog gate boss missing " .. id)
		local arena = World.Bosses[gate.Boss].Arena
		assert(inside(arena, gate.Trigger.Center) and inside(arena, gate.Inside), "Fog gate trigger/inside must lie in the arena " .. id)
		assert(not inside(arena, gate.Outside), "Fog gate outside point must lie outside the arena " .. id)
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
do
	local layout = World.Sanctuary
	assert(World.Altars[layout.PortalDestination] ~= nil, "Sanctuary portal destination missing")
	local region = World.Regions.Sanctuary
	for _, point in { layout.Origin, layout.Loggia, layout.Promenade } do
		assert(inside(region.Bounds, point), "Sanctuary layout point outside its region")
	end
	assert(layout.StairSteps >= 1 and layout.StairRise > 0 and layout.StairRun > 0 and layout.StairWidth > 0, "Invalid staircase")
end

deepFreeze(World.Sanctuary)
deepFreeze(World.Regions)
deepFreeze(World.RegionOrder)
deepFreeze(World.Altars)
deepFreeze(World.Mobs)
deepFreeze(World.Spawns)
deepFreeze(World.Bosses)
deepFreeze(World.FogGates)

return table.freeze(World)

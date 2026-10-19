--!strict
-- Appends the campaign without a circular dependency on WorldDefinitions.
local hasScript = pcall(function() return script.Parent end)
local Attacks: any
if hasScript then Attacks = require(script.Parent.BossAttackCatalog) else Attacks = require("./BossAttackCatalog") end
local Roster = {}
local function vec(x: number, y: number, z: number): any return { X = x, Y = y, Z = z } end
local function at(x: number, z: number): any return { X = x, Y = 3, Z = z, Yaw = 180 } end
function Roster.apply(world: any, profile: ({ [string]: number }) -> any)
	local regions = {
		{ "SanctuaryDepths", "Sanctuary Depths", 520, 900 },
		{ "CelestialPagoda", "Celestial Pagoda Rafters", 0, -2360 },
		{ "SkyCitadel", "Sky Citadel", 0, -2800 },
	}
	for _, entry in regions do
		local id, name, x, z = entry[1] :: string, entry[2] :: string, entry[3] :: number, entry[4] :: number
		world.Regions[id] = { Id = id, Name = name, Bounds = { Center = vec(x, 40, z), Size = vec(360, 200, 360) },
			MapFolder = "Map_" .. id, Greybox = { Color = { 47, 48, 62 }, Material = "Slate" }, Ambience = "StarlessWind", Altars = {} }
		table.insert(world.RegionOrder, id)
		local altarId = "Altar_" .. id
		local altar = { Id = altarId, Name = name .. " Incense", Region = id, Placement = at(x, z + 145), Spawn = at(x, z + 145), Radius = 12, Starting = false }
		world.Altars[altarId] = altar
		world.Regions[id].Altars[id] = altar
	end
	-- A side courtyard leaves the authored monastery route intact.
	world.Regions.DesecratedMonastery.Bounds.Size.X = 900
	local ai = profile({ SightRange = 220, FieldOfView = 360, HearingRange = 200, LeashRange = 1000,
		AlertTime = 0.15, Aggression = 0.85, PatrolRadius = 0, ThinkRate = 15, ComboContinueChance = 0.8 })
	local function phase(index: number, name: string, weapon: string, hp: number, moves: any, motion: string): any
		return { Index = index, Name = name, Weapon = weapon, HPFraction = if index == 2 then 0.5 else nil,
			OnDeathblow = index == 2, Stats = { MaxHP = hp, MaxStamina = 260, PostureCapacity = hp * 0.24,
				StrengthScale = 1.6, DexterityScale = 1.5, PoiseArmor = 0.5 }, AI = table.clone(ai),
			AnimationSet = name, Attacks = moves, AttackInterval = if index == 2 then 2.2 else 3.2,
			GapCloser = { Range = 40, Delay = 2.5, Cooldown = 7, Motion = motion },
			Transition = if index == 2 then { Duration = 2.8, BodyColor = { 80, 110, 160 },
				Shockwave = { Windup = 1.8, Radius = 32, Damage = 24, Posture = 40, Unblockable = true } } else nil }
	end
	local function boss(id: string, name: string, title: string, region: string, x: number, z: number, hp: number, weapon: string, moves: any, archetype: string, scale: number, motion: string)
		local gateId = "Gate_" .. id
		world.Bosses[id] = { Id = id, Name = name, Title = title, Region = region, Archetype = archetype, Scale = scale,
			Arena = { Center = vec(x, 36, z), Size = vec(180, 100, 180) }, Spawn = at(x, z - 25), FogGate = gateId,
			Essence = hp * 4, BodyColor = { 140, 154, 178 }, Victory = "LEGEND FELLED",
			Phases = { phase(1, "Ancient Oath", weapon, hp, moves, motion), phase(2, "Unbound", weapon, hp, moves, motion) } }
		world.FogGates[gateId] = { Id = gateId, Boss = id, Placement = { X = x, Y = 12, Z = z + 90, Yaw = 0 }, Size = vec(26, 24, 2),
			Trigger = { Center = vec(x, 10, z + 78), Size = vec(24, 20, 12) }, Inside = at(x, z + 70), Outside = at(x, z + 108) }
	end
	boss("VenerableBaize", "Venerable Baize", "Beast of the Frosted Ridge", "BambooPass", 0, -1470, 1100, "Unarmed", Attacks.Baize, "Beast", 1.5, "Pillar")
	boss("SlumberingTitan", "The Slumbering Titan", "Ancient of the Sunken Crypt", "SanctuaryDepths", 520, 880, 1600, "Guandao", Attacks.Titan, "Colossus", 3, "Lunge")
	boss("SovereignWu", "Sovereign Wu", "The Starless Oracle", "CelestialPagoda", 0, -2380, 1250, "Catalyst", Attacks.Wu, "Sorcerer", 1.2, "Teleport")
	boss("TwinSentinels", "General Zhao", "The Twin Sentinels: Zhao & the Iron Bull", "DesecratedMonastery", 300, -930, 1000, "Guandao", Attacks.Zhao, "Duo", 1.2, "Lunge")
	boss("AzureWyrm", "Azure Wyrm", "Overlord of the Heavenly Summit", "SkyCitadel", 0, -2830, 1600, "Guandao", Attacks.Wyrm, "Dragon", 2.2, "Aerial")
	local duo = world.Bosses.TwinSentinels
	duo.Phases = { duo.Phases[1] }
	duo.Partner = { Name = "The Iron Bull", Weapon = "Guandao", Stats = { MaxHP = 1600, MaxStamina = 320, PostureCapacity = 460, PoiseArmor = 0.9 },
		Attacks = Attacks.Bull, Affinity = "Iron", Scale = 1.7 }
	duo.Affinity = "Lightning"
	local shen = world.Bosses.GrandmasterShen
	shen.Archetype, shen.Victory = "Duelist", "GREAT FOE VANQUISHED"
	for i, p in shen.Phases do
		p.Attacks, p.AttackInterval, p.AnimationSet = if i == 1 then Attacks.Shen else Attacks.Chimera, 3, if i == 1 then "DisciplinedMaster" else "DemonicChimera"
		p.GapCloser = { Range = 36, Delay = 2.5, Cooldown = 7, Motion = "Lunge" }
	end
	shen.Phases[2].Special = nil
end
return Roster

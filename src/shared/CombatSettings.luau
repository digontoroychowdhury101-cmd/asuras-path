--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/CombatSettings
-- Asura's Path combat tuning. Durations and rates here are real-time values; frame data in
-- WeaponSchema is authored at baseline and scaled through Simulation/Tempo.

export type InjuryTier = "None" | "Impaired" | "Injured" | "Severe"
export type InjuryRegion = "Head" | "Torso" | "LeftArm" | "RightArm" | "LeftLeg" | "RightLeg"
export type InjuryGroup = "Head" | "Torso" | "Arm" | "Leg"
export type Range = { Min: number, Max: number }
export type Thresholds = { Impaired: number, Injured: number, Severe: number }

local function freeze(value: any)
	if type(value) ~= "table" or table.isfrozen(value) then
		return
	end
	for _, child in value do
		freeze(child)
	end
	table.freeze(value)
end

local Settings = {
	SchemaVersion = 2,

	Tempo = {
		Scalar = 1.4,
		TickRate = 60,
		TickSeconds = 1 / 60,
		Telegraph = {
			HeavyMinSeconds = 0.210,
			LightTargetSeconds = 0.085,
		},
	},

	Health = {
		MaxHP = 100,
		Layers = { "ActiveHP", "RecoverableHP", "PermanentDeficit" },
		-- Fraction of each hit's damage that becomes RecoverableHP debt rather than a clean loss.
		RecoverableFraction = {
			Chip = 1.0,
			Light = 0.6,
			Heavy = 0.35,
			RunningAttack = 0.4,
			WeaponArt = 0.25,
			Bleed = 0.0,
			Deathblow = 0.0,
		},
		-- Fraction of each hit's damage that permanently lowers effective max HP until a shrine rest.
		PermanentFraction = {
			Chip = 0.0,
			Light = 0.0,
			Heavy = 0.08,
			RunningAttack = 0.05,
			WeaponArt = 0.12,
			Bleed = 0.5,
			Deathblow = 0.25,
		},
		MaxPermanentDeficit = 60,
		MinEffectiveMaxHP = 40,
		Rally = {
			Window = 3.0,
			ReturnRatio = 0.85,
			DecayDelay = 3.0,
			DecayRate = 8.0,
			DeflectBonus = 4.0,
		},
		Shrine = {
			RestoresActiveHP = true,
			ClearsRecoverableHP = true,
			ClearsPermanentDeficit = true,
			ClearsInjuries = true,
			RestDuration = 1.6,
		},
	},

	Bleed = {
		Max = 100,
		DecayRate = 6.0,
		DecayDelay = 1.5,
		-- Buildup per hit = BaseDamage * move.Bleed * weapon.BleedMultiplier * BuildupScale.
		BuildupScale = 3.0,
		ProcDamageFraction = 0.15,
		ResetOnProc = true,
	},

	Posture = {
		MaxPosture = 100,
		DecayRate = 14.0,
		GuardingDecayMultiplier = 0.35,
		DecayDelay = 0.9,
		LowHealthDecayScale = { AtFullHP = 1.0, AtZeroHP = 0.35 },
		DeflectWindow = 0.10,
		DeflectWindowMin = 0.060,
		DeflectRecovery = 0.20,
		DeflectSpamLockout = 0.30,
		DeflectSpamDecay = 0.45,
		DeflectReflectScale = 0.6,
		DeflectMinimumReflect = 8,
		DeflectChainFloor = 0.030,
		DeflectSelfScale = 0.35,
		BlockScale = 1.0,
		BlockDamageScale = 0.0,
		UnblockableBlockScale = 1.6,
		StanceBreakThreshold = 100,
		StanceBreakResetValue = 0,
		HitScale = 0.5,
	},

	Stamina = {
		Max = 100,
		RegenRate = 32.0,
		RegenDelay = 0.45,
		GuardRegenMultiplier = 0.5,
		BrokenRegenMultiplier = 1.5,
		BreakThreshold = 0,
		RecoverToFraction = 0.6,
		SprintCostPerSecond = 9.0,
		SprintMinimum = 5.0,
		Costs = {
			Light = 3.5,
			Heavy = 9.0,
			Roll = 6.0,
			Dash = 6.0,
			RunningAttack = 6.0,
			WeaponArt = 12.0,
			DeflectSuccess = 0.0,
			DeflectMiss = 12.0,
			Block = 12.0,
			Feint = 4.0,
			Heal = 0.0,
		},
		LightRange = { Min = 3.0, Max = 4.0 },
		HeavyRange = { Min = 8.0, Max = 10.0 },
	},

	Qi = {
		Max = 100,
		Initial = 100,
		GainOnHit = 8,
		GainOnDeflect = 15,
		GainOnDeathblow = 25,
		DecayRate = 0,
		PassiveRegen = 2,
		ClearOnShrine = false,
	},

	Stun = {
		StaminaBroken = 1.4,
		GuardBroken = 1.4,
		StanceBroken = 2.5,
		HitstunLight = 0.28,
		HitstunHeavy = 0.48,
		Blockstun = 0.18,
		DeflectRecoil = 0.32,
		DeathblowAttacker = 1.1,
		DeathblowVictim = 1.6,
	},

	Deathblow = {
		DamageFraction = 0.6,
		MinimumDamage = 30,
		Range = 5.0,
		FacingDot = 0.2,
		InvulnerableToOthers = true,
		ClearsPosture = true,
	},

	Counter = {
		HitMultiplier = 1.25,
		PostureMultiplier = 1.25,
	},

	Feint = {
		-- Seconds after Startup begins during which a Heavy or Weapon Art may be feinted.
		Window = 0.15,
		Kinds = { Heavy = true, WeaponArt = true },
	},

	-- Rapid Roll/Dash spam shortens distance and i-frames; a landed strike or a quiet gap resets it.
	Backdash = {
		SpamWindow = 1.2,
		DecayPerUse = 0.18,
		MinDistanceScale = 0.45,
		IFrameDecayPerUse = 0.25,
		MinIFrameScale = 0.0,
		CancelFraction = 0.6,
	},

	Elixir = {
		HealFraction = 0.4,
		DrinkDuration = 0.9,
		BaseCharges = 3,
		MaxCharges = 8,
	},

	-- Attribute-derived poise: armor >= LightThreshold shrugs off light hitstun, >= HeavyThreshold every hit.
	Poise = {
		LightThreshold = 0.5,
		HeavyThreshold = 0.9,
		PostureReduction = 0.5,
	},

	Respawn = {
		PlayerDelay = 3.5,
		EnemyCorpseTime = 4.0,
		DuelResetDelay = 3.0,
	},

	Enemy = {
		ThinkRate = 10,
		AggroRange = 60,
		LeashRange = 140,
		ReactionTime = 0.22,
		DeflectChance = 0.45,
		HeavyChance = 0.2,
		ArtChance = 0.1,
		Aggression = 0.65,
		ComboContinueChance = 0.7,
		TimingJitter = 0.035,
	},

	Movement = {
		SlideBoost = 1.4,
		SlideFriction = 14,
		SlideMaxSpeed = 95,
		SlideMinSpeed = 8,
		SlideHipDrop = 0.6,
		SlideGroundGrace = 0.16,
		BulletSpeed = 75,
		DoubleJumpUp = 50,
		DoubleJumpForward = 25,
		GlideFallSpeed = 6,
		GlideDuration = 3.5,
		GlideSteering = 4,
		WalkSpeed = 16 * 1.4,
		SprintSpeed = 24 * 1.4,
		DashDistance = 14,
		DashDuration = 0.22,
		RollDistance = 11,
		RollDuration = 0.36,
		RollInvulnerable = { Start = 0.04, Finish = 0.24 },
		DashInvulnerable = { Start = 0.0, Finish = 0.10 },
	},

	Input = {
		BufferWindow = 0.10,
		BufferCapacity = 16,
		DuplicateWindow = 0.033,
		Priority = {
			Deflect = 100,
			Roll = 85,
			Dash = 80,
			WeaponArt = 70,
			Heavy = 60,
			RunningAttack = 55,
			Light = 40,
			Block = 30,
			Heal = 20,
			Equip = 10,
		},
	},

	Injury = {
		Tiers = { "None", "Impaired", "Injured", "Severe" } :: { InjuryTier },
		TierIndex = { None = 0, Impaired = 1, Injured = 2, Severe = 3 } :: { [InjuryTier]: number },
		Regions = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } :: { InjuryRegion },
		Group = {
			Head = "Head",
			Torso = "Torso",
			LeftArm = "Arm",
			RightArm = "Arm",
			LeftLeg = "Leg",
			RightLeg = "Leg",
		} :: { [InjuryRegion]: InjuryGroup },
		-- Accumulated trauma coefficient (0..1) at which each tier begins.
		Thresholds = {
			Head = { Impaired = 0.20, Injured = 0.45, Severe = 0.75 },
			Torso = { Impaired = 0.30, Injured = 0.60, Severe = 0.90 },
			Arm = { Impaired = 0.25, Injured = 0.55, Severe = 0.85 },
			Leg = { Impaired = 0.25, Injured = 0.55, Severe = 0.85 },
		} :: { [InjuryGroup]: Thresholds },
		RecoveryPerSecond = {
			Head = 0.010,
			Torso = 0.008,
			Arm = 0.008,
			Leg = 0.008,
		} :: { [InjuryGroup]: number },
		RecoveryDelay = 6.0,
		-- Once a region reaches this tier, natural recovery stops at its threshold; only a shrine clears it.
		PersistentTier = "Injured" :: InjuryTier,
		BluntHeadConcussionScale = 1.5,
		-- Penalty ranges: Impaired uses Min, Severe uses Max, Injured interpolates the midpoint.
		Penalties = {
			Arm = {
				StaminaCostIncrease = { Min = 0.30, Max = 0.50 },
				DamageReduction = { Min = 0.20, Max = 0.35 },
			},
			Leg = {
				SpeedReduction = { Min = 0.15, Max = 0.30 },
				DashDistanceReduction = { Min = 0.15, Max = 0.30 },
			},
			Head = {
				DeflectWindowReduction = { Min = 0.10, Max = 0.30 },
				PostureDecayReduction = { Min = 0.15, Max = 0.45 },
				VisionBlur = { Min = 0.20, Max = 0.75 },
				EyeVignette = { Min = 0.15, Max = 0.60 },
			},
			Torso = {
				StaminaRegenReduction = { Min = 0.10, Max = 0.30 },
				MaxPostureReduction = { Min = 0.05, Max = 0.15 },
			},
		},
	},
	Colosseum = {
		-- Studio sessions open the ranked queue without the release gate or a Workspace override.
		-- Studio runs on mock persistence (Config.Backend.StudioLiveData = false), so test duels
		-- never touch live ratings. Live servers still require Config.Features.Matchmaking and
		-- Config.Release.RankedIntegrationPassed. Set Workspace attribute AsuraColosseumQA = false
		-- in Studio to rehearse the sealed-league path.
		RankedInDevelopment = true,
	},
}

freeze(Settings)
return Settings

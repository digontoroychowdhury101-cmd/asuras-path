-- [Connection Verified: Computer B is Live]
--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Config
-- Edit this module, then restart Play. Arena geometry is rebuilt once at startup.
-- Editor preview: run tools/RefreshPreview.luau from Studio's Command Bar.
local Config = {
	Project = { Name = "AsurasPath", Phase = 12, SchemaVersion = 12, ArenaVersion = 1 },
	Names = { Root = "AsurasPath", Arena = "Arena", ReadyAttribute = "Phase12Ready" },
	Runtime = { DependencyTimeoutSeconds = 15, MaximumArenaParts = 1200 },
	Backend = { StudioLiveData = false, AutosaveSeconds = 45, LeaseSeconds = 180 },
	Release = { RankedIntegrationPassed = false, PurchasesIntegrationPassed = false },
	PresentationIntensity = "ModerateTarget",
	Assets = {
		-- No uploaded assets are required for the calibration mannequin.
		IDs = {} :: { [string]: string },
		-- Missing production assets: empty IDs are deliberate, never invented IDs.
		Pending = { "MDL_Fighter_CBRig_v1_LOD0", "ANIM_Ironline_Idle",
			"ANIM_Shared_Step_Forward", "ANIM_Shared_Step_Backward", "ANIM_Shared_Step_Left", "ANIM_Shared_Step_Right",
			"ANIM_Calibration_LeadStraight", "ANIM_Calibration_RearStraight",
			"ANIM_Calibration_LeadFrontKick", "ANIM_Calibration_RearFrontKick",
			"ANIM_Calibration_LeadStraight_Body", "SFX_Shared_Strike_Swing", "SFX_Shared_Strike_Impact", "SFX_Shared_Strike_Block", "VFX_Shared_Impact", "ANIM_Calibration_LeadFrontKick_Body", "ANIM_Calibration_RearStraight_Body", "ANIM_Calibration_RearFrontKick_Body", "ANIM_Calibration_LeadHook", "ANIM_Calibration_LeadHook_Body", "ANIM_Calibration_RearHook", "ANIM_Calibration_RearHook_Body", "ANIM_SharedLunge", "ANIM_SharedPullDown", "ANIM_SharedClinch", "ANIM_SharedHeadlock" },
	},
	Match = { RoundCount = 3, RoundSeconds = 120, BreakSeconds = 20, CountdownSeconds = 3, CornerHeal = 25, DominantScoreThreshold = 18 },
	Injury = {
		Thresholds = { Impaired = 35, Injured = 65, Severe = 90 },
		ArmDamagePenalty = 0.8,
		ArmStaminaPenalty = 1.1,
		LegMovePenaltyPerLeg = 0.1,
		LegMovePenaltyCap = 0.2,
		LegDamagePenalty = 0.8,
		StressAccumulationRate = 0.5,
	},
	Features = {
		Combat = true, StyleRolls = true, Persistence = true, Matchmaking = false, PaidPurchases = false,
		Blood = false, Injuries = true, CustomFighter = true,
	},
	Effects = { PoolSize = 8, Volume = 0.28, RollOffDistance = 50,
		ImpactSound = "rbxasset://sounds/action_jump_land.mp3",
		BlockSound = "rbxasset://sounds/action_footsteps_plastic.mp3",
		GrappleSound = "rbxasset://sounds/action_get_up.mp3" },
	Animation = { FadeSeconds = 0.05, LoadTimeout = 5, DriftSeconds = 0.12, MarkerToleranceTicks = 3 },
	Combat = {
		-- Calibration content: strikes, blocks, damage, stamina, standing grapples, and Phase 7 ground fighting.
		MaxHealth = 100, MaxStamina = 100, StaminaRegenPerSecond = 18,
		RegenDelayTicks = 30, GuardDrainPerSecond = 5, GuardDamageScale = 0.1,
		GuardArcCos = math.cos(math.rad(65)), GuardBreakTicks = 45,
		BlockStunTicks = 7, HitStunTicks = 15, KOResetTicks = 180,
		GuardMoveScale = 0.5, AttackMoveScale = 0.3, HitMoveScale = 0,
		AttackTurnScale = 0, GuardTurnScale = 0.7,
		GrappleMaxTicks = 180, GrappleDrainPerSecond = 8, GrappleBreakCost = 15,
		GrappleSeparation = 1.85, GrappleArcCos = math.cos(math.rad(60)),
		GroundMaxTicks = 240, GroundDrainPerSecond = 5, GroundSeparation = 1.2,
		MountDamageScale = 1.25, GroundTransitionCost = 12, SweepCost = 15,
		StandUpCost = 15, TakedownStaminaCost = 10,
		SubmissionMaxTicks = 180, SubmissionDrainPerSecond = 15, SubmissionDamagePerSecond = 8,
		SubmissionEscapeCost = 25, SubmissionStaminaCost = 15, GroundStrikeDamage = 10, GroundStrikeStamina = 8,
		CounterDamageScale = 1.25, CounterStunTicks = 6, FeintStaminaCost = 5,
		PracticeDummyGuard = true, DummyGuardResumeStamina = 60, SweepEpsilon = 0.000001,
		MaxBodyDamage = 100, DisplayExtrapolationTicks = 3, InputBufferTicks = 8, PreviewTimeoutSeconds = 0.35,
		Parts = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" },
		Hurtboxes = {
			{ Part = "Head", X = 0, Y = 5.5, Z = 0, Radius = 0.55 },
			{ Part = "Torso", X = 0, Y = 4, Z = 0, Radius = 0.75 },
			{ Part = "LeftArm", X = -1.02, Y = 4.1, Z = -0.1, Radius = 0.32 },
			{ Part = "RightArm", X = 1.02, Y = 4.1, Z = -0.1, Radius = 0.32 },
			{ Part = "LeftLeg", X = -0.38, Y = 1.6, Z = 0, Radius = 0.4 },
			{ Part = "RightLeg", X = 0.38, Y = 1.6, Z = 0, Radius = 0.4 },
		},
	},
	Movement = {
		TickRate = 60, MaxCatchupSteps = 6, MaxFrameDelta = 0.1,
		Speed = 9.5, BackwardScale = 0.75, StrafeScale = 0.85,
		Acceleration = 52, Deceleration = 64, TurnRate = math.rad(360),
		Radius = 1.15, RootHeight = 3, CollisionPasses = 4, Epsilon = 0.000001,
		MaxFighters = 2, DummyId = 0,
	},
	Network = {
		ShopPerSecond = 2, ShopBurst = 4,
		Protocol = 4, SendRate = 30, SnapshotRate = 30, MaxBatch = 6,
		MaxQueue = 6, MaxPending = 120, MaxSequence = 2147483647,
		MessagesPerSecond = 45, MessageBurst = 60, FramesPerSecond = 60, FrameBurst = 18,
		ActionsPerSecond = 20, ActionBurst = 30, ActionCooldown = 0.06,
		InputTimeout = 0.35, DisconnectWarning = 2, SessionLength = 36,
		InterpolationDelay = 0.067, SnapshotHistory = 8, MaxSequenceGap = 240,
	},
	Camera = {
		FOV = 70, MinFOV = 70, MaxFOV = 90, FOVStep = 5,
		EyeHeight = 5.6, EyeForward = 0.12, Clearance = 0.25,
		PitchLimit = math.rad(75), MouseSensitivity = 0.0025,
		TouchSensitivity = 0.004, GamepadSensitivity = 2.4,
		SensitivityMin = 0.5, SensitivityMax = 2, SensitivityStep = 0.25,
		FocusDistance = 12, CorrectionSpeed = 18, SnapDistance = 3,
		TraumaDecay = 2.5, MaxTraumaYaw = math.rad(4), MaxTraumaPitch = math.rad(3),
		MaxTraumaRoll = math.rad(2.5), MaxFovKick = 4,
	},
	Input = {
		ContextPriority = 3000, StickDeadzone = 0.15, BufferSeconds = 0.2,
		BufferCapacity = 8, SwipePixels = 28, SwipeMaxSeconds = 0.45,
		TouchStickPixels = 60, TouchControlScale = 1, TapHoldSeconds = 0.5,
		Bindings = {
			LeftHand = { Keyboard = "MouseLeftButton", Gamepad = "ButtonL2" },
			RightHand = { Keyboard = "MouseRightButton", Gamepad = "ButtonR2" },
			LeftLeg = { Keyboard = "Q", Gamepad = "ButtonL1" },
			RightLeg = { Keyboard = "E", Gamepad = "ButtonR1" },
			Alternate = { Keyboard = "LeftAlt", Gamepad = "ButtonR3" },
			Body = { Keyboard = "LeftControl", Gamepad = "ButtonB" },
			Guard = { Keyboard = "Space", Gamepad = "ButtonA" },
			Grapple = { Keyboard = "F", Gamepad = "ButtonX" },
			Evade = { Keyboard = "LeftShift", Gamepad = "ButtonY" },
			Tap = { Keyboard = "T", Gamepad = "DPadDown" },
			Style = { Keyboard = "R", Gamepad = "DPadUp" },
		},
	},
	Rig = {
		Version = "CBRig_v1_Calibration",
		Pose = { ArmAnchorX = 1.02, ArmAnchorY = 1.5, LegAnchorX = 0.38, LegAnchorY = -0.2,
			ArmUpperLength = 0.9, ArmLowerLength = 1.1, LegUpperLength = 1.25, LegLowerLength = 1.375,
			WristOffset = 0.25, AnkleOffset = 0.275, ArmParentY = 1, MinDistance = 0.01,
			ReachMargin = 0.001, KODrop = 1.8, KOTilt = 1.35 }, Color = { 130, 130, 130 },
		GloveColor = { 45, 45, 45 }, ShortsColor = { 55, 55, 55 },
		StrideRate = 7, LegSwing = 0.28, GuardShoulder = 0.85, GuardElbow = 1.5, LowGuardShoulder = 0.2, LowGuardElbow = 1.2,
		HeadSize = { 0.9, 1.0, 0.9 }, UpperTorsoSize = { 1.6, 1.25, 0.75 },
		LowerTorsoSize = { 1.35, 0.7, 0.75 }, UpperArmSize = { 0.48, 0.9, 0.48 },
		ForearmSize = { 0.42, 0.85, 0.42 }, HandSize = { 0.5, 0.5, 0.6 },
		ThighSize = { 0.6, 1.25, 0.6 }, ShinSize = { 0.5, 1.1, 0.5 }, FootSize = { 0.55, 0.35, 0.95 },
	},
	Workspace = {
		Gravity = 196.2, GlobalWind = { 6, 0, 2 },
		-- Saved-place / Studio settings. Ordinary Scripts do not assign these.
		-- -400, not -100: falls off the Citadel bridge (y -20) and bastion reached -100 before their
		-- CampaignBounds catch could fire, so the engine deleted the body (Studio F20).
		StreamingEnabled = false, FallenPartsDestroyHeight = -400,
	},
	Lighting = {
		LightingStyle = "Realistic", PrioritizeLightingQuality = true,
		-- Golden-hour shrine above the cloud sea; biome clients use EnvironmentProfiles.
		Brightness = 2, ClockTime = 17 + 40 / 60, GeographicLatitude = 24,
		Ambient = { 42, 38, 37 }, OutdoorAmbient = { 80, 75, 70 },
		ColorShiftTop = { 255, 225, 185 }, ColorShiftBottom = { 24, 28, 38 },
		EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 1,
		GlobalShadows = true, ShadowSoftness = 0.25, ExposureCompensation = 0.08,
		-- Fog values are inert while an Atmosphere is present; kept as a sane fallback.
		FogColor = { 140, 130, 125 }, FogStart = 150, FogEnd = 2200,
		ColorCorrection = {
			Enabled = true, Brightness = 0.02, Contrast = 0.16,
			Saturation = 0.05, TintColor = { 255, 242, 230 },
		},
		Bloom = { Enabled = true, Intensity = 0.22, Size = 24, Threshold = 2.2 },
		DepthOfField = {
			Enabled = false, FarIntensity = 0, NearIntensity = 0,
			FocusDistance = 20, InFocusRadius = 50,
		},
		Atmosphere = {
			Density = 0.35, Offset = 0.1, Haze = 1.8, Glare = 0.45,
			Color = { 224, 191, 142 }, Decay = { 42, 38, 37 },
		},
		SunRays = { Enabled = true, Intensity = 0.25, Spread = 0.4 },
	},
	Materials = {
		Mat = { Material = "Concrete", Color = { 90, 90, 90 }, Reflectance = 0 },
		Fence = { Material = "Metal", Color = { 116, 116, 116 }, Reflectance = 0 },
		Padding = { Material = "SmoothPlastic", Color = { 66, 66, 66 }, Reflectance = 0 },
		Fixture = { Material = "Metal", Color = { 38, 38, 38 }, Reflectance = 0 },
		Diffuser = { Material = "Neon", Color = { 200, 200, 200 }, Reflectance = 0 },
		Void = { Material = "SmoothPlastic", Color = { 0, 0, 0 }, Reflectance = 0 },
		-- Concrete is an asset-free rough mat surrogate, not the final vinyl/canvas material.
	},
	Arena = {
		Sides = 8, AcrossFlats = 48, FloorThickness = 0.5, FenceHeight = 10,
		PostDiameter = 0.7, RailDiameter = 0.36, LowerRailHeight = 0.35,
		WireDiameter = 0.045, WireSpacing = 1.5, WireBottom = 0.5, WireTopInset = 0.35,
		WallThickness = 0.3, GateSide = 1, GateWidth = 3.5,
		GateBarDiameter = 0.16, GateLatchHeight = 4.2, GateLatchLength = 0.5,
		SpawnDistance = 12, SpawnSize = { 2, 0.2, 2 },
		VoidWidth = 160, VoidHeight = 80, VoidCenterY = 20, VoidWallThickness = 1,
		LightHeight = 18, LightOffset = 9, FixtureSize = { 4, 0.45, 1.4 },
		DiffuserSize = { 3.6, 0.08, 1.05 }, DiffuserGap = 0.02,
		SpotLight = { Brightness = 4.5, Range = 40, Angle = 100, Color = { 244, 244, 244 }, Shadows = true },
		GeometryEpsilon = 0.000001,
	},
}

-- Freeze all nested settings so consumers cannot silently mutate shared definitions.
local function deepFreeze(value: any)
	if type(value) ~= "table" or table.isfrozen(value) then
		return
	end
	for _, child in pairs(value) do
		deepFreeze(child)
	end
	table.freeze(value)
end
deepFreeze(Config)
return Config

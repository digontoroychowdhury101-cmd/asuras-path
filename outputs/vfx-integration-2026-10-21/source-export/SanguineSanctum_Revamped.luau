-- =============================================================================
-- THE SANGUINE SANCTUM: DEFINITIVE MASTER ELDEN RING COMBAT & ARENA ENGINE
-- Location: StarterPlayer > StarterPlayerScripts > LocalScript
--
-- REVAMP NOTES:
--   1. VFX: Layered crescents, fracture lightning, impact shock rings, ground cracks,
--      particles, dust, debris, camera shake, hit flashes, phase ascension and dissolve.
--   2. BOSS ASSEMBLY: Torso is the PrimaryPart; armour and blade are welded to it.
--   3. TELEGRAPHS: Boss attacks use radial rune telegraphs rather than solid neon discs.
--   4. COMBAT READABILITY: Front-cone attack checks, timed parry [T], and restart-safe AI.
--   5. This remains a local prototype; public multiplayer needs server-owned combat.
--
-- CONTROLS:
--   [Q] / [LeftAlt]        : Dodge Roll (0.42s Invincibility Frames & Motion Blur)
--   [Left Click] / [E]     : Spectral Light Slash (3-Hit Combo Chain)
--   [R]                    : Heavy Sanguine Piercing Thrust (Double Damage)
--   [T]                    : Timed Parry (press as the boss attack connects)
--   [F]                    : Instant Encounter Reset
-- =============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local VFX = require(ReplicatedStorage:WaitForChild("SanguineVFX_Overhaul"))
VFX.Init("High")

--------------------------------------------------------------------------------
-- 1. THEMATIC PALETTE & ARENA COORDINATES
--------------------------------------------------------------------------------
local PALETTE = {
	BasaltDark      = Color3.fromRGB(24, 22, 28),
	BasaltLight     = Color3.fromRGB(58, 52, 60),
	WeatheredStone  = Color3.fromRGB(92, 86, 90),
	BloodDeep       = Color3.fromRGB(110, 8, 12),
	BloodCrimson    = Color3.fromRGB(220, 20, 25),
	BloodflameCore  = Color3.fromRGB(255, 75, 25),
	MoltenGold      = Color3.fromRGB(255, 205, 75),
	TorchFire       = Color3.fromRGB(255, 160, 50),
	IgnitionWhite   = Color3.fromRGB(255, 252, 245),
	RustedMetal     = Color3.fromRGB(75, 48, 40),
	FogGold         = Color3.fromRGB(225, 180, 110),
	TelegraphRed    = Color3.fromRGB(255, 30, 40),
	StaminaGreen    = Color3.fromRGB(50, 190, 80),
	FPBlue          = Color3.fromRGB(45, 130, 245),
	HPBarRed        = Color3.fromRGB(205, 25, 25),
	LagAmber        = Color3.fromRGB(235, 145, 35)
}

local ARENA_ORIGIN = Vector3.new(0, 10, 0)
local ARENA_RADIUS = 105
local BALCONY_POS  = ARENA_ORIGIN + Vector3.new(0, 4, -ARENA_RADIUS + 12)
local ARENA_CONTAINER = Instance.new("Folder")
ARENA_CONTAINER.Name = "SanguineSanctum_MasterInstance"
ARENA_CONTAINER.Parent = workspace

--------------------------------------------------------------------------------
-- 2. STATE REPOSITORY
--------------------------------------------------------------------------------
local PlayerStats = {
	MaxHP = 100,
	CurrentHP = 100,
	MaxFP = 80,
	CurrentFP = 80,
	MaxStamina = 100,
	CurrentStamina = 100,
	StaminaRegenRate = 36,
	RollCost = 20,
	AttackCost = 14,
	HeavyCost = 26,
	IsInvulnerable = false,
	IsRolling = false,
	IsParrying = false,
	ParryCost = 12,
	IsAttacking = false,
	GracePeriodActive = true,
	ComboStep = 1,
	LastAttackTime = 0,
	IsDead = false,
	HUD = nil
}

local BossEntity = {
	Model = nil,
	Root = nil,
	Sword = nil,
	Wings = {},
	MaxHP = 5500,
	CurrentHP = 5500,
	IsActive = false,
	IsAttacking = false,
	IsPhase2 = false,
	IsFlying = false,
	IsDead = false,
	HoverElevation = 38,
	FlightTime = 0,
	WingConn = nil,
	AIGeneration = 0
}

-- Forward Declarations
local triggerPhase2Transformation
local triggerBossDeath

--------------------------------------------------------------------------------
-- 3. LAYERED SOUND SYNTHESIZER
--------------------------------------------------------------------------------
local function playLayeredSound(soundType, parent)
	parent = parent or workspace
	local function emit(id, vol, pitch, duration)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = vol
		s.PlaybackSpeed = pitch
		s.RollOffMaxDistance = 350
		s.RollOffMinDistance = 20
		s.Parent = parent
		s:Play()
		Debris:AddItem(s, duration or 5)
		return s
	end

	if soundType == "SWING" then
		emit("rbxassetid://9114221580", 1.8, 0.8, 3)
	elseif soundType == "IMPACT" then
		emit("rbxassetid://138090596", 2.6, 0.7, 5)
		emit("rbxassetid://9114223171", 2.2, 0.85, 5)
	elseif soundType == "ROAR" then
		emit("rbxassetid://9069609200", 3.8, 0.75, 7)
	elseif soundType == "PHASE_TRANSITION" then
		emit("rbxassetid://9069609200", 4.2, 0.65, 8)
		emit("rbxassetid://9114223171", 3.5, 0.5, 8)
	elseif soundType == "METEOR" then
		emit("rbxassetid://138090596", 1.8, 1.4, 3)
	elseif soundType == "ROLL" then
		emit("rbxassetid://9114221580", 1.0, 1.5, 2)
	elseif soundType == "VICTORY" then
		emit("rbxassetid://9114223171", 4.0, 0.45, 12)
		emit("rbxassetid://138090596", 2.5, 0.5, 8)
	elseif soundType == "DEATH" then
		emit("rbxassetid://9114223171", 3.5, 0.4, 8)
	end
end

--------------------------------------------------------------------------------
-- 4. CENTRALIZED CAMERA TRAUMA (ONE CAMERA BIND, NO CUMULATIVE SHAKE)
--------------------------------------------------------------------------------
local function applyCameraTrauma(intensity, duration, frequency)
	VFX.CameraShake(intensity, duration, frequency)
end

--------------------------------------------------------------------------------
-- 5. PROCEDURAL PARTICLE FACTORY
--------------------------------------------------------------------------------
local function addEmitter(parent, cfg)
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = cfg.Rate or 40
	pe.Lifetime = cfg.Lifetime or NumberRange.new(1, 2)
	pe.Speed = cfg.Speed or NumberRange.new(5, 10)
	pe.SpreadAngle = cfg.SpreadAngle or Vector2.new(15, 15)
	pe.Color = cfg.Color or ColorSequence.new(PALETTE.BloodflameCore)
	pe.Size = cfg.Size or NumberSequence.new(1)
	pe.Transparency = cfg.Transparency or NumberSequence.new(0)
	pe.LightEmission = cfg.LightEmission or 0
	pe.LightInfluence = cfg.LightInfluence or 0
	pe.Acceleration = cfg.Acceleration or Vector3.zero
	pe.Drag = cfg.Drag or 0
	pe.LockedToPart = cfg.LockedToPart or false
	pe.Texture = cfg.Texture or "rbxasset://textures/particles/sparkles_main.dds"
	pe.Enabled = cfg.Enabled ~= false
	pe.Rotation = cfg.Rotation or NumberRange.new(-180, 180)
	pe.RotSpeed = cfg.RotSpeed or NumberRange.new(-180, 180)
	pe.Parent = parent
	return pe
end

--------------------------------------------------------------------------------
-- 6. ATMOSPHERE / POST FX (PRESERVES UNRELATED LIGHTING OBJECTS)
--------------------------------------------------------------------------------
local function setupAtmosphere()
	VFX.SetupEnvironment()
end

--------------------------------------------------------------------------------
-- 7. ARENA ARCHITECTURE WITH COMPREHENSIVE TORCH LIGHTING
--------------------------------------------------------------------------------
local function buildSanctumArena()
	ARENA_CONTAINER:ClearAllChildren()
	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Geometry"
	mapFolder.Parent = ARENA_CONTAINER

	-- Solid Foundation Bed
	local bed = Instance.new("Part")
	bed.Shape = Enum.PartType.Cylinder
	bed.Size = Vector3.new(6, ARENA_RADIUS * 2, ARENA_RADIUS * 2)
	bed.CFrame = CFrame.new(ARENA_ORIGIN) * CFrame.Angles(0, 0, math.rad(90))
	bed.Color = PALETTE.BasaltDark
	bed.Material = Enum.Material.Basalt
	bed.Anchored = true
	bed.CanCollide = true
	bed.Parent = mapFolder

	-- Concentric Flagstone Rings
	for tier = 1, 4 do
		local r = 24 + (tier * 18)
		local count = math.floor(r * 0.44)
		for i = 1, count do
			local angle = (math.pi * 2 / count) * i
			local pos = ARENA_ORIGIN + Vector3.new(math.cos(angle) * r, 3.1, math.sin(angle) * r)
			local slab = Instance.new("Part")
			slab.Size = Vector3.new(math.random(7, 12), 0.6, math.random(7, 11))
			slab.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(math.random(-2, 2)), angle, math.rad(math.random(-2, 2)))
			slab.Color = (math.random() > 0.4) and PALETTE.BasaltLight or PALETTE.WeatheredStone
			slab.Material = Enum.Material.Slate
			slab.Anchored = true
			slab.CanCollide = true
			slab.Parent = mapFolder
		end
	end

	-- 28 Gothic Columns with High-Intensity Warm Wall Torches
	local pCount = 28
	for i = 1, pCount do
		local angle = (math.pi * 2 / pCount) * i
		local colPos = ARENA_ORIGIN + Vector3.new(math.cos(angle) * (ARENA_RADIUS - 6), 0, math.sin(angle) * (ARENA_RADIUS - 6))
		local h = math.random(42, 68)

		local base = Instance.new("Part")
		base.Size = Vector3.new(9, 5, 9)
		base.CFrame = CFrame.new(colPos + Vector3.new(0, 5, 0))
		base.Color = PALETTE.BasaltDark
		base.Material = Enum.Material.Slate
		base.Anchored = true
		base.CanCollide = true
		base.Parent = mapFolder

		local shaft = Instance.new("Part")
		shaft.Shape = Enum.PartType.Cylinder
		shaft.Size = Vector3.new(h, 6.5, 6.5)
		shaft.CFrame = CFrame.new(colPos + Vector3.new(0, 5 + (h / 2), 0)) * CFrame.Angles(0, 0, math.rad(90))
		shaft.Color = PALETTE.WeatheredStone
		shaft.Material = Enum.Material.Slate
		shaft.Anchored = true
		shaft.CanCollide = true
		shaft.Parent = mapFolder

		-- Burning Torch Sconces (Illuminating the entire ring)
		local brazier = Instance.new("Part")
		brazier.Size = Vector3.new(3.5, 2, 3.5)
		brazier.CFrame = CFrame.new(colPos + Vector3.new(0, 16, 0), ARENA_ORIGIN) * CFrame.new(0, 0, -4.5)
		brazier.Color = PALETTE.RustedMetal
		brazier.Material = Enum.Material.CorrodedMetal
		brazier.Anchored = true
		brazier.CanCollide = false
		brazier.Parent = mapFolder

		local torchLight = Instance.new("PointLight")
		torchLight.Range = 45
		torchLight.Brightness = 5
		torchLight.Color = PALETTE.TorchFire
		torchLight.Shadows = true
		torchLight.Parent = brazier

		addEmitter(brazier, {
			Rate = 22,
			Lifetime = NumberRange.new(0.8, 1.6),
			Speed = NumberRange.new(3, 8),
			SpreadAngle = Vector2.new(15, 15),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, PALETTE.MoltenGold),
				ColorSequenceKeypoint.new(0.5, PALETTE.TorchFire),
				ColorSequenceKeypoint.new(1, PALETTE.BloodDeep)
			}),
			Size = NumberSequence.new(1.6, 0),
			LightEmission = 0.9,
			Acceleration = Vector3.new(0, 14, 0)
		})
	end

	-- Safe Elevated Entrance Balcony (Spawns the player securely)
	local balcony = Instance.new("Part")
	balcony.Name = "PlayerSpawnBalcony"
	balcony.Size = Vector3.new(34, 4, 24)
	balcony.CFrame = CFrame.new(BALCONY_POS)
	balcony.Color = PALETTE.BasaltDark
	balcony.Material = Enum.Material.Slate
	balcony.Anchored = true
	balcony.CanCollide = true
	balcony.Parent = mapFolder

	-- Golden Fog Gate
	local fogWall = Instance.new("Part")
	fogWall.Name = "GoldenFogWall"
	fogWall.Size = Vector3.new(28, 24, 1.5)
	fogWall.CFrame = CFrame.new(BALCONY_POS + Vector3.new(0, 12, -10))
	fogWall.Color = PALETTE.FogGold
	fogWall.Material = Enum.Material.ForceField
	fogWall.Transparency = 0.35
	fogWall.Anchored = true
	fogWall.CanCollide = true
	fogWall.Parent = mapFolder

	addEmitter(fogWall, {
		Rate = 75,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, PALETTE.FogGold),
			ColorSequenceKeypoint.new(1, PALETTE.TorchFire)
		}),
		Size = NumberSequence.new(2, 4),
		Transparency = NumberSequence.new(0.3, 1),
		LightEmission = 0.5
	})

	return BALCONY_POS + Vector3.new(0, 5, 2)
end

--------------------------------------------------------------------------------
-- 8. COMPREHENSIVE SOULS HUD SYSTEM
--------------------------------------------------------------------------------
local function initializeFullHUD()
	local existing = player:WaitForChild("PlayerGui"):FindFirstChild("EldenRing_MasterHUD")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "EldenRing_MasterHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player.PlayerGui

	-- Player Vitals
	local vitalFrame = Instance.new("Frame")
	vitalFrame.Size = UDim2.new(0.34, 0, 0.08, 0)
	vitalFrame.Position = UDim2.new(0.04, 0, 0.05, 0)
	vitalFrame.BackgroundTransparency = 1
	vitalFrame.Parent = gui

	local function makeStatBar(yOffset, height, color, initialRatio)
		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(initialRatio, 0, height, 0)
		bg.Position = UDim2.new(0, 0, yOffset, 0)
		bg.BackgroundColor3 = Color3.fromRGB(15, 12, 14)
		bg.BorderSizePixel = 0
		bg.Parent = vitalFrame

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(1, 0, 1, 0)
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0
		fill.Parent = bg

		local stroke = Instance.new("UIStroke")
		stroke.Color = PALETTE.MoltenGold
		stroke.Thickness = 1
		stroke.Transparency = 0.4
		stroke.Parent = bg

		return fill
	end

	local hpFill = makeStatBar(0, 0.28, PALETTE.HPBarRed, 1.0)
	local fpFill = makeStatBar(0.35, 0.22, PALETTE.FPBlue, 0.75)
	local stFill = makeStatBar(0.64, 0.22, PALETTE.StaminaGreen, 0.88)

	-- Grace Period Indicator
	local graceLabel = Instance.new("TextLabel")
	graceLabel.Name = "GraceIndicator"
	graceLabel.Size = UDim2.new(0.34, 0, 0.03, 0)
	graceLabel.Position = UDim2.new(0.04, 0, 0.135, 0)
	graceLabel.BackgroundTransparency = 1
	graceLabel.Font = Enum.Font.Garamond
	graceLabel.Text = "[ GRACE ACTIVE: INVULNERABLE ]"
	graceLabel.TextColor3 = PALETTE.MoltenGold
	graceLabel.TextSize = 14
	graceLabel.TextXAlignment = Enum.TextXAlignment.Left
	graceLabel.Parent = gui

	-- Dialogue Subtitles Box
	local dialogueLabel = Instance.new("TextLabel")
	dialogueLabel.Name = "BossDialogue"
	dialogueLabel.Size = UDim2.new(0.8, 0, 0.06, 0)
	dialogueLabel.Position = UDim2.new(0.1, 0, 0.74, 0)
	dialogueLabel.BackgroundTransparency = 1
	dialogueLabel.Font = Enum.Font.Garamond
	dialogueLabel.Text = ""
	dialogueLabel.TextColor3 = Color3.fromRGB(245, 240, 230)
	dialogueLabel.TextSize = 22
	dialogueLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	dialogueLabel.TextStrokeTransparency = 0.2
	dialogueLabel.TextTransparency = 1
	dialogueLabel.Parent = gui

	-- Boss Health Bar
	local bossFrame = Instance.new("Frame")
	bossFrame.Size = UDim2.new(0.58, 0, 0.1, 0)
	bossFrame.Position = UDim2.new(0.21, 0, 0.84, 0)
	bossFrame.BackgroundTransparency = 1
	bossFrame.Visible = false
	bossFrame.Parent = gui

	local bossName = Instance.new("TextLabel")
	bossName.Size = UDim2.new(1, 0, 0.35, 0)
	bossName.Position = UDim2.new(0, 0, -0.4, 0)
	bossName.BackgroundTransparency = 1
	bossName.Font = Enum.Font.Antique
	bossName.Text = "MOHGWYN CRUCIBLE WARLORD"
	bossName.TextColor3 = Color3.fromRGB(240, 230, 220)
	bossName.TextSize = 22
	bossName.TextXAlignment = Enum.TextXAlignment.Left
	bossName.TextStrokeColor3 = Color3.fromRGB(15, 5, 5)
	bossName.TextStrokeTransparency = 0.2
	bossName.Parent = bossFrame

	local bossSub = Instance.new("TextLabel")
	bossSub.Name = "BossSubtitle"
	bossSub.Size = UDim2.new(1, 0, 0.25, 0)
	bossSub.Position = UDim2.new(0, 0, 0.95, 0)
	bossSub.BackgroundTransparency = 1
	bossSub.Font = Enum.Font.Garamond
	bossSub.Text = "Lord of the Sunken Sanguine Sanctum"
	bossSub.TextColor3 = PALETTE.MoltenGold
	bossSub.TextSize = 14
	bossSub.TextXAlignment = Enum.TextXAlignment.Left
	bossSub.TextTransparency = 0.3
	bossSub.Parent = bossFrame

	local bossBarBg = Instance.new("Frame")
	bossBarBg.Size = UDim2.new(1, 0, 0.2, 0)
	bossBarBg.Position = UDim2.new(0, 0, 0.05, 0)
	bossBarBg.BackgroundColor3 = Color3.fromRGB(15, 12, 14)
	bossBarBg.BorderSizePixel = 0
	bossBarBg.Parent = bossFrame

	local bossLagFill = Instance.new("Frame")
	bossLagFill.Size = UDim2.new(1, 0, 1, 0)
	bossLagFill.BackgroundColor3 = PALETTE.LagAmber
	bossLagFill.BorderSizePixel = 0
	bossLagFill.Parent = bossBarBg

	local bossHpFill = Instance.new("Frame")
	bossHpFill.Size = UDim2.new(1, 0, 1, 0)
	bossHpFill.BackgroundColor3 = PALETTE.HPBarRed
	bossHpFill.BorderSizePixel = 0
	bossHpFill.Parent = bossBarBg

	local bossStroke = Instance.new("UIStroke")
	bossStroke.Color = PALETTE.MoltenGold
	bossStroke.Thickness = 1.2
	bossStroke.Transparency = 0.35
	bossStroke.Parent = bossBarBg

	-- Phase II Banner
	local phaseBanner = Instance.new("TextLabel")
	phaseBanner.Name = "PhaseBanner"
	phaseBanner.Size = UDim2.new(1, 0, 0.08, 0)
	phaseBanner.Position = UDim2.new(0, 0, 0.42, 0)
	phaseBanner.BackgroundTransparency = 1
	phaseBanner.Font = Enum.Font.Antique
	phaseBanner.Text = "PHASE II: LORD OF THE SANGUINE SKIES"
	phaseBanner.TextColor3 = PALETTE.MoltenGold
	phaseBanner.TextSize = 28
	phaseBanner.TextTransparency = 1
	phaseBanner.Parent = gui

	-- "GREAT ENEMY FELLED" Banner
	local victoryBanner = Instance.new("TextLabel")
	victoryBanner.Name = "VictoryBanner"
	victoryBanner.Size = UDim2.new(1, 0, 0.12, 0)
	victoryBanner.Position = UDim2.new(0, 0, 0.44, 0)
	victoryBanner.BackgroundTransparency = 1
	victoryBanner.Font = Enum.Font.Antique
	victoryBanner.Text = "GREAT ENEMY FELLED"
	victoryBanner.TextColor3 = PALETTE.MoltenGold
	victoryBanner.TextSize = 42
	victoryBanner.TextTransparency = 1
	victoryBanner.Parent = gui

	-- "YOU DIED" Banner
	local deathBanner = Instance.new("TextLabel")
	deathBanner.Name = "DeathBanner"
	deathBanner.Size = UDim2.new(1, 0, 0.14, 0)
	deathBanner.Position = UDim2.new(0, 0, 0.43, 0)
	deathBanner.BackgroundTransparency = 1
	deathBanner.Font = Enum.Font.Antique
	deathBanner.Text = "YOU DIED"
	deathBanner.TextColor3 = Color3.fromRGB(180, 10, 15)
	deathBanner.TextSize = 48
	deathBanner.TextTransparency = 1
	deathBanner.Parent = gui

	PlayerStats.HUD = {
		HPFill = hpFill,
		StaminaFill = stFill,
		GraceIndicator = graceLabel,
		BossFrame = bossFrame,
		BossHPFill = bossHpFill,
		BossLagFill = bossLagFill,
		BossSubtitle = bossSub,
		Dialogue = dialogueLabel,
		PhaseBanner = phaseBanner,
		VictoryBanner = victoryBanner,
		DeathBanner = deathBanner
	}
end

local function showDialogue(text, duration)
	if not PlayerStats.HUD or not PlayerStats.HUD.Dialogue then return end
	local lbl = PlayerStats.HUD.Dialogue
	lbl.Text = text
	TweenService:Create(lbl, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
	task.delay(duration or 3.2, function()
		TweenService:Create(lbl, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()
	end)
end

--------------------------------------------------------------------------------
-- 9. PLAYER COMBAT CONTROLLER (DODGE, I-FRAMES & COMBOS)
--------------------------------------------------------------------------------
local function executeDodgeRoll()
	if PlayerStats.IsDead or PlayerStats.IsRolling or PlayerStats.CurrentStamina < PlayerStats.RollCost then
		return
	end

	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end

	PlayerStats.CurrentStamina = math.clamp(PlayerStats.CurrentStamina - PlayerStats.RollCost, 0, PlayerStats.MaxStamina)
	PlayerStats.IsRolling = true
	PlayerStats.IsInvulnerable = true

	local moveDir = hum.MoveDirection
	if moveDir.Magnitude < 0.1 then
		moveDir = -hrp.CFrame.LookVector
	else
		moveDir = moveDir.Unit
	end

	playLayeredSound("ROLL", hrp)

	local rollSpeed = 62
	local rollDuration = 0.42
	VFX.Dodge(char, hrp, moveDir, rollDuration)
	local startTime = os.clock()

	local rollConn
	rollConn = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed < rollDuration then
			local progress = elapsed / rollDuration
			local decay = (1 - progress) ^ 1.5
			hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * rollSpeed * decay, hrp.AssemblyLinearVelocity.Y, moveDir.Z * rollSpeed * decay)
		else
			rollConn:Disconnect()
		end
	end)

	task.delay(0.40, function()
		PlayerStats.IsInvulnerable = false
	end)
	task.delay(0.48, function()
		PlayerStats.IsRolling = false
	end)
end

local function executePlayerAttack(isHeavy)
	if PlayerStats.IsDead or PlayerStats.IsAttacking or PlayerStats.IsRolling then return end
	local cost = isHeavy and PlayerStats.HeavyCost or PlayerStats.AttackCost
	if PlayerStats.CurrentStamina < cost then return end

	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local hrp = char.HumanoidRootPart

	PlayerStats.IsAttacking = true
	PlayerStats.CurrentStamina = math.clamp(PlayerStats.CurrentStamina - cost, 0, PlayerStats.MaxStamina)

	local now = os.clock()
	if now - PlayerStats.LastAttackTime > 1.2 then
		PlayerStats.ComboStep = 1
	end
	PlayerStats.LastAttackTime = now

	playLayeredSound("SWING", hrp)

	VFX.Slash(hrp, PlayerStats.ComboStep, isHeavy)

	if BossEntity.IsActive and not BossEntity.IsDead and BossEntity.Root then
		local toBoss = BossEntity.Root.Position - hrp.Position
		local horizontalToBoss = Vector3.new(toBoss.X, 0, toBoss.Z)
		local horizontalFacing = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		local facingDot = 0
		if horizontalToBoss.Magnitude > 0.05 and horizontalFacing.Magnitude > 0.05 then
			facingDot = horizontalFacing.Unit:Dot(horizontalToBoss.Unit)
		end
		local hitRange = isHeavy and 27 or 21
		if horizontalToBoss.Magnitude <= hitRange and facingDot >= -0.12 then
			VFX.BossHit(BossEntity.Root.Position, isHeavy)
			local dmg = isHeavy and math.random(240, 340) or math.random(120, 170)
			BossEntity.CurrentHP = math.clamp(BossEntity.CurrentHP - dmg, 0, BossEntity.MaxHP)

			if BossEntity.CurrentHP <= (BossEntity.MaxHP * 0.5) and not BossEntity.IsPhase2 then
				task.spawn(function()
					triggerPhase2Transformation()
				end)
			end

			if BossEntity.CurrentHP <= 0 and not BossEntity.IsDead then
				task.spawn(function()
					triggerBossDeath()
				end)
			end

			if PlayerStats.HUD then
				local ratio = BossEntity.CurrentHP / BossEntity.MaxHP
				PlayerStats.HUD.BossHPFill.Size = UDim2.new(ratio, 0, 1, 0)
				TweenService:Create(PlayerStats.HUD.BossLagFill, TweenInfo.new(0.65, Enum.EasingStyle.Sine), {
					Size = UDim2.new(ratio, 0, 1, 0)
				}):Play()
			end
		end
	end

	PlayerStats.ComboStep = (PlayerStats.ComboStep % 3) + 1
	task.delay(isHeavy and 0.55 or 0.32, function()
		PlayerStats.IsAttacking = false
	end)
end


local function executeParry()
	if PlayerStats.IsDead or PlayerStats.IsRolling or PlayerStats.IsAttacking or PlayerStats.IsParrying then
		return
	end
	if PlayerStats.CurrentStamina < PlayerStats.ParryCost then return end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end

	PlayerStats.CurrentStamina = math.clamp(PlayerStats.CurrentStamina - PlayerStats.ParryCost, 0, PlayerStats.MaxStamina)
	PlayerStats.IsParrying = true
	VFX.Parry(hrp.Position + hrp.CFrame.LookVector * 2.5, hrp.CFrame.LookVector)
	playLayeredSound("SWING", hrp)

	-- The window is deliberately short. Damage is intercepted by damagePlayer below.
	task.delay(0.28, function()
		PlayerStats.IsParrying = false
	end)
end

--------------------------------------------------------------------------------
-- 10. DAMAGE RECEIVER & PLAYER DEFEAT
--------------------------------------------------------------------------------
local function damagePlayer(amount, knockbackDir)
	if PlayerStats.IsDead or PlayerStats.GracePeriodActive then return end

	if PlayerStats.IsParrying then
		PlayerStats.IsParrying = false
		local parryChar = player.Character
		local parryRoot = parryChar and parryChar:FindFirstChild("HumanoidRootPart")
		if parryRoot then
			VFX.PerfectParry(parryRoot.Position + parryRoot.CFrame.LookVector * 2.6, parryRoot.CFrame.LookVector)
		end
		if BossEntity.Root and BossEntity.Root.Parent and not BossEntity.IsDead then
			VFX.BossHit(BossEntity.Root.Position, true, true)
			BossEntity.CurrentHP = math.clamp(BossEntity.CurrentHP - 180, 0, BossEntity.MaxHP)
			if PlayerStats.HUD and PlayerStats.HUD.BossHPFill then
				local ratio = BossEntity.CurrentHP / BossEntity.MaxHP
				PlayerStats.HUD.BossHPFill.Size = UDim2.new(ratio, 0, 1, 0)
				TweenService:Create(PlayerStats.HUD.BossLagFill, TweenInfo.new(0.22, Enum.EasingStyle.Quad), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
			end
			if BossEntity.CurrentHP <= 0 then
				task.spawn(triggerBossDeath)
			elseif BossEntity.CurrentHP <= BossEntity.MaxHP * 0.5 and not BossEntity.IsPhase2 then
				task.spawn(triggerPhase2Transformation)
			end
		end
		return
	end

	if PlayerStats.IsInvulnerable then return end
	PlayerStats.CurrentHP = math.clamp(PlayerStats.CurrentHP - amount, 0, PlayerStats.MaxHP)
	applyCameraTrauma(2.0, 1.2, 42)
	local hitChar = player.Character
	local hitRoot = hitChar and hitChar:FindFirstChild("HumanoidRootPart")
	if hitRoot then VFX.BossHit(hitRoot.Position, false) end

	local cc = Lighting:FindFirstChild("Sanctum_CC")
	if cc then
		cc.TintColor = Color3.fromRGB(255, 95, 95)
		TweenService:Create(cc, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TintColor = Color3.fromRGB(255, 235, 225)
		}):Play()
	end

	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") and knockbackDir then
		char.HumanoidRootPart.AssemblyLinearVelocity = knockbackDir * 50 + Vector3.new(0, 28, 0)
	end

	if PlayerStats.CurrentHP <= 0 and not PlayerStats.IsDead then
		PlayerStats.IsDead = true
		playLayeredSound("DEATH", char and char:FindFirstChild("HumanoidRootPart"))
		applyCameraTrauma(2.5, 3.5, 20)

		if char and char:FindFirstChildOfClass("Humanoid") then
			char:FindFirstChildOfClass("Humanoid").PlatformStand = true
		end

		if PlayerStats.HUD and PlayerStats.HUD.DeathBanner then
			local db = PlayerStats.HUD.DeathBanner
			TweenService:Create(db, TweenInfo.new(2.0, Enum.EasingStyle.Sine), {
				TextTransparency = 0,
				Position = UDim2.new(0, 0, 0.40, 0)
			}):Play()
		end
	end
end

--------------------------------------------------------------------------------
-- 11. BOSS RIG CONSTRUCTOR (HIGH VISIBILITY CRUCIBLE WARLORD)
--------------------------------------------------------------------------------
local function constructCrucibleBoss(rootCFrame, container)
	local boss = Instance.new("Model")
	boss.Name = "MohgwynCrucibleLord"
	boss.Parent = container

	local function addArmor(size, offset, col, mat)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = rootCFrame * offset
		p.Color = col or PALETTE.BasaltDark
		p.Material = mat or Enum.Material.Basalt
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = true
		p.Parent = boss
		return p
	end

	local torso = addArmor(Vector3.new(7, 10, 4.5), CFrame.new(0, 11, 0), PALETTE.BasaltDark, Enum.Material.Metal)
	addArmor(Vector3.new(2.5, 6, 1), CFrame.new(0, 11, 2.3), PALETTE.BloodflameCore, Enum.Material.Neon)
	addArmor(Vector3.new(4, 4.5, 4), CFrame.new(0, 18, 0), PALETTE.BasaltDark, Enum.Material.Slate)
	addArmor(Vector3.new(3, 0.6, 1.2), CFrame.new(0, 18, 1.8), PALETTE.IgnitionWhite, Enum.Material.Neon)

	-- Great Horns
	addArmor(Vector3.new(1.2, 5.5, 1.2), CFrame.new(-2.6, 20.5, -0.6) * CFrame.Angles(0, 0, math.rad(38)), PALETTE.BasaltLight, Enum.Material.CorrodedMetal)
	addArmor(Vector3.new(1.2, 5.5, 1.2), CFrame.new(2.6, 20.5, -0.6) * CFrame.Angles(0, 0, math.rad(-38)), PALETTE.BasaltLight, Enum.Material.CorrodedMetal)

	-- 32-Foot Greatsword
	local swordBlade = addArmor(Vector3.new(3.2, 28, 0.9), CFrame.new(7.5, 26, -4) * CFrame.Angles(math.rad(-28), 0, math.rad(-10)), PALETTE.BasaltDark, Enum.Material.Metal)
	local swordEdge = addArmor(Vector3.new(1.4, 27.5, 1.1), CFrame.new(7.5, 26, -4) * CFrame.Angles(math.rad(-28), 0, math.rad(-10)), PALETTE.BloodflameCore, Enum.Material.Neon)

	-- Dedicated Boss Aura Light (Ensures boss is brightly lit anywhere in the arena)
	local bossLight = Instance.new("PointLight")
	bossLight.Range = 45
	bossLight.Brightness = 8
	bossLight.Color = PALETTE.BloodflameCore
	bossLight.Shadows = true
	bossLight.Parent = torso

	-- 6 Wing Bones
	local wings = {}
	for i = 1, 6 do
		local isRight = (i % 2 == 0)
		local tier = math.ceil(i / 2)
		local side = isRight and 1 or -1
		local length = 14 + (tier * 3.5)

		local bone = addArmor(
			Vector3.new(1.3, length, 1.3),
			CFrame.new(side * 2.5, 14 + (tier * 2.5), -2.2) * CFrame.Angles(0, 0, math.rad(side * 12)),
			PALETTE.BasaltDark,
			Enum.Material.CorrodedMetal
		)

		local wingAura = addEmitter(bone, {
			Rate = 60,
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(8, 16),
			SpreadAngle = Vector2.new(35, 35),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, PALETTE.BloodflameCore),
				ColorSequenceKeypoint.new(0.6, PALETTE.BloodCrimson),
				ColorSequenceKeypoint.new(1, PALETTE.BasaltDark)
			}),
			Size = NumberSequence.new(2.5, 0),
			LightEmission = 0.9,
			Enabled = false
		})

		table.insert(wings, {bone = bone, side = side, tier = tier, aura = wingAura, baseLength = length})
	end

	-- Attach the armour/sword to the torso. The previous version left every part Anchored,
	-- so moving the torso made the boss separate into floating pieces. Wing bones remain
	-- individually anchored because Phase II animates them procedurally.
	local wingPartLookup = {}
	for _, wing in ipairs(wings) do
		wingPartLookup[wing.bone] = true
	end

	for _, part in ipairs(boss:GetChildren()) do
		if part:IsA("BasePart") and part ~= torso then
			if wingPartLookup[part] then
				part.Anchored = true
			else
				part.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Name = "BossAssemblyWeld"
				weld.Part0 = torso
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	torso.Anchored = true
	boss.PrimaryPart = torso
	VFX.AttachBossAura(torso, PALETTE.BloodflameCore)

	local highlight = Instance.new("Highlight")
	highlight.FillColor = PALETTE.BloodDeep
	highlight.OutlineColor = PALETTE.MoltenGold
	highlight.FillTransparency = 0.8
	highlight.OutlineTransparency = 0
	highlight.Adornee = boss
	highlight.Parent = boss

	BossEntity.Model = boss
	BossEntity.Root = torso
	BossEntity.Sword = swordBlade
	BossEntity.Wings = wings
	return boss
end

--------------------------------------------------------------------------------
-- 12. TELEGRAPHED ATTACK VISUALIZERS
--------------------------------------------------------------------------------
local function spawnAttackTelegraph(cf, size, duration)
	return VFX.GroundTelegraph(cf.Position, size * 0.5, duration, "Bloodflame")
end

--------------------------------------------------------------------------------
-- 13. PHASE 2 TRANSFORMATION METAMORPHOSIS
--------------------------------------------------------------------------------
triggerPhase2Transformation = function()
	if BossEntity.IsPhase2 then return end
	BossEntity.IsPhase2 = true
	BossEntity.IsAttacking = true
	BossEntity.IsFlying = true

	showDialogue("Dearest Miquella... Behold the ascension of the Formless Mother!", 4.0)
	playLayeredSound("PHASE_TRANSITION", BossEntity.Root)
	VFX.PhaseTransition(BossEntity.Root, BossEntity.Model)

	local cc = Lighting:FindFirstChild("Sanctum_CC")
	if cc then
		cc.TintColor = Color3.fromRGB(255, 120, 120)
		cc.Contrast = 0.4
	end

	if PlayerStats.HUD and PlayerStats.HUD.PhaseBanner then
		local b = PlayerStats.HUD.PhaseBanner
		PlayerStats.HUD.BossSubtitle.Text = "Ascended God of the Sanguine Skies"
		PlayerStats.HUD.BossSubtitle.TextColor3 = PALETTE.BloodflameCore

		TweenService:Create(b, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			TextTransparency = 0,
			Position = UDim2.new(0, 0, 0.36, 0)
		}):Play()

		task.delay(3.2, function()
			TweenService:Create(b, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {
				TextTransparency = 1,
				Position = UDim2.new(0, 0, 0.30, 0)
			}):Play()
		end)
	end

	for _, w in ipairs(BossEntity.Wings) do
		w.aura.Enabled = true
		w.aura.Rate = 120
		w.bone.Color = PALETTE.BloodflameCore
		w.bone.Material = Enum.Material.Neon
	end

	local bossP = BossEntity.Root.Position
	local targetFlyCF = CFrame.new(bossP.X, BossEntity.HoverElevation, bossP.Z)
	local flyTween = TweenService:Create(BossEntity.Root, TweenInfo.new(2.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		CFrame = targetFlyCF
	})
	flyTween:Play()
	flyTween.Completed:Wait()

	BossEntity.WingConn = RunService.RenderStepped:Connect(function(dt)
		if not BossEntity.Root or not BossEntity.Root.Parent then return end
		BossEntity.FlightTime = BossEntity.FlightTime + dt

		local flapCycle = math.sin(BossEntity.FlightTime * 6.5)
		for _, w in ipairs(BossEntity.Wings) do
			local wingSpread = math.rad(w.side * (45 + (flapCycle * 25)))
			local wingPitch = math.rad(flapCycle * 14)
			w.bone.CFrame = BossEntity.Root.CFrame * CFrame.new(w.side * 3.5, 4 + (w.tier * 2.2), -2.2) * CFrame.Angles(wingPitch, 0, wingSpread)
		end
	end)

	task.wait(1.0)
	BossEntity.IsAttacking = false
end

--------------------------------------------------------------------------------
-- 14. PHASE 2 ATTACKS: METEOR RAIN & SKY DIVEBOMB (WITH VISIBLE TELEGRAPHS)
--------------------------------------------------------------------------------
local function executeBloodflameRain()
	BossEntity.IsAttacking = true
	showDialogue("Rain upon them, Sanguine Ichor!", 3.0)
	playLayeredSound("ROAR", BossEntity.Root)
	applyCameraTrauma(1.8, 3.5, 25)

	VFX.GroundTelegraph(ARENA_ORIGIN + Vector3.new(0, 80, 0), 42, 3.5, "Meteor")

	for i = 1, 24 do
		task.delay(i * 0.16, function()
			local targetSpot
			local char = player.Character
			if math.random() > 0.4 and char and char:FindFirstChild("HumanoidRootPart") then
				targetSpot = char.HumanoidRootPart.Position + Vector3.new(math.random(-16, 16), 0, math.random(-16, 16))
			else
				local ang = math.rad(math.random(0, 360))
				local dist = math.random(10, ARENA_RADIUS - 16)
				targetSpot = ARENA_ORIGIN + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
			end
			targetSpot = Vector3.new(targetSpot.X, 13.2, targetSpot.Z)

			-- 1.2s Clear Ground Telegraph Ring
			spawnAttackTelegraph(CFrame.new(targetSpot), 18, 1.2)

			task.delay(1.1, function()
				VFX.MeteorFall(Vector3.new(targetSpot.X, 80, targetSpot.Z), targetSpot, 0.35, 14)
				task.wait(0.37)
				playLayeredSound("METEOR", workspace)

				if char and char:FindFirstChild("HumanoidRootPart") then
					local dist = (char.HumanoidRootPart.Position - targetSpot).Magnitude
					if dist <= 12 then
						damagePlayer(25, (char.HumanoidRootPart.Position - targetSpot).Unit)
					end
				end
			end)
		end)
	end

	task.wait(5.8)
	BossEntity.IsAttacking = false
end

local function executeSkyDivebomb()
	BossEntity.IsAttacking = true
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		BossEntity.IsAttacking = false
		return
	end

	local targetPos = char.HumanoidRootPart.Position

	-- 1.3s Visible Ground Landing Marker
	local markerPos = Vector3.new(targetPos.X, 13.2, targetPos.Z)
	spawnAttackTelegraph(CFrame.new(markerPos), 45, 1.3)

	playLayeredSound("SWING", BossEntity.Root)
	local recoilCF = CFrame.new(BossEntity.Root.Position + Vector3.new(0, 16, 0), targetPos)
	TweenService:Create(BossEntity.Root, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		CFrame = recoilCF
	}):Play()
	task.wait(0.8)

	playLayeredSound("IMPACT", BossEntity.Root)
	local diveTween = TweenService:Create(BossEntity.Root, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(markerPos.X, 22, markerPos.Z)
	})
	diveTween:Play()
	diveTween.Completed:Wait()

	VFX.Impact(markerPos, 40, "Divebomb")

	local hitDist = (char.HumanoidRootPart.Position - markerPos).Magnitude
	if hitDist <= 40 then
		damagePlayer(45, (char.HumanoidRootPart.Position - markerPos).Unit)
	end

	task.wait(0.9)
	local reAscend = TweenService:Create(BossEntity.Root, TweenInfo.new(1.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut), {
		CFrame = CFrame.new(markerPos.X, BossEntity.HoverElevation, markerPos.Z)
	})
	reAscend:Play()
	reAscend.Completed:Wait()

	BossEntity.IsAttacking = false
end

--------------------------------------------------------------------------------
-- 15. BOSS DEFEAT & "GREAT ENEMY FELLED" CUTSCENE
--------------------------------------------------------------------------------
triggerBossDeath = function()
	if BossEntity.IsDead then return end
	BossEntity.IsDead = true
	BossEntity.IsAttacking = true

	if BossEntity.WingConn then
		BossEntity.WingConn:Disconnect()
	end

	showDialogue("The dynasty... burns to ash...", 4.0)
	playLayeredSound("VICTORY", BossEntity.Root)
	VFX.BossDeath(BossEntity.Model, BossEntity.Root.Position)

	local fallTween = TweenService:Create(BossEntity.Root, TweenInfo.new(2.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(BossEntity.Root.Position.X, 14, BossEntity.Root.Position.Z) * CFrame.Angles(math.rad(-35), 0, 0)
	})
	fallTween:Play()

	task.delay(2.0, function()
		if PlayerStats.HUD and PlayerStats.HUD.VictoryBanner then
			local vb = PlayerStats.HUD.VictoryBanner
			TweenService:Create(vb, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {
				TextTransparency = 0,
				Position = UDim2.new(0, 0, 0.38, 0)
			}):Play()
		end

		local fog = ARENA_CONTAINER:FindFirstChild("Geometry") and ARENA_CONTAINER.Geometry:FindFirstChild("GoldenFogWall")
		if fog then
			TweenService:Create(fog, TweenInfo.new(3.0, Enum.EasingStyle.Sine), {
				Transparency = 1
			}):Play()
			task.delay(3.0, function()
				fog:Destroy()
			end)
		end
	end)
end

--------------------------------------------------------------------------------
-- 16. MAIN BOSS COMBAT AI LOOP (WITH WINDUPS & TELEGRAPHS)
--------------------------------------------------------------------------------
local function runBossAI()
	local generation = BossEntity.AIGeneration
	task.spawn(function()
		while generation == BossEntity.AIGeneration do
			task.wait(0.2)
			if generation ~= BossEntity.AIGeneration then break end
			if BossEntity.IsActive and not BossEntity.IsAttacking and not BossEntity.IsDead and BossEntity.Root then
				local char = player.Character
				if char and char:FindFirstChild("HumanoidRootPart") then
					local targetP = char.HumanoidRootPart.Position
					local bossP = BossEntity.Root.Position

					if not BossEntity.IsPhase2 then
						-- Phase 1 Ground Tracking
						local targetLook = CFrame.new(bossP, Vector3.new(targetP.X, bossP.Y, targetP.Z))
						BossEntity.Model:PivotTo(BossEntity.Root.CFrame:Lerp(targetLook, 0.1))

						local dist = (targetP - bossP).Magnitude
						if dist > 32 then
							-- Step forward
							local stepDir = (targetP - bossP).Unit
							BossEntity.Model:PivotTo(BossEntity.Root.CFrame + Vector3.new(stepDir.X * 0.5, 0, stepDir.Z * 0.5))
						else
							-- Telegraphed Melee Strike
							BossEntity.IsAttacking = true

							-- Project 1.0s danger zone on the ground in front of boss
							local attackCenter = bossP + (BossEntity.Root.CFrame.LookVector * 18)
							spawnAttackTelegraph(CFrame.new(attackCenter.X, 13.2, attackCenter.Z), 36, 1.0)

							playLayeredSound("SWING", BossEntity.Root)
							task.wait(0.9) -- Clear windup window for player to dodge roll

							playLayeredSound("IMPACT", BossEntity.Root)
							VFX.Impact(Vector3.new(attackCenter.X, 13.2, attackCenter.Z), 20, "SwordImpact")

							local playerRoot = char:FindFirstChild("HumanoidRootPart")
							local attackGround = Vector3.new(attackCenter.X, 13.2, attackCenter.Z)
							if playerRoot then
								local playerGround = Vector3.new(playerRoot.Position.X, 13.2, playerRoot.Position.Z)
								if (playerGround - attackGround).Magnitude <= 18 then
									damagePlayer(30, (playerRoot.Position - bossP).Unit)
								end
							end

							task.wait(1.5)
							BossEntity.IsAttacking = false
						end
					else
						-- Phase 2 Flight
						local targetLook = CFrame.new(bossP, Vector3.new(targetP.X, bossP.Y, targetP.Z))
						local bobElevation = BossEntity.HoverElevation + (math.sin(BossEntity.FlightTime * 3) * 2.5)
						local flightCFrame = CFrame.new(bossP.X, bobElevation, bossP.Z) * (targetLook - targetLook.Position)
						BossEntity.Model:PivotTo(flightCFrame)

						if math.random() > 0.45 then
							executeBloodflameRain()
						else
							executeSkyDivebomb()
						end
					end
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- 17. MASTER LAUNCHER & INITIALIZATION
--------------------------------------------------------------------------------
local function startMasterEncounter()
	BossEntity.AIGeneration += 1
	BossEntity.IsActive = false
	BossEntity.IsAttacking = false
	if BossEntity.WingConn then
		BossEntity.WingConn:Disconnect()
		BossEntity.WingConn = nil
	end
	PlayerStats.IsParrying = false
	PlayerStats.IsRolling = false
	PlayerStats.IsAttacking = false
	PlayerStats.IsInvulnerable = false
	VFX.ClearAll()
	setupAtmosphere()
	local spawnCFramePos = buildSanctumArena()
	initializeFullHUD()

	PlayerStats.CurrentHP = PlayerStats.MaxHP
	PlayerStats.CurrentStamina = PlayerStats.MaxStamina
	PlayerStats.IsDead = false
	PlayerStats.IsParrying = false
	PlayerStats.GracePeriodActive = true
	BossEntity.CurrentHP = BossEntity.MaxHP
	BossEntity.IsPhase2 = false
	BossEntity.IsFlying = false
	BossEntity.FlightTime = 0
	BossEntity.IsDead = false

	-- Teleport Character Safely onto Balcony
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")
	local hum = char:WaitForChild("Humanoid")
	hum.Health = hum.MaxHealth
	task.wait(0.3)

	-- Look directly toward the boss in the center
	hrp.CFrame = CFrame.new(spawnCFramePos, ARENA_ORIGIN + Vector3.new(0, 14, 0))

	-- Spawn the Warlord at Center
	constructCrucibleBoss(CFrame.new(ARENA_ORIGIN + Vector3.new(0, 2.5, 0)), ARENA_CONTAINER)

	-- 6-Second Invulnerable Startup Grace Period (Gives you time to view everything)
	task.spawn(function()
		for sec = 6, 1, -1 do
			if PlayerStats.HUD and PlayerStats.HUD.GraceIndicator then
				PlayerStats.HUD.GraceIndicator.Text = string.format("[ GRACE ACTIVE: %d SECONDS REMAINING ]", sec)
			end
			task.wait(1)
		end
		PlayerStats.GracePeriodActive = false
		if PlayerStats.HUD and PlayerStats.HUD.GraceIndicator then
			PlayerStats.HUD.GraceIndicator.Text = "[ GRACE EXPIRED: COMBAT ENGAGED ]"
			TweenService:Create(PlayerStats.HUD.GraceIndicator, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {
				TextTransparency = 1
			}):Play()
		end
	end)

	task.delay(1.5, function()
		if PlayerStats.HUD then
			PlayerStats.HUD.BossFrame.Visible = true
		end
		BossEntity.IsActive = true
		showDialogue("Mortal soul... thine blood belongeth to the Crucible.", 3.5)
		runBossAI()
	end)
end

--------------------------------------------------------------------------------
-- 18. HEARTBEAT VITALITY & INPUT BINDINGS
--------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	if not PlayerStats.IsDead and not PlayerStats.IsRolling and PlayerStats.CurrentStamina < PlayerStats.MaxStamina then
		PlayerStats.CurrentStamina = math.clamp(PlayerStats.CurrentStamina + (PlayerStats.StaminaRegenRate * dt), 0, PlayerStats.MaxStamina)
	end
	if PlayerStats.HUD then
		PlayerStats.HUD.StaminaFill.Size = UDim2.new(PlayerStats.CurrentStamina / PlayerStats.MaxStamina, 0, 1, 0)
		PlayerStats.HUD.HPFill.Size = UDim2.new(PlayerStats.CurrentHP / PlayerStats.MaxHP, 0, 1, 0)
	end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.LeftAlt then
		executeDodgeRoll()
	end
	if input.KeyCode == Enum.KeyCode.E or input.UserInputType == Enum.UserInputType.MouseButton1 then
		executePlayerAttack(false)
	end
	if input.KeyCode == Enum.KeyCode.R then
		executePlayerAttack(true)
	end
	if input.KeyCode == Enum.KeyCode.T then
		executeParry()
	end
	if input.KeyCode == Enum.KeyCode.F then
		startMasterEncounter()
	end
end)

startMasterEncounter()
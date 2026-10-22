--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/InterfaceController
-- Minimal Souls HUD: curved vitality arcs, inward-filling posture, loadout and gourd, boss
-- encounter bar, lock-on reticle with Deathblow calligraphy, telegraph glyphs, Incense Altar menu
-- and the death screen. Everything is built from instances; no uploaded imagery.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local simFolder = Shared:WaitForChild("Simulation")
local sharedFolder = Shared:WaitForChild("Shared")
local Weapons = require(simFolder:WaitForChild("WeaponSchema") :: ModuleScript) :: any
local Settings = require(sharedFolder:WaitForChild("CombatSettings") :: ModuleScript) :: any
local World = require(sharedFolder:WaitForChild("WorldDefinitions") :: ModuleScript)
local WorldState = require(script.Parent:WaitForChild("WorldStateController") :: ModuleScript)
local CameraController = require(script.Parent:WaitForChild("CameraController") :: ModuleScript)
local InputController = require(script.Parent:WaitForChild("InputController") :: ModuleScript)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local Sakura = require(script.Parent:WaitForChild("SakuraKit") :: ModuleScript)
local BossHud = require(script.Parent.BossHud)
local BossMusic = require(script.Parent.BossMusic)
local BossEffects = require(script.Parent.BossEffects)
local BossAnimations = require(script.Parent.BossAnimations)
local DuoBars = require(script.Parent.DuoBars)
local VitalsTags = require(script.Parent.VitalsTags)
local Visibility = require(script.Parent.HudVisibility)
local AltarAscension = require(script.Parent.AltarAscension)
local LevelPreview = require(sharedFolder:WaitForChild("LevelPreview") :: ModuleScript)

type WorldState = WorldState.WorldState
type Entity = WorldState.Entity
type Snapshot = WorldState.Snapshot
type CombatEvent = WorldState.CombatEvent
type Cue = WorldState.Cue
type CameraController = CameraController.CameraController
type InputController = InputController.InputController

local Controller = {}
Controller.__index = Controller

-- Sakura palette (SakuraKit.Colors): plum ink, blossom pink, crimson life, gold trim.
local INK = Sakura.Colors.Ink
local IVORY = Sakura.Colors.Ivory
local MUTED = Color3.fromRGB(190, 156, 176)
local BLOOD = Sakura.Colors.Crimson
local EMBER = Sakura.Colors.Sakura
local BLEED = Sakura.Colors.Blossom
local JADE = Sakura.Colors.Stamina
local GOLD = Sakura.Colors.Gold
local SCAR = Color3.fromRGB(62, 40, 60)
local TRACK = Sakura.Colors.Track
local EDGE = Color3.fromRGB(150, 60, 110)

local TITLE_FONT = Enum.Font.Antique
local BODY_FONT = Enum.Font.Garamond
local NUMBER_FONT = Enum.Font.GothamMedium

local WEAPON_GLYPH: { [string]: string } = { Unarmed = "FIST", Jian = "JIAN", Dao = "DAO", Guandao = "GLAIVE" }
local WEAPON_NAME: { [string]: string } = { Unarmed = "Iron Fist", Jian = "Jian Sword", Dao = "Dao Sabre", Guandao = "Guandao Glaive", None = "—" }
local REASONS: { [string]: string } = {
	GourdEmpty = "The gourd is empty.",
	EnemiesNearby = "Cannot rest while enemies hunt you.",
	InBossFight = "The fog binds you to this fight.",
	NotAtAltar = "Kneel at an Incense Altar first.",
	NoAltar = "There is no altar here.",
	TooFar = "Move closer to the altar.",
	NothingNearby = "Nothing to interact with.",
	WeaponLocked = "That weapon has not been earned.",
	NoOffhand = "No second weapon is carried.",
	AltarNotKindled = "That altar has not been kindled.",
	AlreadyHere = "You already rest here.",
	InsufficientStamina = "Too winded.",
	InsufficientQi = "Not enough Qi.",
	InDuel = "Not during a duel.",
	InColosseum = "The Colosseum forbids it.",
	GourdFull = "Your gourd is already full.",
	Unavailable = "Unavailable right now.",
}

-------------------------------------------------------------------------------------------------
-- Instance helpers
-------------------------------------------------------------------------------------------------

local function make<T>(className: string, parent: Instance?, properties: { [string]: any }): T
	local instance = Instance.new(className :: any)
	for key, value in properties do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance :: any
end

local function label(parent: Instance, text: string, size: number, font: Enum.Font, color: Color3, properties: { [string]: any }?): TextLabel
	local result = make("TextLabel", parent, {
		Text = text,
		TextSize = size,
		Font = font,
		TextColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextStrokeTransparency = 0.6,
		TextStrokeColor3 = INK,
	}) :: TextLabel
	if properties then
		for key, value in properties do
			(result :: any)[key] = value
		end
	end
	return result
end

local function corner(parent: Instance, radius: number)
	make("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	make("UIStroke", parent, { Color = color, Thickness = thickness, Transparency = transparency or 0 })
end

-- Altar buttons share the menu kit's hover / press / SFX juice.
local function button(parent: Instance, text: string, size: UDim2, callback: () -> ()): TextButton
	local result = UiKit.button(parent, text, "Secondary", callback)
	result.Size = size
	result.TextSize = 22
	return result
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

-------------------------------------------------------------------------------------------------
-- Curved segmented arc
-------------------------------------------------------------------------------------------------

type Arc = { Segments: { Frame }, Count: number }
type Layer = { Upto: number, Color: Color3 }

local function newArc(parent: Instance, center: Vector2, radius: number, thickness: number, count: number, startDeg: number, sweepDeg: number): Arc
	local segments: { Frame } = {}
	local step = math.rad(sweepDeg) / count
	for index = 1, count do
		local angle = math.rad(startDeg) + step * (index - 0.5)
		local segment = make("Frame", parent, {
			Name = "Segment" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X + math.cos(angle) * radius, center.Y + math.sin(angle) * radius),
			Size = UDim2.fromOffset(radius * step * 1.08, thickness),
			Rotation = math.deg(angle) + 90,
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
		}) :: Frame
		segments[index] = segment
	end
	return { Segments = segments, Count = count }
end

-- `visible` (0..1) trims the arc length (it grows with the stat's maximum); layers are cumulative.
local function setArc(arc: Arc, layers: { Layer }, visible: number, emptyColor: Color3)
	local shown = math.clamp(math.floor(arc.Count * visible + 0.5), 1, arc.Count)
	for index, segment in arc.Segments do
		if index > shown then
			segment.Visible = false
		else
			segment.Visible = true
			local position = (index - 0.5) / shown
			local color = emptyColor
			for _, layer in layers do
				if position <= layer.Upto then
					color = layer.Color
					break
				end
			end
			segment.BackgroundColor3 = color
			segment.BackgroundTransparency = if color == emptyColor then 0.35 else 0
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Inward posture bar (fills from both ends toward the centre)
-------------------------------------------------------------------------------------------------

type PostureBar = { Frame: Frame, Left: Frame, Right: Frame, Notch: Frame }

local function newPosture(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): PostureBar
	local frame = make("Frame", parent, {
		Name = "Posture",
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = TRACK,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	}) :: Frame
	corner(frame, 3)
	local left = make("Frame", frame, { Name = "Left", Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, BorderSizePixel = 0 }) :: Frame
	local right = make("Frame", frame, {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
	}) :: Frame
	local notch = make("Frame", frame, {
		Name = "Notch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 2, 1, 6),
		BackgroundColor3 = IVORY,
		BorderSizePixel = 0,
	}) :: Frame
	return { Frame = frame, Left = left, Right = right, Notch = notch }
end

local function setPosture(bar: PostureBar, ratio: number, broken: boolean)
	local r = math.clamp(ratio, 0, 1)
	local color = if broken then BLOOD elseif r < 0.6 then lerpColor(GOLD, EMBER, r / 0.6) else lerpColor(EMBER, BLOOD, (r - 0.6) / 0.4)
	bar.Left.Size = UDim2.fromScale(r * 0.5, 1)
	bar.Right.Size = UDim2.fromScale(r * 0.5, 1)
	bar.Left.BackgroundColor3 = color
	bar.Right.BackgroundColor3 = color
	bar.Frame.Visible = r > 0.005 or broken
end

-------------------------------------------------------------------------------------------------
-- Construction
-------------------------------------------------------------------------------------------------

type Fields = {
	State: WorldState,
	Camera: CameraController,
	Input: InputController,
	Player: Player,
	Gui: ScreenGui,
	HealthArc: Arc,
	StaminaArc: Arc,
	QiArc: Arc,
	QiText: TextLabel,
	OwnPosture: PostureBar,
	HealthText: TextLabel,
	LevelText: TextLabel,
	WeaponGlyph: TextLabel,
	WeaponName: TextLabel,
	OffhandName: TextLabel,
	ElixirText: TextLabel,
	EssenceText: TextLabel,
	BossFrame: Frame,
	BossTitle: TextLabel,
	BossPhase: TextLabel,
	BossActive: Frame,
	BossRecoverable: Frame,
	BossPosture: PostureBar,
	BossEntity: number?,
	BossId: string?,
	BossMembers: { number },
	BossScore: BossMusic.Score,
	Duo: DuoBars.View,
	Tags: VitalsTags.View,
	Vitals: Frame,
	Loadout: Frame,
	Billboard: BillboardGui,
	LockPosture: PostureBar,
	LockHealth: Frame,
	LockKanji: TextLabel,
	Deathblow: Frame,
	DeathblowKanji: TextLabel,
	DeathblowPrompt: TextLabel,
	Toast: TextLabel,
	ToastUntil: number,
	Banner: TextLabel,
	BannerSub: TextLabel,
	BannerUntil: number,
	Altar: Frame,
	AltarTitle: TextLabel,
	AltarPages: { [string]: Frame },
	AltarId: string?,
	Ascension: AltarAscension.View,
	AltarStatus: TextLabel,
	TravelList: Frame,
	Death: Frame,
	DeathTitle: TextLabel,
	DeathSub: TextLabel,
	DeathDetail: TextLabel,
	DeathShown: boolean,
	-- Essence spilled by the current death; the EssenceLost cue can arrive before or after the KO.
	DeathSpilled: number,
	Veil: Frame,
	Telegraphs: { BillboardGui },
	Connections: { RBXScriptConnection },
	Disconnects: { () -> () },
	OnIntent: ((action: string, variant: string?) -> ())?,
	OnSummon: ((altarId: string) -> ())?, -- set by DialogueController: summon Lin's projection here
	Clock: number,
}

export type Interface = typeof(setmetatable({} :: Fields, Controller))

-- Bottom-left sakura plate (authored at 1080p, scaled with the viewport): blossom medallion,
-- level and essence, then health / stamina / Qi bars and the inward posture bar.
local VITALS_SIZE = Vector2.new(470, 150)
local function plate(gui: ScreenGui, name: string): Frame
	local frame = make("Frame", gui, {
		Name = name, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.fromOffset(VITALS_SIZE.X, VITALS_SIZE.Y), BackgroundTransparency = 1,
	}) :: Frame
	return frame
end

local function buildVitals(gui: ScreenGui): (Arc, Arc, PostureBar, TextLabel, Arc, TextLabel, TextLabel)
	local frame = plate(gui, "Vitals")
	Sakura.medallion(frame, 112, UDim2.fromOffset(60, 84), true, { 35, 200, 305 })
	local level = label(frame, "Lv. 1", 22, TITLE_FONT, IVORY, {
		Name = "Level", Position = UDim2.fromOffset(128, 18), Size = UDim2.fromOffset(120, 26), TextXAlignment = Enum.TextXAlignment.Left,
	})
	local _, health = Sakura.bar(frame, "Health", Vector2.new(128, 48), 300, 18, 60, true)
	Sakura.crest(frame, 24, UDim2.fromOffset(446, 57))
	local text = label(frame, "", 13, NUMBER_FONT, IVORY, {
		Position = UDim2.fromOffset(128, 48), Size = UDim2.fromOffset(300, 18), ZIndex = 5, TextStrokeTransparency = 0.3,
	})
	-- y 68: VitalsTags status line (rally / lowered ceiling) between health and stamina.
	local _, stamina = Sakura.bar(frame, "Stamina", Vector2.new(128, 86), 270, 8, 54, false)
	local _, qi = Sakura.bar(frame, "Qi", Vector2.new(128, 100), 240, 8, 48, false)
	local qiText = label(frame, "QI 100 / 100", 13, NUMBER_FONT, Sakura.Colors.Qi, {
		Position = UDim2.fromOffset(376, 96), Size = UDim2.fromOffset(90, 16), TextXAlignment = Enum.TextXAlignment.Left,
	})
	local posture = newPosture(frame, UDim2.fromOffset(200, 5), UDim2.fromOffset(128, 114), Vector2.new(0, 0))
	return health, stamina, posture, text, qi, qiText, level
end

local function buildLoadout(gui: ScreenGui): (TextLabel, TextLabel, TextLabel, TextLabel, TextLabel)
	local frame = plate(gui, "Loadout")
	local glyph = label(frame, "FIST", 14, TITLE_FONT, IVORY, { Visible = false })
	local name = label(frame, "", 18, BODY_FONT, IVORY, {
		Position = UDim2.fromOffset(128, 124), Size = UDim2.fromOffset(140, 22), TextXAlignment = Enum.TextXAlignment.Left,
	})
	local offhand = label(frame, "", 14, BODY_FONT, MUTED, {
		Position = UDim2.fromOffset(268, 124), Size = UDim2.fromOffset(96, 22), TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- Flask charges as shapes (◆ full, ◇ spent): readable without relying on the colour.
	local elixir = label(frame, "FLASK —", 18, TITLE_FONT, EMBER, {
		Name = "Flask", Position = UDim2.fromOffset(364, 124), Size = UDim2.fromOffset(110, 22), TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- Essence is the currency (banked + carried); Qi is spell energy and lives by the Qi bar.
	local essence = label(frame, "", 20, TITLE_FONT, GOLD, {
		Name = "Essence", Position = UDim2.fromOffset(230, 18), Size = UDim2.fromOffset(216, 26), TextXAlignment = Enum.TextXAlignment.Right,
	})
	return glyph, name, offhand, elixir, essence
end

-- Top-centre boss plate under the compass: serif name, ornate crimson bar with gold diamond caps.
local function buildBoss(gui: ScreenGui): (Frame, TextLabel, TextLabel, Frame, Frame, PostureBar)
	local frame = make("Frame", gui, {
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.new(0.5, 0, 0, 96),
		BackgroundTransparency = 1,
		Visible = false,
	}) :: Frame
	make("UISizeConstraint", frame, { MaxSize = Vector2.new(900, 96), MinSize = Vector2.new(300, 96) })
	local title = label(frame, "", 24, TITLE_FONT, IVORY, {
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.3,
	})
	local phase = label(frame, "", 16, BODY_FONT, EMBER, {
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local casing = make("Frame", frame, {
		Name = "Casing", Position = UDim2.fromOffset(-5, 48), Size = UDim2.new(1, 10, 0, 22),
		BackgroundColor3 = INK, BackgroundTransparency = 0.3, BorderSizePixel = 0,
	}) :: Frame
	stroke(casing, GOLD, 1, 0.45)
	Sakura.diamond(casing, 16, UDim2.fromScale(0, 0.5), GOLD, EMBER)
	Sakura.diamond(casing, 16, UDim2.fromScale(1, 0.5), GOLD, EMBER)
	local posture = newPosture(frame, UDim2.new(0.5, 0, 0, 5), UDim2.new(0.5, 0, 0, 84), Vector2.new(0.5, 0))
	local track = make("Frame", frame, {
		Name = "Health",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = TRACK,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}) :: Frame
	stroke(track, EDGE, 1, 0.2)
	local recoverable = make("Frame", track, { Name = "Recoverable", Size = UDim2.fromScale(1, 1), BackgroundColor3 = EMBER, BorderSizePixel = 0 }) :: Frame
	local active = make("Frame", track, { Name = "Active", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }) :: Frame
	make("UIGradient", active, { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(236, 64, 72), Color3.fromRGB(140, 8, 22)) })
	return frame, title, phase, active, recoverable, posture
end

local function buildLockBillboard(gui: ScreenGui): (BillboardGui, PostureBar, Frame, TextLabel)
	local billboard = make("BillboardGui", gui, {
		Name = "LockOn",
		Size = UDim2.fromOffset(140, 150),
		StudsOffset = Vector3.new(0, 1.6, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		ResetOnSpawn = false,
	}) :: BillboardGui
	local reticle = make("Frame", billboard, {
		Name = "Reticle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = IVORY,
		BackgroundTransparency = 0.1,
	}) :: Frame
	corner(reticle, 5)
	stroke(reticle, BLOOD, 2)
	local posture = newPosture(billboard, UDim2.new(0.8, 0, 0, 5), UDim2.new(0.5, 0, 0, 6), Vector2.new(0.5, 0))
	local healthTrack = make("Frame", billboard, {
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0.6, 0, 0, 4),
		BackgroundColor3 = TRACK,
		BorderSizePixel = 0,
	}) :: Frame
	local health = make("Frame", healthTrack, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLOOD, BorderSizePixel = 0 }) :: Frame
	local kanji = label(billboard, "!", 72, TITLE_FONT, BLOOD, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(100, 100),
		TextStrokeTransparency = 0.2,
		Visible = false,
	})
	return billboard, posture, health, kanji
end

local function buildDeathblow(gui: ScreenGui): (Frame, TextLabel, TextLabel)
	local frame = make("Frame", gui, {
		Name = "Deathblow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}) :: Frame
	local kanji = label(frame, "EXECUTE", 80, TITLE_FONT, BLOOD, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(480, 480),
		TextTransparency = 0.82,
		TextStrokeTransparency = 1,
	})
	local prompt = label(frame, "", 26, TITLE_FONT, IVORY, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromOffset(520, 34),
	})
	return frame, kanji, prompt
end

local function buildDeath(gui: ScreenGui): (Frame, TextLabel, TextLabel, TextLabel)
	local frame = make("Frame", gui, {
		Name = "Death",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
	}) :: Frame
	local title = label(frame, "YOU FELL", 84, TITLE_FONT, Color3.fromRGB(168, 24, 26), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.new(0.9, 0, 0, 100),
		TextScaled = true,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 21,
	})
	make("UITextSizeConstraint", title, { MinTextSize = 36, MaxTextSize = 84 })
	local sub = label(frame, "SPIRIT SEVERED", 26, BODY_FONT, IVORY, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.85, 0, 0, 34),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 21,
	})
	local detail = label(frame, "", 18, BODY_FONT, MUTED, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.new(0.85, 0, 0, 52),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 21,
	})
	return frame, title, sub, detail
end

function Controller.new(state: WorldState, camera: CameraController, input: InputController): Interface
	local player = Players.LocalPlayer
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "AsuraHUD",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
	}) :: ScreenGui
	local healthArc, staminaArc, ownPosture, healthText, qiArc, qiText, levelText = buildVitals(gui)
	local glyph, weaponName, offhand, elixir, essence = buildLoadout(gui)
	local bossFrame, bossTitle, bossPhase, bossActive, bossRecoverable, bossPosture = buildBoss(gui)
	local billboard, lockPosture, lockHealth, lockKanji = buildLockBillboard(gui)
	local deathblow, deathblowKanji, deathblowPrompt = buildDeathblow(gui)
	local death, deathTitle, deathSub, deathDetail = buildDeath(gui)
	-- Full-screen veil for portal transitions (above the HUD, below nothing interactive).
	local veil = make("Frame", gui, {
		Name = "PortalVeil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(242, 234, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Visible = false,
	}) :: Frame
	local toast = label(gui, "", 22, BODY_FONT, IVORY, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.new(0.8, 0, 0, 28),
		TextScaled = true,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	make("UISizeConstraint", toast, { MaxSize = Vector2.new(640, 28) })
	make("UITextSizeConstraint", toast, { MinTextSize = 14, MaxTextSize = 22 })
	local banner = label(gui, "", 27, TITLE_FONT, IVORY, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.new(0.84, 0, 0, 42),
		TextScaled = true,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	make("UITextSizeConstraint", banner, { MinTextSize = 14, MaxTextSize = 27 })
	local bannerSub = label(gui, "", 16, BODY_FONT, MUTED, {
		Name = "BannerSub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.22, 24),
		Size = UDim2.new(0.8, 0, 0, 24),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	local fields: Fields = {
		State = state,
		Camera = camera,
		Input = input,
		Player = player,
		Gui = gui,
		HealthArc = healthArc,
		StaminaArc = staminaArc,
		QiArc = qiArc,
		QiText = qiText,
		OwnPosture = ownPosture,
		HealthText = healthText,
		LevelText = levelText,
		WeaponGlyph = glyph,
		WeaponName = weaponName,
		OffhandName = offhand,
		ElixirText = elixir,
		EssenceText = essence,
		BossFrame = bossFrame,
		BossTitle = bossTitle,
		BossPhase = bossPhase,
		BossActive = bossActive,
		BossRecoverable = bossRecoverable,
		BossPosture = bossPosture,
		BossEntity = nil,
		BossId = nil, BossMembers = {}, BossScore = BossMusic.new(), Duo = DuoBars.new(bossFrame, gui),
		Tags = VitalsTags.build(gui:FindFirstChild("Vitals") :: Frame), Vitals = gui:FindFirstChild("Vitals") :: Frame, Loadout = gui:FindFirstChild("Loadout") :: Frame,
		Billboard = billboard,
		LockPosture = lockPosture,
		LockHealth = lockHealth,
		LockKanji = lockKanji,
		Deathblow = deathblow,
		DeathblowKanji = deathblowKanji,
		DeathblowPrompt = deathblowPrompt,
		Toast = toast,
		ToastUntil = 0,
		Banner = banner,
		BannerSub = bannerSub,
		BannerUntil = 0,
		Altar = (nil :: any) :: Frame,
		AltarTitle = (nil :: any) :: TextLabel,
		AltarPages = {},
		AltarId = nil,
		Ascension = (nil :: any) :: AltarAscension.View,
		AltarStatus = (nil :: any) :: TextLabel,
		TravelList = (nil :: any) :: Frame,
		Death = death,
		Veil = veil,
		DeathTitle = deathTitle,
		DeathSub = deathSub,
		DeathDetail = deathDetail,
		DeathShown = false,
		DeathSpilled = 0,
		Telegraphs = {},
		Connections = {},
		Disconnects = {},
		OnIntent = nil,
		OnSummon = nil,
		Clock = 0,
	}
	local self = setmetatable(fields, Controller)
	self:BuildAltar()
	-- Panels are authored at 1080p; scale them with the viewport so phones stay legible and
	-- large displays don't shrink the HUD to a corner.
	for name, base in { Vitals = 0.78, Loadout = 0.78, AltarMenu = 0.8 } do
		local panel = gui:FindFirstChild(name)
		if panel and panel:IsA("GuiObject") then
			table.insert(self.Disconnects, HudKit.bindScale(panel, base))
		end
	end

	table.insert(self.Disconnects, state:OnCue(function(cue: Cue)
		self:OnCue(cue)
	end))
	table.insert(self.Disconnects, state:OnEvent(function(event: CombatEvent)
		self:OnEvent(event)
	end))
	table.insert(self.Connections, player:GetAttributeChangedSignal("AsuraResult"):Connect(function()
		local result = player:GetAttribute("AsuraResult")
		if type(result) == "string" and string.sub(result, 1, 1) == "!" then
			local reason = string.sub(result, 2)
			local text = REASONS[reason]
			if text then
				self:ShowToast(text)
			end
		end
	end))
	table.insert(self.Connections, player:GetAttributeChangedSignal("AsuraRegion"):Connect(function()
		local region = player:GetAttribute("AsuraRegion")
		local definition = if type(region) == "string" then World.Regions[region :: any] else nil
		if definition then
			self:ShowBanner(string.upper(definition.Name), "", 3)
		end
	end))
	return self
end

-------------------------------------------------------------------------------------------------
-- Incense Altar menu
-------------------------------------------------------------------------------------------------

function Controller.Intent(self: Interface, action: string, variant: string?)
	local callback = self.OnIntent
	if callback then
		callback(action, variant)
	end
end

function Controller.ShowPage(self: Interface, page: string)
	for name, frame in self.AltarPages do
		frame.Visible = name == page
	end
	if page == "Travel" then
		self:RefreshTravel()
	elseif page == "Level" then
		self:RefreshLevel()
	end
end

function Controller.BuildAltar(self: Interface)
	local frame = make("Frame", self.Gui, {
		Name = "AltarMenu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 60, 0.5, 0),
		Size = UDim2.fromOffset(380, 440),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 5,
	}) :: Frame
	make("UIScale", frame, { Scale = 0.8 })
	corner(frame, 6)
	stroke(frame, EDGE, 2)
	make("UIPadding", frame, {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 14),
	})
	local title = label(frame, "Incense Altar", 30, TITLE_FONT, IVORY, {
		Size = UDim2.new(1, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label(frame, "RESTING SITE", 16, TITLE_FONT, EMBER, {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local function page(name: string): Frame
		local container = make("Frame", frame, {
			Name = name,
			Position = UDim2.fromOffset(0, 70),
			Size = UDim2.new(1, 0, 1, -84),
			BackgroundTransparency = 1,
			Visible = false,
		}) :: Frame
		make("UIListLayout", container, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		self.AltarPages[name] = container
		return container
	end

	-- Resting already set the checkpoint and refilled the flask (server restAt); the menu only
	-- offers deliberate next steps. Lin is summoned on request, never forced open by resting.
	local main = page("Main")
	self.AltarStatus = label(main, "Rested  ·  checkpoint set  ·  flask refilled", 16, BODY_FONT, MUTED, {
		Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0,
	})
	button(main, "Ascension", UDim2.new(1, 0, 0, 46), function()
		self:ShowPage("Level")
	end).LayoutOrder = 1
	button(main, "Summon Lady Lin", UDim2.new(1, 0, 0, 46), function()
		local altarId, summon = self.AltarId, self.OnSummon
		if altarId and summon then summon(altarId) end
	end).LayoutOrder = 2
	button(main, "Travel", UDim2.new(1, 0, 0, 46), function()
		self:ShowPage("Travel")
	end).LayoutOrder = 3
	button(main, "Leave", UDim2.new(1, 0, 0, 46), function()
		self:CloseAltar()
	end).LayoutOrder = 4

	local level = page("Level")
	self.Ascension = AltarAscension.build(level, function(attribute: string)
		self:Intent("LevelUp", attribute)
	end)
	button(level, "Back", UDim2.new(1, 0, 0, 40), function()
		self:ShowPage("Main")
	end).LayoutOrder = 10

	local travel = page("Travel")
	local list = make("ScrollingFrame", travel, {
		Name = "List",
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		LayoutOrder = 1,
	}) :: ScrollingFrame
	make("UIListLayout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	self.TravelList = list
	button(travel, "Back", UDim2.new(1, 0, 0, 40), function()
		self:ShowPage("Main")
	end).LayoutOrder = 2

	self.Altar = frame
	self.AltarTitle = title
end

function Controller.RefreshLevel(self: Interface)
	AltarAscension.refresh(self.Ascension, self.Player)
end

function Controller.RefreshTravel(self: Interface)
	for _, child in self.TravelList:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local raw = self.Player:GetAttribute("AsuraAltars")
	local current = self.AltarId
	local index = 0
	for id in string.gmatch(if type(raw) == "string" then raw else "", "[^,]+") do
		local altar = World.Altars[id]
		if altar then
			index += 1
			local region = World.Regions[altar.Region]
			local entry = button(self.TravelList, altar.Name .. "   —   " .. region.Name, UDim2.new(1, -8, 0, 40), function()
				self:Intent("Travel", id)
			end)
			entry.TextSize = 17
			entry.LayoutOrder = index
			if id == current then
				entry.AutoButtonColor = false
				entry.TextColor3 = MUTED
				entry.Text = altar.Name .. "   (here)"
			end
		end
	end
end

function Controller.OpenAltar(self: Interface, altarId: string)
	local altar = World.Altars[altarId]
	self.AltarId = altarId
	self.AltarTitle.Text = if altar then altar.Name else "Incense Altar"
	self.Altar.Visible = true
	self.Input:SetMenu(true)
	self:ShowPage("Main")
	-- Spring the altar in from the left; the authored UIScale (0.8) is the rest size.
	local scale = self.Altar:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.72
		TweenService:Create(scale, UiKit.Motion.Open, { Scale = 0.8 }):Play()
	end
	self.Altar.Position = UDim2.new(0, 60 - UiKit.Motion.SlidePixels * 2, 0.5, 0)
	TweenService:Create(self.Altar, UiKit.Motion.Open, { Position = UDim2.new(0, 60, 0.5, 0) }):Play()
	UiKit.play("Open")
end

function Controller.CloseAltar(self: Interface)
	if not self.Altar.Visible then
		return
	end
	self.Altar.Visible = false
	self.AltarId = nil
	self.Input:SetMenu(false)
	UiKit.play("Close")
end

-------------------------------------------------------------------------------------------------
-- Transient text
-------------------------------------------------------------------------------------------------

function Controller.ShowToast(self: Interface, text: string)
	if not Visibility.of(self).Notices then return end -- nothing stale outlives the death screen
	self.Toast.Text = text
	self.Toast.TextTransparency = 0
	self.Toast.TextStrokeTransparency = 0.6
	self.ToastUntil = os.clock() + 2.4
end

function Controller.ShowBanner(self: Interface, title: string, subtitle: string, duration: number)
	if not Visibility.of(self).Notices then return end
	self.Banner.TextColor3 = IVORY
	self.Banner.Position = UDim2.fromScale(0.5, 0.22)
	self.BannerSub.Position = UDim2.fromScale(0.5, 0.27)
	local constraint = self.Banner:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then constraint.MaxTextSize = 27 end
	self.Banner.Text = title
	self.BannerSub.Text = subtitle
	self.Banner.TextTransparency = 0
	self.BannerSub.TextTransparency = 0
	self.Banner.TextStrokeTransparency = 0.5
	self.BannerSub.TextStrokeTransparency = 0.6
	self.BannerUntil = os.clock() + duration
end

function Controller.Telegraph(self: Interface, entity: Entity, class: string, impact: number)
	local root = entity.Root
	if not root then
		return
	end
	local perilous = class == "Perilous"
	local billboard = make("BillboardGui", self.Gui, {
		Name = "Telegraph",
		Adornee = root,
		Size = UDim2.fromOffset(if perilous then 110 else 50, if perilous then 110 else 50),
		StudsOffset = Vector3.new(0, if entity.Boss then 5.5 else 4, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}) :: BillboardGui
	local glyph = label(billboard, "!", if perilous then 96 else 40, TITLE_FONT, if perilous then BLOOD else IVORY, {
		Size = UDim2.fromScale(1, 1),
		TextStrokeTransparency = 0.1,
	})
	table.insert(self.Telegraphs, billboard)
	local remaining = math.max(impact - workspace:GetServerTimeNow(), 0.15) + 0.25
	TweenService:Create(glyph, TweenInfo.new(remaining, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(remaining, function()
		local index = table.find(self.Telegraphs, billboard)
		if index then
			table.remove(self.Telegraphs, index)
		end
		billboard:Destroy()
	end)
end

-------------------------------------------------------------------------------------------------
-- Cues and events
-------------------------------------------------------------------------------------------------

function Controller.ShowDeath(self: Interface)
	-- A Colosseum defeat is not a death: no essence is spilled and the duel result is shown instead.
	if self.DeathShown or type(self.Player:GetAttribute("AsuraColosseum")) == "string" then
		return
	end
	self.DeathShown = true
	self:CloseAltar()
	-- Clear anything mid-flight so the death screen stands alone.
	self.Toast.TextTransparency, self.Toast.TextStrokeTransparency, self.ToastUntil = 1, 1, 0
	self.Banner.TextTransparency, self.BannerSub.TextTransparency, self.BannerUntil = 1, 1, 0
	local frame = self.Death
	frame.Visible = true
	frame.BackgroundTransparency = 1
	self:DeathNote(self.DeathSpilled)
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine)
	TweenService:Create(frame, info, { BackgroundTransparency = 0.05 }):Play()
	TweenService:Create(self.DeathTitle, TweenInfo.new(2.2, Enum.EasingStyle.Sine), { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	TweenService:Create(self.DeathSub, TweenInfo.new(2.8, Enum.EasingStyle.Sine), { TextTransparency = 0.1 }):Play()
	TweenService:Create(self.DeathDetail, TweenInfo.new(3.2, Enum.EasingStyle.Sine), { TextTransparency = 0.2 }):Play()
end

-- Loss, wake point and recovery goal, in that order.
function Controller.DeathNote(self: Interface, spilled: number)
	self.DeathSpilled = spilled
	local altarId = self.Player:GetAttribute("AsuraActiveAltar")
	local altar = if type(altarId) == "string" then World.Altars[altarId] else nil
	local lines = {}
	if spilled > 0 then table.insert(lines, string.format("%d essence spilled — reclaim it from your bloodstain", spilled)) end
	if altar then table.insert(lines, "You will wake at " .. altar.Name) end
	self.DeathDetail.Text = table.concat(lines, "\n")
end

function Controller.HideDeath(self: Interface)
	if not self.DeathShown then
		return
	end
	self.DeathShown = false
	self.DeathSpilled = 0
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine)
	TweenService:Create(self.Death, info, { BackgroundTransparency = 1 }):Play()
	for _, text in { self.DeathTitle, self.DeathSub, self.DeathDetail } do
		TweenService:Create(text, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
	task.delay(1.25, function()
		if not self.DeathShown then
			self.Death.Visible = false
		end
	end)
end

-- Fades to the portal's light, holds while the server moves the fighter, then fades back in.
function Controller.Transition(self: Interface, fade: number, destination: string)
	local veil = self.Veil
	veil.Visible = true
	veil.BackgroundTransparency = 1
	self:CloseAltar()
	TweenService:Create(veil, TweenInfo.new(fade, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 0 }):Play()
	task.delay(fade + 0.35, function()
		local out = TweenService:Create(veil, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		out.Completed:Connect(function()
			if veil.BackgroundTransparency >= 0.99 then
				veil.Visible = false
			end
		end)
		out:Play()
		if destination ~= "" then
			self:ShowBanner(string.upper(destination), "Arrived · the altar ahead is your checkpoint", 2.6)
		end
	end)
end

function Controller.OnEvent(self: Interface, event: CombatEvent)
	if event.Kind == "KO" and event.Target == self.State.LocalId then
		self:ShowDeath()
		BossMusic.stop(self.BossScore)
	elseif event.Kind == "StanceBreak" and event.Target == self.State.LocalId then
		self:ShowToast("Posture broken!")
	end
end

function Controller.OnCue(self: Interface, cue: Cue)
	local own = self.State.LocalId
	local data = cue.Data
	local isBossCue = string.sub(cue.Kind, 1, 4) == "Boss" or cue.Kind == "FogGateSealed"
	local ownEncounter = self.Player:GetAttribute("AsuraEncounter")
	if isBossCue then
		local participants = data.participants
		local entity = self.State:Get(cue.Source)
		local encounter = data.boss or (entity and entity.Model:GetAttribute("AsuraEncounter"))
		local included = type(participants) == "table" and table.find(participants, own) ~= nil
		local involved = encounter ~= nil and (encounter == self.BossId or encounter == ownEncounter)
		if cue.Kind == "BossParticipantLeft" then involved = cue.Source == own end
		if not included and not involved then return end
	end
	local sourceEntity = self.State:Get(cue.Source)
	if isBossCue or (sourceEntity and sourceEntity.Model:GetAttribute("AsuraEncounter") == self.BossId and self.BossId ~= nil) then
		BossEffects.cue(cue, self.State)
		if sourceEntity and (cue.Kind == "Telegraph" or cue.Kind == "BossPhase" or cue.Kind == "BossEnrage") then
			BossAnimations.action(sourceEntity.Model, cue.Kind ~= "Telegraph")
		end
	end
	if cue.Kind == "AltarRest" and cue.Source == own then
		local altarId = tostring(data.altar or "")
		self:ShowBanner("ALTAR KINDLED", tostring(data.name or ""), 2.5)
		self:OpenAltar(altarId)
	elseif cue.Kind == "AltarTravel" and cue.Source == own then
		self:ShowToast("You walk the incense road.")
	elseif cue.Kind == "LevelUp" and cue.Source == own then
		local attribute = tostring(data.attribute or "")
		self:ShowToast((LevelPreview.Labels[attribute] or attribute) .. " deepens.")
		task.delay(0.6, function()
			if self.Altar.Visible then
				self:RefreshLevel()
			end
		end)
	elseif cue.Kind == "LevelRefused" and cue.Source == own then
		self:ShowToast(if data.reason == "Not enough essence" then "Not enough essence." else "Cannot grow further.")
	elseif cue.Kind == "EssenceLost" and cue.Source == own then
		self:DeathNote(tonumber(data.amount) or 0)
	elseif cue.Kind == "EssenceRecovered" and cue.Source == own then
		self:ShowToast(string.format("Essence reclaimed  +%d", tonumber(data.amount) or 0))
	elseif cue.Kind == "BossIntro" or cue.Kind == "FogGateSealed" then
		self.BossEntity = cue.Source
		self.BossId = tostring(data.boss or "")
		if type(data.members) == "table" then self.BossMembers = data.members
		elseif #self.BossMembers == 0 then self.BossMembers = { cue.Source } end
		local boss = World.Bosses[self.BossId :: string]
		self.BossTitle.Text = if boss then boss.Name else tostring(data.title or "")
		BossHud.decorate(self.BossFrame, if boss then boss.Title else "", if boss then math.max(#boss.Phases, #self.BossMembers) else 1)
		if DuoBars.bind(self.Duo, self.BossMembers, DuoBars.lockKey(self.Input.Device)) and boss then
			self.BossTitle.Text = string.match(boss.Title, "^([^:]+)") or boss.Name -- each member is named on its own row
		end
		self.BossPhase.Text = tostring(data.name or "")
		self.BossFrame.Visible = true
		BossMusic.set(self.BossScore, self.BossId :: string, 1)
	elseif cue.Kind == "BossPhase" or cue.Kind == "BossEnrage" then
		self.BossPhase.Text = tostring(data.name or "")
		if data.survivor and #self.Duo.Rows == 0 then self.BossTitle.Text = tostring(data.survivor) end
		self:ShowBanner(string.upper(tostring(data.name or "")), "", 2.4)
		if data.shot == nil then self.Camera:BossShot(cue.Source, tonumber(data.duration) or 2.4) end -- handoff shots: EncounterHandoffController
		BossMusic.set(self.BossScore, self.BossId or "", tonumber(data.phase) or 2)
	elseif cue.Kind == "BossFinish" then
		self.Camera:BossShot(cue.Source, 1.3, true)
	elseif cue.Kind == "BossKneel" then
		self:ShowToast("Ankles shattered — strike the head!")
	elseif cue.Kind == "BossGrab" and data.target == own then
		self.Camera:BossShot(cue.Source, tonumber(data.duration) or 1.2)
	elseif cue.Kind == "BossDefeated" then
		self:ShowBanner(tostring(data.banner or "GREAT FOE VANQUISHED"), string.format("+%d essence", tonumber(data.essence) or 0), 4)
		self.Banner.TextColor3 = GOLD
		self.Banner.ZIndex, self.BannerSub.ZIndex = 20, 20
		self.Banner.Position = UDim2.fromScale(0.5, 0.45)
		self.BannerSub.Position = UDim2.fromScale(0.5, 0.51)
		local victoryVeil = self.Gui:FindFirstChild("VictoryVeil")
		if victoryVeil then victoryVeil:Destroy() end
		local veil = make("Frame", self.Gui, { Name = "VictoryVeil", Position = UDim2.fromScale(0, 0.36), Size = UDim2.fromScale(1, 0.22),
			BackgroundColor3 = INK, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 19 }) :: Frame
		TweenService:Create(veil, TweenInfo.new(4), { BackgroundTransparency = 1 }):Play()
		task.delay(4.2, function() veil:Destroy() end)
		self.Banner.TextSize = 44
		local constraint = self.Banner:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint then constraint.MaxTextSize = 44 end
		HudKit.cue(HudKit.Sounds.Objective, 0.8, 0.7)
		HudKit.cue(HudKit.Sounds.Tick, 0.65, 1.4)
		self.BossEntity, self.BossId, self.BossMembers = nil, nil, {}
		self.BossFrame.Visible = false
		DuoBars.clear(self.Duo)
		BossMusic.stop(self.BossScore)
		task.delay(12, BossAnimations.prune) -- the corpse is removed after EnemyCorpseTime
	elseif cue.Kind == "BossReset" or cue.Kind == "BossParticipantLeft" then
		BossAnimations.prune()
		self.BossEntity, self.BossId, self.BossMembers = nil, nil, {}
		self.BossFrame.Visible = false
		DuoBars.clear(self.Duo)
		BossMusic.stop(self.BossScore)
	elseif cue.Kind == "PortalTransit" and cue.Source == own then
		local fade = tonumber(data.fade) or 0.5
		self:Transition(fade, tostring(data.name or ""))
		task.delay(fade + 0.2, function() -- arrival faces the checkpoint; bring the view round with it
			local body = self.State:Own()
			if body and body.Root then self.Camera:Face(body.Root.CFrame.LookVector) end
		end)
	elseif cue.Kind == "HealRefused" and cue.Source == own then
		self:ShowToast(if data.reason == "AtCeiling" then "At your lowered ceiling · gourd kept · rest restores maximum health"
			else string.format("Health is full · gourd kept (%d left)", tonumber(data.charges) or 0))
	elseif cue.Kind == "RavineReturn" and cue.Source == own then
		self:ShowToast("The ravine mist carries you back to the bridge.")
	elseif cue.Kind == "MistReturn" and cue.Source == own then
		self:ShowToast("The mist carries you back to " .. tostring(data.place or "safe ground") .. ".")
	elseif cue.Kind == "SanctuaryCatch" and cue.Source == own then
		self:ShowToast("The clouds return you to the bonfire.")
	elseif cue.Kind == "WeaponReinforced" and cue.Source == own then
		local weapon = tostring(data.weapon or "")
		self:ShowBanner("WEAPON REINFORCED", string.format("%s  +%d", WEAPON_NAME[weapon] or weapon, tonumber(data.level) or 0), 2.6)
	elseif cue.Kind == "ReinforceRefused" and cue.Source == own then
		local reason = tostring(data.reason or "")
		if reason == "Not enough essence" then
			self:ShowToast(string.format("The smith asks %d essence.", tonumber(data.cost) or 0))
		elseif reason == "Reinforcement at maximum" then
			self:ShowToast("This blade can be forged no further.")
		elseif reason == "Weapon is locked" then
			self:ShowToast("That weapon has not been earned.")
		else
			self:ShowToast("The smith sets down his hammer.")
		end
	elseif cue.Kind == "GourdRefilled" and cue.Source == own then
		self:ShowToast(string.format("Gourd refilled  (x%d)", tonumber(data.charges) or 0))
	elseif cue.Kind == "Telegraph" then
		local entity = self.State:Get(cue.Source)
		if entity and type(data.impact) == "number" then
			if entity.Boss then self:Telegraph(entity, tostring(data.class or "Heavy"), data.impact) end -- mobs: EnemyBars
			-- Perilous counters are named by CombatCallouts.warn (top callout priority), not a toast.
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Per-frame refresh
-------------------------------------------------------------------------------------------------

function Controller.UpdateVitals(self: Interface, snapshot: Snapshot)
	local maxHP = math.max(snapshot.MaxHP, 1)
	local active = snapshot.ActiveHP / maxHP
	local recoverable = (snapshot.ActiveHP + snapshot.RecoverableHP) / maxHP
	local ceiling = (maxHP - snapshot.PermanentDeficit) / maxHP
	local bleed = lerpColor(EMBER, BLEED, 0.5 + 0.5 * math.sin(self.Clock * 6))
	setArc(self.HealthArc, {
		{ Upto = active, Color = BLOOD },
		{ Upto = recoverable, Color = if snapshot.RallyActive then bleed else EMBER },
		{ Upto = ceiling, Color = TRACK },
		{ Upto = 1, Color = SCAR },
	}, math.clamp(maxHP / 200, 0.5, 1), TRACK)
	local stamina = snapshot.Stamina / math.max(snapshot.MaxStamina, 1)
	setArc(self.StaminaArc, { { Upto = stamina, Color = if snapshot.State == "StaminaBroken" then MUTED else JADE } }, math.clamp(snapshot.MaxStamina / 200, 0.5, 1), TRACK)
	local maxQi=if self.Player:GetAttribute("AsuraColosseum") and self.Player:GetAttribute("AsuraArenaNormalized")==true then 130 else (tonumber(self.Player:GetAttribute("AsuraMaxQi")) or 100)
 self.QiText.Text = string.format("QI %d / %d",math.floor(snapshot.Qi),maxQi)
	setArc(self.QiArc, { { Upto = snapshot.Qi / maxQi, Color = lerpColor(Sakura.Colors.Qi,BLEED,snapshot.Qi/maxQi) } }, 1, TRACK)
	setPosture(self.OwnPosture, snapshot.Posture / math.max(snapshot.PostureCapacity, 1), snapshot.State == "StanceBroken")
	self.HealthText.Text = string.format("%d / %d", math.floor(snapshot.ActiveHP + 0.5), math.floor(maxHP - snapshot.PermanentDeficit + 0.5))
	self.WeaponGlyph.Text = WEAPON_GLYPH[snapshot.Weapon] or "FIST"
	self.WeaponName.Text = Weapons.get(snapshot.Weapon).Name
	VitalsTags.update(self.Tags, snapshot, self.Clock)
end

function Controller.UpdateLock(self: Interface, own: Entity?, ownSnapshot: Snapshot?)
	local target = self.Camera:LockedEntity()
	local snapshot = target and target.Snapshot
	if not target or not target.Root or not snapshot or not Visibility.of(self).Combat then
		self.Billboard.Enabled = false
		self.Deathblow.Visible = false
		return
	end
	self.Billboard.Adornee = target.Root
	self.Billboard.StudsOffset = Vector3.new(0, if target.Boss then 3 else 1.6, 0)
	self.Billboard.Enabled = true
	-- Health and posture for the locked foe live on its EnemyBars plate and the TargetPlate.
	self.LockPosture.Frame.Visible = false
	(self.LockHealth.Parent :: Frame).Visible = false
	local distance = if own and own.Root then ((target.Root :: BasePart).Position - (own.Root :: BasePart).Position).Magnitude else math.huge
	local ready = snapshot.State == "StanceBroken" and distance <= Settings.Deathblow.Range + 0.5
		and ownSnapshot ~= nil and ownSnapshot.State ~= "KO"
	self.LockKanji.Visible = snapshot.State == "StanceBroken"
	self.LockKanji.TextTransparency = if ready then 0 else 0.55
	self.Deathblow.Visible = ready
	if ready then
		local pulse = 0.5 + 0.5 * math.sin(self.Clock * 7)
		self.DeathblowKanji.TextTransparency = 0.7 + 0.15 * pulse
		local key = self.Input:Label("Heavy")
		self.DeathblowPrompt.Text = if key ~= "" then string.format("DEATHBLOW   [%s]", key) else "DEATHBLOW   [HEAVY]"
	end
end

function Controller.UpdateBoss(self: Interface)
	if self.BossEntity == nil then return end
	for _, id in self.BossMembers do
		local entity = self.State:Get(id)
		if entity then BossAnimations.sync(entity.Model) end
	end
	if #self.Duo.Rows > 0 then
		DuoBars.update(self.Duo, self.State, self.Camera:LockedEntity(), not Visibility.of(self).Boss)
		return
	end
	local active, recoverable, posture, broken = BossHud.values(self.BossFrame, self.State, self.BossMembers)
	self.BossActive.Size = UDim2.fromScale(active, 1)
	self.BossRecoverable.Size = UDim2.fromScale(recoverable, 1)
	setPosture(self.BossPosture, posture, broken)
end

function Controller.Update(self: Interface, dt: number)
	self.Clock += dt
	local now = os.clock()
	local own = self.State:Own()
	local snapshot = own and own.Snapshot
	if snapshot then
		self:UpdateVitals(snapshot)
		if snapshot.State == "KO" then
			self:ShowDeath()
		elseif self.DeathShown then
			self:HideDeath()
		end
	end
	self:UpdateLock(own, snapshot)
	self:UpdateBoss()
	local layers = Visibility.of(self)
	self.Vitals.Visible, self.Loadout.Visible = layers.Vitals, layers.Vitals
	self.BossFrame.Visible = self.BossEntity ~= nil and layers.Boss

	local player = self.Player
	local elixirs = tonumber(player:GetAttribute("AsuraElixirs")) or 0
	local maximum = tonumber(player:GetAttribute("AsuraElixirsMax")) or 0
	self.ElixirText.Text = VitalsTags.flask(elixirs, maximum)
	local low = maximum > 0 and elixirs <= 1
	self.ElixirText.TextColor3 = if elixirs == 0 then MUTED elseif low then lerpColor(EMBER, BLOOD, 0.5 + 0.5 * math.sin(self.Clock * 5)) else EMBER
	self.ElixirText.TextTransparency = if maximum > 0 then 0 else 0.4
	local offhand = player:GetAttribute("AsuraOffhand")
	self.OffhandName.Text = if type(offhand) == "string" and offhand ~= "None" then "Off: " .. (WEAPON_NAME[offhand] or offhand) else ""
	local essence = tonumber(player:GetAttribute("AsuraEssence")) or 0
	local unbanked = tonumber(player:GetAttribute("AsuraUnbanked")) or 0
	self.EssenceText.Text = if unbanked > 0 then string.format("✦ %d ESSENCE  +%d carried", essence, unbanked) else string.format("✦ %d ESSENCE", essence)
	self.LevelText.Text = string.format("Lv. %d", tonumber(player:GetAttribute("AsuraLevel")) or 1)

	if self.Altar.Visible then
		local altar = if self.AltarId then World.Altars[self.AltarId] else nil
		local root = own and own.Root
		if not altar or not root then
			self:CloseAltar()
		else
			local p = altar.Placement
			if (root.Position - Vector3.new(p.X, p.Y, p.Z)).Magnitude > altar.Radius + 6 then
				self:CloseAltar()
			end
		end
	end

	if now > self.ToastUntil and self.Toast.TextTransparency < 1 then
		self.Toast.TextTransparency = math.min(1, self.Toast.TextTransparency + dt * 2)
		self.Toast.TextStrokeTransparency = math.max(self.Toast.TextTransparency, 0.6)
	end
	if now > self.BannerUntil and self.Banner.TextTransparency < 1 then
		local fade = math.min(1, self.Banner.TextTransparency + dt * 1.2)
		self.Banner.TextTransparency = fade
		self.BannerSub.TextTransparency = fade
		self.Banner.TextStrokeTransparency = math.max(fade, 0.5)
		self.BannerSub.TextStrokeTransparency = math.max(fade, 0.6)
	end
end

function Controller.Destroy(self: Interface)
	BossMusic.stop(self.BossScore)
	BossAnimations.clear()
	for _, disconnect in self.Disconnects do
		disconnect()
	end
	table.clear(self.Disconnects)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self.Input:SetMenu(false)
	self.Gui:Destroy()
end

return Controller

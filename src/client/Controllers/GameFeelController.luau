--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/GameFeelController
-- Presentation-only combat feedback driven by the authoritative event stream: deflect sparks and
-- clang, animation hit-stop, weighted camera impulses and concussion (head/eye trauma) visuals.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Schema = require(Shared:WaitForChild("Simulation"):WaitForChild("MoveSchema") :: ModuleScript) :: any
local WorldState = require(script.Parent:WaitForChild("WorldStateController") :: ModuleScript)
local CameraController = require(script.Parent:WaitForChild("CameraController") :: ModuleScript)

type WorldState = WorldState.WorldState
type CombatEvent = WorldState.CombatEvent
type Cue = WorldState.Cue
type CameraController = CameraController.CameraController

local Controller = {}
Controller.__index = Controller

-- Engine-bundled sounds only (the project ships no uploaded assets).
local SOUNDS = {
	Clang = "rbxasset://sounds/unsheath.wav",
	Slash = "rbxasset://sounds/swordslash.wav",
	Lunge = "rbxasset://sounds/swordlunge.wav",
	Blunt = "rbxasset://sounds/action_jump_land.mp3",
	Guard = "rbxasset://sounds/action_footsteps_plastic.mp3",
}

-- Hit-stop seconds and camera weight per event kind.
local HITSTOP: { [string]: number } = {
	Hit = 0.04,
	Armored = 0.04,
	CounterHit = 0.07,
	DeflectSpark = 0.05,
	GuardBreak = 0.06,
	StanceBreak = 0.07,
	Deathblow = 0.08,
}
local WEIGHT: { [string]: number } = {
	Hit = 0.18,
	Armored = 0.12,
	Block = 0.1,
	CounterHit = 0.4,
	DeflectSpark = 0.25,
	GuardBreak = 0.5,
	StanceBreak = 0.55,
	Deathblow = 0.9,
	KO = 0.6,
}
local FOV_PUNCH: { [string]: number } = {
	CounterHit = 2.5,
	GuardBreak = 3,
	StanceBreak = -3,
	Deathblow = -8,
	DeflectSpark = 1.2,
}
local BLUR_BY_TIER: { [string]: number } = { None = 0, Impaired = 4, Injured = 8, Severe = 14 }
local FOV_CLAMP_BY_TIER: { [string]: number } = { None = 0, Impaired = 4, Injured = 8, Severe = 14 }
local SWAY_BY_TIER: { [string]: number } = { None = 0, Impaired = 0.004, Injured = 0.009, Severe = 0.016 }
local FEEL_RANGE = 70

type Frozen = { Track: AnimationTrack, Speed: number, Until: number }

type Fields = {
	State: WorldState,
	Camera: CameraController,
	Folder: Folder,
	Blur: BlurEffect,
	Vignette: ScreenGui,
	VignetteEdges: { Frame },
	Frozen: { [AnimationTrack]: Frozen },
	Disconnects: { () -> () },
	BlurTarget: number,
	VignetteTarget: number,
	Tier: string,
}

export type GameFeel = typeof(setmetatable({} :: Fields, Controller))

local function vignetteEdge(parent: Instance, name: string, size: UDim2, position: UDim2, rotation: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(8, 0, 0)
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
	frame.Parent = parent
	return frame
end

function Controller.new(state: WorldState, camera: CameraController): GameFeel
	local folder = Instance.new("Folder")
	folder.Name = "AsuraFeel"
	folder.Parent = Workspace
	local blur = Instance.new("BlurEffect")
	blur.Name = "AsuraConcussion"
	blur.Size = 0
	blur.Parent = Lighting
	local gui = Instance.new("ScreenGui")
	gui.Name = "AsuraVignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local edges = {
		vignetteEdge(gui, "Left", UDim2.fromScale(0.28, 1), UDim2.fromScale(0, 0), 0),
		vignetteEdge(gui, "Right", UDim2.fromScale(0.28, 1), UDim2.fromScale(0.72, 0), 180),
		vignetteEdge(gui, "Top", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0), 90),
		vignetteEdge(gui, "Bottom", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.7), 270),
	}
	local fields: Fields = {
		State = state,
		Camera = camera,
		Folder = folder,
		Blur = blur,
		Vignette = gui,
		VignetteEdges = edges,
		Frozen = {},
		Disconnects = {},
		BlurTarget = 0,
		VignetteTarget = 1,
		Tier = "None",
	}
	local self = setmetatable(fields, Controller)
	table.insert(self.Disconnects, state:OnEvent(function(event: CombatEvent)
		self:OnEvent(event)
	end))
	table.insert(self.Disconnects, state:OnCue(function(cue: Cue)
		self:OnCue(cue)
	end))
	return self
end

-------------------------------------------------------------------------------------------------
-- Sparks and audio
-------------------------------------------------------------------------------------------------

local function playSound(parent: Instance, id: string, volume: number, pitch: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMaxDistance = 120
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function Controller.Spark(self: GameFeel, point: Vector3, direction: Vector3, color: Color3, count: number, speed: number)
	local anchor = Instance.new("Part")
	anchor.Name = "Spark"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	local facing = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.new(0, 1, 0)
	anchor.CFrame = CFrame.lookAt(point, point + facing)
	local emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Brightness = 3
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(38, 38)
	emitter.Lifetime = NumberRange.new(0.08, 0.24)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Acceleration = Vector3.new(0, -60, 0)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = anchor
	local flash = Instance.new("PointLight")
	flash.Color = color
	flash.Range = 12
	flash.Brightness = 6
	flash.Parent = anchor
	anchor.Parent = self.Folder
	emitter:Emit(count)
	TweenService:Create(flash, TweenInfo.new(0.12), { Brightness = 0 }):Play()
	task.delay(0.6, function()
		anchor:Destroy()
	end)
	return anchor
end

-------------------------------------------------------------------------------------------------
-- Hit-stop
-------------------------------------------------------------------------------------------------

local function animator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
end

function Controller.HitStop(self: GameFeel, models: { Model }, duration: number)
	local release = os.clock() + duration
	for _, model in models do
		local anim = animator(model)
		if anim then
			for _, track in anim:GetPlayingAnimationTracks() do
				local frozen = self.Frozen[track]
				if frozen then
					frozen.Until = math.max(frozen.Until, release)
				else
					self.Frozen[track] = { Track = track, Speed = track.Speed, Until = release }
					track:AdjustSpeed(0)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Event handling
-------------------------------------------------------------------------------------------------

local function involves(self: GameFeel, event: CombatEvent): boolean
	local id = self.State.LocalId
	if event.Source == id or event.Target == id then
		return true
	end
	local locked = self.Camera.Locked
	return locked ~= nil and (event.Source == locked or event.Target == locked)
end

function Controller.OnEvent(self: GameFeel, event: CombatEvent)
	local source = self.State:Get(event.Source)
	local target = self.State:Get(event.Target)
	local point = event.Point or (if target and target.Root then target.Root.Position else nil)
	local own = self.State:Own()
	if not point or not own or not own.Root or (point - own.Root.Position).Magnitude > FEEL_RANGE then
		return
	end
	local kind = event.Kind
	local direction = Vector3.new(0, 1, 0)
	if source and source.Root and target and target.Root then
		direction = (target.Root.Position - source.Root.Position)
	end

	if kind == "DeflectSpark" then
		-- Source is the defender; sparks fly back toward the attacker.
		local back = if target and target.Root and source and source.Root then (target.Root.Position - source.Root.Position) else direction
		local anchor = self:Spark(point, back + Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 196, 92), 48, 46)
		playSound(anchor, SOUNDS.Clang, 0.9, if source and source.Snapshot and source.Snapshot.Weapon=="PrayerOfTheDefiled" then 0.45 else 1.25 + math.random() * 0.15)
		playSound(anchor, SOUNDS.Slash, 0.4, 1.8)
	elseif kind == "Block" then
		local anchor = self:Spark(point, -direction, Color3.fromRGB(200, 200, 210), 10, 22)
		playSound(anchor, SOUNDS.Guard, 0.7, 1.1)
	elseif kind == "GuardBreak" or kind == "StanceBreak" then
		local anchor = self:Spark(point, Vector3.new(0, 1, 0), Color3.fromRGB(255, 120, 40), 60, 34)
		playSound(anchor, SOUNDS.Clang, 1, 0.8)
	elseif kind == "Hit" or kind == "CounterHit" or kind == "Armored" or kind == "BleedProc" then
		local blunt = target ~= nil and source ~= nil and source.Snapshot ~= nil and source.Snapshot.Weapon == "Unarmed"
		local color = if blunt then Color3.fromRGB(230, 220, 200) else Color3.fromRGB(150, 10, 14)
		local anchor = self:Spark(point, direction, color, if kind == "CounterHit" then 34 else 18, 18)
		playSound(anchor, if blunt then SOUNDS.Blunt else SOUNDS.Slash, if kind == "CounterHit" then 1 else 0.7, 0.9 + math.random() * 0.2)
	elseif kind == "Deathblow" then
		local anchor = self:Spark(point, Vector3.new(0, 1, 0), Color3.fromRGB(170, 0, 0), 90, 30)
		playSound(anchor, SOUNDS.Lunge, 1, 0.7)
		playSound(anchor, SOUNDS.Clang, 0.6, 0.6)
	end

	if not involves(self, event) then
		return
	end
	local stop = HITSTOP[kind]
	if stop then
		local models: { Model } = {}
		if source then
			table.insert(models, source.Model)
		end
		if target then
			table.insert(models, target.Model)
		end
		self:HitStop(models, stop)
	end
	local weight = WEIGHT[kind]
	if weight then
		local scale = if event.Target == self.State.LocalId then 1 else 0.6
		self.Camera:Impulse(direction, weight * scale, FOV_PUNCH[kind])
	end
end

function Controller.OnCue(self: GameFeel, cue: Cue)
	local own = self.State:Own()
	if not own or not own.Root then
		return
	end
	if cue.Kind == "Shockwave" then
		local data = cue.Data
		local origin = Vector3.new(tonumber(data.x) or 0, tonumber(data.y) or 0, tonumber(data.z) or 0)
		local distance = (own.Root.Position - origin).Magnitude
		local radius = tonumber(data.radius) or 16
		local strength = math.clamp(1.2 - distance / (radius * 2.5), 0, 1)
		if strength > 0 then
			self.Camera:Impulse(own.Root.Position - origin, strength, 4 * strength)
			local anchor = self:Spark(origin, Vector3.new(0, 1, 0), Color3.fromRGB(190, 30, 30), 120, 60)
			playSound(anchor, SOUNDS.Lunge, 1, 0.45)
		end
	elseif cue.Kind == "BossPhase" and Players.LocalPlayer:GetAttribute("AsuraEncounter") == cue.Data.boss then
		self.Camera:Impulse(Vector3.new(0, 1, 0), 0.7, -5)
	end
end

-------------------------------------------------------------------------------------------------
-- Per-frame: hit-stop release and concussion visuals
-------------------------------------------------------------------------------------------------

function Controller.Update(self: GameFeel, dt: number)
	local now = os.clock()
	for track, frozen in self.Frozen do
		if now >= frozen.Until then
			self.Frozen[track] = nil
			if track.IsPlaying then
				track:AdjustSpeed(frozen.Speed)
			end
		end
	end

	local snapshot = self.State:OwnSnapshot()
	local tier = "None"
	local blur = 0
	local vignette = 0
	if snapshot and snapshot.State ~= "KO" then
		tier = snapshot.Injuries.Head
		local penalties = Schema.penalties(snapshot.Injuries, false, "Right")
		-- Eye trauma (VisionBlur 0.2..0.75) maps onto Blur 4..14 alongside the concussion tier.
		local vision = if penalties.VisionBlur > 0 then 4 + (penalties.VisionBlur - 0.2) / 0.55 * 10 else 0
		blur = math.max(BLUR_BY_TIER[tier] or 0, vision)
		vignette = penalties.EyeVignette
	end
	if tier ~= self.Tier then
		self.Tier = tier
		self.Camera:SetHeadTrauma(tier)
		self.Camera:SetFovClamp(FOV_CLAMP_BY_TIER[tier] or 0)
		self.Camera:SetSway(SWAY_BY_TIER[tier] or 0)
	end
	-- Low-frequency pulse so heavy concussion "breathes" rather than sitting static.
	local pulse = if blur > 0 then 1 + 0.15 * math.sin(now * 1.4) else 1
	self.BlurTarget = math.clamp(blur * pulse, 0, 14)
	self.Blur.Size += (self.BlurTarget - self.Blur.Size) * math.min(1, dt * 4)
	local transparency = 1 - math.clamp(vignette * 1.1, 0, 0.85)
	for _, edge in self.VignetteEdges do
		edge.BackgroundTransparency += (transparency - edge.BackgroundTransparency) * math.min(1, dt * 3)
	end
end

function Controller.Destroy(self: GameFeel)
	for _, disconnect in self.Disconnects do
		disconnect()
	end
	table.clear(self.Disconnects)
	for track, frozen in self.Frozen do
		if track.IsPlaying then
			track:AdjustSpeed(frozen.Speed)
		end
	end
	table.clear(self.Frozen)
	self.Folder:Destroy()
	self.Blur:Destroy()
	self.Vignette:Destroy()
end

return Controller

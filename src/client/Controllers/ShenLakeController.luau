--!strict
-- The server phases drive the Bellwood crack and storm even before the lake streams in.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath"):WaitForChild("Shared")
local Rules = require(Shared:WaitForChild("ShenLakeRules") :: ModuleScript) :: any
local Overworld = require(Shared:WaitForChild("Overworld") :: ModuleScript) :: any
local Assets = require(Shared:WaitForChild("PresentationAssets") :: ModuleScript) :: any
local Effects = require(Shared.EffectsPreference)
local AnimationRules = require(Shared.BossAnimationRules)
local BossAnimations = require(script.Parent.BossAnimations)
local CameraController = require(script.Parent.CameraController)
local OverworldAmbience = require(script.Parent.OverworldAmbience)

local Controller = {}
Controller.__index = Controller

-- Heard and felt this far from the vortex (the basin is 1400 x 1120; the temple's upper hall is ~450 away).
Controller.Reach = 1500
Controller.GatherRadius = 78
local SMOKE = Assets.Textures.Smoke
local LEAF = OverworldAmbience.Leaf
local NS, NK, CS = NumberSequence.new, NumberSequenceKeypoint.new, ColorSequence.new
local rgb = Color3.fromRGB
local CRACK_MOVE = "HesitantMoon"
local CRACK_WINDUP = AnimationRules.Contacts.GrandmasterShen[CRACK_MOVE][1]

local function sound(id: string, parent: Instance, volume: number, speed: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.SoundId, s.Volume, s.PlaybackSpeed, s.Looped = id, volume, speed, looped
	s.Parent = parent
	return s
end

function Controller.Fade(self: any, s: Sound?, volume: number, seconds: number)
	if not s then return end
	local old = self.SoundFades[s]
	if old then old:Cancel(); old:Destroy() end
	local fade = TweenService:Create(s, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = volume })
	self.SoundFades[s] = fade
	fade:Play()
end

function Controller.DestroySound(self: any, s: Sound?)
	if not s then return end
	local fade = self.SoundFades[s]
	if fade then
		fade:Cancel()
		fade:Destroy()
		self.SoundFades[s] = nil
	end
	s:Destroy()
end

function Controller.new(camera: CameraController.CameraController): any
	local self = setmetatable({ Camera = camera, State = "Dormant", Since = 0, Storm = nil :: Model?,
		Gust = nil :: Sound?, Howl = nil :: Sound?, SoundFades = {} :: { [Sound]: Tween },
		CrackSounds = nil :: Folder?, Flash = nil :: ColorCorrectionEffect?, FlashTween = nil :: Tween?,
		ReleasePreview = nil :: (() -> ())?, Connection = nil :: RBXScriptConnection?,
		Pending = {} :: { [thread]: boolean } }, Controller)
	local function sync()
		if not self.Connection then return end
		local phase = Workspace:GetAttribute(Rules.PhaseAttribute)
		if type(phase) ~= "string" then self:Apply("Dormant", 0); return end
		local state, stamp = string.match(phase, "^(%a+):(.+)$")
		local since = tonumber(stamp)
		if state and since then self:Apply(state, since) end
	end
	self.Connection = Workspace:GetAttributeChangedSignal(Rules.PhaseAttribute):Connect(sync)
	sync()
	return self
end

local function vortex(): Vector3
	local v = Overworld.shenLake().Vortex
	return Vector3.new(v.X, v.Y, v.Z)
end

function Controller.Near(_self: any): boolean
	local cam = Workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - vortex()).Magnitude <= Controller.Reach
end

function Controller.Later(self: any, delaySeconds: number, fn: () -> ())
	if delaySeconds <= 0 then fn(); return end
	local pending: thread
	pending = task.delay(delaySeconds, function()
		self.Pending[pending] = nil
		fn()
	end)
	self.Pending[pending] = true
end

function Controller.Cancel(self: any)
	for pending in self.Pending do task.cancel(pending) end
	table.clear(self.Pending)
end

function Controller.Apply(self: any, state: string, since: number)
	if state == self.State and since == self.Since then return end
	local previous = self.State
	self.State, self.Since = state, since
	self:Cancel()
	self:ClearCrack()
	if state == "Summoning" then
		self:ClearStorm()
		local now = Workspace:GetServerTimeNow()
		local crackAt = since + Rules.CrackAt
		if now < crackAt then
			self:Later(crackAt - CRACK_WINDUP - now, function() self:PreviewCrack(crackAt) end)
		end
		if now < crackAt + 0.5 then
			self:Later(crackAt - now, function() self:Crack() end)
		end
		self:Later(since + Rules.WindAt - now, function() self:Gather(since + Rules.SummonSeconds) end)
	elseif state == "Stilled" then
		if previous == "Fight" then self:ClearStorm() end
		self:Gather(nil)
		if self.Gust then
			self:Fade(self.Gust, 0, 5)
			self:Later(5, function()
				self:DestroySound(self.Gust)
				self.Gust = nil
			end)
		end
	elseif state == "Fight" then
		self:Collapse()
	else
		self:ClearStorm()
	end
end

function Controller.PreviewCrack(self: any, crackAt: number)
	local remaining = crackAt - Workspace:GetServerTimeNow()
	if remaining <= 0 then return end
	if self:Near() then
		for _, entity in self.Camera.State.Entities do
			local model: Model = entity.Model
			if model:GetAttribute("AsuraBossAwaiting") ~= true or model:GetAttribute("AsuraEncounter") ~= "GrandmasterShen" then continue end
			local release = BossAnimations.preview(model, CRACK_MOVE, crackAt)
			if release then
				self.ReleasePreview = release
				self:Later(remaining + 1.25, function()
					release()
					self.ReleasePreview = nil
				end)
				return
			end
			break
		end
	end
	-- The server may still be loading the rig, or this client may be waiting on streaming.
	self:Later(math.min(remaining, 0.12), function() self:PreviewCrack(crackAt) end)
end

function Controller.ClearCrack(self: any)
	if self.ReleasePreview then self.ReleasePreview(); self.ReleasePreview = nil end
	if self.FlashTween then
		self.FlashTween:Cancel()
		self.FlashTween:Destroy()
		self.FlashTween = nil
	end
	if self.Flash then self.Flash:Destroy(); self.Flash = nil end
	if self.CrackSounds then self.CrackSounds:Destroy(); self.CrackSounds = nil end
end

function Controller.Crack(self: any)
	if not self:Near() then return end
	local sounds = Instance.new("Folder")
	sounds.Name, sounds.Parent = "ShenLakeCrack", SoundService
	self.CrackSounds = sounds
	for _, layer in { { Assets.Audio.FrostmereIceCrack, 3, 0.62 }, { Assets.Audio.SunBoom, 2.6, 0.55 }, { Assets.Audio.ShenLandImpact, 2.2, 0.7 } } do
		if layer[1] then
			local s = sound(layer[1], sounds, layer[2], layer[3], false)
			s.Ended:Once(function() s:Destroy() end)
			s:Play()
		end
	end
	local camera: CameraController.CameraController = self.Camera
	if camera.Enabled and camera.Camera == Workspace.CurrentCamera then
		camera:Impulse(Vector3.new(0, -1, 0), 7, 6)
		local character = Players.LocalPlayer.Character
		self:Later(0.18, function()
			if camera.Enabled and camera.Camera == Workspace.CurrentCamera and Players.LocalPlayer.Character == character and self:Near() then
				camera:Impulse(Vector3.new(1, 0, 0), 3.5)
			end
		end)
	end
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "ShenLakeCrack"
	flash.Brightness, flash.TintColor = Effects.flash(0.38), rgb(226, 236, 255)
	flash.Parent = Lighting
	local t = TweenService:Create(flash, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0, TintColor = rgb(255, 255, 255) })
	self.Flash, self.FlashTween = flash, t
	t:Play()
	self:Later(1, function()
		t:Destroy()
		flash:Destroy()
		self.Flash, self.FlashTween = nil, nil
	end)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do (e :: any)[k] = v end
	e.Parent = parent
	return e
end

-- The storm at the lake's base. `full` (server time) = when the howl reaches full strength; nil = already there.
function Controller.Gather(self: any, full: number?)
	if self.Storm then return end
	local reduced = Effects.reduced()
	local centre = vortex()
	local storm = Instance.new("Model")
	storm.Name = "ShenLakeStorm"
	local disc = Instance.new("Part")
	disc.Name, disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.Transparency = "Gather", true, false, false, false, 1
	disc.CastShadow = false
	disc.Size = Vector3.new(Controller.GatherRadius * 2, 1, Controller.GatherRadius * 2)
	disc.CFrame = CFrame.new(centre + Vector3.new(0, 1.5, 0))
	disc.Parent = storm
	local scale = if reduced then 0.4 else 1
	-- Mist torn off the water from a wide ring, rushing inward along the surface.
	emitter(disc, { Name = "Mist", Texture = SMOKE, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 26 * scale, Lifetime = NumberRange.new(2.2, 2.8), Speed = NumberRange.new(28, 36),
		Size = NS({ NK(0, 9), NK(0.6, 14), NK(1, 5) }), Transparency = NS({ NK(0, 1), NK(0.2, 0.62), NK(0.8, 0.7), NK(1, 1) }),
		Color = CS(rgb(196, 208, 214), rgb(150, 164, 172)), LightInfluence = 0.75, LightEmission = 0.05, RotSpeed = NumberRange.new(-90, 90),
		Rotation = NumberRange.new(0, 360), Acceleration = Vector3.new(0, 5, 0), LockedToPart = false })
	-- Red leaves of the Bellwood whipped in with it, spinning.
	emitter(disc, { Name = "Leaves", Texture = LEAF, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 16 * scale, Lifetime = NumberRange.new(2.0, 2.6), Speed = NumberRange.new(30, 40),
		Size = NS(0.9), Transparency = NS({ NK(0, 1), NK(0.1, 0), NK(0.85, 0), NK(1, 1) }), Color = CS(rgb(178, 44, 30), rgb(214, 112, 40)),
		LightInfluence = 1, RotSpeed = NumberRange.new(-400, 400), Rotation = NumberRange.new(0, 360), Acceleration = Vector3.new(0, 9, 0),
		LockedToPart = false })
	-- The turning column it feeds.
	local column = Instance.new("Attachment")
	column.Name, column.Position, column.Parent = "Column", Vector3.new(0, 1, 0), disc
	emitter(column, { Name = "Column", Texture = SMOKE, Rate = 14 * scale, Lifetime = NumberRange.new(3.5, 4.5), Speed = NumberRange.new(16, 24),
		SpreadAngle = Vector2.new(10, 10), Size = NS({ NK(0, 8), NK(0.5, 22), NK(1, 34) }),
		Transparency = NS({ NK(0, 0.8), NK(0.25, 0.55), NK(1, 1) }), Color = CS(rgb(170, 182, 190), rgb(120, 130, 140)), LightInfluence = 0.7,
		RotSpeed = NumberRange.new(60, 140), Rotation = NumberRange.new(0, 360), Drag = 0.6, LockedToPart = false })
	-- Howl: one heard from the water (3D) and, while summoning, one carried through the whole basin (2D) that eases off once stilled.
	local howl = sound(Assets.Audio.AshenStairWind or Assets.Audio.Wind, disc, 0, 0.78, true)
	howl.RollOffMode, howl.RollOffMinDistance, howl.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 60, 1300
	howl:Play()
	self.Howl = howl
	local rise = if full then math.max(0.5, full - Workspace:GetServerTimeNow()) else 0.5
	self:Fade(howl, 2.4, rise)
	if full and self:Near() then
		local gust = sound(Assets.Audio.Wind, SoundService, 0, 0.7, true)
		gust:Play()
		self.Gust = gust
		self:Fade(gust, 1.6, rise)
	end
	storm.Parent = Workspace
	self.Storm = storm
end

-- He steps out: the column falls and the wind dies over a few seconds.
function Controller.Collapse(self: any)
	local storm = self.Storm
	if not storm then return end
	for _, d in storm:GetDescendants() do
		if d:IsA("ParticleEmitter") then d.Rate = 0 end
	end
	self:Fade(self.Howl, 0, 3)
	self:Fade(self.Gust, 0, 2)
	self:Later(5, function() self:ClearStorm() end)
end

function Controller.ClearStorm(self: any)
	self:DestroySound(self.Howl)
	self:DestroySound(self.Gust)
	if self.Storm then self.Storm:Destroy() end
	self.Storm, self.Howl, self.Gust = nil, nil, nil
end

function Controller.Destroy(self: any)
	if not self.Connection then return end
	self.Connection:Disconnect()
	self.Connection = nil
	self:Cancel()
	self:ClearCrack()
	self:ClearStorm()
end

return Controller

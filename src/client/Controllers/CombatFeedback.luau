--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Schema = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.MoveSchema) :: any
local Comfort = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference) :: any
local Feedback = {}
Feedback.__index = Feedback
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
function Feedback.new(state: any, camera: any): any
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
	return setmetatable({ State=state, Camera=camera, Blur=blur, Vignette=gui, VignetteEdges=edges, Frozen={}, Tier="None" }, Feedback)
end
local function animator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
end
function Feedback.HitStop(self: any, models: { Model }, duration: number)
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
function Feedback.Event(self: any, event: any, direction: Vector3)
 local id = self.State.LocalId
 if event.Source ~= id and event.Target ~= id and event.Source ~= self.Camera.Locked and event.Target ~= self.Camera.Locked then return end
 local models: {Model} = {}
 for _, actorId in {event.Source, event.Target} do
  local e = self.State:Get(actorId); if e then table.insert(models, e.Model) end
 end
 if HITSTOP[event.Kind] then self:HitStop(models, HITSTOP[event.Kind]) end
 if WEIGHT[event.Kind] then self.Camera:Impulse(direction, WEIGHT[event.Kind] * (if event.Target == id then 1 else 0.6), FOV_PUNCH[event.Kind]) end
end
function Feedback.Update(self: any, dt: number)
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
	local pulse = if blur > 0 and not Comfort.reducedMotion() then 1 + 0.15 * math.sin(now * 1.4) else 1
	self.BlurTarget = math.clamp(blur * pulse, 0, 14)
	self.Blur.Size += (self.BlurTarget - self.Blur.Size) * math.min(1, dt * 4)
	local transparency = 1 - math.clamp(vignette * 1.1, 0, 0.85)
	for _, edge in self.VignetteEdges do
		edge.BackgroundTransparency += (transparency - edge.BackgroundTransparency) * math.min(1, dt * 3)
	end
end
function Feedback.Destroy(self: any)
 for track, frozen in self.Frozen do if track.IsPlaying then track:AdjustSpeed(frozen.Speed) end end
 table.clear(self.Frozen); self.Blur:Destroy(); self.Vignette:Destroy()
 self.Camera:SetHeadTrauma("None"); self.Camera:SetFovClamp(0); self.Camera:SetSway(0)
end
return Feedback

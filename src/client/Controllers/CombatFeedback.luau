--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Schema = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.MoveSchema) :: any
local Comfort = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference) :: any
local PlaybackScale = require(script.Parent.PlaybackScale)
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
local DUPLICATE_CUE = 0.03 -- one contact can raise several events; between the same two bodies they are one stop
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
	return setmetatable({ State=state, Camera=camera, Blur=blur, Vignette=gui, VignetteEdges=edges, Stops={}, Tier="None" }, Feedback)
end
-- Asks each body's playback owner to freeze its action layer. The owner keeps the clip on the server's timeline, so
-- the frozen time is repaid afterward at a bounded rate; the server's clocks and the body's movement do not stop.
function Feedback.HitStop(self: any, models: { Model }, duration: number, pair: string?)
	local now = os.clock()
	if pair then
		local stop = self.Stops[pair]
		if stop and now - stop.At < DUPLICATE_CUE then
			duration = math.max(duration, stop.Duration)
			now = stop.At
		else
			self.Stops[pair] = { At = now, Duration = duration }
		end
	end
	for _, model in models do
		PlaybackScale.request(model, "HitStop", 0, now + duration)
	end
end
function Feedback.Event(self: any, event: any, direction: Vector3)
 local id = self.State.LocalId
 if event.Source ~= id and event.Target ~= id and event.Source ~= self.Camera.Locked and event.Target ~= self.Camera.Locked then return end
 local models: {Model} = {}
 for _, actorId in {event.Source, event.Target} do
  local e = self.State:Get(actorId); if e then table.insert(models, e.Model) end
 end
 if HITSTOP[event.Kind] then self:HitStop(models, HITSTOP[event.Kind], event.Source .. ":" .. event.Target) end
 if WEIGHT[event.Kind] then self.Camera:Impulse(direction, WEIGHT[event.Kind] * (if event.Target == id then 1 else 0.6), FOV_PUNCH[event.Kind]) end
end
function Feedback.Update(self: any, dt: number)
	local now = os.clock()
	for pair, stop in self.Stops do
		if now - stop.At > 1 then
			self.Stops[pair] = nil
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
 PlaybackScale.clear("HitStop")
 table.clear(self.Frozen); self.Blur:Destroy(); self.Vignette:Destroy()
 self.Camera:SetHeadTrauma("None"); self.Camera:SetFovClamp(0); self.Camera:SetSway(0)
end
return Feedback

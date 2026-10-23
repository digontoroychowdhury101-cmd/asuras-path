--!strict
-- Cinematic camera director for the showcase sorceries. It runs in its own render step after the
-- CameraController has placed the camera, blends from that frame into an authored shot and back,
-- and layers trauma shake on top. The camlock never loses its state, so handing back is seamless.
-- Boss shots and dialogue framing always win; reduced motion skips scripted shots and calms shake.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Effects = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference) :: any
local Cinema = {}

export type Frame = { CFrame: CFrame, Fov: number }
export type Shot = { Start: number, Duration: number, Blend: number, Frame: (number) -> Frame? }
export type Director = {
	Controller: any, Shot: Shot?, Last: Frame?, Weight: number, Rate: number,
	Trauma: number, Decay: number, Power: number, Seed: number, Name: string,
}

local MAX_ANGLE = math.rad(4.5) -- peak shake rotation per axis at trauma 1
local FREQUENCY = 17 -- noise samples per second

function Cinema.new(controller: any): Director
	local self: Director = {
		Controller = controller, Shot = nil, Last = nil, Weight = 0, Rate = 4,
		Trauma = 0, Decay = 1, Power = 2, Seed = math.random() * 100, Name = "AsuraSkillCinema",
	}
	RunService:BindToRenderStep(self.Name, Enum.RenderPriority.Camera.Value + 5, function(dt: number)
		Cinema.step(self, math.min(dt, 0.1))
	end)
	return self
end

-- frame(t) returns the shot's camera at t seconds in; returning nil holds the previous frame.
function Cinema.play(self: Director, frame: (number) -> Frame?, duration: number, blend: number?)
	if Effects.reducedMotion() then return end
	self.Shot = { Start = os.clock(), Duration = duration, Blend = blend or 0.25, Frame = frame }
	self.Rate = 1 / math.max(0.02, blend or 0.25)
end

-- Hands the camera back over `blend` seconds (0 = hard cut back).
function Cinema.release(self: Director, blend: number?)
	self.Shot = nil
	self.Rate = 1 / math.max(0.02, blend or 0.35)
end

-- Trauma 0..1 decaying by `decay` per second; shake strength is trauma ^ power.
function Cinema.shake(self: Director, trauma: number, decay: number?, power: number?)
	self.Trauma = math.clamp(math.max(self.Trauma, Effects.motion(trauma)), 0, 1)
	self.Decay = decay or 1
	self.Power = power or 2
end

local function blocked(controller: any): boolean
	return controller ~= nil and (controller.BossShotState ~= nil or controller.DialogueFrame ~= nil)
end

function Cinema.step(self: Director, dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local shot = self.Shot
	if shot and os.clock() - shot.Start >= shot.Duration then
		Cinema.release(self)
		shot = nil
	end
	local active = shot ~= nil and not blocked(self.Controller)
	self.Weight = math.clamp(self.Weight + (if active then dt else -dt) * self.Rate, 0, 1)
	if shot and active then
		self.Last = shot.Frame(os.clock() - shot.Start) or self.Last
	end
	local frame = self.Last
	if frame and self.Weight > 0 then
		local w = self.Weight * self.Weight * (3 - 2 * self.Weight)
		camera.CFrame = camera.CFrame:Lerp(frame.CFrame, w)
		camera.FieldOfView += (frame.Fov - camera.FieldOfView) * w
	elseif self.Weight <= 0 then
		self.Last = nil
	end
	if self.Trauma > 0 then
		self.Trauma = math.max(0, self.Trauma - dt * self.Decay)
		local s = self.Trauma ^ self.Power
		local t = os.clock() * FREQUENCY
		local pitch = MAX_ANGLE * s * math.noise(self.Seed, t)
		local yaw = MAX_ANGLE * s * math.noise(self.Seed + 1, t)
		local roll = MAX_ANGLE * s * math.noise(self.Seed + 2, t)
		camera.CFrame *= CFrame.Angles(pitch, yaw, roll)
	end
end

-- Pulls an authored eye in front of any wall, roof or rock between it and the subject, so wide
-- shots never end up inside a pavilion. Characters are ignored; spell effects never take queries.
local function clear(from: Vector3, at: Vector3): Vector3
	local params = RaycastParams.new()
	local ignore = {}
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then table.insert(ignore, player.Character) end
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(at, from - at, params)
	return if hit then hit.Position + (at - from).Unit * 1.5 else from
end

-- Helpers for authored frames. Dutch tilt rolls the camera around its own look axis.
function Cinema.look(from: Vector3, at: Vector3, fov: number, dutchDegrees: number?): Frame
	return { CFrame = CFrame.lookAt(clear(from, at), at) * CFrame.Angles(0, 0, math.rad(dutchDegrees or 0)), Fov = fov }
end

function Cinema.destroy(self: Director)
	RunService:UnbindFromRenderStep(self.Name)
	self.Shot, self.Last, self.Trauma = nil, nil, 0
end

return table.freeze(Cinema)

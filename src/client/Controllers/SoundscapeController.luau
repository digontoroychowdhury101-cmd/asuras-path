--!strict
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Tween = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local World = require(Shared.Shared.WorldDefinitions)
local Profiles = require(Shared.Shared.EnvironmentProfiles)
local Audio = require(script.Parent.SpatialAudio)
local Wind = require(Shared.Shared.Wind)
local Overworld = require(Shared.Shared.Overworld)
local gate = Overworld.Vesperhold
local ridge = CFrame.new(gate.X, gate.Y, gate.Z) * CFrame.Angles(0, math.rad(gate.Yaw), 0)
-- Distance tests use the same rolloff as the played voice. The bell carries across the fork.
local ridgeCues = {
	{ Key = "Bell", Position = ridge * Vector3.new(-57, 71, -170), Range = 710, Gain = 0.38, Delay = 41 },
	{ Key = "VesperTimber", Position = ridge * Vector3.new(104, -11, 87), Range = 115, Gain = 0.32, Delay = 19 },
	{ Key = "VesperRaven", Position = ridge * Vector3.new(-47, -15, 414), Range = 205, Gain = 0.31, Delay = 29 },
}
local Controller = {}
Controller.__index = Controller
local function stop(s: Sound?)
	if not s or not s.Parent then return end
	local tween = Tween:Create(s, TweenInfo.new(0.7), { Volume = 0 })
	tween.Completed:Once(function() s:Destroy() end); tween:Play()
end
-- Overworld: loudness follows the one wind sample; the lobby and domain (no weather wind) keep their fixed levels.
local function windVolume(self: any, region: string): number
	local w = if self.Weather then self.Weather.Wind else nil
	return if w then Wind.ambience(w) elseif region == "Sanctuary" then 0.12 else 0.22
end
function Controller.new(state: any, movement: any, weather: any?): any
	return setmetatable({ State = state, Movement = movement, Weather = weather, LastMovement = "", Loop = nil,
		Region = "", Ambient = nil, Water = nil, Tick = 0, BellAt = 9, RidgeAt = { 9, 5, 7 }, Time = 0 }, Controller)
end
function Controller.Update(self: any, dt: number)
	self.Time += dt; self.Tick += dt
	if self.Tick < 0.15 then return end
	self.Tick = 0
	local own = self.State:Own()
	if not own or not own.Root then
		stop(self.Loop); self.Loop = nil; self.LastMovement = ""; return
	end
	local p = own.Root.Position
	local region = World.regionAt(p.X, p.Y, p.Z) or tostring(Players.LocalPlayer:GetAttribute("AsuraRegion") or "Sanctuary")
	local insideKeep = region == "Snowfields" and p.X > gate.X + 120 and p.X < gate.X + 419
		and math.abs(p.Z - gate.Z) < 45 and p.Y >= gate.Y
	Audio.zone(if insideKeep then "Cloister" else Profiles.acoustics(region, p))
	if region == "Snowfields" and Overworld.vesperholdWeight(p.X, p.Z) > 0 then
		for i, cue in ridgeCues do
			if self.Time >= self.RidgeAt[i] and (p - cue.Position).Magnitude < cue.Range then
				local sound = Audio.at(cue.Key, cue.Position, cue.Gain)
				if sound then
					sound.RollOffMaxDistance = cue.Range
					sound.RollOffMinDistance = if i == 1 then 85 else 14
				end
				self.RidgeAt[i] = self.Time + cue.Delay + math.random() * 9
			end
		end
	end
	if region ~= self.Region then
		self.Region = region; stop(self.Ambient); stop(self.Water)
		self.Ambient = Audio.play("Wind", SoundService, windVolume(self, region), true)
		self.Water = nil
	elseif self.Ambient and self.Ambient.Parent then
		self.Ambient.Volume = windVolume(self, region)
	end
	-- Water and bells are positioned in world space, so turning the camera changes their direction.
	if region == "DesecratedMonastery" and self.Time >= self.BellAt then
		self.BellAt = self.Time + 18 + math.random() * 14
		Audio.at("Bell", Vector3.new(-62, 18, -820), 0.45)
	end
	local nearWater = region == "DesecratedMonastery" and p.Z < -940 and p.Z > -1080
	if nearWater and not self.Water then
		-- SpatialAudio owns the source part, so stopping the loop cannot re-enter its destruction.
		self.Water = Audio.at("Water", Vector3.new(55, 1, -1015), 0.3, true)
	elseif not nearWater and self.Water then stop(self.Water); self.Water = nil end
	local active = own.Snapshot == nil or own.Snapshot.State ~= "KO"
	local move = if active then self.Movement.State else ""
	if move ~= self.LastMovement then
		stop(self.Loop); self.Loop = nil; self.LastMovement = move
		if move == "BulletJumping" then Audio.play("BulletJump", own.Root, 0.65)
		elseif move == "Gliding" or move == "Sliding" then
			self.Loop = Audio.play(if move == "Gliding" then "Glide" else "Slide", own.Root, 0.3, true)
		end
	end
end
function Controller.Destroy(self: any)
	if self.Loop then self.Loop:Destroy() end
	if self.Ambient then self.Ambient:Destroy() end
	if self.Water then self.Water:Destroy() end
	Audio.destroy()
end
return Controller

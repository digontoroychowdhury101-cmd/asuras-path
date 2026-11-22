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
local LandmarkLayout = require(Shared.Shared.LandmarkLayout)
local VesperholdLayout = require(Shared.Shared.VesperholdLayout)
local gate = Overworld.Vesperhold
local ridge = CFrame.new(gate.X, gate.Y, gate.Z) * CFrame.Angles(0, math.rad(gate.Yaw), 0)
-- Distance tests use the same rolloff as the played voice. The bell carries across the fork.
local ridgeCues = {
	{ Key = "VesperBellGreat", Position = ridge * Vector3.new(-57, 71, -170), Range = 710, Min = 85, Gain = 0.45, Delay = 41 },
	{ Key = "VesperBellDistant", Position = ridge * Vector3.new(-57, 71, -170), Range = 900, Min = 120, Gain = 0.30, Delay = 60, Distant = true },
	{ Key = "VesperTimber", Position = ridge * Vector3.new(104, -11, 87), Range = 115, Gain = 0.32, Delay = 19 },
	{ Key = "VesperRaven", Position = ridge * Vector3.new(-47, -15, 414), Range = 205, Gain = 0.31, Delay = 29 },
	{ Key = "VesperChain", Position = ridge * Vector3.new(104, -11, 87), Range = 90, Gain = 0.35, Delay = 31 },
}
local bellwood = LandmarkLayout.Landmarks.Bellwood
local basin = bellwood.Basin
local basinCentre = LandmarkLayout.basinCentre(bellwood)
local face = CFrame.new(bellwood.Origin.X, bellwood.Origin.Y, bellwood.Origin.Z) * CFrame.Angles(0, math.rad(bellwood.Yaw), 0)
local basinBed, basinWater = LandmarkLayout.basinLevels(bellwood)
local basinGate, basinTemple = LandmarkLayout.gateSpot(bellwood), LandmarkLayout.templeSpot(bellwood)
local ribbons = Vector3.new(basinGate.X, basinGate.Y + 17, basinGate.Z)
local chimes = Vector3.new(basinTemple.X, basinTemple.Y + 18, basinTemple.Z)
local tunnel = bellwood.Tunnel.Path
local torchPositions = {}
for _, light in VesperholdLayout.Firelight do
	if light[1] == "Brazier" then
		table.insert(torchPositions, ridge * Vector3.new(light[2], light[3] + 3, light[4]))
	end
end
local ice = Overworld.Nodes.S4_LakeMargin.Position
local nearIce = Vector3.new(ice.X, ice.Y, ice.Z)
local ravine = Overworld.Nodes.G3_Crossing.Position
local ravineSound = Vector3.new(ravine.X, ravine.Y - 50, ravine.Z)
local crypt = ridge * Vector3.new(570, 286, -332)
local ambientKeys = { Snowfields = "FrostmereBlizzard", MountainAscent = "AshenStairWind" }
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

local function setLoop(self: any, key: string, enabled: boolean, gain: number, at: Vector3?, min: number?, max: number?)
	local sound = self.EnvironmentLoops[key]
	if not enabled then
		stop(sound)
		self.EnvironmentLoops[key] = nil
		return
	end
	if not sound or not sound.Parent then
		sound = if at then Audio.at(key, at, gain, true) else Audio.play(key, SoundService, gain, true)
		self.EnvironmentLoops[key] = sound
		if sound and max then
			sound.RollOffMinDistance = min or 7
			sound.RollOffMaxDistance = max
		end
	elseif at then
		local source = sound.Parent
		if source and source:IsA("BasePart") then source.Position = at end
	end
end

local function nearestTorch(position: Vector3): Vector3?
	local nearest, best = nil, 45
	for _, at in torchPositions do
		local d = (position - at).Magnitude
		if d < best then nearest, best = at, d end
	end
	return nearest
end

local function tunnelSource(p: Vector3): Vector3?
	local nearest, best = nil, 30
	for i = 3, #tunnel do
		local point = tunnel[i]
		local at = face:PointToWorldSpace(Vector3.new(-point[1], point[3], point[2]))
		local distance = (p - at).Magnitude
		if distance < best then nearest, best = at, distance end
	end
	return nearest
end

local function updateEnvironment(self: any, position: Vector3, region: string, insideKeep: boolean, ridgeWeight: number)
	local rain = Players.LocalPlayer:GetAttribute("AsuraWeather") == "Rain"
	local ellipse = LandmarkLayout.basinEllipse(bellwood, position.X, position.Z)
	local nearBasin = region == "Forest" and ellipse <= 1 and position.Y >= basinBed - basin.Deep - 8
		and position.Y <= basinWater + basin.TempleTop
	local tunnelAt = if region == "Forest" and rain then tunnelSource(position) else nil
	local map = if nearBasin or tunnelAt then workspace:FindFirstChild(Overworld.Root) else nil
	local forest = map and map:FindFirstChild(bellwood.Region)
	local landmark = forest and forest:FindFirstChild("Landmark_Bellwood")
	local atBasin = nearBasin and landmark ~= nil and landmark:GetAttribute("BasinSculpted") == true
	local ambient = if atBasin then "BasinBirdsInsects" elseif ridgeWeight > 0.3 then "VesperWindSpires" else ambientKeys[region] or "Wind"
	if ambient ~= "Wind" and Audio.id(ambient) == "" then ambient = "Wind" end
	local gain = if ambient == "Wind" then windVolume(self, region) else 0.30
	if self.AmbientKey ~= ambient or not (self.Ambient and self.Ambient.Parent) then
		stop(self.Ambient)
		self.Ambient = Audio.play(ambient, SoundService, gain, true)
		self.AmbientKey = ambient
	elseif ambient == "Wind" then
		self.Ambient.Volume = gain
	end

	setLoop(self, "VesperRain", ridgeWeight > 0 and rain, 0.28)
	setLoop(self, "VesperChoir", insideKeep and ridgeWeight > 0, 0.16)
	local torch = if ridgeWeight > 0 then nearestTorch(position) else nil
	setLoop(self, "VesperTorch", torch ~= nil, 0.34, torch, 6, 45)
	setLoop(self, "VesperCryptDrips", region == "Snowfields" and (position - crypt).Magnitude < 60, 0.48, crypt, 8, 60)
	setLoop(self, "BasinRainTunnel", tunnelAt ~= nil and landmark ~= nil and landmark:GetAttribute("BoreCarved") == true, 0.40, tunnelAt, 10, 70)
	local shore: Vector3? = nil
	if atBasin and ellipse > 1e-4 then
		local r = 1 / math.sqrt(ellipse)
		shore = Vector3.new(basinCentre.X + (position.X - basinCentre.X) * r, basinWater,
			basinCentre.Z + (position.Z - basinCentre.Z) * r)
	end
	setLoop(self, "BasinLake", shore ~= nil and (position - (shore :: Vector3)).Magnitude < 82, 0.40, shore, 8, 82)
	setLoop(self, "BasinRibbons", atBasin and (position - ribbons).Magnitude < 38, 0.26, ribbons, 5, 38)
	setLoop(self, "BasinChimes", atBasin and (position - chimes).Magnitude < 45, 0.23, chimes, 5, 45)
	setLoop(self, "AmberfallRoar", region == "GoldenRavine" and (position - ravineSound).Magnitude < 250, 0.25, ravineSound, 30, 250)
	local sea: Vector3? = nil
	if region == "AridBasin" then
		local frame = Overworld.Frame
		local candidate = if position.X - frame.MinX < frame.MaxZ - position.Z
			then Vector3.new(frame.MinX + 32, frame.WaterY, position.Z)
			else Vector3.new(position.X, frame.WaterY, frame.MaxZ - 32)
		if (position - candidate).Magnitude < 200 and Overworld.heightAt(candidate.X, candidate.Z) < candidate.Y then
			sea = candidate
		end
	end
	setLoop(self, "SaltreachSurf", sea ~= nil, 0.36, sea, 20, 200)
	if region == "Snowfields" and self.Time >= self.IceAt and (position - nearIce).Magnitude < 200 then
		local sound = Audio.at("FrostmereIceCrack", nearIce, 0.40)
		if sound then sound.RollOffMinDistance, sound.RollOffMaxDistance = 20, 200 end
		self.IceAt = self.Time + 28 + math.random() * 15
	end
end

function Controller.new(state: any, movement: any, weather: any?): any
	return setmetatable({ State = state, Movement = movement, Weather = weather, LastMovement = "", Loop = nil,
		Ambient = nil, AmbientKey = nil, EnvironmentLoops = {}, Water = nil, Tick = 0,
		BellAt = 9, IceAt = 17, RidgeAt = { 9, 23, 5, 7, 13 }, Time = 0 }, Controller)
end
function Controller.Update(self: any, dt: number)
	self.Time += dt; self.Tick += dt
	if self.Tick < 0.15 then return end
	self.Tick = 0
	local own = self.State:Own()
	if not own or not own.Root then
		stop(self.Loop); stop(self.Ambient); stop(self.Water)
		self.Loop, self.Ambient, self.Water, self.LastMovement = nil, nil, nil, ""
		for _, sound in self.EnvironmentLoops do stop(sound) end
		table.clear(self.EnvironmentLoops)
		return
	end
	local p = own.Root.Position
	local region = World.regionAt(p.X, p.Y, p.Z) or tostring(Players.LocalPlayer:GetAttribute("AsuraRegion") or "Sanctuary")
	local insideKeep = region == "Snowfields" and p.X > gate.X + 120 and p.X < gate.X + 419
		and math.abs(p.Z - gate.Z) < 45 and p.Y >= gate.Y
	Audio.zone(if insideKeep then "Cloister" else Profiles.acoustics(region, p))
	local ridgeWeight = if region == "Snowfields" then Overworld.vesperholdWeight(p.X, p.Z) else 0
	if region == "Snowfields" then
		for i, cue in ridgeCues do
			local audible = if cue.Distant then ridgeWeight <= 0.3 else ridgeWeight > 0
			if audible and self.Time >= self.RidgeAt[i] and (p - cue.Position).Magnitude < cue.Range then
				local sound = Audio.at(cue.Key, cue.Position, cue.Gain)
				if sound then
					sound.RollOffMaxDistance = cue.Range
					sound.RollOffMinDistance = cue.Min or 14
				end
				self.RidgeAt[i] = self.Time + cue.Delay + math.random() * 9
			end
		end
	end
	updateEnvironment(self, p, region, insideKeep, ridgeWeight)
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
	for _, sound in self.EnvironmentLoops do sound:Destroy() end
	table.clear(self.EnvironmentLoops)
	Audio.destroy()
end
return Controller

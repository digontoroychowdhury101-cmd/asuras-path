--!strict
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Profiles = require(Shared.Shared.EnvironmentProfiles)
local Assets = require(Shared.Shared.PresentationAssets)
local World = require(Shared.Shared.WorldDefinitions)
local Layout = require(Shared.Shared.LandmarkLayout) :: any
local Ash = require(script.Parent.ArenaAsh)
local Controller = {}
Controller.__index = Controller

function Controller.new(state: any, weather: any?): any
	local self = setmetatable({ State = state, Weather = weather, Key = "", Elapsed = 1, Phase = 1, Boss = "", Tweens = {} }, Controller)
	self.Ash = Ash.new()
	self.Sky = {}
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then for _, face in {"Bk","Dn","Ft","Lf","Rt","Up"} do self.Sky[face] = (sky :: any)["Skybox"..face] end end
	self.Disconnect = state:OnCue(function(cue: any)
		if cue.Kind == "BossPhase" and Players.LocalPlayer:GetAttribute("AsuraEncounter") == cue.Data.boss then
			self.Phase = math.max(self.Phase, tonumber(cue.Data.phase) or 1)
		end
	end)
	return self
end
local function applySky(self: any, key: string)
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		local kind = Profiles.skyFor(key)
		local night = kind == "Night"
		sky.CelestialBodiesShown = not night
		sky.StarCount = if sky.CelestialBodiesShown then 500 else 0
		local set = if night then Assets.Sky elseif kind == "Sunset" then Assets.SunsetSky else nil
		for face, suffix in {Back="Bk",Down="Dn",Front="Ft",Left="Lf",Right="Rt",Up="Up"} do
			local id = if set then set[face] else nil
			local value=if id and id~="" then id else self.Sky[suffix]
			if value then (sky :: any)["Skybox"..suffix]=value end
		end
	end
end
-- Inside the Hollow's vault: no sky at all, and no global shadows, since the vault would shadow every surface even where the
-- engine culls it from view (mac-97). The sky still lights PBR stone: pure black left the temple a dark mass, so all six faces take one
-- flat dark-teal image with soft mottling (win-83, uploaded 2026-11-23, decal 111215040387593), the colour of the vault's glow.
local CAVE_SKY = "rbxassetid://83866687618973"
local function setCave(self: any, cave: boolean)
	if cave == (self.Cave == true) then return end
	self.Cave = cave
	if cave then
		self.Shadows = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then
			sky.CelestialBodiesShown, sky.StarCount = false, 0
			for _, suffix in {"Bk","Dn","Ft","Lf","Rt","Up"} do (sky :: any)["Skybox"..suffix] = CAVE_SKY end
		end
	else
		Lighting.GlobalShadows = if self.Shadows == nil then true else self.Shadows
	end
end
function Controller.Update(self: any, dt: number)
	local actor = self.State:Own()
	self.Ash:Update(dt,if actor and actor.Root then actor.Root.Position else nil,self.Key)
	self.Elapsed += dt
	if self.Elapsed < 0.2 then return end
	self.Elapsed = 0
	local own = self.State:Own()
	if not own or not own.Root then return end
	local boss = Players.LocalPlayer:GetAttribute("AsuraEncounter") or ""
	if boss ~= self.Boss then self.Boss, self.Phase = boss, 1 end
	for _, e in self.State.Entities do
		if boss ~= "" and e.Model:GetAttribute("AsuraEncounter") == boss then
			self.Phase = math.max(self.Phase, tonumber(e.Model:GetAttribute("AsuraBossPhase")) or 1)
		end
	end
	local p = own.Root.Position
	if not self.HollowFetch then
		-- Fetched only on sight, the Hollow temple's ~600 maps rendered white for ~30 s (win-85): start the download on the approach.
		local bw = Layout.Landmarks.Bellwood
		local c = Layout.basinCentre(bw)
		if (p.X - c.X) ^ 2 + (p.Z - c.Z) ^ 2 < bw.Basin.Cavern.Preload ^ 2 then
			self.HollowFetch = true
			task.spawn(function()
				local maps = Layout.hollowMaps(require(Shared.Shared.LandmarkKitRegistry) :: any)
				pcall(function() game:GetService("ContentProvider"):PreloadAsync(maps) end)
			end)
		end
	end
	local reported = Players.LocalPlayer:GetAttribute("AsuraRegion")
	local region = World.regionAt(p.X, p.Y, p.Z) or (if type(reported)=="string" then reported else nil)
	local alive = own.Snapshot == nil or own.Snapshot.State ~= "KO"
	-- The fight takes its look from the boss arena's biome, never one shared night profile.
	local definition = if boss ~= "" then World.Bosses[boss] else nil
	local arena = if definition then definition.Region else nil
	local key = Profiles.resolve(region, boss ~= "" and alive, self.Phase, arena)
	-- Open overworld: the composed biome/time/weather profile (nil in the lobby, the domain and fights, which keep the keyed path below).
	local composed = if self.Weather then self.Weather:Profile(if boss ~= "" and alive then { Phase = self.Phase, Arena = arena } else nil) else nil
	local cave = (if self.Weather then self.Weather.Cavern or 0 else 0) >= 0.5
	local leavingCave = self.Cave == true and not cave
	setCave(self, cave)
	if composed then
		local entering = self.Key ~= "Weather"
		self.Key = "Weather"
		for _, tween in self.Tweens do tween:Cancel() end
		table.clear(self.Tweens)
		for name, values in composed do
			local target = if name == "Lighting" then Lighting else Lighting:FindFirstChild(name)
			if not target then continue end
			if name == "Lighting" and math.abs(values.ClockTime - Lighting.ClockTime) > 12 then
				-- The clock wraps at midnight: snap instead of tweening the long way round through the day.
				Lighting.ClockTime = values.ClockTime
				values = table.clone(values); values.ClockTime = nil
			end
			local tween = TweenService:Create(target, TweenInfo.new(if entering then 2.4 else 0.4, Enum.EasingStyle.Sine), values)
			table.insert(self.Tweens, tween); tween:Play()
		end
		if (entering or leavingCave) and not cave then applySky(self, "Weather") end
		return
	end
	if key == self.Key then
		if leavingCave then applySky(self, key) end
		return
	end
	self.Key = key
	for _, tween in self.Tweens do tween:Cancel() end
	table.clear(self.Tweens)
	for _, light in CollectionService:GetTagged("AsuraArenaLight") do
		local tween=TweenService:Create(light,TweenInfo.new(1.8),{Color=if Profiles.isUnbound(key) then Profiles.UnboundBrazier else Profiles.arena(arena).Brazier})
		table.insert(self.Tweens,tween);tween:Play()
	end
	for name, values in Profiles.get(key) do
		local target = if name == "Lighting" then Lighting else Lighting:FindFirstChild(name)
		if target then
			local tween = TweenService:Create(target, TweenInfo.new(2.4, Enum.EasingStyle.Sine), values)
			table.insert(self.Tweens, tween); tween:Play()
		end
	end
	if not cave then applySky(self, key) end
end
function Controller.Destroy(self: any)
	self.Disconnect()
	self.Ash:Destroy()
	for _, tween in self.Tweens do tween:Cancel() end
end
return Controller

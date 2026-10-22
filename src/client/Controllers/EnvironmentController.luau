--!strict
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Profiles = require(Shared.Shared.EnvironmentProfiles)
local Assets = require(Shared.Shared.PresentationAssets)
local World = require(Shared.Shared.WorldDefinitions)
local Ash = require(script.Parent.ArenaAsh)
local Controller = {}
Controller.__index = Controller

function Controller.new(state: any): any
	local self = setmetatable({ State = state, Key = "", Elapsed = 1, Phase = 1, Boss = "", Tweens = {} }, Controller)
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
	local reported = Players.LocalPlayer:GetAttribute("AsuraRegion")
	local region = World.regionAt(p.X, p.Y, p.Z) or (if type(reported)=="string" then reported else nil)
	local alive = own.Snapshot == nil or own.Snapshot.State ~= "KO"
	-- The fight takes its look from the boss arena's biome, never one shared night profile.
	local definition = if boss ~= "" then World.Bosses[boss] else nil
	local arena = if definition then definition.Region else nil
	local key = Profiles.resolve(region, boss ~= "" and alive, self.Phase, arena)
	if key == self.Key then return end
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
function Controller.Destroy(self: any)
	self.Disconnect()
	self.Ash:Destroy()
	for _, tween in self.Tweens do tween:Cancel() end
end
return Controller

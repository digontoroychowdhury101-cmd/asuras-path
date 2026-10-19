--!strict
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Profiles = require(Shared.Shared.EnvironmentProfiles)
local Assets = require(Shared.Shared.PresentationAssets)
local World = require(Shared.Shared.WorldDefinitions)
local Controller = {}
Controller.__index = Controller

function Controller.new(state: any): any
	local self = setmetatable({ State = state, Key = "", Elapsed = 1, Phase = 1, Boss = "", Tweens = {} }, Controller)
	self.Disconnect = state:OnCue(function(cue: any)
		if cue.Kind == "BossPhase" and Players.LocalPlayer:GetAttribute("AsuraEncounter") == cue.Data.boss then
			self.Phase = math.max(self.Phase, tonumber(cue.Data.phase) or 1)
		end
	end)
	return self
end
function Controller.Update(self: any, dt: number)
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
	local region = World.regionAt(p.X, p.Y, p.Z) or Players.LocalPlayer:GetAttribute("AsuraRegion")
	local alive = own.Snapshot == nil or own.Snapshot.State ~= "KO"
	local key = Profiles.resolve(region, boss ~= "" and alive, self.Phase)
	if key == self.Key then return end
	self.Key = key
	for _, tween in self.Tweens do tween:Cancel() end
	table.clear(self.Tweens)
	for name, values in (Profiles :: any)[key] do
		local target = if name == "Lighting" then Lighting else Lighting:FindFirstChild(name)
		if target then
			local tween = TweenService:Create(target, TweenInfo.new(2.4, Enum.EasingStyle.Sine), values)
			table.insert(self.Tweens, tween); tween:Play()
		end
	end
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.CelestialBodiesShown = key ~= "Cataclysm" and key ~= "AshColosseum"
		sky.StarCount = if sky.CelestialBodiesShown then 500 else 0
		for face, id in Assets.Sky do
			if id ~= "" then (sky :: any)["Skybox" .. ({Back="Bk",Down="Dn",Front="Ft",Left="Lf",Right="Rt",Up="Up"})[face]] = id end
		end
	end
end
function Controller.Destroy(self: any)
	self.Disconnect()
	for _, tween in self.Tweens do tween:Cancel() end
end
return Controller

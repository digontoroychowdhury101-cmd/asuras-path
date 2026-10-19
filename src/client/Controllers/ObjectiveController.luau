--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ObjectiveController
-- HUD objective tracker: a top-right "next step" card plus a WaypointMarker, both derived from
-- replicated player attributes via the pure Shared.Objectives resolver.
-- Presentation only — it never sends intents.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Objectives = require(ReplicatedStorage:WaitForChild("AsurasPath"):WaitForChild("Shared"):WaitForChild("Objectives") :: ModuleScript)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local WaypointMarker = require(script.Parent:WaitForChild("WaypointMarker") :: ModuleScript)
local WorldState = require(script.Parent:WaitForChild("WorldStateController") :: ModuleScript)

local P = HudKit.Palette
local REFRESH = 0.2

local Controller = {}
Controller.__index = Controller

export type ObjectiveController = typeof(setmetatable({} :: {
	Player: Player,
	Ui: any,
	Panel: Frame,
	Header: TextLabel,
	Title: TextLabel,
	Detail: TextLabel,
	Distance: TextLabel,
	Marker: WaypointMarker.WaypointMarker,
	Current: Objectives.Objective?,
	Rested: boolean,
	BossFelled: boolean,
	PendingRegion: string?,
	Elapsed: number,
	Cleanup: { () -> () },
}, Controller))

function Controller.new(state: WorldState.WorldState, ui: any): ObjectiveController
	local player = Players.LocalPlayer
	local panel = HudKit.panel(ui.Gui, "ObjectiveTracker", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 64), Size = UDim2.fromOffset(360, 92), Visible = false })
	HudKit.make("UIPadding", panel, { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 8) })
	local header = HudKit.label(panel, "OBJECTIVE", 14, HudKit.TitleFont, P.Ember, { Size = UDim2.new(1, -60, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
	local distance = HudKit.label(panel, "", 14, Enum.Font.GothamMedium, P.Muted, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(60, 18), TextXAlignment = Enum.TextXAlignment.Right })
	local title = HudKit.label(panel, "", 22, HudKit.TitleFont, P.Ivory, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	HudKit.make("UITextSizeConstraint", title, { MaxTextSize = 22, MinTextSize = 12 })
	local detail = HudKit.label(panel, "", 16, HudKit.BodyFont, P.Muted, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true })

	local self = setmetatable({
		Player = player, Ui = ui, Panel = panel, Header = header, Title = title, Detail = detail, Distance = distance,
		Marker = WaypointMarker.new(ui.Gui), Current = nil, Rested = false, BossFelled = false, PendingRegion = nil,
		Elapsed = REFRESH, Cleanup = {},
	}, Controller)
	table.insert(self.Cleanup, HudKit.bindScale(panel, 0.8))
	local regionConnection = player:GetAttributeChangedSignal("AsuraRegion"):Connect(function()
		self.PendingRegion = nil
	end)
	table.insert(self.Cleanup, function()
		regionConnection:Disconnect()
	end)
	table.insert(self.Cleanup, state:OnCue(function(cue: WorldState.Cue)
		-- Resting, or leaving the Sanctuary, ends the first-rest step.
		if cue.Source == state.LocalId and (cue.Kind == "AltarRest" or cue.Kind == "PortalTransit" or cue.Kind == "AltarTravel") then
			self.Rested = true
			-- AsuraRegion lags a teleport; trust the cue's destination until it catches up.
			local destination = Objectives.regionOf(tostring(cue.Data.to or ""))
			if cue.Kind ~= "AltarRest" and destination then
				self.PendingRegion = destination
			end
		elseif cue.Kind == "BossDefeated" and cue.Data.boss == "GrandmasterShen" then
			self.BossFelled = true
		end
		self.Elapsed = REFRESH
	end))
	return self
end

function Controller.Facts(self: ObjectiveController): Objectives.Facts
	local player = self.Player
	local region = player:GetAttribute("AsuraRegion")
	local stain = player:GetAttribute("AsuraBloodstain")
	local bosses = Objectives.parseAltars(player:GetAttribute("AsuraBosses"))
	return {
		Bosses = bosses,
		Region = self.PendingRegion or (if type(region) == "string" then region else nil),
		Altars = Objectives.parseAltars(player:GetAttribute("AsuraAltars")),
		Bloodstain = if typeof(stain) == "Vector3" then stain else nil,
		InBoss = self.Ui.BossEntity ~= nil,
		InColosseum = type(player:GetAttribute("AsuraColosseum")) == "string",
		BossFelled = self.BossFelled or bosses.GrandmasterShen == true,
		Rested = self.Rested,
	}
end

function Controller.Show(self: ObjectiveController, objective: Objectives.Objective?)
	local previous = self.Current
	self.Current = objective
	self.Panel.Visible = objective ~= nil
	if not objective then
		return
	end
	self.Title.Text = objective.Title
	self.Detail.Text = objective.Detail
	if previous and previous.Key ~= objective.Key then
		self.Header.Text = "NEW OBJECTIVE"
		self.Panel.BackgroundTransparency = 0
		TweenService:Create(self.Panel, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { BackgroundTransparency = 0.25 }):Play()
		HudKit.cue(HudKit.Sounds.Objective, 0.5, 1.2)
		task.delay(3, function()
			if self.Current == objective then
				self.Header.Text = "OBJECTIVE"
			end
		end)
	end
end

function Controller.Update(self: ObjectiveController, dt: number)
	self.Elapsed += dt
	if self.Elapsed < REFRESH then
		return
	end
	self.Elapsed = 0
	local objective = Objectives.resolve(self:Facts())
	if objective == nil or self.Current == nil or objective.Key ~= self.Current.Key then
		self:Show(objective)
	end
	local character = self.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local goal = if objective then self.Marker:Locate(objective.Target) else nil
	local meters = self.Marker:Point(goal, if root then root.Position else nil, self.Ui.Altar.Visible)
	self.Distance.Text = if meters then string.format("%dm", meters) else ""
end

function Controller.Destroy(self: ObjectiveController)
	for _, cleanup in self.Cleanup do
		cleanup()
	end
	self.Marker:Destroy()
	self.Panel:Destroy()
end

return Controller

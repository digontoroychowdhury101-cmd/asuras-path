--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/CombatHud
-- Owns the fight-readability layer: the keybind ActionBar, overhead EnemyBars with attack
-- warnings, CombatCallouts (damage numbers, PARRY / BLOCKED pops, guard emblem) and the top
-- TargetPlate for whoever you are fighting. HudVisibility hides it for the prologue, death and
-- dialogue (and hides world prompts with it); the focused foe's overhead plate drops to its warning.
local Workspace = game:GetService("Workspace")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local ActionBar = require(script.Parent:WaitForChild("ActionBar") :: ModuleScript)
local EnemyBars = require(script.Parent:WaitForChild("EnemyBars") :: ModuleScript)
local Callouts = require(script.Parent:WaitForChild("CombatCallouts") :: ModuleScript)
local TargetPlate = require(script.Parent:WaitForChild("TargetPlate") :: ModuleScript)
local Visibility = require(script.Parent:WaitForChild("HudVisibility") :: ModuleScript)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath").Shared
local BossRules = require(Shared.BossEncounterRules)
local TutorialRules = require(Shared.TutorialRules)

local Controller = {}
Controller.__index = Controller

-- Customization ------------------------------------------------------------------------------
local FOCUS_SECONDS = 8 -- how long the target plate follows the last foe you traded blows with
local taught: { [string]: number } = {} -- boss counters warned this session (hint on the first few)

export type CombatHud = typeof(setmetatable({} :: {
	State: any, Camera: any, Input: any, Ui: any, Bar: ActionBar.View, Bars: EnemyBars.View, Callouts: Callouts.View,
	Target: TargetPlate.View, FocusId: number, FocusUntil: number, Disconnects: { () -> () }, PreviousCommand: any,
}, Controller))

function Controller.new(state: any, camera: any, input: any, ui: any): CombatHud
	local gui = ui.Gui :: ScreenGui
	local self = setmetatable({
		State = state, Camera = camera, Input = input, Ui = ui,
		Bar = ActionBar.new(gui), Bars = EnemyBars.new(gui, state), Callouts = Callouts.new(gui, state), Target = TargetPlate.new(gui),
		FocusId = 0, FocusUntil = 0, Disconnects = {}, PreviousCommand = input.OnCommand,
	}, Controller)
	self.Target.Root.Destroying:Once(HudKit.bindScale(self.Target.Root, 0.9))
	table.insert(self.Disconnects, state:OnEvent(function(event)
		local foe = Callouts.event(self.Callouts, event)
		if foe and foe ~= 0 then self.FocusId, self.FocusUntil = foe, os.clock() + FOCUS_SECONDS end
	end))
	table.insert(self.Disconnects, state:OnCue(function(cue)
		local entity = if cue.Kind == "Telegraph" then state:Get(cue.Source) else nil
		if entity then EnemyBars.cue(self.Bars, entity, cue.Data) end
		local data = cue.Data
		local mine = entity ~= nil and ui.BossId ~= nil and entity.Model:GetAttribute("AsuraEncounter") == ui.BossId
		if mine and type(data.counter) == "string" and type(data.impact) == "number" and Visibility.of(ui).Combat then
			local count = (taught[data.counter] or 0) + 1
			taught[data.counter] = count
			local keys = BossRules.CounterKeys[data.counter]
			local hint = if keys and count <= BossRules.CounterHintCount then TutorialRules.text(keys, function(c: string) return input:Hint(c) end) else nil
			Callouts.warn(self.Callouts, data.counter, data.impact - Workspace:GetServerTimeNow(), hint)
		end
	end))
	local previous = self.PreviousCommand
	input.OnCommand = function(command: string)
		if previous then previous(command) end
		ActionBar.press(self.Bar, command)
	end
	return self
end

function Controller.Update(self: CombatHud, dt: number)
	local ui = self.Ui
	local layers = Visibility.apply(ui)
	local hidden = not layers.Combat
	local snapshot = self.State:OwnSnapshot()
	local locked = self.Camera:LockedEntity()
	ActionBar.update(self.Bar, snapshot, self.Input, locked ~= nil)
	if hidden then self.Bar.Root.Visible = false end
	local focus = locked
	if not focus and os.clock() < self.FocusUntil then focus = self.State:Get(self.FocusId) end
	if focus and not self.State:IsAlive(focus) then focus = nil end
	local bossShown = ui.BossFrame ~= nil and ui.BossFrame.Visible
	local plated = not hidden and not bossShown and focus ~= nil and not focus.Boss
	if hidden then EnemyBars.destroy(self.Bars) else EnemyBars.step(self.Bars, dt, locked, if plated then focus else nil) end
	Callouts.step(self.Callouts, dt, snapshot, hidden)
	TargetPlate.update(self.Target, focus, dt, not plated)
end

function Controller.Destroy(self: CombatHud)
	for _, disconnect in self.Disconnects do disconnect() end
	table.clear(self.Disconnects)
	self.Input.OnCommand = self.PreviousCommand
	EnemyBars.destroy(self.Bars)
	Visibility.restore()
	self.Bar.Root:Destroy()
	self.Callouts.Text:Destroy()
	self.Callouts.Guard:Destroy()
	self.Target.Root:Destroy()
end

return Controller

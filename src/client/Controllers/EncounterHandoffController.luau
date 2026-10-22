--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/EncounterHandoffController
-- Client half of the boss-entry contract (BossHandoff, #16). An entry, metamorphosis or oath cue
-- that carries a `shot` frames the boss for exactly that long while the server holds this player
-- locked and protected; combat input is closed for the shot (the guard is released so client and
-- server agree). Any key, button or the Skip pill ends the shot here and sends the Skip intent, so
-- the server ends the lock at the same moment. Reset, leaving, victory and death restore the
-- follow camera and input immediately.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local InputMap = require(Shared.Shared.InputMap)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local Controller = {}
Controller.__index = Controller
local SHOTS = { BossIntro = true, BossPhase = true, BossEnrage = true }
local ENDS = { BossReset = true, BossDefeated = true }

function Controller.new(state: any, camera: any, input: any, ui: any, send: (string) -> ()): any
	local self = setmetatable({ State = state, Camera = camera, Input = input, Ui = ui, Send = send, Active = false,
		Blocked = false, Links = {}, PreviousCommand = input.OnCommand }, Controller)
	local pill = UiKit.button(ui.Gui, "Skip ›", "Ghost", function() self:Skip() end)
	pill.Name, pill.AnchorPoint, pill.Position, pill.Size, pill.Visible = "HandoffSkip", Vector2.new(1, 1), UDim2.new(1, -24, 1, -24), UDim2.fromOffset(150, 34), false
	self.Pill = pill
	input.OnCommand = function(command: string)
		if self.Active and command ~= "Cursor" then self:Skip() end
		if self.PreviousCommand then self.PreviousCommand(command) end
	end
	table.insert(self.Links, state:OnCue(function(cue: any) self:OnCue(cue) end))
	return self
end

function Controller.Involved(self: any, data: any): boolean
	local own = self.State.LocalId
	if type(data.participants) == "table" and table.find(data.participants, own) then return true end
	return data.boss ~= nil and Players.LocalPlayer:GetAttribute("AsuraEncounter") == data.boss
end

function Controller.OnCue(self: any, cue: any)
	local data = cue.Data or {}
	if SHOTS[cue.Kind] and type(data.shot) == "number" and self:Involved(data) then
		self.Camera:BossShot(cue.Source, data.shot)
		self.Active = true
		if not self.Input.MenuOpen then self.Blocked = true; self.Input:SetMenu(true) end
		self.Pill.Text = "Skip ›  " .. self:Key()
		self.Pill.Visible = true
	elseif self.Active and (ENDS[cue.Kind] or (cue.Kind == "BossParticipantLeft" and cue.Source == self.State.LocalId)) then
		self:Finish(true)
	end
end

function Controller.Key(self: any): string
	local key = self.Input:Label("Interact")
	return if key ~= "" then "[" .. key .. "]" else "[" .. InputMap.label("Interact", "Touch") .. "]"
end

function Controller.Skip(self: any)
	if not self.Active then return end
	self.Send("Skip")
	self:Finish(true)
end

-- Restores the follow camera and combat input; `cut` ends the shot now.
function Controller.Finish(self: any, cut: boolean)
	if cut then self.Camera:EndBossShot() end
	self.Active = false
	self.Pill.Visible = false
	if self.Blocked then
		self.Blocked = false
		self.Input:SetMenu(false)
	end
end

function Controller.Update(self: any)
	if not self.Active then return end
	local own = self.State:Own()
	local dead = own and own.Snapshot and own.Snapshot.State == "KO"
	if dead or self.Camera.BossShotState == nil then self:Finish(dead == true) end
end

function Controller.Destroy(self: any)
	if self.Active then self:Finish(true) end
	self.Input.OnCommand = self.PreviousCommand
	for _, unlink in self.Links do unlink() end
	self.Pill:Destroy()
end

return Controller

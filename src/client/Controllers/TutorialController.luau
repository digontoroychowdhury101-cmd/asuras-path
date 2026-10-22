--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/TutorialController
-- The training card for the opening (TutorialRules). Shows the current step with the player's live
-- key captions while they are near the Sparring Phantom on the Monastery Gate landing, ticks steps
-- off when the server confirms them (TutorialStep cue), and reports the two client-only proofs
-- (camera locked on a foe; an Air Glide held for TutorialRules.GlideSeconds). "Skip training"
-- needs a confirming second press; Replay comes from the Respite menu. The recovery-stakes card is
-- shown on completion, on skip, and the first time a newcomer walks into the courtyard.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Rules = require(Shared.Shared.TutorialRules)
local InputMap = require(Shared.Shared.InputMap)
local World = require(Shared.Shared.WorldDefinitions)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local Controller = {}
Controller.__index = Controller
Controller.ShowRadius = 70 -- the card appears near the training landing
local T = UiKit.Theme
local spawn = assert(World.spawnById("DM_Sparring_Phantom"), "Sparring Phantom spawn missing")
local HOME = Vector3.new(spawn.Placement.X, spawn.Placement.Y, spawn.Placement.Z)
local COURTYARD_Z = -750 -- past the gatehouse: the first lethal encounter

function Controller.new(state: any, camera: any, movement: any, input: any, ui: any): any
	local remote = Shared.Net:WaitForChild("TutorialIntent") :: RemoteEvent
	local card = HudKit.panel(ui.Gui, "TrainingCard", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.46, 0),
		Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false })
	HudKit.make("UIListLayout", card, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	HudKit.make("UIPadding", card, { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
	local function text(order: number, size: number, color: Color3, font: Enum.Font): TextLabel
		return HudKit.label(card, "", size, font, color, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	end
	local self = setmetatable({ State = state, Camera = camera, Movement = movement, Input = input, Ui = ui, Remote = remote, Card = card,
		Header = text(1, 14, T.Gold, T.BodyFont), Title = text(2, 22, T.Ivory, T.TitleFont), Do = text(3, 17, T.Ivory, T.BodyFont),
		Why = text(4, 15, T.Muted, T.BodyFont), Sent = {}, Glide = 0, Armed = false, StakesShown = false, Links = {} }, Controller)
	local skip: TextButton
	skip = UiKit.button(card, "Skip training", "Ghost", function()
		if not self.Armed then
			self.Armed, skip.Text = true, "Press again to skip"
			task.delay(3, function() self.Armed = false; if skip.Parent then skip.Text = "Skip training" end end)
			return
		end
		remote:FireServer({ action = "Skip" })
		self:Stakes()
	end)
	skip.LayoutOrder, skip.Size = 5, UDim2.new(1, 0, 0, 30)
	ui.OnTraining = function(action: string) remote:FireServer({ action = action }); self.Sent = {} end
	table.insert(self.Links, state:OnCue(function(cue: any)
		if cue.Source ~= state.LocalId then return end
		if cue.Kind == "TutorialStep" then
			UiKit.play("Confirm")
			ui:ShowToast("✓ " .. (self:StepTitle(tostring(cue.Data.step)) or "Step") .. " learned")
			if cue.Data.complete then ui:ShowBanner("TRAINING COMPLETE", "The courtyard beyond is lethal", 3); self:Stakes() end
		end
	end))
	return self
end

function Controller.StepTitle(_self: any, id: string): string?
	for _, step in Rules.Steps do if step.Id == id then return step.Title end end
	return nil
end

function Controller.Label(self: any, command: string): string
	local key = self.Input:Label(command)
	return if key ~= "" then key else InputMap.label(command, "Touch")
end

-- The carried-currency rule, once per session, before the first lethal fight (#19): its own card,
-- so the full sentence fits, dismissed with Understood or after a long read.
function Controller.Stakes(self: any)
	if self.StakesShown then return end
	self.StakesShown = true
	local panel = HudKit.panel(self.Ui.Gui, "StakesCard", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.8, 0),
		Size = UDim2.fromOffset(520, 0), AutomaticSize = Enum.AutomaticSize.Y })
	HudKit.make("UIListLayout", panel, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center })
	HudKit.make("UIPadding", panel, { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) })
	HudKit.label(panel, "WHAT DEATH TAKES", 22, T.TitleFont, T.Gold, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26) })
	HudKit.label(panel, Rules.Stakes, 17, T.BodyFont, T.Ivory, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
	local ok = UiKit.button(panel, "Understood", "Primary", function() panel:Destroy() end)
	ok.LayoutOrder, ok.Size = 3, UDim2.fromOffset(180, 36)
	task.delay(20, function() if panel.Parent then panel:Destroy() end end)
end

function Controller.Update(self: any, dt: number)
	local player = Players.LocalPlayer
	local done = Rules.parse(player:GetAttribute("AsuraTutorial"))
	local step = Rules.current(done)
	local own = self.State:Own()
	local root = own and own.Root
	local ui = self.Ui
	local hidden = ui.PrologueActive or ui.DialogueOpen or ui.DeathShown or (ui.Altar and ui.Altar.Visible)
	if root and not self.StakesShown and root.Position.Z < COURTYARD_Z and root.Position.Z > -900 and math.abs(root.Position.X) < 90
		and root.Position.Y < 100 and string.find(tostring(player:GetAttribute("AsuraAltars") or ""), "Cloister", 1, true) == nil then
		self:Stakes()
	end
	self.Card.Visible = step ~= nil and root ~= nil and not hidden and (root.Position - HOME).Magnitude <= Controller.ShowRadius
	if not step then return end
	local count = 0
	for _, s in Rules.Steps do if done[s.Id] then count += 1 end end
	self.Header.Text = string.format("TRAINING  ·  %d / %d", count + 1, #Rules.Steps)
	self.Title.Text = step.Title
	self.Do.Text = Rules.text(step.Do, function(c: string) return self:Label(c) end)
	self.Why.Text = step.Why
	-- Client-only proofs, each reported once per step.
	if step.Id == "LockOn" and self.Camera.Locked and not self.Sent.LockOn then
		local target = self.State:Get(self.Camera.Locked)
		if target and self.State:IsHostile(target) then self.Sent.LockOn = true; self.Remote:FireServer({ action = "Signal", signal = "LockOn" }) end
	elseif step.Id == "Glide" and not self.Sent.Glide then
		self.Glide = if self.Movement.State == "Gliding" then self.Glide + dt else 0
		if self.Glide >= Rules.GlideSeconds then self.Sent.Glide = true; self.Remote:FireServer({ action = "Signal", signal = "Glide" }) end
	end
end

function Controller.Destroy(self: any)
	for _, d in self.Links do d() end
	self.Card:Destroy()
end

return Controller

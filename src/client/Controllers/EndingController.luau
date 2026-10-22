--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/EndingController
-- The crossing (batch 22, #10). Plays EndingRules.Scene after the server has recorded a Cross
-- choice (so nothing here can lose or duplicate progress): three letterboxed Sanctuary shots, the
-- completion card, concise credits from EndingCredits and the return line. Stepped from the frame
-- loop, so skip and interruption are immediate: the first skip jumps to the completion card, a second
-- ends it; death, respawn or leaving the character stops it. Every exit restores the camera, input,
-- HUD flag and destroys the overlay (Stop is idempotent). Remain shows a banner only.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Ending = require(Shared.Shared.EndingRules) :: any
local Credits = require(Shared.Shared.EndingCredits) :: any
local Effects = require(Shared.Shared.EffectsPreference) :: any
local HudKit = require(script.Parent.HudKit)

local P = HudKit.Palette
local VEIL = Color3.fromRGB(12, 24, 20) -- deep jade ink: the dawn beyond the river
local FADE = 0.8

local Controller = {}
Controller.__index = Controller

function Controller.new(camera: any, input: any, ui: any): any
	local self = setmetatable({ Camera = camera, Input = input, Ui = ui, Active = false, Links = {}, Index = 0, Elapsed = 0, Clock = 0 }, Controller) :: any
	local remote = Shared.Net:WaitForChild("DialogueIntent") :: RemoteEvent
	table.insert(self.Links, remote.OnClientEvent:Connect(function(p: any)
		if type(p) ~= "table" or p.action ~= "Ending" then return end
		if p.choice == "Cross" then
			self:Play()
		else
			ui:ShowBanner("YOU REMAIN", "Their names walk with you · Lady Lin opens the crossing whenever you return to her bonfire", 5)
		end
	end))
	local player = Players.LocalPlayer
	local function watch(character: Model) -- one Died link at a time, never one kept per respawn
		if self.DiedLink then self.DiedLink:Disconnect(); self.DiedLink = nil end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then self.DiedLink = humanoid.Died:Connect(function() self:Stop("Interrupted") end) end
	end
	if player.Character then watch(player.Character) end
	table.insert(self.Links, player.CharacterAdded:Connect(function(character: Model) self:Stop("Interrupted"); watch(character) end))
	table.insert(self.Links, player.CharacterRemoving:Connect(function() self:Stop("Interrupted") end))
	return self
end

function Controller.Play(self: any)
	local ui = self.Ui
	if self.Active or ui.PrologueActive or ui.DeathShown then return end
	self.Active, self.Index, self.Elapsed, self.Clock = true, 1, 0, 0
	ui.EndingActive = true
	self.Input:SetMenu(true)
	local gui = HudKit.make("ScreenGui", Players.LocalPlayer:WaitForChild("PlayerGui"), { Name = "AsuraCrossing", IgnoreGuiInset = true, DisplayOrder = 61, ResetOnSpawn = false })
	self.Gui = gui
	self.Veil = HudKit.make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = VEIL, BackgroundTransparency = 1, BorderSizePixel = 0 })
	for edge = 0, 1 do
		HudKit.make("Frame", gui, { AnchorPoint = Vector2.new(0, edge), Position = UDim2.fromScale(0, edge), Size = UDim2.fromScale(1, 0.1), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0 })
	end
	self.Line = HudKit.label(gui, "", 30, HudKit.TitleFont, P.Ivory, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.new(0.84, 0, 0, 40), TextScaled = true, TextWrapped = true, TextTransparency = 1, TextStrokeTransparency = 0.6 })
	HudKit.make("UITextSizeConstraint", self.Line, { MinTextSize = 16, MaxTextSize = 30 })
	self.Sub = HudKit.label(gui, "", 18, HudKit.BodyFont, P.Ember, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.8, 6), Size = UDim2.new(0.84, 0, 0, 44), TextWrapped = true, TextTransparency = 1, TextStrokeTransparency = 0.7 })
	self.Roll = HudKit.label(gui, Credits.Title .. "\n\n" .. table.concat(Credits.lines(), "\n") .. "\n\n" .. Credits.Closing, 15, HudKit.BodyFont, P.Ivory,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(0.8, 0.62), TextScaled = true, TextWrapped = true, TextTransparency = 1, Visible = false })
	HudKit.make("UITextSizeConstraint", self.Roll, { MinTextSize = 11, MaxTextSize = 16 })
	local skipText = if UserInputService.GamepadEnabled then "Any button skips" else "Any key or tap skips"
	HudKit.label(gui, skipText, 14, HudKit.BodyFont, P.Muted, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -12), Size = UDim2.fromOffset(260, 20), TextXAlignment = Enum.TextXAlignment.Right })
	self.SkipLink = UserInputService.InputBegan:Connect(function(event: InputObject)
		local t = event.UserInputType
		local counts = t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 or string.sub(t.Name, 1, 7) == "Gamepad"
		if counts and self.Clock >= Ending.SkipGuard then self:Skip() end
	end)
	self:Draw(Ending.Scene[1])
end

function Controller.Skip(self: any)
	if not self.Active then return end
	if self.Index < Ending.CardBeat then
		self.Index, self.Elapsed = Ending.CardBeat, 0
		self:Draw(Ending.Scene[self.Index])
	else
		self:Stop("Skipped")
	end
end

function Controller.Draw(self: any, beat: any)
	local reduced = Effects.reducedMotion()
	local at, look = Ending.frame(beat, self.Elapsed, reduced)
	if at and look then self.Camera.DialogueFrame = CFrame.lookAt(at, look) end
	local t = self.Elapsed
	local fade = math.clamp(math.min(t, beat.Duration - t) / FADE, 0, 1)
	local overlay = beat.Kind ~= "Shot"
	local veil = if overlay then 0 else 1
	if not overlay and self.Index == Ending.CardBeat - 1 then -- the last shot dissolves into the dawn
		veil = 1 - math.clamp((t - (beat.Duration - 1.2)) / 1.2, 0, 1)
	end
	self.Veil.BackgroundTransparency = veil
	self.Line.Text, self.Sub.Text = beat.Line, beat.Sub
	local y = if beat.Kind == "Credits" then 0.18 elseif overlay then 0.48 else 0.8
	self.Line.Position, self.Sub.Position = UDim2.fromScale(0.5, y), UDim2.new(0.5, 0, y, 6)
	self.Line.TextTransparency, self.Sub.TextTransparency = 1 - fade, 1 - fade
	self.Roll.Visible = beat.Kind == "Credits"
	self.Roll.TextTransparency = 1 - fade
end

function Controller.Update(self: any, dt: number)
	if not self.Active then return end
	self.Clock += dt
	self.Elapsed += dt
	local beat = Ending.Scene[self.Index]
	if self.Elapsed >= beat.Duration then
		self.Index, self.Elapsed = self.Index + 1, 0
		if self.Index > #Ending.Scene then
			self:Stop("Finished")
			return
		end
		beat = Ending.Scene[self.Index]
	end
	self:Draw(beat)
end

-- reason: "Finished" | "Skipped" | "Interrupted" | "Destroyed". Safe to call at any time.
function Controller.Stop(self: any, reason: string)
	if not self.Active then return end
	self.Active = false
	if self.SkipLink then self.SkipLink:Disconnect(); self.SkipLink = nil end
	if self.Gui then self.Gui:Destroy(); self.Gui = nil end
	self.Camera.DialogueFrame = nil
	self.Input:SetMenu(false)
	self.Ui.EndingActive = false
	local final = Ending.Scene[#Ending.Scene]
	if reason == "Interrupted" then
		self.Ui:ShowBanner("THE CROSSING IS RECORDED", "Lady Lin can walk it with you again at the Primal Bonfire", 4)
	elseif reason ~= "Destroyed" then
		self.Ui:ShowBanner(final.Line, final.Sub, 5)
	end
end

function Controller.Destroy(self: any)
	self:Stop("Destroyed")
	if self.DiedLink then self.DiedLink:Disconnect(); self.DiedLink = nil end
	for _, link in self.Links do link:Disconnect() end
	table.clear(self.Links)
end

return Controller

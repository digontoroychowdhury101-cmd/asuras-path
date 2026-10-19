--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/PrologueController
-- First-session prologue: four letterboxed lines that give the climb its motive (the Fallen Abbot,
-- the husked monks, the last disciple) before handing over to the HUD objective. Plays once per
-- session and only for new players (nothing kindled beyond the Primal Bonfire). Skippable with any
-- key, button or tap. Presentation only; input is parked in menu mode while it runs.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)

local P = HudKit.Palette
local HOLD = 4.2
local FADE = 1.1

local LINES: { { string } } = {
 {"Shen devoured the souls of his disciples.", "THE JADE CATACLYSM"},
 {"The celestial pillars shattered. The Abyss awoke.", "Six Fallen Sovereigns bind the living to the dead."},
 {"You are an Asura Emissary, a phantom without an afterlife.", "The ferryman will not carry a soul still bound by six chains."},
 {"Lay the six sovereigns to rest.", "Harvest Qi. Kindle the altars. Choose your path beyond death."},
}

local Controller = {}

local function isNewcomer(player: Player): boolean
	local altars = player:GetAttribute("AsuraAltars")
	return type(altars) ~= "string" or altars == "" or altars == "Altar_SanctuaryBonfire"
end

-- Plays the prologue if this player is new. `ui` gets a PrologueActive flag other HUD pieces honour.
function Controller.Play(ui: any, input: any)
	local player = Players.LocalPlayer
	task.wait(1.5) -- let the profile attributes replicate
	if not isNewcomer(player) then
		return
	end
	ui.PrologueActive = true
	input:SetMenu(true)
	local gui = HudKit.make("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "AsuraPrologue", IgnoreGuiInset = true, DisplayOrder = 60, ResetOnSpawn = false }) :: ScreenGui
	local veil = HudKit.make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.08, BorderSizePixel = 0 }) :: Frame
	local bars: { Frame } = {}
	for edge = 0, 1 do
		table.insert(bars, HudKit.make("Frame", veil, { AnchorPoint = Vector2.new(0, edge), Position = UDim2.fromScale(0, edge), Size = UDim2.new(1, 0, 0.12, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }))
	end
	local line = HudKit.label(veil, "", 34, HudKit.TitleFont, P.Ivory, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(0.8, 0, 0, 48), TextScaled = true, TextTransparency = 1, TextStrokeTransparency = 1 })
	HudKit.make("UITextSizeConstraint", line, { MinTextSize = 18, MaxTextSize = 34 })
	local sub = HudKit.label(veil, "", 20, HudKit.BodyFont, P.Ember, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 34), Size = UDim2.new(0.8, 0, 0, 30), TextWrapped = true, TextTransparency = 1, TextStrokeTransparency = 1 })
	HudKit.label(veil, "Press any key to skip", 14, HudKit.BodyFont, P.Muted, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 0.88, -10), Size = UDim2.fromOffset(240, 20), TextXAlignment = Enum.TextXAlignment.Right })

	local skipped = false
	local skip = UserInputService.InputBegan:Connect(function(event: InputObject)
		local t = event.UserInputType
		if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 or string.sub(t.Name, 1, 7) == "Gamepad" then
			skipped = true
		end
	end)
	local function fade(target: number, duration: number)
		local info = TweenInfo.new(duration, Enum.EasingStyle.Sine)
		TweenService:Create(line, info, { TextTransparency = target, TextStrokeTransparency = if target < 1 then 0.6 else 1 }):Play()
		TweenService:Create(sub, info, { TextTransparency = target, TextStrokeTransparency = if target < 1 then 0.7 else 1 }):Play()
	end
	local function hold(seconds: number)
		local finish = os.clock() + seconds
		while os.clock() < finish and not skipped do
			task.wait(0.05)
		end
	end

	for _, entry in LINES do
		if skipped then
			break
		end
		line.Text, sub.Text = entry[1], entry[2]
		fade(0, FADE)
		hold(FADE + HOLD)
		fade(1, FADE * 0.7)
		hold(FADE * 0.7)
	end
	skip:Disconnect()
	local out = TweenService:Create(veil, TweenInfo.new(1.4, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
	fade(1, 0.4)
	for _, bar in bars do
		TweenService:Create(bar, TweenInfo.new(1.4, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
	end
	out:Play()
	out.Completed:Wait()
	gui:Destroy()
	input:SetMenu(false)
	ui.PrologueActive = false
	ui:ShowBanner("WALK THE ASURA'S PATH", "", 3)
end

return Controller

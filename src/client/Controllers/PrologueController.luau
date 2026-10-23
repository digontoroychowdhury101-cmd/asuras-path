--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/PrologueController
-- Opening presentation (batch 10, #43). An opaque veil covers the screen from the first frame until
-- the avatar has loaded its appearance and settled at the spawn (the server holds respawns for
-- 1.5 s), so no grey silhouette or half-built HUD shows through. New players (nothing kindled
-- beyond the Primal Bonfire) then see four letterboxed lines; any key, button or tap skips. The
-- camera is set behind the standing avatar before the veil lifts, and the handoff names the first
-- step (rest at the bonfire, then train at the Monastery Gate). Replayable from the Respite menu.
-- Presentation only; input is parked in menu mode while the veil is up.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)

local P = HudKit.Palette
local HOLD = 4.2
local FADE = 1.1
local LOAD_TIMEOUT = 8 -- seconds before the veil lifts even if the appearance never reports loaded
local SETTLE = 1.6 -- spawn hold plus a beat, so the avatar is standing still when revealed

local LINES: { { string } } = {
 {"Shen devoured the souls of his disciples.", "THE JADE CATACLYSM"},
 {"The celestial pillars shattered. The Abyss awoke.", "Six Fallen Sovereigns bind the living to the dead."},
 {"You are an Asura Emissary, a phantom without an afterlife.", "The ferryman will not carry a soul still bound by six chains."},
 {"Lay the six sovereigns to rest.", "Harvest Qi. Kindle the altars. Choose your path beyond death."},
}

local Controller = {}
Controller.Handoff = { "WALK THE ASURA'S PATH", "Kneel at the bonfire to rest · then train at the Monastery Gate" }

function Controller.isNewcomer(altars: any): boolean
	return type(altars) ~= "string" or altars == "" or altars == "Altar_SanctuaryBonfire"
end

-- Blocks until the character exists, its appearance has loaded and it has settled (or timeout).
local function ready(player: Player)
	local deadline = os.clock() + LOAD_TIMEOUT
	local character = player.Character or player.CharacterAdded:Wait()
	while os.clock() < deadline and not (player:HasAppearanceLoaded() and character:FindFirstChild("HumanoidRootPart")) do task.wait(0.1) end
	while os.clock() < deadline and player:GetAttribute("AsuraAltars") == nil do task.wait(0.1) end
	task.wait(SETTLE)
end

-- Plays the opening. `force` replays it for anyone (Respite menu); otherwise only newcomers see the
-- lines and everyone else just gets the clean load veil. `ui` gets a PrologueActive flag.
function Controller.Play(ui: any, input: any, camera: any?, force: boolean?)
	local player = Players.LocalPlayer
	if ui.PrologueActive then return end
	ui.PrologueActive = true
	input:SetMenu(true, "Prologue")
	local gui = HudKit.make("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "AsuraPrologue", IgnoreGuiInset = true, DisplayOrder = 60, ResetOnSpawn = false }) :: ScreenGui
	local veil = HudKit.make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0 }) :: Frame
	local bars: { Frame } = {}
	for edge = 0, 1 do
		table.insert(bars, HudKit.make("Frame", veil, { AnchorPoint = Vector2.new(0, edge), Position = UDim2.fromScale(0, edge), Size = UDim2.new(1, 0, 0.12, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }))
	end
	local line = HudKit.label(veil, "", 34, HudKit.TitleFont, P.Ivory, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.new(0.8, 0, 0, 48), TextScaled = true, TextTransparency = 1, TextStrokeTransparency = 1 })
	HudKit.make("UITextSizeConstraint", line, { MinTextSize = 18, MaxTextSize = 34 })
	local sub = HudKit.label(veil, "", 20, HudKit.BodyFont, P.Ember, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 34), Size = UDim2.new(0.8, 0, 0, 30), TextWrapped = true, TextTransparency = 1, TextStrokeTransparency = 1 })
	local hint = HudKit.label(veil, "", 14, HudKit.BodyFont, P.Muted, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 0.88, -10), Size = UDim2.fromOffset(320, 20), TextXAlignment = Enum.TextXAlignment.Right })

	if not force then ready(player) end
	local story = force == true or Controller.isNewcomer(player:GetAttribute("AsuraAltars"))
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
		while os.clock() < finish and not skipped do task.wait(0.05) end
	end
	if story then
		hint.Text = if UserInputService.GamepadEnabled then "Press any button to skip" else "Press any key or tap to skip"
		for _, entry in LINES do
			if skipped then break end
			line.Text, sub.Text = entry[1], entry[2]
			fade(0, FADE)
			hold(FADE + HOLD)
			fade(1, FADE * 0.7)
			hold(FADE * 0.7)
		end
	end
	skip:Disconnect()
	hint.Text = ""
	-- A deliberate first view: behind the avatar, facing where the spawn faces.
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if camera and root and root:IsA("BasePart") then camera:Face(root.CFrame.LookVector) end
	local lift = if story then 1.4 else 0.6
	local out = TweenService:Create(veil, TweenInfo.new(lift, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
	fade(1, 0.4)
	for _, bar in bars do
		TweenService:Create(bar, TweenInfo.new(lift, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
	end
	out:Play()
	out.Completed:Wait()
	gui:Destroy()
	input:SetMenu(false, "Prologue")
	ui.PrologueActive = false
	if story then ui:ShowBanner(Controller.Handoff[1], Controller.Handoff[2], 4) end
end

return Controller

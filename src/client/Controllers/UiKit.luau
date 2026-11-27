--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/UiKit
-- Shared button materials, focus states and menu sounds.
local TweenService = game:GetService("TweenService")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local Effects = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.EffectsPreference)

local UiKit = {}
local P = HudKit.Palette

UiKit.Theme = table.freeze({
	Ink = P.Ink, Ivory = P.Ivory, Muted = P.Muted, Gold = P.Gold, Ember = P.Ember, Edge = P.Edge,
	Surface = Color3.fromRGB(23, 22, 21), Raised = Color3.fromRGB(39, 35, 30),
	Primary = Color3.fromRGB(225, 195, 145), PrimaryHot = Color3.fromRGB(246, 221, 179),
	Secondary = Color3.fromRGB(36, 33, 29), SecondaryHot = Color3.fromRGB(55, 48, 40),
	Danger = Color3.fromRGB(80, 34, 30), DangerHot = Color3.fromRGB(101, 43, 37),
	Backdrop = Color3.fromRGB(8, 8, 8), BackdropAlpha = 0.16,
	Jade = P.Jade, Blood = P.Blood,
	TitleFont = HudKit.TitleFont, BodyFont = HudKit.BodyFont, Radius = 1,
})
UiKit.Motion = table.freeze({
	PressScale = 0.99,
	Hover = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Open = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	OpenFrom = 0.992, SlidePixels = 9,
})
-- SFX hooks: replace Id with an uploaded rbxassetid:// to re-skin; set Id = "" to mute a cue.
UiKit.Sfx = {
	Hover = { Id = HudKit.Sounds.Tick, Volume = 0.12, Pitch = 1.6 },
	Click = { Id = HudKit.Sounds.Tick, Volume = 0.4, Pitch = 1.1 },
	Error = { Id = HudKit.Sounds.Tick, Volume = 0.45, Pitch = 0.55 },
	Open = { Id = HudKit.Sounds.Objective, Volume = 0.25, Pitch = 1.25 },
	Close = { Id = HudKit.Sounds.Tick, Volume = 0.3, Pitch = 0.8 },
}

export type Variant = "Primary" | "Secondary" | "Danger" | "Ghost"
export type Bin = { any }

function UiKit.play(kind: string)
	local cue = UiKit.Sfx[kind]
	if cue and cue.Id ~= "" then
		HudKit.cue(cue.Id, cue.Volume, cue.Pitch)
	end
end

-- Bins hold connections, instances or cleanup functions; clean empties and releases them all.
function UiKit.clean(bin: Bin)
	for _, item in bin do
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif typeof(item) == "Instance" then
			item:Destroy()
		elseif type(item) == "function" then
			item()
		end
	end
	table.clear(bin)
end

local T = UiKit.Theme
local SKIN: { [Variant]: { Base: Color3, Hot: Color3, Text: Color3, Stroke: Color3, Alpha: number, Rim: number } } = {
	Primary = { Base = T.Primary, Hot = T.PrimaryHot, Text = T.Ink, Stroke = T.Gold, Alpha = 0, Rim = 0 },
	Secondary = { Base = T.Secondary, Hot = T.SecondaryHot, Text = T.Ivory, Stroke = T.Edge, Alpha = 0, Rim = 0.25 },
	Danger = { Base = T.Danger, Hot = T.DangerHot, Text = T.Ivory, Stroke = T.Ember, Alpha = 0, Rim = 0.3 },
	Ghost = { Base = T.Ink, Hot = T.Raised, Text = T.Ivory, Stroke = T.Edge, Alpha = 1, Rim = 1 },
}

function UiKit.setEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("UiDisabled", not enabled)
	button.TextTransparency = if enabled then 0 else 0.5
end

function UiKit.button(parent: Instance, text: string, variant: Variant, onActivate: () -> ()): TextButton
	local skin = SKIN[variant]
	local primary = variant == "Primary"
	local button = HudKit.make("TextButton", parent, {
		Name = text, Text = text, Font = if primary then Enum.Font.GothamMedium else UiKit.Theme.BodyFont,
		TextSize = if primary then 17 else 16, TextColor3 = skin.Text, TextStrokeTransparency = 1, AutoButtonColor = false,
		BackgroundColor3 = skin.Base, BackgroundTransparency = skin.Alpha, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44), Selectable = true, ClipsDescendants = false,
	}) :: TextButton
	local stroke = HudKit.make("UIStroke", button, {
		Color = skin.Stroke, Thickness = 1, Transparency = skin.Rim, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}) :: UIStroke
	if primary then
		HudKit.make("Frame", button, { Name = "Bevel", Position = UDim2.fromOffset(1, 0), Size = UDim2.new(1, -2, 0, 1),
			BackgroundColor3 = T.Ivory, BackgroundTransparency = 0.36, BorderSizePixel = 0 })
	end
	local scale = HudKit.make("UIScale", button, {}) :: UIScale
	local hovered, focused, pressed = false, false, false

	local function settle()
		local disabled = button:GetAttribute("UiDisabled") == true
		local hot = (hovered or focused) and not disabled
		local down = pressed and not disabled and not Effects.reducedMotion()
		TweenService:Create(scale, UiKit.Motion.Press, { Scale = if down then UiKit.Motion.PressScale else 1 }):Play()
		TweenService:Create(button, UiKit.Motion.Hover, {
			BackgroundColor3 = if hot then skin.Hot else skin.Base,
			BackgroundTransparency = if variant == "Ghost" and hot then 0 else skin.Alpha,
		}):Play()
		stroke.Color = if focused then (if primary then T.Ivory else T.Gold) else skin.Stroke
		stroke.Transparency = if focused then 0 elseif disabled then math.max(skin.Rim, 0.63) elseif hot then 0.18 else skin.Rim
		stroke.Thickness = if focused then 2 else 1
	end
	button.MouseEnter:Connect(function()
		hovered = true
		if button:GetAttribute("UiDisabled") ~= true then UiKit.play("Hover") end
		settle()
	end)
	button.MouseLeave:Connect(function() hovered, pressed = false, false; settle() end)
	button.SelectionGained:Connect(function() focused = true; settle() end)
	button.SelectionLost:Connect(function() focused, pressed = false, false; settle() end)
	button.MouseButton1Down:Connect(function() pressed = true; settle() end)
	button.MouseButton1Up:Connect(function() pressed = false; settle() end)
	button:GetAttributeChangedSignal("UiDisabled"):Connect(settle)
	button.Activated:Connect(function()
		if button:GetAttribute("UiDisabled") == true then
			UiKit.play("Error")
			return
		end
		UiKit.play("Click")
		onActivate()
	end)
	return button
end

return table.freeze(UiKit)

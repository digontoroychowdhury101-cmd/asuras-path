--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/UiKit
-- Interactive layer over HudKit: the menu theme, motion timings, SFX hooks and themed buttons
-- (Primary / Secondary / Danger / Ghost) with hover-lift, press-compress and stroke-glow tweens.
-- Gamepad selection mirrors hover. A Bin collects connections so owners can clean up in one call.
local TweenService = game:GetService("TweenService")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)

local UiKit = {}
local P = HudKit.Palette

-- Customization ------------------------------------------------------------------------------
UiKit.Theme = table.freeze({
	Ink = P.Ink, Ivory = P.Ivory, Muted = P.Muted, Gold = P.Gold, Ember = P.Ember, Edge = P.Edge,
	Surface = Color3.fromRGB(22, 15, 14), Raised = Color3.fromRGB(36, 24, 22),
	Primary = Color3.fromRGB(150, 18, 22), PrimaryHot = Color3.fromRGB(196, 32, 32),
	Secondary = Color3.fromRGB(30, 21, 19), SecondaryHot = Color3.fromRGB(48, 32, 28),
	Danger = Color3.fromRGB(70, 14, 14), DangerHot = Color3.fromRGB(110, 20, 20),
	Backdrop = Color3.fromRGB(4, 2, 2), BackdropAlpha = 0.4,
	TitleFont = HudKit.TitleFont, BodyFont = HudKit.BodyFont, Radius = 6,
})
UiKit.Motion = table.freeze({
	HoverScale = 1.05, PressScale = 0.95,
	Hover = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Open = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	OpenFrom = 0.9, SlidePixels = 18,
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

local SKIN: { [Variant]: { Base: Color3, Hot: Color3, Text: Color3, Stroke: Color3, Alpha: number } } = {
	Primary = { Base = UiKit.Theme.Primary, Hot = UiKit.Theme.PrimaryHot, Text = UiKit.Theme.Ivory, Stroke = UiKit.Theme.Gold, Alpha = 0 },
	Secondary = { Base = UiKit.Theme.Secondary, Hot = UiKit.Theme.SecondaryHot, Text = UiKit.Theme.Ivory, Stroke = UiKit.Theme.Edge, Alpha = 0.1 },
	Danger = { Base = UiKit.Theme.Danger, Hot = UiKit.Theme.DangerHot, Text = UiKit.Theme.Ivory, Stroke = UiKit.Theme.Edge, Alpha = 0.05 },
	Ghost = { Base = UiKit.Theme.Ink, Hot = UiKit.Theme.Raised, Text = UiKit.Theme.Muted, Stroke = UiKit.Theme.Edge, Alpha = 0.6 },
}

-- Disabled buttons stay visible (dimmed, no lift) and answer clicks with the Error cue.
function UiKit.setEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("UiDisabled", not enabled)
	button.TextTransparency = if enabled then 0 else 0.5
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = if enabled then 0.25 else 0.7
	end
end

function UiKit.button(parent: Instance, text: string, variant: Variant, onActivate: () -> ()): TextButton
	local skin = SKIN[variant]
	local primary = variant == "Primary"
	local button = HudKit.make("TextButton", parent, {
		Name = text, Text = text, Font = if primary then UiKit.Theme.TitleFont else UiKit.Theme.BodyFont,
		TextSize = if primary then 20 else 19, TextColor3 = skin.Text, AutoButtonColor = false,
		BackgroundColor3 = skin.Base, BackgroundTransparency = skin.Alpha, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44), Selectable = true, ClipsDescendants = false,
	}) :: TextButton
	HudKit.make("UICorner", button, { CornerRadius = UDim.new(0, UiKit.Theme.Radius) })
	local stroke = HudKit.make("UIStroke", button, {
		Color = skin.Stroke, Thickness = if primary then 1.5 else 1, Transparency = 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}) :: UIStroke
	HudKit.make("UIGradient", button, { -- lacquer sheen: lit top edge, darker foot
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 160, 155)),
	})
	local scale = HudKit.make("UIScale", button, {}) :: UIScale
	local hovered = false

	local function settle(info: TweenInfo)
		local disabled = button:GetAttribute("UiDisabled") == true
		local lift = hovered and not disabled
		TweenService:Create(scale, info, { Scale = if lift then UiKit.Motion.HoverScale else 1 }):Play()
		TweenService:Create(button, info, { BackgroundColor3 = if lift then skin.Hot else skin.Base }):Play()
		TweenService:Create(stroke, info, {
			Transparency = if disabled then 0.7 elseif lift then 0 else 0.25,
			Thickness = (if primary then 1.5 else 1) + (if lift then 1 else 0),
		}):Play()
	end
	local function enter()
		if not hovered then
			hovered = true
			if button:GetAttribute("UiDisabled") ~= true then
				UiKit.play("Hover")
			end
			settle(UiKit.Motion.Hover)
		end
	end
	local function leave()
		hovered = false
		settle(UiKit.Motion.Hover)
	end
	-- Instance-owned connections die with the button, so callers never need to track them.
	button.MouseEnter:Connect(enter)
	button.SelectionGained:Connect(enter)
	button.MouseLeave:Connect(leave)
	button.SelectionLost:Connect(leave)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, UiKit.Motion.Press, { Scale = UiKit.Motion.PressScale }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		settle(UiKit.Motion.Hover)
	end)
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

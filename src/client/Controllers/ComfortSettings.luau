--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ComfortSettings
-- Comfort and readability rows for the Respite settings page (batch 25, #36 #35): reduced effects
-- (decorative petals, ash, particle density), reduced motion (camera shake/kick, scripted camera
-- moves), reduced flashes (screen blooms) and text size. Changes preview live through the shared
-- EffectsPreference; PauseMenu's Apply saves them with FOV/sensitivity and Back reverts them.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Effects = require(Shared:WaitForChild("Shared"):WaitForChild("EffectsPreference") :: ModuleScript) :: any
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local Comfort = {}
local T = UiKit.Theme

Comfort.Rows = table.freeze({
	{ Key = "ReducedEffects", Text = "Reduced effects" },
	{ Key = "ReducedMotion", Text = "Reduced motion" },
	{ Key = "ReducedFlashes", Text = "Reduced flashes" },
})

-- Pure: the next text scale after `current` (wraps), and its caption.
function Comfort.nextScale(current: number): number
	local scales = Effects.TextScales
	local index = table.find(scales, current) or 1
	return scales[index % #scales + 1]
end
function Comfort.caption(scale: number): string
	return string.format("%d%%", math.floor(scale * 100 + 0.5))
end

local function row(parent: Instance, order: number, text: string, press: () -> ()): TextButton
	local frame = HudKit.make("Frame", parent, { Name = text, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	HudKit.label(frame, text, 18, T.BodyFont, T.Ivory, { Size = UDim2.new(1, -130, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local button = UiKit.button(frame, "", "Secondary", press)
	button.AnchorPoint, button.Position, button.Size = Vector2.new(1, 0.5), UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(120, 40)
	return button
end

-- Builds the rows from LayoutOrder `first` on; returns a refresh function for the shown values.
function Comfort.build(parent: Instance, first: number): () -> ()
	local buttons: { [string]: TextButton } = {}
	for i, spec in Comfort.Rows do
		buttons[spec.Key] = row(parent, first + i - 1, spec.Text, function()
			local prefs = Effects.get()
			Effects.set({ [spec.Key] = not prefs[spec.Key] })
		end)
	end
	local textSize = row(parent, first + #Comfort.Rows, "Text size", function()
		Effects.set({ TextScale = Comfort.nextScale(Effects.textScale()) })
	end)
	local function refresh()
		local prefs = Effects.get()
		for key, button in buttons do button.Text = if prefs[key] then "On" else "Off" end
		textSize.Text = Comfort.caption(prefs.TextScale)
	end
	local stop = Effects.onChanged(function() refresh() end)
	parent.Destroying:Once(stop)
	refresh()
	return refresh
end

return table.freeze(Comfort)

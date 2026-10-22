--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/AltarAscension
-- The altar menu's Ascension page: a fixed header (level, Essence held, cost and what is left)
-- above a bounded scroll region of attribute rows. Each row shows the readable name (Arcane Qi),
-- the current value and the concrete before/after result from LevelPreview; its + button is
-- disabled when Essence is short or the attribute is at its peak. The server still decides.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath"):WaitForChild("Shared")
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local Rules = require(Shared:WaitForChild("ProgressionRules") :: ModuleScript)
local Preview = require(Shared:WaitForChild("LevelPreview") :: ModuleScript)

local Ascension = {}
local T = UiKit.Theme
local ROW = 70

export type Row = { Value: TextLabel, Result: TextLabel, Plus: TextButton }
export type View = { Header: TextLabel, Quote: TextLabel, List: ScrollingFrame, Rows: { [string]: Row } }

-- `page` is the altar menu's Level page (UIListLayout); Back is appended by the caller (order 10).
function Ascension.build(page: Frame, onLevel: (string) -> ()): View
	local header = HudKit.label(page, "", 18, T.TitleFont, T.Ivory, { Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0 })
	local quote = HudKit.label(page, "", 15, T.BodyFont, T.Muted, { Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
	local list = HudKit.make("ScrollingFrame", page, {
		Name = "Attributes", Size = UDim2.new(1, 0, 1, -112), BackgroundColor3 = T.Ink, BackgroundTransparency = 0.6, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = T.Edge, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, ClipsDescendants = true, LayoutOrder = 2,
	}) :: ScrollingFrame
	HudKit.make("UIStroke", list, { Color = T.Edge, Transparency = 0.55 }) -- the scroll boundary is visible
	HudKit.make("UIListLayout", list, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	HudKit.make("UIPadding", list, { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) })
	local rows: { [string]: Row } = {}
	for index, id in Rules.Attributes do
		local row = HudKit.make("Frame", list, { Name = id, Size = UDim2.new(1, 0, 0, ROW), BackgroundTransparency = 1, LayoutOrder = index }) :: Frame
		HudKit.label(row, Preview.Labels[id], 20, T.BodyFont, T.Ivory, { Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, -110, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
		HudKit.label(row, Preview.Summary[id], 13, T.BodyFont, T.Muted, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -110, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
		local result = HudKit.label(row, "", 13, T.BodyFont, T.Gold, {
			Name = "Result", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, -54, 0, 28), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		})
		local value = HudKit.label(row, "10", 22, Enum.Font.GothamMedium, T.Ivory, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, 4), Size = UDim2.fromOffset(52, 30) })
		local plus = UiKit.button(row, "+", "Primary", function() onLevel(id) end)
		plus.AnchorPoint, plus.Position, plus.Size = Vector2.new(1, 0), UDim2.new(1, 0, 0, 2), UDim2.fromOffset(44, 36)
		rows[id] = { Value = value, Result = result, Plus = plus }
	end
	return { Header = header, Quote = quote, List = list, Rows = rows }
end

-- Reads the server-published attributes on the player (Asura* attributes) and redraws.
function Ascension.refresh(view: View, player: Player)
	local essence = tonumber(player:GetAttribute("AsuraEssence")) or 0
	local cost = tonumber(player:GetAttribute("AsuraLevelCost")) or 0
	local level = tonumber(player:GetAttribute("AsuraLevel")) or 1
	local tier = tonumber(player:GetAttribute("AsuraReinforce")) or 0
	local attributes: { [string]: number } = {}
	for _, id in Rules.Attributes do attributes[id] = tonumber(player:GetAttribute("Asura" .. id)) or 10 end
	local affordable, quote = Preview.quote(essence, cost)
	view.Header.Text = string.format("Level %d → %d   ·   ✦ %d Essence", level, level + 1, essence)
	view.Quote.Text, view.Quote.TextColor3 = quote, if affordable then T.Gold else T.Muted
	for id, row in view.Rows do
		row.Value.Text = tostring(attributes[id])
		row.Result.Text = Preview.line(attributes, id, tier)
		UiKit.setEnabled(row.Plus, affordable and attributes[id] < Preview.Max)
	end
end

return table.freeze(Ascension)

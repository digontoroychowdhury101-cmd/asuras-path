--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ArsenalTabs
-- Sorcery and remembrance cards. Weapon and armour inspection live in ArsenalEquipment.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Catalog = require(Shared:WaitForChild("Shared"):WaitForChild("ArsenalCatalog") :: ModuleScript)
local Spells = require(Shared:WaitForChild("Simulation"):WaitForChild("SpellSchema") :: ModuleScript)
local Facts = require(Shared:WaitForChild("Shared"):WaitForChild("ArsenalFacts") :: ModuleScript)
local Inventory = require(Shared:WaitForChild("Simulation"):WaitForChild("ArsenalInventory") :: ModuleScript)
local HudKit = require(script.Parent:WaitForChild("HudKit") :: ModuleScript)
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local Tabs = {}
local T = UiKit.Theme

-- Customization ------------------------------------------------------------------------------
local CONFIRM_SECONDS = 3 -- forging is permanent: the first press arms, the second commits
local DISCIPLINE: { [string]: { Name: string, Color: Color3 } } = {
	CelestialThunder = { Name = "Celestial Thunder", Color = Color3.fromRGB(120, 170, 235) },
	CrimsonFlame = { Name = "Crimson Flame", Color = T.Ember },
	AbyssalVoid = { Name = "Abyssal Void", Color = Color3.fromRGB(140, 96, 186) },
	SpiritTalismans = { Name = "Spirit Talismans", Color = Color3.fromRGB(86, 168, 92) },
}

export type Env = { Label: (command: string) -> string, Attributes: { [string]: number } }
export type Line = { Text: string, Color: Color3, Size: number }

-- A card grows with its text: title, then wrapped lines (use, details, effects/comparison).
local function card(list: ScrollingFrame, order: number, title: string, lines: { Line }, accent: Color3): Frame
	local frame = HudKit.make("Frame", list, {
		Name = title, LayoutOrder = order, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Raised, BackgroundTransparency = 0.2, BorderSizePixel = 0,
	}) :: Frame
	HudKit.make("UICorner", frame, { CornerRadius = UDim.new(0, T.Radius) })
	HudKit.make("UIStroke", frame, { Color = T.Edge, Transparency = 0.5 })
	HudKit.make("UISizeConstraint", frame, { MinSize = Vector2.new(0, 80) })
	local content = HudKit.make("Frame", frame, {
		Name = "CardContent", Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UIListLayout", content, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	HudKit.make("UIPadding", content, { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
	HudKit.label(content, title, 20, T.TitleFont, accent, { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 0 })
	for index, line in lines do
		if line.Text ~= "" then
			HudKit.label(content, line.Text, line.Size, T.BodyFont, line.Color, {
				Name = "Line" .. index, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = index,
			})
		end
	end
	local actions = HudKit.make("Frame", content, {
		Name = "Actions", Size = UDim2.new(1, 0, 0, 44), LayoutOrder = #lines + 1, BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UIListLayout", actions, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	return actions
end

local function lines(l: Facts.Lines): { Line }
	return { { Text = l.Use, Color = T.Ivory, Size = 15 }, { Text = l.Detail, Color = T.Muted, Size = 14 }, { Text = l.Effects, Color = T.Gold, Size = 14 } }
end

local function action(actions: Frame, text: string, variant: UiKit.Variant, width: number, enabled: boolean, fn: () -> ()): TextButton
	local b = UiKit.button(actions, text, variant, fn)
	b.Size = UDim2.new(0.48, -2, 1, 0)
	HudKit.make("UISizeConstraint", b, { MaxSize = Vector2.new(width, 44) })
	b.TextSize, b.TextScaled = 17, true
	HudKit.make("UITextSizeConstraint", b, { MinTextSize = 11, MaxTextSize = 17 })
	UiKit.setEnabled(b, enabled)
	return b
end

-- Slot buttons use Arabic numerals plus the live binding ("Slot 2 [E]"): the old Roman two
-- was hard to tell from one in the menu font.
function Tabs.slotText(slot: number, key: string, equipped: boolean): string
	return (if equipped then "✓ " else "") .. "Slot " .. slot .. " [" .. key .. "]"
end

function Tabs.Spells(send: (any) -> (), inv: any, list: ScrollingFrame, env: Env)
	local ctx = Facts.context(inv, env.Attributes)
	for order, id in Spells.Order do
		local s = Spells.ById[id]
		if inv.spells[id] and s then
			local school = DISCIPLINE[s.Discipline] or { Name = s.Discipline, Color = T.Gold }
			local facts = Facts.spell(id, ctx)
			facts.Detail = school.Name .. "  ·  " .. facts.Detail
			local actions = card(list, order, s.Name, lines(facts), school.Color)
			for slot, command in { "SpellOne", "SpellTwo" } do
				local on = inv.spellSlots[slot] == id
				local b = action(actions, Tabs.slotText(slot, env.Label(command), on), if on then "Primary" else "Secondary", 120, true, function()
					send({ action = "EquipSpell", id = id, slot = slot })
				end)
				b.Font = Enum.Font.GothamMedium -- the menu face draws an old-style "1" that reads as "ı" (F05)
			end
		end
	end
end

-- Readiness is ArsenalInventory.recipeState (token objects, the server forge's rule), by sovereign.
function Tabs.Forge(send: (any) -> (), inv: any, list: ScrollingFrame, _env: Env)
	local order = 0
	for _, boss in Catalog.TokenOrder do
		local ids = {}
		for id, r in Catalog.Recipes do if r.Boss == boss then table.insert(ids, id) end end
		table.sort(ids, function(a, b) return Catalog.Recipes[a].Kind > Catalog.Recipes[b].Kind end) -- weapon, then spell
		for _, id in ids do
			order += 1
			local r, name, state = Catalog.Recipes[id], (string.gsub(boss, "(%l)(%u)", "%1 %2")), Inventory.recipeState(inv, id)
			local ready = state == "Ready"
			local detail = { { Text = r.Kind .. " · Remembrance of " .. name, Color = T.Muted, Size = 14 },
				{ Text = string.format(Catalog.ForgeStates[state], name), Color = if ready then T.Gold else T.Muted, Size = 14 } }
			local actions, armed, button = card(list, order, r.Name, detail, if ready then T.Gold else T.Ivory), false, nil :: TextButton?
			button = action(actions, if ready then "Forge" else state, if ready then "Primary" else "Ghost", 112, ready, function()
				if armed then send({ action = "Forge", id = id }); return end
				armed = true; (button :: TextButton).Text = "Confirm?"
				task.delay(CONFIRM_SECONDS, function() armed = false; if button and button.Parent then button.Text = "Forge" end end)
			end)
		end
	end
end

return table.freeze(Tabs)

--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ArsenalTabs
-- Card rendering for the Arsenal's three tabs (spells, weapons, transmutation). Each card is a
-- raised lacquer row with a discipline/state accent bar, name, wrapped lines from ArsenalFacts
-- (practical use, targeting/cost or style, effects or a comparison with the wielded weapon).
-- Pure presentation: actions call `send` with ArsenalIntent packets; the server validates.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Catalog = require(Shared:WaitForChild("Shared"):WaitForChild("ArsenalCatalog") :: ModuleScript)
local Spells = require(Shared:WaitForChild("Simulation"):WaitForChild("SpellSchema") :: ModuleScript)
local Weapons = require(Shared:WaitForChild("Simulation"):WaitForChild("WeaponSchema") :: ModuleScript)
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
local function card(list: ScrollingFrame, order: number, title: string, lines: { Line }, accent: Color3, actionWidth: number): Frame
	local frame = HudKit.make("Frame", list, {
		Name = title, LayoutOrder = order, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Raised, BackgroundTransparency = 0.2, BorderSizePixel = 0,
	}) :: Frame
	HudKit.make("UICorner", frame, { CornerRadius = UDim.new(0, T.Radius) })
	HudKit.make("UIStroke", frame, { Color = T.Edge, Transparency = 0.5 })
	HudKit.make("Frame", frame, { Name = "Accent", Position = UDim2.fromOffset(0, 10), Size = UDim2.new(0, 3, 1, -20), BackgroundColor3 = accent, BorderSizePixel = 0 })
	local text = HudKit.make("Frame", frame, {
		Name = "Text", Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -actionWidth - 36, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UIListLayout", text, { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	HudKit.make("UIPadding", text, { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) })
	HudKit.label(text, title, 20, T.BodyFont, T.Ivory, { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 0 })
	for index, line in lines do
		if line.Text ~= "" then
			HudKit.label(text, line.Text, line.Size, T.BodyFont, line.Color, {
				Name = "Line" .. index, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = index,
			})
		end
	end
	local actions = HudKit.make("Frame", frame, {
		Name = "Actions", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, actionWidth, 0, 38), BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UIListLayout", actions, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	return actions
end

local function lines(l: Facts.Lines): { Line }
	return { { Text = l.Use, Color = T.Ivory, Size = 15 }, { Text = l.Detail, Color = T.Muted, Size = 14 }, { Text = l.Effects, Color = T.Gold, Size = 14 } }
end

local function action(actions: Frame, text: string, variant: UiKit.Variant, width: number, enabled: boolean, fn: () -> ()): TextButton
	local b = UiKit.button(actions, text, variant, fn)
	b.Size = UDim2.new(0, width, 1, 0)
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
			local actions = card(list, order, s.Name, lines(facts), school.Color, 248)
			for slot, command in { "SpellOne", "SpellTwo" } do
				local on = inv.spellSlots[slot] == id
				action(actions, Tabs.slotText(slot, env.Label(command), on), if on then "Primary" else "Secondary", 120, true, function()
					send({ action = "EquipSpell", id = id, slot = slot })
				end)
			end
		end
	end
end

function Tabs.Weapons(send: (any) -> (), inv: any, list: ScrollingFrame, env: Env)
 local talismans=if inv.materials then inv.materials.LastBreathTalisman or 0 else 0
 if talismans>0 then
  local actions=card(list,0,"Last Breath Talisman",{{Text=tostring(talismans).." owned · wards one fatal blow for 30 seconds",Color=T.Muted,Size=14}},T.Gold,104)
  action(actions,"Invoke","Primary",104,true,function() send({action="UseTalisman"}) end)
 end
	local ctx = Facts.context(inv, env.Attributes)
	for order, id in Weapons.WeaponKeys do
		if inv.weapons[id] then
			local w = Weapons.get(id :: any) -- WeaponKeys is typed string[]; get() wants the key union
			local main, off = inv.mainhand == id, inv.offhand == id
			local facts = Facts.weapon(id, ctx)
			if off then facts.Detail = "Off-hand focus  ·  " .. facts.Detail end
			local actions = card(list, order, w.Name, lines(facts), if main then T.Gold else T.Edge, if id == "Catalyst" then 236 else 120)
			action(actions, if main then "✓ Wielded" else "Wield", if main then "Primary" else "Secondary", 112, not main, function()
				send({ action = "EquipWeapon", id = id, offhand = false })
			end)
			if id == "Catalyst" then
				action(actions, if off then "✓ Off-hand" else "Off-hand", "Secondary", 116, not off, function()
					send({ action = "EquipWeapon", id = id, offhand = true })
				end)
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
			local actions, armed, button = card(list, order, r.Name, detail, if ready then T.Gold else T.Edge, 120), false, nil :: TextButton?
			button = action(actions, if ready then "Forge" else state, if ready then "Primary" else "Ghost", 112, ready, function()
				if armed then send({ action = "Forge", id = id }); return end
				armed = true; (button :: TextButton).Text = "Confirm?"
				task.delay(CONFIRM_SECONDS, function() armed = false; if button and button.Parent then button.Text = "Forge" end end)
			end)
		end
	end
end

return table.freeze(Tabs)

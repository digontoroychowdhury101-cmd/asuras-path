--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/AsurasPath/Controllers/ArsenalTabs
-- Card rendering for the Arsenal's three tabs (spells, weapons, transmutation). Each card is a
-- raised lacquer row with a discipline/state accent bar, name, detail line and themed actions.
-- Pure presentation: actions call `send` with ArsenalIntent packets; the server validates.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Catalog = require(Shared:WaitForChild("Shared"):WaitForChild("ArsenalCatalog") :: ModuleScript)
local Spells = require(Shared:WaitForChild("Simulation"):WaitForChild("SpellSchema") :: ModuleScript)
local Weapons = require(Shared:WaitForChild("Simulation"):WaitForChild("WeaponSchema") :: ModuleScript)
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

local function card(list: ScrollingFrame, order: number, title: string, detail: string, accent: Color3, actionWidth: number): Frame
	local frame = HudKit.make("Frame", list, {
		Name = title, LayoutOrder = order, Size = UDim2.new(1, -10, 0, 66),
		BackgroundColor3 = T.Raised, BackgroundTransparency = 0.2, BorderSizePixel = 0,
	}) :: Frame
	HudKit.make("UICorner", frame, { CornerRadius = UDim.new(0, T.Radius) })
	HudKit.make("UIStroke", frame, { Color = T.Edge, Transparency = 0.5 })
	HudKit.make("Frame", frame, { Name = "Accent", Position = UDim2.fromOffset(0, 10), Size = UDim2.new(0, 3, 1, -20), BackgroundColor3 = accent, BorderSizePixel = 0 })
	HudKit.label(frame, title, 20, T.BodyFont, T.Ivory, {
		Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -actionWidth - 28, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	HudKit.label(frame, detail, 14, T.BodyFont, T.Muted, {
		Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -actionWidth - 28, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local actions = HudKit.make("Frame", frame, {
		Name = "Actions", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, actionWidth, 0, 38), BackgroundTransparency = 1,
	}) :: Frame
	HudKit.make("UIListLayout", actions, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	return actions
end

local function action(actions: Frame, text: string, variant: UiKit.Variant, width: number, enabled: boolean, fn: () -> ()): TextButton
	local b = UiKit.button(actions, text, variant, fn)
	b.Size = UDim2.new(0, width, 1, 0)
	b.TextSize = 17
	UiKit.setEnabled(b, enabled)
	return b
end

function Tabs.Spells(send: (any) -> (), inv: any, list: ScrollingFrame)
	for order, id in Spells.Order do
		local s = Spells.ById[id]
		if inv.spells[id] and s then
			local school = DISCIPLINE[s.Discipline] or { Name = s.Discipline, Color = T.Gold }
			local actions = card(list, order, s.Name, string.format("%s · %d Qi · %ds", school.Name, s.QiCost, s.Cooldown), school.Color, 216)
			for slot, numeral in { "I", "II" } do
				local on = inv.spellSlots[slot] == id
				action(actions, (if on then "✓ Slot " else "Slot ") .. numeral, if on then "Primary" else "Secondary", 104, true, function()
					send({ action = "EquipSpell", id = id, slot = slot })
				end)
			end
		end
	end
end

function Tabs.Weapons(send: (any) -> (), inv: any, list: ScrollingFrame)
	for order, id in Weapons.WeaponKeys do
		if inv.weapons[id] then
			local w = Weapons.get(id :: any) -- WeaponKeys is typed string[]; get() wants the key union
			local main, off = inv.mainhand == id, inv.offhand == id
			local detail = string.format("%s · reach %.1f%s", tostring(w.WeightClass or w.Grip), w.Reach, if main then " · wielded" elseif off then " · off-hand focus" else "")
			local actions = card(list, order, w.Name, detail, if main then T.Gold else T.Edge, if id == "Catalyst" then 236 else 120)
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

function Tabs.Forge(send: (any) -> (), inv: any, list: ScrollingFrame)
	local ids = {}
	for id in Catalog.Recipes do
		table.insert(ids, id)
	end
	table.sort(ids)
	for order, id in ids do
		local r = Catalog.Recipes[id]
		local boss = (string.gsub(r.Boss, "(%l)(%u)", "%1 %2"))
		local spent, owned = inv.spentRemembrances[r.Boss] == true, inv.remembrances[r.Boss] == true
		local ready = owned and not spent
		local actions = card(list, order, r.Name, r.Kind .. " · Remembrance of " .. boss, if ready then T.Gold else T.Edge, 120)
		local armed = false
		local button: TextButton
		button = action(actions, if ready then "Forge" elseif spent then "Spent" else "Locked", if ready then "Primary" else "Ghost", 112, ready, function()
			if armed then
				send({ action = "Forge", id = id })
				return
			end
			armed, button.Text = true, "Confirm?"
			task.delay(CONFIRM_SECONDS, function()
				armed = false
				if button.Parent then button.Text = "Forge" end
			end)
		end)
	end
end

return table.freeze(Tabs)

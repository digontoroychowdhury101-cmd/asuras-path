--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/LevelPreview
-- Concrete before/after results of raising one attribute, derived from the same formulas the
-- server applies (ProgressionRules.stats + CombatSettings base values, as ProfileStore.DeriveStats
-- does), plus readable labels and the Essence cost/remaining line. Essence is the currency spent
-- here; Qi is the regenerating spell resource, so the two words never share a label.
local hasScript = pcall(function() return script.Parent end)
local Rules: any = if hasScript then require((script :: any).Parent.ProgressionRules) else require("./ProgressionRules")
local Settings: any = if hasScript then require((script :: any).Parent.CombatSettings) else require("./CombatSettings")

local Preview = {}

Preview.Max = 99 -- mirrors ProfileStore ATTRIBUTE_MAX and the dialogue level assert
Preview.Currency = "Essence"
Preview.Labels = table.freeze({
	Vigor = "Vigor", Endurance = "Endurance", Strength = "Strength", Dexterity = "Dexterity", ArcaneQi = "Arcane Qi",
})
Preview.Summary = table.freeze({
	Vigor = "Health and Blood Rally recovery",
	Endurance = "Stamina and posture",
	Strength = "Heavy and unarmed strike damage",
	Dexterity = "Bladed technique damage",
	ArcaneQi = "Qi pool and spell damage",
})

export type Benefit = { Label: string, Before: number, After: number, Percent: boolean }

-- Stat rows each attribute moves, read from the derived-stat table.
local ROWS: { [string]: { { any } } } = {
	Vigor = { { "Max HP", "MaxHP" }, { "Rally recovery", "RallyScale", true } },
	Endurance = { { "Stamina", "MaxStamina" }, { "Posture", "PostureCapacity" } },
	Strength = { { "Strength damage", "StrengthScale", true } },
	Dexterity = { { "Blade damage", "DexterityScale", true } },
	ArcaneQi = { { "Max Qi", "MaxQi" }, { "Spell damage", "SpellScale", true } },
}

-- The derived values ProfileStore.DeriveStats produces for these attributes and forge tier.
function Preview.derived(attributes: { [string]: number }, tier: number): { [string]: number }
	local s = Rules.stats(attributes, tier)
	return {
		MaxHP = Settings.Health.MaxHP + s.HPBonus, MaxStamina = Settings.Stamina.Max + s.StaminaBonus,
		PostureCapacity = Settings.Posture.StanceBreakThreshold + s.PostureBonus, MaxQi = s.MaxQi,
		RallyScale = s.RallyScale, SpellScale = s.SpellScale, StrengthScale = s.StrengthScale, DexterityScale = s.DexterityScale,
	}
end

function Preview.benefits(attributes: { [string]: number }, attribute: string, tier: number): { Benefit }
	local rows = ROWS[attribute]
	if not rows then return {} end
	local after = table.clone(attributes)
	after[attribute] = (after[attribute] or 10) + 1
	local a, b = Preview.derived(attributes, tier), Preview.derived(after, tier)
	local result: { Benefit } = {}
	for _, row in rows do
		table.insert(result, { Label = row[1], Before = a[row[2]], After = b[row[2]], Percent = row[3] == true })
	end
	return result
end

local function number(value: number, percent: boolean): string
	if percent then return string.format("%.1f%%", value * 100) end
	local rounded = math.floor(value * 10 + 0.5) / 10
	return if rounded % 1 == 0 then string.format("%d", rounded) else string.format("%.1f", rounded)
end

function Preview.format(b: Benefit): string
	return b.Label .. " " .. number(b.Before, b.Percent) .. " → " .. number(b.After, b.Percent)
end

-- One line for a menu row: every changed stat, or why the attribute cannot grow.
function Preview.line(attributes: { [string]: number }, attribute: string, tier: number): string
	if (attributes[attribute] or 10) >= Preview.Max then return "At its peak" end
	local parts = {}
	for _, b in Preview.benefits(attributes, attribute, tier) do table.insert(parts, Preview.format(b)) end
	return table.concat(parts, "  ·  ")
end

-- Cost line: what this level costs and what is left, or how much more Essence is needed.
function Preview.quote(essence: number, cost: number): (boolean, string)
	if essence >= cost then
		return true, string.format("Cost %d %s  ·  %d left after", cost, Preview.Currency, essence - cost)
	end
	return false, string.format("Need %d more %s  (%d / %d)", cost - essence, Preview.Currency, essence, cost)
end

return table.freeze(Preview)

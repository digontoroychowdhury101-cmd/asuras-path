--!nonstrict
-- Lune regression for playtest findings #41 and #42 (batch 06).
-- Run from the project root: lune run tools/test_arsenal_codex.luau
-- Arsenal card facts are checked against the real cast/damage functions (SpellRules.begin,
-- CombatRules.damageScale, ProfileStore.DeriveStats); Codex summaries for empty, partial and full
-- discovery states never expose locked lore. Rules and source checks only: Studio views pending.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Facts = require("../src/shared/ArsenalFacts")
local Catalog = require("../src/shared/ArsenalCatalog")
local Narrative = require("../src/shared/NarrativeCatalog")
local World = require("../src/shared/WorldDefinitions")
local Spells = require("../src/simulation/SpellSchema")
local SpellRules = require("../src/simulation/SpellRules")
local Weapons = require("../src/simulation/WeaponSchema")
local Moves = require("../src/simulation/MoveSchema")
local Combat = require("../src/simulation/CombatRules")
local Store = require("../src/server/ProfileStore")

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local C = "src/client/Controllers/"
local function near(a: number, b: number): boolean return math.abs(a - b) < 1e-9 end
local function souls(attributes, main, reinforcement)
	return { attributes = attributes, inventory = { mainhand = main, reinforcement = reinforcement }, rpg = nil }
end

-- 1. Spell cards use the cast the server would run (#41).
local attrs = { Vigor = 10, Endurance = 10, Strength = 14, Dexterity = 18, ArcaneQi = 25 }
for _, setup in { { "Jian", "None" }, { "Catalyst", "None" }, { "Jian", "Catalyst" } } do
	local ctx = { Attributes = attrs, Reinforcement = { Jian = 2 }, Mainhand = setup[1], Offhand = setup[2] }
	local derived = Store.DeriveStats(souls(attrs, setup[1], { Jian = 2 }))
	local potency, quick = Facts.potency(ctx)
	local fighter = { Weapon = setup[1], State = "Idle", GuardHeld = false, RootUntil = 0, Qi = 100, SpellScale = derived.SpellScale }
	local cast = SpellRules.begin(fighter, "ThunderclapPalm", 0, {}, if setup[2] ~= "None" then setup[2] else nil)
	check(setup[1] .. "/" .. setup[2] .. " potency equals SpellRules.begin", cast and near(cast.Potency, potency))
	check(setup[1] .. "/" .. setup[2] .. " cast time equals the real release", cast and near(cast.Release - cast.Start, Spells.timing(Spells.get("ThunderclapPalm"), quick).Startup))
end
local ctx = { Attributes = attrs, Reinforcement = { Jian = 2 }, Mainhand = "Jian", Offhand = "None" }
local potency = Facts.potency(ctx)
for _, id in Spells.Order do
	local s = Spells.get(id)
	local lines = Facts.spell(id, ctx)
	check(id .. " has a practical description", #lines.Use > 20 and not string.find(lines.Use, "%d"))
	check(id .. " shows Qi cost and cooldown from the schema", string.find(lines.Detail, s.QiCost .. " Qi", 1, true) and string.find(lines.Detail, "cooldown", 1, true))
	check(id .. " shows targeting", string.find(lines.Detail, Facts.targeting(s), 1, true) ~= nil)
	if s.Damage > 0 then
		local shown = math.floor(s.Damage * potency * 10 + 0.5) / 10
		check(id .. " damage scaled like the server", string.find(lines.Effects, (if shown % 1 == 0 then string.format("%d", shown) else string.format("%.1f", shown)) .. " damage", 1, true) ~= nil)
	else
		check(id .. " defensive effect described", #lines.Effects > 5)
	end
end
check("ward duration comes from SpellRules", string.find(Facts.spell("JadeAegis", ctx).Effects, SpellRules.WardSeconds .. "s", 1, true) ~= nil)
check("root and interrupt values from the schema", string.find(Facts.spell("GraveTendrils", ctx).Effects, "roots 2s", 1, true) and string.find(Facts.spell("ThunderclapPalm", ctx).Effects, "0.4s stagger", 1, true))

-- 2. Weapon cards compare with the wielded weapon using the real damage path (#41).
for _, id in Weapons.WeaponKeys do
	local w = Weapons.get(id)
	local reinforcement = { Jian = 2, [id] = 3 }
	local c = { Attributes = attrs, Reinforcement = reinforcement, Mainhand = "Jian", Offhand = "None" }
	local d = Store.DeriveStats(souls(attrs, id, reinforcement))
	local fighter = { Weapon = id, StrengthScale = d.StrengthScale, DexterityScale = d.DexterityScale, VoidScale = 1 }
	local real = Moves.damage(w.Light[1].BaseDamage, nil) * Combat.damageScale(fighter, w.Light[1])
	check(id .. " light hit equals CombatRules damage at these stats", near(Facts.hit(id, w.Light[1], c), real))
	local lines = Facts.weapon(id, c)
	check(id .. " has playstyle text without numbers", #lines.Use > 20 and not string.find(lines.Use, "%d"))
	check(id .. " shows reach, weight class and scaling", string.find(lines.Detail, "reach", 1, true) and string.find(lines.Detail, (w.WeightClass or "Medium") .. " weight", 1, true)
		and string.find(lines.Detail, Combat.scalingAttribute(id), 1, true))
	if id == "Jian" then
		check("wielded weapon shows its own numbers", string.find(lines.Effects, "Wielded", 1, true) ~= nil)
	else
		check(id .. " compares against the wielded Jian", string.find(lines.Effects, "vs Jian Sword", 1, true) and string.find(lines.Effects, "reach", 1, true))
	end
end
check("damage scaling routing unchanged", Combat.scalingAttribute("Guandao") == "Strength" and Combat.scalingAttribute("Jian") == "Dexterity" and Combat.scalingAttribute("Unarmed") == "Strength")
local scythe = Facts.weapon("ChainScythe", { Attributes = attrs, Reinforcement = {}, Mainhand = "Jian", Offhand = "None" }).Effects
check("longer reach is marked better", string.find(scythe, "reach 15 (+7.5) ▲", 1, true) ~= nil)
check("weapon traits read from schema", string.find(Facts.weapon("TwinDaggers", ctx).Detail, "rear hits ×3", 1, true) and string.find(Facts.weapon("Catalyst", ctx).Detail, "spells ×1.25", 1, true))
for id, text in Catalog.SpellUses do check("spell use text belongs to a real spell: " .. id, Spells.get(id) ~= nil and not string.find(text, "%d")) end
for id in Catalog.WeaponUses do check("weapon use text belongs to a real weapon: " .. id, Weapons.Weapons[id] ~= nil) end

-- 3. Slot labels and bindings (#41).
local tabs = src(C .. "ArsenalTabs.luau")
local Tabs = luau.load(string.match(tabs, "function Tabs%.slotText.-\nend") .. "\nreturn Tabs", { debugName = "slotText", environment = { Tabs = {} } })()
check("slot labels use unmistakable numerals and the binding", Tabs.slotText(1, "1", false) == "Slot 1 [1]" and Tabs.slotText(2, "E", true) == "✓ Slot 2 [E]")
check("roman slot numerals removed", not string.find(tabs, '"II"', 1, true) and not string.find(src(C .. "ArsenalPanel.luau"), "Slot II", 1, true))
check("slot buttons read InputMap commands", string.find(tabs, '"SpellOne", "SpellTwo"', 1, true) and string.find(src(C .. "SpellController.luau"), "ui.Input:Label(command)", 1, true))
check("hints derive keys and Qi gains", string.find(src(C .. "ArsenalPanel.luau"), "Settings.Qi.GainOnHit", 1, true) and string.find(src(C .. "ArsenalPanel.luau"), 'label("SpellTwo")', 1, true))
check("cards grow with wrapped text inside the scroll list", string.find(tabs, "AutomaticSize = Enum.AutomaticSize.Y", 1, true) and string.find(tabs, "TextWrapped = true", 1, true))

-- 4. Codex progress and locked lore (#42).
local Codex = luau.load(src(C .. "CodexView.luau"), { debugName = "CodexView", environment = {
	game = { GetService = function() return { AsurasPath = { Shared = { NarrativeCatalog = Narrative, WorldDefinitions = World, InputMap = require("../src/shared/InputMap"), EndingRules = luau.load(src("src/shared/EndingRules.luau"), { debugName = "EndingRules", environment = { Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end } } })() } } } end },
	require = function(m) return m end, string = string, table = table } })()
local function state(lore, bosses) return { inventory = { LoreEntries = lore }, bosses = bosses } end
local empty = Codex.summary(state({}, {}))
check("empty: 0/8 inscriptions, 0/6 sovereigns", Codex.status(empty) == "0 / 8 Inscriptions  ·  0 / 6 Sovereigns at rest")
check("empty: tagline kept and discovery instruction shown", string.find(Codex.body(empty, nil), Codex.Tagline, 1, true) and string.find(Codex.body(empty, nil), "jade memorial", 1, true))
local function leaks(sum, known)
	for _, e in sum.Inscriptions do
		local l = Narrative.Lore[e.Id]
		if not known[e.Id] and (e.Title == l.Title or e.Known) then return true end
	end
	return false
end
check("empty: no titles leak", not leaks(empty, {}))
check("empty: every locked entry says where to look", empty.Inscriptions[5].Hint == "Bamboo Pass" and empty.Souls[1].Hint == "Ash Colosseum")
local partialLore = { Pillars = true, Bamboo = true }
local partial = Codex.summary(state(partialLore, { GrandmasterShen = true }))
check("partial: counts", partial.Found == 2 and partial.Rested == 1 and string.find(Codex.status(partial), "2 / 8", 1, true))
check("partial: discovered titles, locked hidden", partial.Inscriptions[1].Title == Narrative.Lore.Pillars.Title and not leaks(partial, partialLore))
check("partial: selecting a discovered entry shows its text", Codex.body(partial, "Bamboo") == Narrative.Lore.Bamboo.Text)
check("partial: selecting a locked entry never shows its text", Codex.body(partial, "Dawn") ~= Narrative.Lore.Dawn.Text and not string.find(Codex.body(partial, "Dawn"), Narrative.Lore.Dawn.Text, 1, true))
check("partial: remaining count", string.find(Codex.body(partial, nil), "6 inscriptions remain", 1, true) ~= nil)
check("partial: rested sovereign named, others unbound", partial.Souls[1].Title == "Grandmaster Shen" and partial.Souls[2].Title == "Unbound sovereign")
local all, beaten = {}, {}
for _, id in Narrative.LoreOrder do all[id] = true end
for _, id in Narrative.Sovereigns do beaten[id] = true end
local full = Codex.summary(state(all, beaten))
check("full: 8/8 and 6/6", Codex.status(full) == "8 / 8 Inscriptions  ·  6 / 6 Sovereigns at rest")
check("full: completion message", string.find(Codex.body(full, nil), "Every inscription is recovered", 1, true) ~= nil)
check("full: twins named as a pair", full.Souls[5].Title == "The Twin Sentinels")
check("discovery flags must be exactly true", Codex.summary(state({ Pillars = "yes" }, {})).Found == 0)
local view = src(C .. "DialogueView.luau")
check("long lore scales inside its box", string.find(view, "TextScaled=true", 1, true) and string.find(view, "MaxTextSize=20", 1, true))
check("codex rendered by CodexView", string.find(view, "Codex.render(v,data,selected", 1, true) ~= nil)

-- 5. Module hygiene.
local project = src("default.project.json")
for _, path in { C .. "ArsenalTabs.luau", C .. "ArsenalPanel.luau", C .. "CodexView.luau", C .. "DialogueView.luau", "src/shared/ArsenalFacts.luau", "src/shared/ArsenalCatalog.luau" } do
	local text = src(path)
	local _, lines = string.gsub(text, "\n", "")
	check(path .. " strict and under 150 lines", string.sub(text, 1, 9) == "--!strict" and lines < 150)
end
check("new modules registered", string.find(project, "shared/ArsenalFacts.luau", 1, true) and string.find(project, "Controllers/CodexView.luau", 1, true))

print(string.format("arsenal codex: %d passed, %d failed", passed, failed))
if failed > 0 then error("arsenal codex regression failed") end

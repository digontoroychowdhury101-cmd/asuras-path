--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/ArsenalFacts
-- Text for Arsenal cards, derived from the live schemas and the same scaling the server applies:
-- spell targeting/effects/cost from SpellSchema (+ SpellRules focus, LevelPreview SpellScale), and
-- weapon style plus a comparison with the wielded weapon from WeaponSchema, MoveSchema.damage and
-- CombatRules.scalingAttribute with the player's attributes and per-weapon forge tier. Words that
-- describe a spell's or weapon's role live in ArsenalCatalog; numbers never do.
local hasScript = pcall(function() return script.Parent end)
local function load(name: string, sim: boolean): any
	if hasScript then
		local root = (script :: any).Parent
		return require(if sim then root.Parent.Simulation[name] else root[name])
	end
	return nil
end
local Spells: any = load("SpellSchema", true) or require("../simulation/SpellSchema")
local Weapons: any = load("WeaponSchema", true) or require("../simulation/WeaponSchema")
local Moves: any = load("MoveSchema", true) or require("../simulation/MoveSchema")
local Combat: any = load("CombatRules", true) or require("../simulation/CombatRules")
local SpellRules: any = load("SpellRules", true) or require("../simulation/SpellRules")
local Preview: any = load("LevelPreview", false) or require("./LevelPreview")
local Catalog: any = load("ArsenalCatalog", false) or require("./ArsenalCatalog")

local Facts = {}

export type Context = { Attributes: { [string]: number }, Reinforcement: { [string]: number }, Mainhand: string, Offhand: string? }
export type Lines = { Use: string, Detail: string, Effects: string }

local GRIP: { [string]: string } = { Fist = "bare-handed", OneHanded = "one-handed", TwoHanded = "two-handed" }

local function num(n: number): string
	local r = math.floor(n * 10 + 0.5) / 10
	return if r % 1 == 0 then string.format("%d", r) else string.format("%.1f", r)
end

-- Spell potency exactly as SpellRules.begin computes it: weapon focus × Arcane Qi SpellScale.
function Facts.potency(ctx: Context): (number, boolean)
	local focus, quick = SpellRules.focus({ Weapon = ctx.Mainhand }, if ctx.Offhand ~= "None" then ctx.Offhand else nil)
	local tier = ctx.Reinforcement[ctx.Mainhand] or 0
	return focus * Preview.derived(ctx.Attributes, tier).SpellScale, quick
end

function Facts.targeting(s: any): string
	if s.Shape == "Self" then
		return if s.Status.Teleport then "Self · dash " .. num(s.Range) .. " studs" else "Self"
	elseif s.Shape == "Cone" then
		return string.format("Cone %d° · %s studs", s.Arc, num(s.Range))
	elseif s.Shape == "Line" then
		return (if s.Speed > 0 then "Projectile · " else "Line · ") .. num(s.Range) .. " studs" .. (if s.Pierces then " · pierces" else "")
	elseif s.Shape == "Pillars" then
		return string.format("%d pillar%s on foes within %s studs", s.Pulses, if s.Pulses == 1 then "" else "s", num(s.Range))
	elseif s.Shape == "Aura" then
		return "Aura around you · radius " .. num(s.Range)
	end
	return "Strike " .. num(s.Range) .. " studs away · blast radius " .. num(s.Radius)
end

function Facts.effects(s: any, potency: number): string
	local parts: { string } = {}
	if s.Damage > 0 then
		local hits = if s.Pulses > 1 then string.format(" × %d", s.Pulses) else ""
		table.insert(parts, num(s.Damage * potency) .. " damage" .. hits)
		table.insert(parts, num(s.Posture * potency) .. " posture")
	end
	local st = s.Status
	if st.Burn > 0 then table.insert(parts, "+" .. st.Burn .. " burn") end
	if st.Root > 0 then table.insert(parts, "roots " .. num(st.Root) .. "s") end
	if st.Interrupt then table.insert(parts, "interrupts (" .. num(SpellRules.InterruptSeconds) .. "s stagger)") end
	if st.IgnoreGuard then table.insert(parts, "ignores guard") end
	if st.Drain > 0 then table.insert(parts, "−" .. num(st.Drain) .. " stamina per hit") end
	if st.Ward then table.insert(parts, "blocks your next posture break for " .. SpellRules.WardSeconds .. "s") end
	if st.Teleport and s.Shape ~= "Self" then table.insert(parts, "carries you to the target") end
	if st.Decoy then table.insert(parts, "leaves a phantom decoy") end
	return table.concat(parts, " · ")
end

function Facts.spell(id: string, ctx: Context): Lines
	local s = assert(Spells.get(id), "Unknown spell")
	local potency, quick = Facts.potency(ctx)
	local cast = Spells.timing(s, quick).Startup
	return {
		Use = Catalog.SpellUses[id] or "",
		Detail = string.format("%s  ·  %d Qi  ·  %ss cooldown  ·  %ss cast", Facts.targeting(s), s.QiCost, num(s.Cooldown), string.format("%.2f", cast)),
		Effects = Facts.effects(s, potency),
	}
end

-- Damage a facing hit deals with this weapon in hand, before infusion and injuries.
function Facts.hit(id: string, move: any, ctx: Context): number
	local derived = Preview.derived(ctx.Attributes, ctx.Reinforcement[id] or 0)
	local scale = if Combat.scalingAttribute(id) == "Strength" then derived.StrengthScale else derived.DexterityScale
	return Moves.damage(move.BaseDamage, nil) * scale
end

-- Seconds keep two decimals (swings differ by hundredths); other values one.
local function versus(label: string, mine: number, theirs: number, unit: string, better: boolean): string
	local fine = unit == "s"
	local function show(n: number): string return if fine then string.format("%.2f", n) else num(n) end
	local delta = mine - theirs
	local same = math.abs(delta) < (if fine then 0.005 else 0.05)
	local sign = if same then "=" elseif delta > 0 then "+" .. show(delta) else "−" .. show(-delta)
	return string.format("%s %s%s (%s)", label, show(mine), unit, sign) .. (if same then "" elseif better then " ▲" else " ▼")
end

-- Special properties a weapon has beyond the defaults WeaponSchema.build fills in.
function Facts.traits(w: any): { string }
	local list: { string } = {}
	if (w.CriticalMultiplier or 1.5) ~= 1.5 then table.insert(list, "rear hits ×" .. num(w.CriticalMultiplier)) end
	if (w.SpellPotency or 1) > 1 then table.insert(list, "spells ×" .. string.format("%.2f", w.SpellPotency)) end
	if w.QuickCast then table.insert(list, "faster casting") end
	if w.ProjectileParry then table.insert(list, "guard turns projectiles") end
	if (w.PostureReflect or 0) > 0 then table.insert(list, "reflects " .. num(w.PostureReflect * 100) .. "% posture damage") end
	return list
end

function Facts.weapon(id: string, ctx: Context): Lines
	local w = Weapons.get(id)
	local light, heavy = w.Light[1], w.Heavy
	local attribute = Combat.scalingAttribute(id)
	local detail = string.format("%s · %s · %s weight · reach %s · %d-hit string · scales with %s",
		w.Stance or "Balanced", GRIP[w.Grip] or w.Grip, w.WeightClass or "Medium", num(w.Reach), #w.Light, attribute)
	local traits = Facts.traits(w)
	if #traits > 0 then detail ..= " · " .. table.concat(traits, " · ") end
	local mine = { Facts.hit(id, light, ctx), Facts.hit(id, heavy, ctx), w.Reach, light.Timing.TotalSeconds }
	local effects: string
	if id == ctx.Mainhand then
		effects = string.format("Wielded · light %s · heavy %s · light swing %.2fs · art %s (%d Qi)", num(mine[1]), num(mine[2]), mine[4], w.WeaponArt.Name, w.WeaponArt.QiCost)
	else
		local e = Weapons.get(ctx.Mainhand)
		local theirs = { Facts.hit(ctx.Mainhand, e.Light[1], ctx), Facts.hit(ctx.Mainhand, e.Heavy, ctx), e.Reach, e.Light[1].Timing.TotalSeconds }
		effects = "vs " .. e.Name .. ": " .. table.concat({
			versus("light", mine[1], theirs[1], "", mine[1] > theirs[1]),
			versus("heavy", mine[2], theirs[2], "", mine[2] > theirs[2]),
			versus("reach", mine[3], theirs[3], "", mine[3] > theirs[3]),
			versus("swing", mine[4], theirs[4], "s", mine[4] < theirs[4]),
		}, " · ")
	end
	return { Use = Catalog.WeaponUses[id] or "", Detail = detail, Effects = effects }
end

-- Context from an ArsenalIntent inventory packet and the player's published attributes.
function Facts.context(inv: any, attributes: { [string]: number }): Context
	return { Attributes = attributes, Reinforcement = inv.reinforcement or {}, Mainhand = inv.mainhand or "Unarmed", Offhand = inv.offhand }
end

return table.freeze(Facts)

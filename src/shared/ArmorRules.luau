--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/ArmorRules
-- The one armour source: catalogue, ownership, prices, reinforcement and worn values, read by migration, the smith,
-- combat stats and the panel alike. Engine-free. Values and rationale: outputs/mac-followup-2026-11-02/armour/RESULTS.md.
-- Worn values reach combat as Stats (ProfileStore.DeriveStats): Protection scales strikes, chip, spells and boss attacks
-- (never burn, bleed, a deathblow or the void), PostureBonus widens the existing posture bar, and Speed is one more factor
-- in CombatRules.speedMultiplier. Timing windows, dashes, attacks and input are untouched by any suit.
local Rules = {}

export type ArmorSet = {
	Name: string, Role: string, Blurb: string,
	Protection: number, Posture: number, Speed: number, -- at +0
	PerProtection: number, PerPosture: number, -- each reinforcement
	Base: number, -- Essence for the first reinforcement
	Price: number?, Material: string?, Need: number?, -- to acquire; nil = everyone starts with it
	Altar: string?, Boss: string?, Requirement: string?,
}

Rules.Default = "AshenPilgrim"
Rules.None = "None" -- saved when the player took armour off, so a reload does not dress them again
Rules.MaxLevel = 5
Rules.MaxProtection = 0.3
Rules.Order = table.freeze({ "AshenPilgrim", "CinnabarGuard", "IronOath" })
Rules.Sets = table.freeze({
	AshenPilgrim = table.freeze({ Name = "Ashen Pilgrim", Role = "Light", Blurb = "Road linen and old sash. Nothing slows you.",
		Protection = 0, Posture = 0, Speed = 1, PerProtection = 0.006, PerPosture = 2, Base = 120 }),
	CinnabarGuard = table.freeze({ Name = "Cinnabar Guard", Role = "Medium", Blurb = "Lacquered lamellar over cinnabar cloth.",
		Protection = 0.10, Posture = 15, Speed = 0.97, PerProtection = 0.012, PerPosture = 3, Base = 280,
		Price = 1200, Material = "SpiritIronOre", Need = 3, Altar = "Altar_DesecratedCloister", Requirement = "Kindle the Desecrated Cloister altar" }),
	IronOath = table.freeze({ Name = "Iron Oath", Role = "Heavy", Blurb = "Plate sworn over lamellar. It holds, and it weighs.",
		Protection = 0.18, Posture = 30, Speed = 0.92, PerProtection = 0.012, PerPosture = 4, Base = 480,
		Price = 3600, Material = "StarfallShard", Need = 2, Boss = "TwinSentinels", Requirement = "Lay the Twin Sentinels to rest" }),
} :: { [string]: ArmorSet })

local function whole(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == v and v >= lo and v <= hi and v % 1 == 0
end

function Rules.defaults(): { [string]: { Level: number } }
	return { [Rules.Default] = { Level = 0 } }
end

-- Unknown sets and impossible levels fall away; the starter is always owned.
function Rules.migrate(raw: any): { [string]: { Level: number } }
	local owned = Rules.defaults()
	if type(raw) == "table" then
		for id, entry in raw do
			if type(id) == "string" and Rules.Sets[id] and type(entry) == "table" then
				owned[id] = { Level = if whole(entry.Level, 0, Rules.MaxLevel) then entry.Level else 0 }
			end
		end
	end
	return owned
end

-- What a saved or missing ArmorSet means: an owned set stays, "None" stays, anything else wears the starter.
function Rules.resolve(owned: any, saved: any): string
	if saved == Rules.None then return Rules.None end
	if type(saved) == "string" and Rules.Sets[saved] and owned[saved] then return saved end
	return Rules.Default
end

function Rules.validOwned(owned: any): boolean
	if type(owned) ~= "table" or not owned[Rules.Default] then return false end
	for id, entry in owned do
		if type(id) ~= "string" or not Rules.Sets[id] or type(entry) ~= "table" or not whole(entry.Level, 0, Rules.MaxLevel) then return false end
	end
	return true
end

function Rules.validWorn(owned: any, worn: any): boolean
	return worn == Rules.None or (type(worn) == "string" and Rules.Sets[worn] ~= nil and owned[worn] ~= nil)
end

function Rules.values(id: string, level: number): { Protection: number, Posture: number, Speed: number }
	local set = Rules.Sets[id]
	return { Protection = math.min(set.Protection + set.PerProtection * level, Rules.MaxProtection),
		Posture = set.Posture + set.PerPosture * level, Speed = set.Speed }
end

-- The combat values of what is worn; the absent or malformed answer is bare, so a stripped view (ranked) carries nothing.
function Rules.worn(owned: any, worn: any): { Protection: number, Posture: number, Speed: number }
	if type(owned) == "table" and type(worn) == "string" and Rules.Sets[worn] and type(owned[worn]) == "table" and whole(owned[worn].Level, 0, Rules.MaxLevel) then
		return Rules.values(worn, owned[worn].Level)
	end
	return { Protection = 0, Posture = 0, Speed = 1 }
end

-- Price of reinforcing `level` to `level`+1.
function Rules.upgradeCost(id: string, level: number): (number, string, number)
	local material = if level < 3 then "SpiritIronOre" else "StarfallShard"
	return math.floor(Rules.Sets[id].Base * (level + 1) ^ 1.4), material, if level < 3 then level + 1 else level - 2
end

function Rules.acquireRefusal(p: any, id: string): string?
	local set = Rules.Sets[id]
	if not set then return "Unknown armour" end
	if p.inventory.Armor[id] then return "Already yours" end
	if not set.Price then return "Unknown armour" end
	if set.Altar and not (p.unlockedAltars and p.unlockedAltars[set.Altar]) then return set.Requirement end
	if set.Boss and not (p.defeatedBosses and p.defeatedBosses[set.Boss]) then return set.Requirement end
	if p.qiEssence < set.Price then return "Not enough Essence" end
	if (p.inventory.Materials[set.Material :: string] or 0) < (set.Need :: number) then return "Missing " .. (set.Material :: string) end
	return nil
end

function Rules.acquire(p: any, id: string)
	local refused = Rules.acquireRefusal(p, id); assert(not refused, refused)
	local set = Rules.Sets[id]
	p.qiEssence -= set.Price :: number
	p.inventory.Materials[set.Material :: string] -= set.Need :: number
	p.inventory.Armor[id] = { Level = 0 }
end

-- `level`, when given, is the level the quote was shown for: a set that moved since refuses rather than charge an unseen price.
function Rules.upgradeRefusal(p: any, id: string, level: number?): string?
	local entry = p.inventory.Armor[id]
	if not Rules.Sets[id] or not entry then return "Armour is not yours" end
	if level ~= nil and entry.Level ~= level then return "The quote is out of date" end
	if entry.Level >= Rules.MaxLevel then return "Already +" .. Rules.MaxLevel end
	local cost, material, need = Rules.upgradeCost(id, entry.Level)
	if p.qiEssence < cost then return "Not enough Essence" end
	if (p.inventory.Materials[material] or 0) < need then return "Missing " .. material end
	return nil
end

function Rules.upgrade(p: any, id: string, level: number?): number
	local refused = Rules.upgradeRefusal(p, id, level); assert(not refused, refused)
	local entry = p.inventory.Armor[id]
	local cost, material, need = Rules.upgradeCost(id, entry.Level)
	p.qiEssence -= cost
	p.inventory.Materials[material] -= need
	entry.Level += 1
	return entry.Level
end

function Rules.wearRefusal(p: any, id: string): string?
	if id ~= Rules.None and (not Rules.Sets[id] or not p.inventory.Armor[id]) then return "Armour is not yours" end
	if p.equippedLoadout.ArmorSet == id then return if id == Rules.None then "Already unarmoured" else "Already worn" end
	return nil
end

function Rules.wear(p: any, id: string)
	local refused = Rules.wearRefusal(p, id); assert(not refused, refused)
	p.equippedLoadout.ArmorSet = id
end

-- The panel's view of one set, from the numbers above and the same refusals the smith applies.
function Rules.quote(view: any, id: string): any
	local set = Rules.Sets[id]
	local record = { qiEssence = view.qi, inventory = view.inventory, unlockedAltars = view.altars, defeatedBosses = view.bosses, equippedLoadout = view.loadout }
	local entry = view.inventory.Armor[id]
	local level = if entry then entry.Level else 0
	local now = Rules.values(id, level)
	local q: any = { Id = id, Name = set.Name, Role = set.Role, Blurb = set.Blurb, Owned = entry ~= nil, Level = level,
		Worn = view.loadout.ArmorSet == id, Values = now, Compare = Rules.worn(view.inventory.Armor, view.loadout.ArmorSet) }
	if not entry then
		q.Acquire = { Price = set.Price, Material = set.Material, Need = set.Need, Have = view.inventory.Materials[set.Material :: string] or 0,
			Requirement = set.Requirement, Refusal = Rules.acquireRefusal(record, id) }
	elseif level < Rules.MaxLevel then
		local cost, material, need = Rules.upgradeCost(id, level)
		q.Next = { Level = level + 1, Values = Rules.values(id, level + 1), Cost = cost, Material = material, Need = need,
			Have = view.inventory.Materials[material] or 0, Refusal = Rules.upgradeRefusal(record, id, level) }
	end
	return q
end

return table.freeze(Rules)

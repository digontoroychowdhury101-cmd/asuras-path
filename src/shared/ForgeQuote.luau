--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/ForgeQuote
-- What Master Smith Gao's panel shows for one owned weapon, from the numbers the server charges and
-- fights with: ProgressionRules for tier, price and refusal, ArsenalFacts.hit (MoveSchema.damage and
-- the weapon's own scaling attribute, the figure test_arsenal_codex holds equal to CombatRules) for
-- the blow before and after. The view is DialogueActions.view. Display only: the server recomputes.
local hasScript = pcall(function() return script.Parent end)
local Rules: any = if hasScript then require((script :: any).Parent.ProgressionRules) else require("./ProgressionRules")
local Facts: any = if hasScript then require((script :: any).Parent.ArsenalFacts) else require("./ArsenalFacts")
local Combat: any = if hasScript then require((script :: any).Parent.Parent.Simulation.CombatRules) else require("../simulation/CombatRules")
local Weapons: any = if hasScript then require((script :: any).Parent.Parent.Simulation.WeaponSchema) else require("../simulation/WeaponSchema")

local Quote = {}

export type Quote = {
	Weapon: string, Name: string, Tier: number, Equipped: boolean, Infusion: string?, Attribute: string,
	Light: number, Heavy: number,
	Next: { Tier: number, Light: number, Heavy: number, Cost: number, Material: string, Need: number, Have: number }?,
	Refusal: string?, -- ProgressionRules' reason the next tier cannot be bought now; nil when it can (or at the cap)
}

-- Every owned weapon, the one in hand first, then by name.
function Quote.weapons(view: any): { string }
	local list: { string } = {}
	for id in view.inventory.Weapons do table.insert(list, id) end
	local main = view.loadout.MainWeapon
	table.sort(list, function(a: string, b: string)
		if (a == main) ~= (b == main) then return a == main end
		return a < b
	end)
	return list
end

function Quote.of(view: any, id: string): Quote
	local w = view.inventory.Weapons[id]
	local weapon = Weapons.get(id)
	local function blows(tier: number): (number, number)
		local ctx = { Attributes = view.attributes, Reinforcement = { [id] = tier }, Mainhand = id }
		return Facts.hit(id, weapon.Light[1], ctx), Facts.hit(id, weapon.Heavy, ctx)
	end
	local light, heavy = blows(w.Level)
	local quote: Quote = {
		Weapon = id, Name = weapon.Name, Tier = w.Level, Equipped = view.loadout.MainWeapon == id, Infusion = w.Infusion,
		Attribute = Combat.scalingAttribute(id), Light = light, Heavy = heavy, Next = nil, Refusal = nil,
	}
	if w.Level < Rules.MaxTier then
		local cost, material, need = Rules.upgradeCost(w.Level)
		local nextLight, nextHeavy = blows(w.Level + 1)
		quote.Next = { Tier = w.Level + 1, Light = nextLight, Heavy = nextHeavy, Cost = cost, Material = material, Need = need,
			Have = view.inventory.Materials[material] or 0 }
		quote.Refusal = Rules.upgradeRefusal({ qiEssence = view.qi, inventory = view.inventory }, id, w.Level)
	end
	return quote
end

return table.freeze(Quote)

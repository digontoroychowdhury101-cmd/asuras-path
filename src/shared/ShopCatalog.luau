--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/ShopCatalog
-- Immutable catalog of fighting style gacha probabilities, vanity cosmetics, and monetization pricing.

export type StyleDrop = {
	name: string,
	displayName: string,
	rarity: string, -- "Common" | "Rare" | "Epic" | "Legendary"
	weight: number,
	description: string,
}

export type CosmeticItem = {
	id: string,
	slot: string, -- "Trunks" | "Gloves" | "Taunt"
	name: string,
	rarity: string,
	cashPrice: number,
	robuxPrice: number?, -- nil if cash only
	description: string,
}

export type CurrencyBundle = {
	id: string,
	name: string,
	bundleType: string, -- "Cash" | "Spins" | "Pass"
	amount: number,
	robuxPrice: number,
	productId: number,
	badge: string?,
	description: string,
}

local function deepFreeze(t: any): any
	if type(t) ~= "table" or table.isfrozen(t) then
		return t
	end
	for _, v in pairs(t) do
		if type(v) == "table" then
			deepFreeze(v)
		end
	end
	return table.freeze(t)
end

local ShopCatalog = {
 Crates={
  Wrap={name="Wrap roll",cost=100,refund=25,drops={{id="Wrap_White",weight=60},{id="Wrap_Crimson",weight=28},{id="Wrap_Cyan",weight=10},{id="Wrap_Gold",weight=2}}},
  Accessory={name="Accessory crate",cost=200,refund=50,drops={{id="Accessory_RedBand",weight=75},{id="Accessory_CyanBand",weight=22},{id="Accessory_GoldBand",weight=3}}},
 },
	PityThreshold = 20,
	SpinCostCash = 150,
	MultiSpinCostCash = 1350, -- 10 spins for price of 9
	DuplicateXpBonus = 250, -- Awarded when rolling an already unlocked style

	Styles = {
		{
			name = "Ironline",
			displayName = "Ironline Boxing",
			rarity = "Common",
			weight = 400,
			description = "Boxing fundamentals, high guard resilience, and bone-crushing straight punches.",
		},
		{
			name = "Groundforge",
			displayName = "Groundforge Wrestling",
			rarity = "Common",
			weight = 350,
			description = "Mat wrestling dominance, high takedown leverage, and top control stamina efficiency.",
		},
		{
			name = "ApexStriker",
			displayName = "Apex Striker Muay Thai",
			rarity = "Rare",
			weight = 180,
			description = "Lethal kickboxing arcs, extended active hitboxes, and fierce clinch knees.",
		},
		{
			name = "CobraFlow",
			displayName = "Cobra Flow Counter-Striking",
			rarity = "Epic",
			weight = 60,
			description = "Lightning-fast head movement, slip counters, and pinpoint counter-hit damage scaling.",
		},
		{
			name = "DragonClaw",
			displayName = "Dragon Claw Combat Sambo",
			rarity = "Legendary",
			weight = 10,
			description = "Elite joint locks, vicious submission pressure drain, and high-impact judo hip throws.",
		},
	} :: {StyleDrop},

	Cosmetics = {
		-- Trunks
		Trunks_Charcoal = {
			id = "Trunks_Charcoal",
			slot = "Trunks",
			name = "Standard Charcoal Trunks",
			rarity = "Common",
			cashPrice = 0,
			description = "Regulation fight shorts issued to all debutants.",
		},
		Trunks_GladiatorBlack = {
			id = "Trunks_GladiatorBlack",
			slot = "Trunks",
			name = "Gladiator Black Fight Shorts",
			rarity = "Rare",
			cashPrice = 500,
			robuxPrice = 75,
			description = "Reinforced stretch fabric with matte black finish and red trim.",
		},
		Trunks_ViperGreen = {
			id = "Trunks_ViperGreen",
			slot = "Trunks",
			name = "Viper Strike Venom Shorts",
			rarity = "Epic",
			cashPrice = 1200,
			robuxPrice = 199,
			description = "Acid-green geometric scale patterns favored by high-energy kickers.",
		},
		Trunks_ChampionshipGold = {
			id = "Trunks_ChampionshipGold",
			slot = "Trunks",
			name = "Undisputed Championship Gold Trunks",
			rarity = "Legendary",
			cashPrice = 3000,
			robuxPrice = 399,
			description = "Pure gold leaf side-panels reserved for champions of the cage.",
		},

		-- Gloves
		Gloves_Black = {
			id = "Gloves_Black",
			slot = "Gloves",
			name = "Standard 4oz Fight Mitts",
			rarity = "Common",
			cashPrice = 0,
			description = "Regulation four-ounce leather competition gloves.",
		},
		Gloves_BloodRed = {
			id = "Gloves_BloodRed",
			slot = "Gloves",
			name = "Crimson Knuckle Wraps",
			rarity = "Rare",
			cashPrice = 450,
			robuxPrice = 75,
			description = "Blood-red impact padding engineered for heavy punchers.",
		},
		Gloves_CyanLightning = {
			id = "Gloves_CyanLightning",
			slot = "Gloves",
			name = "Neon Surge Strike Gloves",
			rarity = "Epic",
			cashPrice = 1100,
			robuxPrice = 199,
			description = "Electric cyan wrist trim with responsive shock-absorption foam.",
		},
		Gloves_GoldenClaw = {
			id = "Gloves_GoldenClaw",
			slot = "Gloves",
			name = "Golden Sovereign Fight Gloves",
			rarity = "Legendary",
			cashPrice = 2800,
			robuxPrice = 349,
			description = "Gilded fist mitts with embossed lion emblem.",
		},

		Wrap_White={id="Wrap_White",slot="Wrap",name="White cotton wraps",rarity="Common",cashPrice=0,description="Clean competition cotton."},
  Wrap_Crimson={id="Wrap_Crimson",slot="Wrap",name="Crimson wraps",rarity="Rare",cashPrice=250,description="Deep red woven cotton."},
  Wrap_Cyan={id="Wrap_Cyan",slot="Wrap",name="Glacier wraps",rarity="Epic",cashPrice=600,description="Ice blue woven cotton."},
  Wrap_Gold={id="Wrap_Gold",slot="Wrap",name="Champion wraps",rarity="Legendary",cashPrice=1200,description="Gold competition cotton."},
  Accessory_None={id="Accessory_None",slot="Accessory",name="No accessory",rarity="Common",cashPrice=0,description="Keep it simple."},
  Accessory_RedBand={id="Accessory_RedBand",slot="Accessory",name="Crimson headband",rarity="Rare",cashPrice=300,description="A crimson training band."},
  Accessory_CyanBand={id="Accessory_CyanBand",slot="Accessory",name="Glacier headband",rarity="Epic",cashPrice=700,description="A glacier blue training band."},
  Accessory_GoldBand={id="Accessory_GoldBand",slot="Accessory",name="Champion headband",rarity="Legendary",cashPrice=1400,description="A gold training band."},
  Skin_Light={id="Skin_Light",slot="Skin",name="Light skin",rarity="Common",cashPrice=0,description="Free appearance option."},
  Skin_Tan={id="Skin_Tan",slot="Skin",name="Tan skin",rarity="Common",cashPrice=0,description="Free appearance option."},
  Skin_Deep={id="Skin_Deep",slot="Skin",name="Deep skin",rarity="Common",cashPrice=0,description="Free appearance option."},
  Hair_None={id="Hair_None",slot="Hair",name="Shaved hair",rarity="Common",cashPrice=0,description="Free appearance option."},
  Hair_Crop={id="Hair_Crop",slot="Hair",name="Cropped hair",rarity="Common",cashPrice=0,description="Free appearance option."},
  Hair_Sweep={id="Hair_Sweep",slot="Hair",name="Swept hair",rarity="Common",cashPrice=0,description="Free appearance option."},
  -- Victory Taunts
		Taunt_Bow = {
			id = "Taunt_Bow",
			slot = "Taunt",
			name = "Martial Bow of Respect",
			rarity = "Common",
			cashPrice = 0,
			description = "Traditional bow honoring your opponent and the referee.",
		},
		Taunt_CageClimb = {
			id = "Taunt_CageClimb",
			slot = "Taunt",
			name = "Octagon Fence Roar",
			rarity = "Rare",
			cashPrice = 800,
			robuxPrice = 99,
			description = "Ascend the octagon rails and celebrate facing the crowd.",
		},
		Taunt_BeltSlap = {
			id = "Taunt_BeltSlap",
			slot = "Taunt",
			name = "Waist Championship Slap",
			rarity = "Epic",
			cashPrice = 2000,
			robuxPrice = 249,
			description = "Tap your waist gesturing towards the world title belt.",
		},
		Taunt_ShadowboxFlex = {
			id = "Taunt_ShadowboxFlex",
			slot = "Taunt",
			name = "Lightning Combo Flex",
			rarity = "Legendary",
			cashPrice = 3500,
			robuxPrice = 499,
			description = "Rapid 4-punch combination into a front double-bicep flex.",
		},
	} :: { [string]: CosmeticItem },

	Bundles = {
		Cash_Small = {
			id = "Cash_Small",
			name = "500 Fight Cash",
			bundleType = "Cash",
			amount = 500,
			robuxPrice = 49,
			productId = 10001,
			badge = "POPULAR",
			description = "Quick boost to your purse for rolls and gear.",
		},
		Cash_Medium = {
			id = "Cash_Medium",
			name = "2,500 Fight Cash",
			bundleType = "Cash",
			amount = 2500,
			robuxPrice = 199,
			productId = 10002,
			badge = "+25% BONUS",
			description = "Substantial fight purse for elite gloves and multi-spins.",
		},
		Cash_Large = {
			id = "Cash_Large",
			name = "10,000 Fight Cash",
			bundleType = "Cash",
			amount = 10000,
			robuxPrice = 699,
			productId = 10003,
			badge = "BEST VALUE",
			description = "Championship vault for complete discipline collection.",
		},
		Spins_5 = {
			id = "Spins_5",
			name = "5 Style Spins",
			bundleType = "Spins",
			amount = 5,
			robuxPrice = 99,
			productId = 10004,
			badge = "STARTER",
			description = "5 attempts at rolling rare and epic fighting disciplines.",
		},
		Spins_25 = {
			id = "Spins_25",
			name = "25 Style Spins",
			bundleType = "Spins",
			amount = 25,
			robuxPrice = 399,
			productId = 10005,
			badge = "PITY GUARANTEED",
			description = "Guarantees at least 1 Epic or Legendary discipline via pity threshold!",
		},
		VIP_Pass = {
			id = "VIP_Pass",
			name = "VIP Championship Pass",
			bundleType = "Pass",
			amount = 1,
			robuxPrice = 499,
			productId = 10006,
			badge = "LIFETIME VIP",
			description = "Permanent 2x Style XP earnings + Golden Octagon Nameplate.",
		},
	} :: { [string]: CurrencyBundle },
}

-- Validation assertion
local totalWeight = 0
for _, style in ShopCatalog.Styles do
	assert(style.weight > 0, "Style weight must be positive")
	totalWeight += style.weight
end
assert(totalWeight == 1000, "Style drop weights must sum exactly to 1000")

return deepFreeze(ShopCatalog)

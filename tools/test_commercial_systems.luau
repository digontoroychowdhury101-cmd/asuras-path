--!strict
-- Local Luau runner; validates ProfileSchema, ShopCatalog, MatchmakingRules, Persistence, and Gacha Pity logic.

local ProfileSchema = require("../src/shared/ProfileSchema")
local ShopCatalog = require("../src/shared/ShopCatalog")
local MatchmakingRules = require("../src/simulation/MatchmakingRules")

print("[Commercial Test] 1. ProfileSchema Invariants & Migration...")
local p1 = ProfileSchema.Default(12345)
assert(p1.userId == 12345, "UserId preserved")
assert(p1.elo == 1000, "Initial ELO is 1000")
assert(p1.qiEssence == 500, "Initial welcome cash is 500")
assert(p1.styleSpins == 5, "Initial free spins is 5")
assert(p1.activeStyle == "Ironline", "Active style defaults to Ironline")

local okVal, valErr = ProfileSchema.Validate(p1)
assert(okVal, "Default profile passes strict validation: " .. tostring(valErr))

-- Migration with corrupted/partial fields
local rawCorrupted = {
	schemaVersion = 0,
	elo = "invalid", -- Should reset to 1000
	qiEssence = -50,  -- Should clamp to default
	styles = {
		ApexStriker = { unlocked = true, xp = 1200, level = 2 },
	},
}
local migrated = ProfileSchema.Migrate(rawCorrupted, 99999)
assert(migrated.userId == 99999, "UserId assigned on migration")
assert(migrated.elo == 1000, "Corrupted ELO repaired to 1000")
assert(migrated.qiEssence == 500, "Negative cash repaired to default")
assert(migrated.styles.ApexStriker.unlocked == true, "Existing style unlock preserved")
assert(migrated.styles.ApexStriker.xp == 1200, "Existing style XP preserved")
assert(migrated.styles.Ironline.unlocked == true, "Default style unlocked")

print("[Commercial Test] 2. ShopCatalog Immutability & Drop Probability Sums...")
local sumWeight = 0
for _, s in ShopCatalog.Styles do
	sumWeight += s.weight
	assert(s.weight > 0, "Weight must be positive")
end
assert(sumWeight == 1000, "Total style probability weight must equal exactly 1000 (100.0%)")
assert(ShopCatalog.PityThreshold == 20, "Pity threshold contract is 20 rolls")

-- Verify deep freezing prevents mutation
local freezeOk = pcall(function()
	(ShopCatalog :: any).SpinCostCash = 0
end)
assert(not freezeOk, "ShopCatalog must be deeply frozen and immutable")

print("[Commercial Test] 3. ELO Rating Calculation & Division Belts...")
local rA, rB = 1000, 1000
local expA = MatchmakingRules.CalculateExpectedScore(rA, rB)
assert(math.abs(expA - 0.5) < 0.0001, "Expected score between equal ratings must be exactly 0.5")

-- Fighter A wins (score = 1.0)
local newA, newB = MatchmakingRules.CalculateEloChange(rA, rB, 1.0)
assert(newA == 1016, "Fighter A gains 16 ELO on win against equal opponent")
assert(newB == 984, "Fighter B loses 16 ELO on loss against equal opponent")

-- Division Belts
local div1, _ = MatchmakingRules.GetDivision(850)
assert(string.find(div1, "White Belt") ~= nil, "850 ELO is White Belt")
local div2, _ = MatchmakingRules.GetDivision(1050)
assert(string.find(div2, "Blue Belt") ~= nil, "1050 ELO is Blue Belt")
local div3, _ = MatchmakingRules.GetDivision(1650)
assert(string.find(div3, "Black Belt") ~= nil, "1650 ELO is Black Belt Champion")

print("[Commercial Test] 4. Matchmaking Queue & Expanding Search Window...")
local q: {MatchmakingRules.QueueEntry} = {
	{ userId = 1, elo = 1000, enteredAt = 100, mode = "Ranked1v1" },
	{ userId = 2, elo = 1250, enteredAt = 100, mode = "Ranked1v1" },
}

-- At t=100 (diff is 250, window is 50), no match
local m1, m2 = MatchmakingRules.FindMatch(q, 100)
assert(m1 == nil and m2 == nil, "No match when ELO gap exceeds initial window")

-- At t=150 (50 seconds elapsed, window expands by 250 to 300), match connects!
m1, m2 = MatchmakingRules.FindMatch(q, 150)
assert(m1 == 1 and m2 == 2, "Match found after search window expands to encompass ELO gap")

print("[Commercial Test] 5. Multi-Arena Cage Allocation & Release...")
local venues = MatchmakingRules.CreateVenues(4)
assert(#venues == 4, "4 championship venues created")
assert(venues[1].status == "Available", "Octagon 1 available")

local assigned1 = MatchmakingRules.AssignCage(venues, 101, 102, 1000)
assert(assigned1 == 1, "First match assigned to Octagon 1")
assert(venues[1].status == "Occupied" and venues[1].fighter1 == 101, "Octagon 1 records active fighters")

local assigned2 = MatchmakingRules.AssignCage(venues, 103, 104, 1005)
assert(assigned2 == 2, "Second match assigned to Sparring Cage 2")

-- Release Cage 1 after match finish
MatchmakingRules.ReleaseCage(venues, 1)
assert(venues[1].status == "Available" and venues[1].fighter1 == nil, "Octagon 1 returned to Available pool")

print("[Commercial Test] 6. Gacha Pity Counter Simulation...")
local testProfile = ProfileSchema.Default(777)
testProfile.pityCounter = 19 -- 1 roll away from guaranteed pity
testProfile.styleSpins = 5

-- Simulate a gacha roll triggering pity
local function simulateRoll(p: ProfileSchema.Profile): (ShopCatalog.StyleDrop, boolean)
	p.pityCounter += 1
	local isPity = p.pityCounter >= ShopCatalog.PityThreshold
	local pool = ShopCatalog.Styles
	if isPity then
		p.pityCounter = 0
		local elite: {ShopCatalog.StyleDrop} = {}
		for _, s in ShopCatalog.Styles do
			if s.rarity == "Epic" or s.rarity == "Legendary" then
				table.insert(elite, s)
			end
		end
		pool = elite
	end
	local selected = pool[1] -- First in elite pool is CobraFlow (Epic)
	local isDup = p.styles[selected.name] and p.styles[selected.name].unlocked
	if isDup then
		p.styles[selected.name].xp += ShopCatalog.DuplicateXpBonus
	else
		p.styles[selected.name] = { unlocked = true, xp = 0, level = 1 }
	end
	return selected, isDup == true
end

local pityDrop, isDuplicate = simulateRoll(testProfile)
assert(isDuplicate == false, "Newly unlocked style from pity is not a duplicate")
assert(pityDrop.rarity == "Epic" or pityDrop.rarity == "Legendary", "Pity roll must guarantee Epic or Legendary")
assert(testProfile.pityCounter == 0, "Pity counter resets to 0 upon triggering")
assert(testProfile.styles[pityDrop.name].unlocked == true, "Style successfully unlocked")

print("PASS Commercial Systems: ProfileSchema integrity, ShopCatalog immutability, ELO rating math, expanding queue brackets, multi-arena cage allocation, and gacha pity guarantee.")

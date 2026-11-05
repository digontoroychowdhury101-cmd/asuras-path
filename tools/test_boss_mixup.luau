--!strict
-- Local regression only: the pure rules behind Shen's unpredictable move sets and curved cuts.
local Rules = require("../src/shared/BossEncounterRules")
local passed = 0
local function check(ok: boolean, label: string)
	assert(ok, label)
	passed += 1
end
-- a curved cut is deflected, and it reaches an arc, not a line
local parry, how = Rules.classify("PerilousCut")
check(parry == true and how == "Deflect", "a curved cut is deflected")
check(Rules.AttackKinds.PerilousCut == true, "PerilousCut is a known kind")
check(Rules.cutHit(0, -1, 0, -8, 14, 150), "dead ahead is hit")
check(Rules.cutHit(0, -1, 6, -6, 14, 150), "off the centre line inside the arc is hit")
check(not Rules.cutHit(0, -1, 0, 8, 14, 150), "behind him is safe")
check(not Rules.cutHit(0, -1, 0, -15, 14, 150), "past the radius is safe")
check(Rules.cutHit(0, -1, 0, 1, 14, 150), "on top of him is always hit")
-- broken rhythm
local move = { Pulses = { 0, 0.42, 1.05 } }
check(Rules.pulseCount(move) == 3 and Rules.pulseOffset(move, 2) == 1.05, "a move's own broken rhythm")
check(Rules.pulseCount({ Repeats = 2, Interval = 0.5 }) == 2 and Rules.pulseOffset({ Repeats = 2, Interval = 0.5 }, 1) == 0.5, "even beats still work")
check(Rules.pulseCount({}) == 1, "one strike by default")
-- never the same move twice running, and every move is reachable
local moves = { { Id = "A" }, { Id = "B" }, { Id = "C" } }
local seen: { [string]: boolean } = {}
for i = 0, 99 do
	local index = Rules.pickMove(moves, "A", i / 100)
	check(moves[index].Id ~= "A", "not the same move twice running")
	seen[moves[index].Id] = true
end
check(seen.B == true and seen.C == true, "every other move comes up")
check(Rules.pickMove({ { Id = "A" } }, "A", 0.5) == 1, "a lone move may repeat")
-- timing and mix
check(math.abs(Rules.mixInterval(4, 0.35, 0) - 2.6) < 1e-6 and math.abs(Rules.mixInterval(4, 0.35, 1) - 5.4) < 1e-6, "the beat varies by its jitter")
local mix = { Feint = 0.2, Flourish = 0.14 }
check(Rules.mixChoice(mix, true, 0) == "Attack", "a feint always ends in a real, warned attack")
check(Rules.mixChoice(mix, false, 0.1) == "Feint" and Rules.mixChoice(mix, false, 0.3) == "Flourish" and Rules.mixChoice(mix, false, 0.9) == "Attack", "the mix")
print("Boss mix-up: " .. passed .. " checks passed")

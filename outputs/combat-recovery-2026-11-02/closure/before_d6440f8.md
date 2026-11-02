# Closure before-probe on d6440f8 (offline, real CombatRules of that commit; probe source below)

D-03 before: armor at t_c, move ended -> CounterHit
D-06 before: invulnerable from after t_c -> Whiff
D-07 before: KO'd attacker after late deflect -> Deflected, attacker Blockstun
D-08 before: newer swing's registry holds defender -> true
G-02 before: dash in flight at t_c, granted in the grace -> Hit

```luau
--!nonstrict
-- Closure "before" probe: D-03, D-06, D-07, D-08 and G-02 on d6440f8's CombatRules (old API only).
local _fs = require("@lune/fs") -- marks this file as a Lune suite for lune_compat
local Combat = require("../src/simulation/CombatRules")
local TICK = 1 / 60
local out = {}
local function contact(aw, dw)
	local a, d = Combat.new(1, aw or "Jian", 10), Combat.new(2, dw or "Jian", 10)
	assert(Combat.tryAttack(a, "Light", 10))
	local tc = 10 + a.Move.Timing.StartupSeconds
	a.State, a.StateStart = "Active", tc
	return a, d, tc
end
-- D-03
local a, d, tc = contact("Jian", "Odachi")
assert(Combat.tryAttack(d, "Light", tc - 0.02))
local hit = { Facing = true, Region = "Torso", Move = a.Move, DefenderState = d.State, At = tc }
local later = tc
while d.State ~= "Idle" do later += TICK; Combat.step(d, later, TICK, {}) end
table.insert(out, "D-03 before: armor at t_c, move ended -> " .. Combat.resolveHit(a, d, later + TICK, hit, {}))
-- D-06
a, d, tc = contact()
hit = { Facing = true, Region = "Torso", Move = a.Move, DefenderState = d.State, At = tc }
Combat.cinematic(d, tc + 0.02, 1.0)
table.insert(out, "D-06 before: invulnerable from after t_c -> " .. Combat.resolveHit(a, d, tc + 0.05, hit, {}))
-- D-07
a, d, tc = contact()
assert(Combat.tryDeflect(d, tc - 0.03, tc - 0.03))
hit = { Facing = true, Region = "Torso", Move = a.Move, DefenderState = d.State, At = tc }
Combat.knockOut(a, tc + 0.02)
local o = Combat.resolveHit(a, d, tc + 0.05, hit, {})
table.insert(out, "D-07 before: KO'd attacker after late deflect -> " .. o .. ", attacker " .. a.State)
-- D-08
a, d, tc = contact()
hit = { Facing = true, Region = "Torso", Move = a.Move, DefenderState = d.State, At = tc }
a.HitRegistry[d.Id] = true
local t = tc
while a.State ~= "Idle" do t += TICK; Combat.step(a, t, TICK, {}) end
assert(Combat.tryAttack(a, "Light", t))
Combat.resolveHit(a, d, t + TICK, hit, {})
table.insert(out, "D-08 before: newer swing's registry holds defender -> " .. tostring(a.HitRegistry[d.Id] == true))
-- G-02 (rules level): dash pressed 30 ms before t_c, granted 3 ticks after; contact resolved at grace end
a, d, tc = contact()
hit = { Facing = true, Region = "Torso", Move = a.Move, DefenderState = d.State, At = tc }
assert(Combat.tryDash(d, "Dash", tc + 3 * TICK, 0, 1, {}))
table.insert(out, "G-02 before: dash in flight at t_c, granted in the grace -> " .. Combat.resolveHit(a, d, tc + 4 * TICK, hit, {}))
print(table.concat(out, " | "))
```

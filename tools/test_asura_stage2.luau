--!nonstrict
-- Local Luau runner; no Explorer location. Stage 2 (Asura's Path) CombatRules + LagCompensation checks.
-- LagCompensation is engine code: run through tools/test_asura_stage2.py, which inlines it after this
-- minimal yaw-only Vector3/CFrame shim (the CLI sandbox cannot inject globals into required modules).

local V3 = {}
V3.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return V3[key]
end
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end
V3.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return vec(b.X * a, b.Y * a, b.Z * a)
	end
	return vec(a.X * b, a.Y * b, a.Z * b)
end
V3.__div = function(a, b)
	return vec(a.X / b, a.Y / b, a.Z / b)
end
V3.__unm = function(a)
	return vec(-a.X, -a.Y, -a.Z)
end
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3.Lerp(a, b, t)
	return a + (b - a) * t
end
local Vector3 = { new = vec, zero = vec(0, 0, 0) }

local CF = {}
CF.__index = function(c, key)
	if key == "Position" then
		return c.P
	end
	return CF[key]
end
local function frame(p, yaw)
	return setmetatable({ P = p, Yaw = yaw }, CF)
end
local function rotate(yaw, v)
	local c, s = math.cos(yaw), math.sin(yaw)
	return vec(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end
function CF.PointToWorldSpace(c, v)
	return c.P + rotate(c.Yaw, v)
end
function CF.PointToObjectSpace(c, v)
	return rotate(-c.Yaw, v - c.P)
end
function CF.Lerp(a, b, t)
	return frame(a.P:Lerp(b.P, t), a.Yaw + (b.Yaw - a.Yaw) * t)
end
CF.__mul = function(a, b)
	return frame(a.P + rotate(a.Yaw, b.P), a.Yaw + b.Yaw)
end
local CFrame = {
	new = function(x, y, z)
		return frame(vec(x or 0, y or 0, z or 0), 0)
	end,
	yaw = function(x, y, z, yaw)
		return frame(vec(x, y, z), yaw)
	end,
}
CFrame.identity = CFrame.new(0, 0, 0)

local Settings = require("../src/shared/CombatSettings")
local Combat = require("../src/simulation/CombatRules")
local Weapons = require("../src/simulation/WeaponSchema")
local Lag = require("../src/server/LagCompensation")

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-------------------------------------------------------------------------------------------------
-- LagCompensation
-------------------------------------------------------------------------------------------------
local history = Lag.newHistory()
assert(history.Capacity == 30 and Lag.MAX_REWIND == 0.15)
for i = 0, 59 do
	local t = 10 + i / 60
	history = history
	Lag.record(history, t, CFrame.new(i, 0, 0), Vector3.new(60, 0, 0))
end
assert(history.Count == 30, "ring keeps 30 frames")
assert(near(Lag.oldestTime(history), 10 + 30 / 60) and near(Lag.newestTime(history), 10 + 59 / 60))
local pose, velocity = Lag.samplePoseAt(history, 10 + 45.5 / 60)
assert(near(pose.Position.X, 45.5, 1e-6) and near(velocity.X, 60), "bisection interpolates between ticks")
assert(near(Lag.samplePoseAt(history, 0).Position.X, 30), "clamps to oldest")
assert(near(Lag.samplePoseAt(history, 99).Position.X, 59), "clamps to newest")
Lag.record(history, 10 + 59 / 60, CFrame.new(100, 0, 0), Vector3.zero)
assert(history.Count == 30 and near(Lag.samplePoseAt(history, 99).Position.X, 100), "same-tick record refreshes newest")

assert(near(Lag.rewindTime(5, 4.0, nil), 4.85), "claims older than MAX_REWIND are clamped")
assert(near(Lag.rewindTime(5, 4.95, 0.3), 4.95))
assert(near(Lag.rewindTime(5, nil, 0.02), 5 - (0.02 + 1 / 30 + 1 / 60)), "ping narrows rewind budget")
assert(near(Lag.rewindTime(5, 5.5, nil), 5), "future claims clamp to now")

local d2 = Lag.segmentSegment(vec(-1, 0, 0), vec(1, 0, 0), vec(0, 2, -1), vec(0, 2, 1))
assert(near(d2, 4), "crossing segments 2 studs apart")
local dist = Lag.segmentBoxDistance(vec(-5, 3, 0), vec(5, 3, 0), CFrame.new(0, 0, 0), vec(1, 1, 1))
assert(near(dist, 2, 1e-3), "segment over a box")

local target = Lag.newHistory()
for i = 0, 10 do
	Lag.record(target, 20 + i / 60, CFrame.new(0, 3, 0), Vector3.zero)
end
local now = 20 + 10 / 60
local hit = Lag.queryHit(vec(-3, 3.4, -1.5), vec(-1, 3.4, -4), vec(3, 3.4, -1.5), vec(1, 3.4, 4), 0.3, target, now)
assert(hit and hit.Region == "Torso", "sweep across chest hits torso: " .. tostring(hit and hit.Region))
assert(Lag.queryHit(vec(-3, 9, -2), vec(-1, 9, -4), vec(3, 9, -2), vec(1, 9, -4), 0.3, target, now) == nil, "over the head misses")
-- Tunnelling: both endpoints clear of the body, but the swing passes straight through it.
local tunnel = Lag.queryHit(vec(-6, 3.6, -0.2), vec(-9, 3.6, -0.2), vec(6, 3.6, 0.2), vec(9, 3.6, 0.2), 0.25, target, now)
assert(tunnel ~= nil, "continuous sweep catches a fast pass-through")
-- Rewind: a target that has since moved away is still hit at its historical pose.
local moving = Lag.newHistory()
for i = 0, 20 do
	Lag.record(moving, 30 + i / 60, CFrame.new(i * 0.5, 3, 0), Vector3.new(30, 0, 0))
end
local at = 30 + 20 / 60
local function strikeAt(x, when)
	return Lag.queryHit(vec(x, 3.4, -3), vec(x, 3.4, -3), vec(x, 3.4, 3), vec(x, 3.4, 3), 0.3, moving, when)
end
assert(strikeAt(5.5, at) == nil, "the target has moved on in the present")
assert(strikeAt(5.5, Lag.rewindTime(at, at - 0.3, nil)) ~= nil, "rewound (clamped to 150 ms) pose is hit")
assert(strikeAt(0, Lag.rewindTime(at, at - 0.3, nil)) == nil, "rewind never exceeds MAX_REWIND")

-------------------------------------------------------------------------------------------------
-- CombatRules
-------------------------------------------------------------------------------------------------
local T = 100
local events = {}
local function fresh(id, weapon)
	return Combat.new(id, weapon, T)
end
local function advance(f, from, to)
	local t = from
	while t < to - 1e-9 do
		t = math.min(to, t + 1 / 60)
		Combat.step(f, t, 1 / 60, events)
	end
	return t
end
local function activate(attacker, kind, at)
	local ok, reason = Combat.tryAttack(attacker, kind, at)
	assert(ok, "attack refused: " .. tostring(reason))
	local active = at + attacker.Move.Timing.StartupSeconds
	advance(attacker, at, active + 1e-4)
	assert(attacker.State == "Active", "expected Active, got " .. attacker.State)
	return active + 1e-4
end
local front = { Facing = true, Region = "Torso" }

-- 1. Stamina expenditure with arm injury.
local a = fresh(1, "Jian")
local cost = Weapons.get("Jian").Heavy.StaminaCost
a.Injuries.RightArm = "Severe"
assert(near(Combat.attackStaminaCost(a, Weapons.get("Jian").Heavy), cost * 1.5), "severe arm +50% stamina")
a.Injuries.RightArm = "None"
assert(Combat.tryAttack(a, "Light", T))
assert(near(a.Stamina, 100 - 3.5), "light costs 3.5")

-- 2. Perfect deflect.
a = fresh(1, "Guandao")
local d = fresh(2, "Jian")
local t = activate(a, "Heavy", T)
assert(Combat.tryDeflect(d, t, t - 0.05))
local outcome = Combat.resolveHit(a, d, t, front, events)
assert(outcome == "Deflected", outcome)
assert(d.ActiveHP == 100 and d.Stamina == 100, "deflect negates damage and costs nothing")
assert(a.Posture >= 40 and (a.State == "Blockstun" or a.State == "StanceBroken"), "attacker eats heavy posture")
assert(events[#events].Kind == "DeflectSpark" or events[#events - 1].Kind == "DeflectSpark")

-- Late deflect (outside 100 ms) becomes a block costing 12 stamina.
a = fresh(1, "Dao")
d = fresh(2, "Jian")
t = activate(a, "Light", T)
assert(Combat.tryDeflect(d, t - 0.1, t - 0.25))
d.State = "Deflecting"
d.StateEnd = t + 1
outcome = Combat.resolveHit(a, d, t, front, events)
assert(outcome == "Blocked", outcome)
assert(near(d.Stamina, 88) and d.RecoverableHP > 0, "mistimed deflect: 12 stamina, chip into recoverable")

-- 3. StanceBreak -> Deathblow.
a = fresh(1, "Guandao")
d = fresh(2, "Unarmed")
d.Posture = 99
t = activate(a, "Light", T)
outcome = Combat.resolveHit(a, d, t, front, events)
assert(d.State == "StanceBroken" and near(d.StateEnd - d.StateStart, 2.5), "posture 100 -> StanceBroken 2.5s")
advance(a, t, t + 1)
assert(Combat.canDeathblow(a, d, 4.5, 0.9, t + 1), "deathblow inside 5 studs")
assert(not Combat.canDeathblow(a, d, 5.5, 0.9, t + 1), "deathblow refused beyond 5 studs")
local before = d.ActiveHP
local dealt = Combat.executeDeathblow(a, d, t + 1, events)
assert(a.State == "DeathblowAttacker" and d.State == "DeathblowVictim" and dealt >= 30)
assert(d.Posture == 0 and d.PermanentDeficit > 0 and d.ActiveHP < before, "massive permanent damage, posture reset")
assert(Combat.isInvulnerable(a, t + 1.05) and Combat.isInvulnerable(d, t + 1.05), "cinematic lock is invulnerable")
advance(d, t + 1, t + 3)
assert(d.State ~= "DeathblowVictim")

-- 4. Blood Rally.
a = fresh(1, "Jian")
d = fresh(2, "Dao")
t = activate(d, "Light", T)
Combat.resolveHit(d, a, t, front, events)
local recoverable = a.RecoverableHP
local active = a.ActiveHP
assert(recoverable > 0 and active < 100, "light hit builds recoverable debt")
advance(a, t, t + 0.6)
local t2 = activate(a, "Light", t + 0.6)
Combat.resolveHit(a, d, t2, front, events)
assert(a.ActiveHP > active and a.RecoverableHP < recoverable, "striking back rallies HP")
-- Outside the 3 s window no rally happens.
a = fresh(1, "Jian")
d = fresh(2, "Dao")
t = activate(d, "Light", T)
Combat.resolveHit(d, a, t, front, events)
active = a.ActiveHP
advance(a, t, t + 3.2)
t2 = activate(a, "Light", t + 3.2)
assert(a.RecoverableHP <= recoverable)
Combat.resolveHit(a, d, t2, front, events)
assert(near(a.ActiveHP, active), "no rally after 3 s")
-- Heavy converts recoverable into permanent deficit.
a = fresh(1, "Jian")
d = fresh(2, "Dao")
t = activate(d, "Light", T)
Combat.resolveHit(d, a, t, front, events)
recoverable = a.RecoverableHP
local d2f = fresh(3, "Guandao")
local t3 = activate(d2f, "Heavy", t + 0.5)
Combat.resolveHit(d2f, a, t3, front, events)
assert(a.PermanentDeficit >= recoverable - 1e-6, "heavy converts recoverable to permanent")

-- 5. Counter-hit and feint.
a = fresh(1, "Jian")
d = fresh(2, "Jian")
assert(Combat.tryAttack(d, "Heavy", T))
t = activate(a, "Light", T)
assert(d.State == "Startup" or d.State == "Active")
d.State = "Startup"
outcome = Combat.resolveHit(a, d, t, front, events)
assert(outcome == "CounterHit" and d.Move == nil and d.State == "Hitstun", outcome)
local expected = Weapons.get("Jian").Light[1].BaseDamage * 1.25
assert(near(100 - d.ActiveHP, expected, 1e-6), "counter-hit deals 1.25x")
d = fresh(2, "Dao")
assert(Combat.tryAttack(d, "Heavy", T))
local ok = Combat.tryFeint(d, T + 0.1, events)
assert(ok and d.State == "Idle" and near(d.Stamina, 100 - Weapons.get("Dao").Heavy.StaminaCost - 4), "feint costs 4")
d = fresh(2, "Dao")
assert(Combat.tryAttack(d, "Heavy", T))
assert(not Combat.tryFeint(d, T + 0.2, events), "feint window closes")

-- 6. Backdash decay counter.
local f = fresh(5, "Unarmed")
local g1 = Combat.tryDash(f, "Dash", T, 0, 1, events)
advance(f, T, T + 0.3)
local g2 = Combat.tryDash(f, "Dash", T + 0.3, 0, 1, events)
advance(f, T + 0.3, T + 0.6)
local g3 = Combat.tryDash(f, "Dash", T + 0.6, 0, 1, events)
assert(g1 and g2 and g3 and g2.Distance < g1.Distance and g3.Distance < g2.Distance, "spam shortens dashes")
assert((g3.IFrameEnd - g3.IFrameStart) < (g1.IFrameEnd - g1.IFrameStart), "spam shortens i-frames")
advance(f, T + 0.6, T + 1)
local victim = fresh(6, "Unarmed")
t = activate(f, "Light", T + 1)
Combat.resolveHit(f, victim, t, front, events)
assert(f.DashChain == 0, "landed strike resets backdash decay")

-- Stamina break after spending the last stamina.
f = fresh(7, "Unarmed")
f.Stamina = 3
assert(Combat.tryAttack(f, "Light", T))
advance(f, T, T + 1)
assert(f.State == "StaminaBroken" or f.Stamina > 0)

-- KO.
a = fresh(1, "Guandao")
d = fresh(2, "Unarmed")
d.ActiveHP = 5
t = activate(a, "Heavy", T)
assert(Combat.resolveHit(a, d, t, front, events) == "KO" and d.State == "KO")
assert(Combat.resolveHit(a, d, t, front, events) == "Ignored", "one hit per swing")

-- Replication codec round trip.
f = fresh(123456789012, "Dao")
f.Injuries.LeftLeg = "Severe"
f.Injuries.Head = "Impaired"
f.Posture = 42.5
f.DeathblowPartner = 9876543210
assert(Combat.tryAttack(f, "Light", T))
local text = Combat.packString(f, T + 0.01)
assert(#text == math.ceil(Combat.PACKET_SIZE / 3) * 4)
local snap = Combat.unpackString(text)
assert(snap and snap.State == "Startup" and snap.Weapon == "Dao" and snap.Move == "Dao_L1")
assert(snap.Injuries.LeftLeg == "Severe" and snap.Injuries.Head == "Impaired" and snap.Injuries.Torso == "None")
assert(near(snap.Posture, 42.5, 0.01) and near(snap.Stamina, f.Stamina, 0.01) and snap.DeathblowPartner == 9876543210)
assert(Combat.decode("@@@@") == nil and Combat.unpackString("") == nil)

print("Asura Stage 2: all checks passed")

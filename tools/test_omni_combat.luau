--!nonstrict
-- Post-F26 step 2 regression: one omnidirectional strike rule for players, enemies, bosses and
-- grounded duels (StrikeGeometry). Rules, a 60 Hz circling simulation and source wiring checks.
-- Local regression only: Studio look, real input, device hardware and human fairness are separate.
-- Run from the project root: python3 tools/lune_compat.py tools/test_omni_combat.luau
local fs = require("@lune/fs")
local Strike = require("../src/simulation/StrikeGeometry")
local Combat = require("../src/simulation/CombatRules")
local Schema = require("../src/simulation/MoveSchema")
local Weapons = require("../src/simulation/WeaponSchema")
local Settings = require("../src/shared/CombatSettings")
local Map = require("../src/shared/InputMap") :: any

local passed, failed = 0, 0
local function check(name: string, condition: any)
	if condition then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function src(path: string): string return fs.readFile(path) end
local function has(path: string, needle: string): boolean return string.find(src(path), needle, 1, true) ~= nil end
local function near(a: number, b: number, eps: number?): boolean return math.abs(a - b) <= (eps or 1e-6) end
local DT, T = 1 / 60, 100
local Tracking = Settings.Tracking
local RATE = math.rad(Tracking.StartupTurnRate)

-- 0. Invariants this batch must not move.
check("tempo stays 1.4x at 60 Hz", Settings.Tempo.Scalar == 1.4 and Settings.Tempo.TickRate == 60)
check("deflect baseline stays 100 ms", string.find(src("src/shared/CombatSettings.luau"), "Deflect = 100,", 1, true) ~= nil)
check("tri-layer health unchanged", table.concat(Settings.Health.Layers, ",") == "ActiveHP,RecoverableHP,PermanentDeficit")
check("lag compensation stays 60 Hz / 150 ms", has("src/server/LagCompensation.luau", "LagCompensation.TICK_RATE = 60") and has("src/server/LagCompensation.luau", "LagCompensation.MAX_REWIND = 0.15"))
check("profiles stay schema v4", has("src/shared/ProfileSchema.luau", "local CURRENT_SCHEMA_VERSION = 4"))
check("weapon registry still 12", #Weapons.WeaponKeys == 12)

-- 1. The shared segment is the pre-batch weaponSegment, number for number, for every move.
local function legacy(move, progress: number, bonus: number)
	local reach = move.Reach + bonus + move.Lunge * 0.35 * progress
	if move.Arc > 40 then
		local angle = math.rad(move.Arc) * (progress - 0.5)
		local x, z = math.sin(angle), -math.cos(angle)
		return x * 0.8, 0.6, z * 0.8, x * reach, 0.6, z * reach
	end
	local extension = reach * (0.55 + 0.45 * progress)
	return 0, 0.6, -0.8, 0, 0.6, -extension
end
local identical, moves = true, 0
for _, key in Weapons.WeaponKeys do
	for _, kind in { "Light", "Heavy", "WeaponArt", "RunningAttack" } do
		local f = Combat.new(1, key, T)
		local move = Combat.selectMove(f, kind, T)
		moves += 1
		for _, p in { 0, 0.25, 0.5, 1 } do
			local a = { legacy(move, p, 0.4) }
			local b = { Strike.segment(move, p, 0.4) }
			for i = 1, 6 do identical = identical and near(a[i], b[i]) end
		end
	end
end
check("segment matches the legacy sweep for all " .. moves .. " moves of the 12 weapons", identical and moves == 48)
local tips = Strike.sweep({ Arc = 90, Reach = 6, Lunge = 0 }, 0, 8)
check("drawn sweep is the server tip path", #tips == 9 and near(tips[1][1], -6 * math.sin(math.rad(45))) and near(tips[9][1], 6 * math.sin(math.rad(45))) and near(tips[5][2], -6))

-- 2. Yaw convention and turning.
for _, v in { { 0, -1 }, { 1, 0 }, { -0.6, 0.8 }, { 0.3, -0.4 } } do
	local lx, lz = Strike.look(Strike.yaw(v[1], v[2]) :: number)
	local m = math.sqrt(v[1] ^ 2 + v[2] ^ 2)
	check("yaw/look round-trip " .. v[1] .. "," .. v[2], near(lx, v[1] / m) and near(lz, v[2] / m))
end
check("zero vector has no yaw", Strike.yaw(0, 0) == nil)
check("delta takes the short way across pi", near(Strike.delta(math.rad(170), math.rad(-170)), math.rad(20)))
check("turn caps the step", near(Strike.turn(0, math.rad(90), math.rad(30)), math.rad(30)) and near(Strike.turn(0, math.rad(-20), math.rad(30)), math.rad(-20)))

-- 3. Facing budgets by state (one rule for every actor).
local su = 0.317
check("neutral turns freely", Strike.turnStep("Idle", 0, 0, DT) == math.huge)
check("guarding turns at the shared rate, never a free spin", near(Strike.turnStep("Blocking", 0, 0, DT), RATE * DT) and near(Strike.turnStep("Deflecting", 0, 0, DT), RATE * DT))
check("windup tracks at the shared rate", near(Strike.turnStep("Startup", 0.05, su, DT), RATE * DT))
check("commit lead stops tracking", Strike.turnStep("Startup", su - Tracking.CommitLeadSeconds + 0.001, su, DT) == 0)
check("active frames never turn", Strike.turnStep("Active", 0, su, DT) == 0)
check("recovery turns at the shared rate", near(Strike.turnStep("Recovery", 0.2, 0, DT), RATE * DT))
check("dodges and stuns hold facing", Strike.turnStep("Dashing", 0, 0, DT) == 0 and Strike.turnStep("Hitstun", 0, 0, DT) == 0 and Strike.turnStep("KO", 0, 0, DT) == 0)

-- 4. Commit: every light goes exactly where it was aimed; heavies may track a little, then lock.
local fastExact, budgetRule, heavyMax = true, true, 0
for _, key in Weapons.WeaponKeys do
	local f = Combat.new(1, key, T)
	for _, kind in { "Light", "Heavy" } do
		local startup = Combat.selectMove(f, kind, T).Timing.StartupSeconds
		local b = Strike.windupBudget(startup)
		budgetRule = budgetRule and near(b, RATE * math.max(0, startup - Tracking.CommitLeadSeconds))
		if kind == "Light" and startup <= Tracking.CommitLeadSeconds then fastExact = fastExact and b == 0 end
		if kind == "Heavy" then heavyMax = math.max(heavyMax, b) end
	end
end
check("lights with windups inside the commit lead go exactly where aimed", fastExact)
check("tracking budget is the shared rate over the early windup, every weapon", budgetRule)
check("even the slowest heavy (0.5 s windup) tracks under 90 degrees", heavyMax > 0 and heavyMax < math.rad(90))
local jianHeavy = Combat.selectMove(Combat.new(1, "Jian", T), "Heavy", T)
local budget = Strike.windupBudget(jianHeavy.Timing.StartupSeconds)
check("a client spinning 180 degrees in a swing commits within budget", near(Strike.commit(0, math.rad(180), jianHeavy.Timing.StartupSeconds), budget) or near(Strike.commit(0, math.rad(180), jianHeavy.Timing.StartupSeconds), -budget))
check("a spun light keeps its press aim", Strike.commit(math.rad(30), math.rad(-150), 0.1) == math.rad(30))

-- 5. Circling at 60 Hz. An AI aims at its target's lead point (Tracking.AimLeadSeconds ahead), tracks
-- through the windup at the shared rate, then commits; the target orbits at walk speed and may reverse.
-- The blade is swept continuously (40 substeps, like the server's swept capsule) against a thrust-width
-- capsule (weapon 0.3 + torso 0.95).
local function duel(weapon: string, kind: string, radius: number, speed: number, reverseAt: number?): boolean
	local move = Combat.selectMove(Combat.new(1, weapon, T), kind, T)
	local lead = Tracking.AimLeadSeconds
	local theta, t, dir = 0, 0, 1
	local function target(): (number, number) return math.sin(theta) * radius, -math.cos(theta) * radius end
	local function advance(dt: number)
		if reverseAt and t >= reverseAt then dir = -1 end
		theta += dir * (speed / radius) * dt
		t += dt
	end
	local function aimPoint(): (number, number)
		local x, z = target()
		return x + math.cos(theta) * speed * dir * lead, z + math.sin(theta) * speed * dir * lead
	end
	local startup = move.Timing.StartupSeconds
	local yaw = Strike.yaw(aimPoint()) :: number
	local aim = yaw
	while t < startup - 1e-9 do
		local elapsed = t
		advance(DT)
		yaw = Strike.turn(yaw, Strike.yaw(aimPoint()) :: number, Strike.turnStep("Startup", elapsed, startup, DT))
	end
	local committed = Strike.commit(aim, yaw, startup)
	local c, s = math.cos(committed), math.sin(committed)
	local function world(x: number, z: number): (number, number) return x * c + z * s, -x * s + z * c end
	local N = 40
	for i = 0, N do
		if i > 0 then advance(move.Timing.ActiveSeconds / N) end
		local tx, tz = target()
		local hx, _, hz, bx, _, bz = Strike.segment(move, i / N, 0)
		hx, hz = world(hx, hz)
		bx, bz = world(bx, bz)
		local dx, dz = bx - hx, bz - hz
		local u = math.clamp(((tx - hx) * dx + (tz - hz) * dz) / (dx * dx + dz * dz), 0, 1)
		local qx, qz = hx + dx * u - tx, hz + dz * u - tz
		if math.sqrt(qx * qx + qz * qz) <= 0.3 + 0.95 then return true end
	end
	return false
end
local walk = Settings.Movement.WalkSpeed
for _, case in { { "Unarmed", 3.2 }, { "Jian", 6 } } do
	check(case[1] .. " light strikes a still target", duel(case[1], "Light", case[2], 0))
	check(case[1] .. " light reads a steady circle (aim lead)", duel(case[1], "Light", case[2], walk))
	check(case[1] .. " light whiffs when the target reverses at the press", not duel(case[1], "Light", case[2], walk, 0))
end
check("Jian heavy thrust strikes a still target", duel("Jian", "Heavy", 7, 0))
check("Jian heavy thrust whiffs on a steady circle (commits early)", not duel("Jian", "Heavy", 7, walk))
check("Unarmed heavy whiffs on a steady circle", not duel("Unarmed", "Heavy", 3.5, walk))
check("Dao heavy sweep punishes the same circle", duel("Dao", "Heavy", 6, walk))
check("Dao light sweep catches a reversal", duel("Dao", "Light", 5.5, walk, 0))

-- 5b. Whiff punish geometry. The defender's guard needs the attacker within acos(FACING_DOT) of its
-- facing; a recovering or guarding body turns at the shared rate for the ~0.2 s a light punish takes.
local cone = math.deg(math.acos(0.15))
local turned = math.deg(Strike.turnStep("Recovery", 0, 0, 0.1) + Strike.turnStep("Blocking", 0, 0, 0.1))
check(string.format("a 90-degree flank is guarded (%.0f deg turned into the %.0f deg cone)", turned, cone), 90 - turned <= cone)
check("a punish from behind (150 degrees) lands", 150 - turned > cone)

-- 6. Air: one light and one dodge per airtime, heavier moves wait, landing costs recovery.
local air = Strike.newAir()
check("grounded allows everything", (Strike.airAllows(air, "Heavy")) and (Strike.airAllows(air, "WeaponArt")))
Strike.airUpdate(air, true)
local okHeavy, whyHeavy = Strike.airAllows(air, "Heavy")
check("airborne heavy waits for the ground", not okHeavy and whyHeavy == "Airborne" and not (Strike.airAllows(air, "WeaponArt")))
check("first air light allowed", (Strike.airAllows(air, "Light")))
Strike.airSpend(air, "Light")
local okSecond, whySecond = Strike.airAllows(air, "Light")
check("second air light refused and a landing is owed", not okSecond and whySecond == "AirAttackSpent" and air.Landing)
check("first air dodge allowed", (Strike.airAllows(air, "Dash")))
Strike.airSpend(air, "Dash")
check("second air dodge refused", not (Strike.airAllows(air, "Roll")))
check("deflect and guard stay open in the air", (Strike.airAllows(air, "Deflect")) and (Strike.airAllows(air, "Block")))
check("a free-flight AerialDuel ruleset lifts the limits", (Strike.airAllows(air, "Heavy", "AerialDuel")))
Strike.airUpdate(air, false)
check("touchdown refreshes allowances, keeps the owed landing", air.Attacks == 0 and air.Dodges == 0 and air.Landing)

local f = Combat.new(2, "Jian", T)
assert(Combat.tryAttack(f, "Light", T))
check("landing mid-swing waits", Combat.landingRecovery(f, T + 0.01, Tracking.LandingRecoverySeconds) == "Wait")
local t = T
while f.State ~= "Recovery" do t += DT; Combat.step(f, t, DT, {}) end
check("landing in recovery is applied", Combat.landingRecovery(f, t, Tracking.LandingRecoverySeconds) == "Applied")
check("landing recovery lasts at least the landing cost", f.State == "Recovery" and f.Move == nil and f.StateEnd - t >= Tracking.LandingRecoverySeconds - 1e-9)
local ctx = Combat.context(f, t)
check("deflect stays open while landing", (Schema.canAct(f.State, "Deflect", f.Stamina, f.Posture, ctx)))
check("no combo or dodge out of a landing", not (Schema.canAct(f.State, "Light", f.Stamina, f.Posture, ctx)) and not (Schema.canAct(f.State, "Dash", f.Stamina, f.Posture, ctx)))
while f.State ~= "Idle" do t += DT; Combat.step(f, t, DT, {}) end
check("landing recovery returns to neutral", f.State == "Idle")
local g = Combat.new(3, "Jian", T)
check("idle landing applies", Combat.landingRecovery(g, T, Tracking.LandingRecoverySeconds) == "Applied" and g.State == "Recovery")
local d = Combat.new(5, "Jian", T); d.State = "Dashing"
check("an air dodge into the ground still owes the landing", Combat.landingRecovery(d, T, Tracking.LandingRecoverySeconds) == "Wait")
local h = Combat.new(4, "Jian", T); h.State = "Hitstun"
check("a stun drops the landing", Combat.landingRecovery(h, T, Tracking.LandingRecoverySeconds) == "Dropped")

-- 7. Replicated strike record.
local record = Strike.encode({ Arc = 110, Reach = 7.9, Lunge = 2.5, Yaw = -2.3561, Start = 1234.567, Active = 0.067, Weapon = "Dao" })
local back = Strike.decode(record)
check("strike record round-trips", back and back.Arc == 110 and near(back.Reach, 7.9) and near(back.Yaw, -2.3561, 1e-4) and back.Weapon == "Dao" and near(back.Active, 0.067))
check("malformed record ignored", Strike.decode("nope") == nil and Strike.decode(nil) == nil)

-- 8. Wiring: one path for players, enemies, bosses and duels.
local cs = "src/server/CharacterService.luau"
check("server sweeps the committed frame", has(cs, "local rootCFrame = strikeFrame(attacker)") and has(cs, "weaponSegment(strikeFrame(e), move, 1"))
check("commit happens before contacts each tick", has(cs, "commitStrike(e)\n\t\t\tresolveContacts(e, now)"))
check("strike record published for the client", has(cs, 'SetAttribute("AsuraStrike", Strike.encode('))
check("enemy Face uses the shared turn budget", has(cs, "Strike.turnStep(f.State, simTime - f.StateStart, startup, dt)"))
check("enemies cannot walk-turn while committed", has(cs, "e.Humanoid.AutoRotate = free"))
check("players sent aim feeds the swing", has(cs, "Strike.yaw(dirX, dirZ) or yawOf(e.Root.CFrame)") and has(cs, "return attack(e, \"Heavy\", now, dirX, dirZ)"))
check("air rules gate the buffer and the perform", has(cs, "if not (Strike.airAllows(e.Omni.Air, action, ruleset(e))) then") and has(cs, "local airOk, airReason = Strike.airAllows("))
check("landing recovery runs in the step", has(cs, "Combat.landingRecovery(f, now, Settings.Tracking.LandingRecoverySeconds)"))
check("boss perilous attacks still lock aim at telegraph", has("src/server/Services/BossAttackService.luau", "local aim = Motion.clamp(id"))
check("duels use the same CharacterService path", has("src/server/Services/ColosseumService.luau", "Characters.StartAllocatedMatch") or has("src/server/Services/ColosseumService.luau", "StartAllocatedMatch("))
check("client sends attack aim", has("src/client/Controllers/InputController.luau", 'local hasDirection = attack or action == "Roll" or action == "Dash"'))
check("client lock-on obeys the turn budget", has("src/client/Controllers/CameraController.luau", "Strike.turnStep(snapshot.State, snapshot.StateElapsed, snapshot.StateDuration, dt)"))
check("arcs drawn from the validated record", has("src/client/Controllers/WeaponTrails.luau", "Strike.decode(record)") and has("src/client/Controllers/WeaponTrails.luau", "Strike.sweep(shape, 0, SAMPLES)"))
check("client dash is held by a horizontal LinearVelocity, not a per-frame write the humanoid brakes", has("src/client/Controllers/WorldStateController.luau", "made.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane") and has("src/client/Controllers/WorldStateController.luau", "drive.PlaneVelocity = Vector2.new(planar.X, planar.Z)") and has("src/client/Controllers/WorldStateController.luau", "local left = self.DashLength - moved"))
check("project maps StrikeGeometry", has("default.project.json", '"$path": "src/simulation/StrikeGeometry.luau"'))

-- 8b. Real server path: the actual weaponSegment/strikeFrame/resolveContacts from CharacterService
-- with the real LagCompensation. The attacker commits facing -Z, then its (client-owned) root spins
-- 180 degrees. The blade must still sweep the committed side: a body behind stays untouched, a body in
-- front is struck. Before this batch the sweep followed the live root and cut the body behind.
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local Tempo = require("../src/simulation/Tempo")
local function between(text: string, from: string, to: string): string
	local a = assert(string.find(text, from, 1, true), from)
	return string.sub(text, a, (assert(string.find(text, to, a, true), to)) - 1)
end
local geo = { Vector3 = roblox.Vector3, CFrame = roblox.CFrame, math = math, table = table, type = type, setmetatable = setmetatable,
	ipairs = ipairs, pairs = pairs, next = next, assert = assert, error = error, tostring = tostring, string = string, os = os }
local Lag = luau.load(src("src/server/LagCompensation.luau"), { debugName = "LagCompensation", environment = geo })()
local service = src(cs)
local chunk = "local Combat, Lag, TICK, FACING_DOT, entities, frameEvents, eventPoints, Strike = ...\n"
	.. "local function alive() return true end\nlocal function hostile() return true end\n"
	.. "local function facingDot() return 1 end\nlocal function awardXp() end\n"
	.. between(service, "local function weaponSegment(", "\n-------") .. "\n"
	.. between(service, "local function resolveContacts(", "\n-- Whiffs (batch 09)")
	.. "\nreturn resolveContacts"
local function spun(defenderZ: number): string
	local entities, frameEvents = {}, {}
	local resolve = luau.load(chunk, { debugName = "SpinContacts", environment = geo })(Combat, Lag, Tempo.TickSeconds, 0.15, entities, frameEvents, {}, Strike)
	local a, b = Combat.new(1, "Jian", T), Combat.new(-1, "Jian", T)
	local facing = roblox.CFrame.lookAt(roblox.Vector3.new(0, 3.2, 0), roblox.Vector3.new(0, 3.2, -10))
	local spin = roblox.CFrame.lookAt(roblox.Vector3.new(0, 3.2, 0), roblox.Vector3.new(0, 3.2, 10))
	local bRoot = roblox.CFrame.lookAt(roblox.Vector3.new(0, 3.39, defenderZ), roblox.Vector3.new(0, 3.39, 0))
	local history = Lag.newHistory()
	for i = -30, 0 do Lag.record(history, T + i * Tempo.TickSeconds, bRoot, roblox.Vector3.zero) end
	local ea = { Id = 1, Fighter = a, Root = { CFrame = spin, Position = spin.Position }, Model = { GetAttribute = function() return nil end }, Omni = { YawFor = -1 } }
	local eb = { Id = -1, Fighter = b, Root = { CFrame = bRoot, Position = bRoot.Position }, Model = ea.Model, History = history }
	entities[1], entities[-1] = ea, eb
	assert(Combat.tryAttack(a, "Light", T))
	ea.Omni = { Yaw = Strike.yaw(facing.LookVector.X, facing.LookVector.Z), YawFor = a.MoveStart }
	local t = T
	for _ = 1, 30 do
		t += Tempo.TickSeconds
		Lag.record(history, t, bRoot, roblox.Vector3.zero)
		Combat.step(a, t, Tempo.TickSeconds, frameEvents); Combat.step(b, t, Tempo.TickSeconds, frameEvents)
		if a.State == "Active" then resolve(ea, t) end
	end
	local list = {}
	for _, e in frameEvents do table.insert(list, e.Kind) end
	return table.concat(list, ",")
end
check("a root spun after the commit cannot cut the body behind", not string.find(spun(5), "Hit", 1, true))
check("the committed side is still struck through the spin", string.find(spun(-5), "Hit", 1, true) ~= nil)

-- 9. Devices: attack, dodge, jump and lock on every input, and a target-switch path on each.
for _, command in { "Light", "Heavy", "Dash", "Jump", "Guard", "Lock" } do
	local b = Map.get(command)
	check(command .. " on keyboard/mouse, gamepad and touch", b and (#b.Keys + #b.Mouse) > 0 and #b.Pad > 0 and b.Touch ~= nil)
end
local cam = "src/client/Controllers/CameraController.luau"
check("target switch: mouse flick, stick flick, touch swipe", has(cam, "SWITCH_MOUSE") and has(cam, "SWITCH_STICK") and has("src/client/Controllers/InputController.luau", "self.Camera:Look(self.TouchLook)"))

print(string.format("omni combat: %d passed, %d failed (local regression; Studio, hardware and human play separate)", passed, failed))
if failed > 0 then error("omni combat regression failed") end

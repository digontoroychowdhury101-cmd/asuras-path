--!nonstrict
-- Combat recovery Stage 2 regressions (outputs/combat-recovery-2026-11-02/TIMING_CONTRACT.md, TEST_MATRIX.md).
-- The intent path is the real one: validIntent, onIntent, drainBuffer, eligibleFor and the terminal-record
-- functions are extracted from src/server/CharacterService.luau and run against the real CombatRules,
-- MoveSchema, InputBuffer and Tempo, with only the engine, network and unrelated services stubbed. Each
-- case states its full expected outcome. Run: python3 tools/lune_compat.py tools/test_stage2_timing.luau
-- Evidence type: offline behaviour test (engine emulation). Says nothing about Studio, latency or feel.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Combat = require("../src/simulation/CombatRules")
local Schema = require("../src/simulation/MoveSchema")
local InputBuffer = require("../src/simulation/InputBuffer")
local Tempo = require("../src/simulation/Tempo")
local Settings = require("../src/shared/CombatSettings")

local passed, failed = 0, 0
local function check(name: string, ok: any, detail: any?)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. (if detail ~= nil then "  (" .. tostring(detail) .. ")" else ""))
	end
end
local function between(text: string, from: string, to: string): string
	local a = assert(string.find(text, from, 1, true), from)
	return string.sub(text, a, (assert(string.find(text, to, a, true), to)) - 1)
end

local TICK = Tempo.TickSeconds
local service = fs.readFile("src/server/CharacterService.luau")

-------------------------------------------------------------------------------------------------
-- Harness: the real server intent path on a virtual clock
-------------------------------------------------------------------------------------------------

local chunk = table.concat({
	"local Combat, Schema, InputBuffer, Tempo, Lag, Protocol, Config, entities, performStub, immediate, Strike, ruleset = ...",
	"local running, simTime, tickCount = true, 0, 0",
	"local terminal",
	between(service, "local MAX_SEQUENCE_GAP", "\nlocal DEFAULT_JUMP"),
	between(service, "local INTENT_ACTIONS", "\nlocal WEAPON_VISUALS"),
	between(service, "local function eligibleFor(", "\nlocal function disconnectAll("),
	between(service, "local function validIntent(", "\nlocal function findDeathblowTarget("),
	"local function perform(e, action, pressTime, dirX, dirZ) return performStub(e, action, pressTime, simTime) end",
	between(service, "local function onIntent(", "\n-------"),
	"return { onIntent = onIntent, drainBuffer = drainBuffer, eligibleFor = eligibleFor,",
	"  setTime = function(t, k) simTime, tickCount = t, k end, terminal = function(...) return terminal(...) end }",
}, "\n")

local function newWorld()
	local entities = {}
	local api = luau.load(chunk, { debugName = "Stage2IntentPath" })(
		Combat, Schema, InputBuffer, Tempo, { MAX_REWIND = 0.15 },
		{ Take = function() return true end },
		{ Network = { ActionsPerSecond = 60, ActionBurst = 60 } },
		entities,
		function(e, action, pressTime, now)
			local f = e.Fighter
			if action == "Light" or action == "Heavy" then
				return Combat.tryAttack(f, action, now)
			elseif action == "Deflect" then
				return Combat.tryDeflect(f, now, pressTime)
			elseif action == "Dash" or action == "Roll" then
				local grant, reason = Combat.tryDash(f, action, now, 0, 1, {})
				return grant ~= nil, reason
			end
			return false, "Unsupported"
		end,
		function() return true, "Immediate" end,
		{ airAllows = function() return true end },
		function() return nil end
	)
	local world = { api = api, entities = entities, now = 1000, tick = 0, records = {}, executed = {} }
	function world.player(id: number)
		local attributes = {}
		local player = {
			UserId = id,
			SetAttribute = function(_, name, value)
				attributes[name] = value
				if name == "AsuraIntent" then
					table.insert(world.records, value)
				end
			end,
			GetAttribute = function(_, name) return attributes[name] end,
		}
		local e = {
			Id = id, Player = player, Fighter = Combat.new(id, "Jian", world.now), Buffer = InputBuffer.new(),
			LastSeq = 0, Actions = {}, Respawning = false, Omni = { Air = {} }, IntentLog = {},
		}
		e.Eligible = api.eligibleFor(e)
		e.Buffer.OnDrop = function(seq, action, status) api.terminal(e, seq, status, action) end
		entities[id] = e
		return player, e
	end
	-- One server tick in the production order for intents: Combat.step, then drainBuffer.
	function world.step()
		world.tick += 1
		world.now += TICK
		api.setTime(world.now, world.tick)
		for _, e in entities do
			Combat.step(e.Fighter, world.now, TICK, {})
			local before = e.Fighter.MoveStart
			api.drainBuffer(e)
			if e.Fighter.MoveStart ~= before or e.Fighter.State == "Deflecting" and e.Fighter.StateStart ~= e.LastDeflect then
				e.LastDeflect = e.Fighter.StateStart
			end
		end
	end
	function world.send(player, seq: number, action: string, pressedAgo: number, extra: any?)
		api.setTime(world.now, world.tick)
		local packet = { seq = seq, action = action, time = world.now - pressedAgo }
		for k, v in extra or {} do
			packet[k] = v
		end
		api.onIntent(player, packet)
	end
	-- Terminal records grouped by seq: { [seq] = { "status:reason", ... } }
	function world.terminals()
		local bySeq, seen = {}, {}
		for _, value in world.records do
			for record in string.gmatch(value, "[^;]+") do
				if not seen[record] then
					seen[record] = true
					local seq, status, reason = string.match(record, "^(%d+):(%a+):([^:]*):")
					seq = tonumber(seq)
					bySeq[seq] = bySeq[seq] or {}
					table.insert(bySeq[seq], status .. ":" .. reason)
				end
			end
		end
		return bySeq
	end
	return world
end

-- Ticks from a fresh Heavy until a Light is first eligible: the fixture's "legal tick".
local function heavyLegalTicks(): number
	local w = newWorld()
	local _, e = w.player(1)
	assert(Combat.tryAttack(e.Fighter, "Heavy", w.now))
	for k = 1, 600 do
		w.step()
		if e.Eligible("Light", "") then
			return k
		end
	end
	error("Light never became eligible after a Heavy")
end
local LEGAL = heavyLegalTicks()

-------------------------------------------------------------------------------------------------
-- A. Input ownership and lifetime
-------------------------------------------------------------------------------------------------

-- T-IN-01: a press whose transit is 0/50/100/140 ms reaches the server 90 ms before the fighter can act.
-- It must execute on the first legal tick. (Before Stage 2 the lifetime ran from the rewound press time,
-- so transit >= ~10 ms left less than the 90 ms wait and the press expired after "Buffered".)
for _, transit in { 0, 0.05, 0.10, 0.14 } do
	local w = newWorld()
	local player, e = w.player(1)
	assert(Combat.tryAttack(e.Fighter, "Heavy", w.now))
	local waitTicks = math.floor(0.09 / TICK + 0.5)
	for _ = 1, LEGAL - waitTicks do
		w.step()
	end
	local heavyStart = e.Fighter.MoveStart
	w.send(player, 1, "Light", transit)
	local startedAt
	for k = 1, 20 do
		w.step()
		if e.Fighter.MoveStart ~= heavyStart and e.Fighter.Move and e.Fighter.Move.Kind == "Light" then
			startedAt = k
			break
		end
	end
	local t = w.terminals()[1]
	check(string.format("T-IN-01 transit %d ms: light executes on the first legal tick", transit * 1000),
		startedAt == waitTicks, string.format("started after %s ticks, legal after %d", tostring(startedAt), waitTicks))
	check(string.format("T-IN-01 transit %d ms: exactly one terminal record, Executed", transit * 1000),
		t and #t == 1 and string.sub(t[1], 1, 8) == "Executed", t and table.concat(t, ","))
end

-- T-IN-02: a press that would wait more than the 100 ms queue lifetime from receipt leaves Expired, once,
-- and never executes late.
do
	local w = newWorld()
	local player, e = w.player(1)
	assert(Combat.tryAttack(e.Fighter, "Heavy", w.now))
	local early = math.floor(0.13 / TICK + 0.5)
	for _ = 1, LEGAL - early do
		w.step()
	end
	local heavyStart = e.Fighter.MoveStart
	w.send(player, 1, "Light", 0.02)
	for _ = 1, 30 do
		w.step()
	end
	local t = w.terminals()[1]
	check("T-IN-02 a 130 ms wait expires (never executes late)", e.Fighter.MoveStart == heavyStart)
	check("T-IN-02 exactly one terminal record, Expired:Light", t and #t == 1 and t[1] == "Expired:Light", t and table.concat(t, ","))
end

-- T-IN-03: very old, forged-old and future timestamps. The accepted press time is clamped into
-- [receipt - 150 ms, receipt]; queuing never refreshes its age; a press older than ExecuteBy is Stale.
do
	check("T-IN-03 forged-old press clamps to receipt - 150 ms", math.abs(Tempo.reconcile(1000 - 5, 1000, 0.15) - (1000 - 0.15)) <= TICK)
	check("T-IN-03 future press clamps to receipt", Tempo.reconcile(1000 + 5, 1000, 0.15) <= 1000 + 1e-9)
	local w = newWorld()
	local player, e = w.player(1)
	assert(Combat.tryAttack(e.Fighter, "Heavy", w.now))
	local heavyStart = e.Fighter.MoveStart
	w.send(player, 1, "Light", 5) -- five seconds old: clamped, then can only wait to receipt + 100 ms
	for _ = 1, LEGAL + 10 do
		w.step()
	end
	local t = w.terminals()[1]
	check("T-IN-03 forged-old press does not execute after its lifetime", e.Fighter.MoveStart == heavyStart, e.Fighter.Move and e.Fighter.Move.Id)
	check("T-IN-03 forged-old press ends once, not Executed", t and #t == 1 and string.sub(t[1], 1, 8) ~= "Executed", t and table.concat(t, ","))
	local buffer, drops = InputBuffer.new(), {}
	buffer.OnDrop = function(seq, _, status) table.insert(drops, seq .. status) end
	check("T-IN-03 a push older than ExecuteBy is refused", not InputBuffer.push(buffer, "Light", 10, nil, nil, nil, 10 + Settings.Input.ExecuteBy + 0.01, 7))
	check("T-IN-03 and reported Stale", drops[1] == "7Stale" and InputBuffer.count(buffer) == 0, drops[1])
	-- Re-pushing the same old press inside the duplicate window cannot reset its age past ExecuteBy.
	InputBuffer.push(buffer, "Light", 20, nil, nil, nil, 20.14, 8)
	InputBuffer.push(buffer, "Light", 20.01, nil, nil, nil, 20.20, 9)
	check("T-IN-03 a refreshed duplicate still dies at press + ExecuteBy", InputBuffer.pop(buffer, 20.01 + Settings.Input.ExecuteBy + 0.02) == nil)
end

-- T-IN-04: Light and Deflect pressed on the same tick from Idle. Deflect (priority 100) starts; the Light
-- either runs after the deflect or leaves Superseded. Exactly one terminal each, deterministic.
do
	local outcomes = {}
	for run = 1, 2 do
		local w = newWorld()
		local player, e = w.player(1)
		w.send(player, 1, "Light", 0.01)
		w.send(player, 2, "Deflect", 0.01)
		w.step()
		check("T-IN-04 deflect starts first", e.Fighter.State == "Deflecting", e.Fighter.State)
		for _ = 1, 40 do
			w.step()
		end
		local t = w.terminals()
		check("T-IN-04 deflect Executed once", t[2] and #t[2] == 1 and string.sub(t[2][1], 1, 8) == "Executed")
		check("T-IN-04 light ends exactly once", t[1] and #t[1] == 1, t[1] and table.concat(t[1], ","))
		outcomes[run] = t[1] and t[1][1]
	end
	check("T-IN-04 deterministic", outcomes[1] == outcomes[2])
	print("      T-IN-04 light outcome: " .. tostring(outcomes[1]))
end

-- T-IN-06: a long-running server whose simTime has drifted just below the tick grid (accumulated TICK). The
-- snapped press time must not land after receipt: in Studio after ~2 h it raised inside push, after the ack,
-- and the intent vanished with no terminal record.
do
	local w = newWorld()
	local player, e = w.player(1)
	w.now = 488838 * TICK - 1e-7
	local ok, err = pcall(w.send, player, 1, "Light", 0)
	check("T-IN-06 drifted clock: push does not raise", ok, err)
	w.step()
	local t = w.terminals()[1]
	check("T-IN-06 drifted clock: press executes with one terminal", t and #t == 1 and t[1] == "Executed:Jian_L1" and e.Fighter.State ~= "Idle", t and table.concat(t, ","))
end

-- T-IN-05: every intent ends with exactly one terminal record, across a seeded mixed stream with random
-- transit 0-150 ms, including duplicates, a respawn flush and buffer overflow.
do
	local w = newWorld()
	local player, e = w.player(1)
	local state = 20261102
	local function rand(): number -- deterministic LCG (no Roblox Random under Lune)
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	local actions = { "Light", "Heavy", "Deflect", "Dash", "Light", "Light" }
	local seq = 0
	for k = 1, 600 do
		if rand() < 0.35 then
			seq += 1
			w.send(player, seq, actions[1 + math.floor(rand() * #actions)], rand() * 0.15)
		end
		if k == 300 then
			InputBuffer.clear(e.Buffer) -- death / respawn flush
		end
		w.step()
	end
	for _ = 1, 30 do
		w.step()
	end
	local t, missing, multiple = w.terminals(), 0, 0
	for s = 1, seq do
		if not t[s] then
			missing += 1
		elseif #t[s] > 1 then
			multiple += 1
		end
	end
	check(string.format("T-IN-05 %d intents: none without a terminal record", seq), missing == 0, missing)
	check("T-IN-05 none with more than one terminal record", multiple == 0, multiple)
	local counts = {}
	for _, list in t do
		local status = string.match(list[1], "^%a+")
		counts[status] = (counts[status] or 0) + 1
	end
	local parts = {}
	for status, n in counts do
		table.insert(parts, status .. " " .. n)
	end
	table.sort(parts)
	print("      T-IN-05 terminal mix: " .. table.concat(parts, ", "))
end

-- Death / respawn flush reports every waiting press as Flushed.
do
	local w = newWorld()
	local player, e = w.player(1)
	assert(Combat.tryAttack(e.Fighter, "Heavy", w.now))
	w.send(player, 1, "Light", 0.02)
	w.send(player, 2, "Dash", 0.02)
	InputBuffer.clear(e.Buffer)
	local t = w.terminals()
	check("flush: both waiting presses reported Flushed", t[1] and t[1][1] == "Flushed:Light" and t[2] and t[2][1] == "Flushed:Dash")
end

-------------------------------------------------------------------------------------------------
-- T-SP: spell boundary queue. The real MagicService runs with the real SpellRules; a cast pressed while the
-- fighter is still recovering waits Input.BufferWindow from receipt, starts on the first legal tick and is
-- charged Qi and cooldown exactly once; one that cannot start in time is refused with no cost.
-------------------------------------------------------------------------------------------------

do
	local SpellRules = require("../src/simulation/SpellRules")
	local SpellSchema = require("../src/simulation/SpellSchema")
	local function spellWorld()
		local w = { now = 1000, results = {}, steps = {}, events = {} }
		local fighter = Combat.new(7, "Jian", w.now)
		local player = { UserId = 7 }
		local actor = { Fighter = fighter, Player = player, Root = { Position = Vector3 and Vector3.zero or { X = 0 } } }
		local profile = { souls = { inventory = { spellSlots = { "ThunderclapPalm" }, spells = { ThunderclapPalm = true }, offhand = nil } } }
		local remote = {
			FireClient = function(_, _, packet) table.insert(w.results, packet) end,
			OnServerEvent = { Connect = function(_, fn) w.events.cast = fn return { Disconnect = function() end } end },
		}
		local signal = { Connect = function() return { Disconnect = function() end } end }
		local Shared = { Simulation = { SpellSchema = SpellSchema, SpellRules = SpellRules },
			Shared = { ArsenalProtocol = { valid = function() return true end }, IntentProtocol = { Take = function() return true end }, CombatSettings = Settings },
			Net = { WaitForChild = function() return remote end } }
		Shared.WaitForChild = function() return Shared end
		local services = {
			Players = { GetPlayerByUserId = function(_, id) return if id == 7 then player else nil end, PlayerRemoving = signal },
			ReplicatedStorage = { WaitForChild = function() return Shared end },
		}
		local Characters = {
			OnStep = function(fn) table.insert(w.steps, fn) return function() end end,
			GetActor = function(id) return if id == 7 then actor else nil end,
			Now = function() return w.now end,
			Cue = function() end,
		}
		local env = setmetatable({
			game = { GetService = function(_, name) return services[name] end },
			script = { Parent = { CharacterService = Characters, PersistenceService = { Get = function() return profile end },
				SpellEffects = { clear = function() end, release = function() end, step = function() end } } },
			require = function(module) return module end,
		}, { __index = getfenv and getfenv(1) or _G })
		local source = string.gsub(fs.readFile("src/server/Services/MagicService.luau"), "^%-%-!strict\n", "")
		local Magic = luau.load(source, { debugName = "MagicService", environment = env })()
		Magic.Start()
		w.fighter = fighter
		function w.step()
			w.now += TICK
			Combat.step(fighter, w.now, TICK, {})
			for _, fn in w.steps do
				fn(w.now, TICK)
			end
		end
		function w.press()
			w.events.cast(player, { action = "Cast", slot = 1 })
		end
		return w
	end
	local cost = SpellSchema.get("ThunderclapPalm").QiCost
	local function recoveringTicks(w): number
		local k = 0
		while w.fighter.State ~= "Idle" do
			w.step()
			k += 1
		end
		return k
	end
	local probe = spellWorld()
	assert(Combat.tryAttack(probe.fighter, "Light", probe.now))
	local idleAfter = recoveringTicks(probe)

	-- Pressed 60 ms before the fighter is free: casts on the first legal tick, charged once.
	local w = spellWorld()
	assert(Combat.tryAttack(w.fighter, "Light", w.now))
	local early = math.floor(0.06 / TICK + 0.5)
	for _ = 1, idleAfter - early do
		w.step()
	end
	local qi = w.fighter.Qi
	w.press()
	check("T-SP-01 a cast pressed in recovery is not refused at once", #w.results == 0, w.results[1] and w.results[1].message)
	local castAt
	for k = 1, 20 do
		w.step()
		if w.fighter.State == "Recovery" and w.fighter.Move == nil and not castAt then
			castAt = k
		end
	end
	local finals = 0
	for _, r in w.results do
		if r.action == "Result" then
			finals += 1
		end
	end
	check("T-SP-01 it starts on the first legal tick", castAt == early, string.format("%s vs %d", tostring(castAt), early))
	check("T-SP-01 Qi charged exactly once (less passive regen)", math.abs(qi - w.fighter.Qi - cost) < 1, qi - w.fighter.Qi)
	check("T-SP-01 one Result for the press", finals == 1, finals)

	-- Pressed 150 ms before the fighter is free: refused when the 100 ms window closes, with no cost.
	local w2 = spellWorld()
	assert(Combat.tryAttack(w2.fighter, "Light", w2.now))
	local tooEarly = math.floor(0.15 / TICK + 0.5)
	for _ = 1, idleAfter - tooEarly do
		w2.step()
	end
	local qi2 = w2.fighter.Qi
	w2.press()
	for _ = 1, 30 do
		w2.step()
	end
	local last = w2.results[#w2.results]
	check("T-SP-02 a cast that cannot start in time is refused", last and last.action == "Result" and last.ok == false and last.message == "Cannot cast now", last and last.message)
	check("T-SP-02 the refused cast costs nothing", w2.fighter.Qi >= qi2 - 1e-6 and w2.fighter.State == "Idle")
end

-------------------------------------------------------------------------------------------------
-- B. Replicated timeline: codec v4, action identity, bounded local prediction
-------------------------------------------------------------------------------------------------

-- T-RT-01: the v4 record carries ActionSeq, the sample tick and the sample's server clock; a v3 record is
-- refused rather than misread.
do
	local f = Combat.new(3, "Jian", 50)
	assert(Combat.tryAttack(f, "Light", 50))
	local s = Combat.unpackString(Combat.packString(f, 50.1, nil, 123456, 98765.4321))
	check("T-RT-01 v4 round trip keeps the sample tick", s and s.SampleTick == 123456)
	check("T-RT-01 v4 round trip keeps the sample stamp", s and math.abs(s.SampleStamp - 98765.4321) < 1e-9)
	check("T-RT-01 v4 round trip carries an ActionSeq", s and s.ActionSeq == f.ActionSeq and f.ActionSeq > 0)
	local old = Combat.pack(f, 50.1)
	buffer.writeu8(old, 0, 3)
	check("T-RT-01 a v3 record is refused", Combat.unpack(old) == nil)
end

-- T-RT-02: one move keeps one identity from Startup through Recovery; the same move repeated, or the same
-- non-move state entered twice, gets a new one even when the client only ever sees the same state.
do
	local f = Combat.new(4, "Jian", 0)
	local now = 0
	local function sample(): (string, number)
		local s = Combat.unpackString(Combat.packString(f, now))
		return s.State, s.ActionSeq
	end
	assert(Combat.tryAttack(f, "Light", now))
	local _, first = sample()
	local seen = { [first] = true }
	local states = {}
	while f.State ~= "Idle" do
		now += TICK
		Combat.step(f, now, TICK, {})
		local state, seq = sample()
		states[state] = true
		if f.Move then
			check("T-RT-02 one swing keeps one ActionSeq (" .. state .. ")", seq == first, seq)
		end
	end
	check("T-RT-02 the swing passed Startup, Active and Recovery", states.Active and states.Recovery)
	now += 1
	Combat.step(f, now, TICK, {})
	assert(Combat.tryAttack(f, "Light", now))
	local state, second = sample()
	check("T-RT-02 the same move again is a new action", state == "Startup" and f.Move.Id == "Jian_L1" and second ~= first)
	while f.State ~= "Idle" do
		now += TICK
		Combat.step(f, now, TICK, {})
	end
	now += 2
	Combat.step(f, now, TICK, {})
	assert(Combat.tryDash(f, "Dash", now, 0, 1, {}))
	local _, dashA = sample()
	while f.State ~= "Idle" do
		now += TICK
		Combat.step(f, now, TICK, {})
	end
	now += 2
	Combat.step(f, now, TICK, {})
	assert(Combat.tryDash(f, "Dash", now, 0, 1, {}))
	local _, dashB = sample() -- Dashing -> (Idle skipped) -> Dashing
	check("T-RT-02 two dashes with the Idle between unseen are two actions", dashA ~= dashB)
	seen[second] = true
end

-- T-PR-01: LocalPrediction predicts exactly what the server starts, and nothing it might refuse.
do
	local Prediction = require("../src/simulation/LocalPrediction")
	local Weapons = require("../src/simulation/WeaponSchema")
	local exact, total = 0, 0
	for key in Weapons.Weapons do
		for _, kind in { "Light", "Heavy" } do
			local f = Combat.new(5, key, 10)
			local snap = Combat.unpackString(Combat.packString(f, 10))
			local predicted = Prediction.attack(snap, kind)
			local ok, started = Combat.tryAttack(f, kind, 10)
			total += 1
			if predicted ~= nil and ok and predicted == started then
				exact += 1
			elseif predicted ~= nil then
				print(string.format("      mispredict %s %s: %s vs %s", key, kind, tostring(predicted), tostring(started)))
			end
		end
	end
	check(string.format("T-PR-01 Idle attack prediction matches the server's move (%d/%d)", exact, total), exact == total)
	local f = Combat.new(6, "Jian", 10)
	assert(Combat.tryAttack(f, "Light", 10))
	local busy = Combat.unpackString(Combat.packString(f, 10.02))
	check("T-PR-01 no attack prediction outside Idle (combo follow-ups wait for the server)", Prediction.attack(busy, "Light") == nil)
	local tired = Combat.new(6, "Jian", 10)
	tired.Stamina = 1
	check("T-PR-01 no prediction without stamina to spare", Prediction.attack(Combat.unpackString(Combat.packString(tired, 10)), "Heavy") == nil)
	local fresh = Combat.new(6, "Jian", 10)
	local snap = Combat.unpackString(Combat.packString(fresh, 10))
	local distance, duration = Prediction.dash(snap, "Dash", 5)
	local grant = Combat.tryDash(fresh, "Dash", 10, 0, 1, {})
	check("T-PR-01 predicted dash distance and duration equal the grant", grant and distance == grant.Distance and duration == grant.Duration)
	check("T-PR-01 no dash prediction inside the spam window (decay unknown to the client)", Prediction.dash(snap, "Dash", 0.5) == nil)
	local hurt = Combat.new(6, "Jian", 10)
	local hurtSnap = Combat.unpackString(Combat.packString(hurt, 10))
	hurtSnap.Injuries.LeftLeg = "Injured"
	check("T-PR-01 no dash prediction with a leg injury (distance scaled)", Prediction.dash(hurtSnap, "Dash", 5) == nil)
	check("T-PR-01 terminal record lookup", Prediction.terminal("5:Executed:Jian_L1:9;6:Expired:Light:11", 6) == "Expired"
		and Prediction.terminal("5:Executed:Jian_L1:9", 6) == nil)
end

-- T-PR-02: the real WorldStateController runs one dash executor. A predicted dash adopts the server's
-- grant for the expected DashSeq instead of starting again (no double displacement); a rejected or
-- unconfirmed prediction returns the root to where it started; a predicted swing never moves the body.
do
	local roblox = require("@lune/roblox") :: any
	local task = require("@lune/task")
	local Prediction = require("../src/simulation/LocalPrediction")
	local clock = 100
	local attributes = {}
	local intentChanged = { Links = {} }
	function intentChanged:Connect(fn)
		table.insert(self.Links, fn)
		return { Disconnect = function() end, Connected = true }
	end
	local player = {
		UserId = 1, Name = "Owner",
		CharacterAdded = { Connect = function() return { Disconnect = function() end } end },
		GetAttribute = function(_, name) return attributes[name] end,
		GetAttributeChangedSignal = function() return intentChanged end,
	}
	local function setIntent(value)
		attributes.AsuraIntent = value
		for _, fn in intentChanged.Links do
			fn()
		end
	end
	local quiet = { Connect = function() return { Disconnect = function() end } end }
	local function finder(t)
		return setmetatable(t, { __index = { WaitForChild = function(self, n) return rawget(self, n) end } })
	end
	local services = {
		Players = { LocalPlayer = player, PlayerAdded = quiet, GetPlayers = function() return {} end },
		Workspace = { GetServerTimeNow = function() return clock end, WaitForChild = function() return nil end, GetAttribute = function() return nil end },
		CollectionService = { GetTagged = function() return {} end, GetInstanceAddedSignal = function() return quiet end },
		ReplicatedStorage = finder({ AsurasPath = finder({ Simulation = finder({ CombatRules = Combat, LocalPrediction = Prediction }) }) }),
	}
	local env = {
		game = { GetService = function(_, n) return assert(services[n], n) end },
		os = { clock = function() return clock end },
		task = task, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Enum = roblox.Enum,
		Instance = roblox.Instance, require = function(m) return m end, warn = function() end,
	}
	local World = luau.load(fs.readFile("src/client/Controllers/WorldStateController.luau"), { debugName = "WorldState", environment = env })()
	local net = finder({ StateSnapshots = { OnClientEvent = quiet } })

	local function rig()
		table.clear(intentChanged.Links)
		attributes = {}
		local state = World.new(net)
		local root = roblox.Instance.new("Part")
		root.CFrame = roblox.CFrame.new(0, 3, 0)
		root.AssemblyLinearVelocity = roblox.Vector3.zero -- no physics here: velocities are only read back
		local fighter = Combat.new(1, "Jian", clock)
		local model = roblox.Instance.new("Model")
		model.Parent = roblox.Instance.new("Folder")
		root.Parent = model
		local entity = { Id = 1, Model = model, Root = root, Snapshot = nil, UpdatedAt = clock, Age = 0, Connections = {} }
		state.Entities[1] = entity
		local function publish()
			entity.Snapshot = Combat.unpackString(Combat.packString(fighter, clock, nil, 0, clock))
			entity.UpdatedAt = clock
		end
		publish()
		state:Step(TICK) -- first snapshot: learns DashSeq
		return state, root, fighter, publish
	end
	local function planar(root): number
		local p = root.Position
		return math.sqrt(p.X * p.X + p.Z * p.Z)
	end

	-- Adopted grant: the executor is not restarted and the prediction ends on the server's action.
	local state, root, fighter, publish = rig()
	check("T-PR-02 a dash from Idle is predicted", state:Predict(1, "Dash", 0, 1) == true)
	local from, length, ends = state.DashFrom, state.DashLength, state.DashEnds
	check("T-PR-02 the predicted dash starts locally at once", ends > clock and length > 0)
	root.CFrame = roblox.CFrame.new(0, 3, 5) -- 5 studs travelled before the grant arrives
	clock += 0.08
	assert(Combat.tryDash(fighter, "Dash", clock - 0.03, 0, 1, {}))
	publish()
	state:Step(TICK)
	check("T-PR-02 the grant is adopted, not applied again (start kept)", state.DashFrom == from)
	check("T-PR-02 the grant does not extend or restart the dash", state.DashLength == length and state.DashEnds == ends)
	check("T-PR-02 the prediction is confirmed by the snapshot", state.Predicted == nil)
	setIntent("1:Executed:Dash:9")
	check("T-PR-02 a late Executed record changes nothing", (root.Position - roblox.Vector3.new(0, 3, 5)).Magnitude < 1e-6)
	check("T-PR-02 a second dash inside the spam window is not predicted", state:Predict(2, "Dash", 0, 1) == false)
	state:Destroy()

	-- Rejected: the root returns to its start, the drive stops.
	state, root, fighter, publish = rig()
	assert(state:Predict(7, "Dash", 1, 0))
	root.CFrame = roblox.CFrame.new(6, 3, 0)
	setIntent("6:Executed:Light:3;7:Rejected:Exhausted:4")
	check("T-PR-02 a rejected dash returns the root to its start", planar(root) < 1e-6 and state.Predicted == nil and state.DashEnds == 0)
	state:Destroy()

	-- Unconfirmed: rolled back after CONFIRM_TIMEOUT.
	state, root, fighter, publish = rig()
	assert(state:Predict(8, "Roll", 1, 0))
	root.CFrame = roblox.CFrame.new(4, 3, 0)
	clock += Prediction.CONFIRM_TIMEOUT + 0.05
	publish()
	state:Step(TICK)
	check("T-PR-02 an unconfirmed dash is rolled back after the timeout", planar(root) < 1e-6 and state.Predicted == nil)
	state:Destroy()

	-- A predicted swing ends on an Expired record and never moves the body.
	state, root, fighter, publish = rig()
	check("T-PR-02 a Light from Idle is predicted as its first move", state:Predict(9, "Light", 0, 1) and state.Predicted.Move == "Jian_L1")
	root.CFrame = roblox.CFrame.new(0, 3, 2) -- walking
	setIntent("9:Expired:Light:12")
	check("T-PR-02 an expired swing prediction ends without touching the body", state.Predicted == nil and (root.Position - roblox.Vector3.new(0, 3, 2)).Magnitude < 1e-6)
	state:Destroy()
end

-------------------------------------------------------------------------------------------------
-- C. Defense and contact consistency. The real contact block (facingAt .. settleContacts) and helpers from
-- CharacterService run with the real LagCompensation and CombatRules in the Stage 2 phase order.
-------------------------------------------------------------------------------------------------

do
	local roblox = require("@lune/roblox") :: any
	local V3, CF = roblox.Vector3, roblox.CFrame
	local Strike = require("../src/simulation/StrikeGeometry")
	local geo = { Vector3 = V3, CFrame = CF, math = math, table = table, type = type, setmetatable = setmetatable,
		ipairs = ipairs, pairs = pairs, next = next, assert = assert, error = error, tostring = tostring, string = string, os = os }
	local Lag = luau.load(fs.readFile("src/server/LagCompensation.luau"), { debugName = "LagCompensation", environment = geo })()
	local contactChunk = table.concat({
		"local Combat, Lag, TICK, FACING_DOT, entities, frameEvents, eventPoints, Strike = ...",
		"local function alive() return true end",
		"local function hostile(a, b) return a ~= b end",
		"local function awardXp() end",
		"local function yawOf(cf) local l = cf.LookVector return math.atan2(-l.X, -l.Z) end",
		between(service, "local function flatUnit(", "\nlocal function alive("),
		between(service, "local function weaponSegment(", "\n-------"),
		between(service, "local function facingAt(", "\n-- Whiffs (batch 09)"),
		"return { detect = resolveContacts, resolve = resolveContact, defer = deferContact, settle = settleContacts, pending = pendingContacts }",
	}, "\n")

	-- Two (or three) fighters face to face 5 studs apart; `ping` makes a fighter a player (grace applies).
	local function arena(specs: { any })
		local w = { now = 500, entities = {}, events = {}, list = {} }
		w.api = luau.load(contactChunk, { debugName = "Stage2Contacts", environment = geo })(Combat, Lag, TICK, 0.15, w.entities, w.events, {}, Strike)
		for _, spec in specs do
			local at = V3.new(spec.x or 0, 3, spec.z or 0)
			local cframe = CF.lookAt(at, at + V3.new(spec.lx or 0, 0, spec.lz or -1))
			local e = {
				Id = spec.id, Kind = if spec.ping then "Player" else "Enemy", Fighter = Combat.new(spec.id, spec.weapon or "Jian", w.now),
				Root = { CFrame = cframe, Position = cframe.Position }, Model = { GetAttribute = function() return nil end },
				Omni = { YawFor = -1 }, History = Lag.newHistory(),
				Player = if spec.ping then { GetNetworkPing = function() return spec.ping end } else nil,
			}
			for k = -40, 0 do
				Lag.record(e.History, w.now + k * TICK, cframe, V3.zero)
			end
			w.entities[e.Id] = e
			table.insert(w.list, e)
		end
		-- One server tick in the Stage 2 order: step (closing windows after), settle held contacts, sweep, resolve.
		function w.tick(beforeContacts: (() -> ())?)
			w.now += TICK
			local closing = {}
			for _, e in w.list do
				Lag.record(e.History, w.now, e.Root.CFrame, V3.zero)
				local f = e.Fighter
				if f.State == "Active" and f.Move and w.now >= f.StateEnd then
					table.insert(closing, e)
				else
					Combat.step(f, w.now, TICK, w.events)
				end
			end
			if beforeContacts then
				beforeContacts()
			end
			w.api.settle(w.now)
			local found = {}
			table.sort(w.list, function(a, b) return a.Id > b.Id end)
			for _, e in w.list do
				if e.Fighter.State == "Active" then
					w.api.detect(e, w.now, found)
				end
			end
			for _, c in found do
				if not w.api.defer(c, w.now) then
					w.api.resolve(c, w.now)
				end
			end
			for _, e in closing do
				Combat.step(e.Fighter, w.now, TICK, w.events)
			end
		end
		function w.count(kind: string, source: number?): number
			local n = 0
			for _, event in w.events do
				if event.Kind == kind and (source == nil or event.Source == source or event.Target == source) then
					n += 1
				end
			end
			return n
		end
		return w
	end
	local function run(w, ticks: number, hook: ((number) -> ())?)
		for k = 1, ticks do
			w.tick(if hook then function() hook(k) end else nil)
		end
	end
	local function contactTick(): number
		-- Ticks from a Jian light's start until its first contact on a body 5 studs ahead.
		local w = arena({ { id = 1 }, { id = -1, z = -5, lz = 1 } })
		assert(Combat.tryAttack(w.entities[1].Fighter, "Light", w.now))
		for k = 1, 30 do
			w.tick()
			if w.entities[-1].Fighter.ActiveHP < w.entities[-1].Fighter.MaxHP then
				return k
			end
		end
		error("the reference light never landed")
	end
	local HIT = contactTick()

	-- T-PA-01: an on-time deflect takes no HP, gives Qi and posture as authored, resolves the contact once.
	do
		local w = arena({ { id = 1 }, { id = -1, z = -5, lz = 1 } })
		local a, d = w.entities[1].Fighter, w.entities[-1].Fighter
		assert(Combat.tryAttack(a, "Light", w.now))
		local qi, aPosture = d.Qi, a.Posture
		run(w, 30, function(k)
			if k == HIT - 2 then
				assert(Combat.tryDeflect(d, w.now, w.now))
			end
		end)
		check("T-PA-01 parry: no HP lost", d.ActiveHP == d.MaxHP and d.RecoverableHP == 0)
		check("T-PA-01 parry: Qi gained once", math.abs(d.Qi - math.min(d.MaxQi, qi + Settings.Qi.GainOnDeflect)) < 1e-6, d.Qi - qi)
		check("T-PA-01 parry: attacker takes reflected posture", a.Posture > aPosture)
		check("T-PA-01 parry: exactly one DeflectSpark, no Hit or Block", w.count("DeflectSpark") == 1 and w.count("Hit") == 0 and w.count("Block") == 0)
	end

	-- T-PA-02: a swing that misses rejects every damage path.
	do
		local w = arena({ { id = 1 }, { id = -1, z = -12, lz = 1 } })
		local d = w.entities[-1].Fighter
		assert(Combat.tryAttack(w.entities[1].Fighter, "Light", w.now))
		local posture = d.Posture
		run(w, 30)
		check("T-PA-02 miss: no damage, posture, block or deflect", d.ActiveHP == d.MaxHP and d.Posture == posture
			and w.count("Hit") == 0 and w.count("Block") == 0 and w.count("DeflectSpark") == 0 and w.count("Whiff") == 1)
	end

	-- T-PA-03: window edges at the contact instant: +100 ms (+half tick) deflects, one tick later only guards.
	do
		for _, case in { { 0.10, "Deflected" }, { 0.10 + TICK, "Blocked" }, { -TICK, "Hit" } } do
			local a, d = Combat.new(1, "Jian", 10), Combat.new(2, "Jian", 10)
			assert(Combat.tryAttack(a, "Light", 10))
			local tc = 10 + a.Move.Timing.StartupSeconds
			a.State, a.StateStart = "Active", tc
			if case[1] >= 0 then
				assert(Combat.tryDeflect(d, tc - case[1], tc - case[1]))
				Combat.step(d, tc, TICK, {})
			else
				-- the press comes one tick after t_c: too late, even though it reaches the server first
				assert(Combat.tryDeflect(d, tc + TICK, tc + TICK))
			end
			local outcome = Combat.resolveHit(a, d, tc + TICK, { Facing = true, Region = "Torso", Move = a.Move, DefenderState = if case[1] >= 0 then d.State else "Idle", At = tc }, {})
			check(string.format("T-PA-03 press %+d ms from t_c -> %s", -case[1] * 1000, case[2]), outcome == case[2], outcome)
		end
	end

	-- T-PA-04: bounded grace. A player's deflect stamped before t_c that reaches the server after the contact
	-- was detected still deflects it; one stamped after t_c never does; no press = the hit lands at grace end.
	local function graced(ping: number, pressAt: number?, arriveTicks: number): (any, any)
		local w = arena({ { id = -5 }, { id = 9, z = -5, lz = 1, ping = ping } })
		local a, d = w.entities[-5].Fighter, w.entities[9].Fighter
		assert(Combat.tryAttack(a, "Light", w.now))
		local tc
		run(w, 30, function(k)
			if k == HIT then
				tc = w.now
			elseif tc and pressAt and k == HIT + arriveTicks then
				Combat.tryDeflect(d, w.now, tc + pressAt) -- the drained intent, press time reconciled
			end
		end)
		return w, d
	end
	do
		local w, d = graced(0.1, -0.03, 3)
		check("T-PA-04 deflect pressed 30 ms before t_c, arriving 3 ticks after it, deflects", d.ActiveHP == d.MaxHP and w.count("DeflectSpark") == 1 and w.count("Hit") == 0)
		w, d = graced(0.1, 0.02, 2)
		check("T-PA-04 deflect pressed 20 ms after t_c never deflects", d.ActiveHP < d.MaxHP and w.count("DeflectSpark") == 0)
		w, d = graced(0.1, nil, 0)
		check("T-PA-04 no press: the hit lands once, after the grace", d.ActiveHP < d.MaxHP and w.count("Hit") == 1)
		w, d = graced(0.1, -0.03, 8)
		check("T-PA-04 a press arriving after the grace is too late", d.ActiveHP < d.MaxHP and w.count("DeflectSpark") == 0)
		w, d = graced(2.0, -0.03, 7)
		check("T-PA-04 grace is capped at 100 ms whatever the ping (7 ticks later still lands)", d.ActiveHP < d.MaxHP)
	end

	-- T-PA-05: NPC defenders are never held; a held contact resolves at once when the defender acts anew.
	do
		local w = arena({ { id = -5 }, { id = -6, z = -5, lz = 1 } })
		assert(Combat.tryAttack(w.entities[-5].Fighter, "Light", w.now))
		run(w, HIT)
		check("T-PA-05 NPC defender: resolved on the contact tick", #w.api.pending == 0 and w.entities[-6].Fighter.ActiveHP < w.entities[-6].Fighter.MaxHP)
		local w2 = arena({ { id = -5 }, { id = 9, z = -5, lz = 1, ping = 0.1 } })
		local d = w2.entities[9].Fighter
		assert(Combat.tryAttack(w2.entities[-5].Fighter, "Light", w2.now))
		run(w2, HIT)
		check("T-PA-05 player defender: held for the grace", #w2.api.pending == 1)
		w2.tick(function() Combat.tryAttack(d, "Heavy", w2.now) end)
		check("T-PA-05 starting an attack after t_c ends the hold: hit lands, the attack is cancelled", #w2.api.pending == 0 and d.State == "Hitstun")
	end

	-- T-OR-01: a mutual strike on the same tick is a trade whatever the ids or join order.
	do
		for _, ids in { { 1, -1 }, { -1, 1 }, { 7, 3 } } do
			local w = arena({ { id = ids[1] }, { id = ids[2], z = -5, lz = 1 } })
			local a, b = w.entities[ids[1]].Fighter, w.entities[ids[2]].Fighter
			assert(Combat.tryAttack(a, "Light", w.now))
			assert(Combat.tryAttack(b, "Light", w.now))
			run(w, HIT)
			check(string.format("T-OR-01 ids %d/%d: both struck (trade)", ids[1], ids[2]), a.ActiveHP < a.MaxHP and b.ActiveHP < b.MaxHP and w.count("Hit") == 2)
		end
	end

	-- T-PA-06: one press inside its window answers each distinct contact once: two attackers striking together
	-- are both deflected (stated policy, TIMING_CONTRACT §5.2), never the same contact twice.
	do
		local w = arena({ { id = 1, x = -1.5 }, { id = 2, x = 1.5 }, { id = -1, z = -5, lz = 1 } })
		local d = w.entities[-1].Fighter
		assert(Combat.tryAttack(w.entities[1].Fighter, "Light", w.now))
		assert(Combat.tryAttack(w.entities[2].Fighter, "Light", w.now))
		run(w, 30, function(k)
			if k == HIT - 2 then
				assert(Combat.tryDeflect(d, w.now, w.now))
			end
		end)
		check("T-PA-06 simultaneous attackers: both contacts deflected, one spark each", w.count("DeflectSpark", 1) == 1 and w.count("DeflectSpark", 2) == 1 and d.ActiveHP == d.MaxHP)
	end

	-- T-PA-07: head injury and spam decay shrink the window; a success re-arms and resets the chain.
	do
		local f = Combat.new(1, "Jian", 10)
		f.Injuries.Head = "Severe"
		assert(Combat.tryDeflect(f, 10, 10))
		check("T-PA-07 a severe head injury shortens the window", f.DeflectWindow < Settings.Posture.DeflectWindow and not Combat.isDeflectTimed(f, 10 + 0.095))
		local g = Combat.new(2, "Jian", 10)
		assert(Combat.tryDeflect(g, 10, 10))
		assert(Combat.tryDeflect(g, 10.2, 10.2))
		check("T-PA-07 a second press inside 300 ms decays the window", g.DeflectChain == 1 and g.DeflectWindow < Settings.Posture.DeflectWindow)
		local a = Combat.new(3, "Jian", 10)
		assert(Combat.tryAttack(a, "Light", 10.2))
		a.State = "Active"
		Combat.resolveHit(a, g, 10.25, { Facing = true, Region = "Torso" }, {})
		check("T-PA-07 a successful deflect resets the chain", g.DeflectChain == 0)
		check("T-PA-07 and the next press is legal at once (re-arm)", (Combat.tryDeflect(g, 10.26, 10.26)) and g.DeflectChain == 0)
	end

	-- T-PA-08: Perilous Thrust uses the shared window (was a literal 0.1 s with no half-tick, no injury scaling).
	do
		local function thrust(offset: number, head: string?): string
			local boss, f = Combat.new(-100, "Jian", 10), Combat.new(1, "Jian", 10)
			if head then
				f.Injuries.Head = head :: any
			end
			assert(Combat.tryDeflect(f, 10, 10))
			return Combat.applyBossAttack(boss, f, 10 + offset, 30, 40, "PerilousThrust", true, {})
		end
		check("T-PA-08 thrust at +100 ms + 5 ms (inside the half tick) is deflected", thrust(0.105) == "Deflected")
		check("T-PA-08 thrust a tick past the window is not", thrust(0.10 + TICK) ~= "Deflected")
		check("T-PA-08 head injury shortens the thrust window too", thrust(0.095, "Severe") ~= "Deflected")
		check("T-PA-08 one tick before the press is not deflected (no retroactive parry)", thrust(-TICK) ~= "Deflected")
	end

	-- T-HS: light hitstun can be answered defensively after LightDefendCancel, never with an attack or dodge;
	-- heavy hitstun is unchanged. Before Stage 2 nothing was legal in Hitstun.
	do
		local function stunned(kind: string, after: number)
			local a, d = Combat.new(1, "Jian", 10), Combat.new(2, "Jian", 10)
			assert(Combat.tryAttack(a, kind :: any, 10))
			a.State = "Active"
			assert(Combat.resolveHit(a, d, 10, { Facing = false, Region = "Torso" }, {}) == "Hit" and d.State == "Hitstun")
			Combat.step(d, 10 + after, TICK, {})
			return d, 10 + after
		end
		local d, t = stunned("Light", Settings.Stun.LightDefendCancel)
		check("T-HS light hitstun: deflect legal after the defend point", (Combat.tryDeflect(d, t, t)))
		d, t = stunned("Light", Settings.Stun.LightDefendCancel)
		check("T-HS light hitstun: guard legal after the defend point", (Combat.setGuard(d, true, t)) and d.State == "Blocking")
		d, t = stunned("Light", Settings.Stun.LightDefendCancel)
		check("T-HS light hitstun: still no attack or dash", not Combat.tryAttack(d, "Light", t) and Combat.tryDash(d, "Dash", t, 0, 1, {}) == nil)
		d, t = stunned("Light", Settings.Stun.LightDefendCancel - TICK)
		check("T-HS light hitstun: no deflect before the defend point", not Combat.tryDeflect(d, t, t))
		d, t = stunned("Heavy", 0.3)
		check("T-HS heavy hitstun: still no deflect", not Combat.tryDeflect(d, t, t))
		d, t = stunned("Light", 0.15)
		assert(Combat.tryDeflect(d, t, t - 0.12))
		check("T-HS a rewound press cannot start its window before the hit", d.DeflectPressedAt >= 10)
	end
end

-- The client requires LocalPrediction by WaitForChild: an unmapped module would hang the client bootstrap.
check("LocalPrediction is mapped into Simulation", string.find(fs.readFile("default.project.json"), '"$path": "src/simulation/LocalPrediction.luau"', 1, true) ~= nil)

print(string.format("stage 2 timing: %d passed, %d failed (offline behaviour; Studio, latency and feel separate)", passed, failed))
if failed > 0 then
	error("stage 2 timing regression failed")
end

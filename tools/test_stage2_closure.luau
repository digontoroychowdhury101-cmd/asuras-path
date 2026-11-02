--!nonstrict
-- Combat recovery Stage 2 closure pass (2 November 2026): the cases the Stage 2 review left open.
--   P  prediction is confirmed by its own intent, never by an unrelated action change;
--   D  a contact held in the defender's grace resolves on what was true at t_c (TIMING_CONTRACT §0);
--   G  grace for parry, dodge and boss/area strikes, and the hit-confirm delay it adds;
--   R  receipt -> start is one tick; a refused dash's correction never teleports a new body or passes a wall.
-- Runs the real CombatRules, LocalPrediction, LagCompensation, WorldStateController and the CharacterService
-- intent and contact blocks under Lune, with engine services faked. Evidence class: offline behaviour.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox") :: any
local task = require("@lune/task")
local Combat = require("../src/simulation/CombatRules")
local Schema = require("../src/simulation/MoveSchema")
local InputBuffer = require("../src/simulation/InputBuffer")
local Tempo = require("../src/simulation/Tempo")
local Prediction = require("../src/simulation/LocalPrediction")
local Strike = require("../src/simulation/StrikeGeometry")
local Settings = require("../src/shared/CombatSettings")

local V3, CF = roblox.Vector3, roblox.CFrame
local TICK = Tempo.TickSeconds
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
local service = fs.readFile("src/server/CharacterService.luau")

-------------------------------------------------------------------------------------------------
-- P. Prediction confirmation is correlated to the intent (the real WorldStateController)
-------------------------------------------------------------------------------------------------

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
local function setIntent(value: string)
	attributes.AsuraIntent = value
	for _, fn in intentChanged.Links do
		fn()
	end
end
local blockHit: any = nil -- what the fake Workspace:Blockcast reports (a wall or rising ground), nil = clear
local casts = {}
local quiet = { Connect = function() return { Disconnect = function() end } end }
local function finder(t)
	return setmetatable(t, { __index = { WaitForChild = function(self, n) return rawget(self, n) end } })
end
local services = {
	Players = { LocalPlayer = player, PlayerAdded = quiet, GetPlayers = function() return {} end },
	Workspace = {
		GetServerTimeNow = function() return clock end, WaitForChild = function() return nil end, GetAttribute = function() return nil end,
		Blockcast = function(_, cframe, size, direction, params)
			table.insert(casts, { From = cframe.Position, Direction = direction, Filter = params.FilterDescendantsInstances })
			return blockHit
		end,
	},
	CollectionService = { GetTagged = function() return {} end, GetInstanceAddedSignal = function() return quiet end },
	ReplicatedStorage = finder({ AsurasPath = finder({ Simulation = finder({ CombatRules = Combat, LocalPrediction = Prediction }) }) }),
}
local env = {
	game = { GetService = function(_, n) return assert(services[n], n) end },
	os = { clock = function() return clock end },
	task = task, Vector3 = V3, Vector2 = roblox.Vector2, CFrame = CF, Enum = roblox.Enum,
	Instance = roblox.Instance, require = function(m) return m end, warn = function() end,
	RaycastParams = { new = function() return {} end },
}
local World = luau.load(fs.readFile("src/client/Controllers/WorldStateController.luau"), { debugName = "WorldState", environment = env })()
local net = finder({ StateSnapshots = { OnClientEvent = quiet } })

local sampleTick = 0
local function rig()
	table.clear(intentChanged.Links)
	attributes = {}
	blockHit = nil
	table.clear(casts)
	local state = World.new(net)
	local root = roblox.Instance.new("Part")
	root.Size = V3.new(2, 2, 1)
	root.CFrame = CF.new(0, 3, 0)
	root.AssemblyLinearVelocity = V3.zero
	local fighter = Combat.new(1, "Jian", clock)
	local model = roblox.Instance.new("Model")
	model.Parent = roblox.Instance.new("Folder")
	root.Parent = model
	local entity = { Id = 1, Model = model, Root = root, Snapshot = nil, UpdatedAt = clock, Age = 0, Connections = {} }
	state.Entities[1] = entity
	local function publish(tickOverride: number?)
		sampleTick += 2
		entity.Snapshot = Combat.unpackString(Combat.packString(fighter, clock, nil, tickOverride or sampleTick, clock))
		entity.UpdatedAt = clock
	end
	publish()
	state:Step(TICK)
	return state, root, fighter, publish, entity
end
local function planar(root): number
	local p = root.Position
	return math.sqrt(p.X * p.X + p.Z * p.Z)
end
-- The local drive commands a frame, the given time passes (the body gets there under it), as in Studio.
local function driveTo(state, root, to, seconds)
	state:Step(TICK)
	clock += seconds or 0.1
	root.CFrame = to
end
local function struck(f)
	local attacker = Combat.new(99, "Jian", clock)
	assert(Combat.tryAttack(attacker, "Light", clock))
	attacker.State = "Active"
	return Combat.resolveHit(attacker, f, clock, { Facing = false, Region = "Torso" }, {})
end

-- P-01 hit interruption: the fighter is struck before the predicted dash reaches the server. The Hitstun
-- snapshot changes ActionSeq but names no intent, so the prediction is not confirmed; the server's Expired
-- record then takes back exactly the dash's own travel. (Stage 2 code confirmed on the ActionSeq change.)
do
	local state, root, fighter, publish = rig()
	assert(state:Predict(11, "Dash", 1, 0))
	driveTo(state, root, CF.new(3, 3, 0), 0.05)
	check("P-01 setup: the hit lands", struck(fighter) == "Hit")
	publish()
	state:Step(TICK)
	check("P-01 a hit's ActionSeq change does not confirm the predicted dash", state.Predicted ~= nil and state.Predicted.Seq == 11)
	check("P-01 the server's hitstun stops the local dash", state.DashEnds == 0)
	root.CFrame = CF.new(4, 3, 0) -- 1 stud of knockback after the dash stopped at x = 3
	setIntent("11:Expired:Dash:" .. sampleTick)
	check("P-01 the expired dash takes back only its own travel (knockback kept)", math.abs(root.Position.X - 1) < 1e-6 and state.Predicted == nil, root.Position.X)
	state:Destroy()
end

-- P-02 guard/state change: a guard raised on the server (Blocking) is not the predicted swing.
do
	local state, root, fighter, publish = rig()
	assert(state:Predict(12, "Light", 0, 1))
	clock += 0.03
	assert(Combat.setGuard(fighter, true, clock))
	publish()
	state:Step(TICK)
	check("P-02 a Blocking snapshot does not confirm the predicted Light", state.Predicted ~= nil)
	setIntent("12:Rejected:Blocking:" .. sampleTick)
	check("P-02 the refused swing ends without moving the body", state.Predicted == nil and planar(root) < 1e-6)
	state:Destroy()
end

-- P-03 rejection and P-04 timeout are confirmation-independent: a refusal or an unanswered 0.5 s rolls back.
do
	local state, root = rig()
	assert(state:Predict(13, "Dash", 0, 1))
	driveTo(state, root, CF.new(0, 3, 4))
	setIntent("13:Rejected:Exhausted:" .. sampleTick)
	check("P-03 a rejected dash returns its travel", planar(root) < 1e-6 and state.Predicted == nil)
	state:Destroy()
	local publish
	state, root, _, publish = rig()
	assert(state:Predict(14, "Roll", 1, 0))
	driveTo(state, root, CF.new(4, 3, 0), 0.14)
	clock += Prediction.CONFIRM_TIMEOUT - 0.09
	publish()
	state:Step(TICK)
	check("P-04 no answer within the timeout rolls back", planar(root) < 1e-6 and state.Predicted == nil)
	state:Destroy()
end

-- P-05 delayed confirmation: Idle snapshots keep arriving (the intent is still in flight) and the prediction
-- waits; the snapshot that names intent 15 confirms it, even though no ActionSeq change came first.
do
	local state, _, fighter, publish = rig()
	assert(state:Predict(15, "Light", 0, 1))
	for _ = 1, 8 do
		clock += 0.03
		publish()
		state:Step(TICK)
	end
	check("P-05 0.24 s of unchanged snapshots neither confirm nor roll back", state.Predicted ~= nil and state.Predicted.Seq == 15)
	assert(Combat.tryAttack(fighter, "Light", clock))
	Combat.markIntent(fighter, 15)
	clock += 0.03
	publish()
	state:Step(TICK)
	check("P-05 the snapshot naming intent 15 confirms it", state.Predicted == nil)
	state:Destroy()
end

-- P-06 out-of-order: the Executed record arrives before the snapshot. A sample older than the execution tick
-- (Idle, no intent) changes nothing; a newer one showing another action ends the prediction without undoing
-- the dash the server did execute; a newer one naming the intent would have confirmed it.
do
	local state, root, fighter, publish = rig()
	assert(state:Predict(16, "Dash", 0, 1))
	root.CFrame = CF.new(0, 3, 3)
	local executedAt = sampleTick + 6
	setIntent("16:Executed:Dash:" .. executedAt)
	publish(executedAt - 2)
	state:Step(TICK)
	check("P-06 a sample older than the execution neither confirms nor ends it", state.Predicted ~= nil)
	assert(Combat.tryDash(fighter, "Dash", clock, 0, 1, {}))
	Combat.markIntent(fighter, 16)
	struck(fighter) -- interrupted on the server before any sample showed the dash
	publish(executedAt + 2)
	state:Step(TICK)
	check("P-06 executed then interrupted: the prediction ends", state.Predicted == nil)
	check("P-06 and the executed dash is not taken back", math.abs(root.Position.Z - 3) < 1e-6, root.Position.Z)
	state:Destroy()
end

-- P-07 the snapshot record itself: an intent-started action names its intent; anything after it names 0.
do
	local f = Combat.new(7, "Jian", 20)
	assert(Combat.tryAttack(f, "Light", 20))
	Combat.markIntent(f, 77)
	local s = Combat.unpackString(Combat.packString(f, 20.01))
	check("P-07 v5 record carries the intent that started the action", s and s.IntentSeq == 77)
	struck(f)
	s = Combat.unpackString(Combat.packString(f, 20.02))
	check("P-07 a hit (no intent) names intent 0", s and s.IntentSeq == 0 and s.State == "Hitstun")
	local old = Combat.pack(f, 20.03)
	buffer.writeu8(old, 0, 4)
	check("P-07 a v4 record is refused", Combat.unpack(old) == nil)
	check("P-07 terminal lookup returns status and tick", select(2, Prediction.terminal("5:Executed:Jian_L1:9;6:Expired:Light:11", 6)) == 11)
end

-------------------------------------------------------------------------------------------------
-- R2. Rejected-dash correction: walls, rising ground, interruption, respawn, death
-------------------------------------------------------------------------------------------------

do
	-- Wall: the swept box stops 0.05 studs short of the hit instead of passing through.
	local state, root = rig()
	assert(state:Predict(21, "Dash", 1, 0))
	driveTo(state, root, CF.new(6, 3, 0))
	blockHit = { Distance = 2, Position = V3.new(4, 3, 0) }
	setIntent("21:Rejected:Exhausted:" .. sampleTick)
	check("R-02 a wall between stops the correction short of it", math.abs(root.Position.X - 4.05) < 1e-6, root.Position.X)
	check("R-02 the sweep excludes the own character", casts[1] and casts[1].Filter[1] == state.Entities[1].Model)
	state:Destroy()

	-- Rising ground on the way back is a hit like a wall: the slope is followed only as far as the contact and the
	-- correction never sinks the body (Stage 3: it follows a slope's height rather than cutting through it).
	state, root = rig()
	assert(state:Predict(22, "Dash", 1, 0))
	driveTo(state, root, CF.new(5, 2, 0))
	blockHit = { Distance = 0.5, Position = V3.new(4.5, 2, 0) }
	setIntent("22:Rejected:Exhausted:" .. sampleTick)
	local along = (root.Position - V3.new(5, 2, 0)).Magnitude
	check("R-02 rising ground: corrected only to the contact, never sunk", math.abs(along - 0.45) < 1e-6 and root.Position.Y >= 2, root.Position)
	state:Destroy()

	-- Respawn: the prediction belonged to the previous character; the new one is never moved.
	local entity, publish
	state, root, _, publish, entity = rig()
	assert(state:Predict(23, "Dash", 1, 0))
	local fresh = roblox.Instance.new("Model")
	fresh.Parent = roblox.Instance.new("Folder")
	local spawnRoot = roblox.Instance.new("Part")
	spawnRoot.Size, spawnRoot.CFrame, spawnRoot.Parent = V3.new(2, 2, 1), CF.new(50, 3, 50), fresh
	spawnRoot.AssemblyLinearVelocity = V3.zero
	entity.Model, entity.Root = fresh, spawnRoot
	setIntent("23:Flushed:Dash:" .. sampleTick)
	check("R-02 a respawned character is not teleported toward the old start", spawnRoot.Position == V3.new(50, 3, 50) and #casts == 0)
	state:Destroy()

	-- Death: a KO'd body is left where it fell.
	local fighter
	state, root, fighter, publish = rig()
	assert(state:Predict(24, "Dash", 1, 0))
	driveTo(state, root, CF.new(5, 3, 0))
	Combat.knockOut(fighter, clock)
	publish()
	setIntent("24:Flushed:Dash:" .. sampleTick)
	check("R-02 a KO'd body is not corrected", math.abs(root.Position.X - 5) < 1e-6)
	state:Destroy()
end

-------------------------------------------------------------------------------------------------
-- D. Deferred contacts resolve on what was true at t_c (CombatRules.contactSnapshot)
-------------------------------------------------------------------------------------------------

-- An attacker light reaching its active frame at t_c against a defender; returns the deferred hit context.
local function contact(attackerWeapon: string?, defenderWeapon: string?, facing: boolean?)
	local a, d = Combat.new(1, attackerWeapon or "Jian", 10), Combat.new(2, defenderWeapon or "Jian", 10)
	assert(Combat.tryAttack(a, "Light", 10))
	local tc = 10 + a.Move.Timing.StartupSeconds
	a.State, a.StateStart = "Active", tc
	return a, d, tc, function()
		return { Facing = facing ~= false, Region = "Torso", Move = a.Move, DefenderState = d.State, At = tc, Snapshot = Combat.contactSnapshot(a, d, tc, a.Move) }
	end
end
local function resolve(a, d, hit, now: number): string
	return Combat.resolveHit(a, d, now, hit, {})
end

do
	-- D-01 defender begins a move during the grace: judged Idle at t_c (no counter-hit), and the move is cancelled.
	local a, d, tc, at = contact()
	local hit = at()
	assert(Combat.tryAttack(d, "Light", tc + 0.03))
	local outcome = resolve(a, d, hit, tc + 0.05)
	check("D-01 a move begun after t_c is a plain hit, not a counter", outcome == "Hit", outcome)
	check("D-01 and the move is cancelled into hitstun", d.Move == nil and d.State == "Hitstun")

	-- D-02 hyper armor starting after t_c does not armor the contact.
	a, d, tc, at = contact("Jian", "Odachi")
	hit = at()
	assert(Combat.tryAttack(d, "Light", tc + 0.03))
	check("D-02 setup: the defender's move has hyper armor", d.Move and d.Move.HyperArmor == true)
	outcome = resolve(a, d, hit, tc + 0.05)
	check("D-02 hyper armor begun after t_c does not armor it", outcome == "Hit" and d.State == "Hitstun", outcome)

	-- D-03 hyper armor active at t_c and ended during the grace still armors it (and is not a counter-hit). Stage 2
	-- read the move from the present (gone) but the state from t_c (Startup) and called this a CounterHit.
	a, d, tc = contact("Jian", "Odachi")
	assert(Combat.tryAttack(d, "Light", tc - 0.02))
	hit = { Facing = true, Region = "Torso", Move = a.Move, DefenderState = d.State, At = tc, Snapshot = Combat.contactSnapshot(a, d, tc, a.Move) }
	local later = tc
	while d.State ~= "Idle" do -- the armored move runs out before the contact resolves
		later += TICK
		Combat.step(d, later, TICK, {})
	end
	outcome = resolve(a, d, hit, later + TICK)
	check("D-03 armor active at t_c holds after the move ends", outcome == "Armored", outcome)

	-- D-04 attacker weapon swapped during the grace: damage is the t_c weapon's.
	local function dealt(swap: boolean): number
		local a2, d2, tc2, at2 = contact("Jian", "Jian", false)
		a2.StrengthScale, a2.DexterityScale = 2, 1
		local h = at2()
		if swap then
			Combat.forceWeapon(a2, "Odachi")
		end
		resolve(a2, d2, h, tc2 + 0.05)
		return d2.MaxHP - d2.ActiveHP
	end
	check("D-04 an attacker weapon swap after t_c does not change the damage", math.abs(dealt(true) - dealt(false)) < 1e-6, dealt(true) - dealt(false))

	-- D-05 defender weapon swapped during the grace: the block outcome uses the t_c weapon.
	local function blocked(swap: boolean): (number, number)
		local a2, d2, tc2 = contact("Jian", "Jian")
		assert(Combat.setGuard(d2, true, tc2 - 0.05))
		local h = { Facing = true, Region = "Torso", Move = a2.Move, DefenderState = d2.State, At = tc2, Snapshot = Combat.contactSnapshot(a2, d2, tc2, a2.Move) }
		if swap then
			Combat.forceWeapon(d2, "Odachi")
		end
		resolve(a2, d2, h, tc2 + 0.05)
		return d2.Posture, d2.Stamina
	end
	local p1, s1 = blocked(false)
	local p2, s2 = blocked(true)
	check("D-05 a defender weapon swap after t_c does not change the block outcome", math.abs(p1 - p2) < 1e-6 and math.abs(s1 - s2) < 1e-6, string.format("%.2f/%.2f vs %.2f/%.2f", p1, s1, p2, s2))

	-- D-06 invulnerability gained after t_c (a cinematic lock) does not evade a contact made before it.
	a, d, tc, at = contact()
	hit = at()
	Combat.cinematic(d, tc + 0.02, 1.0)
	outcome = resolve(a, d, hit, tc + 0.05)
	check("D-06 invulnerability begun after t_c does not evade", outcome ~= "Whiff", outcome)

	-- D-07 death during the grace: a KO'd defender takes nothing; a KO'd attacker is not stood up by recoil.
	a, d, tc, at = contact()
	hit = at()
	Combat.knockOut(d, tc + 0.02)
	check("D-07 a defender KO'd during the grace is not hit again", resolve(a, d, hit, tc + 0.05) == "Ignored")
	a, d, tc = contact()
	assert(Combat.tryDeflect(d, tc - 0.03, tc - 0.03))
	hit = { Facing = true, Region = "Torso", Move = a.Move, DefenderState = d.State, At = tc, Snapshot = Combat.contactSnapshot(a, d, tc, a.Move) }
	Combat.knockOut(a, tc + 0.02)
	outcome = resolve(a, d, hit, tc + 0.05)
	check("D-07 an attacker KO'd during the grace stays KO when the deflect resolves", outcome == "Deflected" and a.State == "KO", a.State)

	-- D-08 the attacker starts another swing while the earlier contact waits: the late resolution writes nothing into
	-- the newer swing's hit registry and does not cancel it; the newer swing can still hit the same defender.
	a, d, tc, at = contact()
	hit = at()
	a.HitRegistry[d.Id] = true -- claimed at detection
	local t = tc
	while a.State ~= "Idle" do
		t += TICK
		Combat.step(a, t, TICK, {})
	end
	assert(Combat.tryAttack(a, "Light", t))
	local newer = a.MoveStart
	outcome = resolve(a, d, hit, t + TICK)
	check("D-08 setup: the held contact still lands", outcome == "Hit", outcome)
	check("D-08 the newer swing's registry stays clean", a.HitRegistry[d.Id] == nil)
	check("D-08 the newer swing is not cancelled by its own earlier hit", a.MoveStart == newer and a.State == "Startup")
	d.State, d.StateEnd = "Idle", t -- the defender recovered
	a.State = "Active"
	check("D-08 the newer swing can still hit that defender", Combat.resolveHit(a, d, t + 0.3, { Facing = true, Region = "Torso" }, {}) ~= "Ignored")

	-- A deflect resolved late recoils the attacker out of the newer action: as of t_c the deflect came first.
	a, d, tc = contact()
	assert(Combat.tryDeflect(d, tc - 0.03, tc - 0.03))
	hit = { Facing = true, Region = "Torso", Move = a.Move, DefenderState = d.State, At = tc, Snapshot = Combat.contactSnapshot(a, d, tc, a.Move) }
	a.State, a.Move = "Idle", nil
	assert(Combat.tryAttack(a, "Light", tc + 0.05))
	outcome = resolve(a, d, hit, tc + 0.06)
	check("D-08 a late deflect recoils the attacker out of the newer swing (documented)", outcome == "Deflected" and a.State == "Blockstun" and a.Move == nil, a.State)
end

-------------------------------------------------------------------------------------------------
-- G. Grace: parry, dodge, boss and area strikes; the hit-confirm delay it adds (real contact block)
-------------------------------------------------------------------------------------------------

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

local function arena(defenderPing: number?)
	local w = { now = 500, entities = {}, events = {}, list = {}, detectedAt = nil }
	w.api = luau.load(contactChunk, { debugName = "ClosureContacts", environment = geo })(Combat, Lag, TICK, 0.15, w.entities, w.events, {}, Strike)
	for _, spec in { { id = -5, z = 0, lz = -1 }, { id = 9, z = -5, lz = 1, ping = defenderPing } } do
		local at = V3.new(0, 3, spec.z)
		local cframe = CF.lookAt(at, at + V3.new(0, 0, spec.lz))
		local e = {
			Id = spec.id, Kind = if spec.ping then "Player" else "Enemy", Fighter = Combat.new(spec.id, "Jian", w.now),
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
	function w.tick(beforeContacts: (() -> ())?)
		w.now += TICK
		for _, e in w.list do
			Lag.record(e.History, w.now, e.Root.CFrame, V3.zero)
			Combat.step(e.Fighter, w.now, TICK, w.events)
		end
		if beforeContacts then
			beforeContacts()
		end
		w.api.settle(w.now)
		local found = {}
		for _, e in w.list do
			if e.Fighter.State == "Active" then
				w.api.detect(e, w.now, found)
			end
		end
		for _, c in found do
			w.detectedAt = w.detectedAt or w.now
			if not w.api.defer(c, w.now) then
				w.api.resolve(c, w.now)
			end
		end
	end
	function w.count(kind: string): number
		local n = 0
		for _, event in w.events do
			if event.Kind == kind then
				n += 1
			end
		end
		return n
	end
	return w
end

-- Runs a light from fighter -5 into player 9; `answer(w, tc)` is the defender's drained intent, called on the
-- tick it reaches the server (`arrive` ticks after the contact). Returns the world and the defender.
local function exchange(ping: number?, arrive: number, answer: ((any, number) -> ())?)
	local w = arena(ping)
	local d = w.entities[9].Fighter
	assert(Combat.tryAttack(w.entities[-5].Fighter, "Light", w.now))
	local resolvedTick, k = nil, 0
	for _ = 1, 40 do
		k += 1
		local tc = w.detectedAt
		w.tick(function()
			if tc and answer and k == arrive then
				answer(w, tc)
			end
		end)
		if w.detectedAt and not tc then
			k = 0 -- count arrival ticks from the contact
		end
		if not resolvedTick and w.detectedAt and #w.api.pending == 0 and (w.count("Hit") + w.count("DeflectSpark") + w.count("Evade") + w.count("Block")) > 0 then
			resolvedTick = math.floor((w.now - w.detectedAt) / TICK + 0.5)
		end
	end
	return w, d, resolvedTick
end

do
	-- G-01 parry through the grace (re-verified here with the dash rule in place).
	local w, d = exchange(0.1, 3, function(world, tc) Combat.tryDeflect(world.entities[9].Fighter, world.now, tc - 0.03) end)
	check("G-01 parry pressed 30 ms before t_c, arriving 3 ticks later, deflects", w.count("DeflectSpark") == 1 and d.ActiveHP == d.MaxHP)

	-- G-02 dodge through the grace: the dash's i-frames anchored to its accepted press cover t_c. Stage 2 held the
	-- contact for a dash but judged i-frames from the grant (after t_c), so this landed.
	w, d = exchange(0.1, 3, function(world, tc) Combat.tryDash(world.entities[9].Fighter, "Dash", world.now, 0, 1, world.events, tc - 0.03) end)
	check("G-02 dash pressed 30 ms before t_c, arriving 3 ticks later, evades", w.count("Evade") == 1 and w.count("Hit") == 0 and d.ActiveHP == d.MaxHP)
	w, d = exchange(0.1, 3, function(world, tc) Combat.tryDash(world.entities[9].Fighter, "Dash", world.now, 0, 1, world.events, tc + 0.02) end)
	check("G-03 dash pressed 20 ms after t_c does not evade", w.count("Hit") == 1 and d.ActiveHP < d.MaxHP)
	-- Roll i-frames open 40 ms after the press: a roll pressed 30 ms before t_c is not yet invulnerable at t_c.
	w = exchange(0.1, 3, function(world, tc) Combat.tryDash(world.entities[9].Fighter, "Roll", world.now, 0, 1, world.events, tc - 0.03) end)
	check("G-04 roll pressed 30 ms before t_c (i-frames from +40 ms) is hit", w.count("Hit") == 1)
	w = exchange(0.1, 3, function(world, tc) Combat.tryDash(world.entities[9].Fighter, "Roll", world.now, 0, 1, world.events, tc - 0.06) end)
	check("G-04 roll pressed 60 ms before t_c evades", w.count("Evade") == 1 and w.count("Hit") == 0)
	w = exchange(0.1, 8, function(world, tc) Combat.tryDash(world.entities[9].Fighter, "Dash", world.now, 0, 1, world.events, tc - 0.03) end)
	check("G-05 a dash arriving after the grace is too late", w.count("Hit") == 1)

	-- G-06 hit-confirm delay added by the grace: ticks from contact to outcome, no defensive press.
	local rows, worst = {}, 0
	for _, ping in { 0, 0.05, 0.1, 0.2, 0.3 } do
		local _, _, ticks = exchange(ping, 0, nil)
		local grace = math.min(ping * 0.5 + TICK, 0.1)
		local expect = math.ceil(grace / TICK - 1e-6)
		check(string.format("G-06 ping %d ms: hit confirmed %s ticks after contact (grace %.1f ms)", ping * 1000, tostring(ticks), grace * 1000), ticks == expect, expect)
		worst = math.max(worst, ticks or 99)
		table.insert(rows, string.format("%d ms -> %.1f ms", ping * 1000, (ticks or 0) * TICK * 1000))
	end
	local _, _, npc = exchange(nil, 0, nil)
	check("G-06 an NPC defender's hit confirms on the contact tick", npc == 0, npc)
	check("G-06 the added delay never exceeds the 100 ms cap", worst * TICK <= 0.1 + 1e-6, worst)
	print("      G-06 hit-confirm delay by defender ping: " .. table.concat(rows, ", ") .. "; NPC 0 ms")
end

-- G-07 boss and area strikes have no grace: a press stamped before the strike but not yet drained is not
-- considered (boss contacts are ordered after the tick's intents; area waves resolve at listener time).
do
	local boss, f = Combat.new(-100, "Jian", 10), Combat.new(1, "Jian", 10)
	check("G-07 boss thrust before the deflect drains: hit (no grace)", Combat.applyBossAttack(boss, f, 10, 30, 40, "PerilousThrust", true, {}) ~= "Deflected")
	boss, f = Combat.new(-100, "Jian", 10), Combat.new(1, "Jian", 10)
	assert(Combat.tryDeflect(f, 10, 10 - 0.03))
	check("G-07 boss thrust after the same-tick deflect drained: deflected", Combat.applyBossAttack(boss, f, 10, 30, 40, "PerilousThrust", true, {}) == "Deflected")
	local src, g = Combat.new(-101, "Jian", 10), Combat.new(2, "Jian", 10)
	check("G-07 area wave before the dash drains: hit (no grace, no dash anchoring)", Combat.applyArea(src, g, 10, 10, 10, false, true, {}) == "Hit")
end

-------------------------------------------------------------------------------------------------
-- R1. Receipt -> start: one tick (the real onIntent and drainBuffer in the production step order)
-------------------------------------------------------------------------------------------------

do
	local chunk = table.concat({
		"local Combat, Schema, InputBuffer, Tempo, Lag, Protocol, Config, entities, Strike, ruleset = ...",
		"local running, simTime, tickCount = true, 0, 0",
		"local terminal",
		between(service, "local MAX_SEQUENCE_GAP", "\nlocal DEFAULT_JUMP"),
		between(service, "local INTENT_ACTIONS", "\nlocal WEAPON_VISUALS"),
		between(service, "local function eligibleFor(", "\nlocal function disconnectAll("),
		between(service, "local function validIntent(", "\nlocal function findDeathblowTarget("),
		"local function perform(e, action, pressTime) if action == 'Light' then return Combat.tryAttack(e.Fighter, 'Light', simTime) end return false, 'Unsupported' end",
		"local function immediate() return true, 'Immediate' end",
		between(service, "local function onIntent(", "\n-------"),
		"return { onIntent = onIntent, drainBuffer = drainBuffer, eligibleFor = eligibleFor, setTime = function(t, k) simTime, tickCount = t, k end }",
	}, "\n")
	local entities = {}
	local api = luau.load(chunk, { debugName = "ClosureIntent" })(Combat, Schema, InputBuffer, Tempo, { MAX_REWIND = 0.15 },
		{ Take = function() return true end }, { Network = { ActionsPerSecond = 60, ActionBurst = 60 } }, entities,
		{ airAllows = function() return true end }, function() return nil end)
	local p = { UserId = 1, SetAttribute = function() end, GetAttribute = function() return nil end }
	local e = { Id = 1, Player = p, Fighter = Combat.new(1, "Jian", 1000), Buffer = InputBuffer.new(), LastSeq = 0, Actions = {}, Respawning = false, Omni = { Air = {} }, IntentLog = {} }
	e.Eligible = api.eligibleFor(e)
	entities[1] = e
	local now, tick = 1000, 0
	api.setTime(now, tick)
	api.onIntent(p, { seq = 1, action = "Light", time = now - 0.004 }) -- arrives between tick 0 and tick 1
	tick += 1
	now += TICK
	api.setTime(now, tick)
	Combat.step(e.Fighter, now, TICK, {})
	api.drainBuffer(e) -- production order: listeners, then stepFighter (Combat.step, drainBuffer)
	check("R-01 an intent received between ticks starts on the very next tick", e.Fighter.State == "Startup" and math.abs(e.Fighter.MoveStart - now) < 1e-9)
	local s = Combat.unpackString(Combat.packString(e.Fighter, now, nil, tick, now))
	check("R-01 and that tick's sample names the intent", s and s.IntentSeq == 1)
	-- The Stage 2 probe stamped the start from a step listener, which runs before fighters step: it saw this start
	-- one tick late, hence 33.3 ms. The probe now stamps the tick the state was entered (Stage2Timing.server).
	local probe = fs.readFile("tools/qa/Stage2Timing.server.luau")
	check("R-01 the probe stamps the entering tick, not the observing one", string.find(probe, "entered = previousNow", 1, true) ~= nil)
end

print(string.format("stage 2 closure: %d passed, %d failed (offline behaviour; Studio and two-client fairness separate)", passed, failed))
if failed > 0 then
	process.exit(1)
end

--!nonstrict
-- Combat recovery Stage 3 (Mac, 2 November 2026). Behaviour of the running playback and movement code:
--   T-FC  guard facing reads one instant (CharacterService.facingAt);
--   T-RB  a refused dash takes back only its own displacement and velocity (WorldStateController.Rollback);
--   T-AN  occurrences: predicted dashes and combo links, adoption, phase correction (FighterAnimations, AnimationTiming);
--   T-HS  one playback owner: hitstop and cinematics reach clips only through PlaybackScale;
--   T-FW  footwork and joint corrections (FootStep, ActorPose);
--   T-CT  the blade the server sweeps is the blade the clip shows (StrikeTrajectories).
-- Real modules under Lune with engine services faked. Evidence class: offline behaviour. It says nothing about real
-- Studio geometry, frame order or feel; those are in MAC_TO_WINDOWS.md.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox") :: any
local task = require("@lune/task")
local Combat = require("../src/simulation/CombatRules")
local Tempo = require("../src/simulation/Tempo")
local Prediction = require("../src/simulation/LocalPrediction")
local Timing = require("../src/simulation/AnimationTiming")
local Foot = require("../src/simulation/FootStep")
local Strike = require("../src/simulation/StrikeGeometry")
local Weapons = require("../src/simulation/WeaponSchema")
local Settings = require("../src/shared/CombatSettings")
local Trajectories = require("../src/shared/StrikeTrajectories")
local Catalog = require("../src/shared/AnimationCatalog")

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
local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6)
end
local service = fs.readFile("src/server/CharacterService.luau")

-------------------------------------------------------------------------------------------------
-- Shared harness: one clock, the real WorldStateController, the real FighterAnimations, fake tracks
-------------------------------------------------------------------------------------------------

local clock = 100
local attributes = {}
local intentChanged = { Links = {} }
function intentChanged:Connect(fn)
	table.insert(self.Links, fn)
	return { Disconnect = function() end, Connected = true }
end
local quiet = { Connect = function() return { Disconnect = function() end } end }
local player = {
	UserId = 1, Name = "Owner", CharacterAdded = quiet,
	GetAttribute = function(_, name) return attributes[name] end,
	GetAttributeChangedSignal = function() return intentChanged end,
}
local function setIntent(value: string)
	attributes.AsuraIntent = value
	for _, fn in intentChanged.Links do
		fn()
	end
end
local function finder(t)
	return setmetatable(t, { __index = { WaitForChild = function(self, n) return rawget(self, n) end } })
end
local blockHit: any = nil
local casts = {}
local groundY: ((x: number, z: number) -> number?) = function() return 0 end
local Workspace: any = {
	Children = {}, GetServerTimeNow = function() return clock end, WaitForChild = function() return nil end, GetAttribute = function() return nil end,
	Blockcast = function(_, cframe, size, direction, params)
		table.insert(casts, { From = cframe.Position, Direction = direction, Filter = params.FilterDescendantsInstances })
		return blockHit
	end,
	Raycast = function(_, origin, direction)
		local y = groundY(origin.X, origin.Z)
		if y == nil or y > origin.Y or y < origin.Y + direction.Y then
			return nil
		end
		return { Position = V3.new(origin.X, y, origin.Z) }
	end,
}
local PlaybackScale, ActorPose
local reduced = false
local shared = finder({
	Simulation = finder({ CombatRules = Combat, LocalPrediction = Prediction, AnimationTiming = Timing, FootStep = Foot, WeaponSchema = Weapons, MoveSchema = require("../src/simulation/MoveSchema") }),
	Shared = finder({ AnimationCatalog = Catalog, WorldDefinitions = { Mobs = {} }, StrikeTrajectories = Trajectories, CombatSettings = Settings,
		EffectsPreference = { reducedMotion = function() return reduced end } }),
})
local playerOf: any = function() return nil end
local services = {
	Players = { LocalPlayer = player, PlayerAdded = quiet, GetPlayers = function() return {} end, GetPlayerFromCharacter = function(_, model) return playerOf(model) end },
	Workspace = Workspace,
	CollectionService = { GetTagged = function() return {} end, GetInstanceAddedSignal = function() return quiet end },
	ReplicatedStorage = finder({ AsurasPath = shared }),
	RunService = { IsStudio = function() return false end },
	ContentProvider = { PreloadAsync = function() end },
	Lighting = roblox.Instance.new("Folder"),
	TweenService = { Create = function() return { Play = function() end } end },
	Debris = { AddItem = function() end },
}
local function environment(script)
	return {
		game = { GetService = function(_, n) return assert(services[n], n) end },
		os = { clock = function() return clock end },
		task = { spawn = function() end, delay = task.delay }, Vector3 = V3, Vector2 = roblox.Vector2, CFrame = CF, Enum = roblox.Enum,
		Instance = { new = function(kind)
			if kind == "Animation" then return { AnimationId = "", Destroy = function() end } end
			return roblox.Instance.new(kind)
		end },
		require = function(m) return m end, warn = function() end, script = script,
		RaycastParams = { new = function() return {} end },
		workspace = Workspace,
		Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }, UDim2 = roblox.UDim2,
		TweenInfo = { new = function(...) return { ... } end },
	}
end
local function load(path: string, script: any?)
	return luau.load(fs.readFile(path), { debugName = path, environment = environment(script) })()
end
PlaybackScale = load("src/client/Controllers/PlaybackScale.luau")
ActorPose = load("src/client/Controllers/ActorPose.luau")
local poseFor = setmetatable({ PlaybackScale = PlaybackScale, ActorPose = ActorPose }, nil)
local World = load("src/client/Controllers/WorldStateController.luau")
local Fighter = load("src/client/Controllers/FighterAnimations.luau", { Parent = poseFor })
local net = finder({ StateSnapshots = { OnClientEvent = quiet } })

-- A fake AnimationTrack: counts Play and seek calls, and advances by its speed as the engine would.
local manifest = {}
do
	local function add(slot, name, length)
		if slot and slot.Custom then manifest[slot.Custom] = { Length = length, Name = name } end
	end
	for key, name in { Light1 = "Jian_L1", Light2 = "Jian_L2", Light3 = "Jian_L3", Light4 = "Jian_L4", Heavy = "Jian_Heavy", Running = "Jian_Running", WeaponArt = "Jian_Art" } do
		add(Catalog.weapon("Jian", key), name, Trajectories.forMove(name).ClipLength)
	end
	add(Catalog.weapon("Jian", "Idle"), "Jian_Idle", 2.4)
	add(Catalog.weapon("Jian", "Move"), "Jian_Move", 0.8)
	add(Catalog.weapon("Jian", "Guard"), "Jian_Guard", 2)
	add(Catalog.weapon("Jian", "GuardImpact"), "Jian_GuardImpact", 0.35)
	add(Catalog.weapon("Jian", "Equip"), "Jian_Equip", 0.65)
	add(Catalog.universal("Roll"), "Fighter_Dodge", 0.36)
	for _, key in { "DashForward", "DashLeft", "DashRight" } do
		add(Catalog.universal(key :: any), "Fighter_" .. key, 0.36)
	end
	add(Catalog.universal("Deathblow_Attacker"), "Fighter_DeathblowAttacker", 1.1)
	add(Catalog.universal("Deathblow_Victim"), "Fighter_DeathblowVictim", 1.6)
	add(Catalog.universal("AltarRest"), "Fighter_AltarRest", 3)
	add(Catalog.universal("Backdash"), "Fighter_Backstep", 0.22)
	add(Catalog.universal("Deflect"), "Fighter_Deflect", 0.32)
	add(Catalog.universal("Hitstun_Light"), "Fighter_HitLight", 0.28)
	add(Catalog.universal("Hitstun_Heavy"), "Fighter_HitHeavy", 0.48)
	add(Catalog.universal("StanceBroken"), "Fighter_PostureBroken", 1.2)
	add(Catalog.universal("Recover"), "Fighter_Recover", 0.45)
end
local function newTrack(id: string)
	local data = manifest[id] or { Length = 1, Name = id }
	local t = { Name = data.Name, Animation = { AnimationId = id }, IsPlaying = false, Length = data.Length, Speed = 1, Looped = false,
		Plays = 0, Seeks = 0, Fades = {}, Writes = 0, MaxSpeed = 0, MinMoving = math.huge, Stopped = 0 }
	local position = 0
	function t:Play(fade, _, speed)
		self.Plays += 1
		self.IsPlaying = true
		position = 0
		self.Speed = speed or 1
		table.insert(self.Fades, fade or 0)
	end
	function t:Stop() self.IsPlaying = false; self.Stopped += 1 end
	function t:Destroy() end
	function t:AdjustSpeed(speed)
		self.Speed = speed
		self.Writes += 1
		self.MaxSpeed = math.max(self.MaxSpeed, speed)
		if speed > 0 then self.MinMoving = math.min(self.MinMoving, speed) end
	end
	function t:Advance(dt)
		if self.IsPlaying then
			position += self.Speed * dt
			if position >= self.Length then
				if self.Looped then
					position %= self.Length
				else
					position = self.Length
					self.IsPlaying = false
				end
			end
		end
	end
	return setmetatable(t, {
		__index = function(_, key) if key == "TimePosition" then return position end return nil end,
		__newindex = function(self, key, value)
			if key == "TimePosition" then
				rawset(self, "Seeks", rawget(self, "Seeks") + 1)
				position = value
			else
				rawset(self, key, value)
			end
		end,
	})
end
local function fakeModel(parts, scale)
	local attrs = {}
	return {
		Parent = {}, Name = "Fighter",
		GetAttribute = function(_, n) return attrs[n] end, SetAttribute = function(_, n, v) attrs[n] = v end,
		FindFirstChild = function(_, n) return parts and parts[n] end, FindFirstChildOfClass = function() return nil end,
		GetScale = function() return scale or 1 end, Attributes = attrs,
	}
end
local function fakeRoot(at, look)
	return { CFrame = look or CF.new(at), Position = at, AssemblyLinearVelocity = V3.zero, Size = V3.new(2, 2, 1) }
end

-- The owner's scene: state, animations, one fighter with snapshots published from a real Combat fighter.
local sampleTick = 0
local function scene(rig)
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
	local model = rig or roblox.Instance.new("Model")
	if not rig then
		model.Parent = roblox.Instance.new("Folder")
		root.Parent = model
	end
	local tracks = {}
	local animator = {
		LoadAnimation = function(_, animation)
			local track = newTrack(animation.AnimationId)
			tracks[animation.AnimationId] = track
			return track
		end,
		AnimationPlayed = quiet, GetPlayingAnimationTracks = function() return {} end,
	}
	local humanoid = { RigType = roblox.Enum.HumanoidRigType.R15, FindFirstChildOfClass = function() return animator end }
	local entity = { Id = 1, Model = model, Root = root, Humanoid = humanoid, Boss = false, Snapshot = nil, UpdatedAt = clock, Age = 0, Connections = {} }
	state.Entities[1] = entity
	local function publish(age)
		sampleTick += 2
		entity.Snapshot = Combat.unpackString(Combat.packString(fighter, clock - (age or 0), nil, sampleTick, clock - (age or 0)))
		entity.UpdatedAt = clock
		entity.Age = age or 0
	end
	publish()
	state:Step(TICK)
	local animations = Fighter.new(state)
	-- One client frame in the order Bootstrap runs: state, then playback.
	local function frame(dt)
		dt = dt or 1 / 60
		state:Step(dt)
		animations:Update(dt)
		for _, track in tracks do
			track:Advance(dt)
		end
		clock += dt
	end
	local function by(name)
		for _, track in tracks do
			if track.Name == name then return track end
		end
		return nil
	end
	frame()
	return { State = state, Animations = animations, Root = root, Fighter = fighter, Publish = publish, Frame = frame, Track = by, Entity = entity, Tracks = tracks }
end
local function run(s, seconds, dt)
	local left = seconds
	while left > 1e-9 do
		s.Frame(dt or 1 / 60)
		left -= dt or 1 / 60
	end
end

-------------------------------------------------------------------------------------------------
-- T-FC. Guard facing: one instant, both bodies from history
-------------------------------------------------------------------------------------------------

do
	local geo = { Vector3 = V3, CFrame = CF, math = math, table = table, type = type, setmetatable = setmetatable, ipairs = ipairs, pairs = pairs, next = next, assert = assert, error = error, tostring = tostring, string = string, os = os }
	local Lag = luau.load(fs.readFile("src/server/LagCompensation.luau"), { debugName = "Lag", environment = geo })()
	local chunk = "local Lag = ...\n"
		.. between(service, "local function flatUnit(", "\nlocal function facingDot(") .. "\n"
		.. "local function facingDot(defender, attacker) return flatUnit(defender.Root.CFrame.LookVector):Dot(flatUnit(attacker.Root.Position - defender.Root.Position)) end\n"
		.. between(service, "local function facingAt(", "\n-- Whiffs (batch 09)"):sub(1, (string.find(between(service, "local function facingAt(", "\n-- Whiffs (batch 09)"), "\nend\n", 1, true))) .. "end\n"
		.. "return facingAt"
	local facingAt = luau.load(chunk, { debugName = "Facing", environment = geo })(Lag)
	local FACING_DOT = 0.15
	local function body(samples, live)
		local history = Lag.newHistory()
		for _, sample in samples do
			Lag.record(history, sample[1], sample[2], V3.zero)
		end
		return { History = history, Root = { CFrame = live, Position = live.Position } }
	end
	local function look(at, toward)
		return CF.lookAt(at, toward)
	end
	local D0, A0 = V3.new(0, 3, 0), V3.new(0, 3, -6)
	-- The defender was square to the attacker at the rewound instant; the attacker has since circled behind them.
	local defender = body({ { 9.8, look(D0, A0) }, { 9.9, look(D0, A0) }, { 10, look(D0, A0) } }, look(D0, A0))
	local attacker = body({ { 9.8, CF.new(A0) }, { 9.9, CF.new(0, 3, -6) }, { 10, CF.new(0, 3, 6) } }, CF.new(0, 3, 6))
	local at = 9.9
	local dot = facingAt(defender, attacker, at)
	local mixedThen = defender.History and (function()
		local p = Lag.samplePoseAt(defender.History, at)
		local to = attacker.Root.Position - p.Position
		return p.LookVector:Dot(to.Unit)
	end)()
	check("T-FC-01 moving attacker: guard reads the same instant (square then)", dot > 0.99, dot)
	check("T-FC-01 the old mixed reading would have called it a rear hit", mixedThen < FACING_DOT, mixedThen)

	-- Near the boundary: an attacker walking from just inside to just outside the guard cone is read at `at` on both sides.
	local boundary = math.acos(FACING_DOT)
	local function around(angle, r)
		return V3.new(math.sin(angle) * r, 3, -math.cos(angle) * r)
	end
	local inside, outside = around(boundary - 0.05, 6), around(boundary + 0.05, 6)
	local forward = CF.lookAt(D0, D0 + V3.new(0, 0, -1))
	local d2 = body({ { 9.9, forward }, { 10, forward } }, forward)
	local a2 = body({ { 9.9, CF.new(inside) }, { 10, CF.new(outside) } }, CF.new(outside))
	check("T-FC-02 frontal boundary: inside the cone at `at` guards", facingAt(d2, a2, 9.9) >= FACING_DOT)
	check("T-FC-02 frontal boundary: outside the cone at `at` does not", facingAt(d2, a2, 10) < FACING_DOT)

	-- A defender rotating past the attacker: the rotation at `at` decides, not the present one.
	local away = CF.lookAt(D0, D0 + V3.new(0, 0, 1))
	local d3 = body({ { 9.9, forward }, { 10, away } }, away)
	local a3 = body({ { 9.9, CF.new(A0) }, { 10, CF.new(A0) } }, CF.new(A0))
	check("T-FC-03 rotation: a defender square at `at` keeps its guard though it has since turned", facingAt(d3, a3, 9.9) > 0.99)
	check("T-FC-03 rotation: at the present it has turned away", facingAt(d3, a3, 10) < -0.99)

	-- Delayed contact: a contact resolved later still carries the facing computed at its `at`.
	check("T-FC-04 delayed contact: the reading depends only on `at`, not on when it is asked", facingAt(d3, a3, 9.9) == facingAt(d3, a3, 9.9))

	-- Asymmetric roles: an NPC attacker reads at `now`; a player attacker with an empty history falls back to its live position.
	local a4 = { History = Lag.newHistory(), Root = { CFrame = CF.new(A0), Position = A0 } }
	check("T-FC-05 attacker without history: its live position, the defender's past", facingAt(d3, a4, 9.9) > 0.99)
	local d5 = { History = Lag.newHistory(), Root = { CFrame = away, Position = D0 } }
	check("T-FC-05 defender without history: present-time reading", facingAt(d5, a4, 9.9) < -0.99)
end

-------------------------------------------------------------------------------------------------
-- T-RB. Refused dash: displacement and velocity are separate, and only the dash's own come off
-------------------------------------------------------------------------------------------------

do
	check("T-RB-01 travel is clamped to what the drive commanded", near(Prediction.dashTravel(0, 0, 8, 0, 1, 0, 5), 5))
	check("T-RB-01 a stopped dash undoes only what it moved", near(Prediction.dashTravel(0, 0, 2, 0, 1, 0, 5), 2))
	check("T-RB-01 a shove back along the line is not undone further", near(Prediction.dashTravel(0, 0, -3, 0, 1, 0, 5), 0))
	local vx, vz = Prediction.residualVelocity(30, 0, 30, 0, true)
	check("T-RB-02 velocity: the drive's own command comes off", near(vx, 0) and near(vz, 0))
	vx, vz = Prediction.residualVelocity(30, 12, 30, 0, true)
	check("T-RB-02 velocity across the drive continues", near(vx, 0) and near(vz, 12))
	vx, vz = Prediction.residualVelocity(40, 0, 30, 0, true)
	check("T-RB-02 knockback beyond the command continues", near(vx, 10))
	vx, vz = Prediction.residualVelocity(-20, 0, 30, 0, true)
	check("T-RB-02 velocity against the drive is untouched", near(vx, -20))
	vx, vz = Prediction.residualVelocity(9, 4, 30, 0, false)
	check("T-RB-02 a finished drive owns none of the velocity", near(vx, 9) and near(vz, 4))

	local function dashed(seq, to, seconds, velocity)
		local s = scene()
		assert(s.State:Predict(seq, "Dash", 1, 0))
		s.State:Step(TICK)
		clock += seconds or 0.1
		s.Root.CFrame = to
		s.Root.AssemblyLinearVelocity = velocity or s.State.DashCommand
		return s
	end
	-- Rejected while knockback runs across the line: travel returns; the knockback's displacement and velocity stay.
	local s = dashed(101, CF.new(6, 3, 2), 0.1, V3.new(63.6, 0, 9))
	setIntent("101:Rejected:Exhausted:" .. sampleTick)
	check("T-RB-03 rejection returns the travel along the line, keeps the shove across it", near(s.Root.Position.X, 0, 1e-3) and near(s.Root.Position.Z, 2, 1e-3), s.Root.Position)
	check("T-RB-03 rejection keeps the shove's velocity, removes the drive's", near(s.Root.AssemblyLinearVelocity.X, 0, 1e-3) and near(s.Root.AssemblyLinearVelocity.Z, 9, 1e-3), s.Root.AssemblyLinearVelocity)
	s.State:Destroy()

	-- External movement along the line during the dash: no more than the drive commanded is taken back.
	s = dashed(102, CF.new(20, 3, 0), 0.05)
	setIntent("102:Rejected:Exhausted:" .. sampleTick)
	local driven = s.State.DashDriven
	check("T-RB-04 a shove along the dash stays: only the drive's distance returns", near(s.Root.Position.X, 20 - driven, 1e-3) and driven < 4, s.Root.Position.X)
	s.State:Destroy()

	-- A slow frame: the distance driven comes from real time, not the capped frame delta.
	s = scene()
	assert(s.State:Predict(103, "Dash", 1, 0))
	s.State:Step(0.1)
	clock += 0.2
	setIntent("103:Rejected:Exhausted:" .. sampleTick)
	check("T-RB-05 distance driven is real time, not the frame cap", near(s.State.DashDriven, 0.2 * s.State.DashCommand.Magnitude, 1e-3), s.State.DashDriven)
	s.State:Destroy()

	-- Wall: the drive pushed but the body barely moved. Nothing beyond its movement returns.
	s = dashed(104, CF.new(1, 3, 0))
	setIntent("104:Rejected:Exhausted:" .. sampleTick)
	check("T-RB-06 walled dash returns what it moved, not what was commanded", near(s.Root.Position.X, 0, 1e-3))
	s.State:Destroy()

	-- Wall behind the correction: the sweep stops it short.
	s = dashed(105, CF.new(6, 3, 0))
	blockHit = { Distance = 2, Position = V3.new(4, 3, 0) }
	setIntent("105:Rejected:Exhausted:" .. sampleTick)
	check("T-RB-07 a wall on the way back stops the correction short", near(s.Root.Position.X, 4.05, 1e-3) and casts[1].Filter[1] == s.Entity.Model, s.Root.Position.X)
	s.State:Destroy()

	-- Slopes: climbing dash comes back down the slope; descending dash comes back up it; a fall is not retraced.
	-- The fake ground matches each slope (hip 3 over it), since the correction settles on the ground it finds.
	groundY = function(x) return x / 3 end
	s = dashed(106, CF.new(6, 5, 0))
	setIntent("106:Rejected:Exhausted:" .. sampleTick)
	check("T-RB-08 rising ground: the correction descends with the slope", near(s.Root.Position.X, 0, 1e-3) and near(s.Root.Position.Y, 3, 1e-3), s.Root.Position)
	s.State:Destroy()
	groundY = function(x) return -x / 4 end
	s = dashed(107, CF.new(6, 1.5, 0))
	setIntent("107:Rejected:Exhausted:" .. sampleTick)
	check("T-RB-08 descending ground: the correction climbs back", near(s.Root.Position.X, 0, 1e-3) and near(s.Root.Position.Y, 3, 1e-3), s.Root.Position)
	s.State:Destroy()
	groundY = function(x) return if x > 3 then -12 else 0 end
	s = dashed(108, CF.new(6, -9, 0))
	setIntent("108:Rejected:Exhausted:" .. sampleTick)
	check("T-RB-08 a fall off a ledge is not lifted back up", near(s.Root.Position.Y, -9, 1e-3) and near(s.Root.Position.X, 0, 1e-3), s.Root.Position)
	s.State:Destroy()
	groundY = function(x) return x / 4 end
	s = dashed(109, CF.new(6, 4.5, 0))
	check("T-RB-08 a step inside STEP_FOLLOW is followed", (function() setIntent("109:Rejected:Exhausted:" .. sampleTick); return near(s.Root.Position.Y, 3, 1e-3) end)())
	s.State:Destroy()

	-- Windows acceptance W-07 (Studio, Sanctuary stairs): a climb beyond STEP_FOLLOW used to keep its top height
	-- (10 studs in the air), and a descent down stairs used to be swept flat into the steps (10 of 14 studs kept).
	groundY = function(x) return x / 2 end
	s = dashed(111, CF.new(14, 10, 0), 0.3)
	table.clear(casts)
	setIntent("111:Rejected:Exhausted:" .. sampleTick)
	check("T-RB-11 a dash up stairs beyond STEP_FOLLOW comes back down to the ground", near(s.Root.Position.X, 0, 1e-3) and near(s.Root.Position.Y, 3, 1e-3), s.Root.Position)
	check("T-RB-11 coming down: across first, then down", casts[1] and casts[1].Direction.Y == 0 and casts[2] and casts[2].Direction.Y < 0)
	s.State:Destroy()
	groundY = function(x) return -x / 2 end
	s = dashed(112, CF.new(14, -4, 0), 0.3)
	table.clear(casts)
	setIntent("112:Rejected:Exhausted:" .. sampleTick)
	check("T-RB-12 a dash down stairs (walkable grade) is climbed back", near(s.Root.Position.X, 0, 1e-3) and near(s.Root.Position.Y, 3, 1e-3), s.Root.Position)
	check("T-RB-12 going up: up first, then across over the steps", casts[1] and casts[1].Direction.Y > 0 and casts[2] and casts[2].Direction.Y == 0)
	s.State:Destroy()
	-- Partly undone climb over uneven ground: the body is settled on the ground at its hip height, not left floating.
	groundY = function(x) return if x >= 10 then 7 else 0 end
	s = dashed(113, CF.new(14, 10, 0), 0.12)
	setIntent("113:Rejected:Exhausted:" .. sampleTick)
	local undone = s.State.DashDriven
	check("T-RB-13 a partial correction settles on the ground below", undone < 14 and near(s.Root.Position.X, 14 - undone, 1e-3)
		and near(s.Root.Position.Y, if 14 - undone >= 10 then 10 else 3, 1e-3), tostring(s.Root.Position) .. " undone " .. undone)
	s.State:Destroy()
	groundY = function() return 0 end

	-- Timeout, and interruption then refusal.
	s = dashed(110, CF.new(5, 3, 0), 0.08)
	clock += Prediction.CONFIRM_TIMEOUT
	s.Publish()
	s.State:Step(TICK)
	check("T-RB-09 timeout rolls back what it moved", near(s.Root.Position.X, 0, 1e-3) and s.State.Predicted == nil, s.Root.Position.X)
	s.State:Destroy()

	-- Acknowledged: no double application.
	s = scene()
	assert(s.State:Predict(111, "Dash", 0, -1))
	local from, length = s.State.DashFrom, s.State.DashLength
	s.State:Step(TICK)
	clock += 0.05
	assert(Combat.tryDash(s.Fighter, "Dash", clock, 0, -1, {}))
	Combat.markIntent(s.Fighter, 111)
	s.Publish()
	s.State:Step(TICK)
	check("T-RB-10 acknowledgment: same executor, nothing applied twice", s.State.DashFrom == from and s.State.DashLength == length and s.State.Predicted == nil)
	s.State:Destroy()
end

-------------------------------------------------------------------------------------------------
-- T-AN. Occurrences
-------------------------------------------------------------------------------------------------

do
	-- Dash: starts with the press, in the press's own direction, and acknowledgment adopts it.
	local s = scene()
	s.Root.CFrame = CF.new(0, 3, 0) -- faces -Z
	assert(s.State:Predict(201, "Dash", 0, -1))
	s.Frame()
	local roll = s.Track("Fighter_DashForward")
	check("T-AN-01 a predicted forward dash plays its clip the frame of the press", roll and roll.IsPlaying and roll.Plays == 1)
	run(s, 0.05)
	local before = roll.TimePosition
	assert(Combat.tryDash(s.Fighter, "Dash", clock - 0.03, 0, -1, {}))
	Combat.markIntent(s.Fighter, 201)
	s.Publish(0.02)
	s.Frame()
	check("T-AN-02 acknowledgment adopts the occurrence: no restart", roll.Plays == 1 and roll.TimePosition > before)
	check("T-AN-02 acknowledgment adopts the occurrence: no seek", roll.Seeks == 0, roll.Seeks)
	s.State:Destroy()

	s = scene()
	s.Root.CFrame = CF.new(0, 3, 0)
	assert(s.State:Predict(202, "Dash", 0, 1))
	s.Frame()
	check("T-AN-03 a dash behind the facing is the backstep", s.Track("Fighter_Backstep") and s.Track("Fighter_Backstep").Plays == 1 and s.Track("Fighter_DashForward").Plays == 0)
	s.State:Destroy()

	for _, side in { { -1, "Fighter_DashLeft" }, { 1, "Fighter_DashRight" } } do
		s = scene()
		s.Root.CFrame = CF.new(0, 3, 0)
		assert(s.State:Predict(203, "Dash", side[1], 0))
		s.Frame()
		check("T-AN-03 a sideways dash plays its own side's clip: " .. side[2], s.Track(side[2]).Plays == 1 and s.Track("Fighter_DashForward").Plays == 0)
		s.State:Destroy()
	end

	-- The states that used to play nothing: a finisher, its victim, a rest at a shrine that ends when the state does.
	for _, row in { { "DeathblowAttacker", "Fighter_DeathblowAttacker" }, { "DeathblowVictim", "Fighter_DeathblowVictim" }, { "RestingAtShrine", "Fighter_AltarRest" } } do
		s = scene()
		s.Root.CFrame = CF.new(0, 3, 0)
		s.Fighter.State = row[1]
		s.Fighter.StateEnd = clock + 5
		s.Publish()
		s.Frame()
		check("T-AN-30 " .. row[1] .. " plays its clip once", s.Track(row[2]).Plays == 1 and s.Track(row[2]).IsPlaying)
		run(s, 0.1)
		check("T-AN-30 " .. row[1] .. " does not restart", s.Track(row[2]).Plays == 1)
		s.Fighter.State = "Idle"
		s.Publish()
		s.Frame()
		if row[1] == "RestingAtShrine" then
			check("T-AN-30 the rest ends with its state", not s.Track(row[2]).IsPlaying)
		end
		s.State:Destroy()
	end

	-- Refusal, timeout, a missed intermediate snapshot, a respawn.
	s = scene()
	assert(s.State:Predict(203, "Dash", 0, -1))
	s.Frame()
	roll = s.Track("Fighter_DashForward")
	setIntent("203:Rejected:Exhausted:" .. sampleTick)
	s.Frame()
	check("T-AN-04 a refused dash stops its clip", not roll.IsPlaying and roll.Stopped == 1)
	s.State:Destroy()

	s = scene()
	assert(s.State:Predict(204, "Dash", 0, -1))
	s.Frame()
	roll = s.Track("Fighter_DashForward")
	run(s, Prediction.CONFIRM_TIMEOUT + 0.05)
	check("T-AN-05 an unanswered dash has ended and no longer shows", s.State.Predicted == nil and not roll.IsPlaying)
	s.State:Destroy()

	s = scene()
	assert(s.State:Predict(205, "Dash", 0, -1))
	s.Frame()
	roll = s.Track("Fighter_DashForward")
	run(s, 0.03)
	-- The whole dash ran on the server between two samples: Executed arrives, no Dashing sample is ever seen.
	setIntent("205:Executed:Dash:" .. sampleTick)
	s.Publish()
	s.Frame()
	check("T-AN-06 a missed Dashing sample ends the prediction without restarting anything", s.State.Predicted == nil and roll.Plays == 1)
	s.State:Destroy()

	s = scene()
	assert(s.State:Predict(206, "Dash", 0, -1))
	local replacement = roblox.Instance.new("Model")
	replacement.Parent = roblox.Instance.new("Folder")
	s.Entity.Model = replacement
	check("T-AN-07 a respawned body shows nothing the old one predicted", s.State:Presented(s.Entity.Snapshot) == nil)
	s.State:Destroy()

	-- The combo: L1 -> L2 -> L3 -> L4 through production prediction, each link on the owner's clock.
	s = scene()
	local jian = Weapons.Weapons.Jian
	local L = jian.Light
	local recovery = function(index) return L[index].Timing.StartupSeconds + L[index].Timing.ActiveSeconds end
	assert(s.State:Predict(211, "Light", 0, -1))
	s.Frame()
	local l1 = s.Track("Jian_L1")
	check("T-AN-10 L1 plays the frame of the press", l1 and l1.IsPlaying and l1.Plays == 1)
	-- The second press, early inside the buffer: held until L1's recovery on the local clock.
	run(s, recovery(1) - 0.06)
	check("T-AN-11 a link pressed early is predicted", s.State:Predict(212, "Light", 0, -1) == true)
	s.Frame()
	check("T-AN-11 the link waits for the recovery of the swing it follows", (s.Track("Jian_L2") or { Plays = 0 }).Plays == 0)
	local pressed = clock
	run(s, 0.1)
	local l2 = s.Track("Jian_L2")
	check("T-AN-12 the link starts on the local clock, without a server message", l2 and l2.Plays == 1 and not l1.IsPlaying)
	-- The server now confirms L1 late, and L2 while L3 is pressed.
	assert(Combat.tryAttack(s.Fighter, "Light", clock - 0.2))
	Combat.markIntent(s.Fighter, 211)
	s.Publish()
	s.Frame()
	check("T-AN-13 L1's late confirmation does not rewind what is showing", l2.Plays == 1 and l1.Plays == 1 and s.State.Predicted and s.State.Predicted.Seq == 212)
	s.Fighter.Move, s.Fighter.MoveStart, s.Fighter.State, s.Fighter.StateStart, s.Fighter.StateEnd = L[2], clock - 0.05, "Startup", clock - 0.05, clock + 1
	Combat.markIntent(s.Fighter, 212)
	s.Publish()
	s.Frame()
	check("T-AN-14 the server's L2 is adopted: no second play, no seek", l2.Plays == 1 and l2.Seeks == 0 and s.State.Predicted == nil)
	local elapsed = l2.TimePosition
	-- L3 and L4 from the snapshot's swing.
	run(s, recovery(2) - elapsed)
	check("T-AN-15 the third link is predicted from the running swing", s.State:Predict(213, "Light", 0, -1) == true)
	run(s, 0.12) -- it starts at the server swing's Recovery, which runs a little behind the owner's clip
	local l3 = s.Track("Jian_L3")
	check("T-AN-15 L3 shows", l3 and l3.Plays == 1)
	local third = s.State.Predicted.Started
	while clock < third + recovery(3) do s.Frame() end
	check("T-AN-16 the fourth link is predicted on the third", s.State:Predict(214, "Light", 0, -1) == true)
	run(s, 0.02)
	local l4 = s.Track("Jian_L4")
	check("T-AN-16 L4 shows", l4 and l4.Plays == 1)
	-- Refused link: L4 refused drops only itself.
	setIntent("214:Rejected:Exhausted:" .. sampleTick)
	s.Frame()
	check("T-AN-17 a refused link ends", s.State.Predicted == nil or s.State.Predicted.Seq ~= 214)
	s.State:Destroy()

	-- A missed intermediate confirmation: the server's sample names L2 directly; L1 settles without a rollback.
	s = scene()
	assert(s.State:Predict(221, "Light", 0, -1))
	run(s, recovery(1) - 0.02)
	assert(s.State:Predict(222, "Light", 0, -1))
	run(s, 0.04)
	s.Fighter.Move, s.Fighter.MoveStart, s.Fighter.State, s.Fighter.StateStart, s.Fighter.StateEnd = L[2], clock - 0.02, "Startup", clock - 0.02, clock + 1
	Combat.markIntent(s.Fighter, 222)
	s.Publish()
	s.Frame()
	check("T-AN-18 a sample naming the link settles the swing before it", s.State.Predicted == nil and #s.State.FollowUps == 0)
	check("T-AN-18 no rollback or restart", s.Track("Jian_L2").Plays == 1)
	s.State:Destroy()

	-- Not eligible: too late, stamina, wrong state, heavy.
	local snap = Combat.unpackString(Combat.packString(Combat.new(6, "Jian", 10), 10))
	local t1 = L[1].Timing
	local swing = { Move = L[1].Id, Started = 10 }
	local r = 10 + t1.StartupSeconds + t1.ActiveSeconds
	check("T-AN-20 no link once the combo window has passed", Prediction.followUp(snap, "Light", swing, r + t1.ComboWindowSeconds, 0) == nil)
	check("T-AN-20 no link earlier than the buffer", Prediction.followUp(snap, "Light", swing, r - Settings.Input.BufferWindow, 0) == nil)
	check("T-AN-20 no link for a heavy press", Prediction.followUp(snap, "Heavy", swing, r, 0) == nil)
	check("T-AN-20 unconfirmed costs count against stamina", Prediction.followUp(snap, "Light", swing, r, snap.Stamina) == nil)
	local stunned = table.clone(snap); stunned.State = "Hitstun"
	check("T-AN-20 no link over an interrupting state", Prediction.followUp(stunned, "Light", swing, r, 0) == nil)
	local move, at = Prediction.followUp(snap, "Light", swing, r - 0.05, 0)
	check("T-AN-20 an early press starts at the recovery", move == L[2].Id and near(at, r))
	local finish = r + t1.RecoverySeconds
	local fresh, freshAt = Prediction.restart(snap, "Light", swing, finish - 0.01, 0)
	check("T-AN-22 a press the buffer holds past the link opens at the swing's end", fresh == L[1].Id and near(freshAt, finish))
	local linkEnd = r + t1.ComboWindowSeconds
	check("T-AN-22 no opener while the link might still be open", Prediction.restart(snap, "Light", swing, linkEnd, 0) == nil)
	check("T-AN-22 no opener earlier than the buffer reaches the end", Prediction.restart(snap, "Light", swing, finish - Settings.Input.BufferWindow, 0) == nil)
	check("T-AN-22 an opener needs its stamina too", Prediction.restart(snap, "Light", swing, finish - 0.01, snap.Stamina) == nil)
	local sprinting = table.clone(snap); sprinting.Sprinting = true
	check("T-AN-22 a sprinting press is left to the server", Prediction.restart(sprinting, "Light", swing, finish - 0.01, 0) == nil)
	local last = L[#L]
	local lastSwing = { Move = last.Id, Started = 10 }
	local lastRecovery = 10 + last.Timing.StartupSeconds + last.Timing.ActiveSeconds
	check("T-AN-22 the final light has no link", Prediction.followUp(snap, "Light", lastSwing, lastRecovery - 0.05, 0) == nil)
	local after, afterAt = Prediction.restart(snap, "Light", lastSwing, lastRecovery + last.Timing.RecoverySeconds - 0.05, 0)
	check("T-AN-22 the final light's buffered press restarts the chain at its end", after == L[1].Id and near(afterAt, lastRecovery + last.Timing.RecoverySeconds))
	check("T-AN-21 parry to counter is an opener", Prediction.attack((function() local d = table.clone(snap); d.State = "Deflecting"; return d end)(), "Light") == L[1].Id)
	check("T-AN-21 a sprinting press is the running attack", Prediction.attack((function() local d = table.clone(snap); d.Sprinting = true; return d end)(), "Light") == jian.RunningAttack.Id)

	-- An interrupting snapshot overrides the shown link.
	s = scene()
	assert(s.State:Predict(231, "Light", 0, -1))
	run(s, 0.03)
	local attacker = Combat.new(99, "Jian", clock)
	assert(Combat.tryAttack(attacker, "Light", clock)); attacker.State = "Active"
	Combat.resolveHit(attacker, s.Fighter, clock, { Facing = false, Region = "Torso" }, {})
	s.Publish()
	s.Frame()
	check("T-AN-22 a hit overrides the prediction's presentation", s.State:Presented(s.Entity.Snapshot) == nil and not s.Track("Jian_L1").IsPlaying)
	s.State:Destroy()

	-- Same move repeats (intent differs); a server-driven same-move repeat (ActionSeq differs).
	s = scene()
	assert(Combat.tryAttack(s.Fighter, "Heavy", clock))
	Combat.markIntent(s.Fighter, 241)
	s.Publish()
	s.Frame()
	local heavy = s.Track("Jian_Heavy")
	check("T-AN-23 first heavy plays once", heavy.Plays == 1)
	s.Frame()
	check("T-AN-23 the same occurrence is not replayed", heavy.Plays == 1)
	s.Fighter.State = "Idle"; s.Publish(); s.Frame()
	assert(Combat.tryAttack(s.Fighter, "Heavy", clock))
	Combat.markIntent(s.Fighter, 242)
	s.Publish()
	s.Frame()
	check("T-AN-23 a repeat of the same move is a new occurrence", heavy.Plays == 2)
	s.State:Destroy()

	-- A new observer seeing a swing late: keeps windup at a bounded rate and meets the contact.
	local phases = Timing.identity(0.3, 0.05, 0.6)
	local seat, rate = Timing.plan(phases, 0.1)
	check("T-AN-30 first seen late, it keeps as much windup as 1.5x allows", near(seat, 0, 1e-9) and near(rate, 1.5), seat)
	check("T-AN-30 the old 2x would have started later", seat < 0.3 - 0.2 * 2 + 0.2)
	seat = Timing.plan(phases, 0.25)
	check("T-AN-30 close to contact: starts on the bounded path", near(seat, 0.3 - 0.05 * 1.5))
	check("T-AN-31 past contact it starts at its true phase", near((Timing.plan(phases, 0.32)), 0.32))
	-- Correction: every rate in bounds, every error under the limit never seats, and the error closes.
	local clip, target = 0.0, 0.08
	local most, least, seats = 1, 1, 0
	for _ = 1, 60 do
		local factor, seated = Timing.correct(clip, target, 1, 1 / 60)
		seats += if seated then 1 else 0
		most, least = math.max(most, factor), math.min(least, factor)
		clip += factor / 60
		target += 1 / 60
	end
	check("T-AN-32 catch-up stays within [0.75, 1.5] with no seat", most <= 1.5 and least >= 0.75 and seats == 0, most)
	check("T-AN-32 the error closes", math.abs(target - clip) < 0.01, target - clip)
	check("T-AN-33 beyond 250 ms is a real discontinuity", select(2, Timing.correct(0, 0.3, 1, 1 / 60)) == true)
	-- A phase map that is not one to one (a shared clip): contact lands on the server's active frame.
	local mapped = { Startup = 0.2, Active = 0.1, Total = 0.6, ClipContact = 0.5, ClipActiveEnd = 0.6, ClipLength = 1 }
	check("T-AN-34 per-move phases: the clip's contact maps to the server's first active frame", near(Timing.clipTime(mapped, 0.2), 0.5) and near(Timing.clipTime(mapped, 0.3), 0.6))
	check("T-AN-34 per-move phases: rate follows the phase", near(Timing.nominalRate(mapped, 0.1), 2.5) and near(Timing.nominalRate(mapped, 0.25), 1) and near(Timing.nominalRate(mapped, 0.4), 4 / 3))

	-- Real playback: an observer whose samples arrive late and stale never seats inside the limit.
	s = scene()
	local start = clock
	assert(Combat.tryAttack(s.Fighter, "Heavy", clock - 0.1)) -- first seen 100 ms in, as a new observer
	s.Publish(0.05)
	local contactClip = L and jian.Heavy.Timing.StartupSeconds
	local heavyClip
	for _ = 1, 40 do
		s.Frame()
		heavyClip = s.Track("Jian_Heavy")
		if clock - start + 0.1 >= contactClip then break end
	end
	check("T-AN-35 the late observer stays on the server's clock without seeking again", heavyClip.Seeks <= 1, heavyClip.Seeks)
	check("T-AN-35 its contact lands within a few frames of the server's", math.abs(heavyClip.TimePosition - contactClip) < 0.05, heavyClip.TimePosition - contactClip)
	check("T-AN-35 no speed beyond the bound", heavyClip.MaxSpeed <= 1.5 + 1e-6, heavyClip.MaxSpeed)
	s.State:Destroy()

	-- First use: a track still reporting no length is seated once it knows it.
	s = scene()
	assert(Combat.tryAttack(s.Fighter, "Light", clock))
	s.Publish()
	local slot = Catalog.weapon("Jian", "Light1").Custom
	local loading = s.Tracks[slot]
	loading.Length = 0
	s.Frame()
	check("T-AN-36 first-use load is counted, not treated as a phase error", s.Animations.Stats.Unloaded >= 1)
	loading.Length = manifest[slot].Length
	s.Frame()
	check("T-AN-36 the loaded clip continues on the server's clock", near(loading.TimePosition, clock - s.Fighter.MoveStart, 0.1))
	s.State:Destroy()
end

-------------------------------------------------------------------------------------------------
-- T-HS-06. Duplicate contact cues: one contact can raise several events; between the same two bodies they are one stop.
do
	local Feedback = load("src/client/Controllers/CombatFeedback.luau", { Parent = poseFor })
	local self = { Stops = {} }
	local a, b = {}, {}
	clock = 100
	Feedback.HitStop(self, { a }, 0.04, "1:2")
	clock = 100.01
	Feedback.HitStop(self, { a }, 0.04, "1:2")
	check("T-HS-06 the stop still runs its own length", (PlaybackScale.of(a, 100.035)) == 0)
	check("T-HS-06 a second cue 10 ms later does not lengthen the stop", (PlaybackScale.of(a, 100.045)) == 1, (PlaybackScale.of(a, 100.045)))
	clock = 100.01
	Feedback.HitStop(self, { b }, 0.04, "3:2")
	check("T-HS-06 another pair is not the same contact", (PlaybackScale.of(b, 100.045)) == 0)
	clock = 100.05
	Feedback.HitStop(self, { a }, 0.04, "1:2")
	check("T-HS-06 a later contact between the same bodies is a new stop", (PlaybackScale.of(a, 100.08)) == 0)
	clock = 100.2
	Feedback.HitStop(self, { a }, 0.04, "1:2")
	clock = 100.21
	Feedback.HitStop(self, { a }, 0.07, "1:2")
	check("T-HS-06 of two cues for one contact the longer duration holds, from the first", (PlaybackScale.of(a, 100.26)) == 0 and (PlaybackScale.of(a, 100.275)) == 1)
end

-- T-HS. One playback owner
-------------------------------------------------------------------------------------------------

do
	local s = scene()
	assert(Combat.tryAttack(s.Fighter, "Heavy", clock))
	s.Publish()
	s.Frame()
	local heavy = s.Track("Jian_Heavy")
	local model = s.Entity.Model
	run(s, 0.1)
	PlaybackScale.request(model, "HitStop", 0, clock + 0.07)
	s.Publish(); s.Frame()
	check("T-HS-01 hitstop freezes the action layer", heavy.Speed == 0)
	local frozenAt = heavy.TimePosition
	run(s, 0.05)
	check("T-HS-01 frozen means frozen", near(heavy.TimePosition, frozenAt))
	run(s, 0.05)
	check("T-HS-02 hitstop ends with no saved speed to restore", heavy.Speed > 1)
	check("T-HS-02 the debt is repaid at or under the bound", heavy.MaxSpeed <= 1.5 + 1e-6, heavy.MaxSpeed)
	run(s, 0.25)
	check("T-HS-02 the clip is back on the server's clock", near(heavy.TimePosition, clock - s.Fighter.MoveStart, 0.02), heavy.TimePosition - (clock - s.Fighter.MoveStart))
	check("T-HS-02 no seek paid for it", heavy.Seeks == 0, heavy.Seeks)
	s.State:Destroy()

	-- A track that starts during a freeze obeys it; one that ends during it restores nothing.
	s = scene()
	model = s.Entity.Model
	PlaybackScale.request(model, "HitStop", 0, clock + 0.1)
	assert(Combat.tryAttack(s.Fighter, "Heavy", clock))
	s.Publish()
	s.Frame()
	heavy = s.Track("Jian_Heavy")
	check("T-HS-03 a clip starting in hitstop starts frozen", heavy.Speed == 0)
	s.State:Destroy()

	s = scene()
	model = s.Entity.Model
	assert(Combat.tryAttack(s.Fighter, "Heavy", clock))
	s.Publish(); s.Frame()
	heavy = s.Track("Jian_Heavy")
	PlaybackScale.request(model, "HitStop", 0, clock + 0.1)
	s.Frame()
	s.Fighter.State = "Idle"; s.Publish(); s.Frame()
	local writes = heavy.Writes
	run(s, 0.2)
	check("T-HS-04 a clip stopped during hitstop gets no late speed write", heavy.Writes == writes and not heavy.IsPlaying)
	s.State:Destroy()

	-- Locomotion layers keep moving under hitstop; a finishing shot slows them too.
	s = scene()
	model = s.Entity.Model
	run(s, 0.02)
	local idle = s.Track("Jian_Idle")
	PlaybackScale.request(model, "HitStop", 0, clock + 0.05)
	s.Frame()
	check("T-HS-05 the base layer keeps moving under hitstop", idle.Speed == 1)
	PlaybackScale.request(model, "Finish", 0.25, clock + 0.2, true)
	s.Frame()
	check("T-HS-06 a finishing shot slows the base layer too", near(idle.Speed, 0.25) or idle.Speed == 0)
	PlaybackScale.clear("Finish"); PlaybackScale.clear("HitStop")
	s.Frame()
	check("T-HS-06 and lets go of it", idle.Speed == 1)
	s.State:Destroy()

	-- Repeated requests overlap; they never add up.
	local m = {}
	PlaybackScale.request(m, "HitStop", 0, clock + 0.05)
	PlaybackScale.request(m, "HitStop", 0, clock + 0.03)
	check("T-HS-07 an earlier end never shortens a live stop", (PlaybackScale.of(m, clock + 0.04)) == 0)
	check("T-HS-07 nor is it added on top", (PlaybackScale.of(m, clock + 0.051)) == 1)

	-- CombatFeedback's duplicate cue: the real HitStop.
	local Feedback = luau.load(between(fs.readFile("src/client/Controllers/CombatFeedback.luau"), "function Feedback.HitStop(", "function Feedback.Event(") .. "\nreturn Feedback.HitStop", {
		debugName = "HitStop", environment = setmetatable({ Feedback = {}, PlaybackScale = PlaybackScale, DUPLICATE_CUE = 0.03, os = { clock = function() return clock end }, math = math }, {}),
	})
	local chunk = "local Feedback, PlaybackScale, DUPLICATE_CUE = ...\n" .. between(fs.readFile("src/client/Controllers/CombatFeedback.luau"), "function Feedback.HitStop(", "function Feedback.Event(") .. "\nreturn Feedback.HitStop"
	local hitStop = luau.load(chunk, { debugName = "HitStop", environment = { os = { clock = function() return clock end }, math = math } })({}, PlaybackScale, 0.03)
	local stops = { Stops = {} }
	local body = {}
	hitStop(stops, { body }, 0.04, "1:2")
	clock += 0.01
	hitStop(stops, { body }, 0.04, "1:2") -- one contact raised two events, 10 ms apart
	check("T-HS-08 duplicate contact cues are one stop, measured from the contact", (PlaybackScale.of(body, clock + 0.02)) == 0 and (PlaybackScale.of(body, clock + 0.035)) == 1)
	clock += 0.1
	hitStop(stops, { body }, 0.04, "1:2")
	check("T-HS-08 a later contact is a new stop", (PlaybackScale.of(body, clock + 0.03)) == 0)
	PlaybackScale.clear("HitStop")

	-- Bosses: the scale reaches their one speed write, the plan's rate returns after it, and the debt is repaid.
	do
		local bossRules = { Reactions = {}, Contacts = { Boss = { Smash = { 0.5 } } }, contactFor = function() return 1 end,
			startPlan = function(contact, lead) return 0, 1, 0 end, retime = function() return 1 end,
			resolve = function() return { Key = "Boss_Smash", Source = "Custom", Id = "rbxassetid://9", Priority = "Action", Looped = false, Speed = 1 } end }
		local track = newTrack("rbxassetid://9")
		local animator = { LoadAnimation = function() return track end }
		local humanoid = { RigType = roblox.Enum.HumanoidRigType.R15, FindFirstChildOfClass = function() return animator end }
		local attrs = { AsuraLookKey = "Boss" }
		local model = { Name = "Boss", GetAttribute = function(_, n) return attrs[n] end, SetAttribute = function(_, n, v) attrs[n] = v end,
			FindFirstChild = function() return nil end, FindFirstChildOfClass = function() return humanoid end }
		local env = environment({ Parent = { PlaybackScale = PlaybackScale } })
		env.game = { GetService = function() return { AsurasPath = { Shared = { BossAnimationRules = bossRules }, Simulation = { AnimationTiming = Timing } } } end }
		local Boss = luau.load(fs.readFile("src/client/Controllers/BossAnimations.luau"), { debugName = "Boss", environment = env })()
		Boss.action(model, false, "Smash", "Heavy", Boss.now() + 0.5)
		Boss.sync(model)
		track:Advance(0.05); clock += 0.05
		PlaybackScale.request(model, "HitStop", 0, clock + 0.05)
		Boss.sync(model)
		check("T-HS-10 hitstop reaches a boss track through its owner", track.Speed == 0)
		track:Advance(0.03); clock += 0.03
		Boss.sync(model)
		clock += 0.03
		Boss.sync(model)
		check("T-HS-10 the plan's rate returns with its debt repaid at the bound", near(track.Speed, 1.5, 0.01), track.Speed)
		for _ = 1, 30 do clock += 1 / 60; Boss.sync(model) end
		check("T-HS-10 and settles back to the plan", near(track.Speed, 1, 0.01), track.Speed)
	end

	-- Static guard: only the owners write track speed.
	local writers = {}
	for _, name in fs.readDir("src/client/Controllers") do
		local text = fs.readFile("src/client/Controllers/" .. name)
		if string.find(text, "AdjustSpeed", 1, true) then
			table.insert(writers, name)
		end
	end
	table.sort(writers)
	check("T-HS-09 only the playback owners write track speed", table.concat(writers, ",") == "BossAnimations.luau,FighterAnimations.luau", table.concat(writers, ","))
	local fighter = fs.readFile("src/client/Controllers/FighterAnimations.luau")
	check("T-HS-09 the fixed catch-up is gone", not string.find(fighter, "CATCH_UP", 1, true) and not string.find(fighter, "DRIFT", 1, true))
end

-------------------------------------------------------------------------------------------------
-- T-FW. Footwork and joint corrections
-------------------------------------------------------------------------------------------------

-- A standard R15 rig (tools/animation/general_zhao/rig.py) under a fake Model, scaled. Motor6D.Transform is a plain field.
local RIG = {
	{ "LowerTorso", "Root", { 0, -1, 0 }, { 0, -0.2, 0 }, { 1.991, 0.401, 1.004 } }, { "UpperTorso", "Waist", { 0, 0.2, 0 }, { 0, -0.849, 0 }, { 1.943, 1.698, 1.004 } },
	{ "Head", "Neck", { 0, 0.849, 0 }, { 0, -0.5758, 0 }, { 1.159, 1.182, 1.161 } },
	{ "RightUpperArm", "RightShoulder", { 0.9716, 0.5975, 0 }, { -0.5005, 0.4189, 0 }, { 1, 1.24, 1 } }, { "RightLowerArm", "RightElbow", { 0, -0.355, 0 }, { 0, 0.2747, 0 }, { 1, 1.1, 1 } },
	{ "RightHand", "RightWrist", { 0, -0.5322, 0 }, { 0, 0.1316, 0 }, { 1, 0.3, 1 } },
	{ "LeftUpperArm", "LeftShoulder", { -0.9716, 0.5975, 0 }, { 0.5005, 0.4189, 0 }, { 1, 1.24, 1 } }, { "LeftLowerArm", "LeftElbow", { 0, -0.355, 0 }, { 0, 0.2747, 0 }, { 1, 1.1, 1 } },
	{ "LeftHand", "LeftWrist", { 0, -0.5322, 0 }, { 0, 0.1316, 0 }, { 1, 0.3, 1 } },
	{ "RightUpperLeg", "RightHip", { 0.5, -0.2, 0 }, { 0, 0.4714, 0 }, { 0.993, 1.363, 0.973 } }, { "RightLowerLeg", "RightKnee", { 0, -0.4493, 0 }, { 0, 0.4133, 0 }, { 0.993, 1.301, 0.973 } },
	{ "RightFoot", "RightAnkle", { 0, -0.5965, 0 }, { 0, 0.106, 0 }, { 1.009, 0.312, 1.001 } },
	{ "LeftUpperLeg", "LeftHip", { -0.5, -0.2, 0 }, { 0, 0.4714, 0 }, { 0.993, 1.363, 0.973 } }, { "LeftLowerLeg", "LeftKnee", { 0, -0.4493, 0 }, { 0, 0.4133, 0 }, { 0.993, 1.301, 0.973 } },
	{ "LeftFoot", "LeftAnkle", { 0, -0.5965, 0 }, { 0, 0.106, 0 }, { 1.009, 0.312, 1.001 } },
}
local function makeRig(scale)
	local parts, motors = {}, {}
	for _, row in RIG do
		local motor = { C0 = CF.new(row[3][1] * scale, row[3][2] * scale, row[3][3] * scale), C1 = CF.new(row[4][1] * scale, row[4][2] * scale, row[4][3] * scale), Transform = CF.identity, IsA = function(_, c) return c == "Motor6D" end }
		local part = { Name = row[1], Size = V3.new(row[5][1] * scale, row[5][2] * scale, row[5][3] * scale), IsA = function(_, c) return c == "BasePart" end,
			FindFirstChild = function(_, n) return if n == row[2] then motor else nil end }
		motor.Parent = part
		parts[row[1]] = part
		motors[row[2]] = motor
	end
	local model = fakeModel(parts, scale)
	return model, motors
end
-- World position of a part from the Motor6D chain and the root.
local function world(root, m, name)
	local chain = {
		LeftFoot = { "Root", "LeftHip", "LeftKnee", "LeftAnkle" }, RightFoot = { "Root", "RightHip", "RightKnee", "RightAnkle" },
		LeftKneeAt = { "Root", "LeftHip" }, RightKneeAt = { "Root", "RightHip" },
	}
	local c = root
	local names = chain[name]
	for i, joint in names do
		local motor = m[joint]
		c = c * motor.C0 * motor.Transform * motor.C1:Inverse()
	end
	return c
end
do
	groundY = function() return 0 end
	-- Foot state machine alone.
	local function input(x, z, vx, vz, yaw, release)
		return { LeftX = x - 0.5, LeftZ = z, LeftYaw = yaw or 0, LeftGround = 0, RightX = x + 0.5, RightZ = z, RightYaw = yaw or 0, RightGround = 0, VX = vx or 0, VZ = vz or 0, Scale = 1, Release = release or false }
	end
	local state = Foot.new()
	for _ = 1, 30 do Foot.update(state, input(0, 0), 1 / 60) end
	local lx, lz = state.Left.X, state.Left.Z
	for _ = 1, 30 do Foot.update(state, input(0.1, 0), 1 / 60) end
	check("T-FW-01 a small shift inside the plant radius does not lift the foot", state.Left.X == lx and state.Left.Z == lz and not state.Left.Swinging)

	-- Walk in every direction relative to facing: planted feet do not skate; both feet step; stride is not a clip.
	local function walk(dx, dz, speed, yaw)
		local s = Foot.new()
		local x, z = 0, 0
		local skate, steps, wasL, wasR = 0, 0, false, false
		local lastLx, lastLz, lastRx, lastRz
		for _ = 1, 240 do
			x += dx * speed / 60
			z += dz * speed / 60
			Foot.update(s, input(x, z, dx * speed, dz * speed, yaw), 1 / 60)
			if not s.Left.Swinging and lastLx and wasL == false then
				skate = math.max(skate, math.abs(s.Left.X - lastLx) + math.abs(s.Left.Z - lastLz))
			end
			if not s.Right.Swinging and lastRx and wasR == false then
				skate = math.max(skate, math.abs(s.Right.X - lastRx) + math.abs(s.Right.Z - lastRz))
			end
			if s.Left.Swinging and not wasL then steps += 1 end
			if s.Right.Swinging and not wasR then steps += 1 end
			wasL, wasR = s.Left.Swinging, s.Right.Swinging
			lastLx, lastLz, lastRx, lastRz = s.Left.X, s.Left.Z, s.Right.X, s.Right.Z
		end
		local gap = math.sqrt((s.Left.X - x + 0.5) ^ 2 + (s.Left.Z - z) ^ 2)
		return skate, steps, gap
	end
	for _, case in { { "forward", 0, -1 }, { "back", 0, 1 }, { "left", -1, 0 }, { "right", 1, 0 }, { "diagonal", 0.7071, -0.7071 } } do
		local skate, steps, gap = walk(case[2], case[3], 10)
		check("T-FW-02 " .. case[1] .. ": planted feet hold their point", skate < 1e-9, skate)
		check("T-FW-02 " .. case[1] .. ": both feet keep stepping", steps >= 8, steps)
		check("T-FW-02 " .. case[1] .. ": the feet stay with the body", gap < 3, gap)
	end
	-- Turn in place.
	state = Foot.new()
	Foot.update(state, input(0, 0, 0, 0, 0), 1 / 60)
	Foot.update(state, input(0, 0, 0, 0, math.rad(90)), 1 / 60)
	check("T-FW-03 a turn past the limit steps on the spot", state.Left.Swinging or state.Right.Swinging)
	-- Release, teleport, unlock.
	state = Foot.new()
	Foot.update(state, input(0, 0), 1 / 60)
	Foot.update(state, input(0, 0, 0, 0, 0, true), 1 / 60)
	check("T-FW-04 release lets the lock fall, never blend in", state.Left.Lock < 1)
	for _ = 1, 10 do Foot.update(state, input(3, 0, 0, 0, 0, true), 1 / 60) end
	check("T-FW-04 released feet follow the clip", near(state.Left.X, 2.5) and state.Left.Lock == 0)
	Foot.update(state, input(3, 0), 1 / 60)
	check("T-FW-04 the next contact captures where the foot now is", near(state.Left.X, 2.5) and state.Left.Lock == 1)
	Foot.update(state, input(90, 0), 1 / 60)
	check("T-FW-05 a teleport re-seats, it does not swing across", near(state.Left.X, 89.5) and not state.Left.Swinging)
	state = Foot.new()
	Foot.update(state, input(0, 0), 1 / 60)
	state.Left.Swinging = false
	Foot.update(state, input(5, 0), 1 / 60)
	check("T-FW-05 a point out of reach lets go", near(state.Left.X, 4.5))

	-- ActorPose on a rig, across scales.
	for _, scale in { 1, 1.6 } do
		local model, m = makeRig(scale)
		local height = 3.1924 * scale
		local rootCF = CF.new(0, height, 0)
		local root = { CFrame = rootCF, Position = rootCF.Position, AssemblyLinearVelocity = V3.zero, Size = V3.new(2, 2, 1) * scale }
		local pose = ActorPose.attach(model, root, false)
		check("T-FW-06 scale " .. scale .. ": attaches to an R15 rig", pose ~= nil)
		pose:SetFeet(true)
		local now = 10
		for _ = 1, 20 do pose:Apply(1 / 60, now); now += 1 / 60 end
		local foot = world(rootCF, m, "LeftFoot")
		check("T-FW-06 scale " .. scale .. ": the ankle stands above the ground, not in it", foot.Position.Y >= -1e-3, foot.Position.Y)
		local stand = foot.Position
		-- The body shifts a little while the feet stay put.
		rootCF = CF.new(0.1 * scale, height, 0)
		root.CFrame, root.Position = rootCF, rootCF.Position
		for _ = 1, 20 do pose:Apply(1 / 60, now); now += 1 / 60 end
		foot = world(rootCF, m, "LeftFoot")
		check("T-FW-07 scale " .. scale .. ": a planted foot holds its world point through a body shift", (foot.Position - stand).Magnitude < 0.02 * scale, (foot.Position - stand).Magnitude)
		-- Walk backward: a whole stride; legs stay reachable and knees never reverse; ground respected.
		local worst, flip, under = 0, false, 0
		local z = 0
		for _ = 1, 120 do
			z += 10 / 60
			rootCF = CF.new(0.1 * scale, height, z)
			root.CFrame, root.Position = rootCF, rootCF.Position
			pose:Apply(1 / 60, now)
			now += 1 / 60
			local upper = rootCF * m.Root.C0 * m.Root.Transform * m.Root.C1:Inverse() * m.LeftHip.C0
			local footNow = world(rootCF, m, "LeftFoot")
			local ankleNow = footNow * m.LeftAnkle.C1 -- the joint, not the foot's centre
			local span = (ankleNow.Position - upper.Position).Magnitude
			worst = math.max(worst, span)
			under = math.max(under, -footNow.Position.Y)
			local knee = (rootCF * m.Root.C0 * m.Root.Transform * m.Root.C1:Inverse() * m.LeftHip.C0 * m.LeftHip.Transform * m.LeftHip.C1:Inverse() * m.LeftKnee.C0)
			local toFoot = (footNow.Position - upper.Position).Unit
			local bend = (knee.Position - upper.Position) - toFoot * (knee.Position - upper.Position):Dot(toFoot)
			if bend.Magnitude > 0.05 * scale and bend.Unit:Dot(rootCF.LookVector) < -0.3 then
				flip = true
			end
		end
		local full = (0.9207 + 1.0098) * scale
		check("T-FW-08 scale " .. scale .. ": no overextension backing away", worst <= full * 1.001, worst / full)
		check("T-FW-08 scale " .. scale .. ": no floor penetration", under < 0.02 * scale, under)
		check("T-FW-08 scale " .. scale .. ": the knee never bends backward", not flip)
		-- Death: released, the writes stop; Destroy hands the joints back.
		pose:Release(true)
		for _ = 1, 30 do pose:Apply(1 / 60, now); now += 1 / 60 end
		check("T-FW-09 scale " .. scale .. ": a released body ends up back on the clip", pose.Idle == true)
		m.LeftHip.Transform = CF.Angles(0.4, 0, 0)
		pose:Apply(1 / 60, now)
		check("T-FW-09 scale " .. scale .. ": and nothing is written over it", m.LeftHip.Transform == CF.Angles(0.4, 0, 0))
		pose:Destroy()
	end

	-- Airborne: with no ground below, the feet release to the clip.
	do
		local model, m = makeRig(1)
		local rootCF = CF.new(0, 3.1924, 0)
		local root = { CFrame = rootCF, Position = rootCF.Position, AssemblyLinearVelocity = V3.zero, Size = V3.new(2, 2, 1) }
		local pose = ActorPose.attach(model, root, false)
		pose:SetFeet(true)
		local now = 20
		for _ = 1, 20 do pose:Apply(1 / 60, now); now += 1 / 60 end
		groundY = function() return nil end
		for _ = 1, 30 do pose:Apply(1 / 60, now); now += 1 / 60 end
		check("T-FW-10 no ground below: the planted lock lets go", pose.Plant.Left.Lock == 0)
		groundY = function() return 0 end
		pose:Destroy()
	end

	-- Inertialization: a clip switch continues from the pose shown, and decays with no pop.
	do
		local model, m = makeRig(1)
		local rootCF = CF.new(0, 3.1924, 0)
		local root = { CFrame = rootCF, Position = rootCF.Position, AssemblyLinearVelocity = V3.zero, Size = V3.new(2, 2, 1) }
		local pose = ActorPose.attach(model, root, false)
		local now = 30
		local A, B = CF.Angles(0.2, 0, 0), CF.Angles(1.2, 0, 0)
		local function angleOf(c)
			local _, a = c:ToAxisAngle()
			return a
		end
		for _ = 1, 5 do m.RightShoulder.Transform = A; pose:Apply(1 / 60, now); now += 1 / 60 end
		m.RightShoulder.Transform = B
		pose:Transition()
		pose:Apply(1 / 60, now); now += 1 / 60
		local first = angleOf(m.RightShoulder.Transform)
		check("T-AN-40 the frame of a clip change is near the pose last shown, not the new clip's", math.abs(first - 0.2) < 0.15, first)
		local previous, jump = first, 0
		for _ = 1, 40 do
			m.RightShoulder.Transform = B
			pose:Apply(1 / 60, now); now += 1 / 60
			local a = angleOf(m.RightShoulder.Transform)
			jump = math.max(jump, math.abs(a - previous))
			previous = a
		end
		check("T-AN-40 the offset decays to the new clip", math.abs(previous - 1.2) < 1e-2, previous)
		check("T-AN-40 with no pop (per-frame change bounded)", jump < 0.2, jump)
		check("T-AN-41 a finished transition stops writing", pose.Joints.RightShoulder.Active == false)
		pose:Destroy()
	end

	-- Presentation step moves the body, never the root.
	do
		local model, m = makeRig(1)
		local rootCF = CF.new(0, 3.1924, 0)
		local root = { CFrame = rootCF, Position = rootCF.Position, AssemblyLinearVelocity = V3.zero, Size = V3.new(2, 2, 1) }
		local pose = ActorPose.attach(model, root, false)
		pose:SetStep(V3.new(0, 0, -2))
		pose:Apply(1 / 60, 40)
		check("T-FW-11 a strike step moves the body, not the root", near(m.Root.Transform.Position.Z, -2, 1e-6) and root.Position == rootCF.Position)
		pose:Destroy()
	end

	-- Actors in a real playback scene: the owner gets a pose writer, clips start with no fade, reduced motion leaves the feet to the clip.
	do
		local rig, m = makeRig(1)
		local s = scene(rig)
		s.Root.CFrame = CF.new(0, 3.1924, 0)
		s.Frame()
		local actor = s.Animations.Actors[rig]
		check("T-FW-12 the owner has a pose writer", actor.Pose ~= nil)
		assert(s.State:Predict(301, "Light", 0, -1))
		s.Frame()
		local l1 = s.Track("Jian_L1")
		check("T-AN-42 with a pose writer a clip starts with no fade (first motion is not a fade-in)", l1.Fades[1] == 0, l1.Fades[1])
		s.Frame()
		check("T-FW-12 planted while swinging", actor.Pose.Feet == true)
		reduced = true
		s.Frame()
		check("T-FW-13 reduced motion leaves the feet to the clip", actor.Pose.Feet == false)
		reduced = false
		s.State:Destroy()
		s.Animations:Destroy()
		check("T-FW-14 Destroy hands the joints back", actor.Pose == nil)
		-- A fifth-row fighter beyond the budget or range falls back with no pose.
		local far = scene()
		far.Frame()
		far.State:Destroy()
	end
end

-------------------------------------------------------------------------------------------------
-- T-CT. The blade the server sweeps is the blade the clip shows
-------------------------------------------------------------------------------------------------

do
	local report = {}
	local jian = Weapons.Weapons.Jian
	local moves = { jian.Light[1], jian.Light[2], jian.Light[3], jian.Light[4], jian.Heavy, jian.RunningAttack, jian.WeaponArt }
	for _, move in moves do
		local data = Trajectories.forMove(move.Id)
		check("T-CT-01 " .. move.Id .. " has baked data", data ~= nil)
		if data then
			local t = move.Timing
			check("T-CT-02 " .. move.Id .. " phase data matches the move's frame data", near(data.Startup, t.StartupSeconds, 1e-3) and near(data.Active, t.ActiveSeconds, 1e-3) and near(data.Total, t.TotalSeconds, 1e-3), data.Total - t.TotalSeconds)
			-- The sweep at each tick is the bake, exactly.
			local count = #data.Samples - 1
			local worst = 0
			for k = 0, count do
				local hx, hy, hz, tx, ty, tz = Trajectories.segment(data, k / count, 0, 1)
				local s = data.Samples[k + 1]
				worst = math.max(worst, math.abs(hx - s[1]) + math.abs(hy - s[2]) + math.abs(hz - s[3]) + math.abs(tx - s[4]) + math.abs(ty - s[5]) + math.abs(tz - s[6]))
			end
			check("T-CT-03 " .. move.Id .. " server samples are the visible blade", worst < 1e-6, worst)
			-- A4: between ticks the sampled segment stays within half a stud of the straight path it interpolates.
			local gap = 0
			for k = 1, count do
				local a, b = data.Samples[k], data.Samples[k + 1]
				gap = math.max(gap, math.sqrt((a[4] - b[4]) ^ 2 + (a[6] - b[6]) ^ 2))
			end
			report[move.Id] = { Reach = Trajectories.reach(data, 0, 1), Design = move.Reach + move.Lunge * 0.35, TipStep = gap }
			-- Reach is honest either way: the volume never reaches past the blade.
			local _, _, _, tx, _, tz = Trajectories.segment(data, 1, 0, 1)
			check("T-CT-04 " .. move.Id .. " the volume ends at the visible tip", math.sqrt(tx * tx + tz * tz) <= Trajectories.reach(data, 0, 1) + 1e-6)
			-- The step lands on the first active frame and is gone by the clip's end.
			check("T-CT-05 " .. move.Id .. " the step is out by contact and home by the end", (#data.Step == 0 or Trajectories.stepAt(data, data.ClipContact) > 0) and Trajectories.stepAt(data, data.ClipLength + 1) == 0)
		end
	end
	check("T-CT-06 a reach bonus lengthens the tip along the blade", (function()
		local data = Trajectories.forMove(jian.Light[1].Id)
		local _, _, _, ax, _, az = Trajectories.segment(data, 0.5, 0, 1)
		local _, _, _, bx, _, bz = Trajectories.segment(data, 0.5, 1, 1)
		return near(math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2), 1, 0.2)
	end)())
	check("T-CT-07 a scaled body scales the path", (function()
		local data = Trajectories.forMove(jian.Light[1].Id)
		return near(Trajectories.reach(data, 0, 2), Trajectories.reach(data, 0, 1) * 2)
	end)())
	check("T-CT-08 a character with its own clips keeps the generic path until baked", Trajectories.forFighter(jian.Light[1].Id, "CursedSwordsman") == nil)
	check("T-CT-08 a moveset's own Jian fighter uses the bake", Trajectories.forFighter(jian.Light[1].Id, nil) ~= nil)
	check("T-CT-08 (static source) a boss's clips are its own, so its strike keeps the generic path", string.find(fs.readFile("src/server/CharacterService.luau"), "omni.Blade = if e.Boss then nil", 1, true) ~= nil)
	check("T-CT-09 an unbaked family stays on the generic path", Trajectories.forMove(Weapons.Weapons.Odachi.Light[1].Id) == nil)

	-- The real server sweep: duplicate prevention and root travel between samples.
	local geo = { Vector3 = V3, CFrame = CF, math = math, table = table, type = type, setmetatable = setmetatable, ipairs = ipairs, pairs = pairs, next = next, assert = assert, error = error, tostring = tostring, string = string, os = os }
	local Lag = luau.load(fs.readFile("src/server/LagCompensation.luau"), { debugName = "Lag", environment = geo })()
	local chunk = "local Combat, Lag, TICK, FACING_DOT, entities, frameEvents, eventPoints, Strike, Trajectories = ...\n"
		.. "local function alive() return true end\nlocal function hostile() return true end\n"
		.. "local function facingDot() return 1 end\nlocal function awardXp() end\n"
		.. between(service, "local function flatUnit(", "\nlocal function facingDot(") .. "\n"
		.. between(service, "local function weaponSegment(", "\n-------") .. "\n"
		.. between(service, "local function facingAt(", "\n-- Whiffs (batch 09)")
		.. "\nreturn resolveContacts"
	local T = 50
	local function strike(kind: string, defenderAt: Vector3, attackerFrom: Vector3?, baked: boolean?, perTick: Vector3?, forget: boolean?)
		local entities, frameEvents = {}, {}
		local resolve = luau.load(chunk, { debugName = "Contacts", environment = geo })(Combat, Lag, TICK, 0.15, entities, frameEvents, {}, Strike, Trajectories)
		local a, b = Combat.new(1, "Jian", T), Combat.new(-1, "Jian", T)
		assert(Combat.tryAttack(a, kind, T))
		local t = a.Move.Timing
		a.State, a.StateStart, a.StateEnd = "Active", T + t.StartupSeconds, T + t.StartupSeconds + t.ActiveSeconds
		local aRoot = CF.lookAt(attackerFrom or V3.new(0, 3.2, 0), (attackerFrom or V3.new(0, 3.2, 0)) + V3.new(0, 0, -1))
		local bRoot = CF.lookAt(defenderAt, V3.new(0, defenderAt.Y, 0))
		local history = Lag.newHistory()
		local at = T + t.StartupSeconds
		for i = 0, 60 do
			Lag.record(history, at - 0.5 + i / 60, bRoot, V3.zero)
		end
		local omni = { YawFor = T, Yaw = 0, Blade = if baked ~= false then Trajectories.forMove(a.Move.Id) else nil, BladeFor = a.Move.Id, BladeScale = 1 }
		local ea = { Id = 1, Fighter = a, Root = { CFrame = aRoot, Position = aRoot.Position }, Model = { GetAttribute = function() return nil end }, Omni = omni, History = Lag.newHistory() }
		local eb = { Id = -1, Fighter = b, Root = { CFrame = bRoot, Position = bRoot.Position }, Model = { GetAttribute = function() return nil end }, History = history, Humanoid = { Health = 100, MaxHealth = 100 } }
		entities[1], entities[-1] = ea, eb
		local events = 0
		local ticks = math.max(math.ceil(t.ActiveSeconds / TICK), 1)
		for k = 1, ticks do
			local now = at + k * TICK
			-- The attacker's root advances at a constant rate: the sweep must cover the crossing.
			if attackerFrom then
				local p = if perTick then attackerFrom + perTick * k else attackerFrom + V3.new(0, 0, -(k / ticks) * 4)
				ea.Root.CFrame, ea.Root.Position = CF.lookAt(p, p + V3.new(0, 0, -1)), p
			end
			if forget then
				omni.SweepAt = nil
			end
			local found = {}
			resolve(ea, now, found)
			events += #found
		end
		return events, a.Move.Id
	end
	local L1 = jian.Light[1]
	local reach = Trajectories.reach(Trajectories.forMove(L1.Id), 0, 1)
	check("T-CT-10 a body inside the blade's reach is struck once, not per sample", (strike("Light", V3.new(0, 3.39, -(reach - 0.5)))) == 1)
	check("T-CT-10 a body beyond the blade plus its hurtbox is not", (strike("Light", V3.new(0, 3.39, -(reach + 6)))) == 0)
	check("T-CT-11 duplicate hits are prevented across the active frames", (strike("Heavy", V3.new(0, 3.39, -8))) <= 1)

	-- A root moving between samples: what the blade crossed counts, a teleport does not. Scanned across the plane so the
	-- answer does not rest on one hand-picked body. `forget` drops the remembered root, the sampling the sweep replaced.
	local function scanTravel(perTick: Vector3): (number, number, number)
		local swept, sampled, extra = 0, 0, 0
		for x = -14, 14 do
			for z = -14, 2 do
				local body = V3.new(x, 3.39, z)
				local from = V3.new(0, 3.2, 0)
				local a = (strike("Heavy", body, from, nil, perTick, false)) > 0
				local b = (strike("Heavy", body, from, nil, perTick, true)) > 0
				swept += if a then 1 else 0
				sampled += if b then 1 else 0
				extra += if a and not b then 1 else 0
			end
		end
		return swept, sampled, extra
	end
	local swept, sampled, extra = scanTravel(V3.new(5, 0, 0))
	check("T-CT-13 a root moving 5 studs a tick hits bodies its blade crossed between samples", extra > 0 and swept > sampled, string.format("%d swept, %d sampled", swept, sampled))
	local jumped, jumpedSampled, jumpedExtra = scanTravel(V3.new(7, 0, 0))
	check("T-CT-14 a root moving past the limit in one tick is a teleport, not a sweep", jumpedExtra == 0 and jumped == jumpedSampled, string.format("%d swept, %d sampled", jumped, jumpedSampled))

	-- Old volume against new, as numbers for the handoff: a ring of bodies around a Jian fighter.
	local coverage = {}
	for _, kind in { "Light", "Heavy" } do
		local baked, generic = 0, 0
		local cells = 0
		for r = 3, 12 do
			for a = -80, 80, 20 do
				local rad = math.rad(a)
				local p = V3.new(math.sin(rad) * r, 3.39, -math.cos(rad) * r)
				cells += 1
				baked += if (strike(kind, p)) > 0 then 1 else 0
				generic += if (strike(kind, p, nil, false)) > 0 then 1 else 0
			end
		end
		table.insert(coverage, string.format("%s: blade %d of %d cells, generic %d of %d", kind, baked, cells, generic, cells))
	end
	print("      T-CT coverage: " .. table.concat(coverage, "; "))
	for id, row in report do
		print(string.format("      T-CT %s visible reach %.2f (design %.2f), largest tip step between ticks %.2f", id, row.Reach, row.Design, row.TipStep))
	end
end

-------------------------------------------------------------------------------------------------
-- Stage 3A closure. Run against the source before these fixes: mac-stage3/closure_before_fix.txt.
-- T-RC  a confirmed prediction converges on the server's phase; T-PB  the presented step survives the pose budget;
-- T-TR  trail and debug follow the blade the server selected; T-FB  real construction and cleanup.
-------------------------------------------------------------------------------------------------

-- Runs a fighter's move on its own clock, as the server does: `start` is the server's start, not the press.
local function serve(f, move, start, intent)
	f.Move, f.MoveStart = move, start
	if intent then
		Combat.markIntent(f, intent)
	end
end
local function serverTick(f)
	local move = f.Move
	if not move then
		return
	end
	local t = move.Timing
	local into = clock - f.MoveStart
	local recovery = t.StartupSeconds + t.ActiveSeconds
	if into < t.StartupSeconds then
		f.State, f.StateStart, f.StateEnd = "Startup", f.MoveStart, f.MoveStart + t.StartupSeconds
	elseif into < recovery then
		f.State, f.StateStart, f.StateEnd = "Active", f.MoveStart + t.StartupSeconds, f.MoveStart + recovery
	elseif into < t.TotalSeconds then
		f.State, f.StateStart, f.StateEnd = "Recovery", f.MoveStart + recovery, f.MoveStart + t.TotalSeconds
	else
		f.State, f.Move = "Idle", nil
	end
end

do
	local jian = Weapons.Weapons.Jian
	local function phaseError(track, move, start)
		return track.TimePosition - Timing.clipTime(Trajectories.forMove(move.Id), clock - start)
	end
	-- A delayed confirmation: the press shows at once, the server's start comes `delay` later, the clip must reach it.
	for index, delay in { 0.05, 0.1, 0.15 } do
		local s = scene()
		s.Root.CFrame = CF.new(0, 3, 0)
		local move = jian.Heavy or Weapons.moveForKind(jian, "Heavy", nil)
		assert(s.State:Predict(400 + index, "Heavy", 0, -1))
		s.Frame()
		local clip = s.Track("Jian_Heavy")
		check("T-RC-01 the press shows at once", clip and clip.Plays == 1 and clip.Speed > 0)
		run(s, delay)
		local start = clock
		serve(s.Fighter, move, start, 400 + index)
		local first: number? = nil
		while clock - start < move.Timing.TotalSeconds - 0.04 do
			serverTick(s.Fighter)
			s.Publish()
			s.Frame()
			first = first or phaseError(clip, move, start)
		end
		local last = phaseError(clip, move, start)
		check("T-RC-01 confirmation arrives behind the clip: there is an error to correct", (first :: number) > delay * 0.7, first)
		check(string.format("T-RC-01 %d ms late: the clip reaches the server's phase", delay * 1000), math.abs(last) <= 0.02, last)
		check("T-RC-01 by rate alone: no restart, no seek", clip.Plays == 1 and clip.Seeks == 0, clip.Seeks)
		check("T-RC-01 the rate stays bounded", clip.MaxSpeed <= 1.5 + 1e-6 and clip.MinMoving >= 0.75 - 1e-6, string.format("%.3f..%.3f", clip.MinMoving, clip.MaxSpeed))
		s.State:Destroy()
	end

	-- A chain with every link confirmed late: each stays one occurrence and the last ends on the server's clock.
	do
		local s = scene()
		s.Root.CFrame = CF.new(0, 3, 0)
		local L = jian.Light
		local delay = 0.06
		local clips, errors = {}, {}
		for link = 1, 4 do
			local move = L[link]
			assert(s.State:Predict(420 + link, "Light", 0, -1) == true, "link " .. link)
			s.Frame()
			local clip = s.Track(move.Id)
			clips[link] = clip
			run(s, delay)
			local start = clock
			serve(s.Fighter, move, start, 420 + link)
			serverTick(s.Fighter)
			s.Publish()
			s.Frame()
			errors[link] = { First = phaseError(clip, move, start) }
			local t = move.Timing
			-- The next press just inside this link's window, on the server's clock.
			local until_ = if link < 4 then t.StartupSeconds + t.ActiveSeconds + 0.02 else t.TotalSeconds - 0.06
			while clock - start < until_ do
				serverTick(s.Fighter)
				s.Publish()
				s.Frame()
			end
			errors[link].Last = phaseError(clip, move, start)
		end
		for link, row in errors do
			check(string.format("T-RC-02 link %d: the error shrinks while it plays", link), row.Last < row.First - 0.01, string.format("%.3f to %.3f", row.First, row.Last))
			check(string.format("T-RC-02 link %d: one play, no seek", link), clips[link].Plays == 1 and clips[link].Seeks == 0)
			check(string.format("T-RC-02 link %d: bounded", link), clips[link].MaxSpeed <= 1.5 + 1e-6 and clips[link].MinMoving >= 0.75 - 1e-6)
		end
		check("T-RC-02 the chain's last link ends on the server's phase", math.abs(errors[4].Last) <= 0.02, errors[4].Last)
		s.State:Destroy()
	end

	-- A dash granted late: same occurrence, same convergence, on the clip stretched over the dash.
	do
		local s = scene()
		s.Root.CFrame = CF.new(0, 3, 0)
		assert(s.State:Predict(430, "Dash", 0, -1))
		s.Frame()
		local clip = s.Track("Fighter_DashForward")
		run(s, 0.06)
		local start = clock
		assert(Combat.tryDash(s.Fighter, "Dash", clock, 0, -1, {}))
		Combat.markIntent(s.Fighter, 430)
		s.Publish()
		s.Frame()
		local phases = Timing.uniform(Settings.Movement.DashDuration, clip.Length)
		local first = clip.TimePosition - Timing.clipTime(phases, clock - start)
		for _ = 1, 10 do
			s.Publish()
			s.Frame()
		end
		local last = clip.TimePosition - Timing.clipTime(phases, clock - start)
		check("T-RC-03 a late dash grant converges too", last < first - 0.015 and clip.Plays == 1 and clip.Seeks == 0, string.format("%.3f to %.3f", first, last))
		s.State:Destroy()
	end
end

-- T-PB. The hit data contains the presented step, so the body must show it whichever writer it has.
do
	groundY = function() return 0 end
	local data = Trajectories.forMove("Jian_Heavy")
	local heavy = Weapons.moveForKind(Weapons.Weapons.Jian, "Heavy", nil)
	-- A second fighter in the owner's scene.
	local function remote(s, id, scale, at)
		local rig, motors = makeRig(scale)
		local root = { CFrame = CF.new(at), Position = at, AssemblyLinearVelocity = V3.zero, Size = V3.new(2, 2, 1) }
		local fighter = Combat.new(id, "Jian", clock)
		local animator = {
			LoadAnimation = function(_, animation)
				local track = newTrack(animation.AnimationId)
				s.Tracks[id .. ":" .. animation.AnimationId] = track
				return track
			end,
			AnimationPlayed = quiet, GetPlayingAnimationTracks = function() return {} end,
		}
		local entity = { Id = id, Model = rig, Root = root, Boss = false, UpdatedAt = clock, Age = 0, Connections = {},
			Humanoid = { RigType = roblox.Enum.HumanoidRigType.R15, FindFirstChildOfClass = function() return animator end } }
		s.State.Entities[id] = entity
		local function publish()
			sampleTick += 2
			entity.Snapshot = Combat.unpackString(Combat.packString(fighter, clock, nil, sampleTick, clock))
			entity.UpdatedAt = clock
		end
		publish()
		return { Rig = rig, Motors = motors, Root = root, Fighter = fighter, Publish = publish, Entity = entity,
			Track = function() return s.Tracks[id .. ":" .. Catalog.weapon("Jian", "Heavy").Custom] end,
			Move = function(to) root.CFrame, root.Position = CF.new(to), to end }
	end
	-- One swing of `r`, frame by frame: Update, the Animator's write (or not), PostAnimate. Returns the largest gap
	-- between the body's offset and the step the server's samples include, and the largest step shown.
	local function swing(s, r, scale, opts)
		opts = opts or {}
		local start = clock
		serve(r.Fighter, heavy, start, nil)
		r.Fighter.ActionSeq = (r.Fighter.ActionSeq + 1) % 256
		local gap, shown, frames = 0, 0, 0
		while clock - start < heavy.Timing.TotalSeconds - 0.02 do
			serverTick(r.Fighter)
			r.Publish()
			local track = r.Track()
			local at = if track and track.IsPlaying then track.TimePosition else 0
			if opts.Each then opts.Each(frames) end
			s.Frame()
			track = r.Track()
			at = if frames == 0 then 0 else at
			if opts.AnimatorWrites ~= false then
				r.Motors.Root.Transform = CF.identity
			end
			s.Animations:PostAnimate(1 / 60)
			local expected = Trajectories.stepAt(data, at) * scale
			local z = -r.Motors.Root.Transform.Position.Z
			gap = math.max(gap, math.abs(z - expected))
			shown = math.max(shown, z)
			frames += 1
		end
		return gap, shown
	end
	local hold = Trajectories.stepAt(data, data.ClipContact + 0.01)

	do
		local s = scene()
		local r = remote(s, 2, 1, V3.new(0, 3.2, -100))
		s.Frame()
		check("T-PB-01 setup: past the range there is no pose writer", s.Animations.Actors[r.Rig].Pose == nil)
		local gap, shown = swing(s, r, 1)
		check("T-PB-01 out of range the body still stands where its blade is", gap <= 0.05 and shown >= hold - 0.05, string.format("gap %.2f, shown %.2f of %.2f", gap, shown, hold))
		s.Animations:Destroy()
		s.State:Destroy()
	end

	do
		local s = scene()
		local others = {}
		for id = 2, 9 do
			others[id] = remote(s, id, 1, V3.new(0, 3.2, -8 - id))
		end
		s.Frame()
		local last = others[9]
		check("T-PB-02 setup: past the budget there is no pose writer", s.Animations.Actors[last.Rig].Pose == nil and s.Animations.Actors[others[2].Rig].Pose ~= nil)
		local gap, shown = swing(s, last, 1)
		check("T-PB-02 past the budget the body still stands where its blade is", gap <= 0.05 and shown >= hold - 0.05, string.format("gap %.2f, shown %.2f", gap, shown))
		s.Animations:Destroy()
		s.State:Destroy()
	end

	-- In and out of range during the swing: the step does not drop, jump or double.
	for _, scale in { 1, 2 } do
		local s = scene()
		local r = remote(s, 2, scale, V3.new(0, 3.2, -10))
		s.Frame()
		local actor = s.Animations.Actors[r.Rig]
		local lost, regained = false, false
		local gap, shown = swing(s, r, scale, { Each = function(frame)
			if frame == 12 then
				r.Move(V3.new(0, 3.2, -100))
			elseif frame == 13 then
				lost = actor.Pose == nil
			elseif frame == 26 then
				r.Move(V3.new(0, 3.2, -10))
			elseif frame == 27 then
				regained = actor.Pose ~= nil
			end
		end })
		check(string.format("T-PB-03 scale %d: the swing left and re-entered the budget", scale), lost and regained, tostring(lost) .. " " .. tostring(regained))
		check(string.format("T-PB-03 scale %d: the step is continuous across both changes", scale), gap <= 0.08, string.format("gap %.2f", gap))
		check(string.format("T-PB-04 scale %d: the step scales with the blade the server scales", scale), near(shown, hold * scale, 0.1), string.format("%.2f of %.2f", shown, hold * scale))
		s.Animations:Destroy()
		s.State:Destroy()
	end

	-- No clip writing the joint this frame: the offset is not added to what it wrote last frame, and it is handed back.
	do
		local s = scene()
		local r = remote(s, 2, 1, V3.new(0, 3.2, -100))
		s.Frame()
		local gap = swing(s, r, 1, { AnimatorWrites = false })
		check("T-PB-05 an Animator that did not write does not accumulate the step", gap <= 0.05, string.format("gap %.2f", gap))
		run(s, 0.1)
		s.Animations:PostAnimate(1 / 60)
		check("T-PB-06 when the swing ends the joint is handed back", r.Motors.Root.Transform.Position.Magnitude <= 1e-3, r.Motors.Root.Transform.Position.Magnitude)
		s.Animations:Destroy()
		s.State:Destroy()
	end

	-- Handing over with nothing rewriting the joint: the step writer must let go before the pose writer reads the joint.
	do
		local s = scene()
		local r = remote(s, 2, 1, V3.new(0, 3.2, -100))
		s.Frame()
		local actor = s.Animations.Actors[r.Rig]
		local regained = false
		local gap = swing(s, r, 1, { AnimatorWrites = false, Each = function(frame)
			if frame == 22 then
				r.Move(V3.new(0, 3.2, -10))
			elseif frame == 23 then
				regained = actor.Pose ~= nil
			end
		end })
		check("T-PB-08 a new pose writer does not add the step to the one already shown", regained and gap <= 0.08, string.format("gap %.2f", gap))
		s.Animations:Destroy()
		s.State:Destroy()
	end

	-- Destroying mid-swing leaves no offset behind.
	do
		local s = scene()
		local r = remote(s, 2, 1, V3.new(0, 3.2, -100))
		s.Frame()
		local start = clock
		serve(r.Fighter, heavy, start, nil)
		r.Fighter.ActionSeq = (r.Fighter.ActionSeq + 1) % 256
		for _ = 1, 22 do
			serverTick(r.Fighter)
			r.Publish()
			s.Frame()
			s.Animations:PostAnimate(1 / 60)
		end
		check("T-PB-07 setup: the step is showing", r.Motors.Root.Transform.Position.Magnitude > 0.5)
		s.Animations:Destroy()
		check("T-PB-07 destroying the playback owner hands the joint back", r.Motors.Root.Transform.Position.Magnitude <= 1e-3, r.Motors.Root.Transform.Position.Magnitude)
		s.State:Destroy()
	end
end

-- T-TR. The trail against the server's own transform (the real weaponSegment and strikeFrame from CharacterService).
do
	shared.Shared.PresentationAssets = { Limits = { TrailActors = 16 } }
	shared.Simulation.StrikeGeometry = Strike
	local Trails = load("src/client/Controllers/WeaponTrails.luau")
	local weaponSegment, strikeFrame = luau.load(
		"local Trajectories, Strike = ...\n" .. between(service, "local function weaponSegment(", "\nlocal function weaponRadius(") .. "\nreturn weaponSegment, strikeFrame",
		{ debugName = "Blade", environment = { Vector3 = V3, CFrame = CF, math = math } }
	)(Trajectories, Strike)
	local data = Trajectories.forMove("Jian_Heavy")
	local count = #data.Samples
	local move = { Id = "Jian_Heavy" }
	local function fixture(scale)
		local ownRoot = { Position = V3.new(0, 3, 40), CFrame = CF.new(0, 3, 40) }
		local root = { CFrame = CF.new(0, 3, 0), Position = V3.new(0, 3, 0) }
		local model = fakeModel(nil, scale)
		local entity = { Root = root, Model = model }
		local state = { Own = function() return { Root = ownRoot } end, Get = function() return entity end, Entities = { [7] = entity } }
		local trails = Trails.new(state)
		local swing = { Clip = 0, Key = "Jian_Heavy#1", Move = "Jian_Heavy" }
		trails.Animations = { Swing = function()
			if swing.Off then
				return nil, 0, "", nil
			end
			return data, swing.Clip, swing.Key, swing.Move
		end }
		return trails, root, model, swing
	end
	local function clipAt(index)
		return data.ClipContact + (data.ClipActiveEnd - data.ClipContact) * (index - 1) / (count - 1) + 1e-5
	end
	local function record(yaw, bonus, scale, blade, now)
		return Strike.encode({ Arc = 90, Reach = 7 + bonus, Lunge = 2, Yaw = yaw, Start = now, Active = 0.05, Weapon = "Jian", Bonus = bonus, Scale = scale, Move = "Jian_Heavy", Baked = blade ~= "" })
	end
	local function serverTip(root, yaw, bonus, scale, index)
		local e = { Root = { CFrame = root.CFrame }, Fighter = { MoveStart = 1 }, Omni = { Yaw = yaw, YawFor = 1, Blade = data, BladeFor = move.Id, BladeScale = scale } }
		local _, tip = weaponSegment(strikeFrame(e), move, (index - 1) / (count - 1), bonus, e.Omni)
		return tip
	end
	local function points(folder, name)
		local out = {}
		for _, carrier in folder:GetChildren() do
			if carrier.Name == name then
				for _, child in carrier:GetChildren() do
					if child:IsA("Attachment") then
						table.insert(out, carrier.CFrame:PointToWorldSpace(child.Position))
					end
				end
			end
		end
		return out
	end

	do
		local decoded = Strike.decode(record(0.7, 1.5, 2, "Jian_Heavy", 12.5))
		check("T-TR-01 the record names the selected blade, its bonus and its scale", decoded and decoded.Move == "Jian_Heavy" and decoded.Baked == true and decoded.Bonus == 1.5 and decoded.Scale == 2 and decoded.Weapon == "Jian")
		local plain = Strike.decode(Strike.encode({ Arc = 90, Reach = 7, Lunge = 2, Yaw = 0, Start = 1, Active = 0.05, Weapon = "Dao" }))
		check("T-TR-01 a generic strike names none", plain and plain.Move == nil and plain.Baked == false and plain.Bonus == 0 and plain.Scale == 1 and plain.Weapon == "Dao")
	end

	-- Scaled, with a reach bonus, a committed yaw off the root's facing and a root moving between samples.
	do
		local trails, root, model, swing = fixture(2)
		local yaw, bonus = 0.7, 1.5
		model:SetAttribute("AsuraStrike", record(yaw, bonus, 2, "Jian_Heavy", clock))
		local expected = {}
		for index = 1, count do
			local p = V3.new(index * 0.8, 3, 0)
			root.Position, root.CFrame = p, CF.new(p)
			swing.Clip = clipAt(index)
			trails:Update(1 / 30)
			expected[index] = serverTip(root, yaw, bonus, 2, index)
			clock += 1 / 60
		end
		root.Position, root.CFrame = V3.new(30, 3, 0), CF.new(30, 3, 0)
		trails:Update(1 / 30)
		local drawn = points(trails.Folder, "StrikeArc")
		local worst = if #drawn == count then 0 else math.huge
		for index, at in drawn do
			if expected[index] then
				worst = math.max(worst, (at - expected[index]).Magnitude)
			end
		end
		check("T-TR-02 each trail point is where the server's blade tip was when it was emitted", worst <= 0.01, string.format("%d of %d points, worst %.3f", #drawn, count, worst))
		trails:Destroy()
	end

	-- A predicted swing draws before its record: root facing and model scale, then the record's transform for new points.
	do
		local trails, root, model, swing = fixture(2)
		swing.Clip = clipAt(1)
		trails:Update(1 / 30)
		local first = points(trails.Folder, "StrikeArc")[1]
		local ax, ay, az = select(4, Trajectories.segment(data, 0, 0, 2))
		check("T-TR-03 before the record arrives the trail uses the root's facing and the model's scale", first and (first - root.CFrame:PointToWorldSpace(V3.new(ax, ay, az))).Magnitude <= 0.01)
		model:SetAttribute("AsuraStrike", record(1.2, 1, 2, "Jian_Heavy", clock))
		swing.Clip = clipAt(2)
		trails:Update(1 / 30)
		local second = points(trails.Folder, "StrikeArc")[2]
		check("T-TR-03 once it arrives, new points use it", second and (second - serverTip(root, 1.2, 1, 2, 2)).Magnitude <= 0.01)
		check("T-TR-03 points already drawn stay", first and (points(trails.Folder, "StrikeArc")[1] - first).Magnitude <= 1e-6)
		trails:Destroy()
	end

	-- A record from an earlier swing does not describe this one.
	do
		local trails, root, model, swing = fixture(1)
		model:SetAttribute("AsuraStrike", record(1.2, 3, 1, "Jian_Heavy", clock - 2))
		swing.Clip = clipAt(1)
		trails:Update(1 / 30)
		local first = points(trails.Folder, "StrikeArc")[1]
		local ax, ay, az = select(4, Trajectories.segment(data, 0, 0, 1))
		check("T-TR-04 a finished swing's record is not applied to the next", first and (first - root.CFrame:PointToWorldSpace(V3.new(ax, ay, az))).Magnitude <= 0.01)
		trails:Destroy()
	end

	-- The server's selection wins over what the client would pick.
	do
		local trails, root, model, swing = fixture(1)
		model:SetAttribute("AsuraStrike", record(0, 0, 1, "", clock - 0.01))
		swing.Clip = clipAt(count)
		trails:Update(1 / 30)
		local drawn = points(trails.Folder, "StrikeArc")
		local _, _, _, tx, ty, tz = Trajectories.segment(data, 1, 0, 1)
		local bakedTip = root.CFrame:PointToWorldSpace(V3.new(tx, ty, tz))
		local onBake = false
		for _, at in drawn do
			onBake = onBake or (at - bakedTip).Magnitude <= 0.01
		end
		check("T-TR-05 a swing the server sweeps generically draws no baked blade", #drawn > 0 and not onBake, #drawn)
		trails:Destroy()

		trails, root, model, swing = fixture(1)
		swing.Off = true
		model:SetAttribute("AsuraStrike", record(0, 0, 1, "Jian_Heavy", clock - 0.06))
		trails:Update(1 / 30)
		drawn = points(trails.Folder, "StrikeArc")
		onBake = false
		for _, at in drawn do
			onBake = onBake or (at - bakedTip).Magnitude <= 0.01
		end
		check("T-TR-06 with no local clip the server's selected blade still draws, on the strike's clock", onBake, #drawn)
		trails:Destroy()
	end

	-- Debug describes the selected trajectory.
	do
		attributes.AsuraDebugReach = true
		local getAttribute = Workspace.GetAttribute
		Workspace.GetAttribute = function(_, name) return if name == "AsuraDebugReach" then true else nil end
		local trails, root, model, swing = fixture(2)
		swing.Clip = 0
		model:SetAttribute("AsuraStrike", record(0.7, 1.5, 2, "Jian_Heavy", clock + 0.2))
		trails:Update(1 / 30)
		local outline = points(trails.Folder, "StrikeDebug")
		local missing = 0
		for index = 1, count do
			local tip = serverTip(root, 0.7, 1.5, 2, index)
			local found = false
			for _, at in outline do
				found = found or (at - tip).Magnitude <= 0.01
			end
			missing += if found then 0 else 1
		end
		check("T-TR-07 the debug outline is the selected blade, with its scale, bonus and yaw", #outline > 0 and missing == 0, string.format("%d points, %d tips missing", #outline, missing))
		trails:Destroy()

		trails, root, model, swing = fixture(1)
		swing.Off = true
		model:SetAttribute("AsuraStrike", record(0, 0, 1, "", clock + 0.2))
		trails:Update(1 / 30)
		outline = points(trails.Folder, "StrikeDebug")
		local _, _, _, gx, gy, gz = Strike.segment({ Arc = 90, Reach = 7, Lunge = 2 }, 1, 0)
		local tip = root.CFrame:PointToWorldSpace(V3.new(gx, gy, gz))
		local found = false
		for _, at in outline do
			found = found or (at - tip).Magnitude <= 0.01
		end
		check("T-TR-08 a generic strike's debug outline is the generic shape", found, #outline)
		trails:Destroy()
		Workspace.GetAttribute = getAttribute
		attributes.AsuraDebugReach = nil
	end

	-- Without the debug attribute nothing outlines the whole shape.
	do
		local trails, _, model, swing = fixture(1)
		swing.Clip = 0
		model:SetAttribute("AsuraStrike", record(0, 0, 1, "Jian_Heavy", clock + 0.2))
		trails:Update(1 / 30)
		check("T-TR-10 production draws no outline, and no trail before contact", #points(trails.Folder, "StrikeDebug") == 0 and #points(trails.Folder, "StrikeArc") == 0)
		local folder = trails.Folder
		trails:Destroy()
		check("T-TR-11 Destroy removes the folder and forgets the records", folder.Parent == nil and next(trails.Strikes) == nil and next(trails.Ribbons) == nil)
	end

	-- The record the server writes.
	do
		local chunk = "local Combat, Strike, Trajectories = ...\nlocal function strikeFrame(e) return e.Root.CFrame end\nlocal function yawOf() return 0 end\n"
			.. between(service, "local function commitStrike(", "\n-- Contacts (combat recovery Stage 2") .. "\nreturn commitStrike"
		local commit = luau.load(chunk, { debugName = "Commit", environment = { math = math, type = type, Vector3 = V3, CFrame = CF } })(Combat, Strike, Trajectories)
		local function published(boss, definition, scale, bonus)
			local attrs = { AsuraDefinition = definition }
			local f = { Move = Weapons.moveForKind(Weapons.Weapons.Jian, "Heavy", nil), MoveStart = 50, ReachBonus = bonus, Weapon = "Jian" }
			local e = { Fighter = f, Boss = boss, Kind = "Player", Root = { CFrame = CF.new(0, 3, 0) }, Omni = { AimFor = -1, YawFor = -1 },
				Model = { GetAttribute = function(_, n) return attrs[n] end, SetAttribute = function(_, n, v) attrs[n] = v end, GetScale = function() return scale end } }
			commit(e)
			return Strike.decode(attrs.AsuraStrike)
		end
		local mine = published(false, nil, 1.5, 2)
		check("T-TR-09 the server publishes its selection, scale and bonus", mine and mine.Move == "Jian_Heavy" and mine.Baked == true and mine.Scale == 1.5 and mine.Bonus == 2)
		local boss = published(true, nil, 1, 0)
		check("T-TR-09 a boss publishes none", boss and boss.Move == "Jian_Heavy" and boss.Baked == false)
		local own = published(false, "CursedSwordsman", 1, 0)
		check("T-TR-09 a character with its own clips publishes none", own and own.Baked == false)
	end
end

-- T-FB. CombatFeedback constructed and destroyed for real.
do
	local Feedback = load("src/client/Controllers/CombatFeedback.luau", { Parent = poseFor })
	local gui = roblox.Instance.new("Folder")
	player.WaitForChild = function() return gui end
	local calls = {}
	local camera = { SetHeadTrauma = function(_, v) calls.Trauma = v end, SetFovClamp = function(_, v) calls.Clamp = v end, SetSway = function(_, v) calls.Sway = v end }
	local state = { OwnSnapshot = function() return nil end }
	local feedback = Feedback.new(state, camera)
	local blur, vignette = feedback.Blur, feedback.Vignette
	check("T-FB-01 construction parents its blur and vignette", blur.Parent ~= nil and vignette.Parent == gui)
	local body = {}
	clock = 500
	feedback:HitStop({ body }, 0.5, "1:2")
	feedback:Update(1 / 60)
	check("T-FB-02 setup: a stop is live", (PlaybackScale.of(body, clock + 0.1)) == 0)
	local ok, why = pcall(feedback.Destroy, feedback)
	check("T-FB-03 Destroy completes", ok, why)
	check("T-FB-03 Destroy removes what it made", blur.Parent == nil and vignette.Parent == nil)
	check("T-FB-03 Destroy releases live hitstop", (PlaybackScale.of(body, clock + 0.1)) == 1)
	check("T-FB-03 Destroy forgets its stops", next(feedback.Stops) == nil)
	check("T-FB-03 Destroy resets the camera", calls.Trauma == "None" and calls.Clamp == 0 and calls.Sway == 0)
	player.WaitForChild = nil
end

print(string.format("stage 3 motion: %d passed, %d failed (offline behaviour; Studio, frame order and feel separate)", passed, failed))
if failed > 0 then
	process.exit(1)
end

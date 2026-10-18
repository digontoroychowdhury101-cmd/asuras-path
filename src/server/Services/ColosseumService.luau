--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/ColosseumService
-- Overworld PvP Colosseums. Each ring is an octagon sealed by an invisible barrier and bordered by
-- an ember threshold; standing on that threshold opens matchmaking for the player:
--   * Ranked 1v1 duels: ELO-bracketed queue, gated on round-trip latency so every hit stays inside
--     the LagCompensation rewind budget, journaled before start and settled through the durable
--     match inbox (exactly-once ELO, recoverable after a crash or disconnect).
--   * Casual spars: an instant challenge to any player on the server, sealed on acceptance.
-- Ranked fighters are normalised to a fixed competitive attribute budget that preserves their
-- build's proportions, so story-mode grinding never decides a ranked duel.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AsurasPath")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Settings = require(Shared.Shared.CombatSettings) :: any
local World = require(Shared.Shared.WorldDefinitions)
local Protocol = require(Shared.Shared.IntentProtocol)
local Rules = require(Shared.Simulation.MatchmakingRules) :: any
local Characters = require(script.Parent:WaitForChild("CharacterService") :: ModuleScript)
local Lag = require(script.Parent:WaitForChild("LagCompensation") :: ModuleScript)
local AI = require(script.Parent:WaitForChild("AIService") :: ModuleScript)
local WorldService = require(script.Parent:WaitForChild("WorldService") :: ModuleScript)
local Persistence = require(script.Parent:WaitForChild("PersistenceService") :: ModuleScript) :: any
local ProfileStore = require(script.Parent:WaitForChild("ProfileStore") :: ModuleScript)
local Journal = require(script.Parent:WaitForChild("MatchJournal") :: ModuleScript) :: any

type Bucket = Protocol.Bucket
type Souls = ProfileStore.Souls
type Attributes = ProfileStore.Attributes
type AttributeName = ProfileStore.AttributeName

export type Mode = "Ranked1v1" | "Casual1v1"
export type Phase = "Countdown" | "Fighting" | "Resolving"

export type RingDefinition = {
	Id: string,
	Name: string,
	Glyph: string,
	Region: string,
	Center: Vector3,
	Apothem: number,
	Band: number,
	Yaw: number,
}

type Ring = {
	Definition: RingDefinition,
	Model: Model?,
	Owned: boolean,
	Match: Match?,
	CooldownUntil: number,
	Directions: { Vector3 },
}

type Match = {
	Id: string,
	Ring: Ring,
	Mode: Mode,
	A: number,
	B: number,
	Names: { [number]: string },
	Profiles: { [number]: any },
	Phase: Phase,
	PhaseEnds: number,
	Winner: number?,
	Draw: boolean,
	Reason: string,
	Results: { [string]: any }?,
	Journaled: boolean,
	Busy: boolean,
	ReleaseAt: number,
}

type QueueEntry = {
	userId: number,
	mode: Mode,
	elo: number,
	enteredAt: number,
	ring: string,
}

type Challenge = {
	Id: string,
	From: number,
	To: number,
	Ring: string,
	Expires: number,
}

type Remainder = { Name: AttributeName, Fraction: number }

type Presence = {
	Ring: string?,
	Dismissed: string?,
	Ping: number,
	LastRoster: number,
}

local ColosseumService = {}

-------------------------------------------------------------------------------------------------
-- Tuning
-------------------------------------------------------------------------------------------------

local POLL_INTERVAL = 0.25
local ROSTER_INTERVAL = 2
local COUNTDOWN_SECONDS: number = Config.Match.CountdownSeconds
local FIGHT_SECONDS: number = Config.Match.RoundSeconds
local RESULT_HOLD = 3
local RING_COOLDOWN = 2
local CHALLENGE_SECONDS = 15
local DRAW_EPSILON = 0.01
local ESCAPE_MARGIN = 1.5
local FLOOR_TOP = 0.4
local ROOT_OFFSET = 3
local WALL_HEIGHT = 3.2
local BARRIER_HEIGHT = 34
local PILLAR_HEIGHT = 9
-- Ranked hit validation rewinds at most Lag.MAX_REWIND; a round trip beyond it would leave the
-- slower duelist's strikes judged against positions the server can no longer reconstruct.
local RANKED_ENTRY_PING: number = Lag.MAX_REWIND
local RANKED_DROP_PING: number = Lag.MAX_REWIND * 1.6
local PING_SMOOTHING = 0.2
-- Competitive baseline: every ranked fighter carries exactly this many points above base,
-- distributed in the proportions of their own build and clamped per attribute.
local RANKED_POINT_BUDGET = 60
local RANKED_ATTRIBUTE_CAP = 40
local ATTRIBUTE_BASE = 10
local ATTRIBUTE_ORDER: { AttributeName } = { "Vitality", "Qi", "Strength", "Dexterity" }

local INTENT_RATE = 3
local INTENT_BURST = 6
local INTENT_SHAPES: { [string]: { [string]: string } } = {
	Enqueue = { action = "string" },
	Dequeue = { action = "string" },
	Refresh = { action = "string" },
	Dismiss = { action = "string" },
	Challenge = { action = "string", target = "number" },
	Respond = { action = "string", challenge = "string", accept = "boolean" },
}
local LOCKED_HOOKS = { "Heal", "Rest", "Travel", "LevelUp", "Interact" }

local ASH = Color3.fromRGB(46, 40, 38)
local STONE = Color3.fromRGB(74, 68, 64)
local EMBER = Color3.fromRGB(232, 118, 46)
local CHAR = Color3.fromRGB(28, 22, 20)

local PROMENADE = World.Sanctuary.Promenade

local RING_DEFINITIONS: { RingDefinition } = {
	{
		Id = "Ring_SanctuaryPromenade",
		Name = "The Colosseum Promenade",
		Glyph = "昇",
		Region = "Sanctuary",
		Center = Vector3.new(PROMENADE.X, PROMENADE.Y, PROMENADE.Z),
		Apothem = 16,
		Band = 6,
		Yaw = 0,
	},
	{
		Id = "Ring_OctagonOfAsh",
		Name = "The Octagonal Ring of Ash",
		Glyph = "灰",
		Region = "AshColosseum",
		Center = Vector3.new(118, 0, -1770),
		Apothem = 20,
		Band = 7,
		Yaw = 0,
	},
	{
		Id = "Ring_GatehouseCircle",
		Name = "The Gatehouse Sparring Ring",
		Glyph = "武",
		Region = "DesecratedMonastery",
		Center = Vector3.new(-130, 0, -745),
		Apothem = 16,
		Band = 6,
		Yaw = 0,
	},
}

-------------------------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------------------------

local rings: { [string]: Ring } = {}
local ringOrder: { Ring } = {}
local matches: { [string]: Match } = {}
local matchOf: { [number]: Match } = {}
local normalized: { [number]: boolean } = {}
local queue: { QueueEntry } = {}
local challenges: { [string]: Challenge } = {}
local outgoing: { [number]: string } = {}
local presence: { [number]: Presence } = {}
local budgets: { [number]: Bucket } = {}
local connections: { RBXScriptConnection } = {}
local baseHooks: Characters.Hooks? = nil
local colosseumFolder: Folder? = nil
local running = false
local closing = false
local pairing = false
local accumulator = 0

local net = Shared:WaitForChild("Net")
local remote = net:WaitForChild("ColosseumIntent") :: RemoteEvent

local journalBacking: { [string]: any } = {}
local journalStore: any = if Persistence.IsMock
	then {
		UpdateAsync = function(_self: any, key: string, transform: (any) -> any): any
			local value = transform(ProfileStore.Copy(journalBacking[key]))
			if value ~= nil then
				journalBacking[key] = ProfileStore.Copy(value)
			end
			return ProfileStore.Copy(value)
		end,
	}
	else game:GetService("DataStoreService"):GetDataStore("AsuraMatches_v1")
local journal: any = Journal.new(journalStore, function(fn: () -> any): (boolean, any)
	return Persistence.Engine:Retry(fn)
end, os.time)

-------------------------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------------------------

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function trace(problem: any): string
	return debug.traceback(tostring(problem), 2)
end

local function notify(userId: number, payload: { [string]: any })
	local player = Players:GetPlayerByUserId(userId)
	if player then
		remote:FireClient(player, payload)
	end
end

local function displayName(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	return if player then player.DisplayName else "Unknown"
end

local function presenceOf(userId: number): Presence
	local existing = presence[userId]
	if existing then
		return existing
	end
	local created: Presence = { Ring = nil, Dismissed = nil, Ping = 0, LastRoster = 0 }
	presence[userId] = created
	return created
end

local function soulsOf(userId: number): Souls?
	local profile = Persistence.Get(userId)
	return if profile then profile.souls else nil
end

-- Development (Studio) opens ranked by default; the Workspace attribute AsuraColosseumQA
-- overrides either way. Live servers stay behind the release gate.
local function developmentRanked(): boolean
	if not RunService:IsStudio() then
		return false
	end
	local override = Workspace:GetAttribute("AsuraColosseumQA")
	if type(override) == "boolean" then
		return override
	end
	return Settings.Colosseum.RankedInDevelopment == true
end

local function rankedOpen(): boolean
	return Protocol.QueueEnabled("Ranked1v1", Config.Features.Matchmaking == true, Config.Release.RankedIntegrationPassed == true, developmentRanked())
end

local function inQueue(userId: number): boolean
	for _, entry in queue do
		if entry.userId == userId then
			return true
		end
	end
	return false
end

local function dequeue(userId: number): boolean
	for index, entry in queue do
		if entry.userId == userId then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

-- Octagonal distance: the largest projection onto the eight edge normals (equals the apothem
-- exactly on an edge), so the ring, its threshold and its interior share one metric.
local function octagonDistance(ring: Ring, position: Vector3): number
	local offset = position - ring.Definition.Center
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local best = 0
	for _, direction in ring.Directions do
		best = math.max(best, flat:Dot(direction))
	end
	return best
end

local function verticalOk(ring: Ring, position: Vector3): boolean
	return math.abs(position.Y - ring.Definition.Center.Y) <= 14
end

local function onThreshold(ring: Ring, position: Vector3): boolean
	local d = octagonDistance(ring, position)
	local definition = ring.Definition
	return verticalOk(ring, position) and d >= definition.Apothem + 0.5 and d <= definition.Apothem + 1.5 + definition.Band
end

local function insideRing(ring: Ring, position: Vector3): boolean
	return verticalOk(ring, position) and octagonDistance(ring, position) < ring.Definition.Apothem
end

local function ringFrame(ring: Ring): CFrame
	local definition = ring.Definition
	return CFrame.new(definition.Center) * CFrame.Angles(0, math.rad(definition.Yaw), 0)
end

-- Slot 1 stands on the ring's local +Z side, slot 2 on -Z; both face the centre.
local function duelSpawn(ring: Ring, slot: number): CFrame
	local frame = ringFrame(ring)
	local distance = ring.Definition.Apothem * 0.55
	local position = (frame * CFrame.new(0, FLOOR_TOP + ROOT_OFFSET, if slot == 1 then distance else -distance)).Position
	local centre = Vector3.new(frame.Position.X, position.Y, frame.Position.Z)
	return CFrame.lookAt(position, centre)
end

local function thresholdPoint(ring: Ring, slot: number): CFrame
	local frame = ringFrame(ring)
	local definition = ring.Definition
	local distance = definition.Apothem + 1 + definition.Band * 0.5
	local position = (frame * CFrame.new(if slot == 1 then 3 else -3, ROOT_OFFSET + 0.2, if slot == 1 then distance else -distance)).Position
	local centre = Vector3.new(frame.Position.X, position.Y, frame.Position.Z)
	return CFrame.lookAt(position, centre)
end

local function ringOfPlayer(userId: number): Ring?
	local e = Characters.GetEntity(userId)
	if not e then
		return nil
	end
	local position = e.Root.Position
	for _, ring in ringOrder do
		if onThreshold(ring, position) then
			return ring
		end
	end
	return nil
end

local function freeRing(preferred: string?): Ring?
	local clock = now()
	local first = if preferred then rings[preferred] else nil
	if first and first.Match == nil and clock >= first.CooldownUntil then
		return first
	end
	for _, ring in ringOrder do
		if ring.Match == nil and clock >= ring.CooldownUntil then
			return ring
		end
	end
	return nil
end

-- Whether a player may be pulled into a duel right now.
local function available(userId: number): (boolean, string?)
	if closing then
		return false, "ColosseumClosed"
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player or not Persistence.Get(userId) or Persistence.Engine.busy[userId] then
		return false, "Unavailable"
	end
	if matchOf[userId] or Characters.IsInDuel(userId) then
		return false, "InDuel"
	end
	local e = Characters.GetEntity(userId)
	if not e or e.Respawning or e.Fighter.State == "KO" or e.Fighter.State == "DeathblowVictim" then
		return false, "Fallen"
	end
	if WorldService.IsInBossFight(userId) then
		return false, "InBossFight"
	end
	if AI.IsHunting(userId) then
		return false, "EnemiesNearby"
	end
	return true, nil
end

-------------------------------------------------------------------------------------------------
-- Stat normalisation
-------------------------------------------------------------------------------------------------

-- Redistributes a fixed point budget across the four attributes in the proportions the player
-- invested, clamped per attribute; an uninvested build is spread evenly. Largest-remainder
-- rounding keeps the total exact.
function ColosseumService.NormalizeAttributes(attributes: Attributes): Attributes
	local spent: { [AttributeName]: number } = {} :: any
	local total = 0
	for _, name in ATTRIBUTE_ORDER do
		local points = math.max((attributes[name] or ATTRIBUTE_BASE) - ATTRIBUTE_BASE, 0)
		spent[name] = points
		total += points
	end
	local headroom = RANKED_ATTRIBUTE_CAP - ATTRIBUTE_BASE
	local allocation: { [AttributeName]: number } = {} :: any
	local remainders: { Remainder } = {}
	local assigned = 0
	for _, name in ATTRIBUTE_ORDER do
		local share = if total > 0 then spent[name] / total else 1 / #ATTRIBUTE_ORDER
		local exact = math.min(RANKED_POINT_BUDGET * share, headroom)
		local whole = math.floor(exact)
		allocation[name] = whole
		assigned += whole
		table.insert(remainders, { Name = name, Fraction = exact - whole })
	end
	table.sort(remainders, function(a: Remainder, b: Remainder): boolean
		if a.Fraction ~= b.Fraction then
			return a.Fraction > b.Fraction
		end
		return (table.find(ATTRIBUTE_ORDER, a.Name) :: number) < (table.find(ATTRIBUTE_ORDER, b.Name) :: number)
	end)
	-- Hand out the remaining points; capped attributes overflow to the next in line.
	local guard = 0
	while assigned < RANKED_POINT_BUDGET and guard < 64 do
		guard += 1
		local granted = false
		for _, item in remainders do
			if assigned >= RANKED_POINT_BUDGET then
				break
			end
			if allocation[item.Name] < headroom then
				allocation[item.Name] += 1
				assigned += 1
				granted = true
			end
		end
		if not granted then
			break
		end
	end
	local result: Attributes = {} :: any
	for _, name in ATTRIBUTE_ORDER do
		result[name] = ATTRIBUTE_BASE + allocation[name]
	end
	return result
end

local function rankedStats(userId: number): any
	local record = soulsOf(userId)
	if not record then
		return nil
	end
	local view = table.clone(record) :: any
	view.attributes = ColosseumService.NormalizeAttributes(record.attributes)
	-- Blacksmith reinforcement is story progression too; ranked fighters carry unforged steel.
	view.inventory = table.clone(record.inventory)
	view.inventory.reinforcement = {}
	return ProfileStore.DeriveStats(view)
end

local function normalizedLevel(userId: number): number
	local record = soulsOf(userId)
	if not record then
		return 1
	end
	return ProfileStore.SoulLevel(ColosseumService.NormalizeAttributes(record.attributes))
end

-------------------------------------------------------------------------------------------------
-- Ranked durability (match journal + participant inbox)
-------------------------------------------------------------------------------------------------

-- Settles every pending ranked match recorded in the player's inbox. Yields.
function ColosseumService.Recover(userId: number): boolean
	local profile = Persistence.Get(userId)
	if not profile then
		return false
	end
	for matchId in profile.pendingMatches do
		if matches[matchId] then
			continue
		end
		local ok, record = journal:Read(matchId)
		if not ok or not record then
			return false
		end
		if record.state == "Active" then
			return false
		end
		if record.state == "Complete" then
			local result = record.results and record.results[tostring(userId)]
			if not result or not Persistence.ApplyResult(userId, matchId, result) then
				return false
			end
		elseif not Persistence.Transaction(userId, function(p: any)
			p.pendingMatches[matchId] = nil
		end) then
			return false
		end
	end
	return true
end

local function rankedResults(match: Match): { [string]: any }
	local first, second = match.Profiles[match.A], match.Profiles[match.B]
	local score = if match.Draw then 0.5 elseif match.Winner == match.A then 1 else 0
	local newA, newB = Rules.CalculateEloChange(first.elo, second.elo, score)
	local xp = Characters.GetMatchXp(match.Id)
	local results: { [string]: any } = {}
	for index, userId in { match.A, match.B } do
		local profile = if index == 1 then first else second
		local win = match.Winner == userId
		results[tostring(userId)] = {
			userId = userId,
			mode = "Ranked1v1",
			eloDelta = if index == 1 then newA - first.elo else newB - second.elo,
			cash = 135 + (if win then 150 elseif match.Draw then 50 else 0),
			outcome = if match.Draw then "Draw" elseif win then "Win" else "Loss",
			style = profile.activeStyle,
			xp = (if win then 150 elseif match.Draw then 75 else 50) + (xp[userId] or 0),
		}
	end
	return results
end

local function clearInbox(userId: number, matchId: string)
	if Persistence.Get(userId) then
		Persistence.Transaction(userId, function(p: any)
			p.pendingMatches[matchId] = nil
		end)
	end
end

-------------------------------------------------------------------------------------------------
-- Match lifecycle
-------------------------------------------------------------------------------------------------

local function broadcast(kind: string, match: Match, extra: { [string]: any }?)
	local payload: { [string]: any } = {
		ring = match.Ring.Definition.Id,
		name = match.Ring.Definition.Name,
		mode = match.Mode,
		a = match.A,
		b = match.B,
		an = match.Names[match.A],
		bn = match.Names[match.B],
		x = match.Ring.Definition.Center.X,
		z = match.Ring.Definition.Center.Z,
	}
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	Characters.Cue(kind, 0, payload)
end

local function conclude(match: Match, winner: number?, draw: boolean, reason: string)
	if match.Phase == "Resolving" then
		return
	end
	match.Phase = "Resolving"
	match.Winner = winner
	match.Draw = draw
	match.Reason = reason
	match.ReleaseAt = now() + RESULT_HOLD
	match.Results = if match.Mode == "Ranked1v1" and not closing then rankedResults(match) else nil
	broadcast("ColosseumResult", match, {
		winner = winner,
		draw = draw,
		reason = reason,
		wn = if winner then match.Names[winner] else nil,
	})
end

local function onDuelComplete(matchId: string, winner: number?, isDraw: boolean, _rounds: number, _xp: any)
	local match = matches[matchId]
	if match then
		conclude(match, winner, isDraw, "KO")
	end
end

local function decideOnTime(match: Match)
	local fa, fb = Characters.GetFighter(match.A), Characters.GetFighter(match.B)
	local ra = if fa then fa.ActiveHP / math.max(fa.MaxHP, 1) else 0
	local rb = if fb then fb.ActiveHP / math.max(fb.MaxHP, 1) else 0
	if math.abs(ra - rb) < DRAW_EPSILON then
		conclude(match, nil, true, "Time")
	else
		conclude(match, if ra > rb then match.A else match.B, false, "Time")
	end
end

local function cancelBeforeStart(id: string, mode: Mode, a: number, b: number)
	if mode == "Ranked1v1" then
		journal:Finish(id, nil)
		clearInbox(a, id)
		clearInbox(b, id)
	end
end

-- Seals two players into a ring. Yields while the ranked journal is written.
local function begin(ring: Ring, a: number, b: number, mode: Mode): (boolean, string?)
	if ring.Match then
		return false, "RingOccupied"
	end
	local id = HttpService:GenerateGUID(false)
	local match: Match = {
		Id = id,
		Ring = ring,
		Mode = mode,
		A = a,
		B = b,
		Names = { [a] = displayName(a), [b] = displayName(b) },
		Profiles = { [a] = Persistence.Get(a), [b] = Persistence.Get(b) },
		Phase = "Countdown",
		PhaseEnds = math.huge,
		Winner = nil,
		Draw = false,
		Reason = "",
		Results = nil,
		Journaled = false,
		Busy = false,
		ReleaseAt = math.huge,
	}
	-- Reserve the ring and both fighters before yielding so no second pairing can claim them.
	ring.Match = match
	matchOf[a] = match
	matchOf[b] = match
	local function abandon(reason: string): (boolean, string?)
		ring.Match = nil
		matchOf[a] = nil
		matchOf[b] = nil
		normalized[a] = nil
		normalized[b] = nil
		return false, reason
	end
	if not match.Profiles[a] or not match.Profiles[b] then
		return abandon("Unavailable")
	end
	if mode == "Ranked1v1" then
		local saved = journal:Create(id, { a, b }, game.JobId)
		if not saved then
			return abandon("JournalUnavailable")
		end
		for _, userId in { a, b } do
			local registered = Persistence.Transaction(userId, function(p: any)
				p.pendingMatches[id] = true
			end)
			if not registered then
				cancelBeforeStart(id, mode, a, b)
				return abandon("ProfileBusy")
			end
		end
		match.Journaled = true
	end
	-- Persistence yields: either fighter may have left, died or been pulled into a boss fight.
	for _, userId in { a, b } do
		local e = Characters.GetEntity(userId)
		if closing or not Players:GetPlayerByUserId(userId) or not e or e.Respawning or e.Fighter.State == "KO"
			or WorldService.IsInBossFight(userId) then
			cancelBeforeStart(id, mode, a, b)
			return abandon("Unavailable")
		end
	end
	if mode == "Ranked1v1" then
		normalized[a] = true
		normalized[b] = true
	end
	matches[id] = match
	local started = Characters.StartAllocatedMatch(id, a, b, mode, onDuelComplete, { duelSpawn(ring, 1), duelSpawn(ring, 2) })
	if not started then
		matches[id] = nil
		cancelBeforeStart(id, mode, a, b)
		return abandon("StartRefused")
	end
	for slot, userId in { a, b } do
		dequeue(userId)
		local pending = outgoing[userId]
		if pending then
			challenges[pending] = nil
			outgoing[userId] = nil
		end
		if mode == "Ranked1v1" then
			local stats = rankedStats(userId)
			if stats then
				Characters.ApplyStats(userId, stats, true)
			end
		end
		Characters.Cinematic(userId, COUNTDOWN_SECONDS)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("AsuraColosseum", ring.Definition.Id)
		end
		local opponent = if slot == 1 then b else a
		local profile = match.Profiles[opponent]
		notify(userId, {
			action = "MatchFound",
			matchId = id,
			ring = ring.Definition.Id,
			name = ring.Definition.Name,
			mode = mode,
			opponent = opponent,
			opponentName = match.Names[opponent],
			opponentElo = if mode == "Ranked1v1" and profile then profile.elo else nil,
			level = if mode == "Ranked1v1" then normalizedLevel(userId) else nil,
			starts = now() + COUNTDOWN_SECONDS,
			ends = now() + COUNTDOWN_SECONDS + FIGHT_SECONDS,
		})
	end
	match.PhaseEnds = now() + COUNTDOWN_SECONDS
	broadcast("ColosseumBegin", match, { starts = match.PhaseEnds })
	return true, nil
end

-- Releases a resolved match: journal, settle, restore story stats and return both to the threshold.
local function release(match: Match)
	if match.Busy then
		return
	end
	match.Busy = true
	local ok, problem = xpcall(function(): boolean
		local record: any = nil
		if match.Journaled then
			local saved, written = journal:Finish(match.Id, match.Results)
			if not saved then
				return false -- Retry on the next poll; never award before the journal commits.
			end
			record = written
			match.Journaled = false
		end
		if record and record.state == "Complete" then
			for _, userId in { match.A, match.B } do
				if Persistence.Get(userId) then
					local result = record.results[tostring(userId)]
					if result and not Persistence.ApplyResult(userId, match.Id, result) then
						warn("[Colosseum] Result for " .. userId .. " deferred to the durable inbox")
					end
				end
			end
		elseif record then
			clearInbox(match.A, match.Id)
			clearInbox(match.B, match.Id)
		end
		local ring = match.Ring
		local returns: { [number]: CFrame } = {
			[match.A] = thresholdPoint(ring, 1),
			[match.B] = thresholdPoint(ring, 2),
		}
		for _, userId in { match.A, match.B } do
			normalized[userId] = nil
			Characters.RefreshProgression(userId)
		end
		Characters.EndAllocatedMatch(match.Id, returns)
		matches[match.Id] = nil
		ring.Match = nil
		ring.CooldownUntil = now() + RING_COOLDOWN
		for _, userId in { match.A, match.B } do
			if matchOf[userId] == match then
				matchOf[userId] = nil
			end
			local result = if match.Results then match.Results[tostring(userId)] else nil
			local opponent = if userId == match.A then match.B else match.A
			notify(userId, {
				action = "MatchResult",
				matchId = match.Id,
				mode = match.Mode,
				outcome = if match.Draw then "Draw" elseif match.Winner == userId then "Win" elseif match.Winner == nil then "Cancelled" else "Loss",
				reason = match.Reason,
				opponentName = match.Names[opponent],
				eloDelta = if result then result.eloDelta else nil,
				profile = Persistence.PublicProfile(userId),
			})
			local p = presence[userId]
			if p then
				p.Ring = nil
				p.Dismissed = nil
			end
		end
		return true
	end, trace)
	match.Busy = false
	if not ok then
		warn("[Colosseum] Release failed: " .. tostring(problem))
	end
end

local function stepMatch(match: Match, clock: number)
	if match.Phase == "Countdown" then
		if clock >= match.PhaseEnds then
			match.Phase = "Fighting"
			match.PhaseEnds = clock + FIGHT_SECONDS
			broadcast("ColosseumFight", match, { ends = match.PhaseEnds })
			for _, userId in { match.A, match.B } do
				notify(userId, { action = "MatchState", phase = "Fighting", ends = match.PhaseEnds })
			end
		end
	elseif match.Phase == "Fighting" then
		if clock >= match.PhaseEnds then
			decideOnTime(match)
			return
		end
		-- Duelists that slip the barrier (lag, physics) are placed back on their mark.
		for slot, userId in { match.A, match.B } do
			local e = Characters.GetEntity(userId)
			if e and e.Fighter.State ~= "KO" then
				local position = e.Root.Position
				if octagonDistance(match.Ring, position) > match.Ring.Definition.Apothem + ESCAPE_MARGIN
					or position.Y < match.Ring.Definition.Center.Y - 8 then
					Characters.Teleport(userId, duelSpawn(match.Ring, slot))
				end
			end
		end
	end
	if match.Phase == "Resolving" and clock >= match.ReleaseAt and not match.Busy then
		task.spawn(release, match)
	end
end

-------------------------------------------------------------------------------------------------
-- Queue and challenges
-------------------------------------------------------------------------------------------------

local function queueStatus(userId: number, ok: boolean, err: string?)
	notify(userId, { action = "Queue", ok = ok, err = err, queued = inQueue(userId), rankedOpen = rankedOpen() })
end

local function enqueue(userId: number): (boolean, string?)
	if closing then
		return false, "ColosseumClosed"
	end
	if not rankedOpen() then
		return false, "RankedClosed"
	end
	local ring = ringOfPlayer(userId)
	if not ring then
		return false, "StepOnThreshold"
	end
	if inQueue(userId) then
		return false, "AlreadyQueued"
	end
	local ready, reason = available(userId)
	if not ready then
		return false, reason
	end
	if presenceOf(userId).Ping > RANKED_ENTRY_PING then
		return false, "HighLatency"
	end
	if not ColosseumService.Recover(userId) then
		return false, "RecoveryPending"
	end
	-- Recover yields: repeat occupancy checks before touching the queue.
	if inQueue(userId) or matchOf[userId] then
		return false, "AlreadyAssigned"
	end
	local profile = Persistence.Get(userId)
	if not profile or Persistence.Engine.busy[userId] then
		return false, "ProfileBusy"
	end
	table.insert(queue, { userId = userId, mode = "Ranked1v1" :: Mode, elo = profile.elo, enteredAt = os.clock(), ring = ring.Definition.Id })
	return true, nil
end

local function pairRanked()
	if pairing or closing or #queue < 2 then
		return
	end
	pairing = true
	local ok, problem = xpcall(function(): boolean
		for index = #queue, 1, -1 do
			local entry = queue[index]
			local userId = entry.userId
			if not Players:GetPlayerByUserId(userId) or not Persistence.Get(userId) then
				table.remove(queue, index)
			elseif presenceOf(userId).Ping > RANKED_DROP_PING then
				table.remove(queue, index)
				queueStatus(userId, false, "HighLatency")
			end
		end
		-- Only fighters who can be sealed right now take part in this pairing pass.
		local eligible: { QueueEntry } = {}
		for _, entry in queue do
			if available(entry.userId) then
				table.insert(eligible, entry)
			end
		end
		local first, second = Rules.FindMatch(eligible :: any, os.clock())
		if not first or not second then
			return false
		end
		local a, b = eligible[first], eligible[second]
		local ring = freeRing(a.ring) or freeRing(b.ring)
		if not ring then
			return false
		end
		local started, reason = begin(ring, a.userId, b.userId, "Ranked1v1" :: Mode)
		if not started then
			warn("[Colosseum] Ranked pairing refused: " .. tostring(reason))
		end
		return true
	end, trace)
	pairing = false
	if not ok then
		warn("[Colosseum] Pairing failed: " .. tostring(problem))
	end
end

local function challenge(from: number, target: number): (boolean, string?)
	if from == target then
		return false, "InvalidTarget"
	end
	local ring = ringOfPlayer(from)
	if not ring then
		return false, "StepOnThreshold"
	end
	local ready, reason = available(from)
	if not ready then
		return false, reason
	end
	local targetReady, targetReason = available(target)
	if not targetReady then
		return false, "Target" .. (targetReason or "Unavailable")
	end
	local previous = outgoing[from]
	if previous then
		local old = challenges[previous]
		challenges[previous] = nil
		if old then
			notify(old.To, { action = "ChallengeWithdrawn", challenge = previous })
		end
	end
	for _, existing in challenges do
		if existing.From == target and existing.To == from then
			return false, "AlreadyChallenged"
		end
	end
	local id = HttpService:GenerateGUID(false)
	local expires = now() + CHALLENGE_SECONDS
	challenges[id] = { Id = id, From = from, To = target, Ring = ring.Definition.Id, Expires = expires }
	outgoing[from] = id
	notify(target, {
		action = "Challenge",
		challenge = id,
		from = from,
		fromName = displayName(from),
		ring = ring.Definition.Id,
		name = ring.Definition.Name,
		expires = expires,
	})
	return true, nil
end

local function respond(userId: number, id: string, accept: boolean)
	local pending = challenges[id]
	if not pending or pending.To ~= userId then
		notify(userId, { action = "ChallengeResult", ok = false, err = "ChallengeExpired" })
		return
	end
	challenges[id] = nil
	if outgoing[pending.From] == id then
		outgoing[pending.From] = nil
	end
	if not accept then
		notify(pending.From, { action = "ChallengeResult", ok = false, err = "ChallengeDeclined", name = displayName(userId) })
		return
	end
	if now() > pending.Expires then
		notify(userId, { action = "ChallengeResult", ok = false, err = "ChallengeExpired" })
		return
	end
	local fromReady, fromReason = available(pending.From)
	local toReady, toReason = available(userId)
	if not fromReady or not toReady then
		local err = if not fromReady then "Target" .. (fromReason or "Unavailable") else toReason
		notify(userId, { action = "ChallengeResult", ok = false, err = err })
		notify(pending.From, { action = "ChallengeResult", ok = false, err = if not toReady then "Target" .. (toReason or "Unavailable") else fromReason })
		return
	end
	local ring = freeRing(pending.Ring)
	if not ring then
		notify(userId, { action = "ChallengeResult", ok = false, err = "RingsOccupied" })
		notify(pending.From, { action = "ChallengeResult", ok = false, err = "RingsOccupied" })
		return
	end
	local started, reason = begin(ring, pending.From, userId, "Casual1v1" :: Mode)
	if not started then
		notify(userId, { action = "ChallengeResult", ok = false, err = reason })
		notify(pending.From, { action = "ChallengeResult", ok = false, err = reason })
	end
end

local function roster(userId: number): { any }
	local list: { any } = {}
	for _, player in Players:GetPlayers() do
		local other = player.UserId
		if other ~= userId and Persistence.Get(other) then
			local record = soulsOf(other)
			local ready, reason = available(other)
			table.insert(list, {
				id = other :: any,
				name = player.DisplayName,
				level = if record then record.level else 1,
				status = if ready then "Ready" else (reason or "Unavailable"),
			})
		end
	end
	table.sort(list, function(x: any, y: any): boolean
		if (x.status == "Ready") ~= (y.status == "Ready") then
			return x.status == "Ready"
		end
		return tostring(x.name) < tostring(y.name)
	end)
	return list
end

local function sendPanel(userId: number, ring: Ring, action: string)
	local profile = Persistence.Get(userId)
	local p = presenceOf(userId)
	p.LastRoster = os.clock()
	notify(userId, {
		action = action,
		ring = ring.Definition.Id,
		name = ring.Definition.Name,
		glyph = ring.Definition.Glyph,
		rankedOpen = rankedOpen(),
		queued = inQueue(userId),
		elo = if profile then profile.elo else nil,
		ping = math.floor(p.Ping * 1000 + 0.5),
		pingLimit = math.floor(RANKED_ENTRY_PING * 1000 + 0.5),
		level = normalizedLevel(userId),
		players = roster(userId),
		occupied = ring.Match ~= nil,
	})
end

-------------------------------------------------------------------------------------------------
-- Intents
-------------------------------------------------------------------------------------------------

local function validIntent(payload: any): boolean
	if type(payload) ~= "table" or type(payload.action) ~= "string" then
		return false
	end
	local shape = INTENT_SHAPES[payload.action]
	if not shape then
		return false
	end
	local count = 0
	for key, value in payload do
		count += 1
		if type(key) ~= "string" or shape[key] == nil or type(value) ~= shape[key] then
			return false
		end
	end
	local expected = 0
	for _ in shape do
		expected += 1
	end
	if count ~= expected then
		return false
	end
	if payload.action == "Challenge" then
		return payload.target == payload.target and payload.target % 1 == 0 and math.abs(payload.target) < 2 ^ 53
	elseif payload.action == "Respond" then
		return #payload.challenge <= 40 and string.match(payload.challenge, "^[%x%-]+$") ~= nil
	end
	return true
end

local function onIntent(player: Player, payload: any)
	if not running or not validIntent(payload) then
		return
	end
	local userId = player.UserId
	local clock = os.clock()
	local budget = budgets[userId]
	if not budget then
		budget = { tokens = INTENT_BURST, time = clock }
		budgets[userId] = budget
	end
	if not Protocol.Take(budget, clock, 1, INTENT_RATE, INTENT_BURST) then
		return
	end
	local action: string = payload.action
	if action == "Enqueue" then
		task.spawn(function()
			local ok, err = enqueue(userId)
			queueStatus(userId, ok, err)
		end)
	elseif action == "Dequeue" then
		dequeue(userId)
		queueStatus(userId, true, nil)
	elseif action == "Refresh" then
		local ring = ringOfPlayer(userId)
		if ring then
			sendPanel(userId, ring, "Roster")
		end
	elseif action == "Dismiss" then
		local p = presenceOf(userId)
		p.Dismissed = p.Ring
	elseif action == "Challenge" then
		local ok, err = challenge(userId, payload.target)
		notify(userId, { action = "ChallengeResult", ok = ok, err = err, sent = ok, name = displayName(payload.target) })
	elseif action == "Respond" then
		task.spawn(respond, userId, payload.challenge, payload.accept)
	end
end

-------------------------------------------------------------------------------------------------
-- Ring geometry
-------------------------------------------------------------------------------------------------

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, geometry: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if geometry then
		pcall(function()
			p.CollisionGroup = "WorldGeometry"
		end)
	end
	p.Parent = parent
	return p
end

local function buildRing(ring: Ring, parent: Folder): Model
	local definition = ring.Definition
	local frame = ringFrame(ring)
	local model = Instance.new("Model")
	model.Name = definition.Id
	model:SetAttribute("AsuraColosseum", definition.Name)
	local apothem = definition.Apothem
	local outer = apothem + 1 + definition.Band
	local edge = 2 * math.tan(math.rad(22.5))

	-- Two squares rotated 45° share an apothem and union into a regular octagon.
	for index = 0, 1 do
		local yaw = CFrame.Angles(0, math.rad(45 * index), 0)
		part(model, "Threshold" .. index, Vector3.new(outer * 2, 0.4, outer * 2), frame * yaw * CFrame.new(0, 0.0, 0), STONE, Enum.Material.Slate, true)
		part(model, "Floor" .. index, Vector3.new(apothem * 2, 0.8, apothem * 2), frame * yaw * CFrame.new(0, 0, 0), ASH, Enum.Material.Basalt, true)
	end
	local sigil = part(model, "Sigil", Vector3.new(0.05, apothem * 1.1, apothem * 1.1), frame * CFrame.new(0, FLOOR_TOP + 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)), CHAR, Enum.Material.Slate, false)
	sigil.Shape = Enum.PartType.Cylinder
	sigil.CanCollide = false
	sigil.CanQuery = false
	local inner = part(model, "SigilCore", Vector3.new(0.06, apothem * 0.35, apothem * 0.35), frame * CFrame.new(0, FLOOR_TOP + 0.04, 0) * CFrame.Angles(0, 0, math.rad(90)), EMBER, Enum.Material.Neon, false)
	inner.Shape = Enum.PartType.Cylinder
	inner.CanCollide = false
	inner.CanQuery = false
	inner.Transparency = 0.55

	for k = 0, 7 do
		local yaw = frame * CFrame.Angles(0, math.rad(45 * k), 0)
		local length = apothem * edge
		part(model, "Wall" .. k, Vector3.new(length + 0.9, WALL_HEIGHT, 1), yaw * CFrame.new(0, FLOOR_TOP + WALL_HEIGHT * 0.5, -apothem - 0.5), STONE, Enum.Material.Slate, true)
		local glow = part(model, "Ember" .. k, Vector3.new(length * 0.9, 0.12, 0.6), yaw * CFrame.new(0, 0.22, -(apothem + 1 + definition.Band * 0.5)), EMBER, Enum.Material.Neon, false)
		glow.CanCollide = false
		glow.CanQuery = false
		glow.Transparency = 0.35
		local barrier = part(model, "Barrier" .. k, Vector3.new(length + 1.2, BARRIER_HEIGHT, 1), yaw * CFrame.new(0, FLOOR_TOP + BARRIER_HEIGHT * 0.5, -apothem - 0.5), CHAR, Enum.Material.SmoothPlastic, false)
		barrier.Transparency = 1
		barrier.CanQuery = false
		barrier.CastShadow = false

		local vertex = frame * CFrame.Angles(0, math.rad(45 * k + 22.5), 0) * CFrame.new(0, 0, -(apothem / math.cos(math.rad(22.5)) + 0.6))
		local pillar = part(model, "Pillar" .. k, Vector3.new(1.6, PILLAR_HEIGHT, 1.6), vertex * CFrame.new(0, FLOOR_TOP + PILLAR_HEIGHT * 0.5, 0), CHAR, Enum.Material.Basalt, true)
		local brazier = part(model, "Brazier" .. k, Vector3.new(1.2, 0.8, 1.2), pillar.CFrame * CFrame.new(0, PILLAR_HEIGHT * 0.5 + 0.4, 0), EMBER, Enum.Material.Neon, false)
		brazier.CanCollide = false
		brazier.CanQuery = false
		local light = Instance.new("PointLight")
		light.Color = EMBER
		light.Range = 18
		light.Brightness = 1.4
		light.Shadows = k % 2 == 0
		light.Parent = brazier
	end

	local signPost = part(model, "Sign", Vector3.new(1, 1, 1), frame * CFrame.new(0, FLOOR_TOP + PILLAR_HEIGHT + 3, 0), CHAR, Enum.Material.SmoothPlastic, false)
	signPost.Transparency = 1
	signPost.CanCollide = false
	signPost.CanQuery = false
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(420, 90)
	billboard.MaxDistance = 140
	billboard.LightInfluence = 0
	billboard.Parent = signPost
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.62, 0)
	title.Font = Enum.Font.Antique
	title.TextScaled = true
	title.Text = definition.Glyph .. "  " .. string.upper(definition.Name)
	title.TextColor3 = Color3.fromRGB(236, 226, 206)
	title.TextStrokeTransparency = 0.4
	title.Parent = billboard
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0, 0.62)
	hint.Size = UDim2.new(1, 0, 0.38, 0)
	hint.Font = Enum.Font.Garamond
	hint.TextScaled = true
	hint.Text = "Step upon the ember threshold to duel"
	hint.TextColor3 = EMBER
	hint.TextStrokeTransparency = 0.5
	hint.Parent = billboard

	model.PrimaryPart = model:FindFirstChild("Floor0") :: BasePart
	model.Parent = parent
	return model
end

local function validateDefinitions()
	local seen: { [string]: boolean } = {}
	for _, definition in RING_DEFINITIONS do
		assert(not seen[definition.Id], "Duplicate Colosseum ring " .. definition.Id)
		seen[definition.Id] = true
		local region = World.Regions[definition.Region :: any]
		assert(region, "Unknown Colosseum region " .. definition.Region)
		local reach = (definition.Apothem + 1 + definition.Band) / math.cos(math.rad(22.5))
		for _, corner in { Vector3.new(reach, 0, reach), Vector3.new(-reach, 0, reach), Vector3.new(reach, 0, -reach), Vector3.new(-reach, 0, -reach) } do
			local point = definition.Center + corner
			assert(World.contains(region.Bounds, point.X, point.Y, point.Z), "Colosseum ring leaves its region: " .. definition.Id)
		end
		for _, altar in World.Altars do
			local p = altar.Placement
			assert((Vector3.new(p.X, p.Y, p.Z) - definition.Center).Magnitude > reach + altar.Radius + 4, "Colosseum ring overlaps altar " .. altar.Id)
		end
		for _, entry in World.Spawns do
			local p = entry.Placement
			assert((Vector3.new(p.X, 0, p.Z) - definition.Center).Magnitude > reach + 12, "Colosseum ring overlaps spawn " .. entry.Id)
		end
	end
end

-------------------------------------------------------------------------------------------------
-- Poll
-------------------------------------------------------------------------------------------------

local function poll()
	local clock = now()
	for _, match in matches do
		stepMatch(match, clock)
	end
	for id, pending in challenges do
		if clock > pending.Expires then
			challenges[id] = nil
			if outgoing[pending.From] == id then
				outgoing[pending.From] = nil
			end
			notify(pending.From, { action = "ChallengeResult", ok = false, err = "ChallengeExpired", name = displayName(pending.To) })
			notify(pending.To, { action = "ChallengeWithdrawn", challenge = id })
		end
	end
	local wall = os.clock()
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local p = presenceOf(userId)
		local okPing, sample = pcall(function()
			return player:GetNetworkPing()
		end)
		if okPing and type(sample) == "number" then
			p.Ping = if p.Ping <= 0 then sample else p.Ping + (sample - p.Ping) * PING_SMOOTHING
		end
		local match = matchOf[userId]
		if match then
			continue
		end
		-- Clear the Colosseum flag once a returned duelist is standing again.
		if player:GetAttribute("AsuraColosseum") ~= nil then
			local e = Characters.GetEntity(userId)
			if e and e.Fighter.State ~= "KO" and not e.Respawning and not Characters.IsInDuel(userId) then
				player:SetAttribute("AsuraColosseum", nil)
			end
		end
		local e = Characters.GetEntity(userId)
		local position = if e then e.Root.Position else nil
		-- Nobody outside a match stands inside a sealed ring.
		if position and e and e.Fighter.State ~= "KO" then
			for _, ring in ringOrder do
				if insideRing(ring, position) then
					Characters.Teleport(userId, thresholdPoint(ring, if (position - ring.Definition.Center):Dot(ringFrame(ring).LookVector) < 0 then 1 else 2))
					position = nil
					break
				end
			end
		end
		local current: Ring? = nil
		if position then
			for _, ring in ringOrder do
				if onThreshold(ring, position) then
					current = ring
					break
				end
			end
		end
		local currentId = if current then current.Definition.Id else nil
		if currentId ~= p.Ring then
			p.Ring = currentId
			if current then
				if p.Dismissed ~= currentId then
					sendPanel(userId, current, "Open")
				end
			else
				p.Dismissed = nil
				notify(userId, { action = "Close" })
			end
		elseif current and p.Dismissed ~= currentId and wall - p.LastRoster >= ROSTER_INTERVAL then
			sendPanel(userId, current, "Roster")
		end
	end
	if not pairing and #queue >= 2 then
		task.spawn(pairRanked)
	end
end

-------------------------------------------------------------------------------------------------
-- Hooks: duel rules layered over the story-mode world hooks
-------------------------------------------------------------------------------------------------

local function invoke(fn: any, ...: any): ...any
	return fn(...)
end

local function installHooks()
	local base = Characters.GetHooks() :: any
	baseHooks = base
	local wrapped = table.clone(base) :: any
	local baseStats: any = base.Stats
	wrapped.Stats = function(userId: number): any
		if normalized[userId] then
			return rankedStats(userId)
		end
		return if baseStats ~= nil then invoke(baseStats, userId) else nil
	end
	local baseEquip: any = base.CanEquip
	wrapped.CanEquip = function(userId: number, weapon: string): boolean
		local match = matchOf[userId]
		if match and match.Mode == "Ranked1v1" then
			return false
		end
		return if baseEquip ~= nil then invoke(baseEquip, userId, weapon) == true else true
	end
	local baseSwap: any = base.Swap
	wrapped.Swap = function(userId: number): (boolean, string)
		local match = matchOf[userId]
		if match and match.Mode == "Ranked1v1" then
			return false, "InColosseum"
		end
		if baseSwap ~= nil then
			return invoke(baseSwap, userId)
		end
		return false, "Unavailable"
	end
	for _, name in LOCKED_HOOKS do
		local original: any = base[name]
		wrapped[name] = function(userId: number, ...: any): (boolean, string)
			if matchOf[userId] then
				return false, "InColosseum"
			end
			if original ~= nil then
				return invoke(original, userId, ...)
			end
			return false, "Unavailable"
		end
	end
	Characters.SetHooks(wrapped)
end

-------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------

function ColosseumService.Start()
	assert(not running, "ColosseumService already started")
	validateDefinitions()
	running = true
	closing = false
	local root = Workspace:FindFirstChild(Config.Names.Root)
	if not root then
		root = Instance.new("Folder")
		root.Name = Config.Names.Root
		root.Parent = Workspace
	end
	local container = (root :: Instance):FindFirstChild("Colosseums")
	local owned = false
	if not container then
		container = Instance.new("Folder")
		container.Name = "Colosseums"
		container.Parent = root
		owned = true
	end
	colosseumFolder = if owned then container :: Folder else nil
	for _, definition in RING_DEFINITIONS do
		local directions: { Vector3 } = {}
		for k = 0, 7 do
			local look = (CFrame.Angles(0, math.rad(definition.Yaw + 45 * k), 0)).LookVector
			table.insert(directions, -Vector3.new(look.X, 0, look.Z).Unit)
		end
		local ring: Ring = {
			Definition = definition,
			Model = nil,
			Owned = false,
			Match = nil,
			CooldownUntil = 0,
			Directions = directions,
		}
		-- An authored model with the ring's id replaces the procedural build.
		local authored = Workspace:FindFirstChild(definition.Id, true)
		if authored and authored:IsA("Model") then
			ring.Model = authored
		else
			ring.Model = buildRing(ring, container :: Folder)
			ring.Owned = true
		end
		rings[definition.Id] = ring
		table.insert(ringOrder, ring)
	end
	installHooks()
	table.insert(connections, remote.OnServerEvent:Connect(onIntent))
	table.insert(connections, RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= POLL_INTERVAL then
			accumulator = 0
			local ok, problem = pcall(poll)
			if not ok then
				warn("[Colosseum] Poll failed: " .. tostring(problem))
			end
		end
	end))
end

-- Forfeits any match the leaving player is part of and withdraws their queue and challenges.
function ColosseumService.Disconnect(userId: number)
	dequeue(userId)
	local pending = outgoing[userId]
	if pending then
		local old = challenges[pending]
		challenges[pending] = nil
		if old then
			notify(old.To, { action = "ChallengeWithdrawn", challenge = pending })
		end
		outgoing[userId] = nil
	end
	for id, entry in challenges do
		if entry.To == userId then
			challenges[id] = nil
			if outgoing[entry.From] == id then
				outgoing[entry.From] = nil
			end
			notify(entry.From, { action = "ChallengeResult", ok = false, err = "TargetUnavailable", name = displayName(userId) })
		end
	end
	local match = matchOf[userId]
	if match and match.Phase ~= "Resolving" then
		conclude(match, if match.A == userId then match.B else match.A, false, "Forfeit")
		match.ReleaseAt = now()
	end
	presence[userId] = nil
	budgets[userId] = nil
end

function ColosseumService.IsInMatch(userId: number): boolean
	return matchOf[userId] ~= nil
end

function ColosseumService.CanEquip(userId: number): boolean
	return matchOf[userId] == nil and not inQueue(userId)
end

function ColosseumService.RankedOpen(): boolean
	return rankedOpen()
end

function ColosseumService.GetRings(): { RingDefinition }
	return RING_DEFINITIONS
end

-- Shutdown: cancels every unfinished match (ranked journals close as Cancelled, so no ELO moves)
-- and releases fighters before persistence closes.
function ColosseumService.Close(deadline: number?)
	closing = true
	table.clear(queue)
	table.clear(challenges)
	table.clear(outgoing)
	for _, match in matches do
		if match.Phase ~= "Resolving" then
			conclude(match, nil, false, "Shutdown")
		end
		match.Results = nil
		match.ReleaseAt = 0
	end
	local limit = math.min(deadline or math.huge, os.clock() + 10)
	while next(matches) ~= nil and os.clock() < limit do
		for _, match in matches do
			if not match.Busy then
				task.spawn(release, match)
			end
		end
		task.wait(0.1)
	end
end

function ColosseumService.Destroy()
	running = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for id, match in matches do
		Characters.EndAllocatedMatch(id, nil)
		for _, userId in { match.A, match.B } do
			normalized[userId] = nil
			matchOf[userId] = nil
		end
	end
	table.clear(matches)
	local base = baseHooks
	if base then
		Characters.SetHooks(base)
		baseHooks = nil
	end
	for _, ring in ringOrder do
		if ring.Owned and ring.Model then
			ring.Model:Destroy()
		end
	end
	if colosseumFolder then
		colosseumFolder:Destroy()
		colosseumFolder = nil
	end
	table.clear(rings)
	table.clear(ringOrder)
	table.clear(queue)
	table.clear(challenges)
	table.clear(outgoing)
	table.clear(presence)
	table.clear(budgets)
end

return ColosseumService

--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/TutorialService
-- Runs the opening training (TutorialRules) for fresh profiles. Steps advance only on proof judged
-- here from authoritative combat events, a drink that actually spent a gourd charge, or the two
-- client-only actions (lock-on, Air Glide) reported over TutorialIntent. Progress persists in the
-- souls record (world.tutorial) and is published as the AsuraTutorial attribute; Skip and Replay are
-- explicit requests. While training, the Sparring Phantom's ring is non-lethal for that player
-- (KOProtected floors health at 1) and the phantom returns after it falls. It drops no Essence.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AsurasPath")
local Rules = require(Shared.Shared.TutorialRules)
local Budget = require(Shared.Shared.IntentProtocol)
local World = require(Shared.Shared.WorldDefinitions)
local Characters = require(script.Parent.CharacterService)
local AI = require(script.Parent.AIService)
local Persistence = require(script.Parent.PersistenceService) :: any
local remote = Shared.Net:WaitForChild("TutorialIntent") :: RemoteEvent

local Tutorial = {}
Tutorial.SpawnId = "DM_Sparring_Phantom"
Tutorial.RingRadius = 32 -- non-lethal sparring ground around the phantom's home
Tutorial.PERILOUS_WINDOW = 1.0 -- seconds around a published perilous impact

type State = { Done: { [string]: boolean }, Elixirs: number?, Protected: boolean, Bucket: Budget.Bucket }
local states: { [number]: State } = {}
local connections: { RBXScriptConnection } = {}
local disconnects: { () -> () } = {}
local running = false
local home = assert(World.spawnById(Tutorial.SpawnId), "Sparring Phantom spawn missing")
local HOME = Vector3.new(home.Placement.X, home.Placement.Y, home.Placement.Z)

-- A profile with no training record that has already gone past the Monastery Gate predates the
-- tutorial: it starts complete. Pure.
function Tutorial.initial(souls: any): { [string]: boolean }
	local done: { [string]: boolean } = {}
	for id in souls.world.tutorial or {} do done[id] = true end
	if next(done) == nil and (souls.world.altars.Altar_DesecratedCloister or next(souls.world.bosses) ~= nil) then
		done[Rules.Complete] = true
	end
	return done
end

local function publish(player: Player, s: State)
	player:SetAttribute("AsuraTutorial", Rules.serialize(s.Done))
end

local function persist(player: Player, s: State)
	local snapshot = table.clone(s.Done)
	task.spawn(function()
		local ok, err = Persistence.Transaction(player.UserId, function(p: any)
			p.souls.world.tutorial = snapshot
		end)
		if not ok then warn("[TutorialService] progress not saved: " .. tostring(err)) end
	end)
end

local function record(player: Player, signal: string)
	local s = states[player.UserId]
	local step = if s then Rules.advance(s.Done, signal) else nil
	if not s or not step then return end
	s.Done[step] = true
	if Rules.finished(s.Done) then s.Done[Rules.Complete] = true end
	publish(player, s)
	persist(player, s)
	local upcoming = Rules.current(s.Done)
	Characters.Cue("TutorialStep", player.UserId, { step = step, nextStep = if upcoming then upcoming.Id else "", complete = upcoming == nil })
end

local function perilous(attackerId: number): boolean
	local e = Characters.GetEntity(attackerId)
	local tag = e and e.Model:GetAttribute("AsuraTelegraph")
	if type(tag) ~= "string" then return false end
	local class, _, impact = string.match(tag, "^(%a+)|([^|]*)|([%d%.%-]+)$")
	return class == "Perilous" and math.abs(Characters.Now() - (tonumber(impact) or -math.huge)) <= Tutorial.PERILOUS_WINDOW
end

local function onEvent(event: any, _point: Vector3?)
	for _, player in Players:GetPlayers() do
		local id = player.UserId
		if states[id] and (event.Source == id or event.Target == id) then
			local signal = Rules.signal(event.Kind, event.Source, event.Target, id, perilous(event.Target))
			if signal then record(player, signal) end
		end
	end
end

local function handle(player: Player, packet: any)
	local s = states[player.UserId]
	if not s or type(packet) ~= "table" or not Budget.Take(s.Bucket, os.clock(), 1, 1, 6) then return end
	if packet.action == "Signal" and type(packet.signal) == "string" and Rules.ClientSignals[packet.signal] then
		record(player, packet.signal)
	elseif packet.action == "Skip" or packet.action == "Replay" then
		s.Done = if packet.action == "Skip" then { [Rules.Skipped] = true } else {}
		publish(player, s)
		persist(player, s)
	end
end

local function poll()
	local phantomNeeded = false
	for _, player in Players:GetPlayers() do
		local id = player.UserId
		local profile = Persistence.Get(id)
		local s: State? = states[id]
		if not s and profile and profile.souls then
			local created: State = { Done = Tutorial.initial(profile.souls), Elixirs = nil, Protected = false, Bucket = { tokens = 6, time = os.clock() } }
			states[id], s = created, created
			publish(player, created)
		end
		local e = Characters.GetEntity(id)
		if s and e then
			local training = Rules.current(s.Done) ~= nil
			local inRing = training and (e.Root.Position - HOME).Magnitude <= Tutorial.RingRadius
			if inRing or s.Protected then e.Fighter.KOProtected = inRing end -- re-applied to a respawned body
			s.Protected = inRing
			phantomNeeded = phantomNeeded or (training and (e.Root.Position - HOME).Magnitude <= Tutorial.RingRadius * 2)
			local elixirs = player:GetAttribute("AsuraElixirs")
			if type(elixirs) == "number" then
				if s.Elixirs and elixirs < s.Elixirs then record(player, "Heal") end -- a charge is spent only on an accepted drink
				s.Elixirs = elixirs
			end
		end
	end
	if phantomNeeded then AI.SpawnMob(Tutorial.SpawnId) end -- returns the live phantom if it still stands
end

function Tutorial.Start()
	assert(not running, "TutorialService already started")
	running = true
	table.insert(disconnects, Characters.Subscribe(onEvent))
	table.insert(connections, remote.OnServerEvent:Connect(handle))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player) states[player.UserId] = nil end))
	task.spawn(function()
		while running do
			poll()
			task.wait(0.5)
		end
	end)
end

function Tutorial.Destroy()
	running = false
	for _, c in connections do c:Disconnect() end
	for _, d in disconnects do d() end
	table.clear(connections); table.clear(disconnects); table.clear(states)
end

return Tutorial

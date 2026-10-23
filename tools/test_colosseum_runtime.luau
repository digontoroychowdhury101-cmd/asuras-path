--!nonstrict
-- Batch 24: the real ColosseumService and WagerService with two duelists and a spectator on the real
-- ProfileStore / MatchJournal / WagerLedger over mock DataStores. Fakes stand in only for characters,
-- players, remotes and the clock. Covers ranked queue -> pairing -> journal + inbox -> countdown ->
-- bell closes wagers -> KO -> exactly-once ELO and settlement; ranked-normalized vs Open (casual)
-- builds; disconnect forfeit with rejoin recovery; a leave during match setup; journal outage; and
-- shutdown. LOCAL MOCK EVIDENCE ONLY: no live DataStore, network, replication or real clients.
-- Run: lune run tools/test_colosseum_runtime.luau (locally: python3 tools/lune_compat.py tools/test_colosseum_runtime.luau)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox") :: any
local task = require("@lune/task")
local Store = require("../src/server/ProfileStore")
local Schema = require("../src/shared/ProfileSchema")
local Journal = require("../src/server/MatchJournal")
local World = require("../src/shared/WorldDefinitions")
local Arena = require("../src/shared/ArenaRules")
local V3, CF = roblox.Vector3, roblox.CFrame

local passed, failed = 0, 0
local function check(name: string, ok: any)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local clock = 0
local fakeOs = { clock = function() return clock end, time = function() return 100000 + math.floor(clock) end, date = os.date }
local function signal()
	local s = { Links = {} }
	function s:Connect(fn) local link = { Connected = true }; function link:Disconnect() self.Connected = false end; table.insert(self.Links, { L = link, F = fn }); return link end
	function s:Fire(...) for _, e in table.clone(self.Links) do if e.L.Connected then e.F(...) end end end
	return s
end

-- Durable stores (profiles, match journal, spectator ledger) with an outage switch per key prefix.
local data, down = {}, {}
local function datastore(prefix: string)
	return { UpdateAsync = function(_, key, fn)
		if down[prefix] then error("simulated DataStore outage") end
		fn(Store.Copy(data[prefix .. key]))
		local value = fn(Store.Copy(data[prefix .. key]))
		if value ~= nil then data[prefix .. key] = Store.Copy(value) end
		return Store.Copy(value)
	end }
end
local engine = Store.new(datastore("P:"), Schema, { owner = "Server", now = function() return 100000 + math.floor(clock) end, wait = function() end, attempts = 2, leaseSeconds = 180 })
local onTransaction: ((number) -> ())? = nil
local Persistence = { Engine = engine, IsMock = false }
function Persistence.Get(id) return engine:Get(id) end
function Persistence.Transaction(id, fn) if onTransaction then onTransaction(id) end; return engine:Transaction(id, fn) end
function Persistence.ApplyResult(id, matchId, result) return engine:ApplyResult(id, matchId, result) end
function Persistence.PublicProfile(id) local p = engine:Get(id); if p then p.receipts = nil end; return p end

-- Players: 7 watches from the balcony; 8 and 9 duel.
local players, Players = {}, { PlayerRemoving = signal(), PlayerAdded = signal() }
local function join(id: number, name: string)
	local p = { UserId = id, DisplayName = name, Name = name, Parent = true, Attributes = {} }
	function p:GetNetworkPing() return 0.05 end
	function p:SetAttribute(k, v) self.Attributes[k] = v end
	function p:GetAttribute(k) return self.Attributes[k] end
	players[id] = p
	assert(engine:Load(id))
	return p
end
function Players:GetPlayerByUserId(id) return players[id] end
function Players:GetPlayers() local l = {}; for _, p in players do table.insert(l, p) end; return l end
local function leave(id: number) players[id] = nil end

-- Characters: entities with a fighter state; records stats, cues and allocated matches.
local entities, cues, applied, started, ended = {}, {}, {}, {}, {}
local baseHooks = { Stats = function(id) return "story:" .. id end, CanEquip = function() return true end, Swap = function() return true, "Swapped" end }
for _, name in { "Heal", "Rest", "Travel", "LevelUp", "Interact" } do baseHooks[name] = function() return true, "ok" end end
local hooks = baseHooks
local Characters = {}
function Characters.GetEntity(id) return entities[id] end
Characters.GetActor = Characters.GetEntity
function Characters.GetFighter(id) return entities[id] and entities[id].Fighter end
function Characters.IsInDuel(id) return entities[id] ~= nil and entities[id].Duel ~= nil end
function Characters.StartAllocatedMatch(id, a, b, mode, done, spawns) started[id] = { A = a, B = b, Mode = mode, Done = done }; entities[a].Duel, entities[b].Duel = id, id; return true end
function Characters.EndAllocatedMatch(id, returns) ended[id] = returns or true; local m = started[id]; if m then for _, u in { m.A, m.B } do if entities[u] then entities[u].Duel = nil end end end end
function Characters.ApplyStats(id, stats, ranked) applied[id] = { Stats = stats, Ranked = ranked } end
function Characters.Cue(kind, source, payload) table.insert(cues, { Kind = kind, Data = payload }) end
function Characters.Cinematic() end
function Characters.GetMatchXp() return {} end
function Characters.Teleport(id, cf) entities[id].Root.Position = cf.Position end
function Characters.RefreshProgression() end
function Characters.RefreshRoster() end
function Characters.GetHooks() return hooks end
function Characters.SetHooks(h) hooks = h end
local function stand(id: number, at: any) entities[id] = { Root = { Position = at }, Fighter = { State = "Idle", ActiveHP = 100, MaxHP = 100 }, Respawning = false } end

-- Engine services and the module environment.
local remotes = {}
local function remote(name)
	local r = { OnServerEvent = signal(), Sent = {} }
	function r:FireClient(player, payload) table.insert(self.Sent, { To = player.UserId, P = payload }) end
	remotes[name] = r
	return r
end
remote("ColosseumIntent"); remote("WagerIntent")
local Workspace = roblox.Instance.new("Workspace")
roblox.implementMethod("Workspace", "GetServerTimeNow", function() return clock end)
local heartbeat = signal()
local guid = 0
local services = {
	Players = Players, Workspace = Workspace, RunService = { Heartbeat = heartbeat, IsStudio = function() return true end },
	HttpService = { GenerateGUID = function() guid += 1; return string.format("%08x-0000-4000-8000-%012x", guid, guid) end },
	DataStoreService = { GetDataStore = function(_, name) return datastore(name .. ":") end },
}
local function finder(t) return setmetatable(t, { __index = { WaitForChild = function(self, n) return rawget(self, n) end } }) end
local SharedModules = finder({ CombatSettings = require("../src/shared/CombatSettings"), WorldDefinitions = World, IntentProtocol = require("../src/infrastructure/IntentProtocol"), ArenaRules = Arena })
local AsurasPath = finder({ Config = require("../src/shared/Config"), Shared = SharedModules, Simulation = finder({ MatchmakingRules = require("../src/simulation/MatchmakingRules") }),
	Net = finder({ ColosseumIntent = remotes.ColosseumIntent, WagerIntent = remotes.WagerIntent }) })
services.ReplicatedStorage = finder({ AsurasPath = AsurasPath })
local game = { GetService = function(_, n) return assert(services[n], n) end, JobId = "local-job" }
local WagerWorld = { make = function() return roblox.Instance.new("Folder"), { Disconnect = function() end } end, near = function() return true end }
local siblings = finder({ CharacterService = Characters, LagCompensation = { MAX_REWIND = 0.15 }, AIService = { IsHunting = function() return false end },
	WorldService = { IsInBossFight = function() return false end }, PersistenceService = Persistence, ProfileStore = Store, MatchJournal = Journal, WagerWorld = WagerWorld })
local function module(path: string): any
	local env = { game = game, workspace = Workspace, script = { Parent = siblings }, require = function(m) return m end, task = task, os = fakeOs,
		Vector3 = V3, CFrame = CF, Color3 = roblox.Color3, Enum = roblox.Enum, Instance = roblox.Instance, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2,
		warn = function() end, print = function() end }
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
siblings.WagerLedger = module("src/server/Services/WagerLedger.luau")
-- Execute the real Sanctuary finish against primitive visual stand-ins. Imported meshes are Studio
-- evidence; this fixture proves that cosmetic assembly cannot move/resize the live duel geometry.
local visualKit = { Surface = {} }
for _, key in { "PavingPath", "Stone", "Bronze", "Timber" } do
	visualKit.Surface[key] = { Material = roblox.Enum.Material.Slate, Variant = "Test" .. key, Color = roblox.Color3.fromRGB(140, 150, 160) }
end
function visualKit.decor() return { Collide = false, Query = false, Shadow = false } end
function visualKit.folder(name, parent)
	local folder = roblox.Instance.new("Folder"); folder.Name, folder.Parent = name, parent; return folder
end
function visualKit.slab(parent, name, size, cf, key)
	local p = roblox.Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Anchored = name, size, cf, true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material, p.Color, p.Parent = visualKit.Surface[key].Material, visualKit.Surface[key].Color, parent
	return p
end
function visualKit.place() return nil end
function visualKit.glow(parent, cf, size) return visualKit.slab(parent, "Paper", size, cf, "Stone") end
siblings.SanctuaryKit = visualKit
local ringFinish = module("src/server/Services/SanctuaryRingFinish.luau")
siblings.SanctuaryRingFinish = { Dress = function(model)
	local originals, known = {}, {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			known[p] = true
			table.insert(originals, { Part = p, Name = p.Name, Size = p.Size, Frame = p.CFrame, Collide = p.CanCollide,
				Query = p.CanQuery, Touch = p.CanTouch, Anchored = p.Anchored, Shape = p.Shape, Transparency = p.Transparency })
		end
	end
	ringFinish.Dress(model)
	for _, old in originals do
		local p = old.Part
		check("Sanctuary finish preserves " .. old.Name .. " physics", p.Parent == model and p.Name == old.Name and p.Size == old.Size and p.CFrame == old.Frame
			and p.CanCollide == old.Collide and p.CanQuery == old.Query and p.CanTouch == old.Touch and p.Anchored == old.Anchored and p.Shape == old.Shape)
		if old.Name:match("^Barrier") then check("Sanctuary finish preserves barrier visibility", p.Transparency == old.Transparency) end
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not known[p] then
			check("Sanctuary decoration never collides or answers queries", not p.CanCollide and not p.CanQuery and not p.CanTouch)
		end
	end
end }
local Colosseum = module("src/server/Services/ColosseumService.luau")
local Wagers = module("src/server/Services/WagerService.luau")

local spectator, duelA, duelB = join(7, "Watcher"), join(8, "Ashen"), join(9, "Jade")
assert(engine:Transaction(8, function(p) p.attributes.Strength = 40; p.attributes.Vigor = 30 end)) -- a grinded story build
local promenade = World.Sanctuary.Promenade
local centre = V3.new(promenade.X, promenade.Y, promenade.Z)
local function onThreshold(slot: number) return centre + V3.new(if slot == 1 then 3 else -3, 3.2, if slot == 1 then 20 else -20) end
stand(7, centre + V3.new(40, 15, 0)); stand(8, onThreshold(1)); stand(9, onThreshold(2))
Wagers.Start(Colosseum)
Colosseum.Start()
local function tick(seconds: number) local finish = clock + seconds; while clock < finish do clock += 0.3; heartbeat:Fire(0.3); task.wait(0) end end
local function intent(player, payload) remotes.ColosseumIntent.OnServerEvent:Fire(player, payload); task.wait(0) end
local function wager(match, fighter, amount) remotes.WagerIntent.OnServerEvent:Fire(spectator, { action = "Wager", match = match, fighter = fighter, amount = amount }); task.wait(0); clock += 1 end
local function sent(id, action) local hit; for _, s in remotes.ColosseumIntent.Sent do if s.To == id and s.P.action == action then hit = s.P end end; return hit end
local function cue(kind) local hit; for _, c in cues do if c.Kind == kind then hit = c.Data end end; return hit end
local function live() local id; for m, s in started do if not ended[m] then id = m end end; return id end
local function qi(id) return engine:Get(id).qiEssence end

-- 1. Ranked: queue, pairing, journal + inboxes, normalized builds, countdown and wager closure.
intent(duelA, { action = "Enqueue" }); intent(duelB, { action = "Enqueue" }); tick(0.6)
local ranked = live()
check("two duelists on the threshold are paired into a ranked match", ranked ~= nil and started[ranked].Mode == "Ranked1v1")
local JOURNAL = "AsuraMatches_v1:Match_"
check("the match is journaled and both inboxes hold it before the bell", data[JOURNAL .. ranked] and data[JOURNAL .. ranked].state == "Active" and engine:Get(8).pendingMatches[ranked] and engine:Get(9).pendingMatches[ranked])
local found = sent(8, "MatchFound")
check("both duelists receive the countdown with a normalized level", found and sent(9, "MatchFound") and found.level == sent(9, "MatchFound").level and found.starts > clock)
local statsA, statsB = applied[8], applied[9]
check("ranked applies normalized stats: a grinded build gains nothing", statsA and statsB and statsA.Ranked and statsA.Stats.MaxHP == statsB.Stats.MaxHP and statsA.Stats.MaxHP ~= nil)
check("hooks serve normalized stats during the match", type(hooks.Stats(8)) == "table" and duelA.Attributes.AsuraArenaNormalized == true)
local bank = qi(7)
wager(ranked, 8, 100)
check("a spectator wager escrows before the bell", qi(7) == bank - 100 and engine:Get(7).arenaWagers[ranked])
remotes.WagerIntent.OnServerEvent:Fire(duelB, { action = "Wager", match = ranked, fighter = 9, amount = 100 }); task.wait(0)
check("a duelist cannot wager on their own match", next(engine:Get(9).arenaWagers) == nil)
tick(12.5)
local before = qi(7); wager(ranked, 9, 100)
check("the opening bell closes wagering", qi(7) == before)
-- KO and settlement.
started[ranked].Done(ranked, 8, false, 1, {})
tick(4)
check("the winner's ELO rises and the loser's falls exactly once", engine:Get(8).colosseum.Wins == 1 and engine:Get(9).colosseum.Losses == 1 and engine:Get(8).elo > 1000 and engine:Get(9).elo < 1000)
check("inboxes are cleared after settlement", engine:Get(8).pendingMatches[ranked] == nil and engine:Get(9).pendingMatches[ranked] == nil)
tick(6)
check("the winning wager pays 1.8x once", qi(7) == bank + 80)
check("Colosseum.Recover after settlement duplicates nothing", Colosseum.Recover(8) and engine:Get(8).colosseum.Wins == 1)
check("story stats return after the match", hooks.Stats(8) == "story:8" and ended[ranked] ~= nil)

-- 2. Open (casual) builds: a challenge keeps story stats and moves no rating.
stand(8, onThreshold(1)); stand(9, onThreshold(2)); tick(3)
intent(duelA, { action = "Challenge", target = 9 })
local offer = sent(9, "Challenge")
intent(duelB, { action = "Respond", challenge = offer and offer.challenge or "x", accept = true })
local casual = live()
check("a challenge starts an Open spar", casual ~= nil and started[casual].Mode == "Casual1v1")
check("Open builds keep the story stats", hooks.Stats(8) == "story:8" and duelA.Attributes.AsuraArenaNormalized == false)
local elo = engine:Get(8).elo
started[casual].Done(casual, 9, false, 1, {}); tick(4)
check("an Open spar moves no rating", engine:Get(8).elo == elo and engine:Get(9).colosseum.Wins == 0)

-- 3. Disconnect mid-match: forfeit, spectator settlement, and the leaver's inbox settles on rejoin.
stand(8, onThreshold(1)); stand(9, onThreshold(2)); tick(3)
intent(duelA, { action = "Enqueue" }); intent(duelB, { action = "Enqueue" }); tick(0.6)
local forfeit = live()
bank = qi(7); wager(forfeit, 9, 100); tick(12.5)
Colosseum.Disconnect(9); assert(engine:Release(9)); leave(9)
tick(4)
check("a leaver forfeits: the remaining duelist wins once", engine:Get(8).colosseum.Wins == 2)
tick(6)
check("a wager on the leaver is lost, not refunded", qi(7) == bank - 100)
join(9, "Jade"); stand(9, onThreshold(2))
check("the leaver's pending result settles on rejoin, once", engine:Get(9).pendingMatches[forfeit] ~= nil and Colosseum.Recover(9)
	and engine:Get(9).colosseum.Losses == 2 and engine:Get(9).pendingMatches[forfeit] == nil and Colosseum.Recover(9) and engine:Get(9).colosseum.Losses == 2)

-- 4. A leave while the match is still being set up (inbox write in flight): no result, no rating.
tick(3); local cuesBefore = #cues
onTransaction = function(id) if id == 9 and players[9] then onTransaction = nil; Colosseum.Disconnect(9); leave(9) end end
intent(duelA, { action = "Enqueue" }); intent(duelB, { action = "Enqueue" }); tick(8) -- the ELO window widens 5/s
local resultCue = false
for i = cuesBefore + 1, #cues do if cues[i].Kind == "ColosseumResult" then resultCue = true end end
check("a leave during setup broadcasts no forfeit for a match that never began", not resultCue)
check("a leave during setup strands nobody: the remaining fighter is free and still queued", onTransaction == nil and not Colosseum.IsInMatch(8) and live() == nil and engine:Get(8).colosseum.Wins == 2)
local setupJournal = nil
for key, value in data do if string.find(key, JOURNAL, 1, true) and value.state == "Cancelled" then setupJournal = value end end
check("its journal closes Cancelled and no inbox entry remains", setupJournal ~= nil and next(engine:Get(8).pendingMatches) == nil)
assert(engine:Release(9)); join(9, "Jade"); stand(9, onThreshold(2)); Colosseum.Recover(9)

-- 5. Match journal unavailable: pairing is refused cleanly and nobody is stranded.
intent(duelA, { action = "Dequeue" }); tick(3); down["AsuraMatches_v1:"] = true
intent(duelA, { action = "Enqueue" }); intent(duelB, { action = "Enqueue" }); tick(8)
check("a journal outage starts no ranked match", live() == nil and not Colosseum.IsInMatch(8) and not Colosseum.IsInMatch(9))
check("and leaves no inbox entry behind", next(engine:Get(8).pendingMatches) == nil and next(engine:Get(9).pendingMatches) == nil)
down["AsuraMatches_v1:"] = nil; intent(duelA, { action = "Dequeue" }); intent(duelB, { action = "Dequeue" })

-- 6. Shutdown during a ranked match with a wager: cancelled, no rating, stake refunded.
tick(3)
intent(duelA, { action = "Enqueue" }); intent(duelB, { action = "Enqueue" }); tick(8)
local shut = live()
bank = qi(7); wager(shut, 8, 100)
local winsA, lossesB = engine:Get(8).colosseum.Wins, engine:Get(9).colosseum.Losses
Colosseum.Close(); Wagers.Close(); task.wait(1)
check("shutdown cancels the ranked match without rating changes", shut ~= nil and engine:Get(8).colosseum.Wins == winsA and engine:Get(9).colosseum.Losses == lossesB
	and data[JOURNAL .. shut].state == "Cancelled")
Wagers.Recover(7)
check("shutdown refunds the spectator's stake", qi(7) == bank)
check("no Colosseum inbox entry survives shutdown", next(engine:Get(8).pendingMatches) == nil and next(engine:Get(9).pendingMatches) == nil)
Colosseum.Destroy(); Wagers.Destroy()
check("Destroy restores the story hooks", hooks == baseHooks)

print(string.format("colosseum runtime: %d passed, %d failed (local mocks; live DataStore and multi-client not exercised)", passed, failed))
if failed > 0 then error("colosseum runtime regression failed") end

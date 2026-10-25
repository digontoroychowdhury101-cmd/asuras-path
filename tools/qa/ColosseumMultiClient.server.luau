--!nonstrict
-- Unmapped Studio-only harness (follow-up 23). Three real local clients through StudioTestService:
-- two duelists and a spectator. Drives the production Colosseum/Wager remotes from the clients and
-- reads authoritative state here. Evidence type: seeded Studio diagnostic on the in-memory Studio
-- mock store (placement by teleport, intents fired by the client scripts, no physical input). It
-- says nothing about live DataStore durability. Launch: insert this, the client script and a
-- RemoteEvent "ColoQA" in ReplicatedStorage into the open place (do not save), then from the
-- Command Bar: game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(3, {}).
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local STS = game:GetService("StudioTestService")
local Http = game:GetService("HttpService")
local event = RS:WaitForChild("ColoQA", 15)
if not event then return end

local ready, observed, wagerMsgs, reports = {}, {}, {}, {}
event.OnServerEvent:Connect(function(p, op, data)
	if op == "Ready" then ready[p.UserId] = data
	elseif op == "Observed" then observed[p.UserId] = observed[p.UserId] or {}; table.insert(observed[p.UserId], data)
	elseif op == "Wager" then wagerMsgs[p.UserId] = wagerMsgs[p.UserId] or {}; table.insert(wagerMsgs[p.UserId], data)
	elseif op == "Report" then reports[p.UserId] = data end
end)

local result = { kind = "Seeded Studio diagnostic: 3 local clients (2 duelists + spectator), Studio mock store; no physical input, no live service", checks = {} }
local function check(ok, name, details)
	table.insert(result.checks, { name = name, passed = ok == true, details = details })
	print(string.format("[ColoQA] %s %s %s", if ok then "PASS" else "FAIL", name, if details ~= nil then Http:JSONEncode(details) else ""))
end
local function untilTrue(fn, seconds)
	local deadline = os.clock() + seconds
	repeat if fn() then return true end task.wait(0.2) until os.clock() > deadline
	return false
end
local function saw(id, pred)
	for _, m in observed[id] or {} do if pred(m) then return m end end
	return nil
end

local ok, err = xpcall(function()
	assert(untilTrue(function() return workspace:GetAttribute("AsuraReady") and #Players:GetPlayers() == 3 end, 240), "three players")
	local S = game.ServerScriptService.AsurasPath.Services
	local C = require(S.CharacterService)
	local Coliseum = require(S.ColosseumService)
	local Wager = require(S.WagerService)
	local P = require(S.PersistenceService)
	local Defs = require(RS.AsurasPath.Shared.WorldDefinitions)
	local list = Players:GetPlayers(); table.sort(list, function(a, b) return a.UserId < b.UserId end)
	local A, B, Spec = list[1], list[2], list[3]
	assert(untilTrue(function() return ready[A.UserId] and ready[B.UserId] and ready[Spec.UserId] end, 300), "client bootstraps")
	check(true, "three real clients booted", { A = A.UserId, B = B.UserId, S = Spec.UserId, mock = P.IsMock })

	-- Both rings exist and are reachable by teleport placement (diagnostic).
	local rings = {}
	for _, r in Coliseum.GetRings() do rings[r.Id or r.Name] = r; end
	local names = {}; for k in rings do table.insert(names, k) end
	check(rings.Ring_SanctuaryPromenade ~= nil and rings.Ring_OctagonOfAsh ~= nil, "both rings registered", names)

	local ring = rings.Ring_SanctuaryPromenade
	local center = ring.Center
	-- Challenges need both fighters on the threshold band (ColosseumService.onThreshold).
	local function thresh(player, slot)
		local frame = CFrame.new(center) * CFrame.Angles(0, math.rad(ring.Yaw), 0)
		local d = ring.Apothem + 1 + ring.Band * 0.5
		local pos = (frame * CFrame.new(if slot == 1 then 3 else -3, 3.2, if slot == 1 then d else -d)).Position
		local f = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		C.Teleport(player.UserId, f); event:FireClient(player, "Position", f)
	end
	thresh(A, 1); thresh(B, 2)
	local promenade = Defs.Sanctuary.Promenade
	local booth = Vector3.new(promenade.X + 30, promenade.Y + 13, promenade.Z)
	local boothFrame = CFrame.new(booth); C.Teleport(Spec.UserId, boothFrame); event:FireClient(Spec, "Position", boothFrame)
	task.wait(2)

	local qi0 = P.Get(Spec.UserId).qiEssence
	-- Casual challenge through the production remote.
	event:FireClient(A, "Challenge", B.UserId)
	local allocated = untilTrue(function() return Coliseum.IsInMatch(A.UserId) and Coliseum.IsInMatch(B.UserId) end, 20)
	check(allocated, "challenge / accept allocates both duelists", { a = saw(A.UserId, function(m) return m.action == "ChallengeResult" end) })
	check(A:GetAttribute("AsuraArenaNormalized") == false, "casual (Open) duel keeps build stats", A:GetAttribute("AsuraArenaNormalized"))

	-- Spectator escrow before the bell; duelist refused.
	event:FireClient(Spec, "WagerRefresh")
	local matchId
	untilTrue(function()
		for _, m in wagerMsgs[Spec.UserId] or {} do if m.action == "Panel" and m.matches and m.matches[1] then matchId = m.matches[1].id; return true end end
		return false
	end, 10)
	check(matchId ~= nil, "spectator panel lists the open duel", matchId)
	if matchId then
		event:FireClient(Spec, "Wager", { match = matchId, fighter = A.UserId, amount = 100 })
		event:FireClient(A, "Wager", { match = matchId, fighter = A.UserId, amount = 100 })
		task.wait(2)
		local bet = P.Get(Spec.UserId).arenaWagers[matchId]
		check(bet and bet.State == "Pending" and P.Get(Spec.UserId).qiEssence == qi0 - 100, "stake escrowed before the bell", { qi0 = qi0, qi = P.Get(Spec.UserId).qiEssence, bet = bet })
		check(P.Get(A.UserId).arenaWagers[matchId] == nil, "a duelist cannot wager on their own duel")
		-- A duplicate request for the same duel is refused (one wager per duel).
		event:FireClient(Spec, "Wager", { match = matchId, fighter = B.UserId, amount = 50 })
		task.wait(1.5)
		check(P.Get(Spec.UserId).qiEssence == qi0 - 100, "duplicate wager refused, no second escrow", P.Get(Spec.UserId).qiEssence)
	end

	check(untilTrue(function() return saw(A.UserId, function(m) return m.phase == "Fighting" end) and saw(B.UserId, function(m) return m.phase == "Fighting" end) end, 30), "countdown reaches Fighting on both duelists")
	if matchId then
		local before = P.Get(Spec.UserId).qiEssence
		event:FireClient(Spec, "Wager", { match = matchId, fighter = B.UserId, amount = 50 })
		task.wait(1.5)
		check(P.Get(Spec.UserId).qiEssence == before, "wager rejected once the bell has rung", P.Get(Spec.UserId).qiEssence)
	end
	-- Authoritative damage from a client attack.
	local a, b = C.GetEntity(A.UserId), C.GetEntity(B.UserId)
	local y = center.Y + 3.4
	C.Teleport(A.UserId, CFrame.lookAt(Vector3.new(center.X, y, center.Z + 1.65), Vector3.new(center.X, y, center.Z - 1.65)))
	C.Teleport(B.UserId, CFrame.lookAt(Vector3.new(center.X, y, center.Z - 1.65), Vector3.new(center.X, y, center.Z + 1.65)))
	task.wait(0.7); event:FireClient(A, "Position", a.Root.CFrame); event:FireClient(B, "Position", b.Root.CFrame); task.wait(0.7)
	local hp = b.Fighter.ActiveHP
	event:FireClient(A, "Attack", a.LastSeq or 0) -- seq must follow the server's (anti-replay gap)
	check(untilTrue(function() return b.Fighter.ActiveHP < hp end, 12), "client attack deals authoritative damage", { before = hp, after = b.Fighter.ActiveHP })
	-- Target/lighting isolation: the spectator is not in the duel and keeps story lighting attributes.
	event:FireAllClients("Report"); untilTrue(function() return reports[A.UserId] and reports[B.UserId] and reports[Spec.UserId] end, 8)
	check(reports[Spec.UserId] and reports[Spec.UserId].duel == nil and reports[A.UserId] and reports[A.UserId].duel ~= nil, "spectator stays outside the duel (no duel attribute)", { spec = reports[Spec.UserId], a = reports[A.UserId] and reports[A.UserId].duel })
	check(reports[Spec.UserId] and reports[A.UserId] and reports[Spec.UserId].lighting == reports[A.UserId].lighting, "Promenade duel leaves the shared Sanctuary lighting unchanged (no duel profile leaks)", { spec = reports[Spec.UserId] and reports[Spec.UserId].lighting, a = reports[A.UserId] and reports[A.UserId].lighting })

	-- B leaves mid-match: A wins by forfeit; the spectator's winning stake settles exactly once.
	event:FireClient(B, "Leave")
	check(untilTrue(function() return #Players:GetPlayers() == 2 and not Coliseum.IsInMatch(A.UserId) end, 25), "mid-match leave releases the survivor")
	check(A:GetAttribute("AsuraColosseum") == nil, "survivor restored after the leave")
	if matchId then
		check(untilTrue(function() local bet = P.Get(Spec.UserId).arenaWagers[matchId]; return bet and bet.State == "Settled" end, 20), "spectator wager settled after the forfeit")
		local after = P.Get(Spec.UserId).qiEssence
		check(after == qi0 - 100 + 180, "winning stake paid 1.8x once", { qi0 = qi0, after = after })
		Wager.Recover(Spec.UserId); task.wait(1); Wager.Recover(Spec.UserId); task.wait(1)
		check(P.Get(Spec.UserId).qiEssence == after, "repeated recovery pays nothing more", P.Get(Spec.UserId).qiEssence)
		local settles = 0
		for _, m in wagerMsgs[Spec.UserId] or {} do if m.action == "Settlement" then settles += 1 end end
		check(settles == 1, "exactly one settlement notice", settles)
	end

	-- Ranked queue with the remaining two: normalisation, then a leave during setup.
	thresh(A, 1); thresh(Spec, 2); task.wait(1.5)
	local rankedOpen = Coliseum.RankedOpen()
	check(true, "ranked queue state", { rankedOpen = rankedOpen })
	if rankedOpen then
		event:FireClient(A, "Enqueue"); event:FireClient(Spec, "Enqueue")
		local paired = untilTrue(function() return Coliseum.IsInMatch(A.UserId) and Coliseum.IsInMatch(Spec.UserId) end, 30)
		check(paired, "two queued players are paired")
		if paired then
			check(A:GetAttribute("AsuraArenaNormalized") == true and Spec:GetAttribute("AsuraArenaNormalized") == true, "ranked fighters are normalised", { a = A:GetAttribute("AsuraArenaNormalized"), s = Spec:GetAttribute("AsuraArenaNormalized") })
			event:FireClient(A, "Leave")
			check(untilTrue(function() return #Players:GetPlayers() == 1 and not Coliseum.IsInMatch(Spec.UserId) end, 25), "leave during setup releases the remaining fighter")
			check(Spec:GetAttribute("AsuraColosseum") == nil, "remaining fighter restored after setup leave")
			local m = saw(Spec.UserId, function(m) return m.action == "Result" or m.action == "Ended" or m.result ~= nil end)
			check(true, "remaining fighter's last arena message", m)
		end
	end
end, debug.traceback)

result.passed = ok
result.error = if ok then nil else err
local failed = 0
for _, c in result.checks do if not c.passed then failed += 1 end end
result.failed = failed
local encoded = Http:JSONEncode(result)
print("[ColoQA RESULT] " .. encoded)
pcall(function() STS:EndTest(encoded) end)

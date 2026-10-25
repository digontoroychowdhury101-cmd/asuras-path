--!nonstrict
-- Unmapped Studio-only harness (post-F26 step 2, omnidirectional combat). Two real local clients through
-- StudioTestService in a casual Colosseum duel on the Promenade; both fighters strike through the shared
-- CharacterService path. Clients fire the production ActionIntent remote with their own aim; the server
-- places the fighters, forces Jian on both and cues the defender's dodge/deflect from the attacker's
-- windup. Evidence type: 2-client Studio diagnostic (seeded placement and cue timing, real client
-- remotes and client-owned bodies; no human input). Launch: insert this, OmniPvP.client.luau (as a
-- LocalScript in StarterPlayerScripts) and a RemoteEvent "OmniPvPQA" in ReplicatedStorage into the open
-- place (never save), then run game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, {}).
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local STS = game:GetService("StudioTestService")
local Http = game:GetService("HttpService")
local event = RS:WaitForChild("OmniPvPQA", 15)
if not event then return end

local ready, observed = {}, {}
event.OnServerEvent:Connect(function(p, op, data)
	if op == "Ready" then ready[p.UserId] = data
	elseif op == "Observed" then observed[p.UserId] = observed[p.UserId] or {}; table.insert(observed[p.UserId], data) end
end)
local result = { kind = "2-client Studio diagnostic: casual Promenade duel, production ActionIntent remotes, seeded placement/cues; no human input", checks = {} }
local function check(ok, name, details)
	table.insert(result.checks, { name = name, passed = ok == true, details = details })
	print(string.format("[OmniPvP] %s %s %s", if ok then "PASS" else "FAIL", name, if details ~= nil then Http:JSONEncode(details) else ""))
end
local function untilTrue(fn, seconds)
	local deadline = os.clock() + seconds
	repeat if fn() then return true end task.wait(0.1) until os.clock() > deadline
	return false
end

local ok, err = xpcall(function()
	local joined = untilTrue(function() return workspace:GetAttribute("AsuraReady") and #Players:GetPlayers() >= 2 end, 420)
	assert(joined, string.format("two players (have %d, server ready %s)", #Players:GetPlayers(), tostring(workspace:GetAttribute("AsuraReady"))))
	local S = game.ServerScriptService.AsurasPath.Services
	local C = require(S.CharacterService)
	local Coliseum = require(S.ColosseumService)
	local list = Players:GetPlayers(); table.sort(list, function(a, b) return a.UserId < b.UserId end)
	local A, B = list[1], list[2]
	assert(untilTrue(function() return ready[A.UserId] and ready[B.UserId] end, 300), "client bootstraps")
	check(true, "two real clients booted", { A = A.UserId, B = B.UserId })

	local events = {}
	C.Subscribe(function(e) table.insert(events, { k = e.Kind, s = e.Source, t = e.Target, v = e.Value }) end)
	local function count(kind, source, target, from)
		local n = 0
		for i = from + 1, #events do
			local e = events[i]
			if e.k == kind and (source == nil or e.s == source) and (target == nil or e.t == target) then n += 1 end
		end
		return n
	end

	local ring
	for _, r in Coliseum.GetRings() do if (r.Id or r.Name) == "Ring_SanctuaryPromenade" then ring = r end end
	assert(ring, "Promenade ring")
	local center = ring.Center
	local function thresh(player, slot)
		local frame = CFrame.new(center) * CFrame.Angles(0, math.rad(ring.Yaw), 0)
		local d = ring.Apothem + 1 + ring.Band * 0.5
		local pos = (frame * CFrame.new(if slot == 1 then 3 else -3, 3.2, if slot == 1 then d else -d)).Position
		local f = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		C.Teleport(player.UserId, f); event:FireClient(player, "Position", f)
	end
	thresh(A, 1); thresh(B, 2)
	task.wait(2)
	event:FireClient(A, "Challenge", B.UserId)
	check(untilTrue(function() return Coliseum.IsInMatch(A.UserId) and Coliseum.IsInMatch(B.UserId) end, 20), "challenge / accept allocates both duelists")
	check(untilTrue(function()
		local function fighting(p) for _, m in observed[p.UserId] or {} do if m.phase == "Fighting" then return true end end return false end
		return fighting(A) and fighting(B)
	end, 30), "countdown reaches Fighting on both duelists")

	local a, b = C.GetEntity(A.UserId), C.GetEntity(B.UserId)
	C.ForceWeapon(A.UserId, "Jian"); C.ForceWeapon(B.UserId, "Jian")
	a.Fighter.KOProtected, b.Fighter.KOProtected = true, true
	local y = center.Y + 3.4
	local function reset()
		for _, e in { a, b } do
			local f = e.Fighter
			f.ActiveHP, f.RecoverableHP, f.PermanentDeficit, f.Posture, f.Stamina = f.MaxHP, 0, 0, 0, f.MaxStamina
		end
	end
	-- A at +Z facing -Z; B `gap` studs away at `deg` degrees round from A's facing.
	local function place(gap, deg)
		local pa = Vector3.new(center.X, y, center.Z + 2)
		local r = math.rad(deg)
		local pb = pa + Vector3.new(-math.sin(r), 0, -math.cos(r)) * gap
		local fa = CFrame.lookAt(pa, pa + Vector3.new(0, 0, -1))
		local fb = CFrame.lookAt(pb, Vector3.new(pa.X, pb.Y, pa.Z))
		C.Teleport(A.UserId, fa); C.Teleport(B.UserId, fb)
		event:FireClient(A, "Position", fa); event:FireClient(B, "Position", fb)
		task.wait(0.6)
		reset()
	end
	local function act(player, action, x, z)
		local e = C.GetEntity(player.UserId)
		event:FireClient(player, "Act", { action = action, x = x, z = z, seq = e and e.LastSeq or 0 })
	end
	local function idle(e) return untilTrue(function() return e.Fighter.State == "Idle" end, 3) end
	local function toward(from, to)
		local d = to.Root.Position - from.Root.Position
		local flat = Vector3.new(d.X, 0, d.Z).Unit
		return flat.X, flat.Z
	end

	-- 1. A committed thrust at B lands; the same thrust aimed 35 degrees beside B whiffs.
	place(4.5, 0); idle(a)
	local mark, hp = #events, b.Fighter.ActiveHP
	act(A, "Light", toward(a, b))
	check(untilTrue(function() return count("Hit", A.UserId, B.UserId, mark) + count("CounterHit", A.UserId, B.UserId, mark) > 0 end, 3), "aimed Jian light hits the other client", { before = hp, after = b.Fighter.ActiveHP })
	place(4.5, 0); idle(a)
	mark = #events
	local x, z = toward(a, b)
	local r = math.rad(35)
	act(A, "Light", x * math.cos(r) - z * math.sin(r), x * math.sin(r) + z * math.cos(r))
	task.wait(0.6)
	check(count("Whiff", A.UserId, nil, mark) > 0 and count("Hit", A.UserId, B.UserId, mark) == 0, "the same light aimed 35 degrees beside B whiffs (true miss)", { whiffs = count("Whiff", A.UserId, nil, mark) })
	local yaw = tonumber(string.match(a.Model:GetAttribute("AsuraStrike") or "", "^[^|]+|[^|]+|[^|]+|([^|]+)"))
	check(yaw ~= nil, "A's committed strike record replicated", a.Model:GetAttribute("AsuraStrike"))

	-- 2. Spin exploit: B stands behind A; A aims away and its client spins the body to face B mid-swing.
	place(3.5, 180); idle(a)
	mark = #events
	act(A, "Light", 0, -1)
	event:FireClient(A, "Spin", { target = b.Root.Position, seconds = 0.4 })
	task.wait(0.7)
	check(count("Hit", A.UserId, B.UserId, mark) == 0 and count("Whiff", A.UserId, nil, mark) > 0, "a client spinning its body mid-swing cannot strike the fighter behind it", { hits = count("Hit", A.UserId, B.UserId, mark), whiffs = count("Whiff", A.UserId, nil, mark) })

	-- 3. Dodge and deflect against A's heavy, cued from the server when A's windup is seen.
	local function cued(action, lead, tries)
		local good, outcomes = 0, {}
		for _ = 1, tries do
			place(4.5, 0); idle(a); idle(b)
			mark = #events
			act(A, "Heavy", toward(a, b))
			if untilTrue(function() return a.Fighter.State == "Startup" end, 2) then
				local impact = a.Fighter.MoveStart + a.Fighter.Move.Timing.StartupSeconds
				untilTrue(function() return C.Now() >= impact - lead end, 1)
				if action == "Dash" then
					local sx, sz = toward(b, a)
					act(B, "Dash", -sz, sx)
				else
					act(B, "Deflect")
				end
			end
			task.wait(0.8)
			local hit = count("Hit", A.UserId, B.UserId, mark) + count("CounterHit", A.UserId, B.UserId, mark)
			local okay = if action == "Dash" then hit == 0 and (count("Evade", B.UserId, A.UserId, mark) + count("Whiff", A.UserId, nil, mark)) > 0
				else count("DeflectSpark", B.UserId, A.UserId, mark) > 0
			if okay then good += 1 end
			table.insert(outcomes, string.format("hit=%d evade=%d whiff=%d deflect=%d block=%d", hit, count("Evade", B.UserId, A.UserId, mark), count("Whiff", A.UserId, nil, mark), count("DeflectSpark", B.UserId, A.UserId, mark), count("Block", B.UserId, A.UserId, mark)))
		end
		return good, outcomes
	end
	local dodges, dodgeLog = cued("Dash", 0.16, 3)
	check(dodges >= 2, "B's client dodge, cued at A's heavy windup, avoids the strike", dodgeLog)
	local deflects, deflectLog = cued("Deflect", 0.09, 4)
	check(deflects >= 1, "B's client deflect, cued at A's heavy windup, parries", deflectLog)

	-- 4. Air: one light and no heavy per airtime; the landing costs move-less recovery.
	place(6, 0); idle(a)
	mark = #events
	event:FireClient(A, "Jump")
	untilTrue(function() return a.Omni.Air.Airborne end, 1.5)
	local airborne = a.Omni.Air.Airborne
	act(A, "Light", 0, -1); task.wait(0.18); act(A, "Light", 0, -1); task.wait(0.05); act(A, "Heavy", 0, -1)
	task.wait(0.15)
	local attacks, owed = a.Omni.Air.Attacks, a.Omni.Air.Landing
	local landed = untilTrue(function() return a.Fighter.State == "Recovery" and a.Fighter.Move == nil end, 2)
	check(airborne and attacks == 1 and owed and landed, "one air light only, then a landing recovery", { airborne = airborne, attacks = attacks, owed = owed, landed = landed })
	check(true, "air sequence strikes recorded (information)", { whiffs = count("Whiff", A.UserId, nil, mark), hits = count("Hit", A.UserId, B.UserId, mark) })

	check(true, "network round trip (Studio local)", { A = A:GetNetworkPing(), B = B:GetNetworkPing() })
end, debug.traceback)

result.passed = ok
result.error = if ok then nil else err
local failed = 0
for _, c in result.checks do if not c.passed then failed += 1 end end
result.failed = failed
local encoded = Http:JSONEncode(result)
print("[OmniPvP RESULT] " .. encoded)
pcall(function() STS:EndTest(encoded) end)

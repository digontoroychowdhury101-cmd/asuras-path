--!nonstrict
-- Unmapped Studio-only harness (lane R2-5): Grandmaster Shen with TWO real local clients. Evidence type: seeded Studio
-- diagnostic (placement by teleport, HP/KO seeded server-side, client entry by Humanoid:MoveTo and ProximityPrompt hold,
-- no physical input). Observes the live gate/fight rules in WorldService; changes none.
-- Design under test (source: WorldService.luau updateGates / traverseGate / startFight / PlayerRemoving):
--   * A walks in through the trigger (armed after being seen outside the arena) -> startFight seals the gate, A.AsuraEncounter set.
--   * B outside during the fight cannot join: the prompt refuses with "ArenaOccupied" (toast text in InterfaceController.REASONS),
--     a walker is blocked by the sealed wall or expelled to Gate.Outside (updateGates, non-participant inside Arena).
--   * A KO/leave -> living == 0 -> Reset: wall unsealed, Shen despawned, AsuraEncounter nil. A fresh fight can then start.
-- Launch (local copy only, never saved): inject this + ShenMultiClient.client.luau + a RemoteEvent "ShenQA" in ReplicatedStorage,
-- then Test > Clients and Servers > Local Server, 2 players (or StudioTestService:ExecuteMultiplayerTestAsync(2, {})).
-- Results: "[ShenMC] PASS|FAIL|INFO ..." lines and one "[ShenMC RESULT] {json}" in the server output.
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local STS = game:GetService("StudioTestService")
local Http = game:GetService("HttpService")
local event = RS:WaitForChild("ShenQA", 15)
if not event then return end

local ready, reports, promptInfos = {}, {}, {}
event.OnServerEvent:Connect(function(p, op, data)
	if op == "Ready" then ready[p.UserId] = true
	elseif op == "Report" then reports[p.UserId] = data
	elseif op == "PromptInfo" then table.insert(promptInfos, { user = p.UserId, data = data }) end
end)

local result = { kind = "Seeded Studio diagnostic: Shen with 2 local clients; no live service", checks = {}, promptInfos = promptInfos }
local function check(ok, name, details)
	table.insert(result.checks, { name = name, passed = ok == true, details = details })
	print(string.format("[ShenMC] %s %s %s", if ok then "PASS" else "FAIL", name, if details ~= nil then Http:JSONEncode(details) else ""))
end
local function info(name, details)
	print(string.format("[ShenMC] INFO %s %s", name, if details ~= nil then Http:JSONEncode(details) else ""))
end
local function untilTrue(fn, seconds)
	local deadline = os.clock() + seconds
	repeat if fn() then return true end task.wait(0.2) until os.clock() > deadline
	return false
end
local function report(p)
	reports[p.UserId] = nil
	event:FireClient(p, "Report")
	untilTrue(function() return reports[p.UserId] ~= nil end, 10)
	return reports[p.UserId] or {}
end

local ok, err = xpcall(function()
	assert(untilTrue(function() return workspace:GetAttribute("AsuraReady") and #Players:GetPlayers() == 2 end, 900), "two players")
	local S = game.ServerScriptService.AsurasPath.Services
	local C = require(S.CharacterService)
	local AI = require(S.AIService)
	local World = require(RS.AsurasPath.Shared.WorldDefinitions)
	local gate = World.FogGates.Gate_AshColosseum
	local boss = World.Bosses[gate.Boss]
	local list = Players:GetPlayers(); table.sort(list, function(a, b) return a.UserId < b.UserId end)
	local A, B = list[1], list[2]
	assert(untilTrue(function() return ready[A.UserId] and ready[B.UserId] and C.GetEntity(A.UserId) and C.GetEntity(B.UserId) end, 300), "client bootstraps")
	check(true, "two real clients booted", { A = A.UserId, B = B.UserId })
	-- The overworld ground guard bounces players standing on unwritten terrain to a ready altar; wait for generation first.
	local OW = require(S.OverworldService)
	local gen = untilTrue(function() local st = OW.Stats(); return st.Total ~= nil and st.Done >= st.Total end, 900)
	check(gen, "overworld terrain generation finished before the scenarios", { done = OW.Stats().Done, total = OW.Stats().Total })

	local function inBounds(box, p)
		return math.abs(p.X - box.Center.X) <= box.Size.X / 2 and math.abs(p.Y - box.Center.Y) <= box.Size.Y / 2 and math.abs(p.Z - box.Center.Z) <= box.Size.Z / 2
	end
	local wall = workspace:FindFirstChild("FogGate_" .. gate.Id, true)
	local function sealed() return wall ~= nil and wall:GetAttribute("Sealed") == true end
	local function present() return AI.IsBossPresent(boss.Id) end
	local function pos(p) return C.GetEntity(p.UserId).Root.Position end
	local function shen()
		for _, e in C.Entities() do
			if e.Kind == "Enemy" and e.Model:GetAttribute("AsuraLookKey") == boss.Id then return e end
		end
		return nil
	end
	check(wall ~= nil and not sealed(), "gate wall found and open before the fight", wall and wall:GetFullName())

	-- Outside the arena on the approach side: Gate.Outside direction, 10 studs short of the wall (inside prompt reach), faced at it.
	local pl = Vector3.new(gate.Placement.X, gate.Placement.Y, gate.Placement.Z)
	local out = Vector3.new(gate.Outside.X, gate.Outside.Y, gate.Outside.Z)
	local dir = Vector3.new(out.X - pl.X, 0, out.Z - pl.Z).Unit
	local trigger = Vector3.new(gate.Trigger.Center.X, out.Y, gate.Trigger.Center.Z)
	local function stand(p, distance, side)
		local at = pl + dir * distance + Vector3.new(side, 0, 0)
		local f = CFrame.lookAt(Vector3.new(at.X, out.Y + 0.5, at.Z), Vector3.new(pl.X, out.Y + 0.5, pl.Z))
		C.Teleport(p.UserId, f); event:FireClient(p, "Position", f)
	end
	-- Interact is an unbuffered action: the client fires the real ActionIntent packet (the E key with no visible prompt); seq continues the server counter.
	local function intent(p, action) event:FireClient(p, "Intent", action, C.GetEntity(p.UserId).LastSeq + 1) end
	local function walkIn(p, seconds) event:FireClient(p, "MoveTo", trigger, seconds) end

	-- 1. A walks in on foot (armed outside the arena, then reaches the trigger).
	C.GetEntity(A.UserId).Fighter.KOProtected = true
	C.GetEntity(B.UserId).Fighter.KOProtected = true
	stand(A, 40, -6); stand(B, 12, 6)
	task.wait(2.5) -- updateGates ticks arm both (outside the arena)
	check(not inBounds(boss.Arena, pos(A)) and not inBounds(boss.Arena, pos(B)), "both start outside the arena", { a = tostring(pos(A)), b = tostring(pos(B)) })
	walkIn(A, 40)
	local entered = untilTrue(sealed, 45)
	local route = "walk-in"
	if not entered then
		check(false, "A walk-in seals the gate and starts the fight", { a = tostring(pos(A)), trigger = tostring(trigger) })
		stand(A, 12, -6); task.wait(1.5)
		event:FireClient(A, "Prompt") -- fallback so the later checks still run
		entered = untilTrue(sealed, 15)
		route = "prompt (fallback)"
	else
		check(true, "A walk-in seals the gate and starts the fight", { a = tostring(pos(A)) })
	end
	if not entered then error("no fight could be started; later criteria need one") end
	info("entry route used", route)

	-- 2. State while sealed.
	task.wait(1)
	check(A:GetAttribute("AsuraEncounter") == boss.Id, "A AsuraEncounter is Shen", A:GetAttribute("AsuraEncounter"))
	check(B:GetAttribute("AsuraEncounter") == nil, "B (outside) has no AsuraEncounter", B:GetAttribute("AsuraEncounter"))
	check(untilTrue(present, 10), "boss present on the server")
	local e = shen()
	check(e ~= nil, "Shen entity found", e and e.Model:GetFullName())
	info("Shen AI mode (Idle means no line of sight, see 10b terrain plug)", e and e.Model:GetAttribute("AsuraAIMode"))

	-- 3. B outside during A's fight: prompt refusal, walk-in, no joining.
	stand(B, 12, 6); task.wait(1.5)
	B:SetAttribute("AsuraResult", nil)
	event:FireClient(B, "Prompt")
	local function isRefused() return B:GetAttribute("AsuraResult") == "!ArenaOccupied" end
	local refused = untilTrue(isRefused, 6)
	local refuseRoute = "client prompt hold"
	if not refused then -- the client prompt is not "shown" in a headless test client (prompt state in result.promptInfos); use the server Interact intent, the same traverseGate path as the E key with no visible prompt
		refuseRoute = "ActionIntent Interact (prompt hold did not trigger)"
		intent(B, "Interact")
		refused = untilTrue(isRefused, 10)
	end
	check(refused, "B gate interaction is refused with ArenaOccupied (client toast text exists in REASONS)", { route = refuseRoute, result = B:GetAttribute("AsuraResult") })
	walkIn(B, 12)
	task.wait(13)
	check(not inBounds(boss.Arena, pos(B)) or B:GetAttribute("AsuraEncounter") == nil, "B walking at the sealed gate does not end up a participant", { b = tostring(pos(B)), enc = B:GetAttribute("AsuraEncounter") })
	check(B:GetAttribute("AsuraEncounter") == nil and sealed() and A:GetAttribute("AsuraEncounter") == boss.Id, "B cannot join; fight and seal untouched")
	check(not inBounds(boss.Arena, pos(B)), "B is not left inside the arena", tostring(pos(B)))

	-- 4. Per-player replication seen by both clients (Humanoid.Health mirrors Fighter.ActiveHP).
	e = shen()
	local ra, rb = report(A), report(B)
	check(ra.sealed == true and rb.sealed == true, "Sealed replicates to both clients", { a = ra.sealed, b = rb.sealed })
	check(ra.encounter == boss.Id and rb.encounter == nil, "AsuraEncounter per client: A Shen, B none", { a = ra.encounter, b = rb.encounter })
	local before = e.Fighter.ActiveHP
	local dealt = math.min(150, before * 0.25)
	C.ApplyArea(A.UserId, e.Id, dealt, 0, true) -- seeded damage (diagnostic)
	task.wait(1.5)
	local hp, maxHp = e.Fighter.ActiveHP, e.Fighter.MaxHP
	check(hp < before, "server HP dropped after seeded damage", { before = before, after = hp })
	ra, rb = report(A), report(B)
	check(ra.shenFound == true and math.abs((ra.health or -1) - hp) <= 1 and ra.maxHealth == maxHp, "A client sees Shen HP match the server", { server = hp, client = ra.health, max = ra.maxHealth })
	if rb.shenFound == true then
		check(math.abs((rb.health or -1) - hp) <= 1 and rb.maxHealth == maxHp, "B client sees Shen HP match the server", { server = hp, client = rb.health, max = rb.maxHealth })
	elseif workspace.StreamingEnabled then
		info("B client does not have Shen (StreamingEnabled, outside stream radius); replication to B not assessable", { b = tostring(pos(B)), shen = tostring(e.Root.Position) })
	else
		check(false, "B client sees Shen HP match the server", { found = rb.shenFound })
	end

	-- 5. A dies: reset, B untouched.
	local bBefore = pos(B)
	C.GetEntity(A.UserId).Fighter.KOProtected = false
	local ae = C.GetEntity(A.UserId)
	C.ApplyArea(e.Id, ae.Id, ae.Fighter.ActiveHP + 5, 0, true)
	check(untilTrue(function() return not sealed() end, 12), "A death unseals the gate")
	check(untilTrue(function() return not present() end, 12), "A death resets the fight: Shen despawned")
	check(A:GetAttribute("AsuraEncounter") == nil, "A AsuraEncounter cleared", A:GetAttribute("AsuraEncounter"))
	check((pos(B) - bBefore).Magnitude < 30 and B:GetAttribute("AsuraEncounter") == nil and C.GetEntity(B.UserId).Fighter.State ~= "KO", "B untouched by A's death/reset", { moved = (pos(B) - bBefore).Magnitude })

	-- 5b. Both participants inside at the same tick (seeded: both armed outside, teleported onto the trigger together).
	local function alive(p) local en = C.GetEntity(p.UserId); return en ~= nil and not en.Respawning and en.Fighter.State ~= "KO" end
	check(untilTrue(function() return alive(A) and alive(B) end, 60), "both players alive after A's respawn")
	C.GetEntity(A.UserId).Fighter.KOProtected = true; C.GetEntity(B.UserId).Fighter.KOProtected = true
	stand(A, 40, -6); stand(B, 40, 6); task.wait(2.5)
	-- Fire the client "Position" event too (as stand() does) or A's client reasserts its old spot and A is outside at the tick.
	local function place(p, dx)
		local f = CFrame.new(trigger + Vector3.new(dx, 0.5, 0))
		C.Teleport(p.UserId, f); event:FireClient(p, "Position", f)
	end
	local function inside(p) return inBounds(gate.Trigger, pos(p)) or inBounds(boss.Arena, pos(p)) end
	place(A, -0.4); place(B, 0.4)
	for _ = 1, 3 do -- one-shot placement can be overwritten by the client; retry until both are inside before the fight tick
		if inside(A) and inside(B) then break end
		place(A, -0.4); place(B, 0.4)
	end
	local enA = C.GetEntity(A.UserId)
	check(inside(A) and inside(B), "BOTH-INSIDE precondition: A and B both in trigger/arena before the fight tick", { aPos = tostring(pos(A)), bPos = tostring(pos(B)), aTrigger = inBounds(gate.Trigger, pos(A)), bTrigger = inBounds(gate.Trigger, pos(B)), aArena = inBounds(boss.Arena, pos(A)), bArena = inBounds(boss.Arena, pos(B)), aRespawning = enA.Respawning, aState = enA.Fighter.State, aEnc = tostring(A:GetAttribute("AsuraEncounter")) })
	local both = untilTrue(sealed, 15)
	check(both and untilTrue(function() return A:GetAttribute("AsuraEncounter") == boss.Id and B:GetAttribute("AsuraEncounter") == boss.Id end, 5), "BOTH-INSIDE: simultaneous entry seals the gate with both as participants", { a = tostring(A:GetAttribute("AsuraEncounter")), b = tostring(B:GetAttribute("AsuraEncounter")), aPos = tostring(pos(A)), bPos = tostring(pos(B)), aInArena = inBounds(boss.Arena, pos(A)), bInArena = inBounds(boss.Arena, pos(B)), aInTrigger = inBounds(gate.Trigger, pos(A)), bInTrigger = inBounds(gate.Trigger, pos(B)), trigger = tostring(Vector3.new(gate.Trigger.Size.X, gate.Trigger.Size.Y, gate.Trigger.Size.Z)) })
	if both then
		task.wait(1)
		e = shen()
		if e then
			C.ApplyArea(A.UserId, e.Id, 100, 0, true)
			local ea = C.GetEntity(A.UserId); ea.Fighter.KOProtected = false
			C.ApplyArea(e.Id, ea.Id, ea.Fighter.ActiveHP + 5, 0, true)
			check(untilTrue(function() return not alive(A) end, 10) and sealed() and B:GetAttribute("AsuraEncounter") == boss.Id and alive(B), "BOTH-INSIDE: A dies, B keeps fighting, gate stays sealed", { sealed = sealed(), b = B:GetAttribute("AsuraEncounter") })
			local eb = C.GetEntity(B.UserId); eb.Fighter.KOProtected = false
			C.ApplyArea(e.Id, eb.Id, eb.Fighter.ActiveHP + 5, 0, true)
			check(untilTrue(function() return not sealed() and not present() end, 15) and A:GetAttribute("AsuraEncounter") == nil and B:GetAttribute("AsuraEncounter") == nil, "BOTH-INSIDE: last participant dies, gate unsealed, Shen despawned, both encounters nil")
		end
	end
	check(untilTrue(function() return alive(A) and alive(B) end, 60), "both players alive again")
	C.GetEntity(A.UserId).Fighter.KOProtected = true; C.GetEntity(B.UserId).Fighter.KOProtected = true

	-- 5c. BossFelled re-entry: A beats Shen (seeded damage), then tries the gate again. B stays outside.
	stand(A, 40, -6); stand(B, 80, 6); task.wait(2.5)
	walkIn(A, 40)
	if untilTrue(sealed, 45) and untilTrue(function() return A:GetAttribute("AsuraEncounter") == boss.Id end, 5) then
		task.wait(1)
		e = shen()
		if e then
			for _ = 1, 40 do
				if not sealed() then break end
				C.ApplyArea(A.UserId, e.Id, e.Fighter.MaxHP, 0, true)
				task.wait(0.5)
			end
		end
		local felled = untilTrue(function() return not sealed() end, 15)
		info("Shen kill by seeded damage", { gateUnsealed = felled, shenPresent = present(), aEncounter = A:GetAttribute("AsuraEncounter") })
		if felled then
			task.wait(2)
			stand(A, 12, -6); task.wait(2.5)
			A:SetAttribute("AsuraResult", nil)
			intent(A, "Interact")
			check(untilTrue(function() return A:GetAttribute("AsuraResult") == "!BossFelled" end, 10), "BOSSFELLED: re-entry via gate interaction is refused with BossFelled (toast text exists in REASONS)", A:GetAttribute("AsuraResult"))
			stand(A, 40, -6); task.wait(2.5); walkIn(A, 40); task.wait(20)
			check(not sealed() and A:GetAttribute("AsuraEncounter") == nil, "BOSSFELLED: walking back in does not start a fight (silent, no toast on this route)", { sealed = sealed(), enc = A:GetAttribute("AsuraEncounter") })
		else
			check(false, "BOSSFELLED: seeded damage defeated Shen (precondition)", { shenHP = e and e.Fighter.ActiveHP })
		end
	else
		check(false, "BOSSFELLED: A walk-in started a fight (precondition)")
	end
	check(untilTrue(function() return not sealed() end, 30), "gate open before scenario 6")
	check(untilTrue(function() return alive(A) and alive(B) end, 60), "both players alive before scenario 6")
	C.GetEntity(A.UserId).Fighter.KOProtected = true; C.GetEntity(B.UserId).Fighter.KOProtected = true

	-- 6. Fresh fight afterwards: B walks in (seal is reusable), then B leaves the test mid-fight.
	stand(B, 40, 0); task.wait(2.5)
	walkIn(B, 40)
	local second = untilTrue(sealed, 45)
	check(second and untilTrue(function() return B:GetAttribute("AsuraEncounter") == boss.Id end, 5), "after the reset B walk-in starts a fresh sealed fight", { b = B:GetAttribute("AsuraEncounter") })
	if second then
		event:FireClient(B, "Leave") -- StudioTestService:LeaveTest on B -> PlayerRemoving
		check(untilTrue(function() return #Players:GetPlayers() == 1 end, 25), "B left the test")
		check(untilTrue(function() return not sealed() and not present() end, 15), "participant leave (PlayerRemoving) unseals the gate and resets Shen")
		check(A.Parent == Players and A:GetAttribute("AsuraEncounter") == nil, "remaining player A has no encounter")
	end
end, debug.traceback)

result.passed = ok
result.error = if ok then nil else err
local failed = 0
for _, c in result.checks do if not c.passed then failed += 1 end end
result.failed = failed
if not ok then print("[ShenMC] FAIL harness aborted " .. tostring(err)) end
local encoded = Http:JSONEncode(result)
print("[ShenMC RESULT] " .. encoded)
pcall(function() STS:EndTest(encoded) end)

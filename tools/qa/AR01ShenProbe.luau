-- AR01 seeded Shen encounter probe (Studio Play, Server datamodel, mock profile only; NOT earned play).
-- Installs a server Script (execute_luau's own require() would get fresh module copies) that:
--   1. makes the first player invulnerable and walks them in through the fog gate's inside point,
--   2. parks them at the gate, centre and each corner for HOLD seconds while sampling Shen every 0.2 s:
--      position vs BossMotion's 12-stud clamp, each telegraph (move id, boss->player distance, whether a
--      90-radius move reaches), and where each Skyfall lands,
--   3. lowers Shen's HP to 40% to ask for phase 2 and keeps sampling (BloodWave),
--   4. leaves through the fog gate's outside point and records whether the encounter reset.
-- Results land as JSON in ServerScriptService.AR01ShenProbe's "Result" attribute. Stop Play discards all.
local src = [==[
local HS = game:GetService("HttpService")
local S = game.ServerScriptService.AsurasPath.Services
local C = require(S.CharacterService)
local W = require(S.WorldService)
local A = require(S.AIService)
local P = require(S.PersistenceService)
local D = require(game.ReplicatedStorage.AsurasPath.Shared.WorldDefinitions)
local HOLD = script:GetAttribute("Hold") or 20
local out = { samples = 0, outsideClamp = 0, worstClamp = 0, telegraphs = {}, landings = {}, stops = {}, notes = {} }
local function done() script:SetAttribute("Result", HS:JSONEncode(out)) end
local p, e, s
for _ = 1, 60 do
	p = game.Players:GetPlayers()[1]
	e = p and C.GetEntity(p.UserId)
	s = p and W.GetSession(p.UserId)
	if e and s then break end
	task.wait(1)
end
if not (game:GetService("RunService"):IsStudio() and P.IsMock and e and s) then out.error = "not ready / not mock Studio" done() return end
local boss = D.Bosses.GrandmasterShen
local gate = D.FogGates[boss.FogGate]
local c, sz = boss.Arena.Center, boss.Arena.Size
s.Bosses.GrandmasterShen = nil
e.Fighter.InvulnerableUntil = math.huge
-- InvulnerableUntil is overwritten by hit reactions; re-assert it with HP and posture every frame
-- so a 20-second corner stand is a survey of the boss, not a death.
local heal = game:GetService("RunService").Heartbeat:Connect(function()
	local q = C.GetEntity(p.UserId)
	if q and q.Fighter.State ~= "KO" then q.Fighter.ActiveHP, q.Fighter.Posture, q.Fighter.InvulnerableUntil = q.Fighter.MaxHP, 0, math.huge end
end)
C.Teleport(p.UserId, CFrame.new(gate.Outside.X, gate.Outside.Y, gate.Outside.Z) * CFrame.Angles(0, math.pi, 0))
task.wait(2)
C.Teleport(p.UserId, CFrame.new(gate.Inside.X, gate.Inside.Y, gate.Inside.Z) * CFrame.Angles(0, math.pi, 0))
local id
for _ = 1, 50 do
	id = A.GetBossEntity("GrandmasterShen")
	if id then break end
	task.wait(0.2)
end
out.fightStarted = W.IsInBossFight(p.UserId)
out.bossPresent = id ~= nil
if not id then out.error = "Shen did not spawn on entry" done() return end
local be = C.GetEntity(id)
local spawnPos = be.Root.Position
out.spawn = { spawnPos.X, spawnPos.Y, spawnPos.Z }
out.spawnGap = (Vector3.new(spawnPos.X, 0, spawnPos.Z) - Vector3.new(gate.Inside.X, 0, gate.Inside.Z)).Magnitude
local lastTele = nil
local lastBoss = "?"
local fightT0 = os.clock()
local watch
watch = game:GetService("RunService").Heartbeat:Connect(function()
	local q = C.GetEntity(id)
	if q then
		lastBoss = string.format("state=%s mode=%s hp=%.0f b=(%.1f,%.1f,%.1f)", tostring(q.Fighter.State), tostring(A.GetMode(id)), q.Fighter.ActiveHP, q.Root.Position.X, q.Root.Position.Y, q.Root.Position.Z)
	end
	if not W.IsInBossFight(p.UserId) then
		local pp = e.Root.Position
		out.fightEnded = string.format("t=%.1f s after entry; stop=%s; player=(%.1f,%.1f,%.1f) %s; boss last %s", os.clock() - fightT0, tostring(out.currentStop), pp.X, pp.Y, pp.Z, tostring(e.Fighter.State), lastBoss)
		watch:Disconnect()
	end
end)
local function sample(label)
	be = C.GetEntity(id)
	if not be then return end
	local b = be.Root.Position
	out.samples += 1
	local over = math.max(math.abs(b.X - c.X) - (sz.X / 2 - 12), math.abs(b.Z - c.Z) - (sz.Z / 2 - 12))
	if over > 0.5 then out.outsideClamp += 1 end
	out.worstClamp = math.max(out.worstClamp, over)
	local tele = be.Model:GetAttribute("AsuraTelegraph")
	if tele and tele ~= lastTele then
		local move = string.split(tele, "|")[2]
		local pp = e.Root.Position
		local d = (Vector3.new(b.X, 0, b.Z) - Vector3.new(pp.X, 0, pp.Z)).Magnitude
		table.insert(out.telegraphs, { at = label, move = move, dist = math.floor(d * 10) / 10, phase = be.Model:GetAttribute("AsuraBossPhase") })
		if move == "GuandaoSkyfall" then
			task.delay(2.2, function()
				local q = C.GetEntity(id)
				if q then
					local l = q.Root.Position
					table.insert(out.landings, { at = label, x = math.floor(l.X), z = math.floor(l.Z),
						inside = math.abs(l.X - c.X) <= sz.X / 2 - 12 + 0.5 and math.abs(l.Z - c.Z) <= sz.Z / 2 - 12 + 0.5 })
				end
			end)
		end
	end
	lastTele = tele
end
local inset = 6
local stops = {
	{ "gate", gate.Inside.X, gate.Inside.Z },
	{ "centre", c.X, c.Z },
	{ "SW", c.X - sz.X / 2 + inset, c.Z - sz.Z / 2 + inset },
	{ "SE", c.X + sz.X / 2 - inset, c.Z - sz.Z / 2 + inset },
	{ "NE", c.X + sz.X / 2 - inset, c.Z + sz.Z / 2 - inset },
	{ "NW", c.X - sz.X / 2 + inset, c.Z + sz.Z / 2 - inset },
}
for _, stop in stops do
	if stop[1] == "SW" and script:GetAttribute("TraceSW") then
		task.spawn(function()
			for i = 1, 20 do
				local q = id and C.GetEntity(id)
				local bp = q and q.Root.Position
				table.insert(out.notes, string.format("SW t+%.1f boss=%s state=%s hp=%s b=(%s)", (i - 1) * 0.1, tostring(A.IsBossPresent("GrandmasterShen")),
					tostring(q and q.Fighter.State), tostring(q and q.Fighter.ActiveHP), bp and string.format("%.1f,%.1f,%.1f", bp.X, bp.Y, bp.Z) or "nil"))
				task.wait(0.1)
			end
			local q = id and C.GetEntity(id)
			if q then
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				local list = {}
				for _, ent in C.Entities() do table.insert(list, ent.Model) end
				rp.FilterDescendantsInstances = list
				local from, to = q.Root.Position + Vector3.new(0, 1.5, 0), e.Root.Position + Vector3.new(0, 1.5, 0)
				local hit = workspace:Raycast(from, to - from, rp)
				table.insert(out.notes, "SW sight ray: " .. (if hit then hit.Instance:GetFullName() .. string.format(" at (%.1f,%.1f,%.1f) query=%s", hit.Position.X, hit.Position.Y, hit.Position.Z, tostring(hit.Instance.CanQuery)) else "clear"))
			end
		end)
	end
	C.Teleport(p.UserId, CFrame.new(stop[2], 3, stop[3]))
	task.delay(1.5, function()
		local q = C.GetEntity(p.UserId)
		local pp = q and q.Root.Position
		table.insert(out.notes, string.format("%s +1.5s: fight=%s boss=%s pstate=%s respawning=%s p=(%.1f,%.1f,%.1f)", stop[1], tostring(W.IsInBossFight(p.UserId)),
			tostring(A.IsBossPresent("GrandmasterShen")), tostring(q and q.Fighter.State), tostring(q and q.Respawning), pp and pp.X or 0, pp and pp.Y or 0, pp and pp.Z or 0))
	end)
	local t0 = os.clock()
	local near = math.huge
	while os.clock() - t0 < HOLD do
		sample(stop[1])
		be = C.GetEntity(id)
		if be then near = math.min(near, (Vector3.new(be.Root.Position.X, 0, be.Root.Position.Z) - Vector3.new(stop[2], 0, stop[3])).Magnitude) end
		task.wait(0.2)
	end
	table.insert(out.stops, { stop = stop[1], closestApproach = math.floor(near * 10) / 10 })
end
-- Phase 2 request: lower Shen's HP below half.
be = C.GetEntity(id)
if be then
	be.Fighter.ActiveHP = be.Fighter.MaxHP * 0.4
	C.Teleport(p.UserId, CFrame.new(c.X, 3, c.Z))
	local t0 = os.clock()
	while os.clock() - t0 < HOLD * 1.5 do
		sample("phase2")
		task.wait(0.2)
	end
	out.phaseAfter = C.GetEntity(id) and C.GetEntity(id).Model:GetAttribute("AsuraBossPhase")
end
out.currentStop = "exit"
-- Exit through the gate and see whether the encounter resets.
C.Teleport(p.UserId, CFrame.new(gate.Outside.X, gate.Outside.Y, gate.Outside.Z))
task.wait(8)
out.fightAfterExit = W.IsInBossFight(p.UserId)
out.bossAfterExit = A.IsBossPresent("GrandmasterShen")
out.playerKO = e.Fighter.State == "KO"
heal:Disconnect()
done()
]==]
local old = game.ServerScriptService:FindFirstChild("AR01ShenProbe")
if old then old:Destroy() end
local sc = Instance.new("Script")
sc.Name = "AR01ShenProbe"
sc.Source = src
sc:SetAttribute("Hold", HOLD_SECONDS)
sc.Parent = game.ServerScriptService
return "installed"

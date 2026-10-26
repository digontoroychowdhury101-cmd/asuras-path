--!nonstrict
-- Unmapped Studio-only probe (post-F26 Step 4, Twin Sentinels greybox). Insert into ServerScriptService
-- during Play (never save); answers ServerStorage.TwinsQA:Invoke(op, ...).
-- Evidence types: entry placement, KO protection and heals are a seeded Studio diagnostic; "roll",
-- "dash" and "deflect" runs push the player's own intents through the real CharacterService path at a
-- fixed lead before the next Twin impact (server-timed, so also seeded). Boss AI, strikes, perilous
-- attacks, outcomes, the Oath and the lifecycle are the live game. Observes only; changes no rule.
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Characters = require(SSS.AsurasPath.Services.CharacterService)
local AI = require(SSS.AsurasPath.Services.AIService)
local World = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.WorldDefinitions)
local Rules = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.BossEncounterRules)

local FACING = math.deg(math.acos(0.15)) -- half cone in which a guard or deflect faces an attacker
local impacts, events, cues = {}, {}, {}
local seen = {}
local function own()
	local p = Players:GetPlayers()[1]
	return p and Characters.GetEntity(p.UserId)
end
local function twins()
	local list = {}
	for _, e in Characters.Entities() do
		if e.Kind == "Enemy" and e.Model:GetAttribute("AsuraEncounter") == "TwinSentinels" and e.Fighter.State ~= "KO" then table.insert(list, e) end
	end
	return list
end
local function bearing(me, foe)
	local d = foe.Root.Position - me.Root.Position
	return math.deg(math.atan2(d.X, d.Z)), Vector3.new(d.X, 0, d.Z).Magnitude
end

-- Perilous pulses and melee telegraphs as the game announces them (the wrapper only listens).
local originalCue = Characters.Cue
Characters.Cue = function(kind, source, payload)
	if kind == "Telegraph" and payload and payload.class == "Perilous" and payload.kind then
		local key = source .. ":" .. payload.move .. ":" .. string.format("%.3f", payload.impact)
		if not seen[key] then
			seen[key] = true
			table.insert(impacts, { at = payload.impact, id = source, move = payload.move, kind = payload.kind, perilous = true,
				deflect = payload.kind == "PerilousThrust" or payload.kind == "ShieldCharge" or payload.kind == "Barrage", block = payload.kind == "ShieldCharge" or payload.kind == "Barrage" })
		end
	end
	if kind == "BossIntro" or kind == "BossEnrage" or kind == "BossDefeated" or kind == "BossReset" or kind == "FogGateSealed" or kind == "BossFinish" then
		table.insert(cues, string.format("%.3f %s src=%d %s", Characters.Now(), kind, source, tostring(payload and (payload.name or payload.boss) or "")))
	end
	return originalCue(kind, source, payload)
end
Characters.Subscribe(function(event)
	local me = own()
	if me and (event.Target == me.Id or event.Source == me.Id) then
		table.insert(events, { t = Characters.Now(), k = event.Kind, s = event.Source, g = event.Target, v = event.Value })
		if #events > 2000 then table.remove(events, 1) end
	end
end)

-- Melee windups: impact = first active frame. Bearing is taken at impact.
local protect, sustain, react, lead, handledAt = false, false, nil, 0.06, -1
local lastHeal = 0
Run.Heartbeat:Connect(function()
	local me = own()
	if not me then return end
	local now = Characters.Now()
	if protect then me.Fighter.KOProtected = true end
	if sustain and now - lastHeal > 1.5 then lastHeal = now; Characters.RestoreFighter(me.Id) end
	for _, e in twins() do
		local f = e.Fighter
		if f.State == "Startup" and f.Move then
			local key = e.Id .. ":" .. string.format("%.3f", f.MoveStart)
			if not seen[key] then
				seen[key] = true
				table.insert(impacts, { at = f.MoveStart + f.Move.Timing.StartupSeconds, id = e.Id, move = f.Move.Id, kind = f.Move.Kind,
					deflect = f.Move.Deflectable, block = not f.Move.Unblockable, reach = f.Move.Reach, arc = f.Move.Arc })
			end
		end
	end
	for _, row in impacts do
		if row.bearing == nil and now >= row.at then
			local foe = Characters.GetEntity(row.id)
			if foe then row.bearing, row.distance = bearing(me, foe) end
		end
	end
	-- Server-timed reaction to the next pending impact (one response per impact cluster).
	if react then
		local nextAt = math.huge
		for _, row in impacts do if row.at > now and row.at < nextAt then nextAt = row.at end end
		if nextAt < math.huge and nextAt - now <= lead and nextAt > handledAt + 0.25 then
			handledAt = nextAt
			if react == "deflect" then
				Characters.PushIntent(me.Id, "Deflect")
			else
				local list = twins()
				local away = Vector3.zero
				for _, e in list do away += (me.Root.Position - e.Root.Position) * Vector3.new(1, 0, 1) end
				if away.Magnitude < 0.1 then away = Vector3.new(0, 0, 1) end
				local side = Vector3.new(-away.Z, 0, away.X).Unit
				Characters.PushIntent(me.Id, if react == "roll" then "Roll" else "Dash", nil, side.X, side.Z)
			end
		end
	end
end)

local ops = {}
function ops.info()
	local me = own()
	if not me then return "no player" end
	local out = { string.format("t=%.2f player (%.1f,%.1f,%.1f) %s hp %.0f enc=%s", Characters.Now(), me.Root.Position.X, me.Root.Position.Y, me.Root.Position.Z,
		me.Fighter.State, me.Fighter.ActiveHP, tostring(me.Model.Parent and Players:GetPlayers()[1]:GetAttribute("AsuraEncounter"))) }
	for _, e in Characters.Entities() do
		if e.Kind == "Enemy" and e.Model:GetAttribute("AsuraEncounter") == "TwinSentinels" then
			local p = e.Root.Position
			table.insert(out, string.format("%d %s (%.1f,%.1f,%.1f) %s hp %.0f/%.0f mode %s enraged %s scale %.2f", e.Id, e.Model.Name, p.X, p.Y, p.Z, e.Fighter.State,
				e.Fighter.ActiveHP, e.Fighter.MaxHP, tostring(AI.GetMode(e.Id)), tostring(e.Model:GetAttribute("AsuraBossEnraged")), e.Model:GetScale()))
		end
	end
	return table.concat(out, "\n")
end
function ops.enter()
	local trigger = World.FogGates.Gate_TwinSentinels.Trigger.Center
	Characters.Teleport(own().Id, CFrame.new(trigger.X, 3, trigger.Z) * CFrame.Angles(0, 0, 0))
	return "placed in the gate trigger"
end
function ops.protect(on) protect = on == true; return "protect " .. tostring(protect) end
function ops.sustain(on) sustain = on == true; return "sustain " .. tostring(sustain) end
function ops.react(mode, seconds) react, lead = mode, seconds or 0.06; handledAt = -1; return "react " .. tostring(mode) end
function ops.reset() table.clear(impacts); table.clear(events); table.clear(cues); return "cleared" end
function ops.cues() return table.concat(cues, "\n") end
function ops.kill(name)
	for _, e in twins() do
		if string.find(e.Model.Name, name, 1, true) then
			e.Fighter.KOProtected = false
			Characters.ApplyArea(own().Id, e.Id, e.Fighter.ActiveHP + 1, 0, true)
			return "struck " .. e.Model.Name
		end
	end
	return "none"
end
-- Seeded player death by a Twin (retry/reset check) and a server Skip (same path as the key).
function ops.die()
	local me, list = own(), twins()
	if not list[1] then return "no twin" end
	protect, sustain = false, false
	me.Fighter.KOProtected = false
	Characters.ApplyArea(list[1].Id, me.Id, me.Fighter.ActiveHP + 5, 0, true)
	return "player " .. me.Fighter.State
end
function ops.skip() return Characters.PushIntent(own().Id, "Skip") end
-- First Twin impact after `since` (entry/skip grace).
function ops.first(since)
	local best
	for _, row in impacts do if row.at >= since and (best == nil or row.at < best.at) then best = row end end
	return if best then string.format("%.3f %s %s (+%.3f s)", best.at, best.move, best.kind, best.at - since) else "none"
end
function ops.now() return Characters.Now() end
-- Seeded: take one Twin out without a KO (no Oath), to watch the other alone.
function ops.remove(name)
	for _, e in twins() do
		if string.find(e.Model.Name, name, 1, true) then Characters.DespawnEnemy(e.Id); return "removed " .. e.Model.Name end
	end
	return "none"
end
-- Seeded punish window: when the Bull enters Recovery, the player is placed 4 studs `side` of it
-- ("behind" or "front"), facing it, and throws one light 0.03 s later. Tallies what the light met.
function ops.window(seconds, side)
	local bull
	for _, e in twins() do if string.find(e.Model.Name, "Bull", 1, true) then bull = e end end
	if not bull then return "no bull" end
	local me, seen, out, last = own(), {}, {}, nil
	local tally = {}
	local conn = Characters.Subscribe(function(event)
		if event.Source == me.Id and event.Target == bull.Id and last then
			tally[last .. " " .. event.Kind] = (tally[last .. " " .. event.Kind] or 0) + 1
		end
	end)
	local beat = Run.Heartbeat:Connect(function()
		local f = bull.Fighter
		if f.State == "Recovery" and f.Move and not seen[f.MoveStart] then
			seen[f.MoveStart] = true
			last = f.Move.Id
			local look = bull.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local spot = bull.Root.Position + look.Unit * (if side == "front" then 4 else -4)
			spot = Vector3.new(spot.X, 3, spot.Z)
			Characters.Teleport(me.Id, CFrame.lookAt(spot, Vector3.new(bull.Root.Position.X, 3, bull.Root.Position.Z)))
			task.delay(0.03, function()
				local d = bull.Root.Position - me.Root.Position
				Characters.PushIntent(me.Id, "Light", nil, d.X / d.Magnitude, d.Z / d.Magnitude)
			end)
		end
	end)
	task.wait(seconds)
	beat:Disconnect(); conn()
	for k, v in tally do table.insert(out, k .. "=" .. v) end
	table.sort(out)
	return side .. ": " .. table.concat(out, " | ")
end
-- The Bull's swings for `seconds`: per move, measured Startup/Recovery and the committed strike record
-- (arc, reach, lunge) the server swept and the client drew, against WeaponSchema. With `punish`, the
-- player dashes through each swing 0.05 s before impact (server-timed) and throws one light at the
-- Bull's back once it is in Recovery.
function ops.bull(seconds, punish)
	local Geometry = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.StrikeGeometry)
	local Weapons = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.WeaponSchema)
	local bull
	for _, e in twins() do if string.find(e.Model.Name, "Bull", 1, true) then bull = e end end
	if not bull then return "no bull" end
	local me = own()
	local rows, last, since, current, dashed, struck = {}, bull.Fighter.State, Characters.Now(), nil, {}, {}
	local strikeConn = bull.Model:GetAttributeChangedSignal("AsuraStrike"):Connect(function()
		local s = Geometry.decode(bull.Model:GetAttribute("AsuraStrike"))
		local move = bull.Fighter.Move
		if s and move then
			local row = rows[move.Id] or { n = 0, startup = {}, recovery = {}, arc = {}, reach = {}, lunge = {} }
			rows[move.Id] = row
			table.insert(row.arc, s.Arc); table.insert(row.reach, s.Reach); table.insert(row.lunge, s.Lunge)
		end
	end)
	local outcome = {}
	local eventConn = Characters.Subscribe(function(event)
		if event.Source == me.Id and event.Target == bull.Id then outcome[event.Kind] = (outcome[event.Kind] or 0) + 1 end
		if event.Source == bull.Id and event.Target == me.Id and (event.Kind == "Hit" or event.Kind == "Evade") then outcome["bull " .. event.Kind] = (outcome["bull " .. event.Kind] or 0) + 1 end
	end)
	local conn = Run.Heartbeat:Connect(function()
		local f, now = bull.Fighter, Characters.Now()
		if f.State ~= last then
			if current and (last == "Startup" or last == "Recovery") then
				local row = rows[current] or { n = 0, startup = {}, recovery = {}, arc = {}, reach = {}, lunge = {} }
				rows[current] = row
				table.insert(if last == "Startup" then row.startup else row.recovery, now - since)
				if last == "Startup" then row.n += 1 end
			end
			last, since = f.State, now
		end
		if f.Move then current = f.Move.Id end
		if punish and f.State == "Startup" and f.Move and not dashed[f.MoveStart] and now >= f.MoveStart + f.Move.Timing.StartupSeconds - 0.05 then
			dashed[f.MoveStart] = true
			local d = bull.Root.Position - me.Root.Position
			Characters.PushIntent(me.Id, "Dash", nil, d.X / d.Magnitude, d.Z / d.Magnitude)
		end
		if punish and f.State == "Recovery" and dashed[f.MoveStart] and not struck[f.MoveStart] and now - since > 0.05 then
			struck[f.MoveStart] = true
			local d = bull.Root.Position - me.Root.Position
			Characters.PushIntent(me.Id, "Light", nil, d.X / d.Magnitude, d.Z / d.Magnitude)
		end
	end)
	task.wait(seconds)
	conn:Disconnect(); strikeConn:Disconnect(); eventConn()
	local maul = Weapons.get("IronBullMaul")
	local out = {}
	local function mean(t) local s = 0; for _, v in t do s += v end; return if #t > 0 then s / #t else 0 / 0 end
	for id, row in rows do
		local spec = maul.Moves[id]
		table.insert(out, string.format("%s x%d startup %.3f (spec %.3f) recovery %.3f (spec %.3f) arc %.0f reach %.1f lunge %.1f (spec %s/%s/%s)", id, row.n,
			mean(row.startup), spec and spec.Timing.StartupSeconds or -1, mean(row.recovery), spec and spec.Timing.RecoverySeconds or -1,
			mean(row.arc), mean(row.reach), mean(row.lunge), tostring(spec and spec.Arc), tostring(spec and spec.Reach), tostring(spec and spec.Lunge)))
	end
	table.sort(out)
	local tally = {}
	for k, v in outcome do table.insert(tally, k .. "=" .. v) end
	table.sort(tally)
	table.insert(out, "outcomes: " .. table.concat(tally, " "))
	return table.concat(out, "\n")
end
-- Seeded: player and both Twins to fixed spots (player at x,z facing north; Twins 9 studs north).
function ops.stage(x, z)
	Characters.Teleport(own().Id, CFrame.lookAt(Vector3.new(x, 3, z), Vector3.new(x, 3, z - 10)))
	for i, e in twins() do
		Characters.Teleport(e.Id, CFrame.lookAt(Vector3.new(x + (i - 1.5) * 8, e.Root.Position.Y, z - 9), Vector3.new(x, e.Root.Position.Y, z)))
	end
	return "staged"
end
-- Seeded: put a named Twin `distance` studs behind the player along the camera look (lx, lz).
function ops.behind(name, distance, lx, lz)
	local me = own()
	for _, e in twins() do
		if string.find(e.Model.Name, name, 1, true) then
			local p = me.Root.Position - Vector3.new(lx, 0, lz) * distance
			Characters.Teleport(e.Id, CFrame.lookAt(Vector3.new(p.X, e.Root.Position.Y, p.Z), Vector3.new(me.Root.Position.X, e.Root.Position.Y, me.Root.Position.Z)))
			-- Held there for 12 s (anchored) so the client can sample the frame; then released.
			e.Root.Anchored = true
			task.delay(12, function() if e.Root.Parent then e.Root.Anchored = false end end)
			return "placed " .. e.Model.Name
		end
	end
	return "none"
end
-- Stand `distance` studs from a named Twin, facing it (so a lock key picks that Twin).
function ops.face(name, distance, lx, lz)
	for _, e in twins() do
		if string.find(e.Model.Name, name, 1, true) then
			local p = e.Root.Position
			local spot = Vector3.new(p.X - (lx or 0) * (distance or 8), 3, p.Z - (lz or -1) * (distance or 8))
			Characters.Teleport(own().Id, CFrame.lookAt(spot, Vector3.new(p.X, 3, p.Z)))
			return "facing " .. e.Model.Name
		end
	end
	return "none"
end
function ops.moves(since)
	local tally = {}
	for _, row in impacts do
		if row.at >= (since or 0) then
			local foe = Characters.GetEntity(row.id)
			local key = (if foe then foe.Model.Name else tostring(row.id)) .. " " .. row.move
			tally[key] = (tally[key] or 0) + 1
		end
	end
	local out = {}
	for k, v in tally do table.insert(out, k .. " x" .. v) end
	table.sort(out)
	return table.concat(out, " | ")
end
-- Pairs of impacts from the two Twins within `window` seconds and the responses the rules allow.
function ops.pairs(window)
	window = window or 0.35
	table.sort(impacts, function(a, b) return a.at < b.at end)
	local out, counts = {}, { pairs = 0, roll = 0, dash = 0, deflect = 0, guard = 0, none = 0 }
	local m = Characters.GetEntity(own().Id)
	for i = 1, #impacts - 1 do
		local a, b = impacts[i], impacts[i + 1]
		if a.id ~= b.id and b.at - a.at <= window and a.bearing and b.bearing then
			counts.pairs += 1
			local dt = b.at - a.at
			local spread = math.abs(((b.bearing - a.bearing + 180) % 360) - 180)
			local ok = {}
			if dt <= 0.10 + 1e-6 then table.insert(ok, "dash"); counts.dash += 1 end
			if dt <= 0.20 + 1e-6 then table.insert(ok, "roll"); counts.roll += 1 end
			if dt <= 0.10 + 1e-6 and spread <= 2 * FACING and a.deflect and b.deflect then table.insert(ok, "deflect"); counts.deflect += 1 end
			if spread <= 2 * FACING and a.block and b.block then table.insert(ok, "guard"); counts.guard += 1 end
			-- Two separate answers: dash then dash (0.22 s apart) or roll then roll (0.36 s).
			if dt >= 0.22 then table.insert(ok, "dash+dash") end
			if #ok == 0 then counts.none += 1 end
			table.insert(out, string.format("%.3f dt=%3.0fms spread=%5.1f %s(%s %.1f) + %s(%s %.1f) -> %s", a.at, dt * 1000, spread,
				a.move, a.kind, a.distance or -1, b.move, b.kind, b.distance or -1, if #ok > 0 then table.concat(ok, ",") else "NONE"))
		end
	end
	local _ = m
	table.insert(out, string.format("impacts %d pairs %d | dash %d roll %d deflect %d guard %d none %d", #impacts, counts.pairs, counts.dash, counts.roll, counts.deflect, counts.guard, counts.none))
	return table.concat(out, "\n")
end
function ops.outcomes(from)
	local tally = {}
	for _, r in events do
		if r.t >= (from or 0) then
			local key = (if r.g == own().Id then "on player " else "by player ") .. r.k
			tally[key] = (tally[key] or 0) + 1
		end
	end
	local out = {}
	for k, v in tally do table.insert(out, k .. "=" .. v) end
	table.sort(out)
	return table.concat(out, " | ")
end
function ops.gate()
	local wall = workspace:FindFirstChild("FogGate_Gate_TwinSentinels", true)
	local enemies = 0
	for _, e in Characters.Entities() do if e.Kind == "Enemy" and e.Model:GetAttribute("AsuraEncounter") == "TwinSentinels" then enemies += 1 end end
	return string.format("gate sealed=%s collide=%s twins=%d bossEntity=%s", tostring(wall and wall:GetAttribute("Sealed")), tostring(wall and wall.CanCollide), enemies, tostring(AI.GetBossEntity("TwinSentinels")))
end
local _ = Rules

local old = game:GetService("ServerStorage"):FindFirstChild("TwinsQA")
if old then old:Destroy() end
local fn = Instance.new("BindableFunction")
fn.Name = "TwinsQA"
fn.OnInvoke = function(op, ...)
	local handler = ops[op]
	if not handler then return "unknown op" end
	local ok, a, b = pcall(handler, ...)
	if not ok then return "error: " .. tostring(a) end
	return a, b
end
fn.Parent = game:GetService("ServerStorage")
print("[TwinsQA] probe ready")

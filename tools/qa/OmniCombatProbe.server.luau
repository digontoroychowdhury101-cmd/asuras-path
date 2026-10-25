--!nonstrict
-- Unmapped Studio-only probe (post-F26 step 2, omnidirectional combat). Insert into
-- ServerScriptService during Play (never save); answers ServerStorage.OmniQA:Invoke(op, ...).
-- Evidence types: placement, weapons, heal and KO protection are a seeded Studio diagnostic; the
-- "react" op pushes the player's own Dash/Deflect/Light intents through the real CharacterService path
-- at exact offsets from an enemy windup (server-timed, so also seeded); strikes, whiffs, evades and
-- AI behaviour are the live game. Reads authoritative state only; changes no rule.
local Run = game:GetService("RunService")
if not Run:IsStudio() then return end
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Characters = require(SSS.AsurasPath.Services.CharacterService)
local AI = require(SSS.AsurasPath.Services.AIService)

local log, strikes, watched, seq = {}, {}, {}, { log = 0, strikes = 0 }
Characters.Subscribe(function(event)
	seq.log += 1
	log[seq.log] = { t = Characters.Now(), k = event.Kind, s = event.Source, g = event.Target, v = event.Value }
	log[seq.log - 800] = nil
end)
local function watch(e)
	if watched[e.Id] then return end
	watched[e.Id] = true
	e.Model:GetAttributeChangedSignal("AsuraStrike"):Connect(function()
		local nearest, bearing = nil, nil
		for _, other in Characters.Entities() do
			if other ~= e and other.Root.Parent and (other.Root.Position - e.Root.Position).Magnitude < 20 and Characters.IsHostile(e.Id, other.Id) then
				local d = other.Root.Position - e.Root.Position
				nearest, bearing = other.Id, math.atan2(-d.X, -d.Z)
			end
		end
		seq.strikes += 1
		strikes[seq.strikes] = { t = Characters.Now(), id = e.Id, rec = e.Model:GetAttribute("AsuraStrike"), foe = nearest, bearing = bearing,
			air = e.Omni.Air.Airborne }
		strikes[seq.strikes - 300] = nil
	end)
end
local function own()
	local p = Players:GetPlayers()[1]
	return p and Characters.GetEntity(p.UserId)
end
local protect = false
task.spawn(function()
	while true do
		for _, e in Characters.Entities() do watch(e) end
		local me = own()
		if me and protect then me.Fighter.KOProtected = true end
		task.wait(0.2)
	end
end)

local ops = {}
function ops.info()
	local e = own()
	if not e then return "no player" end
	local out = { string.format("player %d %s at (%.1f,%.1f,%.1f) state %s air %s", e.Id, e.Fighter.Weapon, e.Root.Position.X, e.Root.Position.Y, e.Root.Position.Z, e.Fighter.State, tostring(e.Omni.Air.Airborne)) }
	for id, other in Characters.Entities() do
		if other.Kind == "Enemy" and (other.Root.Position - e.Root.Position).Magnitude < 90 then
			local p = other.Root.Position
			table.insert(out, string.format("%d %s %s (%.1f,%.1f,%.1f) %s hp %.0f mode %s", id, other.Model.Name, other.Fighter.Weapon, p.X, p.Y, p.Z, other.Fighter.State, other.Fighter.ActiveHP, tostring(AI.GetMode(id))))
		end
	end
	return table.concat(out, "\n")
end
function ops.protect(on) protect = on == true; return "protect " .. tostring(protect) end
function ops.place(x, y, z, yaw) Characters.Teleport(own().Id, CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)); return "placed" end
function ops.weapon(id, weapon) id = id or own().Id; Characters.ForceWeapon(id, weapon); return "weapon " .. tostring(id) .. " " .. weapon end
function ops.moveEnemy(id, x, y, z, yaw) Characters.Teleport(id, CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)); return "moved" end
function ops.heal()
	for _, e in Characters.Entities() do
		local f = e.Fighter
		f.ActiveHP, f.RecoverableHP, f.PermanentDeficit, f.Posture, f.Stamina = f.MaxHP, 0, 0, 0, f.MaxStamina
	end
	return "healed"
end
function ops.mark() return seq.log, seq.strikes end
function ops.events(from)
	local out = {}
	for i = (from or 0) + 1, seq.log do
		local r = log[i]
		if r then table.insert(out, string.format("%.3f %s %d->%d %.2f", r.t, r.k, r.s, r.g, r.v)) end
	end
	return table.concat(out, "\n")
end
function ops.strikes(from)
	local out = {}
	for i = (from or 0) + 1, seq.strikes do
		local r = strikes[i]
		if r then
			local yaw = tonumber(string.match(r.rec or "", "^[^|]+|[^|]+|[^|]+|([^|]+)")) or 0
			local off = if r.bearing then math.deg(((r.bearing - yaw + math.pi) % (2 * math.pi)) - math.pi) else 0 / 0
			table.insert(out, string.format("%.3f id %d air=%s foe=%s offset=%.1fdeg rec=%s", r.t, r.id, tostring(r.air), tostring(r.foe), off, tostring(r.rec)))
		end
	end
	return table.concat(out, "\n")
end
function ops.state(id)
	local e = if id then Characters.GetEntity(id) else own()
	if not e then return "gone" end
	local f = e.Fighter
	return string.format("%d %s %.3f->%.3f move=%s hp=%.1f air=%s attacks=%d dodges=%d landing=%s autorotate=%s", e.Id, f.State, f.StateStart, f.StateEnd,
		f.Move and f.Move.Id or "-", f.ActiveHP, tostring(e.Omni.Air.Airborne), e.Omni.Air.Attacks, e.Omni.Air.Dodges, tostring(e.Omni.Air.Landing), tostring(e.Humanoid.AutoRotate))
end
function ops.push(id, action, x, z) return Characters.PushIntent(id, action, nil, x, z) end
-- Server-timed player intents at `lead` seconds before each enemy impact, for `seconds`.
function ops.react(mode, enemyId, seconds, lead)
	local me, foe = own(), Characters.GetEntity(enemyId)
	if not me or not foe then return "missing" end
	local handled, results, deadline = {}, {}, os.clock() + seconds
	local conn
	conn = Run.Heartbeat:Connect(function()
		if os.clock() > deadline then conn:Disconnect(); return end
		local f = foe.Fighter
		if f.State == "Startup" and f.Move and not handled[f.MoveStart] then
			local impact = f.MoveStart + f.Move.Timing.StartupSeconds
			local now = Characters.Now()
			if now >= impact - lead then
				handled[f.MoveStart] = true
				local d = me.Root.Position - foe.Root.Position
				local side = Vector3.new(-d.Z, 0, d.X).Unit
				if mode == "dash" then
					Characters.PushIntent(me.Id, "Dash", nil, side.X, side.Z)
				elseif mode == "deflect" or mode == "punish" then
					Characters.PushIntent(me.Id, "Deflect")
					if mode == "punish" then
						task.delay(f.Move.Timing.ActiveSeconds + 0.03, function()
							local a = foe.Root.Position - me.Root.Position
							Characters.PushIntent(me.Id, "Light", nil, a.X / a.Magnitude, a.Z / a.Magnitude)
						end)
					end
				end
				table.insert(results, string.format("%s %.3f s before impact (%s)", mode, impact - now, f.Move.Id))
			end
		end
	end)
	task.wait(seconds + 0.2)
	return table.concat(results, "\n")
end
-- Per-frame server positions of the player and one enemy (windups, swings and dashes only).
function ops.sample(enemyId, seconds)
	local me, foe = own(), Characters.GetEntity(enemyId)
	local rows, last = {}, nil
	local conn = Run.Heartbeat:Connect(function()
		local f, mf = foe.Fighter, me.Fighter
		if f.State == "Startup" or f.State == "Active" or mf.State == "Dashing" or f.State ~= last then
			local d = me.Root.Position - foe.Root.Position
			local flat = Vector3.new(d.X, 0, d.Z)
			local look = foe.Root.CFrame.LookVector
			local off = if flat.Magnitude > 0.01 then math.deg(math.acos(math.clamp(flat.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit), -1, 1))) else 0
			table.insert(rows, string.format("%.3f foe %s %s me %s dist %.2f offAxis %.1f", Characters.Now(), f.State, f.Move and f.Move.Id or "-", mf.State, flat.Magnitude, off))
		end
		last = f.State
	end)
	task.wait(seconds)
	conn:Disconnect()
	return table.concat(rows, "\n")
end

local fn = Instance.new("BindableFunction")
fn.Name = "OmniQA"
fn.OnInvoke = function(op, ...)
	local handler = ops[op]
	if not handler then return "unknown op" end
	local ok, a, b = pcall(handler, ...)
	if not ok then return "error: " .. tostring(a) end
	return a, b
end
fn.Parent = game:GetService("ServerStorage")
print("[OmniQA] probe ready")

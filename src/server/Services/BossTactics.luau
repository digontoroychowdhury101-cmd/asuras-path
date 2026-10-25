--!strict
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local World = require(Shared.Shared.WorldDefinitions)
local Types = require(Shared.Shared.BossTypes)
local Rules = require(Shared.Shared.BossEncounterRules)
local Combat = require(Shared.Simulation.CombatRules)
local Characters = require(script.Parent.CharacterService)
local Attacks = require(script.Parent.BossAttackService)
local Motion = require(script.Parent.BossMotion)
local Tactics = {}
type Schedule = { Next: number, Cursor: number, FarSince: number, NextClose: number, Extra: { Types.Attack }, Kneeling: boolean, StandHip: number? }
local schedules: { [number]: Schedule } = {}
function Tactics.reset(id: number)
	Attacks.cancel(id)
	schedules[id] = nil
end
function Tactics.enrage(id: number, inherited: { Types.Attack })
	Attacks.cancel(id)
	local schedule = schedules[id]
	if not schedule then
		schedule = { Next = Characters.Now() + 1, Cursor = 0, FarSince = Characters.Now(), NextClose = Characters.Now() + 3, Extra = {}, Kneeling = false }
		schedules[id] = schedule
	end
	schedule.Extra = inherited; schedule.Next = Characters.Now() + 1
end
-- Encounter handoff: nothing is scheduled to start before control returns at `untilTime`.
function Tactics.hold(id: number, untilTime: number)
	local schedule = schedules[id]
	if not schedule then
		schedule = { Next = untilTime, Cursor = 0, FarSince = untilTime, NextClose = untilTime, Extra = {}, Kneeling = false }
		schedules[id] = schedule
	end
	schedule.Next, schedule.NextClose = math.max(schedule.Next, untilTime), math.max(schedule.NextClose, untilTime)
	schedule.FarSince = math.max(schedule.FarSince, untilTime)
end
function Tactics.step(id: number, boss: World.BossDef, phase: number, targetId: number, allowed: { [number]: boolean }?, now: number): boolean
	local e, target = Characters.GetEntity(id), Characters.GetEntity(targetId)
	if not e then return false end
	local schedule = schedules[id]
	if not schedule then
		schedule = { Next = now + 2, Cursor = 0, FarSince = now, NextClose = now, Extra = {}, Kneeling = false }
		schedules[id] = schedule
	end
	if e.Fighter.State == "StanceBroken" and boss.Archetype == "Colossus" then
		if not schedule.Kneeling then
			schedule.Kneeling = true
			Attacks.cancel(id)
			e.Model:SetAttribute("AsuraVisceralTarget", "Head")
			Characters.Cue("BossKneel", id, { duration = 2.5 })
			-- Lower the head into the normal deathblow reach, then restore when posture recovers.
			schedule.StandHip = e.Humanoid.HipHeight
			e.Humanoid.HipHeight = 0
		end
		return true
	elseif schedule.Kneeling then
		schedule.Kneeling = false
		e.Model:SetAttribute("AsuraVisceralTarget", "Ankles")
		-- The scaled standing height, not a constant (F11: 6 sank the scale-3 Titan's feet 0.58 studs).
		e.Humanoid.HipHeight = schedule.StandHip or e.Humanoid.HipHeight
	end
	if Attacks.step(id, now) then return true end
	if not target or not allowed or not allowed[targetId] or target.Fighter.State == "KO" or e.Fighter.State ~= "Idle" then return false end
	local distance = (target.Root.Position - e.Root.Position).Magnitude
	local p = boss.Phases[phase]
	local closer = p.GapCloser
	if distance <= (closer and closer.Range or 40) then schedule.FarSince = now end
	if closer and now >= schedule.NextClose and Rules.shouldClose(distance, schedule.FarSince, now, closer.Range, closer.Delay) then
		schedule.NextClose = now + closer.Cooldown
		schedule.Next = now + 2
		Attacks.start(id, { Id = "Pursuit", Kind = "Leap", Motion = closer.Motion, Windup = 1, Radius = 18, Damage = 22, Posture = 30 }, targetId, allowed, now)
		return true
	end
	-- A cornered oracle marks a destination before shadow-stepping away.
	if boss.Archetype == "Sorcerer" and distance < 16 and now >= schedule.NextClose then
		schedule.NextClose = now + 7
		local away = e.Root.Position - target.Root.Position
		local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
		local destination = Motion.clamp(id, e.Root.Position + direction * 35)
		Characters.Cue("BossTeleport", id, { x = destination.X, y = destination.Y, z = destination.Z })
		Characters.Teleport(id, CFrame.new(destination))
		Combat.cinematic(e.Fighter, now, 0.4)
		return true
	end
	if now < schedule.Next then return false end
	local moves: { Types.Attack } = table.clone(p.Attacks or {})
	for _, move in schedule.Extra do table.insert(moves, move) end
	if #moves == 0 then return false end
	schedule.Cursor = schedule.Cursor % #moves + 1
	schedule.Next = now + (p.AttackInterval or 3)
	local attack = table.clone(moves[schedule.Cursor])
	if e.Model:GetAttribute("AsuraBossEnraged") then
		attack.Element, attack.Damage, attack.Posture = "Lightning+Iron", attack.Damage * 1.2, attack.Posture * 1.2
	end
	Attacks.start(id, attack, targetId, allowed, now)
	return true
end
return Tactics

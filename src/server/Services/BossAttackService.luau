--!strict
local Shared = game:GetService("ReplicatedStorage").AsurasPath
local Types = require(Shared.Shared.BossTypes)
local World = require(Shared.Shared.WorldDefinitions)
local Rules = require(Shared.Shared.BossEncounterRules)
local Characters = require(script.Parent.CharacterService)
local Motion = require(script.Parent.BossMotion)
local Hazards = require(script.Parent.BossHazards)
local Service = {}
type Active = { Attack: Types.Attack, Impact: number, Origin: Vector3, Aim: Vector3, Target: number,
	Allowed: { [number]: boolean }?, Hazard: Hazards.Hazard?, Pulse: number }
local active: { [number]: Active } = {}
function Service.cancel(id: number)
	active[id] = nil
	Motion.cancel(id)
	local e = Characters.GetEntity(id)
	if e then e.Model:SetAttribute("AsuraBossAttack", nil) end
end
function Service.start(id: number, attack: Types.Attack, target: number, allowed: { [number]: boolean }?, now: number)
	Service.cancel(id)
	local e, victim = Characters.GetEntity(id), Characters.GetEntity(target)
	if not e or not victim or not allowed or not allowed[target] then return end
	local impact = Rules.impact(now, attack.Windup)
	local origin = Vector3.new(e.Root.Position.X, 3, e.Root.Position.Z)
	local aim = Motion.clamp(id, Vector3.new(victim.Root.Position.X, e.Root.Position.Y, victim.Root.Position.Z))
	active[id] = { Attack = attack, Impact = impact, Origin = origin, Aim = aim, Target = target, Allowed = allowed, Hazard = nil, Pulse = 0 }
	local _, counter = Rules.classify(attack.Kind)
	Characters.StopMoving(id)
	Characters.SetGuard(id, false)
	if attack.Kind ~= "Tail" then Characters.Face(id, aim) end
	e.Model:SetAttribute("AsuraBossAttack", attack.Kind)
	e.Model:SetAttribute("AsuraTelegraph", string.format("Perilous|%s|%.3f", attack.Id, impact))
	Characters.Cue("Telegraph", id, { class = "Perilous", move = attack.Id, kind = attack.Kind, counter = counter, impact = impact,
		radius = attack.Radius, ox = origin.X, oz = origin.Z, x = aim.X, y = 0, z = aim.Z, duration = attack.Duration, element = attack.Element })
	if attack.Motion then Motion.begin(id, attack.Motion, aim, now, impact) end
end
local function strike(id: number, current: Active)
	local e = Characters.GetEntity(id)
	if not e then return end
	local a = current.Attack
	for target in current.Allowed or {} do
		local victim = Characters.GetEntity(target)
		if not victim or victim.Fighter.State == "KO" then continue end
		local delta = victim.Root.Position - e.Root.Position
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local within = flat.Magnitude <= a.Radius
		if a.Kind == "PerilousGrab" then within = delta.Magnitude <= a.Radius end
		if a.Kind == "PerilousThrust" or a.Kind == "ShieldCharge" then
			local p, origin, aim = victim.Root.Position, current.Origin, current.Aim
			within = Rules.segmentHit(p.X, p.Z, origin.X, origin.Z, aim.X, aim.Z, 5) and math.abs(delta.Y) < 8
		elseif a.Kind == "PerilousSweep" or a.Kind == "Tail" then
			within = within and victim.Root.Position.Y - current.Origin.Y <= (a.Height or 5)
			if a.Kind == "Tail" and flat.Magnitude > 0.01 then within = within and e.Root.CFrame.LookVector:Dot(flat.Unit) < 0.3 end
		end
		if within then Characters.ApplyBossAttack(id, target, a.Damage, a.Posture, a.Kind) end
	end
end
function Service.step(id: number, now: number): boolean
	local current, e = active[id], Characters.GetEntity(id)
	if not current then return false end
	if not e or e.Fighter.State == "KO" or e.Fighter.State == "StanceBroken" or e.Fighter.State == "DeathblowVictim"
		or e.Fighter.State == "Hitstun" or e.Fighter.State == "GuardBroken" then Service.cancel(id); return false end
	Characters.StopMoving(id)
	Motion.step(id, now)
	if now < current.Impact then return true end
	local a = current.Attack
	local kind = a.Kind
	if kind == "PerilousSweep" or kind == "PerilousThrust" or kind == "PerilousGrab" or kind == "Tail" or kind == "ShieldCharge" then
		if now >= current.Impact + current.Pulse * (a.Interval or 0.7) then
			strike(id, current)
			current.Pulse += 1
			if current.Pulse < (a.Repeats or 1) then
				Characters.Cue("Telegraph", id, { class = "Perilous", kind = kind, counter = select(2, Rules.classify(kind)),
					move = a.Id, impact = current.Impact + current.Pulse * (a.Interval or 0.7) })
			else Service.cancel(id); return true end
		end
	else
		if not current.Hazard then
			local origin = if kind == "Leap" then Vector3.new(current.Aim.X, 3, current.Aim.Z) else current.Origin
			if kind == "Ritual" then
				local encounter = e.Model:GetAttribute("AsuraEncounter")
				local boss = if type(encounter) == "string" then World.Bosses[encounter] else nil
				if boss then origin = Vector3.new(boss.Arena.Center.X, 3, boss.Arena.Center.Z) end
			end
			current.Hazard = Hazards.new(a, origin, current.Aim, current.Impact, current.Allowed)
			if kind == "Breath" then
				local direction = current.Aim - current.Origin
				local endpoint = current.Aim + (if direction.Magnitude > 0.1 then direction.Unit * 70 else Vector3.zAxis * 70)
				Motion.begin(id, "Aerial", endpoint, now, now + (a.Duration or 3))
			end
			Characters.Cue("BossHazard", id, { kind = kind, radius = a.Radius, speed = a.Speed or 36, duration = a.Duration,
				repeats = a.Repeats or 1, interval = a.Interval or 1, element = a.Element, x = origin.X, y = 0.3, z = origin.Z,
				ax = current.Aim.X, az = current.Aim.Z })
		end
		if not Hazards.step(id, current.Hazard :: Hazards.Hazard, now) then Service.cancel(id) end
	end
	return true
end
return Service

--!strict
local Replicated = game:GetService("ReplicatedStorage").AsurasPath
local Types = require(Replicated.Shared.BossTypes)
local Rules = require(Replicated.Shared.BossEncounterRules)
local Characters = require(script.Parent.CharacterService)
type Entity = Characters.Entity
type Projectile = { Position: Vector3, Target: number, Hit: boolean }
export type Hazard = { Attack: Types.Attack, Origin: Vector3, Aim: Vector3, Start: number, Previous: number,
	Allowed: { [number]: boolean }?, Hits: { [string]: boolean }, Projectiles: { Projectile }, LastTick: number }
local Hazards = {}
function Hazards.new(attack: Types.Attack, origin: Vector3, aim: Vector3, now: number, allowed: { [number]: boolean }?): Hazard
	local projectiles: { Projectile } = {}
	if attack.Kind == "Barrage" then
		local targets = {}
		for id in allowed or {} do table.insert(targets, id) end
		table.sort(targets)
		for i = 1, attack.Count or 5 do
			table.insert(projectiles, { Position = origin + Vector3.new((i - 3) * 2, 8, 0), Target = targets[(i - 1) % math.max(#targets, 1) + 1] or 0, Hit = false })
		end
	end
	return { Attack = attack, Origin = origin, Aim = aim, Start = now, Previous = 0, Allowed = allowed,
		Hits = {}, Projectiles = projectiles, LastTick = -1 }
end
local function hit(id: number, hazard: Hazard, e: Entity, key: string)
	if hazard.Hits[key] then return end
	hazard.Hits[key] = true
	local a = hazard.Attack
	Characters.ApplyBossAttack(id, e.Id, a.Damage, a.Posture, a.Kind)
end
function Hazards.step(id: number, h: Hazard, now: number): boolean
	local a = h.Attack
	local elapsed, dt = now - h.Start, math.max(0, now - h.Start - h.Previous)
	local kind, height = a.Kind, a.Height or 6
	local speed = a.Speed or 36
	local sendProjectiles = math.floor(elapsed * 10) > h.LastTick
	local duration = a.Duration or (if kind == "Barrage" then a.Radius / speed + 1 else a.Radius / speed)
	local repeats, interval = a.Repeats or 1, a.Interval or 1
	for _, e in Characters.Entities() do
		if e.Kind ~= "Player" or not h.Allowed or not h.Allowed[e.Id] or e.Fighter.State == "KO" then continue end
		local p = e.Root.Position
		local delta = p - h.Origin
		local distance, altitude = Vector3.new(delta.X, 0, delta.Z).Magnitude, delta.Y
		if kind == "Barrage" then
			for i, projectile in h.Projectiles do
				if projectile.Hit or projectile.Target ~= e.Id then continue end
				local old = projectile.Position
				local direction = p - old
				local travel = math.min(direction.Magnitude, speed * dt)
				projectile.Position += if direction.Magnitude > 0.01 then direction.Unit * travel else Vector3.zero
				if (p - projectile.Position).Magnitude <= 3 then hit(id, h, e, tostring(i) .. ":" .. e.Id); projectile.Hit = true end
				if sendProjectiles then Characters.Cue("BossProjectile", id, { index = i, x = projectile.Position.X, y = projectile.Position.Y, z = projectile.Position.Z }) end
			end
		elseif kind == "Gravity" or kind == "Ritual" or kind == "Breath" or (kind == "Leap" and a.Element == "Frost") then
			local center = if kind == "Gravity" then h.Aim else h.Origin
			local d = p - center
			local inside = Vector3.new(d.X, 0, d.Z).Magnitude <= a.Radius and altitude <= height
			if kind == "Breath" then
				local endPoint = h.Aim + (h.Aim - h.Origin) * 2
				inside = altitude <= height and Rules.segmentHit(p.X, p.Z, h.Origin.X, h.Origin.Z, endPoint.X, endPoint.Z, 14)
			end
			if inside then
				if kind == "Gravity" and d.Magnitude > 2 then
					local pull = Vector3.new(-d.X, 0, -d.Z).Unit * 18
					e.Root.AssemblyLinearVelocity = Vector3.new(pull.X, e.Root.AssemblyLinearVelocity.Y, pull.Z)
				end
				hit(id, h, e, tostring(math.floor(elapsed / 0.8)) .. ":" .. e.Id)
			end
		else
			for pulse = 0, repeats - 1 do
				local age, previous = elapsed - pulse * interval, h.Previous - pulse * interval
				if age >= 0 and previous <= duration and Rules.waveHit(distance, altitude, age, previous, speed, a.Radius, height) then
					hit(id, h, e, tostring(pulse) .. ":" .. e.Id)
				end
			end
		end
	end
	h.Previous = elapsed
	h.LastTick = math.floor(elapsed * 10)
	return elapsed < duration + (repeats - 1) * interval
end
return Hazards

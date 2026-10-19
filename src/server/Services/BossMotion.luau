--!strict
local Characters = require(script.Parent.CharacterService)
local World = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.WorldDefinitions)
local Motion = {}
type Flight = { From: Vector3, To: Vector3, Start: number, Impact: number, Height: number, Kind: string, Perch: Vector3, Anchored: boolean }
local flights: { [number]: Flight } = {}
function Motion.clamp(id: number, point: Vector3): Vector3
	local e = Characters.GetEntity(id)
	local bossId = e and e.Model:GetAttribute("AsuraEncounter")
	local boss = if type(bossId) == "string" then World.Bosses[bossId] else nil
	if not boss then return point end
	local c, s = boss.Arena.Center, boss.Arena.Size
	return Vector3.new(math.clamp(point.X, c.X - s.X / 2 + 12, c.X + s.X / 2 - 12), point.Y,
		math.clamp(point.Z, c.Z - s.Z / 2 + 12, c.Z + s.Z / 2 - 12))
end
local function pillarPerch(id: number, target: Vector3): Vector3
	local e = Characters.GetEntity(id)
	local bossId = e and e.Model:GetAttribute("AsuraEncounter")
	local boss = if type(bossId) == "string" then World.Bosses[bossId] else nil
	if boss then
		local c = boss.Arena.Center
		return Vector3.new(c.X + (if target.X >= c.X then -60 else 60), 34, c.Z + (if target.Z >= c.Z then -50 else 50))
	end
	return Motion.clamp(id, target + Vector3.new(50, 31, -50))
end
function Motion.begin(id: number, kind: string, destination: Vector3, now: number, impact: number)
	Motion.cancel(id)
	local e = Characters.GetEntity(id)
	if not e then return end
	local target = Motion.clamp(id, destination)
	flights[id] = { From = e.Root.Position, To = target, Start = now, Impact = impact,
		Kind = kind, Perch = pillarPerch(id, target),
		Height = if kind == "Pillar" then 34 elseif kind == "Aerial" then 28 elseif kind == "Teleport" then 0 else 4,
		Anchored = e.Root.Anchored }
	e.Root.Anchored = true
	Characters.StopMoving(id)
end
function Motion.step(id: number, now: number)
	local flight, e = flights[id], Characters.GetEntity(id)
	if not flight or not e then return end
	local t = math.clamp((now - flight.Start) / math.max(flight.Impact - flight.Start, 0.01), 0, 1)
	-- Hang above a pillar/ceiling, then commit to the marked landing point.
	local point = flight.From:Lerp(flight.To, t) + Vector3.new(0, math.sin(math.pi * t) * flight.Height, 0)
	if flight.Kind == "Teleport" then point = if t < 0.75 then flight.From else flight.To end
	if flight.Kind == "Pillar" then
		point = if t < 0.3 then flight.From:Lerp(flight.Perch, t / 0.3) elseif t < 0.65 then flight.Perch else flight.Perch:Lerp(flight.To, (t - 0.65) / 0.35)
	end
	local direction = flight.To - flight.From
	local look = Vector3.new(direction.X, 0, direction.Z)
	e.Model:PivotTo(if look.Magnitude > 0.1 then CFrame.lookAt(point, point + Vector3.new(look.X, 0, look.Z)) else CFrame.new(point))
	if t >= 1 then Motion.cancel(id) end
end
function Motion.cancel(id: number)
	local flight, e = flights[id], Characters.GetEntity(id)
	if flight and e then e.Root.Anchored = flight.Anchored; e.Root.AssemblyLinearVelocity = Vector3.zero end
	flights[id] = nil
end
return Motion

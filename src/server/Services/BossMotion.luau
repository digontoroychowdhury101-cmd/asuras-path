--!strict
local Characters = require(script.Parent.CharacterService)
local World = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.WorldDefinitions)
local Bodies = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.BossBodies)
local Weapons = require(game:GetService("ReplicatedStorage").AsurasPath.Simulation.WeaponSchema)
local Motion = {}
type Flight = { From: Vector3, To: Vector3, Start: number, Impact: number, Height: number, Kind: string, Perch: Vector3, Anchored: boolean, Clear: number }
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
-- The pillar across the arena from the target, perched on its top (feet just above it), plus the
-- horizontal radius within which the body must stay above the column.
local function pillarPerch(id: number, target: Vector3): (Vector3, number)
	local e = Characters.GetEntity(id)
	local bossId = e and e.Model:GetAttribute("AsuraEncounter")
	local boss = if type(bossId) == "string" then World.Bosses[bossId] else nil
	if boss and e then
		local scale = e.Model:GetScale()
		local c = boss.Arena.Center
		for _, pillar in Bodies.pillars(boss) do
			if (pillar.X < c.X) == (target.X >= c.X) and (pillar.Z < c.Z) == (target.Z >= c.Z) then
				local hull = (Bodies.Hulls :: any)[boss.Archetype]
				local reach = if hull then math.max(hull[1], hull[3]) * 0.5 * scale else 2
				return Vector3.new(pillar.X, Bodies.perchY(pillar, scale), pillar.Z), pillar.Half * math.sqrt(2) + reach
			end
		end
	end
	return Motion.clamp(id, target + Vector3.new(50, 31, -50)), 0
end
-- Where a lunge or aerial landing should end: a body short of the marked point on the boss's
-- side, not inside the target (F10: Shen's Flowing Jian ended 0.2 studs from the player and
-- climbed onto them). Hits still resolve from the marked origin/aim, so reach and timing hold.
local function bodyStop(e: any): number
	local bossId = e.Model:GetAttribute("AsuraEncounter")
	local boss = if type(bossId) == "string" then World.Bosses[bossId] else nil
	local hull = if boss then (Bodies.Hulls :: any)[boss.Archetype] else nil
	return (if hull then math.max(hull[1], hull[3]) * 0.5 else 1) * e.Model:GetScale() + 2
end
-- The living partner of a Twin (same encounter, another enemy body), and the spacing two bodies keep.
function Motion.partner(e: any): any?
	local encounter = e.Model:GetAttribute("AsuraEncounter")
	if type(encounter) ~= "string" then return nil end
	for _, other in Characters.Entities() do
		if other ~= e and other.Kind == "Enemy" and other.Fighter.State ~= "KO" and other.Model:GetAttribute("AsuraEncounter") == encounter then
			return other
		end
	end
	return nil
end
function Motion.duoGap(a: any, b: any): number
	return 2.5 * (a.Model:GetScale() + b.Model:GetScale())
end
function Motion.approach(id: number, kind: string, aim: Vector3): Vector3
	local e = Characters.GetEntity(id)
	if not e or (kind ~= "Lunge" and kind ~= "Aerial") then return aim end
	local at = e.Root.Position
	local x, z = Bodies.closeIn(at.X, at.Z, aim.X, aim.Z, bodyStop(e))
	-- A Twin's lunge ends on its engage point (the AI's closeIn stop), clear of its partner (post-F26
	-- Step 4: both ended 3 studs apart on the player). Hits still use the marked origin and aim.
	local partner = Motion.partner(e)
	if partner then
		local o = partner.Root.Position
		local stop = math.max(bodyStop(e), Weapons.get(e.Fighter.Weapon).Light[1].Reach * 0.6)
		x, z = Bodies.flank(at.X, at.Z, aim.X, aim.Z, stop, o.X, o.Z, Motion.duoGap(e, partner))
	end
	return Vector3.new(x, aim.Y, z)
end
function Motion.begin(id: number, kind: string, destination: Vector3, now: number, impact: number)
	Motion.cancel(id)
	local e = Characters.GetEntity(id)
	if not e then return end
	local target = Motion.clamp(id, destination)
	local perch, clear = pillarPerch(id, target)
	if kind == "Pillar" then -- the pounce comes down beside the mark, on the pillar's side (F11: it landed on the player)
		local x, z = Bodies.closeIn(perch.X, perch.Z, target.X, target.Z, bodyStop(e))
		target = Vector3.new(x, target.Y, z)
	end
	flights[id] = { From = e.Root.Position, To = target, Start = now, Impact = impact, Clear = clear,
		Kind = kind, Perch = perch,
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
		-- Rise before crossing the column, hold on its top, leave the top before falling (BossBodies.arc).
		local from, perch, to = flight.From, flight.Perch, flight.To
		local p = if t < 0.3 then Bodies.arc({ from.X, from.Y, from.Z }, { perch.X, perch.Y, perch.Z }, perch.Y, flight.Clear, false, true, t / 0.3)
			elseif t < 0.65 then { perch.X, perch.Y, perch.Z }
			else Bodies.arc({ perch.X, perch.Y, perch.Z }, { to.X, to.Y, to.Z }, perch.Y, flight.Clear, true, false, (t - 0.65) / 0.35)
		point = Vector3.new(p[1], p[2], p[3])
	end
	local direction = flight.To - flight.From
	local look = Vector3.new(direction.X, 0, direction.Z)
	e.Model:PivotTo(if look.Magnitude > 0.1 then CFrame.lookAt(point, point + Vector3.new(look.X, 0, look.Z)) else CFrame.new(point))
	if t >= 1 then Motion.cancel(id) end
end
-- A felled body keeps the anchor settleCorpse gave it (F12: a Wyrm killed in flight was set on the
-- floor, then this restored its pre-flight unanchored root and it fell through the arena).
function Motion.cancel(id: number)
	local flight, e = flights[id], Characters.GetEntity(id)
	if flight and e then
		if e.Fighter.State ~= "KO" then e.Root.Anchored = flight.Anchored end
		e.Root.AssemblyLinearVelocity = Vector3.zero
	end
	flights[id] = nil
end
return Motion

--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/BossBodies
-- Authoritative body shapes for the bosses that are not upright humanoids (batches 12-13). The
-- capsules are root-relative studs at scale 1 (CharacterService.ScaleEnemy multiplies them with the
-- model), use the existing injury regions, and are what the visual creature looks are authored
-- around, so a hit that lands on the body is a hit the server sees. Also holds the arena pillar
-- layout and the pure path maths that keep the beast from clipping through it.
local Bodies = {}

export type Capsule = { Region: string, A: { number }, B: { number }, Radius: number }
export type Shape = { Capsules: { Capsule }, Box: { number }, Reach: number }
export type Pillar = { X: number, Z: number, Half: number, Top: number }

local function c(region: string, a: { number }, b: { number }, radius: number): Capsule
	return { Region = region, A = a, B = b, Radius = radius }
end

-- Box = { centreY, halfX, halfY, halfZ } broad phase; Reach = furthest capsule surface from the root.
Bodies.Shapes = table.freeze({
	-- Venerable Baize: a low frost beast, head forward, forelegs as the "arms".
	Beast = { Capsules = {
		c("Head", { 0, 0.35, -2.25 }, { 0, 0.55, -2.75 }, 0.62),
		c("Torso", { 0, -0.55, -1.25 }, { 0, -0.45, 1.45 }, 1.05),
		c("LeftArm", { -0.75, -1.2, -1.2 }, { -0.75, -2.62, -1.3 }, 0.38),
		c("RightArm", { 0.75, -1.2, -1.2 }, { 0.75, -2.62, -1.3 }, 0.38),
		c("LeftLeg", { -0.8, -1.15, 1.25 }, { -0.8, -2.58, 1.4 }, 0.42),
		c("RightLeg", { 0.8, -1.15, 1.25 }, { 0.8, -2.58, 1.4 }, 0.42),
	}, Box = { -1.0, 1.8, 2.1, 3.6 }, Reach = 3.6 },
	-- Azure Wyrm: a horned dragon on four short legs; the tail is part of the body.
	Dragon = { Capsules = {
		c("Head", { 0, 0.55, -2.55 }, { 0, 1.05, -3.35 }, 0.7),
		c("Torso", { 0, -0.6, -1.7 }, { 0, -0.4, 1.7 }, 1.15),
		c("Torso", { 0, -0.6, 2.2 }, { 0, -1.5, 5.2 }, 0.5),
		c("LeftArm", { -0.9, -1.3, -1.2 }, { -0.95, -2.6, -1.35 }, 0.4),
		c("RightArm", { 0.9, -1.3, -1.2 }, { 0.95, -2.6, -1.35 }, 0.4),
		c("LeftLeg", { -0.95, -1.3, 1.2 }, { -1.0, -2.55, 1.35 }, 0.45),
		c("RightLeg", { 0.95, -1.3, 1.2 }, { 1.0, -2.55, 1.35 }, 0.45),
	}, Box = { -0.6, 2.1, 2.4, 4.9 }, Reach = 5.8 },
})

-- World-geometry hulls (size x,y,z then centre x,y,z) that stop the long bodies at pillars and walls.
Bodies.Hulls = table.freeze({ Beast = { 2.2, 1.5, 5.0, 0, -0.45, 0.05 }, Dragon = { 2.6, 1.7, 6.2, 0, -0.45, 0.4 } })
Bodies.RootHeight = 3 -- root above the ground at scale 1 (HipHeight 2 + half the root)

function Bodies.shape(archetype: string?): Shape?
	return if archetype then (Bodies.Shapes :: any)[archetype] else nil
end

-- The frost pillars of Baize's arena (BossArenas builds them; AI and BossMotion avoid them).
function Bodies.pillars(boss: any): { Pillar }
	if not boss or boss.Archetype ~= "Beast" then return {} end
	local list: { Pillar } = {}
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(list, { X = boss.Arena.Center.X + x * 60, Z = boss.Arena.Center.Z + z * 50, Half = 4, Top = 30 })
		end
	end
	return list
end

-- Root height standing on a pillar top: top + root height + a small gap so feet never sink.
function Bodies.perchY(pillar: Pillar, scale: number): number
	return pillar.Top + Bodies.RootHeight * scale + 0.2
end

-- Walking: if the straight line to (tx,tz) passes within `clear` of a pillar's footprint, return
-- the tangent point round the nearest such pillar on the shorter side (a path to a tangent point
-- never cuts the column's corner); otherwise the goal itself.
function Bodies.steer(fx: number, fz: number, tx: number, tz: number, pillars: { Pillar }, clear: number): (number, number)
	local dx, dz = tx - fx, tz - fz
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.5 then return tx, tz end
	local ux, uz = dx / length, dz / length
	local best, bx, bz = math.huge, tx, tz
	for _, p in pillars do
		local radius = p.Half * math.sqrt(2) + clear
		local along = (p.X - fx) * ux + (p.Z - fz) * uz
		local side = (p.X - fx) * -uz + (p.Z - fz) * ux
		if along > -radius and along < length + radius and math.abs(side) < radius and along < best then
			best = along
			local rx, rz = fx - p.X, fz - p.Z
			local d = math.sqrt(rx * rx + rz * rz)
			local wide = radius + 1
			local options: { { number } } = {}
			if d <= wide then -- already in the margin: slide round the column
				for _, s in { -1, 1 } do table.insert(options, { fx - rz / d * s * wide, fz + rx / d * s * wide }) end
			else
				local base, turn = math.atan2(rz, rx), math.acos(wide / d)
				for _, s in { -1, 1 } do table.insert(options, { p.X + math.cos(base + s * turn) * wide, p.Z + math.sin(base + s * turn) * wide }) end
			end
			local cost = math.huge
			for _, o in options do
				local c = math.sqrt((o[1] - fx) ^ 2 + (o[2] - fz) ^ 2) + math.sqrt((tx - o[1]) ^ 2 + (tz - o[2]) ^ 2)
				if c < cost then cost, bx, bz = c, o[1], o[2] end
			end
		end
	end
	return bx, bz
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- A leap that must stay at height `high` while within `clear` horizontal studs of the pillar it
-- leaves (`fromPillar`) or lands on (`toPillar`), so the body rises before it crosses the column
-- and leaves the top before it falls. u runs 0..1; points are { x, y, z }.
-- F07/F08: where a melee foe walks to engage: `stop` studs short of its target on the side it comes
-- from. Steered at the target's own root, a humanoid pushed into the player and climbed onto their
-- head (Studio: the Sparring Phantom stood 4 studs up at 0.8 flat and every swing passed beneath it).
function Bodies.closeIn(fx: number, fz: number, tx: number, tz: number, stop: number): (number, number)
	local dx, dz = fx - tx, fz - tz
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-3 then dx, dz, d = 0, 1, 1 end
	return tx + dx / d * stop, tz + dz / d * stop
end

function Bodies.arc(from: { number }, to: { number }, high: number, clear: number, fromPillar: boolean, toPillar: boolean, u: number): { number }
	local dx, dz = to[1] - from[1], to[3] - from[3]
	local distance = math.sqrt(dx * dx + dz * dz)
	local cramped = (fromPillar or toPillar) and distance <= clear * 1.05
	if cramped then
		-- Too close for a slope: rise then cross (landing), or cross then drop (leaving).
		local first, second = smooth(u * 2), smooth(u * 2 - 1)
		if toPillar then
			return { from[1] + dx * second, from[2] + (high - from[2]) * first, from[3] + dz * second }
		end
		return { from[1] + dx * first, high + (to[2] - high) * second, from[3] + dz * first }
	end
	local s = smooth(u)
	local travelled = distance * s
	local y: number
	if toPillar then
		y = from[2] + (high - from[2]) * math.clamp(travelled / math.max(distance - clear, 0.01), 0, 1) ^ 0.55
	elseif fromPillar then
		y = high + (to[2] - high) * math.clamp((travelled - clear) / math.max(distance - clear, 0.01), 0, 1) ^ 1.6
	else
		y = from[2] + (to[2] - from[2]) * s
	end
	return { from[1] + dx * s, y, from[3] + dz * s }
end

return table.freeze(Bodies)

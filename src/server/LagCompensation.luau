--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/LagCompensation
-- 60 Hz pose history per entity and continuous weapon-vs-hurtbox queries against rewound poses.
-- Ring slots are allocated once; recording overwrites in place and sampling returns multiple values.

export type Capsule = { Region: string, A: Vector3, B: Vector3, Radius: number }
export type Profile = { Capsules: { Capsule }, BoxOffset: CFrame, BoxHalfSize: Vector3, Reach: number }

export type History = {
	Capacity: number,
	Head: number,
	Count: number,
	Times: { number },
	CFrames: { CFrame },
	Velocities: { Vector3 },
	WeaponA: { Vector3 },
	WeaponB: { Vector3 },
	WeaponRadius: { number },
	Profile: Profile,
}

export type Hit = { Region: string, Point: Vector3, Fraction: number, Distance: number }

local LagCompensation = {}

LagCompensation.TICK_RATE = 60
LagCompensation.TICK = 1 / 60
LagCompensation.HISTORY_FRAMES = 30
LagCompensation.MAX_REWIND = 0.15
LagCompensation.INTERPOLATION_DELAY = 1 / 30
LagCompensation.MAX_SWEEP_STEPS = 12

local EPSILON = 1e-9
local ZERO = Vector3.zero
local GOLDEN = (math.sqrt(5) - 1) / 2

-- Root-part-relative capsules for a standard R15 humanoid (HumanoidRootPart at the hip line).
LagCompensation.HumanoidProfile = table.freeze({
	Capsules = table.freeze({
		table.freeze({ Region = "Head", A = Vector3.new(0, 1.55, 0), B = Vector3.new(0, 2.05, 0), Radius = 0.6 }),
		table.freeze({ Region = "Torso", A = Vector3.new(0, -0.15, 0), B = Vector3.new(0, 1.05, 0), Radius = 0.95 }),
		table.freeze({ Region = "LeftArm", A = Vector3.new(-1.5, 1.05, 0), B = Vector3.new(-1.5, -0.55, 0), Radius = 0.45 }),
		table.freeze({ Region = "RightArm", A = Vector3.new(1.5, 1.05, 0), B = Vector3.new(1.5, -0.55, 0), Radius = 0.45 }),
		table.freeze({ Region = "LeftLeg", A = Vector3.new(-0.5, -0.95, 0), B = Vector3.new(-0.5, -2.75, 0), Radius = 0.5 }),
		table.freeze({ Region = "RightLeg", A = Vector3.new(0.5, -0.95, 0), B = Vector3.new(0.5, -2.75, 0), Radius = 0.5 }),
	}),
	BoxOffset = CFrame.new(0, -0.3, 0),
	BoxHalfSize = Vector3.new(2.05, 2.95, 1.0),
	Reach = 3.6,
}) :: Profile

function LagCompensation.newHistory(profile: Profile?, capacity: number?): History
	local size = capacity or LagCompensation.HISTORY_FRAMES
	assert(size % 1 == 0 and size >= 2 and size <= 240, "History capacity must be an integer in 2..240")
	local times: { number } = table.create(size, -math.huge)
	local cframes: { CFrame } = table.create(size, CFrame.identity)
	local velocities: { Vector3 } = table.create(size, ZERO)
	local weaponA: { Vector3 } = table.create(size, ZERO)
	local weaponB: { Vector3 } = table.create(size, ZERO)
	local weaponRadius: { number } = table.create(size, 0)
	return {
		Capacity = size,
		Head = 0,
		Count = 0,
		Times = times,
		CFrames = cframes,
		Velocities = velocities,
		WeaponA = weaponA,
		WeaponB = weaponB,
		WeaponRadius = weaponRadius,
		Profile = profile or LagCompensation.HumanoidProfile,
	}
end

function LagCompensation.clear(history: History)
	history.Head = 0
	history.Count = 0
end

local function slot(history: History, logical: number): number
	-- logical 0 = oldest, Count-1 = newest
	return (history.Head - history.Count + logical) % history.Capacity + 1
end

function LagCompensation.record(history: History, time: number, cframe: CFrame, velocity: Vector3, weaponA: Vector3?, weaponB: Vector3?, weaponRadius: number?)
	local index: number
	if history.Count > 0 and time <= history.Times[history.Head] + EPSILON then
		-- Same or older tick: refresh the newest sample rather than breaking monotonic order.
		index = history.Head
		time = history.Times[index]
	else
		history.Head = history.Head % history.Capacity + 1
		history.Count = math.min(history.Count + 1, history.Capacity)
		index = history.Head
	end
	history.Times[index] = time
	history.CFrames[index] = cframe
	history.Velocities[index] = velocity
	history.WeaponA[index] = weaponA or cframe.Position
	history.WeaponB[index] = weaponB or cframe.Position
	history.WeaponRadius[index] = weaponRadius or 0
end

function LagCompensation.newestTime(history: History): number?
	if history.Count == 0 then
		return nil
	end
	return history.Times[history.Head]
end

function LagCompensation.oldestTime(history: History): number?
	if history.Count == 0 then
		return nil
	end
	return history.Times[slot(history, 0)]
end

-- Largest logical index whose time is <= t (bisection); -1 when t predates the history.
local function bisect(history: History, t: number): number
	local low, high = 0, history.Count - 1
	if t < history.Times[slot(history, 0)] then
		return -1
	end
	if t >= history.Times[slot(history, high)] then
		return high
	end
	while high - low > 1 do
		local mid = (low + high) // 2
		if history.Times[slot(history, mid)] <= t then
			low = mid
		else
			high = mid
		end
	end
	return low
end

-- Interpolated pose at t, clamped to the stored range: (cframe, velocity, weaponA, weaponB, weaponRadius).
function LagCompensation.samplePoseAt(history: History, timestamp: number): (CFrame?, Vector3, Vector3, Vector3, number)
	if history.Count == 0 then
		return nil, ZERO, ZERO, ZERO, 0
	end
	local lower = bisect(history, timestamp)
	if lower < 0 then
		local i = slot(history, 0)
		return history.CFrames[i], history.Velocities[i], history.WeaponA[i], history.WeaponB[i], history.WeaponRadius[i]
	end
	local i = slot(history, lower)
	if lower >= history.Count - 1 then
		return history.CFrames[i], history.Velocities[i], history.WeaponA[i], history.WeaponB[i], history.WeaponRadius[i]
	end
	local j = slot(history, lower + 1)
	local t0, t1 = history.Times[i], history.Times[j]
	local alpha = if t1 - t0 > EPSILON then math.clamp((timestamp - t0) / (t1 - t0), 0, 1) else 0
	if alpha <= EPSILON then
		return history.CFrames[i], history.Velocities[i], history.WeaponA[i], history.WeaponB[i], history.WeaponRadius[i]
	end
	return history.CFrames[i]:Lerp(history.CFrames[j], alpha),
		history.Velocities[i]:Lerp(history.Velocities[j], alpha),
		history.WeaponA[i]:Lerp(history.WeaponA[j], alpha),
		history.WeaponB[i]:Lerp(history.WeaponB[j], alpha),
		history.WeaponRadius[i] + (history.WeaponRadius[j] - history.WeaponRadius[i]) * alpha
end

-- Server time to rewind a target to for an attacker. Client claims are trusted only inside the
-- MAX_REWIND ceiling and never beyond measured round-trip plus interpolation delay.
function LagCompensation.rewindTime(now: number, claimedTime: number?, ping: number?): number
	local budget = LagCompensation.MAX_REWIND
	if ping ~= nil and ping == ping and ping >= 0 then
		budget = math.min(budget, ping + LagCompensation.INTERPOLATION_DELAY + LagCompensation.TICK)
	end
	local earliest = now - budget
	if claimedTime == nil or claimedTime ~= claimedTime then
		return earliest
	end
	return math.clamp(claimedTime, earliest, now)
end

-- Closest points between segments p1q1 and p2q2: (distanceSquared, s, t, closest1, closest2).
function LagCompensation.segmentSegment(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): (number, number, number, Vector3, Vector3)
	local d1 = q1 - p1
	local d2 = q2 - p2
	local r = p1 - p2
	local a = d1:Dot(d1)
	local e = d2:Dot(d2)
	local f = d2:Dot(r)
	local s, t
	if a <= EPSILON and e <= EPSILON then
		local diff = p1 - p2
		return diff:Dot(diff), 0, 0, p1, p2
	end
	if a <= EPSILON then
		s = 0
		t = math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= EPSILON then
			t = 0
			s = math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			s = if denom > EPSILON then math.clamp((b * f - c * e) / denom, 0, 1) else 0
			t = (b * s + f) / e
			if t < 0 then
				t = 0
				s = math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t = 1
				s = math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	local c1 = p1 + d1 * s
	local c2 = p2 + d2 * t
	local diff = c1 - c2
	return diff:Dot(diff), s, t, c1, c2
end

function LagCompensation.capsuleCapsule(a0: Vector3, a1: Vector3, ra: number, b0: Vector3, b1: Vector3, rb: number): (boolean, number, Vector3)
	local distSq, _, _, c1, c2 = LagCompensation.segmentSegment(a0, a1, b0, b1)
	local radius = ra + rb
	local distance = math.sqrt(distSq)
	local point = if distance > EPSILON then c2 + (c1 - c2) * ((rb) / distance) else c2
	return distSq <= radius * radius, distance - radius, point
end

local function pointBoxDistanceSq(localPoint: Vector3, half: Vector3): number
	local dx = math.max(math.abs(localPoint.X) - half.X, 0)
	local dy = math.max(math.abs(localPoint.Y) - half.Y, 0)
	local dz = math.max(math.abs(localPoint.Z) - half.Z, 0)
	return dx * dx + dy * dy + dz * dz
end

-- Segment-to-OBB distance. Distance to a convex set is convex along the segment, so a golden-section
-- search converges to the true minimum; 24 iterations resolve well below 1e-4 studs on weapon lengths.
function LagCompensation.segmentBoxDistance(p: Vector3, q: Vector3, box: CFrame, half: Vector3): (number, Vector3)
	local lp = box:PointToObjectSpace(p)
	local lq = box:PointToObjectSpace(q)
	local delta = lq - lp
	local low, high = 0, 1
	local x1 = high - GOLDEN * (high - low)
	local x2 = low + GOLDEN * (high - low)
	local f1 = pointBoxDistanceSq(lp + delta * x1, half)
	local f2 = pointBoxDistanceSq(lp + delta * x2, half)
	for _ = 1, 24 do
		if f1 <= f2 then
			high = x2
			x2 = x1
			f2 = f1
			x1 = high - GOLDEN * (high - low)
			f1 = pointBoxDistanceSq(lp + delta * x1, half)
		else
			low = x1
			x1 = x2
			f1 = f2
			x2 = low + GOLDEN * (high - low)
			f2 = pointBoxDistanceSq(lp + delta * x2, half)
		end
	end
	local best = (low + high) * 0.5
	local bestSq = pointBoxDistanceSq(lp + delta * best, half)
	local startSq = pointBoxDistanceSq(lp, half)
	local endSq = pointBoxDistanceSq(lq, half)
	if startSq < bestSq then
		best, bestSq = 0, startSq
	end
	if endSq < bestSq then
		best, bestSq = 1, endSq
	end
	return math.sqrt(bestSq), p + (q - p) * best
end

local function sweepSteps(prevA: Vector3, prevB: Vector3, curA: Vector3, curB: Vector3, radius: number, targetTravel: number): number
	local travel = math.max((curA - prevA).Magnitude, (curB - prevB).Magnitude) + targetTravel
	local spacing = math.max(radius, 0.25)
	return math.clamp(math.ceil(travel / spacing), 1, LagCompensation.MAX_SWEEP_STEPS)
end

-- Swept weapon capsule vs a target OBB moving from boxFrom to boxTo over the same interval.
function LagCompensation.sweptCapsuleVsBox(prevA: Vector3, prevB: Vector3, curA: Vector3, curB: Vector3, radius: number, boxFrom: CFrame, boxTo: CFrame, half: Vector3): (boolean, number, Vector3)
	local steps = sweepSteps(prevA, prevB, curA, curB, radius, (boxTo.Position - boxFrom.Position).Magnitude)
	for step = 0, steps do
		local alpha = step / steps
		local a = prevA:Lerp(curA, alpha)
		local b = prevB:Lerp(curB, alpha)
		local box = if alpha <= 0 then boxFrom elseif alpha >= 1 then boxTo else boxFrom:Lerp(boxTo, alpha)
		local distance, point = LagCompensation.segmentBoxDistance(a, b, box, half)
		if distance <= radius then
			return true, alpha, point
		end
	end
	return false, 1, curB
end

-- Swept weapon capsule vs a target capsule moving with its root between two poses.
function LagCompensation.sweptCapsuleVsCapsule(prevA: Vector3, prevB: Vector3, curA: Vector3, curB: Vector3, radius: number, capsule: Capsule, rootFrom: CFrame, rootTo: CFrame): (boolean, number, Vector3, number)
	local steps = sweepSteps(prevA, prevB, curA, curB, radius, (rootTo.Position - rootFrom.Position).Magnitude)
	local closest = math.huge
	for step = 0, steps do
		local alpha = step / steps
		local a = prevA:Lerp(curA, alpha)
		local b = prevB:Lerp(curB, alpha)
		local root = if alpha <= 0 then rootFrom elseif alpha >= 1 then rootTo else rootFrom:Lerp(rootTo, alpha)
		local hit, gap, point = LagCompensation.capsuleCapsule(a, b, radius, root:PointToWorldSpace(capsule.A), root:PointToWorldSpace(capsule.B), capsule.Radius)
		closest = math.min(closest, gap)
		if hit then
			return true, alpha, point, gap
		end
	end
	return false, 1, curB, closest
end

-- Full query: swept-box broadphase then per-region swept capsules against the target rewound to
-- `rewindTo`. Returns the earliest-contact region (ties broken by deepest penetration).
function LagCompensation.queryHit(prevA: Vector3, prevB: Vector3, curA: Vector3, curB: Vector3, radius: number, target: History, rewindTo: number, interval: number?): Hit?
	if target.Count == 0 then
		return nil
	end
	local span = interval or LagCompensation.TICK
	local rootTo = LagCompensation.samplePoseAt(target, rewindTo)
	local rootFrom = LagCompensation.samplePoseAt(target, rewindTo - span)
	if rootTo == nil or rootFrom == nil then
		return nil
	end
	local profile = target.Profile
	local reachSq = (profile.Reach + radius + (curB - curA).Magnitude + (curB - prevB).Magnitude) ^ 2
	local offset = rootTo.Position - curA
	if offset:Dot(offset) > reachSq then
		return nil
	end
	local broad = LagCompensation.sweptCapsuleVsBox(prevA, prevB, curA, curB, radius, rootFrom * profile.BoxOffset, rootTo * profile.BoxOffset, profile.BoxHalfSize)
	if not broad then
		return nil
	end
	local bestRegion: string? = nil
	local bestFraction, bestGap = math.huge, math.huge
	local bestPoint = curB
	for _, capsule in profile.Capsules do
		local hit, fraction, point, gap = LagCompensation.sweptCapsuleVsCapsule(prevA, prevB, curA, curB, radius, capsule, rootFrom, rootTo)
		if hit and (fraction < bestFraction - EPSILON or (math.abs(fraction - bestFraction) <= EPSILON and gap < bestGap)) then
			bestRegion, bestFraction, bestGap, bestPoint = capsule.Region, fraction, gap, point
		end
	end
	if bestRegion == nil then
		return nil
	end
	return { Region = bestRegion, Point = bestPoint, Fraction = bestFraction, Distance = bestGap }
end

return table.freeze(LagCompensation)

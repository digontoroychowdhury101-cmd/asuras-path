--!strict
local Rules = {}
Rules.ThrustWindow = 0.1
Rules.MinimumWarning = 0.65
Rules.AttackKinds = table.freeze({ PerilousSweep = true, PerilousThrust = true, PerilousGrab = true,
	Shockwave = true, Barrage = true, Gravity = true, Ritual = true, Leap = true, Breath = true, Tail = true, ShieldCharge = true })
function Rules.classify(kind: string): (boolean, string)
	if kind == "PerilousSweep" or kind == "Tail" then return true, "Double Jump" end
	if kind == "PerilousThrust" then return true, "Deflect" end
	if kind == "PerilousGrab" then return true, "Slide Dash" end
	if kind == "Gravity" then return false, "Bullet Jump" end
	if kind == "Shockwave" or kind == "Leap" or kind == "Ritual" or kind == "Breath" then return true, "Air Glide" end
	return false, "Evade"
end
function Rules.impact(now: number, windup: number): number
	return now + math.max(Rules.MinimumWarning, windup)
end
function Rules.tightDeflect(pressedAt: number, impactAt: number): boolean
	local delta = impactAt - pressedAt
	return delta >= 0 and delta <= Rules.ThrustWindow + 1e-9
end
-- Swept annulus: remains correct when a frame steps across a fast moving ring.
function Rules.waveHit(distance: number, height: number, elapsed: number, previous: number, speed: number, radius: number, clearance: number): boolean
	return height <= clearance and distance <= radius and distance >= math.max(0, previous * speed - 3)
		and distance <= math.min(radius, elapsed * speed + 3)
end
function Rules.segmentHit(px: number, pz: number, ax: number, az: number, bx: number, bz: number, width: number): boolean
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / math.max(dx * dx + dz * dz, 0.001), 0, 1)
	return (px - ax - dx * t)^2 + (pz - az - dz * t)^2 <= width^2
end
function Rules.shouldClose(distance: number, farSince: number, now: number, range: number, delay: number): boolean
	return distance > range and now - farSince >= delay
end
function Rules.enrage(alive: number, alreadyEnraged: boolean): boolean
	return alive == 1 and not alreadyEnraged
end
function Rules.lifecycle(living: number, defeated: boolean, entityPresent: boolean): string
	if defeated then return "Victory" end
	if living == 0 or not entityPresent then return "Reset" end
	return "Sealed"
end
function Rules.loot(essence: number, count: number): { { X: number, Z: number, Amount: number } }
	local drops = {}
	for i = 1, count do
		local angle = (i - 1) * math.pi * 2 / count
		table.insert(drops, { X = math.cos(angle) * 7, Z = math.sin(angle) * 7,
			Amount = math.floor(essence / count) + (if i <= essence % count then 1 else 0) })
	end
	return drops
end
return table.freeze(Rules)

--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Simulation/AnimationTiming
-- Pure playback timing (combat recovery Stage 3, TIMING_CONTRACT §7-8): the mapping from an action's server
-- timeline to its clip's timeline, the bounded phase correction that replaced the hard seat and 2x catch-up, and
-- the critically damped decay behind pose inertialization. Numbers only, so it runs and is tested without the engine.
-- Adapted (see THIRD_PARTY_NOTICES.md) from Orange Duck Motion-Matching @ 57b7250: spring.h decay_spring_damper_exact,
-- damp_adjustment_exact; controller.cpp adjust_character_position_by_velocity (the cap relative to current motion).
local Timing = {}

Timing.MIN_RATE = 0.75 -- A6: slowest correction, relative to the phase's authored rate
Timing.MAX_RATE = 1.5 -- A6 / A10: fastest correction; nothing catches up faster
Timing.SEAT_LIMIT = 0.25 -- error beyond this is a real discontinuity: seated once, counted, and inertialized
Timing.CORRECTION_HALFLIFE = 0.05
Timing.TICK_TOLERANCE = 1 / 120 -- half a server tick: errors inside this are not worth a rate change

local LN2 = 0.69314718056

export type Phases = {
	Startup: number, -- server seconds to the first active frame
	Active: number,
	Total: number,
	ClipContact: number, -- clip seconds of the first active frame
	ClipActiveEnd: number,
	ClipLength: number,
}

-- A one-to-one mapping for a clip authored on its move's own frame data.
function Timing.identity(startup: number, active: number, total: number): Phases
	return { Startup = startup, Active = active, Total = total, ClipContact = startup, ClipActiveEnd = startup + active, ClipLength = total }
end

-- A clip stretched evenly over an action (dodge, reaction, deflect): every phase runs at length/duration.
function Timing.uniform(duration: number, clipLength: number): Phases
	return { Startup = duration, Active = 0, Total = duration, ClipContact = clipLength, ClipActiveEnd = clipLength, ClipLength = clipLength }
end

local function segment(p: Phases, elapsed: number): (number, number, number)
	-- (server start of the phase, clip start of the phase, clip seconds per server second)
	if elapsed < p.Startup then
		return 0, 0, if p.Startup > 0 then p.ClipContact / p.Startup else 1
	elseif elapsed < p.Startup + p.Active then
		return p.Startup, p.ClipContact, if p.Active > 0 then (p.ClipActiveEnd - p.ClipContact) / p.Active else 1
	end
	local recovery = p.Total - p.Startup - p.Active
	return p.Startup + p.Active, p.ClipActiveEnd, if recovery > 1e-6 then (p.ClipLength - p.ClipActiveEnd) / recovery else 1
end

-- Clip seconds for `elapsed` server seconds into the action. Held at the end of the clip past its total.
function Timing.clipTime(p: Phases, elapsed: number): number
	if elapsed <= 0 then
		return 0
	end
	local serverStart, clipStart, rate = segment(p, elapsed)
	return math.min(clipStart + (elapsed - serverStart) * rate, p.ClipLength)
end

-- Clip seconds per server second at this point of the action (the rate playing at 1x relative to the server).
function Timing.nominalRate(p: Phases, elapsed: number): number
	local _, _, rate = segment(p, math.max(elapsed, 0))
	return rate
end

-- Where a swing first seen late starts, and how fast it plays until its contact: it keeps as much windup as the
-- bounded rate allows and reaches the contact on the server's clock when it can. Past the point of no recovery it
-- starts at its true phase (the old 2x would have compressed the telegraph instead).
function Timing.plan(p: Phases, elapsed: number): (number, number)
	local position = Timing.clipTime(p, elapsed)
	if elapsed <= 0 or elapsed >= p.Startup or p.Startup <= 0 then
		return position, 1
	end
	local remaining = p.Startup - elapsed -- server seconds until the strike lands
	local nominal = p.ClipContact / p.Startup
	local seat = math.max(0, p.ClipContact - remaining * nominal * Timing.MAX_RATE)
	local rate = (p.ClipContact - seat) / (remaining * nominal)
	return seat, math.clamp(rate, 1, Timing.MAX_RATE)
end

-- The rate factor (relative to the phase's nominal rate) that pulls `clip` toward `target`, and whether the error
-- is a discontinuity that must be seated instead. The adjustment is damped, then capped relative to the clip's own
-- motion, so a stopped or slow clip is never dragged and nothing ever exceeds [MIN_RATE, MAX_RATE].
function Timing.correct(clip: number, target: number, nominal: number, dt: number): (number, boolean)
	local err = target - clip
	if math.abs(err) > Timing.SEAT_LIMIT then
		return 1, true
	end
	if math.abs(err) <= Timing.TICK_TOLERANCE or dt <= 0 or nominal <= 1e-6 then
		return 1, false
	end
	local adjustment = err * (1 - math.exp(-LN2 * dt / Timing.CORRECTION_HALFLIFE))
	return math.clamp(1 + adjustment / (nominal * dt), Timing.MIN_RATE, Timing.MAX_RATE), false
end

-- Exact critically damped decay toward zero of a value and its velocity (decay_spring_damper_exact).
function Timing.decay(x: number, v: number, halflife: number, dt: number): (number, number)
	local y = (4 * LN2) / (halflife + 1e-5) / 2
	local j1 = v + x * y
	local e = math.exp(-y * dt)
	return e * (x + j1 * dt), e * (v - j1 * y * dt)
end

return table.freeze(Timing)

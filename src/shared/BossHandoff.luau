--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/BossHandoff
-- The shared boss-entry contract (#16). Whenever an encounter takes the camera (entry framing, a
-- phase metamorphosis, the surviving Twin's oath) the player is locked and protected for exactly
-- the shot plus the camera's return blend; the boss holds for the same window; and no boss impact
-- may land sooner than Lead seconds after readable control resumes. Skipping ends the lock early
-- (the lead then counts from the skip); death, reset and leaving release it at once. Pure timing,
-- shared by the server scheduler and the client camera so both agree on when control returns.
local Handoff = {}

Handoff.Shots = table.freeze({ Intro = 2.4, Phase = 1.2, Enrage = 1.1 }) -- seconds the camera is held
Handoff.Blend = 0.35 -- the follow camera's return to the player after a shot
Handoff.Lead = 0.9 -- minimum readable warning between control returning and the first impact

export type Window = { Kind: string, Start: number, Lock: number, Ends: number, Skipped: boolean }

function Handoff.shot(kind: string): number
	return Handoff.Shots[kind] or Handoff.Shots.Phase
end

-- A new window opening at `now`: locked until Lock, protected until Ends (= Lock + Blend).
function Handoff.window(kind: string, now: number): Window
	local lock = now + Handoff.shot(kind)
	return { Kind = kind, Start = now, Lock = lock, Ends = lock + Handoff.Blend, Skipped = false }
end

function Handoff.protected(window: Window?, now: number): boolean
	return window ~= nil and now < window.Ends
end

-- The earliest moment a boss strike may connect once this window has opened.
function Handoff.earliest(window: Window): number
	return window.Ends + Handoff.Lead
end

-- Pushes an impact scheduled during a handoff out to the readable minimum; never earlier.
function Handoff.defer(impact: number, window: Window?): number
	if not window then return impact end
	return math.max(impact, Handoff.earliest(window))
end

-- Skipping closes the shot now; protection keeps only the camera's return blend.
function Handoff.skip(window: Window, now: number): Window
	if now >= window.Lock then return window end
	return { Kind = window.Kind, Start = window.Start, Lock = now, Ends = now + Handoff.Blend, Skipped = true }
end

-- Seconds of lock (shot + blend) left for a fighter, for Combat.cinematic.
function Handoff.remaining(window: Window, now: number): number
	return math.max(window.Ends - now, 0)
end

return table.freeze(Handoff)

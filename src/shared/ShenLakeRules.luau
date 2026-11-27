--!strict
-- Grandmaster Shen's lake trial (win-106): the one server-wide state of the Bellwood lake, plus the summoning's timeline.
--   Dormant    Shen is absent and the lake is ordinary water.
--   Summoning  the relic was taken. CrackAt seconds in, Shen's blow splits the cavern; from WindAt a howling wind gathers at the
--              lake's base (ShenLakeController). After SummonSeconds his presence stills the lake.
--   Stilled    the lake is pressed flat and hard enough to stand on (the arena's invisible floor collides); Shen waits in the storm
--              until someone steps into the arena.
--   Fight      the encounter runs on the stilled lake.
-- WorldService owns the state and mirrors it on Workspace attributes; clients only present it.
local Rules = {}

export type State = "Dormant" | "Summoning" | "Stilled" | "Fight"
export type Event = "Relic" | "Tick" | "Enter" | "Wipe" | "Felled" | "Abandoned"

Rules.CrackAt = 2.2
Rules.WindAt = 3.0
Rules.SummonSeconds = 9

-- Workspace attributes (server writes, clients read).
Rules.StateAttribute = "AsuraShenLake"
Rules.PhaseAttribute = "AsuraShenLakePhase" -- State and server timestamp replicate together.
Rules.RelicTag = "AsuraShenRelic"

-- `elapsed` = seconds in the current state.
function Rules.step(state: State, event: Event, elapsed: number): State
	if event == "Relic" then
		return if state == "Dormant" then "Summoning" else state
	elseif event == "Tick" then
		return if state == "Summoning" and elapsed >= Rules.SummonSeconds then "Stilled" else state
	elseif event == "Enter" then
		return if state == "Stilled" then "Fight" else state
	elseif event == "Wipe" then
		return if state == "Fight" then "Stilled" else state
	elseif event == "Felled" then
		return if state == "Fight" then "Dormant" else state
	elseif event == "Abandoned" then
		return if state == "Fight" then state else "Dormant"
	end
	return state
end

function Rules.walkable(state: string): boolean
	return state == "Stilled" or state == "Fight"
end

return Rules

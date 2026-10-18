--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Simulation/MatchmakingRules
-- Pure mathematical simulation module: ELO rating calculations, bracket expansion, and multi-cage allocation.

export type QueueEntry = {
	userId: number,
	elo: number,
	enteredAt: number,
	mode: string, -- "Ranked1v1" | "Casual1v1"
}

export type CageState = {
	id: number,
	name: string,
	status: string, -- "Available" | "Occupied" | "Decided"
	fighter1: number?,
	fighter2: number?,
	startedAt: number,
}

local MatchmakingRules = {}

local BASE_SEARCH_WINDOW = 50
local WINDOW_EXPANSION_PER_SEC = 5 -- Expands by 5 ELO per second (50 ELO per 10s)
local MAX_SEARCH_WINDOW = 400

function MatchmakingRules.CalculateExpectedScore(ratingA: number, ratingB: number): number
	return 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
end

function MatchmakingRules.CalculateEloChange(ratingA: number, ratingB: number, scoreA: number): (number, number)
	local expectedA = MatchmakingRules.CalculateExpectedScore(ratingA, ratingB)
	local expectedB = 1 - expectedA

	local kA = if ratingA < 1600 then 32 else 16
	local kB = if ratingB < 1600 then 32 else 16

	local scoreB = 1 - scoreA
	local deltaA = math.round(kA * (scoreA - expectedA))
	local deltaB = math.round(kB * (scoreB - expectedB))

	local newA = math.max(100, ratingA + deltaA)
	local newB = math.max(100, ratingB + deltaB)

	return newA, newB
end

function MatchmakingRules.GetDivision(elo: number): (string, {number})
	if elo >= 1600 then
		return "Black Belt (Undisputed Champion)", { 245, 195, 60 }
	elseif elo >= 1400 then
		return "Brown Belt (Master Contender)", { 180, 115, 65 }
	elseif elo >= 1200 then
		return "Purple Belt (Elite Fighter)", { 165, 75, 230 }
	elseif elo >= 1000 then
		return "Blue Belt (Championship Prospect)", { 50, 140, 240 }
	else
		return "White Belt (Debutant)", { 220, 225, 235 }
	end
end

function MatchmakingRules.FindMatch(queue: {QueueEntry}, now: number): (number?, number?)
	if #queue < 2 then
		return nil, nil
	end

	for i = 1, #queue - 1 do
		local a = queue[i]
		local waitA = math.max(0, now - a.enteredAt)
		local windowA = math.min(MAX_SEARCH_WINDOW, BASE_SEARCH_WINDOW + waitA * WINDOW_EXPANSION_PER_SEC)

		for j = i + 1, #queue do
			local b = queue[j]
			if a.mode == b.mode then
				local waitB = math.max(0, now - b.enteredAt)
				local windowB = math.min(MAX_SEARCH_WINDOW, BASE_SEARCH_WINDOW + waitB * WINDOW_EXPANSION_PER_SEC)
				local activeWindow = math.max(windowA, windowB)

				local eloDiff = math.abs(a.elo - b.elo)
				if eloDiff <= activeWindow then
					return i, j
				end
			end
		end
	end

	return nil, nil
end

function MatchmakingRules.CreateVenues(cageCount: number): { [number]: CageState }
	local cages: { [number]: CageState } = {}
	local cageNames = { "Main Championship Octagon", "Sparring Cage B", "Underground Mat C", "Training Pit D" }
	for id = 1, cageCount do
		cages[id] = {
			id = id,
			name = cageNames[id] or ("Octagon " .. id),
			status = "Available",
			fighter1 = nil,
			fighter2 = nil,
			startedAt = 0,
		}
	end
	return cages
end

function MatchmakingRules.AssignCage(cages: { [number]: CageState }, p1: number, p2: number, now: number): number?
	for id, cage in ipairs(cages) do
		if cage.status == "Available" then
			cage.status = "Occupied"
			cage.fighter1 = p1
			cage.fighter2 = p2
			cage.startedAt = now
			return id
		end
	end
	return nil
end

function MatchmakingRules.ReleaseCage(cages: { [number]: CageState }, cageId: number)
	local cage = cages[cageId]
	if cage then
		cage.status = "Available"
		cage.fighter1 = nil
		cage.fighter2 = nil
		cage.startedAt = 0
	end
end

return table.freeze(MatchmakingRules)

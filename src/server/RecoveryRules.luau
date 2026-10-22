--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/RecoveryRules
-- Death and respawn lifecycle rules shared by CharacterService, WorldService and SanctuaryService.
-- Player:LoadCharacter can position a new body after CharacterAdded handlers have placed it, which
-- dropped later-altar respawns at the engine default spawn where the Sanctuary fall safeguard then
-- returned them to the bonfire. A respawn now holds its target through a short settle window and
-- re-asserts it when the body is displaced; the safeguard only catches bodies that fell from the
-- Sanctuary. Pure: callers supply the ground probe and positions.
local RecoveryRules = {}

export type Probe = (origin: Vector3, direction: Vector3) -> Vector3?
export type Hold = { Target: CFrame, Until: number, Corrections: number }
export type Verdict = "Hold" | "Correct" | "Release"
export type FallState = { Aloft: boolean }
export type FallLimits = { Radius: number, FloorY: number }
export type Life = { Life: number, DeathLife: number }

-- A respawned body is checked for this long; walking or dashing never covers TOLERANCE studs in it.
RecoveryRules.SETTLE_SECONDS = 1.5
RecoveryRules.TOLERANCE = 48
RecoveryRules.MAX_CORRECTIONS = 8
local PROBE_UP = 2
local PROBE_DOWN = 40

-- Stands the root on the first floor under the spawn so no checkpoint drops or buries the body.
function RecoveryRules.standing(spawn: CFrame, rootHeight: number, probe: Probe?): CFrame
	if not probe then
		return spawn
	end
	local hit = probe(spawn.Position + Vector3.yAxis * PROBE_UP, Vector3.yAxis * -(PROBE_UP + PROBE_DOWN))
	if not hit then
		return spawn
	end
	return spawn + Vector3.yAxis * (hit.Y + rootHeight - spawn.Position.Y)
end

function RecoveryRules.begin(target: CFrame, now: number): Hold
	return { Target = target, Until = now + RecoveryRules.SETTLE_SECONDS, Corrections = 0 }
end

function RecoveryRules.check(hold: Hold, position: Vector3, now: number): Verdict
	if now >= hold.Until or hold.Corrections >= RecoveryRules.MAX_CORRECTIONS then
		return "Release"
	end
	if (position - hold.Target.Position).Magnitude > RecoveryRules.TOLERANCE then
		hold.Corrections += 1
		return "Correct"
	end
	return "Hold"
end

-- Sanctuary fall recovery: only a body last seen in the Sanctuary is caught when it drops below the
-- shrine. Ground regions, the unclaimed space between them and respawn placement are never caught.
function RecoveryRules.sanctuaryFall(state: FallState, region: string?, flat: number, y: number, settling: boolean, limits: FallLimits): boolean
	if settling then
		state.Aloft = false
		return false
	end
	if region == "Sanctuary" then
		state.Aloft = true
	elseif region ~= nil then
		state.Aloft = false
	end
	return state.Aloft and flat < limits.Radius and y < limits.FloorY
end

-- One death penalty per life: duplicate KO reports before the next respawn are ignored.
function RecoveryRules.claimDeath(life: Life): boolean
	if life.DeathLife == life.Life then
		return false
	end
	life.DeathLife = life.Life
	return true
end

function RecoveryRules.spawned(life: Life)
	life.Life += 1
end

return RecoveryRules

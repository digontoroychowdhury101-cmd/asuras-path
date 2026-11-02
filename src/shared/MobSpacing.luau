--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/MobSpacing
-- Footwork for ordinary foes (bosses keep their own tuning). Studio trace, 2026-11-01: monks patrolled and
-- closed at the full 23.5 studs/s (35 sprinting), engaged on a point 0.6 x reach (2.7 studs) from the
-- player's root - body contact for two R15s - and kept walking into it through every windup and combo
-- follow-up, so a strike read as being shoved. Foes now walk while patrolling and in footsies, stand off
-- at three quarters of their reach and step back out of a crowd. Pure, so the specs can run it.
local Spacing = {}

Spacing.ContactRadius = 1.2 -- studs from root to body surface at scale 1 (ContactCues.BodyRadius)
Spacing.MinGap = 0.9 -- clear air kept between two bodies at the standoff point
Spacing.CrowdGap = 0.35 -- closer than this and the foe steps back before it swings
Spacing.AllyGap = 3.4 -- two foes closing on one target keep at least this far apart
-- Attack turns (Studio group trace, 2026-11-02): a Cloister monk and swordsman swung together, and the
-- swordsman's 30-damage blows landed while a Lv1 player was punishing the monk, killing them in ~11 s.
-- Ordinary foes sharing a target now take turns: one opens an attack, the rest circle in reach until
-- its swing (or the stagger the player punished it into) has been over this long. No turn is held past
-- TurnMax, so a player who stunlocks one foe still has the other to answer.
Spacing.TurnGap = 0.8
Spacing.TurnMax = 3.0

-- Fraction of the weapon-scaled run speed per AI mode. Engage only sprints from far away.
local PACE = table.freeze({ Idle = 0.38, Patrol = 0.38, Alert = 0.42, Return = 0.5, Combat = 0.55, Engage = 0.7 })

-- Where a foe stops in front of its target: inside its reach so its swings connect, never inside contact.
function Spacing.standoff(reach: number, scale: number, targetScale: number?): number
	local contact = Spacing.ContactRadius * (scale + (targetScale or 1)) + Spacing.MinGap
	return math.max(reach * 0.75, contact)
end

-- True when the foe stands so close it would swing through the target's body.
function Spacing.crowded(distance: number, scale: number, targetScale: number?): boolean
	return distance < Spacing.ContactRadius * (scale + (targetScale or 1)) + Spacing.CrowdGap
end

-- May this foe open a new attack on a target whose turn `holder` took at `since` and holds until `heldUntil`?
function Spacing.mayOpen(holder: number?, self: number, since: number, heldUntil: number, now: number): boolean
	return holder == nil or holder == self or now >= heldUntil or now >= since + Spacing.TurnMax
end

-- The walk-speed multiplier for a mode; Engage runs at full speed only while far beyond reach.
function Spacing.pace(mode: string, distance: number, reach: number): number
	if mode == "Engage" and distance > reach * 3 then
		return 1
	end
	return PACE[mode] or 1
end

return table.freeze(Spacing)

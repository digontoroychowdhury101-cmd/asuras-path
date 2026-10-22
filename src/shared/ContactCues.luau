--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/ContactCues
-- How attack contact reads to the local player, from authoritative combat events only. Beside
-- the existing block / parry / hit / deathblow calls it names the three outcomes that used to be
-- silent: a whiff (the attack window closed touching no one; the server reports how many studs
-- short of the nearest foe it fell), an evade (the strike met dodge i-frames) and a feint (an
-- attack abandoned during its startup, which pressing guard does on purpose). Hitboxes are not
-- changed: this only describes what the 60 Hz server already decided.
local Cues = {}

Cues.NoticeRange = 8 -- a whiff further than this from every foe was swung at nothing; stay quiet
Cues.BodyRadius = 1.2 -- flat distance from a fighter's root to the surface a blade must reach
Cues.Short = 0.5 -- below this the swing reached the foe's position but missed it (arc / facing)

export type Tone = "Muted" | "Ivory" | "Gold" | "Crimson"
-- Text: what to say; Over: whose head the popup floats over ("Source" | "Target" | nil for a centre
-- callout); Arc: draw the attack's real reach around the attacker.
export type Cue = { Text: string, Tone: Tone, Over: ("Source" | "Target")?, Arc: boolean }

-- Studs a strike of `reach` fell short of a body standing at `to` (0 when within reach).
function Cues.gap(from: Vector3, to: Vector3, reach: number): number
	local flat = math.sqrt((to.X - from.X) ^ 2 + (to.Z - from.Z) ^ 2)
	return math.max(0, flat - Cues.BodyRadius - reach)
end

-- `own` is the local fighter id; `near` says the event's source is a nearby fighter (opponent feints).
function Cues.describe(kind: string, source: number, target: number, value: number, own: number, near: boolean): Cue?
	if kind == "Whiff" then
		if source ~= own or target == 0 then return nil end
		if value >= Cues.Short then
			return { Text = string.format("OUT OF REACH  +%.1f", value), Tone = "Muted", Over = "Target", Arc = true }
		end
		return { Text = "MISSED", Tone = "Muted", Over = "Target", Arc = true }
	elseif kind == "Evade" then -- Source dodged Target's strike
		if source == own then return { Text = "EVADED", Tone = "Ivory", Over = nil, Arc = false } end
		if target == own then return { Text = "DODGED", Tone = "Muted", Over = "Source", Arc = false } end
	elseif kind == "Feint" then
		if source == own then return { Text = "FEINT · attack cancelled", Tone = "Ivory", Over = nil, Arc = false } end
		if near then return { Text = "FEINT", Tone = "Muted", Over = "Source", Arc = false } end
	end
	return nil
end

return table.freeze(Cues)

--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/Wind
-- The one wind source (ticket 11, ruling R3). Foliage (FoliageWind writes GlobalWind from this), precipitation,
-- cloth and ambience all read `Wind.sample`; nothing else holds a wind direction or speed.
-- Overworld prevailing wind is FROM the east-south-east (bearing 112.5 deg clockwise from north = -Z), so it
-- blows toward the west-north-west: it carries sea moisture over the Bellwood and the divide, leaving Amberfall
-- and the Saltreach in the rain shadow. The lobby keeps Config.Workspace.GlobalWind, passed in unchanged.
local Wind = {}

Wind.Prevailing = table.freeze({ Name = "ESE", FromDegrees = 112.5, Speed = 9 })
local from = math.rad(Wind.Prevailing.FromDegrees)
-- North is -Z and east is +X; the vector points where the air goes (opposite of where it comes from).
Wind.Toward = table.freeze({ X = -math.sin(from), Z = math.cos(from) })

export type Sample = { X: number, Y: number, Z: number, Speed: number }

-- `gain` is the weather state's multiplier (EnvironmentProfiles.compose returns it as WindGain).
function Wind.sample(overworld: boolean, lobby: { number }, gain: number?): Sample
	if not overworld then
		return { X = lobby[1], Y = lobby[2], Z = lobby[3], Speed = math.sqrt(lobby[1] ^ 2 + lobby[2] ^ 2 + lobby[3] ^ 2) }
	end
	local speed = Wind.Prevailing.Speed * (gain or 1)
	return { X = Wind.Toward.X * speed, Y = 0, Z = Wind.Toward.Z * speed, Speed = speed }
end

-- Particle acceleration for falling precipitation: gravity plus a share of the wind.
function Wind.drift(sample: Sample, fall: number, share: number): (number, number, number)
	return sample.X * share, -fall, sample.Z * share
end

-- Ambient wind loop volume for the same speed (the old shrine/other split was 0.12 / 0.22).
function Wind.ambience(sample: Sample): number
	return math.clamp(0.1 + sample.Speed * 0.012, 0.1, 0.35)
end

return table.freeze(Wind)

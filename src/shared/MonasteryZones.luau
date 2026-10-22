--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/MonasteryZones
-- The walked areas of the Desecrated Monastery as rectangles joined by doorways (batch 15). Two
-- uses: wayfinding follows the doorways (gatehouse, courtyard south gap, bridgeheads, cloister
-- gateway, the west postern) instead of a straight line through walls (#28), and each Monastery
-- spawn fights only inside its zone, so a monk never chases across a wall, onto the safe landing
-- or over the bridge (#27). Pure data and maths: shared by the server AI and the client marker.
local Zones = {}

export type Zone = { Id: string, Name: string, X0: number, X1: number, Z0: number, Z1: number }
export type Door = { A: string, B: string, X: number, Z: number, Name: string }

-- Z0 is the north (higher z) edge, Z1 the south edge.
Zones.List = table.freeze({
	{ Id = "Landing", Name = "the gate landing", X0 = -26, X1 = 26, Z0 = -690, Z1 = -752 },
	{ Id = "Courtyard", Name = "the courtyard", X0 = -82, X1 = 82, Z0 = -752, Z1 = -858 },
	{ Id = "Halls", Name = "the prayer halls", X0 = -102, X1 = 118, Z0 = -858, Z1 = -936 },
	{ Id = "Bridge", Name = "the ravine bridge", X0 = -12, X1 = 12, Z0 = -930, Z1 = -990 },
	{ Id = "Road", Name = "the south road", X0 = -14, X1 = 14, Z0 = -988, Z1 = -1124 },
	{ Id = "Cloister", Name = "the cloister", X0 = 14, X1 = 128, Z0 = -990, Z1 = -1114 },
	{ Id = "Graves", Name = "the grave field", X0 = -132, X1 = -14, Z0 = -990, Z1 = -1112 },
	{ Id = "WestReach", Name = "the waterfall path", X0 = -180, X1 = -82, Z0 = -752, Z1 = -936 },
	{ Id = "EastPass", Name = "the ridge pass", X0 = 82, X1 = 404, Z0 = -786, Z1 = -1034 },
} :: { Zone })

Zones.Doors = table.freeze({
	{ A = "Landing", B = "Courtyard", X = 0, Z = -752, Name = "Gatehouse" },
	{ A = "Courtyard", B = "Halls", X = 0, Z = -858, Name = "Processional path" },
	{ A = "Halls", B = "Bridge", X = 0, Z = -932, Name = "Bridge" },
	{ A = "Bridge", B = "Road", X = 0, Z = -989, Name = "Far bridgehead" },
	{ A = "Road", B = "Cloister", X = 14, Z = -1012, Name = "Cloister gateway" },
	{ A = "Road", B = "Graves", X = -14, Z = -1040, Name = "Grave field" },
	{ A = "Courtyard", B = "EastPass", X = 82, Z = -811, Name = "Ridge pass" },
	{ A = "Courtyard", B = "WestReach", X = -82, Z = -830, Name = "West postern" },
	{ A = "WestReach", B = "Halls", X = -102, Z = -880, Name = "Hall breach" },
} :: { Door })

-- Which zone each Monastery spawn may fight in (the Sparring Phantom keeps its own short leash).
Zones.Spawns = table.freeze({
	DM_Monk_Courtyard_A = "Courtyard", DM_Monk_Courtyard_B = "Courtyard", DM_Monk_Courtyard_C = "Courtyard",
	DM_Monk_Hall_A = "Halls", DM_Monk_Hall_B = "Halls", DM_Swordsman_Bridge = "Bridge",
	DM_Monk_Cloister = "Cloister", DM_Swordsman_Cloister = "Cloister",
})
Zones.Grace = 6 -- studs a foe may follow past its zone edge (doorway fights stay fair)

-- Authored footpaths (x, z polylines) that terrain, scatter and dressing keep clear: the secret
-- waterfall path (west postern -> alcove -> west hall breach) and the walk to the mausoleum.
Zones.WestPath = table.freeze({ { -84, -830 }, { -100, -828 }, { -116, -831 }, { -128, -835 }, { -122, -850 }, { -114, -866 }, { -106, -878 }, { -100, -880 } })
Zones.GravePath = table.freeze({ { -14, -1046 }, { -30, -1066 }, { -74, -1068 }, { -104, -1068 }, { -110, -1067 } })
Zones.Alcove = table.freeze({ X = -140, Z = -840 })

function Zones.distanceToPath(path: { { number } }, x: number, z: number): number
	local best = math.huge
	for k = 1, #path - 1 do
		local a, b = path[k], path[k + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local t = math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / (dx * dx + dz * dz), 0, 1)
		best = math.min(best, math.sqrt((x - a[1] - dx * t) ^ 2 + (z - a[2] - dz * t) ^ 2))
	end
	return best
end

function Zones.get(id: string): Zone?
	for _, zone in Zones.List do
		if zone.Id == id then return zone end
	end
	return nil
end

function Zones.contains(zone: Zone, x: number, z: number, margin: number?): boolean
	local m = margin or 0
	return x >= zone.X0 - m and x <= zone.X1 + m and z <= zone.Z0 + m and z >= zone.Z1 - m
end

-- The zone containing a point (first match; the bridge wins over the halls' south strip).
function Zones.at(x: number, z: number): Zone?
	local best: Zone? = nil
	for _, zone in Zones.List do
		if Zones.contains(zone, x, z) and (best == nil or (zone.X1 - zone.X0) * (zone.Z0 - zone.Z1) < (best.X1 - best.X0) * (best.Z0 - best.Z1)) then
			best = zone
		end
	end
	return best
end

-- Doorways from zone `from` to zone `to` along the fewest crossings (breadth first).
function Zones.path(from: string, to: string): { Door }
	if from == to then return {} end
	local previous: { [string]: Door } = {}
	local seen, queue = { [from] = true }, { from }
	while #queue > 0 do
		local here = table.remove(queue, 1) :: string
		for _, door in Zones.Doors do
			local other = if door.A == here then door.B elseif door.B == here then door.A else nil
			if other and not seen[other] then
				seen[other], previous[other] = true, door
				table.insert(queue, other)
			end
		end
	end
	local doors: { Door } = {}
	local cursor = to
	while cursor ~= from do
		local door = previous[cursor]
		if not door then return {} end
		table.insert(doors, 1, door)
		cursor = if door.A == cursor then door.B else door.A
	end
	return doors
end

return Zones

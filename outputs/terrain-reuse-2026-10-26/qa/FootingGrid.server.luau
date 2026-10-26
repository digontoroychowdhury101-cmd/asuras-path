-- Server probe on a 2-stud grid over each campaign region: the walkable collider surface (top part,
-- veils excluded) against the terrain surface at the same spot. Terrain standing above the collider
-- surface is a lump the body walks on instead of the authored floor.
local World = require(game.ReplicatedStorage.AsurasPath.Shared.WorldDefinitions)
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local out = {}
for _, map in workspace:GetChildren() do
	local id = map:GetAttribute("AsuraRegion")
	if not (map.Name:match("^Map_") and id and map:FindFirstChild("Structure")) then continue end
	local floors = {}
	for _, p in map.Structure:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "MistVeil" and p.CanCollide then table.insert(floors, p) end
	end
	local partsOnly = RaycastParams.new()
	partsOnly.FilterType = Enum.RaycastFilterType.Include
	partsOnly.FilterDescendantsInstances = floors
	local b = World.Regions[id].Bounds
	local c, s = b.Center, b.Size
	local topY = c.Y + s.Y / 2
	local n, lumps, bad, worst, buckets = 0, 0, 0, { 0 }, {}
	local nat, high, float, worstFloat, edgeFloat = 0, 0, 0, { 0 }, 0
	for x = c.X - s.X / 2 + 1, c.X + s.X / 2, 2 do
		for z = c.Z - s.Z / 2 + 1, c.Z + s.Z / 2, 2 do
			local ph = workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -s.Y - 60, 0), partsOnly)
			if not ph then continue end
			n += 1
			-- Terrain ray starts 12 studs above the floor: anything it meets first is above the floor.
			local proxy = ph.Instance:GetAttribute("AsuraTerrainProxy")
			local th = workspace:Raycast(Vector3.new(x, ph.Position.Y + 12, z), Vector3.new(0, if proxy then -18 else -12.5, 0), terrainOnly)
			if proxy then
				nat += 1
				local d = if th then th.Position.Y - ph.Position.Y else -6
				if d > 1 and d < 11.5 then high += 1 end
				local lp = ph.Instance.CFrame:PointToObjectSpace(ph.Position)
				local edge = math.min(ph.Instance.Size.X / 2 - math.abs(lp.X), ph.Instance.Size.Z / 2 - math.abs(lp.Z))
				if d < -1 and edge < 3 then edgeFloat += 1 end
				if d < -1 and edge >= 3 then
					float += 1
					if -d > worstFloat[1] then worstFloat = { -d, string.format("(%.0f,%.1f,%.0f) on %s", x, ph.Position.Y, z, ph.Instance.Name) } end
				end
			elseif th then
				local d = th.Position.Y - ph.Position.Y
				if d > 0.3 then
					lumps += 1
					if d > 2 then bad += 1 end
					local key = ph.Instance.Name
					local e = buckets[key] or { 0, 0, x, z }
					e[1] += 1; e[2] = math.max(e[2], d)
					buckets[key] = e
					if d > worst[1] then worst = { d, string.format("(%.0f,%.1f,%.0f) on %s", x, ph.Position.Y, z, ph.Instance.Name) } end
				end
			end
		end
	end
	local list = {}
	for k, e in buckets do table.insert(list, { k, e }) end
	table.sort(list, function(a, b2) return a[2][1] > b2[2][1] end)
	local top = {}
	for i = 1, math.min(6, #list) do
		local e = list[i][2]
		table.insert(top, string.format("%s x%d max %.1f near (%.0f,%.0f)", list[i][1], e[1], e[2], e[3], e[4]))
	end
	table.insert(out, string.format("%s: built cells %d, terrain lumps >0.3: %d (>2: %d), worst %.2f %s\n   natural cells %d: bumps >1 above lid %d, interior feet floating >1 %d (worst %.1f %s), edge-strip floating %d\n   %s",
		id, n - nat, lumps, bad, worst[1], tostring(worst[2]), nat, high, float, worstFloat[1], tostring(worstFloat[2]), edgeFloat, table.concat(top, "\n   ")))
end
return table.concat(out, "\n")

--!strict
-- ModuleScript: ReplicatedStorage/AsurasPath/Shared/ArenaLightPlan
-- Where boss-arena lights go. The four corner braziers are the arena's character light but
-- leave the centre of every arena (where the duel actually happens) outside their reach, so a
-- grid of shadowless overhead fill lanterns guarantees neutral light on every floor point.
-- Shared and pure so the coverage can be checked without the engine.
local Plan = {}

Plan.FloorY = 0 -- arena floors sit at Y 0 (spawns at Y 3)
Plan.Brazier = table.freeze({ Inset = 0.34, Height = 3, Range = 55, Brightness = 3 })
Plan.Fill = table.freeze({ Height = 18, Range = 60, Brightness = 0.9, MaxSpacing = 80 })
-- A floor point counts as lit when it lies inside this share of a light's range; Roblox point
-- light falloff makes the last stretch of the range too dim to separate actors from the floor.
Plan.Reach = 0.85

type Arena = { Center: { X: number, Y: number, Z: number }, Size: { X: number, Y: number, Z: number } }

function Plan.braziers(arena: Arena): { Vector3 }
	local c, s, inset = arena.Center, arena.Size, Plan.Brazier.Inset
	local result: { Vector3 } = {}
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		table.insert(result, Vector3.new(c.X + corner[1] * s.X * inset, Plan.FloorY + 0.35, c.Z + corner[2] * s.Z * inset))
	end
	return result
end

local function axis(center: number, size: number): { number }
	local count = math.max(1, math.ceil(size / Plan.Fill.MaxSpacing))
	local result: { number } = {}
	for i = 1, count do
		table.insert(result, center + (i - (count + 1) / 2) * size / count)
	end
	return result
end

function Plan.fills(arena: Arena): { Vector3 }
	local result: { Vector3 } = {}
	for _, x in axis(arena.Center.X, arena.Size.X) do
		for _, z in axis(arena.Center.Z, arena.Size.Z) do
			table.insert(result, Vector3.new(x, Plan.FloorY + Plan.Fill.Height, z))
		end
	end
	return result
end

-- Worst distance from any sampled floor point to its nearest light, as a share of that light's
-- range (<= Plan.Reach means fully lit). `step` is the sampling pitch in studs.
function Plan.worstReach(arena: Arena, lights: { Vector3 }, range: number, step: number): (number, Vector3?)
	local c, s = arena.Center, arena.Size
	local worst, at = 0, nil :: Vector3?
	local x = c.X - s.X / 2
	while x <= c.X + s.X / 2 + 1e-6 do
		local z = c.Z - s.Z / 2
		while z <= c.Z + s.Z / 2 + 1e-6 do
			local point = Vector3.new(x, Plan.FloorY + 3, z) -- chest height of a standing fighter
			local nearest = math.huge
			for _, light in lights do
				nearest = math.min(nearest, (light - point).Magnitude)
			end
			if nearest / range > worst then
				worst, at = nearest / range, point
			end
			z += step
		end
		x += step
	end
	return worst, at
end

return table.freeze(Plan)

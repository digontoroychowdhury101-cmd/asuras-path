--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryTerrace
-- Dressing for the Veiled Ascetic's terrace (SanctuaryColossus owns the slab, the statue and the tree):
-- a paved processional path from the gate to her seat between paired carved stelae and lanterns, a
-- few distinctive ruins - a fallen pailou, banded pillars, broken stelae - with mossy outcrops among the
-- roots, lanterns along the front rim, and layered rock spurs under the edge in place of plain boxes.
-- Dressing stays near the path and landing and away from the pilgrim daises, so the open terrace and
-- every view of her remain clear. `centre` is the terrace centre on its top, +Z toward the plaza.
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Props = require(script.Parent:WaitForChild("SanctuaryProps") :: ModuleScript)
local Leaves = require(script.Parent:WaitForChild("SanctuaryLeaves") :: ModuleScript)

local Terrace = {}

local M = Enum.Material
local function block(group: Instance, size: Vector3, cf: CFrame)
	Kit.part(group, "RuinCollision", size, cf * CFrame.new(0, size.Y / 2, 0), Color3.new(), M.SmoothPlastic,
		{ Collide = true, Query = false, Transparency = 1, Shadow = false })
end

-- x, z, yaw (degrees), scale, tilt (degrees)
local PILLARS = { { -40, 205, 10, 1.3, 0 }, { -48, 196, 40, 1.0, 9 }, { 46, 212, -20, 1.5, 0 }, { 104, 176, 0, 1.2, -6 },
	{ -108, 170, 25, 1.4, 0 }, { 150, 60, 0, 1.8, 0 }, { -155, 40, 15, 1.6, 7 }, { 60, -120, 0, 2.1, 0 }, { -84, -150, 30, 2.0, 0 } }
local GATES = { { -62, 150, 20, 1.15 }, { 74, 95, -35, 1.0 } }
local OUTCROPS = { { -56, 160, 1.2 }, { 80, 106, 1.0 }, { -30, 190, 0.9 }, { 112, 184, 1.1 }, { -150, 52, 1.8 }, { 156, 72, 2.0 }, { 20, 236, 0.7 } }

local function ruins(group: Instance, centre: CFrame)
	for _, p in PILLARS do
		local cf = centre * CFrame.new(p[1], -0.4, p[2]) * CFrame.Angles(0, math.rad(p[3]), math.rad(p[5]))
		if not Kit.place(group, "Ruin_Pillar", cf, p[4]) then
			Kit.slab(group, "RuinPillar", Vector3.new(2.2, 10, 2.2) * p[4], cf * CFrame.new(0, 5 * p[4], 0), "Stone")
		end
		block(group, Vector3.new(2.8, 11, 2.8) * p[4], cf)
	end
	for _, g in GATES do
		local cf = centre * CFrame.new(g[1], -0.3, g[2]) * CFrame.Angles(0, math.rad(g[3]), 0)
		Kit.place(group, "Ruin_Gate", cf, g[4])
		for _, x in { -4.5, 4.5 } do
			block(group, Vector3.new(2.4, 10, 2.4) * g[4], cf * CFrame.new(x * g[4], 0, 0))
		end
	end
	for _, o in OUTCROPS do
		local cf = centre * CFrame.new(o[1], -0.6, o[2]) * CFrame.Angles(0, o[1] * 0.07, 0)
		Kit.place(group, "Rock_Outcrop", cf, o[3])
		block(group, Vector3.new(8, 3.6, 5) * o[3], cf)
	end
end

local function processional(group: Instance, centre: CFrame, radius: number, seat: number)
	local near, far = radius - 3, seat + 22
	local length = near - far
	local mid = centre * CFrame.new(0, 0, (near + far) / 2)
	Kit.slab(group, "ProcessionalWay", Vector3.new(16, 0.4, length), mid * CFrame.new(0, -0.15, 0), "PavingPath")
	for side = -1, 1, 2 do
		Kit.slab(group, "WayInlay", Vector3.new(0.14, 0.05, length - 2), mid * CFrame.new(side * 7.6, 0.06, 0), "Bronze", Kit.decor())
		Kit.slab(group, "ProcessionalEdging", Vector3.new(0.55, 0.2, length), mid * CFrame.new(side * 8.28, -0.015, 0), "StoneDark", Kit.decor())
		Kit.slab(group, "WayOuterThread", Vector3.new(0.06, 0.025, length - 2), mid * CFrame.new(side * 7.25, 0.06, 0), "Bronze", Kit.decor())
		for _, z in { near - 8, near - 30, near - 52 } do
			Props.lantern(group, centre * CFrame.new(side * 10.5, 0.05, z))
		end
		local face = CFrame.Angles(0, math.rad(side * 90), 0) -- front panels turn to the path
		Props.stele(group, centre * CFrame.new(side * 17, 0, near - 19) * face, if side < 0 then "SHE KEEPS\nTHE GATE" else "THE VEILED\nASCETIC")
		Props.stele(group, centre * CFrame.new(side * 17, 0, near - 41) * face, "", side > 0)
	end
	Props.stele(group, centre * CFrame.new(-28, 0, near - 10) * CFrame.Angles(0, math.rad(160), math.rad(4)), "", true)
end

-- Two quiet gardens make a human-scale forecourt at the gate. They remain well outside the central
-- 16-stud procession and the pilgrim daises; the imported tree and roots keep all their space.
local function forecourt(group: Instance, centre: CFrame, radius: number)
	local near = radius - 3
	for side = -1, 1, 2 do
		local wing = centre * CFrame.new(side * 17.3, 0, near - 47)
		Kit.slab(group, "ForecourtWing", Vector3.new(18.6, 0.16, 11), wing * CFrame.new(0, -0.03, 0), "PavingPath", Kit.decor())
		Kit.slab(group, "ForecourtCrossInlay", Vector3.new(18.2, 0.025, 0.08), wing * CFrame.new(0, 0.065, 4.8), "Bronze", Kit.decor())
		local garden = centre * CFrame.new(side * 35, 0, near - 28)
		Kit.part(group, "GardenEarth", Vector3.new(17, 0.1, 26), garden, Color3.fromRGB(52, 62, 49), M.Ground, Kit.decor())
		for _, x in { -8.9, 8.9 } do
			Kit.slab(group, "GardenKerb", Vector3.new(0.65, 0.38, 27.2), garden * CFrame.new(x, 0.08, 0), "StoneDark", Kit.decor())
		end
		for _, z in { -13.3, 13.3 } do
			Kit.slab(group, "GardenKerb", Vector3.new(18.4, 0.38, 0.65), garden * CFrame.new(0, 0.08, z), "StoneDark", Kit.decor())
		end
		Kit.place(group, "Rock_Outcrop", garden * CFrame.new(-side * 1.6, -0.3, 1.4) * CFrame.Angles(0, side * 0.8, 0), 1.2)
		Props.tree(group, garden * CFrame.new(side * 3, 0, -4) * CFrame.Angles(0, side * 1.4, 0), 0.65, true)
		Props.shrub(group, garden * CFrame.new(-side * 4, 0, 7), 0.9)
		Leaves.Scatter(group, garden * CFrame.new(0, 0.1, 0), Vector2.new(8, 12), 36, 571 + side)
		Props.bench(group, centre * CFrame.new(side * 22, 0.05, near - 11) * CFrame.Angles(0, math.rad(side * 90), 0))
	end
end

-- Lanterns along the front rim, either side of the landing.
local function rim(group: Instance, centre: CFrame, radius: number)
	for _, deg in { -58, -46, -34, -22, 22, 34, 46, 58 } do
		local a = math.rad(deg)
		Props.lantern(group, centre * CFrame.new(math.sin(a) * (radius - 9), 0, math.cos(a) * (radius - 9)))
	end
end

-- Layered karst spurs and shelves under the edge (top at the kerb, hanging into the clouds).
local function underside(group: Instance, centre: CFrame, radius: number)
	local rng = Random.new(4471)
	for k = 0, 21 do
		local a = math.rad(k * (360 / 22) + 6)
		local edge = centre * CFrame.Angles(0, a, 0) * CFrame.new(0, -7, -(radius - 10)) * CFrame.Angles(math.rad(-6), 0, 0)
		local s = rng:NextNumber(0.9, 1.3)
		if not Kit.place(group, "Cliff_Shelf", edge * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Vector3.new(s, 1.7 * s, 1.5)) then
			Kit.slab(group, "TerraceSpur", Vector3.new(20, 80, 15), edge * CFrame.new(0, -40, 0), "Rock")
		end
		if k % 2 == 0 then
			Kit.place(group, "Cliff_Spur", centre * CFrame.Angles(0, a + 0.1, 0) * CFrame.new(0, -24, -(radius - 30)), Vector3.new(2.2, 1.9, 2.2) * s)
		end
	end
end

-- A few crimson maples among the outer ruins, well off the path, the statue's views and the daises.
local TREES = { { -78, 150, 1.0 }, { -146, 60, 1.3 }, { 120, 196, 0.9 }, { 150, 40, 1.2 } }

function Terrace.Dress(group: Instance, centre: CFrame, radius: number, seat: number)
	processional(group, centre, radius, seat)
	forecourt(group, centre, radius)
	for i, t in TREES do
		Props.tree(group, centre * CFrame.new(t[1], -0.2, t[2]) * CFrame.Angles(0, i * 1.3, 0), t[3], i % 2 == 0)
		Props.shrub(group, centre * CFrame.new(t[1] + 5, -0.2, t[2] - 3), 1.3)
	end
	ruins(group, centre)
	rim(group, centre, radius)
	underside(group, centre, radius)
end

return table.freeze(Terrace)

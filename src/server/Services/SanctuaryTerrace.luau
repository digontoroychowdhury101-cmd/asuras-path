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
local Frame = require(script.Parent:WaitForChild("SanctuaryFrame") :: ModuleScript)

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
	Kit.slab(group, "ProcessionalWay", Vector3.new(32, 0.4, length), mid * CFrame.new(0, -0.15, 0), "PavingPath")
	for side = -1, 1, 2 do
		Kit.slab(group, "WayInlay", Vector3.new(0.14, 0.05, length - 2), mid * CFrame.new(side * 15.6, 0.06, 0), "Bronze", Kit.decor())
		Kit.slab(group, "ProcessionalEdging", Vector3.new(0.55, 0.2, length), mid * CFrame.new(side * 16.28, -0.015, 0), "StoneDark", Kit.decor())
		Kit.slab(group, "WayOuterThread", Vector3.new(0.06, 0.025, length - 2), mid * CFrame.new(side * 15.25, 0.06, 0), "Bronze", Kit.decor())
		for _, z in { near - 8, near - 30, near - 52 } do
			Props.lantern(group, centre * CFrame.new(side * 20.5, 0.05, z))
		end
		local face = CFrame.Angles(0, math.rad(side * 90), 0) -- front panels turn to the path
		Props.stele(group, centre * CFrame.new(side * 27, 0, near - 19) * face, if side < 0 then "SHE KEEPS\nTHE GATE" else "THE VEILED\nASCETIC")
		Props.stele(group, centre * CFrame.new(side * 27, 0, near - 41) * face, "", side > 0)
	end
	Props.stele(group, centre * CFrame.new(-28, 0, near - 10) * CFrame.Angles(0, math.rad(160), math.rad(4)), "", true)
end

-- Two quiet gardens make a human-scale forecourt at the gate. They remain well outside the central
-- 32-stud procession and the pilgrim daises; the imported tree and roots keep all their space.
local function forecourt(group: Instance, centre: CFrame, radius: number)
	local near = radius - 3
	for side = -1, 1, 2 do
		local wing = centre * CFrame.new(side * 30, 0, near - 20)
		Kit.slab(group, "ForecourtWing", Vector3.new(26, 0.16, 11), wing * CFrame.new(0, -0.03, 0), "PavingPath", Kit.decor())
		Kit.slab(group, "ForecourtCrossInlay", Vector3.new(25.6, 0.025, 0.08), wing * CFrame.new(0, 0.065, 4.8), "Bronze", Kit.decor())
		local garden = centre * CFrame.new(side * 32, 0, near - 55)
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

-- Raised prayer courts, approached by broad five-step flights, give the foreground a clear second
-- level. Their clean roof silhouettes and low carved fronts frame the much taller goddess. Crags
-- and crimson planting occupy the outer half; the centre stays open for processional circulation.
local function landscapeGardens(group: Instance, centre: CFrame, seat: number)
	local gardens = Kit.folder("TerraceCragGardens", group)
	for side = -1, 1, 2 do
		local garden = Kit.folder(if side < 0 then "WestCragGarden" else "EastCragGarden", gardens)
		local at = centre * CFrame.new(side * 68, 0, 208)
		local yaw = if side < 0 then -0.24 else 0.38
		local top = 2.55
		Kit.slab(garden, "PrayerCourtFoundation", Vector3.new(48, 2.4, 44), at * CFrame.new(0, 1.2, 0), "StoneDark")
		Kit.slab(garden, "PrayerCourtPaving", Vector3.new(48.3, 0.3, 44.3), at * CFrame.new(0, 2.4, 0), "PavingPath")
		Kit.slab(garden, "PrayerCourtShadowCourse", Vector3.new(48.8, 0.3, 44.8), at * CFrame.new(0, 2.1, 0), "StoneDark", Kit.decor())
		for step = 1, 5 do
			local height = top * step / 5
			local cf = centre * CFrame.new(side * (33 + step * 2), height * 0.5, 223)
			Kit.slab(garden, "PrayerCourtStep", Vector3.new(2.05, height, 12), cf, "Stone")
			Kit.slab(garden, "PrayerCourtStepNosing", Vector3.new(0.18, 0.13, 12.2), cf * CFrame.new(-side * 0.94, height * 0.5, 0), "StoneDark", Kit.decor())
		end
		local shrine = at * CFrame.new(-side * 9, top, -2)
		Frame.pavilion(garden, shrine, 12, 10, 10.2, { Square = true, Rise = 0.86, Xs = { -6, 6 } })
		Props.stele(garden, shrine * CFrame.new(0, 0, -1.7), "", side > 0)
		Kit.part(garden, "CragGardenEarth", Vector3.new(21, 0.12, 33), at * CFrame.new(side * 12, top + 0.03, -2),
			Color3.fromRGB(47, 57, 46), M.Ground, Kit.decor())
		local ledgeTop = top + (if side < 0 then 4.8 else 5.9)
		Kit.place(garden, "Cliff_Ledge", at * CFrame.new(side * 13, ledgeTop, -6) * CFrame.Angles(0, yaw, 0), Vector3.new(0.43, 0.23, 0.51))
		Kit.place(garden, "Rock_Outcrop", at * CFrame.new(side * 14, top - 0.25, -5) * CFrame.Angles(0, yaw + 0.35, 0), Vector3.new(2.2, 2.4, 2.1))
		Kit.place(garden, "Rock_Outcrop", at * CFrame.new(side * 20, top - 0.2, 9) * CFrame.Angles(0, yaw - 0.7, 0), Vector3.new(1.5, 1.7, 1.5))
		for x = -21, 21, 6 do
			Kit.place(garden, "Rail_Bay", at * CFrame.new(x, top, 22), Vector3.new(6 / 5.1, 0.72, 1))
		end
		for z = -19, 17, 6 do
			Kit.place(garden, "Rail_Bay", at * CFrame.new(side * 24, top, z) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(6 / 5.1, 0.72, 1))
		end
		for _, x in { -18, 18 } do Props.lantern(garden, at * CFrame.new(x, top, 20.5)) end
		Props.tree(garden, at * CFrame.new(side * 13, ledgeTop - 0.12, -6) * CFrame.Angles(0, yaw + side * 0.8, 0),
			if side < 0 then 1.18 else 1.12, side > 0)
		for i, p in { { side * 20, top + 1.5, 9 }, { side * 7, top + 0.2, 16 }, { side * 19, ledgeTop - 0.2, -9 } } do
			Props.shrub(garden, at * CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(0, i * 1.7 + side, 0), 1.4 + i * 0.12)
		end
		Leaves.Scatter(garden, at * CFrame.new(0, top + 0.06, 13), Vector2.new(20, 6), 35, 7621 + side)
	end
	-- A single cool stone bench looks diagonally toward her seat, outside the procession and beds.
	local foot = (centre * CFrame.new(-43, 0.12, 231)).Position
	local target = (centre * CFrame.new(0, 0.12, seat)).Position
	local bench = CFrame.lookAt(foot, target)
	Kit.slab(gardens, "PilgrimStoneSeat", Vector3.new(7.8, 0.38, 2.1), bench * CFrame.new(0, 1.82, 0), "Stone", Kit.decor())
	Kit.slab(gardens, "SeatShadowCourse", Vector3.new(7.9, 0.14, 2.2), bench * CFrame.new(0, 1.56, 0), "StoneDark", Kit.decor())
	for _, x in { -2.7, 2.7 } do
		Kit.slab(gardens, "StoneSeatTrestle", Vector3.new(0.95, 1.5, 1.6), bench * CFrame.new(x, 0.75, 0), "Stone", Kit.decor())
		Kit.slab(gardens, "StoneSeatFoot", Vector3.new(1.5, 0.24, 1.95), bench * CFrame.new(x, 0.12, 0), "StoneDark", Kit.decor())
	end
	gardens:SetAttribute("RaisedPrayerCourts", 2)
	gardens:SetAttribute("ProcessionalClearWidth", 32)
end

-- Lanterns along the front rim, either side of the landing.
local function rim(group: Instance, centre: CFrame, radius: number)
	for _, deg in { -58, -46, -34, -22, 22, 34, 46, 58 } do
		local a = math.rad(deg)
		Props.lantern(group, centre * CFrame.new(math.sin(a) * (radius - 9), 0, math.cos(a) * (radius - 9)))
	end
end

-- Floating karst is broad where it carries the sanctuary, then fractures downward into the clouds.
-- The vista meshes' closed, irregular feet form that plateau; their broken summits point down.
-- Eight overlapping outer masses and one central mass cover the complete support, so its smooth
-- collision cylinders and circular paving rim can disappear without leaving a hovering disc.
type Cliff = { Name: string, Angle: number, Reach: number, Height: number, Width: number, Depth: number }
local CLIFFS: { Cliff } = {
	{ Name = "Vista_Ridge", Angle = 3, Reach = 0.74, Height = 286, Width = 2.2, Depth = 3.8 },
	{ Name = "Vista_Crown", Angle = 46, Reach = 0.69, Height = 310, Width = 2.65, Depth = 3.025 },
	{ Name = "Vista_Ridge", Angle = 92, Reach = 0.74, Height = 274, Width = 2.2, Depth = 3.8 },
	{ Name = "Vista_Crown", Angle = 136, Reach = 0.67, Height = 298, Width = 2.55, Depth = 2.97 },
	{ Name = "Vista_Ridge", Angle = 181, Reach = 0.74, Height = 326, Width = 2.2, Depth = 3.8 },
	{ Name = "Vista_Crown", Angle = 227, Reach = 0.66, Height = 282, Width = 2.5, Depth = 2.915 },
	{ Name = "Vista_Ridge", Angle = 272, Reach = 0.74, Height = 304, Width = 2.2, Depth = 3.8 },
	{ Name = "Vista_Crown", Angle = 316, Reach = 0.70, Height = 294, Width = 2.6, Depth = 3.08 },
	{ Name = "Vista_Crown", Angle = 19, Reach = 0, Height = 258, Width = 3.2, Depth = 3.63 },
}

-- Reuse the imported, baked collision shape as a thin wafer at the rock cap. The descending cliff
-- stays nonphysical: colliding its whole body would intrude into the main staircase below it.
local function groundWafer(parent: Instance, rock: BasePart, top: number, index: number)
	local support = rock:Clone()
	support:ClearAllChildren()
	support.Name = "KarstCapGround_" .. index
	support.Size = Vector3.new(rock.Size.X, 0.6, rock.Size.Z)
	support.CFrame = CFrame.new(rock.Position.X, top - 0.3, rock.Position.Z) * rock.CFrame.Rotation
	support.Anchored, support.CanCollide, support.CanQuery, support.CanTouch = true, true, true, false
	support.Transparency, support.CastShadow = 1, false
	support:SetAttribute("AsuraGroundSupport", true)
	support.Parent = parent
end

-- The front mass extends over the stair approach. Its flanking cap bounds come from the actual
-- imported cap polygons, outside the old 246-stud floor and the neighbouring cliff caps. Two
-- shallow supports leave an unbroken +/-28-stud corridor above the original stairs and landing.
local function frontGround(parent: Instance, centre: CFrame, top: number)
	for i, b in { { -143, -28, 226, 296 }, { 28, 153, 224, 288 } } do
		local frame = centre * CFrame.new((b[1] + b[2]) / 2, top - 0.3, (b[3] + b[4]) / 2)
		local support = Kit.part(parent, "StairFlankCapGround_" .. i, Vector3.new(b[2] - b[1], 0.6, b[4] - b[3]), frame,
			Color3.fromRGB(90, 101, 112), M.Rock, { Collide = true, Query = true, Transparency = 1, Shadow = false })
		support.CanTouch = false
		support:SetAttribute("AsuraGroundSupport", true)
	end
end

local function underside(group: Instance, centre: CFrame, radius: number): boolean
	local cliffs = Kit.folder("TerraceKarstCliffs", group)
	local supports = Kit.folder("TerraceCapGround", group)
	local placed = 0
	for index, s in CLIFFS do
		local authoredHeight = if s.Name == "Vista_Crown" then 173.40224 else 155.18605
		local scale = Vector3.new(s.Width, s.Height / authoredHeight, s.Depth)
		local top = -0.075 - (index % 3) * 0.025
		local frame = centre * CFrame.Angles(0, math.rad(s.Angle), 0)
			* CFrame.new(0, top, radius * s.Reach) * CFrame.Angles(math.pi, 0, 0)
		local cliff = Kit.place(cliffs, s.Name, frame, scale)
		if cliff then
			cliff.Name = "TerraceKarstShoulder_" .. index
			cliff:SetAttribute("CliffTopElevation", centre.Position.Y + top)
			cliff:SetAttribute("CliffHeight", s.Height)
			for _, p in cliff:GetDescendants() do
				if p:IsA("BasePart") then
					-- Native summit moss would hang underneath the inverted island. The clean scanned
					-- rock alone also keeps this complete foundation to nine opaque MeshParts.
					if p.Name:find("__Moss", 1, true) then
						p:Destroy()
					else
						p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
						local finish = p:FindFirstChildOfClass("SurfaceAppearance")
						if finish then finish.Color = Color3.fromRGB(176, 190, 202) end
						if index > 1 and s.Reach > 0 then groundWafer(supports, p, centre.Position.Y + top, index) end
					end
				end
			end
			if index == 1 then frontGround(supports, centre, top) end
			placed += 1
		end
	end
	cliffs:SetAttribute("CragMeshBudget", 9)
	cliffs:SetAttribute("CragTriangleBudget", 170352)
	cliffs:SetAttribute("CompletePlateauFoundation", placed == #CLIFFS)
	supports:SetAttribute("SupportBudget", 9)
	supports:SetAttribute("StairClearanceHalfWidth", 28)
	return placed == #CLIFFS
end

-- A few crimson maples among the outer ruins, well off the path, the statue's views and the daises.
local TREES = { { -78, 150, 1.0 }, { -146, 60, 1.3 }, { 120, 196, 0.9 }, { 150, 40, 1.2 } }

function Terrace.Dress(group: Instance, centre: CFrame, radius: number, seat: number)
	processional(group, centre, radius, seat)
	forecourt(group, centre, radius)
	landscapeGardens(group, centre, seat)
	for i, t in TREES do
		Props.tree(group, centre * CFrame.new(t[1], -0.2, t[2]) * CFrame.Angles(0, i * 1.3, 0), t[3], i % 2 == 0)
		Props.shrub(group, centre * CFrame.new(t[1] + 5, -0.2, t[2] - 3), 1.3)
	end
	ruins(group, centre)
	rim(group, centre, radius)
	return underside(group, centre, radius)
end

return table.freeze(Terrace)

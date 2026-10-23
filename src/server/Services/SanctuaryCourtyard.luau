--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/SanctuaryCourtyard
-- The Shrine of the Ascendant's lower courtyard (lobby kit, concept 2026-10-21): a square paved
-- terrace with an axial path and bronze inlay lines, two long shallow jade-grey basins with carved
-- coping, the low three-step bonfire dais inside a radial paving medallion, stone lanterns flanking
-- the walk, memorial stelae and banners, and a carved balustrade open to the four routes (stairs N,
-- forge W, duel court E, pilgrim walk S). Collision is primitive: floors, dais steps, rim kerbs and
-- one wall per balustrade run. Coordinates are local to the plaza centre (north is -Z).
local Kit = require(script.Parent:WaitForChild("SanctuaryKit") :: ModuleScript)
local Rails = require(script.Parent:WaitForChild("SanctuaryRails") :: ModuleScript)
local Leaves = require(script.Parent:WaitForChild("SanctuaryLeaves") :: ModuleScript)
local Bonfire = require(script.Parent:WaitForChild("SanctuaryBonfire") :: ModuleScript)
local Props = require(script.Parent:WaitForChild("SanctuaryProps") :: ModuleScript)
local Assets = require(game:GetService("ReplicatedStorage").AsurasPath.Shared.PresentationAssets)
local Terrain = game:GetService("Workspace").Terrain

local Courtyard = {}

local HALF = 46 -- north/south extent and existing route anchors stay fixed
local HALF_X = 58
local TOP = 0.1 -- flagstone top
local POOL = { X0 = 24, X1 = 42, Z0 = -20, Z1 = 32, Floor = -0.7, Water = -0.14 }
-- Openings in the balustrade, as half-widths: north stairs, west/east walkways, south pilgrim walk.
local OPEN = { N = 20, W = 7, E = 7, S = 14 }
Courtyard.Half, Courtyard.Top, Courtyard.Pool, Courtyard.Open = HALF, TOP, table.freeze(POOL), table.freeze(OPEN)

local Y = Vector3.yAxis
local function invisible(): any
	return { Collide = true, Query = false, Transparency = 1, Shadow = false }
end

-- Broad stone courses are deliberately quiet; the existing PBR supplies chips and fine grain.
-- These recessed dark joints break the machine-regular texture at normal player-camera height.
local function pavingJoints(group: Instance, origin: CFrame, x0: number, x1: number, z0: number, z1: number)
	local row, width = 4.8, x1 - x0
	for k = 1, math.floor((z1 - z0) / row) do
		local z = z0 + k * row
		Kit.part(group, "RecessedPavingJoint", Vector3.new(width, 0.018, 0.045), origin * CFrame.new((x0 + x1) / 2, TOP + 0.007, z),
			Color3.fromRGB(55, 63, 66), Enum.Material.Slate, Kit.decor())
		local phase = if k % 2 == 0 then 0.28 else 0.62
		for j = 1, 2 do
			local x = x0 + width * (j - phase) / 2
			Kit.part(group, "RecessedPavingJoint", Vector3.new(0.045, 0.018, math.min(row, z1 - z + row)),
				origin * CFrame.new(x, TOP + 0.007, z - row / 2), Color3.fromRGB(55, 63, 66), Enum.Material.Slate, Kit.decor())
		end
	end
end

local function basin(group: Instance, origin: CFrame, side: number)
	local x0, x1 = side * POOL.X0, side * POOL.X1
	local cx, cz = (x0 + x1) / 2, (POOL.Z0 + POOL.Z1) / 2
	local w, l = math.abs(x1 - x0), POOL.Z1 - POOL.Z0
	Kit.slab(group, "BasinFloor", Vector3.new(w, 2, l), origin * CFrame.new(cx, POOL.Floor - 1, cz), "Basin")
	-- Real water supplies ripples and local reflections. Its voxel bounds extend under the paving:
	-- the solid floor and coping conceal Terrain's rounded shore and keep the basin shallow to walk.
	-- Water extends under the coping and paving; the finished rim exposes only the two basins.
	local a = (origin * CFrame.new(math.min(x0, x1), 0, POOL.Z0)).Position
	local b = (origin * CFrame.new(math.max(x0, x1), 0, POOL.Z1)).Position
	local left = math.floor(a.X / 4) * 4 - (if side > 0 then 4 else 0)
	local right = math.ceil(b.X / 4) * 4 + (if side < 0 then 4 else 0)
	local front, back = math.floor(a.Z / 4) * 4 - 4, math.ceil(b.Z / 4) * 4 + 4
	Terrain:FillBlock(CFrame.new((left + right) / 2, origin.Y - 2, (front + back) / 2), Vector3.new(right - left, 4, back - front), Enum.Material.Water)
	Kit.hidden(group, "StillWater", Vector3.new(w, 0.1, l), origin * CFrame.new(cx, POOL.Water - 0.05, cz))
	Leaves.Scatter(group, origin * CFrame.new(cx, POOL.Water + 0.02, cz), Vector2.new(w / 2 - 0.8, l / 2 - 1), 14, 90 + side, true)
	if Assets.Textures.Smoke ~= "" then
		for _, z in { POOL.Z0 + 9, cz, POOL.Z1 - 9 } do
			local anchor = Kit.hidden(group, "PoolMistEdge", Vector3.new(1, 0.1, 8), origin * CFrame.new(side * (POOL.X0 + 1.8), 0.1, z))
			local mist = Instance.new("ParticleEmitter")
			mist.Name, mist.Texture, mist.Rate = "WaterEdgeMist", Assets.Textures.Smoke, 0.38
			mist.Lifetime, mist.Speed, mist.Acceleration = NumberRange.new(4, 6), NumberRange.new(0.15, 0.35), Vector3.new(0.12, 0.08, 0)
			mist.Size = Kit.sequence({ { 0, 1 }, { 1, 4.5 } })
			mist.Transparency = Kit.sequence({ { 0, 1 }, { 0.25, 0.88 }, { 1, 1 } })
			mist.Color, mist.LightInfluence = ColorSequence.new(Color3.fromRGB(211, 217, 216)), 0.65
			mist.Rotation, mist.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-4, 4)
			mist.Parent = anchor
		end
	end
	-- Coping on all four edges; each piece's back (+Z) faces the water, its pivot on the water edge.
	local edges = {
		{ Vector3.new(x0, 0, POOL.Z0), Vector3.new(x0, 0, POOL.Z1), Vector3.new(side, 0, 0) },
		{ Vector3.new(x1, 0, POOL.Z0), Vector3.new(x1, 0, POOL.Z1), Vector3.new(-side, 0, 0) },
		{ Vector3.new(x0, 0, POOL.Z0), Vector3.new(x1, 0, POOL.Z0), Vector3.new(0, 0, 1) },
		{ Vector3.new(x0, 0, POOL.Z1), Vector3.new(x1, 0, POOL.Z1), Vector3.new(0, 0, -1) },
	}
	for _, e in edges do
		local a, b, into = e[1], e[2], e[3]
		local mid = (a + b) * 0.5
		local length = (b - a).Magnitude
		local frame = CFrame.fromMatrix(mid + Y * TOP, Y:Cross(into), Y)
		-- Each carved coping bay keeps the original grain scale; long one-piece stretches read as plastic.
		local bays = math.max(1, math.round(length / 8))
		local bay = length / bays
		for i = 1, bays do
			local at = origin * frame * CFrame.new(-length / 2 + bay * (i - 0.5), 0, 0)
			if not Kit.place(group, "Pool_Rim", at, Vector3.new((bay - 0.025) / 8, 1, 1)) then
				Kit.slab(group, "BasinCoping", Vector3.new(bay - 0.025, 0.5, 1.2), at * CFrame.new(0, 0.2, -0.6), "Stone", Kit.decor())
			end
		end
		Kit.slab(group, "BasinWaterline", Vector3.new(length - 0.2, 0.14, 0.18), origin * frame * CFrame.new(0, -0.12, 0.12), "StoneDark", Kit.decor())
		Kit.slab(group, "CopingShadowCourse", Vector3.new(length, 0.12, 0.16), origin * frame * CFrame.new(0, 0.13, -1.13), "StoneDark", Kit.decor())
		local kerb = (origin * frame * CFrame.new(0, 0, -0.62)).Position
		local along = (origin * frame).XVector * length * 0.5
		Kit.blocker(group, "CopingKerb", kerb - along - Y * 0.0, kerb + along, 0.5, 1.25)
	end
	for _, c in { { x0, POOL.Z0 }, { x1, POOL.Z0 }, { x0, POOL.Z1 }, { x1, POOL.Z1 } } do
		local ox = if math.abs(c[1]) < math.abs(cx) then -side else side
		local oz = if c[2] < cz then -1 else 1
		Kit.place(group, "Pool_Corner", origin * CFrame.new(c[1] + ox * 0.62, TOP, c[2] + oz * 0.62))
	end
end

local function dais(group: Instance, origin: CFrame)
	Kit.place(group, "Paving_Medallion", origin * CFrame.new(0, TOP - 0.01, 0))
end

local function balustrade(group: Instance, origin: CFrame)
	local ex, ez = HALF_X - 0.6, HALF - 0.6
	local function run(a: Vector3, b: Vector3)
		Rails.run(group, (origin * CFrame.new(a + Y * TOP)).Position, (origin * CFrame.new(b + Y * TOP)).Position)
	end
	for side = -1, 1, 2 do
		run(Vector3.new(side * ex, 0, -ez), Vector3.new(side * OPEN.N, 0, -ez))
		run(Vector3.new(side * ex, 0, ez), Vector3.new(side * OPEN.S, 0, ez))
		run(Vector3.new(-ex, 0, side * ez), Vector3.new(-ex, 0, side * OPEN.W))
		run(Vector3.new(ex, 0, side * ez), Vector3.new(ex, 0, side * OPEN.E))
	end
end

-- Builds the courtyard; returns the bonfire altar's anchor part (WorldService mounts its rest prompt).
function Courtyard.Build(parent: Instance, origin: CFrame, altarId: string, plinth: number): BasePart
	local group = Kit.folder("CentralPlaza", parent)
	local function floor(name: string, x0: number, x1: number, z0: number, z1: number, surface: string)
		Kit.slab(group, name, Vector3.new(x1 - x0, 4, z1 - z0), origin * CFrame.new((x0 + x1) / 2, TOP - 2, (z0 + z1) / 2), surface)
	end
	floor("AxialWalk", -POOL.X0, POOL.X0, -HALF, HALF, "PavingPath")
	pavingJoints(group, origin, -POOL.X0 + 1.5, POOL.X0 - 1.5, -HALF + 1, HALF - 1)
	for side = -1, 1, 2 do
		local a, b = math.min(side * POOL.X1, side * HALF_X), math.max(side * POOL.X1, side * HALF_X)
		floor("Flagstones", a, b, -HALF, HALF, "Paving")
		local c, d = math.min(side * POOL.X0, side * POOL.X1), math.max(side * POOL.X0, side * POOL.X1)
		floor("Flagstones", c, d, -HALF, POOL.Z0, "Paving")
		floor("Flagstones", c, d, POOL.Z1, HALF, "Paving")
		basin(group, origin, side)
		pavingJoints(group, origin, a + 0.5, b - 0.5, POOL.Z0, POOL.Z1)
		Kit.slab(group, "PathInlay", Vector3.new(0.12, 0.04, HALF * 2 - 2), origin * CFrame.new(side * 19.5, TOP + 0.01, 0), "Bronze", Kit.decor())
		for _, z in { -16, 27, 42.5 } do
			Props.lantern(group, origin * CFrame.new(side * 21.2, TOP, z))
		end
		Props.stele(group, origin * CFrame.new(side * 49, TOP, 37) * CFrame.Angles(0, math.rad(side * 45), 0), "REMEMBER\nDEATH")
		for _, x in { 28, 42 } do
			Props.banner(group, origin * CFrame.new(side * x, TOP, HALF - 1.6))
		end
		-- Sparse crimson maples and shrubs in the outer strips, echoing the sacred tree's leaves.
		Props.tree(group, origin * CFrame.new(side * 50.5, TOP, 20) * CFrame.Angles(0, side, 0), 0.8)
		for _, z in { 10, 30, 41 } do
			Props.shrub(group, origin * CFrame.new(side * 55.4, TOP, z) * CFrame.Angles(0, z, 0), 1.1)
		end
	end
	Kit.slab(group, "TerraceSkirting", Vector3.new(HALF_X * 2 + 1, 2.2, HALF * 2 + 1), origin * CFrame.new(0, TOP - 4.6, 0), "StoneDark")
	dais(group, origin)
	balustrade(group, origin)
	local anchor = Kit.part(group, "AltarAnchor_" .. altarId, Vector3.new(1, 0.2, 1), origin * CFrame.new(0, plinth, 0), Color3.new(), Enum.Material.Slate,
		{ Collide = false, Query = false, Transparency = 1, Shadow = false })
	Bonfire.Build(group, origin * CFrame.new(0, TOP + 0.03, 0))
	local petals = Kit.hidden(group, "PetalAnchor", Vector3.new(HALF * 1.8, 1, HALF * 1.8), origin * CFrame.new(0, 32, 0))
	Leaves.Emitter(petals, { Rate = 2, Size = 0.28, Wind = Vector3.new(1.5, -1.0, 0.8) })
	return anchor
end

return table.freeze(Courtyard)

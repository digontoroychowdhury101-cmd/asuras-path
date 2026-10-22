--!strict
-- ModuleScript: ServerScriptService/AsurasPath/Services/MonasteryTerrain
-- Terrain of the Desecrated Monastery: the valley floor of mud and sour moss between dark rock
-- ridges, the side plateau holding the Twin Sentinels' arena with the pass cut to reach it, and the
-- misted ravine. Walkable tops stay just under MonasteryKit.GROUND so the flagstones cover them.
-- Batch 07: the floor used to span the region bounds, which the boss roster widened to 900 studs
-- for the Twins' side courtyard, leaving flat empty ground ~350 studs past both ridges. It now
-- covers only the valley, the plateau and the pass; MonasteryBounds walls the crest.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("AsurasPath").Shared.WorldDefinitions)
local Zones = require(ReplicatedStorage:WaitForChild("AsurasPath").Shared.MonasteryZones)

local Terrain = {}

local BOUNDS = (World.Regions :: any).DesecratedMonastery.Bounds
local CENTER = Vector3.new(BOUNDS.Center.X, 0, BOUNDS.Center.Z)
local MARGIN = 80

Terrain.RAVINE_Z = -960
Terrain.VALLEY_HALF = 214 -- floor half-width; the ridge crests stand near x = ±180..200
Terrain.PLATEAU = { X0 = 206, X1 = 404, Z0 = -786, Z1 = -1034 } -- Twins arena (x 210..390) and approach
Terrain.EAST_PASS = { X0 = 140, X1 = 236, Z0 = -796, Z1 = -824 } -- the courtyard road's cut through the ridge

-- Smooth terrain renders and collides 2 studs above a filled block's top, so fills stop at
-- TERRAIN_TOP to leave the surface just under the flagstones.
local TERRAIN_TOP = -2.2

-- Terrain extent cleared on build and teardown (region bounds plus the cliff margin).
function Terrain.Extent(): (CFrame, Vector3)
	return CFrame.new(CENTER.X, -20, CENTER.Z), Vector3.new(BOUNDS.Size.X + MARGIN * 2, 120, BOUNDS.Size.Z + MARGIN * 2)
end

function Terrain.Clear()
	local cframe, size = Terrain.Extent()
	Workspace.Terrain:FillBlock(cframe, size, Enum.Material.Air)
end

local function floor(t: Terrain, x0: number, x1: number, z0: number, z1: number)
	t:FillBlock(CFrame.new((x0 + x1) * 0.5, (TERRAIN_TOP - 16) * 0.5, (z0 + z1) * 0.5), Vector3.new(x1 - x0, 16 + TERRAIN_TOP, math.abs(z1 - z0)), Enum.Material.Ground)
end

-- Batch 15 (#26): the dead ground between the outer walls and the ridges becomes boulder scree,
-- keeping clear of every walked zone, the waterfall path and alcove, the ridge-pass road and the
-- ravine, so leaving the route is either the authored secret or a visible climb, not empty flat.
Terrain.Scree = {
	{ -180, -90, -662, -934 }, { 90, 180, -662, -934 }, { -180, -34, -662, -752 }, { 34, 180, -662, -752 },
	{ -180, -140, -926, -1120 }, { 136, 180, -926, -1120 },
}
-- Batch 24: the Gatehouse sparring ring (ColosseumService Ring_GatehouseCircle) keeps a clear yard
-- that opens onto the waterfall path; the batch 15 scree had buried its octagon. Stones that would
-- touch it are skipped after their random draws, so every other scattered stone stays where it was.
Terrain.SPARRING_YARD = { X = -130, Z = -745, Clear = 30 }
function Terrain.inYard(x: number, z: number, radius: number): boolean
	local yard = Terrain.SPARRING_YARD
	return math.sqrt((x - yard.X) ^ 2 + (z - yard.Z) ^ 2) < radius + yard.Clear
end
function Terrain.screeClear(x: number, z: number, radius: number): boolean
	if z < -936 and z > -994 and math.abs(x) < 140 then return false end -- the ravine keeps its own shape
	if math.abs(z + 811) < radius + 10 and x > 70 then return false end -- road through the ridge pass
	if Zones.distanceToPath(Zones.WestPath, x, z) < radius + 3 then return false end
	if math.sqrt((x - Zones.Alcove.X) ^ 2 + (z - Zones.Alcove.Z) ^ 2) < radius + 10 then return false end
	for _, zone in Zones.List do -- boulders end a stud outside the walls, so no flat band remains
		if zone.Id ~= "WestReach" and zone.Id ~= "EastPass" and Zones.contains(zone, x, z, radius + 1) then return false end
	end
	return true
end

local function scree(t: Terrain, rng: Random)
	for _, box in Terrain.Scree do
		for x = box[1], box[2], 8 do
			for z = box[3], box[4], -8 do
				local r = rng:NextNumber(8, 12)
				local px, pz = x + rng:NextNumber(-2, 2), z + rng:NextNumber(-2, 2)
				while r >= 4 and not Terrain.screeClear(px, pz, r) do r -= 2 end -- smaller stones fill the seams by walls
				if r >= 4 then
					local lift, rock = rng:NextNumber(1, 5), rng:NextNumber() < 0.7
					if not Terrain.inYard(px, pz, r) then
						t:FillBall(Vector3.new(px, lift * r / 10, pz), r, if rock then Enum.Material.Rock else Enum.Material.Slate)
					end
				end
			end
		end
	end
end

function Terrain.Build(rng: Random)
	local t = Workspace.Terrain
	t:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(58, 50, 44))
	t:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(46, 38, 34))
	t:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(70, 68, 46))
	t:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(62, 62, 64))
	t:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(52, 54, 56))
	local sz = BOUNDS.Size.Z + MARGIN * 2
	floor(t, -Terrain.VALLEY_HALF, Terrain.VALLEY_HALF, CENTER.Z + sz * 0.5, CENTER.Z - sz * 0.5)
	local plateau = Terrain.PLATEAU
	floor(t, plateau.X0, plateau.X1, plateau.Z0, plateau.Z1)
	-- Top-layer patches of mud and sour moss break up the floor between the stones.
	for _ = 1, 36 do
		local x, z = rng:NextNumber(-190, 190), CENTER.Z + rng:NextNumber(-215, 215)
		local material = if rng:NextNumber() < 0.55 then Enum.Material.Mud else Enum.Material.LeafyGrass
		t:FillBlock(CFrame.new(x, TERRAIN_TOP - 1, z), Vector3.new(rng:NextNumber(16, 40), 2, rng:NextNumber(16, 40)), material)
	end
	-- Valley walls: dark rock ridges east, west and north; the south stays open for the road.
	for z = -640, -1160, -22 do
		for side = -1, 1, 2 do
			local x = side * (180 + rng:NextNumber(-6, 12))
			t:FillBall(Vector3.new(x, rng:NextNumber(-6, 14), z), rng:NextNumber(26, 36), Enum.Material.Rock)
			t:FillBall(Vector3.new(x + side * 18, rng:NextNumber(18, 38), z), rng:NextNumber(18, 26), Enum.Material.Slate)
		end
	end
	for x = -200, 200, 22 do
		t:FillBall(Vector3.new(x, rng:NextNumber(-4, 16), -656 + rng:NextNumber(-4, 4)), rng:NextNumber(24, 32), Enum.Material.Rock)
	end
	scree(t, rng)
	-- The east pass: a cut through the ridge where the courtyard road leaves for the side plateau.
	local pass = Terrain.EAST_PASS
	t:FillBlock(CFrame.new((pass.X0 + pass.X1) * 0.5, 22.5, (pass.Z0 + pass.Z1) * 0.5), Vector3.new(pass.X1 - pass.X0, 44, math.abs(pass.Z1 - pass.Z0)), Enum.Material.Air)
	-- The ravine: a chain of spherical cuts that taper into the cliffs at both ends.
	for x = -136, 136, 8 do
		local taper = math.clamp((math.abs(x) - 100) / 36, 0, 1)
		t:FillBall(Vector3.new(x, 14, Terrain.RAVINE_Z + rng:NextNumber(-1.5, 1.5)), 26 - taper * 11, Enum.Material.Air)
	end
	local ravine = Region3.new(Vector3.new(-140, -16, Terrain.RAVINE_Z - 28), Vector3.new(140, -2, Terrain.RAVINE_Z + 28))
	t:ReplaceMaterial(ravine:ExpandToGrid(4), 4, Enum.Material.Ground, Enum.Material.Mud)
end

return Terrain
